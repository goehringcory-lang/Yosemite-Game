#!/usr/bin/env python3
"""Upgrades freshly generated 16px art to the 32px palette art, in place.

The pixel-art generators under tools/ (npcgen, hubs, mapgen, plants, ui) still
draw at the original 16px scale and write straight into assets/. Run them
through tools/art32/regen.sh, or run this afterwards: it finds every PNG under
assets/ that is now the same size as its 16px original (so, freshly
generated), and runs it through the same pass `build.py` uses.

    python3 tools/art32/upgrade.py            # every freshly generated image
    python3 tools/art32/upgrade.py FILE...    # just these

A sheet added after the 32px upgrade has no 16px original. Name it on the
command line and it is upgraded while it is still a 16px-high row of icons.

    python3 tools/art32/upgrade.py --fresh FILE...

says the named files were all just drawn at 16px (a hub builder wrote them),
so each is upgraded whatever its size: a new building, or one redrawn at a
new size. Don't name a file twice: it would be doubled again.
"""
from __future__ import annotations

import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build  # noqa: E402
import passes  # noqa: E402
import pixel32 as K  # noqa: E402


def original_sizes() -> dict[str, tuple[int, int]]:
    sizes = {}
    for path in build.base_files():
        sizes[path] = build.read_base(path).shape[1::-1]
    return sizes


def main() -> None:
    args = sys.argv[1:]
    if args and args[0] == "--fresh":
        n = 0
        for a in args[1:]:
            path = os.path.relpath(os.path.abspath(a), build.ROOT)
            cat = build.category_of(path)
            if cat is None:
                continue
            full = os.path.join(build.ROOT, path)
            K.save(passes.run(cat, path, np.array(Image.open(full).convert("RGBA"))), full)
            n += 1
        print("upgraded", n, "images")
        return
    wanted = [os.path.relpath(os.path.abspath(a), build.ROOT) for a in args]
    sizes = original_sizes()
    for path in wanted:
        full = os.path.join(build.ROOT, path)
        if path not in sizes and build.category_of(path) and os.path.exists(full):
            w, h = Image.open(full).size
            if h == 16:
                sizes[path] = (w, h)
    n = 0
    for path, size in sizes.items():
        if wanted and path not in wanted:
            continue
        cat = build.category_of(path)
        full = os.path.join(build.ROOT, path)
        if cat is None or not os.path.exists(full):
            continue
        now = Image.open(full).size
        # The press book's sheet grows a row at a time as plants are added,
        # so for it the width alone says whether it's freshly drawn.
        fresh = now[0] == size[0] if path == "assets/sprites/plants.png" else now == size
        if not fresh:  # already 32px (or resized): leave it
            continue
        K.save(passes.run(cat, path, np.array(Image.open(full).convert("RGBA"))), full)
        n += 1
    print("upgraded", n, "images")


if __name__ == "__main__":
    main()
