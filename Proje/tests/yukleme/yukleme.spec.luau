--!nocheck

local Binder = require(Client.Binder)
local Loading = require(Shared.Config.Loading)
local Terms = require(Shared.Config.Terms)
local Screen = require(Shared.Loading.Screen)
local Schema = require(Shared.Net.Schema)

local function sourceOf(fragment)
	for _, entry in SourceIndex do
		if string.find(entry.fsPath, fragment, 1, true) then
			return entry.source
		end
	end
	error("kaynak yok: " .. fragment)
end

describe("Yukleme", function()
	it("T-018: adim anlatimi yok; ipuclari tam olarak uc cumle", function()
		expect(Terms.LoadingSteps).toBeNil()
		expect(Terms.LoadingTips).toEqual({
			"Tip: Making people laugh matters more than drawing well!",
			"Tip: Everyone sees your drawing at the end of the round!",
			"Tip: Tap an emoji to react to a drawing!",
		})
		local marks = {}
		for _, entry in Binder.expected() do
			marks[entry.mark] = true
		end
		expect(marks.yukleme_adim_1).toBeNil()
		expect(marks.yukleme_ipucu).toBe(true)
	end)

	it("T-025: ipucu Config suresinde bir degisir ve basa doner", function()
		local count = #Terms.LoadingTips
		local step = Loading.TipSeconds
		expect(Screen.tipIndex(0, count, step)).toBe(1)
		expect(Screen.tipIndex(step * 0.99, count, step)).toBe(1)
		expect(Screen.tipIndex(step, count, step)).toBe(2)
		expect(Screen.tipIndex(step * count, count, step)).toBe(1)
		expect(Screen.tipIndex(step * (count * 5 + 2), count, step)).toBe(3)
	end)

	it("T-025: ekran gercek yuklemeye bagli kapanir; alt sure dolmadan kapanmaz", function()
		local min = Loading.MinSeconds
		expect(Screen.shouldClose("loading", true, min + 60, min)).toBe(false)
		expect(Screen.shouldClose("ready", false, min + 60, min)).toBe(false)
		expect(Screen.shouldClose("ready", true, min * 0.5, min)).toBe(false)
		expect(Screen.shouldClose("ready", true, min, min)).toBe(true)
	end)

	it("T-025: yukleme basarisizsa ekran kapanmaz, cubugun yazisi yeniden girmesini ister", function()
		expect(Screen.barText("loading", Terms)).toBe("Loading...")
		expect(Screen.barText("ready", Terms)).toBe(Terms.Loading)
		expect(Screen.barText("failed", Terms)).toBe(Terms.DataLoadFailed)
		expect(Terms.DataLoadFailed).toBe("OOPS! PLEASE REJOIN")
		expect(Screen.shouldClose("failed", true, 1e6, Loading.MinSeconds)).toBe(false)
	end)

	it("T-025: hata yazisi Config rengindedir; hata disinda yazi kendi rengine ve Loading... metnine doner", function()
		expect(Loading.FailedTextColor).toBe("#FF0000")
		expect(Screen.barColor("failed", Loading.FailedTextColor)).toBe("#FF0000")
		for _, status in { "loading", "ready" } do
			expect(Screen.barColor(status, Loading.FailedTextColor)).toBeNil()
			expect(Screen.barText(status, Terms)).toBe("Loading...")
		end
	end)

	it("K-012: dolgu dolmaz; en soldan baslar, saga gider, geri doner", function()
		local cycle = Loading.BarCycleSeconds
		local function near(a, b)
			expect(math.abs(a - b) < 1e-9).toBe(true)
		end
		near(Screen.fillPosition(0, cycle, 0.3), 0)
		near(Screen.fillPosition(cycle, cycle, 0.3), 0.7)
		near(Screen.fillPosition(cycle * 0.5, cycle, 0.3), 0.35)
		near(Screen.fillPosition(cycle * 1.5, cycle, 0.3), 0.35)
		near(Screen.fillPosition(cycle * 2, cycle, 0.3), 0)
		near(Screen.fillPosition(0, cycle, -0.3), 0.3)
		near(Screen.fillPosition(cycle, cycle, -0.3), 1)
	end)

	it("K-013: yukleme basarisizsa dolgu durur", function()
		expect(Screen.fillMoves("loading")).toBe(true)
		expect(Screen.fillMoves("failed")).toBe(false)
	end)

	it("T-025: yeniden dene dugmesi ve durum yazisi yok; profil acilamazsa oyuncu atilmaz, sonuc istemciye gider", function()
		local marks = {}
		for _, entry in Binder.expected() do
			marks[entry.mark] = true
		end
		expect(marks.yukleme_tekrar).toBeNil()
		expect(marks.yukleme_durum).toBeNil()
		expect(Schema.Messages.Loaded.fields).toEqual({ ok = "boolean" })
		expect(string.find(sourceOf("PlayerDataService"), ":Kick(", 1, true)).toBeNil()
		expect(string.find(sourceOf("Main.server"), "\"Loaded\"", 1, true)).toBeTruthy()
	end)
end)
