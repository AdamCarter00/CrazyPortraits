local RevealController = {}
RevealController.__index = RevealController

function RevealController.new(scene, refs, revealEvents, uiController, frameController)
	return setmetatable({
		scene           = scene,
		refs            = refs,
		revealEvents    = revealEvents,
		uiController    = uiController,
		frameController = frameController,
		_currentOwner   = nil,
	}, RevealController)
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

function RevealController:Enter(playerName, theme, drawingBuffer)
	if self._currentOwner then
		self.revealEvents.DrawingFinished:Fire(self._currentOwner)
	end

	self.uiController:HideReportOverlay()
	self.scene:HideAllUI()
	self.refs.EmojiGui.Enabled = true
	-- The drawing fills the screen during the reveal, so both the phase label and the
	-- sidebar are hidden; CleanRoundController reopens them when the round ends.
	self.scene:HidePhaseGui()
	if self.refs.SidebarGui then self.refs.SidebarGui.Enabled = false end

	self.scene:RenderDrawing(drawingBuffer)
	-- Show the owner's equipped frame border on the single "Frame" ImageLabel (default / no
	-- special frame hides it). The reveal shows no caption.
	self.frameController:Apply(self.frameController:FrameNameFor(playerName))

	self._currentOwner = playerName
	self.revealEvents.DrawingShown:Fire(playerName, theme, drawingBuffer)
end

function RevealController:Exit()
	if self._currentOwner then
		self.revealEvents.DrawingFinished:Fire(self._currentOwner)
		self._currentOwner = nil
	end
	self.frameController:Clear()
	self.revealEvents.RevealEnded:Fire()
end

return RevealController
