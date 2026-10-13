"""Pixel-art helpers for the 32px art pass: crisp 2x enlargement, palette
mapping, and the light pass. Everything works on numpy uint8 RGBA arrays.

The light comes from the upper left (the golden-hour sun low in the
southwest, as the sprites were already shaded). A pixel on a lit rim steps
one color up its ramp, one on a shaded rim steps one down.
"""
from __future__ import annotations

import numpy as np
from PIL import Image

import palette as P

PAL = np.array(P.COLORS, dtype=np.uint8)  # (n, 3)
_LUT: np.ndarray | None = None
# palette index -> (ramp-start, ramp-end) so a step can clamp inside its ramp
_RAMP_SPAN = np.zeros((len(P.COLORS), 2), dtype=np.int32)
for _i, (_r, _s) in enumerate(P.RAMP_OF):
    _m = [k for k, (rr, _ss) in enumerate(P.RAMP_OF) if rr == _r]
    _RAMP_SPAN[_i] = (_m[0], _m[-1])
DARKEST = 0  # granite 1 .. used only for rims; night is the true shadow color
NIGHT_DARK = [i for i, (r, s) in enumerate(P.RAMP_OF) if r == "night"][0]


def load(path: str) -> np.ndarray:
    return np.array(Image.open(path).convert("RGBA"))


def save(a: np.ndarray, path: str) -> None:
    Image.fromarray(a, "RGBA").save(path, optimize=True)


def _lut() -> np.ndarray:
    """5-bit-per-channel lookup: rgb -> nearest palette index."""
    global _LUT
    if _LUT is None:
        r, g, b = np.meshgrid(np.arange(32), np.arange(32), np.arange(32), indexing="ij")
        rgb = np.stack([r, g, b], -1).reshape(-1, 3)
        rgb = (rgb * 255 // 31).astype(np.int32)
        _LUT = np.array([P.nearest(tuple(int(v) for v in c)) for c in rgb], dtype=np.uint8)
    return _LUT


def indices(a: np.ndarray) -> np.ndarray:
    """Palette index for every pixel of an RGBA array (alpha ignored)."""
    q = (a[..., :3].astype(np.int32) * 31 + 127) // 255
    return _lut()[q[..., 0] * 1024 + q[..., 1] * 32 + q[..., 2]]


def remap(a: np.ndarray, dither: float = 0.0, seed: int = 7) -> np.ndarray:
    """Map every opaque pixel onto the palette. Alpha becomes 0 or 255.

    dither > 0 adds an ordered (Bayer 4x4) bias before matching, for soft
    painted areas, so gradients become a pattern instead of banding.
    """
    src = a
    if dither > 0:
        h, w = a.shape[:2]
        bayer = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=np.float32) / 16.0 - 0.47
        tile = np.tile(bayer, (h // 4 + 1, w // 4 + 1))[:h, :w]
        rgb = a[..., :3].astype(np.float32) + (tile * dither)[..., None]
        src = a.copy()
        src[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    idx = indices(src)
    out = np.zeros_like(a)
    out[..., :3] = PAL[idx]
    out[..., 3] = np.where(a[..., 3] >= 128, 255, 0)
    return out


def scale2x(a: np.ndarray) -> np.ndarray:
    """EPX / Scale2x: doubles the size and rounds off stair-steps on
    diagonals without inventing any new colors."""
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


def nearest2x(a: np.ndarray) -> np.ndarray:
    return a.repeat(2, axis=0).repeat(2, axis=1)


def step_idx(idx: np.ndarray, delta: int) -> np.ndarray:
    lo, hi = _RAMP_SPAN[idx, 0], _RAMP_SPAN[idx, 1]
    return np.clip(idx.astype(np.int32) + delta, lo, hi).astype(np.uint8)


def light_pass(a: np.ndarray, rim_idx: tuple[int, ...] = ()) -> np.ndarray:
    """Rim light from the upper left. Opaque pixels whose upper or left
    neighbour is empty step up their ramp; ones whose lower or right
    neighbour is empty step down. The dark outline pixels are left alone.
    """
    opaque = a[..., 3] >= 128
    idx = indices(a)
    p = np.pad(opaque, 1)
    lit = opaque & (~p[:-2, 1:-1] | ~p[1:-1, :-2])
    shade = opaque & (~p[2:, 1:-1] | ~p[1:-1, 2:]) & ~lit
    is_rim = np.isin(idx, np.array(rim_idx, dtype=np.uint8)) if rim_idx else np.zeros_like(opaque)
    out = a.copy()
    for mask, d in ((lit & ~is_rim, 1), (shade & ~is_rim, -1)):
        new = step_idx(idx, d)
        out[..., :3] = np.where(mask[..., None], PAL[new], out[..., :3])
    return out


def per_cell(a: np.ndarray, cw: int, ch: int, fn) -> np.ndarray:
    """Applies fn to every cw x ch cell of a sheet separately, so nothing a
    pass adds can spill into the neighbouring frame."""
    out = a.copy()
    h, w = a.shape[:2]
    for y in range(0, h - ch + 1, ch):
        for x in range(0, w - cw + 1, cw):
            out[y:y + ch, x:x + cw] = fn(a[y:y + ch, x:x + cw])
    return out


# Darkest step of each ramp: the outline color that belongs to a neighbour.
_RAMP_DARKEST = np.array([_RAMP_SPAN[i, 0] for i in range(len(P.COLORS))], dtype=np.uint8)


def outline(a: np.ndarray) -> np.ndarray:
    """A one-pixel outline just outside the silhouette, in the darkest color
    of the ramp it borders (so a green hat gets a deep-green edge, not a
    black one). Keeps figures readable on any ground."""
    opaque = a[..., 3] >= 128
    idx = indices(a)
    p = np.pad(opaque, 1)
    pi = np.pad(idx, 1)
    out = a.copy()
    edge = ~opaque & (p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:])
    # prefer the neighbour below/right (the shaded side), then above/left
    src = np.where(p[2:, 1:-1], pi[2:, 1:-1],
          np.where(p[1:-1, 2:], pi[1:-1, 2:],
          np.where(p[:-2, 1:-1], pi[:-2, 1:-1], pi[1:-1, :-2])))
    col = PAL[_RAMP_DARKEST[src]]
    out[..., :3] = np.where(edge[..., None], col, out[..., :3])
    out[..., 3] = np.where(edge, 255, out[..., 3])
    return out


# ---------------------------------------------------------------- texture

def _hash(h: int, w: int, seed: int) -> np.ndarray:
    """Per-pixel noise in [0, 1) that doesn't depend on the image size's
    layout (the same pixel gets the same value on every build)."""
    rng = np.random.default_rng(seed)
    return rng.random((h, w), dtype=np.float32)


def _value_noise(h: int, w: int, cell: int, seed: int, wrap: int = 0) -> np.ndarray:
    """Smooth noise in [0, 1], one lattice point every `cell` pixels. With
    wrap > 0 the pattern repeats every `wrap` pixels, so tiles stay seamless."""
    rng = np.random.default_rng(seed)
    if wrap:
        gh = gw = wrap // cell
        lat = rng.random((gh, gw), dtype=np.float32)
        ys = (np.arange(h) % wrap) / cell
        xs = (np.arange(w) % wrap) / cell
        y0 = ys.astype(int)
        x0 = xs.astype(int)
        fy = (ys - y0)[:, None]
        fx = (xs - x0)[None, :]
        y1 = (y0 + 1) % gh
        x1 = (x0 + 1) % gw
    else:
        gh, gw = h // cell + 2, w // cell + 2
        lat = rng.random((gh, gw), dtype=np.float32)
        ys = np.arange(h) / cell
        xs = np.arange(w) / cell
        y0 = ys.astype(int)
        x0 = xs.astype(int)
        fy = (ys - y0)[:, None]
        fx = (xs - x0)[None, :]
        y1, x1 = y0 + 1, x0 + 1
    fy = fy * fy * (3 - 2 * fy)
    fx = fx * fx * (3 - 2 * fx)
    a = lat[y0][:, x0] * (1 - fx) + lat[y0][:, x1] * fx
    b = lat[y1][:, x0] * (1 - fx) + lat[y1][:, x1] * fx
    return (a * (1 - fy) + b * fy).astype(np.float32)


def _ramp_ids(*names: str) -> np.ndarray:
    return np.array([i for i, (r, _s) in enumerate(P.RAMP_OF) if r in names], dtype=np.uint8)


def paint_texture(a: np.ndarray, seed: int = 1, wrap: int = 0) -> np.ndarray:
    """Turns flat palette bands into painted ground: soft blotches that
    step a color up or down its own ramp, scattered flecks lit from the upper
    left, grass tufts, and glints on water. Only ever moves along a ramp, so
    the palette (and each material's hue) is kept."""
    h, w = a.shape[:2]
    idx = indices(a).astype(np.int32)
    opaque = a[..., 3] >= 128
    n_big = _value_noise(h, w, 24 if not wrap else 16, seed, wrap)
    n_mid = _value_noise(h, w, 8, seed + 1, wrap)
    n = 0.6 * n_big + 0.4 * n_mid
    rnd = _hash(h, w, seed + 2) if not wrap else _tile_hash(h, w, wrap, seed + 2)
    grass = np.isin(idx, _ramp_ids("pine", "meadow"))
    rock = np.isin(idx, _ramp_ids("granite"))
    soil = np.isin(idx, _ramp_ids("tan", "bark", "oak"))
    water = np.isin(idx, _ramp_ids("merced"))
    delta = np.zeros((h, w), dtype=np.int32)
    # soft blotches
    delta += np.where(grass & (n > 0.62), 1, 0) - np.where(grass & (n < 0.34), 1, 0)
    delta += np.where(soil & (n > 0.66), 1, 0) - np.where(soil & (n < 0.32), 1, 0)
    delta += np.where(rock & (n > 0.7), 1, 0) - np.where(rock & (n < 0.28), 1, 0)
    # flecks: a light pixel with a shadow pixel down-right of it
    fleck = rnd < 0.018
    delta += np.where(fleck & (grass | soil | rock), 1, 0)
    shadow = np.zeros_like(fleck)
    shadow[1:, 1:] = fleck[:-1, :-1]
    delta -= np.where(shadow & (grass | soil | rock) & ~fleck, 1, 0)
    # grass tufts: two-pixel blades, the left one lit
    tuft = (rnd > 0.99) & grass
    delta += np.where(tuft, 2, 0)
    right = np.zeros_like(tuft)
    right[:, 1:] = tuft[:, :-1]
    delta += np.where(right & grass & ~tuft, 1, 0)
    # water glints: short horizontal runs
    glint = (rnd < 0.012) & water
    for dx in (0, 1, 2):
        sh = np.zeros_like(glint)
        sh[:, dx:] = glint[:, :w - dx] if dx else glint
        delta += np.where(sh & water, 1, 0)
    delta = np.clip(delta, -1, 2)
    out = a.copy()
    new = step_idx(idx.astype(np.uint8), 0)
    for d in (-1, 1, 2):
        m = (delta == d) & opaque
        if m.any():
            out[..., :3] = np.where(m[..., None], PAL[step_idx(idx.astype(np.uint8), d)], out[..., :3])
    return out


def _tile_hash(h: int, w: int, wrap: int, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    base = rng.random((wrap, wrap), dtype=np.float32)
    return np.tile(base, (h // wrap + 1, w // wrap + 1))[:h, :w]


def form_light(a: np.ndarray, rims: tuple[int, ...] = (), lo: float = 0.22, hi: float = 0.78) -> np.ndarray:
    """One light for the whole game, from the upper left: across each sprite
    the top-left pixels step up their ramp and the bottom-right ones step
    down, with a Bayer dither on the border so it reads as painted light
    rather than a gradient. Outline colors (darkest steps) are left alone."""
    h, w = a.shape[:2]
    opaque = a[..., 3] >= 128
    ys, xs = np.nonzero(opaque)
    if len(ys) < 40:
        return a
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    t = (0.5 * (xx - x0) / max(1, x1 - x0) + 0.5 * (yy - y0) / max(1, y1 - y0))
    bayer = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=np.float32) / 16.0 - 0.5
    t = t + np.tile(bayer, (h // 4 + 1, w // 4 + 1))[:h, :w] * 0.12
    idx = indices(a)
    keep = np.isin(idx, np.array(rims, dtype=np.uint8)) if rims else np.zeros_like(opaque)
    out = a.copy()
    for mask, d in ((opaque & ~keep & (t < lo), 1), (opaque & ~keep & (t > hi), -1)):
        out[..., :3] = np.where(mask[..., None], PAL[step_idx(idx, d)], out[..., :3])
    return out
