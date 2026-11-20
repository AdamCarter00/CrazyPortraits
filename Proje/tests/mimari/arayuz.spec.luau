--!nocheck

local GuiVisibility = require(Client.GuiVisibility)

local function fakeGui(className, marker, enabled)
	local attributes = { Isaret = marker }
	return {
		ClassName = className,
		Enabled = enabled,
		IsA = function(self, name)
			return self.ClassName == name
		end,
		GetAttribute = function(_, key)
			return attributes[key]
		end,
	}
end

local function fakePlayerGui(children)
	return {
		GetChildren = function()
			return children
		end,
	}
end

describe("Arayuz -- GuiVisibility", function()
	it("iş 2: yalniz isaretli kendi GUI'ler gizlenir, TouchGui ve yabancilar kalir", function()
		local canvas = fakeGui("ScreenGui", "canvas", true)
		local timer = fakeGui("ScreenGui", "timer", true)
		local touch = fakeGui("ScreenGui", nil, true)
		touch.Name = "TouchGui"
		local frame = fakeGui("Frame", "x", true)
		local visibility = GuiVisibility.new(fakePlayerGui({ canvas, timer, touch, frame }))
		visibility:HideExcept({ canvas })
		expect(canvas.Enabled).toBe(true)
		expect(timer.Enabled).toBe(false)
		expect(touch.Enabled).toBe(true)
		expect(frame.Enabled).toBe(true)
	end)

	it("iş 2: Restore yalniz kendi kapattiklarini acar", function()
		local shown = fakeGui("ScreenGui", "a", true)
		local alreadyOff = fakeGui("ScreenGui", "b", false)
		local visibility = GuiVisibility.new(fakePlayerGui({ shown, alreadyOff }))
		visibility:HideExcept({})
		expect(shown.Enabled).toBe(false)
		visibility:Restore()
		expect(shown.Enabled).toBe(true)
		expect(alreadyOff.Enabled).toBe(false)
	end)

	it("iş 2: istemci kodu PlayerGui'yi gezip topluca kapatmaz", function()
		local offenders = {}
		for _, entry in SourceIndex do
			if entry.area == "Client" and not string.find(entry.fsPath, "GuiVisibility", 1, true)
				and not string.find(entry.fsPath, "AdminClient", 1, true) then
				if string.find(entry.source, "GetChildren%(%)[^\n]*\n[^\n]*IsA%(\"ScreenGui\"%)") then
					table.insert(offenders, entry.fsPath)
				end
			end
		end
		expect(offenders).toEqual({})
	end)
end)
