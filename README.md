# VHDL SoC Workspace

Bu repo, `CV32E40P` tabanli mikrodenetleyici SoC gelistirmesi icin kullanilan calisma alanidir. Su anki odak, testli non-AI baseline uzerine `AI_CSR`, `AI_MEM`, `AI_UART` veri yukleyici ve RTL hizlandirici adasini eklemektir.

Bugun itibariyla repo su ana kadar su zinciri calistirabiliyor:

- `CV32E40P`
- `OBI -> AXI-Lite` veri yolu koprusu
- yerel `ROM / IMEM / DMEM`
- `UART0`, `UART1`, `GPIO`, `Timer`, `I2C`, `QSPI_CFG`
- `AI_CSR`, `AI_MEM`, `AI_UART` loader, `AI_IRQ`
- sentetik agirlikli TinyConv-sekilli RTL hizlandirici iskeleti
- yerel `QSPI_XIP`
- `ROM -> QSPI/XIP -> IMEM -> handoff` boot akisi
- `fpga_top` FPGA wrapper
- self-checking sim testleri
- Vivado `RTL elaboration`, `synthesis` ve `implementation` checkpoint

Bu repo su an kart ustunde final demo bitstream'i degil. `fpga_top` implementation seviyesine geldi; karta ozel `.xdc`, gercek pin-seviyesi flash bring-up, resmi modelin board-level Vivado kaynak etkisi ve accuracy/performance sign-off sonraki asamalardadir.

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
  - `AI_MEM`
  - `QSPI_XIP`
  - kalan erisimler `external AXI`

### Yerel Bellekler

- `ROM`: `0x0000_0000`, `4 KB`
- `IMEM`: `0x0001_0000`, `8 KB`
- `DMEM`: `0x0002_0000`, `8 KB`
- `AI_MEM`: `0x2000_0000`, `32 KB window / 30 KB hedef`
- `QSPI_XIP`: `0x3000_0000`, `16 MB`

Detaylar:
- [soc/MEMORY_MAP_V0.md](./soc/MEMORY_MAP_V0.md#L1)
- [soc/soc_map_pkg.sv](./soc/soc_map_pkg.sv#L1)

### Cevre Birimleri

Su anki aktif peripheral set:

- `UART0`: native `AXI-Lite`
- `UART1`: native `AXI-Lite`
- `AI_CSR`: native `AXI-Lite`
- `AI_MEM`: CPU AXI-Lite + AI internal port
- `AI_UART loader`: UART1 RX hattini dinleyerek AI_MEM'e byte stream yazar
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
- [soc/tb_cv32e40p_axi_soc_rom_boot.sv](./soc/tb_cv32e40p_axi_soc_rom_boot.sv#L1)
- [soc/tb_cv32e40p_axi_soc_rom_handoff.sv](./soc/tb_cv32e40p_axi_soc_rom_handoff.sv#L1)
- [soc/tb_cv32e40p_axi_soc_rom_image.sv](./soc/tb_cv32e40p_axi_soc_rom_image.sv#L1)

## En Onemli Dosyalar

### Ana SoC Top

- [soc/cv32e40p_axi_soc.sv](./soc/cv32e40p_axi_soc.sv#L1)

Buradan bakarak su ana mimariyi gorebilirsin:
- local memory decode
- MMIO decode
- QSPI XIP entegrasyonu
- boot/reset davranisi
- peripheral baglantilari

### Bellek Katmani

- [soc/soc_mem_sp.sv](./soc/soc_mem_sp.sv#L1)
- [soc/soc_rom.sv](./soc/soc_rom.sv#L1)
- [soc/soc_imem.sv](./soc/soc_imem.sv#L1)
- [soc/soc_axi_lite_imem.sv](./soc/soc_axi_lite_imem.sv#L1)
- [soc/soc_dmem.sv](./soc/soc_dmem.sv#L1)

### Boot ve Flash

- [soc/soc_boot_copy_xip.sv](./soc/soc_boot_copy_xip.sv#L1)
- [soc/soc_qspi_xip.sv](./soc/soc_qspi_xip.sv#L1)
- [soc/soc_axi_lite_qspi_xip.sv](./soc/soc_axi_lite_qspi_xip.sv#L1)
- [soc/soc_qspi_init_seq.sv](./soc/soc_qspi_init_seq.sv#L1)
- [soc/soc_qspi_cfg_mux.sv](./soc/soc_qspi_cfg_mux.sv#L1)
- [soc/soc_apb_qspi_cfg.sv](./soc/soc_apb_qspi_cfg.sv#L1)

### Peripheral Katmani

- [soc/soc_axi_lite_uart.sv](./soc/soc_axi_lite_uart.sv#L1)
- [soc/soc_ai_csr.sv](./soc/soc_ai_csr.sv#L1)
- [soc/soc_ai_mem.sv](./soc/soc_ai_mem.sv#L1)
- [soc/soc_ai_uart_loader.sv](./soc/soc_ai_uart_loader.sv#L1)
- [soc/soc_ai_tinyconv_accel.sv](./soc/soc_ai_tinyconv_accel.sv#L1)
- [soc/soc_axi_lite_apb_island.sv](./soc/soc_axi_lite_apb_island.sv#L1)
- [soc/soc_apb_gpio.sv](./soc/soc_apb_gpio.sv#L1)
- [soc/soc_apb_timer.sv](./soc/soc_apb_timer.sv#L1)
- [soc/soc_apb_i2c_master.sv](./soc/soc_apb_i2c_master.sv#L1)
- [soc/soc_irq_router.sv](./soc/soc_irq_router.sv#L1)

### Ana Dokumanlar

- [TEAM_GUIDE.md](./TEAM_GUIDE.md#L1)
- [soc/ARCHITECTURE_DECISIONS_V0.md](./soc/ARCHITECTURE_DECISIONS_V0.md#L1)
- [soc/MEMORY_MAP_V0.md](./soc/MEMORY_MAP_V0.md#L1)
- [soc/AI_RUNTIME_CONTRACT.md](./soc/AI_RUNTIME_CONTRACT.md#L1)
- [soc/AI_ACCELERATOR_STATUS.md](./soc/AI_ACCELERATOR_STATUS.md#L1)
- [soc/TFLM_MICRO_SPEECH_REFERENCE.md](./soc/TFLM_MICRO_SPEECH_REFERENCE.md#L1)
- [soc/AI_UART_PAYLOAD_PROTOCOL.md](./soc/AI_UART_PAYLOAD_PROTOCOL.md#L1)
- [soc/AI_FIRMWARE_DEMO_FLOW.md](./soc/AI_FIRMWARE_DEMO_FLOW.md#L1)
- [soc/PROJECT_REMAINING_WORK.md](./soc/PROJECT_REMAINING_WORK.md#L1)
- [soc/QSPI_CFG_REGMAP.md](./soc/QSPI_CFG_REGMAP.md#L1)
- [soc/VIVADO_TEST_GUIDE.md](./soc/VIVADO_TEST_GUIDE.md#L1)
- [soc/VIVADO_IMPLEMENTATION_CHECKPOINT.md](./soc/VIVADO_IMPLEMENTATION_CHECKPOINT.md#L1)
- [soc/TEKNOFEST_REVIEW_CHECKLIST.md](./soc/TEKNOFEST_REVIEW_CHECKLIST.md#L1)

## Hangi Vendor IP'ler Kullaniyor

Aktif ucuncu taraf kaynaklari:

- `CV32E40P` core
- UART alt bloklari
- GPIO/Timer peripheral alt bloklari
- QSPI XIP alt bloklari

Atif ve kaynak bilgileri:
- [soc/third_party/ATTRIBUTION.md](./soc/third_party/ATTRIBUTION.md#L1)

## Hemen Baslamak Icin

### Sunum / Demo Paneli

Kart elde yokken mimariyi ve Vivado kanitlarini gorsel olarak anlatmak icin:

```bash
xdg-open demo/index.html
```

Panel dosyalari:
- [demo/index.html](./demo/index.html#L1)
- [demo/README.md](./demo/README.md#L1)

### Gereken Araclar

- `iverilog`
- `vvp`
- `verilator`
- `perl`
- AI model tooling icin `python3` + `numpy`
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
make -C soc AI_PYTHON=../.venv/bin/python ai-smoke
make -C soc AI_PYTHON=../.venv/bin/python ai-feature-payload-demo
make -C soc AI_PYTHON=../.venv/bin/python ai-uart-packet-demo
make -C soc AI_PYTHON=../.venv/bin/python ai-wav-feature-demo
make -C soc ai-model-tool-smoke
make -C soc AI_PYTHON=../.venv/bin/python ai-model-tflm-fetch
make -C soc AI_PYTHON=../.venv/bin/python ai-model-tflm-export
make -C soc AI_PYTHON=../.venv/bin/python ai-model-tflm-demo-golden
make -C soc AI_PYTHON=../.venv/bin/python ai-model-tflm-wav-demo-golden
make -C soc AI_PYTHON=../.venv/bin/python ai-accel-tflm-full-smoke
make -C soc AI_PYTHON=../.venv/bin/python ai-accel-tflm-smoke
make -C soc AI_PYTHON=../.venv/bin/python ai-island-tflm-smoke
make -C soc AI_PYTHON=../.venv/bin/python ai-tflm-smoke
make -C soc ai-accel-model-smoke
make -C soc ai-island-e2e-smoke
make -C soc ai-uart-to-accel-e2e-smoke
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

Resmi Micro Speech model package'i ile:

```bash
make -C soc AI_PYTHON=../.venv/bin/python ai-model-tflm-export
vivado -mode batch -source soc/vivado_smoke.tcl -tclargs xc7a35tcpg236-1 rtl model
vivado -mode batch -source soc/vivado_smoke.tcl -tclargs xc7a35tcpg236-1 ooc model
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

AI tarafinda su altyapi artik entegre ve smoke testlidir:

- `AI_CSR` register alani: `ID`, `CTRL`, `STATUS`, input/output adresleri, sonuc ve cycle sayaci
- `AI_MEM`: `0x2000_0000` altinda CPU ve AI internal erisimli 30 KB local bellek
- `AI_UART loader`: UART1 RX uzerinden AI_MEM'e stream yazma
- `AI_IRQ`: hizlandirici done durumunda fast IRQ bit 19'a bagli
- `soc_ai_tinyconv_accel`: 49x40 input, depthwise-conv sekilli tarama, ReLU, FC-benzeri skor ve argmax akisi
- `tools/ai/export_tinyconv_assets.py`: gercek `.tflite`/`.npz` model asset ve golden uretim araci
- resmi TFLite Micro `micro_speech_quantized.tflite` modelini build asamasinda indirip RTL package formatina cevirme
- `49x40 = 1960 byte` feature payload uretme/dogrulama araci
- yaklasik WAV -> feature payload demo araci

## Su An Ne Eksik

AI harici mimaride hala sonraki fazda olan basliklar:

- karta ozel `.xdc`
- pin-seviyesi gercek QSPI flash bring-up
- timing/power/resource raporlarinin final board constraintleriyle yenilenmesi
- daha urunlesmis boot guvenlikleri:
  - magic
  - size/bounds check
  - checksum / CRC
  - hata kodlari
- daha gercek firmware demolari:
  - `UART print`
  - coklu peripheral bring-up

AI tarafinda kalan yarismaya kritik isler:

- Resmi model package'li Vivado akisini board constraintleriyle tekrar calistirip kaynak/timing etkisini raporlamak
- Full-shape 49x40 resmi model RTL testini periyodik kosmak
- Resmi bit-exact audio preprocessing yolunu cozmek
  - `audio_preprocessor_int8.tflite`, TFLM Signal Library custom op'lari ister
  - mevcut `wav_to_feature_payload.py` sadece demo/veri-yolu icin yaklasik yoldur
- Accuracy hedefini yazilim/TFLite referansina gore raporlamak
- CPU firmware ile UART1 input -> AI start -> IRQ ISR -> UART0 result akisina e2e demo eklemek
- UART payload protokolunun firmware parser/result response kismini uygulamak
- AI resource/performance raporunu cikarmak
- AXI/AXI-Lite protocol checker ve fiziksel tasarim/GDSII sign-off akisini tamamlamak

Detayli ve guncel kalan is listesi:
- [soc/PROJECT_REMAINING_WORK.md](./soc/PROJECT_REMAINING_WORK.md#L1)

## Repo Icinde Calisirken Pratik Kurallar

- Ana referans top dosya: [soc/cv32e40p_axi_soc.sv](./soc/cv32e40p_axi_soc.sv#L1)
- Adres/slot degisikligi gerekiyorsa once [soc/soc_map_pkg.sv](./soc/soc_map_pkg.sv#L1) degistir
- Yeni peripheral eklerken:
  - once local testbench
  - sonra top-level smoke test
  - sonra `make -C soc full`
- Generated dosyalar repo kokeninde tutulmaz; `build/` ve Vivado loglari yeniden uretilir

## Kisa Sonuc

Bu repo su anda AI harici mikrodenetleyici SoC iskeletini anlamak, simule etmek ve Vivado'da smoke seviyesinde sentezlemek icin yeterince duzenli durumdadir. Yeni gelen bir ekip arkadasi icin en iyi baslangic sirasi:

1. [soc/ARCHITECTURE_DECISIONS_V0.md](./soc/ARCHITECTURE_DECISIONS_V0.md#L1)
2. [soc/MEMORY_MAP_V0.md](./soc/MEMORY_MAP_V0.md#L1)
3. [soc/cv32e40p_axi_soc.sv](./soc/cv32e40p_axi_soc.sv#L1)
4. `make -C soc full`
5. sonra ilgili periferalin `tb_*` dosyasina bakmak
