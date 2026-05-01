#!/usr/bin/env python3
"""Prepare a 49x40 int8 Micro Speech feature payload for AI_MEM loading.

This tool is a format bridge for the SoC demo path. It does not implement the
official Micro Speech audio preprocessor; it validates or creates the 1960-byte
feature tensor that the accelerator consumes.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np


INPUT_H = 49
INPUT_W = 40
INPUT_SIZE = INPUT_H * INPUT_W
DEFAULT_ZERO_POINT = -128


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _as_int8_vector(values: np.ndarray, source: str) -> np.ndarray:
    flat = np.asarray(values).reshape(-1)
    if flat.size != INPUT_SIZE:
        raise ValueError(f"{source} must contain {INPUT_SIZE} elements, got {flat.size}")

    if np.issubdtype(flat.dtype, np.unsignedinteger):
        if np.any(flat > 255):
            raise ValueError(f"{source} unsigned values must fit in one byte")
        return flat.astype(np.uint8).view(np.int8)

    as_i64 = flat.astype(np.int64)
    if np.any(as_i64 < -128) or np.any(as_i64 > 255):
        raise ValueError(f"{source} values must be int8 [-128,127] or byte [0,255]")
    if np.any(as_i64 > 127):
        return as_i64.astype(np.uint8).view(np.int8)
    return as_i64.astype(np.int8)


def read_memh(path: Path) -> np.ndarray:
    values: list[int] = []
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.split("//", 1)[0].split("#", 1)[0].strip()
        if not line:
            continue
        for token in line.replace(",", " ").split():
            token = token.lower().replace("8'h", "").replace("0x", "")
            value = int(token, 16)
            if value < 0 or value > 255:
                raise ValueError(f"{path}: memh token {token!r} is not a byte")
            values.append(value)
    return _as_int8_vector(np.asarray(values, dtype=np.uint8), str(path))


def load_payload(args: argparse.Namespace) -> tuple[np.ndarray, str]:
    if args.input_npy is not None:
        return _as_int8_vector(np.load(args.input_npy), str(args.input_npy)), str(args.input_npy)
    if args.input_memh is not None:
        return read_memh(args.input_memh), str(args.input_memh)
    if args.input_bin is not None:
        data = np.frombuffer(args.input_bin.read_bytes(), dtype=np.uint8)
        return _as_int8_vector(data, str(args.input_bin)), str(args.input_bin)
    if args.demo is not None:
        return demo_payload(args.demo, args.seed), f"demo:{args.demo}"
    raise ValueError("one input source is required")


def demo_payload(kind: str, seed: int) -> np.ndarray:
    if kind == "silence":
        return np.full((INPUT_SIZE,), DEFAULT_ZERO_POINT, dtype=np.int8)
    if kind == "ramp":
        return np.linspace(-128, 127, INPUT_SIZE, dtype=np.int16).astype(np.int8)
    if kind == "checker":
        yy, xx = np.indices((INPUT_H, INPUT_W))
        values = np.where(((yy + xx) & 1) == 0, -96, 64)
        return values.astype(np.int8).reshape(-1)
    if kind == "random":
        rng = np.random.default_rng(seed)
        return rng.integers(-128, 128, size=(INPUT_SIZE,), dtype=np.int8)
    raise ValueError(f"unknown demo payload kind {kind!r}")


def write_memh(vector: np.ndarray, path: Path) -> None:
    data = vector.view(np.uint8)
    path.write_text("".join(f"{int(x):02x}\n" for x in data), encoding="utf-8")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--input-npy", type=Path, help="1960-element int8/byte NumPy array")
    source.add_argument("--input-memh", type=Path, help="1960 byte-per-line memh file")
    source.add_argument("--input-bin", type=Path, help="1960-byte binary payload")
    source.add_argument(
        "--demo",
        choices=("silence", "ramp", "checker", "random"),
        help="create a deterministic non-audio demo payload",
    )
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--name", default="feature_payload")
    parser.add_argument("--seed", type=int, default=2026)
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    args.out_dir.mkdir(parents=True, exist_ok=True)

    try:
        vector, source = load_payload(args)
    except Exception as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    stem = f"{args.name}_1960_int8"
    npy_path = args.out_dir / f"{stem}.npy"
    memh_path = args.out_dir / f"{stem}.memh"
    bin_path = args.out_dir / f"{stem}.bin"
    manifest_path = args.out_dir / f"{args.name}_manifest.json"

    payload_bytes = vector.view(np.uint8).tobytes()
    np.save(npy_path, vector)
    write_memh(vector, memh_path)
    bin_path.write_bytes(payload_bytes)

    manifest = {
        "source": source,
        "shape": [INPUT_H, INPUT_W],
        "element_count": INPUT_SIZE,
        "dtype": "int8",
        "byte_order": "row-major input[y][x]",
        "files": {
            "npy": str(npy_path),
            "memh": str(memh_path),
            "bin": str(bin_path),
        },
        "stats": {
            "min": int(vector.min()),
            "max": int(vector.max()),
            "mean": float(np.mean(vector.astype(np.float64))),
            "sha256": _sha256(payload_bytes),
        },
        "note": "This is the accelerator input tensor format, not raw audio.",
    }
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    print(f"wrote {npy_path}")
    print(f"wrote {memh_path}")
    print(f"wrote {bin_path}")
    print(f"wrote {manifest_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
