#!/usr/bin/env python3
"""Create a deterministic int8 TinyConv .tflite model for tooling smoke tests."""

from __future__ import annotations

import argparse
import os
import random
import sys
from pathlib import Path

import numpy as np


INPUT_SIZE = 1960


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", type=Path, required=True)
    return parser.parse_args(argv)


def representative_data() -> object:
    rng = np.random.default_rng(12345)
    for _ in range(32):
        yield [rng.normal(0.0, 0.25, size=(1, INPUT_SIZE)).astype(np.float32)]


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    args.out_dir.mkdir(parents=True, exist_ok=True)

    os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "2")
    import tensorflow as tf  # type: ignore

    tf.random.set_seed(2026)
    np.random.seed(2026)
    random.seed(2026)

    model = tf.keras.Sequential(
        [
            tf.keras.layers.Input(shape=(INPUT_SIZE,), name="spectrogram_vector"),
            tf.keras.layers.Reshape((49, 40, 1), name="reshape_49x40x1"),
            tf.keras.layers.DepthwiseConv2D(
                kernel_size=(10, 8),
                strides=(2, 2),
                padding="same",
                depth_multiplier=8,
                activation="relu",
                use_bias=True,
                name="depthwise_conv2d",
            ),
            tf.keras.layers.Flatten(name="flatten_4000"),
            tf.keras.layers.Dense(4, use_bias=True, name="fc_4"),
        ]
    )

    sample = np.linspace(-1.0, 1.0, INPUT_SIZE, dtype=np.float32).reshape(1, INPUT_SIZE)
    _ = model(sample)

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.representative_dataset = representative_data
    converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
    converter.inference_input_type = tf.int8
    converter.inference_output_type = tf.int8
    tflite_model = converter.convert()

    model_path = args.out_dir / "synthetic_tinyconv_int8.tflite"
    model_path.write_bytes(tflite_model)

    rng = np.random.default_rng(2027)
    input_vector = rng.integers(-128, 128, size=(INPUT_SIZE,), dtype=np.int8)
    np.save(args.out_dir / "input_1960_int8.npy", input_vector)

    print(f"wrote {model_path}")
    print(f"wrote {args.out_dir / 'input_1960_int8.npy'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
