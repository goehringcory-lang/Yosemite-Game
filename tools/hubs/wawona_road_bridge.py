#!/usr/bin/env python3
"""Paints the Wawona Road's bridge over the South Fork of the Merced.

Highway 41 crosses the South Fork just north of the Wawona Hotel on a
concrete bridge, but the Wawona map drew the road straight through the
river, with the water foaming against the asphalt on both sides as if it
were dammed. This paints the bridge's two concrete parapets (posts, a lit
cap, end blocks on the banks) and the shade they throw on the water, as one
sprite the Wawona story overlay stands over the road
(scenes/story/content/wawona.tscn, RoadBridge).

    python3 tools/hubs/wawona_road_bridge.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/sprites/wawona/road_bridge.png"

W, H = 106, 144
# Each parapet's left edge and width, across the sprite (the road runs
# between them, x 14 .. 86; the right one also hides the foam along the asphalt).
PARAPETS = [(0, 14), (86, 14)]
# Rows of the end blocks on each bank.
END = 14

CAP = (206, 202, 186)
LIT = (176, 172, 155)
BODY = (158, 155, 140)
SHADE = (118, 114, 104)
DEEP = (78, 74, 68)
JOINT = (96, 92, 84)
WATER_SHADE = (20, 40, 46, 110)


def main() -> None:
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = im.load()
    for x0, w in PARAPETS:
        # shade thrown on the water to the right of each parapet (sun from the upper left)
        for y in range(END, H - END):
            for dx in range(4):
                x = x0 + w + dx
                if x < W and px[x, y][3] == 0:
                    px[x, y] = WATER_SHADE
        for y in range(H):
            end = y < END or y >= H - END
            for dx in range(w):
                x = x0 + dx
                if dx == 0:
                    c = LIT
                elif dx == w - 1:
                    c = DEEP
                elif dx == w - 2:
                    c = SHADE
                elif dx <= 2:
                    c = CAP
                else:
                    c = BODY
                # posts every 16 rows, and the expansion joints at the ends
                if not end and y % 16 == 0:
                    c = JOINT if 0 < dx < w - 1 else c
                if end and (y == END - 1 or y == H - END):
                    c = DEEP
                px[x, y] = (*c, 255)
            # a top and bottom edge to the whole run
        for dx in range(w):
            px[x0 + dx, 0] = (*CAP, 255)
            px[x0 + dx, H - 1] = (*DEEP, 255)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    im.save(OUT, optimize=True)
    print("wrote", OUT.relative_to(ROOT))


if __name__ == "__main__":
    main()
