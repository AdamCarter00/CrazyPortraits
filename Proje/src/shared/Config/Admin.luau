--!strict

local SECONDS_PER_HOUR = 3600
local SECONDS_PER_DAY = 24 * SECONDS_PER_HOUR

return table.freeze({
	SecondsPerHour = SECONDS_PER_HOUR,
	HoursPerDay = 24,

	-- Admin beyaz listesi: UserId.
	AdminUserIds = table.freeze({ 10330652079 }),

	AnomalyKickThreshold = 5,
	AnomalyWindowSeconds = 60,
	RateLimitMaxPerMinute = 30,
	RateLimitWindowSeconds = 60,

	DataStoreWriteRetries = 2,
	DataStoreWriteBackoffSeconds = 7,

	ReportFetchLimit = 60,
	ReportListLimit = 20,
	ReportListMax = 100,
	FirstDrawListLimit = 50,
	DrawingsPageSize = 50,
	ErrorFlashSeconds = 4,

	BanDurations = table.freeze({
		["1h"] = SECONDS_PER_HOUR,
		["1d"] = SECONDS_PER_DAY,
		["7d"] = 7 * SECONDS_PER_DAY,
		["30d"] = 30 * SECONDS_PER_DAY,
	}),
})
