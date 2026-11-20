--!nocheck

local function stripComments(source)
	local noBlocks = string.gsub(source, "%-%-%[(=*)%[.-%]%1%]", "")
	return (string.gsub(noBlocks, "%-%-[^\n]*", ""))
end

local function isPureShared(entry)
	return entry.area == "Shared" and string.sub(entry.robloxPath, 1, #"Shared/Net") ~= "Shared/Net"
end

describe("Mimari", function()
	it("src/shared oyun mantigi saf: game, task, os, math.random yok", function()
		local offenders = {}
		for _, entry in SourceIndex do
			if isPureShared(entry) then
				local code = stripComments(entry.source)
				for _, pattern in { "%f[%w_]game%f[^%w_]", "%f[%w_]task%.", "%f[%w_]os%.", "math%.random" } do
					if string.find(code, pattern) then
						table.insert(offenders, entry.fsPath .. " (" .. pattern .. ")")
					end
				end
			end
		end
		expect(offenders).toEqual({})
	end)

	it("src/shared modulleri saf ortamda yuklenir", function()
		for _, entry in SourceIndex do
			if isPureShared(entry) and entry.className == "ModuleScript" then
				require(entry.node)
			end
		end
	end)

	it("istemciye giden bilgi yalniz Net'ten gecer", function()
		local offenders = {}
		for _, entry in SourceIndex do
			local inNet = string.sub(entry.robloxPath, 1, #"Shared/Net") == "Shared/Net"
			local code = stripComments(entry.source)
			if not inNet and (string.find(code, "FireClient") or string.find(code, "FireAllClients")) then
				table.insert(offenders, entry.fsPath)
			end
		end
		expect(offenders).toEqual({})
	end)

	it("Config saf veri ve dondurulmus", function()
		local function check(value, path, bad)
			local kind = type(value)
			if kind == "table" then
				if not table.isfrozen(value) then
					table.insert(bad, path .. " dondurulmamis")
				end
				for key, child in value do
					check(child, path .. "." .. tostring(key), bad)
				end
			elseif kind ~= "string" and kind ~= "number" and kind ~= "boolean" then
				table.insert(bad, path .. " " .. kind)
			end
		end
		local bad = {}
		for _, node in Shared.Config:GetChildren() do
			check(require(node), node.Name, bad)
		end
		expect(bad).toEqual({})
	end)
end)

describe("Para", function()
	it("K-004: Kapi 1'de Yildiz verilmez, istemciye de gitmez", function()
		local offenders = {}
		for _, entry in SourceIndex do
			local isWallet = string.find(entry.fsPath, "PlayerDataService", 1, true) ~= nil
			if not isWallet and string.find(stripComments(entry.source), "AddStars") then
				table.insert(offenders, entry.fsPath)
			end
		end
		expect(offenders).toEqual({})
		local Schema = require(Shared.Net.Schema)
		for name in Schema.Messages do
			expect(string.find(string.lower(name), "star")).toBeNil()
		end
	end)
end)
