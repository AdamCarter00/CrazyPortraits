--!strict

local Players = game:GetService("Players")

local Server = script.Parent:WaitForChild("Server")
local AdminService = require(Server.AdminService)
local AdminCommandRouter = require(Server.AdminCommandRouter)
local AdminChatHook = require(Server.AdminChatHook)
local DrawingsChatHook = require(Server.DrawingsChatHook)
local BanService = require(Server.BanService)
local PlayerDataService = require(Server.PlayerDataService)
local RoundService = require(Server.RoundService)
local Measurement = require(Server.Measurement)

local function startup(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if not ok then
		warn("[Main] baslatilamadi:", name, "-", err)
	end
end

startup("AdminService", function()
	AdminService:Init()
end)
startup("BanService", function()
	BanService:Init()
end)
startup("AdminCommandRouter", AdminCommandRouter.connect)
startup("AdminChatHook", AdminChatHook.connect)
startup("DrawingsChatHook", DrawingsChatHook.connect)
startup("RoundService", RoundService.start)
startup("Measurement", function()
	RoundService.observe(Measurement.observe)
end)

local function onPlayerAdded(player: Player)
	local banEntry = BanService.isBanned(player.UserId)
	if banEntry then
		pcall(function()
			player:Kick(BanService.formatBanMessage(banEntry))
		end)
		return
	end
	Measurement.join(player)
	local ok, err = pcall(function()
		PlayerDataService:OnPlayerAdded(player)
	end)
	if not ok then
		warn("[Main] PlayerData:", player.Name, "-", err)
	end
	Measurement.profileReady(player)
	if player.Parent and RoundService.isStarted() then
		RoundService.join(player)
	end
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(onPlayerAdded, player)
end)

Players.PlayerRemoving:Connect(function(player)
	Measurement.leave(player)
	local ok, err = pcall(function()
		PlayerDataService:OnPlayerRemoving(player)
	end)
	if not ok then
		warn("[Main] PlayerData cikis:", player.Name, "-", err)
	end
end)

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
