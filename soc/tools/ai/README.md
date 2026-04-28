# TinyConv AI Model Tooling

This directory contains the extraction/golden path for the AI accelerator.

## What It Produces

`export_tinyconv_assets.py` validates the competition model shape and emits:

- `tinyconv_assets.npz`: normalized weights, biases, quantization values, labels.
- `manifest.json`: shape and quantization summary.
- `soc_ai_model_pkg.sv`: generated SystemVerilog package for the next RTL phase.
- `ref_depthwise_output.npy`, `ref_logits.npy`, `ref_result_class.txt`: NumPy reference goldens when an input vector is provided.
- `tflite_*` golden files when a `.tflite` model is used with TensorFlow Lite installed.

## Smoke Test

From `soc/`:

```sh
make ai-model-tool-smoke
```

This uses deterministic synthetic weights to verify the tool path without requiring TensorFlow.

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
