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
			var o := i * 4
			out[o] = int(clampf(col.r, 0, 1) * 255.0)
			out[o + 1] = int(clampf(col.g, 0, 1) * 255.0)
			out[o + 2] = int(clampf(col.b, 0, 1) * 255.0)
			out[o + 3] = 255
	var im := Image.create_from_data(_pw, _ph, false, Image.FORMAT_RGBA8, out)
	_shore_and_edges(im)
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
		Terrain.FOREST, Terrain.FIR, Terrain.SUBALPINE:
			return _forest(x, y, a, b, n, r)
		Terrain.MEADOW, Terrain.FOOTHILL:
			return _meadow(x, y, i, a, b, n, r, false)
		Terrain.WET_MEADOW:
			return _meadow(x, y, i, a, b, n, r, true)
		Terrain.LAWN:
			return _lawn(x, y, a, b, n, r)
		Terrain.TRAIL, Terrain.CAMP:
			return _trail(x, y, a, b, n, r)
		Terrain.PAVED, Terrain.BUILT:
			return _flagstone(x, y, a, n, r)
		Terrain.PARKING:
			return _gravel(x, y, a, b, n, r)
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
	elif wet and r < 0.03:
		col = c("9fc7c0")
	return col


func _lawn(x: int, y: int, a: float, b: float, n: float, r: float) -> Color:
	var stripe := (x / 20 + y / 320) % 2 == 0
	var col := c("4c9445").lerp(c("5aa54c"), b)
	if stripe:
		col = col.lightened(0.055)
	else:
		col = col.darkened(0.03)
	col = col.lerp(c("6cb45a"), smooth(0.62, 0.9, a) * 0.22)
	if r < 0.05:
		col = col.lightened(0.09)
	elif r < 0.09:
		col = col.darkened(0.08)
	elif r > 0.9997:
		col = c("f0ecd8") # daisy
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


func _asphalt(x: int, y: int, a: float, n: float, r: float) -> Color:
	var col := c("55514d").lerp(c("655f59"), n * 0.6 + a * 0.3)
	if r < 0.07:
		col = c("777069")
	elif r < 0.12:
		col = c("46423f")
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
