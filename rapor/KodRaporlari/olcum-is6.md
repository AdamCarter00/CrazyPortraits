# İş 6 — Ölçüm (T-021)

2026-11-20 · kasa: T-016, T-017, T-021, K-008 · yayın yok.
Olay alanlarının Explore'daki sırası ve değerleri: `rapor\AnalitikRaporlar\SOZLUK.md`.
İki adımda yapıldı: ilk adım `d8077aa` (8 olay, K-008 açıldı); devam (K-008 cevabı, Cikis fazı, Teslim, CizimTepki,
GameAnalytics paketi rafta) bu raporun "Devam" bölümünde.

## Ne yapıldı

| Parça | Dosya | Ne |
|---|---|---|
| Çekirdek (LEAK'ten) | `src/shared/Analytics/Core.luau` | Şema doğrulama, `CustomField01..03` eşlemesi, kapalı değer listeleri (birleşik `gün/kaynak` alanı dahil), bütçe (penceredeki en yüksek oyuncu sayısıyla; IlkGiris/D1Donus/Cikis için ayrılmış pay), Studio'da Output, kapatma anahtarı, hata uyarısı sınırı. Saf: saat, oyuncu sayısı, gönderim ve Output dışarıdan girer. |
| UTC gün | `src/shared/Analytics/Day.luau` | Unix sn → `YYYY-AA-GG`, gün ekleme (ay/yıl/artık yıl). |
| Olaylar | `src/shared/Analytics/Metrics.luau` | T-021'in 10 olayı. Tur makinesinin durumuna bakar (yeni tur, geç katılım, gösterilen çizim, podyum); makineye dokunmaz. Teslim için RoundService teslimden önceki aşamayı ve turu verir. |
| Ayarlar | `src/shared/Config/Analytics.luau` | Olay adları, alan listeleri, değer listeleri, kova sınırları, kohort gün aralığı, bütçe. |
| Sunucu | `src/server/Measurement.luau` | `AnalyticsService:LogCustomEvent`, LaunchData okuma (pcall), profil kaydı. |
| Profil | `PlayerDataService` | `GetFirstJoin` / `RecordFirstJoin`: `firstJoin = {day, source, version}`; şablonda yok (Reconcile eski profillere yazmasın), bir kez yazılır, hemen `Save`. Yeni profil = `SessionLoadCount == 1`. |
| Bağlantı | `RoundService.observe`, `Main.server` | Her tur çağrısından sonra ölçüm gözlemcisi (pcall); giriş `PlayerAdded`'da hemen, profil yüklenince ikinci adım, çıkış `PlayerRemoving`'de. |

Testler: `tests/olcum/core.spec.luau` (çekirdek, 15), `tests/olcum/olcum.spec.luau` (akış + Okuma tablosu, 47). Toplam (bütün depo) 154 test yeşil.

- Okuma testleri bir "test günü" simüle eder: 9 oyuncu, iki sunucu (dolu / tek kişilik), gerçek tur makinesiyle; tek başına giriş, dolu sunucu, reveal sırasında geç giren izleyici, boş teslim, süre dolunca teslim, iptal edilen tur (herkes boş), teslimden sonra çıkış, sahibi çıkmış çizimin reveal'ı, oylar (sahibin kendi oyu, nötr emoji), aynı gün tekrar giriş, gece yarısı dönüşü, gece yarısını çıkmadan geçme, profil okunamayan, F-001'den eski profil.
- Pay/payda: D1 1/7 (Wilson 0.026–0.513) · ortalama oturum 1750/7, tüm oturumlar 1930/9 · ilk 60 sn 1/7 · 5. dk 4/7 · ilk tur 3/7 · zincir 4·4·3·1 /7 · oylama anı 4/7 · başlayan maç 4/7 · bekleme 91/4 · tek başına 4/7, Eslesme hayır 3/7 · **nerede çıkılıyor** lobi 4, çizimde teslimsiz 2, teslimden sonra 1 · **teslim** ortalama 36 sn (12 teslim), düğme 11 / süre doldu 1, çizgi 0:6 · 1-10:5 · 11-40:1 · **reveal ilgisi** CizimTepki ortalaması `2-3` kovasında 30 (5 çizim), `1` kovasında 0 (sahibi çıkmış 1 çizim) · **etiketli dilim** bütün olaylarda (D1 1/2, oturum 280, BesDakika 1/2, TurBasladi/IlkReveal/TurTamam 1, Eslesme hayır 1, Teslim 15 sn, CizimTepki 58,5).
- Gizlilik testi: gönderilen hiçbir olayın adında, değerinde ya da alanında kullanıcı numarası (ya da son 4 hanesi) veya adı yok; alan anahtarları yalnız `CustomField01..03`.
- Studio (Play, tek oyuncu, çıkış; ikinci adımda): `[Analitik] Eslesme deger=16 eslesti=hayir kohort=bilinmiyor/bilinmiyor ilk_oturum=hayir` ve `[Analitik] Cikis deger=16 kohort=bilinmiyor/bilinmiyor oturum_tipi=donus faz=lobi`. Adam'ın hesabı F-001'den eski profil olduğu için IlkGiris yok; doğru. Tur, Teslim ve CizimTepki Studio'da denenmedi: istemci arayüz bağlaması eksik (Binder 37 işaret), Ready gelmiyor.

## Devam: K-008, T-021 eklemeleri, T-017

- **K-008:** kohort alanı `gün/kaynak` (ör. `2026-11-20/etiketli`); kohort taşıyan 10 olayın hepsinde bu alan var, ayrı kaynak alanı kalmadı (test zorlar). IlkGiris, D1Donus, BesDakika bir alan boşalttı.
- **Kohort gün aralığı:** 2026-11-20 – **2027-02-28** (önce 2027-03-31). Cikis'in değer birleşimi 8000'i geçmesin diye; test zorlar. Üçüncü adımda kohort listesi yalnız oluşabilen değerlere indi (gün × {etiketli, etiketsiz}, `aralik_disi` × 2, tek `bilinmiyor/bilinmiyor`): faz 6 değere çıkınca Cikis 205 × 5 × 6 = 6.150. Aralık bu yöntemle en çok 2027-03-30'a uzayabilir. Aralık dışı gün `aralik_disi/<kaynak>` olarak gider.
- **Cikis faz:** çıkış anındaki aşama. Çıkış turu ilerletse de (son bekleneni çıkınca reveal başlar) çıkıştan önceki faz yazılır; bu yüzden faz her tur çağrısından sonra saklanır.
- **Teslim:** "nasıl" sunucuda teslimin geldiği aşamadan çıkar: çizim aşaması = düğme, toplama aşaması = süre doldu (istemci `Collect` gelince kendisi gönderir, `DrawingScreen:collect`). Değer, 3-2-1 sayımı bitip çizim açıldığı andan (startsAt, T-022) sayılır.
- **CizimTepki:** her çizimin gösterimi bitince sahibine. Payda = o çizim gösterilirken en az bir an hazır olan, sahibi dışındaki oyuncular; "ekrandaki oyuncu kovası" bu sayı. Payda 0 ise gitmez. Üçüncü adımda: sahibi çıktıysa sunucuda en erken girmiş oyuncuya bağlanır (LEAK `forTable`), `sahibi_cikti = evet`, kohort sahibinin (çıkarken saklanır, tur bitince silinir); sunucuda kimse yoksa gitmez.
- **CizimdeCikis** (dördüncü adım, `1cde1af`): çıkıştaki faz `cizim_teslimsiz` ise Cikis'ten önce gider; değer = 3-2-1 sayımı bitip çizimin açıldığı andan (T-022; geç katılan için tura girdiği andan) çıkışa sn; sayım sırasında çıkan 0. Teslim edilmemiş çizimin çizgi sayısı sunucuda yoktu: istemci Round kanalında `Progress {strokes}` bildirir (çizgi sayısı değişince, en sık `Round.ProgressSendSeconds` = 2 sn'de bir; sunucu sayıyı 0–80 tam sayı olarak doğrular, oyuncu başına `ProgressAcceptSeconds` = 1 sn sınırı). Son bildirimden sonraki birkaç saniyenin çizgileri eksik kalabilir. Birleşim 5 × 205 × 3 = 3.075. Okuma: çizgi kovası dağılımı; test gününde 0 çizgi 1, 11-40 1.
- **T-017:** `ReplicatedStorage.Packages` (içinde yalnız GameAnalytics 2.2.6 ve `_Index`; 21 ModuleScript, hiç Script/LocalScript yok, place'te onu require eden kod yok) **ServerStorage.Packages**'a taşındı, silinmedi. Play'de doğrulama: istemcide paket yok (ServerStorage boş, ReplicatedStorage.Packages yok); sunucuda yalnız paketin kendi modülleri var, GA'nın yüklenince kurduğu nesnelerden hiçbiri yok, Output'ta GA satırı yok. Değişiklik Studio'da, place kaydedilmedi (publish de yok): Adam kaydedince kalıcı olur.

## Koddaki okumalar (T-021'de açık yazmayan, karar değil)

- **Eski F-001 profili** (profil var, ilk giriş kaydı yok): yeni sayılmaz; kohort `bilinmiyor/bilinmiyor`, oturum tipi `donus`. Kayıt yazılmaz.
- **D1Donus** oturumun giriş gününe bakar; gece yarısını oyundan çıkmadan geçen oturum (ilk ya da sonraki) D1 saymaz.
- **Etiketli** = LaunchData boş olmayan herhangi bir metin. LEAK'teki gibi kampanya adı listesi yok; ham metin hiçbir alana girmez.
- **LaunchData** girişte ve profil yüklenince okunur; geç gelirse kaçar (BORC).
- **o_an "turda"**: o anki turun katılımcısı (çizim, toplama, reveal, podyum dahil). Hazır olmayan oyuncu reveal görmüş sayılmaz.
- **Tur sırası** izlenen turları da sayar (T-021 R1 = tur sırası 1 her katılımla).
- **Faz:** üçüncü adımdan beri çizim ve toplama aşamasında turda olmayan oyuncu `izliyor` (T-021); reveal ve podyumda faz herkes için aynı.
- **Teslim "süre doldu"**: son saniyede basılan düğme gecikmeyle toplama aşamasına düşerse süre doldu sayılır.

## Madde 6 — LEAK TEST1–2'de LaunchData etiketi

Kaynak: `Oyunlar\LEAK\rapor\AnalitikRaporlar\2026.11.06-TEST1\veri.md`, `2026.11.07-TEST2\veri.md`. LEAK'te "yeni oyuncu" = H1 hunisinin ilk adımı (HubArrival, kayıtta `seen` yok); etiket huninin Custom field 1'i.

| Test | Yeni gelen (HubArrival) | Etiketli | Pay | Not |
|---|---|---|---|---|
| TEST1 | 197 | 34 (KAPAK-A 9 + KAPAK-B 25) | %17 | Huni "Last 7 days", veri 06.11 08:00'de kesilmiş (kampanya sürerken; reklam öncesi yeni gelenler dahil). Ads Manager'ın son Plays değeri 196 (43 + 153), farklı ölçü ve farklı anda. |
| TEST2 | 1.918 | 321 (KAPAK-B) | %16,7 | Huni 11/7–11/9 (kampanya 07.11 19:00 öncesi saatler dahil). Ads Manager Plays 1.613; 321 / 1.613 ≈ %20, ama Plays tekil yeni oyuncu değil. |

"Reklam döneminde gelen yeni oyunculardan kaçı reklamla geldi" verisi yok: etiketsiz (`organik`) grubu reklamla gelip oyun sayfasından Play'e basanları da içeriyor, Acquisition ekranı (TEST1 ekran 47–48) o gün boştu (bütün kaynaklar 0). Bulunabilen: yeni gelenlerin yaklaşık **%17'si** etiket taşıdı; reklamla gelenlerin ne kadarının etiket taşıdığı **yok**.

## Madde 7 — Prova listesi (yayınlanmış oyunda, reklamdan önce)

Hazırlık: 5 yeni alt hesap (A, B, C, D, E; oyuna hiç girmemiş; E telefonda) + Adam'ın hesabı. Adım 10 T-021 Kısıt'ındaki "bir tur telefonda baştan sona"; Explore sayıları adım 1–9 içindir (E ayrı sayılır). Prova günü = G (UTC). Saatler UTC.
Tur için en az 2 hazır oyuncu varsayıldı (`MinPlayers`; depoda yerel değişiklik olarak 1 duruyor, commit edilmedi; yayında kaç olduğunu kontrol et).

| # | Ne yapılır | Beklenen olaylar |
|---|---|---|
| 1 | A, `https://www.roblox.com/games/72378550860176?launchData=PROVA` ile, boş sunucuya girer; 40 sn sonra çıkar | IlkGiris deger 1 kohort `G/etiketli` · Eslesme hayir ~40 · Cikis ilk_0-60 faz lobi |
| 2 | B boş sunucuya girer; 20 sn sonra C aynı sunucuya (arkadaşa katıl). Tur 1: B çizip Submit'e basar; C hiçbir şey yapmaz, süre dolar | IlkGiris B 1, C 0 · Eslesme B evet ~20, C evet 0 · TurBasladi B, C · Teslim B dugme, C sure_doldu cizgi 0 |
| 3 | Tur 1'in reveal'ı sırasında D girer; B'nin çizimine C bir emoji, D nötr emoji basar | IlkGiris D 0 · IlkReveal D izleyici · CizimTepki B 100, ekrandaki 2-3 · TurTamam B, C bos_teslim, D izledi (sıra 1) |
| 4 | Tur 2'de B, C, D çizip Submit'e basar; birkaç emoji | Teslim dugme ×3 · CizimTepki ×3 (2-3) · TurTamam sıra 2 ×3 |
| 5 | Tur 3 sürerken, D girişinden 5 dk geçtikten sonra: D teslim etmeden çıkar; C teslim edip çıkar; B teslim eder, reveal sırasında çıkar | BesDakika B, C, D · Cikis D cizim_teslimsiz, C teslim_sonrasi, B reveal (üçü ilk_300+) · Teslim C, B dugme · tur 3'te CizimTepki ve TurTamam yok (B kendi çiziminin gösteriminde çıkarsa sunucuda tepki verecek kimse kalmaz) |
| 6 | A aynı gün tekrar girer, çıkar | Cikis donus · D1Donus yok |
| 7 | B, G 23:50'de girer, 23:55'te çıkar; G+1 00:05'te tekrar girer | G+1 girişinde D1Donus (kohort `G/etiketsiz`) |
| 8 | C, G 23:55'te girer, G+1 00:05'e kadar çıkmadan kalır; G+1'de bir daha girmez | D1Donus yok · Cikis donus |
| 9 | Adam'ın hesabı girer, çıkar | Cikis kohort `bilinmiyor/bilinmiyor`, oturum_tipi donus · IlkGiris yok |
| 10 | Bir telefonla (yeni alt hesap E ve bir arkadaş) bir tur baştan sona: sayım, çizim, Submit, reveal, emoji, podyum; ikinci turda E çizerken (birkaç çizgi sonra, teslim etmeden) oyundan çıkar | E için IlkGiris … TurTamam sıra 1 · CizimdeCikis cizgi 1-10 (ya da bildirim gecikmesiyle 0) · Cikis faz cizim_teslimsiz |

**View Events'te tek tek** (her olay en az bir kez, alanları SOZLUK'teki sırayla): IlkGiris (A, B, C, D; 4) · D1Donus (B; 1) · Cikis (A ×2, B ×3, C ×2, D, Adam) · BesDakika (B, C, D) · Eslesme (her oturumda bir) · TurBasladi (B, C, D) · IlkReveal (B, C, D) · TurTamam (sıra 1 ×3, sıra 2 ×3) · Teslim (7: tur 1 ×2, tur 2 ×3, tur 3 ×2) · CizimTepki (4) · CizimdeCikis (D, tur 3; E, adım 10). Ayrıca: A'nın kohortu `G/etiketli`; hiçbir alanda ad ya da numara yok.

**Explore'da pay ve payda** (kohort = `G/…`, tekil kullanıcı): IlkGiris 4 · D1 1/4 · ilk 60 sn 1/4 · 5. dk 3/4 · ilk tur tamamlama 2/4 (D izledi, sayılmaz) · R0/R1/R2/R3 3/4, 3/4, 3/4, 0/4 · oylama anı 3/4 · başlayan maç 3/4 · IlkGiris ortalaması 0,5 · Eslesme hayır (ilk oturum) 1/4 · faz (ilk oturum) lobi 1, cizim_teslimsiz 1, teslim_sonrasi 1, reveal 1 · Teslim nasıl dugme 6 / sure_doldu 1 · etiketli (`G/etiketli`): IlkGiris 1, D1 0/1, öteki olaylar 0. Ortalama oturum, bekleme, teslim süresi ve CizimTepki değerleri: o günün süreleri ve basılan emojilerle elle karşılaştır.

**Panel:** Creator Hub'daki hazır Day 1 retention kartına erişim var mı, G kohortunu gösteriyor mu (STANDART §6.1).
