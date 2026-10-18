#!/usr/bin/env python3
"""Builds the 32px art from the original 16px art.

The 16px originals stay in git history (BASE_REV); this reads each one from
there, so the build is repeatable and never doubles an already-doubled sheet.
Every asset belongs to one category (see CATEGORIES), in the order the art is
upgraded, and each category has its own pass in passes.py.

    python3 tools/art32/build.py                 # everything
    python3 tools/art32/build.py characters      # one category
    python3 tools/art32/build.py --list          # what falls in each category
"""
from __future__ import annotations

import fnmatch
import io
import os
import subprocess
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import passes  # noqa: E402
import pixel32 as K  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
# The last commit with the 16px art.
BASE_REV = "293679d"

# category -> path globs (relative to the project), in upgrade order.
CATEGORIES: dict[str, list[str]] = {
    "characters": [
        "assets/sprites/player.png",
        "assets/sprites/npcs/*.png",
        "assets/sprites/critters.png",
    ],
    "terrain": [
        "assets/sprites/tiles.png",
        "assets/sprites/terrain.png",
        "assets/map/ground/*.png",
    ],
    "props": [
        "assets/sprites/flora.png",
        "assets/sprites/flora_glow.png",
        "assets/sprites/plants.png",
        "assets/sprites/oak_*.png",
        "assets/sprites/tent.png",
        "assets/sprites/blocker.png",
        "assets/sprites/items.png",
        "assets/sprites/food_items.png",
        "assets/sprites/wild_items.png",
        "assets/sprites/meal_items.png",
        "assets/sprites/store_items.png",
        "assets/sprites/story_items.png",
        "assets/sprites/side_quest_items.png",
        "assets/sprites/info_sign.png",
        "assets/sprites/map_kiosk.png",
        "assets/sprites/trailhead.png",
    ],
    "structures": [
        "assets/sprites/buildings/*.png",
        "assets/sprites/hub_buildings/*.png",
        "assets/sprites/curry/*.png",
        "assets/sprites/curry/interiors/*.png",
        "assets/sprites/ahwahnee/*.png",
        "assets/sprites/ahwahnee/seasons/*.png",
        "assets/sprites/cave/*.png",
        "assets/sprites/lamon/*.png",
        "assets/sprites/glacier/*.png",
    ],
    # Menus keep their layout, so the pictures keep their size and only
    # take on the palette; the title painting is drawn at the 32px grade.
    "ui": [
        "assets/ui/*.png",
        "assets/sprites/portraits/*.png",
        "assets/sprites/gear/*.png",
    ],
    # The park and area maps are looked at on the map screens; the relief
    # map is data (heights in the red channel), so it is left as it is.
    "maps": [
        "assets/map/park_map.png",
        "assets/map/areas/[!y]*.png",
        "assets/map/areas/yosemite_valley.png",
    ],
}
SKIP_SUFFIX = (".import",)


def base_files() -> list[str]:
    out = subprocess.check_output(["git", "ls-tree", "-r", "--name-only", BASE_REV, "assets/"], cwd=ROOT, text=True)
    return [p for p in out.splitlines() if p.endswith(".png")]


def category_of(path: str) -> str | None:
    for cat, globs in CATEGORIES.items():
        if any(fnmatch.fnmatchcase(path, g) for g in globs):
            return cat
    return None


def read_base(path: str) -> np.ndarray:
    blob = subprocess.check_output(["git", "show", f"{BASE_REV}:{path}"], cwd=ROOT)
    return np.array(Image.open(io.BytesIO(blob)).convert("RGBA"))


def build(only: list[str]) -> None:
    done = 0
    for path in base_files():
        cat = category_of(path)
        if cat is None or (only and cat not in only):
            continue
        out = passes.run(cat, path, read_base(path))
        K.save(out, os.path.join(ROOT, path))
        done += 1
    print(f"built {done} images")


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if "--list" in sys.argv:
        for p in base_files():
            print(f"{category_of(p) or '-':12s} {p}")
        sys.exit(0)
    for a in args:
        if a not in CATEGORIES:
            sys.exit(f"unknown category {a}; choose from {', '.join(CATEGORIES)}")
    build(args)
