# F-015 Crazy Portraits 2 · V0 iş listesi (2026-11-19)

Hedef: 5 gün [Adam]. Kaynak: [[F-015]] `## V0 planı` ve düzeltme listesi · [[OTOPSI]] · [[CEKIRDEK]].
Oyun kasası açılınca bu dosya oraya taşınır; burada link kalır.
Sıra önem sırasıdır. Önerilen gün yanında. Parantezdeki numaralar sade listedeki (sohbet 2026-11-19) maddeler.

> Kopya, 2026-11-20: PORTFOY `kayit/kanitlar/F-015-V0/IS-LISTESI.md`'den alındı. İş sırası bundan sonra burada tutulur.

## 0 · Kurulum (Gün 1 başı) — BİTTİ 2026-11-20
- Depo + Rojo; place aynı (Crazy Portraits, placeId 72378550860176).
- Snapshot'tan olduğu gibi taşınacaklar: `StrokeCodec`, `FloodFill`, `StrokeValidator`, `DrawRenderer`, `PassController`, `ProfileStore`, `PlayerDataService`, `BanService`, `AdminService` + admin paneli. `AnalyticsService` snapshot'ta yok, Studio'da.
- **Neden:** bunlar sağlam ve test edilebilir; yeniden yazmak gün yer.

## 1 · Tur yönetimi baştan (Gün 1–2) — en önemli — SUNUCU TARAFI BİTTİ 2026-11-20 (istemci ekranları 4-5. işlerde)
Saf durum makinesi + zamanlayıcı + yan etki katmanı; Lune testleriyle.
- Herkes teslim edince tur biter; üst sınır 140 sn (2).
- Takılan ekranlar: "Round starting in 0s", "Round over"; oyuncu sayısı düşünce lobi durumu yeniden yayınlanır (3).
- Hazır yarışı: oyuncu durumu oluşmadan gelen Ready (4).
- Reveal'da hot-join: gösterim/oylama sırasında giren hemen görür ve oy verir (18).
- Oy, çizim kimliğiyle gönderilir; geç oy yanlış çizime yazılmaz (9).
- Tur sonu sonuçları herkese yayınlanır (podyum için veri) (11).
- **Neden:** hataların çoğu bu tek modülden çıkıyor; reveal, oy ve ölçüm işleri buna dayanıyor. İlk gösterim bugün ~2 dk sonra geliyor.

## 2 · Mobilde joystick kaybı (Gün 2) (1) — KOD HAZIR 2026-11-20 (`client/GuiVisibility`); çizim istemcisi (3) bunu çağıracak, telefonda doğrulama 10. işte
- Çizimde yalnız oyunun kendi GUI'leri gizlenir; Roblox `TouchGui` ellenmez.
- **Neden:** mobil oyuncu ilk turdan sonra lobide yürüyemiyor; trafiğin çoğu mobil. İş küçük.

## 3 · Çizim verisinin güvenliği (Gün 2)
- Geri alma geçmişi ile gönderilen çizgi listesi ayrılır; 80 çizgiden sonra baş silinmez (5).
- Çizim Submit anında gönderilir; Submit edip çıkanın çizimi kaybolmaz (6).
- Silgi ayrı durum; fırça boyu seçince beyaz çizmeye devam etmez (19).
- Dokunma: ilk parmak takip edilir, ötekiler yok sayılır; tuvalden çıkınca çizgi biter, girince yenisi başlar (15).
- **Neden:** oyuncunun emeği sessizce kayboluyor; en kötü hata türü.

## 4 · Reveal anı (Gün 3)
- 2D gösterim katmanı [Adam, 2026-11-20]; arkada 3D sahne karartılmış; çizim ekranın ≥%70'i (7). Emoji yağmuru çizimin kenarına.
- Solda model [Adam, 2026-11-20]: çizim ekranındaki klonun aynısı (gerçek oyuncu değil; oyuncu çıksa da klon durur [Adam]). Tek değişiklik: klon bugün reveal başında siliniyor (OTOPSI C·6), reveal ve podyum bitene kadar kalsın.
- Kare tuval (bugün 1.17:1 → gösterimde %15 sıkışma); ışık etkisi yok (7).
- Çizenin adı, "3 / 6", 5 sn süre çubuğu, açılış sesi, çizimler arası kısa geçiş (8).
- **Neden:** oyunun ödül anı bugün ekranın %45'inde, sıkışık, soluk, sessiz. Yatırımın asıl yeri.

## 5 · Oy ve podyum (Gün 3)
- Seçili emoji belirgin; sunucu onayı; çizim başına canlı toplam (10).
- Tur sonu podyumu: ilk 3 çizim + isim + tepki; 2 kişide yan yana; bonus yok (11).
- Sahibin kendi çizimine emoji basması **kalır** (kasıtlı: ilk tepkiyi başlatsın, puan yok).
- **Neden:** oyuncu oyunun sayıldığını görmüyor; kazanan yok.

## 6 · Ölçüm (Gün 4) — araç kararı bundan önce
- Başlamadan önce kasada T-016'yı oku (ikinci oyuncu gördü mü ve ilk eşleşme süresi dahil).
- Olaylar olduğu anda: giriş + kaynak (`UserAcquisitionSource`, reklam açık mı) → hazır → yalnız bekleme → ilk fırça → teslim (düğme/süre) → ilk gösterim → ilk oy → kendi çiziminin gösterimi + aldığı tepki → ikinci çizime başlama → tur n tamamlandı ("çizdi mi" alanıyla); sunucu başına oyuncu sayısı zaman serisi (21).
- Mevcut hatalar: `QuitAlone` sınıflaması, `RoundComplete`'in çizmeyeni saymasın; temel analitik işlevleri eksiksiz ve doğru (22).
- **Neden:** düzeltmelerin işe yarayıp yaramadığı yalnız bununla görülür; Kapı 1 bu olaylarla okunur.
- **Açık:** Roblox analitiği mi, GA mı (ayrı oturum; LEAK'in altyapısı Roblox analitiğiyle).

## 7 · Mobil arayüz (Gün 4–5)
- Dokunma hedefleri ≥44 pt: Submit (bugün 40×14), emoji (47×29), renk/araç (13).
- Güvenli alan: `ScreenInsets = CoreUISafeInsets`; tuval ve üst satır çentik/üst çubuk dışına (14).
- Ekran yönü yatayda kilitli: `StarterGui.ScreenOrientation = LandscapeSensor` (dış öneri, kabul; bugünkü değer Studio'da kontrol edilir — kodda yok ama özellik panelden ayarlı olabilir).
- Be Next Drawn duraklatıldığı için düğme kalkar; joystick çakışması (16) böylece kapanır.
- **Neden:** telefonda Submit'e zor basılıyor, düğmeler çentiğe giriyor.

## 8 · Yükleme ekranı (Gün 5) (17)
- İçerik: "Oyuncuyu çiz · güzel değil komik çiz · tepki topla"; oyundaki emojiler; telefonda gerilmesin.
- Sabit 5 sn bekleme yok; hata olursa yeniden deneme.
- **Neden:** yeni oyuncuya verilen ilk talimat bugün yanlış (olmayan tema).

## 9 · Kapatılacaklar (Gün 5, kısa)
- Market kapanır, çerçeve satışı durur [Adam].
- Be Next Drawn duraklatılır (satıştan kalkar) [Adam] (20).
- "Theme: …" yazan süs tabelaları; ölü kod (kopya admin istemcileri, tema sistemi, `dailyMissions`).

## 10 · Test (Gün 5)
- Studio çoklu istemciyle baştan sona tur (STANDART: yayından önce).
- Telefonda gerçek dokunma: iki parmak, Submit, emoji, joystick ilk turdan sonra, çentik tarafı.

## Listede olmayanlar
- Tek başına girene galeri: Kapı 1'e alınmadı; ölçüm gösterirse ek güncelleme [Adam, 2026-11-19].
- Öğretici, emoji yağmuru inceliği, ara yükleme, ileri al / temizle, "mürekkep bitti", 8 kişide performans: sonraya. Dikey yön yok (yatay kilit).
