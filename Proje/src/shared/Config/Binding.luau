--!strict

-- Kodun arayuzde aradigi sabit isaretler. Renk ve firca isaretleri Config.Drawing'den gelir.
-- Her satir BAGLAMA.md'de de yazili olmali (test zorlar).
return table.freeze({
	MarkerAttribute = "Isaret",
	SelectedMark = "secili",

	Marks = table.freeze({
		table.freeze({ mark = "cizim_ekran", class = "ScreenGui" }),
		table.freeze({ mark = "cizim_tuval", class = "ImageLabel" }),
		table.freeze({ mark = "cizim_sure", class = "TextLabel" }),
		table.freeze({ mark = "cizim_baslik", class = "TextLabel" }),
		table.freeze({ mark = "cizim_gonder", class = "GuiButton" }),
		table.freeze({ mark = "arac_silgi", class = "GuiButton", selectable = true }),
		table.freeze({ mark = "arac_kova", class = "GuiButton", selectable = true }),
		table.freeze({ mark = "arac_geri", class = "GuiButton" }),
		table.freeze({ mark = "gecis_ekran", class = "ScreenGui" }),
		table.freeze({ mark = "gecis_cerceve", class = "CanvasGroup" }),
		table.freeze({ mark = "gecis_etiket", class = "TextLabel" }),
		table.freeze({ mark = "ekran_yukleme", class = "ScreenGui" }),
		table.freeze({ mark = "ekran_emoji", class = "ScreenGui" }),
		table.freeze({ mark = "ekran_yan_menu", class = "ScreenGui" }),
		table.freeze({ mark = "ekran_asama", class = "ScreenGui" }),
		table.freeze({ mark = "ekran_sonuc", class = "ScreenGui" }),
		table.freeze({ mark = "ekran_market", class = "ScreenGui" }),
		table.freeze({ mark = "ekran_ogretici", class = "ScreenGui" }),
	}),
})
