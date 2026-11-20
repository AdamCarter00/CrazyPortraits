--!strict

export type Status = "loading" | "ready" | "failed"

local Screen = {}

function Screen.tipIndex(elapsed: number, count: number, seconds: number): number
	return math.floor(math.max(0, elapsed) / seconds) % count + 1
end

function Screen.barText(status: Status, terms: { Loading: string, DataLoadFailed: string }): string
	return if status == "failed" then terms.DataLoadFailed else terms.Loading
end

function Screen.shouldClose(status: Status, gameLoaded: boolean, elapsed: number, minSeconds: number): boolean
	return status == "ready" and gameLoaded and elapsed >= minSeconds
end

return Screen
