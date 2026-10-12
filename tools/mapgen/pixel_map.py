"""Turns the park map's smooth hillshade into pixel art, after mapgen has drawn it.

    python3 tools/mapgen/pixel_map.py

The map comes out of `godot ... mapgen.tscn -- art park` as a smooth relief
picture with thousands of colours, which looked like a photograph next to the
rest of the game. This snaps every pixel to a small palette of shade ramps in
the game's style (forest, meadow, the faded country outside the park, granite
and snow, water, roads, ink) with a 4x4 ordered dither between neighbouring
shades, the way pixel artists render a gradient. Nothing moves, so the markers and labels ParkMap draws stay put.
Running it again changes nothing.
"""
import os
import sys

import numpy as np
from PIL import Image

PATH = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "map", "park_map.png")

# Shade ramps, darkest first. Kept short, like a hand-picked pixel palette.
PALETTE_HEX = [
    # forest
    "1c3424", "2a4c2e", "3e6838", "56844a", "7aa25e",
    # the faded country outside the park
    "8e9a78", "a6b490", "bac6a0", "ced2b0", "e0e0c4",
    # meadow and foothill grass
    "8a9450", "a8b062", "c8c888", "e2dcae",
    # granite, scree and snow
    "3e3e46", "5c5c64", "80808a", "a8a8ae", "cecece", "f0f0ec",
    # water
    "234e94", "3470c0", "5a98dc", "9ac4ec",
    # roads and the park line
    "c8a868", "e6cc92", "f6e6b6",
    # ink: borders and shadows
    "2a1f1a", "4a3a2c",
]
PALETTE = np.array([[int(h[i:i + 2], 16) for i in (0, 2, 4)] for h in PALETTE_HEX], dtype=np.float32)

# 4x4 Bayer matrix, centred on zero.
BAYER = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=np.float32) + 0.5) / 16.0 - 0.5
# How far the dither nudges a pixel before it is snapped (in 0-255 units).
SPREAD = 14.0


def main(path: str) -> None:
    im = Image.open(path).convert("RGBA")
    a = np.asarray(im).astype(np.float32)
    rgb, alpha = a[..., :3], a[..., 3:]
    h, w = rgb.shape[:2]
    # Already a palette picture (a second run): leave it alone.
    flat = rgb.reshape(-1, 3)
    if np.all(np.min(((flat[:, None, :] - PALETTE[None, :, :]) ** 2).sum(-1), axis=1) < 1.0):
        print("%s is already pixel-graded" % path)
        return
    threshold = np.tile(BAYER, (h // 4 + 1, w // 4 + 1))[:h, :w][..., None]
    nudged = rgb + threshold * SPREAD
    # nearest palette colour, weighting green the way the eye does
    weight = np.array([0.3, 0.59, 0.11], dtype=np.float32) * 3.0
    d = (((nudged[:, :, None, :] - PALETTE[None, None, :, :]) ** 2) * weight).sum(-1)
    snapped = PALETTE[np.argmin(d, axis=-1)]
    out = np.concatenate([snapped, alpha], axis=-1).clip(0, 255).astype(np.uint8)
    Image.fromarray(out, "RGBA").save(path)
    print("Pixel-graded %s (%d colours)" % (path, len(PALETTE_HEX)))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else PATH)
