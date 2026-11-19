--[[
QuitLog
-------
Append-only research log of players who quit DURING the drawing phase
WITHOUT submitting (i.e. quitType == "QuitMidRound" while phase == Drawing).
Players who pressed Submit before leaving are NOT recorded here; they are
already covered by the QuitAfterSubmit analytics path.

Meant to be read externally via Open Cloud (raw, per-player). Mirrors the
two-store design of ReportIndex so listing recent entries does not require
scanning the whole keyspace.

Two-store design:
  DrawingQuitLog_v1      -> regular DataStore: key = entryKey, value = full entry
  DrawingQuitLogIndex_v1 -> OrderedDataStore: key = entryKey, value = timestamp

entryKey format: "u{userId}:{serverTimeNow}"
  - userId is embedded so entries are cleanly separable per player.
  - the timestamp suffix makes each quit a distinct key, so successive quits
    by the same player append rather than overwrite (true append log).

The detail value is a flat table (all scalar fields) so it deserializes
cleanly in any Open Cloud consumer:
  {
    userId          = number,   -- player identity (for separation)
    startedDrawing  = boolean,  -- did they draw at all (strokesDrawn > 0)
    strokesDrawn    = number,   -- brush + flood-fill strokes started, else 0
    undoCount       = number,   -- undo presses, else 0
    lifetimeSession = number,   -- which lifetime session this was (-1 if unknown)
    roundInSession  = number,   -- which round of this session (completed + 1)
    drawingElapsed  = number,   -- seconds into the drawing phase at quit (<=140)
    timestamp       = number,   -- server epoch seconds
  }
]]

local DataStoreService  = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Analytics = require(script.Parent:WaitForChild("AnalyticsService"))

local QuitLog = {}

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local detailStore = DataStoreService:GetDataStore(Constants.QUITLOG_DETAIL_STORE)
local indexStore  = DataStoreService:GetOrderedDataStore(Constants.QUITLOG_INDEX_STORE)

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

-- entry: flat table as documented in the file header. userId is required and
-- must be a positive number; everything else is logged as-is.
function QuitLog.record(entry)
	if typeof(entry) ~= "table" then return end
	local userId = entry.userId
	if typeof(userId) ~= "number" or userId <= 0 then return end

	local timestamp = os.time()
	entry.timestamp = timestamp
	local entryKey  = string.format("u%d:%d", userId, math.floor(workspace:GetServerTimeNow() * 1000))

	-- Writes run off the caller thread (player removal must not block on
	-- DataStore latency). Both writes are pcall-guarded independently.
	task.spawn(function()
		local okDetail, errDetail = pcall(function()
			detailStore:SetAsync(entryKey, entry)
		end)
		if not okDetail then
			warn("[QuitLog] detail write failed:", errDetail)
			Analytics:LogServerError(userId, "error", "QuitLog detail write failed: " .. tostring(errDetail))
			return
		end
		local okIndex, errIndex = pcall(function()
			indexStore:SetAsync(entryKey, timestamp)
		end)
		if not okIndex then
			warn("[QuitLog] index write failed:", errIndex)
			Analytics:LogServerError(userId, "error", "QuitLog index write failed: " .. tostring(errIndex))
		end
	end)
end

-- Lists the most recent entry keys (newest first). Each result is
-- { entryKey = string, timestamp = number }; fetch details with getEntry.
function QuitLog.listRecent(limit)
	if typeof(limit) ~= "number" or limit <= 0 then limit = 20 end
	limit = math.min(limit, 100)

	local results = {}
	local ok, err = pcall(function()
		local pages = indexStore:GetSortedAsync(false, limit)
		local page  = pages:GetCurrentPage()
		for _, item in ipairs(page) do
			table.insert(results, {
				entryKey  = item.key,
				timestamp = item.value,
			})
		end
	end)
	if not ok then
		warn("[QuitLog] listRecent failed:", err)
		return {}
	end
	return results
end

function QuitLog.getEntry(entryKey)
	if typeof(entryKey) ~= "string" or #entryKey == 0 then return nil end
	local ok, entry = pcall(function()
		return detailStore:GetAsync(entryKey)
	end)
	if not ok then
		warn("[QuitLog] getEntry failed:", entry)
		return nil
	end
	if typeof(entry) ~= "table" then return nil end
	return entry
end

return QuitLog
