#!/usr/bin/env python3
"""Notes how deep the painted sky runs down from the top of each cliff wall
painting, column by column, for SeamBackdrop (scripts/world/seam_backdrop.gd):
where the woods stand past a map's top edge, it lays forest floor over that
band of sky, so the woods meet the cliff tops instead of a strip of blue that
reads as a river. Reading the paintings in the game would mean fetching them
back from the graphics card, which stalls a frame.

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
            # [from x, to x, rows of sky down from the top] each, for runs
            # of columns with the same depth
            spans = []
            for x in range(image.width):
                depth = 0
                while depth < image.height and is_sky(image.getpixel((x, depth))):
                    depth += 1
                if depth == 0:
                    continue
                if spans and spans[-1][1] == x and spans[-1][2] == depth:
                    spans[-1][1] = x + 1
                else:
                    spans.append([x, x + 1, depth])
            if spans:
                skies[res.group(1)] = spans
    with open(OUT, "w") as f:
        f.write("{\n" + ",\n".join("\t%s: %s" % (json.dumps(k), json.dumps(v, separators=(",", ":"))) for k, v in skies.items()) + "\n}")
        f.write("\n")
    print("wrote %d walls to %s" % (len(skies), OUT))


if __name__ == "__main__":
    main()
