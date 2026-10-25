"""Looks at real terrain from the Valley floor, for the cliff paintings.

Each column of a picture is a line of sight across the DEM and each row a
slope of that line, so every pixel knows the real point of rock (or forest
beyond the rim) it shows, how far off it is, and which way the ground there
faces. Two ways of setting the columns up:

- walk(): the columns run side by side, square to the wall, as if the picture
  were taken walking along the Valley floor, the eye always the same distance
  out from the foot of the wall. A long wall stays the same scale end to end
  (El Capitan, Cathedral Rocks, the Three Brothers).
- camera(): every column from one eye, fanned out in azimuth: a true
  panorama, for a view up a canyon or from a rim.

Rows are a true perspective in both: a row is a sight line rising at the
slope that meets the picture's height for it [param d0] metres out, so the
ground behind a rim sinks out of sight as it does from below, and a nearer
buttress stands up in front of the face behind it.
"""
from __future__ import annotations

import math
from dataclasses import dataclass

import numpy as np

from dem import DEM

EARTH_R = 6371000.0
REFRACTION = 0.13  # the usual allowance: air bends sight lines a little round the earth


@dataclass
class View:
    """What each pixel of the picture looks at."""
    hit: np.ndarray  # (H, W) bool: the sight line met the ground
    e: np.ndarray  # (H, W) UTM easting of the point seen
    n: np.ndarray  # (H, W) northing
    z: np.ndarray  # (H, W) its height
    dist: np.ndarray  # (H, W) metres from the eye
    nx: np.ndarray  # (H, W) surface normal across the picture (+ right)
    ny: np.ndarray  # (H, W) up (+ up)
    nz: np.ndarray  # (H, W) toward the viewer
    slope: np.ndarray  # (H, W) degrees from level
    eye_z: np.ndarray  # (W,) the eye's height, per column
    scale_v: np.ndarray  # (W,) metres of height per row at d0, per column

    FIELDS = ("hit", "e", "n", "z", "dist", "nx", "ny", "nz", "slope")

    def take(self, other: "View", mask: np.ndarray) -> None:
        """Copies [param other]'s pixels where [param mask] (H, W) is set:
        for joining views."""
        for name in self.FIELDS:
            getattr(self, name)[mask] = getattr(other, name)[mask]
        cols = mask.any(axis=0)
        self.eye_z[cols] = other.eye_z[cols]
        self.scale_v[cols] = other.scale_v[cols]


def _march(dem: DEM, oe: np.ndarray, on: np.ndarray, de: np.ndarray, dn: np.ndarray, ts: np.ndarray,
           eyes: np.ndarray, tan_rows: np.ndarray, near: float, curve: bool, right: np.ndarray, fwd: np.ndarray,
           scale_v: np.ndarray) -> View:
    """Casts every column's sight line: from (oe, on) along (de, dn) at
    distances [param ts], the eye at [param eyes], each row at the slope in
    [param tan_rows] (W, H). Ground nearer than [param near] is not looked at
    (a bank at your feet would hide the whole wall, and the trees would hide
    it from you anyway). [param right] and [param fwd] (W, 2) are each
    column's picture axes in the world, for the normals."""
    W, H = tan_rows.shape
    E = oe[:, None] + ts[None, :] * de[:, None]
    N = on[:, None] + ts[None, :] * dn[:, None]
    prof = dem.sample(E, N)
    if curve:
        prof = prof - (ts * ts / (2.0 * EARTH_R) * (1.0 - REFRACTION))[None, :]
    dt = np.maximum(ts, 1e-3)[None, :]
    near_c = np.broadcast_to(np.asarray(near, np.float32), (W,))[:, None]
    tan_all = np.where(ts[None, :] > near_c, (prof - eyes[:, None]) / dt, -1e3)
    ang = np.maximum.accumulate(tan_all, axis=1)
    idx = np.empty((W, H), np.int64)
    for c in range(W):
        idx[c] = np.searchsorted(ang[c], tan_rows[c], side="left")
    hit = idx < len(ts)
    idx = np.minimum(idx, len(ts) - 1)
    cols = np.arange(W)[:, None]
    # refine to where the ground rises through the sight line z = eye + t tan
    i1 = idx
    i0 = np.maximum(idx - 1, 0)
    t0, t1 = ts[i0], ts[i1]
    g0 = prof[cols, i0] - (eyes[:, None] + t0 * tan_rows)
    g1 = prof[cols, i1] - (eyes[:, None] + t1 * tan_rows)
    frac = np.where(np.abs(g1 - g0) > 1e-4, np.clip(-g0 / (g1 - g0 + 1e-9), 0, 1), 0.0)
    t = t0 + (t1 - t0) * frac
    he = oe[:, None] + t * de[:, None]
    hn = on[:, None] + t * dn[:, None]
    hz = dem.sample(he, hn)
    gx = dem.sample(he, hn, dem.dzde)
    gy = dem.sample(he, hn, dem.dzdn)
    # surface normal in the world (east, north, up), then in the picture's axes
    nw_e, nw_n, nw_u = -gx, -gy, np.ones_like(gx)
    ln = np.sqrt(nw_e * nw_e + nw_n * nw_n + nw_u * nw_u)
    nw_e, nw_n, nw_u = nw_e / ln, nw_n / ln, nw_u / ln
    nx = nw_e * right[:, 0:1] + nw_n * right[:, 1:2]
    nz = -(nw_e * fwd[:, 0:1] + nw_n * fwd[:, 1:2])
    slope = np.degrees(np.arctan(np.hypot(gx, gy)))
    T = lambda a: np.ascontiguousarray(a.T).astype(np.float32)  # noqa: E731
    return View(hit.T.copy(), T(he), T(hn), T(hz), T(t), T(nx), T(nw_u), T(nz), T(slope), eyes.astype(np.float32),
                scale_v.astype(np.float32))


def _rows(H: int, eyes: np.ndarray, base_z: float, base_row: np.ndarray, scale_v: np.ndarray, d0: float) -> np.ndarray:
    """Each row's sight-line slope, per column: row base_row[c] meets base_z
    d0 metres out, and each row up adds scale_v[c] metres there."""
    rows = np.arange(H, dtype=np.float32) + 0.5
    rz = base_z + (base_row[:, None] - rows[None, :]) * scale_v[:, None]
    return ((rz - eyes[:, None]) / d0).astype(np.float32)


def _fit_scale(skies: list[tuple[float, float, float]], eyes: np.ndarray, base_z: float, base_row: np.ndarray,
               d0: float) -> np.ndarray:
    """The scale_v per column that stands the skyline [param pad] rows below
    the top at each control point (column, skyline slope, pad), and changes
    smoothly between them."""
    W = len(base_row)
    cs = np.array([s[0] for s in skies], np.float32)
    tops = np.array([float(np.median(eyes)) + s[1] * d0 for s in skies], np.float32)
    pads = np.array([s[2] for s in skies], np.float32)
    order = np.argsort(cs)
    cols = np.arange(W, dtype=np.float32) + 0.5
    top = np.interp(cols, cs[order], tops[order])
    pad = np.interp(cols, cs[order], pads[order])
    return ((top - base_z) / np.maximum(base_row - pad, 1.0)).astype(np.float32)


def _fits(dem: DEM, oe, on, de, dn, ts, eyes, near, curve: bool, fit, W: int) -> list[tuple[float, float, float]]:
    """The skyline at each fit window: [(first col, last col, rows), ...]."""
    out = []
    for c0, c1, rows_pad in fit:
        c0, c1 = max(0, int(c0)), min(W, int(c1))
        if c1 <= c0:
            continue
        sky = _skyline(dem, oe, on, de, dn, ts, eyes, near, curve, range(c0, c1, 3))
        out.append(((c0 + c1) / 2.0, sky, rows_pad))
    return out


def _skyline(dem: DEM, oe, on, de, dn, ts, eyes, near, curve: bool, cols) -> float:
    sky = -1e3
    nears = np.broadcast_to(np.asarray(near, np.float32), (len(oe),))
    for c in cols:
        pe = dem.sample(oe[c] + ts * de[c], on[c] + ts * dn[c])
        if curve:
            pe = pe - ts * ts / (2.0 * EARTH_R) * (1.0 - REFRACTION)
        tt = np.where(ts > nears[c], (pe - eyes[c]) / np.maximum(ts, 1e-3), -1e3)
        sky = max(sky, float(tt.max()))
    return sky


def walk(dem: DEM, *, e: float, n: float, azimuth: float, W: int, H: int, cx: float, scale_h: float,
         base_z: float, base_row: np.ndarray, eye: float, d0: float, fit: list[tuple[float, float, float]],
         start: float, depth: float, mirror: bool = False, near: float = 150.0,
         squash: float | None = None) -> View:
    """The walking view: columns [param scale_h] metres apart along a line
    through UTM (e, n) square to [param azimuth] (degrees east of north),
    column [param cx] through that point; the lines of sight start [param
    start] metres in front of it and run [param depth] beyond. Each column's
    eye stands [param d0] metres out from where its own line meets the foot
    of the wall, [param eye] metres above the ground. [param mirror] draws
    west on the left when looking south. [param fit] = [(first column, last
    column, rows), ...]: the highest skyline between each pair of columns
    stands that many rows below the top, the scale changing smoothly from
    one to the next; or [param squash] gives the metres per row outright."""
    az = math.radians(azimuth)
    fwd = np.array([math.sin(az), math.cos(az)])
    right = np.array([math.cos(az), -math.sin(az)])
    if mirror:
        right = -right
    step = dem.res * 0.7
    ts = np.arange(0.0, start + depth, step, dtype=np.float32)
    us = (np.arange(W, dtype=np.float32) + 0.5 - cx) * scale_h
    le = e - start * fwd[0] + us * right[0]
    ln_ = n - start * fwd[1] + us * right[1]
    prof = dem.sample(le[:, None] + ts[None, :] * fwd[0], ln_[:, None] + ts[None, :] * fwd[1])
    # the Valley floor along each line (its low point before the wall), and
    # the foot of the wall: where the ground first rises well above it
    span = max(2, int(len(ts) * 0.7))
    lo_i = np.argmin(prof[:, :span], axis=1)
    floor = prof[np.arange(W), lo_i]
    rising = (prof > (floor + 45.0)[:, None]) & (np.arange(len(ts))[None, :] > lo_i[:, None])
    foot_i = np.where(rising.any(axis=1), rising.argmax(axis=1), len(ts) - 1)
    foot_t = ts[foot_i]
    # where each line first comes down onto the floor (it may start on the
    # far wall's talus, across a narrow stretch of the Valley)
    on_floor = prof <= (floor + 25.0)[:, None]
    floor_t = ts[np.where(on_floor.any(axis=1), on_floor.argmax(axis=1), 0)]

    def steady(a: np.ndarray) -> np.ndarray:
        # no jumps from column to column
        k = 15
        pad = np.pad(a, k, mode="edge")
        med = np.array([np.median(pad[i:i + 2 * k + 1]) for i in range(W)], np.float32)
        return np.convolve(np.pad(med, 6, mode="edge"), np.ones(13) / 13, mode="same")[6:-6]
    foot_s = steady(foot_t)
    # the eye d0 out from the foot, but never back up the far side's slope
    t_eye = np.clip(np.maximum(foot_s - d0, steady(floor_t)), 0, ts[-1] - d0).astype(np.float32)
    # and never look over the wall's own foot, where the Valley is narrow
    near_c = np.clip(0.6 * (foot_s - t_eye), 60.0, near).astype(np.float32)
    oe = (le + t_eye * fwd[0]).astype(np.float64)
    on = (ln_ + t_eye * fwd[1]).astype(np.float64)
    ground = dem.sample(oe, on)
    eyes = (np.maximum(ground, base_z) + eye).astype(np.float32)
    # every column's sight line runs the full depth on from its own eye
    rts = ts
    de, dn = np.full(W, fwd[0]), np.full(W, fwd[1])
    br = np.asarray(base_row, np.float32)
    if squash is None:
        sv = _fit_scale(_fits(dem, oe, on, de, dn, rts, eyes, near_c, False, fit, W), eyes, base_z, br, d0)
    else:
        sv = np.full(W, squash, np.float32)
    tan_rows = _rows(H, eyes, base_z, br, sv, d0)
    rights = np.repeat(right[None, :], W, 0)
    fwds = np.repeat(fwd[None, :], W, 0)
    return _march(dem, oe, on, de, dn, rts, eyes, tan_rows, near_c, False, rights, fwds, sv)


def camera(dem: DEM, *, e: float, n: float, eye: float, W: int, H: int, az_at, base_z: float,
           base_row: np.ndarray, d0: float, fit: list[tuple[float, float, float]], depth: float, near: float = 150.0,
           curve: bool = True, eye_abs: float | None = None, squash: float | None = None) -> View:
    """The panorama from one eye at UTM (e, n), [param eye] metres above the
    ground (or at height [param eye_abs]): column c looks along azimuth
    [param az_at](c) (degrees east of north, any monotonic function). Rows as
    for walk(): row base_row[c] meets base_z d0 metres out."""
    cs = np.arange(W, dtype=np.float64) + 0.5
    azs = np.radians(np.array([az_at(c) for c in cs], np.float64))
    de, dn = np.sin(azs), np.cos(azs)
    # which way the picture runs: right is the way the azimuth turns
    turn = np.sign(np.gradient(azs))
    turn[turn == 0] = 1.0
    rights = np.stack([np.cos(azs) * turn, -np.sin(azs) * turn], 1)
    fwds = np.stack([de, dn], 1)
    # finer steps near the eye, coarser far off
    ts = [0.0]
    while ts[-1] < depth:
        ts.append(ts[-1] + max(dem.res * 0.7, ts[-1] * 0.0015))
    ts = np.array(ts, np.float32)
    ground = float(dem.sample(np.array([e]), np.array([n]))[0])
    ez = eye_abs if eye_abs is not None else max(ground, base_z) + eye
    eyes = np.full(W, ez, np.float32)
    oe, on = np.full(W, e), np.full(W, n)
    br = np.asarray(base_row, np.float32)
    if squash is None:
        sv = _fit_scale(_fits(dem, oe, on, de, dn, ts, eyes, near, curve, fit, W), eyes, base_z, br, d0)
    else:
        sv = np.full(W, squash, np.float32)
    tan_rows = _rows(H, eyes, base_z, br, sv, d0)
    return _march(dem, oe, on, de, dn, ts, eyes, tan_rows, near, curve, rights, fwds, sv)
