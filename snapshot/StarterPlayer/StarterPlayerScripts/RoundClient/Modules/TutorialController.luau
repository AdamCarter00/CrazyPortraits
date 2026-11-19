--[[
TutorialController
------------------
Shows the one-step tutorial (TutorialGui > Step-1) once, after the local player finishes
their first round of the session. The server is the source of truth: it decides eligibility
(first round this session + never shown before), marks the player seen, and fires
TutorialRemote. This controller only owns the on-screen presentation and the exact open
moment, which the server cannot know.

Open timing (OnSignal):
  - If the "You Got" result screen is on screen, wait for its fade-out to finish
    (ResultController:OnSequenceComplete) and open right after, so the tutorial does not
    overlap it.
  - Otherwise (the player's drawing was not revealed, so there is no result screen) open
    after a short grace delay (TUTORIAL_OPEN_DELAY); the server already gated the signal
    until after the gallery teleport + Lobby fade.

While Step-1 is up, every sidebar frame except MarketFrame is hidden so the market is the
only thing on the sidebar; their prior Visible is restored on close. The player dismisses
it by clicking CloseTutoButton (MouseButton1Click covers both mouse and touch on a
GuiButton). A new DRAWING_PHASE also tears it down (see RoundClient) as a safety net.

UI layout (set up manually in Studio):
  PlayerGui.TutorialGui            -> Enabled toggled by this controller
    Step-1                         -> the tutorial frame, shown on open
      CloseTutoButton  (GuiButton) -> tap/click to dismiss; several may share this name
                                      (one per region) and any of them dismisses.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants       = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local ResultController = require(script.Parent:WaitForChild("ResultController"))

local CHAIN_WAIT = Constants.GUI_TIMEOUT

local TutorialController = {}

local gui          = nil
local step1        = nil
-- Every button under Step-1 named "CloseTutoButton" (there are several, one per screen
-- region); any of them dismisses the tutorial, so all are bound on Show.
local closeButtons = {}
-- Sidebar frames hidden while the tutorial is up (MarketFrame is intentionally excluded).
local hideFrames  = {}
-- [frame] = its Visible value captured on Show, written back on Hide. Captures the real
-- prior state (not a hard-coded true) so a frame something else legitimately hid stays hid.
local savedVisibility = {}
-- Live MouseButton1Click connections for the close buttons, disconnected on Hide.
local closeConns = {}
local isOpen    = false

--------------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------------

function TutorialController:Init(tutorialGui, refs)
	if not tutorialGui then
		-- Optional feature: stay inert (OnSignal becomes a no-op) without a GUI.
		return
	end
	gui = tutorialGui
	gui.Enabled = false

	step1 = gui:WaitForChild("Step-1", CHAIN_WAIT)
	if not step1 then
		warn("[TutorialController] Init: TutorialGui.Step-1 missing; tutorial will not show")
		gui = nil
		return
	end

	-- Wait for at least one CloseTutoButton, then collect every sibling sharing that name:
	-- Step-1 has several identically named close buttons (one per region) and any must
	-- dismiss the tutorial, so all are gathered here and bound in Show.
	if not step1:WaitForChild("CloseTutoButton", CHAIN_WAIT) then
		warn("[TutorialController] Init: Step-1.CloseTutoButton missing; tutorial will not show")
		gui = nil
		return
	end

	closeButtons = {}
	for _, child in ipairs(step1:GetChildren()) do
		if child.Name == "CloseTutoButton" and child:IsA("GuiButton") then
			table.insert(closeButtons, child)
		end
	end

	-- The sidebar frames to hide while the tutorial is up. Any may be nil (missing sidebar);
	-- Show/Hide skip nils, so a partial sidebar never errors.
	hideFrames = {
		refs and refs.SidebarStarFrame,
		refs and refs.SidebarSubjectFrame,
		refs and refs.SidebarInviteFrame,
	}
end

--------------------------------------------------------------------------------
-- Show / Hide
--------------------------------------------------------------------------------

function TutorialController:Show()
	if not gui or isOpen then return end
	isOpen = true

	-- Hide every sidebar frame except MarketFrame, saving the prior Visible to restore later.
	for _, frame in ipairs(hideFrames) do
		if frame then
			savedVisibility[frame] = frame.Visible
			frame.Visible = false
		end
	end

	if step1 then step1.Visible = true end
	gui.Enabled = true

	-- Bind every close button: a click on any of them dismisses the tutorial.
	for _, button in ipairs(closeButtons) do
		table.insert(closeConns, button.MouseButton1Click:Connect(function()
			TutorialController:Hide()
		end))
	end
end

-- Idempotent: safe to call when already closed (the DRAWING_PHASE safety net may call it
-- without a Show having run).
function TutorialController:Hide()
	if not isOpen then return end
	isOpen = false

	for _, conn in ipairs(closeConns) do
		conn:Disconnect()
	end
	closeConns = {}

	if gui then gui.Enabled = false end

	for frame, visible in pairs(savedVisibility) do
		frame.Visible = visible
	end
	savedVisibility = {}
end

--------------------------------------------------------------------------------
-- Server signal
--------------------------------------------------------------------------------

-- Fired by the server (TutorialRemote) after the player's first finished round. Opens once
-- the "You Got" screen is gone: chains off the result's fade-out when one is showing, else
-- opens after a short grace delay.
function TutorialController:OnSignal()
	if not gui then return end

	if ResultController:IsActive() then
		ResultController:OnSequenceComplete(function()
			TutorialController:Show()
		end)
	else
		task.delay(Constants.TUTORIAL_OPEN_DELAY, function()
			TutorialController:Show()
		end)
	end
end

return TutorialController
