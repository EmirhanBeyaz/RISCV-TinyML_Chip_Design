# Memory Map V0

Bu dosya geçici ama merkezi adres haritasıdır. Tek kaynak [soc_map_pkg.sv](./soc_map_pkg.sv) olmalıdır.

Kurallar:
- MMIO çevre birimleri `4 KB` slot kullanır.
- Yeni çevre birimi eklerken mümkünse sadece yeni bir slot açılır.
- Bellek blokları güç-of-two `window` alır.
- Gerçek kapasite `implemented_bytes` ile tutulur.
- Decode mantığı `window_bytes` üzerinden yapılır.

## Yerel Bellekler

| Bölge | Base | Window | Gerçek |
|---|---:|---:|---:|
| ROM | `0x0000_0000` | `4 KB` | `4 KB` |
| IMEM | `0x0001_0000` | `8 KB` | `8 KB` |
| DMEM | `0x0002_0000` | `8 KB` | `8 KB` |

## MMIO Slotları

| Slot | Base | Bölge |
|---|---:|---|
| 0 | `0x1000_0000` | QSPI CFG |
| 1 | `0x1000_1000` | GPIO |
| 2 | `0x1000_2000` | TIMER |
| 3 | `0x1000_3000` | I2C |
| 4 | `0x1000_4000` | UART0 |
| 5 | `0x1000_5000` | UART1 / AI_UART |
| 6 | `0x1000_6000` | AI_CSR |
| 7+ | ayrılmış | gelecekteki çevre birimleri |

## Büyük Pencereler

| Bölge | Base | Window | Gerçek |
|---|---:|---:|---:|
| AI_MEM | `0x2000_0000` | `32 KB` | `30 KB` |
| QSPI XIP | `0x3000_0000` | `16 MB` | `16 MB` |

Not:
- `AI_MEM` için `32 KB` decode penceresi kullanılıyor; gerçek ihtiyaç `30 KB`.
- `AI_CSR` native AXI-Lite slave olarak bağlıdır; APB adasının içinde değildir.
- `AI_MEM`, CPU AXI-Lite erişimi ile AI UART loader / accelerator internal portunu paylaşır.
- İleride değişiklik gerektiğinde önce `soc_map_pkg.sv`, sonra decoder ve linker script güncellenmeli.
