--!nocheck

local Machine = require(Shared.Round.Machine)
local RoundConfig = require(Shared.Config.Round)
local Metrics = require(Shared.Analytics.Metrics)
local Core = require(Shared.Analytics.Core)
local Day = require(Shared.Analytics.Day)
local Config = require(Shared.Config.Analytics)

local RoundTest = table.clone(RoundConfig)
RoundTest.MinPlayers = 2

local DAY1 = "2026-11-20"
local DAY2 = "2026-11-21"
local TAG = "CP2-REKLAM"

local function at(day, hours, minutes, seconds)
	return Day.startUnix(day) + hours * 3600 + (minutes or 0) * 60 + (seconds or 0)
end

-- Dunya: ortak saat, ortak profil deposu, ortak analitik kaydi; her sunucunun kendi makinesi ve olcumu var.
local function newWorld(start)
	return { now = start, sent = {}, warnings = {}, profiles = {}, servers = {} }
end

local function newServer(world)
	local server = { world = world, online = {} }
	server.machine = Machine.new({ config = RoundTest, random = function()
		return 0
	end })
	server.core = Core.new({
		config = Config,
		clock = function()
			return world.now
		end,
		studio = false,
		playerCount = function()
			local count = 0
			for _ in server.online do
				count += 1
			end
			return math.max(count, 1)
		end,
		send = function(target, name, value, custom)
			table.insert(world.sent, { user = target, name = name, value = value, custom = custom, at = world.now })
		end,
		output = function() end,
		warn = function(line)
			table.insert(world.warnings, line)
		end,
	})
	server.metrics = Metrics.new({ config = Config, core = server.core })
	table.insert(world.servers, server)
	return server
end

local function observe(server)
	Metrics.observe(server.metrics, server.machine, server.world.now)
end

local function loadProfile(world, id)
	local profile = world.profiles[id]
	if not profile then
		profile = { loads = 0, writes = 0 }
		world.profiles[id] = profile
	end
	if profile.fail then
		return { ok = false }
	end
	profile.loads += 1
	return { ok = true, record = profile.record, fresh = profile.loads == 1 }
end

local function resolve(server, id, launch)
	local world = server.world
	local record = Metrics.profile(server.metrics, id, world.now, loadProfile(world, id), launch)
	if record then
		local profile = world.profiles[id]
		if profile.record == nil then
			profile.record = record
			profile.writes += 1
		end
	end
end

local function join(server, id, options)
	options = options or {}
	local world = server.world
	server.online[id] = true
	Metrics.join(server.metrics, id, world.now, options.launch)
	if not options.later then
		resolve(server, id, options.launch)
	end
	Machine.join(server.machine, id, "Oyuncu" .. id, world.now)
	if options.ready ~= false then
		Machine.ready(server.machine, id, world.now)
	end
	observe(server)
end

local function leave(server, id)
	Machine.leave(server.machine, id, server.world.now)
	observe(server)
	Metrics.leave(server.metrics, id, server.world.now)
	server.online[id] = nil
end

local function submit(server, id, strokes)
	Machine.submit(server.machine, id, buffer.create(1), strokes, server.world.now)
	observe(server)
end

local function anyoneOnline(world)
	for _, server in world.servers do
		if next(server.online) then
			return true
		end
	end
	return false
end

local function advance(world, target)
	while world.now < target do
		if not anyoneOnline(world) then
			world.now = target
			break
		end
		world.now = math.min(world.now + 1, target)
		for _, server in world.servers do
			Machine.tick(server.machine, world.now)
			observe(server)
		end
	end
end

local function decode(entry)
	for key, spec in Config.Olaylar do
		if spec.Ad == entry.name then
			local fields = {}
			for index, field in spec.Alanlar do
				fields[field] = entry.custom[Core.fieldKey(index)]
			end
			return key, fields
		end
	end
	error("bilinmeyen olay " .. entry.name)
end

local function events(world, key, where)
	local out = {}
	for _, entry in world.sent do
		local name, fields = decode(entry)
		if name == key and (where == nil or where(fields, entry.value)) then
			table.insert(out, { user = entry.user, value = entry.value, fields = fields })
		end
	end
	return out
end

local function unique(list)
	local seen, count = {}, 0
	for _, item in list do
		if not seen[item.user] then
			seen[item.user] = true
			count += 1
		end
	end
	return count
end

local function mean(list)
	local total = 0
	for _, item in list do
		total += item.value
	end
	return total / #list
end

local function wilson(successes, n)
	local z = 1.959963984540054
	local p = successes / n
	local denominator = 1 + z * z / n
	local center = (p + z * z / (2 * n)) / denominator
	local margin = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / denominator
	return center - margin, center + margin
end

local function cohort(day)
	return function(fields)
		return fields.kohort == day
	end
end

local function both(a, b)
	return function(fields, value)
		return a(fields, value) and b(fields, value)
	end
end

local function field(name, ...)
	local allowed = { ... }
	return function(fields)
		return table.find(allowed, fields[name]) ~= nil
	end
end

local P = {}
for n = 1, 9 do
	P[n] = 918273600 + n
end

-- Kapi 1 test gunu: bilinen 9 oyuncu, iki sunucu, gun 1 ve gece yarisindan sonra gun 2.
local function testDay()
	local world = newWorld(at(DAY1, 9))
	local full = newServer(world)
	local solo = newServer(world)

	join(solo, P[5])
	advance(world, at(DAY1, 9, 0, 40))
	leave(solo, P[5])

	local t0 = at(DAY1, 10)
	advance(world, t0)
	join(full, P[1], { launch = TAG })
	advance(world, t0 + 20)
	join(full, P[2])
	advance(world, t0 + 25)
	join(full, P[3])
	advance(world, t0 + 60)
	submit(full, P[1], 3)
	submit(full, P[2], 0)
	advance(world, t0 + 70)
	submit(full, P[3], 5)
	advance(world, t0 + 75)
	join(full, P[4])
	advance(world, t0 + 120)
	for _, id in { P[1], P[2], P[3], P[4] } do
		submit(full, id, 0)
	end
	advance(world, t0 + 140)
	leave(full, P[2])
	advance(world, t0 + 150)
	for _, id in { P[1], P[3], P[4] } do
		submit(full, id, 2)
	end
	advance(world, t0 + 320)
	leave(full, P[1])
	advance(world, t0 + 330)
	leave(full, P[3])
	advance(world, t0 + 380)
	leave(full, P[4])

	advance(world, at(DAY1, 11))
	world.profiles[P[8]] = { loads = 0, writes = 0, fail = true }
	join(solo, P[8])
	advance(world, at(DAY1, 11, 0, 30))
	leave(solo, P[8])

	advance(world, at(DAY1, 11, 30))
	world.profiles[P[9]] = { loads = 4, writes = 0 }
	join(solo, P[9])
	advance(world, at(DAY1, 11, 31))
	leave(solo, P[9])

	advance(world, at(DAY1, 12))
	join(solo, P[5])
	advance(world, at(DAY1, 12, 1))
	leave(solo, P[5])

	advance(world, at(DAY1, 23, 50))
	join(solo, P[6], { launch = TAG })
	advance(world, at(DAY1, 23, 54))
	leave(solo, P[6])

	advance(world, at(DAY1, 23, 58))
	join(solo, P[7])
	advance(world, at(DAY2, 0, 5))
	leave(solo, P[7])

	advance(world, at(DAY2, 0, 10))
	join(solo, P[6])
	advance(world, at(DAY2, 0, 12))
	leave(solo, P[6])

	return world
end

local world = testDay()
local newcomers = unique(events(world, "IlkGiris", cohort(DAY1)))
local firstSession = field("ilk_oturum", "evet")

describe("Olcum -- test gunu akisi", function()
	it("simulasyon uyarisiz biter; payda: gun 1 kohortunda 7 yeni oyuncu", function()
		expect(world.warnings).toEqual({})
		expect(newcomers).toBe(7)
		expect(#events(world, "IlkGiris")).toBe(7)
	end)

	it("T-021: dolu sunucu -- IlkGiris degeri tek basina girene 1, digerlerine 0", function()
		local values = {}
		for _, item in events(world, "IlkGiris") do
			values[item.user] = item.value
		end
		expect(values).toEqual({
			[P[1]] = 1,
			[P[2]] = 0,
			[P[3]] = 0,
			[P[4]] = 0,
			[P[5]] = 1,
			[P[6]] = 1,
			[P[7]] = 1,
		})
	end)

	it("T-021: Eslesme oturumda bir kez -- ikinci baglantida bekleme suresiyle, olmazsa cikista oturum suresiyle", function()
		local got = {}
		for _, item in events(world, "Eslesme") do
			table.insert(got, { item.user, item.fields.eslesti, item.value })
		end
		expect(got).toEqual({
			{ P[5], "hayir", 40 },
			{ P[1], "evet", 20 },
			{ P[2], "evet", 0 },
			{ P[3], "evet", 0 },
			{ P[4], "evet", 0 },
			{ P[8], "hayir", 30 },
			{ P[9], "hayir", 60 },
			{ P[5], "hayir", 60 },
			{ P[6], "hayir", 240 },
			{ P[7], "hayir", 420 },
			{ P[6], "hayir", 120 },
		})
	end)

	it("T-021: TurBasladi oturumda bir kez, rol ve giristen gecen sureyle; gec giren ilk turunda", function()
		local got = {}
		for _, item in events(world, "TurBasladi") do
			table.insert(got, { item.user, item.fields.rol, item.value })
		end
		expect(got).toEqual({
			{ P[1], "model", 35 },
			{ P[2], "cizen", 15 },
			{ P[3], "cizen", 10 },
			{ P[4], "cizen", 31 },
		})
	end)

	it("T-021: gec giren reveal'da izleyici; IlkReveal oturumda bir kez", function()
		local got = {}
		for _, item in events(world, "IlkReveal") do
			got[item.user] = item.fields.reveal_rol
		end
		expect(got).toEqual({ [P[1]] = "model", [P[2]] = "cizen", [P[3]] = "cizen", [P[4]] = "izleyici" })
		expect(#events(world, "IlkReveal")).toBe(4)
	end)

	it("T-021: TurTamam -- bos teslim, izleyen ve iptal edilen tur; tur sirasi oturumdaki tamamlanan tur", function()
		local got = {}
		for _, item in events(world, "TurTamam") do
			table.insert(got, { item.user, item.fields.tur_sirasi, item.fields.katilim })
		end
		table.sort(got, function(a, b)
			if a[2] ~= b[2] then
				return a[2] < b[2]
			end
			return a[1] < b[1]
		end)
		expect(got).toEqual({
			{ P[1], "1", "model" },
			{ P[2], "1", "bos_teslim" },
			{ P[3], "1", "cizdi" },
			{ P[4], "1", "izledi" },
			{ P[1], "2", "model" },
			{ P[3], "2", "cizdi" },
			{ P[4], "2", "cizdi" },
		})
	end)

	it("T-021: BesDakika yalniz ilk oturumda 300. saniyede, o anki durumla", function()
		local got = {}
		for _, item in events(world, "BesDakika") do
			got[item.user] = item.fields.o_an
		end
		expect(got).toEqual({ [P[1]] = "turda", [P[3]] = "turda", [P[4]] = "lobide", [P[7]] = "lobide" })
	end)

	it("T-021: Cikis -- oturum tipi ilk oturum kovasi, donus ya da bilinmiyor", function()
		local got = {}
		for _, item in events(world, "Cikis") do
			table.insert(got, { item.user, item.fields.oturum_tipi, item.value, item.fields.kohort })
		end
		expect(got).toEqual({
			{ P[5], "ilk_0-60", 40, DAY1 },
			{ P[2], "ilk_60-300", 120, DAY1 },
			{ P[1], "ilk_300+", 320, DAY1 },
			{ P[3], "ilk_300+", 305, DAY1 },
			{ P[4], "ilk_300+", 305, DAY1 },
			{ P[8], "bilinmiyor", 30, "bilinmiyor" },
			{ P[9], "donus", 60, "bilinmiyor" },
			{ P[5], "donus", 60, DAY1 },
			{ P[6], "ilk_60-300", 240, DAY1 },
			{ P[7], "ilk_300+", 420, DAY1 },
			{ P[6], "donus", 120, DAY1 },
		})
	end)

	it("T-021: gece yarisi donusu D1Donus gonderir; ayni gun tekrar giris ve cikmadan gecme gondermez", function()
		local got = {}
		for _, item in events(world, "D1Donus") do
			table.insert(got, { item.user, item.fields.kohort, item.fields.kaynak, item.fields.surum })
		end
		expect(got).toEqual({ { P[6], DAY1, "etiketli", Config.Surum } })
	end)

	it("T-021: ilk giris kaydi profile oyuncu numarasiyla bir kez yazilir", function()
		expect(world.profiles[P[5]].writes).toBe(1)
		expect(world.profiles[P[5]].record).toEqual({ day = DAY1, source = "etiketsiz", version = Config.Surum })
		expect(world.profiles[P[6]].record).toEqual({ day = DAY1, source = "etiketli", version = Config.Surum })
		expect(world.profiles[P[7]].record.day).toBe(DAY1)
		expect(world.profiles[P[8]].record).toBeNil()
		expect(world.profiles[P[9]].record).toBeNil()
	end)

	it("T-021: kullanici adi ve numarasi hicbir alana ve olay adina girmez", function()
		local keys = {}
		for index = 1, 3 do
			keys[Core.fieldKey(index)] = true
		end
		for _, entry in world.sent do
			expect(type(entry.value)).toBe("number")
			for _, id in P do
				expect(entry.value ~= id).toBe(true)
				expect(string.find(entry.name, tostring(id), 1, true)).toBeNil()
			end
			for key, value in entry.custom do
				expect(keys[key]).toBe(true)
				expect(string.find(value, "Oyuncu", 1, true)).toBeNil()
				for _, id in P do
					expect(string.find(value, tostring(id), 1, true)).toBeNil()
					expect(string.find(value, string.sub(tostring(id), -4), 1, true)).toBeNil()
				end
			end
		end
	end)
end)

describe("Olcum -- T-021 Okuma tablosu (gun 1 kohortu, tekil kullanici)", function()
	it("T-021: D1 = D1Donus tekil / IlkGiris tekil = 1/7, %95 Wilson araligi", function()
		local pay = unique(events(world, "D1Donus", cohort(DAY1)))
		expect({ pay, newcomers }).toEqual({ 1, 7 })
		local low, high = wilson(pay, newcomers)
		expect(low).toBeCloseTo(0.0257, 1e-4)
		expect(high).toBeCloseTo(0.5131, 1e-4)
	end)

	it("T-021: ortalama oturum -- ilk oturum 1750/7, tum oturumlar 1930/9", function()
		local first = events(world, "Cikis", both(cohort(DAY1), field("oturum_tipi", table.unpack(Config.Alanlar.oturum_tipi.Ilk))))
		expect(#first).toBe(7)
		expect(mean(first)).toBeCloseTo(1750 / 7)
		local all = events(world, "Cikis", cohort(DAY1))
		expect(#all).toBe(9)
		expect(mean(all)).toBeCloseTo(1930 / 9)
	end)

	it("T-021: ilk 60 sn'de cikan = Cikis ilk_0-60 tekil / IlkGiris = 1/7", function()
		local pay = unique(events(world, "Cikis", both(cohort(DAY1), field("oturum_tipi", "ilk_0-60"))))
		expect({ pay, newcomers }).toEqual({ 1, 7 })
	end)

	it("T-021: 5. dakikada hala oynayan = BesDakika tekil / IlkGiris = 4/7", function()
		local pay = unique(events(world, "BesDakika", cohort(DAY1)))
		expect({ pay, newcomers }).toEqual({ 4, 7 })
	end)

	it("T-021: ilk turu tamamlama = TurTamam sira 1 (model/cizdi/bos teslim) / IlkGiris = 3/7", function()
		local pay = unique(events(world, "TurTamam", both(
			both(cohort(DAY1), field("tur_sirasi", "1")),
			field("katilim", "model", "cizdi", "bos_teslim")
		)))
		expect({ pay, newcomers }).toEqual({ 3, 7 })
	end)

	it("T-021: tur zinciri R0 > R1 > R2 > R3 = 4/7, 4/7, 3/7, 0/7", function()
		local chain = { unique(events(world, "TurBasladi", both(cohort(DAY1), firstSession))) }
		for order = 1, 3 do
			table.insert(chain, unique(events(world, "TurTamam", both(cohort(DAY1), field("tur_sirasi", tostring(order))))))
		end
		expect(chain).toEqual({ 4, 4, 3, 0 })
	end)

	it("T-021: oylama anina ulasma = IlkReveal (ilk oturum) / IlkGiris = 4/7", function()
		local pay = unique(events(world, "IlkReveal", both(cohort(DAY1), firstSession)))
		expect({ pay, newcomers }).toEqual({ 4, 7 })
	end)

	it("T-021: baslayan mac orani = TurBasladi (ilk oturum) / IlkGiris = 4/7", function()
		local pay = unique(events(world, "TurBasladi", both(cohort(DAY1), firstSession)))
		expect({ pay, newcomers }).toEqual({ 4, 7 })
	end)

	it("T-021: ortalama bekleme = TurBasladi degerinin ortalamasi = 91/4", function()
		expect(mean(events(world, "TurBasladi", cohort(DAY1)))).toBeCloseTo(91 / 4)
	end)

	it("T-016: tek basina girenler = IlkGiris ortalamasi 4/7; Eslesme hayir orani 3/7", function()
		expect(mean(events(world, "IlkGiris", cohort(DAY1)))).toBeCloseTo(4 / 7)
		local all = events(world, "Eslesme", both(cohort(DAY1), firstSession))
		local alone = events(world, "Eslesme", both(both(cohort(DAY1), firstSession), field("eslesti", "hayir")))
		expect({ #alone, #all }).toEqual({ 3, 7 })
	end)

	it("T-021: reklam etiketli dilimi -- kaynak alani olan olaylarda: D1 1/2, oturum 280, ilk 60 sn 0/2, 5. dk 1/2", function()
		local tagged = field("kaynak", "etiketli")
		local payda = unique(events(world, "IlkGiris", both(cohort(DAY1), tagged)))
		expect(payda).toBe(2)
		expect(unique(events(world, "D1Donus", both(cohort(DAY1), tagged)))).toBe(1)
		local first = events(world, "Cikis", both(both(cohort(DAY1), tagged), field("oturum_tipi", table.unpack(Config.Alanlar.oturum_tipi.Ilk))))
		expect(mean(first)).toBeCloseTo(280)
		expect(unique(events(world, "Cikis", both(both(cohort(DAY1), tagged), field("oturum_tipi", "ilk_0-60"))))).toBe(0)
		expect(unique(events(world, "BesDakika", both(cohort(DAY1), tagged)))).toBe(1)
	end)
end)

describe("Olcum -- profil ve sinir durumlari", function()
	it("T-021: profil okunamazsa oyuncu yeni sayilmaz; 5 dakikadan uzun kalsa da BesDakika ve TurTamam gitmez", function()
		local w = newWorld(at(DAY1, 8))
		local s = newServer(w)
		w.profiles[1] = { loads = 0, writes = 0, fail = true }
		join(s, 1)
		advance(w, at(DAY1, 8, 6))
		leave(s, 1)
		expect(#events(w, "IlkGiris")).toBe(0)
		expect(#events(w, "BesDakika")).toBe(0)
		local exit = events(w, "Cikis")[1].fields
		expect(exit).toEqual({ kohort = "bilinmiyor", kaynak = "bilinmiyor", oturum_tipi = "bilinmiyor" })
		expect(events(w, "Eslesme")[1].fields.ilk_oturum).toBe("bilinmiyor")
	end)

	it("T-021: profil gelmeden cikan bilinmiyor; bekleyen olaylar o alanlarla gider", function()
		local w = newWorld(at(DAY1, 8))
		local s = newServer(w)
		join(s, 1, { later = true })
		join(s, 2, { later = true })
		advance(w, at(DAY1, 8, 0, 10))
		leave(s, 2)
		expect(events(w, "Eslesme", function(f)
			return f.ilk_oturum == "bilinmiyor"
		end)[1].user).toBe(2)
		resolve(s, 1)
		local first = events(w, "Eslesme", function(f)
			return f.ilk_oturum == "evet"
		end)
		expect(#first).toBe(1)
		expect(first[1].user).toBe(1)
		expect(first[1].value).toBe(0)
		expect(first[1].fields.kohort).toBe(DAY1)
		expect(#events(w, "IlkGiris")).toBe(1)
	end)

	it("T-021: ilk giris girisin UTC gunuyle kaydedilir, profil gece yarisindan sonra gelse de", function()
		local w = newWorld(at(DAY1, 23, 59, 59))
		local s = newServer(w)
		join(s, 1, { later = true })
		advance(w, at(DAY2, 0, 0, 2))
		resolve(s, 1)
		expect(w.profiles[1].record.day).toBe(DAY1)
		expect(events(w, "IlkGiris")[1].fields.kohort).toBe(DAY1)
	end)

	it("LaunchData giriste bos, profil aninda doluysa kaynak etiketli olur", function()
		local w = newWorld(at(DAY1, 8))
		local s = newServer(w)
		join(s, 1, { later = true })
		resolve(s, 1, TAG)
		expect(events(w, "IlkGiris")[1].fields.kaynak).toBe("etiketli")
		expect(w.profiles[1].record.source).toBe("etiketli")
	end)

	it("T-021: iki gun sonra donen ve eski F-001 oyuncusu D1Donus gondermez", function()
		local w = newWorld(at(DAY1, 8))
		local s = newServer(w)
		join(s, 1)
		leave(s, 1)
		advance(w, at(Day.after(DAY1, 2), 8))
		join(s, 1)
		leave(s, 1)
		w.profiles[2] = { loads = 7, writes = 0 }
		join(s, 2)
		leave(s, 2)
		expect(#events(w, "D1Donus")).toBe(0)
		expect(#events(w, "IlkGiris")).toBe(1)
	end)

	it("kohort araligi disindaki gun aralik_disi olarak gider, olay dusmez", function()
		local w = newWorld(at(Day.after(Config.Alanlar.kohort.Gunler.Son, 1), 8))
		local s = newServer(w)
		join(s, 1)
		leave(s, 1)
		expect(events(w, "IlkGiris")[1].fields.kohort).toBe("aralik_disi")
		expect(w.profiles[1].record.day).toBe(Day.after(Config.Alanlar.kohort.Gunler.Son, 1))
		expect(w.warnings).toEqual({})
	end)

	it("T-021: donus oturumunda TurTamam gitmez; TurBasladi ve IlkReveal ilk oturum mu = hayir ile gider", function()
		local w = newWorld(at(DAY1, 8))
		for id = 1, 2 do
			w.profiles[id] = { loads = 1, writes = 1, record = { day = DAY1, source = "etiketsiz", version = Config.Surum } }
		end
		local s = newServer(w)
		join(s, 1)
		join(s, 2)
		advance(w, at(DAY1, 8, 0, 20))
		submit(s, 1, 2)
		submit(s, 2, 2)
		advance(w, at(DAY1, 8, 1))
		expect(#events(w, "TurTamam")).toBe(0)
		expect(#events(w, "TurBasladi", field("ilk_oturum", "hayir"))).toBe(2)
		expect(#events(w, "IlkReveal", field("ilk_oturum", "hayir"))).toBe(2)
		expect(#events(w, "IlkGiris")).toBe(0)
	end)

	it("T-021: BesDakika o an -- tur suruyor ama oyuncu turda degilse beklemede", function()
		local w = newWorld(at(DAY1, 8))
		local s = newServer(w)
		join(s, 1)
		local machine = { phase = "Drawing", players = {}, round = { participantOrder = { 99 }, subject = { id = 99 } } }
		w.now += Config.BesDakikaSaniye
		Metrics.observe(s.metrics, machine, w.now)
		expect(events(w, "BesDakika")[1].fields.o_an).toBe("beklemede")
	end)

	it("T-021: tur sirasi 5. turdan sonra 5+ kovasinda", function()
		local w = newWorld(at(DAY1, 8))
		local s = newServer(w)
		join(s, 1)
		join(s, 2)
		for _ = 1, 6 do
			advance(w, w.now + RoundTest.LobbyCountdownSeconds + RoundTest.TransitionSeconds)
			submit(s, 1, 1)
			submit(s, 2, 1)
			advance(w, w.now + RoundTest.TransitionSeconds + 2 * RoundTest.RevealSecondsPerDrawing + RoundTest.PodiumSeconds + 1)
		end
		local orders = {}
		for _, item in events(w, "TurTamam", function(f)
			return true
		end) do
			if item.user == 1 then
				table.insert(orders, item.fields.tur_sirasi)
			end
		end
		expect(orders).toEqual({ "1", "2", "3", "4", "5+", "5+" })
	end)
end)
