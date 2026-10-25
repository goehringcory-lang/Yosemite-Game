"""The conifers, built the way each one grows.

- pine(): a trunk with limbs spiralling up it and needles in brushy tufts out
  along the limbs (ponderosa, Jeffrey, sugar pine, lodgepole, gray pine).
- fir(): stiff whorls of level limbs carrying flat, layered sprays, up to a
  spire (white fir, red fir).
- cedar(): a buttressed, fibrous trunk under a dense cone of drooping, lacy
  sprays (incense cedar).
- sequoia(): a fluted cinnamon column with a fire scar, crooked limbs and
  rounded clumps of blue-green scale leaves high up (giant sequoia).
- snag(): a dead tree, silver, its top broken off.
"""
from __future__ import annotations

import math

import numpy as np

from conifers import (Crown, Limb, Tuft, limb_path, paint_limbs, paint_tufts, ramps, snow_cover, trunk,
                      tufts_along)
from kit import FOOT, Art, value_noise


def _envelope(pts: list[tuple[float, float]], t: float) -> float:
    """Piecewise-linear crown half-width at t (0 crown bottom .. 1 top)."""
    for (t0, w0), (t1, w1) in zip(pts, pts[1:]):
        if t0 <= t <= t1:
            return w0 + (w1 - w0) * (t - t0) / max(1e-6, t1 - t0)
    return pts[-1][1]


def _trunk_line(bx: float, by: float, top: float, lean: float, seed: int, wander: float = 0.5, n: int = 8):
    pts = []
    for i in range(n + 1):
        f = i / n
        y = by - (by - top) * f
        pts.append((bx + lean * f * f + math.sin(f * 5.0 + seed) * wander * f, y))

    def x_at(y: float) -> float:
        f = (by - y) / max(1e-6, by - top)
        return bx + lean * f * f + math.sin(f * 5.0 + seed) * wander * f
    return pts, x_at


def _flat_bottom(art: Art, by: float) -> None:
    art.mat[int(by) + 1:, :] = -1


def _fit(tufts: list[Tuft], limbs: list[Limb], W: int, axis_x, top_margin: float = 2.0, side_margin: float = 2.0) -> None:
    """Keeps the crown inside the canvas (with room for the outline): squeezes
    it toward the trunk if it would spill over a side, and lowers the clumps
    that would poke out of the top."""
    reach = 0.0
    for tf in tufts:
        ext = tf.r * (1.0 + 0.65 * tf.spike) + 0.5
        reach = max(reach, abs(tf.x - axis_x(tf.y)) + ext - (W / 2.0 - side_margin))
    for lb in limbs:
        for x, y in lb.pts:
            reach = max(reach, abs(x - axis_x(y)) + lb.r0 - (W / 2.0 - side_margin))
    if reach > 0:
        half = W / 2.0 - side_margin
        k = (half - reach * 0.0) / (half + reach)
        for tf in tufts:
            ax = axis_x(tf.y)
            tf.x = ax + (tf.x - ax) * k
            tf.r = min(tf.r, max(1.0, (half - abs(tf.x - ax)) / (1.0 + 0.65 * tf.spike)))
        for lb in limbs:
            lb.pts = [(axis_x(y) + (x - axis_x(y)) * k, y) for x, y in lb.pts]
    for tf in tufts:
        ext = tf.r * (1.0 + 0.65 * tf.spike * tf.squash)
        if tf.y - ext < top_margin:
            tf.y = top_margin + ext


# ------------------------------------------------------------------ pines

def pine(W: int, H: int, seed: int, *, needle: str, bark: str, fissure: str, top: float, crown_bottom: float,
         env: list[tuple[float, float]], r_base: float, r_top: float, lean: float = 0.0, spacing: float = 4.5,
         tuft_r: tuple[float, float] = (2.2, 3.6), tuft_spacing: float = 2.6, droop: tuple[float, float] = (0.45, 0.05),
         upturn: tuple[float, float] = (0.9, 0.5), rise: tuple[float, float] = (0.0, 0.35), stubs: int = 4,
         tip_cluster: int = 3, plates: tuple[float, float] = (3.0, 6.0), crown_k: float = 0.52, local_k: float = 0.42,
         flare: float = 1.4, spikes: int = 13, spike: float = 0.9, top_tufts: int = 4, limb: str = "limb",
         start: float = 0.35, cones: int = 0, flat_top: float = 0.0, fissure_w: float = 0.32, base_light: float = 0.2,
         strips: bool = False, plate_light: float = 0.24, side_bias: float = 0.0, long_limbs: int = 0,
         hang_cones: int = 0, limb_r: float = 1.25, fork: float = 0.0, see_through: float = 0.0,
         season: str = "summer") -> Art:
    rmp = ramps(needle=needle, bark=bark, fissure=fissure, limb=limb, deadlimb="deadlimb", cone="cone", snow="snow")
    art = Art(W, H, rmp, seed)
    art.dither["needle"] = 0.28
    rng = np.random.default_rng(seed)
    bx, by = W / 2.0, H - FOOT
    pts, trunk_x = _trunk_line(bx, by, top, lean, seed)
    limbs: list[Limb] = []
    tufts: list[Tuft] = []
    y = crown_bottom
    az = rng.random() * 6.283
    crown_h = crown_bottom - top
    n_limb = 0
    while y > top + 3:
        t = (crown_bottom - y) / crown_h
        width = _envelope(env, t) * rng.uniform(0.82, 1.12)
        az += 2.4 + rng.normal() * 0.35  # near the golden angle: limbs spiral round
        cosz = math.cos(az)
        if side_bias:
            # a crown swept to one side (wind, or the sugar pine's long limbs)
            width *= 1.0 + side_bias * cosz
        length = width / max(0.35, abs(cosz)) if abs(cosz) > 0.35 else width * rng.uniform(0.5, 0.9)
        length = min(length, width * 1.5)
        d = droop[0] + (droop[1] - droop[0]) * t
        u = upturn[0] + (upturn[1] - upturn[0]) * t
        rs = rise[0] + (rise[1] - rise[0]) * t
        lp, z = limb_path(trunk_x(y), y, length, az, d, u, 6, 0.25, rng, rs)
        thick = limb_r - 0.55 * t
        limbs.append(Limb(lp, z, thick, 0.45))
        if rng.random() >= see_through:
            tufts += tufts_along(lp, z, rng, start, tuft_r, tuft_spacing, 0.6, "needle", tip_cluster, 0.5, spikes, spike)
        else:
            tufts += tufts_along(lp, z, rng, 0.85, tuft_r, tuft_spacing * 2, 0.5, "needle", 1, 0.5, spikes, spike)
        n_limb += 1
        y -= spacing * rng.uniform(0.7, 1.3)
    for _ in range(long_limbs):
        # a few long, level limbs reaching far out: the sugar pine's arms
        ly = crown_bottom - crown_h * rng.uniform(0.15, 0.75)
        side = 1 if rng.random() < 0.5 + side_bias * 0.5 else -1
        laz = (0.0 if side > 0 else math.pi) + rng.normal() * 0.25
        lp, z = limb_path(trunk_x(ly), ly, W * 0.46 * rng.uniform(0.85, 1.0), laz, 0.12, 0.25, 8, 0.15, rng)
        limbs.append(Limb(lp, z, limb_r + 0.15, 0.55))
        tufts += tufts_along(lp, z, rng, 0.55, tuft_r, tuft_spacing * 1.2, 0.5, "needle", tip_cluster + 1, 0.55, spikes, spike)
        for _ in range(hang_cones):
            cx, cy = lp[-1][0] + rng.normal() * 1.5, lp[-1][1] + 2.5
            tufts.append(Tuft(cx, cy, 0.0, z + 0.3, 0, "cone"))
    # the leader: a cluster at the top
    for i in range(top_tufts):
        rr = rng.uniform(*tuft_r)
        tufts.append(Tuft(trunk_x(top + 2) + rng.normal() * 2.2, top + 2 + i * 2.2 + rng.normal(), rr, rng.normal() * 0.3,
                          int(rng.integers(1 << 30)), "needle", 1.0, spikes, spike))
    # dead stubs low on the trunk, where the tree has pruned itself
    for _ in range(stubs):
        sy = crown_bottom + (by - 14 - crown_bottom) * rng.random()
        lp, z = limb_path(trunk_x(sy), sy, rng.uniform(2.0, 3.5), rng.random() * 6.283, 0.4, 0.1, 2)
        limbs.append(Limb(lp, z, 0.6, 0.35, dead=True))
    if flat_top > 0:
        # an old tree's crown: flattened, the top tufts pulled level
        for tf in tufts:
            if tf.y < top + 10:
                tf.y = top + 6 + (tf.y - top - 6) * (1 - flat_top)
    cone_at = []
    real = [tf for tf in tufts if tf.mat == "needle"]
    for _ in range(cones):
        tf = real[int(rng.integers(len(real)))]
        cone_at.append((tf.x + rng.normal(), tf.y + tf.r * 0.6))
    hung = [tf for tf in tufts if tf.mat == "cone"]
    tufts = real
    _fit(tufts, limbs, W, trunk_x)
    crown = Crown(trunk_x((crown_bottom + top) / 2), (crown_bottom + top) / 2 - crown_h * 0.08,
                  max(e[1] for e in env) * 1.05, crown_h * 0.62)
    back = [tf for tf in tufts if tf.z < -0.05]
    front = [tf for tf in tufts if tf.z >= -0.05]
    paint_tufts(art, back, crown, crown_k, local_k, base_light - 0.08)
    paint_limbs(art, limbs, False)
    if fork > 0:
        # a trunk that forks (gray pine): a second stem from partway up
        fy = by - (by - top) * fork
        fpts, _ = _trunk_line(trunk_x(fy), fy, top + 6, -lean * 1.6 - 5, seed + 3)
        trunk(art, fpts, r_base * 0.62, r_top, "bark", "fissure", plates, 0.0, 1.0, seed + 5, plate_light=plate_light,
              fissure_w=fissure_w, strips=strips)
    trunk(art, pts, r_base, r_top, "bark", "fissure", plates, flare, 5.0, seed, plate_light=plate_light,
          fissure_w=fissure_w, strips=strips)
    paint_limbs(art, limbs, True)
    paint_tufts(art, front, crown, crown_k, local_k, base_light)
    for cx, cy in cone_at:
        m = art.ellipse(cx, cy, 0.9, 1.6)
        art.put(m & (art.mat >= 0), "cone", 0.5)
    for tf in hung:
        # a long cone hanging from a limb tip
        m, info = art.capsule(tf.x, tf.y - 1.5, tf.x + 0.3, tf.y + 3.5, 1.0, 0.8)
        art.put(m, "cone", 0.3 + 0.5 * Art.diffuse(info[1], info[2]))
    if season == "winter":
        snow_cover(art, seed)
    _flat_bottom(art, by)
    return art


def ponderosa(W: int, H: int, variant: str, season: str = "summer") -> Art:
    """Pinus ponderosa, the Valley floor's tree. a: an old-growth tree, bare
    trunk of cinnamon plates up to a broad, open, flat-topped crown of brushy
    needle tufts; b: a mature tree, the crown rounder; c: a young "blackjack",
    dark-barked, its crown still a narrow cone reaching low."""
    if variant == "a":
        return pine(W, H, 4101, needle="ponderosa_needle", bark="ponderosa_bark", fissure="ponderosa_fissure",
                    top=5, crown_bottom=66, env=[(0, 17), (0.25, 24), (0.55, 26), (0.8, 22), (1.0, 12)],
                    r_base=3.7, r_top=1.1, lean=-1.5, spacing=3.9, tuft_r=(2.4, 3.9), flat_top=0.5, stubs=3,
                    droop=(0.55, 0.1), upturn=(1.0, 0.6), cones=5, plates=(4.5, 9.0), season=season)
    if variant == "b":
        return pine(W, H, 4202, needle="ponderosa_needle", bark="ponderosa_bark", fissure="ponderosa_fissure",
                    top=6, crown_bottom=72, env=[(0, 20), (0.3, 24), (0.6, 21), (0.85, 14), (1.0, 6)],
                    r_base=3.5, r_top=1.0, lean=1.0, spacing=3.8, tuft_r=(2.3, 3.7), stubs=2,
                    droop=(0.5, 0.05), upturn=(0.95, 0.55), cones=4, plates=(4.0, 8.0), season=season)
    return pine(W, H, 4303, needle="ponderosa_needle", bark="blackjack_bark", fissure="ponderosa_fissure",
                top=12, crown_bottom=92, env=[(0, 19), (0.3, 18), (0.6, 13), (0.85, 8), (1.0, 3)],
                r_base=2.9, r_top=0.9, lean=0.5, spacing=3.4, tuft_r=(2.0, 3.3), stubs=2,
                droop=(0.35, 0.0), upturn=(0.7, 0.5), rise=(0.0, 0.3), plates=(2.0, 3.0), fissure_w=0.4, season=season)


def jeffrey(W: int, H: int, variant: str) -> Art:
    """Pinus jeffreyi on the rim at Glacier Point: the ponderosa's mountain
    cousin, bluer in the needle and pinker in the bark, its crown more
    compact and swept by the wind."""
    if variant == "a":
        return pine(W, H, 5101, needle="jeffrey_needle", bark="jeffrey_bark", fissure="ponderosa_fissure",
                    top=4, crown_bottom=40, env=[(0, 12), (0.35, 15), (0.7, 13), (1.0, 6)], r_base=2.8, r_top=0.9,
                    lean=-1.0, spacing=3.2, tuft_r=(1.9, 3.0), stubs=1, droop=(0.45, 0.1), upturn=(0.9, 0.5),
                    cones=3, plates=(3.0, 6.0), flat_top=0.3, side_bias=0.2)
    return pine(W, H, 5202, needle="jeffrey_needle", bark="jeffrey_bark", fissure="ponderosa_fissure",
                top=5, crown_bottom=36, env=[(0, 11), (0.4, 13), (0.75, 10), (1.0, 4)], r_base=2.5, r_top=0.8,
                lean=1.2, spacing=3.0, tuft_r=(1.8, 2.8), stubs=1, droop=(0.4, 0.05), upturn=(0.85, 0.5),
                cones=2, plates=(2.6, 5.0), side_bias=-0.25)


def sugar_pine(W: int, H: int, variant: str) -> Art:
    """Pinus lambertiana, the tallest pine: a straight column of grey-purple
    plated bark, a few great level limbs reaching far out, one side longer
    than the other, with the foot-long cones hanging from their tips."""
    if variant == "a":
        return pine(W, H, 6101, needle="sugar_needle", bark="sugar_bark", fissure="ponderosa_fissure",
                    top=4, crown_bottom=82, env=[(0, 18), (0.3, 22), (0.6, 22), (0.85, 18), (1.0, 10)],
                    r_base=4.1, r_top=1.2, lean=0.5, spacing=5.2, tuft_r=(2.2, 3.4), stubs=3,
                    droop=(0.2, 0.05), upturn=(0.45, 0.35), rise=(0.0, 0.1), plates=(3.0, 9.0), long_limbs=3,
                    hang_cones=2, side_bias=0.35, flat_top=0.6, limb_r=1.5, fissure_w=0.4)
    return pine(W, H, 6202, needle="sugar_needle", bark="sugar_bark", fissure="ponderosa_fissure",
                top=6, crown_bottom=90, env=[(0, 20), (0.3, 21), (0.6, 19), (0.85, 14), (1.0, 7)],
                r_base=3.8, r_top=1.1, lean=-0.8, spacing=5.0, tuft_r=(2.1, 3.3), stubs=3,
                droop=(0.25, 0.05), upturn=(0.5, 0.35), rise=(0.0, 0.1), plates=(3.0, 9.0), long_limbs=2,
                hang_cones=2, side_bias=-0.3, limb_r=1.45, fissure_w=0.4)


def lodgepole(W: int, H: int, variant: str) -> Art:
    """Pinus contorta var. murrayana, round Tuolumne Meadows: ruler-straight
    and slender, thin scaly bark, dead twig stubs low down, and a narrow,
    ragged crown of short limbs tipped with yellow-green needle tufts."""
    spec = {
        # an old tree: tall, the crown in its upper half
        "a": dict(seed=7101, top=3, crown_bottom=62, env=[(0, 9), (0.4, 11), (0.75, 9), (1.0, 4)], r_base=2.4,
                  stubs=7, spacing=3.0),
        # a mature tree
        "b": dict(seed=7202, top=4, crown_bottom=60, env=[(0, 10), (0.4, 10), (0.8, 7), (1.0, 3)], r_base=2.2,
                  stubs=5, spacing=2.8),
        # a young tree, limbs nearly to the ground
        "c": dict(seed=7303, top=4, crown_bottom=66, env=[(0, 10), (0.3, 9), (0.7, 6), (1.0, 2.5)], r_base=1.8,
                  stubs=1, spacing=2.4),
        # a tall, thin tree from a crowded stand
        "d": dict(seed=7404, top=3, crown_bottom=58, env=[(0, 6), (0.4, 7), (0.8, 6), (1.0, 3)], r_base=1.8,
                  stubs=9, spacing=3.2),
        # Glacier Point's
        "gp": dict(seed=7505, top=3, crown_bottom=40, env=[(0, 7), (0.4, 7.5), (0.8, 5.5), (1.0, 2.5)], r_base=1.6,
                   stubs=4, spacing=2.6),
    }[variant]
    return pine(W, H, spec["seed"], needle="lodgepole_needle", bark="lodgepole_bark", fissure="ponderosa_fissure",
                top=spec["top"], crown_bottom=spec["crown_bottom"], env=spec["env"], r_base=spec["r_base"],
                r_top=0.7, lean=0.3, spacing=spec["spacing"], tuft_r=(1.5, 2.4), stubs=spec["stubs"],
                droop=(0.3, 0.0), upturn=(0.6, 0.6), rise=(0.1, 0.35), plates=(2.2, 3.2), fissure_w=0.18,
                tip_cluster=2, start=0.45, flare=0.8, limb_r=0.9, plate_light=0.3)


def gray_pine(W: int, H: int, variant: str) -> Art:
    """Pinus sabiniana in El Portal's foothills: a leaning, often forked trunk
    of dark bark and a thin, wispy crown of long grey-green needles that the
    sky shows through, with heavy cones."""
    if variant == "a":
        return pine(W, H, 8101, needle="gray_needle", bark="gray_bark", fissure="ponderosa_fissure",
                    top=4, crown_bottom=62, env=[(0, 16), (0.4, 20), (0.75, 17), (1.0, 8)], r_base=2.5, r_top=0.8,
                    lean=7.0, spacing=4.6, tuft_r=(1.8, 2.8), stubs=2, droop=(0.5, 0.2), upturn=(0.9, 0.6),
                    plates=(2.0, 4.0), fissure_w=0.45, cones=4, see_through=0.45, fork=0.45, spike=1.1,
                    tuft_spacing=3.4, crown_k=0.4, local_k=0.5)
    return pine(W, H, 8202, needle="gray_needle", bark="gray_bark", fissure="ponderosa_fissure",
                top=5, crown_bottom=58, env=[(0, 15), (0.4, 19), (0.75, 16), (1.0, 7)], r_base=2.4, r_top=0.8,
                lean=-6.0, spacing=4.4, tuft_r=(1.8, 2.8), stubs=2, droop=(0.5, 0.2), upturn=(0.9, 0.6),
                plates=(2.0, 4.0), fissure_w=0.45, cones=3, see_through=0.4, spike=1.1, tuft_spacing=3.4,
                crown_k=0.4, local_k=0.5)


# ------------------------------------------------------------------ firs

def fir(W: int, H: int, seed: int, *, needle: str, bark: str, top: float, crown_bottom: float,
        env: list[tuple[float, float]], r_base: float, whorl: float = 4.0, per_whorl: int = 5,
        tuft_r: tuple[float, float] = (1.8, 2.8), droop: float = 0.25, stubs: int = 2, plates=(2.0, 4.0),
        fissure_w: float = 0.35, spire: int = 5, base_light: float = 0.18, season: str = "summer") -> Art:
    rmp = ramps(needle=needle, bark=bark, fissure="ponderosa_fissure", limb="limb", deadlimb="deadlimb", cone="cone",
                snow="snow")
    art = Art(W, H, rmp, seed)
    art.dither["needle"] = 0.26
    rng = np.random.default_rng(seed)
    bx, by = W / 2.0, H - FOOT
    pts, trunk_x = _trunk_line(bx, by, top, 0.0, seed, 0.25)
    limbs: list[Limb] = []
    tufts: list[Tuft] = []
    crown_h = crown_bottom - top
    y = crown_bottom
    az0 = rng.random() * 6.283
    while y > top + spire:
        t = (crown_bottom - y) / crown_h
        width = _envelope(env, t)
        az0 += 0.7
        for k in range(per_whorl):
            az = az0 + k * 6.283 / per_whorl + rng.normal() * 0.2
            cosz = math.cos(az)
            length = width * rng.uniform(0.85, 1.05) / max(0.4, abs(cosz)) if abs(cosz) > 0.4 else width * 0.6
            length = min(length, width * 1.4)
            # level limbs, the lower ones drooping at the tips
            lp, z = limb_path(trunk_x(y), y, length, az, 0.05 + droop * (1 - t), -droop * (1 - t) * 0.6, 5, 0.1, rng)
            limbs.append(Limb(lp, z, 0.9 - 0.4 * t, 0.4))
            # flat sprays lying along the top of the limb, layered
            tufts += tufts_along(lp, z, rng, 0.12, tuft_r, 1.9, 0.35, "needle", 2, 0.3, 11, 0.55, 0.62)
        y -= whorl * rng.uniform(0.85, 1.15)
    # the spire
    for i in range(spire + 2):
        yy = top + i * 1.2
        rr = 0.9 + i * 0.28
        tufts.append(Tuft(trunk_x(yy) + rng.normal() * 0.3, yy + 1, rr, 0.2, int(rng.integers(1 << 30)), "needle",
                          0.8, 9, 0.4))
    for _ in range(stubs):
        sy = crown_bottom + (by - 10 - crown_bottom) * rng.random()
        lp, z = limb_path(trunk_x(sy), sy, rng.uniform(1.5, 3.0), rng.random() * 6.283, 0.3, 0.0, 2)
        limbs.append(Limb(lp, z, 0.5, 0.3, dead=True))
    _fit(tufts, limbs, W, trunk_x)
    crown = Crown(trunk_x((crown_bottom + top) / 2), (crown_bottom + top) / 2, max(e[1] for e in env) * 1.1, crown_h * 0.6)
    back = [tf for tf in tufts if tf.z < -0.05]
    front = [tf for tf in tufts if tf.z >= -0.05]
    paint_tufts(art, back, crown, 0.55, 0.34, base_light - 0.1, under_k=0.28)
    paint_limbs(art, limbs, False)
    trunk(art, pts, r_base, 0.7, "bark", "fissure", plates, 1.0, 4.0, seed, plate_light=0.2, fissure_w=fissure_w)
    paint_limbs(art, limbs, True)
    paint_tufts(art, front, crown, 0.55, 0.34, base_light, under_k=0.28)
    if season == "winter":
        snow_cover(art, seed, 0.7)
    _flat_bottom(art, by)
    return art


def white_fir(W: int, H: int, variant: str = "a", season: str = "summer") -> Art:
    """Abies concolor: the Valley's silvery blue-green fir, a dense, even cone
    of level whorls over smooth grey bark."""
    return fir(W, H, 9101, needle="white_fir_needle", bark="white_fir_bark", top=3, crown_bottom=92,
               env=[(0, 15), (0.25, 14), (0.55, 10.5), (0.8, 6.5), (1.0, 2)], r_base=2.6, whorl=3.6, per_whorl=5,
               stubs=1, season=season)


def red_fir(W: int, H: int, variant: str) -> Art:
    """Abies magnifica on the rim at Glacier Point: deep blue-green, a narrow
    spire of short level limbs over furrowed, red-purple bark."""
    if variant == "a":
        return fir(W, H, 9202, needle="red_fir_needle", bark="red_fir_bark", top=2, crown_bottom=52,
                   env=[(0, 12), (0.3, 11), (0.6, 8), (0.85, 5), (1.0, 1.6)], r_base=2.3, whorl=3.0, per_whorl=5,
                   tuft_r=(1.5, 2.4), stubs=2, plates=(2.0, 4.5), fissure_w=0.45)
    return fir(W, H, 9303, needle="red_fir_needle", bark="red_fir_bark", top=2, crown_bottom=44,
               env=[(0, 10.5), (0.3, 10), (0.6, 7), (0.85, 4.5), (1.0, 1.5)], r_base=2.1, whorl=2.8, per_whorl=5,
               tuft_r=(1.4, 2.3), stubs=2, plates=(2.0, 4.5), fissure_w=0.45)


# ------------------------------------------------------------------ cedar

def incense_cedar(W: int, H: int, variant: str, season: str = "summer") -> Art:
    """Calocedrus decurrens, everywhere on the Valley floor: a trunk of
    cinnamon-red, fibrous bark, strongly tapered from a flared, buttressed
    foot, under a dense cone of flat, lacy sprays that droop from the limbs
    and turn up at the tips. a: an old tree, the trunk bare to a third of its
    height; b: a younger one, sprays almost to the ground."""
    seed = 3101 if variant == "a" else 3202
    rmp = ramps(needle="cedar_spray", bark="cedar_bark", fissure="cedar_fissure", limb="limb_red", deadlimb="deadlimb",
                cone="cone", snow="snow")
    art = Art(W, H, rmp, seed)
    art.dither["needle"] = 0.26
    rng = np.random.default_rng(seed)
    bx, by = W / 2.0, H - FOOT
    top = 3 if variant == "a" else 6
    crown_bottom = 72 if variant == "a" else 92
    env = [(0, 16), (0.2, 17), (0.5, 13.5), (0.78, 9), (1.0, 3)] if variant == "a" else \
        [(0, 15), (0.25, 15), (0.55, 11.5), (0.8, 7), (1.0, 2.5)]
    pts, trunk_x = _trunk_line(bx, by, top, 0.6 if variant == "a" else -0.4, seed, 0.4)
    limbs: list[Limb] = []
    tufts: list[Tuft] = []
    crown_h = crown_bottom - top
    y = crown_bottom
    az = rng.random() * 6.283
    while y > top + 3:
        t = (crown_bottom - y) / crown_h
        width = _envelope(env, t) * rng.uniform(0.85, 1.1)
        az += 2.4 + rng.normal() * 0.3
        cosz = math.cos(az)
        length = width / max(0.4, abs(cosz)) if abs(cosz) > 0.4 else width * rng.uniform(0.45, 0.8)
        length = min(length, width * 1.35)
        # limbs droop out from the trunk, then sweep up at the tips
        lp, z = limb_path(trunk_x(y), y, length, az, 0.55 - 0.3 * t, 0.85 - 0.2 * t, 5, 0.2, rng)
        limbs.append(Limb(lp, z, 1.0 - 0.45 * t, 0.4))
        # sprays hang below and along the limb: flattened, lacy, taller than wide
        tufts += tufts_along(lp, z, rng, 0.15, (1.9, 3.0), 1.8, 0.55, "needle", 2, -0.1, 6, 0.38, 0.72)
        y -= 2.6 * rng.uniform(0.75, 1.25)
    for i in range(4):
        yy = top + i * 1.6
        tufts.append(Tuft(trunk_x(yy) + rng.normal() * 0.5, yy + 1.5, 1.2 + i * 0.4, 0.1, int(rng.integers(1 << 30)),
                          "needle", 1.2, 8, 0.45))
    _fit(tufts, limbs, W, trunk_x)
    crown = Crown(trunk_x((crown_bottom + top) / 2) - 1, (crown_bottom + top) / 2, 17, crown_h * 0.6)
    back = [tf for tf in tufts if tf.z < -0.05]
    front = [tf for tf in tufts if tf.z >= -0.05]
    paint_tufts(art, back, crown, 0.56, 0.34, 0.1, under_k=0.26)
    paint_limbs(art, limbs, False, "limb")
    # the strongly tapered, fibrous trunk with its buttressed foot
    trunk(art, pts, 3.3 if variant == "a" else 2.8, 0.7, "bark", "fissure", (1.6, 5.0), 2.4, 9.0, seed,
          plate_light=0.18, fissure_w=0.42, strips=True)
    paint_limbs(art, limbs, True, "limb")
    paint_tufts(art, front, crown, 0.56, 0.34, 0.2, under_k=0.26)
    if season == "winter":
        snow_cover(art, seed, 0.6)
    _flat_bottom(art, by)
    return art


# ------------------------------------------------------------------ sequoia

def sequoia(W: int, H: int, variant: str) -> Art:
    """Sequoiadendron giganteum in the Mariposa Grove: a vast, fluted column
    of bright cinnamon bark flaring into buttresses at the ground, with a
    black fire scar at its foot, bare for half its height, then great crooked
    limbs that bend upward, carrying rounded, cottony clumps of blue-green
    scale leaves; the old trees' tops dead or broken."""
    seed = {"a": 2101, "b": 2202, "c": 2303}[variant]
    return giant(W, H, seed, r_base=W * 0.15, scars=[(0.35 if variant != "b" else -0.4, 0.16 if variant == "a" else 0.1, 0.38)],
                 spike_top=variant == "a")


def grizzly_giant(W: int, H: int) -> Art:
    """The Grizzly Giant, the Mariposa Grove's oldest: a squat, battered
    column leaning off true, its dead top broken short, fire scars deep in its
    foot, and the famous limb, thicker than most trees, thrust out from high
    on its side and bent up like an elbow."""
    return giant(W, H, 1858, r_base=W * 0.15, lean=-20.0, crown_frac=0.4, crown_w=0.3, spike_top=True,
                 scars=[(0.4, 0.2, 0.36), (-0.45, 0.13, 0.26)], elbow=(0.5, 1.0, 0.34), top_pad=16, limb_gap=7.0)


def tunnel_tree(W: int, H: int) -> Art:
    """The California Tunnel Tree: a living sequoia with a tunnel cut through
    its foot in 1895 for the stages, the daylight showing through. The arch is
    where the old one was, so you walk through it as before."""
    return giant(W, H, 1895, r_base=17.0, lean=-2.0, crown_frac=0.5, crown_w=0.46, scars=[], tunnel=(18.0, 22.0))


def giant(W: int, H: int, seed: int, *, r_base: float, lean: float | None = None, crown_frac: float = 0.5,
          crown_w: float = 0.42, scars: list[tuple[float, float, float]] = (), spike_top: bool = False,
          elbow: tuple[float, float, float] | None = None, tunnel: tuple[float, float] | None = None,
          top_pad: float = 10, limb_gap: float = 4.6) -> Art:
    rmp = ramps(needle="sequoia_leaf", bark="sequoia_bark", fissure="sequoia_fissure", limb="limb_red",
                deadlimb="deadlimb", cone="cone", char="char", cut="cut_wood", sky="tunnel_light", grass="tunnel_grass")
    art = Art(W, H, rmp, seed)
    art.dither["needle"] = 0.26
    art.dither["bark"] = 0.3
    rng = np.random.default_rng(seed)
    bx, by = W / 2.0, H - FOOT
    top = 4
    crown_bottom = H * crown_frac
    pts, trunk_x = _trunk_line(bx, by, top + top_pad, rng.normal() * 2 if lean is None else lean, seed, 0.6)
    limbs: list[Limb] = []
    tufts: list[Tuft] = []
    crown_h = crown_bottom - top
    env = [(0, W * crown_w * 0.72), (0.3, W * crown_w), (0.65, W * crown_w * 0.95), (0.9, W * crown_w * 0.6),
           (1.0, W * crown_w * 0.3)]
    y = crown_bottom
    az = rng.random() * 6.283
    while y > top + 8:
        t = (crown_bottom - y) / crown_h
        width = _envelope(env, t) * rng.uniform(0.8, 1.1)
        az += 2.4 + rng.normal() * 0.4
        cosz = math.cos(az)
        length = width / max(0.45, abs(cosz)) if abs(cosz) > 0.45 else width * rng.uniform(0.4, 0.7)
        length = min(length, width * 1.3)
        # big limbs: out level or a little down, then an elbow up
        lp, z = limb_path(trunk_x(y), y, length, az, 0.25, 1.1, 6, 0.4, rng)
        limbs.append(Limb(lp, z, 2.4 - 1.0 * t, 0.9))
        # the foliage: rounded, cottony clumps over the outer limb
        tufts += tufts_along(lp, z, rng, 0.25, (3.6, 5.8), 2.6, 1.1, "needle", 4, 0.8, 16, 0.42)
        y -= limb_gap * rng.uniform(0.75, 1.25)
    if elbow:
        # one great limb: out level from high on the trunk, then bent sharply up
        f, side, thick = elbow
        ey = by - (by - top) * f
        ex = trunk_x(ey)
        reach = W * 0.34
        lp = [(ex, ey), (ex + side * reach * 0.4, ey - 7), (ex + side * reach * 0.75, ey - 15),
              (ex + side * reach * 0.92, ey - 27), (ex + side * reach * 0.95, ey - 42)]
        limbs.append(Limb(lp, 0.4, r_base * thick, r_base * thick * 0.6))
        for _ in range(11):
            s = rng.uniform(0.55, 1.0)
            i = min(len(lp) - 2, int(s * (len(lp) - 1)))
            f2 = s * (len(lp) - 1) - i
            tx = lp[i][0] + (lp[i + 1][0] - lp[i][0]) * f2 + rng.normal() * 5
            ty = lp[i][1] + (lp[i + 1][1] - lp[i][1]) * f2 - 4 + rng.normal() * 4
            tufts.append(Tuft(tx, ty, rng.uniform(3.6, 5.4), 0.55 + rng.random() * 0.3, int(rng.integers(1 << 30)), "needle",
                              1.0, 16, 0.42))
    # clumps close round the upper trunk, so it vanishes into the crown
    for _ in range(int(W * 0.12)):
        yy = top + 8 + (crown_bottom - top - 14) * rng.random() ** 1.3
        rr = rng.uniform(3.4, 5.4)
        tufts.append(Tuft(trunk_x(yy) + rng.normal() * W * 0.08, yy, rr, rng.uniform(0.0, 0.6),
                          int(rng.integers(1 << 30)), "needle", 1.0, 16, 0.42))
    if spike_top:
        # a dead spike top above the living crown
        limbs.append(Limb([(trunk_x(top + 12), top + 14), (trunk_x(top + 12) + 1, top)], 0.5, 1.8, 0.5, dead=True))
    else:
        for _ in range(3):
            rr = rng.uniform(3.0, 4.5)
            tufts.append(Tuft(trunk_x(top + 10) + rng.normal() * 4, top + 9 + rng.random() * 5, rr, rng.normal() * 0.3,
                              int(rng.integers(1 << 30)), "needle", 1.0, 16, 0.45))
    if spike_top:
        # the living crown stops short of the dead top, raggedly
        kept = []
        for tf in tufts:
            if tf.y < top + 16:
                if rng.random() < 0.55:
                    continue
                tf.y = top + 16 + rng.uniform(-3, 4)
            kept.append(tf)
        tufts = kept
    _fit(tufts, limbs, W, trunk_x)
    crown = Crown(trunk_x((crown_bottom + top) / 2), (crown_bottom + top) / 2, W * crown_w * 1.05, crown_h * 0.6)
    back = [tf for tf in tufts if tf.z < -0.05]
    front = [tf for tf in tufts if tf.z >= -0.05]
    paint_tufts(art, back, crown, 0.56, 0.38, 0.06, under_k=0.12)
    paint_limbs(art, [lb for lb in limbs if not (elbow and lb is limbs[-1 if not spike_top else -2])], False)
    # the trunk: a fluted column, its ridges lit in turn
    mask, info = art.polyline(pts, r_base, r_base * 0.3)
    fl = (art.Y + 0.5 > by - 22) & (art.Y < by + 1)
    k = np.clip((art.Y + 0.5 - (by - 22)) / 22, 0, 1) ** 2.2
    half = r_base + r_base * 0.55 * k
    fm = fl & (np.abs(art.X + 0.5 - bx) <= half)
    nx = np.where(fm, np.clip((art.X + 0.5 - bx) / (half + 0.01), -1, 1), info[1])
    mask = mask | fm
    # flutes: the bark stands in vertical ridges, a few pixels apart, that
    # wander a little as they climb
    wob = (value_noise(W, H, 9, seed + 1) - 0.5) * 3.0
    ph = (art.X + 0.5 - bx + wob) / 2.6
    ridge = np.sin(ph * math.pi)
    light = Art.diffuse(np.clip(nx * 0.75 + ridge * 0.4, -1, 1), np.zeros_like(nx))
    art.put(mask, "bark", 0.16 + 0.86 * light)
    furrow = mask & (np.abs(np.cos(ph * math.pi)) > 0.93) & (value_noise(W, H, 5, seed + 2) > 0.35)
    art.put(furrow, "fissure", 0.25 + 0.6 * light)
    # fire scars: black, tapering hollows up from the ground
    for side, height, width in scars:
        sx = bx + r_base * side
        sh = H * height
        scar = (art.Y + 0.5 > by - sh) & (np.abs(art.X + 0.5 - sx) < r_base * width *
                                          np.clip((art.Y + 0.5 - (by - sh)) / sh, 0, 1) ** 0.7)
        art.put(scar & mask, "char", 0.3 + 0.4 * light)
    if tunnel:
        # the tunnel: dark inside, the daylight at the far end, and the pale
        # cut wood round its edge
        tw, th = tunnel
        dx = (art.X + 0.5 - bx) / (tw / 2.0)
        up = (by + 1 - (art.Y + 0.5)) / th
        inside = ((up < 0.6) | (dx * dx + ((up - 0.6) / 0.4) ** 2 < 1.0)) & (np.abs(dx) < 1.0) & (up > 0)
        edge = (np.abs(dx) < 1.18) & ((up < 0.62) | (dx * dx + ((up - 0.6) / 0.46) ** 2 < 1.0)) & (up > 0) & ~inside
        art.put(edge & mask, "cut", np.where(dx < 0, 0.85, 0.45))
        art.put(inside, "char", 0.1 + 0.5 * np.clip(1 - up, 0, 1))
        far = inside & (np.abs(dx) < 0.42) & (up < 0.5)
        art.put(far & (up >= 0.18), "sky", 0.6)
        art.put(far & (up < 0.18), "grass", 0.5)
    if elbow:
        paint_limbs(art, [limbs[-1 if not spike_top else -2]], True)
    paint_limbs(art, limbs, True)
    paint_tufts(art, front, crown, 0.56, 0.38, 0.14, under_k=0.12)
    if spike_top:
        # the dead, broken top: silver wood standing out of the crown
        sx = trunk_x(top + 14)
        m, info = art.polyline([(sx, top + 22), (sx + 0.5, top + 8), (sx + 1.5, top + 1)], 2.2, 0.6)
        art.put(m, "deadlimb", 0.25 + 0.6 * Art.diffuse(info[1], info[2]))
        for dx, dy, ln in ((-1, 12, 4), (1, 9, 3)):
            m, info = art.capsule(sx, top + dy, sx + dx * ln, top + dy - 2, 0.7, 0.4)
            art.put(m, "deadlimb", 0.3 + 0.5 * Art.diffuse(info[1], info[2]))
    _flat_bottom(art, by)
    return art


def fallen_monarch(W: int, H: int) -> Art:
    """The Fallen Monarch: a sequoia that fell centuries ago and has hardly
    rotted, its root plate standing on end at the left and its fluted trunk
    lying straight along the ground. (In an 1899 photograph a troop of cavalry
    stands on top of it.)"""
    seed = 1899
    rmp = ramps(bark="sequoia_bark", fissure="sequoia_fissure", soil="root_soil", root="limb_red", cut="cut_wood",
                char="char")
    art = Art(W, H, rmp, seed)
    art.dither["bark"] = 0.3
    rng = np.random.default_rng(seed)
    x0, x1 = 16.0, W - 2.0
    u = np.clip((art.X + 0.5 - x0) / (x1 - x0), 0, 1)
    half = 14.0 + (7.0 - 14.0) * u
    cy = H - 6.0 - half
    v = (art.Y + 0.5 - cy) / half  # -1 top .. 1 underside
    log = (art.X + 0.5 >= x0) & (art.X + 0.5 <= x1) & (np.abs(v) <= 1.0)
    # the log lit as a cylinder lying across the view, from above and the left
    ny = np.clip(v, -1, 1)
    light = Art.diffuse(np.zeros_like(ny) - 0.15, ny)
    wob = (value_noise(W, H, 9, seed + 1) - 0.5) * 2.0
    ph = (art.Y + 0.5 - cy + wob) / 2.4
    ridge = np.sin(ph * math.pi)
    lit = Art.diffuse(np.zeros_like(ny) - 0.15, np.clip(ny * 0.8 + ridge * 0.35, -1, 1))
    art.put(log, "bark", 0.14 + 0.86 * lit)
    furrow = log & (np.abs(np.cos(ph * math.pi)) > 0.92) & (value_noise(W, H, 5, seed + 2) > 0.4)
    art.put(furrow, "fissure", 0.25 + 0.6 * light)
    # the broken top end, pale and splintered
    end = log & (art.X + 0.5 > x1 - 2.5)
    art.put(end, "cut", 0.55 + 0.3 * (art.Y % 2 == 0))
    # the root plate on end: a dark disc of roots and earth
    dx = (art.X + 0.5 - 17.0) / 15.0
    dy = (art.Y + 0.5 - 26.0) / 23.0
    plate = dx * dx + dy * dy <= 1.0 + (value_noise(W, H, 2.0, seed + 3) - 0.5) * 0.4
    art.put(plate, "soil", 0.62 - dx * 0.3 - dy * 0.35 + (value_noise(W, H, 1.5, seed + 4) - 0.5) * 0.4)
    # roots curling out of the plate
    for i in range(9):
        a = i / 9 * 6.283 + rng.normal() * 0.2
        px, py = 17.0 + math.cos(a) * 13.0, 26.0 + math.sin(a) * 20.0
        qx, qy = 17.0 + math.cos(a) * 17.5, 26.0 + math.sin(a) * 24.5
        m, info = art.capsule(px, py, min(max(qx, 1.0), W - 2), min(max(qy, 1.0), H - 4), 1.3, 0.6)
        art.put(m, "root", 0.3 + 0.5 * Art.diffuse(info[1], info[2]))
    art.mat[H - 4:, :] = -1
    return art


# ------------------------------------------------------------------ snags

def snag(W: int, H: int, variant: str = "a") -> Art:
    """A dead conifer still standing: silver-grey wood where the bark has
    gone, darker where it hangs on, its top snapped off, a few broken limbs,
    and the holes woodpeckers have dug."""
    seed = 1101 if variant == "a" else 1202
    rmp = ramps(bark="snag", fissure="snag_dark", limb="deadlimb", deadlimb="deadlimb", char="char", patch="limb")
    art = Art(W, H, rmp, seed)
    rng = np.random.default_rng(seed)
    bx, by = W / 2.0, H - FOOT
    top = 8
    pts, trunk_x = _trunk_line(bx, by, top, rng.normal() * 1.5, seed, 0.6)
    limbs = []
    for _ in range(7):
        sy = top + 6 + (by - top - 25) * rng.random()
        lp, z = limb_path(trunk_x(sy), sy, rng.uniform(3, 9), rng.random() * 6.283, 0.3, 0.4, 3)
        limbs.append(Limb(lp, z, 0.9, 0.4, dead=True))
    paint_limbs(art, limbs, False, "limb", "deadlimb")
    m = trunk(art, pts, W * 0.12, W * 0.06, "bark", "fissure", (2.4, 9.0), 1.6, 5.0, seed, plate_light=0.12,
              fissure_w=0.16, strips=True)
    # the snapped top: a jagged, splintered end
    jag = m & (art.Y < top + 3 + np.sin(art.X * 2.1) * 1.5)
    art.mat[jag] = -1
    # patches of bark still hanging on low down, darker
    patch = m & (value_noise(W, H, 6, seed + 3) > 0.6) & (art.Y > H * 0.45)
    art.recolor(patch, "patch")
    # woodpecker holes
    for _ in range(4):
        hy = top + 12 + (by - top - 30) * rng.random()
        art.put(art.ellipse(trunk_x(hy) + rng.normal() * 0.8, hy, 0.8, 0.9) & m, "char", 0.2)
    paint_limbs(art, limbs, True, "limb", "deadlimb")
    _flat_bottom(art, by)
    return art
