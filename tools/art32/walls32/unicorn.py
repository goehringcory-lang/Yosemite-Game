#!/usr/bin/env python3
"""Paints Unicorn Peak for Tuolumne Meadows, standing behind Cathedral
Peak's east shoulder: its true skyline (the lidar silhouette skylines.py
measured for the climbing screen, in scripts/climb/art/landmark_shapes.gd),
drawn taller than life like the other masses, lit column by column from
that measurement's facing, sheer where it measured cliff, with lodgepoles
climbing its gentler flanks.

USGS heights are out of reach from the cloud sessions, so this reuses the
measured skyline instead of rendering the lidar again as masses.py does.

    python3 tools/art32/walls32/unicorn.py
    python3 tools/art32/walls32/masses_finish.py unicorn_peak
    python3 tools/normals/normals.py assets/sprites/tuolumne/NAME.png   # its normal map
    godot --headless --path . --import
"""
from __future__ import annotations

import os
import re

import numpy as np
from PIL import Image

import masses_finish as MF

ROOT = MF.ROOT
OUT = os.path.join(MF.DIR, "unicorn_peak.png")
SHAPES = os.path.join(ROOT, "scripts", "climb", "art", "landmark_shapes.gd")
# canvas, in art pixels (each 2x2 on screen, the painter's pixel size)
W, H = 190, 124
ROCK_H = 104  # art rows from the foot to the summit
FOOT = 3


def _shape(name: str) -> dict:
    src = open(SHAPES).read()
    block = src[src.index('"%s": {' % name):]
    block = block[:block.index("\n\t},")]
    out = {}
    for key in ("top", "tone", "steep"):
        m = re.search(r'"%s": \[([^\]]*)\]' % key, block)
        out[key] = np.array([float(v) for v in m.group(1).split(",")], np.float32)
    return out


def _resample(v: np.ndarray, n: int) -> np.ndarray:
    # drop the empty samples at the ends, then stretch over n columns
    nz = np.nonzero(v["top"] > 0)[0]
    lo, hi = nz[0], nz[-1]
    out = {}
    for k, arr in v.items():
        a = arr[lo:hi + 1]
        xs = np.linspace(0, len(a) - 1, n)
        out[k] = np.interp(xs, np.arange(len(a)), a)
    return out


def paint() -> Image.Image:
    sh = _shape("unicorn_peak")
    margin = 8
    cols = W - 2 * margin
    s = _resample(sh, cols)
    # the horn: the skyline's highest point drawn up into the spire that
    # names the peak, the rest of the ridge kept low beside it
    cmax = int(np.argmax(s["top"]))
    cc = np.arange(cols)
    s["top"] = s["top"] ** 1.6 * 0.82 + 0.3 * np.exp(-(((cc - cmax) / (0.035 * cols)) ** 2))
    s["steep"] = np.maximum(s["steep"], np.exp(-(((cc - cmax) / (0.03 * cols)) ** 2)))
    base = H - FOOT
    rgb = np.zeros((H, W, 3), np.uint8)
    al = np.zeros((H, W), np.uint8)
    tops = np.full(W, H, np.int32)
    ramp = MF.ROCK
    for c in range(cols):
        x = c + margin
        # ease the ends down into the forest, as the masses' flanks do
        edge = min(c / (cols * 0.12), (cols - 1 - c) / (cols * 0.06))
        ease = min(1.0, 0.1 + 0.9 * edge)
        t = s["top"][c] * ease
        top = int(round(base - (0.18 * ease + 0.82 * t) * ROCK_H))
        tops[x] = top
        tone = float(s["tone"][c])
        steep = float(s["steep"][c])
        for y in range(top, H):
            up = (base - y) / ROCK_H
            # lit from the column's facing, a little lighter high up
            lv = tone * 0.85 + up * 0.15
            n = MF._hash(x // 2, y // 3, 5) - 0.5
            lv += n * 0.08
            # sheer columns: darker, streaked down their faces
            if steep > 0.45:
                lv -= 0.08
                if MF._hash(x, 9, 6) > 0.8 and MF._hash(x, y // 6, 14) > 0.4:
                    lv -= 0.18
            # sheeting joints across the gentler rock
            elif (y + int(MF._hash(x // 5, 1, 7) * 4)) % 9 == 0 and MF._hash(x // 3, y // 9, 8) > 0.5:
                lv -= 0.14
            i = int(np.clip(round((1.0 - lv) * 8.0) + 2, 0, 10))
            rgb[y, x] = ramp[i]
            al[y, x] = 255
    # a dark rim round the silhouette
    for x in range(W):
        if tops[x] < H:
            rgb[tops[x], x] = ramp[8]
    for y in range(H):
        row = np.nonzero(al[y])[0]
        if len(row):
            rgb[y, row[0]] = ramp[7]
            rgb[y, row[-1]] = ramp[9]
    # the forest: up the lower flanks in a ragged line, and scattered on
    # the gentle granite above it
    for c in range(cols):
        x = c + margin
        steep = float(s["steep"][c])
        h_col = base - tops[x]
        line = base - int(h_col * (0.22 + 0.2 * MF._hash(x // 4, 2, 11)) * (0.5 if steep > 0.5 else 1.0))
        for y in range(max(tops[x] + 2, line), H):
            rgb[y, x] = MF.PINE[2 if MF._hash(x, y, 12) > 0.4 else 1]
            al[y, x] = 255
    for k in range(70):
        x = margin + int(MF._hash(k, 1, 13) * cols)
        c = x - margin
        if not 0 <= c < cols or s["steep"][c] > 0.35:
            continue
        y = int(base - (base - tops[x]) * MF._hash(k, 2, 13) * 0.75)
        tall = 3 + int(MF._hash(k, 3, 13) * 4)
        for j in range(tall):
            half = j // 2
            yy = y - tall + j
            if yy <= tops[x] + 1:
                continue
            for xx in range(x - half, x + half + 1):
                if 0 <= xx < W and al[yy, xx]:
                    rgb[yy, xx] = MF.PINE[4 if xx < x else 2]
    a = np.dstack([rgb, al])
    big = a.repeat(2, 0).repeat(2, 1)
    return Image.fromarray(big, "RGBA")


def main() -> None:
    paint().save(OUT)
    print("painted", os.path.relpath(OUT, ROOT))


if __name__ == "__main__":
    main()
