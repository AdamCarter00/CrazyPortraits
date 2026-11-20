--[[
FloodFill
---------
Shared 4-connected flood fill over a raw RGBA pixel buffer (the format used by
EditableImage:Read/WritePixelsBuffer). Used by:
  - CanvasController (live bucket fill + undo redraw)
  - DrawRenderer    (reveal + gallery replay)

Buffer layout: row-major RGBA, stride = WIDTH * 4, one byte per channel.

Performance notes:
  - The BFS frontier (queue) is a pre-allocated u16 buffer reused across calls,
    so a fill allocates nothing on the heap — no GC pressure even when many
    fills run back-to-back (undo with several fills, 8-slot gallery render).
  - The visited bitset is likewise a reused module-level buffer.

REENTRANCY: NOT reentrant. The queue and visited buffers are module-level and
shared. This is safe because fill() never yields (no task.wait / coroutine
yield) and Luau is single-threaded, so one call always completes before another
begins. Do NOT add a yield inside fill().
]]

local Drawing = require(script.Parent.Parent.Config.Drawing)

local W = Drawing.CanvasSize
local H = Drawing.CanvasSize

local FloodFill = {}

--------------------------------------------------------------------------------
-- Reused buffers
--------------------------------------------------------------------------------

-- Visited bitset: one bit per pixel.
local VISITED_BYTES = W * H / 8
local VISITED_BUF   = buffer.create(VISITED_BYTES)

-- BFS frontier. Worst case every one of W*H pixels is enqueued once; each entry
-- is an (x, y) pair of u16 = 4 bytes. Capacity = W*H*4 bytes covers the worst
-- case exactly, so the queue never needs to grow.
local QUEUE_BYTES = W * H * 4
local QUEUE_BUF   = buffer.create(QUEUE_BYTES)

local function markVisited(i)
	local byteIdx = i // 8
	buffer.writeu8(VISITED_BUF, byteIdx, bit32.bor(buffer.readu8(VISITED_BUF, byteIdx), bit32.lshift(1, i % 8)))
end

local function isVisited(i)
	return bit32.band(buffer.readu8(VISITED_BUF, i // 8), bit32.lshift(1, i % 8)) ~= 0
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

-- fill(buf, bx, by, dr, dg, db)
--   buf            — RGBA pixel buffer (W*H*4 bytes)
--   bx, by         — seed pixel coordinates (0-based)
--   dr, dg, db     — destination color (0-255 per channel)
-- Recolors the contiguous same-colored region containing the seed.
--
-- Returns the bounding box of the recolored pixels as (minX, minY, maxX, maxY)
-- — 0-based, inclusive — so callers can write back only the touched sub-region
-- instead of the whole canvas. Returns nil when nothing was painted (seed out of
-- bounds, or already the destination color).
function FloodFill.fill(buf, bx, by, dr, dg, db)
	if bx < 0 or bx >= W or by < 0 or by >= H then
		warn("[FloodFill] seed out of bounds", bx, by)
		return nil
	end

	local stride = W * 4
	local pi0 = by * stride + bx * 4
	local hr  = buffer.readu8(buf, pi0)
	local hg  = buffer.readu8(buf, pi0 + 1)
	local hb  = buffer.readu8(buf, pi0 + 2)

	-- Already the target color: nothing to do.
	if hr == dr and hg == dg and hb == db then return nil end

	-- Dirty rectangle of recolored pixels (inclusive). Seeded inverted so the
	-- first painted pixel sets the real bounds.
	local minX, minY = W, H
	local maxX, maxY = -1, -1

	buffer.fill(VISITED_BUF, 0, 0, VISITED_BYTES)

	-- head/tail are byte offsets into QUEUE_BUF; each entry is 4 bytes (x:u16, y:u16).
	local head = 0
	local tail = 0

	buffer.writeu16(QUEUE_BUF, tail, bx)
	buffer.writeu16(QUEUE_BUF, tail + 2, by)
	tail += 4
	markVisited(by * W + bx)

	while head < tail do
		local x = buffer.readu16(QUEUE_BUF, head)
		local y = buffer.readu16(QUEUE_BUF, head + 2)
		head += 4

		local pi = y * stride + x * 4
		if buffer.readu8(buf, pi) == hr and buffer.readu8(buf, pi + 1) == hg and buffer.readu8(buf, pi + 2) == hb then
			buffer.writeu8(buf, pi,     dr)
			buffer.writeu8(buf, pi + 1, dg)
			buffer.writeu8(buf, pi + 2, db)

			if x < minX then minX = x end
			if x > maxX then maxX = x end
			if y < minY then minY = y end
			if y > maxY then maxY = y end

			local vi
			if x > 0 then
				vi = y * W + (x - 1)
				if not isVisited(vi) then
					markVisited(vi)
					buffer.writeu16(QUEUE_BUF, tail, x - 1); buffer.writeu16(QUEUE_BUF, tail + 2, y); tail += 4
				end
			end
			if x < W - 1 then
				vi = y * W + (x + 1)
				if not isVisited(vi) then
					markVisited(vi)
					buffer.writeu16(QUEUE_BUF, tail, x + 1); buffer.writeu16(QUEUE_BUF, tail + 2, y); tail += 4
				end
			end
			if y > 0 then
				vi = (y - 1) * W + x
				if not isVisited(vi) then
					markVisited(vi)
					buffer.writeu16(QUEUE_BUF, tail, x); buffer.writeu16(QUEUE_BUF, tail + 2, y - 1); tail += 4
				end
			end
			if y < H - 1 then
				vi = (y + 1) * W + x
				if not isVisited(vi) then
					markVisited(vi)
					buffer.writeu16(QUEUE_BUF, tail, x); buffer.writeu16(QUEUE_BUF, tail + 2, y + 1); tail += 4
				end
			end
		end
	end

	-- No pixel matched the seed color after all (e.g. an antialiased seed pixel
	-- whose neighbors differ): nothing was painted.
	if maxX < 0 then return nil end

	return minX, minY, maxX, maxY
end

return FloodFill
