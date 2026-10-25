"""Land cover from OpenStreetMap for the terrain paintings: where the forest,
meadows, bare granite, talus, water, roads and buildings are, rasterized onto
the same UTM grid as the heights. Map data (c) OpenStreetMap contributors,
ODbL; the game's credits name it.

The map is fetched once a tile at a time from the OpenStreetMap API (small
tiles, a pause between them, as its usage policy asks) and cached in
tools/art32/walls32/cache/ (git-ignored).
"""
from __future__ import annotations

import math
import os
import time
import urllib.request
import xml.etree.ElementTree as ET

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, "cache")
API = "https://api.openstreetmap.org/api/0.6/map"
AGENT = "ValleyDaysArtTool/1.0 (github.com/goehringcory-lang/yosemite-game)"
TILE = 0.03  # degrees

# Land cover classes, in the order they are painted (later wins).
NONE, FOREST, SCRUB, MEADOW, WETLAND, SAND, SCREE, ROCK, BUILT, WATER, ROAD, STREAM, RIVER, PARKING = range(14)
NAMES = ["none", "forest", "scrub", "meadow", "wetland", "sand", "scree", "rock", "built", "water", "road",
         "stream", "river", "parking"]

AREA_TAGS = [
    (FOREST, [("natural", "wood"), ("landuse", "forest")]),
    (SCRUB, [("natural", "scrub"), ("natural", "heath")]),
    (MEADOW, [("natural", "grassland"), ("landuse", "meadow"), ("landuse", "grass"), ("leisure", "park")]),
    (WETLAND, [("natural", "wetland")]),
    (SAND, [("natural", "beach"), ("natural", "sand")]),
    (SCREE, [("natural", "scree"), ("natural", "shingle")]),
    (ROCK, [("natural", "bare_rock")]),
    (PARKING, [("amenity", "parking")]),
    (BUILT, [("building", None)]),
    (WATER, [("natural", "water"), ("waterway", "riverbank"), ("natural", "glacier")]),
]
ROADS = {"motorway", "trunk", "primary", "secondary", "tertiary", "unclassified", "residential", "service"}


def _tiles(lon0: float, lat0: float, lon1: float, lat1: float) -> list[tuple[float, float, float, float]]:
    out = []
    a = math.floor(lon0 / TILE) * TILE
    while a < lon1:
        b = math.floor(lat0 / TILE) * TILE
        while b < lat1:
            out.append((round(a, 4), round(b, 4), round(a + TILE, 4), round(b + TILE, 4)))
            b += TILE
        a += TILE
    return out


def fetch(lon0: float, lat0: float, lon1: float, lat1: float) -> list[str]:
    """The cached .osm files covering the box (downloading what's missing)."""
    os.makedirs(CACHE, exist_ok=True)
    paths = []
    for t in _tiles(lon0, lat0, lon1, lat1):
        path = os.path.join(CACHE, "osm_%.4f_%.4f.osm" % (t[0], t[1]))
        if not os.path.exists(path):
            url = "%s?bbox=%.4f,%.4f,%.4f,%.4f" % (API, *t)
            for attempt in range(5):
                try:
                    req = urllib.request.Request(url, headers={"User-Agent": AGENT})
                    with urllib.request.urlopen(req, timeout=180) as resp:
                        blob = resp.read()
                    break
                except OSError:
                    if attempt == 4:
                        raise
                    time.sleep(2 ** attempt * 3)
            with open(path + ".part", "wb") as f:
                f.write(blob)
            os.replace(path + ".part", path)
            time.sleep(1.5)
        paths.append(path)
    return paths


class Map:
    """The ways and multipolygons of the fetched tiles, merged."""

    def __init__(self, paths: list[str]) -> None:
        self.nodes: dict[str, tuple[float, float]] = {}
        self.node_tags: dict[str, dict[str, str]] = {}
        self.ways: dict[str, tuple[list[str], dict[str, str]]] = {}
        self.rels: dict[str, tuple[list[tuple[str, str, str]], dict[str, str]]] = {}
        for p in paths:
            root = ET.parse(p).getroot()
            for el in root:
                if el.tag == "node":
                    self.nodes[el.get("id")] = (float(el.get("lat")), float(el.get("lon")))
                    tags = {t.get("k"): t.get("v") for t in el.findall("tag")}
                    if tags:
                        self.node_tags[el.get("id")] = tags
                elif el.tag == "way":
                    nds = [n.get("ref") for n in el.findall("nd")]
                    tags = {t.get("k"): t.get("v") for t in el.findall("tag")}
                    self.ways[el.get("id")] = (nds, tags)
                elif el.tag == "relation":
                    mem = [(m.get("type"), m.get("ref"), m.get("role")) for m in el.findall("member")]
                    tags = {t.get("k"): t.get("v") for t in el.findall("tag")}
                    self.rels[el.get("id")] = (mem, tags)

    def coords(self, nds: list[str]) -> list[tuple[float, float]]:
        return [self.nodes[n] for n in nds if n in self.nodes]


def _match(tags: dict[str, str], rules) -> bool:
    for k, v in rules:
        if k in tags and (v is None or tags[k] == v):
            return True
    return False


def _rings(m: Map, rel_members) -> tuple[list[list[str]], list[list[str]]]:
    """Joins a multipolygon's member ways into closed outer and inner rings."""
    out = {"outer": [], "inner": []}
    for role in ("outer", "inner"):
        segs = [list(m.ways[ref][0]) for t, ref, r in rel_members if t == "way" and r == role and ref in m.ways]
        rings = []
        while segs:
            ring = segs.pop(0)
            changed = True
            while ring[0] != ring[-1] and changed:
                changed = False
                for i, s in enumerate(segs):
                    if s[0] == ring[-1]:
                        ring += s[1:]
                    elif s[-1] == ring[-1]:
                        ring += s[::-1][1:]
                    elif s[-1] == ring[0]:
                        ring = s[:-1] + ring
                    elif s[0] == ring[0]:
                        ring = s[::-1][:-1] + ring
                    else:
                        continue
                    segs.pop(i)
                    changed = True
                    break
            rings.append(ring)
        out[role] = rings
    return out["outer"], out["inner"]


def utm_np(lat: np.ndarray, lon: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Vectorized latitude/longitude to UTM zone 11N (as dem.utm)."""
    a = 6378137.0
    f = 1 / 298.257222101
    e2 = f * (2 - f)
    ep2 = e2 / (1 - e2)
    k0 = 0.9996
    phi = np.radians(lat)
    lam = np.radians(lon) - math.radians(-117.0)
    n = a / np.sqrt(1 - e2 * np.sin(phi) ** 2)
    t = np.tan(phi) ** 2
    c = ep2 * np.cos(phi) ** 2
    aa = np.cos(phi) * lam
    e4, e6 = e2 * e2, e2 * e2 * e2
    mm = a * ((1 - e2 / 4 - 3 * e4 / 64 - 5 * e6 / 256) * phi
              - (3 * e2 / 8 + 3 * e4 / 32 + 45 * e6 / 1024) * np.sin(2 * phi)
              + (15 * e4 / 256 + 45 * e6 / 1024) * np.sin(4 * phi)
              - (35 * e6 / 3072) * np.sin(6 * phi))
    x = k0 * n * (aa + (1 - t + c) * aa ** 3 / 6 + (5 - 18 * t + t * t + 72 * c - 58 * ep2) * aa ** 5 / 120) + 500000.0
    y = k0 * (mm + n * np.tan(phi) * (aa * aa / 2 + (5 - t + 9 * c + 4 * c * c) * aa ** 4 / 24
                                      + (61 - 58 * t + t * t + 600 * c - 330 * ep2) * aa ** 6 / 720))
    return x, y


class Cover:
    """A land cover raster on a UTM grid: cls[row, col], row 0 north."""

    def __init__(self, e0: float, n1: float, res: float, w: int, h: int) -> None:
        self.e0, self.n1, self.res, self.w, self.h = e0, n1, res, w, h
        self.img = Image.new("L", (w, h), NONE)
        self.draw = ImageDraw.Draw(self.img)
        self.falls: list[tuple[float, float, str]] = []  # (e, n, name)

    def _px(self, pts: list[tuple[float, float]]) -> list[tuple[float, float]]:
        if not pts:
            return []
        lat = np.array([p[0] for p in pts])
        lon = np.array([p[1] for p in pts])
        e, n = utm_np(lat, lon)
        return list(zip(((e - self.e0) / self.res).tolist(), ((self.n1 - n) / self.res).tolist()))

    def polygon(self, pts, cls: int) -> None:
        px = self._px(pts)
        if len(px) >= 3:
            self.draw.polygon(px, fill=cls)

    def line(self, pts, cls: int, width_m: float) -> None:
        px = self._px(pts)
        if len(px) >= 2:
            self.draw.line(px, fill=cls, width=max(1, int(round(width_m / self.res))), joint="curve")

    @property
    def cls(self) -> np.ndarray:
        return np.array(self.img, np.uint8)


def cover(e0: float, n0: float, e1: float, n1: float, res: float, lonlat_box: tuple[float, float, float, float]) -> Cover:
    """Rasterizes the map's land cover over the UTM box."""
    w, h = int(round((e1 - e0) / res)), int(round((n1 - n0) / res))
    cache = os.path.join(CACHE, "cover2_%d_%d_%d_%d_%g.png" % (e0, n0, e1, n1, res))
    cv = Cover(e0, n1, res, w, h)
    m = Map(fetch(*lonlat_box))
    for nid, tags in m.node_tags.items():
        if tags.get("waterway") == "waterfall":
            la, lo = m.nodes[nid]
            e, n = utm_np(np.array([la]), np.array([lo]))
            cv.falls.append((float(e[0]), float(n[0]), tags.get("name", "")))
    if os.path.exists(cache):
        cv.img = Image.open(cache).convert("L")
        cv.draw = ImageDraw.Draw(cv.img)
        return cv
    # areas, in class order, ways then multipolygons
    for cls, rules in AREA_TAGS:
        for wid, (nds, tags) in m.ways.items():
            if len(nds) > 3 and nds[0] == nds[-1] and _match(tags, rules):
                cv.polygon(m.coords(nds), cls)
        for rid, (mem, tags) in m.rels.items():
            if tags.get("type") == "multipolygon" and _match(tags, rules):
                outer, inner = _rings(m, mem)
                for r in outer:
                    cv.polygon(m.coords(r), cls)
                for r in inner:
                    # holes take the cover round them back off
                    cv.polygon(m.coords(r), NONE)
    # lines: roads, then streams and rivers on top
    for wid, (nds, tags) in m.ways.items():
        hw = tags.get("highway")
        if hw in ROADS:
            cv.line(m.coords(nds), ROAD, 9.0 if hw in ("primary", "secondary", "tertiary") else 5.0)
    for wid, (nds, tags) in m.ways.items():
        ww = tags.get("waterway")
        if ww == "stream":
            # wide: where a creek goes over a cliff it is a fall, and the
            # spray makes it wider than the creek
            cv.line(m.coords(nds), STREAM, 22.0)
        elif ww == "river":
            cv.line(m.coords(nds), RIVER, 26.0)
    cv.img.save(cache)
    return cv
