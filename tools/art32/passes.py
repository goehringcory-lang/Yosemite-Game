"""The per-category art passes. Each takes the original 16px image and
returns the 32px one, mapped onto the Valley Days palette (palette.py)."""
from __future__ import annotations

import numpy as np

import palette as P
import pixel32 as K

# the darkest color of every ramp: outlines are never lit by the rim pass
_RIMS = tuple(K._RAMP_SPAN[i, 0] for i in range(len(P.COLORS)))


def characters(path: str, a: np.ndarray) -> np.ndarray:
    big = K.remap(K.scale2x(a))
    if a.shape[1] == 48 and a.shape[0] == 96:  # a 3x4 sheet of 16x24 frames
        return K.per_cell(big, 32, 48, K.outline)
    return big


def terrain(path: str, a: np.ndarray) -> np.ndarray:
    if "/ground/" in path:
        # a painted map: enlarge crisply, then paint the texture back in
        return K.paint_texture(K.remap(K.nearest2x(a)), seed=hash_seed(path))
    # tile sheets: tiles repeat, so the texture must wrap at the tile size
    return K.paint_texture(K.remap(K.nearest2x(a)), seed=hash_seed(path), wrap=32)


# sheets of equal cells, in 32px-grid pixels
_CELLS = {
    "assets/sprites/flora.png": (64, 96),
    "assets/sprites/plants.png": (32, 32),
    "assets/sprites/items.png": (32, 32),
    "assets/sprites/food_items.png": (32, 32),
    "assets/sprites/store_items.png": (32, 32),
    "assets/sprites/story_items.png": (32, 32),
    "assets/sprites/side_quest_items.png": (32, 32),
}


def _lit(path: str, big: np.ndarray) -> np.ndarray:
    """The one-light pass: glows are light themselves, and scene-sized
    overlays are lit by their own painting, so both are left alone."""
    if "glow" in path or max(big.shape[:2]) > 400:
        return big
    cell = _CELLS.get(path)
    if cell:
        return K.per_cell(big, cell[0], cell[1], lambda c: K.form_light(c, _RIMS))
    return K.form_light(big, _RIMS)


def props(path: str, a: np.ndarray) -> np.ndarray:
    return _lit(path, K.remap(K.scale2x(a)))


def structures(path: str, a: np.ndarray) -> np.ndarray:
    return _lit(path, K.remap(K.scale2x(a)))


def ui(path: str, a: np.ndarray) -> np.ndarray:
    if path.endswith("title_background.png"):
        # a painting: keep its soft sky and rock, with a light ordered dither
        return K.remap(K.scale2x(a), dither=10)
    return K.remap(a)


def maps(path: str, a: np.ndarray) -> np.ndarray:
    return K.remap(a, dither=8)


def hash_seed(path: str) -> int:
    return sum(ord(c) * (i + 1) for i, c in enumerate(path)) % 100003


def run(category: str, path: str, a: np.ndarray) -> np.ndarray:
    return globals()[category](path, a)
