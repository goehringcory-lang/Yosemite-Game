"""Drawing kit for the Ahwahnee's rooms, painted natively at 32px.

Everything is drawn straight in the Valley Days palette (tools/art32/palette.py)
on numpy RGBA canvases. Light is painted the palette way: a pixel never gets a
new color, it steps up or down a ladder of palette colors (LIGHTER / DARKER),
with a 4x4 Bayer dither where the step is partial, so soft light reads as
painted texture instead of banding.
"""
from __future__ import annotations

import math
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "art32"))
import palette as P  # noqa: E402
import pixel32 as K32  # noqa: E402


def _hex(h: str) -> tuple[int, int, int]:
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


# Named palette colors: ramp letter + step, dark to light.
_LETTER = {"granite": "G", "tan": "T", "pine": "P", "meadow": "M", "oak": "O", "bark": "B",
           "merced": "W", "amber": "A", "night": "K"}
C: dict[str, tuple[int, int, int]] = {}
for _ramp, _hexes in P.RAMPS.items():
    if _ramp == "accent":
        for _n, _h in zip(("L", "S", "R", "N"), _hexes):
            C[_n] = _hex(_h)
        continue
    for _i, _h in enumerate(_hexes):
        C[_LETTER[_ramp] + str(_i)] = _hex(_h)

# One step lighter / darker for every palette color. Mostly along its own
# ramp, carried on into a neighbouring ramp of the same hue at the ends, so
# polished bark can catch the light as tan and a granite shadow sinks to night.
_UP = {
    "B0": "B1", "B1": "B2", "B2": "B3", "B3": "T2",
    "T0": "T1", "T1": "T2", "T2": "T3", "T3": "G5",
    "G0": "G1", "G1": "G2", "G2": "G3", "G3": "G4", "G4": "G5", "G5": "N",
    "O0": "O1", "O1": "O2", "O2": "O3", "O3": "A3",
    "A0": "A1", "A1": "A2", "A2": "A3", "A3": "N",
    "P0": "P1", "P1": "P2", "P2": "P3", "P3": "M0",
    "M0": "M1", "M1": "M2", "M2": "M3", "M3": "N",
    "W0": "W1", "W1": "W2", "W2": "W3", "W3": "W4", "W4": "W5", "W5": "N",
    "L": "S", "S": "N", "R": "A1", "N": "N",
    "K0": "K1", "K1": "G1",
}
_DOWN = {
    "B0": "K0", "B1": "B0", "B2": "B1", "B3": "B2",
    "T0": "B1", "T1": "T0", "T2": "T1", "T3": "T2",
    "G0": "K0", "G1": "G0", "G2": "G1", "G3": "G2", "G4": "G3", "G5": "G4",
    "O0": "B2", "O1": "O0", "O2": "O1", "O3": "O2",
    "A0": "B2", "A1": "A0", "A2": "A1", "A3": "A2",
    "P0": "K0", "P1": "P0", "P2": "P1", "P3": "P2",
    "M0": "P3", "M1": "M0", "M2": "M1", "M3": "M2",
    "W0": "K1", "W1": "W0", "W2": "W1", "W3": "W2", "W4": "W3", "W5": "W4",
    "L": "K1", "S": "L", "R": "A0", "N": "G5",
    "K0": "K0", "K1": "K0",
}
_NAMES = list(C.keys())
_IDX = {n: P.COLORS.index(C[n]) for n in _NAMES}
UP = np.arange(len(P.COLORS), dtype=np.int32)
DOWN = np.arange(len(P.COLORS), dtype=np.int32)
for _n in _NAMES:
    UP[_IDX[_n]] = _IDX[_UP[_n]]
    DOWN[_IDX[_n]] = _IDX[_DOWN[_n]]
PAL = np.array(P.COLORS, dtype=np.uint8)

BAYER = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=np.float32) + 0.5) / 16.0


def col(c) -> tuple[int, int, int]:
    return C[c] if isinstance(c, str) else c


def up(c: str, n: int = 1) -> str:
    for _ in range(n):
        c = _UP[c]
    return c


def down(c: str, n: int = 1) -> str:
    for _ in range(n):
        c = _DOWN[c]
    return c


def hash2(x: int, y: int, s: int = 0) -> float:
    """Stable noise in [0, 1) for integer coordinates."""
    h = (x * 374761393 + y * 668265263 + s * 2246822519) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFFFF) / float(0x1000000)


def noise(h: int, w: int, cell: int, seed: int) -> np.ndarray:
    return K32._value_noise(h, w, cell, seed)


class Canvas:
    """An RGBA image to paint on, clipped at its edges."""

    def __init__(self, w: int, h: int, fill=None):
        self.w, self.h = w, h
        self.a = np.zeros((h, w, 4), dtype=np.uint8)
        if fill is not None:
            self.rect(0, 0, w, h, fill)

    # ------------------------------------------------------------ primitives

    def _clip(self, x: int, y: int, w: int, h: int):
        x0, y0 = max(0, int(x)), max(0, int(y))
        x1, y1 = min(self.w, int(x) + int(w)), min(self.h, int(y) + int(h))
        return x0, y0, x1, y1

    def px(self, x: int, y: int, c) -> None:
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            self.a[y, x, :3] = col(c)
            self.a[y, x, 3] = 255

    def rect(self, x: int, y: int, w: int, h: int, c) -> None:
        x0, y0, x1, y1 = self._clip(x, y, w, h)
        if x1 > x0 and y1 > y0:
            self.a[y0:y1, x0:x1, :3] = col(c)
            self.a[y0:y1, x0:x1, 3] = 255

    def hline(self, x: int, y: int, w: int, c) -> None:
        self.rect(x, y, w, 1, c)

    def vline(self, x: int, y: int, h: int, c) -> None:
        self.rect(x, y, 1, h, c)

    def frame(self, x: int, y: int, w: int, h: int, c) -> None:
        self.hline(x, y, w, c)
        self.hline(x, y + h - 1, w, c)
        self.vline(x, y, h, c)
        self.vline(x + w - 1, y, h, c)

    def ellipse(self, cx: float, cy: float, rx: float, ry: float, c) -> None:
        x0, y0, x1, y1 = self._clip(cx - rx - 1, cy - ry - 1, rx * 2 + 3, ry * 2 + 3)
        if x1 <= x0 or y1 <= y0:
            return
        yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
        m = ((xx + 0.5 - cx) / max(rx, 0.5)) ** 2 + ((yy + 0.5 - cy) / max(ry, 0.5)) ** 2 <= 1.0
        self.a[y0:y1, x0:x1, :3][m] = col(c)
        self.a[y0:y1, x0:x1, 3][m] = 255

    def poly(self, pts: list[tuple[float, float]], c) -> None:
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        x0, y0, x1, y1 = self._clip(min(xs), min(ys), max(xs) - min(xs) + 2, max(ys) - min(ys) + 2)
        if x1 <= x0 or y1 <= y0:
            return
        yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
        xx += 0.5
        yy += 0.5
        inside = np.zeros(xx.shape, dtype=bool)
        n = len(pts)
        for i in range(n):
            ax, ay = pts[i]
            bx, by = pts[(i + 1) % n]
            cond = ((ay > yy) != (by > yy))
            xint = (bx - ax) * (yy - ay) / ((by - ay) if by != ay else 1e-6) + ax
            inside ^= cond & (xx < xint)
        self.a[y0:y1, x0:x1, :3][inside] = col(c)
        self.a[y0:y1, x0:x1, 3][inside] = 255

    def line(self, x0: float, y0: float, x1: float, y1: float, c) -> None:
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(n):
            t = i / max(1, n - 1)
            self.px(round(x0 + (x1 - x0) * t), round(y0 + (y1 - y0) * t), c)

    def dither(self, x: int, y: int, w: int, h: int, a, b, t) -> None:
        """Fills with color a, and b where the Bayer threshold is under t (a
        number, or an array the size of the area)."""
        x0, y0, x1, y1 = self._clip(x, y, w, h)
        if x1 <= x0 or y1 <= y0:
            return
        yy, xx = np.mgrid[y0:y1, x0:x1]
        thr = BAYER[yy & 3, xx & 3]
        tt = t if np.isscalar(t) else np.asarray(t)[y0 - int(y):y1 - int(y), x0 - int(x):x1 - int(x)]
        m = thr < tt
        area = self.a[y0:y1, x0:x1]
        area[..., :3] = np.where(m[..., None], np.array(col(b), np.uint8), np.array(col(a), np.uint8))
        area[..., 3] = 255

    def ramp_fill(self, x: int, y: int, w: int, h: int, ramp: list[str], t: np.ndarray) -> None:
        """Fills with a ramp of colors: t (0..1, the area's shape) picks the
        color, dithered between neighbours."""
        x0, y0, x1, y1 = self._clip(x, y, w, h)
        if x1 <= x0 or y1 <= y0:
            return
        tt = np.asarray(t, dtype=np.float32)
        if tt.ndim == 0:
            tt = np.full((h, w), float(tt), np.float32)
        tt = tt[y0 - int(y):y1 - int(y), x0 - int(x):x1 - int(x)]
        yy, xx = np.mgrid[y0:y1, x0:x1]
        v = np.clip(tt, 0, 1) * (len(ramp) - 1)
        i = np.floor(v).astype(int)
        frac = v - i
        i = np.where(BAYER[yy & 3, xx & 3] < frac, i + 1, i)
        i = np.clip(i, 0, len(ramp) - 1)
        cols = np.array([col(r) for r in ramp], np.uint8)
        self.a[y0:y1, x0:x1, :3] = cols[i]
        self.a[y0:y1, x0:x1, 3] = 255

    def blit(self, other: "Canvas", x: int, y: int) -> None:
        x0, y0, x1, y1 = self._clip(x, y, other.w, other.h)
        if x1 <= x0 or y1 <= y0:
            return
        src = other.a[y0 - y:y1 - y, x0 - x:x1 - x]
        m = src[..., 3] >= 128
        self.a[y0:y1, x0:x1][m] = src[m]

    # ------------------------------------------------------------ light

    def tone(self, delta: np.ndarray, mask: np.ndarray | None = None, x: int = 0, y: int = 0) -> None:
        """Steps every pixel up (delta > 0) or down its light ladder, by
        delta steps, dithered on the fraction. delta covers the area at x, y."""
        d = np.asarray(delta, dtype=np.float32)
        h, w = d.shape
        x0, y0, x1, y1 = self._clip(x, y, w, h)
        if x1 <= x0 or y1 <= y0:
            return
        d = d[y0 - y:y1 - y, x0 - x:x1 - x]
        area = self.a[y0:y1, x0:x1]
        opaque = area[..., 3] >= 128
        if mask is not None:
            opaque &= np.asarray(mask)[y0 - y:y1 - y, x0 - x:x1 - x]
        yy, xx = np.mgrid[y0:y1, x0:x1]
        thr = BAYER[yy & 3, xx & 3]
        mag = np.abs(d)
        steps = np.floor(mag).astype(int) + (thr < (mag - np.floor(mag))).astype(int)
        steps = np.where(opaque, steps, 0)
        if not steps.any():
            return
        idx = K32.indices(area).astype(np.int32)
        sign = np.sign(d)
        for _ in range(int(steps.max())):
            go = steps > 0
            idx = np.where(go & (sign > 0), UP[idx], np.where(go & (sign < 0), DOWN[idx], idx))
            steps = steps - 1
        area[..., :3] = PAL[idx]

    def outline(self, c="B0") -> None:
        """A one-pixel rim just outside the silhouette (needs a free pixel
        round the drawing)."""
        op = self.a[..., 3] >= 128
        p = np.pad(op, 1)
        edge = ~op & (p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:])
        self.a[edge, :3] = col(c)
        self.a[edge, 3] = 255

    def rim(self, lit: float = 1.0, shade: float = -1.0) -> None:
        """Steps the silhouette's own edge pixels: up on the upper-left, down
        on the lower-right, so every piece reads as lit from the window side."""
        op = self.a[..., 3] >= 128
        p = np.pad(op, 1)
        top = op & (~p[:-2, 1:-1] | ~p[1:-1, :-2])
        bot = op & (~p[2:, 1:-1] | ~p[1:-1, 2:]) & ~top
        d = np.zeros(op.shape, np.float32)
        d[top] = lit
        d[bot] = shade
        self.tone(d)

    def save(self, path: str) -> None:
        a = self.a.copy()
        a[..., 3] = np.where(a[..., 3] >= 128, 255, 0)
        a[a[..., 3] == 0] = 0
        Image.fromarray(a, "RGBA").save(path, optimize=True)


# ---------------------------------------------------------------- lettering

_FONT = {
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
    "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
    "G": ["01110", "10001", "10000", "10111", "10001", "10001", "01111"],
    "H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
    "I": ["111", "010", "010", "010", "010", "010", "111"],
    "M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
    "N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
    "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
    "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
    "W": ["10001", "10001", "10001", "10101", "10101", "11011", "10001"],
    "U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
    "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
    "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    "V": ["10001", "10001", "10001", "10001", "01010", "01010", "00100"],
    "B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
    "Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
    " ": ["000", "000", "000", "000", "000", "000", "000"],
}


def text_width(s: str) -> int:
    return sum(len(_FONT[ch][0]) + 1 for ch in s) - 1


def text(cv: Canvas, x: int, y: int, s: str, c, shadow=None) -> None:
    for ch in s:
        g = _FONT[ch]
        for gy, row in enumerate(g):
            for gx, bit in enumerate(row):
                if bit == "1":
                    if shadow:
                        cv.px(x + gx + 1, y + gy + 1, shadow)
                    cv.px(x + gx, y + gy, c)
        x += len(g[0]) + 1


def smoothstep(e0: float, e1: float, x):
    t = np.clip((np.asarray(x, np.float32) - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def radial(h: int, w: int, cx: float, cy: float, rx: float, ry: float) -> np.ndarray:
    """1 at (cx, cy) falling smoothly to 0 at the ellipse rx, ry."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.sqrt(((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2)
    return 1.0 - smoothstep(0.0, 1.0, d)


__all__ = ["C", "Canvas", "BAYER", "up", "down", "hash2", "noise", "text", "text_width",
           "smoothstep", "radial", "math", "np", "ROOT"]
