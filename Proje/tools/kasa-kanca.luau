--!nocheck
-- Claude Code kancasinda yalniz cikis kodu 2 araci durdurur.

local process = require("@lune/process")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")

-- Kapali alan: butun Obsidian klasoru (oyun kasasi da PORTFOY da). Kasa yalniz tools/kasa.luau ile okunur.
-- KASA_YOLU verilmisse o kasa da ayrica kapatilir.
local OBSIDIAN_KOK = "C:/Users/Dev/Desktop/Obsidian"

-- Git Bash yollari /c/... biciminde gelir; karsilastirma icin c:/... yapilir.
local function normalize(path)
	local lowered = string.lower((string.gsub(path, "\\", "/")))
	return (string.gsub((string.gsub(lowered, "^/(%a)/", "%1:/")), "/+$", ""))
end

local roots = { normalize(process.env.OBSIDIAN_KOK or OBSIDIAN_KOK) }
if process.env.KASA_YOLU then
	table.insert(roots, normalize(process.env.KASA_YOLU))
end

local ok, input = pcall(function()
	return serde.decode("json", stdio.readToEnd())
end)
if not ok or type(input) ~= "table" then
	process.exit(0)
end

local toolInput = input.tool_input or {}

local function insideVault(path)
	if type(path) ~= "string" or path == "" then
		return false
	end
	local target = normalize(path)
	for _, vault in roots do
		local tail = string.match(vault, "([^/]+/[^/]+)$") or vault
		if target == vault or string.sub(target, 1, #vault + 1) == vault .. "/" then
			return true
		end
		if string.find(target .. "/", "/" .. tail .. "/", 1, true) ~= nil then
			return true
		end
	end
	return false
end

local function commandMentionsVault(command)
	for _, vault in roots do
		local tail = string.match(vault, "([^/]+/[^/]+)$") or vault
		if string.find(command, tail, 1, true) ~= nil then
			return true
		end
	end
	return false
end

local blocked = insideVault(toolInput.file_path) or insideVault(toolInput.path) or insideVault(toolInput.notebook_path)

if type(toolInput.command) == "string" then
	local command = string.lower((string.gsub(toolInput.command, "\\", "/")))
	local mentionsVault = commandMentionsVault(command)
	if mentionsVault and not string.find(command, "tools/kasa.luau", 1, true) then
		blocked = true
	end
end

if blocked then
	stdio.ewrite("Kasa dosyalarına doğrudan erişim kapalı. Kasayı `lune run tools/kasa.luau` ile oku; K'yi `k-ac` ile aç.\n")
	process.exit(2)
end
process.exit(0)
