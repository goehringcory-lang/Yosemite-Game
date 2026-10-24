#!/usr/bin/env python3
"""Lays painted trees side by side on a ground colour, for looking at.

    python3 tools/art32/trees32/preview.py OUT.png NAME[:SEASON]...     # e.g. tree_black_oak_a:fall
    python3 tools/art32/trees32/preview.py --zoom 3 OUT.png NAME...
    python3 tools/art32/trees32/preview.py --old OUT.png NAME...  # the sprites in assets/, as they are
"""
from __future__ import annotations

import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)


def main() -> None:
    args = sys.argv[1:]
    zoom = 1
    old = False
    while args and args[0].startswith("--"):
        if args[0] == "--zoom":
            zoom = int(args[1])
            args = args[2:]
        elif args[0] == "--old":
            old = True
            args = args[1:]
    out, names = args[0], args[1:]
    import paint
    ims = []
    for spec in names:
        name, _, season = spec.partition(":")
        if old:
            folder = paint.SPECIES[name][0]
            path = os.path.join(paint.ROOT, folder + (f"seasons/{name}_{season}.png" if season else name + ".png"))
            if season:
                path = os.path.join(paint.ROOT, paint.A + f"seasons/{name}_{season}.png")
            ims.append(Image.open(path).convert("RGBA"))
        else:
            ims.append(Image.fromarray(paint.render(name, season or None), "RGBA"))
    gap = 12
    W = sum(i.width for i in ims) + gap * (len(ims) + 1)
    H = max(i.height for i in ims) + gap * 2
    sheet = Image.new("RGBA", (W, H), (86, 112, 62, 255))
    x = gap
    for im in ims:
        sheet.alpha_composite(im, (x, H - gap - im.height))
        x += im.width + gap
    if zoom > 1:
        sheet = sheet.resize((W * zoom, H * zoom), Image.NEAREST)
    sheet.save(out)
    print("wrote", out, sheet.size)


if __name__ == "__main__":
    main()
