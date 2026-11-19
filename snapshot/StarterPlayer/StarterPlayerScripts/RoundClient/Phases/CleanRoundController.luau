local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))

local CleanRoundController = {}
CleanRoundController.__index = CleanRoundController

function CleanRoundController.new(scene, refs, canvasController, drawingController, passController)
	return setmetatable({
		scene            = scene,
		refs             = refs,
		canvasController = canvasController,
		drawingController = drawingController,
		passController   = passController,
	}, CleanRoundController)
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

function CleanRoundController:Enter()
	-- State teardown is invisible (no scene change), so run it now regardless of the
	-- transition screen.
	self.drawingController:Exit()
	self.canvasController:SetDrawingEnabled(false)
	self.canvasController:ClearCanvas()

	-- The visible reset (free camera, hide reveal UI, show the lobby phase label)
	-- runs behind the "Lobby" transition screen so it does not change under the
	-- screen's fade-in; if no screen showed this transition (mid-join), it runs now.
	-- The reveal surface has no caption anymore, and FrameController:Clear() hides the
	-- frame border when the reveal exits, so there is nothing to clear here.
	self.passController:ScheduleSceneSetup(function()
		self.scene:HideAllUI()
		self.scene:SetFreeCamera()
		self.scene:ShowPhaseGui(Constants.TEXT_PHASE_CLEAN, "")
		-- Reopen the sidebar the reveal hid (RevealController disables it so the drawing
		-- has the full screen).
		if self.refs.SidebarGui then self.refs.SidebarGui.Enabled = true end
	end)
end

function CleanRoundController:Exit() end

return CleanRoundController
