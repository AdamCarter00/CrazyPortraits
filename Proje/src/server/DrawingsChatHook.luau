--[[
DrawingsChatHook
----------------
Server-side TextChatService hook that turns `/drawings` into an open request for
the drawing-analysis panel (browse first-timer drawings) for whitelisted admins.
Kept separate from AdminChatHook so the analysis tool stays independent of the
/panel moderation flow. Non-admin usage is logged as an anomaly and ignored.
]]

local Players         = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local AdminService         = require(script.Parent:WaitForChild("AdminService"))
local DrawingsPanelService = require(script.Parent:WaitForChild("DrawingsPanelService"))

local DrawingsChatHook = {}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function ensureDrawingsCommand()
	local existing = TextChatService:FindFirstChild("DrawingsCommand", true)
	if existing then return existing end

	local cmd = Instance.new("TextChatCommand")
	cmd.Name                = "DrawingsCommand"
	cmd.PrimaryAlias        = "/drawings"
	cmd.AutocompleteVisible = false
	cmd.Parent              = TextChatService
	return cmd
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

function DrawingsChatHook.connect()
	local command = ensureDrawingsCommand()

	command.Triggered:Connect(function(textSource, _message)
		if not textSource then return end
		local player = Players:GetPlayerByUserId(textSource.UserId)
		if not player then return end

		if not AdminService:IsAdmin(player) then
			AdminService:RegisterAnomaly(player, "UnauthorizedSlashCommand", {
				command = "/drawings",
			})
			return
		end

		DrawingsPanelService.handleShowDrawings(player, { cursor = nil })
	end)
end

return DrawingsChatHook
