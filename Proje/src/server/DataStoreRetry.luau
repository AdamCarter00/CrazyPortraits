--[[
DataStoreRetry
--------------
Wraps a DataStore write (SetAsync / UpdateAsync) in a short retry so a
transient throttle does not surface to the admin as a hard failure. The
backoff (Admin.DataStoreWriteBackoffSeconds) is sized to clear the ~6s
per-key UpdateAsync cooldown, which is the common cause of a second action
on the same report key failing (e.g. Dismiss immediately followed by Ban).

writeWithRetry(fn) runs fn() in pcall up to DATASTORE_WRITE_RETRIES + 1 times,
waiting between attempts, and returns (ok, resultOrErr) of the last attempt.
fn must be the actual DataStore call so each retry re-issues it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared").Config
local Admin = require(Config.Admin)

local DataStoreRetry = {}

function DataStoreRetry.writeWithRetry(fn)
	local attempts = Admin.DataStoreWriteRetries + 1
	local ok, result
	for attempt = 1, attempts do
		ok, result = pcall(fn)
		if ok then
			return true, result
		end
		if attempt < attempts then
			task.wait(Admin.DataStoreWriteBackoffSeconds)
		end
	end
	return false, result
end

return DataStoreRetry
