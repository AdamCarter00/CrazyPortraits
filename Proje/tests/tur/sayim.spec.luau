--!nocheck

local Machine = require(Shared.Round.Machine)
local Countdown = require(Shared.Round.Countdown)
local RoundConfig = require(Shared.Config.Round)
local Terms = require(Shared.Config.Terms)
local Schema = require(Shared.Net.Schema)

local function started()
	local config = table.clone(RoundConfig)
	config.MinPlayers = 2
	local state = Machine.new({ config = config, random = function()
		return 0
	end })
	for id = 1, 2 do
		Machine.join(state, id, "P" .. id, 0)
		Machine.ready(state, id, 0)
	end
	local startedAt = config.LobbyCountdownSeconds
	for _, effect in Machine.tick(state, startedAt) do
		if effect.name == "Drawing" then
			return state, effect.payload, startedAt
		end
	end
	error("tur baslamadi")
end

describe("T-022 -- cizim basi sayimi", function()
	it("T-022: sayim cizim suresinin oncesinde; DrawSeconds sayim bitince baslar", function()
		local _, payload, startedAt = started()
		Schema.shape("Drawing", payload)
		expect(RoundConfig.TransitionSeconds >= RoundConfig.CountdownSeconds).toBe(true)
		expect(payload.startsAt).toBe(startedAt + RoundConfig.TransitionSeconds)
		expect(payload.endsAt - payload.startsAt).toBe(RoundConfig.DrawSeconds)
		expect(Countdown.at(payload, payload.startsAt - RoundConfig.CountdownSeconds, RoundConfig.CountdownSeconds).show).toBe(true)
		expect(Countdown.at(payload, payload.startsAt, RoundConfig.CountdownSeconds).canDraw).toBe(true)
	end)

	it("T-022: 3-2-1 sayilir, sayim bitince katman kaybolur ve cizim acilir", function()
		local payload = { startsAt = 100 }
		local seconds = RoundConfig.CountdownSeconds
		expect(Countdown.at(payload, 100 - seconds - 0.5, seconds)).toEqual({ show = false, canDraw = false })
		expect(Countdown.at(payload, 100 - seconds, seconds)).toEqual({ show = true, digit = 3, canDraw = false })
		expect(Countdown.at(payload, 98.5, seconds).digit).toBe(2)
		expect(Countdown.at(payload, 99.9, seconds).digit).toBe(1)
		expect(Countdown.at(payload, 100, seconds)).toEqual({ show = false, canDraw = true })
		expect(Countdown.at(payload, 140, seconds)).toEqual({ show = false, canDraw = true })
	end)

	it("T-022: yazi yalniz modelin adini soyler; model kendisi icin Draw yourself; metin Terms'te", function()
		local payload = { subjectUserId = 5, subjectName = "Ayse" }
		expect(Countdown.title(payload, 6, Terms)).toBe(string.format(Terms.DrawOther, "AYSE"))
		expect(Countdown.title(payload, 5, Terms)).toBe(Terms.DrawSelf)
		expect(string.find(string.lower(Terms.DrawOther), "theme")).toBeNil()
		expect(Terms.DrawSelf).toBe(string.upper(Terms.DrawSelf))
		expect(Terms.DrawOther).toBe("DRAW %s")
		expect(Countdown.title(payload, 6, Terms)).toBe("DRAW AYSE")
		expect(Countdown.title({ subjectUserId = 5, subjectName = "ahmet" }, 6, Terms)).toBe("DRAW AHMET")
		expect(string.format(Terms.CountdownDigit, 3)).toBe("3")
	end)

	it("T-022: cizim sirasinda giren sayimi gormez, hemen cizer", function()
		local state, payload = started()
		local later = payload.startsAt + 10
		Machine.join(state, 3, "P3", later)
		local drawing
		for _, effect in Machine.ready(state, 3, later) do
			if effect.name == "Drawing" then
				drawing = effect.payload
			end
		end
		expect(Countdown.at(drawing, later, RoundConfig.CountdownSeconds)).toEqual({ show = false, canDraw = true })
	end)
end)
