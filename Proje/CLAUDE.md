# Crazy Portraits 2 — çalışma kuralları

Bir oyuncu model olur, herkes (model dahil) onun avatarını çizer, çizimler emojiyle oylanır; F-001 Crazy Portraits'in yeniden yapımı, aynı place (placeId 72378550860176). Luau · Rojo · Lune. Studio'ya Rojo ve Studio MCP ile bağlısın. Bu depo senin çalışma alanın.
Portföy kartı: `F-015` (PORTFOY kasası). Oyun kasası: `C:\Users\Dev\Desktop\Obsidian\<bu klasörün adı>`.

## Kararlar nerede

- Tasarım kararları oyun kasasında (Obsidian), `notlar/` altındaki T ve K notlarında. Tek kaynak orası.
- Kasayı yalnız kasa aracıyla oku: `lune run tools/kasa.luau <komut>`. Araç notun yalnız `Karar →` ve `Kısıt →`
  bölümlerini gösterir. Kasa dosyalarını kendin açma, düzenleme; bir kanca bunu zaten engeller. PORTFOY kasası da
  aynı kancayla kapalı; ona hiç dokunma.
- Kasada yazan bir şeyi depoda tekrar yazma: doküman, özet, çeviri, kararı anlatan yorum yok.
- Sayılar ve oyuncuya görünen metinler `src/shared/Config`'te. Koda sayı ya da metin gömme.

## Kasa aracı

| Komut | Ne yapar |
|---|---|
| `liste [sistem]` | notları sisteme göre başlıklarıyla listeler |
| `sistem <ad>` | bir sistemin bütün kararlarını gösterir |
| `oku <no> …` | seçilen notların Karar ve Kısıt'ını gösterir |
| `bagli <no> …` | o nota bir ve iki adımda dayanan notları listeler |
| `degisen [--hepsi]` | kararı değişen, hiç uygulanmamış notları ve K'lerin durumunu gösterir |
| `isaretle <no> … \| --hepsi` | uyguladığın notları işaretler |
| `k-ac` | sıradaki numarayla, doğru biçimde yeni K açar |
| `kontrol` | kasanın biçimini denetler |
| `kapsam [no …] [--sistem <ad>]` | adı not numarasıyla başlayan testi olmayan karar/olcum notlarını listeler |

Kasa yolu deponun klasör adından türetilir: `Oyunlar\<ad>\Proje` → `Obsidian\<ad>`. Farklıysa `KASA_YOLU` ortam
değişkeniyle verilir. İşaretler `Proje\.kasa-iz.json`'da; commit'e kat.

Notu okurken:
- `karar` bağlayıcıdır. `olcum`: karar geçerli, sayısı ayardır; değeri Config'e koy. `dustu`: bu özellik olmayacak;
  kodda varsa kaldır. `acik` ve `fikir` karar değildir, uygulama.
- `gerilim` doluysa çakışma çözülmemiştir; kendin çözme, K aç.
- `dayanir`: bir not değişince etkilenen notları bu bağlardan bul.

## Oturum düzeni

1. Oturum açılınca `degisen` kendiliğinden çalışır. Kararı değişenleri uygula ya da işe al.
2. Bir işe başlamadan o sistemin kararlarını oku. İstemciye veri gönderen her parça planlanırken gizli bilginin
   kime gittiği kontrol edilir; Player'ın altındaki her şey her istemciye gider, oraya gizli bilgi konmaz.
3. Kodu yaz, `lune run tests/run.luau` ile testleri koş, gerekirse Studio'da dene.
4. İş bitince testler yeşil olsun; commit at, uyguladığın notları `isaretle` ile işaretle, push et.
5. `rapor\SON-ISLER.md`'ye satır ekle ve son mesajında kasaya işlenecekleri yaz (→ Son işler).

## Boşluk bulursan: K

Kasada cevabı olmayan, eksik ya da çelişkili bir şey bulursan K aç:

    lune run tools/kasa.luau k-ac --soru "...?" --sistem a,b [--dayanir T-001] [--baglam "..."] [--varsayim "..."]

Başlık tek soru olsun, Türkçe yaz. `--sistem` yalnız kasanın `sistem/` klasöründe sayfası olan etiketleri kabul eder;
yeni bir etiket gerekiyorsa K'de söyle. `Karar`, `Kısıt` ve `Neden` bölümlerine yazma; onları Adam doldurur.

- **Bekle:** oyun kuralını, kazanma koşulunu, gizli bilginin kime gittiğini, kalıcı veriyi, place yapısını ya da
  birden çok sistemi etkiliyorsa. O parçayı yapma, başka işe geç; başka iş yoksa dur ve söyle.
- **Varsayımla devam et:** tek bir yerde değişen, geri alması kolay şeylerde. Varsayımla yaptığın işi ayrı bir
  commit'e koy.

Adam "K'leri cevapladım, devam et" deyince `degisen` cevapları gösterir. Cevap varsayımından farklıysa o commit'i
geri al ve cevaba göre yap.

## Kod ile kasa farklıysa

Not değiştiyse ve kod henüz ona uyarlanmadıysa fark iştir: notu uygula. Kod nota göre yazılmış olduğu hâlde fark
varsa ya da hangisinin geçerli olduğu belli değilse dur ve sor.

## Teknik borç

Önce oyun çıkar. Hemen kapatılır, borca girmez: (1) normal oynayan oyuncunun karşılaştığı her bozukluk;
(2) gizli bilginin bilmemesi gereken istemciye gitmesi; (3) bir oyuncunun başkalarının oyununu bozabilmesi.
Bunların dışındaki güvenlik, verimlilik ve temizlik işleri bilerek bırakılabilir; bırakılan her şey nedeni ve
ele alınma koşuluyla `BORC.md`'ye yazılır.

## Mimari (testler zorlar)

- `src/shared` içindeki oyun mantığı saf Luau: `game`, `task`, `os`, `math.random` yok.
- Zaman dışarıdan girer; rastgelelik tohumludur.
- İstemciye giden her bilgi tek bir yerden, beyaz listeyle geçer.
- `Config` saf veridir.

## Harita ve arayüz

Harita (Workspace, 3B dünya) ve ses Adam'ın. Arayüzü (StarterGui) sen kurarsın: yerleşim, boyut ve yer tutucu
biçim. Son biçim (renk, yazı tipi, ikon, saydamlık) Adam'ın; var olan bir nesnenin bu değerlerini değiştirmeden önce sor.

- Haritada parça ya da model kurma, taşıma; Adam açıkça izin verdiği tek bir iş için hariç.
- Biçim değerleri koda ve Config'e girmez; kod onları nesnelerden okur. Kod yalnız içerik, görünürlük ve davranış yazar.
- Kod çalışırken eksik nesne yaratmaz. Beklenen bütün işaretler aranır; eksik, çift ya da yanlış sınıf varsa oyun
  hata verir ve eksikleri Output'a listeler.
- İşaretle bul, isimle değil: kodun sürdüğü her nesnede bir işaret attribute'u var. Yolu ya da adı koda yazma.
- Çoğaltılan nesne şablondur; kod klonlar.
- Haritadaki bir nesneye işaret yazmadan önce listeyi göster, Adam'ın onayını al.

İşaret listesi `BAGLAMA.md`'de; her satır dayandığı notu taşır.

## Rojo ve Studio

- Proje dosyası `default.project.json` (`rojo serve`). İkinci bir place gerekirse ayrı proje dosyası ve port.
- Kodu yalnız dosyada yaz; Rojo Studio'ya taşır. Studio'da script değiştirme.
- Studio MCP'yi yapıyı okumak, oyunu çalıştırıp denemek, çıktıyı okumak ve arayüzü kurmak için kullan.

## Yorum satırı

Varsayılan: yorum yok. Yorum yalnız koddan görünmeyen ve bilinmezse kodu değiştireni hataya düşürecek şeyi yazar
(Roblox API tuhaflığı, bilerek yapılmış performans hilesi, gizli sıra bağımlılığı); en fazla iki satır. Oyun kuralı,
kararın gerekçesi, not numarası yoruma yazılmaz. Kararın izi: test adı not numarasıyla başlar
(`T-007: …`), commit mesajı numarayı taşır.

## Yedek

Git kökü bu deponun üstündeki oyun klasörüdür (`Oyunlar\<ad>\`): `Proje`, `rapor` ve `Icerikler` birlikte yedeklenir.
Her iş sonunda commit'ten sonra push. Origin: {github adresi}.

## Rapor klasörü

Raporlar `rapor\` kökünde değil, konusuna göre bir kategori klasöründe: `ArayuzRaporlari` · `HaritaRaporlari` ·
`KodRaporlari` · `GorselRaporlari` · `AnalitikRaporlar`. Raporun ekran görüntüleri raporla aynı adlı bir klasörde.
Konusu ikisine uyuyorsa ağır basanı seç; emin değilsen sor.

## Son işler

Her işin sonunda (kod değişikliği, inceleme, rapor; commit olsun olmasın) `rapor\SON-ISLER.md`'nin en üstüne tek satır:

    - YYYY-AA-GG · iş · kasa: notlar · commit: kısa hash · rapor: yol · kasaya işlenecek: …

**Kasaya işlenecek:** kasada değişmesi gereken her şey; örnek: `K-012 varsayımıyla uygulandı · T-030 uygulandı ·
bekleyen kalktı: T-018 (arayuz)`. Yoksa `—`. Aynı satırı son mesajında da yaz. Oyun kasasını düzenleyen AI bu
dosyayı okuyup kasaya işler; bu satır yazılmadan iş bitmiş sayılmaz.

## Analitik raporları

Analitik `rapor\AnalitikRaporlar\` altında, test klasöründe. **Test klasörünün adı PORTFOY'daki test dosyasıyla aynı:**
`F-015-TESTn`. Düzen aynı yerdeki `README.md`'de. Yorum ve karar burada değil, PORTFOY'daki test dosyasında.

- Koddaki olayların anlamını çıkardığında: `AnalitikRaporlar\SOZLUK.md`.
- Bir analitik paketini uyguladığında: o testin `paket.md` dosyasının sonundaki "Uygulama raporu" bölümü.
