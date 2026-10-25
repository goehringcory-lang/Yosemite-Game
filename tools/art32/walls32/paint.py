#!/usr/bin/env python3
"""Paints the Valley's cliff walls again, natively for the 32px game, as the
real cliffs: each wall is drawn from the USGS's lidar heights of the cliff that
really stands over that place, seen straight on from its foot (El Capitan over
its meadow, the Three Brothers over Leidig Meadow, Sentinel Rock, Cathedral
Rocks with Bridalveil Fall, the Royal Arches and Washington Column, the
Glacier Point Apron over Curry Village...).

The shape and the light come from the terrain: every pixel knows the real
patch of rock it shows and which way that faces, so buttresses, prows, roofs,
ledges and gullies fall where they are and catch the game's light from the
upper left. Over that the granite gets what makes it Yosemite's: black
streaks down the faces below each notch in the rim where water runs off,
golden-tan staining, cream scars where slabs have fallen, cracks and the
curving edges of exfoliation sheets, brush on the ledges, forest on every
bench and talus slope and beyond the rim. The Valley's south wall is drawn
with west on the left, as the scenes are laid out, so it reads mirrored from
how it looks from the floor.

Each picture keeps its size and the cliff outline the scene was built with
(the solid CLIFF tiles), so collision is unchanged; waterfalls are lined up
under the animated falls already hanging there.

    godot --headless --path . res://tools/art32/ground32/dump.tscn -- DUMP_DIR
    python3 tools/art32/walls32/paint.py DUMP_DIR [region ids]
    python3 tools/art32/walls32/paint.py --out DIR DUMP_DIR [ids]      # write elsewhere, to look first
    python3 tools/art32/walls32/paint.py --preview DIR DUMP_DIR [ids]  # the bare render, anchors marked

The first run downloads the heights (cached in tools/art32/walls32/cache/,
git-ignored). Then `godot --headless --path . --import`. Pillow and numpy.
"""
from __future__ import annotations

import json
import math
import os
import sys
from dataclasses import dataclass, field

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, ".."))

import dem as D  # noqa: E402
import elevation as EV  # noqa: E402
from pixel32 import scale2x  # noqa: E402
from ramps import RAMPS  # noqa: E402

CLIFF, TALUS, FALLS = 8, 9, 14
LIGHT = np.array([-0.56, 0.66, 0.5], np.float32)  # picture right, up, toward the viewer
LIGHT /= np.linalg.norm(LIGHT)
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], np.float32) / 16.0
SKIRT = 44  # art pixels of talus skirt below the cliff line (the 16px builders' SKIRT)


@dataclass
class Look:
    """One view a wall's picture is drawn from. A wall joins one or more."""
    anchor: tuple[float, float, float]  # a real point (lat, lon) and the sprite x it stands at
    # a second point and its sprite x: sets the scale (and, walking, squares
    # the view to the two); or else give the azimuth and the scale
    toward: tuple[float, float, float] | None = None
    azimuth: float | None = None  # walking: the line of sight, degrees east of north
    scale: float | None = None  # walking: metres per sprite pixel across
    # walking past the Valley's south wall the picture is drawn with west on
    # the left, as the scenes are laid out (so it reads mirrored)
    facing: str = "north"
    eye_at: tuple[float, float] | None = None  # a camera: where the eye stands; None walks
    eye: float = 25.0  # the eye's height above the ground
    back: float = 900.0  # walking: the eye's distance out from the foot of the wall
    start: float = 1700.0  # walking: the lines of sight start this far in front of the anchor
    depth: float = 5000.0  # and reach this far past it
    near: float | None = None  # ground nearer the eye than this is looked over (default: 0.6 of [back] walking, 350 m)
    per_px: float | None = None  # a camera without [toward]: degrees of azimuth per sprite pixel
    turn: str = "short"  # a camera with [toward]: which way it turns from anchor to toward ("short", "cw", "ccw")
    # the vertical scale: the highest skyline near the anchor stands [fit] rows
    # below the top; or, with [squash], each row is that many times the
    # metres of a column across (a tall wall on a thin strip is cut off at
    # the top rather than squashed flat)
    fit: float = 6.0
    fit_span: float = 500.0  # sprite pixels either side of the anchor the fit looks at
    # more places along the wall to fit the skyline: (sprite x, rows below the
    # top; less than 0 runs it off the top)
    fits: list = field(default_factory=list)
    squash: float | None = None
    x0: float = -1e9  # the sprite columns this look paints
    x1: float = 1e9
    res: float = 2.0  # metres per cell of the heights


@dataclass
class Wall:
    sprite: str
    looks: list[Look]
    base_z: float  # the Valley floor's height at the foot of the wall
    fall: str = ""  # the animated fall hanging on this wall
    seed: int = 1
    warm: float = 0.25  # share of the granite that weathers gold-tan
    streaks: float = 1.0  # how streaked the faces are
    # (kind, [(metres right of the first look's anchor, height)...]) patches
    # of rock of their own (diorite, fresh scars)
    features: list = field(default_factory=list)
    blend: float = 64.0  # sprite pixels over which two looks dissolve into each other
    # what grows on the slopes: "conifer" (the Valley's pine and fir forest)
    # or "foothill" (the Merced canyon below the Valley: live oak, gray pine,
    # chaparral and grass cured gold)
    flora: str = "conifer"


# El Capitan's Nose: its toe, found in the lidar (the prow's southernmost
# point, just below the summit).
NOSE = (37.72859, -119.63704)
HALF_DOME = (37.74600, -119.53325)
WASHINGTON_COLUMN = (37.74853, -119.56005)

WALLS: dict[str, Wall] = {
    # El Capitan over its meadow: the Nose at the climb, the Southwest Face
    # to its left in the sun, the Southeast Face to its right in shade with the
    # North America Wall, out to the East Buttress and Manure Pile Buttress
    "el_capitan_meadow": Wall(
        "assets/sprites/valley/el_capitan_wall.png",
        [Look(NOSE + (1296.0,), toward=(37.73050, -119.61990, 2128.0))],  # Manure Pile Buttress, at the Nutcracker
        base_z=1220.0, seed=101, warm=0.38,
        features=[
            # the North America Wall: diorite on the Southeast Face, shaped like
            # the continent (Alaska up left, Florida down right, Central America
            # trailing away below)
            ("diorite", [(110, 2010), (170, 2065), (250, 2080), (300, 2105), (360, 2090), (400, 2050), (430, 2080),
                         (500, 2105), (580, 2095), (640, 2060), (650, 2000), (620, 1950), (640, 1900), (600, 1880),
                         (560, 1840), (545, 1770), (525, 1750), (515, 1810), (470, 1825), (420, 1790), (395, 1730),
                         (360, 1680), (325, 1635), (300, 1590), (290, 1635), (310, 1690), (300, 1740), (260, 1790),
                         (230, 1850), (200, 1920), (150, 1950), (120, 1980)]),
        ]),
    # the Three Brothers over Leidig Meadow, seen square to the north wall
    # from the meadow: three tilted blocks stepping up to the north, Lower
    # Brother, Middle Brother and Eagle Peak
    "leidig_meadow": Wall(
        "assets/sprites/valley/three_brothers_wall.png",
        [Look((37.73983, -119.61397, 976.0), azimuth=329.0, scale=2.0)], base_z=1212.0, seed=102, warm=0.3),
    # Sentinel Rock's tower over the Four Mile Trailhead
    "four_mile_trailhead": Wall(
        "assets/sprites/valley/sentinel_wall.png",
        [Look((37.72886, -119.59446, 1488.0), azimuth=178.0, scale=1.8, facing="south", depth=1300.0, back=650.0)],
        base_z=1212.0, fall="SentinelFall", seed=103),
    # Cathedral Rocks: Bridalveil Fall from its hanging valley, Lower, Middle
    # and Higher Cathedral Rock, the Cathedral Spires standing free
    "bridalveil_fall": Wall(
        "assets/sprites/valley/cathedral_wall.png",
        [Look((37.7168, -119.6468, 720.0), toward=(37.7136, -119.6326, 1616.0), facing="south", depth=1700.0,
              fits=[(1200.0, 4.0), (1616.0, 6.0)])],
        base_z=1215.0, fall="BridalveilFall", seed=104, warm=0.3),
    # the Royal Arches over Ahwahnee Meadow
    "ahwahnee_meadow": Wall(
        "assets/sprites/valley/royal_arches_wall.png",
        [Look((37.7486, -119.5700, 1104.0), azimuth=8.0, scale=1.6)], base_z=1215.0, seed=105, streaks=1.4,
        features=[("arches", {"at": (37.7488, -119.5690), "z": 1230.0, "depth": 13.0,
                              "arcs": [(250, 150), (340, 205), (430, 260), (520, 315), (610, 370), (700, 425)]})]),
    # the Royal Arches behind the hotel, the cascade at their west end,
    # Washington Column to the east
    "the_ahwahnee": Wall(
        "assets/sprites/ahwahnee/royal_arches_wall.png",
        [Look((37.7496, -119.5712, 364.0), azimuth=4.0, scale=1.05)],
        base_z=1215.0, fall="RoyalArchCascade", seed=106, streaks=1.4,
        features=[("arches", {"at": (37.7488, -119.5690), "z": 1230.0, "depth": 13.0,
                              "arcs": [(250, 150), (340, 205), (430, 260), (520, 315), (610, 370), (700, 425)]})]),
    # Housekeeping Camp: the cliffs under Glacier Point across the river
    "housekeeping_camp": Wall(
        "assets/sprites/valley/housekeeping_wall.png",
        [Look((37.7350, -119.5803, 1024.0), azimuth=180.0, scale=1.6, facing="south", squash=1.7)],
        base_z=1212.0, seed=107),
    # Curry Village: the foot of Glacier Point's wall, Staircase Falls and the
    # Glacier Point Apron, the wall going on up out of sight
    "curry_village": Wall(
        "assets/sprites/curry/curry_wall.png",
        [Look((37.7350, -119.5749, 2288.0), azimuth=185.0, scale=1.4, facing="south", squash=1.7)],
        base_z=1215.0, fall="StaircaseFalls", seed=108),
    # Upper Pines: the wall under Glacier Point's east shoulder
    "upper_pines": Wall(
        "assets/sprites/valley/upper_pines_wall.png",
        [Look((37.7318, -119.5650, 1024.0), azimuth=180.0, scale=1.6, facing="south", squash=1.7)],
        base_z=1220.0, seed=109),
    # Happy Isles: Half Dome over the shoulders at the mouth of the Merced's canyon
    "happy_isles": Wall(
        "assets/sprites/valley/happy_isles_wall.png",
        [Look(HALF_DOME + (1616.0,), toward=WASHINGTON_COLUMN + (1100.0,), eye_at=(37.7400, -119.5705), eye=30.0,
              depth=9000.0, fit_span=1400.0, res=3.0)],
        base_z=1225.0, seed=110),
    # Tenaya Creek: Washington Column and the wall north of the creek
    "tenaya_creek": Wall(
        "assets/sprites/valley/tenaya_wall.png",
        [Look(WASHINGTON_COLUMN + (1024.0,), azimuth=15.0, scale=1.7)], base_z=1225.0, seed=111),
    # Mirror Lake: the panorama from below the lake, turning through north:
    # Washington Column (Astroman) on the left under North Dome, Mount
    # Watkins over Tenaya Canyon, Clouds Rest at its head, and Half Dome's
    # northwest face looming on the right
    "mirror_lake": Wall(
        "assets/sprites/valley/mirror_lake_wall.png",
        [Look(WASHINGTON_COLUMN + (400.0,), toward=HALF_DOME + (1616.0,), eye_at=(37.7445, -119.5555), eye=30.0,
              turn="cw", depth=8000.0, fit_span=1200.0, near=300.0, res=4.0, fits=[(1000.0, 8.0)])],
        base_z=1240.0, seed=112, streaks=1.5),
    # El Portal: the Merced canyon's north side over the town, steep brushy
    # slopes and granite outcrops, then up the canyon to Arch Rock
    "el_portal": Wall(
        "assets/sprites/valley/el_portal_wall.png",
        [Look((37.6760, -119.7836, 1680.0), azimuth=350.0, scale=1.6, x1=2700.0, back=700.0, fit=4.0),
         Look((37.6890, -119.7296, 3408.0), azimuth=330.0, scale=1.6, x0=2700.0, back=700.0, fit=4.0, fit_span=900.0)],
        base_z=600.0, seed=114, warm=0.45, streaks=0.5, flora="foothill"),
    # Crow's Camp: the wall of Tenaya Canyon above the creek, past Mirror Lake
    "crows_camp": Wall(
        "assets/sprites/valley/crows_camp_wall.png",
        [Look((37.7480, -119.5420, 1184.0), azimuth=345.0, scale=1.6, back=600.0)],
        base_z=1260.0, seed=115, streaks=1.3),
    # Yosemite Village and Camp 4: the foot of the north wall, Lower Yosemite
    # Fall in its gully, the wall going on up out of sight
    "yosemite_village": Wall(
        "assets/sprites/buildings/village_wall.png",
        [Look((37.7514, -119.5971, 1424.0), azimuth=2.0, scale=1.25, squash=1.7)],
        base_z=1215.0, fall="LowerYosemiteFall", seed=113),
}


# ------------------------------------------------------------------ helpers

def blur(a: np.ndarray, sigma: float) -> np.ndarray:
    """Separable Gaussian blur (edges clamped)."""
    if sigma <= 0:
        return a
    r = max(1, int(sigma * 2.5))
    k = np.exp(-0.5 * (np.arange(-r, r + 1) / sigma) ** 2).astype(np.float32)
    k /= k.sum()
    out = a.astype(np.float32)
    for axis in (0, 1):
        p = np.pad(out, [(r, r) if i == axis else (0, 0) for i in range(2)], mode="edge")
        acc = np.zeros_like(out)
        n = out.shape[axis]
        for i, w in enumerate(k):
            acc += w * (p[i:i + n] if axis == 0 else p[:, i:i + n])
        out = acc
    return out


def noise(w: int, h: int, cell: float, seed: int) -> np.ndarray:
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


def inside(u: np.ndarray, z: np.ndarray, poly: list[tuple[float, float]]) -> np.ndarray:
    """Which of the points (u, z) lie inside the polygon, by the even-odd rule."""
    res = np.zeros(u.shape, bool)
    n = len(poly)
    for i in range(n):
        u0, z0 = poly[i]
        u1, z1 = poly[(i + 1) % n]
        if z0 == z1:
            continue
        cond = (z >= min(z0, z1)) & (z < max(z0, z1))
        uc = u0 + (z - z0) * (u1 - u0) / (z1 - z0)
        res ^= cond & (u < uc)
    return res


def stretched_noise(w: int, h: int, cx: float, cy: float, seed: int) -> np.ndarray:
    """Smooth noise 0..1 with its lattice [param cx] apart across and
    [param cy] apart down: stains that run down the fall line."""
    rng = np.random.default_rng(seed)
    gh, gw = int(h / cy) + 3, int(w / cx) + 3
    lat = rng.random((gh, gw)).astype(np.float32)
    ys = np.arange(h) / cy
    xs = np.arange(w) / cx
    y0 = ys.astype(int)
    x0 = xs.astype(int)
    fy = ys - y0
    fx = xs - x0
    fy = (fy * fy * (3 - 2 * fy))[:, None]
    fx = (fx * fx * (3 - 2 * fx))[None, :]
    a = lat[y0][:, x0] * (1 - fx) + lat[y0][:, x0 + 1] * fx
    b = lat[y0 + 1][:, x0] * (1 - fx) + lat[y0 + 1][:, x0 + 1] * fx
    return (a * (1 - fy) + b * fy).astype(np.float32)


def yy_rel(h: int, w: int) -> np.ndarray:
    """0 at the top row .. 1 at the bottom, for every pixel."""
    return np.repeat((np.arange(h, dtype=np.float32) / max(1, h - 1))[:, None], w, axis=1)


def poly_mask(w: int, h: int, pts: list[tuple[float, float]]) -> np.ndarray:
    """Pixels inside a polygon (picture coordinates), by the even-odd rule."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    xx += 0.5
    yy += 0.5
    inside = np.zeros((h, w), bool)
    n = len(pts)
    for i in range(n):
        x0, y0 = pts[i]
        x1, y1 = pts[(i + 1) % n]
        if y0 == y1:
            continue
        cond = (yy >= min(y0, y1)) & (yy < max(y0, y1))
        xc = x0 + (yy - y0) * (x1 - x0) / (y1 - y0)
        inside ^= cond & (xx < xc)
    return inside


class Frame:
    """Where the real world lands in a walking look's picture (art pixels)."""

    def __init__(self, look: Look, W: int, base_z: float) -> None:
        la, lo, xa = look.anchor
        self.ea, self.na = D.utm(la, lo)
        if look.toward is not None:
            lb, lob, xb = look.toward
            eb, nb = D.utm(lb, lob)
            rx, ry = eb - self.ea, nb - self.na
            ln = math.hypot(rx, ry)
            rx, ry = rx / ln, ry / ln
            # the picture's right is the line A->B; the sight line runs at
            # right angles to it, toward the wall
            az = math.degrees(math.atan2(-ry, rx)) % 360.0
            if look.facing == "south":
                az = (az + 180.0) % 360.0
        else:
            az = look.azimuth
        self.azimuth = az
        a = math.radians(az)
        fwd = (math.sin(a), math.cos(a))
        right = (math.cos(a), -math.sin(a))
        if look.facing == "south":
            right = (-right[0], -right[1])  # west on the left, as the scenes are laid out
        self.fwd, self.right = fwd, right
        if look.toward is not None:
            ub = (eb - self.ea) * right[0] + (nb - self.na) * right[1]
            self.scale_h = ub / ((xb - xa) / 2.0)  # metres per art pixel
        else:
            self.scale_h = look.scale * 2.0
        self.cx = xa / 2.0
        self.W = W
        self.base_z = base_z
        self.base_rows: np.ndarray | None = None
        self.scale_vs: np.ndarray | None = None

    def px(self, du: float, z: float) -> tuple[float, float]:
        """Picture position of a point [param du] metres right of the anchor
        along the wall, at height [param z]."""
        x = self.cx + du / self.scale_h
        c = int(min(max(x, 0), self.W - 1))
        return x, self.base_rows[c] - (z - self.base_z) / self.scale_vs[c]


def bearing(e0: float, n0: float, e1: float, n1: float) -> float:
    return math.degrees(math.atan2(e1 - e0, n1 - n0)) % 360.0


def load_dump(dump_dir: str, rid: str) -> dict:
    with open(os.path.join(dump_dir, rid + ".json")) as f:
        return json.load(f)


def cliff_rows(dump: dict) -> np.ndarray:
    """For every tile column, how many rows of solid cliff the scene has."""
    w, h, k = dump["w"], dump["h"], dump["kinds"]
    out = np.zeros(w, np.int32)
    for x in range(w):
        r = 0
        while r < h and k[r * w + x] in (CLIFF, FALLS):
            r += 1
        out[x] = r
    return out


# ------------------------------------------------------------------ painting

class Painting:
    def __init__(self, W: int, H: int) -> None:
        self.names = list(RAMPS)
        self.ramps = [np.array([tuple(int(c[i:i + 2], 16) for i in (0, 2, 4)) for c in RAMPS[n]], np.uint8)
                      for n in self.names]
        self.mat = np.full((H, W), -1, np.int16)
        self.val = np.zeros((H, W), np.float32)
        self.dither = {n: 0.36 for n in self.names}

    def m(self, name: str) -> int:
        return self.names.index(name)

    def put(self, mask: np.ndarray, mat: str, val) -> None:
        self.mat[mask] = self.m(mat)
        if isinstance(val, np.ndarray):
            self.val[mask] = val[mask]
        else:
            self.val[mask] = val

    def render(self) -> np.ndarray:
        H, W = self.mat.shape
        out = np.zeros((H, W, 4), np.uint8)
        bay = np.tile(BAYER, (H // 4 + 1, W // 4 + 1))[:H, :W] - 0.47
        for i, name in enumerate(self.names):
            m = self.mat == i
            if not m.any():
                continue
            ramp = self.ramps[i]
            n = len(ramp)
            v = np.clip(self.val, 0, 1) * (n - 1) + bay * self.dither[name]
            idx = np.clip(np.floor(v + 0.5), 0, n - 1).astype(int)
            out[m, :3] = ramp[idx[m]]
            out[m, 3] = 255
        return out


def soften(line: np.ndarray, k: int = 24) -> np.ndarray:
    """The scene's cliff line (tile steps) as a smooth curve."""
    p = np.pad(line.astype(np.float32), k, mode="edge")
    return np.convolve(p, np.ones(2 * k + 1) / (2 * k + 1), mode="same")[k:-k]


def blur_xy(a: np.ndarray, sx: float, sy: float) -> np.ndarray:
    """A Gaussian blur with its own width across and down."""
    out = a.astype(np.float32)
    for axis, sigma in ((1, sx), (0, sy)):
        if sigma <= 0:
            continue
        r = max(1, int(sigma * 2.5))
        k = np.exp(-0.5 * (np.arange(-r, r + 1) / sigma) ** 2).astype(np.float32)
        k /= k.sum()
        p = np.pad(out, [(r, r) if i == axis else (0, 0) for i in range(2)], mode="edge")
        acc = np.zeros_like(out)
        n = out.shape[axis]
        for i, w in enumerate(k):
            acc += w * (p[i:i + n] if axis == 0 else p[:, i:i + n])
        out = acc
    return out


def _heights(e0: float, n0: float, e1: float, n1: float, res: float) -> tuple[D.DEM, np.ndarray]:
    e0, e1 = math.floor(e0 / 100) * 100 - 100, math.ceil(e1 / 100) * 100 + 100
    n0, n1 = math.floor(n0 / 100) * 100 - 100, math.ceil(n1 / 100) * 100 + 100
    dm = D.fetch(e0, n0, e1, n1, res)
    raw_slope = np.degrees(np.arctan(np.hypot(dm.dzde, dm.dzdn)))
    # smooth the lidar a little: a cliff's cells are noisy, and it would show
    # as vertical stripes
    return D.DEM(blur(dm.z, 1.6 * 2.0 / res), dm.e0, dm.n1, dm.res), raw_slope


def _look_view(look: Look, wall: Wall, W: int, H: int, soft: np.ndarray, falls: list[float]) -> tuple[EV.View, Frame | None]:
    """Renders one look over the whole picture's width. [param falls]: the
    sprite x of each fall hanging from the top, where the rim must run off
    the top of the picture (a fall can't pour out of the sky)."""
    xa = look.anchor[2]
    fit = [((xa - look.fit_span) / 2.0, (xa + look.fit_span) / 2.0, look.fit)]
    for x, pad in look.fits:
        fit.append(((x - 120.0) / 2.0, (x + 120.0) / 2.0, pad))
    for x in falls:
        if look.x0 - wall.blend <= x <= look.x1 + wall.blend:
            # the fall's own fit wins over any other close by
            fit = [f for f in fit if abs((f[0] + f[1]) / 2.0 - x / 2.0) > 100.0]
            fit.append(((x - 40.0) / 2.0, (x + 40.0) / 2.0, -10.0))
    if look.eye_at is None:
        fr = Frame(look, W, wall.base_z)
        us = (np.array([0, W]) - fr.cx) * fr.scale_h
        es, ns = [], []
        for u in us:
            # the eyes walk up to the foot of the wall, so their lines reach
            # as far again past it
            for t in (-look.start, look.depth + look.start):
                es.append(fr.ea + u * fr.right[0] + t * fr.fwd[0])
                ns.append(fr.na + u * fr.right[1] + t * fr.fwd[1])
        dm, raw_slope = _heights(min(es), min(ns), max(es), max(ns), look.res)
        view = EV.walk(dm, e=fr.ea, n=fr.na, azimuth=fr.azimuth, W=W, H=H, cx=fr.cx, scale_h=fr.scale_h,
                       base_z=wall.base_z, base_row=soft, eye=look.eye, d0=look.back, fit=fit, start=look.start,
                       depth=look.depth, mirror=look.facing == "south",
                       near=look.near if look.near is not None else 0.6 * look.back,
                       squash=None if look.squash is None else look.squash * fr.scale_h)
        fr.base_rows = soft
        fr.scale_vs = view.scale_v
        h_m = fr.scale_h
    else:
        fr = None
        ee, en = D.utm(*look.eye_at)
        ea, na = D.utm(look.anchor[0], look.anchor[1])
        az_a = bearing(ee, en, ea, na)
        if look.toward is not None:
            eb, nb = D.utm(look.toward[0], look.toward[1])
            az_b = bearing(ee, en, eb, nb)
            d_az = (az_b - az_a + 180.0) % 360.0 - 180.0
            if look.turn == "cw" and d_az < 0:
                d_az += 360.0
            elif look.turn == "ccw" and d_az > 0:
                d_az -= 360.0
            per = d_az / ((look.toward[2] - xa) / 2.0)  # degrees per art pixel
        else:
            per = look.per_px * 2.0

        def az_at(c: float) -> float:
            return az_a + (c - xa / 2.0) * per

        pts_e, pts_n = [ee], [en]
        for c in np.linspace(0, W, 24):
            a = math.radians(az_at(c))
            pts_e.append(ee + look.depth * math.sin(a))
            pts_n.append(en + look.depth * math.cos(a))
        dm, raw_slope = _heights(min(pts_e), min(pts_n), max(pts_e), max(pts_n), look.res)
        d_a = math.hypot(ea - ee, na - en)
        h_m = math.radians(abs(per)) * d_a
        view = EV.camera(dm, e=ee, n=en, eye=look.eye, W=W, H=H, az_at=az_at, base_z=wall.base_z, base_row=soft,
                         d0=d_a, fit=fit, depth=look.depth, near=look.near if look.near is not None else 350.0,
                         squash=None if look.squash is None else look.squash * h_m)
    # how steep the real ground is where each pixel looks, from the unsmoothed
    # heights (a cliff stays a cliff)
    view.slope = np.maximum(view.slope, dm.sample(view.e, view.n, raw_slope) * 0.85)
    view.m_across = h_m
    sq = float(np.median(view.scale_v)) / h_m
    print(f"   look at x={xa:.0f}: {h_m:.2f} m per art pixel across, {float(np.median(view.scale_v)):.2f} up"
          f" (x{sq:.2f})")
    return view, fr


def paint(wall: Wall, dump: dict, preview: bool = False) -> np.ndarray:
    sprite_path = os.path.join(ROOT, wall.sprite)
    SW, SH = Image.open(sprite_path).size
    W, H = SW // 2, SH // 2
    tiles = cliff_rows(dump)
    T = dump["tile"]
    # the cliff line per art column (art rows), as the scene's solid tiles have it
    line = np.repeat(tiles * (T // 2), T // 2)[:W].astype(np.float32)
    if len(line) < W:
        line = np.pad(line, (0, W - len(line)), mode="edge")
    soft = soften(line)
    view, fr = None, None
    bay = np.tile(BAYER, (H // 4 + 1, W // 4 + 1))[:H, :W]
    xs = (np.arange(W, dtype=np.float32) + 0.5) * 2.0
    falls = [a["x"] + a["w"] / 2.0 for a in dump.get("anims", []) if a["name"] == wall.fall and a["y"] < 24]
    for i, look in enumerate(wall.looks):
        v, f = _look_view(look, wall, W, H, soft, falls)
        if fr is None:
            fr = f
        if view is None:
            view = v
            continue
        # dissolve into the new look across [blend] sprite pixels at its edges
        b = wall.blend / 2.0
        w_in = np.clip((xs - (look.x0 - b)) / max(1.0, 2 * b), 0, 1) * np.clip(((look.x1 + b) - xs) / max(1.0, 2 * b), 0, 1)
        view.take(v, bay < w_in[None, :])
    if preview:
        return _preview(view, wall, W, H, line)
    return _compose(view, fr, wall, dump, W, H, line, soft)


def _preview(view, wall: Wall, W: int, H: int, line: np.ndarray) -> np.ndarray:
    d = np.clip(view.nx * LIGHT[0] + view.ny * LIGHT[1] + view.nz * LIGHT[2], 0, 1)
    g = (40 + 200 * d).astype(np.uint8)
    rgb = np.stack([g, g, g], -1)
    veg = view.hit & (view.slope < 34)
    rgb[veg] = (rgb[veg] * np.array([0.45, 0.75, 0.45])).astype(np.uint8)
    rgb[~view.hit] = (40, 60, 90)
    for look in wall.looks:
        for pt in (look.anchor, look.toward):
            if pt is None:
                continue
            x = int(pt[2] / 2)
            if 0 < x < W:
                rgb[:, max(0, x - 1):x + 1] = (255, 60, 60)
    for x in range(W):
        y = int(line[x])
        if 0 <= y < H:
            rgb[y, x] = (255, 220, 0)
    out = np.zeros((H, W, 4), np.uint8)
    out[..., :3] = rgb
    out[..., 3] = 255
    return out.repeat(2, 0).repeat(2, 1)


def _compose(view, fr: Frame, wall: Wall, dump: dict, W: int, H: int, line: np.ndarray, soft: np.ndarray,
             keep: np.ndarray | None = None, masks=None, finish=None) -> np.ndarray:
    """Paints the picture. With [param keep] (a freestanding rock: which
    pixels are part of it), everything else is left transparent: no sky, no
    skirt to a cliff line. [param masks] (forest, brush, talus) says where
    each goes, rather than by slope. [param finish] (P, rock, shade) -> mask
    paints the rock's own details and its trees in place of the walls'
    exfoliation arcs and forest, and returns the pixels it drew outside
    [param keep]."""
    rng = np.random.default_rng(wall.seed)
    P = Painting(W, H)
    hit = view.hit
    # ---- light: the surface's own facing, softened across columns (each
    # column is its own line of sight, and the lidar's noise would stripe it)
    nx, ny, nz = blur_xy(view.nx, 5.0, 2.0), blur_xy(view.ny, 5.0, 2.0), blur_xy(view.nz, 5.0, 2.0)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz) + 1e-6
    nx, ny, nz = nx / ln, ny / ln, nz / ln
    diff = np.clip(nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2], 0, 1)
    slope = view.slope
    dist = blur_xy(view.dist, 1.2, 0.0)
    # roofs and ledges: where the rock just above stands nearer, this is in its
    # shade; where it steps back, this is a lit lip
    up1 = np.vstack([dist[:1], dist[:-1]])
    up3 = np.vstack([dist[:3], dist[:-3]])
    under = np.clip((dist - np.minimum(up1, up3) - 5.0) / 22.0, 0, 1)
    lip = np.clip((up1 - dist - 8.0) / 25.0, 0, 1)
    shade = 0.22 + 0.74 * diff - 0.28 * under + 0.1 * lip
    shade += (noise(W, H, 60, wall.seed) - 0.5) * 0.05
    shade = blur_xy(shade, 1.2, 0.6)
    # distance: the far rock is paler and flatter in the haze
    hitd = view.dist[hit]
    near_d = np.percentile(hitd, 20) if hitd.size else 0.0
    haze = np.clip((view.dist - near_d) / 2600.0, 0, 0.45)
    shade = shade + (0.62 - shade) * haze
    # silhouettes: where a nearer buttress, tower or rim stands in front of
    # rock farther back, its edge is drawn dark, so the layers read apart
    dd = view.dist
    sil = np.zeros((H, W), bool)
    for dy, dx in ((-1, 0), (-2, 0)):
        nb = np.roll(dd, -dy, 0)
        nbh = np.roll(hit, -dy, 0)
        sil |= hit & (~nbh | (nb - dd > np.maximum(80.0, dd * 0.1)))
    for dx in (-1, 1):
        # across, a step must hold over two columns (a sight line grazing a
        # face flickers between near and far)
        nb1 = np.roll(dd, -dx, 1)
        nb2 = np.roll(dd, -2 * dx, 1)
        sil |= hit & (nb1 - dd > np.maximum(150.0, dd * 0.15)) & (nb2 - dd > np.maximum(150.0, dd * 0.15))
    sil[0, :] = False
    shade = np.where(sil, shade - 0.34, shade)
    # ---- what grows where: forest on benches and talus, brush on the ledges
    n_veg = noise(W, H, 5, wall.seed + 1)
    big = noise(W, H, 30, wall.seed + 4)
    far_cut = (np.percentile(hitd, 75) + 300) if hitd.size else 1e9
    far = hit & (dist > far_cut)
    # the ground just in front of the cliff, where the sight line meets the
    # Valley floor: the forest at the foot
    front = hit & (view.dist < 250.0)
    # the foothill canyon's slopes hold soil and brush far steeper than the
    # Valley's granite does: only its outcrops and cliffs are bare
    veg_slope = 31.0 if wall.flora != "foothill" else 44.0
    forest = hit & ((slope < veg_slope + 6 * (n_veg - 0.5)) | front)
    # the talus slopes under the walls: blocks of fallen granite with trees
    # growing among them, the trees in clumps and the boulders showing
    # between (the steeper, the more boulders)
    stand = noise(W, H, 7, wall.seed + 11) * 0.7 + noise(W, H, 2.5, wall.seed + 12) * 0.3
    talus = forest & ~front & (slope > 20) & (stand < (slope - 20) / 22 * 0.55)
    forest &= ~talus
    # brush in clumps on the ledges and low-angle slabs, not a sprinkle
    clump = noise(W, H, 14, wall.seed + 6) * 0.6 + n_veg * 0.4
    brush = hit & ~forest & ~talus & (slope < 40) & (clump > 0.64 - (40 - slope) / 45)
    if masks is not None:
        forest, brush, talus = masks
    veg = forest | brush
    rock = hit & ~veg & ~talus
    # ---- the rock
    P.put(rock, "granite", shade)
    bay = np.tile(BAYER, (H // 4 + 1, W // 4 + 1))[:H, :W]
    # gold-tan weathering: in long stains down the fall line, mostly on the
    # sunny faces, and under the roofs where water seeps out
    broad = stretched_noise(W, H, 40.0, 140.0, wall.seed + 4) * 0.75 + noise(W, H, 12, wall.seed + 5) * 0.25
    warm = rock & ((broad + (bay - 0.5) * 0.08 < wall.warm) & (diff > 0.3) | (under > 0.45))
    P.put(warm, "warm", shade + 0.02)
    # cracks: thin dark joints down the faces, lit on their left lip
    for _ in range(int(W / 9)):
        x = rng.uniform(0, W)
        y = rng.uniform(0, H * 0.8)
        run = rng.uniform(5, 30)
        wob = rng.uniform(0.2, 0.8)
        for i in range(int(run)):
            xi = int(x + math.sin(i * 0.35 + x) * wob)
            yi = int(y + i)
            if 1 <= xi < W - 1 and 0 <= yi < H and rock[yi, xi] and slope[yi, xi] > 60:
                P.val[yi, xi] -= 0.22
                P.val[yi, xi - 1] += 0.05
    # exfoliation: the edges of sheets peeling off the faces, short curved
    # arcs lit above and dark below, following the curve of the rock
    for _ in range(int(W / 14) if finish is None else 0):
        x = rng.uniform(0, W)
        y = rng.uniform(4, H * 0.8)
        xi, yi = int(x), int(y)
        if not (0 <= xi < W and 0 <= yi < H) or not rock[yi, xi] or slope[yi, xi] < 55:
            continue
        span = rng.uniform(6, 18)
        bow = rng.uniform(1.5, 4.0) * (1 if rng.random() < 0.7 else -1)
        for k in range(int(span)):
            f = k / span
            ax = int(x + k - span / 2)
            ay = int(y - bow * (1 - (2 * f - 1) ** 2))
            if 0 <= ax < W and 1 <= ay < H - 1 and rock[ay, ax]:
                P.val[ay, ax] -= 0.2
                P.val[ay - 1, ax] += 0.08
    # features: diorite, fresh scars, the Royal Arches
    _features(P, view, fr, wall, rock, shade, W, H)
    # black streaks: below the notches in the rim, under the roofs, down the faces
    _streaks(P, view, rock, slope, W, H, rng, wall, under)
    # ---- the talus, the forest and brush
    _talus(P, talus, shade, W, H, wall)
    extra = None
    if finish is None:
        _forest(P, view, forest, brush, far, shade, n_veg, W, H, rng, wall)
    else:
        extra = finish(P, rock, shade)
    # beyond what the sight lines reach: forest on the far rim, in the haze
    # and above the rim the sky, pale at the horizon
    sky = ~hit if extra is None else ~hit & ~extra
    P.put(sky, "sky", 0.92 - 0.75 * (1 - yy_rel(H, W)) ** 0.9)
    P.dither["sky"] = 0.6
    # ---- a fall's gully, if one hangs here
    for a in dump.get("anims", []):
        if a["name"] == wall.fall and wall.fall:
            _gully(P, a, rock | veg, shade, W, H, rng)
    # ---- the talus skirt at the foot, and the cut to the scene's cliff line
    if keep is None:
        out_mask = _skirt(P, view, line, soft, shade, W, H, rng, wall)
    else:
        out_mask = keep if extra is None else keep | extra
    P.dither["granite"] = 0.16
    P.dither["warm"] = 0.16
    img = P.render()
    img[~out_mask] = 0
    return scale2x(img)


def _features(P: Painting, view, fr: Frame | None, wall: Wall, rock: np.ndarray, shade: np.ndarray, W: int,
              H: int) -> None:
    """Patches of rock of their own, placed by each pixel's real point (metres
    along the wall from the first look's anchor, or from the feature's own
    point, and height): the diorite of the North America Wall, fresh scars,
    and the Royal Arches' great curved overhangs."""
    if fr is None:
        return
    u = (view.e - fr.ea) * fr.right[0] + (view.n - fr.na) * fr.right[1]
    for kind, data in wall.features:
        if kind in ("diorite", "fresh"):
            m = inside(u, view.z, data) & rock
            if kind == "diorite":
                veins = (noise(W, H, 2.5, wall.seed + 7) > 0.8) | (noise(W, H, 7, wall.seed + 9) > 0.86)
                P.put(m & ~veins, "diorite", shade * 0.9)
            else:
                P.put(m, "fresh", np.clip(shade * 0.75 + 0.22, 0, 1))
        elif kind == "arches":
            ce, cn = D.utm(*data["at"])
            du = u - ((ce - fr.ea) * fr.right[0] + (cn - fr.na) * fr.right[1])
            dz = view.z - data["z"]
            depth = data.get("depth", 10.0)
            wob = (noise(W, H, 9, wall.seed + 50) - 0.5) * 8.0
            for a, b in data["arcs"]:
                r = np.sqrt((du / a) ** 2 + (dz / b) ** 2)
                d = (1.0 - r) * b + wob  # metres inside the arc, measured up
                # the arch fades out down its legs
                rise = np.clip(dz / b, 0, 1)
                legs = rock & (rise > 0.35 + 0.25 * np.abs(du / a))
                # each arch is an overhang: a band of shade under its lip, the lip lit
                below = legs & (d > 0) & (d < depth)
                lip = legs & (d <= 0) & (d > -3.0)
                P.val[below] -= 0.32 * np.clip(1.0 - d[below] / depth, 0.3, 1.0)
                P.val[lip] += 0.1


def _streaks(P: Painting, view, rock: np.ndarray, slope: np.ndarray, W: int, H: int, rng, wall: Wall,
             under: np.ndarray) -> None:
    """Water runs off the rim at its low points and down the fall line, and
    seeps out from under the roofs, leaving the dark stripes every Yosemite
    wall carries: black where the water runs most of the year, a grey wash
    where it runs only in spring."""
    top = np.full(W, H, np.int32)
    for x in range(W):
        ys = np.nonzero(rock[:, x] & (slope[:, x] > 50))[0]
        if len(ys):
            top[x] = ys[0]
    sm = np.convolve(np.pad(top.astype(np.float32), 6, mode="edge"), np.ones(13) / 13, mode="same")[6:-6]
    strong = np.zeros((H, W), np.float32)
    faint = np.zeros((H, W), np.float32)
    last = -99
    for x in range(8, W - 8):
        if top[x] >= H or x - last < 14:
            continue
        # a notch: the rim here lower (a larger row) than on both sides
        prom = sm[x] - 0.5 * (sm[x - 8] + sm[x + 8])
        if prom > 1.2 and rng.random() < 0.65 * wall.streaks:
            _stripe(strong, x + rng.normal(), top[x], rng.uniform(2.0, 5.5), rng.uniform(0.35, 0.95), rock, rng, 0.95)
            # a grey wash either side, where the runoff spreads in spring
            _stripe(faint, x + rng.normal() * 2, top[x], rng.uniform(5.0, 10.0), rng.uniform(0.3, 0.8), rock, rng, 0.8)
            last = x
    # seeps: from under each roof, a short streak down the face below it
    ys, xs = np.nonzero(rock & (under > 0.55))
    if len(ys):
        pick = rng.choice(len(ys), size=min(len(ys), int(W / 30 * wall.streaks)), replace=False)
        for i in pick:
            _stripe(strong if rng.random() < 0.5 else faint, xs[i] + rng.normal(), int(ys[i]) + 1, rng.uniform(1.0, 3.0),
                    rng.uniform(0.15, 0.4), rock, rng, 0.85)
    # and down the big open faces, black bands from top to bottom and grey
    # washes between them
    for _ in range(int(W / 90 * wall.streaks)):
        x = rng.uniform(0, W)
        col = rock[:, int(x)] & (slope[:, int(x)] > 62)
        yy = np.nonzero(col)[0]
        if len(yy) < 30:
            continue
        y0 = int(yy[0] + rng.uniform(0, 0.3) * (yy[-1] - yy[0]))
        _stripe(strong, x, y0, rng.uniform(0.8, 3.2), rng.uniform(0.3, 1.0), rock, rng, 0.9)
    for _ in range(int(W / 40 * wall.streaks)):
        x = rng.uniform(0, W)
        col = rock[:, int(x)] & (slope[:, int(x)] > 55)
        yy = np.nonzero(col)[0]
        if not len(yy):
            continue
        y0 = yy[0] + rng.uniform(0, max(1, (yy[-1] - yy[0]) * 0.5))
        _stripe(faint, x, int(y0), rng.uniform(2.0, 6.0), rng.uniform(0.25, 0.7), rock, rng, rng.uniform(0.5, 0.85))
    # soften each stripe's edge, then keep it solid: water streaks are
    # bands with ragged edges, not dots
    rag = (noise(W, H, 2.0, wall.seed + 40) - 0.5) * 0.25
    steep = rock & (slope > 50)
    wash = steep & (blur_xy(faint, 1.2, 2.0) + rag > 0.4)
    P.val[wash] -= 0.13
    m = steep & (blur_xy(strong, 0.7, 2.0) + rag > 0.42)
    P.put(m, "streak", np.clip(P.val, 0, 1) * 0.75 + 0.1)


def _stripe(acc: np.ndarray, x: float, y0: int, width: float, length: float, rock: np.ndarray, rng, k: float) -> None:
    H, W = acc.shape
    run = int(max(4, (H - y0) * length))
    cx = x
    for i in range(run):
        y = y0 + i
        if y >= H:
            break
        cx += rng.normal() * 0.18
        # a streak is widest a little below its source and wanders as it runs
        wdt = width * (0.7 + 0.6 * math.sin(min(1.0, i / max(1.0, run * 0.4)) * 1.5)) * (0.8 + 0.4 * rng.random())
        fade = k * (1.0 - (i / run) ** 1.4)
        x0, x1 = int(max(0, cx - wdt)), int(min(W, cx + wdt + 1))
        if x1 <= x0:
            continue
        xs = np.arange(x0, x1)
        prof = np.clip(1.15 - np.abs(xs + 0.5 - cx) / max(0.6, wdt), 0, 1) * fade
        acc[y, x0:x1] = np.maximum(acc[y, x0:x1], prof * rock[y, x0:x1])


def _forest(P: Painting, view, forest: np.ndarray, brush: np.ndarray, far: np.ndarray, shade: np.ndarray,
            n_veg: np.ndarray, W: int, H: int, rng, wall: Wall) -> None:
    """Conifers as tight crowns, lit on the left; oaks on the low talus, brush
    on the ledges; the treetops along each stand's upper edge break into the
    rock behind them."""
    # a conifer's crown is about 12 m across and 25 m tall: its size in the
    # picture follows the wall's scale and how far off the forest stands
    yy, xx = np.mgrid[0:H, 0:W]
    v = np.zeros((H, W), np.float32)
    crown = np.zeros((H, W), np.float32)
    lit = np.zeros((H, W), np.float32)
    m_px = float(np.median(view.scale_v))
    d_med = float(np.median(view.dist[forest])) if forest.any() else 1000.0
    for band, (lo, hi) in enumerate(((0.0, 0.7), (0.7, 1.4), (1.4, 99.0))):
        sel = forest & (view.dist >= lo * d_med) & (view.dist < hi * d_med)
        if not sel.any() and band < 2:
            continue
        d_b = float(np.median(view.dist[sel])) if sel.any() else d_med * 2
        # metres per row at that distance (rows widen with distance), and per column
        mv = m_px * d_b / max(1.0, wall.looks[0].back)
        mh = max(0.5, getattr(view, "m_across", 2.0))
        # conifers 12 m across and 25 m tall; the foothills' oaks and
        # chaparral round, about 9 m
        cw_m, ch_m = (12.0, 25.0) if wall.flora != "foothill" else (9.0, 8.0)
        cell_w = int(np.clip(round(cw_m / mh), 3, 8))
        cell_h = int(np.clip(round(ch_m / mv), 3, 12))
        cr, li, _tn = crown_field(W, H, cell_w, cell_h, wall.seed + 20 + band, pointed=wall.flora != "foothill")
        crown = np.where(sel, cr, crown)
        lit = np.where(sel, li, lit)
    # the canopy takes the slope's light broadly: column-to-column flicker in
    # the terrain's facing would stripe it
    canopy = blur_xy(shade, 3.0, 1.5)
    v = 0.18 + 0.5 * canopy + 0.32 * lit * crown - 0.16 * (crown < 0.25)
    low = view.z < wall.base_z + 220.0
    oak = forest & low & (n_veg < 0.4) & (view.slope > 16)
    if wall.flora == "foothill":
        # live oak and chaparral, a gray pine here and there, and between them
        # the grass of the foothills, cured gold by summer, in broad drifts
        drift = stretched_noise(W, H, 16.0, 32.0, wall.seed + 70) * 0.7 + noise(W, H, 4, wall.seed + 72) * 0.3
        grass = forest & (drift > 0.58) & (view.slope < 34)
        P.put(grass, "straw", 0.35 + 0.5 * shade + (noise(W, H, 2, wall.seed + 71) - 0.5) * 0.2)
        forest = forest & ~grass
        oak = forest & (n_veg < 0.62)
        brush = brush | (forest & ~oak)
    con = forest & ~oak
    P.put(con & ~far, "forest", v)
    P.put(con & far, "far", v * 0.85 + 0.12)
    P.put(oak, "oak", v + 0.04)
    P.put(brush, "brush", v + 0.03)
    # treetops breaking up into the rock above
    veg = forest | brush
    above = np.vstack([veg[:1], veg[:-1]])
    edge = forest & ~above
    ys, xs = np.nonzero(edge)
    for y, x in zip(ys, xs):
        if rng.random() < 0.4:
            hgt = int(rng.integers(1, 3))
            for k in range(1, hgt + 1):
                yk = y - k
                if yk < 0:
                    break
                P.mat[yk, x] = P.m("far" if far[y, x] else "forest")
                P.val[yk, x] = 0.25 + 0.3 * shade[y, x]


def crown_field(W: int, H: int, cw: float, ch: float, seed: int, pointed: bool = True,
                size: tuple[float, float] = (0.8, 1.2)) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """A canopy of tree crowns on a staggered, jittered grid of [param cw] x
    [param ch] cells: every pixel belongs to the nearest crown (searching the
    cells round it, so no straight seams run between them). Returns how far
    into its crown each pixel is (1 at the heart, 0 at the rim or in a gap),
    how lit it is from the upper left, and the crown's own random tint."""
    rr = np.random.default_rng(seed)
    gw, gh = int(W / cw) + 4, int(H / ch) + 4
    ox = rr.random((gh, gw)) * 0.7 + 0.15
    oy = rr.random((gh, gw)) * 0.7 + 0.15
    sz = rr.uniform(size[0], size[1], (gh, gw))
    tn = rr.random((gh, gw))
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    yy += 0.5
    xx += 0.5
    gy0 = np.floor(yy / ch).astype(np.int32)
    best = np.full((H, W), 9.0, np.float32)
    bdx = np.zeros((H, W), np.float32)
    bdy = np.zeros((H, W), np.float32)
    btn = np.zeros((H, W), np.float32)
    for dyc in (-1, 0, 1):
        gy = np.clip(gy0 + dyc, 0, gh - 1)
        # every other row of cells shifts half a cell, like brickwork
        shift = (gy % 2) * 0.5
        gx0 = np.floor(xx / cw - shift).astype(np.int32)
        for dxc in (-1, 0, 1):
            gx = np.clip(gx0 + dxc, 0, gw - 1)
            cx = (gx + shift + ox[gy, gx]) * cw
            cy = (gy + oy[gy, gx]) * ch
            s = sz[gy, gx]
            dx = (xx - cx) / (cw * 0.62 * s)
            dy = (yy - cy) / (ch * 0.62 * s)
            if pointed:
                # a conifer: pointed above, broad below
                d = np.abs(dx) * (1.0 + np.clip(-dy, 0, None) * 0.9) + np.abs(dy) * 0.55
            else:
                d = np.sqrt(dx * dx + dy * dy)
            closer = d < best
            best = np.where(closer, d, best)
            bdx = np.where(closer, dx, bdx)
            bdy = np.where(closer, dy, bdy)
            btn = np.where(closer, tn[gy, gx], btn)
    crown = np.clip(1.0 - best, 0, 1)
    lit = np.clip(0.5 - bdx * 0.45 - bdy * 0.2, 0, 1)
    return crown, lit, btn


def _talus(P: Painting, talus: np.ndarray, shade: np.ndarray, W: int, H: int, wall: Wall) -> None:
    """Fallen blocks of granite of every size, each lit on its upper left with
    a dark seam under it, packed into the slope."""
    blocks, lit, tone = crown_field(W, H, 4.0, 3.0, wall.seed + 60, pointed=False, size=(0.7, 1.4))
    v = 0.2 + 0.55 * shade + 0.25 * lit + (tone - 0.5) * 0.2
    seam = blocks < 0.18
    P.put(talus, "granite", np.where(seam, v - 0.32, v))


def _gully(P: Painting, a: dict, solid: np.ndarray, shade: np.ndarray, W: int, H: int, rng) -> None:
    """The wet, mossy cleft a fall pours down: dark rock behind the water,
    green where the spray keeps it damp."""
    cx = (a["x"] + a["w"] / 2.0) / 2.0
    h = (a["y"] + a["h"]) / 2.0
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    wob = np.sin(yy * 0.07 + 0.4) * 1.5 + np.sin(yy * 0.19) * 0.8
    d = np.abs(xx + 0.5 - cx - wob)
    rag = noise(W, H, 3, 78) * 3.0
    wet = solid & (yy < h + 2) & (d < 5 + rag)
    P.put(wet, "wet", shade * 0.7 + 0.1)
    moss = solid & (yy < h + 6) & (d >= 5 + rag) & (d < 9 + rag) & (noise(W, H, 3, 77) > 0.35)
    P.put(moss, "moss", shade * 0.7 + 0.15)


def _skirt(P: Painting, view, line: np.ndarray, soft: np.ndarray, shade: np.ndarray, W: int, H: int, rng,
           wall: Wall) -> np.ndarray:
    """The picture is solid down to the scene's cliff line; below it the talus
    breaks up into blocks and gaps through which the painted ground shows."""
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    edge = soft[None, :] - 2 + (noise(W, H, 4, wall.seed + 30) - 0.5) * 6
    solid = yy < edge
    rr = np.random.default_rng(wall.seed + 31)
    cw, ch = 7, 5
    gw, gh = W // cw + 2, H // ch + 2
    ox = rr.random((gh, gw)) * cw
    oy = rr.random((gh, gw)) * ch
    sz = rr.uniform(0.45, 1.0, (gh, gw))
    keep = rr.random((gh, gw))
    gx = (np.arange(W) // cw)
    gy = (np.arange(H) // ch)
    cxs = gx[None, :] * cw + ox[gy[:, None], gx[None, :]]
    cys = gy[:, None] * ch + oy[gy[:, None], gx[None, :]]
    s = sz[gy[:, None], gx[None, :]]
    dx = (xx + 0.5 - cxs) / (cw * 0.5 * s)
    dy = (yy + 0.5 - cys) / (ch * 0.5 * s)
    r = dx * dx + dy * dy
    depth = (yy - edge) / SKIRT  # 0 at the cliff line .. 1 at the skirt's foot
    block = (r < 1.0) & (yy >= edge) & (keep[gy[:, None], gx[None, :]] > 0.45 + depth * 1.6)
    light = np.clip(0.7 - dx * 0.25 - dy * 0.35, 0, 1)
    P.put(block, "granite", 0.3 + 0.5 * light * (1 - 0.3 * depth))
    seam = block & (dy > 0.55)
    P.val[seam] -= 0.25
    return solid | block


def main() -> None:
    args = sys.argv[1:]
    out_dir = None
    preview = False
    if args[:1] == ["--out"]:
        out_dir = args[1]
        args = args[2:]
    elif args[:1] == ["--preview"]:
        out_dir = args[1]
        preview = True
        args = args[2:]
    if not args:
        sys.exit(__doc__)
    dump_dir, ids = args[0], args[1:]
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)
    for rid, wall in WALLS.items():
        if ids and rid not in ids:
            continue
        img = paint(wall, load_dump(dump_dir, rid), preview)
        name = os.path.basename(wall.sprite)
        dest = os.path.join(out_dir, rid + ("_preview.png" if preview else "_" + name)) if out_dir else os.path.join(ROOT, wall.sprite)
        Image.fromarray(img, "RGBA").save(dest, optimize=True)
        print("painted", rid, "->", dest)


if __name__ == "__main__":
    main()
