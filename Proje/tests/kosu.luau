--!nocheck

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local serde = require("@lune/serde")

local KosuBitti = require("./lib/KosuBitti")
local Sandbox = require("./lib/Sandbox")
local Framework = require("./lib/Framework")
local Project = require("./lib/Project")

local filter = nil
local verbose = false
local specRoot = "tests"
local args = process.args
for index, arg in args do
	if arg == "--filter" or arg == "-f" then
		filter = args[index + 1]
	elseif arg == "--hepsi" then
		verbose = true
	elseif arg == "--dizin" then
		specRoot = args[index + 1]
	end
end

local project = Project.load()
local sourceIndex = project.sourceIndex


local specs = {}

local function findSpecs(dir)
	for _, entry in fs.readDir(dir) do
		local entryPath = dir .. "/" .. entry
		if fs.isDir(entryPath) then
			if entry ~= "lib" then
				findSpecs(entryPath)
			end
		elseif string.match(entry, "%.spec%.luau$") then
			table.insert(specs, entryPath)
		end
	end
end

findSpecs(specRoot)
table.sort(specs)

local specGlobals = {
	describe = Framework.describe,
	it = Framework.it,
	expect = Framework.expect,
	print = print,
	Shared = project.Shared,
	Server = project.Server,
	Client = project.Client,
	SourceIndex = sourceIndex,
	ProjectFile = serde.decode("json", fs.readFile("default.project.json")),
	repr = Framework.repr,
	loadPure = function(source)
		return pcall(function()
			return Sandbox.runScript("<inline-test>", source, {})
		end)
	end,
	compile = function(source, name)
		local chunk, err = luau.load(source, { debugName = name or "<inline>" })
		return chunk ~= nil, err
	end,
	loadShared = function(overrides)
		local fresh = Project.load()
		for name, values in overrides do
			local node = fresh.Shared.Config[name]
			local merged = table.clone(Sandbox.require(node))
			for key, value in values do
				merged[key] = value
			end
			rawset(node, "_result", table.freeze(merged))
		end
		return fresh.Shared, fresh.Server
	end,
	deepEqual = Framework.deepEqual,
	fsRead = fs.readFile,
	runSpecs = function(dir)
		local result = process.exec("lune", { "run", "tests/run.luau", "--dizin", dir })
		return result.code, result.stdout
	end,
	jsonSize = function(value)
		return #serde.encode("json", value)
	end,
}

if verbose then
	print("")
	print("test kosumu" .. (filter and ("  [filtre: " .. filter .. "]") or ""))
	print(("  %d spec dosyasi, %d kaynak dosyasi"):format(#specs, #sourceIndex))
end

local loadFailures = {}
for _, specPath in specs do
	local ok, err = pcall(function()
		Sandbox.runScript(specPath, fs.readFile(specPath), specGlobals)
	end)
	if not ok then
		table.insert(loadFailures, { path = specPath, err = tostring(err) })
	end
end

if #loadFailures > 0 then
	print("")
	for _, failure in loadFailures do
		print("  [YUKLEME HATASI] " .. failure.path)
		print("      " .. string.gsub(failure.err, "\n", "\n      "))
	end
end

local results = Framework.run(filter, verbose)

if verbose or results.failed > 0 or #loadFailures > 0 then
	print("")
end
print(("  %d gecti, %d kaldi, %d atlandi"):format(results.passed, results.failed, results.skipped))

if verbose and #results.failures > 0 then
	print("")
	print("  BASARISIZ:")
	for _, failure in results.failures do
		print("    - " .. failure.name)
	end
end
if verbose then
	print("")
end

if results.failed > 0 or #loadFailures > 0 then
	process.exit(1)
end
process.exit(KosuBitti)
