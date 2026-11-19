--[[
PlayerDataService
-----------------
Owns each player's persistent profile (ProfileStore-backed) and the only
sanctioned API for reading/writing that data. Game code talks to this service,
never to ProfileStore directly.

Holds:
  - Star balance — pushed to the owning client over StarRemote so the SideBar
    StarCount label stays in sync.

The server is the source of truth; the client only mirrors what is pushed and
never derives the value itself.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants    = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local ProfileStore = require(script.Parent:WaitForChild("ProfileStore"))

local Remotes          = ReplicatedStorage:WaitForChild("Remotes")
local StarRemote       = Remotes:WaitForChild("StarRemote")
local FrameStateRemote = Remotes:WaitForChild("FrameStateRemote")

--------------------------------------------------------------------------------
-- Schema
--------------------------------------------------------------------------------

local TEMPLATE = {
	stars = 0,

	-- Subject-guarantee: true while the player owns an unspent "be the next subject"
	-- purchase. Persisted so the right survives a rejoin (Robux is non-refundable, so a
	-- buyer who leaves before their turn keeps the guarantee). Consumed (set false) when
	-- they are made the subject. See SubjectGuaranteeService / RoundManager.subjectQueue.
	subjectGuarantee = false,

	-- Cosmetic frame ownership/equip (FrameShopService). ownedFrames is a set keyed by
	-- frame id ([frameId] = true) so a grant is idempotent and a lookup is O(1).
	-- equippedFrame is the equipped frame id, or "" for no special frame (= default).
	ownedFrames   = {},
	equippedFrame = "",

	-- Tutorial: true once the player has been SHOWN the one-step tutorial (TutorialGui).
	-- Persisted so it is shown only once ever: the server sets this the moment it decides
	-- to show (not on the client dismiss), so a disconnect/crash mid-tutorial never re-shows
	-- it on the next session. See RoundManager.CleanRound (eligibility) / TutorialController.
	seenTutorial = false,

	-- Daily missions were archived (see _archive/README_missions.md). This field is
	-- intentionally KEPT but inert: no code reads or writes it anymore. It stays so
	-- existing profiles are untouched and restoring the feature needs no data work --
	-- do not re-add it on restore, and do not remove it (that would drop the field
	-- from new profiles).
	dailyMissions = {
		dayNumber = -1,
		progress  = {}, -- [missionId] = number
		done      = {}, -- [missionId] = true
	},
}

local store = ProfileStore.New("PlayerData_v2", TEMPLATE)

-- [player] = profile. A player is present here only while their session is live.
local activeProfiles = {}

-- Transient session analytics (not persisted; cleared on leave). sessionStarsEarned is the
-- gross sum of every AddStars this session (spending never lowers it); sessionFrameBought
-- flags players who bought a frame this session. Both read by Round/init at quit-logging time.
local sessionStarsEarned = {}
local sessionFrameBought = {}

local PlayerDataService = {}

--------------------------------------------------------------------------------
-- Replication
--------------------------------------------------------------------------------

local function pushStars(player, profile)
	if player.Parent then
		StarRemote:FireClient(player, profile.Data.stars)
	end
end

-- Pushes the player's frame ownership/equip state to their client (MarketController
-- mirrors it onto the shop buttons). Same join-time-race shape as pushStars: the client
-- also requests it once its listener is connected (FrameShopService answers that).
local function pushFrameState(player, profile)
	if player.Parent then
		FrameStateRemote:FireClient(player, {
			owned    = profile.Data.ownedFrames,
			equipped = profile.Data.equippedFrame,
		})
	end
end

-- Mirrors the equipped frame onto a replicated Player attribute so any client can read a
-- drawing owner's frame at reveal time (FrameController:FrameNameFor reads this attribute).
-- The push above is for the owning player's own shop UI; this is for everyone else's reveal.
local function applyEquippedAttribute(player, frameId)
	player:SetAttribute(Constants.FRAME_EQUIP_ATTRIBUTE, frameId)
end

-- The client connects its StarRemote listener only after its loading screen
-- finishes, which can land after the join-time push below — so that push may be
-- lost. To close the race, the client also fires StarRemote once it is ready and
-- we reply with the current value. Safe to call any time: if the profile is not
-- loaded yet we stay silent and the join-time push (or a later request) covers it.
StarRemote.OnServerEvent:Connect(function(player)
	local profile = activeProfiles[player]
	if profile then
		pushStars(player, profile)
	end
end)

--------------------------------------------------------------------------------
-- Player Lifecycle
--------------------------------------------------------------------------------

function PlayerDataService:OnPlayerAdded(player)
	local profile = store:StartSessionAsync("player_" .. player.UserId, {
		Cancel = function()
			return player.Parent == nil
		end,
	})

	if not profile then
		-- Session could not be opened (conflict/timeout). Kicking is the safe call:
		-- letting the player in profile-less would risk a later overwrite of good data.
		warn("[PlayerDataService] Could not open profile:", player.Name)
		player:Kick("Data could not be loaded, please rejoin.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	profile.OnSessionEnd:Connect(function()
		activeProfiles[player] = nil
	end)

	if not player.Parent then
		-- Player left during the async load; release the lock so their next join
		-- (possibly on another server) is not blocked.
		profile:EndSession()
		return
	end

	activeProfiles[player] = profile
	pushStars(player, profile)
	-- Sync the equipped-frame attribute from the loaded profile so an already-equipped frame
	-- shows on this player's drawings at reveal without waiting for an equip action.
	applyEquippedAttribute(player, profile.Data.equippedFrame)
end

function PlayerDataService:OnPlayerRemoving(player)
	sessionStarsEarned[player] = nil
	sessionFrameBought[player] = nil
	local profile = activeProfiles[player]
	if profile then
		profile:EndSession()
	end
end

--------------------------------------------------------------------------------
-- Stars
--------------------------------------------------------------------------------

function PlayerDataService:GetStars(player)
	local profile = activeProfiles[player]
	if not profile then return 0 end
	return profile.Data.stars
end

function PlayerDataService:AddStars(player, amount)
	local profile = activeProfiles[player]
	if not profile then return false end
	if typeof(amount) ~= "number" or amount <= 0 then return false end

	local floored = math.floor(amount)
	profile.Data.stars += floored
	-- AddStars is the single choke point for every Star source (reveal reward, ...),
	-- so the gross session total is summed here once.
	sessionStarsEarned[player] = (sessionStarsEarned[player] or 0) + floored
	pushStars(player, profile)
	return true
end

function PlayerDataService:SetStars(player, amount)
	local profile = activeProfiles[player]
	if not profile then return false end
	if typeof(amount) ~= "number" or amount < 0 then return false end

	profile.Data.stars = math.floor(amount)
	pushStars(player, profile)
	return true
end

-- Deducts Stars for a purchase. Server-authoritative: returns false (and changes
-- nothing) when the profile is missing, the amount is non-positive, or the balance is
-- insufficient, so a caller can treat false as "purchase denied". On success it pushes
-- the new balance like the other writers.
function PlayerDataService:SpendStars(player, amount)
	local profile = activeProfiles[player]
	if not profile then return false end
	if typeof(amount) ~= "number" or amount <= 0 then return false end

	amount = math.floor(amount)
	if profile.Data.stars < amount then return false end

	profile.Data.stars -= amount
	pushStars(player, profile)
	return true
end

--------------------------------------------------------------------------------
-- Session analytics state (transient)
--------------------------------------------------------------------------------

function PlayerDataService:GetSessionStarsEarned(player)
	return sessionStarsEarned[player] or 0
end

function PlayerDataService:MarkFrameBoughtThisSession(player)
	sessionFrameBought[player] = true
end

function PlayerDataService:DidBuyFrameThisSession(player)
	return sessionFrameBought[player] == true
end

--------------------------------------------------------------------------------
-- Subject Guarantee
--------------------------------------------------------------------------------

function PlayerDataService:HasGuarantee(player)
	local profile = activeProfiles[player]
	if not profile then return false end
	return profile.Data.subjectGuarantee == true
end

function PlayerDataService:SetGuarantee(player, owned)
	local profile = activeProfiles[player]
	if not profile then return false end
	profile.Data.subjectGuarantee = owned == true
	return true
end

--------------------------------------------------------------------------------
-- Tutorial
--------------------------------------------------------------------------------

function PlayerDataService:GetSeenTutorial(player)
	local profile = activeProfiles[player]
	if not profile then return false end
	return profile.Data.seenTutorial == true
end

function PlayerDataService:SetSeenTutorial(player)
	local profile = activeProfiles[player]
	if not profile then return false end
	profile.Data.seenTutorial = true
	return true
end

--------------------------------------------------------------------------------
-- Frames (cosmetic frame ownership + equip)
--------------------------------------------------------------------------------

function PlayerDataService:IsFrameOwned(player, frameId)
	local profile = activeProfiles[player]
	if not profile then return false end
	return profile.Data.ownedFrames[frameId] == true
end

-- Marks a frame as owned. Idempotent (re-granting an owned frame still returns true). Does
-- NOT push: callers decide whether to follow with SetEquippedFrame + push (so a grant+equip
-- is one push, not two).
function PlayerDataService:GrantFrame(player, frameId)
	local profile = activeProfiles[player]
	if not profile then return false end
	if typeof(frameId) ~= "string" or frameId == "" then return false end

	profile.Data.ownedFrames[frameId] = true
	return true
end

function PlayerDataService:GetEquippedFrame(player)
	local profile = activeProfiles[player]
	if not profile then return "" end
	return profile.Data.equippedFrame
end

-- Sets the equipped frame. "" unequips (back to default) and is always allowed; any other
-- id must be owned (server-authoritative: a player cannot equip a frame they do not own).
-- Returns false without changing anything when the profile is missing or the frame is not
-- owned. Does NOT push; the caller pushes the resulting frame state.
function PlayerDataService:SetEquippedFrame(player, frameId)
	local profile = activeProfiles[player]
	if not profile then return false end
	if typeof(frameId) ~= "string" then return false end
	if frameId ~= "" and profile.Data.ownedFrames[frameId] ~= true then return false end

	profile.Data.equippedFrame = frameId
	applyEquippedAttribute(player, frameId)
	return true
end

-- Pushes the current frame ownership/equip state to the player's client. Public so
-- FrameShopService can answer the client's join-time state request and follow each
-- purchase/equip with a single push.
function PlayerDataService:PushFrameState(player)
	local profile = activeProfiles[player]
	if not profile then return end
	pushFrameState(player, profile)
end

--------------------------------------------------------------------------------
-- Shutdown
--------------------------------------------------------------------------------

game:BindToClose(function()
	for _, profile in pairs(activeProfiles) do
		profile:EndSession()
	end
end)

return PlayerDataService
