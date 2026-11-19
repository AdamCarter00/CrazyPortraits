--[[
SubjectGuaranteeService
-----------------------
Owns the MarketplaceService.ProcessReceipt callback for the subject-guarantee
Developer Product (Constants.SUBJECT_GUARANTEE_PRODUCT_ID). On a granted purchase it
marks the buyer's profile as owning an unspent guarantee (PlayerDataService) and queues
them as the next subject (RoundManager). Both sides are persisted/queued so the right
survives a rejoin; the queue is consumed when the player is actually made the subject.

This MUST be the only ProcessReceipt assignment in the game (Roblox allows one).
Init(roundManager) wires the queue target; GameServer calls it once at startup.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local Constants         = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local SubjectGuaranteeService = {}

local roundManager = nil

local PRODUCT_ID = Constants.SUBJECT_GUARANTEE_PRODUCT_ID

--------------------------------------------------------------------------------
-- Receipt
--------------------------------------------------------------------------------

-- ProcessReceipt must be idempotent: Roblox re-calls it (across sessions/servers)
-- until it returns PurchaseGranted, so any return other than Granted means "try again
-- later". We grant only our product, only when the buyer is present and their profile
-- is loaded; anything else returns NotProcessedYet so a missing player/profile is
-- retried on a later call (typically once they have rejoined) rather than lost.
local function processReceipt(receiptInfo)
	if receiptInfo.ProductId ~= PRODUCT_ID then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if not PlayerDataService:SetGuarantee(player, true) then
		-- Profile not loaded yet; retry on a later call.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if roundManager then
		roundManager:EnqueueSubjectGuarantee(player)
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

function SubjectGuaranteeService:Init(manager)
	roundManager = manager
	if PRODUCT_ID == 0 then
		warn("[SubjectGuaranteeService] SUBJECT_GUARANTEE_PRODUCT_ID is 0; purchases disabled")
	end
	MarketplaceService.ProcessReceipt = processReceipt
end

return SubjectGuaranteeService
