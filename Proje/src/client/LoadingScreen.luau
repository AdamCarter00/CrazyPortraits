local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Loading = require(Shared.Config.Loading)
local Terms = require(Shared.Config.Terms)
local Screen = require(Shared.Loading.Screen)

local LoadingScreen = {}
LoadingScreen.__index = LoadingScreen

function LoadingScreen.new(refs)
	local self = setmetatable({
		refs = refs,
		status = "loading",
		startedAt = os.clock(),
		fillSize = refs.yukleme_cubuk_dolgu.Size.X.Scale,
		textColor = refs.yukleme_cubuk_yazi.TextColor3,
	}, LoadingScreen)
	refs.yukleme_ekran.Enabled = true
	self:step()
	self.connection = RunService.Heartbeat:Connect(function()
		self:step()
	end)
	return self
end

function LoadingScreen:finish(ok: boolean)
	if self.status == "loading" then
		self.status = if ok then "ready" else "failed"
	end
end

function LoadingScreen:step()
	local refs = self.refs
	local elapsed = os.clock() - self.startedAt
	refs.yukleme_ipucu.Text = Terms.LoadingTips[Screen.tipIndex(elapsed, #Terms.LoadingTips, Loading.TipSeconds)]
	refs.yukleme_cubuk_yazi.Text = Screen.barText(self.status, Terms)
	local color = Screen.barColor(self.status, Loading.FailedTextColor)
	refs.yukleme_cubuk_yazi.TextColor3 = if color then Color3.fromHex(color) else self.textColor
	if Screen.fillMoves(self.status) then
		local fill = refs.yukleme_cubuk_dolgu
		local x = Screen.fillPosition(elapsed, Loading.BarCycleSeconds, self.fillSize)
		fill.Position = UDim2.new(x, fill.Position.X.Offset, fill.Position.Y.Scale, fill.Position.Y.Offset)
	end
	if Screen.shouldClose(self.status, game:IsLoaded(), elapsed, Loading.MinSeconds) then
		self.connection:Disconnect()
		refs.yukleme_ekran.Enabled = false
	end
end

return LoadingScreen
