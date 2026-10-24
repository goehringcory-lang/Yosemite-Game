#!/usr/bin/env python3
"""Lays an area's sprites over a ground picture, for looking at the ground
in place without importing it into Godot (no lighting, people or effects).

    python3 tools/art32/ground32/preview.py DUMP.json GROUND.png OUT.png [x,y,w,h] [scale]
"""
from __future__ import annotations

import json
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))

_cache: dict[str, Image.Image] = {}


def _tex(tex: str) -> Image.Image | None:
    if tex not in _cache:
        p = os.path.join(ROOT, tex.replace("res://", ""))
        _cache[tex] = Image.open(p).convert("RGBA") if os.path.exists(p) else None
    return _cache[tex]


def compose(dump: dict, ground: Image.Image, rect=None) -> Image.Image:
    base = ground.convert("RGBA").copy()
    items = []
    for sp in dump["sprites"]:
        if not sp["visible"] or "_glow" in sp["tex"]:
            continue
        im = _tex(sp["tex"])
        if im is None:
            continue
        if sp["region"]:
            x, y, w, h = (int(v) for v in sp["region"])
            fr = im.crop((x, y, x + w, y + h))
        else:
            hf, vf = max(1, sp["hf"]), max(1, sp["vf"])
            fw, fh = im.width // hf, im.height // vf
            fr = im.crop((0, 0, fw, fh))
        if sp["flip"]:
            fr = fr.transpose(Image.FLIP_LEFT_RIGHT)
        if sp["centered"]:
            left = sp["x"] + sp["ox"] - fr.width / 2.0
            top = sp["y"] + sp["oy"] - fr.height / 2.0
        else:
            left = sp["x"] + sp["ox"]
            top = sp["y"] + sp["oy"]
        items.append((sp["z"], sp["y"], int(round(left)), int(round(top)), fr))
    items.sort(key=lambda t: (t[0], t[1]))
    for _, _, x, y, fr in items:
        base.alpha_composite(fr, (x, y)) if x >= 0 and y >= 0 else base.paste(fr, (x, y), fr)
    if rect:
        x, y, w, h = rect
        base = base.crop((x, y, x + w, y + h))
    return base


if __name__ == "__main__":
    dump = json.load(open(sys.argv[1]))
    ground = Image.open(sys.argv[2])
    rect = tuple(int(v) for v in sys.argv[4].split(",")) if len(sys.argv) > 4 else None
    out = compose(dump, ground, rect)
    scale = int(sys.argv[5]) if len(sys.argv) > 5 else 1
    if scale > 1:
        out = out.resize((out.width * scale, out.height * scale), Image.NEAREST)
    out.save(sys.argv[3])
