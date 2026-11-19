local Signal = require(script.Parent.Signal)

return {
	IntroStarted    = Signal.new(),
	DrawingShown    = Signal.new(), -- (oyuncuAdi, tema, cizimTamponu)
	DrawingFinished = Signal.new(), -- (oyuncuAdi)
	RevealEnded     = Signal.new(),
}
