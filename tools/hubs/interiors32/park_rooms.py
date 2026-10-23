"""The insides of the park's buildings (all but the Ahwahnee's six rooms,
which ahwahnee32/rooms.py paints), each painted as one 32px picture under
its furniture, straight from its spec in tools/hubs/build_interiors.gd:
the floor, the back wall and what hangs on it, the rugs, the side and front
walls and their doors, then the light: daylight through the windows and
across the floor, lamps and fires, and a soft shadow under every piece of
furniture where the built scene stands it."""
from __future__ import annotations

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "ahwahnee32"))
sys.path.insert(0, HERE)

import decor as D  # noqa: E402
import materials as M  # noqa: E402
import specs as SP  # noqa: E402
import walls as WL  # noqa: E402
from kit import BAYER, C, Canvas, down, np, radial, up  # noqa: E402
import rooms as AR  # noqa: E402  (the Ahwahnee's: scene reading, vignette, furniture light)

# What each room's windows look out on.
VIEWS = {
    "welcome_center": "valley", "yosemite_museum": "valley", "bests_studio": "valley",
    "wilderness_center": "forest", "valley_post_office": "valley", "degnans": "valley",
    "village_store_inside": "forest", "valley_lodge_lobby": "valley", "yosemite_chapel": "valley",
    "curry_registration": "forest", "curry_pavilion": "forest",
    "glacier_snack_stand": "dome", "geology_hut": "dome",
    "el_portal_market": "forest", "el_portal_post_office": "forest", "yosemite_view_lodge": "forest",
    "wawona_store": "meadow", "wawona_hotel_lobby": "meadow", "wawona_hotel_dining": "meadow",
    "hill_studio": "meadow", "clark_cottage": "meadow", "washburn_cottage": "meadow",
    "hodgdon_cabin": "meadow", "wells_fargo": "meadow", "artist_studio": "meadow",
    "blacksmith_shop": "meadow", "wawona_jail": "meadow", "grove_museum": "forest",
    "parsons_lodge": "meadow", "mccauley_cabin": "meadow", "tuolumne_visitor_center": "meadow",
    "tuolumne_store": "meadow", "tuolumne_lodge": "meadow",
}

# Parlors hang curtains at their windows: the fabric's ramp.
CURTAINS = {
    "wawona_hotel_lobby": ["P0", "P1", "P2", "P3"], "wawona_hotel_dining": ["P0", "P1", "P2", "P3"],
    "washburn_cottage": ["B1", "A0", "R", "A1"], "clark_cottage": ["P0", "P1", "P2", "P3"],
    "hill_studio": ["T1", "T2", "T3", "N"], "yosemite_view_lodge": ["B1", "A0", "R", "A1"],
}


def wall_tone(spec: dict) -> str:
    """The wall's palette color. Pale painted walls stay pale; timber walls
    keep a warm mid tone so the furniture reads against them."""
    kind, hexc = spec["wall"][0], spec["wall"][1]
    c = WL.nearest(hexc)
    if kind in ("lap", "plaster", "stucco", "canvas") and c in ("N", "G4"):
        return "G5"
    return c


# Spec colors whose nearest palette color loses their hue.
HUES = {"4a5a4a": "P1", "6a2a2a": "R", "4a5a6a": "W1", "3a5a3a": "P1", "2f4a34": "P1"}


def hue(hexc: str) -> str:
    return HUES.get(hexc, WL.nearest(hexc))


def wine(cv: Canvas, x: int, y: int, w: int, h: int) -> None:
    """Deepens the palette's red to a wine red where it fills an area: half
    its pixels, in ordered dither, go to dark bark."""
    area = cv.a[y:y + h, x:x + w]
    yy, xx = np.mgrid[y:y + area.shape[0], x:x + area.shape[1]]
    red = np.all(area[..., :3] == np.array(C["R"], np.uint8), axis=-1)
    area[..., :3][red & (BAYER[yy & 3, xx & 3] < 0.45)] = C["B1"]


def floor_tone(spec: dict) -> str:
    c = WL.nearest(spec["floor"][1])
    return {"T0": "B2", "B1": "B2"}.get(c, c) if spec["floor"][0] == "planks" else c


def paint_wall(cv: Canvas, spec: dict, x: int, y: int, w: int, h: int, sd: int, side: bool = False) -> None:
    kind = spec["wall"][0]
    base = wall_tone(spec)
    if side and spec.get("side"):
        base = WL.nearest(spec["side"])
        if base == "N":
            base = "G5"
    if kind == "boards" or (side and kind in ("lap", "plaster", "stucco", "logs") and spec.get("side")):
        if kind == "lap":
            WL.lap(cv, x, y, w, h, base, sd)
        else:
            WL.boards(cv, x, y, w, h, base, sd)
    elif kind == "logs":
        WL.logs(cv, x, y, w, h, base, sd)
    elif kind == "lap":
        WL.lap(cv, x, y, w, h, base, sd)
    elif kind == "plaster":
        WL.plaster(cv, x, y, w, h, base, sd, warm=WL.warmth(spec["wall"][1]) if base in ("G4", "G5") else 0.0)
    elif kind == "stucco":
        WL.stucco(cv, x, y, w, h, base, sd, warm=WL.warmth(spec["wall"][1]) if base in ("G4", "G5") else 0.0)
    elif kind == "granite":
        M.granite(cv, x, y, w, h, sd, course=16)
    elif kind == "stone":
        WL.fieldstone(cv, x, y, w, h, sd, light=-0.4)
    elif kind == "canvas":
        WL.canvas_wall(cv, x, y, w, h, base, sd)
    else:
        cv.rect(x, y, w, h, base)


def paint_floor(cv: Canvas, spec: dict, wh: int, sd: int) -> None:
    W, H = cv.w, cv.h
    kind = spec["floor"][0]
    base = floor_tone(spec)
    if kind == "planks":
        WL.planks(cv, 0, wh, W, H - wh, base, sd)
    elif kind == "tile":
        a = WL.nearest(spec["floor"][1])
        b = WL.nearest(spec["floor"][2]) if len(spec["floor"]) > 2 else down(a)
        if b not in ("R", "A0"):
            # the second tile halfway to the spec's, as the 16px builder mixed it
            h1, h2 = spec["floor"][1], spec["floor"][2]
            mix = "".join("%02x" % ((int(h1[i:i + 2], 16) + int(h2[i:i + 2], 16)) // 2) for i in (0, 2, 4))
            b = WL.nearest(mix)
            if b == a:
                b = down(a)
        else:
            b = "R"
        dots = None
        if b == "R":
            # a deli's cream and tan check, the red kept for small inset squares
            b, dots = "T2", ("R", "A1")
        WL.checker(cv, 0, wh, W, H - wh, a, b, sd, size=32, dots=dots)
    elif kind == "stone":
        WL.flagstones(cv, 0, wh, W, H - wh, base, sd)
    elif kind == "carpet":
        base = hue(spec["floor"][1])
        motif = WL.nearest(spec["floor"][2]) if len(spec["floor"]) > 2 else up(base)
        M.carpet(cv, 0, wh, W, H - wh, sd, base=base, motif=up(base) if base != "R" else "A1", border=motif)
        if base == "R":
            wine(cv, 0, wh, W, H - wh)
    elif kind == "dirt":
        WL.earth(cv, 0, wh, W, H - wh, base, sd)
    else:
        cv.rect(0, wh, W, H - wh, base)


def surround(cv: Canvas, spec: dict, wh: int, sd: int) -> None:
    """The side walls and the front wall, seen from above, and the doors
    through them."""
    W, H = cv.w, cv.h
    kind = spec["wall"][0]
    for sx in (0, W - 32):
        if kind == "granite":
            M.granite(cv, sx, 0, 32, H, sd + sx, course=16, light=-0.3)
        elif kind == "stone":
            WL.fieldstone(cv, sx, 0, 32, H, sd + sx, light=-0.3)
        elif kind == "canvas":
            WL.canvas_wall(cv, sx, 0, 32, H, WL.nearest(spec.get("side", spec["wall"][1])), sd + sx)
            cv.tone(np.full((H, 32), -0.4, np.float32), x=sx)
        elif kind == "logs":
            _log_ends(cv, sx, H, wall_tone(spec), sd + sx)
        else:
            base = WL.nearest(spec.get("side", "8a6440"))
            if kind == "lap" and spec.get("side"):
                WL.lap(cv, sx, 0, 32, H, "G5" if base == "N" else base, sd + sx)
            else:
                WL.boards(cv, sx, 0, 32, H, base, sd + sx, bw=16, batten=False)
            cv.tone(np.full((H, 32), -0.4, np.float32), x=sx)
        cap_x = sx + 26 if sx == 0 else sx
        M.timber(cv, cap_x, 0, 6, H, sd)
    if kind == "granite":
        M.granite(cv, 0, H - 32, W, 32, sd + 9, course=16, light=-0.4)
    elif kind == "stone":
        WL.fieldstone(cv, 0, H - 32, W, 32, sd + 9, light=-0.4)
    elif kind == "logs":
        WL.logs(cv, 0, H - 32, W, 32, wall_tone(spec), sd + 9)
        cv.tone(np.full((32, W), -0.5, np.float32), y=H - 32)
    else:
        base = WL.nearest(spec.get("side", "8a6440"))
        if kind == "canvas":
            WL.canvas_wall(cv, 0, H - 32, W, 32, base, sd + 9)
        elif kind == "lap" and spec.get("side"):
            WL.lap(cv, 0, H - 32, W, 32, "G5" if base == "N" else base, sd + 9)
        else:
            WL.boards(cv, 0, H - 32, W, 32, base, sd + 9, bw=16, batten=False)
        cv.tone(np.full((32, W), -0.5, np.float32), y=H - 32)
    M.timber(cv, 0, H - 32, W, 6, sd, vertical=False)
    mat = WL.nearest(spec.get("mat", "7a3a2a"))
    mat_ramp = {"P1": ["P0", "P1", "O2"], "P0": ["P0", "P1", "O2"]}.get(mat, ["B0", "R", "O2"])
    for d in spec["doors"]:
        if d["side"] == "left":
            M.door_side(cv, 0, d["row"] * 32, True)
        elif d["side"] == "right":
            M.door_side(cv, W - 32, d["row"] * 32, False)
        elif d["side"] == "front":
            M.door_front(cv, W // 2, H, mat_ramp)
        elif d["side"] == "back":
            M.arch(cv, d["x"] * 2, wh, d.get("look", "wood"), sd)
    cv.rect(32, wh, 2, H - wh - 32, "K0")
    cv.rect(W - 34, wh, 2, H - wh - 32, "K0")


def _log_ends(cv: Canvas, sx: int, H: int, base: str, sd: int) -> None:
    """A log wall seen end-on from above: the logs' top faces running back,
    chinked between."""
    WL.boards(cv, sx, 0, 32, H, down(base), sd, bw=16, batten=False)
    cv.tone(np.full((H, 32), -0.3, np.float32), x=sx)
    for y in range(0, H, 16):
        cv.hline(sx, y, 32, "T1")


# ---------------------------------------------------------------- one room

def paint(room_id: str) -> Canvas:
    spec = SP.load()[room_id]
    return paint_spec(spec)


def paint_spec(spec: dict) -> Canvas:
    room_id = spec["id"]
    W, H = spec["size"][0] * 32, spec["size"][1] * 32
    wh = spec["rows"] * 32
    sd = spec.get("seed", 7)
    view = VIEWS.get(room_id, "valley")
    cv = Canvas(W, H)
    paint_floor(cv, spec, wh, sd)
    paint_wall(cv, spec, 0, 0, W, wh, sd + 1)
    wall = wall_tone(spec)
    beams = spec.get("beams", False)
    if spec.get("wainscot"):
        WL.wainscot(cv, 0, wh - 40, W, 34, hue(spec["wainscot"]), sd + 2)
        wine(cv, 0, wh - 40, W, 34)
    if beams:
        top = 16
        M.timber(cv, 0, 0, W, top, sd, vertical=False)
        cv.hline(0, top, W, "K0")
        dd = np.zeros((8, W), np.float32)
        for i in range(8):
            dd[i] = -1.2 * (1 - i / 8)
        cv.tone(dd, y=top + 1)
    elif spec["wall"][0] not in ("canvas", "logs", "granite", "stone"):
        WL.cornice(cv, W, down(wall) if wall in ("G5", "T3") else wall)
    # baseboard along the foot of the back wall
    WL.skirting(cv, 0, wh, W, "B1" if spec["wall"][0] != "granite" else "G2", 8)
    if beams:
        for bx in range(60, W - 40, 192):
            M.timber(cv, bx, 16, 10, wh - 24 - (40 if spec.get("wainscot") else 0), sd + bx)
    lights: list[tuple] = []
    for d in spec.get("deco", []):
        _deco(cv, d, wh, sd, view, lights, room_id, spec.get("deco", []))
    for r in spec.get("rugs", []):
        x, y, w, h = r[0] * 2, r[1] * 2, r[2] * 2, r[3] * 2
        field = WL.ramp4(WL.nearest(r[4]))
        if field[1] in ("R", "A0"):
            field = M.RUG_RED
        elif field[1].startswith("P"):
            field = M.RUG_GREEN
        elif field[1].startswith("O"):
            field = M.RUG_GOLD
        accent = [WL.nearest(r[6]), "O2" if WL.nearest(r[5]) in ("T3", "G5", "N") else WL.nearest(r[5]), "T3"]
        if accent[0] == field[1]:
            accent[0] = "B0"
        M.rug(cv, x, y, w, h, field, accent, sd + x)
    surround(cv, spec, wh, sd)
    # the light
    dl = AR.vignette(H, W, wh, 0.8)
    light = spec.get("light", 1.0)
    if light < 1.0:
        dl -= (1.0 - light) * 3.0
    for kind, *args in lights:
        if kind == "window":
            x, y, w, h, ln, slant = args
            dl += 0.5 * radial(H, W, x + w / 2, y + h / 2, w * 0.9 + 16, h * 0.9 + 16)
            M.window_shaft(dl, x, w, wh, ln, 0.9, slant)
        elif kind == "sconce":
            M.sconce_glow(dl, args[0], args[1], 40, 1.1)
        elif kind == "glass":
            x, w = args
            dl += 0.4 * radial(H, W, x + w / 2, wh * 0.5, w, wh * 0.6)
            M.window_shaft(dl, x, w, wh, 160, 0.8, 0.4)
    AR.furniture_light(dl, room_id, wh)
    warm = np.zeros((H, W), np.float32)
    for p in AR.scene_props(room_id):
        name = os.path.basename(p["tex"])
        if "forge" in name or "stove" in name:
            # embers glowing through the firebox
            dl += 1.0 * radial(H, W, p["x"], p["y"] + 6, 64, 40)
            warm += radial(H, W, p["x"], p["y"] + 6, 64, 40)
        elif "hearth" in name:
            warm += radial(H, W, p["x"], p["y"] + 26, 90, 70)
        elif "lamp" in name and "desk" not in name:
            warm += 0.8 * radial(H, W, p["x"], p["y"] - 4, 60, 40)
    for kind, *args in lights:
        if kind == "sconce":
            warm += 0.7 * radial(H, W, args[0], args[1] + 6, 36, 30)
    cv.tone(dl)
    firelight(cv, np.clip(warm, 0, 1))
    return cv


# Granite and pale colors under fire or lamp light, warmed to the amber ramp.
_WARM = {"G2": "T1", "G3": "T2", "G4": "T3", "G5": "A3", "N": "A3", "W4": "T3", "W5": "A3"}


def firelight(cv: Canvas, s: np.ndarray) -> None:
    """Warms the cool greys where fire or lamp light falls (s 0..1), in
    ordered dither, so a hearth glows amber on stone instead of white."""
    yy, xx = np.mgrid[0:cv.h, 0:cv.w]
    pick = BAYER[yy & 3, xx & 3] < s * 0.85
    for a, b in _WARM.items():
        m = pick & np.all(cv.a[..., :3] == np.array(C[a], np.uint8), axis=-1)
        cv.a[..., :3][m] = C[b]


def _deco(cv: Canvas, d: list, wh: int, sd: int, view: str, lights: list, room_id: str, deco_all: list) -> None:
    k = d[0]
    if k == "window":
        x, y, w, h = d[1] * 2, d[2] * 2, d[3] * 2, d[4] * 2
        ln = (d[5] if len(d) > 5 else 60) * 2
        slant = (d[6] if len(d) > 6 else 0) / max(1, (d[5] if len(d) > 5 else 60))
        D.window(cv, x, y, w, h, view, sd + x, CURTAINS.get(room_id))
        lights.append(("window", x, y, w, h, ln, slant))
    elif k == "tall_window":
        x, w = d[1] * 2, d[2] * 2
        v = d[3] if len(d) > 3 else "valley"
        M.tall_window(cv, x, 24, w, wh - 56, v, 0, sd + x)
        lights.append(("glass", x, w))
    elif k == "frame":
        D.frame(cv, d[1] * 2, d[2] * 2, d[3] * 2, d[4] * 2, d[5], sd + d[1])
    elif k == "stained":
        D.stained(cv, d[1] * 2, d[2] * 2, d[3] * 2, d[4] * 2, sd + d[1])
    elif k == "lancet":
        x, y, w, h = d[1] * 2, d[2] * 2, d[3] * 2, d[4] * 2
        D.lancet(cv, x, y, w, h, sd + x)
        lights.append(("window", x, y, w, h, 120, 0.2))
    elif k == "band":
        cols = [WL.nearest(c) for c in (d[3] if len(d) > 3 else ["8a2f2f", "e8d8a8", "2f4a34", "c89a3a"])]
        M.frieze(cv, d[1] * 2, d[2] * 2, ground=cols[0], cols=(cols[2] if cols[2] != cols[0] else "R", cols[1], cols[3], "R"))
    elif k == "sign":
        D.sign(cv, d[1] * 2, d[2] * 2, d[3])
    elif k == "sconce":
        D.sconce(cv, d[1] * 2, d[2] * 2)
        lights.append(("sconce", d[1] * 2, d[2] * 2))
    elif k == "clock":
        D.clock(cv, d[1] * 2, d[2] * 2)
    elif k == "shelf":
        D.shelf(cv, d[1] * 2, d[2] * 2, d[3] * 2, d[4], sd + d[1])
    elif k == "pegs":
        D.pegs(cv, d[1] * 2, d[2] * 2, d[3] * 2, d[4], sd + d[1])
    elif k == "pboxes":
        D.po_boxes(cv, d[1] * 2, d[2] * 2, d[3] * 2, d[4] * 2)
    elif k == "bars":
        D.bars(cv, d[1] * 2, d[2] * 2, d[3] * 2, wh)
    elif k == "cross":
        D.cross(cv, d[1] * 2, d[2] * 2)
    elif k == "flag":
        D.flag(cv, d[1] * 2, d[2] * 2, left=any(o[0] in ("clock", "sign") and 0 < o[1] - d[1] < 40 for o in deco_all))
    elif k == "baskets":
        D.baskets(cv, d[1] * 2, d[2] * 2, d[3] * 2, sd + d[1])
    elif k == "poster":
        D.frame(cv, d[1] * 2, d[2] * 2, d[3] * 2, d[4] * 2, "poster", sd + d[1])
    elif k == "board":
        D.notice_board(cv, d[1] * 2, d[2] * 2, d[3] * 2, d[4] * 2, sd + d[1])
    elif k == "antlers":
        D.antlers(cv, d[1] * 2, d[2] * 2)
    elif k == "rack":
        D.shirt_rack(cv, d[1] * 2, d[2] * 2, d[3] * 2)
    elif k == "bunting":
        D.bunting(cv, d[1] * 2, d[2] * 2, d[3] * 2)
    elif k == "rope_wall":
        D.rope_wall(cv, d[1] * 2, d[2] * 2, d[3] * 2, d[4] * 2, sd + d[1])
    elif k == "topo":
        D.topo(cv, d[1] * 2, d[2] * 2, d[3] * 2, d[4] * 2, sd + d[1])
    elif k == "shoe_wall":
        D.shoe_wall(cv, d[1] * 2, d[2] * 2, d[3] * 2, d[4] * 2, sd + d[1])
    elif k == "gear_rail":
        D.gear_rail(cv, d[1] * 2, d[2] * 2, d[3] * 2, sd + d[1])
    elif k == "mural":
        AR._mural(cv, d[1] * 2, d[2] * 2, d[3] * 2, d[4] * 2, sd)


def room_ids() -> list[str]:
    return [k for k in SP.load() if not k.startswith("ahwahnee_")]


# The Camp Curry Store and the Mountain Shop are built with Curry Village
# (tools/hubs/build_curry_village.gd), not from build_interiors.gd's specs;
# here are theirs, in the same 16px units, written over the pictures that
# builder makes.
CURRY = {
    "curry_store": {"id": "curry_store", "out": "assets/sprites/curry/interiors/store_room.png",
        "size": (30, 17), "rows": 4, "seed": 75,
        "floor": ["planks", "a07a4e"], "wall": ["lap", "e2d6b0"], "wainscot": "2f4a34", "side": "8a6440",
        "deco": [["bunting", 16, 2, 448], ["window", 44, 10, 36, 28, 60, 20], ["window", 400, 10, 36, 28, 60, -20],
            ["shelf", 96, 6, 288, "goods"], ["shelf", 96, 30, 288, "crockery"],
            ["sconce", 22, 18], ["sconce", 88, 12], ["sconce", 390, 12], ["sconce", 458, 18]],
        "rugs": [[136, 150, 208, 60, "8a2f2f", "e8d8a8", "2f4a34"]],
        "doors": [{"side": "front"}]},
    "curry_mountain_shop": {"id": "curry_mountain_shop", "out": "assets/sprites/curry/interiors/shop_room.png",
        "size": (30, 17), "rows": 4, "seed": 77,
        "floor": ["planks", "8a6440"], "wall": ["boards", "8a6440"], "side": "6a4a30",
        "deco": [["rope_wall", 24, 8, 136, 40], ["topo", 180, 8, 96, 50], ["shoe_wall", 300, 8, 150, 40],
            ["sconce", 168, 14], ["sconce", 290, 14], ["sconce", 462, 14],
            ["gear_rail", 16, 52, 448]],
        "rugs": [[150, 169, 185, 65, "3a68a8", "e8d8a8", "2a1f1a"]], "mat": "3a68a8",
        "doors": [{"side": "front"}]},
}


def paint_curry() -> None:
    from kit import ROOT
    for spec in CURRY.values():
        paint_spec(spec).save(os.path.join(ROOT, spec["out"]))
        print("painted", spec["id"])
