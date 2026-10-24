#!/usr/bin/env python3
"""Paints the insides of the park's buildings natively at 32px, in the
Valley Days palette, over the art the 16px builders drew for them: every room
in tools/hubs/build_interiors.gd but the Ahwahnee's six (ahwahnee32/paint.py
paints those), the Camp Curry Store and the Mountain Shop, and the furniture
they share (furniture.py, fittings.py, goods.py). tools/hubs/rebuild_interiors.sh
runs it last; on its own:

    python3 tools/hubs/interiors32/paint.py              # every room and piece
    python3 tools/hubs/interiors32/paint.py rooms        # just the rooms
    python3 tools/hubs/interiors32/paint.py props        # just the furniture
    python3 tools/hubs/interiors32/paint.py preview DIR  # each room with its furniture, as the scene places it

Rebuilding Curry Village (build_curry.tscn) redraws the Store and the Shop
at 16px; run this again after it.

Furniture is painted into the canvas the builder already made for it, so the
scenes' collision shapes and sprite offsets stay right.
"""
from __future__ import annotations

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "ahwahnee32"))
sys.path.insert(0, HERE)

from kit import ROOT  # noqa: E402
import park_rooms as PR  # noqa: E402

OUT = os.path.join(ROOT, "assets", "sprites", "interiors")


def paint_rooms() -> None:
    for room_id in PR.room_ids():
        PR.paint(room_id).save(os.path.join(OUT, room_id + ".png"))
        print("painted", room_id)
    PR.paint_curry()


def paint_props() -> None:
    import fittings
    import furniture
    import goods
    print("painted", furniture.paint_all() + fittings.paint_all() + goods.paint_all(), "pieces")


def preview(out_dir: str) -> None:
    from PIL import Image
    import rooms as AR
    os.makedirs(out_dir, exist_ok=True)
    pictures = {r: os.path.join(OUT, r + ".png") for r in PR.room_ids()}
    pictures.update({k: os.path.join(ROOT, v["out"]) for k, v in PR.CURRY.items()})
    for room_id, path in pictures.items():
        base = Image.open(path).convert("RGBA")
        for p in sorted(AR.scene_props(room_id), key=lambda p: p["y"]):
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
