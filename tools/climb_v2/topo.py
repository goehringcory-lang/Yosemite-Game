#!/usr/bin/env python3
"""Draws climbing v2 walls as topo sheets: one PNG per route, its pitches side
by side, from the JSON that convert_routes.tscn's "dump" mode writes.

    godot --headless --path . res://tools/climb_v2/convert_routes.tscn -- dump /tmp/walls
    python3 tools/climb_v2/topo.py /tmp/walls /tmp/topos

Hands are filled dots (bigger = better), feet small rings, cracks are drawn in
the sling colour of the cam that fits (ClimbRack.WIDTHS), constrictions as
white ticks, bolts silver, pins orange, crux zones red, rests green, ledges
brown. The climber's shortest hand path (WallCheck.climb_path) isn't drawn.
"""
import json, os, sys, glob, re
from PIL import Image, ImageDraw, ImageFont

PX = 26
CAM = ["#2f6cc0", "#8a8a90", "#7a4aa8", "#4f9a3a", "#c8382e", "#dcaa2c", "#2f6cc0", "#8a8a90"]
KIND = {"jug": "#f4e3b0", "edge": "#e0c890", "crimp": "#d09060", "sloper": "#b0a0c0", "pinch": "#c0d090",
        "pocket": "#a08060", "undercling": "#90c0d0", "sidepull": "#e0a0a0", "gaston": "#e0b0d0",
        "jam": "#ffffff", "horn": "#f0d060", "stance": "#a0e0a0"}
ROCK = {"golden": "#9a8468", "apron": "#a8a49a", "polished": "#b4ae9e", "orange": "#a8805a", "dark": "#6e6a66",
        "pale": "#b8b0a0", "roof": "#8a7a6a", "columbia": "#8a8478", "elcap": "#b0aca0", "arches": "#9a9080",
        "dome": "#a8a8a0", "knobby": "#8a8a80", "ice": "#b8d0e0"}


def font(size):
    for f in ["/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "/usr/share/fonts/dejavu/DejaVuSans.ttf"]:
        if os.path.exists(f):
            return ImageFont.truetype(f, size)
    return ImageFont.load_default()


def width_index(w):
    return max(0, min(7, int(round(w))))


def draw_pitch(w):
    W, H = w["size"]
    img = Image.new("RGB", (int(W * PX) + 2, int(H * PX) + 46), ROCK.get(w.get("rock", ""), "#9a9488"))
    d = ImageDraw.Draw(img)
    to = lambda p: (p[0] * PX + 1, (H - p[1]) * PX + 40)
    f = font(11)
    info = w.get("info", {})
    d.rectangle([0, 0, img.width, 38], fill="#222")
    d.text((4, 3), "P%d  %s" % (w["pitch"] + 1, info.get("name", "")), fill="#fff", font=font(12))
    d.text((4, 20), "%s  %.0f m  %s" % (w.get("style", ""), info.get("height", 0), info.get("grade", "")), fill="#bbb", font=f)
    for y in range(0, int(H) + 1, 5):
        d.line([to((0, y)), to((0.4, y))], fill="#333")
        d.text(to((0.5, y + 0.4)), "%d" % y, fill="#333", font=f)
    for z in w["zones"]:
        x, y, zw, zh = z["rect"]
        col = {"crux": "#d03030", "rest": "#40b040", "ledge": "#7a5a3a"}.get(z["kind"], "#4080c0")
        d.rectangle([to((x, y + zh)), to((x + zw, y))], outline=col, width=2)
        if z["kind"] == "crux":
            d.text(to((x + 0.1, y + zh - 0.1)), z["data"].get("name", "") + " " + "".join(s[0].upper() for s in z["data"].get("sequence", [])), fill="#ffdddd", font=f)
    for c in w["cracks"]:
        pts = c["points"]
        for i in range(len(pts) - 1):
            col = CAM[width_index((c["widths"][i] + c["widths"][i + 1]) / 2)]
            d.line([to(pts[i]), to(pts[i + 1])], fill=col, width=max(2, int(2 + c["widths"][i] * 0.7)))
        for i in c.get("constrictions", []):
            x, y = to(pts[i])
            d.line([(x - 6, y), (x + 6, y)], fill="#fff", width=2)
    for h in w["holds"]:
        x, y = to(h["pos"])
        if h["hand"]:
            r = 2 + h["size"] * 4
            col = KIND.get(h["kind"], "#ddd")
            outline = "#d03030" if any(t.startswith("crux:") for t in h["tags"]) else "#222"
            if "decoy" in h["tags"]:
                outline = "#ff00ff"
            d.ellipse([x - r, y - r, x + r, y + r], fill=col, outline=outline)
        else:
            d.ellipse([x - 2, y - 2, x + 2, y + 2], outline="#333")
    for p in w["fixed"]:
        x, y = to(p["pos"])
        col = {"bolt": "#e8e8f0", "pin": "#e08030", "anchor": "#ffff60"}.get(p["kind"], "#fff")
        d.rectangle([x - 3, y - 3, x + 3, y + 3], fill=col, outline="#000")
    return img


def main(src, out):
    os.makedirs(out, exist_ok=True)
    routes = {}
    for path in sorted(glob.glob(os.path.join(src, "*_p*.json"))):
        m = re.match(r"(.+)_p(\d+)\.json", os.path.basename(path))
        routes.setdefault(m.group(1), []).append((int(m.group(2)), json.load(open(path))))
    for rid, pitches in routes.items():
        imgs = [draw_pitch(w) for _, w in sorted(pitches, key=lambda t: t[0])]
        sheet = Image.new("RGB", (sum(i.width for i in imgs) + 6 * (len(imgs) + 1), max(i.height for i in imgs) + 34), "#111")
        ImageDraw.Draw(sheet).text((8, 8), rid.replace("_", " ").title(), fill="#fff", font=font(16))
        x = 6
        for i in imgs:
            sheet.paste(i, (x, 28 + sheet.height - 34 - i.height))
            x += i.width + 6
        sheet.save(os.path.join(out, rid + ".png"))
        print("wrote", os.path.join(out, rid + ".png"))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
