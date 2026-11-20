--!strict

-- Saniye. Zaman sunucu saatidir (workspace:GetServerTimeNow).
return table.freeze({
	MinPlayers = 2,
	LobbyCountdownSeconds = 15,
	TransitionSeconds = 3,
	CountdownSeconds = 3,
	DrawSeconds = 140,
	CollectTimeoutSeconds = 7,
	RevealSecondsPerDrawing = 5,
	MidJoinMinSeconds = 60,
	PodiumSize = 3,
	PodiumSeconds = 8,
	TickSeconds = 0.25,
	ProgressSendSeconds = 2,
	ProgressAcceptSeconds = 1,

	Emojis = table.freeze({ "laugh", "crazy", "shocked", "thinking" }),
	NeutralEmojis = table.freeze({ "thinking" }),
	EmojiImages = table.freeze({
		laugh = "rbxassetid://114846288032822",
		crazy = "rbxassetid://82661481595257",
		shocked = "rbxassetid://135489123825296",
		thinking = "rbxassetid://86270765562943",
	}),
})
