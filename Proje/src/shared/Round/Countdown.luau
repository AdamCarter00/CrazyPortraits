--!strict

local Countdown = {}

export type View = { show: boolean, digit: number?, canDraw: boolean }

function Countdown.at(payload: { startsAt: number }, now: number, seconds: number): View
	local remaining = payload.startsAt - now
	if remaining <= 0 then
		return { show = false, digit = nil, canDraw = true }
	elseif remaining > seconds then
		return { show = false, digit = nil, canDraw = false }
	end
	return { show = true, digit = math.ceil(remaining), canDraw = false }
end

function Countdown.title(payload: { subjectUserId: number, subjectName: string }, localUserId: number, terms): string
	if payload.subjectUserId == localUserId then
		return terms.DrawSelf
	end
	return string.upper(string.format(terms.DrawOther, payload.subjectName))
end

return Countdown
