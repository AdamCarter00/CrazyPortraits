# F-001 Crazy Portraits — çekirdek bölge denetimi (gösterim, çizim, arayüz, mobil, analitik)

Tarih: 2026-11-19 · Önceki rapor: [OTOPSI.md](OTOPSI.md). Orada yazılanlar burada tekrar edilmedi, yalnız bölümüne bağlantı verildi.
`?` = koddan ya da ölçümden çıkmıyor.

**Kaynaklar**
- Kod: `snapshot/` (commit "F-001 snapshot 2026-11-19"). Kısaltmalar OTOPSI'deki gibi: `SSS/`, `RC/`, `RM/`, `K` = `RM/Constants.luau`.
- `AS` = `ServerScriptService.AnalyticsService`. **Snapshot'ta yok.** OTOPSI bu dosyaya atıf yapıyor ama dosya hiç kopyalanmamış; bu yüzden Studio'dan `script_read` ile okundu. Satır numaraları Studio'daki hâle göre.
- Canlı ölçüm: Studio'da **Clients and Servers, 2 oyuncu**, Device Emulator **iPhone 14 (yatay)** ve **iPad (yatay)**. Ekran görüntüleri: [`cekirdek-ekran/`](cekirdek-ekran/) (19 dosya). Piksel ölçüleri istemcide salt-okunur bir `execute_luau` ile alındı (`AbsoluteSize`/`AbsolutePosition`, birim = pt).
  - iPhone 14 yatay: tam ekran 843×388, güvenli alan 749 geniş, üst inset 58.
  - iPad: 1179×819.

**Yöntem ve sınırlar**
- Place değiştirilmedi ve kaydedilmedi.
- Play sırasında, yalnız oyun oturumundaki istemcide (place'e yazılmadan) şunlar yapıldı: Market ve Loading GUI'leri ekran görüntüsü için birkaç saniye `Enabled` yapılıp kapatıldı; Player1'den `EmojiRemote` ile emoji gönderildi; fareyle tuvale çizgi çekildi.
- Play canlı DataStore'a yazdı (Adam onayladı). Test hesaplarının Yıldızları değişti, oturum sayaçları arttı. GA'ya olay gitti mi: `?`.
- Video kaydı aracı bu Studio sürümünde çalışmadı ("Tool handler not found"). Akış süreleri koddan ve art arda alınan karelerden çıkarıldı.
- Emülatörde enjekte edilen fare tıklamaları GUI düğmelerini (renk, Submit, emoji) **tetiklemedi**; tuval çizimi çalıştı. Gerçek dokunma davranışı ölçülmedi, E bölümündeki listeye bırakıldı.
- Bu oturumda başka bir olay da oldu: Rojo şablonu (kökteki `rojo init`) place'e geçici olarak Baseplate, Lighting ayarları ve "Hello world" script'leri yazdı. Place kaydedilmeden kapatıldı; yeniden açıldığında bu nesneler yoktu (doğrulandı). Lighting değerleri MCP'den okunamadı: `?`.

---

## A · Gösterim (reveal)

### 1. Kare kare akış

Sunucu sırası: `StartCollectingPhase` → `StartRevealPhase` → çizim başına döngü → `CleanRound` (`SSS/Round/init.luau:653-682, 691-880, 888-989`).

| # | Ne görünür | Süre | Kamera | Ses/animasyon | Oyuncu ne yapabilir |
|---|---|---|---|---|---|
| 0 | Çizim süresi biter. Sunucu `COLLECTING_PHASE` yayınlar. | — | Çizim kamerası (`CamPart`). Erken Submit eden için serbest kamera. | — | — |
| 1 | **"Reveal" perdesi** (mor tam ekran, `PassGui`). Faz etiketi "Drawing"den "Reveal"e değiştiği için açılır (`K:144-151`, `RC/Modules/PassController.luau:81-82`). Arkasında: tuval temizlenir, çizim tamponu gönderilir, PhaseGui "Collecting drawings", **kenar çubuğu açılır** (`RC/Phases/CollectingController.luau:21-32`). | Perde 0,3 sn fade + 3 sn (`PassController.luau:125-129`). Toplama, herkes gönderince 0,5 sn'lik yoklamayla biter; en fazla 7 sn (`Round/init.luau:672-678`). | Değişmez | Fade | Hiçbir şey (perde üstte) |
| 2 | `REVEAL_INTRO_PHASE`. Etiket yine "Reveal" olduğu için **yeni perde açılmaz**. PhaseGui "Get ready" (`RC/Phases/RevealIntroController.luau:19-25`). Karakterler koltuklara ışınlanır, model klonu silinir (`Round/init.luau:768, 776`). | Sunucu 3 sn bekler (`Round/init.luau:781`). Perde toplama başında açıldığı için "Get ready" pratikte **0-1 sn görünür ya da hiç görünmez**. Ekran: [`iphone14-04`](cekirdek-ekran/iphone14-04-gecis-reveal.jpg). | **Sabit `RevealCam`** (`RC/Core/Sceneography.luau:23-32`) | — | Kenar çubuğu açık; Market'e basılabilir |
| 3..N+2 | Her çizim: `REVEAL_PHASE` + (isim, tema, tampon) (`Round/init.luau:826`). İstemci: PhaseGui ve kenar çubuğu kapanır, EmojiGui açılır, çizim ekrana basılır, sahibin çerçevesi uygulanır (`RC/Phases/RevealController.luau:19-39`). **İsim, tema, "n / N", süre çubuğu ve geçiş animasyonu yok**; bir çizimden ötekine sert kesme. | **Her çizim tam 5 sn** (`K:53`, `Round/init.luau:827`) | Sabit | Emoji düğmeleri "nefes alır" (UIStroke 1↔2 px, `RC/init.client.luau:128-187`). **Ses yok**: yalnız lobi müziği (`LoopSound`) çalmaya devam eder; `Sceneography:PlaySound` hiç çağrılmıyor (`Sceneography.luau:110-113`, grep). | Emoji (0,3 sn), Report |
| N+3 | `ClearDisplay` → `CLEAN_ROUND_PHASE`. **"Lobby" perdesi**, arkasında serbest kamera ve "Round over" (`RC/Phases/CleanRoundController.luau:21-41`). | 3,3 sn | Serbest | Fade | — |
| N+4 | Aynı anda `NewRound` + `TryStartRound` (`Round/init.luau:987-988`): 2+ kişide hemen "Round starting in 15s" başlar. "Round over" yazısı pratikte görünmez. 1,5 sn'de galeri noktalarına ışınlama (`:976-979`). 3,3 sn'de "You Got" sonuç ekranı (`:949-966`). | Sonuç: tepki varsa 3 + 0,5 + 3 + 0,5 sn, yoksa 3 + 0,5 sn (`RC/Modules/ResultController.luau:233-268`) | Serbest | Fade | Lobi. 15 sn'lik geri sayımın ~3 sn'si perde, ~7 sn'si sonuç ekranıyla geçer. |

- **Toplam gösterim süresi**: ≈ toplama (0,5-7) + 3 + 5·N sn. 2 kişide ≈ 14 sn, 8 kişide ≈ 44 sn.
- **Kamera kadrajı**: `RevealCam` (90, 16.3, -127.7) ekrandan (90.3, 19.2, -157.6) 30 stud uzakta ve 2,9 stud aşağıda. Ekran 27 stud, çizim alanı bunun %70'i (18,9 stud).
  - Varsayılan FOV ile **çizim ekran yüksekliğinin ~%45'ini kaplar.** Ölçüm de aynı: iPhone'da 126/279 px. Telefonda çizim ≈ 175 pt yüksekliğinde; ekranın geri kalanı koyu duvar ve hoparlör ([`iphone14-05`](cekirdek-ekran/iphone14-05-gosterim-cercevesiz.jpg)).
  - Kaynak: Studio `Workspace.Map.GamePlay.Reveal.RevealCam`, `…Screen.DisplayPart`.

### 2. Render kalitesi

- **Çözünürlük**: Çizim 512×512 EditableImage (`K:29`). Gösterim yüzeyi: `DisplayPart` 27×27 stud, `SurfaceGui` `PixelsPerStud` = 50, yani 1350 px. `Image` 0.7×0.7 → **945×945 px**. 512 px, 945 px'e **bilineer** büyütülüyor (`ResampleMode.Default`, `RC/Core/RefsBuilder.luau:274-278`). Çizgiler bulanık.
- **En-boy oranı hatası (yeni)**:
  - Çizim tuvali `CanvasLabel` = MainFrame'in 0.75×0.75'i. MainFrame `UIAspectRatioConstraint` 1.17 (Studio). Yani **tuval 1.17:1 yatay**; ölçüm: iPhone 294×251, iPad 548×468.
  - 512×512 doku bu kutuya `Stretch` ile yayılıyor (`RC/Modules/CanvasController.luau:71-74`). `ScreenToCanvas` x ve y'yi ayrı ölçeklediği için (`:121-127`) oyuncunun gördüğü çizim kendi içinde tutarlı.
  - Ama gösterim ve galeri **kare** (945×945). Sonuç: gösterimde her çizim **yatayda ~%15 sıkışır**, oyuncunun çizdiği daire dikey elips olur.
- **Işık**: `SurfaceGui.LightInfluence = 1` (Studio). Beyaz tuval gösterimde **açık mavi-gri** görünüyor ([`ipad-05`](cekirdek-ekran/ipad-05-gosterim-emoji-yagmuru.jpg)). Renkler sahnenin ışığına göre değişir.
- **Kenar kırpma**: yok, çizimin tamamı `Stretch` ile gösteriliyor. `EmojiLayer` `ClipsDescendants = false`: emojiler çizimin ve çerçevenin dışına taşıyor ([`ipad-06`](cekirdek-ekran/ipad-06-gosterim-wood-cerceve-emoji.jpg)).
- **Çerçeve hizası**: Çerçeve, `Image`'in kardeşi olan tek bir `Frame` ImageLabel. Konum ve boyut **SurfaceGui'ye göre** veriliyor, çizime göre değil (`K:235-242`, `RC/Modules/FrameController.luau:58-78`).
  - Her çerçevenin kendi elle girilmiş ölçüsü var ve bazıları eş olmayan oranlarla gerilmiş (`Stretch`): Dark 1.23×1.155, Gold 1.14×1.15, Cute 1.1×1.08 (`K:236-241`).
  - Wood ekranda kabaca hizalı ([`iphone14-06`](cekirdek-ekran/iphone14-06-gosterim-wood-cerceve.jpg)). Öteki çerçeveler canlıda görülmedi: `?`.
- **8 çizimde performans**: Ölçülmedi (2 oyuncu vardı): `?`. Koddan çıkan maliyet:
  - Her çizimde sunucu tamponu **her oyuncuya ayrı** gönderiyor (`Round/init.luau:826`, `broadcastPhase` `:67-73`). Tampon en fazla 5 + 4·15000 ≈ **60 KB** (`K:20-22`; `RM/StrokeCodec.luau:14`'teki "~192 KB" yorumu eskimiş). En kötü durumda 8×8×60 KB ≈ 3,8 MB/tur. Tur sonunda galeri için bir 3,8 MB daha (`Round/init.luau:981-985`).
  - İstemci her çizimi gösterim anında decode edip baştan render ediyor (`Sceneography.luau:90-98`). Önceden render ya da önbellek yok.
  - `DrawRenderer.render` 200 000 fırça darbesinden sonra `task.wait()` ile bekliyor (`RM/DrawRenderer.luau:189-192`). Ağır bir çizimde render iki kareye bölünür. Bu sırada sıradaki `REVEAL_PHASE` gelirse **iki render aynı EditableImage'e karışabilir**: `Enter` remote handler içinde bekliyor ve router bunu engellemiyor (`RC/Core/PhaseRouter.luau:18-31`). Sıklığı: `?`.
  - Tur sonunda galerinin 8 slotu sonuç ekranıyla aynı anda art arda render ediliyor (`RC/Modules/GalleryController.luau:137-142`).
  - İstemcide toplam **10 adet 512² EditableImage** var (1 tuval + 1 gösterim + 8 galeri, ≈ 1 MB her biri). Yalnız gösterimde bütçe hatasına karşı koruma var (`RefsBuilder.luau:266-279`). Tuval (`CanvasController.luau:71`) ve galeri (`GalleryController.luau:71-73`) `nil` dönüşünü kontrol etmiyor; düşük bellekli cihazda açılışta hata verebilir: `?`.

### 3. Emoji oylama

- **Düğme boyutu** (ölçüm, pt):

  | | Emoji düğmesi | Report |
  |---|---|---|
  | iPhone 14 | **47×29** | 46×28 |
  | iPad | 65×62 | — |

  Telefonda yükseklik 44 pt önerisinin altında. Düğmeler `UIGridLayout` ile boyutlanıyor, kendi `{0,100},{0,100}` değerleri göz ardı ediliyor.
- **Geri bildirim zayıf**:
  - Basınca yerelde tık sesi çalar ve seçilen düğmenin kenarı 2 px olur. Ama nefes animasyonu zaten 1↔2 px arasında gidip geliyor (`K:85-88`, `init.client.luau:157-176`). **Seçili düğme, nefesin tepe noktasından ayırt edilmiyor.**
  - Sunucudan onay gelmiyor; oyuncu oyunun sayıldığını göremiyor. Çizim başına toplam oy sayısı ekranda yok.
- **Emoji yağmuru**: Her basış, **herkese** aynı ikonu gösterir (`Round/init.luau:1031-1035`, `RC/Reveal/EmojiRain.luau:11-58`).
  - Konum: x rastgele 0-1, y 0,5-1. Boyut 0,06'dan 0,14'e büyür (yüzeyde ≈ 57 → 132 px). 2 sn'de yükselip söner.
  - Ikonlar **çizimin üstüne** çiziliyor ve çizimi kapatıyor. Oyuncu başına 0,3 sn sınırından başka kısıt yok; 8 kişide saniyede ~25 ikon olur.
  - Sayılmayan basışlar da yağar: `normal`, sahibin kendi çizimine bastığı emoji, son seçim olmayan basışlar.
  - Ses yok.
- **0,3 sn bekleme**: İstemcide `tick()` ile (`init.client.luau:169-170`), sunucuda yine 0,3 sn ve `tick()` ile (`SSS/Round/RoundRemotes.luau:139-141`). Aralıklar aynı olduğu için ağ gecikmesindeki dalgalanmada sunucu bir basışı **sessizce düşürebilir**. İstemci yeni seçimi gösterirken sunucuda eski oy kalır.
- **Son seçim mantığı**: `ps.currentVote` her basışta üzerine yazılır (`Round/init.luau:1027`). Çizim başında `nil`'lenir (`:807-810`), 5 sn sonunda sayılır (`:832-841`).
  - Yalnız `laugh`, `skull`, `shocked` sayılır; `normal` hiçbir yere yazılmaz (`K:190-194`).
  - Oy geri alınamaz. Kimin neye oy verdiği tutulmuyor.
  - Canlı test: Player1 ~12 kez karışık emoji bastı; sonuçta "😂 1" (yalnız son seçim) ([`ipad-07`](cekirdek-ekran/ipad-07-sonuc-you-got.jpg)).

### 4. Hatalar ve kırılgan yerler (OTOPSI H·17 dışında)

1. **Geç gelen oy sonraki çizime yazılıyor.**
   - Sunucu `currentVote`'u sıfırlayıp hemen yeni çizimi yayınlıyor (`Round/init.luau:807-826`). Emoji, faz hâlâ `REVEAL_PHASE` olduğu sürece kabul ediliyor (`RoundRemotes.luau:133`).
   - Önceki çizimin son ~RTT'sinde basılan oy, sunucuya sıfırlamadan sonra varırsa **yeni çizimin oyu** sayılır.
   - Tersi de var: tally 5 sn tamamlanınca yapılıyor (`:827-832`). Oyuncunun ekranında çizim ağ gecikmesi kadar geç açıldığı için son ~RTT'deki oy kaybolur.
2. **Sahip kendi çizimine emoji basabiliyor**: UI bunu engellemiyor, sunucu oyu saymıyor ama yağmuru herkese yayıyor (`Round/init.luau:1018-1035`). İstemci sahibin adını biliyor (`RevealController.luau:19`), düğmeleri kapatmak kolay.
3. **Raporla gizlenen çizim** (eşik dolunca `HideDrawingRemote`, `Round/init.luau:1077-1084`):
   - "Drawing Hidden" katmanı çıkıyor, ama emoji yağmuru katmanın **üstünde** kalıyor: EmojiLayer ZIndex 50, katman ZIndex 11 (`RC/Modules/UIController.luau:252`).
   - Oylar sayılmaya, **Yıldız ödenmeye** ve sonuç ekranında gösterilmeye devam ediyor; tally gizleme durumuna bakmıyor (`Round/init.luau:829-865`).
   - Yalnız kendi raporlayana gösterilen katman, sonraki çizimde `HideReportOverlay` ile kalkıyor (`RevealController.luau:24`). Doğru davranış.
4. **Çıkan oyuncunun çizimi**:
   - Toplama fazından sonra çıkarsa çizimi yine gösterilir. Çerçevesi varsayılana döner (OTOPSI H·17/9). Yıldız ödenmez ama tally tutulur (`Round/init.luau:863`).
   - Toplamadan önce çıkarsa durumu silinir, çizim gösterilmez (`SSS/Round/RoundState.luau:57-62`). Submit edip çıkanın çizimi de kaybolur (OTOPSI H·17/5).
5. **Boş çizim**: 0 stroke gösterilmez (`Round/init.luau:95`). Sahibine "çizimin boştu" gibi bir bildirim, sonuç ekranı ya da Yıldız yok.
   - **Yalnız silgi** kullanılmış çizim (beyaz stroke'lar) boş sayılmaz ve bembeyaz gösterilir (`RM/StrokeCodec.luau:86`).
   - Tek bir doldurma bütün tuvali boyar ve geçerli çizim sayılır.
   - Hiç çizim yoksa intro atlanır, tur doğrudan lobiye döner (`Round/init.luau:703-705, 790-793`).
6. **Gösterim sırasında kenar çubuğu açık kalıyor**: toplama ve intro boyunca açık, ilk çizimde kapanıyor (`CollectingController.luau:24`, `RevealController.luau:30`). Bu arada Market'e basılırsa MarketGui ilk çizimin üstünde açık kalır; gösterim MarketGui'yi kapatmıyor (`Sceneography.luau:42-51` yalnız Canvas/Emoji kapatır).
7. **`drawingVotes`** alanı tanımlı ama hiç kullanılmıyor (`RoundState.luau:28, 77`).

### 5. Sonuç ekranı ("You Got") ve galeri

- **Sonuç ekranı** yalnız sahibine gönderiliyor (`Round/init.luau:953-956`).
  - İçerik: 3 tepki türünün sayısı ve "Emoji ★x / Round ★20" (`ResultController.luau:202-269`).
  - Telefonda 288×47 pt; sayılar 24×15 pt ([`iphone14-08`](cekirdek-ekran/iphone14-08-sonuc-lobi-joysticksiz.jpg)).
  - Ses yok; yalnız fade.
  - Eksikler: kendi çiziminin küçük resmi, sıra/yüzde ("3. oldun"), kimin oy verdiği, `normal` sayısı, başkalarının sonuçları. Çizimi gösterilmeyen oyuncu hiçbir şey görmüyor.
- **Galeri**: Son turun en fazla 8 çizimi, lobideki 8 tabelada; altında sahibin adı (`GalleryController.luau:87-103`).
  - Raporlananlar süzülüyor (`Round/init.luau:343-355`). Oy, sıra ve tepki sayısı yok; etkileşim yok.
  - İsimler çok küçük, tabelalar uzakta ([`ipad-07`](cekirdek-ekran/ipad-07-sonuc-you-got.jpg)).
  - Spawn noktasındaki iki süs tabelasında "Theme: One Eye" / "Theme: Bird" yazıyor, oysa tema sistemi kapalı ([`ipad-02`](cekirdek-ekran/ipad-02-lobi-ilk-joystickli.jpg)).
- **Podyum için bugün elde olan veri** (sunucuda, tur sonunda):
  - Gösterilen her çizim için `roundEmojiResults[ownerName] = { tally = {laugh, skull, shocked}, emojiStars, roundStars }` (`Round/init.luau:854-858`). Pozitif tepki toplamı = sıralama ölçütü.
  - `encodedDrawings[i] = { playerName, ownerUserId, theme, buffer }`, gösterim sırasıyla (`:707-715`). Podyum çizimleri yeniden gönderilebilir.
  - `roundReportTotals[ownerName]`: gizlenenleri podyumdan çıkarmak için (`:1068`).
  - **Eksikler**: oy veren → oy eşlemesi (yalnız son oy tutulur ve sonra silinir), `normal` sayısı, beraberlik kuralı, oy anı. Sonuçlar bugün yalnız sahibine gidiyor; podyum için herkese giden yeni bir yayın gerekir.

---

## B · Çizim sistemi

### 6. Araçlar

| Araç | Var mı | Ayrıntı (dosya:satır) |
|---|---|---|
| Renk | 16 sabit renk | `K:165-182`. Düğme rengi koddan basılıyor (`UIController.luau:148-176`). Renk seçici ya da damlalık yok. |
| Fırça | 3 boy: S/M/L | 0.01/0.04/0.08 × 512 = **5 / 20 / 41 px** (`CanvasController.luau:31-33`) |
| Silgi | var | Beyaz boyayla çizer (`CanvasController.luau:101-104`, `StrokeCodec.luau:86`) |
| Doldurma | var | 4 komşulu, **tam renk eşleşmesi**, tolerans yok (`RM/FloodFill.luau:76-81, 105`). DrawCircle kenarları yumuşatıyorsa çizgi çevresinde boşluk kalır: `?` |
| Geri al | var | En fazla 80 adım (`K:23`) |
| İleri al / Temizle / Opaklık / Şekil / Yakınlaştırma | **yok** | — |

**Yeni hatalar:**
- **Silgi durumu kopuyor**: Silgiden sonra fırça boyu seçilince silgi vurgusu kalkıyor (`UIController.luau:184-190, 99-102`). Ama `CanvasController.eraserActive` ve beyaz renk **değişmiyor**, oyuncu beyaz çizmeye devam ediyor. Çıkış yolu yalnız bir renk seçmek (`CanvasController.luau:91-94`). Silgi seçiliyken önceki rengin vurgusu da yerinde kalıyor.
- **80 stroke'tan sonra ilk çizgiler gösterimden siliniyor**:
  - Geri alma geçmişi ile gönderilen stroke listesi **aynı tablo** (`self.strokes`). 81. stroke'ta en eski stroke listeden atılıyor (`CanvasController.luau:217-222, 244-247, 279-282`).
  - O stroke oyuncunun tuvalinde görünmeye devam ediyor, ama **sunucuya gitmiyor** ve gösterimde yok. Geri al'a basılınca yerelde de kayboluyor (`:303-311`).
  - 1200 noktayı geçen her stroke ayrıca yeni bir stroke sayılıyor (`:278-296`). Bu yüzden ayrıntılı çizimlerde sınıra kolay ulaşılır.

### 7. Girdi

- **Fare**: `InputBegan`/`InputChanged`/`InputEnded` (`RC/Modules/InputController.luau:38-69`). Tıklama tuval dışında başlarsa çizilmez; doğru davranış.
- **Dokunma**: `TouchStarted`/`TouchMoved`/`TouchEnded` (`:75-103`). **Dokunma kimliği tutulmuyor.**
  - İki parmakla dokununca iki parmağın hareketi aynı stroke'a yazılır; parmaklar arasında zikzak çizgi çıkar.
  - Herhangi bir parmağın kalkması stroke'u bitirir.
  - `TouchMoved` için `gameProcessed` kontrolü yok.
- **Kalem**: Ayrı bir yol yok; dokunma ya da fare gibi davranır. Basınç yok.
- **Kamera/kaydırma çakışması**: Çizim sırasında kamera `Scriptable` (`Sceneography.luau:17-21`). Zıplama kapatılıyor (`RC/Phases/DrawingController.luau:59-107`). Joystick de kalkıyor, ama bunun sebebi bir hata (aşağıda).
- **Tuval dışına taşma**: Parmak tuvalden çıkıp geri girerse stroke bitmiyor; `lastPixel` korunuyor (`InputController.luau:110-114`, `CanvasController.luau:268-273`). **Çıkış ve giriş noktaları arasına düz bir çizgi çekiliyor.** Koordinatlar kenara sıkıştırıldığı için (`:124-125`) bu çizgi kenar boyunca da uzayabilir.
- **Mobilde kritik hata: joystick ve zıplama tuşu kayboluyor.**
  - `HideAllGuisExceptCanvas` `PlayerGui`'deki **bütün** ScreenGui'leri kapatıyor; Roblox'un `TouchGui`'si de buna dahil (`Sceneography.luau:57-65`, çağrı `DrawingController.luau:146`). Hiçbir kod geri açmıyor.
  - Ölçüm: ilk turdan sonra lobide `TouchGui.Enabled = false`. Ekranlar: [`ipad-02`](cekirdek-ekran/ipad-02-lobi-ilk-joystickli.jpg) (önce, joystick var), [`ipad-08`](cekirdek-ekran/ipad-08-lobi-joysticksiz.jpg) ve [`iphone14-08`](cekirdek-ekran/iphone14-08-sonuc-lobi-joysticksiz.jpg) (sonra, yok).
  - Mobil oyuncu ilk turdan sonra **lobide yürüyemiyor**: Market'e, galeriye ve trambolene gidemiyor.

### 8. Tuval

- Çözünürlük 512×512 (`K:29`). Ekranda iPhone 14'te **294×251 pt**, iPad'de **548×468 pt**. Oran 1.17:1 olduğu için gösterim kareye dönünce şekil bozuluyor (A·2).
- Ölçekleme: Scale + tek `UIAspectRatioConstraint` (MainFrame, 1.17, FitWithinMaxSize). Tuval ekranın sağında, modelin klonu solda. **Oyuncu modeli görerek çizebiliyor.** iPad'de modelin sol kenarı kadrajın dışına taşıyor ([`ipad-03`](cekirdek-ekran/ipad-03-cizim.jpg), [`iphone14-03`](cekirdek-ekran/iphone14-03-cizim.jpg)).
- iPhone 14'te tuvalin sağ kenarı x = 761 pt; güvenli alan 749'da bitiyor. Yani tuval ve L fırça düğmesi **12 pt kadar çentik/köşe bölgesine** giriyor. Bütün GUI'lerde `ScreenInsets = None` ve `IgnoreGuiInset = true` (C·11).

### 9. Gecikme ve veri

- Çizim sırasında sunucuya **yalnız sayaçlar** gidiyor: stroke ve undo sayısı, 2 sn'de bir (`DrawingController.luau:277-297`, `K:348`). **Stroke'ların kendisi gitmiyor.**
- Tampon **tek seferde**, sunucunun `COLLECTING_PHASE` yayını gelince gönderiliyor (`CollectingController.luau:27-30`).
  - Format: 5 bayt başlık + 4 bayt/nokta (`StrokeCodec.luau:66-180`). En fazla 80 stroke / 1200 nokta/stroke / toplam 15 000 nokta → **en fazla ~60 KB**.
  - Sunucu `StrokeValidator` ile aynı sınırları uyguluyor, tuval dışındaki noktaları atıyor (`SSS/StrokeValidator.luau:37-138`). Doğrulanan çizim yeniden encode edilip yayınlanıyor (`Round/init.luau:709`).
- **Kayıp riskleri**:
  1. Tampon toplama penceresinden (≤ 7 sn, herkes gönderince daha kısa) sonra varırsa **sessizce atılır** (`RoundRemotes.luau:186`).
  2. Bağlantı kopması veya çıkış: bütün çizim gider. Periyodik yükleme yok.
  3. 80+ stroke'ta ilk stroke'lar (B·6).
  4. Sınırlar yerelde de uygulandığı için, sınıra ulaşınca çizim **uyarısız durur**: `MAX_TOTAL_PIXELS` (`CanvasController.luau:262-263`). Oyuncuya "mürekkep bitti" gibi bir bildirim yok.
- Analitik için yalnız `StrokeValidator: truncated buffer` hata olayı var (`Round/init.luau:995-999`).

### 10. Submit akışı ve 90 → 140 sn

- **Submit**:
  - Düğme 1 sn sonra görünür (`DrawingController.luau:240-243`). Telefonda **40×14 pt**, iPad'de 76×26 pt; "Time Left" etiketiyle yan yana, üst köşede ([`iphone14-03`](cekirdek-ekran/iphone14-03-cizim.jpg)).
  - Basınca tuval kapanır, kenar çubuğu açılır, serbest kamera, "Waiting for others mm:ss left" (`DrawingController.luau:201-222`). Sunucu oyuncuyu bekleme pedine ışınlar (`Round/init.luau:1004-1006`).
  - **Çizim o anda gönderilmiyor**; toplama fazını bekliyor. Onay penceresi yok, geri dönüş yok.
- **`DRAWING_DURATION`'a bağlı yerler** (değer 140 olursa):

  | Yer | Etki |
  |---|---|
  | `K:49` | Tek kaynak |
  | `Round/init.luau:642` | Sunucu fazı 3 + 140 sn sonra bitirir |
  | `RoundRemotes.luau:35, 52` | Ara katılım "> 60 sn kaldıysa": 140'ta ilk **80 sn** içinde girenler çizime katılır (bugün 30 sn) |
  | `DrawingController.luau:237, 254` | Sayaç ve clamp otomatik uyar. "Time Left: 140" `TextScaled` olduğu için yazı küçülür. |
  | `K:71` | Son 10 sn uyarısı yalnız **görsel** (kırmızı yanıp sönme). **Ses yok**, süreye bağlı müzik de yok. |
  | `AS:167-176` | `Drawing:SubmitTime:SecX-Y` 5 sn'lik kutular, üst sınır `ANALYTICS_MAX_ELAPSED` = 180 (`K:275`). 140 bu sınırın altında: kutu sayısı 18'den 28'e çıkar, sınır taşmaz. |
  | `AS:252-258` | `Quit:QuitMidRound…:Drawing:SecX-Y` ve `QuitAfterSubmit…:WaitSecX-Y` aynı kutularla çalışır; sorun yok. |
  | `SSS/QuitLog.luau:31` | Yorum "<=140" diyor, yani bu değer bir zamanlar 140'mış ya da öyle planlanmış. Kod bu değeri kullanmıyor. |

  Tur başına süre +50 sn olur; gösterim süresi değişmez. Erken bitiş olmadığı için (OTOPSI H·17/1) Submit edenler 140 sn'ye kadar bekler.

---

## C · Arayüz ve mobil uyum

### 11. ScreenGui tablosu

Ortak özellikler:
- Hepsinde `IgnoreGuiInset = true`, `ScreenInsets = None`, `ClipToDeviceSafeArea = false`, yani **güvenli alan hiç dikkate alınmıyor**.
- Bütün StarterGui'de **tek bir** `UIAspectRatioConstraint` var (CanvasGui.MainFrame). `UIScale` ve `UITextSizeConstraint` hiç yok.
- Metinlerin çoğu `TextScaled` (kutu küçüldükçe yazı da küçülüyor).

Ölçüler pt, telefon = iPhone 14 yatay, tablet = iPad.

| ScreenGui | Ölçekleme | Telefon ölçüleri / sorunlar | Tablet |
|---|---|---|---|
| LoadingGui (DO 3) | Tam ekran ImageLabel, **Stretch** | 843×388: görsel **~1,5 kat yatay gerilmiş**. "Game Loading" yazısı kartların altına biniyor ([`iphone14-10`](cekirdek-ekran/iphone14-10-yukleme-howtoplay.jpg)) | 1179×819, oran doğala yakın ([`ipad-01`](cekirdek-ekran/ipad-01-yukleme-howtoplay.jpg)) |
| CanvasGui | Scale + AR 1.17 | Submit **40×14**, Timer 51×10, renk 36×27, araç 39×35, fırça 43×28. Tuval sağ kenarı güvenli alan dışında (+12). Üstteki Theme/Submit satırı y ≈ 22-38, Roblox üst çubuk bölgesinde. | Submit 76×26, renk 68×50, araç 73×66 |
| EmojiGui | Scale + GridLayout | Emoji 47×29, Report 46×28 | 65×62, 64×59 |
| SidebarGui (DO 2) | Scale 0.16×0.70 | 135×271; düğmeler 135×30; BE NEXT DRAWN 115×28 (y 197-225). **Dinamik joystick bölgesine çok yakın/çakışık**: joystick başlangıcı y 237-311, x 29-103. Sol alta dokunarak yürümeye çalışan oyuncu satın alma düğmesine basabilir (bu turda TouchGui kapalıyken ölçüldü; gerçek dokunmayla doğrulanmalı: E). | 189×572; BE NEXT DRAWN 161×59 |
| PhaseGui | Scale | 191×26, y = -50 (ekranın üstünden 8 pt). Yazılar **18 ve 14 pt yükseklikte**; üst çubuk bölgesinde | 267×55 |
| ResultGui | Scale | 288×47, sayılar 24×15 | 403×100 |
| MarketGui (DO 2) | Scale 0.71×0.82 | Kapatma düğmesi 39×31, x 715-754: **güvenli alan dışında**. Logo kenar çubuğunun üstüne biniyor (x 127 < 133). DisplayOrder kenar çubuğuyla aynı (2). Başlık 13 pt, rozet 9 pt, düğmeler 111×19 ([`iphone14-09`](cekirdek-ekran/iphone14-09-market.jpg)). | 834×670 |
| PassGui (DO 3) | Tam ekran CanvasGroup | Sorun yok | Sorun yok |
| TutorialGui (DO 1) | Tam ekran | 4 adet `CloseTutoButton`'dan üçünün **genişliği negatif** (-0.214 ve -0.053 scale; ölçüm -180×127, -180×220, -44×40). Dokunma alanları belirsiz. Metin 194×27. | — |

- **Küçük ekranda üst üste binme**: Market ile kenar çubuğu; Theme/Submit/Timer satırı ile Roblox üst çubuğu; sağ kenarda çentik.
  - Emoji paneli ile sonuç paneli aynı yerde ama aynı anda açılmıyorlar.
  - Market çizim sırasında açılamıyor (kenar çubuğu kapalı), ama intro sırasında açılabiliyor (A·4/6).
- **Dikey (portrait) yön**: Ölçülmedi: `?`. Oyun yönü kilitlemiyor (`ScreenOrientation` kodda yok, grep).

### 12. Yükleme ekranı ("How to play")

- **Tetikleme**: `RoundClient` başında `RefsBuilder.build` çağrılır (`RefsBuilder.luau:226-366`).
  - `LoadingGui` StarterGui'de olduğu için ancak PlayerGui kopyalandıktan sonra görünür. Ondan önce Roblox'un varsayılan yükleme ekranı çıkıyor; `ReplicatedFirst` boş (ölçüm).
- **Ne kadar kalıyor**: En az 5 sn (`K:48`). Bütün GUI ve harita referansları bulunana ve emoji/araç ikonları `PreloadAsync` ile önyüklenene kadar sürer (`:283-321, 333-346`). Hazır olsa bile 5 sn bekletiyor. İlerleme göstergesi ya da atlama yok.
- **Neden bozuk**:
  1. İçerik tema anlatıyor ("1 Get theme", "Use the theme!") ama tema kapalı (`K:119`).
  2. Gösterilen 😍 emojisi oyunda yok (oyundakiler 😂 💀 😱 😐).
  3. Oylama, Yıldız, çerçeve ve "Be next drawn" anlatılmıyor.
  4. Telefonda yatay gerilme ve yazı çakışması (C·11).
  5. Herhangi bir zorunlu referans 8 sn içinde bulunamazsa ekran "Game failed to load. Please rejoin." yazısında **kalıcı olarak takılı kalır**; yeniden deneme yok (`:21, 348-351`). Harita parçaları da aynı 8 sn ile bekleniyor (`:81-99`). `StreamingEnabled` açıksa risk büyür; değeri MCP'den okunamadı: `?`.

### 13. Faz sayacı ve PhaseGui (OTOPSI B·4, H·17/2'ye ek)

- **Hesaplama**: Lobi ve çizim sayaçları `workspace:GetServerTimeNow()` ile hesaplanıyor (`RC/Phases/WaitingController.luau:39-50`, `DrawingController.luau:228-267`). Saat kayması yok.
- **Yanlış ya da takılı gösterdiği yeni durumlar**:
  1. **Gösterim ve toplamada hiç sayaç yok**. Toplama 7 sn'ye kadar sürebilir, gösterimde "kaçıncı çizim / kaç sn" bilgisi yok (`CollectingController.luau:23`, `RevealController.luau:29`).
  2. **Submit sonrası** "00:00 left" yazısı toplama gelene kadar kalıyor (`DrawingController.luau:245-257`).
  3. **"Round over" hiç görünmüyor**: 2+ kişide `CleanRound` hemen yeni geri sayımı başlatıyor (`Round/init.luau:987-988`).
     - Lobi geri sayımı (15 sn) perde (3,3 sn) ve sonuç ekranı (~7 sn) ile **üst üste** akıyor. Oyuncunun lobide serbest kaldığı süre ≈ 5 sn ([`iphone14-08`](cekirdek-ekran/iphone14-08-sonuc-lobi-joysticksiz.jpg): sonuç ekranı açıkken "in 10s").
  4. **Ara katılımla izleyici olan** oyuncu, tur sürerken "Waiting for players" görüyor (`RoundRemotes.luau:98` → `WaitingController.luau:27`). Yanıltıcı.
  5. PhaseGui telefonda 18 pt yüksekliğinde ve üst çubuk bölgesinde (C·11).

### 14. Kenar çubuğu

- **Fazlara göre görünürlük**:

  | Faz | Kenar çubuğu | Kaynak |
  |---|---|---|
  | Açılış | açılır | `RefsBuilder.luau:359` |
  | Çizim | kapanır (bütün GUI'lerle) | `Sceneography.luau:57-65` |
  | Submit sonrası | açılır | `DrawingController.luau:218` |
  | Toplama + intro | **açık** | `CollectingController.luau:24` |
  | Her çizimin gösterimi | kapanır | `RevealController.luau:30` |
  | Temizlik | açılır | `CleanRoundController.luau:39` |
  | Öğretici açıkken | Yıldız, şans ve Invite kareleri gizlenir, Market kalır | `RC/Modules/TutorialController.luau:101-122` |

- **Mobilde yer kaplama**: Telefonda ekran genişliğinin %16'sı, yüksekliğinin %70'i (135×271 pt). iPad'de 189×572.
  - "CHANCE TO BE DRAWN" yazısı iPad'de iki satıra bölünüyor.
  - Şans çubuğu yalnız lobide anlamlı, ama fazlardan bağımsız olarak her açık olduğunda görünüyor.
- **Yeni hata (para)**: BE NEXT DRAWN, sahiplik ya da kuyruk durumuna bakmadan her basışta satın alma penceresini açıyor (`RC/Modules/SubjectController.luau:39-47`; çift alım: OTOPSI E·11). Joystick bölgesine yakınlığı yüzünden **yanlışlıkla açılma** riski var (C·11).

### 15. Market ve çerçeveler

- **Market önizlemeleri** `ScaleType = Fit` ile 123×74'lük bir alana yerleşiyor; önizlemede oran korunuyor.
  - **Önizleme ile gösterim farklı görseller kullanıyor**: Cute önizleme `117275548398278`, gösterim `71908176717123`; Wood önizleme `99801184416471`, gösterim `75348877897496`. Gold, Goofy, Dark ve CardBoard aynı (ölçüm ve `K:236-241`). Oyuncu satın aldığı görseli gösterimde görmüyor.
- **Gösterimde oran sorunu**: Çerçeve `Stretch` ile, elle girilmiş ve **en-boyu eşit olmayan** ölçülerle basılıyor (`K:235-242`). Çerçeve görselinin oranı bu ölçüyle uyuşmuyorsa gerilir. Görsellerin kendi oranları MCP'den okunamadı: `?`.
  - Konum ve boyut çizime göre değil SurfaceGui'ye göre veriliyor (`FrameController.luau:74-77`). Çizim alanı değişirse (ör. tuval kare yapılırsa) bütün çerçeve değerleri yeniden ayarlanmalı.
- **Çerçeve render'ı şunlara bağlı**:
  - `FrameController.FrameNameFor` sahibin `Player` nesnesindeki `EquippedFrame` attribute'unu **isimle** arıyor (`FrameController.luau:44-51`). Attribute'u `SSS/PlayerDataService.luau:101` yazıyor.
  - Ardından `Apply` tek `Frame` ImageLabel'ı ayarlıyor (`:58-78`).
- **Robux fiyatı** ("R$ 49") GUI'de sabit metin; kod hiçbir yerde `GetProductInfo` ile fiyat çekmiyor (`RC/Modules/MarketController.luau:93-98` yalnız görünürlüğü ayarlıyor). Fiyat değişirse yazı yanlış kalır. Gerçek fiyat: `?`.
- Sahip olunmayan Goofy kartında Robux ve Yıldız düğmeleri 5 pt üst üste biniyor (telefon ölçümü: Robux y 155-174, Yıldız 169-188).
- Kart metinleri telefonda 9-13 pt yüksekliğinde.

---

## D · Analitik denetimi

### 16. Gönderilen olaylar (OTOPSI F·13'teki listenin ayrıntısı ve doğruluğu)

Hepsi GameAnalytics design event; `AS:81-96` üzerinden `addDesignEvent(userId, {eventId, value?, customFields?})`. "Değer" = GA `value` alanı.

| Olay kimliği | Ne zaman | Değer / alanlar | Kaynak | Doğru mu, işe yarıyor mu |
|---|---|---|---|---|
| `Round:Phase:Drawing` | Çizim başında, o anki hazır oyuncu başına | — | `Round/init.luau:631`, `AS:155-161` | Ara katılanlar sayılmıyor (OTOPSI). Tur indeksi yok, ilk tur ile 5. tur ayrılamıyor. |
| `Round:Phase:Collecting` | Toplama başında | — | `:667` | İzleyicileri de sayıyor (OTOPSI) |
| `Round:Phase:RevealIntro` / `Reveal` | Intro başında / ilk çizimden önce, tur başına bir | — | `:773, :788` | **Bütün çizimler boşsa hiç gönderilmiyor**, ama aşağıdaki `RoundComplete` gidiyor. Huni adım atlıyor. |
| `Round:Phase:RoundComplete` | `CleanRound`'da | — | `:917` | **Çizim yapmayan ya da boş çizim gönderen** de "tamamladı" sayılıyor. Ölçtüğü şey "tur sonunda sunucudaydı". |
| `Round:Subject` | Tur başına bir | — | `:639`, `AS:219-221` | Doğru. Payda olarak kullanılabilir. |
| `Round:SubjectQuit` | Model çizim veya toplamada çıkarsa | — | `:520-523` | Doğru |
| `Drawing:SubmitTime` + `Drawing:SubmitTime:SecX-Y` | Submit düğmesinde | değer = sn (0-180) | `RoundRemotes.luau:165`, `AS:167-176` | **Süre bitince otomatik toplananlar yok**. "Submit oranı" için payda olarak `Phase:Drawing` gerekiyor, o da eksik (yukarıda). |
| `Session:RoundsPlayed{A\|B}` + `:{0..20Plus}` | **Çıkışta** | değer = tur sayısı (kesilmemiş) | `Round/init.luau:505`, `AS:182-192` | Sayı `RoundComplete`'e dayanıyor, yani "çizmeden geçen tur" da sayılıyor. Sunucu kapanınca gönderilip gönderilmediği: `?`. |
| `Session:RoundsPlayedBuyer{g}` + kutu | Çıkışta, "bu oturumda çerçeve alan" | aynı | `:513-515`, `AS:198-206` | **Şişkin**: siteden alınmış bir Game Pass ilk girişteki senkronda "bu oturumda alındı" sayılıyor (`SSS/FrameShopService.luau:89-103, 119-128`). Yıldızla ve Robux'la alım da ayrılmıyor. |
| `Session:StarsEarned` | Çıkışta | değer = brüt Yıldız | `:512`, `AS:210-214` | Doğru, ama yalnız oturum sonunda |
| `Session:Quit:{Tür}{g}` (+ alt kutular) | Çıkışta | değer ve `customFields`: `QuitAfterSubmit` {waitDuration, submitElapsed, quitElapsed, roundsCompleted}; `QuitMidRound` {phase, phaseElapsed, roundsCompleted}; ötekilerde değer = kalan oyuncu sayısı | `:458-506`, `AS:241-274` | Aşağıda 17/1-3 |
| `Market:Opened` | Oturumda ilk açılışta | — | `FrameShopService.luau:132-136` | Kapanış ve bakma süresi yok. Hangi kartın görüldüğü yok. |
| `Shop:FrameBought` | Yıldız ya da Robux alımında, pass senkronunda | — | `FrameShopService.luau:70, 101` | **Para birimi, fiyat ve çerçeve yok.** Robux geliri ile Yıldız harcaması aynı sayıda toplanıyor. |
| Hata olayları | Kesik tampon (warning); giriş/çıkış ve DataStore yazım hataları (error) | mesaj metni | `Round/init.luau:997`; `GameServer.server.luau:109, 119, 129, 147, 157`; `BanService.luau:124, 143, 180`; `ModerationService.luau:28`; `QuitLog.luau:74, 82`; `FirstDrawingService.luau:76, 86`; `SessionService.luau:57`; `AS:280-295` | Çizimle ilgili tek hata kesik tampon. Mesajlara `tostring(err)` ekleniyor, bu da benzersiz mesaj sayısını artırıyor. |
| İstemci `ga:initClient()` | Açılışta | — | `RC/init.client.luau:13-22` | Oyun kodu istemciden olay göndermiyor. SDK'nın istemcide ne topladığı: `?`. |
| SDK otomatik: oturum başı/sonu, Game Pass satışı | — | — | OTOPSI F·13 | — |

### 17. Bozuk, yanıltıcı ve eksik olaylar

1. **`QuitAlone` yanlış sınıflanıyor.**
   - Hesap "hazır oyuncu sayısı − 1" (`Round/init.luau:451-456`). Hazır olmadan (yükleme ekranında) çıkan oyuncu zaten listede değil, ama yine de 1 çıkarılıyor.
   - Sonuç: lobide 1 kişi varken yükleme sırasında çıkan oyuncu **`QuitAlone`** sayılıyor (`:493-500`). Kalan oyuncu sayısı da 1 eksik yazılıyor.
2. **`QuitAlone:Loading` ve `:Lobby` ayrımı** değerin 1'den küçük olup olmamasına bakıyor (`AS:265-268`). Gerçek ayrım "hazır mı" sorusu, bu da yalnız dolaylı olarak doğru çıkıyor. En az bir tur oynayıp sonra yalnız kalan oyuncu `QuitAfterRound` sayılıyor; **yalnız kalma bilgisi kayboluyor** (`:491`).
3. `QuitMidRound` faz adları: `Clean` fazı hiç oluşmuyor; `CleanRound` aynı karede `Waiting`'e geçiyor (`:893, 987`).
4. **Hiç olmayan olaylar**: emoji/oy, rapor (yalnız DataStore'a yazılıyor), ilk fırça, gösterimin görülmesi, kendi çiziminin gösterimi, sonuç ekranı, öğretici, davet düğmesi, "Be next drawn" düğmesi ve satın alma penceresi, Developer Product geliri (OTOPSI), yükleme süresi, cihaz/ekran boyutu.
5. **Hiç kullanılmayan**: `AS:301-303 ClearPlayer` boş bir fonksiyon. Çağrılıyor ama hiçbir şey yapmıyor.
6. **GameAnalytics kimlik yapısının kısıtları**:
   - Kimlik en çok **5 parça** (koddaki yorum: `AS:189, 247`). Parça uzunluğu ve karakter kuralları: `?`.
   - A/B grubu ve 5 sn'lik kutular kimliğin **içine** gömülmüş (`RoundsPlayedA:7`, `QuitMidRoundB:Drawing:Sec85-89`). Her yeni boyut, kimlik sayısını çarpıyor ve dashboard'da toplamak elle yapılıyor.
   - Tek bir sayısal `value` alanı var; ikinci bir ölçü (ör. hem süre hem tur no) ancak `customFields` ile gider. `customFields`'ın GA tarafında nasıl sorgulandığı: `?`.
   - Oturum sonu olayları çıkışa bağlı; çökme ya da kapanmada kayıp riski: `?`.

### 18. V0 hunisi

Önerilen yol iki katmanlı:
- Roblox **yerleşik analitiği**: `LogOnboardingFunnelStepEvent` (oyuncu başına bir kez), `LogFunnelStepEvent` (tekrarlayan, huni oturum kimliğiyle), `LogCustomEvent` (sayı/değer). Dashboard'u hazır, kurulum gerektirmiyor. Özel alanlar sınırlı (3 alan, düşük çeşitlilik).
- **Ham kayıt**: oturum kimliği + zaman damgalı satırlar; DataStore'a ya da Open Cloud ile okunabilen bir yere. Edinim kaynağı ve girişten geçen saniyeler gibi birleştirme gerektiren analizler için.

API adlarının ve alan sınırlarının bugünkü hâli Roblox belgelerinden doğrulanmalı: `?`.

| Adım | Bugün ölçülüyor mu | Ölçüm noktası | Önerilen araç |
|---|---|---|---|
| Giriş + edinim kaynağı + reklam | Hayır (grep 0) | `SSS/GameServer.server.luau` PlayerAdded (~`:85`). `GetJoinData()` (launchData, referans). `Enum.UserAcquisitionSource` ve "reklamdan mı geldi" bilgisinin hangi API'den okunduğu: `?`. | Onboarding adım 1 + **ham kayıt** (kaynak birleştirme için) |
| Hazır | Hayır | `RoundRemotes.luau:102-104` (ilk Ready); girişten sn | Onboarding 2 + ham |
| Lobide yalnız bekleme | Yalnız çıkışta, `QuitAlone` değeri olarak (17/1 hatalı) | Başlangıç: Ready iken hazır sayısı < 2 (`Round/init.luau:562`). Bitiş: `:565` (geri sayım başladı) ya da `OnPlayerRemoving` | `LogCustomEvent` (değer = sn, alan = bitiş nedeni) |
| İlk fırça | Hayır (yalnız QuitLog'da dolaylı) | İstemcide `CanvasController:startStroke` 0→1 (`:224-239`). Ya da sunucuda `DrawProgressRemote`'ta ilk `strokes > 0` (`RoundRemotes.luau:181`); 2 sn gecikmeli ama ek remote gerektirmez. | Onboarding 3 + tur hunisi |
| Teslim | Kısmen (yalnız düğme) | Düğme `RoundRemotes.luau:151-167`, otomatik toplama `:185-203`. İkisi ayrı alanla gönderilmeli. | Tur hunisi |
| İlk gösterim | Hayır (`Phase:Reveal` oyuncu başına değil, tur başına) | `Round/init.luau:826`'da oyuncunun ilk `REVEAL_PHASE`'i | Onboarding 4 |
| İlk oy | Hayır | `Round/init.luau:1012-1029` (ilk geçerli `currentVote`) | Onboarding 5 + `LogCustomEvent` |
| Kendi çiziminin gösterimi | Hayır | `:826`'da `drawing.playerName == player.Name`; sonuç `:854` | Tur hunisi (alan: pozitif tepki sayısı) |
| İkinci çizime başlama | Dolaylı (`RoundsPlayed` çıkışta) | `StartDrawingPhase` `:630`, `sessionRounds ≥ 1` iken | Onboarding 6 |
| Tur n tamamlandı | Çıkışta toplu | `CleanRound` `:917` (n = `sessionRounds`). "Çizdi mi" alanıyla birlikte. | `LogFunnelStepEvent` (huni oturumu = sunucu oturumu + oyuncu) |
| Galeri oyu / izleyici oyu / canlı oy | Hiçbiri. **Galeride oylama yok.** | Canlı: `:1012`. İzleyici: aynı yer + `round.spectators[player]`. Galeri: önce özelliğin yapılması gerekiyor. | `LogCustomEvent` (alan = bağlam) |
| Teklif / satın alma | Yalnız `Shop:FrameBought` ve SDK'nın Game Pass olayı | Teklif: `SubjectController.luau:39`, `MarketController.luau:65-69` (istemci; sunucuya remote gerekir). Sonuç: `PromptProductPurchaseFinished` (yok), `ProcessReceipt` `SSS/SubjectGuaranteeService.luau:36-56`, `FrameShopService.luau:109-114` | `LogEconomyEvent` ya da `LogCustomEvent` + **ham** (gelir doğrulama) |
| Sunucu başına oyuncu sayısı zaman serisi | Hayır | Sunucuda 60 sn'lik döngü; `#Players`, hazır sayısı, faz | **Ham** (MemoryStore sorted map ya da saatlik DataStore anahtarı). Yerleşik analitik sunucu düzeyinde zaman serisi için uygun değil (`?`). |

---

## E · Elle kontrol listesi (MCP ile ölçülemeyenler)

Ekran görüntüleri alındı (A–C). Aşağıdakiler gerçek dokunma ya da başka cihaz gerektiriyor. Cihazlar: iPhone SE (küçük), iPhone 14, iPad; yatay **ve** dikey.

| Ekran / adım | Neye bakılacak |
|---|---|
| Yükleme | Telefonda yatay gerilme ve yazının kartlara binmesi; dikeyde görünüm; yükleme süresi (5 sn + ?) |
| Lobi (ilk) | Sol alttaki joystick'e dokununca BE NEXT DRAWN satın alma penceresi açılıyor mu (C·11); Market/Invite'a başparmakla rahat basılıyor mu |
| Lobi (1. turdan sonra) | **Joystick ve zıplama geri geliyor mu** (B·7; bugün gelmiyor) |
| Çizim | Parmakla 5/20/41 px fırçalar; **iki parmak** (zikzak çiziyor mu); tuvalden çıkıp geri girme (düz çizgi); doldurmanın kenar bırakıp bırakmadığı; Submit'e (40×14) tek seferde basılabiliyor mu; çentik tarafında tuval kenarı; silgi → fırça boyu hatası (B·6) |
| Teslim | "Waiting for others" yazısı okunuyor mu; bekleme pedinde ne yapılabiliyor |
| Gösterim | Çizim ekranın kaçta kaçı; daire çiz, elips mi çıkıyor (A·2); renkler soluk mu (ışık); çerçevelerin altısı da tek tek: hizalama ve gerilme |
| Oylama | 47×29 emojiye basmak; seçimin görülüp görülmediği; son 0,5 sn'de basılan oyun hangi çizime yazıldığı (sunucu konsoluna `print` gerekir) |
| Sonuç | "You Got" okunuyor mu; tepkisiz turda yalnız Yıldız adımı geliyor mu |
| Market | Kapatma düğmesi çentik altında mı; Goofy'de düğmeler üst üste mi; Robux fiyatı doğru mu |
| Be Next Drawn | Satın alma penceresi açılıyor mu (Studio test alımı); ikinci alımda ne oluyor (OTOPSI E·11) |
| Öğretici | Negatif boyutlu kapatma düğmeleri: ekranın neresine dokununca kapanıyor |
| Dikey yön | Hiçbir GUI dikey için ayarlanmamış; tuval ve emoji paneli nereye düşüyor (`?`) |

---

## Yeniden yapımda (çekirdek bölgeler için)

| Olduğu gibi kalacak | Neden |
|---|---|
| `RM/StrokeCodec.luau`, `SSS/StrokeValidator.luau`, `RM/FloodFill.luau` | Format küçük, sınırlar iki yanda uygulanıyor, tahsissiz. Yalnız eskimiş yorum (`StrokeCodec.luau:14`). |
| `RM/DrawRenderer.luau` (dab primitifleri) | Tuval ile gösterimin piksel-aynı olması değerli. Yalnız `render`'ın bekleme yaptığı yere dikkat (A·2). |
| `RC/Modules/PassController.luau` | Token'lı perde mantığı sağlam. Etiket katlama davranışı bilinçli tasarım. |

| Cilalanacak | Ne yapılacak |
|---|---|
| `RC/Modules/CanvasController.luau` | Geri alma geçmişi ile gönderilen stroke listesini ayır (B·6). Silgiyi ayrı bir durum yap. İleri al ve temizle ekle. Bütçe dolunca uyar. |
| `RC/Modules/InputController.luau` | Dokunma kimliği, tek parmak kuralı, tuvalden çıkınca stroke'u kes |
| `RC/Reveal/EmojiRain.luau` | Ikonları çizimin dışına/kenarına al, oyuncu başına seyrelt, ses ekle |
| `RC/Modules/FrameController.luau` + `K` FRAME_DISPLAY | Konumu çizime göre ver, 9-slice ya da sabit oranlı görsel kullan, önizleme ile gösterim aynı görsel olsun, sahibin çerçevesi payload'da gelsin |
| `SSS/Round/init.luau` oy ve tally kısmı | Oyu çizim kimliğiyle gönder (A·4/1'deki yarış biter). Oy veren → oy kaydı. Herkese giden sonuç/podyum yayını. |

| Baştan yazılacak | Neden |
|---|---|
| Bütün ScreenGui'ler (CanvasGui, EmojiGui, Sidebar, Phase, Result, Market, Loading, Tutorial) | Güvenli alan yok, tek AR kısıtı var, telefonda 14-30 pt'lik dokunma hedefleri, sabit metinli fiyatlar, negatif boyutlu düğmeler. Koddan ya da Rojo modeliyle, `ScreenInsets = CoreUISafeInsets`, `UIScale` ve en az 44 pt kuralıyla. |
| `RC/Core/Sceneography.luau` GUI gizleme | Bütün PlayerGui'yi kapatmak `TouchGui`'yi öldürüyor (B·7). Yalnız oyunun kendi GUI listesini yönet. |
| Gösterim sahnesi (`RevealController`, `RevealIntroController`, `RevealCam` kadrajı) | Ekranın %45'inde, ışık almış, sıkışmış, isimsiz, sessiz bir gösterim. 2D tam ekran (ya da yakın kadraj) gösterim katmanı + isim/sayaç/süre çubuğu + ses olarak yeniden kurulmalı. |
| Yükleme ekranı | İçerik yanlış (tema), görsel geriliyor, sabit 5 sn bekletiyor, hatada takılıyor |
| `AS` + olay noktaları | 18. maddedeki huniyle, olduğu anda (çıkışta değil) |

## Gösterim ve çizimde en çok değer katacak 5 iş

1. **Gösterimi bir "an" hâline getir.**
   - Tam ekran 2D gösterim katmanı (ScreenGui + EditableImage); çizim ekranın ≥ %70'i.
   - Sahibin adı, "3 / 6", 5 sn'lik süre çubuğu, açılış sesi/davul, çizimler arası kısa geçiş.
   - Kare tuval + `LightInfluence 0` ile şekil ve renk bozulmasını gider.
   - *Neden:* Çekirdek ödül anı bugün ekranın %45'inde, soluk, sıkışmış ve sessiz oynuyor; oyunun komikliği burada ya yaşanıyor ya da kayboluyor (A·1-2).
   - *Büyüklük:* Orta, ~3-5 gün.
2. **Oy geri bildirimi ve tur sonu podyumu.**
   - Oy, çizim kimliğiyle gönderilsin ve sunucu onaylasın. Seçili emoji belirgin olsun. Canlı toplam görünsün.
   - Tur sonunda ilk 3 çizim + isim + tepki sayısı herkese gösterilsin. Veri zaten `roundEmojiResults` içinde (A·5).
   - *Neden:* Bugün oyuncu oyunun sayıldığını görmüyor, kazanan yok (OTOPSI C·8), geç oy yanlış çizime gidiyor (A·4/1).
   - *Büyüklük:* Orta, ~3-4 gün.
3. **Mobil çizim temizliği.**
   - `TouchGui` hatası; dokunma kimliği ve tek parmak; tuval dışı çizgi; ≥ 44 pt düğmeler (Submit 40×14 → büyük alt düğme); güvenli alan; dikey yön kararı.
   - *Neden:* Roblox trafiğinin büyük kısmı mobil. Bugün mobil oyuncu ilk turdan sonra yürüyemiyor, Submit'e zor basıyor, iki parmakta çizimi bozuluyor (B·7, C·11).
   - *Büyüklük:* Orta, ~3 gün (GUI yeniden yazımı ayrıca).
4. **Çizim verisinin güvenilirliği.**
   - Stroke geçmişini geri alma sınırından ayır (80+ stroke kaybı).
   - Çizim sırasında 5-10 sn'de bir sıkıştırılmış ara yükleme yap: çıkan ya da geç gönderen oyuncunun çizimi kaybolmaz, Submit anında gönderim mümkün olur, erken bitiş (OTOPSI H·17/1) kolaylaşır.
   - Silgi durumu düzeltilsin, ileri al ve temizle eklensin, "mürekkep bitti" uyarısı gösterilsin.
   - *Neden:* Bugün çizim sessizce eksik ya da hiç gösterilmeyebiliyor (B·6, B·9). Bu, oyuncunun emeğini çöpe atan en kötü hata türü.
   - *Büyüklük:* Küçük-orta, ~2-3 gün.
5. **Çizim ve gösterim olaylarıyla ölçüm.**
   - İlk fırça, teslim türü (düğme/süre), kendi çiziminin gösterimi + aldığı tepki, ilk oy, oy başına bağlam; olduğu anda gönderilsin.
   - `RoundComplete` "çizdi mi" alanını taşısın.
   - *Neden:* 1-4 numaralı işlerin etkisi ancak bu olaylarla görülür. Bugün emoji, ilk fırça ve gösterim için hiç olay yok (D·17-18).
   - *Büyüklük:* Küçük, ~1-2 gün (huni altyapısı OTOPSI F·14 ile ortak).
