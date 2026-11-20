--!strict

return table.freeze({
	Acik = true,
	CiktiOneki = "[Analitik]",
	Surum = "V0",

	Butce = table.freeze({
		OyuncuBasinaDakikada = 18,
		OncelikPayiOyuncuBasina = 6,
		PencereSaniye = 60,
	}),
	HataUyariSaniye = 60,

	BesDakikaSaniye = 300,
	IlkOturumSinirlari = table.freeze({ 60, 300 }),
	TurSirasiSinirlari = table.freeze({ 2, 3, 4, 5 }),

	Olaylar = table.freeze({
		IlkGiris = table.freeze({ Ad = "IlkGiris", Alanlar = table.freeze({ "kohort", "kaynak", "surum" }), Oncelikli = true }),
		D1Donus = table.freeze({ Ad = "D1Donus", Alanlar = table.freeze({ "kohort", "kaynak", "surum" }), Oncelikli = true }),
		Cikis = table.freeze({ Ad = "Cikis", Alanlar = table.freeze({ "kohort", "kaynak", "oturum_tipi" }), Oncelikli = true }),
		BesDakika = table.freeze({ Ad = "BesDakika", Alanlar = table.freeze({ "kohort", "kaynak", "o_an" }) }),
		Eslesme = table.freeze({ Ad = "Eslesme", Alanlar = table.freeze({ "eslesti", "kohort", "ilk_oturum" }) }),
		TurBasladi = table.freeze({ Ad = "TurBasladi", Alanlar = table.freeze({ "rol", "kohort", "ilk_oturum" }) }),
		IlkReveal = table.freeze({ Ad = "IlkReveal", Alanlar = table.freeze({ "reveal_rol", "kohort", "ilk_oturum" }) }),
		TurTamam = table.freeze({ Ad = "TurTamam", Alanlar = table.freeze({ "tur_sirasi", "katilim", "kohort" }) }),
	}),

	-- Gunler: o araliktaki her UTC gunu (YYYY-AA-GG) izinli; araligin disindaki gun AralikDisi olur.
	Alanlar = table.freeze({
		kohort = table.freeze({
			Gunler = table.freeze({ Ilk = "2026-11-20", Son = "2027-03-31" }),
			Bilinmiyor = "bilinmiyor",
			AralikDisi = "aralik_disi",
		}),
		kaynak = table.freeze({ Etiketli = "etiketli", Etiketsiz = "etiketsiz", Bilinmiyor = "bilinmiyor" }),
		surum = table.freeze({ "V0" }),
		oturum_tipi = table.freeze({
			Ilk = table.freeze({ "ilk_0-60", "ilk_60-300", "ilk_300+" }),
			Donus = "donus",
			Bilinmiyor = "bilinmiyor",
		}),
		o_an = table.freeze({ Turda = "turda", Lobide = "lobide", Beklemede = "beklemede" }),
		eslesti = table.freeze({ Evet = "evet", Hayir = "hayir" }),
		ilk_oturum = table.freeze({ Evet = "evet", Hayir = "hayir", Bilinmiyor = "bilinmiyor" }),
		rol = table.freeze({ Model = "model", Cizen = "cizen" }),
		reveal_rol = table.freeze({ Model = "model", Cizen = "cizen", Izleyici = "izleyici" }),
		tur_sirasi = table.freeze({ "1", "2", "3", "4", "5+" }),
		katilim = table.freeze({ Model = "model", Cizdi = "cizdi", BosTeslim = "bos_teslim", Izledi = "izledi" }),
	}),
})
