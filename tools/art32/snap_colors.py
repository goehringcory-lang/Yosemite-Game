#!/usr/bin/env python3
"""Snaps the color literals in the UI and climbing code to the palette, so
menus and the code-drawn climbing art use the same colors as the sprites.
Alpha is kept; HDR values (above 1, used for glow) are left alone.

Applied once (see git history); safe to run again, since snapped colors
snap to themselves.

    python3 tools/art32/snap_colors.py
"""
from __future__ import annotations

import glob
import os
import re

import palette as P

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FILES = [
    "scripts/ui/*.gd", "scripts/climb/*.gd", "scripts/climb/art/*.gd", "assets/ui/theme.tres",
    "scripts/story/journal.gd", "scripts/story/dialogue_box.gd", "scripts/story/register_pages.gd",
    "scripts/story/hearts.gd", "scripts/story/quest_marker.gd", "scripts/story/station.gd",
    "scripts/story/chuckah.gd",
]
NUM = r"-?\d*\.?\d+"


def snap(rgb: tuple[float, float, float]) -> tuple[float, float, float]:
    r, g, b = (round(max(0.0, min(1.0, c)) * 255) for c in rgb)
    pr, pg, pb = P.COLORS[P.nearest((r, g, b))]
    return pr / 255, pg / 255, pb / 255


def fmt(v: float) -> str:
    return f"{v:.3f}".rstrip("0").rstrip(".") or "0"


def fix(text: str) -> str:
    def hexc(m: re.Match) -> str:
        h = m.group(2)
        if len(h) not in (6, 8):
            return m.group(0)
        rgb = tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
        pr, pg, pb = snap(rgb)
        out = "%02x%02x%02x" % (round(pr * 255), round(pg * 255), round(pb * 255))
        return f'{m.group(1)}"{out}{h[6:]}")'

    def flt(m: re.Match) -> str:
        parts = [float(x) for x in re.findall(NUM, m.group(2))]
        if len(parts) not in (3, 4) or any(p > 1.0 or p < 0.0 for p in parts[:3]):
            return m.group(0)
        pr, pg, pb = snap(tuple(parts[:3]))
        vals = [fmt(pr), fmt(pg), fmt(pb)] + ([fmt(parts[3])] if len(parts) == 4 else [])
        return f"{m.group(1)}({', '.join(vals)})"

    text = re.sub(r'(Color\()"#?([0-9a-fA-F]{6,8})"\)', hexc, text)
    text = re.sub(r"(Color)\(((?:\s*" + NUM + r"\s*,){2,3}\s*" + NUM + r"\s*)\)", flt, text)
    return text


def main() -> None:
    n = 0
    for g in FILES:
        for p in glob.glob(os.path.join(ROOT, g)):
            s = open(p).read()
            t = fix(s)
            if t != s:
                open(p, "w").write(t)
                n += 1
    print("snapped colors in", n, "files")


if __name__ == "__main__":
    main()
