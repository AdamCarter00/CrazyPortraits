--[[
PassController
--------------
Shows a brief phase-transition screen (PlayerGui.PassGui) when the round moves to
a new visible stage, with PhaseLabel naming the stage. Several internal phases fold
into one visible stage (Constants.PHASE_PASS_LABELS), so Show only re-displays the
screen when the visible name actually changes -- otherwise the same word would flash
back-to-back across the COLLECTING/REVEAL_INTRO/REVEAL phases (all "Reveal").

The very first phase a client sees on join is the stage already in progress, not a
transition into it, so the first Show only records the stage and shows nothing; the
screen appears from the next stage change onward.

Show enables PassGui and fades it in, then the screen stays up until BOTH of two
conditions are met: PASS_DURATION has elapsed AND the scene setup has finished (see
ScheduleSceneSetup). Only then does it fade out and disable. So the screen is never
a hollow placeholder that lifts on a hard-coded timer to reveal a half-built scene;
it behaves like the boot loading curtain (held until the work behind it is done).
PASS_MAX_HOLD caps the wait: if the scene-ready signal never arrives (a bug), the
screen still closes (with a warn) rather than trapping the player behind it. All of
this is guarded by a token (same pattern as WaitingController) so a fast sequence of
stages does not let an earlier transition's close hide a later screen. The fade
tweens GroupTransparency on PassFrame (the SkipFrame CanvasGroup) so the whole
screen fades as one; if it is not a CanvasGroup the screen just hard toggles.

ScheduleSceneSetup(callback) runs the caller's scene setup (camera/CanvasGui on the
client) PASS_SETUP_DELAY after the screen opened -- so it happens behind the fully
shown screen rather than racing the fade-in -- and marks the scene ready when the
callback returns (setup is synchronous: it completes within the frame). But only if
the last Show actually displayed the screen this transition. If it did not (first
stage on join, or no CanvasGroup / no PassGui), the callback runs immediately and
no screen is involved, so the scene is never needlessly delayed.

The whole controller is a no-op when PassGui is missing (RefsBuilder already warns),
so a missing GUI never blocks the round.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))

local FADE_INFO = TweenInfo.new(Constants.PASS_FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local PassController = {}
PassController.__index = PassController

function PassController.new(refs)
	return setmetatable({
		refs          = refs,
		_lastLabel    = nil,
		_seenFirst    = false,
		_token        = 0,
		_shown        = false, -- did the last Show actually display the screen?
		_durationDone = false, -- has PASS_DURATION elapsed for the current screen?
		_sceneReady   = false, -- has the scene setup for the current screen finished?
		_fadeTween    = nil,   -- the in-flight GroupTransparency tween (fade in OR out)
	}, PassController)
end

-- Starts a GroupTransparency tween (fade in or out), first cancelling any tween still
-- in flight from a previous transition. Without this cancel, a fast Reveal->Lobby
-- sequence lets the prior fade-out keep driving GroupTransparency while the new fade-in
-- runs on the same property -- the two race and the fade-in is intermittently swallowed,
-- so the screen pops in fully opaque some of the time. Cancelling makes the new fade the
-- sole writer; the caller sets the start value right before calling.
function PassController:_startFade(frame, target)
	if self._fadeTween then
		self._fadeTween:Cancel()
	end
	self._fadeTween = TweenService:Create(frame, FADE_INFO, { GroupTransparency = target })
	self._fadeTween:Play()
end

function PassController:Show(phase)
	self._shown = false

	local gui = self.refs.PassGui
	if not gui then return end

	local label = Constants.PHASE_PASS_LABELS[phase]
	if not label or label == self._lastLabel then return end
	self._lastLabel = label

	-- First stage on join is already in progress, not a transition: record only.
	if not self._seenFirst then
		self._seenFirst = true
		return
	end

	self._token += 1
	local token = self._token
	self._shown        = true
	self._durationDone = false
	-- Default to ready: only a transition whose controller calls ScheduleSceneSetup
	-- (Drawing) has a scene to wait for and flips this to false there. A transition
	-- that does not (Reveal, which relies on the server's intro hold instead) stays
	-- ready, so it closes on PASS_DURATION alone rather than stalling to PASS_MAX_HOLD.
	self._sceneReady   = true

	if self.refs.PassPhaseLabel then
		self.refs.PassPhaseLabel.Text = label
	end

	-- Fade the whole screen as one via the SkipFrame CanvasGroup; without it the
	-- screen just hard toggles with PassGui.Enabled below.
	local frame = self.refs.PassFrame
	local fades = frame ~= nil and frame:IsA("CanvasGroup")
	if fades then
		-- Cancel any in-flight fade first, THEN pin to fully transparent: a still-running
		-- fade-out from the previous transition would otherwise keep writing
		-- GroupTransparency and race this fade-in (see _startFade).
		if self._fadeTween then
			self._fadeTween:Cancel()
		end
		frame.GroupTransparency = 1
	end
	gui.Enabled = true
	if fades then
		self:_startFade(frame, 0)
	end

	-- One of the two close conditions. The screen does not close here on its own;
	-- it closes once the scene is also ready (see _tryClose / ScheduleSceneSetup).
	task.delay(Constants.PASS_DURATION, function()
		if self._token ~= token then return end
		self._durationDone = true
		self:_tryClose(token)
	end)

	-- Safety cap: if the scene-ready signal never arrives, close anyway so the
	-- player is not trapped behind the screen. _tryClose ignores a stale token, so
	-- this is a no-op if the screen already closed normally.
	task.delay(Constants.PASS_MAX_HOLD, function()
		if self._token ~= token then return end
		if not self._sceneReady then
			warn("[PassController] scene-ready timed out after PASS_MAX_HOLD; closing screen anyway")
		end
		self._durationDone = true
		self._sceneReady   = true
		self:_tryClose(token)
	end)
end

-- Closes the screen only when BOTH PASS_DURATION has elapsed and the scene is
-- ready, and only for the current transition (stale token = a newer Show already
-- took over). Fades out via the CanvasGroup, or hard toggles if there is none.
function PassController:_tryClose(token)
	if self._token ~= token then return end
	if not (self._durationDone and self._sceneReady) then return end

	local gui = self.refs.PassGui
	if not gui then return end

	local frame = self.refs.PassFrame
	local fades = frame ~= nil and frame:IsA("CanvasGroup")
	if fades then
		self:_startFade(frame, 1)
		task.delay(Constants.PASS_FADE_DURATION, function()
			if self._token == token then
				gui.Enabled = false
			end
		end)
	else
		gui.Enabled = false
	end
end

-- Runs the caller's scene setup behind the shown screen (PASS_SETUP_DELAY after it
-- opened), then marks the scene ready so the screen can close. If the last Show did
-- not display a screen, runs the setup immediately and skips the close bookkeeping
-- (there is nothing to close). Token-guarded so a newer transition cancels a pending
-- setup from an older one. Must be called after the matching Show (RoundClient
-- connects Show before the router dispatch that triggers Enter, so the controller's
-- Enter sees the correct _shown state).
function PassController:ScheduleSceneSetup(callback)
	if not self._shown then
		callback()
		return
	end
	-- This transition has a scene to build, so hold the close until it finishes
	-- (Show defaults _sceneReady to true for transitions that never register one).
	self._sceneReady = false
	local token = self._token
	task.delay(Constants.PASS_SETUP_DELAY, function()
		if self._token ~= token then return end
		callback()
		-- Setup is synchronous, so its return means the scene is built; signal ready
		-- and try to close (waits on PASS_DURATION too, via _tryClose).
		self._sceneReady = true
		self:_tryClose(token)
	end)
end

return PassController
