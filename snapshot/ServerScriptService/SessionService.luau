--[[
SessionService
--------------
Tracks a per-player "lifetime session count": how many times the player has
joined the game across their whole history. Backed by a DataStore keyed on
UserId, incremented atomically on each join.

The count is read+incremented when the player joins (BeginSession) and cached
in memory so other systems (e.g. the drawing-quit log) can read it cheaply
without another DataStore round-trip. Returns -1 when the value is unknown
(DataStore failure) so callers can log "unknown" rather than block.
]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Analytics = require(script.Parent:WaitForChild("AnalyticsService"))

local SessionService = {}

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local store = DataStoreService:GetDataStore(Constants.SESSION_COUNT_STORE)

-- [userId] = number (lifetime session count for the current join), or -1 unknown
local cache = {}

local function keyFor(userId)
	return "u" .. tostring(userId)
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

-- Atomically increments and caches the player's lifetime session count.
-- Safe to call from a spawned thread; never errors out (DataStore failures
-- leave the cached value at -1 = unknown).
function SessionService:BeginSession(userId)
	if typeof(userId) ~= "number" or userId <= 0 then return end

	cache[userId] = -1  -- default to unknown until the write succeeds

	local newCount
	local ok, err = pcall(function()
		store:UpdateAsync(keyFor(userId), function(old)
			local prev = (typeof(old) == "number") and old or 0
			newCount = prev + 1
			return newCount
		end)
	end)
	if not ok then
		warn("[SessionService] BeginSession UpdateAsync failed:", err)
		Analytics:LogServerError(userId, "error", "SessionService write failed: " .. tostring(err))
		return
	end
	if typeof(newCount) == "number" then
		cache[userId] = newCount
	end
end

-- Returns the cached lifetime session count, or -1 if unknown / not loaded.
function SessionService:GetSessionCount(userId)
	if typeof(userId) ~= "number" then return -1 end
	local v = cache[userId]
	if typeof(v) ~= "number" then return -1 end
	return v
end

function SessionService:ClearCache(userId)
	cache[userId] = nil
end

return SessionService
