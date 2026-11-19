--[[
BanService
----------
Persists timed bans tied to UserId. PlayerAdded checks here so banned
users get kicked on join (in any server). Lazy-expire: nothing is purged
proactively; isBanned returns nil for expired rows so the player can
join again.

Schema (BannedPlayers_v1):
  key   = "ban_" .. userId
  value = { bannedAt, expiresAt, byUserId, reason, reportKey }
  expiresAt = nil means permanent.
]]

local DataStoreService  = game:GetService("DataStoreService")
local MessagingService  = game:GetService("MessagingService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants      = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local AdminService   = require(script.Parent:WaitForChild("AdminService"))
local Analytics      = require(script.Parent:WaitForChild("AnalyticsService"))
local DataStoreRetry = require(script.Parent:WaitForChild("DataStoreRetry"))

local BanService = {}

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local BAN_TOPIC = Constants.BAN_TOPIC

local banStore  -- DataStore handle; nil until Init runs
local initialized = false

-- Side-effect hooks fired (on every server) when a ban lands. Wired at boot so
-- BanService stays free of round/gallery requires; see BanService.onBan.
local banListeners = {}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function keyFor(userId)
	return "ban_" .. tostring(userId)
end

local function kickIfHere(userId, message)
	local target = Players:GetPlayerByUserId(userId)
	if target and target.Parent then
		pcall(function() target:Kick(message) end)
	end
end

local function formatBanMessage(banEntry)
	if banEntry and banEntry.expiresAt then
		local remaining = math.max(0, banEntry.expiresAt - os.time())
		local hours     = math.ceil(remaining / Constants.SECONDS_PER_HOUR)
		return string.format("You are suspended for %d more hour(s).", hours)
	end
	return "You are permanently suspended."
end

--------------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------------

function BanService:Init()
	if initialized then return end
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(Constants.BAN_STORE)
	end)
	if ok then
		banStore = store
	else
		warn("[BanService] Init: DataStore unavailable -", store)
	end

	-- Cross-server propagation: when any server publishes a new ban, every
	-- server checks whether the banned user is currently here and kicks
	-- them. The publishing server also receives its own message, so the
	-- explicit local kick in AdminPanelService is a fast-path; this hook
	-- is idempotent because Kick on an already-leaving player is a no-op.
	pcall(function()
		MessagingService:SubscribeAsync(BAN_TOPIC, function(message)
			local payload = message and message.Data
			if typeof(payload) ~= "table" then return end
			if typeof(payload.userId) ~= "number" then return end
			local entry = BanService.isBanned(payload.userId)
			if not entry then return end
			kickIfHere(payload.userId, formatBanMessage(entry))
			-- Every server (the publisher receives its own message too) runs the ban
			-- side-effects here, so a banned owner's drawing is pulled from the reveal/
			-- gallery on all servers, not just where the admin acted.
			for _, listener in ipairs(banListeners) do
				pcall(listener, payload.userId)
			end
		end)
	end)

	initialized = true
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

-- Registers a side-effect run once per ban on EVERY server (via the BAN_TOPIC
-- subscriber), with the banned userId. Used to pull the banned owner's drawing
-- from the reveal/gallery without coupling BanService to RoundManager.
function BanService.onBan(callback)
	table.insert(banListeners, callback)
end

-- Returns (ok, reason). reason is set only on failure so the admin panel can
-- show a precise message instead of a generic "Ban failed":
--   "store_unavailable" -> DataStore never initialised (Studio API access off)
--   "store_busy"        -> write threw even after retries (throttle/quota)
function BanService.ban(adminPlayer, targetUserId, durationSeconds, reason, reportKey)
	if not banStore then
		-- DataStore never came up (Init failed / Studio API access off). Without
		-- this the ban silently no-ops; the admin only sees the row flip back.
		warn("[BanService] ban: banStore unavailable, ban NOT persisted for", targetUserId)
		Analytics:LogServerError(targetUserId, "error", "Ban failed: banStore unavailable")
		return false, "store_unavailable"
	end
	if typeof(targetUserId) ~= "number" or targetUserId <= 0 then return false, "store_busy" end

	local now = os.time()
	local entry = {
		bannedAt   = now,
		expiresAt  = (typeof(durationSeconds) == "number") and (now + durationSeconds) or nil,
		byUserId   = adminPlayer and adminPlayer.UserId or 0,
		reason     = reason or "",
		reportKey  = reportKey,
	}

	local ok, err = DataStoreRetry.writeWithRetry(function()
		banStore:SetAsync(keyFor(targetUserId), entry)
	end)
	if not ok then
		warn("[BanService] ban write failed:", err)
		Analytics:LogServerError(targetUserId, "error", "Ban write failed: " .. tostring(err))
		return false, "store_busy"
	end

	AdminService:LogAction(adminPlayer, "Ban", {
		targetUserId = targetUserId,
		duration     = durationSeconds,
		reason       = reason,
		reportKey    = reportKey,
	})

	-- Notify all servers so the target gets kicked wherever they are now.
	task.spawn(function()
		local pubOk, pubErr = pcall(function()
			MessagingService:PublishAsync(BAN_TOPIC, { userId = targetUserId })
		end)
		if not pubOk then
			warn("[BanService] publish failed:", pubErr)
		end
	end)

	return true
end

function BanService.isBanned(userId)
	if not banStore then return nil end
	if typeof(userId) ~= "number" or userId <= 0 then return nil end

	local ok, entry = pcall(function()
		return banStore:GetAsync(keyFor(userId))
	end)
	if not ok then
		-- Read FAILED (throttle/network/quota), not "no ban on record". We stay
		-- fail-open (return nil so the join proceeds) but make it loud: a banned
		-- player can slip in for this session and is only caught on rejoin, so
		-- the warn + analytics are the only signal this happened.
		warn("[BanService] isBanned read FAILED (fail-open, player allowed in):", entry)
		Analytics:LogServerError(userId, "error", "isBanned read failed: " .. tostring(entry))
		return nil
	end
	if typeof(entry) ~= "table" then return nil end

	if entry.expiresAt and entry.expiresAt < os.time() then
		return nil
	end

	return entry
end

return BanService
