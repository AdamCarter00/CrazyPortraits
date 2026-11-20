--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Machine = require(Shared.Round.Machine)
local RoundConfig = require(Shared.Config.Round)
local StrokeValidator = require(Shared.Drawing.StrokeValidator)
local StrokeCodec = require(Shared.Drawing.StrokeCodec)

local RoundService = {}

local state = nil

local function now(): number
	return workspace:GetServerTimeNow()
end

local function apply(effects)
	for _, effect in effects do
		if effect.to == "all" then
			Net.toAll(effect.name, effect.payload)
		else
			Net.toUserId(effect.to, effect.name, effect.payload)
		end
	end
end

local function onSubmit(player: Player, payload: any)
	if typeof(payload) ~= "table" or typeof(payload.drawing) ~= "buffer" then
		return
	end
	local strokes, rejected = StrokeValidator.validate(payload.drawing)
	if not strokes then
		return
	end
	if rejected > 0 then
		warn("[RoundService]", player.Name, "-", rejected, "gecersiz cizgi atildi")
	end
	apply(Machine.submit(state, player.UserId, StrokeCodec.encode(strokes), #strokes, now()))
end

local function onVote(player: Player, payload: any)
	if typeof(payload) ~= "table" or typeof(payload.drawingId) ~= "string" or typeof(payload.emoji) ~= "string" then
		return
	end
	apply(Machine.vote(state, player.UserId, payload.drawingId, payload.emoji, now()))
end

function RoundService.start(pickSubject: (candidates: { number }, state: any) -> number)
	state = Machine.new({ config = RoundConfig, pickSubject = pickSubject })

	Net.onServerEvent("Round", function(player, name, payload)
		if name == "Ready" then
			apply(Machine.ready(state, player.UserId, now()))
		elseif name == "Submit" then
			onSubmit(player, payload)
		elseif name == "Vote" then
			onVote(player, payload)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(RoundConfig.TickSeconds)
			local ok, err = pcall(function()
				apply(Machine.tick(state, now()))
			end)
			if not ok then
				warn("[RoundService] tick:", err)
			end
		end
	end)
end

function RoundService.join(player: Player)
	apply(Machine.join(state, player.UserId, player.DisplayName, now()))
end

function RoundService.leave(player: Player)
	apply(Machine.leave(state, player.UserId, now()))
end

function RoundService.isStarted(): boolean
	return state ~= nil
end

Players.PlayerRemoving:Connect(function(player)
	if state then
		RoundService.leave(player)
	end
end)

return RoundService
