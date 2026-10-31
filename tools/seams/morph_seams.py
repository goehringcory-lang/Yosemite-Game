#!/usr/bin/env python3
"""Bends the rivers, roads, trails and creeks near the edges of the Valley
floor areas so they meet the same river or road on the next area over a
seam (see scripts/world/seam.gd), instead of missing it by a few tiles.

The areas were drawn one at a time, so at an edge the Merced on one map may
run 200 pixels north of the Merced on the next. For each seam this finds
the rivers, roads, trails and creeks crossing the edge on both sides, pairs
the ones that are the same feature (same kind, in the same order along the
edge, not too far apart), and agrees where each pair meets: where the
hand-made area (the Village, Curry Village, the Ahwahnee) has it, or half
way between two built ones. Then, in a band of BAND tiles along the edge
of each built area, the feature bends from where it was to where it meets,
tile column by tile column. Cliffs and talus never move; features with no
partner across the seam are left as they are.

It rewrites, in place:
  * the Ground tiles in each band, and the Blocker tiles round them (water
    blocks the edge of walkable ground, as the builders do),
  * trees, rocks and other things standing on the new water or road, and
    the wild clutter there, which are taken up,
  * the ground picture over each band, from tools/art32/ground32/paint.py
    (feathered into the old picture at the band's inner side), and its
    normal map (tools/normals/normals.py).

    godot --headless --path . res://tools/seams/export_seams.tscn -- /tmp/seams.json
    python3 tools/seams/morph_seams.py /tmp/seams.json --plan        # what it would do
    python3 tools/seams/morph_seams.py /tmp/seams.json               # do it (needs GODOT)

Run it on the committed maps once: a second run finds the features already
meeting and changes nothing. Needs Pillow and numpy.
"""

from __future__ import annotations

import base64
import json
import os
import re
import struct
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TILE = 32
TERRAIN_SOURCE = 1
BLOCK_SOURCE = 3
# How many tiles in from its edge an area's features bend (the two tiles
# the maps overlap by included): at least BAND, and more for a feature that
# has further to go, so it bends no steeper than one tile across for
# STEEP tiles in.
BAND = 8
MOST_BAND = 26
STEEP = 1.6
OVERLAP = 2
# Roads and trails this close (in tiles) are left alone: the seam's nudge
# (data/park/seam_nudges.json) lines them up to the pixel, and moving one by
# a tile only kinks the painted road.
WAY_SLACK = 2.0
# Features further apart than this along the edge aren't the same one.
FARTHEST = 22

# Ground rows (tools/mapgen/terrain.gd)
CLIFF, TALUS, SCREE, RIVER, LAKE, CREEK, FALLS, SAND = 8, 9, 10, 11, 12, 13, 14, 15
ROAD, PARKING, BRIDGE, TRAIL, PAVED = 16, 17, 18, 19, 20
SOLID = {CLIFF, TALUS, SCREE, RIVER, LAKE, FALLS}
# What never moves: the walls and what falls from them.
FIXED = {CLIFF, TALUS, SCREE, FALLS}
## Bridges and roads stay dry: water bent across one runs under it.
KEEP_DRY = {ROAD, BRIDGE, PAVED}
# The features that bend, by class: a river with its sandy banks, a road, a
# trail or path, a creek.
CLASSES = {
    "river": {RIVER, LAKE, SAND},
    "way": {ROAD, PARKING, BRIDGE, TRAIL, PAVED},
    "creek": {CREEK},
}
FEATURE = set().union(*CLASSES.values())
# Must contain one of these to count (a strip of beach alone isn't a river).
CORE = {"river": {RIVER, LAKE}, "way": {ROAD, BRIDGE, TRAIL, PAVED}, "creek": {CREEK}}

# The areas the Valley floor builder makes (tools/hubs/build_valley_floor.gd);
# the others are drawn by hand and keep their edges.
BUILT = {"el_capitan_meadow", "tunnel_view", "happy_isles", "mirror_lake", "leidig_meadow",
         "four_mile_trailhead", "bridalveil_fall", "housekeeping_camp", "ahwahnee_meadow",
         "upper_pines", "tenaya_creek", "crows_camp", "big_oak_flat_junction", "crane_flat"}


# --- scene files ------------------------------------------------------------

def scene_path(area: str) -> str:
    return os.path.join(ROOT, "scenes", "regions", area + ".tscn")


def layer_match(text: str, name: str):
    return re.search(r'(\[node name="%s" type="TileMapLayer"[^\n]*\n(?:[^\[\n][^\n]*\n)*?tile_map_data = PackedByteArray\(")([^"]*)("\))' % name, text)


def read_layer(text: str, name: str) -> dict:
    m = layer_match(text, name)
    cells = {}
    if m is None:
        return cells
    raw = base64.b64decode(m.group(2))
    for i in range((len(raw) - 2) // 12):
        x, y, src, ax, ay, alt = struct.unpack_from("<hhHHHH", raw, 2 + i * 12)
        cells[(x, y)] = (src, ax, ay, alt)
    return cells


def write_layer(text: str, name: str, cells: dict) -> str:
    m = layer_match(text, name)
    out = bytearray(b"\x00\x00")
    for (x, y), (src, ax, ay, alt) in sorted(cells.items(), key=lambda kv: (kv[0][1], kv[0][0])):
        out += struct.pack("<hhHHHH", x, y, src, ax, ay, alt)
    return text[:m.start(2)] + base64.b64encode(bytes(out)).decode() + text[m.end(2):]


def art_path(text: str) -> str:
    gid = re.search(r'\[node name="GroundArt"[^\n]*\n(?:[^\[\n][^\n]*\n)*?texture = ExtResource\("([^"]+)"\)', text).group(1)
    path = re.search(r'\[ext_resource type="Texture2D"[^\n]*path="res://([^"]+)"[^\n]*id="%s"\]' % re.escape(gid), text).group(1)
    return os.path.join(ROOT, path)


class Area:
    def __init__(self, area: str):
        self.id = area
        self.text = open(scene_path(area)).read()
        self.ground = read_layer(self.text, "Ground")
        self.blocker = read_layer(self.text, "Blocker")
        xs = [x for x, _ in self.ground]
        ys = [y for _, y in self.ground]
        self.w = max(xs) + 1
        self.h = max(ys) + 1
        self.changed: set = set()
        # the tile rectangles of the bands painted again: (x0, y0, x1, y1, side)
        self.bands: list = []

    def kind(self, x: int, y: int):
        cell = self.ground.get((x, y))
        return cell[2] if cell and cell[0] == TERRAIN_SOURCE else None

    def set_kind(self, x: int, y: int, kind: int) -> None:
        cell = self.ground[(x, y)]
        if cell[2] != kind:
            self.ground[(x, y)] = (TERRAIN_SOURCE, (x * 7 + y * 3) % 4, kind, cell[3])
            self.changed.add((x, y))

    def cell_at(self, side, depth: int, along: int):
        """The tile [param depth] in from the edge on [param side], at
        [param along] along it."""
        sx, sy = side
        if sx > 0:
            return (self.w - 1 - depth, along)
        if sx < 0:
            return (depth, along)
        if sy > 0:
            return (along, self.h - 1 - depth)
        return (along, depth)

    def column(self, side, depth: int, lo: int, hi: int) -> list:
        return [self.kind(*self.cell_at(side, depth, a)) if self.length(side) > a >= 0 else None for a in range(lo, hi)]

    def length(self, side) -> int:
        return self.h if side[0] != 0 else self.w


# --- features ---------------------------------------------------------------

def features(col: list) -> list:
    """The runs of river, road, trail and creek in a column of kinds:
    [(class, start, end (exclusive), kinds)]."""
    found = []
    i = 0
    n = len(col)
    while i < n:
        k = col[i]
        cls = next((c for c, ks in CLASSES.items() if k in ks), None)
        if cls is None:
            i += 1
            continue
        j = i
        while j < n and col[j] in CLASSES[cls]:
            j += 1
        run = col[i:j]
        if any(r in CORE[cls] for r in run):
            found.append((cls, i, j, run))
        i = j
    return found


def pair(a: list, b: list) -> list:
    """Pairs features of the same kind along the edge, keeping their order
    (so a bent river never crosses a road), near pairs first, none further
    apart than FARTHEST: [(fa, fb)]."""
    best = {}

    def solve(i: int, j: int):
        if i == len(a) or j == len(b):
            return (0.0, [])
        if (i, j) in best:
            return best[(i, j)]
        options = [solve(i + 1, j), solve(i, j + 1)]
        gap = abs((a[i][1] + a[i][2]) / 2 - (b[j][1] + b[j][2]) / 2)
        if a[i][0] == b[j][0] and gap <= FARTHEST:
            score, chosen = solve(i + 1, j + 1)
            # a near pair is worth more than two far ones
            options.append((score + (1.0 - gap / (FARTHEST + 1)) ** 2, [(a[i], b[j])] + chosen))
        result = max(options, key=lambda o: o[0])
        best[(i, j)] = result
        return result

    return solve(0, 0)[1]


def resample(kinds: list, width: int) -> list:
    if width <= 0:
        return []
    return [kinds[min(len(kinds) - 1, int((i + 0.5) * len(kinds) / width))] for i in range(width)]


def smooth(t: float) -> float:
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


# --- one seam ---------------------------------------------------------------

def edge_span(seam: dict):
    """The seam's two areas, their sides, the tile shift from the first's
    along index to the second's, and the along range (in the first's tiles)
    both maps cover."""
    sx, sy = seam["side"]
    ox, oy = seam["offset"]
    along_px = oy if sx != 0 else ox
    shift = round(along_px / TILE)
    b = seam["bounds"]
    nb = seam["neighbor_bounds"]
    if sx != 0:
        lo, hi = max(b[1], nb[1]), min(b[1] + b[3], nb[1] + nb[3])
    else:
        lo, hi = max(b[0], nb[0]), min(b[0] + b[2], nb[0] + nb[2])
    # looked at a little past where both maps are, for a river that runs
    # just past the end of the other
    return (sx, sy), (-sx, -sy), shift, int(lo // TILE) - FARTHEST, int(-(-hi // TILE)) + FARTHEST


def plan_seam(seam: dict, areas: dict) -> list:
    """Works out where each paired feature meets: [(feature in A's tiles,
    feature in B's tiles, meeting start, meeting end, kinds)], in A's along
    tiles."""
    A, B = areas[seam["region"]], areas[seam["neighbor"]]
    side_a, side_b, shift, lo, hi = edge_span(seam)
    col_a = A.column(side_a, 0, lo, hi)
    col_b = B.column(side_b, 0, lo - shift, hi - shift)
    meets = []
    for fa, fb in pair(features(col_a), features(col_b)):
        both = [i for i in range(len(col_a)) if col_a[i] is not None and col_b[i] is not None]
        if not both:
            continue
        if A.id in BUILT and B.id not in BUILT:
            start, end, kinds = fb[1], fb[2], fb[3]
        elif B.id in BUILT and A.id not in BUILT:
            start, end, kinds = fa[1], fa[2], fa[3]
        else:
            width = round((fa[2] - fa[1] + fb[2] - fb[1]) / 2)
            middle = ((fa[1] + fa[2]) / 2 + (fb[1] + fb[2]) / 2) / 2
            start = round(middle - width / 2)
            end = start + width
            kinds = resample(fa[3] if len(fa[3]) >= len(fb[3]) else fb[3], width)
        # where both maps are (a hand-made area's river past the end of the
        # other map can't be met)
        if (start < both[0] or end > both[-1] + 1) and (A.id not in BUILT or B.id not in BUILT):
            continue
        if start < both[0]:
            start, end = both[0], both[0] + (end - start)
        if end > both[-1] + 1:
            start, end = both[-1] + 1 - (end - start), both[-1] + 1
        meets.append((fa, fb, start + lo, end + lo, kinds))
    return meets


def band_for(gap: float) -> int:
    return int(min(MOST_BAND, max(BAND, round(abs(gap) * STEEP) + OVERLAP)))


def bend(area: Area, side, lo: int, hi: int, shift: int, meets: list, which: int) -> int:
    """Bends [param area]'s side of each paired feature (which: 0 for the
    seam's own area, 1 for its neighbor) from where it runs a band's depth
    in to where it meets at the edge. Returns how many tiles changed."""
    before = len(area.changed)
    a0, a1 = lo - shift, hi - shift
    moves = []
    for meet in meets:
        own = meet[which]
        start, end, kinds = meet[2] - lo, meet[3] - lo, meet[4]
        if (own[1], own[2]) == (start, end):
            continue  # it meets already
        if own[0] == "way" and abs((start + end) / 2 - (own[1] + own[2]) / 2) < WAY_SLACK:
            continue  # the seam's nudge lines roads up to the pixel already
        depth = band_for((start + end) / 2 - (own[1] + own[2]) / 2)
        # the same feature that far in: the nearest of its class to its
        # place at the edge
        same = [f for f in features(area.column(side, depth, a0, a1)) if f[0] == own[0]]
        if not same:
            continue
        deep = min(same, key=lambda f: abs((f[1] + f[2]) / 2 - (own[1] + own[2]) / 2))
        if abs((deep[1] + deep[2]) / 2 - (own[1] + own[2]) / 2) > FARTHEST / 2:
            continue
        moves.append((own, deep, start, end, kinds, depth))
    if not moves:
        return 0
    deepest = max(m[5] for m in moves)
    for d in range(deepest):
        col = area.column(side, d, a0, a1)
        new = list(col)
        placed = []
        for own, deep, start, end, kinds, depth in moves:
            if d >= depth:
                continue
            t = smooth((d - (OVERLAP - 1)) / (depth - OVERLAP + 1))
            # take up the feature where it ran at this depth...
            centre = (own[1] + own[2]) / 2 * (1 - t) + (deep[1] + deep[2]) / 2 * t
            was = (own[1] + own[2]) / 2 + ((deep[1] + deep[2]) / 2 - (own[1] + own[2]) / 2) * d / depth
            for f in features(col):
                if f[0] == own[0] and abs((f[1] + f[2]) / 2 - was) <= max(3, (f[2] - f[1])):
                    for i in range(f[1], f[2]):
                        if col[i] != BRIDGE:
                            new[i] = None
            mid = (start + end) / 2 * (1 - t) + (deep[1] + deep[2]) / 2 * t
            width = round((end - start) * (1 - t) + (deep[2] - deep[1]) * t)
            placed.append((round(mid - width / 2), resample(kinds if t < 0.5 else deep[3], width)))
        for i in range(len(new)):
            if new[i] is None and col[i] is not None:
                new[i] = fill(col, i)
        # ...and lay it where it runs now
        for first, lay in placed:
            for i, k in enumerate(lay):
                at = first + i
                if 0 <= at < len(new) and col[at] is not None and col[at] not in FIXED \
                        and not (col[at] in KEEP_DRY and k not in CLASSES["way"]):
                    new[at] = k
        for i, k in enumerate(new):
            if k is not None and k != col[i]:
                area.set_kind(*area.cell_at(side, d, a0 + i), k)
    area.bands.append((side, a0, a1, deepest))
    return len(area.changed) - before


def fill(col: list, i: int) -> int:
    """The ground beside a taken-up feature: the nearest kind along the
    column that isn't a feature or a wall."""
    for d in range(1, len(col)):
        for j in (i - d, i + d):
            if 0 <= j < len(col) and col[j] is not None and col[j] not in FEATURE and col[j] not in FIXED:
                return col[j]
    return 0


# --- what follows from the new ground --------------------------------------

def reblock(area: Area) -> None:
    """Water and walls block where they meet walkable ground, round every
    tile that changed."""
    near = set()
    for x, y in area.changed:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                near.add((x + dx, y + dy))
    for x, y in near:
        if (x, y) not in area.ground:
            continue
        k = area.kind(x, y)
        edge = k in SOLID and any(
            (x + dx, y + dy) in area.ground and area.kind(x + dx, y + dy) not in SOLID
            for dx in (-1, 0, 1) for dy in (-1, 0, 1))
        if edge:
            area.blocker[(x, y)] = (BLOCK_SOURCE, 0, 0, 0)
        else:
            area.blocker.pop((x, y), None)


OPEN_GROUND = FEATURE | {CREEK}


def take_up(area: Area) -> list:
    """Takes up the trees, rocks and props standing on tiles that are now
    water, road or trail. Returns their names."""
    gone = []
    text = area.text
    blocks = re.split(r"(?=\n\[node )", text)
    doomed = set()
    for block in blocks:
        m = re.match(r'\n\[node name="([^"]+)"[^\n]*parent="Entities"', block)
        if not m:
            continue
        pos = re.search(r"^position = Vector2\(([-\d.e]+), ([-\d.e]+)\)", block, re.M)
        if not pos:
            continue
        cell = (int(float(pos.group(1)) // TILE), int(float(pos.group(2)) // TILE))
        if cell in area.changed and area.kind(*cell) in OPEN_GROUND:
            doomed.add(m.group(1))
    kept = []
    for block in blocks:
        m = re.match(r'\n\[node name="([^"]+)"[^\n]*parent="([^"]+)"', block)
        if m:
            parent = m.group(2)
            name = m.group(1)
            if (parent == "Entities" and name in doomed) or any(parent == "Entities/" + d or parent.startswith("Entities/" + d + "/") for d in doomed):
                continue
        kept.append(block)
    area.text = "".join(kept)
    gone += sorted(doomed)
    # the wild clutter
    dressing = os.path.join(ROOT, "scenes", "regions", "dressing", "wild", area.id + ".tscn")
    if os.path.exists(dressing):
        dtext = open(dressing).read()
        blocks = re.split(r"(?=\n\[node )", dtext)
        out = []
        for block in blocks:
            pos = re.search(r"^position = Vector2\(([-\d.e]+), ([-\d.e]+)\)", block, re.M)
            if block.startswith("\n[node") and pos:
                cell = (int(float(pos.group(1)) // TILE), int(float(pos.group(2)) // TILE))
                if cell in area.changed and area.kind(*cell) in OPEN_GROUND:
                    continue
            out.append(block)
        open(dressing, "w").write("".join(out))
    return gone


def story_in_the_way(area: Area) -> list:
    """The story's people, pickups and spots on tiles that are now water."""
    found = []
    for sub in ("story/content", "story/doors"):
        path = os.path.join(ROOT, "scenes", sub, area.id + ".tscn")
        if not os.path.exists(path):
            continue
        for m in re.finditer(r'\[node name="([^"]+)"[^\n]*\n((?:[^\[\n][^\n]*\n)*)', open(path).read()):
            pos = re.search(r"^position = Vector2\(([-\d.e]+), ([-\d.e]+)\)", m.group(2), re.M)
            if pos:
                cell = (int(float(pos.group(1)) // TILE), int(float(pos.group(2)) // TILE))
                if cell in area.changed and area.kind(*cell) in SOLID:
                    found.append(m.group(1))
    return found


# Feather the new picture into the old over this many pixels at the band's
# inner side, with an ordered dither.
FEATHER = 48
BAYER = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) + 0.5) / 16.0


def repaint(areas: list, godot: str) -> None:
    """Paints each area's ground afresh from its new tiles and pastes the
    bands into its picture."""
    with tempfile.TemporaryDirectory() as tmp:
        dump = os.path.join(tmp, "dump")
        out = os.path.join(tmp, "paint")
        ids = [a.id for a in areas]
        subprocess.run([godot, "--headless", "--path", ROOT, "res://tools/art32/ground32/dump.tscn", "--", dump] + ids,
                       check=True, stdout=subprocess.DEVNULL)
        subprocess.run([sys.executable, os.path.join(ROOT, "tools", "art32", "ground32", "paint.py"), dump] + ids + ["--out", out],
                       check=True, stdout=subprocess.DEVNULL)
        for area in areas:
            art = art_path(area.text)
            old = np.array(Image.open(art).convert("RGBA"))
            new = np.array(Image.open(os.path.join(out, os.path.basename(art))).convert("RGBA"))
            h, w = old.shape[:2]
            ys, xs = np.mgrid[0:h, 0:w]
            take = np.zeros((h, w), dtype=bool)
            for side, a0, a1, deepest in area.bands:
                sx, sy = side
                band = deepest * TILE
                # how far in from the edge, and whether along the band
                if sx != 0:
                    depth = (w - 1 - xs) if sx > 0 else xs
                    along = ys
                else:
                    depth = (h - 1 - ys) if sy > 0 else ys
                    along = xs
                inside = (along >= a0 * TILE) & (along < a1 * TILE)
                # 1 at the edge, fading to 0 over FEATHER at the band's inner side
                weight = np.clip((band - depth) / FEATHER, 0.0, 1.0)
                take |= inside & (weight > BAYER[ys % 4, xs % 4])
            old[take] = new[take]
            Image.fromarray(old).save(art)
    # and the light's relief for the new ground (LitSprites)
    subprocess.run([sys.executable, os.path.join(ROOT, "tools", "normals", "normals.py")] + [art_path(a.text) for a in areas],
                   check=True, stdout=subprocess.DEVNULL)


# --- main -------------------------------------------------------------------

def main() -> None:
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        sys.exit(1)
    seams = json.load(open(args[0]))
    plan_only = "--plan" in args
    areas = {}
    for s in seams:
        for a in (s["region"], s["neighbor"]):
            if a not in areas:
                areas[a] = Area(a)
    done = set()
    for s in seams:
        key = tuple(sorted((s["region"], s["neighbor"])))
        if key in done:
            continue
        done.add(key)
        A, B = areas[s["region"]], areas[s["neighbor"]]
        side_a, side_b, shift, lo, hi = edge_span(s)
        meets = plan_seam(s, areas)
        moved = []
        for area, side, sh, which in ((A, side_a, 0, 0), (B, side_b, shift, 1)):
            if area.id not in BUILT:
                continue
            n = bend(area, side, lo, hi, sh, meets, which)
            if n:
                moved.append("%s %d tiles" % (area.id, n))
        print("%s <-> %s: %s; %s" % (A.id, B.id,
              ", ".join("%s %d-%d -> %d-%d / %d-%d" % (m[0][0], m[0][1] + lo, m[0][2] + lo, m[2], m[3], m[1][1] + lo, m[1][2] + lo) for m in meets) or "nothing crosses on both sides",
              ", ".join(moved) or "nothing to bend"))
    touched = [a for a in areas.values() if a.changed]
    for area in touched:
        reblock(area)
        in_the_way = story_in_the_way(area)
        if in_the_way:
            print("  %s: the story has %s on new water" % (area.id, ", ".join(in_the_way)))
    if plan_only:
        return
    for area in touched:
        gone = take_up(area)
        area.text = write_layer(area.text, "Ground", area.ground)
        area.text = write_layer(area.text, "Blocker", area.blocker)
        open(scene_path(area.id), "w").write(area.text)
        print("%s: %d tiles changed, took up %s" % (area.id, len(area.changed), ", ".join(gone) or "nothing"))
    repaint(touched, os.environ.get("GODOT", "godot"))


if __name__ == "__main__":
    main()
