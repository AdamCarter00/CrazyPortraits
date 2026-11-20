--!nocheck

local Binder = require(Client.Binder)
local Round = require(Shared.Config.Round)

describe("Oylama -- emoji seti", function()
	it("T-027: puanli emojiler komik, cilgin, sok; kuru kafa yok; notr emoji dusunceli", function()
		expect(Round.Emojis).toEqual({ "laugh", "crazy", "shocked", "thinking" })
		expect(Round.NeutralEmojis).toEqual({ "thinking" })
		expect(table.find(Round.Emojis, "skull")).toBeNil()
		expect(table.find(Round.Emojis, "normal")).toBeNil()
		local marks = {}
		for _, entry in Binder.expected() do
			marks[entry.mark] = true
		end
		expect(marks.emoji_skull).toBeNil()
		expect(marks.emoji_normal).toBeNil()
	end)

	it("K-003: her notr emoji emoji setinde var", function()
		for _, name in Round.NeutralEmojis do
			expect(table.find(Round.Emojis, name)).toBeTruthy()
		end
	end)

	it("T-027: her emojinin Roblox gorsel kimligi var, fazlasi yok", function()
		local extra = {}
		for name, image in Round.EmojiImages do
			if table.find(Round.Emojis, name) == nil then
				table.insert(extra, name)
			end
			expect(string.match(image, "^rbxassetid://%d+$")).toBeTruthy()
		end
		expect(extra).toEqual({})
		for _, name in Round.Emojis do
			expect(Round.EmojiImages[name]).toBeTruthy()
		end
	end)
end)
