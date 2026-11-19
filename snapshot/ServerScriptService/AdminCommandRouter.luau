--[[
AdminCommandRouter
------------------
Single OnServerEvent listener for AdminRemote. Every call is gated by
AdminService.IsAdmin + rate limit before any handler runs. Unknown
commands and unauthorized callers are silently dropped while being
logged as anomalies.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdminService         = require(script.Parent:WaitForChild("AdminService"))
local AdminPanelService    = require(script.Parent:WaitForChild("AdminPanelService"))
local DrawingsPanelService = require(script.Parent:WaitForChild("DrawingsPanelService"))

local AdminRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AdminRemote")

local AdminCommandRouter = {}

--------------------------------------------------------------------------------
-- Handlers
--------------------------------------------------------------------------------

local handlers = {}

handlers.Ping = function(player, _payload)
	AdminService:LogAction(player, "Ping")
	AdminRemote:FireClient(player, "AdminAck", { command = "Ping" })
end

handlers.ViewReport = function(player, payload)
	AdminPanelService.handleViewReport(player, payload)
end

handlers.ViewFirstDrawing = function(player, payload)
	AdminPanelService.handleViewFirstDrawing(player, payload)
end

handlers.DismissReport = function(player, payload)
	AdminPanelService.handleDismissReport(player, payload)
end

handlers.BanReportee = function(player, payload)
	AdminPanelService.handleBanReportee(player, payload)
end

handlers.ShowDrawings = function(player, payload)
	DrawingsPanelService.handleShowDrawings(player, payload)
end

handlers.ViewDrawing = function(player, payload)
	DrawingsPanelService.handleViewDrawing(player, payload)
end

--------------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------------

function AdminCommandRouter.connect()
	AdminRemote.OnServerEvent:Connect(function(player, commandName, payload)
		if typeof(commandName) ~= "string" or #commandName == 0 then
			AdminService:RegisterAnomaly(player, "BadArgs")
			return
		end

		if not AdminService:IsAdmin(player) then
			AdminService:RegisterAnomaly(player, "UnauthorizedAdminCall", {
				command = commandName,
			})
			return
		end

		if not AdminService:CheckRateLimit(player, "global") then
			-- Tell the admin instead of dropping silently: an optimistic Dismiss/Ban
			-- row would otherwise hang with no confirmation and no rollback.
			AdminRemote:FireClient(player, "CommandRejected", {
				command = commandName,
				reason  = "rate_limited",
			})
			return
		end

		local handler = handlers[commandName]
		if not handler then
			AdminService:RegisterAnomaly(player, "UnknownAdminCommand", {
				command = commandName,
			})
			return
		end

		-- Isolate handlers: an unexpected error in one must not tear down the single
		-- OnServerEvent listener (which would silently kill all later admin actions).
		local ok, err = pcall(handler, player, payload)
		if not ok then
			warn("[AdminCommandRouter] handler error for", commandName, "-", err)
			AdminRemote:FireClient(player, "CommandRejected", {
				command = commandName,
				reason  = "server_error",
			})
		end
	end)
end

return AdminCommandRouter
