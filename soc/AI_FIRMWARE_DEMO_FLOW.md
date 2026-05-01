# AI Firmware Demo Flow

Bu dokuman, kart demosunda CPU firmware'in AI adasini nasil kullanacagini
sabitler. Hedef: UART1'den gelen feature payload'u AI_MEM'e yazmak, AI
hizlandiriciyi baslatmak, IRQ/done beklemek ve sonucu UART0'dan yazdirmak.

## Bellek ve Registerlar

```text
AI_CSR_BASE      = 0x1000_6000
AI_MEM_BASE      = 0x2000_0000
AI_INPUT_OFFSET  = 0x0000
AI_OUTPUT_OFFSET = 0x7000
AI_INPUT_LEN     = 1960
AI_IRQ_FAST_BIT  = 19
```

CSR registerlari:

```text
0x00 ID
0x04 CTRL
0x08 STATUS
0x0c INPUT_BASE
0x10 INPUT_LEN
0x14 OUTPUT_BASE
0x18 RESULT_CLASS
0x1c SCORE0
0x20 SCORE1
0x24 SCORE2
0x28 SCORE3
0x2c CYCLE_COUNT
0x34 UART_BAUD
0x38 UART_COUNT
```

`CTRL` bitleri:

```text
bit0 accel_start pulse
bit1 irq_enable
bit2 uart_start pulse
bit3 clear_done_irq
```

`STATUS` bitleri:

```text
bit0 accel_busy
bit1 accel_done
bit2 irq_pending
bit3 uart_active
bit4 uart_done
bit5 uart_error
bit6 model_present
bit7 ai_mem_present
```

## Demo Modu A: Raw AI_UART Loader

Bu mod en az firmware ister. PC UART1'e yalnizca 1960 byte feature payload
gonderir.

Akis:

1. `INPUT_BASE = AI_MEM_BASE`
2. `INPUT_LEN = 1960`
3. `OUTPUT_BASE = AI_MEM_BASE + 0x7000`
4. `UART_BAUD` ayarla
5. `CTRL.clear_done_irq = 1`
6. `CTRL.uart_start = 1`
7. `STATUS.uart_done` bekle
8. `CTRL.clear_done_irq = 1`
9. `CTRL.accel_start = 1` ve gerekirse `irq_enable = 1`
10. `STATUS.accel_done` veya AI IRQ bekle
11. `RESULT_CLASS/SCORE0..3/CYCLE_COUNT` oku
12. UART0'dan sonucu yazdir

Bu modda checksum yoktur. Basit bring-up ve test icin uygundur.

## Demo Modu B: Firmware Packet Parser

Bu mod daha saglam demo icindir. PC UART1'e
[AI_UART_PAYLOAD_PROTOCOL.md](./AI_UART_PAYLOAD_PROTOCOL.md#L1) formatindaki
paketi gonderir.

Firmware:

1. Header oku ve `magic/version/type/header_size` kontrol et.
2. `payload_len == 1960` kontrol et.
3. Payload'u oku.
4. CRC32 dogrula.
5. Payload'u `AI_MEM_BASE` adresine yaz.
6. Accelerator'u `AI_CSR` uzerinden baslat.
7. IRQ/done bekle.
8. Sonucu UART0'a yaz.

Bu modda `soc_ai_uart_loader` raw donanim loader'i kullanilmaz; UART1 RX'i CPU
firmware tarafindan tuketilir.

## UART0 Result Format Onerisi

ASCII cikis yeterli:

```text
AI_RESULT class=<0..3> label=<silence|unknown|yes|no> scores=<s0,s1,s2,s3> cycles=<n>
```

Bu format demo paneli veya terminal tarafinda kolay parse edilir.

## Reference Pseudocode

Detayli C-benzeri referans icin:

```text
soc/firmware/ai_demo_flow.c
```

Bu dosya su an build edilen firmware degil; firmware yazilirken kullanilacak
referans akis iskeletidir.
