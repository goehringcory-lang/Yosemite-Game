#!/usr/bin/env python3
"""Render the Valley Days motion-graphic ad (30 s, 1920x1080, 30 fps).

Everything on screen comes from the repository: screenshots in docs/, the
title painting and logo, the DotGothic16 font, and the title music and
sound effects in assets/audio.

    python3 tools/ad/make_ad.py [out.mp4]

Needs Pillow, numpy and ffmpeg on PATH. Frames go to a temp folder, then
ffmpeg encodes them with the soundtrack.
"""
import math
import os
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
W, H, FPS = 1920, 1080, 30
DUR = 30.0

FONT = os.path.join(ROOT, "assets/fonts/DotGothic16-Regular.ttf")
CREAM = (246, 236, 214)
GOLD = (232, 186, 92)
BARK = (43, 29, 20)
INK = (24, 16, 12)


def P(*a):
    return os.path.join(ROOT, *a)


def doc(name):
    return Image.open(P("docs", name + ".png")).convert("RGB")


_fonts = {}


def font(size):
    if size not in _fonts:
        _fonts[size] = ImageFont.truetype(FONT, size)
    return _fonts[size]


# ---------------------------------------------------------------- easing
def clamp(x, a=0.0, b=1.0):
    return max(a, min(b, x))


def ease_out(x):
    x = clamp(x)
    return 1 - (1 - x) ** 3


def ease_in_out(x):
    x = clamp(x)
    return 4 * x ** 3 if x < 0.5 else 1 - (-2 * x + 2) ** 3 / 2


def back_out(x, s=1.8):
    x = clamp(x)
    return 1 + (s + 1) * (x - 1) ** 3 + s * (x - 1) ** 2


def prog(t, a, b):
    return clamp((t - a) / (b - a))


# ---------------------------------------------------------------- assets
def crop_frac(im, box):
    w, h = im.size
    return im.crop((int(box[0] * w), int(box[1] * h), int(box[2] * w), int(box[3] * h)))


def load_assets():
    A = {}
    tb = Image.open(P("assets/ui/title_background.png")).convert("RGB")
    A["title_bg"] = tb

    # The logo: the title screenshot minus the bare painting, inside the
    # logo's box, so it lifts off cleanly with its outline.
    ui = np.array(doc("ui_title")).astype(int)
    bg3 = np.array(tb.resize((2880, 1620), Image.NEAREST)).astype(int)
    mask = (np.abs(ui - bg3).sum(2) > 30).astype(np.uint8) * 255
    x0, y0, x1, y1 = 880, 170, 2000, 498
    m = Image.fromarray(mask[y0:y1, x0:x1]).filter(ImageFilter.MaxFilter(7))
    logo = Image.fromarray(ui[y0:y1, x0:x1].astype(np.uint8)).convert("RGBA")
    logo.putalpha(m)
    A["logo"] = logo.crop(logo.getbbox())

    # Shots, cropped to 16:9 where the original isn't.
    A["glacier"] = doc("glacier_point_overlook")
    A["cathedral"] = doc("tuolumne_cathedral_peak")
    A["horsetail"] = doc("seasons_horsetail_fall")
    A["rapids"] = doc("fishing_rapids")
    A["dialogue"] = doc("polish_dialogue")
    A["nose"] = doc("climb_the_nose_polished")
    A["summit"] = doc("climb_summit")
    A["bivy"] = doc("night_sky_bivy")
    A["cast"] = doc("valley_life_forward_cast")
    A["campfire"] = doc("polish_campfire")
    A["viewfinder"] = doc("photo_viewfinder_tunnel_view")
    A["wildlife"] = doc("wildlife_valley")
    A["snow"] = doc("seasons_snow_village")
    A["dusk"] = doc("yosemite_village_dusk")
    A["camp4"] = doc("camp4_night")
    A["firefall"] = doc("curry_village_firefall")
    # The sea of clouds, without the caption box below it.
    A["clouds"] = crop_frac(doc("half_dome_cloud_sea"), (0, 0.09, 1, 0.72))
    A["hd_summit"] = crop_frac(doc("half_dome_summit"), (0, 0.09, 1, 0.80))

    # Portrait grid: 10 x 5 cells of 160 px at 8 + 168k.
    pg = doc("cast_portraits")
    A["faces"] = [pg.crop((8 + 168 * c, 8 + 168 * r, 168 + 168 * c, 168 + 168 * r))
                  for r in range(5) for c in range(10)]
    return A


# ---------------------------------------------------------------- drawing
def cover(im, w, h, zoom=1.0, fx=0.5, fy=0.5):
    """Scale im to cover w x h at the given zoom, centred on (fx, fy)."""
    iw, ih = im.size
    s = max(w / iw, h / ih) * zoom
    cw, ch = w / s, h / s
    cx = clamp(fx * iw, cw / 2, iw - cw / 2)
    cy = clamp(fy * ih, ch / 2, ih - ch / 2)
    box = (cx - cw / 2, cy - ch / 2, cx + cw / 2, cy + ch / 2)
    return im.resize((w, h), Image.BILINEAR, box=box)


def kb(im, p, z0, z1, f0, f1, w=W, h=H):
    """Ken Burns move over p in [0,1]."""
    e = ease_in_out(p)
    return cover(im, w, h, z0 + (z1 - z0) * e,
                 f0[0] + (f1[0] - f0[0]) * e, f0[1] + (f1[1] - f0[1]) * e)


def text_size(s, size):
    b = font(size).getbbox(s)
    return b[2] - b[0], b[3] - b[1]


def draw_text(img, xy, s, size, fill=CREAM, anchor="la", shadow=True, alpha=1.0):
    if alpha <= 0:
        return
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    f = font(size)
    a = int(255 * alpha)
    if shadow:
        off = max(2, size // 16)
        d.text((xy[0] + off, xy[1] + off), s, font=f, fill=INK + (int(a * 0.85),), anchor=anchor)
    d.text(xy, s, font=f, fill=fill + (a,), anchor=anchor)
    img.alpha_composite(layer)


def headline(img, t, t0, lines, x, y, size=84, color=CREAM, out_t=None):
    """Per-letter rise-and-fade headline. lines: list of (text, colour)."""
    f = font(size)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    k = 0
    fade = 1.0 if out_t is None else 1 - prog(t, out_t, out_t + 0.35)
    for li, (s, col) in enumerate(lines):
        cx = x
        ly = y + li * int(size * 1.18)
        for ch in s:
            p = prog(t, t0 + k * 0.025, t0 + k * 0.025 + 0.45)
            k += 1
            adv = f.getlength(ch)
            if p > 0 and ch != " ":
                e = back_out(p, 1.4)
                a = int(255 * clamp(p * 2.5) * fade)
                yy = ly + (1 - e) * size * 0.6
                off = max(3, size // 14)
                d.text((cx + off, yy + off), ch, font=f, fill=INK + (int(a * 0.85),))
                d.text((cx, yy), ch, font=f, fill=(col or color) + (a,))
            cx += adv
    img.alpha_composite(layer)


def panel(img, box, alpha=1.0, radius=14):
    """A rounded box in the game's dark-bark UI style with a gold rule."""
    if alpha <= 0:
        return
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    x0, y0, x1, y1 = box
    a = int(255 * alpha)
    radius = max(1, min(radius, (y1 - y0) // 2 - 1, (x1 - x0) // 2 - 1))
    d.rounded_rectangle((x0 + 6, y0 + 8, x1 + 6, y1 + 8), radius, fill=(0, 0, 0, int(a * 0.35)))
    d.rounded_rectangle(box, radius, fill=BARK + (int(a * 0.92),), outline=GOLD + (a,), width=4)
    if x1 - x0 < 40 or y1 - y0 < 40:
        return
    d.rounded_rectangle((x0 + 9, y0 + 9, x1 - 9, y1 - 9), radius - 6, outline=(120, 86, 52, int(a * 0.8)), width=2)
    img.alpha_composite(layer)


def tag(img, t, t0, label, x, y, out_t=None):
    """A small pill label that slides in from the left."""
    p = ease_out(prog(t, t0, t0 + 0.45))
    if out_t is not None:
        p *= 1 - ease_out(prog(t, out_t, out_t + 0.3))
    if p <= 0:
        return
    size = 34
    tw, th = text_size(label, size)
    w = tw + 56
    xx = x - (1 - p) * 60
    panel(img, (xx, y, xx + w, y + 64), alpha=p, radius=12)
    draw_text(img, (xx + 28, y + 32), label, size, fill=GOLD, anchor="lm", alpha=p, shadow=False)


def vignette():
    yy, xx = np.mgrid[0:H, 0:W]
    r = np.sqrt(((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2)) ** 2)
    a = (clamp_arr((r - 0.75) / 0.7) ** 1.6 * 150).astype(np.uint8)
    v = np.zeros((H, W, 4), np.uint8)
    v[..., 3] = a
    return Image.fromarray(v, "RGBA")


def clamp_arr(x):
    return np.clip(x, 0, 1)


def framed(img, shot, box, alpha=1.0, border=8):
    """Paste a shot as a card with a cream border and drop shadow."""
    x0, y0, x1, y1 = [int(v) for v in box]
    w, h = x1 - x0, y1 - y0
    if w <= 0 or h <= 0 or alpha <= 0:
        return
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    a = int(255 * alpha)
    d.rectangle((x0 - border + 10, y0 - border + 14, x1 + border + 10, y1 + border + 14), fill=(0, 0, 0, int(a * 0.4)))
    d.rectangle((x0 - border, y0 - border, x1 + border, y1 + border), fill=CREAM + (a,))
    s = shot.resize((w, h), Image.BILINEAR).convert("RGBA")
    if alpha < 1:
        s.putalpha(a)
    layer.alpha_composite(s, (x0, y0))
    img.alpha_composite(layer)


# ---------------------------------------------------------------- scenes
# Each scene draws onto a full-frame RGBA image for local time t.

def sc_open(A, t, d):
    # Title painting, slow push-in; a line of type rises over it.
    img = kb(A["title_bg"], t / d, 1.18, 1.0, (0.55, 0.45), (0.5, 0.5)).convert("RGBA")
    shade = Image.new("RGBA", (W, H), (10, 8, 20, int(110 * (1 - prog(t, 0, 1.2)) + 40)))
    img.alpha_composite(shade)
    headline(img, t, 0.5, [("This is Yosemite.", CREAM)], 140, 760, size=96, out_t=d - 0.4)
    return img


def sc_roam(A, t, d):
    # Three shots slide past in a row of cards, then one fills the frame.
    img = kb(A["glacier"], t / d, 1.12, 1.0, (0.4, 0.4), (0.6, 0.5)).convert("RGBA")
    img.alpha_composite(Image.new("RGBA", (W, H), (12, 10, 8, 90)))
    shots = [A["cathedral"], A["horsetail"], A["rapids"]]
    cw, ch = 520, 293
    gap = 60
    total = 3 * cw + 2 * gap
    for i, s in enumerate(shots):
        p = back_out(prog(t, 0.25 + i * 0.18, 0.95 + i * 0.18), 1.2)
        drift = -40 * (t / d)
        x = (W - total) / 2 + i * (cw + gap) + drift
        y = 430 + (1 - p) * 700
        framed(img, cover(s, cw * 2, ch * 2), (x, y, x + cw, y + ch), alpha=clamp(p * 2))
    headline(img, t, 0.1, [("Roam the whole park", CREAM)], 140, 170, size=88, out_t=d - 0.35)
    tag(img, t, 0.6, "Valley floor to Tuolumne, open from day one", 144, 300, out_t=d - 0.35)
    return img


def sc_people(A, t, d):
    # Portraits pop in across the frame, then the dialogue shot rises.
    img = Image.new("RGBA", (W, H), (52, 38, 28, 255))
    faces = A["faces"]
    order = [17, 3, 41, 28, 9, 22, 35, 0, 46, 13, 31, 6, 38, 19, 25, 44, 11, 2, 33, 48,
             15, 27, 7, 40, 21, 36, 4, 29, 12, 45, 24, 8, 39, 16, 30, 1, 47, 20, 34, 10]
    cols, rows, cs = 10, 4, 176
    ox, oy = (W - cols * cs) / 2 + 8, 300
    pan = -60 * (t / d)
    for k, idx in enumerate(order):
        c, r = k % cols, k // cols
        p = back_out(prog(t, 0.05 + k * 0.028, 0.45 + k * 0.028), 2.2)
        if p <= 0:
            continue
        sz = int(160 * max(0.01, p))
        f = faces[idx].resize((sz, sz), Image.NEAREST)
        x = int(ox + c * cs + pan + (160 - sz) / 2)
        y = int(oy + r * cs + (160 - sz) / 2)
        img.alpha_composite(f.convert("RGBA"), (x, y))
    # Dialogue shot slides up over the grid.
    p = ease_out(prog(t, 2.0, 2.7))
    if p > 0:
        w, h = 1280, 720
        x = (W - w) / 2
        y = H - (H - 300 + 40) * p + 40
        framed(img, cover(A["dialogue"], w, h, 1.0), (x, y, x + w, y + h))
    headline(img, t, 0.1, [("Meet the people who made its history", CREAM)], 140, 120, size=80, out_t=d - 0.35)
    tag(img, t, 0.9, "Muir, Adams, Lamon and dozens more", 144, 212, out_t=d - 0.35)
    return img


def sc_climb(A, t, d):
    # Split screen: the Nose on the left, a summit card flips in on the right.
    img = Image.new("RGBA", (W, H), BARK + (255,))
    split = W * 0.5
    left = kb(A["nose"], t / d, 1.25, 1.05, (0.3, 0.6), (0.3, 0.35), int(split), H)
    p = ease_out(prog(t, 0, 0.5))
    img.alpha_composite(left.convert("RGBA"), (int(-split * (1 - p)), 0))
    q = ease_out(prog(t, 0.25, 0.8))
    right = kb(A["summit"], t / d, 1.15, 1.0, (0.7, 0.4), (0.6, 0.5), W - int(split), H)
    img.alpha_composite(right.convert("RGBA"), (int(split + (W - split) * (1 - q)), 0))
    # gold seam
    ImageDraw.Draw(img).rectangle((split - 4, 0, split + 4, H), fill=GOLD)
    # Bivy card at the end
    r = back_out(prog(t, 2.0, 2.6), 1.3)
    if r > 0:
        w, h = 640, 360
        x, y = W - w - 90, H - h - 90 + (1 - r) * 500
        framed(img, A["bivy"], (x, y, x + w, y + h), alpha=clamp(r * 2))
    img.alpha_composite(Image.new("RGBA", (W, 360), (0, 0, 0, 0)))
    grad = np.zeros((300, W, 4), np.uint8)
    grad[..., 3] = (np.linspace(170, 0, 300)[:, None]).astype(np.uint8)
    img.alpha_composite(Image.fromarray(grad, "RGBA"), (0, 0))
    headline(img, t, 0.3, [("Climb the big walls", CREAM)], 120, 80, size=96, out_t=d - 0.35)
    tag(img, t, 0.9, "The Nose  ·  Half Dome  ·  a night on the wall", 124, 200, out_t=d - 0.35)
    return img


def sc_life(A, t, d):
    # 2x2 grid of valley-life shots, each tile with its own label.
    img = Image.new("RGBA", (W, H), (30, 42, 30, 255))
    tiles = [(A["cast"], "Fish"), (A["campfire"], "Cook"),
             (A["viewfinder"], "Photograph"), (A["wildlife"], "Spot wildlife")]
    g = 24
    tw, th = (W - 3 * g) / 2, (H - 3 * g) / 2
    for i, (s, label) in enumerate(tiles):
        c, r = i % 2, i // 2
        p = ease_out(prog(t, 0.1 + i * 0.2, 0.6 + i * 0.2))
        if p <= 0:
            continue
        x0 = g + c * (tw + g)
        y0 = g + r * (th + g)
        z = 1.25 - 0.12 * (t / d) - 0.1 * (1 - p)
        shot = cover(s, int(tw), int(th), z, 0.5, 0.55).convert("RGBA")
        # wipe in from one side
        wv = int(tw * p)
        if c == 0:
            img.alpha_composite(shot.crop((0, 0, wv, int(th))), (int(x0), int(y0)))
        else:
            img.alpha_composite(shot.crop((int(tw) - wv, 0, int(tw), int(th))), (int(x0 + tw - wv), int(y0)))
        tag(img, t, 0.5 + i * 0.2, label, int(x0 + 24), int(y0 + th - 88), out_t=d - 0.3)
    # centre badge
    b = back_out(prog(t, 1.2, 1.7), 1.6)
    if b > 0:
        s = "Live the valley life"
        size = int(72 * b)
        if size > 4:
            tw2, _ = text_size(s, size)
            cx, cy = W / 2, H / 2
            fade = 1 - prog(t, d - 0.35, d)
            panel(img, (cx - tw2 / 2 - 50, cy - size * 0.8, cx + tw2 / 2 + 50, cy + size * 0.8), alpha=fade)
            draw_text(img, (cx, cy), s, size, fill=CREAM, anchor="mm", alpha=fade)
    return img


def sc_seasons(A, t, d):
    # Quick-cut across seasons and times of day; a label ticks over.
    beats = [(A["snow"], "Winter"), (A["dusk"], "Dusk"), (A["camp4"], "Night at Camp 4"),
             (A["firefall"], "Firefall")]
    n = len(beats)
    seg = d / n
    i = min(n - 1, int(t / seg))
    lt = t - i * seg
    s, label = beats[i]
    img = kb(s, lt / seg, 1.18, 1.05, (0.45, 0.5), (0.55, 0.45)).convert("RGBA")
    # white flash on each cut
    fl = 1 - prog(lt, 0, 0.18)
    if i > 0 and fl > 0:
        img.alpha_composite(Image.new("RGBA", (W, H), (255, 250, 235, int(170 * fl))))
    grad = np.zeros((360, W, 4), np.uint8)
    grad[..., 3] = (np.linspace(0, 190, 360)[:, None]).astype(np.uint8)
    img.alpha_composite(Image.fromarray(grad, "RGBA"), (0, H - 360))
    draw_text(img, (140, H - 210), "Every season. Every hour.", 64, fill=GOLD,
              alpha=ease_out(prog(t, 0.1, 0.5)) * (1 - prog(t, d - 0.3, d)))
    p = ease_out(prog(lt, 0.05, 0.35))
    draw_text(img, (140 + (1 - p) * 40, H - 130), label, 52, fill=CREAM, alpha=p)
    return img


def sc_clouds(A, t, d):
    img = kb(A["clouds"], t / d, 1.0, 1.22, (0.5, 0.55), (0.48, 0.62)).convert("RGBA")
    headline(img, t, 0.4, [("Find your way", CREAM), ("above the clouds.", GOLD)], 140, 150, size=92,
             out_t=d - 0.4)
    return img


def sc_end(A, t, d):
    img = kb(A["title_bg"], t / d, 1.08, 1.0, (0.5, 0.45), (0.5, 0.5)).convert("RGBA")
    img.alpha_composite(Image.new("RGBA", (W, H), (14, 10, 24, 70)))
    logo = A["logo"]
    p = back_out(prog(t, 0.2, 1.0), 1.5)
    if p > 0:
        lw = int(logo.width * 1.05 * max(0.05, p))
        lh = int(logo.height * 1.05 * max(0.05, p))
        l = logo.resize((lw, lh), Image.BILINEAR)
        img.alpha_composite(l, (int((W - lw) / 2), int(250 + (logo.height * 1.05 - lh) / 2)))
    q = ease_out(prog(t, 1.0, 1.6))
    s = "A cozy pixel adventure in Yosemite"
    tw, _ = text_size(s, 50)
    if q > 0:
        panel(img, (W / 2 - tw / 2 - 44, 640 + (1 - q) * 30, W / 2 + tw / 2 + 44, 730 + (1 - q) * 30), alpha=q)
        draw_text(img, (W / 2, 685 + (1 - q) * 30), s, 50, fill=CREAM, anchor="mm", alpha=q, shadow=False)
    r = ease_out(prog(t, 1.8, 2.4))
    draw_text(img, (W / 2, 830), "Your Yosemite story starts here.", 44, fill=GOLD, anchor="mm", alpha=r)
    return img


SCENES = [
    (sc_open, 3.0),
    (sc_roam, 3.6),
    (sc_people, 4.4),
    (sc_climb, 4.0),
    (sc_life, 3.8),
    (sc_seasons, 3.6),
    (sc_clouds, 3.2),
    (sc_end, 4.4),
]
XF = 0.45  # cross-transition length


def frame(A, VIG, t):
    """Composite the frame at time t, with a diagonal wipe between scenes."""
    start = 0.0
    for k, (fn, d) in enumerate(SCENES):
        if t < start + d or k == len(SCENES) - 1:
            lt = t - start
            # Every scene after the first starts its clock XF early, under
            # the wipe that brings it in, so it is already moving.
            img = fn(A, lt + (XF if k else 0.0), d)
            if k + 1 < len(SCENES) and lt > d - XF:
                nfn, nd = SCENES[k + 1]
                nxt = nfn(A, lt - (d - XF), nd)
                p = ease_in_out((lt - (d - XF)) / XF)
                img = wipe(img, nxt, p)
            break
        start += d
    img.alpha_composite(VIG)
    # global fade in/out
    fi = 1 - prog(t, 0, 0.6)
    fo = prog(t, DUR - 0.8, DUR)
    a = max(fi, fo)
    if a > 0:
        img.alpha_composite(Image.new("RGBA", (W, H), (0, 0, 0, int(255 * a))))
    return img.convert("RGB")


def wipe(a, b, p):
    """Diagonal gold-edged wipe from a to b."""
    if p <= 0:
        return a
    if p >= 1:
        return b
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    slant = 400
    x = -slant + (W + 2 * slant) * p
    d.polygon([(0, 0), (x + slant / 2, 0), (x - slant / 2, H), (0, H)], fill=255)
    out = Image.composite(b, a, m)
    edge = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(edge).line([(x + slant / 2, 0), (x - slant / 2, H)], fill=GOLD + (255,), width=14)
    out.alpha_composite(edge)
    return out


# ---------------------------------------------------------------- audio
def scene_starts():
    s, out = 0.0, []
    for fn, d in SCENES:
        out.append(s - (XF if out else 0.0))  # when each scene's own clock reads 0
        s += d
    return out


def build_audio(path):
    st = scene_starts()
    # (file, start seconds, gain)
    sfx = [
        ("ui_open.wav", st[1], 0.5),
        ("talk.wav", st[2] + 2.0, 0.6),
        ("climb_cam.wav", st[3] + 0.3, 0.7),
        ("climb_topout.wav", st[3] + 0.9, 0.6),
        ("pickup.wav", st[4] + 0.2, 0.5),
        ("shutter.wav", st[4] + 0.6, 0.8),
        ("ui_move.wav", st[5] + 0.9, 0.5),
        ("ui_move.wav", st[5] + 1.8, 0.5),
        ("ui_move.wav", st[5] + 2.7, 0.5),
        ("story_sting.wav", st[7] + 0.15, 0.7),
    ]
    inputs = ["-i", P("assets/audio/music_title.wav")]
    filt = ["[0:a]atrim=0:%.2f,afade=t=in:d=0.6,afade=t=out:st=%.2f:d=2.2,volume=0.9[m]" % (DUR, DUR - 2.2)]
    labels = ["[m]"]
    for i, (f, at, g) in enumerate(sfx):
        inputs += ["-i", P("assets/audio", f)]
        ms = int(max(0, at) * 1000)
        filt.append("[%d:a]adelay=%d|%d,volume=%.2f[s%d]" % (i + 1, ms, ms, g, i))
        labels.append("[s%d]" % i)
    filt.append("%samix=inputs=%d:duration=first:normalize=0,alimiter=limit=0.95[out]" % ("".join(labels), len(labels)))
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error"] + inputs +
                   ["-filter_complex", ";".join(filt), "-map", "[out]", "-ac", "2", "-ar", "48000", path],
                   check=True)


# ---------------------------------------------------------------- main
def main():
    out = sys.argv[1] if len(sys.argv) > 1 else P("docs/valley_days_ad.mp4")
    only = os.environ.get("AD_STILLS")  # comma list of times: write PNGs only
    A = load_assets()
    VIG = vignette()
    if only:
        for s in only.split(","):
            frame(A, VIG, float(s)).save(os.path.splitext(out)[0] + "_%s.png" % s)
        return
    total = sum(d for _, d in SCENES)
    assert abs(total - DUR) < 1e-6, total
    with tempfile.TemporaryDirectory() as tmp:
        audio = os.path.join(tmp, "a.wav")
        build_audio(audio)
        enc = subprocess.Popen(
            ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24",
             "-s", "%dx%d" % (W, H), "-r", str(FPS), "-i", "-", "-i", audio,
             "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p",
             "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", "-shortest", out],
            stdin=subprocess.PIPE)
        n = int(DUR * FPS)
        for i in range(n):
            enc.stdin.write(frame(A, VIG, i / FPS).tobytes())
            if i % 60 == 0:
                print("frame %d/%d" % (i, n), flush=True)
        enc.stdin.close()
        enc.wait()
    print("wrote", out)


if __name__ == "__main__":
    main()
