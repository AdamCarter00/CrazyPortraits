--[[
FirstDrawingService
-------------------
Stores the FIRST finished drawing of a first-time player: only those whose
lifetime session is 1 and who completed their very first round with a
non-empty drawing. Exactly two pieces of data are kept: the drawing buffer
and its theme. No moderation/ban state — this is a viewing-only feed for the
admin panel's "First-Timers" tab.

One record per player (key = "u{userId}"). If a record already exists it is
left untouched (first write wins), so a DataStore hiccup or an unexpected
re-trigger never overwrites the genuine first drawing.

Mirrors ReportIndex's two-store layout so the panel can list recent entries
without scanning the whole keyspace:
  FirstTimerDrawings_v1       -> regular DataStore: key = "u{userId}", value = entry
  FirstTimerDrawingsIndex_v1  -> OrderedDataStore: key = "u{userId}", value = timestamp

Entry value:
  { ownerUserId = number, theme = string, drawingBuffer = buffer, timestamp = number }
]]

local DataStoreService  = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared").Config
local Admin = require(Config.Admin)
local Stores = require(Config.Stores)

local FirstDrawingService = {}

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local detailStore = DataStoreService:GetDataStore(Stores.FirstDrawDetail)
local indexStore  = DataStoreService:GetOrderedDataStore(Stores.FirstDrawIndex)

local function keyFor(userId)
	return "u" .. tostring(userId)
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

-- Persists a first-timer's first drawing. No-op if a record already exists for
-- this userId (first write wins). Runs off the caller thread.
function FirstDrawingService.persist(ownerUserId, theme, drawingBuffer)
	if typeof(ownerUserId) ~= "number" or ownerUserId <= 0 then return end
	if typeof(theme) ~= "string" then theme = tostring(theme) end
	if typeof(drawingBuffer) ~= "buffer" then return end

	local key       = keyFor(ownerUserId)
	local timestamp = os.time()

	task.spawn(function()
		-- UpdateAsync so the "already exists" check and the write are atomic:
		-- returning nil from the transform leaves the existing value untouched.
		local wrote = false
		local okDetail, errDetail = pcall(function()
			detailStore:UpdateAsync(key, function(old)
				if typeof(old) == "table" then
					return nil  -- first drawing already recorded; keep it
				end
				wrote = true
				return {
					ownerUserId   = ownerUserId,
					theme         = theme,
					drawingBuffer = drawingBuffer,
					timestamp     = timestamp,
				}
			end)
		end)
		if not okDetail then
			warn("[FirstDrawingService] detail write failed:", errDetail)
			return
		end
		if not wrote then return end  -- nothing new written, skip index

		local okIndex, errIndex = pcall(function()
			indexStore:SetAsync(key, timestamp)
		end)
		if not okIndex then
			warn("[FirstDrawingService] index write failed:", errIndex)
		end
	end)
end

-- Lists recent first-timer entries (newest first), summaries only (no buffer).
-- Each result: { entryId, ownerUserId, theme, timestamp }.
function FirstDrawingService.listRecent(limit)
	if typeof(limit) ~= "number" or limit <= 0 then limit = Admin.FirstDrawListLimit end
	limit = math.min(limit, Admin.ReportListMax)

	local index = {}
	local okIndex, errIndex = pcall(function()
		local pages = indexStore:GetSortedAsync(false, limit)
		local page  = pages:GetCurrentPage()
		for _, item in ipairs(page) do
			table.insert(index, { entryId = item.key, timestamp = item.value })
		end
	end)
	if not okIndex then
		warn("[FirstDrawingService] listRecent failed:", errIndex)
		return {}
	end

	-- Resolve theme/owner per entry (drawing buffer omitted from list payload —
	-- it is large; fetched only on view).
	local results = {}
	for _, idx in ipairs(index) do
		local entry = FirstDrawingService.getEntry(idx.entryId)
		if entry then
			table.insert(results, {
				entryId     = idx.entryId,
				ownerUserId = entry.ownerUserId,
				theme       = entry.theme,
				timestamp   = entry.timestamp,
			})
		end
	end
	return results
end

-- Paginated, oldest-first summary list for the /drawings analysis panel.
-- cursorTimestamp nil starts from the beginning; otherwise resumes strictly
-- after that timestamp (exclusive). Buffer omitted; resolved on view.
-- Returns (results, nextCursor): results is { entryId, ownerUserId, theme,
-- timestamp }; nextCursor is the last page entry's timestamp, or nil when the
-- page was not full (no more pages).
--
-- Note: GetSortedAsync minValue is inclusive, so the cursor passes
-- cursorTimestamp + 1. Two records sharing the exact same second straddling a
-- page boundary could be skipped; first-timer writes are second-resolution and
-- rarely collide, so this is acceptable for a browse-only tool.
function FirstDrawingService.listPage(cursorTimestamp)
	local pageSize = Admin.DrawingsPageSize

	local page
	local ok, err = pcall(function()
		local minValue = nil
		if typeof(cursorTimestamp) == "number" then
			minValue = cursorTimestamp + 1
		end
		local pages = indexStore:GetSortedAsync(true, pageSize, minValue)
		page = pages:GetCurrentPage()
	end)
	if not ok then
		warn("[FirstDrawingService] listPage failed:", err)
		return {}, nil
	end

	local results = {}
	local lastTimestamp = nil
	for _, item in ipairs(page) do
		local entry = FirstDrawingService.getEntry(item.key)
		if entry then
			table.insert(results, {
				entryId     = item.key,
				ownerUserId = entry.ownerUserId,
				theme       = entry.theme,
				timestamp   = entry.timestamp,
			})
		end
		lastTimestamp = item.value
	end

	-- A short page means we reached the end; no further cursor.
	local nextCursor = (#page >= pageSize) and lastTimestamp or nil
	return results, nextCursor
end

function FirstDrawingService.getEntry(entryId)
	if typeof(entryId) ~= "string" or #entryId == 0 then return nil end
	local ok, entry = pcall(function()
		return detailStore:GetAsync(entryId)
	end)
	if not ok then
		warn("[FirstDrawingService] getEntry failed:", entry)
		return nil
	end
	if typeof(entry) ~= "table" then return nil end
	return entry
end

return FirstDrawingService
