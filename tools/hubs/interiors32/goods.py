"""The things that make a park room lived in, painted natively at 32px:
table lamps with mica shades, rocking chairs with a wool blanket over the
arm, a coat tree, a firewood box by the stove, a chainsaw-carved bear, and
the gift-shop goods (tables of field guides and folded park shirts, a bin of
plush black bears, a stand of sun hats and beanies).

Like furniture.py and fittings.py, each piece is drawn into the canvas size
the builder gave it, seen in 3/4 from the front and lit from the upper left,
in the Valley Days palette, with a dark rim round it. On its own:

    python3 tools/hubs/interiors32/goods.py      # paints every piece in place
"""
from __future__ import annotations

import importlib.util
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "ahwahnee32"))
sys.path.insert(0, HERE)

from kit import ROOT, Canvas, down, hash2, math, up  # noqa: E402

_spec = importlib.util.spec_from_file_location("ahw_props", os.path.join(HERE, "..", "ahwahnee32", "props.py"))
AP = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(AP)
rrect, finish = AP.rrect, AP.finish

OAK = ["B1", "B2", "B3", "T1"]
HONEY = ["B2", "B3", "T1", "T2"]


def _up(c: str) -> str:
    return up(c) if up(c) != "N" else c


def _shadow(cv: Canvas, cx: float, cy: float, rx: float, ry: float) -> None:
    """A soft floor shadow, darker at its heart."""
    cv.ellipse(cx, cy, rx, ry, "B0")
    cv.ellipse(cx, cy, rx * 0.7, ry * 0.6, "K0")


# ---------------------------------------------------------------- lamps and chairs

def table_lamp(w: int, h: int) -> Canvas:
    """A round oak side table with a craftsman lamp on it: a hammered copper
    base and a mica shade glowing amber, a book left open beside it."""
    cv = Canvas(w, h)
    cx = w // 2
    top = h - 24
    # the table: a round top seen at an angle, a pedestal and three feet
    for lx in (cx - 12, cx + 9):
        cv.rect(lx, top + 6, 3, h - top - 8, OAK[0])
        cv.vline(lx, top + 6, h - top - 8, OAK[1])
    cv.rect(cx - 2, top + 6, 5, h - top - 9, OAK[1])
    cv.vline(cx - 2, top + 6, h - top - 9, OAK[2])
    cv.hline(cx - 13, h - 3, 27, OAK[0])
    cv.ellipse(cx, top + 4, 16, 5, OAK[0])
    cv.ellipse(cx, top + 3, 16, 5, OAK[1])
    cv.ellipse(cx - 1, top + 2, 14, 3.5, OAK[2])
    cv.hline(cx - 9, top, 10, OAK[3])
    # a book, open, on the near edge
    cv.poly([(cx + 4, top + 3), (cx + 10, top + 1), (cx + 15, top + 3), (cx + 9, top + 5)], "N")
    cv.line(cx + 9, top + 1, cx + 9, top + 5, "G4")
    cv.hline(cx + 5, top + 3, 3, "G3")
    # the lamp: a copper base, a stem and a four-sided mica shade
    cv.ellipse(cx - 3, top + 1, 5, 2, "A0")
    cv.rect(cx - 6, top - 9, 7, 9, "A0")
    cv.vline(cx - 5, top - 9, 9, "A1")
    cv.px(cx - 3, top - 6, "A2")
    cv.rect(cx - 4, top - 18, 3, 9, "B1")
    sy = top - 34
    cv.poly([(cx - 15, sy + 16), (cx + 9, sy + 16), (cx + 3, sy), (cx - 9, sy)], "O2")
    cv.poly([(cx - 15, sy + 16), (cx - 6, sy + 16), (cx - 4, sy), (cx - 9, sy)], "A3")
    cv.poly([(cx + 1, sy + 16), (cx + 9, sy + 16), (cx + 3, sy), (cx, sy)], "O1")
    # copper straps between the mica panes
    for k in (-9, -3, 3):
        cv.line(cx + k * 0.6 - 2, sy, cx + k - 3, sy + 16, "A0")
    cv.hline(cx - 9, sy, 13, "B1")
    cv.hline(cx - 15, sy + 16, 25, "B1")
    cv.hline(cx - 14, sy + 17, 23, "A2")
    # flecks of mica catching the light
    for i in range(10):
        fx = cx - 11 + int(hash2(i, 1, 5) * 16)
        fy = sy + 3 + int(hash2(i, 2, 5) * 11)
        cv.px(fx, fy, "A3" if i % 2 else "O3")
    return finish(cv, "B0", light=False)


def rocker(w: int, h: int) -> Canvas:
    """A hickory rocking chair: a slatted back, arms, a rush seat with a
    striped wool blanket thrown over it, on curved rockers."""
    cv = Canvas(w, h)
    r = HONEY
    cx = w // 2
    # rockers: two long curves along the floor
    for xx in range(1, w - 1):
        u = (xx - cx) / (w / 2)
        yy = h - 4 - int(5 * u * u)
        cv.rect(xx, yy, 1, 3, r[0])
        cv.px(xx, yy, r[2])
    # back posts and the crest
    for px in (4, w - 7):
        cv.rect(px, 2, 3, h - 10, r[1])
        cv.vline(px, 2, h - 10, r[2])
        cv.px(px + 1, 1, r[3])
    for yy in (4, 9):
        cv.rect(5, yy, w - 10, 3, r[1])
        cv.hline(5, yy, w - 10, r[3])
    for sx in range(9, w - 9, 4):
        cv.vline(sx, 12, 12, r[2])
        cv.vline(sx + 1, 12, 12, r[0])
    # the seat
    cv.rect(3, 24, w - 6, 6, "O1")
    for yy in range(24, 30):
        for xx in range(3, w - 3):
            if (xx + yy) % 3 == 0:
                cv.px(xx, yy, "O0")
    cv.hline(3, 24, w - 6, "O3")
    # a striped blanket draped over the seat and down the front
    bx, bw = 7, w - 18
    cv.rect(bx, 20, bw, 18, "R")
    cv.vline(bx, 20, 18, "A1")
    cv.vline(bx + bw - 1, 22, 16, "A0")
    for k, (yy, c) in enumerate(((23, "O2"), (24, "K1"), (31, "O2"), (32, "K1"))):
        cv.hline(bx, yy, bw, c)
    for xx in range(bx, bx + bw, 2):
        cv.px(xx, 38, "A1")
    cv.poly([(bx + bw - 6, 20), (bx + bw, 20), (bx + bw + 1, 28)], "A0")
    # arms and front legs
    for ax in (1, w - 5):
        cv.rect(ax, 17, 4, 3, r[2])
        cv.hline(ax, 17, 4, r[3])
        cv.rect(ax + 1, 20, 2, h - 26, r[1])
    return finish(cv)


def coat_rack(w: int, h: int) -> Canvas:
    """A bentwood coat tree: a red wool hunting jacket, a canvas barn coat
    and a felt hat on its hooks, on a turned pole with splayed feet."""
    cv = Canvas(w, h)
    cx = w // 2
    cv.rect(cx - 1, 4, 3, h - 10, OAK[1])
    cv.vline(cx - 1, 4, h - 10, OAK[2])
    for dx in (-9, 9):
        cv.line(cx, h - 8, cx + dx, h - 2, OAK[0])
        cv.line(cx, h - 9, cx + dx, h - 3, OAK[1])
    cv.ellipse(cx, 3, 3, 2, OAK[2])
    for dx in (-6, 6):
        cv.line(cx, 10, cx + dx, 6, OAK[1])
    # a buffalo-check wool jacket on the left hook
    jx, jy = 2, 8
    cv.rect(jx, jy, 13, 30, "R")
    cv.rect(jx - 1, jy + 2, 4, 20, "A0")
    for yy in range(jy, jy + 30, 4):
        cv.hline(jx, yy, 13, "K1")
    for xx in range(jx + 1, jx + 13, 4):
        cv.vline(xx, jy, 30, "B0")
    cv.vline(jx + 12, jy + 1, 29, "A0")
    cv.poly([(jx + 4, jy), (jx + 10, jy), (jx + 7, jy + 6)], "B0")
    # a canvas barn coat on the right, its corduroy collar
    kx = w - 15
    cv.rect(kx, jy + 4, 13, 32, "T2")
    cv.vline(kx, jy + 4, 32, "T3")
    cv.vline(kx + 12, jy + 5, 31, "T1")
    cv.rect(kx + 1, jy + 4, 11, 4, "B1")
    for yy in (jy + 14, jy + 22, jy + 30):
        cv.px(kx + 6, yy, "B0")
    cv.rect(kx + 2, jy + 26, 4, 4, "T1")
    # a felt hat hung at the top
    cv.ellipse(cx + 1, 6, 8, 2, "B1")
    cv.rect(cx - 3, 1, 8, 5, "B1")
    cv.hline(cx - 3, 1, 8, "B2")
    cv.hline(cx - 3, 4, 8, "R")
    return finish(cv)


# ---------------------------------------------------------------- by the fire

def log_box(w: int, h: int) -> Canvas:
    """A plank box of split oak and pine by the stove: round ends of logs
    with their rings, bark on the outside, a fan of kindling at the back."""
    cv = Canvas(w, h)
    bt = h - 18
    # kindling standing up behind
    for i in range(9):
        kx = 6 + int(i * (w - 12) / 9)
        kh = 8 + int(hash2(i, 1, 3) * 6)
        cv.line(kx, bt, kx + (i % 3) - 1, bt - kh, "B3" if i % 2 else "T1")
    # the logs, ends towards us, stacked in two rows
    rows = [(bt + 1, 6), (bt - 6, 5)]
    for ry, n in rows:
        for i in range(n):
            lx = 6 + int((i + (0.5 if ry < bt else 0)) * (w - 12) / 6)
            rr = 4 + (hash2(i, ry, 4) > 0.5)
            cv.ellipse(lx, ry, rr + 1, rr + 1, "B1")
            cv.ellipse(lx, ry, rr, rr, "T2" if (i + ry) % 3 else "T1")
            cv.ellipse(lx, ry, rr * 0.5, rr * 0.5, "T1")
            cv.px(lx, ry, "B2")
            if (i + ry) % 2:
                cv.line(lx, ry, lx + rr, ry - 1, "B2")
    # the box front: three planks and corner posts
    cv.rect(1, bt + 3, w - 2, h - bt - 5, OAK[1])
    for yy in range(bt + 3, h - 2, 5):
        cv.hline(1, yy, w - 2, OAK[0])
        cv.hline(1, yy + 1, w - 2, OAK[2])
    for px in (1, w - 4):
        cv.rect(px, bt + 1, 3, h - bt - 3, OAK[0])
        cv.vline(px, bt + 1, h - bt - 3, OAK[2])
    cv.hline(2, bt + 3, w - 4, OAK[3])
    return finish(cv)


def bear_carving(w: int, h: int) -> Canvas:
    """A black bear carved from a cedar round with a chainsaw, sitting up on
    a stump: the saw marks left in its coat, a pale muzzle, a polished nose."""
    cv = Canvas(w, h)
    cx = w // 2
    # the stump
    cv.rect(cx - 12, h - 16, 24, 14, "B2")
    for xx in range(cx - 12, cx + 12, 3):
        cv.vline(xx, h - 15, 13, "B1")
    cv.vline(cx - 12, h - 16, 14, "B3")
    cv.ellipse(cx, h - 16, 12, 3, "T2")
    cv.ellipse(cx, h - 16, 7, 1.5, "T1")
    # the body, haunches and front paws
    by = h - 18
    cv.ellipse(cx, by - 12, 11, 13, "B0")
    cv.ellipse(cx - 2, by - 14, 8, 10, "B1")
    cv.ellipse(cx - 9, by - 2, 6, 4, "B0")
    cv.ellipse(cx + 9, by - 2, 6, 4, "B0")
    cv.rect(cx - 6, by - 10, 4, 10, "B1")
    cv.rect(cx + 2, by - 10, 4, 10, "B0")
    cv.hline(cx - 6, by - 1, 4, "T1")
    cv.hline(cx + 2, by - 1, 4, "T1")
    # the head: round ears, a tan muzzle, the nose
    hy = by - 30
    cv.ellipse(cx, hy, 8, 7, "B0")
    cv.ellipse(cx - 1, hy - 1, 6, 5, "B1")
    for ex in (-6, 6):
        cv.ellipse(cx + ex, hy - 6, 3, 3, "B0")
        cv.ellipse(cx + ex, hy - 6, 1.5, 1.5, "B2")
    cv.ellipse(cx, hy + 3, 4, 3, "T1")
    cv.ellipse(cx - 1, hy + 2, 2.5, 1.5, "T2")
    cv.rect(cx - 1, hy + 1, 3, 2, "K0")
    cv.px(cx - 1, hy + 1, "G3")
    cv.px(cx - 3, hy - 2, "K0")
    cv.px(cx + 3, hy - 2, "K0")
    # chainsaw strokes through the coat
    for i in range(16):
        sx = cx - 9 + int(hash2(i, 1, 9) * 18)
        sy = hy + 6 + int(hash2(i, 2, 9) * 22)
        cv.line(sx, sy, sx + 2, sy + 3, "B2" if i % 3 else "B3")
    return finish(cv)


# ---------------------------------------------------------------- the gift shop

_COVERS = ["P2", "W1", "R", "O1", "M0", "B1", "W2", "A0", "L", "P1"]


def _book(cv: Canvas, x: int, y: int, w: int, h: int, c: str) -> None:
    """A book lying flat, seen from the front: its cover on top, the page
    edge below."""
    cv.rect(x, y, w, 2, c)
    cv.hline(x, y, w, _up(c))
    cv.rect(x, y + 2, w, h - 2, "N")
    cv.hline(x, y + h - 1, w, "G4")
    cv.vline(x, y + 2, h - 2, down(c))


def book_table(w: int, h: int) -> Canvas:
    """A sale table of books about the park: stacks of field guides and
    histories, a few stood up to show their covers (a granite dome, a
    wildflower), and a little easel card."""
    cv = Canvas(w, h)
    top = 16
    # the table: a plank top over a skirt and four legs
    for lx in (3, w - 6):
        cv.rect(lx, top + 8, 3, h - top - 9, OAK[0])
        cv.vline(lx, top + 8, h - top - 9, OAK[1])
    cv.rect(1, top + 4, w - 2, 6, OAK[1])
    cv.hline(1, top + 9, w - 2, OAK[0])
    cv.rect(0, top, w, 5, OAK[2])
    cv.hline(0, top, w, OAK[3])
    for lx in (14, w - 17):
        cv.rect(lx, top + 8, 3, h - top - 9, OAK[0])
    # stacks lying flat
    x = 3
    i = 0
    while x < w - 14:
        n = 2 + int(hash2(i, 1, 7) * 3)
        bw = 12 + int(hash2(i, 2, 7) * 4)
        yy = top + 1
        for k in range(n):
            off = int(hash2(i, k, 8) * 3) - 1
            yy -= 4
            _book(cv, x + off, yy, bw, 4, _COVERS[(i * 3 + k) % len(_COVERS)])
        x += bw + 4
        i += 1
        if i == 2:
            # a guide stood up on a stand, its cover facing out
            cv.rect(x, top - 20, 15, 20, "W1")
            cv.rect(x + 1, top - 19, 13, 12, "W3")
            cv.poly([(x + 1, top - 7), (x + 5, top - 15), (x + 9, top - 12), (x + 13, top - 7)], "G4")
            cv.ellipse(x + 8, top - 12, 4, 3, "G5")
            cv.rect(x + 1, top - 7, 13, 2, "P1")
            cv.hline(x + 2, top - 4, 10, "N")
            cv.hline(x + 2, top - 2, 7, "W4")
            x += 19
        if i == 3:
            cv.rect(x, top - 18, 13, 18, "M1")
            cv.ellipse(x + 6, top - 11, 4, 4, "S")
            cv.ellipse(x + 6, top - 11, 1.5, 1.5, "O3")
            cv.vline(x + 6, top - 7, 5, "P2")
            cv.hline(x + 2, top - 3, 9, "N")
            x += 17
    # a hand-lettered card
    cv.rect(w - 12, top - 12, 10, 9, "N")
    cv.hline(w - 11, top - 9, 8, "R")
    cv.hline(w - 11, top - 6, 6, "G3")
    cv.line(w - 7, top - 3, w - 5, top, "B1")
    return finish(cv)


def shirt_table(w: int, h: int) -> Canvas:
    """A sale table of folded park T-shirts and sweatshirts in stacks, each
    with a printed badge on its chest (a dome over pines), a size card on
    each stack."""
    cv = Canvas(w, h)
    top = 18
    for lx in (3, w - 6, 14, w - 17):
        cv.rect(lx, top + 8, 3, h - top - 9, OAK[0])
        cv.vline(lx, top + 8, h - top - 9, OAK[1])
    cv.rect(1, top + 4, w - 2, 6, OAK[1])
    cv.hline(1, top + 9, w - 2, OAK[0])
    cv.rect(0, top, w, 5, OAK[2])
    cv.hline(0, top, w, OAK[3])
    cols = [("P1", "P2"), ("G4", "G5"), ("W1", "W2"), ("A0", "R"), ("O1", "O2"), ("K1", "G1")]
    n = max(3, (w - 4) // 20)
    sw = (w - 4) // n
    for i in range(n):
        x = 3 + i * sw
        d, c = cols[i % len(cols)]
        layers = 3 + (i % 2)
        y = top + 1
        for k in range(layers):
            y -= 5
            cv.rect(x, y, sw - 4, 5, c)
            cv.hline(x, y, sw - 4, _up(c))
            cv.hline(x, y + 4, sw - 4, d)
            cv.vline(x + sw - 5, y, 5, d)
        # the badge on the top shirt: a granite dome over a row of pines
        bx = x + (sw - 4) // 2
        cv.ellipse(bx, y + 2, 4, 2, "N" if c not in ("G5", "G4") else "P1")
        cv.px(bx - 1, y + 2, "G3")
        cv.px(bx + 1, y + 2, "G3")
        cv.hline(bx - 3, y + 3, 7, "P2")
        # a size card tucked in front
        cv.rect(x + 1, top - 3, 5, 3, "N")
        cv.px(x + 3, top - 2, "B1")
    return finish(cv)


def plush_bin(w: int, h: int) -> Canvas:
    """A woven bin heaped with plush black bears (and a cinnamon one), button
    eyes and tan muzzles, a few with a ribbon round the neck."""
    cv = Canvas(w, h)
    bt = h - 22
    # bears heaped behind the rim, back ones first
    spots = [(0.25, -8, "B0"), (0.75, -9, "B1"), (0.5, -13, "B0"), (0.15, -1, "B2"), (0.5, -3, "B0"), (0.85, -2, "B1")]
    for i, (u, dy, c) in enumerate(spots):
        bx = int(4 + u * (w - 8))
        by = bt + dy
        cv.ellipse(bx, by + 6, 7, 5, c)
        cv.ellipse(bx, by, 6, 5, c)
        cv.ellipse(bx - 1, by - 1, 4, 3, _up(c) if c != "B2" else "B3")
        for ex in (-5, 5):
            cv.ellipse(bx + ex, by - 4, 2, 2, c)
            cv.px(bx + ex, by - 4, "T1")
        cv.ellipse(bx, by + 2, 2.5, 1.8, "T2")
        cv.px(bx, by + 1, "K0")
        cv.px(bx - 2, by - 1, "K0")
        cv.px(bx + 2, by - 1, "K0")
        if i % 2:
            cv.hline(bx - 4, by + 5, 9, "R" if i != 3 else "W2")
    # the bin: woven splints, a rolled rim
    cv.poly([(1, bt + 2), (w - 1, bt + 2), (w - 4, h - 2), (3, h - 2)], "O1")
    for yy in range(bt + 3, h - 2):
        for xx in range(2, w - 2):
            if (xx // 3 + yy // 3) % 2 == 0 and (xx + yy) % 3 == 0:
                cv.px(xx, yy, "O0")
    for yy in range(bt + 6, h - 2, 5):
        cv.hline(3, yy, w - 6, "O0")
    cv.rect(0, bt, w, 4, "O2")
    cv.hline(0, bt, w, "O3")
    cv.hline(0, bt + 3, w, "O0")
    # a price tag on a string
    cv.rect(w - 11, bt + 8, 7, 5, "N")
    cv.px(w - 9, bt + 10, "R")
    return finish(cv)


def hat_stand(w: int, h: int) -> Canvas:
    """A spinning stand of hats for the trail: wide-brimmed sun hats, ball
    caps with a little dome on the front, and knit beanies with pompoms."""
    cv = Canvas(w, h)
    cx = w // 2
    cv.rect(cx - 1, 8, 3, h - 14, "G1")
    cv.vline(cx - 1, 8, h - 14, "G3")
    cv.ellipse(cx, h - 4, 11, 3, "K0")
    cv.ellipse(cx, h - 5, 10, 2, "G1")
    cv.hline(cx - 6, h - 6, 6, "G3")
    tiers = [6, 26, 46]
    for t, ty in enumerate(tiers):
        cv.rect(cx - 15, ty + 14, 31, 2, "G2")
        cv.hline(cx - 15, ty + 14, 31, "G4")
        for side in (-1, 1):
            hx = cx + side * 8
            if t == 0:
                # a sun hat: a wide straw brim and a band
                cv.ellipse(hx, ty + 10, 9, 3, "T2")
                cv.ellipse(hx, ty + 9, 9, 2, "T3")
                cv.rect(hx - 5, ty + 2, 10, 7, "T2")
                cv.ellipse(hx, ty + 2, 5, 2, "T3")
                cv.hline(hx - 5, ty + 6, 10, "P1" if side < 0 else "R")
            elif t == 1:
                # a ball cap: a crown, a bill, a patch on the front
                c = "P1" if side < 0 else "W1"
                cv.ellipse(hx, ty + 6, 6, 5, c)
                cv.rect(hx - 6, ty + 6, 12, 4, c)
                cv.ellipse(hx - 1, ty + 4, 3, 2, _up(c))
                cv.poly([(hx - 7, ty + 10), (hx + 7, ty + 10), (hx + 5, ty + 13), (hx - 5, ty + 13)], down(c))
                cv.rect(hx - 2, ty + 5, 5, 4, "N")
                cv.px(hx, ty + 6, "G3")
                cv.hline(hx - 1, ty + 8, 3, "P2")
            else:
                # a knit beanie with a cuff and a pompom
                c = "R" if side < 0 else "O2"
                cv.ellipse(hx, ty + 6, 6, 6, c)
                cv.rect(hx - 6, ty + 6, 12, 7, c)
                for xx in range(hx - 5, hx + 6, 2):
                    cv.vline(xx, ty + 3, 6, down(c))
                cv.rect(hx - 6, ty + 9, 12, 4, "N")
                cv.hline(hx - 6, ty + 10, 12, c)
                cv.ellipse(hx, ty - 1, 3, 3, "N")
                cv.px(hx - 1, ty - 2, "G5")
    cv.ellipse(cx, 7, 3, 2, "G3")
    return finish(cv, "K0")


# ---------------------------------------------------------------- the table

PROPS = {
    "table_lamp": table_lamp,
    "rocker": rocker,
    "coat_rack": coat_rack,
    "log_box": log_box,
    "bear_carving": bear_carving,
    "book_table": book_table,
    "shirt_table": shirt_table,
    "plush_bin": plush_bin,
    "hat_stand": hat_stand,
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


def sheet(path: str) -> None:
    """Every piece side by side on a floor-colored strip, for a look."""
    from PIL import Image
    sizes = {"table_lamp": (40, 60), "rocker": (36, 52), "coat_rack": (32, 80), "log_box": (56, 36),
             "bear_carving": (36, 64), "book_table": (88, 48), "shirt_table": (88, 48), "plush_bin": (44, 48),
             "hat_stand": (36, 80)}
    W = sum(s[0] + 12 for s in sizes.values()) + 12
    im = Image.new("RGBA", (W, 100), (138, 100, 64, 255))
    x = 12
    for name, (w, h) in sizes.items():
        cv = PROPS[name](w, h)
        im.alpha_composite(Image.fromarray(cv.a, "RGBA"), (x, 92 - h))
        x += w + 12
    im = im.resize((im.width * 3, im.height * 3), Image.NEAREST)
    im.save(path)


if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[1] == "sheet":
        sheet(sys.argv[2])
    else:
        print("painted", paint_all(sys.argv[1:] or None), "pieces")
