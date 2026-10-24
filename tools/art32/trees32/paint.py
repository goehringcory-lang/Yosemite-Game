#!/usr/bin/env python3
"""Paints the park's trees natively for the 32px game, as the real species.

    python3 tools/art32/trees32/paint.py                 # every tree and its seasons, in place
    python3 tools/art32/trees32/paint.py NAME...         # just these (e.g. tree_ponderosa_a)
    python3 tools/art32/trees32/paint.py --out DIR [NAME...]   # write elsewhere, to look first
    python3 tools/art32/trees32/paint.py --list          # every sprite it paints

Each sprite keeps its canvas and its anchor (the trunk's foot, centred, four
pixels above the bottom edge), so the scenes, their collision and the ground's
shadows stay as they are. A tree's seasons go to assets/sprites/ahwahnee/seasons/
as <name>_<season>.png, where SeasonalDressing finds them; the homestead's
oaks are one sheet of the four seasons (tree_oak_seasons.png). Then
`godot --headless --path . --import`.
"""
from __future__ import annotations

import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)

import broadleaf as B  # noqa: E402
import pines  # noqa: E402
from kit import scale2x  # noqa: E402

A = "assets/sprites/ahwahnee/"
G = "assets/sprites/glacier/"

# name -> (folder, painter(w, h, season), the season its base sprite shows, its other seasons)
SPECIES: dict[str, tuple[str, object, str, tuple[str, ...]]] = {}


def _add(name: str, folder: str, painter, base: str = "summer", extra: tuple[str, ...] = ()) -> None:
    SPECIES[name] = (folder, painter, base, extra)


for _v in "abc":
    _add(f"tree_ponderosa_{_v}", A, lambda w, h, s, v=_v: pines.ponderosa(w, h, v, s), extra=("winter",))
for _v in "ab":
    _add(f"tree_incense_cedar_{_v}", A, lambda w, h, s, v=_v: pines.incense_cedar(w, h, v, s), extra=("winter",))
_add("tree_white_fir", A, lambda w, h, s: pines.white_fir(w, h, "a", s), extra=("winter",))
for _v in "ab":
    _add(f"tree_sugar_pine_{_v}", A, lambda w, h, s, v=_v: pines.sugar_pine(w, h, v))
for _v in "abcd":
    _add(f"tree_lodgepole_{_v}", A, lambda w, h, s, v=_v: pines.lodgepole(w, h, v))
for _v in "ab":
    _add(f"tree_gray_pine_{_v}", A, lambda w, h, s, v=_v: pines.gray_pine(w, h, v))
for _v in "abc":
    _add(f"tree_sequoia_giant_{_v}", A, lambda w, h, s, v=_v: pines.sequoia(w, h, v))
_add("tree_snag", A, lambda w, h, s: pines.snag(w, h, "a"))
_add("tree_grizzly_giant", A, lambda w, h, s: pines.grizzly_giant(w, h))
_add("tree_tunnel", A, lambda w, h, s: pines.tunnel_tree(w, h))
_add("tree_fallen_monarch", A, lambda w, h, s: pines.fallen_monarch(w, h))
_add("tree_whitebark", A, lambda w, h, s: B.whitebark(w, h))
for _v in "abc":
    _add(f"tree_black_oak_{_v}", A, lambda w, h, s, v=_v: B.black_oak(w, h, v, s), extra=("spring", "fall", "winter"))
for _v in "ab":
    _add(f"tree_blue_oak_{_v}", A, lambda w, h, s, v=_v: B.blue_oak(w, h, v, s), extra=("fall", "winter"))
    _add(f"tree_live_oak_{_v}", A, lambda w, h, s, v=_v: B.live_oak(w, h, v, s))
    _add(f"tree_alder_{_v}", A, lambda w, h, s, v=_v: B.alder(w, h, v, s), extra=("fall", "winter"))
    _add(f"tree_dogwood_bloom_{_v}", A, lambda w, h, s, v=_v: B.dogwood(w, h, v, s), "spring", ("summer", "fall", "winter"))
    _add(f"tree_willow_{_v}", A, lambda w, h, s, v=_v: B.willow(w, h, v, s), extra=("fall", "winter"))
_add("tree_redbud", A, lambda w, h, s: B.redbud(w, h, "a", s), extra=("spring", "fall", "winter"))
_add("tree_buckeye", A, lambda w, h, s: B.buckeye(w, h, "a", s), "spring", ("summer", "fall", "winter"))
_add("tree_apple_old", A, lambda w, h, s: B.apple(w, h, "a", s), extra=("spring", "fall", "winter"))
for _v in "ab":
    _add(f"gp_jeffrey_{_v}", G, lambda w, h, s, v=_v: pines.jeffrey(w, h, v))
    _add(f"gp_red_fir_{_v}", G, lambda w, h, s, v=_v: pines.red_fir(w, h, v))
_add("gp_lodgepole", G, lambda w, h, s: pines.lodgepole(w, h, "gp"))
_add("gp_snag", G, lambda w, h, s: pines.snag(w, h, "b"))

# the homestead's acorn oaks: one sheet, spring | summer | fall | winter
OAK_SHEET = A + "tree_oak_seasons.png"
OAK_SHEET_TREE = "c"


def files() -> list[tuple[str, str, str]]:
    """Every (sprite name, season, path) this paints."""
    out = []
    for name, (folder, _p, base, extra) in SPECIES.items():
        out.append((name, base, folder + name + ".png"))
        for s in extra:
            out.append((name, s, A + "seasons/" + f"{name}_{s}.png"))
    return out


def target(name: str) -> str:
    folder = SPECIES[name][0]
    return os.path.join(ROOT, folder + name + ".png")


def size_of(name: str) -> tuple[int, int]:
    return Image.open(target(name)).size


def render(name: str, season: str | None = None) -> np.ndarray:
    folder, painter, base, _extra = SPECIES[name]
    w, h = size_of(name)
    art = painter(w // 2, h // 2, season or base)
    return scale2x(art.render())


def oak_sheet() -> np.ndarray:
    w, h = size_of("tree_black_oak_" + OAK_SHEET_TREE)
    frames = [scale2x(B.black_oak(w // 2, h // 2, OAK_SHEET_TREE, s).render()) for s in B.SEASONS]
    return np.concatenate(frames, axis=1)


def main() -> None:
    args = sys.argv[1:]
    if args[:1] == ["--list"]:
        for name, season, path in files():
            print(f"{name:26s} {season:7s} {path}")
        print("tree_oak_seasons          (sheet)  " + OAK_SHEET)
        return
    out_dir = None
    if args[:1] == ["--out"]:
        out_dir = args[1]
        args = args[2:]
        os.makedirs(out_dir, exist_ok=True)
    names = set(args)
    n = 0
    for name, season, path in files():
        if names and name not in names:
            continue
        img = render(name, season)
        dest = os.path.join(out_dir, os.path.basename(path)) if out_dir else os.path.join(ROOT, path)
        Image.fromarray(img, "RGBA").save(dest, optimize=True)
        n += 1
    if not names or "tree_oak_seasons" in names:
        dest = os.path.join(out_dir, "tree_oak_seasons.png") if out_dir else os.path.join(ROOT, OAK_SHEET)
        Image.fromarray(oak_sheet(), "RGBA").save(dest, optimize=True)
        n += 1
    print("painted", n, "sprites")


if __name__ == "__main__":
    main()
