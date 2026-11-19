--[[
GroupService
------------
Assigns each player a persistent A/B cohort, used purely as an ANALYTICS label
(group is folded into GameAnalytics event ids). The two groups receive identical
gameplay — the split exists only so retention/quit/submit metrics can be compared
across cohorts later.

The assignment is deterministic from the UserId (even -> "A", odd -> "B"), so it
needs no storage and can never fail: the same player always lands in the same
group across sessions and servers, with no DataStore call in the hot join path.
]]

local GroupService = {}

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

-- Returns the player's sticky A/B group, derived purely from the UserId.
-- Even UserId -> "A", odd -> "B". Falls back to "A" for an invalid id.
function GroupService:LoadGroup(userId)
	if typeof(userId) ~= "number" or userId <= 0 then return "A" end
	return (userId % 2 == 0) and "A" or "B"
end

--------------------------------------------------------------------------------

return GroupService
