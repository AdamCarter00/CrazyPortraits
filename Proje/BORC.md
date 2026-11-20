# Teknik borç

Bilerek bırakılan işler (CLAUDE.md → Teknik borç). Raporlar `rapor\` altında.

| Ne | Neden bırakıldı | Hangi koşulda ele alınır | Kaynak |
|---|---|---|---|
| Admin paneli (`client/AdminClient`) arayüzünü çalışma anında kuruyor, biçim değerleri kodda; sohbet kancaları eksik `TextChatCommand`'ı kendisi yaratıyor | F-001'den olduğu gibi taşındı (iş listesi 0); yalnız geliştirici aracı, oyuncu görmüyor | Panelde değişiklik gerektiğinde ya da arayüz işaret düzenine geçirilirken | IS-LISTESI 0 |
| Rapor yazma tarafı (`ModerationService`) taşınmadı; panel yalnız DataStore'daki eski raporları gösteriyor | İş listesinde rapor yok; panel okuma tarafıyla çalışıyor | Oyuna rapor düğmesi geri geldiğinde | IS-LISTESI 0 |
| `FirstDrawingService` taşındı ama tur ona ilk çizimi yazmıyor | Tur yönetimi yeni; ilk çizim kaydı iş listesinde yok | Admin "First-Timers" sekmesi yeniden gerekince ya da ölçüm işinde (6) | IS-LISTESI 0 |
| Round kanalında (Ready/Submit/Vote) hız sınırı yok; Ready tekrarı gönderene anlık durumu (gösterimde çizim tamponu dahil) yeniden yollar | Yalnız gönderenin kendisine gider, başkasının oyununu bozmaz | Yayından önce ya da kötüye kullanım görülürse | IS-LISTESI 1 |
