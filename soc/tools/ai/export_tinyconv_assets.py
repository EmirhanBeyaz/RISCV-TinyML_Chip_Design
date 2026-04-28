#!/usr/bin/env python3
"""Export TinyConv speech-model assets for RTL integration.

The hardware target is the model shape from the competition spec:

  1960 int8 input samples -> 49x40x1
  DepthwiseConv2D 10x8, depth multiplier 8, stride 2, SAME padding
  ReLU, flatten 4000
  FullyConnected 4000 -> 4

The script supports two flows:

* `--model-tflite`: extract constants and TFLite golden outputs when a
  TensorFlow Lite interpreter is installed.
* `--model-npz`: consume a normalized asset dump and produce RTL-friendly
  package/golden files without TensorFlow.
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import numpy as np


INPUT_H = 49
INPUT_W = 40
INPUT_SIZE = INPUT_H * INPUT_W
OUT_H = 25
OUT_W = 20
CHANNELS = 8
K_H = 10
K_W = 8
PAD_H = 4
PAD_W = 3
STRIDE = 2
CLASSES = 4
FLAT_SIZE = OUT_H * OUT_W * CHANNELS
LABELS = ("silence", "unknown", "yes", "no")


@dataclass(frozen=True)
class TinyConvAssets:
    dw_weight: np.ndarray
    dw_bias: np.ndarray
    fc_weight: np.ndarray
    fc_bias: np.ndarray
    input_scale: np.ndarray
    input_zero_point: np.ndarray
    dw_weight_scale: np.ndarray
    dw_weight_zero_point: np.ndarray
    dw_output_scale: np.ndarray
    dw_output_zero_point: np.ndarray
    fc_weight_scale: np.ndarray
    fc_weight_zero_point: np.ndarray
    output_scale: np.ndarray
    output_zero_point: np.ndarray
    labels: tuple[str, ...] = LABELS


@dataclass(frozen=True)
class ReferenceResult:
    depthwise_output: np.ndarray
    logits: np.ndarray
    result_class: int


def _scalar_array(value: Any, dtype: Any) -> np.ndarray:
    return np.asarray(value, dtype=dtype).reshape(())


def _optional_array(data: dict[str, np.ndarray], key: str, default: Any, dtype: Any) -> np.ndarray:
    if key not in data:
        return _scalar_array(default, dtype)
    return np.asarray(data[key], dtype=dtype)


def _optional_labels(data: dict[str, np.ndarray]) -> tuple[str, ...]:
    if "labels" not in data:
        return LABELS
    values = [str(x.decode() if isinstance(x, bytes) else x) for x in data["labels"].reshape(-1)]
    if len(values) != CLASSES:
        raise ValueError(f"labels must contain {CLASSES} entries, got {len(values)}")
    return tuple(values)


def _normalize_depthwise_weight(arr: np.ndarray) -> np.ndarray:
    arr = np.asarray(arr)
    if arr.shape == (K_H, K_W, CHANNELS):
        return arr.astype(np.int8)
    if arr.shape == (1, K_H, K_W, CHANNELS):
        return arr.reshape(K_H, K_W, CHANNELS).astype(np.int8)
    if arr.shape == (K_H, K_W, 1, CHANNELS):
        return arr[:, :, 0, :].astype(np.int8)
    if arr.size == K_H * K_W * CHANNELS:
        return arr.reshape(K_H, K_W, CHANNELS).astype(np.int8)
    raise ValueError(f"depthwise weight shape {arr.shape} is not compatible with 10x8x8")


def _normalize_fc_weight(arr: np.ndarray) -> np.ndarray:
    arr = np.asarray(arr)
    if arr.shape == (CLASSES, FLAT_SIZE):
        return arr.astype(np.int8)
    if arr.shape == (FLAT_SIZE, CLASSES):
        return arr.T.astype(np.int8)
    if arr.size == CLASSES * FLAT_SIZE:
        reshaped = arr.reshape(CLASSES, FLAT_SIZE)
        return reshaped.astype(np.int8)
    raise ValueError(f"FC weight shape {arr.shape} is not compatible with 4x4000")


def load_npz_assets(path: Path) -> TinyConvAssets:
    with np.load(path, allow_pickle=False) as loaded:
        data = {key: loaded[key] for key in loaded.files}

    required = ("dw_weight", "dw_bias", "fc_weight", "fc_bias")
    missing = [key for key in required if key not in data]
    if missing:
        raise ValueError(f"{path} is missing required arrays: {', '.join(missing)}")

    assets = TinyConvAssets(
        dw_weight=_normalize_depthwise_weight(data["dw_weight"]),
        dw_bias=np.asarray(data["dw_bias"], dtype=np.int32).reshape(CHANNELS),
        fc_weight=_normalize_fc_weight(data["fc_weight"]),
        fc_bias=np.asarray(data["fc_bias"], dtype=np.int32).reshape(CLASSES),
        input_scale=_optional_array(data, "input_scale", 1.0, np.float64),
        input_zero_point=_optional_array(data, "input_zero_point", 0, np.int32),
        dw_weight_scale=_optional_array(data, "dw_weight_scale", 1.0, np.float64),
        dw_weight_zero_point=_optional_array(data, "dw_weight_zero_point", 0, np.int32),
        dw_output_scale=_optional_array(data, "dw_output_scale", 1.0, np.float64),
        dw_output_zero_point=_optional_array(data, "dw_output_zero_point", 0, np.int32),
        fc_weight_scale=_optional_array(data, "fc_weight_scale", 1.0, np.float64),
        fc_weight_zero_point=_optional_array(data, "fc_weight_zero_point", 0, np.int32),
        output_scale=_optional_array(data, "output_scale", 1.0, np.float64),
        output_zero_point=_optional_array(data, "output_zero_point", 0, np.int32),
        labels=_optional_labels(data),
    )
    validate_assets(assets)
    return assets


def validate_assets(assets: TinyConvAssets) -> None:
    checks = (
        (assets.dw_weight.shape, (K_H, K_W, CHANNELS), "dw_weight"),
        (assets.dw_bias.shape, (CHANNELS,), "dw_bias"),
        (assets.fc_weight.shape, (CLASSES, FLAT_SIZE), "fc_weight"),
        (assets.fc_bias.shape, (CLASSES,), "fc_bias"),
    )
    for got, expected, name in checks:
        if got != expected:
            raise ValueError(f"{name} shape must be {expected}, got {got}")
    if len(assets.labels) != CLASSES:
        raise ValueError(f"labels must contain {CLASSES} entries")


def save_assets_npz(assets: TinyConvAssets, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    np.savez_compressed(
        path,
        dw_weight=assets.dw_weight,
        dw_bias=assets.dw_bias,
        fc_weight=assets.fc_weight,
        fc_bias=assets.fc_bias,
        input_scale=assets.input_scale,
        input_zero_point=assets.input_zero_point,
        dw_weight_scale=assets.dw_weight_scale,
        dw_weight_zero_point=assets.dw_weight_zero_point,
        dw_output_scale=assets.dw_output_scale,
        dw_output_zero_point=assets.dw_output_zero_point,
        fc_weight_scale=assets.fc_weight_scale,
        fc_weight_zero_point=assets.fc_weight_zero_point,
        output_scale=assets.output_scale,
        output_zero_point=assets.output_zero_point,
        labels=np.asarray(assets.labels, dtype="S"),
    )


def _pick_scale(scale: np.ndarray, idx: int) -> float:
    flat = np.asarray(scale, dtype=np.float64).reshape(-1)
    if flat.size == 1:
        return float(flat[0])
    if idx >= flat.size:
        raise ValueError(f"quant scale index {idx} out of range for shape {scale.shape}")
    return float(flat[idx])


def _pick_zp(zero_point: np.ndarray, idx: int) -> int:
    flat = np.asarray(zero_point, dtype=np.int32).reshape(-1)
    if flat.size == 1:
        return int(flat[0])
    if idx >= flat.size:
        raise ValueError(f"quant zero-point index {idx} out of range for shape {zero_point.shape}")
    return int(flat[idx])


def _requantize(acc: int, src_scale: float, weight_scale: float, dst_scale: float, dst_zp: int) -> int:
    if dst_scale == 0.0:
        raise ValueError("destination quantization scale must be non-zero")
    real_value = float(acc) * src_scale * weight_scale / dst_scale
    return int(np.rint(real_value + float(dst_zp)))


def run_numpy_reference(assets: TinyConvAssets, input_vector: np.ndarray) -> ReferenceResult:
    validate_assets(assets)
    vector = np.asarray(input_vector).reshape(-1)
    if vector.size != INPUT_SIZE:
        raise ValueError(f"input vector must have {INPUT_SIZE} elements, got {vector.size}")
    inp = vector.astype(np.int32).reshape(INPUT_H, INPUT_W)

    input_zp = _pick_zp(assets.input_zero_point, 0)
    input_scale = _pick_scale(assets.input_scale, 0)
    dw_out_zp = _pick_zp(assets.dw_output_zero_point, 0)
    dw_out_scale = _pick_scale(assets.dw_output_scale, 0)
    depthwise = np.zeros((OUT_H, OUT_W, CHANNELS), dtype=np.int8)

    for oh in range(OUT_H):
        for ow in range(OUT_W):
            for ch in range(CHANNELS):
                acc = int(assets.dw_bias[ch])
                weight_zp = _pick_zp(assets.dw_weight_zero_point, ch)
                weight_scale = _pick_scale(assets.dw_weight_scale, ch)
                for kh in range(K_H):
                    in_y = oh * STRIDE + kh - PAD_H
                    if in_y < 0 or in_y >= INPUT_H:
                        continue
                    for kw in range(K_W):
                        in_x = ow * STRIDE + kw - PAD_W
                        if in_x < 0 or in_x >= INPUT_W:
                            continue
                        sample = int(inp[in_y, in_x]) - input_zp
                        weight = int(assets.dw_weight[kh, kw, ch]) - weight_zp
                        acc += sample * weight
                q = _requantize(acc, input_scale, weight_scale, dw_out_scale, dw_out_zp)
                q = max(q, dw_out_zp)
                depthwise[oh, ow, ch] = np.clip(q, -128, 127)

    flat = depthwise.reshape(FLAT_SIZE).astype(np.int32)
    logits = np.zeros((CLASSES,), dtype=np.int8)
    for cls in range(CLASSES):
        acc = int(assets.fc_bias[cls])
        weight_zp = _pick_zp(assets.fc_weight_zero_point, cls)
        weight_scale = _pick_scale(assets.fc_weight_scale, cls)
        for idx in range(FLAT_SIZE):
            acc += (int(flat[idx]) - dw_out_zp) * (int(assets.fc_weight[cls, idx]) - weight_zp)
        out_zp = _pick_zp(assets.output_zero_point, 0)
        out_scale = _pick_scale(assets.output_scale, 0)
        q = _requantize(acc, dw_out_scale, weight_scale, out_scale, out_zp)
        logits[cls] = np.clip(q, -128, 127)

    return ReferenceResult(
        depthwise_output=depthwise,
        logits=logits,
        result_class=int(np.argmax(logits.astype(np.int32))),
    )


def _get_interpreter_class() -> Any:
    try:
        import tensorflow as tf  # type: ignore

        return tf.lite.Interpreter
    except Exception:
        pass

    try:
        from tflite_runtime.interpreter import Interpreter  # type: ignore

        return Interpreter
    except Exception as exc:
        raise RuntimeError(
            "No TensorFlow Lite interpreter is installed. Install either tensorflow "
            "or tflite-runtime, or use --model-npz with a pre-extracted asset dump."
        ) from exc


def _make_interpreter(interpreter_cls: Any, path: Path) -> Any:
    try:
        return interpreter_cls(model_path=str(path), experimental_preserve_all_tensors=True)
    except TypeError:
        return interpreter_cls(model_path=str(path))


def _tensor_value(interpreter: Any, detail: dict[str, Any]) -> np.ndarray | None:
    try:
        return np.asarray(interpreter.get_tensor(detail["index"]))
    except Exception:
        return None


def _quant(detail: dict[str, Any]) -> tuple[np.ndarray, np.ndarray]:
    params = detail.get("quantization_parameters", {})
    scales = np.asarray(params.get("scales", []), dtype=np.float64)
    zps = np.asarray(params.get("zero_points", []), dtype=np.int32)
    if scales.size == 0:
        scales = _scalar_array(1.0, np.float64)
    if zps.size == 0:
        zps = _scalar_array(0, np.int32)
    return scales, zps


def _score_name(detail: dict[str, Any], needle: str) -> int:
    return 1 if needle.lower() in str(detail.get("name", "")).lower() else 0


def _find_tensor(
    details: list[dict[str, Any]],
    interpreter: Any,
    predicate: Any,
    label: str,
    name_hint: str | None = None,
) -> tuple[dict[str, Any], np.ndarray]:
    candidates: list[tuple[int, dict[str, Any], np.ndarray]] = []
    for detail in details:
        value = _tensor_value(interpreter, detail)
        if value is None:
            continue
        if predicate(value):
            score = _score_name(detail, name_hint) if name_hint else 0
            candidates.append((score, detail, value))
    if not candidates:
        raise ValueError(f"could not find TFLite tensor for {label}")
    candidates.sort(key=lambda item: item[0], reverse=True)
    _, detail, value = candidates[0]
    return detail, value


def _find_tensor_detail(
    details: list[dict[str, Any]],
    predicate: Any,
    label: str,
    name_hint: str | None = None,
) -> dict[str, Any]:
    candidates: list[tuple[int, dict[str, Any]]] = []
    for detail in details:
        if predicate(detail):
            score = _score_name(detail, name_hint) if name_hint else 0
            candidates.append((score, detail))
    if not candidates:
        raise ValueError(f"could not find TFLite tensor for {label}")
    candidates.sort(key=lambda item: item[0], reverse=True)
    return candidates[0][1]


def load_tflite_assets(path: Path) -> tuple[TinyConvAssets, Any, dict[str, int]]:
    interpreter_cls = _get_interpreter_class()
    interpreter = _make_interpreter(interpreter_cls, path)
    interpreter.allocate_tensors()
    details = interpreter.get_tensor_details()
    inputs = interpreter.get_input_details()
    outputs = interpreter.get_output_details()
    if len(inputs) != 1 or len(outputs) != 1:
        raise ValueError("expected a single-input, single-output TinyConv model")

    dw_detail, dw_raw = _find_tensor(
        details,
        interpreter,
        lambda arr: arr.dtype in (np.dtype("int8"), np.dtype("uint8")) and arr.size == K_H * K_W * CHANNELS,
        "depthwise weights",
        "depthwise",
    )
    fc_detail, fc_raw = _find_tensor(
        details,
        interpreter,
        lambda arr: arr.dtype in (np.dtype("int8"), np.dtype("uint8")) and arr.size == CLASSES * FLAT_SIZE,
        "fully-connected weights",
        "fully",
    )
    dw_bias_detail, dw_bias_raw = _find_tensor(
        details,
        interpreter,
        lambda arr: arr.dtype == np.dtype("int32") and arr.size == CHANNELS,
        "depthwise bias",
        "depthwise",
    )
    fc_bias_detail, fc_bias_raw = _find_tensor(
        details,
        interpreter,
        lambda arr: arr.dtype == np.dtype("int32") and arr.size == CLASSES,
        "fully-connected bias",
        "fully",
    )

    dw_output_detail = _find_tensor_detail(
        details,
        lambda detail: detail["dtype"] in (np.dtype("int8"), np.dtype("uint8"))
        and int(np.prod(detail["shape"])) == FLAT_SIZE
        and set((OUT_H, OUT_W, CHANNELS)).issubset(set(int(x) for x in detail["shape"])),
        "depthwise output activation",
        "depthwise",
    )

    input_scale, input_zp = _quant(inputs[0])
    dw_weight_scale, dw_weight_zp = _quant(dw_detail)
    dw_output_scale, dw_output_zp = _quant(dw_output_detail)
    fc_weight_scale, fc_weight_zp = _quant(fc_detail)
    output_scale, output_zp = _quant(outputs[0])

    assets = TinyConvAssets(
        dw_weight=_normalize_depthwise_weight(dw_raw),
        dw_bias=np.asarray(dw_bias_raw, dtype=np.int32).reshape(CHANNELS),
        fc_weight=_normalize_fc_weight(fc_raw),
        fc_bias=np.asarray(fc_bias_raw, dtype=np.int32).reshape(CLASSES),
        input_scale=input_scale,
        input_zero_point=input_zp,
        dw_weight_scale=dw_weight_scale,
        dw_weight_zero_point=dw_weight_zp,
        dw_output_scale=dw_output_scale,
        dw_output_zero_point=dw_output_zp,
        fc_weight_scale=fc_weight_scale,
        fc_weight_zero_point=fc_weight_zp,
        output_scale=output_scale,
        output_zero_point=output_zp,
        labels=LABELS,
    )
    validate_assets(assets)
    tensor_indices = {
        "input": int(inputs[0]["index"]),
        "output": int(outputs[0]["index"]),
        "depthwise_output": int(dw_output_detail["index"]),
    }
    return assets, interpreter, tensor_indices


def run_tflite_golden(
    interpreter: Any,
    tensor_indices: dict[str, int],
    input_vector: np.ndarray,
    out_dir: Path,
) -> None:
    input_detail = interpreter.get_input_details()[0]
    input_shape = tuple(int(x) for x in input_detail["shape"])
    input_dtype = input_detail["dtype"]
    value = np.asarray(input_vector).reshape(input_shape).astype(input_dtype)
    interpreter.set_tensor(tensor_indices["input"], value)
    interpreter.invoke()

    tflite_output = np.asarray(interpreter.get_tensor(tensor_indices["output"]))
    try:
        depthwise_output = np.asarray(interpreter.get_tensor(tensor_indices["depthwise_output"]))
    except Exception as exc:
        depthwise_output = None
        (out_dir / "tflite_depthwise_output_unavailable.txt").write_text(
            f"{type(exc).__name__}: {exc}\n",
            encoding="utf-8",
        )
    result_class = int(np.argmax(tflite_output.reshape(-1).astype(np.int32)))

    np.save(out_dir / "tflite_input.npy", value)
    if depthwise_output is not None:
        np.save(out_dir / "tflite_depthwise_output.npy", depthwise_output)
    np.save(out_dir / "tflite_output.npy", tflite_output)
    (out_dir / "tflite_result_class.txt").write_text(f"{result_class}\n", encoding="utf-8")


def write_reference_golden(result: ReferenceResult, out_dir: Path) -> None:
    np.save(out_dir / "ref_depthwise_output.npy", result.depthwise_output)
    np.save(out_dir / "ref_logits.npy", result.logits)
    (out_dir / "ref_result_class.txt").write_text(f"{result.result_class}\n", encoding="utf-8")


def _sv_literal(value: int, bits: int, signed: bool) -> str:
    prefix = f"{bits}'s" if signed else f"{bits}'"
    if signed and value < 0:
        return f"-{prefix}d{abs(int(value))}"
    return f"{prefix}d{int(value)}"


def _sv_array(name: str, bits: int, values: np.ndarray, signed: bool, per_line: int = 12) -> str:
    flat = np.asarray(values).reshape(-1)
    lines = [f"  localparam logic {'signed ' if signed else ''}[{bits - 1}:0] {name} [0:{flat.size - 1}] = '{{"]
    for start in range(0, flat.size, per_line):
        chunk = flat[start : start + per_line]
        suffix = "," if start + per_line < flat.size else ""
        body = ", ".join(_sv_literal(int(x), bits, signed) for x in chunk)
        lines.append(f"    {body}{suffix}")
    lines.append("  };")
    return "\n".join(lines)


def _int_scalar(value: np.ndarray) -> int:
    return int(np.asarray(value).reshape(-1)[0])


def write_sv_package(assets: TinyConvAssets, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    text = "\n".join(
        [
            "// Generated by tools/ai/export_tinyconv_assets.py",
            "// Do not edit by hand.",
            "package soc_ai_model_pkg;",
            "  localparam int AI_INPUT_H = 49;",
            "  localparam int AI_INPUT_W = 40;",
            "  localparam int AI_OUT_H = 25;",
            "  localparam int AI_OUT_W = 20;",
            "  localparam int AI_CHANNELS = 8;",
            "  localparam int AI_K_H = 10;",
            "  localparam int AI_K_W = 8;",
            "  localparam int AI_CLASSES = 4;",
            f"  localparam int AI_INPUT_ZERO_POINT = {_int_scalar(assets.input_zero_point)};",
            f"  localparam int AI_DW_OUTPUT_ZERO_POINT = {_int_scalar(assets.dw_output_zero_point)};",
            f"  localparam int AI_OUTPUT_ZERO_POINT = {_int_scalar(assets.output_zero_point)};",
            _sv_array("AI_DW_WEIGHT", 8, assets.dw_weight, signed=True),
            _sv_array("AI_DW_BIAS", 32, assets.dw_bias, signed=True, per_line=8),
            _sv_array("AI_FC_WEIGHT", 8, assets.fc_weight, signed=True),
            _sv_array("AI_FC_BIAS", 32, assets.fc_bias, signed=True, per_line=4),
            "endpackage",
            "",
        ]
    )
    path.write_text(text, encoding="utf-8")


def write_manifest(assets: TinyConvAssets, path: Path) -> None:
    manifest = {
        "shape": {
            "input": [INPUT_SIZE],
            "reshape": [INPUT_H, INPUT_W, 1],
            "depthwise_weight": list(assets.dw_weight.shape),
            "depthwise_output": [OUT_H, OUT_W, CHANNELS],
            "flatten": [FLAT_SIZE],
            "fc_weight": list(assets.fc_weight.shape),
            "classes": list(assets.labels),
        },
        "quantization": {
            "input_scale": np.asarray(assets.input_scale).reshape(-1).tolist(),
            "input_zero_point": np.asarray(assets.input_zero_point).reshape(-1).tolist(),
            "dw_weight_scale": np.asarray(assets.dw_weight_scale).reshape(-1).tolist(),
            "dw_weight_zero_point": np.asarray(assets.dw_weight_zero_point).reshape(-1).tolist(),
            "dw_output_scale": np.asarray(assets.dw_output_scale).reshape(-1).tolist(),
            "dw_output_zero_point": np.asarray(assets.dw_output_zero_point).reshape(-1).tolist(),
            "fc_weight_scale": np.asarray(assets.fc_weight_scale).reshape(-1).tolist(),
            "fc_weight_zero_point": np.asarray(assets.fc_weight_zero_point).reshape(-1).tolist(),
            "output_scale": np.asarray(assets.output_scale).reshape(-1).tolist(),
            "output_zero_point": np.asarray(assets.output_zero_point).reshape(-1).tolist(),
        },
    }
    path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def synthetic_assets() -> tuple[TinyConvAssets, np.ndarray]:
    rng = np.random.default_rng(2026)
    assets = TinyConvAssets(
        dw_weight=rng.integers(-3, 4, size=(K_H, K_W, CHANNELS), dtype=np.int8),
        dw_bias=rng.integers(-200, 200, size=(CHANNELS,), dtype=np.int32),
        fc_weight=rng.integers(-2, 3, size=(CLASSES, FLAT_SIZE), dtype=np.int8),
        fc_bias=rng.integers(-1000, 1000, size=(CLASSES,), dtype=np.int32),
        input_scale=_scalar_array(1.0 / 64.0, np.float64),
        input_zero_point=_scalar_array(0, np.int32),
        dw_weight_scale=np.full((CHANNELS,), 1.0 / 32.0, dtype=np.float64),
        dw_weight_zero_point=np.zeros((CHANNELS,), dtype=np.int32),
        dw_output_scale=_scalar_array(1.0 / 32.0, np.float64),
        dw_output_zero_point=_scalar_array(-128, np.int32),
        fc_weight_scale=np.full((CLASSES,), 1.0 / 64.0, dtype=np.float64),
        fc_weight_zero_point=np.zeros((CLASSES,), dtype=np.int32),
        output_scale=_scalar_array(1.0 / 16.0, np.float64),
        output_zero_point=_scalar_array(0, np.int32),
        labels=LABELS,
    )
    input_vector = rng.integers(-128, 128, size=(INPUT_SIZE,), dtype=np.int8)
    return assets, input_vector


def run_self_test(out_dir: Path, sv_out: Path | None) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    assets, input_vector = synthetic_assets()
    save_assets_npz(assets, out_dir / "tinyconv_assets.npz")
    np.save(out_dir / "input_vector.npy", input_vector)
    result = run_numpy_reference(assets, input_vector)
    write_reference_golden(result, out_dir)
    write_manifest(assets, out_dir / "manifest.json")
    if sv_out is not None:
        write_sv_package(assets, sv_out)
    print(f"ai-model-tool-smoke: PASS, class={result.result_class} ({assets.labels[result.result_class]})")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group()
    source.add_argument("--model-tflite", type=Path, help="quantized TinyConv .tflite model")
    source.add_argument("--model-npz", type=Path, help="normalized asset dump")
    parser.add_argument("--input-npy", type=Path, help="1960-element int8 input vector for golden generation")
    parser.add_argument("--out-dir", type=Path, required=True, help="output directory")
    parser.add_argument("--sv-out", type=Path, help="SystemVerilog package output path")
    parser.add_argument("--no-sv", action="store_true", help="skip SystemVerilog package generation")
    parser.add_argument("--self-test", action="store_true", help="run a deterministic synthetic smoke test")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    out_dir = args.out_dir
    sv_out = None if args.no_sv else args.sv_out or (out_dir / "soc_ai_model_pkg.sv")

    if args.self_test:
        run_self_test(out_dir, sv_out)
        return 0

    if args.model_tflite is None and args.model_npz is None:
        print("error: provide --model-tflite, --model-npz, or --self-test", file=sys.stderr)
        return 2

    out_dir.mkdir(parents=True, exist_ok=True)
    interpreter = None
    tensor_indices: dict[str, int] | None = None
    if args.model_tflite is not None:
        assets, interpreter, tensor_indices = load_tflite_assets(args.model_tflite)
        save_assets_npz(assets, out_dir / "tinyconv_assets.npz")
    else:
        assets = load_npz_assets(args.model_npz)
        save_assets_npz(assets, out_dir / "tinyconv_assets.npz")

    write_manifest(assets, out_dir / "manifest.json")
    if sv_out is not None:
        write_sv_package(assets, sv_out)

    if args.input_npy is not None:
        input_vector = np.load(args.input_npy)
        if interpreter is not None and tensor_indices is not None:
            run_tflite_golden(interpreter, tensor_indices, input_vector, out_dir)
        reference = run_numpy_reference(assets, input_vector)
        write_reference_golden(reference, out_dir)
        print(f"reference class={reference.result_class} ({assets.labels[reference.result_class]})")

    print(f"wrote assets to {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
