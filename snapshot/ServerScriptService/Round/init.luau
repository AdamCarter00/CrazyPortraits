local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants        = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local StrokeCodec      = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("StrokeCodec"))

local RoundState       = require(script:WaitForChild("RoundState"))
local RoundRemotes     = require(script:WaitForChild("RoundRemotes"))

local ThemeService         = require(script.Parent:WaitForChild("ThemeService"))
local SubjectService       = require(script.Parent:WaitForChild("SubjectService"))
local Analytics            = require(script.Parent:WaitForChild("AnalyticsService"))
local ModerationService    = require(script.Parent:WaitForChild("ModerationService"))
local GroupService         = require(script.Parent:WaitForChild("GroupService"))
local SessionService       = require(script.Parent:WaitForChild("SessionService"))
local QuitLog              = require(script.Parent:WaitForChild("QuitLog"))
local FirstDrawingService  = require(script.Parent:WaitForChild("FirstDrawingService"))
local PlayerDataService    = require(script.Parent:WaitForChild("PlayerDataService"))

local sessionRounds = {}

--------------------------------------------------------------------------------
-- Remotes
--------------------------------------------------------------------------------

local Remotes            = ReplicatedStorage:WaitForChild("Remotes")
local PhaseRemote        = Remotes:WaitForChild("PhaseRemote")
local EmojiRemote        = Remotes:WaitForChild("EmojiRemote")
local ClearDisplayRemote = Remotes:WaitForChild("ClearDisplayRemote")
local HideDrawingRemote  = Remotes:WaitForChild("HideDrawingRemote")
local GalleryRemote      = Remotes:WaitForChild("GalleryRemote")
local ResultRemote       = Remotes:WaitForChild("ResultRemote")
local SubjectChanceRemote = Remotes:WaitForChild("SubjectChanceRemote")
local TutorialRemote     = Remotes:WaitForChild("TutorialRemote")

local MAX_GALLERY_SLOTS = Constants.GALLERY_SLOT_COUNT

local TOTAL_THEMES = #ThemeService.themes

local RoundManager = {}
RoundManager.state               = RoundState.new()
RoundManager.reportCounts        = {}  -- [playerName] = reporterSet ({[userId]=true}), reset per drawing
RoundManager.currentDrawingMeta  = nil -- { ownerName, ownerUserId, theme, buffer }
RoundManager.lastRoundDrawings   = {}  -- list of { playerName, ownerUserId, theme, buffer } from previous round
RoundManager.roundReportsByUser  = {}  -- [reporterUserId] = { [ownerName]=true }, drives each player's gallery filter
RoundManager.roundReportTotals   = {}  -- [ownerName] = distinctReporterCount, drives the >=threshold global gallery filter
RoundManager.roundEmojiResults   = {}  -- [ownerName] = { tally = { [emojiName] = count }, emojiStars, roundStars }, this round's per-drawing result (sent to each owner in CleanRound)
RoundManager.subjectQueue        = {}  -- FIFO list of userIds who bought the subject guarantee; head (if still in lobby) is next round's subject

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local PHASE_SLUG = {
	Waiting              = "Waiting",
	DRAWING_PHASE        = "Drawing",
	COLLECTING_PHASE     = "Collecting",
	REVEAL_INTRO_PHASE   = "RevealIntro",
	REVEAL_PHASE         = "Reveal",
	CLEAN_ROUND_PHASE    = "Clean",
}

local function phaseToSlug(phase)
	return PHASE_SLUG[phase] or "Unknown"
end

local function broadcastPhase(playerList, ...)
	for _, player in ipairs(playerList) do
		if player.Parent then
			PhaseRemote:FireClient(player, ...)
		end
	end
end

local function allSubmitted(playerList, players, spectators)
	for _, player in ipairs(playerList) do
		-- Spectators never draw, so they would otherwise pin this to false forever and
		-- block the early finish even after every drawer has submitted.
		if spectators and spectators[player] then continue end
		if player.Parent and players[player] and not players[player].drawingData then
			return false
		end
	end
	return true
end

-- Captures ownerUserId here (while the owner is still in playerList) so the
-- reveal/report flow keeps a valid UserId even if the owner leaves before or
-- during the reveal of their drawing. Looking it up from a live Player later
-- would yield 0 once they have left, which silently breaks the ban path.
local function collectDrawings(playerList, players)
	local drawings = {}
	for _, player in ipairs(playerList) do
		local ps = players[player]
		if ps and ps.drawingData and #ps.drawingData > 0 then
			table.insert(drawings, {
				playerName  = player.Name,
				ownerUserId = player.UserId,
				theme       = ps.currentTheme,
				data        = ps.drawingData,
			})
		end
	end
	return drawings
end

local function resetPlayerStates(playerList, players)
	for _, player in ipairs(playerList) do
		local ps = players[player]
		if not ps then continue end

		if ps.currentTheme then
			ps.bannedThemes[ps.currentTheme] = true
		end

		local count = 0
		for _ in pairs(ps.bannedThemes) do count += 1 end
		if count >= TOTAL_THEMES then
			ps.bannedThemes = {}
		end

		ps.drawingData             = nil
		ps.currentTheme            = nil
		ps.submittedDuringDrawing  = false
		ps.submitElapsed           = nil
		ps.strokesDrawn            = 0
		ps.undoCount               = 0
	end
end

local function buildBannedSlots(playerList, players)
	local bannedPerSlot = {}
	for i, player in ipairs(playerList) do
		local ps          = players[player]
		bannedPerSlot[i]  = ps and ps.bannedThemes or nil
	end
	return bannedPerSlot
end

local function delayWithToken(state, seconds, fn)
	local myToken = state.round.token
	task.delay(seconds, function()
		if not state:IsTokenValid(myToken) then return end
		fn()
	end)
end

-- Resolves the reveal seats (Map/GamePlay/Reveal/Seats/seat1..seatN). Returns the
-- seat parts sorted by their numeric suffix so seat1 is always slot 1, regardless
-- of child order in Studio. Returns an empty list (with a warn) if the folder is
-- missing, so the caller can skip teleporting rather than error.
local function getRevealSeats()
	local map      = workspace:FindFirstChild("Map")
	local gamePlay = map and map:FindFirstChild("GamePlay")
	local reveal   = gamePlay and gamePlay:FindFirstChild("Reveal")
	local folder   = reveal and reveal:FindFirstChild("Seats")
	if not folder then
		warn("[RoundManager] getRevealSeats: Map/GamePlay/Reveal/Seats missing")
		return {}
	end

	local seats = {}
	for _, child in ipairs(folder:GetChildren()) do
		local index = tonumber(child.Name:match("^seat(%d+)$"))
		if child:IsA("BasePart") and index then
			table.insert(seats, { index = index, part = child })
		end
	end
	table.sort(seats, function(a, b) return a.index < b.index end)

	local ordered = {}
	for i, entry in ipairs(seats) do
		ordered[i] = entry.part
	end
	return ordered
end

-- Teleports every player still in the round to their own reveal seat. Each player
-- gets a distinct seat (seat1, seat2, ...); the lobby is capped at the seat count
-- so there are always enough. If players outnumber seats anyway, the extras are
-- left where they are and a warn is logged (the "one seat per player" rule wins
-- over forcing everyone in).
local function teleportToRevealSeats(playerList)
	local seats = getRevealSeats()
	if #seats == 0 then return end

	local seatIndex = 0
	for _, player in ipairs(playerList) do
		if not player.Parent then continue end
		local character = player.Character
		local rootPart  = character and character:FindFirstChild("HumanoidRootPart")
		if not rootPart then continue end

		seatIndex += 1
		local seat = seats[seatIndex]
		if not seat then
			warn("[RoundManager] teleportToRevealSeats: ran out of seats, leaving", player.Name, "in place")
			break
		end
		character:PivotTo(seat.CFrame + Vector3.new(0, 5, 0))
	end
end

local function getGallerySpots()
	local map      = workspace:FindFirstChild("Map")
	local gamePlay = map and map:FindFirstChild("GamePlay")
	local gallery  = gamePlay and gamePlay:FindFirstChild("Gallery")
	local folder   = gallery and gallery:FindFirstChild("GalleryParts")
	if not folder then
		warn("[RoundManager] getGallerySpots: Map/GamePlay/Gallery/GalleryParts missing")
		return {}
	end

	local spots = {}
	for _, child in ipairs(folder:GetChildren()) do
		local index = tonumber(child.Name)
		if child:IsA("BasePart") and index then
			table.insert(spots, { index = index, part = child })
		end
	end
	table.sort(spots, function(a, b) return a.index < b.index end)

	local ordered = {}
	for i, entry in ipairs(spots) do
		ordered[i] = entry.part
	end
	return ordered
end

local function teleportToGallerySpots(playerList)
	local spots = getGallerySpots()
	if #spots == 0 then return end

	local spotIndex = 0
	for _, player in ipairs(playerList) do
		if not player.Parent then continue end
		local character = player.Character
		local rootPart  = character and character:FindFirstChild("HumanoidRootPart")
		if not rootPart then continue end

		spotIndex += 1
		local spot = spots[spotIndex]
		if not spot then
			warn("[RoundManager] teleportToGallerySpots: ran out of spots, leaving", player.Name, "in place")
			break
		end
		character:PivotTo(spot.CFrame + Vector3.new(0, 5, 0))
	end
end

-- Resolves the single waiting pad (Map/GamePlay/SubmitPart) a player is moved to right
-- after they submit. One shared part (not per-player like the seats), so submitters gather
-- there while the rest keep drawing. Returns nil (with a warn) if it is missing so the
-- caller skips the teleport rather than errors.
local function getSubmitPart()
	local map      = workspace:FindFirstChild("Map")
	local gamePlay = map and map:FindFirstChild("GamePlay")
	local part     = gamePlay and gamePlay:FindFirstChild("SubmitPart")
	if not part or not part:IsA("BasePart") then
		warn("[RoundManager] getSubmitPart: Map/GamePlay/SubmitPart missing")
		return nil
	end
	return part
end

-- Teleports one player onto the submit pad (called from OnSubmitButtonPressed). No-op if the
-- part or the player's character is missing.
local function teleportToSubmitPart(player)
	local part = getSubmitPart()
	if not part then return end

	local character = player.Character
	local rootPart  = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	character:PivotTo(part.CFrame + Vector3.new(0, 5, 0))
end

--------------------------------------------------------------------------------
-- Subject Guarantee
--------------------------------------------------------------------------------

-- Returns the queue-head player who is still in the lobby (ready), without consuming
-- the queue. Skips queued userIds whose player has left or is not ready: they keep
-- their place (their guarantee is persisted), they just cannot be subject this round.
-- nil if the queue is empty or no queued player is currently eligible.
function RoundManager:_resolveGuaranteedPlayer()
	for _, userId in ipairs(self.subjectQueue) do
		local player = Players:GetPlayerByUserId(userId)
		if player and self.state.readyPlayers[player] then
			return player
		end
	end
	return nil
end

-- Drops a player from the subject queue (by userId). Used once they have been made the
-- subject, or to clear a stale entry.
function RoundManager:_dequeueSubject(userId)
	for i = #self.subjectQueue, 1, -1 do
		if self.subjectQueue[i] == userId then
			table.remove(self.subjectQueue, i)
		end
	end
end

-- Computes each ready player's odds of being the next subject and pushes them so the
-- lobby chance bar stays live. Shows ONLY the weighted-system odds (SubjectService,
-- lastModel excluded); it intentionally ignores the guarantee queue, so a player's bar
-- never reveals whether someone bought their way to next subject.
function RoundManager:BroadcastSubjectChances()
	local readyList = self.state:GetReadyPlayers()
	local chances   = SubjectService:ComputeChances(readyList)

	for _, player in ipairs(readyList) do
		if player.Parent then
			SubjectChanceRemote:FireClient(player, chances[player] or 0)
		end
	end
end

-- Queues a player who just bought the subject guarantee (called by
-- SubjectGuaranteeService on a granted receipt). Appended once (FIFO); re-pushes the
-- lobby chances so the bars update immediately.
function RoundManager:EnqueueSubjectGuarantee(player)
	for _, userId in ipairs(self.subjectQueue) do
		if userId == player.UserId then
			self:BroadcastSubjectChances()
			return
		end
	end
	table.insert(self.subjectQueue, player.UserId)
	self:BroadcastSubjectChances()
end

--------------------------------------------------------------------------------
-- Player Lifecycle
--------------------------------------------------------------------------------

-- Returns the last round's gallery filtered for one player: drawings they
-- reported are removed, and drawings that reached the report threshold are
-- removed for everyone. Entries are compacted so the client sees no gaps.
function RoundManager:buildGalleryForPlayer(player)
	local result    = {}
	local userSet   = self.roundReportsByUser[player.UserId]
	local threshold = ModerationService.getThreshold()
	for _, entry in ipairs(self.lastRoundDrawings) do
		local hiddenForAll = (self.roundReportTotals[entry.playerName] or 0) >= threshold
		local reportedByMe = userSet and userSet[entry.playerName]
		if not hiddenForAll and not reportedByMe then
			table.insert(result, entry)
		end
	end
	return result
end

-- Pulls a banned owner's drawing from BOTH the live reveal and the lobby gallery.
-- Fired (on every server) by the BanService.onBan hook, so it must work in any
-- phase and be safe when the owner has no drawing showing — both branches no-op
-- in that case, and double-firing is harmless.
function RoundManager:RemoveOwnerDrawings(userId)
	if typeof(userId) ~= "number" then return end

	-- 1) If this exact drawing is on screen during reveal, cover it with the same
	-- barrier the report-threshold path uses (client shows the overlay + clears).
	local meta = self.currentDrawingMeta
	if meta and meta.ownerUserId == userId and self.state.round.phase == "REVEAL_PHASE" then
		for _, p in ipairs(self.state.round.currentPlayers) do
			if p.Parent then
				HideDrawingRemote:FireClient(p)
			end
		end
	end

	-- 2) Drop the owner's entry from the gallery source so it stays gone for the
	-- rest of this gallery's lifetime, then re-push to everyone currently in the
	-- lobby (compacted by buildGalleryForPlayer, so no empty slot is left).
	local removed = false
	for i = #self.lastRoundDrawings, 1, -1 do
		if self.lastRoundDrawings[i].ownerUserId == userId then
			table.remove(self.lastRoundDrawings, i)
			removed = true
		end
	end
	if removed then
		for _, p in ipairs(Players:GetPlayers()) do
			GalleryRemote:FireClient(p, self:buildGalleryForPlayer(p))
		end
	end
end

function RoundManager:OnPlayerAdded(player)
	sessionRounds[player] = 0
	self.state:AddPlayer(player)
	SubjectService:OnPlayerAdded(player)

	-- Deterministic from UserId (no DataStore, never fails), so assign inline.
	local ps = self.state.players[player]
	if ps then
		ps.group = GroupService:LoadGroup(player.UserId)
	end

	task.spawn(function()
		-- Same: a thrown error here would leave lifetimeSession at -1 (unknown),
		-- so the first-timer capture would silently never fire for this player.
		local ok, err = pcall(function()
			SessionService:BeginSession(player.UserId)
			local ps = self.state.players[player]
			if ps then
				ps.lifetimeSession = SessionService:GetSessionCount(player.UserId)
			end
		end)
		if not ok then
			warn("[RoundManager] BeginSession failed for", player.Name, "-", err)
		end
	end)

	if #self.lastRoundDrawings > 0 then
		GalleryRemote:FireClient(player, self:buildGalleryForPlayer(player))
	end

	-- Re-queue a persisted, unspent guarantee (Robux is non-refundable, so a buyer who
	-- left before their turn keeps it). PlayerDataService loads the profile before this
	-- runs (see GameServer order); EnqueueSubjectGuarantee de-dupes by userId. Also
	-- pushes this player's initial chance bar even when they have no guarantee.
	if PlayerDataService:HasGuarantee(player) then
		self:EnqueueSubjectGuarantee(player)
	else
		self:BroadcastSubjectChances()
	end
end

function RoundManager:OnPlayerRemoving(player)
	local rounds      = sessionRounds[player] or 0
	sessionRounds[player] = nil

	-- A spectator leaving mid-round produces zero analytics for the round they only
	-- watched (the same rule as the rest of the round): skip the quit/rounds logging
	-- entirely and go straight to resource cleanup below.
	if self.state.round.spectators[player] then
		Analytics:ClearPlayer(player)
		self.state:RemovePlayer(player)
		SubjectService:OnPlayerRemoving(player)
		SessionService:ClearCache(player.UserId)
		return
	end

	local phase       = self.state.round.phase
	local playerState = self.state.players[player]
	local group       = playerState and playerState.group or nil
	local lobbyCount = 0
	for _ in pairs(self.state.readyPlayers) do
		lobbyCount += 1
	end
	-- The leaving player is still in readyPlayers at this point; subtract them.
	local peersRemaining = math.max(0, lobbyCount - 1)

	local quitEvent
	local quitValue        = peersRemaining
	local quitCustomFields = nil
	if phase == "DRAWING_PHASE" and playerState and playerState.submittedDuringDrawing then
		quitEvent = "QuitAfterSubmit"
		local submitElapsedRaw = typeof(playerState.submitElapsed) == "number"
			and playerState.submitElapsed or 0
		local startTime        = self.state.round.startTime
		local quitElapsedRaw   = startTime and (workspace:GetServerTimeNow() - startTime) or submitElapsedRaw
		local waitDurationRaw  = math.max(0, quitElapsedRaw - submitElapsedRaw)

		local maxElapsed    = Constants.ANALYTICS_MAX_ELAPSED
		local submitElapsed = math.clamp(math.floor(submitElapsedRaw), 0, maxElapsed)
		local quitElapsed   = math.clamp(math.floor(quitElapsedRaw),   0, maxElapsed)
		local waitDuration  = math.clamp(math.floor(waitDurationRaw),  0, maxElapsed)

		quitValue = waitDuration
		quitCustomFields = {
			waitDuration    = waitDuration,
			submitElapsed   = submitElapsed,
			quitElapsed     = quitElapsed,
			roundsCompleted = rounds,
		}
	elseif phase ~= "Waiting" then
		quitEvent = "QuitMidRound"
		local phaseStart   = self.state.round.phaseStartTime
		local rawElapsed   = phaseStart and (workspace:GetServerTimeNow() - phaseStart) or 0
		local phaseElapsed = math.clamp(math.floor(rawElapsed), 0, Constants.ANALYTICS_MAX_PHASE_ELAPSED)
		quitCustomFields = {
			phase           = phaseToSlug(phase),
			phaseElapsed    = phaseElapsed,
			roundsCompleted = rounds,
		}
	elseif rounds >= 1 then
		quitEvent = "QuitAfterRound"
	elseif peersRemaining == 0 then
		quitEvent = "QuitAlone"
		local enterTime = self.state.lobbyEnterTime[player]
		if enterTime then
			quitValue = math.max(1, math.ceil(workspace:GetServerTimeNow() - enterTime))
		else
			quitValue = 0
		end
	else
		quitEvent = "QuitFromLobby"
	end

	Analytics:LogRoundsPlayed(player, rounds, group)
	Analytics:LogQuit(player, quitEvent, quitValue, quitCustomFields, group)

	-- Session totals: gross Stars earned (read before PlayerDataService clears it on its own
	-- OnPlayerRemoving, which GameServer runs after this). Frame buyers also get a parallel
	-- RoundsPlayedBuyer on top of the everyone-counts RoundsPlayed above (the two compared
	-- give buyers vs non-buyers).
	Analytics:LogStarsEarned(player, PlayerDataService:GetSessionStarsEarned(player))
	if PlayerDataService:DidBuyFrameThisSession(player) then
		Analytics:LogRoundsPlayedBuyer(player, rounds, group)
	end

	-- Subject abandonment: the leaver is THIS round's subject and the subject is still live
	-- (currentSubject is held only through drawing/collecting and released at reveal), so this
	-- is a mid-round subject quit. Rate = Round:SubjectQuit / Round:Subject.
	local currentSubject = self.state.round.currentSubject
	if currentSubject and currentSubject.model == player then
		Analytics:LogSubjectQuit(player)
	end

	-- Drawing-quit research log: only players who left DURING drawing WITHOUT
	-- submitting (QuitMidRound on the drawing phase). QuitAfterSubmit players
	-- already dropped into a different branch above and are excluded by design.
	if quitEvent == "QuitMidRound" and phase == "DRAWING_PHASE" then
		local strokesDrawn = (playerState and playerState.strokesDrawn) or 0
		local undoCount    = (playerState and playerState.undoCount) or 0
		QuitLog.record({
			userId          = player.UserId,
			startedDrawing  = strokesDrawn > 0,
			strokesDrawn    = strokesDrawn,
			undoCount       = undoCount,
			lifetimeSession = (playerState and playerState.lifetimeSession) or -1,
			roundInSession  = rounds + 1,
			drawingElapsed  = (quitCustomFields and quitCustomFields.phaseElapsed) or 0,
		})
	end

	Analytics:ClearPlayer(player)
	self.state:RemovePlayer(player)
	SubjectService:OnPlayerRemoving(player)
	SessionService:ClearCache(player.UserId)

	-- The leaving player keeps any queued guarantee (persisted; consumed only when made
	-- subject). Re-push the remaining lobby's chances now that the pool changed.
	self:BroadcastSubjectChances()
end

--------------------------------------------------------------------------------
-- Waiting Phase
--------------------------------------------------------------------------------

function RoundManager:TryStartRound()
	if self.state.round.phase ~= "Waiting" then return end
	-- A player just readied up (or the lobby reset): refresh everyone's chance bar
	-- before the early-return below, so even a sub-MIN_PLAYERS lobby shows live odds.
	self:BroadcastSubjectChances()
	local readyList = self.state:GetReadyPlayers()
	if #readyList < Constants.MIN_PLAYERS then return end

	local serverTime = workspace:GetServerTimeNow()
	broadcastPhase(readyList, "WAITING_PHASE", serverTime, Constants.ROUND_START_DELAY)

	delayWithToken(self.state, Constants.ROUND_START_DELAY, function()
		self:StartDrawingPhase()
	end)
end

--------------------------------------------------------------------------------
-- Drawing Phase
--------------------------------------------------------------------------------

function RoundManager:StartDrawingPhase()
	if self.state.round.phase ~= "Waiting" then return end

	local playerList = self.state:GetReadyPlayers()
	if #playerList < Constants.MIN_PLAYERS then return end

	-- Subject guarantee: the queue head (if still in lobby) is forced as subject. Only
	-- consume the right when they actually became the subject — if their pick failed and
	-- PrepareSubject fell back to a weighted pick, the guarantee is untouched and rolls
	-- to the next round.
	local guaranteed = self:_resolveGuaranteedPlayer()
	local subject = SubjectService:PrepareSubject(playerList, guaranteed)
	if not subject then
		warn("[RoundManager] StartDrawingPhase: no suitable subject, retrying in", Constants.ROUND_START_DELAY, "s")
		delayWithToken(self.state, Constants.ROUND_START_DELAY, function()
			self:TryStartRound()
		end)
		return
	end

	if guaranteed and subject.model == guaranteed then
		self:_dequeueSubject(guaranteed.UserId)
		PlayerDataService:SetGuarantee(guaranteed, false)
	end

	self.state.round.phase          = "DRAWING_PHASE"
	self.state.round.currentSubject = subject
	self.state.round.currentPlayers = playerList

	-- Reset here, not in CleanRound: CleanRound still needs these to build the
	-- just-finished round's per-player galleries.
	self.roundReportsByUser = {}
	self.roundReportTotals  = {}

	-- Offset the drawing start by PASS_DURATION so the client's phase-transition
	-- screen is fully shown before the timer begins: clients receive DRAWING_PHASE
	-- now (PassGui appears), but startTime is in the future, so the countdown holds
	-- at DRAWING_DURATION until the screen clears. The phase delay below matches.
	local startTime                  = workspace:GetServerTimeNow() + Constants.PASS_DURATION
	self.state.round.startTime       = startTime
	self.state.round.phaseStartTime  = startTime

	local bannedPerSlot = buildBannedSlots(playerList, self.state.players)
	local themes        = ThemeService:PickThemes(#playerList, bannedPerSlot)

	for i, player in ipairs(playerList) do
		if not player.Parent then continue end
		local ps = self.state.players[player]
		if not ps then
			warn("[RoundManager] StartDrawingPhase: playerState not found -", player.Name)
			continue
		end
		ps.currentTheme = themes[i]
		self.state.lobbyEnterTime[player] = nil
		PhaseRemote:FireClient(player, "DRAWING_PHASE", ps.currentTheme, startTime, subject.model.Name, ps.group or "A")
		Analytics:LogPhase(player, "Drawing")
	end

	-- subject.model is the chosen Player (PrepareSubject contract). Logged once per round
	-- (each round has exactly one subject), so its count is the total-rounds denominator:
	-- subject-quit rate = SubjectQuit / Subject. Guarantee or weighted alike, only while
	-- the subject is still in the game.
	if subject.model.Parent then
		Analytics:LogSubject(subject.model)
	end

	delayWithToken(self.state, Constants.PASS_DURATION + Constants.DRAWING_DURATION, function()
		self:StartCollectingPhase()
	end)
end

--------------------------------------------------------------------------------
-- Collecting Phase
--------------------------------------------------------------------------------

-- Uses the live currentPlayers list (not a drawing-start snapshot) so players
-- who joined mid-round still have their drawing collected and revealed.
function RoundManager:StartCollectingPhase()
	if self.state.round.phase ~= "DRAWING_PHASE" then
		warn("[RoundManager] StartCollectingPhase: unexpected phase -", self.state.round.phase)
		return
	end

	local playerList = self.state.round.currentPlayers

	self.state.round.phase          = "COLLECTING_PHASE"
	self.state.round.phaseStartTime = workspace:GetServerTimeNow()
	broadcastPhase(playerList, "COLLECTING_PHASE")

	for _, player in ipairs(playerList) do
		if not player.Parent then continue end
		Analytics:LogPhase(player, "Collecting")
	end

	local myToken  = self.state.round.token
	local elapsed  = 0
	while elapsed < Constants.COLLECT_TIMEOUT do
		task.wait(0.5)
		elapsed += 0.5
		if not self.state:IsTokenValid(myToken) then return end
		if self.state.round.phase ~= "COLLECTING_PHASE" then return end
		if allSubmitted(playerList, self.state.players, self.state.round.spectators) then break end
	end

	if not self.state:IsTokenValid(myToken) then return end
	self:StartRevealPhase()
end

--------------------------------------------------------------------------------
-- Reveal Phase
--------------------------------------------------------------------------------

-- Uses the live currentPlayers list (not a drawing-start snapshot). This list no
-- longer changes once we leave DRAWING_PHASE (mid-join only adds during drawing),
-- so a single read here is stable for the whole reveal loop.
function RoundManager:StartRevealPhase()
	if self.state.round.phase ~= "COLLECTING_PHASE" then
		warn("[RoundManager] StartRevealPhase: unexpected phase -", self.state.round.phase)
		return
	end

	local playerList = self.state.round.currentPlayers

	self.state.round.phase          = "REVEAL_PHASE"
	self.state.round.phaseStartTime = workspace:GetServerTimeNow()

	local drawings = collectDrawings(playerList, self.state.players)
	if #drawings == 0 then
		warn("[RoundManager] StartRevealPhase: no drawings to show, cleaning up round")
	end

	local encodedDrawings = {}
	for _, drawing in ipairs(drawings) do
		local encoded = StrokeCodec.encode(drawing.data)
		table.insert(encodedDrawings, {
			playerName  = drawing.playerName,
			ownerUserId = drawing.ownerUserId,
			theme       = drawing.theme,
			buffer      = encoded,
		})

		-- First-timer capture: a first-session player completing their very first
		-- round with a non-empty drawing. sessionRounds is still 0 here (it is
		-- bumped later in CleanRound), so 0 means "this is the first round".
		for _, p in ipairs(playerList) do
			if p.Name == drawing.playerName then
				local ps = self.state.players[p]
				if ps and (sessionRounds[p] or 0) == 0 then
					-- The session count loads asynchronously on join. If it is
					-- still unknown by reveal time, re-read it once here: the
					-- DataStore call has almost certainly resolved into the cache
					-- during the drawing phase, so this recovers a first-timer
					-- that would otherwise be silently missed.
					if ps.lifetimeSession == -1 then
						ps.lifetimeSession = SessionService:GetSessionCount(p.UserId)
					end
					if ps.lifetimeSession == 1 then
						FirstDrawingService.persist(drawing.ownerUserId, drawing.theme, encoded)
					elseif ps.lifetimeSession == -1 then
						-- Still unknown even after the re-read (DataStore slow/
						-- failed). A genuine first-timer may be missed here.
						warn("[RoundManager] first-timer capture skipped: session count unknown for", p.Name)
					end
				end
				break
			end
		end
	end

	local gallery = {}
	for i = 1, math.min(#encodedDrawings, MAX_GALLERY_SLOTS) do
		gallery[i] = encodedDrawings[i]
	end
	self.lastRoundDrawings = gallery

	-- Per-drawing reaction tally for this round, filled as each drawing is revealed
	-- and sent to each owner in CleanRound. Reset here so a drawing with no reactions
	-- (or an owner who left) simply has no entry.
	self.roundEmojiResults = {}

	if typeof(Constants.POSITIVE_REACTIONS) ~= "table" then
		warn("[RoundManager] Constants.POSITIVE_REACTIONS missing; no reaction will count as positive this round")
	end

	local myToken = self.state.round.token
	if #encodedDrawings > 0 then
		self.state.round.phase          = "REVEAL_INTRO_PHASE"
		self.state.round.phaseStartTime = workspace:GetServerTimeNow()
		broadcastPhase(playerList, "REVEAL_INTRO_PHASE")
		-- Teleport after the broadcast so the client has already entered REVEAL_INTRO
		-- (and locked its camera to RevealCam) by the time the character moves; the
		-- player watches from the fixed reveal camera and never sees their own teleport.
		teleportToRevealSeats(playerList)
		for _, player in ipairs(playerList) do
			if not player.Parent then continue end
			-- Spectators produce zero analytics for the round they only watched.
			if self.state.round.spectators[player] then continue end
			Analytics:LogPhase(player, "RevealIntro")
		end
		-- Release after broadcast so client camera is already free when player teleports
		SubjectService:ReleaseSubject(self.state.round.currentSubject)
		self.state.round.currentSubject = nil
		-- Hold the intro at least until the phase-transition screen (PassGui, shown on
		-- this REVEAL_INTRO broadcast for PASS_DURATION) has cleared, so the first
		-- drawing is never revealed underneath it.
		task.wait(math.max(Constants.REVEAL_INTRO_DURATION, Constants.PASS_DURATION))

		self.state.round.phase          = "REVEAL_PHASE"
		self.state.round.phaseStartTime = workspace:GetServerTimeNow()
		for _, player in ipairs(playerList) do
			if not player.Parent then continue end
			if self.state.round.spectators[player] then continue end
			Analytics:LogPhase(player, "Reveal")
		end
	else
		SubjectService:ReleaseSubject(self.state.round.currentSubject)
		self.state.round.currentSubject = nil
	end

	for _, drawing in ipairs(encodedDrawings) do
		if not self.state:IsTokenValid(myToken) then return end
		if self.state.round.phase ~= "REVEAL_PHASE" then
			warn("[RoundManager] StartRevealPhase: phase changed mid-reveal, stopping")
			return
		end

		local owner = nil
		for _, p in ipairs(playerList) do
			if p.Name == drawing.playerName then owner = p break end
		end
		self.state.round.currentDrawingOwner = owner
		for _, p in ipairs(playerList) do
			local ps = self.state.players[p]
			if ps then ps.currentVote = nil end
		end

		-- Reset per-drawing report state
		self.reportCounts[drawing.playerName] = {}
		-- ownerUserId is captured at collect time (see collectDrawings), so it
		-- stays valid for the ban path even if the owner has since left.
		-- reportId is stamped once here so every report on this drawing upserts a
		-- single panel row. token+os.time() keeps it unique across rounds/restarts.
		self.currentDrawingMeta = {
			ownerName   = drawing.playerName,
			ownerUserId = drawing.ownerUserId or 0,
			theme       = drawing.theme,
			buffer      = drawing.buffer,
			reportId    = "report_" .. self.state.round.token .. "_" .. os.time() .. "_" .. (drawing.ownerUserId or 0),
		}

		broadcastPhase(playerList, "REVEAL_PHASE", drawing.playerName, drawing.theme, drawing.buffer)
		task.wait(Constants.REVEAL_DRAWING_VIEW_DURATION)

		-- Tally this drawing's reactions by emoji type (each reactor's LAST emoji
		-- counts once, same spam-proof rule as the reward). Stored per owner name so
		-- it survives the owner leaving before CleanRound; it is the ResultGui source.
		local tally = {}
		local positiveReactions = 0
		for _, p in ipairs(playerList) do
			local ps = self.state.players[p]
			if ps and p ~= owner and ps.currentVote
				and Constants.POSITIVE_REACTIONS and Constants.POSITIVE_REACTIONS[ps.currentVote] then
				tally[ps.currentVote] = (tally[ps.currentVote] or 0) + 1
				positiveReactions += 1
			end
		end

		-- ResultGui payload: per-type counts plus the Star breakdown shown on the
		-- StarContainer screen (base for finishing the round, bonus for reactions).
		-- Guarded: a missing reward constant would otherwise nil-error the arithmetic.
		local rewardBase    = Constants.ROUND_REWARD_BASE
		local rewardPerReact = Constants.ROUND_REWARD_PER_REACTION
		if typeof(rewardBase) ~= "number" or typeof(rewardPerReact) ~= "number" then
			warn("[RoundManager] reveal reward: ROUND_REWARD_BASE/PER_REACTION missing or non-number; defaulting to 0")
			rewardBase    = rewardBase or 0
			rewardPerReact = rewardPerReact or 0
		end
		local emojiStars = positiveReactions * rewardPerReact
		self.roundEmojiResults[drawing.playerName] = {
			tally       = tally,
			emojiStars  = emojiStars,
			roundStars  = rewardBase,
		}

		-- Per-round Star reward, paid to the drawing's owner now that their drawing
		-- has been revealed. Only paid to owners still present (an absent owner cannot
		-- receive Stars), but the tally above is kept regardless for CleanRound.
		if owner and owner.Parent then
			PlayerDataService:AddStars(owner, rewardBase + emojiStars)
		end
	end

	if not self.state:IsTokenValid(myToken) then return end
	if self.state.round.phase ~= "REVEAL_PHASE" then return end

	for _, player in ipairs(playerList) do
		if player.Parent then
			ClearDisplayRemote:FireClient(player)
		end
	end
	-- Gallery teleport happens inside CleanRound, after the CLEAN broadcast, so it
	-- lands behind the "Lobby" transition screen instead of yanking the player to
	-- their gallery spot before the screen has covered it.
	self:CleanRound()
end

--------------------------------------------------------------------------------
-- Round Cleanup
--------------------------------------------------------------------------------

-- Reads currentPlayers before NewRound() clears it, so mid-join players are also
-- reset and logged as having completed the round.
function RoundManager:CleanRound()
	if self.state.round.phase == "Waiting" then return end

	local playerList = self.state.round.currentPlayers

	self.state.round.phase          = "CLEAN_ROUND_PHASE"
	self.state.round.phaseStartTime = workspace:GetServerTimeNow()

	self.reportCounts       = {}
	self.currentDrawingMeta = nil

	resetPlayerStates(playerList, self.state.players)

	-- Players eligible to see the one-step tutorial this round: a non-spectator finishing
	-- their FIRST round this session who has never been shown it. Marked seen now (on the
	-- decision to show, not on the client dismiss) so a disconnect mid-tutorial never
	-- re-shows it. The actual fire is deferred to the result thread below so it lands after
	-- the gallery teleport + Lobby fade; this set is captured by that closure.
	local tutorialEligible = {}
	local now = workspace:GetServerTimeNow()
	for _, player in ipairs(playerList) do
		if not player.Parent then continue end

		-- Spectators only watched this round: no round-completion analytics, no
		-- session-round bump, no result screen. The reveal/teleport/gallery/lobby-reset
		-- below still apply to them (they were in the scene).
		if not self.state.round.spectators[player] then
			-- "First round this session" is the 0->1 transition, so read before the bump.
			local firstRoundThisSession = (sessionRounds[player] or 0) == 0
			Analytics:LogPhase(player, "RoundComplete")
			sessionRounds[player] = (sessionRounds[player] or 0) + 1

			if Constants.TUTORIAL_ENABLED
				and firstRoundThisSession
				and not PlayerDataService:GetSeenTutorial(player)
			then
				PlayerDataService:SetSeenTutorial(player)
				tutorialEligible[player] = true
			end
		end

		if self.state.readyPlayers[player] then
			self.state.lobbyEnterTime[player] = now
		end
	end

	broadcastPhase(playerList, "CLEAN_ROUND_PHASE")

	-- Result screen ("you got"): sent after the CLEAN broadcast and delayed until the
	-- client's "Lobby" transition screen has fully faded out (PASS_DURATION + the
	-- fade), so the result's own sequence plays in full view instead of starting
	-- hidden behind the screen. Doing the timing server-side keeps the client from
	-- juggling the two messages' arrival order. Only players whose drawing was revealed
	-- have an entry; others get nothing, so their ResultGui never opens. Both the
	-- results map and the spectator set are captured here, not read in the delayed
	-- thread: NewRound (below) overwrites roundEmojiResults and clears spectators, so
	-- reading them later would send stale/incorrect results. Self-cancels if a new round
	-- has already reached drawing, so a late result can never drop onto the next round's
	-- screen. NewRound bumps the token, so this cannot use delayWithToken.
	local resultsByName  = self.roundEmojiResults
	local spectatorsSnap = self.state.round.spectators
	task.delay(Constants.PASS_DURATION + Constants.PASS_FADE_DURATION, function()
		if self.state.round.phase == "DRAWING_PHASE" then return end
		for _, player in ipairs(playerList) do
			if player.Parent and not spectatorsSnap[player] then
				local result = resultsByName[player.Name]
				if result then
					ResultRemote:FireClient(player, result)
				end
				-- Tutorial: fired on the same delayed thread so it lands once the player is in
				-- the gallery and the Lobby fade is done. Goes to every eligible player whether
				-- or not they got a result above; the client decides the open moment (after the
				-- "You Got" fade-out, or after a short grace delay when there was no result).
				if tutorialEligible[player] then
					TutorialRemote:FireClient(player)
				end
			end
		end
	end)

	-- Teleport to the gallery spots PASS_SETUP_DELAY after the CLEAN broadcast, so the
	-- client's "Lobby" transition screen is covering the view when the player is moved
	-- (matches the client setup delay; without it the player visibly jumps under the
	-- screen's fade-in). NewRound below bumps the round token, so this cannot use
	-- delayWithToken; instead it self-cancels if a new round has already reached the
	-- drawing phase (otherwise the lobby/gallery placement is still correct). The lobby
	-- start delay (ROUND_START_DELAY) is far longer than PASS_SETUP_DELAY, so the move
	-- always lands while players are still in the lobby.
	task.delay(Constants.PASS_SETUP_DELAY, function()
		if self.state.round.phase == "DRAWING_PHASE" then return end
		teleportToGallerySpots(playerList)
	end)

	for _, player in ipairs(playerList) do
		if player.Parent then
			GalleryRemote:FireClient(player, self:buildGalleryForPlayer(player))
		end
	end

	self.state:NewRound()
	self:TryStartRound()
end

--------------------------------------------------------------------------------
-- Drawing Submission
--------------------------------------------------------------------------------

function RoundManager:OnDrawingSubmitted(player, _strokes, _rejected, truncated)
	if truncated then
		Analytics:LogError(player, "warning", "StrokeValidator: truncated buffer")
	end
end

-- Called the moment a player presses Submit during the drawing phase (SubmitRemote), before
-- the collect phase gathers their canvas. Moves them onto the waiting pad so they leave the
-- drawing area while everyone else keeps drawing.
function RoundManager:OnSubmitButtonPressed(player)
	teleportToSubmitPart(player)
end

--------------------------------------------------------------------------------
-- Emoji
--------------------------------------------------------------------------------

function RoundManager:OnEmojiReceived(player, emojiName)
	-- A drawing whose owner has left has currentDrawingOwner == nil; reactions to it
	-- still count for react3 and still tally (only the owner's own Star reward is
	-- skipped, since there is no one to pay). The only exclusion is reacting to your
	-- OWN drawing, so compare by the drawing's owner NAME, not the (possibly nil)
	-- owner instance.
	local owner     = self.state.round.currentDrawingOwner
	local isOwnDrawing = owner ~= nil and player == owner
	if not isOwnDrawing then
		local ps = self.state.players[player]
		if ps then
			-- currentVote is this player's last emoji on the CURRENT drawing; it is
			-- nil'd at the start of each reveal (StartRevealPhase). Re-reacting to the
			-- same drawing only overwrites it, so each reacting player's last emoji
			-- counts once toward the drawing's reaction tally / owner reward.
			ps.currentVote = emojiName
		end
	end

	for p in pairs(self.state.players) do
		if p.Parent then
			EmojiRemote:FireClient(p, emojiName)
		end
	end
end

--------------------------------------------------------------------------------
-- Report
--------------------------------------------------------------------------------

function RoundManager:OnReportReceived(reporter)
	if self.state.round.phase ~= "REVEAL_PHASE" then return end
	local meta = self.currentDrawingMeta
	if not meta then return end

	-- A player cannot report the drawing they own
	if reporter.Name == meta.ownerName then return end

	local reporterSet = self.reportCounts[meta.ownerName]
	if not reporterSet then return end

	-- Each player can only report once per drawing
	if reporterSet[reporter.UserId] then return end
	reporterSet[reporter.UserId] = true

	local count = 0
	for _ in pairs(reporterSet) do count += 1 end

	local userSet = self.roundReportsByUser[reporter.UserId]
	if not userSet then
		userSet = {}
		self.roundReportsByUser[reporter.UserId] = userSet
	end
	userSet[meta.ownerName] = true
	-- Each drawing is revealed exactly once, so the last count written here is its
	-- final distinct-reporter total (no more reports land on this owner afterwards).
	self.roundReportTotals[meta.ownerName] = count

	ModerationService.logReportAudit(reporter.UserId, meta.ownerUserId, meta.theme, meta.buffer)

	-- Every valid report shows up in the admin panel (one row per drawing, count
	-- bumped). Invalid ownerUserId still appears so an admin can Dismiss it; Ban is
	-- rejected later by BanService.
	ModerationService.upsertReport(meta.reportId, meta.ownerUserId, meta.theme, meta.buffer, count)

	if count >= ModerationService.getThreshold() then
		-- Hide for everyone (always — moderation must take effect even if the
		-- owner's UserId was somehow lost).
		for _, p in ipairs(self.state.round.currentPlayers) do
			if p.Parent then
				HideDrawingRemote:FireClient(p)
			end
		end
		ModerationService.logThresholdReached(meta.ownerUserId, meta.theme, count)
	end
end

--------------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------------

RoundRemotes.connect(RoundManager)
return RoundManager
