"""Real elevation for the cliff paintings: USGS 3D Elevation Program (3DEP)
heights, fetched once from the National Map's elevation service and cached in
tools/art32/walls32/cache/ (git-ignored), in UTM zone 11N metres.

Yosemite's 3DEP data is lidar, a metre or two per sample, enough to show
El Capitan's prow, the Royal Arches and every buttress and gully.
"""
from __future__ import annotations

import hashlib
import math
import os
import time
import urllib.request

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, "cache")
SERVICE = "https://elevation.nationalmap.gov/arcgis/rest/services/3DEPElevation/ImageServer/exportImage"
UTM11 = 26911  # NAD83 / UTM zone 11N


def utm(lat: float, lon: float) -> tuple[float, float]:
    """WGS84/NAD83 latitude and longitude to UTM zone 11N easting, northing
    (Snyder's series, good to a few centimetres here)."""
    a = 6378137.0
    f = 1 / 298.257222101
    e2 = f * (2 - f)
    ep2 = e2 / (1 - e2)
    k0 = 0.9996
    phi = math.radians(lat)
    lam = math.radians(lon) - math.radians(-117.0)
    n = a / math.sqrt(1 - e2 * math.sin(phi) ** 2)
    t = math.tan(phi) ** 2
    c = ep2 * math.cos(phi) ** 2
    aa = math.cos(phi) * lam
    e4, e6 = e2 * e2, e2 * e2 * e2
    m = a * ((1 - e2 / 4 - 3 * e4 / 64 - 5 * e6 / 256) * phi
             - (3 * e2 / 8 + 3 * e4 / 32 + 45 * e6 / 1024) * math.sin(2 * phi)
             + (15 * e4 / 256 + 45 * e6 / 1024) * math.sin(4 * phi)
             - (35 * e6 / 3072) * math.sin(6 * phi))
    x = k0 * n * (aa + (1 - t + c) * aa ** 3 / 6 + (5 - 18 * t + t * t + 72 * c - 58 * ep2) * aa ** 5 / 120) + 500000.0
    y = k0 * (m + n * math.tan(phi) * (aa * aa / 2 + (5 - t + 9 * c + 4 * c * c) * aa ** 4 / 24
                                       + (61 - 58 * t + t * t + 600 * c - 330 * ep2) * aa ** 6 / 720))
    return x, y


class DEM:
    """A height grid in UTM metres: z[row, col], row 0 at the north edge."""

    def __init__(self, z: np.ndarray, e0: float, n1: float, res: float) -> None:
        self.z = z.astype(np.float32)
        self.e0, self.n1, self.res = e0, n1, res  # west edge, north edge, metres per cell
        gy, gx = np.gradient(self.z, res)
        # dz/de (east) and dz/dn (north: rows run south)
        self.dzde = gx.astype(np.float32)
        self.dzdn = (-gy).astype(np.float32)

    @property
    def shape(self) -> tuple[int, int]:
        return self.z.shape

    def _rc(self, e: np.ndarray, n: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
        return (self.n1 - n) / self.res - 0.5, (e - self.e0) / self.res - 0.5

    def sample(self, e: np.ndarray, n: np.ndarray, grid: np.ndarray | None = None) -> np.ndarray:
        """Bilinear sample of [param grid] (the heights by default) at UTM
        points; outside the grid gives the edge value."""
        g = self.z if grid is None else grid
        r, c = self._rc(e, n)
        h, w = g.shape
        r = np.clip(r, 0, h - 1.001)
        c = np.clip(c, 0, w - 1.001)
        r0 = np.floor(r).astype(np.int32)
        c0 = np.floor(c).astype(np.int32)
        fr = r - r0
        fc = c - c0
        a = g[r0, c0] * (1 - fc) + g[r0, c0 + 1] * fc
        b = g[r0 + 1, c0] * (1 - fc) + g[r0 + 1, c0 + 1] * fc
        return (a * (1 - fr) + b * fr).astype(np.float32)


def fetch(e0: float, n0: float, e1: float, n1: float, res: float = 2.0) -> DEM:
    """The 3DEP heights over a UTM box (west, south, east, north), at
    [param res] metres per cell, from the cache or the service."""
    os.makedirs(CACHE, exist_ok=True)
    w = int(round((e1 - e0) / res))
    h = int(round((n1 - n0) / res))
    key = hashlib.sha1(f"{e0:.1f},{n0:.1f},{e1:.1f},{n1:.1f},{res}".encode()).hexdigest()[:16]
    path = os.path.join(CACHE, f"dem_{key}.tif")
    if not os.path.exists(path):
        # the service hands out at most about 4000 cells a side: fetch in tiles
        tile = 2000
        z = np.zeros((h, w), np.float32)
        for ty in range(0, h, tile):
            for tx in range(0, w, tile):
                tw, th = min(tile, w - tx), min(tile, h - ty)
                be0 = e0 + tx * res
                bn1 = n1 - ty * res
                url = (f"{SERVICE}?bbox={be0},{bn1 - th * res},{be0 + tw * res},{bn1}&bboxSR={UTM11}&imageSR={UTM11}"
                       f"&size={tw},{th}&format=tiff&pixelType=F32&interpolation=RSP_BilinearInterpolation&f=image")
                for attempt in range(5):
                    try:
                        with urllib.request.urlopen(url, timeout=120) as resp:
                            blob = resp.read()
                        break
                    except OSError:
                        if attempt == 4:
                            raise
                        time.sleep(2 ** attempt)
                part_path = path + ".part"
                with open(part_path, "wb") as f:
                    f.write(blob)
                z[ty:ty + th, tx:tx + tw] = np.array(Image.open(part_path), dtype=np.float32)
                os.remove(part_path)
        Image.fromarray(z, "F").save(path)
    z = np.array(Image.open(path), dtype=np.float32)
    return DEM(z, e0, n1, res)
