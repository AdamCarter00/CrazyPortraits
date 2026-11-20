--!nocheck

local luau = require("@lune/luau")

local Sandbox = {}

local NodeMethods = {}

local NodeMeta = {
	__index = function(node, key)
		local method = NodeMethods[key]
		if method then
			return method
		end
		return rawget(node, "_children")[key]
	end,
	__tostring = function(node)
		return rawget(node, "_path")
	end,
}

function NodeMethods:FindFirstChild(name)
	return rawget(self, "_children")[name]
end

function NodeMethods:WaitForChild(name)
	local child = rawget(self, "_children")[name]
	if not child then
		error(("%s icinde '%s' yok"):format(rawget(self, "_path"), name), 2)
	end
	return child
end

function NodeMethods:GetChildren()
	local out = {}
	for _, child in rawget(self, "_children") do
		table.insert(out, child)
	end
	table.sort(out, function(a, b)
		return rawget(a, "Name") < rawget(b, "Name")
	end)
	return out
end

function NodeMethods:IsA(className)
	return rawget(self, "ClassName") == className
end

local function newNode(name, className, parent)
	local node = setmetatable({
		Name = name,
		ClassName = className,
		Parent = parent,
		_children = {},
		_path = parent and (rawget(parent, "_path") .. "/" .. name) or name,
		_source = nil,
		_fsPath = nil,
		_loaded = false,
		_result = nil,
	}, NodeMeta)
	if parent then
		rawget(parent, "_children")[name] = node
	end
	return node
end

Sandbox.newNode = newNode

local function sanitizedMath()
	local m = {}
	for key, value in math do
		if key ~= "random" and key ~= "randomseed" then
			m[key] = value
		end
	end
	return table.freeze(m)
end

local PURE_GLOBALS = {
	assert = assert,
	error = error,
	ipairs = ipairs,
	next = next,
	pairs = pairs,
	pcall = pcall,
	xpcall = xpcall,
	rawequal = rawequal,
	rawget = rawget,
	rawlen = rawlen,
	rawset = rawset,
	select = select,
	setmetatable = setmetatable,
	getmetatable = getmetatable,
	tonumber = tonumber,
	tostring = tostring,
	type = type,
	unpack = unpack,
	table = table,
	string = string,
	bit32 = bit32,
	utf8 = utf8,
	buffer = buffer,
	math = sanitizedMath(),
}

local loading = {}

local function moduleRequire(target)
	if type(target) ~= "table" or rawget(target, "ClassName") == nil then
		error("require() yalnizca bir modul nesnesi alir (Roblox uyumu). Aldi: " .. type(target), 2)
	end

	local path = rawget(target, "_path")

	if rawget(target, "ClassName") ~= "ModuleScript" then
		error(("require(%s): bu bir ModuleScript degil (%s)"):format(path, rawget(target, "ClassName")), 2)
	end

	if rawget(target, "_loaded") then
		return rawget(target, "_result")
	end

	if loading[path] then
		error("Dairesel require: " .. path, 2)
	end
	loading[path] = true

	local env = {}
	for key, value in PURE_GLOBALS do
		env[key] = value
	end
	for key, value in rawget(target, "_extraGlobals") or {} do
		env[key] = value
	end
	env.script = target
	env.require = moduleRequire

	local chunk, compileErr = luau.load(rawget(target, "_source"), {
		debugName = rawget(target, "_fsPath"),
		environment = env,
		injectGlobals = false,
	})
	if not chunk then
		loading[path] = nil
		error(("Derleme hatasi %s:\n%s"):format(path, tostring(compileErr)), 0)
	end

	local ok, result = pcall(chunk)
	loading[path] = nil
	if not ok then
		error(("Yuklenirken hata %s:\n%s"):format(path, tostring(result)), 0)
	end

	rawset(target, "_loaded", true)
	rawset(target, "_result", result)
	return result
end

Sandbox.require = moduleRequire
Sandbox.PURE_GLOBALS = PURE_GLOBALS

function Sandbox.runScript(fsPath, source, extraGlobals)
	local env = {}
	for key, value in PURE_GLOBALS do
		env[key] = value
	end
	for key, value in extraGlobals do
		env[key] = value
	end
	env.require = moduleRequire

	local chunk, compileErr = luau.load(source, {
		debugName = fsPath,
		environment = env,
		injectGlobals = false,
	})
	if not chunk then
		error(("Derleme hatasi %s:\n%s"):format(fsPath, tostring(compileErr)), 0)
	end
	return chunk()
end

return Sandbox
