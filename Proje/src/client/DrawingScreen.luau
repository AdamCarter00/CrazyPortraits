local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Drawing = require(Shared.Config.Drawing)
local Round = require(Shared.Config.Round)
local Terms = require(Shared.Config.Terms)
local Net = require(Shared.Net)
local Session = require(Shared.Drawing.Session)
local Pointer = require(Shared.Drawing.Pointer)
local StrokeCodec = require(Shared.Drawing.StrokeCodec)
local Countdown = require(Shared.Round.Countdown)
local CanvasView = require(script.Parent.CanvasView)

local DrawingScreen = {}
DrawingScreen.__index = DrawingScreen

local SELECTABLE = { "arac_silgi", "arac_kova" }
for _, color in Drawing.Colors do
	table.insert(SELECTABLE, color.mark)
end
for _, mark in Drawing.BrushMarks do
	table.insert(SELECTABLE, mark)
end

function DrawingScreen.new(refs, selected, ticks, visibility)
	local self = setmetatable({}, DrawingScreen)
	self.refs = refs
	self.selected = selected
	self.ticks = ticks
	self.visibility = visibility
	self.view = CanvasView.new(refs.cizim_tuval)
	self.session = Session.new()
	self.pointer = Pointer.new()
	self.roundId = nil
	self.submitted = false
	self.token = 0
	for _, color in Drawing.Colors do
		ticks[color.mark].Image = Drawing.TickImage
	end
	refs.cizim_ekran.Enabled = false
	refs.cizim_sayim_kutu.Visible = false
	self:_bindButtons()
	self:_bindInput()
	self:_selectTool()
	return self
end

function DrawingScreen:_selectTool()
	local active = self.session:selectedMarks()
	for _, mark in SELECTABLE do
		self.selected[mark].Enabled = active[mark] == true
	end
	for _, color in Drawing.Colors do
		self.ticks[color.mark].Visible = active[color.mark] == true
	end
end

function DrawingScreen:_bindButtons()
	local refs = self.refs
	for index, color in Drawing.Colors do
		refs[color.mark].Activated:Connect(function()
			self.session:selectColor(index)
			self:_selectTool()
		end)
	end
	for index, mark in Drawing.BrushMarks do
		refs[mark].Activated:Connect(function()
			self.session:selectSize(index)
			self:_selectTool()
		end)
	end
	refs.arac_silgi.Activated:Connect(function()
		self.session:selectEraser()
		self:_selectTool()
	end)
	refs.arac_kova.Activated:Connect(function()
		self.session:selectFill()
		self:_selectTool()
	end)
	refs.arac_geri.Activated:Connect(function()
		if self.session:undo() then
			self.view:redraw(self.session.strokes)
		end
	end)
	refs.cizim_gonder.Activated:Connect(function()
		self:submit()
	end)
end

function DrawingScreen:_handle(events, x, y)
	local session, view = self.session, self.view
	for _, event in events do
		if event == "start" then
			session:beginStroke()
		elseif event == "point" then
			local pixel = view:toCanvas(x, y)
			if session.current and session:addPoint(pixel.X, pixel.Y) then
				view:dab(session.current or session.strokes[#session.strokes], pixel)
			end
		elseif event == "stop" then
			session:endStroke()
			view:endLine()
		elseif event == "tap" then
			local pixel = view:toCanvas(x, y)
			local stroke = session:fill(pixel.X, pixel.Y)
			if stroke then
				view:fill(stroke)
			end
		end
	end
end

local function pointerId(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		return input
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseMovement then
		return "mouse"
	end
	return nil
end

function DrawingScreen:_bindInput()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not self.session.enabled then
			return
		end
		local id = pointerId(input)
		if id == nil or input.UserInputType == Enum.UserInputType.MouseMovement then
			return
		end
		local x, y = input.Position.X, input.Position.Y
		self:_handle(self.pointer:began(id, self.view:contains(x, y), self.session.tool == "fill"), x, y)
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not self.session.enabled then
			return
		end
		local id = pointerId(input)
		if id == nil then
			return
		end
		local isMove = input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
		if not isMove then
			return
		end
		local x, y = input.Position.X, input.Position.Y
		self:_handle(self.pointer:moved(id, self.view:contains(x, y)), x, y)
	end)
	UserInputService.InputEnded:Connect(function(input)
		local id = pointerId(input)
		if id == nil or input.UserInputType == Enum.UserInputType.MouseMovement then
			return
		end
		self:_handle(self.pointer:ended(id), input.Position.X, input.Position.Y)
	end)
end

function DrawingScreen:open(payload, localName)
	if self.roundId == payload.roundId then
		return
	end
	self.roundId = payload.roundId
	if self.onOpened then
		self.onOpened()
	end
	self.submitted = false
	self.token += 1
	local token = self.token
	local refs = self.refs

	self.session:reset()
	self.pointer:cancel()
	self.view:clear()
	self:_selectTool()

	local title = Countdown.title(payload, game.Players.LocalPlayer.UserId, Terms)
	refs.cizim_baslik.Text = title
	refs.cizim_sayim_yazi.Text = title
	refs.cizim_sayim_kutu.Visible = false

	self.visibility:HideExcept({ refs.cizim_ekran, refs.gecis_ekran })
	if self.healthWas == nil then
		self.healthWas = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Health)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end
	refs.cizim_ekran.Enabled = true

	local sentStrokes, sentAt = 0, -math.huge
	task.spawn(function()
		while self.token == token and not self.submitted do
			local now = workspace:GetServerTimeNow()
			local countdown = Countdown.at(payload, now, Round.CountdownSeconds)
			refs.cizim_sayim_kutu.Visible = countdown.show
			if countdown.digit then
				refs.cizim_sayim.Text = string.format(Terms.CountdownDigit, countdown.digit)
			end
			if now >= payload.startsAt then
				local remaining = math.max(0, math.ceil(payload.endsAt - now))
				refs.cizim_sure.Text = string.format(Terms.TimerText, remaining)
			end
			if countdown.canDraw then
				self.session:setEnabled(true)
				local strokes = #self.session:getStrokes()
				if strokes ~= sentStrokes and now - sentAt >= Round.ProgressSendSeconds then
					sentStrokes, sentAt = strokes, now
					Net.fireServer("Round", "Progress", { strokes = strokes })
				end
			end
			task.wait(0.2)
		end
	end)
end

-- Cizim, Submit anindan itibaren sunucudadir: ekrani kapatmak ya da oyundan cikmak cizimi kaybettirmez.
function DrawingScreen:submit()
	if self.submitted or self.roundId == nil then
		return
	end
	self.submitted = true
	self:_handle(self.pointer:cancel(), 0, 0)
	self.session:setEnabled(false)
	Net.fireServer("Round", "Submit", { drawing = StrokeCodec.encode(self.session:getStrokes()) })
	self:_hide()
	if self.onSubmitted then
		self.onSubmitted()
	end
end

function DrawingScreen:_hide()
	self.refs.cizim_ekran.Enabled = false
	self.visibility:Restore()
	if self.healthWas ~= nil then
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, self.healthWas)
		self.healthWas = nil
	end
end

function DrawingScreen:collect()
	if self.roundId ~= nil and not self.submitted then
		self:submit()
	end
end

function DrawingScreen:close()
	self.token += 1
	self.roundId = nil
	self.session:setEnabled(false)
	self:_handle(self.pointer:cancel(), 0, 0)
	self:_hide()
end

return DrawingScreen
