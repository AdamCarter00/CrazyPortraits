# AnalitikRaporlar — düzen

Bu klasör yalnız analitik çalışmasını tutar. Diğer raporlar `rapor\` altındaki kategori klasörlerinde (ArayuzRaporlari, HaritaRaporlari, KodRaporlari, GorselRaporlari).
Claude Code için kural CLAUDE.md'de. Testin sorusu, kilidi, yorumu ve kararı PORTFOY'daki test dosyasında (`testler/F-xxx-TESTn.md`); burada yalnız ham veri ve uygulama.

## Yapı

```
SOZLUK.md          her olay ve değer ne demek (tek yer; kod değişince güncellenir)
0-kurulum\         ölçümün kurulum raporları + Claude Code'un uzun anlam raporları
F-xxx-TESTn\          adı PORTFOY'daki test dosyasıyla aynı
  veri.md          sayılar, yorumsuz, ekran numarasıyla
  ekranlar\        ekran görüntüleri (numaralı)
  bagimsiz-analiz-<model>.md   dış modelin bağımsız analizi, olduğu gibi (karar değil)
  paket.md         ne değiştirmeyi düşünüyoruz (plan + Claude Code'un uygulama raporu)
```

## Kurallar

- paket.md'de her satır kimden geldiğini söyler, kasadaki gibi: "Adam, gg.aa:" · "Adam'ın kararı:" · "Claude'un çıkarımı:" / "Öneren: Claude" · "Koddan (Claude Code):" · "Veri:".
- Adam onaylamadıysa hiçbir öneri karar gibi yazılmaz.
- Kararlar kasada; burada yalnız kaydı durur.
- Yorum burada tutulmaz; PORTFOY'daki test dosyasındadır.
