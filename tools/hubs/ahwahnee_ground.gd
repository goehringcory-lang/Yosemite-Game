extends RefCounted
## Paints the ground of the two Ahwahnee regions (the Stoneman Meadow trail
## and the hotel grounds) as one detailed picture per region, from the same
## terrain grid the builder uses for walking and collision. The tile layer
## underneath still decides where the player can walk; this picture is what
## they see: grass tufts and wildflowers, dappled forest floor, mowed lawn
## stripes, packed-dirt trail, flagstone terraces, raked gravel, and a river
## with depth, shore foam, ripples and sun glints.
##
## Palettes are mid-day values; the world's day/night tint darkens them.

const Terrain = preload("res://tools/mapgen/terrain.gd")
const T := 16
const FORMAL := [Terrain.PAVED, Terrain.PARKING, Terrain.ROAD, Terrain.BRIDGE, Terrain.BUILT]
## Formal groups that get a smoothed outline of their own in paint().
const PAVE_SET := [Terrain.PAVED, Terrain.PARKING, Terrain.BUILT, Terrain.BRIDGE]
const WET_SET := [Terrain.RIVER, Terrain.LAKE, Terrain.CREEK, Terrain.FALLS]

var w := 0
var h := 0
var kind := PackedInt32Array()
## Tiles that get mow stripes (lawn) or raked lines (gravel) are decided by
## kind; [member bed] tiles are dark garden soil under the flower-bed sprites.
var bed := PackedByteArray()
var seed_value := 1
## Pixel-exact shapes drawn over the tile ground: rings are gravel drives with
## a cobble curb around a lawn island ([cx, cy, outer rx, outer ry, inner rx,
## inner ry] in pixels); soils are flower-bed rectangles (Rect2i in pixels).
var rings: Array = []
var soils: Array[Rect2i] = []
## Optional per-tile brightness (1.0 = unchanged), blended smoothly between
## tile centers. The generated hubs feed it their hillshade.
var tint := PackedFloat32Array()
## Gives roads a dark edge line and a worn gravel shoulder (the generated hubs'
## roads are plain tile runs, so this keeps them from looking like gray blocks).
var road_shoulders := false
## Trims gravel, flagstone and plaza edges where they meet natural ground: a
## dark edge line, a lit inner line, and a thin contact shadow on the ground
## outside. Reads as a curb instead of a hard-cut rectangle.
var edge_trim := true

var _na := PackedByteArray() # large scale
var _nb := PackedByteArray() # medium scale
var _nc := PackedByteArray() # small scale
var _wx := PackedByteArray() # warp x
var _wy := PackedByteArray() # warp y
var _nf := PackedByteArray() # flower clusters
var _water_depth := PackedFloat32Array() # tiles from land, per tile
var _pk := PackedByteArray() # the ground type shown at each pixel
var _pw := 0
var _ph := 0
## Per-pixel road cover (0..1) from the smoothed road mask, for the shoulders.
var _road_s := PackedFloat32Array()
## Smoothed 0/1 masks of the formal and water groups, one value per tile.
var _mroad := PackedFloat32Array()
var _mpave := PackedFloat32Array()
var _mwet := PackedFloat32Array()
## The kind each tile lends to the paved and water groups (see _path_rep).
var _fkind := PackedInt32Array()
var _wkind := PackedInt32Array()
## Bilinear weights from pixel columns and rows to tile centers (see _path_index).
var _qx0 := PackedInt32Array()
var _qx1 := PackedInt32Array()
var _qtx := PackedFloat32Array()
var _qy0 := PackedInt32Array()
var _qy1 := PackedInt32Array()
var _qty := PackedFloat32Array()
## Per tile: 1 where the tile is paving or water (see _path_hard).
var _thard := PackedByteArray()
## Per tile: 1 where any formal or water cover reaches the 3x3 tiles around it.
var _tany := PackedByteArray()
## Per pixel: 1 where the shown ground is paving or water, and 1 where it is water.
var _phard := PackedByteArray()
var _pwet := PackedByteArray()


static func c(hex: String) -> Color:
	return Color(hex)


static func hash2(x: int, y: int, s := 0) -> float:
	var v := (x * 374761393 + y * 668265263 + s * 2147483647) & 0x7fffffff
	v = ((v ^ (v >> 13)) * 1274126177) & 0x7fffffff
	v = v ^ (v >> 16)
	return float(v & 0xffff) / 65535.0


static func smooth(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _noise_bytes(freq: float, s: int, octaves := 1) -> PackedByteArray:
	var n := FastNoiseLite.new()
	n.seed = s
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	if octaves > 1:
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
		n.fractal_octaves = octaves
	var im := n.get_image(_pw, _ph, false, false, false)
	im.convert(Image.FORMAT_L8)
	return im.get_data()


func paint(grid: PackedInt32Array, width: int, height: int, seed_v: int) -> Image:
	kind = grid
	w = width
	h = height
	seed_value = seed_v
	_pw = w * T
	_ph = h * T
	_na = _noise_bytes(0.011, seed_v, 3)
	_nb = _noise_bytes(0.045, seed_v + 1, 2)
	_nc = _noise_bytes(0.16, seed_v + 2)
	_wx = _noise_bytes(0.06, seed_v + 3, 2)
	_wy = _noise_bytes(0.06, seed_v + 4, 2)
	_nf = _noise_bytes(0.03, seed_v + 5, 2)
	if bed.size() != w * h:
		bed.resize(w * h)
	_compute_water_depth()
	_path_index()
	_path_groups()
	var out := PackedByteArray()
	out.resize(_pw * _ph * 4)
	_pk.resize(_pw * _ph)
	_road_s.resize(_pw * _ph)
	_phard.resize(_pw * _ph)
	_pwet.resize(_pw * _ph)
	for y in _ph:
		for x in _pw:
			var i := y * _pw + x
			# Each formal group is a smoothed outline (see _path_groups), so its
			# edges are curves rather than tile steps. Ties go to bridge, water,
			# then road.
			var near := (y / T) * w + x / T
			var k := 0
			var tx := x / T
			var ty := y / T
			# A tile's own pixels use a lower cutoff (see _path_cut), so one-tile
			# roads and streams survive the blur. The shoreline wobbles on
			# low-frequency noise; roads do not.
			var own := kind[near]
			# (_tany skips the samples where no group cover is near.)
			if _tany[near] == 1 and own == Terrain.BRIDGE and _path_sample(_mpave, x, y) > 0.25:
				k = Terrain.BRIDGE
			elif _tany[near] == 1 and _path_sample(_mwet, x, y) > _path_cut(_path_wet(own), (float(_na[i]) / 255.0 - 0.5) * 0.3):
				k = _wkind[near]
			elif _tany[near] == 1 and _path_sample(_mroad, x, y) > _path_cut(own == Terrain.ROAD, 0.0):
				k = Terrain.ROAD
			elif _tany[near] == 1 and _path_sample(_mpave, x, y) > _path_cut(own in PAVE_SET, 0.0):
				k = _fkind[near]
			else:
				# Natural ground: warp the lookup so borders are ragged.
				var wxn := float(_wx[i]) / 255.0 - 0.5
				var wyn := float(_wy[i]) / 255.0 - 0.5
				var jx := (hash2(x, y, 5) - 0.5) * 2.4
				var jy := (hash2(x, y, 6) - 0.5) * 2.4
				var nt := _path_natural_tile(clampi((x + int(wxn * 17.0 + jx)) / T, 0, w - 1), clampi((y + int(wyn * 17.0 + jy)) / T, 0, h - 1))
				tx = nt.x
				ty = nt.y
				k = kind[ty * w + tx]
			_pk[i] = k
			_phard[i] = 1 if _path_hard(k) else 0
			_pwet[i] = 1 if _is_water(k) else 0
			_road_s[i] = _path_sample(_mroad, x, y)
			var col := _color(k, x, y, i, tx, ty)
			if bed[ty * w + tx] != 0 and k in [Terrain.LAWN, Terrain.MEADOW]:
				col = _bed_color(x, y, i)
			if not rings.is_empty() or not soils.is_empty():
				col = _shapes(col, k, x, y, i)
			if tint.size() == w * h and k not in FORMAL and not _is_water(k):
				var tn := _tint_at(x, y)
				col = Color(col.r * tn, col.g * tn, col.b * tn * (1.0 + (1.0 - tn) * 0.15))
			var o := i * 4
			out[o] = int(clampf(col.r, 0, 1) * 255.0)
			out[o + 1] = int(clampf(col.g, 0, 1) * 255.0)
			out[o + 2] = int(clampf(col.b, 0, 1) * 255.0)
			out[o + 3] = 255
	var im := Image.create_from_data(_pw, _ph, false, Image.FORMAT_RGBA8, out)
	_shore_and_edges(im)
	if edge_trim:
		_edge_trim(im)
	if road_shoulders:
		_road_shoulders(im)
	return im


## Smoothed outlines for the formal and water groups. Each group is a 0/1 mask
## at tile resolution, blurred twice with a 3x3 box, so a pixel belongs to the
## group where the blurred mask (sampled at the pixel) is above one half. The
## outline stays within about half a tile of the real tiles.
func _path_groups() -> void:
	var n := w * h
	var road := PackedFloat32Array()
	var pave := PackedFloat32Array()
	var wet := PackedFloat32Array()
	road.resize(n)
	pave.resize(n)
	wet.resize(n)
	for t in n:
		road[t] = 1.0 if kind[t] == Terrain.ROAD else 0.0
		pave[t] = 1.0 if kind[t] in PAVE_SET else 0.0
		wet[t] = 1.0 if _path_wet(kind[t]) else 0.0
	_mroad = _path_blur(road)
	_mpave = _path_blur(pave)
	_mwet = _path_blur(wet)
	_thard.resize(n)
	for t in n:
		_thard[t] = 1 if _path_hard(kind[t]) else 0
	# Tiles with any group cover within one tile; elsewhere every sample is zero.
	_tany.resize(n)
	for y in h:
		for x in w:
			var any := 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var t := clampi(y + dy, 0, h - 1) * w + clampi(x + dx, 0, w - 1)
					if _mroad[t] > 0.0 or _mpave[t] > 0.0 or _mwet[t] > 0.0:
						any = 1
			_tany[y * w + x] = any
	_fkind.resize(n)
	_wkind.resize(n)
	for y in h:
		for x in w:
			_fkind[y * w + x] = _path_rep(x, y, PAVE_SET, Terrain.PAVED)
			_wkind[y * w + x] = _path_rep(x, y, WET_SET, Terrain.RIVER)


## Two passes of a 3x3 box blur over a tile-resolution mask (edges clamped).
func _path_blur(src: PackedFloat32Array) -> PackedFloat32Array:
	var a := src
	for _pass in 2:
		var b := PackedFloat32Array()
		b.resize(w * h)
		for y in h:
			for x in w:
				var s := 0.0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						s += a[clampi(y + dy, 0, h - 1) * w + clampi(x + dx, 0, w - 1)]
				b[y * w + x] = s / 9.0
		a = b
	return a


## The blurred-mask cutoff for a pixel: one half in general, but a quarter on a
## tile that is itself a member, where a one-tile-wide run blurs to a third.
func _path_cut(own_member: bool, wobble: float) -> float:
	return (0.25 if own_member else 0.5) + wobble


## A blurred mask at a pixel, bilinear between tile centers (tile i is centered
## at i + 0.5 tiles).
func _path_sample(m: PackedFloat32Array, x: int, y: int) -> float:
	var y0 := _qy0[y]
	var y1 := _qy1[y]
	var x0 := _qx0[x]
	var x1 := _qx1[x]
	var tx := _qtx[x]
	return lerpf(lerpf(m[y0 + x0], m[y0 + x1], tx), lerpf(m[y1 + x0], m[y1 + x1], tx), _qty[y])


## The kind a tile lends to a group: its own kind if it is a member, else the
## nearest member within two tiles, else the fallback.
func _path_rep(x: int, y: int, group: Array, fallback: int) -> int:
	if kind[y * w + x] in group:
		return kind[y * w + x]
	for r in range(1, 3):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var nx := x + dx
				var ny := y + dy
				if nx >= 0 and ny >= 0 and nx < w and ny < h and kind[ny * w + nx] in group:
					return kind[ny * w + nx]
	return fallback


## A natural tile for the warped lookup: the tile itself, or the nearest one that
## is not paving or water, so the grass never shows a paved tile's ground.
func _path_natural_tile(tx: int, ty: int) -> Vector2i:
	if _thard[ty * w + tx] == 0:
		return Vector2i(tx, ty)
	for r in range(1, 3):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var nx := tx + dx
				var ny := ty + dy
				if nx >= 0 and ny >= 0 and nx < w and ny < h and _thard[ny * w + nx] == 0:
					return Vector2i(nx, ny)
	return Vector2i(tx, ty)


## Bilinear weights for each pixel column and row (tile i is centered at i + 0.5).
func _path_index() -> void:
	_qx0.resize(_pw)
	_qx1.resize(_pw)
	_qtx.resize(_pw)
	for x in _pw:
		var fx := clampf((x + 0.5) / T - 0.5, 0.0, w - 1.0)
		var x0 := floori(fx)
		_qx0[x] = x0
		_qx1[x] = mini(x0 + 1, w - 1)
		_qtx[x] = fx - x0
	_qy0.resize(_ph)
	_qy1.resize(_ph)
	_qty.resize(_ph)
	for y in _ph:
		var fy := clampf((y + 0.5) / T - 0.5, 0.0, h - 1.0)
		var y0 := floori(fy)
		_qy0[y] = y0 * w
		_qy1[y] = mini(y0 + 1, h - 1) * w
		_qty[y] = fy - y0


## Ground that gets a smoothed outline instead of the warped tile lookup.
func _path_hard(k: int) -> bool:
	return k in FORMAL or _path_wet(k)


func _path_wet(k: int) -> bool:
	return _is_water(k) or k == Terrain.FALLS


## Water with a clear depth gradient: pale teal in the shallows, deeper blue out
## in the channel. Ripples gather in soft patches as small 3-pixel dashes, and
## sun glints are rare 2-pixel sparkles, so the surface reads as moving light.
func _path_water(k: int, x: int, y: int, i: int, a: float, b: float, n: float, r: float) -> Color:
	var d := _depth_at(x, y)
	var shallow := c("a4dcc8")
	var mid := c("55b3ae")
	var deep := c("2f7f98")
	var abyss := c("215c7e")
	if k == Terrain.CREEK:
		shallow = c("b2e3cc")
		mid = c("6ec0b4")
		deep = c("3f9aa0")
		abyss = c("2d7a8c")
	if k == Terrain.LAKE:
		shallow = c("8fcfb4")
		mid = c("3f9e96")
		deep = c("2a7470")
		abyss = c("1d5563")
	# Depth is at least one tile out from land; the gradient runs over ~3 tiles.
	var t := clampf((d - 0.5) / 2.5, 0.0, 1.0)
	var col := shallow.lerp(mid, smooth(0.0, 0.4, t)).lerp(deep, smooth(0.3, 0.75, t)).lerp(abyss, smooth(0.7, 1.0, t))
	col = col.lerp(abyss, smooth(0.55, 0.9, a) * 0.18)
	# Ripple patches: a 6-pixel cell holds a 3-pixel dash, only in some cells.
	var zone := smooth(0.5, 0.78, float(_nb[i]) / 255.0)
	var rp := hash2(x / 6, y / 6, 61)
	if y % 6 == 2 and x % 6 >= 1 and x % 6 <= 3 and zone > 0.2 and rp < 0.3 + zone * 0.5:
		col = col.lightened(0.16) if x % 6 == 2 else col.lightened(0.09)
	# Sun glints: a 2-pixel sparkle, at most one per 14-pixel cell, in ripple patches.
	var gx := x / 14
	var gy := y / 14
	if zone > 0.3 and hash2(gx, gy, 62) > 0.9 and y % 14 == 4 + int(hash2(gx, gy, 63) * 4.0):
		var gxo := 5 + int(hash2(gx, gy, 64) * 4.0)
		if x % 14 == gxo or x % 14 == gxo + 1:
			col = c("f6fffa")
	# Pebbles in the shallows, in small clusters.
	if d < 1.2 and hash2(x / 3, y / 3, 65) < 0.05:
		col = c("9b9482").lerp(col, 0.3 + d * 0.3)
	return col


# ---------------------------------------------------------------- water depth

func _is_water(k: int) -> bool:
	return k == Terrain.RIVER or k == Terrain.LAKE or k == Terrain.CREEK


## Distance in tiles from each tile to the nearest non-water tile, smoothed.
func _compute_water_depth() -> void:
	_water_depth.resize(w * h)
	for y in h:
		for x in w:
			var best := 9.0
			if _is_water(kind[y * w + x]):
				for r in range(1, 6):
					var found := false
					for dy in range(-r, r + 1):
						for dx in range(-r, r + 1):
							if maxi(absi(dx), absi(dy)) != r:
								continue
							var nx := x + dx
							var ny := y + dy
							if nx < 0 or ny < 0 or nx >= w or ny >= h:
								continue
							if not _is_water(kind[ny * w + nx]) and kind[ny * w + nx] != Terrain.BRIDGE:
								found = true
								best = minf(best, Vector2(dx, dy).length())
					if found:
						break
			else:
				best = 0.0
			_water_depth[y * w + x] = best


func _tint_at(x: int, y: int) -> float:
	var fx := (x + 0.0) / T - 0.5
	var fy := (y + 0.0) / T - 0.5
	var x0 := clampi(floori(fx), 0, w - 1)
	var y0 := clampi(floori(fy), 0, h - 1)
	var x1 := mini(x0 + 1, w - 1)
	var y1 := mini(y0 + 1, h - 1)
	var tx := clampf(fx - x0, 0.0, 1.0)
	var ty := clampf(fy - y0, 0.0, 1.0)
	var a := lerpf(tint[y0 * w + x0], tint[y0 * w + x1], tx)
	var b := lerpf(tint[y1 * w + x0], tint[y1 * w + x1], tx)
	return lerpf(a, b, ty)


func _depth_at(x: int, y: int) -> float:
	var fx := (x + 0.0) / T - 0.5
	var fy := (y + 0.0) / T - 0.5
	var x0 := clampi(floori(fx), 0, w - 1)
	var y0 := clampi(floori(fy), 0, h - 1)
	var x1 := mini(x0 + 1, w - 1)
	var y1 := mini(y0 + 1, h - 1)
	var tx := clampf(fx - x0, 0.0, 1.0)
	var ty := clampf(fy - y0, 0.0, 1.0)
	var a := lerpf(_water_depth[y0 * w + x0], _water_depth[y0 * w + x1], tx)
	var b := lerpf(_water_depth[y1 * w + x0], _water_depth[y1 * w + x1], tx)
	return lerpf(a, b, ty)


# ---------------------------------------------------------------- colors

func _shapes(col: Color, k: int, x: int, y: int, i: int) -> Color:
	for ring: Array in rings:
		var dx: float = x + 0.5 - ring[0]
		var dy: float = y + 0.5 - ring[1]
		var eo: float = pow(dx / ring[2], 2.0) + pow(dy / ring[3], 2.0)
		if eo > 1.5:
			continue
		var ei: float = pow(dx / ring[4], 2.0) + pow(dy / ring[5], 2.0)
		var a := float(_na[i]) / 255.0
		var b := float(_nb[i]) / 255.0
		var n := float(_nc[i]) / 255.0
		var r := hash2(x, y, 1)
		if eo <= 1.0 and ei >= 1.0:
			if eo > 0.9 or ei < 1.16:
				# cobble curb with a dark outer joint
				var cobble := hash2(x / 4 + y / 4, x / 3 - y / 5, 90)
				var curb := c("c8c1b1").lerp(c("a49d8d"), cobble)
				if eo > 0.975 or ei < 1.03:
					curb = c("6f685b")
				elif (x + y) % 5 == 0:
					curb = curb.darkened(0.12)
				return curb
			return _gravel(x, y, a, b, n, r)
		if ei < 1.0:
			return _lawn(x, y, a, b, n, r)
		# Gravel tiles of the ring outside the painted curb are lawn, except
		# the drive leaving the ring to the south.
		if k == Terrain.PARKING and not (y > ring[1] and absf(x - ring[0]) < 34.0):
			return _lawn(x, y, a, b, n, r)
	for rect in soils:
		if rect.has_point(Vector2i(x, y)):
			var lx := x - rect.position.x
			var ly := y - rect.position.y
			# round the corners
			if (lx < 2 or lx >= rect.size.x - 2) and (ly < 2 or ly >= rect.size.y - 2):
				continue
			return _bed_color(x, y, i)
	return col


func _bed_color(x: int, y: int, i: int) -> Color:
	var n := float(_nc[i]) / 255.0
	var col := c("4a3524").lerp(c("62452e"), n)
	if hash2(x, y, 40) < 0.06:
		col = col.lightened(0.14)
	return col


func _color(k: int, x: int, y: int, i: int, tx: int, ty: int) -> Color:
	var a := float(_na[i]) / 255.0
	var b := float(_nb[i]) / 255.0
	var n := float(_nc[i]) / 255.0
	var r := hash2(x, y, 1)
	match k:
		Terrain.FOREST:
			return _forest(x, y, a, b, n, r)
		Terrain.FIR:
			return _forest(x, y, a, b, n, r).lerp(c("2f4a3a"), 0.28)
		Terrain.SUBALPINE:
			return _granite_sand(x, y, a, b, n, r)
		Terrain.FOOTHILL:
			return _golden(x, y, i, a, b, n, r)
		Terrain.SCRUB:
			return _chaparral(x, y, a, b, n, r)
		Terrain.SNOW:
			return _snow(x, y, a, b, n, r)
		Terrain.ALPINE:
			return _alpine(x, y, a, b, n, r)
		Terrain.MEADOW:
			return _meadow(x, y, i, a, b, n, r, false)
		Terrain.WET_MEADOW:
			return _meadow(x, y, i, a, b, n, r, true)
		Terrain.LAWN:
			return _lawn(x, y, a, b, n, r)
		Terrain.CAMP:
			return _duff(x, y, a, b, n, r)
		Terrain.TRAIL:
			return _trail(x, y, a, b, n, r)
		Terrain.PAVED, Terrain.BUILT:
			return _flagstone(x, y, a, n, r)
		Terrain.PARKING:
			return _lot(x, y, a, b, n, r)
		Terrain.ROAD:
			return _asphalt(x, y, a, n, r)
		Terrain.SAND:
			return _sand(x, y, a, b, n, r)
		Terrain.RIVER, Terrain.LAKE, Terrain.CREEK, Terrain.FALLS:
			return _path_water(k, x, y, i, a, b, n, r)
		Terrain.BRIDGE:
			return _gravel(x, y, a, b, n, r).darkened(0.08)
		Terrain.TALUS, Terrain.SCREE:
			return _talus(x, y, a, b, n, r)
		Terrain.CLIFF, Terrain.GRANITE:
			return _rock(x, y, a, b, n, r)
	return c("6f9a44")


func _forest(x: int, y: int, a: float, b: float, n: float, r: float) -> Color:
	var col := c("4a6135").lerp(c("617647"), b)
	col = col.lerp(c("6b5a3a"), smooth(0.55, 0.85, a) * 0.6)
	col = col.lerp(c("3a4c2c"), smooth(0.5, 0.2, b) * 0.5)
	# Sunlight through the canopy: warm dappled patches.
	var dapple := smooth(0.66, 0.74, float(_nb[(y * _pw + x + 7 * _pw + 13) % _nb.size()]) / 255.0 * 0.6 + n * 0.5 * 0.4 + a * 0.35)
	col = col.lerp(c("9aa860"), dapple * 0.42)
	if r < 0.045:
		col = c("7d6842")
	elif r < 0.07:
		col = c("34462a")
	elif r < 0.078:
		col = c("a08a5a")
	# needle strokes
	if hash2(x / 2, y / 3, 9) < 0.05 and hash2(x, y, 10) < 0.7:
		col = col.lightened(0.1)
	return col


func _meadow(x: int, y: int, i: int, a: float, b: float, n: float, r: float, wet: bool) -> Color:
	var base_a := c("4a8232") if not wet else c("3d7842")
	var base_b := c("72a244") if not wet else c("5a9558")
	# broad drifts of tone, then mottling
	var col := base_a.lerp(base_b, smooth(0.3, 0.7, a))
	col = col.lerp(base_b.lightened(0.05), smooth(0.45, 0.75, b) * 0.4)
	col = col.lerp(c("b3ab52"), smooth(0.62, 0.9, a * 0.6 + b * 0.5) * 0.4)
	col = col.lerp(c("34602a"), smooth(0.42, 0.12, b) * 0.4)
	# grass blades: short vertical strokes
	var stroke := hash2(x, y / 3, 22)
	if stroke < 0.075 and y % 3 != 2:
		col = c("9ccb58") if y % 3 == 0 else c("5f9540")
	elif r < 0.05:
		col = col.darkened(0.14)
	elif r > 0.965:
		col = col.lightened(0.1)
	# wildflowers in drifts: little 2x2 blossoms
	var flower := float(_nf[i]) / 255.0
	var p := 0.0015 + 0.07 * smooth(0.62, 0.84, flower)
	if hash2(x / 2, y / 2, 33) < p and not wet:
		var pick := hash2(x / 30, y / 30, 34)
		var fc := c("f0d24a") if pick < 0.3 else (c("9b6fca") if pick < 0.55 else (c("f4f0e0") if pick < 0.72 else (c("e0713a") if pick < 0.88 else c("d95a88"))))
		col = fc if (x + y) % 2 == 0 else fc.darkened(0.12)
	elif wet and r < 0.008:
		col = c("9fc7c0")
	return col


## Foothill grass cured gold by summer, with green oak-shade patches.
func _golden(x: int, y: int, i: int, a: float, b: float, n: float, r: float) -> Color:
	var col := c("a89a4c").lerp(c("c8b862"), smooth(0.3, 0.7, a))
	col = col.lerp(c("8c8a40"), smooth(0.5, 0.8, b) * 0.4)
	col = col.lerp(c("6f8a3c"), smooth(0.66, 0.9, 1.0 - a) * 0.35)
	var stroke := hash2(x, y / 3, 24)
	if stroke < 0.08 and y % 3 != 2:
		col = c("e0d078") if y % 3 == 0 else c("8a7a3a")
	elif r < 0.05:
		col = col.darkened(0.14)
	elif r > 0.97:
		col = col.lightened(0.1)
	var flower := float(_nf[i]) / 255.0
	if hash2(x / 2, y / 2, 35) < 0.0015 + 0.04 * smooth(0.66, 0.86, flower):
		col = c("e8903a") if hash2(x / 24, y / 24, 36) < 0.6 else c("a67bd0")
	return col


func _chaparral(x: int, y: int, a: float, b: float, n: float, r: float) -> Color:
	var col := c("6b7040").lerp(c("86804a"), b)
	col = col.lerp(c("5a6238"), smooth(0.5, 0.85, a) * 0.5)
	if r < 0.07:
		col = c("4a4f2c")
	elif r < 0.1:
		col = c("9a8458")
	elif r > 0.97:
		col = col.lightened(0.1)
	return col


## High-country forest floor: pale granite grit with needle litter.
func _granite_sand(x: int, y: int, a: float, b: float, n: float, r: float) -> Color:
	var col := c("a79a7e").lerp(c("c4b896"), b)
	col = col.lerp(c("7e8260"), smooth(0.5, 0.85, a) * 0.55)
	col = col.lerp(c("5f7348"), smooth(0.72, 0.95, 1.0 - b) * 0.4)
	if r < 0.06:
		col = c("e4dcc4")
	elif r < 0.11:
		col = c("7d745f")
	elif r < 0.13:
		col = c("5a4a36")
	if hash2(x / 2, y / 3, 12) < 0.04:
		col = col.darkened(0.12)
	return col


func _snow(x: int, y: int, a: float, b: float, n: float, r: float) -> Color:
	var col := c("e8f0f6").lerp(c("cfdcea"), b * 0.8)
	col = col.lerp(c("b8c8dc"), smooth(0.55, 0.9, a) * 0.5)
	if r < 0.05:
		col = c("ffffff")
	elif r < 0.09:
		col = c("a8bad2")
	return col


func _alpine(x: int, y: int, a: float, b: float, n: float, r: float) -> Color:
	var col := c("8b8a78").lerp(c("a6a28c"), b)
	col = col.lerp(c("6e7a52"), smooth(0.45, 0.8, a) * 0.5)
	if r < 0.06:
		col = c("c8c2ac")
	elif r < 0.1:
		col = c("66604f")
	elif hash2(x / 3, y / 3, 41) < 0.012:
		col = c("d6a8c8") if hash2(x / 40, y / 40, 42) > 0.5 else c("f0e068")
	return col


func _lawn(x: int, y: int, a: float, b: float, n: float, r: float) -> Color:
	# Mown in wide alternating swaths, each swath slightly warmer on one side
	# (the grass lies toward the mower), over broad drifts of tone.
	var swath := (x / 24) % 2 == 0
	var along := float(x % 24) / 24.0
	var col := c("489043").lerp(c("5aa44c"), b)
	col = col.lerp(c("37783c"), smooth(0.55, 0.15, a) * 0.6)
	col = col.lerp(c("74bc5c"), smooth(0.55, 0.9, a) * 0.4)
	if swath:
		col = col.lightened(0.045 + 0.02 * along)
	else:
		col = col.darkened(0.035 - 0.015 * along)
	# clover and moss patches, drier tan where the lawn thins
	var patch := smooth(0.72, 0.9, float(_nb[(y * _pw + x + 11 * _pw + 5) % _nb.size()]) / 255.0 * 0.6 + n * 0.5 * 0.4 + a * 0.3)
	col = col.lerp(c("5fa04a"), patch * 0.35)
	var dry := smooth(0.78, 0.95, a * 0.5 + b * 0.5)
	col = col.lerp(c("8aa850"), dry * 0.18)
	# blades: short strokes, lit on the upper-left
	var stroke := hash2(x, y / 3, 52)
	if stroke < 0.06 and y % 3 != 2:
		col = col.lightened(0.12) if y % 3 == 0 else col.darkened(0.1)
	elif r < 0.04:
		col = col.lightened(0.07)
	elif r < 0.075:
		col = col.darkened(0.07)
	elif r > 0.9997:
		col = c("f0ecd8") # daisy
	elif r > 0.9985 and patch > 0.4:
		col = c("f4f0e0") if hash2(x, y, 53) > 0.5 else c("e8d868")
	return col


func _trail(x: int, y: int, a: float, b: float, n: float, r: float) -> Color:
	var col := c("a67f52").lerp(c("c39c69"), b)
	col = col.lerp(c("8f6b45"), smooth(0.55, 0.9, a) * 0.35)
	if r < 0.05:
		col = c("8b8478") # pebble
	elif r < 0.058:
		col = c("cfc7b6")
	elif r < 0.11:
		col = col.darkened(0.08)
	elif r > 0.97:
		col = col.lightened(0.1)
	# faint compaction lines along the trail
	if (y / 3) % 7 == 0 and n > 0.5:
		col = col.darkened(0.04)
	return col


## Campground ground: trampled duff, pine-needle litter, grit and the odd
## root-dark patch, with the packed lighter dirt worn where feet go.
func _duff(x: int, y: int, a: float, b: float, n: float, r: float) -> Color:
	var col := c("8a6c44").lerp(c("a78856"), smooth(0.3, 0.75, b))
	col = col.lerp(c("6c5434"), smooth(0.55, 0.9, a) * 0.55)
	col = col.lerp(c("b89a68"), smooth(0.7, 0.95, n * 0.5 + b * 0.5) * 0.22)
	# needle litter: short slanted strokes
	var sx := (x + y / 2) / 3
	if hash2(sx, y / 2, 15) < 0.07 and (x + y) % 3 != 0:
		col = c("5c3f24") if hash2(x, y, 16) < 0.5 else c("c9a96e")
	if r < 0.04:
		col = c("6e6658")
	elif r < 0.055:
		col = c("c8bca0")
	elif r < 0.09:
		col = col.darkened(0.1)
	elif r > 0.985:
		col = c("6c8a3e")
	return col


## A stone plaza: slabs in staggered rows, each a different width, with warm or
## cool stone per slab, a lit top-left edge and a shaded bottom-right edge. Joints
## wobble and some break so the slabs merge, the worn middle is a shade lighter,
## and moss only sits in a few joints.
func _flagstone(x: int, y: int, a: float, _n: float, r: float) -> Color:
	var i := y * _pw + x
	var wob_y := int((float(_nb[i]) / 255.0 - 0.5) * 6.0)
	var yy := y + wob_y
	var row := floori(float(yy) / 13.0)
	var ly := yy - row * 13
	var off := int(hash2(row, 3, seed_value) * 22.0)
	var xs := x + off + int((float(_nb[i]) / 255.0 - 0.5) * 4.0)
	# Vertical joints: one per 24-pixel column, each jittered within its column.
	var k0 := floori(float(xs) / 24.0)
	var p0 := k0 * 24 + int(hash2(k0, row, seed_value + 21) * 12.0)
	var slab := k0
	var start := p0
	var stop := (k0 + 1) * 24 + int(hash2(k0 + 1, row, seed_value + 21) * 12.0)
	if xs < p0:
		slab = k0 - 1
		start = (k0 - 1) * 24 + int(hash2(k0 - 1, row, seed_value + 21) * 12.0)
		stop = p0
	var lx := xs - start
	var sw := stop - start
	# Joints: a line at a slab edge, dropped now and then so slabs merge.
	var joint_v := xs == p0 and hash2(k0, row, seed_value + 22) > 0.35
	var joint_h := ly == 0 and hash2(slab, row, seed_value + 23) > 0.5
	if joint_v or joint_h:
		if hash2(x / 2, y / 2, 95) < 0.2:
			return c("64804c") # moss
		if hash2(x / 2, y / 2, 94) > 0.93:
			return c("8f9a6a")
		return c("9d9383")
	var hue := hash2(slab, row, seed_value + 8)
	var tone := hash2(slab, row, seed_value + 9)
	var col := c("d3c6a8") if hue < 0.4 else (c("bebcb0") if hue > 0.78 else c("cdb49b"))
	col = col.lerp(col.darkened(0.07), tone * 0.6)
	col = col.lightened(0.05 * smooth(0.55, 0.85, a))
	if lx == 1 or ly == 1:
		col = col.lightened(0.12)
	elif lx >= sw - 2 or ly >= 12:
		col = col.darkened(0.1)
	# Specks in small clusters, not per pixel.
	var sp := hash2(x / 2, y / 2, 97)
	if sp < 0.06:
		col = col.darkened(0.05)
	elif sp > 0.97:
		col = col.lightened(0.06)
	if r > 0.998:
		col = c("7b8f5a") # a blade of grass
	return col


func _gravel(x: int, y: int, a: float, b: float, n: float, r: float) -> Color:
	var col := c("c2b499").lerp(c("d3c8ae"), b)
	col = col.lerp(c("aa9c82"), smooth(0.55, 0.9, a) * 0.3)
	if r < 0.1:
		col = c("a39678")
	elif r < 0.16:
		col = c("e2d8c0")
	elif r < 0.19:
		col = c("8d8069")
	# raked lines
	if y % 5 == 0 and float(_nb[(y * _pw + x) % _nb.size()]) / 255.0 > 0.42:
		col = col.darkened(0.06)
	return col


## A gravel lot: the raked gravel with packed, darker tire lanes, oil-stained
## patches and a few weeds along the margins.
func _lot(x: int, y: int, a: float, b: float, n: float, r: float) -> Color:
	var col := _gravel(x, y, a, b, n, r)
	col = col.lerp(c("8e8574"), smooth(0.58, 0.85, a) * 0.5)
	# worn parking bays: faint darker lanes every 24 px
	if (x / 3) % 8 == 0 and b > 0.4:
		col = col.darkened(0.07)
	if smooth(0.7, 0.82, b * 0.7 + n * 0.3) > 0.5 and r < 0.6:
		col = col.lerp(c("5f5a52"), 0.35)
	if r > 0.9985:
		col = c("6c8a3e")
	return col


## Dark road: grit in small clusters over a faint worn patch.
func _asphalt(x: int, y: int, a: float, _n: float, _r: float) -> Color:
	var col := c("57524d").lerp(c("625b55"), smooth(0.45, 0.8, a))
	col = col.lerp(c("6b645c"), smooth(0.6, 0.85, a) * 0.3)
	var grit := hash2(x / 2, y / 2, 98)
	if grit < 0.1:
		col = c("716a62")
	elif grit > 0.92:
		col = c("45413e")
	return col


func _sand(x: int, y: int, a: float, b: float, n: float, r: float) -> Color:
	var col := c("d4c493").lerp(c("e2d5a8"), b)
	col = col.lerp(c("bfae80"), smooth(0.55, 0.9, a) * 0.35)
	if r < 0.06:
		col = c("9f927a")
	elif r < 0.085:
		col = c("f0e8c8")
	elif r < 0.1:
		col = c("b8b0a0")
	return col


func _boulder(x: int, y: int, cw: int, ch: int, ox: int, oy: int, seed_v: int) -> Vector3:
	## Inside-ness (1 inside, 0 outside), light (0..1), and edge (1 near rim)
	## of the boulder in the jittered grid cell holding (x, y).
	var gx := (x + ox) / cw
	var gy := (y + oy) / ch
	var cx := gx * cw + int(cw * (0.3 + hash2(gx, gy, seed_v) * 0.4)) - ox
	var cy := gy * ch + int(ch * (0.3 + hash2(gx, gy, seed_v + 1) * 0.4)) - oy
	var rx := cw * (0.28 + hash2(gx, gy, seed_v + 2) * 0.22)
	var ry := ch * (0.28 + hash2(gx, gy, seed_v + 3) * 0.2)
	var dx := (x - cx) / rx
	var dy := (y - cy) / ry
	var d := dx * dx + dy * dy
	if d > 1.0:
		return Vector3(0, 0, 0)
	var lit := clampf(0.55 - dx * 0.3 - dy * 0.42, 0.0, 1.0)
	return Vector3(1, lit, 1.0 if d > 0.72 else 0.0)


func _talus(x: int, y: int, a: float, b: float, n: float, r: float) -> Color:
	# Rocky forest floor at the foot of the wall: duff with scattered boulders.
	var base := _forest(x, y, a, b, n, r).darkened(0.18).lerp(c("55504a"), smooth(0.45, 0.7, a) * 0.5)
	for layer in 2:
		var cw := 17 - layer * 4
		var ch := 12 - layer * 3
		var gx := (x + layer * 9) / cw
		var gy := (y + layer * 6) / ch
		if hash2(gx, gy, 77 + layer) > 0.42:
			continue
		var bo := _boulder(x, y, cw, ch, layer * 9, layer * 6, 60 + layer * 11)
		if bo.x > 0.5:
			var tone := c("77706a").lerp(c("b9b1a5"), bo.y)
			tone = tone.lerp(c("8c8d72"), smooth(0.7, 0.9, a) * 0.3)
			if bo.z > 0.5:
				tone = tone.darkened(0.28)
			base = tone
	return base


func _rock(x: int, y: int, a: float, b: float, n: float, r: float) -> Color:
	var col := c("77716b").lerp(c("9a948b"), a)
	if float(_nb[(y * _pw + x) % _nb.size()]) / 255.0 < 0.3:
		col = col.darkened(0.15)
	if r < 0.05:
		col = col.lightened(0.1)
	return col


func _water(k: int, x: int, y: int, i: int, a: float, b: float, n: float, r: float) -> Color:
	var d := _depth_at(x, y)
	var deep := c("2b6877")
	var mid := c("3f8c94")
	var shallow := c("86c5b6")
	if k == Terrain.CREEK:
		deep = c("3a8288")
		mid = c("58a3a0")
		shallow = c("8fcbb8")
	if k == Terrain.LAKE:
		deep = c("25605e")
		mid = c("2f7a70")
		shallow = c("6cb5a0")
	var t := clampf(d / 3.2, 0.0, 1.0)
	var col := shallow.lerp(mid, smooth(0.0, 0.45, t)).lerp(deep, smooth(0.4, 1.0, t))
	# Long ripples stretched along the flow (north-south).
	var ripple := float(_nb[((y * 1) * _pw + x * 3 + (y % 5) * 0) % _nb.size()]) / 255.0
	var streak := sin(float(x) * 0.55 + b * 6.0 + float(y) * 0.05) * 0.5 + 0.5
	if streak > 0.86:
		col = col.lightened(0.12)
	elif streak < 0.1:
		col = col.darkened(0.1)
	col = col.lerp(deep, smooth(0.65, 0.95, a) * 0.3)
	# Pebbles visible through the shallows.
	if d < 1.6 and r < 0.14 - d * 0.05:
		col = c("a9a08a").lerp(col, 0.4 + d * 0.15)
	# Sun glints.
	if r > 0.9985 - t * 0.0008 and ripple > 0.4:
		col = c("f4fffb")
	elif hash2(x / 3, y, 61) > 0.992 and streak > 0.6:
		col = col.lightened(0.22)
	return col


# ---------------------------------------------------------------- finishing

## Foam where water meets land, drawn from the ground type actually shown at
## each pixel (so it follows the ragged, warped borders).
## Foam where water meets land: a soft band of flecks, thickest at the very edge,
## that follows the smoothed shoreline. Land just beside the water gets a damp
## sand band that fades into the grass.
func _shore_and_edges(im: Image) -> void:
	for y in range(3, _ph - 3):
		for x in range(3, _pw - 3):
			var i := y * _pw + x
			if _pwet[i] == 1:
				var d := _depth_at(x, y)
				var band := 0.32 + (hash2(x / 3, y / 3, 71) - 0.5) * 0.14 + (float(_nb[i]) / 255.0 - 0.5) * 0.12
				if d < 0.5 + band:
					var near := 1.0 - (d - 0.5) / band
					if hash2(x / 2, y / 2, 72) < 0.3 + near * 0.6:
						im.set_pixel(x, y, c("eef8f2") if near > 0.55 else c("b9dfd4"))
			elif _phard[i] == 0 and (_pwet[i + 3] == 1 or _pwet[i - 3] == 1 or _pwet[i + 3 * _pw] == 1 or _pwet[i - 3 * _pw] == 1):
				if hash2(x / 2, y / 2, 73) < 0.7:
					im.set_pixel(x, y, im.get_pixel(x, y).lerp(c("8f8462"), 0.35))


## Soft gravel shoulders beside roads, fading over a few pixels and broken into
## clusters, and a subtle dark edge line on the road itself.
func _road_shoulders(im: Image) -> void:
	var edits := {}
	for y in range(2, _ph - 2):
		for x in range(2, _pw - 2):
			var i := y * _pw + x
			var k := _pk[i]
			var s := _road_s[i]
			if k == Terrain.ROAD:
				if s < 0.64 and hash2(x / 3, y / 3, 81) > 0.3:
					edits[i] = im.get_pixel(x, y).darkened(0.2)
			elif _phard[i] == 0 and k != Terrain.CLIFF and k != Terrain.GRANITE and s > 0.06:
				var amt := 0.55 * smooth(0.06, 0.5, s) * (0.8 + 0.2 * hash2(x / 2, y / 2, 88))
				edits[i] = im.get_pixel(x, y).lerp(c("a08e6c"), amt)
	for i: int in edits:
		im.set_pixel(i % _pw, i / _pw, edits[i])


## A pixel of formal ground (paved, gravel, plaza) that sits against natural
## ground gets a curb; see [member edge_trim].
func _edge_trim(im: Image) -> void:
	# A painted ring has its own curb, so its gravel is left alone.
	var trim := [Terrain.PAVED, Terrain.BUILT] if not rings.is_empty() else [Terrain.PAVED, Terrain.PARKING, Terrain.BUILT]
	var edits := {}
	for y in range(2, _ph - 2):
		for x in range(2, _pw - 2):
			var i := y * _pw + x
			var k := _pk[i]
			if k in trim:
				var out := 0
				for o: int in [1, -1, _pw, -_pw]:
					var nk := _pk[i + o]
					if nk not in trim and nk != Terrain.PARKING and nk != Terrain.ROAD and nk != Terrain.BRIDGE and not _is_water(nk):
						out += 1
				if out > 0:
					edits[i] = im.get_pixel(x, y).darkened(0.34)
				else:
					var inner := 0
					for o: int in [2, -2, 2 * _pw, -2 * _pw]:
						var nk := _pk[i + o]
						if nk not in trim and nk != Terrain.PARKING and nk != Terrain.ROAD and nk != Terrain.BRIDGE and not _is_water(nk):
							inner += 1
					if inner > 0:
						edits[i] = im.get_pixel(x, y).lightened(0.07)
			elif k not in FORMAL and not _is_water(k) and k != Terrain.CLIFF and k != Terrain.GRANITE:
				# contact shadow, heavier on the south and east sides of a curb
				for d: Vector2i in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0)]:
					if _pk[i + d.y * _pw + d.x] in trim:
						var amount := 0.2 if d.y == -1 or d.x == -1 else 0.1
						edits[i] = im.get_pixel(x, y).darkened(amount)
						break
	for i: int in edits:
		im.set_pixel(i % _pw, i / _pw, edits[i])
