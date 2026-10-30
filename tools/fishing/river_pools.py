#!/usr/bin/env python3
"""Widens the Merced into fishing holes: cuts each pool in POOLS out of the
bank in its area's ground picture and its tiles, in place.

A hole is an oval laid over the edge of the river. Inside it the ground
picture is repainted as water in the river's own colors, by how far each
pixel is from the shore (shallow and light at the edge, dark in the deep
middle, and a little darker still at the hole's heart); a few pixels of the
sandy beach go round the new shore. The Ground tiles under it become river
and the Blocker tiles block it, so you can't walk in, the fly lands in it
and nothing grows there; ground clutter (the area's wild dressing) inside it
is taken up. Trees, signs, roads, trails and spots must stay clear of it:
the tool refuses a pool that touches one (--find suggests places that
don't).

    python3 tools/fishing/river_pools.py                 # cut every pool
    python3 tools/fishing/river_pools.py --check         # only check them
    python3 tools/fishing/river_pools.py --find AREA     # suggest places

Run it once on the committed pictures: cutting a pool twice paints it twice.
The FishingWater nodes in the story overlays (scenes/story/content/) mark
the same ovals as holes for the fish (scripts/fishing/fishing_water.gd);
tests/fishing_test.gd checks the two agree. Needs Pillow and numpy.
"""
from __future__ import annotations

import base64
import math
import os
import re
import struct
import sys

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TILE = 32
# Ground terrain rows (tools/mapgen/terrain.gd).
RIVER = 11
WATER_ROWS = (11, 12, 13)
# Ground a pool may be cut into: forest, meadow, wet meadow, foothill, fir,
# subalpine, scrub, granite, sand, and the water itself.
CUTTABLE = (0, 1, 2, 3, 4, 5, 6, 7, 11, 12, 13, 15)
TERRAIN_SOURCE = 1
BLOCK_SOURCE = 3
# How far trees, signs and spots must stand from the new shore (pixels).
CLEARANCE = 20

# Each hole: its area, the middle of the oval, and its half width and half
# height in pixels. The middle sits on the river's bank, so about half of the
# oval is new water. Keep in step with the FishingWater "hole" nodes.
POOLS = [
    ("leidig_meadow", (1520, 1048), (150, 62)),
    ("el_capitan_meadow", (1136, 1336), (170, 70)),
    ("housekeeping_camp", (1392, 1048), (170, 70)),
    ("curry_village", (2288, 1960), (170, 70)),
    ("yosemite_village", (1328, 1688), (170, 70)),
    ("el_portal", (1360, 1320), (170, 70)),
    ("wawona", (1008, 856), (170, 70)),
]


def scene_path(area: str) -> str:
    return os.path.join(ROOT, "scenes", "regions", area + ".tscn")


def read_layer(text: str, name: str) -> tuple[re.Match, dict]:
    m = re.search(r'(\[node name="%s" type="TileMapLayer"[^\n]*\n(?:[^\[\n][^\n]*\n)*?tile_map_data = PackedByteArray\(")([^"]*)("\))' % name, text)
    if m is None:
        raise SystemExit("no %s layer" % name)
    raw = base64.b64decode(m.group(2))
    cells = {}
    for i in range((len(raw) - 2) // 12):
        x, y, src, ax, ay, alt = struct.unpack_from("<hhHHHH", raw, 2 + i * 12)
        cells[(x, y)] = (src, ax, ay, alt)
    return m, cells


def pack_layer(cells: dict) -> str:
    out = bytearray(b"\x00\x00")
    for (x, y), (src, ax, ay, alt) in sorted(cells.items(), key=lambda kv: (kv[0][1], kv[0][0])):
        out += struct.pack("<hhHHHH", x, y, src, ax, ay, alt)
    return base64.b64encode(bytes(out)).decode()


def art_path(text: str) -> str:
    gid = re.search(r'\[node name="GroundArt"[^\n]*\n(?:[^\[\n][^\n]*\n)*?texture = ExtResource\("([^"]+)"\)', text).group(1)
    path = re.search(r'\[ext_resource type="Texture2D" path="res://([^"]+)" id="%s"\]' % re.escape(gid), text).group(1)
    return os.path.join(ROOT, path)


def obstacles(area: str, text: str) -> list[tuple[str, float, float]]:
    """Trees, signs and other things standing in the area, the story's
    people, pickups and doors, and its named spots."""
    found = []
    for m in re.finditer(r'\[node name="([^"]+)" type="[^"]+" parent="Entities"[^\n]*\n((?:[^\[\n][^\n]*\n)*)', text):
        pos = re.search(r"^position = Vector2\(([-\d.]+), ([-\d.]+)\)", m.group(2), re.M)
        if pos:
            found.append((m.group(1), float(pos.group(1)), float(pos.group(2))))
    for m in re.finditer(r'\[node name="([^"]+)" type="Marker2D"[^\n]*\n((?:[^\[\n][^\n]*\n)*)', text):
        pos = re.search(r"^position = Vector2\(([-\d.]+), ([-\d.]+)\)", m.group(2), re.M)
        if pos:
            found.append((m.group(1), float(pos.group(1)), float(pos.group(2))))
    for sub in ("story/content", "story/doors"):
        path = os.path.join(ROOT, "scenes", sub, area + ".tscn")
        if not os.path.exists(path):
            continue
        for m in re.finditer(r'\[node name="([^"]+)"[^\n]*parent="\."[^\n]*\n((?:[^\[\n][^\n]*\n)*)', open(path).read()):
            pos = re.search(r"^position = Vector2\(([-\d.]+), ([-\d.]+)\)", m.group(2), re.M)
            if pos and "FishingWater" not in m.group(2) and not m.group(1).endswith(("Hole", "Rapids")):
                found.append((m.group(1), float(pos.group(1)), float(pos.group(2))))
    return found


def inside(px: float, py: float, center, radii, grow=0.0) -> bool:
    dx = (px - center[0]) / (radii[0] + grow)
    dy = (py - center[1]) / (radii[1] + grow)
    return dx * dx + dy * dy <= 1.0


def problems(area: str, center, radii) -> list[str]:
    text = open(scene_path(area)).read()
    _, ground = read_layer(text, "Ground")
    found = []
    for name, x, y in obstacles(area, text):
        if inside(x, y, center, radii, CLEARANCE):
            found.append(name)
    water = 0
    cells = 0
    for (cx, cy), (src, ax, ay, alt) in ground.items():
        if inside(cx * TILE + 16, cy * TILE + 16, center, radii, 16):
            if src == TERRAIN_SOURCE and ay not in CUTTABLE:
                found.append("ground %d at %d,%d" % (ay, cx, cy))
        if inside(cx * TILE + 16, cy * TILE + 16, center, radii):
            cells += 1
            water += src == TERRAIN_SOURCE and ay in WATER_ROWS
    if cells and not 0.2 <= water / cells <= 0.7:
        found.append("only %d%% of it is river now" % round(100 * water / cells))
    return found


def is_water(rgb: np.ndarray) -> np.ndarray:
    r, g, b = (rgb[..., i].astype(int) for i in range(3))
    teal = (b > r + 25) & (g > r + 15)
    white = (r > 215) & (g > 215) & (b > 215)
    return teal | white


def distance(mask: np.ndarray, limit: int) -> np.ndarray:
    """How many pixels each True pixel is from the nearest False one (up
    to limit), by repeated erosion."""
    dist = np.zeros(mask.shape, dtype=np.int32)
    cur = mask.copy()
    for d in range(1, limit + 1):
        dist[cur] = d
        nxt = cur.copy()
        nxt[1:, :] &= cur[:-1, :]
        nxt[:-1, :] &= cur[1:, :]
        nxt[:, 1:] &= cur[:, :-1]
        nxt[:, :-1] &= cur[:, 1:]
        nxt[0, :] = nxt[-1, :] = False
        nxt[:, 0] = nxt[:, -1] = False
        if not nxt.any():
            break
        cur = nxt
    return dist


# A 4x4 ordered dither, so the river's two-color shading reads as pixel art
# rather than noise.
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 + 1 / 32.0


def shades(px: np.ndarray) -> tuple[np.ndarray, np.ndarray, float]:
    """The two commonest colors in [param px], and how often the second
    turns up between them."""
    colors, counts = np.unique(px.reshape(-1, 3), axis=0, return_counts=True)
    order = np.argsort(-counts)
    first = colors[order[0]]
    if len(order) == 1:
        return first, first, 0.0
    second = colors[order[1]]
    return first, second, counts[order[1]] / (counts[order[0]] + counts[order[1]])


def paint(img: np.ndarray, center, radii, rng: np.random.Generator) -> None:
    # the window repainted: the oval, and the river beyond its ends where the
    # shading blends back into the old
    x0 = max(0, int(center[0] - radii[0] * 1.6) - 16)
    x1 = min(img.shape[1], int(center[0] + radii[0] * 1.6) + 16)
    y0 = max(0, int(center[1] - radii[1] * 1.6) - 16)
    y1 = min(img.shape[0], int(center[1] + radii[1] * 1.6) + 16)
    # a wider window to learn the river's colors from, and to measure the
    # distance to the shore in (so the window's own edge isn't a shore)
    wx0, wx1 = max(0, x0 - 400), min(img.shape[1], x1 + 400)
    wy0, wy1 = max(0, y0 - 160), min(img.shape[0], y1 + 160)
    learn = img[wy0:wy1, wx0:wx1, :3].copy()
    water = is_water(learn)
    dist = distance(water, 60)
    shore_out = distance(~water, 8)
    # the river's shading by distance from the shore
    lut = {}
    for d in range(1, 61):
        px = learn[dist == d]
        if len(px) >= 8:
            lut[d] = shades(px)
    deepest = max(lut)
    palette = np.unique(learn[water].reshape(-1, 3), axis=0).astype(float)
    palette = np.concatenate([palette, palette * 0.86, palette * 0.74])
    sand = learn[(shore_out >= 2) & (shore_out <= 6)]
    sand = sand[(sand[:, 0].astype(int) > 150) & (sand[:, 0].astype(int) > sand[:, 2].astype(int) + 15)]

    # the new water: an oval with a ragged edge
    ys, xs = np.mgrid[wy0:wy1, wx0:wx1]
    ang = np.arctan2((ys - center[1]) / radii[1], (xs - center[0]) / radii[0])
    phase = rng.uniform(0, math.tau, 3)
    wobble = 1.0 + 0.05 * np.sin(3 * ang + phase[0]) + 0.035 * np.sin(7 * ang + phase[1]) + 0.02 * np.sin(13 * ang + phase[2])
    norm = np.sqrt(((xs - center[0]) / radii[0]) ** 2 + ((ys - center[1]) / radii[1]) ** 2) / wobble
    pool = norm <= 1.0
    new_water = pool | water
    nd = distance(new_water, deepest + 40)
    out = distance(~new_water, 7)
    snapped = {}
    for yy in range(y0 - wy0, y1 - wy0):
        for xx in range(x0 - wx0, x1 - wx0):
            n = norm[yy, xx]
            if new_water[yy, xx]:
                # the old river blends in beyond the oval, more of it repainted nearer
                if not pool[yy, xx] and (n > 1.55 or rng.random() > (1.55 - n) / 0.55):
                    continue
                d = int(nd[yy, xx])
                first, second, mix = lut[min(max(d, 1), deepest)]
                c = second if BAYER[(yy + wy0) % 4, (xx + wx0) % 4] < mix else first
                # the hole's heart is deeper than the river ever gets
                heart = max(0.0, 1.0 - n) ** 1.5
                if heart > 0.05:
                    key = (tuple(c), round(heart * 8))
                    if key not in snapped:
                        want = c.astype(float) * (1.0 - 0.26 * heart)
                        snapped[key] = palette[np.argmin(((palette - want) ** 2).sum(axis=1))]
                    c = snapped[key]
                img[yy + wy0, xx + wx0, :3] = np.clip(c, 0, 255).astype(np.uint8)
                img[yy + wy0, xx + wx0, 3] = 255
            elif len(sand) and 1 <= out[yy, xx] <= 6 and n <= 1.3 and not water[yy, xx]:
                # a sandy beach round the new shore, ragged at its back
                if out[yy, xx] >= 5 and rng.random() < 0.5:
                    continue
                img[yy + wy0, xx + wx0, :3] = sand[rng.integers(len(sand))]


def cut(area: str, center, radii, rng) -> None:
    path = scene_path(area)
    text = open(path).read()
    gm, ground = read_layer(text, "Ground")
    for (cx, cy), (src, ax, ay, alt) in list(ground.items()):
        if inside(cx * TILE + 16, cy * TILE + 16, center, radii, -4):
            ground[(cx, cy)] = (TERRAIN_SOURCE, (cx * 7 + cy * 3) % 4, RIVER, 0)
    text = text[:gm.start(2)] + pack_layer(ground) + text[gm.end(2):]
    bm, blocker = read_layer(text, "Blocker")
    for (cx, cy), cell in ground.items():
        if cell[0] == TERRAIN_SOURCE and cell[2] == RIVER and inside(cx * TILE + 16, cy * TILE + 16, center, radii, 24):
            blocker[(cx, cy)] = (BLOCK_SOURCE, 0, 0, 0)
    text = text[:bm.start(2)] + pack_layer(blocker) + text[bm.end(2):]
    open(path, "w").write(text)
    art = art_path(text)
    img = np.array(Image.open(art).convert("RGBA"))
    paint(img, center, radii, rng)
    Image.fromarray(img).save(art)
    # ground clutter in the new water goes
    dressing = os.path.join(ROOT, "scenes", "regions", "dressing", "wild", area + ".tscn")
    if os.path.exists(dressing):
        dtext = open(dressing).read()
        blocks = re.split(r"(?=\n\[node )", dtext)
        kept = []
        gone = 0
        for block in blocks:
            pos = re.search(r"^position = Vector2\(([-\d.]+), ([-\d.]+)\)", block, re.M)
            if block.startswith("\n[node") and pos and inside(float(pos.group(1)), float(pos.group(2)), center, radii, 12):
                gone += 1
                continue
            kept.append(block)
        open(dressing, "w").write("".join(kept))
        print("  took up %d bits of clutter" % gone)
    print("cut a hole in %s at %s" % (area, center))


def find(area: str) -> None:
    text = open(scene_path(area)).read()
    _, ground = read_layer(text, "Ground")
    rivers = [(cx, cy) for (cx, cy), c in ground.items() if c[0] == TERRAIN_SOURCE and c[2] == RIVER]
    if not rivers:
        print("no river in", area)
        return
    by_col = {}
    for cx, cy in rivers:
        lo, hi = by_col.get(cx, (cy, cy))
        by_col[cx] = (min(lo, cy), max(hi, cy))
    for radii in ((170, 70), (150, 62), (130, 56)):
        for cx in sorted(by_col):
            lo, hi = by_col[cx]
            for cy in (lo * TILE + 8, (hi + 1) * TILE - 8):
                center = (cx * TILE + 16, cy)
                if not problems(area, center, radii):
                    print(area, center, radii)


def main() -> None:
    args = sys.argv[1:]
    if args and args[0] == "--find":
        find(args[1])
        return
    bad = False
    for area, center, radii in POOLS:
        found = problems(area, center, radii)
        if found:
            bad = True
            print("%s %s: in the way: %s" % (area, center, ", ".join(found)))
    if bad or (args and args[0] == "--check"):
        sys.exit(1 if bad else 0)
    rng = np.random.default_rng(1868)
    for area, center, radii in POOLS:
        cut(area, center, radii, rng)


if __name__ == "__main__":
    main()
