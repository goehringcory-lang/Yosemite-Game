#!/usr/bin/env python3
"""Moves a scene a 16px hub builder just wrote onto the 32px grid.

The hub builders (tools/hubs/) still lay scenes out in 16px pixels, so a
rebuilt scene needs the same doubling migrate_scenes.py gave every scene once.
One difference: a sprite's offset is worked out from its texture's height, and
a texture the builder didn't redraw (the info sign, Curry Village's props) is
already 32px, so its offset is already right and is left as it is.

    python3 tools/art32/migrate_built.py SCENE --fresh PNG...

The PNGs after --fresh are the ones the builder drew (and upgrade.py has
since doubled); every other texture counts as already 32px.
"""
from __future__ import annotations

import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import migrate_scenes as M  # noqa: E402

ROOT = M.ROOT


def main() -> None:
    args = sys.argv[1:]
    if not args or "--fresh" not in args:
        sys.exit(__doc__)
    i = args.index("--fresh")
    scenes, fresh = args[:i], {"res://" + os.path.relpath(os.path.abspath(p), ROOT) for p in args[i + 1:]}
    for scene in scenes:
        text = open(scene).read()
        paths = dict(re.findall(r'\[ext_resource type="Texture2D"[^\]]*path="([^"]+)" id="([^"]+)"\]', text))
        ids = {v: k for k, v in paths.items()}
        out = []
        foreign = False
        for line in M.migrate_scene(text).split("\n"):
            if line.startswith("["):
                foreign = False
            m = re.match(r'texture = ExtResource\("([^"]+)"\)', line)
            if m:
                foreign = ids.get(m.group(1), "") not in fresh
            m = re.match(r"offset = Vector2\(([^)]*)\)", line)
            if m and foreign:
                # undo the doubling: half of each is the offset the builder set
                x, y = (float(v) / 4 for v in m.group(1).split(","))
                line = "offset = Vector2(%s, %s)" % (M.dbl(str(x)), M.dbl(str(y)))
            out.append(line)
        open(scene, "w").write("\n".join(out))
        print("migrated", scene)


if __name__ == "__main__":
    main()
