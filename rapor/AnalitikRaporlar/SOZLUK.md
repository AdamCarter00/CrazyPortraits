# Sözlük — koddaki olaylar

Olayların anlamı ve okuma hesabı kasada **T-021** (K-008 ile) içinde. Burada yalnız koddan çıkan okuma bilgisi:
Explore'daki "Custom field 1/2/3" hangi alan, değerler ne yazıyor, olay kodda tam olarak ne zaman gidiyor.
Kaynak: `src/shared/Config/Analytics.luau` (adlar, değerler, sınırlar), `src/shared/Analytics/Metrics.luau` (tetikler).
Kod: iş 6, 2026-11-20 (K-008, Cikis fazı + izliyor, Teslim, CizimTepki + sahibi çıktı mı eklemeleriyle).

## Alan sırası (Custom field 1 · 2 · 3)

| Olay | Değer | 1 | 2 | 3 |
|---|---|---|---|---|
| IlkGiris | 1 = girişte sunucuda tek, 0 = değil | kohort | surum | — |
| D1Donus | 1 | kohort | surum | — |
| Cikis | oturum süresi (sn, yuvarlanmış) | kohort | oturum_tipi | faz |
| BesDakika | 1 | kohort | o_an | — |
| Eslesme | girişten ikinci bağlantıya sn (eşleşmediyse oturum süresi) | eslesti | kohort | ilk_oturum |
| TurBasladi | girişten tur başına sn | rol | kohort | ilk_oturum |
| IlkReveal | 1 | reveal_rol | kohort | ilk_oturum |
| TurTamam | 1 | tur_sirasi | katilim | kohort |
| Teslim | çizimin açıldığı andan (3-2-1 sayımı bitince, T-022) teslime sn | nasil | cizgi | kohort |
| CizimdeCikis | 3-2-1 sayımı bitip çizim açıldıktan (ya da oyuncu tura sonradan girdikten) çıkışa sn; sayım sırasında çıkan 0 | cizgi | kohort | ilk_oturum |
| CizimTepki | tepki veren ÷ tepki verebilecek × 100 (tam sayı) | ekrandaki | sahibi_cikti | kohort |

## Değerler

- **kohort** (K-008): `<gün>/<kaynak>`, ör. `2026-11-20/etiketli`.
  - gün: ilk girişin UTC günü `YYYY-AA-GG` (Config'teki aralıkta, şimdi 2026-11-20 – 2027-02-28; dışındaysa
    `aralik_disi`).
  - kaynak: `etiketli` = girişte ya da profil yüklenince LaunchData boş olmayan bir metin (içeriği gönderilmez) ·
    `etiketsiz`. Profilde ilk girişteki değer saklanır.
  - `bilinmiyor/bilinmiyor` = profil okunamadı **ya da F-001'den kalma eski profil** (ilk giriş kaydı yok). Gün ve
    kaynak yalnız birlikte bilinmiyor olur; `bilinmiyor/etiketli` gibi bir değer gitmez.
  - Etiketli dilim: kohort `…/etiketli` ile biten değerler. Bir gün için: `2026-11-20/etiketli` + `2026-11-20/etiketsiz`.
- **surum:** ilk girişteki oyun sürümü (`V0`).
- **oturum_tipi:** `ilk_0-60` / `ilk_60-300` / `ilk_300+` (ilk oturum, süreye göre) · `donus` (kayıtlı ya da eski
  profil) · `bilinmiyor` (profil okunamadı ya da profil gelmeden çıktı).
- **faz** (çıkış anı): `lobi` (lobi aşaması) · `izliyor` (çizim ya da toplama aşaması, oyuncu turun katılımcısı
  değil) · `cizim_teslimsiz` (aynı aşama, katılımcı, teslim etmemiş) · `teslim_sonrasi` (aynı aşama, katılımcı,
  teslim etmiş) · `reveal` · `podyum` (bu ikisi katılımcı olsun olmasın herkes için).
  Çıkışın kendisi turu ilerletse de (son bekleneni çıkınca reveal başlar) çıkıştan önceki faz yazılır.
- **o_an:** `lobide` (lobi aşaması) · `turda` (o anki turun katılımcısı; çizim, toplama, reveal, podyum) · `beklemede`
  (tur sürüyor, oyuncu katılımcı değil).
- **eslesti:** `evet` / `hayir`. **ilk_oturum:** `evet` / `hayir` / `bilinmiyor`.
- **rol:** `model` / `cizen`. **reveal_rol:** `model` / `cizen` (boş teslim eden dahil) / `izleyici`.
- **tur_sirasi:** oturumda reveal'ı biten kaçıncı tur (`1`–`4`, `5+`); izlenen turlar da sayılır.
- **katilim:** `model` · `cizdi` (en az bir çizgi) · `bos_teslim` (boş gönderdi ya da süre bitti) · `izledi`
  (katılımcı değil, reveal biterken hazırdı).
- **nasil:** `dugme` (çizim aşamasında gelen teslim) · `sure_doldu` (süre bitince istemcinin kendiliğinden gönderdiği,
  toplama aşamasında gelen teslim). Son saniyede basılan düğme gecikmeyle toplama aşamasına düşerse `sure_doldu` olur.
- **cizgi:** Teslim'de teslim edilen çizgi sayısı; CizimdeCikis'te istemcinin o turda en son bildirdiği çizgi sayısı
  (bildirim çizgi sayısı değiştikçe, en sık `Round.ProgressSendSeconds`'ta bir; son birkaç saniyedeki çizgiler
  eksik kalabilir; hiç bildirim yoksa `0`). Kovalar `0` / `1-10` / `11-40` / `41-80` / `80+`.
- **ekrandaki:** o çizim gösterilirken en az bir an hazır olan, sahibi dışındaki oyuncu sayısı `1` / `2-3` / `4-7`
  (8 ve üstü de `4-7`). CizimTepki'nin paydası budur.
- **sahibi_cikti:** `hayir` = olay çizim sahibine bağlı · `evet` = sahibi gösterim bitmeden oyundan çıkmıştı, olay
  sunucuda o an en erken girmiş oyuncuya bağlı. İki durumda da kohort alanı sahibinin. Bu olayı tekil kullanıcıyla
  sayma; değerin ortalamasıyla oku.

## Tetik ayrıntıları (koddan)

- Oyuncu `PlayerAdded`'da izlenmeye başlar (giriş anı = süre başlangıcı). Profil gelene kadar alanı profile bağlı
  olaylar bekletilir, profil gelince değer o anki haliyle gönderilir; profil gelmeden çıkarsa `bilinmiyor` alanlarla.
- Yeni oyuncu = profil o oturumda ilk kez oluştu. IlkGiris profil yüklenince gider; kayıt (`firstJoin`) aynı anda
  profile yazılır ve hemen kaydedilir, bir daha yazılmaz.
- D1Donus: oturumun giriş günü = kayıttaki gün + 1 ise, profil yüklenince bir kez. Gece yarısını oyundan çıkmadan
  geçen oturum D1Donus göndermez.
- BesDakika ve TurTamam yalnız `ilk_oturum = evet` için gider; profil okunamayan oyuncuda gitmez.
- İptal edilen tur (kimse çizmedi) reveal'a girmez: IlkReveal, TurTamam ve CizimTepki yok; TurBasladi ve Teslim
  gitmiş olabilir.
- Teslim: sunucunun kabul ettiği her teslimde bir kez (turda bir oyuncu bir kez teslim edebilir).
- CizimdeCikis: çıkıştaki faz `cizim_teslimsiz` ise, Cikis'ten hemen önce. İzleyen (`izliyor`) ve teslim edip çıkan
  için gitmez.
- CizimTepki: çizimin gösterimi bitince (sonraki çizime ya da podyuma geçince). Sahibinin kendi oyu sayılmaz, nötr
  emoji sayılır. Sahibi o anda oyunda değilse sunucudaki ilk gelen oyuncuya bağlanır (LEAK `forTable` kalıbı);
  sunucuda kimse yoksa ya da tepki verebilecek kimse yoksa gitmez.
- Studio'da hiçbir olay servise gitmez; Output'a `[Analitik] <Olay> deger=… alan=…` yazılır.
- Oran sınırı aşılırsa olay düşer; IlkGiris, D1Donus ve Cikis'e ayrılmış pay var.
