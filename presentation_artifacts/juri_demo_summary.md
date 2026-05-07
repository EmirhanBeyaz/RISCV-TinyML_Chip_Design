# AnkaRISC Jüri Canlı Demo Özeti

## Canlı demoda gösterilenler

| Test | Gösterilen kanıt | Sonuç |
|---|---|---|
| AI CSR | AXI-Lite register okuma/yazma, accel_start, irq set/clear | PASS beklenir |
| UART | CTRL ayarı ve TXDATA=0x55 ile uart_tx frame | PASS beklenir |
| IRQ Router | Timer/GPIO/UART/AI kaynaklarının core_irq bitlerine taşınması | PASS beklenir |
| GPIO | PIN0, SETDIR, OUT0, SETGPIO, CLRGPIO ve readback | PASS beklenir |
| RISC-V Benchmark | FPU'suz fixed-point/integer C kodu, ELF/BIN/IMEM HEX | PASS beklenir |

## Benchmark içeriği

- Taylor Q15 sin(x) seri açılımı
- Newton interpolasyonu
- Sabit çevrim pencereli nümerik ve sistem benchmarkları
- Newton sqrt, bisection sqrt, Newton reciprocal, Jacobi 2x2
- CORDIC sin/cos, FIR16 filter, 8x8 matvec
- CRC32 64B, sort32, pointer chase64
- 4x4 integer matris çarpımı
- 512 byte memory copy
- UART çıktı altyapısı
- GPIO LED durum göstergesi
- mcycle ile çevrim ölçümü altyapısı

## 1 saniyeye ölçeklenen işlemci benchmark sonuçları

Bu ölçümde işlemci 50 MHz saat varsayımıyla değerlendirilir. Her algoritma `100000` çevrim, yani `2 ms`, boyunca üç kez çalıştırılır; ortalama değer `x500` ile `1 saniye` eşdeğerine ölçeklenir. Böylece tüm iş yükleri aynı zaman bütçesi altında karşılaştırılır.

| İş yükü sınıfı | Benchmark | 2 ms pencere sonucu | 1 saniye eşdeğeri | Akademik yorum |
|---|---|---:|---:|---|
| Nümerik | `newton_sqrt` | 1394 iterasyon | 697000 iterasyon/s | Bölme içeren iteratif karekök hesabında aritmetik yoğunluğu ölçer. |
| Nümerik | `bisection_sqrt` | 1523 iterasyon | 761666 iterasyon/s | Karşılaştırma ve dallanma yoğun kök arama davranışını temsil eder. |
| Nümerik | `newton_reciprocal` | 1924 iterasyon | 962000 iterasyon/s | Fixed-point çarpma ağırlıklı reciprocal iterasyonlarının verimini gösterir. |
| Nümerik | `jacobi_2x2` | 935 iterasyon | 467500 iterasyon/s | Küçük ölçekli lineer denklem çözümünde veri bağımlı güncelleme yükünü ölçer. |
| DSP | `cordic_sincos` | 396 hesap | 198000 hesap/s | FPU olmadan trigonometrik hesap yapılabildiğini gösteren CORDIC yüküdür. |
| DSP | `fir16_filter` | 269 sample | 134500 sample/s | 16 tap FIR filtre ile çarp-topla yoğun DSP benzeri iş yükünü temsil eder. |
| AI-benzeri | `matvec8x8` | 77 matvec | 38500 matvec/s | 8x8 matris-vektör çarpımıyla küçük AI çekirdeklerinin 64 MAC yükünü örnekler. |
| Veri | `crc32_64B` | 18 blok | 9000 blok/s | 64 byte bloklarda bit kaydırma, XOR ve veri bütünlüğü maliyetini ölçer. |
| Kontrol | `sort32` | 18 sıralama | 9166 sıralama/s | Dallanma yoğun kontrol akışı ve küçük bellek taşıma maliyetini görünür kılar. |
| Bellek | `pointer_chase64` | 149 zincir | 74500 zincir/s | Bağımlı bellek erişimlerinde ardışık yükleme gecikmesini karakterize eder. |

## Yazılım çıktıları

- ELF: `soc/sw/benchmark.elf`
- BIN: `soc/sw/benchmark.bin`
- IMEM HEX: `soc/sw/benchmark_imem.hex`
- Text boyutu: 4004 byte
- IMEM word sayısı: 1018

## Sunum cümlesi

Bu demo ile yalnızca RTL dosyası değil; register seviyesi çevre birimi doğrulaması, interrupt yönlendirme, UART/GPIO haberleşmesi ve FPU bulunmayan RISC-V mikrodenetleyici üzerinde çalışacak fixed-point bare-metal benchmark akışı gösterilmektedir. Benchmark, 2 ms'lik sabit ölçüm penceresinden 1 saniyeye ölçeklenerek nümerik çözüm, DSP, AI-benzeri matris işlemi, veri bütünlüğü ve bellek erişimi karakterini birlikte gösterir.
