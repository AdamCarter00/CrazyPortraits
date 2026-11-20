# İş 6 — Ölçüm (T-021)

2026-11-20 · kasa: T-016, T-017, T-021 (K-008 açıldı) · yayın yok.
Olay alanlarının Explore'daki sırası ve değerleri: `rapor\AnalitikRaporlar\SOZLUK.md`.

## Ne yapıldı

| Parça | Dosya | Ne |
|---|---|---|
| Çekirdek (LEAK'ten) | `src/shared/Analytics/Core.luau` | Şema doğrulama, `CustomField01..03` eşlemesi, kapalı değer listeleri, bütçe (penceredeki en yüksek oyuncu sayısıyla; IlkGiris/D1Donus/Cikis için ayrılmış pay), Studio'da Output, kapatma anahtarı, hata uyarısı sınırı. Saf: saat, oyuncu sayısı, gönderim ve Output dışarıdan girer. |
| UTC gün | `src/shared/Analytics/Day.luau` | Unix sn → `YYYY-AA-GG`, gün ekleme (ay/yıl/artık yıl). |
| Olaylar | `src/shared/Analytics/Metrics.luau` | T-021'in 8 olayı. Tur makinesinin durumuna bakar (yeni tur, geç katılım, reveal, podyum); makineye dokunmaz. |
| Ayarlar | `src/shared/Config/Analytics.luau` | Olay adları, alan listeleri, değer listeleri, kova sınırları, kohort gün aralığı, bütçe. |
| Sunucu | `src/server/Measurement.luau` | `AnalyticsService:LogCustomEvent`, LaunchData okuma (pcall), profil kaydı. |
| Profil | `PlayerDataService` | `GetFirstJoin` / `RecordFirstJoin`: `firstJoin = {day, source, version}`; şablonda yok (Reconcile eski profillere yazmasın), bir kez yazılır, hemen `Save`. Yeni profil = `SessionLoadCount == 1`. |
| Bağlantı | `RoundService.observe`, `Main.server` | Her tur çağrısından sonra ölçüm gözlemcisi (pcall); giriş `PlayerAdded`'da hemen, profil yüklenince ikinci adım, çıkış `PlayerRemoving`'de. |

Testler: `tests/olcum/core.spec.luau` (çekirdek, 14), `tests/olcum/olcum.spec.luau` (akış + Okuma tablosu, 31). Toplam 134 test yeşil.

- Okuma testleri bir "test günü" simüle eder: 9 oyuncu, iki sunucu (dolu / tek kişilik), gerçek tur makinesiyle; tek başına giriş, dolu sunucu, reveal sırasında geç giren izleyici, boş teslim, iptal edilen tur (herkes boş), aynı gün tekrar giriş, gece yarısı dönüşü, gece yarısını çıkmadan geçme, profil okunamayan, F-001'den eski profil. Her Okuma satırı için pay/payda: D1 1/7 (Wilson 0.026–0.513), ortalama oturum 1750/7 · 1930/9, ilk 60 sn 1/7, 5. dk 4/7, ilk tur 3/7, zincir 4·4·3·0 /7, oylama anı 4/7, başlayan maç 4/7, bekleme 91/4, tek başına 4/7 ve Eslesme hayır 3/7, etiketli dilim (D1 1/2, oturum 280, 60 sn 0/2, 5. dk 1/2).
- Gizlilik testi: gönderilen hiçbir olayın adında, değerinde ya da alanında kullanıcı numarası (ya da son 4 hanesi) veya adı yok; alan anahtarları yalnız `CustomField01..03`.
- Studio (Play, tek oyuncu): çıkışta `[Analitik] Eslesme deger=19 eslesti=hayir kohort=bilinmiyor ilk_oturum=hayir` ve `[Analitik] Cikis deger=19 kohort=bilinmiyor kaynak=bilinmiyor oturum_tipi=donus`. Adam'ın hesabı F-001'den eski profil olduğu için IlkGiris yok; doğru.

## Koddaki okumalar (T-021'de açık yazmayan, karar değil)

- **Eski F-001 profili** (profil var, ilk giriş kaydı yok): yeni sayılmaz; kohort ve kaynak `bilinmiyor`, oturum tipi `donus`. Kayıt yazılmaz.
- **D1Donus** oturumun giriş gününe bakar; gece yarısını oyundan çıkmadan geçen oturum (ilk ya da sonraki) D1 saymaz.
- **Etiketli** = LaunchData boş olmayan herhangi bir metin. LEAK'teki gibi kampanya adı listesi yok; ham metin hiçbir alana girmez.
- **LaunchData** girişte ve profil yüklenince okunur; geç gelirse kaçar (BORC).
- **o_an "turda"**: o anki turun katılımcısı (çizim, toplama, reveal, podyum dahil). Hazır olmayan oyuncu reveal görmüş sayılmaz.
- **Tur sırası** izlenen turları da sayar (T-021 R1 = tur sırası 1 her katılımla).

## K-008 (açıldı, varsayımla devam)

Etiketli dilim TurBasladi, IlkReveal, TurTamam ve Eslesme'de okunamaz: bu olayların üç alanı dolu ve kaynak yok. Varsayım: kod tabloyu olduğu gibi uygular; etiketli dilim yalnız kaynak alanı olan satırlarda. Bu varsayıma bağlı kod yok, ayrı commit gerekmedi.

## Madde 6 — LEAK TEST1–2'de LaunchData etiketi

Kaynak: `Oyunlar\LEAK\rapor\AnalitikRaporlar\2026.11.06-TEST1\veri.md`, `2026.11.07-TEST2\veri.md`. LEAK'te "yeni oyuncu" = H1 hunisinin ilk adımı (HubArrival, kayıtta `seen` yok); etiket huninin Custom field 1'i.

| Test | Yeni gelen (HubArrival) | Etiketli | Pay | Not |
|---|---|---|---|---|
| TEST1 | 197 | 34 (KAPAK-A 9 + KAPAK-B 25) | %17 | Huni "Last 7 days", veri 06.11 08:00'de kesilmiş (kampanya sürerken; reklam öncesi yeni gelenler dahil). Ads Manager'ın son Plays değeri 196 (43 + 153), farklı ölçü ve farklı anda. |
| TEST2 | 1.918 | 321 (KAPAK-B) | %16,7 | Huni 11/7–11/9 (kampanya 07.11 19:00 öncesi saatler dahil). Ads Manager Plays 1.613; 321 / 1.613 ≈ %20, ama Plays tekil yeni oyuncu değil. |

"Reklam döneminde gelen yeni oyunculardan kaçı reklamla geldi" verisi yok: etiketsiz (`organik`) grubu reklamla gelip oyun sayfasından Play'e basanları da içeriyor, Acquisition ekranı (TEST1 ekran 47–48) o gün boştu (bütün kaynaklar 0). Bulunabilen: yeni gelenlerin yaklaşık **%17'si** etiket taşıdı; reklamla gelenlerin ne kadarının etiket taşıdığı **yok**.

## Madde 7 — Prova listesi (yayınlanmış oyunda, reklamdan önce)

Hazırlık: 4 yeni alt hesap (A, B, C, D; oyuna hiç girmemiş) + Adam'ın hesabı. Prova günü = G (UTC). Saatler UTC.
Tur için en az 2 hazır oyuncu varsayıldı (`MinPlayers`; depoda yerel değişiklik olarak 1 duruyor, commit edilmedi; yayında kaç olduğunu kontrol et).

| # | Ne yapılır | Beklenen olaylar |
|---|---|---|
| 1 | A, `https://www.roblox.com/games/72378550860176?launchData=PROVA` ile, boş sunucuya girer; 40 sn sonra çıkar | IlkGiris deger 1 kaynak etiketli · Eslesme hayir ~40 · Cikis ilk_0-60 |
| 2 | B boş sunucuya girer; 20 sn sonra C aynı sunucuya (arkadaşa katıl). Tur 1: C boş gönderir, B çizer | IlkGiris B 1, C 0 · Eslesme B evet ~20, C evet 0 · TurBasladi B, C |
| 3 | Tur 1'in reveal'ı sırasında D girer | IlkGiris D 0 · IlkReveal D izleyici · TurTamam D sıra 1 izledi |
| 4 | Tur 2'de B, C, D çizer; üçü de D'nin girişinden 5 dk sonrasına kadar kalır, sonra çıkar | TurTamam sıra 2 ×3 · BesDakika B, C, D · Cikis ilk_300+ ×3 |
| 5 | A aynı gün tekrar girer, çıkar | Cikis donus · D1Donus yok |
| 6 | B, G 23:50'de girer, 23:55'te çıkar; G+1 00:05'te tekrar girer | G+1 girişinde D1Donus (kohort G) |
| 7 | C, G 23:55'te girer, G+1 00:05'e kadar çıkmadan kalır; G+1'de bir daha girmez | D1Donus yok · Cikis donus |
| 8 | Adam'ın hesabı girer, çıkar | Cikis kohort bilinmiyor, oturum_tipi donus · IlkGiris yok |

**View Events'te tek tek** (her olay en az bir kez, alanları SOZLUK'teki sırayla): IlkGiris (A, B, C, D; 4) · D1Donus (B; 1) · Cikis (A ×2, B ×3, C ×2, D, Adam) · BesDakika (B, C, D) · Eslesme (her oturumda bir) · TurBasladi (B, C, D) · IlkReveal (B, C, D) · TurTamam (sıra 1 ×3, sıra 2 ×3). Ayrıca: Custom field 1'de A'nın satırı `etiketli`; hiçbir alanda ad ya da numara yok.

**Explore'da pay ve payda** (kohort = G, tekil kullanıcı): IlkGiris 4 · D1 1/4 · ilk 60 sn 1/4 · 5. dk 3/4 · ilk tur tamamlama 2/4 (D izledi, sayılmaz) · R0/R1/R2/R3 3/4, 3/4, 3/4, 0/4 · oylama anı 3/4 · başlayan maç 3/4 · IlkGiris ortalaması 0,5 · Eslesme hayır (ilk oturum) 1/4 · etiketli: IlkGiris 1, D1 0/1. Ortalama oturum ve bekleme: o günün süreleriyle elle karşılaştır.

**Panel:** Creator Hub'daki hazır Day 1 retention kartına erişim var mı, G kohortunu gösteriyor mu (STANDART §6.1).

## Diğer

- Place'te `ReplicatedStorage.Packages.GameAnalytics` (gameanalytics-sdk 2.2.6) duruyor; kodda kullanılmıyor (test zorlar). T-017'ye göre kaldırılabilir; Studio nesnesi olduğu için silmedim, Adam'ın onayı gerekir.
