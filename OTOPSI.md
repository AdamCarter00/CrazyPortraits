# F-001 Crazy Portraits — teknik otopsi

Tarih: 2026-11-19 · Kaynak: Studio'daki place "Crazy Portraits (ALPHA)" (placeId 72378550860176), MCP ile yalnız okundu.
Place'te hiçbir şey değiştirilmedi, çalıştırılmadı. Bütün kanıtlar `snapshot/` (commit "F-001 snapshot 2026-11-19") içinden.
`?` = koddan çıkmıyor.

**Kısaltmalar** (dosya:satır için):
`SSS/` = `snapshot/ServerScriptService/` · `RC/` = `snapshot/StarterPlayer/StarterPlayerScripts/RoundClient/` · `RM/` = `snapshot/ReplicatedStorage/Modules/` · `K` = `RM/Constants.luau`

---

## Harita

Ayrıntılı ağaç ve her script'in görevi: `snapshot/_harita.md`. Remote'lar, store'lar, ürün ID'leri ve GUI ağacı: `snapshot/_veri.md`.

Kısa özet: tek sunucu girişi `SSS/GameServer.server.luau`, bütün oyun döngüsü `SSS/Round/init.luau` (1095 satır) içinde, tek istemci girişi `RC/init.client.luau`. 60 script kopyalandı. **Kopyalanamayan**: GameAnalytics SDK 2.2.6'nın 20 iç modülü (klasör adındaki `@2.2.6` noktaları yüzünden MCP okuyamıyor; Wally'den yeniden indirilebilir).

Tur fazları (sunucu): `Waiting → DRAWING_PHASE → COLLECTING_PHASE → REVEAL_INTRO_PHASE → REVEAL_PHASE (çizim başına) → CLEAN_ROUND_PHASE → Waiting`.

---

## A · Giriş ve ilk dakika

**1. İlk 60 saniye**
1. Sunucu, sırayla ve beklemeli: ban kontrolü (DataStore okuma) → ProfileStore profili (açılamazsa oyuncu atılır) → 4 Game Pass sahiplik sorgusu → `RoundManager:OnPlayerAdded` (`SSS/GameServer.server.luau:85-131`, `SSS/PlayerDataService.luau:120-133`, `SSS/FrameShopService.luau:119-128`). Karakter SpawnLocation'a ışınlanır (`GameServer.server.luau:55-74`).
2. `OnPlayerAdded`: A/B grubu, oturum sayacı (async), önceki turun galerisi varsa gönderilir, şans çubuğu yayılır (`SSS/Round/init.luau:392-431`).
3. İstemci: "Game Loading..." ekranı **en az 5 sn** (`K:48`, `RC/Core/RefsBuilder.luau:333-346`). Sonra PhaseGui "Waiting for players", kenar çubuğu (Yıldız, "CHANCE TO BE DRAWN", Market, Invite), lobi müziği (`RefsBuilder.luau:353-363`).
4. İstemci `ReadyRemote`'u ateşler (`RC/init.client.luau:217`). Sunucu `Waiting` fazındaysa `TryStartRound`: hazır oyuncu ≥ 2 ise herkese "Round starting in Ns" geri sayımı (15 sn) (`SSS/Round/init.luau:556-570`, `RC/Phases/WaitingController.luau:39-50`). < 2 ise hiçbir şey gönderilmez; ekran "Waiting for players"ta kalır.
5. 15 sn sonra `DRAWING_PHASE`: model seçilir, herkese tema, 3 sn geçiş perdesi, sonra 90 sn çizim (`Round/init.luau:576-645`).
- Yani 2. oyuncu hazırsa en erken çizim ≈ giriş + 5 + 15 + 3 ≈ **23 sn**; ilk gösterim ≈ **~2 dk** (90 sn çizim + toplama + 3 sn intro). Tek başınaysa ilk 60 saniyede oyun hiç başlamaz.

**2. Tur ortasında giren** (`SSS/Round/RoundRemotes.luau:102-122`)
- Çizim fazı ve **60 sn'den fazla** kaldıysa: hemen çizime katılır, kendi teması verilir, süre kalan kadar (`RoundRemotes.luau:48-69`, `K:45`).
- Çizim fazında ≤ 60 sn kaldıysa veya toplama fazındaysa: **izleyici** olur ("WAITING_PHASE" ekranı, gösterimi izler ve emoji atabilir; analitikte sayılmaz) (`RoundRemotes.luau:82-100`).
- Gösterim/oylama (REVEAL_INTRO, REVEAL) veya CLEAN fazında girerse: düz "Waiting for players" ekranı, geri sayım yok; bir sonraki turu bekler ve otomatik dahil olur (`RoundRemotes.luau:118-121`, `Round/init.luau:987-988`). Bu sırada emoji yağmurunu görür (emoji herkese yayılıyor, `Round/init.luau:1031-1035`) ama ekrandaki çizimi görmez.

**3. Sabitler** (hepsi `RM/Constants.luau`)
| Ne | Değer | Satır |
|---|---|---|
| En az oyuncu | 2 | `K:26` |
| Yükleme ekranı (en az) | 5 sn | `K:48` |
| Lobi geri sayımı | 15 sn | `K:54` |
| Geçiş perdesi (çizim başı öne kaydırılır) | 3 sn | `K:65`, `Round/init.luau:614` |
| Çizim | 90 sn (Submit düğmesi 1 sn sonra görünür) | `K:49-50` |
| Toplama (çizim tamponu bekleme) | en fazla 7 sn | `K:51` |
| Gösterim girişi | max(2, 3) = 3 sn | `K:52`, `Round/init.luau:781` |
| Gösterim + oylama | çizim başına 5 sn (ayrı oylama fazı yok) | `K:53` |
| Sonuç ekranı | 3,3 sn gecikme + 3 + 0,5 + 3 + 0,5 sn | `K:96-99`, `Round/init.luau:949` |
| Ara katılım eşiği | > 60 sn kalmışsa | `K:45` |

---

## B · Boş sunucu

**4. Tek kişi**: Bot yok, yönlendirme yok, özel mesaj yok. Ekranda yalnız "Waiting for players" (`RefsBuilder.luau:356`); `TryStartRound` 2'nin altında sessizce döner (`Round/init.luau:562`). Şans çubuğu tek kişide %100 gösterir (`SSS/SubjectService.luau:282-301`). Yapılabilecekler: Invite düğmesi (`RC/Modules/UIController.luau:373-383`), market, trambolin, önceki turun galerisi (sunucu yeni açıldıysa boş). Ek olarak:
- Tur ortasında 1 kişi kalırsa tur iptal edilmez, sonuna kadar oynanır. Bitince tek kalan "Round over" yazısında takılır; "Waiting for players"a dönülmez (`RC/Phases/CleanRoundController.luau:36`, `Round/init.luau:988` → `:562`).
- Geri sayım sırasında oyuncu sayısı 2'nin altına düşerse tur başlamaz ama ekran "Round starting in 0s"ta donar; yeni biri gelene kadar düzelmez (`Round/init.luau:580`, `WaitingController.luau:46`; `OnPlayerRemoving` yeniden yayın yapmıyor `:433-550`).

**5. Eşleştirme**: TeleportService, MemoryStore, sunucu seçimi yok (oyunun kodunda ve SDK'da grep: 0 sonuç). Sunucu boyutu (MaxPlayers): `?`. Haritada 8 gösterim koltuğu ve 8 galeri noktası var, kod yorumu "lobi koltuk sayısıyla sınırlı" diyor (`Round/init.luau:180`); 8 olduğu tahmin, kodda kesin değil.

---

## C · Tur, tema ve oylama

**6. Model seçimi** (`SSS/SubjectService.luau:244-265, 341-375`)
- Ağırlıklı rastgele: ağırlık = (seçilmeden geçen tur sayısı + 1). Seçilenin sayacı 0'lanır. **Bir önceki model aday değil** (art arda olamaz, `:361`).
- 2 kişilik sunucuda bu, katı sırayla dönüşmek demek.
- Ücretli garanti: kuyruğun başındaki alıcı hazırsa ağırlıklı seçim atlanır, "art arda olamaz" kuralı da delinir (`:351-357`, `Round/init.luau:586-599`).
- Model gerçek oyuncu değil, karakterinin klonu: SubjectPart üzerinde idle animasyonla durur, gösterim başında silinir (`SubjectService.luau:224-242, 377-383`).

**7. Tema** (`SSS/ThemeService.luau:9-33`)
- 18 tema, kodda sabit. Tur içinde herkese **ayrı** tema verilir (havuzdan tekrarsız çekilir); bir oyuncu bütün temaları görene kadar aynısını tekrar almaz (`ThemeService.luau:39-73`, `Round/init.luau:107-138, 618-628`).
- **Ama tema sistemi kapalı**: `THEME_ENABLED = false` (`K:119`). Ekranda yalnız "Draw <isim>" / "Draw yourself" yazar (`RC/Phases/DrawingController.luau:155-170`).
- Tema yine de hesaplanır, gösterime gönderilir, rapor ve ilk çizim kayıtlarına yazılır. Oyuncu temayı hiç görmez.

**8. Oylama**
- Emojiler: `laugh`, `skull`, `shocked`, `normal` (`K:123-128`; GUI düğme adları aynı). Negatif emoji yok; `normal` nötr (puan vermez) (`K:190-194`).
- Her çizim 5 sn ekranda; oyuncu çizim başına istediği kadar basar (0,3 sn bekleme), **yalnız son seçimi** sayılır. Kendi çizimine oy veremez (`SSS/Round/RoundRemotes.luau:132-144`, `Round/init.luau:1012-1029`).
- Puan: çizim sahibine **20 Yıldız taban + pozitif tepki başına 1 Yıldız** (`K:188-189`, `Round/init.luau:832-865`). Çizimi boş olan gösterilmez, ödül almaz (`Round/init.luau:95`).
- **Kazanan yok.** Sıralama, birinci, podyum hesaplanmıyor. Her sahip turda yalnız kendi sonucunu görür ("You Got": tepki sayıları + Yıldız) (`Round/init.luau:947-966`, `RC/Modules/ResultController.luau`).
- Gösterimde çizimin sahibinin adı ve tema gösterilmiyor (`RC/Phases/RevealController.luau:19-39`). İsimler yalnız sonra lobi galerisinde çıkıyor (`RC/Modules/GalleryController.luau:100-102`).
- Gösterim sırası: hazır olma sırası (Players listesi), karıştırılmıyor (`Round/init.luau:91-105`).

---

## D · Kalıcılık ve geri gelme

**9. DataStore**
- Profil (`PlayerData_v2`, ProfileStore): `stars`, `subjectGuarantee` (bool), `ownedFrames`, `equippedFrame`, `seenTutorial`, `dailyMissions` (artık kullanılmıyor) (`SSS/PlayerDataService.luau:29-62`).
- Ayrı store'lar: oturum sayacı, ban, admin denetim kaydı, raporlanan çizimler + dizin + rapor denetim izi, çizim ortası çıkış kaydı, ilk kez gelenlerin ilk çizimi (`K:321-337`, liste `snapshot/_veri.md`).
- **Kaydedilmeyenler**: oylar, tepki geçmişi, kazanma (zaten yok), oynanan tur sayısı, oyuncunun kendi çizimleri (ilk kez gelenin ilk çizimi ve raporlananlar hariç).
- Tur bitince kalan: Yıldız bakiyesi (profilde). Galeri (son turun ≤ 8 çizimi) yalnız sunucu belleğinde, sunucu kapanınca gider (`Round/init.luau:745-749`).

**10. Geri çağıran şeyler**
- Var: Yıldız → kozmetik çerçeve (başkalarının gösteriminde görünür, `RC/Modules/FrameController.luau:44-78`), lobide son turun galerisi, bir kerelik öğretici (`K:112`, `Round/init.luau:920-926`), davet düğmesi.
- Yok: günlük ödül (günlük görevler arşivlenmiş, `PlayerDataService.luau:50-59`), rozet (BadgeService grep: 0), seviye, koleksiyon, kişisel galeri/portfolyo.

---

## E · Para

**11. Ürünler** (fiyatlar kodda ve place'te yok: `?`)
| Ürün | Tür / ID | Ne yapar | Nerede, ne zaman |
|---|---|---|---|
| "BE NEXT DRAWN" | Developer Product 3606209956 (`K:200`) | Profilde garanti bayrağı + FIFO kuyruğa ekleme; bir sonraki tur başında model olursun (`SSS/SubjectGuaranteeService.luau:36-56`) | Kenar çubuğundaki SubjectFrame düğmesi, her zaman görünür (çizim sırasında ve gösterimde kenar çubuğu gizli) (`RC/Modules/SubjectController.luau:37-47`, `DrawingController.luau:146,218`, `RevealController.luau:30`). Otomatik teklif yok. |
| Cute / Gold / Goofy / Dark çerçeve | Game Pass 1891548320 / 1893605960 / 1893947553 / 1893282287 (`K:264-269`) | Çerçeveyi verir ve takar; alternatif olarak 150 Yıldız (`K:249-256`) | Market → çerçeve kartındaki Robux düğmesi (`RC/Modules/MarketController.luau:65-69`). Otomatik teklif yok; Market düğmesinde yanıp sönen "NEW" etiketi var (`UIController.luau:321-325`). |
| Wood / CardBoard | yalnız 20 Yıldız | çerçeve | Market |

- Game Pass satın alımı istemci tarafında `PromptGamePassPurchase`, sunucu `PromptGamePassPurchaseFinished` ve girişte `UserOwnsGamePassAsync` ile verir (`SSS/FrameShopService.luau:89-128`).
- **Hata**: garanti bir bool. Zaten garantisi olan biri tekrar satın alırsa Robux düşer ama hiçbir şey eklenmez; istemci düğmesi sahipliği kontrol etmiyor (`PlayerDataService.luau:242-247`, `SubjectGuaranteeService.luau:46-55`, `SubjectController.luau:39-47`). `K:196-199`'daki "tekrar tekrar alınabilir" yorumu davranışla çelişiyor.

**12. "Sıradaki model sen ol" ne zaman anlamlı**
- 2 kişilik sunucu: anlamsız. Önceki model aday olamadığı için diğer oyuncu zaten %100 seçilir (`SubjectService.luau:361`). Ürün burada yalnız "art arda iki kez model olmak" işine yarar.
- 3+ kişide anlam kazanır; 5-8 kişide en değerli olur (ağırlık mantığından çıkarım; oran verisi yok: `?`).
- Teklif ne zaman çıkıyor: bağlama göre hiç çıkmıyor. Düğme lobide hep orada, satın alma her an mümkün, bir sonraki `StartDrawingPhase`'de uygulanır.
- Şans çubuğu garanti kuyruğunu bilerek yok sayar: alıcı bile %100 görmez (`Round/init.luau:307-320`).

---

## F · Ölçüm

**13. Gönderilen analitik olaylar**: GameAnalytics SDK 2.2.6 kullanılıyor (`SSS/AnalyticsService.luau`). Roblox AnalyticsService kullanılmıyor (grep: 0).
| Olay | Ne zaman | Kaynak |
|---|---|---|
| `Round:Phase:Drawing` / `Collecting` / `RevealIntro` / `Reveal` / `RoundComplete` | her faz başında, oyuncu başına | `Round/init.luau:631,667,773,788,917` |
| `Round:Subject`, `Round:SubjectQuit` | tur başına bir; model çizimde çıkarsa | `Round/init.luau:639,522` |
| `Drawing:SubmitTime` (+ 5 sn'lik kutular) | Submit'e basınca | `RoundRemotes.luau:165`, `AnalyticsService.luau:167-176` |
| `Session:RoundsPlayed{A\|B}` (+ `:0`…`:20Plus`) | **çıkışta** | `Round/init.luau:505`, `AnalyticsService.luau:182-192` |
| `Session:RoundsPlayedBuyer{A\|B}` | çıkışta, o oturumda çerçeve alanlar için | `Round/init.luau:513-515` |
| `Session:StarsEarned` | çıkışta | `Round/init.luau:512` |
| `Session:Quit:{QuitAfterSubmit\|QuitMidRound\|QuitAfterRound\|QuitAlone\|QuitFromLobby}{A\|B}` + faz / süre kutuları | çıkışta | `Round/init.luau:458-506`, `AnalyticsService.luau:241-274` |
| `Market:Opened` (oturumda bir), `Shop:FrameBought` | market / alım | `FrameShopService.luau:132-136, 70, 101` |
| Hata olayları | hata yollarında | `AnalyticsService.luau:280-295` |
| SDK'nın kendisi: oturum başı/sonu, Game Pass alımı | otomatik | Studio: `…gameanalytics-sdk.GameAnalytics` satır 894, 1049 (snapshot'ta yok) |

GA dışı araştırma kayıtları (DataStore, Open Cloud ile okunuyordu): `QuitLog` (çizimde Submit'siz çıkanlar, `SSS/QuitLog.luau`), `FirstDrawingService`, `SessionService`.

Tur hunisi (R0→R1→…): ayrı bir huni olayı yok. `Session:RoundsPlayed{grup}:{n}` kutularından, yani **çıkış anında** gönderilen "bu oturumda kaç tur tamamladı" sayısından türetiliyordu (`AnalyticsService.luau:182-192`). Faz bazında `Round:Phase:*` sayımları da kullanılabiliyordu. A/B grupları yalnız etiket; oynanış aynı (`SSS/GroupService.luau:4-7`).

Ölçüm tutarsızlıkları:
- İzleyiciler `Collecting` olarak sayılıyor, diğer fazlarda sayılmıyor (`Round/init.luau:665-668` ile `:772` karşılaştır).
- Ara katılımla çizime girenler `Drawing` olarak hiç sayılmıyor (`RoundRemotes.luau:62-68`).
- Developer Product geliri GA'ya gitmiyor: SDK'nın `ProcessReceiptCallback`'i çağrılmıyor (`SubjectGuaranteeService.luau:36-56`).

**14. Yeniden yapımda kesin gerekli olaylar** (bugün hiçbiri yok)
- `Join` (UserId, sunucudaki oyuncu sayısı, ilk oturum mu, **kaynak**: `GetJoinData`/launchData/reklam parametresi. Koddaki grep: 0, yani reklamsız/reklamlı ayrımı yapılamıyordu).
- `Ready` (yükleme bitti, girişten itibaren sn).
- `LobbyWaitEnded` (geri sayım başladı veya oyuncu çıktı; **yalnız bekleme süresi** + kaç kişi beklediği). Bugün yalnız çıkışta `QuitAlone` değeri olarak var.
- `FirstDrawStart` / `FirstStroke` (girişten sn), `Submit` (var), `DrawingCollected` (boş mu).
- `FirstRevealSeen` (girişten sn), `VoteCast` (emoji, çizim sırası; bugün emoji için hiç olay yok), `ResultSeen`.
- Tur indeksli huni: tur başlangıcında `RoundStart{n}`, bitişte `RoundComplete{n}` (çıkışı beklemeden).
- Para: `OfferShown` / `PromptOpened` / `PurchaseCompleted` (Developer Product dahil), ürün ve bağlam.
- Sunucu sağlığı: oyuncu sayısı zaman serisi, 1 kişilik sunucuda geçen süre.

---

## G · İçerik güvenliği

**15. Moderasyon**
- **Raporlama**: gösterimde Report düğmesi. Raporlayan için çizim anında "Drawing Hidden" ile kapanır (`UIController.luau:279-285`). Kişi başına çizim başına bir rapor; sahibi raporlayamaz (`Round/init.luau:1042-1068`).
- **Eşik**: 4 farklı raporcu → çizim herkesten gizlenir ve galeriden düşer (`K:272`, `Round/init.luau:1077-1086, 343-355`). Sahip raporlayamadığı için **5 kişiden az sunucuda eşik hiç dolmaz**.
- Her rapor DataStore'a yazılır (panel satırı + raporcu bazında denetim izi) (`SSS/ModerationService.luau:56-119`).
- **Admin**: `/panel` (raporları gör, dismiss, ban 1s/1g/7g/30g/kalıcı), `/drawings` (ilk çizimleri gez); beyaz liste koda gömülü (`SSS/AdminService.luau:35-37`). Ban MessagingService ile bütün sunuculara yayılır, oyuncuyu atar, çizimlerini gösterim ve galeriden çeker (`SSS/BanService.luau:84-98`, `Round/init.luau:361-390`). Ban okuması hata verirse oyuncu içeri alınır (fail-open, `BanService.luau:174-182`).
- **Yok**: otomatik görüntü filtresi, oylayarak atma, çizimde metin (o yüzden metin filtresi gerekmiyor).

---

## H · Yeniden kullanılabilirlik

**16. Modüller**
| Olduğu gibi (ya da çok az değişiklikle) kullanılabilir | Neden |
|---|---|
| `RM/StrokeCodec.luau`, `RM/FloodFill.luau`, `SSS/StrokeValidator.luau` | Saf buffer mantığı, Roblox API'si yok (yalnız `warn`). Lune'da test edilebilir. Kalite iyi, limitler sınanıyor. |
| `RM/DrawRenderer.luau` | Canvas ile gösterimin piksel-aynı olması iyi çözülmüş. EditableImage'a bağlı, Lune'da mock gerekir. |
| `SSS/ThemeService.luau`, `SSS/GroupService.luau`, `SSS/DataStoreRetry.luau`, `RC/Core/Signal.luau`, `RC/Core/PhaseRouter.luau` | Küçük ve saf. ThemeService'e RNG enjekte edilirse test edilebilir. |
| `SSS/ProfileStore.luau` | Üçüncü parti, sürümü takip edilerek paket olarak alınmalı. |
| `SSS/PlayerDataService.luau`, `SSS/BanService.luau`, `SSS/AdminService.luau` + admin paneli | Çalışıyor ve savunmacı yazılmış. Şema temizliği gerekir (`dailyMissions`, bool garanti). |
| `RC/Modules/CanvasController.luau`, `InputController.luau`, `RC/Modules/PassController.luau` | Mantık sağlam ama Studio'da elle yapılmış GUI adlarına bağlı. GUI Rojo'ya (.rbxm/.model.json) veya koddan kuruluma taşınınca kalır. |

| Baştan yazılmalı | Neden |
|---|---|
| `SSS/Round/init.luau` (+ `RoundRemotes`, `RoundState`) | 1095 satırlık tek modül: durum makinesi, zamanlama, analitik, ödül, rapor, galeri, ışınlama iç içe. Zamanlama `task.delay` zincirleri ve token'larla dağınık. Saf bir durum makinesi + zamanlayıcı + yan etki katmanı olarak bölünmeli; şu hâliyle test edilemez. A/B kırılgan noktalarının çoğu burada (17. madde). |
| `SSS/AnalyticsService.luau` | Olay şeması kuyruk sonrası (çıkışta) ve grup son ekli. 14. maddedeki huni şemasıyla yeniden kurulmalı. |
| `SSS/SubjectService.luau` | Klon/animasyon kısmı alınabilir. Seçim mantığı saf fonksiyona çıkarılmalı; 2 kişilik dönüşüm ve garanti etkileşimi tasarım kararı olarak yeniden ele alınmalı. |
| `RC/Core/RefsBuilder.luau`, `RC/Modules/UIController.luau` | Yüzlerce `WaitForChild` ile Studio'daki GUI ağacına bağlı; ölü dallar var. |
| `RC/Modules/AdminPanelClient.luau`, `RC/Modules/DrawingsPanelClient.luau` | Bayt bayt kopya ve kimse require etmiyor; silinmeli. |

Rojo uyumu: modüller göreli `script.Parent` require'ları kullanıyor, Rojo'ya uygun. Yorumlar bu kodun bir zamanlar diskte Rojo deposu olarak durduğunu gösteriyor: `SSS/AnalyticsService.luau:5,9` ("Round/init.luau", "Rojo does not manage ServerStorage"), `SSS/PlayerDataService.luau:50` ("_archive/README_missions.md"). O depo bulunursa geçmişiyle birlikte daha değerli olur: `?`. `Proje/` klasörü şu an boş şablon (`Proje/default.project.json`).

**17. Bilinen hatalar ve kırılgan yerler**
1. **Çizim erken bitmiyor**: herkes Submit'e bassa bile 90 sn'nin tamamı beklenir. Submit yalnız bekleme pedine ışınlar; "hepsi gönderdi" kontrolü yalnız toplama fazında (`Round/init.luau:1004-1006`, `:677`).
2. **Geri sayım sıfırlanıyor ama tur erken başlıyor**: geri sayım sırasında her yeni hazır oyuncu, herkese yeni bir 15 sn yayınlatır. Gerçek başlangıç ise ilk zamanlayıcıdır, yani ekranda "7s" yazarken tur başlayabilir (`RoundRemotes.luau:106-110`, `Round/init.luau:564-569`).
3. **Takılan ekranlar**: "Round starting in 0s" ve "Round over" (B·4'te anlatıldı).
4. **Hazır-yükleme yarışı**: sunucu `OnPlayerAdded`'ı ban + profil + 4 Game Pass sorgusundan sonra çalıştırıyor. Bu 5 sn'lik yükleme ekranından uzun sürerse `Ready` oyuncu durumu oluşmadan gelir. Oyuncu tura "hazır" sayılır ama DRAWING_PHASE almaz (`GameServer.server.luau:85-131`, `Round/init.luau:623-627`, `RoundRemotes.luau:59-60`). Sıklığı: `?`.
5. Çizim sunucuya yalnız toplama fazında gider; Submit edip çıkanın çizimi kaybolur (`RC/Phases/CollectingController.luau:21-32`).
6. Garanti ürününün çift satın alımı Robux yakıyor (E·11).
7. Rapor eşiği 4 → 5 kişiden az sunucuda çalışmaz (G·15).
8. `SubjectChanceRemote` hız sınırı yok: her çağrı bütün oyunculara yayın yaptırır (`RoundRemotes.luau:128-130`).
9. Çerçeve, sahibin adına göre `Players`'tan aranıyor; sahip çıktıysa varsayılan çerçeve gösterilir (`FrameController.luau:44-51`).
10. Ölü kod ve varlıklar: Market sekme bloğu (GUI'de `TopBar`/`Screens` yok, `UIController.luau:341-367`), `SubjectReleasePart` yalnız kontrol ediliyor (`SubjectService.luau:69,73`), `Rewards` sesi, `ReplicatedStorage.Frames` ve `Templates`, `dailyMissions` alanı, kopya admin istemcileri, kapalı tema sistemi, oynanışı etkilemeyen A/B grubu.
11. Eskimiş yorumlar: `StrokeCodec.luau:14` (600 px, sabit 1200), `QuitLog.luau:31` ("<=140", sınır 600), `AdminService.luau:34` (PLACEHOLDER), `Round/init.luau:1014` ("react3": arşivlenmiş görevlerden kalma). `AdminService.luau:36` yorumunda kişisel iletişim bilgisi var; depo herkese açılacaksa temizlenmeli.
12. Koddaki TODO/FIXME: yok (grep: 0).

---

## Koddan çıkan en önemli 3 bulgu

1. **Oyun yalnız kalan ya da az kişili oyuncuya hiçbir şey sunmuyor ve bekletiyor.** En az 2 kişi gerekiyor. Tek kişiye bot, pratik modu, yönlendirme ya da açıklama yok. İki kişiyle bile ilk gösterim girişten ~2 dk sonra geliyor, çünkü çizim herkes bitirse de 90 sn sürüyor. Üstüne geri sayım ve "Round over" takılmaları var (A·1, B·4, H·17/1-3).
2. **Çekirdek döngüde rekabet ve geri bildirim zayıf.** Kazanan yok. Oylar yalnız sahibine +1 Yıldız. Gösterimde kimin çizdiği ve tema görünmüyor. Tema sistemi kapalı (`K:119`), istem yalnız "Draw <isim>". Uzun vadeli tek ilerleme Yıldız → çerçeve (C·7-8, D·10).
3. **Ölçüm çıkışa bağlı, ilk dakikayı görmüyor.** Tur hunisi oturum sonunda gönderilen sayıdan türetiliyor. Giriş, ilk çizim, ilk gösterim, ilk oy, yalnız bekleme süresi ve trafik kaynağı ölçülmüyor. Developer Product geliri analitiğe gitmiyor (F·13-14). Bunlar ölçülmeden "neden kaldılar/gittiler" sorusu koddan cevaplanamaz.

## Yeniden yapımda ilk değiştirilecek 3 şey

1. **Bekleme yolunu kaldır.** Tek oyuncu için hemen oynanabilen bir yol koy (ör. NPC/sahne modelini çizme ya da eski çizimlere oy). Herkes bitirince çizimi erken bitir. Geri sayımı tek zamanlayıcıya bağla ve oyuncu sayısı düşünce lobi durumunu yeniden yayınla. *Neden:* İlk eğlenceye kadar geçen süre şu an en az ~2 dk ve tek başına sonsuz. Bu, kodun en büyük ve en kolay ölçülebilir kaybı.
2. **`Round/init.luau`'yu saf durum makinesi olarak, Rojo + Lune testleriyle baştan yaz.** StrokeCodec, FloodFill, Validator ve DrawRenderer'ı olduğu gibi taşı. *Neden:* 17. maddedeki hataların çoğu (erken bitmeme, geri sayım, takılan ekran, hazır yarışı) bu modüldeki dağınık `task.delay`/token akışından çıkıyor. Şablon (`Proje/`) Lune testleri ve Config bekliyor; mevcut yapı test edilemiyor.
3. **Ölçümü ilk dakika hunisiyle baştan kur** (14. madde: Join+kaynak → Ready → lobi beklemesi → ilk çizim → ilk gösterim → ilk oy → tur n tamamlandı; satın alma teklif/sonuç), ve olayları çıkışta değil olduğu anda gönder. *Neden:* Yeni sürümün ilk iki değişikliğinin işe yarayıp yaramadığı ancak bu olaylarla görülür. Eski sürümde bu sorular cevapsız kaldı.
