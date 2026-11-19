local InputController = {}

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

function InputController:SetCanvas(canvas)
	self.canvas = canvas
end

function InputController:SetFillMode(enabled)
	self.fillModeActive = enabled
end

--------------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------------

function InputController:Init(canvasController, canvas)
	self.canvasController = canvasController
	self.canvas           = canvas
	self.isPressed        = false
	self.fillModeActive   = false

	local UserInputService = game:GetService("UserInputService")

	local function isInsideCanvas(x, y)
		local pos  = self.canvas.AbsolutePosition
		local size = self.canvas.AbsoluteSize
		return x >= pos.X and x <= pos.X + size.X
			and y >= pos.Y and y <= pos.Y + size.Y
	end

	--------------------------------------------------------------------------------
	-- Mouse Input
	--------------------------------------------------------------------------------

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

		local x, y  = input.Position.X, input.Position.Y
		local inside = isInsideCanvas(x, y)

		if self.fillModeActive then
			if inside then
				self.canvasController:FloodFill(x, y)
			end
			return
		end

		self.isPressed = true
		if inside then
			self.canvasController:startStroke()
		end
		self:TryDraw(x, y, inside)
	end)

	UserInputService.InputEnded:Connect(function(input, _gameProcessed)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		self.isPressed = false
		self.canvasController:ResetLastPosition()
	end)

	UserInputService.InputChanged:Connect(function(input, _gameProcessed)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
		local x, y = input.Position.X, input.Position.Y
		self:TryDraw(x, y, isInsideCanvas(x, y))
	end)

	--------------------------------------------------------------------------------
	-- Touch Input
	--------------------------------------------------------------------------------

	UserInputService.TouchStarted:Connect(function(touch, gameProcessed)
		if gameProcessed then return end

		local x, y  = touch.Position.X, touch.Position.Y
		local inside = isInsideCanvas(x, y)

		if self.fillModeActive then
			if inside then
				self.canvasController:FloodFill(x, y)
			end
			return
		end

		self.isPressed = true
		if inside then
			self.canvasController:startStroke()
		end
		self:TryDraw(x, y, inside)
	end)

	UserInputService.TouchMoved:Connect(function(touch, _gameProcessed)
		local x, y = touch.Position.X, touch.Position.Y
		self:TryDraw(x, y, isInsideCanvas(x, y))
	end)

	UserInputService.TouchEnded:Connect(function()
		self.isPressed = false
		self.canvasController:ResetLastPosition()
	end)
end

--------------------------------------------------------------------------------
-- Draw Gate
--------------------------------------------------------------------------------

function InputController:TryDraw(mouseX, mouseY, inside)
	if self.isPressed and inside then
		self.canvasController:Draw(mouseX, mouseY)
	end
end

--------------------------------------------------------------------------------

return InputController
