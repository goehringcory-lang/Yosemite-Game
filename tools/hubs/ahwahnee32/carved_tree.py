#!/usr/bin/env python3
"""Paints the old black oak at the edge of the Tea Lawn, natively at 32px.

The Ahwahnee's head chef shows it to the player at the end of his side story
(data/quests/ahwahnee_chef_larder.tres). Two sprites, same size and anchor:

  assets/sprites/ahwahnee/carved_oak_hidden.png   wild grape hangs over the trunk
  assets/sprites/ahwahnee/carved_oak.png          the vine pulled aside: a face
                                                  carved into the bark

The canopy is the Ahwahnee's own black oak (tree_black_oak_a.png); the trunk
is painted here, older and wider, in the palette's bark and tan ramps. The
carving is a plain face with long hair, no regalia (see STORY.md, "Writing
guardrails"): what it shows and who made it are pending tribal review.

    python3 tools/hubs/ahwahnee32/carved_tree.py
    godot --headless --path . --import
"""
from __future__ import annotations

import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import kit  # noqa: E402

OUT = os.path.join(kit.ROOT, "assets", "sprites", "ahwahnee")
CANOPY = os.path.join(OUT, "tree_black_oak_a.png")

W = 184
H = 236
# The trunk: centre column, top (under the canopy) and the ground line.
CX = 92
TOP = 120
BASE = 230
# The carved panel on the trunk.
FACE_Y = 168


def _put(a: np.ndarray, x: int, y: int, c: str) -> None:
    if 0 <= x < a.shape[1] and 0 <= y < a.shape[0]:
        a[y, x, :3] = kit.C[c]
        a[y, x, 3] = 255


def _half_width(y: int) -> int:
    """The trunk flares at the root and narrows a little up into the crown."""
    t = (y - TOP) / (BASE - TOP)
    w = 17 + int(3 * t)
    if y > BASE - 14:
        w += (y - (BASE - 14)) // 2 + 1
    return w


def _trunk(a: np.ndarray) -> None:
    for y in range(TOP, BASE + 1):
        hw = _half_width(y)
        for x in range(CX - hw, CX + hw + 1):
            u = (x - (CX - hw)) / (2 * hw)  # 0 left .. 1 right
            # deep vertical furrows, wandering a little down the trunk
            furrow = (x + int(3 * kit.hash2(x // 5, y // 9, 3))) % 7
            c = "B2" if u < 0.3 else "B1" if u < 0.78 else "B0"
            if furrow == 0:
                c = kit.down(c)
            elif furrow in (2, 3) and u < 0.55 and kit.hash2(x, y // 3, 5) > 0.45:
                c = kit.up(c)
            if kit.hash2(x, y, 9) > 0.93:
                c = "G2" if u < 0.5 else "G1"  # grey lichen flecks
            _put(a, x, y, c)
        _put(a, CX - hw - 1, y, "K0")
        _put(a, CX + hw + 1, y, "K0")
    # roots into the grass
    for dx, length in ((-24, 7), (-14, 4), (15, 5), (25, 8)):
        for i in range(length):
            x = CX + dx + (i if dx > 0 else -i) // 2
            y = BASE - 2 + i // 3
            _put(a, x, y, "B2" if dx < 0 else "B1")
    for x in range(CX - 30, CX + 31):
        _put(a, x, BASE + 1, "K0")


def _carving(a: np.ndarray) -> None:
    """A face cut into the bark: pale inner wood, with dark grooves for the
    hair, brow, eyes, nose and mouth. Weathered, so the edges are soft."""
    rx, ry = 11, 17
    cy = FACE_Y
    # the panel where the bark was taken off
    for y in range(cy - ry - 2, cy + ry + 3):
        for x in range(CX - rx - 2, CX + rx + 3):
            d = ((x - CX) / (rx + 2)) ** 2 + ((y - cy) / (ry + 2)) ** 2
            if d <= 1.0:
                c = "T1" if x < CX + 4 else "T0"
                if d > 0.8:
                    c = "B2"  # the cut edge, a step into the bark
                elif x < CX - 3 and y < cy:
                    c = "T2"  # catching the light from the upper left
                if kit.hash2(x, y, 21) > 0.9 and d < 0.8:
                    c = kit.down(c)  # weathered grain
                _put(a, x, y, c)
    # long hair, falling past the shoulders on both sides
    for y in range(cy - 14, cy + 15):
        for side in (-1, 1):
            spread = 7 + min(3, max(0, (y - cy + 6) // 4))
            for k in range(2):
                x = CX + side * (spread + k)
                _put(a, x, y, "B0" if k == 0 else "B1")
    for x in range(CX - 7, CX + 8):  # hairline
        _put(a, x, cy - 14 + abs(x - CX) // 4, "B0")
    # brow
    for x in range(CX - 6, CX + 7):
        if x != CX:
            _put(a, x, cy - 7 + (1 if abs(x - CX) > 4 else 0), "B1")
    # eyes: short grooves under the brow
    for x in (CX - 5, CX - 4, CX - 3, CX + 3, CX + 4, CX + 5):
        _put(a, x, cy - 5, "B0")
    _put(a, CX - 4, cy - 4, "T0")
    _put(a, CX + 4, cy - 4, "T0")
    # nose: a ridge lit on its left, shadowed on its right
    for y in range(cy - 5, cy + 3):
        _put(a, CX - 1, y, "T2")
        _put(a, CX + 1, y, "B1")
    for x in range(CX - 2, CX + 3):
        _put(a, x, cy + 3, "B1")
    # mouth, calm and closed
    for x in range(CX - 3, CX + 4):
        _put(a, x, cy + 7, "B0")
    # cheekbones and jaw, cut shallow
    for y in range(cy + 1, cy + 11):
        _put(a, CX - 6 + (y - cy) // 4, y, "T0")
        _put(a, CX + 6 - (y - cy) // 4, y, "B2")
    for x in range(CX - 3, CX + 4):
        _put(a, x, cy + 12, "T0")
    # shoulders, a simple collar line at the foot of the panel
    for x in range(CX - 9, CX + 10):
        _put(a, x, cy + 16 - abs(x - CX) // 3, "B1")


def _vine(a: np.ndarray) -> None:
    """Wild grape hanging down over the carving, so you'd walk past it."""
    strands = (-14, -10, -6, -2, 2, 6, 10, 14)
    for i, sx in enumerate(strands):
        x = CX + sx
        for y in range(TOP + 4, FACE_Y + 22 + (i % 3) * 3):
            x += 1 if kit.hash2(i, y // 4, 31) > 0.7 else -1 if kit.hash2(i, y // 4, 32) > 0.7 else 0
            x = max(CX - 16, min(CX + 16, x))
            _put(a, x, y, "B1")
            # leaves: little clusters along the strand
            if kit.hash2(i, y, 33) > 0.4:
                for dx, dy in ((-1, 0), (1, 0), (0, -1), (-1, -1), (1, 1), (-2, 0), (2, 1), (0, 1), (-1, 1), (1, -1)):
                    if kit.hash2(x + dx, y + dy, 34) > 0.25:
                        lit = dx < 0 or dy < 0
                        shade = "M1" if lit else "P2"
                        if kit.hash2(x + dx, y + dy, 35) > 0.85:
                            shade = "M2" if lit else "P1"
                        _put(a, x + dx, y + dy, shade)


def paint(revealed: bool) -> np.ndarray:
    a = np.zeros((H, W, 4), dtype=np.uint8)
    _trunk(a)
    if revealed:
        _carving(a)
    else:
        _vine(a)
    canopy = np.array(Image.open(CANOPY).convert("RGBA"))
    # the crown sits over the top of the trunk: everything above the oak's
    # own trunk, so the new trunk shows below it
    crown = canopy[:136].copy()
    a[:136][crown[:, :, 3] > 0] = crown[crown[:, :, 3] > 0]
    if revealed:
        # the vine, pushed aside: a few strands hang at the trunk's edges
        for y in range(TOP + 4, TOP + 30):
            for x in (CX - 18, CX + 18):
                if kit.hash2(x, y, 40) > 0.4:
                    _put(a, x + (1 if kit.hash2(x, y, 41) > 0.5 else 0), y, "P2" if x > CX else "M1")
    return a


def main() -> None:
    for name, revealed in (("carved_oak_hidden", False), ("carved_oak", True)):
        Image.fromarray(paint(revealed), "RGBA").save(os.path.join(OUT, name + ".png"), optimize=True)
        print("painted", name)


if __name__ == "__main__":
    main()
