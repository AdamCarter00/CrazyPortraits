--[[
DrawingsPanelClient
-------------------
Browse-only analysis panel for first-timer drawings, opened with /drawings.
Listens to AdminRemote events and builds its UI at runtime on the first
DrawingsPage. Non-admin clients receive no events so nothing appears for them.

Independent from AdminPanelClient (the /panel moderation panel): a separate
ScreenGui, no ban/dismiss actions. The left list is paginated (oldest first);
clicking a row fetches and renders that single drawing at 200x200 on the right,
with its theme, owner, UTC time, and A/B experiment group (from the owner UserId).

The drawing is always rendered onto a 512x512 EditableImage (the size the whole
render pipeline — DrawRenderer / FloodFill — is built around) and shown in a
200x200 ImageLabel with ScaleType.Stretch, exactly like the gallery / admin
preview. Rendering at a smaller buffer is unsafe (FloodFill assumes 512x512).
]]

local Players              = game:GetService("Players")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")
local AssetService         = game:GetService("AssetService")
local ContextActionService = game:GetService("ContextActionService")

local Constants    = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local StrokeCodec  = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("StrokeCodec"))
local DrawRenderer = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("DrawRenderer"))

local AdminRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AdminRemote")

local CANVAS_SIZE = Vector2.new(Constants.CANVAS_SIZE, Constants.CANVAS_SIZE)
local ESC_ACTION  = "DrawingsPanelClose"

local DrawingsPanelClient = {}

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local refs = nil

local currentEntries = {}    -- current page summaries (oldest first)
local nextCursor     = nil   -- cursor for the next page, or nil at the end
-- History of the `cursor` values that produced each visited page, so "Previous"
-- can walk back. The top is the current page's cursor. The first page has no
-- cursor; it is stored as the FIRST_PAGE sentinel rather than nil so the table
-- keeps a real length (a nil element would make #cursorStack drop it). The
-- sentinel is translated back to nil before going to the server.
local FIRST_PAGE     = newproxy()
local cursorStack    = {}
local loading        = false

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function formatTime(timestamp)
	if not timestamp then return "" end
	return os.date("!%Y-%m-%d %H:%M UTC", timestamp)
end

-- A/B experiment group from the owner's UserId (even -> A, odd -> B), matching
-- GroupService so a player's drawing shows the same group as the live game.
local function groupOf(ownerUserId)
	if typeof(ownerUserId) ~= "number" or ownerUserId <= 0 then return "?" end
	return (ownerUserId % 2 == 0) and "A Grubu" or "B Grubu"
end

local renderCurrentPage

--------------------------------------------------------------------------------
-- Build
--------------------------------------------------------------------------------

local function buildUI(player)
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name           = "DrawingsPanelGui"
	screenGui.ResetOnSpawn   = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder   = 1000
	screenGui.Enabled        = false
	screenGui.Parent         = playerGui

	local overlay = Instance.new("Frame")
	overlay.Name                   = "Overlay"
	overlay.Size                   = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3       = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.5
	overlay.BorderSizePixel        = 0
	overlay.Parent                 = screenGui

	local panel = Instance.new("Frame")
	panel.Name             = "Panel"
	panel.AnchorPoint      = Vector2.new(0.5, 0.5)
	panel.Position         = UDim2.fromScale(0.5, 0.5)
	panel.Size             = UDim2.fromScale(0.85, 0.85)
	panel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	panel.BorderColor3     = Constants.SELECTED_BORDER_COLOR
	panel.BorderSizePixel  = Constants.SELECTED_BORDER_THICKNESS
	panel.Parent           = overlay

	local titleBar = Instance.new("Frame")
	titleBar.Name             = "TitleBar"
	titleBar.Size             = UDim2.new(1, 0, 0, 36)
	titleBar.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	titleBar.BorderSizePixel  = 0
	titleBar.Parent           = panel

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size                   = UDim2.new(1, -200, 1, 0)
	titleLabel.Position               = UDim2.fromOffset(10, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text                   = "Cizim Analizi"
	titleLabel.TextColor3             = Color3.new(1, 1, 1)
	titleLabel.TextXAlignment         = Enum.TextXAlignment.Left
	titleLabel.Font                   = Enum.Font.GothamBold
	titleLabel.TextSize               = 18
	titleLabel.Parent                 = titleBar

	local pageLabel = Instance.new("TextLabel")
	pageLabel.Name                   = "PageLabel"
	pageLabel.AnchorPoint            = Vector2.new(1, 0.5)
	pageLabel.Position               = UDim2.new(1, -44, 0.5, 0)
	pageLabel.Size                   = UDim2.fromOffset(150, 36)
	pageLabel.BackgroundTransparency = 1
	pageLabel.Text                   = ""
	pageLabel.TextColor3             = Color3.fromRGB(200, 200, 200)
	pageLabel.TextXAlignment         = Enum.TextXAlignment.Right
	pageLabel.Font                   = Enum.Font.Gotham
	pageLabel.TextSize               = 13
	pageLabel.Parent                 = titleBar

	local closeButton = Instance.new("TextButton")
	closeButton.Name             = "CloseButton"
	closeButton.AnchorPoint      = Vector2.new(1, 0.5)
	closeButton.Position         = UDim2.new(1, -6, 0.5, 0)
	closeButton.Size             = UDim2.fromOffset(28, 28)
	closeButton.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
	closeButton.BorderSizePixel  = 0
	closeButton.Text             = "X"
	closeButton.TextColor3       = Color3.new(1, 1, 1)
	closeButton.Font             = Enum.Font.GothamBold
	closeButton.TextSize         = 16
	closeButton.Parent           = titleBar

	local content = Instance.new("Frame")
	content.Name                   = "Content"
	content.Position               = UDim2.fromOffset(0, 36)
	content.Size                   = UDim2.new(1, 0, 1, -36)
	content.BackgroundTransparency = 1
	content.Parent                 = panel

	-- Left: paginated list + page nav at the bottom.
	local listScroll = Instance.new("ScrollingFrame")
	listScroll.Name                = "DrawingList"
	listScroll.Size                = UDim2.new(0.45, 0, 1, -40)
	listScroll.BackgroundColor3    = Color3.fromRGB(20, 20, 20)
	listScroll.BorderSizePixel     = 0
	listScroll.CanvasSize          = UDim2.new(0, 0, 0, 0)
	listScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listScroll.ScrollBarThickness  = 6
	listScroll.Parent              = content

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 4)
	listLayout.Parent  = listScroll

	local nav = Instance.new("Frame")
	nav.Name             = "Nav"
	nav.Position         = UDim2.new(0, 0, 1, -40)
	nav.Size             = UDim2.new(0.45, 0, 0, 40)
	nav.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	nav.BorderSizePixel  = 0
	nav.Parent           = content

	local function makeNavButton(name, text, anchorRight)
		local btn = Instance.new("TextButton")
		btn.Name             = name
		btn.Size             = UDim2.fromOffset(120, 28)
		btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
		btn.BorderSizePixel  = 0
		btn.Text             = text
		btn.TextColor3       = Color3.new(1, 1, 1)
		btn.Font             = Enum.Font.GothamBold
		btn.TextSize         = 13
		btn.Parent           = nav
		if anchorRight then
			btn.AnchorPoint = Vector2.new(1, 0.5)
			btn.Position    = UDim2.new(1, -10, 0.5, 0)
		else
			btn.Position = UDim2.new(0, 10, 0.5, -14)
		end
		return btn
	end

	local prevButton = makeNavButton("PrevButton", "< Onceki", false)
	local nextButton = makeNavButton("NextButton", "Sonraki >", true)

	-- Right: 200x200 preview + metadata.
	local preview = Instance.new("Frame")
	preview.Name                   = "Preview"
	preview.Position               = UDim2.fromScale(0.45, 0)
	preview.Size                   = UDim2.new(0.55, 0, 1, 0)
	preview.BackgroundTransparency = 1
	preview.Parent                 = content

	local drawingImage = Instance.new("ImageLabel")
	drawingImage.Name             = "Drawing"
	drawingImage.AnchorPoint      = Vector2.new(0.5, 0)
	drawingImage.Position         = UDim2.new(0.5, 0, 0, 16)
	drawingImage.Size             = UDim2.fromOffset(200, 200)
	drawingImage.BackgroundColor3 = Color3.new(1, 1, 1)
	drawingImage.BorderColor3     = Constants.SELECTED_BORDER_COLOR
	drawingImage.BorderSizePixel  = 2
	drawingImage.ScaleType        = Enum.ScaleType.Stretch
	drawingImage.Parent           = preview

	local editableImage = AssetService:CreateEditableImage({ Size = CANVAS_SIZE })
	drawingImage.ImageContent = Content.fromObject(editableImage)
	DrawRenderer.clear(editableImage)

	local metaFrame = Instance.new("Frame")
	metaFrame.Name             = "Meta"
	metaFrame.AnchorPoint      = Vector2.new(0.5, 0)
	metaFrame.Position         = UDim2.new(0.5, 0, 0, 232)
	metaFrame.Size             = UDim2.new(1, -20, 0, 150)
	metaFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	metaFrame.BorderSizePixel  = 0
	metaFrame.Parent           = preview

	local metaLayout = Instance.new("UIListLayout")
	metaLayout.Padding = UDim.new(0, 4)
	metaLayout.Parent  = metaFrame

	local metaPadding = Instance.new("UIPadding")
	metaPadding.PaddingTop  = UDim.new(0, 8)
	metaPadding.PaddingLeft = UDim.new(0, 10)
	metaPadding.Parent      = metaFrame

	local function makeMetaLabel(name, color, size)
		local label = Instance.new("TextLabel")
		label.Name                   = name
		label.Size                   = UDim2.new(1, 0, 0, 22)
		label.BackgroundTransparency = 1
		label.Text                   = ""
		label.TextColor3             = color or Color3.new(1, 1, 1)
		label.Font                   = Enum.Font.Gotham
		label.TextSize               = size or 14
		label.TextXAlignment         = Enum.TextXAlignment.Left
		label.Parent                 = metaFrame
		return label
	end

	refs = {
		player        = player,
		screenGui     = screenGui,
		pageLabel     = pageLabel,
		listScroll    = listScroll,
		prevButton    = prevButton,
		nextButton    = nextButton,
		editableImage = editableImage,
		themeLabel    = makeMetaLabel("Theme"),
		ownerLabel    = makeMetaLabel("Owner"),
		timeLabel     = makeMetaLabel("Time"),
		-- Group sits last, smaller and dimmer — a quiet footnote under the metadata.
		groupLabel    = makeMetaLabel("Group", Color3.fromRGB(170, 170, 170), 12),
	}

	closeButton.MouseButton1Click:Connect(function()
		DrawingsPanelClient.hide()
	end)

	prevButton.MouseButton1Click:Connect(function()
		DrawingsPanelClient.requestPrevPage()
	end)

	nextButton.MouseButton1Click:Connect(function()
		DrawingsPanelClient.requestNextPage()
	end)
end

--------------------------------------------------------------------------------
-- List rendering
--------------------------------------------------------------------------------

local function clearList()
	for _, child in ipairs(refs.listScroll:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
end

local function makeRow(entry)
	local row = Instance.new("TextButton")
	row.Size                   = UDim2.new(1, -6, 0, 52)
	row.BackgroundColor3       = Color3.fromRGB(40, 40, 40)
	row.BorderSizePixel        = 0
	row.AutoButtonColor        = true
	row.Font                   = Enum.Font.Gotham
	row.TextSize               = 12
	row.TextColor3             = Color3.new(1, 1, 1)
	row.TextXAlignment         = Enum.TextXAlignment.Left
	row.TextYAlignment         = Enum.TextYAlignment.Top
	row.RichText               = true
	row.TextWrapped            = true
	row.Text = string.format(
		"<b>%s</b>\n%s  -  %s",
		tostring(entry.theme or "?"),
		formatTime(entry.timestamp),
		groupOf(entry.ownerUserId)
	)

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingTop  = UDim.new(0, 4)
	pad.Parent      = row

	row.MouseButton1Click:Connect(function()
		AdminRemote:FireServer("ViewDrawing", { entryId = entry.entryId })
	end)

	return row
end

function renderCurrentPage()
	clearList()
	for _, entry in ipairs(currentEntries) do
		makeRow(entry).Parent = refs.listScroll
	end

	-- Page number from how deep we are in the cursor stack (1-based).
	local pageNo = math.max(1, #cursorStack)
	refs.pageLabel.Text = string.format("Sayfa %d  (%d kayit)", pageNo, #currentEntries)

	-- Prev is available once we are past the first page; Next while a cursor exists.
	local hasPrev = #cursorStack > 1
	local hasNext = nextCursor ~= nil
	refs.prevButton.Active           = hasPrev
	refs.prevButton.AutoButtonColor  = hasPrev
	refs.prevButton.TextTransparency = hasPrev and 0 or 0.5
	refs.nextButton.Active           = hasNext
	refs.nextButton.AutoButtonColor  = hasNext
	refs.nextButton.TextTransparency = hasNext and 0 or 0.5
end

--------------------------------------------------------------------------------
-- Pagination requests
--------------------------------------------------------------------------------

function DrawingsPanelClient.requestNextPage()
	if loading or nextCursor == nil then return end
	loading = true
	-- Push the cursor that will produce the next page; showPage just renders it.
	table.insert(cursorStack, nextCursor)
	AdminRemote:FireServer("ShowDrawings", { cursor = nextCursor })
end

function DrawingsPanelClient.requestPrevPage()
	if loading or #cursorStack <= 1 then return end
	loading = true
	-- Pop the current page's cursor; the new top is the previous page's cursor.
	table.remove(cursorStack)
	local prevCursor = cursorStack[#cursorStack]
	if prevCursor == FIRST_PAGE then prevCursor = nil end
	AdminRemote:FireServer("ShowDrawings", { cursor = prevCursor })
end

--------------------------------------------------------------------------------
-- Event entry points
--------------------------------------------------------------------------------

-- A page arrived from the server (the only server->client list event; the first
-- /drawings open and every page nav all deliver DrawingsPage).
-- payload: { entries, cursor, nextCursor }.
--
-- A nil cursor marks a fresh /drawings open (the chat hook always requests the
-- first page with cursor=nil), so the navigation stack restarts. Forward/back
-- nav pushes/pops the stack itself before firing, then renders here.
function DrawingsPanelClient.showPage(payload)
	if not refs then buildUI(Players.LocalPlayer) end
	loading = false

	if payload.cursor == nil then
		-- Fresh open: restart the browse from page 1 (sentinel = no cursor).
		cursorStack = { FIRST_PAGE }
	end

	currentEntries = (typeof(payload.entries) == "table") and payload.entries or {}
	nextCursor     = payload.nextCursor

	renderCurrentPage()
	refs.screenGui.Enabled = true

	ContextActionService:BindAction(ESC_ACTION, function(_, state)
		if state == Enum.UserInputState.Begin then
			DrawingsPanelClient.hide()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Escape)
end

function DrawingsPanelClient.renderDrawing(entry)
	if not refs then return end

	if typeof(entry.drawingBuffer) == "buffer" then
		local strokes = StrokeCodec.decode(entry.drawingBuffer)
		DrawRenderer.render(refs.editableImage, strokes)
	else
		DrawRenderer.clear(refs.editableImage)
	end

	refs.themeLabel.Text = "Tema: " .. tostring(entry.theme or "?")
	refs.ownerLabel.Text = "Owner UserId: " .. tostring(entry.ownerUserId or 0)
	refs.timeLabel.Text  = "Tarih: " .. formatTime(entry.timestamp)
	refs.groupLabel.Text = "Grup: " .. groupOf(entry.ownerUserId)
end

function DrawingsPanelClient.hide()
	if not refs then return end
	refs.screenGui.Enabled = false
	ContextActionService:UnbindAction(ESC_ACTION)
end

return DrawingsPanelClient
