--!strict

-- F-001 ile ayni place: adlar degisirse eski veri okunmaz.
return table.freeze({
	PlayerData = "PlayerData_v2",
	AuditLog = "AdminAuditLog_v1",
	Ban = "BannedPlayers_v1",
	ReportDetail = "ReportedDrawings_v1",
	ReportIndex = "ReportIndex_v1",
	FirstDrawDetail = "FirstTimerDrawings_v1",
	FirstDrawIndex = "FirstTimerDrawingsIndex_v1",
	BanTopic = "AdminBan_v1",
	FrameEquipAttribute = "EquippedFrame",
})
