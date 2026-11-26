#!/usr/bin/env python3
"""Paints the rock over the Wapama trail tunnel at O'Shaughnessy Dam's north
end: assets/sprites/valley/hetch_hetchy_tunnel_roof.png.

The knob's cliff face in hetch_hetchy_wall.png stops where the tunnel runs
(tiles 22-29, row 19-20 in tools/hubs/build_hetch_hetchy.gd). This carries
the same granite on down over the tunnel, so the trail goes into the rock:
a dark portal at each end with a concrete collar and a lamp, and the rock's
contact shadow along its foot. scenes/story/dressing/hetch_hetchy.tscn hangs
it over the tunnel (scripts/world/tunnel_roof.gd fades it while you're inside).
Run after the wall is rebuilt (tools/hubs/rebuild_hetch_hetchy.sh).

  python3 tools/hubs/hetch_hetchy_tunnel.py
"""
import os

from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "../..")
WALL = os.path.join(ROOT, "assets/sprites/valley/hetch_hetchy_wall.png")
OUT = os.path.join(ROOT, "assets/sprites/valley/hetch_hetchy_tunnel_roof.png")
X0, X1 = 704, 960  # the knob, in region pixels
TOP = 568  # where the roof starts (over the face's foot)
H = 120  # down past the tunnel's south side
SRC_TOP = 440  # granite rows of the face to carry down

DARK = (24, 24, 30, 255)
MOUTH = [(36, 36, 44, 255), (52, 51, 58, 255), (70, 69, 74, 255)]
COLLAR = [(150, 146, 136, 255), (196, 190, 176, 255), (110, 107, 100, 255)]
LAMP = (255, 214, 140, 255)


def main() -> None:
    wall = Image.open(WALL).convert("RGBA")
    w = X1 - X0
    im = Image.new("RGBA", (w, H))
    src = wall.crop((X0, SRC_TOP, X1, SRC_TOP + H))
    for y in range(H):
        for x in range(w):
            r, g, b, a = src.getpixel((x, y))
            if a < 255:
                r, g, b = wall.getpixel((X0 + (x * 7) % w, SRC_TOP - 40 + y % 40))[:3]
            im.putpixel((x, y), (r, g, b, 255))
    # Soft top edge, so the roof melts into the face above it.
    for y in range(10):
        for x in range(w):
            if (x * 5 + y * 3) % 10 >= y:
                im.putpixel((x, y), (0, 0, 0, 0))
    # The rock's foot: a dark contact line and its shadow.
    for x in range(w):
        for y in range(H - 6, H):
            p = im.getpixel((x, y))
            k = 0.45 if y < H - 2 else 0.25
            im.putpixel((x, y), (int(p[0] * k), int(p[1] * k), int(p[2] * k), 255))
    # Portals at each end, at the tunnel's rows (608-672 in the region).
    t0, t1 = 608 - TOP, 672 - TOP
    for side in (0, 1):
        for i in range(14):
            x = i if side == 0 else w - 1 - i
            for y in range(t0 - 6, t1 + 2):
                if i < 3:
                    col = COLLAR[0 if y % 6 else 2]
                elif i < 5:
                    col = COLLAR[1]
                else:
                    depth = min(2, (i - 5) // 3)
                    col = MOUTH[2 - depth] if y > t0 else COLLAR[2]
                    if i > 10:
                        col = DARK
                im.putpixel((x, y), col)
        # A lamp over each mouth.
        lx = 8 if side == 0 else w - 9
        for dx in (-1, 0, 1):
            for dy in (0, 1):
                im.putpixel((lx + dx, t0 - 10 + dy), LAMP)
    im.save(OUT)
    print("saved", os.path.relpath(OUT, ROOT))
    floor()


FLOOR_OUT = os.path.join(ROOT, "assets/sprites/valley/hetch_hetchy_tunnel_floor.png")
FLOOR = [(38, 38, 44, 255), (46, 46, 52, 255), (56, 55, 60, 255), (70, 68, 70, 255)]
POOL = (92, 84, 70, 255)


def floor() -> None:
    """The tunnel's own floor, laid over the boulders at the cliff's foot:
    worn dark concrete, wet in streaks, with warm pools under the lamps."""
    w, h = X1 - X0, 84
    im = Image.new("RGBA", (w, h))
    for y in range(h):
        for x in range(w):
            n = (x * 37 + y * 91 + (x * y) % 13) % 17
            col = FLOOR[1] if n > 4 else FLOOR[0]
            if n == 16:
                col = FLOOR[2]
            if y < 3 or y > h - 4:
                col = FLOOR[0]
            if (x // 32) % 4 == 2 and 30 < y < 54 and (x + y) % 2 == 0:
                col = FLOOR[3]
            for lx in (14, w // 2, w - 15):
                if (x - lx) ** 2 / 400 + (y - h / 2) ** 2 / 300 < 1 and (x + y) % 2 == 0:
                    col = POOL
            im.putpixel((x, y), col)
    im.save(FLOOR_OUT)
    print("saved", os.path.relpath(FLOOR_OUT, ROOT))


if __name__ == "__main__":
    main()
