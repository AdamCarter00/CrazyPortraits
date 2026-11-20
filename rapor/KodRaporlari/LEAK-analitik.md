# LEAK analitik altyapısı — F-015 için inceleme

Yalnız okuma. Kaynak: `Oyunlar\LEAK\Proje` (`src/server/Analytics.luau`, `src/shared/Config/Analytics.luau`,
`src/server/Session/MatchMetrics.luau`, `src/server/Hub/HubController.luau`, `tests/shell/olcum.spec.luau`).
Testleri bu oturumda koşmadım; aşağıdaki test bilgisi dosyadan okundu.

## 1. Modüller

| Modül | İş |
|---|---|
| `server/Analytics.luau` | Tek giriş kapısı. `AnalyticsService`'i sarar; şema doğrular, bütçe uygular, hatayı yutar. |
| `shared/Config/Analytics.luau` | Saf veri: olay → alan listesi (`Events`), alan → izinli değerler (`Fields`), kova sınırları, bütçe, adım adları, kampanya listesi. |
| `server/Session/MatchMetrics.luau` | Masa (desk place) tarafı olay üreticisi. Maç durumunu izler, oyun olaylarını analitik olaya çevirir. Her işlev `pcall` içinde; iç hata oyunu durdurmaz. |
| `server/Hub/HubController.luau` | Hub (lobi place) tarafı olay üreticisi: kuyruk, menü, ışınlanma, kampanya. Metrikler `entry.metric` altında. |
| `Matchmaking/{Bus,Penalties,Store,Travel}.luau` | Yalnız `Analytics.backend(servis, işlem)` çağırır (`BackendIssue`). |
| `Matchmaking/Store.Trail` | Oyuncunun izi (`matches`, `funnel`, `funnelStep`, `campaign`, `firstSession`, `menuOpened`); ışınlanmayla hub ↔ masa arasında taşınır. |

`Analytics.luau` içindeki işlevler:

- **Özel olay:** `log(player, ad, değer, alanlar)` → `LogCustomEvent`. Şema Config'ten; alan değeri izinli listede değilse, alan eksik ya da fazlaysa ya da olay bilinmiyorsa hiçbir şey gitmez (`warn`).
- **Özel alan:** alanlar şema sırasına göre `CustomField01..03` anahtarına yazılır (`Enum.AnalyticsCustomFieldKeys`); değerler hep metin.
- **Onboarding hunisi:** `onboarding(player, adım, {campaign})` → `LogOnboardingFunnelStepEvent`; adım numarası `Config.OnboardingSteps` sırasından gelir.
- **Funnel:** `queueStep(player, sessionId, adım, ulaşılan)` → `LogFunnelStepEvent`, huni adı `Queue`. Kimlik her kuyruk girişinde `HttpService:GenerateGUID`. Geçilmiş adım tekrar yazılmaz.
- **Segment okuma:** yok. `GetSegment`, `GetDefaultCustomFields`, `UserAcquisitionSource` kullanılmıyor. Kaynak ayrımı oyuncunun `GetJoinData().LaunchData` değeriyle yapılıyor (`campaign()`, `readCampaign`, `awaitCampaign`: en çok 10 deneme, 1 sn arayla).
- **Oran sınırı:** `spend()`: 60 sn'lik pencerede en çok `18 × son pencerenin en yüksek oyuncu sayısı` olay. Aşılırsa olay **düşer**; kuyruk ya da yeniden deneme yok.
- **Diğer:** `BackendIssue` için servis+işlem başına 60 sn bekleme; hata uyarısı 60 sn'de bir; Studio'da servise gitmez, Output'a `[Analitik] …` yazar; `Config.Enabled` her şeyi kapatır; `forTable` masa olaylarını sunucudaki ilk oyuncuya bağlar, sunucu boşsa göndermez; kova işlevleri (`waitBucket`, `stayBucket`, `lobbyBucket`, `leaveGap`, `peak`, `experience`, `pool`, `group`, `yesNo`).

## 2. Gönderilen olaylar

Değer sütunu `LogCustomEvent`'in sayı değeri. Her olay en çok 3 alan taşır.

| Olay | Değer | Alanlar |
|---|---|---|
| QueueWait | bekleme sn | wait_bucket, group, pool |
| QueueAbandon | bekleme sn | abandon_how, wait_bucket, pool |
| HubLeftUnqueued | hubda kalma sn | stay_bucket, menu_opened |
| DeskBound | 1 | route, experience, group |
| PlayMenuOpened | 1 | first_session |
| Teleport | ışınlanma sn | teleport_kind, teleport_result, teleport_route |
| CountdownLeft | 1 | countdown_how |
| MatchStarted | oyuncu sayısı | table_kind, social, continuation |
| MatchEnded | maç süresi sn | ending, players, table_kind |
| TableClosed | masada oynanan maç | table_kind, peak |
| PlayerMatchResult | oyuncunun mesaj sayısı | experience, result, chat |
| NextMatch | 1 | decision, experience, last_result |
| MidMatchLeave | el numarası | status, role, experience |
| PhaseTimeout | 1 | phase, actor, experience |
| VoteCast | 1 | vote, experience |
| CardDiscarded | 1 | changed, timed_out, experience |
| BackendIssue | 1 (havuz belgesinde bayt) | service, operation |
| QueueJoined | 1 | pool, subscription, previous |
| QueueAttemptClosed | deneme sn | attempt_result, pool, exit_pool |
| AfterCancel | iptalden sonra sn (eylem yoksa 60) | next_action, pool |
| LobbyLeft | lobide kalma sn | lobby_how, table_kind, lobby_bucket |
| LeaveDetail | maç süresi sn | leave_phase, leave_order, leave_gap |

Huniler:

- **Onboarding** (yalnız ilk maçını oynamamış oyuncu için; alan `campaign`): HubArrival → PlayMenu → DeskBound → DeskArrival → MatchStart → MatchEnd.
- **Queue funnel** (kimlik = GUID): Queued → Found → Arrived → Started.

Alan değerleri `Config.Fields`'te kapalı listelerdir (ör. `experience`: first / 2-5 / 6+, `result`: won / lost / cancelled / left_alive / left_ghost, kovalar `0-30`, `30-60`…). Kullanıcı adı ve numarası hiçbir alana ya da huni kimliğine girmez (test zorluyor).

## 3. F-015 için sınıflandırma

**Olduğu gibi taşınabilir** (oyuna bağlı olmayan mekanizma):

- `Analytics.luau` çekirdeği: şema doğrulama + `CustomFieldNN` eşlemesi (`encode`), `deliver` (Studio'da yaz, canlıda `pcall`), `spend` bütçesi, hata uyarısı sınırı, `Enabled` anahtarı, `log`, `onboarding`, `queueStep` (adıyla funnel adımı), kova yardımcısı, `backend` bekleme mantığı.
- Config biçimi: dondurulmuş `Events` (olay → alan listesi) + `Fields` (alan → izinli değerler); "olay başına ≤3 alan, değer birleşimleri ≤8000" testi.
- Test altyapısı: `AnalyticsService` ve `Enum.AnalyticsCustomFieldKeys` taklidi (`DeskSim.luau:473-490, 563-568`), servis hatası enjekte etme (`analyticsFails`), bütçeyi seçenekle düşürme.
- Her izleyici işlevini `pcall`'la saran kalıp (`MatchMetrics` sonu).

**Değişmesi gereken:**

- `Shared`, `Session.Clock` bağımlılıkları: F-015'te zaman dışarıdan girer kuralı var; `Clock.now()` yerine enjekte edilen saat.
- `task.wait` ve `HttpService` çağrıları `Analytics.luau` ve hub kodunda; F-015'te saf `src/shared` içine girmemeli, sunucu katmanında kalmalı.
- Bütçe sunucu geneli ve ilk oyuncuya bağlı (LEAK'in kendi borcu: tek istemci payı bitirebilir, `BORC.md` satır 27). F-015'te en az `BackendIssue` benzeri sistem olaylarını ayırmak düşünülmeli.
- Segment ve kaynak: LEAK `LaunchData` kullanıyor; F-015 listesi `UserAcquisitionSource` ve reklam açık mı istiyor (`IS-LISTESI.md` satır 50). LEAK'te karşılığı yok, sıfırdan yazılacak. `GetSegment` okuması da yok.
- Uyarı metinleri koda gömülü Türkçe (`"Analitik gonderilemedi"`); F-015'te geliştirici metni de Config'e alınacaksa taşınmalı.
- Olay listesi sunucu başına oyuncu sayısı zaman serisini (IS-LISTESI, madde 21) içermiyor; `peakPlayers` yalnız bütçe için, olay değil.

**LEAK'e özgü (taşınmaz):**

- Bütün `Events` ve `Fields` içeriği: kuyruk, havuz, parti, ışınlanma, rol, oy, kart, güç, faz, ceza kaydı.
- `MatchMetrics`, `HubController` metrik bölümü, `Store.Trail`: hub ↔ masa iki place ve ışınlanma izi. F-015 tek place; iz taşıma ve `TeleportRoutes`, `Penalties.matches` bağı gerekmez.
- `Campaigns` (KAPAK-A/B), `LaunchData` bekleme döngüsü.
- Oyuna özel huni adımları (`HubArrival` … `MatchEnd`, `Queue`).
- `BackendIssue` servis/işlem listesi (MemoryStore havuzu, Messaging, Teleport).

## 4. Testler

Var: `tests/shell/olcum.spec.luau`, yaklaşık 2300 satır, 131 `it`. Kapsadığı konular: şema (olay sayısı, alan sayısı, 8000 sınırı), kova sınırları, alan anahtarı biçimi, izinsiz değer düşer, servis hatasında oyun sürer, bütçe aşımı, Studio'da yalnız Output, kapatma anahtarı, kampanya/LaunchData varyasyonları, huni kimliği ve adım sırası, masa/maç olayları, ışınlanma yolları, `BackendIssue`, gizlilik (ad ve numara hiçbir alana girmez), sık döngülerde olay üretilmemesi. Testler `DeskSim` simülatörü üzerinden sahte `AnalyticsService` ile koşar; gerçek servis çağrılmaz.

Yok: `Analytics.luau` için ayrı, hub/masa'dan bağımsız birim test dosyası; çekirdek yalnız bu büyük dosya ve `DeskSim` üzerinden sınanıyor. F-015'e taşırken çekirdek için küçük bir ayrı spec yazmak daha kolay olur.

## 5. Ek notlar

- LEAK `BORC.md` analitikle ilgili satırlar: bütçenin sunucu geneli olması (27), ışınlanma izinin iki yerde kopyası (30), eski sürüm sunucunun `matches`/`seen` alanlarını silmesi (29).
- Ayrıntılı ölçüm raporları LEAK'te `rapor\AnalitikRaporlar\0-kurulum\` (`olcum.md`, `olcum-plan.md`, `ultra-olcum.md`, `olcum-son.md`); bu inceleme onları okumadı.
