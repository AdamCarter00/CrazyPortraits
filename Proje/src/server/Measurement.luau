--!strict

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.Analytics)
local Core = require(Shared.Analytics.Core)
local Metrics = require(Shared.Analytics.Metrics)
local PlayerDataService = require(script.Parent.PlayerDataService)

local Measurement = {}

local tracked: { [number]: Player } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function launchData(player: Player): any
	local ok, data = pcall(function()
		return player:GetJoinData().LaunchData
	end)
	return if ok then data else nil
end

local core = Core.new({
	config = Config,
	clock = now,
	studio = RunService:IsStudio(),
	playerCount = function()
		return #Players:GetPlayers()
	end,
	send = function(userId, name, value, custom)
		local player = tracked[userId]
		if not player then
			return
		end
		local fields = {}
		for key, text in custom do
			fields[(Enum.AnalyticsCustomFieldKeys :: any)[key].Name] = text
		end
		AnalyticsService:LogCustomEvent(player, name, value, fields)
	end,
	output = print,
	warn = warn,
})

local state = Metrics.new({ config = Config, core = core })

local function guarded(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if not ok then
		warn(Config.CiktiOneki, name, err)
	end
end

function Measurement.join(player: Player)
	guarded("join", function()
		tracked[player.UserId] = player
		Metrics.join(state, player.UserId, now(), launchData(player))
	end)
end

function Measurement.profileReady(player: Player)
	guarded("profile", function()
		if tracked[player.UserId] ~= player then
			return
		end
		local record = Metrics.profile(state, player.UserId, now(), PlayerDataService:GetFirstJoin(player), launchData(player))
		if record then
			PlayerDataService:RecordFirstJoin(player, record)
		end
	end)
end

function Measurement.leave(player: Player)
	guarded("leave", function()
		if tracked[player.UserId] ~= player then
			return
		end
		Metrics.leave(state, player.UserId, now())
		tracked[player.UserId] = nil
	end)
end

function Measurement.observe(machine: any, at: number, action: any?)
	guarded("observe", function()
		Metrics.observe(state, machine, at, action)
	end)
end

return Measurement
