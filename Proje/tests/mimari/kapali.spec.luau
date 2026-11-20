--!nocheck

local function stripComments(source)
	local noBlocks = string.gsub(source, "%-%-%[(=*)%[.-%]%1%]", "")
	return (string.gsub(noBlocks, "%-%-[^\n]*", ""))
end

local function offendersFor(patterns, allowed)
	local offenders = {}
	for _, entry in SourceIndex do
		local isAllowed = false
		for _, name in allowed or {} do
			if string.find(entry.fsPath, name, 1, true) then
				isAllowed = true
			end
		end
		if not isAllowed then
			local code = stripComments(entry.source)
			for _, pattern in patterns do
				if string.find(code, pattern) then
					table.insert(offenders, entry.fsPath .. " (" .. pattern .. ")")
				end
			end
		end
	end
	return offenders
end

describe("Kapali ozellikler", function()
	it("T-010: Kapi 1'de Robux satisi ve market yok", function()
		expect(offendersFor({
			"MarketplaceService",
			"ProcessReceipt",
			"PromptProductPurchase",
			"PromptGamePassPurchase",
			"PromptPurchase",
			"UserOwnsGamePassAsync",
		})).toEqual({})
	end)

	it("T-010: cerceve satin alma ve takma kodu yok; sahiplik yalniz profil servisinde", function()
		expect(offendersFor({ "FrameShop", "EquipFrame", "BuyFrame" }, { "PlayerDataService" })).toEqual({})
		expect(offendersFor({ "GrantFrame", "SetEquippedFrame", "IsFrameOwned" }, { "PlayerDataService" })).toEqual({})
	end)

	it("T-011: Be Next Drawn kodu yok; hak alani yalniz profil sablonunda durur", function()
		expect(offendersFor({ "SubjectGuarantee", "subjectQueue", "BeNextDrawn" })).toEqual({})
		expect(offendersFor({ "subjectGuarantee" }, { "PlayerDataService" })).toEqual({})
	end)

	it("T-001: tema secimi ve tema mesaji yok", function()
		local Schema = require(Shared.Net.Schema)
		for _, name in { "Drawing", "Reveal", "Podium", "Lobby" } do
			expect(Schema.Messages[name].fields.theme).toBeNil()
		end
	end)
end)
