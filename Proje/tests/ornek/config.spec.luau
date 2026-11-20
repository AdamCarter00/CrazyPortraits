--!nocheck

local Terms = require(Shared.Config.Terms)

describe("Sablon -- Config", function()
	it("Terms yuklenir ve dondurulmustur", function()
		expect(type(Terms.GameName)).toBe("string")
		expect(table.isfrozen(Terms)).toBe(true)
	end)
end)
