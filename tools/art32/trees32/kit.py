"""Drawing kit for the native 32px trees.

A tree is painted on art pixels (half the sprite's size, the two-pixel grain of
every sprite in the game) and doubled with Scale2x at the end, as the ground is.
Nothing is painted as a colour straight away: every pixel gets a material (a
colour ramp: needles, bark, fissure...) and a shade from 0 (deepest shadow) to
1 (full sun), and only `render` turns shades into ramp steps, with a narrow
ordered-dither seam where one step gives way to the next. So the light on each
material falls into a few clean bands, the way a pixel artist would shade it.

The light is the game's one light: from the upper left, a little toward the
viewer (the golden-hour sun low in the southwest).
"""
from __future__ import annotations

import math

import numpy as np

# The trunk's foot: this many art pixels above the bottom edge, where the
# 16px-era sprites stood (the scenes' offsets and collision assume it).
FOOT = 4.0
LIGHT = np.array([-0.56, -0.66, 0.5], dtype=np.float32)
LIGHT /= np.linalg.norm(LIGHT)
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=np.float32) / 16.0


def rgb(h: str) -> tuple[int, int, int]:
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


class Art:
    """An art-pixel canvas of materials and shades. [param ramps] maps each
    material name to its colours, dark to light."""

    def __init__(self, w: int, h: int, ramps: dict[str, list[str]], seed: int) -> None:
        self.w, self.h = w, h
        self.names = list(ramps)
        self.ramps = [np.array([rgb(c) for c in ramps[n]], dtype=np.uint8) for n in self.names]
        self.mat = np.full((h, w), -1, np.int16)
        self.val = np.zeros((h, w), np.float32)
        # the y of the surface normal where foliage was painted (-1 faces up),
        # for snow to settle on
        self.up = np.zeros((h, w), np.float32)
        self.rng = np.random.default_rng(seed)
        self.Y, self.X = np.mgrid[0:h, 0:w].astype(np.float32)
        # per-material dither strength (fraction of a ramp step)
        self.dither = {n: 0.32 for n in self.names}

    def m(self, name: str) -> int:
        return self.names.index(name)

    # ------------------------------------------------------------ painting

    def put(self, mask: np.ndarray, mat: str, val) -> None:
        if not mask.any():
            return
        self.mat[mask] = self.m(mat)
        if isinstance(val, np.ndarray):
            self.val[mask] = val[mask]
        else:
            self.val[mask] = val

    def shade(self, mask: np.ndarray, delta) -> None:
        """Moves the shade of what is already painted under [param mask]."""
        m = mask & (self.mat >= 0)
        if isinstance(delta, np.ndarray):
            self.val[m] += delta[m]
        else:
            self.val[m] += delta

    def recolor(self, mask: np.ndarray, mat: str) -> None:
        m = mask & (self.mat >= 0)
        self.mat[m] = self.m(mat)

    # ------------------------------------------------------------ shapes

    def ellipse(self, cx: float, cy: float, rx: float, ry: float) -> np.ndarray:
        return ((self.X + 0.5 - cx) / rx) ** 2 + ((self.Y + 0.5 - cy) / ry) ** 2 <= 1.0

    def capsule(self, x0: float, y0: float, x1: float, y1: float, r0: float, r1: float | None = None) -> tuple[np.ndarray, np.ndarray]:
        """A stroke from (x0, y0) to (x1, y1), r0 thick at the start and r1 at
        the end (half widths). Returns the mask and, for every pixel, how far
        along the stroke it lies (0..1) and the x and y of the surface normal
        there, as if the stroke were a round rod (for shading)."""
        if r1 is None:
            r1 = r0
        px, py = self.X + 0.5 - x0, self.Y + 0.5 - y0
        dx, dy = x1 - x0, y1 - y0
        ll = dx * dx + dy * dy
        t = np.clip((px * dx + py * dy) / ll, 0.0, 1.0) if ll > 0 else np.zeros_like(px)
        cxp, cyp = px - t * dx, py - t * dy
        r = r0 + (r1 - r0) * t
        d = np.sqrt(cxp * cxp + cyp * cyp)
        mask = d <= r
        # the surface normal of the stroke as a round rod: from its axis out
        # to the pixel, in half widths
        nx = cxp / np.maximum(r, 0.01)
        ny = cyp / np.maximum(r, 0.01)
        return mask, np.stack([t, np.clip(nx, -1, 1), np.clip(ny, -1, 1)])

    def polyline(self, pts: list[tuple[float, float]], r0: float, r1: float) -> tuple[np.ndarray, np.ndarray]:
        """A tapering stroke through [param pts]: the union of its segments,
        with t running 0..1 over the whole length."""
        lens = [math.dist(pts[i], pts[i + 1]) for i in range(len(pts) - 1)]
        total = sum(lens) or 1.0
        mask = np.zeros((self.h, self.w), bool)
        tt = np.zeros((self.h, self.w), np.float32)
        nx = np.zeros((self.h, self.w), np.float32)
        ny = np.zeros((self.h, self.w), np.float32)
        best = np.full((self.h, self.w), 1e9, np.float32)
        run = 0.0
        for i, ln in enumerate(lens):
            ta, tb = run / total, (run + ln) / total
            ra, rb = r0 + (r1 - r0) * ta, r0 + (r1 - r0) * tb
            m, info = self.capsule(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], ra, rb)
            d = info[1] ** 2 + info[2] ** 2
            take = m & (d < best)
            tt[take] = ta + (tb - ta) * info[0][take]
            nx[take] = info[1][take]
            ny[take] = info[2][take]
            best[take] = d[take]
            mask |= m
            run += ln
        return mask, np.stack([tt, nx, ny])

    def blob(self, cx: float, cy: float, r: float, spikes: int, spike: float, seed: int, squash: float = 1.0) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
        """A ragged round clump: radius r, its rim broken into [param spikes]
        points that reach out by up to [param spike] of r (needle tips, leaf
        edges). Returns the mask and the normal's x and y over it."""
        rng = np.random.default_rng(seed)
        x0, x1 = int(max(0, cx - r * 1.6 - 1)), int(min(self.w, cx + r * 1.6 + 2))
        y0, y1 = int(max(0, cy - r * 1.6 * squash - 1)), int(min(self.h, cy + r * 1.6 * squash + 2))
        mask = np.zeros((self.h, self.w), bool)
        nx = np.zeros((self.h, self.w), np.float32)
        ny = np.zeros((self.h, self.w), np.float32)
        if x1 <= x0 or y1 <= y0:
            return mask, nx, ny
        X = self.X[y0:y1, x0:x1] + 0.5 - cx
        Y = (self.Y[y0:y1, x0:x1] + 0.5 - cy) / squash
        ang = np.arctan2(Y, X)
        d = np.sqrt(X * X + Y * Y)
        k = max(3, spikes)
        phase = rng.random() * 6.283
        amp = rng.random(k) * spike
        # a spike at each of k angles, sharpened
        a = (ang + phase) / 6.283 * k
        i0 = np.floor(a).astype(int) % k
        f = a - np.floor(a)
        tri = 1.0 - np.abs(f - 0.5) * 2.0
        rim = r * (1.0 - spike * 0.35 + amp[i0] * tri ** 2.2)
        inside = d <= rim
        mask[y0:y1, x0:x1] = inside
        nx[y0:y1, x0:x1] = np.clip(X / np.maximum(rim, 0.5), -1, 1)
        ny[y0:y1, x0:x1] = np.clip(Y / np.maximum(rim, 0.5), -1, 1)
        return mask, nx, ny

    # ------------------------------------------------------------ light

    @staticmethod
    def diffuse(nx: np.ndarray, ny: np.ndarray, nz: np.ndarray | None = None) -> np.ndarray:
        """Lambert light for a normal (screen x right, y down, z to the viewer),
        0..1."""
        if nz is None:
            nz = np.sqrt(np.clip(1.0 - nx * nx - ny * ny, 0.0, 1.0))
        return np.clip(nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2], 0.0, 1.0)

    # ------------------------------------------------------------ output

    def render(self, outline: bool = True, outline_mats: dict[str, str] | None = None) -> np.ndarray:
        """Turns shades into colours: each material's ramp, with an ordered
        dither seam between steps, and an outline one pixel outside the shape
        in the darkest colour of the material it borders."""
        h, w = self.h, self.w
        out = np.zeros((h, w, 4), np.uint8)
        bay = np.tile(BAYER, (h // 4 + 1, w // 4 + 1))[:h, :w] - 0.47
        for i, name in enumerate(self.names):
            m = self.mat == i
            if not m.any():
                continue
            ramp = self.ramps[i]
            n = len(ramp)
            v = np.clip(self.val, 0.0, 1.0) * (n - 1) + bay * self.dither[name]
            idx = np.clip(np.floor(v + 0.5), 0, n - 1).astype(int)
            out[m, :3] = ramp[idx[m]]
            out[m, 3] = 255
        if outline:
            opaque = self.mat >= 0
            p = np.pad(opaque, 1)
            pm = np.pad(self.mat, 1, constant_values=-1)
            edge = ~opaque & (p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:])
            # prefer the neighbour below / right (the shaded side)
            src = np.where(p[:-2, 1:-1], pm[:-2, 1:-1], -1)
            src = np.where(p[1:-1, :-2], pm[1:-1, :-2], src)
            src = np.where(p[1:-1, 2:], pm[1:-1, 2:], src)
            src = np.where(p[2:, 1:-1], pm[2:, 1:-1], src)
            for i, name in enumerate(self.names):
                e = edge & (src == i)
                if not e.any():
                    continue
                target = outline_mats.get(name, name) if outline_mats else name
                out[e, :3] = self.ramps[self.m(target)][0]
                out[e, 3] = 255
        return out


def scale2x(a: np.ndarray) -> np.ndarray:
    """EPX / Scale2x, as the rest of the game's art was doubled."""
    h, w = a.shape[:2]
    p = np.pad(a, ((1, 1), (1, 1), (0, 0)), mode="edge")
    c = p[1:-1, 1:-1]
    up, down = p[:-2, 1:-1], p[2:, 1:-1]
    left, right = p[1:-1, :-2], p[1:-1, 2:]

    def eq(x: np.ndarray, y: np.ndarray) -> np.ndarray:
        return np.all(x == y, axis=-1)

    ul, ur, dl, dr = c.copy(), c.copy(), c.copy(), c.copy()
    m = eq(left, up) & ~eq(left, down) & ~eq(up, right)
    ul[m] = up[m]
    m = eq(up, right) & ~eq(up, left) & ~eq(right, down)
    ur[m] = right[m]
    m = eq(down, left) & ~eq(down, right) & ~eq(left, up)
    dl[m] = left[m]
    m = eq(right, down) & ~eq(right, up) & ~eq(down, left)
    dr[m] = down[m]
    out = np.zeros((h * 2, w * 2, 4), dtype=np.uint8)
    out[0::2, 0::2], out[0::2, 1::2], out[1::2, 0::2], out[1::2, 1::2] = ul, ur, dl, dr
    return out


def voronoi(w: int, h: int, cell_w: float, cell_h: float, seed: int, jitter: float = 0.8, warp: float = 0.0) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Cells of a jittered grid (bark plates, granite blocks): for every pixel,
    the cell it is in, the distance to the cell's edge (in pixels, roughly) and
    the cell's random value 0..1."""
    rng = np.random.default_rng(seed)
    gw, gh = int(w / cell_w) + 3, int(h / cell_h) + 3
    sx = (np.arange(gw)[None, :] - 1 + 0.5 + (rng.random((gh, gw)) - 0.5) * jitter) * cell_w
    sy = (np.arange(gh)[:, None] - 1 + 0.5 + (rng.random((gh, gw)) - 0.5) * jitter) * cell_h
    sx = sx.ravel()
    sy = sy.ravel()
    rv = rng.random(sx.size)
    Y, X = np.mgrid[0:h, 0:w].astype(np.float32)
    X += 0.5
    Y += 0.5
    if warp:
        # wobble the cells so their edges wander like real plates and joints
        X = X + (value_noise(w, h, max(2.0, cell_w * 0.8), seed + 7) - 0.5) * warp * cell_w
        Y = Y + (value_noise(w, h, max(2.0, cell_h * 0.6), seed + 8) - 0.5) * warp * cell_h
    # anisotropic distance: plates are taller than wide
    ax = 1.0 / cell_w
    ay = 1.0 / cell_h
    d1 = np.full((h, w), 1e9, np.float32)
    d2 = np.full((h, w), 1e9, np.float32)
    idx = np.zeros((h, w), np.int32)
    for k in range(sx.size):
        d = ((X - sx[k]) * ax) ** 2 + ((Y - sy[k]) * ay) ** 2
        closer = d < d1
        d2 = np.where(closer, d1, np.minimum(d2, d))
        idx = np.where(closer, k, idx)
        d1 = np.where(closer, d, d1)
    edge = (np.sqrt(d2) - np.sqrt(d1)) * min(cell_w, cell_h) * 0.5
    return idx, edge, rv[idx]


def value_noise(w: int, h: int, cell: float, seed: int) -> np.ndarray:
    """Smooth noise 0..1 with one lattice point every [param cell] pixels."""
    rng = np.random.default_rng(seed)
    gh, gw = int(h / cell) + 3, int(w / cell) + 3
    lat = rng.random((gh, gw)).astype(np.float32)
    ys = np.arange(h) / cell
    xs = np.arange(w) / cell
    y0 = ys.astype(int)
    x0 = xs.astype(int)
    fy = ys - y0
    fx = xs - x0
    fy = (fy * fy * (3 - 2 * fy))[:, None]
    fx = (fx * fx * (3 - 2 * fx))[None, :]
    a = lat[y0][:, x0] * (1 - fx) + lat[y0][:, x0 + 1] * fx
    b = lat[y0 + 1][:, x0] * (1 - fx) + lat[y0 + 1][:, x0 + 1] * fx
    return (a * (1 - fy) + b * fy).astype(np.float32)
