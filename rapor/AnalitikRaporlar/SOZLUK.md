# Sözlük — koddaki olaylar

Olayların anlamı ve okuma hesabı kasada **T-021**'de. Burada yalnız koddan çıkan okuma bilgisi: Explore'daki
"Custom field 1/2/3" hangi alan, değerler ne yazıyor, olay kodda tam olarak ne zaman gidiyor.
Kaynak: `src/shared/Config/Analytics.luau` (adlar, değerler, sınırlar), `src/shared/Analytics/Metrics.luau` (tetikler).
Kod: iş 6, 2026-11-20.

## Alan sırası (Custom field 1 · 2 · 3)

| Olay | Değer | 1 | 2 | 3 |
|---|---|---|---|---|
| IlkGiris | 1 = girişte sunucuda tek, 0 = değil | kohort | kaynak | surum |
| D1Donus | 1 | kohort | kaynak | surum |
| Cikis | oturum süresi (sn, yuvarlanmış) | kohort | kaynak | oturum_tipi |
| BesDakika | 1 | kohort | kaynak | o_an |
| Eslesme | girişten ikinci bağlantıya sn (eşleşmediyse oturum süresi) | eslesti | kohort | ilk_oturum |
| TurBasladi | girişten tur başına sn | rol | kohort | ilk_oturum |
| IlkReveal | 1 | reveal_rol | kohort | ilk_oturum |
| TurTamam | 1 | tur_sirasi | katilim | kohort |

## Değerler

- **kohort:** ilk girişin UTC günü `YYYY-AA-GG` (Config'teki aralıkta; dışındaysa `aralik_disi`) · `bilinmiyor` = profil
  okunamadı **ya da F-001'den kalma eski profil** (ilk giriş kaydı yok).
- **kaynak:** `etiketli` = girişte ya da profil yüklenince LaunchData boş olmayan bir metin (içeriği gönderilmez) ·
  `etiketsiz` · `bilinmiyor` (yukarıdaki iki durum). Profilde ilk girişteki değer saklanır; D1Donus ve Cikis onu yazar.
- **surum:** ilk girişteki oyun sürümü (`V0`).
- **oturum_tipi:** `ilk_0-60` / `ilk_60-300` / `ilk_300+` (ilk oturum, süreye göre) · `donus` (kayıtlı ya da eski
  profil) · `bilinmiyor` (profil okunamadı ya da profil gelmeden çıktı).
- **o_an:** `lobide` (lobi aşaması) · `turda` (o anki turun katılımcısı; çizim, toplama, reveal, podyum) · `beklemede`
  (tur sürüyor, oyuncu katılımcı değil).
- **eslesti:** `evet` / `hayir`. **ilk_oturum:** `evet` / `hayir` / `bilinmiyor`.
- **rol:** `model` / `cizen`. **reveal_rol:** `model` / `cizen` (boş teslim eden dahil) / `izleyici`.
- **tur_sirasi:** oturumda reveal'ı biten kaçıncı tur (`1`–`4`, `5+`); izlenen turlar da sayılır.
- **katilim:** `model` · `cizdi` (en az bir çizgi) · `bos_teslim` (boş gönderdi ya da süre bitti) · `izledi`
  (katılımcı değil, reveal biterken hazırdı).

## Tetik ayrıntıları (koddan)

- Oyuncu `PlayerAdded`'da izlenmeye başlar (giriş anı = süre başlangıcı). Profil gelene kadar alanı profile bağlı
  olaylar bekletilir, profil gelince değer o anki haliyle gönderilir; profil gelmeden çıkarsa `bilinmiyor` alanlarla.
- Yeni oyuncu = profil o oturumda ilk kez oluştu. IlkGiris profil yüklenince gider; kayıt (`firstJoin`) aynı anda
  profile yazılır ve hemen kaydedilir, bir daha yazılmaz.
- D1Donus: oturumun giriş günü = kayıttaki gün + 1 ise, profil yüklenince bir kez. Gece yarısını oyundan çıkmadan
  geçen oturum D1Donus göndermez.
- BesDakika ve TurTamam yalnız `ilk_oturum = evet` için gider; profil okunamayan oyuncuda gitmez.
- İptal edilen tur (kimse çizmedi) reveal'a girmez: IlkReveal ve TurTamam yok, TurBasladi gitmiş olabilir.
- Studio'da hiçbir olay servise gitmez; Output'a `[Analitik] <Olay> deger=… alan=…` yazılır.
- Oran sınırı aşılırsa olay düşer; IlkGiris, D1Donus ve Cikis'e ayrılmış pay var.
