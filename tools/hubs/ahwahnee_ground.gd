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
	var out := PackedByteArray()
	out.resize(_pw * _ph * 4)
	_pk.resize(_pw * _ph)
	for y in _ph:
		for x in _pw:
			var i := y * _pw + x
			# Warp the lookup so borders between ground types are ragged.
			var wxn := float(_wx[i]) / 255.0 - 0.5
			var wyn := float(_wy[i]) / 255.0 - 0.5
			var jx := (hash2(x, y, 5) - 0.5) * 2.4
			var jy := (hash2(x, y, 6) - 0.5) * 2.4
			var tx := clampi((x + int(wxn * 17.0 + jx)) / T, 0, w - 1)
			var ty := clampi((y + int(wyn * 17.0 + jy)) / T, 0, h - 1)
			var k := kind[ty * w + tx]
			# Paved, gravel and road edges stay crisp; natural ground is ragged.
			var sx := clampi((x + int(wxn * 1.6 + jx * 0.5)) / T, 0, w - 1)
			var sy := clampi((y + int(wyn * 1.6 + jy * 0.5)) / T, 0, h - 1)
			var ks := kind[sy * w + sx]
			if ks in FORMAL or k in FORMAL:
				k = ks
				tx = sx
				ty = sy
			_pk[i] = k
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
	# Dark garden soil with small clods; no per-pixel grain.
	var a := float(_na[i]) / 255.0
	var col := c("4a3524").lerp(c("62452e"), smooth(0.35, 0.75, a))
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
			return _water(k, x, y, i, a, b, n, r)
		Terrain.BRIDGE:
			return _gravel(x, y, a, b, n, r).darkened(0.08)
		Terrain.TALUS, Terrain.SCREE:
			return _talus(x, y, a, b, n, r)
		Terrain.CLIFF, Terrain.GRANITE:
			return _rock(x, y, a, b, n, r)
	return c("6f9a44")


func _forest(x: int, y: int, a: float, b: float, n: float, r: float) -> Color:
	# Mossy forest floor: olive moss, warm needle duff, cool shade in the hollows.
	var shade := smooth(0.5, 0.2, a)
	var col := c("5d7a3c").lerp(c("3f5d40"), shade * 0.6)
	col = col.lerp(c("7a5a37"), smooth(0.5, 0.85, b) * 0.45)
	# Sunlight through the canopy: soft warm patches, grouped rather than dotted.
	var sun := smooth(0.6, 0.74, b * 0.5 + a * 0.5)
	col = col.lerp(c("9aa45e"), sun * 0.3)
	# Needle litter and twigs as small clusters.
	var twig := _nat_pair(x, y, 9, 311, 0.2)
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
	# Foothill grass cured gold by summer.
	return _nat_grass(x, y, a, b, 2)


func _chaparral(x: int, y: int, a: float, b: float, n: float, r: float) -> Color:
	# Chaparral floor: dusty olive-sage with dry tan patches and low shrub clumps.
	var col := c("6b7040").lerp(c("86804a"), smooth(0.4, 0.8, b))
	col = col.lerp(c("4f6040"), smooth(0.5, 0.2, a) * 0.5)
	col = col.lerp(c("9a8458"), smooth(0.7, 0.95, a) * 0.35)
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
	var col := c("a79a7e").lerp(c("c4b896"), smooth(0.3, 0.8, b))
	col = col.lerp(c("7e8260"), smooth(0.55, 0.9, a) * 0.45)
	col = col.lerp(c("5f7348"), smooth(0.72, 0.95, 1.0 - b) * 0.3)
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
	# Cool blue-white drifts: lit wind crests, blue hollows, a few ice glints.
	var drift := sin(float(x) * 0.07 + b * 3.0 - float(y) * 0.05)
	var col := c("e8f0f6").lerp(c("cfdcea"), b * 0.6)
	col = col.lerp(c("b8c8dc"), smooth(0.55, 0.9, a) * 0.5)
	col = col.lerp(c("f6fafd"), smooth(0.3, 0.9, drift) * 0.35)
	var glint := _nat_pair(x, y, 10, 451, 0.04)
	if glint == 1:
		col = c("ffffff")
	elif glint == 2:
		col = c("a8bed6")
	return col


func _alpine(x: int, y: int, a: float, b: float, n: float, r: float) -> Color:
	# Alpine turf: grey-green sedge clumps on granite grit, a few bright flowers.
	var col := c("8b8a78").lerp(c("a6a28c"), smooth(0.3, 0.7, b))
	col = col.lerp(c("6e7a52"), smooth(0.45, 0.8, a) * 0.5)
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
	# Packed dirt: warm brown, lighter where feet wear the centre, cooler at the edges.
	var worn := smooth(2.0, 20.0, _nat_trail_edge(x, y))
	var col := c("8f6843").lerp(c("c69d6c"), worn)
	col = col.lerp(c("7d5a48"), smooth(0.6, 0.9, a) * 0.3)
	col = col.lerp(c("b48a5a"), smooth(0.35, 0.65, b) * 0.2)
	# Pebble clusters: lit top-left, dark below.
	var peb := _nat_pebble(x, y, 10, 361, 0.14)
	if peb == 1:
		col = c("d8caa6")
	elif peb == 2:
		col = c("a6977f")
	elif peb == 3:
		col = c("5f5349")
	return col


## Campground ground: trampled duff, pine-needle litter, grit and the odd
## root-dark patch, with the packed lighter dirt worn where feet go.
## Campground ground: trampled needle duff and twigs, with the packed dirt
## worn lighter along the centre of the paths.
func _duff(x: int, y: int, a: float, b: float, n: float, r: float) -> Color:
	var worn := smooth(2.0, 20.0, _nat_trail_edge(x, y))
	var col := c("8a6c44").lerp(c("a78856"), smooth(0.3, 0.75, b))
	col = col.lerp(c("6c5434"), smooth(0.55, 0.9, a) * 0.45)
	col = col.lerp(c("b89a68"), worn * 0.4)
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


func _flagstone(x: int, y: int, a: float, n: float, r: float) -> Color:
	var row_h := 12
	var row := y / row_h
	var off := int(hash2(row, 3, seed_value) * 30.0)
	var slab_w := 18 + int(hash2(row, 4, seed_value) * 14.0)
	var sx := (x + off) / slab_w
	var lx := (x + off) % slab_w
	var ly := y % row_h
	var tone := hash2(sx, row, seed_value + 8)
	var col := c("b7b09f").lerp(c("d0c9b6"), tone)
	col = col.lerp(c("a7a08f"), smooth(0.5, 0.9, a) * 0.3)
	if lx == 0 or ly == 0:
		col = c("867f70")
		if r < 0.25:
			col = c("5f7a44") # moss in the joints
	elif lx == 1 or ly == 1:
		col = col.lightened(0.09)
	elif lx == slab_w - 1 or ly == row_h - 1:
		col = col.darkened(0.1)
	if r < 0.05:
		col = col.darkened(0.06)
	elif r > 0.965:
		col = col.lightened(0.07)
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


func _asphalt(x: int, y: int, a: float, n: float, r: float) -> Color:
	var col := c("55514d").lerp(c("655f59"), n * 0.6 + a * 0.3)
	if r < 0.07:
		col = c("777069")
	elif r < 0.12:
		col = c("46423f")
	return col


func _sand(x: int, y: int, a: float, b: float, n: float, r: float) -> Color:
	# Pale sand: warm ridges, cooler wind-shaded hollows, scattered pebbles.
	var col := c("dccb92").lerp(c("e8dbab"), smooth(0.4, 0.8, b))
	col = col.lerp(c("bca97d"), smooth(0.55, 0.9, a) * 0.4)
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
	var base := _forest(x, y, a, b, n, r).lerp(c("4a4740"), 0.25).lerp(c("5a5752"), smooth(0.45, 0.7, a) * 0.5)
	for layer in 2:
		var cw := 17 - layer * 4
		var ch := 12 - layer * 3
		var gx := (x + layer * 9) / cw
		var gy := (y + layer * 6) / ch
		if hash2(gx, gy, 77 + layer) > 0.42:
			continue
		var bo := _boulder(x, y, cw, ch, layer * 9, layer * 6, 60 + layer * 11)
		if bo.x > 0.5:
			# Lit upper-left, cool rim on the shadow side.
			var tone := c("7a736b").lerp(c("c0b8aa"), bo.y)
			tone = tone.lerp(c("8c8d72"), smooth(0.7, 0.9, a) * 0.3)
			if bo.z > 0.5:
				tone = tone.lerp(c("4e5260"), 0.45)
			base = tone
	return base


func _rock(x: int, y: int, a: float, b: float, n: float, r: float) -> Color:
	# Granite: faceted slabs with lit upper-left faces, cool cracks, and rare lichen.
	var v := _nat_vor(x, y, 13, 381)
	var col := c("847d75").lerp(c("a79f92"), v.z * 0.75)
	col = col.lerp(c("6c6e78"), v.x * 0.3)
	col = col.lerp(c("5a5860"), smooth(0.9, 0.3, v.y) * 0.4)
	if _nat_pair(x, y, 9, 391, 0.05) != 0:
		col = col.lerp(c("a9a262"), 0.5)
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
func _shore_and_edges(im: Image) -> void:
	for y in range(2, _ph - 2):
		for x in range(2, _pw - 2):
			var i := y * _pw + x
			if not _is_water(_pk[i]):
				continue
			var edge := 0
			for o: int in [2, -2, 2 * _pw, -2 * _pw]:
				if not _is_water(_pk[i + o]):
					edge += 1
			if edge > 0:
				var f := hash2(x, y, 71)
				if f < 0.55:
					im.set_pixel(x, y, c("e6f3ee"))
				elif f < 0.8:
					im.set_pixel(x, y, c("b9dcd2"))


func _road_shoulders(im: Image) -> void:
	var edits := {}
	for y in range(2, _ph - 2):
		for x in range(2, _pw - 2):
			var i := y * _pw + x
			var k := _pk[i]
			if k == Terrain.ROAD:
				var open := false
				for o: int in [1, -1, _pw, -_pw]:
					var nk := _pk[i + o]
					if nk != Terrain.ROAD and nk != Terrain.BRIDGE and nk != Terrain.PARKING:
						open = true
				if open:
					edits[i] = c("3a3735")
				else:
					var inner := false
					for o: int in [2, -2, 2 * _pw, -2 * _pw]:
						var nk := _pk[i + o]
						if nk != Terrain.ROAD and nk != Terrain.BRIDGE and nk != Terrain.PARKING:
							inner = true
					if inner:
						edits[i] = im.get_pixel(x, y).darkened(0.12)
			elif k not in FORMAL and not _is_water(k) and k not in [Terrain.CLIFF, Terrain.GRANITE]:
				var near := 0
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
					if _pk[i + d.y * _pw + d.x] == Terrain.ROAD:
						near += 1 if absi(d.x) + absi(d.y) == 1 else 0
				if near > 0 and hash2(x, y, 88) < 0.78:
					edits[i] = im.get_pixel(x, y).lerp(c("8c7a5a"), 0.55)
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


## Grass ground shared by the meadow kinds. Mode 0 meadow, 1 wet meadow,
## 2 golden foothill grass (straw tones, no flowers).
func _nat_grass(x: int, y: int, a: float, b: float, mode: int) -> Color:
	var sun := smooth(0.42, 0.72, a)
	var shade := smooth(0.5, 0.2, a)
	var col := c("5f9a3c")
	var sun_c := c("8aa94a")
	var shade_c := c("3f7b58")
	var body := c("3b6a2e")
	var shade_body := c("2e5c44")
	var tip := c("9dc766")
	if mode == 1:
		col = c("3f7a4c")
		body = c("2f6446")
		shade_body = c("24523f")
		tip = c("86bfa0")
	elif mode == 2:
		col = c("b09a48")
		sun_c = c("cdb35c")
		shade_c = c("7f8556")
		body = c("7f7434")
		shade_body = c("6a6a3e")
		tip = c("e8d37c")
	col = col.lerp(sun_c, sun * 0.55).lerp(shade_c, shade * 0.55)
	if mode != 2:
		col = col.lerp(c("4f8c3a"), smooth(0.5, 0.8, b) * 0.25)
	# Grass tufts: darker "v" and "w" marks with a lighter tip.
	var tuft_p := 0.5
	if mode == 1:
		tuft_p = 0.3
	elif mode == 2:
		tuft_p = 0.35
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


## Pixels from (x, y) to the nearest non-trail tile edge, looking up to three
## tiles along each axis. Gives a path its lighter worn centre.
func _nat_trail_edge(x: int, y: int) -> float:
	var tx := clampi(x / T, 0, w - 1)
	var ty := clampi(y / T, 0, h - 1)
	var best := 3.0 * float(T)
	for dir: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		for k in range(1, 4):
			var nx := tx + dir.x * k
			var ny := ty + dir.y * k
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				break
			var kk := kind[ny * w + nx]
			if kk == Terrain.TRAIL or kk == Terrain.CAMP:
				continue
			var dd: float
			if dir.x < 0:
				dd = float(x - (nx + 1) * T)
			elif dir.x > 0:
				dd = float(nx * T - x)
			elif dir.y < 0:
				dd = float(y - (ny + 1) * T)
			else:
				dd = float(ny * T - y)
			best = minf(best, maxf(dd, 0.0))
			break
	return best
