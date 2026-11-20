--!strict

-- Saniye. Zaman sunucu saatidir (workspace:GetServerTimeNow).
return table.freeze({
	MinPlayers = 2,
	LobbyCountdownSeconds = 15,
	TransitionSeconds = 3,
	CountdownSeconds = 3,
	CountdownInDraw = false,
	DrawSeconds = 140,
	CollectTimeoutSeconds = 7,
	RevealSecondsPerDrawing = 5,
	MidJoinMinSeconds = 60,
	PodiumSize = 3,
	PodiumSeconds = 8,
	TickSeconds = 0.25,
	ProgressSendSeconds = 2,
	ProgressAcceptSeconds = 1,

	Emojis = table.freeze({ "laugh", "skull", "shocked", "normal" }),
	NeutralEmojis = table.freeze({ "normal" }),
})
