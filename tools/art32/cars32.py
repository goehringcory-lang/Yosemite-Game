#!/usr/bin/env python3
"""Paints the park's parked cars again, natively for the 32px game, into
assets/sprites/cars/ (Tuolumne Meadows keeps the old ones in
assets/sprites/curry/).

Each car is parked nose-in, seen from above and behind as the camera sees
everything: the hood and windshield up top, the roof with a sheen, the rear
window, then the tail with its lights, plate and bumper, and the tyres under
it. Five bodies (a sedan, a station wagon with a roof box, a pickup with gear
in the bed, a hatchback and a two-tone camper van), in the muted paints of a
real lot. They're drawn on art pixels of 2x2 and rounded off with Scale2x like
every other sprite, on the same canvas sizes as before, so the scenes'
offsets and collisions still fit.

    python3 tools/art32/cars32.py            # writes car_0..car_11.png
    python3 tools/art32/cars32.py sheet OUT  # all twelve side by side, 4x
"""
from __future__ import annotations

import colorsys
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
from pixel32 import scale2x  # noqa: E402

OUT = os.path.join(ROOT, "assets", "sprites", "cars")

# (width, height) in art pixels for each body, as the scenes expect.
SIZES = [(28, 42), (28, 46), (28, 46), (28, 40), (32, 58)]
PAINTS = ["3f6f99", "a33a30", "dedbd2", "3e5e48", "c49a4c", "a7a9a8", "6e2f33", "3e4247"]

OUTLINE = (29, 26, 30)
TYRE = (34, 33, 37)
TYRE_HI = (70, 68, 72)
CHROME = (200, 200, 194)
CHROME_DK = (122, 124, 126)
GLASS = [(31, 44, 58), (45, 66, 84), (70, 98, 118), (122, 156, 174), (186, 214, 224)]
TAIL = (178, 40, 36)
TAIL_HI = (240, 96, 72)
LAMP = (255, 236, 176)
PLATE = (232, 228, 214)
PLATE_DK = (60, 92, 140)


def _hex(h: str) -> tuple[int, int, int]:
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def ramp(base: str) -> list[tuple[int, int, int]]:
    """Five steps of a paint, darkest first: shadows cool, lights warm."""
    r, g, b = (v / 255.0 for v in _hex(base))
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    out = []
    for dl, dh, ds in ((-0.26, 0.03, 0.05), (-0.13, 0.015, 0.03), (0.0, 0.0, 0.0), (0.1, -0.012, -0.04), (0.2, -0.025, -0.1)):
        rr, gg, bb = colorsys.hls_to_rgb((h + dh) % 1.0, min(max(l + dl, 0.04), 0.96), min(max(s + ds, 0.0), 1.0))
        out.append((int(rr * 255), int(gg * 255), int(bb * 255)))
    return out


class Canvas:
    def __init__(self, w: int, h: int):
        self.w, self.h = w, h
        self.a = np.zeros((h, w, 4), np.uint8)

    def px(self, x: int, y: int, c) -> None:
        if 0 <= x < self.w and 0 <= y < self.h:
            self.a[y, x, :3] = c
            self.a[y, x, 3] = 255

    def rect(self, x: int, y: int, w: int, h: int, c) -> None:
        x0, y0, x1, y1 = max(x, 0), max(y, 0), min(x + w, self.w), min(y + h, self.h)
        if x0 < x1 and y0 < y1:
            self.a[y0:y1, x0:x1, :3] = c
            self.a[y0:y1, x0:x1, 3] = 255

    def hline(self, x: int, y: int, w: int, c) -> None:
        self.rect(x, y, w, 1, c)

    def vline(self, x: int, y: int, h: int, c) -> None:
        self.rect(x, y, 1, h, c)

    def clear(self, x: int, y: int) -> None:
        if 0 <= x < self.w and 0 <= y < self.h:
            self.a[y, x] = 0

    def outline(self) -> None:
        """A dark rim one pixel outside the silhouette (inside the canvas)."""
        op = self.a[:, :, 3] > 0
        p = np.pad(op, 1)
        near = p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:]
        rim = near & ~op
        self.a[rim, :3] = OUTLINE
        self.a[rim, 3] = 255


def body(cv: Canvas, x0: int, y0: int, w: int, h: int, P, round_top=True) -> None:
    """A slab of body panel lit from the upper left."""
    cv.rect(x0, y0, w, h, P[2])
    cv.vline(x0, y0, h, P[3])
    cv.vline(x0 + 1, y0, h, P[3])
    cv.vline(x0 + w - 2, y0, h, P[1])
    cv.vline(x0 + w - 1, y0, h, P[0])
    if round_top:
        cv.clear(x0, y0)
        cv.clear(x0 + w - 1, y0)


def glass(cv: Canvas, x0: int, y0: int, w: int, h: int, slope: int = 1, glint: int = 2) -> None:
    """Tinted glass, darkest at the bottom where it meets the body, with a
    diagonal streak of reflected sky."""
    for i in range(h):
        inset = max(0, (h - 1 - i) * slope // max(h, 1)) if slope > 0 else 0
        t = 1 + (i * 2) // max(h, 1)
        cv.hline(x0 + inset, y0 + i, w - inset * 2, GLASS[min(t, 2)])
    for i in range(h):
        x = x0 + glint + i
        if x < x0 + w - 2:
            cv.px(x, y0 + h - 1 - i, GLASS[3])
            cv.px(x + 1, y0 + h - 1 - i, GLASS[4] if i == h // 2 else GLASS[3])


def tail(cv: Canvas, x0: int, y0: int, w: int, P, h: int = 7) -> None:
    """The rear face: lights in the corners, a plate, the bumper, tyres."""
    cv.rect(x0, y0, w, h - 2, P[1])
    cv.hline(x0, y0, w, P[2])
    cv.vline(x0, y0, h - 2, P[2])
    cv.vline(x0 + w - 1, y0, h - 2, P[0])
    # tail lights
    cv.rect(x0 + 1, y0 + 1, 3, 2, TAIL)
    cv.px(x0 + 1, y0 + 1, TAIL_HI)
    cv.rect(x0 + w - 4, y0 + 1, 3, 2, TAIL)
    cv.px(x0 + w - 4, y0 + 1, TAIL_HI)
    # plate
    pw = 6
    px = x0 + (w - pw) // 2
    cv.rect(px, y0 + 1, pw, 3, PLATE)
    cv.hline(px + 1, y0 + 2, pw - 2, PLATE_DK)
    # bumper
    cv.rect(x0 - 1, y0 + h - 2, w + 2, 2, (58, 58, 62))
    cv.hline(x0, y0 + h - 2, w, (88, 88, 92))
    # tyres under the corners
    cv.rect(x0, y0 + h, 4, 2, TYRE)
    cv.rect(x0 + w - 4, y0 + h, 4, 2, TYRE)
    cv.hline(x0 + 1, y0 + h, 2, TYRE_HI)


def front(cv: Canvas, x0: int, w: int, P) -> None:
    """The nose, seen from above at the far end: bumper and headlamps."""
    cv.hline(x0 + 2, 0, w - 4, CHROME_DK)
    cv.rect(x0 + 1, 1, 3, 1, LAMP)
    cv.rect(x0 + w - 4, 1, 3, 1, LAMP)


def mirrors(cv: Canvas, x0: int, w: int, y: int, P) -> None:
    cv.rect(x0 - 1, y, 1, 2, P[1])
    cv.rect(x0 + w, y, 1, 2, P[0])


def front_tyres(cv: Canvas, x0: int, w: int, y: int) -> None:
    cv.rect(x0 - 1, y, 1, 5, TYRE)
    cv.rect(x0 + w, y, 1, 5, TYRE)


def sedan(cv: Canvas, P) -> None:
    W, H = cv.w, cv.h
    x0, w = 2, W - 4
    front_tyres(cv, x0, w, 5)
    body(cv, x0, 0, w, H - 9, P)
    front(cv, x0, w, P)
    # hood crease
    cv.vline(x0 + w // 2 - 3, 3, 6, P[3])
    cv.vline(x0 + w // 2 + 2, 3, 6, P[1])
    glass(cv, x0 + 2, 10, w - 4, 5)
    mirrors(cv, x0, w, 13, P)
    # roof with a sheen
    cv.rect(x0 + 3, 15, w - 6, 10, P[3])
    cv.hline(x0 + 4, 16, w - 10, P[4])
    cv.vline(x0 + 2, 15, 10, GLASS[2])
    cv.vline(x0 + w - 3, 15, 10, GLASS[0])
    glass(cv, x0 + 2, 25, w - 4, 6, slope=-1, glint=4)
    # trunk deck
    cv.rect(x0 + 1, 31, w - 2, 2, P[2])
    tail(cv, x0, H - 9, w, P)


def wagon(cv: Canvas, P) -> None:
    W, H = cv.w, cv.h
    x0, w = 2, W - 4
    front_tyres(cv, x0, w, 5)
    body(cv, x0, 0, w, H - 9, P)
    front(cv, x0, w, P)
    cv.vline(x0 + w // 2 - 3, 3, 5, P[3])
    glass(cv, x0 + 2, 9, w - 4, 5)
    mirrors(cv, x0, w, 12, P)
    # a long roof with rails and a cargo box
    cv.rect(x0 + 2, 14, w - 4, 16, P[3])
    cv.vline(x0 + 2, 14, 16, (40, 40, 44))
    cv.vline(x0 + w - 3, 14, 16, (40, 40, 44))
    bx, bw = x0 + 5, w - 10
    cv.rect(bx, 16, bw, 11, (54, 56, 60))
    cv.rect(bx + 1, 16, bw - 2, 10, (78, 82, 88))
    cv.hline(bx + 2, 17, bw - 5, (118, 124, 130))
    cv.vline(bx + 1, 17, 8, (98, 104, 110))
    glass(cv, x0 + 2, 30, w - 4, 5, slope=0, glint=5)
    tail(cv, x0, H - 9, w, P)


def pickup(cv: Canvas, P) -> None:
    W, H = cv.w, cv.h
    x0, w = 2, W - 4
    front_tyres(cv, x0, w, 5)
    body(cv, x0, 0, w, H - 9, P)
    front(cv, x0, w, P)
    cv.vline(x0 + w // 2, 3, 6, P[3])
    glass(cv, x0 + 2, 10, w - 4, 4)
    mirrors(cv, x0, w, 12, P)
    cv.rect(x0 + 3, 14, w - 6, 7, P[3])
    cv.hline(x0 + 4, 15, w - 9, P[4])
    glass(cv, x0 + 3, 21, w - 6, 2, slope=0, glint=3)
    # the bed: walls, a dark floor, and gear in it
    by = 23
    bh = H - 9 - by
    cv.rect(x0, by, w, bh, P[1])
    cv.rect(x0 + 2, by + 1, w - 4, bh - 1, (46, 42, 40))
    for y in range(by + 2, by + bh, 2):
        cv.hline(x0 + 2, y, w - 4, (56, 52, 48))
    # a cooler, a duffel and a coiled rope
    cv.rect(x0 + 3, by + 2, 7, 5, (230, 230, 226))
    cv.hline(x0 + 3, by + 2, 7, (64, 120, 168))
    cv.rect(x0 + 12, by + 3, 8, 4, (56, 92, 60))
    cv.hline(x0 + 12, by + 3, 8, (86, 128, 86))
    cv.rect(x0 + 5, by + 8, 5, 4, (196, 120, 40))
    cv.px(x0 + 7, by + 10, (120, 70, 24))
    tail(cv, x0, H - 9, w, P)


def hatchback(cv: Canvas, P) -> None:
    W, H = cv.w, cv.h
    x0, w = 2, W - 4
    front_tyres(cv, x0, w, 4)
    body(cv, x0, 0, w, H - 9, P)
    front(cv, x0, w, P)
    cv.vline(x0 + w // 2 - 2, 3, 4, P[3])
    glass(cv, x0 + 2, 7, w - 4, 6)
    mirrors(cv, x0, w, 11, P)
    cv.rect(x0 + 3, 13, w - 6, 10, P[3])
    cv.hline(x0 + 4, 14, w - 10, P[4])
    cv.vline(x0 + 2, 13, 10, GLASS[2])
    cv.vline(x0 + w - 3, 13, 10, GLASS[0])
    # a bike on the roof
    cv.hline(x0 + 5, 18, w - 10, (40, 40, 44))
    cv.rect(x0 + 6, 15, 3, 7, (36, 36, 40))
    cv.rect(x0 + w - 9, 15, 3, 7, (36, 36, 40))
    cv.vline(x0 + 7, 16, 5, (90, 90, 96))
    cv.vline(x0 + w - 8, 16, 5, (90, 90, 96))
    cv.hline(x0 + 8, 17, w - 16, (196, 64, 52))
    glass(cv, x0 + 2, 23, w - 4, 8, slope=0, glint=4)
    tail(cv, x0, H - 9, w, P)


def camper(cv: Canvas, P) -> None:
    """A two-tone camper van: paint below, cream above, a pop-top roof."""
    W, H = cv.w, cv.h
    x0, w = 2, W - 4
    cream = ramp("efe6cf")
    front_tyres(cv, x0, w, 4)
    body(cv, x0, 0, w, H - 10, P)
    front(cv, x0, w, P)
    # a short nose and a split windshield
    glass(cv, x0 + 2, 4, w - 4, 5)
    cv.vline(x0 + w // 2, 4, 5, P[2])
    mirrors(cv, x0, w, 7, P)
    # the cream upper body and the pop-top
    cv.rect(x0 + 1, 9, w - 2, H - 10 - 9 - 9, cream[2])
    cv.vline(x0 + 1, 9, H - 28, cream[3])
    cv.vline(x0 + w - 2, 9, H - 28, cream[1])
    cv.rect(x0 + 4, 12, w - 8, H - 34, cream[3])
    cv.hline(x0 + 5, 13, w - 12, cream[4])
    cv.hline(x0 + 4, 12 + H - 35, w - 8, cream[1])
    # roof vents and a rack with a surfboard-shaped kayak
    cv.rect(x0 + 6, 16, 4, 3, cream[1])
    cv.rect(x0 + w - 10, 30, 4, 3, cream[1])
    cv.rect(x0 + w // 2 - 2, 20, 5, 14, (210, 120, 40))
    cv.vline(x0 + w // 2 - 2, 21, 12, (240, 160, 70))
    cv.vline(x0 + w // 2 + 2, 21, 12, (160, 84, 28))
    cv.clear(x0 + w // 2 - 2, 20)
    cv.clear(x0 + w // 2 + 2, 20)
    # the rear window and the paint band above the tail
    glass(cv, x0 + 2, H - 19, w - 4, 4, slope=0, glint=5)
    cv.rect(x0, H - 15, w, 5, P[2])
    cv.vline(x0, H - 15, 5, P[3])
    cv.vline(x0 + w - 1, H - 15, 5, P[0])
    # the VW roundel's place: a spare tyre on the tail
    tail(cv, x0, H - 10, w, P, h=8)
    cv.rect(x0 + w // 2 - 3, H - 13, 6, 4, TYRE)
    cv.rect(x0 + w // 2 - 1, H - 12, 2, 2, TYRE_HI)


STYLES = [sedan, wagon, pickup, hatchback, camper]


def paint_car(i: int) -> np.ndarray:
    style = i % 5
    w, h = SIZES[style]
    cv = Canvas(w, h)
    P = ramp(PAINTS[(i * 3) % len(PAINTS)])
    # leave a pixel of margin all round for the outline
    inner = Canvas(w - 2, h - 2)
    STYLES[style](inner, P)
    cv.a[1:-1, 1:-1] = inner.a
    cv.outline()
    return scale2x(cv.a)


def main() -> None:
    if len(sys.argv) > 2 and sys.argv[1] == "sheet":
        cars = [paint_car(i) for i in range(12)]
        hmax = max(c.shape[0] for c in cars)
        sheet = Image.new("RGBA", (sum(c.shape[1] + 8 for c in cars), hmax + 8), (110, 112, 116, 255))
        x = 4
        for c in cars:
            sheet.alpha_composite(Image.fromarray(c, "RGBA"), (x, 4 + hmax - c.shape[0]))
            x += c.shape[1] + 8
        sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(sys.argv[2])
        return
    os.makedirs(OUT, exist_ok=True)
    for i in range(12):
        Image.fromarray(paint_car(i), "RGBA").save(os.path.join(OUT, f"car_{i}.png"))
    print("painted 12 cars into", os.path.relpath(OUT, ROOT))


if __name__ == "__main__":
    main()
