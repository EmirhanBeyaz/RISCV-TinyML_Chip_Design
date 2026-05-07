# CD-Rom SoC Ekip Çalışma Yönergesi

Bu doküman, repoyu GitHub'a yükledikten sonra takım arkadaşlarının aynı noktadan devam edebilmesi için yazıldı. Amaç, yeni gelen birinin önce mimariyi anlaması, sonra doğru testleri çalıştırması, en son da güvenli şekilde geliştirme yapmasıdır.

## 1. Projenin Şu Anki Durumu

Bu repo şu anda mikrodenetleyici SoC baseline'ını ve AI adasi icin testli CSR/MEM/UART/IRQ altyapisini icerir.

Tamamlanmış ana parçalar:

- `CV32E40P` işlemci çekirdeği
- `OBI -> AXI-Lite` veri yolu köprüsü
- `ROM / IMEM / DMEM` yerel bellek katmanı
- `UART0`, `UART1`, `GPIO`, `Timer`, `I2C`, `QSPI_CFG`
- `QSPI_XIP` read-only flash penceresi
- `ROM -> QSPI/XIP -> IMEM -> handoff` boot akışı
- `fpga_top` FPGA wrapper
- modül ve sistem seviyesinde self-checking testbenchler
- Vivado `RTL elaboration`, `synthesis`, `implementation` checkpoint
- jüri/sunum için statik demo paneli

Henüz tamamlanmamış ana parçalar:

- gerçek TFLite Micro Speech ağırlıkları, golden vektörleri ve accuracy/performance sign-off
- karta özel `.xdc`
- gerçek QSPI flash pin bring-up
- kart üstünde UART/GPIO/flash fiziksel demo
- daha ürünleşmiş boot güvenlikleri: `magic`, `size/bounds`, `CRC/checksum`, hata kodları

Önemli ayrım:

- `cv32e40p_axi_soc.sv`: SoC'nin ana mimari top dosyasıdır.
- `fpga_top.sv`: Vivado implementation için kullanılan FPGA dostu wrapper'dır.

## 2. İlk Bakılacak Dosyalar

Yeni başlayan biri bu sırayı takip etmeli:

1. [README.md](./README.md)
2. [soc/ARCHITECTURE_DECISIONS_V0.md](./soc/ARCHITECTURE_DECISIONS_V0.md)
3. [soc/MEMORY_MAP_V0.md](./soc/MEMORY_MAP_V0.md)
4. [soc/VIVADO_IMPLEMENTATION_CHECKPOINT.md](./soc/VIVADO_IMPLEMENTATION_CHECKPOINT.md)
5. [soc/cv32e40p_axi_soc.sv](./soc/cv32e40p_axi_soc.sv)
6. [soc/fpga_top.sv](./soc/fpga_top.sv)
7. [soc/Makefile](./soc/Makefile)

Sunum için:

- [index.html](./index.html)
- [site/sunum.html](./site/sunum.html)
- [site/README.md](./site/README.md)

## 3. Klasör Mantığı

```text
.
|-- cv32e40p/              # CV32E40P işlemci çekirdeği
|-- index.html             # GitHub Pages giriş sayfası
|-- site/
|   |-- assets/            # Sunum demosu için CSS ve JavaScript
|   |-- *.json             # KLayout 2.5D katman verileri
|   `-- *.html             # Statik sunum giriş dosyası
|-- soc/                   # SoC RTL, testbench, bellek image'ları ve dokümanlar
|   |-- third_party/       # Kullanılan açık kaynak RTL referansları ve atıflar
|   |-- *.sv               # Tasarım ve testbench dosyaları
|   |-- *.memh             # Test/boot bellek görüntüleri
|   |-- Makefile           # Ana test hedefleri
|   `-- vivado_*.tcl       # Vivado kaynak ekleme / smoke scriptleri
|-- TEAM_GUIDE.md          # Bu doküman
|-- README.md              # Genel proje özeti
`-- .gitignore             # Build/log/Vivado çıktılarını dışarıda tutar
```

Generated dosyalar repoya eklenmemeli:

- `soc/build/`
- `.Xil/`
- `vivado.log`
- `vivado.jou`
- `vivado_*.backup.*`
- Vivado proje cache klasörleri

## 4. Gerekli Araçlar

Linux tarafı için beklenen araçlar:

```bash
which make
which iverilog
which vvp
which verilator
which perl
which vivado
```

`vivado` bulunmuyorsa Vivado ortamı shell'e eklenmemiştir. Vivado GUI içinden çalışılacaksa bu sorun olmayabilir, ancak batch komutları için `vivado` komutu PATH içinde olmalı.

## 5. İlk Kurulum ve İlk Test

GitHub'a yüklendikten sonra takım arkadaşı şu şekilde başlamalı:

```bash
git clone <repo-url>
cd <repo-klasoru>
```

İlk kontrol:

```bash
make -C soc full
```

Beklenen sonuç:

- testler hata kodu olmadan bitmeli
- ilgili testbenchler `PASS` yazmalı
- warning olabilir, fakat `ERROR`, `$fatal` veya derleme kırılması olmamalı

Tek tek faydalı hedefler:

```bash
make -C soc real-core-smoke
make -C soc rom-image-smoke
make -C soc soc-uart0-smoke
make -C soc soc-uart1-smoke
make -C soc soc-gpio-smoke
make -C soc soc-timer-smoke
make -C soc soc-i2c-smoke
make -C soc qspi-cfg-smoke
make -C soc qspi-xip-smoke
```

Temizlik:

```bash
make -C soc clean
```

## 6. Vivado ile Kontrol

### GUI ile önerilen yol

1. Vivado'da yeni boş RTL proje aç.
2. Part olarak kullanılan FPGA'yı seç.
3. Proje açıldıktan sonra Tcl Console'da şu komutu çalıştır:

```tcl
source /path/to/repo/soc/vivado_gui_add_sources.tcl
```

Bu script:

- doğru RTL dosyalarını ekler
- include dizinlerini ayarlar
- gereksiz simülasyon dosyalarını dışarıda bırakır
- top module olarak `fpga_top` seçer

Sonra şu sırayı takip et:

1. `Open Elaborated Design`
2. `Run Synthesis`
3. `Run Implementation`
4. Raporlardan LUT/FF/BRAM/DSP/IOB kullanımını kontrol et

Son başarılı checkpoint:

- top: `fpga_top`
- device: `xc7a100tcsg324-3`
- LUT: `6882`
- FF: `4077`
- BRAM tile: `6`
- DSP: `5`
- IOB: `30`
- black box: `0`

### Batch smoke

Vivado batch smoke için:

```bash
vivado -mode batch -source soc/vivado_smoke.tcl -tclargs xc7a35tcpg236-1 rtl
vivado -mode batch -source soc/vivado_smoke.tcl -tclargs xc7a35tcpg236-1 ooc
```

Not:

- Batch smoke `cv32e40p_axi_soc` seviyesini kontrol eder.
- GUI implementation akışı için `fpga_top` kullanılmalıdır.
- Board-level final sign-off için `.xdc` şarttır.

## 7. Demo Paneli

Kart elde yokken jüriye tasarımı anlatmak için:

```bash
python3 -m http.server 8080
```

Ardından tarayıcıda `http://localhost:8080/` adresini aç.

Panelin anlattığı şeyler:

- SoC blokları
- `OBI -> AXI-Lite` dönüşümü
- boot akışı
- Vivado başarı kanıtları
- bellek/MMIO haritası
- AI altyapısının entegre edildiği, gerçek model sign-off'unun kaldığı

Bu panel teknik doğrulamanın yerine geçmez. Teknik kanıtlar testbenchler, Vivado raporları ve checkpoint dokümanlarıdır.

## 8. Geliştirme Kuralları

### Genel kural

Her değişiklik küçük ve test edilebilir olmalı. Bir PR veya commit şu üç soruya cevap vermeli:

- Ne değişti?
- Neden değişti?
- Nasıl doğrulandı?

### Yeni peripheral eklenirse

Sıra:

1. Yerel wrapper yaz
2. Modül testbench'i ekle
3. `soc_map_pkg.sv` adres slotunu güncelle
4. `MEMORY_MAP_V0.md` dokümanını güncelle
5. `cv32e40p_axi_soc.sv` decode bağlantısını ekle
6. Sistem smoke testi ekle
7. `make -C soc full` çalıştır
8. Vivado elaboration/synthesis kontrol et

### Bellek haritası değişirse

Önce:

- [soc/soc_map_pkg.sv](./soc/soc_map_pkg.sv)

Sonra:

- [soc/MEMORY_MAP_V0.md](./soc/MEMORY_MAP_V0.md)
- ilgili decoder
- ilgili testbench
- gerekirse firmware/linker beklentileri

### AI tarafında çalışılırsa

AI işi mevcut baseline'ı kırmadan yapılmalı.

Mevcut entegre altyapı:

- `AI_CSR`: `0x1000_6000`
- `AI_MEM`: `0x2000_0000`, 32 KB window / 30 KB implemented
- `AI_UART loader`: UART1 RX hattindan AI_MEM'e byte stream
- `AI_IRQ`: fast IRQ bit 19
- `soc_ai_tinyconv_accel`: sentetik agirlikli TinyConv-sekilli RTL iskeleti
- `tools/ai/export_tinyconv_assets.py`: model asset/golden uretim araci

Sonraki önerilen sıra:

1. Resmi TFLite Micro Speech quantized `.tflite` modelini `tools/ai/export_tinyconv_assets.py` ile asset/golden dosyalarina cevir
2. `soc_ai_tinyconv_accel` içindeki sentetik ağırlık fonksiyonlarını gerçek ağırlık/bias/scale ROM'larıyla değiştir
3. CPU firmware akışını ekle: UART1 input, AI start, IRQ ISR, UART0 result
4. Yazılım referansı ile cycle/accuracy karşılaştırması üret
5. AXI/AXI-Lite protocol check ve Vivado/OpenLane sign-off tarafını genişlet

AI entegrasyonu sırasında özellikle korunacak şeyler:

- ROM boot testleri
- QSPI XIP testleri
- UART/GPIO/Timer/I2C testleri
- `fpga_top` Vivado elaboration/synthesis akışı

## 9. GitHub Çalışma Düzeni

Önerilen branch modeli:

- `main`: çalışan baseline
- `feature/ai-csr`: AI CSR işi
- `feature/ai-mem`: AI bellek işi
- `feature/board-xdc`: board constraint işi
- `fix/<kisa-konu>`: küçük hata düzeltmeleri
- `docs/<kisa-konu>`: dokümantasyon güncellemeleri

Commit mesajı formatı:

```text
<alan>: <kisa aciklama>
```

Örnekler:

```text
soc: add ai csr address decode
test: add qspi xip smoke coverage
docs: update vivado implementation guide
demo: clarify boot flow panel
```

Push öncesi minimum kontrol:

```bash
make -C soc full
```

Vivado dosyası değiştiyse ek kontrol:

```bash
vivado -mode batch -source soc/vivado_smoke.tcl -tclargs xc7a35tcpg236-1 rtl
```

`fpga_top`, kaynak listesi veya constraint akışı değiştiyse GUI veya batch implementation yeniden kontrol edilmeli.

## 10. Bu Klasörü GitHub'a İlk Kez Yükleme

Şu an çalışma klasörü git repo değilse, repo kökünde:

```bash
git init
git add .
git commit -m "repo: add cd-rom soc baseline"
git branch -M main
git remote add origin <github-repo-url>
git push -u origin main
```

Eğer GitHub'da repo önceden oluşturulduysa `<github-repo-url>` şu formatlardan biri olabilir:

```text
https://github.com/<org-veya-kullanici>/<repo>.git
git@github.com:<org-veya-kullanici>/<repo>.git
```

Push öncesi kontrol:

```bash
git status --short
git remote -v
```

`soc/build/`, `vivado.log`, `vivado.jou`, `.Xil/` gibi dosyalar staged görünmemeli. Görünüyorsa `.gitignore` kontrol edilmeli.

## 11. PR Açarken Yazılacak Açıklama

PR veya merge request açıklamasında şu format kullanılmalı:

```text
## Özet
- 

## Değişen Alanlar
- 

## Doğrulama
- [ ] make -C soc full
- [ ] Vivado RTL elaboration
- [ ] Vivado synthesis
- [ ] Vivado implementation gerekiyorsa

## Riskler / Notlar
- 
```

Eksik test varsa saklanmamalı; açıkça yazılmalı.

## 12. Sık Yapılan Hatalar

- `cv32e40p_axi_soc` yerine yanlış top seçmek
- Vivado GUI'de dosyaları elle ekleyip include path unutmak
- `fpga_top` yerine iç SoC top'unu board top gibi sentezlemeye çalışmak
- `soc/build/` klasörünü commit'e eklemek
- bellek haritasını kodda değiştirip `MEMORY_MAP_V0.md` dokümanını güncellememek
- peripheral ekleyip testbench eklememek
- AI değişikliklerinde mevcut boot/QSPI/UART testlerini kırmak

## 13. Kısa Devralma Özeti

Bu repo takım için şu an iyi bir başlangıç baseline'ıdır:

- non-AI SoC mimarisi çalışır ve testlidir
- Vivado implementation seviyesine taşınmıştır
- kart olmadığı için fiziksel demo yoktur
- AI CSR/MEM/UART/IRQ altyapısı entegre edilmiştir
- gerçek model ağırlıkları ve accuracy sign-off hâlâ ayrı iştir
- ekip çalışması için önce küçük branchler, sonra testli PR akışı izlenmelidir
