#!/usr/bin/env python3
"""Paints Upper Yosemite Fall and the rim above the Village's wall.

The Village's wall painting (assets/sprites/buildings/village_wall.png) is the
lower cliff only: Lower Yosemite Fall pours out of a notch at its top edge,
and nothing is drawn above the map. This paints the backdrop the camera sees
when it tilts up at the foot of the Lower Fall (LandmarkView in
scenes/story/content/yosemite_village.tscn): the upper cliff set back behind
the lower one, with the rim against the sky, Upper Yosemite Fall pouring off
it, and the forested bench between the two falls.

There's no lidar render of the upper cliff, so it is built from the Three
Brothers' wall painting next door (the same north wall, rendered by
tools/art32/walls32/paint.py): its sky, rim and face, run twice across the
map's width where the two runs meet best, a little hazier for the distance.
The fall itself is painted here in the Lower Fall's colors, as animation
frames SeasonalFalls dries up with the others.

Writes:
  assets/sprites/buildings/upper_falls_backdrop.png   (3840 x HEIGHT)
  assets/sprites/buildings/upper_yosemite_fall_N.png  (FRAMES frames)
and, in village_wall.png, paints the middle cascades over the sky that showed
through the Lower Fall's notch and hangs the bench's forest over the top edge.
Run it on the wall as the walls32 painter left it (git show the wall from
before this script first ran, if it needs running again).

    python3 tools/hubs/yosemite_falls_backdrop.py
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SPRITES = ROOT / "assets/sprites"
WALL = SPRITES / "buildings/village_wall.png"
SOURCE = SPRITES / "valley/three_brothers_wall.png"
OUT = SPRITES / "buildings/upper_falls_backdrop.png"
FALL = SPRITES / "buildings/upper_yosemite_fall_%d.png"

WIDTH = 3840
# Rows above the map (y < 0) the backdrop covers, and rows below y = 0 it
# reaches behind the wall (seen only through the Lower Fall's notch).
HEIGHT = 204
BELOW = 72
# Rows of the Three Brothers' face left out (from CUT_AT down), so the rim
# and a strip of sky fit in what the camera can show above the map.
CUT_AT = 92
CUT = 30
# Where Upper Yosemite Fall leaves the rim, across the map: a little west of
# the Lower Fall (whose sprite stands at x 1376, 96 wide), as from the Village.
FALL_X = 1404
FRAMES = 6
# The fall's frames are this wide, centred on FALL_X.
FALL_W = 56
# Columns of the Three Brothers' painting used (its last are a ragged edge),
# and how wide the dithered seam between the two runs is.
SOURCE_W = 1980
BLEND = 32
# How far toward the sky the distant cliff fades.
HAZE = 0.14

# The Lower Fall's water, light to deep.
FOAM = (245, 238, 224)
WHITE = (214, 241, 238)
PALE = (159, 216, 217)
BLUE = (99, 179, 198)
DEEP = (58, 134, 168)
SKY_TOP = (74, 128, 165)
SKY = (92, 145, 179)
BENCH = [(38, 62, 44), (52, 84, 52), (70, 104, 58)]


def is_sky(px: np.ndarray) -> np.ndarray:
    r, g, b = px[..., 0].astype(int), px[..., 1].astype(int), px[..., 2].astype(int)
    return (b > r + 40) & (b > 140)


def rim_of(img: np.ndarray) -> np.ndarray:
    """The first row of rock in each column."""
    sky = is_sky(img) | (img[..., 3] == 0)
    rim = np.zeros(img.shape[1], dtype=int)
    for x in range(img.shape[1]):
        rock = np.where(~sky[:, x])[0]
        rim[x] = rock[0] if len(rock) else img.shape[0]
    return rim


def build_cliff() -> np.ndarray:
    src = np.array(Image.open(SOURCE).convert("RGBA"))
    rows = HEIGHT + BELOW
    # The painting's last columns are its ragged edge: leave them off.
    src = src[:rows + CUT, :SOURCE_W]
    keep = np.concatenate([src[:CUT_AT], src[CUT_AT + CUT:]], axis=0)
    # dither the rows either side of the cut together
    for i in range(6):
        y = CUT_AT - 3 + i
        mask = ((np.arange(src.shape[1]) * 5 + i * 3) % 6) < i
        keep[y, mask] = src[y + CUT, mask] if i >= 3 else keep[y, mask]
    src = keep
    h, w = src.shape[:2]
    rim = rim_of(src)
    # The second run starts where its rim and tones best match the first's
    # end, and the two cross over in a dithered seam BLEND pixels wide.
    need = WIDTH - w + BLEND
    best, start = None, 0
    for o in range(0, w - need):
        d = abs(rim[o] - rim[w - BLEND]) * 6 + np.abs(src[:, o, :3].astype(int) - src[:, w - BLEND, :3].astype(int)).mean()
        if best is None or d < best:
            best, start = d, o
    second = src[:, start:start + need]
    cliff = np.concatenate([src[:, :w - BLEND], second], axis=1)
    for i in range(BLEND):
        x = w - BLEND + i
        t = (i + 0.5) / BLEND
        for y in range(h):
            # ordered dither between the two runs
            if ((y * 7 + i * 3) % 8) / 8.0 >= t:
                cliff[y, x] = src[y, w - BLEND + i]
            else:
                cliff[y, x] = second[y, i]
    # Below the forest band the Three Brothers' painting turns to talus and
    # then nothing: fill it with the bench's dark forest and gorge.
    rng = np.random.default_rng(1435)
    for x in range(WIDTH):
        col = cliff[:, x]
        empty = np.where(col[:, 3] < 255)[0]
        empty = empty[empty > 100]
        if len(empty):
            y0 = empty[0]
            for y in range(y0, rows):
                c = BENCH[int(rng.integers(0, 2)) if y > y0 + 3 else 2]
                cliff[y, x] = (*c, 255)
    return cliff


def haze(cliff: np.ndarray) -> None:
    sky = is_sky(cliff)
    rgb = cliff[..., :3].astype(float)
    rgb[~sky] = rgb[~sky] * (1 - HAZE) + np.array(SKY) * HAZE
    cliff[..., :3] = rgb.round().astype(np.uint8)


def paint_bench(cliff: np.ndarray, rng) -> None:
    """A ragged line of conifers along the bench where the backdrop meets
    the wall's top edge, so the seam reads as the forested ledge between
    the falls."""
    y_line = HEIGHT
    for x in range(0, WIDTH):
        top = y_line - 6 - int(4 * np.sin(x / 23.0) + 3 * np.sin(x / 7.3 + 1.0))
        for y in range(top, min(y_line + 4, cliff.shape[0])):
            cliff[y, x] = (*BENCH[0 if y > top + 3 else 1], 255)
    # tree tips
    x = 0
    while x < WIDTH:
        h = int(rng.integers(6, 14))
        base = y_line - 4
        for i in range(h):
            half = max(0, (i * 3) // h)
            for dx in range(-half, half + 1):
                xx = x + dx
                if 0 <= xx < WIDTH:
                    cliff[base - h + i, xx] = (*BENCH[1 if dx < 0 else 0], 255)
        cliff[base - h, x] = (*BENCH[2], 255)
        x += int(rng.integers(3, 8))


def notch(cliff: np.ndarray, rim: np.ndarray) -> int:
    """Cuts the creek's notch into the rim where the fall leaves it; returns
    the row the water goes over."""
    r = int(np.median(rim[FALL_X - 30:FALL_X + 30]))
    lip = r + 6
    for x in range(FALL_X - 14, FALL_X + 15):
        depth = lip - int(abs(x - FALL_X) * 0.45)
        for y in range(0, max(depth, 0)):
            if y < rim[x] + 10:
                cliff[y, x] = (*(SKY_TOP if y < 18 else SKY), 255)
    return lip


def _wobble(y: float, seed: float, scale: float) -> float:
    return np.sin(y / scale + seed) * 0.6 + np.sin(y / (scale * 0.37) + seed * 2.3) * 0.4


def fall_frames(top: int, bottom: int) -> list[Image.Image]:
    """The water from the lip to the bench: a ribbon that leaves the notch
    narrow, spreads and sways as it drops, with streaks running down it frame
    to frame and spray at the foot."""
    w = FALL_W
    h = bottom - top + 14
    frames = []
    rng = np.random.default_rng(2425)
    # streaks: long vertical runs of light and shade
    streak = rng.random((h + 96, w))
    for x in range(w):
        for y in range(1, h + 96):
            streak[y, x] = streak[y - 1, x] * 0.8 + streak[y, x] * 0.2
    for f in range(FRAMES):
        im = np.zeros((h, w, 4), dtype=np.uint8)
        frng = np.random.default_rng(f + 11)
        for y in range(h):
            t = min(y / max(h - 14, 1), 1.0)
            cx = w / 2 + 3.0 * t * _wobble(y, 0.6, 19.0)
            left = cx - (4.5 + t * 9.0 + 1.8 * _wobble(y, 1.9, 6.0) * t)
            right = cx + (4.5 + t * 9.5 + 1.8 * _wobble(y, 4.1, 7.0) * t)
            for x in range(w):
                if x + 0.5 < left or x + 0.5 > right:
                    # loose water peeling off the edges
                    d = min(abs(x + 0.5 - left), abs(x + 0.5 - right))
                    if d < 2.5 and t > 0.2 and frng.random() < 0.18:
                        im[y, x] = (*PALE, 255)
                    continue
                n = streak[(y - f * 4) % (h + 96), x]
                d = min(x + 0.5 - left, right - x - 0.5)
                if d < 1.0:
                    c = BLUE if n < 0.45 else PALE
                elif n > 0.62:
                    c = FOAM
                elif n > 0.47:
                    c = WHITE
                elif n > 0.38:
                    c = PALE
                else:
                    c = BLUE
                im[y, x] = (*c, 255)
        # spray where it lands on the bench
        for i in range(90):
            x = int(frng.normal(w / 2, 8))
            y = h - 1 - int(abs(frng.normal(0, 7)))
            if 0 <= x < w and 0 <= y < h:
                im[y, x] = (*(FOAM if frng.random() < 0.5 else WHITE), 255)
        frames.append(Image.fromarray(im, "RGBA"))
    return frames


def cascade(cliff: np.ndarray, rng) -> None:
    """The middle cascades: white water threading down the dark gorge from
    the bench to the top of the Lower Fall."""
    x0, x1 = FALL_X, 1424
    for y in range(HEIGHT - 4, HEIGHT + BELOW):
        t = (y - HEIGHT + 4) / (BELOW + 4)
        cx = x0 + (x1 - x0) * t + 3 * np.sin(y / 5.0)
        half = 3 + 2 * t
        for x in range(int(cx - half - 2), int(cx + half + 3)):
            d = abs(x + 0.5 - cx)
            if d <= half:
                c = FOAM if rng.random() < 0.35 else (WHITE if rng.random() < 0.7 else PALE)
                cliff[y, x] = (*c, 255)
            elif d <= half + 1.5 and rng.random() < 0.4:
                cliff[y, x] = (*BLUE, 255)


def fringe_wall() -> None:
    """The bench's forest hanging over the wall painting's top edge, so the
    wall no longer ends in a straight cut where the backdrop meets it."""
    wall = np.array(Image.open(WALL).convert("RGBA"))
    rng = np.random.default_rng(1915)
    for x in range(wall.shape[1]):
        if wall[0, x, 3] == 0:
            continue  # the Lower Fall's notch
        d = 3 + int(3 * (np.sin(x / 13.0) + 1) + 2 * (np.sin(x / 4.1 + 2.0) + 1))
        for y in range(d):
            if wall[y, x, 3] == 0:
                break
            wall[y, x] = (*BENCH[1 if (y < d - 2 and rng.random() < 0.55) else 0], 255)
        if d < wall.shape[0] and wall[d, x, 3]:
            wall[d, x, :3] = (wall[d, x, :3] * 0.62).astype(np.uint8)
    Image.fromarray(wall, "RGBA").save(WALL, optimize=True)


def fill_notch(cliff: np.ndarray) -> None:
    """Paints the gorge and the middle cascades over the sky the wall
    painting shows through the Lower Fall's notch, from the backdrop's rows
    below the bench (the creek's painted water lies under the wall there, so
    the notch can't simply be left see-through)."""
    wall = np.array(Image.open(WALL).convert("RGBA"))
    region = wall[:BELOW, 1200:1700]
    sky = is_sky(region) & (region[..., 3] > 0)
    region[sky] = cliff[HEIGHT:HEIGHT + BELOW, 1200:1700][sky]
    wall[:BELOW, 1200:1700] = region
    Image.fromarray(wall, "RGBA").save(WALL, optimize=True)


def main() -> None:
    rng = np.random.default_rng(1872)
    cliff = build_cliff()
    rim = rim_of(cliff)
    lip = notch(cliff, rim)
    haze(cliff)
    # The gorge behind the Lower Fall's notch: dark wet rock.
    for y in range(HEIGHT - 2, HEIGHT + BELOW):
        for x in range(FALL_X - 70, FALL_X + 90):
            cliff[y, x] = (33, 39, 45, 255) if (x + y) % 5 else (42, 50, 56, 255)
    paint_bench(cliff, rng)
    cascade(cliff, rng)
    fill_notch(cliff)
    Image.fromarray(cliff[:HEIGHT], "RGBA").save(OUT, optimize=True)
    for i, im in enumerate(fall_frames(lip, HEIGHT - 4)):
        im.save(str(FALL) % i, optimize=True)
    fringe_wall()
    print("backdrop", OUT.relative_to(ROOT), cliff.shape[1], "x", cliff.shape[0])
    print("fall lip at backdrop row", lip, "-> world y", lip - HEIGHT, "x", FALL_X - FALL_W // 2)


if __name__ == "__main__":
    main()
