local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Drawing = require(Shared.Config.Drawing)
local FloodFill = require(Shared.Drawing.FloodFill)
local DrawRenderer = require(script.Parent.DrawRenderer)

local SIZE = Drawing.CanvasSize
local CANVAS_VECTOR = Vector2.new(SIZE, SIZE)
local WHITE = Color3.new(1, 1, 1)
local BYTES = SIZE * SIZE * 4

local drawPoint = DrawRenderer.drawPoint
local interpolateLine = DrawRenderer.interpolateLine

local CanvasView = {}
CanvasView.__index = CanvasView

local function brushPixels(size)
	return math.max(1, math.round(SIZE * size))
end

function CanvasView.new(label)
	local self = setmetatable({}, CanvasView)
	self.label = label
	self.image = AssetService:CreateEditableImage({ Size = CANVAS_VECTOR })
	label.ImageContent = Content.fromObject(self.image)
	label.ScaleType = Enum.ScaleType.Stretch
	self.scratch = buffer.create(BYTES)
	self.lastPixel = nil
	self:clear()
	return self
end

function CanvasView:clear()
	self.image:DrawRectangle(Vector2.zero, CANVAS_VECTOR, WHITE, 0, Enum.ImageCombineType.Overwrite)
	self.lastPixel = nil
end

function CanvasView:toCanvas(x, y)
	local pos = self.label.AbsolutePosition
	local size = self.label.AbsoluteSize
	return Vector2.new(
		math.clamp(math.floor((x - pos.X) / size.X * SIZE), 0, SIZE - 1),
		math.clamp(math.floor((y - pos.Y) / size.Y * SIZE), 0, SIZE - 1)
	)
end

function CanvasView:contains(x, y)
	local pos = self.label.AbsolutePosition
	local size = self.label.AbsoluteSize
	return x >= pos.X and x <= pos.X + size.X and y >= pos.Y and y <= pos.Y + size.Y
end

function CanvasView:endLine()
	self.lastPixel = nil
end

-- stroke: Session'in ic bicimi (renk r/g/b 0-1, silgi beyaz yazilir).
function CanvasView:dab(stroke, pixel)
	local size = brushPixels(stroke.s)
	local color = Color3.new(stroke.r, stroke.g, stroke.b)
	if self.lastPixel then
		interpolateLine(self.image, self.lastPixel, pixel, size, color)
	else
		drawPoint(self.image, pixel, size, color)
	end
	self.lastPixel = pixel
end

local function writeRect(image, source, minX, minY, maxX, maxY)
	local width = maxX - minX + 1
	local height = maxY - minY + 1
	local stride = SIZE * 4
	local rect = buffer.create(width * height * 4)
	for row = 0, height - 1 do
		buffer.copy(rect, row * width * 4, source, (minY + row) * stride + minX * 4, width * 4)
	end
	image:WritePixelsBuffer(Vector2.new(minX, minY), Vector2.new(width, height), rect)
end

function CanvasView:fill(stroke)
	local seed = stroke.p[1]
	local pixels = self.image:ReadPixelsBuffer(Vector2.zero, CANVAS_VECTOR)
	local minX, minY, maxX, maxY = FloodFill.fill(
		pixels, seed[1], seed[2],
		math.round(stroke.r * 255), math.round(stroke.g * 255), math.round(stroke.b * 255)
	)
	if minX then
		writeRect(self.image, pixels, minX, minY, maxX, maxY)
	end
end

function CanvasView:redraw(strokes)
	buffer.fill(self.scratch, 0, 0xFF, BYTES)
	self.image:WritePixelsBuffer(Vector2.zero, CANVAS_VECTOR, self.scratch)
	self.lastPixel = nil
	for _, stroke in strokes do
		if stroke.isFill then
			self:fill(stroke)
		else
			local points = stroke.p
			if #points > 0 then
				local size = brushPixels(stroke.s)
				local color = Color3.new(stroke.r, stroke.g, stroke.b)
				local previous = Vector2.new(points[1][1], points[1][2])
				drawPoint(self.image, previous, size, color)
				for i = 2, #points do
					local current = Vector2.new(points[i][1], points[i][2])
					interpolateLine(self.image, previous, current, size, color)
					previous = current
				end
			end
		end
	end
end

return CanvasView
