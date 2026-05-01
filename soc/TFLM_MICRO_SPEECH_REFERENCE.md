# TFLite Micro Speech Reference

Bu dokuman, AI adasinda referans alinan resmi TensorFlow Lite Micro Micro Speech
orneginin proje icindeki rolunu sabitler.

## Kaynak

Resmi kaynak:

```text
https://github.com/tensorflow/tflite-micro/tree/main/tensorflow/lite/micro/examples/micro_speech
```

Bu repo komple vendor edilmeyecek. Biz sadece model kontratini, kucuk referans
dosyalarini ve `micro_speech_quantized.tflite` modelini build asamasinda aliriz.

## Model Kontrati

Resmi Micro Speech modelinin SoC tarafinda kullandigimiz kismi:

```text
input:  49 x 40 int8 spectrogram feature = 1960 byte
output: 4 kategori
labels: silence, unknown, yes, no
```

Donanim pipeline hedefi:

```text
1960 int8
  -> reshape 49x40x1
  -> DepthwiseConv2D, kernel 10x8, stride 2, depth_multiplier 8
  -> ReLU
  -> flatten 25x20x8 = 4000
  -> FullyConnected 4000 -> 4
  -> class scores / argmax
```

Not: Resmi TFLite modelinde Softmax olasilik uretimi vardir. V1 RTL icin
zorunlu sign-off cikisi `4 skor + argmax class` olarak tutulur. Gerekirse
Softmax yazilim/demo tarafinda uygulanabilir.

## SoC Eslesmesi

- `AI_MEM` input buffer: `0x2000_0000`, `1960 B`
- `AI_MEM` output buffer: `0x2000_7000`
- `AI_CSR`: `0x1000_6000`
- `AI_IRQ`: fast IRQ bit `19`
- Veri yukleme: CPU AXI-Lite yazimi veya UART1 RX loader

Bu katman, Micro Speech modelinin kendisi degil, modeli calistiran SoC veri
yoludur.

## Resmi Modeli Cekme

Proje kokunden:

```bash
make -C soc AI_PYTHON=../.venv/bin/python ai-model-tflm-fetch
```

Bu hedef su dosyalari `soc/build/tflm_micro_speech/` altina indirir:

- `models/micro_speech_quantized.tflite`
- `micro_model_settings.h`
- `README.md`
- `manifest.json`

Audio preprocessing V1 donanim kapsaminda olmadigi icin varsayilan hedef WAV
test verilerini veya `audio_preprocessor_int8.tflite` modelini indirmez.

## Feature Payload Hazirlama

AI accelerator ham ses degil, `49x40 = 1960 byte` int8 feature tensor alir.
Bu tensorun dosya formati:

```bash
make -C soc AI_PYTHON=../.venv/bin/python ai-feature-payload-demo
```

Bu komut `soc/build/ai_feature_payload/` altinda:

- `.npy`: Python/TFLite golden icin
- `.memh`: testbench/simulasyon icin
- `.bin`: UART uzerinden karta gondermek icin

dosyalarini uretir. Gercek ses demosunda `.npy` kaynagi resmi veya uyumlu bir
audio preprocessing akisindan gelecek; bu arac sadece format dogrulama ve
paketleme yapar.

Resmi Micro Speech modelini bu demo payload uzerinde calistirip golden uretmek:

```bash
make -C soc AI_PYTHON=../.venv/bin/python ai-model-tflm-demo-golden
```

## WAV Demo Yolu

Resmi `audio_preprocessor_int8.tflite` modeli `SignalWindow` gibi TFLM custom
Signal Library op'lari kullandigi icin stok masaustu TensorFlow Lite interpreter
ile dogrudan calismaz. Bu nedenle V1'de iki ayri yol tutulur:

- Accuracy/sign-off icin: resmi/uyumlu TFLM preprocessing runtime sonraki is.
- Veri yolu demosu icin: hafif yaklasik WAV preprocessor.

Yaklasik WAV -> `49x40` payload uretmek:

```bash
make -C soc AI_PYTHON=../.venv/bin/python ai-wav-feature-demo
```

Bu yol resmi `yes_1000ms.wav` orneginden:

- `yes_1000ms_1960_int8.npy`
- `yes_1000ms_1960_int8.memh`
- `yes_1000ms_1960_int8.bin`

dosyalarini uretir. `.bin`, kart demosunda UART loader'a gonderilecek ham
1960-byte payload olarak kullanilabilir.

Bu payload uzerinde resmi Micro Speech classifier golden uretmek:

```bash
make -C soc AI_PYTHON=../.venv/bin/python ai-model-tflm-wav-demo-golden
```

## RTL Asset Uretme

TensorFlow veya `tflite-runtime` kurulu Python ortami ile:

```bash
make -C soc AI_PYTHON=../.venv/bin/python ai-model-tflm-export
```

Bu hedef resmi `.tflite` dosyasindan:

- `tinyconv_assets.npz`
- `manifest.json`
- `soc_ai_model_pkg.sv`
- `smoke_input_vector.memh`
- `soc_ai_model_smoke_golden_pkg.sv`

dosyalarini `soc/build/ai_model_tflm_micro_speech/` altina uretir.

## Hızlı RTL Smoke

Resmi model package'i ile accelerator veri yolunu derlemek ve kucuk smoke
golden ile kosmak icin:

```bash
make -C soc AI_PYTHON=../.venv/bin/python ai-accel-tflm-smoke
```

Bu test tam 49x40 inference sign-off degildir; amaci resmi modelden uretilen
SystemVerilog package'in RTL tarafindan okunabildigini ve accumulator/requantize
yolunun kirilmadigini hizli kontrol etmektir.

Tam `49x40` accelerator veri yolunu kontrol etmek icin:

```bash
make -C soc AI_PYTHON=../.venv/bin/python ai-accel-tflm-full-smoke
```

Bu hedef hizli regresyona dahil degildir; resmi model package'i ve 1960 byte
input ile tum accelerator taramasini kosar.

Resmi model package'i AI island yolundan gecirmek icin:

```bash
make -C soc AI_PYTHON=../.venv/bin/python ai-island-tflm-smoke
```

Bu test `AI_MEM -> AI_CSR -> accelerator -> IRQ/result` baglantisini resmi
model agirlik paketiyle kontrol eder.

## Vivado Model Package Modu

Vivado batch smoke/ooc akisini resmi model package ile calistirmak:

```bash
make -C soc AI_PYTHON=../.venv/bin/python ai-model-tflm-export
vivado -mode batch -source soc/vivado_smoke.tcl -tclargs xc7a35tcpg236-1 rtl model
vivado -mode batch -source soc/vivado_smoke.tcl -tclargs xc7a35tcpg236-1 ooc model
```

GUI projesinde ayni modu kullanmak icin Tcl Console:

```tcl
set use_ai_model_pkg 1
source /home/emirhan/Desktop/VHDL/soc/vivado_gui_add_sources.tcl
```

## V1 Siniri

V1'de ham ses -> spectrogram preprocessing donanimda degil. AI accelerator,
hazirlanmis `49x40` int8 feature tensorunu alir. Bu karar tasarimi FPGA/Vivado
ve RTL entegrasyonu icin makul boyutta tutar; preprocessing daha sonra yazilim
veya ayri donanim blogu olarak eklenebilir.
