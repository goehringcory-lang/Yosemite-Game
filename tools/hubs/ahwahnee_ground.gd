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
## How far (in tiles) the path distance fields look for an edge.
const PATH_REACH := 3

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
## Glacier Point's ground: granite as smooth domed slabs peeling in sheets
## (not faceted blocks), and the red fir forest's floor as brown needle duff
## with moss only in the hollows.
var smooth_granite := false
var fir_duff := false

var _na := PackedByteArray() # large scale
var _nb := PackedByteArray() # medium scale
var _nc := PackedByteArray() # small scale
var _wx := PackedByteArray() # warp x
var _wy := PackedByteArray() # warp y
var _nf := PackedByteArray() # flower clusters
var _pk := PackedByteArray() # the ground type shown at each pixel
var _pw := 0
var _ph := 0
## Per-pixel road cover (0..1) from the smoothed road mask, for the shoulders.
var _road_s := PackedFloat32Array()
## Per-pixel depth (in tiles, 0.5 at the shore) of water pixels, from the
## smoothed outline, so the foam and the depth tint follow its curves.
var _pdep := PackedFloat32Array()
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
	_path_index()
	_path_groups()
	var out := PackedByteArray()
	out.resize(_pw * _ph * 4)
	_pk.resize(_pw * _ph)
	_road_s.resize(_pw * _ph)
	_pdep.resize(_pw * _ph)
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
			# The shoreline wobbles on low-frequency noise; roads do not.
			var own := kind[near]
			# (_tany skips the samples where no group cover is near.)
			if _tany[near] == 1 and own == Terrain.BRIDGE and _path_sample(_mpave, x, y) > -0.4:
				k = Terrain.BRIDGE
			elif _tany[near] == 1 and _path_sample(_mwet, x, y) > _path_cut((float(_na[i]) / 255.0 - 0.5) * 0.5):
				k = _wkind[near]
				_pdep[i] = 0.5 + _path_sample(_mwet, x, y) - _path_cut((float(_na[i]) / 255.0 - 0.5) * 0.5)
			elif _tany[near] == 1 and _path_sample(_mroad, x, y) > _path_cut(0.0):
				k = Terrain.ROAD
			elif _tany[near] == 1 and _path_sample(_mpave, x, y) > _path_cut(0.0):
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
			_road_s[i] = clampf(0.5 + _path_sample(_mroad, x, y) * 0.6, 0.0, 1.0)
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


## Smoothed outlines for the formal and water groups. Each group gets a signed
## distance field at tile resolution (tile centers, in tiles: positive inside,
## negative outside, zero on the tile edge), lightly smoothed. Sampled
## bilinearly at each pixel and cut near zero, it keeps a run's real width
## (one-tile roads and streams stay one tile wide) while tile steps become
## diagonals and square corners round off.
func _path_groups() -> void:
	var n := w * h
	var road := PackedByteArray()
	var pave := PackedByteArray()
	var wet := PackedByteArray()
	road.resize(n)
	pave.resize(n)
	wet.resize(n)
	for t in n:
		road[t] = 1 if kind[t] == Terrain.ROAD else 0
		pave[t] = 1 if kind[t] in PAVE_SET else 0
		wet[t] = 1 if _path_wet(kind[t]) else 0
	_mroad = _path_blur(_path_sdf(road))
	_mpave = _path_blur(_path_sdf(pave))
	_mwet = _path_blur(_path_sdf(wet))
	_thard.resize(n)
	for t in n:
		_thard[t] = 1 if _path_hard(kind[t]) else 0
	# Tiles with any group edge within reach; elsewhere every sample is far out.
	_tany.resize(n)
	for y in h:
		for x in w:
			var any := 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var t := clampi(y + dy, 0, h - 1) * w + clampi(x + dx, 0, w - 1)
					if _mroad[t] > -1.0 or _mpave[t] > -1.0 or _mwet[t] > -1.0:
						any = 1
			_tany[y * w + x] = any
	_fkind.resize(n)
	_wkind.resize(n)
	for y in h:
		for x in w:
			_fkind[y * w + x] = _path_rep(x, y, PAVE_SET, Terrain.PAVED)
			_wkind[y * w + x] = _path_rep(x, y, WET_SET, Terrain.RIVER)


## Signed distance (in tiles) from each tile center to the edge of a 0/1 tile
## mask, searched out to PATH_REACH tiles and clamped there.
func _path_sdf(m: PackedByteArray) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(w * h)
	for y in h:
		for x in w:
			var inside := m[y * w + x]
			var best := float(PATH_REACH * PATH_REACH + 1)
			for dy in range(-PATH_REACH, PATH_REACH + 1):
				var ny := y + dy
				if ny < 0 or ny >= h:
					continue
				for dx in range(-PATH_REACH, PATH_REACH + 1):
					var nx := x + dx
					if nx < 0 or nx >= w or m[ny * w + nx] == inside:
						continue
					best = minf(best, float(dx * dx + dy * dy))
			var d := minf(sqrt(best), float(PATH_REACH)) - 0.5
			out[y * w + x] = d if inside == 1 else -d
	return out


## A center-weighted 3x3 blur (edges clamped), mixed with the original, which
## rounds the distance field's corners without shifting its zero line on
## straight runs.
func _path_blur(src: PackedFloat32Array) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(w * h)
	for y in h:
		for x in w:
			var s := 0.0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var wt := 4.0 if dx == 0 and dy == 0 else (2.0 if dx == 0 or dy == 0 else 1.0)
					s += src[clampi(y + dy, 0, h - 1) * w + clampi(x + dx, 0, w - 1)] * wt
			# Half blur, half original, so a lone tile or a one-tile run keeps
			# its body instead of blurring away.
			b[y * w + x] = lerpf(src[y * w + x], s / 16.0, 0.45)
	return b


## The distance-field cutoff for a pixel, in tiles: a little below the edge so
## runs that only touch at a corner stay joined, plus an optional wobble.
func _path_cut(wobble: float) -> float:
	return -0.12 + wobble


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
	var d := _pdep[i]
	var shallow := c("5bb5ad")
	var mid := c("3f9aa3")
	var deep := c("2f7f98")
	var abyss := c("215c7e")
	if k == Terrain.CREEK:
		shallow = c("68bdb0")
		mid = c("6ec0b4")
		deep = c("3f9aa0")
		abyss = c("2d7a8c")
	if k == Terrain.LAKE:
		shallow = c("4fa99c")
		mid = c("3f9e96")
		deep = c("2a7470")
		abyss = c("1d5563")
	# Depth is 0.5 at the shore; the gradient runs over ~2 tiles.
	var t := clampf((d - 0.5) / 1.8, 0.0, 1.0)
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


# ---------------------------------------------------------------- water

func _is_water(k: int) -> bool:
	return k == Terrain.RIVER or k == Terrain.LAKE or k == Terrain.CREEK


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
	# Dark garden soil in four steps, with small clods.
	var a := float(_na[i]) / 255.0
	var lvl := _nat_tone(a, x, y)
	var col: Color = [c("3a2a1c"), c("4a3524"), c("5a402a"), c("62452e")][lvl]
	var clod := _nat_pebble(x, y, 9, 401, 0.25)
	if clod == 1:
		col = c("7a5a3e")
	elif clod == 2:
		col = c("5a4129")
	elif clod == 3:
		col = c("35261a")
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
			if fir_duff:
				return _fir_duff(x, y, a, b, n, r)
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
		Terrain.GRANITE:
			if smooth_granite:
				return _slab(x, y, a, b, n, r)
			return _rock(x, y, a, b, n, r)
		Terrain.CLIFF:
			return _rock(x, y, a, b, n, r)
	return c("6f9a44")


func _forest(x: int, y: int, a: float, b: float, n: float, r: float) -> Color:
	# Mossy forest floor in four tone steps: blue-green moss in the shade,
	# olive in the light, and warm needle-duff patches where the field runs high.
	# Tones kept close, so the floor reads as one calm ground with tufts on
	# it (far-apart steps read as a busy camouflage), the duff only where
	# the field runs highest, and twigs few.
	var lvl := _nat_tone(a * 0.6 + b * 0.4, x, y)
	var col: Color = [c("41603f"), c("4a6636"), c("54703a"), c("5f783c")][lvl]
	if _nat_tone(clampf(b * 2.2 - 1.3, 0.0, 1.0), x, y) == 3:
		col = c("6f5a3a")
	# Needle litter and twigs as small clusters.
	var twig := _nat_pair(x, y, 9, 311, 0.07)
	if twig == 1:
		col = c("a88a58")
	elif twig == 2:
		col = c("4a3420")
	# Moss and fern tufts with lit tips.
	var tuft := _nat_tuft(x, y, 11, 301, 0.3)
	if tuft == 1:
		col = c("3d6234")
	elif tuft == 3:
		col = c("2f5140")
	elif tuft == 2:
		col = c("7c9a58")
	return col


func _meadow(x: int, y: int, i: int, a: float, b: float, n: float, r: float, wet: bool) -> Color:
	# Warm mid-green turf (wet meadow is bluer). Foothill tiles get straw grass.
	var mode := 1 if wet else 0
	if not wet and kind[clampi(y / T, 0, h - 1) * w + clampi(x / T, 0, w - 1)] == Terrain.FOOTHILL:
		mode = 2
	return _nat_grass(x, y, a, b, mode)


## Foothill grass cured gold by summer, with green oak-shade patches.
func _golden(x: int, y: int, i: int, a: float, b: float, n: float, r: float) -> Color:
	# Foothill grass cured gold by summer: ochre base, dense gold tufts.
	return _nat_grass(x, y, a, b, 2)


func _chaparral(x: int, y: int, a: float, b: float, n: float, r: float) -> Color:
	# Chaparral floor: dusty olive-sage in four steps, dry tan patches, shrub clumps.
	var lvl := _nat_tone(b * 0.6 + a * 0.4, x, y)
	var col: Color = [c("4f6040"), c("626c44"), c("7c7c4c"), c("9a8458")][lvl]
	var tuft := _nat_tuft(x, y, 11, 411, 0.45)
	if tuft == 1:
		col = c("4a5a32")
	elif tuft == 3:
		col = c("3b4d3c")
	elif tuft == 2:
		col = c("a2a36a")
	var peb := _nat_pebble(x, y, 9, 421, 0.12)
	if peb == 1:
		col = c("c9b58e")
	elif peb == 2:
		col = c("9a8458")
	elif peb == 3:
		col = c("4a4f2c")
	return col


## High-country forest floor: pale granite grit with needle litter.
## High-country forest floor: pale granite grit with needle litter.
func _granite_sand(x: int, y: int, a: float, b: float, n: float, r: float) -> Color:
	var lvl := _nat_tone(b * 0.6 + a * 0.4, x, y)
	var col: Color = [c("737a5c"), c("a09580"), c("b8ac8e"), c("cbbf9e")][lvl]
	var peb := _nat_pebble(x, y, 8, 431, 0.22)
	if peb == 1:
		col = c("e4dcc4")
	elif peb == 2:
		col = c("7d745f")
	elif peb == 3:
		col = c("5a4a36")
	var twig := _nat_pair(x, y, 9, 441, 0.1)
	if twig == 1:
		col = c("8a6a48")
	elif twig == 2:
		col = c("4f3d2a")
	return col


func _snow(x: int, y: int, a: float, b: float, n: float, r: float) -> Color:
	# Cool blue-white snow in four steps, with a few ice glints.
	var lvl := _nat_tone(b * 0.5 + a * 0.5, x, y)
	var col: Color = [c("b8c8dc"), c("d4e0ec"), c("e8f0f6"), c("f6fafd")][lvl]
	var glint := _nat_pair(x, y, 10, 451, 0.04)
	if glint == 1:
		col = c("ffffff")
	elif glint == 2:
		col = c("a8bed6")
	return col


func _alpine(x: int, y: int, a: float, b: float, n: float, r: float) -> Color:
	# Alpine turf: grey-green in four steps on granite grit, a few bright flowers.
	var lvl := _nat_tone(b * 0.5 + a * 0.5, x, y)
	var col: Color = [c("6a7458"), c("82846a"), c("9a9a80"), c("b2ae94")][lvl]
	var peb := _nat_pebble(x, y, 9, 471, 0.14)
	if peb == 1:
		col = c("c8c2ac")
	elif peb == 2:
		col = c("a6a28c")
	elif peb == 3:
		col = c("66604f")
	var tuft := _nat_tuft(x, y, 11, 461, 0.4)
	if tuft == 1:
		col = c("56694a")
	elif tuft == 3:
		col = c("4a5e52")
	elif tuft == 2:
		col = c("a8b478")
	var fl := _nat_flower(x, y, 19, 481, 0.03)
	if fl.x != 0:
		col = c("d6a8c8") if fl.y % 2 == 0 else c("f0e068")
	return col


func _lawn(x: int, y: int, a: float, b: float, n: float, r: float) -> Color:
	# Mown turf: soft, wide mow bands that fade into each other, no hard stripes.
	var band := sin(float(x) * 0.09 + b * 2.5 + float(y) * 0.012)
	var col := c("4f9a40").lerp(c("5aa84a"), smooth(0.6, 0.9, a) * 0.6)
	col = col.lerp(c("3f8a52"), smooth(0.5, 0.15, a) * 0.5)
	col = col.lerp(c("62ad4c"), smooth(-0.3, 0.9, band) * 0.25)
	# A few short, cut tufts and rare daisies.
	var tuft := _nat_tuft(x, y, 11, 341, 0.22)
	if tuft == 1:
		col = c("2f6a2e")
	elif tuft == 3:
		col = c("2a5e44")
	elif tuft == 2:
		col = c("9ad273")
	var fl := _nat_flower(x, y, 17, 351, 0.012)
	if fl.x != 0:
		col = c("f5f1e2") if fl.x == 1 else c("f2d262")
	return col


func _trail(x: int, y: int, a: float, b: float, n: float, r: float) -> Color:
	# Packed dirt in tone steps from low-frequency noise, so no band follows
	# the tile grid under the ragged trail outline.
	var lvl := _nat_tone(0.3 + a * 0.45 + b * 0.22, x, y)
	var col: Color = [c("7a5448"), c("96704c"), c("b08758"), c("c89f6e")][lvl]
	# Pebble clusters: lit top-left, dark below.
	var peb := _nat_pebble(x, y, 10, 361, 0.14)
	if peb == 1:
		col = c("d8caa6")
	elif peb == 2:
		col = c("a6977f")
	elif peb == 3:
		col = c("5f5349")
	return col


## Campground ground: trampled needle duff and twigs in four tone steps,
## with grit and the odd root-dark patch.
func _duff(x: int, y: int, a: float, b: float, n: float, r: float) -> Color:
	var lvl := _nat_tone(0.15 + b * 0.45 + a * 0.35, x, y)
	var col: Color = [c("6a4f30"), c("846140"), c("a07c4f"), c("b89a68")][lvl]
	var twig := _nat_pair(x, y, 7, 491, 0.3)
	if twig == 1:
		col = c("c9a96e")
	elif twig == 2:
		col = c("5c3f24")
	var peb := _nat_pebble(x, y, 11, 501, 0.1)
	if peb == 1:
		col = c("b9ab8c")
	elif peb == 2:
		col = c("8f7f66")
	elif peb == 3:
		col = c("5a4c3c")
	return col


## A stone plaza: slabs in staggered rows, each a different width, with warm or
## cool stone per slab, a lit top-left edge and a shaded bottom-right edge. Joints
## wobble and some break so the slabs merge, the worn middle is a shade lighter,
## and moss only sits in a few joints.
func _flagstone(x: int, y: int, a: float, _n: float, r: float) -> Color:
	var i := y * _pw + x
	# Slabs about 16x9, a person standing on two or three of them: big slabs
	# in straight courses read as a wall standing up, not a floor.
	var wob_y := int((float(_nb[i]) / 255.0 - 0.5) * 4.0)
	var yy := y + wob_y
	var row := floori(float(yy) / 9.0)
	var ly := yy - row * 9
	var off := int(hash2(row, 3, seed_value) * 14.0)
	var xs := x + off + int((float(_nb[i]) / 255.0 - 0.5) * 4.0)
	# Vertical joints: one per 16-pixel column, each jittered within its column.
	var k0 := floori(float(xs) / 16.0)
	var p0 := k0 * 16 + int(hash2(k0, row, seed_value + 21) * 8.0)
	var slab := k0
	var start := p0
	var stop := (k0 + 1) * 16 + int(hash2(k0 + 1, row, seed_value + 21) * 8.0)
	if xs < p0:
		slab = k0 - 1
		start = (k0 - 1) * 16 + int(hash2(k0 - 1, row, seed_value + 21) * 8.0)
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
	var col := c("d0c4a8") if hue < 0.45 else (c("c6c0ae") if hue > 0.8 else c("cbbca1"))
	col = col.lerp(col.darkened(0.05), tone * 0.5)
	col = col.lightened(0.05 * smooth(0.55, 0.85, a))
	if lx == 1 or ly == 1:
		col = col.lightened(0.12)
	elif lx >= sw - 2 or ly >= 8:
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
	# Pale sand in four steps: cooler wind-shaded hollows, warm ridges, pebbles.
	var lvl := _nat_tone(b * 0.5 + a * 0.5, x, y)
	var col: Color = [c("b9a77e"), c("cdb98a"), c("dccb92"), c("e9dcae")][lvl]
	var peb := _nat_pebble(x, y, 10, 371, 0.1)
	if peb == 1:
		col = c("f3ead0")
	elif peb == 2:
		col = c("c6b79c")
	elif peb == 3:
		col = c("9a8c76")
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
	var base := _forest(x, y, a, b, n, r)
	if _nat_tone(a, x, y) >= 2:
		base = c("57534c")
	for layer in 2:
		var cw := 17 - layer * 4
		var ch := 12 - layer * 3
		var gx := (x + layer * 9) / cw
		var gy := (y + layer * 6) / ch
		if hash2(gx, gy, 77 + layer) > 0.42:
			continue
		var bo := _boulder(x, y, cw, ch, layer * 9, layer * 6, 60 + layer * 11)
		if bo.x > 0.5:
			# Lit upper-left in steps, cool rim on the shadow side.
			var tone: Color = [c("6f6a64"), c("8a847b"), c("a79f92"), c("c0b8aa")][_nat_tone(bo.y, x, y)]
			if bo.z > 0.5:
				tone = c("4e5260")
			base = tone
	return base


## Bare granite slab: smooth, pale and warm in the sun, in broad tones; the
## edges of the exfoliating sheets as soft darker lines; a few cracks, grit,
## and lichen in green and rust.
func _slab(x: int, y: int, a: float, b: float, n: float, r: float) -> Color:
	var lvl := _nat_tone(a * 0.7 + b * 0.3, x, y)
	var col: Color = [c("8f8b84"), c("a39e94"), c("b5afa2"), c("c6bfae")][lvl]
	# sheet edges: thin lines where the medium field crosses a step
	var sheet := fmod(b * 5.0 + a * 1.5, 1.0)
	if sheet < 0.035:
		col = c("7c7974")
	elif sheet < 0.07:
		col = col.darkened(0.06)
	var crack := _nat_pair(x, y, 13, 611, 0.03)
	if crack != 0:
		col = c("66646a")
	var grit := _nat_pebble(x, y, 7, 621, 0.08)
	if grit == 1:
		col = c("d8d0bc")
	elif grit == 2:
		col = c("7a766e")
	var lichen := _nat_pair(x, y, 17, 631, 0.04)
	if lichen == 1:
		col = c("a9a262")
	elif lichen == 2 and r < 0.4:
		col = c("b07a42")
	return col


## The red fir forest floor: a deep brown mat of needles and cone scales,
## twigs, and moss only where the low field dips.
func _fir_duff(x: int, y: int, a: float, b: float, n: float, r: float) -> Color:
	var col := _duff(x, y, a, b, n, r)
	col = col.lerp(c("4a3a2a"), 0.22)
	if _nat_tone(clampf(1.2 - a * 2.0, 0.0, 1.0), x, y) == 3:
		col = _forest(x, y, a, b, n, r)
	return col


func _rock(x: int, y: int, a: float, b: float, n: float, r: float) -> Color:
	# Granite: faceted slabs lit on the upper-left in steps, cool cracks, rare lichen.
	var v := _nat_vor(x, y, 13, 381)
	var lvl := _nat_tone(v.z, x, y)
	var col: Color
	if v.x > 0.5:
		col = [c("5f6068"), c("70727a"), c("80838a"), c("93959b")][lvl]
	else:
		col = [c("6e6a64"), c("847e76"), c("988f84"), c("aca596")][lvl]
	if v.y < 0.9:
		col = c("58565e")
	if _nat_pair(x, y, 9, 391, 0.05) != 0:
		col = c("a9a262")
	return col



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
				var d := _pdep[i]
				# A thin, steady foam line at the shore, then a broken lighter
				# band just inside it.
				var wob := (float(_nb[i]) / 255.0 - 0.5) * 0.06
				if d < 0.56 + wob:
					im.set_pixel(x, y, c("e4f4ec"))
				elif d < 0.68 + wob and hash2(x / 2, y / 2, 72) < 0.45:
					im.set_pixel(x, y, im.get_pixel(x, y).lerp(c("bfe3d6"), 0.6))
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


## Quantizes a low-frequency value (0..1) into four tone steps (0 darkest to
## 3 brightest). Where two steps meet, a 1 px checker band alternates between
## them, so the edge reads as hand-placed pixels rather than a soft gradient.
func _nat_tone(v: float, x: int, y: int) -> int:
	var f := clampf(v, 0.0, 0.9999) * 4.0
	var lvl := int(f)
	var frac := f - float(lvl)
	var checker := (x + y) % 2 == 0
	if frac < 0.06 and lvl > 0 and checker:
		lvl -= 1
	elif frac > 0.94 and lvl < 3 and checker:
		lvl += 1
	return lvl


## Grass ground shared by the meadow kinds. Mode 0 meadow, 1 wet meadow,
## 2 golden foothill grass (ochre base, gold tufts, no flowers).
func _nat_grass(x: int, y: int, a: float, b: float, mode: int) -> Color:
	var lvl := _nat_tone(a * 0.7 + b * 0.3, x, y)
	var col: Color
	var body := c("2b5a33")
	var shade_body := c("23503f")
	var tip := c("b8d878")
	if mode == 1:
		col = [c("2f5e48"), c("3b6e52"), c("4f8a5e"), c("6aa074")][lvl]
		body = c("1f4a3c")
		shade_body = c("1a3f36")
		tip = c("9fd0b0")
	elif mode == 2:
		col = [c("8a7236"), c("a88a40"), c("c2a24c"), c("d8bc66")][lvl]
		body = c("6e5222")
		shade_body = c("5c4a22")
		tip = c("f4e28a")
	else:
		col = [c("3d7452"), c("4f8a44"), c("6a9e3a"), c("9ab554")][lvl]
	# Grass tufts: darker "v" and "w" marks with a lighter tip.
	var tuft_p := 0.5
	if mode == 1:
		tuft_p = 0.3
	elif mode == 2:
		tuft_p = 0.7
	var tuft := _nat_tuft(x, y, 11, 321, tuft_p)
	if tuft == 1:
		col = body
	elif tuft == 3:
		col = shade_body
	elif tuft == 2:
		col = tip
	# Sparse wildflowers in small clusters, gathered into drifts.
	if mode == 0:
		var fl := _nat_flower(x, y, 13, 331, 0.14)
		if fl.x != 0:
			var petal: Color = [c("f6f2e4"), c("f4dc4e"), c("ea9ac0"), c("a98ad8")][fl.y]
			var centre: Color = [c("f2c94a"), c("e0962e"), c("f2e08a"), c("f0d880")][fl.y]
			col = petal if fl.x == 1 else centre
	return col


## Offset from the nearest cell anchor, plus the cell's hash. Anchors sit at
## least 2 px inside their cell, so a sprite that reaches 2 px around its
## anchor never spills into a neighbouring cell.
func _nat_jit(x: int, y: int, cs: int, s: int) -> Vector3:
	var gx := x / cs
	var gy := y / cs
	var ax := gx * cs + 2 + int(hash2(gx, gy, s) * float(cs - 5))
	var ay := gy * cs + 2 + int(hash2(gx, gy, s + 1) * float(cs - 5))
	return Vector3(float(x - ax), float(y - ay), hash2(gx, gy, s + 2))


## Grass tuft at (x, y): 0 none, 1 blade, 2 lit tip, 3 shaded blade. Each tuft
## is a 5 px "v" or "w" built from its cell anchor; cells above prob stay empty.
func _nat_tuft(x: int, y: int, cs: int, s: int, prob: float) -> int:
	var d := _nat_jit(x, y, cs, s)
	if d.z > prob:
		return 0
	var dx := int(d.x)
	var dy := int(d.y)
	if hash2(x / cs, y / cs, s + 3) < 0.5:
		# v: two blades splaying up from the root at (0, 0)
		if dx == 0 and dy == 0:
			return 1
		if dy == -1 and absi(dx) == 1:
			return 3 if dx > 0 else 1
		if dy == -2 and absi(dx) == 2:
			return 2 if dx < 0 else 3
		return 0
	# w: three tips over two valleys
	if dy == -1 and (dx == -2 or dx == 0 or dx == 2):
		return 2 if dx == -2 else (3 if dx > 0 else 1)
	if dy == 0 and (dx == -1 or dx == 1):
		return 3 if dx > 0 else 1
	return 0


## Wildflower cluster: Vector2i(state, colour index), state 0 none, 1 petal,
## 2 centre. Density follows the flower field at the cell centre, so the
## blooms come in drifts and a cluster never flickers between pixels.
func _nat_flower(x: int, y: int, cs: int, s: int, base: float) -> Vector2i:
	var d := _nat_jit(x, y, cs, s)
	var gx := x / cs
	var gy := y / cs
	var fy := clampi(gy * cs + cs / 2, 0, _ph - 1)
	var fx := clampi(gx * cs + cs / 2, 0, _pw - 1)
	var fld := float(_nf[fy * _pw + fx]) / 255.0
	var prob := base * (0.4 + 1.6 * smooth(0.5, 0.85, fld))
	if d.z > prob:
		return Vector2i(0, 0)
	var dx := int(d.x)
	var dy := int(d.y)
	var pick := int(clampf(d.z / maxf(prob, 0.0001) * 4.0, 0.0, 3.0))
	if dx == 0 and dy == 0:
		return Vector2i(2, pick)
	if (dx == -1 and dy == 0) or (dx == 0 and dy == -1):
		return Vector2i(1, pick)
	return Vector2i(0, 0)


## Two-pixel litter or twig: 1 on the lit pixel, 2 on the dark pixel beside it
## (right or below, chosen per cell), 0 elsewhere.
func _nat_pair(x: int, y: int, cs: int, s: int, prob: float) -> int:
	var d := _nat_jit(x, y, cs, s)
	if d.z > prob:
		return 0
	var dx := int(d.x)
	var dy := int(d.y)
	if dx == 0 and dy == 0:
		return 1
	var horiz := hash2(x / cs, y / cs, s + 3) < 0.5
	if horiz and dx == 1 and dy == 0:
		return 2
	if not horiz and dx == 0 and dy == 1:
		return 2
	return 0


## Three-pixel pebble: 1 lit top-left, 2 mid to its right, 3 dark below it,
## 0 elsewhere.
func _nat_pebble(x: int, y: int, cs: int, s: int, prob: float) -> int:
	var d := _nat_jit(x, y, cs, s)
	if d.z > prob:
		return 0
	var dx := int(d.x)
	var dy := int(d.y)
	if dx == 0 and dy == 0:
		return 1
	if dx == 1 and dy == 0:
		return 2
	if dx == 0 and dy == 1:
		return 3
	return 0


## Voronoi facets: Vector3(facet hash, distance to the facet edge, lit). Lit is
## high on the upper-left side of each facet and falls off toward lower-right.
func _nat_vor(x: int, y: int, cs: int, s: int) -> Vector3:
	var gx := x / cs
	var gy := y / cs
	var best := 1.0e9
	var second := 1.0e9
	var bdx := 0.0
	var bdy := 0.0
	var bid := 0.0
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			var cx := gx + ox
			var cy := gy + oy
			var px := cx * cs + int(hash2(cx, cy, s) * float(cs))
			var py := cy * cs + int(hash2(cx, cy, s + 1) * float(cs))
			var ddx := float(x - px)
			var ddy := float(y - py)
			var dd := ddx * ddx + ddy * ddy
			if dd < best:
				second = best
				best = dd
				bdx = ddx
				bdy = ddy
				bid = hash2(cx, cy, s + 2)
			elif dd < second:
				second = dd
	var lit := clampf(0.5 - (bdx + bdy) / (1.5 * float(cs)), 0.0, 1.0)
	return Vector3(bid, sqrt(second) - sqrt(best), lit)

