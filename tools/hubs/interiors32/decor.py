"""What hangs on the back walls of the park's rooms, at 32px: windows onto
the place outside, framed paintings, photographs, maps and menus, signs,
shelves of goods, pegs of tools and coats, post-office boxes, a flag, a
clock, lancet windows, a cross, notice boards, antlers, a rack of shirts,
the Museum's baskets and a jail's bars. Positions are in 32px pixels."""
from __future__ import annotations

import materials as M
import walls as WL
from kit import C, Canvas, down, hash2, math, np, radial, text, text_width, up


# ---------------------------------------------------------------- windows

def window(cv: Canvas, x: int, y: int, w: int, h: int, view: str, seed: int, curtains=None) -> None:
    """A sash window onto the place outside: the view through four-light
    sashes, a deep timber frame and a sill, with tie-back curtains when the
    room is a parlor."""
    M.timber(cv, x - 6, y - 6, w + 12, h + 12, seed)
    cv.rect(x - 2, y - 2, w + 4, h + 4, "B0")
    for yy in range(h):
        v = yy / h
        for xx in range(w):
            cv.px(x + xx, y + yy, M.view_color(x + xx, v * 0.8 + 0.12, view, x + xx, y + yy, x + w / 2, max(w, 60)))
    gy, gx = np.mgrid[0:h, 0:w].astype(np.float32)
    band = (gx + gy * 0.7) % (w * 1.5 + 8)
    cv.tone(np.where((band > w * 0.2) & (band < w * 0.36), 0.7, 0.0), x=x, y=y)
    # sashes: a meeting rail across the middle and muntins
    cv.rect(x, y + h // 2 - 2, w, 4, "B1")
    cv.hline(x, y + h // 2 - 2, w, "B3")
    cv.hline(x, y + h // 2 + 1, w, "B0")
    nx = max(1, round(w / 30))
    for i in range(1, nx + 1):
        mx = x + round(w * i / (nx + 1))
        cv.vline(mx - 1, y, h, "B0")
        cv.vline(mx, y, h, "B2")
    cv.rect(x - 9, y + h + 4, w + 18, 6, "B2")
    cv.hline(x - 9, y + h + 4, w + 18, "B3")
    cv.hline(x - 9, y + h + 9, w + 18, "B0")
    if curtains:
        for side in (0, 1):
            cx0 = x - 10 if side == 0 else x + w - 8
            _curtain(cv, cx0, y - 8, 18, h + 14, curtains, side)
        cv.rect(x - 14, y - 10, w + 28, 4, "O0")
        cv.hline(x - 14, y - 10, w + 28, "O2")


def _curtain(cv: Canvas, x: int, y: int, w: int, h: int, ramp: list[str], side: int) -> None:
    for xx in range(w):
        fold = math.sin(xx * 0.9 + side) * 0.5 + 0.5
        for yy in range(h):
            pinch = 0.55 if h * 0.55 < yy < h * 0.62 else 1.0
            v = fold * pinch + (0.15 if side == 0 else -0.05)
            c = ramp[min(3, max(0, int(v * 3.3 + (hash2(xx, yy // 5, 2) - 0.5) * 0.3)))]
            cv.px(x + xx, y + yy, c)
    ty = y + int(h * 0.56)
    cv.rect(x, ty, w, 3, "O1")
    cv.hline(x, ty, w, "O3")
    cv.hline(x, y + h - 1, w, down(ramp[0]))


def lancet(cv: Canvas, x: int, y: int, w: int, h: int, seed: int) -> None:
    """A pointed window of leaded colored glass, as in the Chapel: blues,
    with a ruby and gold border and a darker lead tracery."""
    fr = Canvas(w + 12, h + 10)
    M.timber(fr, 0, 0, w + 12, h + 10, seed)
    mask = Canvas(w + 12, h + 10)
    _arch_shape(mask, 0, 0, w + 12, h + 10, "K0")
    fr.a[mask.a[..., 3] == 0] = 0
    cv.blit(fr, x - 6, y - 6)
    gl = Canvas(w, h)
    for yy in range(0, h, 4):
        for xx in range(0, w, 4):
            edge = xx < 4 or xx >= w - 4
            c = ("R" if (yy // 4) % 2 else "O2") if edge else ["W1", "W2", "W2", "W3", "L"][int(hash2(xx // 4, yy // 4, seed) * 5)]
            if not edge and abs(xx + 2 - w / 2) < 3 and 0.35 * h < yy < 0.55 * h:
                c = "O3"
            gl.rect(xx, yy, 4, 4, c)
            gl.px(xx + 1, yy + 1, up(c))
    for yy in range(0, h + 1, 4):
        gl.hline(0, yy, w, "K0")
    for xx in range(0, w + 1, 4):
        gl.vline(xx, 0, h, "K0")
    gl.vline(w // 2, 0, h, "B0")
    gl.hline(0, int(h * 0.45), w, "B0")
    gy, gx = np.mgrid[0:h, 0:w].astype(np.float32)
    gl.tone(0.6 * (1 - gy / h) - 0.2)
    m2 = Canvas(w, h)
    _arch_shape(m2, 0, 0, w, h, "K0")
    gl.a[m2.a[..., 3] == 0] = 0
    cv.blit(gl, x, y)
    cv.rect(x - 8, y + h + 4, w + 16, 5, "G4")
    cv.hline(x - 8, y + h + 4, w + 16, "G5")
    cv.hline(x - 8, y + h + 8, w + 16, "G2")


def _arch_shape(cv: Canvas, x: int, y: int, w: int, h: int, c) -> None:
    """A pointed arch: two arcs meeting at the top."""
    r = w * 0.85
    for yy in range(h):
        for xx in range(w):
            if yy >= w * 0.6:
                cv.px(x + xx, y + yy, c)
                continue
            dy = w * 0.6 - yy
            okl = (xx - (w - r)) ** 2 + dy ** 2 <= r * r
            okr = (xx - r) ** 2 + dy ** 2 <= r * r
            if okl and okr:
                cv.px(x + xx, y + yy, c)


def stained(cv: Canvas, x: int, y: int, w: int, h: int, seed: int) -> None:
    M.timber(cv, x - 5, y - 5, w + 10, h + 10, seed)
    M.stained(cv, x, y, w, h, seed)


# ---------------------------------------------------------------- frames

def frame(cv: Canvas, x: int, y: int, w: int, h: int, kind: str, seed: int) -> None:
    """A framed thing on the wall, by kind: an oil painting in gilt, a
    black-and-white photograph matted in a dark frame, a map, a portrait, a
    chalkboard menu, a notice, a wanted bill or a printed poster."""
    gilt = kind in ("painting", "portrait")
    if gilt:
        cv.rect(x - 6, y - 6, w + 12, h + 12, "O1")
        cv.frame(x - 6, y - 6, w + 12, h + 12, "O0")
        cv.hline(x - 5, y - 5, w + 10, "O3")
        cv.vline(x - 5, y - 5, h + 10, "O2")
        cv.hline(x - 5, y + h + 4, w + 10, "O0")
        cv.vline(x + w + 4, y - 5, h + 10, "O0")
        for k in range(x - 3, x + w + 3, 6):
            cv.px(k, y - 3, "O3")
            cv.px(k + 3, y + h + 2, "O2")
        cv.frame(x - 1, y - 1, w + 2, h + 2, "B0")
    elif kind in ("menu",):
        M.timber(cv, x - 6, y - 6, w + 12, h + 12, seed, vertical=False)
        cv.frame(x - 6, y - 6, w + 12, h + 12, "B0")
    elif kind in ("wanted", "notice", "poster"):
        pass
    else:
        cv.rect(x - 5, y - 5, w + 10, h + 10, "B1")
        cv.frame(x - 5, y - 5, w + 10, h + 10, "B0")
        cv.hline(x - 4, y - 4, w + 8, "B3")
        cv.vline(x - 4, y - 4, h + 8, "B2")
    if kind == "painting":
        _landscape(cv, x, y, w, h, seed, mono=False)
    elif kind == "photo":
        # a cream mat round a silver print
        cv.rect(x, y, w, h, "G5")
        cv.hline(x, y, w, "G4")
        m = 4 if w > 50 else 3
        _landscape(cv, x + m, y + m, w - 2 * m, h - 2 * m, seed, mono=True)
        cv.frame(x + m - 1, y + m - 1, w - 2 * m + 2, h - 2 * m + 2, "G3")
    elif kind == "portrait":
        cv.ramp_fill(x, y, w, h, ["B0", "B1", "B2"], np.clip(1 - np.mgrid[0:h, 0:w][0] / h * 0.8, 0, 1))
        cx = x + w // 2
        cv.ellipse(cx, y + h * 0.62 + h * 0.3, w * 0.34, h * 0.36, "K1")
        cv.ellipse(cx - 1, y + h * 0.62 + h * 0.3, w * 0.3, h * 0.33, "G1")
        cv.poly([(cx - 4, y + h * 0.62), (cx + 4, y + h * 0.62), (cx, y + h * 0.82)], "N")
        cv.ellipse(cx, y + h * 0.4, w * 0.18, h * 0.2, "T2")
        cv.ellipse(cx - 1, y + h * 0.38, w * 0.15, h * 0.17, "T3")
        cv.ellipse(cx, y + h * 0.26, w * 0.19, h * 0.1, "B1")
        cv.px(cx - 3, y + int(h * 0.4), "B0")
        cv.px(cx + 3, y + int(h * 0.4), "B0")
    elif kind == "map":
        _map(cv, x, y, w, h, seed)
    elif kind == "menu":
        cv.rect(x, y, w, h, "P0")
        n = Canvas(w, h)
        cv.tone(np.where(np.array([[hash2(i, j, seed) for i in range(w)] for j in range(h)]) > 0.9, 0.6, 0.0), x=x, y=y)
        cv.hline(x + w // 2 - w // 4, y + 4, w // 2, "N")
        cv.hline(x + w // 2 - w // 4 + 2, y + 5, w // 2 - 4, "G4")
        for i, ly in enumerate(range(y + 11, y + h - 4, 6)):
            ln = int((w - 14) * (0.45 + hash2(ly, 1, seed) * 0.3))
            cv.hline(x + 5, ly, ln, "G5" if i % 3 else "O3")
            for k in range(x + 5 + ln + 3, x + w - 12, 3):
                cv.px(k, ly, "G2")
            cv.hline(x + w - 10, ly, 5, "G5")
        cv.rect(x - 2, y + h + 1, w + 4, 3, "B2")
        cv.px(x + 6, y + h - 1, "N")
        cv.px(x + 8, y + h - 1, "O3")
        del n
    elif kind in ("notice", "poster", "wanted"):
        _paper(cv, x, y, w, h, kind, seed)
    # every frame casts a little shadow on the wall, down and to the right
    d = np.zeros((h + 16, w + 16), np.float32)
    d[-4:, 4:] = -0.8
    d[4:, -4:] = -0.8
    cv.tone(d, x=x - 6 + 4 if gilt else x - 5 + 4, y=y - 6 + 4 if gilt else y - 5 + 4)


def _landscape(cv: Canvas, x: int, y: int, w: int, h: int, seed: int, mono: bool) -> None:
    """A small picture of the Valley: a granite wall or dome against the sky,
    a fall, forest and meadow, in color or in silver."""
    kind = int(hash2(seed, 1, 9) * 3)
    for yy in range(h):
        v = yy / h
        for xx in range(w):
            u = xx / w
            if kind == 0:
                ridge = 0.22 + 0.5 * (u - 0.25) ** 2 if u < 0.6 else 0.36 + 0.1 * math.sin(u * 8 + seed)
            elif kind == 1:
                dome = 1 - ((u - 0.62) / 0.28) ** 2
                ridge = 0.62 - max(0.0, dome) * 0.42 if u > 0.34 or dome > 0 else 0.6
                if u < 0.4:
                    ridge = min(ridge, 0.45 + 0.1 * math.sin(u * 11))
            else:
                ridge = 0.3 + 0.12 * math.sin(u * 5 + seed * 0.3) + 0.05 * math.sin(u * 17)
            b = hash2(xx, yy, seed) * 0.8
            if v < ridge:
                c = ["W5", "W4", "W4", "A3"][min(3, int(v * 6 + b))] if not mono else ["N", "G5", "G5", "G4"][min(3, int(v * 6 + b))]
            elif v < 0.74:
                k = min(3, int((v - ridge) * 8 + (0.8 if u > 0.6 else 0) + b * 0.7))
                c = (["G5", "G4", "G3", "G3"] if not mono else ["G5", "G4", "G3", "G2"])[k]
            elif v < 0.86:
                c = ("P1" if hash2(xx // 2, yy // 2, seed + 3) > 0.4 else "P2") if not mono else ("G1" if hash2(xx // 2, yy // 2, seed + 3) > 0.4 else "G2")
            else:
                c = ("M1" if hash2(xx, yy, seed + 4) > 0.5 else "O2") if not mono else ("G3" if hash2(xx, yy, seed + 4) > 0.5 else "G2")
            cv.px(x + xx, y + yy, c)
    if hash2(seed, 2, 9) > 0.35 and w > 20:
        fx = x + int(w * (0.3 if kind != 1 else 0.2))
        top = y + int(h * 0.34)
        cv.vline(fx, top, int(h * 0.42), "N")
        cv.vline(fx + 1, top + 2, int(h * 0.4), "G5" if mono else "W4")
    if mono:
        cv.tone(np.full((h, w), 0.0, np.float32), x=x, y=y)


def _map(cv: Canvas, x: int, y: int, w: int, h: int, seed: int) -> None:
    """A park map: parchment, forest and meadow in soft greens, contour-ish
    granite, the Merced winding through, roads and a you-are-here dot."""
    cv.rect(x, y, w, h, "T3")
    n_ = Canvas(w, h)
    del n_
    for i in range(int(w * h / 260)):
        px = x + 3 + int(hash2(i, 1, seed) * (w - 6))
        py = y + 3 + int(hash2(i, 2, seed) * (h - 6))
        cv.ellipse(px, py, 3 + hash2(i, 3, seed) * 6, 2 + hash2(i, 4, seed) * 4, "M2" if i % 3 else "M1")
    for i in range(int(w * h / 600)):
        px = x + 3 + int(hash2(i, 5, seed) * (w - 6))
        py = y + 3 + int(hash2(i, 6, seed) * (h - 6))
        cv.ellipse(px, py, 4 + hash2(i, 7, seed) * 5, 3, "G4")
        cv.ellipse(px - 1, py - 1, 2, 1.5, "G5")
    for xx in range(w):
        yy = y + h // 2 + int(math.sin(xx * 0.09 + seed) * h * 0.14 + math.sin(xx * 0.031) * h * 0.1)
        cv.px(x + xx, yy, "W2")
        cv.px(x + xx, yy + 1, "W3")
    for xx in range(0, w, 2):
        yy = y + h // 2 + 6 + int(math.sin(xx * 0.05 + seed) * h * 0.12)
        cv.px(x + xx, yy, "A0")
    cv.frame(x + 2, y + 2, w - 4, h - 4, "T1")
    cv.ellipse(x + int(w * 0.55), y + int(h * 0.42), 2, 2, "R")
    cv.px(x + int(w * 0.55), y + int(h * 0.42) - 1, "N")
    # a compass rose in the corner
    cx, cy = x + w - 9, y + 9
    cv.vline(cx, cy - 5, 11, "B1")
    cv.hline(cx - 4, cy, 9, "B1")
    cv.px(cx, cy - 6, "R")


def _paper(cv: Canvas, x: int, y: int, w: int, h: int, kind: str, seed: int) -> None:
    """A sheet tacked to the wall, its corners curling."""
    base = "T3" if kind == "wanted" else ("N" if kind == "notice" else ["W3", "O2", "M2", "S"][int(hash2(seed, 3, 1) * 4)])
    cv.rect(x, y, w, h, base)
    cv.tone(np.where(np.array([[hash2(i, j, seed) for i in range(w)] for j in range(h)]) > 0.88, -0.6, 0.0), x=x, y=y)
    cv.hline(x, y, w, up(base) if up(base) != "N" else base)
    cv.vline(x + w - 1, y, h, down(base))
    cv.hline(x, y + h - 1, w, down(base))
    if kind == "wanted":
        tw = text_width("WANTED")
        if tw <= w - 2:
            text(cv, x + (w - tw) // 2, y + 3, "WANTED", "B0")
        else:
            cv.rect(x + 3, y + 3, w - 6, 5, "B1")
        cv.rect(x + w // 2 - 8, y + 13, 16, 20, "T2")
        cv.ellipse(x + w // 2, y + 21, 5, 6, "B2")
        cv.rect(x + w // 2 - 6, y + 27, 12, 6, "B1")
        cv.ellipse(x + w // 2, y + 17, 6, 2, "B0")
        for ly in range(y + 37, y + h - 3, 4):
            cv.hline(x + 4, ly, int((w - 8) * (0.6 + 0.4 * hash2(ly, 2, seed))), "T1")
        cv.hline(x + 5, y + h - 6, w - 10, "R")
    elif kind == "notice":
        cv.hline(x + 4, y + 4, w - 8, "B1")
        for ly in range(y + 9, y + h - 3, 4):
            cv.hline(x + 4, ly, int((w - 8) * (0.5 + 0.5 * hash2(ly, 2, seed))), "G3")
    else:
        cv.rect(x + 3, y + 3, w - 6, h // 2, down(base))
        cv.poly([(x + 3, y + 3 + h // 2), (x + w // 2, y + 6), (x + w - 3, y + 3 + h // 2)], "G4")
        cv.hline(x + 4, y + h - 7, w - 8, "B0")
    cv.px(x + w // 2, y + 1, "R")
    cv.px(x + w // 2, y + 2, "A0")


# ---------------------------------------------------------------- signs, clocks, flags

def sign(cv: Canvas, cx: int, y: int, s: str) -> None:
    M.wall_sign(cv, cx, y, s.upper())


def clock(cv: Canvas, x: int, y: int) -> None:
    """A schoolhouse clock: a round oak case, a cream dial with hour ticks."""
    cv.ellipse(x + 1, y + 2, 12, 12, "B0")
    cv.ellipse(x, y, 12, 12, "B1")
    cv.ellipse(x - 1, y - 1, 11, 11, "B3")
    cv.ellipse(x, y, 10, 10, "B2")
    cv.ellipse(x, y, 8.5, 8.5, "O0")
    cv.ellipse(x, y, 7.5, 7.5, "N")
    cv.ellipse(x + 1, y + 1, 6, 6, "G5")
    cv.ellipse(x, y, 5.5, 5.5, "N")
    for k in range(12):
        a = k * math.pi / 6
        cv.px(x + round(math.cos(a) * 6.5), y + round(math.sin(a) * 6.5), "B0" if k % 3 == 0 else "G3")
    cv.line(x, y, x, y - 5, "B0")
    cv.line(x, y, x + 3, y + 1, "B0")
    cv.px(x, y, "R")
    cv.px(x - 5, y - 6, "N")


def flag(cv: Canvas, x: int, y: int, left: bool = False) -> None:
    """The flag on a brass-tipped staff, hanging in soft folds (to the
    staff's left when something hangs on the wall to its right)."""
    cv.vline(x, y - 4, 64, "O1")
    cv.vline(x + 1, y - 4, 64, "O0")
    cv.ellipse(x + 0.5, y - 5, 2.5, 2.5, "O3")
    fw, fh = 38, 24
    for xx in range(fw):
        drop = int(math.sin(xx * 0.25) * 1.5 + xx * 0.06)
        fold = math.sin(xx * 0.5)
        for yy in range(fh):
            stripe = (yy * 13 // fh) % 2 == 0
            c = "R" if stripe else "N"
            if xx < 16 and yy < 13:
                c = "W1"
                if (xx % 4 == 1) and (yy % 3 == 1):
                    c = "N"
            if fold > 0.6:
                c = up(c) if c != "N" else "N"
            elif fold < -0.5:
                c = down(c)
            cv.px(x - 2 - xx if left else x + 2 + xx, y + yy + drop, c)


def cross(cv: Canvas, x: int, y: int) -> None:
    """A plain brass cross over the altar."""
    cv.rect(x - 3, y, 6, 34, "O1")
    cv.rect(x - 11, y + 8, 22, 6, "O1")
    cv.vline(x - 3, y, 34, "O3")
    cv.hline(x - 11, y + 8, 22, "O3")
    cv.vline(x + 2, y, 34, "O0")
    cv.hline(x - 11, y + 13, 22, "O0")
    cv.px(x - 2, y + 1, "N")


def antlers(cv: Canvas, x: int, y: int) -> None:
    """A rack of mule-deer antlers on a shield of timber."""
    cv.poly([(x - 8, y - 2), (x + 8, y - 2), (x + 8, y + 8), (x, y + 13), (x - 8, y + 8)], "B2")
    cv.hline(x - 8, y - 2, 17, "B3")
    cv.vline(x + 8, y - 2, 10, "B0")
    for s in (-1, 1):
        pts = [(x + s * 3, y), (x + s * 10, y - 6), (x + s * 16, y - 10), (x + s * 20, y - 18)]
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            cv.line(ax, ay, bx, by, "T3")
            cv.line(ax, ay + 1, bx, by + 1, "T1")
        cv.line(x + s * 10, y - 6, x + s * 9, y - 16, "T3")
        cv.line(x + s * 16, y - 10, x + s * 22, y - 12, "T3")
        cv.line(x + s * 20, y - 18, x + s * 24, y - 22, "G5")


# ---------------------------------------------------------------- shelves and racks

def shelf(cv: Canvas, x: int, y: int, w: int, goods: str, seed: int) -> None:
    """A wall shelf on brackets, stocked: jars, tins and boxes (goods),
    books, crockery or rocks and cones (specimens)."""
    sy = y + 18
    cv.rect(x, sy, w, 5, "B2")
    cv.hline(x, sy, w, "B3")
    cv.hline(x, sy + 4, w, "B0")
    for bx in (x + 6, x + w - 9):
        cv.poly([(bx, sy + 5), (bx + 4, sy + 5), (bx + 4, sy + 12)], "B1")
        cv.vline(bx + 3, sy + 5, 7, "B0")
    # shadow of the shelf on the wall
    d = np.zeros((4, w), np.float32)
    d[:] = -0.8
    cv.tone(d, x=x + 2, y=sy + 5)
    cols = ["R", "O2", "P3", "L", "W2", "N", "A1", "M1"]
    gx = x + 3
    i = 0
    while gx < x + w - 8:
        t = cols[int(hash2(i, 1, seed) * len(cols))]
        if goods == "books":
            bh = 11 + int(hash2(i, 2, seed) * 5)
            bw = 3 + int(hash2(i, 3, seed) * 2)
            cv.rect(gx, sy - bh, bw, bh, down(t))
            cv.vline(gx, sy - bh, bh, t)
            cv.hline(gx, sy - bh + 2, bw, "O3")
            gx += bw
            if hash2(i, 4, seed) > 0.85:
                gx += 3
        elif goods == "crockery":
            if i % 3 == 2:
                cv.ellipse(gx + 5, sy - 9, 6, 9, "N")
                cv.ellipse(gx + 5, sy - 9, 4, 7, "W4")
                cv.ellipse(gx + 5, sy - 9, 1.5, 2, "W2")
                gx += 13
            else:
                c = "N" if i % 2 else "W2"
                cv.rect(gx + 1, sy - 9, 8, 9, c)
                cv.ellipse(gx + 5, sy - 9, 4, 1.5, up(c) if c != "N" else "G5")
                cv.vline(gx + 1, sy - 8, 8, up(c) if c != "N" else "N")
                cv.vline(gx + 8, sy - 8, 8, down(c))
                cv.hline(gx + 1, sy - 5, 8, "W1" if c == "N" else "N")
                gx += 11
        elif goods == "specimens":
            c = ["G3", "G4", "T1", "B2", "G2"][i % 5]
            cv.ellipse(gx + 5, sy - 4, 5, 4, c)
            cv.ellipse(gx + 4, sy - 5, 2, 1.5, up(c))
            gx += 12
        else:
            k = i % 4
            if k == 0:
                # a glass jar with a lid
                cv.rect(gx + 1, sy - 12, 8, 12, "W4")
                cv.rect(gx + 2, sy - 9, 6, 9, t)
                cv.vline(gx + 2, sy - 9, 9, up(t) if up(t) != "N" else t)
                cv.rect(gx + 1, sy - 14, 8, 3, "O1")
                cv.hline(gx + 1, sy - 14, 8, "O3")
                cv.vline(gx + 1, sy - 11, 10, "N")
                gx += 11
            elif k == 1:
                # a tin with a label
                cv.rect(gx + 1, sy - 10, 8, 10, "G4")
                cv.rect(gx + 1, sy - 8, 8, 6, t)
                cv.vline(gx + 1, sy - 10, 10, "G5")
                cv.vline(gx + 8, sy - 10, 10, "G2")
                cv.hline(gx + 3, sy - 6, 4, "N")
                gx += 10
            elif k == 2:
                # a box of goods
                bw = 10 + int(hash2(i, 5, seed) * 4)
                cv.rect(gx, sy - 15, bw, 15, t)
                cv.vline(gx, sy - 15, 15, up(t) if up(t) != "N" else t)
                cv.vline(gx + bw - 1, sy - 15, 15, down(t))
                cv.hline(gx, sy - 15, bw, up(t) if up(t) != "N" else "G5")
                cv.rect(gx + 2, sy - 10, bw - 4, 4, "N")
                cv.hline(gx + 3, sy - 9, bw - 6, down(t))
                gx += bw + 2
            else:
                # a bottle
                cv.rect(gx + 2, sy - 12, 5, 12, "P1" if hash2(i, 6, seed) > 0.5 else "A0")
                cv.rect(gx + 3, sy - 16, 3, 4, "P1" if hash2(i, 6, seed) > 0.5 else "A0")
                cv.vline(gx + 3, sy - 11, 9, "W4")
                cv.rect(gx + 2, sy - 8, 5, 4, "N")
                gx += 9
        i += 1


def baskets(cv: Canvas, x: int, y: int, w: int, seed: int) -> None:
    """The Museum's shelf of woven baskets (Miwok and Paiute): their banded
    patterns as on the reviewed 16px shelf, now with a coiled-weave texture
    and their round forms lit from the window side."""
    sy = y + 28
    cv.rect(x, sy, w, 6, "B2")
    cv.hline(x, sy, w, "B3")
    cv.hline(x, sy + 5, w, "B0")
    d = np.zeros((5, w), np.float32)
    d[:] = -0.8
    cv.tone(d, x=x + 2, y=sy + 6)
    bx = x + 6
    i = 0
    while bx < x + w - 20:
        bw = 16 + int(hash2(i, 1, seed) * 12)
        bh = 14 + int(hash2(i, 2, seed) * 12)
        sub = Canvas(bw + 2, bh + 1)
        for yy in range(bh):
            t = yy / bh
            half = bw / 2 * (0.7 + 0.3 * math.sin(t * math.pi))
            for xx in range(-int(half), int(half) + 1):
                band = (yy // 4) % 3
                c = "T2" if band != 1 else "A0"
                if band == 1 and (xx + yy // 2) % 4 == 0:
                    c = "B0"
                if band != 1 and (xx + yy) % 2 == 0:
                    c = "T3" if yy % 4 < 2 else "T2"
                sub.px(bw // 2 + 1 + xx, yy, c)
        sub.hline(1, 0, bw, "T3")
        yy_, xx_ = np.mgrid[0:bh + 1, 0:bw + 2].astype(np.float32)
        sub.tone(-(xx_ - bw / 2 - 1) / (bw / 2) * 0.9 - 0.2 * (yy_ / bh))
        cv.blit(sub, bx, sy - bh)
        bx += bw + 6
        i += 1


def pegs(cv: Canvas, x: int, y: int, w: int, kind: str, seed: int) -> None:
    """A peg rail with what hangs from it: a smith's tongs and hammers,
    coils of rope, pots and pans, or coats and hats."""
    cv.rect(x, y, w, 6, "B2")
    cv.hline(x, y, w, "B3")
    cv.hline(x, y + 5, w, "B0")
    i = 0
    for px in range(x + 10, x + w - 8, 20):
        cv.rect(px - 1, y + 2, 3, 4, "B0")
        cv.px(px - 1, y + 2, "B3")
        if kind == "smithy":
            if i % 2 == 0:
                cv.line(px - 1, y + 6, px - 3, y + 30, "G1")
                cv.line(px + 1, y + 6, px + 3, y + 30, "G1")
                cv.line(px, y + 6, px - 2, y + 30, "G3")
                cv.rect(px - 2, y + 5, 4, 3, "G2")
            else:
                cv.rect(px - 1, y + 6, 3, 20, "B3")
                cv.vline(px - 1, y + 6, 20, "T2")
                cv.rect(px - 5, y + 25, 11, 6, "G1")
                cv.hline(px - 5, y + 25, 11, "G3")
                cv.vline(px + 5, y + 25, 6, "K0")
        elif kind == "ropes":
            c = ["R", "W2", "O2", "M1"][i % 4]
            for r in range(3):
                cv.ellipse(px, y + 18 + r, 8 - r, 11 - r, c if r % 2 == 0 else down(c))
            cv.ellipse(px, y + 18, 4, 7, "K0")
            cv.ellipse(px, y + 18, 4, 7, "B1")
            cv.vline(px - 6, y + 12, 12, up(c) if up(c) != "N" else c)
            cv.vline(px, y + 28, 8, c)
        elif kind == "kitchen":
            if i % 3 == 2:
                cv.vline(px, y + 6, 10, "G2")
                cv.rect(px - 1, y + 14, 3, 12, "G3")
                cv.ellipse(px, y + 27, 3, 3, "G3")
            else:
                cv.vline(px, y + 6, 6, "G1")
                r = 8 if i % 3 == 0 else 6
                cv.ellipse(px, y + 12 + r, r, r, "K0")
                cv.ellipse(px, y + 12 + r, r - 1, r - 1, "G1" if i % 3 == 0 else "O0")
                cv.ellipse(px - 1, y + 11 + r, r - 3, r - 3, "G2" if i % 3 == 0 else "O1")
                cv.px(px - 3, y + 9 + r, "G4" if i % 3 == 0 else "O3")
        elif kind == "coats":
            c = ["B2", "W1", "T1", "R", "P1"][int(hash2(i, 1, seed) * 5)]
            cv.poly([(px - 4, y + 6), (px + 4, y + 6), (px + 8, y + 34), (px - 8, y + 34)], c)
            cv.line(px - 4, y + 6, px - 8, y + 34, up(c) if up(c) != "N" else c)
            cv.line(px + 4, y + 6, px + 8, y + 34, down(c))
            cv.vline(px, y + 8, 26, down(c))
            for by in range(y + 12, y + 32, 6):
                cv.px(px + 1, by, "O2")
            if i % 2 == 0:
                cv.ellipse(px, y + 4, 9, 3, "B1")
                cv.ellipse(px, y + 1, 5, 4, "B1")
                cv.hline(px - 5, y, 10, "B2")
                cv.hline(px - 5, y + 3, 10, "R")
        i += 1


def po_boxes(cv: Canvas, x: int, y: int, w: int, h: int) -> None:
    """A wall of brass post-office boxes in an oak case, each a small door
    with a window and a dial."""
    M.timber(cv, x - 5, y - 5, w + 10, h + 10, 7, vertical=False)
    cv.frame(x - 5, y - 5, w + 10, h + 10, "B0")
    s = 16
    for j, by in enumerate(range(y, y + h - s + 1, s)):
        for i, bx in enumerate(range(x, x + w - s + 1, s)):
            cv.rect(bx, by, s - 1, s - 1, "O1")
            cv.hline(bx, by, s - 1, "O3")
            cv.vline(bx, by, s - 1, "O2")
            cv.hline(bx, by + s - 2, s - 1, "O0")
            cv.vline(bx + s - 2, by, s - 1, "O0")
            cv.rect(bx + 3, by + 2, s - 7, 5, "B0")
            cv.px(bx + 4, by + 3, "G3")
            cv.ellipse(bx + s // 2 - 0.5, by + 10, 1.5, 1.5, "O3")
            cv.px(bx + s // 2, by + 10, "B0")
            if hash2(i, j, 3) > 0.8:
                cv.rect(bx + 3, by + 3, s - 7, 3, "N")


def bars(cv: Canvas, x: int, w: int, y_top: int, wall_h: int) -> None:
    """Strap-iron bars across the cell, floor to ceiling, rivetted at the
    crossbands, the dark of the cell behind."""
    cv.rect(x, y_top, w, wall_h - y_top, "K0")
    cv.ramp_fill(x + 4, y_top + 4, w - 8, wall_h - y_top - 4, ["K0", "B0", "B1"], np.clip(np.mgrid[0:wall_h - y_top - 4, 0:w - 8][0] / (wall_h - y_top), 0, 0.6))
    for bx in range(x + 2, x + w - 2, 8):
        cv.rect(bx, y_top, 3, wall_h - y_top, "G1")
        cv.vline(bx, y_top, wall_h - y_top, "G3")
        cv.vline(bx + 2, y_top, wall_h - y_top, "K0")
    for by in (y_top + 8, y_top + (wall_h - y_top) // 2):
        cv.rect(x, by, w, 4, "G1")
        cv.hline(x, by, w, "G3")
        cv.hline(x, by + 3, w, "K0")
        for bx in range(x + 3, x + w - 2, 8):
            cv.px(bx, by + 1, "G4")


def notice_board(cv: Canvas, x: int, y: int, w: int, h: int, seed: int) -> None:
    """A cork board of trail notices, pinned every which way."""
    M.timber(cv, x - 5, y - 5, w + 10, h + 10, seed, vertical=False)
    cv.rect(x, y, w, h, "T1")
    n = np.array([[hash2(i, j, seed) for i in range(w)] for j in range(h)])
    cv.tone(np.where(n > 0.8, 0.6, np.where(n < 0.15, -0.6, 0.0)), x=x, y=y)
    for i in range(int(w * h / 560)):
        nw, nh = 14 + int(hash2(i, 3, seed) * 8), 12 + int(hash2(i, 4, seed) * 8)
        nx = x + 2 + int(hash2(i, 1, seed) * max(1, w - nw - 4))
        ny = y + 2 + int(hash2(i, 2, seed) * max(1, h - nh - 4))
        c = ["N", "G5", "O3", "N", "W4"][i % 5]
        cv.rect(nx + 1, ny + 1, nw, nh, "B1")
        cv.rect(nx, ny, nw, nh, c)
        for ly in range(ny + 4, ny + nh - 2, 3):
            cv.hline(nx + 2, ly, int((nw - 4) * (0.5 + 0.5 * hash2(ly, i, seed))), "G2")
        if i % 4 == 0:
            cv.rect(nx + 2, ny + 3, nw - 4, 4, "M1")
        cv.px(nx + nw // 2, ny + 1, "R")
        cv.px(nx + nw // 2, ny, "A2")


def shirt_rack(cv: Canvas, x: int, y: int, w: int) -> None:
    """A rail of park T-shirts on hangers."""
    cv.rect(x - 2, y, w + 4, 3, "G2")
    cv.hline(x - 2, y, w + 4, "G4")
    cols = ["P2", "O2", "W1", "R", "N", "M1", "B2"]
    for k, i in enumerate(range(0, w - 14, 16)):
        c = cols[k % len(cols)]
        sx = x + i + 1
        cv.line(sx + 7, y + 3, sx + 3, y + 7, "G3")
        cv.line(sx + 7, y + 3, sx + 11, y + 7, "G3")
        cv.rect(sx + 1, y + 7, 13, 6, c)
        cv.rect(sx + 3, y + 7, 9, 18, c)
        cv.vline(sx + 3, y + 7, 18, up(c) if up(c) != "N" else c)
        cv.vline(sx + 11, y + 9, 16, down(c))
        cv.hline(sx + 1, y + 12, 3, down(c))
        cv.hline(sx + 11, y + 12, 3, down(c))
        cv.ellipse(sx + 7, y + 8, 2.5, 1.5, down(c))
        if c != "N":
            cv.rect(sx + 5, y + 13, 5, 4, "N")
            cv.px(sx + 7, y + 14, c)


def sconce(cv: Canvas, x: int, y: int) -> None:
    M.sconce(cv, x, y)


# ---------------------------------------------------------------- the Mountain Shop and the Store

def bunting(cv: Canvas, x: int, y: int, w: int) -> None:
    """A string of cloth pennants swagged under the ceiling."""
    cols = ["R", "O2", "W2", "P3", "N"]
    for k, px in enumerate(range(x, x + w, 22)):
        sag = int(4 * math.sin((px - x) / 22 * math.pi / 2 % math.pi))
        cv.line(px, y + sag, px + 22, y + int(4 * math.sin(((px - x) / 22 + 1) * math.pi / 2 % math.pi)), "B1")
        c = cols[k % len(cols)]
        cv.poly([(px + 4, y + sag + 1), (px + 16, y + sag + 1), (px + 10, y + sag + 14)], c)
        cv.line(px + 4, y + sag + 1, px + 10, y + sag + 14, up(c) if up(c) != "N" else c)
        cv.px(px + 10, y + sag + 13, down(c))


def rope_wall(cv: Canvas, x: int, y: int, w: int, h: int, seed: int) -> None:
    """A slatwall of climbing ropes, each coiled on its hook: dynamic ropes
    in their bright sheaths, the coils lit along the top."""
    M.timber(cv, x - 5, y - 5, w + 10, h + 10, seed, vertical=False)
    cv.rect(x, y, w, h, "B0")
    for sy in range(y + 6, y + h, 10):
        cv.hline(x, sy, w, "B1")
    cols = ["R", "W2", "O2", "P3", "L", "A1", "W3", "S"]
    nx, ny = 4, 2
    for j in range(ny):
        for i in range(nx):
            cx = x + int(w * (i + 0.5) / nx)
            cy = y + int(h * (j + 0.5) / ny) + 2
            c = cols[(i + j * nx) % len(cols)]
            r = min(w / nx, h / ny) * 0.36
            cv.ellipse(cx + 1, cy + 2, r + 1, r * 0.8 + 1, "K0")
            for k in range(5, 0, -1):
                cv.ellipse(cx, cy, r * (0.55 + 0.09 * k), r * 0.8 * (0.55 + 0.09 * k), c if k % 2 else down(c))
            cv.ellipse(cx, cy, r * 0.45, r * 0.36, "B0")
            # strands of the coil catching the light up top, and a fleck pattern
            for a in range(0, 180, 12):
                ang = math.radians(180 + a)
                cv.px(cx + math.cos(ang) * r * 0.8, cy + math.sin(ang) * r * 0.64, up(c) if up(c) != "N" else "N")
            for a in range(0, 360, 40):
                ang = math.radians(a + seed)
                cv.px(cx + math.cos(ang) * r * 0.7, cy + math.sin(ang) * r * 0.56, "N")
            cv.rect(cx - 2, cy - int(r * 0.8) - 4, 4, 4, "G3")


def topo(cv: Canvas, x: int, y: int, w: int, h: int, seed: int) -> None:
    """A hand-drawn route topo of El Capitan pinned up behind the counter:
    the wall's outline in ink on parchment, the Nose's line of pitches
    climbing it, and the name across the top."""
    M.timber(cv, x - 5, y - 5, w + 10, h + 10, seed, vertical=False)
    cv.rect(x, y, w, h, "T3")
    cv.tone(np.where(np.array([[hash2(i, j, seed) for i in range(w)] for j in range(h)]) > 0.9, -0.6, 0.0), x=x, y=y)
    text(cv, x + 8, y + 6, "EL CAP", "B0")
    # the wall: its prow in the middle, overhangs either side
    base_y = y + h - 6
    prev = None
    for xx in range(w - 16):
        u = xx / (w - 16)
        top = 0.22 + 0.55 * abs(u - 0.52) ** 1.3 + 0.03 * math.sin(u * 23)
        ty = y + 14 + int((h - 24) * top)
        if prev is not None:
            cv.line(x + 8 + xx - 1, prev, x + 8 + xx, ty, "B1")
        prev = ty
        if xx % 3 == 0:
            cv.vline(x + 8 + xx, ty + 2, max(0, base_y - ty - 2), "T2")
    cv.hline(x + 6, base_y, w - 12, "B1")
    # the route: pitch by pitch up the prow, belays as dots
    px, py = x + w * 0.5, base_y - 2
    for k in range(12):
        nx_ = x + w * 0.5 + math.sin(k * 1.3 + seed) * w * 0.06
        ny_ = base_y - 2 - (k + 1) * (h - 30) / 12
        cv.line(px, py, nx_, ny_, "R")
        cv.px(nx_, ny_, "B0")
        cv.px(nx_ + 1, ny_, "B0")
        px, py = nx_, ny_
    for k in range(3):
        lx = x + w - 30
        cv.hline(lx, y + 8 + k * 4, 22 - k * 5, "T1")


def shoe_wall(cv: Canvas, x: int, y: int, w: int, h: int, seed: int) -> None:
    """Shelves of climbing shoes, pair by pair: downturned toes in bright
    rubber and leather, laces and straps."""
    M.timber(cv, x - 5, y - 5, w + 10, h + 10, seed, vertical=False)
    cv.rect(x, y, w, h, "B1")
    rows = 3
    cols = ["R", "O2", "W2", "P3", "A1", "L", "M1"]
    for r in range(rows):
        sy = y + int(h * (r + 1) / rows) - 3
        cv.rect(x, sy, w, 3, "B3")
        cv.hline(x, sy, w, "T2")
        cv.hline(x, sy + 2, w, "B0")
        k = 0
        for sx in range(x + 4, x + w - 16, 22):
            c = cols[int(hash2(r, k, seed) * len(cols))]
            for s in (0, 7):
                cv.poly([(sx + s, sy - 3), (sx + s + 3, sy - 9), (sx + s + 7, sy - 8), (sx + s + 8, sy - 1), (sx + s, sy - 1)], c)
                cv.hline(sx + s, sy - 1, 9, "K0")
                cv.px(sx + s + 4, sy - 7, "N")
                cv.line(sx + s + 1, sy - 4, sx + s + 6, sy - 6, up(c) if up(c) != "N" else "N")
            k += 1


def gear_rail(cv: Canvas, x: int, y: int, w: int, seed: int) -> None:
    """A pegboard band of hardware for sale: cams on slings, quickdraws,
    chalk bags and helmets."""
    cv.rect(x, y, w, 28, "B1")
    for py in range(y + 3, y + 28, 6):
        for px in range(x + 3, x + w, 6):
            cv.px(px, py, "B0")
    cv.hline(x, y, w, "B3")
    cv.hline(x, y + 27, w, "B0")
    cols = ["R", "O2", "W2", "P3", "L", "A1"]
    for k, px in enumerate(range(x + 14, x + w - 10, 40)):
        c = cols[int(hash2(k, 1, seed) * len(cols))]
        kind = k % 4
        cv.rect(px - 1, y + 2, 3, 3, "G4")
        if kind == 0:
            # a cam: sling, stem, lobes
            cv.vline(px, y + 5, 10, c)
            cv.vline(px + 1, y + 5, 10, down(c))
            cv.ellipse(px, y + 18, 5, 4, "G4")
            cv.ellipse(px, y + 18, 3, 2, "G2")
            cv.hline(px - 5, y + 18, 11, "G5")
        elif kind == 1:
            # quickdraws on a carabiner
            for q in (-4, 3):
                cv.rect(px + q, y + 5, 3, 9, c)
                cv.ellipse(px + q + 1, y + 18, 2.5, 4, "G4")
                cv.ellipse(px + q + 1, y + 18, 1, 2.5, "B1")
        elif kind == 2:
            # a chalk bag
            cv.rect(px - 5, y + 7, 11, 13, c)
            cv.ellipse(px, y + 7, 5.5, 2, "N")
            cv.vline(px - 5, y + 7, 13, up(c) if up(c) != "N" else c)
            cv.vline(px + 5, y + 7, 13, down(c))
        else:
            # a helmet
            cv.ellipse(px, y + 15, 8, 7, c)
            cv.ellipse(px - 2, y + 12, 3, 2, up(c) if up(c) != "N" else "N")
            cv.hline(px - 8, y + 19, 17, down(c))
            for v in (-3, 2):
                cv.px(px + v, y + 10, "K0")
