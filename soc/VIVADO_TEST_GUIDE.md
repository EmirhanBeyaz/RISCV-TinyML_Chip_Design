# Vivado Test Yönergesi

Bu doküman, mevcut `AI` harici SoC mimarisini Vivado üzerinde nasıl test edeceğimizi adım adım anlatır.

Bu aşamada hedefimiz:
- tasarımın Vivado tarafından doğru okunması,
- top-level RTL elaboration'ın başarıyla tamamlanması,
- `cv32e40p_axi_soc` için out-of-context sentezin alınması,
- oluşan rapor ve artefact'ların doğru yorumlanmasıdır.

Bu doküman **kart üstü FPGA bring-up** dokümanı değildir.  
Bu aşama sadece `Vivado smoke / synthesis` doğrulamasıdır.

## 1. Önkoşullar

Makinede şunlar kurulu olmalı:
- `vivado`
- `iverilog`
- `vvp`
- `verilator`
- `perl`

Kontrol için:

```bash
which vivado
which iverilog
which verilator
```

`vivado` boş dönüyorsa, Vivado ortamı shell'e yüklenmemiştir.

## 2. Çalışma Dizini

Repo köküne geç:

```bash
cd /home/emirhan/Desktop/VHDL
```

## 3. Önce RTL Regresyonu Çalıştır

Vivado'dan önce, RTL tarafının temiz olduğundan emin ol:

```bash
make -C soc full
```

Bu komut:
- modül smoke testlerini,
- sistem smoke testlerini,
- gerçek `CV32E40P` smoke testini,
- ROM/boot image testlerini birlikte çalıştırır.

Beklenen sonuç:
- bütün testlerde `PASS`
- komut sonunda hata kodu olmadan bitiş

Not:
- `iverilog` ve `verilator` bazı warning'ler verebilir
- warning görmek normaldir
- esas kırmızı çizgi `ERROR`, derleme hatası veya testbench `PASS` alamamasıdır

## 4. Vivado RTL Smoke Test

İlk Vivado adımı `RTL elaboration` olmalı.

Komut:

```bash
vivado -mode batch -source soc/vivado_smoke.tcl -tclargs xc7a35tcpg236-1 rtl
```

Bu komut şunları yapar:
- `cv32e40p` manifest'inden RTL dosyalarını toplar
- `soc/` içindeki SoC dosyalarını ekler
- `cv32e40p_axi_soc` modülünü top olarak seçer
- Vivado içinde `synth_design -rtl` çalıştırır

Beklenen başarılı satırlar:
- `RTL elaboration completed.`
- `synth_design completed successfully`

Bu aşama neyi kanıtlar:
- dosyalar doğru bulunuyor mu
- include dizinleri doğru mu
- top-level hiyerarşi Vivado tarafından kurulabiliyor mu
- temel SystemVerilog uyumluluğu yerinde mi

Bu aşama neyi kanıtlamaz:
- timing closure
- gerçek FPGA kart davranışı
- `.xdc` / pin constraint doğruluğu

## 5. Vivado OOC Synthesis

İkinci adım `out-of-context synthesis` olmalı.

Komut:

```bash
vivado -mode batch -source soc/vivado_smoke.tcl -tclargs xc7a35tcpg236-1 ooc
```

Bu komut:
- yine aynı RTL dosyalarını kullanır
- `cv32e40p_axi_soc` için OOC sentez alır
- utilization ve timing raporları üretir
- bir `DCP` checkpoint bırakır

Beklenen başarılı satırlar:
- `Out-of-context synthesis completed.`
- `synth_design completed successfully`

Bu aşama neyi kanıtlar:
- tasarım sentez alabiliyor mu
- kaba kaynak kullanımı ne durumda
- daha ciddi sentez blokajı var mı

Bu aşama neyi kanıtlamaz:
- board-level timing
- gerçek IO pin davranışı
- gerçek clock tree/constraint kapanışı

## 6. Çıktılar Nerede Oluşur

Komutlardan sonra artefact'lar burada oluşur:

### RTL Smoke

```text
soc/build/vivado_smoke/rtl_xc7a35tcpg236-1/
```

Bu klasörde tipik olarak:
- `vivado_soc_smoke.xpr`
- Vivado cache klasörleri
- elaboration project dosyaları

### OOC Synthesis

```text
soc/build/vivado_smoke/ooc_xc7a35tcpg236-1/
```

Önemli dosyalar:
- `cv32e40p_axi_soc_ooc.dcp`
- `reports/utilization_ooc.rpt`
- `reports/timing_ooc.rpt`

## 7. Özellikle Bakılacak Çıktılar

Öncelik sırası şöyle olmalı:

### 1. Terminal çıktısı

Önce terminale bak:
- `synth_design completed successfully`
- `RTL elaboration completed.`
- `Out-of-context synthesis completed.`

Eğer terminalde `ERROR:` varsa önce onu çöz.

### 2. Utilization raporu

Dosya:

[utilization_ooc.rpt](/home/emirhan/Desktop/VHDL/soc/build/vivado_smoke/ooc_xc7a35tcpg236-1/reports/utilization_ooc.rpt:1)

Burada şunlara bak:
- LUT sayısı
- FF sayısı
- BRAM kullanımı
- DSP kullanımı

Bu tasarım için özellikle:
- `IMEM` ve `DMEM` tarafının BRAM'e düşmesi olumlu işarettir

### 3. Timing raporu

Dosya:

[timing_ooc.rpt](/home/emirhan/Desktop/VHDL/soc/build/vivado_smoke/ooc_xc7a35tcpg236-1/reports/timing_ooc.rpt:1)

Bu aşamada yorum:
- tamamen board-level kesin sonuç değildir
- ama çok bariz kombinasyonel riskleri erken gösterebilir

## 8. Normal Sayılan Warning'ler

Bu repo için şu sınıftaki warning'ler şu aşamada beklenebilir:
- `cv32e40p_pkg` içindeki package `parameter/localparam` warning'leri
- `third_party/peripherals` içindeki `always_comb` / `MULTIDRIVEN` warning'leri
- `unused/unconnected` port warning'leri
- `OOC` moduna özgü clock/XDC eksikliği kaynaklı uyarılar

Bunlar tek başına blocker değildir.

Blocker sayılabilecek durumlar:
- `ERROR:`
- `CRITICAL WARNING:` ve sentezi durduran durumlar
- `synth_design` tamamlanmaması
- raporların üretilmemesi

## 9. GUI Üzerinden Aynı Testi Yapmak

İstersen batch yerine GUI ile de aynı testi takip edebilirsin.

### En Temiz GUI Yolu

Bu repo için GUI tarafında en güvenli yöntem, **boş proje açıp kaynakları Tcl script ile içeri almaktır**.  
Sebep basit: `CV32E40P` manifest'i, include dizinleri ve hariç tutulması gereken birkaç dosya var. Bunları elle seçmek hata üretmeye çok açık.

Bu iş için hazır script:

- [soc/vivado_gui_add_sources.tcl](/home/emirhan/Desktop/VHDL/soc/vivado_gui_add_sources.tcl:1)

### Yöntem A: GUI'de boş proje aç, sonra kaynakları script ile ekle

1. Vivado ana ekranda `Create Project` de.
2. Proje adı ver.
3. `RTL Project` seç.
4. Kaynak ekleme ekranına geldiğinde dosya seçmek zorunda değilsin.  
   Burada boş geçebilirsin; önemli olan proje açılması.
5. FPGA part seçim ekranında cihazını seç.
6. Proje açıldıktan sonra:
   - `Tools -> Run Tcl Script...` de
   - [soc/vivado_gui_add_sources.tcl](/home/emirhan/Desktop/VHDL/soc/vivado_gui_add_sources.tcl:1) dosyasını seç

Alternatif olarak Tcl Console'da:

```tcl
source /home/emirhan/Desktop/VHDL/soc/vivado_gui_add_sources.tcl
```

Script şunları otomatik yapar:
- doğru `cv32e40p` RTL dosyalarını ekler
- simülasyon-only clock-gate dosyasını dışarıda bırakır
- bizim SoC dosyalarını ekler
- `third_party` kaynaklarını ekler
- include dizinlerini ayarlar
- top module'ü `cv32e40p_axi_soc` yapar

Sonra GUI içinde:
- `Open Elaborated Design`
- `Run Synthesis`

### Yöntem B: Batch ile proje oluştur, sonra GUI'de aç

Önce:

```bash
vivado -mode batch -source soc/vivado_smoke.tcl -tclargs xc7a35tcpg236-1 rtl
```

Sonra şu projeyi GUI ile aç:

```text
soc/build/vivado_smoke/rtl_xc7a35tcpg236-1/vivado_soc_smoke.xpr
```

GUI içinde:
- `Open Elaborated Design`
- `Run Synthesis`

### Yöntem C: Doğrudan batch ile çalış

Bu daha tekrarlanabilir ve ekip için daha güvenilir yöntemdir:

```bash
vivado -mode batch -source soc/vivado_smoke.tcl -tclargs xc7a35tcpg236-1 rtl
vivado -mode batch -source soc/vivado_smoke.tcl -tclargs xc7a35tcpg236-1 ooc
```

## 10. Bu Aşamada Ne Beklemeliyiz

Şu an doğru beklenti:
- Vivado RTL smoke geçsin
- Vivado OOC synthesis geçsin
- raporlar oluşsun

Şu an yanlış beklenti:
- gerçek FPGA kart doğrulaması
- pin-level QSPI davranışının birebir kanıtı
- final `.xdc` / board timing closure

## 11. Sorun Çıkarsa İlk Kontrol Listesi

Bir hata gördüğünde şu sırayla git:

1. `make -C soc full` tekrar geçiyor mu?
2. `vivado` komutu bulunuyor mu?
3. repo kökünde misin?
4. `soc/build/vivado_smoke/...` klasörü oluştu mu?
5. terminalde ilk `ERROR:` satırı ne?
6. sorun `rtl` modunda mı, `ooc` modunda mı?

## 12. Kısa Çalışma Akışı

En kısa doğru akış:

```bash
cd /home/emirhan/Desktop/VHDL
make -C soc full
vivado -mode batch -source soc/vivado_smoke.tcl -tclargs xc7a35tcpg236-1 rtl
vivado -mode batch -source soc/vivado_smoke.tcl -tclargs xc7a35tcpg236-1 ooc
```

Başarılı kabul kriteri:
- `make -C soc full` geçer
- `rtl` smoke geçer
- `ooc` smoke geçer
- `utilization_ooc.rpt` ve `timing_ooc.rpt` oluşur
