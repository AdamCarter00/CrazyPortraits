local StrokeValidator = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants         = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local StrokeCodec       = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("StrokeCodec"))

-- Coordinates are wire-encoded as u16 (0-65535) but the canvas is only
-- CANVAS_SIZE wide/tall. Anything at or beyond the edge is out of bounds.
local CANVAS_SIZE = Constants.CANVAS_SIZE

-- Whitelist sets rebuilt from Constants for fast O(1) lookup.
local VALID_SIZE_IDX  = { [0] = true, [1] = true, [2] = true }  -- 0.01, 0.04, 0.08
local SIZE_TO_FLOAT   = { [0] = 0.01, [1] = 0.04, [2] = 0.08 }

local VALID_COLOR_IDX = {}
for i = 0, #Constants.VALID_COLORS - 1 do
	VALID_COLOR_IDX[i] = true
end

local IDX_TO_COLOR = {}
for i, c in ipairs(Constants.VALID_COLORS) do
	IDX_TO_COLOR[i - 1] = c
end

--------------------------------------------------------------------------------
-- validate(player, buf) → decoded stroke table, rejectedCount, truncated
--
-- buf must be a Roblox buffer (typeof == "buffer").
-- Returns:
--   strokes        — decoded stroke list in DrawRenderer wire format (may be empty)
--   rejectedCount  — number of strokes that failed index validation
--   truncated      — true if buffer ran out mid-stroke
-- Returns nil on type error.
-- Enforces MAX_STROKES, MAX_PIXELS_PER_STROKE, MAX_TOTAL_PIXELS caps.
--------------------------------------------------------------------------------

function StrokeValidator.validate(player, buf)
	if typeof(buf) ~= "buffer" then
		warn("[StrokeValidator]", player.Name, "sent invalid data instead of buffer")
		return nil
	end

	local size   = buffer.len(buf)
	local offset = 0

	local maxStrokes    = Constants.MAX_STROKES
	local maxPxPerStroke = Constants.MAX_PIXELS_PER_STROKE
	local maxTotal      = Constants.MAX_TOTAL_PIXELS

	local strokes    = {}
	local totalPx    = 0
	local rejected   = 0
	local strokeCount = 0
	local truncated  = false

	while offset + 5 <= size do
		if strokeCount >= maxStrokes then break end
		if totalPx >= maxTotal then break end

		local sizeIdx  = buffer.readu8(buf, offset)
		local colorIdx = buffer.readu8(buf, offset + 1)
		local flags    = buffer.readu8(buf, offset + 2)
		local pxCount  = buffer.readu16(buf, offset + 3)
		offset += 5

		-- bounds check: ensure we can read all declared pixels
		local pxBytes = pxCount * 4
		if offset + pxBytes > size then
			warn("[StrokeValidator]", player.Name, "truncated buffer - reading stroke", strokeCount + 1)
			truncated = true
			break
		end

		-- validate indices
		if not VALID_SIZE_IDX[sizeIdx] or not VALID_COLOR_IDX[colorIdx] then
			rejected += 1
			offset   += pxBytes
			continue
		end

		local isFill = bit32.band(flags, 1) == 1
		local c      = IDX_TO_COLOR[colorIdx]
		local pxBudget = math.min(pxCount, maxPxPerStroke, maxTotal - totalPx)

		-- strokeEnd marks where this stroke's pixel data ends regardless of budget
		local strokeEnd = offset + pxCount * 4

		local p         = {}
		local prevX, prevY = -1, -1

		for _ = 1, pxBudget do
			local x = buffer.readu16(buf, offset)
			local y = buffer.readu16(buf, offset + 2)
			offset += 4

			-- Drop any pixel outside the canvas (a malformed/cheating client can
			-- send u16 values up to 65535). prevX/prevY are left untouched so the
			-- next in-bounds pixel still dedups correctly against the last kept one.
			if x >= CANVAS_SIZE or y >= CANVAS_SIZE then
				continue
			end

			if x ~= prevX or y ~= prevY then
				p[#p + 1] = x
				p[#p + 1] = y
				prevX, prevY = x, y
			end
		end

		-- always advance to end of this stroke's pixel block
		offset = strokeEnd

		if #p == 0 and not isFill then
			rejected += 1
			continue
		end

		totalPx    += math.floor(#p / 2)
		strokeCount += 1

		local stroke = {
			s = SIZE_TO_FLOAT[sizeIdx],
			r = c.r / 255,
			g = c.g / 255,
			b = c.b / 255,
			p = p,
		}
		if isFill then stroke.f = true end

		strokes[#strokes + 1] = stroke
	end

	if rejected > 0 then
		warn("[StrokeValidator]", player.Name, "-", rejected, "invalid strokes rejected")
	end

	return strokes, rejected, truncated
end

return StrokeValidator
