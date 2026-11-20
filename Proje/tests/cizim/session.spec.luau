--!nocheck

local Session = require(Shared.Drawing.Session)
local Pointer = require(Shared.Drawing.Pointer)
local StrokeCodec = require(Shared.Drawing.StrokeCodec)
local StrokeValidator = require(Shared.Drawing.StrokeValidator)
local Drawing = require(Shared.Config.Drawing)

local function line(session, x, y, count)
	expect(session:beginStroke()).toBe(true)
	for i = 0, (count or 2) - 1 do
		session:addPoint(x + i, y)
	end
	session:endStroke()
end

local function sessionOn()
	local session = Session.new()
	session:setEnabled(true)
	return session
end

describe("Cizim -- Session (is 3)", function()
	it("is-3: 80 cizgiden sonra bas silinmez; gonderilen liste ve geri alma gecmisi ayridir", function()
		local session = sessionOn()
		for i = 1, Drawing.MaxStrokes do
			line(session, i, 1)
		end
		expect(#session.strokes).toBe(Drawing.MaxStrokes)
		expect(session.strokes[1].p[1][1]).toBe(1)
		expect(#session.undoStack).toBe(Drawing.MaxUndoSteps)
	end)

	it("is-3: gecmis siniri asilinca ilk cizgi gonderilen listede kalir, yalniz geri alinamaz", function()
		local fresh = loadShared({ Drawing = { MaxUndoSteps = 10 } })
		local session = require(fresh.Drawing.Session).new()
		session:setEnabled(true)
		for i = 1, 30 do
			line(session, i, 1)
		end
		local first = session.strokes[1]
		for _ = 1, 10 do
			expect(session:undo()).toBeTruthy()
		end
		expect(session:undo()).toBeNil()
		expect(#session.strokes).toBe(20)
		expect(session.strokes[1]).toBe(first)
	end)

	it("is-3: sinir dolunca yeni cizgi baslamaz; yerel tuval ile gonderilen ayni kalir", function()
		local session = sessionOn()
		for i = 1, Drawing.MaxStrokes do
			line(session, i, 1)
		end
		expect(session:beginStroke()).toBe(false)
		expect(#StrokeValidator.validate(StrokeCodec.encode(session:getStrokes()))).toBe(Drawing.MaxStrokes)
	end)

	it("is-3: geri alma cizgiyi ve butceyi geri verir", function()
		local session = sessionOn()
		line(session, 5, 5, 4)
		line(session, 9, 9, 3)
		expect(session.totalPixels).toBe(7)
		session:undo()
		expect(#session.strokes).toBe(1)
		expect(session.totalPixels).toBe(4)
	end)

	it("is-3: piksel butcesi dolunca cizim durur", function()
		local session = sessionOn()
		local accepted = 0
		for _ = 1, 20 do
			if session:beginStroke() then
				for i = 1, Drawing.MaxPixelsPerStroke do
					if session:addPoint(i % 500, 3) then
						accepted += 1
					end
				end
				session:endStroke()
			end
		end
		expect(accepted).toBe(Drawing.MaxTotalPixels)
		expect(session:beginStroke()).toBe(false)
	end)

	it("is-3: tek cizgi 1200 noktada bolunur, nokta kaybolmaz", function()
		local session = sessionOn()
		session:beginStroke()
		for i = 1, Drawing.MaxPixelsPerStroke + 5 do
			session:addPoint(i % 500, 1)
		end
		session:endStroke()
		expect(#session.strokes).toBe(2)
		expect(session.totalPixels).toBe(Drawing.MaxPixelsPerStroke + 5)
	end)

	it("is-3: silgi ayri durum; firca boyu secince beyaz cizmeye devam etmez", function()
		local session = sessionOn()
		session:selectColor(5)
		session:selectEraser()
		line(session, 1, 1)
		expect(session.strokes[1].isEraser).toBe(true)
		expect(session.strokes[1].r).toBe(1)
		session:selectSize(2)
		line(session, 2, 2)
		local stroke = session.strokes[2]
		expect(stroke.isEraser).toBe(false)
		expect(stroke.r).toBe(Drawing.Colors[5].r / 255)
		expect(stroke.s).toBe(Drawing.BrushSizes[2])
	end)

	it("is-3: renk secince silgiden cikilir, silgi renk durumunu bozmaz", function()
		local session = sessionOn()
		session:selectColor(7)
		session:selectEraser()
		session:selectColor(9)
		expect(session.tool).toBe("brush")
		session:selectEraser()
		expect(session.colorIndex).toBe(9)
	end)

	it("is-3: kova yalniz kova aracindayken calisir ve tek tohum noktasi yazar", function()
		local session = sessionOn()
		expect(session:fill(1, 1)).toBeNil()
		session:selectFill()
		local stroke = session:fill(10, 12)
		expect(stroke.isFill).toBe(true)
		expect(stroke.p).toEqual({ { 10, 12 } })
		expect(session:beginStroke()).toBe(false)
	end)

	it("is-3: kapaliyken cizilmez", function()
		local session = Session.new()
		expect(session:beginStroke()).toBe(false)
	end)

	it("is-3: kodlanan cizim yerel cizgilerle ayni sayida cizgi tasir", function()
		local session = sessionOn()
		session:selectColor(3)
		line(session, 7, 7, 5)
		session:selectFill()
		session:fill(20, 20)
		local decoded = StrokeCodec.decode(StrokeCodec.encode(session:getStrokes()))
		expect(#decoded).toBe(2)
		expect(decoded[2].f).toBe(true)
	end)
end)

describe("Cizim -- Pointer (T-015)", function()
	it("T-015: ilk parmak izlenir, ikinci parmak yok sayilir", function()
		local pointer = Pointer.new()
		expect(pointer:began(1, true)).toEqual({ "start", "point" })
		expect(pointer:began(2, true)).toEqual({})
		expect(pointer:moved(2, true)).toEqual({})
		expect(pointer:ended(2)).toEqual({})
		expect(pointer:moved(1, true)).toEqual({ "point" })
	end)

	it("T-015: parmak tuvalden cikinca cizgi biter, girince yenisi baslar", function()
		local pointer = Pointer.new()
		pointer:began(1, true)
		expect(pointer:moved(1, false)).toEqual({ "stop" })
		expect(pointer:moved(1, false)).toEqual({})
		expect(pointer:moved(1, true)).toEqual({ "start", "point" })
		expect(pointer:ended(1)).toEqual({ "stop" })
	end)

	it("T-015: tuval disinda baslayan parmak, girince cizmeye baslar", function()
		local pointer = Pointer.new()
		expect(pointer:began(1, false)).toEqual({})
		expect(pointer:moved(1, true)).toEqual({ "start", "point" })
	end)

	it("T-015: ilk parmak kalkinca ikincisi izlenebilir", function()
		local pointer = Pointer.new()
		pointer:began(1, true)
		pointer:began(2, true)
		pointer:ended(1)
		expect(pointer:began(2, true)).toEqual({ "start", "point" })
	end)

	it("T-015: kova modunda dokunus tek kez doldurur, surukleyince tekrar doldurmaz", function()
		local pointer = Pointer.new()
		expect(pointer:began(1, true, true)).toEqual({ "tap" })
		expect(pointer:moved(1, false)).toEqual({})
		expect(pointer:moved(1, true)).toEqual({})
		expect(pointer:ended(1)).toEqual({})
		expect(pointer:began(1, true)).toEqual({ "start", "point" })
	end)

	it("T-015: faz bitince iptal acik cizgiyi kapatir ve izlemeyi birakir", function()
		local pointer = Pointer.new()
		pointer:began(1, true)
		expect(pointer:cancel()).toEqual({ "stop" })
		expect(pointer:began(5, true)).toEqual({ "start", "point" })
	end)
end)

describe("Cizim -- Session.reset (is 3)", function()
	it("is-3: reset ayni nesneyi bastan baslatir; dugmelerin tuttugu oturum bayatlamaz", function()
		local session = sessionOn()
		session:selectColor(5)
		session:selectEraser()
		line(session, 1, 1)
		local before = session
		session:reset()
		expect(session).toBe(before)
		expect(#session.strokes).toBe(0)
		expect(session.tool).toBe("brush")
		expect(session.colorIndex).toBe(Drawing.DefaultColorIndex)
		expect(session.enabled).toBe(false)
		session:setEnabled(true)
		session:selectColor(7)
		expect(session.colorIndex).toBe(7)
	end)
end)
