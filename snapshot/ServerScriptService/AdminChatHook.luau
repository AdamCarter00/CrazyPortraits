--[[
AdminChatHook
-------------
Server-side TextChatService hook that turns `/panel` into a panel-open
request for whitelisted admins. Non-admin usage is logged as an anomaly
and silently ignored.

Uses TextChatCommand (modern Roblox API) which keeps the slash command
out of the visible chat log automatically.
]]

local Players         = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local AdminService      = require(script.Parent:WaitForChild("AdminService"))
local AdminPanelService = require(script.Parent:WaitForChild("AdminPanelService"))

local AdminChatHook = {}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function ensurePanelCommand()
	local existing = TextChatService:FindFirstChild("PanelCommand", true)
	if existing then return existing end

	local cmd = Instance.new("TextChatCommand")
	cmd.Name             = "PanelCommand"
	cmd.PrimaryAlias     = "/panel"
	cmd.AutocompleteVisible = false
	cmd.Parent           = TextChatService
	return cmd
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

function AdminChatHook.connect()
	local command = ensurePanelCommand()

	command.Triggered:Connect(function(textSource, _message)
		if not textSource then return end
		local player = Players:GetPlayerByUserId(textSource.UserId)
		if not player then return end

		if not AdminService:IsAdmin(player) then
			AdminService:RegisterAnomaly(player, "UnauthorizedSlashCommand", {
				command = "/panel",
			})
			return
		end

		-- handleShowPanel issues ~170 synchronous DataStore reads; run it off the
		-- Triggered thread so the chat command does not block (and an error in it
		-- cannot break this listener).
		task.spawn(AdminPanelService.handleShowPanel, player)
	end)
end

return AdminChatHook
