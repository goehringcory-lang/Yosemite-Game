#!/usr/bin/env python3
"""Paints Hetch Hetchy's entrance station: El Portal's Arch Rock station
(assets/sprites/el_portal/entrance_station.png and its _glow) with HETCHY
lettered on the board instead, to assets/sprites/valley/hetch_hetchy_entrance*.png.
Its normal map comes from tools/normals/normals.py.

  python3 tools/hubs/hetch_hetchy_entrance.py
"""
import os
from collections import Counter

from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "../..")
SRC = "assets/sprites/el_portal/entrance_station"
DST = "assets/sprites/valley/hetch_hetchy_entrance"
BOARD = (10, 44, 86, 54)  # x0, y0, x1, y1 of the lettering on the board
GLYPHS = {
    "H": ["##..##"] * 4 + ["######"] * 2 + ["##..##"] * 4,
    "E": ["######"] * 2 + ["##...."] * 2 + ["#####."] * 2 + ["##...."] * 2 + ["######"] * 2,
    "T": ["######"] * 2 + ["..##.."] * 8,
    "C": [".#####", "######"] + ["##...."] * 6 + ["######", ".#####"],
    "Y": ["##..##"] * 3 + [".####.", ".####."] + ["..##.."] * 5,
}


def main() -> None:
    im = Image.open(os.path.join(ROOT, SRC + ".png")).convert("RGBA")
    x0, y0, x1, y1 = BOARD
    light = (228, 221, 204, 255)
    board = Counter(im.getpixel((x, y)) for x in range(x0, x1) for y in range(y0, y1)
                    if sum(im.getpixel((x, y))[:3]) < 400).most_common(1)[0][0]
    for x in range(x0, x1):
        for y in range(y0, y1):
            if sum(im.getpixel((x, y))[:3]) > 400:
                im.putpixel((x, y), board)
    text = "HETCHY"
    width = len(text) * 8 - 2
    left = (x0 + x1) // 2 - width // 2
    for i, ch in enumerate(text):
        for gy, row in enumerate(GLYPHS[ch]):
            for gx, c in enumerate(row):
                if c == "#":
                    im.putpixel((left + i * 8 + gx, y0 + gy), light)
    im.save(os.path.join(ROOT, DST + ".png"))
    glow = os.path.join(ROOT, SRC + "_glow.png")
    if os.path.exists(glow):
        Image.open(glow).save(os.path.join(ROOT, DST + "_glow.png"))
    print("saved", DST)


if __name__ == "__main__":
    main()
