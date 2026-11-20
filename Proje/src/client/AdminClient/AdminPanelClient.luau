--[[
AdminPanelClient
----------------
Admin moderation panel. Listens to AdminRemote events and builds the UI
at runtime on first ShowPanel. Non-admin clients receive no events so
nothing ever appears for them.

ShowPanel payload contains both active and history lists; tab switching
is fully client-side (no extra server round-trip).

Action buttons (Dismiss / Ban) use optimistic updates: the row is moved
to history locally as soon as the admin clicks, then the server write
catches up. A fresh /panel always restores ground truth from DataStore.
]]

local Players              = game:GetService("Players")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")
local AssetService         = game:GetService("AssetService")
local ContextActionService = game:GetService("ContextActionService")

local Config = ReplicatedStorage:WaitForChild("Shared").Config
local Admin = require(Config.Admin)
local Drawing = require(Config.Drawing)
local StrokeCodec = require(ReplicatedStorage:WaitForChild("Shared").Drawing.StrokeCodec)
local DrawRenderer = require(script.Parent.Parent:WaitForChild("DrawRenderer"))

local Net = require(ReplicatedStorage:WaitForChild("Shared").Net)

local SELECTED_BORDER_COLOR = Color3.fromRGB(85, 255, 0)
local SELECTED_BORDER_THICKNESS = 3

local CANVAS_SIZE = Vector2.new(Drawing.CanvasSize, Drawing.CanvasSize)
local ESC_ACTION  = "AdminPanelClose"

-- Ban menu options in display order. Durations resolve from Admin.BanDurations
-- so the client and AdminPanelService never drift; "perm" maps to nil (permanent).
local BAN_OPTIONS = {
	{ key = "1h",   label = "1h" },
	{ key = "1d",   label = "1d" },
	{ key = "7d",   label = "7d" },
	{ key = "30d",  label = "30d" },
	{ key = "perm", label = "Perm" },
}

local AdminPanelClient = {}

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local refs        = nil
local cachedActive        = {}
local cachedHistory       = {}
local cachedFirstDrawings = {}
local currentTab          = "active"

-- [reportId] = { report, fromIndex, prevStatus, prevResolvedAt, prevResolvedBy, prevBanDuration }
-- Tracks rows optimistically moved to history while awaiting the server's
-- Ban/DismissResult, so a rejected action can be rolled back to "active".
local pendingActions = {}

--------------------------------------------------------------------------------
-- Helpers (forward decls)
--------------------------------------------------------------------------------

local renderCurrentTab
local makeReportRow
local makeFirstDrawingRow

--------------------------------------------------------------------------------
-- Build
--------------------------------------------------------------------------------

local function buildUI(player)
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name             = "AdminPanelGui"
	screenGui.ResetOnSpawn     = false
	screenGui.IgnoreGuiInset   = true
	screenGui.DisplayOrder     = 1000
	screenGui.Enabled          = false
	screenGui.Parent           = playerGui

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
	panel.BorderColor3     = SELECTED_BORDER_COLOR
	panel.BorderSizePixel  = SELECTED_BORDER_THICKNESS
	panel.Parent           = overlay

	local titleBar = Instance.new("Frame")
	titleBar.Name             = "TitleBar"
	titleBar.Size             = UDim2.new(1, 0, 0, 36)
	titleBar.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	titleBar.BorderSizePixel  = 0
	titleBar.Parent           = panel

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size                   = UDim2.new(1, -40, 1, 0)
	titleLabel.Position               = UDim2.fromOffset(10, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text                   = "Admin Panel"
	titleLabel.TextColor3             = Color3.new(1, 1, 1)
	titleLabel.TextXAlignment         = Enum.TextXAlignment.Left
	titleLabel.Font                   = Enum.Font.GothamBold
	titleLabel.TextSize               = 18
	titleLabel.Parent                 = titleBar

	local errorLabel = Instance.new("TextLabel")
	errorLabel.Name                   = "ErrorLabel"
	errorLabel.AnchorPoint            = Vector2.new(1, 0.5)
	errorLabel.Position               = UDim2.new(1, -44, 0.5, 0)
	errorLabel.Size                   = UDim2.new(0.5, 0, 1, 0)
	errorLabel.BackgroundTransparency = 1
	errorLabel.Text                   = ""
	errorLabel.TextColor3             = Color3.fromRGB(255, 120, 120)
	errorLabel.TextXAlignment         = Enum.TextXAlignment.Right
	errorLabel.Font                   = Enum.Font.GothamBold
	errorLabel.TextSize               = 13
	errorLabel.Parent                 = titleBar

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

	local tabBar = Instance.new("Frame")
	tabBar.Name             = "TabBar"
	tabBar.Position         = UDim2.fromOffset(0, 36)
	tabBar.Size             = UDim2.new(1, 0, 0, 32)
	tabBar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	tabBar.BorderSizePixel  = 0
	tabBar.Parent           = panel

	local function makeTabButton(name, text, posX)
		local btn = Instance.new("TextButton")
		btn.Name             = name
		btn.Position         = UDim2.fromOffset(posX, 4)
		btn.Size             = UDim2.fromOffset(160, 24)
		btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
		btn.BorderSizePixel  = 0
		btn.Text             = text
		btn.TextColor3       = Color3.new(1, 1, 1)
		btn.Font             = Enum.Font.GothamBold
		btn.TextSize         = 13
		btn.Parent           = tabBar
		return btn
	end

	local activeTab  = makeTabButton("ActiveTab",  "Active (0)",  10)
	local historyTab = makeTabButton("HistoryTab", "History (0)", 180)
	local firstTab   = makeTabButton("FirstTab",   "First-Timers (0)", 350)

	local content = Instance.new("Frame")
	content.Name                   = "Content"
	content.Position               = UDim2.fromOffset(0, 68)
	content.Size                   = UDim2.new(1, 0, 1, -68)
	content.BackgroundTransparency = 1
	content.Parent                 = panel

	local listScroll = Instance.new("ScrollingFrame")
	listScroll.Name                = "ReportList"
	listScroll.Size                = UDim2.new(0.45, 0, 1, 0)
	listScroll.BackgroundColor3    = Color3.fromRGB(20, 20, 20)
	listScroll.BorderSizePixel     = 0
	listScroll.CanvasSize          = UDim2.new(0, 0, 0, 0)
	listScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listScroll.ScrollBarThickness  = 6
	listScroll.Parent              = content

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 4)
	listLayout.Parent  = listScroll

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
	drawingImage.Size             = UDim2.fromOffset(300, 300)
	drawingImage.BackgroundColor3 = Color3.new(1, 1, 1)
	drawingImage.BorderColor3     = SELECTED_BORDER_COLOR
	drawingImage.BorderSizePixel  = 2
	drawingImage.ScaleType        = Enum.ScaleType.Stretch
	drawingImage.Parent           = preview

	local editableImage = AssetService:CreateEditableImage({ Size = CANVAS_SIZE })
	drawingImage.ImageContent = Content.fromObject(editableImage)
	DrawRenderer.clear(editableImage)

	local metaFrame = Instance.new("Frame")
	metaFrame.Name                   = "Meta"
	metaFrame.AnchorPoint            = Vector2.new(0.5, 0)
	metaFrame.Position               = UDim2.new(0.5, 0, 0, 330)
	metaFrame.Size                   = UDim2.new(1, -20, 0, 150)
	metaFrame.BackgroundColor3       = Color3.fromRGB(20, 20, 20)
	metaFrame.BorderSizePixel        = 0
	metaFrame.Parent                 = preview

	local metaLayout = Instance.new("UIListLayout")
	metaLayout.Padding = UDim.new(0, 4)
	metaLayout.Parent  = metaFrame

	local metaPadding = Instance.new("UIPadding")
	metaPadding.PaddingTop  = UDim.new(0, 8)
	metaPadding.PaddingLeft = UDim.new(0, 10)
	metaPadding.Parent      = metaFrame

	local function makeMetaLabel(name)
		local label = Instance.new("TextLabel")
		label.Name                   = name
		label.Size                   = UDim2.new(1, 0, 0, 22)
		label.BackgroundTransparency = 1
		label.Text                   = ""
		label.TextColor3             = Color3.new(1, 1, 1)
		label.Font                   = Enum.Font.Gotham
		label.TextSize               = 14
		label.TextXAlignment         = Enum.TextXAlignment.Left
		label.Parent                 = metaFrame
		return label
	end

	refs = {
		player        = player,
		screenGui     = screenGui,
		panel         = panel,
		errorLabel    = errorLabel,
		activeTab     = activeTab,
		historyTab    = historyTab,
		firstTab      = firstTab,
		listScroll    = listScroll,
		drawingImage  = drawingImage,
		editableImage = editableImage,
		themeLabel    = makeMetaLabel("Theme"),
		ownerLabel    = makeMetaLabel("Owner"),
		reporterLabel = makeMetaLabel("Reports"),
		timeLabel     = makeMetaLabel("Time"),
		statusLabel   = makeMetaLabel("Status"),
	}

	closeButton.MouseButton1Click:Connect(function()
		AdminPanelClient.hide()
	end)

	activeTab.MouseButton1Click:Connect(function()
		currentTab = "active"
		renderCurrentTab()
	end)

	historyTab.MouseButton1Click:Connect(function()
		currentTab = "history"
		renderCurrentTab()
	end)

	firstTab.MouseButton1Click:Connect(function()
		currentTab = "first"
		renderCurrentTab()
	end)
end

--------------------------------------------------------------------------------
-- Rendering helpers
--------------------------------------------------------------------------------

local function clearList()
	for _, child in ipairs(refs.listScroll:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextButton") then
			child:Destroy()
		end
	end
end

local function highlightTabs()
	local SELECTED = SELECTED_BORDER_COLOR
	local IDLE     = Color3.fromRGB(45, 45, 45)
	local BLACK    = Color3.new(0, 0, 0)
	local WHITE    = Color3.new(1, 1, 1)

	refs.activeTab.BackgroundColor3  = (currentTab == "active")  and SELECTED or IDLE
	refs.activeTab.TextColor3        = (currentTab == "active")  and BLACK or WHITE
	refs.historyTab.BackgroundColor3 = (currentTab == "history") and SELECTED or IDLE
	refs.historyTab.TextColor3       = (currentTab == "history") and BLACK or WHITE
	refs.firstTab.BackgroundColor3   = (currentTab == "first")   and SELECTED or IDLE
	refs.firstTab.TextColor3         = (currentTab == "first")   and BLACK or WHITE
end

local function updateTabCounts()
	refs.activeTab.Text  = string.format("Active (%d)",  #cachedActive)
	refs.historyTab.Text = string.format("History (%d)", #cachedHistory)
	refs.firstTab.Text   = string.format("First-Timers (%d)", #cachedFirstDrawings)
end

local function formatTime(timestamp)
	if not timestamp then return "" end
	return os.date("!%Y-%m-%d %H:%M UTC", timestamp)
end

local function statusBadge(report)
	if report.status == "dismissed" then
		return "[Dismissed]"
	elseif report.status == "banned" then
		if report.banDuration then
			local hours = math.ceil(report.banDuration / Admin.SecondsPerHour)
			if hours >= Admin.HoursPerDay then
				return string.format("[Banned %dd]", math.ceil(hours / Admin.HoursPerDay))
			else
				return string.format("[Banned %dh]", hours)
			end
		else
			return "[Banned Perm]"
		end
	end
	return ""
end

local function moveReportToHistory(reportId, mutate)
	for i, report in ipairs(cachedActive) do
		if report.reportId == reportId then
			-- Snapshot the pre-action fields so onActionResult can roll back if
			-- the server rejects this optimistic move.
			pendingActions[reportId] = {
				report          = report,
				fromIndex       = i,
				prevStatus      = report.status,
				prevResolvedAt  = report.resolvedAt,
				prevResolvedBy  = report.resolvedBy,
				prevBanDuration = report.banDuration,
			}

			table.remove(cachedActive, i)
			mutate(report)
			report.resolvedAt = os.time()
			report.resolvedBy = Players.LocalPlayer.UserId
			table.insert(cachedHistory, 1, report)
			return
		end
	end
end

-- Undoes an optimistic moveReportToHistory: pulls the row back out of history,
-- restores its original fields, and reinserts it into the active list.
local function rollbackPendingAction(reportId)
	local pending = pendingActions[reportId]
	pendingActions[reportId] = nil
	if not pending then return end

	local report = pending.report
	for i, r in ipairs(cachedHistory) do
		if r == report then
			table.remove(cachedHistory, i)
			break
		end
	end

	report.status      = pending.prevStatus
	report.resolvedAt  = pending.prevResolvedAt
	report.resolvedBy  = pending.prevResolvedBy
	report.banDuration = pending.prevBanDuration

	local insertAt = math.clamp(pending.fromIndex, 1, #cachedActive + 1)
	table.insert(cachedActive, insertAt, report)
end

local function onDismiss(reportId)
	Net.fireServer("Admin", "DismissReport", { reportId = reportId })
	moveReportToHistory(reportId, function(r) r.status = "dismissed" end)
	renderCurrentTab()
end

local function onBan(reportId, durationKey, durationSeconds)
	Net.fireServer("Admin", "BanReportee", {
		reportId    = reportId,
		durationKey = durationKey,
	})
	moveReportToHistory(reportId, function(r)
		r.status      = "banned"
		r.banDuration = durationSeconds
	end)
	renderCurrentTab()
end

function makeReportRow(report)
	local row = Instance.new("Frame")
	row.Size             = UDim2.new(1, -6, 0, 78)
	row.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	row.BorderSizePixel  = 0

	local viewButton = Instance.new("TextButton")
	viewButton.Size                   = UDim2.new(1, -100, 1, 0)
	viewButton.BackgroundTransparency = 1
	viewButton.Font                   = Enum.Font.Gotham
	viewButton.TextSize               = 12
	viewButton.TextColor3             = Color3.new(1, 1, 1)
	viewButton.TextXAlignment         = Enum.TextXAlignment.Left
	viewButton.TextYAlignment         = Enum.TextYAlignment.Top
	viewButton.RichText               = true
	viewButton.TextWrapped            = true
	viewButton.Parent                 = row

	local viewPadding = Instance.new("UIPadding")
	viewPadding.PaddingLeft = UDim.new(0, 6)
	viewPadding.PaddingTop  = UDim.new(0, 4)
	viewPadding.Parent      = viewButton

	local badge = statusBadge(report)
	local badgeLine = (badge ~= "") and ("\n" .. badge) or ""
	viewButton.Text = string.format(
		"<b>%s</b>\nowner %d, reports %d\n%s%s",
		tostring(report.theme or "?"),
		tonumber(report.ownerUserId) or 0,
		tonumber(report.reporterCount) or 0,
		formatTime(report.timestamp),
		badgeLine
	)

	viewButton.MouseButton1Click:Connect(function()
		Net.fireServer("Admin", "ViewReport", { reportId = report.reportId })
	end)

	if report.status == "active" or report.status == nil then
		local actions = Instance.new("Frame")
		actions.AnchorPoint            = Vector2.new(1, 0)
		actions.Position               = UDim2.new(1, -4, 0, 4)
		actions.Size                   = UDim2.new(0, 94, 1, -8)
		actions.BackgroundTransparency = 1
		actions.Parent                 = row

		local dismissBtn = Instance.new("TextButton")
		dismissBtn.Size             = UDim2.new(1, 0, 0, 28)
		dismissBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
		dismissBtn.BorderSizePixel  = 0
		dismissBtn.Text             = "Dismiss"
		dismissBtn.TextColor3       = Color3.new(1, 1, 1)
		dismissBtn.Font             = Enum.Font.GothamBold
		dismissBtn.TextSize         = 12
		dismissBtn.Parent           = actions

		local banToggle = Instance.new("TextButton")
		banToggle.Position         = UDim2.fromOffset(0, 32)
		banToggle.Size             = UDim2.new(1, 0, 0, 28)
		banToggle.BackgroundColor3 = Color3.fromRGB(150, 60, 60)
		banToggle.BorderSizePixel  = 0
		banToggle.Text             = "Ban v"
		banToggle.TextColor3       = Color3.new(1, 1, 1)
		banToggle.Font             = Enum.Font.GothamBold
		banToggle.TextSize         = 12
		banToggle.Parent           = actions

		local banMenu = Instance.new("Frame")
		banMenu.AnchorPoint            = Vector2.new(1, 0)
		banMenu.Position               = UDim2.new(0, -2, 0, 32)
		banMenu.Size                   = UDim2.fromOffset(220, 28)
		banMenu.BackgroundColor3       = Color3.fromRGB(30, 30, 30)
		banMenu.BorderSizePixel        = 0
		banMenu.Visible                = false
		banMenu.ZIndex                 = 5
		banMenu.Parent                 = actions

		local banLayout = Instance.new("UIListLayout")
		banLayout.FillDirection      = Enum.FillDirection.Horizontal
		banLayout.Padding            = UDim.new(0, 2)
		banLayout.SortOrder          = Enum.SortOrder.LayoutOrder
		banLayout.Parent             = banMenu

		for i, opt in ipairs(BAN_OPTIONS) do
			local optBtn = Instance.new("TextButton")
			optBtn.LayoutOrder      = i
			optBtn.Size             = UDim2.fromOffset(42, 28)
			optBtn.BackgroundColor3 = Color3.fromRGB(150, 60, 60)
			optBtn.BorderSizePixel  = 0
			optBtn.Text             = opt.label
			optBtn.TextColor3       = Color3.new(1, 1, 1)
			optBtn.Font             = Enum.Font.GothamBold
			optBtn.TextSize         = 12
			optBtn.ZIndex           = 5
			optBtn.Parent           = banMenu

			optBtn.MouseButton1Click:Connect(function()
				banMenu.Visible = false
				-- nil for "perm" (absent from BAN_DURATIONS) = permanent ban
				onBan(report.reportId, opt.key, Admin.BanDurations[opt.key])
			end)
		end

		dismissBtn.MouseButton1Click:Connect(function()
			onDismiss(report.reportId)
		end)

		banToggle.MouseButton1Click:Connect(function()
			banMenu.Visible = not banMenu.Visible
		end)
	end

	return row
end

-- First-Timers row: view-only (no action buttons). Clicking fetches the drawing.
function makeFirstDrawingRow(entry)
	local row = Instance.new("Frame")
	row.Size             = UDim2.new(1, -6, 0, 56)
	row.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	row.BorderSizePixel  = 0

	local viewButton = Instance.new("TextButton")
	viewButton.Size                   = UDim2.new(1, 0, 1, 0)
	viewButton.BackgroundTransparency = 1
	viewButton.Font                   = Enum.Font.Gotham
	viewButton.TextSize               = 12
	viewButton.TextColor3             = Color3.new(1, 1, 1)
	viewButton.TextXAlignment         = Enum.TextXAlignment.Left
	viewButton.TextYAlignment         = Enum.TextYAlignment.Top
	viewButton.RichText               = true
	viewButton.TextWrapped            = true
	viewButton.Parent                 = row

	local viewPadding = Instance.new("UIPadding")
	viewPadding.PaddingLeft = UDim.new(0, 6)
	viewPadding.PaddingTop  = UDim.new(0, 4)
	viewPadding.Parent      = viewButton

	viewButton.Text = string.format(
		"<b>%s</b>\nowner %d\n%s",
		tostring(entry.theme or "?"),
		tonumber(entry.ownerUserId) or 0,
		formatTime(entry.timestamp)
	)

	viewButton.MouseButton1Click:Connect(function()
		Net.fireServer("Admin", "ViewFirstDrawing", { entryId = entry.entryId })
	end)

	return row
end

renderCurrentTab = function()
	clearList()
	local list
	if currentTab == "active" then
		list = cachedActive
	elseif currentTab == "history" then
		list = cachedHistory
	else
		list = cachedFirstDrawings
	end

	for _, item in ipairs(list) do
		if currentTab == "first" then
			makeFirstDrawingRow(item).Parent = refs.listScroll
		else
			makeReportRow(item).Parent = refs.listScroll
		end
	end
	updateTabCounts()
	highlightTabs()
end

--------------------------------------------------------------------------------
-- Transient error banner (title bar). Token guards against an earlier message's
-- clear timer wiping a newer message.
--------------------------------------------------------------------------------

-- Server failure reasons -> short admin-facing messages. Unknown reasons fall
-- back to a generic string so the panel never shows a raw code.
local REASON_TEXT = {
	rate_limited      = "Too fast - wait a moment and retry",
	bad_duration      = "Invalid ban duration",
	not_found         = "Report no longer available",
	store_busy        = "DataStore busy - retry",
	store_unavailable = "DataStore unavailable (Studio API access off?)",
	server_error      = "Server error - retry",
}

local function reasonText(reason)
	return REASON_TEXT[reason] or "Action failed - retry"
end

local errorToken = 0

local function flashError(message)
	if not refs then return end
	errorToken += 1
	local myToken = errorToken
	refs.errorLabel.Text = message
	task.delay(Admin.ErrorFlashSeconds, function()
		if errorToken == myToken and refs then
			refs.errorLabel.Text = ""
		end
	end)
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

-- Server confirmation for an optimistic Ban/Dismiss. On failure, roll the row
-- back to "active" and surface a short message so the admin can retry.
function AdminPanelClient.onActionResult(eventKind, payload)
	if not refs then return end
	if typeof(payload.reportId) ~= "string" then return end

	if payload.ok then
		pendingActions[payload.reportId] = nil
		return
	end

	rollbackPendingAction(payload.reportId)
	renderCurrentTab()

	local verb = (eventKind == "BanResult") and "Ban" or "Dismiss"
	flashError(verb .. ": " .. reasonText(payload.reason))
end

-- Server rejected a command outside the optimistic Dismiss/Ban path (panel open
-- rate-limited, ViewReport target gone, or a handler error). No row to roll back;
-- just surface the reason so the panel never appears to hang.
function AdminPanelClient.onCommandRejected(_eventKind, payload)
	if not refs then return end
	flashError(reasonText(payload.reason))
end

function AdminPanelClient.show(player, active, history, firstDrawings)
	if not refs then buildUI(player) end

	-- Fresh ground truth from the server supersedes any in-flight optimistic
	-- actions, so drop their rollback snapshots.
	pendingActions = {}

	cachedActive        = active        or {}
	cachedHistory       = history       or {}
	cachedFirstDrawings = firstDrawings or {}
	currentTab          = "active"

	refs.errorLabel.Text = ""

	DrawRenderer.clear(refs.editableImage)
	refs.themeLabel.Text    = ""
	refs.ownerLabel.Text    = ""
	refs.reporterLabel.Text = ""
	refs.timeLabel.Text     = ""
	refs.statusLabel.Text   = ""

	renderCurrentTab()
	refs.screenGui.Enabled = true

	ContextActionService:BindAction(ESC_ACTION, function(_, state)
		if state == Enum.UserInputState.Begin then
			AdminPanelClient.hide()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Escape)
end

function AdminPanelClient.hide()
	if not refs then return end
	refs.screenGui.Enabled = false
	ContextActionService:UnbindAction(ESC_ACTION)
end

function AdminPanelClient.renderDrawing(report)
	if not refs then return end
	if typeof(report.drawingBuffer) ~= "buffer" then return end

	local strokes = StrokeCodec.decode(report.drawingBuffer)
	DrawRenderer.render(refs.editableImage, strokes)

	refs.themeLabel.Text    = "Theme: " .. tostring(report.theme or "?")
	refs.ownerLabel.Text    = "Owner UserId: " .. tostring(report.ownerUserId or 0)
	refs.reporterLabel.Text = "Reports: " .. tostring(report.reporterCount or 0)
	refs.timeLabel.Text     = "Time: " .. formatTime(report.timestamp)
	refs.statusLabel.Text   = ""
end

-- First-Timers detail: drawing + theme only (no reporter/status fields).
function AdminPanelClient.renderFirstDrawing(entry)
	if not refs then return end
	if typeof(entry.drawingBuffer) ~= "buffer" then return end

	local strokes = StrokeCodec.decode(entry.drawingBuffer)
	DrawRenderer.render(refs.editableImage, strokes)

	refs.themeLabel.Text    = "Theme: " .. tostring(entry.theme or "?")
	refs.ownerLabel.Text    = "Owner UserId: " .. tostring(entry.ownerUserId or 0)
	refs.reporterLabel.Text = "First-time player"
	refs.timeLabel.Text     = "Time: " .. formatTime(entry.timestamp)
	refs.statusLabel.Text   = ""
end

return AdminPanelClient
