"""Contact shadows for the ground: a soft two-step shadow under everything that
stands on it, cast down and to the right (the light is from the upper left).

Shadows are in tone steps (how far down its ramp a ground pixel goes), so
they keep the ground's colors: a shaded meadow is a deeper, cooler green, not
grey. Overlapping shadows take the darker, they don't stack.
"""
from __future__ import annotations

import os

import numpy as np
from PIL import Image

import field as F

# Sprites that are part of the ground or the backdrop, or light.
SKIP_PARTS = ("_glow", "camp4_duff", "/wild_", "vista", "view_below", "_below", "ground_",
              "/clutter/wild", "string_light", "lights_", "mist", "cascade_", "falls_", "fall_",
              "smoke", "spray", "puddle", "rug", "mat_", "track", "flowerbed", "garden_steps",
              "plank", "boardwalk", "bridge", "footbridge", "shadow", "foam", "pool")
TREE_PARTS = ("tree_", "sequoia", "grizzly", "tunnel_tree", "oak_canopy", "black_oak", "carved_oak")
# Low things whose shadow is only a thin rim.
LOW_PARTS = ("plant_", "flower", "lupine", "fern", "bracken", "grass", "mushroom", "cattail",
             "paintbrush", "wildflower", "sign", "post", "lamp", "flag", "headstone")

_cache: dict[str, np.ndarray] = {}


def _alpha(root: str, tex: str) -> np.ndarray | None:
    if tex in _cache:
        return _cache[tex]
    path = os.path.join(root, tex.replace("res://", ""))
    if not os.path.exists(path):
        _cache[tex] = None
        return None
    im = Image.open(path).convert("RGBA")
    a = np.asarray(im)[:, :, 3] > 40
    _cache[tex] = a
    return a


def _frame(sp: dict, a: np.ndarray) -> np.ndarray:
    if sp["region"]:
        x, y, w, h = (int(v) for v in sp["region"])
        return a[y:y + h, x:x + w]
    hf, vf = max(1, sp["hf"]), max(1, sp["vf"])
    fw, fh = a.shape[1] // hf, a.shape[0] // vf
    return a[:fh, :fw]


def _ellipse(field: np.ndarray, cx: float, cy: float, rx: float, ry: float, core: float, B: np.ndarray) -> None:
    H, W = field.shape
    x0, x1 = int(max(cx - rx - 2, 0)), int(min(cx + rx + 3, W))
    y0, y1 = int(max(cy - ry - 2, 0)), int(min(cy + ry + 3, H))
    if x0 >= x1 or y0 >= y1:
        return
    yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
    e = ((xx + 0.5 - cx) / rx) ** 2 + ((yy + 0.5 - cy) / ry) ** 2
    b = B[y0:y1, x0:x1]
    # Penumbra one step, the core two, with a dithered rim between them.
    v = np.where(e < 1.0 + (b - 0.5) * 0.25, 1.0, 0.0)
    v = np.where(e < core * core + (b - 0.5) * 0.3, 2.0, v)
    field[y0:y1, x0:x1] = np.maximum(field[y0:y1, x0:x1], v)


def shade_field(dump: dict, H: int, W: int, root: str, k: float = 1.0) -> np.ndarray:
    """The shadow (in tone steps) at each pixel of a ground [param k] times
    the world's scale (the painter works at half scale)."""
    field = np.zeros((H, W), np.float32)
    B = F.bayer(H, W)
    for sp in dump["sprites"]:
        tex = sp["tex"]
        if not sp["visible"] or sp["z"] <= -5 or sp["material"]:
            continue
        low = tex.lower()
        if any(p in low for p in SKIP_PARTS):
            continue
        a = _alpha(root, tex)
        if a is None:
            continue
        fr = _frame(sp, a)
        fh, fw = fr.shape
        if fh == 0 or fw == 0:
            continue
        rows = np.nonzero(fr.any(axis=1))[0]
        cols = np.nonzero(fr.any(axis=0))[0]
        if len(rows) == 0:
            continue
        sx, sy = abs(sp["sx"]) * k, abs(sp["sy"]) * k
        left = (sp["x"] + sp["ox"]) * k - (fw * sx / 2.0 if sp["centered"] else 0.0)
        top = (sp["y"] + sp["oy"]) * k - (fh * sy / 2.0 if sp["centered"] else 0.0)
        bottom = rows[-1]
        foot_rows = fr[max(bottom - 3, 0):bottom + 1]
        fcols = np.nonzero(foot_rows.any(axis=0))[0]
        foot_w = (fcols[-1] - fcols[0] + 1) * sx if len(fcols) else 4
        foot_cx = left + ((fcols[0] + fcols[-1]) / 2.0 + 0.5) * sx if len(fcols) else left + fw * sx / 2
        foot_y = top + (bottom + 1) * sy
        width = (cols[-1] - cols[0] + 1) * sx
        height = (rows[-1] - rows[0] + 1) * sy
        if any(p in low for p in TREE_PARTS):
            rx = max(width * 0.36, 5.0)
            ry = max(min(rx * 0.34, 14.0), 2.5)
            _ellipse(field, foot_cx + rx * 0.22, foot_y - ry * 0.25, rx, ry, 0.55, B)
        elif any(p in low for p in LOW_PARTS):
            rx = max(foot_w * 0.55, 1.5)
            ry = max(rx * 0.3, 1.0)
            _ellipse(field, foot_cx + 1.5, foot_y - ry * 0.4, rx, ry, 0.0, B)
        elif width >= 110 and height >= 70:
            # A building: a band of shadow along the foot of its wall, deeper
            # at the wall, reaching a little past its right corner.
            depth = 6.0
            x0 = int(left + cols[0] * sx) + 2
            x1 = int(left + (cols[-1] + 1) * sx) + 4
            for x in range(max(x0, 0), min(x1, W)):
                cx = int((x - 3 - left) / sx)
                cx = min(max(cx, 0), fw - 1)
                col = np.nonzero(fr[:, cx])[0]
                yb = top + (col[-1] + 1) * sy if len(col) else foot_y
                for d in range(int(depth)):
                    y = int(yb) + d - 1
                    if 0 <= y < H:
                        v = 2.0 if d < 3 + (B[y, x] - 0.5) * 2 else 1.0
                        field[y, x] = max(field[y, x], v)
        else:
            rx = max(foot_w * 0.58 + 1.0, 2.0)
            ry = max(min(rx * 0.32, 7.0), 1.2)
            core = 0.6 if rx > 6 else 0.0
            _ellipse(field, foot_cx + rx * 0.15, foot_y - ry * 0.35, rx, ry, core, B)
    return field


def canopy_field(dump: dict, H: int, W: int, root: str, k: float = 1.0) -> np.ndarray:
    """How much tree canopy is overhead at each pixel (0 open sky to 1 under
    a crown), from where the trees stand: the duff of needles and leaves lies
    under them, the grass grows between."""
    field = np.zeros((H, W), np.float32)
    for sp in dump["sprites"]:
        low = sp["tex"].lower()
        if not sp["visible"] or not any(p in low for p in TREE_PARTS) or "_glow" in low:
            continue
        a = _alpha(root, sp["tex"])
        if a is None:
            continue
        fr = _frame(sp, a)
        rows = np.nonzero(fr.any(axis=1))[0]
        cols = np.nonzero(fr.any(axis=0))[0]
        if len(rows) == 0:
            continue
        fh, fw = fr.shape
        left = (sp["x"] + sp["ox"]) * k - (fw * k / 2.0 if sp["centered"] else 0.0)
        top = (sp["y"] + sp["oy"]) * k - (fh * k / 2.0 if sp["centered"] else 0.0)
        cx = left + (cols[0] + cols[-1]) / 2.0 * k
        cy = top + (rows[-1] + 1) * k
        r = max((cols[-1] - cols[0] + 1) * k * 0.6, 6.0)
        x0, x1 = int(max(cx - r, 0)), int(min(cx + r + 1, W))
        y0, y1 = int(max(cy - r * 0.7, 0)), int(min(cy + r * 0.7 + 1, H))
        if x0 >= x1 or y0 >= y1:
            continue
        yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
        e = ((xx - cx) / r) ** 2 + ((yy - cy) / (r * 0.7)) ** 2
        field[y0:y1, x0:x1] = np.maximum(field[y0:y1, x0:x1], np.clip(1.2 - e, 0, 1))
    return F.blur(field, 6)
