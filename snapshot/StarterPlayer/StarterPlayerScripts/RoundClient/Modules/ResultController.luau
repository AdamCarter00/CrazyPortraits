--[[
ResultController
----------------
Shows the per-round result screen for the LOCAL player's drawing. The server (Round)
is the source of truth: at round end it sends this player's result over ResultRemote,
but only if their drawing was actually revealed — so a player with no drawing never
gets a payload and the GUI stays hidden.

Payload (from the server):
  { tally = { [emojiId] = count }, emojiStars = number, roundStars = number }
    tally      -> per-type reaction counts (laugh / skull / shocked)
    emojiStars -> Stars earned from those reactions (count * per-reaction)
    roundStars -> Stars earned just for finishing the round (the base reward)

Sequence (durations in Constants):
  1. EmojiContainer shows the reaction counts for RESULT_EMOJI_VIEW_DURATION,
  2. EmojiContainer fades out over RESULT_CONTAINER_FADE_DURATION,
  3. StarContainer shows the Star breakdown for RESULT_STAR_VIEW_DURATION,
  4. the whole ResultFrame fades out over RESULT_FADE_DURATION, then the GUI disables.
When the drawing got no reactions (empty tally), steps 1-2 are skipped and the GUI
opens straight on the StarContainer (step 3).
A new payload (or a DRAWING_PHASE hide) bumps renderToken, cancelling the sequence.

UI layout (set up manually in Studio):
  PlayerGui.ResultGui                 -> Enabled toggled by this controller
    ResultFrame                       -> faded out as a whole at the end
      EmojiContainer                  -> shown first, then faded out
        LaughFrame / SkullFrame / ShockedFrame
          Count  (TextLabel)          -> number of that reaction
      StarContainer                   -> shown after the emoji step
        EmojiScore / RoundScore
          Count  (TextLabel)          -> Stars from reactions / Stars from the round
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))

local CHAIN_WAIT = Constants.GUI_TIMEOUT

-- emoji id (as sent by the server / Studio button name) -> Studio frame name.
local FRAME_BY_EMOJI = {
	laugh   = "LaughFrame",
	skull   = "SkullFrame",
	shocked = "ShockedFrame",
}

-- Per-class transparency properties faded to 1 (and restored from a cache on show).
local FADE_PROPS = {
	GuiObject   = "BackgroundTransparency",
	TextLabel   = "TextTransparency",
	TextButton  = "TextTransparency",
	ImageLabel  = "ImageTransparency",
	ImageButton = "ImageTransparency",
	UIStroke    = "Transparency",
}

local ResultController = {}

local gui            = nil
local resultFrame    = nil
local emojiContainer = nil
local starContainer  = nil
-- [emojiId] = Count TextLabel (under EmojiContainer)
local emojiCounts = {}
-- Star breakdown Count labels (under StarContainer)
local emojiScoreCount = nil
local roundScoreCount = nil
-- Fade-target lists: { instance, prop, value } captured once so a fade is reversible.
-- frameTargets covers the whole ResultFrame (final fade); the per-container lists are
-- subsets used for the mid-sequence EmojiContainer fade.
local frameTargets = {}
local emojiTargets = {}
-- Bumped on every Render so a running sequence knows it has been superseded.
local renderToken = 0
-- Callbacks fired when a "You Got" sequence finishes IN FULL (hideAndReset). Not fired on
-- cancellation (a new render / DRAWING_PHASE hide), so a listener (TutorialController) learns
-- exactly when the fade-out has truly ended. Each is fired once then dropped.
local sequenceCompleteCallbacks = {}

--------------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------------

-- Collects every faded property under `root` (with its authored value) into `out`.
local function captureInto(out, root)
	local function consider(inst, prop)
		if prop and (inst[prop] ~= nil) then
			table.insert(out, { inst = inst, prop = prop, value = inst[prop] })
		end
	end
	-- The root's own background, then every descendant by class.
	if root:IsA("GuiObject") then
		consider(root, FADE_PROPS.GuiObject)
	end
	for _, inst in ipairs(root:GetDescendants()) do
		if inst:IsA("UIStroke") then
			consider(inst, FADE_PROPS.UIStroke)
		elseif inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
			consider(inst, FADE_PROPS.ImageLabel)
			consider(inst, FADE_PROPS.GuiObject)
		elseif inst:IsA("TextLabel") or inst:IsA("TextButton") then
			consider(inst, FADE_PROPS.TextLabel)
			consider(inst, FADE_PROPS.GuiObject)
		elseif inst:IsA("GuiObject") then
			consider(inst, FADE_PROPS.GuiObject)
		end
	end
end

function ResultController:Init(resultGui)
	if not resultGui then
		warn("[ResultController] Init: ResultGui missing; results will not show")
		return
	end
	gui = resultGui
	gui.Enabled = false

	resultFrame = gui:WaitForChild("ResultFrame", CHAIN_WAIT)
	if not resultFrame then
		warn("[ResultController] Init: ResultFrame missing")
		return
	end

	emojiContainer = resultFrame:WaitForChild("EmojiContainer", CHAIN_WAIT)
	if emojiContainer then
		for emojiId, frameName in pairs(FRAME_BY_EMOJI) do
			local frame = emojiContainer:WaitForChild(frameName, CHAIN_WAIT)
			emojiCounts[emojiId] = frame and frame:WaitForChild("Count", CHAIN_WAIT)
			if not emojiCounts[emojiId] then
				warn("[ResultController] Init: Count label missing under", frameName)
			end
		end
	else
		warn("[ResultController] Init: ResultFrame.EmojiContainer missing")
	end

	starContainer = resultFrame:WaitForChild("StarContainer", CHAIN_WAIT)
	if starContainer then
		local emojiScore = starContainer:WaitForChild("EmojiScore", CHAIN_WAIT)
		local roundScore = starContainer:WaitForChild("RoundScore", CHAIN_WAIT)
		emojiScoreCount = emojiScore and emojiScore:WaitForChild("Count", CHAIN_WAIT)
		roundScoreCount = roundScore and roundScore:WaitForChild("Count", CHAIN_WAIT)
		if not (emojiScoreCount and roundScoreCount) then
			warn("[ResultController] Init: EmojiScore/RoundScore Count label missing")
		end
	else
		warn("[ResultController] Init: ResultFrame.StarContainer missing")
	end

	captureInto(frameTargets, resultFrame)
	if emojiContainer then
		captureInto(emojiTargets, emojiContainer)
	end
end

--------------------------------------------------------------------------------
-- Fade helpers
--------------------------------------------------------------------------------

-- Snaps every property in `targets` back to its authored value.
local function restore(targets)
	for _, t in ipairs(targets) do
		t.inst[t.prop] = t.value
	end
end

-- Tweens every property in `targets` to fully transparent over `duration`.
local function fadeOut(targets, duration)
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, t in ipairs(targets) do
		TweenService:Create(t.inst, info, { [t.prop] = 1 }):Play()
	end
end

local function hideAndReset()
	if gui then gui.Enabled = false end
	restore(frameTargets)
	if emojiContainer then emojiContainer.Visible = true end
	if starContainer then starContainer.Visible = false end
end

-- Drains the one-shot completion callbacks. Called only at the natural end of a full
-- sequence (after the final fade-out), never on cancellation, so a listener learns the
-- "You Got" fade has truly finished.
local function fireSequenceComplete()
	if #sequenceCompleteCallbacks == 0 then return end
	local pending = sequenceCompleteCallbacks
	sequenceCompleteCallbacks = {}
	for _, fn in ipairs(pending) do
		task.spawn(fn)
	end
end

--------------------------------------------------------------------------------
-- Render
--------------------------------------------------------------------------------

-- result: { tally = { [emojiId]=count }, emojiStars, roundStars } for the local
-- player's drawing, or nil to hide. A missing emoji key means zero of that reaction.
function ResultController:Render(result)
	if not gui then return end

	-- Any new call (hide or show) invalidates a sequence that may be in flight.
	renderToken += 1

	if typeof(result) ~= "table" then
		hideAndReset()
		return
	end

	local tally = typeof(result.tally) == "table" and result.tally or {}
	local hasReactions = next(tally) ~= nil
	for emojiId, label in pairs(emojiCounts) do
		if label then
			label.Text = tostring(tally[emojiId] or 0)
		end
	end
	if emojiScoreCount then emojiScoreCount.Text = tostring(result.emojiStars or 0) end
	if roundScoreCount then roundScoreCount.Text = tostring(result.roundStars or 0) end

	restore(frameTargets)
	gui.Enabled = true

	local myToken = renderToken
	local function stillCurrent()
		return myToken == renderToken
	end

	-- StarContainer step + final fade. Shared so the emoji step can chain into it, or
	-- it can run directly when there are no reactions to show.
	local function showStarThenClose()
		if emojiContainer then emojiContainer.Visible = false end
		if starContainer then starContainer.Visible = true end

		task.delay(Constants.RESULT_STAR_VIEW_DURATION, function()
			if not stillCurrent() then return end
			fadeOut(frameTargets, Constants.RESULT_FADE_DURATION)
			task.delay(Constants.RESULT_FADE_DURATION, function()
				if not stillCurrent() then return end
				hideAndReset()
				fireSequenceComplete()
			end)
		end)
	end

	-- No reactions: skip the EmojiContainer entirely and open straight on StarContainer.
	if not hasReactions then
		showStarThenClose()
		return
	end

	-- Reactions present: EmojiContainer at full opacity first, then fade it out and
	-- hand off to the StarContainer step.
	if emojiContainer then emojiContainer.Visible = true end
	if starContainer then starContainer.Visible = false end

	task.delay(Constants.RESULT_EMOJI_VIEW_DURATION, function()
		if not stillCurrent() then return end

		fadeOut(emojiTargets, Constants.RESULT_CONTAINER_FADE_DURATION)

		task.delay(Constants.RESULT_CONTAINER_FADE_DURATION, function()
			if not stillCurrent() then return end
			showStarThenClose()
		end)
	end)
end

--------------------------------------------------------------------------------
-- Sequence hooks (read by TutorialController)
--------------------------------------------------------------------------------

-- True while a "You Got" sequence is on screen, so a caller can decide whether to wait for
-- its completion or act immediately.
function ResultController:IsActive()
	return gui ~= nil and gui.Enabled
end

-- Registers a ONE-SHOT callback fired when the current/next full sequence finishes its
-- fade-out (not on cancellation). It is dropped after firing, so re-register to listen again.
function ResultController:OnSequenceComplete(fn)
	if typeof(fn) == "function" then
		table.insert(sequenceCompleteCallbacks, fn)
	end
end

return ResultController
