--!strict

-- Oyuncuya gorunen butun metnin tek evi.
return table.freeze({
	GameName = "Crazy Portraits",

	Waiting = "Waiting for players",
	RoundStarting = "Round starting in %ds",
	PhaseDrawing = "Drawing",
	PhaseSubmitted = "Waiting for others",
	PhaseCollect = "Collecting drawings",
	PhaseReveal = "Revealing",
	RevealCount = "%d / %d",
	PhaseClean = "Round over",
	TimerText = "Time Left: %d",
	DrawSelf = "Draw yourself",
	DrawOther = "Draw %s",
	CountdownDigit = "%d",

	LoadingSteps = table.freeze({ "Draw the player", "Make it funny, not pretty", "Collect reactions" }),

	BanTimed ="You are suspended for %d more hour(s).",
	BanPermanent = "You are permanently suspended.",
	DataLoadFailed = "Data could not be loaded, please rejoin.",

	-- Faz -> gecis perdesinde gorunen asama adi; ayni ada dusen fazlar perdeyi yeniden acmaz.
	PhaseLabels = table.freeze({
		Lobby = "Lobby",
		Drawing = "Drawing",
		Collecting = "Reveal",
		Reveal = "Reveal",
		Podium = "Results",
	}),
})
