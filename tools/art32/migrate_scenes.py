#!/usr/bin/env python3
"""One-time migration of the world's scenes and resources from the 16px grid
to the 32px grid: every position, offset, size, collision shape, radius and
atlas region in pixels is doubled. Tile cells (tile_map_data) are in tiles, so
they stay as they are; the TileSet's tile_size and its atlases change instead.

Already applied (see git history). It is not safe to run twice.

    python3 tools/art32/migrate_scenes.py
"""
from __future__ import annotations

import glob
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

# Scene files (pixel quantities in world space).
SCENE_GLOBS = [
    "scenes/regions/*.tscn", "scenes/regions/generated/*.tscn", "scenes/objects/*.tscn",
    "scenes/story/*.tscn", "scenes/story/content/*.tscn", "scenes/player/*.tscn",
    "scenes/world/*.tscn", "assets/sprites/player_frames.tres",
]
# Data resources that hold atlas regions of sheets that were doubled.
DATA_GLOBS = ["data/**/*.tres"]

VECTOR_PROPS = ("position", "offset", "size", "area", "body_size", "reach_size", "region_rect", "region")
SCALAR_PROPS = ("radius", "wander_radius", "ground_inset")
NUM = r"-?\d+(?:\.\d+)?"


def dbl(token: str) -> str:
    v = float(token) * 2
    return str(int(v)) if v == int(v) else repr(round(v, 4)).rstrip("0")


def scale_args(args: str) -> str:
    return re.sub(NUM, lambda m: dbl(m.group(0)), args)


def migrate_scene(text: str) -> str:
    def vec(m: re.Match) -> str:
        return f"{m.group(1)} = {m.group(2)}({scale_args(m.group(3))})"

    text = re.sub(r"^(" + "|".join(VECTOR_PROPS) + r") = (Vector2|Rect2)\(([^)]*)\)", vec, text, flags=re.M)
    text = re.sub(r"^(" + "|".join(SCALAR_PROPS) + r") = (" + NUM + r")$",
                  lambda m: f"{m.group(1)} = {dbl(m.group(2))}", text, flags=re.M)
    return text


def migrate_data(text: str) -> str:
    return re.sub(r"^(region) = (Rect2)\(([^)]*)\)", lambda m: f"{m.group(1)} = {m.group(2)}({scale_args(m.group(3))})",
                  text, flags=re.M)


def migrate_tileset(text: str) -> str:
    text = re.sub(r"(texture_region_size = )Vector2i\((\d+), (\d+)\)",
                  lambda m: f"{m.group(1)}Vector2i({int(m.group(2)) * 2}, {int(m.group(3)) * 2})", text)
    text = re.sub(r"(texture_origin = )Vector2i\(([^)]*)\)", lambda m: f"{m.group(1)}Vector2i({scale_args(m.group(2))})", text)
    text = re.sub(r"(/y_sort_origin = )(\d+)", lambda m: f"{m.group(1)}{int(m.group(2)) * 2}", text)
    text = re.sub(r"(polygon_\d+/points = PackedVector2Array\()([^)]*)\)",
                  lambda m: f"{m.group(1)}{scale_args(m.group(2))})", text)
    # sources without an explicit region size were 16x16; the TileSet itself 16x16
    text = text.replace('[resource]\n', '[resource]\ntile_size = Vector2i(32, 32)\n', 1)
    return text


def main() -> None:
    if "--force" not in sys.argv and os.path.exists(os.path.join(ROOT, "assets/tiles/.migrated32")):
        sys.exit("already migrated")
    n = 0
    for g in SCENE_GLOBS:
        for p in glob.glob(os.path.join(ROOT, g)):
            s = open(p).read()
            t = migrate_scene(s)
            if t != s:
                open(p, "w").write(t)
                n += 1
    for g in DATA_GLOBS:
        for p in glob.glob(os.path.join(ROOT, g), recursive=True):
            s = open(p).read()
            t = migrate_data(s)
            if t != s:
                open(p, "w").write(t)
                n += 1
    p = os.path.join(ROOT, "assets/tiles/world_tileset.tres")
    s = open(p).read()
    open(p, "w").write(migrate_tileset(s))
    open(os.path.join(ROOT, "assets/tiles/.migrated32"), "w").write("scenes and tileset are on the 32px grid\n")
    print("migrated", n, "files")


if __name__ == "__main__":
    main()
