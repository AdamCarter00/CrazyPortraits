local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local Constants         = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))

local ReportRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ReportRemote")
local FrameRemote  = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("FrameRemote")

-- Breathing pulse for the sidebar MarketFrame's NewLabel border. Local to this controller
-- (not in Constants) since these values drive one decorative UIStroke nowhere else.
local PULSE_DURATION      = 1.1
local PULSE_THICKNESS_MIN = 1
local PULSE_THICKNESS_MAX = 3
local PULSE_TRANSPARENCY_MIN = 0
local PULSE_TRANSPARENCY_MAX = 0.5
local PULSE_INFO = TweenInfo.new(
	PULSE_DURATION,
	Enum.EasingStyle.Sine,
	Enum.EasingDirection.InOut,
	-1,   -- repeat forever
	true  -- reverse each cycle so it eases back in instead of snapping
)

local UIController = {}

-- Starts an endless, reversing tween on a UIStroke so its border softly "breathes"
-- (thickness + transparency together). Seeds the min end first so the first cycle grows
-- outward; the single looping tween then never needs restarting.
local function startBreathingStroke(stroke)
	stroke.Thickness    = PULSE_THICKNESS_MIN
	stroke.Transparency = PULSE_TRANSPARENCY_MIN
	TweenService:Create(stroke, PULSE_INFO, {
		Thickness    = PULSE_THICKNESS_MAX,
		Transparency = PULSE_TRANSPARENCY_MAX,
	}):Play()
end

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

function UIController:SetCanvas(canvas)
	self.canvas = canvas
end

--------------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------------

function UIController:Init(canvasController, clickSound, inputController, displayLabel, onSubmit)
	self.canvasController = canvasController
	self.inputController  = inputController

	-- All WaitForChild calls below are timed (GUI_TIMEOUT) so a missing element
	-- under StreamingEnabled never yields this thread forever. RefsBuilder has
	-- already gated CanvasGui/MainFrame as fatal, so reaching here means they
	-- exist; the guards cover the deeper tool/button nodes defensively.
	local T = Constants.GUI_TIMEOUT
	local playerGui    = game.Players.LocalPlayer:WaitForChild("PlayerGui")
	local CanvasGui    = playerGui:WaitForChild("CanvasGui", T)
	local MainFrame    = CanvasGui and CanvasGui:WaitForChild("MainFrame", T)
	local BottomPanel  = MainFrame and MainFrame:WaitForChild("BottomPanel", T)
	local ToolFrame    = BottomPanel and BottomPanel:WaitForChild("ToolsFrame", T)
	local BrushFrame   = BottomPanel and BottomPanel:WaitForChild("BrushsizeFrame", T)
	local ColorFrame   = MainFrame and MainFrame:WaitForChild("RightPanel", T)
	local EraserButton = ToolFrame and ToolFrame:WaitForChild("EraserButton", T)
	local UndoButton   = ToolFrame and ToolFrame:WaitForChild("UndoButton", T)
	local FillButton   = ToolFrame and ToolFrame:WaitForChild("FillButton", T)

	if not (MainFrame and ToolFrame and BrushFrame and ColorFrame
		and EraserButton and UndoButton and FillButton) then
		warn("[UIController] Init: drawing UI tree incomplete; tools disabled")
		return
	end

	--------------------------------------------------------------------------------
	-- Helpers
	--------------------------------------------------------------------------------

	local fillModeActive  = false
	local eraserActive    = false

	local function playClickSound()
		if clickSound then clickSound:Play() end
	end

	local function setToolHighlight(button, active)
		button.BorderSizePixel = active and Constants.SELECTED_BORDER_THICKNESS or 0
		button.BorderColor3    = Constants.SELECTED_BORDER_COLOR
		local scale = button:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", button)
		scale.Scale = active and Constants.SELECTED_BUTTON_SCALE or 1
	end

	local function deactivateFillMode()
		fillModeActive = false
		self.inputController:SetFillMode(false)
		setToolHighlight(FillButton, false)
	end

	local function deactivateEraser()
		eraserActive = false
		setToolHighlight(EraserButton, false)
	end

	local function highlightSelected(frame, selected)
		for _, button in ipairs(frame:GetChildren()) do
			if button:IsA("GuiButton") then
				local active = button == selected
				button.BorderSizePixel = active and Constants.SELECTED_BORDER_THICKNESS or 0
				button.BorderColor3    = Constants.SELECTED_BORDER_COLOR
				local scale = button:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", button)
				scale.Scale = active and Constants.SELECTED_BUTTON_SCALE or 1
			end
		end
	end

	--------------------------------------------------------------------------------
	-- Color Buttons
	--
	-- Each button is matched to a Constants.VALID_COLORS entry BY NAME, then its
	-- BackgroundColor3 is painted FROM that entry and that exact color is what
	-- SetColor receives on click. This guarantees the button color equals the
	-- encoded color (the wire/reveal palette): a button can never drift from the
	-- validator's palette in Studio. Matching is case-insensitive and ignores
	-- Turkish diacritics, so a button named with or without accents (any case)
	-- binds to the same palette entry.
	--------------------------------------------------------------------------------

	-- Fold to a lowercase ASCII key: strips Turkish diacritics and spaces so the
	-- Studio button name need not match the canonical name byte-for-byte. The
	-- diacritics are written as raw UTF-8 byte escapes (lowercase forms, since we
	-- lower-case first) to keep this source file ASCII-only:
	--   \xc5\x9f=s  \xc4\xb1=i  \xc4\x9f=g  \xc3\xbc=u  \xc3\xb6=o  \xc3\xa7=c
	--   \xc3\xa2=a  \xc3\xae=i  \xc3\xbb=u   (and the lone uppercase \xc4\xb0 = I)
	local function colorKey(name)
		name = string.lower(name or "")
		local map = {
			["\xc5\x9f"]="s", ["\xc4\xb1"]="i", ["\xc4\x9f"]="g",
			["\xc3\xbc"]="u", ["\xc3\xb6"]="o", ["\xc3\xa7"]="c",
			["\xc4\xb0"]="i", ["\xc3\xa2"]="a", ["\xc3\xae"]="i", ["\xc3\xbb"]="u",
		}
		for from, to in pairs(map) do
			name = string.gsub(name, from, to)
		end
		name = string.gsub(name, "%s+", "")
		return name
	end

	local COLOR_BY_KEY = {}
	for _, entry in ipairs(Constants.VALID_COLORS) do
		COLOR_BY_KEY[colorKey(entry.name)] = Color3.fromRGB(entry.r, entry.g, entry.b)
	end

	for _, colorButton in ipairs(ColorFrame:GetChildren()) do
		if colorButton:IsA("GuiButton") then
			local exactColor = COLOR_BY_KEY[colorKey(colorButton.Name)]
			if exactColor then
				-- Paint the button from the palette so its visible color is the
				-- exact color that will be encoded/revealed.
				colorButton.BackgroundColor3 = exactColor
			else
				-- Unmatched button: fall back to its authored color but warn, since
				-- this color will quantize (possibly to black) on encode.
				warn("[UIController] color button '" .. colorButton.Name
					.. "' has no VALID_COLORS match; its color may not survive encoding")
				exactColor = colorButton.BackgroundColor3
			end

			colorButton.MouseButton1Click:Connect(function()
				canvasController:SetColor(exactColor)
				deactivateFillMode()
				deactivateEraser()
				playClickSound()
				highlightSelected(ColorFrame, colorButton)
			end)
		end
	end

	--------------------------------------------------------------------------------
	-- Brush Size Buttons
	--------------------------------------------------------------------------------

	for _, brushButton in ipairs(BrushFrame:GetChildren()) do
		if brushButton:IsA("GuiButton") then
			brushButton.MouseButton1Click:Connect(function()
				canvasController:SetBrushSize(brushButton.Name)
				deactivateFillMode()
				deactivateEraser()
				playClickSound()
				highlightSelected(BrushFrame, brushButton)
			end)
		end
	end

	--------------------------------------------------------------------------------
	-- Tool Buttons
	--------------------------------------------------------------------------------

	EraserButton.MouseButton1Click:Connect(function()
		canvasController:ActivateEraser()
		deactivateFillMode()
		eraserActive = true
		setToolHighlight(EraserButton, true)
		playClickSound()
	end)

	UndoButton.MouseButton1Click:Connect(function()
		canvasController:Undo()
		playClickSound()
	end)

	FillButton.MouseButton1Click:Connect(function()
		fillModeActive = not fillModeActive
		self.inputController:SetFillMode(fillModeActive)
		deactivateEraser()
		setToolHighlight(FillButton, fillModeActive)
		playClickSound()
	end)

	--------------------------------------------------------------------------------
	-- Submit Button
	--------------------------------------------------------------------------------

	local SubmitFrame  = MainFrame:WaitForChild("SubmitFrame", T)
	local SubmitButton = SubmitFrame and SubmitFrame:WaitForChild("SubmitButton", T)

	if SubmitButton then
		SubmitButton.MouseButton1Click:Connect(function()
			if onSubmit then onSubmit() end
		end)
	end

	--------------------------------------------------------------------------------
	-- Report Button
	--------------------------------------------------------------------------------

	local EmojiGui      = playerGui:WaitForChild("EmojiGui", T)
	local EmojiMain     = EmojiGui and EmojiGui:WaitForChild("MainFrame", T)
	local ReportButton  = EmojiMain and EmojiMain:WaitForChild("ReportButton", T)

	local reportOverlay
	local reportedThisRound = false

	local function getReportOverlay()
		if reportOverlay and reportOverlay.Parent then return reportOverlay end
		if not displayLabel then return nil end
		local overlay = Instance.new("Frame")
		overlay.Name             = "ReportOverlay"
		overlay.Size             = UDim2.fromScale(1, 1)
		overlay.Position         = UDim2.fromScale(0, 0)
		overlay.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		overlay.BorderSizePixel  = 0
		overlay.ZIndex           = displayLabel.ZIndex + 10
		overlay.Visible          = false
		local label = Instance.new("TextLabel")
		label.Size               = UDim2.fromScale(1, 0.2)
		label.Position           = UDim2.fromScale(0, 0.4)
		label.BackgroundTransparency = 1
		label.Text               = "Drawing Hidden"
		label.TextColor3         = Color3.new(1, 1, 1)
		label.TextScaled         = true
		label.Font               = Enum.Font.GothamBold
		label.Parent             = overlay
		overlay.Parent           = displayLabel.Parent
		reportOverlay            = overlay
		return overlay
	end

	function UIController:ShowReportOverlay()
		reportedThisRound = true
		local overlay = getReportOverlay()
		if overlay then overlay.Visible = true end
	end

	function UIController:HideReportOverlay()
		if reportOverlay then reportOverlay.Visible = false end
		reportedThisRound = false
	end

	if ReportButton then
		ReportButton.MouseButton1Click:Connect(function()
			if reportedThisRound then return end
			playClickSound()
			self:ShowReportOverlay()
			ReportRemote:FireServer()
		end)
	end

	--------------------------------------------------------------------------------
	-- Sidebar
	--------------------------------------------------------------------------------

	local SidebarGui       = playerGui:WaitForChild("SidebarGui", T)
	local SidebarContainer = SidebarGui and SidebarGui:WaitForChild("Container", T)

	--------------------------------------------------------------------------------
	-- Market
	--
	-- MarketButton (sidebar) toggles MarketGui open/closed; CloseButton closes it.
	-- TopBar holds one button per screen (FramesButton -> FramesScreen, SoonButton ->
	-- SoonScreen); clicking a tab shows its screen, hides the others, and highlights
	-- the active tab button. FramesScreen is the default open screen.
	--------------------------------------------------------------------------------

	local MarketGui    = playerGui:WaitForChild("MarketGui", T)
	local MarketFrame  = SidebarContainer and SidebarContainer:FindFirstChild("MarketFrame")
	local MarketButton = MarketFrame and MarketFrame:FindFirstChild("MarketButton")

	if MarketButton and MarketGui then
		MarketButton.MouseButton1Click:Connect(function()
			playClickSound()
			local opened = not MarketGui.Enabled
			MarketGui.Enabled = opened
			-- Analytics: signal only on open (not close). The server de-dupes to once per
			-- session, so firing on every open is fine.
			if opened then
				FrameRemote:FireServer("opened")
			end
		end)
	end

	local MarketNewLabel  = MarketFrame and MarketFrame:FindFirstChild("NewLabel")
	local MarketNewStroke = MarketNewLabel and MarketNewLabel:FindFirstChildOfClass("UIStroke")
	if MarketNewStroke then
		startBreathingStroke(MarketNewStroke)
	end

	local MarketContainer = MarketGui and MarketGui:WaitForChild("Container", T)
	local CloseButton     = MarketContainer and MarketContainer:FindFirstChild("CloseButton")
	local TopBar          = MarketContainer and MarketContainer:FindFirstChild("TopBar")
	local Screens         = MarketContainer and MarketContainer:FindFirstChild("Screens")

	if CloseButton and MarketGui then
		CloseButton.MouseButton1Click:Connect(function()
			playClickSound()
			MarketGui.Enabled = false
		end)
	end

	-- Tab definitions: each pairs a TopBar button with the Screen it shows. To add a
	-- market tab, author the button + screen in Studio and add one row here.
	if TopBar and Screens then
		local tabs = {
			{ button = "FramesButton", screen = "FramesScreen" },
			{ button = "SoonButton",   screen = "SoonScreen"   },
		}

		local function selectTab(active)
			for _, tab in ipairs(tabs) do
				local screen = Screens:FindFirstChild(tab.screen)
				if screen then screen.Visible = tab == active end
				local button = TopBar:FindFirstChild(tab.button)
				if button then setToolHighlight(button, tab == active) end
			end
		end

		for _, tab in ipairs(tabs) do
			local button = TopBar:FindFirstChild(tab.button)
			if button then
				button.MouseButton1Click:Connect(function()
					playClickSound()
					selectTab(tab)
				end)
			end
		end

		selectTab(tabs[1])
	end

	--------------------------------------------------------------------------------
	-- Invite Button
	--------------------------------------------------------------------------------

	local SocialService = game:GetService("SocialService")
	local InviteFrame   = SidebarContainer and SidebarContainer:FindFirstChild("InviteFrame")
	local InviteButton  = InviteFrame and InviteFrame:FindFirstChild("InviteButton")

	if InviteButton then
		InviteButton.MouseButton1Click:Connect(function()
			pcall(function()
				SocialService:PromptGameInvite(game.Players.LocalPlayer)
			end)
		end)
	end
end

--------------------------------------------------------------------------------

return UIController
