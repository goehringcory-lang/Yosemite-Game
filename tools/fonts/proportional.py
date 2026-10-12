"""Makes DotGothic16's Latin letters proportional, the way pixel fonts set them.

    pip install fonttools
    python3 tools/fonts/proportional.py

DotGothic16 is a Japanese dot font: every Latin letter sits in the same
half-width cell, so a narrow "i" or "l" floats in a wide gap ("Vi l lage").
This gives each Latin glyph the width of its ink plus the one-pixel gap the
font already leaves on each side of its widest letters (an "m" keeps its
width; an "i" closes up), narrows the space to five dots (digits keep one
width, for the clock), and writes the
result as "DotGothic16 Prop" (the SIL Open Font License allows modified
versions; the font declares no Reserved Font Name). Japanese glyphs are left
alone. Running it again gives the same file.
"""
import os

from fontTools.ttLib import TTFont

HERE = os.path.dirname(__file__)
SRC = os.path.join(HERE, "..", "..", "assets", "fonts", "DotGothic16-Regular.ttf")
OUT = os.path.join(HERE, "..", "..", "assets", "fonts", "DotGothic16Prop-Regular.ttf")
# The font draws on a 16-dot grid in 1000 units: one dot is 62.5 units.
DOT = 62.5
# The side gap of the widest letters ("m", "W"): half a dot each side.
SIDE = 28
SPACE = round(5 * DOT)
# What gets closed up: Basic Latin, Latin-1, Latin Extended-A and the
# general punctuation the game uses (dashes, quotes, bullets, ellipsis, ‹ ›).
RANGES = [(0x21, 0x7E), (0xA1, 0x17F), (0x2010, 0x203A)]
# Digits keep their full, equal width (tabular figures), so the clock and
# counts line up and a "1" never crowds the colon after it ("1:00").
TABULAR = set(range(0x30, 0x3A))
# Colons and semicolons get a whole dot each side, so "11:00" stays apart.
ROOMY = {0x3A: 62, 0x3B: 62}
NAME = "DotGothic16 Prop"


def main() -> None:
    font = TTFont(SRC)
    cmap = font.getBestCmap()
    glyf = font["glyf"]
    hmtx = font["hmtx"]
    done = set()
    for lo, hi in RANGES:
        for code in range(lo, hi + 1):
            name = cmap.get(code)
            if code in TABULAR or name is None or name in done:
                continue
            done.add(name)
            glyph = glyf[name]
            adv, _ = hmtx[name]
            if adv != 500 or glyph.numberOfContours == 0:
                continue  # full-width or blank: leave it
            if glyph.isComposite():
                glyph.expand(glyf)
                continue
            side = ROOMY.get(code, SIDE)
            shift = side - glyph.xMin
            coords = glyph.coordinates
            for i in range(len(coords)):
                x, y = coords[i]
                coords[i] = (x + shift, y)
            glyph.recalcBounds(glyf)
            hmtx[name] = (glyph.xMax + side, glyph.xMin)
    for code in (0x20, 0xA0):
        if code in cmap:
            hmtx[cmap[code]] = (SPACE, 0)
    for record in font["name"].names:
        if record.nameID in (1, 4, 16):
            record.string = NAME
        elif record.nameID == 6:
            record.string = NAME.replace(" ", "") + "-Regular"
        elif record.nameID == 3:
            record.string = NAME + " Regular"
    font["post"].isFixedPitch = 0
    font["OS/2"].panose.bProportion = 0
    font.save(OUT)
    print("Wrote %s" % OUT)


if __name__ == "__main__":
    main()
