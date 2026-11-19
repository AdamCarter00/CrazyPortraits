local player    = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--------------------------------------------------------------------------------
-- Services
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local Constants    = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))

do
	local packages = ReplicatedStorage:FindFirstChild("Packages")
	local gaModule = packages and packages:FindFirstChild("GameAnalytics")
	if gaModule then
		local ok, ga = pcall(require, gaModule)
		if ok and typeof(ga) == "table" and typeof(ga.initClient) == "function" then
			pcall(function() ga:initClient() end)
		end
	end
end

local Sceneography  = require(script.Core.Sceneography)
local PhaseRouter   = require(script.Core.PhaseRouter)
local RevealEvents  = require(script.Core.RevealEvents)
local RefsBuilder   = require(script.Core.RefsBuilder)

--------------------------------------------------------------------------------
-- Remotes
--------------------------------------------------------------------------------

local Remotes             = ReplicatedStorage:WaitForChild("Remotes")
local PhaseRemote         = Remotes:WaitForChild("PhaseRemote")
local CanvasRemote        = Remotes:WaitForChild("CanvasRemote")
local EmojiRemote         = Remotes:WaitForChild("EmojiRemote")
local ReadyRemote         = Remotes:WaitForChild("ReadyRemote")
local ClearDisplayRemote  = Remotes:WaitForChild("ClearDisplayRemote")
local HideDrawingRemote   = Remotes:WaitForChild("HideDrawingRemote")
local StarRemote          = Remotes:WaitForChild("StarRemote")
local ResultRemote        = Remotes:WaitForChild("ResultRemote")
local SubjectChanceRemote = Remotes:WaitForChild("SubjectChanceRemote")
local FrameRemote         = Remotes:WaitForChild("FrameRemote")
local FrameStateRemote    = Remotes:WaitForChild("FrameStateRemote")
local TutorialRemote      = Remotes:WaitForChild("TutorialRemote")

--------------------------------------------------------------------------------
-- Loading Screen + Refs Setup
--------------------------------------------------------------------------------

local refs = RefsBuilder.build(playerGui)
if not refs then return end

--------------------------------------------------------------------------------
-- Modules
--------------------------------------------------------------------------------

local Modules               = script:WaitForChild("Modules")
local UIController          = require(Modules:WaitForChild("UIController"))
local CanvasController      = require(Modules:WaitForChild("CanvasController"))
local InputController       = require(Modules:WaitForChild("InputController"))
local GalleryController     = require(Modules:WaitForChild("GalleryController"))
local MarketController       = require(Modules:WaitForChild("MarketController"))
local ResultController       = require(Modules:WaitForChild("ResultController"))
local FrameController        = require(Modules:WaitForChild("FrameController"))
local PassController          = require(Modules:WaitForChild("PassController"))
local SubjectController       = require(Modules:WaitForChild("SubjectController"))
local TutorialController      = require(Modules:WaitForChild("TutorialController"))
CanvasController:Init(refs.CanvasLabel)
UIController:SetCanvas(refs.CanvasLabel)
InputController:SetCanvas(refs.CanvasLabel)
InputController:Init(CanvasController, refs.CanvasLabel)
GalleryController:Init()
MarketController:Init(refs.MarketFramesScreen)
ResultController:Init(refs.ResultGui)
SubjectController:Init(refs)
TutorialController:Init(refs.TutorialGui, refs)

--------------------------------------------------------------------------------
-- Sceneography
--------------------------------------------------------------------------------

local scene = Sceneography.new(refs)
local frameController = FrameController.new(refs)
local passController = PassController.new(refs)

--------------------------------------------------------------------------------
-- Phase Controllers
--------------------------------------------------------------------------------

local DrawingCtrl = require(script.Phases.DrawingController).new(scene, refs, CanvasController, passController)

UIController:Init(CanvasController, refs.ClickSound, InputController, refs.displayLabel,
	function()
		if not DrawingCtrl:IsRoundActive() then return end
		DrawingCtrl:SubmitDraw()
	end
)

local router = PhaseRouter.new()
router:RegisterMany({
	WAITING_PHASE       = require(script.Phases.WaitingController).new(scene, refs),
	DRAWING_PHASE       = DrawingCtrl,
	COLLECTING_PHASE    = require(script.Phases.CollectingController).new(scene, refs, CanvasController, CanvasRemote),
	REVEAL_INTRO_PHASE  = require(script.Phases.RevealIntroController).new(scene, refs, RevealEvents),
	REVEAL_PHASE        = require(script.Phases.RevealController).new(scene, refs, RevealEvents, UIController, frameController),
	CLEAN_ROUND_PHASE   = require(script.Phases.CleanRoundController).new(scene, refs, CanvasController, DrawingCtrl, passController),
})

--------------------------------------------------------------------------------
-- Emoji Buttons
--------------------------------------------------------------------------------
--
-- Every button's authored UIStroke softly breathes (thickness only) so the bar reads
-- as interactive. The breathe runs from boot and restarts each new round. Selecting
-- any emoji stops the breathe on all buttons (the player has engaged); it resumes when
-- the round resets.

local lastEmojiSent = 0

local emojiButtons = {}
for _, btn in ipairs(refs.EmojiButtonArea:GetChildren()) do
	if btn:IsA("ImageButton") then
		table.insert(emojiButtons, btn)
	end
end

local BREATHE_TWEEN = TweenInfo.new(
	Constants.EMOJI_BREATHE_DURATION,
	Enum.EasingStyle.Sine,
	Enum.EasingDirection.InOut,
	-1,   -- repeat forever
	true  -- reverse each cycle so it eases back instead of snapping
)

-- Per-button breathe state: its UIStroke and the live looping tween (nil while stopped).
local emojiBreathe = {}
for _, btn in ipairs(emojiButtons) do
	local stroke = btn:FindFirstChildOfClass("UIStroke")
	if stroke then
		emojiBreathe[btn] = { stroke = stroke, tween = nil }
	end
end

local function startEmojiBreathing()
	for _, state in pairs(emojiBreathe) do
		if not state.tween then
			state.stroke.Thickness = Constants.EMOJI_BREATHE_MIN
			state.tween = TweenService:Create(state.stroke, BREATHE_TWEEN, { Thickness = Constants.EMOJI_BREATHE_MAX })
			state.tween:Play()
		end
	end
end

-- Stops the breathe on every button: the selected one rests at EMOJI_SELECTED_THICKNESS
-- so the player's pick stays the most prominent, the rest drop to the thin BREATHE_MIN.
local function stopEmojiBreathing(selected)
	for btn, state in pairs(emojiBreathe) do
		if state.tween then
			state.tween:Cancel()
			state.tween = nil
		end
		state.stroke.Thickness = btn == selected and Constants.EMOJI_SELECTED_THICKNESS or Constants.EMOJI_BREATHE_MIN
	end
end

for _, btn in ipairs(emojiButtons) do
	btn.MouseButton1Click:Connect(function()
		local now = tick()
		if (now - lastEmojiSent) >= Constants.EMOJI_COOLDOWN then
			lastEmojiSent = now
			refs.ClickSound:Play()
			EmojiRemote:FireServer(btn.Name)
			stopEmojiBreathing(btn)
		end
	end)
end

startEmojiBreathing()

-- Each revealed drawing is its own vote: when the next one is shown, drop the previous
-- pick (clear the selected stroke, resume the breathe) and reset the cooldown so the
-- player can react to the new drawing immediately.
RevealEvents.DrawingShown:Connect(function()
	lastEmojiSent = 0
	startEmojiBreathing()
end)

-- Show the transition screen and THEN dispatch the phase, in this exact order and
-- in one handler: the controller's Enter checks whether a screen is up (via
-- ScheduleSceneSetup) to decide whether to delay its scene setup, so Show must have
-- run first. Two separate OnClientEvent connections do not guarantee that order.
PhaseRemote.OnClientEvent:Connect(function(phase, ...)
	passController:Show(phase)
	router:Dispatch(phase, ...)
end)

PhaseRemote.OnClientEvent:Connect(function(phase)
	-- A new round invalidates last round's reaction, so restart the emoji breathe; if
	-- it never stopped (player did not react) startEmojiBreathing is a no-op.
	if phase == "DRAWING_PHASE" then
		startEmojiBreathing()
		-- The result screen is shown in CLEAN_ROUND and stays up through the lobby; hide
		-- it once a new round's drawing phase begins.
		ResultController:Render(nil)
		-- Safety net: a new round always tears down the tutorial (restoring the sidebar
		-- frames) if it was still up.
		TutorialController:Hide()
	end
end)

-- Tell the server this client finished loading. This is the player's admission signal:
-- the server replies on PhaseRemote with the live phase (start a round, mid-join the
-- drawing, spectate, or wait). We fire it only AFTER the PhaseRemote listeners above are
-- connected, because that reply is sent exactly once (admission is not idempotent -- see
-- ReadyRemote.OnServerEvent) and RemoteEvents drop events that arrive with no listener.
ReadyRemote:FireServer()

--------------------------------------------------------------------------------
-- Display Reset
--------------------------------------------------------------------------------

ClearDisplayRemote.OnClientEvent:Connect(function()
	UIController:HideReportOverlay()
	scene:ClearDisplay()
end)

HideDrawingRemote.OnClientEvent:Connect(function()
	UIController:ShowReportOverlay()
	scene:ClearDisplay()
end)

--------------------------------------------------------------------------------
-- Star Count
--------------------------------------------------------------------------------

-- Server is the source of truth: it sends the current Star balance on join and on
-- every change. The label only ever mirrors what arrives here. We request the
-- current value once the listener is connected, because the join-time push may
-- have fired during the loading screen (before this listener existed).
if refs.StarCountLabel then
	StarRemote.OnClientEvent:Connect(function(stars)
		refs.StarCountLabel.Text = tostring(stars)
	end)
	StarRemote:FireServer()
end

--------------------------------------------------------------------------------
-- Result Screen
--------------------------------------------------------------------------------

-- Server sends this player's per-drawing result (reaction tally + Star breakdown) at
-- round end, but only if their drawing was revealed. The server delays this send until
-- the "Lobby" transition screen has faded out, so the controller can open ResultGui on
-- receipt and have it play in full view; the DRAWING_PHASE handler hides it when the
-- next round starts.
if refs.ResultGui then
	ResultRemote.OnClientEvent:Connect(function(result)
		ResultController:Render(result)
	end)
end

--------------------------------------------------------------------------------
-- Tutorial
--------------------------------------------------------------------------------

-- Server fires this once, after the player's first finished round (it owns the eligibility
-- gating and marks the player seen). No FireServer race-fix is needed: this is a fresh
-- per-round push, not join-time state, and this listener is connected long before the
-- player's first round can end. TutorialController picks the exact open moment.
if refs.TutorialGui then
	TutorialRemote.OnClientEvent:Connect(function()
		TutorialController:OnSignal()
	end)
end

--------------------------------------------------------------------------------
-- Subject Chance
--------------------------------------------------------------------------------

-- Same server-authoritative race-fix as StarCount: render whatever the server
-- sends (the player's odds of being next subject) and request the current value once,
-- since the join-time push may have landed during the loading screen.
if refs.SubjectChanceBar or refs.SubjectChanceLabel then
	SubjectChanceRemote.OnClientEvent:Connect(function(chance)
		SubjectController:Render(chance)
	end)
	SubjectChanceRemote:FireServer()
end

--------------------------------------------------------------------------------
-- Frame Shop
--------------------------------------------------------------------------------

-- Same server-authoritative race-fix as StarCount: render the frame ownership/
-- equip state the server sends, and request the current state once the listener is
-- connected (the join-time push may have landed during the loading screen).
if refs.MarketFramesScreen then
	FrameStateRemote.OnClientEvent:Connect(function(state)
		MarketController:Render(state)
	end)
	FrameRemote:FireServer("request")
end

--------------------------------------------------------------------------------
-- Reveal Features
--------------------------------------------------------------------------------

require(script.Reveal.EmojiRain).init(EmojiRemote, refs.emojiLayer, refs.EmojiButtonArea)
