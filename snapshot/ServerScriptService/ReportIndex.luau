--[[
ReportIndex
-----------
Chronological index over reported drawings. Backed by an OrderedDataStore
so the admin panel can list "most recent N reports" without scanning the
full `ReportedDrawings_v1` keyspace.

Two-store design:
  ReportIndex_v1     -> OrderedDataStore: key = reportKey, value = timestamp
  ReportedDrawings_v1 -> regular DataStore: key = reportKey, value = full entry

The index is written alongside every report's first upsert. Listing pulls
the recent index entries, then fetches details on demand.
]]

local DataStoreService  = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants      = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local DataStoreRetry = require(script.Parent:WaitForChild("DataStoreRetry"))

local ReportIndex = {}

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local indexStore  = DataStoreService:GetOrderedDataStore(Constants.REPORT_INDEX_STORE)
local detailStore = DataStoreService:GetDataStore(Constants.REPORT_DETAIL_STORE)

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

function ReportIndex.recordReport(reportKey, timestamp)
	if typeof(reportKey) ~= "string" or #reportKey == 0 then return end
	if typeof(timestamp) ~= "number" then return end
	task.spawn(function()
		local ok, err = pcall(function()
			indexStore:SetAsync(reportKey, timestamp)
		end)
		if not ok then
			warn("[ReportIndex] index write failed:", err)
		end
	end)
end

function ReportIndex.listRecent(limit)
	if typeof(limit) ~= "number" or limit <= 0 then limit = Constants.REPORT_LIST_LIMIT end
	limit = math.min(limit, Constants.REPORT_LIST_MAX)

	local results = {}
	local ok, err = pcall(function()
		local pages = indexStore:GetSortedAsync(false, limit)
		local page  = pages:GetCurrentPage()
		for _, entry in ipairs(page) do
			table.insert(results, {
				reportKey = entry.key,
				timestamp = entry.value,
			})
		end
	end)
	if not ok then
		warn("[ReportIndex] listRecent failed:", err)
		return {}
	end
	return results
end

function ReportIndex.getReport(reportKey)
	if typeof(reportKey) ~= "string" or #reportKey == 0 then return nil end
	local ok, entry = pcall(function()
		return detailStore:GetAsync(reportKey)
	end)
	if not ok then
		warn("[ReportIndex] getReport failed:", entry)
		return nil
	end
	if typeof(entry) ~= "table" then return nil end
	return entry
end

function ReportIndex.updateReport(reportKey, transformFn)
	if typeof(reportKey) ~= "string" or #reportKey == 0 then return false end
	if typeof(transformFn) ~= "function" then return false end
	-- Retry across the per-key UpdateAsync cooldown: a second moderation action on
	-- the same report (Dismiss then Ban) would otherwise throttle and look failed.
	local ok, err = DataStoreRetry.writeWithRetry(function()
		detailStore:UpdateAsync(reportKey, function(old)
			if typeof(old) ~= "table" then return nil end
			return transformFn(old)
		end)
	end)
	if not ok then
		warn("[ReportIndex] updateReport failed:", err)
		return false
	end
	return true
end

return ReportIndex
