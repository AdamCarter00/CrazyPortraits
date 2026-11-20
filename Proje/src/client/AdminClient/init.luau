--!strict

-- Admin olmayan istemciye sunucu hic Admin mesaji gondermez; panel onlarda acilmaz.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared").Net)
local AdminPanelClient = require(script:WaitForChild("AdminPanelClient"))
local DrawingsPanelClient = require(script:WaitForChild("DrawingsPanelClient"))

local AdminClient = {}

function AdminClient.start()
	local player = Players.LocalPlayer
	Net.onClientEvent("Admin", function(eventKind, payload)
		if typeof(eventKind) ~= "string" or typeof(payload) ~= "table" then
			return
		end
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
	end)
end

return AdminClient
