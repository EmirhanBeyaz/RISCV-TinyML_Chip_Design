# AI UART Payload Protocol

Bu dokuman, PC -> SoC AI demo yolunda kullanilacak UART veri formatini sabitler.

## Iki Mod

### 1. Raw Loader Modu

Mevcut `soc_ai_uart_loader` donanim blogu raw byte stream bekler:

```text
1960 byte feature payload
```

Bu modda baslik, length veya checksum yoktur. `AI_CSR.INPUT_LEN = 1960`
yazildiktan sonra `CTRL[2] uart_start` verilir ve loader gelen 1960 byte'i
dogrudan `AI_MEM` input buffer'ina yazar.

Kullanim:

```text
*.bin -> UART1 -> AI_UART loader -> AI_MEM
```

### 2. Firmware Packet Modu

Final demo icin onerilen daha guvenli format budur. Bu formatta UART verisini
CPU firmware okur, dogrular, sonra payload kismini `AI_MEM`e yazar.

Packet layout little-endian:

| Offset | Boyut | Alan |
|---:|---:|---|
| `0x00` | 4 | magic: `43 44 41 49` (`"CDAI"`) |
| `0x04` | 1 | version: `1` |
| `0x05` | 1 | message type: `1` = feature payload |
| `0x06` | 2 | header size: `16` |
| `0x08` | 4 | payload length, default `1960` |
| `0x0c` | 4 | CRC32 over payload bytes |
| `0x10` | N | payload bytes |

Bu formatin amaci:

- yanlis uzunluk yakalama
- bozuk UART aktarimini yakalama
- ileride farkli mesaj tipleri ekleyebilme

## Host Tool

Demo payload dosyasini packet haline getirmek:

```bash
make -C soc AI_PYTHON=../.venv/bin/python ai-uart-packet-demo
```

Uretilen dosyalar:

```text
soc/build/ai_uart_packet/demo_silence_uart_packet.bin
soc/build/ai_uart_packet/demo_silence_uart_packet.json
```

## Firmware Akisi

Firmware packet modunda beklenen akış:

1. UART1'den 16 byte header oku.
2. Magic/version/type/header size kontrol et.
3. `payload_len` kadar byte oku.
4. CRC32 dogrula.
5. Payload'u `AI_MEM + 0x0000` adresine yaz.
6. `AI_CSR.INPUT_BASE = 0x2000_0000`
7. `AI_CSR.INPUT_LEN = 1960`
8. `AI_CSR.OUTPUT_BASE = 0x2000_7000`
9. `AI_CSR.CTRL.start = 1`
10. AI IRQ veya done bekle.
11. Result class/skorlarini oku ve UART0'a yaz.

## Karar

- Simulasyon ve basit kart bring-up icin raw loader modu korunur.
- Juri/demo firmware'i icin packet modu tercih edilir.
