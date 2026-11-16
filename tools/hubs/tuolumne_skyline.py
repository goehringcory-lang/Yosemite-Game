#!/usr/bin/env python3
"""Paints the High Sierra skyline hung above Tuolumne Meadows' north edge
(scenes/world/tuolumne_skyline.tscn): what you see past the lodgepoles when
you walk to the top of the map and the camera looks up.

West to east, left to right as the map runs: Mount Hoffmann far off at the
west end, a low ridge of granite domes behind the meadow, the jagged teeth
of Ragged Peak, White Mountain, the broad granite block of Mount Conness,
and at the east end the rust-red metamorphic summits of Mount Dana and
Mount Gibbs over Tioga Pass. Three layers, farthest first, each hazier and
bluer the farther it is: the high peaks with their snowfields, a forested
middle ridge with granite outcrops, and the near forest's crowns along the
bottom (most of which hide behind the map's own trees).

Two pictures: summer (snow left in the high gullies) and winter (spring and
winter: deep snow on everything above the trees). Painted at the art's
16px scale and doubled, like the masses. The ranges are drawn from memory
of their shapes, not measured: the cloud sessions can't reach the USGS.

    python3 tools/hubs/tuolumne_skyline.py
    godot --headless --path . --import
"""
from __future__ import annotations

import math
import os

import numpy as np
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.path.join(ROOT, "assets", "sprites", "tuolumne")
W, H = 2240, 180  # art pixels (each 2x2 on screen): 4480 x 360, the map's width

SKY_TOP = (0x4A, 0x80, 0xA5)  # the seam backdrop's sky (scripts/world/seam_backdrop.gd)
SKY_LOW = (0x9C, 0xBF, 0xD6)

# the far peaks: granite, and Dana and Gibbs's red metamorphic rock
GRANITE = {"lit": [(0xC9, 0xD0, 0xD8), (0xB4, 0xBE, 0xCA)], "shade": [(0x8E, 0x9C, 0xB0), (0x7A, 0x89, 0xA0)]}
RED = {"lit": [(0xB8, 0x95, 0x86), (0xA4, 0x82, 0x78)], "shade": [(0x82, 0x70, 0x76), (0x6E, 0x60, 0x6A)]}
SNOW = {"lit": (0xF2, 0xF6, 0xFA), "shade": (0xC2, 0xD0, 0xE2), "edge": (0xA6, 0xB6, 0xCC)}
RIM = (0x6A, 0x7A, 0x92)
# the middle ridge, bluer for the distance
MID = {"forest": [(0x3A, 0x55, 0x58), (0x45, 0x62, 0x62), (0x52, 0x70, 0x6A)],
       "rock": [(0x9A, 0xA8, 0xB4), (0x7E, 0x8E, 0x9E)], "snow": (0xD8, 0xE2, 0xEC)}
# the near crowns, the scene's lodgepole greens a little hazed
NEAR = [(0x18, 0x30, 0x24), (0x22, 0x40, 0x2C), (0x30, 0x52, 0x36), (0x3E, 0x62, 0x3E)]

# [centre x, height above the foot, half-width, roundness, jag, rock]
# heights in art rows above row H (the bottom); roundness is the power of
# the profile (1 a straight-sided cone, 2 a broad rounded hulk, more a
# flat-topped block), jag adds teeth along the crest
PEAKS = [
    (150, 112, 260, 1.7, 0.45, "granite"),   # Mount Hoffmann, far west
    (470, 96, 210, 1.5, 0.3, "granite"),     # Tuolumne Peak
    (800, 88, 200, 1.6, 0.2, "granite"),     # the ridge north of the domes
    (1200, 128, 170, 1.25, 1.0, "granite"),  # Ragged Peak
    (1450, 134, 190, 1.5, 0.35, "granite"),  # White Mountain
    (1720, 150, 220, 2.6, 0.3, "granite"),   # Mount Conness, a broad block
    (2000, 162, 250, 1.7, 0.15, "red"),      # Mount Dana, a big rounded hulk
    (2230, 146, 210, 1.9, 0.15, "red"),      # Mount Gibbs
]


def _hash(*v: int) -> float:
    h = 2166136261
    for x in v:
        h = ((h ^ (x & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF
    h ^= h >> 13
    h = (h * 1274126177) & 0xFFFFFFFF
    return (h & 0xFFFFFF) / float(0x1000000)


def _noise(x: float, sd: int) -> float:
    """Smooth 1-D value noise, 0..1."""
    i = math.floor(x)
    f = x - i
    f = f * f * (3 - 2 * f)
    return _hash(i, sd) * (1 - f) + _hash(i + 1, sd) * f


def _peak_height(p, x: float) -> float:
    cx, ht, hw, sharp, jag, _ = p
    d = abs(x - cx) / hw
    if d >= 1.0:
        return 0.0
    v = max(0.0, 1.0 - d ** sharp)
    # teeth along the crest, most near the top
    teeth = (_noise(x / 6.0, int(cx)) - 0.5) * 2.0 * jag * 10.0 * v
    rough = (_noise(x / 23.0, int(cx) + 1) - 0.5) * 8.0 * v
    return ht * v + teeth + rough


def far_profile() -> tuple[np.ndarray, np.ndarray]:
    """The skyline's height per column and which peak owns it."""
    tops = np.zeros(W, np.float32)
    owner = np.full(W, -1, np.int32)
    for x in range(W):
        best, who = 74.0 + (_noise(x / 40.0, 3) - 0.5) * 16.0, -1
        for i, p in enumerate(PEAKS):
            h = _peak_height(p, x)
            if h > best:
                best, who = h, i
        tops[x] = best
        owner[x] = who
    return tops, owner


def paint(winter: bool) -> Image.Image:
    rgb = np.zeros((H, W, 3), np.uint8)
    al = np.full((H, W), 255, np.uint8)
    # the sky: dithered bands from the high blue down to the pale horizon
    bands = 7
    for y in range(H):
        t = y / (H * 0.8)
        b = min(bands - 1, t * (bands - 1))
        lo, f = int(b), b - int(b)
        c0 = [SKY_TOP[k] + (SKY_LOW[k] - SKY_TOP[k]) * lo / (bands - 1) for k in range(3)]
        c1 = [SKY_TOP[k] + (SKY_LOW[k] - SKY_TOP[k]) * min(bands - 1, lo + 1) / (bands - 1) for k in range(3)]
        for x in range(W):
            # an ordered 2x2 dither in the last part of each band
            d = ((x & 1) * 2 + (y & 1)) / 4.0
            rgb[y, x] = c1 if f > 0.5 + d * 0.5 else c0
    # the far peaks
    tops, owner = far_profile()
    snowline = 0.6 if winter else 0.4  # share of a peak's height below its top that holds snow
    for x in range(W):
        top = H - int(round(tops[x]))
        who = owner[x]
        rock = RED if who >= 0 and PEAKS[who][5] == "red" else GRANITE
        cx = PEAKS[who][0] if who >= 0 else x
        ht = PEAKS[who][1] if who >= 0 else 50.0
        # the ridge from the summit down: west of it lit, east of it in shade,
        # and gullies (snow chutes) running down the faces
        for y in range(max(0, top), H):
            depth = (y - top)
            ridge = cx + (y - (H - ht)) * 0.35 + (_noise(y / 5.0, int(cx) + 7) - 0.5) * 10.0
            lit = x < ridge
            # faces: lit and shade, each in two tones broken by vertical ribs
            # blotchy ribs and buttresses down the faces
            rib = _noise((x + 6.0 * _noise(y / 7.0, int(cx) + 8)) / 6.0, int(cx) + 9)
            col = rock["lit" if lit else "shade"][1 if rib > 0.6 else 0]
            if who < 0:  # the low ridge between the peaks: one hazy tone
                col = rock["shade"][0] if _noise(x / 30.0, 12) > 0.35 else rock["lit"][1]
            # snow in the gullies, which run down the fall line of each face
            fall = ((y * 0.7) if lit else (-y * 0.7)) + 6.0 * _noise(y / 5.0, int(cx) + 13)
            gully = _noise((x + fall) / 7.0, int(cx) + 11)
            reach = (ht * snowline) * (0.4 + 0.8 * gully)
            if who >= 0 and depth < reach:
                if gully > (0.7 if not winter else 0.25) or (winter and depth < 8):
                    col = SNOW["lit" if lit else "shade"]
                    if not winter and depth > reach - 2:
                        col = SNOW["edge"]
            rgb[y, x] = col
        if 0 <= top < H:
            rgb[top, x] = SNOW["lit"] if (winter and owner[x] >= 0) else RIM
    # the middle ridge: lower, forested, granite outcrops, hazed
    for x in range(W):
        mtop = 60 + (_noise(x / 70.0, 21) - 0.5) * 28 + (_noise(x / 17.0, 22) - 0.5) * 8
        # granite domes standing out of it here and there
        dome = max(0.0, 1.0 - abs(((x + 140) % 380) - 190) / 70.0)
        mtop += dome * dome * 22 * _hash((x + 140) // 380, 23)
        top = H - int(mtop)
        for y in range(max(0, top), H):
            depth = y - top
            if dome > 0.25 and depth < dome * 22 * _hash((x + 140) // 380, 23):
                c = MID["rock"][0 if (x + 140) % 380 < 190 else 1]
                if winter and depth < 4:
                    c = MID["snow"]
            else:
                c = MID["forest"][2 if depth < 2 and _hash(x, 24) > 0.5 else (1 if _hash(x // 2, y // 2, 25) > 0.5 else 0)]
                # winter: snow lying on the crest and in the clearings
                if winter and (depth < 2 or _hash(x, y // 2, 26) > 0.86):
                    c = MID["snow"]
            rgb[y, x] = c
        # tree tips poking up from the forested crest
        if dome < 0.25 and _hash(x // 3, 27) > 0.5:
            tip = 2 + int(_hash(x // 3, 28) * 3)
            if x % 3 == 1:
                for k in range(tip):
                    if 0 <= top - 1 - k < H:
                        rgb[top - 1 - k, x] = MID["forest"][0]
    # the near forest: crowns along the bottom
    for x in range(W):
        ntop = 30 + (_noise(x / 25.0, 31) - 0.5) * 14
        top = H - int(ntop)
        tree = x // 5
        tip = int(_hash(tree, 32) * 7)
        off = abs(x % 5 - 2)
        top -= max(0, tip - off * 2)
        for y in range(max(0, top), H):
            k = 3 if (y - top < 2 and x % 5 <= 2) else (2 if x % 5 <= 1 else (1 if _hash(x, y // 3, 33) > 0.4 else 0))
            rgb[y, x] = NEAR[k]
    a = np.dstack([rgb, al])
    return Image.fromarray(a.repeat(2, 0).repeat(2, 1), "RGBA")


def main() -> None:
    for name, winter in (("skyline_summer", False), ("skyline_winter", True)):
        path = os.path.join(OUT, name + ".png")
        paint(winter).save(path, optimize=True)
        print("painted", os.path.relpath(path, ROOT))


if __name__ == "__main__":
    main()
