#!/usr/bin/env python3
"""Finishes Tuolumne's freestanding granite after masses.py has painted it
(Lembert Dome, Pothole Dome, Fairview Dome, Cathedral Peak, and Unicorn
Peak from unicorn.py), so the rock sits in the meadow's world of lit
lodgepoles instead of standing on it like a cut-out:

- the forest round the rock is lit like the scene's own lodgepoles (their
  greens, a lit tip on every crown, darker toward the forest floor), not
  one flat dark green;
- the foot ends in tree bases, trunks and gaps at uneven heights, not a
  ruled line across the bottom of the sprite;
- the outline low on the flanks gets a fringe of small pines, so the
  rock's sides don't end in long straight edges;
- a peak named in SHADE gets its faces split at the ridge: lit to the west
  (the light comes from the upper left), in shade to the east, as Cathedral
  Peak stands over the meadows in the afternoon.

Run once on the painter's output (it edits the PNGs in place; running it
twice would plant the fringe twice):

    python3 tools/art32/walls32/masses.py DUMP_DIR       # if repainting
    python3 tools/art32/walls32/masses_finish.py [names]
    python3 tools/normals/normals.py assets/sprites/tuolumne/NAME.png   # its normal map
    godot --headless --path . --import
"""
from __future__ import annotations

import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
DIR = os.path.join(ROOT, "assets", "sprites", "tuolumne")
NAMES = ["lembert_dome", "pothole_dome", "fairview_dome", "cathedral_peak"]

# the scene's lodgepoles (assets/sprites/ahwahnee/tree_lodgepole_*.png),
# darkest first
PINE = [(0x10, 0x24, 0x1A), (0x17, 0x32, 0x20), (0x20, 0x41, 0x27), (0x2B, 0x51, 0x2D),
        (0x38, 0x61, 0x34), (0x48, 0x72, 0x3B), (0x5B, 0x84, 0x43)]
BARK = [(0x1D, 0x15, 0x11), (0x2C, 0x20, 0x18), (0x3B, 0x2C, 0x22)]
# the granite ramp the painter uses, lightest first
ROCK = [(0xEE, 0xEA, 0xDC), (0xDF, 0xD9, 0xCB), (0xCC, 0xC6, 0xBA), (0xB7, 0xB2, 0xAA), (0xA0, 0x9D, 0x9A),
        (0x88, 0x88, 0x8A), (0x71, 0x73, 0x79), (0x5C, 0x5F, 0x69), (0x49, 0x4D, 0x59), (0x38, 0x3C, 0x48),
        (0x2A, 0x2D, 0x38)]
# Peaks whose east faces fall into shade: the ridge runs from the summit
# (found as the highest rock) down to this share of the width at the foot,
# and the shaded side is this many steps darker on the rock ramp.
SHADE = {"cathedral_peak": (0.66, 3)}
FOOT_BAND = 26  # rows at the bottom where the forest gets tree bases


def _hash(*v: int) -> float:
    h = 2166136261
    for x in v:
        h = ((h ^ (x & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF
    h ^= h >> 13
    h = (h * 1274126177) & 0xFFFFFFFF
    return (h & 0xFFFFFF) / float(0x1000000)


def _is_green(rgb: np.ndarray) -> np.ndarray:
    r, g, b = (rgb[..., i].astype(np.int32) for i in range(3))
    return (g > r + 6) & (g >= b) & (g < 140)


def _is_rock(rgb: np.ndarray, alpha: np.ndarray) -> np.ndarray:
    r, g, b = (rgb[..., i].astype(np.int32) for i in range(3))
    return (alpha > 0) & (np.abs(r - g) < 30) & (np.abs(g - b) < 40) & ~_is_green(rgb)


def relight_forest(a: np.ndarray) -> None:
    """The flat dark forest becomes lit lodgepoles: each green pixel takes a
    pine tone from its old brightness, a step lighter where the crown has
    open air or rock above (its lit tip) or to its upper left, a step darker
    low down where the forest closes over the floor."""
    rgb, al = a[..., :3], a[..., 3]
    green = _is_green(rgb) & (al > 0)
    h, w = green.shape
    lum = rgb[..., 1].astype(np.float32)
    # old forest greens run ~30..74 in green: spread them over the pine ramp
    t = np.clip((lum - 28.0) / 48.0, 0.0, 1.0)
    idx = np.rint(t * 3.0 + 1.0).astype(np.int32)  # 1..4
    above = np.zeros_like(green)
    above[2:, :] = ~green[:-2, :]
    upleft = np.zeros_like(green)
    upleft[2:, 2:] = ~green[:-2, :-2]
    idx += (above | upleft).astype(np.int32)
    idx += (above & upleft).astype(np.int32)
    # deeper in the forest band at the foot it grows darker, unevenly
    rows = np.arange(h)[:, None].repeat(w, 1)
    cols = np.arange(w)[None, :].repeat(h, 0)
    depth = np.clip((rows - (h - 30)) / 30.0, 0.0, 1.0)
    noise = ((cols // 2 * 73 + rows // 2 * 151) % 97) / 97.0
    idx -= ((depth > noise) & ~above).astype(np.int32)
    idx = np.clip(idx, 0, len(PINE) - 1)
    pal = np.array(PINE, np.uint8)
    rgb[green] = pal[idx[green]]


def ragged_foot(a: np.ndarray, sd: int) -> None:
    """Along the bottom, the forest stops at the ground tree by tree: each
    crown ends at its own height, with its trunk below it, and the ground
    shows between. Worked in 2x2 blocks, the painter's own pixel size."""
    rgb, al = a[..., :3], a[..., 3]
    h, w = al.shape
    green = _is_green(rgb) & (al > 0)
    x = 0
    k = 0
    while x < w:
        tw = 2 * (2 + int(_hash(k, 1, sd) * 3))  # 4..8 px across
        col = slice(x, min(w, x + tw))
        # only where the forest reaches the foot
        if green[h - FOOT_BAND:h - 4, col].mean() > 0.5:
            # most crowns come down to the ground; some stand on bare trunks
            r = _hash(k, 2, sd)
            lift = 0 if r < 0.4 else 2 * (1 + int((r - 0.4) / 0.6 * 5))  # 2..10 px
            if lift > 0:
                cut = h - lift
                al[cut:, col] = 0
                # the trunk, in the middle of the gap, and its shade on the left
                tx = x + tw // 2 - 1
                if lift >= 4 and tx + 2 <= w:
                    for yy in range(cut, h):
                        rgb[yy, tx] = BARK[1]
                        rgb[yy, tx + 1] = BARK[2] if yy % 4 else BARK[1]
                        al[yy, tx:tx + 2] = 255
                    rgb[cut, tx:tx + 2] = BARK[0]
                # the crown's skirt is in shade
                rgb[cut - 2:cut, col] = PINE[0]
                al[cut - 2:cut, col] = np.where(al[cut - 2:cut, col] > 0, 255, 0)
        x += tw
        k += 1
    # the painter's last rows of ruled dashes go
    al[h - 2:, :] = np.where(al[h - 2:, :] > 0, al[h - 2:, :], 0)


def flank_fringe(a: np.ndarray, sd: int) -> None:
    """Small pines along the bare outline low on the flanks, standing up out
    of the rock's edge, so its sides read as forested slope, not a cut line."""
    rgb, al = a[..., :3], a[..., 3]
    h, w = al.shape
    tops = np.full(w, h, np.int32)
    for x in range(w):
        ys = np.nonzero(al[:, x] > 0)[0]
        if len(ys):
            tops[x] = ys[0]
    summit = int(tops.min())
    for x in range(2, w - 2, 2):
        y = int(tops[x])
        if y >= h - 6:
            continue
        # only the lower part of the outline (the flanks)
        if (y - summit) < (h - summit) * 0.5:
            continue
        if _hash(x // 2, 3, sd) > 0.55:
            continue
        tall = 2 * (5 + int(_hash(x, 4, sd) * 5))  # 10..18 px
        for k in range(tall):
            half = (k * 2 // 5) // 2 * 2 // 2  # widens down the tree, in px
            yy = y + 2 - tall + k
            if yy < 0:
                continue
            for xx in range(x - half, x + half + 2):
                if 0 <= xx < w:
                    lit = xx <= x
                    tone = 5 if (k < 2 and lit) else (3 if lit else 1)
                    if k > tall - 3:
                        tone = max(0, tone - 1)
                    rgb[yy, xx] = PINE[tone]
                    al[yy, xx] = 255


def shade_east(a: np.ndarray, foot_share: float, steps: int) -> None:
    """The face east of the ridge (summit down to [foot_share] of the width)
    is in shade: its rock is [steps] darker on the granite ramp."""
    rgb, al = a[..., :3], a[..., 3]
    h, w = al.shape
    rock = _is_rock(rgb, al)
    ys, xs = np.nonzero(rock)
    top = ys.min()
    sx = float(xs[ys == top].mean())
    fx = foot_share * w
    ramp = np.array(ROCK, np.int32)
    flat = rgb.reshape(-1, 3).astype(np.int32)
    d = ((flat[:, None, :] - ramp[None, :, :]) ** 2).sum(-1)
    nearest = d.argmin(1).reshape(h, w)
    for y in range(top, h):
        f = (y - top) / max(1.0, h - top)
        ridge = sx + (fx - sx) * f
        # a wandering ridge, not a ruled one
        ridge += (_hash(y // 6, 7, 11) - 0.5) * 6.0
        for x in range(int(ridge), w):
            if not rock[y, x]:
                continue
            n = min(len(ROCK) - 1, int(nearest[y, x]) + steps)
            # right along the ridge, one step less: the edge catches light
            if x - ridge < 3:
                n = max(0, n - 1)
            rgb[y, x] = ROCK[n]


def finish(name: str) -> None:
    path = os.path.join(DIR, name + ".png")
    a = np.array(Image.open(path).convert("RGBA"))
    sd = sum(ord(c) for c in name)
    if name in SHADE:
        shade_east(a, *SHADE[name])
    flank_fringe(a, sd)
    relight_forest(a)
    ragged_foot(a, sd)
    Image.fromarray(a, "RGBA").save(path)
    print("finished", os.path.relpath(path, ROOT))


def main() -> None:
    names = sys.argv[1:] or NAMES
    for n in names:
        finish(n)


if __name__ == "__main__":
    main()
