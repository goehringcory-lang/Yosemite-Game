"""The broadleaf trees, each in its seasons: California black oak, blue oak,
interior live oak, white alder, Pacific dogwood, western redbud, California
buckeye, the shrubby willows of the river banks and the homestead's old apple.

A broadleaf tree is grown as a branching skeleton in three dimensions: the
trunk forks into limbs, the limbs into branches and twigs, each bending a
little as it goes. Leaves sit in clumps round the twig ends, so in summer the
crown is a mass of lit clumps with the limbs showing through its gaps, and in
winter the same skeleton stands bare.
"""
from __future__ import annotations

import math
from dataclasses import dataclass, field

import numpy as np

from conifers import RAMPS as CONIFER_RAMPS
from kit import FOOT, Art, value_noise, voronoi

RAMPS = {
    # California black oak: glossy dark green in summer, lit yellow-green.
    "black_oak_leaf": ["0e1d14", "15281a", "1d341f", "264325", "31522a", "3e612f", "4d7134", "5f8239", "759341", "8ea44b"],
    # The spring flush: yellow-green, with new leaves unfolding pink-bronze.
    "oak_spring": ["1b2a16", "28391b", "374a20", "485c27", "5a6f2e", "6e8237", "849541", "9ca94d", "b5bc5c"],
    "oak_bronze": ["3c2420", "56332a", "704436", "8a5642", "a2694e", "b77d5c", "c9936c"],
    # Fall: gold, then russet and brown.
    "oak_gold": ["3d2a10", "583c13", "775217", "96691d", "b28226", "c99a31", "dcb142", "e9c75e"],
    "oak_russet": ["2e1a10", "462714", "5f3518", "79451d", "915524", "a6672e", "b97b3c"],
    "oak_dead": ["2a1d14", "3c2a1b", "513923", "674a2e", "7d5c3a"],
    "black_oak_bark": ["131211", "1e1c1a", "2a2724", "37332f", "45403b", "554f49", "665f58"],
    # Blue oak: small blue-green leaves, pale grey checkered bark.
    "blue_oak_leaf": ["16282a", "203632", "2b453c", "385446", "466451", "57745d", "6a856b", "80977c", "98aa90"],
    "blue_oak_bark": ["35332f", "4c4843", "645f58", "7d776e", "958e83", "aca59a", "c2bcb1"],
    "blue_oak_check": ["24221f", "34312d", "45413c", "57524b"],
    # Interior live oak: dense, dark, evergreen.
    "live_oak_leaf": ["0c1a12", "122416", "182f1b", "203b20", "294825", "33552a", "3f632f", "4c7235", "5c823e"],
    "live_oak_bark": ["1d1a18", "2b2622", "3a332d", "4a4139", "5b5046", "6d6054"],
    # White alder: dark green leaves, smooth pale bark.
    "alder_leaf": ["0e1f16", "15291b", "1c3621", "254428", "2f5230", "3b6138", "4a7141", "5b814b", "6f9257"],
    "alder_fall": ["2a2416", "403a1d", "5a5126", "736830", "8c7f3c", "a4964b", "baab5e"],
    "alder_bark": ["3b3b39", "555451", "706e69", "8c8984", "a7a49d", "bfbcb4", "d4d1c8"],
    "catkin": ["3a2420", "583630", "784a40", "96604e"],
    # Pacific dogwood: layered green tiers, white bracts in spring, red in fall.
    "dogwood_leaf": ["10221a", "17301f", "1f3e25", "294d2b", "345c31", "416b38", "4f7b40", "608c4b"],
    "bract": ["7f877b", "a6ae9f", "c9cfc0", "e6eadd", "f7f9f1"],
    "dogwood_fall": ["3a1418", "541b21", "6e2429", "892f32", "a13c3a", "b74e45", "c96552", "d68062"],
    "berry": ["4a0c10", "7a1618", "a82522", "cc4434"],
    "dogwood_bark": ["28231f", "3a332d", "4e453d", "62574d", "776a5e"],
    # Western redbud: magenta bloom on bare twigs, blue-green hearts, pods.
    "redbud_leaf": ["12261f", "1a3427", "23432f", "2e5338", "3a6341", "48744b", "588556", "6b9662"],
    "redbud_bloom": ["3e1430", "5c1c44", "7e2658", "a2346e", "c44a86", "de6ea0", "f096bc", "fcc0d8"],
    "redbud_fall": ["3a1c14", "57291a", "7a3d20", "9e5626", "bd722e", "d4903c", "e6ad52"],
    "redbud_bark": ["24181a", "362426", "4a3230", "5e423c", "725248"],
    "pod": ["2e1418", "48202a", "653038", "83424a"],
    # California buckeye: bright palmate leaves, flower candles, dry by July.
    "buckeye_leaf": ["132919", "1b381f", "264927", "315a2e", "3e6c35", "4d7e3d", "5f9046", "74a251", "8eb45f"],
    "buckeye_flower": ["a8988a", "c8baac", "e2d8ca", "f4eee4", "fcf8f2"],
    "buckeye_dry": ["2c1c14", "45301c", "634424", "82592e", "9f6f39", "b88646", "cc9e58"],
    "buckeye_bark": ["393735", "53504c", "6f6b65", "8b867e", "a6a097", "beb8ad", "d2cdc2"],
    "buckeye_fruit": ["3a2c1c", "56442c", "746040", "937c55", "ad966b"],
    # The willows: narrow grey-green leaves on red-brown wands.
    "willow_leaf": ["12251b", "1a3322", "24422a", "2f5132", "3b613a", "497043", "59804d", "6b9058", "80a266"],
    "willow_fall": ["2e2a14", "48421a", "655c22", "83772c", "a09238", "b9aa48", "ccbe5e"],
    "willow_bark": ["2a1913", "3f261b", "563424", "6e442f", "86563c"],
    # The old apple: gnarled bark, blossom, fruit.
    "apple_leaf": ["11231a", "19311f", "224026", "2c4f2d", "385e34", "466e3c", "557e45", "678f51"],
    "apple_bloom": ["b48090", "d09ca8", "e6bec4", "f4dcdc", "fcf2ee"],
    "apple_fruit": ["520e0e", "801a16", "a8281e", "c6402c", "da6640"],
    "apple_bark": ["211a15", "30261e", "413429", "534436", "665443"],
    "twig_snow": ["8698ae", "a7b7c8", "c8d4df", "e4ebf1", "f6f9fb"],
}


def ramps(**alias: str) -> dict[str, list[str]]:
    out = {}
    for k, v in alias.items():
        out[k] = RAMPS[v] if v in RAMPS else CONIFER_RAMPS[v]
    return out


# ------------------------------------------------------------------ skeleton

@dataclass
class Seg:
    pts: list[np.ndarray]  # 3D: x across, y up, z toward the viewer
    r0: float
    r1: float
    level: int


@dataclass
class Plan:
    """How a species branches."""
    trunk_h: float  # height of the first fork, in canvas pixels before fitting
    trunk_r: float  # trunk half width at the foot (pixels, kept through fitting)
    lean: float = 0.0
    levels: int = 3
    children: tuple = (3, 3, 2, 2)
    spread: tuple = ((0.45, 0.85), (0.35, 0.7), (0.3, 0.6), (0.3, 0.6))
    ratio: tuple = ((0.55, 0.75), (0.55, 0.75), (0.55, 0.7), (0.5, 0.7))
    first_len: float = 30.0
    thin: float = 0.62
    tropism: float = 0.06  # bend toward the sky per step
    wobble: float = 0.16
    stems: int = 1  # stems from the ground (shrubs, multi-trunked trees)
    stem_spread: float = 0.5


def _norm(v: np.ndarray) -> np.ndarray:
    n = np.linalg.norm(v)
    return v / n if n > 1e-9 else v


def _turn(d: np.ndarray, ang: float, roll: float) -> np.ndarray:
    up = np.array([0.0, 1.0, 0.0]) if abs(d[1]) < 0.9 else np.array([1.0, 0.0, 0.0])
    p1 = _norm(np.cross(d, up))
    p2 = np.cross(d, p1)
    perp = math.cos(roll) * p1 + math.sin(roll) * p2
    return _norm(math.cos(ang) * d + math.sin(ang) * perp)


def grow(plan: Plan, rng: np.random.Generator) -> tuple[list[Seg], list[tuple[np.ndarray, np.ndarray, int]]]:
    segs: list[Seg] = []
    tips: list[tuple[np.ndarray, np.ndarray, int]] = []

    def branch(p: np.ndarray, d: np.ndarray, length: float, r: float, level: int) -> None:
        steps = 3 if level > 0 else 4
        pts = [p.copy()]
        cur, dd = p.copy(), d.copy()
        wob = plan.wobble * (0.35 if level == 0 else 1.0)
        for _ in range(steps):
            dd = _norm(dd + rng.normal(size=3) * wob + np.array([0.0, plan.tropism, 0.0]))
            cur = cur + dd * length / steps
            pts.append(cur.copy())
        r_end = r * (0.78 if level == 0 else plan.thin)
        segs.append(Seg(pts, r, r_end, level))
        if level >= plan.levels:
            tips.append((cur, dd, level))
            return
        n = plan.children[min(level, len(plan.children) - 1)]
        roll0 = rng.random() * 6.283
        lo, hi = plan.spread[min(level, len(plan.spread) - 1)]
        ra, rb = plan.ratio[min(level, len(plan.ratio) - 1)]
        for k in range(n):
            ang = rng.uniform(lo, hi)
            roll = roll0 + k * 6.283 / n + rng.normal() * 0.35
            nd = _turn(dd, ang, roll)
            nl = (plan.first_len if level == 0 else length) * rng.uniform(ra, rb) * (1.0 if level else 1.0)
            branch(cur, nd, nl, r_end * (0.85 if level == 0 else 1.0), level + 1)
        # a side branch from partway along, now and then
        if level >= 1 and rng.random() < 0.5:
            mid = pts[len(pts) // 2]
            nd = _turn(dd, rng.uniform(0.6, 1.0), rng.random() * 6.283)
            branch(mid, nd, length * rng.uniform(0.35, 0.55), r_end * 0.8, level + 1)

    for s in range(plan.stems):
        if plan.stems > 1:
            roll = s * 6.283 / plan.stems + rng.normal() * 0.3
            d = _turn(np.array([0.0, 1.0, 0.0]), plan.stem_spread * rng.uniform(0.6, 1.1), roll)
            base = np.array([rng.normal() * 1.2, 0.0, rng.normal() * 0.8])
            branch(base, d, plan.trunk_h * rng.uniform(0.7, 1.05), plan.trunk_r * rng.uniform(0.55, 0.75), 0)
        else:
            d = _norm(np.array([plan.lean * 0.04, 1.0, 0.0]))
            branch(np.zeros(3), d, plan.trunk_h, plan.trunk_r, 0)
    return segs, tips


# ------------------------------------------------------------------ the tree

@dataclass
class Clump:
    x: float
    y: float
    r: float
    z: float
    seed: int
    mat: str
    bright: float = 0.0
    spikes: int = 8
    spike: float = 0.4
    squash: float = 1.0


@dataclass
class Look:
    """What a season puts on the skeleton."""
    leaves: list[tuple[str, float]] = field(default_factory=list)  # (material, weight)
    density: float = 1.0  # share of clumps kept
    dots: list[tuple[str, float, float]] = field(default_factory=list)  # (material, per clump, size)
    snow: float = 0.0
    hang: str = ""  # material of things hanging below twigs (fruit, pods, catkins)
    hang_n: int = 0
    hang_p: float = 0.4  # share of twig ends that carry them


class Broadleaf:
    def __init__(self, W: int, H: int, seed: int, plan: Plan, bark: str, mats: dict[str, str], *,
                 crown_w: float, crown_top: float = 3.0, lobe: tuple[float, float] = (5.0, 8.0),
                 clump_r: tuple[float, float] = (2.0, 3.4), per_lobe: tuple[int, int] = (4, 7),
                 bark_plates: tuple[float, float] = (2.0, 3.5), fissure: str = "", squash: float = 1.0,
                 spikes: int = 8, spike: float = 0.4, along: float = 0.6, tiers: bool = False,
                 twigs: int = 4, twig_len: float = 4.0, wide: float = 1.5, fissure_w: float = 0.3) -> None:
        self.W, self.H = W, H
        self.fissure_w = fissure_w
        self.seed = seed
        self.plan = plan
        self.bark = bark
        self.fissure = fissure
        self.mats = mats
        self.bark_plates = bark_plates
        self.rng = np.random.default_rng(seed)
        rng = self.rng
        self.bx, self.by = W / 2.0, H - FOOT
        segs, tips = grow(plan, rng)
        self.segs, self.tips = segs, tips
        self.zmax = max(1e-3, max(abs(p[2]) for s in segs for p in s.pts))
        # Fit the skeleton to the canvas: the crown (with its leaf clumps, which
        # reach about a lobe past the twig ends) fills crown_w and comes up to
        # crown_top. Across may stretch a little more than up, as a spreading
        # oak's crown does.
        reach = lobe[1] * 0.85 + clump_r[1] * 1.2
        xs = [p[0] for s in segs for p in s.pts]
        ys = [p[1] for s in segs for p in s.pts]
        span = max(1e-3, max(abs(min(xs)), abs(max(xs))))
        fx = (crown_w / 2.0 - reach) / span
        fy = (self.by - crown_top - reach) / max(1e-3, max(ys))
        self.fy = fy
        self.fx = min(max(fx, fy * 0.7), fy * wide)
        # leaf clumps round every twig end and along the last branches
        self.clumps: list[Clump] = []
        for p, d, lv in tips:
            n = int(rng.integers(per_lobe[0], per_lobe[1] + 1))
            lr = rng.uniform(*lobe)
            tx, ty = self.project(p)
            for _ in range(n):
                ox, oy = rng.normal() * lr * 0.55, rng.normal() * lr * 0.42 - lr * 0.25
                self.clumps.append(Clump(tx + ox, ty + oy, rng.uniform(*clump_r), float(p[2] / self.zmax) + rng.normal() * 0.1,
                                         int(rng.integers(1 << 30)), "", 0.0, spikes, spike, squash))
        for s in segs:
            if s.level >= max(1, plan.levels - 1):
                for f in np.linspace(0.3, 0.9, 3):
                    if rng.random() > along:
                        continue
                    i = min(len(s.pts) - 2, int(f * (len(s.pts) - 1)))
                    q = s.pts[i] + (s.pts[i + 1] - s.pts[i]) * (f * (len(s.pts) - 1) - i)
                    x, y = self.project(q)
                    self.clumps.append(Clump(x + rng.normal() * 1.5, y - 1.5 + rng.normal() * 1.5, rng.uniform(*clump_r),
                                             float(q[2] / self.zmax), int(rng.integers(1 << 30)), "", 0.0, spikes, spike,
                                             squash))
        if tiers:
            # a dogwood's layered look: clumps settle into level tiers
            for c in self.clumps:
                band = 5.0
                c.y = round(c.y / band) * band + (c.y % band) * 0.3
        # a clump with no other near it would float free of the tree
        keep = []
        for c in self.clumps:
            near = sum(1 for o in self.clumps if o is not c and (o.x - c.x) ** 2 + (o.y - c.y) ** 2 < (c.r + o.r + 1.5) ** 2)
            if near >= 1:
                keep.append(c)
        self.clumps = keep
        # keep the crown inside the canvas, with room for the outline: squeeze
        # it toward the trunk (and down) as a whole, so nothing piles up at an edge
        kx = 1.0
        for c in self.clumps:
            ext = c.r * (1.0 + 0.65 * c.spike) + 1.5
            off = abs(c.x - self.bx)
            room = W / 2.0 - ext - 0.5
            if off > room > 0:
                kx = min(kx, room / off)
        ky = 1.0
        for c in self.clumps:
            ext = c.r * (1.0 + 0.65 * c.spike) * c.squash + 1.5
            if c.y - ext < 0:
                ky = min(ky, (self.by - ext) / max(1e-3, self.by - c.y))
        for c in self.clumps:
            c.x = self.bx + (c.x - self.bx) * kx
            c.y = self.by - (self.by - c.y) * ky
        self.fx *= kx
        self.fy *= ky
        # the bare crown's twigs: fine sprays off every branch end
        self.twigs: list[tuple[list[tuple[float, float]], float]] = []
        for p, d, lv in tips:
            x0, y0 = self.project(p)
            for _ in range(twigs):
                a = math.atan2(-float(d[1]), float(d[0])) + rng.normal() * 0.8
                a = min(max(a, -math.pi + 0.3), -0.3) if rng.random() < 0.8 else a
                ln = twig_len * rng.uniform(0.6, 1.2)
                xm, ym = x0 + math.cos(a) * ln * 0.5, y0 + math.sin(a) * ln * 0.5
                a2 = a + rng.normal() * 0.4
                x1, y1 = xm + math.cos(a2) * ln * 0.5, ym + math.sin(a2) * ln * 0.5
                x1 = min(max(x1, 1.5), W - 2.5)
                y1 = max(y1, 1.5)
                self.twigs.append(([(x0, y0), (xm, ym), (x1, y1)], float(p[2] / self.zmax)))
        xs2 = [c.x for c in self.clumps] or [self.bx]
        ys2 = [c.y for c in self.clumps] or [self.by / 2]
        self.cx = float(np.mean(xs2))
        self.cy = float(np.mean(ys2)) - 2
        self.rx = max(4.0, (max(xs2) - min(xs2)) / 2 + clump_r[1])
        self.ry = max(4.0, (max(ys2) - min(ys2)) / 2 + clump_r[1])

    def project(self, p: np.ndarray) -> tuple[float, float]:
        return self.bx + float(p[0]) * self.fx, self.by - float(p[1]) * self.fy + float(p[2]) * self.fx * 0.18

    # ------------------------------------------------------------ painting

    def paint(self, look: Look) -> Art:
        mats = dict(self.mats)
        mats["bark"] = self.bark
        if self.fissure:
            mats["fissure"] = self.fissure
        for m, _w in look.leaves:
            mats[m] = m
        for m, _n, _s in look.dots:
            mats[m] = m
        if look.hang:
            mats[look.hang] = look.hang
        mats["snow"] = "twig_snow"
        art = Art(self.W, self.H, ramps(**mats), self.seed)
        for m, _w in look.leaves:
            art.dither[m] = 0.26
        rng = np.random.default_rng(self.seed + 99)
        # choose which clumps this season keeps, and their colours
        clumps = []
        if look.leaves:
            weights = np.array([w for _m, w in look.leaves], dtype=np.float64)
            weights /= weights.sum()
            for c in self.clumps:
                if rng.random() > look.density:
                    continue
                m = look.leaves[int(rng.choice(len(look.leaves), p=weights))][0]
                clumps.append(Clump(c.x, c.y, c.r, c.z, c.seed, m, rng.normal() * 0.05, c.spikes, c.spike, c.squash))
        bare = not clumps
        # back to front: the limbs and clumps behind, the trunk, the ones in front
        items = []
        for s in self.segs:
            z = float(np.mean([p[2] for p in s.pts]) / self.zmax)
            items.append((z if s.level > 0 else 0.0, 0, s))
        for c in clumps:
            items.append((c.z, 2, c))
        for tw in self.twigs:
            items.append((tw[1], 1, tw))
        items.sort(key=lambda t: (t[0], t[1]))
        for z, kind, it in items:
            if kind == 0:
                self._seg(art, it, bare, look.snow)
            elif kind == 1:
                self._twig(art, it)
            else:
                self._clump(art, it)
        self._flat_bottom(art)
        # flowers, berries, fruit and the like dotted over the lit clumps
        for m, per, size in look.dots:
            for c in clumps:
                n = int(per) + (1 if rng.random() < per - int(per) else 0)
                for _ in range(n):
                    a = rng.random() * 6.283
                    rr = c.r * rng.uniform(0.0, 0.8)
                    x, y = c.x + math.cos(a) * rr, c.y + math.sin(a) * rr * 0.8 - c.r * 0.2
                    self._dot(art, x, y, size, m, 0.55 + 0.4 * (c.z * 0.3 + 0.5 - (y - c.y) / (2 * c.r + 1)))
        if look.hang:
            for p, _d, _lv in self.tips:
                if rng.random() > look.hang_p:
                    continue
                for _ in range(max(1, look.hang_n)):
                    x, y = self.project(p + rng.normal(size=3) * 1.2)
                    m, info = art.capsule(x, y, x + rng.normal() * 0.3, y + 2.4, 0.9, 0.7)
                    art.put(m, look.hang, 0.35 + 0.5 * Art.diffuse(info[1], info[2]))
        return art

    def _flat_bottom(self, art: Art) -> None:
        art.mat[int(self.by) + 1:, :] = -1

    def _seg(self, art: Art, s: Seg, bare: bool, snow: float) -> None:
        pts = [self.project(p) for p in s.pts]
        r0, r1 = s.r0, s.r1
        if s.level >= self.plan.levels and not bare:
            return  # twigs are hidden in the leaves
        m, info = art.polyline(pts, max(0.5, r0), max(0.45, r1))
        if s.level == 0:
            # the trunk's foot widens into the ground
            fy = self.by - 5
            fl = (art.Y + 0.5 > fy) & (art.Y < self.by + 1)
            k = np.clip((art.Y + 0.5 - fy) / 5, 0, 1) ** 1.6
            half = r0 + 1.4 * k
            x0 = pts[0][0]
            fm = fl & (np.abs(art.X + 0.5 - x0) <= half)
            nx = np.where(fm, np.clip((art.X + 0.5 - x0) / (half + 0.01), -1, 1), info[1])
            ny = np.where(fm, 0.0, info[2])
            m = m | fm
        else:
            nx, ny = info[1], info[2]
        light = Art.diffuse(nx, ny)
        art.put(m, "bark", 0.14 + 0.8 * light)
        if self.fissure and s.level <= 1:
            _idx, edge, rv = voronoi(art.w, art.h, self.bark_plates[0], self.bark_plates[1], self.seed + s.level, 1.0, 0.5)
            fis = m & (edge < self.fissure_w)
            art.put(fis, "fissure", 0.1 + 0.6 * light)
        if snow > 0 and bare:
            # snow lying along the top of the limb
            top = m & (ny < -0.35) & (value_noise(art.w, art.h, 3, self.seed + 5) < snow + 0.3)
            art.put(top, "snow", 0.55 + 0.45 * light)

    def _twig(self, art: Art, tw: tuple[list[tuple[float, float]], float]) -> None:
        pts, z = tw
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
            for i in range(n + 1):
                f = i / max(1, n)
                xi, yi = int(x0 + (x1 - x0) * f), int(y0 + (y1 - y0) * f)
                if 0 <= xi < art.w and 0 <= yi < art.h:
                    art.mat[yi, xi] = art.m("bark")
                    art.val[yi, xi] = 0.3 + 0.2 * z

    def _clump(self, art: Art, c: Clump) -> None:
        m, nx, ny = art.blob(c.x, c.y, c.r, c.spikes, c.spike, c.seed, c.squash)
        if not m.any():
            return
        cnx = np.clip((art.X + 0.5 - self.cx) / self.rx, -1, 1)
        cny = np.clip((art.Y + 0.5 - self.cy) / self.ry, -1, 1)
        cnz = np.clip(np.sqrt(np.clip(1 - cnx * cnx - cny * cny, 0, 1)) * 0.7 + c.z * 0.3, 0, 1)
        dc = Art.diffuse(cnx, cny, cnz)
        dl = Art.diffuse(nx, ny)
        v = 0.08 + 0.56 * dc + 0.4 * (dl - 0.3) + 0.1 * c.z + c.bright - 0.1 * np.clip(ny, 0, 1)
        art.put(m, c.mat, v)

    @staticmethod
    def _dot(art: Art, x: float, y: float, size: float, mat: str, v: float) -> None:
        if size <= 1.0:
            xi, yi = int(x), int(y)
            if 0 <= xi < art.w and 0 <= yi < art.h and art.mat[yi, xi] >= 0:
                art.mat[yi, xi] = art.m(mat)
                art.val[yi, xi] = v
            return
        m = art.ellipse(x, y, size * 0.6, size * 0.6) & (art.mat >= 0)
        art.put(m, mat, v)


# ------------------------------------------------------------------ species

SEASONS = ("spring", "summer", "fall", "winter")


def black_oak(W: int, H: int, variant: str, season: str = "summer") -> Art:
    """Quercus kelloggii, the Valley's oak: a short trunk of black, ridged
    bark forking into big crooked limbs under a broad, irregular, open crown
    of large glossy leaves. Spring: the flush of yellow-green with new
    leaves unfolding pink-bronze; fall: gold and russet; winter: bare, a few
    brown leaves hanging on, snow along the limbs."""
    seed = {"a": 701, "b": 724, "c": 747}[variant]
    lean = {"a": -3.0, "b": 3.5, "c": 0.0}[variant]
    plan = Plan(trunk_h=16 if variant != "b" else 19, trunk_r=4.6, lean=lean, levels=3, children=(3, 3, 2, 2),
                spread=((0.55, 1.0), (0.35, 0.75), (0.3, 0.65)), first_len=30, thin=0.6, tropism=0.04, wobble=0.2)
    t = Broadleaf(W, H, seed, plan, "black_oak_bark", {}, crown_w=W * (0.98 if variant != "b" else 0.9), crown_top=3,
                  lobe=(6.5, 9.5), clump_r=(2.5, 4.0), per_lobe=(5, 8), bark_plates=(2.2, 3.6),
                  fissure="ponderosa_fissure", spikes=9, spike=0.45, twigs=5, twig_len=5.0)
    looks = {
        "summer": Look(leaves=[("black_oak_leaf", 1.0)]),
        "spring": Look(leaves=[("oak_spring", 0.9), ("oak_bronze", 0.1)], density=0.92),
        "fall": Look(leaves=[("oak_gold", 0.62), ("oak_russet", 0.38)], density=0.85),
        "winter": Look(leaves=[], snow=0.25),
    }
    art = t.paint(looks[season])
    if season == "winter":
        # a few dead leaves hang on through the winter
        rng = np.random.default_rng(seed + 3)
        saved = [(c.r) for c in t.clumps]
        for c in t.clumps:
            c.r = 0.9
        art2 = t.paint(Look(leaves=[("oak_dead", 1.0)], density=0.12))
        for c, r in zip(t.clumps, saved):
            c.r = r
        keep = (art2.mat >= 0) & (art2.mat == art2.m("oak_dead"))
        art.names.append("oak_dead")
        art.ramps.append(art2.ramps[art2.m("oak_dead")])
        art.dither["oak_dead"] = 0.3
        sel = keep & (art.mat == -1)
        art.mat[sel] = art.m("oak_dead")
        art.val[sel] = art2.val[sel]
        del rng
    return art


def blue_oak(W: int, H: int, variant: str, season: str = "summer") -> Art:
    """Quercus douglasii on El Portal's gold hills: a stout trunk of pale,
    checkered grey bark and a compact, rounded crown of small blue-green
    leaves; gold-brown in fall, bare and twiggy in winter."""
    seed = 801 if variant == "a" else 812
    plan = Plan(trunk_h=16, trunk_r=3.3, lean=-2 if variant == "a" else 2, levels=3, children=(3, 3, 2),
                spread=((0.55, 1.0), (0.4, 0.75), (0.35, 0.7)), first_len=22, thin=0.6, tropism=0.04, wobble=0.24)
    t = Broadleaf(W, H, seed, plan, "blue_oak_bark", {}, crown_w=W * 0.94, crown_top=3, lobe=(4.5, 7.0),
                  clump_r=(1.8, 3.0), per_lobe=(5, 8), bark_plates=(2.4, 2.8), fissure="blue_oak_check",
                  spikes=9, spike=0.35, fissure_w=0.22)
    looks = {
        "summer": Look(leaves=[("blue_oak_leaf", 1.0)]),
        "fall": Look(leaves=[("oak_gold", 0.5), ("oak_russet", 0.5)], density=0.8),
        "winter": Look(leaves=[]),
    }
    return t.paint(looks.get(season, looks["summer"]))


def live_oak(W: int, H: int, variant: str, season: str = "summer") -> Art:
    """Quercus wislizeni: evergreen, a dense dark dome of small hard leaves
    on a short trunk that splits low into several stems."""
    seed = 901 if variant == "a" else 913
    plan = Plan(trunk_h=12, trunk_r=3.4, lean=0, levels=3, children=(4, 3, 2), spread=((0.6, 1.05), (0.4, 0.8), (0.35, 0.7)),
                first_len=24, thin=0.6, tropism=0.03, wobble=0.22)
    t = Broadleaf(W, H, seed, plan, "live_oak_bark", {}, crown_w=W * 0.95, crown_top=3, lobe=(5.0, 8.0),
                  clump_r=(2.0, 3.2), per_lobe=(7, 10), along=0.9, spikes=10, spike=0.32)
    return t.paint(Look(leaves=[("live_oak_leaf", 1.0)]))


def alder(W: int, H: int, variant: str, season: str = "summer") -> Art:
    """Alnus rhombifolia along the rivers: a straight, smooth, pale grey trunk
    and a narrow, upright oval crown of dark green leaves; in fall they brown
    and drop, and in winter purple-brown catkins hang from the bare twigs."""
    seed = 1001 if variant == "a" else 1012
    plan = Plan(trunk_h=20, trunk_r=2.3, lean=0.5 if variant == "a" else -0.5, levels=3, children=(3, 2, 2),
                spread=((0.2, 0.45), (0.25, 0.55), (0.3, 0.6)), first_len=30, thin=0.6, tropism=0.16, wobble=0.14)
    t = Broadleaf(W, H, seed, plan, "alder_bark", {}, crown_w=W * 0.94, crown_top=3, lobe=(4.0, 6.0),
                  clump_r=(1.8, 2.9), per_lobe=(5, 8), along=0.9, spikes=9, spike=0.38, wide=1.0)
    looks = {
        "summer": Look(leaves=[("alder_leaf", 1.0)]),
        "fall": Look(leaves=[("alder_fall", 0.7), ("alder_leaf", 0.3)], density=0.7),
        "winter": Look(leaves=[], hang="catkin", hang_n=1, hang_p=0.5),
    }
    art = t.paint(looks.get(season, looks["summer"]))
    _lenticels(art, t.seed)
    return art


def _lenticels(art: Art, seed: int) -> None:
    """The dark marks on smooth pale bark (alder, buckeye)."""
    rng = np.random.default_rng(seed + 7)
    bark = art.mat == art.m("bark")
    ys, xs = np.nonzero(bark)
    for _ in range(max(1, len(ys) // 40)):
        i = int(rng.integers(len(ys)))
        art.val[ys[i], xs[i]] -= 0.35
        if xs[i] + 1 < art.w and bark[ys[i], xs[i] + 1]:
            art.val[ys[i], xs[i] + 1] -= 0.3


def dogwood(W: int, H: int, variant: str, season: str = "spring") -> Art:
    """Cornus nuttallii in the shade of the big conifers: a small tree with
    level, layered branches. Spring: big white bracts floating over the
    tiers; summer: green; fall: rose-red leaves and red berries; winter: bare
    twigs, upturned, with the round flower buds already set."""
    seed = 1101 if variant == "a" else 1123
    plan = Plan(trunk_h=14, trunk_r=1.9, lean=1 if variant == "a" else -1.5, levels=3, children=(3, 3, 2),
                spread=((0.75, 1.15), (0.5, 0.9), (0.4, 0.8)), first_len=18, thin=0.62, tropism=0.02, wobble=0.18)
    t = Broadleaf(W, H, seed, plan, "dogwood_bark", {}, crown_w=W * 0.95, crown_top=6, lobe=(4.0, 6.0),
                  clump_r=(1.7, 2.6), per_lobe=(4, 6), squash=0.7, spikes=8, spike=0.36, tiers=True)
    looks = {
        "spring": Look(leaves=[("dogwood_leaf", 1.0)], density=0.9, dots=[("bract", 0.7, 1.0)]),
        "summer": Look(leaves=[("dogwood_leaf", 1.0)]),
        "fall": Look(leaves=[("dogwood_fall", 1.0)], density=0.9, dots=[("berry", 0.6, 1.0)]),
        "winter": Look(leaves=[], dots=[]),
    }
    art = t.paint(looks[season])
    if season == "spring":
        _bracts(art, seed)
    return art


def _bracts(art: Art, seed: int) -> None:
    """Turns each white dot into a dogwood 'flower': four (or six) bracts
    round a green-yellow eye."""
    m = art.mat == art.m("bract")
    ys, xs = np.nonzero(m)
    eye = art.m("dogwood_leaf") if "dogwood_leaf" in art.names else None
    for y, x in zip(ys, xs):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            xx, yy = x + dx, y + dy
            if 0 <= xx < art.w and 0 <= yy < art.h and art.mat[yy, xx] >= 0:
                art.mat[yy, xx] = art.m("bract")
                art.val[yy, xx] = 0.75 if dy <= 0 and dx <= 0 else 0.5
        if eye is not None:
            art.mat[y, x] = eye
            art.val[y, x] = 0.95


def redbud(W: int, H: int, variant: str = "a", season: str = "summer") -> Art:
    """Cercis occidentalis on the canyon slopes: a many-stemmed shrub-tree.
    Spring: magenta bloom crowding the bare twigs before the leaves; summer:
    round blue-green leaves; fall: yellow and rust, with the flat pods
    hanging; winter: bare, pods still on."""
    seed = 1201
    plan = Plan(trunk_h=10, trunk_r=1.4, levels=3, children=(3, 2, 2), spread=((0.4, 0.8), (0.35, 0.7), (0.3, 0.6)),
                first_len=11, thin=0.65, tropism=0.08, wobble=0.22, stems=4, stem_spread=0.55)
    t = Broadleaf(W, H, seed, plan, "redbud_bark", {}, crown_w=W * 0.95, crown_top=3, lobe=(3.0, 5.0),
                  clump_r=(1.5, 2.5), per_lobe=(4, 6), spikes=8, spike=0.3)
    looks = {
        "spring": Look(leaves=[("redbud_bloom", 1.0)], density=0.95),
        "summer": Look(leaves=[("redbud_leaf", 1.0)]),
        "fall": Look(leaves=[("redbud_fall", 0.8), ("redbud_leaf", 0.2)], density=0.8, hang="pod", hang_n=1, hang_p=0.3),
        "winter": Look(leaves=[], hang="pod", hang_n=1, hang_p=0.3),
    }
    return t.paint(looks[season])


def buckeye(W: int, H: int, variant: str = "a", season: str = "spring") -> Art:
    """Aesculus californica: a broad, low dome on several smooth silver stems.
    Spring into June: bright palmate leaves with upright candles of creamy
    flowers; summer: the leaves dry brown in the heat and fall; fall and
    winter: bare silver limbs hung with big, pear-shaped seed pods."""
    seed = 1301
    plan = Plan(trunk_h=11, trunk_r=1.9, levels=3, children=(3, 2, 2), spread=((0.55, 0.95), (0.4, 0.8), (0.35, 0.7)),
                first_len=18, thin=0.62, tropism=0.03, wobble=0.18, stems=3, stem_spread=0.7)
    t = Broadleaf(W, H, seed, plan, "buckeye_bark", {}, crown_w=W * 0.96, crown_top=3, lobe=(4.5, 7.0),
                  clump_r=(2.0, 3.2), per_lobe=(5, 8), squash=0.85, spikes=7, spike=0.42)
    looks = {
        "spring": Look(leaves=[("buckeye_leaf", 1.0)], dots=[("buckeye_flower", 0.35, 1.0)]),
        "summer": Look(leaves=[("buckeye_dry", 0.85), ("buckeye_leaf", 0.15)], density=0.75),
        "fall": Look(leaves=[], hang="buckeye_fruit", hang_n=1, hang_p=0.45),
        "winter": Look(leaves=[], hang="buckeye_fruit", hang_n=1, hang_p=0.35),
    }
    art = t.paint(looks[season])
    if season == "spring":
        _candles(art)
    _lenticels(art, seed)
    return art


def _candles(art: Art) -> None:
    """Draws each flower dot up into an upright candle, three pixels tall."""
    m = art.mat == art.m("buckeye_flower")
    ys, xs = np.nonzero(m)
    for y, x in zip(ys, xs):
        for dy in (1, 2, 3):
            yy = y - dy
            if yy >= 0:
                art.mat[yy, x] = art.m("buckeye_flower")
                art.val[yy, x] = 0.85 - dy * 0.12 + (0.1 if x % 2 else 0.0)


def willow(W: int, H: int, variant: str, season: str = "summer") -> Art:
    """The willows of the Merced's banks (arroyo and shining willow): not the
    weeping willow of gardens but a thicket of upright, arching red-brown
    wands with narrow grey-green leaves; yellow in fall, bare in winter."""
    seed = 1401 if variant == "a" else 1414
    plan = Plan(trunk_h=30, trunk_r=1.1, levels=2, children=(2, 2, 2), spread=((0.12, 0.3), (0.15, 0.35)),
                first_len=16, thin=0.7, tropism=0.08, wobble=0.1, stems=9, stem_spread=0.38)
    t = Broadleaf(W, H, seed, plan, "willow_bark", {}, crown_w=W * 0.96, crown_top=3, lobe=(3.0, 5.0),
                  clump_r=(1.4, 2.3), per_lobe=(4, 6), along=1.0, squash=1.6, spikes=12, spike=0.6, wide=1.2,
                  twigs=2, twig_len=3.0)
    looks = {
        "summer": Look(leaves=[("willow_leaf", 1.0)]),
        "fall": Look(leaves=[("willow_fall", 0.8), ("willow_leaf", 0.2)], density=0.85),
        "winter": Look(leaves=[]),
    }
    return t.paint(looks.get(season, looks["summer"]))


def apple(W: int, H: int, variant: str = "a", season: str = "summer") -> Art:
    """The Lamon orchard's old apple, planted in the 1860s: a gnarled, leaning
    trunk and crooked spreading limbs. Spring: pink-white blossom; summer:
    green with small apples setting; fall: yellowing leaves and red apples;
    winter: bare spurs."""
    seed = 1501
    plan = Plan(trunk_h=12, trunk_r=2.4, lean=2, levels=3, children=(3, 2, 2), spread=((0.6, 1.0), (0.45, 0.85), (0.4, 0.8)),
                first_len=18, thin=0.6, tropism=0.03, wobble=0.22)
    t = Broadleaf(W, H, seed, plan, "apple_bark", {}, crown_w=W * 0.95, crown_top=4, lobe=(4.0, 6.0),
                  clump_r=(1.8, 2.8), per_lobe=(5, 7), spikes=8, spike=0.35)
    looks = {
        "spring": Look(leaves=[("apple_bloom", 0.7), ("apple_leaf", 0.3)]),
        "summer": Look(leaves=[("apple_leaf", 1.0)], dots=[("apple_fruit", 0.35, 1.0)]),
        "fall": Look(leaves=[("oak_gold", 0.5), ("apple_leaf", 0.5)], density=0.85, dots=[("apple_fruit", 0.8, 1.6)]),
        "winter": Look(leaves=[], snow=0.15),
    }
    return t.paint(looks[season])


def whitebark(W: int, H: int, variant: str = "a", season: str = "summer") -> Art:
    """Pinus albicaulis on the granite above Tuolumne: wind-pruned, several
    pale grey stems swept up from one base, the dark yellow-green needles
    bunched in tufts at their tips."""
    seed = 1601
    plan = Plan(trunk_h=14, trunk_r=1.6, levels=2, children=(2, 2, 2), spread=((0.3, 0.6), (0.3, 0.6)),
                first_len=13, thin=0.65, tropism=0.06, wobble=0.24, stems=5, stem_spread=0.6)
    t = Broadleaf(W, H, seed, plan, "whitebark_bark", {}, crown_w=W * 0.95, crown_top=3, lobe=(3.0, 4.5),
                  clump_r=(1.8, 2.8), per_lobe=(4, 6), along=0.7, spikes=13, spike=0.9, twigs=0)
    return t.paint(Look(leaves=[("whitebark_needle", 1.0)]))

