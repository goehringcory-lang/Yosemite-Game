#!/usr/bin/env python3
"""Paints the icons of the curios you can come across as hidden finds
(Finds, data/park/finds.json): an old piton, a railroad spike, a tin of ski
wax, a glass insulator and a lost headlamp. 32x32, outlined like the other
story item icons.

    python3 tools/discovery/curio_icons.py
"""
from pathlib import Path
from PIL import Image

OUT = Path(__file__).resolve().parents[2] / "assets" / "sprites" / "gear"
INK = (42, 32, 26, 255)


def canvas():
    return Image.new("RGBA", (32, 32), (0, 0, 0, 0))


def rect(im, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            im.putpixel((x, y), c)


def outline(im):
    src = im.copy()
    for y in range(32):
        for x in range(32):
            if src.getpixel((x, y))[3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < 32 and 0 <= ny < 32 and src.getpixel((nx, ny))[3]:
                    im.putpixel((x, y), INK)
                    break
    return im


def piton():
    # A soft-iron horizontal piton: an eye, and a blade going rusty.
    im = canvas()
    rust, iron, light, dark = (150, 78, 40, 255), (118, 112, 106, 255), (170, 164, 156, 255), (82, 70, 62, 255)
    for i in range(18):  # blade, on a diagonal
        x, y = 8 + i, 20 - i // 2
        rect(im, x, y, x, y + 2, iron if i % 5 else rust)
        im.putpixel((x, y), light)
        if i > 10 and i % 3 == 0:
            im.putpixel((x, y + 2), rust)
    rect(im, 4, 18, 9, 25, dark)  # eye
    rect(im, 6, 20, 7, 23, (0, 0, 0, 0))
    im.putpixel((5, 19), light)
    im.putpixel((8, 24), rust)
    return outline(im)


def spike():
    # A railroad spike, its hooked head to the left.
    im = canvas()
    steel, light, rust = (96, 86, 80, 255), (146, 134, 124, 255), (138, 70, 36, 255)
    rect(im, 5, 11, 9, 19, steel)  # head
    rect(im, 5, 11, 9, 11, light)
    rect(im, 10, 13, 25, 17, steel)  # shank
    rect(im, 10, 13, 25, 13, light)
    rect(im, 26, 14, 27, 16, steel)  # chisel point
    im.putpixel((28, 15), steel)
    for x, y in ((13, 16), (17, 15), (21, 17), (24, 14), (7, 18)):
        im.putpixel((x, y), rust)
    return outline(im)


def wax():
    # A round tin of ski wax, lid off to one side, green wax inside.
    im = canvas()
    tin, light, wax_c, wax_l, red = (150, 150, 158, 255), (204, 206, 212, 255), (64, 120, 72, 255), (104, 158, 104, 255), (178, 52, 44, 255)
    for y in range(32):
        for x in range(32):
            dx, dy = (x - 13) / 9.0, (y - 18) / 6.0
            if dx * dx + dy * dy <= 1.0:
                im.putpixel((x, y), tin)
            if dx * dx + dy * dy <= 0.55:
                im.putpixel((x, y), wax_c)
    rect(im, 9, 15, 13, 16, wax_l)
    rect(im, 4, 19, 22, 21, tin)
    rect(im, 4, 22, 22, 24, (118, 118, 126, 255))
    rect(im, 7, 22, 19, 23, red)  # the label band
    for y in range(32):  # the lid, leaning on it
        for x in range(32):
            dx, dy = (x - 24) / 5.0, (y - 11) / 6.0
            if dx * dx + dy * dy <= 1.0:
                im.putpixel((x, y), light if dx < 0 else tin)
    rect(im, 23, 9, 25, 12, red)
    return outline(im)


def insulator():
    # A blue-green glass telephone insulator: a dome with a ridge and skirt.
    im = canvas()
    glass, light, dark = (88, 168, 170, 255), (172, 226, 222, 255), (52, 118, 126, 255)
    for y in range(5, 27):
        if y < 14:
            half = round(9 * (1 - ((14 - y) / 9.5) ** 2) ** 0.5)
        elif y < 21:
            half = 9 if y not in (15, 16) else 8
        else:
            half = 11
        half = max(2, min(half, 11))
        rect(im, 16 - half, y, 15 + half, y, glass)
    rect(im, 7, 15, 24, 16, dark)  # the wire groove
    rect(im, 5, 25, 26, 26, dark)  # the drip skirt
    for y in range(7, 24):
        im.putpixel((12 - max(0, (12 - y) // 2), y), light)
    rect(im, 14, 6, 16, 6, light)
    return outline(im)


def headlamp():
    # A headlamp on its elastic strap, the lens lit.
    im = canvas()
    strap, strap_l, body, lens, glow = (60, 84, 150, 255), (98, 126, 192, 255), (52, 52, 58, 255), (250, 236, 150, 255), (255, 252, 214, 255)
    for x in range(3, 29):  # the strap, a loose loop
        y = 20 + int(round(((x - 16) / 13.0) ** 2 * -6))
        rect(im, x, y, x, y + 2, strap)
        im.putpixel((x, y), strap_l)
    rect(im, 11, 15, 20, 23, body)
    rect(im, 13, 17, 18, 21, lens)
    rect(im, 14, 18, 16, 19, glow)
    im.putpixel((19, 15), (200, 60, 50, 255))  # the switch
    return outline(im)


ICONS = {
    "rusty_piton": piton,
    "railroad_spike": spike,
    "ski_wax_tin": wax,
    "glass_insulator": insulator,
    "lost_headlamp": headlamp,
}

if __name__ == "__main__":
    for name, paint in ICONS.items():
        paint().save(OUT / f"{name}.png")
        print("wrote", OUT / f"{name}.png")
