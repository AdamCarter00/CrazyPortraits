--[[
AdminPanelService
-----------------
Business logic behind admin panel commands. AdminCommandRouter calls these
functions; this file decides what to fetch, what to send back, and how
much detail to expose.

ShowPanel returns both active and history lists in a single payload so
the client can switch tabs without re-fetching (rate-limit friendly).

Drawing buffers are large (~96 KB) so the list payload omits them; only
ViewReport pulls a single drawing.
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared").Config
local Admin = require(Config.Admin)
local Terms = require(Config.Terms)
local AdminService        = require(script.Parent:WaitForChild("AdminService"))
local ReportIndex         = require(script.Parent:WaitForChild("ReportIndex"))
local BanService          = require(script.Parent:WaitForChild("BanService"))
local FirstDrawingService = require(script.Parent:WaitForChild("FirstDrawingService"))

local Net = require(ReplicatedStorage:WaitForChild("Shared").Net)

local FETCH_LIMIT = Admin.ReportFetchLimit
local LIST_LIMIT  = Admin.ReportListLimit

-- Finite ban durations come from Config; "perm" is handled separately (nil = permanent).
local DURATIONS = Admin.BanDurations

local AdminPanelService = {}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function toSummary(reportKey, entry)
	return {
		reportId      = reportKey,
		ownerUserId   = entry.ownerUserId,
		theme         = entry.theme,
		reporterCount = entry.reporterCount,
		timestamp     = entry.timestamp,
		status        = entry.status or "active",
		resolvedAt    = entry.resolvedAt,
		resolvedBy    = entry.resolvedBy,
		banDuration   = entry.banDuration,
	}
end

local function sortActive(a, b)
	if a.reporterCount ~= b.reporterCount then
		return (a.reporterCount or 0) > (b.reporterCount or 0)
	end
	return (a.timestamp or 0) > (b.timestamp or 0)
end

local function sortHistory(a, b)
	return (a.resolvedAt or 0) > (b.resolvedAt or 0)
end

local function trim(list, limit)
	while #list > limit do
		table.remove(list)
	end
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

function AdminPanelService.handleShowPanel(player)
	-- Opening the panel is the heaviest admin action (~170 DataStore reads:
	-- report index + per-report fetch + first-drawing fetch). The /panel chat
	-- path does not pass through AdminCommandRouter's rate limiter, so gate it
	-- here too. On limit, tell the client instead of dropping silently so an
	-- already-open panel can surface "rate limited" rather than appearing to hang.
	if not AdminService:CheckRateLimit(player, "global") then
		Net.toPlayer(player, "PanelRejected", { reason = "rate_limited" })
		return
	end

	AdminService:LogAction(player, "ShowPanel")

	local indexEntries = ReportIndex.listRecent(FETCH_LIMIT)

	local active, history = {}, {}

	for _, indexEntry in ipairs(indexEntries) do
		local entry = ReportIndex.getReport(indexEntry.reportKey)
		if entry then
			local summary = toSummary(indexEntry.reportKey, entry)
			if summary.status == "active" then
				table.insert(active, summary)
			else
				table.insert(history, summary)
			end
		end
	end

	table.sort(active, sortActive)
	table.sort(history, sortHistory)
	trim(active, LIST_LIMIT)
	trim(history, LIST_LIMIT)

	-- First-Timers tab: recent first-time players' first drawings (summaries
	-- only; the drawing buffer is fetched on view via ViewFirstDrawing).
	local firstDrawings = FirstDrawingService.listRecent(Admin.FirstDrawListLimit)

	Net.toPlayer(player, "ShowPanel", {
		active        = active,
		history       = history,
		firstDrawings = firstDrawings,
	})
end

function AdminPanelService.handleViewReport(player, payload)
	if typeof(payload) ~= "table" or typeof(payload.reportId) ~= "string" then
		AdminService:RegisterAnomaly(player, "BadArgs", { command = "ViewReport" })
		return
	end

	local entry = ReportIndex.getReport(payload.reportId)
	if not entry then
		-- Read failed or the report is gone; tell the client so the preview pane
		-- shows a message instead of silently staying blank.
		Net.toPlayer(player, "ViewReportFailed", { reportId = payload.reportId, reason = "not_found" })
		return
	end

	AdminService:LogAction(player, "ViewReport", { reportId = payload.reportId })

	Net.toPlayer(player, "ReportDetail", {
		reportId      = payload.reportId,
		ownerUserId   = entry.ownerUserId,
		theme         = entry.theme,
		reporterCount = entry.reporterCount,
		timestamp     = entry.timestamp,
		drawingBuffer = entry.drawingBuffer,
	})
end

-- First-Timers tab: fetch a single first drawing's buffer + theme on demand.
-- View-only; no moderation fields are exposed.
function AdminPanelService.handleViewFirstDrawing(player, payload)
	if typeof(payload) ~= "table" or typeof(payload.entryId) ~= "string" then
		AdminService:RegisterAnomaly(player, "BadArgs", { command = "ViewFirstDrawing" })
		return
	end

	local entry = FirstDrawingService.getEntry(payload.entryId)
	if not entry then return end

	AdminService:LogAction(player, "ViewFirstDrawing", { entryId = payload.entryId })

	Net.toPlayer(player, "FirstDrawingDetail", {
		entryId       = payload.entryId,
		ownerUserId   = entry.ownerUserId,
		theme         = entry.theme,
		timestamp     = entry.timestamp,
		drawingBuffer = entry.drawingBuffer,
	})
end

-- Tells the client whether an optimistic action (dismiss/ban) actually took
-- effect on the server. The client applies the change immediately on click; on
-- ok == false it rolls the row back to "active" so the panel never shows a
-- resolution that did not happen. reason (failure only) lets the panel show a
-- precise message: "rate_limited" | "bad_duration" | "not_found" | "store_busy"
-- | "store_unavailable".
local function sendActionResult(player, eventKind, reportId, ok, reason)
	Net.toPlayer(player, eventKind, { reportId = reportId, ok = ok, reason = reason })
end

function AdminPanelService.handleDismissReport(player, payload)
	if typeof(payload) ~= "table" or typeof(payload.reportId) ~= "string" then
		AdminService:RegisterAnomaly(player, "BadArgs", { command = "DismissReport" })
		return
	end

	local entry = ReportIndex.getReport(payload.reportId)
	if not entry or (entry.status or "active") ~= "active" then
		sendActionResult(player, "DismissResult", payload.reportId, false, "not_found")
		return
	end

	local adminUserId = player.UserId
	local ok = ReportIndex.updateReport(payload.reportId, function(e)
		e.status     = "dismissed"
		e.resolvedAt = os.time()
		e.resolvedBy = adminUserId
		return e
	end)

	if ok then
		AdminService:LogAction(player, "DismissReport", { reportId = payload.reportId })
	end
	sendActionResult(player, "DismissResult", payload.reportId, ok, ok and nil or "store_busy")
end

function AdminPanelService.handleBanReportee(player, payload)
	if typeof(payload) ~= "table"
		or typeof(payload.reportId) ~= "string"
		or typeof(payload.durationKey) ~= "string" then
		AdminService:RegisterAnomaly(player, "BadArgs", { command = "BanReportee" })
		return
	end

	if DURATIONS[payload.durationKey] == nil and payload.durationKey ~= "perm" then
		sendActionResult(player, "BanResult", payload.reportId, false, "bad_duration")
		return
	end

	local entry = ReportIndex.getReport(payload.reportId)
	if not entry
		or (entry.status or "active") ~= "active"
		or entry.ownerUserId == player.UserId then
		sendActionResult(player, "BanResult", payload.reportId, false, "not_found")
		return
	end

	local durationSeconds = DURATIONS[payload.durationKey]

	local banOk, banReason = BanService.ban(player, entry.ownerUserId, durationSeconds, "Drawing report", payload.reportId)
	if not banOk then
		sendActionResult(player, "BanResult", payload.reportId, false, banReason or "store_busy")
		return
	end

	-- The ban is already persisted. If the report's status update fails the player
	-- stays banned but the report would resurface as "active" on the next /panel,
	-- so report ok == false and let the admin retry; the retry re-bans (idempotent
	-- SetAsync) and reattempts the status flip.
	local adminUserId = player.UserId
	local reportOk = ReportIndex.updateReport(payload.reportId, function(e)
		e.status      = "banned"
		e.resolvedAt  = os.time()
		e.resolvedBy  = adminUserId
		e.banDuration = durationSeconds
		return e
	end)
	if not reportOk then
		warn("[AdminPanelService] ban persisted but report status update failed for", payload.reportId)
		AdminService:LogAction(player, "BanReportStatusStale", {
			reportId     = payload.reportId,
			targetUserId = entry.ownerUserId,
		})
	end
	sendActionResult(player, "BanResult", payload.reportId, reportOk, reportOk and nil or "store_busy")

	local target = Players:GetPlayerByUserId(entry.ownerUserId)
	if target then
		local message
		if durationSeconds then
			message = string.format(Terms.BanTimed, math.ceil(durationSeconds / Admin.SecondsPerHour))
		else
			message = Terms.BanPermanent
		end
		pcall(function() target:Kick(message) end)
	end
end

return AdminPanelService
