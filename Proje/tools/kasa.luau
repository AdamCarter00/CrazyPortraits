--!nocheck

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")

-- Kasa yolu: KASA_YOLU varsa o; yoksa deponun klasor adindan (Oyunlar/<ad>/Proje -> OBSIDIAN_KOK/<ad>).
local OBSIDIAN_KOK = "C:/Users/Dev/Desktop/Obsidian"
local ARCHIVE_LAST_K = 0
local STATUSES = { fikir = true, acik = true, taslak = true, karar = true, olcum = true, dustu = true }
local DECIDED = { karar = true, olcum = true, dustu = true }
local HEADS = { "Karar →", "Kısıt →", "Neden", "Açık" }

local args = process.args

local function fail(message)
	stdio.ewrite(message .. "\n")
	process.exit(1)
end

local function trim(s)
	return (string.gsub((string.gsub(s, "^%s+", "")), "%s+$", ""))
end

local function slashes(path)
	return (string.gsub((string.gsub(path, "\\", "/")), "/+$", ""))
end

local function deriveVault()
	local dir = slashes(process.cwd)
	while dir ~= "" do
		if fs.isFile(dir .. "/default.project.json") then
			local game = string.match(dir, "([^/]+)/[Pp]roje$")
			if game then
				return slashes(process.env.OBSIDIAN_KOK or OBSIDIAN_KOK) .. "/" .. game
			end
			return nil
		end
		local parent = string.match(dir, "^(.*)/[^/]+$")
		if not parent or parent == dir then
			return nil
		end
		dir = parent
	end
	return nil
end

local vault = slashes(process.env.KASA_YOLU or deriveVault() or fail(
	"Kasa yolu bulunamadı: depo Oyunlar/<ad>/Proje biçiminde değil. KASA_YOLU ortam değişkeniyle ver."
))
local notesDir = vault .. "/notlar"

local function idKey(id)
	return (string.sub(id, 1, 1) == "T" and 0 or 10000) + tonumber(string.sub(id, 3))
end

local function byId(a, b)
	return idKey(a) < idKey(b)
end

local function listOf(value)
	local items = {}
	local inner = string.match(value or "", "^%[(.*)%]$") or ""
	for item in string.gmatch(inner, "[^,]+") do
		item = trim(item)
		if item ~= "" then
			table.insert(items, item)
		end
	end
	return items
end

local function linksOf(value)
	local ids = {}
	for id in string.gmatch(value or "", "%[%[([TK]%-%d%d%d)") do
		table.insert(ids, id)
	end
	return ids
end

local function parse(id, raw)
	local text = string.gsub(raw, "\r\n", "\n")
	local note = {
		id = id,
		text = text,
		meta = {},
		sections = {},
		heads = {},
		sistem = {},
		dayanir = {},
		gerilim = {},
		olcum = "",
		karar = "",
		kisit = "",
	}
	local front, body = string.match(text, "^%-%-%-\n(.-)\n%-%-%-\n(.*)$")
	if not front then
		note.broken = true
		return note
	end
	for line in string.gmatch(front .. "\n", "([^\n]*)\n") do
		local key, value = string.match(line, "^([%w_]+):(.*)$")
		if key then
			note.meta[key] = trim(value)
		end
	end
	note.durum = note.meta.durum
	note.sistem = listOf(note.meta.sistem)
	note.dayanir = linksOf(note.meta.dayanir)
	note.gerilim = linksOf(note.meta.gerilim)
	note.olcum = note.meta.olcum or ""
	note.title = string.match(body, "^\n*# ([^\n]+)")
	local current
	for line in string.gmatch(body .. "\n", "([^\n]*)\n") do
		local head = string.match(line, "^## (.+)$")
		if head then
			current = trim(head)
			table.insert(note.heads, current)
			note.sections[current] = {}
		elseif current then
			table.insert(note.sections[current], line)
		end
	end
	for name, lines in note.sections do
		note.sections[name] = trim(table.concat(lines, "\n"))
	end
	note.karar = note.sections["Karar →"] or ""
	note.kisit = note.sections["Kısıt →"] or ""
	return note
end

local function loadNotes()
	if not fs.isDir(notesDir) then
		fail("Kasa bulunamadı: " .. notesDir .. " (KASA_YOLU)")
	end
	local notes, order = {}, {}
	for _, name in fs.readDir(notesDir) do
		local id = string.match(name, "^([TK]%-%d%d%d)%.md$")
		if id then
			notes[id] = parse(id, fs.readFile(notesDir .. "/" .. name))
			table.insert(order, id)
		end
	end
	table.sort(order, byId)
	return notes, order
end

local function allowedTags()
	local tags = {}
	for _, name in fs.readDir(vault .. "/sistem") do
		local tag = string.match(name, "^(.+)%.md$")
		if tag then
			tags[tag] = true
		end
	end
	return tags
end

local function plain(s)
	return (string.gsub(s, "%[%[([^%]|]+)|?[^%]]*%]%]", "%1"))
end

local function indent(s)
	return "    " .. (string.gsub(s, "\n", "\n    "))
end

local function render(note)
	local meta = { "sistem: " .. (#note.sistem > 0 and table.concat(note.sistem, ", ") or "-") }
	if #note.dayanir > 0 then
		table.insert(meta, "dayanir: " .. table.concat(note.dayanir, ", "))
	end
	if #note.gerilim > 0 then
		table.insert(meta, "GERILIM: " .. table.concat(note.gerilim, ", "))
	end
	if note.olcum ~= "" then
		table.insert(meta, "olcum: " .. note.olcum)
	end
	local out = {
		string.format("%s [%s] %s", note.id, note.durum or "?", note.title or ""),
		"  " .. table.concat(meta, " | "),
		"  Karar:",
		indent(note.karar ~= "" and plain(note.karar) or "-"),
	}
	if note.kisit ~= "" then
		table.insert(out, "  Kısıt:")
		table.insert(out, indent(plain(note.kisit)))
	end
	return table.concat(out, "\n")
end

local function fingerprint(note)
	local parts = {
		note.durum or "",
		note.karar,
		note.kisit,
		table.concat(note.dayanir, ","),
		table.concat(note.gerilim, ","),
		note.olcum,
	}
	return string.sub(serde.hash("sha256", table.concat(parts, "\n\0\n")), 1, 16)
end

local function repoRoot()
	local dir = slashes(process.env.CLAUDE_PROJECT_DIR or process.cwd)
	while dir ~= "" do
		if fs.isFile(dir .. "/default.project.json") then
			return dir
		end
		local parent = string.match(dir, "^(.*)/[^/]*$")
		if parent == nil or parent == dir then
			break
		end
		dir = parent
	end
	return nil
end

local function marksPath()
	local root = repoRoot()
	if not root then
		fail("Repo kökü bulunamadı (default.project.json). Komutu repo içinden çalıştır.")
	end
	return root .. "/.kasa-iz.json"
end

local function readMarks()
	local path = marksPath()
	if not fs.isFile(path) then
		return {}
	end
	return serde.decode("json", fs.readFile(path))
end

local function writeMarks(marks)
	local ids = {}
	for id in marks do
		table.insert(ids, id)
	end
	table.sort(ids, byId)
	local lines = {}
	for index, id in ids do
		local mark = marks[id]
		local comma = index < #ids and "," or ""
		table.insert(lines, string.format('  "%s": {"h": "%s", "d": "%s"}%s', id, mark.h, mark.d, comma))
	end
	fs.writeFile(marksPath(), "{\n" .. table.concat(lines, "\n") .. "\n}\n")
end

local function option(name)
	for index, arg in args do
		if arg == name then
			return args[index + 1]
		end
	end
	return nil
end

local function flag(name)
	return table.find(args, name) ~= nil
end

local VALUE_OPTIONS = { ["--sistem"] = true }

local function idArgs()
	local ids = {}
	for index = 2, #args do
		local arg = string.upper(args[index])
		if VALUE_OPTIONS[args[index - 1]] then
			continue
		elseif string.match(arg, "^[TK]%-%d%d%d$") then
			table.insert(ids, arg)
		elseif string.sub(arg, 1, 2) ~= "--" then
			fail("Geçersiz not numarası: " .. args[index])
		end
	end
	return ids
end

local function joined(list)
	return #list > 0 and table.concat(list, ", ") or "-"
end

local function listLine(note, skipTag)
	local others = {}
	for _, tag in note.sistem do
		if tag ~= skipTag then
			table.insert(others, tag)
		end
	end
	local suffix = #others > 0 and ("  (" .. table.concat(others, ", ") .. ")") or ""
	return string.format("  %s [%s] %s%s", note.id, note.durum or "?", note.title or "", suffix)
end

local function cmdListe()
	local notes, order = loadNotes()
	local tags = allowedTags()
	local filter = args[2]
	if filter then
		if not tags[filter] then
			fail("Bilinmeyen sistem: " .. filter)
		end
		print(filter)
		for _, id in order do
			if table.find(notes[id].sistem, filter) then
				print(listLine(notes[id], filter))
			end
		end
		return
	end
	local counts = {}
	for _, id in order do
		local durum = notes[id].durum or "?"
		counts[durum] = (counts[durum] or 0) + 1
	end
	print(string.format(
		"KASA · %d not · karar %d · olcum %d · dustu %d · acik %d",
		#order, counts.karar or 0, counts.olcum or 0, counts.dustu or 0, counts.acik or 0
	))
	local names = {}
	for tag in tags do
		table.insert(names, tag)
	end
	table.sort(names)
	for _, tag in names do
		local rows = {}
		for _, id in order do
			local note = notes[id]
			if note.sistem[1] == tag and (note.durum == "karar" or note.durum == "olcum") then
				table.insert(rows, listLine(note, tag))
			end
		end
		if #rows > 0 then
			print("\n" .. tag)
			print(table.concat(rows, "\n"))
		end
	end
	local dropped, open = {}, {}
	for _, id in order do
		local note = notes[id]
		if note.durum == "dustu" then
			table.insert(dropped, listLine(note))
		elseif not DECIDED[note.durum] then
			table.insert(open, listLine(note))
		end
	end
	if #dropped > 0 then
		print("\nDüşenler (bu özellikler olmayacak)")
		print(table.concat(dropped, "\n"))
	end
	if #open > 0 then
		print("\nKarar değil (açık soru ya da fikir)")
		print(table.concat(open, "\n"))
	end
end

local function cmdSistem()
	local tag = args[2]
	if not tag or not allowedTags()[tag] then
		fail("Kullanım: sistem <ad> (sistemler için: liste)")
	end
	local notes, order = loadNotes()
	local live, dropped, open = {}, {}, {}
	for _, id in order do
		local note = notes[id]
		if table.find(note.sistem, tag) then
			if note.durum == "dustu" then
				table.insert(dropped, note)
			elseif DECIDED[note.durum] then
				table.insert(live, note)
			else
				table.insert(open, note)
			end
		end
	end
	local out = {}
	for _, note in live do
		table.insert(out, render(note))
	end
	print(table.concat(out, "\n\n"))
	if #dropped > 0 then
		print("\nDüşenler (bu özellikler olmayacak; kodda varsa kaldır)")
		for _, note in dropped do
			local karar = string.gsub(plain(note.karar), "%s*\n%s*", " ")
			print(string.format("  %s %s → %s", note.id, note.title or "", karar))
		end
	end
	if #open > 0 then
		print("\nKarar değil (açık soru ya da fikir)")
		for _, note in open do
			print(listLine(note, tag))
		end
	end
end

local function cmdOku()
	local ids = idArgs()
	if #ids == 0 then
		fail("Kullanım: oku <no> ...")
	end
	local notes = loadNotes()
	local out = {}
	for _, id in ids do
		table.insert(out, notes[id] and render(notes[id]) or (id .. ": böyle bir not yok"))
	end
	print(table.concat(out, "\n\n"))
end

local function cmdDegisen()
	local notes, order = loadNotes()
	local marks = readMarks()
	local changed, answered, openK, unapplied, vanished = {}, {}, {}, {}, {}
	for _, id in order do
		local note = notes[id]
		local mark = marks[id]
		if DECIDED[note.durum] then
			if mark == nil then
				table.insert(unapplied, id)
			elseif mark.h ~= fingerprint(note) then
				table.insert(mark.d == "acik" and answered or changed, id)
			end
		elseif note.durum == "acik" and string.sub(id, 1, 1) == "K" then
			table.insert(openK, id)
		end
	end
	for id in marks do
		if notes[id] == nil then
			table.insert(vanished, id)
		end
	end
	table.sort(vanished, byId)
	local all = flag("--hepsi")
	print(string.format("KASA · %d not", #order))
	if next(marks) == nil then
		print("Henüz hiçbir not işaretlenmedi: kod kasaya göre uyarlanmadı.")
	end
	print(string.format("Kararı değişen (%d): %s", #changed, joined(changed)))
	print(string.format("Cevaplanan K (%d): %s", #answered, joined(answered)))
	print(string.format("Bekleyen K (%d): %s", #openK, joined(openK)))
	print(string.format("Hiç uygulanmamış: %d not%s", #unapplied, all and "" or " (ayrıntı: degisen --hepsi)"))
	if #vanished > 0 then
		print("Kasada artık olmayan işaretli not: " .. joined(vanished))
	end
	if all and #unapplied > 0 then
		local groups, names = {}, {}
		for _, id in unapplied do
			local tag = notes[id].sistem[1] or "-"
			if not groups[tag] then
				groups[tag] = {}
				table.insert(names, tag)
			end
			table.insert(groups[tag], id)
		end
		table.sort(names)
		for _, tag in names do
			print(string.format("  %s: %s", tag, table.concat(groups[tag], ", ")))
		end
	end
	local detail = {}
	for _, id in changed do
		table.insert(detail, render(notes[id]))
	end
	for _, id in answered do
		table.insert(detail, render(notes[id]))
	end
	if #detail > 0 then
		print("\n" .. table.concat(detail, "\n\n"))
	end
end

local function cmdIsaretle()
	local notes, order = loadNotes()
	local ids = flag("--hepsi") and order or idArgs()
	if #ids == 0 then
		fail("Kullanım: isaretle <no> ... | --hepsi")
	end
	local marks = readMarks()
	for _, id in ids do
		local note = notes[id]
		if not note then
			fail(id .. ": böyle bir not yok")
		end
		marks[id] = { h = fingerprint(note), d = note.durum or "?" }
	end
	writeMarks(marks)
	print(string.format("%d not işaretlendi.", #ids))
end

local function cmdKac()
	local question = option("--soru")
	if not question or trim(question) == "" then
		fail('Kullanım: k-ac --soru "...?" --sistem a,b [--dayanir T-001,T-002] [--baglam "..."] [--varsayim "..."]')
	end
	question = trim(question)
	if string.sub(question, -1) ~= "?" then
		fail("Başlık tek bir soru olmalı ve ? ile bitmeli.")
	end
	local tags = allowedTags()
	local chosen = {}
	for tag in string.gmatch(option("--sistem") or "", "[^,%s]+") do
		if not tags[tag] then
			fail("Bilinmeyen sistem: " .. tag)
		end
		table.insert(chosen, tag)
	end
	if #chosen < 1 or #chosen > 3 then
		fail("--sistem 1-3 etiket ister.")
	end
	local notes = loadNotes()
	local depends = {}
	for id in string.gmatch(string.upper(option("--dayanir") or ""), "[TK]%-%d%d%d") do
		if not notes[id] then
			fail("dayanir: böyle bir not yok: " .. id)
		end
		table.insert(depends, '"[[' .. id .. ']]"')
	end
	local last = ARCHIVE_LAST_K
	for id in notes do
		if string.sub(id, 1, 1) == "K" then
			last = math.max(last, tonumber(string.sub(id, 3)))
		end
	end
	local id = string.format("K-%03d", last + 1)
	local path = notesDir .. "/" .. id .. ".md"
	if fs.isFile(path) then
		fail(id .. " zaten var.")
	end
	local stamp = "Claude Code, " .. os.date("%d.%m")
	local open = {}
	local context = option("--baglam")
	if context and trim(context) ~= "" then
		table.insert(open, stamp .. " — bağlam: " .. trim(context))
	end
	local assumption = option("--varsayim")
	if assumption and trim(assumption) ~= "" then
		table.insert(open, stamp .. " — varsayım: " .. trim(assumption) .. " Bu varsayımla devam edildi.")
	else
		table.insert(open, stamp .. " — cevap bekleniyor; bu parça yapılmadı.")
	end
	local text = table.concat({
		"---",
		"id: " .. id,
		"durum: acik",
		"sistem: [" .. table.concat(chosen, ", ") .. "]",
		"dayanir: [" .. table.concat(depends, ", ") .. "]",
		"gerilim: []",
		"olcum: ",
		"---",
		"",
		"# " .. question,
		"",
		"## Karar →",
		"",
		"",
		"## Kısıt →",
		"",
		"",
		"## Neden",
		"",
		"",
		"## Açık",
		table.concat(open, "\n\n"),
		"",
	}, "\n")
	fs.writeFile(path, text)
	local marks = readMarks()
	marks[id] = { h = fingerprint(parse(id, text)), d = "acik" }
	writeMarks(marks)
	print(id .. " açıldı: " .. question)
end

local function cmdKontrol()
	local notes, order = loadNotes()
	local tags = allowedTags()
	local warnings = {}
	local function warn(id, message)
		table.insert(warnings, id .. ": " .. message)
	end
	for _, id in order do
		local note = notes[id]
		local raw = fs.readFile(notesDir .. "/" .. id .. ".md")
		local text = note.text
		if string.sub(raw, 1, 3) == "\239\187\191" then
			warn(id, "BOM")
		end
		if string.find(raw, "\r", 1, true) then
			warn(id, "CRLF")
		end
		local shape = "^%-%-%-\nid: [^\n]+\ndurum: [^\n]+\nsistem: %[[^\n]*%]\ndayanir: %[[^\n]*%]\n"
			.. "gerilim: %[[^\n]*%]\nolcum: [^\n]*\n%-%-%-\n\n# [^\n]+\n\n"
		if not string.match(text, shape) then
			warn(id, "frontmatter ya da başlık biçimi")
		else
			if note.meta.id ~= id then
				warn(id, "id dosya adıyla uyuşmuyor")
			end
			if not STATUSES[note.durum] then
				warn(id, "geçersiz durum: " .. tostring(note.durum))
			end
			for _, tag in note.sistem do
				if not tags[tag] then
					warn(id, "bilinmeyen sistem: " .. tag)
				end
			end
		end
		if table.concat(note.heads, "|") ~= table.concat(HEADS, "|") then
			warn(id, "başlıklar: " .. table.concat(note.heads, " · "))
		end
		for head in string.gmatch(text, "\n## ([^\n]+)\n## ") do
			warn(id, "boş bölüm tek newline: " .. head)
		end
		for head in string.gmatch(text, "\n## ([^\n]+)\n\n## ") do
			warn(id, "boş bölüm tek boş satır: " .. head)
		end
		local ending = "## Açık\n"
		if string.sub(text, -#ending) == ending then
			warn(id, "dosya sonu: boş Açık tek newline")
		elseif string.sub(text, -3) == "\n\n\n" then
			warn(id, "dosya sonu: fazla newline")
		elseif string.sub(text, -1) ~= "\n" then
			warn(id, "dosya sonu: newline yok")
		end
	end
	for _, id in order do
		local note = notes[id]
		local seen = {}
		for link in string.gmatch(note.text, "%[%[([TK]%-%d%d%d)%]%]") do
			if not notes[link] and not seen[link] then
				seen[link] = true
				warn(id, "kırık bağ: " .. link)
			end
		end
		if note.durum ~= "dustu" then
			for _, dep in note.dayanir do
				if notes[dep] and notes[dep].durum == "dustu" then
					warn(id, "düşmüş nota dayanıyor: " .. dep)
				end
			end
		end
	end
	local counts, present, lastT = {}, {}, 0
	for _, id in order do
		local durum = notes[id].durum or "?"
		counts[durum] = (counts[durum] or 0) + 1
		if string.sub(id, 1, 1) == "T" then
			local number = tonumber(string.sub(id, 3))
			present[number] = true
			lastT = math.max(lastT, number)
		end
	end
	local missing = {}
	for number = 1, lastT do
		if not present[number] then
			table.insert(missing, string.format("T-%03d", number))
		end
	end
	print(string.format("%d not · son T-%03d · eksik T: %s", #order, lastT, joined(missing)))
	local parts = {}
	for _, durum in { "karar", "olcum", "dustu", "acik", "fikir", "taslak" } do
		if counts[durum] then
			table.insert(parts, durum .. " " .. counts[durum])
		end
	end
	print(table.concat(parts, " · "))
	for _, message in warnings do
		print("UYARI " .. message)
	end
end

local function luauFiles(dir, out)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			luauFiles(path, out)
		elseif string.match(name, "%.luau$") then
			table.insert(out, path)
		end
	end
	return out
end

local function testedIds()
	local root = repoRoot()
	if not root or not fs.isDir(root .. "/tests") then
		fail("tests/ bulunamadı. Komutu repo içinden çalıştır.")
	end
	local tested = {}
	for _, path in luauFiles(root .. "/tests", {}) do
		for name in string.gmatch(fs.readFile(path), "%f[%w_]it%(%s*\"([^\"]*)\"") do
			local rest = name
			while true do
				local id, after = string.match(rest, "^([TK]%-%d%d%d)%s*,?%s*(.*)$")
				if not id then
					break
				end
				tested[id] = true
				rest = after
			end
		end
	end
	return tested
end

local function cmdKapsam()
	local notes, order = loadNotes()
	local scope = idArgs()
	if #scope == 0 then
		scope = order
	else
		table.sort(scope, byId)
	end
	local tagFilter = option("--sistem")
	if flag("--sistem") then
		if not tagFilter or not allowedTags()[tagFilter] then
			fail("Bilinmeyen sistem: " .. tostring(tagFilter))
		end
		local filtered = {}
		for _, id in scope do
			if notes[id] and table.find(notes[id].sistem, tagFilter) then
				table.insert(filtered, id)
			end
		end
		scope = filtered
	end
	local tested = testedIds()
	local groups, names, droppedWith, droppedWithout, undecided = {}, {}, {}, {}, {}
	local total, covered = 0, 0
	for _, id in scope do
		local note = notes[id]
		if not note then
			fail(id .. ": böyle bir not yok")
		end
		if note.durum == "dustu" then
			table.insert(tested[id] and droppedWith or droppedWithout, id)
		elseif note.durum == "karar" or note.durum == "olcum" then
			total += 1
			if tested[id] then
				covered += 1
			else
				local tag = tagFilter or note.sistem[1] or "-"
				if not groups[tag] then
					groups[tag] = {}
					table.insert(names, tag)
				end
				table.insert(groups[tag], id)
			end
		else
			table.insert(undecided, id)
		end
	end
	table.sort(names)
	print(string.format("KAPSAM · karar/olcum %d not · testi olan %d · olmayan %d", total, covered, total - covered))
	for _, tag in names do
		print(string.format("  %s: %s", tag, table.concat(groups[tag], ", ")))
	end
	if #droppedWith + #droppedWithout > 0 then
		print(string.format("\nDüşenler (%d): test şart değil, kalıntı aranır", #droppedWith + #droppedWithout))
		print("  testi olan: " .. joined(droppedWith))
		print("  testi olmayan: " .. joined(droppedWithout))
	end
	if #undecided > 0 then
		print("\nKarar değil: " .. joined(undecided))
	end
end

local function cmdBagli()
	local ids = idArgs()
	if #ids == 0 then
		fail("Kullanım: bagli <no> ...")
	end
	local notes, order = loadNotes()
	local dependents = {}
	for _, id in order do
		for _, dep in notes[id].dayanir do
			dependents[dep] = dependents[dep] or {}
			table.insert(dependents[dep], id)
		end
	end
	local out = {}
	for _, id in ids do
		local note = notes[id]
		if not note then
			table.insert(out, id .. ": böyle bir not yok")
			continue
		end
		local seen = { [id] = true }
		local first = {}
		for _, dep in dependents[id] or {} do
			if not seen[dep] then
				seen[dep] = true
				table.insert(first, dep)
			end
		end
		local second = {}
		for _, near in first do
			for _, dep in dependents[near] or {} do
				if not seen[dep] then
					seen[dep] = true
					table.insert(second, dep)
				end
			end
		end
		table.sort(first, byId)
		table.sort(second, byId)
		local lines = { string.format("%s [%s] %s", id, note.durum or "?", note.title or "") }
		for _, group in { { "1 adım", first }, { "2 adım", second } } do
			table.insert(lines, string.format("  %s (%d)", group[1], #group[2]))
			for _, dep in group[2] do
				table.insert(lines, "  " .. listLine(notes[dep]))
			end
		end
		table.insert(out, table.concat(lines, "\n"))
	end
	print(table.concat(out, "\n\n"))
end

local commands = {
	liste = cmdListe,
	sistem = cmdSistem,
	oku = cmdOku,
	bagli = cmdBagli,
	degisen = cmdDegisen,
	isaretle = cmdIsaretle,
	["k-ac"] = cmdKac,
	kontrol = cmdKontrol,
	kapsam = cmdKapsam,
}

local run = commands[args[1] or ""]
if not run then
	fail("Komutlar: liste [sistem] · sistem <ad> · oku <no> ... · bagli <no> ... · degisen [--hepsi] · isaretle <no> ... | --hepsi · k-ac · kontrol · kapsam [no ...] [--sistem <ad>]")
end
run()
