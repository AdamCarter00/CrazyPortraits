local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Players            = game:GetService("Players")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))

local Remotes     = ReplicatedStorage:WaitForChild("Remotes")
local FrameRemote = Remotes:WaitForChild("FrameRemote")

local STAR_PREFIX = "\u{2B50} "

local LABEL_EQUIP  = "Equip"
local LABEL_ACTIVE = "Active"

local COLOR_BUY    = Color3.fromRGB(255, 255, 255)
local COLOR_OWNED  = Color3.fromRGB(34, 197, 94)

local MarketController = {}

local cards = {}
local frameState = { owned = {}, equipped = "" }

-- Each card is an authored frame directly under FrameArea. The node name carries a number
-- prefix (1Cute, 2Gold, ...) only so the UIGridLayout keeps a fixed order; the frame id
-- (the string every other module keys on) is the prefix-less name. StarButton is the Star
-- purchase; RobuxButton (premium frames only) opens the Game Pass prompt. Wood and CardBoard
-- are Star-only, so they have no gamePass id and their RobuxButton, if authored, stays hidden.
local function cardDefs()
	return {
		{ node = "1Cute",      id = Constants.CUTE_FRAME_NAME      },
		{ node = "2Gold",      id = Constants.GOLD_FRAME_NAME      },
		{ node = "3Goofy",     id = Constants.GOOFY_FRAME_NAME     },
		{ node = "4Dark",      id = Constants.DARK_FRAME_NAME      },
		{ node = "5Wood",      id = Constants.WOOD_FRAME_NAME      },
		{ node = "6CardBoard", id = Constants.CARDBOARD_FRAME_NAME },
	}
end

local function priceText(price)
	return STAR_PREFIX .. tostring(price)
end

-- Star purchase / equip toggle: unowned buys (server charges Stars), owned equips, the
-- equipped one unequips. Same request path as before.
local function onStarClicked(card)
	local owned    = frameState.owned[card.id] == true
	local equipped = frameState.equipped == card.id

	if not owned then
		FrameRemote:FireServer("buy", card.id)
		return
	end

	if equipped then
		FrameRemote:FireServer("equip", "")
	else
		FrameRemote:FireServer("equip", card.id)
	end
end

-- Robux purchase: opens the Game Pass prompt. Ownership/grant happens server-side
-- (FrameShopService listens to PromptGamePassPurchaseFinished) and comes back over
-- FrameStateRemote, so there is nothing to send here. Owned frames ignore the click (the
-- button reads Equip/Active and equipping is StarButton's job).
local function onRobuxClicked(card)
	if not card.gamePass then return end
	if frameState.owned[card.id] == true then return end
	MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, card.gamePass)
end

local function paintStarButton(card)
	local button = card.starButton
	if not button or not button:IsA("TextButton") then return end

	local owned    = frameState.owned[card.id] == true
	local equipped = frameState.equipped == card.id

	if not owned then
		button.Text = card.price and priceText(card.price) or ""
		button.BackgroundColor3 = COLOR_BUY
	elseif equipped then
		button.Text = LABEL_ACTIVE
		button.BackgroundColor3 = COLOR_OWNED
	else
		button.Text = LABEL_EQUIP
		button.BackgroundColor3 = COLOR_OWNED
	end
end

-- The RobuxButton only offers the Robux buy while the frame is unowned. Once owned (bought
-- either way) equipping runs through StarButton, so the RobuxButton is hidden to avoid a
-- dead second control.
local function paintRobuxButton(card)
	local button = card.robuxButton
	if not button then return end

	button.Visible = card.gamePass ~= nil and frameState.owned[card.id] ~= true
end

local function paintCard(card)
	paintStarButton(card)
	paintRobuxButton(card)
end

function MarketController:Init(frameArea)
	cards = {}
	if not frameArea then
		warn("[MarketController] FrameArea missing; frame market disabled")
		return
	end

	for _, def in ipairs(cardDefs()) do
		local node = frameArea:FindFirstChild(def.node)
		if not node then
			warn("[MarketController] card '" .. def.node .. "' missing; skipping")
			continue
		end

		local buttonFrame = node:FindFirstChild("ButtonFrame")
		local starButton  = buttonFrame and buttonFrame:FindFirstChild("StarButton")
		if not starButton then
			warn("[MarketController] '" .. def.node .. ".ButtonFrame.StarButton' missing; card inert")
			continue
		end

		local card = {
			id          = def.id,
			price       = Constants.FRAME_PRICES[def.id],
			gamePass    = Constants.FRAME_GAMEPASS_IDS[def.id],
			starButton  = starButton,
			robuxButton = buttonFrame:FindFirstChild("RobuxButton"),
		}
		table.insert(cards, card)

		starButton.MouseButton1Click:Connect(function()
			onStarClicked(card)
		end)

		if card.robuxButton and card.robuxButton:IsA("TextButton") then
			card.robuxButton.MouseButton1Click:Connect(function()
				onRobuxClicked(card)
			end)
		end
	end

	self:Render(frameState)
end

function MarketController:Render(state)
	if typeof(state) ~= "table" then return end
	frameState = {
		owned    = typeof(state.owned) == "table" and state.owned or {},
		equipped = typeof(state.equipped) == "string" and state.equipped or "",
	}

	for _, card in ipairs(cards) do
		paintCard(card)
	end
end

return MarketController
