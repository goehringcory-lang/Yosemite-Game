#!/usr/bin/env python3
"""Paints the view from one of the park's overlooks as it really is: every
pixel a line of sight from the railing across the USGS's heights, out to the
crest of the Sierra, onto the land cover OpenStreetMap maps there (forest,
meadow, bare granite, talus, the Merced and its falls, roads, buildings).

The light is the afternoon sun's, from the west-southwest, with the shadows
the terrain really casts; distance fades into a blue haze; granite is
streaked black on its faces, the falls run white where the creeks go over
the cliffs, and snow lies in the high peaks' north-facing cirques.

    python3 tools/art32/walls32/vista.py glacier_point            # writes the painting, fixes the falls in the scene
    python3 tools/art32/walls32/vista.py --out DIR glacier_point  # writes elsewhere, to look first

The first run downloads the heights and the map (cached in
tools/art32/walls32/cache/, git-ignored). Then `godot --headless --path . --import`.
"""
from __future__ import annotations

import math
import os
import re
import sys
from dataclasses import dataclass, field

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)

import dem as D  # noqa: E402
import osm as O  # noqa: E402
from paint import BAYER, blur, noise  # noqa: E402
from pixel32 import scale2x  # noqa: E402

EARTH_R = 6371000.0
REFRACTION = 0.13


@dataclass
class View:
    name: str
    out: str  # the painting, relative to the project
    eye: tuple[float, float]  # lat, lon
    eye_h: float  # metres above the ground
    size: tuple[int, int]  # art pixels (the painting is twice this)
    # the azimuth across the painting: [bearing, painting pixels per degree]
    # knots from the left edge, so the busy stretches of skyline get room
    density: list
    horizon: float  # art row of the level line of sight
    v_deg: float = 10.0  # painting pixels per degree up and down, at the horizon
    near: float = 150.0  # metres of foreground left to the game's own drop
    # (from bearing, to bearing, metres at the first, metres at the second):
    # looking over the overlook's own higher ground in those directions, the
    # cut growing steadily from one bearing to the other
    near_more: list = field(default_factory=list)
    depth: float = 60000.0
    near_box: tuple[float, float, float, float] = (0, 0, 0, 0)  # metres round the eye: west, south, east, north
    near_res: float = 4.0
    far_box: tuple[float, float, float, float] = (0, 0, 0, 0)
    far_res: float = 30.0
    sun: tuple[float, float] = (250.0, 32.0)  # azimuth, elevation
    scene: str = ""  # the scene whose vista shader shows it (its falls are fixed up)
    # how far the painting slides as you walk, as a share of the camera's
    # movement (written into the scene, and into the builder's constant)
    parallax: tuple[float, float] | None = None
    parallax_const: str = ""
    # a script holding the first fall as FALL_TOP, FALL_BOTTOM and
    # FALL_HALF_WIDTH, in half the painting's pixels (the title screen)
    title_falls: str = ""
    # the falls to shimmer first, by their names on the map, in order
    prefer_falls: list = field(default_factory=list)
    # falls that run only a few weeks a year, painted dry
    dry_falls: list = field(default_factory=list)
    builder: str = ""  # the builder script holding the falls as a constant
    falls_const: str = ""
    max_falls: int = 6
    clouds: list = field(default_factory=list)  # (azimuth, elevation, width deg, height deg)



VIEWS = {
    # Glacier Point: from the railing, Yosemite Falls across the Valley to the
    # left, the Royal Arches and North Dome, Half Dome over Tenaya Canyon with
    # Clouds Rest behind, the crest of the Sierra, Curry Village and the
    # Merced 3,200 feet below; then, looking past the point's own higher
    # ground to the east, Liberty Cap and Mount Broderick over Nevada and
    # Vernal falls. (Illilouette Fall, in its gorge behind the point, can't
    # be seen from the railing.)
    "glacier_point": View(
        "glacier_point", "assets/sprites/glacier/vista.png", (37.73067, -119.57367), 1.6, (820, 500),
        density=[[290, 6], [318, 8], [335, 5], [385, 13], [435, 8.5], [490, 8.5]], horizon=62.0,
        sun=(228.0, 46.0), near_more=[(92.0, 140.0, 520.0, 520.0)],
        near_box=(-5000, -2500, 8000, 7500), far_box=(-30000, -30000, 45000, 40000),
        scene="scenes/regions/glacier_point.tscn", builder="tools/hubs/build_glacier_point.gd",
        parallax=(0.25, 0.05), parallax_const="VISTA_PARALLAX",
        prefer_falls=["Upper Yosemite Fall", "Lower Yosemite Fall", "Nevada Fall", "Vernal Fall", "Royal Arch Cascade"],
        dry_falls=["Horsetail Fall"],
        clouds=[(18.0, 5.5, 12.0, 1.8), (80.0, 6.0, 16.0, 2.2), (118.0, 4.8, 10.0, 1.5), (330.0, 6.2, 9.0, 1.4)]),
    # Tunnel View, the title painting: El Capitan on the left, Half Dome far
    # up the Valley with Clouds Rest behind, Sentinel Rock, and Bridalveil
    # Fall pouring from its hanging valley beside Cathedral Rocks on the
    # right, the forest of the Valley's west end below. Late afternoon.
    "tunnel_view": View(
        "tunnel_view", "assets/ui/title_background.png", (37.71557, -119.67689), 1.6, (480, 270),
        density=[[48, 18.5], [100, 18.5]], v_deg=18.5, horizon=172.0, near=220.0,
        near_box=(-1500, -2500, 15000, 5500), far_box=(-15000, -25000, 60000, 30000),
        sun=(246.0, 34.0), scene="scenes/regions/tunnel_view.tscn", builder="tools/hubs/build_valley_floor.gd",
        falls_const="TV_VISTA_FALLS", max_falls=1, title_falls="scripts/ui/title_screen.gd",
        prefer_falls=["Bridalveil Fall"], dry_falls=["Horsetail Fall"],
        clouds=[(56.0, 19.0, 9.0, 2.0), (73.0, 12.5, 7.0, 1.4), (86.0, 17.0, 12.0, 2.6), (98.0, 15.0, 8.0, 1.8)]),
}

# Colour ramps, dark to light.
RAMPS = {
    "granite": ["2c2f3a", "3b3f4b", "4d505b", "61636c", "77777d", "8e8c8d", "a5a29e", "bbb6ae", "cfc9bd", "e1dbcc", "efeadb"],
    "streak": ["16151a", "201e23", "2a272b", "353135", "403b3e", "4c4648", "5a5353"],
    "talus": ["30313a", "40414a", "52525a", "66656b", "7b797c", "918e8e", "a6a29f", "bab5ae"],
    "forest": ["0a140f", "0f1c14", "142519", "1a2f1e", "213924", "29432a", "324e30", "3c5937", "47643e"],
    "brush": ["1b2414", "252f1a", "2f3a20", "3a4626", "46532d", "536035", "616e3e", "6f7b48"],
    "meadow": ["2a3a1c", "374a22", "455a29", "546a31", "647a39", "758a43", "879a4f", "99a95c", "abb86b"],
    "wet": ["1c2e1e", "243a24", "2e472a", "395431", "456238", "537040"],
    "water": ["14303d", "1b3c4a", "234a57", "2c5864", "386772", "47767f", "58868d", "6c979c", "84a9ac"],
    "white": ["8fa3ad", "a9bac2", "c3d0d5", "dbe4e6", "eef3f3", "fafcfb"],
    "snow": ["7d8ea3", "96a7ba", "b0bfce", "c9d4df", "dee6ed", "eef3f6"],
    "built": ["3a332e", "4f463e", "665b50", "7e7163", "978a7a", "b0a492", "c9bfad"],
    "road": ["343538", "424346", "515255", "616264", "727375"],
    "sand": ["6e6352", "857963", "9d9076", "b4a78b", "c9bda1"],
}
SKY_TOP = np.array([58, 104, 150], np.float32)
SKY_LOW = np.array([176, 202, 214], np.float32)
HAZE = np.array([150, 176, 196], np.float32)


def _rgb(h: str) -> tuple[int, int, int]:
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


RAMP_RGB = {k: np.array([_rgb(c) for c in v], np.float32) for k, v in RAMPS.items()}
MATS = list(RAMPS)


def azimuths(view: View) -> np.ndarray:
    """The azimuth of every art column's centre."""
    W = view.size[0]
    b = np.array([k[0] for k in view.density], np.float64)
    d = np.array([k[1] for k in view.density], np.float64) / 2.0  # art pixels per degree
    fine = np.linspace(b[0], b[-1], 20000)
    dens = np.interp(fine, b, d)
    x = np.concatenate([[0.0], np.cumsum((dens[1:] + dens[:-1]) / 2.0 * np.diff(fine))])
    return np.interp(np.arange(W) + 0.5, x, fine) % 360.0


def column_of(view: View, bearing: float) -> float:
    """The art column at a bearing."""
    az = azimuths(view)
    un = np.unwrap(np.radians(az))
    b = math.radians(bearing)
    while b < un[0]:
        b += 2 * math.pi
    return float(np.interp(b, un, np.arange(len(az)) + 0.5))


def _in(b: float, a0: float, a1: float) -> bool:
    return (b - a0) % 360.0 <= (a1 - a0) % 360.0


class Terrain:
    """Heights from several grids: the finest that covers a point wins."""

    def __init__(self, dems: list[D.DEM]) -> None:
        self.dems = dems

    def _which(self, e: np.ndarray, n: np.ndarray) -> np.ndarray:
        k = np.full(e.shape, len(self.dems) - 1, np.int8)
        for i in range(len(self.dems) - 1, -1, -1):
            d = self.dems[i]
            h, w = d.shape
            inside = (e > d.e0 + d.res) & (e < d.e0 + (w - 1) * d.res) & (n < d.n1 - d.res) & (n > d.n1 - (h - 1) * d.res)
            k[inside] = i
        return k

    def sample(self, e: np.ndarray, n: np.ndarray, what: str = "z") -> np.ndarray:
        k = self._which(e, n)
        out = np.zeros(e.shape, np.float32)
        for i, d in enumerate(self.dems):
            m = k == i
            if m.any():
                grid = {"z": d.z, "e": d.dzde, "n": d.dzdn}[what]
                out[m] = d.sample(e[m], n[m], grid)
        return out


def heights(view: View) -> tuple[Terrain, float, float]:
    ee, en = D.utm(*view.eye)
    dems = []
    for box, res in ((view.near_box, view.near_res), (view.far_box, view.far_res)):
        w, s, e, n = box
        dm = D.fetch(math.floor((ee + w) / 100) * 100, math.floor((en + s) / 100) * 100,
                     math.ceil((ee + e) / 100) * 100, math.ceil((en + n) / 100) * 100, res)
        dems.append(D.DEM(blur(dm.z, 1.0), dm.e0, dm.n1, dm.res))
    return Terrain(dems), ee, en


def march(t: Terrain, ee: float, en: float, ez: float, view: View) -> dict[str, np.ndarray]:
    """Every pixel's line of sight: where it meets the ground, if it does."""
    W, H = view.size
    az_deg = azimuths(view)
    az = np.radians(az_deg)
    de, dn = np.sin(az), np.cos(az)
    f = view.v_deg / 2.0 * 180.0 / math.pi  # art pixels per radian, up and down
    rows = np.arange(H, dtype=np.float64) + 0.5
    tan_r = (view.horizon - rows) / f  # (H,)
    near_c = np.full(W, view.near)
    for a0, a1, m0, m1 in view.near_more:
        for c in range(W):
            if _in(az_deg[c], a0, a1):
                f_ = ((az_deg[c] - a0) % 360.0) / max(1e-6, (a1 - a0) % 360.0)
                near_c[c] = max(near_c[c], m0 + (m1 - m0) * f_)
    ts = [view.near]
    while ts[-1] < view.depth:
        ts.append(ts[-1] + max(view.near_res * 0.6, ts[-1] * 0.0018))
    ts = np.array(ts, np.float64)
    drop = ts * ts / (2.0 * EARTH_R) * (1.0 - REFRACTION)
    out = {k: np.zeros((H, W), np.float32) for k in ("e", "n", "z", "dist")}
    hit = np.zeros((H, W), bool)
    for c0 in range(0, W, 64):
        c1 = min(W, c0 + 64)
        E = ee + ts[None, :] * de[c0:c1, None]
        N = en + ts[None, :] * dn[c0:c1, None]
        prof = t.sample(E, N) - drop[None, :]
        tan_all = np.where(ts[None, :] > near_c[c0:c1, None], (prof - ez) / ts[None, :], -1e3)
        ang = np.maximum.accumulate(tan_all, axis=1)
        for c in range(c0, c1):
            i = c - c0
            idx = np.searchsorted(ang[i], tan_r, side="left")
            ok = idx < len(ts)
            idx = np.minimum(idx, len(ts) - 1)
            i0 = np.maximum(idx - 1, 0)
            g0 = prof[i, i0] - (ez + ts[i0] * tan_r)
            g1 = prof[i, idx] - (ez + ts[idx] * tan_r)
            fr = np.where(np.abs(g1 - g0) > 1e-6, np.clip(-g0 / (g1 - g0 + 1e-12), 0, 1), 0.0)
            d = ts[i0] + (ts[idx] - ts[i0]) * fr
            hit[:, c] = ok
            out["dist"][:, c] = d
            out["e"][:, c] = ee + d * de[c]
            out["n"][:, c] = en + d * dn[c]
    out["z"] = t.sample(out["e"], out["n"])
    out["hit"] = hit
    gx = t.sample(out["e"], out["n"], "e")
    gy = t.sample(out["e"], out["n"], "n")
    ln = np.sqrt(gx * gx + gy * gy + 1.0)
    out["ne"], out["nn"], out["nu"] = -gx / ln, -gy / ln, 1.0 / ln
    out["slope"] = np.degrees(np.arctan(np.hypot(gx, gy))).astype(np.float32)
    return out


def shadows(t: Terrain, px: dict[str, np.ndarray], sun: tuple[float, float]) -> np.ndarray:
    """1 where the sun reaches the ground a pixel shows, 0 where terrain
    between casts it in shadow (soft-edged by a little blur later)."""
    az, el = math.radians(sun[0]), math.radians(sun[1])
    se, sn, su = math.sin(az) * math.cos(el), math.cos(az) * math.cos(el), math.sin(el)
    hit = px["hit"]
    ys, xs = np.nonzero(hit)
    lit = np.ones(hit.shape, np.float32)
    steps = [6.0]
    while steps[-1] < 9000:
        steps.append(steps[-1] * 1.06 + 2.0)
    steps = np.array(steps, np.float32)
    for k0 in range(0, len(ys), 40000):
        yy, xx = ys[k0:k0 + 40000], xs[k0:k0 + 40000]
        e = px["e"][yy, xx][:, None] + steps[None, :] * se
        n = px["n"][yy, xx][:, None] + steps[None, :] * sn
        z = px["z"][yy, xx][:, None] + 2.0 + steps[None, :] * su
        g = t.sample(e, n)
        blocked = (g > z).any(axis=1)
        lit[yy[blocked], xx[blocked]] = 0.0
    return lit


def paint(view: View, out_path: str) -> list[tuple]:
    t, ee, en = heights(view)
    ground = float(t.sample(np.array([ee]), np.array([en]))[0])
    ez = ground + view.eye_h
    W, H = view.size
    print(f"  {view.name}: eye at {ez:.0f} m, {W}x{H} art pixels")
    px = march(t, ee, en, ez, view)
    hit = px["hit"]
    # land cover where the map covers it
    nb = view.near_box
    lon0, lat0 = view.eye[1] + nb[0] / 88000.0, view.eye[0] + nb[1] / 111000.0
    lon1, lat1 = view.eye[1] + nb[2] / 88000.0, view.eye[0] + nb[3] / 111000.0
    cv = O.cover(math.floor((ee + nb[0]) / 100) * 100, math.floor((en + nb[1]) / 100) * 100,
                 math.ceil((ee + nb[2]) / 100) * 100, math.ceil((en + nb[3]) / 100) * 100, 4.0,
                 (lon0, lat0, lon1, lat1))
    cls_grid = cv.cls
    r = ((cv.n1 - px["n"]) / cv.res).astype(np.int64)
    c = ((px["e"] - cv.e0) / cv.res).astype(np.int64)
    inside = hit & (r >= 0) & (r < cls_grid.shape[0]) & (c >= 0) & (c < cls_grid.shape[1])
    cls = np.zeros((H, W), np.uint8)
    cls[inside] = cls_grid[r[inside], c[inside]]
    print("  shadows...")
    lit = shadows(t, px, view.sun)
    lit = np.clip(blur(lit, 0.6) * 1.15 - 0.075, 0, 1)
    return _compose(view, px, cls, lit, cv, out_path, ee, en, ez)


def _compose(view: View, px, cls, lit, cv, out_path: str, ee: float, en: float, ez: float) -> list[tuple]:
    W, H = view.size
    hit = px["hit"]
    rng = np.random.default_rng(7)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    az = math.radians(view.sun[0])
    el = math.radians(view.sun[1])
    s = np.array([math.sin(az) * math.cos(el), math.cos(az) * math.cos(el), math.sin(el)], np.float32)
    diff = np.clip(px["ne"] * s[0] + px["nn"] * s[1] + px["nu"] * s[2], 0, 1)
    # the sky lights the shade too: shaded rock is blue-grey, not black
    light = 0.38 + 0.62 * diff * lit
    slope = px["slope"]
    dist = px["dist"]
    z = px["z"]
    # what each pixel shows
    mat = np.full((H, W), -1, np.int16)
    val = np.zeros((H, W), np.float32)
    M = {m: i for i, m in enumerate(MATS)}
    steep = slope > 40
    n_v = noise(W, H, 3, 11)
    n_b = noise(W, H, 11, 12)
    water = hit & np.isin(cls, (O.WATER, O.RIVER)) & (slope < 14)
    white = hit & ((np.isin(cls, (O.RIVER,)) & (slope >= 14)) | ((cls == O.STREAM) & (slope > 45)))
    for e, n, nm in cv.falls:
        if nm in view.dry_falls:
            white &= np.hypot(px["e"] - e, px["n"] - n) > 400.0
    rock = hit & ~water & ~white & ((cls == O.ROCK) | (steep & ~np.isin(cls, (O.WATER,))) |
                                    ((cls == O.NONE) & (slope > 30 + 8 * n_b)) | ((z > 3050) & (cls == O.NONE)))
    talus = hit & ~water & ~white & ~rock & (cls == O.SCREE)
    meadow = hit & ~rock & ~water & ~white & (cls == O.MEADOW)
    wet = hit & ~rock & ~water & ~white & (cls == O.WETLAND)
    built = hit & (cls == O.BUILT) & ~rock
    road = hit & np.isin(cls, (O.ROAD, O.PARKING)) & ~rock & (dist < 4000)
    sand = hit & (cls == O.SAND) & ~rock
    brush = hit & ~rock & ~water & ~white & ~meadow & ~wet & ~built & ~road & ~sand & ~talus & (
        (cls == O.SCRUB) | ((z > 2700) & (n_v > 0.55)))
    forest = hit & ~rock & ~water & ~white & ~meadow & ~wet & ~built & ~road & ~sand & ~talus & ~brush
    # snow in the high north-facing cirques and gullies
    snow = rock & (z > 3250 - 120 * n_b) & (px["nn"] > 0.15) & (slope < 52) & (n_v > 0.35)

    def put(m, name, v):
        mat[m] = M[name]
        val[m] = v[m] if isinstance(v, np.ndarray) else v

    # granite: the sun's light, cool where shaded, the faces streaked
    put(rock, "granite", 0.08 + 0.88 * light + (n_b - 0.5) * 0.08)
    # the overlook's own cliffs, close by and mostly in shade, kept dark and
    # plain so they frame the view rather than compete with it
    near_rock = rock & (dist < 700)
    flutes = np.repeat(noise(W, H // 8 + 2, 3.0, 17), 8, axis=0)[:H]
    put(near_rock, "granite", 0.06 + 0.52 * light + (flutes - 0.5) * 0.12)
    _streaks(rock & (slope > 55) & (dist > 700), mat, val, M, rng, W, H)
    put(talus, "talus", 0.1 + 0.8 * light + (noise(W, H, 1.5, 13) - 0.5) * 0.3)
    # forest: crowns, lit on the sun side, sized by distance
    f_px = view.v_deg / 2.0 * 180.0 / math.pi
    crown, tint = _crowns(dist, f_px, W, H)
    in_crown = crown > 0.15
    put(forest, "forest", 0.06 + 0.6 * light * (0.6 + 0.4 * crown) + 0.22 * crown * lit +
        np.where(in_crown, (tint - 0.5) * 0.16, -0.04))
    # black oaks among the conifers on the Valley floor, a lighter, yellower green
    oaks = forest & (z < 1300) & (tint > 0.82) & in_crown
    put(oaks, "brush", 0.15 + 0.7 * light * (0.6 + 0.4 * crown) + 0.15 * crown * lit)
    put(brush, "brush", 0.1 + 0.7 * light + (n_v - 0.5) * 0.25)
    # meadows: greener where wet, cured gold in drifts on the rises
    put(meadow, "meadow", 0.15 + 0.75 * light + (noise(W, H, 2, 14) - 0.5) * 0.15 + (noise(W, H, 9, 18) - 0.5) * 0.2)
    put(wet, "wet", 0.15 + 0.7 * light)
    put(built, "built", 0.2 + 0.7 * light + (noise(W, H, 1, 15) - 0.5) * 0.4)
    put(road, "road", 0.3 + 0.5 * light)
    # cars in the lots
    cars = road & (cls == O.PARKING) & (noise(W, H, 1.0, 19) > 0.62)
    if cars.any():
        mat[cars] = M["built"]
        val[cars] = np.random.default_rng(20).random(int(cars.sum()))
    put(sand, "sand", 0.2 + 0.7 * light)
    # water: the sky in it, darker under the banks
    put(water, "water", 0.35 + 0.35 * lit + (noise(W, H, 2, 16) - 0.5) * 0.3)
    put(white, "white", 0.35 + 0.55 * light)
    put(snow, "snow", 0.2 + 0.8 * light)
    # the colours, then the haze of distance over them
    rgb = np.zeros((H, W, 3), np.float32)
    bay = np.tile(BAYER, (H // 4 + 1, W // 4 + 1))[:H, :W] - 0.47
    for name, i in M.items():
        m = mat == i
        if not m.any():
            continue
        ramp = RAMP_RGB[name]
        k = len(ramp)
        v = np.clip(val, 0, 1) * (k - 1) + bay * 0.4
        idx = np.clip(np.floor(v + 0.5), 0, k - 1).astype(int)
        rgb[m] = ramp[idx[m]]
    haze = 1.0 - np.exp(-np.maximum(dist - 800.0, 0.0) / 22000.0)
    # in steps, dithered, so the far ridges stay flat bands of colour
    hz = np.clip(np.floor(haze * 6.0 + bay * 0.8 + 0.5) / 6.0, 0, 0.85)
    rgb = np.where(hit[..., None], rgb * (1 - hz[..., None]) + HAZE[None, None, :] * hz[..., None], rgb)
    # silhouettes: a dark edge where nearer ground stands in front of farther
    up = np.vstack([dist[:1], dist[:-1]])
    sil = hit & (up - dist > np.maximum(400.0, dist * 0.35)) & np.vstack([hit[:1], hit[:-1]])
    rgb[sil] *= 0.78
    # the sky and its clouds
    sky = ~hit
    # the sky in a few flat bands, deep blue overhead to pale at the
    # horizon, with a narrow dithered seam between bands (no all-over grain)
    tt = np.clip(yy / max(1.0, view.horizon + 30.0), 0, 1) ** 1.25
    bands = 7.0
    level = np.clip(np.floor(tt * bands + bay * 0.9 + 0.05), 0, bands) / bands
    sky_rgb = SKY_TOP[None, None, :] * (1 - level[..., None]) + SKY_LOW[None, None, :] * level[..., None]
    sky_rgb = _clouds(sky_rgb, view, W, H, bay)
    rgb = np.where(sky[..., None], sky_rgb, rgb)
    # into palette-like steps: each channel to the nearest of a few levels,
    # dithered, so the painting stays pixel art
    img = np.zeros((H, W, 4), np.uint8)
    q = np.clip(rgb + (bay * hit)[..., None] * 6.0, 0, 255)
    img[..., :3] = (np.round(q / 4.0) * 4.0).clip(0, 255).astype(np.uint8)
    img[..., 3] = 255
    big = scale2x(img)
    Image.fromarray(big, "RGBA").save(out_path, optimize=True)
    return _falls(view, white & (dist > 1000), cv, px, ee, en)


def _crowns(dist: np.ndarray, f_px: float, W: int, H: int) -> np.ndarray:
    """Tree crowns about 11 m across, as many pixels as that is at each
    distance: 1 at a crown's lit top, 0 in the gaps; and each crown's own
    random tint, 0..1."""
    out = np.zeros((H, W), np.float32)
    tint = np.zeros((H, W), np.float32)
    yy, xx = np.mgrid[0:H, 0:W]
    for i, (lo, hi) in enumerate(((0, 1400), (1400, 2600), (2600, 5000), (5000, 1e9))):
        sel = (dist >= lo) & (dist < hi)
        if not sel.any():
            continue
        d = float(np.median(dist[sel]))
        cw = int(np.clip(round(11.0 * f_px / d), 1, 5))
        ch = max(1, int(round(cw * 1.4)))
        rr = np.random.default_rng(30 + i)
        gw, gh = W // cw + 2, H // ch + 2
        ox = rr.random((gh, gw)) * cw
        oy = rr.random((gh, gw)) * ch
        gx = xx // cw
        gy = yy // ch
        dx = (xx + 0.5 - (gx * cw + ox[gy, gx])) / max(0.6, cw * 0.6)
        dy = (yy + 0.5 - (gy * ch + oy[gy, gx])) / max(0.6, ch * 0.6)
        size = 0.75 + 0.5 * rr.random((gh, gw))[gy, gx]
        cr = np.clip(1.0 - np.sqrt(dx * dx + dy * dy) / size, 0, 1)
        tn = rr.random((gh, gw))[gy, gx]
        if cw == 1:
            cr = (rr.random((H, W)) > 0.45).astype(np.float32) * 0.8
        out = np.where(sel, cr, out)
        tint = np.where(sel, tn, tint)
    return out, tint


def _streaks(face: np.ndarray, mat, val, M, rng, W: int, H: int) -> None:
    """Dark water streaks down the steep faces, from the top of each face."""
    acc = np.zeros((H, W), np.float32)
    for x in range(1, W - 1):
        col = face[:, x]
        if not col.any():
            continue
        ys = np.nonzero(col)[0]
        # each run of face in this column
        starts = ys[np.r_[True, np.diff(ys) > 1]]
        for y0 in starts:
            if rng.random() < 0.06:
                run = int(rng.integers(20, 90))
                wdt = 1 if rng.random() < 0.6 else 2
                for k in range(run):
                    yk = y0 + k
                    if yk >= H or not face[yk, x]:
                        break
                    acc[yk, x:x + wdt] = 1.0 - k / run * 0.5
    m = face & (acc > 0.45)
    mat[m] = M["streak"]
    val[m] = np.clip(val[m] * 0.8, 0, 1)


def _clouds(sky: np.ndarray, view: View, W: int, H: int, bay: np.ndarray) -> np.ndarray:
    """Summer cumulus: rounded tops lit from the sun's side, flat grey bases."""
    f = view.v_deg / 2.0 * 180.0 / math.pi
    out = sky.copy()
    rng = np.random.default_rng(91)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    for az, el, wd, ht in view.clouds:
        cx = column_of(view, az)
        if cx > W + 60:
            continue
        cy = view.horizon - math.tan(math.radians(el)) * f
        px_deg = view.v_deg / 2.0
        rw, rh = wd * px_deg / 2.0, ht * px_deg
        dens = np.zeros((H, W), np.float32)
        for _ in range(int(wd * 1.6)):
            bx = cx + rng.normal() * rw * 0.45
            by = cy - abs(rng.normal()) * rh * 0.6
            br = rng.uniform(0.25, 0.55) * rh * 1.6
            d = np.sqrt(((xx - bx) / br) ** 2 + ((yy - by) / (br * 0.8)) ** 2)
            dens = np.maximum(dens, 1.0 - d)
        base = yy > cy + rh * 0.15  # a flat underside
        dens[base] = 0
        m = dens > 0.04
        shade = np.clip(0.55 + (cx - xx) / max(1.0, rw) * 0.2 + (cy - yy) / max(1.0, rh) * 0.35 + dens * 0.25, 0, 1)
        # three tones: the grey underside, the body, and the sunlit tops
        tone = np.clip(np.floor(shade * 3.0 + bay * 0.6), 0, 2)
        cols = np.array([[168, 182, 196], [214, 222, 228], [248, 248, 244]], np.float32)
        out[m] = cols[tone[m].astype(int)]
    return out


def _falls(view: View, white: np.ndarray, cv, px, ee: float, en: float) -> list[tuple]:
    """The painting's waterfalls as the vista shader wants them: top and bottom
    in painting pixels (twice the art pixels) and the half widths there."""
    H, W = white.shape
    found = []
    seen = np.zeros_like(white)
    ys, xs = np.nonzero(white)
    for y, x in sorted(zip(ys.tolist(), xs.tolist())):
        if seen[y, x]:
            continue
        # follow this fall down: a run of white pixels, column by column
        x0, y0 = x, y
        cx, cy = x, y
        widths = []
        while cy < H:
            row = white[cy, max(0, cx - 3):cx + 4]
            if not row.any():
                break
            cols = np.nonzero(row)[0] + max(0, cx - 3)
            cx = int(round(cols.mean()))
            widths.append(len(cols))
            seen[cy, cols] = True
            cy += 1
        if cy - y0 >= 6:
            found.append((x0, y0, cx, cy - 1, widths))
    # the falls the view prefers first, then any the map names, then the longest
    named = []
    for e, n, nm in cv.falls:
        if nm:
            rank = view.prefer_falls.index(nm) if nm in view.prefer_falls else len(view.prefer_falls)
            named.append((rank, np.hypot(px["e"] - e, px["n"] - n)))

    def match(f) -> tuple[int, int]:
        """(rank, which named fall) for a run: the best-ranked fall near it."""
        x0, y0, x1, y1, _w = f
        best, which = len(view.prefer_falls) + 1, -1
        for i, (rank, h) in enumerate(named):
            if float(h[y0:y1 + 1, min(x0, x1):max(x0, x1) + 1].min()) < 300.0 and rank < best:
                best, which = rank, i
        return best, which
    found.sort(key=lambda f: (match(f)[0], -(f[3] - f[1])))
    # one run for each named fall (its longest), then the unnamed ones
    keep, used = [], set()
    for f in found:
        _rank, which = match(f)
        if which >= 0 and which in used:
            continue
        used.add(which)
        keep.append(f)
    out = []
    for x0, y0, x1, y1, w in keep[:view.max_falls]:
        top_w = max(1.0, float(np.mean(w[:3])) / 2.0) * 2.0
        bot_w = max(1.0, float(np.mean(w[-3:])) / 2.0) * 2.0
        out.append(((x0 * 2 + 1, y0 * 2), (x1 * 2 + 1, y1 * 2 + 2), (top_w, bot_w)))
    out.sort(key=lambda f: f[0][0])
    return out


def fix_scene(view: View, falls: list[tuple]) -> None:
    """Writes the falls into the scene's vista shader and the builder's
    constant, so the shimmer runs where the painting's falls are."""
    lines = ", ".join("%g, %g, %g, %g" % (a[0], a[1], b[0], b[1]) for a, b, _w in falls)
    widths = ", ".join("%g, %g" % w for _a, _b, w in falls)
    if view.scene:
        path = os.path.join(ROOT, view.scene)
        s = open(path).read()
        s = re.sub(r"shader_parameter/falls = PackedVector4Array\([^)]*\)",
                   "shader_parameter/falls = PackedVector4Array(%s)" % lines, s, count=1)
        s = re.sub(r"shader_parameter/fall_widths = PackedVector2Array\([^)]*\)",
                   "shader_parameter/fall_widths = PackedVector2Array(%s)" % widths, s, count=1)
        s = re.sub(r"shader_parameter/fall_count = \d+", "shader_parameter/fall_count = %d" % len(falls), s, count=1)
        if view.parallax:
            s = re.sub(r"shader_parameter/parallax = Vector2\([^)]*\)",
                       "shader_parameter/parallax = Vector2(%g, %g)" % view.parallax, s, count=1)
        open(path, "w").write(s)
    if view.title_falls and falls:
        path = os.path.join(ROOT, view.title_falls)
        s = open(path).read()
        (a, b, w) = falls[0]
        s = re.sub(r"const FALL_TOP := Vector2\([^)]*\)", "const FALL_TOP := Vector2(%g, %g)" % (a[0] / 2, a[1] / 2), s, count=1)
        s = re.sub(r"const FALL_BOTTOM := Vector2\([^)]*\)", "const FALL_BOTTOM := Vector2(%g, %g)" % (b[0] / 2, b[1] / 2), s,
                   count=1)
        s = re.sub(r"const FALL_HALF_WIDTH := Vector2\([^)]*\)", "const FALL_HALF_WIDTH := Vector2(%g, %g)" % (w[0] / 2, w[1] / 2),
                   s, count=1)
        open(path, "w").write(s)
    if view.builder and view.parallax_const and view.parallax:
        path = os.path.join(ROOT, view.builder)
        s = open(path).read()
        s = re.sub(r"const %s := Vector2\([^)]*\)" % view.parallax_const,
                   "const %s := Vector2(%g, %g)" % ((view.parallax_const,) + tuple(view.parallax)), s, count=1)
        open(path, "w").write(s)
    if view.builder and view.falls_const:
        path = os.path.join(ROOT, view.builder)
        s = open(path).read()
        one = "[%s]" % ", ".join("[Vector2(%g, %g), Vector2(%g, %g), Vector2(%g, %g)]" %
                                (a[0], a[1], b[0], b[1], w[0], w[1]) for a, b, w in falls)
        s = re.sub(r"const %s := \[\[.*\]\]" % view.falls_const, "const %s := %s" % (view.falls_const, one), s, count=1)
        open(path, "w").write(s)


def main() -> None:
    args = sys.argv[1:]
    out_dir = None
    if args[:1] == ["--out"]:
        out_dir = args[1]
        args = args[2:]
        os.makedirs(out_dir, exist_ok=True)
    for name in args or list(VIEWS):
        view = VIEWS[name]
        dest = os.path.join(out_dir, name + "_vista.png") if out_dir else os.path.join(ROOT, view.out)
        falls = paint(view, dest)
        print("  falls:", falls)
        if not out_dir:
            fix_scene(view, falls)
        print("painted", dest)


if __name__ == "__main__":
    main()
