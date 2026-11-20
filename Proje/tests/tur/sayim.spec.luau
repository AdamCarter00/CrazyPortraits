--!nocheck

local Machine = require(Shared.Round.Machine)
local Countdown = require(Shared.Round.Countdown)
local RoundConfig = require(Shared.Config.Round)
local Terms = require(Shared.Config.Terms)
local Schema = require(Shared.Net.Schema)

local function configWith(overrides)
	local config = table.clone(RoundConfig)
	config.MinPlayers = 2
	for key, value in overrides or {} do
		config[key] = value
	end
	return config
end

local function started(config)
	local state = Machine.new({ config = config, random = function()
		return 0
	end })
	for id = 1, 2 do
		Machine.join(state, id, "P" .. id, 0)
		Machine.ready(state, id, 0)
	end
	for _, effect in Machine.tick(state, config.LobbyCountdownSeconds) do
		if effect.name == "Drawing" then
			return state, effect.payload
		end
	end
	error("tur baslamadi")
end

describe("T-022 -- cizim basi sayimi", function()
	it("T-022: varsayilan (K-009 varsayimi) sayim cizimden once, 3 sn geciste; cizim suresi tam", function()
		local _, payload = started(configWith())
		Schema.shape("Drawing", payload)
		expect(RoundConfig.CountdownInDraw).toBe(false)
		expect(payload.countdownEndsAt).toBe(payload.startsAt)
		expect(payload.endsAt - payload.startsAt).toBe(RoundConfig.DrawSeconds)
		expect(RoundConfig.TransitionSeconds >= RoundConfig.CountdownSeconds).toBe(true)
	end)

	it("T-022: bayrak acilinca sayim cizim suresinin icinde; tur suresi degismez", function()
		local config = configWith({ CountdownInDraw = true })
		local _, payload = started(config)
		expect(payload.countdownEndsAt).toBe(payload.startsAt + config.CountdownSeconds)
		expect(payload.endsAt - payload.startsAt).toBe(config.DrawSeconds)
	end)

	it("T-022: 3-2-1 sayilir, sayim bitince katman kaybolur ve cizim acilir", function()
		local payload = { countdownEndsAt = 100 }
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
		expect(Countdown.title(payload, 6, Terms)).toBe(string.format(Terms.DrawOther, "Ayse"))
		expect(Countdown.title(payload, 5, Terms)).toBe(Terms.DrawSelf)
		expect(string.find(string.lower(Terms.DrawOther), "theme")).toBeNil()
		expect(string.format(Terms.CountdownDigit, 3)).toBe("3")
	end)

	it("T-022: cizim sirasinda giren sayimi gormez, hemen cizer", function()
		local state, payload = started(configWith())
		local later = payload.countdownEndsAt + 10
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
