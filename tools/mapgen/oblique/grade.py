"""Colour-grades the Valley map picture after gen.js has drawn it.

    python3 tools/mapgen/oblique/grade.py

Gives the picture a touch more contrast, warm sunlit tones and cool shadows,
a soft vignette toward the edges, and a lift in the blue of the rivers, without
moving a pixel (the labels, kiosks and the player marker are placed from
yosemite_valley_view.json, so the geometry must stay put). Safe to run once
after each gen.js run; running it twice grades twice.
"""
import os
import sys

import numpy as np
from PIL import Image

PATH = os.path.join(os.path.dirname(__file__), "..", "..", "..", "assets", "map", "areas", "yosemite_valley.png")


def main(path: str) -> None:
    im = Image.open(path).convert("RGBA")
    a = np.asarray(im).astype(np.float32) / 255.0
    rgb, alpha = a[..., :3], a[..., 3:]
    lum = (rgb * np.array([0.3, 0.55, 0.15], dtype=np.float32)).sum(axis=-1, keepdims=True)
    # contrast curve around mid grey
    rgb = (rgb - 0.5) * 1.12 + 0.5
    # warm the lights, cool the shadows
    warm = (lum - 0.45) * 0.07
    rgb = rgb + np.concatenate([warm, warm * 0.35, -warm], axis=-1)
    # rivers and lakes (blue-dominant pixels) get a little more blue
    blue = np.clip((rgb[..., 2:3] - np.maximum(rgb[..., 0:1], rgb[..., 1:2])) * 6.0, 0.0, 1.0)
    rgb = rgb + blue * np.array([-0.02, 0.03, 0.07], dtype=np.float32)
    # vignette
    h, w = rgb.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.sqrt(((xx - w / 2) / (w / 2)) ** 2 + ((yy - h / 2) / (h / 2)) ** 2)
    rgb = rgb * (1.0 - np.clip((d - 0.55) * 0.28, 0.0, 0.2))[..., None]
    out = np.concatenate([np.clip(rgb, 0.0, 1.0), alpha], axis=-1)
    Image.fromarray((out * 255.0 + 0.5).astype(np.uint8), "RGBA").save(path)
    print("graded", os.path.normpath(path))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else PATH)
