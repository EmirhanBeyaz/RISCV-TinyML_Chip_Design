# Project Remaining Work

Bu dosya, repodaki mevcut durumdan sonra kalan işleri ekip icin net ayirmak
icin tutulur. Durum: AI harici SoC iskeleti ve AI adasi temel entegrasyonu
simulasyon seviyesinde calisiyor; kart ve final accuracy sign-off henuz yok.

## 1. AI Harici SoC / Board-Level Kalanlar

- Karta ozel `.xdc` dosyasini netlestirmek
  - clock/reset pinleri
  - UART0/UART1 pinleri
  - QSPI flash pinleri
  - GPIO/LED/debug pinleri
- `fpga_top` uzerinden gercek board constraint ile Vivado implementation almak
- Timing constraintleri eklemek
  - ana saat periyodu
  - false-path / async reset kararları
  - UART/QSPI board IO timing varsayimlari
- Gercek QSPI flash bring-up yapmak
  - pin seviyesinde okuma
  - flash ID / basic read testi
  - XIP veya boot image okuma
- Boot zincirini daha guvenli hale getirmek
  - magic kontrolu
  - image size / bounds kontrolu
  - checksum veya CRC
  - hata durumunda debug/status kodu
- Firmware demo akisini eklemek
  - UART0 print
  - GPIO blink/status
  - Timer interrupt
  - QSPI boot status
- AXI/AXI-Lite protokol checker veya daha sert bus testleri eklemek
- Vivado power/timing/resource raporlarini proje checkpoint dokumanina islemek

## 2. AI Tarafi Kalanlar

- Resmi Micro Speech model package'inin Vivado kaynak akisini board uzerinde
  tekrar dogrulamak
  - batch/GUI scriptlerine opsiyonel `model` modu eklendi
  - model ROM/tablo boyutunun kaynak kullanim etkisi raporlanmali
  - gerekirse package yerine ROM/RAM tabanli agirlik saklama dusunulecek
- Full-shape resmi model RTL testini periyodik kosmak
  - hedef: `ai-accel-tflm-full-smoke`
  - yavas oldugu icin gunluk `full` icinde degil
- Resmi/bit-exact audio preprocessing yolunu cozmek
  - `audio_preprocessor_int8.tflite` TFLM Signal Library custom op'lari ister
  - desktop TensorFlow Lite interpreter tek basina yeterli degil
  - secenekler: TFLM C++ runner, custom-op destekli Python wrapper, veya RTL/firmware preprocessing
- Gercek test setiyle accuracy raporu uretmek
  - silence / unknown / yes / no ornekleri
  - TFLite golden class
  - RTL class
  - eslesme orani
- CPU firmware demo akisini gercek build sistemine baglamak
  - akisin dokumani: [AI_FIRMWARE_DEMO_FLOW.md](./AI_FIRMWARE_DEMO_FLOW.md#L1)
  - referans pseudocode: [firmware/ai_demo_flow.c](./firmware/ai_demo_flow.c#L1)
  - RISC-V toolchain/linker/startup henuz eklenmedi
- UART payload protokolunun firmware tarafini uygulamak
  - format karari: [AI_UART_PAYLOAD_PROTOCOL.md](./AI_UART_PAYLOAD_PROTOCOL.md#L1)
  - host packet araci hazir
  - firmware parser henuz yazilmadi
- Softmax kararini netlestirmek
  - RTL V1: raw score + argmax yeterli
  - demo UI/firmware: gerekirse softmax benzeri olasilik gosterimi
- AI performans/resource raporu cikarmak
  - cycle count
  - LUT/FF/BRAM/DSP farki
  - model package eklenince Vivado resource etkisi

## 3. Simulasyon ve Regresyon Kalanlar

- `make -C soc full` korunacak
- AI icin mevcut hizli hedefler korunacak
  - `ai-smoke`
  - `ai-tflm-smoke`
  - `ai-island-tflm-smoke`
- Full-shape resmi model testi ayri, yavas hedef olarak korunacak
  - hedef: `ai-accel-tflm-full-smoke`
- UART1 payload loader icin 1960-byte tam uzunluk testi eklenmeli
- CPU firmware seviyesinde e2e sim hedefi eklenmeli
- Vivado GUI/batch kaynak listeleri `nomodel/model` secimiyle guncel tutulacak

## 4. Dokumantasyon ve Juri Anlatimi

- Mimari semada su bloklar ayri gorunmeli
  - CV32E40P
  - OBI -> AXI/AXI-Lite bridge
  - ROM/IMEM/DMEM
  - QSPI XIP / boot copy
  - APB island
  - UART0/UART1/GPIO/Timer/I2C
  - AI_CSR
  - AI_MEM 30 KB
  - AI_UART loader
  - TinyConv accelerator
  - IRQ router
- AI ic mimari semasi ayrica gosterilmeli
  - 1960 int8 input
  - reshape 49x40x1
  - depthwise conv
  - ReLU
  - FC
  - skor/argmax
- `AI unit` tek kutu olarak birakilmamali; alt baglantilar acik gorunmeli
- Reuse edilen acik kaynaklar sadece attribution olarak anlatilmali
- Vivado synthesis/implementation raporlari ekran goruntusu ve tablolarla saklanmali

## 5. Kisa Oncelik Sirasi

1. `ai-island-tflm-smoke`, `ai-tflm-smoke` ve `ai-accel-tflm-full-smoke` hedeflerini ekip makinelerinde tekrar dogrula.
2. UART1 payload firmware parser/result response akisini yaz.
3. Resmi model package'li Vivado run'ini kaynak/timing raporuyla tekrar al.
4. Board `.xdc` ve fpga_top implementation sonucunu guncelle.
5. Bit-exact audio preprocessing icin TFLM C++ runner veya uyumlu bir yol sec.
6. Accuracy/performance raporunu cikart.
