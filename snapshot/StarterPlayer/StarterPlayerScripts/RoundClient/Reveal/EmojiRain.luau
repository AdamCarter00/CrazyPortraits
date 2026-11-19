local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants         = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))

local EmojiRain = {}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function playAnimation(emojiLayer, emojiButtonArea, emojiName)
	if not emojiLayer then return end
	local button = emojiButtonArea:FindFirstChild(emojiName)
	if not button then return end

	local clone = button:Clone()
	clone.Active = false

	local stroke = clone:FindFirstChildOfClass("UIStroke")
	if stroke then stroke:Destroy() end
	local corner = clone:FindFirstChildOfClass("UICorner")
	if corner then corner:Destroy() end
	local accentLabel = clone:FindFirstChild("AccentLabel")
	if accentLabel then accentLabel:Destroy() end

	local startX = math.random()
	local startY = 0.5 + math.random() * 0.5

	clone.AnchorPoint            = Vector2.new(0.5, 0.5)
	clone.Size                   = UDim2.fromScale(0.06, 0.06)
	clone.Position               = UDim2.fromScale(startX, startY)
	clone.ZIndex                 = button.ZIndex + 10
	clone.ImageTransparency      = 0
	clone.BackgroundTransparency = 1
	clone.Parent                 = emojiLayer

	local riseDuration = Constants.EMOJI_RISE_DURATION
	local fadeRatio    = 0.35

	TweenService:Create(
		clone,
		TweenInfo.new(riseDuration * (1 - fadeRatio), Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{
			Size     = UDim2.fromScale(0.14, 0.14),
			Position = UDim2.fromScale(startX, startY - Constants.EMOJI_RISE_AMOUNT),
		}
	):Play()

	task.delay(riseDuration * (1 - fadeRatio), function()
		TweenService:Create(
			clone,
			TweenInfo.new(riseDuration * fadeRatio, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ ImageTransparency = 1 }
		):Play()
	end)

	game:GetService("Debris"):AddItem(clone, riseDuration)
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

function EmojiRain.init(emojiRemote, emojiLayer, emojiButtonArea)
	emojiRemote.OnClientEvent:Connect(function(emojiName)
		if emojiName then
			playAnimation(emojiLayer, emojiButtonArea, emojiName)
		end
	end)
end

return EmojiRain
