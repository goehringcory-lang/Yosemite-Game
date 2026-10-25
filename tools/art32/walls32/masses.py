#!/usr/bin/env python3
"""Paints Tuolumne's freestanding granite (Lembert Dome, Pothole Dome,
Fairview Dome, Cathedral Peak) from the USGS's lidar heights, as each looks
from where people see it, with the cliff painter's granite, streaks and
stains, the broken edges of the dome's exfoliation sheets, and lodgepole
pines: dense round its foot and on its flanks, scattered over its gentler
granite where OpenStreetMap has woods, here and there rooted in a crack.
Only the rock and its fringe of forest are painted: the ground round it is
left transparent, as the scene's sprites stand on its own painted ground.
Each sprite keeps its canvas (the builder lays the solid tiles under it from
that size).

Each outline also covers the granite and cliff tiles the scene was built
with under the sprite (read from the terrain dump, as paint.py reads the
cliff lines): the dome is drawn a little taller if it must be, and the
forest climbs its flanks the rest of the way.

    godot --headless --path . res://tools/art32/ground32/dump.tscn -- DUMP_DIR
    python3 tools/art32/walls32/masses.py DUMP_DIR [names]              # all of them, in place
    python3 tools/art32/walls32/masses.py --out DIR DUMP_DIR [names]    # write elsewhere, to look first

Heights and map are cached in tools/art32/walls32/cache/. Then
`godot --headless --path . --import`.
"""
from __future__ import annotations

import math
import os
import sys
from dataclasses import dataclass

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import dem as D  # noqa: E402
import elevation as EV  # noqa: E402
import osm as O  # noqa: E402
import paint as PT  # noqa: E402


GRANITE, CLIFF = 7, 8  # tools/mapgen/terrain.gd
FOOT = 3.0  # art rows of the canvas under the rock's foot


@dataclass
class Mass:
    sprite: str
    node: str  # the scene node it hangs from (the dump names its sprite's parent)
    summit: tuple[float, float]  # lat, lon of the rock's top
    eye: tuple[float, float]  # where it is seen from
    radius: float  # metres round the summit that belong to the rock
    floor: float  # height of the ground at its foot (below this is left out)
    width: float = 0.96  # share of the canvas the rock spans across
    pad: float = 4.0  # art rows from the top to the summit
    eye_h: float = 1.7
    seed: int = 300
    warm: float = 0.2
    streaks: float = 0.8
    trees: float = 1.0  # how thickly its mapped woods are planted
    stretch: tuple[float, float] = (1.0, 1.0)  # (behind, sideways): the radius as an ellipse, squashed toward the eye
    # how much taller than true the rock is drawn (the game's sprites stand
    # taller than life); if it would overflow the canvas it's drawn to fit
    exaggerate: float = 2.2
    flank: float = 0.14  # share of its width at either end over which the outline eases down into the forest
    tree: tuple[float, float] = (5.0, 15.0)  # a lodgepole's crown, metres across and tall
    sheets: float = 34.0  # metres between the edges of its exfoliation sheets (0: none)
    region: str = "tuolumne_meadows"


MASSES = {
    # Lembert Dome over its lot, from the meadow and the road to the south:
    # the long, glacier-smoothed back to the east and the plucked face under
    # the summit to the west
    "lembert_dome": Mass("assets/sprites/tuolumne/lembert_dome.png", "LembertDome", (37.88196, -119.34701), (37.8665, -119.3440),
                         radius=1000.0, floor=2625.0, seed=301, warm=0.2, streaks=0.5, stretch=(0.7, 1.2), exaggerate=2.6),
    # Pothole Dome at the meadow's west end, a low whaleback
    "pothole_dome": Mass("assets/sprites/tuolumne/pothole_dome.png", "PotholeDome", (37.88054, -119.39388), (37.8745, -119.3985),
                         radius=520.0, floor=2612.0, seed=302, stretch=(0.9, 1.2), exaggerate=2.6, sheets=22.0),
    # Fairview Dome from the Tioga Road below its north face, the tallest of
    # the Tuolumne domes
    "fairview_dome": Mass("assets/sprites/tuolumne/fairview_dome.png", "FairviewDome", (37.87142, -119.40399), (37.8794, -119.4041),
                          radius=650.0, floor=2590.0, seed=303, warm=0.15, streaks=0.3, exaggerate=1.6),
    # Cathedral Peak from the Cathedral Lakes trail to the northwest: the
    # summit spire, Eichorn Pinnacle on the west shoulder, the towers of the
    # ridge running off to the east (whitebark pines, smaller, up here)
    "cathedral_peak": Mass("assets/sprites/tuolumne/cathedral_peak.png", "CathedralPeak", (37.84785, -119.40552), (37.8560, -119.4170),
                           radius=700.0, floor=2930.0, seed=304, warm=0.1, streaks=0.15, exaggerate=3.0,
                           tree=(4.0, 9.0), sheets=0.0),
}


def render(m: Mass, dump: dict) -> np.ndarray:
    """Renders to see where the rock really reaches across, then framed so
    it spans [member Mass.width] of the canvas, and once more taller if its
    middle doesn't stand over the scene's footprint for it."""
    view, g = _view(m, None)
    _core, keep, _top, _top_t = _outline(m, view, g)
    cols = np.nonzero(keep.any(axis=0))[0]
    frame = (g["az_at"](cols[0] + 0.5), g["az_at"](cols[-1] + 0.5))
    view, g = _view(m, frame)
    fp = footprint(m, dump, g["W"], g["H"])
    _core, _keep, top, top_t = _outline(m, view, g)
    lift = _lift(np.maximum(top, top_t), fp, float(g["base_row"][0]))
    if lift > 1.02:
        view, g = _view(m, frame, lift)
    return _paint(m, view, g, fp)


def footprint(m: Mass, dump: dict, W: int, H: int) -> np.ndarray:
    """The art row (per art column) of the top of the granite and cliff
    tiles the scene laid under the sprite, H where there are none: the
    outline must stand above it, or the slabs would show round the rock."""
    s = next(sp for sp in dump["sprites"] if sp["parent"] == m.node and sp["tex"].endswith(os.path.basename(m.sprite)))
    SW, SH = 2 * W, 2 * H
    x0 = s["x"] + s["ox"] - (SW / 2.0 if s["centered"] else 0.0)
    y0 = s["y"] + s["oy"] - (SH / 2.0 if s["centered"] else 0.0)
    tw, th, t = dump["w"], dump["h"], dump["tile"]
    kinds = np.array(dump["kinds"], np.int32).reshape(th, tw)
    solid = (kinds == GRANITE) | (kinds == CLIFF)
    # only the slabs joined to the rock's own cliff tiles under the sprite
    tx0, tx1 = max(0, int(x0 // t)), min(tw, int(math.ceil((x0 + SW) / t)))
    ty0, ty1 = max(0, int(y0 // t)), min(th, int(math.ceil((y0 + SH) / t)))
    mine = np.zeros_like(solid)
    mine[ty0:ty1, tx0:tx1] = kinds[ty0:ty1, tx0:tx1] == CLIFF
    for _ in range(64):
        p = np.pad(mine, 1)
        grow = solid & (p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:] | mine)
        if (grow == mine).all():
            break
        mine = grow
    steps = np.full(W, float(H), np.float32)
    for c in range(W):
        tx = int((x0 + (c + 0.5) * 2.0) // t)
        if not 0 <= tx < tw:
            continue
        rows = np.nonzero(mine[:, tx])[0]
        if len(rows):
            steps[c] = max(0.0, (rows[0] * t - y0) / 2.0)
    # the tiles climb in steps: a curve over them that comes down past their
    # ends at a slope a dome's flank could stand at, softened
    cols = np.arange(W, dtype=np.float32)
    env = np.full(W, float(H), np.float32)
    for c in np.nonzero(steps < H)[0]:
        env = np.minimum(env, steps[c] + 1.4 * np.abs(cols - c))
    sm = PT.blur_xy(env[None, :], 3.0, 0.0)[0]
    env = np.minimum(sm, env)
    # and it comes down to the ground before the canvas's sides, rather than
    # being cut off by them (the slabs' far ends may show beside the rock)
    side = np.minimum(cols + 0.5, W - 0.5 - cols)
    env = np.maximum(env, (H - FOOT) - 2.2 * side)
    return np.minimum(env, float(H)).astype(np.float32)


def _lift(outline: np.ndarray, fp: np.ndarray, foot_row: float) -> float:
    """How much taller the rock must be drawn for its middle to stand a few
    rows over the footprint (its flanks get forest instead)."""
    cols = np.nonzero(fp < foot_row)[0]
    if not len(cols):
        return 1.0
    c0, c1 = cols[0], cols[-1]
    mid = cols[(cols > c0 + (c1 - c0) * 0.3) & (cols < c1 - (c1 - c0) * 0.3)]
    if not len(mid):
        return 1.0
    need = (foot_row - fp[mid] + 4.0) / np.maximum(1.0, foot_row - outline[mid])
    return float(np.clip(np.percentile(need, 90), 1.0, 1.3))


def _view(m: Mass, frame: tuple[float, float] | None, lift: float = 1.0):
    path = os.path.join(PT.ROOT, m.sprite)
    SW, SH = Image.open(path).size
    W, H = SW // 2, SH // 2
    se, sn = D.utm(*m.summit)
    ee, en = D.utm(*m.eye)
    d = math.hypot(se - ee, sn - en)
    az_c = math.degrees(math.atan2(se - ee, sn - en)) % 360.0
    # the rock's angular width, and degrees per art column to fit it: first a
    # generous guess from its radius, then its true reach
    if frame is None:
        half = math.degrees(math.atan2(m.radius * m.stretch[1], d))
        per = 2.0 * half / (W * 0.5)
    else:
        a0, a1 = frame
        per = (a1 - a0) / (W * m.width)
        az_c = (a0 + a1) / 2.0
    span = max(d, m.radius) + m.radius * 2.5
    box = (math.floor((min(se, ee) - span) / 100) * 100, math.floor((min(sn, en) - span) / 100) * 100,
           math.ceil((max(se, ee) + span) / 100) * 100, math.ceil((max(sn, en) + span) / 100) * 100)
    dm = D.fetch(*box, 2.0)
    raw_slope = np.degrees(np.arctan(np.hypot(dm.dzde, dm.dzdn)))
    dm = D.DEM(PT.blur(dm.z, 1.2), dm.e0, dm.n1, dm.res)
    base_row = np.full(W, H - FOOT, np.float32)

    def az_at(c: float) -> float:
        return az_c + (c - W / 2.0) * per

    m_across = math.radians(per) * d  # metres per art column at the summit
    # metres per row: the exaggeration, unless that would overflow the canvas
    top = float(dm.sample(np.array([se]), np.array([sn]))[0])
    rows_needed = (top - m.floor) / (m_across / (m.exaggerate * lift))
    room = base_row[0] - m.pad
    squash = m_across / (m.exaggerate * lift) * max(1.0, rows_needed / room)
    view = EV.camera(dm, e=ee, n=en, eye=m.eye_h, W=W, H=H, az_at=az_at, base_z=m.floor, base_row=base_row, d0=d,
                     fit=[], depth=d + m.radius * 3.0, near=min(300.0, d * 0.4), curve=False, squash=squash)
    if frame is not None:
        print(f"  {os.path.basename(m.sprite)}: {d:.0f} m off, {m_across:.1f} m per column, x{m_across / squash:.1f} tall")
    view.slope = np.maximum(view.slope, dm.sample(view.e, view.n, raw_slope) * 0.85)
    view.m_across = m_across
    return view, dict(W=W, H=H, se=se, sn=sn, ee=ee, en=en, d=d, az_c=az_c, az_at=az_at, box=box,
                      base_row=base_row, squash=squash, m_across=m_across)


def _outline(m: Mass, view, g: dict):
    """Which pixels are the rock: its own surface within its radius of the
    summit and above the floor (the core); and the picture's outline, the
    core filled down to the ground, its flanks eased down into the forest at
    either end where the radius cut the ridge off."""
    W, H = g["W"], g["H"]
    dx = view.e - g["se"]
    dy = view.n - g["sn"]
    # an ellipse: squashed along the line of sight, stretched across it
    fx, fy = math.sin(math.radians(g["az_c"])), math.cos(math.radians(g["az_c"]))
    along = dx * fx + dy * fy
    across = dx * fy - dy * fx
    r = np.sqrt((along / (m.radius * m.stretch[0])) ** 2 + (across / (m.radius * m.stretch[1])) ** 2)
    core = view.hit & (r <= 1.0) & (view.z > m.floor + 6.0)
    # nor what shows past it
    core &= view.dist < g["d"] + m.radius * 1.2
    # fill pin holes, drop specks
    k = core.copy()
    for _ in range(2):
        p = np.pad(k, 1)
        n = p[:-2, 1:-1].astype(int) + p[2:, 1:-1] + p[1:-1, :-2] + p[1:-1, 2:]
        k = (k & (n >= 2)) | (~k & (n >= 3))
    core = k & view.hit
    cols = np.nonzero(core.any(axis=0))[0]
    top = np.full(W, float(H), np.float32)
    for c in cols:
        top[c] = float(np.nonzero(core[:, c])[0].min())
    c0, c1 = (cols[0], cols[-1]) if len(cols) else (0, -1)
    span_c = max(1.0, c1 - c0)
    xs = np.arange(W)
    edge = np.minimum(xs - c0, c1 - xs).astype(np.float32)
    t = np.clip(edge / (span_c * m.flank), 0, 1)
    t = t * t * (3 - 2 * t)
    foot_row = float(g["base_row"][0])
    top_t = foot_row - (foot_row - np.minimum(top, foot_row)) * t
    outline = np.maximum(top, top_t)
    ys = np.arange(H, dtype=np.float32)[:, None]
    inside = (xs >= c0) & (xs <= c1)
    keep = inside[None, :] & (ys >= outline[None, :]) & (ys <= foot_row)
    return core, keep, top, top_t


def _cover(m: Mass, view, g: dict) -> np.ndarray:
    """The map's land cover under every pixel."""
    lat0, lon0 = min(m.summit[0], m.eye[0]) - 0.02, min(m.summit[1], m.eye[1]) - 0.025
    lat1, lon1 = max(m.summit[0], m.eye[0]) + 0.02, max(m.summit[1], m.eye[1]) + 0.025
    cv = O.cover(*g["box"], 4.0, (lon0, lat0, lon1, lat1))
    grid = cv.cls
    rr = ((cv.n1 - view.n) / cv.res).astype(np.int64)
    cc = ((view.e - cv.e0) / cv.res).astype(np.int64)
    ok = view.hit & (rr >= 0) & (rr < grid.shape[0]) & (cc >= 0) & (cc < grid.shape[1])
    cover = np.zeros(view.hit.shape, np.uint8)
    cover[ok] = grid[rr[ok], cc[ok]]
    return cover


def _paint(m: Mass, view, g: dict, fp: np.ndarray) -> np.ndarray:
    W, H = g["W"], g["H"]
    core, keep, top, top_t = _outline(m, view, g)
    cover = _cover(m, view, g)
    noise = PT.noise
    ys = np.arange(H, dtype=np.float32)[:, None]
    slope = view.slope
    foot_row = float(g["base_row"][0])
    outline = np.maximum(top, top_t)
    # where the outline falls short of the footprint, the rock's shoulders
    # stand out to cover it: its apron of slabs behind and beside it; and the
    # forest at the foot spills a pixel or two onto the ground, ragged,
    # rather than ending in a ruled line
    wav = (noise(W, 1, 7, m.seed + 3)[0] - 0.5) * 3.0
    reach = np.minimum(np.where(fp < H, fp - 3.0 + wav, float(H)), foot_row)
    apron = (ys >= reach[None, :]) & (ys < outline[None, :])
    bottom = foot_row + 1.0 + 2.5 * noise(W, 1, 3, m.seed + 4)[0]
    spill = (ys > foot_row) & (ys <= bottom[None, :]) & (keep | apron).any(axis=0)[None, :]
    keep = keep | apron | spill
    # the forest: solid round the rock's foot (the ground in front of it, and
    # a band where it meets the ground), up the flanks where the outline was
    # eased down, and in the thickest of the mapped woods
    fringe = (ys - outline[None, :]) < (3.0 + 9.0 * noise(W, H, 6, m.seed + 1))
    fringe &= (top_t > top + 0.5)[None, :] & ~apron
    side = np.minimum(np.arange(W) + 0.5, W - 0.5 - np.arange(W))
    band = (H * 0.03 + 12.0 * noise(W, H, 7, m.seed + 2) ** 1.5) * np.clip(side / 14.0, 0, 1)[None, :]
    foot = ys > foot_row - band
    groves = noise(W, H, 7.0, m.seed + 14) * 0.7 + noise(W, H, 2.5, m.seed + 15) * 0.3
    woods = ((cover == O.FOREST) & (slope < 42) & ~apron) | (apron & (groves > 0.45))
    ground = keep & ~core & ~apron
    dense = keep & (ground | fringe | foot | (woods & ~apron & (slope < 32) & (groves > 0.62)))
    sparse = keep & ~dense & woods & (groves > 0.42)
    cracks = keep & ~dense & ~woods & (slope < 30) & (noise(W, H, 2.0, m.seed + 13) > 0.8)
    talus = keep & (cover == O.SCREE) & ~dense & ~apron
    brush = keep & (cover == O.SCRUB) & ~dense & ~apron
    wall = PT.Wall(m.sprite, [], base_z=m.floor, seed=m.seed, warm=m.warm, streaks=m.streaks)
    rng = np.random.default_rng(m.seed + 90)

    def finish(P, rock, shade):
        if m.sheets > 0:
            _sheets(P, rock, slope, top, W, H, m, g)
        # the apron: granite slabs, lit as their outline leans (toward the
        # sun on the left flank, away on the right), darker down by the ground
        lean = np.gradient(PT.blur_xy(reach[None, :], 4.0, 0.0)[0])
        face = 0.6 - 0.22 * np.clip(lean / 1.2, -1, 1)
        down = np.clip((ys - reach[None, :]) / np.maximum(4.0, foot_row - reach[None, :]), 0, 1)
        slab = face[None, :] - 0.14 * down + (noise(W, H, 9, m.seed + 41) - 0.5) * 0.08
        P.put(apron & ~dense, "granite", np.clip(slab, 0, 1))
        # over the ridge, where the forest stands against the sky, there is
        # no terrain to light it: the apron's light
        shade = np.where(view.hit & ~apron, shade, np.clip(slab, 0, 1))
        return _plant(P, view, g, m, dense, sparse, cracks, shade, rng) | apron

    img = PT._compose(view, None, wall, {}, W, H, g["base_row"], g["base_row"], keep=keep,
                      masks=(dense, brush, talus), finish=finish)
    return img


def _sheets(P, rock: np.ndarray, slope: np.ndarray, top: np.ndarray, W: int, H: int, m: Mass, g: dict) -> None:
    """A dome is granite peeling off in shells, like an onion's: where a shell
    has broken away, its edge is a step across the face, running round the
    dome's curve (parallel to its outline, as the shells are to its
    surface), dark under the step and lit on its lip, and broken, as the
    shells come away in pieces."""
    t = top.astype(np.float32).copy()
    have = t < H
    if not have.any():
        return
    xs = np.arange(W)
    t = np.interp(xs, xs[have], t[have]).astype(np.float32)
    k = max(3, int(W * 0.03))
    t = np.convolve(np.pad(t, k, mode="edge"), np.ones(2 * k + 1) / (2 * k + 1), mode="same")[k:-k]
    rows = m.sheets / g["squash"]  # the shells' thickness, in rows
    ys = np.arange(H, dtype=np.float32)[:, None]
    wob = (PT.noise(W, H, 14, m.seed + 30) - 0.5) * rows * 0.8 + (PT.noise(W, H, 4, m.seed + 31) - 0.5) * 1.5
    depth = np.maximum(ys - t[None, :] + wob, 0.0)
    # the shells thicken a little going in
    lvl = np.floor(np.sqrt(depth / rows + 0.25) * 2.2)
    below = np.vstack([lvl[1:], lvl[-1:]])
    step = rock & (lvl != below) & (slope > 18) & (slope < 80) & (ys > t[None, :] + 2)
    step &= PT.noise(W, H, 9, m.seed + 32) > 0.48
    lip = np.vstack([step[1:], np.zeros((1, W), bool)]) & rock & ~step
    P.val[step] -= 0.17
    P.val[lip] += 0.07


def _plant(P, view, g: dict, m: Mass, dense: np.ndarray, sparse: np.ndarray, cracks: np.ndarray, shade: np.ndarray,
           rng) -> np.ndarray:
    """Lodgepole pines one by one, each its true size for how far off it
    stands (and never less than a few pixels, to read as a tree), narrow and
    pointed, lit on the left: a canopy of overlapping crowns where the forest
    is thick, single trees on the granite with their shadows falling to the
    right. The farthest are drawn first. Returns the pixels drawn outside the
    rock's outline (treetops above a ridge)."""
    H, W = dense.shape
    drawn = np.zeros((H, W), bool)
    # under the thick forest: the shade between the crowns
    canopy = PT.blur_xy(shade, 3.0, 1.5)
    P.put(dense, "forest", 0.08 + 0.26 * canopy + (PT.noise(W, H, 3, m.seed + 40) - 0.5) * 0.12)
    # candidates: a fine jittered grid, each kept by the share of its cell a
    # tree of that size there would fill
    cell = 2.0
    gy, gx = np.mgrid[0:int(H / cell), 0:int(W / cell)]
    py = ((gy + rng.random(gy.shape)) * cell).astype(int).ravel()
    px = ((gx + rng.random(gx.shape)) * cell)
    px = px.ravel()
    pyc = np.clip(py, 0, H - 1)
    pxc = np.clip(px.astype(int), 0, W - 1)
    # (a tree over the ridge, against the sky, stands as far off as the ridge)
    first = np.argmax(view.hit, axis=0)
    ridge = np.where(view.hit.any(axis=0), view.dist[first, np.arange(W)], g["d"])
    dist = np.maximum(np.where(view.hit[pyc, pxc], view.dist[pyc, pxc], ridge[pxc]), 50.0)
    w_m, h_m = m.tree
    w = np.maximum(2.0, w_m * g["d"] / (g["m_across"] * dist)) * rng.uniform(0.85, 1.2, len(py))
    h = np.clip(np.round(w * h_m / w_m * rng.uniform(0.8, 1.2, len(py))), 4, 40)
    area = w * h * 0.5
    dens = np.where(dense[pyc, pxc], 1.4, np.where(sparse[pyc, pxc], 0.32 * m.trees,
                                                     np.where(cracks[pyc, pxc], 0.06, 0.0)))
    ok = rng.random(len(py)) < dens * cell * cell / area
    order = np.argsort(-dist[ok], kind="stable")
    tx, ty, tw, th = px[ok][order], pyc[ok][order], w[ok][order], h[ok][order].astype(int)
    on_rock = ~dense[ty, tx.astype(int)]
    forest = P.m("forest")
    for x, y, wd, hg, bare in zip(tx, ty, tw, th, on_rock):
        sh = float(shade[y, int(x)])
        v_lit = 0.4 + 0.32 * sh + rng.uniform(-0.06, 0.06)
        v_dark = 0.14 + 0.16 * sh
        if bare:
            # its shadow on the granite, to the lower right
            for k in range(int(wd * 0.5) + 1, int(wd * 1.4) + 2):
                xs = int(x + k)
                for yy in (y, y - 1):
                    if 0 <= xs < W and 0 <= yy < H and P.mat[yy, xs] != forest:
                        P.val[yy, xs] -= 0.2
        _tree(P, drawn, x, y, wd, hg, v_lit, v_dark, rng, forest)
    return drawn | dense


def _tree(P, drawn: np.ndarray, x: float, y: int, w: float, h: int, v_lit: float, v_dark: float, rng,
          mat: int) -> None:
    H, W = drawn.shape
    y0 = y - h + 1
    for k in range(h):
        yy = y0 + k
        if yy < 0 or yy >= H:
            continue
        f = (k + 1) / h
        # a lodgepole: a narrow spire, nearly as broad halfway down as at the foot
        half = max(0.5, w * 0.5 * f ** 0.7)
        if w >= 3 and 0 < k < h - 1:
            half += rng.uniform(-0.45, 0.35)
        for xx in range(int(math.floor(x - half)), int(math.ceil(x + half)) + 1):
            if xx < 0 or xx >= W:
                continue
            dx = xx + 0.5 - x
            if abs(dx) > half + 0.01:
                continue
            # the sun on its upper left, its lower boughs in their own shade
            v = v_lit if (k == 0 or (dx < -0.2 * half and f < 0.8)) else v_dark
            if k == h - 1:
                v = v_dark - 0.06
            P.mat[yy, xx] = mat
            P.val[yy, xx] = v
            drawn[yy, xx] = True


def main() -> None:
    args = sys.argv[1:]
    out_dir = None
    if args[:1] == ["--out"]:
        out_dir = args[1]
        args = args[2:]
        os.makedirs(out_dir, exist_ok=True)
    dump_dir, names = args[0], args[1:]
    dumps: dict[str, dict] = {}
    for name in names or list(MASSES):
        m = MASSES[name]
        if m.region not in dumps:
            dumps[m.region] = PT.load_dump(dump_dir, m.region)
        img = render(m, dumps[m.region])
        dest = os.path.join(out_dir, name + ".png") if out_dir else os.path.join(PT.ROOT, m.sprite)
        Image.fromarray(img, "RGBA").save(dest, optimize=True)
        print("painted", dest)


if __name__ == "__main__":
    main()
