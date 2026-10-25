#!/usr/bin/env python3
"""The real skylines of the landmarks the climbing screen, the Glacier Point
binoculars, the slackline and the story vistas paint past the edge of the
wall (scripts/climb/art/climb_landscape.gd): each one's silhouette, measured
from the USGS's lidar heights as seen from where the game looks at it (its
routes' side of the Valley, or Glacier Point's railing), with how each
column of it faces the light, how much of it is sheer wall, and where its
waterfalls and its named features stand across it (from OpenStreetMap).

The landscape painter keeps its own sizes, layers and colors; this only gives
it the true shapes. Written to scripts/climb/art/landmark_shapes.gd.

    python3 tools/art32/walls32/skylines.py                # write the shapes
    python3 tools/art32/walls32/skylines.py --preview DIR  # and a sheet of them, to look at

Heights are cached in tools/art32/walls32/cache/ (git-ignored).
"""
from __future__ import annotations

import math
import os
import sys
from dataclasses import dataclass, field

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import dem as D  # noqa: E402
import elevation as EV  # noqa: E402
import paint as PT  # noqa: E402

OUT = os.path.join(PT.ROOT, "scripts", "climb", "art", "landmark_shapes.gd")
SAMPLES = 128
EXAGGERATE = 1.7  # how much taller than true the painter draws them (as the cliff walls)
# light from the upper left, as everywhere in the game: picture right, up, toward the viewer
LIGHT = np.array([-0.62, 0.62, 0.48], np.float32)
LIGHT /= np.linalg.norm(LIGHT)

# where the game looks from
SENTINEL_BRIDGE = (37.7434, -119.5878)
CURRY = (37.7375, -119.5717)
AHWAHNEE_MEADOW = (37.7470, -119.5720)
GLACIER_POINT = (37.73067, -119.57367)
SWAN_SLAB = (37.7425, -119.6030)
EL_CAP_FOOT = (37.7290, -119.6365)
EL_CAP_MEADOW = (37.7215, -119.6340)
SPIRES_FOOT = (37.7215, -119.6250)
COOKS_MEADOW = (37.7445, -119.5905)
BRIDALVEIL_MEADOW = (37.7255, -119.6460)
CATHEDRAL_PEAK = (37.8475, -119.4050)
LYELL_CANYON = (37.7700, -119.2720)
CATHEDRAL_SPIRES = (37.7140, -119.6330)
SENTINEL_NORTH_FACE = (37.7300, -119.5945)
THE_NOSE = (37.7300, -119.6370)
MIRROR_LAKE = (37.7469, -119.5517)
LEIDIG_MEADOW = (37.7440, -119.5950)
LECONTE = (37.7330, -119.5730)

NOSE = (37.72859, -119.63704)


@dataclass
class Sky:
    target: tuple[float, float]  # the landmark's summit or middle
    eye: tuple[float, float]
    radius: float  # metres round the target that are its own rock
    floor: float  # the height drawn as its foot
    eye_h: float = 150.0  # metres above the ground (a climber partway up a wall)
    falls: list = field(default_factory=list)  # (lat, lon) of its waterfalls, top first
    marks: dict = field(default_factory=dict)  # name -> (lat, lon): features the painter places


SKIES: dict[str, Sky] = {
    # Half Dome from down the Valley: the sheer face on the left, the round
    # back falling away to the right
    "half_dome": Sky((37.74600, -119.53325), SENTINEL_BRIDGE, 1300.0, 1700.0),
    "north_dome": Sky((37.75687, -119.55989), CURRY, 700.0, 2050.0),
    "basket_dome": Sky((37.76354, -119.55072), GLACIER_POINT, 600.0, 1950.0, eye_h=2.0),
    "liberty_cap": Sky((37.72877, -119.53250), GLACIER_POINT, 380.0, 1800.0, eye_h=2.0),
    "mt_broderick": Sky((37.73326, -119.53524), GLACIER_POINT, 300.0, 1800.0, eye_h=2.0),
    # Glacier Point from Camp 4, rising to the point, where the rim falls
    # away into the Merced's canyon
    "glacier_point": Sky((37.73067, -119.57367), SWAN_SLAB, 1100.0, 1250.0, marks={"point": GLACIER_POINT}),
    "royal_arches": Sky((37.74863, -119.57004), LECONTE, 700.0, 1230.0, marks={"arches": (37.74863, -119.57004)}),
    "washington_column": Sky((37.74853, -119.56005), CURRY, 450.0, 1230.0),
    # Sentinel Rock from the Valley floor to the north, an obelisk
    "sentinel_rock": Sky((37.72886, -119.59446), LEIDIG_MEADOW, 350.0, 1850.0, falls=[(37.72491, -119.59650)]),
    "cathedral_rocks": Sky((37.71575, -119.63760), EL_CAP_FOOT, 800.0, 1230.0),
    "el_capitan": Sky((37.73422, -119.63761), CATHEDRAL_SPIRES, 1300.0, 1225.0, marks={"prow": NOSE}),
    "three_brothers": Sky((37.74187, -119.61406), CATHEDRAL_SPIRES, 900.0, 1225.0),
    "yosemite_falls": Sky((37.75697, -119.59677), SENTINEL_NORTH_FACE, 1100.0, 1225.0, eye_h=300.0,
                          falls=[(37.75697, -119.59677), (37.75144, -119.59714)]),
    "bridalveil": Sky((37.71681, -119.64677), THE_NOSE, 650.0, 1200.0, eye_h=300.0, falls=[(37.71681, -119.64677)]),
    "nevada_fall": Sky((37.72490, -119.53336), GLACIER_POINT, 520.0, 1600.0, eye_h=2.0, falls=[(37.72490, -119.53336)]),
    "clouds_rest": Sky((37.76784, -119.48925), GLACIER_POINT, 1800.0, 2200.0, eye_h=2.0),
    # Tuolumne's needles, from Cathedral Peak
    "cockscomb": Sky((37.83549, -119.38468), CATHEDRAL_PEAK, 450.0, 3230.0, eye_h=40.0),
    "unicorn_peak": Sky((37.84571, -119.38196), CATHEDRAL_PEAK, 500.0, 3080.0, eye_h=40.0),
    "echo_peaks": Sky((37.83369, -119.40253), CATHEDRAL_PEAK, 450.0, 3200.0, eye_h=40.0),
    "matthes_crest": Sky((37.82700, -119.37500), CATHEDRAL_PEAK, 1300.0, 3050.0, eye_h=40.0),
    # the Lyell group, from Lyell Canyon below the glacier
    "mt_lyell": Sky((37.73942, -119.27161), LYELL_CANYON, 1300.0, 3550.0, eye_h=40.0),
    "mt_maclure": Sky((37.74375, -119.28037), LYELL_CANYON, 900.0, 3550.0, eye_h=40.0),
    "donohue_pass": Sky((37.76102, -119.24867), LYELL_CANYON, 1300.0, 3300.0, eye_h=40.0),
    # from Glacier Point's railing
    "north_rim": Sky((37.75647, -119.59290), GLACIER_POINT, 1500.0, 1225.0, eye_h=2.0),
    "mt_hoffmann": Sky((37.84671, -119.51062), GLACIER_POINT, 2500.0, 2700.0, eye_h=2.0),
    "mt_watkins": Sky((37.78270, -119.51766), GLACIER_POINT, 1300.0, 1700.0, eye_h=2.0),
    "mt_starr_king": Sky((37.70294, -119.51755), GLACIER_POINT, 1100.0, 2100.0, eye_h=2.0),
    "mt_clark": Sky((37.69654, -119.42862), GLACIER_POINT, 1600.0, 3000.0, eye_h=2.0),
    "mt_florence": Sky((37.73988, -119.31622), GLACIER_POINT, 2500.0, 3000.0, eye_h=2.0),
    "vernal_fall": Sky((37.72755, -119.54375), GLACIER_POINT, 350.0, 1450.0, eye_h=2.0, falls=[(37.72755, -119.54375)]),
    "illilouette_fall": Sky((37.71393, -119.56145), GLACIER_POINT, 450.0, 1350.0, eye_h=2.0,
                            falls=[(37.71393, -119.56145)]),
}
# The same landmarks as the binoculars see them from Glacier Point, where
# that's not the way the routes see them.
for _kind in ("half_dome", "el_capitan", "sentinel_rock", "three_brothers", "yosemite_falls", "royal_arches",
              "north_dome", "washington_column", "mt_lyell", "mt_maclure"):
    _s = SKIES[_kind]
    SKIES[_kind + "@glacier_point"] = Sky(_s.target if _kind != "three_brothers" else (37.74600, -119.61471),
                                          GLACIER_POINT, _s.radius, _s.floor, eye_h=2.0, falls=_s.falls,
                                          marks=_s.marks)


def _rock(sky: Sky):
    """The heights round the landmark and which of them are its own rock:
    what stands over its floor within its radius, joined to its summit (not
    a neighbour across a canyon that rises as high)."""
    te, tn = D.utm(*sky.target)
    ee, en = D.utm(*sky.eye)
    d = math.hypot(te - ee, tn - en)
    res = float(np.clip(d / 1500.0, 2.0, 15.0))
    pad = sky.radius + 300.0
    box = (math.floor((min(te, ee) - pad) / 100) * 100, math.floor((min(tn, en) - pad) / 100) * 100,
           math.ceil((max(te, ee) + pad) / 100) * 100, math.ceil((max(tn, en) + pad) / 100) * 100)
    dm = D.fetch(*box, res)
    raw_slope = np.degrees(np.arctan(np.hypot(dm.dzde, dm.dzdn)))
    dm = D.DEM(PT.blur(dm.z, max(0.6, 2.4 / res)), dm.e0, dm.n1, dm.res)
    yy, xx = np.mgrid[0:dm.z.shape[0], 0:dm.z.shape[1]]
    ce = dm.e0 + (xx + 0.5) * dm.res
    cn = dm.n1 - (yy + 0.5) * dm.res
    rr = np.hypot(ce - te, cn - tn)
    above = (rr < sky.radius) & (dm.z > sky.floor)
    tr = int(np.clip((dm.n1 - tn) / dm.res, 0, above.shape[0] - 1))
    tc = int(np.clip((te - dm.e0) / dm.res, 0, above.shape[1] - 1))
    if not above[tr, tc]:
        k = int(100.0 / dm.res)
        r0, c0 = max(0, tr - k), max(0, tc - k)
        win = np.where(above[r0:tr + k, c0:tc + k], dm.z[r0:tr + k, c0:tc + k], -1e9)
        r, c = np.unravel_index(np.argmax(win), win.shape)
        tr, tc = r0 + r, c0 + c
    blob = Image.fromarray(above.astype(np.uint8) * 255, "L").copy()  # (a copy: one sharing the array ignores the fill)
    ImageDraw.floodfill(blob, (tc, tr), 128)
    mine = np.array(blob) == 128
    # the share of its rock the radius cut off (it should end by itself)
    cut = float((mine & (rr > sky.radius - 3 * dm.res)).sum()) / max(1, int(mine.sum())) * 100.0
    # how far across it reaches, seen from the eye
    az = np.degrees(np.arctan2(ce[mine] - ee, cn[mine] - en))
    az_c = math.degrees(math.atan2(te - ee, tn - en))
    rel = (az - az_c + 180.0) % 360.0 - 180.0
    return dict(dm=dm, raw_slope=raw_slope, mine=mine, te=te, tn=tn, ee=ee, en=en, d=d, res=res, az_c=az_c,
                lo=float(rel.min()), hi=float(rel.max()), z_top=float(dm.z[mine].max()), cut=cut)


def measure(name: str, sky: Sky) -> dict:
    """The landmark's silhouette and light, [member SAMPLES] columns across."""
    g = _rock(sky)
    dm, mine, d = g["dm"], g["mine"], g["d"]
    ee, en = g["ee"], g["en"]
    # the picture spans the rock, with a little sky either side
    span = g["hi"] - g["lo"]
    a0, a1 = g["lo"] - span * 0.04, g["hi"] + span * 0.04
    az_0 = g["az_c"] + a0
    W, H = SAMPLES, 200
    per = (a1 - a0) / W
    base_row = np.full(W, H - 8.0, np.float32)
    squash = max(1.0, (g["z_top"] - sky.floor) / (H - 30.0))
    # the camera sees only the landmark's own rock: nothing nearer or beside
    # it stands in the way (the painter has its own layers for those)
    ground = float(dm.sample(np.array([ee]), np.array([en]))[0])
    alone = D.DEM(np.where(mine, dm.z, -1000.0), dm.e0, dm.n1, dm.res)
    view = EV.camera(alone, e=ee, n=en, eye=sky.eye_h, W=W, H=H, az_at=lambda c: az_0 + c * per,
                     base_z=sky.floor, base_row=base_row, d0=d, fit=[], depth=d + sky.radius * 1.4,
                     near=max(30.0, d - sky.radius * 1.4), squash=squash, eye_abs=ground + sky.eye_h)
    own = view.hit & (view.z > sky.floor)
    first = np.where(own.any(axis=0), np.argmax(own, axis=0), H).astype(np.float32)
    top_row = float(first.min())
    foot = float(base_row[0])
    height = np.clip((foot - first) / max(1.0, foot - top_row), 0.0, 1.0)
    # the surface's facing from the true heights (the lone rock's edges are cliffs to nowhere)
    slope = dm.sample(view.e, view.n, g["raw_slope"])
    gx = dm.sample(view.e, view.n, dm.dzde)
    gy = dm.sample(view.e, view.n, dm.dzdn)
    azs = np.radians(az_0 + (np.arange(W) + 0.5) * per)[None, :]
    ln0 = np.sqrt(gx * gx + gy * gy + 1.0)
    we, wn, wu = -gx / ln0, -gy / ln0, 1.0 / ln0
    vnx = we * np.cos(azs) - wn * np.sin(azs)
    vnz = -(we * np.sin(azs) + wn * np.cos(azs))
    # the light on each column's upper part, and how much of it is sheer
    nx, ny, nz = (PT.blur_xy(a.astype(np.float32), 1.5, 1.0) for a in (vnx, wu, vnz))
    ln = np.sqrt(nx * nx + ny * ny + nz * nz) + 1e-6
    diff = np.clip((nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2]) / ln, 0, 1)
    tone = np.zeros(W, np.float32)
    steep = np.zeros(W, np.float32)
    for c in range(W):
        if first[c] >= H:
            continue
        r0 = int(first[c])
        r1 = int(r0 + max(2.0, (foot - r0) * 0.45))
        m = own[r0:r1, c]
        if m.any():
            tone[c] = float(diff[r0:r1, c][m].mean())
            steep[c] = float((slope[r0:r1, c][m] > 58.0).mean())
    tone = np.where(height > 0.02, tone, np.median(tone[height > 0.02]) if (height > 0.02).any() else 0.5)

    def across(lat: float, lon: float) -> float:
        fe, fn = D.utm(lat, lon)
        a = math.degrees(math.atan2(fe - ee, fn - en))
        a = (a - g["az_c"] + 180.0) % 360.0 - 180.0
        return float(np.clip((a - a0) / (a1 - a0), 0.0, 1.0))

    return {"top": height, "tone": tone, "steep": steep, "falls": [across(*f) for f in sky.falls],
            "marks": {k: across(*v) for k, v in sky.marks.items()}, "d": d, "az": g["az_c"] % 360.0,
            "half": (a1 - a0) / 2.0, "rise": g["z_top"] - sky.floor, "res": g["res"], "cut": g["cut"],
            "aspect": (a1 - a0) / max(0.1, math.degrees(math.atan2(g["z_top"] - sky.floor, d)))}


def view_image(name: str, sky: Sky) -> Image.Image:
    """The whole view round the landmark, its own rock tinted: to choose its
    floor and radius by."""
    g = _rock(sky)
    dm, mine, d = g["dm"], g["mine"], g["d"]
    span = g["hi"] - g["lo"]
    a0, a1 = g["lo"] - span * 0.5, g["hi"] + span * 0.5
    W, H = 360, 180
    per = (a1 - a0) / W
    rise = g["z_top"] - sky.floor
    squash = max(1.0, (rise * 1.8) / (H - 20.0))
    view = EV.camera(dm, e=g["ee"], n=g["en"], eye=sky.eye_h, W=W, H=H, az_at=lambda c: g["az_c"] + a0 + c * per,
                     base_z=sky.floor - rise * 0.5, base_row=np.full(W, H - 4.0, np.float32), d0=d, fit=[],
                     depth=d + sky.radius * 2.5, near=50.0, squash=squash)
    diff = np.clip(view.nx * LIGHT[0] + view.ny * LIGHT[1] + view.nz * LIGHT[2], 0, 1)
    gg = (60 + 180 * diff).astype(np.uint8)
    img = np.stack([gg, gg, gg], -1)
    img[~view.hit] = [120, 160, 210]
    vr = np.clip(((dm.n1 - view.n) / dm.res).astype(np.int64), 0, mine.shape[0] - 1)
    vc = np.clip(((view.e - dm.e0) / dm.res).astype(np.int64), 0, mine.shape[1] - 1)
    own = view.hit & mine[vr, vc]
    img[own] = (img[own] * np.array([1.0, 0.82, 0.62])).astype(np.uint8)
    im = Image.fromarray(img)
    ImageDraw.Draw(im).text((4, 2), "%s  cut %.0f%%" % (name, g["cut"]), fill=(0, 0, 0))
    return im


def _arr(a: np.ndarray, nd: int) -> str:
    return "[" + ", ".join(("%." + str(nd) + "f") % v for v in a) + "]"


def write(shapes: dict[str, dict]) -> None:
    lines = [
        "extends RefCounted",
        "## The real skylines of the landscape's landmarks, measured from the USGS's",
        "## lidar heights by tools/art32/walls32/skylines.py (generated: don't edit by",
        "## hand). Each: \"top\" the silhouette's height (0 foot .. 1 summit) and \"tone\"",
        "## how much of the game's upper-left light its upper face takes (0 .. 1), and",
        "## \"steep\" how much of that face is sheer wall, at %d steps from left to" % SAMPLES,
        "## right; \"falls\" where its waterfalls leave the rim and \"marks\" where its",
        "## named features stand (0 left .. 1 right); \"aspect\" how much wider than",
        "## tall it really looks. A name with \"@glacier_point\" is the landmark as",
        "## seen from Glacier Point's railing.",
        "",
        "const SHAPES := {",
    ]
    for name, s in shapes.items():
        marks = ", ".join('"%s": %.3f' % (k, v) for k, v in s["marks"].items())
        lines.append('\t"%s": {' % name)
        lines.append('\t\t"top": %s,' % _arr(s["top"], 3))
        lines.append('\t\t"tone": %s,' % _arr(s["tone"], 2))
        lines.append('\t\t"steep": %s,' % _arr(s["steep"], 2))
        lines.append('\t\t"falls": [%s],' % ", ".join("%.3f" % f for f in s["falls"]))
        lines.append('\t\t"marks": {%s},' % marks)
        lines.append('\t\t"aspect": %.2f,' % s["aspect"])
        lines.append("\t},")
    lines.append("}")
    with open(OUT, "w") as f:
        f.write("\n".join(lines) + "\n")
    print("wrote", OUT)


def _sizes() -> dict[str, tuple[int, int]]:
    """Each landmark's width and height in the climbing screen (scale 1)."""
    import re
    src = open(os.path.join(PT.ROOT, "scripts", "climb", "art", "climb_landscape.gd")).read()
    return {m.group(1): (int(m.group(2)), int(m.group(3)))
            for m in re.finditer(r'"(\w+)": \{"w": (\d+), "h": (\d+)', src)}


def preview(shapes: dict[str, dict], out_dir: str) -> None:
    """A sheet: each silhouette at its size in the climbing screen (x2),
    shaded by its tone, sheer wall bluer, falls and marks as ticks."""
    os.makedirs(out_dir, exist_ok=True)
    sizes = _sizes()
    cw, ch = 380, 330
    cols = 5
    rows = (len(shapes) + cols - 1) // cols
    sheet = Image.new("RGB", (cw * cols, ch * rows), (120, 160, 200))
    dr = ImageDraw.Draw(sheet)
    for k, (name, s) in enumerate(shapes.items()):
        w, h = sizes.get(name.split("@")[0], (150, 100))
        # as the painter draws it: its true proportions, a little taller
        h = int(np.clip(w / s["aspect"] * EXAGGERATE, h * 0.6, h))
        w, h = w * 2, h * 2
        ox, oy = (k % cols) * cw + (cw - w) // 2, (k // cols) * ch + ch - 10 - h
        top = s["top"]
        n = len(top)
        for x in range(w):
            f = x / max(1, w - 1) * (n - 1)
            i = int(f)
            j = min(n - 1, i + 1)
            t = f - i
            v = top[i] * (1 - t) + top[j] * t
            y = oy + h - int(v * h)
            g = int(70 + 170 * s["tone"][i])
            col = (g, g - 8, g - 22) if s["steep"][i] < 0.5 else (g - 25, g - 22, g)
            dr.line([ox + x, y, ox + x, oy + h], fill=col)
        for f in s["falls"]:
            x = ox + int(f * (w - 1))
            dr.line([x, oy + int(h * 0.1), x, oy + h], fill=(255, 255, 255))
        for mk, f in s["marks"].items():
            x = ox + int(f * (w - 1))
            dr.line([x, oy - 12, x, oy - 2], fill=(255, 60, 60))
        dr.text(((k % cols) * cw + 4, (k // cols) * ch + 2), name, fill=(0, 0, 0))
    sheet.save(os.path.join(out_dir, "skylines.png"))
    print("preview", os.path.join(out_dir, "skylines.png"))


def main() -> None:
    args = sys.argv[1:]
    prev = None
    if args[:1] == ["--views"]:
        out_dir, names = args[1], args[2:] or list(SKIES)
        os.makedirs(out_dir, exist_ok=True)
        ims = [view_image(n, SKIES[n]) for n in names]
        cols = 3
        sheet = Image.new("RGB", (360 * cols, 180 * ((len(ims) + cols - 1) // cols)), (40, 40, 40))
        for k, im in enumerate(ims):
            sheet.paste(im, ((k % cols) * 360, (k // cols) * 180))
        sheet.save(os.path.join(out_dir, "views.png"))
        print("views", os.path.join(out_dir, "views.png"))
        return
    if args[:1] == ["--preview"]:
        prev = args[1]
        args = args[2:]
    shapes = {}
    for name in args or list(SKIES):
        s = measure(name, SKIES[name])
        print(f"  {name}: {s['d'] / 1000:.1f} km at {s['az']:.0f} deg, {2 * s['half']:.1f} deg wide, "
              f"{s['rise']:.0f} m tall, {s['res']:.0f} m heights" + (f", {s['cut']:.0f}% cut off" if s["cut"] > 1 else ""))
        shapes[name] = s
    if not args:
        write(shapes)
    if prev:
        preview(shapes, prev)


if __name__ == "__main__":
    main()
