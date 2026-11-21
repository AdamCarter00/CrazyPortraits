--!nocheck

local Binder = require(Client.Binder)
local Binding = require(Shared.Config.Binding)
local Marker = require(Shared.Binding.Marker)
local Round = require(Shared.Config.Round)
local Drawing = require(Shared.Config.Drawing)

local FAMILIES = {
	GuiButton = { TextButton = true, ImageButton = true },
	BasePart = { Part = true, MeshPart = true },
}

local function node(name, className, children, attributes)
	local self = { Name = name, ClassName = className, Children = children or {}, Attributes = attributes or {} }
	function self:IsA(other)
		return self.ClassName == other or (FAMILIES[other] ~= nil and FAMILIES[other][self.ClassName] == true)
	end
	function self:GetAttribute(key)
		return self.Attributes[key]
	end
	function self:GetChildren()
		return self.Children
	end
	function self:GetFullName()
		return "Root." .. self.Name
	end
	function self:GetDescendants()
		local list = {}
		local function walk(parent)
			for _, child in parent.Children do
				table.insert(list, child)
				walk(child)
			end
		end
		walk(self)
		return list
	end
	return self
end

local function concreteClass(entry)
	if entry.class == "GuiButton" then
		return "TextButton"
	elseif entry.class == "BasePart" then
		return "Part"
	end
	return entry.class
end

local function treeFor(expected, skip)
	local children = {}
	for _, entry in expected do
		if not (skip and skip[entry.mark]) then
			local inner = {}
			if entry.selectable then
				table.insert(inner, node(Binding.SelectedMark, "UIStroke"))
			end
			if entry.tick then
				table.insert(inner, node(Binding.SelectedTick, "ImageLabel"))
			end
			table.insert(children, node(entry.mark, concreteClass(entry), inner))
		end
	end
	return node("Root", "Folder", children)
end

local function apply(plan)
	for _, item in plan.assign do
		item.inst.Attributes[Binding.MarkerAttribute] = item.mark
	end
	for _, item in plan.clear do
		item.inst.Attributes[Binding.MarkerAttribute] = nil
	end
end

local function plan(root, expected)
	return Marker.plan(root, expected, Binding.MarkerAttribute, Binding.SelectedMark, Binding.SelectedTick)
end

describe("Baglama -- kapsam", function()
	it("is-V0: her bekleyen isaretin grubu var ve isaretler tekil", function()
		local seen = {}
		for _, entry in Binder.expected() do
			expect(type(entry.group)).toBe("string")
			expect(seen[entry.mark]).toBeNil()
			seen[entry.mark] = true
		end
		for _, entry in Binder.expectedWorld() do
			expect(seen[entry.mark]).toBeNil()
			seen[entry.mark] = true
		end
	end)

	it("is-V0: emoji ve podyum yuvasi isaretleri Config'ten uretilir", function()
		local seen = {}
		for _, entry in Binder.expected() do
			seen[entry.mark] = entry
		end
		for _, name in Round.Emojis do
			expect(seen["emoji_" .. name].selectable).toBe(true)
		end
		for slot = 1, Round.PodiumSize do
			expect(seen["podyum_yuva_" .. slot]).toBeTruthy()
			expect(seen["podyum_tepki_" .. slot]).toBeTruthy()
		end
		expect(seen["podyum_yuva_" .. Round.PodiumSize + 1]).toBeNil()
	end)

	it("is-V0: BAGLAMA.md'deki her isaret kodda var, kodda olan her isaret BAGLAMA.md'de", function()
		local inCode = {}
		for _, entry in Binder.expected() do
			inCode[entry.mark] = true
		end
		for _, entry in Binder.expectedWorld() do
			inCode[entry.mark] = true
		end
		local inDoc = {}
		for line in string.gmatch(fsRead("BAGLAMA.md"), "[^\r\n]+") do
			local firstCell = string.match(line, "^|%s*(`[^|]+)|")
			if firstCell then
				for mark in string.gmatch(firstCell, "`([^`]+)`") do
					inDoc[mark] = true
				end
			end
		end
		local onlyDoc, onlyCode = {}, {}
		for mark in inDoc do
			if not inCode[mark] then
				table.insert(onlyDoc, mark)
			end
		end
		for mark in inCode do
			if not inDoc[mark] then
				table.insert(onlyCode, mark)
			end
		end
		table.sort(onlyDoc)
		table.sort(onlyCode)
		expect(onlyDoc).toEqual({})
		expect(onlyCode).toEqual({})
	end)
end)

describe("Baglama -- Marker.plan", function()
	it("is-V0: tam arayuz sorunsuz planlanir; calistirinca Binder de baglar", function()
		local expected = Binder.expected()
		local root = treeFor(expected)
		local result = plan(root, expected)
		expect(#result.problems).toBe(0)
		expect(#result.clear).toBe(0)
		apply(result)
		local _, _, problems = Binder.tryCollect(root, expected)
		expect(problems).toEqual({})
	end)

	it("is-V0: tekrar calistirmak ayni sonucu verir, eksikler listelenir", function()
		local expected = Binder.expected()
		local root = treeFor(expected, { cizim_sure = true, podyum_ad_2 = true })
		local first = plan(root, expected)
		expect(#first.problems).toBe(2)
		apply(first)
		local second = plan(root, expected)
		expect(#second.problems).toBe(2)
		expect(#second.clear).toBe(0)
		expect(second.problems[1].kind).toBe("eksik")
	end)

	it("is-V0: cift ad ve yanlis sinif isaretlenmez, raporlanir", function()
		local expected = Binder.expected()
		local root = treeFor(expected)
		table.insert(root.Children, node("cizim_gonder", "TextButton"))
		for _, child in root.Children do
			if child.Name == "cizim_tuval" then
				child.ClassName = "Frame"
			end
		end
		local result = plan(root, expected)
		local kinds = {}
		for _, problem in result.problems do
			kinds[problem.mark] = problem.kind
		end
		expect(kinds.cizim_gonder).toBe("cift")
		expect(kinds.cizim_tuval).toBe("sinif")
		for _, item in result.assign do
			expect(item.mark == "cizim_gonder" or item.mark == "cizim_tuval").toBe(false)
		end
	end)

	it("is-V0: secili UIStroke eksikse, yanlis sinifsa ve aciksa ayri ayri bildirilir", function()
		local expected = Binder.expected()
		local root = treeFor(expected)
		for _, child in root.Children do
			if child.Name == "arac_silgi" then
				child.Children = {}
			elseif child.Name == "arac_kova" then
				child.Children[1].ClassName = "Frame"
			elseif child.Name == "arac_geri" then
				child.Children = { node(Binding.SelectedMark, "UIStroke") }
			elseif child.Name == "renk_siyah" then
				child.Children[1].Enabled = true
			end
		end
		local kinds = {}
		for _, problem in plan(root, expected).problems do
			kinds[problem.mark] = (problem.warning and "uyari:" or "") .. problem.kind
		end
		expect(kinds.arac_silgi).toBe("secili_eksik")
		expect(kinds.arac_kova).toBe("secili_hatali")
		expect(kinds.renk_siyah).toBe("uyari:secili_acik")
		expect(kinds.arac_geri).toBeNil()
	end)

	it("T-028: tick yalniz renklerde; eksik ya da yanlis sinif tick bildirilir, dogrusu isaretlenir", function()
		local expected = Binder.expected()
		for _, entry in expected do
			expect(entry.tick == true).toBe(string.sub(entry.mark, 1, 5) == "renk_")
		end
		local root = treeFor(expected)
		for _, child in root.Children do
			if child.Name == "renk_beyaz" then
				child.Children = { child.Children[1] }
			elseif child.Name == "renk_gri" then
				child.Children[2].ClassName = "Frame"
			end
		end
		local result = plan(root, expected)
		local kinds = {}
		for _, problem in result.problems do
			kinds[problem.mark] = problem.kind
		end
		expect(kinds.renk_beyaz).toBe("tik_eksik")
		expect(kinds.renk_gri).toBe("tik_hatali")
		local tickAssigned = 0
		for _, item in result.assign do
			if item.mark == Binding.SelectedTick then
				tickAssigned += 1
			end
		end
		expect(tickAssigned).toBe(#Drawing.Colors - 2)
		apply(result)
		expect(#plan(root, expected).clear).toBe(0)
	end)

	it("is-V0: adi degisen nesnenin eski isareti temizlenecekler arasinda cikar", function()
		local expected = Binder.expected()
		local root = treeFor(expected)
		table.insert(root.Children, node("gonder_eski", "TextButton", {}, { Isaret = "cizim_gonder" }))
		table.insert(root.Children, node("bilinmeyen", "Frame", {}, { Isaret = "olmayan_isaret" }))
		local reasons = {}
		for _, item in plan(root, expected).clear do
			reasons[item.old] = item.reason
		end
		expect(reasons.cizim_gonder).toBe("adi isaretle uyusmuyor")
		expect(reasons.olmayan_isaret).toBe("taninmayan isaret")
	end)

	it("is-V0: komut varsayilan olarak yazmaz", function()
		expect(string.find(fsRead("tools/isaretle.luau"), "local APPLY = false", 1, true)).toBeTruthy()
	end)
end)
