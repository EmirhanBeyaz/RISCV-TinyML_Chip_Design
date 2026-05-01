#!/usr/bin/env python3
"""Convert a 16 kHz mono WAV into a 49x40 int8 demo feature payload.

This is a lightweight host-side demo preprocessor. It is not a bit-exact
implementation of TensorFlow Lite Micro's Signal Library audio preprocessor.
Use it to exercise the SoC data path from a real WAV file while the official
preprocessor/runtime integration is still a separate sign-off task.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import wave
from pathlib import Path

import numpy as np


SAMPLE_RATE = 16_000
FRAME_LEN = 480
FRAME_STRIDE = 320
FEATURE_COUNT = 49
FEATURE_SIZE = 40
INPUT_SIZE = FEATURE_COUNT * FEATURE_SIZE
FFT_SIZE = 512


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def read_wav_mono_i16(path: Path) -> np.ndarray:
    with wave.open(str(path), "rb") as wav:
        channels = wav.getnchannels()
        sample_width = wav.getsampwidth()
        rate = wav.getframerate()
        frames = wav.getnframes()
        data = wav.readframes(frames)

    if channels != 1:
        raise ValueError(f"{path} must be mono, got {channels} channels")
    if sample_width != 2:
        raise ValueError(f"{path} must be 16-bit PCM, got sample width {sample_width}")
    if rate != SAMPLE_RATE:
        raise ValueError(f"{path} must be {SAMPLE_RATE} Hz, got {rate} Hz")

    return np.frombuffer(data, dtype="<i2").astype(np.float32) / 32768.0


def frame_signal(samples: np.ndarray) -> np.ndarray:
    required = (FEATURE_COUNT - 1) * FRAME_STRIDE + FRAME_LEN
    if samples.size < required:
        samples = np.pad(samples, (0, required - samples.size))
    else:
        samples = samples[:required]

    frames = np.zeros((FEATURE_COUNT, FRAME_LEN), dtype=np.float32)
    for idx in range(FEATURE_COUNT):
        start = idx * FRAME_STRIDE
        frames[idx, :] = samples[start : start + FRAME_LEN]
    return frames


def linear_log_features(samples: np.ndarray) -> np.ndarray:
    frames = frame_signal(samples)
    window = np.hanning(FRAME_LEN).astype(np.float32)
    features = np.zeros((FEATURE_COUNT, FEATURE_SIZE), dtype=np.float32)

    for frame_idx, frame in enumerate(frames):
        spectrum = np.fft.rfft(frame * window, n=FFT_SIZE)
        power = (np.abs(spectrum) ** 2).astype(np.float32)
        bands = np.array_split(power[1:], FEATURE_SIZE)
        energies = np.asarray([float(np.mean(band)) for band in bands], dtype=np.float32)
        features[frame_idx, :] = np.log1p(energies * 1.0e4)

    return features


def quantize_feature(features: np.ndarray) -> np.ndarray:
    lo = float(np.min(features))
    hi = float(np.max(features))
    if hi - lo < 1.0e-9:
        return np.full((INPUT_SIZE,), -128, dtype=np.int8)

    normalized = (features - lo) / (hi - lo)
    quantized = np.rint(normalized * 255.0 - 128.0)
    return np.clip(quantized, -128, 127).astype(np.int8).reshape(-1)


def write_memh(vector: np.ndarray, path: Path) -> None:
    data = vector.view(np.uint8)
    path.write_text("".join(f"{int(x):02x}\n" for x in data), encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--wav", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--name", default=None)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    args.out_dir.mkdir(parents=True, exist_ok=True)

    samples = read_wav_mono_i16(args.wav)
    features_f32 = linear_log_features(samples)
    vector = quantize_feature(features_f32)
    payload_bytes = vector.view(np.uint8).tobytes()

    name = args.name or args.wav.stem
    stem = f"{name}_1960_int8"
    npy_path = args.out_dir / f"{stem}.npy"
    memh_path = args.out_dir / f"{stem}.memh"
    bin_path = args.out_dir / f"{stem}.bin"
    manifest_path = args.out_dir / f"{name}_manifest.json"

    np.save(npy_path, vector)
    write_memh(vector, memh_path)
    bin_path.write_bytes(payload_bytes)

    manifest = {
        "source_wav": str(args.wav),
        "shape": [FEATURE_COUNT, FEATURE_SIZE],
        "dtype": "int8",
        "element_count": INPUT_SIZE,
        "sample_rate_hz": SAMPLE_RATE,
        "frame_len_samples": FRAME_LEN,
        "frame_stride_samples": FRAME_STRIDE,
        "method": "demo_linear_log_energy_40band",
        "official_tflm_preprocessor_bit_exact": False,
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
        "note": (
            "Demo feature payload for SoC data-path validation. "
            "Not a replacement for official TFLM Signal Library preprocessing."
        ),
    }
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    print(f"wrote {npy_path}")
    print(f"wrote {memh_path}")
    print(f"wrote {bin_path}")
    print(f"wrote {manifest_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
