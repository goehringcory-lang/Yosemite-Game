#!/usr/bin/env python3
"""Lays footbridges and fords across the Merced on the Valley floor, so the
far bank of the river in each area is somewhere you can go.

Most Valley areas are painted the same way: the cliff along the top, the
road, a meadow or the woods, then the river near the bottom with a strip of
sand and woods beyond it. Before this the strip past the river could only be
reached in El Capitan Meadow (over El Capitan Bridge); in Housekeeping Camp,
Upper Pines and along Southside Drive (Four Mile and Bridalveil) it was
painted but cut off. Each crossing here closes a loop: over the bridge, along
the far bank, and back by another crossing or over a seam.

A crossing is a rectangle of tiles running across the river. Its Ground tiles
become BRIDGE (a plank footbridge with rails, as tools/art32/ground32 paints
one) or CREEK (a cobbled riffle you can wade, the ford), and the Blocker
tiles under it are taken out. The ground picture is painted again by
tools/art32/ground32/paint.py from the changed grid, and only the crossing
and a margin round it is copied into the area's picture, so fishing holes
and everything else painted there stay as they are.

    godot --headless --path . res://tools/art32/ground32/dump.tscn -- DUMP_DIR
    python3 tools/seams/river_crossings.py DUMP_DIR          # lay every crossing
    python3 tools/seams/river_crossings.py --check           # only check them

Then run tools/normals/normals.py on the changed ground pictures and
`godot --headless --path . --import`. Run it once on the committed maps: a
crossing already laid is skipped (its tiles are walkable already).
tests/valley_floor_test.gd checks every crossing is walkable end to end.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "fishing"))
import river_pools as rp  # noqa: E402  (tile layer reading and writing)

TILE = 32
TERRAIN_SOURCE = 1
CREEK = 13
SAND = 15
BRIDGE = 18
SOLID = (8, 9, 10, 11, 12, 14)  # cliff, talus, scree, river, lake, falls
# How far round a crossing the fresh paint is copied in (pixels), and how
# wide the band is over which it fades into the old picture.
MARGIN = 40
FEATHER = 16

# Keep in step with CROSSINGS in scripts/world/valley_floor.gd.
# (area, kind, x0, y0, x1, y1): tiles x0..x1, y0..y1 inclusive.
CROSSINGS = [
    ("housekeeping_camp", "bridge", 22, 30, 23, 32),
    ("upper_pines", "bridge", 27, 43, 28, 45),
    ("four_mile_trailhead", "ford", 46, 30, 47, 32),
    ("leidig_meadow", "ford", 24, 30, 25, 33),
]


def apply_tiles(area: str, kind: str, x0: int, y0: int, x1: int, y1: int) -> bool:
    path = rp.scene_path(area)
    text = open(path).read()
    gm, ground = rp.read_layer(text, "Ground")
    terrain = BRIDGE if kind == "bridge" else CREEK
    changed = False
    for cy in range(y0, y1 + 1):
        for cx in range(x0, x1 + 1):
            src, ax, ay, alt = ground.get((cx, cy), (TERRAIN_SOURCE, 0, 0, 0))
            if ay != terrain:
                ground[(cx, cy)] = (TERRAIN_SOURCE, (cx * 7 + cy * 3) % 4, terrain, 0)
                changed = True
    text = text[:gm.start(2)] + rp.pack_layer(ground) + text[gm.end(2):]
    bm, blocker = rp.read_layer(text, "Blocker")
    for cy in range(y0, y1 + 1):
        for cx in range(x0, x1 + 1):
            if (cx, cy) in blocker:
                del blocker[(cx, cy)]
                changed = True
    text = text[:bm.start(2)] + rp.pack_layer(blocker) + text[bm.end(2):]
    if changed:
        open(path, "w").write(text)
    return changed


def check(area: str, kind: str, x0: int, y0: int, x1: int, y1: int) -> list[str]:
    """Problems with a crossing: it must start and end on walkable ground, run
    over water, and keep clear of trees, signs and spots."""
    out = []
    text = open(rp.scene_path(area)).read()
    _, ground = rp.read_layer(text, "Ground")
    _, blocker = rp.read_layer(text, "Blocker")

    def walkable(cx, cy):
        return (cx, cy) not in blocker and ground.get((cx, cy), (0, 0, 8, 0))[2] not in SOLID

    for cx in range(x0, x1 + 1):
        if not walkable(cx, y0 - 1) or not walkable(cx, y1 + 1):
            out.append("%s %s at column %d doesn't land on walkable ground" % (area, kind, cx))
    rect = (x0 * TILE - 8, y0 * TILE - 24, (x1 + 1) * TILE + 8, (y1 + 1) * TILE + 8)
    for name, px, py in rp.obstacles(area, text):
        if rect[0] <= px <= rect[2] and rect[1] <= py <= rect[3]:
            out.append("%s %s is in the way of %s" % (area, kind, name))
    return out


def repaint(dump_dir: str, areas: dict) -> None:
    """Paints the changed areas afresh into a scratch folder and copies each
    crossing (and its margin) into the area's ground picture."""
    with tempfile.TemporaryDirectory() as tmp:
        dumps = os.path.join(tmp, "dump")
        os.makedirs(dumps)
        for area, rects in areas.items():
            d = json.load(open(os.path.join(dump_dir, area + ".json")))
            w = d["w"]
            for kind, x0, y0, x1, y1 in rects:
                for cy in range(y0, y1 + 1):
                    for cx in range(x0, x1 + 1):
                        d["kinds"][cy * w + cx] = BRIDGE if kind == "bridge" else SAND
            json.dump(d, open(os.path.join(dumps, area + ".json"), "w"))
        out = os.path.join(tmp, "out")
        subprocess.run([sys.executable, os.path.join(ROOT, "tools", "art32", "ground32", "paint.py"),
                        "--out", out, dumps] + list(areas), check=True, stdout=subprocess.DEVNULL)
        for area, rects in areas.items():
            art = rp.art_path(open(rp.scene_path(area)).read())
            old = np.array(Image.open(art).convert("RGBA")).astype(np.float32)
            new = np.array(Image.open(os.path.join(out, os.path.basename(art))).convert("RGBA")).astype(np.float32)
            h, w = old.shape[:2]
            yy, xx = np.mgrid[0:h, 0:w]
            weight = np.zeros((h, w), np.float32)
            for _kind, x0, y0, x1, y1 in rects:
                # distance outside the crossing's margin box
                bx0, by0 = x0 * TILE - MARGIN, y0 * TILE - MARGIN
                bx1, by1 = (x1 + 1) * TILE + MARGIN, (y1 + 1) * TILE + MARGIN
                dx = np.maximum(np.maximum(bx0 - xx, xx - bx1), 0)
                dy = np.maximum(np.maximum(by0 - yy, yy - by1), 0)
                d = np.maximum(dx, dy).astype(np.float32)
                weight = np.maximum(weight, np.clip(1.0 - d / FEATHER, 0.0, 1.0))
            # dither the fade so it stays on whole pixels, like the art
            rng = np.random.default_rng(7)
            take = (rng.random((h, w)) < weight)[..., None]
            merged = np.where(take, new, old)
            Image.fromarray(merged.astype(np.uint8)).save(art)
            print("painted %d crossing(s) into %s" % (len(rects), os.path.relpath(art, ROOT)))


def stones(area: str, _kind: str, x0: int, y0: int, x1: int, y1: int) -> None:
    """Paints a ford into the area's picture: the river runs on over it,
    paler where it's shallow, with flat-topped granite stepping stones
    across, each with a wet rim, a shadow down and to the right and a little
    white water on its upstream side."""
    art = rp.art_path(open(rp.scene_path(area)).read())
    img = np.array(Image.open(art).convert("RGBA")).astype(np.float32)
    h, w = img.shape[:2]
    rx0, rx1 = x0 * TILE, (x1 + 1) * TILE
    ry0, ry1 = y0 * TILE - 8, (y1 + 1) * TILE + 8
    yy, xx = np.mgrid[0:h, 0:w]
    water = rp.is_water(img[..., :3].astype(np.uint8))
    # shallows: the water over the ford lightens toward the cobbles
    cx = (rx0 + rx1) / 2.0
    band = np.clip(1.0 - np.abs(xx - cx) / ((rx1 - rx0) / 2.0 + 18), 0, 1)
    band *= ((yy >= ry0) & (yy < ry1))
    shallow = np.array([118, 160, 150], np.float32)
    k = (band * 0.45 * water)[..., None]
    img[..., :3] = img[..., :3] * (1 - k) + shallow * k
    rng = np.random.default_rng(len(area) * 31 + x0)
    stone_lo = np.array([92, 94, 98], np.float32)
    stone_mid = np.array([150, 148, 142], np.float32)
    stone_hi = np.array([196, 190, 178], np.float32)
    shadow = np.array([30, 52, 60], np.float32)
    foam = np.array([226, 236, 232], np.float32)
    y = ry0 + 4
    i = 0
    while y < ry1 - 6:
        sx = cx + (-9 if i % 2 == 0 else 9) + rng.integers(-3, 4)
        sy = y + 9
        a, b = 12 + rng.integers(0, 3), 8 + rng.integers(0, 2)
        d = ((xx - sx) / a) ** 2 + ((yy - sy) / b) ** 2
        ds = ((xx - sx - 3) / a) ** 2 + ((yy - sy - 3) / b) ** 2
        on_water = water | (band > 0)
        # foam on the upstream (west) side, shadow down-right, then the stone
        f = (d < 1.45) & (d >= 1.0) & (xx < sx) & on_water
        img[f, :3] = foam
        s = (ds < 1.0) & (d >= 1.0) & on_water
        img[s, :3] = img[s, :3] * 0.4 + shadow * 0.6
        top = d < 1.0
        light = np.clip(1.0 - ((xx - sx + a * 0.35) / a) ** 2 - ((yy - sy + b * 0.4) / b) ** 2, 0, 1)
        col = np.where((d > 0.7)[..., None], stone_lo, np.where((light > 0.55)[..., None], stone_hi, stone_mid))
        img[top, :3] = col[top]
        y += 16 + rng.integers(0, 3)
        i += 1
    # keep to whole art pixels (2x2), like the rest of the ground
    sub = img[(yy // 2 * 2 == yy) & (xx // 2 * 2 == xx)]
    del sub
    img[1::2, :, :] = np.where(((yy[1::2] >= ry0 - 8) & (yy[1::2] < ry1 + 8) & (xx[1::2] >= rx0 - 24) & (xx[1::2] < rx1 + 24))[..., None], img[0::2, :, :][: img[1::2].shape[0]], img[1::2])
    img[:, 1::2, :] = np.where(((yy[:, 1::2] >= ry0 - 8) & (yy[:, 1::2] < ry1 + 8) & (xx[:, 1::2] >= rx0 - 24) & (xx[:, 1::2] < rx1 + 24))[..., None], img[:, 0::2, :][:, : img[:, 1::2].shape[1]], img[:, 1::2])
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(art)
    print("laid a ford in %s" % os.path.relpath(art, ROOT))


def main() -> None:
    args = sys.argv[1:]
    problems = []
    for c in CROSSINGS:
        problems += check(*c)
    if args and args[0] == "--check":
        print("\n".join(problems) or "all crossings clear")
        sys.exit(1 if problems else 0)
    if not args:
        raise SystemExit(__doc__)
    todo: dict = {}
    for c in CROSSINGS:
        area = c[0]
        if apply_tiles(*c):
            if c[1] == "bridge":
                todo.setdefault(area, []).append(c[1:])
            else:
                stones(*c)
        else:
            print("%s %s already laid" % (area, c[1]))
    if problems:
        print("warnings:\n  " + "\n  ".join(problems))
    if todo:
        repaint(args[0], todo)


if __name__ == "__main__":
    main()
