--[[
AnalyticsService
----------------
Thin wrapper around the GameAnalytics Roblox SDK. Keeps a stable public
API so callers (Round/init.luau, GameServer) don't depend on the SDK
directly.

Secrets are loaded from ServerStorage.Secrets (a ModuleScript created
manually in Studio, never committed; Rojo does not manage ServerStorage
so it is safe from sync deletions). If Secrets is missing or malformed,
the SDK is not initialized and all logging calls become no-ops.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))

local AnalyticsService = {}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local initialized = false
local GameAnalytics

local function tryLoadSecrets()
	local secretsModule = ServerStorage:FindFirstChild("Secrets")
	if not secretsModule or not secretsModule:IsA("ModuleScript") then
		warn("[AnalyticsService] Secrets ModuleScript not found in ServerStorage; analytics disabled")
		return nil
	end

	local ok, secrets = pcall(require, secretsModule)
	if not ok or typeof(secrets) ~= "table" then
		warn("[AnalyticsService] Secrets require failed; analytics disabled")
		return nil
	end

	if typeof(secrets.GAME_KEY) ~= "string" or typeof(secrets.SECRET_KEY) ~= "string" then
		warn("[AnalyticsService] Secrets missing GAME_KEY or SECRET_KEY; analytics disabled")
		return nil
	end

	return secrets
end

local function tryLoadSdk()
	local packages = ReplicatedStorage:FindFirstChild("Packages")
	if not packages then
		warn("[AnalyticsService] ReplicatedStorage.Packages not found; analytics disabled")
		return nil
	end

	local sdkModule = packages:FindFirstChild("GameAnalytics")
	if not sdkModule then
		warn("[AnalyticsService] Packages.GameAnalytics not found; analytics disabled")
		return nil
	end

	local ok, sdk = pcall(require, sdkModule)
	if not ok then
		warn("[AnalyticsService] GameAnalytics require failed:", sdk)
		return nil
	end
	return sdk
end

local BIN_WIDTH = 5  -- analytics time buckets are 5-second wide

local function elapsedToBin(elapsed, capStart)
	if elapsed >= capStart then
		return string.format("Sec%dPlus", capStart)
	end
	local lower = math.floor(elapsed / BIN_WIDTH) * BIN_WIDTH
	local upper = lower + (BIN_WIDTH - 1)
	return string.format("Sec%d-%d", lower, upper)
end

local function safeDesignEvent(player, eventId, value, customFields)
	if not initialized then return end
	local payload = { eventId = eventId }
	if typeof(value) == "number" then
		payload.value = value
	end
	if typeof(customFields) == "table" then
		payload.customFields = customFields
	end
	local ok, err = pcall(function()
		GameAnalytics:addDesignEvent(player.UserId, payload)
	end)
	if not ok then
		warn("[AnalyticsService] addDesignEvent failed:", eventId, "-", err)
	end
end

local function safeErrorEvent(userId, severity, message)
	if not initialized then return end
	if typeof(userId) ~= "number" or userId <= 0 then return end
	if typeof(message) ~= "string" or #message == 0 then return end
	local ok, err = pcall(function()
		GameAnalytics:addErrorEvent(userId, {
			severity = severity,
			message  = message,
		})
	end)
	if not ok then
		warn("[AnalyticsService] addErrorEvent failed:", message, "-", err)
	end
end

-- Resolves a severity name ("warning"/"error"/...) to the SDK enum, or nil if
-- the SDK is not loaded / the name is unknown.
local function resolveSeverity(severity)
	if not GameAnalytics then return nil end
	return GameAnalytics.EGAErrorSeverity and GameAnalytics.EGAErrorSeverity[severity]
end

--------------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------------

function AnalyticsService:Init()
	if initialized then return end

	local secrets = tryLoadSecrets()
	if not secrets then return end

	GameAnalytics = tryLoadSdk()
	if not GameAnalytics then return end

	local okConfig, errConfig = pcall(function()
		GameAnalytics:configureBuild(Constants.GAME_VERSION)
	end)
	if not okConfig then
		warn("[AnalyticsService] configureBuild failed:", errConfig)
	end

	local okInit, errInit = pcall(function()
		GameAnalytics:initServer(secrets.GAME_KEY, secrets.SECRET_KEY)
	end)
	if not okInit then
		warn("[AnalyticsService] initServer failed:", errInit)
		return
	end

	initialized = true
end

--------------------------------------------------------------------------------
-- Round Funnel (Design Events — funnel modeling decided later)
--------------------------------------------------------------------------------

function AnalyticsService:LogPhase(player, stepName)
	if typeof(stepName) ~= "string" or #stepName == 0 then
		warn("[AnalyticsService] LogPhase: invalid stepName for", player.Name)
		return
	end
	safeDesignEvent(player, "Round:Phase:" .. stepName)
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------

function AnalyticsService:LogSubmitTime(player, elapsed)
	if typeof(elapsed) ~= "number" then return end
	local clamped = math.clamp(math.floor(elapsed), 0, Constants.ANALYTICS_MAX_ELAPSED)
	-- Both A and B groups submit (the split is analytics-only, gameplay is
	-- identical), so the event id carries no group suffix. Group-level breakdown
	-- still comes from the RoundsPlayed/Quit events that fold the group in.
	safeDesignEvent(player, "Drawing:SubmitTime", clamped)
	local bin = elapsedToBin(clamped, Constants.ANALYTICS_MAX_ELAPSED)
	safeDesignEvent(player, "Drawing:SubmitTime:" .. bin)
end

--------------------------------------------------------------------------------
-- Custom Events
--------------------------------------------------------------------------------

function AnalyticsService:LogRoundsPlayed(player, rounds, group)
	if typeof(rounds) ~= "number" then return end
	local g       = (group == "A" or group == "B") and group or "Unknown"
	local maxRounds = Constants.ANALYTICS_MAX_ROUNDS
	local clamped = math.clamp(math.floor(rounds), 0, maxRounds)
	local bucket  = (clamped >= maxRounds) and (maxRounds .. "Plus") or tostring(clamped)
	-- Group is folded into the event id (RoundsPlayedA / RoundsPlayedB) to
	-- keep the segment count low (GA hard limit is 5).
	safeDesignEvent(player, "Session:RoundsPlayed" .. g, rounds)
	safeDesignEvent(player, "Session:RoundsPlayed" .. g .. ":" .. bucket)
end

-- Buyer-only variant of LogRoundsPlayed: emitted on top of the regular RoundsPlayed
-- (never instead of it) for players who bought a frame this session. The regular metric
-- still counts everyone, so RoundsPlayed minus RoundsPlayedBuyer = non-buyers. Mirrors the
-- group suffix + bucket child of LogRoundsPlayed so the two are comparable side by side.
function AnalyticsService:LogRoundsPlayedBuyer(player, rounds, group)
	if typeof(rounds) ~= "number" then return end
	local g         = (group == "A" or group == "B") and group or "Unknown"
	local maxRounds = Constants.ANALYTICS_MAX_ROUNDS
	local clamped   = math.clamp(math.floor(rounds), 0, maxRounds)
	local bucket    = (clamped >= maxRounds) and (maxRounds .. "Plus") or tostring(clamped)
	safeDesignEvent(player, "Session:RoundsPlayedBuyer" .. g, rounds)
	safeDesignEvent(player, "Session:RoundsPlayedBuyer" .. g .. ":" .. bucket)
end

-- Total Stars a player earned across the session (gross: the running sum of every AddStars,
-- so spending in the shop does not lower it). value enables sum & mean in GA.
function AnalyticsService:LogStarsEarned(player, total)
	if typeof(total) ~= "number" then return end
	local clamped = math.clamp(math.floor(total), 0, Constants.ANALYTICS_MAX_STARS)
	safeDesignEvent(player, "Session:StarsEarned", clamped)
end

-- The player chosen as this round's subject (weighted or guaranteed alike — no split).
-- Logged exactly once per round, so its count doubles as the total-rounds denominator for
-- the subject-quit rate (count(Round:SubjectQuit) / count(Round:Subject)).
function AnalyticsService:LogSubject(player)
	safeDesignEvent(player, "Round:Subject")
end

-- The subject left while still being drawn (currentSubject live = drawing/collecting), i.e.
-- a mid-round subject abandonment (0 or 1 per round). Sibling of Round:Subject so the rate
-- reads directly: count(Round:SubjectQuit) / count(Round:Subject).
function AnalyticsService:LogSubjectQuit(player)
	safeDesignEvent(player, "Round:SubjectQuit")
end

-- Player opened the market this session (caller guards once-per-session).
function AnalyticsService:LogMarketOpened(player)
	safeDesignEvent(player, "Market:Opened")
end

-- Player bought a frame. frameId is deliberately NOT in the event id (a future multi-frame
-- shop would blow up cardinality); a single node keeps the buy count clean.
function AnalyticsService:LogFrameBought(player, _frameId)
	safeDesignEvent(player, "Shop:FrameBought")
end

function AnalyticsService:LogQuit(player, quitType, quitValue, customFields, group)
	if typeof(quitType) ~= "string" or #quitType == 0 then return end
	local g      = (group == "A" or group == "B") and group or "Unknown"
	local value  = typeof(quitValue) == "number" and quitValue or nil
	local fields = typeof(customFields) == "table" and customFields or nil
	-- Group is folded into the quit type suffix (QuitMidRoundA, QuitAloneB...)
	-- so each branch stays within GA's 5-segment limit while keeping the
	-- group split visible directly in the event tree.
	local typedQuit = quitType .. g
	safeDesignEvent(player, "Session:Quit:" .. typedQuit, value, fields)

	if quitType == "QuitMidRound" and fields and typeof(fields.phase) == "string" then
		local elapsed = typeof(fields.phaseElapsed) == "number" and fields.phaseElapsed or nil
		safeDesignEvent(player, "Session:Quit:" .. typedQuit .. ":" .. fields.phase, elapsed)
		if elapsed then
			local bin = elapsedToBin(elapsed, Constants.ANALYTICS_MAX_ELAPSED)
			safeDesignEvent(player, "Session:Quit:" .. typedQuit .. ":" .. fields.phase .. ":" .. bin)
		end
	elseif quitType == "QuitAfterSubmit" then
		local wait = value
		if wait then
			local bin = elapsedToBin(wait, Constants.ANALYTICS_MAX_ELAPSED)
			safeDesignEvent(player, "Session:Quit:" .. typedQuit .. ":Wait" .. bin)
		end
	elseif quitType == "QuitAlone" then
		local stage = (value and value >= 1) and "Lobby" or "Loading"
		local childValue = (stage == "Lobby") and value or nil
		safeDesignEvent(player, "Session:Quit:" .. typedQuit .. ":" .. stage, childValue)
		if stage == "Lobby" and value then
			local bin = elapsedToBin(value, Constants.ANALYTICS_MAX_LOBBY_ELAPSED)
			safeDesignEvent(player, "Session:Quit:" .. typedQuit .. ":" .. stage .. ":" .. bin)
		end
	end
end

--------------------------------------------------------------------------------
-- Errors
--------------------------------------------------------------------------------

function AnalyticsService:LogError(player, severity, message)
	if typeof(player) ~= "Instance" then return end
	local sev = resolveSeverity(severity)
	if not sev then return end
	safeErrorEvent(player.UserId, sev, message)
end

-- Server-level error not tied to a live Player Instance (e.g. a DataStore write
-- failure inside a spawned thread, where only the affected userId is known).
-- GA still needs a userId to attribute the error to; callers pass the userId of
-- the player the failing operation was for. No-op if userId is unknown/invalid.
function AnalyticsService:LogServerError(userId, severity, message)
	local sev = resolveSeverity(severity)
	if not sev then return end
	safeErrorEvent(userId, sev, message)
end

--------------------------------------------------------------------------------
-- Per-player cleanup
--------------------------------------------------------------------------------

function AnalyticsService:ClearPlayer(_player)
	-- GameAnalytics manages player sessions internally; nothing to clean.
end

return AnalyticsService
