--!nocheck

local Framework = {}

local suites = {}
local suiteStack = {}

local function repr(value, depth)
	depth = depth or 0
	local t = type(value)
	if t == "string" then
		return '"' .. value .. '"'
	elseif t ~= "table" then
		return tostring(value)
	elseif depth > 2 then
		return "{...}"
	end

	local parts = {}
	local isArray = true
	local count = 0
	for key in value do
		count += 1
		if type(key) ~= "number" then
			isArray = false
		end
	end
	if isArray then
		for _, item in value do
			table.insert(parts, repr(item, depth + 1))
		end
	else
		local keys = {}
		for key in value do
			table.insert(keys, key)
		end
		table.sort(keys, function(a, b)
			return tostring(a) < tostring(b)
		end)
		for _, key in keys do
			table.insert(parts, tostring(key) .. " = " .. repr(value[key], depth + 1))
		end
	end
	return "{ " .. table.concat(parts, ", ") .. " }"
end

local function deepEqual(a, b)
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for key, valueA in a do
		if not deepEqual(valueA, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

Framework.repr = repr
Framework.deepEqual = deepEqual

local MatcherFns = {}
local MatchersMeta = {}

-- Yigin: check(1) -> matcher(2) -> bagli closure(3) -> spec(4)
local ERROR_LEVEL = 4

local function check(self, condition, message)
	if self._negated then
		if condition then
			error("OLMAMALIYDI -> " .. message, ERROR_LEVEL)
		end
		return
	end
	if not condition then
		error(message, ERROR_LEVEL)
	end
end

function MatcherFns.toBe(self, expected)
	check(self, self._value == expected, ("beklenen %s, gelen %s"):format(repr(expected), repr(self._value)))
end

function MatcherFns.toEqual(self, expected)
	check(self, deepEqual(self._value, expected), ("derin esitlik bekleniyordu\n    beklenen: %s\n    gelen   : %s"):format(repr(expected), repr(self._value)))
end

function MatcherFns.toBeNil(self)
	check(self, self._value == nil, ("nil bekleniyordu, gelen %s"):format(repr(self._value)))
end

function MatcherFns.toBeTruthy(self)
	check(self, self._value and true or false, ("dogru bekleniyordu, gelen %s"):format(repr(self._value)))
end

function MatcherFns.toBeFalsy(self)
	check(self, not self._value, ("yanlis bekleniyordu, gelen %s"):format(repr(self._value)))
end

function MatcherFns.toBeCloseTo(self, expected, tolerance)
	tolerance = tolerance or 1e-6
	local diff = math.abs(self._value - expected)
	check(self, diff <= tolerance, ("%s ~= %s (tolerans %s, fark %s)"):format(repr(self._value), repr(expected), tostring(tolerance), tostring(diff)))
end

function MatcherFns.toBeBetween(self, low, high)
	check(self, self._value >= low and self._value <= high, ("%s degeri [%s, %s] araliginda degil"):format(repr(self._value), tostring(low), tostring(high)))
end

function MatcherFns.toContain(self, needle)
	local found = false
	for _, item in self._value do
		if deepEqual(item, needle) then
			found = true
			break
		end
	end
	check(self, found, ("%s icinde %s yok"):format(repr(self._value), repr(needle)))
end

function MatcherFns.toHaveLength(self, expected)
	check(self, #self._value == expected, ("uzunluk %d bekleniyordu, gelen %d"):format(expected, #self._value))
end

function MatcherFns.toThrow(self, substring)
	local ok, err = pcall(self._value)
	local threw = not ok
	if substring and threw then
		check(self, string.find(tostring(err), substring, 1, true) ~= nil, ("hata mesaji '%s' icermiyordu:\n    %s"):format(substring, tostring(err)))
		return
	end
	check(self, threw, "hata firlatmasi bekleniyordu, firlatmadi")
end

MatchersMeta.__index = function(self, key)
	-- expect(nil) durumunda _value tabloda hic yoktur ve __index tetiklenir;
	-- ic alanlar icin nil donmezsek "bilinmeyen matcher: _value" hatasi aliriz.
	if string.sub(tostring(key), 1, 1) == "_" then
		return nil
	end

	if key == "never" then
		return setmetatable({ _value = rawget(self, "_value"), _negated = true }, MatchersMeta)
	end

	local matcher = MatcherFns[key]
	if not matcher then
		error("bilinmeyen matcher: expect(...)." .. tostring(key), 2)
	end
	return function(...)
		return matcher(self, ...)
	end
end

function Framework.expect(value)
	return setmetatable({ _value = value, _negated = false }, MatchersMeta)
end

function Framework.describe(name, body)
	table.insert(suiteStack, name)
	local ok, err = pcall(body)
	table.remove(suiteStack)
	if not ok then
		error(("describe('%s') icinde hata: %s"):format(name, tostring(err)), 0)
	end
end

function Framework.it(name, body)
	local prefix = table.concat(suiteStack, " > ")
	table.insert(suites, {
		suite = prefix,
		name = name,
		body = body,
	})
end

function Framework.run(filter, verbose)
	local results = { passed = 0, failed = 0, skipped = 0, failures = {} }
	local currentSuite = nil

	local function header(suite)
		if suite ~= currentSuite then
			currentSuite = suite
			print("")
			print("  " .. currentSuite)
		end
	end

	for _, case in suites do
		local fullName = case.suite .. " > " .. case.name
		if filter and not string.find(string.lower(fullName), string.lower(filter), 1, true) then
			results.skipped += 1
			continue
		end

		if verbose then
			header(case.suite)
		end

		local ok, err = pcall(case.body)
		if ok then
			results.passed += 1
			if verbose then
				print("    [ok] " .. case.name)
			end
		else
			results.failed += 1
			header(case.suite)
			print("    [X ] " .. case.name)
			print("         " .. string.gsub(tostring(err), "\n", "\n         "))
			table.insert(results.failures, { name = fullName, err = tostring(err) })
		end
	end

	return results
end

function Framework.reset()
	suites = {}
	suiteStack = {}
end

function Framework.count()
	return #suites
end

return Framework
