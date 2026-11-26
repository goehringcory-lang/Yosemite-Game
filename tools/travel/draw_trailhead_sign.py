"""Draws assets/sprites/trailhead_sign.png (32x48): a trailhead signpost with
two arrow boards and a green trail mark, in the map kiosk's palette.
Run: python3 tools/travel/draw_trailhead_sign.py"""
from pathlib import Path
from PIL import Image

OUT = Path(__file__).resolve().parents[2] / "assets/sprites/trailhead_sign.png"
INK = (42, 27, 20, 255)
DARK = (71, 48, 31, 255)
WOOD = (107, 72, 41, 255)
LIGHT = (146, 105, 61, 255)
PALE = (176, 146, 95, 255)
CREAM = (228, 221, 204, 255)
GREEN = (92, 143, 60, 255)
LEAF = (174, 203, 98, 255)
SHADOW = (42, 27, 20, 110)

im = Image.new("RGBA", (32, 48), (0, 0, 0, 0))
px = im.load()


def rect(x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px[x, y] = c


# ground shadow
for x in range(9, 23):
    px[x, 46] = SHADOW
for x in range(11, 21):
    px[x, 47] = SHADOW
# post
rect(14, 6, 17, 46, INK)
rect(15, 7, 16, 46, WOOD)
for y in range(7, 46):
    px[15, y] = LIGHT
# cap with the green trail mark (a little pine)
rect(12, 1, 19, 7, INK)
rect(13, 2, 18, 6, GREEN)
px[15, 2] = LEAF
px[16, 2] = LEAF
rect(14, 3, 17, 3, LEAF)
rect(15, 4, 16, 5, CREAM)


def arrow(y, right):
    # board 20x7 with a pointed end, outlined in ink
    x0, x1 = (6, 27) if right else (4, 25)
    rect(x0, y, x1, y + 6, INK)
    rect(x0 + 1, y + 1, x1 - 1, y + 5, PALE)
    rect(x0 + 1, y + 1, x1 - 1, y + 1, (214, 189, 136, 255))
    rect(x0 + 1, y + 5, x1 - 1, y + 5, LIGHT)
    tip = x1 + 1 if right else x0 - 1
    step = 1 if right else -1
    for i in range(3):
        for yy in range(y + 1 + i, y + 6 - i):
            px[tip + step * i, yy] = INK if i == 2 or yy in (y + 1 + i, y + 5 - i) else PALE
    # carved letters
    for k, x in enumerate(range(x0 + 3, x1 - 2)):
        if k % 4 != 3:
            px[x, y + 3] = DARK


arrow(10, True)
arrow(19, False)
arrow(28, True)
im.save(OUT)
print("wrote", OUT)
