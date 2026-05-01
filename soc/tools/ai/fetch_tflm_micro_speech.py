#!/usr/bin/env python3
"""Fetch the official TFLite Micro Micro Speech reference assets.

This intentionally downloads only the small files needed by the CD-ROM SoC AI
flow instead of vendoring the full TensorFlow Lite Micro repository.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path


DEFAULT_REF = "main"
RAW_BASE = "https://raw.githubusercontent.com/tensorflow/tflite-micro"
EXAMPLE_PATH = "tensorflow/lite/micro/examples/micro_speech"


@dataclass(frozen=True)
class Asset:
    relpath: str
    required: bool = True

    def url(self, ref: str) -> str:
        return f"{RAW_BASE}/{ref}/{EXAMPLE_PATH}/{self.relpath}"


BASE_ASSETS = (
    Asset("models/micro_speech_quantized.tflite"),
    Asset("micro_model_settings.h"),
    Asset("README.md"),
)

PREPROCESSOR_ASSETS = (
    Asset("models/audio_preprocessor_int8.tflite"),
)

TESTDATA_ASSETS = (
    Asset("testdata/yes_1000ms.wav"),
    Asset("testdata/no_1000ms.wav"),
    Asset("testdata/silence_1000ms.wav"),
    Asset("testdata/noise_1000ms.wav"),
)


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _download(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": "cd-rom-soc-ai-fetch/1.0"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read()


def fetch_asset(asset: Asset, ref: str, out_dir: Path, force: bool) -> dict[str, object]:
    target = out_dir / asset.relpath
    url = asset.url(ref)

    if target.exists() and not force:
        data = target.read_bytes()
        status = "cached"
    else:
        data = _download(url)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        status = "downloaded"

    return {
        "path": asset.relpath,
        "url": url,
        "bytes": len(data),
        "sha256": _sha256(data),
        "status": status,
    }


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", type=Path, required=True, help="download output directory")
    parser.add_argument("--ref", default=DEFAULT_REF, help="Git ref to fetch from")
    parser.add_argument("--force", action="store_true", help="re-download even when files exist")
    parser.add_argument(
        "--include-preprocessor",
        action="store_true",
        help="also fetch the int8 audio preprocessor model",
    )
    parser.add_argument(
        "--include-testdata",
        action="store_true",
        help="also fetch a few official WAV samples for later software preprocessing work",
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    out_dir: Path = args.out_dir
    out_dir.mkdir(parents=True, exist_ok=True)

    assets = list(BASE_ASSETS)
    if args.include_preprocessor:
        assets.extend(PREPROCESSOR_ASSETS)
    if args.include_testdata:
        assets.extend(TESTDATA_ASSETS)

    records: list[dict[str, object]] = []
    try:
        for asset in assets:
            record = fetch_asset(asset, args.ref, out_dir, args.force)
            records.append(record)
            print(f"{record['status']}: {record['path']} ({record['bytes']} bytes)")
    except urllib.error.URLError as exc:
        print(f"error: could not download TFLM Micro Speech asset: {exc}", file=sys.stderr)
        return 1

    manifest = {
        "source": "tensorflow/tflite-micro",
        "example": EXAMPLE_PATH,
        "ref": args.ref,
        "assets": records,
        "notes": [
            "Only selected reference assets are downloaded; the full TFLM repo is not vendored.",
            "The SoC RTL consumes the quantized Micro Speech model through generated assets.",
        ],
    }
    (out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"wrote manifest: {out_dir / 'manifest.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
