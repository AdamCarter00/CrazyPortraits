local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))

local RevealIntroController = {}
RevealIntroController.__index = RevealIntroController

function RevealIntroController.new(scene, refs, revealEvents)
	return setmetatable({
		scene        = scene,
		refs         = refs,
		revealEvents = revealEvents,
	}, RevealIntroController)
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

function RevealIntroController:Enter()
	self.scene:HideAllUI()
	self.scene:SetRevealCamera()
	self.scene:ShowPhaseGui(Constants.TEXT_PHASE_REVEAL_INTRO, "")

	self.revealEvents.IntroStarted:Fire()
end

function RevealIntroController:Exit()
end

return RevealIntroController
