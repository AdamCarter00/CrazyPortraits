local StrokeCodec = {}

--[[
Wire format (binary buffer):
  Per stroke header — 5 bytes:
    [0]   uint8  size index  (0 = 0.01, 1 = 0.04, 2 = 0.08)
    [1]   uint8  color index (0-based, Drawing.Colors order)
    [2]   uint8  flags       (bit 0 = isFill)
    [3-4] uint16 pixel count (little-endian)
  Per pixel — 4 bytes:
    [0-1] uint16 x (0-511, little-endian)
    [2-3] uint16 y (0-511, little-endian)

]]

local Drawing = require(script.Parent.Parent.Config.Drawing)

local SIZE_TO_IDX = {}
local IDX_TO_SIZE = {}
local SIZE_VALUES = {}
for i, size in Drawing.BrushSizes do
	SIZE_TO_IDX[size] = i - 1
	IDX_TO_SIZE[i - 1] = size
	table.insert(SIZE_VALUES, { size, i - 1 })
end

-- Map an arbitrary brush size to a valid size index. An exact match wins;
-- otherwise we snap to the NEAREST valid size instead of dropping the stroke, so
-- a brush size that drifted off the canonical values (float rounding, future
-- tweak) still renders rather than vanishing from the reveal. Used by encode.
local function nearestSizeIdx(s)
	local exact = SIZE_TO_IDX[s]
	if exact ~= nil then return exact end
	if type(s) ~= "number" then return 0 end  -- default to smallest
	local bestIdx, bestDist = 0, math.huge
	for _, pair in ipairs(SIZE_VALUES) do
		local dist = math.abs(s - pair[1])
		if dist < bestDist then
			bestDist, bestIdx = dist, pair[2]
		end
	end
	return bestIdx
end

-- color index lookup built from VALID_COLORS
local COLOR_TO_IDX = {}
local IDX_TO_COLOR = {}
for i, c in ipairs(Drawing.Colors) do
	local key = c.r .. "," .. c.g .. "," .. c.b
	COLOR_TO_IDX[key] = i - 1
	IDX_TO_COLOR[i - 1] = c
end

-- Convert 0-1 float to nearest VALID_COLORS index. Returns 0 (black) if not found.
local function colorToIdx(r, g, b)
	local key = math.round(r * 255) .. "," .. math.round(g * 255) .. "," .. math.round(b * 255)
	return COLOR_TO_IDX[key] or 0
end

--------------------------------------------------------------------------------
-- encode(strokes) → buffer
--
-- Accepts two stroke formats:
--   CanvasController internal: { s, r, g, b, isEraser, isFill, p={{x,y},...} }
--   DrawRenderer wire:         { s, r, g, b, f=bool,   p={x1,y1,x2,y2,...}  }
--------------------------------------------------------------------------------

function StrokeCodec.encode(strokes)
	local maxStrokes     = Drawing.MaxStrokes
	local maxPxPerStroke = Drawing.MaxPixelsPerStroke
	local maxTotal       = Drawing.MaxTotalPixels

	local entries = {}
	local totalPx = 0

	for i, stroke in ipairs(strokes) do
		if i > maxStrokes then break end
		if totalPx >= maxTotal then break end

		-- Snap to the nearest valid brush size instead of dropping the stroke when
		-- stroke.s is not exactly a canonical value (prevents a silently missing
		-- stroke in the reveal).
		local sizeIdx = nearestSizeIdx(stroke.s)

		local r = stroke.r
		local g = stroke.g
		local b = stroke.b
		if stroke.isEraser then r, g, b = 1, 1, 1 end

		local colorIdx = colorToIdx(r, g, b)
		local isFill   = stroke.isFill == true or stroke.f == true

		-- Read the first (x, y) of a stroke regardless of which point layout it
		-- uses: internal is {{x,y},...}, wire is {x1,y1,x2,y2,...}.
		local p = stroke.p
		local function firstPoint()
			if type(p[1]) == "table" then return p[1][1], p[1][2] end
			return p[1], p[2]
		end

		local pts      = {}
		local pxBudget = math.min(maxPxPerStroke, maxTotal - totalPx)

		if isFill then
			-- A fill carries only its seed point; emit exactly that one pixel and
			-- skip the line dedup loop entirely (keeps the fill format unambiguous).
			local sx, sy = firstPoint()
			if sx ~= nil and sy ~= nil and pxBudget >= 1 then
				pts[1] = sx
				pts[2] = sy
			end
		else
			-- Line stroke: flatten its points, dropping consecutive duplicates and
			-- respecting the per-stroke pixel budget.
			local prevX, prevY = -1, -1
			if type(p[1]) == "table" then
				-- internal format: array of {x, y}
				for _, pt in ipairs(p) do
					local px, py = pt[1], pt[2]
					if px ~= prevX or py ~= prevY then
						prevX, prevY = px, py
						pts[#pts + 1] = px
						pts[#pts + 1] = py
						if #pts / 2 >= pxBudget then break end
					end
				end
			else
				-- wire format: flat list x1,y1,x2,y2,...
				local count = #p
				local j = 1
				while j < count and #pts / 2 < pxBudget do
					local px, py = p[j], p[j + 1]
					if px ~= prevX or py ~= prevY then
						prevX, prevY = px, py
						pts[#pts + 1] = px
						pts[#pts + 1] = py
					end
					j += 2
				end
			end
		end

		if #pts == 0 and not isFill then continue end

		local pxCount = math.floor(#pts / 2)
		totalPx += pxCount

		entries[#entries + 1] = {
			sizeIdx  = sizeIdx,
			colorIdx = colorIdx,
			isFill   = isFill,
			pts      = pts,
			pxCount  = pxCount,
		}
	end

	-- second pass: allocate and fill buffer
	local byteCount = 0
	for _, e in ipairs(entries) do
		byteCount += 5 + e.pxCount * 4
	end

	local buf    = buffer.create(byteCount)
	local offset = 0

	for _, e in ipairs(entries) do
		buffer.writeu8(buf, offset,     e.sizeIdx)
		buffer.writeu8(buf, offset + 1, e.colorIdx)
		buffer.writeu8(buf, offset + 2, e.isFill and 1 or 0)
		buffer.writeu16(buf, offset + 3, e.pxCount)
		offset += 5

		local pts = e.pts
		for j = 1, #pts - 1, 2 do
			buffer.writeu16(buf, offset,     pts[j])
			buffer.writeu16(buf, offset + 2, pts[j + 1])
			offset += 4
		end
	end

	return buf
end

--------------------------------------------------------------------------------
-- decode(buf) → strokes (DrawRenderer wire format)
--
-- Output format matches what DrawRenderer.render and StrokeValidator expect:
--   { s=float, r=float, g=float, b=float, f=bool, p={x1,y1,x2,y2,...} }
-- r/g/b are 0-1 floats.
--------------------------------------------------------------------------------

function StrokeCodec.decode(buf)
	local size   = buffer.len(buf)
	local offset = 0
	local strokes = {}

	while offset + 5 <= size do
		local sizeIdx  = buffer.readu8(buf, offset)
		local colorIdx = buffer.readu8(buf, offset + 1)
		local flags    = buffer.readu8(buf, offset + 2)
		local pxCount  = buffer.readu16(buf, offset + 3)
		offset += 5

		local s = IDX_TO_SIZE[sizeIdx]
		if not s then
			offset += pxCount * 4
			continue
		end

		local c = IDX_TO_COLOR[colorIdx]
		if not c then
			offset += pxCount * 4
			continue
		end

		local isFill = bit32.band(flags, 1) == 1
		local p      = {}

		local available = math.floor((size - offset) / 4)
		local readCount = math.min(pxCount, available)

		for _ = 1, readCount do
			p[#p + 1] = buffer.readu16(buf, offset)
			p[#p + 1] = buffer.readu16(buf, offset + 2)
			offset += 4
		end

		local stroke = {
			s = s,
			r = c.r / 255,
			g = c.g / 255,
			b = c.b / 255,
			p = p,
		}
		if isFill then stroke.f = true end

		strokes[#strokes + 1] = stroke
	end

	return strokes
end

return StrokeCodec
