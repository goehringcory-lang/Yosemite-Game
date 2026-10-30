#!/usr/bin/env python3
"""Paints a normal map for each sprite, so real lights can shade the art.

Every picture in the game is drawn by code with its light and shade already
painted in. This reads that shading back as relief: brighter pixels stand a
little higher, and each shape's edge rounds down to the ground, so a lamp or
the low sun catches the near side of a roof, a trunk or a cobble and leaves
the far side dimmer. The normal maps go in assets/normals/, mirroring
assets/sprites/ (cabin_a.png -> assets/normals/curry/cabin_a.png), each with
its Godot .import file. LitSprites (scripts/world/lit_sprites.gd) puts them on
the sprites in the regions it lights.

    python3 tools/normals/normals.py FILE...         # these sprites
    python3 tools/normals/normals.py --region curry_village
                                                     # every sprite that region uses
    python3 tools/normals/normals.py --preview OUT.png FILE
                                                     # the sprite lit three ways

Pictures that give light or are light (glows, windows, shadows, halos) get
none: they shouldn't be shaded.
"""
from __future__ import annotations

import argparse
import hashlib
import os
import re
import secrets
import sys

import numpy as np
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SPRITES = "assets/sprites/"
NORMALS = "assets/normals/"
## Pictures that are light, not things the light falls on.
SKIP_WORDS = ("glow", "shadow", "halo", "window", "light", "_mist", "spray", "blocker")
## The painted ground of a region is big and flat: only its own painted
## shading makes relief, and gently, so paths and grass don't look embossed.
GROUND_PREFIX = "ground_"

## How much a step in painted brightness raises the surface (pixels of
## height for full black to full white), and how high a shape's rounded edge
## rises over its rim.
LUMA_RELIEF = 2.2
GROUND_RELIEF = 1.1
BEVEL_HEIGHT = 2.5
## Normal maps are stored in steps of this (of 255) per channel.
QUANT = 8


def luma(rgb: np.ndarray) -> np.ndarray:
    return (rgb[..., 0] * 0.299 + rgb[..., 1] * 0.587 + rgb[..., 2] * 0.114) / 255.0


def blur3(a: np.ndarray) -> np.ndarray:
    """A 3x3 box blur that keeps the edges."""
    p = np.pad(a, 1, mode="edge")
    out = np.zeros_like(a)
    for dy in range(3):
        for dx in range(3):
            out += p[dy:dy + a.shape[0], dx:dx + a.shape[1]]
    return out / 9.0


def edge_distance(solid: np.ndarray, reach: int) -> np.ndarray:
    """Pixels from each solid pixel to the nearest see-through one (8-way),
    capped at reach."""
    dist = np.where(solid, reach, 0).astype(np.float32)
    for step in range(1, reach + 1):
        p = np.pad(dist, 1, mode="constant", constant_values=0)
        near = np.minimum.reduce([
            p[1 + dy:1 + dy + dist.shape[0], 1 + dx:1 + dx + dist.shape[1]]
            for dy in (-1, 0, 1) for dx in (-1, 0, 1)
        ])
        dist = np.where(solid, np.minimum(dist, near + 1), 0)
    return dist


def normal_map(rgba: np.ndarray, ground: bool = False) -> np.ndarray:
    """RGBA uint8 normal map for an RGBA uint8 picture. Normals use Godot's
    convention: red right, green up (toward the top of the picture), blue out
    of the screen."""
    alpha = rgba[..., 3] / 255.0
    solid = alpha > 0.5
    h = luma(rgba[..., :3].astype(np.float32))
    h = blur3(h) * (GROUND_RELIEF if ground else LUMA_RELIEF)
    if not ground:
        size = min(rgba.shape[0], rgba.shape[1])
        reach = int(np.clip(size // 10, 2, 6))
        d = edge_distance(solid, reach) / reach
        bevel = d * d * (3.0 - 2.0 * d)
        h = h * np.clip(d * 2.0, 0.0, 1.0) + bevel * BEVEL_HEIGHT
        h = np.where(solid, h, 0.0)
    p = np.pad(h, 1, mode="edge")
    dx = (p[1:-1, 2:] - p[1:-1, :-2]) * 0.5
    dy = (p[2:, 1:-1] - p[:-2, 1:-1]) * 0.5   # +y is down the picture
    nx = -dx
    ny = dy        # a slope rising downward faces up the picture
    nz = np.ones_like(h)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    n = np.stack([nx / length, ny / length, nz / length], axis=-1)
    out = np.zeros(rgba.shape, dtype=np.uint8)
    # In steps of QUANT: plenty for pixel art, and the PNGs stay small.
    q = np.round((n * 0.5 + 0.5) * 255.0 / QUANT) * QUANT
    out[..., :3] = np.clip(q, 0, 255).astype(np.uint8)
    out[..., 3] = 255
    flat = np.array([128, 128, 255, 255], dtype=np.uint8)
    out[~solid] = flat
    return out


def light_preview(rgba: np.ndarray, normals: np.ndarray, sun: tuple[float, float, float]) -> np.ndarray:
    """The picture lit as LitSprites lights it: flat ground keeps its painted
    colour; slopes toward the light brighten and slopes away dim."""
    n = normals[..., :3].astype(np.float32) / 127.5 - 1.0
    n[..., 1] = -n[..., 1]   # back to picture coordinates (+y down)
    lx, ly, lz = sun
    ln = np.sqrt(lx * lx + ly * ly + lz * lz)
    ndl = np.clip((n[..., 0] * lx + n[..., 1] * ly + n[..., 2] * lz) / ln, 0.0, None)
    flat = lz / ln
    k = 0.45
    shade = (1.0 - k) + k * np.clip(ndl / flat, 0.0, 2.0)
    out = rgba.copy().astype(np.float32)
    out[..., :3] = np.clip(out[..., :3] * shade[..., None], 0, 255)
    return out.astype(np.uint8)


def normal_path(sprite: str) -> str:
    rel = os.path.relpath(sprite, ROOT).replace(os.sep, "/")
    assert rel.startswith(SPRITES), rel
    return os.path.join(ROOT, NORMALS + rel[len(SPRITES):])


def skip(sprite: str) -> bool:
    name = os.path.basename(sprite)
    return any(word in name for word in SKIP_WORDS)


IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"
uid="{uid}"
path="res://.godot/imported/{name}-{md5}.ctex"
metadata={{
"vram_texture": false
}}

[deps]

source_file="{res}"
dest_files=["res://.godot/imported/{name}-{md5}.ctex"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
"""

UID_CHARS = "abcdefghijklmnopqrstuvwxy012345678"


def new_uid() -> str:
    return "uid://" + "".join(secrets.choice(UID_CHARS) for _ in range(13))


def write_import(png: str) -> None:
    """A Godot .import beside a new normal map (an existing one keeps its uid)."""
    path = png + ".import"
    rel = os.path.relpath(png, ROOT).replace(os.sep, "/")
    res = "res://" + rel
    uid = None
    if os.path.exists(path):
        m = re.search(r'uid="([^"]+)"', open(path).read())
        uid = m.group(1) if m else None
    text = IMPORT.format(uid=uid or new_uid(), name=os.path.basename(png),
                         md5=hashlib.md5(res.encode()).hexdigest(), res=res)
    with open(path, "w") as f:
        f.write(text)


def make(sprite: str) -> str | None:
    if skip(sprite):
        return None
    img = np.array(Image.open(sprite).convert("RGBA"))
    ground = os.path.basename(sprite).startswith(GROUND_PREFIX)
    out = normal_path(sprite)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    Image.fromarray(normal_map(img, ground)).save(out, optimize=True)
    write_import(out)
    return out


def region_sprites(region: str) -> list[str]:
    """Every sprite a region's scene and its dressing use, with the seasonal
    versions of the Ahwahnee-style art (see seasonal_dressing.gd)."""
    scenes = [f"scenes/regions/{region}.tscn"]
    for folder in ("scenes/regions/dressing", "scenes/regions/dressing/wild"):
        for name in (f"{region}.tscn", f"{region}_dressing.tscn"):
            if os.path.exists(os.path.join(ROOT, folder, name)):
                scenes.append(f"{folder}/{name}")
    found: set[str] = set()
    for scene in scenes:
        text = open(os.path.join(ROOT, scene)).read()
        for rel in re.findall(r'path="res://(assets/sprites/[^"]+\.png)"', text):
            found.add(rel)
    seasons = os.path.join(ROOT, SPRITES, "ahwahnee", "seasons")
    for rel in list(found):
        if rel.startswith(SPRITES + "ahwahnee/") and os.path.isdir(seasons):
            base = os.path.splitext(os.path.basename(rel))[0]
            for f in os.listdir(seasons):
                if f.endswith(".png") and re.fullmatch(re.escape(base) + r"_(spring|summer|fall|winter)\.png", f):
                    found.add(f"{SPRITES}ahwahnee/seasons/{f}")
    return sorted(os.path.join(ROOT, rel) for rel in found)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("files", nargs="*")
    ap.add_argument("--region", action="append", default=[])
    ap.add_argument("--preview")
    args = ap.parse_args()
    if args.preview:
        img = np.array(Image.open(args.files[0]).convert("RGBA"))
        nm = normal_map(img, os.path.basename(args.files[0]).startswith(GROUND_PREFIX))
        # morning sun from the east, the high noon sun from the south, evening from the west
        lit = [light_preview(img, nm, s) for s in ((1.0, 0.2, 0.45), (0.0, 1.0, 1.4), (-1.0, 0.2, 0.45))]
        flat = np.zeros_like(img)
        flat[...] = nm
        row = np.concatenate([img, flat] + lit, axis=1)
        big = Image.fromarray(row).resize((row.shape[1] * 3, row.shape[0] * 3), Image.NEAREST)
        bg = Image.new("RGBA", big.size, (60, 70, 60, 255))
        bg.alpha_composite(big)
        bg.save(args.preview)
        return
    files = [os.path.abspath(f) for f in args.files]
    for region in args.region:
        files += region_sprites(region)
    made = 0
    for f in sorted(set(files)):
        if make(f):
            made += 1
    print(f"{made} normal maps written ({len(set(files)) - made} skipped as lights)")


if __name__ == "__main__":
    sys.exit(main())
