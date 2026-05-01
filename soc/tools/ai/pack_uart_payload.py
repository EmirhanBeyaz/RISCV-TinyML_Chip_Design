#!/usr/bin/env python3
"""Pack a 1960-byte AI feature payload into the CD-ROM UART demo packet."""

from __future__ import annotations

import argparse
import json
import struct
import zlib
from pathlib import Path

import numpy as np


MAGIC = b"CDAI"
VERSION = 1
MSG_FEATURE_PAYLOAD = 1
HEADER_SIZE = 16
PAYLOAD_BYTES = 1960


def read_payload(path: Path) -> bytes:
    if path.suffix == ".npy":
        vector = np.load(path).reshape(-1)
        if vector.size != PAYLOAD_BYTES:
            raise ValueError(f"{path} must contain {PAYLOAD_BYTES} elements, got {vector.size}")
        if np.issubdtype(vector.dtype, np.unsignedinteger):
            return vector.astype(np.uint8).tobytes()
        return vector.astype(np.int8).view(np.uint8).tobytes()

    data = path.read_bytes()
    if len(data) != PAYLOAD_BYTES:
        raise ValueError(f"{path} must be exactly {PAYLOAD_BYTES} bytes, got {len(data)}")
    return data


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True, help="1960-byte .bin or .npy payload")
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--name", default=None)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    args.out_dir.mkdir(parents=True, exist_ok=True)

    payload = read_payload(args.input)
    crc = zlib.crc32(payload) & 0xFFFF_FFFF
    header = struct.pack(
        "<4sBBHII",
        MAGIC,
        VERSION,
        MSG_FEATURE_PAYLOAD,
        HEADER_SIZE,
        len(payload),
        crc,
    )
    packet = header + payload

    name = args.name or args.input.stem
    packet_path = args.out_dir / f"{name}_uart_packet.bin"
    manifest_path = args.out_dir / f"{name}_uart_packet.json"
    packet_path.write_bytes(packet)
    manifest = {
        "input": str(args.input),
        "packet": str(packet_path),
        "magic": MAGIC.decode("ascii"),
        "version": VERSION,
        "message_type": MSG_FEATURE_PAYLOAD,
        "header_size": HEADER_SIZE,
        "payload_len": len(payload),
        "crc32": f"0x{crc:08x}",
        "packet_len": len(packet),
        "note": "Firmware packet mode. Raw AI_UART loader mode uses the payload bytes without this header.",
    }
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"wrote {packet_path}")
    print(f"wrote {manifest_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
