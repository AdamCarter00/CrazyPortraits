--!strict

-- Kodun arayuzde ve dunyada aradigi sabit isaretler. Renk, firca, emoji ve podyum yuvasi
-- isaretleri Binder.expected'ta ilgili Config'ten uretilir. Her satir BAGLAMA.md'de de yazili olmali (test zorlar).
return table.freeze({
	MarkerAttribute = "Isaret",
	SelectedMark = "secili",
	GuiWaitSeconds = 10,

	Marks = table.freeze({
		table.freeze({ mark = "cizim_ekran", class = "ScreenGui", group = "cizim" }),
		table.freeze({ mark = "cizim_tuval", class = "ImageLabel", group = "cizim" }),
		table.freeze({ mark = "cizim_sure", class = "TextLabel", group = "cizim" }),
		table.freeze({ mark = "cizim_baslik", class = "TextLabel", group = "cizim" }),
		table.freeze({ mark = "cizim_gonder", class = "GuiButton", group = "cizim" }),
		table.freeze({ mark = "arac_silgi", class = "GuiButton", selectable = true, group = "cizim" }),
		table.freeze({ mark = "arac_kova", class = "GuiButton", selectable = true, group = "cizim" }),
		table.freeze({ mark = "arac_geri", class = "GuiButton", group = "cizim" }),
		table.freeze({ mark = "cizim_sayim_kutu", class = "GuiObject", group = "cizim" }),
		table.freeze({ mark = "cizim_sayim", class = "TextLabel", group = "cizim" }),
		table.freeze({ mark = "cizim_sayim_yazi", class = "TextLabel", group = "cizim" }),

		table.freeze({ mark = "asama_ekran", class = "ScreenGui", group = "asama" }),
		table.freeze({ mark = "asama_ana", class = "TextLabel", group = "asama" }),
		table.freeze({ mark = "asama_ek", class = "TextLabel", group = "asama" }),

		table.freeze({ mark = "gecis_ekran", class = "ScreenGui", group = "gecis" }),
		table.freeze({ mark = "gecis_cerceve", class = "CanvasGroup", group = "gecis" }),
		table.freeze({ mark = "gecis_etiket", class = "TextLabel", group = "gecis" }),

		table.freeze({ mark = "yukleme_ekran", class = "ScreenGui", group = "yukleme" }),
		table.freeze({ mark = "yukleme_ipucu", class = "TextLabel", group = "yukleme" }),
		table.freeze({ mark = "yukleme_cubuk_yazi", class = "TextLabel", group = "yukleme" }),

		table.freeze({ mark = "lobi_ekran", class = "ScreenGui", group = "lobi" }),
		table.freeze({ mark = "lobi_davet", class = "GuiButton", group = "lobi" }),

		table.freeze({ mark = "reveal_ekran", class = "ScreenGui", group = "reveal" }),
		table.freeze({ mark = "reveal_tuval", class = "ImageLabel", group = "reveal" }),
		table.freeze({ mark = "reveal_ad", class = "TextLabel", group = "reveal" }),
		table.freeze({ mark = "reveal_sira", class = "TextLabel", group = "reveal" }),
		table.freeze({ mark = "reveal_sure", class = "Frame", group = "reveal" }),

		table.freeze({ mark = "emoji_ekran", class = "ScreenGui", group = "emoji" }),
		table.freeze({ mark = "podyum_ekran", class = "ScreenGui", group = "podyum" }),
	}),

	WorldMarks = table.freeze({
		table.freeze({ mark = "sahne_model_durak", class = "BasePart", group = "dunya" }),
		table.freeze({ mark = "sahne_kamera_cizim", class = "BasePart", group = "dunya" }),
		table.freeze({ mark = "sahne_kamera_reveal", class = "BasePart", group = "dunya" }),
	}),
})
