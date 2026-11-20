# BAGLAMA

Haritanın ve arayüzün motora bağlandığı işaretler. Kod yeni bir arayüz nesnesi isterse önce buraya satır olarak
girer; arayüzün kurulum listesi bu dosyadır (CLAUDE.md → Harita ve arayüz).

İşaret: nesnenin `Isaret` attribute'unun (string) değeri. Küçük harf, alt çizgi, Türkçe karakter yok.

Seçilebilir düğmelerin (Not sütununda "seçilebilir") altında işareti `secili` olan, kapalı bir `UIStroke` bulunur.
Kod yalnız onun `Enabled`'ını açıp kapatır; renk ve kalınlık Adam'ın.

## 2B panel

| İşaret | Sınıf | Not | İş |
|---|---|---|---|
| `cizim_ekran` | ScreenGui | Çizim ekranı (CanvasGui) | 3 |
| `cizim_tuval` | ImageLabel | Çizimin yapıldığı yüzey | 3 |
| `cizim_sure` | TextLabel | Kalan süre | 3 |
| `cizim_baslik` | TextLabel | "Draw …" satırı (tema yok, T-001) | 3 |
| `cizim_gonder` | GuiButton | Submit | 3 |
| `arac_silgi` | GuiButton | Silgi, seçilebilir | 3 |
| `arac_kova` | GuiButton | Kova doldurma, seçilebilir | 3 |
| `arac_geri` | GuiButton | Geri al | 3 |
| `firca_1` `firca_2` `firca_3` | GuiButton | Fırça boyları, `Config.Drawing.BrushSizes` sırasıyla, seçilebilir | 3 |
| `renk_siyah` `renk_beyaz` `renk_gri` `renk_ten` `renk_kirmizi` `renk_turuncu` `renk_sari` `renk_yesil` `renk_turkuaz` `renk_mavi` `renk_mor` `renk_pembe` `renk_kahve` `renk_koyu_yesil` `renk_lacivert` `renk_bordo` | GuiButton | Palet; renk değeri `Config.Drawing.Colors`'tan, seçilebilir | 3 |
| `gecis_ekran` | ScreenGui | Faz geçiş perdesi (PassGui) | 3 |
| `gecis_cerceve` | CanvasGroup | Perdenin solan çerçevesi | 3 |
| `gecis_etiket` | TextLabel | Perdedeki aşama adı | 3 |
| `ekran_yukleme` `ekran_emoji` `ekran_yan_menu` `ekran_asama` `ekran_sonuc` `ekran_market` `ekran_ogretici` | ScreenGui | Çizimde gizlenen diğer oyun ekranları (yalnız işaretli ScreenGui'ler gizlenir, TouchGui ellenmez) | 2 |

## 3B dünya

| İşaret | Sınıf | Not | İş |
|---|---|---|---|
