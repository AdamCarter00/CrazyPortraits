--[[
DrawingsPanelService
--------------------
Business logic behind the /drawings analysis panel — a browse-only tool over
every first-timer drawing in FirstTimerDrawings_v1, separate from the /panel
moderation flow. AdminCommandRouter calls these handlers; they decide what to
fetch and send back.

ShowDrawings returns one paginated page of summaries (oldest first); the client
walks pages with a cursor. ViewDrawing pulls a single drawing's buffer on demand
(buffers are ~96 KB, omitted from the list payload).

A/B experiment grouping is derived client-side from each record's ownerUserId, so
nothing here computes it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdminService        = require(script.Parent:WaitForChild("AdminService"))
local FirstDrawingService = require(script.Parent:WaitForChild("FirstDrawingService"))

local AdminRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AdminRemote")

local DrawingsPanelService = {}

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

function DrawingsPanelService.handleShowDrawings(player, payload)
	-- The /drawings chat path does not pass through AdminCommandRouter's rate
	-- limiter, so gate here too (a page is up to DRAWINGS_PAGE_SIZE+1 reads).
	-- On limit, drop silently like the router's other commands.
	if not AdminService:CheckRateLimit(player, "global") then return end

	-- Optional cursor: number resumes after that timestamp; anything else starts
	-- from the beginning (oldest first).
	local cursor = nil
	if typeof(payload) == "table" and typeof(payload.cursor) == "number" then
		cursor = payload.cursor
	end

	AdminService:LogAction(player, "ShowDrawings", { cursor = cursor })

	local entries, nextCursor = FirstDrawingService.listPage(cursor)

	AdminRemote:FireClient(player, "DrawingsPage", {
		entries    = entries,
		cursor     = cursor,
		nextCursor = nextCursor,
	})
end

function DrawingsPanelService.handleViewDrawing(player, payload)
	if typeof(payload) ~= "table" or typeof(payload.entryId) ~= "string" then
		AdminService:RegisterAnomaly(player, "BadArgs", { command = "ViewDrawing" })
		return
	end

	local entry = FirstDrawingService.getEntry(payload.entryId)
	if not entry then return end

	AdminService:LogAction(player, "ViewDrawing", { entryId = payload.entryId })

	AdminRemote:FireClient(player, "DrawingDetail", {
		entryId       = payload.entryId,
		ownerUserId   = entry.ownerUserId,
		theme         = entry.theme,
		timestamp     = entry.timestamp,
		drawingBuffer = entry.drawingBuffer,
	})
end

return DrawingsPanelService
