--!nocheck

local Core = require(Shared.Analytics.Core)
local Day = require(Shared.Analytics.Day)
local Config = require(Shared.Config.Analytics)

local function withConfig(overrides)
	local merged = table.clone(Config)
	for key, value in overrides or {} do
		merged[key] = value
	end
	return merged
end

local function harness(options)
	options = options or {}
	local h = { now = 0, sent = {}, lines = {}, warnings = {}, players = options.players or 1 }
	h.core = Core.new({
		config = options.config or Config,
		clock = function()
			return h.now
		end,
		studio = options.studio == true,
		playerCount = function()
			return h.players
		end,
		send = function(target, name, value, custom)
			if options.failing then
				error("servis hatasi")
			end
			table.insert(h.sent, { target = target, name = name, value = value, custom = custom })
		end,
		output = function(line)
			table.insert(h.lines, line)
		end,
		warn = function(line)
			table.insert(h.warnings, line)
		end,
	})
	return h
end

local GOOD_EXIT = { kohort = "2026-11-20", kaynak = "etiketsiz", oturum_tipi = "donus" }
local GOOD_FIVE = { kohort = "2026-11-20", kaynak = "etiketsiz", o_an = "lobide" }

local function cardinality(spec)
	local count = 0
	for key, entry in spec do
		if key == "Gunler" then
			count += (Day.startUnix(entry.Son) - Day.startUnix(entry.Ilk)) // 86400 + 1
		elseif type(entry) == "table" then
			count += cardinality(entry)
		else
			count += 1
		end
	end
	return count
end

describe("Olcum cekirdegi -- sema", function()
	it("T-021: her olay en cok 3 alan tasir, alanlarin hepsi Config'te kapali liste", function()
		for key, event in Config.Olaylar do
			expect(#event.Alanlar <= 3).toBe(true)
			expect(type(event.Ad)).toBe("string")
			for _, field in event.Alanlar do
				expect(Config.Alanlar[field] ~= nil).toBe(true)
			end
		end
	end)

	it("T-021: olay basina alan degeri birlesimi 8000'i gecmez", function()
		for _, event in Config.Olaylar do
			local combos = 1
			for _, field in event.Alanlar do
				combos *= cardinality(Config.Alanlar[field])
			end
			expect(combos <= 8000).toBe(true)
		end
	end)

	it("T-021: kova etiketleri sinir sayisindan bir fazla", function()
		expect(#Config.Alanlar.oturum_tipi.Ilk).toBe(#Config.IlkOturumSinirlari + 1)
		expect(#Config.Alanlar.tur_sirasi).toBe(#Config.TurSirasiSinirlari + 1)
		expect(Core.allows(Config.Alanlar.surum, Config.Surum)).toBe(true)
	end)

	it("T-021: oncelikli olaylar IlkGiris, D1Donus ve Cikis", function()
		local priority = {}
		for key, event in Config.Olaylar do
			if event.Oncelikli then
				table.insert(priority, key)
			end
		end
		table.sort(priority)
		expect(priority).toEqual({ "Cikis", "D1Donus", "IlkGiris" })
	end)

	it("alanlar sema sirasiyla CustomField01..03 anahtarina, metin olarak yazilir", function()
		local h = harness()
		h.core:log(7, "Cikis", 42, GOOD_EXIT)
		expect(h.sent[1].name).toBe(Config.Olaylar.Cikis.Ad)
		expect(h.sent[1].value).toBe(42)
		expect(h.sent[1].custom).toEqual({
			CustomField01 = "2026-11-20",
			CustomField02 = "etiketsiz",
			CustomField03 = "donus",
		})
	end)

	it("T-021: listede olmayan alan degeri gonderilmez", function()
		local h = harness()
		expect(h.core:log(1, "Cikis", 1, { kohort = "2026-11-20", kaynak = "reklam", oturum_tipi = "donus" })).toBe(false)
		expect(h.core:log(1, "Cikis", 1, { kohort = "2026-11-20", kaynak = "etiketsiz" })).toBe(false)
		expect(h.core:log(1, "Cikis", 1, { kohort = "2026-11-20", kaynak = "etiketsiz", oturum_tipi = "donus", ad = "x" })).toBe(false)
		expect(h.core:log(1, "Yok", 1, {})).toBe(false)
		expect(#h.sent).toBe(0)
		expect(#h.warnings).toBe(4)
	end)

	it("kohort yalniz araliktaki gecerli UTC gunlerini kabul eder", function()
		local spec = Config.Alanlar.kohort
		expect(Core.allows(spec, spec.Gunler.Ilk)).toBe(true)
		expect(Core.allows(spec, spec.Gunler.Son)).toBe(true)
		expect(Core.allows(spec, Day.after(spec.Gunler.Ilk, -1))).toBe(false)
		expect(Core.allows(spec, Day.after(spec.Gunler.Son, 1))).toBe(false)
		expect(Core.allows(spec, "2026-11-31")).toBe(false)
		expect(Core.allows(spec, "bilinmiyor")).toBe(true)
		expect(Core.allows(spec, "aralik_disi")).toBe(true)
		expect(Core.allows(spec, 20261120)).toBe(false)
	end)
end)

describe("Olcum cekirdegi -- gonderim", function()
	it("Studio'da servise gitmez, Output'a onekle yazar", function()
		local h = harness({ studio = true })
		expect(h.core:log(1, "Cikis", 12, GOOD_EXIT)).toBe(true)
		expect(#h.sent).toBe(0)
		expect(h.lines[1]).toBe(Config.CiktiOneki .. " Cikis deger=12 kohort=2026-11-20 kaynak=etiketsiz oturum_tipi=donus")
	end)

	it("kapatma anahtari her seyi durdurur", function()
		local h = harness({ config = withConfig({ Acik = false }) })
		expect(h.core:log(1, "Cikis", 1, GOOD_EXIT)).toBe(false)
		expect(#h.sent).toBe(0)
	end)

	it("servis hata verirse oyun surer, uyari pencerede bir kez yazilir", function()
		local h = harness({ failing = true })
		expect(h.core:log(1, "Cikis", 1, GOOD_EXIT)).toBe(false)
		expect(h.core:log(1, "Cikis", 1, GOOD_EXIT)).toBe(false)
		expect(#h.warnings).toBe(1)
		h.now = Config.HataUyariSaniye
		h.core:log(1, "Cikis", 1, GOOD_EXIT)
		expect(#h.warnings).toBe(2)
	end)

	it("T-021: butce dolunca oncelikli olmayan olay duser, oncelikli olaylar ayrilan paydan gider", function()
		local h = harness({ players = 2 })
		local budget = Config.Butce
		local total = budget.OyuncuBasinaDakikada * 2
		local open = total - budget.OncelikPayiOyuncuBasina * 2
		for _ = 1, open do
			expect(h.core:log(1, "BesDakika", 1, GOOD_FIVE)).toBe(true)
		end
		expect(h.core:log(1, "BesDakika", 1, GOOD_FIVE)).toBe(false)
		for _ = open + 1, total do
			expect(h.core:log(1, "Cikis", 1, GOOD_EXIT)).toBe(true)
		end
		expect(h.core:log(1, "Cikis", 1, GOOD_EXIT)).toBe(false)
		h.now = budget.PencereSaniye
		expect(h.core:log(1, "BesDakika", 1, GOOD_FIVE)).toBe(true)
	end)

	it("butce penceredeki en yuksek oyuncu sayisina gore buyur", function()
		local h = harness({ players = 1 })
		h.core:log(1, "Cikis", 1, GOOD_EXIT)
		h.players = 3
		for _ = 2, Config.Butce.OyuncuBasinaDakikada * 3 do
			expect(h.core:log(1, "Cikis", 1, GOOD_EXIT)).toBe(true)
		end
		h.players = 1
		expect(h.core:log(1, "Cikis", 1, GOOD_EXIT)).toBe(false)
	end)
end)

describe("Olcum -- arac", function()
	it("T-017: olaylar AnalyticsService ile gider, GameAnalytics kodda yok", function()
		local senders = {}
		for _, entry in SourceIndex do
			if string.find(entry.source, "GameAnalytics", 1, true) then
				error(entry.fsPath .. " GameAnalytics kullaniyor")
			end
			if string.find(entry.source, "LogCustomEvent", 1, true) then
				table.insert(senders, entry.fsPath)
			end
		end
		expect(senders).toEqual({ "src/server/Measurement.luau" })
	end)
end)

describe("Olcum -- UTC gun", function()
	it("Unix saniyesinden UTC gunu ve gun ekleme ay/yil sinirinda dogru", function()
		expect(Day.fromUnix(0)).toBe("1970-01-01")
		expect(Day.fromUnix(1795132800)).toBe("2026-11-20")
		expect(Day.fromUnix(1795132800 - 1)).toBe("2026-11-19")
		expect(Day.after("2026-11-30", 1)).toBe("2026-12-01")
		expect(Day.after("2026-12-31", 1)).toBe("2027-01-01")
		expect(Day.after("2028-02-28", 1)).toBe("2028-02-29")
		expect(Day.startUnix("2026-11-20")).toBe(1795132800)
		expect(Day.isDay("2026-02-29")).toBe(false)
	end)
end)
