local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider   = game:GetService("ContentProvider")
local AssetService      = game:GetService("AssetService")
local RunService        = game:GetService("RunService")

local Constants    = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local DrawRenderer = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("DrawRenderer"))

local GUI_TIMEOUT = Constants.GUI_TIMEOUT

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

-- Logs which name failed and at which parent so failures are debuggable.
local function waitForRequired(parent, name, label)
	if not parent then
		warn("[RefsBuilder] waitForRequired: parent is nil, cannot wait for", name)
		return nil
	end
	local obj = parent:WaitForChild(name, GUI_TIMEOUT)
	if not obj then
		warn("[RefsBuilder] Required ref missing:", name, "- parent:", parent:GetFullName(), label and ("(" .. label .. ")") or "")
	end
	return obj
end

local function waitForOptional(parent, name)
	if not parent then return nil end
	local obj = parent:WaitForChild(name, GUI_TIMEOUT)
	if not obj then
		warn("[RefsBuilder] Optional ref missing:", name, "- parent:", parent:GetFullName())
	end
	return obj
end

-- Logs which step in the chain failed.
local function waitForChain(root, names, label)
	local node = root
	for i, name in ipairs(names) do
		if not node then
			warn("[RefsBuilder] Chain broken before step", i, "('" .. name .. "')", label and ("- " .. label) or "")
			return nil
		end
		local next = node:WaitForChild(name, GUI_TIMEOUT)
		if not next then
			warn("[RefsBuilder] Chain step failed: '" .. name .. "' not found under", node:GetFullName(), label and ("(" .. label .. ")") or "")
			return nil
		end
		node = next
	end
	return node
end

--------------------------------------------------------------------------------
-- Fatal Batch  (missing any one = nil return, game cannot run)
--------------------------------------------------------------------------------

local function loadFatalRefs(playerGui)
	local r = {}

	-- PlayerGui
	r.CanvasGui = playerGui:WaitForChild("CanvasGui", GUI_TIMEOUT)
	r.EmojiGui  = playerGui:WaitForChild("EmojiGui",  GUI_TIMEOUT)

	if not r.CanvasGui then warn("[RefsBuilder] FATAL: CanvasGui missing") end
	if not r.EmojiGui  then warn("[RefsBuilder] FATAL: EmojiGui missing")  end

	if not (r.CanvasGui and r.EmojiGui) then
		return nil
	end

	-- All in-game panels now live under CanvasGui > MainFrame.
	r.MainFrame = waitForChain(r.CanvasGui, { "MainFrame" }, "FATAL")
	if not r.MainFrame then
		warn("[RefsBuilder] FATAL: CanvasGui.MainFrame missing")
		return nil
	end

	-- Workspace
	local gamePlay = waitForChain(workspace, { "Map", "GamePlay" }, "FATAL")
	if not gamePlay then return nil end

	r.cameraPart        = gamePlay:WaitForChild("CamPart",            GUI_TIMEOUT)
	r.SpawnLocation     = gamePlay:WaitForChild("SpawnLocation",      GUI_TIMEOUT)
	r.SubjectPart       = gamePlay:WaitForChild("SubjectPart",        GUI_TIMEOUT)
	r.SubjectReleasePart = gamePlay:WaitForChild("SubjectReleasePart", GUI_TIMEOUT)

	local displayPart    = waitForChain(gamePlay, { "Screen", "DisplayPart" }, "FATAL")

	if not r.cameraPart         then warn("[RefsBuilder] FATAL: CamPart missing")            end
	if not r.SpawnLocation      then warn("[RefsBuilder] FATAL: SpawnLocation missing")      end
	if not r.SubjectPart        then warn("[RefsBuilder] FATAL: SubjectPart missing")        end
	if not r.SubjectReleasePart then warn("[RefsBuilder] FATAL: SubjectReleasePart missing") end
	if not displayPart         then warn("[RefsBuilder] FATAL: Screen.DisplayPart missing")end

	if not (r.cameraPart and r.SpawnLocation and r.SubjectPart and r.SubjectReleasePart and displayPart) then
		return nil
	end

	r._gamePlay   = gamePlay
	r._displayPart = displayPart
	return r
end

--------------------------------------------------------------------------------
-- Required Batch  (missing = warn + continue, game still launches)
--------------------------------------------------------------------------------

local function loadRequiredRefs(r, playerGui)
	r.PhaseGui  = waitForRequired(playerGui, "PhaseGui",  "required")
	r.Sounds    = waitForRequired(playerGui, "Voices",    "required")

	r.CanvasLabel = waitForRequired(r.MainFrame, "CanvasLabel", "required")
	r.TimerLabel  = waitForChain(r.MainFrame, { "TimerFrame", "TimerLabel" }, "required")
	r.ThemeLabel  = waitForChain(r.MainFrame, { "ThemeFrame", "ThemeLabel" }, "required")
	local PhaseFrame = r.PhaseGui and waitForRequired(r.PhaseGui, "PhaseFrame", "required")
	r.PhaseInfo  = PhaseFrame and waitForRequired(PhaseFrame, "PhaseInfo", "required")
	r.ExtraInfo  = PhaseFrame and waitForRequired(PhaseFrame, "ExtraInfo", "required")
	r.EmojiMainFrame = waitForRequired(r.EmojiGui, "MainFrame", "required")
	r.ClickSound  = r.Sounds and waitForRequired(r.Sounds, "ClickSound", "required")
	r.LoopSound   = r.Sounds and waitForRequired(r.Sounds, "LoopSound",  "required")

	r.EmojiButtonArea = r.EmojiMainFrame and waitForRequired(r.EmojiMainFrame, "ButtonsFrame", "required")

	local displaySurface = r._displayPart and waitForRequired(r._displayPart, "SurfaceGui", "required")
	r._displaySurface    = displaySurface
	r.displayLabel       = displaySurface and waitForRequired(displaySurface, "Image", "required")

	r.emojiLayer = displaySurface and waitForOptional(displaySurface, "EmojiLayer")

	-- Frame: the single authored ImageLabel that draws the equipped frame's border around
	-- the drawing (FrameController sets its Image/Position/Size/Visible at reveal time). It
	-- sits under the SurfaceGui alongside the drawing "Image" (ImageLabel) and the
	-- "EmojiLayer" (a Frame container). Optional: a missing Frame must not block boot, so
	-- FrameController stays inert (shows nothing) without it.
	r.frameLabel = displaySurface and waitForOptional(displaySurface, "Frame")

end

--------------------------------------------------------------------------------
-- Optional Batch  (cosmetic / non-blocking)
--------------------------------------------------------------------------------

local function loadOptionalRefs(r, playerGui)
	-- SidebarGui gates StarCount and the subject panel; a timed wait (not a bare
	-- FindFirstChild) avoids missing it before it replicates to PlayerGui at boot, and
	-- the warn surfaces a missing sidebar instead of silently disabling those features.
	r.SidebarGui = playerGui:WaitForChild("SidebarGui", GUI_TIMEOUT)
	if not r.SidebarGui then
		warn("[RefsBuilder] SidebarGui missing - StarCount and subject panel will not show")
	end

	-- Sidebar Container + the frames the tutorial hides (MarketFrame stays visible, so it is
	-- not grabbed here). TutorialController toggles their Visible while Step-1 is up and
	-- restores it on close. All optional so a missing sidebar never blocks boot.
	r.SidebarContainer = r.SidebarGui
		and waitForChain(r.SidebarGui, { "Container" }, "optional")
	r.SidebarStarFrame    = r.SidebarContainer and waitForOptional(r.SidebarContainer, "StarFrame")
	r.SidebarSubjectFrame = r.SidebarContainer and waitForOptional(r.SidebarContainer, "SubjectFrame")
	r.SidebarInviteFrame  = r.SidebarContainer and waitForOptional(r.SidebarContainer, "InviteFrame")

	-- StarFrame > StarCount: the label that mirrors the player's Star balance.
	-- Server-driven over StarRemote; optional so a missing sidebar never blocks boot.
	r.StarCountLabel = r.SidebarStarFrame and waitForOptional(r.SidebarStarFrame, "StarCount")

	-- SubjectFrame: the lobby subject-guarantee panel (SubjectController). ChanceLabel/
	-- ChanceBar mirror the player's weighted odds of being next subject (server-driven
	-- over SubjectChanceRemote); SubjectButton opens the Robux purchase prompt. Optional
	-- so a missing panel never blocks boot; the feature just stays hidden/inert.
	local subjectFrame = r.SidebarGui
		and waitForChain(r.SidebarGui, { "Container", "SubjectFrame" }, "optional")
	local chanceFrame = subjectFrame and waitForChain(subjectFrame, { "ChanceFrame" }, "optional")
	r.SubjectChanceLabel = chanceFrame and waitForOptional(chanceFrame, "ChanceLabel")
	r.SubjectChanceBar   = chanceFrame and waitForOptional(chanceFrame, "ChanceBar")
	r.SubjectButton      = subjectFrame and waitForOptional(subjectFrame, "SubjectButton")

	-- ResultGui: per-round reaction-count screen for the local player's drawing,
	-- driven by ResultController over ResultRemote. Optional so a missing GUI never
	-- blocks boot; its own Enabled state is managed by the controller. Uses a timed
	-- wait (not FindFirstChild) because the GUI may not have replicated to PlayerGui
	-- yet at boot; a bare lookup could miss it and silently disable the result screen.
	r.ResultGui = waitForOptional(playerGui, "ResultGui")

	-- MarketGui: the shop screen opened from the sidebar MarketButton. Closed at boot
	-- (see RefsBuilder.build) and toggled open by UIController. Optional so a missing
	-- GUI never blocks boot; the market button simply does nothing if it is absent.
	r.MarketGui = waitForOptional(playerGui, "MarketGui")

	-- FrameArea (Container > FrameArea) holds the authored, number-prefixed frame cards
	-- (1Cute, 2Gold, ... 6CardBoard; the prefix keeps the UIGridLayout ordered) directly as
	-- its children. Each card is a Frame with a ButtonFrame > StarButton (Star buy) and, for
	-- the premium frames, a RobuxButton (Game Pass buy). MarketController binds those cards in
	-- place (no dynamic cloning). Optional so a missing market never blocks boot; the frame
	-- cards just stay unbound.
	r.MarketFramesScreen = r.MarketGui
		and waitForChain(r.MarketGui, { "Container", "FrameArea" }, "optional")

	-- PassGui: the phase-transition screen shown briefly when a new visible stage
	-- begins (PassController). Closed at boot; optional so a missing GUI never
	-- blocks boot and transitions simply do not show. SkipFrame is a CanvasGroup so
	-- PassController can fade the whole screen as one via its GroupTransparency.
	r.PassGui = waitForOptional(playerGui, "PassGui")
	r.PassFrame = r.PassGui and waitForChain(r.PassGui, { "SkipFrame" }, "optional")
	r.PassPhaseLabel = r.PassFrame
		and waitForChain(r.PassFrame, { "Mid", "PhaseLabel" }, "optional")

	-- RevealCam: the fixed camera the client locks to during the reveal (Sceneography
	-- :SetRevealCamera). Optional so a missing part never blocks boot; the reveal then
	-- just keeps the player's free camera as before.
	r.revealCamPart = r._gamePlay
		and waitForChain(r._gamePlay, { "Reveal", "RevealCam" }, "optional")

	-- TutorialGui: the one-step tutorial shown after the player's first finished round
	-- (TutorialController). Closed at boot; optional so a missing GUI never blocks boot and
	-- the tutorial simply does not show.
	r.TutorialGui = waitForOptional(playerGui, "TutorialGui")
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

local RefsBuilder = {}

function RefsBuilder.build(playerGui)
	local LoadingGui = playerGui:WaitForChild("LoadingGui", GUI_TIMEOUT)
	if not LoadingGui then
		warn("[RefsBuilder] LoadingGui missing - cannot show loading screen")
		return nil
	end
	local LoadingText = LoadingGui:WaitForChild("LoadingText", GUI_TIMEOUT)
	LoadingGui.Enabled = true

	local refs       = nil
	local uiReady    = false
	local timerDone  = false
	local loadFailed = false

	task.spawn(function()
		local ok, err = pcall(function()
			local fatal = loadFatalRefs(playerGui)
			if not fatal then
				loadFailed = true
				return
			end

			-- Close all GUIs immediately so nothing is visible during loading.
			fatal.CanvasGui.Enabled = false
			fatal.EmojiGui.Enabled  = false

			loadRequiredRefs(fatal, playerGui)
			loadOptionalRefs(fatal, playerGui)

			if fatal.PhaseGui      then fatal.PhaseGui.Enabled      = false end
			if fatal.SidebarGui   then fatal.SidebarGui.Enabled   = false end
			if fatal.MarketGui    then fatal.MarketGui.Enabled    = false end
			if fatal.PassGui      then fatal.PassGui.Enabled      = false end
			if fatal.TutorialGui  then fatal.TutorialGui.Enabled  = false end

			-- CreateEditableImage returns nil (no error) when the session hits its
			-- EditableImage budget. A nil image leaves the display ImageLabel showing
			-- its authored texture (black), so the reveal/gallery surface stays blank.
			-- Guard it: warn loudly and skip the binding rather than erroring boot on
			-- Content.fromObject(nil) / DrawRenderer.clear(nil).
			local canvasSize = Vector2.new(Constants.CANVAS_SIZE, Constants.CANVAS_SIZE)
			local okImage, image = pcall(function()
				return AssetService:CreateEditableImage({ Size = canvasSize })
			end)
			fatal.displayEditableImage = okImage and image or nil
			if not fatal.displayEditableImage then
				warn("[RefsBuilder] CreateEditableImage failed (nil/over budget); reveal & gallery display will stay blank -", tostring(image))
			elseif fatal.displayLabel then
				fatal.displayLabel.Image        = ""
				fatal.displayLabel.ImageContent = Content.fromObject(fatal.displayEditableImage)
				fatal.displayLabel.ScaleType    = Enum.ScaleType.Stretch
				fatal.displayLabel.ResampleMode = Enum.ResamplerMode.Default
				DrawRenderer.clear(fatal.displayEditableImage)
			end

			fatal.camera = workspace.CurrentCamera

			local toPreload = {}
			local function queueButton(btn)
				if btn:IsA("ImageButton") and btn.Image ~= "" then
					table.insert(toPreload, btn)
				end
			end

			if fatal.EmojiButtonArea then
				for _, btn in ipairs(fatal.EmojiButtonArea:GetChildren()) do
					queueButton(btn)
				end
			end
			local bottomPanel = fatal.MainFrame:FindFirstChild("BottomPanel")
			local ToolFrame   = bottomPanel and bottomPanel:FindFirstChild("ToolsFrame")
			if ToolFrame then
				for _, btn in ipairs(ToolFrame:GetDescendants()) do
					queueButton(btn)
				end
			end
			if #toPreload > 0 then
				-- Preload is a best-effort cache warm-up; icons still load on demand
				-- if it fails. Studio routinely returns Failure for valid assets, so
				-- only log on a live server. PreloadAsync retries each asset, firing
				-- the callback repeatedly per asset, which previously spammed one warn
				-- per attempt (tens of thousands under flaky CDN). Count distinct failed
				-- assets instead and emit a single summary line after preload returns.
				local logFailures = not RunService:IsStudio()
				local failedAssets = {}
				local failedCount  = 0
				ContentProvider:PreloadAsync(toPreload, function(assetId, status)
					if status ~= Enum.AssetFetchStatus.Success and not failedAssets[assetId] then
						failedAssets[assetId] = true
						failedCount += 1
					end
				end)
				if logFailures and failedCount > 0 then
					warn(string.format("[RefsBuilder] PreloadAsync: %d/%d asset(s) failed to preload (icons load on demand)", failedCount, #toPreload))
				end
			end

			refs    = fatal
			uiReady = true
		end)

		if not ok then
			warn("[RefsBuilder] Unexpected error during load:", err)
			loadFailed = true
		end
	end)

	task.spawn(function()
		task.wait(Constants.LOADING_DURATION)
		timerDone = true
	end)

	do
		local dots     = { ".", "..", "..." }
		local dotIndex = 0
		while not loadFailed and not (uiReady and timerDone) do
			dotIndex         = (dotIndex % 3) + 1
			LoadingText.Text = "Game Loading" .. dots[dotIndex]
			task.wait(0.75)
		end
	end

	if loadFailed then
		LoadingText.Text = "Game failed to load. Please rejoin."
		return nil
	end

	LoadingGui.Enabled = false
	if refs.PhaseGui then
		refs.PhaseGui.Enabled = true
		if refs.PhaseInfo then refs.PhaseInfo.Text = "Waiting for players" end
		if refs.ExtraInfo then refs.ExtraInfo.Text = "" end
	end
	if refs.SidebarGui then refs.SidebarGui.Enabled = true end
	if refs.LoopSound then
		refs.LoopSound.Looped = true
		refs.LoopSound:Play()
	end

	return refs
end

return RefsBuilder
