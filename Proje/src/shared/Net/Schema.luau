--!strict

-- Istemciye giden her mesajin beyaz listesi. Alan tipi "?" ile baslarsa istege bagli.
local Schema = {}

Schema.Messages = table.freeze({
	Lobby = { channel = "Round", fields = { status = "string", readyCount = "number", minPlayers = "number", endsAt = "?number" } },
	Drawing = {
		channel = "Round",
		fields = {
			roundId = "number",
			subjectUserId = "number",
			subjectName = "string",
			startsAt = "number",
			countdownEndsAt = "number",
			endsAt = "number",
			participants = "table",
		},
	},
	Collect = { channel = "Round", fields = { roundId = "number" } },
	Reveal = {
		channel = "Round",
		fields = {
			roundId = "number",
			drawingId = "string",
			ownerUserId = "number",
			ownerName = "string",
			index = "number",
			total = "number",
			startsAt = "number",
			endsAt = "number",
			drawing = "buffer",
		},
	},
	VoteAccepted = { channel = "Round", fields = { drawingId = "string", emoji = "string" } },
	Podium = { channel = "Round", fields = { roundId = "number", entries = "table", endsAt = "number" } },

	AdminAck = { channel = "Admin", fields = { command = "string" } },
	CommandRejected = { channel = "Admin", fields = { command = "?string", reason = "string" } },
	PanelRejected = { channel = "Admin", fields = { reason = "string" } },
	ShowPanel = { channel = "Admin", fields = { active = "table", history = "table", firstDrawings = "table" } },
	ViewReportFailed = { channel = "Admin", fields = { reportId = "string", reason = "string" } },
	ReportDetail = {
		channel = "Admin",
		fields = {
			reportId = "string",
			ownerUserId = "?number",
			theme = "?string",
			reporterCount = "?number",
			timestamp = "?number",
			drawingBuffer = "?buffer",
		},
	},
	FirstDrawingDetail = {
		channel = "Admin",
		fields = { entryId = "string", ownerUserId = "?number", theme = "?string", timestamp = "?number", drawingBuffer = "?buffer" },
	},
	DrawingDetail = {
		channel = "Admin",
		fields = { entryId = "string", ownerUserId = "?number", theme = "?string", timestamp = "?number", drawingBuffer = "?buffer" },
	},
	DrawingsPage = { channel = "Admin", fields = { entries = "table", cursor = "?number", nextCursor = "?number" } },
	BanResult = { channel = "Admin", fields = { reportId = "string", ok = "boolean", reason = "?string" } },
	DismissResult = { channel = "Admin", fields = { reportId = "string", ok = "boolean", reason = "?string" } },
})

function Schema.channel(name: string): string
	local message = Schema.Messages[name]
	if not message then
		error(`Net: beyaz listede olmayan mesaj '{name}'`, 2)
	end
	return message.channel
end

function Schema.shape(name: string, payload: { [string]: any }): { [string]: any }
	local message = Schema.Messages[name]
	if not message then
		error(`Net: beyaz listede olmayan mesaj '{name}'`, 2)
	end
	for key in payload do
		if message.fields[key] == nil then
			error(`Net: '{name}' mesajinda beyaz listede olmayan alan '{tostring(key)}'`, 2)
		end
	end
	local out = {}
	for key, kind in message.fields do
		local optional = string.sub(kind, 1, 1) == "?"
		local wanted = if optional then string.sub(kind, 2) else kind
		local value = payload[key]
		if value == nil then
			if not optional then
				error(`Net: '{name}' mesajinda '{key}' eksik`, 2)
			end
		elseif type(value) ~= wanted then
			error(`Net: '{name}.{key}' {wanted} olmali, {type(value)} geldi`, 2)
		end
		out[key] = value
	end
	return out
end

return Schema
