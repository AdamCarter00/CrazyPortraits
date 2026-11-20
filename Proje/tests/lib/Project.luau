--!nocheck

local fs = require("@lune/fs")
local Sandbox = require("./Sandbox")
-- Sim bilerek fakir (yalniz GetService, uc servis): Players/Instance/task'a dokunan
-- sunucu modulu Lune'da yuklenmesin, saf olmadigi gorunsun.
local function robloxShim(roots)
	local dataModel = Sandbox.newNode("game", "DataModel", nil)

	local function service(className, childName, childNode)
		local node = Sandbox.newNode(className, className, dataModel)
		if childNode then
			rawget(node, "_children")[childName] = childNode
		end
		return node
	end

	local services = {
		ReplicatedStorage = service("ReplicatedStorage", "Shared", roots.Shared),
		ServerScriptService = service("ServerScriptService", "Server", roots.Server),
		StarterPlayer = service("StarterPlayer", nil, nil),
	}

	rawset(dataModel, "GetService", function(_, name)
		local node = services[name]
		if not node then
			error(("game:GetService(\"%s\"): test ortaminda boyle bir servis yok"):format(tostring(name)), 2)
		end
		return node
	end)

	return dataModel
end


local Project = {}

local function classify(fileName)
	if string.match(fileName, "%.server%.luau$") then
		return string.gsub(fileName, "%.server%.luau$", ""), "Script"
	elseif string.match(fileName, "%.client%.luau$") then
		return string.gsub(fileName, "%.client%.luau$", ""), "LocalScript"
	elseif string.match(fileName, "%.luau$") then
		return string.gsub(fileName, "%.luau$", ""), "ModuleScript"
	end
	return nil, nil
end

local AREAS = {
	{ dir = "src/shared", name = "Shared" },
	{ dir = "src/server", name = "Server" },
	{ dir = "src/client", name = "Client" },
	{ dir = "src/places", name = "Places" },
}

-- Betikler proje kokunden calistirilir: tools/ altindakiler icin de onek bos kalir.
function Project.load(root)
	root = root or ""

	local sourceIndex = {}

	local function attachSource(node, fsPath, area)
		local source = fs.readFile(fsPath)
		rawset(node, "_source", source)
		rawset(node, "_fsPath", fsPath)
		table.insert(sourceIndex, {
			robloxPath = rawget(node, "_path"),
			fsPath = fsPath,
			area = area,
			className = rawget(node, "ClassName"),
			node = node,
			source = source,
		})
	end

	local function buildTree(fsDir, node, area)
		for _, entry in fs.readDir(fsDir) do
			local entryPath = fsDir .. "/" .. entry

			if fs.isDir(entryPath) then
				local child = Sandbox.newNode(entry, "Folder", node)
				buildTree(entryPath, child, area)
			elseif entry == "init.luau" then
				-- Rojo kurali: init.luau klasoru bir ModuleScript'e cevirir
				rawset(node, "ClassName", "ModuleScript")
				attachSource(node, entryPath, area)
			else
				local name, className = classify(entry)
				if name then
					local child = Sandbox.newNode(name, className, node)
					attachSource(child, entryPath, area)
				end
			end
		end
	end

	local roots = {}
	for _, area in AREAS do
		local node = Sandbox.newNode(area.name, "Folder", nil)
		roots[area.name] = node
		local dir = root .. area.dir
		if fs.isDir(dir) then
			buildTree(dir, node, area.name)
		end
	end

	local game = robloxShim(roots)
	for _, entry in sourceIndex do
		local shell = entry.area == "Server"
			or entry.area == "Places"
			or entry.area == "Client"
			or string.sub(entry.robloxPath, 1, #"Shared/Net") == "Shared/Net"
		if shell then
			rawset(entry.node, "_extraGlobals", { game = game })
		end
	end

	return {
		Shared = roots.Shared,
		Server = roots.Server,
		Client = roots.Client,
		game = game,
		sourceIndex = sourceIndex,
	}
end

function Project.engine(root)
	local tree = Project.load(root)
	return function(name)
		return Sandbox.require(tree.Shared.Engine[name])
	end, tree
end

return Project
