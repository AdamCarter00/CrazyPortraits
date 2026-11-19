# Explorer haritası (yalnız script'ler)

Dosya uzantısı: `.server.luau` = Script, `.client.luau` = LocalScript, `.luau` = ModuleScript.
Çocuğu olan script'ler Rojo düzeninde klasör + `init` olarak yazıldı.

```
ServerScriptService/
  GameServer.server.luau        Tek giriş noktası: servisleri başlatır, PlayerAdded/Removing sırasını yönetir
  Round/init.luau               RoundManager: tur durum makinesi (Waiting→Drawing→Collecting→RevealIntro→Reveal→Clean), oy, rapor, galeri, ödül
  Round/RoundState.luau         Tur ve oyuncu durumu tablosu + tur token'ı
  Round/RoundRemotes.luau       İstemci→sunucu remote dinleyicileri (Ready, Submit, Canvas, Emoji, Report, DrawProgress, SubjectChance), ara katılım/izleyici
  SubjectService.luau           Model (çizilen oyuncu) seçimi (ağırlıklı rastgele) + klonu sahneye koyma
  SubjectGuaranteeService.luau  ProcessReceipt: "sıradaki model sen ol" Developer Product
  ThemeService.luau             18 tema listesi + oyuncu başına tekrarsız dağıtım
  StrokeValidator.luau          İstemciden gelen çizim tamponunu doğrular/kırpar
  PlayerDataService.luau        ProfileStore profili: Yıldız, garanti hakkı, çerçeveler, tutorial
  ProfileStore.luau             Üçüncü parti (loleris / MAD STUDIO) oturum kilitli DataStore kütüphanesi
  FrameShopService.luau         Çerçeve mağazası: Yıldızla alım, Game Pass senkronu, tak/çıkar
  AnalyticsService.luau         GameAnalytics SDK sarmalayıcısı (design/error event)
  GroupService.luau             UserId tek/çift → A/B grubu (yalnız analitik etiketi)
  SessionService.luau           Ömür boyu oturum sayacı (DataStore)
  QuitLog.luau                  Çizim ortasında çıkanların araştırma kaydı (DataStore)
  FirstDrawingService.luau      İlk kez gelenlerin ilk çizimini saklar (admin "First-Timers")
  ModerationService.luau        Rapor kaydı, eşik denetimi, rapor denetim izi
  ReportIndex.luau              Raporlar için OrderedDataStore dizini
  DataStoreRetry.luau           DataStore yazımı için yeniden deneme
  BanService.luau               Süreli/kalıcı ban + MessagingService ile sunucular arası atma
  AdminService.luau             Admin beyaz listesi, denetim kaydı, anomali sayacı, hız sınırı
  AdminCommandRouter.luau       AdminRemote komut yönlendirici
  AdminPanelService.luau        /panel: rapor listesi, görüntüle, dismiss, ban
  AdminChatHook.luau            /panel sohbet komutu
  DrawingsPanelService.luau     /drawings: ilk çizimleri sayfalı gezme
  DrawingsChatHook.luau         /drawings sohbet komutu
ServerStorage/
  Secrets.luau                  GameAnalytics anahtarları (git'e girmez)
ReplicatedStorage/
  Modules/Constants.luau        Bütün sabitler: süreler, limitler, renkler, ürün ID'leri, store adları
  Modules/StrokeCodec.luau      Çizim ⇄ ikili tampon (5 bayt başlık + 4 bayt/nokta)
  Modules/DrawRenderer.luau     Çizimi EditableImage'a basar (canvas ile piksel-aynı)
  Modules/FloodFill.luau        4-komşulu kova doldurma (tahsissiz)
  Packages/GameAnalytics.luau   Wally paketi yönlendiricisi → _Index/gameanalytics-sdk@2.2.6 (iç modüller KOPYALANAMADI)
StarterPlayer/StarterPlayerScripts/
  RoundClient/init.client.luau  İstemci girişi: yükleme, modülleri bağlar, faz yönlendirme, emoji, Ready sinyali
  RoundClient/Core/RefsBuilder.luau     Yükleme ekranı + GUI/harita referansları (fatal/required/optional)
  RoundClient/Core/PhaseRouter.luau     Faz adı → controller Enter/Exit
  RoundClient/Core/Sceneography.luau    Kamera, GUI gizle/göster, gösterim ekranına çizim basma
  RoundClient/Core/RevealEvents.luau    Gösterim sinyalleri
  RoundClient/Core/Signal.luau          Basit sinyal
  RoundClient/Phases/WaitingController.luau      Lobi: "Waiting for players" / "Round starting in Ns"
  RoundClient/Phases/DrawingController.luau      Çizim fazı: tuval, süre, Submit, zıplamayı kapatma, ilerleme raporu
  RoundClient/Phases/CollectingController.luau   Tuvali kodlayıp CanvasRemote ile gönderir
  RoundClient/Phases/RevealIntroController.luau  Gösterim kamerası + "Get ready"
  RoundClient/Phases/RevealController.luau       Tek çizimi gösterir + sahibin çerçevesi
  RoundClient/Phases/CleanRoundController.luau   Tur sonu: lobiye dönüş
  RoundClient/Reveal/EmojiRain.luau              Gelen her emojiyi ekranda yükselen ikon olarak oynatır
  RoundClient/Modules/CanvasController.luau      Yerel çizim, geri al, doldur, piksel bütçesi
  RoundClient/Modules/InputController.luau       Fare/dokunma → tuval
  RoundClient/Modules/UIController.luau          Araç/renk/fırça düğmeleri, Submit, Report, Market, Invite
  RoundClient/Modules/GalleryController.luau     Lobideki 8 mini tuval
  RoundClient/Modules/ResultController.luau      "You Got" sonuç ekranı
  RoundClient/Modules/TutorialController.luau    Tek adımlı öğretici
  RoundClient/Modules/SubjectController.luau     Şans çubuğu + "BE NEXT DRAWN" satın alma istemi
  RoundClient/Modules/MarketController.luau      Çerçeve mağazası kartları
  RoundClient/Modules/FrameController.luau       Gösterimde sahibin çerçevesi
  RoundClient/Modules/PassController.luau        Faz geçiş perdesi (PassGui)
  RoundClient/Modules/AdminPanelClient.luau      KOPYA (AdminClient altındakiyle bayt bayt aynı; require eden yok)
  RoundClient/Modules/DrawingsPanelClient.luau   KOPYA (aynı; require eden yok)
  AdminClient/init.client.luau                   AdminRemote olaylarını panellere dağıtır
  AdminClient/AdminPanelClient.luau              /panel arayüzü (çalışma anında kurulur)
  AdminClient/DrawingsPanelClient.luau           /drawings arayüzü
Workspace/PL3Trampoline/Bouncer/Script.server.luau  Ücretsiz model trambolin (@CloneTrooper1019, 2017)
```

## Kopyalanamayanlar

| Ne | Neden |
|---|---|
| `ReplicatedStorage.Packages._Index["gameanalytics_gameanalytics-sdk@2.2.6"]` altındaki 20 ModuleScript (gameanalytics-sdk, GameAnalytics, GameAnalyticsClient, Events, GAErrorSeverity, GAProgressionStatus, GAResourceFlowType, HttpApi, HashLib, Base64, Logger, Postie, State, Store, DataStoreQueue, Threading, Types, Utilities, Validation, Version) | Klasör adında nokta var (`@2.2.6`); MCP `script_read` noktalı yolu çözemiyor ("Script not found"). Okumanın tek yolu `execute_luau`, o da kurala aykırı (çalıştırma). Paket Wally'den `gameanalytics/gameanalytics-sdk@2.2.6` olarak yeniden indirilebilir; Studio'daki kopyanın değiştirilip değiştirilmediği: `?` |

Satır sonları: MCP çıktısı dosya sonundaki satır sonunu göstermiyor; dosyalar satırlar `\n` ile birleştirilerek yazıldı. İçerik değiştirilmedi.
