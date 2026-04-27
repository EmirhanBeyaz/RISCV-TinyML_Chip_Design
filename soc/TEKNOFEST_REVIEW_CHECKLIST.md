# Teknofest Hakem Geri Bildirimi Checklist

Bu dosya, hakemlerin puan kırdığı mimari ve raporlama başlıklarını tekrar kaçırmamak için tutulur.

Amaç:
- mimari şemayı daha teknik ve savunulabilir hale getirmek
- raporda eksik bırakılan bağlantıları açıkça göstermek
- mevcut RTL ile rapor arasında boşluk kalmamasını sağlamak

## 1. OBI -> AXI Dönüşümü Şemada Açıkça Gösterilmeli

Hakem notu:
- `CV32E40P` çekirdeğinin doğal arayüzü `OBI`
- mimari şemada `OBI2AXI` dönüşümü görünmüyor

Bizim mevcut RTL karşılığı:
- [cv32e40p_obi_to_axi_lite.sv](./cv32e40p_obi_to_axi_lite.sv#L1)

Rapor/şema kuralı:
- `CV32E40P` bloğunun data tarafında doğrudan `AXI` çizilmemeli
- araya açıkça `OBI -> AXI-Lite` köprüsü konmalı
- instruction tarafı ayrı, data tarafı ayrı gösterilmeli

Yazı içinde net cümle:
- `CV32E40P` çekirdeği doğal olarak `OBI` arayüzü üretir. SoC veri tarafında çevre birimleri ve yerel belleklerle entegrasyon için `OBI -> AXI-Lite` köprüsü kullanılmıştır.

## 2. Boot ROM Şemada Açıkça Görünmeli

Hakem notu:
- Boot ROM mimari şemada görünmüyor

Bizim mevcut RTL karşılığı:
- [soc_rom.sv](./soc_rom.sv#L1)
- [soc_boot_copy_xip.sv](./soc_boot_copy_xip.sv#L1)

Rapor/şema kuralı:
- `Boot ROM` ayrı blok olarak çizilmeli
- `ROM -> QSPI/XIP -> IMEM -> CPU fetch` zinciri açık olmalı
- `boot-copy` veya `boot loader` mantığı ayrıca etiketlenmeli

Yazı içinde net cümle:
- sistem açılışında `Boot ROM`, `QSPI/XIP` alanından program imajını `IMEM`e kopyalayan boot akışını başlatır; çekirdek daha sonra komutlarını `IMEM` üzerinden yürütür

## 3. AI Tarafındaki 30 KB Bellek ve UART Net Gösterilmeli

Hakem notu:
- `AI` tarafındaki `30 kB` bellek ve `UART` mimari şemada görünmüyor
- muhtemelen AI bloğu içine gömülmüş ama bağlantı okunmuyor

Bizim rapor/şema kuralı:
- `AI_PROCESSOR`
- `AI_CSR`
- `AI_MEM (30 kB)`
- `AI_UART`
ayrı bloklar olarak çizilmeli

Gösterilmesi gereken bağlantılar:
- `CPU/MMIO -> AI_CSR`
- `AI_CSR -> status/done/irq`
- `AI_PROCESSOR <-> AI_MEM`
- `AI_UART <-> AI_MEM` veya veri yolu
- gerekirse `AI_PROCESSOR -> IRQ router`

Burada özellikle yapılmaması gereken:
- `AI unit` diye tek kutu çizip tüm alt yapıyı içine saklamak

## 4. Peripheral Bölümü Ayrı ve Düzenli Olmalı

Hakem notu:
- peripheral’ların sadece adı geçmiş, detay yok

Bizim rapor kuralı:
- çevre birimleri için ayrı bölüm olmalı
- her blok için en az şu tablo verilmeli:
  - blok adı
  - görev
  - bus tipi
  - adres aralığı
  - interrupt üretip üretmediği
  - mevcut durum: `reuse / wrapper / custom`

Şu an elimizde RTL karşılığı olanlar:
- `UART0`
- `GPIO`
- `Timer`
- `QSPI_CFG`
- `ROM`
- `IMEM`
- `DMEM`

İleride eklenecekler:
- `UART1`
- `I2C`
- `QSPI master/XIP`
- `AI_CSR`
- `AI_MEM`
- `AI_UART`

## 5. Interconnect Detayı Genel Cümleyle Geçiştirilmemeli

Hakem notu:
- `AXI/AXI-Lite tabanlı yapı hedeflenecektir` demek yetmiyor
- neyin `AXI`, neyin `AXI-Lite`, kimin master/slave olduğu açıkça bekleniyor

Bizim rapor kuralı:
- ayrı bir `Interconnect Yapısı` alt başlığı olmalı
- burada en az bir tablo bulunmalı

Önerilen tablo sütunları:
- blok
- arayüz tipi
- rol (`master/slave`)
- bağlandığı yer
- kullanım amacı

Bu faz için teknik gerçeklik:
- `CV32E40P data side` -> `OBI`
- `OBI bridge output` -> `AXI-Lite master`
- `DMEM` -> local `AXI-Lite slave`
- `UART0` -> local `AXI-Lite slave`
- `MMIO APB island` -> `AXI-Lite slave` arkasında `APB` peripheral alanı
- `GPIO/Timer/QSPI_CFG` -> `APB slave`
- `QSPI_XIP` -> local `AXI-Lite read-only slave` olacak

Master adayları:
- CPU data-side bridge
- boot-copy engine

Slave adayları:
- DMEM
- UART0
- APB island
- QSPI_XIP
- external AXI window

## 6. Şema Beklentisi: “İsim Listesi” Değil “Akış Diyagramı”

Hakemlerin asıl mesajı şu:
- sadece blok isimlerini dizmek yetmiyor
- veri ve kontrol akışını göstermek gerekiyor

Bu yüzden final şemada açıkça görünmesi gereken akışlar:
- instruction fetch yolu
- data access yolu
- boot yolu
- IRQ yolu
- AI status/done yolu
- peripheral MMIO yolu

## 7. Bizim Açımızdan Doğrudan Aksiyonlar

Bu geri bildirime göre her OTR/final raporda zorunlu kontrol listemiz:

1. Şemada `OBI -> AXI-Lite` köprüsü görünmeli
2. `Boot ROM` görünmeli
3. `ROM -> QSPI/XIP -> IMEM` akışı görünmeli
4. `AI_MEM 30 kB` ayrı blok olarak görünmeli
5. `AI_UART` ayrı blok olarak görünmeli
6. Peripheral’lar için tablo olmalı
7. Interconnect için `master/slave + AXI/AXI-Lite/APB` tablosu olmalı
8. IRQ kaynakları ve CPU’ya giden yol görünmeli

## 8. Mevcut Durum Değerlendirmesi

Bugün RTL tarafında bu eleştirilerin bir kısmını kapatmış durumdayız:
- `OBI -> AXI-Lite`: var
- `Boot ROM`: var
- `IMEM/DMEM`: var
- `QSPI_CFG`: var
- `boot-copy`: var
- `UART0/GPIO/Timer`: var
- `IRQ routing`: var

Henüz eksik olanlar:
- gerçek `QSPI_XIP` top-level entegrasyonu
- `UART1`
- `I2C`
- AI tarafının tam blok ayrımı
- rapor içinde peripheral/interconnect tabloları

## 9. Kural

Bundan sonra yeni bir blok eklerken sadece RTL’yi değil, şu soruları da kapatacağız:
- şemada nasıl görünecek?
- hangi bus’a bağlı?
- master mı slave mi?
- adresi ne?
- IRQ üretiyor mu?
- raporda hangi bölümde anlatılacak?

Bu dosya, bundan sonra mimari anlatım için “hakem gözüyle kontrol listesi” olarak kullanılmalı.
