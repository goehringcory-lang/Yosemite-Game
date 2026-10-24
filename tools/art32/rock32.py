#!/usr/bin/env python3
"""Cleans the granite of the Valley's cliff walls for the 32px game.

The walls were drawn at 16px with a fine dither and then doubled, which left
the rock covered in salt-and-pepper speckle and stray orange flecks, so it
read as noise rather than stone. This works on the walls' art pixels (2x2):
every granite pixel takes the most common granite tone around it, so the rock
gathers into clean planes of light and shade; a pixel keeps its tone where
enough of the same tone runs through it (cracks, edges and planes), and the
dark outlines and
outlines, the pines on the ledges, the falls and anything else not granite
stay exactly as drawn. A few lichen flecks are kept. Then Scale2x rounds it
off as before.

    python3 tools/art32/rock32.py FILE...            # in place
    python3 tools/art32/rock32.py --out DIR FILE...  # to look first
"""
from __future__ import annotations

import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from pixel32 import scale2x  # noqa: E402


def _is_granite(rgb: np.ndarray) -> np.ndarray:
    r, g, b = (rgb[..., i].astype(np.int32) for i in range(3))
    mx = np.maximum(np.maximum(r, g), b)
    mn = np.minimum(np.minimum(r, g), b)
    lum = (r * 299 + g * 587 + b * 114) // 1000
    # grey or cool shadow, not the darkest outline tones
    return ((mx - mn < 40) & (lum > 60)) | ((b >= r) & (mx - mn < 70) & (lum > 62))


def _is_fleck(rgb: np.ndarray) -> np.ndarray:
    r, g, b = (rgb[..., i].astype(np.int32) for i in range(3))
    return (r > g + 30) & (g > b + 10) & (r > 150)


def clean(a: np.ndarray, radius: int = 1, passes: int = 2) -> np.ndarray:
    small = a[0::2, 0::2].copy()
    h, w = small.shape[:2]
    opaque = small[..., 3] > 0
    yy, xx = np.mgrid[0:h, 0:w]
    rnd = ((xx * 374761393 + yy * 668265263) & 0xFFFF) / 65535.0
    # most lichen flecks go; the rest stay as accents
    fl = _is_fleck(small[..., :3]) & opaque & (rnd > 0.3)
    for _ in range(passes):
        gran = _is_granite(small[..., :3]) & opaque
        key = (small[..., 0].astype(np.int32) << 16) | (small[..., 1].astype(np.int32) << 8) | small[..., 2]
        cols = np.unique(key[gran])
        best = np.zeros((h, w), np.int32)
        best_n = np.full((h, w), -1, np.int32)
        own_n = np.zeros((h, w), np.int32)
        for c in cols:
            m = (gran & (key == c)).astype(np.int32)
            p = np.pad(m, radius)
            n = np.zeros((h, w), np.int32)
            for dy in range(2 * radius + 1):
                for dx in range(2 * radius + 1):
                    n += p[dy:dy + h, dx:dx + w]
            own_n = np.where(key == c, n, own_n)
            better = n > best_n
            best = np.where(better, c, best)
            best_n = np.where(better, n, best_n)
        # Speckle (a tone with at most two of its own round it) gives way;
        # lines and planes, which have more, stay.
        tgt = ((gran & (own_n <= 3)) | fl) & (best_n >= 3)
        small[tgt, 0] = (best[tgt] >> 16) & 255
        small[tgt, 1] = (best[tgt] >> 8) & 255
        small[tgt, 2] = best[tgt] & 255
        fl[:] = False
    out = scale2x(small)
    return out[:a.shape[0], :a.shape[1]]


def main() -> None:
    args = sys.argv[1:]
    out_dir = None
    if args[:1] == ["--out"]:
        out_dir = args[1]
        args = args[2:]
        os.makedirs(out_dir, exist_ok=True)
    for f in args:
        a = np.array(Image.open(f).convert("RGBA"))
        res = clean(a)
        dest = os.path.join(out_dir, os.path.basename(f)) if out_dir else f
        Image.fromarray(res, "RGBA").save(dest)
        print("cleaned", dest)


if __name__ == "__main__":
    main()
