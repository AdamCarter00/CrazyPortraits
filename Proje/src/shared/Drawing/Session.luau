--!strict

-- Saf cizim oturumu: arac durumu, kesinlesmis cizgiler (gonderilen liste) ve geri alma gecmisi AYRI tutulur.
-- Geri alma gecmisi dolunca yalniz geri alinabilirlik kaybolur; cizgi gonderilen listeden dusmez.
local Drawing = require(script.Parent.Parent.Config.Drawing)

local Session = {}
Session.__index = Session

function Session.new()
	local self = setmetatable({}, Session)
	self:reset()
	return self
end

-- Dugmeler oturum nesnesine bagli kalir: yeni tur yeni nesne degil, reset ile baslar.
function Session:reset()
	self.tool = "brush"
	self.colorIndex = Drawing.DefaultColorIndex
	self.sizeIndex = Drawing.DefaultBrushIndex
	self.enabled = false
	self.strokes = {}
	self.undoStack = {}
	self.current = nil
	self.totalPixels = 0
	self.strokesStarted = 0
	self.undoCount = 0
end

local function makeStroke(self, isFill: boolean)
	local color = Drawing.Colors[self.colorIndex]
	local erasing = self.tool == "eraser"
	return {
		s = Drawing.BrushSizes[self.sizeIndex],
		r = if erasing then 1 else color.r / 255,
		g = if erasing then 1 else color.g / 255,
		b = if erasing then 1 else color.b / 255,
		isEraser = erasing,
		isFill = isFill,
		p = {},
	}
end

local function commit(self, stroke)
	table.insert(self.strokes, stroke)
	table.insert(self.undoStack, stroke)
	if #self.undoStack > Drawing.MaxUndoSteps then
		table.remove(self.undoStack, 1)
	end
end

function Session:setEnabled(enabled: boolean)
	self.enabled = enabled
	if not enabled then
		self:endStroke()
	end
end

function Session:selectColor(index: number)
	if Drawing.Colors[index] then
		self.colorIndex = index
		self.tool = "brush"
	end
end

function Session:selectSize(index: number)
	if Drawing.BrushSizes[index] then
		self.sizeIndex = index
		self.tool = "brush"
	end
end

function Session:selectEraser()
	self.tool = "eraser"
end

function Session:selectFill()
	self.tool = "fill"
end

function Session:selectedMarks(): { [string]: boolean }
	if self.tool == "eraser" then
		return { arac_silgi = true }
	end
	local marks = { [Drawing.Colors[self.colorIndex].mark] = true }
	if self.tool == "fill" then
		marks.arac_kova = true
	else
		marks[Drawing.BrushMarks[self.sizeIndex]] = true
	end
	return marks
end

function Session:canStartStroke(): boolean
	return self.enabled
		and #self.strokes < Drawing.MaxStrokes
		and self.totalPixels < Drawing.MaxTotalPixels
end

function Session:beginStroke(): boolean
	if self.tool == "fill" or not self:canStartStroke() then
		return false
	end
	self:endStroke()
	self.current = makeStroke(self, false)
	self.strokesStarted += 1
	return true
end

-- Nokta kabul edildiyse true. Butce dolunca cizim sessizce durur: yerel tuval ile gonderilen cizim ayni kalir.
function Session:addPoint(x: number, y: number): boolean
	local stroke = self.current
	if not stroke or not self.enabled or self.totalPixels >= Drawing.MaxTotalPixels then
		return false
	end
	table.insert(stroke.p, { x, y })
	self.totalPixels += 1
	if #stroke.p >= Drawing.MaxPixelsPerStroke then
		self:endStroke()
		if self.tool ~= "fill" and self:canStartStroke() then
			self.current = makeStroke(self, false)
			self.strokesStarted += 1
		end
	end
	return true
end

function Session:endStroke()
	local stroke = self.current
	self.current = nil
	if stroke and #stroke.p > 0 then
		commit(self, stroke)
	end
end

function Session:fill(x: number, y: number): any?
	if self.tool ~= "fill" or not self:canStartStroke() then
		return nil
	end
	local stroke = makeStroke(self, true)
	stroke.isEraser = false
	stroke.p = { { x, y } }
	self.totalPixels += 1
	self.strokesStarted += 1
	commit(self, stroke)
	return stroke
end

function Session:undo(): any?
	self:endStroke()
	local stroke = table.remove(self.undoStack)
	if not stroke then
		return nil
	end
	local index = table.find(self.strokes, stroke)
	if index then
		table.remove(self.strokes, index)
	end
	self.totalPixels = math.max(0, self.totalPixels - #stroke.p)
	self.undoCount += 1
	return stroke
end

function Session:getStrokes(): { any }
	self:endStroke()
	return self.strokes
end

function Session:clear()
	self.strokes = {}
	self.undoStack = {}
	self.current = nil
	self.totalPixels = 0
end

return Session
