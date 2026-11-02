#!/usr/bin/env python3
"""Finds where each region's painted ground has water, so WaterSurface only
draws its reflections there (and not at all when no water is in view).

Writes data/park/water_cells.json: for each ground texture, the rectangles (in
texture pixels, on a CELL grid) that hold any pixel the water shader would
treat as water. Uses the same test as waterness() in
assets/shaders/water_surface.gdshader; keep the two in step.

Run after painting a ground: python3 tools/perf/water_cells.py
"""
import glob
import json
import os
import sys

import numpy as np
from PIL import Image

CELL = 32
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "data", "park", "water_cells.json")
GROUNDS = ["assets/sprites/**/ground_*.png"]


def water_mask(path):
    im = np.asarray(Image.open(path).convert("RGBA"), dtype=np.float32) / 255.0
    r, g, b, a = im[..., 0], im[..., 1], im[..., 2], im[..., 3]
    w1 = np.clip((b - g) * 10.0, 0.0, 1.0) * (g >= r)
    ratio = b / np.maximum(g, 0.001)
    w2 = np.clip((ratio - 0.8) * 8.0, 0.0, 1.0) * (g >= r + 0.06) * (b >= r + 0.04)
    return (a > 0.5) & (np.maximum(w1, w2) > 0.5)


def cells(mask):
    h, w = mask.shape
    rows, cols = -(-h // CELL), -(-w // CELL)
    padded = np.zeros((rows * CELL, cols * CELL), dtype=bool)
    padded[:h, :w] = mask
    return padded.reshape(rows, CELL, cols, CELL).any(axis=(1, 3))


def rects(grid):
    """Runs of water cells along each row, joined downward while a run
    below spans the same columns. Returns [x, y, w, h] in texture pixels."""
    open_runs = {}
    out = []
    for y in range(grid.shape[0]):
        runs = []
        x = 0
        row = grid[y]
        while x < len(row):
            if row[x]:
                start = x
                while x < len(row) and row[x]:
                    x += 1
                runs.append((start, x))
            else:
                x += 1
        still = {}
        for run in runs:
            if run in open_runs:
                still[run] = open_runs[run]
            else:
                still[run] = y
        for run, top in open_runs.items():
            if run not in still:
                out.append([run[0] * CELL, top * CELL, (run[1] - run[0]) * CELL, (y - top) * CELL])
        open_runs = still
    for run, top in open_runs.items():
        out.append([run[0] * CELL, top * CELL, (run[1] - run[0]) * CELL, (grid.shape[0] - top) * CELL])
    out.sort(key=lambda r: (r[1], r[0]))
    return out


def main():
    table = {}
    for pattern in GROUNDS:
        for path in sorted(glob.glob(os.path.join(ROOT, pattern), recursive=True)):
            rel = os.path.relpath(path, ROOT).replace(os.sep, "/")
            table["res://" + rel] = rects(cells(water_mask(path)))
    with open(OUT, "w") as f:
        json.dump({"cell": CELL, "grounds": table}, f, indent=None, separators=(",", ":"))
        f.write("\n")
    with_water = sum(1 for v in table.values() if v)
    print("wrote %s: %d grounds, %d with water" % (os.path.relpath(OUT, ROOT), len(table), with_water), file=sys.stderr)


if __name__ == "__main__":
    main()
