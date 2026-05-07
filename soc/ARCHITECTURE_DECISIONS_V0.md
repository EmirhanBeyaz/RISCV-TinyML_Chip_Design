# Architecture Decisions V0

Bu dosya, projenin mevcut resmi teknik yönünü sabitlemek için tutulur.
Başvuru omurgası proje raporu ile uyumlu tutulur.
Detay teknik yürütme takımın güncel teknik planı doğrultusunda yapılır.

## 1. Sabit Omurga

Bu kararlar korunacaktır:

- CPU çekirdeği `CV32E40P`
- SoC tipi `RISC-V tabanlı mikrodenetleyici`
- Boot fikri `ROM -> QSPI -> IMEM`
- Yerel bellekler `ROM`, `IMEM`, `DMEM`
- AI hedefi `Micro Speech / KWS`
- CPU-AI koordinasyonu `memory-mapped CSR + IRQ`
- Temel çevre birimleri `GPIO`, `Timer`, `UARTx2`, `I2C Master`, `QSPI Master`

## 2. Bus Kararı

Sistem içi ana yön şu şekilde olacaktır:

- CPU instruction tarafı yerel instruction path üzerinden çalışır
- CPU data tarafı bus/interconnect üzerinden memory-mapped erişim yapar
- Üst seviye bus yaklaşımı `AXI / AXI-Lite`
- Gerekirse çevre birimleri için `AXI-Lite -> APB` ada yapısı kullanılır

Not:
- `CV32E40P` doğal olarak `OBI` konuştuğu için data tarafında bridge/wrapper kullanılması kabul edilmiş tasarım kararıdır

## 3. Bellek Kararı

Bellek organizasyonu şu omurga ile ilerler:

- `ROM`: boot kodu / ilk başlatma
- `IMEM`: instruction memory
- `DMEM`: data memory
- `AIMEM`: AI veri akışı için ayrılmış alan

Şu an için yön:

- `ROM` küçük ve kontrol amaçlı tutulabilir
- `IMEM` ve `DMEM` ayrı kalır
- `AIMEM`, accelerator ile veri paylaşımı için ayrı pencere olarak düşünülür

Memory map değişebilir, fakat bu dört bölgenin varlığı korunur.

## 4. AI Kararı

İlk gerçekçi hedef `MVP accelerator` yaklaşımıdır:

- `MFCC / log-mel` gibi feature extraction ilk aşamada CPU tarafında yapılır
- Donanım hızlandırıcısı ilk versiyonda yalnızca inference işini üstlenir
- CPU, giriş/çıkış adreslerini ve boyutları CSR üzerinden yazar
- Hızlandırıcı iş bitince `DONE` ve/veya `IRQ` üretir

İleri seviye opsiyonlar:

- `DMA`
- `AXI-Stream`
- cycle sayacı (`PERF_CYCLES`)

Bunlar hedeflenir ama ilk çalışan sürüm için zorunlu değildir.

## 5. Çevre Birimi Kararı

Temel çevre birimleri korunur:

- `GPIO`
- `Timer`
- `UART0`
- `UART1`
- `I2C Master`
- `QSPI Master`

Uygulama yaklaşımı:

- Basit ve standart peripheral IP'lerde açık kaynak reuse kabul edilir
- Gerekirse vendor + wrapper yöntemi kullanılır
- Ancak tüm SoC omurgası dışarıdan alınmaz

## 6. Reuse Kararı

Kabul edilen yaklaşım:

- Seçici açık kaynak IP reuse
- Vendor edilen bloklar repo içine alınır
- Gerekli durumlarda wrapper ile uyarlanır
- Entegrasyon ve doğrulama bu projede yapılır

Kabul edilmeyen yaklaşım:

- Hazır bir SoC'yi neredeyse aynen alıp isim değiştirerek kullanmak

## 7. Doğrulama Kararı

Minimum doğrulama hattı:

- modül seviyesi self-checking testler
- sistem seviyesi smoke testler
- boot akışı testleri
- AI kontrol akışı testleri

Hedef araçlar:

- `Icarus Verilog`
- `GTKWave`
- `ISS/Spike`
- gerekirse daha güçlü simülatörler
- FPGA prototipleme

İleri seviye doğrulama:

- `UVM uyumlu` modüler test yaklaşımı

## 8. Fiziksel Tasarım Kararı

Yön:

- FPGA bring-up
- daha sonra açık kaynak ASIC akışına uygun ilerleme
- `OpenLane` hedefli fiziksel tasarım yaklaşımı

Bu aşama erken entegrasyon kararlarını bloke etmez.

## 9. Dikkatli Anlatılması Gerekenler

Sunum ve rapor dilinde şu çerçeve korunmalıdır:

- Açık kaynak bloklar doğrudan ürün gibi değil, uyarlanmış IP olarak anlatılmalı
- Asıl değer `mimari seçim`, `entegrasyon`, `memory map`, `boot`, `AI_CSR/IRQ`, `doğrulama` ve `bring-up` tarafındadır
- OTR kararları, İnüfest başvurusundan kopuş değil; detay tasarım netleşmesi olarak konumlandırılmalıdır

## 10. Şu Anki Çalışma Sırası

Önerilen yakın sıra:

1. `OBI -> AXI/AXI-Lite` hattını koru
2. `AXI-Lite -> APB` peripheral island kur
3. `Timer` ve `GPIO` entegrasyonu
4. `IRQ` toplama yaklaşımı
5. `UART` stratejisi
6. `QSPI boot`
7. `AI_CSR + AIMEM + accelerator`

## 11. V0 Sonucu

Bu proje şu cümle ile özetlenir:

`CV32E40P tabanlı, AXI/AXI-Lite yönelimli, ROM->QSPI->IMEM boot akışına sahip, seçici reuse kullanan, CSR+IRQ ile kontrol edilen Micro Speech odaklı AI hızlandırıcılı bir mikrodenetleyici SoC`
