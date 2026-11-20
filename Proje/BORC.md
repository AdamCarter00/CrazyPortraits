# Teknik borç

Bilerek bırakılan işler (CLAUDE.md → Teknik borç). Raporlar `rapor\` altında.

| Ne | Neden bırakıldı | Hangi koşulda ele alınır | Kaynak |
|---|---|---|---|
| Admin paneli (`client/AdminClient`) arayüzünü çalışma anında kuruyor, biçim değerleri kodda; sohbet kancaları eksik `TextChatCommand`'ı kendisi yaratıyor | F-001'den olduğu gibi taşındı (iş listesi 0); yalnız geliştirici aracı, oyuncu görmüyor | Panelde değişiklik gerektiğinde ya da arayüz işaret düzenine geçirilirken | IS-LISTESI 0 |
| Rapor yazma tarafı (`ModerationService`) taşınmadı; panel yalnız DataStore'daki eski raporları gösteriyor | İş listesinde rapor yok; panel okuma tarafıyla çalışıyor | Oyuna rapor düğmesi geri geldiğinde | IS-LISTESI 0 |
| `FirstDrawingService` taşındı ama tur ona ilk çizimi yazmıyor | Tur yönetimi yeni; ilk çizim kaydı iş listesinde yok | Admin "First-Timers" sekmesi yeniden gerekince ya da ölçüm işinde (6) | IS-LISTESI 0 |
| Round kanalında (Ready/Submit/Vote) hız sınırı yok; Ready tekrarı gönderene anlık durumu (gösterimde çizim tamponu dahil) yeniden yollar | Yalnız gönderenin kendisine gider, başkasının oyununu bozmaz | Yayından önce ya da kötüye kullanım görülürse | IS-LISTESI 1 |
| Çizim 80 çizgiye ya da 15000 piksele ulaşınca yeni çizgi sessizce başlamaz; "mürekkep bitti" göstergesi yok | Yerel tuval ile gönderilen çizim aynı kalsın diye gerekli sınır; gösterge iş listesinde "sonraya" | Oyuncular sınıra takılıyorsa (ölçümde ilk fırçadan teslime kadar süre ve çizgi sayısı) | IS-LISTESI 3 |
| Çizim ekranı geçiş perdesi beklemeden açılıyor (ilk 3 sn tuval kapalı ama görünür); PassController henüz bağlı değil | Perde `Isaret` işaretleriyle bağlanacak, iş 4 reveal akışıyla birlikte | Reveal geçişi kurulurken | IS-LISTESI 4 |
| Eski çizim ekranındaki zıplama kilidi (JumpPower = 0) taşınmadı | Mobilde joystick/zıplama çakışması Be Next Drawn düğmesi kalkınca kapanıyor (iş 7) | Telefon testinde çakışma görülürse | IS-LISTESI 7 |
| `PlayerDataService`te çerçeve, Be Next Drawn hakkı, öğretici ve `dailyMissions` alanları ile bunların erişim işlevleri duruyor; kullanılmıyor (test, satış kodunun başka yerde olmadığını zorlar) | Alanlar kalıcı profilde; çerçeve satın almış oyuncuların verisi silinmemeli, T-010 çerçeveleri rafa kaldırıyor, silmiyor | Çerçeveler ya da Be Next Drawn geri gelince kullanılır; kalıcı alanların sökülmesine karar verilirse veri taşıma planıyla | IS-LISTESI 9 |
| Admin panelleri eski raporlardaki `theme` alanını gösteriyor; `FirstDrawingService.persist` hâlâ tema parametresi alıyor, yeni çizimlerde "?" çıkar | Yalnız geliştirici aracı; eski kayıtların temasını okumak için gerekli | Eski raporlar silinince ya da panel işaret düzenine geçirilirken | IS-LISTESI 9 |
