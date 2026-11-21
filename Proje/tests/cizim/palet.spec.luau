--!nocheck

local StrokeCodec = require(Shared.Drawing.StrokeCodec)
local StrokeValidator = require(Shared.Drawing.StrokeValidator)
local Drawing = require(Shared.Config.Drawing)

local function indexOf(mark)
	for i, c in Drawing.Colors do
		if c.mark == mark then
			return i
		end
	end
	return nil
end

describe("Cizim -- palet", function()
	it("T-023: 18 renk ve 3 firca boyu", function()
		expect(#Drawing.Colors).toBe(18)
		expect(#Drawing.BrushSizes).toBe(3)
		expect(#Drawing.BrushMarks).toBe(3)
	end)

	it("T-023: uc ten tonu ve ayri sarisin rengi var", function()
		for _, mark in { "renk_ten", "renk_orta_ten", "renk_koyu_kahve", "renk_sarisin", "renk_sari" } do
			expect(indexOf(mark)).toBeTruthy()
		end
	end)

	it("T-023: kalan renklerin kodlayici indeksi F-001 kayitlariyla ayni", function()
		local kept = {
			renk_siyah = 1, renk_beyaz = 2, renk_gri = 3, renk_ten = 4, renk_kirmizi = 5, renk_turuncu = 6,
			renk_sari = 7, renk_yesil = 8, renk_turkuaz = 9, renk_mavi = 10, renk_mor = 11, renk_pembe = 12,
			renk_lacivert = 15,
		}
		for mark, index in kept do
			expect(indexOf(mark)).toBe(index)
		end
	end)

	it("T-023: eski 16 rengin numarasi ve degeri degismez, yeni renkler sonda", function()
		local old = {
			{ "renk_siyah", 26, 26, 26 }, { "renk_beyaz", 255, 255, 255 }, { "renk_gri", 158, 158, 158 },
			{ "renk_ten", 245, 196, 161 }, { "renk_kirmizi", 232, 57, 46 }, { "renk_turuncu", 249, 115, 22 },
			{ "renk_sari", 250, 204, 21 }, { "renk_yesil", 34, 197, 94 }, { "renk_turkuaz", 20, 184, 166 },
			{ "renk_mavi", 59, 130, 246 }, { "renk_mor", 139, 92, 246 }, { "renk_pembe", 236, 72, 153 },
			{ "renk_koyu_kahve", 110, 68, 40 }, { "renk_orta_ten", 198, 134, 90 }, { "renk_lacivert", 30, 58, 95 },
			{ "renk_sarisin", 250, 226, 140 },
		}
		for index, row in old do
			local c = Drawing.Colors[index]
			expect(c.mark).toBe(row[1])
			expect(c.r).toBe(row[2])
			expect(c.g).toBe(row[3])
			expect(c.b).toBe(row[4])
		end
		expect(indexOf("renk_acik_mavi")).toBe(17)
		expect(indexOf("renk_koyu_yesil")).toBe(18)
	end)

	it("T-023: dogrulayici yeni renkleri kabul eder, paletin disini reddeder", function()
		local function one(colorIdx)
			local buf = buffer.create(5 + 4)
			buffer.writeu8(buf, 0, 0)
			buffer.writeu8(buf, 1, colorIdx)
			buffer.writeu8(buf, 2, 0)
			buffer.writeu16(buf, 3, 1)
			buffer.writeu16(buf, 5, 1)
			buffer.writeu16(buf, 7, 1)
			return StrokeValidator.validate(buf)
		end
		for _, idx in { 16, 17 } do
			local strokes, rejected = one(idx)
			local c = Drawing.Colors[idx + 1]
			expect(rejected).toBe(0)
			expect(math.round(strokes[1].r * 255)).toBe(c.r)
			expect(math.round(strokes[1].b * 255)).toBe(c.b)
		end
		local strokes, rejected = one(#Drawing.Colors)
		expect(#strokes).toBe(0)
		expect(rejected).toBe(1)
	end)

	it("T-023: her renk kodla-coz sonrasi ayni renge doner", function()
		for _, c in Drawing.Colors do
			local strokes = { { s = Drawing.BrushSizes[1], r = c.r / 255, g = c.g / 255, b = c.b / 255, p = { 1, 1, 2, 2 } } }
			local decoded = StrokeCodec.decode(StrokeCodec.encode(strokes))
			expect(math.round(decoded[1].r * 255)).toBe(c.r)
			expect(math.round(decoded[1].g * 255)).toBe(c.g)
			expect(math.round(decoded[1].b * 255)).toBe(c.b)
		end
	end)

	it("T-023: isaretler tekil", function()
		local seen = {}
		for _, c in Drawing.Colors do
			expect(seen[c.mark]).toBe(nil)
			seen[c.mark] = true
		end
	end)
end)
