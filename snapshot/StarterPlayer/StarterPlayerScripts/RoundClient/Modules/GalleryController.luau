--[[
GalleryController
-----------------
Renders the previous round's drawings onto 8 mini canvases in the lobby, plus the
drawing owner's name under each.

Scene layout (set up manually in Studio):
  workspace.Map.GamePlay.Gallery.GalleryCanvas
    1..8 (Model)
      Canvas (Part)
        BackGround (Part)
          SurfaceGui
            ImageLabel        -- the drawing
        Part (Part)
          SurfaceGui
            TextLabel         -- the owner's name

Each ImageLabel is bound to its own EditableImage at boot and cleared. The server
pushes the gallery via GalleryRemote at round end (and on join).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AssetService      = game:GetService("AssetService")

local Constants    = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local StrokeCodec  = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("StrokeCodec"))
local DrawRenderer = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("DrawRenderer"))

local GalleryRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("GalleryRemote")

local SLOT_COUNT  = Constants.GALLERY_SLOT_COUNT
local CHAIN_WAIT  = Constants.GUI_TIMEOUT
local CANVAS_SIZE = Vector2.new(Constants.CANVAS_SIZE, Constants.CANVAS_SIZE)

local GalleryController = {}

local slots = {}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function resolveSurfaceChild(canvas, partName, guiChild)
	local part = canvas:WaitForChild(partName, CHAIN_WAIT)
	if not part then
		warn("[GalleryController]", partName, "missing under", canvas:GetFullName())
		return nil
	end
	local surfaceGui = part:WaitForChild("SurfaceGui", CHAIN_WAIT)
	if not surfaceGui then
		warn("[GalleryController] SurfaceGui missing under", part:GetFullName())
		return nil
	end
	local guiObject = surfaceGui:WaitForChild(guiChild, CHAIN_WAIT)
	if not guiObject then
		warn("[GalleryController]", guiChild, "missing under", surfaceGui:GetFullName())
		return nil
	end
	return guiObject
end

local function resolveImageLabel(canvas)
	return resolveSurfaceChild(canvas, "BackGround", "ImageLabel")
end

local function resolveTextLabel(canvas)
	return resolveSurfaceChild(canvas, "Part", "TextLabel")
end

local function bindSlot(i, imageLabel, textLabel)
	local editableImage = AssetService:CreateEditableImage({ Size = CANVAS_SIZE })
	imageLabel.Image        = ""
	imageLabel.ImageContent  = Content.fromObject(editableImage)
	imageLabel.ScaleType     = Enum.ScaleType.Stretch
	imageLabel.ResampleMode  = Enum.ResamplerMode.Default

	DrawRenderer.clear(editableImage)
	if textLabel then textLabel.Text = "" end

	slots[i] = {
		editableImage = editableImage,
		imageLabel    = imageLabel,
		textLabel     = textLabel,
	}
end

local function renderSlot(i, entry)
	local slot = slots[i]
	if not slot then return end

	if not entry or typeof(entry.buffer) ~= "buffer" then
		DrawRenderer.clear(slot.editableImage)
		if slot.textLabel then slot.textLabel.Text = "" end
		return
	end

	local strokes = StrokeCodec.decode(entry.buffer)
	DrawRenderer.render(slot.editableImage, strokes)

	if slot.textLabel then
		slot.textLabel.Text = entry.playerName or ""
	end
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

function GalleryController:Init()
	local map = workspace:WaitForChild("Map", CHAIN_WAIT)
	local gamePlay = map and map:WaitForChild("GamePlay", CHAIN_WAIT)
	local gallery = gamePlay and gamePlay:WaitForChild("Gallery", CHAIN_WAIT)
	local galleryCanvas = gallery and gallery:WaitForChild("GalleryCanvas", CHAIN_WAIT)
	if not galleryCanvas then
		warn("[GalleryController] GalleryCanvas not found; gallery disabled")
		return
	end

	for i = 1, SLOT_COUNT do
		local model  = galleryCanvas:WaitForChild(tostring(i), CHAIN_WAIT)
		local canvas = model and model:WaitForChild("Canvas", CHAIN_WAIT)
		if canvas then
			local imageLabel = resolveImageLabel(canvas)
			if imageLabel then
				bindSlot(i, imageLabel, resolveTextLabel(canvas))
			end
		else
			warn("[GalleryController] Canvas not found under GalleryCanvas/" .. i)
		end
	end

	GalleryRemote.OnClientEvent:Connect(function(drawings)
		self:Render(drawings)
	end)
end

function GalleryController:Render(drawings)
	local list = typeof(drawings) == "table" and drawings or {}
	for i = 1, SLOT_COUNT do
		renderSlot(i, list[i])
	end
end

return GalleryController
