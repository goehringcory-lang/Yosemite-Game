#!/usr/bin/env python3
"""Bakes Tuolumne Falls' white water for Glen Aulin (build_glen_aulin.gd).

The falls are laid along the river on their side, so they use White
Cascade's wall-fall frames (glen_aulin_fall_N.png, and their normal maps)
faded out toward the lip and the foot: turned along the river, the frames'
hard ends would otherwise stop the white water in a straight line. Writes
glen_aulin_rapids_N.png beside them. Run by tools/hubs/rebuild_glen_aulin.sh
after the falls are drawn.

    python3 tools/hubs/glen_aulin_rapids.py
"""
import glob
import os

import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
TOP_FADE = 0.2   # share of the frame's height faded in at the lip
FOOT_FADE = 0.35  # and faded out at the foot


def fade(h: int) -> np.ndarray:
    y = (np.arange(h) + 0.5) / h
    top = np.clip(y / TOP_FADE, 0.0, 1.0)
    foot = np.clip((1.0 - y) / FOOT_FADE, 0.0, 1.0)
    f = np.minimum(top, foot)
    return f * f * (3.0 - 2.0 * f)  # smoothstep


def main() -> None:
    for kind in ("sprites", "normals"):
        for src in sorted(glob.glob(os.path.join(ROOT, "assets", kind, "valley", "glen_aulin_fall_[0-9].png"))):
            im = np.array(Image.open(src).convert("RGBA")).astype(np.float32)
            im[:, :, 3] *= fade(im.shape[0])[:, None]
            out = src.replace("glen_aulin_fall_", "glen_aulin_rapids_")
            Image.fromarray(np.round(im).astype(np.uint8), "RGBA").save(out)
            print("wrote", os.path.relpath(out, ROOT))


if __name__ == "__main__":
    main()
