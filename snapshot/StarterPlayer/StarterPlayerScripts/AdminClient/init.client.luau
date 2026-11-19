--[[
AdminClient
-----------
Wires AdminPanelClient to AdminRemote. Runs on every client; non-admins
simply never receive any FireClient events from the server so the UI
never appears for them.

Kept independent from RoundClient so an unrelated error there does not
prevent admin moderation.
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdminRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AdminRemote")

local AdminPanelClient    = require(script:WaitForChild("AdminPanelClient"))
local DrawingsPanelClient = require(script:WaitForChild("DrawingsPanelClient"))

local player = Players.LocalPlayer

AdminRemote.OnClientEvent:Connect(function(eventKind, payload)
	if typeof(eventKind) ~= "string" then return end
	if typeof(payload) ~= "table" then return end

	if eventKind == "ShowPanel" then
		AdminPanelClient.show(player, payload.active or {}, payload.history or {}, payload.firstDrawings or {})
	elseif eventKind == "ReportDetail" then
		AdminPanelClient.renderDrawing(payload)
	elseif eventKind == "FirstDrawingDetail" then
		AdminPanelClient.renderFirstDrawing(payload)
	elseif eventKind == "BanResult" or eventKind == "DismissResult" then
		AdminPanelClient.onActionResult(eventKind, payload)
	elseif eventKind == "ViewReportFailed" or eventKind == "PanelRejected" or eventKind == "CommandRejected" then
		AdminPanelClient.onCommandRejected(eventKind, payload)
	elseif eventKind == "DrawingsPage" then
		DrawingsPanelClient.showPage(payload)
	elseif eventKind == "DrawingDetail" then
		DrawingsPanelClient.renderDrawing(payload)
	end
	-- AdminAck and any unknown events are ignored.
end)
