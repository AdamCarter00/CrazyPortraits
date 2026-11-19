local CanvasController = {}

--------------------------------------------------------------------------------
-- Services & Constants
--------------------------------------------------------------------------------

local AssetService      = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants         = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local StrokeCodec       = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("StrokeCodec"))
local FloodFill         = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FloodFill"))
local DrawRenderer      = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("DrawRenderer"))

local CANVAS_W    = Constants.CANVAS_SIZE
local CANVAS_H    = Constants.CANVAS_SIZE
local CANVAS_SIZE = Vector2.new(CANVAS_W, CANVAS_H)
local WHITE       = Color3.new(1, 1, 1)

-- Palette index 0 (first VALID_COLORS entry) as a Color3 — the default brush
-- color, so it matches the encoded palette exactly (see Init).
local DEFAULT_COLOR = Color3.fromRGB(
	Constants.VALID_COLORS[1].r,
	Constants.VALID_COLORS[1].g,
	Constants.VALID_COLORS[1].b
)

local BRUSH_NAME_TO_SIZE = {
	["0.01"] = 0.01, ["0.04"] = 0.04, ["0.08"] = 0.08,
}

local function brushPixels(size)
	return math.max(1, math.round(CANVAS_W * size))
end

--------------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------------

function CanvasController:Init(canvasLabel)
	if not canvasLabel then
		warn("[CanvasController] Init: canvasLabel is nil - drawing will not work")
		return
	end
	self.canvasLabel  = canvasLabel
	self.canDraw      = false
	-- Default to the first palette color (not pure black 0,0,0) so a stroke drawn
	-- before any color is picked encodes to a real VALID_COLORS index and looks
	-- the same locally and in the reveal. DEFAULT_COLOR is the palette's index 0.
	self.currentColor = DEFAULT_COLOR
	self.currentSize  = Constants.DEFAULT_BRUSH_SIZE
	self.lastPixel    = nil
	self.eraserActive = false
	self.strokes      = {}
	self.currentStroke = nil

	-- Analytics counters (monotonic within a round; reset via ResetProgress).
	-- strokesDrawn counts every brush stroke + flood fill started; undoCount
	-- counts undo presses. Reported to the server during the drawing phase.
	self.strokesDrawn = 0
	self.undoCount    = 0

	-- Live pixel budget. Counts every point committed to a stroke (one per Draw
	-- dab, one per fill seed). When it reaches MAX_TOTAL_PIXELS, further drawing
	-- is blocked locally so what the player sees on their own canvas is exactly
	-- what survives encoding (StrokeCodec.encode / StrokeValidator also cap at
	-- MAX_TOTAL_PIXELS). Counting raw points (>= the deduped count encode uses)
	-- means the local cap is reached no later than the encode cap, so the reveal
	-- can never show LESS than the local canvas. Reset in ClearCanvas.
	self.totalPixels  = 0

	self.editableImage = AssetService:CreateEditableImage({ Size = CANVAS_SIZE })
	self.canvasLabel.ImageContent  = Content.fromObject(self.editableImage)
	self.canvasLabel.ScaleType     = Enum.ScaleType.Stretch
	self.canvasLabel.ResampleMode  = Enum.ResamplerMode.Default

	self:ClearCanvas()
end

--------------------------------------------------------------------------------
-- State Setters
--------------------------------------------------------------------------------

function CanvasController:SetDrawingEnabled(enabled)
	self.canDraw = enabled
	if not enabled then
		self.lastPixel     = nil
		self.currentStroke = nil
	end
end

function CanvasController:SetColor(color3)
	self.currentColor = color3
	self.eraserActive = false
end

function CanvasController:SetBrushSize(name)
	local size = BRUSH_NAME_TO_SIZE[tostring(name)]
	if size then self.currentSize = size end
end

function CanvasController:ActivateEraser()
	self.eraserActive = true
	self.currentColor = WHITE
end

--------------------------------------------------------------------------------
-- Canvas Helpers
--------------------------------------------------------------------------------

function CanvasController:ClearCanvas()
	self.editableImage:DrawRectangle(
		Vector2.new(0, 0), CANVAS_SIZE, WHITE, 0,
		Enum.ImageCombineType.Overwrite
	)
	self.strokes       = {}
	self.currentStroke = nil
	self.lastPixel     = nil
	self.totalPixels   = 0
end

function CanvasController:ScreenToCanvas(mouseX, mouseY)
	local pos  = self.canvasLabel.AbsolutePosition
	local size = self.canvasLabel.AbsoluteSize
	local px   = math.clamp(math.floor((mouseX - pos.X) / size.X * CANVAS_W), 0, CANVAS_W - 1)
	local py   = math.clamp(math.floor((mouseY - pos.Y) / size.Y * CANVAS_H), 0, CANVAS_H - 1)
	return Vector2.new(px, py)
end

--------------------------------------------------------------------------------
-- Low-Level Drawing
--------------------------------------------------------------------------------

-- Live drawing primitives live in DrawRenderer so the client canvas and the
-- shared display/gallery render produce pixel-identical strokes (same DrawCircle
-- dab + interpolation). Aliased here for brevity; both live drawing and the
-- post-Undo redraw go through them.
local drawPoint       = DrawRenderer.drawPoint
local interpolateLine = DrawRenderer.interpolateLine

-- Reused white-fill buffer for clearing the canvas during redraw.
local CANVAS_BUF = buffer.create(CANVAS_W * CANVAS_H * 4)

-- writeDirtyRect(image, srcBuf, minX, minY, maxX, maxY)
--   Writes only the (minX,minY)..(maxX,maxY) inclusive sub-region of the full
--   CANVAS_W*CANVAS_H RGBA srcBuf back to the EditableImage. Packs the rect's
--   rows contiguously into a buffer sized EXACTLY rectW*rectH*4 — WritePixelsBuffer
--   requires the buffer length to equal size.X*size.Y*4, so an oversized scratch
--   buffer is rejected. The upload is still proportional to the painted area, not
--   the whole 1 MB canvas.
local function writeDirtyRect(image, srcBuf, minX, minY, maxX, maxY)
	local rectW    = maxX - minX + 1
	local rectH    = maxY - minY + 1
	local stride   = CANVAS_W * 4
	local rowBytes = rectW * 4
	local dirty    = buffer.create(rectW * rectH * 4)
	local dstOff   = 0
	for row = 0, rectH - 1 do
		local srcOff = (minY + row) * stride + minX * 4
		buffer.copy(dirty, dstOff, srcBuf, srcOff, rowBytes)
		dstOff += rowBytes
	end
	image:WritePixelsBuffer(Vector2.new(minX, minY), Vector2.new(rectW, rectH), dirty)
end

-- Redraws every stroke from scratch (used after Undo). Line strokes are drawn
-- with the exact same path as live drawing (interpolateLine + DrawCircle) so the
-- result is pixel-identical to what was drawn on the canvas. Fill strokes are
-- replayed against the real canvas state at that point in the stroke order:
-- the canvas is read into a buffer, the flood fill is reapplied from the seed
-- pixel, then written back — matching how the fill behaved when first painted.
local function redrawAllStrokes(image, strokes)
	-- Start from a clean white canvas.
	buffer.fill(CANVAS_BUF, 0, 0xFF, CANVAS_W * CANVAS_H * 4)
	image:WritePixelsBuffer(Vector2.zero, CANVAS_SIZE, CANVAS_BUF)

	for _, stroke in ipairs(strokes) do
		if stroke.isFill then
			local p = stroke.p
			if p and #p >= 1 then
				-- These are the controller's own internal strokes, so the seed is a
				-- nested pair p[1] = {x, y} (NOT the flat wire layout DrawRenderer
				-- consumes). Read it as nested here.
				local bx, by = p[1][1], p[1][2]
				local r255 = math.round(stroke.r * 255)
				local g255 = math.round(stroke.g * 255)
				local b255 = math.round(stroke.b * 255)
				local buf  = image:ReadPixelsBuffer(Vector2.zero, CANVAS_SIZE)
				local minX, minY, maxX, maxY = FloodFill.fill(buf, bx, by, r255, g255, b255)
				if minX then
					writeDirtyRect(image, buf, minX, minY, maxX, maxY)
				end
			end
		else
			local pixelSize = brushPixels(stroke.s)
			local color     = Color3.new(stroke.r, stroke.g, stroke.b)
			local pts       = stroke.p
			if #pts > 0 then
				local prev = Vector2.new(pts[1][1], pts[1][2])
				drawPoint(image, prev, pixelSize, color)
				for i = 2, #pts do
					local cur = Vector2.new(pts[i][1], pts[i][2])
					interpolateLine(image, prev, cur, pixelSize, color)
					prev = cur
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Stroke Lifecycle
--------------------------------------------------------------------------------

-- Removes the oldest stroke (the undo-history overflow case) and subtracts its
-- pixels from the live budget so a long session that keeps dropping old strokes
-- can keep drawing. Pairs with every place that enforces MAX_UNDO_STEPS.
function CanvasController:dropOldestStroke()
	local oldest = self.strokes[1]
	if not oldest then return end
	self.totalPixels = math.max(0, self.totalPixels - #oldest.p)
	table.remove(self.strokes, 1)
end

function CanvasController:startStroke()
	if not self.canDraw then return end
	if self.currentStroke and #self.currentStroke.p > 0 then
		self:ResetLastPosition()
	end
	self.strokesDrawn += 1
	self.currentStroke = {
		s        = self.currentSize,
		r        = self.currentColor.R,
		g        = self.currentColor.G,
		b        = self.currentColor.B,
		isEraser = self.eraserActive,
		p        = {},
	}
	self.lastPixel = nil
end

function CanvasController:ResetLastPosition()
	self.lastPixel = nil
	if self.currentStroke and #self.currentStroke.p > 0 then
		if #self.strokes >= Constants.MAX_UNDO_STEPS then
			self:dropOldestStroke()
		end
		table.insert(self.strokes, self.currentStroke)
	end
	self.currentStroke = nil
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------

function CanvasController:Draw(mouseX, mouseY)
	if not self.canDraw then return end
	if not self.currentStroke then return end

	-- Out of pixel budget: stop drawing entirely (no canvas dab, no recorded
	-- point) so the local canvas never contains pixels that encoding would drop.
	if self.totalPixels >= Constants.MAX_TOTAL_PIXELS then return end

	local pixel     = self:ScreenToCanvas(mouseX, mouseY)
	local pixelSize = brushPixels(self.currentSize)
	local color     = self.currentColor

	if self.lastPixel then
		interpolateLine(self.editableImage, self.lastPixel, pixel, pixelSize, color)
	else
		drawPoint(self.editableImage, pixel, pixelSize, color)
	end
	self.lastPixel = pixel

	table.insert(self.currentStroke.p, { pixel.X, pixel.Y })
	self.totalPixels += 1

	if #self.currentStroke.p >= Constants.MAX_PIXELS_PER_STROKE then
		if #self.strokes >= Constants.MAX_UNDO_STEPS then
			self:dropOldestStroke()
		end
		table.insert(self.strokes, self.currentStroke)

		-- Splitting a maxed-out stroke starts a new stroke, so count it like any
		-- other started stroke (keeps strokesDrawn consistent for the quit-log
		-- analytics).
		self.strokesDrawn += 1
		self.currentStroke = {
			s        = self.currentSize,
			r        = self.currentColor.R,
			g        = self.currentColor.G,
			b        = self.currentColor.B,
			isEraser = self.eraserActive,
			p        = {},
		}
	end
end

--------------------------------------------------------------------------------
-- Undo
--------------------------------------------------------------------------------

function CanvasController:Undo()
	if #self.strokes == 0 then return end
	self.undoCount += 1
	local removed = table.remove(self.strokes, #self.strokes)
	if removed then
		self.totalPixels = math.max(0, self.totalPixels - #removed.p)
	end
	redrawAllStrokes(self.editableImage, self.strokes)
end

--------------------------------------------------------------------------------
-- Flood Fill
--------------------------------------------------------------------------------

function CanvasController:FloodFill(mouseX, mouseY)
	if not self.canDraw then return end

	-- A fill records one seed pixel (p = {{bx,by}}), so it costs 1 of the budget.
	-- Block it when the budget is exhausted, matching the Draw guard, so a fill
	-- that wouldn't survive encoding never lands on the local canvas either.
	if self.totalPixels >= Constants.MAX_TOTAL_PIXELS then return end

	local seed   = self:ScreenToCanvas(mouseX, mouseY)
	local image  = self.editableImage
	local buf    = image:ReadPixelsBuffer(Vector2.zero, CANVAS_SIZE)

	local bx, by = seed.X, seed.Y
	if bx < 0 or bx >= CANVAS_W or by < 0 or by >= CANVAS_H then
		warn("[CanvasController] FloodFill: seed out of bounds", bx, by)
		return
	end
	local dr255   = math.round(self.currentColor.R * 255)
	local dg255   = math.round(self.currentColor.G * 255)
	local db255   = math.round(self.currentColor.B * 255)

	-- Write back only the painted rectangle (most fills cover a small region).
	-- nil rect means the fill was a no-op (seed already this color); skip the
	-- write but still record the stroke so undo/analytics stay consistent.
	local minX, minY, maxX, maxY = FloodFill.fill(buf, bx, by, dr255, dg255, db255)
	if minX then
		writeDirtyRect(image, buf, minX, minY, maxX, maxY)
	end

	self.strokesDrawn += 1

	local stroke = {
		s        = self.currentSize,
		r        = self.currentColor.R,
		g        = self.currentColor.G,
		b        = self.currentColor.B,
		isEraser = false,
		isFill   = true,
		p        = { {bx, by} },
	}
	if #self.strokes >= Constants.MAX_UNDO_STEPS then
		self:dropOldestStroke()
	end
	table.insert(self.strokes, stroke)
	self.totalPixels += 1
end

--------------------------------------------------------------------------------
-- Get Canvas Data
--------------------------------------------------------------------------------

function CanvasController:GetStrokes()
	return self.strokes
end

--------------------------------------------------------------------------------
-- Progress Counters (analytics)
--------------------------------------------------------------------------------

function CanvasController:ResetProgress()
	self.strokesDrawn = 0
	self.undoCount    = 0
end

function CanvasController:GetProgress()
	return self.strokesDrawn, self.undoCount
end

function CanvasController:GetCanvasData()
	return StrokeCodec.encode(self.strokes)
end

--------------------------------------------------------------------------------

return CanvasController
