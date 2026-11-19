local RoundManager       = require(script.Parent.Round)
local SubjectService     = require(script.Parent.SubjectService)
local AnalyticsService   = require(script.Parent.AnalyticsService)
local AdminService       = require(script.Parent.AdminService)
local AdminCommandRouter = require(script.Parent.AdminCommandRouter)
local AdminChatHook      = require(script.Parent.AdminChatHook)
local DrawingsChatHook   = require(script.Parent.DrawingsChatHook)
local BanService         = require(script.Parent.BanService)
local PlayerDataService  = require(script.Parent.PlayerDataService)
local SubjectGuaranteeService = require(script.Parent.SubjectGuaranteeService)
local FrameShopService   = require(script.Parent.FrameShopService)

--------------------------------------------------------------------------------
-- Services
--------------------------------------------------------------------------------

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))

--------------------------------------------------------------------------------
-- Service startup
--------------------------------------------------------------------------------

-- Each startup step is isolated so one failing service does not abort the rest
-- (a half-booted server is far easier to diagnose from logs than a silent
-- chain stop). Failures are loud on purpose: at launch these warns are the
-- first signal that a system never came up.
local function startup(name, fn)
	local ok, err = pcall(fn)
	if not ok then
		warn("[GameServer] startup FAILED:", name, "-", err)
	end
end

startup("AnalyticsService:Init",  function() AnalyticsService:Init() end)
startup("SubjectService:Init",    function() SubjectService:Init() end)
startup("SubjectGuaranteeService:Init", function() SubjectGuaranteeService:Init(RoundManager) end)
startup("FrameShopService:Init",  function() FrameShopService:Init() end)
startup("AdminService:Init",      function() AdminService:Init() end)
startup("BanService:Init",        function() BanService:Init() end)
startup("BanService:onBan",       function()
	-- On every server: a ban pulls the owner's drawing from the reveal/gallery.
	BanService.onBan(function(userId) RoundManager:RemoveOwnerDrawings(userId) end)
end)
startup("AdminCommandRouter",     function() AdminCommandRouter.connect() end)
startup("AdminChatHook",          function() AdminChatHook.connect() end)
startup("DrawingsChatHook",       function() DrawingsChatHook.connect() end)

--------------------------------------------------------------------------------
-- Player Lifecycle
--------------------------------------------------------------------------------

local function teleportToSpawn(player)
	local character = player.Character
	if not character then return end
	-- Timeouts + guards: with StreamingEnabled a part may not be present yet, and
	-- an untimed WaitForChild would yield this thread forever ("Infinite yield").
	local rootPart = character:WaitForChild("HumanoidRootPart", Constants.CHARACTER_WAIT_TIMEOUT)
	if not rootPart then return end

	local gamePlay = workspace.Map.GamePlay
	local spawnPoint = gamePlay:WaitForChild("SpawnLocation", Constants.MAP_TIMEOUT)
	if not spawnPoint then
		warn("[GameServer] teleportToSpawn: SpawnLocation missing for", player.Name)
		return
	end

	task.wait(0.2)
	if player.Character then
		player.Character:PivotTo(spawnPoint.CFrame + Vector3.new(0, 5, 0))
	end
end

local function onCharacterAdded(player)
	player.CharacterAdded:Connect(function()
		task.spawn(teleportToSpawn, player)
	end)
	if player.Character then
		task.spawn(teleportToSpawn, player)
	end
end

local function onPlayerAdded(player)
	local banEntry = BanService.isBanned(player.UserId)
	if banEntry then
		local message
		if banEntry.expiresAt then
			local remaining = math.max(0, banEntry.expiresAt - os.time())
			local hours     = math.ceil(remaining / Constants.SECONDS_PER_HOUR)
			message = string.format("You are suspended for %d more hour(s).", hours)
		else
			message = "You are permanently suspended."
		end
		pcall(function() player:Kick(message) end)
		return
	end
	if player.Parent then
		-- Data loads first so the player's persistent state (Star balance, ...) is
		-- independent of round logic. Guarded separately: a profile load failure
		-- Kicks the player from within the service, but must not also abort the
		-- round join below.
		local dataOk, dataErr = pcall(function()
			PlayerDataService:OnPlayerAdded(player)
		end)
		if not dataOk then
			warn("[GameServer] PlayerData OnPlayerAdded failed for", player.Name, "-", dataErr)
			AnalyticsService:LogError(player, "error", "PlayerData OnPlayerAdded failed: " .. tostring(dataErr))
		end

		-- Frame Game Pass sync runs after the profile loads so its grants have somewhere to
		-- land. Guarded separately: an ownership web-call failure must not abort the round join.
		local frameOk, frameErr = pcall(function()
			FrameShopService:OnPlayerAdded(player)
		end)
		if not frameOk then
			warn("[GameServer] FrameShop OnPlayerAdded failed for", player.Name, "-", frameErr)
			AnalyticsService:LogError(player, "error", "FrameShop OnPlayerAdded failed: " .. tostring(frameErr))
		end

		-- Runs in a spawned thread, so an error here would otherwise vanish.
		-- Make it loud: a failed join leaves the player in a broken state.
		local ok, err = pcall(function()
			RoundManager:OnPlayerAdded(player)
		end)
		if not ok then
			warn("[GameServer] OnPlayerAdded failed for", player.Name, "-", err)
			AnalyticsService:LogError(player, "error", "OnPlayerAdded failed: " .. tostring(err))
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(onPlayerAdded, player)
	onCharacterAdded(player)
end)

Players.PlayerRemoving:Connect(function(player)
	-- Guarded so a mid-cleanup error still lets the rest of removal proceed and,
	-- critically, surfaces in logs (this path writes the quit log + frees state).
	local ok, err = pcall(function()
		RoundManager:OnPlayerRemoving(player)
	end)
	if not ok then
		warn("[GameServer] OnPlayerRemoving failed for", player.Name, "-", err)
		AnalyticsService:LogError(player, "error", "OnPlayerRemoving failed: " .. tostring(err))
	end

	-- Independent guard: the profile session must be released even if round
	-- cleanup above threw, otherwise the lock blocks the player's next join.
	local dataOk, dataErr = pcall(function()
		PlayerDataService:OnPlayerRemoving(player)
	end)
	if not dataOk then
		warn("[GameServer] PlayerData OnPlayerRemoving failed for", player.Name, "-", dataErr)
		AnalyticsService:LogError(player, "error", "PlayerData OnPlayerRemoving failed: " .. tostring(dataErr))
	end
end)

--------------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------------

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
	onCharacterAdded(player)
end
