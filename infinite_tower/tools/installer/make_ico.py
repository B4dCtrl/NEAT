#!/usr/bin/env python3
"""Packs tools/installer/icon/icon_<size>.png into tools/installer/icon.ico
(PNG-compressed ICO entries, supported since Windows Vista).
    python3 -I tools/installer/make_ico.py"""
import struct
from pathlib import Path

HERE = Path(__file__).resolve().parent
SIZES = [16, 24, 32, 48, 64, 128, 256]

pngs = [(s, (HERE / "icon" / f"icon_{s}.png").read_bytes()) for s in SIZES]
header = struct.pack("<HHH", 0, 1, len(pngs))
offset = 6 + 16 * len(pngs)
entries = b""
for s, data in pngs:
    dim = 0 if s >= 256 else s
    entries += struct.pack("<BBBBHHII", dim, dim, 0, 0, 1, 32, len(data), offset)
    offset += len(data)
(HERE / "icon.ico").write_bytes(header + entries + b"".join(d for _, d in pngs))
print("wrote", HERE / "icon.ico")
