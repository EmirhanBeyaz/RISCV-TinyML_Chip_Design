# VHDL SoC Workspace

Bu repo, `CV32E40P` tabanli mikrodenetleyici SoC gelistirmesi icin kullanilan calisma alanidir. Su anki odak, `AI` harici mimariyi temiz, test edilebilir ve Vivado'da sentezlenebilir halde tutmaktir.

Bugun itibariyla repo su ana kadar su zinciri calistirabiliyor:

- `CV32E40P`
- `OBI -> AXI-Lite` veri yolu koprusu
- yerel `ROM / IMEM / DMEM`
- `UART0`, `UART1`, `GPIO`, `Timer`, `I2C`, `QSPI_CFG`
- yerel `QSPI_XIP`
- `ROM -> QSPI/XIP -> IMEM -> handoff` boot akisi
- `fpga_top` FPGA wrapper
- self-checking sim testleri
- Vivado `RTL elaboration`, `synthesis` ve `implementation` checkpoint

Bu repo su an kart ustunde final demo bitstream'i degil. `fpga_top` implementation seviyesine geldi; karta ozel `.xdc`, gercek pin-seviyesi flash bring-up ve `AI` entegrasyonu sonraki asamalardadir.

## Klasor Yapisi

```text
.
|-- cv32e40p/              # Upstream CV32E40P core
|-- demo/                  # Juri/sunum icin statik SoC demo paneli
|-- soc/                   # Tum SoC RTL, testbench ve proje dokumanlari
|   |-- third_party/       # Projede kullanilan ucuncu taraf RTL kaynaklari
|   |-- *.sv               # SoC bloklari ve testbenchler
|   |-- *.memh             # Simulasyon icin ROM/flash/IMEM goruntuleri
|   `-- Makefile           # Ana regresyon ve smoke test hedefleri
|-- .gitignore             # Build/log/Vivado artiklarini disarida tutar
`-- README.md              # Bu dosya
```

## Mimari Ozet

### Islemci ve Veri Yolu

- Islemci cekirdegi `CV32E40P`
- Cekirdegin veri tarafi dogal olarak `OBI` konusur
- SoC icinde veri tarafi `OBI -> AXI-Lite` koprusu ile tasinir
- Yerel adres cozumleme sirasi:
  - `IMEM alias`
  - `DMEM`
  - `MMIO`
  - `QSPI_XIP`
  - kalan erisimler `external AXI`

### Yerel Bellekler

- `ROM`: `0x0000_0000`, `4 KB`
- `IMEM`: `0x0001_0000`, `8 KB`
- `DMEM`: `0x0002_0000`, `8 KB`
- `AI_MEM`: `0x2000_0000`, `32 KB window / 30 KB hedef`
- `QSPI_XIP`: `0x3000_0000`, `16 MB`

Detaylar:
- [soc/MEMORY_MAP_V0.md](/home/emirhan/Desktop/VHDL/soc/MEMORY_MAP_V0.md:1)
- [soc/soc_map_pkg.sv](/home/emirhan/Desktop/VHDL/soc/soc_map_pkg.sv:1)

### Cevre Birimleri

Su anki aktif non-AI peripheral set:

- `UART0`: native `AXI-Lite`
- `UART1`: native `AXI-Lite`
- `GPIO`: `APB island` arkasinda
- `Timer`: `APB island` arkasinda
- `I2C master`: `APB island` arkasinda
- `QSPI_CFG`: `APB island` arkasinda
- `QSPI_XIP`: yerel read-only flash penceresi

### Boot Akisi

Mevcut boot akisi su mantikta calisir:

1. CPU `ROM`dan baslar
2. ROM kodu `QSPI_XIP` penceresinden header / image okur
3. Gerekli uygulama kodu `IMEM`e kopyalanir
4. Boot handoff ile `IMEM` uygulamasina dallanilir

Bu akisin testli hali:
- [soc/tb_cv32e40p_axi_soc_rom_boot.sv](/home/emirhan/Desktop/VHDL/soc/tb_cv32e40p_axi_soc_rom_boot.sv:1)
- [soc/tb_cv32e40p_axi_soc_rom_handoff.sv](/home/emirhan/Desktop/VHDL/soc/tb_cv32e40p_axi_soc_rom_handoff.sv:1)
- [soc/tb_cv32e40p_axi_soc_rom_image.sv](/home/emirhan/Desktop/VHDL/soc/tb_cv32e40p_axi_soc_rom_image.sv:1)

## En Onemli Dosyalar

### Ana SoC Top

- [soc/cv32e40p_axi_soc.sv](/home/emirhan/Desktop/VHDL/soc/cv32e40p_axi_soc.sv:1)

Buradan bakarak su ana mimariyi gorebilirsin:
- local memory decode
- MMIO decode
- QSPI XIP entegrasyonu
- boot/reset davranisi
- peripheral baglantilari

### Bellek Katmani

- [soc/soc_mem_sp.sv](/home/emirhan/Desktop/VHDL/soc/soc_mem_sp.sv:1)
- [soc/soc_rom.sv](/home/emirhan/Desktop/VHDL/soc/soc_rom.sv:1)
- [soc/soc_imem.sv](/home/emirhan/Desktop/VHDL/soc/soc_imem.sv:1)
- [soc/soc_axi_lite_imem.sv](/home/emirhan/Desktop/VHDL/soc/soc_axi_lite_imem.sv:1)
- [soc/soc_dmem.sv](/home/emirhan/Desktop/VHDL/soc/soc_dmem.sv:1)

### Boot ve Flash

- [soc/soc_boot_copy_xip.sv](/home/emirhan/Desktop/VHDL/soc/soc_boot_copy_xip.sv:1)
- [soc/soc_qspi_xip.sv](/home/emirhan/Desktop/VHDL/soc/soc_qspi_xip.sv:1)
- [soc/soc_axi_lite_qspi_xip.sv](/home/emirhan/Desktop/VHDL/soc/soc_axi_lite_qspi_xip.sv:1)
- [soc/soc_qspi_init_seq.sv](/home/emirhan/Desktop/VHDL/soc/soc_qspi_init_seq.sv:1)
- [soc/soc_qspi_cfg_mux.sv](/home/emirhan/Desktop/VHDL/soc/soc_qspi_cfg_mux.sv:1)
- [soc/soc_apb_qspi_cfg.sv](/home/emirhan/Desktop/VHDL/soc/soc_apb_qspi_cfg.sv:1)

### Peripheral Katmani

- [soc/soc_axi_lite_uart.sv](/home/emirhan/Desktop/VHDL/soc/soc_axi_lite_uart.sv:1)
- [soc/soc_axi_lite_apb_island.sv](/home/emirhan/Desktop/VHDL/soc/soc_axi_lite_apb_island.sv:1)
- [soc/soc_apb_gpio.sv](/home/emirhan/Desktop/VHDL/soc/soc_apb_gpio.sv:1)
- [soc/soc_apb_timer.sv](/home/emirhan/Desktop/VHDL/soc/soc_apb_timer.sv:1)
- [soc/soc_apb_i2c_master.sv](/home/emirhan/Desktop/VHDL/soc/soc_apb_i2c_master.sv:1)
- [soc/soc_irq_router.sv](/home/emirhan/Desktop/VHDL/soc/soc_irq_router.sv:1)

### Ana Dokumanlar

- [TEAM_GUIDE.md](/home/emirhan/Desktop/VHDL/TEAM_GUIDE.md:1)
- [soc/ARCHITECTURE_DECISIONS_V0.md](/home/emirhan/Desktop/VHDL/soc/ARCHITECTURE_DECISIONS_V0.md:1)
- [soc/MEMORY_MAP_V0.md](/home/emirhan/Desktop/VHDL/soc/MEMORY_MAP_V0.md:1)
- [soc/QSPI_CFG_REGMAP.md](/home/emirhan/Desktop/VHDL/soc/QSPI_CFG_REGMAP.md:1)
- [soc/VIVADO_TEST_GUIDE.md](/home/emirhan/Desktop/VHDL/soc/VIVADO_TEST_GUIDE.md:1)
- [soc/VIVADO_IMPLEMENTATION_CHECKPOINT.md](/home/emirhan/Desktop/VHDL/soc/VIVADO_IMPLEMENTATION_CHECKPOINT.md:1)
- [soc/TEKNOFEST_REVIEW_CHECKLIST.md](/home/emirhan/Desktop/VHDL/soc/TEKNOFEST_REVIEW_CHECKLIST.md:1)

## Hangi Vendor IP'ler Kullaniyor

Aktif ucuncu taraf kaynaklari:

- `CV32E40P` core
- UART alt bloklari
- GPIO/Timer peripheral alt bloklari
- QSPI XIP alt bloklari

Atif ve kaynak bilgileri:
- [soc/third_party/ATTRIBUTION.md](/home/emirhan/Desktop/VHDL/soc/third_party/ATTRIBUTION.md:1)

## Hemen Baslamak Icin

### Sunum / Demo Paneli

Kart elde yokken mimariyi ve Vivado kanitlarini gorsel olarak anlatmak icin:

```bash
xdg-open demo/index.html
```

Panel dosyalari:
- [demo/index.html](/home/emirhan/Desktop/VHDL/demo/index.html:1)
- [demo/README.md](/home/emirhan/Desktop/VHDL/demo/README.md:1)

### Gereken Araclar

- `iverilog`
- `vvp`
- `verilator`
- `perl`
- Vivado smoke test icin `vivado`

### Ana Regresyon

Proje kokunden:

```bash
make -C soc full
```

Bu komut:
- modul seviyesinde smoke testleri
- sistem seviyesinde smoke testleri
- gercek `CV32E40P` smoke testini
- ROM/boot image testlerini
birlikte kosar.

### Tek Tek Faydali Testler

```bash
make -C soc full
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

Build artiklari:
- `soc/build/`

Temizlemek icin:

```bash
make -C soc clean
```

## Vivado Smoke Test

Proje kokunden:

```bash
vivado -mode batch -source soc/vivado_smoke.tcl -tclargs xc7a35tcpg236-1 rtl
vivado -mode batch -source soc/vivado_smoke.tcl -tclargs xc7a35tcpg236-1 ooc
```

Bu iki komutun anlami:
- `rtl`: Vivado dosyalari okuyup top-level elaboration yapiyor mu
- `ooc`: board-level tasarima girmeden `cv32e40p_axi_soc` sentez aliyor mu

Beklenen artefactlar:
- `soc/build/vivado_smoke/rtl_<part>/`
- `soc/build/vivado_smoke/ooc_<part>/`

Not:
- Bu asama board bring-up degildir
- `.xdc`, clock constraint, top-level FPGA pin wrapper ve gercek board entegrasyonu sonraki fazdir

## Su An Ne Tamamlandi

AI harici tarafta su alanlar guvenle ilerlemis durumda:

- SoC top-level entegrasyonu
- local bellek yapisi
- MMIO organizasyonu
- UART0/UART1
- GPIO
- Timer
- I2C
- QSPI config/status
- QSPI XIP
- boot kopyalama ve handoff
- `fpga_top`
- Vivado smoke, sentez ve implementation checkpoint

## Su An Ne Eksik

AI harici mimaride hala sonraki fazda olan basliklar:

- karta ozel `.xdc`
- pin-seviyesi gercek QSPI flash bring-up
- daha urunlesmis boot guvenlikleri:
  - magic
  - size/bounds check
  - checksum / CRC
  - hata kodlari
- daha gercek firmware demolari:
  - `UART print`
  - coklu peripheral bring-up

AI tarafinda ise ayri olarak kalanlar:

- `AI_CSR`
- `AI_MEM`
- `AI IRQ`
- accelerator entegrasyonu

## Repo Icinde Calisirken Pratik Kurallar

- Ana referans top dosya: [soc/cv32e40p_axi_soc.sv](/home/emirhan/Desktop/VHDL/soc/cv32e40p_axi_soc.sv:1)
- Adres/slot degisikligi gerekiyorsa once [soc/soc_map_pkg.sv](/home/emirhan/Desktop/VHDL/soc/soc_map_pkg.sv:1) degistir
- Yeni peripheral eklerken:
  - once local testbench
  - sonra top-level smoke test
  - sonra `make -C soc full`
- Generated dosyalar repo kokeninde tutulmaz; `build/` ve Vivado loglari yeniden uretilir

## Kisa Sonuc

Bu repo su anda AI harici mikrodenetleyici SoC iskeletini anlamak, simule etmek ve Vivado'da smoke seviyesinde sentezlemek icin yeterince duzenli durumdadir. Yeni gelen bir ekip arkadasi icin en iyi baslangic sirasi:

1. [soc/ARCHITECTURE_DECISIONS_V0.md](/home/emirhan/Desktop/VHDL/soc/ARCHITECTURE_DECISIONS_V0.md:1)
2. [soc/MEMORY_MAP_V0.md](/home/emirhan/Desktop/VHDL/soc/MEMORY_MAP_V0.md:1)
3. [soc/cv32e40p_axi_soc.sv](/home/emirhan/Desktop/VHDL/soc/cv32e40p_axi_soc.sv:1)
4. `make -C soc full`
5. sonra ilgili periferalin `tb_*` dosyasina bakmak
