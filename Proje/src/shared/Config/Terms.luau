--!strict

-- Oyuncuya gorunen butun metnin tek evi.
return table.freeze({
	GameName = "Crazy Portraits",

	TimerText = "Time Left: %d",
	DrawSelf = "Draw yourself",
	DrawOther = "Draw %s",

	BanTimed = "You are suspended for %d more hour(s).",
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
