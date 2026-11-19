--[[
AdminService
------------
Server-only admin authority, audit logging, anomaly tracking, and rate
limiting. The whitelist lives in this file as a constant Lua table; the
client never learns whether a player is an admin.

Public API:
  AdminService:Init()
  AdminService:IsAdmin(player) -> bool
  AdminService:LogAction(player, action, details)
  AdminService:RegisterAnomaly(player, kind, details)
  AdminService:CheckRateLimit(player, bucket) -> bool

Design principles:
  - Fail-closed: any uncertainty results in deny + silent drop.
  - No leakage: unauthorized callers receive no response, no error.
  - Defense in depth: whitelist + rate limit + anomaly counter + audit log.
]]

local DataStoreService  = game:GetService("DataStoreService")
local HttpService       = game:GetService("HttpService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))

local AdminService = {}

--------------------------------------------------------------------------------
-- Whitelist
--------------------------------------------------------------------------------

-- Replace PLACEHOLDER_USER_ID with the real Roblox UserId before deploying.
local ADMIN_USER_IDS = {
	[10330652079] = true,  -- user.email: ismailbaransen@gmail.com
}

-- Length of the random GUID suffix appended to audit log keys.
local AUDIT_KEY_GUID_LEN = 8

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local initialized = false
local auditStore  -- DataStore handle; nil if Init has not run

-- [userId] = { count, firstAt }
local anomalyCounters = {}

-- [userId][bucket] = { count, windowStart }
local rateLimitBuckets = {}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function makeAuditKey(userId)
	local suffix = string.sub(HttpService:GenerateGUID(false), 1, AUDIT_KEY_GUID_LEN)
	return string.format("a_%d_%d_%s", os.time(), userId or 0, suffix)
end

local function writeAudit(entry)
	if not auditStore then return end
	task.spawn(function()
		local key = makeAuditKey(entry.userId)
		local ok, err = pcall(function()
			auditStore:SetAsync(key, entry)
		end)
		if not ok then
			warn("[AdminService] Audit write failed:", err)
		end
	end)
end

local function purgeOldAnomalies(userId, now)
	local bucket = anomalyCounters[userId]
	if not bucket then return end
	if now - bucket.firstAt > Constants.ANOMALY_WINDOW_SECONDS then
		anomalyCounters[userId] = nil
	end
end

--------------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------------

function AdminService:Init()
	if initialized then return end

	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(Constants.AUDIT_LOG_STORE)
	end)
	if ok then
		auditStore = store
	else
		warn("[AdminService] Init: audit DataStore unavailable -", store)
	end

	-- Clear per-player state when they leave so memory does not grow.
	Players.PlayerRemoving:Connect(function(player)
		anomalyCounters[player.UserId]  = nil
		rateLimitBuckets[player.UserId] = nil
	end)

	initialized = true
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

function AdminService:IsAdmin(player)
	if typeof(player) ~= "Instance" then return false end
	if not player:IsA("Player") then return false end
	return ADMIN_USER_IDS[player.UserId] == true
end

function AdminService:LogAction(player, action, details)
	if typeof(action) ~= "string" or #action == 0 then return end

	local entry = {
		userId    = player and player.UserId or 0,
		userName  = player and player.Name   or "system",
		action    = action,
		details   = typeof(details) == "table" and details or nil,
		timestamp = os.time(),
		jobId     = game.JobId,
	}

	print("[AdminService] Action:", action, "by", entry.userName)
	writeAudit(entry)
end

function AdminService:RegisterAnomaly(player, kind, details)
	if typeof(kind) ~= "string" or #kind == 0 then return end

	local userId   = player and player.UserId or 0
	local userName = player and player.Name   or "unknown"
	local now      = os.time()

	warn("[AdminService] Anomaly:", kind, "by", userName)

	writeAudit({
		userId    = userId,
		userName  = userName,
		action    = "Anomaly:" .. kind,
		details   = typeof(details) == "table" and details or nil,
		timestamp = now,
		jobId     = game.JobId,
	})

	if not player or not player:IsA("Player") then return end

	purgeOldAnomalies(userId, now)
	local bucket = anomalyCounters[userId]
	if not bucket then
		bucket = { count = 0, firstAt = now }
		anomalyCounters[userId] = bucket
	end
	bucket.count += 1

	if bucket.count >= Constants.ANOMALY_KICK_THRESHOLD then
		writeAudit({
			userId    = userId,
			userName  = userName,
			action    = "Anomaly:AutoKick",
			details   = { triggerKind = kind, count = bucket.count },
			timestamp = now,
			jobId     = game.JobId,
		})
		anomalyCounters[userId] = nil
		pcall(function() player:Kick() end)
	end
end

function AdminService:CheckRateLimit(player, bucketName)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return false end
	if typeof(bucketName) ~= "string" or #bucketName == 0 then bucketName = "global" end

	local now      = os.time()
	local userId   = player.UserId
	local userBuckets = rateLimitBuckets[userId]
	if not userBuckets then
		userBuckets = {}
		rateLimitBuckets[userId] = userBuckets
	end

	local bucket = userBuckets[bucketName]
	if not bucket or now - bucket.windowStart >= Constants.RATE_LIMIT_WINDOW_SECONDS then
		userBuckets[bucketName] = { count = 1, windowStart = now }
		return true
	end

	if bucket.count >= Constants.RATE_LIMIT_MAX_PER_MINUTE then
		return false
	end
	bucket.count += 1
	return true
end

return AdminService
