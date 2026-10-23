"""Materials for the park's rooms at 32px, beside the Ahwahnee's (which
ahwahnee32/materials.py paints): board-and-batten and log walls, painted lap
siding, tent canvas, fieldstone, flagstone and packed-earth floors, and the
spec's colors brought onto the Valley Days palette."""
from __future__ import annotations

import kit
import materials as M
from kit import C, Canvas, down, hash2, math, noise, np, up


# ---------------------------------------------------------------- color

def nearest(hexcol: str) -> str:
    """The palette color closest to a spec's hex color, by name."""
    r, g, b = int(hexcol[0:2], 16), int(hexcol[2:4], 16), int(hexcol[4:6], 16)
    best, bd = "G3", 1e9
    for name, (pr, pg, pb) in C.items():
        # weighted for the eye: green counts most, blue least
        d = 2 * (r - pr) ** 2 + 4 * (g - pg) ** 2 + 3 * (b - pb) ** 2
        if d < bd:
            best, bd = name, d
    return best


def ramp4(base: str) -> list[str]:
    """Four steps round a color, dark to light, for fabric and paint."""
    return [down(base), base, up(base), up(base, 2)]


# ---------------------------------------------------------------- lettering

# The Ahwahnee's sign font is missing what the park's other signs spell.
kit._FONT.update({
    "C": ["01110", "10001", "10000", "10000", "10000", "10001", "01110"],
    "F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
    "K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
    "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
    "1": ["010", "110", "010", "010", "010", "010", "111"],
    "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
    "9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
    "&": ["01100", "10010", "10100", "01000", "10101", "10010", "01101"],
    "'": ["1", "1", "0", "0", "0", "0", "0"],
    "-": ["000", "000", "000", "111", "000", "000", "000"],
    ".": ["0", "0", "0", "0", "0", "0", "1"],
})


# ---------------------------------------------------------------- walls

def boards(cv: Canvas, x0: int, y0: int, w: int, h: int, base: str, seed: int, bw: int = 20, batten: bool = True) -> None:
    """Board-and-batten: wide vertical boards, each a shade off the next,
    with long grain and the odd knot, and a narrow batten over every joint,
    lit on its left and casting a shadow to its right."""
    cv.rect(x0, y0, w, h, base)
    d = np.zeros((h, w), np.float32)
    for i, bx in enumerate(range(x0, x0 + w, bw)):
        ww = min(bw, x0 + w - bx)
        d[:, bx - x0:bx - x0 + ww] = (hash2(i, 1, seed) - 0.5) * 0.9
    cv.tone(d, x=x0, y=y0)
    for i, bx in enumerate(range(x0, x0 + w, bw)):
        ww = min(bw, x0 + w - bx)
        for g in range(int(h / 14) + 2):
            gx = bx + 3 + int(hash2(i, g, seed + 2) * max(1, ww - 6))
            gy = y0 + int(hash2(g, i, seed + 3) * h)
            gl = min(8 + int(hash2(g, i, seed + 4) * 24), y0 + h - gy)
            if gl > 0:
                cv.tone(np.full((gl, 1), -1.0 if g % 4 else 0.8, np.float32), x=gx, y=gy)
        if hash2(i, 7, seed) > 0.65:
            ky = y0 + 6 + int(hash2(i, 8, seed) * max(1, h - 12))
            kx = bx + 4 + int(hash2(i, 9, seed) * max(1, ww - 8))
            cv.ellipse(kx, ky, 1.5, 2.5, down(base, 2))
            cv.px(kx, ky - 2, down(base))
        if batten and bx > x0:
            cv.rect(bx - 2, y0, 5, h, base)
            cv.vline(bx - 2, y0, h, up(base) if up(base) != "N" else base)
            cv.vline(bx + 2, y0, h, down(base))
            cv.vline(bx + 3, y0, h, down(base))
            for ny in range(y0 + 10, y0 + h, 36):
                cv.px(bx, ny, down(base, 2))
        elif not batten:
            cv.vline(bx, y0, h, down(base, 2))
    # soft mottling so a wall of boards doesn't read as stripes
    n = noise(h, w, 18, seed + 5)
    cv.tone(np.where(n > 0.8, 0.3, np.where(n < 0.2, -0.3, 0.0)), x=x0, y=y0)


def logs(cv: Canvas, x0: int, y0: int, w: int, h: int, base: str, seed: int, lh: int = 16) -> None:
    """Peeled logs laid up horizontally: each one rounded by the light (lit
    on top, dark beneath), with bark streaks and knots, and pale chinking
    between them."""
    ramp = [down(base, 2), down(base), base, up(base), up(base, 2)]
    r = 0
    for ly in range(y0 + h, y0 - lh, -lh):
        top = ly - lh
        sub_h = lh - 3
        t = np.linspace(0, 1, sub_h)[:, None] * np.ones((1, w))
        # round: lit band a third of the way down, falling off to the underside
        shape = 0.95 - np.abs(t - 0.28) * 1.45
        jitter = (hash2(r, 1, seed) - 0.5) * 0.15
        cv.ramp_fill(x0, top + 2, w, sub_h, ramp, np.clip(shape + jitter, 0, 1))
        for g in range(int(w / 24)):
            gx = x0 + int(hash2(r, g, seed + 2) * w)
            gy = top + 4 + int(hash2(g, r, seed + 3) * (sub_h - 5))
            gl = 8 + int(hash2(g, r, seed + 4) * 26)
            cv.hline(gx, gy, min(gl, x0 + w - gx), down(base) if g % 4 else up(base))
        for k in range(int(w / 140) + 1):
            kx = x0 + int(hash2(r, k, seed + 5) * w)
            ky = top + 5 + int(hash2(k, r, seed + 6) * (sub_h - 8))
            cv.ellipse(kx, ky, 3, 2.2, down(base))
            cv.ellipse(kx, ky, 1.6, 1.2, down(base, 2))
            cv.px(kx - 1, ky - 2, up(base))
        # chinking: pale mortar packed in the gap, shaded under the log above
        cv.rect(x0, top, w, 2, "T2")
        cv.hline(x0, top, w, "T1")
        cv.hline(x0, top + 1, w, "T3")
        for cx in range(x0, x0 + w, 5):
            if hash2(cx, r, seed + 7) > 0.7:
                cv.px(cx, top + 1, "T2")
        cv.hline(x0, top + lh - 1, w, down(base, 2))
        r += 1


def lap(cv: Canvas, x0: int, y0: int, w: int, h: int, base: str, seed: int, course: int = 10) -> None:
    """Painted lap siding: narrow boards each overlapping the one below, a
    lit top edge and a crisp shadow line under every lap, the paint a touch
    worn here and there."""
    cv.rect(x0, y0, w, h, base)
    for i, ry in enumerate(range(y0, y0 + h, course)):
        cv.hline(x0, ry, w, up(base) if up(base) != "N" or base == "N" else base)
        cv.hline(x0, ry + course - 2, w, down(base))
        cv.hline(x0, ry + course - 1, w, down(base, 2))
        # butt joints, staggered
        jx = x0 + int(hash2(i, 1, seed) * 180)
        while jx < x0 + w:
            cv.vline(jx, ry, course - 1, down(base))
            jx += 180 + int(hash2(i, jx, seed) * 120)
    n = noise(h, w, 22, seed + 1)
    cv.tone(np.where(n < 0.2, -0.35, 0.0) + np.where(n > 0.85, 0.3, 0.0), x=x0, y=y0)


def plaster(cv: Canvas, x0: int, y0: int, w: int, h: int, base: str, seed: int, rough: bool = False, warm: float = 0.0) -> None:
    """Troweled plaster (rough, the stucco's coarser float finish). warm
    dithers a share of tan into a pale base: the palette's cream."""
    cv.rect(x0, y0, w, h, base)
    if warm > 0:
        cv.dither(x0, y0, w, h, base, "T3", warm)
    n = noise(h, w, 20, seed) * 0.7 + noise(h, w, 5, seed + 1) * 0.3
    d = np.where(n < 0.25, -0.35, 0.0) + np.where(n > 0.8, 0.3, 0.0)
    if rough:
        n2 = noise(h, w, 2, seed + 2)
        d += np.where(n2 > 0.86, -0.6, 0.0) + np.where(n2 < 0.1, 0.45, 0.0)
    cv.tone(d, x=x0, y=y0)


def canvas_wall(cv: Canvas, x0: int, y0: int, w: int, h: int, base: str, seed: int) -> None:
    """Tent canvas stretched on a timber frame, as at Tuolumne's lodge: panels
    sewn at the seams, the cloth sagging soft between the poles."""
    cv.rect(x0, y0, w, h, base)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    panel = 64
    u = (xx % panel) / panel
    # the cloth bellies between seams: brightest on the left of each panel,
    # in shade toward the next seam, more so lower down where it hangs slack
    sag = 0.35 - 1.0 * u * (0.5 + 0.5 * (yy / max(1, h)))
    # a few long vertical creases
    crease = np.sin(xx * 0.33 + 1.3 * np.sin(xx * 0.05)) * np.sin((xx // panel) * 1.7 + 1)
    cv.tone(sag + np.where(crease > 0.85, -0.6, 0.0) - 0.3, x=x0, y=y0)
    for sx in range(x0 + panel, x0 + w, panel):
        cv.vline(sx, y0, h, down(base, 2))
        cv.vline(sx + 1, y0, h, up(base) if up(base) != "N" else "N")
        for sy in range(y0 + 3, y0 + h, 6):
            cv.px(sx - 2, sy, down(base))
            cv.px(sx + 3, sy + 3, down(base))
    for px in range(x0 + 16, x0 + w, 192):
        M.timber(cv, px, y0, 7, h, seed + px)


def fieldstone(cv: Canvas, x0: int, y0: int, w: int, h: int, seed: int, light: float = 0.0, cell: int = 22, mortar: str = "G2") -> None:
    """Rounded river and field stones set in mortar, each lit on its upper
    left like a cobble, in granite greys with a warm one now and then."""
    out, ox, oy = cv, x0, y0
    cv, x0, y0 = Canvas(w, h), 0, 0
    cv.rect(x0, y0, w, h, mortar)
    n = noise(h, w, 4, seed)
    cv.tone(np.where(n > 0.7, 0.4, 0.0), x=x0, y=y0)
    for j, sy in enumerate(range(y0 - cell // 2, y0 + h + cell, int(cell * 0.8))):
        for i, sx in enumerate(range(x0 - cell // 2 + (j % 2) * cell // 2, x0 + w + cell, cell)):
            jx = sx + (hash2(i, j, seed) - 0.5) * cell * 0.4
            jy = sy + (hash2(j, i, seed + 1) - 0.5) * cell * 0.3
            rx = cell * (0.38 + 0.14 * hash2(i, j, seed + 2))
            ry = cell * (0.30 + 0.1 * hash2(i, j, seed + 3))
            t = ["G3", "G3", "G4", "G2", "G3", "T1", "G4", "G3", "G4", "G3"][int(hash2(i, j, seed + 4) * 10)]
            _stone(cv, jx, jy, rx, ry, t, seed + i * 7 + j)
    if light:
        cv.tone(np.full((h, w), light, np.float32), x=x0, y=y0)
    out.blit(cv, ox, oy)


def _stone(cv: Canvas, cx: float, cy: float, rx: float, ry: float, t: str, sd: int) -> None:
    x0, y0 = int(cx - rx - 1), int(cy - ry - 1)
    ww, hh = int(rx * 2 + 3), int(ry * 2 + 3)
    yy, xx = np.mgrid[0:hh, 0:ww].astype(np.float32)
    dx = (xx + x0 + 0.5 - cx) / rx
    dy = (yy + y0 + 0.5 - cy) / ry
    d2 = dx * dx + dy * dy
    m = d2 <= 1.0
    sub = cv.a[max(0, y0):y0 + hh, max(0, x0):x0 + ww]
    if sub.size == 0:
        return
    m = m[max(0, -y0):max(0, -y0) + sub.shape[0], max(0, -x0):max(0, -x0) + sub.shape[1]]
    sub[..., :3][m] = C[t]
    sub[..., 3][m] = 255
    # light from the upper left: up on that rim, down on the other
    shade = (-dx - dy) * 0.9 * np.sqrt(np.clip(d2, 0, 1))
    shade += np.where(d2 > 0.75, np.where(dx + dy > 0, -0.8, 0.5), 0.0)
    fl = np.array([[hash2(int(x0 + i), int(y0 + j), sd) for i in range(ww)] for j in range(hh)])
    shade += np.where(fl > 0.93, -0.9, 0.0) + np.where(fl < 0.04, 0.8, 0.0)
    cv.tone(np.where(d2 <= 1.0, shade, 0.0).astype(np.float32), mask=(d2 <= 1.0), x=x0, y=y0)


def stucco(cv: Canvas, x0: int, y0: int, w: int, h: int, base: str, seed: int, warm: float = 0.0) -> None:
    plaster(cv, x0, y0, w, h, base, seed, rough=True, warm=warm)


def warmth(hexcol: str) -> float:
    """How much tan a pale wall color wants dithered in to read as cream."""
    r, b = int(hexcol[0:2], 16), int(hexcol[4:6], 16)
    return float(np.clip((r - b - 25) / 60.0, 0.0, 0.5))


# ---------------------------------------------------------------- floors

def flagstones(cv: Canvas, x0: int, y0: int, w: int, h: int, base: str, seed: int, cell: int = 38) -> None:
    """Irregular flagstones laid in mortar: each slab its own tone, worn
    smooth, its upper-left edge catching the light."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    gx, gy = (xx // cell).astype(int), (yy // cell).astype(int)
    best = np.full((h, w), 1e9, np.float32)
    second = np.full((h, w), 1e9, np.float32)
    owner = np.zeros((h, w), np.int32)
    for oy in (-1, 0, 1):
        for ox in (-1, 0, 1):
            cx_, cy_ = gx + ox, gy + oy
            hx = np.vectorize(lambda a, b: hash2(int(a), int(b), seed))(cx_, cy_)
            hy = np.vectorize(lambda a, b: hash2(int(b), int(a), seed + 1))(cx_, cy_)
            px = (cx_ + 0.15 + 0.7 * hx) * cell
            py = (cy_ + 0.15 + 0.7 * hy) * cell
            d = np.sqrt((xx - px) ** 2 + ((yy - py) * 1.15) ** 2)
            closer = d < best
            second = np.where(closer, best, np.minimum(second, d))
            owner = np.where(closer, (cx_ * 7919 + cy_ * 104729) & 0xFFFF, owner)
            best = np.where(closer, d, best)
    edge = second - best
    x0c, y0c, x1c, y1c = cv._clip(x0, y0, w, h)
    cv.rect(x0, y0, w, h, base)
    # each slab a little lighter or darker than the next, never a full step
    off = (np.vectorize(lambda o: hash2(int(o), 3, seed))(owner) - 0.5) * 0.8
    n = noise(h, w, 6, seed + 2)
    d = off + np.where(n > 0.8, 0.3, np.where(n < 0.18, -0.3, 0.0))
    # lit just inside the joint on the lower-right of a joint (upper-left of a slab)
    gxd = np.zeros_like(edge)
    gxd[:, 1:] = edge[:, 1:] - edge[:, :-1]
    gyd = np.zeros_like(edge)
    gyd[1:, :] = edge[1:, :] - edge[:-1, :]
    d += np.where((edge < 4) & (gxd + gyd > 0), 0.7, 0.0)
    d += np.where((edge < 4) & (gxd + gyd < 0), -0.6, 0.0)
    cv.tone(d.astype(np.float32), x=x0, y=y0)
    joint = edge < 2.0
    sub = cv.a[y0c:y1c, x0c:x1c]
    j = joint[y0c - y0:y1c - y0, x0c - x0:x1c - x0]
    sub[..., :3][j] = C[down(base, 2)]


def earth(cv: Canvas, x0: int, y0: int, w: int, h: int, base: str, seed: int) -> None:
    """Packed earth: trodden smooth, mottled, with grit, pebbles and a few
    bits of straw and iron scale near the forge."""
    cv.rect(x0, y0, w, h, base)
    n = noise(h, w, 16, seed) * 0.6 + noise(h, w, 4, seed + 1) * 0.4
    cv.tone(np.where(n > 0.7, 0.5, np.where(n < 0.3, -0.5, 0.0)), x=x0, y=y0)
    for i in range(int(w * h / 90)):
        px = x0 + int(hash2(i, 1, seed) * w)
        py = y0 + int(hash2(i, 2, seed) * h)
        k = hash2(i, 3, seed)
        if k > 0.93:
            cv.rect(px, py, 2, 2, "G3")
            cv.px(px, py, "G4")
            cv.px(px + 1, py + 1, "G1")
        elif k > 0.91:
            cv.line(px, py, px + 3, py + (1 if k > 0.92 else -1), "T2")
        else:
            cv.px(px, py, down(base) if k > 0.4 else up(base))


def planks(cv: Canvas, x0: int, y0: int, w: int, h: int, base: str, seed: int) -> None:
    """Floorboards in the spec's tone: the Ahwahnee's polished boards, with
    tones round the room's own color."""
    tones = (base, base, down(base), base, base) if base not in ("T2", "T3") else (base, down(base), base, base)
    M.planks(cv, x0, y0, w, h, seed, tones=tones)


# ---------------------------------------------------------------- trim

def wainscot(cv: Canvas, x0: int, y0: int, w: int, h: int, base: str, seed: int) -> None:
    """Raised panels along the foot of the wall in the spec's color: stained
    timber, or painted (the cottages' green, the Washburn red)."""
    cv.rect(x0, y0, w, h, base)
    cv.hline(x0, y0, w, up(base, 2))
    cv.hline(x0, y0 + 1, w, up(base))
    cv.hline(x0, y0 + 3, w, down(base))
    pw = 44
    for px in range(x0 + 6, x0 + w - pw // 2, pw + 8):
        ww = min(pw, x0 + w - 6 - px)
        ph = h - 12
        cv.rect(px, y0 + 7, ww, ph, base)
        cv.hline(px, y0 + 7, ww, down(base, 2))
        cv.vline(px, y0 + 7, ph, down(base, 2))
        cv.hline(px + 1, y0 + 6 + ph, ww - 1, up(base))
        cv.vline(px + ww - 1, y0 + 8, ph - 1, up(base))
        cv.rect(px + 4, y0 + 11, ww - 8, ph - 8, down(base))
        cv.hline(px + 4, y0 + 11, ww - 8, up(base))
        for g in range(2):
            gy = y0 + 13 + int(hash2(px, g, seed) * max(1, ph - 12))
            cv.hline(px + 6, gy, ww - 14, base)
    cv.hline(x0, y0 + h - 1, w, down(base, 2))


def skirting(cv: Canvas, x0: int, y: int, w: int, base: str, h: int = 8) -> None:
    """A baseboard: a lit top bead, the board, and a dark shadow at the floor."""
    cv.rect(x0, y - h, w, h, base)
    cv.hline(x0, y - h, w, up(base, 2) if up(base, 2) != "N" else up(base))
    cv.hline(x0, y - h + 1, w, up(base))
    cv.hline(x0, y - 2, w, down(base))
    cv.hline(x0, y - 1, w, "K0")


def cornice(cv: Canvas, w: int, base: str, h: int = 12) -> None:
    """The crown along the top of a wall with no beams: a stepped moulding
    and the shade of the ceiling under it."""
    cv.rect(0, 0, w, h, down(base))
    cv.hline(0, h - 4, w, up(base))
    cv.hline(0, h - 3, w, base)
    cv.hline(0, h - 1, w, down(base, 2))
    cv.hline(0, 3, w, base)
    d = np.zeros((10, w), np.float32)
    for i in range(10):
        d[i] = -1.0 * (1 - i / 10)
    cv.tone(d, x=0, y=h)


def checker(cv: Canvas, x0: int, y0: int, w: int, h: int, a: str, b: str, seed: int, size: int = 32, dots=None) -> None:
    """A store's tile floor in two tones: each tile flat and a little worn,
    a fine grout line, a soft sheen along the upper-left of each, and the
    odd scuff. Quieter than the Ahwahnee's polished stone."""
    for ty in range(0, h, size):
        for tx in range(0, w, size):
            t = a if ((tx // size + ty // size) % 2 == 0) else b
            x, y = x0 + tx, y0 + ty
            cv.rect(x, y, size, size, t)
            cv.hline(x + 1, y + 1, size - 2, up(t) if up(t) != "N" or t == "N" else t)
            cv.vline(x + 1, y + 1, size - 2, up(t) if up(t) != "N" or t == "N" else t)
            cv.hline(x + 1, y + size - 1, size - 1, down(t))
            cv.vline(x + size - 1, y + 1, size - 1, down(t))
            cv.hline(x, y, size, down(a, 2) if a != "N" else "G3")
            cv.vline(x, y, size, down(a, 2) if a != "N" else "G3")
    n = noise(h, w, 14, seed)
    n2 = noise(h, w, 3, seed + 1)
    cv.tone(np.where(n < 0.18, -0.45, 0.0) + np.where(n > 0.86, 0.3, 0.0) + np.where(n2 > 0.9, -0.5, 0.0), x=x0, y=y0)
    if dots:
        for ty in range(0, h + 1, size):
            for tx in range(0, w + 1, size):
                cx, cy = x0 + tx, y0 + ty
                cv.rect(cx - 2, cy - 2, 5, 5, dots[0])
                cv.px(cx - 1, cy - 1, dots[1])
