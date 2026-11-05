#!/usr/bin/env python3
"""Writes where every room's windows and their painted daylight are, for
RoomWindows (scripts/world/room_windows.gd), into data/park/room_windows.json.

The room pictures are painted with the noon light baked in: daylight through
each window falls as a bright shaft across the floor (materials.window_shaft)
and the glass shows the view by day. RoomWindows turns that light with the
clock: it takes the shafts away at night, warms and stretches them at either
end of the day, and darkens the glass to dusk and stars. It needs to know
where the painters put them, so this runs the painters (park_rooms.py and the
Ahwahnee's rooms.py) without saving anything and notes each window and shaft
they paint, in the picture's pixels:

    python3 tools/hubs/interiors32/room_windows.py

Run it again whenever a room's windows change.
"""
from __future__ import annotations

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "ahwahnee32"))
sys.path.insert(0, HERE)

import decor as D  # noqa: E402
import materials as M  # noqa: E402
import park_rooms as PR  # noqa: E402
import rooms as AR  # noqa: E402
from kit import ROOT  # noqa: E402

OUT = os.path.join(ROOT, "data", "park", "room_windows.json")

_found: dict = {}


def _record() -> None:
    """Wraps the painters' window and shaft calls so each one is noted in
    _found as it is painted."""
    shaft, sash, tall, lancet = M.window_shaft, D.window, M.tall_window, D.lancet

    def window_shaft(delta, x, w, y_floor, length, strength=0.9, slant=0.5):
        _found["shafts"].append({"x": int(x), "w": int(w), "y": int(y_floor), "len": int(length),
            "strength": round(float(strength), 3), "slant": round(float(slant), 3)})
        return shaft(delta, x, w, y_floor, length, strength, slant)

    def window(cv, x, y, w, h, *args, **kw):
        _found["panes"].append({"x": int(x), "y": int(y), "w": int(w), "h": int(h), "kind": "sash"})
        return sash(cv, x, y, w, h, *args, **kw)

    def tall_window(cv, x, y, w, h, view, transom, *args, **kw):
        _found["panes"].append({"x": int(x), "y": int(y + transom), "w": int(w), "h": int(h - transom), "kind": "tall"})
        return tall(cv, x, y, w, h, view, transom, *args, **kw)

    def lancet_window(cv, x, y, w, h, *args, **kw):
        _found["panes"].append({"x": int(x), "y": int(y), "w": int(w), "h": int(h), "kind": "stained"})
        return lancet(cv, x, y, w, h, *args, **kw)

    M.window_shaft, D.window, M.tall_window, D.lancet = window_shaft, window, tall_window, lancet_window


def _note(room_id: str, paint) -> dict | None:
    _found.clear()
    _found.update({"panes": [], "shafts": []})
    paint()
    if not _found["panes"] and not _found["shafts"]:
        return None
    return {"panes": list(_found["panes"]), "shafts": list(_found["shafts"])}


def main() -> None:
    _record()
    rooms: dict[str, dict] = {}
    jobs = [(r, lambda r=r: PR.paint(r)) for r in PR.room_ids()]
    jobs += [(k, lambda s=s: PR.paint_spec(s)) for k, s in PR.CURRY.items()]
    jobs += [(k, fn) for k, fn in AR.ROOMS.items()]
    for room_id, paint in jobs:
        found = _note(room_id, paint)
        if found:
            rooms[room_id] = found
            print(room_id, len(found["panes"]), "windows,", len(found["shafts"]), "shafts")
    with open(OUT, "w") as f:
        json.dump(rooms, f, indent=1, sort_keys=True)
        f.write("\n")
    print("wrote", os.path.relpath(OUT, ROOT))


if __name__ == "__main__":
    main()
