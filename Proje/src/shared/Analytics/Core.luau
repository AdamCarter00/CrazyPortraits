--!strict

local Day = require(script.Parent.Day)

export type Custom = { [string]: string }

export type Deps = {
	config: any,
	clock: () -> number,
	studio: boolean,
	playerCount: () -> number,
	send: (target: any, name: string, value: number, custom: Custom) -> (),
	output: (line: string) -> (),
	warn: (line: string) -> (),
}

local Core = {}
Core.__index = Core

local DAY_RANGE = "Gunler"

local function allows(spec: any, value: any): boolean
	if type(value) ~= "string" then
		return false
	end
	for key, entry in spec do
		if key == DAY_RANGE then
			if Day.isDay(value) and value >= entry.Ilk and value <= entry.Son then
				return true
			end
		elseif type(entry) == "table" then
			if allows(entry, value) then
				return true
			end
		elseif entry == value then
			return true
		end
	end
	return false
end

Core.allows = allows

function Core.fieldKey(index: number): string
	return string.format("CustomField%02d", index)
end

function Core.new(deps: Deps)
	return setmetatable({
		deps = deps,
		config = deps.config,
		windowStart = -math.huge,
		spent = 0,
		samples = {} :: { { stamp: number, count: number } },
		lastFailureWarn = -math.huge,
	}, Core)
end

function Core:peakPlayers(stamp: number): number
	local samples = self.samples
	local count = self.deps.playerCount()
	local last = samples[#samples]
	if not last or last.count ~= count then
		table.insert(samples, { stamp = stamp, count = count })
	end
	while samples[2] and stamp - samples[2].stamp >= self.config.Butce.PencereSaniye do
		table.remove(samples, 1)
	end
	local peak = 1
	for _, sample in samples do
		peak = math.max(peak, sample.count)
	end
	return peak
end

function Core:spend(priority: boolean): boolean
	local budget = self.config.Butce
	local stamp = self.deps.clock()
	if stamp - self.windowStart >= budget.PencereSaniye then
		self.windowStart = stamp
		self.spent = 0
	end
	local peak = self:peakPlayers(stamp)
	local limit = budget.OyuncuBasinaDakikada * peak
	if not priority then
		limit -= budget.OncelikPayiOyuncuBasina * peak
	end
	if self.spent >= limit then
		return false
	end
	self.spent += 1
	return true
end

function Core:failed(problem: any)
	local stamp = self.deps.clock()
	if stamp - self.lastFailureWarn >= self.config.HataUyariSaniye then
		self.lastFailureWarn = stamp
		self.deps.warn(string.format("%s gonderilemedi: %s", self.config.CiktiOneki, tostring(problem)))
	end
end

function Core:encode(key: string, fields: { [string]: any }?): (Custom?, string?)
	local event = self.config.Olaylar[key]
	if not event then
		return nil, "bilinmeyen olay " .. tostring(key)
	end
	local given = fields or {}
	local custom: Custom = {}
	for index, field in event.Alanlar do
		local value = given[field]
		local spec = self.config.Alanlar[field]
		if not spec or not allows(spec, value) then
			return nil, string.format("%s.%s izinli degil (%s)", event.Ad, field, tostring(value))
		end
		custom[Core.fieldKey(index)] = value
	end
	for field in given do
		if not table.find(event.Alanlar, field) then
			return nil, string.format("%s semasinda %s yok", event.Ad, tostring(field))
		end
	end
	return custom, nil
end

local function describe(event, value: number, fields: { [string]: any }): string
	local parts = { event.Ad, "deger=" .. tostring(value) }
	for _, field in event.Alanlar do
		table.insert(parts, field .. "=" .. tostring(fields[field]))
	end
	return table.concat(parts, " ")
end

function Core:log(target: any, key: string, value: number, fields: { [string]: any }?): boolean
	local ok, result = pcall(function()
		local custom, problem = self:encode(key, fields)
		if not custom then
			self.deps.warn(string.format("%s %s", self.config.CiktiOneki, tostring(problem)))
			return false
		end
		local event = self.config.Olaylar[key]
		if not self.config.Acik or not self:spend(event.Oncelikli == true) then
			return false
		end
		if self.deps.studio then
			self.deps.output(string.format("%s %s", self.config.CiktiOneki, describe(event, value, fields or {})))
			return true
		end
		local sent, problemSending = pcall(self.deps.send, target, event.Ad, value, custom)
		if not sent then
			self:failed(problemSending)
		end
		return sent
	end)
	if not ok then
		self:failed(result)
		return false
	end
	return result
end

return Core
