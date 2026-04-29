# AI Runtime Contract

Bu dosya, gercek `.tflite` modeli gelmeden once AI adasinin CPU, loader,
accelerator ve testbench tarafinda ayni veri sozlesmesini kullanmasi icin
tutulur. Model agirliklari degisse bile bu runtime akisi korunmalidir.

## Bellek Penceresi

`AI_MEM` base adresi:

```text
0x2000_0000
```

`AI_MEM` decode window boyutu `32 KB`, gercek implemented alan `30 KB` olarak
kullanilir.

## Varsayilan Buffer Yerlesimi

| Offset | Boyut | Anlam |
|---:|---:|---|
| `0x0000` | `1960 B` | `49x40` int8 input feature vector |
| `0x7000` | `4 B` | result class, unsigned low 2 bit |
| `0x7004` | `4 B` | signed score/logit 0 |
| `0x7008` | `4 B` | signed score/logit 1 |
| `0x700c` | `4 B` | signed score/logit 2 |
| `0x7010` | `4 B` | signed score/logit 3 |

Notlar:

- Input byte sirasi row-major `input[y][x]` seklindedir.
- Accelerator input'u byte olarak okur; 32-bit word icindeki lane adresin
  `addr[1:0]` degeriyle secilir.
- Output kelimeleri little-endian AXI-Lite yazimlariyla `AI_MEM`e yazilir.
- Simdilik softmax sonucu degil, argmax ve ham skor/logit degerleri raporlanir.

## CSR Akisi

`AI_CSR` base adresi:

```text
0x1000_6000
```

Varsayilan firmware/test akisi:

1. `INPUT_BASE` registerina `0x2000_0000` yaz.
2. `INPUT_LEN` registerina `1960` yaz.
3. `OUTPUT_BASE` registerina `0x2000_7000` yaz.
4. Gerekirse `CTRL[3]` veya `IRQ_CLEAR` ile onceki done/irq durumunu temizle.
5. `CTRL[1]` ile IRQ enable sec.
6. `CTRL[0]` ile accelerator start pulse uret.
7. `STATUS[1] == done` veya `STATUS[2] == irq` olana kadar bekle.
8. `RESULT_CLASS`, `RESULT0..3` ve `CYCLE_COUNT` registerlarini oku.

## UART Loader Akisi

`AI_UART loader`, UART1 RX hattindan gelen byte stream'i `AI_MEM` icine yazar.
Varsayilan hedef, input buffer baslangici olan `0x2000_0000` adresidir.

Firmware/test akisi:

1. `INPUT_BASE = 0x2000_0000`
2. `INPUT_LEN = 1960`
3. `UART_BAUD` registerini secili sim/kart hizina gore ayarla.
4. `CTRL[2]` ile UART loader start pulse uret.
5. `STATUS[4] == uart_done` veya `STATUS[5] == uart_error` durumunu izle.

## Model Kontrati

Mevcut accelerator hedef sekli:

```text
input:       49 x 40 int8
depthwise:   10 x 8 kernel, 8 channel, stride 2, SAME padding
activation: ReLU / quantized clamp
flatten:    25 x 20 x 8 = 4000
fc:         4000 -> 4
output:     4 skor + argmax class
```

Gercek `.tflite` modeli geldiginde beklenen generated package:

```text
soc_ai_model_pkg.sv
```

Bu package en az sunlari saglamalidir:

- `ai_dw_weight(idx)`
- `ai_dw_bias(ch)`
- `ai_dw_weight_zero_point(ch)`
- `ai_dw_requant_multiplier(ch)`
- `ai_fc_weight(idx)`
- `ai_fc_bias(class)`
- `ai_fc_weight_zero_point(class)`
- `ai_fc_requant_multiplier(class)`
- input/depthwise/output zero-point sabitleri
- `AI_REQUANT_SHIFT`

Package modunda RTL yolu su quantized akisi kullanir:

```text
depthwise_acc -> requantize -> ReLU clamp -> int8 feature
fc_acc        -> requantize -> int8 score/logit
```

`AI_REQUANT_SHIFT` ve multiplier degerleri exporter tarafinda uretilen fixed-point
yaklasimdir. TFLite golden dosyalari nihai sign-off referansi olarak kalir.

Gercek model gelmeden once sentetik package ayni arayuzle kullanilir. Boylece
RTL, testbench ve firmware akisi model dosyasi degistiginde yeniden mimari
degisiklik istemez.

## Golden Test Beklentisi

Modul seviyesi AI testi su zinciri dogrulamalidir:

```text
generated/synthetic model package
  -> AI_MEM input bytes
  -> soc_ai_tinyconv_accel
  -> AI_MEM output words
  -> Python/TFLite golden class ve skor karsilastirmasi
```

Ilk kabul kriteri argmax class eslesmesidir. Requantization tamamlandikca skor
eslesmesi de bit-level veya toleransli karsilastirma seviyesine cekilmelidir.

Mevcut hizli smoke hedefi `ai-accel-model-smoke`, ayni generated model
package'i reduced-size bir input/shape ile kosar. Bu, Icarus regresyonunu hizli
tutmak icindir; exporter full-shape RTL golden dosyalarini da uretir. Sentetik
smoke, offset/requantization yolunu gercekten kapsamak icin non-zero input,
output ve weight zero-point degerleri kullanir.

`ai-island-e2e-smoke` hedefi, CPU yerine AXI-Lite test task'lari kullanarak
`AI_MEM input -> AI_CSR start -> accelerator done/IRQ -> CSR ve AI_MEM output`
akisini birlikte dogrular.

`ai-uart-to-accel-e2e-smoke` hedefi ayni island testini UART loader modu ile
derler ve `UART RX -> AI_MEM -> AI_CSR start -> accelerator done/IRQ -> result`
akisini kapsar.
