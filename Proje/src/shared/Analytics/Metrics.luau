--!strict

local Day = require(script.Parent.Day)

export type Record = { day: string, source: string, version: string }
export type ProfileResult = { ok: boolean, record: Record?, fresh: boolean? }
export type Action = { kind: string, userId: number, phase: string, round: any }

local Metrics = {}

local Status = table.freeze({
	New = "yeni",
	Returning = "kayitli",
	Legacy = "eski",
	Unknown = "bilinmiyor",
})

local function bucket(labels: { string }, limits: { number }, value: number): string
	for index, limit in limits do
		if value < limit then
			return labels[index]
		end
	end
	return labels[#labels]
end

local function seconds(value: number): number
	return math.floor(value + 0.5)
end

local function isParticipant(round, id: number): boolean
	return round ~= nil and table.find(round.participantOrder, id) ~= nil
end

local function drawingPhase(phase: string): boolean
	return phase == "Drawing" or phase == "Collecting"
end

local function drawStart(round): number
	return round.countdownEndsAt or round.startsAt
end

function Metrics.new(deps: { config: any, core: any })
	return {
		config = deps.config,
		core = deps.core,
		players = {},
		completedRound = nil :: number?,
		submits = { round = nil :: any, seen = {} },
		shown = nil :: any,
		departed = { round = nil :: any, cohorts = {} },
	}
end

function Metrics.source(config, launchData: any): string
	if type(launchData) == "string" and launchData ~= "" then
		return config.Kaynak.Etiketli
	end
	return config.Kaynak.Etiketsiz
end

function Metrics.cohort(config, day: string?, source: string?): string
	local spec = config.Alanlar.kohort
	if day == nil or source == nil or not Day.isDay(day) then
		return spec.Bilinmiyor
	end
	local days = spec.Bilesik[1]
	local part = if day < days.Gunler.Ilk or day > days.Gunler.Son then days.AralikDisi else day
	return part .. spec.Ayirac .. source
end

local function describeProfile(config, status: string, record: Record?)
	local firstSession = config.Alanlar.ilk_oturum
	return {
		status = status,
		record = record,
		cohort = Metrics.cohort(config, record and record.day, record and record.source),
		firstSession = if status == Status.New
			then firstSession.Evet
			elseif status == Status.Unknown then firstSession.Bilinmiyor
			else firstSession.Hayir,
	}
end

local function send(m, player, key: string, value: number, build: (info: any) -> { [string]: string }?)
	local fields = build(player.info)
	if fields then
		m.core:log(player.id, key, value, fields)
	end
end

local function event(m, player, key: string, value: number, build: (info: any) -> { [string]: string }?)
	if player.info then
		send(m, player, key, value, build)
	else
		table.insert(player.pending, { key = key, value = value, build = build })
	end
end

local function settle(m, player, info)
	player.info = info
	local pending = player.pending
	player.pending = {}
	for _, item in pending do
		send(m, player, item.key, item.value, item.build)
	end
end

local function matched(m, player, value: number)
	player.matched = true
	local config = m.config
	event(m, player, "Eslesme", seconds(value), function(info)
		return { eslesti = config.Alanlar.eslesti.Evet, kohort = info.cohort, ilk_oturum = info.firstSession }
	end)
end

function Metrics.join(m, id: number, now: number, launchData: any)
	if m.players[id] then
		return
	end
	local others = 0
	for _ in m.players do
		others += 1
	end
	local player = {
		id = id,
		joinedAt = now,
		alone = others == 0,
		source = Metrics.source(m.config, launchData),
		info = nil :: any,
		pending = {},
		matched = false,
		phase = m.config.Alanlar.faz.Lobi,
		drawRound = nil :: any,
		drawStartedAt = 0,
		progress = { round = nil :: any, strokes = 0 },
		fiveMinutes = false,
		startedRound = false,
		sawReveal = false,
		roundsCompleted = 0,
	}
	m.players[id] = player
	if others > 0 then
		matched(m, player, 0)
		for _, other in m.players do
			if not other.matched then
				matched(m, other, now - other.joinedAt)
			end
		end
	end
end

function Metrics.profile(m, id: number, now: number, result: ProfileResult, launchData: any): Record?
	local player = m.players[id]
	if not player or player.info then
		return nil
	end
	local config = m.config
	if Metrics.source(config, launchData) == config.Kaynak.Etiketli then
		player.source = config.Kaynak.Etiketli
	end
	local write: Record? = nil
	local info
	if not result.ok then
		info = describeProfile(config, Status.Unknown, nil)
	elseif result.record then
		info = describeProfile(config, Status.Returning, result.record)
	elseif result.fresh then
		write = { day = Day.fromUnix(player.joinedAt), source = player.source, version = config.Surum }
		info = describeProfile(config, Status.New, write)
	else
		info = describeProfile(config, Status.Legacy, nil)
	end

	local record = info.record
	if info.status == Status.New then
		m.core:log(id, "IlkGiris", if player.alone then 1 else 0, { kohort = info.cohort, surum = record.version })
	elseif info.status == Status.Returning and Day.fromUnix(player.joinedAt) == Day.after(record.day, 1) then
		m.core:log(id, "D1Donus", 1, { kohort = info.cohort, surum = record.version })
	end
	settle(m, player, info)
	return write
end

local function sessionType(config, info, duration: number): string
	local values = config.Alanlar.oturum_tipi
	if info.status == Status.New then
		return bucket(values.Ilk, config.IlkOturumSinirlari, duration)
	elseif info.status == Status.Unknown then
		return values.Bilinmiyor
	end
	return values.Donus
end

function Metrics.leave(m, id: number, now: number)
	local player = m.players[id]
	if not player then
		return
	end
	local config = m.config
	if not player.info then
		settle(m, player, describeProfile(config, Status.Unknown, nil))
	end
	local duration = now - player.joinedAt
	local info = player.info
	if player.phase == config.Alanlar.faz.CizimTeslimsiz and player.drawRound then
		local strokes = if player.progress.round == player.drawRound then player.progress.strokes else 0
		m.core:log(id, "CizimdeCikis", seconds(math.max(now - player.drawStartedAt, 0)), {
			cizgi = bucket(config.Alanlar.cizgi, config.CizgiSinirlari, strokes),
			kohort = info.cohort,
			ilk_oturum = info.firstSession,
		})
	end
	if not player.matched then
		m.core:log(id, "Eslesme", seconds(duration), {
			eslesti = config.Alanlar.eslesti.Hayir,
			kohort = info.cohort,
			ilk_oturum = info.firstSession,
		})
	end
	m.core:log(id, "Cikis", seconds(duration), {
		kohort = info.cohort,
		oturum_tipi = sessionType(config, info, duration),
		faz = player.phase,
	})
	m.departed.cohorts[id] = info.cohort
	m.players[id] = nil
end

local function phaseOf(config, machine, id: number): string
	local values = config.Alanlar.faz
	local phase = machine.phase
	local round = machine.round
	if phase == "Reveal" then
		return values.Reveal
	elseif phase == "Podium" then
		return values.Podyum
	elseif drawingPhase(phase) and round then
		if not isParticipant(round, id) then
			return values.Izliyor
		end
		return if round.awaiting[id] then values.CizimTeslimsiz else values.TeslimSonrasi
	end
	return values.Lobi
end

local function moment(config, machine, id: number): string
	local values = config.Alanlar.o_an
	if machine.phase == "Lobby" or machine.round == nil then
		return values.Lobide
	elseif isParticipant(machine.round, id) then
		return values.Turda
	end
	return values.Beklemede
end

local function participation(config, round, id: number): string
	local values = config.Alanlar.katilim
	if round.subject.id == id then
		return values.Model
	elseif isParticipant(round, id) then
		local drawing = round.drawings[id]
		return if drawing and drawing.strokeCount > 0 then values.Cizdi else values.BosTeslim
	end
	return values.Izledi
end

local function firstSessionOnly(info): boolean
	return info.status == Status.New
end

local function onSubmit(m, action: Action, now: number)
	local round = action.round
	local id = action.userId
	local player = m.players[id]
	if not round or not player or not drawingPhase(action.phase) then
		return
	end
	local drawing = round.drawings[id]
	local submits = m.submits
	if submits.round ~= round then
		submits.round = round
		submits.seen = {}
	end
	if not drawing or submits.seen[id] then
		return
	end
	submits.seen[id] = true
	local config = m.config
	local how = if action.phase == "Drawing" then config.Alanlar.nasil.Dugme else config.Alanlar.nasil.SureDoldu
	local strokes = bucket(config.Alanlar.cizgi, config.CizgiSinirlari, drawing.strokeCount)
	event(m, player, "Teslim", seconds(math.max(now - drawStart(round), 0)), function(info)
		return { nasil = how, cizgi = strokes, kohort = info.cohort }
	end)
end

local function representative(m)
	local chosen = nil
	for _, player in m.players do
		if chosen == nil or player.joinedAt < chosen.joinedAt or (player.joinedAt == chosen.joinedAt and player.id < chosen.id) then
			chosen = player
		end
	end
	return chosen
end

local function finishShown(m)
	local shown = m.shown
	m.shown = nil
	local eligible, reacted = 0, 0
	local votes = shown.round.votes[shown.entry.drawingId] or {}
	for id in shown.viewers do
		eligible += 1
		if votes[id] ~= nil then
			reacted += 1
		end
	end
	if eligible == 0 then
		return
	end
	local config = m.config
	local screen = bucket(config.Alanlar.ekrandaki, config.EkrandakiSinirlari, eligible)
	local value = seconds(100 * reacted / eligible)
	local left = config.Alanlar.sahibi_cikti
	local owner = m.players[shown.entry.ownerId]
	if owner then
		event(m, owner, "CizimTepki", value, function(info)
			return { ekrandaki = screen, sahibi_cikti = left.Hayir, kohort = info.cohort }
		end)
		return
	end
	local stand = representative(m)
	if stand then
		m.core:log(stand.id, "CizimTepki", value, {
			ekrandaki = screen,
			sahibi_cikti = left.Evet,
			kohort = m.departed.cohorts[shown.entry.ownerId] or config.Alanlar.kohort.Bilinmiyor,
		})
	end
end

local function trackReveal(m, machine)
	local round = machine.round
	local current = nil
	if machine.phase == "Reveal" and round and round.reveal then
		current = round.reveal.list[round.reveal.index]
	end
	if m.shown and m.shown.entry ~= current then
		finishShown(m)
	end
	if current == nil then
		return
	end
	if not m.shown then
		m.shown = { round = round, entry = current, viewers = {} }
	end
	for id, state in machine.players do
		if state.ready and id ~= current.ownerId then
			m.shown.viewers[id] = true
		end
	end
end

function Metrics.observe(m, machine, now: number, action: Action?)
	local config = m.config
	if action and action.kind == "submit" then
		onSubmit(m, action, now)
	elseif action and action.kind == "progress" then
		local player = m.players[action.userId]
		if player and action.round and drawingPhase(action.phase) then
			player.progress = { round = action.round, strokes = action.strokes }
		end
	end
	if m.departed.round ~= machine.round then
		m.departed = { round = machine.round, cohorts = {} }
	end
	trackReveal(m, machine)

	for id, player in m.players do
		if machine.players[id] then
			player.phase = phaseOf(config, machine, id)
			if player.phase == config.Alanlar.faz.CizimTeslimsiz and player.drawRound ~= machine.round then
				player.drawRound = machine.round
				player.drawStartedAt = math.max(now, drawStart(machine.round))
			end
		end
		if not player.fiveMinutes and now - player.joinedAt >= config.BesDakikaSaniye then
			player.fiveMinutes = true
			local at = moment(config, machine, id)
			event(m, player, "BesDakika", 1, function(info)
				if not firstSessionOnly(info) then
					return nil
				end
				return { kohort = info.cohort, o_an = at }
			end)
		end
	end

	local round = machine.round
	local phase = machine.phase
	if round == nil then
		return
	end

	if drawingPhase(phase) then
		local roles = config.Alanlar.rol
		for _, id in round.participantOrder do
			local player = m.players[id]
			if player and not player.startedRound then
				player.startedRound = true
				local role = if round.subject.id == id then roles.Model else roles.Cizen
				event(m, player, "TurBasladi", seconds(now - player.joinedAt), function(info)
					return { rol = role, kohort = info.cohort, ilk_oturum = info.firstSession }
				end)
			end
		end
	elseif phase == "Reveal" then
		local roles = config.Alanlar.reveal_rol
		for id, state in machine.players do
			local player = m.players[id]
			if state.ready and player and not player.sawReveal then
				player.sawReveal = true
				local role = if round.subject.id == id
					then roles.Model
					elseif isParticipant(round, id) then roles.Cizen
					else roles.Izleyici
				event(m, player, "IlkReveal", 1, function(info)
					return { reveal_rol = role, kohort = info.cohort, ilk_oturum = info.firstSession }
				end)
			end
		end
	elseif phase == "Podium" and m.completedRound ~= round.id then
		m.completedRound = round.id
		for id, state in machine.players do
			local player = m.players[id]
			if state.ready and player then
				player.roundsCompleted += 1
				local order = bucket(config.Alanlar.tur_sirasi, config.TurSirasiSinirlari, player.roundsCompleted)
				local joined = participation(config, round, id)
				event(m, player, "TurTamam", 1, function(info)
					if not firstSessionOnly(info) then
						return nil
					end
					return { tur_sirasi = order, katilim = joined, kohort = info.cohort }
				end)
			end
		end
	end
end

return Metrics
