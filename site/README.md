# SoC Sunum Sitesi

Bu klasör, RISC-V tabanlı SoC çalışması için hazırlanan statik sunum panelini içerir. GitHub Pages kök dizinden yayınlandığında ana `index.html`, bu paneli gömülü bir pencere olarak gösterir.

## Yapı

```text
site/
|-- sunum.html              # Asıl etkileşimli sunum paneli
|-- assets/
|   |-- styles.css          # Görsel tasarım
|   `-- app.js              # Etkileşim, grafikler ve KLayout görüntüleyici
|-- layers_full.json        # Üst metal 2.5D katman verisi
|-- detail_view.json        # Yakınlaştırma seviyesinde serim detayı
`-- librelane_outputs/      # Küçük LibreLane özet çıktıları
```

GDS, DEF ve post-layout netlist gibi büyük fiziksel tasarım çıktıları Git dışında bırakılır. Etkileşimli serim görünümü için JSON dışa aktarımları kullanılır.

## Yerelde Çalıştırma

KLayout görüntüleyici JSON dosyalarını yüklediği için siteyi yerel bir HTTP sunucusu üzerinden aç:

```bash
python3 -m http.server 8080
```

Ardından tarayıcıda aç:

```text
http://localhost:8080/
```

Asıl panel doğrudan şu adresten de açılabilir:

```text
http://localhost:8080/site/sunum.html
```

## Doğrulama

Repo kökünden:

```bash
node --check site/assets/app.js
```
