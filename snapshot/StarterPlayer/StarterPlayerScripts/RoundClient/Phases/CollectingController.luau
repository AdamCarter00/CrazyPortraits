local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants    = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local StrokeCodec  = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("StrokeCodec"))

local CollectingController = {}
CollectingController.__index = CollectingController

function CollectingController.new(scene, refs, canvasController, canvasRemote)
	return setmetatable({
		scene            = scene,
		refs             = refs,
		canvasController = canvasController,
		canvasRemote     = canvasRemote,
	}, CollectingController)
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

function CollectingController:Enter()
	self.scene:HideAllUI()
	self.scene:ShowPhaseGui(Constants.TEXT_PHASE_COLLECT, "")
	if self.refs.SidebarGui then self.refs.SidebarGui.Enabled = true end
	self.canvasController:ResetLastPosition()
	self.canvasController:SetDrawingEnabled(false)
	local strokes = self.canvasController:GetStrokes()
	self.canvasController:ClearCanvas()
	task.spawn(function()
		self.canvasRemote:FireServer(StrokeCodec.encode(strokes))
	end)
end

function CollectingController:Exit() end

return CollectingController
