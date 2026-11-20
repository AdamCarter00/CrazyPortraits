--!strict

export type Effect = { to: any, name: string, payload: { [string]: any } }

export type Deps = {
	config: any,
	random: () -> number,
}

local Machine = {}

local function emit(out: { Effect }, to: any, name: string, payload: { [string]: any })
	table.insert(out, { to = to, name = name, payload = payload })
end

function Machine.new(deps: Deps)
	return {
		deps = deps,
		config = deps.config,
		phase = "Lobby",
		players = {},
		pendingReady = {},
		joinCounter = 0,
		missed = {},
		lastSubjectId = nil :: number?,
		roundCounter = 0,
		countdownEndsAt = nil :: number?,
		round = nil :: any,
	}
end

local function readyIds(state): { number }
	local list = {}
	for id, player in state.players do
		if player.ready then
			table.insert(list, id)
		end
	end
	table.sort(list, function(a, b)
		return state.players[a].order < state.players[b].order
	end)
	return list
end

local function lobbyPayload(state)
	return {
		status = if state.countdownEndsAt then "countdown" else "waiting",
		readyCount = #readyIds(state),
		minPlayers = state.config.MinPlayers,
		endsAt = state.countdownEndsAt,
	}
end

local function drawingPayload(state)
	local round = state.round
	return {
		roundId = round.id,
		subjectUserId = round.subject.id,
		subjectName = round.subject.name,
		startsAt = round.startsAt,
		endsAt = round.endsAt,
		participants = table.clone(round.participantOrder),
	}
end

local function currentReveal(state)
	local reveal = state.round.reveal
	return reveal.list[reveal.index]
end

local function revealPayload(state)
	local round = state.round
	local entry = currentReveal(state)
	return {
		roundId = round.id,
		drawingId = entry.drawingId,
		ownerUserId = entry.ownerId,
		ownerName = entry.ownerName,
		index = round.reveal.index,
		total = #round.reveal.list,
		startsAt = round.reveal.startsAt,
		endsAt = round.reveal.endsAt,
		drawing = entry.data,
	}
end

local function tally(state, entry)
	local reactions = {}
	for _, emoji in state.config.Emojis do
		reactions[emoji] = 0
	end
	for voterId, emoji in state.round.votes[entry.drawingId] or {} do
		if voterId ~= entry.ownerId then
			reactions[emoji] += 1
		end
	end
	return reactions
end

local function score(state, reactions): number
	local total = 0
	for emoji, count in reactions do
		if table.find(state.config.NeutralEmojis, emoji) == nil then
			total += count
		end
	end
	return total
end

local function tallyPayload(state, entry)
	local reactions = tally(state, entry)
	return { drawingId = entry.drawingId, reactions = reactions, score = score(state, reactions) }
end

local function podiumPayload(state)
	local round = state.round
	local ranked = {}
	for order, entry in round.reveal.list do
		local reactions = tally(state, entry)
		table.insert(ranked, { entry = entry, reactions = reactions, score = score(state, reactions), order = order })
	end
	table.sort(ranked, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		return a.order < b.order
	end)
	local entries = {}
	for rank, item in ranked do
		if rank > state.config.PodiumSize then
			break
		end
		table.insert(entries, {
			rank = rank,
			drawingId = item.entry.drawingId,
			ownerUserId = item.entry.ownerId,
			ownerName = item.entry.ownerName,
			drawing = item.entry.data,
			reactions = item.reactions,
			score = item.score,
		})
	end
	return {
		roundId = round.id,
		entries = entries,
		endsAt = round.podiumEndsAt,
	}
end

local function snapshot(state, out: { Effect }, to: number)
	local phase = state.phase
	if phase == "Lobby" then
		emit(out, to, "Lobby", lobbyPayload(state))
	elseif phase == "Drawing" or phase == "Collecting" then
		emit(out, to, "Drawing", drawingPayload(state))
	elseif phase == "Reveal" then
		emit(out, to, "Reveal", revealPayload(state))
		emit(out, to, "Tally", tallyPayload(state, currentReveal(state)))
	elseif phase == "Podium" then
		emit(out, to, "Podium", podiumPayload(state))
	end
end

local function updateCountdown(state, now: number, out: { Effect })
	if state.phase ~= "Lobby" then
		return
	end
	local enough = #readyIds(state) >= state.config.MinPlayers
	if enough and state.countdownEndsAt == nil then
		state.countdownEndsAt = now + state.config.LobbyCountdownSeconds
	elseif not enough then
		state.countdownEndsAt = nil
	end
	emit(out, "all", "Lobby", lobbyPayload(state))
end

local function enterLobby(state, now: number, out: { Effect })
	state.phase = "Lobby"
	state.round = nil
	state.countdownEndsAt = nil
	updateCountdown(state, now, out)
end

local function pickSubject(state, participants: { number }): number
	local candidates = {}
	local total = 0
	for _, id in participants do
		if id ~= state.lastSubjectId then
			local weight = (state.missed[id] or 0) + 1
			table.insert(candidates, { id = id, weight = weight })
			total += weight
		end
	end
	if #candidates == 0 then
		return participants[1]
	end
	local roll = state.deps.random() * total
	for _, candidate in candidates do
		roll -= candidate.weight
		if roll < 0 then
			return candidate.id
		end
	end
	return candidates[#candidates].id
end

local function startRound(state, now: number, out: { Effect })
	local participants = readyIds(state)
	local subjectId = pickSubject(state, participants)
	for _, id in participants do
		state.missed[id] = if id == subjectId then 0 else (state.missed[id] or 0) + 1
	end
	state.lastSubjectId = subjectId
	state.roundCounter += 1
	state.countdownEndsAt = nil
	local startsAt = now + state.config.TransitionSeconds
	local participantSet = {}
	for _, id in participants do
		participantSet[id] = true
	end
	state.round = {
		id = state.roundCounter,
		subject = { id = subjectId, name = state.players[subjectId].name },
		participantOrder = participants,
		awaiting = participantSet,
		names = {},
		drawings = {},
		startsAt = startsAt,
		endsAt = startsAt + state.config.DrawSeconds,
		votes = {},
	}
	for _, id in participants do
		state.round.names[id] = state.players[id].name
	end
	state.phase = "Drawing"
	emit(out, "all", "Drawing", drawingPayload(state))
end

local function showDrawing(state, now: number, index: number, out: { Effect })
	local reveal = state.round.reveal
	reveal.index = index
	reveal.startsAt = if index == 1 then now + state.config.TransitionSeconds else now
	reveal.endsAt = reveal.startsAt + state.config.RevealSecondsPerDrawing
	emit(out, "all", "Reveal", revealPayload(state))
end

local function startReveal(state, now: number, out: { Effect })
	local round = state.round
	local list = {}
	for _, ownerId in round.participantOrder do
		local drawing = round.drawings[ownerId]
		if drawing and drawing.strokeCount > 0 then
			table.insert(list, {
				drawingId = `{round.id}-{#list + 1}`,
				ownerId = ownerId,
				ownerName = round.names[ownerId],
				data = drawing.data,
			})
		end
	end
	if #list == 0 then
		enterLobby(state, now, out)
		return
	end
	round.reveal = { list = list, index = 0, startsAt = now, endsAt = now }
	state.phase = "Reveal"
	showDrawing(state, now, 1, out)
end

local function startPodium(state, now: number, out: { Effect })
	state.phase = "Podium"
	state.round.podiumEndsAt = now + state.config.PodiumSeconds
	emit(out, "all", "Podium", podiumPayload(state))
end

local function allSubmitted(state): boolean
	return next(state.round.awaiting) == nil
end

local function advanceIfDone(state, now: number, out: { Effect })
	if (state.phase == "Drawing" or state.phase == "Collecting") and allSubmitted(state) then
		startReveal(state, now, out)
	end
end

function Machine.join(state, id: number, name: string, now: number): { Effect }
	local out = {}
	if state.players[id] then
		return out
	end
	state.joinCounter += 1
	state.players[id] = { id = id, name = name, ready = false, order = state.joinCounter }
	if state.pendingReady[id] then
		state.pendingReady[id] = nil
		return Machine.ready(state, id, now)
	end
	return out
end

function Machine.ready(state, id: number, now: number): { Effect }
	local out = {}
	local player = state.players[id]
	if not player then
		state.pendingReady[id] = true
		return out
	end
	if player.ready then
		snapshot(state, out, id)
		return out
	end
	player.ready = true
	if state.phase == "Lobby" then
		updateCountdown(state, now, out)
	else
		if state.phase == "Drawing" and state.round.endsAt - now > state.config.MidJoinMinSeconds then
			local round = state.round
			table.insert(round.participantOrder, id)
			round.awaiting[id] = true
			round.names[id] = player.name
		end
		snapshot(state, out, id)
	end
	return out
end

function Machine.leave(state, id: number, now: number): { Effect }
	local out = {}
	state.pendingReady[id] = nil
	if not state.players[id] then
		return out
	end
	state.players[id] = nil
	state.missed[id] = nil
	if state.phase == "Lobby" then
		updateCountdown(state, now, out)
	elseif state.phase == "Drawing" or state.phase == "Collecting" then
		state.round.awaiting[id] = nil
		advanceIfDone(state, now, out)
	end
	return out
end

function Machine.submit(state, id: number, data: any, strokeCount: number, now: number): { Effect }
	local out = {}
	if state.phase ~= "Drawing" and state.phase ~= "Collecting" then
		return out
	end
	local round = state.round
	if not round.awaiting[id] then
		return out
	end
	round.awaiting[id] = nil
	round.drawings[id] = { data = data, strokeCount = strokeCount }
	advanceIfDone(state, now, out)
	return out
end

function Machine.vote(state, id: number, drawingId: string, emoji: string, now: number): { Effect }
	local out = {}
	if state.phase ~= "Reveal" then
		return out
	end
	local player = state.players[id]
	if not player or not player.ready then
		return out
	end
	if table.find(state.config.Emojis, emoji) == nil then
		return out
	end
	local entry = currentReveal(state)
	if entry.drawingId ~= drawingId then
		return out
	end
	local votes = state.round.votes[drawingId]
	if not votes then
		votes = {}
		state.round.votes[drawingId] = votes
	end
	votes[id] = emoji
	emit(out, id, "VoteAccepted", { drawingId = drawingId, emoji = emoji })
	emit(out, "all", "Tally", tallyPayload(state, entry))
	return out
end

function Machine.tick(state, now: number): { Effect }
	local out = {}
	local phase = state.phase
	if phase == "Lobby" then
		if state.countdownEndsAt and now >= state.countdownEndsAt then
			startRound(state, now, out)
		end
	elseif phase == "Drawing" then
		if now >= state.round.endsAt then
			state.phase = "Collecting"
			state.round.collectEndsAt = now + state.config.CollectTimeoutSeconds
			emit(out, "all", "Collect", { roundId = state.round.id })
		end
	elseif phase == "Collecting" then
		if now >= state.round.collectEndsAt then
			startReveal(state, now, out)
		end
	elseif phase == "Reveal" then
		local reveal = state.round.reveal
		if now >= reveal.endsAt then
			if reveal.index < #reveal.list then
				showDrawing(state, now, reveal.index + 1, out)
			else
				startPodium(state, now, out)
			end
		end
	elseif phase == "Podium" then
		if now >= state.round.podiumEndsAt then
			enterLobby(state, now, out)
		end
	end
	return out
end

return Machine
