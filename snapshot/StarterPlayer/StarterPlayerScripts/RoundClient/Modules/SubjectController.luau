--[[
SubjectController
-----------------
Drives the lobby subject-guarantee panel (SidebarGui.Container.SubjectFrame):
  - SubjectButton opens the Robux purchase prompt for the subject-guarantee Developer
    Product (Constants.SUBJECT_GUARANTEE_PRODUCT_ID).
  - ChanceLabel / ChanceBar mirror the player's odds of being next round's subject.
    The server is the source of truth: it sends the chance over SubjectChanceRemote
    (RoundClient forwards it to Render); this controller only paints what arrives.

The chance bar is a scale-driven progress bar: only its X scale tracks the value, while
the authored Y/offset sizing and (green) color are left as set in Studio.

All parts are optional — a missing button/label/bar just makes that piece inert and
warns once, so a half-authored panel never blocks the rest.
]]

local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Players            = game:GetService("Players")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))

local SubjectController = {}

local chanceLabel = nil
local chanceBar   = nil

--------------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------------

function SubjectController:Init(refs)
	chanceLabel = refs.SubjectChanceLabel
	chanceBar   = refs.SubjectChanceBar

	local button = refs.SubjectButton
	if button and button:IsA("GuiButton") then
		button.MouseButton1Click:Connect(function()
			-- ID 0 means the product is not configured yet; skip rather than open an
			-- invalid prompt (matches the server ignoring the receipt).
			if Constants.SUBJECT_GUARANTEE_PRODUCT_ID == 0 then return end
			MarketplaceService:PromptProductPurchase(
				Players.LocalPlayer,
				Constants.SUBJECT_GUARANTEE_PRODUCT_ID
			)
		end)
	else
		warn("[SubjectController] SubjectButton missing; purchase prompt disabled")
	end
end

--------------------------------------------------------------------------------
-- Render
--------------------------------------------------------------------------------

-- chance: number in [0,1]. Paints the label as a whole-percent string and the bar's
-- X scale to match. Clamped defensively so a bad value never overflows the bar.
function SubjectController:Render(chance)
	if typeof(chance) ~= "number" then chance = 0 end
	chance = math.clamp(chance, 0, 1)

	if chanceLabel then
		chanceLabel.Text = math.floor(chance * 100 + 0.5) .. "%"
	end
	if chanceBar then
		local size = chanceBar.Size
		chanceBar.Size = UDim2.new(chance, size.X.Offset, size.Y.Scale, size.Y.Offset)
	end
end

return SubjectController
