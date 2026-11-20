--!strict

export type Status = "loading" | "ready" | "failed"

local Screen = {}

function Screen.tipIndex(elapsed: number, count: number, seconds: number): number
	return math.floor(math.max(0, elapsed) / seconds) % count + 1
end

function Screen.barText(status: Status, terms: { Loading: string, DataLoadFailed: string }): string
	return if status == "failed" then terms.DataLoadFailed else terms.Loading
end

-- Dolgunun Position.X.Scale'i: sol kenari cubugun solundan sagina gidip doner. Negatif genislikli dolgu
-- konumunun soluna cizilir; gorunen sol kenar Position + min(0, Size) olur.
function Screen.fillPosition(elapsed: number, cycleSeconds: number, sizeScale: number): number
	local width = math.abs(sizeScale)
	local span = math.max(0, 1 - width)
	local phase = (math.max(0, elapsed) / cycleSeconds) % 2
	local along = if phase <= 1 then phase else 2 - phase
	return along * span - math.min(0, sizeScale)
end

function Screen.fillMoves(status: Status): boolean
	return status ~= "failed"
end

function Screen.shouldClose(status: Status, gameLoaded: boolean, elapsed: number, minSeconds: number): boolean
	return status == "ready" and gameLoaded and elapsed >= minSeconds
end

return Screen
