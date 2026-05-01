# TinyConv AI Model Tooling

This directory contains the extraction/golden path for the AI accelerator.

## What It Produces

`export_tinyconv_assets.py` validates the competition model shape and emits:

- `tinyconv_assets.npz`: normalized weights, biases, quantization values, labels.
- `manifest.json`: shape and quantization summary.
- `soc_ai_model_pkg.sv`: generated SystemVerilog package with weights, biases,
  zero-points and fixed-point requantization parameters.
- `soc_ai_model_smoke_golden_pkg.sv`, `smoke_input_vector.memh`,
  `smoke_rtl_scores.npy`, `smoke_rtl_result_class.txt`: reduced-size current
  RTL-datapath goldens for fast package-based smoke tests.
- `soc_ai_model_golden_pkg.sv`, `input_vector.memh`, `rtl_scores.npy`,
  `rtl_result_class.txt`: full-shape current RTL-datapath goldens.
- `ref_depthwise_output.npy`, `ref_logits.npy`, `ref_result_class.txt`: NumPy reference goldens when an input vector is provided.
- `tflite_*` golden files when a `.tflite` model is used with TensorFlow Lite installed.

## Smoke Test

From `soc/`:

```sh
make ai-model-tool-smoke
```

This uses deterministic synthetic weights to verify the tool path without requiring TensorFlow.
It still requires NumPy because the asset/golden path is NumPy-based.
When NumPy is available, the generated synthetic package can also be compiled
through a reduced-size accelerator smoke path. This compares the RTL output
against generated synthetic RTL golden files while keeping Icarus runs quick:

```sh
make ai-accel-model-smoke
```

The synthetic smoke intentionally uses non-zero input, output, and weight
zero-points so the RTL offset/requantization path is exercised before the real
`.tflite` model is available.

The CSR/MEM/accelerator path can be checked together with:

```sh
make ai-island-e2e-smoke
```

The UART loader can also be included in that path, covering
UART RX -> AI_MEM -> CSR start -> accelerator result:

```sh
make ai-uart-to-accel-e2e-smoke
```

After installing TensorFlow, the `.tflite` extraction path can be tested with a generated TinyConv model:

```sh
make AI_PYTHON=../.venv-ai/bin/python ai-model-tflite-smoke
```

## Official TFLite Micro Micro Speech Flow

The project does not vendor the full TensorFlow Lite Micro repository. Instead,
it can fetch the small official Micro Speech reference assets into `build/`:

```sh
make AI_PYTHON=../.venv-ai/bin/python ai-model-tflm-fetch
```

Then export the official quantized Micro Speech model into the RTL package
format used by `soc_ai_tinyconv_accel`:

```sh
make AI_PYTHON=../.venv-ai/bin/python ai-model-tflm-export
```

Compile and run the accelerator datapath with the official model package using
the reduced fast smoke shape:

```sh
make AI_PYTHON=../.venv-ai/bin/python ai-accel-tflm-smoke
```

Check the same official model package through the integrated AI island path
(`AI_MEM -> AI_CSR -> accelerator -> IRQ/result`):

```sh
make AI_PYTHON=../.venv-ai/bin/python ai-island-tflm-smoke
```

Or run the full official-model fetch/export/accelerator smoke chain:

```sh
make AI_PYTHON=../.venv-ai/bin/python ai-tflm-smoke
```

The full `49x40` accelerator datapath can be checked separately. This is kept
out of daily `full` because it is intentionally slower:

```sh
make AI_PYTHON=../.venv-ai/bin/python ai-accel-tflm-full-smoke
```

Outputs are written under:

```text
build/tflm_micro_speech/
build/ai_model_tflm_micro_speech/
```

The official model still expects a precomputed `49x40` int8 feature tensor.
Raw audio preprocessing is intentionally outside the V1 RTL accelerator.

## Feature Payloads

The accelerator input is always a `49x40 = 1960 byte` int8 tensor. For demos
and UART loading, prepare this payload explicitly:

```sh
make AI_PYTHON=../.venv-ai/bin/python ai-feature-payload-demo
```

This writes:

```text
build/ai_feature_payload/demo_silence_1960_int8.npy
build/ai_feature_payload/demo_silence_1960_int8.memh
build/ai_feature_payload/demo_silence_1960_int8.bin
```

- `.npy` is for Python/TFLite golden generation.
- `.memh` is for simulation/testbench loading.
- `.bin` is the 1960-byte UART payload for a board-side loader.

The firmware packet format can be generated with:

```sh
make AI_PYTHON=../.venv-ai/bin/python ai-uart-packet-demo
```

See `soc/AI_UART_PAYLOAD_PROTOCOL.md` for the raw-loader and firmware-packet
formats.

To validate/export a real precomputed feature tensor:

```sh
../.venv-ai/bin/python tools/ai/prepare_feature_payload.py \
  --input-npy path/to/input_1960_int8.npy \
  --out-dir build/ai_feature_payload \
  --name sample_yes
```

The tool also accepts `--input-memh` and `--input-bin`. It does not implement
official WAV/audio preprocessing; it only handles the tensor format consumed by
the RTL accelerator.

To run the official Micro Speech model on the demo feature tensor and emit
TFLite/NumPy goldens:

```sh
make AI_PYTHON=../.venv-ai/bin/python ai-model-tflm-demo-golden
```

## WAV Demo Path

The official TFLM audio preprocessor model uses custom Signal Library ops such
as `SignalWindow`; the stock desktop TensorFlow Lite interpreter cannot execute
that model directly. Until the custom-op runtime is integrated, a lightweight
host demo preprocessor can convert a 16 kHz mono WAV into the same `49x40`
payload shape:

```sh
make AI_PYTHON=../.venv-ai/bin/python ai-wav-feature-demo
```

This fetches official Micro Speech WAV samples and writes:

```text
build/ai_wav_feature/yes_1000ms_1960_int8.npy
build/ai_wav_feature/yes_1000ms_1960_int8.memh
build/ai_wav_feature/yes_1000ms_1960_int8.bin
```

Then the official Micro Speech classifier model can be run on that demo payload:

```sh
make AI_PYTHON=../.venv-ai/bin/python ai-model-tflm-wav-demo-golden
```

This path is useful for end-to-end data movement and demo plumbing. It is not
an accuracy sign-off path because the host preprocessor is approximate, not
bit-exact TFLM Signal Library preprocessing.

## Real Model Flow

Create a local environment from the repo root when TensorFlow is needed:

```sh
python3 -m venv .venv-ai
.venv-ai/bin/python -m pip install --upgrade pip setuptools wheel tensorflow
```

Place the quantized TinyConv `.tflite` model somewhere outside generated build output, then run:

```sh
../.venv-ai/bin/python tools/ai/export_tinyconv_assets.py \
  --model-tflite path/to/model.tflite \
  --input-npy path/to/input_1960_int8.npy \
  --out-dir build/ai_model
```

The host Python environment must have either `tensorflow` or `tflite-runtime` for direct `.tflite` extraction. If that is not available, create a normalized `.npz` with these arrays and use `--model-npz`:

- `dw_weight`: `10x8x8` int8
- `dw_bias`: `8` int32
- `fc_weight`: `4x4000` int8
- `fc_bias`: `4` int32
- optional quant arrays: `input_scale`, `input_zero_point`, `dw_weight_scale`, `dw_weight_zero_point`, `dw_output_scale`, `dw_output_zero_point`, `fc_weight_scale`, `fc_weight_zero_point`, `output_scale`, `output_zero_point`

The NumPy reference is a practical local checker, but the TFLite golden files are the sign-off reference for matching the official model.
