--!nocheck

local StrokeCodec = require(Shared.Drawing.StrokeCodec)
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
	it("T-023: 16 renk ve 3 firca boyu", function()
		expect(#Drawing.Colors).toBe(16)
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
