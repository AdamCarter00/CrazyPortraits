# Script dışı veri (Studio, 2026-11-19, yalnız okuma)

Kaynak: Studio MCP `search_game_tree` / `inspect_instance` (place: "Crazy Portraits (ALPHA)", placeId 72378550860176, universeId 10098045434).

## RemoteEvent'ler — `ReplicatedStorage.Remotes` (hepsi RemoteEvent, RemoteFunction yok)

| Ad | Yön | Kullanan (dosya:satır) |
|---|---|---|
| ReadyRemote | C→S | istemci yüklenince bir kez: `StarterPlayer/StarterPlayerScripts/RoundClient/init.client.luau:217`; sunucu `ServerScriptService/Round/RoundRemotes.luau:102` |
| PhaseRemote | S→C | faz yayını: `ServerScriptService/Round/init.luau:67-73`, `RoundRemotes.luau:67,98,120` |
| SubmitRemote | C→S | "bitirdim" düğmesi: `RoundRemotes.luau:151` |
| DrawProgressRemote | C→S | çizim ilerleme sayaçları (2 sn'de bir): `RoundRemotes.luau:173` |
| CanvasRemote | C→S | çizim tamponu (yalnız COLLECTING'de kabul): `RoundRemotes.luau:185` |
| EmojiRemote | iki yön | oy + herkese emoji yağmuru: `RoundRemotes.luau:132`, `Round/init.luau:1031-1035` |
| ReportRemote | C→S | çizim raporu: `RoundRemotes.luau:146` |
| HideDrawingRemote | S→C | eşik aşılınca / ban'da çizimi gizle: `Round/init.luau:370,1082` |
| ClearDisplayRemote | S→C | gösterim sonu ekran temizliği: `Round/init.luau:873` |
| GalleryRemote | S→C | lobi galerisi (son tur, ≤8): `Round/init.luau:387,419,983` |
| ResultRemote | S→C | "You Got" sonuç ekranı: `Round/init.luau:955` |
| TutorialRemote | S→C | tek adımlı öğretici: `Round/init.luau:962` |
| SubjectChanceRemote | iki yön | "çizilme şansı" çubuğu: `Round/init.luau:317`, `RoundRemotes.luau:128` |
| StarRemote | iki yön | Yıldız bakiyesi: `ServerScriptService/PlayerDataService.luau:81,109` |
| FrameRemote | C→S | çerçeve al/tak/"opened": `ServerScriptService/FrameShopService.luau:150` |
| FrameStateRemote | S→C | çerçeve sahipliği: `PlayerDataService.luau:90` |
| AdminRemote | iki yön | admin paneli: `ServerScriptService/AdminCommandRouter.luau:60` |

## Configuration / *Value nesneleri

Oyuna ait hiç `Configuration` ya da `ValueBase` nesnesi yok (aramada çıkanların hepsi `PluginGuiService` altındaki RoMixamo eklentisine ait).
Bütün ayarlar `ReplicatedStorage/Modules/Constants.luau` içinde. Oyuncu attribute'u: `EquippedFrame` (`PlayerDataService.luau:101`).

## Ürün kimlikleri (koddan)

| Tür | Ad (koddan) | ID | Fiyat | Kaynak |
|---|---|---|---|---|
| Developer Product | Subject guarantee ("BE NEXT DRAWN") | 3606209956 | ? | `Constants.luau:200` |
| Game Pass | Cute çerçeve | 1891548320 | ? Robux (ayrıca 150 Yıldız) | `Constants.luau:265`, `:250` |
| Game Pass | Gold çerçeve | 1893605960 | ? Robux (ayrıca 150 Yıldız) | `Constants.luau:266`, `:251` |
| Game Pass | Goofy çerçeve | 1893947553 | ? Robux (ayrıca 150 Yıldız) | `Constants.luau:267`, `:252` |
| Game Pass | Dark çerçeve | 1893282287 | ? Robux (ayrıca 150 Yıldız) | `Constants.luau:268`, `:253` |
| — (yalnız Yıldız) | Wood çerçeve | — | 20 Yıldız | `Constants.luau:254` |
| — (yalnız Yıldız) | CardBoard çerçeve | — | 20 Yıldız | `Constants.luau:255` |

Robux fiyatları kodda ve place'te yok (`?`).

## DataStore adları (koddan)

| Store | Tür | Kaynak |
|---|---|---|
| PlayerData_v2 (ProfileStore, anahtar `player_<UserId>`) | DataStore | `PlayerDataService.luau:62,121` |
| PlayerSessionCount_v1 (anahtar `u<UserId>`) | DataStore | `Constants.luau:332`, `SessionService.luau:26` |
| BannedPlayers_v1 (anahtar `ban_<UserId>`) | DataStore | `Constants.luau:323`, `BanService.luau:71` |
| AdminAuditLog_v1 | DataStore | `Constants.luau:322`, `AdminService.luau:93` |
| ReportedDrawings_v1 | DataStore | `Constants.luau:324`, `ModerationService.luau:15` |
| ReportIndex_v1 | OrderedDataStore | `Constants.luau:325`, `ReportIndex.luau:28` |
| ReportAuditLog_v1 | DataStore | `Constants.luau:326`, `ModerationService.luau:16` |
| DrawingQuitLog_v1 / DrawingQuitLogIndex_v1 | DataStore / Ordered | `Constants.luau:330-331`, `QuitLog.luau:48-49` |
| FirstTimerDrawings_v1 / FirstTimerDrawingsIndex_v1 | DataStore / Ordered | `Constants.luau:336-337`, `FirstDrawingService.luau:35-36` |
| MessagingService konusu: AdminBan_v1 | — | `Constants.luau:327`, `BanService.luau:85,157` |
| GameAnalytics SDK kendi iç DataStore kuyruğu | ? | `Packages/_Index/.../Store/DataStoreQueue` (okunamadı) |

## Gizli anahtarlar

`ServerStorage/Secrets.luau`: GameAnalytics `GAME_KEY` + `SECRET_KEY`. Dosya snapshot'ta aynen var ama git'e girmedi (`.git/info/exclude`).

## ScreenGui ağacı (StarterGui, kısa)

- **LoadingGui**: LoadingImage, LoadingText ("Game Loading..." en az 5 sn).
- **Voices** (Folder): LoopSound (lobi müziği, sürekli), ClickSound, Rewards (kodda kullanılmıyor).
- **CanvasGui › MainFrame**: CanvasLabel (512×512 EditableImage), RightPanel (16 renk düğmesi), BottomPanel (ToolsFrame: Eraser/Undo/Fill; BrushsizeFrame: 0.01/0.04/0.08), TimerFrame›TimerLabel, ThemeFrame›ThemeLabel, SubmitFrame›SubmitButton.
- **EmojiGui › MainFrame**: ButtonsFrame (ImageButton: `laugh`, `skull`, `shocked`, `normal`), ReportButton, TextFrame›TextLabel.
- **SidebarGui › Container**: StarFrame (StarCount), SubjectFrame ("CHANCE TO BE DRAWN", ChanceFrame›ChanceBar/ChanceLabel, SubjectButton "BE NEXT DRAWN"), MarketFrame (MarketButton, NewLabel), InviteFrame (InviteButton).
- **PhaseGui › PhaseFrame**: PhaseInfo, ExtraInfo.
- **ResultGui › ResultFrame**: EmojiContainer (Laugh/Skull/ShockedFrame›Count), StarContainer (EmojiScore/RoundScore›Count).
- **MarketGui › Container**: CloseButton, Bar, FrameArea (1Cute, 2Gold, 3Goofy, 4Dark, 5Wood, 6CardBoard; her biri ButtonFrame›StarButton [+ RobuxButton, Wood ve CardBoard hariç]). `TopBar`/`Screens` yok (koddaki sekme bloğu ölü: `UIController.luau:341`).
- **PassGui › SkipFrame** (CanvasGroup) › Mid › PhaseLabel: faz geçiş perdesi.
- **TutorialGui › Step-1**: ImageLabel, TextLabel, 4× CloseTutoButton.
- Çalışma anında yaratılan: AdminPanelGui, DrawingsPanelGui (yalnız admin istemcisinde).

## Harita (Workspace.Map.GamePlay)

SpawnLocation, CamPart (çizim kamerası), SubjectPart + SubjectLight (modelin klonu burada durur), SubjectReleasePart (kodda yalnız varlığı kontrol ediliyor), SubjectClone (Folder), SubmitPart (bitirenlerin bekleme pedi), Screen›DisplayPart›SurfaceGui (Image, Frame, EmojiLayer), Reveal›Seats (seat1..seat8) + RevealCam, Gallery›GalleryCanvas (1..8) + GalleryParts (1..8), iki dekor model `1`, `2` (Canvas1).

8 koltuk + 8 galeri noktası var; kod yorumu "lobi koltuk sayısıyla sınırlı" diyor (`Round/init.luau:180`). Sunucu boyutu (Players.MaxPlayers) place'ten okunamadı: `?`.

## Diğer

- `ReplicatedStorage.Templates`: TemplateFrame, TagsCard (kodda referans yok).
- `ReplicatedStorage.Frames`: Wood, Pink, Gold Part'ları (kod artık kullanmıyor; `FrameController.luau:7` "no ReplicatedStorage.Frames folder").
- `Workspace.PL3Trampoline`: ücretsiz model trambolin (2017).
- TextChatService komutları çalışma anında yaratılıyor: `/panel`, `/drawings` (`AdminChatHook.luau:24`, `DrawingsChatHook.luau:22`).
