"""The Ahwahnee's materials at 32px: polished plank and tile floors, cut
granite, board-formed concrete stained like redwood, plaster, timber, the
painted basket-pattern beams, tall windows onto the Valley, stained glass,
kilim rugs, sconces and doorways."""
from __future__ import annotations

from kit import BAYER, C, Canvas, down, hash2, math, noise, np, radial, smoothstep, text, text_width, up

# Fabric and material ramps, dark to light.
RED = ["B1", "A0", "R", "A1"]
RUG_RED = ["B0", "R", "A0", "T3"]
RUG_GREEN = ["P0", "P2", "P1", "T3"]
RUG_GOLD = ["B1", "O1", "O0", "N"]
GREEN = ["P0", "P1", "P2", "P3"]
GOLD = ["O0", "O1", "O2", "O3"]
WOOD = ["B0", "B1", "B2", "B3"]
BRASS = ["O0", "O1", "O2", "O3", "A3"]
IRON = ["K0", "G0", "G1", "G2"]
LINEN = ["G3", "G4", "G5", "N"]


# ---------------------------------------------------------------- floors

def planks(cv: Canvas, x0: int, y0: int, w: int, h: int, seed: int, tones=("B2", "B3", "B2", "B3", "T1")) -> None:
    """Long polished boards running across the room, 12px wide, with
    staggered butt joints, grain, the odd knot and a lit top edge."""
    row_h = 12
    for r in range((h + row_h - 1) // row_h):
        y = y0 + r * row_h
        x = x0 - int(hash2(r, 1, seed) * 140)
        k = 0
        while x < x0 + w:
            ln = 120 + int(hash2(r, k, seed + 1) * 150)
            base = tones[int(hash2(r, k, seed + 2) * len(tones)) % len(tones)]
            bx0, bx1 = max(x, x0), min(x + ln, x0 + w)
            if bx1 > bx0:
                cv.rect(bx0, y, bx1 - bx0, row_h, base)
                # grain: long thin streaks, darker, a few lighter
                for g in range(int((bx1 - bx0) / 26)):
                    gx = bx0 + int(hash2(r * 31 + g, k, seed + 3) * (bx1 - bx0))
                    gy = y + 2 + int(hash2(r * 17 + g, k, seed + 4) * (row_h - 4))
                    gl = 6 + int(hash2(g, r * 7 + k, seed + 5) * 22)
                    cv.hline(gx, gy, min(gl, bx1 - gx), down(base) if g % 3 else up(base))
                if hash2(r, k, seed + 6) > 0.78:
                    kx = bx0 + 10 + int(hash2(r, k, seed + 7) * max(1, bx1 - bx0 - 20))
                    ky = y + 4 + int(hash2(k, r, seed + 8) * 4)
                    cv.ellipse(kx, ky, 2.5, 1.5, down(base))
                    cv.px(kx - 1, ky - 1, down(base, 2))
                    cv.hline(kx - 6, ky - 2, 4, down(base))
                    cv.hline(kx + 3, ky + 2, 4, down(base))
                cv.hline(bx0, y + 1, bx1 - bx0, up(base))
                cv.hline(bx0, y + row_h - 2, bx1 - bx0, down(base))
                cv.hline(bx0, y, bx1 - bx0, "B0" if base != "T1" else "B1")
                if x >= x0:
                    cv.vline(x, y, row_h, "B0")
                    cv.vline(x + 1, y + 1, row_h - 2, up(base))
                    # nail heads at the joint
                    cv.px(x + 4, y + 3, "B1")
                    cv.px(x + 4, y + row_h - 4, "B1")
            x += ln
            k += 1


def tiles(cv: Canvas, x0: int, y0: int, w: int, h: int, seed: int, a="T1", b="B3", size=32, grout="B1", dots=None) -> None:
    """Square floor tiles laid on the grid, two tones in a checker, each with
    its own wear and a bevelled lit edge."""
    for ty in range(0, h, size):
        for tx in range(0, w, size):
            t = a if ((tx // size + ty // size) % 2 == 0) else b
            x, y = x0 + tx, y0 + ty
            cv.rect(x, y, size, size, t)
            n = noise(size, size, 11, seed + tx * 7 + ty * 13)
            yy, xx = np.mgrid[0:size, 0:size]
            fleck = np.array([[hash2(x + i, y + j, seed) for i in range(size)] for j in range(size)])
            d = np.where(n > 0.8, 0.35, np.where(n < 0.18, -0.35, 0.0)) + np.where(fleck > 0.985, -1.0, 0.0)
            # a soft polish across each tile, brightest at its upper left
            d += 0.3 * (1 - (xx + yy) / (2 * size))
            cv.tone(d, x=x, y=y)
            cv.hline(x + 1, y + 1, size - 2, up(t))
            cv.vline(x + 1, y + 1, size - 2, up(t))
            cv.hline(x + 1, y + size - 2, size - 2, down(t))
            cv.vline(x + size - 2, y + 1, size - 2, down(t))
            cv.hline(x, y, size, grout)
            cv.vline(x, y, size, grout)
    if dots:
        for ty in range(0, h + 1, size):
            for tx in range(0, w + 1, size):
                _diamond(cv, x0 + tx, y0 + ty, 3, dots[0], dots[1])


def inlay_border(cv: Canvas, x: int, y: int, w: int, h: int, cols=("B0", "O2", "R", "T3")) -> None:
    """A mosaic band of stepped diamonds set into a tile floor, the hotel's
    basket pattern underfoot."""
    bw = 12
    for (rx, ry, rw, rh) in ((x, y, w, bw), (x, y + h - bw, w, bw), (x, y, bw, h), (x + w - bw, y, bw, h)):
        cv.rect(rx, ry, rw, rh, cols[0])
    for i in range(x + 6, x + w - 6, 12):
        _diamond(cv, i, y + 6, 4, cols[1], cols[2])
        _diamond(cv, i, y + h - 6, 4, cols[1], cols[2])
    for j in range(y + 18, y + h - 12, 12):
        _diamond(cv, x + 6, j, 4, cols[1], cols[2])
        _diamond(cv, x + w - 6, j, 4, cols[1], cols[2])
    cv.frame(x, y, w, h, cols[3])
    cv.frame(x + bw - 1, y + bw - 1, w - 2 * bw + 2, h - 2 * bw + 2, cols[3])


def _diamond(cv: Canvas, cx: int, cy: int, r: int, outer, inner) -> None:
    for k in range(r + 1):
        cv.hline(cx - (r - k), cy - k, (r - k) * 2 + 1, outer)
        cv.hline(cx - (r - k), cy + k, (r - k) * 2 + 1, outer)
    if r >= 3:
        for k in range(r - 1):
            cv.hline(cx - (r - 2 - k), cy - k, (r - 2 - k) * 2 + 1, inner)
            cv.hline(cx - (r - 2 - k), cy + k, (r - 2 - k) * 2 + 1, inner)


def carpet(cv: Canvas, x0: int, y0: int, w: int, h: int, seed: int, base="B1", motif="B2", border="O1") -> None:
    """Wall-to-wall wool carpet: a tight woven texture, a quiet lattice of
    small diamonds and a border inside the walls."""
    cv.rect(x0, y0, w, h, base)
    n = noise(h, w, 3, seed)
    yy, xx = np.mgrid[0:h, 0:w]
    weave = ((xx + yy) % 4 == 0) & (n > 0.45)
    cv.tone(np.where(weave, 0.4, 0.0), x=x0, y=y0)
    for j in range(y0 + 24, y0 + h - 16, 24):
        for i in range(x0 + 24 + (12 if (j // 24) % 2 else 0), x0 + w - 16, 24):
            _diamond(cv, i, j, 2, motif, motif)
    m = 14
    cv.frame(x0 + m, y0 + m, w - 2 * m, h - 2 * m, border)
    cv.frame(x0 + m + 3, y0 + m + 3, w - 2 * m - 6, h - 2 * m - 6, motif)


# ---------------------------------------------------------------- walls

def granite(cv: Canvas, x0: int, y0: int, w: int, h: int, seed: int, course: int = 16, light: float = 0.0) -> None:
    """Cut granite in courses: blocks of uneven length, a lit top-left edge, a
    shaded bottom-right, dark mortar and speckled grain."""
    cv.rect(x0, y0, w, h, "G1")
    r = 0
    y = y0
    while y < y0 + h:
        ch = course
        x = x0 - int(hash2(r, 3, seed) * 30)
        k = 0
        while x < x0 + w:
            bw = 26 + int(hash2(r, k, seed) * 30)
            t = ["G3", "G3", "G4", "G2", "G3"][int(hash2(k, r, seed + 1) * 5)]
            bx0, bx1 = max(x + 1, x0), min(x + bw, x0 + w)
            by1 = min(y + ch, y0 + h)
            if bx1 > bx0 and by1 > y + 1:
                cv.rect(bx0, y + 1, bx1 - bx0, by1 - y - 1, t)
                # speckle
                for s in range(int((bx1 - bx0) * (by1 - y) / 14)):
                    sx = bx0 + int(hash2(s, k * 13 + r, seed + 2) * (bx1 - bx0))
                    sy = y + 1 + int(hash2(k * 7 + r, s, seed + 3) * max(1, by1 - y - 1))
                    cv.px(sx, sy, down(t) if s % 3 else up(t))
                cv.hline(bx0, y + 1, bx1 - bx0, up(t))
                if x + 1 >= x0:
                    cv.vline(x + 1, y + 1, by1 - y - 1, up(t))
                cv.hline(bx0, by1 - 1, bx1 - bx0, down(t))
                if x + bw - 1 < x0 + w:
                    cv.vline(x + bw - 1, y + 1, by1 - y - 1, down(t))
            x += bw
            k += 1
        y += ch
        r += 1
    if light:
        cv.tone(np.full((h, w), light, np.float32), x=x0, y=y0)


def board_formed(cv: Canvas, x0: int, y0: int, w: int, h: int, seed: int, base="B2") -> None:
    """Concrete cast in board forms and stained to look like redwood, as the
    hotel was built: faint vertical board lines and tie holes."""
    cv.rect(x0, y0, w, h, base)
    n = noise(h, w, 24, seed)
    cv.tone(np.where(n > 0.78, 0.3, np.where(n < 0.2, -0.3, 0.0)), x=x0, y=y0)
    for i, bx in enumerate(range(x0 + 5, x0 + w, 9)):
        d = np.zeros((h, 2), np.float32)
        d[:, 0] = -0.5 if hash2(bx, 0, seed) > 0.3 else -0.8
        d[:, 1] = 0.25
        cv.tone(d, x=bx, y=y0)
        # one board in a few a shade off, as the forms took the stain
        if hash2(i, 5, seed) > 0.8:
            cv.tone(np.full((h, 7), 0.3 if hash2(i, 6, seed) > 0.5 else -0.3, np.float32), x=bx + 2, y=y0)
    for ty in range(y0 + 14, y0 + h - 6, 30):
        for tx in range(x0 + 14 + (ty // 30 % 2) * 22, x0 + w - 6, 44):
            cv.px(tx, ty, down(base, 2))
            cv.px(tx + 1, ty + 1, up(base))


def plaster(cv: Canvas, x0: int, y0: int, w: int, h: int, seed: int, base="T3") -> None:
    """Warm troweled plaster: soft mottling a step either way."""
    cv.rect(x0, y0, w, h, base)
    n = noise(h, w, 20, seed) * 0.75 + noise(h, w, 5, seed + 1) * 0.25
    cv.tone(np.where(n < 0.22, -0.3, 0.0), x=x0, y=y0)


def timber(cv: Canvas, x: int, y: int, w: int, h: int, seed: int = 1, vertical: bool = True) -> None:
    """A post or beam of dark stained timber with grain and a lit edge."""
    cv.rect(x, y, w, h, "B1")
    if vertical:
        for gx in range(x + 2, x + w - 1, 3):
            for gy in range(y, y + h, 1):
                if hash2(gx, gy // 7, seed) > 0.72:
                    cv.px(gx, gy, "B2")
        cv.vline(x, y, h, "B0")
        cv.vline(x + 1, y, h, "B2")
        cv.vline(x + 2, y, h, "B3")
        cv.vline(x + w - 1, y, h, "B0")
    else:
        for gy in range(y + 2, y + h - 1, 2):
            for gx in range(x, x + w):
                if hash2(gx // 9, gy, seed) > 0.7:
                    cv.px(gx, gy, "B2")
        cv.hline(x, y, w, "B2")
        cv.hline(x, y + 1, w, "B3")
        cv.hline(x, y + h - 1, w, "B0")


def frieze(cv: Canvas, y: int, h: int, x0: int = 0, w: int | None = None, ground="B0", cols=("R", "O2", "T3", "P2")) -> None:
    """The painted beams of the Ahwahnee: a band of stepped diamonds and
    zigzags taken from the Valley's baskets (tribal review passed)."""
    w = cv.w if w is None else w
    cv.rect(x0, y, w, h, ground)
    cv.hline(x0, y, w, cols[1])
    cv.hline(x0, y + h - 1, w, cols[1])
    cv.hline(x0, y + 2, w, cols[2])
    cv.hline(x0, y + h - 3, w, cols[2])
    mid = y + h // 2
    r = max(2, (h - 8) // 2)
    step = r * 2 + 6
    for i, cx in enumerate(range(x0 + step // 2, x0 + w, step)):
        _stepped(cv, cx, mid, r, cols[0] if i % 2 == 0 else cols[3], cols[1])
        # small zigzag between the diamonds
        zx = cx + step // 2
        for k in range(-1, 2):
            cv.px(zx + k, mid + (1 if k % 2 else -1), cols[2])


def _stepped(cv: Canvas, cx: int, cy: int, r: int, outer, inner) -> None:
    """A stepped (terraced) diamond, two pixels a step."""
    for k in range(0, r + 1):
        half = (r - k) // 2 * 2 + 1
        cv.hline(cx - half, cy - k, half * 2 + 1, outer)
        cv.hline(cx - half, cy + k, half * 2 + 1, outer)
    if r >= 4:
        _stepped(cv, cx, cy, r - 3, inner, inner)


def beam_ceiling(cv: Canvas, h: int = 22) -> None:
    """The ceiling beam along the top of the back wall, its face painted."""
    timber(cv, 0, 0, cv.w, h, 3, vertical=False)
    frieze(cv, 5, h - 9)
    cv.hline(0, h, cv.w, "K0")
    # its shadow on the wall below
    d = np.zeros((6, cv.w), np.float32)
    for i in range(6):
        d[i] = -1.2 * (1 - i / 6)
    cv.tone(d, x=0, y=h + 1)


def wainscot(cv: Canvas, x0: int, y0: int, w: int, h: int, seed: int) -> None:
    """Raised panels of dark timber along the bottom of a wall."""
    cv.rect(x0, y0, w, h, "B1")
    cv.hline(x0, y0, w, "B3")
    cv.hline(x0, y0 + 1, w, "B2")
    cv.hline(x0, y0 + 3, w, "B0")
    pw = 40
    for px in range(x0 + 4, x0 + w - pw // 2, pw + 6):
        ww = min(pw, x0 + w - 4 - px)
        cv.rect(px, y0 + 7, ww, h - 12, "B2")
        cv.hline(px, y0 + 7, ww, "B0")
        cv.vline(px, y0 + 7, h - 12, "B0")
        cv.hline(px + 1, y0 + h - 6, ww - 1, "B3")
        cv.vline(px + ww - 1, y0 + 8, h - 13, "B3")
        cv.rect(px + 4, y0 + 11, ww - 8, h - 20, "B1")
        for g in range(3):
            gy = y0 + 13 + int(hash2(px, g, seed) * max(1, h - 24))
            cv.hline(px + 6, gy, ww - 14, "B2")
    cv.hline(x0, y0 + h - 1, w, "B0")


def base_course(cv: Canvas, y: int, h: int, seed: int) -> None:
    """A granite skirting along the foot of the wall."""
    granite(cv, 0, y, cv.w, h, seed, course=h // 2 if h > 20 else h)
    cv.hline(0, y, cv.w, "G5")


# ---------------------------------------------------------------- the view

def view_color(gx: float, v: float, view: str, xx: int, yy: int, wx: float = 0.0, ww: float = 80.0) -> str:
    """The Valley seen through the hotel's windows (gx is the room x, v 0 at
    the top of the glass; wx, ww the window's middle and width). Hazy
    granite walls under a pale sky, Half Dome in the dome windows, then the
    forest and the meadow."""
    b = BAYER[yy & 3, xx & 3]
    sky = ["W5", "W5", "W4", "W4", "W3"]
    s = sky[min(4, int(v * 5 + b * 0.9))]
    # a few soft clouds
    cl = math.sin(gx * 0.045 + 1.7) * 0.5 + math.sin(gx * 0.11) * 0.3
    if 0.06 < v < 0.16 and cl > 0.35 and (v - 0.06) * 30 < (cl - 0.35) * 8 + 1:
        s = "N" if v < 0.12 else "W5"
    # far rim, hazy, and near walls
    far = 0.30 + 0.05 * math.sin(gx * 0.023 + 0.4) + 0.025 * math.sin(gx * 0.09)
    near = 0.40 + 0.09 * math.sin(gx * 0.012 + 2.1) + 0.04 * math.sin(gx * 0.047) + 0.015 * math.sin(gx * 0.19)
    if view == "dome":
        dx = (gx - wx) / (ww * 0.5)
        # Half Dome: the sheer northwest face on the left, the round back
        if -0.55 <= dx <= 1.2:
            near = min(near, 0.14 + 0.34 * ((dx + 0.55) / 1.75) ** 1.6)
    if view == "meadow":
        far += 0.1
        near += 0.12
    trees = 0.70 + 0.04 * math.sin(gx * 0.21) + 0.03 * math.sin(gx * 0.53 + 2)
    tx = int(gx) % 11
    trees -= max(0, 4 - abs(tx - 5)) * 0.022 * (1 if hash2(int(gx) // 11, 1, 3) > 0.35 else 0.4)
    if view == "forest":
        trees = 0.26 + 0.25 * hash2(int(gx) // 13, 2, 5) - max(0, 6 - abs(int(gx) % 13 - 6)) * 0.03
    if v >= trees:
        if view == "meadow" and v > 0.86:
            return ["M1", "M2", "M2", "M3"][int(hash2(int(gx) // 2, yy // 2, 9) * 4)]
        if v > 0.93:
            return "M1" if hash2(int(gx) // 3, yy, 4) > 0.4 else "M0"
        lit = (int(gx) % 11) < 5
        return ["P1", "P2", "P3"][min(2, int(hash2(int(gx) // 2, yy // 3, 6) * 1.8) + (1 if lit else 0))]
    if v >= near:
        depth = (v - near) / max(0.05, trees - near)
        slope = math.sin(gx * 0.012 + 2.1) * 0.09 + math.sin(gx * 0.047) * 0.04
        if view == "dome" and -0.55 <= (gx - wx) / (ww * 0.5) <= 1.2:
            dxx = (gx - wx) / (ww * 0.5)
            face = "G5" if dxx < -0.25 else ("G4" if dxx < 0.4 else "G3")
            if v - near < 0.02:
                return "G5"
            return face if b > depth * 0.6 else down(face)
        face = "G4" if (math.cos(gx * 0.012 + 2.1) > -0.2) else "G3"
        if v - near < 0.012:
            return "G5"
        # streaks down the face: water stains and joints
        if hash2(int(gx) // 3, int(v * 40), 7) > 0.86:
            face = down(face)
        return face if b > depth * 0.7 else down(face)
    if v >= far:
        return "W4" if v - far > 0.03 or b > 0.5 else "G5"
    return s


# ---------------------------------------------------------------- windows

def tall_window(cv: Canvas, x: int, y: int, w: int, h: int, view: str, transom: int, seed: int, glass_light: bool = True) -> None:
    """A tall window of many small panes onto the Valley, a band of stained
    glass across its top, in a deep timber frame on a granite sill."""
    timber(cv, x - 6, y - 6, w + 12, h + 10, seed)
    cv.rect(x - 2, y - 2, w + 4, h + 2, "B0")
    # glass
    for yy in range(h - transom):
        v = yy / (h - transom)
        for xx in range(w):
            cv.px(x + xx, y + transom + yy, view_color(x + xx, v * 0.92 + 0.04, view, x + xx, y + yy, x + w / 2, w))
    if glass_light:
        # reflections across the glass: two soft diagonal bands
        gh = h - transom
        yy, xx = np.mgrid[0:gh, 0:w].astype(np.float32)
        band = (xx + yy * 0.6) % (w * 1.6)
        d = np.where((band > w * 0.18) & (band < w * 0.34), 0.7, 0.0) + np.where((band > w * 0.42) & (band < w * 0.48), 0.5, 0.0)
        cv.tone(d, x=x, y=y + transom)
    if transom:
        stained(cv, x, y, w, transom, seed)
    # mullions and muntins
    nx = max(2, round(w / 22))
    for i in range(1, nx):
        mx = x + round(w * i / nx)
        cv.vline(mx - 1, y + transom, h - transom, "B0")
        cv.vline(mx, y + transom, h - transom, "B1")
    for my in range(y + transom + 20, y + h - 4, 20):
        cv.hline(x, my, w, "B0")
        cv.hline(x, my + 1, w, "B1")
    cv.rect(x, y + transom - 2, w, 3, "B1")
    cv.hline(x, y + transom - 2, w, "B3")
    # sill
    cv.rect(x - 8, y + h, w + 16, 5, "G4")
    cv.hline(x - 8, y + h, w + 16, "G5")
    cv.hline(x - 8, y + h + 4, w + 16, "G2")


def stained(cv: Canvas, x: int, y: int, w: int, h: int, seed: int) -> None:
    """Stained glass in Jeannette Dyer Spencer's manner: small leaded panes,
    a stepped diamond on a field of blue, rimmed in red and gold."""
    for yy in range(0, h, 4):
        for xx in range(0, w, 4):
            cx, cy = xx + 2 - w / 2, yy + 2 - h / 2
            d = abs(cx) / (w / 2) + abs(cy) / (h / 2)
            ring = int(d * 4)
            colset = ["O3", "R", "O2", "W2", "W3"]
            c = colset[min(ring, 4)]
            if ring >= 3 and hash2(xx // 4, yy // 4, seed) > 0.75:
                c = "P3"
            if yy < 4 or yy >= h - 4 or xx < 4 or xx >= w - 4:
                c = "R" if (xx // 4 + yy // 4) % 2 else "O2"
            cv.rect(x + xx, y + yy, 4, 4, c)
            cv.px(x + xx + 1, y + yy + 1, up(c))
    for yy in range(0, h + 1, 4):
        cv.hline(x, y + yy, w, "K0")
    for xx in range(0, w + 1, 4):
        cv.vline(x + xx, y, h, "K0")


def window_shaft(delta: np.ndarray, x: int, w: int, y_floor: int, length: int, strength: float = 0.9, slant: float = 0.5) -> None:
    """Adds a slanting shaft of daylight from a window at x..x+w onto the
    floor below it (into a room-sized light map)."""
    H, W = delta.shape
    for i in range(length):
        y = y_floor + i
        if y >= H:
            break
        t = i / length
        off = int(i * slant)
        a = strength * (1 - smoothstep(0.0, 1.0, t))
        x0, x1 = max(0, x + off), min(W, x + w + off)
        if x1 > x0:
            delta[y, x0:x1] += a


# ---------------------------------------------------------------- rugs

def rug(cv: Canvas, x: int, y: int, w: int, h: int, field: list[str], accent: list[str], seed: int, style: str = "kilim") -> None:
    """A wool rug in the hotel's manner: a fringed kilim with stepped
    medallions on a field, layered borders and a woven texture."""
    # fringe on the short ends
    for fy in range(y + 2, y + h - 2, 2):
        cv.hline(x - 5, fy, 5, "G5" if fy % 4 else "T3")
        cv.hline(x + w, fy, 5, "G5" if fy % 4 else "T3")
    f0, f1, f2, f3 = field
    cv.rect(x, y, w, h, f1)
    # weave texture
    yy, xx = np.mgrid[0:h, 0:w]
    n = noise(h, w, 5, seed)
    cv.tone(np.where(((xx // 2 + yy) % 3 == 0) & (n > 0.5), -0.45, 0.0) + np.where(n < 0.22, -0.5, 0.0), x=x, y=y)
    # borders
    cv.frame(x, y, w, h, f0)
    cv.rect(x + 2, y + 2, w - 4, 8, accent[0])
    cv.rect(x + 2, y + h - 10, w - 4, 8, accent[0])
    cv.rect(x + 2, y + 2, 8, h - 4, accent[0])
    cv.rect(x + w - 10, y + 2, 8, h - 4, accent[0])
    for i in range(x + 8, x + w - 6, 8):
        _diamond(cv, i, y + 6, 2, accent[1], accent[1])
        _diamond(cv, i, y + h - 6, 2, accent[1], accent[1])
    for j in range(y + 14, y + h - 10, 8):
        _diamond(cv, x + 6, j, 2, accent[1], accent[1])
        _diamond(cv, x + w - 6, j, 2, accent[1], accent[1])
    cv.frame(x + 10, y + 10, w - 20, h - 20, accent[2])
    cv.frame(x + 12, y + 12, w - 24, h - 24, f0)
    # field: a row of stepped medallions, little motifs scattered between
    inner_x, inner_w = x + 14, w - 28
    inner_y, inner_h = y + 14, h - 28
    n_med = max(1, round(inner_w / (inner_h * 1.7)))
    r = max(5, min(inner_h // 2 - 8, int(inner_w / n_med / 3.0) - 6))
    for i in range(n_med):
        cx = inner_x + int(inner_w * (i + 0.5) / n_med)
        cy = inner_y + inner_h // 2
        _medallion(cv, cx, cy, r, f0, f3, accent)
    for k in range(int(inner_w * inner_h / 500)):
        mx = inner_x + 4 + int(hash2(k, 1, seed) * (inner_w - 8))
        my = inner_y + 4 + int(hash2(k, 2, seed) * (inner_h - 8))
        near = min(abs(mx - (inner_x + int(inner_w * (i + 0.5) / n_med))) for i in range(n_med))
        if near > r + 6:
            cv.px(mx, my, f2)
            cv.px(mx - 1, my, f2)
            cv.px(mx + 1, my, f2)
            cv.px(mx, my - 1, f2)
            cv.px(mx, my + 1, f2)
    # a little wear and pile shading toward the near edge
    d = np.zeros((h, w), np.float32)
    d[-6:, :] = -0.35
    d[:4, :] += 0.25
    cv.tone(d, x=x, y=y)


def _medallion(cv: Canvas, cx: int, cy: int, r: int, dark, light, accent) -> None:
    """A stepped medallion: rings of terraced diamonds, half again as wide as
    tall, with hooks off its side points."""
    rings = [dark, accent[1], accent[2], accent[0], light, dark]
    i = 0
    while r - i * 3 >= 1:
        rr = r - i * 3
        c = rings[i % len(rings)]
        for k in range(rr + 1):
            half = int((rr - k) * 1.5) // 2 * 2 + 1
            cv.hline(cx - half, cy - k, half * 2 + 1, c)
            cv.hline(cx - half, cy + k, half * 2 + 1, c)
        i += 1
    ext = int(r * 1.5) // 2 * 2 + 1
    for s_ in (-1, 1):
        x0 = cx + s_ * (ext + 1)
        cv.hline(min(x0, x0 + s_ * 4), cy, 5, dark)
        cv.vline(x0 + s_ * 4, cy - 3, 7, dark)
        cv.px(x0 + s_ * 3, cy - 3, dark)
        cv.px(x0 + s_ * 3, cy + 3, dark)


# ---------------------------------------------------------------- fittings

def sconce(cv: Canvas, x: int, y: int) -> None:
    """A wrought-iron wall sconce with an amber parchment shade."""
    cv.rect(x - 1, y + 10, 3, 8, "K0")
    cv.hline(x - 4, y + 17, 9, "K0")
    cv.px(x - 4, y + 16, "K0")
    cv.px(x + 4, y + 16, "K0")
    cv.poly([(x - 6, y + 10), (x + 6, y + 10), (x + 4, y), (x - 4, y)], "A2")
    cv.vline(x - 5, y + 2, 8, "A3")
    cv.vline(x + 4, y + 2, 8, "A1")
    cv.hline(x - 4, y, 9, "O1")
    cv.hline(x - 6, y + 10, 13, "O0")
    for k in range(-3, 4, 2):
        cv.px(x + k, y + 5, "A1")


def sconce_glow(delta: np.ndarray, x: int, y: int, r: float = 46, s: float = 1.3) -> None:
    H, W = delta.shape
    delta += s * radial(H, W, x, y + 6, r, r * 0.8)


def wall_sign(cv: Canvas, cx: int, y: int, s: str) -> None:
    """A carved timber board with gilded letters."""
    tw = text_width(s) + 16
    x = cx - tw // 2
    cv.rect(x, y, tw, 15, "B1")
    cv.frame(x, y, tw, 15, "B0")
    cv.hline(x + 1, y + 1, tw - 2, "B3")
    cv.hline(x + 1, y + 13, tw - 2, "B0")
    cv.rect(x + 3, y + 3, tw - 6, 9, "B0")
    text(cv, x + 8, y + 4, s, "O3", shadow="B0")
    for sx in (x + 4, x + tw - 5):
        cv.px(sx, y + 7, "O2")


def door_side(cv: Canvas, x: int, y: int, left: bool) -> None:
    """An opening two tiles tall in a side wall: a timber-framed passage with
    the next room's warm light spilling through."""
    cv.rect(x, y - 8, 32, 72, "B1")
    cv.hline(x, y - 8, 32, "B3")
    cv.rect(x + (0 if left else 6), y, 26, 64, "K0")
    d = np.zeros((64, 26), np.float32)
    for i in range(26):
        d[:, i] = (2.0 * (i / 26) if left else 2.0 * (1 - i / 26))
    sub = Canvas(26, 64, "B0")
    sub.tone(d)
    cv.blit(sub, x + (0 if left else 6), y)
    jx = x + 26 if left else x
    cv.rect(jx, y - 8, 6, 72, "B2")
    cv.vline(jx, y - 8, 72, "B3")
    cv.vline(jx + 5, y - 8, 72, "B0")
    # threshold
    cv.rect(x, y + 60, 32, 4, "G4")
    cv.hline(x, y + 60, 32, "G5")


def door_front(cv: Canvas, cx: int, rh: int, mat: list[str]) -> None:
    """The doorway in the front wall: threshold, jambs and a woven mat."""
    cv.rect(cx - 48, rh - 32, 96, 32, "B1")
    cv.rect(cx - 40, rh - 32, 80, 32, "K0")
    cv.rect(cx - 48, rh - 34, 96, 4, "G4")
    cv.hline(cx - 48, rh - 34, 96, "G5")
    cv.rect(cx - 36, rh - 12, 72, 10, mat[1])
    cv.frame(cx - 36, rh - 12, 72, 10, mat[0])
    for i in range(cx - 32, cx + 32, 6):
        _diamond(cv, i + 3, rh - 7, 2, mat[2], mat[2])


def arch(cv: Canvas, cx: int, wall_h: int, look: str, seed: int) -> None:
    """A doorway in the back wall: a granite arch, a timber one with
    panelled doors, an open arch with the lobby's light beyond, or the
    elevator's brass gate."""
    dw, dh = 52, 76
    x, y = cx - dw // 2, wall_h - dh
    if look == "stone":
        sub = Canvas(dw + 28, dh + 18)
        granite(sub, 0, 0, dw + 28, dh + 18, seed, course=12)
        cv.blit(sub, x - 14, y - 14)
        # voussoirs: a ring of wedge stones round the opening
        cv.ellipse(cx, y + dw // 2, dw / 2 + 9, dw / 2 + 9, "G4")
        cv.ellipse(cx, y + dw // 2, dw / 2 + 9, dw / 2 + 9 - 1, "G4")
        for a in range(0, 181, 18):
            ang = math.radians(180 + a)
            r0, r1 = dw / 2 + 1, dw / 2 + 9
            cv.line(cx + math.cos(ang) * r0, y + dw // 2 + math.sin(ang) * r0,
                    cx + math.cos(ang) * r1, y + dw // 2 + math.sin(ang) * r1, "G2")
        cv.rect(x - 9, y + dw // 2, dw + 18, dh - dw // 2, "G3")
        for gy in range(y + dw // 2, y + dh, 12):
            cv.hline(x - 9, gy, 9, "G2")
            cv.hline(x + dw, gy, 9, "G2")
            cv.hline(x - 9, gy + 1, 9, "G5")
            cv.hline(x + dw, gy + 1, 9, "G5")
    else:
        timber(cv, x - 10, y - 10, dw + 20, dh + 10, seed)
        frieze(cv, y - 10, 9, x - 10, dw + 20)
    cv.ellipse(cx, y + dw // 2, dw / 2, dw / 2, "K0")
    cv.rect(x, y + dw // 2, dw, dh - dw // 2, "K0")
    if look == "elevator":
        cv.ellipse(cx, y + dw // 2, dw / 2 - 2, dw / 2 - 2, "O0")
        cv.rect(x + 2, y + dw // 2, dw - 4, dh - dw // 2, "O0")
        for gx in range(x + 4, x + dw - 3, 5):
            for gy in range(y + 6, y + dh):
                if (cx - gx) ** 2 + (y + dw // 2 - gy) ** 2 <= (dw / 2 - 3) ** 2 or gy >= y + dw // 2:
                    cv.px(gx, gy, "O2")
                    cv.px(gx + 1, gy, "O1")
        for gy in (y + dw // 2 + 4, y + dh - 14):
            cv.hline(x + 2, gy, dw - 4, "O3")
            cv.hline(x + 2, gy + 1, dw - 4, "O0")
        # the floor dial above
        cv.ellipse(cx, y - 18, 10, 6, "O2")
        cv.ellipse(cx, y - 18, 8, 4, "N")
        cv.line(cx, y - 18, cx + 5, y - 21, "K0")
        cv.vline(cx, y - 12, 2, "O1")
    elif look == "open":
        sub = Canvas(dw - 4, dh - 4, "B1")
        yy, xx = np.mgrid[0:dh - 4, 0:dw - 4].astype(np.float32)
        sub.tone(2.6 * (yy / (dh - 4)) + 0.5 - np.abs(xx - (dw - 4) / 2) / dw)
        tiles(sub, 0, dh - 22, dw - 4, 18, seed, a="T2", b="T1", size=9)
        sub.tone(np.full((dh - 4, dw - 4), -0.6, np.float32))
        mask = Canvas(dw - 4, dh - 4)
        mask.ellipse((dw - 4) / 2, dw // 2 - 2, dw / 2 - 2, dw / 2 - 2, "K0")
        mask.rect(0, dw // 2 - 2, dw - 4, dh, "K0")
        sub.a[mask.a[..., 3] == 0] = 0
        cv.blit(sub, x + 2, y + 2)
    else:
        for k in range(2):
            px = x + 2 + k * (dw // 2 - 2)
            pw = dw // 2 - 2
            cv.rect(px, y + 22, pw, dh - 22, "B2")
            cv.frame(px, y + 22, pw, dh - 22, "B0")
            cv.rect(px + 4, y + 28, pw - 8, 18, "B1")
            cv.rect(px + 4, y + 50, pw - 8, 20, "B1")
            cv.hline(px + 4, y + 28, pw - 8, "B0")
            cv.hline(px + 4, y + 50, pw - 8, "B0")
        cv.px(cx - 3, y + 48, "O3")
        cv.px(cx + 2, y + 48, "O3")
    cv.rect(x - 4, wall_h - 4, dw + 8, 4, "G4")
    cv.hline(x - 4, wall_h - 4, dw + 8, "G5")
