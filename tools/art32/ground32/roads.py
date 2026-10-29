"""Roads for the native 32px ground painter, traced from the terrain grid.

The grid draws a road as a strip of tiles: one or two wide, stepping in
stairs where it runs on a slant, widening for a tile where a driveway or a
pull-out joins it. Blurring that mask gave lumpy roads that bulged at every
driveway, with a stray scrap of double yellow line in each bulge. Here the
road is traced instead: the tile mask is thinned to its middle line, short
spurs (driveways, pull-outs) are cut off, the rest is joined into one line per
road through bends and T junctions and smoothed, and each road is painted at
one steady width (one or two tiles, whichever it mostly is) round that line.
Road tiles the traced road doesn't cover are kept as plain asphalt aprons.

Pure numpy; coordinates are in art pixels (x, y), ``T`` art pixels to a tile.
"""
from __future__ import annotations

import numpy as np

import field as F

Q = 4  # thinning grid: pixels per tile
SPUR = 2.5  # spurs shorter than this many tiles are driveways, not roads


def _nbrs(P: np.ndarray):
    """The eight neighbours of every pixel of a 0/1 array padded by one,
    clockwise from north."""
    return (P[:-2, 1:-1], P[:-2, 2:], P[1:-1, 2:], P[2:, 2:],
            P[2:, 1:-1], P[2:, :-2], P[1:-1, :-2], P[:-2, :-2])


def thin(mask: np.ndarray) -> np.ndarray:
    """Zhang-Suen thinning to an 8-connected line one pixel wide."""
    img = mask.astype(np.uint8)
    while True:
        changed = False
        for step in (0, 1):
            n = _nbrs(np.pad(img, 1))
            b = sum(v.astype(np.int32) for v in n)
            a = sum(((n[i] == 0) & (n[(i + 1) % 8] == 1)).astype(np.int32) for i in range(8))
            p2, p4, p6, p8 = n[0], n[2], n[4], n[6]
            if step == 0:
                c = ((p2 & p4 & p6) == 0) & ((p4 & p6 & p8) == 0)
            else:
                c = ((p2 & p4 & p8) == 0) & ((p2 & p6 & p8) == 0)
            rm = (img == 1) & (b >= 2) & (b <= 6) & (a == 1) & c
            if rm.any():
                img[rm] = 0
                changed = True
        if not changed:
            break
    # Corners of stairs: a pixel on the inside of an L whose neighbours stay
    # joined without it (8-connectivity number 1) carries nothing; take them
    # out one orientation at a time so a stair keeps one of each pair.
    changed = True
    while changed:
        changed = False
        for i in (0, 2, 4, 6):
            n = _nbrs(np.pad(img, 1))
            b = sum(v.astype(np.int32) for v in n)
            # n is N, NE, E, SE, S, SW, W, NW; Yokoi's number on the complement
            c = [1 - v.astype(np.int32) for v in n]
            nc = sum(c[k] - c[k] * c[(k + 1) % 8] * c[(k + 2) % 8] for k in (0, 2, 4, 6))
            rm = (img == 1) & (b >= 2) & (nc == 1) & (n[i] == 1) & (n[(i + 2) % 8] == 1)
            if rm.any():
                img[rm] = 0
                changed = True
    return img.astype(bool)


def erosion_depth(mask: np.ndarray) -> np.ndarray:
    """How many 4-neighbour erosions each pixel survives, plus one."""
    d = np.zeros(mask.shape, np.int32)
    cur = mask.copy()
    k = 0
    while cur.any():
        k += 1
        d[cur] = k
        P = np.pad(cur, 1, mode="edge")
        cur = cur & P[:-2, 1:-1] & P[2:, 1:-1] & P[1:-1, :-2] & P[1:-1, 2:]
    return d


def _components(mask: np.ndarray) -> list[list[tuple[int, int]]]:
    """8-connected pixel groups of a sparse mask."""
    pts = set(zip(*np.nonzero(mask)))
    out = []
    while pts:
        seed = pts.pop()
        comp = [seed]
        stack = [seed]
        while stack:
            y, x = stack.pop()
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    p = (y + dy, x + dx)
                    if p in pts:
                        pts.remove(p)
                        comp.append(p)
                        stack.append(p)
        out.append(comp)
    return out


def _order(comp: list[tuple[int, int]]) -> list[tuple[int, int]]:
    """A chain's pixels in order from one end."""
    s = set(comp)

    def nb(p):
        return [(p[0] + dy, p[1] + dx) for dy in (-1, 0, 1) for dx in (-1, 0, 1)
                if (dy or dx) and (p[0] + dy, p[1] + dx) in s]

    ends = [p for p in comp if len(nb(p)) <= 1]
    cur = ends[0] if ends else comp[0]
    path = [cur]
    seen = {cur}
    while True:
        nxt = [q for q in nb(cur) if q not in seen]
        if not nxt:
            break
        # straight neighbours first, so stairs aren't skipped
        nxt.sort(key=lambda q: abs(q[0] - cur[0]) + abs(q[1] - cur[1]))
        cur = nxt[0]
        seen.add(cur)
        path.append(cur)
    return path


class Road:
    """One traced road: a polyline (art pixels, x/y), its width in tiles, and
    what each end does: "edge" (runs off the map), "dead" (stops), or a
    junction ("join", with the half width of the road it meets)."""

    def __init__(self, pts: np.ndarray, width: int):
        self.pts = pts
        self.width = width
        self.ends = ["dead", "dead"]
        self.meet = [0.0, 0.0]


def trace(carriage: np.ndarray, T: int) -> list[Road]:
    """The roads in a tile mask of road (and road bridge) tiles."""
    th, tw = carriage.shape
    pad = 3 * Q
    m = F.upsample(carriage.astype(np.uint8), Q).astype(bool)
    # Roads running off the map keep going in the padding, so their lines
    # reach the edge instead of stopping short of it.
    mp = np.pad(m, pad, mode="edge")
    # Round off the stairs first, so a slanting road thins to one line.
    mp = F.blur(mp.astype(np.float32), Q) > 0.5
    sk = thin(mp)[pad:-pad, pad:-pad]
    depth = erosion_depth(mp)[pad:-pad, pad:-pad]
    H, W = sk.shape
    n = _nbrs(np.pad(sk.astype(np.uint8), 1))
    cnt = sum(v.astype(np.int32) for v in n)
    junc = sk & (cnt >= 3)
    jd = F.box_blur(junc.astype(np.float32), 1) > 0
    groups = _components(sk & jd)
    nodes = [np.mean(c, axis=0) for c in groups]
    node_px = {}
    for i, c in enumerate(groups):
        for p in c:
            node_px[p] = i

    def node_at(p):
        for dy in (-2, -1, 0, 1, 2):
            for dx in (-2, -1, 0, 1, 2):
                q = (p[0] + dy, p[1] + dx)
                if q in node_px:
                    return node_px[q]
        return None

    # chains: [path (q pixels), node or None at each end]
    chains = []
    for comp in _components(sk & ~jd):
        path = _order(comp)
        a, b = node_at(path[0]), node_at(path[-1])
        if len(path) == 1 and a is None:
            continue
        chains.append([path, a, b])

    # Junction groups a pixel or two apart (where a thick bend thinned to a
    # small knot) are one junction.
    parent = list(range(len(nodes)))

    def root(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    for path, a, b in chains:
        if a is not None and b is not None and len(path) < Q:
            parent[root(a)] = root(b)
    merged = {}
    for i in range(len(nodes)):
        merged.setdefault(root(i), []).append(nodes[i])
    nodes = [np.mean(merged[root(i)], axis=0) if root(i) == i else None for i in range(len(nodes))]
    for i in range(len(nodes)):
        nodes[i] = np.mean(merged[root(i)], axis=0)
    chains = [[p, None if a is None else root(a), None if b is None else root(b)] for p, a, b in chains
              if not (a is not None and b is not None and (len(p) < Q or root(a) == root(b) and len(p) < 4 * Q))]

    def on_edge(p):
        return p[0] <= 1 or p[1] <= 1 or p[0] >= H - 2 or p[1] >= W - 2

    # Cut off short spurs (driveways and pull-outs), then join roads through
    # the junctions they leave with only two roads in them, and through the
    # straight side of a T.
    for _ in range(3):
        deg = {}
        for c in chains:
            for k in (1, 2):
                if c[k] is not None:
                    deg[c[k]] = deg.get(c[k], 0) + 1
        keep = []
        for c in chains:
            path, a, b = c
            free = [x is None and not on_edge(p) for x, p in ((a, path[0]), (b, path[-1]))]
            spur = (free[0] and b is not None and deg.get(b, 0) >= 3) or (free[1] and a is not None and deg.get(a, 0) >= 3)
            if spur and len(path) < SPUR * Q:
                continue
            keep.append(c)
        chains = keep
        chains = _join(chains, nodes)

    roads = []
    joined_at = {}
    for path, a, b in chains:
        # Through a junction the thinned line bends toward the side road;
        # leave out a road's width either side and run straight across.
        gap = 2 * Q
        drop = set()
        for i, p in enumerate(path):
            if p is None:
                drop.update(range(i - gap, i + gap + 1))
        path = [p for i, p in enumerate(path) if p is not None and (i not in drop or i in (0, len(path) - 1))]
        # A stopping end thins to a curl; cut its last tile and run it on
        # straight instead.
        cut = [x is None and not on_edge(p) and len(path) > 4 * Q for x, p in ((a, path[0]), (b, path[-1]))]
        path = path[Q if cut[0] else 0:len(path) - (Q if cut[1] else 0)]
        yx = np.array(path, np.float32)
        for k in (0, 1):
            if cut[k]:
                e = yx[-1] if k else yx[0]
                f = yx[-1 - 2 * Q] if k else yx[2 * Q]
                d = (e - f) / max(float(np.hypot(*(e - f))), 1e-6)
                ext = e[None, :] + d[None, :] * np.arange(1, Q + 1)[:, None]
                yx = np.vstack([yx, ext]) if k else np.vstack([ext[::-1], yx])
        # node centres at junction ends
        if a is not None:
            yx = np.vstack([nodes[a][None, :], yx])
        if b is not None:
            yx = np.vstack([yx, nodes[b][None, :]])
        dep = np.array([depth[p] for p in path], np.float32)
        wt = 2 if np.median(dep) >= 0.75 * Q else 1
        pts = (yx[:, ::-1] + 0.5) * (T / Q)
        r = Road(_smooth(_resample(pts, 1.0), T * 3), wt)
        for k, (x, p) in enumerate(((a, path[0]), (b, path[-1]))):
            if x is not None:
                r.ends[k] = "join"
                joined_at.setdefault(x, []).append((r, k))
            elif on_edge(p):
                r.ends[k] = "edge"
                # carry the line on past the map's edge
                d = r.pts[-1] - r.pts[-2] if k else r.pts[0] - r.pts[1]
                d = d / max(np.hypot(*d), 1e-6)
                ext = (r.pts[-1] if k else r.pts[0]) + d * T
                r.pts = np.vstack([r.pts, ext]) if k else np.vstack([ext, r.pts])
        roads.append(r)
    for ends in joined_at.values():
        widest = max(rr.width for rr, _ in ends)
        for rr, k in ends:
            rr.meet[k] = widest * T / 2.0
    return roads


def _dir(path, nodes, end) -> np.ndarray:
    path = [p for p in path if p is not None]
    p = np.array(path[0] if end == 0 else path[-1], np.float32)
    q = np.array(path[min(2 * Q, len(path) - 1)] if end == 0 else path[max(len(path) - 1 - 2 * Q, 0)], np.float32)
    d = q - p
    return d / max(np.hypot(*d), 1e-6)


def _join(chains, nodes):
    """Join chains that pass straight through a junction into one."""
    while True:
        at = {}
        for i, c in enumerate(chains):
            for k in (1, 2):
                if c[k] is not None:
                    at.setdefault(c[k], []).append((i, k))
        pair = None
        for node, ends in at.items():
            if len(ends) == 2 and ends[0][0] != ends[1][0]:
                pair = ends
            elif len(ends) == 3:
                best = None
                for x in range(3):
                    for y in range(x + 1, 3):
                        (i, ki), (j, kj) = ends[x], ends[y]
                        if i == j:
                            continue
                        di = _dir(chains[i][0], nodes, ki - 1)
                        dj = _dir(chains[j][0], nodes, kj - 1)
                        cos = float(di @ dj)
                        if cos < -0.85 and (best is None or cos < best[0]):
                            best = (cos, [ends[x], ends[y]])
                if best:
                    pair = best[1]
            if pair:
                break
        if not pair:
            return chains
        (i, ki), (j, kj) = pair
        pi, pj = chains[i][0], chains[j][0]
        # orient: i runs into the node, j runs out of it
        if ki == 1:
            pi = pi[::-1]
            ai = chains[i][2]
        else:
            ai = chains[i][1]
        if kj == 2:
            pj = pj[::-1]
            bj = chains[j][1]
        else:
            bj = chains[j][2]
        # None marks the junction passed through, for trace() to straighten
        merged = [pi + [None] + pj, ai, bj]
        chains = [c for k, c in enumerate(chains) if k not in (i, j)] + [merged]


def _resample(pts: np.ndarray, step: float) -> np.ndarray:
    seg = np.hypot(*np.diff(pts, axis=0).T)
    s = np.concatenate([[0.0], np.cumsum(seg)])
    if s[-1] < step:
        return pts
    t = np.arange(0.0, s[-1], step)
    t = np.append(t, s[-1])
    return np.stack([np.interp(t, s, pts[:, 0]), np.interp(t, s, pts[:, 1])], axis=1)


def _smooth(pts: np.ndarray, win: int) -> np.ndarray:
    """A moving average along the line, three times over, ends held."""
    if len(pts) < 5:
        return pts
    out = pts.copy()
    h = win // 2
    for _ in range(3):
        c = np.vstack([np.zeros((1, 2)), np.cumsum(out, axis=0)])
        n = len(out)
        i = np.arange(n)
        r = np.minimum(np.minimum(i, n - 1 - i), h)
        out = (c[i + r + 1] - c[i - r]) / (2 * r + 1)[:, None]
    return out


def stamp_disks(shape, pts: np.ndarray, radius: float) -> np.ndarray:
    """Union of disks of a radius round each point."""
    H, W = shape
    out = np.zeros(shape, bool)
    r = int(np.ceil(radius))
    oy, ox = np.mgrid[-r:r + 1, -r:r + 1]
    keep = (oy + 0.5) ** 2 + (ox + 0.5) ** 2 <= radius ** 2
    oy, ox = oy[keep], ox[keep]
    # points closer than a pixel add nothing
    p = np.unique(np.floor(pts).astype(np.int32), axis=0)
    for chunk in range(0, len(p), 512):
        q = p[chunk:chunk + 512]
        ys = (q[:, 1][:, None] + oy[None, :]).ravel()
        xs = (q[:, 0][:, None] + ox[None, :]).ravel()
        ok = (ys >= 0) & (ys < H) & (xs >= 0) & (xs < W)
        out[ys[ok], xs[ok]] = True
    return out


def reach_lots(r: Road, lots: np.ndarray, T: int) -> None:
    """A road that stops just short of a lot (or a walk) runs on into it a
    tile, so it meets the lot square instead of ending in a round cap."""
    H, W = lots.shape
    for k in (0, 1):
        if r.ends[k] != "dead":
            continue
        end = r.pts[-1] if k else r.pts[0]
        d = end - (r.pts[-2] if k else r.pts[1])
        d = d / max(np.hypot(*d), 1e-6)
        hit = False
        for step in range(0, 3 * T):
            x, y = (end + d * step).astype(int)
            if 0 <= y < H and 0 <= x < W and lots[y, x]:
                hit = True
                break
        if not hit:
            continue
        ext = end[None, :] + d[None, :] * np.arange(1, T * 2 + 1)[:, None]
        r.pts = np.vstack([r.pts, ext]) if k else np.vstack([ext[::-1], r.pts])
        r.ends[k] = "lot"


def offset_line(pts: np.ndarray, d: float) -> np.ndarray:
    """The line moved sideways by d pixels (to its right, looking along it)."""
    t = np.gradient(pts, axis=0)
    t = t / np.maximum(np.hypot(t[:, 0], t[:, 1]), 1e-6)[:, None]
    nrm = np.stack([-t[:, 1], t[:, 0]], axis=1)
    return pts + nrm * d


def arc_length(pts: np.ndarray) -> np.ndarray:
    return np.concatenate([[0.0], np.cumsum(np.hypot(*np.diff(pts, axis=0).T))])
