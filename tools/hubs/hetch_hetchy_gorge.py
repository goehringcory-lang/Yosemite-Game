#!/usr/bin/env python3
"""Paints the view down past O'Shaughnessy Dam's crest into the Tuolumne
gorge: assets/sprites/valley/hetch_hetchy_gorge.png (960x540, two screen
pixels to a painted pixel).

The vista shader (assets/shaders/vista.gdshader) shows it through the drop
west of the dam in Hetch Hetchy (tools/hubs/build_hetch_hetchy.gd's
_place_gorge). Looking down from the crest: the dam's curved downstream face
on the right, the outlet jets roaring out of its foot in a white plume, and
the river winding away west between dark granite walls, oaks and gray pines
on the ledges. The builder's GORGE_JETS animate the two jets.

  python3 tools/hubs/hetch_hetchy_gorge.py
"""
import math
import os
import random

import numpy as np
from PIL import Image

W, H = 480, 270
OUT = os.path.join(os.path.dirname(__file__), "../../assets/sprites/valley/hetch_hetchy_gorge.png")

GRANITE = ["2b2a30", "3d3c43", "514f55", "6a6a70", "85837f", "a29e96", "bdb8ae"]
SHADE = "1f2232"
CONCRETE = ["5d5c5a", "77756f", "908d85", "a9a59b", "c4bfb3", "dcd6c8"]
RIVER = ["1d4a52", "2a6a6c", "3f8a83", "6fb0a4"]
FOAM = ["9fd8d9", "d7ece6", "f5eee0"]
OAK = ["1d2e1e", "2c4228", "3f5a32", "5a7540"]
PINE = ["24331f", "35482a", "4c6233"]


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def vnoise(seed, scale):
    rng = np.random.default_rng(seed)
    gw, gh = W // scale + 3, H // scale + 3
    g = rng.random((gh, gw))
    ys, xs = np.mgrid[0:H, 0:W]
    fx, fy = xs / scale, ys / scale
    x0, y0 = fx.astype(int), fy.astype(int)
    ax, ay = fx - x0, fy - y0
    ax = ax * ax * (3 - 2 * ax)
    ay = ay * ay * (3 - 2 * ay)
    a = g[y0, x0] * (1 - ax) + g[y0, x0 + 1] * ax
    b = g[y0 + 1, x0] * (1 - ax) + g[y0 + 1, x0 + 1] * ax
    return a * (1 - ay) + b * ay


BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 + 1 / 32.0


def ramp(colors, t):
    """Dithered pick from a ramp by t in 0..1 (array)."""
    cols = np.array([rgb(c) for c in colors], np.uint8)
    n = len(colors)
    ys, xs = np.mgrid[0:H, 0:W]
    f = np.clip(t, 0, 0.999) * (n - 1)
    i = f.astype(int)
    frac = f - i
    i = i + (frac > BAYER[ys % 4, xs % 4])
    return cols[np.clip(i, 0, n - 1)]


def river_x(y):
    # The river leaves the plume at the dam's foot (right) and winds west,
    # dropping toward the bottom-left of the picture.
    return 185 - max(0, y - 150) * 1.5 - max(0, 150 - y) * 0.2 + 10 * math.sin(y * 0.07) + 5 * math.sin(y * 0.17 + 1.0)


def main():
    random.seed(1923)
    ys, xs = np.mgrid[0:H, 0:W].astype(float)
    big = vnoise(1, 40)
    mid = vnoise(2, 14)
    fine = vnoise(3, 4)
    # Granite: lit on ledges (high noise), dark in clefts; deeper = darker.
    depth = np.clip(ys / H, 0, 1)
    rx = np.array([river_x(y) for y in range(H)])[:, None]
    dist = np.abs(xs - rx)
    # The canyon walls fall toward the river: lighter far from it (tops of the
    # walls, nearer the eye), shadowed close to it (deep in the gorge).
    wall_t = np.clip(dist / 140.0, 0, 1)
    t = 0.15 + 0.55 * wall_t + 0.25 * (mid - 0.5) + 0.15 * (fine - 0.5) - 0.1 * depth
    # Vertical joints and streaks down the walls.
    streak = vnoise(4, 6)
    joints = (np.abs(np.sin(xs * 0.21 + big * 9.0)) > 0.96)
    t = t - 0.22 * joints - 0.08 * (streak > 0.72)
    img = ramp(GRANITE, t)
    # The shadow side: the south (lower) wall in shade.
    shade = (xs < rx) & (dist < 110) & (dist > 14)
    sh = np.array(rgb(SHADE), np.uint8)
    mask = shade & ((0.55 + 0.25 * (1 - dist / 110)) > BAYER[ys.astype(int) % 4, xs.astype(int) % 4])
    img[mask] = (img[mask] * 0.5 + sh * 0.5).astype(np.uint8)
    # River: deep green-blue with foam along riffles.
    below = ys > 172
    water = (dist < (9 + 4 * (1 - depth))) & below
    wt = 0.2 + 0.6 * vnoise(5, 5) + 0.2 * (1 - dist / 14)
    img[water] = ramp(RIVER, wt)[water]
    riffle = water & (vnoise(6, 3) > 0.8)
    img[riffle] = ramp(FOAM, vnoise(7, 2))[riffle]
    bank = (dist >= 9 + 4 * (1 - depth)) & (dist < 12 + 4 * (1 - depth)) & below
    img[bank] = ramp(["3b3a36", "5e574a", "7d7463"], fine)[bank]
    # Oaks and gray pines on the ledges, thicker far from the river.
    trees = (big > 0.58) & (mid > 0.55) & (dist > 30) & (fine > 0.35)
    img[trees] = ramp(OAK, mid * 0.6 + fine * 0.4)[trees]
    for _ in range(160):
        x = random.randrange(W)
        y = random.randrange(H)
        if abs(x - river_x(y)) < 35 or x > 190:
            continue
        c = [rgb(p) for p in PINE]
        for dy in range(6):
            half = max(0, (dy + 1) // 2)
            for dx in range(-half, half + 1):
                px, py = x + dx, y + dy
                if 0 <= px < W and 0 <= py < H:
                    img[py, px] = c[0 if dx < 0 else (2 if dx > 0 else 1)]
    # The dam's downstream face down the right side: curved concrete, lit,
    # with board-form lines, from x=200 to the edge; its foot at the river.
    face_x = 200 + 4 * np.sin(ys * 0.02)
    face = xs >= face_x
    ft = 0.35 + 0.4 * ((xs - face_x) / 280.0) + 0.12 * (fine - 0.5)
    lines = (ys.astype(int) % 9 == 0)
    ft = ft - 0.18 * lines
    img[face] = ramp(CONCRETE, ft)[face]
    edge = (xs >= face_x) & (xs < face_x + 2)
    img[edge] = rgb("3a3936")
    # The plume: spray from the outlet jets at the dam's foot, billowing
    # west and down over the river.
    plume_d = np.sqrt(((xs - 186) / 34.0) ** 2 + ((ys - 182) / 42.0) ** 2)
    plume_t = (1 - plume_d) + 0.6 * (vnoise(8, 9) - 0.5) + 0.25 * (vnoise(9, 4) - 0.5)
    pm = plume_t > 0.15
    img[pm] = ramp(FOAM, np.clip(plume_t * 1.4, 0, 1))[pm]
    soft = (plume_t > 0.0) & ~pm & ((plume_t * 4 + 0.3) > BAYER[ys.astype(int) % 4, xs.astype(int) % 4])
    img[soft] = (img[soft] * 0.4 + np.array(rgb(FOAM[1])) * 0.6).astype(np.uint8)
    out = Image.fromarray(img, "RGB").resize((W * 2, H * 2), Image.NEAREST)
    out.save(OUT)
    print("saved", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
