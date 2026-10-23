"""The park's shared interior furniture, painted natively at 32px: seating,
beds, tables, counters, desks, pianos, cases and the like that the Village,
Curry, Glacier Point, El Portal, Wawona and Tuolumne rooms share. Each piece
is drawn into the canvas size the interior builder gave it, seen in 3/4 from
the front and lit from the upper left, with a dark rim round it, in the
Valley Days palette (tools/hubs/ahwahnee32/kit.py).

    python3 tools/hubs/interiors32/furniture.py     # paints every piece in place
"""
from __future__ import annotations

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "ahwahnee32"))
sys.path.insert(0, HERE)

from kit import ROOT, Canvas, down, hash2, math, np, up  # noqa: E402

# Wood ramps, dark to light: walnut, stained oak, honey fir and pale pine.
WALNUT = ["B0", "B1", "B2", "B3"]
OAK = ["B1", "B2", "B3", "T1"]
HONEY = ["B2", "B3", "T1", "T2"]
PINE = ["B3", "T1", "T2", "T3"]
# Upholstery, dark to light.
LODGE_GREEN = ["P0", "P1", "P2", "P3"]
OLD_GOLD = ["O0", "O1", "O2", "O3"]
LEATHER = ["B0", "B1", "B2", "B3"]
VELVET = ["B1", "R", "R", "A1"]
CHINTZ = ["T1", "T2", "T3", "N"]
BRASS = ["O0", "O1", "O2", "O3"]


# ---------------------------------------------------------------- helpers

def rrect(cv: Canvas, x: int, y: int, w: int, h: int, c, r: int = 2) -> None:
    """A rectangle with its corners rounded off by r pixels."""
    cv.rect(x + r, y, w - 2 * r, h, c)
    cv.rect(x, y + r, w, h - 2 * r, c)
    for k in range(r):
        inset = r - int(math.sqrt(max(0, r * r - (r - k - 0.5) ** 2)) + 0.5)
        cv.hline(x + inset, y + k, w - 2 * inset, c)
        cv.hline(x + inset, y + h - 1 - k, w - 2 * inset, c)


def finish(cv: Canvas, rim: str = "B0", light: bool = True) -> Canvas:
    if light:
        cv.rim(0.6, -0.6)
    cv.outline(rim)
    return cv


def legs(cv: Canvas, xs: list[int], y: int, h: int, ramp=WALNUT, w: int = 3) -> None:
    for x in xs:
        cv.rect(x, y, w, h, ramp[1])
        cv.vline(x, y, h, ramp[2])
        cv.hline(x, y + h - 1, w, ramp[0])


def grain(cv: Canvas, x: int, y: int, w: int, h: int, ramp, seed: int, every: int = 3, vertical=False) -> None:
    """Fills with the ramp's body tone and draws long grain streaks."""
    cv.rect(x, y, w, h, ramp[1])
    if vertical:
        for gx in range(x + 1, x + w - 1, every):
            for gy in range(y, y + h):
                v = hash2(gx, gy // 5, seed)
                if v > 0.72:
                    cv.px(gx, gy, ramp[2])
                elif v < 0.12:
                    cv.px(gx, gy, ramp[0])
        return
    for gy in range(y + 1, y + h - 1, every - 1 if every > 2 else 2):
        for gx in range(x, x + w):
            v = hash2(gx // 7, gy, seed)
            if v > 0.74:
                cv.px(gx, gy, ramp[2])
            elif v < 0.1:
                cv.px(gx, gy, ramp[0])


def slab(cv: Canvas, x: int, y: int, w: int, h: int, ramp, seed: int, planks: int = 0) -> None:
    """A table or counter top seen from above: grained, a lit front edge and
    lit back edge, optional plank joints running along it."""
    grain(cv, x, y, w, h, [ramp[1], ramp[2], ramp[3]], seed)
    cv.hline(x + 1, y, w - 2, ramp[3])
    if planks:
        for k in range(1, planks):
            jy = y + round(h * k / planks)
            cv.hline(x + 1, jy, w - 2, ramp[1])
            for jx in range(x + 6 + int(hash2(k, 1, seed) * 30), x + w - 4, 48 + int(hash2(k, 2, seed) * 30)):
                cv.vline(jx, jy - round(h / planks) + 1, round(h / planks) - 1, ramp[1])
    cv.hline(x, y + h - 1, w, ramp[3])


def apron(cv: Canvas, x: int, y: int, w: int, h: int, ramp) -> None:
    """The front edge band under a top."""
    cv.rect(x, y, w, h, ramp[1])
    cv.hline(x, y, w, ramp[0])
    cv.hline(x, y + h - 1, w, ramp[0])


def panels(cv: Canvas, x: int, y: int, w: int, h: int, ramp, n: int, seed: int) -> None:
    """A front face of raised panels: rails and stiles, each panel bevelled,
    lit upper-left and shaded lower-right."""
    grain(cv, x, y, w, h, ramp, seed, every=5, vertical=True)
    pw = w / n
    for i in range(n):
        px0 = int(x + i * pw) + 4
        px1 = int(x + (i + 1) * pw) - 4
        py0, py1 = y + 4, y + h - 4
        if px1 - px0 < 6 or py1 - py0 < 4:
            continue
        cv.rect(px0, py0, px1 - px0, py1 - py0, ramp[2])
        grain(cv, px0 + 2, py0 + 2, px1 - px0 - 4, py1 - py0 - 4, [ramp[1], ramp[2], ramp[3]], seed + i, every=6, vertical=True)
        # a soft sheen down the panel's lit side
        cv.vline(px0 + 2, py0 + 2, py1 - py0 - 4, ramp[3])
        cv.hline(px0, py0, px1 - px0, ramp[0])
        cv.vline(px0, py0, py1 - py0, ramp[0])
        cv.hline(px0 + 1, py1 - 1, px1 - px0 - 1, ramp[3])
        cv.vline(px1 - 1, py0 + 1, py1 - py0 - 1, ramp[3])
    cv.hline(x, y, w, ramp[0])


def drawer(cv: Canvas, x: int, y: int, w: int, h: int, ramp) -> None:
    cv.rect(x, y, w, h, ramp[2])
    cv.hline(x, y, w, ramp[3])
    cv.hline(x, y + h - 1, w, ramp[0])
    cv.vline(x + w - 1, y, h, ramp[0])
    kx = x + w // 2 - 2
    cv.rect(kx, y + h // 2 - 1, 4, 2, "O1")
    cv.px(kx, y + h // 2 - 1, "O3")


def book_row(cv: Canvas, x0: int, x1: int, base: int, seed: int, maxh: int = 10) -> None:
    """Spines standing on a shelf at y = base, with the odd one leaning."""
    cols = ["R", "P1", "W1", "O1", "B1", "A0", "P2", "T1", "W2", "L"]
    x = x0
    k = 0
    while x < x1 - 2:
        bw = 2 + int(hash2(k, 1, seed) * 2.2)
        bh = maxh - 3 + int(hash2(k, 2, seed) * 4)
        c = cols[int(hash2(k, 3, seed) * len(cols))]
        if hash2(k, 4, seed) > 0.9 and x + 6 < x1:
            # one leaning over
            for s in range(bh):
                cv.hline(x + s // 3, base - 1 - s, 3, c)
            x += 6
            k += 1
            continue
        bw = min(bw, x1 - x)
        cv.rect(x, base - bh, bw, bh, c)
        cv.vline(x, base - bh, bh, up(c))
        if bw > 2:
            cv.vline(x + bw - 1, base - bh, bh, down(c))
        cv.px(x + bw // 2, base - bh + 2, "O2" if c not in ("O1",) else "N")
        x += bw
        k += 1


# ---------------------------------------------------------------- seating

def upholstered(ramp, *, arms: int = 13, pattern: str | None = None, frame=None, crest: bool = False,
                buttons: bool = True, cushions: int = 0, pillow=None):
    """A sofa or armchair seen from the front: a back with buttoned tufting,
    seat cushions, rolled arms, a skirt and turned legs. pattern: 'dots' (a
    woven figure), 'rose' (chintz roses); frame: a show-wood ramp for a
    carved crest rail (the Victorian parlor pieces)."""
    def paint(w: int, h: int) -> Canvas:
        cv = Canvas(w, h)
        d0, d1, d2, d3 = ramp
        x0, x1 = 2, w - 2
        top = 3
        if crest and frame:
            # a carved show-wood crest over a camel back
            cx = w // 2
            for xx in range(x0 + 6, x1 - 6):
                u = (xx - cx) / ((x1 - x0) / 2 - 6)
                yy = top + int(5 * u * u)
                cv.vline(xx, yy, 4, frame[1])
                cv.px(xx, yy, frame[3])
            cv.ellipse(cx, top, 5, 3, frame[2])
            cv.px(cx - 1, top - 1, frame[3])
            cv.px(cx, top + 1, frame[0])
            top += 3
        # the back
        bx0, bx1 = x0 + 5, x1 - 5
        if crest:
            for xx in range(bx0, bx1):
                u = (xx - w / 2) / ((bx1 - bx0) / 2)
                yy = top + int(5 * u * u)
                cv.vline(xx, yy, 22 - (yy - top), d1)
                cv.hline(xx, yy, 1, d3)
                cv.px(xx, yy + 1, d2)
        else:
            rrect(cv, bx0, top, bx1 - bx0, 19, d1, 4)
            cv.rect(bx0 + 3, top + 1, bx1 - bx0 - 6, 3, d2)
            cv.hline(bx0 + 4, top + 1, bx1 - bx0 - 8, d3)
        # soft modelling of the back: lit at the top, a shade where it meets the seat
        d = np.zeros((h, w), np.float32)
        d[top + 13:top + 19, :] = -0.5
        cv.tone(d)
        if buttons:
            for row, by in enumerate((top + 8, top + 13)):
                for bx in range(bx0 + 8 + (5 if row else 0), bx1 - 6, 10):
                    cv.px(bx, by, d0)
                    cv.px(bx - 1, by - 1, d3 if not pattern else d2)
                    # diamond pleats between the buttons
                    cv.px(bx + 2, by + 2, d0 if row == 0 else d2)
                    cv.px(bx - 3, by + 2, d0 if row == 0 else d2)
        if pattern == "rose":
            for i, rx in enumerate(range(bx0 + 7, bx1 - 5, 13)):
                ry = top + 8 + (4 if i % 2 else 0)
                cv.ellipse(rx, ry, 2.5, 2, "S")
                cv.px(rx, ry, "R")
                cv.px(rx - 1, ry - 1, "N")
                cv.px(rx + 3, ry + 1, "P2")
                cv.px(rx - 3, ry + 2, "P2")
        # seat cushions
        sy = top + 18
        n = cushions or max(1, (bx1 - bx0 - 2 * arms + 10) // 32)
        cw = (x1 - x0 - 2 * arms + 4) / n
        for i in range(n):
            cx = int(x0 + arms - 2 + i * cw)
            rrect(cv, cx, sy, int(cw) - 1, 11, d2, 2)
            cv.hline(cx + 2, sy, int(cw) - 5, d3)
            cv.hline(cx + 2, sy + 1, int(cw) - 5, d3 if i == 0 else d2)
            cv.hline(cx + 1, sy + 10, int(cw) - 3, d1)
            cv.vline(cx + int(cw) - 2, sy + 2, 8, d1)
        if pattern == "dots":
            for gy in range(top + 6, sy + 9, 5):
                for gx in range(bx0 + 4 + (gy % 2) * 3, bx1 - 4, 6):
                    if cv.a[gy, gx, 3]:
                        cv.px(gx, gy, "O3")
        if pattern == "rose":
            for k in range(n * 2):
                rx = int(x0 + arms + 4 + hash2(k, 1, 7) * (x1 - x0 - 2 * arms - 8))
                ry = sy + 3 + int(hash2(k, 2, 7) * 5)
                cv.px(rx, ry, "S")
                cv.px(rx + 1, ry, "S")
                cv.px(rx, ry + 1, "R")
        # front skirt, with welting along its top and a ruched edge
        fy = sy + 11
        cv.rect(x0 + arms - 3, fy, x1 - x0 - 2 * arms + 6, h - fy - 5, d1)
        cv.hline(x0 + arms - 3, fy, x1 - x0 - 2 * arms + 6, d3)
        cv.hline(x0 + arms - 3, h - 6, x1 - x0 - 2 * arms + 6, d0)
        if frame:
            # a carved apron rail of show wood
            cv.rect(x0 + arms - 3, h - 9, x1 - x0 - 2 * arms + 6, 4, frame[1])
            cv.hline(x0 + arms - 3, h - 9, x1 - x0 - 2 * arms + 6, frame[3])
            for k in range(x0 + arms, x1 - arms, 6):
                cv.px(k, h - 7, frame[0])
        else:
            for k in range(x0 + arms, x1 - arms, 4):
                cv.px(k, h - 7, d0)
        # rolled arms
        for side, ax in ((0, x0), (1, x1 - arms)):
            rrect(cv, ax, top + 7, arms, h - top - 12, d1, 4)
            rrect(cv, ax + 1, top + 7, arms - 2, 7, d2, 3)
            cv.hline(ax + 3, top + 8, arms - 6, d3)
            cv.ellipse(ax + arms / 2, top + 10, arms / 2 - 3, 2, d3 if side == 0 else d2)
            cv.px(int(ax + arms / 2), top + 10, d1)
            cv.vline(ax + (arms - 2 if side == 0 else 1), top + 14, h - top - 21, d0)
            if pattern == "dots":
                for gy in range(top + 16, h - 8, 5):
                    cv.px(ax + arms // 2, gy, "O3")
            if frame:
                cv.rect(ax + 1, top + 13, arms - 2, 2, frame[2])
                cv.hline(ax + 1, top + 13, arms - 2, frame[3])
        if pillow:
            for i, pc in enumerate(pillow):
                px = x0 + arms + 2 if i == 0 else x1 - arms - 14
                rrect(cv, px, sy - 8, 12, 11, pc, 3)
                cv.hline(px + 3, sy - 7, 6, up(pc))
                cv.hline(px + 3, sy + 2, 6, down(pc))
                cv.px(px + 6, sy - 3, down(pc))
        lr = frame or WALNUT
        for lx in (x0 + 3, x1 - 6):
            cv.rect(lx, h - 5, 3, 4, lr[1])
            cv.px(lx, h - 5, lr[3])
            cv.px(lx + 1, h - 2, lr[0])
        return finish(cv)
    return paint


def chair(w: int, h: int) -> Canvas:
    """A Windsor dining chair seen from behind: a bowed top rail on spindles
    of honey fir, a woven rush seat and splayed legs."""
    cv = Canvas(w, h)
    r = HONEY
    cx = w // 2
    # bowed crest rail
    for xx in range(3, w - 3):
        u = (xx - cx) / (w / 2 - 3)
        yy = 2 + int(2 * u * u)
        cv.vline(xx, yy, 3, r[1])
        cv.px(xx, yy, r[3])
    # spindles
    for sx in range(5, w - 5, 3):
        cv.vline(sx, 5, 14, r[2])
        cv.px(sx, 5, r[3])
    for px in (3, w - 5):
        cv.rect(px, 3, 2, 18, r[1])
        cv.vline(px, 3, 18, r[2])
    # rush seat: a woven square with a lit front edge
    cv.rect(2, 19, w - 4, 7, "O1")
    for yy in range(19, 26):
        for xx in range(2, w - 2):
            if (xx + yy) % 3 == 0:
                cv.px(xx, yy, "O0")
            elif (xx - yy) % 5 == 0:
                cv.px(xx, yy, "O2")
    cv.hline(3, 19, w - 6, "O3")
    cv.rect(2, 26, w - 4, 2, r[1])
    cv.hline(2, 27, w - 4, r[0])
    # splayed legs and a stretcher
    for lx, sx in ((3, -1), (w - 6, 1)):
        for yy in range(28, h - 1):
            t = (yy - 28) / max(1, h - 30)
            xx = lx + int(round(sx * t * 2))
            cv.rect(xx, yy, 3, 1, r[1])
            cv.px(xx, yy, r[2])
    cv.hline(5, h - 6, w - 10, r[1])
    cv.hline(5, h - 7, w - 10, r[2])
    return finish(cv)


def bench(w: int, h: int) -> Canvas:
    """A plank bench of honey fir: a low back rail on two posts, a seat of
    two boards, and stout legs."""
    cv = Canvas(w, h)
    r = HONEY
    # back rail and its posts
    for px in (6, w - 9):
        cv.rect(px, 2, 3, 12, r[1])
        cv.vline(px, 2, 12, r[2])
    cv.rect(3, 2, w - 6, 6, r[1])
    grain(cv, 3, 3, w - 6, 4, r, 11)
    cv.hline(3, 2, w - 6, r[3])
    cv.hline(3, 7, w - 6, r[0])
    # the seat, two boards
    slab(cv, 1, 11, w - 2, 9, r, 13, planks=2)
    cv.rect(1, 20, w - 2, 3, r[1])
    cv.hline(1, 22, w - 2, r[0])
    for k in range(6, w - 4, 22):
        cv.px(k, 13, r[0])
        cv.px(k, 17, r[0])
    legs(cv, [4, w - 8], 23, h - 25, r, 4)
    cv.hline(8, h - 7, w - 16, r[1])
    cv.hline(8, h - 8, w - 16, r[2])
    return finish(cv)


def pew(w: int, h: int) -> Canvas:
    """A chapel pew seen from behind: a sliver of the seat beyond, the back
    of the backrest in raised panels with a hymnal rack, and carved ends."""
    cv = Canvas(w, h)
    r = OAK
    # the seat beyond the top rail
    cv.rect(6, 1, w - 12, 4, r[2])
    cv.hline(6, 1, w - 12, r[3])
    # the top rail
    cv.rect(3, 5, w - 6, 5, r[2])
    grain(cv, 3, 6, w - 6, 3, [r[1], r[2], r[3]], 31)
    cv.hline(3, 5, w - 6, "T2")
    cv.hline(3, 9, w - 6, r[0])
    # the back, in raised panels
    panels(cv, 5, 10, w - 10, 20, r, max(2, (w - 10) // 30), 33)
    # the hymnal rack: a shelf with books and the odd hymnal lying flat
    cv.rect(8, 22, w - 16, 3, r[1])
    cv.hline(8, 22, w - 16, r[3])
    for i, bx in enumerate(range(14, w - 18, 26)):
        c = "R" if i % 3 == 0 else ("P1" if i % 3 == 1 else "B0")
        cv.rect(bx, 17, 8, 5, c)
        cv.hline(bx, 17, 8, up(c))
        cv.px(bx + 3, 19, "O2")
        cv.rect(bx + 9, 18, 6, 4, "B0")
        cv.hline(bx + 9, 18, 6, "B2")
    cv.rect(8, 25, w - 16, 2, r[0])
    # the ends, cut in a scroll and standing to the floor
    for ex in (0, w - 6):
        cv.rect(ex, 3, 6, h - 4, r[2])
        cv.vline(ex, 3, h - 4, r[3])
        cv.vline(ex + 5, 3, h - 4, r[0])
        cv.ellipse(ex + 3, 3, 3, 3, r[2])
        cv.px(ex + 2, 2, "T2")
        cv.px(ex + 3, 4, r[0])
        cv.rect(ex + 1, h - 4, 4, 3, r[1])
    cv.rect(6, 30, w - 12, h - 34, r[0])
    cv.hline(6, 30, w - 12, r[1])
    return finish(cv)


def stool(w: int, h: int) -> Canvas:
    """A three-legged stool, a round seat worn pale in the middle."""
    cv = Canvas(w, h)
    r = HONEY
    cx = w // 2
    for lx, s in ((5, -1), (cx - 1, 0), (w - 8, 1)):
        for yy in range(12, h - 1):
            t = (yy - 12) / (h - 13)
            xx = lx + int(round(s * t * 3))
            cv.rect(xx, yy, 3, 1, r[1] if lx != cx - 1 else r[0])
            cv.px(xx, yy, r[2] if lx != cx - 1 else r[1])
    cv.hline(6, h - 12, w - 12, r[1])
    cv.hline(6, h - 13, w - 12, r[2])
    cv.ellipse(cx, 8, w / 2 - 2, 6, r[1])
    cv.ellipse(cx, 7, w / 2 - 2, 6, r[2])
    cv.ellipse(cx - 1, 6, w / 2 - 6, 4, r[3])
    cv.ellipse(cx - 2, 5, 3, 1.5, "T2")
    for k in range(-8, 9, 4):
        cv.px(cx + k, 7 + (k % 3), r[1])
    return finish(cv)


# ---------------------------------------------------------------- beds

def bed(style: str):
    """A bed seen from its foot: headboard, pillows, a turned-down sheet and
    the cover over the mattress, then the footboard. style: green (a forest
    green spread on a dark panel bed), quilt (a patchwork quilt on a pine
    homestead bed), white (white chenille on a spool bed)."""
    def paint(w: int, h: int) -> Canvas:
        cv = Canvas(w, h)
        wood = PINE if style == "quilt" else WALNUT
        # headboard
        if style == "white":
            cv.rect(4, 4, w - 8, 4, wood[1])
            cv.hline(4, 4, w - 8, wood[3])
            for sx in range(8, w - 8, 5):
                for yy in range(8, 22):
                    cv.px(sx, yy, wood[2] if (yy // 2) % 2 else wood[1])
                    cv.px(sx + 1, yy, wood[1] if (yy // 2) % 2 else wood[0])
        elif style == "quilt":
            # split logs
            for k, yy in enumerate((4, 10, 16)):
                cv.rect(4, yy, w - 8, 6, wood[1])
                cv.hline(4, yy, w - 8, wood[3])
                cv.hline(4, yy + 1, w - 8, wood[2])
                cv.hline(4, yy + 5, w - 8, wood[0])
                for g in range(3):
                    gx = 8 + int(hash2(k, g, 3) * (w - 20))
                    cv.hline(gx, yy + 3, 6, wood[0])
        else:
            cv.rect(4, 3, w - 8, 19, wood[1])
            cv.hline(4, 3, w - 8, wood[3])
            for k in range(2):
                px = 8 + k * ((w - 16) // 2)
                pw = (w - 16) // 2 - 2
                cv.rect(px, 7, pw, 12, wood[2])
                cv.hline(px, 7, pw, wood[0])
                cv.vline(px, 7, 12, wood[0])
                cv.hline(px + 1, 18, pw - 1, wood[3])
        for px in (1, w - 6):
            cv.rect(px, 0 if style != "quilt" else 2, 5, 24, wood[2])
            cv.vline(px, 1, 22, wood[3])
            cv.vline(px + 4, 1, 22, wood[0])
            cv.ellipse(px + 2.5, 1 if style != "quilt" else 3, 3, 2, wood[3])
        # mattress
        cv.rect(4, 22, w - 8, h - 34, "G5")
        # pillows
        for px in (7, w // 2 + 1):
            pw = w // 2 - 8
            rrect(cv, px, 22, pw, 11, "N", 3)
            cv.hline(px + 2, 32, pw - 4, "G4")
            cv.vline(px + pw - 2, 24, 7, "G5")
            cv.px(px + pw // 2, 27, "G5")
        # turned-down sheet
        cv.rect(4, 35, w - 8, 5, "N")
        cv.hline(4, 39, w - 8, "G4")
        cv.hline(4, 35, w - 8, "G5")
        # the cover
        cy0, cy1 = 40, h - 12
        if style == "quilt":
            cols = ["R", "O2", "W2", "N", "T2", "P2", "A1", "W3"]
            sq = 8
            for j, yy in enumerate(range(cy0, cy1, sq)):
                for i, xx in enumerate(range(4, w - 4, sq)):
                    c = cols[int(hash2(i, j, 5) * len(cols))]
                    if (i + j) % 2 == 0:
                        c = "N" if hash2(i, j, 6) > 0.4 else "T3"
                    cv.rect(xx, yy, min(sq, w - 4 - xx), min(sq, cy1 - yy), c)
                    cv.px(xx + 3, yy + 3, down(c))
                    cv.px(xx + 4, yy + 4, down(c))
            for yy in range(cy0, cy1, sq):
                cv.hline(4, yy, w - 8, "T1")
            for xx in range(4, w - 4, sq):
                cv.vline(xx, cy0, cy1 - cy0, "T1")
            cv.frame(4, cy0, w - 8, cy1 - cy0, "R")
            edge = ["A0", "R"]
        elif style == "green":
            cv.rect(4, cy0, w - 8, cy1 - cy0, "P1")
            for yy in range(cy0 + 5, cy1 - 2, 7):
                for xx in range(9 + (4 if (yy // 7) % 2 else 0), w - 8, 8):
                    cv.px(xx, yy, "O2")
                    cv.px(xx - 1, yy, "O1")
                    cv.px(xx + 1, yy, "O1")
                    cv.px(xx, yy - 1, "O1")
                    cv.px(xx, yy + 1, "O1")
            cv.rect(4, cy0, w - 8, 3, "P2")
            cv.hline(4, cy0, w - 8, "P3")
            cv.rect(4, cy1 - 7, w - 8, 3, "O1")
            cv.hline(4, cy1 - 7, w - 8, "O2")
            edge = ["P0", "P1"]
        else:
            cv.rect(4, cy0, w - 8, cy1 - cy0, "G5")
            for yy in range(cy0 + 4, cy1 - 2, 5):
                for xx in range(8 + (3 if (yy // 5) % 2 else 0), w - 6, 6):
                    cv.px(xx, yy, "N")
                    cv.px(xx + 1, yy + 1, "G4")
            # a medallion of tufting in the middle
            cx, cyy = w // 2, (cy0 + cy1) // 2
            for a in range(16):
                ang = a * math.pi / 8
                cv.px(cx + math.cos(ang) * 12, cyy + math.sin(ang) * 8, "G3")
                cv.px(cx + math.cos(ang) * 6, cyy + math.sin(ang) * 4, "G3")
            cv.px(cx, cyy, "G3")
            edge = ["G3", "G4"]
        # folds: the cover's soft shading down the sides
        d = np.zeros((h, w), np.float32)
        d[cy0:cy1, 4:8] = -0.5
        d[cy0:cy1, w - 8:w - 4] = -0.7
        d[cy0:cy0 + 3, 4:w - 4] += 0.4
        cv.tone(d)
        # the cover falls over the foot
        cv.rect(3, cy1, w - 6, 5, edge[1])
        cv.hline(3, cy1, w - 6, up(edge[1]))
        cv.hline(3, cy1 + 4, w - 6, edge[0])
        for fx in range(7, w - 6, 6):
            cv.vline(fx, cy1 + 1, 3, edge[0])
        # footboard
        cv.rect(1, h - 7, w - 2, 6, wood[2])
        cv.hline(1, h - 7, w - 2, wood[3])
        cv.hline(1, h - 2, w - 2, wood[0])
        for px in (1, w - 5):
            cv.rect(px, h - 10, 4, 9, wood[2])
            cv.vline(px, h - 10, 9, wood[3])
            cv.ellipse(px + 2, h - 10, 2.5, 1.5, wood[3])
        return finish(cv)
    return paint


def cot(blanket):
    """A canvas camp cot on folding X legs, a pillow and a wool blanket
    with a stripe, folded back at the head."""
    def paint(w: int, h: int) -> Canvas:
        cv = Canvas(w, h)
        b0, b1, b2, b3 = blanket
        # the frame rails
        for rx in (2, w - 5):
            cv.rect(rx, 3, 3, h - 10, "B1")
            cv.vline(rx, 3, h - 10, "B3")
        # canvas sling
        cv.rect(5, 4, w - 10, h - 12, "T2")
        for yy in range(6, h - 8, 4):
            cv.hline(5, yy, w - 10, "T1")
        # pillow
        rrect(cv, 6, 5, w - 12, 10, "N", 3)
        cv.hline(8, 14, w - 16, "G4")
        cv.px(w // 2, 9, "G5")
        # blanket
        cv.rect(5, 17, w - 10, h - 25, b1)
        for yy in range(17, h - 8):
            for xx in range(5, w - 5):
                if (xx + yy * 2) % 5 == 0:
                    cv.px(xx, yy, b0)
        cv.rect(5, 17, w - 10, 5, b2)
        cv.hline(5, 17, w - 10, b3)
        cv.hline(5, 21, w - 10, b0)
        for sy in (h - 20, h - 17):
            cv.hline(5, sy, w - 10, b3 if sy == h - 20 else b0)
        cv.rect(5, h - 19, w - 10, 2, "N")
        d = np.zeros((h, w), np.float32)
        d[17:h - 8, 5:8] = -0.5
        d[17:h - 8, w - 8:w - 5] = -0.6
        cv.tone(d)
        # folding legs
        cv.rect(2, h - 8, w - 4, 2, "B1")
        cv.line(4, h - 6, w - 6, h - 2, "B1")
        cv.line(w - 5, h - 6, 4, h - 2, "B2")
        for lx in (2, w - 5):
            cv.rect(lx, h - 3, 3, 2, "B0")
        return finish(cv)
    return paint


def washstand(w: int, h: int) -> Canvas:
    """A washstand with a marble top, a white pitcher in its basin, a towel
    on the rail and a cupboard below."""
    cv = Canvas(w, h)
    r = OAK
    # back splash and towel rail
    cv.rect(4, 8, w - 8, 8, r[2])
    cv.hline(4, 8, w - 8, r[3])
    for px in (3, w - 6):
        cv.rect(px, 4, 3, 14, r[2])
        cv.ellipse(px + 1.5, 4, 2, 2, r[3])
    cv.hline(5, 6, w - 10, r[1])
    # the towel over the rail
    cv.rect(w - 15, 6, 7, 14, "N")
    cv.vline(w - 9, 7, 13, "G4")
    cv.hline(w - 15, 9, 7, "W3")
    cv.hline(w - 15, 17, 7, "W3")
    # marble top
    cv.rect(2, 16, w - 4, 8, "G4")
    cv.hline(2, 16, w - 4, "N")
    for k in range(6):
        cv.px(4 + int(hash2(k, 1, 9) * (w - 8)), 18 + int(hash2(k, 2, 9) * 5), "G3")
    cv.hline(2, 23, w - 4, "G2")
    # basin and pitcher
    cv.ellipse(w // 2 - 2, 20, 9, 3, "G5")
    cv.ellipse(w // 2 - 2, 20, 7, 2, "G4")
    cv.ellipse(w // 2 - 2, 20, 6, 1.5, "W3")
    cx = w // 2 - 3
    cv.ellipse(cx, 14, 4, 5, "N")
    cv.rect(cx - 3, 6, 6, 8, "N")
    cv.vline(cx - 2, 7, 10, "G5")
    cv.vline(cx + 2, 8, 9, "G4")
    cv.px(cx - 3, 5, "N")
    cv.px(cx - 4, 5, "N")
    cv.vline(cx + 4, 8, 6, "G4")
    cv.hline(cx - 3, 11, 6, "W2")
    # the cupboard
    cv.rect(3, 24, w - 6, h - 28, r[1])
    cv.rect(5, 26, w - 10, h - 32, r[2])
    cv.hline(5, 26, w - 10, r[0])
    cv.vline(5, 26, h - 32, r[0])
    cv.hline(6, h - 7, w - 11, r[3])
    cv.vline(w // 2, 26, h - 32, r[0])
    cv.px(w // 2 - 2, 34, "O2")
    cv.px(w // 2 + 2, 34, "O2")
    legs(cv, [3, w - 6], h - 4, 3, r)
    return finish(cv)


def dresser(w: int, h: int) -> Canvas:
    """A walnut dresser with a tall swinging mirror in a carved harp, drawers
    with brass pulls and a lace runner on top."""
    cv = Canvas(w, h)
    r = WALNUT
    cx = w // 2
    # the harp and mirror
    for px in (cx - 16, cx + 13):
        cv.rect(px, 6, 3, 22, r[2])
        cv.vline(px, 6, 22, r[3])
    cv.ellipse(cx, 12, 13, 11, r[1])
    cv.rect(cx - 13, 12, 26, 14, r[1])
    cv.ellipse(cx, 12, 11, 9, "W3")
    cv.rect(cx - 11, 12, 22, 13, "W3")
    # the reflection: the room's far wall, a window's light
    cv.rect(cx - 11, 18, 22, 7, "T2")
    cv.hline(cx - 11, 18, 22, "T1")
    cv.poly([(cx - 9, 16), (cx - 2, 5), (cx + 2, 5), (cx - 6, 20)], "W4")
    cv.line(cx + 3, 22, cx + 9, 12, "W4")
    cv.px(cx + 5, 8, "W5")
    cv.ellipse(cx, 1, 5, 2, r[2])
    cv.px(cx - 1, 0, r[3])
    # top with a lace runner and a hairbrush
    cv.rect(1, 27, w - 2, 6, r[2])
    cv.hline(1, 27, w - 2, r[3])
    cv.hline(1, 32, w - 2, r[0])
    cv.rect(10, 27, w - 20, 4, "N")
    for k in range(10, w - 10, 2):
        cv.px(k, 31, "G5")
    cv.rect(13, 26, 8, 2, "B2")
    cv.ellipse(w - 15, 28, 3, 1.5, "W3")
    # drawers
    cv.rect(2, 33, w - 4, h - 37, r[1])
    for dy in range(34, h - 6, 8):
        drawer(cv, 4, dy, w // 2 - 5, 7, r)
        drawer(cv, w // 2 + 1, dy, w // 2 - 5, 7, r)
    legs(cv, [2, w - 5], h - 4, 3, r)
    return finish(cv)


def trunk(ramp, straps):
    """A trunk with a domed lid: wooden slats and iron straps (the
    homestead's), or dark leather with brass corners (the hotel guest's)."""
    def paint(w: int, h: int) -> Canvas:
        cv = Canvas(w, h)
        d0, d1, d2, d3 = ramp
        # domed lid seen from above and in front
        cv.ellipse(w / 2, 9, w / 2 - 3, 7, d2)
        cv.rect(3, 9, w - 6, 6, d2)
        cv.ellipse(w / 2 - 2, 7, w / 2 - 9, 4, d3)
        cv.hline(3, 15, w - 6, d0)
        # body
        cv.rect(3, 16, w - 6, h - 19, d1)
        if straps == "iron":
            for yy in range(18, h - 4, 5):
                cv.hline(4, yy, w - 8, d0)
            for yy in range(5, 14, 4):
                cv.hline(6, yy, w - 12, d1)
        for sx in (10, w - 13):
            c = "G1" if straps == "iron" else "O1"
            cv.rect(sx, 3, 3, h - 6, c)
            cv.vline(sx, 3, h - 6, "G3" if straps == "iron" else "O3")
            for ry in range(6, h - 4, 6):
                cv.px(sx + 1, ry, "G4" if straps == "iron" else "O2")
        if straps == "brass":
            for (x, y) in ((3, 15), (w - 7, 15), (3, h - 7), (w - 7, h - 7)):
                cv.rect(x, y, 4, 4, "O2")
                cv.px(x, y, "O3")
            for (x, y, c) in ((16, 20, "W2"), (w - 24, 23, "S"), (16, 7, "O3")):
                cv.rect(x, y, 7, 5, c)
                cv.hline(x + 1, y + 2, 5, down(c))
        # the hasp and lock
        cv.rect(w // 2 - 3, 13, 6, 6, "O1" if straps == "brass" else "G2")
        cv.px(w // 2, 16, "K0")
        cv.hline(w // 2 - 3, 13, 6, "O3" if straps == "brass" else "G4")
        # end handles
        cv.rect(1, 19, 2, 4, "K1")
        cv.rect(w - 3, 19, 2, 4, "K1")
        cv.hline(3, h - 3, w - 6, d0)
        return finish(cv)
    return paint


# ---------------------------------------------------------------- tables

def coffee_table(w: int, h: int) -> Canvas:
    """A lodge coffee table of thick split planks on log legs, with a stack
    of park guides, a field glass and an enamel mug."""
    cv = Canvas(w, h)
    r = HONEY
    slab(cv, 2, 3, w - 4, 11, r, 21, planks=2)
    cv.rect(2, 14, w - 4, 4, r[1])
    cv.hline(2, 17, w - 4, r[0])
    for lx in (5, w - 10):
        cv.rect(lx, 18, 5, h - 20, r[1])
        cv.vline(lx, 18, h - 20, r[2])
        cv.hline(lx, h - 3, 5, r[0])
    cv.hline(10, h - 7, w - 20, r[1])
    # books and a map
    for i, c in enumerate(("P1", "W1", "R")):
        cv.rect(7 + i, 9 - i * 2, 15 - i * 2, 2, c)
        cv.hline(7 + i, 9 - i * 2, 15 - i * 2, up(c))
    cv.rect(26, 5, 12, 7, "T3")
    cv.line(27, 9, 37, 7, "W2")
    cv.px(30, 6, "M1")
    # an enamel camp mug
    cv.rect(w - 15, 5, 6, 6, "W2")
    cv.hline(w - 15, 5, 6, "W4")
    cv.ellipse(w - 12, 5, 3, 1, "B0")
    cv.px(w - 9, 7, "W2")
    cv.px(w - 9, 8, "W2")
    return finish(cv)


def table_long(look: str):
    """A long table, by look: pine (the Pavilion's, set for dinner), check (a
    red-checked cloth, set for dinner), picnic (planks and a bench end,
    ketchup and mustard), plain (a cabin table with an oil lamp and a tin
    cup) or paints (an artist's table of sketches, tubes and brushes)."""
    def paint(w: int, h: int) -> Canvas:
        cv = Canvas(w, h)
        ramp = {"pine": HONEY, "check": OAK, "picnic": PINE, "plain": OAK, "paints": HONEY}[look]
        if look == "check":
            # a red-and-white checked cloth falling over the edge
            for yy in range(3, 22):
                for xx in range(2, w - 2):
                    a = (xx // 6) % 2
                    b = ((yy - 3) // 4) % 2
                    c = "R" if a and b else ("N" if not a and not b else ("R" if (xx + yy) % 2 else "N"))
                    cv.px(xx, yy, c)
            cv.hline(2, 3, w - 4, "N")
            for yy in range(22, 31):
                for xx in range(2, w - 2):
                    a = (xx // 6) % 2
                    b = ((yy - 22) // 3) % 2
                    cv.px(xx, yy, "R" if a and b else ("G5" if not a and not b else ("R" if (xx + yy) % 2 else "G5")))
            for fx in range(2, w - 2, 12):
                cv.vline(fx, 22, 9, "B0")
            cv.hline(2, 30, w - 4, "B0")
            d = np.zeros((h, w), np.float32)
            d[22:31, :] = -0.4
            cv.tone(d)
            top = 3
        else:
            slab(cv, 1, 3, w - 2, 18, ramp, 41 + w, planks=3 if look in ("picnic", "pine") else 2)
            apron(cv, 1, 21, w - 2, 6, ramp)
            if look == "picnic":
                # the bench boards beyond, and the cross braces
                cv.rect(4, 27, w - 8, 3, ramp[1])
                cv.hline(4, 27, w - 8, ramp[3])
            top = 3
        # legs
        lr = ramp
        if look == "picnic":
            for lx in (8, w - 14):
                for k, c in enumerate((lr[2], lr[1], lr[1], lr[0])):
                    cv.line(lx + k, 27, lx - 4 + k, h - 2, c)
                    cv.line(lx + 4 + k, 27, lx + 8 + k, h - 2, c)
        elif look in ("pine", "check"):
            # trestle ends with a stretcher
            for lx in (6, w - 12):
                cv.rect(lx, 27, 6, h - 31, lr[1])
                cv.vline(lx, 27, h - 31, lr[2])
                cv.rect(lx - 3, h - 5, 12, 4, lr[1])
                cv.hline(lx - 3, h - 5, 12, lr[3])
            cv.rect(12, 34, w - 24, 3, lr[1])
            cv.hline(12, 34, w - 24, lr[2])
        else:
            legs(cv, [3, w - 7], 27, h - 29, lr, 4)
            cv.hline(7, h - 8, w - 14, lr[1])
        # what's on it
        if look in ("pine", "check"):
            n = max(3, w // 28)
            for i in range(n):
                px = int(10 + (w - 20) * (i + 0.5) / n)
                cv.ellipse(px, 13, 5, 2.5, "N")
                cv.ellipse(px, 13, 3, 1.5, "G5")
                cv.vline(px - 7, 11, 4, "G3")
                cv.vline(px + 7, 11, 4, "G3")
                # an enamel mug
                cv.rect(px + 4, 5, 4, 4, "W3" if look == "pine" else "N")
                cv.hline(px + 4, 5, 4, "W4" if look == "pine" else "G5")
                cv.px(px + 8, 6, "W3" if look == "pine" else "N")
            # a bread board and a jug in the middle, salt and pepper
            cx = w // 2
            cv.rect(cx - 9, 7, 18, 6, "B3")
            cv.hline(cx - 9, 7, 18, "T1")
            cv.ellipse(cx - 2, 9, 5, 2.5, "O1")
            cv.ellipse(cx - 3, 8, 3, 1.5, "O2")
            cv.rect(cx + 5, 3, 4, 7, "W1" if look == "pine" else "G5")
            cv.px(cx + 5, 3, "W3")
            for k, sx in enumerate((w // 4, w * 3 // 4)):
                cv.rect(sx, 6, 2, 3, "N")
                cv.rect(sx + 3, 6, 2, 3, "G1")
                # a candle in a jar
                cv.rect(sx - 8, 4, 4, 5, "W4")
                cv.vline(sx - 7, 2, 3, "N")
                cv.px(sx - 7, 1, "A3")
        elif look == "picnic":
            cv.rect(w // 2 - 8, 6, 3, 8, "R")
            cv.px(w // 2 - 8, 5, "N")
            cv.rect(w // 2 - 4, 6, 3, 8, "O3")
            cv.px(w // 2 - 4, 5, "N")
            cv.rect(w // 2 + 4, 8, 10, 6, "N")
            cv.rect(w // 2 + 5, 9, 8, 4, "O2")
            cv.hline(w // 2 + 5, 9, 8, "A1")
            cv.rect(18, 9, 9, 5, "W1")
            cv.hline(18, 9, 9, "W3")
        elif look == "plain":
            # an oil lamp with its chimney, a tin cup and a loaf
            lx = w // 2 + 10
            cv.ellipse(lx, 12, 4, 2, "O1")
            cv.rect(lx - 2, 6, 5, 6, "W4")
            cv.vline(lx - 1, 6, 5, "N")
            cv.rect(lx - 1, 2, 3, 4, "W5")
            cv.px(lx, 8, "A3")
            cv.rect(14, 8, 5, 5, "G3")
            cv.hline(14, 8, 5, "G5")
            cv.ellipse(w // 2 - 8, 11, 7, 3, "O1")
            cv.ellipse(w // 2 - 9, 10, 5, 2, "O2")
            cv.hline(w // 2 - 12, 10, 3, "O0")
        elif look == "paints":
            # sketches, a paint box, tubes and a jar of brushes
            cv.rect(6, 6, 22, 14, "N")
            cv.rect(8, 8, 18, 6, "W4")
            cv.rect(8, 13, 18, 5, "M1")
            cv.line(9, 12, 25, 10, "G4")
            cv.rect(30, 9, 18, 9, "B1")
            cv.rect(31, 10, 16, 7, "B3")
            for k, c in enumerate(("R", "O3", "W2", "P2", "N", "L")):
                cv.rect(32 + (k % 3) * 5, 11 + (k // 3) * 3, 4, 2, c)
            for k, c in enumerate(("R", "W2", "O2")):
                cv.rect(54 + k * 5, 14 - k, 4, 2, c)
                cv.px(57 + k * 5, 14 - k, "G4")
            jx = w - 18
            cv.rect(jx, 7, 6, 8, "W4")
            cv.hline(jx, 7, 6, "W5")
            for k in range(4):
                cv.line(jx + 1 + k, 7, jx - 2 + k * 3, 0, "B2" if k % 2 else "O1")
            cv.px(jx - 2, 0, "R")
            cv.px(jx + 7, 0, "W2")
        return finish(cv)
    return paint


def table_round(look: str):
    """A round café table under a cloth: red (a red gingham, coffee and a
    pastry), white (cream, a pizza on its tray), linen (white linen set for
    dinner, with a candle) or green (a lodge table with a lamp and a
    book)."""
    cloths = {
        "red": ["B1", "R", "R", "N"],
        "white": ["G4", "G5", "N", "N"],
        "linen": ["G4", "G5", "N", "N"],
        "green": ["P0", "P1", "P2", "P3"],
    }

    def paint(w: int, h: int) -> Canvas:
        cv = Canvas(w, h)
        c0, c1, c2, c3 = cloths[look]
        cx = w / 2
        # the cloth's top
        cv.ellipse(cx, 13, w / 2 - 3, 10, c2)
        if look == "red":
            # gingham: alternate light threads
            for yy in range(2, 24):
                for xx in range(3, w - 3):
                    if cv.a[yy, xx, 3] and ((xx // 4) % 2 == 0 or (yy // 3) % 2 == 0):
                        both = (xx // 4) % 2 == 0 and (yy // 3) % 2 == 0
                        if both or (xx + yy) % 2:
                            cv.px(xx, yy, "N")
        else:
            cv.ellipse(cx - 3, 10, w / 2 - 12, 5, c3)
        # the cloth's hanging skirt, in folds
        cv.rect(4, 13, w - 8, 18, c1)
        cv.ellipse(cx, 31, w / 2 - 4, 3, c1)
        for fx in range(7, w - 6, 6):
            cv.vline(fx, 17, 15, c0)
            cv.vline(fx + 1, 17, 15, c2 if look != "red" else "A1")
        if look == "red":
            for yy in range(14, 33, 3):
                for xx in range(4, w - 4):
                    if cv.a[yy, xx, 3] and (xx // 4) % 2 == 0 and (xx + yy) % 2:
                        cv.px(xx, yy, "G5")
        d = np.zeros((h, w), np.float32)
        yy, xx = np.mgrid[0:h, 0:w]
        d += np.where(yy > 13, -0.6 * np.clip((xx - w * 0.55) / (w * 0.45), 0, 1), 0)
        cv.tone(d)
        # pedestal
        cv.rect(int(cx) - 3, 33, 6, h - 37, "B1")
        cv.vline(int(cx) - 3, 33, h - 37, "B2")
        cv.ellipse(cx, h - 3, 9, 2.5, "B1")
        cv.hline(int(cx) - 8, h - 4, 16, "B2")
        icx = int(cx)
        if look == "red":
            # a cup of coffee on its saucer and a bear claw
            cv.ellipse(icx - 6, 13, 6, 2.5, "N")
            cv.rect(icx - 9, 7, 6, 6, "N")
            cv.ellipse(icx - 6, 7, 3, 1, "B1")
            cv.px(icx - 3, 9, "N")
            cv.px(icx - 2, 9, "N")
            cv.ellipse(icx + 8, 12, 6, 3, "G5")
            cv.ellipse(icx + 8, 11, 4, 2.5, "O1")
            cv.ellipse(icx + 7, 10, 2.5, 1.5, "O2")
            for k in (-3, 0, 3):
                cv.px(icx + 8 + k, 13, "B2")
        elif look == "white":
            # a pizza on a tin tray, a slice gone
            cv.ellipse(icx, 12, 13, 6, "G3")
            cv.ellipse(icx, 11, 12, 5, "G4")
            cv.ellipse(icx, 11, 10, 4, "O1")
            cv.ellipse(icx, 11, 9, 3, "O2")
            cv.poly([(icx, 11), (icx + 10, 9), (icx + 10, 14)], "G4")
            for k in range(7):
                px = icx - 7 + int(hash2(k, 1, 3) * 12)
                py = 9 + int(hash2(k, 2, 3) * 4)
                if px < icx + 2 or py < 10:
                    cv.px(px, py, "R")
                    cv.px(px + 1, py, "A0")
            cv.px(icx - 4, 12, "P2")
            cv.px(icx + 1, 9, "P2")
            # a glass of soda
            cv.rect(icx + 13, 5, 4, 6, "W4")
            cv.vline(icx + 13, 5, 6, "W5")
        elif look == "linen":
            for px in (int(cx - w / 4), int(cx + w / 4)):
                cv.ellipse(px, 13, 5, 2.5, "N")
                cv.ellipse(px, 13, 3, 1.5, "W5")
                cv.vline(px - 7, 11, 4, "G3")
                cv.vline(px + 6, 11, 4, "G3")
                cv.rect(px + 2, 6, 3, 4, "W5")
            cv.rect(icx - 2, 9, 4, 3, "O1")
            cv.rect(icx - 1, 2, 2, 7, "N")
            cv.px(icx - 1, 1, "A2")
            cv.px(icx - 1, 0, "O3")
            cv.px(icx + 3, 12, "L")
            cv.px(icx + 4, 11, "S")
            cv.px(icx + 3, 11, "P2")
        else:
            # a small brass lamp and an open book
            cv.ellipse(icx + 6, 12, 4, 1.5, "O1")
            cv.vline(icx + 6, 4, 8, "O2")
            cv.poly([(icx + 1, 6), (icx + 11, 6), (icx + 9, 1), (icx + 3, 1)], "A2")
            cv.hline(icx + 3, 1, 7, "A3")
            cv.hline(icx + 1, 6, 11, "A1")
            cv.rect(icx - 12, 9, 12, 5, "N")
            cv.vline(icx - 6, 9, 5, "G4")
            cv.hline(icx - 11, 11, 4, "G3")
            cv.hline(icx - 5, 11, 4, "G3")
        return finish(cv, "B0")
    return paint


# ---------------------------------------------------------------- counters

def _register(cv: Canvas, x: int, y: int) -> None:
    """A brass cash register: the keys, the sale flags and the cash drawer."""
    cv.rect(x, y + 4, 18, 10, "O1")
    cv.hline(x, y + 4, 18, "O3")
    cv.rect(x + 3, y, 12, 5, "O2")
    cv.hline(x + 3, y, 12, "O3")
    cv.rect(x + 5, y + 1, 8, 2, "K0")
    cv.px(x + 6, y + 1, "N")
    cv.px(x + 9, y + 1, "N")
    for kx in range(x + 2, x + 16, 3):
        for ky in (y + 6, y + 9):
            cv.px(kx, ky, "N")
            cv.px(kx, ky + 1, "G3")
    cv.hline(x, y + 13, 18, "O0")
    cv.px(x + 17, y + 6, "O3")


def _bell(cv: Canvas, x: int, y: int) -> None:
    cv.ellipse(x, y + 4, 5, 2, "B0")
    cv.ellipse(x, y + 2, 4, 3, "O2")
    cv.ellipse(x - 1, y + 1, 2, 1.5, "O3")
    cv.px(x, y - 1, "O1")
    cv.hline(x - 4, y + 4, 9, "O0")


def _ledger(cv: Canvas, x: int, y: int) -> None:
    cv.rect(x, y, 28, 9, "B0")
    cv.rect(x + 1, y, 26, 8, "N")
    cv.vline(x + 14, y, 8, "G4")
    for ly in (y + 2, y + 4, y + 6):
        cv.hline(x + 3, ly, 9, "G3")
        cv.hline(x + 16, ly, 9, "G3")
    cv.line(x + 22, y + 1, x + 28, y - 4, "K0")


def _jars(cv: Canvas, x: int, y: int) -> None:
    """Glass candy jars with brass lids: red hots, lemon drops, mint
    sticks."""
    for k, c in enumerate(("R", "O3", "M2", "S")):
        jx = x + k * 9
        cv.rect(jx, y + 2, 7, 10, "W4")
        cv.rect(jx + 1, y + 5, 5, 6, c)
        for s in range(4):
            cv.px(jx + 1 + int(hash2(k, s, 2) * 5), y + 5 + int(hash2(s, k, 2) * 6), up(c) if s % 2 else down(c))
        cv.vline(jx + 1, y + 3, 7, "W5")
        cv.rect(jx, y, 7, 2, "O1")
        cv.hline(jx, y, 7, "O3")


def _cups(cv: Canvas, x: int, y: int, n: int = 3) -> None:
    """Stacked coffee mugs."""
    for k in range(n):
        cx = x + k * 7
        for s in range(2):
            cv.rect(cx, y + 4 - s * 3, 6, 4, "N")
            cv.hline(cx, y + 4 - s * 3, 6, "G5")
            cv.px(cx + 6, y + 5 - s * 3, "N")
        cv.ellipse(cx + 3, y + 1, 3, 1, "G4")


def _pastries(cv: Canvas, x: int, y: int, n: int = 5) -> None:
    """A tray of muffins and bear claws."""
    cv.rect(x - 2, y + 5, n * 7 + 3, 4, "G3")
    cv.hline(x - 2, y + 5, n * 7 + 3, "G5")
    for k in range(n):
        px = x + k * 7
        if k % 2:
            cv.ellipse(px + 3, y + 4, 3.5, 2.5, "O1")
            cv.ellipse(px + 2, y + 3, 2, 1.5, "O2")
            cv.px(px + 1, y + 5, "B2")
            cv.px(px + 5, y + 5, "B2")
        else:
            cv.rect(px + 1, y + 4, 5, 3, "N")
            cv.ellipse(px + 3, y + 3, 3.5, 2.5, "B2")
            cv.px(px + 2, y + 2, "B3")
            cv.px(px + 4, y + 3, "O2")


def _scale(cv: Canvas, x: int, y: int) -> None:
    """A postal scale: a brass pan over a dial."""
    cv.rect(x, y + 4, 14, 8, "G1")
    cv.hline(x, y + 4, 14, "G3")
    cv.ellipse(x + 7, y + 8, 3, 2.5, "N")
    cv.line(x + 7, y + 8, x + 9, y + 6, "R")
    cv.ellipse(x + 7, y + 2, 7, 2, "O2")
    cv.hline(x + 1, y + 2, 12, "O3")
    cv.vline(x + 7, y + 3, 2, "O0")
    cv.rect(x + 4, y - 1, 6, 3, "T3")


def _lamp(cv: Canvas, x: int, y: int) -> None:
    """A green-shaded banker's lamp."""
    cv.ellipse(x, y + 12, 4, 1.5, "O1")
    cv.vline(x, y + 4, 8, "O2")
    cv.ellipse(x, y + 4, 8, 3, "P1")
    cv.ellipse(x - 1, y + 3, 6, 2, "P3")
    cv.hline(x - 7, y + 6, 15, "A3")


def counter(look: str):
    """A shop or lodge counter: a top seen from above, a front of raised
    panels, and what's on it. default (the Welcome Center's: ledger and
    bell), grill (a steel-topped lunch counter with a register, mugs and a
    lamp), market (a register and candy jars), serving (the Pavilion's long
    steel serving line, mugs and pastries) or snacks (a register and mugs)."""
    def paint(w: int, h: int) -> Canvas:
        cv = Canvas(w, h)
        wood = {"default": OAK, "grill": HONEY, "market": OAK, "serving": OAK, "snacks": HONEY}[look]
        steel = look in ("grill", "serving")
        ty0, ty1 = 12, 23
        if steel:
            cv.rect(1, ty0, w - 2, ty1 - ty0, "G4")
            for k in range(0, w, 7):
                cv.vline(k + int(hash2(k, 1, 5) * 4), ty0 + 1, ty1 - ty0 - 2, "G3" if k % 2 else "G5")
            cv.hline(1, ty0, w - 2, "N")
            cv.hline(1, ty1 - 2, w - 2, "G5")
            cv.hline(1, ty1 - 1, w - 2, "G2")
            # a long glint of the window on the steel
            for k in range(12, w - 12, 60):
                cv.hline(k, ty0 + 3, 18, "N")
                cv.hline(k + 4, ty0 + 5, 9, "G5")
        else:
            slab(cv, 1, ty0, w - 2, ty1 - ty0, wood, 51 + w, planks=2)
            cv.hline(1, ty1 - 1, w - 2, "T2")
        # front
        cv.rect(1, ty1, w - 2, 4, wood[1])
        cv.hline(1, ty1, w - 2, wood[0])
        cv.hline(1, ty1 + 3, w - 2, wood[0])
        panels(cv, 1, ty1 + 4, w - 2, h - ty1 - 9, wood, max(2, (w - 2) // 48), 53 + w)
        # kick plate
        cv.rect(1, h - 5, w - 2, 4, wood[0])
        cv.hline(1, h - 5, w - 2, wood[1])
        # the items
        if look == "default":
            _bell(cv, 16, 8)
            _ledger(cv, w // 2 - 14, 5)
            cv.rect(w - 34, 6, 18, 8, "T3")
            for k in range(3):
                cv.hline(w - 32, 8 + k * 2, 14, "W2" if k == 0 else "G3")
            cv.rect(w - 30, 3, 10, 4, "M1")
            cv.hline(w - 30, 3, 10, "M2")
        elif look == "grill":
            _register(cv, w - 34, 1)
            _cups(cv, 20, 6, 3)
            _lamp(cv, w // 2 + 20, 0)
            # a napkin box and a sugar jar
            cv.rect(w // 2 - 20, 7, 8, 6, "G3")
            cv.rect(w // 2 - 19, 6, 6, 2, "N")
            cv.rect(w // 2 - 8, 5, 5, 8, "W4")
            cv.rect(w // 2 - 8, 4, 5, 2, "G3")
        elif look == "market":
            _register(cv, w - 32, 1)
            _jars(cv, 12, 2)
        elif look == "serving":
            _cups(cv, 30, 6, 4)
            _pastries(cv, 70, 5, 6)
            # a coffee urn and a stack of trays
            ux = w - 50
            cv.rect(ux, 0, 12, 13, "G3")
            cv.vline(ux + 1, 1, 11, "G5")
            cv.vline(ux + 10, 1, 11, "G2")
            cv.ellipse(ux + 6, 0, 6, 2, "G4")
            cv.rect(ux + 12, 7, 3, 2, "O2")
            cv.rect(w - 30, 8, 22, 6, "B2")
            for k in range(3):
                cv.hline(w - 30, 8 + k * 2, 22, "B3" if k % 2 == 0 else "B1")
            cv.rect(w // 2 + 20, 7, 28, 6, "G5")
            for k in range(5):
                cv.ellipse(w // 2 + 23 + k * 5, 9, 2.5, 1.5, "N")
        elif look == "snacks":
            _register(cv, w - 34, 1)
            _cups(cv, 16, 6, 3)
            # a rack of chips and a jar of jerky
            cv.rect(w // 2 - 16, 3, 22, 10, "B1")
            for k, c in enumerate(("R", "O3", "W2", "M2")):
                cv.rect(w // 2 - 15 + k * 5, 4, 4, 7, c)
                cv.hline(w // 2 - 15 + k * 5, 4, 4, up(c))
            cv.rect(w // 2 + 12, 4, 8, 9, "W4")
            cv.rect(w // 2 + 13, 7, 6, 5, "B2")
            cv.rect(w // 2 + 12, 3, 8, 2, "O1")
        return finish(cv)
    return paint


# ---------------------------------------------------------------- desks

def desk(look: str):
    """A pedestal desk: its top seen from above, two banks of drawers either
    side of the kneehole. papers (an ink well and letters), lamp (a reading
    lamp), telegraph (a sounder and key, the line's insulators), typewriter
    (an Underwood and a sheet in it), writing (a slant blotter, pens and an
    inkstand)."""
    def paint(w: int, h: int) -> Canvas:
        cv = Canvas(w, h)
        r = OAK
        ty0, ty1 = 12, 22
        slab(cv, 1, ty0, w - 2, ty1 - ty0, r, 61 + w, planks=0)
        cv.hline(1, ty1 - 1, w - 2, "T2")
        apron(cv, 1, ty1, w - 2, 5, r)
        pw = min(26, w // 3)
        for px in (2, w - 2 - pw):
            cv.rect(px, ty1 + 5, pw, h - ty1 - 8, r[1])
            for dy in range(ty1 + 6, h - 5, 8):
                drawer(cv, px + 2, dy, pw - 4, 7, r)
            cv.hline(px, h - 3, pw, r[0])
        # kneehole in shadow
        kx0, kx1 = 2 + pw, w - 2 - pw
        cv.rect(kx0, ty1 + 5, kx1 - kx0, h - ty1 - 9, "B0")
        cv.hline(kx0, ty1 + 5, kx1 - kx0, "K1")
        drawer(cv, kx0 + 3, ty1 + 1, kx1 - kx0 - 6, 4, r)
        # a green leather writing surface
        cv.rect(w // 2 - 14, 14, 28, 6, "P1")
        cv.frame(w // 2 - 14, 14, 28, 6, "P0")
        if look in ("papers", "writing", "lamp"):
            cv.rect(w // 2 - 9, 13, 14, 7, "N")
            cv.rect(w // 2 - 7, 11, 13, 7, "G5")
            for ly in (13, 15):
                cv.hline(w // 2 - 5, ly, 9, "G3")
            cv.line(w // 2 + 6, 13, w // 2 + 11, 9, "K0")
        if look == "papers":
            cv.rect(8, 9, 6, 6, "K1")
            cv.hline(8, 9, 6, "W1")
            cv.vline(11, 4, 5, "N")
            cv.rect(w - 22, 8, 14, 6, "T3")
            cv.rect(w - 21, 6, 14, 6, "N")
            cv.hline(w - 19, 8, 9, "G3")
        elif look == "writing":
            # an inkstand with two wells and pens, a stack of letters tied in string
            cv.rect(8, 9, 16, 5, "O1")
            cv.hline(8, 9, 16, "O3")
            cv.rect(10, 6, 4, 4, "K1")
            cv.rect(17, 6, 4, 4, "K1")
            cv.line(12, 6, 15, 0, "N")
            cv.line(19, 6, 22, 1, "W5")
            cv.rect(w - 24, 6, 14, 8, "T3")
            cv.hline(w - 24, 6, 14, "N")
            cv.vline(w - 17, 6, 8, "A0")
            cv.hline(w - 24, 10, 14, "A0")
        elif look == "lamp":
            _lamp(cv, w - 14, 0)
            cv.rect(8, 8, 10, 6, "R")
            cv.hline(8, 8, 10, "A1")
            cv.rect(9, 5, 9, 3, "W1")
        elif look == "telegraph":
            # the sounder on its base, the key, and a pad of forms
            bx = w // 2 - 6
            cv.rect(bx - 6, 9, 20, 5, "B2")
            cv.hline(bx - 6, 9, 20, "B3")
            for px in (bx - 3, bx + 9):
                cv.rect(px, 3, 3, 7, "O1")
                cv.px(px, 3, "O3")
            cv.rect(bx - 2, 4, 14, 2, "G2")
            cv.hline(bx - 2, 4, 14, "G4")
            cv.rect(bx + 3, 6, 4, 3, "G1")
            kx = w - 22
            cv.rect(kx, 11, 12, 3, "B1")
            cv.line(kx + 1, 10, kx + 10, 9, "O2")
            cv.ellipse(kx + 10, 9, 2, 1.5, "K1")
            cv.rect(8, 8, 12, 6, "N")
            for ly in (10, 12):
                cv.hline(9, ly, 10, "W2")
            # the wire up to the wall
            cv.line(bx + 12, 4, w - 6, 0, "K1")
        elif look == "typewriter":
            # an Underwood: the carriage, a sheet in it, the keys
            tx = w // 2 - 12
            cv.rect(tx + 3, 0, 18, 6, "N")
            for ly in (2, 4):
                cv.hline(tx + 5, ly, 12, "G3")
            cv.rect(tx - 1, 5, 26, 3, "K1")
            cv.hline(tx - 1, 5, 26, "G2")
            cv.ellipse(tx - 2, 6, 2, 2, "G3")
            cv.rect(tx + 1, 8, 22, 7, "K0")
            cv.hline(tx + 1, 8, 22, "G1")
            for ky, off in ((10, 0), (12, 1)):
                for kx in range(tx + 3 + off, tx + 21, 3):
                    cv.px(kx, ky, "N")
            cv.rect(tx + 8, 13, 8, 1, "G4")
            cv.px(tx + 11, 9, "O2")
            # a stack of paper and a cup of pencils
            cv.rect(8, 8, 12, 6, "N")
            cv.hline(8, 9, 12, "G5")
            cv.rect(w - 16, 6, 6, 8, "R")
            cv.hline(w - 16, 6, 6, "A1")
            for k in range(3):
                cv.vline(w - 15 + k * 2, 2, 4, "O3" if k != 1 else "W2")
        return finish(cv)
    return paint


# ---------------------------------------------------------------- the big pieces

def bookcase(curios: bool):
    """A tall bookcase with a crown moulding, four shelves of books, and for
    the curio case a mix of minerals, a bird's nest, a pine cone, jars and an
    old camera among the books."""
    def paint(w: int, h: int) -> Canvas:
        cv = Canvas(w, h)
        r = WALNUT if not curios else OAK
        # carcase
        cv.rect(2, 6, w - 4, h - 8, r[1])
        grain(cv, 2, 6, 6, h - 8, r, 71, vertical=True)
        grain(cv, w - 8, 6, 6, h - 8, r, 72, vertical=True)
        # crown
        cv.rect(0, 0, w, 7, r[2])
        cv.hline(0, 0, w, r[3])
        cv.hline(1, 1, w - 2, "T1")
        cv.hline(0, 6, w, r[0])
        for k in range(3, w - 3, 4):
            cv.px(k, 4, r[1])
        # interior and shelves
        ix0, ix1 = 7, w - 7
        top, bot = 8, h - 10
        cv.rect(ix0, top, ix1 - ix0, bot - top, r[0])
        rows = 4
        rh = (bot - top) / rows
        for i in range(rows):
            sy = int(top + (i + 1) * rh)
            base = sy - 1
            # the back wall of each shelf, in shadow under the shelf above
            cv.rect(ix0, int(top + i * rh), ix1 - ix0, 4, "K1")
            if curios and i in (0, 2):
                x = ix0 + 1
                k = 0
                while x < ix1 - 5:
                    kind = (k + i) % 5
                    if kind == 0:
                        cv.ellipse(x + 3, base - 3, 3.5, 3, "G4")
                        cv.ellipse(x + 2, base - 4, 1.5, 1, "N")
                        cv.px(x + 4, base - 2, "G2")
                        x += 9
                    elif kind == 1:
                        cv.rect(x, base - 9, 6, 9, "W4")
                        cv.rect(x + 1, base - 6, 4, 5, "O2" if i else "R")
                        cv.rect(x, base - 10, 6, 2, "B1")
                        cv.vline(x + 1, base - 8, 6, "W5")
                        x += 9
                    elif kind == 2:
                        # a sugar pine cone
                        for s in range(9):
                            cv.hline(x + 1 + (1 if s % 2 else 0), base - 2 - s, 5 - abs(4 - s) // 3, "B2" if s % 2 else "B3")
                        x += 9
                    elif kind == 3:
                        # an old box camera
                        cv.rect(x, base - 7, 8, 7, "K1")
                        cv.ellipse(x + 4, base - 3, 2, 2, "G3")
                        cv.px(x + 3, base - 4, "N")
                        cv.rect(x + 1, base - 9, 3, 2, "G1")
                        x += 11
                    else:
                        # amethyst and quartz
                        cv.poly([(x, base), (x + 3, base - 8), (x + 6, base)], "L")
                        cv.line(x + 3, base - 7, x + 3, base - 1, "S")
                        cv.poly([(x + 5, base), (x + 7, base - 5), (x + 9, base)], "N")
                        x += 11
                    k += 1
            else:
                book_row(cv, ix0 + 1, ix1 - 1, base, 73 + i * 7 + (40 if curios else 0), maxh=int(rh) - 3)
            # the shelf board
            cv.rect(ix0, sy, ix1 - ix0, 3, r[2])
            cv.hline(ix0, sy, ix1 - ix0, r[3])
            cv.hline(ix0, sy + 2, ix1 - ix0, r[0])
        # side light falling across the shelves
        d = np.zeros((h, w), np.float32)
        yy, xx = np.mgrid[0:h, 0:w]
        d += np.where((xx > ix1 - 10) & (yy > top) & (yy < bot), -0.6, 0.0)
        cv.tone(d)
        # plinth with a drawer row
        cv.rect(2, bot, w - 4, h - bot - 2, r[1])
        cv.hline(2, bot, w - 4, r[3])
        drawer(cv, 6, bot + 2, w // 2 - 7, h - bot - 6, r)
        drawer(cv, w // 2 + 1, bot + 2, w // 2 - 7, h - bot - 6, r)
        cv.hline(2, h - 2, w - 4, r[0])
        return finish(cv)
    return paint


def piano(look: str):
    """An upright keyboard against the wall, its keys toward the room.
    upright (Best's Studio's, a sheet of Chopin on the stand), organ (the
    chapel's pump organ: a carved gallery top, stops and two foot pedals),
    parlor (the Wawona's, with brass candle sconces and fretwork)."""
    def paint(w: int, h: int) -> Canvas:
        cv = Canvas(w, h)
        r = WALNUT
        x0, x1 = 3, w - 3
        # the case top
        top = 4 if look != "organ" else 14
        if look == "organ":
            # a carved gallery with turned spindles and a pediment
            cv.poly([(x0 + 6, 14), (w // 2, 2), (x1 - 6, 14)], r[2])
            cv.poly([(x0 + 10, 14), (w // 2, 5), (x1 - 10, 14)], r[1])
            cv.ellipse(w // 2, 9, 3, 3, "O2")
            cv.px(w // 2 - 1, 8, "O3")
            for sx in range(x0 + 2, x1 - 2, 4):
                cv.vline(sx, 10, 5, r[3])
            cv.rect(x0, 9, x1 - x0, 2, r[2])
            cv.hline(x0, 9, x1 - x0, r[3])
        cv.rect(x0, top, x1 - x0, 6, r[2])
        cv.hline(x0, top, x1 - x0, r[3])
        cv.hline(x0, top + 1, x1 - x0, "B3" if look != "organ" else "T1")
        cv.hline(x0, top + 5, x1 - x0, r[0])
        # the upper front
        fy0, fy1 = top + 6, 38
        cv.rect(x0 + 1, fy0, x1 - x0 - 2, fy1 - fy0, r[1])
        # a polished sheen and the window reflected
        d = np.zeros((h, w), np.float32)
        d[fy0:fy1, x0 + 6:x0 + 9] = 0.9
        d[fy0:fy1, x0 + 12:x0 + 13] = 0.6
        if look == "parlor":
            # fretwork panels with red silk behind, candle sconces
            for px in (x0 + 4, x1 - 22):
                cv.rect(px, fy0 + 3, 18, 14, "A0")
                for yy in range(fy0 + 3, fy0 + 17):
                    for xx in range(px, px + 18):
                        if (xx + yy) % 4 == 0 or (xx - yy) % 4 == 0:
                            cv.px(xx, yy, r[2])
                cv.frame(px, fy0 + 3, 18, 14, r[3])
            for sx in (x0 - 1, x1 - 2):
                cv.rect(sx, fy0 + 4, 3, 3, "O2")
                cv.rect(sx, fy0 - 2, 3, 6, "N")
                cv.px(sx + 1, fy0 - 4, "A3")
                cv.px(sx + 1, fy0 - 3, "O3")
        elif look == "organ":
            # stop knobs and a mirror-backed shelf
            for k, sx in enumerate(range(x0 + 8, x1 - 6, 6)):
                cv.ellipse(sx, fy0 + 15, 2, 2, "N" if k % 2 else "G5")
                cv.px(sx, fy0 + 15, "K0")
            cv.rect(w // 2 - 10, fy0 + 3, 20, 9, "W3")
            cv.frame(w // 2 - 11, fy0 + 2, 22, 11, r[3])
            cv.line(w // 2 - 6, fy0 + 10, w // 2 + 2, fy0 + 4, "W4")
        cv.tone(d)
        # music stand and score
        cv.rect(w // 2 - 15, fy1 - 14, 30, 11, r[0])
        cv.hline(w // 2 - 15, fy1 - 14, 30, r[2])
        for k, sx in enumerate((w // 2 - 13, w // 2 + 1)):
            cv.rect(sx, fy1 - 13, 12, 9, "N" if k == 0 else "G5")
            for ly in range(fy1 - 11, fy1 - 5, 2):
                cv.hline(sx + 1, ly, 10, "G3")
                cv.px(sx + 2 + (ly * 3) % 8, ly - 1, "K0")
        # keyboard
        ky = fy1
        cv.rect(x0 - 1, ky, x1 - x0 + 2, 3, r[2])
        cv.hline(x0 - 1, ky, x1 - x0 + 2, r[3])
        cv.rect(x0 + 3, ky + 3, x1 - x0 - 6, 8, "N")
        for kx in range(x0 + 4, x1 - 3, 3):
            cv.vline(kx, ky + 3, 8, "G4")
        for kx in range(x0 + 5, x1 - 4, 3):
            if (kx // 3) % 7 not in (2, 6):
                cv.rect(kx, ky + 3, 2, 5, "K0")
        cv.rect(x0, ky + 3, 3, 9, r[1])
        cv.rect(x1 - 3, ky + 3, 3, 9, r[1])
        cv.rect(x0 - 1, ky + 11, x1 - x0 + 2, 3, r[1])
        cv.hline(x0 - 1, ky + 11, x1 - x0 + 2, r[3])
        # the lower front: a panel, then legs or toe blocks and pedals
        ly0 = ky + 14
        cv.rect(x0 + 2, ly0, x1 - x0 - 4, h - ly0 - 4, r[1])
        cv.rect(x0 + 8, ly0 + 2, x1 - x0 - 16, h - ly0 - 9, r[0])
        cv.frame(x0 + 8, ly0 + 2, x1 - x0 - 16, h - ly0 - 9, r[2])
        if look == "organ":
            for px in (w // 2 - 12, w // 2 + 2):
                cv.rect(px, h - 10, 10, 7, "R")
                cv.hline(px, h - 10, 10, "A1")
                for k in range(px + 1, px + 10, 2):
                    cv.px(k, h - 7, "A0")
        else:
            for px in (w // 2 - 6, w // 2 - 1, w // 2 + 4):
                cv.rect(px, h - 8, 3, 2, "O2")
                cv.px(px, h - 8, "O3")
        for lx in (x0, x1 - 5):
            cv.rect(lx, ky + 14, 5, h - ky - 16, r[2])
            cv.vline(lx, ky + 14, h - ky - 16, r[3])
            cv.rect(lx - 1, h - 4, 7, 3, r[1])
        cv.hline(x0, h - 2, x1 - x0, r[0])
        return finish(cv, "K0")
    return paint


def pulpit(w: int, h: int) -> Canvas:
    """The chapel's pulpit: a slanted reading desk with an open Bible and a
    ribbon marker, a gilt cross on the front panel, on a stepped base."""
    cv = Canvas(w, h)
    r = OAK
    # the slanted desk top and the book
    cv.poly([(2, 18), (w - 2, 18), (w - 5, 6), (5, 6)], r[2])
    cv.hline(5, 6, w - 10, r[3])
    cv.hline(2, 18, w - 4, r[0])
    cv.rect(8, 6, w - 16, 10, "N")
    cv.vline(w // 2, 6, 10, "G4")
    for ly in range(8, 15, 2):
        cv.hline(10, ly, w // 2 - 12, "G3")
        cv.hline(w // 2 + 2, ly, w // 2 - 12, "G3")
    cv.vline(w // 2 + 1, 14, 9, "R")
    cv.rect(7, 15, w - 14, 2, "B0")
    # the body: panelled, wider at the top
    cv.rect(4, 19, w - 8, h - 27, r[1])
    grain(cv, 4, 19, w - 8, h - 27, r, 81, vertical=True)
    cv.rect(2, 19, w - 4, 4, r[2])
    cv.hline(2, 19, w - 4, r[3])
    cv.hline(2, 22, w - 4, r[0])
    cv.rect(8, 26, w - 16, h - 40, r[2])
    cv.frame(8, 26, w - 16, h - 40, r[0])
    cv.hline(9, h - 15, w - 17, r[3])
    # the cross
    cx = w // 2
    cv.rect(cx - 1, 29, 3, 18, "O2")
    cv.rect(cx - 6, 34, 13, 3, "O2")
    cv.vline(cx - 1, 29, 18, "O3")
    cv.hline(cx - 6, 34, 13, "O3")
    cv.vline(cx + 1, 30, 17, "O0")
    # stepped base
    cv.rect(2, h - 9, w - 4, 4, r[2])
    cv.hline(2, h - 9, w - 4, r[3])
    cv.rect(0, h - 5, w, 4, r[1])
    cv.hline(0, h - 5, w, r[3])
    cv.hline(0, h - 2, w, r[0])
    return finish(cv)


def case(contents: str):
    """A display case: a glass top over a felt-lined tray seen from above,
    with the window glinting across the glass, on a panelled cabinet.
    museum (small baskets, a mortar and obsidian points, minerals and an old
    photograph), books, cones (giant sequoia and sugar pine cones) or
    icecream (an ice-cream dipping cabinet of tubs)."""
    def paint(w: int, h: int) -> Canvas:
        cv = Canvas(w, h)
        r = WALNUT if contents != "icecream" else ["G1", "G2", "G3", "G4"]
        gy0, gy1 = 4, 28
        # the frame round the glass
        cv.rect(1, gy0 - 3, w - 2, gy1 - gy0 + 6, r[2])
        cv.hline(1, gy0 - 3, w - 2, r[3])
        # the lining
        lining = {"museum": "P1", "books": "B1", "cones": "P1", "icecream": "G4"}[contents]
        cv.rect(4, gy0, w - 8, gy1 - gy0, lining)
        for yy in range(gy0, gy1):
            for xx in range(4, w - 4):
                if (xx + yy) % 4 == 0 and contents != "icecream":
                    cv.px(xx, yy, down(lining))
        # the contents
        if contents == "museum":
            x = 8
            k = 0
            while x < w - 14:
                kind = k % 4
                cy = gy0 + 6 + (k % 2) * 8
                if kind == 0:
                    # a small coiled basket with a band of pattern
                    cv.ellipse(x + 5, cy + 4, 6, 4, "O1")
                    cv.ellipse(x + 5, cy + 3, 5, 3, "O2")
                    cv.ellipse(x + 5, cy + 3, 3, 1.5, "B1")
                    for a in range(0, 360, 45):
                        cv.px(x + 5 + math.cos(math.radians(a)) * 4, cy + 3 + math.sin(math.radians(a)) * 2.5, "B1")
                    x += 15
                elif kind == 1:
                    # obsidian points laid in a row
                    for s in range(3):
                        cv.poly([(x + s * 5, cy + 7), (x + 2 + s * 5, cy), (x + 4 + s * 5, cy + 7)], "K1")
                        cv.px(x + 2 + s * 5, cy + 2, "G2")
                    x += 18
                elif kind == 2:
                    # a granite mortar and pestle
                    cv.ellipse(x + 5, cy + 4, 5, 4, "G3")
                    cv.ellipse(x + 5, cy + 3, 3, 2, "G1")
                    cv.line(x + 8, cy - 1, x + 12, cy + 6, "G4")
                    x += 16
                else:
                    # a photograph mounted on card, a label below
                    cv.rect(x, cy - 2, 11, 9, "N")
                    cv.rect(x + 1, cy - 1, 9, 7, "G3")
                    cv.rect(x + 1, cy + 2, 9, 4, "G2")
                    cv.px(x + 4, cy, "G4")
                    x += 15
                cv.rect(x - 9, gy1 - 4, 6, 2, "N")
                k += 1
        elif contents == "books":
            for k, bx in enumerate(range(8, w - 16, 16)):
                c = ["R", "P1", "W1", "O1", "B1", "L"][k % 6]
                by = gy0 + 4 + (k % 2) * 4
                cv.rect(bx, by, 12, 14, c)
                cv.hline(bx, by, 12, up(c))
                cv.vline(bx, by, 14, down(c))
                cv.rect(bx + 3, by + 3, 7, 3, "N" if c != "W1" else "O3")
                cv.hline(bx + 3, by + 9, 7, up(c))
        elif contents == "cones":
            x = 8
            k = 0
            while x < w - 14:
                if k % 3 == 1:
                    # a long sugar pine cone lying on its side
                    for s in range(20):
                        cv.vline(x + s, gy0 + 9 - (2 if 3 < s < 17 else 0), 6 + (4 if 3 < s < 17 else 0), "B2" if s % 2 else "B3")
                        if s % 2 == 0:
                            cv.px(x + s, gy0 + 8, "T1")
                    cv.px(x - 1, gy0 + 11, "B1")
                    x += 24
                else:
                    # giant sequoia cones: small, egg shaped, scaled
                    for s in range(2):
                        cx, cy = x + 4 + s * 6, gy0 + 7 + s * 9
                        cv.ellipse(cx, cy, 3.5, 4.5, "B2")
                        for t in range(4):
                            cv.hline(cx - 2, cy - 3 + t * 2, 4, "B3" if t % 2 else "B1")
                        cv.px(cx - 1, cy - 3, "T1")
                    x += 16
                cv.rect(x - 10, gy1 - 4, 6, 2, "N")
                k += 1
        else:
            # tubs in the freezer: vanilla, chocolate, strawberry, mint
            n = max(3, (w - 8) // 16)
            tw = (w - 8) / n
            for k in range(n):
                tx = int(4 + k * tw)
                c = ["N", "B2", "S", "M3", "T3"][k % 5]
                cv.rect(tx + 1, gy0 + 2, int(tw) - 2, gy1 - gy0 - 4, "G5")
                cv.ellipse(tx + tw / 2, gy0 + 11, tw / 2 - 3, 7, c)
                cv.ellipse(tx + tw / 2 - 2, gy0 + 9, tw / 2 - 7, 3, up(c))
                for s in range(4):
                    cv.px(tx + 4 + int(hash2(k, s, 3) * (tw - 8)), gy0 + 9 + int(hash2(s, k, 3) * 6), down(c))
                cv.rect(tx + int(tw) - 5, gy0 + 4, 2, 6, "G4")
            # a scoop
            cv.line(w - 14, gy0 + 3, w - 7, gy0 + 1, "G3")
        # the glass: a pale cast and two glints of the window across it
        yy, xx = np.mgrid[0:gy1 - gy0, 0:w - 8].astype(np.float32)
        band = (xx + yy * 1.4) % 90
        d = np.where((band > 10) & (band < 16), 1.6, 0.0) + np.where((band > 20) & (band < 22), 1.0, 0.0)
        if contents != "icecream":
            d += 0.25
        else:
            d *= 0.5
        cv.tone(d, x=4, y=gy0)
        cv.hline(4, gy0, w - 8, "W5")
        cv.vline(4, gy0, gy1 - gy0, "W4")
        # the front rail and the cabinet
        cv.rect(1, gy1, w - 2, 4, r[2])
        cv.hline(1, gy1, w - 2, r[3])
        cv.hline(1, gy1 + 3, w - 2, r[0])
        if contents == "icecream":
            cv.rect(1, gy1 + 4, w - 2, h - gy1 - 8, "N")
            cv.hline(1, gy1 + 4, w - 2, "G5")
            for k in range(1, 3):
                cv.vline(int(w * k / 3), gy1 + 6, h - gy1 - 12, "G4")
            cv.rect(6, gy1 + 8, w - 12, 6, "R")
            cv.hline(6, gy1 + 8, w - 12, "A1")
            for k in range(8, w - 8, 6):
                cv.px(k, gy1 + 11, "N")
            cv.rect(1, h - 5, w - 2, 4, "G2")
            cv.hline(1, h - 5, w - 2, "G3")
        else:
            panels(cv, 1, gy1 + 4, w - 2, h - gy1 - 9, r, max(2, (w - 2) // 40), 91 + w)
            cv.rect(1, h - 5, w - 2, 4, r[0])
            cv.hline(1, h - 5, w - 2, r[1])
        return finish(cv)
    return paint


PROPS = {
    "armchair": upholstered(LODGE_GREEN, arms=9, cushions=1),
    "armchair_gold": upholstered(OLD_GOLD, arms=9, cushions=1, pattern="dots"),
    "sofa": upholstered(LEATHER, arms=13, pillow=["P1", "R"]),
    "sofa_parlor": upholstered(VELVET, arms=12, pattern="dots", frame=WALNUT, crest=True, buttons=True),
    "sofa_rose": upholstered(CHINTZ, arms=12, pattern="rose", frame=OAK, crest=True, buttons=False),
    "chair": chair,
    "bench": bench,
    "pew": pew,
    "stool": stool,
    "bed_green": bed("green"),
    "bed_quilt": bed("quilt"),
    "bed_white": bed("white"),
    "cot": cot(["P0", "P1", "P2", "P3"]),
    "cot_brown": cot(["B1", "B2", "B3", "T1"]),
    "washstand": washstand,
    "dresser_mirror": dresser,
    "trunk": trunk(HONEY, "iron"),
    "trunk_dark": trunk(LEATHER, "brass"),
    "coffee_table": coffee_table,
    "table_long_pine": table_long("pine"),
    "table_long_check": table_long("check"),
    "table_long_picnic": table_long("picnic"),
    "table_long_plain": table_long("plain"),
    "table_long_paints": table_long("paints"),
    "table_round_red": table_round("red"),
    "table_round_white": table_round("white"),
    "table_round_linen": table_round("linen"),
    "table_round_green": table_round("green"),
    "counter": counter("default"),
    "counter_grill": counter("grill"),
    "counter_market": counter("market"),
    "counter_serving": counter("serving"),
    "counter_snacks": counter("snacks"),
    "desk": desk("papers"),
    "desk_lamp": desk("lamp"),
    "desk_telegraph": desk("telegraph"),
    "desk_typewriter": desk("typewriter"),
    "desk_writing": desk("writing"),
    "bookcase": bookcase(False),
    "bookcase_curios": bookcase(True),
    "piano": piano("upright"),
    "piano_organ": piano("organ"),
    "piano_parlor": piano("parlor"),
    "pulpit": pulpit,
    "case": case("museum"),
    "case_books": case("books"),
    "case_cones": case("cones"),
    "case_icecream": case("icecream"),
}


def paint_all(only: list[str] | None = None) -> int:
    from PIL import Image
    out = os.path.join(ROOT, "assets", "sprites", "interiors", "props")
    n = 0
    for name, fn in PROPS.items():
        if only and name not in only:
            continue
        path = os.path.join(out, name + ".png")
        if not os.path.exists(path):
            print("skipped", name, "(the builder hasn't drawn it)")
            continue
        w, h = Image.open(path).size
        cv = fn(w, h)
        assert (cv.w, cv.h) == (w, h), (name, cv.w, cv.h, w, h)
        cv.save(path)
        n += 1
    return n


if __name__ == "__main__":
    print("painted", paint_all(sys.argv[1:] or None), "pieces")
