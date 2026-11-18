"""Finish the lake bed on Tenaya's 32px painted ground before baking its normals.

Run after the hub's palette upgrade (rebuild_tenaya_lake.sh). The connected
water mask keeps the beach, shoreline and fishing spots in exact register.
"""
from pathlib import Path
import sys

import numpy as np
from PIL import Image, ImageDraw

import field as F

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools/perf"))
from water_cells import water_mask

GROUND = ROOT / "assets/sprites/ahwahnee/ground_tenaya_lake.png"
# Cold blue in the trough, turquoise over submerged granite, pale green
# where the sand shows through. All tones read as water to the ground shader.
WATER = np.array([F.hexrgb(color) for color in (
    "163e5d", "194861", "1d536d", "205d75", "24697e", "2b7686",
    "36858e", "449597", "58a4a0", "6cb4ab", "83c2b6", "9ecfc1",
)])

# Tone steps on a submerged granite block, from its sunward lip to the
# shadow in the sand beneath it. Stamps are in two-world-pixel art pixels.
FACETS = {"h": 1.8, "t": 0.8, "f": -0.7, "s": -1.6}
BLOCK = F.Stamp([
    "....hhhh...",
    "..hhtttth..",
    ".htttttttf.",
    "httttttfff.",
    ".fffffffss.",
    "...ssssss..",
], FACETS)
PEBBLE = F.Stamp([".hh.", "httf", ".fss"], FACETS)


def paint(path: Path) -> None:
    mask_image = Image.fromarray(water_mask(path).astype(np.uint8)).copy()
    # The centre of the lake in build_tenaya_lake.gd's tile grid.
    center = (64 * 32, 19 * 32)
    if mask_image.getpixel(center) != 1:
        raise ValueError("Expected open water at the centre of Tenaya Lake")
    ImageDraw.floodfill(mask_image, center, 2)
    lake = np.asarray(mask_image) == 2
    # Work on the art grid. Composite at full resolution at the end so the
    # half-pixel corners of the original shoreline survive.
    wet = lake[1::2, 1::2]
    h, w = wet.shape
    y, x = np.mgrid[:h, :w]
    relief = F.fbm(h, w, 65, 1851)
    grain = F.value_noise(h, w, 8, 1861)
    # The proportion of dry land nearby describes the shelf. East Beach has
    # a long sandy apron; under the north wall the bottom drops away fast.
    near = 1.0 - F.blur(wet, 22)
    far = 1.0 - F.blur(wet, 95)
    beach = np.clip((x / 16.0 - 72.0) / 15.0, 0, 1)
    shelf = np.clip(near * 0.95 + far * (1.25 + beach * 0.8), 0, 1)
    tone = 1.4 + shelf * 8.1 + (relief - 0.5) * (2.7 + shelf * 3.0)
    # Eroded ledges run diagonally under the shallows. Break their edges
    # into irregular patches before the shelves disappear into deep water.
    bedding = np.sin(x * 0.053 + y * 0.11 + relief * 11.0 + grain * 0.65)
    tone += shelf * ((bedding > 0.42) * 0.7 - (bedding < -0.7) * 0.5)
    shoal = wet & (shelf > 0.19)
    for stamp, spacing, density, seed in [(BLOCK, 16, 0.46, 64), (PEBBLE, 6, 0.76, 65)]:
        ys, xs, _ = F.scatter(h, w, spacing, density * shelf * relief, seed, shoal)
        F.apply_tone(tone, wet, ys, xs, stamp)
    # A little sand grain at the margins. In the open lake, keep broad,
    # quiet shapes for the moving reflections and the fishing line.
    tone += shelf * (grain - 0.5) * 1.3
    index = np.clip(np.floor(tone + F.bayer(h, w) * 0.32), 0, len(WATER) - 1).astype(np.intp)
    color = np.asarray(Image.fromarray(WATER[index]).resize(mask_image.size, Image.Resampling.NEAREST))
    ground = np.array(Image.open(path).convert("RGBA"))
    ground[lake, :3] = color[lake]
    Image.fromarray(ground).save(path, optimize=True)


if __name__ == "__main__":
    paint(GROUND)
