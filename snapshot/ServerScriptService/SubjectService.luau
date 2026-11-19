--[[
SubjectService
--------------
Subject (cizilen oyuncu) yasam dongusu:
  - Drawing basinda secilen oyuncunun klonu sahnede SubjectPart'a konur.
  - Gercek oyuncuya hicbir sey yapilmaz; serbest hareket eder.
  - Reveal basinda klon yok edilir.
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))

local SubjectService = {}

--------------------------------------------------------------------------------
-- Tunables
--------------------------------------------------------------------------------

local MAP_TIMEOUT            = Constants.MAP_TIMEOUT
local CHARACTER_WAIT_TIMEOUT = Constants.CHARACTER_WAIT_TIMEOUT

-- Roblox default idle assets (Animate script uses these too).
-- Idle1 calm pose held continuously; Idle2 layered on top with pulsing weight
-- (mirrors what default Animate LocalScript does, but server-driven so it
-- runs on a clone that lives outside Players hierarchy).
local R15_IDLE_ANIMATIONS = {
	primary   = "rbxassetid://507766388",
	secondary = "rbxassetid://507766666",
}
local R6_IDLE_ANIMATIONS = {
	primary   = "rbxassetid://180435571",
	secondary = "rbxassetid://180435792",
}

local IDLE_FADE_TIME         = 0.4
local IDLE_PULSE_MIN_WAIT    = 6
local IDLE_PULSE_MAX_WAIT    = 12
local IDLE_PULSE_PEAK_WEIGHT = 1
local IDLE_PULSE_BASE_WEIGHT = 0

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

SubjectService.roundCounter = {}
SubjectService.lastModel    = nil

local mapRefs = {
	subjectPart = nil,
	cloneFolder = nil,
	releasePart = nil,
}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function resolveMapParts()
	local map      = workspace:WaitForChild("Map", MAP_TIMEOUT)
	local gamePlay = map and map:WaitForChild("GamePlay", MAP_TIMEOUT)
	if not gamePlay then
		warn("[SubjectService] Map/GamePlay not found - subject phase will not work")
		return
	end

	mapRefs.subjectPart = gamePlay:FindFirstChild("SubjectPart")
	mapRefs.releasePart = gamePlay:FindFirstChild("SubjectReleasePart")
	mapRefs.cloneFolder = gamePlay:FindFirstChild("SubjectClone")

	if not mapRefs.subjectPart then warn("[SubjectService] Map/GamePlay/SubjectPart missing")         end
	if not mapRefs.releasePart then warn("[SubjectService] Map/GamePlay/SubjectReleasePart missing")  end
	if not mapRefs.cloneFolder then warn("[SubjectService] Map/GamePlay/SubjectClone folder missing") end
end

local function getCharacterParts(character)
	if not character then return nil, nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	return humanoid, rootPart
end

local function ensureCharacter(player, timeout)
	local character = player.Character
	if not character then
		local conn
		local thread = coroutine.running()
		local fired  = false
		conn = player.CharacterAdded:Connect(function(c)
			if fired then return end
			fired = true
			conn:Disconnect()
			character = c
			task.spawn(thread)
		end)
		task.delay(timeout, function()
			if fired then return end
			fired = true
			conn:Disconnect()
			task.spawn(thread)
		end)
		coroutine.yield()
	end

	if not character then return nil, nil, nil end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
		or character:WaitForChild("Humanoid", timeout)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
		or character:WaitForChild("HumanoidRootPart", timeout)

	return character, humanoid, rootPart
end

local function loadTrack(animator, assetId)
	if not assetId or assetId == "" or assetId == "rbxassetid://0" then return nil end
	local anim = Instance.new("Animation")
	anim.AnimationId = assetId
	local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
	anim:Destroy()
	if not ok or not track then return nil end
	return track
end

-- The facial expression (e.g. a smile) is a "mood" animation that loops on an
-- animatable head; the default Animate script normally drives it. We destroy the
-- clone's Animate script (it cannot run reliably outside the Players hierarchy), so
-- the mood id has to be read off it BEFORE deletion and replayed by us. The Animate
-- script holds it under mood.Animation*; HumanoidDescription.IdleAnimation is the
-- fallback. Returns the asset id string, or nil when the head isn't animatable.
local function readMoodAnimationId(clone, humanoid)
	local animate = clone:FindFirstChild("Animate")
	local mood = animate and animate:FindFirstChild("mood")
	if mood then
		local moodAnim = mood:FindFirstChildOfClass("Animation")
		if moodAnim and moodAnim.AnimationId ~= "" then
			return moodAnim.AnimationId
		end
	end

	local ok, description = pcall(function() return humanoid:GetAppliedDescription() end)
	if ok and description and description.IdleAnimation and description.IdleAnimation ~= 0 then
		return "rbxassetid://" .. tostring(description.IdleAnimation)
	end

	return nil
end

local function playIdleLoop(clone)
	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	-- Read the mood (facial) animation before the Animate script is destroyed.
	local moodId = readMoodAnimationId(clone, humanoid)

	local cloneAnimate = clone:FindFirstChild("Animate")
	if cloneAnimate then cloneAnimate:Destroy() end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	-- Facial mood plays on its own track at full weight; it only touches FaceControls
	-- (the head), so it layers freely over the body idle without conflicting.
	local mood = loadTrack(animator, moodId)
	if mood then
		mood.Looped   = true
		mood.Priority = Enum.AnimationPriority.Idle
		mood:Play(IDLE_FADE_TIME, 1, 1)
	end

	local pool      = humanoid.RigType == Enum.HumanoidRigType.R6 and R6_IDLE_ANIMATIONS or R15_IDLE_ANIMATIONS
	local primary   = loadTrack(animator, pool.primary)
	local secondary = loadTrack(animator, pool.secondary)
	if not primary then return end

	primary.Looped   = true
	primary.Priority = Enum.AnimationPriority.Idle
	primary:Play(IDLE_FADE_TIME, 1, 1)

	if secondary then
		secondary.Looped   = true
		secondary.Priority = Enum.AnimationPriority.Idle
		secondary:Play(IDLE_FADE_TIME, IDLE_PULSE_BASE_WEIGHT, 1)

		task.spawn(function()
			while clone.Parent do
				task.wait(math.random(IDLE_PULSE_MIN_WAIT, IDLE_PULSE_MAX_WAIT))
				if not clone.Parent then return end
				secondary:AdjustWeight(IDLE_PULSE_PEAK_WEIGHT, IDLE_FADE_TIME)
				task.wait(secondary.Length > 0 and secondary.Length or 3)
				if not clone.Parent then return end
				secondary:AdjustWeight(IDLE_PULSE_BASE_WEIGHT, IDLE_FADE_TIME)
			end
		end)
	end
end

local function lockCloneHumanoid(clone)
	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.AutoRotate = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping,          false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated,           false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming,         false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing,         false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown,      false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,          false)
	humanoid:ChangeState(Enum.HumanoidStateType.Running)

	local rootPart = clone:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		pcall(function() rootPart:SetNetworkOwner(nil) end)
	end
end

local function buildClone(character, cframe, parent)
	if not parent then return nil end
	if not character or not character.Parent then return nil end

	local wasArchivable = character.Archivable
	character.Archivable = true
	local clone = character:Clone()
	character.Archivable = wasArchivable
	if not clone then return nil end

	clone:SetAttribute("IsSubjectClone", true)
	clone:PivotTo(cframe)
	clone.Parent = parent

	lockCloneHumanoid(clone)
	playIdleLoop(clone)

	return clone
end

local function weightedRandom(candidates, roundCounter)
	local totalWeight = 0
	local weights     = {}

	for i, player in ipairs(candidates) do
		local w      = (roundCounter[player] or 0) + 1
		weights[i]   = w
		totalWeight += w
	end

	local roll  = math.random() * totalWeight
	local total = 0

	for i, player in ipairs(candidates) do
		total += weights[i]
		if roll <= total then
			return i, player
		end
	end

	return #candidates, candidates[#candidates]
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

function SubjectService:Init()
	resolveMapParts()
end

-- Per-player probability of being picked as subject THIS round under the weighted
-- system, for the lobby chance bar. Mirrors weightedRandom + PrepareSubject candidate
-- rules exactly so the bar shows the real odds, not a flat 1/N: weight is the same
-- (roundCounter+1), and lastModel (last round's subject) is excluded from the pool
-- (its real chance is 0), so the total is taken over candidates only. Does NOT know
-- about the guarantee queue — RoundManager applies the queue-head 100%/0% override on
-- top of this. Returns [player] = ratio in [0,1]; sums to 1 across candidates.
function SubjectService:ComputeChances(readyPlayers)
	local chances = {}
	local totalWeight = 0

	for _, player in ipairs(readyPlayers) do
		if player ~= self.lastModel then
			totalWeight += (self.roundCounter[player] or 0) + 1
		end
	end

	for _, player in ipairs(readyPlayers) do
		if player == self.lastModel or totalWeight <= 0 then
			chances[player] = 0
		else
			chances[player] = ((self.roundCounter[player] or 0) + 1) / totalWeight
		end
	end

	return chances
end

function SubjectService:OnPlayerAdded(player)
	self.roundCounter[player] = 0
end

function SubjectService:OnPlayerRemoving(player)
	self.roundCounter[player] = nil
	if self.lastModel == player then
		self.lastModel = nil
	end
end

-- Builds the subject clone for a chosen model and commits the selection state
-- (roundCounter reset + lastModel). Returns the subject table or nil if the clone
-- build failed. Shared by the guarantee path and the weighted path so both commit
-- selection identically.
function SubjectService:_makeSubject(model)
	local character, humanoid, rootPart = ensureCharacter(model, CHARACTER_WAIT_TIMEOUT)
	if not (character and humanoid and rootPart and humanoid.Health > 0) then
		warn("[SubjectService]", model.Name, "not ready, skipping")
		return nil
	end

	local clone = buildClone(character, mapRefs.subjectPart.CFrame, mapRefs.cloneFolder)
	if not clone then
		warn("[SubjectService]", model.Name, "clone build failed, skipping")
		return nil
	end

	self.roundCounter[model] = 0
	self.lastModel           = model
	return { model = model, clone = clone }
end

-- Doner: { model = Player, clone = Model } veya nil
-- guaranteedPlayer (optional): a player who bought the subject guarantee and is first
-- in RoundManager's queue. When set and still present, they become the subject and the
-- weighted draw is skipped — the guarantee overrides everything, including the
-- lastModel back-to-back block. The caller (RoundManager) consumes the queue/right.
function SubjectService:PrepareSubject(playerList, guaranteedPlayer)
	if not (mapRefs.subjectPart and mapRefs.cloneFolder) then
		warn("[SubjectService] PrepareSubject: required map parts missing, aborting")
		return nil
	end

	for _, player in ipairs(playerList) do
		self.roundCounter[player] = (self.roundCounter[player] or 0) + 1
	end

	if guaranteedPlayer and guaranteedPlayer.Parent then
		local subject = self:_makeSubject(guaranteedPlayer)
		if subject then return subject end
		-- Clone build failed: fall through to the normal weighted pick so the round still
		-- gets a subject. The caller only consumes the guarantee when the returned subject
		-- IS the guaranteed player, so a failure here leaves the right intact for next round.
	end

	local candidates = {}
	for _, player in ipairs(playerList) do
		if player ~= self.lastModel and player.Parent then
			table.insert(candidates, player)
		end
	end

	while #candidates > 0 do
		local index, model = weightedRandom(candidates, self.roundCounter)
		local subject = self:_makeSubject(model)
		if subject then return subject end
		table.remove(candidates, index)
	end

	warn("[SubjectService] No suitable subject found among", #playerList, "players")
	return nil
end

function SubjectService:ReleaseSubject(subject)
	if not subject then return end

	if subject.clone and subject.clone.Parent then
		subject.clone:Destroy()
	end
end

--------------------------------------------------------------------------------

return SubjectService
