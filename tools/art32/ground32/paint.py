#!/usr/bin/env python3
"""Paints the ground of the park's hand-made outdoor areas again, for the
32px game, from the terrain grid that decides where the player can walk (so
collision and foraging are unchanged).

The 16px builders paint each area's ground and the 32px pass upgrades it,
which left blotchy camouflage, glyph-like dither marks, muddy roads and
salt-and-pepper lots. This paints the ground on the same two-pixel grain as
the sprites standing on it (art pixels of 2x2, rounded off by Scale2x as the
sprites were), in clusters of flat tone with the texture in small hand-shaped
motifs rather than noise:

- Valley meadow as tufts of blades with seed heads and a few lupine, yarrow,
  buttercup and shooting stars; ponderosa and cedar needle duff with cones and
  twigs; mown lawn in stripes with clover; oak litter and grass cured gold in
  the foothills; red fir duff, cones and granite grit at Glacier Point;
  chaparral soil with manzanita leaves; grass leaning over every edge.
- Asphalt roads with a double yellow line, worn white fog lines and gravel
  shoulders; lots striped round the cars parked in them, with oil stains;
  concrete walks with saw-cut joints and granite curbs; cut stone on the
  Ahwahnee's terraces and a cobble curb round its entrance circle.
- The Merced deepening from a cobbled bed in the shallows to blue-green pools,
  with current streaks, sun glints and a broken foam line, wet dark banks,
  and sand bars with ripples and pebbles; Mirror Lake still and green.
- Granite slabs peeling in sheets with cracks and lichen; talus as lit blocks.
- A shadow under every tree, building, rock, car and bench, cast down and to
  the right (the light is from the upper left), on the ground's own ramps.

Tuolumne Meadows keeps its own ground.

    godot --headless --path . res://tools/art32/ground32/dump.tscn -- DUMP_DIR
    python3 tools/art32/ground32/paint.py DUMP_DIR [region ids]
    python3 tools/art32/ground32/paint.py --out DIR DUMP_DIR [ids]   # write elsewhere, to look first

Then `godot --headless --path . --import`. Needs Pillow and numpy.
"""
from __future__ import annotations

import json
import os
import sys
import time

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, ".."))

import field as F  # noqa: E402
import roads as RD  # noqa: E402
import shadows  # noqa: E402
from pixel32 import scale2x  # noqa: E402
from ramps import COLORS, RAMPS  # noqa: E402

(FOREST, MEADOW, WET_MEADOW, FOOTHILL, FIR, SUBALPINE, SCRUB, GRANITE, CLIFF, TALUS, SCREE,
 RIVER, LAKE, CREEK, FALLS, SAND, ROAD, PARKING, BRIDGE, TRAIL, PAVED, CAMP, SNOW, ALPINE,
 LAWN, BUILT) = range(26)
WATER_SET = (RIVER, LAKE, CREEK, FALLS)
PAVE_SET = (PARKING, PAVED, BUILT, BRIDGE)

SKIP = {"tuolumne_meadows"}

# Per-area settings: what the forest kind is in that place, and the shapes
# the 16px builders drew over the tile ground.
REGIONS: dict[str, dict] = {
    "lamon_homestead": {"forest": "orchard"},
    "el_portal": {"forest": "oakwood"},
    "curry_village": {"lawn": (26, 28, 53, 23)},
    "the_ahwahnee": {"hotel": True, "flagstone": True},
    # The back of Half Dome: steep rock round the summit and the saddle, and
    # the drop off the northwest face beyond the top two rows.
    "half_dome": {"steep": True, "drop": 2},
}

C = {k: F.hexrgb(v) for k, v in COLORS.items()}
RAMP = {k: np.array([F.hexrgb(h) for h in v], np.uint8) for k, v in RAMPS.items()}
MATS = list(RAMPS.keys())
MAT = {m: i for i, m in enumerate(MATS)}


def S(rows, key):
    return F.Stamp(rows, key)


TONE = {"3": 3, "2": 2, "1": 1, "0": 0, "d": -1, "D": -2, "E": -3}
# Grass: tufts of blades, lit at the tips and dark at the root.
TUFTS = [
    S(["2...2", ".1.1.", "d1d1d"], TONE),
    S(["1.2", "1.1", "dDd"], TONE),
    S([".2.", "21.", "dd."], TONE),
    S(["2..", ".1.", ".d."], TONE),
    S(["..2", ".1.", ".d."], TONE),
    S(["2.1.2", "1.1.1", "dDdDd"], TONE),
]
DARK_BLADES = [S(["d", "D"], TONE), S(["d.d", "DdD"], TONE), S(["D"], TONE)]
FINE = [S(["1", "d"], TONE), S(["1"], TONE), S(["d"], TONE)]
NEEDLES = [
    S(["1.", ".1"], TONE), S([".1", "1."], TONE), S(["11"], TONE), S(["2"], TONE),
    S(["d.", ".d"], TONE), S([".d", "d."], TONE), S(["dd"], TONE), S(["D"], TONE),
]
STRAW = [
    S(["2", "1", "d"], TONE), S(["2.", ".1", ".d"], TONE), S([".2", "1.", "d."], TONE),
    S(["2.2", "1.1", "ddd"], TONE), S(["1", "d"], TONE),
]
CONE = S(["hc", "cd"], {"h": "cone_hi", "c": "cone", "d": "cone_dk"})
FIR_CONE = S([".h.", "chc", "cdc", ".d."], {"h": "cone_hi", "c": "cone", "d": "cone_dk"})
TWIG = [S(["ttT"], {"t": "twig", "T": "twig_hi"}), S(["t..", ".tT"], {"t": "twig", "T": "twig_hi"})]
PEBBLE = [
    S(["a", "s"], {"a": "peb_a", "s": "peb_sh"}), S(["ab", "ss"], {"a": "peb_a", "b": "peb_b", "s": "peb_sh"}),
    S(["d", "s"], {"d": "peb_d", "s": "peb_sh"}), S(["c"], {"c": "peb_c"}), S(["b"], {"b": "peb_b"}),
]
SEED = [S(["s"], {"s": "seed"}), S(["s", "k"], {"s": "seed", "k": "seed_dk"})]
FLOWERS = [
    S(["L", "l"], {"L": "lupine_hi", "l": "lupine"}),
    S(["y"], {"y": "yarrow"}), S(["b"], {"b": "buttercup"}), S(["p"], {"p": "shooting"}),
    S(["y.y"], {"y": "yarrow"}),
]
OATS = [S(["s", "k"], {"s": "seed", "k": "seed_dk"}), S(["s"], {"s": "seed"})]
LEAVES = [
    S(["ab"], {"a": "leaf_oak", "b": "leaf_oak2"}), S(["a", "d"], {"a": "leaf_oak", "d": "leaf_dk"}),
    S(["b"], {"b": "leaf_oak2"}), S(["a"], {"a": "leaf_oak"}),
]
MANZ = [S(["m"], {"m": "manz_leaf"}), S(["mn"], {"m": "manz_leaf", "n": "manz_leaf2"}), S(["n"], {"n": "manz_leaf2"})]
LICHEN = [
    S(["ll", "Ll"], {"l": "lichen", "L": "lichen_dk"}), S(["o"], {"o": "lichen_o"}),
    S(["l."], {"l": "lichen"}), S(["L"], {"L": "lichen_dk"}),
]
CLOVER = S(["c.c"], {"c": "clover"})
GLINT = [S(["f"], {"f": "foam_hi"}), S(["ff"], {"f": "foam_hi"})]
STREAK_H = [S(["11"], TONE), S(["111"], TONE), S(["1"], TONE), S(["dd"], TONE)]
STREAK_V = [S(["1", "1"], TONE), S(["1", "1", "1"], TONE), S(["d", "d"], TONE)]
APPLE = S(["r"], {"r": "lichen_o"})


class Painter:
    def __init__(self, dump: dict):
        self.d = dump
        self.id = dump["id"]
        self.cfg = REGIONS.get(self.id, {})
        # Painted on art pixels of 2x2 world pixels, then Scale2x'd.
        self.T = dump["tile"] // 2
        self.tw = dump["w"]
        self.th = dump["h"]
        self.W = self.tw * self.T
        self.H = self.th * self.T
        self.grid = np.array(dump["kinds"], np.int32).reshape(self.th, self.tw)
        self.seed = sum(ord(c) * (i + 1) for i, c in enumerate(self.id)) * 7919

    # ------------------------------------------------------------ layout

    def _fill_nearest(self, member: np.ndarray, values: np.ndarray, reach: int = 4) -> np.ndarray:
        """Each tile takes its own value if a member, else the nearest member's."""
        out = np.where(member, values, -1)
        for _ in range(reach):
            if (out >= 0).all():
                break
            for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                sh = np.roll(np.roll(out, dy, axis=0), dx, axis=1)
                out = np.where((out < 0) & (sh >= 0), sh, out)
        return out

    def _smooth_mask(self, tiles: np.ndarray, r: int, wobble: np.ndarray | None = None) -> tuple[np.ndarray, np.ndarray]:
        up = F.upsample(tiles.astype(np.float32), self.T)
        b = F.blur(up, r)
        cut = 0.5 if wobble is None else 0.5 + wobble
        return b > cut, b

    def layout(self) -> None:
        H, W, T = self.H, self.W, self.T
        g = self.grid
        s = self.seed
        self.Nl = F.fbm(H, W, 110, s + 1, 3)
        self.Nm = F.fbm(H, W, 32, s + 2, 2)
        self.Ns = F.value_noise(H, W, 4, s + 3)
        self.Np = F.fbm(H, W, 55, s + 4, 3)
        self.R = F.hash2(*np.mgrid[0:H, 0:W][::-1], s + 5)
        self.B = F.bayer(H, W)
        lawn = self.cfg.get("lawn")
        if lawn:
            x0, y0, lw, lh = lawn
            sub = g[y0:y0 + lh, x0:x0 + lw]
            sub[sub == MEADOW] = LAWN

        hard = np.isin(g, WATER_SET + PAVE_SET + (ROAD, TRAIL))
        natural = self._fill_nearest(~hard, g, 8)
        natural[natural < 0] = FOREST
        # Natural ground: a warped tile lookup, so the borders between grass,
        # duff and rock are ragged rather than tile steps.
        wx = (F.fbm(H, W, 20, s + 6, 2) - 0.5) * 16 + (self.R - 0.5) * 2
        wy = (F.fbm(H, W, 20, s + 7, 2) - 0.5) * 16
        yy, xx = np.mgrid[0:H, 0:W]
        tx = np.clip(((xx + wx) // T).astype(np.int32), 0, self.tw - 1)
        ty = np.clip(((yy + wy) // T).astype(np.int32), 0, self.th - 1)
        K = natural[ty, tx]
        del tx, ty, wx, wy

        # Smoothed groups, lowest priority first.
        trail_m, self.trail_b = self._smooth_mask(g == TRAIL, 6, (self.Nm - 0.5) * 0.18)
        K = np.where(trail_m, TRAIL, K)
        pave_tiles = np.isin(g, PAVE_SET)
        pave_m, self.pave_b = self._smooth_mask(pave_tiles, 6)
        pave_kind = self._fill_nearest(pave_tiles, g, 3)
        K = np.where(pave_m, F.upsample(np.maximum(pave_kind, 0), T), K)
        K = np.where(self._road_layout(), ROAD, K)
        wet_tiles = np.isin(g, WATER_SET)
        wet_m, self.wet_b = self._smooth_mask(wet_tiles, 10, (self.Nl - 0.5) * 0.36 + (self.Nm - 0.5) * 0.2)
        wet_kind = self._fill_nearest(wet_tiles, g, 3)
        K = np.where(wet_m, F.upsample(np.maximum(wet_kind, 0), T), K)
        bridge_m, _ = self._smooth_mask(g == BRIDGE, 3)
        K = np.where(bridge_m, BRIDGE, K)
        self.K = K
        # Depth inside the water: 0 at the shore, 1 in the middle of a wide channel.
        wm = np.isin(K, WATER_SET).astype(np.float32)
        d1 = F.blur(wm, 7)
        d2 = F.blur(wm, 26)
        self.depth = np.clip((d1 - 0.5) * 2.0 * 0.3 + (d2 - 0.5) * 2.0 * 0.85, 0.0, 1.0) * wm
        self.wet_near = F.blur(wm, 2)
        # Flow runs along the channel: horizontal unless its banks run up and down.
        gy, gx = np.gradient(d2)
        self.flow_v = np.abs(gx) > np.abs(gy) * 1.4

    def _road_layout(self) -> np.ndarray:
        """Traces the roads (see roads.py) and returns where the asphalt goes:
        each road at its steady width, the aprons of road tiles the roads
        don't cover (driveways, pull-outs), and small rounds in the corners."""
        H, W, T = self.H, self.W, self.T
        g = self.grid
        carriage = g == ROAD
        for y0, y1, x0, x1, _vertical, road, _beside in self._bridge_spans():
            if road:
                carriage[y0:y1, x0:x1] = True
        # A walk or trail laid across a road (a tile or two wide) doesn't cut it.
        P = np.pad(carriage, 2)
        h, w = carriage.shape
        up = P[1:h + 1, 2:-2] | P[0:h, 2:-2]
        down = P[3:h + 3, 2:-2] | P[4:h + 4, 2:-2]
        left = P[2:-2, 1:w + 1] | P[2:-2, 0:w]
        right = P[2:-2, 3:w + 3] | P[2:-2, 4:w + 4]
        across = (up & down) | (left & right)
        carriage |= across & np.isin(g, (PAVED, BUILT, TRAIL))
        lots = np.isin(g, (PARKING, PAVED, BUILT))
        lot_px = F.upsample(lots, T).astype(bool)
        # Traced twice: the second time without the driveways and pull-outs
        # the first found, which pull the line off the road's middle.
        for _ in range(2):
            self.roads = RD.trace(carriage, T)
            for r in self.roads:
                RD.reach_lots(r, lot_px, T)
            clean = np.zeros((H, W), bool)
            for r in self.roads:
                clean |= RD.stamp_disks((H, W), r.pts, r.width * T / 2.0)
            # Road tiles the traced road (mostly) misses are a driveway or
            # pull-out when they touch a lot or a walk; otherwise they're only
            # the corners of a stair-stepped road, and grow over.
            cover = clean.reshape(self.th, T, self.tw, T).mean(axis=(1, 3))
            left = (g == ROAD) & (cover < 0.25)
            P = np.pad(lots, 1)
            apron_t = left & (P[:-2, 1:-1] | P[2:, 1:-1] | P[1:-1, :-2] | P[1:-1, 2:])
            carriage &= ~apron_t
        apron = F.upsample(apron_t, T).astype(bool)
        union = (clean & ~lot_px) | apron
        # rounds in the corners, and no sliver of ground left between a road
        # and the lot it runs along
        road = union | ((F.blur((union | lot_px).astype(np.float32), 6) > 0.5) & ~lot_px)
        self.road_clean = clean
        # asphalt beyond the traced roads' edges, where fog lines stop
        beyond = road & ~(F.box_blur(clean.astype(np.float32), 1) > 0)
        self.road_beyond = F.box_blur(beyond.astype(np.float32), 1) > 0.999
        return road

    # ------------------------------------------------------------ materials

    def materials(self) -> np.ndarray:
        """The ground material at each pixel (an index into MATS)."""
        K = self.K
        forest = self.cfg.get("forest", "forest")
        M = np.full(K.shape, MAT["duff"], np.int16)
        # Patches (grass among the trees, bare soil in the foothills) have
        # ragged edges from the small noise, not dithered ones.
        P = self.Np + (self.Ns - 0.5) * 0.08
        isf = K == FOREST
        self.canopy = shadows.canopy_field(self.d, self.H, self.W, ROOT, 0.5)
        if forest == "forest":
            # Duff under the crowns, grass in the openings between them.
            self.green = isf & (P * 0.95 + (1.0 - self.canopy) * 0.32 + (self.Nm - 0.5) * 0.25 > 0.7)
        elif forest == "orchard":
            self.green = isf & (P > 0.28)
        else:
            self.green = np.zeros(K.shape, bool)
        M[isf] = MAT["litter"] if forest == "oakwood" else MAT["duff"]
        self.oak_straw = isf & (P > 0.52) if forest == "oakwood" else np.zeros(K.shape, bool)
        M[self.green] = MAT["grass"]
        M[self.oak_straw] = MAT["straw"]
        M[np.isin(K, (MEADOW, LAWN))] = MAT["grass"]
        M[K == WET_MEADOW] = MAT["sedge"]
        M[K == FOOTHILL] = MAT["straw"]
        M[(K == FOOTHILL) & (P < 0.22)] = MAT["soil"]
        M[K == SCRUB] = MAT["soil"]
        M[(K == SCRUB) & (P > 0.62)] = MAT["straw"]
        M[K == FIR] = MAT["firduff"]
        M[(K == FIR) & (P > 0.68)] = MAT["sand"]
        M[np.isin(K, (GRANITE, CLIFF, TALUS, SCREE, ALPINE, SNOW))] = MAT["granite"]
        M[np.isin(K, (SUBALPINE, SAND))] = MAT["sand"]
        M[K == CAMP] = MAT["camp"]
        M[K == TRAIL] = MAT["trail"]
        M[np.isin(K, (ROAD, PARKING))] = MAT["asphalt"]
        M[np.isin(K, (PAVED, BUILT, BRIDGE))] = MAT["concrete"]
        # One water for river, creek and lake, so where they meet there is no seam.
        M[np.isin(K, (RIVER, CREEK, FALLS, LAKE))] = MAT["water"]
        return M

    def macro(self, base: float, steps=(0.42, 0.64), lo: float = 0.0) -> np.ndarray:
        """Flat tone clusters: base, base + 1, base + 2 where the large and
        medium fields run high (and base - 1 below [param lo]), with ragged edges."""
        f = 0.55 * self.Nl + 0.45 * self.Nm + (self.Ns - 0.5) * 0.12
        t = np.full(f.shape, base, np.float32)
        for th in steps:
            t += (f > th)
        if lo > 0:
            t -= (f < lo)
        return t

    def paint(self) -> np.ndarray:
        t0 = time.time()
        self.layout()
        H, W = self.H, self.W
        K = self.K
        M = self.materials()
        R = self.R
        tone = np.zeros((H, W), np.float32)
        over = np.zeros((H, W, 3), np.uint8)
        over_m = np.zeros((H, W), bool)
        s = self.seed
        xx = np.arange(W)[None, :]
        yy = np.arange(H)[:, None]

        def m(name):
            return M == MAT[name]

        def scatter(cell, dens, seed, mask, stamps):
            ys, xs, pick = F.scatter(H, W, cell, dens, s + seed, mask)
            n = len(stamps)
            for i, st in enumerate(stamps):
                sel = (pick * n).astype(int) == i
                F.apply_tone(tone, mask, ys[sel], xs[sel], st)

        def dots(cell, dens, seed, mask, stamps, spill=None):
            ys, xs, pick = F.scatter(H, W, cell, dens, s + seed, mask)
            dest = mask if spill is None else spill
            n = len(stamps)
            for i, st in enumerate(stamps):
                sel = (pick * n).astype(int) == i
                for dx, dy, v in st.cells:
                    y = ys[sel] + dy
                    x = xs[sel] + dx
                    ok = (y >= 0) & (y < H) & (x >= 0) & (x < W)
                    y, x = y[ok], x[ok]
                    ok = dest[y, x]
                    over[y[ok], x[ok]] = C[v] if isinstance(v, str) else v
                    over_m[y[ok], x[ok]] = True

        # ---- grass: meadow, lawn, the green under the trees
        g = m("grass")
        lawn = g & (K == LAWN)
        meadow = g & ~lawn
        tone[meadow] = self.macro(4.0, (0.4, 0.66), 0.22)[meadow]
        tone[meadow & (K == FOREST)] -= 1.0
        stripe = ((xx // 24) % 2).astype(np.float32)
        tone[lawn] = (self.macro(5.0, (0.55,)) + stripe)[lawn]
        scatter(3, 0.62, 11, meadow, TUFTS)
        scatter(4, 0.4, 12, meadow, DARK_BLADES)
        scatter(2, 0.35, 13, lawn, FINE)
        dots(9, 0.22, 14, lawn, [CLOVER])
        open_meadow = meadow & (K == MEADOW)
        dots(6, 0.28, 15, open_meadow, SEED)
        flower_zone = self.Np > 0.56
        dots(7, np.where(flower_zone, 0.3, 0.03).astype(np.float32), 16, open_meadow, FLOWERS)
        if self.cfg.get("forest") == "orchard":
            dots(23, 0.15, 17, g, [APPLE])

        # ---- wet meadow sedge
        sg = m("sedge")
        tone[sg] = self.macro(3.0, (0.42, 0.66))[sg]
        scatter(2, 0.55, 21, sg, TUFTS)
        dots(10, 0.18, 22, sg, [FLOWERS[3], FLOWERS[0]])

        # ---- needle duff
        du = m("duff")
        tone[du] = self.macro(3.0, (0.42, 0.68), 0.2)[du]
        scatter(2, 0.55, 31, du, NEEDLES)
        dots(14, 0.25, 32, du, [CONE])
        dots(18, 0.25, 33, du, TWIG)

        # ---- oak litter
        li = m("litter")
        tone[li] = self.macro(3.0, (0.45, 0.68))[li]
        scatter(2, 0.45, 41, li, NEEDLES)
        dots(2, 0.4, 42, li, LEAVES)
        dots(18, 0.18, 43, li, TWIG)

        # ---- cured foothill grass
        st = m("straw")
        tone[st] = self.macro(3.6, (0.42, 0.68), 0.2)[st]
        scatter(2, 0.6, 51, st, STRAW)
        dots(5, 0.3, 52, st, OATS)

        # ---- chaparral and bare foothill soil
        so = m("soil")
        tone[so] = self.macro(3.0, (0.45, 0.68))[so]
        scatter(3, 0.35, 61, so, FINE)
        dots(2, np.where(K == SCRUB, 0.35, 0.08).astype(np.float32), 62, so, MANZ)
        dots(4, 0.3, 63, so, PEBBLE)

        # ---- red fir duff
        fd = m("firduff")
        tone[fd] = self.macro(3.0, (0.42, 0.68), 0.2)[fd]
        scatter(2, 0.5, 71, fd, NEEDLES)
        dots(15, 0.3, 72, fd, [FIR_CONE])
        dots(4, 0.1, 73, fd, PEBBLE[:2])
        dots(18, 0.25, 74, fd, TWIG)

        # ---- sand bars, granite grit
        sa = m("sand")
        tone[sa] = self.macro(3.6, (0.45, 0.7))[sa]
        rip = np.sin(xx * 0.18 + yy * 1.1 + self.Nm * 9.0) > 0.88
        tone[sa & rip & (K == SAND)] += 1.0
        dots(3, 0.3, 81, sa, PEBBLE)

        # ---- campground dirt
        ca = m("camp")
        tone[ca] = self.macro(3.0, (0.45, 0.7))[ca]
        scatter(2, 0.25, 91, ca, NEEDLES)
        dots(4, 0.22, 92, ca, PEBBLE)
        dots(21, 0.18, 93, ca, [CONE])

        # ---- trails: decomposed granite, worn pale down the middle
        tr = m("trail")
        tone[tr] = (self.macro(3.0, (0.5,)) + (self.trail_b > 0.78) + (self.trail_b < 0.58) * -1.0)[tr]
        dots(3, 0.3, 101, tr, PEBBLE)
        scatter(3, 0.22, 102, tr, [FINE[1], FINE[2]])

        # ---- granite: slabs peeling in sheets, cracks, lichen; talus as blocks
        gr = m("granite")
        slab = gr & np.isin(K, (GRANITE, CLIFF, SNOW, ALPINE))
        tone[slab] = self.macro(5.0, (0.4, 0.62))[slab]
        sheet = (self.Nl * 3.0 + self.Nm * 0.5) % 1.0
        tone[slab & (sheet < 0.03)] -= 2.0
        tone[slab & (sheet >= 0.03) & (sheet < 0.06)] += 1.0
        crack = (np.abs(F.value_noise(H, W, 20, s + 111) - 0.5) < 0.014) & (self.Np > 0.45)
        tone[slab & crack] -= 2.0
        dots(4, np.where(self.Np > 0.55, 0.4, 0.05).astype(np.float32), 112, slab, LICHEN)
        if self.cfg.get("steep"):
            # Steep granite (the cliff tiles) falls away from the rock you can
            # walk on: a shade darker, with dark water streaks down the fall
            # line, and a shadowed band below the edge of the walkable rock.
            cl = slab & (K == CLIFF)
            tone[cl] -= 1.5
            col = F.hash2(xx // 3 + 0 * yy, yy // 60 + 0 * xx, s + 181)
            tone[cl & (col > 0.88) & (self.Nm > 0.42)] -= 1.5
            walk = F.blur((K == GRANITE).astype(np.float32), 5)
            tone[cl & (walk > 0.04)] -= 1.0
            drop = int(self.cfg.get("drop", 0)) * self.T
            if drop:
                # Over the lip: nothing but haze, and the Valley far below.
                d = (yy < drop + (self.Nm - 0.5) * 10) & (K == CLIFF)
                t = np.clip((yy / max(drop, 1)) + 0.0 * xx, 0.0, 1.0)
                haze = np.array([118, 140, 170], np.float32) * (1.0 - t[..., None]) + np.array([66, 80, 108], np.float32) * t[..., None]
                over[d] = haze[d].astype(np.uint8)
                over_m |= d
        tal = gr & np.isin(K, (TALUS, SCREE))
        if tal.any():
            # Talus: angular blocks of every size lying on grey grit, each lit
            # on its upper left, dark on its lower right, with its shadow on
            # the grit beside it.
            ys, xs = np.nonzero(tal)
            y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
            sub = tal[y0:y1, x0:x1]
            hh, ww = y1 - y0, x1 - x0
            grit = 3.0 + (self.Ns[y0:y1, x0:x1] > 0.55) + (self.R[y0:y1, x0:x1] > 0.9) - (self.R[y0:y1, x0:x1] < 0.08)
            t = grit.copy()
            for cell, seed, keep in ((13, 120, 0.62), (7, 124, 0.45)):
                bid, d1, gap, bdx, bdy = F.voronoi(hh, ww, cell, s + seed)
                on = F.hash2(bid, bid * 7, s + seed + 1) < keep
                size = 0.32 + F.hash2(bid, bid * 3, s + seed + 2) * 0.16
                inside = on & (np.maximum(np.abs(bdx), np.abs(bdy)) * 0.55 + d1 * 0.45 < cell * size)
                base = 5.0 + np.floor(F.hash2(bid, bid * 5, s + seed + 3) * 2.0)
                lit = (-bdx - bdy) / cell
                bt = base + (lit > 0.12) * 1.5 - (lit < -0.22) * 1.5
                # the shadow each block throws down and to the right
                shadow = np.zeros_like(inside)
                shadow[2:, 2:] = inside[:-2, :-2]
                t = np.where(shadow & ~inside, np.minimum(t, 1.5), t)
                t = np.where(inside, bt, t)
            tone[y0:y1, x0:x1][sub] = t[sub]
            dots(6, 0.22, 123, tal, LICHEN)

        # ---- asphalt: roads and lots
        asp = m("asphalt")
        tone[asp] = 3.0 + ((self.Nl[asp] > 0.62) & (K[asp] == ROAD)) + (K[asp] == PARKING)
        tone[asp & (R > 0.94)] += 1.0
        tone[asp & (R < 0.03)] -= 1.0
        # Patched repairs: crisp darker rectangles of fresher asphalt.
        cy_, cx_ = yy // 40, xx // 40
        hp = F.hash2(cx_ + 0 * yy, cy_ + 0 * xx, s + 132)
        px0 = (F.hash2(cx_ + 0 * yy, cy_ + 0 * xx, s + 133) * 20).astype(np.int32)
        py0 = (F.hash2(cx_ + 0 * yy, cy_ + 0 * xx, s + 134) * 24).astype(np.int32)
        pw_ = 8 + (F.hash2(cx_ + 0 * yy, cy_ + 0 * xx, s + 135) * 18).astype(np.int32)
        ph_ = 6 + (F.hash2(cx_ + 0 * yy, cy_ + 0 * xx, s + 136) * 10).astype(np.int32)
        lx_ = xx % 40 - px0
        ly_ = yy % 40 - py0
        patch = (hp < 0.13) & (lx_ >= 0) & (lx_ < pw_) & (ly_ >= 0) & (ly_ < ph_)
        tone[asp & patch] -= 1.0
        # The edges are sun-faded where no tires run.
        inner = F.box_blur((K == ROAD).astype(np.float32), 5) > 0.999
        tone[asp & ~inner & (K == ROAD)] += 1.0

        # ---- concrete walks and plazas, or the Ahwahnee's cut stone
        co = m("concrete")
        if self.cfg.get("flagstone"):
            ys, xs = np.nonzero(co)
            if len(ys):
                y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
                bid, d1, gap, bdx, bdy = F.voronoi(y1 - y0, x1 - x0, 7, s + 140)
                base = np.floor(3.6 + F.hash2(bid, bid * 3, s + 141) * 2.6)
                t = base + ((-bdx - bdy) / 7.0 > 0.45)
                t = np.where(gap < 0.9, 1.0, t)
                sub = co[y0:y1, x0:x1]
                tone[y0:y1, x0:x1][sub] = t[sub]
        else:
            # Slabs poured one at a time, each its own shade, saw-cut between.
            slab_t = (F.hash2(xx // 32 + 0 * yy, yy // 32 + 0 * xx, s + 142) > 0.72).astype(np.float32)
            tone[co] = (4.0 + slab_t)[co]
            tone[co & (R > 0.96)] += 1.0
            tone[co & (R < 0.025)] -= 1.0
            joint = np.broadcast_to(xx % 32 == 0, (H, W)) | np.broadcast_to(yy % 32 == 0, (H, W))
            tone[co & joint] = 2.0
            lit = np.broadcast_to(xx % 32 == 1, (H, W)) | np.broadcast_to(yy % 32 == 1, (H, W))
            tone[co & lit & ~joint] += 1.0

        # ---- water
        wa = m("water")
        lk = m("lake")
        D = self.depth
        creek = wa & (K == CREEK)
        wt = 9.4 - D * 6.4 + (self.Nl - 0.5) * 0.8
        tone[wa] = wt[wa]
        # creeks run shallower and paler, blending into the river or lake they join
        cb = F.blur((K == CREEK).astype(np.float32), 10)
        tone[wa] += (cb * 1.2)[wa]
        tone[lk] = (7.0 - D * 3.8 + (self.Nl - 0.5) * 0.8)[lk]
        # The bed shows through the shallows: cobbles.
        shallow = (wa | lk) & (D < np.where(creek, 0.8, 0.55))
        if shallow.any():
            ys, xs = np.nonzero(shallow)
            y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
            bid, d1, gap, bdx, bdy = F.voronoi(y1 - y0, x1 - x0, 4, s + 150)
            fade = 1.0 - np.clip(D[y0:y1, x0:x1] / 0.65, 0, 1)
            t = (F.hash2(bid, bid * 5, s + 151) - 0.5) * 2.0 + ((-bdx - bdy) / 4.0 > 0.4) * 1.0
            t = np.where(gap < 0.8, -1.0, t) * fade
            sub = shallow[y0:y1, x0:x1]
            tone[y0:y1, x0:x1][sub] += t[sub]
        zone = self.Nm > 0.52
        # still water (the lake, and a little way into the stream beside it)
        stillw = F.blur((K == LAKE).astype(np.float32), 12) > 0.3
        moving = wa & zone & ~stillw
        ys, xs, pick = F.scatter(H, W, 3, 0.6, s + 152, moving)
        for i, stp in enumerate(STREAK_H):
            sel = ((pick * len(STREAK_H)).astype(int) == i) & ~self.flow_v[ys, xs]
            F.apply_tone(tone, wa, ys[sel], xs[sel], stp)
        for i, stp in enumerate(STREAK_V):
            sel = ((pick * len(STREAK_V)).astype(int) == i) & self.flow_v[ys, xs]
            F.apply_tone(tone, wa, ys[sel], xs[sel], stp)
        dots(11, 0.22, 153, wa & zone & (D > 0.15) & (D < 0.7) & ~stillw, GLINT)
        dots(21, 0.12, 156, wa & stillw & (D > 0.2) & (D < 0.6), [GLINT[1]])
        dots(21, 0.12, 154, lk & (D > 0.2) & (D < 0.6), [GLINT[1]])
        falls = wa & (K == FALLS)
        if falls.any():
            dots(2, 0.5, 155, falls, [S(["f"], {"f": "foam"}), S(["f"], {"f": "foam_lo"})])

        if self.cfg.get("hotel"):
            self._hotel(tone, M, over, over_m)
        self._bridges(tone, M, over, over_m)

        # ---- edges
        # Wet banks: a darker band on land along the water.
        land_wet = ~(wa | lk) & (self.wet_near > 0.05) & ~np.isin(K, (ROAD, PARKING, PAVED, BUILT, BRIDGE))
        tone[land_wet] -= np.where(self.wet_near[land_wet] > 0.25, 2.0, 1.0)
        # Foam along the shore, broken.
        edge = (wa | lk) & (D < 0.06) & (self.Ns > 0.3)
        fo = edge & (R > 0.2)
        over[fo] = np.where((R[fo] > 0.65)[:, None], C["foam_hi"], C["foam"])
        over_m |= fo
        lo = (wa | lk) & (D >= 0.06) & (D < 0.12) & (self.Ns > 0.55) & (R > 0.45)
        over[lo] = C["foam_lo"]
        over_m |= lo

        # Road shoulders: gravel along the asphalt; then the lines.
        rd = (K == ROAD).astype(np.float32)
        shoulder = (F.box_blur(rd, 5) > 0) & (K != ROAD) & ~np.isin(K, WATER_SET + PAVE_SET)
        M[shoulder] = MAT["trail"]
        tone[shoulder] = (2.0 + (F.box_blur(rd, 2) > 0) + (R > 0.8))[shoulder]
        dots(2, 0.35, 161, shoulder, PEBBLE)
        self._road_lines(over, over_m, M)
        self._parking_lines(over, over_m, tone)

        # Curbs where paving meets the ground, with a shadow outside them.
        pv = np.isin(K, (PAVED, BUILT)) & (M == MAT["concrete"])
        pb = F.blur(pv.astype(np.float32), 1)
        curb = pv & (pb < 0.7)
        gyp, _ = np.gradient(pb)
        over[curb] = C["curb"]
        over[curb & (gyp > 0.02)] = C["curb_hi"]
        over[curb & (gyp < -0.02)] = C["curb_dk"]
        over_m |= curb
        outside = ~pv & (pb > 0.02) & (gyp < -0.02) & ~(wa | lk)
        tone[outside] -= 1.0

        # Grass leaning over the edges of everything it meets.
        grassy = np.isin(M, (MAT["grass"], MAT["sedge"])) & ~over_m
        gb = F.blur(grassy.astype(np.float32), 1)
        fringe = ~grassy & (gb > 0.12) & ~(wa | lk) & ~curb
        blades = [S(["a", "b"], {"a": "g_hi", "b": "g_lo"}), S(["a.a", "b.b"], {"a": "g_hi", "b": "g_lo"}),
                  S(["a"], {"a": "g_hi"}), S([".a", "b."], {"a": "g_hi", "b": "g_lo"})]
        C["g_hi"] = RAMP["grass"][6]
        C["g_lo"] = RAMP["grass"][4]
        dots(2, 0.6, 171, fringe, blades)
        strawy = (M == MAT["straw"]) & ~over_m
        sb = F.blur(strawy.astype(np.float32), 1)
        sfringe = ~strawy & ~grassy & (sb > 0.12) & ~(wa | lk) & ~curb
        C["s_hi"] = RAMP["straw"][6]
        C["s_lo"] = RAMP["straw"][3]
        dots(2, 0.55, 172, sfringe, [S(["a", "b"], {"a": "s_hi", "b": "s_lo"}), S(["a"], {"a": "s_hi"})])

        # ---- contact shadows
        shade = shadows.shade_field(self.d, H, W, ROOT, 0.5)
        tone -= shade
        # ---- colorize: water keeps a fine dither on its depth, the rest is flat
        dith = np.where(np.isin(M, (MAT["water"], MAT["lake"])), (self.B - 0.5) * 0.9, 0.0)
        idx = np.floor(tone + dith).astype(np.int32)
        out = np.zeros((H, W, 3), np.uint8)
        for name, i in MAT.items():
            sel = M == i
            if not sel.any():
                continue
            ramp = RAMP[name]
            out[sel] = ramp[np.clip(idx[sel], 0, len(ramp) - 1)]
        # Overlays (flecks, foam, lines) take the shadow as a cool darkening.
        if over_m.any():
            o = over[over_m].astype(np.float32)
            k = np.clip(shade[over_m], 0, 3)[:, None]
            o = o * (1.0 - 0.16 * k) + np.array([18, 22, 40], np.float32) * 0.06 * k
            out[over_m] = np.clip(o, 0, 255).astype(np.uint8)
        rgba = np.concatenate([out, np.full((H, W, 1), 255, np.uint8)], axis=2)
        big = scale2x(rgba)
        print(f"  {self.id}: painted {W * 2}x{H * 2} in {time.time() - t0:.1f}s")
        return big

    # ------------------------------------------------------------ roads and lots

    def _road_lines(self, over, over_m, M) -> None:
        """A double yellow line down the middle of every traced road, across
        its bridges too, stopping at the edge of the road it runs into and a
        tile short of a dead end; and worn white fog lines just inside each
        edge, broken where a driveway, lot or bridge opens off the road."""
        H, W, T = self.H, self.W, self.T
        Kr = self.K == ROAD
        deck = (self.K == BRIDGE) & (M == MAT["asphalt"])
        yel = C["yellow"]
        for r in self.roads:
            s = RD.arc_length(r.pts)
            cut = []
            for k in (0, 1):
                cut.append({"join": r.meet[k] + 3.0, "dead": float(T), "lot": 0.0, "edge": 0.0}[r.ends[k]])
            sel = (s >= cut[0]) & (s <= s[-1] - cut[1])
            if sel.sum() < 4:
                continue
            mid = RD._resample(r.pts[sel], 0.5)
            for d in (-1.5, 1.5):
                q = np.unique(np.floor(RD.offset_line(mid, d)).astype(np.int32), axis=0)
                xs, ys = q[:, 0], q[:, 1]
                ok = (ys >= 0) & (ys < H) & (xs >= 0) & (xs < W)
                xs, ys = xs[ok], ys[ok]
                ok = (Kr[ys, xs] | deck[ys, xs]) & (self.R[ys, xs] > 0.04)
                over[ys[ok], xs[ok]] = yel
                over_m[ys[ok], xs[ok]] = True
        # Fog lines: a worn white line just inside each edge of the traced road.
        cl = self.road_clean.astype(np.float32)
        k2 = F.box_blur(cl, 2) > 0.999
        k3 = F.box_blur(cl, 3) > 0.999
        other = self.road_beyond | np.isin(self.K, (PARKING, BRIDGE))
        fog = Kr & k2 & ~k3 & ~(F.box_blur(other.astype(np.float32), 4) > 0)
        for r in self.roads:
            for k in (0, 1):
                if r.ends[k] == "dead":
                    fog &= ~RD.stamp_disks((H, W), r.pts[[-1 if k else 0]], r.width * T / 2.0 + 4)
        fog &= (self.Ns > 0.25) & (self.R > 0.12)
        over[fog] = np.where((self.R[fog] > 0.4)[:, None], C["white"], C["white_dk"])
        over_m |= fog

    def _parking_lines(self, over, over_m, tone) -> None:
        """White stall lines round the cars parked in each lot, carried on at
        the same pitch along the row, and an oil stain in each stall."""
        cars = [sp for sp in self.d["sprites"] if "/car_" in sp["tex"] and sp["visible"]]
        if not cars:
            return
        H, W = self.H, self.W
        lot = self.K == PARKING
        rows: dict[int, list[dict]] = {}
        for c in cars:
            rows.setdefault(int(round(c["y"] / 8.0)), []).append(c)
        for row in rows.values():
            xs = sorted(c["x"] / 2.0 for c in row)
            gaps = [b - a for a, b in zip(xs, xs[1:]) if b - a > 20]
            pitch = min(gaps) if gaps else 36.0
            pitch = max(32.0, min(pitch, 48.0))
            foot = row[0]["y"] / 2.0
            y_top = int(foot - 44)
            y_bot = int(foot + 2)
            mid = min(max((y_top + y_bot) // 2, 0), H - 1)
            lines = []
            x = xs[0] - pitch / 2.0
            while 0 < x < W and lot[mid, int(x)]:
                lines.append(x)
                x -= pitch
            x = xs[0] + pitch / 2.0
            while 0 < x < W and lot[mid, int(x)]:
                lines.append(x)
                x += pitch
            for lx in lines:
                xi = int(round(lx))
                for yy in range(max(y_top, 0), min(y_bot, H)):
                    if 0 <= xi < W and lot[yy, xi] and self.R[yy, xi] > 0.1:
                        over[yy, xi] = C["white"] if self.R[yy, xi] > 0.3 else C["white_dk"]
                        over_m[yy, xi] = True
                # Every stall gets a stain, parked in or not.
                cx, cy = int(lx + pitch / 2.0), int(foot - 8)
                if 0 <= cx < W and lot[min(cy, H - 1), min(cx, W - 1)] and F.hash2(np.array([cx]), np.array([cy]), 9)[0] < 0.55:
                    ey, ex = np.ogrid[-4:5, -7:8]
                    e = (ex / 5.5) ** 2 + (ey / 3.0) ** 2 + (F.hash2(ex + cx, ey + cy, 7) - 0.5) * 0.6 < 1.0
                    y0, x0 = cy - 4, cx - 7
                    if 0 <= y0 and y0 + 9 <= H and 0 <= x0 and x0 + 15 <= W:
                        sub = tone[y0:y0 + 9, x0:x0 + 15]
                        sub[e & lot[y0:y0 + 9, x0:x0 + 15]] -= 1.0

    # ------------------------------------------------------------ bridges

    def _bridge_spans(self):
        """Each bridge in the grid: its tile rectangle (y0, y1, x0, x1), whether
        its deck runs north-south, whether a road crosses it (road at both
        ends), and whether it stands beside a road (a parapet)."""
        g = self.grid
        seen = np.zeros(g.shape, bool)
        out = []
        for ty, tx in zip(*np.nonzero(g == BRIDGE)):
            if seen[ty, tx]:
                continue
            comp = []
            stack = [(ty, tx)]
            seen[ty, tx] = True
            while stack:
                y, x = stack.pop()
                comp.append((y, x))
                for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < self.th and 0 <= nx < self.tw and not seen[ny, nx] and g[ny, nx] == BRIDGE:
                        seen[ny, nx] = True
                        stack.append((ny, nx))
            ys = [c[0] for c in comp]
            xs = [c[1] for c in comp]
            y0, y1, x0, x1 = min(ys), max(ys) + 1, min(xs), max(xs) + 1
            # It spans the way the water isn't: water left and right means the
            # deck runs north-south.
            wl = np.isin(g[y0:y1, max(x0 - 1, 0)], WATER_SET).sum() + np.isin(g[y0:y1, min(x1, self.tw - 1)], WATER_SET).sum()
            wu = np.isin(g[max(y0 - 1, 0), x0:x1], WATER_SET).sum() + np.isin(g[min(y1, self.th - 1), x0:x1], WATER_SET).sum()
            vertical = wl > wu if wl != wu else (y1 - y0) >= (x1 - x0)
            if vertical:
                ends = (g[max(y0 - 1, 0), x0:x1] == ROAD).any() and (g[min(y1, self.th - 1), x0:x1] == ROAD).any()
            else:
                ends = (g[y0:y1, max(x0 - 1, 0)] == ROAD).any() and (g[y0:y1, min(x1, self.tw - 1)] == ROAD).any()
            beside_road = np.isin(g[max(y0 - 1, 0):y1 + 1, max(x0 - 1, 0):x1 + 1], (ROAD,)).any()
            out.append((y0, y1, x0, x1, vertical, bool(ends), beside_road))
        return out

    def _bridges(self, tone, M, over, over_m) -> None:
        """Bridges with no sprite of their own: a plank footbridge with rails,
        or, where a road crosses, an asphalt deck between concrete parapets.
        Each casts a shadow on the water beside it."""
        if any("bridge" in sp["tex"].lower() for sp in self.d["sprites"]):
            return
        T = self.T
        H, W = self.H, self.W
        for y0, y1, x0, x1, vertical, road, beside_road in self._bridge_spans():
            if not road and beside_road:
                # A parapet beside a road bridge: a granite wall, lit on top.
                py0, py1, px0, px1 = y0 * T, y1 * T, x0 * T, x1 * T
                sub_t = tone[py0:py1, px0:px1]
                M[py0:py1, px0:px1] = MAT["granite"]
                yy, xx = np.mgrid[py0:py1, px0:px1]
                block = F.hash2(xx // 8 + (yy // 5) * 3, yy // 5, self.seed + 183)
                sub_t[:] = 5.0 + (block > 0.6) - (block < 0.2)
                sub_t[(xx + (yy // 5) * 4) % 8 == 0] = 3.0
                sub_t[yy % 5 == 0] = 3.0
                sub_t[yy == py0] = 7.0
                sub_t[yy == py1 - 1] = 2.0
                over_m[py0:py1, px0:px1] = False
                continue
            py0, py1, px0, px1 = y0 * T, y1 * T, x0 * T, x1 * T
            if vertical:
                px0 += 2
                px1 -= 2
            else:
                py0 += 2
                py1 -= 2
            yy, xx = np.mgrid[py0:py1, px0:px1]
            along = (yy - py0) if vertical else (xx - px0)
            across = (xx - px0) if vertical else (yy - py0)
            width = (px1 - px0) if vertical else (py1 - py0)
            sub_t = tone[py0:py1, px0:px1]
            sub_m = M[py0:py1, px0:px1]
            if road:
                sub_m[:] = MAT["asphalt"]
                sub_t[:] = 3.0 + (self.R[py0:py1, px0:px1] > 0.94)
                rail = (across < 3) | (across >= width - 3)
                sub_m[rail] = MAT["concrete"]
                sub_t[rail] = np.where((across[rail] == 0) | (across[rail] == width - 3), 6.0, 4.0)
                sub_t[(across == 2) | (across == width - 1)] = 2.0
            else:
                sub_m[:] = MAT["wood"]
                plank = along // 3
                sub_t[:] = 3.0 + (F.hash2(plank, plank * 3, self.seed + 181) > 0.55) + (along % 3 == 0) * -1.0
                sub_t[(F.hash2(plank, across // 6, self.seed + 182) > 0.93)] -= 1.0
                rail = (across < 2) | (across >= width - 2)
                sub_t[rail] = 5.0
                sub_t[(across == 1) | (across == width - 1)] = 2.0
            # The shadow on the water to the right of, or below, the deck.
            if vertical:
                sy0, sy1, sx0, sx1 = py0 + 2, py1, px1, min(px1 + 3, W)
            else:
                sy0, sy1, sx0, sx1 = py1, min(py1 + 3, H), px0 + 2, px1
            sh = np.isin(M[sy0:sy1, sx0:sx1], (MAT["water"], MAT["lake"]))
            tone[sy0:sy1, sx0:sx1][sh] -= 2.0
            over_m[py0:py1, px0:px1] = False

    # ------------------------------------------------------------ the Ahwahnee

    def _hotel(self, tone, M, over, over_m) -> None:
        """The entrance circle (a gravel drive with a cobble curb round a lawn
        island) and the rose garden's four beds, as build_ahwahnee.gd lays them."""
        T = self.T
        g = self.grid
        H, W = self.H, self.W
        cols = [x for x in range(self.tw) if self.th > 46 and (g[46:, x] == PARKING).all()]
        if cols:
            cx = (cols[len(cols) // 2] + 0.5) * T
            cy = 42.0 * T
            ro = (10.5 * T, 5.6 * T)
            ri = (7.3 * T, 3.2 * T)
            yy, xx = np.mgrid[0:H, 0:W]
            dx = xx + 0.5 - cx
            dy = yy + 0.5 - cy
            eo = (dx / ro[0]) ** 2 + (dy / ro[1]) ** 2
            ei = (dx / ri[0]) ** 2 + (dy / ri[1]) ** 2
            ring = (eo <= 1.0) & (ei >= 1.0)
            curb = ring & ((eo > 0.9) | (ei < 1.16))
            drive = ring & ~curb
            island = ei < 1.0
            south = (self.K == PARKING) & (yy > cy) & (np.abs(dx) < 1.6 * T) & (eo > 1.0)
            gravel = drive | south
            M[gravel] = MAT["trail"]
            tone[gravel] = (4.0 + (self.Nm[gravel] > 0.55) + (self.R[gravel] > 0.85) - (self.R[gravel] < 0.1))
            out_lot = (self.K == PARKING) & (eo > 1.0) & ~south
            for sel in (island, out_lot):
                M[sel] = MAT["grass"]
                tone[sel] = 5.0 + (self.Nl[sel] > 0.55) + ((xx[sel] // 24) % 2)
            cob = F.hash2((xx[curb] + yy[curb]) // 3, (xx[curb] - yy[curb]) // 2, 90)
            col = np.where((cob > 0.5)[:, None], C["curb_hi"], C["curb"])
            joint = (eo[curb] > 0.975) | (ei[curb] < 1.04)
            col[joint] = C["curb_dk"]
            over[curb] = col
            over_m[curb] = True
        for qx, qy in ((63, 38), (70, 38), (63, 43), (70, 43)):
            mx = (qx + 3) * T
            my = (qy + 2) * T
            x0, y0, w, h = mx - 28, my - 14, 56, 28
            sub = np.zeros((H, W), bool)
            sub[y0 + 1:y0 + h - 1, x0:x0 + w] = True
            sub[y0:y0 + h, x0 + 1:x0 + w - 1] = True
            M[sub] = MAT["bed"]
            tone[sub] = 2.0 + (self.Ns[sub] > 0.55) + (self.R[sub] > 0.9) * 2


def main() -> None:
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        sys.exit(1)
    out_dir = None
    if "--out" in args:
        i = args.index("--out")
        out_dir = args[i + 1]
        del args[i:i + 2]
        os.makedirs(out_dir, exist_ok=True)
    dump_dir = args[0]
    wanted = set(args[1:])
    for name in sorted(os.listdir(dump_dir)):
        if not name.endswith(".json"):
            continue
        rid = name[:-5]
        if rid in SKIP or (wanted and rid not in wanted):
            continue
        dump = json.load(open(os.path.join(dump_dir, name)))
        out = Painter(dump).paint()
        path = os.path.join(ROOT, dump["ground"].replace("res://", ""))
        if out_dir:
            path = os.path.join(out_dir, os.path.basename(path))
        Image.fromarray(out, "RGBA").save(path)
        print("wrote", path)


if __name__ == "__main__":
    main()
