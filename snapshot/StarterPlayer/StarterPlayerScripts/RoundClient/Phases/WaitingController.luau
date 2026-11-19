local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))

local WaitingController = {}
WaitingController.__index = WaitingController

function WaitingController.new(scene, refs)
	return setmetatable({
		scene  = scene,
		refs   = refs,
		_token = 0,
	}, WaitingController)
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

function WaitingController:Enter(startTime, duration)
	self.scene:HideAllUI()

	self._token += 1

	if typeof(startTime) == "number" and typeof(duration) == "number" then
		self:_startCountdown(startTime, duration, self._token)
	else
		self.scene:ShowPhaseGui(Constants.TEXT_WAITING, "")
	end
end

function WaitingController:Exit()
	self._token += 1
end

--------------------------------------------------------------------------------
-- Countdown
--------------------------------------------------------------------------------

function WaitingController:_startCountdown(startTime, duration, token)
	self.scene:ShowPhaseGui(Constants.TEXT_ROUND_STARTING, "")
	task.spawn(function()
		while self._token == token do
			local elapsed   = workspace:GetServerTimeNow() - startTime
			local remaining = math.max(0, math.ceil(duration - elapsed))
			self.scene:SetPhaseInfo(Constants.TEXT_ROUND_STARTING, "in " .. remaining .. "s")
			if remaining <= 0 then break end
			task.wait(0.25)
		end
	end)
end

return WaitingController
