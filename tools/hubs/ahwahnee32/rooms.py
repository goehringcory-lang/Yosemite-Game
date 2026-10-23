"""The six rooms of the Ahwahnee, each painted as one 32px picture under its
furniture. Layouts are in the rooms' own 32px pixels and follow the room specs
in tools/hubs/build_interiors.gd (sizes, back-wall depth and doors); where the
furniture stands is read from the built scene, so contact shadows and lamp
light land under the real pieces."""
from __future__ import annotations

import os
import re

import materials as M
from kit import ROOT, Canvas, hash2, math, np, radial, smoothstep, text, text_width


# ---------------------------------------------------------------- scene

def scene_props(room_id: str) -> list[dict]:
    """Every sprite in the room's built scene: where it stands (bottom
    middle), its texture and its frame size."""
    path = os.path.join(ROOT, "scenes", "regions", room_id + ".tscn")
    if not os.path.exists(path):
        return []
    text_ = open(path).read()
    tex = dict(re.findall(r'\[ext_resource type="Texture2D" path="res://([^"]+)" id="([^"]+)"\]', text_))
    tex = {v: k for k, v in tex.items()}
    out = []
    for block in re.split(r"\n(?=\[node )", text_):
        m = re.match(r'\[node name="([^"]+)" type="StaticBody2D" parent="Entities"', block)
        if not m:
            continue
        pos = re.search(r"position = Vector2\(([-\d.]+), ([-\d.]+)\)", block)
        if not pos:
            continue
        out.append({"name": m.group(1), "x": float(pos.group(1)), "y": float(pos.group(2)), "tex": None})
    # sprites are child nodes: match them to their parent body by name
    for block in re.split(r"\n(?=\[node )", text_):
        m = re.match(r'\[node name="Sprite" type="Sprite2D" parent="Entities/([^"]+)"', block)
        if not m:
            continue
        t = re.search(r'texture = ExtResource\("([^"]+)"\)', block)
        hf = re.search(r"hframes = (\d+)", block)
        for p in out:
            if p["name"] == m.group(1) and t:
                p["tex"] = tex.get(t.group(1))
                p["frames"] = int(hf.group(1)) if hf else 1
    return [p for p in out if p["tex"]]


def _size(tex: str, frames: int) -> tuple[int, int]:
    from PIL import Image
    w, h = Image.open(os.path.join(ROOT, tex)).size
    return w // frames, h


def furniture_light(delta: np.ndarray, room_id: str, wall_h: int) -> None:
    """Soft contact shadows under every piece, and pools of warm light
    round the lamps and the fires."""
    H, W = delta.shape
    for p in scene_props(room_id):
        w, h = _size(p["tex"], p.get("frames", 1))
        name = os.path.basename(p["tex"])
        x, y = p["x"], p["y"]
        if y < wall_h + 4:
            continue
        if "column" in name:
            delta += -1.2 * radial(H, W, x + 10, y - 2, w * 0.9, 9)
            continue
        if "info_sign" in name:
            delta += -0.9 * radial(H, W, x + 2, y - 1, 12, 4)
            continue
        if "lamp" in name and "desk" not in name:
            delta += 1.4 * radial(H, W, x, y - 4, 70, 46)
        if "hearth" in name:
            delta += 1.6 * radial(H, W, x, y + 26, w * 0.85, 70)
        rx = max(8.0, w * 0.5)
        delta += -1.1 * radial(H, W, x + 3, y - 2, rx, max(4.0, min(10.0, h * 0.12)))


def vignette(H: int, W: int, wall_h: int, strength: float = 1.0) -> np.ndarray:
    """Light falling off toward the corners, the ceiling and the front."""
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    dx = (xx - W / 2) / (W / 2)
    dy = (yy - H * 0.55) / (H * 0.55)
    v = dx * dx * 0.5 + dy * dy * 0.5
    d = -strength * smoothstep(0.35, 1.25, v) * 1.6
    # the wall dims toward the ceiling
    d += np.where(yy < wall_h, -0.9 * np.clip(1 - yy / wall_h, 0, 1) ** 1.6, 0.0)
    # the floor in the back wall's shade
    fl = (yy >= wall_h) & (yy < wall_h + 14)
    d += np.where(fl, -0.9 * (1 - (yy - wall_h) / 14), 0.0)
    return d.astype(np.float32)


# ---------------------------------------------------------------- walls round the room

def surround(cv: Canvas, wall_h: int, doors: list[dict], mat: list[str], seed: int) -> None:
    """The side walls and the front wall, seen from above: granite with a
    timber cap, and the openings through them."""
    W, H = cv.w, cv.h
    for sx in (0, W - 32):
        M.granite(cv, sx, 0, 32, H, seed + sx, course=16, light=-0.3)
        cap_x = sx + 26 if sx == 0 else sx
        M.timber(cv, cap_x, 0, 6, H, seed)
    M.granite(cv, 0, H - 32, W, 32, seed + 9, course=16, light=-0.4)
    M.timber(cv, 0, H - 32, W, 6, seed, vertical=False)
    for d in doors:
        if d["side"] == "left":
            M.door_side(cv, 0, d["row"] * 32, True)
        elif d["side"] == "right":
            M.door_side(cv, W - 32, d["row"] * 32, False)
        elif d["side"] == "front":
            M.door_front(cv, W // 2, H, mat)
    # inner corners
    cv.rect(32, wall_h, 2, H - wall_h - 32, "K0")
    cv.rect(W - 34, wall_h, 2, H - wall_h - 32, "K0")


def skirting(cv: Canvas, wall_h: int, seed: int, h: int = 20) -> None:
    M.granite(cv, 0, wall_h - h, cv.w, h, seed, course=h // 2)
    cv.hline(0, wall_h - h, cv.w, "G5")
    cv.hline(0, wall_h - 1, cv.w, "K0")


def finish(cv: Canvas, delta: np.ndarray) -> None:
    cv.tone(delta)


# ---------------------------------------------------------------- the rooms

def lobby() -> Canvas:
    W, H, wh, sd = 960, 544, 160, 81
    cv = Canvas(W, H)
    M.tiles(cv, 0, wh, W, H - wh, sd, a="T1", b="B3")
    M.inlay_border(cv, 64, wh + 24, W - 128, H - wh - 72)
    # the back wall: plaster over timber wainscot on a granite base
    M.plaster(cv, 0, 0, W, wh, sd)
    M.beam_ceiling(cv)
    for px in (140, 400, 560, 820):
        M.timber(cv, px - 7, 22, 14, wh - 22, sd + px)
        cv.rect(px - 10, 22, 20, 6, "B1")
        cv.hline(px - 10, 27, 20, "B0")
    M.frieze(cv, 104, 10)
    M.wainscot(cv, 0, 114, W, 28, sd)
    skirting(cv, wh, sd, 18)
    for x in (296, 616):
        M.timber(cv, x - 6, 28, 60, 80, sd)
        M.stained(cv, x, 34, 48, 68, sd + x)
        cv.rect(x - 8, 108, 64, 4, "G4")
        cv.hline(x - 8, 108, 64, "G5")
    _painting(cv, 192, 40, 84, 54, sd)
    _valley_map(cv, 690, 42, 66, 48)
    M.wall_sign(cv, 480, 30, "THE AHWAHNEE")
    M.arch(cv, 480, wh, "open", sd)
    for sx in (238, 722):
        M.sconce(cv, sx, 48)
    M.rug(cv, 336, 256, 288, 160, M.RUG_RED, ["B0", "O2", "T3"], sd)
    doors = [{"side": "left", "row": 11}, {"side": "right", "row": 11}, {"side": "front"}]
    surround(cv, wh, doors, ["B0", "R", "O2"], sd)
    d = vignette(H, W, wh)
    for sx in (238, 722):
        M.sconce_glow(d, sx, 48)
    for x in (296, 616):
        d += 0.8 * radial(H, W, x + 24, 70, 50, 50)
        M.window_shaft(d, x, 48, wh, 70, 0.5, 0.4)
    d += 0.5 * radial(H, W, 480, wh + 30, 70, 50)
    furniture_light(d, "ahwahnee_lobby", wh)
    finish(cv, d)
    return cv


def great_lounge() -> Canvas:
    W, H, wh, sd = 1408, 640, 224, 83
    cv = Canvas(W, H)
    M.planks(cv, 0, wh, W, H - wh, sd)
    M.board_formed(cv, 0, 0, W, wh, sd)
    M.beam_ceiling(cv, 24)
    skirting(cv, wh, sd, 22)
    # the chimney breasts behind the two great fireplaces
    for cx in (144, 1264):
        sub = Canvas(176, wh - 24)
        M.granite(sub, 0, 0, 176, wh - 24, sd + cx, course=14, light=0.2)
        cv.blit(sub, cx - 88, 24)
        cv.vline(cx - 89, 24, wh - 24, "K0")
        cv.vline(cx + 88, 24, wh - 24, "K0")
    # timber piers between the windows
    wins = [(280, "valley"), (400, "dome"), (540, "valley"), (788, "dome"), (928, "valley"), (1048, "meadow")]
    for x, _v in wins:
        for px in (x - 12, x + 92):
            M.timber(cv, px - 6, 24, 12, wh - 46, sd + px)
    for x, v in wins:
        M.tall_window(cv, x, 34, 80, wh - 62, v, 40, sd + x)
    M.arch(cv, 704, wh, "stone", sd)
    for sx in (250, 640, 768, 1158):
        M.sconce(cv, sx, 74)
    M.rug(cv, 220, 318, 300, 150, M.RUG_RED, ["B0", "O2", "T3"], sd)
    M.rug(cv, 868, 318, 300, 150, M.RUG_GREEN, ["B0", "O2", "R"], sd + 1)
    M.rug(cv, 576, 470, 256, 92, M.RUG_GOLD, ["B1", "R", "B0"], sd + 2)
    doors = [{"side": "left", "row": 14}]
    surround(cv, wh, doors, ["B0", "R", "O2"], sd)
    d = vignette(H, W, wh, 0.8)
    for x, _v in wins:
        M.window_shaft(d, x + 4, 72, wh, 170, 1.0, 0.45)
        d += 0.5 * radial(H, W, x + 40, 120, 60, 90)
    for sx in (250, 640, 768, 1158):
        M.sconce_glow(d, sx, 74, 40, 1.0)
    furniture_light(d, "ahwahnee_great_lounge", wh)
    finish(cv, d)
    return cv


def solarium() -> Canvas:
    W, H, wh, sd = 960, 544, 192, 87
    cv = Canvas(W, H)
    M.tiles(cv, 0, wh, W, H - wh, sd, a="T2", b="T2", grout="T0", dots=("P1", "O2"))
    M.inlay_border(cv, 64, wh + 20, W - 128, H - wh - 68, cols=("P1", "O2", "R", "T3"))
    M.board_formed(cv, 0, 0, W, wh, sd)
    M.beam_ceiling(cv, 18)
    skirting(cv, wh, sd, 16)
    wins = [(64, "meadow"), (236, "dome"), (604, "valley"), (776, "meadow")]
    for x, _v in wins:
        M.tall_window(cv, x, 28, 120, wh - 52, _v, 34, sd + x)
    # the middle pier: granite, with a round stained-glass light
    sub = Canvas(196, wh - 34)
    M.granite(sub, 0, 0, 196, wh - 34, sd, course=14, light=0.2)
    cv.blit(sub, 382, 18)
    cv.vline(381, 18, wh - 34, "K0")
    cv.vline(578, 18, wh - 34, "K0")
    cv.ellipse(480, 84, 34, 34, "B1")
    cv.ellipse(480, 84, 31, 31, "B0")
    ring = Canvas(60, 60)
    M.stained(ring, 0, 0, 60, 60, sd)
    mask = Canvas(60, 60)
    mask.ellipse(30, 30, 29, 29, "K0")
    ring.a[mask.a[..., 3] == 0] = 0
    cv.blit(ring, 450, 54)
    M.rug(cv, 320, 340, 320, 100, M.RUG_GREEN, ["B0", "O2", "T3"], sd)
    surround(cv, wh, [{"side": "front"}], ["P0", "P2", "O2"], sd)
    d = vignette(H, W, wh, 0.6)
    for x, _v in wins:
        M.window_shaft(d, x + 6, 112, wh, 240, 1.15, 0.5)
        d += 0.4 * radial(H, W, x + 60, 110, 80, 90)
    d += 0.6 * radial(H, W, 480, 84, 46, 46)
    furniture_light(d, "ahwahnee_solarium", wh)
    finish(cv, d)
    return cv


def dining_room() -> Canvas:
    W, H, wh, sd = 1536, 640, 224, 89
    cv = Canvas(W, H)
    M.planks(cv, 0, wh, W, H - wh, sd, tones=("B2", "B2", "B3", "B2"))
    M.board_formed(cv, 0, 0, W, wh, sd)
    wins = [(116, "valley"), (316, "dome"), (516, "valley"), (936, "valley"), (1136, "dome"), (1336, "forest")]
    for x, v in wins:
        M.tall_window(cv, x, 40, 88, wh - 66, v, 42, sd + x)
    # sugar pine trusses: knee braces from each pier up to the beam
    M.beam_ceiling(cv, 26)
    for px in (260, 460, 660, 880, 1080, 1280):
        for s in (-1, 1):
            for t in range(6):
                cv.line(px + s * 8, 92 + t, px + s * 52, 26 + t, "B1" if t not in (0, 5) else ("B3" if t == 0 else "B0"))
        cv.rect(px - 56, 26, 112, 8, "B1")
        cv.hline(px - 56, 26, 112, "B3")
        cv.hline(px - 56, 33, 112, "B0")
    skirting(cv, wh, sd, 22)
    M.wall_sign(cv, 770, 70, "THE DINING ROOM")
    for sx in (712, 828):
        M.sconce(cv, sx, 104)
    doors = [{"side": "right", "row": 14}]
    surround(cv, wh, doors, ["B0", "R", "O2"], sd)
    d = vignette(H, W, wh, 0.8)
    for x, _v in wins:
        M.window_shaft(d, x + 4, 80, wh, 190, 0.9, 0.45)
        d += 0.4 * radial(H, W, x + 44, 130, 60, 90)
    for sx in (712, 828):
        M.sconce_glow(d, sx, 104, 40, 1.1)
    for cx in (360, 768, 1176):
        d += 0.7 * radial(H, W, cx, 380, 190, 90)
    furniture_light(d, "ahwahnee_dining_room", wh)
    finish(cv, d)
    return cv


def mural_room() -> Canvas:
    W, H, wh, sd = 960, 544, 160, 91
    cv = Canvas(W, H)
    M.tiles(cv, 0, wh, W, H - wh, sd, a="T1", b="B3")
    M.inlay_border(cv, 64, wh + 24, W - 128, H - wh - 72)
    M.plaster(cv, 0, 0, W, wh, sd, base="T3")
    M.beam_ceiling(cv, 16)
    for x in (80, 600):
        _mural(cv, x, 24, 280, 112, sd + x)
    M.frieze(cv, 140, 8)
    skirting(cv, wh, sd, 12)
    M.arch(cv, 480, wh, "elevator", sd)
    M.rug(cv, 344, 280, 272, 140, M.RUG_GREEN, ["B0", "O2", "R"], sd)
    surround(cv, wh, [{"side": "front"}], ["B0", "R", "O2"], sd)
    d = vignette(H, W, wh)
    for x in (80, 600):
        d += 0.3 * radial(H, W, x + 140, 80, 180, 70)
    d += 0.7 * radial(H, W, 480, wh - 30, 60, 60)
    furniture_light(d, "ahwahnee_mural_room", wh)
    finish(cv, d)
    return cv


def guest_room() -> Canvas:
    W, H, wh, sd = 960, 544, 160, 93
    cv = Canvas(W, H)
    M.carpet(cv, 0, wh, W, H - wh, sd, base="P1", motif="P2", border="O1")
    M.plaster(cv, 0, 0, W, wh, sd, base="T3")
    M.timber(cv, 0, 0, W, 8, sd, vertical=False)
    M.frieze(cv, 8, 10)
    M.wainscot(cv, 0, 118, W, 32, sd)
    skirting(cv, wh, sd, 10)
    # the window onto Half Dome, with drapes
    M.tall_window(cv, 600, 30, 160, 102, "dome", 0, sd)
    for side in (0, 1):
        _drape(cv, 584 if side == 0 else 742, 22, 34, 118, side)
    cv.rect(578, 18, 204, 6, "B1")
    cv.hline(578, 18, 204, "B3")
    for k in (578, 780):
        cv.ellipse(k, 21, 4, 4, "O2")
    _painting(cv, 170, 34, 100, 66, sd + 3)
    for sx in (300, 480):
        M.sconce(cv, sx, 56)
    M.rug(cv, 240, 300, 240, 120, M.RUG_RED, ["B0", "O2", "T3"], sd)
    surround(cv, wh, [{"side": "front"}], ["B0", "R", "O2"], sd)
    d = vignette(H, W, wh)
    for sx in (300, 480):
        M.sconce_glow(d, sx, 56, 40, 1.1)
    M.window_shaft(d, 606, 150, wh, 150, 1.0, 0.5)
    d += 0.6 * radial(H, W, 680, 80, 110, 80)
    furniture_light(d, "ahwahnee_guest_room", wh)
    finish(cv, d)
    return cv


ROOMS = {
    "ahwahnee_lobby": lobby,
    "ahwahnee_great_lounge": great_lounge,
    "ahwahnee_solarium": solarium,
    "ahwahnee_dining_room": dining_room,
    "ahwahnee_mural_room": mural_room,
    "ahwahnee_guest_room": guest_room,
}


# ---------------------------------------------------------------- wall pieces

def _painting(cv: Canvas, cx: int, y: int, w: int, h: int, sd: int) -> None:
    """A gilt-framed oil of the Valley: El Capitan, a fall and the meadow."""
    x = cx - w // 2
    cv.rect(x - 5, y - 5, w + 10, h + 10, "O1")
    cv.frame(x - 5, y - 5, w + 10, h + 10, "O0")
    cv.hline(x - 4, y - 4, w + 8, "O3")
    cv.vline(x - 4, y - 4, h + 8, "O2")
    cv.frame(x - 1, y - 1, w + 2, h + 2, "B0")
    for yy in range(h):
        v = yy / h
        for xx in range(w):
            u = xx / w
            ridge = 0.25 + 0.5 * (u - 0.2) ** 2 if u < 0.55 else 0.33 + 0.12 * math.sin(u * 9)
            if v < ridge:
                c = ["A3", "T3", "W4", "W4"][min(3, int(v * 9 + (hash2(xx, yy, 1) * 0.8)))]
            elif v < 0.74:
                c = ["G5", "G4", "G4", "G3"][min(3, int((v - ridge) * 7 + (1.5 if u > 0.55 else 0) + hash2(xx, yy, 2) * 0.6))]
            elif v < 0.84:
                c = "P1" if hash2(xx // 2, yy // 2, 3) > 0.4 else "P2"
            else:
                c = "M1" if hash2(xx, yy, 4) > 0.5 else "O2"
            cv.px(x + xx, y + yy, c)
    fx = x + int(w * 0.68)
    cv.vline(fx, y + int(h * 0.36), int(h * 0.38), "N")
    cv.vline(fx + 1, y + int(h * 0.36), int(h * 0.38), "W4")
    cv.rect(x + w + 5, y - 3, 2, h + 9, "B0")
    cv.rect(x - 3, y + h + 5, w + 10, 2, "B0")


def _valley_map(cv: Canvas, cx: int, y: int, w: int, h: int) -> None:
    """A framed map of the Valley floor and the river."""
    x = cx - w // 2
    cv.rect(x - 3, y - 3, w + 6, h + 6, "B0")
    cv.rect(x - 2, y - 2, w + 4, h + 4, "B2")
    cv.rect(x, y, w, h, "T3")
    for i in range(14):
        px = x + 3 + int(hash2(i, 1, 5) * (w - 8))
        py = y + 3 + int(hash2(i, 2, 5) * (h - 8))
        cv.ellipse(px, py, 3 + hash2(i, 3, 5) * 4, 2 + hash2(i, 4, 5) * 3, "M2")
    for xx in range(w):
        yy = y + h // 2 + int(math.sin(xx * 0.18) * 4 + math.sin(xx * 0.05) * 3)
        cv.px(x + xx, yy, "W2")
        cv.px(x + xx, yy + 1, "W3")
    cv.rect(x, y, w, 9, "G3")
    cv.rect(x, y + h - 7, w, 7, "G3")
    for xx in range(0, w, 3):
        cv.px(x + xx, y + 9, "G2")
    cv.px(x + w // 2 + 6, y + h // 2 - 4, "R")
    cv.rect(x + w + 3, y, 2, h + 5, "B0")


def _hanging_fern(cv: Canvas, x: int, y: int, sd: int) -> None:
    cv.vline(x, y, 22, "K0")
    cv.ellipse(x, y + 30, 11, 7, "O1")
    cv.ellipse(x, y + 28, 11, 4, "O2")
    cv.hline(x - 10, y + 27, 21, "O3")
    for i in range(16):
        ang = math.pi * (0.05 + 0.9 * i / 15)
        ln = 14 + hash2(i, 1, sd) * 10
        ex, ey = x - math.cos(ang) * ln, y + 26 + math.sin(ang) * ln * 0.9
        cv.line(x - math.cos(ang) * 4, y + 26, ex, ey, "P2" if i % 3 else "P3")
        cv.px(ex, ey, "P1")


def _chandelier(cv: Canvas, cx: int, y0: int, y1: int) -> None:
    """A wrought-iron ring of candles on a chain."""
    for y in range(y0, y1, 3):
        cv.px(cx, y, "K0")
        cv.px(cx, y + 1, "G1")
    cv.ellipse(cx, y1 + 8, 30, 7, "K0")
    cv.ellipse(cx, y1 + 7, 27, 5, "G0")
    cv.ellipse(cx, y1 + 7, 25, 4, "K0")
    for i in range(9):
        a = math.pi * 2 * i / 9
        bx = cx + math.cos(a) * 26
        by = y1 + 8 + math.sin(a) * 6
        cv.rect(bx - 1, by - 7, 3, 7, "N")
        cv.px(bx, by - 9, "A3")
        cv.px(bx, by - 8, "A2")
        cv.px(bx, by - 10, "O3")
    cv.line(cx, y1, cx - 26, y1 + 8, "K0")
    cv.line(cx, y1, cx + 26, y1 + 8, "K0")


def _drape(cv: Canvas, x: int, y: int, w: int, h: int, side: int) -> None:
    """Heavy drapes in the hotel's red, gathered by a tieback."""
    for xx in range(w):
        fold = math.sin(xx * 0.7) * 0.5 + 0.5
        for yy in range(h):
            pinch = 0.6 if 64 < yy < 72 else 1.0
            ramp = M.RED
            v = fold * pinch + (0.15 if side == 0 else -0.1)
            c = ramp[min(3, max(0, int(v * 3.2 + (hash2(xx, yy // 6, 2) - 0.5) * 0.4)))]
            cv.px(x + xx, y + yy, c)
    cv.rect(x, y + 66, w, 4, "O1")
    cv.hline(x, y + 66, w, "O3")
    cv.hline(x, y + h - 1, w, "B0")


def _mural(cv: Canvas, x: int, y: int, w: int, h: int, sd: int) -> None:
    """Robert Boardman Howard's mural: the Valley's forest and wildlife in
    flat, soft colors on a ground of gold leaf, like a Japanese screen."""
    M.timber(cv, x - 6, y - 6, w + 12, h + 12, sd, vertical=False)
    cv.rect(x - 2, y - 2, w + 4, h + 4, "B0")
    # gold leaf, laid in squares
    for yy in range(0, h, 10):
        for xx in range(0, w, 10):
            c = "O3" if hash2(xx // 10, yy // 10, sd) > 0.3 else "A3"
            cv.rect(x + xx, y + yy, 10, 10, c)
            cv.hline(x + xx, y + yy, 10, "O2")
    # soft cliffs, flat grey-blue with a lit side
    for xx in range(w):
        top = int(h * (0.22 + 0.13 * math.sin(xx * 0.03 + sd) + 0.05 * math.sin(xx * 0.11)))
        slope = math.cos(xx * 0.03 + sd) * 0.13 + math.cos(xx * 0.11) * 0.05
        cv.rect(x + xx, y + top, 1, int(h * 0.62) - top, "G4" if slope < 0.02 else "G3")
        cv.px(x + xx, y + top, "G5")
    # mist drifting along the cliff foot
    for xx in range(w):
        my = y + int(h * 0.56 + 3 * math.sin(xx * 0.05))
        if math.sin(xx * 0.09 + sd) > -0.3:
            cv.rect(x + xx, my, 1, 3, "N")
    # the forest: flat cedars and pines
    for i, tx in enumerate(range(x + 8, x + w - 4, 18)):
        th = 34 + int(hash2(i, 1, sd) * 26)
        base = y + h - 6
        for k in range(th):
            half = int((k / th) * 9) + 1
            if (th - k) % 7 < 2 and k > 4:
                half -= 2
            cv.hline(tx - half, base - th + k, half * 2 + 1, "P1" if i % 2 else "P2")
        cv.vline(tx, base - 4, 6, "B1")
    cv.rect(x, y + h - 6, w, 6, "M0")
    cv.hline(x, y + h - 6, w, "M1")
    # deer browsing at the forest edge, and a pair of birds
    for k, dx in enumerate((w // 3, int(w * 0.72))):
        _deer(cv, x + dx, y + h - 7, k % 2 == 0)
    for bx, by in ((x + 40, y + 20), (x + 52, y + 26), (x + w - 60, y + 16)):
        cv.hline(bx - 2, by, 2, "B1")
        cv.hline(bx + 1, by, 2, "B1")
        cv.px(bx, by + 1, "B1")


def _deer(cv: Canvas, x: int, y: int, facing_left: bool) -> None:
    s = -1 if facing_left else 1
    cv.rect(x - 7, y - 12, 14, 6, "T1")
    cv.hline(x - 7, y - 12, 14, "T2")
    for lx in (-6, -3, 3, 6):
        cv.vline(x + lx, y - 6, 6, "T0")
    cv.rect(x + s * 7 - (1 if s < 0 else 0), y - 18, 2, 7, "T1")
    cv.rect(x + s * 8 - (2 if s < 0 else 0), y - 20, 4, 3, "T1")
    cv.px(x + s * 8, y - 22, "B1")
    cv.px(x - s * 8, y - 11, "N")
