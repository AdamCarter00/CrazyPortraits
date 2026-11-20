# Yeni oyun nasıl açılır

Bu klasör bir şablon; içinde çalışılmaz. Bir fikir PORTFOY'da Kapı 0'ı geçip yapıma girince (kart `aktif`):

1. **Ad seç:** `F-xxx-ad` (kart numarası + kısa ad, Türkçe karaktersiz, boşluksuz). Örnek: `F-004-dukkan`.
2. **Kopyala:**
   - `Desktop\Oyunlar\_SABLON-OYUN` → `Desktop\Oyunlar\F-004-dukkan`
   - `Desktop\Obsidian\_SABLON-OYUN` → `Desktop\Obsidian\F-004-dukkan`
   İki klasörün adı **aynı** olmak zorunda: kasa aracı kasayı bu addan bulur.
3. **Yer tutucuları doldur:** `{OYUN}` ve `F-xxx` (depoda `Proje\CLAUDE.md`, `Proje\default.project.json`,
   `Proje\src\shared\Config\Terms.luau`; kasada `BASLA.md`). CLAUDE.md'de `{Bir cümle: oyun ne.}` ve `{github adresi}`.
   Kasa BASLA'sının başındaki kutuyu sil.
4. **Yedek:** `Desktop\Oyunlar\F-004-dukkan` klasöründe `git init`, GitHub'da private depo aç, origin ekle, ilk commit + push.
5. **Bağla:** PORTFOY'daki karta `kasa:` ve `depo:` yollarını yaz. Obsidian'da yeni kasayı aç.
6. **Dene:** `Proje` klasöründe Claude Code'u aç. Oturum açılışında `degisen` çalışmalı ("değişen not yok" gibi).
   Sonra: `lune run tests/run.luau` (1 test geçmeli) ve `lune run tools/kasa.luau kontrol`.

Bırakılan oyun: klasörler silinmez; kasa `DURUM.md`'ye kapanış satırı yazılır, depo arşivlenir.
