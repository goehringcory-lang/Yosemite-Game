#!/usr/bin/env python3
"""Copies the patched part of a freshly painted ground picture into a map's
32px ground picture (the second half of tools/mapgen/patch_land.sh).

    python3 tools/mapgen/patch_ground.py HUB PICTURE_16PX X0 Y0 X1 Y1 [--check]

PICTURE_16PX is the whole map painted at 16px to a tile by patch_land.tscn. It
gets the same 32px pass as the map's ground picture (tools/art32/passes.py,
seeded by the picture's path), so it matches it, and the tiles X0..X1, Y0..Y1
(plus a margin, for the painter's blending across tile edges) are pasted in.
With --check it pastes nothing and prints how much of the picture outside the
patch differs, which should be none.
"""
from __future__ import annotations

import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "art32"))
import passes  # noqa: E402
import pixel32 as K  # noqa: E402

TILE = 32
MARGIN = 3


def main() -> None:
    hub, picture = sys.argv[1], sys.argv[2]
    x0, y0, x1, y1 = (int(v) for v in sys.argv[3:7])
    check = "--check" in sys.argv
    rel = f"assets/map/ground/{hub}_ground.png"
    target = os.path.join(ROOT, rel)
    fresh = passes.run("terrain", rel, np.array(Image.open(picture).convert("RGBA")))
    old = np.array(Image.open(target).convert("RGBA"))
    if fresh.shape != old.shape:
        sys.exit(f"sizes differ: {fresh.shape} painted, {old.shape} in {rel}")
    if check:
        diff = np.any(fresh != old, axis=2)
        print(f"{diff.mean() * 100:.3f}% of pixels differ")
        return
    h, w = old.shape[:2]
    px0, py0 = max(0, (x0 - MARGIN) * TILE), max(0, (y0 - MARGIN) * TILE)
    px1, py1 = min(w, (x1 + MARGIN) * TILE), min(h, (y1 + MARGIN) * TILE)
    old[py0:py1, px0:px1] = fresh[py0:py1, px0:px1]
    K.save(old, target)
    print(f"pasted {px1 - px0}x{py1 - py0} px at {px0},{py0} into {rel}")


if __name__ == "__main__":
    main()
