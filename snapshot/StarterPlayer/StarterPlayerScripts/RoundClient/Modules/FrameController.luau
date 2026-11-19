--[[
FrameController
---------------
Swaps the cosmetic border (frame) around the reveal display to match the drawing owner's
equipped frame. The border is a single authored ImageLabel named "Frame" that lives under
Screen.DisplayPart > SurfaceGui, alongside the drawing "Image" (ImageLabel) and the
"EmojiLayer" (a Frame container); there is no clone and no ReplicatedStorage.Frames folder.
"default" means no frame at all (the Frame ImageLabel is hidden, leaving the bare drawing).

Apply(frameName) points the Frame ImageLabel at the named frame: it sets the Image /
Position / Size from Constants.FRAME_DISPLAY and shows it. A default / unknown / nil name
hides it. Clear() hides it again. Both are no-ops when the Frame ref is missing, so a missing
setup never blocks the reveal.

Equipped-frame source is temporary: FrameNameFor reads an attribute off the owning Player
(see Constants.FRAME_EQUIP_ATTRIBUTE). When the shop/ownership data reaches the reveal, only
FrameNameFor changes to read the server payload.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))

local FrameController = {}
FrameController.__index = FrameController

function FrameController.new(refs)
	-- The Frame ImageLabel is optional (authored in Studio): without it every owner falls
	-- back to no frame.
	local frameLabel = refs and refs.frameLabel
	if not frameLabel then
		warn("[FrameController] SurfaceGui.Frame missing; no frames will show")
	end

	return setmetatable({
		refs       = refs,
		frameLabel = frameLabel,
	}, FrameController)
end

-- Resolves the frame id for a drawing owner. Temporary: reads an attribute off the
-- owning Player. Returns DEFAULT_FRAME_NAME when the player or attribute is absent.
function FrameController:FrameNameFor(playerName)
	local player = playerName and Players:FindFirstChild(playerName)
	local equipped = player and player:GetAttribute(Constants.FRAME_EQUIP_ATTRIBUTE)
	if typeof(equipped) == "string" and equipped ~= "" then
		return equipped
	end
	return Constants.DEFAULT_FRAME_NAME
end

-- Points the authored "Frame" ImageLabel at the owner's equipped frame. A known frame id
-- shows the ImageLabel with that frame's Image / Position / Size (from FRAME_DISPLAY).
-- default / nil / unknown hides it, leaving the bare drawing. Inert if the ref is missing.
-- The single label is just reconfigured each call, so moving to the next owner swaps frames
-- automatically (no leftover clone to clear).
function FrameController:Apply(frameName)
	local label = self.frameLabel
	if not label then return end

	local entry = frameName
		and frameName ~= Constants.DEFAULT_FRAME_NAME
		and Constants.FRAME_DISPLAY[frameName]

	if not entry then
		if frameName and frameName ~= Constants.DEFAULT_FRAME_NAME then
			warn("[FrameController] Unknown frame '" .. tostring(frameName) .. "'; showing none")
		end
		label.Visible = false
		return
	end

	label.Image    = entry.image
	label.Position = entry.position
	label.Size     = entry.size
	label.Visible  = true
end

-- Hides the frame border. Called when the reveal ends so the scene is left on the bare
-- drawing with no leftover border.
function FrameController:Clear()
	if self.frameLabel then
		self.frameLabel.Visible = false
	end
end

return FrameController
