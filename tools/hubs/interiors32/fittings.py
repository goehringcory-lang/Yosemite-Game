"""Furniture and fittings for the park's interiors, painted natively at 32px:
the shop and museum pieces (fireplaces, stoves and the forge with their
fires in two frames, barrels, crates, coolers, store shelves, racks, easels,
relief models, exhibit panels, the Museum's baskets) and the Camp Curry
Store and Mountain Shop's furniture.

Each piece is drawn into the canvas size the builder gave it (frames side by
side for the fires), seen in 3/4 from the front and lit from the upper left,
in the Valley Days palette, with a dark rim round it. On its own:

    python3 tools/hubs/interiors32/fittings.py      # paints every piece in place
"""
from __future__ import annotations

import importlib.util
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "ahwahnee32"))
sys.path.insert(0, HERE)

import materials as M  # noqa: E402
from kit import ROOT, Canvas, down, hash2, math, np, radial, text, up  # noqa: E402

_spec = importlib.util.spec_from_file_location("ahw_props", os.path.join(HERE, "..", "ahwahnee32", "props.py"))
AP = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(AP)
rrect, finish, _legs = AP.rrect, AP.finish, AP._legs

IRON = ["K0", "G0", "G1", "G2", "G3"]


# ---------------------------------------------------------------- helpers

# Glyphs the kit's font lacks, 5x7 like it.
_GLYPH = {
    "C": ["01110", "10001", "10000", "10000", "10000", "10001", "01110"],
    "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
    "F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
    "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
    "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
    ".": ["0", "0", "0", "0", "0", "0", "1"],
}


def say(cv: Canvas, x: int, y: int, s: str, c, shadow=None) -> None:
    """Lettering in the kit's 5x7 font, with the few glyphs it lacks."""
    import kit
    for ch in s:
        g = _GLYPH.get(ch) or kit._FONT[ch]
        for gy, row in enumerate(g):
            for gx, bit in enumerate(row):
                if bit == "1":
                    if shadow:
                        cv.px(x + gx + 1, y + gy + 1, shadow)
                    cv.px(x + gx, y + gy, c)
        x += len(g[0]) + 1


def say_width(s: str) -> int:
    import kit
    return sum(len((_GLYPH.get(ch) or kit._FONT[ch])[0]) + 1 for ch in s) - 1


def cylinder(cv: Canvas, x: int, y: int, w: int, h: int, s: float = 1.0) -> None:
    """Shades a round body across its width: lit a third of the way in from
    the left, falling off into the right side."""
    xx = np.arange(w, dtype=np.float32) / max(1, w - 1)
    d = np.where(xx < 0.32, 0.9 * (1 - np.abs(xx - 0.22) / 0.22).clip(0, 1), -1.2 * np.clip((xx - 0.32) / 0.68, 0, None) ** 1.4)
    cv.tone(np.tile(d * s, (h, 1)).astype(np.float32), x=x, y=y)


def grain(cv: Canvas, x: int, y: int, w: int, h: int, base: str, seed: int, vertical: bool = False) -> None:
    """Fills with wood: base color, sparse long streaks of grain a step
    darker, the odd one a step lighter."""
    cv.rect(x, y, w, h, base)
    if vertical:
        for gx in range(x + 1, x + w - 1, 3):
            for k in range(int(h / 16) + 1):
                gy = y + int(hash2(gx, k, seed) * h)
                ln = 4 + int(hash2(k, gx, seed + 1) * 10)
                cv.vline(gx, gy, min(ln, y + h - gy), down(base) if (gx + k) % 4 else up(base))
    else:
        for gy in range(y + 1, y + h - 1, 3):
            for k in range(int(w / 26) + 1):
                gx = x + int(hash2(k, gy, seed) * w)
                ln = 6 + int(hash2(gy, k, seed + 1) * 14)
                cv.hline(gx, gy, min(ln, x + w - gx), down(base) if (gy + k) % 4 else up(base))


def board(cv: Canvas, x: int, y: int, w: int, h: int, base: str, seed: int) -> None:
    """A lit-edged slab of wood seen from the front (a table top, a shelf)."""
    grain(cv, x, y, w, h, base, seed)
    cv.hline(x, y, w, up(base))
    cv.hline(x, y + h - 1, w, down(base, 2))


def panel_front(cv: Canvas, x: int, y: int, w: int, h: int, base: str, n: int, seed: int) -> None:
    """A cabinet front of raised panels: stiles and rails, each sunk field
    bevelled (lit top and left, shaded bottom and right) with a little
    vertical grain."""
    grain(cv, x, y, w, h, base, seed)
    pw = (w - 4) / n
    for i in range(n):
        px = int(x + 3 + i * pw)
        ww = int(pw) - 4
        fy, fh = y + 4, h - 8
        cv.rect(px, fy, ww, fh, base)
        for k in range(3):
            gx = px + 3 + int(hash2(i, k, seed) * max(1, ww - 6))
            gy = fy + 2 + int(hash2(k, i, seed + 1) * 4)
            cv.vline(gx, gy, fh - 6, down(base) if k else up(base))
        cv.hline(px, fy, ww, down(base, 2))
        cv.vline(px, fy, fh, down(base, 2))
        cv.hline(px + 1, fy + 1, ww - 1, down(base))
        cv.hline(px + 1, fy + fh - 1, ww - 1, up(base))
        cv.vline(px + ww - 1, fy + 1, fh - 1, up(base))
    cv.hline(x, y, w, down(base, 2))
    cv.hline(x, y + h - 1, w, down(base, 2))


def fire(cv: Canvas, x0: int, x1: int, base_y: int, max_h: int, f: int, high: bool = True) -> None:
    """Flames over a bed of embers between x0 and x1, their tips flickering
    differently in each frame f."""
    span = max(1, x1 - x0)
    for xx in range(x0, x1):
        u = (xx - x0) / span
        body = math.sin(u * math.pi)
        flick = 0.62 + 0.38 * math.sin(xx * 0.9 + f * 2.3) * math.sin(xx * 0.37 + f * 1.3)
        ht = int((0.35 + 0.65 * body) * max_h * flick * (1.0 if high else 0.55))
        for k in range(ht):
            t = k / max(1, ht)
            c = "N" if t < 0.18 and body > 0.6 and high else ("A3" if t < 0.35 else ("O3" if t < 0.5 else ("A2" if t < 0.72 else ("A1" if t < 0.9 else "A0"))))
            if t > 0.8 and (xx + k + f) % 3 == 0:
                continue
            cv.px(xx, base_y - k, c)
    for s in range(4 if high else 2):
        ex = x0 + int(hash2(s, f, 19) * span)
        ey = base_y - max_h - 2 - int(hash2(s, f + 3, 19) * 6)
        cv.px(ex, ey, "A3" if s % 2 else "O3")
    for ex in range(x0, x1, 2):
        cv.px(ex, base_y + 1, "A1" if (ex // 2 + f) % 2 else "A2")
        if (ex // 2) % 3 == 0:
            cv.px(ex + 1, base_y + 1, "A0")


def glow(cv: Canvas, cx: float, cy: float, rx: float, ry: float, s: float, mask=None) -> None:
    """Warm light thrown round a fire or a lamp, stepped up the ramps."""
    cv.tone(s * radial(cv.h, cv.w, cx, cy, rx, ry), mask=mask)


def barrel(cv: Canvas, x: int, y: int, w: int, h: int, wood: str, seed: int, lid: bool = True) -> None:
    """A cask: bellied staves, two iron hoops, its head an ellipse on top."""
    ry = max(3, w // 6)
    body = Canvas(w, h)
    for yy in range(ry, h):
        t = (yy - ry) / max(1, h - ry - 1)
        bulge = 1.0 + 0.08 * math.sin(t * math.pi)
        half = (w / 2 - 1) * bulge / 1.08
        body.hline(int(w / 2 - half), yy, int(half * 2) + 1, wood)
    for sx in range(3, w - 1, 5):
        for yy in range(ry, h):
            if body.a[yy, sx, 3]:
                body.px(sx, yy, down(wood))
            if sx + 1 < w and body.a[yy, sx + 1, 3] and yy % 7 != 3:
                body.px(sx + 1, yy, up(wood) if sx < w * 0.45 else wood)
    for k in range(int(w * h / 60)):
        gx = int(hash2(k, 1, seed) * w)
        gy = ry + int(hash2(k, 2, seed) * (h - ry))
        if body.a[gy, gx, 3]:
            body.px(gx, gy, down(wood) if k % 3 else up(wood))
    for hy in (ry + 3, h - 7):
        for yy in (hy, hy + 1, hy + 2):
            row = body.a[yy, :, 3] > 0
            xs = np.nonzero(row)[0]
            if len(xs):
                body.hline(xs[0], yy, xs[-1] - xs[0] + 1, "G0" if yy == hy + 2 else ("G3" if yy == hy else "G1"))
        cv_nail = [int(w * 0.22), int(w * 0.5), int(w * 0.78)]
        for nx in cv_nail:
            body.px(nx, hy + 1, "G3")
    cylinder(body, 0, 0, w, h, 1.0)
    # the head
    body.ellipse(w / 2, ry, w / 2 - 1, ry, "G1")
    body.ellipse(w / 2, ry, w / 2 - 2.5, ry - 1.2, up(wood) if lid else "B0")
    if lid:
        for k in range(-int(w / 2) + 4, int(w / 2) - 3, 4):
            body.vline(int(w / 2 + k), ry - int(ry * 0.7), int(ry * 1.4), wood)
        body.hline(int(w * 0.3), ry - 1, int(w * 0.25), "T3")
    cv.blit(body, x, y)


def crate(cv: Canvas, x: int, y: int, w: int, h: int, wood: str, seed: int, top: int = 6, label: str | None = None) -> None:
    """A slatted wooden crate: its lid seen from above, its front of boards
    with corner posts and nail heads."""
    cv.rect(x, y, w, top, up(wood))
    for sx in range(x + 1, x + w - 1, 7):
        cv.vline(sx + 6, y, top, wood)
    cv.hline(x, y, w, "T3" if wood != "T3" else "N")
    fy = y + top
    fh = h - top
    for k, by in enumerate(range(fy, fy + fh, 5)):
        bh = min(5, fy + fh - by)
        t = wood if k % 2 == 0 else down(wood)
        grain(cv, x, by, w, bh, t, seed + k)
        cv.hline(x, by, w, down(wood, 2))
    for px in (x, x + w - 4):
        cv.rect(px, fy, 4, fh, wood)
        cv.vline(px, fy, fh, up(wood))
        cv.vline(px + 3, fy, fh, down(wood, 2))
        cv.px(px + 1, fy + 2, "G2")
        cv.px(px + 1, fy + fh - 3, "G2")
    if label:
        lw = 12
        lx = x + w // 2 - lw // 2
        cv.rect(lx, fy + fh // 2 - 3, lw, 6, "T3")
        cv.hline(lx + 2, fy + fh // 2 - 1, lw - 4, label)
        cv.hline(lx + 2, fy + fh // 2 + 1, lw - 6, label)


def jar(cv: Canvas, x: int, y: int, c: str, h: int = 12, w: int = 8) -> None:
    """A glass jar of something: its contents, a lit side and a lid."""
    cv.rect(x, y + 2, w, h - 2, c)
    cv.rect(x, y, w, 3, "G4")
    cv.hline(x, y, w, "G5")
    cv.vline(x + 1, y + 3, h - 5, up(c))
    cv.vline(x + w - 1, y + 3, h - 3, down(c))
    cv.rect(x + 2, y + 5, w - 4, 3, "N")
    cv.hline(x + 2, y + 6, w - 4, down(c))


def can(cv: Canvas, x: int, y: int, c: str, h: int = 10, w: int = 7) -> None:
    cv.rect(x, y, w, h, c)
    cv.hline(x, y, w, "G4")
    cv.hline(x, y + h - 1, w, "G2")
    cv.vline(x + 1, y + 1, h - 2, up(c))
    cv.vline(x + w - 1, y + 1, h - 2, down(c))
    cv.rect(x + 1, y + 3, w - 2, 4, "N")
    cv.hline(x + 2, y + 4, w - 4, c)


def box(cv: Canvas, x: int, y: int, w: int, h: int, c: str) -> None:
    cv.rect(x, y, w, h, c)
    cv.hline(x, y, w, up(c))
    cv.vline(x, y, h, up(c))
    cv.vline(x + w - 1, y + 1, h - 1, down(c))
    cv.hline(x + 1, y + 3, w - 2, "N")
    cv.px(x + w // 2, y + h - 3, down(c))


def view(cv: Canvas, x: int, y: int, w: int, h: int, seed: int, kind: str = "valley", mono: bool = False) -> None:
    """A little picture of the park: sky, a granite wall with a fall, pines
    and meadow (a cliff, falls or sunset), or the same in black and white."""
    for yy in range(h):
        v = yy / max(1, h - 1)
        for xx in range(w):
            u = xx / max(1, w - 1)
            b = M.BAYER[(y + yy) & 3, (x + xx) & 3]
            if kind == "sunset":
                ridge = 0.42 + 0.22 * (u - 0.35) ** 2 * 4 - 0.12 * max(0, 1 - abs(u - 0.7) * 5)
            elif kind == "falls":
                ridge = 0.22 + 0.1 * math.sin(u * 5 + seed)
            else:
                ridge = (0.3 + 0.55 * (u - 0.32) ** 2) if u < 0.62 else 0.36 + 0.08 * math.sin(u * 13 + seed)
            if v < ridge:
                if kind == "sunset":
                    c = ["A1", "A2", "A3", "T3"][min(3, int(v / ridge * 4 + b * 0.8))]
                else:
                    c = ["W5", "W4", "W4", "W3"][min(3, int(v * 6 + b * 0.8))]
            elif v < 0.74:
                d = (v - ridge) / max(0.05, 0.74 - ridge)
                lit = u < 0.5
                if kind == "sunset":
                    c = ["A2", "T2", "T1", "B2"][min(3, int(d * 3 + b * 0.8))]
                else:
                    c = (["G5", "G4", "G4", "G3"] if lit else ["G4", "G3", "G3", "G2"])[min(3, int(d * 3 + b * 0.8))]
            elif v < 0.86:
                c = "P1" if hash2(xx // 2, yy, seed) > 0.45 else "P2"
                if kind == "sunset":
                    c = "P0" if c == "P1" else "P1"
            else:
                c = "M1" if hash2(xx, yy, seed + 1) > 0.5 else ("O2" if kind != "sunset" else "M0")
            cv.px(x + xx, y + yy, c)
    if kind in ("valley", "falls"):
        fx = x + int(w * (0.68 if kind == "valley" else 0.45))
        top = y + int(h * (0.38 if kind == "valley" else 0.24))
        cv.vline(fx, top, int(h * 0.36), "N")
        cv.vline(fx + 1, top + 2, int(h * 0.3), "W5")
        cv.ellipse(fx, y + int(h * 0.74), 3, 1.5, "N")
    if mono:
        lum = {"K0": 0, "K1": 0, "B0": 0, "P0": 0, "P1": 1, "W0": 1, "B1": 1, "G0": 1, "P2": 2, "G1": 2, "B2": 2, "A0": 2,
               "P3": 2, "M0": 3, "G2": 3, "B3": 3, "T0": 2, "T1": 3, "W1": 2, "W2": 3, "O0": 3, "M1": 3, "A1": 3,
               "G3": 3, "O1": 3, "T2": 4, "W3": 4, "M2": 4, "O2": 4, "A2": 4, "G4": 4, "W4": 5, "T3": 4, "M3": 5,
               "O3": 5, "A3": 5, "G5": 5, "W5": 5, "N": 5, "L": 2, "S": 4, "R": 2}
        import kit
        inv = {kit.C[k]: k for k in lum}
        ramp = ["K0", "G0", "G1", "G2", "G3", "G4", "G5", "N"]
        for yy in range(h):
            for xx in range(w):
                px = tuple(int(v) for v in cv.a[y + yy, x + xx, :3])
                name = inv.get(px)
                if name is not None:
                    cv.a[y + yy, x + xx, :3] = kit.C[ramp[min(7, lum[name] + 1)]]


def picture_frame(cv: Canvas, x: int, y: int, w: int, h: int, gilt: bool) -> None:
    """A moulded frame round x, y, w, h, gilt or dark."""
    r = ["O0", "O1", "O2", "O3"] if gilt else ["K0", "B0", "B1", "B2"]
    cv.rect(x - 3, y - 3, w + 6, h + 6, r[1])
    cv.hline(x - 3, y - 3, w + 6, r[3])
    cv.vline(x - 3, y - 3, h + 6, r[2])
    cv.hline(x - 2, y + h + 2, w + 4, r[0])
    cv.vline(x + w + 2, y - 2, h + 4, r[0])
    cv.frame(x - 1, y - 1, w + 2, h + 2, r[0])


# ---------------------------------------------------------------- the forge and the smithy

def anvil(w: int, h: int) -> Canvas:
    """A blacksmith's anvil on a stump: the horn to the left, a hardy hole in
    the face, a hammer laid across the heel."""
    cv = Canvas(w, h)
    # the stump, end grain on top
    sx0, sx1 = 14, w - 14
    cv.rect(sx0, 22, sx1 - sx0, h - 24, "B2")
    grain(cv, sx0, 22, sx1 - sx0, h - 24, "B2", 3, vertical=True)
    for k in range(0, h - 24, 6):
        cv.px(sx0 + 2 + (k * 7) % (sx1 - sx0 - 4), 24 + k, "B0")
    cylinder(cv, sx0, 22, sx1 - sx0, h - 24, 0.9)
    cv.hline(sx0, h - 3, sx1 - sx0, "B0")
    # the iron: waist, then the face and horn
    cv.rect(17, 16, w - 34, 8, "G0")
    cv.vline(17, 16, 8, "G1")
    cv.poly([(2, 10), (12, 7), (12, 15), (4, 13)], "G1")
    cv.hline(3, 10, 9, "G3")
    cv.rect(10, 6, w - 16, 10, "G1")
    cv.rect(10, 6, w - 16, 3, "G3")
    cv.hline(10, 6, w - 16, "G4")
    cv.hline(12, 7, w - 22, "G5")
    cv.hline(10, 15, w - 16, "K0")
    cv.rect(w - 12, 8, 4, 3, "K0")
    cv.px(w - 14, 8, "K0")
    # the hammer
    cv.line(18, 4, 34, 2, "B3")
    cv.line(18, 5, 34, 3, "B1")
    cv.rect(14, 1, 5, 6, "G1")
    cv.hline(14, 1, 5, "G3")
    return finish(cv, "K0")


def forge(w: int, h: int) -> Canvas:
    """The smithy's forge, two frames: a granite hearth with its coals dull
    then bright, a sheet-iron hood, the chimney, and the bellows."""
    fw = w // 2
    out = Canvas(w, h)
    for f in range(2):
        cv = Canvas(fw, h)
        # chimney stack of brick
        cx0, cx1 = fw // 2 - 12, fw // 2 + 12
        for by in range(0, 30, 4):
            off = 0 if (by // 4) % 2 else 4
            cv.rect(cx0, by, cx1 - cx0, 4, "B1")
            for bx in range(cx0 - off, cx1, 8):
                cv.rect(max(cx0, bx + 1), by + 1, min(7, cx1 - max(cx0, bx + 1)), 3, "A0" if hash2(bx, by, 4) > 0.4 else "B2")
        cv.vline(cx0, 0, 30, "B3")
        # the hood
        cv.poly([(fw // 2 - 14, 28), (fw // 2 + 14, 28), (fw - 6, 48), (6, 48)], "G0")
        cv.poly([(fw // 2 - 14, 28), (fw // 2 - 6, 28), (16, 48), (6, 48)], "G1")
        cv.hline(fw // 2 - 14, 28, 28, "G2")
        cv.rect(4, 47, fw - 8, 3, "G1")
        cv.hline(4, 47, fw - 8, "G3")
        for rx in range(10, fw - 8, 10):
            cv.px(rx, 48, "G3")
        # the hearth: cut granite under a lip of iron
        M.granite(cv, 4, 62, fw - 8, h - 64, 1890, course=10, light=-0.2)
        cv.rect(2, 56, fw - 4, 7, "G0")
        cv.hline(2, 56, fw - 4, "G2")
        cv.hline(2, 62, fw - 4, "K0")
        # coals in the firepot
        cv.rect(10, 52, fw - 20, 5, "K0")
        for k in range(36):
            px = 11 + int(hash2(k, 1, f) * (fw - 22))
            py = 52 + int(hash2(k, 2, f) * 4)
            cv.px(px, py, ["A0", "A1", "A2", "B1"][(k + f * 2) % 4] if f else ["A0", "B1", "A0", "K0"][k % 4])
        if f:
            fire(cv, fw // 2 - 9, fw // 2 + 9, 51, 7, f)
        # a pair of tongs hung on the hood
        cv.line(fw - 12, 38, fw - 8, 54, "K0")
        cv.line(fw - 10, 38, fw - 7, 54, "G1")
        g = 0.9 if f else 0.4
        glow(cv, fw / 2, 52, fw * 0.55, 18, g)
        cv.rim(0.5, -0.6)
        cv.outline("K0")
        out.blit(cv, f * fw, 0)
    return out


def workbench(w: int, h: int) -> Canvas:
    """A stout bench: a thick top with a vise, a coil of blue rope being
    cut to length, a hot knife, tape and a tape measure, and a shelf below
    with a tool box and a red can."""
    cv = Canvas(w, h)
    top = 24
    # legs and the low shelf
    for lx in (6, w - 14):
        cv.rect(lx, top + 10, 8, h - top - 12, "B1")
        cv.vline(lx, top + 10, h - top - 12, "B2")
        cv.vline(lx + 7, top + 10, h - top - 12, "B0")
    board(cv, 8, h - 22, w - 16, 5, "B2", 7)
    # under the bench: a tool box and a red fuel can
    cv.rect(26, h - 35, 22, 13, "B0")
    cv.rect(27, h - 34, 20, 11, "B1")
    cv.hline(27, h - 34, 20, "B2")
    cv.rect(33, h - 37, 8, 3, "G1")
    cv.rect(78, h - 38, 24, 16, "R")
    cv.vline(78, h - 38, 16, "A1")
    cv.vline(101, h - 37, 15, "A0")
    cv.rect(82, h - 41, 6, 3, "O2")
    cv.hline(80, h - 31, 20, "A0")
    # the top: a thick slab, its edge toward us
    board(cv, 2, top, w - 4, 6, "T1", 3)
    cv.rect(2, top + 6, w - 4, 6, "B2")
    grain(cv, 2, top + 6, w - 4, 6, "B2", 4)
    cv.hline(2, top + 6, w - 4, "T2")
    cv.hline(2, top + 11, w - 4, "B0")
    # the vise on the right end
    cv.rect(w - 16, top - 6, 12, 8, "G1")
    cv.hline(w - 16, top - 6, 12, "G3")
    cv.rect(w - 14, top + 6, 8, 8, "G0")
    cv.hline(w - 20, top + 9, 18, "G2")
    # rope coil
    cv.ellipse(34, top - 4, 20, 8, "W1")
    cv.ellipse(34, top - 5, 18, 6, "W2")
    for r in (15, 11, 7):
        cv.ellipse(34, top - 5, r, r * 0.38, "W1")
        cv.ellipse(34, top - 5.5, r - 1.5, r * 0.38 - 1, "W2")
    cv.ellipse(34, top - 5, 4, 1.6, "B1")
    for k in range(-16, 17, 4):
        cv.px(34 + k, top - 1, "W3")
    cv.line(54, top - 3, 74, top - 3, "W2")
    cv.line(54, top - 2, 74, top - 2, "W1")
    # hot knife and tape
    cv.rect(76, top - 7, 14, 5, "G1")
    cv.hline(76, top - 7, 14, "G3")
    cv.rect(90, top - 5, 6, 2, "G4")
    cv.rect(102, top - 8, 10, 7, "O2")
    cv.hline(102, top - 8, 10, "O3")
    cv.ellipse(107, top - 4.5, 2, 2, "B0")
    return finish(cv)


# ---------------------------------------------------------------- casks, crates and coolers

def barrels(w: int, h: int) -> Canvas:
    """Two casks: one open and heaped with crackers, one lidded, a flour
    sack slumped against them."""
    cv = Canvas(w, h)
    barrel(cv, 4, 6, 30, h - 8, "T1", 11, lid=False)
    # the crackers heaped in the open one
    for k in range(18):
        cx = 9 + int(hash2(k, 1, 3) * 20)
        cy = 5 + int(hash2(k, 2, 3) * 6)
        cv.rect(cx, cy, 4, 3, "T3")
        cv.hline(cx, cy, 4, "N")
        cv.px(cx + 3, cy + 2, "T2")
    barrel(cv, 38, 12, 30, h - 14, "B3", 12, lid=True)
    # flour sack
    cv.poly([(28, h - 2), (30, h - 18), (36, h - 22), (44, h - 17), (46, h - 2)], "G4")
    cv.poly([(30, h - 18), (36, h - 22), (38, h - 18), (33, h - 4), (28, h - 2)], "G5")
    cv.line(32, h - 19, 42, h - 18, "T1")
    cv.rect(33, h - 13, 9, 5, "T3")
    cv.hline(34, h - 11, 7, "W1")
    return finish(cv)


def crates(w: int, h: int) -> Canvas:
    """Three crates of stock, two on the floor and one on top."""
    cv = Canvas(w, h)
    crate(cv, 2, 26, 32, h - 28, "T1", 1, 7, "R")
    crate(cv, 30, 30, 32, h - 32, "B3", 2, 7, "W1")
    crate(cv, 12, 4, 28, 24, "T2", 3, 6, "P2")
    # a stencil across the top crate's lid
    cv.hline(16, 7, 10, "B2")
    return finish(cv)


def cooler(w: int, h: int) -> Canvas:
    """An ice chest: white enamel, a hinged lid with a handle, ICE in blue,
    and short wooden legs."""
    cv = Canvas(w, h)
    x0, x1 = 3, w - 3
    rrect(cv, x0, 16, x1 - x0, h - 24, "G5", 3)
    # the lid, seen from above
    rrect(cv, x0, 10, x1 - x0, 10, "N", 3)
    cv.hline(x0 + 3, 11, x1 - x0 - 6, "N")
    cv.hline(x0 + 1, 19, x1 - x0 - 2, "G3")
    cv.hline(x0 + 1, 20, x1 - x0 - 2, "G4")
    cv.rect(w // 2 - 7, 6, 14, 5, "G1")
    cv.rect(w // 2 - 5, 7, 10, 2, "G0")
    cv.hline(w // 2 - 7, 6, 14, "G3")
    # front panel
    cv.rect(x0 + 5, 24, x1 - x0 - 10, h - 36, "N")
    cv.frame(x0 + 5, 24, x1 - x0 - 10, h - 36, "G4")
    tw = say_width("ICE") * 2
    for k in range(2):
        cvx = w // 2 - tw // 2
        # double-size letters
        big = Canvas(say_width("ICE"), 7)
        say(big, 0, 0, "ICE", "W2")
        sc = np.repeat(np.repeat(big.a, 2, 0), 2, 1)
        m = sc[..., 3] > 0
        y0 = 28
        sub = cv.a[y0:y0 + sc.shape[0], cvx:cvx + sc.shape[1]]
        sub[m] = sc[m]
        cv.hline(cvx, y0 + 14, tw, "W1")
        break
    # latches, drain, legs
    for lx in (x0 + 7, x1 - 11):
        cv.rect(lx, 18, 4, 4, "G2")
        cv.px(lx, 18, "G4")
    cv.rect(x1 - 9, h - 13, 3, 2, "G2")
    cv.tone(np.where(np.arange(w)[None, :] > w * 0.6, -0.5, 0.0) * np.ones((h - 14, 1)), x=0, y=10)
    for lx in (x0 + 4, x1 - 9):
        cv.rect(lx, h - 9, 5, 8, "B1")
        cv.vline(lx, h - 9, 8, "B2")
    return finish(cv, "G0")


def canisters(w: int, h: int) -> Canvas:
    """A rack of bear canisters: black cylinders with screw lids and a
    yellow warning band, on two wooden shelves."""
    cv = Canvas(w, h)
    for px in (2, w - 6):
        cv.rect(px, 6, 4, h - 8, "B1")
        cv.vline(px, 6, h - 8, "B2")
        cv.vline(px + 3, 6, h - 8, "B0")
    for row, sy in enumerate((6, 32)):
        for i, cx in enumerate(range(9, w - 12, 17)):
            ch = 20
            y = sy + 4
            cv.rect(cx, y + 3, 14, ch - 3, "K1")
            cv.ellipse(cx + 7, y + 3, 7, 2.5, "G1")
            cv.ellipse(cx + 7, y + 2.5, 5.5, 1.6, "G2")
            cv.hline(cx + 3, y + 2, 4, "G3")
            for gx in range(cx + 1, cx + 13, 3):
                cv.px(gx, y + 5, "G0")
            cv.rect(cx, y + 11, 14, 4, "O2")
            cv.hline(cx, y + 11, 14, "O3")
            cv.px(cx + 4, y + 13, "K0")
            cv.px(cx + 9, y + 13, "K0")
            cylinder(cv, cx, y + 3, 14, ch - 3, 0.8)
        board(cv, 2, sy + 24, w - 4, 4, "B2", row)
    return finish(cv)


# ---------------------------------------------------------------- shelves and racks

_STOCK = ["R", "O2", "M1", "L", "W2", "N", "A1", "P2", "S"]


def shelf(w: int, h: int, seed: int = 7) -> Canvas:
    """A store's shelving: a dark back, three shelves of jars, tins and
    boxes, and turned feet."""
    cv = Canvas(w, h)
    cv.rect(2, 2, w - 4, h - 10, "B2")
    cv.rect(5, 4, w - 10, h - 14, "B0")
    grain(cv, 5, 4, w - 10, h - 14, "B1", seed)
    cv.tone(np.full((h - 14, w - 10), -0.5, np.float32), x=5, y=4)
    cv.rect(2, 2, w - 4, 3, "B3")
    cv.hline(2, 2, w - 4, "T2")
    for px in (2, w - 5):
        cv.rect(px, 2, 3, h - 6, "B2")
        cv.vline(px, 2, h - 6, "B3")
    lv = (h - 14) // 3
    for level in range(3):
        base = 4 + (level + 1) * lv
        x = 7
        k = 0
        while x < w - 14:
            r = hash2(level, k, seed)
            c = _STOCK[int(hash2(k, level, seed + 1) * len(_STOCK))]
            if r < 0.3:
                jar(cv, x, base - 14, c)
                x += 10
            elif r < 0.6:
                can(cv, x, base - 11, c)
                x += 9
            elif r < 0.85:
                bw = 9 + int(hash2(k, 3, seed) * 5)
                box(cv, x, base - 17, bw, 17, c)
                x += bw + 2
            else:
                # a bottle
                cv.rect(x + 1, base - 15, 5, 15, "P1" if k % 2 else "A0")
                cv.rect(x + 2, base - 19, 3, 4, "P1" if k % 2 else "A0")
                cv.vline(x + 2, base - 14, 12, "P3" if k % 2 else "A2")
                cv.rect(x + 1, base - 9, 5, 4, "N")
                x += 8
            k += 1
        board(cv, 3, base, w - 6, 4, "B3", level)
        cv.hline(3, base + 4, w - 6, "K0")
    cv.rect(2, h - 8, w - 4, 4, "B2")
    cv.hline(2, h - 8, w - 4, "B3")
    for fx in (3, w - 8):
        cv.rect(fx, h - 4, 5, 3, "B1")
    return finish(cv)


def rack(w: int, h: int) -> Canvas:
    """A clothes rack of park sweatshirts and jackets on hangers."""
    cv = Canvas(w, h)
    for px in (3, w - 6):
        cv.rect(px, 4, 3, h - 10, "G1")
        cv.vline(px, 4, h - 10, "G3")
    cv.rect(1, h - 7, 10, 3, "G0")
    cv.rect(w - 11, h - 7, 10, 3, "G0")
    for ex in (2, w - 10):
        cv.ellipse(ex + 4, h - 3, 3, 2, "K0")
    cv.rect(3, 5, w - 6, 3, "G2")
    cv.hline(3, 5, w - 6, "G4")
    cols = [["P0", "P1", "P2"], ["O0", "O1", "O2"], ["W0", "W1", "W2"], ["A0", "R", "A1"], ["G4", "G5", "N"]]
    n = max(3, (w - 10) // 13)
    sp = (w - 10) / n
    for i in range(n):
        x = int(6 + i * sp)
        d0, d1, d2 = cols[i % 5]
        cv.line(x + 5, 8, x + 5, 5, "G3")
        cv.line(x + 1, 11, x + 5, 8, "G3")
        cv.line(x + 9, 11, x + 5, 8, "G3")
        cv.rect(x, 11, 11, h - 30, d1)
        cv.rect(x - 1, 11, 13, 6, d1)
        cv.hline(x - 1, 11, 13, d2)
        cv.vline(x, 12, h - 31, d2)
        cv.vline(x + 10, 12, h - 31, d0)
        cv.vline(x + 5, 13, h - 33, d0)
        cv.px(x + 4, 12, d0)
        cv.px(x + 6, 12, d0)
        # a hood folded back over the hanger, and the sleeves hanging
        cv.ellipse(x + 5, 12, 4, 2, d0)
        cv.hline(x + 3, 11, 5, d2)
        cv.vline(x - 1, 17, h - 40, d0)
        cv.vline(x + 11, 17, h - 40, d0)
        # a printed badge on the chest
        cv.rect(x + 2, 20, 3, 3, "N" if d1 != "G5" else "P1")
        cv.hline(x, h - 20, 11, d0)
    return finish(cv)


def postcards(w: int, h: int) -> Canvas:
    """A turning rack of postcards: three tiers of little views of the park
    on a turned post."""
    cv = Canvas(w, h)
    cx = w // 2
    cv.rect(cx - 1, 50, 3, h - 54, "B1")
    cv.vline(cx - 1, 50, h - 54, "B3")
    cv.ellipse(cx, h - 4, 9, 3, "B0")
    cv.ellipse(cx, h - 5, 8, 2, "B2")
    kinds = ["valley", "falls", "sunset"]
    for row in range(3):
        y = 2 + row * 17
        cv.rect(3, y, w - 6, 17, "B1")
        cv.hline(3, y, w - 6, "B3")
        cv.hline(3, y + 16, w - 6, "B0")
        for k in range(3):
            x = 5 + k * 10
            view(cv, x, y + 2, 9, 12, row * 3 + k, kinds[(row + k) % 3])
            cv.frame(x, y + 2, 9, 12, "N")
    return finish(cv)


def spinner(w: int, h: int) -> Canvas:
    """A wire carousel of folded trail maps on a pole."""
    cv = Canvas(w, h)
    cx = w // 2
    cv.rect(cx - 1, 46, 2, h - 50, "G1")
    cv.vline(cx - 1, 46, h - 50, "G3")
    cv.ellipse(cx, h - 4, 9, 3, "K0")
    cv.ellipse(cx, h - 5, 8, 2, "G1")
    cols = ["W2", "O2", "M1", "S", "N", "L", "A1", "W3", "R"]
    for row in range(3):
        y = 4 + row * 15
        cv.hline(2, y + 14, w - 4, "G2")
        for k in range(3):
            x = 3 + k * 10
            c = cols[(row * 3 + k) % len(cols)]
            cv.rect(x, y, 9, 14, c)
            cv.hline(x, y, 9, up(c))
            cv.vline(x + 8, y + 1, 13, down(c))
            # a map on the front: contours and a trail
            cv.rect(x + 1, y + 6, 7, 6, "T3")
            cv.px(x + 2, y + 8, "M1")
            cv.px(x + 5, y + 7, "M1")
            cv.line(x + 1, y + 11, x + 7, y + 7, "R")
            cv.hline(x + 1, y + 2, 6, "N" if c != "N" else "B1")
            cv.hline(x + 1, y + 4, 4, down(c))
    cv.rect(cx - 1, 0, 2, 5, "G2")
    return finish(cv, "K0")


def pack_rack(w: int, h: int) -> Canvas:
    """A gear shelf with daypacks and haul bags on three shelves."""
    cv = Canvas(w, h)
    for px in (2, w - 7):
        cv.rect(px, 2, 5, h - 6, "B1")
        cv.vline(px, 2, h - 6, "B3")
        cv.vline(px + 4, 2, h - 6, "B0")
    packs = [("A1", "A2", "A0"), ("W2", "W3", "W1"), ("P2", "P3", "P1")]
    for level in range(3):
        y = 6 + level * 32
        d1, d2, d0 = packs[level]
        # a daypack
        rrect(cv, 9, y + 2, 24, 24, d1, 5)
        cv.hline(12, y + 3, 18, d2)
        cv.vline(10, y + 6, 16, d2)
        rrect(cv, 13, y + 12, 16, 11, d0, 3)
        cv.hline(14, y + 12, 14, d1)
        cv.px(21, y + 17, "O3")
        cv.vline(21, y + 2, 4, "K0")
        # a haul bag, taller and a step darker
        rrect(cv, 37, y + 4, 26, 22, down(d1), 4)
        cv.hline(40, y + 5, 20, d1)
        cv.rect(37, y + 9, 26, 3, "K1")
        cv.px(49, y + 15, "O3")
        cv.line(42, y + 4, 46, y, "G4")
        cv.line(58, y + 4, 54, y, "G4")
        board(cv, 2, y + 27, w - 4, 4, "B2", level)
        cv.hline(2, y + 31, w - 4, "K0")
    return finish(cv)


# ---------------------------------------------------------------- the museum

def basket(big: bool, seed: int):
    """A coiled basket of the Valley's weavers, its banded design as the
    builder drew it: light courses, a dark band set with a row of stitched
    dots, a middle band (the motif is kept as it passed tribal review);
    painted as a round form with a rim and the coil stitches showing."""
    def paint(w: int, h: int) -> Canvas:
        cv = Canvas(w, h)
        cx = w / 2
        top, bot = 6, h - 3
        rim_ry = 3 if big else 2.5
        for yy in range(top, bot):
            t = (yy - top) / (bot - top - 1)
            if big:
                half = (w / 2 - 2) * (0.55 + 0.45 * t)
            else:
                half = (w / 2 - 2) * (0.8 + 0.2 * math.sin(t * math.pi))
            if yy > bot - 3:
                half -= (yy - (bot - 3)) * 1.2
            band = ((yy - top) // 4) % 4
            for xx in range(int(cx - half), int(cx + half) + 1):
                c = "T3" if band < 2 else ("B2" if band == 2 else "T1")
                if band == 2 and ((xx // 2) + ((yy - top) // 2)) % 3 == 0 and (yy - top) % 4 in (1, 2):
                    c = "B0"
                cv.px(xx, yy, c)
        # the coils: a faint seam between courses in the light bands
        for yy in range(top + 2, bot, 4):
            band = ((yy - top) // 4) % 4
            if band in (0, 1, 3):
                for xx in range(w):
                    if cv.a[yy, xx, 3] and (xx + yy // 4) % 2 == 0:
                        cv.px(xx, yy, "T2" if band < 2 else "T0")
        cylinder(cv, 0, top, w, bot - top, 0.9)
        # the mouth: a rim coil and the dark inside
        half0 = (w / 2 - 2) * (0.55 if big else 0.8)
        cv.ellipse(cx, top, half0 + 0.5, rim_ry, "T2")
        cv.ellipse(cx, top, half0 - 1.5, rim_ry - 1, "B1")
        cv.ellipse(cx - 1, top + 0.5, half0 - 3, rim_ry - 1.6, "B0")
        cv.hline(int(cx - half0 + 1), top - int(rim_ry), int(half0), "T3")
        return finish(cv)
    return paint


def _terrain(look: str, mh: int, mw: int) -> tuple[np.ndarray, np.ndarray]:
    """A relief model's heights (0..1) and surface (0 rock, 1 forest, 2
    meadow, 3 water, 4 ice, 5 snow) over mh x mw pixels, far edge at the top."""
    from kit import noise
    yy, xx = np.mgrid[0:mh, 0:mw].astype(np.float32)
    n1 = noise(mh, mw, 9, 71) - 0.5
    n2 = noise(mh, mw, 4, 72) - 0.5
    surf = np.zeros((mh, mw), np.int32)
    if look in ("valley", "glacier"):
        mid = mh * 0.55 + 2.5 * np.sin(xx * 0.06) + 1.2 * np.sin(xx * 0.17)
        d = np.abs(yy - mid)
        fl = 4.0 if look == "valley" else 6.5
        wall = np.clip((d - fl) / 5.0, 0, 1)
        hgt = 0.2 + 0.62 * wall ** 0.7 + 0.12 * n1 * wall + 0.05 * n2 * wall
        # Half Dome on the far wall toward the east, El Capitan's prow on the near wall to the west
        hd = np.clip(1 - ((xx - mw * 0.8) / 7) ** 2 - ((yy - mid + 9) / 5) ** 2, 0, 1)
        hgt += 0.3 * np.where(yy > mid - 9, np.minimum(hd * 3, 1) * hd ** 0.3, hd)
        ec = np.clip(1 - ((xx - mw * 0.2) / 6) ** 2 - ((yy - mid - 8) / 4) ** 2, 0, 1)
        hgt += 0.18 * ec ** 0.5
        surf[:] = 0
        rim = (wall >= 1) & (n1 > -0.15)
        surf[rim] = 1
        if look == "valley":
            floor_ = d < fl + 0.6
            surf[floor_] = np.where(n2[floor_] > 0.05, 1, 2)
            river = np.abs(yy - mid - 0.8 * np.sin(xx * 0.4)) < 0.7
            surf[river] = 3
        else:
            ice = d < fl + 0.6
            hgt[ice] = 0.62 + 0.02 * n2[ice]
            surf[ice] = 4
            surf[(wall >= 1) & (n1 > 0.15)] = 5
    elif look == "tuolumne":
        mid = mh * 0.5 + 3 * np.sin(xx * 0.05 + 1) + 1.5 * np.sin(xx * 0.13)
        d = np.abs(yy - mid)
        hgt = 0.18 + 0.4 * np.clip((d - 6) / 8, 0, 1) + 0.12 * n1
        for du, dv, r, a in ((0.22, 0.25, 6, 0.5), (0.5, 0.8, 5, 0.4), (0.78, 0.18, 6, 0.55), (0.92, 0.75, 4, 0.35)):
            dome = np.clip(1 - ((xx - mw * du) / (r * 1.5)) ** 2 - ((yy - mh * dv) / r) ** 2, 0, 1)
            hgt += a * np.sqrt(dome)
        surf[:] = 1
        surf[(d < 6.5) & (hgt < 0.4)] = 2
        surf[hgt > 0.45] = 0
        river = np.abs(yy - mid - 1.5 * np.sin(xx * 0.3)) < 0.7
        surf[river & (hgt < 0.4)] = 3
    else:
        r1 = noise(mh, mw, 12, 81)
        r2 = noise(mh, mw, 5, 82)
        hgt = 0.1 + 0.75 * r1 ** 1.4 + 0.15 * r2
        surf[:] = 0
        surf[(hgt < 0.42) & (r2 > 0.3)] = 1
        surf[hgt > 0.7] = 5
        lake = (hgt < 0.24) & (noise(mh, mw, 7, 83) > 0.5)
        hgt[lake] = 0.2
        surf[lake] = 3
    return hgt.astype(np.float32), surf


def relief(look: str):
    """A relief model of the park on a display table: the terrain modelled
    and hill-shaded from the upper left (the Valley with Half Dome and El
    Capitan, the Valley full of ice, the high country's peaks and lakes, or
    Tuolumne's meadow among its domes), its cut edge toward the room, a brass
    plaque on the table's apron."""
    def paint(w: int, h: int) -> Canvas:
        cv = Canvas(w, h)
        mx0, mx1 = 4, w - 4
        my0, my1 = 3, 30
        mw, mh = mx1 - mx0, my1 - my0
        H, S = _terrain(look, mh, mw)
        gx = np.zeros_like(H)
        gy = np.zeros_like(H)
        gx[:, 1:-1] = (H[:, 2:] - H[:, :-2]) / 2
        gy[1:-1, :] = (H[2:, :] - H[:-2, :]) / 2
        # lit from the upper left: slopes facing up-left brighten
        lit = -(gx + gy) * 14.0 + (H - 0.5) * 0.6
        for yy in range(mh):
            for xx in range(mw):
                b = M.BAYER[yy & 3, xx & 3] - 0.5
                l = lit[yy, xx] + b * 0.7
                s = S[yy, xx]
                if s == 3:
                    c = "W3" if hash2(xx, yy, 3) > 0.7 else "W2"
                elif s == 4:
                    c = "N" if l > -0.1 else ("W5" if l > -0.8 else "W4")
                elif s == 5:
                    c = "N" if l > -0.5 else "G4"
                elif s == 2:
                    c = "M2" if l > 0.2 else ("M1" if l > -0.4 else "M0")
                elif s == 1:
                    c = "P3" if l > 0.6 else ("P2" if l > -0.2 else "P1")
                    if hash2(xx, yy, 9) > 0.8:
                        c = "P1"
                else:
                    c = "G5" if l > 1.1 else ("G4" if l > 0.35 else ("G3" if l > -0.45 else "G2"))
                cv.px(mx0 + xx, my0 + yy, c)
        if look == "glacier":
            # crevasses: short dark breaks across the ice's flow
            for k in range(26):
                cx_ = int(hash2(k, 1, 13) * mw)
                cy_ = int(hash2(k, 2, 13) * mh)
                if S[cy_, cx_] == 4:
                    for t in range(3):
                        if cy_ + t < mh and S[cy_ + t, cx_] == 4:
                            cv.px(mx0 + cx_ + (t == 2), my0 + cy_ + t, "W3" if t else "W4")
        # the model's cut edge, its layers of board stepped with the height
        for xx in range(mw):
            top = my1 - int(H[-1, xx] * 3)
            cv.vline(mx0 + xx, top, my1 + 4 - top, "T2")
            cv.px(mx0 + xx, top, "T3")
            for k in range(my1 + 4 - top):
                if (top + k) % 2 == 0:
                    cv.px(mx0 + xx, top + k, "T1")
        cv.hline(mx0, my1 + 3, mw, "T0")
        cv.frame(mx0 - 1, my0 - 1, mw + 2, my1 - my0 + 6, "B0")
        # the table: a moulded rim, an apron with a plaque, legs
        cv.rect(1, my1 + 4, w - 2, 4, "B2")
        cv.hline(1, my1 + 4, w - 2, "B3")
        cv.rect(3, my1 + 8, w - 6, 12, "B1")
        grain(cv, 3, my1 + 8, w - 6, 12, "B1", 9)
        cv.hline(3, my1 + 8, w - 6, "B0")
        cv.hline(3, my1 + 19, w - 6, "B0")
        pw = 26
        cv.rect(w // 2 - pw // 2, my1 + 10, pw, 7, "O1")
        cv.hline(w // 2 - pw // 2, my1 + 10, pw, "O3")
        cv.hline(w // 2 - pw // 2 + 3, my1 + 13, pw - 6, "O0")
        _legs(cv, [4, w - 7, w // 2 - 1], my1 + 20, h - my1 - 22)
        return finish(cv)
    return paint


def panel(w: int, h: int) -> Canvas:
    """A free-standing exhibit panel: a dark green frame on two legs, a cream
    sheet with a title bar, a photograph and lines of text."""
    cv = Canvas(w, h)
    for lx in (8, w - 12):
        cv.rect(lx, 44, 4, h - 47, "B1")
        cv.vline(lx, 44, h - 47, "B3")
        cv.rect(lx - 3, h - 4, 10, 3, "B0")
    cv.rect(10, 50, w - 20, 3, "B1")
    cv.rect(1, 1, w - 2, 48, "P0")
    cv.hline(1, 1, w - 2, "P2")
    cv.vline(1, 1, 48, "P1")
    cv.rect(4, 4, w - 8, 42, "G5")
    cv.hline(4, 4, w - 8, "N")
    cv.rect(4, 4, w - 8, 5, "P1")
    cv.hline(7, 6, 22, "G5")
    view(cv, 7, 12, w - 14, 16, 30, "valley")
    cv.frame(6, 11, w - 12, 18, "B0")
    for k, ly in enumerate(range(32, 44, 3)):
        cv.hline(7, ly, int(w - 16 - hash2(k, 2, 4) * 14), "B2")
    cv.hline(1, 48, w - 2, "K0")
    return finish(cv, "K0")


def easel(look: str):
    """A studio easel: splayed front legs, a back leg, the tray with a
    palette and brushes, and a canvas: a painting of the Valley, the falls,
    a half-finished one, or a photograph."""
    def paint(w: int, h: int) -> Canvas:
        cv = Canvas(w, h)
        cx = w // 2
        # legs
        cv.line(cx - 4, 2, 6, h - 2, "B1")
        cv.line(cx - 3, 2, 7, h - 2, "B3")
        cv.line(cx + 3, 2, w - 7, h - 2, "B1")
        cv.line(cx + 4, 2, w - 6, h - 2, "B2")
        cv.line(cx, 4, cx, h - 8, "B0")
        cv.line(cx + 1, 4, cx + 1, h - 8, "B1")
        cv.rect(cx - 3, 0, 7, 4, "B2")
        cv.hline(cx - 3, 0, 7, "B3")
        # the canvas
        x, y, cw, ch = 7, 9, w - 14, 40
        if look == "photo":
            picture_frame(cv, x, y, cw, ch, False)
            cv.rect(x, y, cw, ch, "N")
            view(cv, x + 3, y + 3, cw - 6, ch - 6, 41, "valley", mono=True)
        else:
            picture_frame(cv, x, y, cw, ch, True)
            kind = {"painting": "valley", "two": "sunset", "half": "falls"}[look]
            view(cv, x, y, cw, ch, 17 if look == "painting" else 23, kind)
            if look == "half":
                # the lower part still bare canvas, the sketch in pencil
                cv.rect(x, y + 17, cw, ch - 17, "G5")
                for xx in range(cw):
                    yy = y + 17 + int(10 + 6 * math.sin(xx * 0.18))
                    if xx % 2 == 0:
                        cv.px(x + xx, yy, "G3")
                for k in range(6):
                    tx = x + 4 + k * 6
                    cv.line(tx, y + ch - 4, tx + 2, y + ch - 12, "G3")
                # where the paint stops, a ragged edge
                for xx in range(cw):
                    if hash2(xx, 1, 9) > 0.5:
                        cv.px(x + xx, y + 17, "G4")
        # the tray, a palette with dabs of paint, brushes
        cv.rect(4, y + ch + 4, w - 8, 4, "B2")
        cv.hline(4, y + ch + 4, w - 8, "T1")
        cv.hline(4, y + ch + 7, w - 8, "B0")
        if look != "photo":
            cv.ellipse(14, y + ch + 2, 7, 3, "T2")
            cv.ellipse(14, y + ch + 1.5, 6, 2, "T3")
            for k, c in enumerate(("R", "W2", "O3", "N", "P2")):
                cv.px(10 + k * 2, y + ch + 1 + (k % 2), c)
            cv.line(w - 20, y + ch + 3, w - 8, y + ch, "B3")
            cv.line(w - 18, y + ch + 3, w - 10, y + ch - 1, "T2")
            cv.px(w - 8, y + ch, "W2")
        return finish(cv)
    return paint


def telescope(w: int, h: int) -> Canvas:
    """A brass spotting telescope on a wooden tripod, aimed up at the rim."""
    cv = Canvas(w, h)
    cx = w // 2
    for ex in (5, cx, w - 5):
        cv.line(cx, 34, ex, h - 2, "B1")
        cv.line(cx + 1, 34, ex + (1 if ex >= cx else 0), h - 2, "B3" if ex <= cx else "B2")
        cv.rect(ex - 1, h - 3, 3, 2, "G1")
    cv.rect(cx - 3, 30, 7, 6, "G1")
    cv.hline(cx - 3, 30, 7, "G3")
    # the tube: three draws, brass, toward the upper left
    for i, (r, c) in enumerate(((4.0, "O1"), (3.2, "O2"), (2.5, "O1"))):
        x0 = 30 - i * 9
        y0 = 26 - i * 7
        for t in range(10):
            px, py = x0 - t, y0 - t * 0.75
            cv.ellipse(px, py, r, r * 0.9, c)
    for t in range(26):
        cv.px(31 - t, 22 - t * 0.75, "O3")
    cv.ellipse(5, 3, 3.5, 3, "O0")
    cv.ellipse(5, 3, 2, 1.8, "W1")
    cv.ellipse(32, 27, 3, 3, "K0")
    return finish(cv)


def safe(w: int, h: int) -> Canvas:
    """The express office's safe: green-enamelled iron, the company's
    initials in gilt, a brass dial and handle, on squat feet."""
    cv = Canvas(w, h)
    rrect(cv, 2, 2, w - 4, h - 8, "P1", 2)
    cv.rect(2, 2, w - 4, 4, "P2")
    cv.hline(3, 2, w - 6, "P3")
    cv.vline(2, 3, h - 10, "P2")
    cv.vline(w - 3, 3, h - 10, "P0")
    cv.hline(2, h - 7, w - 4, "P0")
    # the door
    cv.rect(6, 9, w - 12, h - 20, "P0")
    cv.rect(7, 10, w - 14, h - 22, "P1")
    cv.frame(7, 10, w - 14, h - 22, "O1")
    cv.hline(8, 11, w - 16, "P2")
    say(cv, 11, 13, "WF", "O3", shadow="P0")
    cv.hline(10, 22, w - 20, "O1")
    # dial and handle
    cv.ellipse(w / 2 - 3, 32, 6, 6, "O1")
    cv.ellipse(w / 2 - 3, 32, 4.5, 4.5, "O2")
    cv.ellipse(w / 2 - 4, 31, 2, 2, "O3")
    for a in range(0, 360, 45):
        cv.px(w / 2 - 3 + math.cos(math.radians(a)) * 5.5, 32 + math.sin(math.radians(a)) * 5.5, "O0")
    cv.px(w / 2 - 3, 32, "K0")
    cv.rect(w - 15, 29, 3, 8, "O2")
    cv.vline(w - 15, 29, 8, "O3")
    for hy in (12, h - 16):
        cv.rect(4, hy, 2, 4, "O1")
    # feet
    for fx in (4, w - 10):
        cv.rect(fx, h - 6, 6, 4, "K0")
        cv.hline(fx, h - 6, 6, "G1")
    return finish(cv, "K0")


def luggage(w: int, h: int) -> Canvas:
    """A bellman's cart: a brass frame on wheels, its red-carpet deck stacked
    with a leather case, a blue grip and a hatbox."""
    cv = Canvas(w, h)
    for ux in (4, w - 7):
        cv.rect(ux, 4, 3, h - 14, "O1")
        cv.vline(ux, 4, h - 14, "O3")
    cv.rect(4, 2, w - 8, 3, "O2")
    cv.hline(4, 2, w - 8, "O3")
    cv.rect(2, h - 12, w - 4, 4, "R")
    cv.hline(2, h - 12, w - 4, "A1")
    cv.rect(2, h - 8, w - 4, 2, "O0")
    for wx in (7, w - 9):
        cv.ellipse(wx, h - 4, 3, 3, "K0")
        cv.px(wx - 1, h - 5, "G3")
    cases = [(7, h - 26, w - 14, 14, "B2"), (10, h - 38, w - 22, 12, "W1")]
    for (x, y, cw, ch, c) in cases:
        rrect(cv, x, y, cw, ch, c, 2)
        cv.hline(x + 2, y, cw - 4, up(c))
        cv.vline(x, y + 2, ch - 4, up(c))
        cv.hline(x + 1, y + ch - 1, cw - 2, down(c))
        for sx in (x + 5, x + cw - 7):
            cv.vline(sx, y, ch, down(c, 2) if c != "W1" else "B1")
            cv.px(sx, y + ch // 2, "O2")
        cv.rect(x + cw // 2 - 3, y - 2, 7, 2, "B0")
        cv.px(x + cw // 2 - 3, y - 1, "B1")
    cv.rect(14, h - 21, 7, 5, "O3")
    cv.hline(15, h - 19, 5, "O1")
    cv.rect(w - 22, h - 34, 6, 4, "N")
    cx = w // 2
    cv.rect(cx - 10, h - 48, 20, 9, "T1")
    cv.ellipse(cx, h - 39, 10, 3, "T1")
    cv.ellipse(cx, h - 48, 10, 3, "T3")
    cv.hline(cx - 10, h - 44, 20, "R")
    cylinder(cv, cx - 10, h - 47, 20, 9, 0.7)
    return finish(cv)


# ---------------------------------------------------------------- lamps and plants

def lamp(w: int, h: int) -> Canvas:
    """A floor lamp: a pleated parchment shade, lit from within, on a bronze
    pole with a turned foot."""
    cv = Canvas(w, h)
    cx = w // 2
    cv.poly([(cx - 12, 24), (cx + 12, 24), (cx + 7, 3), (cx - 7, 3)], "T3")
    cv.poly([(cx - 12, 24), (cx - 4, 24), (cx - 2, 3), (cx - 7, 3)], "N")
    cv.poly([(cx + 5, 24), (cx + 12, 24), (cx + 7, 3), (cx + 4, 3)], "T2")
    for k in range(-9, 10, 3):
        cv.line(cx + k * 0.6, 4, cx + k, 23, "A3" if k < 0 else "T2")
    cv.hline(cx - 7, 3, 15, "O1")
    cv.hline(cx - 12, 24, 25, "O0")
    cv.hline(cx - 11, 25, 23, "A2")
    cv.rect(cx - 1, 26, 3, h - 34, "O0")
    cv.vline(cx - 1, 26, h - 34, "O2")
    for ky in (38, 56):
        cv.ellipse(cx, ky, 3, 1.5, "O1")
        cv.px(cx - 2, ky - 1, "O3")
    cv.ellipse(cx, h - 5, 9, 3, "O0")
    cv.ellipse(cx, h - 6, 8, 2, "O1")
    cv.hline(cx - 6, h - 7, 6, "O3")
    return finish(cv, "B0", light=False)


def plant(w: int, h: int) -> Canvas:
    """A potted rubber plant: broad glossy leaves, each lit on its upper
    side, a pale midrib, in a terracotta pot."""
    cv = Canvas(w, h)
    cx = w // 2
    top = h - 18
    cv.poly([(cx - 10, top), (cx + 10, top), (cx + 7, h - 2), (cx - 7, h - 2)], "A0")
    cv.poly([(cx - 10, top), (cx - 3, top), (cx - 2, h - 2), (cx - 7, h - 2)], "A1")
    cv.vline(cx - 7, top + 3, 12, "A2")
    cv.rect(cx - 11, top - 3, 23, 5, "A1")
    cv.hline(cx - 11, top - 3, 23, "A2")
    cv.hline(cx - 11, top + 1, 23, "B1")
    cv.ellipse(cx, top - 3, 9, 2, "B0")
    # (angle from upright, length): back leaves first
    leaves = [(-0.35, 26), (0.3, 27), (0.0, 33), (-1.0, 17), (1.0, 18), (-0.7, 22), (0.7, 22), (-0.15, 18), (0.2, 16)]
    for i, (a, ln) in enumerate(leaves):
        dx, dy = math.sin(a), -math.cos(a)
        bx, by = cx + dx * 3, top - 4
        tx, ty = cx + dx * ln, top - 4 + dy * ln
        cv.line(cx, top - 3, bx + dx * ln * 0.3, by + dy * ln * 0.3, "P0")
        # the blade: a pointed oval along the leaf's axis
        px, py = -dy, dx
        L = ln * 0.75
        sx, sy = bx + dx * ln * 0.28, by + dy * ln * 0.28
        wd = 4.5 if ln > 20 else 3.6
        side1, side2 = [], []
        for k in range(9):
            t = k / 8
            wk = wd * math.sin(t * math.pi) ** 0.8
            ax, ay = sx + dx * L * t, sy + dy * L * t
            side1.append((ax + px * wk, ay + py * wk))
            side2.append((ax - px * wk, ay - py * wk))
        lit_first = (px + py) < 0
        cv.poly(side1 + side2[::-1], "P1")
        cv.poly([(sx, sy)] + (side1 if lit_first else side2) + [(sx + dx * L, sy + dy * L)], "P2" if i < 3 else "P3")
        cv.line(sx, sy, sx + dx * L * 0.9, sy + dy * L * 0.9, "M1" if i >= 3 else "P3")
        hx, hy = sx + dx * L * 0.35 + (px if lit_first else -px) * wd * 0.45, sy + dy * L * 0.35 + (py if lit_first else -py) * wd * 0.45
        cv.px(hx, hy, "M2")
    return finish(cv, "P0", light=False)


# ---------------------------------------------------------------- stoves and fireplaces

def stove(w: int, h: int) -> Canvas:
    """A cast-iron potbelly stove, two frames: its fire low, then high. A
    blue enamel coffee pot sits on the shelf, the pipe rises out of sight."""
    fw = w // 2
    out = Canvas(w, h)
    for f in range(2):
        cv = Canvas(fw, h)
        cx = fw // 2
        # stovepipe with a damper
        cv.rect(cx - 4, 0, 8, 34, "G0")
        cv.vline(cx - 3, 0, 34, "G2")
        cv.vline(cx - 2, 0, 34, "G1")
        cv.vline(cx + 3, 0, 34, "K0")
        for jy in (10, 22):
            cv.hline(cx - 4, jy, 8, "K0")
            cv.hline(cx - 4, jy + 1, 8, "G2")
        cv.rect(cx - 6, 30, 12, 5, "G1")
        cv.hline(cx - 6, 30, 12, "G3")
        # top plate and its rim
        cv.ellipse(cx, 38, 15, 4, "G1")
        cv.ellipse(cx, 37, 13, 3, "G2")
        cv.rect(cx - 15, 38, 30, 3, "K0")
        # the belly
        cv.ellipse(cx, 56, 17, 16, "K1")
        cv.ellipse(cx, 56, 17, 16, "G0")
        cylinder(cv, cx - 17, 41, 34, 31, 1.0)
        cv.rect(cx - 13, 46, 26, 3, "G2")
        cv.hline(cx - 13, 46, 26, "G3")
        cv.rect(cx - 12, 68, 24, 3, "G1")
        # the door, its fire behind a grate
        cv.rect(cx - 7, 52, 14, 12, "K0")
        if f:
            cv.rect(cx - 6, 53, 12, 10, "A0")
            fire(cv, cx - 5, cx + 5, 61, 8, f)
        else:
            cv.rect(cx - 6, 58, 12, 5, "B0")
            for ex in range(cx - 6, cx + 6, 2):
                cv.px(ex, 61, "A1")
                cv.px(ex + 1, 60, "A0")
            fire(cv, cx - 4, cx + 3, 60, 4, f, high=False)
        for gx in range(cx - 6, cx + 7, 3):
            cv.vline(gx, 52, 12, "G1")
        cv.frame(cx - 8, 51, 16, 14, "G2")
        cv.px(cx + 9, 57, "G4")
        # legs and ash pan
        for lx in (cx - 13, cx + 10):
            cv.rect(lx, 70, 4, h - 72, "K0")
            cv.vline(lx, 70, h - 72, "G1")
            cv.rect(lx - 1, h - 3, 6, 2, "K0")
        cv.rect(cx - 6, 72, 12, 4, "G1")
        # the coffee pot
        px0 = 2
        cv.rect(px0 + 1, 30, 10, 9, "W1")
        cv.poly([(px0 + 2, 30), (px0 + 10, 30), (px0 + 8, 26), (px0 + 4, 26)], "W2")
        cv.vline(px0 + 2, 31, 7, "W3")
        cv.rect(px0 + 5, 24, 3, 2, "G1")
        cv.line(px0, 33, px0 - 2, 30, "W1")
        for k in range(4):
            cv.px(px0 + 4 + k * 2, 32 + (k % 2) * 3, "N")
        if f:
            cv.px(px0 + 6, 21, "G4")
            cv.px(px0 + 7, 19, "G5")
        glow(cv, cx, 60, 26, 20, 1.0 if f else 0.45)
        cv.rim(0.4, -0.5)
        cv.outline("K0")
        out.blit(cv, f * fw, 0)
    return out


def rubble(cv: Canvas, x0: int, y0: int, w: int, h: int, seed: int) -> None:
    """Rough granite rubble: rounded field stones packed in dark mortar,
    each lit on its upper left."""
    cv.rect(x0, y0, w, h, "G1")
    yy = y0
    r = 0
    while yy < y0 + h:
        sh = 9 + int(hash2(r, 1, seed) * 6)
        xx = x0 - int(hash2(r, 2, seed) * 10)
        k = 0
        while xx < x0 + w:
            sw = 12 + int(hash2(r, k, seed + 3) * 14)
            t = ["G3", "G4", "G3", "G2", "T2", "G4"][int(hash2(k, r, seed + 4) * 6)]
            sub = Canvas(sw, sh)
            rrect(sub, 0, 0, sw - 1, sh - 1, t, 3)
            for s in range(sw * sh // 12):
                sub.px(int(hash2(s, k, seed + r) * sw), int(hash2(k, s, seed + r) * sh), down(t) if s % 3 else up(t))
            d = np.zeros((sh, sw), np.float32)
            yy_, xx_ = np.mgrid[0:sh, 0:sw].astype(np.float32)
            d += 0.9 * np.clip(1 - (xx_ / sw + yy_ / sh), 0, 1) - 0.8 * np.clip((xx_ / sw + yy_ / sh) - 1.1, 0, 1) * 2
            sub.tone(d)
            cv.blit(sub, xx, yy)
            xx += sw
            k += 1
        yy += sh
        r += 1


def hearth(style: str):
    """A stone fireplace on the back wall, two frames (fire low, then high):
    cut granite with a timber mantel (lodge lobbies, the Pavilion), field
    rubble with a granite lintel (Parsons Lodge) or a smaller cut-stone one
    (the View Lodge)."""
    def paint(w: int, h: int) -> Canvas:
        fw = w // 2
        out = Canvas(w, h)
        for f in range(2):
            cv = Canvas(fw, h)
            if style == "rubble":
                rubble(cv, 0, 0, fw, h - 8, 151)
            else:
                M.granite(cv, 0, 0, fw, h - 8, 61 if style == "cut" else 117, course=12, light=0.05)
            cv.hline(0, 0, fw, "G5")
            # the opening
            ow = int(fw * (0.56 if style != "small" else 0.5))
            ox0 = fw // 2 - ow // 2
            ox1 = ox0 + ow
            oh = int(h * 0.36)
            oy1 = h - 10
            oy0 = oy1 - oh
            # lintel or arch, and the mantel above
            if style == "rubble":
                cv.rect(ox0 - 8, oy0 - 10, ow + 16, 10, "G3")
                cv.hline(ox0 - 8, oy0 - 10, ow + 16, "G5")
                cv.hline(ox0 - 8, oy0 - 9, ow + 16, "G4")
                cv.hline(ox0 - 8, oy0 - 1, ow + 16, "G1")
                for k in range(3):
                    cv.vline(ox0 - 8 + (ow + 16) * (k + 1) // 4, oy0 - 9, 8, "G2")
            else:
                my = oy0 - 16
                cv.rect(ox0 - 12, my, ow + 24, 7, "B1")
                grain(cv, ox0 - 12, my, ow + 24, 7, "B1", 5)
                cv.hline(ox0 - 12, my, ow + 24, "B3")
                cv.hline(ox0 - 12, my + 1, ow + 24, "B2")
                cv.hline(ox0 - 12, my + 6, ow + 24, "B0")
                for kx in (ox0 - 8, ox1 + 5):
                    cv.rect(kx, my + 7, 3, 4, "B1")
                # on the mantel: candlesticks, a clock or a photograph
                for mx in (ox0 - 4, ox1 + 1):
                    cv.rect(mx, my - 9, 3, 9, "N")
                    cv.rect(mx - 1, my - 2, 5, 2, "O1")
                    cv.px(mx + 1, my - 11, "A2")
                    cv.px(mx + 1, my - 12, "O3")
                cv.rect(fw // 2 - 7, my - 11, 14, 11, "B2")
                cv.hline(fw // 2 - 7, my - 11, 14, "B3")
                if style == "cut":
                    cv.ellipse(fw / 2, my - 6, 4, 4, "N")
                    cv.px(fw // 2, my - 7, "K0")
                    cv.px(fw // 2 + 1, my - 6, "K0")
                else:
                    view(cv, fw // 2 - 5, my - 9, 10, 8, 3, "valley", mono=True)
            # stone voussoirs round the opening's head
            cv.rect(ox0 - 3, oy0 - 3, ow + 6, oh + 3, "G4")
            cv.hline(ox0 - 3, oy0 - 3, ow + 6, "G5")
            for vx in range(ox0, ox1, 9):
                cv.vline(vx, oy0 - 3, 3, "G2")
            cv.rect(ox0, oy0, ow, oh, "K0")
            cv.ellipse(fw / 2, oy0, ow / 2, 5, "G4")
            cv.ellipse(fw / 2, oy0 + 1, ow / 2 - 2, 4, "K0")
            # firebrick back and sides
            for by in range(oy0 + 5, oy1 - 3, 5):
                off = 0 if (by // 5) % 2 else 5
                for bx in range(ox0 + 4 + off, ox1 - 4, 10):
                    cv.rect(bx, by, min(8, ox1 - 4 - bx), 3, "B1")
                    cv.hline(bx, by, min(8, ox1 - 4 - bx), "A0")
            cv.rect(ox0, oy0, 4, oh, "B0")
            cv.rect(ox1 - 4, oy0, 4, oh, "B0")
            # andirons, logs, the fire
            fy = oy1 - 5
            cv.rect(ox0 + 6, fy - 1, ow - 12, 5, "B1")
            cv.hline(ox0 + 6, fy - 1, ow - 12, "B2")
            cv.rect(ox0 + 10, fy - 6, ow - 20, 5, "B2")
            cv.hline(ox0 + 10, fy - 6, ow - 20, "B3")
            cv.ellipse(ox0 + 10, fy - 4, 2.5, 2.5, "T2")
            cv.ellipse(ox1 - 10, fy - 4, 2.5, 2.5, "T2")
            fire(cv, ox0 + 9, ox1 - 9, fy - 6, int(oh * (0.62 if f else 0.42)), f, high=bool(f))
            for ax in (ox0 + 7, ox1 - 10):
                cv.rect(ax, fy - 8, 3, 12, "K0")
                cv.ellipse(ax + 1, fy - 9, 2.5, 2.5, "O2")
            # the fire's light on the stone face
            yy, xx = np.mgrid[0:h, 0:fw].astype(np.float32)
            outside = (xx < ox0) | (xx >= ox1) | (yy < oy0)
            dist = np.sqrt(((xx - fw / 2) / (ow * 0.95)) ** 2 + ((yy - oy1 + 8) / (oh * 1.4)) ** 2)
            cv.tone(np.where(outside, (1.0 if f else 0.6) * np.clip(1 - dist, 0, 1), 0.0).astype(np.float32))
            # the hearthstone
            cv.rect(0, h - 10, fw, 8, "G3")
            cv.hline(0, h - 10, fw, "G5")
            cv.hline(0, h - 9, fw, "G4")
            for jx in range(fw // 4, fw, fw // 2):
                cv.vline(jx, h - 9, 7, "G2")
            cv.hline(0, h - 3, fw, "G1")
            cv.rim(0.4, -0.6)
            cv.outline("K0")
            out.blit(cv, f * fw, 0)
        return out
    return paint


# ---------------------------------------------------------------- Camp Curry Store

def store_counter(w: int, h: int) -> Canvas:
    """The store's long counter: a pale maple top over a panelled front, a
    brass scale, candy jars, the ledger, a bell and a basket of eggs."""
    cv = Canvas(w, h)
    top = 12
    board(cv, 2, top, w - 4, 8, "T2", 3)
    cv.hline(2, top, w - 4, "T3")
    cv.hline(2, top + 1, w - 4, "T3")
    cv.rect(2, top + 8, w - 4, 3, "B2")
    cv.hline(2, top + 10, w - 4, "B0")
    panel_front(cv, 4, top + 11, w - 8, h - top - 16, "B3", 7, 5)
    cv.rect(2, h - 5, w - 4, 4, "B1")
    cv.hline(2, h - 5, w - 4, "B0")
    # scale
    cv.rect(24, 1, 3, 12, "O1")
    cv.hline(10, 2, 32, "O2")
    cv.hline(10, 3, 32, "O0")
    for sx in (10, 34):
        cv.ellipse(sx + 4, 9, 6, 2, "O1")
        cv.ellipse(sx + 4, 8.5, 5, 1.2, "O3")
        cv.vline(sx + 1, 3, 6, "O0")
        cv.vline(sx + 7, 3, 6, "O0")
    cv.rect(20, 11, 11, 2, "O0")
    # candy jars
    for jx, c in ((76, "S"), (88, "O3"), (100, "M2")):
        cv.rect(jx, 2, 10, 11, "W5")
        cv.rect(jx + 1, 5, 8, 7, c)
        for k in range(4):
            cv.px(jx + 2 + k * 2, 6 + k % 2 * 3, up(c) if c != "M2" else "N")
        cv.rect(jx + 2, 0, 6, 2, "G3")
        cv.vline(jx + 1, 3, 9, "N")
    # the ledger
    cv.rect(122, 6, 26, 8, "N")
    cv.vline(135, 6, 8, "G3")
    for ly in (8, 10):
        cv.hline(124, ly, 9, "G3")
        cv.hline(137, ly, 9, "G3")
    cv.rect(121, 12, 28, 2, "B1")
    # the bell
    cv.ellipse(176, 9, 5, 4, "O2")
    cv.ellipse(175, 7, 2, 1.5, "O3")
    cv.rect(172, 12, 9, 2, "O0")
    cv.px(176, 4, "O1")
    # basket of eggs
    cv.ellipse(214, 9, 13, 5, "T1")
    cv.ellipse(214, 8, 11, 3, "B1")
    for k, (ex, ey) in enumerate(((206, 7), (211, 6), (216, 6), (221, 7), (209, 9), (214, 9), (219, 9))):
        cv.ellipse(ex, ey, 2.5, 2, "N" if k % 3 else "T3")
        cv.px(ex - 1, ey - 1, "N")
    for k in range(-12, 13, 3):
        cv.px(214 + k, 12, "T2")
    cv.line(202, 8, 214, 0, "T1")
    cv.line(214, 0, 226, 8, "T1")
    return finish(cv)


def produce_table(w: int, h: int) -> Canvas:
    """A trestle table of three crates heaped with apples, lemons and
    greens."""
    cv = Canvas(w, h)
    for lx in (8, w - 14):
        cv.rect(lx, 34, 6, h - 36, "B1")
        cv.vline(lx, 34, h - 36, "B3")
    cv.line(12, h - 10, w - 12, h - 10, "B1")
    board(cv, 2, 28, w - 4, 7, "T1", 2)
    cv.hline(2, 28, w - 4, "T2")
    heaps = [("R", "A1", "A0"), ("O3", "A3", "O2"), ("M1", "M2", "P2")]
    for i in range(3):
        x = 4 + i * 34
        crate(cv, x, 12, 32, 17, "T2", i, 4)
        c, hi, lo = heaps[i]
        for k in range(14):
            hx = x + 4 + (k % 7) * 4 + (2 if k >= 7 else 0)
            hy = 9 + (0 if k >= 7 else 4) + int(hash2(k, i, 3) * 2)
            if i == 2:
                cv.ellipse(hx, hy, 3, 2.5, lo)
                cv.ellipse(hx - 0.5, hy - 0.5, 2.2, 1.6, c)
                cv.px(hx - 1, hy - 1, hi)
            else:
                cv.ellipse(hx, hy, 2.5, 2.5, lo)
                cv.ellipse(hx - 0.4, hy - 0.4, 2, 2, c)
                cv.px(hx - 1, hy - 1, hi)
                if i == 0 and k % 3 == 0:
                    cv.px(hx, hy - 3, "B1")
        cv.rect(x + 10, 22, 12, 5, "T3")
        cv.hline(x + 12, 24, 8, "B1")
    return finish(cv)


def chalkboard(w: int, h: int) -> Canvas:
    """A sandwich board on the floor: TODAY, PIE, BREAD in chalk."""
    cv = Canvas(w, h)
    for lx, ex in ((8, 4), (w - 11, w - 8)):
        cv.line(lx, 58, ex, h - 2, "B1")
        cv.line(lx + 1, 58, ex + 1, h - 2, "B3")
    cv.rect(3, 2, w - 6, 60, "B2")
    grain(cv, 3, 2, w - 6, 60, "B2", 3)
    cv.hline(3, 2, w - 6, "B3")
    cv.vline(3, 2, 60, "B3")
    cv.hline(3, 61, w - 6, "B0")
    cv.rect(7, 6, w - 14, 52, "P0")
    n = np.array([[hash2(x, y, 7) for x in range(w - 14)] for y in range(52)])
    cv.tone(np.where(n > 0.93, 0.6, 0.0).astype(np.float32), x=7, y=6)
    cx = w // 2
    say(cv, cx - say_width("TODAY") // 2, 9, "TODAY", "N")
    cv.hline(10, 18, w - 20, "G4")
    say(cv, cx - say_width("PIE") // 2, 23, "PIE", "O3")
    say(cv, cx - say_width("BREAD") // 2, 34, "BREAD", "O3")
    # a slice of pie drawn in chalk
    cv.poly([(cx - 8, 52), (cx + 8, 52), (cx + 2, 45)], "T3")
    cv.hline(cx - 8, 52, 17, "A2")
    cv.px(cx, 49, "R")
    cv.rect(9, 57, 8, 2, "N")
    return finish(cv)


# ---------------------------------------------------------------- Mountain Shop

def shop_counter(w: int, h: int) -> Canvas:
    """The Mountain Shop's counter: dark-stained, the rental ledger, a red
    rope coil, a dish of carabiners, an ice axe, and the shop's card."""
    cv = Canvas(w, h)
    top = 12
    board(cv, 2, top, w - 4, 8, "T1", 4)
    cv.hline(2, top, w - 4, "T2")
    cv.rect(2, top + 8, w - 4, 3, "B1")
    cv.hline(2, top + 10, w - 4, "K0")
    panel_front(cv, 4, top + 11, w - 8, h - top - 16, "B1", 6, 8)
    cv.rect(2, h - 5, w - 4, 4, "B0")
    # ledger
    cv.rect(18, 6, 24, 8, "N")
    cv.vline(30, 6, 8, "G3")
    for ly in (8, 10):
        cv.hline(20, ly, 8, "G3")
        cv.hline(32, ly, 8, "G3")
    cv.line(36, 7, 42, 3, "K0")
    # rope coil
    for r in (12, 9, 6):
        cv.ellipse(70, 9, r, r * 0.42, "A0")
        cv.ellipse(70, 8.5, r - 1.5, r * 0.42 - 1, "R")
    cv.ellipse(70, 9, 3, 1.3, "B1")
    for k in range(-11, 12, 3):
        cv.px(70 + k, 12, "A1")
    # a dish of carabiners
    cv.ellipse(104, 10, 12, 4, "G1")
    cv.ellipse(104, 9, 10, 2.5, "G3")
    for k, c in enumerate(("R", "W2", "O3", "P3", "G5")):
        cv.ellipse(96 + k * 4, 6 + (k % 2), 1.5, 2.5, c)
        cv.px(96 + k * 4, 6 + (k % 2), "G1")
    # ice axe leaning on the counter
    cv.line(140, 2, 146, 22, "B2")
    cv.line(141, 2, 147, 22, "B3")
    cv.rect(135, 0, 12, 3, "G4")
    cv.hline(135, 0, 12, "N")
    cv.px(134, 2, "G3")
    # the shop's card
    cv.rect(166, 4, 22, 10, "T3")
    cv.hline(166, 4, 22, "N")
    say(cv, 168, 5, "YMS", "B1")
    cv.rect(165, 13, 24, 2, "B0")
    return finish(cv)


def practice_wall(w: int, h: int) -> Canvas:
    """The practice wall: plywood panels on a timber frame, bolted with
    colored holds, chalk on the jugs, a taped route and its grade."""
    cv = Canvas(w, h)
    cv.rect(2, 2, w - 4, h - 12, "B1")
    cv.hline(2, 2, w - 4, "B3")
    cv.vline(2, 2, h - 12, "B2")
    x0, y0, x1, y1 = 8, 8, w - 8, h - 20
    cv.rect(x0, y0, x1 - x0, y1 - y0, "T2")
    # the plywood: grain swirls and a panel joint grid
    for k in range(40):
        gy = y0 + int(hash2(k, 1, 31) * (y1 - y0))
        gx = x0 + int(hash2(k, 2, 31) * (x1 - x0 - 20))
        ln = 14 + int(hash2(k, 3, 31) * 30)
        for t in range(ln):
            cv.px(gx + t, gy + int(1.5 * math.sin(t * 0.25 + k)), "T1" if k % 3 else "T3")
    d = np.zeros((y1 - y0, x1 - x0), np.float32)
    yy, xx = np.mgrid[0:y1 - y0, 0:x1 - x0]
    d += np.where(((xx + yy) % 90) < 22, 0.3, 0.0)
    cv.tone(d, x=x0, y=y0)
    for by in range(y0, y1, 48):
        cv.hline(x0, by, x1 - x0, "T0")
        cv.hline(x0, by + 1, x1 - x0, "T3")
    cv.vline((x0 + x1) // 2, y0, y1 - y0, "T0")
    cv.vline((x0 + x1) // 2 + 1, y0, y1 - y0, "T3")
    # t-nut holes
    for ty in range(y0 + 8, y1 - 4, 12):
        for tx in range(x0 + 6 + (ty // 12 % 2) * 6, x1 - 4, 12):
            cv.px(tx, ty, "T0")
    # holds
    cols = ["R", "W2", "O2", "P3", "S", "L", "N", "A1"]
    for i in range(30):
        hx = x0 + 6 + int(hash2(i, 1, 5) * (x1 - x0 - 18))
        hy = y0 + 6 + int(hash2(i, 2, 5) * (y1 - y0 - 18))
        c = cols[int(hash2(i, 3, 5) * len(cols))]
        sz = 3 + int(hash2(i, 4, 5) * 3)
        cv.ellipse(hx, hy + 1, sz + 0.5, sz * 0.7 + 0.5, "K0")
        cv.ellipse(hx, hy, sz, sz * 0.7, c)
        cv.ellipse(hx - 1, hy - 1, sz * 0.5, sz * 0.35, up(c))
        cv.px(hx, hy, down(c, 2))
        if i % 3 == 0:
            for k in range(3):
                cv.px(hx - 1 + k, hy - sz, "N")
    # the route: red tape tabs zigzagging up
    for i in range(10):
        tx = x0 + 22 + int(18 * math.sin(i * 1.3)) + i * 6
        ty = y1 - 14 - i * 15
        cv.rect(tx, ty, 6, 2, "R")
        cv.px(tx, ty, "A1")
    # the grade on a strip of tape
    cv.rect(x0 + 4, y1 - 14, 22, 11, "N")
    cv.hline(x0 + 4, y1 - 4, 22, "G4")
    say(cv, x0 + 7, y1 - 12, "5.7", "B0")
    # the kicker board and frame foot
    cv.rect(2, h - 12, w - 4, 8, "B2")
    grain(cv, 2, h - 12, w - 4, 8, "B2", 3)
    cv.hline(2, h - 12, w - 4, "B3")
    cv.hline(2, h - 5, w - 4, "B0")
    return finish(cv)


def crash_pad(w: int, h: int) -> Canvas:
    """A bouldering pad on the floor: blue nylon, quilted, a carry strap and
    the maker's gold patch."""
    cv = Canvas(w, h)
    rrect(cv, 2, 3, w - 4, h - 6, "W1", 3)
    cv.rect(4, 4, w - 8, 14, "W2")
    cv.hline(5, 4, w - 10, "W3")
    cv.hline(3, h - 5, w - 6, "W0")
    cv.rect(3, 19, w - 6, h - 24, "W1")
    for x in range(20, w - 10, 26):
        cv.vline(x, 5, h - 10, "W0")
        cv.vline(x + 1, 5, 12, "W3")
    cv.hline(3, 18, w - 6, "W0")
    for sx in (10, w - 16):
        cv.rect(sx, 3, 6, h - 6, "K1")
        cv.vline(sx, 3, h - 6, "G1")
        cv.rect(sx - 1, h - 10, 8, 4, "G2")
    cv.rect(w // 2 - 12, 8, 24, 8, "O2")
    cv.hline(w // 2 - 12, 8, 24, "O3")
    cv.frame(w // 2 - 11, 9, 22, 6, "O1")
    for k in range(4):
        cv.px(w // 2 - 7 + k * 5, 12, "O0")
    return finish(cv, "K0")


def glass_case(w: int, h: int) -> Canvas:
    """A glass-topped display case of climbing gear: a rack of cams by
    size, quickdraws and carabiners laid on felt."""
    cv = Canvas(w, h)
    cv.rect(4, 22, w - 8, h - 30, "B1")
    panel_front(cv, 4, 50, w - 8, h - 58, "B1", 4, 3)
    cv.rect(2, 20, w - 4, 4, "B2")
    cv.hline(2, 20, w - 4, "B3")
    # the felt under glass
    cv.rect(8, 24, w - 16, 26, "K1")
    cv.rect(9, 25, w - 18, 24, "W0")
    camc = ["R", "W2", "O3", "P3", "L", "A1", "S", "G4"]
    for i in range(8):
        x = 16 + i * 15
        c = camc[i]
        cv.vline(x, 29, 11, "G4")
        cv.rect(x - 3 - i // 3, 27, 7 + i // 3 * 2, 4, c)
        cv.hline(x - 3 - i // 3, 27, 7 + i // 3 * 2, up(c))
        cv.ellipse(x, 41, 2, 1.5, "G3")
    for i in range(7):
        x = 18 + i * 17
        cv.ellipse(x, 45, 2, 2.5, "G5")
        cv.ellipse(x + 8, 45, 2, 2.5, "G5")
        cv.rect(x + 2, 44, 6, 2, "R" if i % 2 else "W2")
    # glass: a frame and the window's reflection
    cv.frame(8, 24, w - 16, 26, "B0")
    d = np.zeros((24, w - 18), np.float32)
    yy, xx = np.mgrid[0:24, 0:w - 18]
    band = (xx + yy * 1.2) % 70
    d += np.where((band > 6) & (band < 12), 1.2, 0.0) + np.where((band > 16) & (band < 18), 0.8, 0.0)
    cv.tone(d, x=9, y=25)
    cv.hline(9, 25, w - 18, "W4")
    # feet
    for fx in (4, w - 12):
        cv.rect(fx, h - 8, 8, 6, "B0")
    return finish(cv)


def boot_bench(w: int, h: int) -> Canvas:
    """The fitting bench: a pair of red approach shoes and a foot-measuring
    stand on a plank seat."""
    cv = Canvas(w, h)
    for lx in (6, w - 14):
        cv.rect(lx, 22, 8, h - 24, "B1")
        cv.vline(lx, 22, h - 24, "B3")
        cv.vline(lx + 7, 22, h - 24, "B0")
    board(cv, 2, 12, w - 4, 6, "T1", 2)
    cv.hline(2, 12, w - 4, "T2")
    cv.rect(2, 18, w - 4, 4, "B2")
    cv.hline(2, 21, w - 4, "B0")
    # shoes
    for sx in (14, 32):
        rrect(cv, sx, 4, 15, 9, "R", 3)
        cv.rect(sx + 7, 1, 7, 6, "A0")
        cv.hline(sx + 1, 4, 10, "A1")
        cv.hline(sx, 12, 15, "K1")
        for k in range(3):
            cv.px(sx + 9 + k * 2, 3, "N")
    # the measuring stand
    cv.rect(58, 6, 22, 7, "G2")
    cv.hline(58, 6, 22, "G4")
    for k in range(0, 22, 3):
        cv.px(58 + k, 9, "K0")
    cv.rect(58, 1, 4, 7, "G2")
    cv.vline(58, 1, 7, "G4")
    return finish(cv)


def rope_bin(w: int, h: int) -> Canvas:
    """A slatted bin of new ropes, each coil a different color."""
    cv = Canvas(w, h)
    cv.rect(5, 24, w - 10, h - 26, "B2")
    for k, sx in enumerate(range(5, w - 6, 8)):
        grain(cv, sx, 24, 7, h - 26, "B2" if k % 2 else "B3", k, vertical=True)
        cv.vline(sx + 7, 24, h - 26, "B0")
    cv.hline(5, 24, w - 10, "T1")
    cv.hline(5, 25, w - 10, "B3")
    cv.rect(5, h - 4, w - 10, 3, "B1")
    for k, (c, hi, lo) in enumerate((("R", "A1", "A0"), ("W2", "W3", "W1"), ("O2", "O3", "O1"), ("P2", "P3", "P1"))):
        cx = 13 + k * 11
        cy = 18 + (k % 2) * 2
        cv.ellipse(cx, cy, 8, 6, lo)
        for r in (7, 5, 3):
            cv.ellipse(cx, cy - 0.5, r, r * 0.75, c)
            cv.ellipse(cx - 0.5, cy - 1, r - 1, r * 0.75 - 1, hi if r == 7 else c)
        cv.ellipse(cx, cy, 2, 1.5, "B0")
    return finish(cv)


def stool(w: int, h: int) -> Canvas:
    """A three-legged shop stool with a round seat."""
    cv = Canvas(w, h)
    cx = w // 2
    for lx, ex in ((cx - 7, 4), (cx, cx), (cx + 6, w - 5)):
        cv.line(lx, 12, ex, h - 2, "B1")
        cv.line(lx + 1, 12, ex + 1, h - 2, "B2" if lx <= cx else "B0")
    cv.hline(7, 24, w - 14, "B1")
    cv.ellipse(cx, 9, 11, 5.5, "B2")
    cv.ellipse(cx, 8, 10, 4.5, "T1")
    cv.ellipse(cx - 2, 7, 6, 2.5, "T2")
    cv.hline(cx - 9, 13, 18, "B0")
    return finish(cv)


# ---------------------------------------------------------------- the table

_P = "assets/sprites/interiors/props/"
_C = "assets/sprites/curry/interiors/"

PROPS = {
    _P + "anvil.png": anvil,
    _P + "barrels.png": barrels,
    _P + "basket.png": basket(False, 1),
    _P + "basket_big.png": basket(True, 2),
    _P + "basket_great.png": basket(True, 3),
    _P + "canisters.png": canisters,
    _P + "cooler.png": cooler,
    _P + "crates.png": crates,
    _P + "easel.png": easel("painting"),
    _P + "easel_half.png": easel("half"),
    _P + "easel_photo.png": easel("photo"),
    _P + "easel_two.png": easel("two"),
    _P + "forge.png": forge,
    _P + "hearth.png": hearth("cut"),
    _P + "hearth_lodge.png": hearth("rubble"),
    _P + "hearth_small.png": hearth("small"),
    _P + "lamp.png": lamp,
    _P + "luggage.png": luggage,
    _P + "panel.png": panel,
    _P + "plant.png": plant,
    _P + "postcards.png": postcards,
    _P + "rack.png": rack,
    _P + "relief.png": relief("valley"),
    _P + "relief_glacier.png": relief("glacier"),
    _P + "relief_high.png": relief("high"),
    _P + "relief_tuolumne.png": relief("tuolumne"),
    _P + "safe.png": safe,
    _P + "shelf.png": shelf,
    _P + "spinner.png": spinner,
    _P + "stove.png": stove,
    _P + "telescope.png": telescope,
    _P + "workbench.png": workbench,
    _C + "boot_bench.png": boot_bench,
    _C + "crash_pad.png": crash_pad,
    _C + "glass_case.png": glass_case,
    _C + "pack_rack.png": pack_rack,
    _C + "postcard_rack.png": postcards,
    _C + "practice_wall.png": practice_wall,
    _C + "produce_table.png": produce_table,
    _C + "rope_bin.png": rope_bin,
    _C + "shop_counter.png": shop_counter,
    _C + "shop_stove.png": stove,
    _C + "stool.png": stool,
    _C + "store_barrels.png": barrels,
    _C + "store_chalkboard.png": chalkboard,
    _C + "store_cooler.png": cooler,
    _C + "store_counter.png": store_counter,
    _C + "store_shelf.png": lambda w, h: shelf(w, h, 11),
    _C + "store_stove.png": stove,
    _C + "workbench.png": workbench,
}


def paint_all() -> int:
    from PIL import Image
    n = 0
    for rel, fn in PROPS.items():
        path = os.path.join(ROOT, rel)
        if not os.path.exists(path):
            print("skipped", rel, "(the builder hasn't drawn it)")
            continue
        w, h = Image.open(path).size
        cv = fn(w, h)
        assert (cv.w, cv.h) == (w, h), (rel, cv.w, cv.h, w, h)
        cv.save(path)
        n += 1
    return n


if __name__ == "__main__":
    print("painted", paint_all(), "pieces")
