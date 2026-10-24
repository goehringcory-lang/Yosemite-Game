"""Numpy building blocks for the native 32px ground painter: smooth noise,
blurs, Voronoi cells, ordered dither and vectorized stamps.

Everything is deterministic from a seed, so a repaint gives the same picture.
"""
from __future__ import annotations

import numpy as np
from PIL import Image

BAYER4 = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], np.float32) + 0.5) / 16.0


def rng(seed: int) -> np.random.Generator:
    return np.random.default_rng(seed & 0x7FFFFFFF)


def hash2(x: np.ndarray, y: np.ndarray, s: int = 0) -> np.ndarray:
    """A float in [0, 1) per integer coordinate pair, stable across runs."""
    v = (x.astype(np.int64) * 374761393 + y.astype(np.int64) * 668265263 + s * 2147483647) & 0x7FFFFFFF
    v = ((v ^ (v >> 13)) * 1274126177) & 0x7FFFFFFF
    v = v ^ (v >> 16)
    return (v & 0xFFFF).astype(np.float32) / 65536.0


def value_noise(h: int, w: int, cell: float, seed: int) -> np.ndarray:
    """Smooth noise in [0, 1] with features about [param cell] pixels across."""
    gh = int(h / cell) + 3
    gw = int(w / cell) + 3
    grid = rng(seed).random((gh, gw), dtype=np.float32)
    im = Image.fromarray(grid, mode="F").resize((int(gw * cell), int(gh * cell)), Image.BICUBIC)
    a = np.asarray(im, dtype=np.float32)[:h, :w]
    lo, hi = np.percentile(a, 1), np.percentile(a, 99)
    return np.clip((a - lo) / max(hi - lo, 1e-6), 0.0, 1.0)


def fbm(h: int, w: int, cell: float, seed: int, octaves: int = 3) -> np.ndarray:
    out = np.zeros((h, w), np.float32)
    amp = 1.0
    total = 0.0
    for o in range(octaves):
        out += value_noise(h, w, max(cell / (2 ** o), 2.0), seed + o * 101) * amp
        total += amp
        amp *= 0.5
    return out / total


def box_blur(a: np.ndarray, r: int) -> np.ndarray:
    """A box blur of radius r (edges clamped), by running sums."""
    if r <= 0:
        return a.astype(np.float32)
    out = a.astype(np.float32)
    for axis in (0, 1):
        pad = [(0, 0), (0, 0)]
        pad[axis] = (r + 1, r)
        p = np.pad(out, pad, mode="edge")
        c = np.cumsum(p, axis=axis, dtype=np.float64)
        n = out.shape[axis]
        if axis == 0:
            out = ((c[2 * r + 1:2 * r + 1 + n] - c[:n]) / (2 * r + 1)).astype(np.float32)
        else:
            out = ((c[:, 2 * r + 1:2 * r + 1 + n] - c[:, :n]) / (2 * r + 1)).astype(np.float32)
    return out


def blur(a: np.ndarray, r: int) -> np.ndarray:
    """Three box passes: close to a gaussian of sigma ~ r."""
    for _ in range(3):
        a = box_blur(a, max(1, r // 2))
    return a


def upsample(grid: np.ndarray, t: int) -> np.ndarray:
    return np.repeat(np.repeat(grid, t, axis=0), t, axis=1)


def voronoi(h: int, w: int, cell: int, seed: int):
    """Jittered-grid Voronoi: (cell id, distance to nearest point, distance
    gap to the second nearest, offset x/y from the nearest point)."""
    gh = h // cell + 2
    gw = w // cell + 2
    r = rng(seed)
    jx = r.random((gh, gw), dtype=np.float32) * 0.8 + 0.1
    jy = r.random((gh, gw), dtype=np.float32) * 0.8 + 0.1
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    cx = (xx // cell).astype(np.int32)
    cy = (yy // cell).astype(np.int32)
    best = np.full((h, w), 1e9, np.float32)
    second = np.full((h, w), 1e9, np.float32)
    bid = np.zeros((h, w), np.int32)
    bdx = np.zeros((h, w), np.float32)
    bdy = np.zeros((h, w), np.float32)
    for oy in (-1, 0, 1):
        for ox in (-1, 0, 1):
            gx = np.clip(cx + ox, 0, gw - 1)
            gy = np.clip(cy + oy, 0, gh - 1)
            px = (gx + jx[gy, gx]) * cell
            py = (gy + jy[gy, gx]) * cell
            dx = xx - px
            dy = yy - py
            d = np.sqrt(dx * dx + dy * dy)
            closer = d < best
            second = np.where(closer, best, np.minimum(second, d))
            best = np.where(closer, d, best)
            bid = np.where(closer, gy * gw + gx, bid)
            bdx = np.where(closer, dx, bdx)
            bdy = np.where(closer, dy, bdy)
    return bid, best, second - best, bdx, bdy


def bayer(h: int, w: int) -> np.ndarray:
    return np.tile(BAYER4, (h // 4 + 1, w // 4 + 1))[:h, :w]


class Stamp:
    """A little pattern of tone steps (or palette colors) placed many times.

    [param rows] are strings; each character maps through [param key] to a
    tone step (int) or a color (hex string). '.' is empty. The anchor is the
    bottom-middle pixel, so tufts grow up from where they stand.
    """

    def __init__(self, rows: list[str], key: dict):
        self.cells: list[tuple[int, int, object]] = []
        hgt = len(rows)
        wid = max(len(r) for r in rows)
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch != "." and ch != " ":
                    self.cells.append((x - wid // 2, y - (hgt - 1), key[ch]))


def scatter(h: int, w: int, cell: int, density: np.ndarray | float, seed: int, mask: np.ndarray):
    """Positions on a jittered grid: one candidate per cell, kept where the
    mask is set and with probability [param density] (a float or a per-pixel
    array). Returns (ys, xs, a per-point random in [0, 1))."""
    gy, gx = np.mgrid[0:h // cell + 1, 0:w // cell + 1]
    gy = gy.ravel()
    gx = gx.ravel()
    xs = gx * cell + (hash2(gx, gy, seed) * cell).astype(np.int64)
    ys = gy * cell + (hash2(gx, gy, seed + 1) * cell).astype(np.int64)
    keep = (xs < w) & (ys < h)
    xs, ys, gx, gy = xs[keep], ys[keep], gx[keep], gy[keep]
    keep = mask[ys, xs]
    xs, ys, gx, gy = xs[keep], ys[keep], gx[keep], gy[keep]
    roll = hash2(gx, gy, seed + 2)
    d = density[ys, xs] if isinstance(density, np.ndarray) else density
    keep = roll < d
    return ys[keep], xs[keep], hash2(gx[keep], gy[keep], seed + 3)


def apply_tone(tone: np.ndarray, mask: np.ndarray, ys, xs, stamp: Stamp) -> None:
    """Adds a stamp's tone steps at each point, only on pixels of the mask."""
    h, w = tone.shape
    for dx, dy, v in stamp.cells:
        if not isinstance(v, (int, float)):
            continue
        y = ys + dy
        x = xs + dx
        ok = (y >= 0) & (y < h) & (x >= 0) & (x < w)
        y, x = y[ok], x[ok]
        ok = mask[y, x]
        tone[y[ok], x[ok]] += v


def apply_color(rgb: np.ndarray, mask: np.ndarray, ys, xs, stamp: Stamp, colors: dict) -> None:
    """Paints a stamp's palette colors at each point, only on the mask."""
    h, w = mask.shape
    for dx, dy, v in stamp.cells:
        if isinstance(v, (int, float)):
            continue
        y = ys + dy
        x = xs + dx
        ok = (y >= 0) & (y < h) & (x >= 0) & (x < w)
        y, x = y[ok], x[ok]
        ok = mask[y, x]
        rgb[y[ok], x[ok]] = colors[v]


def hexrgb(h: str) -> np.ndarray:
    return np.array([int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)], np.uint8)
