#!/usr/bin/env python3
"""Notes where each cliff wall painting meets the sky along its top edge,
for SeamBackdrop (scripts/world/seam_backdrop.gd): above a map whose cliffs
stand against the sky, the sky goes on up past the map's top, not woods.
Reading the paintings in the game would mean fetching them back from the
graphics card, which stalls a frame.

    python3 tools/seams/wall_skies.py      # writes data/park/wall_skies.json
"""
import glob
import json
import os
import re

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "data", "park", "wall_skies.json")


def is_sky(px) -> bool:
    r, g, b, a = px
    return a > 230 and b > r + 20 and b > g


def main() -> None:
    skies = {}
    for path in sorted(glob.glob(os.path.join(ROOT, "scenes", "regions", "*.tscn"))):
        text = open(path).read()
        for m in re.finditer(r'\[node name="(\w*Wall)" type="Sprite2D" parent="\."[^\n]*\n((?:[^\[\n][^\n]*\n)*)', text):
            tex = re.search(r'texture = ExtResource\("([^"]+)"\)', m.group(2))
            if not tex:
                continue
            res = re.search(r'\[ext_resource type="Texture2D"[^\n]*path="(res://[^"]+)"[^\n]*id="%s"\]' % re.escape(tex.group(1)), text)
            if not res or res.group(1) in skies:
                continue
            image = Image.open(os.path.join(ROOT, res.group(1)[len("res://"):])).convert("RGBA")
            spans = []
            start = None
            sky = None
            for x in range(image.width):
                px = image.getpixel((x, 0))
                if is_sky(px):
                    if start is None:
                        start = x
                        sky = px
                elif start is not None:
                    spans.append([start, x])
                    start = None
            if start is not None:
                spans.append([start, image.width])
            if spans:
                skies[res.group(1)] = {"color": "#%02x%02x%02x" % sky[:3], "spans": spans}
    with open(OUT, "w") as f:
        json.dump(skies, f, indent="\t")
        f.write("\n")
    print("wrote %d walls to %s" % (len(skies), OUT))


if __name__ == "__main__":
    main()
