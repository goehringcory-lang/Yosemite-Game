"""The Valley Days palette: 46 colors drawn from Yosemite's own tones.

Every asset is mapped onto this one table, so a granite wall, a pine, the
river and a lantern all share the same family of colors. Ramps run dark to
light and the light always comes from the upper left (golden-hour sun low in
the southwest), so a lit edge steps one color up its ramp and a shaded edge
steps one down.

    python3 tools/art32/palette.py     # writes the .gpl, the swatch PNG, and checks the size
"""
from __future__ import annotations

import os
import sys

from PIL import Image

# name -> list of hex colors, dark to light.
RAMPS: dict[str, list[str]] = {
    # Half Dome, El Capitan, the Valley's cliffs: cool to warm granite.
    "granite": ["2b2a30", "47464d", "6a6a70", "93918f", "bdb8ae", "e4ddcc"],
    # Sandstone, trails, talus, cabin plaster: warm tans.
    "tan": ["5e4a38", "86694b", "b0925f", "d6bd88"],
    # Ponderosa and incense cedar, shaded forest floor.
    "pine": ["12291d", "1d3f2b", "2c5c37", "437f45"],
    # Valley meadows in June.
    "meadow": ["5c8f3c", "84b04a", "aecb62", "d3e48a"],
    # Black oak, dry grass, aspen in fall, the lantern glow.
    "oak": ["7e531c", "ad7a22", "d8a63b", "f1cf6a"],
    # Bark, cabin wood, soil.
    "bark": ["2a1b14", "47301f", "6b4829", "92693d"],
    # The Merced and Bridalveil, deep to foam.
    "merced": ["142f47", "235679", "3a86a8", "63b3c6", "9fd8d9", "d6f1ee"],
    # Alpenglow, firefall, sunset on the rim: golden-hour amber.
    "amber": ["a84a1c", "d9772a", "f7a64a", "ffd48a"],
    # Wildflowers and the few accents: lupine, shooting star, poppy, snow.
    "accent": ["6f5aa6", "d47a9b", "b3362b", "f5eee0"],
    # Night: the shadow color, never pure black.
    "night": ["15141c", "2d3050"],
}

# Which ramp reads as "shadow-cast" for a given ramp, used by the light pass.
SHADOW_OF = {
    "granite": "night", "tan": "bark", "pine": "night", "meadow": "pine",
    "oak": "bark", "bark": "night", "merced": "night", "amber": "bark",
    "accent": "night", "night": "night",
}


def _rgb(h: str) -> tuple[int, int, int]:
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


COLORS: list[tuple[int, int, int]] = []
RAMP_OF: list[tuple[str, int]] = []  # color index -> (ramp, step)
for _name, _hexes in RAMPS.items():
    for _i, _h in enumerate(_hexes):
        COLORS.append(_rgb(_h))
        RAMP_OF.append((_name, _i))
assert 32 <= len(COLORS) <= 48, len(COLORS)


def _lab(rgb: tuple[int, int, int]) -> tuple[float, float, float]:
    def lin(c: float) -> float:
        c /= 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (lin(c) for c in rgb)
    x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883

    def f(t: float) -> float:
        return t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116
    fx, fy, fz = f(x), f(y), f(z)
    return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)


LABS = [_lab(c) for c in COLORS]
_CACHE: dict[tuple[int, int, int], int] = {}


def nearest(rgb: tuple[int, int, int]) -> int:
    """Index of the palette color closest to rgb (CIE Lab distance)."""
    hit = _CACHE.get(rgb)
    if hit is not None:
        return hit
    lab = _lab(rgb)
    best, best_d = 0, 1e18
    for i, p in enumerate(LABS):
        d = (lab[0] - p[0]) ** 2 * 1.2 + (lab[1] - p[1]) ** 2 + (lab[2] - p[2]) ** 2
        if d < best_d:
            best, best_d = i, d
    _CACHE[rgb] = best
    return best


def step(index: int, delta: int) -> int:
    """The color delta steps up (+) or down (-) the same ramp, clamped."""
    ramp, i = RAMP_OF[index]
    members = [k for k, (r, _s) in enumerate(RAMP_OF) if r == ramp]
    return members[max(0, min(len(members) - 1, i + delta))]


def write_gpl(path: str) -> None:
    with open(path, "w") as f:
        f.write("GIMP Palette\nName: Valley Days (Yosemite)\nColumns: 8\n#\n")
        for (r, g, b), (ramp, i) in zip(COLORS, RAMP_OF):
            f.write(f"{r:3d} {g:3d} {b:3d}\t{ramp} {i + 1}\n")


def write_swatch(path: str) -> None:
    cell = 16
    cols = 8
    rows = (len(COLORS) + cols - 1) // cols
    img = Image.new("RGBA", (cols * cell, rows * cell), (0, 0, 0, 0))
    for i, c in enumerate(COLORS):
        for y in range(cell):
            for x in range(cell):
                img.putpixel(((i % cols) * cell + x, (i // cols) * cell + y), (*c, 255))
    img.save(path)


if __name__ == "__main__":
    root = os.path.dirname(os.path.abspath(__file__))
    write_gpl(os.path.join(root, "valley_days.gpl"))
    write_swatch(os.path.join(root, "valley_days_palette.png"))
    print(len(COLORS), "colors")
    sys.exit(0)
