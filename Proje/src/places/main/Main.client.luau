local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = script.Parent:WaitForChild("Client")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Binding = require(Shared.Config.Binding)
local Terms = require(Shared.Config.Terms)
local Net = require(Shared.Net)
local Binder = require(Client:WaitForChild("Binder"))
local GuiVisibility = require(Client:WaitForChild("GuiVisibility"))
local DrawingScreen = require(Client:WaitForChild("DrawingScreen"))
local PhaseView = require(Client:WaitForChild("PhaseView"))

require(Client:WaitForChild("AdminClient")).start()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local refs, selected = Binder.bind(playerGui, Binder.expected(), Binding.GuiWaitSeconds)
local visibility = GuiVisibility.new(playerGui)
local drawing = DrawingScreen.new(refs, selected, visibility)
local phase = PhaseView.new(refs)

local function secondsLeft(endsAt)
	return math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
end

drawing.onOpened = function()
	phase:hide()
end

drawing.onSubmitted = function()
	phase:show(Terms.PhaseSubmitted)
end

Net.onClientEvent("Round", function(name, payload)
	if name == "Lobby" then
		drawing:close()
		if payload.status == "countdown" then
			phase:ticker(function()
				return string.format(Terms.RoundStarting, secondsLeft(payload.endsAt))
			end)
		else
			phase:show(Terms.Waiting)
		end
	elseif name == "Drawing" then
		if table.find(payload.participants, player.UserId) then
			drawing:open(payload)
		else
			drawing:close()
			phase:ticker(function()
				return Terms.PhaseDrawing, string.format(Terms.TimerText, secondsLeft(payload.endsAt))
			end)
		end
	elseif name == "Collect" then
		drawing:collect()
		phase:show(Terms.PhaseCollect)
	elseif name == "Reveal" then
		drawing:close()
		phase:show(Terms.PhaseReveal, string.format(Terms.RevealCount, payload.index, payload.total))
	elseif name == "Podium" then
		drawing:close()
		phase:show(Terms.PhaseClean)
	end
end)

Net.fireServer("Round", "Ready", {})
