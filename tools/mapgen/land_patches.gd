extends RefCounted
## Hand corrections to a generated map's land cover, listed per hub in
## hub_content.gd as "land_patches". Each patch names lon/lat polygons:
##   "clear"  no OpenStreetMap buildings: their cells become forest floor
##            with dense forest. (Curry Village is its own hand-made hub, so
##            the Valley map doesn't repeat its cabins under the Apron.)
##   "slabs"  cliff painted as smooth granite slabs, and the forest at their
##            foot turned to walkable slab, so the rock sweeps up to the wall.
##   "talus"  a band of talus (unwalkable) along the foot of the cliff.
##   "unpave" true: in the "clear" area, roads, lots and paved walks that
##            don't lead through it (or to a spawn, shuttle stop or door) are
##            forest floor too, so the cleared village's loops don't dead-end.
## region_builder.gd applies them when it generates a map, ground_upgrade.gd
## paints the slabs, and patch_land.gd applies them to a map already built.

const Terrain = preload("res://tools/mapgen/terrain.gd")
## Ground that the slabs and the talus can cover.
const NATURAL := [Terrain.FOREST, Terrain.FOOTHILL, Terrain.FIR, Terrain.SCRUB, Terrain.MEADOW]
## How far from the cliff (in tiles) each reaches.
const SLAB_REACH := 2
const TALUS_REACH := 1
## Ground that "unpave" can take up, and what its paths may cross.
const PAVING := [Terrain.ROAD, Terrain.PARKING, Terrain.PAVED]
const PASSABLE := [Terrain.ROAD, Terrain.PARKING, Terrain.PAVED, Terrain.BRIDGE]
## Dense forest on cleared ground, as in OSM woods (region_builder.gd).
const FOREST_DENSITY := 0.42


## A w x h mask, 1 where a cell's center is inside one of the hub's [param key]
## polygons. [param to_cell] maps Vector2(lon, lat) to a fractional cell.
static func mask(content: Dictionary, key: String, w: int, h: int, to_cell: Callable) -> PackedByteArray:
	var m := PackedByteArray()
	m.resize(w * h)
	for patch: Dictionary in content.get("land_patches", []):
		if not patch.has(key):
			continue
		var poly := PackedVector2Array()
		for p: Vector2 in patch[key]:
			poly.append(to_cell.call(p))
		var box := Rect2(poly[0], Vector2.ZERO)
		for p in poly:
			box = box.expand(p)
		for j in range(maxi(0, floori(box.position.y)), mini(h, ceili(box.end.y) + 1)):
			for i in range(maxi(0, floori(box.position.x)), mini(w, ceili(box.end.x) + 1)):
				if Geometry2D.is_point_in_polygon(Vector2(i + 0.5, j + 0.5), poly):
					m[j * w + i] = 1
	return m


static func any(m: PackedByteArray) -> bool:
	return m.find(1) >= 0


## True if any of the hub's patches sets [param flag] (like "unpave").
static func wants(content: Dictionary, flag: String) -> bool:
	return content.get("land_patches", []).any(func(p: Dictionary) -> bool: return p.get(flag, false))


## Turns the paving inside [param area] to forest floor, except the shortest
## ways between the places roads enter the area (so through roads stay) and
## from each of [param spots] that has paving within two tiles to that
## network. Returns the cells it changed.
static func unpave(kind: PackedInt32Array, w: int, h: int, area: PackedByteArray, spots: Array[Vector2i]) -> Array[Vector2i]:
	var inside := func(c: Vector2i) -> bool:
		return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h and area[c.y * w + c.x] != 0
	var passable := func(c: Vector2i) -> bool:
		return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h and kind[c.y * w + c.x] in PASSABLE
	var steps: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	# Entries: paving inside the area next to road outside it, one per run.
	var entries: Array[Vector2i] = []
	var seen := {}
	for j in h:
		for i in w:
			var c := Vector2i(i, j)
			if seen.has(c) or not inside.call(c) or not passable.call(c):
				continue
			var touches := steps.any(func(d: Vector2i) -> bool: return not inside.call(c + d) and passable.call(c + d))
			if not touches:
				continue
			entries.append(c)
			# Neighbouring entry cells are the same road coming in.
			var run: Array[Vector2i] = [c]
			while not run.is_empty():
				var r: Vector2i = run.pop_back()
				if seen.has(r):
					continue
				seen[r] = true
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var n := r + Vector2i(dx, dy)
						if not seen.has(n) and inside.call(n) and passable.call(n) and steps.any(func(d: Vector2i) -> bool: return not inside.call(n + d) and passable.call(n + d)):
							run.append(n)
	var kept := {}
	for a in entries.size():
		for path in _paths_from(entries[a], entries.slice(a + 1), inside, passable, steps):
			for c in path:
				kept[c] = true
	for spot in spots:
		var start := Vector2i(-1, -1)
		for r in range(0, 3):
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if start.x < 0 and inside.call(spot + Vector2i(dx, dy)) and passable.call(spot + Vector2i(dx, dy)):
						start = spot + Vector2i(dx, dy)
		if start.x < 0:
			continue
		var targets: Array[Vector2i] = []
		targets.assign(kept.keys() if not kept.is_empty() else entries)
		for path in _paths_from(start, targets, inside, passable, steps, true):
			for c in path:
				kept[c] = true
	var changed: Array[Vector2i] = []
	for j in h:
		for i in w:
			var c := Vector2i(i, j)
			if inside.call(c) and kind[j * w + i] in PAVING and not kept.has(c):
				kind[j * w + i] = Terrain.FOREST
				changed.append(c)
	return changed


## Breadth-first shortest paths over passable cells inside the area, from
## [param start] to each of [param targets] (or only to the nearest).
static func _paths_from(start: Vector2i, targets: Array[Vector2i], inside: Callable, passable: Callable, steps: Array[Vector2i], nearest_only := false) -> Array:
	var came := {start: start}
	var queue: Array[Vector2i] = [start]
	var head := 0
	var wanted := {}
	for t in targets:
		wanted[t] = true
	var found: Array[Vector2i] = []
	while head < queue.size():
		var c := queue[head]
		head += 1
		if wanted.has(c):
			found.append(c)
			if nearest_only:
				break
		for d in steps:
			var n := c + d
			if not came.has(n) and inside.call(n) and passable.call(n):
				came[n] = c
				queue.append(n)
	var paths := []
	for t in found:
		var path: Array[Vector2i] = [t]
		var c := t
		while c != start:
			c = came[c]
			path.append(c)
		paths.append(path)
	return paths


## Turns natural ground near the cliff into slab (inside [param slabs]) or
## talus (inside [param talus]). Cells marked in [param keep] (spawns, signs,
## the climb start) stay as they are. Returns the cells it changed.
static func reshape(kind: PackedInt32Array, w: int, h: int, slabs: PackedByteArray, talus: PackedByteArray, keep: PackedByteArray) -> Array[Vector2i]:
	var changed: Array[Vector2i] = []
	var src := kind.duplicate()
	for j in h:
		for i in w:
			var k := j * w + i
			if (slabs[k] == 0 and talus[k] == 0) or keep[k] != 0 or src[k] not in NATURAL:
				continue
			var reach := SLAB_REACH if slabs[k] != 0 else TALUS_REACH
			if not _near(src, w, h, i, j, reach, Terrain.CLIFF):
				continue
			kind[k] = Terrain.GRANITE if slabs[k] != 0 else Terrain.TALUS
			changed.append(Vector2i(i, j))
	return changed


static func _near(src: PackedInt32Array, w: int, h: int, i: int, j: int, reach: int, type: int) -> bool:
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var x := i + dx
			var y := j + dy
			if x >= 0 and y >= 0 and x < w and y < h and src[y * w + x] == type:
				return true
	return false
