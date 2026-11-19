local DrawRenderer = {}

--------------------------------------------------------------------------------
-- Renders a stroke list onto a given EditableImage.
-- Used by both the server-fed display path (reveal / gallery / admin) and,
-- through the shared dab primitives below, by the client canvas (CanvasController).
--
-- Wire stroke format (StrokeCodec.decode / StrokeValidator output):
--   { s=0.01, r=0, g=0, b=0, p={x1,y1,x2,y2,...}, f=true/nil }
--
-- p: flat integer list (0-511 range), consecutive pairs are (x, y).
--
-- IMPORTANT: line strokes are drawn with the exact same EditableImage:DrawCircle
-- primitive the live client canvas uses (drawPoint / interpolateLine below). This
-- guarantees the display produces pixel-identical boundaries to the drawer's own
-- canvas, so a flood fill that is contained on the client is also contained here
-- (a manual rasterizer could leave a 1px gap on a thin diagonal outline that the
-- fill would then leak through).
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants         = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local FloodFill         = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FloodFill"))

local CANVAS_W    = Constants.CANVAS_SIZE
local CANVAS_H    = Constants.CANVAS_SIZE
local CANVAS_SIZE = Vector2.new(CANVAS_W, CANVAS_H)

local function brushPixels(size)
	return math.max(1, math.round(CANVAS_W * size))
end

--------------------------------------------------------------------------------
-- Shared dab primitives (also used by CanvasController for live drawing + undo).
--
-- These MUST stay the single definition of "what pixels a brush dab produces".
-- Both the client canvas and the display image are EditableImage instances of
-- the same size, so the same DrawCircle call yields the same pixels on either.
--------------------------------------------------------------------------------

function DrawRenderer.drawPoint(image, pixel, pixelSize, color)
	local radius = pixelSize / 2
	image:DrawCircle(pixel, radius, color, 0, Enum.ImageCombineType.Overwrite)
end

function DrawRenderer.interpolateLine(image, from, to, pixelSize, color)
	local dx    = math.abs(to.X - from.X)
	local dy    = math.abs(to.Y - from.Y)
	-- Cap at canvas width so a corrupt coordinate can never spin this loop tens
	-- of thousands of times (no-op for valid strokes; they never exceed CANVAS_W).
	local steps = math.min(math.max(dx, dy), CANVAS_W)
	if steps == 0 then
		DrawRenderer.drawPoint(image, to, pixelSize, color)
		return
	end
	for i = 0, steps do
		local t  = i / steps
		local ix = math.round(from.X + (to.X - from.X) * t)
		local iy = math.round(from.Y + (to.Y - from.Y) * t)
		DrawRenderer.drawPoint(image, Vector2.new(ix, iy), pixelSize, color)
	end
end

-- Reused white-fill buffer for clearing the canvas.
local CANVAS_BUF = buffer.create(CANVAS_W * CANVAS_H * 4)

function DrawRenderer.clear(ei)
	buffer.fill(CANVAS_BUF, 0, 0xFF, CANVAS_W * CANVAS_H * 4)
	ei:WritePixelsBuffer(Vector2.zero, CANVAS_SIZE, CANVAS_BUF)
end

-- Writes only the (minX,minY)..(maxX,maxY) inclusive sub-region of the full
-- CANVAS_W*CANVAS_H RGBA srcBuf back to the EditableImage. Packs the rect rows
-- contiguously into a buffer sized EXACTLY rectW*rectH*4 — WritePixelsBuffer
-- requires the buffer length to equal size.X*size.Y*4, so an oversized scratch
-- buffer is rejected. The upload stays proportional to the painted area.
local function writeDirtyRect(ei, srcBuf, minX, minY, maxX, maxY)
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
	ei:WritePixelsBuffer(Vector2.new(minX, minY), Vector2.new(rectW, rectH), dirty)
end

--------------------------------------------------------------------------------
-- render(ei, strokes)
--
-- Replays the stroke list onto the EditableImage in order, starting from a clean
-- white canvas. Line strokes go through DrawCircle (shared primitive); fill
-- strokes read the current pixels back, flood fill from the seed, and write back
-- -- exactly mirroring CanvasController's own replay so the result is identical.
--
-- Consecutive fills are batched: a run of adjacent fill strokes shares a single
-- ReadPixelsBuffer and a single WritePixelsBuffer of their combined dirty rect.
-- The run is flushed before the next line stroke (or at the end) so draw order —
-- and therefore the final image — stays pixel-identical to per-fill replay. Line
-- strokes are untouched (still DrawCircle), preserving boundary pixels exactly.
--------------------------------------------------------------------------------

local DAB_YIELD_BUDGET = Constants.RENDER_DAB_YIELD_BUDGET

function DrawRenderer.render(ei, strokes)
	if not strokes or #strokes == 0 then
		DrawRenderer.clear(ei)
		return
	end

	-- Start from a clean white canvas.
	DrawRenderer.clear(ei)

	-- Active fill-run state. fillBuf is non-nil while a run is open; the dirty
	-- rect accumulates every fill in the run, then flushes as one sub-region write.
	local fillBuf = nil
	local dMinX, dMinY, dMaxX, dMaxY = 0, 0, 0, 0

	local function flushFillRun()
		if fillBuf then
			if dMaxX >= 0 then
				writeDirtyRect(ei, fillBuf, dMinX, dMinY, dMaxX, dMaxY)
			end
			fillBuf = nil
		end
	end

	-- Dab budget: a dense drawing (or several gallery slots replayed back-to-back)
	-- can issue millions of DrawCircle calls; without yielding, one resumption point
	-- exhausts its execution time and the render aborts mid-image (the 30s timeout).
	-- We yield at stroke boundaries — never inside an open fill run — so stroke order
	-- and the final pixels stay identical to a single-pass replay.
	local dabsSinceYield = 0

	for _, stroke in ipairs(strokes) do
		local p     = stroke.p
		local count = #p

		if stroke.f then
			-- Flood fill replays against the canvas state at this point in the
			-- stroke order (same as the live client). p is flat: p[1]=x, p[2]=y.
			if count >= 2 then
				if not fillBuf then
					fillBuf = ei:ReadPixelsBuffer(Vector2.zero, CANVAS_SIZE)
					dMinX, dMinY, dMaxX, dMaxY = CANVAS_W, CANVAS_H, -1, -1
				end
				local r255 = math.round(stroke.r * 255)
				local g255 = math.round(stroke.g * 255)
				local b255 = math.round(stroke.b * 255)
				local minX, minY, maxX, maxY = FloodFill.fill(fillBuf, p[1], p[2], r255, g255, b255)
				if minX then
					if minX < dMinX then dMinX = minX end
					if minY < dMinY then dMinY = minY end
					if maxX > dMaxX then dMaxX = maxX end
					if maxY > dMaxY then dMaxY = maxY end
				end
			end
		else
			if count < 2 then continue end
			-- A line ends the current fill run: flush its pixels first so this
			-- line draws on top of them, matching the original stroke order.
			flushFillRun()

			local pixelSize = brushPixels(stroke.s)
			local color     = Color3.new(stroke.r, stroke.g, stroke.b)

			local prev = Vector2.new(p[1], p[2])
			DrawRenderer.drawPoint(ei, prev, pixelSize, color)
			dabsSinceYield += 1
			for i = 3, count - 1, 2 do
				local cur = Vector2.new(p[i], p[i + 1])
				DrawRenderer.interpolateLine(ei, prev, cur, pixelSize, color)
				-- interpolateLine issues ~max(dx,dy) dabs (capped at CANVAS_W); mirror
				-- that here to track work without changing the primitive's signature.
				dabsSinceYield += math.min(math.max(math.abs(cur.X - prev.X), math.abs(cur.Y - prev.Y)), CANVAS_W) + 1
				prev = cur
			end
		end

		-- Yield between strokes once enough dabs have accumulated, but never while a
		-- fill run is open (fillBuf ~= nil) so the read/fill/write stays atomic and
		-- the final pixels match a single-pass replay. Only line strokes add dabs,
		-- and each one flushes any open run first, so the budget is reached with
		-- fillBuf == nil anyway; the guard just makes that invariant explicit.
		if fillBuf == nil and dabsSinceYield >= DAB_YIELD_BUDGET then
			dabsSinceYield = 0
			task.wait()
		end
	end

	-- Flush a trailing fill run (drawing ended on one or more fills).
	flushFillRun()
end

return DrawRenderer
