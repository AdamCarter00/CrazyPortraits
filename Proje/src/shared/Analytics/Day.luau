--!strict

local Day = {}

local SECONDS = 86400
local PATTERN = "^(%d%d%d%d)%-(%d%d)%-(%d%d)$"

-- Howard Hinnant'in days_from_civil / civil_from_days algoritmasi (proleptik Gregoryen, 1970-01-01 = 0).
local function daysFromCivil(year: number, month: number, day: number): number
	if month <= 2 then
		year -= 1
	end
	local era = (if year >= 0 then year else year - 399) // 400
	local yearOfEra = year - era * 400
	local shifted = if month > 2 then month - 3 else month + 9
	local dayOfYear = (153 * shifted + 2) // 5 + day - 1
	local dayOfEra = yearOfEra * 365 + yearOfEra // 4 - yearOfEra // 100 + dayOfYear
	return era * 146097 + dayOfEra - 719468
end

local function civilFromDays(days: number): (number, number, number)
	days += 719468
	local era = (if days >= 0 then days else days - 146096) // 146097
	local dayOfEra = days - era * 146097
	local yearOfEra = (dayOfEra - dayOfEra // 1460 + dayOfEra // 36524 - dayOfEra // 146096) // 365
	local dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra // 4 - yearOfEra // 100)
	local shifted = (5 * dayOfYear + 2) // 153
	local day = dayOfYear - (153 * shifted + 2) // 5 + 1
	local month = if shifted < 10 then shifted + 3 else shifted - 9
	local year = yearOfEra + era * 400 + (if month <= 2 then 1 else 0)
	return year, month, day
end

local function format(days: number): string
	local year, month, day = civilFromDays(days)
	return string.format("%04d-%02d-%02d", year, month, day)
end

local function parse(text: string): number?
	local year, month, day = string.match(text, PATTERN)
	if not year then
		return nil
	end
	return daysFromCivil(tonumber(year) :: number, tonumber(month) :: number, tonumber(day) :: number)
end

function Day.isDay(text: any): boolean
	if type(text) ~= "string" then
		return false
	end
	local days = parse(text)
	return days ~= nil and format(days) == text
end

function Day.fromUnix(seconds: number): string
	return format(seconds // SECONDS)
end

function Day.startUnix(text: string): number
	return (parse(text) :: number) * SECONDS
end

function Day.after(text: string, count: number): string?
	local days = parse(text)
	if not days then
		return nil
	end
	return format(days + count)
end

return Day
