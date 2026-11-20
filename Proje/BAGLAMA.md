# BAGLAMA

Haritanın ve arayüzün motora bağlandığı işaretler. Kod yeni bir arayüz nesnesi isterse önce buraya satır olarak
girer; arayüzün kurulum listesi bu dosyadır (CLAUDE.md → Harita ve arayüz). Test, bu dosya ile kodu iki yönde
karşılaştırır: kodda olup burada olmayan da, burada olup kodda olmayan da hata.

İşaret: nesnenin `Isaret` attribute'unun (string) değeri. Küçük harf, alt çizgi, Türkçe karakter yok.
**Nesnenin adı işaretle aynı olursa komut işareti kendisi atar** (aşağıda "İşaretleme komutu").

Seçilebilir düğmelerin (Not sütununda "seçilebilir") altında adı ve işareti `secili` olan, kapalı bir `UIStroke`
bulunur. Kod yalnız onun `Enabled`'ını açıp kapatır; renk ve kalınlık Adam'ın.

Her ScreenGui kendi işaretini taşır. Çizim sırasında işaretli ScreenGui'ler gizlenir (çizim ve geçiş hariç);
işaretsiz olanlar ve Roblox'un `TouchGui`'si ellenmez. Her ScreenGui `ResetOnSpawn = false` olmalı.

Kod nesne yaratmaz, yalnız içerik, görünürlük ve davranış yazar. "Kod yazar" sütunu bunu söyler; yazılmayan her şey
(renk, yazı tipi, ikon, saydamlık, yerleşim) Adam'ın.

## Çizim

| İşaret | Sınıf | Not | İş |
|---|---|---|---|
| `cizim_ekran` | ScreenGui | Çizim ekranı | 3 |
| `cizim_tuval` | ImageLabel | Çizimin yapıldığı yüzey; kare olmalı (kod EditableImage bağlar) | 3 |
| `cizim_sure` | TextLabel | Kalan süre | 3 |
| `cizim_baslik` | TextLabel | "Draw …" satırı (tema yok, T-001) | 3 |
| `cizim_gonder` | GuiButton | Submit; en az 44 pt (T-015) | 3 |
| `arac_silgi` | GuiButton | Silgi, seçilebilir | 3 |
| `arac_kova` | GuiButton | Kova doldurma, seçilebilir | 3 |
| `arac_geri` | GuiButton | Geri al | 3 |
| `firca_1` `firca_2` `firca_3` | GuiButton | Fırça boyları, `Config.Drawing.BrushSizes` sırasıyla, seçilebilir | 3 |
| `renk_siyah` `renk_beyaz` `renk_gri` `renk_ten` `renk_kirmizi` `renk_turuncu` `renk_sari` `renk_yesil` `renk_turkuaz` `renk_mavi` `renk_mor` `renk_pembe` `renk_kahve` `renk_koyu_yesil` `renk_lacivert` `renk_bordo` | GuiButton | Palet; renk değeri `Config.Drawing.Colors`'tan, seçilebilir | 3 |

## Faz göstergesi ve geçiş perdesi

| İşaret | Sınıf | Not | İş |
|---|---|---|---|
| `asama_ekran` | ScreenGui | Faz göstergesi: lobi bekleme/geri sayım, "Waiting for others", "Collecting drawings", "Round over" | 3 |
| `asama_ana` | TextLabel | Ana metin | 3 |
| `asama_ek` | TextLabel | Ek metin: süre, geri sayım, sıra | 3 |
| `gecis_ekran` | ScreenGui | Faz geçiş perdesi | 3 |
| `gecis_cerceve` | CanvasGroup | Perdenin solan çerçevesi | 3 |
| `gecis_etiket` | TextLabel | Perdedeki aşama adı | 3 |

## Yükleme (T-018)

| İşaret | Sınıf | Not | İş |
|---|---|---|---|
| `yukleme_ekran` | ScreenGui | Yükleme ekranı; sabit bekleme yok, hazır olunca kod kapatır | 8 |
| `yukleme_adim_1` `yukleme_adim_2` `yukleme_adim_3` | TextLabel | Üç adım; metin `Terms.LoadingSteps` sırasıyla | 8 |
| `yukleme_durum` | TextLabel | Hata ya da bekleme durumu | 8 |
| `yukleme_tekrar` | GuiButton | Hata olunca yeniden dene | 8 |

## Lobi (T-020: yalnız Invite)

| İşaret | Sınıf | Not | İş |
|---|---|---|---|
| `lobi_ekran` | ScreenGui | Lobi paneli; Yıldız sayacı, Market, Be Next Drawn ve "Chance to be drawn" çubuğu yok | 9 |
| `lobi_davet` | GuiButton | Invite | 9 |

## Reveal (T-004)

| İşaret | Sınıf | Not | İş |
|---|---|---|---|
| `reveal_ekran` | ScreenGui | 2B katman; arkadaki karartma ve model solda için ayrı satır gerekmez (karartma bu ekranın içinde duran sabit bir Frame) | 4 |
| `reveal_tuval` | ImageLabel | Gösterilen çizim; kare, ekranın en az %70'i (T-004) | 4 |
| `reveal_ad` | TextLabel | Çizenin adı | 4 |
| `reveal_sira` | TextLabel | "3 / 6" | 4 |
| `reveal_sure` | Frame | Süre çubuğunun dolgusu; kod yalnız `Size.X.Scale`'i yazar | 4 |

## Emoji (T-006)

| İşaret | Sınıf | Not | İş |
|---|---|---|---|
| `emoji_ekran` | ScreenGui | Reveal'da görünen emoji şeridi | 5 |
| `emoji_toplam` | TextLabel | Gösterilen çizimin canlı toplam tepkisi, herkese (K-006); nötr emoji ve sahibinin kendi oyu hariç | 5 |
| `emoji_laugh` `emoji_skull` `emoji_shocked` `emoji_normal` | GuiButton | `Config.Round.Emojis` sırasıyla, seçilebilir (seçili emoji belirgin); en az 44 pt | 5 |
| `emoji_sayi_laugh` `emoji_sayi_skull` `emoji_sayi_shocked` `emoji_sayi_normal` | TextLabel | Düğmenin yanında o emojinin canlı sayısı (sahibinin oyu hariç); düğmenin çocuğu olabilir | 5 |

## Podyum (T-007)

| İşaret | Sınıf | Not | İş |
|---|---|---|---|
| `podyum_ekran` | ScreenGui | Tur sonu podyumu | 5 |
| `podyum_yuva_1` `podyum_yuva_2` `podyum_yuva_3` | Frame | Sıra yuvası, `Config.Round.PodiumSize` kadar; kod yalnız görünürlüğü yazar (2 kişide 3. yuva gizli) | 5 |
| `podyum_tuval_1` `podyum_tuval_2` `podyum_tuval_3` | ImageLabel | Yuvadaki çizim; kare | 5 |
| `podyum_ad_1` `podyum_ad_2` `podyum_ad_3` | TextLabel | Çizenin adı | 5 |
| `podyum_tepki_1` `podyum_tepki_2` `podyum_tepki_3` | TextLabel | Toplam tepki sayısı (nötr emoji ve sahibinin kendi oyu hariç, K-003) | 5 |

## 3B dünya

| İşaret | Sınıf | Not | İş |
|---|---|---|---|
| `sahne_model_durak` | BasePart | Model klonunun durduğu yer; klon reveal ve podyum bitene kadar kalır (T-005) | 4 |
| `sahne_kamera_cizim` | BasePart | Çizim aşamasında kameranın yeri ve yönü (K-007) | 4 |
| `sahne_kamera_reveal` | BasePart | Reveal ve podyumda kameranın yeri ve yönü (K-007) | 4 |

`SpawnLocation` işaretsizdir: Roblox oyuncuyu gerçek bir `SpawnLocation` sınıfına kendisi doğurur, kod ışınlamaz.
Kamerayı kod yönetir, kilitli (K-007); Adam iki Part'ı haritada kamera yeri olarak işaretler. Kod kameranın
`CFrame`'ini bu Part'tan alır; Part görünmez ve çarpışmasız olabilir.

## İşaretleme komutu

`tools/isaretle.luau`, Studio'da (Edit) komut çubuğundan ya da MCP `execute_luau` ile çalışır. Nesneleri **adına
göre** bulur (`StarterGui` ve `Workspace` altında), sınıfını denetler, `Isaret` yazar; seçilebilir düğmelerin altında
`secili` adlı `UIStroke`'u arar. Komut başındaki `APPLY = false` iken yalnız rapor verir; yazmak için `true` yapılır.
Tekrar çalıştırılabilir: aynı sonucu verir, düzelen eksikler listeden düşer.

Rapor grup grup `tamam/toplam` yazar, ardından sorunları listeler:

- `eksik`: o adda nesne yok.
- `cift`: aynı adda birden çok nesne; hiçbirine işaret yazılmaz.
- `sinif`: nesne var ama sınıfı yanlış.
- `secili_eksik` / `secili_hatali`: düğmenin altında `secili` adlı tek bir `UIStroke` yok.
- `uyari: secili_acik`: `secili` kapalı olmalı; komut `Enabled`'a dokunmaz.
- `eski isaret`: `Isaret` taşıyan ama adı eşleşmeyen nesne (yeniden adlandırılmış ya da kopyalanmış). `APPLY = true`
  iken bu nesnelerin `Isaret`'i silinir; yoksa çalışma anında "cift" hatası verirdi.

Komut yalnız `Isaret` attribute'unu yazar ve siler; başka hiçbir özelliğe dokunmaz.
