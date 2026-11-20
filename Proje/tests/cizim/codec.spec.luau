--!nocheck

local StrokeCodec = require(Shared.Drawing.StrokeCodec)
local StrokeValidator = require(Shared.Drawing.StrokeValidator)
local FloodFill = require(Shared.Drawing.FloodFill)
local Drawing = require(Shared.Config.Drawing)

local function black()
	local c = Drawing.Colors[1]
	return c.r / 255, c.g / 255, c.b / 255
end

describe("Cizim -- StrokeCodec ve StrokeValidator", function()
	it("kodla-coz cizgiyi korur", function()
		local r, g, b = black()
		local strokes = { { s = Drawing.BrushSizes[2], r = r, g = g, b = b, p = { 1, 2, 3, 4, 3, 4, 5, 6 } } }
		local decoded = StrokeCodec.decode(StrokeCodec.encode(strokes))
		expect(#decoded).toBe(1)
		expect(decoded[1].s).toBe(Drawing.BrushSizes[2])
		expect(decoded[1].p).toEqual({ 1, 2, 3, 4, 5, 6 })
	end)

	it("dogrulayici tuval disindaki noktalari ve gecersiz renkleri atar", function()
		local buf = buffer.create(5 + 2 * 4 + 5 + 4)
		buffer.writeu8(buf, 0, 0)
		buffer.writeu8(buf, 1, 0)
		buffer.writeu8(buf, 2, 0)
		buffer.writeu16(buf, 3, 2)
		buffer.writeu16(buf, 5, 10)
		buffer.writeu16(buf, 7, 10)
		buffer.writeu16(buf, 9, 60000)
		buffer.writeu16(buf, 11, 10)
		buffer.writeu8(buf, 13, 0)
		buffer.writeu8(buf, 14, 200)
		buffer.writeu8(buf, 15, 0)
		buffer.writeu16(buf, 16, 1)
		buffer.writeu16(buf, 18, 1)
		buffer.writeu16(buf, 20, 1)
		local strokes, rejected = StrokeValidator.validate(buf)
		expect(#strokes).toBe(1)
		expect(strokes[1].p).toEqual({ 10, 10 })
		expect(rejected).toBe(1)
	end)

	it("dogrulayici buffer olmayani reddeder", function()
		expect(StrokeValidator.validate("x")).toBeNil()
	end)

	it("cizgi sayisi ust siniri asilmaz", function()
		local r, g, b = black()
		local strokes = {}
		for i = 1, Drawing.MaxStrokes + 10 do
			strokes[i] = { s = Drawing.BrushSizes[1], r = r, g = g, b = b, p = { i, i } }
		end
		local validated = StrokeValidator.validate(StrokeCodec.encode(strokes))
		expect(#validated).toBe(Drawing.MaxStrokes)
	end)

	it("FloodFill yuklenir", function()
		expect(type(FloodFill.fill)).toBe("function")
	end)
end)
