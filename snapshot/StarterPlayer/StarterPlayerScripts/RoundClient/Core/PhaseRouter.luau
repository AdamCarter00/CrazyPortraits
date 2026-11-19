local PhaseRouter = {}
PhaseRouter.__index = PhaseRouter

function PhaseRouter.new()
	return setmetatable({ _controllers = {}, _current = nil }, PhaseRouter)
end

function PhaseRouter:Register(phase, controller)
	self._controllers[phase] = controller
end

function PhaseRouter:RegisterMany(map)
	for phase, ctrl in pairs(map) do
		self:Register(phase, ctrl)
	end
end

function PhaseRouter:Dispatch(phase, ...)
	local ctrl = self._controllers[phase]
	if not ctrl then
		warn("[PhaseRouter] unknown phase:", phase)
		return
	end

	if self._current and self._current ~= ctrl then
		self._current:Exit()
	end

	self._current = ctrl
	ctrl:Enter(...)
end

return PhaseRouter
