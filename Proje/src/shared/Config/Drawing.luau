--!strict

return table.freeze({
	CanvasSize = 512,
	MaxStrokes = 80,
	MaxPixelsPerStroke = 1200,
	MaxTotalPixels = 15000,
	MaxUndoSteps = 80,
	RenderDabYieldBudget = 200000,

	-- Sira = StrokeCodec'in renk indeksi (0-15); degisirse istemci ve sunucu birlikte degisir.
	Colors = table.freeze({
		table.freeze({ name = "Siyah", mark = "renk_siyah", r = 26, g = 26, b = 26 }),
		table.freeze({ name = "Beyaz", mark = "renk_beyaz", r = 255, g = 255, b = 255 }),
		table.freeze({ name = "Gri", mark = "renk_gri", r = 158, g = 158, b = 158 }),
		table.freeze({ name = "Ten", mark = "renk_ten", r = 245, g = 196, b = 161 }),
		table.freeze({ name = "Kirmizi", mark = "renk_kirmizi", r = 232, g = 57, b = 46 }),
		table.freeze({ name = "Turuncu", mark = "renk_turuncu", r = 249, g = 115, b = 22 }),
		table.freeze({ name = "Sari", mark = "renk_sari", r = 250, g = 204, b = 21 }),
		table.freeze({ name = "Yesil", mark = "renk_yesil", r = 34, g = 197, b = 94 }),
		table.freeze({ name = "Turkuaz", mark = "renk_turkuaz", r = 20, g = 184, b = 166 }),
		table.freeze({ name = "Mavi", mark = "renk_mavi", r = 59, g = 130, b = 246 }),
		table.freeze({ name = "Mor", mark = "renk_mor", r = 139, g = 92, b = 246 }),
		table.freeze({ name = "Pembe", mark = "renk_pembe", r = 236, g = 72, b = 153 }),
		table.freeze({ name = "Kahve", mark = "renk_kahve", r = 146, g = 64, b = 14 }),
		table.freeze({ name = "Koyu yesil", mark = "renk_koyu_yesil", r = 22, g = 101, b = 52 }),
		table.freeze({ name = "Lacivert", mark = "renk_lacivert", r = 30, g = 58, b = 95 }),
		table.freeze({ name = "Bordo", mark = "renk_bordo", r = 190, g = 18, b = 60 }),
	}),

	-- Indeks = StrokeCodec'in firca boyu indeksi.
	BrushSizes = table.freeze({ 0.01, 0.04, 0.08 }),
	BrushMarks = table.freeze({ "firca_1", "firca_2", "firca_3" }),

	DefaultColorIndex = 1,
	DefaultBrushIndex = 1,
})
