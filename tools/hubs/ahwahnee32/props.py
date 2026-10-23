"""The Ahwahnee's furniture, painted natively at 32px. Each piece is drawn
into the canvas size the interior builder gave it (w x h, frames side by side
for the fireplace), seen in 3/4 from the front and lit from the upper left,
with a dark rim round it."""
from __future__ import annotations

import materials as M
from kit import Canvas, down, hash2, math, np, up

RED = ["B1", "A0", "R", "A1"]
# upholstery red: shadow, body, seat, highlight (the palette has one true red)
UPH_RED = ["A0", "R", "R", "A1"]
GREEN = ["P0", "P1", "P2", "P3"]
GOLD = ["O0", "O1", "O2", "O3"]
WOOD = ["B0", "B1", "B2", "B3"]


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


def _legs(cv: Canvas, xs: list[int], y: int, h: int, c="B1") -> None:
    for x in xs:
        cv.rect(x, y, 3, h, c)
        cv.vline(x, y, h, up(c))
        cv.px(x + 1, y + h - 1, "B0")


# ---------------------------------------------------------------- upholstery

def _pattern_band(cv: Canvas, x: int, y: int, w: int, ground: str, motif: str) -> None:
    """A woven band across a front panel: little stepped diamonds."""
    cv.rect(x, y, w, 4, ground)
    for i in range(x + 3, x + w - 2, 6):
        cv.px(i, y + 1, motif)
        cv.hline(i - 1, y + 2, 3, motif)
        cv.px(i, y + 3, motif)


def sofa(ramp: list[str], pillows: list[str], band: str):
    def paint(w: int, h: int) -> Canvas:
        cv = Canvas(w, h)
        d0, d1, d2, d3 = ramp
        x0, x1 = 2, w - 2
        # the back, seen from above and in front
        rrect(cv, x0 + 6, 3, x1 - x0 - 12, 18, d1, 4)
        cv.rect(x0 + 8, 4, x1 - x0 - 16, 4, d2)
        cv.hline(x0 + 9, 4, x1 - x0 - 18, d3)
        # tufting
        for bx in range(x0 + 16, x1 - 12, 12):
            for by in (11, 16):
                cv.px(bx + (6 if by == 16 else 0), by, d0)
                cv.px(bx + (6 if by == 16 else 0) - 1, by - 1, d2)
        # seat cushions
        n = max(2, (x1 - x0 - 24) // 34)
        cw = (x1 - x0 - 24) / n
        for i in range(n):
            cx = int(x0 + 12 + i * cw)
            rrect(cv, cx, 20, int(cw) - 1, 11, d2, 2)
            cv.hline(cx + 2, 20, int(cw) - 5, d3)
            cv.hline(cx + 1, 30, int(cw) - 3, d1)
        # front skirt with its woven band
        cv.rect(x0 + 8, 31, x1 - x0 - 16, 8, d1)
        _pattern_band(cv, x0 + 8, 33, x1 - x0 - 16, d0, band)
        cv.hline(x0 + 8, 38, x1 - x0 - 16, d0)
        # rolled arms
        for ax in (x0, x1 - 13):
            rrect(cv, ax, 9, 13, 30, d1, 4)
            rrect(cv, ax + 1, 9, 11, 8, d2, 3)
            cv.hline(ax + 3, 10, 7, d3)
            cv.vline(ax + (11 if ax == x0 else 1), 16, 21, d0)
        # throw pillows
        for i, pc in enumerate(pillows):
            px = x0 + 16 if i == 0 else x1 - 30
            rrect(cv, px, 12, 14, 12, pc, 3)
            cv.hline(px + 3, 13, 8, up(pc))
            cv.hline(px + 3, 22, 8, down(pc))
            cv.px(px + 7, 17, down(pc))
        _legs(cv, [x0 + 4, x1 - 7, w // 2 - 1], 39, h - 41)
        return finish(cv)
    return paint


def armchair(ramp: list[str], band: str):
    def paint(w: int, h: int) -> Canvas:
        cv = Canvas(w, h)
        d0, d1, d2, d3 = ramp
        rrect(cv, 6, 3, w - 12, 20, d1, 5)
        cv.rect(9, 4, w - 18, 4, d2)
        cv.hline(10, 4, w - 20, d3)
        cv.px(w // 2, 12, d0)
        cv.px(w // 2 - 1, 11, d2)
        rrect(cv, 9, 21, w - 18, 11, d2, 2)
        cv.hline(11, 21, w - 22, d3)
        cv.rect(8, 32, w - 16, 7, d1)
        _pattern_band(cv, 8, 34, w - 16, d0, band)
        for ax in (2, w - 12):
            rrect(cv, ax, 11, 10, 28, d1, 4)
            rrect(cv, ax + 1, 11, 8, 7, d2, 3)
            cv.hline(ax + 3, 12, 4, d3)
        _legs(cv, [5, w - 8], 39, h - 41)
        return finish(cv)
    return paint


# ---------------------------------------------------------------- tables

def coffee_table(w: int, h: int) -> Canvas:
    cv = Canvas(w, h)
    rrect(cv, 2, 3, w - 4, 12, "B2", 2)
    cv.hline(4, 3, w - 8, "B3")
    for gx in range(6, w - 6, 9):
        cv.hline(gx, 6 + (gx % 5), 5, "B1")
    cv.rect(2, 15, w - 4, 4, "B1")
    cv.hline(2, 18, w - 4, "B0")
    _legs(cv, [4, w - 7], 19, h - 21)
    cv.rect(7, 19, w - 14, 2, "B1")
    # a stack of books and a coffee cup
    for i, c in enumerate(("W1", "R", "P2")):
        cv.rect(8 + i, 9 - i * 2, 16 - i * 2, 2, c)
        cv.hline(8 + i, 9 - i * 2, 16 - i * 2, up(c))
    cv.rect(w - 18, 6, 6, 5, "N")
    cv.hline(w - 18, 6, 6, "G4")
    cv.px(w - 12, 8, "N")
    cv.ellipse(w - 15, 11, 5, 1.5, "G5")
    return finish(cv)


def _cloth_table(cv: Canvas, w: int, h: int, cloth: list[str], round_: bool) -> int:
    """A table under a hanging cloth; returns the y of the cloth's top."""
    c0, c1, c2, c3 = cloth
    if round_:
        cv.ellipse(w / 2, 14, w / 2 - 3, 11, c2)
        cv.ellipse(w / 2 - 2, 12, w / 2 - 8, 7, c3)
        cv.rect(4, 14, w - 8, 20, c1)
        cv.ellipse(w / 2, 34, w / 2 - 4, 4, c1)
        for fx in range(8, w - 6, 7):
            cv.vline(fx, 18, 17, c0)
            cv.vline(fx + 1, 18, 17, c2)
        cv.rect(w // 2 - 6, 37, 12, 3, "B1")
        cv.hline(w // 2 - 8, 39, 16, "B0")
        return 4
    cv.rect(2, 3, w - 4, 16, c2)
    cv.hline(3, 3, w - 6, c3)
    cv.rect(2, 19, w - 4, 13, c1)
    for fx in range(6, w - 4, 10):
        cv.vline(fx, 20, 12, c0)
        cv.vline(fx + 1, 20, 12, c2)
    cv.hline(2, 31, w - 4, c0)
    _legs(cv, [5, w - 8], 32, h - 34)
    return 3


def table_round(set_: str):
    def paint(w: int, h: int) -> Canvas:
        cv = Canvas(w, h)
        _cloth_table(cv, w, h, ["G3", "G4", "G5", "N"], True)
        cx = w // 2
        if set_ == "tea":
            # a silver tea service on a tray
            cv.ellipse(cx, 13, 14, 5, "G3")
            cv.ellipse(cx, 12, 13, 4, "G4")
            cv.ellipse(cx - 3, 9, 5, 4, "G4")
            cv.ellipse(cx - 4, 8, 3, 2, "N")
            cv.rect(cx - 4, 4, 3, 2, "G2")
            cv.line(cx + 2, 8, cx + 5, 6, "G3")
            for ox in (6, 10):
                cv.rect(cx + ox - 2, 11, 4, 3, "N")
                cv.hline(cx + ox - 2, 11, 4, "W4")
            cv.ellipse(cx - 14, 16, 4, 2, "N")
            cv.ellipse(cx - 14, 15, 2, 1, "A0")
        else:
            # a glass vase of wildflowers: lupine, poppies and shooting stars
            cv.rect(cx - 3, 6, 6, 9, "W4")
            cv.vline(cx - 2, 7, 7, "W5")
            cv.hline(cx - 3, 14, 6, "W3")
            for i in range(9):
                fx = cx - 9 + int(hash2(i, 1, 4) * 18)
                fy = -0 + 1 + int(hash2(i, 2, 4) * 7)
                cv.line(cx, 8, fx, fy + 2, "P2")
                c = ["L", "R", "S", "O3", "L"][i % 5]
                cv.px(fx, fy, c)
                cv.px(fx + 1, fy, c)
                cv.px(fx, fy + 1, down(c))
        return finish(cv)
    return paint


def table_long(feast: bool):
    def paint(w: int, h: int) -> Canvas:
        cv = Canvas(w, h)
        cloth = ["G3", "G4", "G5", "N"]
        top = _cloth_table(cv, w, h, cloth, False)
        if feast:
            # the Bracebridge table: a red runner, greenery and platters
            cv.rect(2, 8, w - 4, 6, "R")
            cv.hline(2, 8, w - 4, "A1")
            cv.hline(2, 13, w - 4, "A0")
            cv.rect(2, 19, w - 4, 4, "R")
            for gx in range(4, w - 4, 3):
                cv.px(gx, 9 + (gx * 7) % 3, "P2" if gx % 2 else "P3")
                if gx % 13 == 0:
                    cv.px(gx, 11, "R")
            cx = w // 2
            # the boar's head platter and fruit
            cv.ellipse(cx, 11, 13, 4, "G4")
            cv.ellipse(cx, 10, 9, 4, "T1")
            cv.ellipse(cx - 2, 9, 5, 2, "T2")
            cv.px(cx + 7, 10, "R")
            for fx in (cx - 46, cx + 46):
                cv.ellipse(fx, 11, 9, 3, "O1")
                for k in range(5):
                    cv.ellipse(fx - 5 + k * 2.5, 9 + (k % 2), 2, 2, ["R", "O3", "M2", "R", "A1"][k])
        # place settings
        n = max(3, w // 30)
        for i in range(n):
            px = int(8 + (w - 16) * (i + 0.5) / n)
            if feast and abs(px - w // 2) < 20:
                continue
            cv.ellipse(px, 15, 5, 2.5, "N")
            cv.ellipse(px, 15, 3, 1.5, "G5")
            cv.vline(px - 7, 13, 4, "G3")
            cv.vline(px + 7, 13, 4, "G3")
            cv.rect(px + 4, 7, 3, 4, "W5")
            cv.px(px + 4, 7, "N")
        # candlesticks with their flames
        for cxp in (w // 4, w * 3 // 4) if not feast else (w // 4, w // 2 - 22, w // 2 + 22, w * 3 // 4):
            cv.rect(cxp - 2, 10, 4, 2, "O1")
            cv.rect(cxp - 1, 2, 2, 8, "N")
            cv.px(cxp - 1, 1, "A2")
            cv.px(cxp - 1, 0, "O3")
            cv.vline(cxp - 1, 2, 8, "G5")
        return finish(cv)
    return paint


def chair(w: int, h: int) -> Canvas:
    """A dining chair seen from behind: a tall ladder back of dark oak with a
    leather seat."""
    cv = Canvas(w, h)
    cv.rect(3, 2, 3, h - 4, "B1")
    cv.rect(w - 6, 2, 3, h - 4, "B1")
    cv.vline(3, 2, h - 4, "B2")
    cv.vline(w - 6, 2, h - 4, "B2")
    cv.rect(3, 1, w - 6, 4, "B2")
    cv.hline(3, 1, w - 6, "B3")
    for y in (9, 15):
        cv.rect(5, y, w - 10, 3, "B1")
        cv.hline(5, y, w - 10, "B3")
    # the hotel's stepped motif cut in the top rail
    cv.px(w // 2, 2, "R")
    cv.hline(w // 2 - 1, 3, 3, "R")
    cv.rect(2, 20, w - 4, 7, "A0")
    cv.hline(3, 20, w - 6, "A1")
    cv.hline(2, 26, w - 4, "B1")
    for x in (4, w - 6):
        cv.px(x, 23, "O2")
    _legs(cv, [3, w - 6], 27, h - 29)
    return finish(cv)


# ---------------------------------------------------------------- the great pieces

def hearth(w: int, h: int) -> Canvas:
    """One of the Great Lounge's two sandstone fireplaces, big enough to
    stand in, its fire in two frames."""
    fw = w // 2
    out = Canvas(w, h)
    for f in range(2):
        cv = Canvas(fw, h)
        # the sandstone surround, in big dressed blocks
        sx0, sx1 = 4, fw - 4
        cv.rect(sx0, 6, sx1 - sx0, h - 18, "T2")
        y = 6
        r = 0
        while y < h - 12:
            ch = 18 if r % 2 == 0 else 14
            x = sx0 - (10 if r % 2 else 0)
            k = 0
            while x < sx1:
                bw = 30 + int(hash2(r, k, 5) * 18)
                t = ["T2", "T2", "T3", "T1"][int(hash2(k, r, 6) * 4)]
                bx0, bx1 = max(x, sx0), min(x + bw, sx1)
                cv.rect(bx0, y, bx1 - bx0, ch, t)
                cv.hline(bx0, y, bx1 - bx0, up(t))
                cv.hline(bx0, y + ch - 1, bx1 - bx0, "T0")
                if x > sx0:
                    cv.vline(x, y, ch, "T0")
                    cv.vline(x + 1, y, ch, up(t))
                for s in range((bx1 - bx0) * ch // 30):
                    cv.px(bx0 + int(hash2(s, k + r * 9, 7) * (bx1 - bx0)), y + int(hash2(k, s + r, 8) * ch), down(t))
                x += bw
                k += 1
            y += ch
            r += 1
        # mantel shelf of timber
        cv.rect(sx0 - 3, 40, sx1 - sx0 + 6, 7, "B1")
        cv.hline(sx0 - 3, 40, sx1 - sx0 + 6, "B3")
        cv.hline(sx0 - 3, 41, sx1 - sx0 + 6, "B2")
        cv.hline(sx0 - 3, 46, sx1 - sx0 + 6, "B0")
        # things on the mantel: brass candlesticks and a pair of baskets' worth of shadow
        for mx in (sx0 + 12, sx1 - 14):
            cv.rect(mx, 30, 3, 10, "N")
            cv.rect(mx - 1, 38, 5, 2, "O1")
            cv.px(mx + 1, 28, "A2")
            cv.px(mx + 1, 27, "O3")
        cv.rect(fw // 2 - 10, 32, 20, 8, "B2")
        cv.hline(fw // 2 - 10, 32, 20, "B3")
        cv.rect(fw // 2 - 8, 34, 16, 4, "G4")
        # the opening: a flat arch over a deep firebox
        ox0, ox1 = 26, fw - 26
        oy0, oy1 = 64, h - 18
        cv.rect(ox0 - 4, oy0 - 6, ox1 - ox0 + 8, 6, "T3")
        cv.hline(ox0 - 4, oy0 - 6, ox1 - ox0 + 8, "G5")
        cv.hline(ox0 - 4, oy0 - 1, ox1 - ox0 + 8, "T1")
        for vx in range(ox0, ox1, 12):
            cv.vline(vx, oy0 - 6, 6, "T1")
        cv.rect(ox0, oy0, ox1 - ox0, oy1 - oy0, "K0")
        # brick back, warmed by the fire
        for by in range(oy0 + 4, oy1 - 4, 5):
            off = 0 if (by // 5) % 2 else 5
            for bx in range(ox0 + 4 + off, ox1 - 4, 10):
                cv.rect(bx, by, 8, 3, "B1")
                cv.hline(bx, by, 8, "A0")
        cv.rect(ox0, oy0, 5, oy1 - oy0, "B0")
        cv.rect(ox1 - 5, oy0, 5, oy1 - oy0, "B0")
        # andirons and logs
        fy = oy1 - 8
        for ax in (ox0 + 12, ox1 - 14):
            cv.rect(ax, fy - 10, 3, 12, "K0")
            cv.ellipse(ax + 1, fy - 11, 2.5, 2.5, "O2")
        cv.rect(ox0 + 8, fy - 2, ox1 - ox0 - 16, 5, "B1")
        cv.hline(ox0 + 8, fy - 2, ox1 - ox0 - 16, "B2")
        cv.rect(ox0 + 14, fy - 7, ox1 - ox0 - 28, 5, "B2")
        cv.hline(ox0 + 14, fy - 7, ox1 - ox0 - 28, "B3")
        cv.ellipse(ox0 + 14, fy - 5, 2.5, 2.5, "T2")
        cv.ellipse(ox1 - 14, fy - 5, 2.5, 2.5, "T2")
        # the fire
        fx0, fx1 = ox0 + 12, ox1 - 12
        for xx in range(fx0, fx1):
            u = (xx - fx0) / (fx1 - fx0)
            base = math.sin(u * math.pi)
            flick = 0.65 + 0.35 * math.sin(xx * 0.55 + f * 2.3) * math.sin(xx * 0.21 + f * 1.1)
            ht = int(8 + 34 * base * flick)
            for k in range(ht):
                t = k / max(1, ht)
                c = "A3" if t < 0.3 and base > 0.5 else ("O3" if t < 0.45 else ("A2" if t < 0.7 else ("A1" if t < 0.9 else "A0")))
                if t > 0.82 and (xx + k + f) % 3 == 0:
                    continue
                cv.px(xx, fy - 6 - k, c)
        for s in range(6):
            ex = fx0 + int(hash2(s, f, 9) * (fx1 - fx0))
            ey = fy - 44 - int(hash2(s, f + 3, 9) * 14)
            cv.px(ex, ey, "A3" if s % 2 else "O3")
        # embers
        for ex in range(ox0 + 10, ox1 - 10, 3):
            cv.px(ex, fy + 3, "A1" if (ex + f) % 2 else "A2")
        # fire glow on the stone round the opening
        glow = np.zeros((h, fw), np.float32)
        yy, xx = np.mgrid[0:h, 0:fw].astype(np.float32)
        dist = np.sqrt(((xx - fw / 2) / 70) ** 2 + ((yy - (oy1 - 20)) / 60) ** 2)
        glow = np.where((xx < ox0) | (xx >= ox1) | (yy < oy0), 1.2 * np.clip(1 - dist, 0, 1), 0.0)
        cv.tone(glow)
        # hearthstone
        cv.rect(0, h - 18, fw, 14, "G3")
        cv.hline(0, h - 18, fw, "G5")
        cv.hline(0, h - 17, fw, "G4")
        for jx in range(18, fw, 36):
            cv.vline(jx, h - 17, 13, "G2")
        cv.hline(0, h - 5, fw, "G1")
        # an iron fire screen, half open
        for sx in range(ox0 - 2, ox0 + 18, 2):
            cv.vline(sx, oy1 - 26, 26, "K0")
        cv.rect(ox0 - 3, oy1 - 28, 22, 3, "K0")
        # fire tools on their stand
        tx = fw - 14
        cv.vline(tx, h - 54, 40, "K0")
        cv.rect(tx - 3, h - 16, 7, 2, "K0")
        cv.ellipse(tx, h - 56, 2.5, 2.5, "O2")
        cv.line(tx - 4, h - 50, tx - 4, h - 22, "G1")
        cv.line(tx + 4, h - 50, tx + 4, h - 22, "G1")
        cv.rect(tx + 2, h - 24, 5, 4, "K0")
        cv.rim(0.5, -0.6)
        cv.outline("B0")
        out.blit(cv, f * fw, 0)
    return out


def piano(w: int, h: int) -> Canvas:
    """The lounge's grand piano: an ebony case curving back to its tail, the
    lid closed and gleaming, the keyboard toward the room."""
    cv = Canvas(w, h)
    # the case, seen from above: straight bass side, curved treble side to the tail
    pts = [(4, 40), (4, 6), (16, 3), (40, 3), (58, 6), (70, 14), (78, 26), (84, 36), (84, 40)]
    cv.poly(pts, "K0")
    cv.poly([(p[0], p[1] + 8) for p in pts[-2:]] + [(4, 48), (4, 40)], "K0")
    cv.rect(4, 40, 80, 8, "B0")
    cv.hline(4, 47, 80, "K0")
    # gloss: the window reflected along the lid
    cv.poly([(10, 8), (38, 6), (52, 9), (30, 14), (10, 14)], "B0")
    cv.line(12, 9, 44, 7, "G2")
    cv.line(14, 11, 30, 10, "G1")
    cv.line(60, 14, 72, 26, "G1")
    cv.hline(6, 40, 76, "G1")
    # keyboard
    cv.rect(6, 41, 68, 9, "N")
    for kx in range(7, 74, 3):
        cv.vline(kx, 41, 9, "G4")
    for kx in range(8, 72, 3):
        if (kx // 3) % 7 not in (2, 6):
            cv.rect(kx, 41, 2, 5, "K0")
    cv.rect(4, 50, 72, 3, "B0")
    cv.hline(4, 50, 72, "G1")
    # music stand with a score
    cv.rect(22, 30, 34, 9, "K0")
    cv.rect(26, 31, 12, 7, "N")
    cv.rect(40, 31, 12, 7, "G5")
    for ly in (33, 35):
        cv.hline(27, ly, 10, "G3")
        cv.hline(41, ly, 10, "G3")
    # lyre, pedals and legs
    cv.rect(38, 53, 4, 8, "K0")
    cv.rect(34, 60, 12, 2, "O2")
    for lx in (7, 70):
        cv.rect(lx, 53, 4, h - 55, "K0")
        cv.vline(lx, 53, h - 55, "G0")
        cv.rect(lx - 1, h - 4, 6, 2, "O1")
    cv.rect(76, 46, 4, h - 48, "K0")
    return finish(cv, "K0", light=False)


def lamp(w: int, h: int) -> Canvas:
    """A wrought-iron floor lamp with a lit parchment shade."""
    cv = Canvas(w, h)
    cx = w // 2
    cv.poly([(cx - 12, 22), (cx + 12, 22), (cx + 8, 3), (cx - 8, 3)], "A2")
    cv.poly([(cx - 12, 22), (cx - 5, 22), (cx - 3, 3), (cx - 8, 3)], "A3")
    cv.poly([(cx + 6, 22), (cx + 12, 22), (cx + 8, 3), (cx + 5, 3)], "A1")
    cv.hline(cx - 8, 3, 17, "O1")
    cv.hline(cx - 12, 22, 25, "O0")
    # a band of the hotel's pattern round the shade
    for k in range(-9, 10, 3):
        cv.px(cx + k, 18, "A0")
        cv.px(cx + k, 17, "A1")
    cv.rect(cx - 1, 23, 3, h - 30, "K0")
    cv.vline(cx - 1, 23, h - 30, "G1")
    cv.ellipse(cx, 44, 3, 2, "K0")
    cv.poly([(cx, h - 9), (cx - 10, h - 3), (cx - 8, h - 2), (cx, h - 6), (cx + 8, h - 2), (cx + 10, h - 3)], "K0")
    cv.px(cx - 1, h - 7, "G1")
    return finish(cv, "B0", light=False)


def plant(kind: str):
    def paint(w: int, h: int) -> Canvas:
        cv = Canvas(w, h)
        cx = w // 2
        top = h - 22
        if kind == "brass":
            cv.poly([(cx - 10, top), (cx + 10, top), (cx + 7, h - 4), (cx - 7, h - 4)], "O1")
            cv.poly([(cx - 10, top), (cx - 4, top), (cx - 3, h - 4), (cx - 7, h - 4)], "O2")
            cv.vline(cx - 7, top + 2, 12, "O3")
            cv.rect(cx - 11, top - 2, 23, 4, "O2")
            cv.hline(cx - 11, top - 2, 23, "O3")
            cv.hline(cx - 7, top + 9, 15, "O0")
            cv.rect(cx - 6, h - 4, 13, 2, "O0")
            fronds = 11
            cols = ("P2", "P3", "M0")
        elif kind == "fern":
            cv.poly([(cx - 9, top), (cx + 9, top), (cx + 7, h - 3), (cx - 7, h - 3)], "W1")
            cv.vline(cx - 6, top + 2, 14, "W2")
            cv.rect(cx - 10, top - 2, 21, 4, "W2")
            cv.hline(cx - 10, top - 2, 21, "W3")
            for k in range(-6, 7, 3):
                cv.px(cx + k, top + 8, "N")
            fronds = 14
            cols = ("P2", "P3", "M1")
        else:
            cv.poly([(cx - 9, top), (cx + 9, top), (cx + 6, h - 3), (cx - 6, h - 3)], "A0")
            cv.vline(cx - 6, top + 2, 14, "A1")
            cv.rect(cx - 10, top - 2, 21, 4, "A1")
            cv.hline(cx - 10, top - 2, 21, "A2")
            fronds = 10
            cols = ("P2", "P3", "M0")
        cv.ellipse(cx, top - 1, 9, 2, "B0")
        for i in range(fronds):
            a = math.pi * (0.08 + 0.84 * i / (fronds - 1))
            ln = (top - 4) * (0.65 + 0.35 * hash2(i, 1, len(kind)))
            if kind == "fern":
                ex, ey = cx - math.cos(a) * ln * 0.75, top - 2 - math.sin(a) * ln * 0.55
            else:
                ex, ey = cx - math.cos(a) * ln * 0.55, top - 2 - math.sin(a) * ln
            steps = 18
            for s in range(steps):
                t = s / steps
                px = cx + (ex - cx) * t
                py = top - 2 + (ey - top + 2) * t + (math.sin(t * math.pi) * -3 if kind != "fern" else t * t * 8)
                c = cols[1] if t < 0.5 else cols[0]
                cv.px(px, py, c)
                if kind != "brass" or s % 2:
                    side = 1 + int(2 * math.sin(t * math.pi))
                    cv.px(px - side * math.sin(a), py - side * 0.6, cols[2] if i % 3 == 0 else cols[1])
                    cv.px(px + side * math.sin(a), py + side * 0.4, cols[0])
        return finish(cv, "P0", light=False)
    return paint


def column(w: int, h: int) -> Canvas:
    """A granite pier of the Dining Room, with a timber capital where the
    trusses spring."""
    cv = Canvas(w, h)
    M.granite(cv, 3, 14, w - 6, h - 26, 41, course=14, light=0.15)
    cv.vline(3, 14, h - 26, "G5")
    cv.vline(w - 4, 14, h - 26, "G1")
    cv.rect(0, 2, w, 12, "B1")
    cv.hline(0, 2, w, "B3")
    cv.hline(0, 3, w, "B2")
    cv.hline(0, 13, w, "B0")
    M.frieze(cv, 6, 6, 1, w - 2)
    cv.rect(1, h - 12, w - 2, 10, "G3")
    cv.hline(1, h - 12, w - 2, "G5")
    cv.hline(1, h - 3, w - 2, "G1")
    return finish(cv, "K0", light=False)


def bench(w: int, h: int) -> Canvas:
    """A settle of dark oak with a green cushion, its back cut with the
    stepped pattern."""
    cv = Canvas(w, h)
    cv.rect(4, 2, w - 8, 12, "B1")
    cv.hline(4, 2, w - 8, "B3")
    cv.hline(4, 3, w - 8, "B2")
    for i, px in enumerate(range(10, w - 10, 12)):
        cv.px(px, 7, "R" if i % 2 else "O2")
        cv.hline(px - 1, 8, 3, "R" if i % 2 else "O2")
        cv.px(px, 9, "R" if i % 2 else "O2")
    cv.rect(2, 14, w - 4, 8, "P1")
    cv.hline(3, 14, w - 6, "P3")
    cv.hline(3, 15, w - 6, "P2")
    for k in range(3):
        cv.vline(int(2 + (w - 4) * (k + 1) / 4), 15, 6, "P0")
    cv.rect(2, 22, w - 4, 4, "B1")
    cv.hline(2, 25, w - 4, "B0")
    for ax in (1, w - 6):
        cv.rect(ax, 6, 5, 20, "B2")
        cv.hline(ax, 6, 5, "B3")
    _legs(cv, [4, w - 7], 26, h - 28)
    return finish(cv)


# ---------------------------------------------------------------- the lobby

def counter(w: int, h: int) -> Canvas:
    """The front desk: dark timber with a basket-pattern band, a brass bell,
    the guest register and a reading lamp."""
    cv = Canvas(w, h)
    cv.rect(2, 14, w - 4, 10, "B2")
    cv.hline(2, 14, w - 4, "B3")
    cv.hline(2, 15, w - 4, "T1")
    for gx in range(6, w - 6, 14):
        cv.hline(gx, 18 + gx % 4, 7, "B1")
    cv.rect(2, 24, w - 4, h - 26, "B1")
    cv.hline(2, 24, w - 4, "B0")
    M.frieze(cv, 27, 8, 4, w - 8)
    pw = (w - 12) // 4
    for i in range(4):
        px = 6 + i * pw
        cv.rect(px + 2, 38, pw - 4, h - 44, "B2")
        cv.frame(px + 2, 38, pw - 4, h - 44, "B0")
        cv.hline(px + 3, h - 7, pw - 6, "B3")
        cv.vline(px + pw - 3, 39, h - 46, "B3")
        cv.rect(px + 6, 42, pw - 12, h - 52, "B1")
    cv.rect(2, h - 4, w - 4, 2, "B0")
    # the register, open, a pen, the bell, a lamp and a little sign
    cv.rect(40, 8, 28, 9, "N")
    cv.vline(54, 8, 9, "G3")
    for ly in (10, 12, 14):
        cv.hline(42, ly, 10, "G3")
        cv.hline(56, ly, 10, "G3")
    cv.rect(38, 15, 32, 2, "R")
    cv.line(62, 9, 68, 5, "K0")
    cv.ellipse(100, 12, 5, 4, "O2")
    cv.ellipse(99, 10, 2, 1.5, "O3")
    cv.rect(96, 15, 9, 2, "O0")
    cv.px(100, 7, "O1")
    lx = w - 30
    cv.rect(lx - 1, 2, 3, 13, "O1")
    cv.poly([(lx - 9, 6), (lx + 9, 6), (lx + 5, -1), (lx - 5, -1)], "P2")
    cv.hline(lx - 9, 6, 19, "P1")
    cv.hline(lx - 4, 0, 9, "P3")
    cv.rect(lx - 6, 14, 13, 3, "O0")
    cv.rect(14, 9, 16, 7, "B0")
    cv.rect(15, 10, 14, 5, "O2")
    cv.hline(17, 12, 10, "B1")
    return finish(cv)


def luggage(w: int, h: int) -> Canvas:
    """A bellman's brass luggage cart stacked with leather cases and a
    hatbox."""
    cv = Canvas(w, h)
    # the cart: a carpeted deck, brass uprights and an arched top rail
    for ux in (4, w - 7):
        cv.rect(ux, 6, 3, h - 16, "O1")
        cv.vline(ux, 6, h - 16, "O3")
    cv.rect(4, 4, w - 8, 3, "O1")
    cv.hline(4, 4, w - 8, "O3")
    cv.ellipse(w // 2, 5, (w - 8) / 2, 3, "O2")
    cv.rect(2, h - 12, w - 4, 4, "R")
    cv.hline(2, h - 12, w - 4, "A1")
    cv.rect(2, h - 8, w - 4, 2, "O0")
    for wx in (7, w - 9):
        cv.ellipse(wx, h - 4, 3, 3, "K0")
        cv.px(wx - 1, h - 5, "G2")
    # the cases
    cases = [(6, h - 24, w - 12, 12, "B2"), (9, h - 34, w - 20, 10, "W1"), (11, h - 42, w - 24, 8, "T1")]
    for (x, y, cw, ch, c) in cases:
        rrect(cv, x, y, cw, ch, c, 2)
        cv.hline(x + 2, y, cw - 4, up(c))
        cv.hline(x + 1, y + ch - 1, cw - 2, down(c))
        for sx in (x + 5, x + cw - 7):
            cv.vline(sx, y, ch, "B0")
            cv.px(sx, y + ch // 2, "O2")
        cv.rect(x + cw // 2 - 3, y - 2, 7, 2, "B0")
    cv.rect(16, h - 30, 6, 4, "R")
    cv.rect(30, h - 21, 7, 5, "O3")
    cv.ellipse(w // 2, h - 49, 9, 3, "S")
    cv.rect(w // 2 - 9, h - 49, 18, 6, "S")
    cv.ellipse(w // 2, h - 43, 9, 3, "L")
    cv.ellipse(w // 2, h - 50, 9, 3, "N")
    return finish(cv)


# ---------------------------------------------------------------- the guest room

def bed(w: int, h: int) -> Canvas:
    """A guest-room bed: a carved headboard, white pillows, a turned-down
    sheet and a red spread with the hotel's woven band."""
    cv = Canvas(w, h)
    # headboard
    cv.rect(3, 2, w - 6, 18, "B1")
    cv.hline(3, 2, w - 6, "B3")
    cv.hline(3, 3, w - 6, "B2")
    M.frieze(cv, 8, 7, 6, w - 12)
    for px in (2, w - 7):
        cv.rect(px, 0, 5, 22, "B2")
        cv.hline(px, 0, 5, "B3")
        cv.vline(px + 4, 1, 21, "B0")
    # mattress, pillows and sheet
    cv.rect(5, 20, w - 10, h - 30, "G5")
    for px in (8, w // 2 + 2):
        rrect(cv, px, 21, w // 2 - 10, 10, "N", 3)
        cv.hline(px + 2, 30, w // 2 - 14, "G4")
        cv.hline(px + 3, 22, w // 2 - 16, "N")
    cv.rect(5, 33, w - 10, 6, "N")
    cv.hline(5, 38, w - 10, "G4")
    # the spread
    cv.rect(4, 39, w - 8, h - 49, "R")
    cv.hline(4, 39, w - 8, "A1")
    cv.rect(4, h - 26, w - 8, 6, "B0")
    for i in range(8, w - 8, 6):
        cv.px(i, h - 24, "O2")
        cv.hline(i - 1, h - 23, 3, "O2")
        cv.px(i, h - 22, "O2")
    for fx in range(10, w - 8, 12):
        cv.vline(fx, 42, h - 70, "A0")
    # the spread falls over the foot: the front face
    cv.rect(3, h - 12, w - 6, 6, "A0")
    cv.hline(3, h - 12, w - 6, "R")
    # footboard
    cv.rect(2, h - 7, w - 4, 5, "B2")
    cv.hline(2, h - 7, w - 4, "B3")
    cv.hline(2, h - 3, w - 4, "B0")
    return finish(cv)


def dresser(w: int, h: int) -> Canvas:
    """A chest of drawers with brass pulls and a swinging mirror."""
    cv = Canvas(w, h)
    # mirror on its stand
    cx = w // 2
    cv.rect(cx - 13, 2, 26, 24, "B1")
    cv.rect(cx - 11, 4, 22, 20, "W3")
    cv.poly([(cx - 11, 14), (cx - 2, 4), (cx + 3, 4), (cx - 11, 20)], "W4")
    cv.line(cx + 2, 23, cx + 10, 13, "W4")
    cv.rect(cx - 11, 18, 22, 6, "T2")
    cv.hline(cx - 13, 2, 26, "B3")
    for px in (cx - 15, cx + 13):
        cv.rect(px, 8, 3, 18, "B2")
    # top and drawers
    cv.rect(2, 26, w - 4, 6, "B2")
    cv.hline(2, 26, w - 4, "B3")
    cv.hline(2, 27, w - 4, "T1")
    cv.rect(3, 32, w - 6, h - 36, "B1")
    for i, dy in enumerate(range(33, h - 6, 8)):
        cv.rect(5, dy, w - 10, 7, "B2")
        cv.hline(5, dy, w - 10, "B3")
        cv.hline(5, dy + 6, w - 10, "B0")
        for px in (w // 3, w * 2 // 3):
            cv.rect(px - 2, dy + 3, 4, 2, "O2")
            cv.px(px - 2, dy + 3, "O3")
    _legs(cv, [4, w - 7], h - 4, 3)
    # a brush and a little dish on top
    cv.rect(8, 23, 8, 3, "T2")
    cv.ellipse(w - 12, 25, 4, 1.5, "N")
    return finish(cv)


def desk(w: int, h: int) -> Canvas:
    """A writing desk under a green-shaded lamp, hotel stationery laid out."""
    cv = Canvas(w, h)
    cv.rect(2, 14, w - 4, 10, "B2")
    cv.hline(2, 14, w - 4, "B3")
    cv.hline(2, 15, w - 4, "T1")
    cv.rect(2, 24, w - 4, 6, "B1")
    cv.hline(2, 29, w - 4, "B0")
    for px in (3, w - 21):
        cv.rect(px, 30, 18, h - 33, "B1")
        cv.frame(px, 30, 18, h - 33, "B0")
        for dy in range(32, h - 6, 7):
            cv.rect(px + 2, dy, 14, 6, "B2")
            cv.hline(px + 2, dy, 14, "B3")
            cv.rect(px + 7, dy + 3, 4, 1, "O2")
    cv.rect(w // 2 - 8, 25, 16, 3, "B2")
    cv.px(w // 2, 26, "O2")
    # leather blotter, letter and pen
    cv.rect(22, 16, 30, 7, "P1")
    cv.rect(26, 15, 14, 7, "N")
    for ly in (17, 19):
        cv.hline(28, ly, 9, "G3")
    cv.line(42, 16, 48, 20, "K0")
    cv.rect(10, 17, 8, 5, "G5")
    cv.hline(10, 17, 8, "N")
    # the lamp
    lx = w - 14
    cv.rect(lx - 1, 4, 2, 12, "O1")
    cv.rect(lx - 4, 15, 9, 2, "O0")
    cv.poly([(lx - 9, 6), (lx + 8, 6), (lx + 5, 0), (lx - 6, 0)], "P2")
    cv.hline(lx - 6, 0, 12, "P3")
    cv.hline(lx - 9, 6, 18, "A3")
    return finish(cv)


def trunk(w: int, h: int) -> Canvas:
    """A steamer trunk with oak slats, brass corners and travel labels."""
    cv = Canvas(w, h)
    rrect(cv, 3, 3, w - 6, 12, "T1", 3)
    cv.hline(5, 3, w - 10, "T2")
    cv.rect(3, 15, w - 6, h - 18, "B2")
    cv.hline(3, 15, w - 6, "B0")
    for sx in (10, w // 2, w - 11):
        cv.rect(sx - 2, 3, 4, h - 6, "B3")
        cv.vline(sx - 2, 3, h - 6, "T2")
    for (x, y) in ((3, 3), (w - 7, 3), (3, h - 7), (w - 7, h - 7)):
        cv.rect(x, y, 4, 4, "O2")
        cv.px(x, y, "O3")
    cv.rect(w // 2 - 3, 13, 6, 5, "O2")
    cv.px(w // 2, 16, "B0")
    for (x, y, c) in ((14, 19, "W2"), (32, 22, "O3"), (16, 7, "R")):
        cv.rect(x, y, 6, 5, c)
        cv.hline(x + 1, y + 2, 4, down(c))
    return finish(cv)


PROPS = {
    "hearth_ahw_great": hearth,
    "counter_ahw_desk": counter,
    "luggage_ahw": luggage,
    "plant_ahw_brass": plant("brass"),
    "plant_ahw_fern": plant("fern"),
    "plant_ahw": plant("terracotta"),
    "armchair_ahw_red": armchair(UPH_RED, "O2"),
    "armchair_ahw_gold": armchair(GOLD, "R"),
    "armchair_ahw_green": armchair(GREEN, "O2"),
    "sofa_ahw_red": sofa(UPH_RED, ["O2", "P2"], "O2"),
    "sofa_ahw_green": sofa(GREEN, ["R", "O2"], "O2"),
    "sofa_ahw_gold": sofa(GOLD, ["P2", "R"], "R"),
    "coffee_table_ahw": coffee_table,
    "piano_ahw_grand": piano,
    "table_round_ahw_tea": table_round("tea"),
    "table_round_ahw_vase": table_round("vase"),
    "chair_ahw": chair,
    "lamp_ahw": lamp,
    "column_ahw": column,
    "table_long_ahw_linen": table_long(False),
    "table_long_ahw_feast": table_long(True),
    "bench_ahw_dark": bench,
    "bed_ahw": bed,
    "dresser_ahw_mirror": dresser,
    "desk_ahw_lamp": desk,
    "trunk_ahw": trunk,
}
