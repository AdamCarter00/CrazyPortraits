local DataStoreService  = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants    = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local AdminService = require(script.Parent:WaitForChild("AdminService"))
local ReportIndex  = require(script.Parent:WaitForChild("ReportIndex"))
local Analytics    = require(script.Parent:WaitForChild("AnalyticsService"))

local ModerationService = {}

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local reportStore = DataStoreService:GetDataStore(Constants.REPORT_DETAIL_STORE)
local auditStore  = DataStoreService:GetDataStore(Constants.REPORT_AUDIT_STORE)

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function saveReport(key, entry)
	local ok, err = pcall(function()
		reportStore:SetAsync(key, entry)
	end)
	if not ok then
		warn("[ModerationService] DataStore write failed:", err)
		Analytics:LogServerError(entry.ownerUserId, "error", "Report write failed: " .. tostring(err))
		return nil
	end
	return key
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

function ModerationService.getThreshold()
	return Constants.REPORT_THRESHOLD
end

-- Audit signal for the moment a drawing crosses the threshold and is hidden for
-- everyone. Fires once per drawing (the caller gates it on the threshold).
function ModerationService.logThresholdReached(ownerUserId, theme, reporterCount)
	AdminService:LogAction(nil, "ReportThresholdReached", {
		ownerUserId   = ownerUserId,
		theme         = theme,
		reporterCount = reporterCount,
	})
end

-- Raw per-reporter audit trail: one record per distinct reporter+drawing,
-- preserving WHO reported (the panel only keeps an aggregate reporterCount per
-- drawing). Own store so it never affects the panel listing. The caller dedupes
-- so a player can only generate one audit per drawing.
function ModerationService.logReportAudit(reporterUserId, ownerUserId, theme, drawingBuffer)
	local timestamp = os.time()
	task.spawn(function()
		local key = "audit_" .. timestamp .. "_" .. reporterUserId .. "_" .. ownerUserId
		local ok, err = pcall(function()
			auditStore:SetAsync(key, {
				reporterUserId = reporterUserId,
				ownerUserId    = ownerUserId,
				theme          = theme,
				drawingBuffer  = drawingBuffer,
				timestamp      = timestamp,
			})
		end)
		if not ok then
			warn("[ModerationService] audit write failed:", err)
		end
	end)
end

-- Upserts the panel record for a reported drawing. The caller passes a stable
-- reportId (one per owner+drawing per round) so every report on the same drawing
-- updates ONE row: first report inserts an active record, later reports only bump
-- reporterCount. Never touches status/timestamp, so a resolved record stays
-- resolved even if a late report arrives.
function ModerationService.upsertReport(reportId, ownerUserId, theme, drawingBuffer, reporterCount)
	if typeof(reportId) ~= "string" or #reportId == 0 then
		warn("[ModerationService] upsertReport: missing reportId, report not recorded for owner", ownerUserId)
		return
	end
	task.spawn(function()
		local existing = ReportIndex.getReport(reportId)
		if existing == nil then
			local timestamp = os.time()
			local key = saveReport(reportId, {
				ownerUserId   = ownerUserId,
				theme         = theme,
				drawingBuffer = drawingBuffer,
				reporterCount = reporterCount,
				timestamp     = timestamp,
				status        = "active",
			})
			if key then
				ReportIndex.recordReport(key, timestamp)
				AdminService:LogAction(nil, "ReportReceived", {
					ownerUserId   = ownerUserId,
					theme         = theme,
					reporterCount = reporterCount,
				})
			else
				-- saveReport already warned; surface that the report never reached
				-- the panel so it is not mistaken for a clean insert.
				warn("[ModerationService] upsertReport: insert failed, report not in panel for owner", ownerUserId)
			end
		else
			local ok = ReportIndex.updateReport(reportId, function(e)
				e.reporterCount = reporterCount
				return e
			end)
			if not ok then
				warn("[ModerationService] upsertReport: reporterCount update failed for", reportId)
			end
		end
	end)
end

--------------------------------------------------------------------------------

return ModerationService
