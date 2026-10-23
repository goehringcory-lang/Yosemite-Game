#!/usr/bin/env python3
"""Paints the Ahwahnee's six rooms and their furniture natively at 32px, in
the Valley Days palette, over the art the 16px interior builder drew for them.
tools/hubs/rebuild_interiors.sh runs it last; on its own:

    python3 tools/hubs/ahwahnee32/paint.py              # every room and piece
    python3 tools/hubs/ahwahnee32/paint.py rooms        # just the rooms
    python3 tools/hubs/ahwahnee32/paint.py props        # just the furniture
    python3 tools/hubs/ahwahnee32/paint.py preview DIR  # each room with its furniture, as the scene places it

Furniture is painted into the canvas the builder already made for it (so the
scene's collision and sprite offsets stay right), in the files named with an
"ahw" look in build_interiors.gd: sofa_ahw_red.png and the like.
"""
from __future__ import annotations

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from kit import ROOT, Canvas  # noqa: E402
import rooms as R  # noqa: E402

OUT = os.path.join(ROOT, "assets", "sprites", "interiors")


def paint_rooms() -> None:
    for room_id, fn in R.ROOMS.items():
        fn().save(os.path.join(OUT, room_id + ".png"))
        print("painted", room_id)


def paint_props() -> None:
    import props as PR
    from PIL import Image
    n = 0
    for name, fn in PR.PROPS.items():
        path = os.path.join(OUT, "props", name + ".png")
        if not os.path.exists(path):
            print("skipped", name, "(the builder hasn't drawn it)")
            continue
        w, h = Image.open(path).size
        cv = fn(w, h)
        assert (cv.w, cv.h) == (w, h), (name, cv.w, cv.h, w, h)
        cv.save(path)
        n += 1
    print("painted", n, "pieces")


def preview(out_dir: str) -> None:
    from PIL import Image
    os.makedirs(out_dir, exist_ok=True)
    for room_id in R.ROOMS:
        base = Image.open(os.path.join(OUT, room_id + ".png")).convert("RGBA")
        items = sorted(R.scene_props(room_id), key=lambda p: p["y"])
        for p in items:
            im = Image.open(os.path.join(ROOT, p["tex"])).convert("RGBA")
            fw = im.width // p.get("frames", 1)
            im = im.crop((0, 0, fw, im.height))
            base.alpha_composite(im, (int(p["x"] - fw / 2), int(p["y"] - im.height)))
        base.save(os.path.join(out_dir, room_id + ".png"))
        print("preview", room_id)


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "all"
    if what in ("all", "rooms"):
        paint_rooms()
    if what in ("all", "props"):
        paint_props()
    if what == "preview":
        preview(sys.argv[2])
