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
