--!strict

-- Ilk parmak (ya da fare) izlenir, digerleri yok sayilir. Her cagri olay listesi dondurur: "start", "point", "stop", "tap".
-- Parmak tuvalden cikinca cizgi biter, girince yenisi baslar.
local Pointer = {}
Pointer.__index = Pointer

function Pointer.new()
	return setmetatable({ active = nil, drawing = false, tapOnly = false }, Pointer)
end

function Pointer:began(id: any, inside: boolean, tapOnly: boolean?): { string }
	local events = {}
	if self.active ~= nil then
		return events
	end
	self.active = id
	self.tapOnly = tapOnly == true
	if inside then
		if self.tapOnly then
			table.insert(events, "tap")
		else
			self.drawing = true
			table.insert(events, "start")
			table.insert(events, "point")
		end
	end
	return events
end

function Pointer:moved(id: any, inside: boolean): { string }
	local events = {}
	if id ~= self.active or self.tapOnly then
		return events
	end
	if inside then
		if not self.drawing then
			self.drawing = true
			table.insert(events, "start")
		end
		table.insert(events, "point")
	elseif self.drawing then
		self.drawing = false
		table.insert(events, "stop")
	end
	return events
end

function Pointer:ended(id: any): { string }
	local events = {}
	if id ~= self.active then
		return events
	end
	if self.drawing then
		table.insert(events, "stop")
	end
	self.active = nil
	self.drawing = false
	self.tapOnly = false
	return events
end

function Pointer:cancel(): { string }
	local events = {}
	if self.drawing then
		table.insert(events, "stop")
	end
	self.active = nil
	self.drawing = false
	self.tapOnly = false
	return events
end

return Pointer
