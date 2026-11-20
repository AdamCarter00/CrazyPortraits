local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = script.Parent:WaitForChild("Client")
local Net = require(ReplicatedStorage:WaitForChild("Shared").Net)
local Binder = require(Client:WaitForChild("Binder"))
local GuiVisibility = require(Client:WaitForChild("GuiVisibility"))
local DrawingScreen = require(Client:WaitForChild("DrawingScreen"))

require(Client:WaitForChild("AdminClient")).start()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local refs, selected = Binder.collect(playerGui, Binder.expected())
local visibility = GuiVisibility.new(playerGui)
local drawing = DrawingScreen.new(refs, selected, visibility)

Net.onClientEvent("Round", function(name, payload)
	if name == "Drawing" then
		if table.find(payload.participants, player.UserId) then
			drawing:open(payload)
		else
			drawing:close()
		end
	elseif name == "Collect" then
		drawing:collect()
	elseif name == "Lobby" or name == "Reveal" or name == "Podium" then
		drawing:close()
	end
end)

Net.fireServer("Round", "Ready", {})
