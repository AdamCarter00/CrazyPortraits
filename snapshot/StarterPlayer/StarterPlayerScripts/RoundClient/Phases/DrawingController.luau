local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))

local SubmitRemote       = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SubmitRemote")
local DrawProgressRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DrawProgressRemote")

local DrawingController = {}
DrawingController.__index = DrawingController

function DrawingController.new(scene, refs, canvasController, passController)
	return setmetatable({
		scene            = scene,
		refs             = refs,
		canvasController = canvasController,
		passController   = passController,
		_roundActive     = false,
		_roundToken      = 0,
		_startTime       = nil,
		_group           = nil,
		_submitted       = false,
		_submitButton    = nil,
		_jumpDisabled    = false,
		_savedJumpPower  = nil,
		_savedUseJumpPower = nil,
		_jumpCharConn    = nil,
	}, DrawingController)
end

--------------------------------------------------------------------------------
-- Jump control (mobile)
--
-- While the canvas is open, the default mobile jump button overlaps the
-- brush-size buttons, so a player drawing on touch keeps jumping by accident.
-- Setting JumpPower = 0 (with UseJumpPower) makes Roblox auto-hide the jump
-- button AND stops the jump; SetStateEnabled(Jumping, false) is a belt-and-
-- braces guard so a keyboard/edge-case jump is blocked too. Both are reverted
-- the moment the canvas closes (submit or phase change).
--
-- A respawn mid-drawing spawns a fresh Humanoid that would re-enable jumping,
-- so while the block is active we also listen for CharacterAdded and re-apply
-- it to the new Humanoid.
--------------------------------------------------------------------------------

local function getLocalHumanoid()
	local character = Players.LocalPlayer.Character
	if not character then return nil end
	return character:FindFirstChildOfClass("Humanoid")
end

-- Pure apply: forces the jump block on whatever Humanoid is passed (the current
-- one, or a freshly spawned one after respawn). Does not touch saved state.
local function applyJumpBlock(humanoid)
	humanoid.UseJumpPower = true
	humanoid.JumpPower    = 0  -- 0 also auto-hides the mobile jump button
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
end

function DrawingController:_disableJump()
	if self._jumpDisabled then return end
	self._jumpDisabled = true

	local humanoid = getLocalHumanoid()
	if humanoid then
		-- Snapshot the original values so they can be restored exactly when the
		-- canvas closes. These are the avatar's configured jump settings, which a
		-- respawn would reset to the same defaults anyway, so reusing them for a
		-- respawned character on restore is correct.
		self._savedUseJumpPower = humanoid.UseJumpPower
		self._savedJumpPower    = humanoid.JumpPower
		applyJumpBlock(humanoid)
	end

	-- Re-apply on respawn so the jump button stays hidden for the whole canvas.
	self._jumpCharConn = Players.LocalPlayer.CharacterAdded:Connect(function(character)
		if not self._jumpDisabled then return end
		local newHumanoid = character:FindFirstChildOfClass("Humanoid")
			or character:WaitForChild("Humanoid", Constants.CHARACTER_WAIT_TIMEOUT)
		if newHumanoid and self._jumpDisabled then
			applyJumpBlock(newHumanoid)
		end
	end)
end

function DrawingController:_restoreJump()
	if not self._jumpDisabled then return end
	self._jumpDisabled = false

	if self._jumpCharConn then
		self._jumpCharConn:Disconnect()
		self._jumpCharConn = nil
	end

	local humanoid = getLocalHumanoid()
	if humanoid then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		if self._savedUseJumpPower ~= nil then
			humanoid.UseJumpPower = self._savedUseJumpPower
		end
		if self._savedJumpPower ~= nil then
			humanoid.JumpPower = self._savedJumpPower
		end
	end

	self._savedJumpPower    = nil
	self._savedUseJumpPower = nil
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

function DrawingController:Enter(theme, startTime, subjectName, group)
	local refs = self.refs

	self._roundActive = true
	self._roundToken += 1
	self._startTime   = startTime
	self._group       = group
	self._submitted   = false
	-- Cleared now (not in the deferred setup below): the timer loop starts immediately
	-- and reads _submitButton, so a stale handle from last round must not linger until
	-- the setup callback reassigns it. The timer only acts on it once elapsed >= delay,
	-- which the PASS_DURATION offset keeps past the callback, but nil-ing here removes
	-- the trap outright instead of relying on that timing.
	self._submitButton = nil
	self.canvasController:ResetProgress()
	-- The timer/reporter loops can run now: startTime is offset into the future, so
	-- the countdown holds at DRAWING_DURATION (clamped in _startTimer) until the
	-- transition screen clears, and the reporter is idle until the player draws.
	self:_startTimer(startTime, self._roundToken)
	self:_startProgressReporter(self._roundToken)

	-- The whole visible swap -- hiding the lobby UI AND building the canvas/camera/
	-- prompt -- runs behind the transition screen so nothing changes under the
	-- screen's fade-in (the lobby countdown was visibly vanishing otherwise). If no
	-- screen showed this transition, ScheduleSceneSetup runs it immediately. Token
	-- guards the round so a phase change before the delay elapses cancels a stale setup.
	local token = self._roundToken
	self.passController:ScheduleSceneSetup(function()
		if self._roundToken ~= token then return end

		-- Clear the canvas-adjacent labels/emoji, then close every other GUI so the
		-- drawing phase is a clean full-screen canvas (PassGui is left for its own fade).
		self.scene:HideAllUI()
		self.scene:HideAllGuisExceptCanvas()

		refs.CanvasGui.Enabled  = true
		refs.TimerLabel.Visible = true
		-- When the local player is the subject, address them directly so the prompt
		-- reads naturally ("Draw yourself like ..."); otherwise name the subject.
		-- The theme "like <theme>" tail is only added for the A/B theme arm: group A
		-- while THEME_ENABLED is on. With the theme system bypassed (THEME_ENABLED false),
		-- or for group B, the prompt is just "Draw <subject>".
		local isSubject = subjectName and subjectName == Players.LocalPlayer.Name
		local useTheme  = Constants.THEME_ENABLED and group ~= "B"
		if useTheme then
			local themeText = theme or ""
			if isSubject then
				refs.ThemeLabel.Text = "Draw yourself like " .. themeText
			else
				refs.ThemeLabel.Text = "Draw " .. (subjectName or "") .. " like " .. themeText
			end
		else
			if isSubject then
				refs.ThemeLabel.Text = "Draw yourself"
			else
				refs.ThemeLabel.Text = "Draw " .. (subjectName or "")
			end
		end
		refs.ThemeLabel.Visible = true

		local mainFrame  = refs.CanvasGui:FindFirstChild("MainFrame")
		local submitFrame = mainFrame and mainFrame:FindFirstChild("SubmitFrame")
		local submitButton = submitFrame and submitFrame:FindFirstChild("SubmitButton")
		if submitButton then
			submitButton.Visible = false
		end
		self._submitButton = submitButton

		self.scene:SetCinematicCamera()

		-- Canvas is now open: kill the mobile jump button so it can't overlap the
		-- brush-size buttons (reverted in Exit / SubmitDraw when the canvas closes).
		self:_disableJump()

		self.canvasController:SetDrawingEnabled(true)
	end)
end

function DrawingController:Exit()
	self._roundActive = false
	-- Phase changed away from drawing (collect/reveal/clean): restore jump.
	self:_restoreJump()
end

function DrawingController:IsRoundActive()
	return self._roundActive
end

function DrawingController:SubmitDraw()
	if not self._submitted and self._startTime then
		self._submitted = true
		-- The server recomputes submit elapsed authoritatively from its own
		-- start time, so no argument is sent (a client value would be ignored).
		SubmitRemote:FireServer()
	end

	self.canvasController:ResetLastPosition()
	local refs = self.refs
	refs.CanvasGui.Enabled = false
	-- Canvas closed on submit: give the jump button back for the waiting phase.
	self:_restoreJump()
	-- The sidebar is hidden for the whole drawing phase (DrawingController:Enter),
	-- then reopened in CollectingController for everyone. A player who submits early
	-- is done drawing, so bring their sidebar back now instead of making them wait
	-- for the phase change.
	if refs.SidebarGui then refs.SidebarGui.Enabled = true end
	self.scene:SetFreeCamera()
	self.canvasController:SetDrawingEnabled(false)
	self.scene:ShowPhaseGui(Constants.TEXT_PHASE_SUBMITTED, "")
end

--------------------------------------------------------------------------------
-- Timer
--------------------------------------------------------------------------------

function DrawingController:_startTimer(startTime, token)
	local refs = self.refs
	task.spawn(function()
		while self._roundActive and self._roundToken == token do
			local elapsed = workspace:GetServerTimeNow() - startTime
			-- startTime is offset PASS_DURATION into the future (server delays the
			-- drawing start for the transition screen), so elapsed is negative until
			-- the screen clears; clamp the top so the countdown holds at DRAWING_DURATION
			-- instead of showing inflated seconds during the transition.
			local remaining = math.clamp(math.ceil(Constants.DRAWING_DURATION - elapsed), 0, Constants.DRAWING_DURATION)
			refs.TimerLabel.Text = Constants.TEXT_TIMER .. remaining

			if self._submitButton and not self._submitButton.Visible
				and elapsed >= Constants.SUBMIT_BUTTON_DELAY then
				self._submitButton.Visible = true
			end

			if self._submitted then
				local mm = math.floor(remaining / Constants.SECONDS_PER_MINUTE)
				local ss = remaining - mm * Constants.SECONDS_PER_MINUTE
				self.scene:SetPhaseInfo(
					Constants.TEXT_PHASE_SUBMITTED,
					string.format("%02d:%02d left", mm, ss)
				)
			end

			if elapsed >= Constants.DRAWING_DURATION then
				refs.TimerLabel.Text = ""
				break
			end

			if remaining <= Constants.TIMER_WARNING_THRESHOLD then
				local blink = math.floor(tick() / Constants.TIMER_BLINK_INTERVAL) % 2 == 0
				refs.TimerLabel.TextColor3 = blink and Constants.TIMER_BLINK_COLOR_ON or Constants.TIMER_BLINK_COLOR_OFF
			end

			task.wait(Constants.TIMER_BLINK_INTERVAL)
		end
	end)
end

--------------------------------------------------------------------------------
-- Progress Reporter
--------------------------------------------------------------------------------

-- Periodically reports the live stroke/undo counts to the server so a player
-- who quits mid-drawing (without submitting) still leaves this data behind.
-- Only sends when a count has changed since the last send, so an idle drawer
-- generates no traffic. A flush at the end covers the last interval.
function DrawingController:_startProgressReporter(token)
	task.spawn(function()
		local lastStrokes, lastUndo = -1, -1
		local function flush()
			local strokes, undo = self.canvasController:GetProgress()
			if strokes ~= lastStrokes or undo ~= lastUndo then
				lastStrokes, lastUndo = strokes, undo
				DrawProgressRemote:FireServer(strokes, undo)
			end
		end

		while self._roundActive and self._roundToken == token do
			flush()
			task.wait(Constants.DRAW_PROGRESS_REPORT_INTERVAL)
		end
		-- Final flush so the last partial interval is not lost on a clean exit.
		if self._roundToken == token then
			flush()
		end
	end)
end

return DrawingController
