--!nocheck

local Binder = require(Client.Binder)
local Binding = require(Shared.Config.Binding)

local function fakeInstance(className, mark, children)
	local attributes = { Isaret = mark }
	return {
		ClassName = className,
		IsA = function(self, name)
			if name == "GuiButton" then
				return self.ClassName == "TextButton" or self.ClassName == "ImageButton"
			end
			return self.ClassName == name
		end,
		GetAttribute = function(_, key)
			return attributes[key]
		end,
		GetChildren = function()
			return children or {}
		end,
	}
end

local function worldFor(expected, overrides)
	local instances = {}
	for _, entry in expected do
		local className = if entry.class == "GuiButton" then "TextButton" else entry.class
		local children = nil
		if entry.selectable then
			children = { fakeInstance("UIStroke", Binding.SelectedMark) }
		end
		if not (overrides and overrides[entry.mark] == "yok") then
			table.insert(instances, fakeInstance(overrides and overrides[entry.mark] or className, entry.mark, children))
		end
	end
	return {
		GetDescendants = function()
			return instances
		end,
	}
end

describe("Arayuz -- Binder", function()
	it("is-3: tam isaretli arayuz baglanir", function()
		local expected = Binder.expected()
		local bound, selected = Binder.collect(worldFor(expected), expected, function() end)
		expect(bound.cizim_tuval).toBeTruthy()
		expect(selected.renk_siyah).toBeTruthy()
	end)

	it("is-3: tryCollect sorunlari firlatmadan listeler; PlayerGui bos ise hepsi eksik gorunur", function()
		local expected = Binder.expected()
		local empty = { GetDescendants = function() return {} end }
		local _, _, problems = Binder.tryCollect(empty, expected)
		expect(#problems).toBe(#expected)
		local _, _, ok = Binder.tryCollect(worldFor(expected), expected)
		expect(#ok).toBe(0)
	end)

	it("is-3: eksik, cift ve yanlis sinif hata verir; hicbir nesne yaratilmaz", function()
		local expected = Binder.expected()
		local world = worldFor(expected, { cizim_sure = "yok", cizim_tuval = "Frame" })
		expect(function()
			Binder.collect(world, expected, function() end)
		end).toThrow("2 baglama sorunu")
		local instances = world:GetDescendants()
		table.insert(instances, fakeInstance("TextButton", "cizim_gonder"))
		expect(function()
			Binder.collect(world, expected, function() end)
		end).toThrow("baglama sorunu")
	end)

	it("is-3: kodda gecen her isaret BAGLAMA.md'de yazili", function()
		local doc = fsRead("BAGLAMA.md")
		local missing = {}
		for _, entry in Binder.expected() do
			if not string.find(doc, "`" .. entry.mark .. "`", 1, true) then
				table.insert(missing, entry.mark)
			end
		end
		if not string.find(doc, "`" .. Binding.SelectedMark .. "`", 1, true) then
			table.insert(missing, Binding.SelectedMark)
		end
		expect(missing).toEqual({})
	end)
end)
