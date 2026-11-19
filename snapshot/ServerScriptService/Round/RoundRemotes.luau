local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants         = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local StrokeValidator   = require(script.Parent.Parent:WaitForChild("StrokeValidator"))
local ThemeService      = require(script.Parent.Parent:WaitForChild("ThemeService"))
local Analytics         = require(script.Parent.Parent:WaitForChild("AnalyticsService"))

--------------------------------------------------------------------------------
-- Remotes
--------------------------------------------------------------------------------

local Remotes             = ReplicatedStorage:WaitForChild("Remotes")
local PhaseRemote         = Remotes:WaitForChild("PhaseRemote")
local CanvasRemote        = Remotes:WaitForChild("CanvasRemote")
local EmojiRemote         = Remotes:WaitForChild("EmojiRemote")
local ReadyRemote         = Remotes:WaitForChild("ReadyRemote")
local ReportRemote        = Remotes:WaitForChild("ReportRemote")
local SubmitRemote        = Remotes:WaitForChild("SubmitRemote")
local DrawProgressRemote  = Remotes:WaitForChild("DrawProgressRemote")
local SubjectChanceRemote = Remotes:WaitForChild("SubjectChanceRemote")

-- Upper bounds for client-reported progress counts. These are analytics-only
-- values (no gameplay/economy impact), so we just clamp obviously bogus inputs
-- rather than fully validating them.
local MAX_REPORTED_COUNT = Constants.MAX_STROKES * 4

local RoundRemotes = {}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function getRemainingTime(state)
	local elapsed = workspace:GetServerTimeNow() - state.round.startTime
	return Constants.DRAWING_DURATION - elapsed
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

function RoundRemotes.connect(manager)
	local state = manager.state

	-- Tries to admit a player who readied up while a round is already running.
	-- Returns true if the player was given a live phase (joined the drawing), false
	-- if they cannot join this round (too little time left, wrong phase, already in).
	local function tryMidJoinDrawing(player)
		if state.round.phase ~= "DRAWING_PHASE" or not state.round.startTime then
			return false
		end
		if getRemainingTime(state) <= Constants.MID_JOIN_MIN_SECONDS then
			return false
		end
		for _, p in ipairs(state.round.currentPlayers) do
			if p == player then return false end
		end

		local playerState = state.players[player]
		if not playerState then return false end

		local theme = ThemeService:PickThemes(1, { [1] = playerState.bannedThemes })[1]
		playerState.currentTheme = theme
		table.insert(state.round.currentPlayers, player)
		local subjectName = state.round.currentSubject and state.round.currentSubject.model.Name or ""
		local group       = playerState.group or "A"
		PhaseRemote:FireClient(player, "DRAWING_PHASE", theme, state.round.startTime, subjectName, group)
		return true
	end

	-- Admits a player who readied up too late to draw (mid-join refused) as a
	-- SPECTATOR of the current round: they are added to currentPlayers so the reveal
	-- broadcast/teleport/emoji reach them, but flagged in round.spectators so the
	-- manager skips all their analytics/round-completion. Only joinable
	-- before the reveal starts (drawing or collecting); once reveal begins a newcomer
	-- waits for the next round instead. Returns true if admitted.
	--
	-- Spectator system: a mid-round joiner who can't draw is admitted as a spectator
	-- (watches/reacts, skipped for analytics/round-completion). When false the
	-- guard below short-circuits and they fall through to the plain WAITING_PHASE in
	-- ReadyRemote instead.
	local SPECTATOR_ENABLED = true
	local function trySpectate(player)
		if not SPECTATOR_ENABLED then return false end
		local phase = state.round.phase
		if phase ~= "DRAWING_PHASE" and phase ~= "COLLECTING_PHASE" then
			return false
		end
		if not state.players[player] then return false end
		for _, p in ipairs(state.round.currentPlayers) do
			if p == player then return false end
		end

		table.insert(state.round.currentPlayers, player)
		state.round.spectators[player] = true
		-- No drawing phase for a spectator: they get the passive waiting screen until
		-- the reveal broadcast, which reaches them because they are in currentPlayers.
		PhaseRemote:FireClient(player, "WAITING_PHASE")
		return true
	end

	ReadyRemote.OnServerEvent:Connect(function(player)
		if state.readyPlayers[player] then return end
		state.readyPlayers[player] = true

		if state.round.phase == "Waiting" then
			state.lobbyEnterTime[player] = workspace:GetServerTimeNow()
			manager:TryStartRound()
			return
		end

		-- A round is already running. Admit the player to the drawing phase if it is
		-- still joinable; if it is too late to draw but the reveal has not started yet,
		-- admit them as a spectator so they can watch and react. Otherwise put them in
		-- an explicit waiting state so their UI matches reality (a mid-round joiner who
		-- can't participate). Without this the client stays on the boot-time "Waiting
		-- for players" screen while the live scene (subject clone, reveal) plays around them.
		if not tryMidJoinDrawing(player) and not trySpectate(player) then
			state.lobbyEnterTime[player] = workspace:GetServerTimeNow()
			PhaseRemote:FireClient(player, "WAITING_PHASE")
		end
	end)

	-- Client requests its current subject chance once its listener is connected, since
	-- the join-time push may have fired during the loading screen (same race-fix as
	-- StarRemote). Re-broadcasting to the whole lobby is cheap (one-shot
	-- on boot) and keeps the guarantee-override logic in one place (BroadcastSubjectChances).
	SubjectChanceRemote.OnServerEvent:Connect(function()
		manager:BroadcastSubjectChances()
	end)

	EmojiRemote.OnServerEvent:Connect(function(player, emojiName)
		if state.round.phase ~= "REVEAL_PHASE"      then return end
		if not state.players[player]                 then return end
		if typeof(emojiName) ~= "string"             then return end
		if not Constants.VALID_EMOJIS[emojiName]     then return end

		local playerState = state.players[player]
		local now         = tick()
		if (now - playerState.lastEmojiTime) < Constants.EMOJI_COOLDOWN then return end
		playerState.lastEmojiTime = now

		manager:OnEmojiReceived(player, emojiName)
	end)

	ReportRemote.OnServerEvent:Connect(function(player)
		if not state.players[player] then return end
		manager:OnReportReceived(player)
	end)

	SubmitRemote.OnServerEvent:Connect(function(player)
		if state.round.phase ~= "DRAWING_PHASE" then return end
		local playerState = state.players[player]
		if not playerState then return end
		if playerState.submittedDuringDrawing then return end
		if not state.round.startTime then return end

		local elapsed = workspace:GetServerTimeNow() - state.round.startTime
		if elapsed < 0 then elapsed = 0 end
		if elapsed < Constants.SUBMIT_BUTTON_DELAY then return end

		playerState.submittedDuringDrawing = true
		playerState.submitElapsed          = elapsed

		Analytics:LogSubmitTime(player, elapsed)
		manager:OnSubmitButtonPressed(player)
	end)

	-- Client reports its live stroke/undo counts during drawing so that a
	-- player who quits mid-drawing (without submitting) still has this data on
	-- the server. Monotonic: only accept non-decreasing values so a stale/late
	-- packet can't lower the recorded progress.
	DrawProgressRemote.OnServerEvent:Connect(function(player, strokesDrawn, undoCount)
		if state.round.phase ~= "DRAWING_PHASE" then return end
		local playerState = state.players[player]
		if not playerState then return end
		if typeof(strokesDrawn) ~= "number" or typeof(undoCount) ~= "number" then return end

		local s = math.clamp(math.floor(strokesDrawn), 0, MAX_REPORTED_COUNT)
		local u = math.clamp(math.floor(undoCount),    0, MAX_REPORTED_COUNT)
		if s > playerState.strokesDrawn then playerState.strokesDrawn = s end
		if u > playerState.undoCount    then playerState.undoCount    = u end
	end)

	CanvasRemote.OnServerEvent:Connect(function(player, data)
		if state.round.phase ~= "COLLECTING_PHASE" then return end

		local playerState = state.players[player]
		if not playerState then
			warn("[RoundRemotes] CanvasRemote: playerState not found -", player.Name)
			return
		end
		if playerState.drawingData then return end
		if typeof(data) ~= "buffer" then
			warn("[RoundRemotes] CanvasRemote: expected buffer, got invalid data -", player.Name)
			return
		end

		local validated, rejected, truncated = StrokeValidator.validate(player, data)
		if validated then
			playerState.drawingData = validated
			manager:OnDrawingSubmitted(player, validated, rejected, truncated)
		end
	end)
end

return RoundRemotes
