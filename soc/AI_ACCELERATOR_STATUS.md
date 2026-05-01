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
- `tools/ai/fetch_tflm_micro_speech.py`: resmi TFLite Micro Micro Speech
  referans dosyalarini build klasorune indirir; tum TFLM reposu vendor edilmez
- `tools/ai/prepare_feature_payload.py`: hazir `49x40` int8 tensorleri `.npy`,
  `.memh` ve UART'a uygun `.bin` payload formatina cevirir
- `tools/ai/wav_to_feature_payload.py`: 16 kHz mono WAV dosyasindan yaklasik
  demo feature payload uretir; resmi Signal Library preprocessing yerine gecmez
- `ai-model-tflm-fetch` / `ai-model-tflm-export`: resmi
  `micro_speech_quantized.tflite` dosyasini indirip RTL package formatina cevirme
  akisini baslatir
- `ai-wav-feature-demo` / `ai-model-tflm-wav-demo-golden`: resmi test WAV
  dosyasindan demo payload ve classifier golden uretir

## Bilerek Eksik Kalanlar

- Resmi TFLite Micro Speech quantized agirlik/bias/scale degerleri build
  asamasinda export edilebilir; bu henuz varsayilan RTL/Vivado kaynak listesine
  sabit model ROM'u olarak alinmadi.
- Resmi `audio_preprocessor_int8.tflite` modeli TFLM Signal Library custom
  op'lari (`SignalWindow` vb.) kullandigi icin stok desktop TensorFlow Lite
  interpreter ile dogrudan calismaz; bit-exact audio preprocessing sign-off
  sonraki fazdir.
- Mevcut accelerator sentetik deterministik agirlik fonksiyonlari kullanir; accuracy iddiasi tasimaz.
- Softmax olasiliklari yerine argmax ve ham sinif skorlarinin yazilmasi uygulanmistir.
- CPU firmware ISR demo akisi henuz eklenmedi.
- AXI protocol checker ve ASIC/GDSII sign-off akisi henuz tamamlanmadi.

Bu nedenle mevcut durum, AI adasinin SoC'ye bagli ve testli oldugunu kanitlar; final yarismada gereken accuracy/performance kaniti icin resmi model agirliklari ve golden test setiyle bir sonraki faz gerekir.
