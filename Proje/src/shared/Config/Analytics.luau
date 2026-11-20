--!strict

local KAYNAK = table.freeze({ Etiketli = "etiketli", Etiketsiz = "etiketsiz" })

-- Gunler: o araliktaki her UTC gunu (YYYY-AA-GG) izinli; araligin disindaki gun AralikDisi olur.
-- Aralik, Cikis'in deger birlesimi 8000'in altinda kalacak kadar (test zorlar).
local GUN = table.freeze({
	Gunler = table.freeze({ Ilk = "2026-11-20", Son = "2027-02-28" }),
	AralikDisi = "aralik_disi",
})

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
	CizgiSinirlari = table.freeze({ 1, 11, 41, 81 }),
	EkrandakiSinirlari = table.freeze({ 2, 4 }),

	Kaynak = KAYNAK,

	Olaylar = table.freeze({
		IlkGiris = table.freeze({ Ad = "IlkGiris", Alanlar = table.freeze({ "kohort", "surum" }), Oncelikli = true }),
		D1Donus = table.freeze({ Ad = "D1Donus", Alanlar = table.freeze({ "kohort", "surum" }), Oncelikli = true }),
		Cikis = table.freeze({ Ad = "Cikis", Alanlar = table.freeze({ "kohort", "oturum_tipi", "faz" }), Oncelikli = true }),
		BesDakika = table.freeze({ Ad = "BesDakika", Alanlar = table.freeze({ "kohort", "o_an" }) }),
		Eslesme = table.freeze({ Ad = "Eslesme", Alanlar = table.freeze({ "eslesti", "kohort", "ilk_oturum" }) }),
		TurBasladi = table.freeze({ Ad = "TurBasladi", Alanlar = table.freeze({ "rol", "kohort", "ilk_oturum" }) }),
		IlkReveal = table.freeze({ Ad = "IlkReveal", Alanlar = table.freeze({ "reveal_rol", "kohort", "ilk_oturum" }) }),
		TurTamam = table.freeze({ Ad = "TurTamam", Alanlar = table.freeze({ "tur_sirasi", "katilim", "kohort" }) }),
		Teslim = table.freeze({ Ad = "Teslim", Alanlar = table.freeze({ "nasil", "cizgi", "kohort" }) }),
		CizimdeCikis = table.freeze({ Ad = "CizimdeCikis", Alanlar = table.freeze({ "cizgi", "kohort", "ilk_oturum" }) }),
		CizimTepki = table.freeze({ Ad = "CizimTepki", Alanlar = table.freeze({ "ekrandaki", "sahibi_cikti", "kohort" }) }),
	}),

	Alanlar = table.freeze({
		kohort = table.freeze({ Bilesik = table.freeze({ GUN, KAYNAK }), Ayirac = "/", Bilinmiyor = "bilinmiyor/bilinmiyor" }),
		surum = table.freeze({ "V0" }),
		oturum_tipi = table.freeze({
			Ilk = table.freeze({ "ilk_0-60", "ilk_60-300", "ilk_300+" }),
			Donus = "donus",
			Bilinmiyor = "bilinmiyor",
		}),
		faz = table.freeze({
			Lobi = "lobi",
			Izliyor = "izliyor",
			CizimTeslimsiz = "cizim_teslimsiz",
			TeslimSonrasi = "teslim_sonrasi",
			Reveal = "reveal",
			Podyum = "podyum",
		}),
		o_an = table.freeze({ Turda = "turda", Lobide = "lobide", Beklemede = "beklemede" }),
		eslesti = table.freeze({ Evet = "evet", Hayir = "hayir" }),
		ilk_oturum = table.freeze({ Evet = "evet", Hayir = "hayir", Bilinmiyor = "bilinmiyor" }),
		rol = table.freeze({ Model = "model", Cizen = "cizen" }),
		reveal_rol = table.freeze({ Model = "model", Cizen = "cizen", Izleyici = "izleyici" }),
		tur_sirasi = table.freeze({ "1", "2", "3", "4", "5+" }),
		katilim = table.freeze({ Model = "model", Cizdi = "cizdi", BosTeslim = "bos_teslim", Izledi = "izledi" }),
		nasil = table.freeze({ Dugme = "dugme", SureDoldu = "sure_doldu" }),
		cizgi = table.freeze({ "0", "1-10", "11-40", "41-80", "80+" }),
		ekrandaki = table.freeze({ "1", "2-3", "4-7" }),
		sahibi_cikti = table.freeze({ Evet = "evet", Hayir = "hayir" }),
	}),
})
