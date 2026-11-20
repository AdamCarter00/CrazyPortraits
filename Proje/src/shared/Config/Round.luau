--!strict

-- Saniye. Zaman sunucu saatidir (workspace:GetServerTimeNow).
return table.freeze({
	MinPlayers = 2,
	LobbyCountdownSeconds = 15,
	TransitionSeconds = 3,
	DrawSeconds = 140,
	CollectTimeoutSeconds = 7,
	RevealSecondsPerDrawing = 5,
	PodiumSeconds = 8,
	TickSeconds = 0.25,

	Emojis = table.freeze({ "laugh", "skull", "shocked", "normal" }),
})
