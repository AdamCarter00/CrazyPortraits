--!nocheck

local Machine = require(Shared.Round.Machine)
local RoundConfig = require(Shared.Config.Round)
local Schema = require(Shared.Net.Schema)

local function firstCandidate(candidates)
	return candidates[1]
end

local function newMachine()
	return Machine.new({ config = RoundConfig, pickSubject = firstCandidate })
end

local function find(effects, name, to)
	for _, effect in effects do
		if effect.name == name and (to == nil or effect.to == to) then
			return effect
		end
	end
	return nil
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

	it("is-1: tura katilmayan teslim edemez, ikinci teslim yok sayilir", function()
		local state, t = startedRound(2)
		addReady(state, 9, t + 1)
		Machine.submit(state, 9, drawing(), 5, t + 2)
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
		for _, name in { "Lobby", "Drawing", "Collect", "Reveal", "VoteAccepted", "Podium" } do
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
