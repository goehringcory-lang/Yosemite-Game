"""The park's conifers: the pines (ponderosa, Jeffrey, sugar, lodgepole, gray
pine, whitebark), the firs (white and red), incense cedar and the giant
sequoia, each built the way the tree grows and lit as one volume.

A tree is a trunk and a set of limbs in three dimensions (x across the screen,
y up the trunk, z toward the viewer), projected straight onto the canvas. The
limbs behind the trunk are painted first, then the trunk, then the limbs in
front, so the crown wraps round it. Foliage is laid along each limb as clumps
(needle tufts, flat sprays) lit twice: by where the clump sits on the crown,
which makes the whole tree one round lit form, and by the clump's own rounded
surface, which gives the brushy texture of needles in sun and shade.
"""
from __future__ import annotations

import math
from dataclasses import dataclass, field

import numpy as np

from kit import Art, value_noise, voronoi


@dataclass
class Limb:
    pts: list[tuple[float, float]]  # projected points, trunk to tip
    z: float  # depth of the tip, -1 (behind) .. 1 (in front)
    r0: float
    r1: float
    dead: bool = False


@dataclass
class Tuft:
    x: float
    y: float
    r: float
    z: float
    seed: int
    mat: str = "needle"
    squash: float = 1.0
    spikes: int = 9
    spike: float = 0.55
    bright: float = 0.0  # extra light (sun-caught tips)


@dataclass
class Crown:
    """Where the crown's lit volume sits, for the large-scale light."""
    cx: float
    cy: float
    rx: float
    ry: float


@dataclass
class Tree:
    art: Art
    base: tuple[float, float]
    limbs: list[Limb] = field(default_factory=list)
    tufts: list[Tuft] = field(default_factory=list)
    crown: Crown | None = None


# ------------------------------------------------------------------ trunk

def trunk(art: Art, pts: list[tuple[float, float]], r_base: float, r_top: float,
          bark: str = "bark", fissure: str = "fissure", plates: tuple[float, float] = (3.0, 6.0),
          flare: float = 1.6, flare_h: float = 5.0, seed: int = 1, plate_light: float = 0.16,
          fissure_w: float = 0.55, strips: bool = False) -> np.ndarray:
    """Paints the trunk along [param pts] (base first). Bark plates are cells
    split by dark fissures; the trunk is lit as a cylinder from the left.
    Returns the trunk's mask."""
    mask, info = art.polyline(pts, r_base, r_top)
    bx, by = pts[0]
    nx = info[1]
    # the root flare: the trunk widens into the ground
    if flare > 0:
        fl = (art.Y + 0.5 > by - flare_h) & (art.Y < by + 1)
        k = np.clip((art.Y + 0.5 - (by - flare_h)) / flare_h, 0, 1) ** 1.6
        half = r_base + flare * k
        fm = fl & (np.abs(art.X + 0.5 - bx) <= half)
        mask = mask | fm
        nx = np.where(fm, np.clip((art.X + 0.5 - bx) / (half + 0.01), -1, 1), nx)
    # lit as an upright cylinder: only the normal's x counts
    light = Art.diffuse(nx, np.zeros_like(nx))
    if strips:
        # fibrous bark (cedar, sequoia): long vertical strips
        idx, edge, rv = voronoi(art.w, art.h, plates[0], plates[1] * 3.0, seed, 0.9)
    else:
        idx, edge, rv = voronoi(art.w, art.h, plates[0], plates[1], seed, 1.0, 0.5)
    plate_v = 0.14 + 0.86 * light + (rv - 0.5) * plate_light
    art.put(mask, bark, plate_v)
    # each plate stands proud of the fissures: lit along its upper edge,
    # in shade along its lower one
    fis_edge = mask & (edge < fissure_w)
    below = np.zeros_like(fis_edge)
    below[:-1] = fis_edge[1:]
    above = np.zeros_like(fis_edge)
    above[1:] = fis_edge[:-1]
    art.shade(mask & below & ~fis_edge, -0.14)
    art.shade(mask & above & ~below & ~fis_edge, 0.08)
    art.put(fis_edge, fissure, 0.1 + 0.7 * light)
    return mask


# ------------------------------------------------------------------ limbs

def limb_path(x0: float, y0: float, length: float, azimuth: float, droop: float, upturn: float,
              steps: int = 6, wiggle: float = 0.0, rng: np.random.Generator | None = None, rise: float = 0.0) -> tuple[list[tuple[float, float]], float]:
    """A limb from the trunk at (x0, y0): [param azimuth] (radians, 0 = screen
    right, pi/2 = toward the viewer) sets which way it points in 3D, so a limb
    toward the viewer looks short. It starts [param droop] (radians below
    level) and bends up by [param upturn] toward the tip. Returns the
    projected points and the tip's depth."""
    pts = [(x0, y0)]
    x, y = x0, y0
    seg = length / steps
    cx, cz = math.cos(azimuth), math.sin(azimuth)
    for i in range(steps):
        t = (i + 0.5) / steps
        ang = -droop + (droop + upturn) * t * t + rise
        if rng is not None and wiggle:
            ang += (rng.random() - 0.5) * wiggle
        horiz = seg * math.cos(ang)
        x += horiz * cx
        # depth moves the limb a little down the screen (we look down on it)
        y -= seg * math.sin(ang)
        y += horiz * cz * 0.18
        pts.append((x, y))
    return pts, cz


def paint_limbs(art: Art, limbs: list[Limb], front: bool, mat: str = "limb", dead_mat: str = "deadlimb") -> None:
    for lb in limbs:
        if (lb.z >= 0) != front:
            continue
        m, info = art.polyline(lb.pts, lb.r0, lb.r1)
        light = Art.diffuse(info[1], info[2])
        v = 0.2 + 0.6 * light + 0.1 * lb.z
        art.put(m, dead_mat if lb.dead else mat, v)


# ------------------------------------------------------------------ foliage

def paint_tufts(art: Art, tufts: list[Tuft], crown: Crown, crown_k: float = 0.5, local_k: float = 0.42,
                base: float = 0.1, depth_k: float = 0.12, under_k: float = 0.0) -> None:
    """Paints the foliage clumps back to front. Each is lit by where it sits
    on the crown (crown_k) and by its own round surface (local_k)."""
    for tf in sorted(tufts, key=lambda t: t.z):
        m, nx, ny = art.blob(tf.x, tf.y, tf.r, tf.spikes, tf.spike, tf.seed, tf.squash)
        if not m.any():
            continue
        cnx = np.clip((art.X + 0.5 - crown.cx) / crown.rx, -1, 1)
        cny = np.clip((art.Y + 0.5 - crown.cy) / crown.ry, -1, 1)
        cnz = np.clip(np.sqrt(np.clip(1 - cnx * cnx - cny * cny, 0, 1)) * 0.7 + tf.z * 0.3, 0, 1)
        dc = Art.diffuse(cnx, cny, cnz)
        dl = Art.diffuse(nx, ny)
        v = base + crown_k * dc + local_k * (dl - 0.3) + depth_k * tf.z + tf.bright
        if under_k:
            # the underside of a clump is in its own shade
            v = v - under_k * np.clip(ny, 0, 1)
        art.put(m, tf.mat, v)
        art.up[m] = ny[m]


def snow_cover(art: Art, seed: int, amount: float = 0.55, mats: tuple[str, ...] = ("needle",)) -> None:
    """Winter: snow settles on the upper face of every clump of foliage, more
    on the lit, open top of the crown, in soft drifts rather than speckle."""
    ids = [art.m(m) for m in mats if m in art.names]
    fol = np.isin(art.mat, ids)
    drift = value_noise(art.w, art.h, 3.0, seed + 11)
    lying = fol & (art.up < -0.18 - 0.4 * (1 - amount)) & (drift < 0.35 + amount * 0.6)
    # it stays where the clump above doesn't shade it from the sky
    art.put(lying, "snow", np.clip(art.val + 0.25, 0.2, 1.0))


def tufts_along(pts: list[tuple[float, float]], z: float, rng: np.random.Generator, start: float, r: tuple[float, float],
                spacing: float, spread: float, mat: str = "needle", tip_cluster: int = 3, up: float = 0.6,
                spikes: int = 9, spike: float = 0.55, squash: float = 1.0) -> list[Tuft]:
    """Clumps along the outer part of a limb (from [param start] of its
    length to the tip), sitting a little above it, with a bigger cluster at
    the tip, where a pine carries its needles."""
    out: list[Tuft] = []
    lens = [math.dist(pts[i], pts[i + 1]) for i in range(len(pts) - 1)]
    total = sum(lens)
    if total <= 0:
        return out

    def at(s: float) -> tuple[float, float]:
        d = s * total
        for i, ln in enumerate(lens):
            if d <= ln or i == len(lens) - 1:
                f = 0 if ln == 0 else min(1.0, d / ln)
                return pts[i][0] + (pts[i + 1][0] - pts[i][0]) * f, pts[i][1] + (pts[i + 1][1] - pts[i][1]) * f
            d -= ln
        return pts[-1]

    s = start
    while s <= 1.0:
        x, y = at(s)
        rr = rng.uniform(*r) * (0.8 + 0.3 * s)
        out.append(Tuft(x + rng.normal() * spread, y - rr * up + rng.normal() * spread * 0.6, rr,
                        z + rng.normal() * 0.15, int(rng.integers(1 << 30)), mat, squash, spikes, spike))
        s += spacing / total * rng.uniform(0.7, 1.3)
    tx, ty = pts[-1]
    for _ in range(tip_cluster):
        rr = rng.uniform(*r) * 1.1
        out.append(Tuft(tx + rng.normal() * rr * 0.7, ty - rr * up * 0.8 + rng.normal() * rr * 0.5, rr,
                        z + 0.05 + rng.normal() * 0.1, int(rng.integers(1 << 30)), mat, squash, spikes, spike))
    return out


# ------------------------------------------------------------------ ramps

# Each ramp runs dark (deep shade, cool and blue) to light (full sun, warm).
RAMPS = {
    # Ponderosa: long yellow-green needles in brushy tufts.
    "ponderosa_needle": ["10221a", "17301f", "203f25", "2b4f2a", "395f2f", "4a7034", "5e823a", "769443", "90a64f", "aab964"],
    # Mature ponderosa: cinnamon-orange plates, the puzzle-piece bark.
    "ponderosa_bark": ["2e1812", "45231a", "602f20", "7c3e27", "984f2e", "b06338", "c27a44", "d29452", "e0ad68"],
    "ponderosa_fissure": ["140d0b", "21150f", "301e15", "40291c"],
    # A young ponderosa, a "blackjack": dark brown-black bark.
    "blackjack_bark": ["1a1411", "261d17", "352820", "45342a", "574335", "6c5442"],
    # Jeffrey pine: bluer needles, pinker plates.
    "jeffrey_needle": ["0f2020", "152c28", "1d3a30", "274a38", "335a40", "426a48", "547c53", "6b8f60", "86a370"],
    "jeffrey_bark": ["3a1c1a", "552822", "70362a", "8a4632", "a2583c", "b66c4a", "c8845c", "d89c70"],
    # Sugar pine: blue-green needles, grey-brown furrowed bark, purple cast.
    "sugar_needle": ["0f211f", "152d29", "1c3a33", "25493c", "305845", "3d684e", "4d7959", "618b66", "799f78"],
    "sugar_bark": ["231a1a", "332624", "45342f", "58443b", "6c5548", "806656", "957a66"],
    # Lodgepole: short yellow-green needles, thin orange-grey scaly bark.
    "lodgepole_needle": ["10241a", "173220", "204127", "2b512d", "386134", "48723b", "5b8443", "72974d", "8aa95a"],
    "lodgepole_bark": ["2c2018", "3f2f23", "54402f", "6a523d", "80654c", "967a5e", "aa8e72"],
    # Gray pine: sparse, long, grey-green needles you can see through.
    "gray_needle": ["1a2824", "243530", "30433b", "3d5246", "4b6152", "5c7160", "70826f", "869580", "9eaa94"],
    "gray_bark": ["1e1b19", "2c2724", "3c3530", "4e4540", "62574e", "766a5e"],
    # Whitebark pine: dark yellow-green, pale bark.
    "whitebark_needle": ["10221c", "172f22", "203d29", "2b4c30", "385c37", "476c3e", "597e47", "6e9052"],
    "whitebark_bark": ["3a3834", "524e48", "6b665e", "858076", "a09a8e", "bab4a6", "d0cbbd"],
    # White fir: silvery blue-green, the bluest tree on the Valley floor.
    "white_fir_needle": ["112220", "182d29", "213a33", "2b483c", "365646", "446551", "54755d", "67866b", "7d987d", "96aa92"],
    "white_fir_bark": ["24252a", "323339", "43444a", "56565b", "6a696c", "7e7c7c", "939089"],
    # Red fir: deep blue-green; furrowed red-purple bark.
    "red_fir_needle": ["0d1d1e", "132828", "193432", "21413c", "2a4f47", "355e52", "426d5e", "537d6b", "678f7c"],
    "red_fir_bark": ["271818", "3a2220", "4e2e29", "623b32", "77493b", "8c5847", "a06a56"],
    # Incense cedar: flat yellow-green sprays; cinnamon, fibrous bark.
    "cedar_spray": ["10221a", "17301e", "203f24", "2b4f29", "385f2e", "476f33", "588038", "6c913f", "84a24a", "9fb45a"],
    "cedar_bark": ["2c140f", "441e16", "5e2b1e", "773a27", "8e4b31", "a45e3c", "b8744b", "c98c5e"],
    "cedar_fissure": ["150a08", "22100c", "331812", "442118"],
    # Giant sequoia: blue-green scale foliage; bright cinnamon, deeply fluted bark.
    "sequoia_leaf": ["0e211e", "142d27", "1b3a30", "234839", "2d5742", "39664b", "477656", "588763", "6d9972", "86ab84"],
    "sequoia_bark": ["3e1a12", "5a2618", "76341f", "924427", "aa5630", "c0693b", "d28149", "e09a5c", "ebb476"],
    "sequoia_fissure": ["1c0b08", "2a110b", "3a1910", "4c2216"],
    # Limbs, live and dead.
    "limb": ["1d1511", "2b2019", "3b2c22", "4d3a2c", "604937"],
    "limb_red": ["2a1410", "3e1e16", "55291c", "6c3524", "84432d"],
    "deadlimb": ["2c2a28", "45413c", "625c54", "817a70", "a19a8e", "bdb6a8"],
    "snag": ["2a2724", "3e3a35", "56504a", "6f6860", "8a8278", "a69e92", "c0b9ab", "d6d0c2"],
    "snag_dark": ["151311", "211e1b", "2e2a26", "3c3732"],
    "char": ["0f0c0b", "1a1514", "261f1d", "332a27"],
    "cut_wood": ["7a4a2e", "9c6a44", "bd8c60", "d8aa7c", "e8c49a"],
    "tunnel_light": ["8ea492", "b4c6b2", "d2ddcc", "e8eee2"],
    "tunnel_grass": ["4a6a30", "62833a", "7a9a46", "94b058"],
    "root_soil": ["1f1510", "33241a", "4a3726", "624b36", "7a6048", "927a5e"],
    "cone": ["2a1a10", "45291a", "603a22", "7c4d2c", "966238"],
    "snow": ["7c8ea6", "9aaec4", "bccbdb", "dbe5ee", "f2f6f8"],
}


def ramps(*names: str, **alias: str) -> dict[str, list[str]]:
    out = {n: RAMPS[n] for n in names}
    for k, v in alias.items():
        out[k] = RAMPS[v]
    return out
