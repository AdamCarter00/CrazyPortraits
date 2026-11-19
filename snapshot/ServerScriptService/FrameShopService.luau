--[[
FrameShopService
----------------
Server side of the cosmetic frame shop. Frames are bought with Stars (in-game
currency). Server-authoritative: the price comes from Constants.FRAME_PRICES, never the
client; the buy is denied silently when the balance is short. Buying grants the frame and
auto-equips it.

The client talks to this service over FrameRemote (request/buy/equip). Frame state
(ownedFrames + equippedFrame) is pushed back over FrameStateRemote by PlayerDataService;
this service just asks PlayerDataService to push after each change.

Equip is a single-button toggle on the client: buying auto-equips, tapping an owned frame
equips it, tapping the equipped frame unequips (frameId == "" -> default).
]]

local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Constants         = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local Analytics         = require(script.Parent:WaitForChild("AnalyticsService"))

local Remotes     = ReplicatedStorage:WaitForChild("Remotes")
local FrameRemote = Remotes:WaitForChild("FrameRemote")

local FrameShopService = {}

-- Reverse of Constants.FRAME_GAMEPASS_IDS: Game Pass id -> frame id, so a purchase/ownership
-- callback (which only knows the Game Pass id) can resolve the frame to grant.
local frameIdForGamePass = {}
for frameId, gamePassId in pairs(Constants.FRAME_GAMEPASS_IDS) do
	frameIdForGamePass[gamePassId] = frameId
end

-- [player] = true once we have logged their market open this session, so Market:Opened
-- fires at most once per player per session (the client may FireServer("opened") on every
-- open). Transient; a rejoining player gets a fresh session and is logged again.
local marketOpenedThisSession = setmetatable({}, { __mode = "k" })

--------------------------------------------------------------------------------
-- Request handling (Star purchase + equip toggle + state request)
--------------------------------------------------------------------------------

local function onBuy(player, frameId)
	-- Already owned: nothing to charge; just re-sync the client so its button is correct.
	if PlayerDataService:IsFrameOwned(player, frameId) then
		PlayerDataService:PushFrameState(player)
		return
	end

	local price = Constants.FRAME_PRICES[frameId]
	if typeof(price) ~= "number" then
		warn("[FrameShopService] buy: no Star price for frame -", tostring(frameId))
		PlayerDataService:PushFrameState(player)
		return
	end

	-- Insufficient balance is a silent denial: SpendStars changes nothing and the push
	-- below leaves the button reading "Buy".
	if not PlayerDataService:SpendStars(player, price) then
		PlayerDataService:PushFrameState(player)
		return
	end

	PlayerDataService:GrantFrame(player, frameId)
	PlayerDataService:SetEquippedFrame(player, frameId) -- auto-equip on purchase
	PlayerDataService:PushFrameState(player)

	Analytics:LogFrameBought(player, frameId)
	PlayerDataService:MarkFrameBoughtThisSession(player)
end

--------------------------------------------------------------------------------
-- Robux Game Pass purchase + ownership sync
--
-- The four premium frames also sell for Robux via a Game Pass. Game Passes are NOT
-- consumable, so they never reach ProcessReceipt (that stays owned solely by the
-- subject-guarantee Dev Product, SubjectGuaranteeService). Ownership is Roblox-owned:
-- we grant on the PromptGamePassPurchaseFinished callback and re-sync at join via
-- UserOwnsGamePassAsync so a pass bought on another server (or before this feature) is
-- honored.
--------------------------------------------------------------------------------

-- Grants (and optionally equips) the frame that a Game Pass unlocks. Idempotent: a
-- re-grant of an owned frame is a no-op grant + push, so calling it on every join is safe.
-- equipOnPurchase auto-equips (a fresh Robux buy); join-time sync passes false so a player's
-- saved equipped frame is left untouched.
local function grantGamePassFrame(player, frameId, equipOnPurchase)
	local alreadyOwned = PlayerDataService:IsFrameOwned(player, frameId)

	PlayerDataService:GrantFrame(player, frameId)
	if equipOnPurchase then
		PlayerDataService:SetEquippedFrame(player, frameId) -- auto-equip on purchase
	end
	PlayerDataService:PushFrameState(player)

	-- Only log/mark a genuinely new grant, so a join-time re-sync of an already-owned pass
	-- does not inflate the frame-bought analytics.
	if not alreadyOwned then
		Analytics:LogFrameBought(player, frameId)
		PlayerDataService:MarkFrameBoughtThisSession(player)
	end
end

-- Fired after the client's PromptGamePassPurchase resolves. Grants the frame only on a
-- completed purchase; a dismissed/failed prompt (wasPurchased false) or an unmapped pass id
-- is ignored.
local function onGamePassPurchaseFinished(player, gamePassId, wasPurchased)
	if not wasPurchased then return end
	local frameId = frameIdForGamePass[gamePassId]
	if not frameId then return end
	grantGamePassFrame(player, frameId, true)
end

-- Join-time sync: for every Game Pass frame the player already owns on Roblox, make sure the
-- profile reflects it. Each ownership check is a web call, so it is pcall-guarded and a
-- failure just leaves that frame ungranted this session (a later join or purchase covers it).
local function syncGamePasses(player)
	for gamePassId, frameId in pairs(frameIdForGamePass) do
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamePassId)
		end)
		if ok and owns then
			grantGamePassFrame(player, frameId, false)
		end
	end
end

-- Market open is logged once per session (not per open); the client fires "opened" every
-- time the shop is opened and this flag de-dupes.
local function onMarketOpened(player)
	if marketOpenedThisSession[player] then return end
	marketOpenedThisSession[player] = true
	Analytics:LogMarketOpened(player)
end

local function onEquip(player, frameId)
	-- SetEquippedFrame validates ownership ("" always allowed = unequip to default); an
	-- unowned id silently fails and the push restores the client's correct state.
	PlayerDataService:SetEquippedFrame(player, frameId)
	PlayerDataService:PushFrameState(player)
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

function FrameShopService:Init()
	FrameRemote.OnServerEvent:Connect(function(player, action, frameId)
		if action == "buy" then
			onBuy(player, typeof(frameId) == "string" and frameId or "")
		elseif action == "equip" then
			-- frameId may be "" (unequip); default to "" if the client omitted it.
			onEquip(player, typeof(frameId) == "string" and frameId or "")
		elseif action == "opened" then
			onMarketOpened(player)
		else
			-- nil / "request": the client's join-time state request (race-fix), same as
			-- StarRemote. Reply with the current state.
			PlayerDataService:PushFrameState(player)
		end
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(onGamePassPurchaseFinished)
end

-- Called by GameServer after PlayerDataService loads the profile (so grants have somewhere
-- to land). Re-syncs any Game Pass frames the player already owns on Roblox.
function FrameShopService:OnPlayerAdded(player)
	syncGamePasses(player)
end

return FrameShopService
