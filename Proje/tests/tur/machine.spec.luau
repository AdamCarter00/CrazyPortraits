--!nocheck

local Machine = require(Shared.Round.Machine)
local RoundConfig = require(Shared.Config.Round)
local Schema = require(Shared.Net.Schema)

local function firstCandidate(candidates)
	return candidates[1]
end

local TestConfig = table.clone(RoundConfig)
TestConfig.MinPlayers = 2

local function newMachine()
	return Machine.new({ config = TestConfig, random = function() return 0 end })
end

local function find(effects, name, to)
	for _, effect in effects do
		if effect.name == name and (to == nil or effect.to == to) then
			return effect
		end
	end
	return nil
end

local function readyIds(state)
	local list = {}
	for id, p in state.players do
		if p.ready then
			table.insert(list, id)
		end
	end
	return list
end

local function addReady(state, id, now)
	Machine.join(state, id, "P" .. id, now)
	return Machine.ready(state, id, now)
end

local function startedRound(count)
	local state = newMachine()
	for id = 1, count or 2 do
		addReady(state, id, 0)
	end
	Machine.tick(state, RoundConfig.LobbyCountdownSeconds)
	return state, RoundConfig.LobbyCountdownSeconds
end

local function drawing()
	local b = buffer.create(1)
	return b
end

local function submitAll(state, ids, now)
	local out
	for _, id in ids do
		out = Machine.submit(state, id, drawing(), 3, now)
	end
	return out
end

describe("Tur -- lobi", function()
	it("is-1: yeterli hazir oyuncu olunca geri sayim baslar ve yeni gelen sayaci sifirlamaz", function()
		local state = newMachine()
		addReady(state, 1, 0)
		local out = addReady(state, 2, 1)
		local lobby = find(out, "Lobby", "all")
		expect(lobby.payload.status).toBe("countdown")
		expect(lobby.payload.endsAt).toBe(1 + RoundConfig.LobbyCountdownSeconds)
		out = addReady(state, 3, 5)
		expect(find(out, "Lobby", "all").payload.endsAt).toBe(1 + RoundConfig.LobbyCountdownSeconds)
	end)

	it("is-1: oyuncu sayisi duserse lobi durumu yeniden yayinlanir, tur baslamaz", function()
		local state = newMachine()
		addReady(state, 1, 0)
		addReady(state, 2, 0)
		local out = Machine.leave(state, 2, 3)
		local lobby = find(out, "Lobby", "all")
		expect(lobby.payload.status).toBe("waiting")
		expect(lobby.payload.endsAt).toBeNil()
		Machine.tick(state, 100)
		expect(state.phase).toBe("Lobby")
	end)

	it("is-1: oyuncu durumu olusmadan gelen Ready kaybolmaz", function()
		local state = newMachine()
		addReady(state, 1, 0)
		Machine.ready(state, 2, 0)
		local out = Machine.join(state, 2, "P2", 1)
		expect(find(out, "Lobby", "all").payload.readyCount).toBe(2)
		expect(state.countdownEndsAt).toBe(1 + RoundConfig.LobbyCountdownSeconds)
	end)

	it("is-1: tek basina hazir olan icin tur baslamaz", function()
		local state = newMachine()
		addReady(state, 1, 0)
		Machine.tick(state, 1000)
		expect(state.phase).toBe("Lobby")
	end)
end)

describe("Tur -- cizim", function()
	it("T-002: herkes teslim edince sure dolmadan tur gosterime gecer", function()
		local state, t = startedRound(2)
		expect(state.phase).toBe("Drawing")
		local out = submitAll(state, { 1, 2 }, t + 10)
		expect(state.phase).toBe("Reveal")
		expect(find(out, "Reveal", "all")).toBeTruthy()
	end)

	it("T-002: cizim suresinin ust siniri Config'teki deger (140 sn)", function()
		expect(RoundConfig.DrawSeconds).toBe(140)
		local state, t = startedRound(2)
		local endsAt = state.round.endsAt
		expect(endsAt).toBe(t + RoundConfig.TransitionSeconds + RoundConfig.DrawSeconds)
		Machine.tick(state, endsAt - 0.01)
		expect(state.phase).toBe("Drawing")
		local out = Machine.tick(state, endsAt)
		expect(state.phase).toBe("Collecting")
		expect(find(out, "Collect", "all")).toBeTruthy()
	end)

	it("T-003: cogunluk teslim etse de cizim kisalmaz", function()
		local state, t = startedRound(3)
		submitAll(state, { 1, 2 }, t + 5)
		Machine.tick(state, t + 60)
		expect(state.phase).toBe("Drawing")
	end)

	it("T-002: toplama, gec kalanlar gelince ya da zaman asiminda biter", function()
		local state = startedRound(2)
		local endsAt = state.round.endsAt
		Machine.tick(state, endsAt)
		Machine.submit(state, 1, drawing(), 2, endsAt + 1)
		expect(state.phase).toBe("Collecting")
		Machine.tick(state, endsAt + RoundConfig.CollectTimeoutSeconds)
		expect(state.phase).toBe("Reveal")
		expect(#state.round.reveal.list).toBe(1)
	end)

	it("is-1: teslim edip cikanin cizimi gosterimde kalir", function()
		local state, t = startedRound(3)
		Machine.submit(state, 1, drawing(), 2, t + 5)
		Machine.leave(state, 1, t + 6)
		submitAll(state, { 2, 3 }, t + 7)
		expect(state.phase).toBe("Reveal")
		expect(state.round.reveal.list[1].ownerId).toBe(1)
	end)

	it("is-1: teslim etmeden cikan beklenmez", function()
		local state, t = startedRound(2)
		Machine.submit(state, 1, drawing(), 2, t + 5)
		Machine.leave(state, 2, t + 6)
		expect(state.phase).toBe("Reveal")
	end)

	it("K-005: bos cizim gosterilmez; hic dolu cizim yoksa tur lobiye doner", function()
		local state, t = startedRound(2)
		Machine.submit(state, 1, drawing(), 0, t + 1)
		local out = Machine.submit(state, 2, drawing(), 0, t + 2)
		expect(state.phase).toBe("Lobby")
		expect(find(out, "Lobby", "all")).toBeTruthy()
	end)

	it("is-1: tura katilmayan teslim edemez, ikinci teslim yok sayilir", function()
		local state, t = startedRound(2)
		local late = state.round.endsAt - RoundConfig.MidJoinMinSeconds
		addReady(state, 9, late)
		Machine.submit(state, 9, drawing(), 5, late + 1)
		expect(state.round.drawings[9]).toBeNil()
		Machine.submit(state, 1, drawing(), 2, t + 3)
		Machine.submit(state, 1, drawing(), 7, t + 4)
		expect(state.round.drawings[1].strokeCount).toBe(2)
	end)
end)

describe("Tur -- gosterim ve oy", function()
	local function inReveal(count)
		local ids = {}
		for id = 1, count do
			table.insert(ids, id)
		end
		local state, t = startedRound(count)
		submitAll(state, ids, t + 1)
		return state, t + 1
	end

	it("T-006: oy cizim kimligiyle gelir ve sunucu onaylar", function()
		local state, t = inReveal(2)
		local current = state.round.reveal.list[1]
		local out = Machine.vote(state, 2, current.drawingId, "laugh", t)
		local ack = find(out, "VoteAccepted", 2)
		expect(ack.payload.drawingId).toBe(current.drawingId)
		expect(ack.payload.emoji).toBe("laugh")
	end)

	it("K-006: kabul edilen oy canli toplami herkese yayinlar; oy veren kimlik tasimaz", function()
		local state, t = inReveal(3)
		local current = state.round.reveal.list[1]
		Machine.vote(state, 2, current.drawingId, "laugh", t)
		local out = Machine.vote(state, 3, current.drawingId, "normal", t)
		local tallyEffect = find(out, "Tally", "all")
		expect(tallyEffect.payload.drawingId).toBe(current.drawingId)
		expect(tallyEffect.payload.reactions.laugh).toBe(1)
		expect(tallyEffect.payload.reactions.normal).toBe(1)
		expect(tallyEffect.payload.score).toBe(1)
		for key in tallyEffect.payload do
			expect(key == "drawingId" or key == "reactions" or key == "score").toBe(true)
		end
		Schema.shape("Tally", tallyEffect.payload)
	end)

	it("K-006: sahibin kendi oyu canli toplama da girmez; reddedilen oy toplam yayinlamaz", function()
		local state, t = inReveal(2)
		local current = state.round.reveal.list[1]
		local out = Machine.vote(state, current.ownerId, current.drawingId, "laugh", t)
		expect(find(out, "Tally", "all").payload.score).toBe(0)
		expect(find(Machine.vote(state, 2, current.drawingId, "bomb", t), "Tally")).toBeNil()
	end)

	it("K-006: gosterim sirasinda giren mevcut toplami da alir", function()
		local state, t = inReveal(3)
		local current = state.round.reveal.list[1]
		Machine.vote(state, 2, current.drawingId, "skull", t)
		Machine.join(state, 7, "P7", t + 1)
		local out = Machine.ready(state, 7, t + 1)
		expect(find(out, "Tally", 7).payload.reactions.skull).toBe(1)
	end)

	it("T-006: gec gelen oy yanlis cizime yazilmaz", function()
		local state, t = inReveal(2)
		local first = state.round.reveal.list[1]
		Machine.tick(state, state.round.reveal.endsAt)
		expect(state.round.reveal.index).toBe(2)
		local out = Machine.vote(state, 2, first.drawingId, "skull", state.round.reveal.endsAt)
		expect(#out).toBe(0)
		local second = state.round.reveal.list[2]
		expect(state.round.votes[second.drawingId]).toBeNil()
	end)

	it("T-006: gecersiz emoji kabul edilmez", function()
		local state, t = inReveal(2)
		local out = Machine.vote(state, 2, state.round.reveal.list[1].drawingId, "bomb", t)
		expect(#out).toBe(0)
	end)

	it("T-006: oyuncunun son secimi sayilir", function()
		local state, t = inReveal(2)
		local id = state.round.reveal.list[1].drawingId
		Machine.vote(state, 2, id, "laugh", t)
		Machine.vote(state, 2, id, "skull", t)
		Machine.tick(state, state.round.reveal.endsAt)
		local podium = find(Machine.tick(state, state.round.reveal.endsAt), "Podium", "all")
		expect(podium.payload.entries[1].reactions.skull).toBe(1)
		expect(podium.payload.entries[1].reactions.laugh).toBe(0)
	end)

	it("T-008: sahibi kendi cizimine emoji atabilir ama sayilmaz", function()
		local state, t = inReveal(2)
		local current = state.round.reveal.list[1]
		local out = Machine.vote(state, current.ownerId, current.drawingId, "laugh", t)
		expect(find(out, "VoteAccepted", current.ownerId)).toBeTruthy()
		Machine.tick(state, state.round.reveal.endsAt)
		local podium = find(Machine.tick(state, state.round.reveal.endsAt), "Podium", "all")
		expect(podium.payload.entries[1].reactions.laugh).toBe(0)
	end)

	it("T-009: gosterim sirasinda giren hemen gosterimi gorur ve oy verir", function()
		local state, t = inReveal(2)
		Machine.join(state, 7, "P7", t + 1)
		local out = Machine.ready(state, 7, t + 1)
		local reveal = find(out, "Reveal", 7)
		expect(reveal).toBeTruthy()
		expect(reveal.payload.drawingId).toBe(state.round.reveal.list[1].drawingId)
		expect(type(reveal.payload.drawing)).toBe("buffer")
		out = Machine.vote(state, 7, reveal.payload.drawingId, "shocked", t + 2)
		expect(find(out, "VoteAccepted", 7)).toBeTruthy()
	end)

	it("is-1: tur sonu sonuclari herkese yayinlanir, sahibin oyu haric sayilir", function()
		local state, t = inReveal(3)
		local list = state.round.reveal.list
		Machine.vote(state, 2, list[1].drawingId, "laugh", t)
		Machine.vote(state, 3, list[1].drawingId, "laugh", t)
		Machine.vote(state, 1, list[1].drawingId, "skull", t)
		Machine.tick(state, state.round.reveal.endsAt)
		Machine.vote(state, 1, list[2].drawingId, "normal", state.round.reveal.endsAt)
		Machine.tick(state, state.round.reveal.endsAt)
		local out = Machine.tick(state, state.round.reveal.endsAt)
		local podium = find(out, "Podium", "all")
		expect(#podium.payload.entries).toBe(3)
		expect(podium.payload.entries[1].reactions.laugh).toBe(2)
		expect(podium.payload.entries[1].reactions.skull).toBe(0)
		expect(podium.payload.entries[2].reactions.normal).toBe(1)
		expect(podium.payload.entries[1].ownerName).toBe("P1")
	end)

	it("is-1: podyumdan sonra lobi yayinlanir ve geri sayim kendiliginden baslar", function()
		local state = inReveal(2)
		Machine.tick(state, state.round.reveal.endsAt)
		Machine.tick(state, state.round.reveal.endsAt)
		local out = Machine.tick(state, state.round.podiumEndsAt)
		expect(state.phase).toBe("Lobby")
		expect(find(out, "Lobby", "all").payload.status).toBe("countdown")
	end)

	it("is-1: model cikarsa tur ve adi kalir", function()
		local state, t = startedRound(3)
		local subject = state.round.subject
		Machine.leave(state, subject.id, t + 1)
		expect(state.phase).toBe("Drawing")
		expect(state.round.subject.name).toBe("P" .. subject.id)
	end)
end)

describe("Tur -- istemciye giden veri", function()
	it("T-001: tura tema verilmez", function()
		local state = startedRound(2)
		expect(Schema.Messages.Drawing.fields.theme).toBeNil()
		expect(state.round.theme).toBeNil()
	end)

	it("is-1: makinenin urettigi her mesaj beyaz listeden gecer", function()
		local all = {}
		local function keep(effects)
			for _, effect in effects do
				table.insert(all, effect)
			end
		end
		local state = newMachine()
		for id = 1, 3 do
			Machine.join(state, id, "P" .. id, 0)
			keep(Machine.ready(state, id, 0))
		end
		keep(Machine.tick(state, RoundConfig.LobbyCountdownSeconds))
		keep(Machine.ready(state, 1, 16))
		keep(Machine.tick(state, state.round.endsAt))
		keep(Machine.submit(state, 1, drawing(), 2, state.round.collectEndsAt - 1))
		keep(Machine.submit(state, 2, drawing(), 2, state.round.collectEndsAt - 1))
		keep(Machine.tick(state, state.round.collectEndsAt))
		keep(Machine.vote(state, 3, state.round.reveal.list[1].drawingId, "laugh", 0))
		keep(Machine.ready(state, 3, 0))
		keep(Machine.tick(state, state.round.reveal.endsAt))
		keep(Machine.tick(state, state.round.reveal.endsAt))
		keep(Machine.ready(state, 3, 0))
		keep(Machine.tick(state, state.round.podiumEndsAt))

		local seen = {}
		for _, effect in all do
			Schema.shape(effect.name, effect.payload)
			seen[effect.name] = true
		end
		for _, name in { "Lobby", "Drawing", "Collect", "Reveal", "VoteAccepted", "Tally", "Podium" } do
			expect(seen[name]).toBe(true)
		end
	end)

	it("is-1: beyaz listede olmayan alan ya da mesaj hata verir", function()
		expect(function()
			Schema.shape("Lobby", { status = "waiting", readyCount = 1, minPlayers = 2, secret = 1 })
		end).toThrow("beyaz listede olmayan alan")
		expect(function()
			Schema.shape("Gizli", {})
		end).toThrow("beyaz listede olmayan mesaj")
	end)

	it("is-1: cizimin kendisi gosterimden once kimseye gitmez", function()
		local state, t = startedRound(2)
		local out = Machine.submit(state, 1, drawing(), 2, t + 1)
		expect(#out).toBe(0)
	end)
end)

describe("Tur -- model secimi", function()
	local function roundWith(count, random)
		local state = Machine.new({ config = RoundConfig, random = random })
		for id = 1, count do
			addReady(state, id, 0)
		end
		Machine.tick(state, RoundConfig.LobbyCountdownSeconds)
		return state
	end

	local function nextRound(state)
		submitAll(state, state.round.participantOrder, 100)
		Machine.tick(state, state.round.reveal.endsAt)
		for _ = 1, #state.round.reveal.list do
			Machine.tick(state, state.round.reveal.endsAt)
		end
		Machine.tick(state, state.round.podiumEndsAt)
		local t = state.countdownEndsAt
		Machine.tick(state, t)
	end

	it("K-001: bir onceki model aday olmaz; iki kisilikte sira katidir", function()
		local state = roundWith(2, function()
			return 0
		end)
		local first = state.round.subject.id
		nextRound(state)
		expect(state.round.subject.id).never.toBe(first)
	end)

	it("K-001: agirlik, secilmeden gecen tur sayisi + 1", function()
		local state = roundWith(3, function()
			return 0.999
		end)
		expect(state.round.subject.id).toBe(3)
		expect(state.missed[3]).toBe(0)
		expect(state.missed[1]).toBe(1)
		local state2 = Machine.new({ config = RoundConfig, random = function() return 0.5 end })
		state2.missed = { [1] = 0, [2] = 0, [3] = 8 }
		for id = 1, 3 do
			addReady(state2, id, 0)
		end
		Machine.tick(state2, RoundConfig.LobbyCountdownSeconds)
		expect(state2.round.subject.id).toBe(3)
	end)

	it("K-001: secim tohumlu rastgele ile tekrarlanir", function()
		local function run()
			local seed = 7
			local state = roundWith(4, function()
				seed = (seed * 1103515245 + 12345) % 2147483648
				return seed / 2147483648
			end)
			return state.round.subject.id
		end
		expect(run()).toBe(run())
	end)
end)

describe("Tur -- cizim sirasinda giris", function()
	it("K-002: yeterli sure varsa giren o turda cizer", function()
		local state, t = startedRound(2)
		Machine.join(state, 5, "P5", t + 1)
		local out = Machine.ready(state, 5, t + 1)
		expect(find(out, "Drawing", 5)).toBeTruthy()
		expect(state.round.awaiting[5]).toBe(true)
		submitAll(state, { 1, 2 }, t + 5)
		expect(state.phase).toBe("Drawing")
		Machine.submit(state, 5, drawing(), 1, t + 6)
		expect(state.phase).toBe("Reveal")
	end)

	it("K-002: sure yetmiyorsa izler ve sonraki tura girer", function()
		local state, t = startedRound(2)
		local late = state.round.endsAt - RoundConfig.MidJoinMinSeconds
		addReady(state, 5, late)
		expect(state.round.awaiting[5]).toBeNil()
		submitAll(state, { 1, 2 }, late + 1)
		Machine.tick(state, state.round.reveal.endsAt)
		Machine.tick(state, state.round.reveal.endsAt)
		Machine.tick(state, state.round.podiumEndsAt)
		expect(state.countdownEndsAt).toBeTruthy()
		expect(#readyIds(state)).toBe(3)
	end)
end)

describe("Tur -- podyum", function()
	local function podiumAfter(count, votes)
		local state, t = startedRound(count)
		local ids = {}
		for id = 1, count do
			table.insert(ids, id)
		end
		submitAll(state, ids, t + 1)
		local list = state.round.reveal.list
		local out
		for index = 1, count do
			for _, vote in votes[index] or {} do
				Machine.vote(state, vote[1], list[index].drawingId, vote[2], state.round.reveal.startsAt)
			end
			out = Machine.tick(state, state.round.reveal.endsAt)
		end
		return find(out, "Podium", "all").payload
	end

	it("K-003: toplam tepkiyle siralanir, notr emoji sayilmaz", function()
		local podium = podiumAfter(4, {
			[1] = { { 2, "normal" }, { 3, "normal" }, { 4, "normal" } },
			[2] = { { 1, "laugh" } },
			[3] = { { 1, "skull" }, { 2, "shocked" }, { 4, "laugh" } },
		})
		expect(podium.entries[1].ownerUserId).toBe(3)
		expect(podium.entries[1].score).toBe(3)
		expect(podium.entries[2].ownerUserId).toBe(2)
		expect(podium.entries[3].score).toBe(0)
	end)

	it("K-003: ilk 3 gosterilir, esitlikte once gosterilen one gecer", function()
		local podium = podiumAfter(4, {})
		expect(#podium.entries).toBe(3)
		expect(podium.entries[1].ownerUserId).toBe(1)
		expect(podium.entries[3].ownerUserId).toBe(3)
		expect(podium.entries[1].rank).toBe(1)
	end)

	it("T-007: iki kisilik masada iki cizim yan yana", function()
		local podium = podiumAfter(2, {})
		expect(#podium.entries).toBe(2)
	end)

	it("T-007: podyum girisleri cizimi tasir; yalniz gosterilmis ilk 3 cizim gider", function()
		local podium = podiumAfter(5, {})
		expect(#podium.entries).toBe(3)
		for _, entry in podium.entries do
			expect(type(entry.drawing)).toBe("buffer")
		end
		Schema.shape("Podium", podium)
	end)

	it("T-009: podyum sirasinda giren, podyumu cizimleriyle birlikte gorur", function()
		local state, t = startedRound(3)
		submitAll(state, { 1, 2, 3 }, t + 1)
		for _ = 1, 3 do
			Machine.tick(state, state.round.reveal.endsAt)
		end
		expect(state.phase).toBe("Podium")
		Machine.join(state, 9, "P9", state.round.podiumEndsAt - 1)
		local out = Machine.ready(state, 9, state.round.podiumEndsAt - 1)
		local snapshot = find(out, "Podium", 9)
		expect(snapshot).toBeTruthy()
		expect(type(snapshot.payload.entries[1].drawing)).toBe("buffer")
	end)

	it("K-003: sahibinin kendi emojisi siralamayi etkilemez", function()
		local podium = podiumAfter(3, { [1] = { { 1, "laugh" }, { 1, "laugh" } }, [2] = { { 1, "laugh" } } })
		expect(podium.entries[1].ownerUserId).toBe(2)
	end)
end)
