local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DrawRenderer = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("DrawRenderer"))
local StrokeCodec  = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("StrokeCodec"))

local Sceneography = {}
Sceneography.__index = Sceneography

function Sceneography.new(refs)
	return setmetatable({ refs = refs }, Sceneography)
end

--------------------------------------------------------------------------------
-- Camera
--------------------------------------------------------------------------------

function Sceneography:SetCinematicCamera()
	local refs = self.refs
	refs.camera.CameraType = Enum.CameraType.Scriptable
	refs.camera.CFrame     = refs.cameraPart.CFrame
end

function Sceneography:SetRevealCamera()
	local refs = self.refs
	if not refs.revealCamPart then
		-- RevealCam missing (RefsBuilder warned): leave the camera as-is rather than
		-- snapping to a nil CFrame, so the reveal still plays with the free camera.
		return
	end
	refs.camera.CameraType = Enum.CameraType.Scriptable
	refs.camera.CFrame     = refs.revealCamPart.CFrame
end

function Sceneography:SetFreeCamera()
	self.refs.camera.CameraType = Enum.CameraType.Custom
end

--------------------------------------------------------------------------------
-- UI
--------------------------------------------------------------------------------

function Sceneography:HideAllUI()
	local refs = self.refs
	refs.CanvasGui.Enabled   = false
	refs.EmojiGui.Enabled    = false
	refs.TimerLabel.Text       = ""
	refs.TimerLabel.Visible    = false
	refs.TimerLabel.TextColor3 = Color3.new(1, 1, 1)
	refs.ThemeLabel.Text     = ""
	refs.ThemeLabel.Visible  = false
end

-- Disables every ScreenGui under PlayerGui except the canvas, so the drawing phase
-- shows a clean full-screen canvas. PassGui is skipped: this runs behind the live
-- transition curtain, which PassController fades out on its own schedule -- forcing
-- it off here would pop a half-built scene into view.
function Sceneography:HideAllGuisExceptCanvas()
	local canvasGui = self.refs.CanvasGui
	local passGui   = self.refs.PassGui
	for _, gui in ipairs(canvasGui.Parent:GetChildren()) do
		if gui:IsA("ScreenGui") and gui ~= canvasGui and gui ~= passGui then
			gui.Enabled = false
		end
	end
end

--------------------------------------------------------------------------------
-- PhaseGui
--------------------------------------------------------------------------------

function Sceneography:SetPhaseInfo(mainText, extraText)
	local refs = self.refs
	if refs.PhaseInfo then refs.PhaseInfo.Text = mainText or "" end
	if refs.ExtraInfo then refs.ExtraInfo.Text = extraText or "" end
end

function Sceneography:ShowPhaseGui(mainText, extraText)
	if self.refs.PhaseGui then self.refs.PhaseGui.Enabled = true end
	self:SetPhaseInfo(mainText, extraText)
end

function Sceneography:HidePhaseGui()
	if self.refs.PhaseGui then self.refs.PhaseGui.Enabled = false end
end

--------------------------------------------------------------------------------
-- Display
--------------------------------------------------------------------------------

function Sceneography:RenderDrawing(drawingBuffer)
	local image = self.refs.displayEditableImage
	if not image then
		warn("[Sceneography] RenderDrawing: displayEditableImage missing; reveal surface stays blank")
		return
	end
	local strokes = (typeof(drawingBuffer) == "buffer") and StrokeCodec.decode(drawingBuffer) or {}
	DrawRenderer.render(image, strokes)
end

function Sceneography:ClearDisplay()
	local image = self.refs.displayEditableImage
	if image then DrawRenderer.clear(image) end
end


--------------------------------------------------------------------------------
-- Audio
--------------------------------------------------------------------------------

function Sceneography:PlaySound(soundName)
	local sound = self.refs.Sounds:FindFirstChild(soundName)
	if sound then sound:Play() end
end

return Sceneography
