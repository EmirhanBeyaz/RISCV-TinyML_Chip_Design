# AI Accelerator Status

Bu not, mevcut AI entegrasyonunun gercek yarismaya gore nerede durdugunu net tutmak icin eklendi.

## Entegre Edilenler

- `AI_CSR`: `0x1000_6000`, native AXI-Lite control/status/result register alani
- `AI_MEM`: `0x2000_0000`, 32 KB decode window / 30 KB implemented local memory
- `AI_UART loader`: UART1 RX uzerinden gelen byte stream'i `AI_MEM` giris adresine yazar
- `AI_IRQ`: accelerator done durumunda `SOC_IRQ_FAST_AI_BIT = 19`
- `soc_ai_tinyconv_accel`: TinyConv sekline uygun RTL inference iskeleti
  - 49x40 input adresleme
  - 10x8 depthwise convolution taramasi
  - stride 2 / SAME padding davranisi
  - ReLU
  - FC-benzeri 4 sinif skor biriktirme
  - argmax sonucu ve skor registerlari
- `tools/ai/export_tinyconv_assets.py`: gercek model fazi icin asset/golden uretim araci
  - `.tflite` modelden agirlik, bias ve quantization degerlerini cikarma
  - normalized `.npz` asset dump uretme/okuma
  - NumPy reference golden ciktilari uretme
  - sonraki RTL fazinda kullanilacak `soc_ai_model_pkg.sv` package dosyasini generate etme
- `tools/ai/make_synthetic_tinyconv_tflite.py`: TensorFlow kurulu ortamda `.tflite` extraction hattini sentetik int8 TinyConv modelle smoke test eder

## Bilerek Eksik Kalanlar

- Resmi TFLite Micro Speech quantized agirlik/bias/scale degerleri henuz RTL ROM'a alinmadi; artik bunun icin tooling hazir, model dosyasi gerekiyor.
- Mevcut accelerator sentetik deterministik agirlik fonksiyonlari kullanir; accuracy iddiasi tasimaz.
- Softmax olasiliklari yerine argmax ve ham sinif skorlarinin yazilmasi uygulanmistir.
- CPU firmware ISR demo akisi henuz eklenmedi.
- AXI protocol checker ve ASIC/GDSII sign-off akisi henuz tamamlanmadi.

Bu nedenle mevcut durum, AI adasinin SoC'ye bagli ve testli oldugunu kanitlar; final yarismada gereken accuracy/performance kaniti icin resmi model agirliklari ve golden test setiyle bir sonraki faz gerekir.
