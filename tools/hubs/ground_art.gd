extends RefCounted
## Paints the whole ground of a hand-made hub as one picture: grass with
## tufts and flowers, forest floor, worn dirt paths, cobblestones, asphalt,
## granite wall, talus, falls and river. The terrain grid decides what goes
## where (and still drives walking and foraging); this picture is what the
## player sees, with wobbly edges between materials, painted detail, and
## soft light and shade.
##
## Usage: var image := GroundArt.new().paint(kind_grid, width_tiles, height_tiles, paths, seed)
## [param paths] are dictionaries {"points": PackedVector2Array (in tiles),
## "width": tiles, "kind": "dirt" or "cobble"} drawn as winding paths.

const Terrain = preload("res://tools/mapgen/terrain.gd")
const T := 16
const PATH_DIRT := 40
const PATH_COBBLE := 41

var _w := 0
var _h := 0
var _wt := 0
var _ht := 0
var _kind := PackedInt32Array()
var _mat := PackedByteArray()
var _seed := 1
var _warp_x := FastNoiseLite.new()
var _warp_y := FastNoiseLite.new()
var _patch := FastNoiseLite.new()
var _fine := FastNoiseLite.new()
var _shade := FastNoiseLite.new()
var _big_x := FastNoiseLite.new()
var _big_y := FastNoiseLite.new()


static func c(hex: String) -> Color:
	return Color(hex)


func paint(kind: PackedInt32Array, width_tiles: int, height_tiles: int, paths: Array, seed_value := 1, stamps := []) -> Image:
	_wt = width_tiles
	_ht = height_tiles
	_w = _wt * T
	_h = _ht * T
	_kind = kind
	_seed = seed_value
	_setup_noise()
	_build_material_map(paths)
	var data := PackedByteArray()
	data.resize(_w * _h * 4)
	for y in _h:
		for x in _w:
			var col := _pixel(x, y)
			var i := (y * _w + x) * 4
			data[i] = int(clampf(col.r, 0.0, 1.0) * 255.0)
			data[i + 1] = int(clampf(col.g, 0.0, 1.0) * 255.0)
			data[i + 2] = int(clampf(col.b, 0.0, 1.0) * 255.0)
			data[i + 3] = 255
	var image := Image.create_from_data(_w, _h, false, Image.FORMAT_RGBA8, data)
	_decals(image)
	for stamp: Dictionary in stamps:
		if stamp.type == "firepit":
			_firepit(image, int(stamp.x), int(stamp.y))
	return image


func _setup_noise() -> void:
	_warp_x.seed = _seed
	_warp_x.frequency = 0.06
	_warp_y.seed = _seed + 11
	_warp_y.frequency = 0.06
	_patch.seed = _seed + 3
	_patch.frequency = 0.035
	_patch.fractal_octaves = 3
	_fine.seed = _seed + 5
	_fine.frequency = 0.35
	_big_x.seed = _seed + 21
	_big_x.frequency = 0.03
	_big_y.seed = _seed + 23
	_big_y.frequency = 0.03
	_shade.seed = _seed + 7
	_shade.frequency = 0.012
	_shade.fractal_octaves = 2


# ---------------------------------------------------------------- material map

func _build_material_map(paths: Array) -> void:
	# Winding paths as stamped discs first.
	var path_mask := PackedByteArray()
	path_mask.resize(_w * _h)
	for path: Dictionary in paths:
		var pts: PackedVector2Array = path.points
		var radius: float = float(path.width) * T / 2.0
		var code := PATH_COBBLE if path.get("kind", "dirt") == "cobble" else PATH_DIRT
		for i in pts.size() - 1:
			var a := pts[i] * T
			var b := pts[i + 1] * T
			var steps := int(a.distance_to(b) / 2.0) + 1
			for s in steps + 1:
				var p := a.lerp(b, float(s) / steps)
				var wob := 1.0 + 0.16 * sin(p.x * 0.09 + p.y * 0.13)
				var r := radius * wob
				for dy in range(int(-r) - 1, int(r) + 2):
					for dx in range(int(-r) - 1, int(r) + 2):
						if dx * dx + dy * dy <= r * r:
							var px_x := int(p.x) + dx
							var px_y := int(p.y) + dy
							if px_x >= 0 and px_y >= 0 and px_x < _w and px_y < _h:
								path_mask[px_y * _w + px_x] = code
	_mat.resize(_w * _h)
	for y in _h:
		for x in _w:
			var wx := x + _warp_x.get_noise_2d(x, y) * 5.0
			var wy := y + _warp_y.get_noise_2d(x, y) * 5.0
			var tx := clampi(int(wx) / T, 0, _wt - 1)
			var ty := clampi(int(wy) / T, 0, _ht - 1)
			var m := _kind[ty * _wt + tx]
			# Where one kind of grass meets another, wander much further, so
			# the lawn and the forest floor blend instead of meeting on a line.
			if _is_grass(m):
				var bx := x + _big_x.get_noise_2d(x, y) * 15.0
				var by := y + _big_y.get_noise_2d(x, y) * 15.0
				var m2 := _kind[clampi(int(by) / T, 0, _ht - 1) * _wt + clampi(int(bx) / T, 0, _wt - 1)]
				if _is_grass(m2):
					m = m2
			var pm := path_mask[y * _w + x]
			if pm != 0 and m in [Terrain.FOREST, Terrain.MEADOW, Terrain.WET_MEADOW, Terrain.TRAIL, Terrain.CAMP, Terrain.BUILT, Terrain.PAVED, Terrain.SAND]:
				m = pm
			_mat[y * _w + x] = m


func _m(x: int, y: int) -> int:
	return _mat[clampi(y, 0, _h - 1) * _w + clampi(x, 0, _w - 1)]


func _is_grass(m: int) -> bool:
	return m == Terrain.FOREST or m == Terrain.MEADOW or m == Terrain.WET_MEADOW


func _is_hard(m: int) -> bool:
	return m in [Terrain.PAVED, Terrain.BUILT, Terrain.PARKING, Terrain.ROAD, PATH_COBBLE]


func _is_water(m: int) -> bool:
	return m == Terrain.RIVER or m == Terrain.LAKE or m == Terrain.FALLS


# ---------------------------------------------------------------- pixels

func _hash(x: int, y: int, k := 0) -> float:
	var v := (x * 374761393 + y * 668265263 + (k + _seed) * 2147483647) & 0x7fffffff
	v = ((v ^ (v >> 13)) * 1274126177) & 0x7fffffff
	v = v ^ (v >> 16)
	return float(v & 0xffff) / 65535.0


func _pixel(x: int, y: int) -> Color:
	var m: int = _mat[y * _w + x]
	var col: Color
	match m:
		Terrain.MEADOW:
			col = _grass(x, y, false)
		Terrain.FOREST:
			col = _forest_floor(x, y)
		Terrain.WET_MEADOW:
			col = _wet_meadow(x, y)
		Terrain.TRAIL, Terrain.CAMP, PATH_DIRT:
			col = _dirt(x, y)
		Terrain.PAVED, PATH_COBBLE:
			col = _cobble(x, y)
		Terrain.BUILT:
			col = _flagstone(x, y)
		Terrain.PARKING:
			col = _asphalt(x, y, true)
		Terrain.ROAD:
			col = _asphalt(x, y, false)
		Terrain.CLIFF:
			col = _cliff(x, y)
		Terrain.TALUS, Terrain.SCREE:
			col = _talus(x, y)
		Terrain.FALLS:
			col = _falls(x, y)
		Terrain.RIVER, Terrain.LAKE:
			col = _water(x, y)
		Terrain.BRIDGE:
			col = _bridge(x, y)
		Terrain.SAND:
			col = _sand(x, y)
		_:
			col = _grass(x, y, false)
	col = _edges(x, y, m, col)
	# Broad light and shade across the whole ground: sun through the trees.
	var shade := _shade.get_noise_2d(x, y)
	col = col * (0.97 + shade * 0.11)
	return col


func _grass(x: int, y: int, lawn: bool) -> Color:
	var p := _patch.get_noise_2d(x, y)
	var f := _fine.get_noise_2d(x, y)
	var base := c("6fb04e").lerp(c("5f9d43"), clampf(p * 1.6 + 0.5, 0.0, 1.0))
	if p > 0.25:
		base = base.lerp(c("86c257"), clampf((p - 0.25) * 2.0, 0.0, 0.7))
	base = base * (1.0 + f * 0.05)
	# blades and specks
	var h := _hash(x, y, 1)
	if h > 0.985:
		return c("4f8a3a")
	if h > 0.965 and _hash(x, y + 1, 1) < 0.5:
		return base.lightened(0.16)
	if h < 0.012:
		return c("8ecb5c")
	# tiny vertical blades every so often
	if _hash(x / 3, y / 4, 2) > 0.93 and (x % 3) == 1 and (y % 4) < 2:
		return c("4d8a3a")
	return base


func _wet_meadow(x: int, y: int) -> Color:
	var col := _grass(x, y, false).lerp(c("467f52"), 0.45)
	var puddle := _patch.get_noise_2d(x * 1.6, y * 1.6)
	if puddle > 0.32:
		var edge := puddle > 0.36
		return c("4f8fb8") if edge else c("3f7ea8")
	# reeds
	if _hash(x / 2, y / 5, 3) > 0.9 and (x % 2) == 0 and (y % 5) < 4:
		return c("8aa85a")
	return col


func _forest_floor(x: int, y: int) -> Color:
	var p := _patch.get_noise_2d(x * 1.3, y * 1.3)
	var base := c("62883f").lerp(c("54763a"), clampf(p * 1.5 + 0.5, 0.0, 1.0))
	var h := _hash(x, y, 5)
	# pine needles and small twigs
	if h > 0.982:
		return c("8a7446")
	if h > 0.955 and _hash(x + 1, y - 1, 5) > 0.5:
		return c("6f5a36")
	if h < 0.02:
		return c("48682f")
	if h < 0.05:
		return base.lightened(0.07)
	# tufts
	if _hash(x / 3, y / 3, 6) > 0.94 and (x + y) % 3 == 0:
		return c("77a04a")
	return base


func _dirt(x: int, y: int) -> Color:
	var f := _fine.get_noise_2d(x * 0.8, y * 0.8)
	var base := c("b58f62").lerp(c("a58058"), clampf(f + 0.5, 0.0, 1.0))
	var h := _hash(x, y, 7)
	if h > 0.985:
		return c("8f7a62")          # a pebble
	if h > 0.972:
		return c("cfae84")
	if h < 0.03:
		return c("94704a")
	# wheel ruts run along the path
	if (y % 16 == 4 or y % 16 == 11) and _hash(x / 6, y, 8) > 0.4:
		return base.darkened(0.08)
	return base


func _flagstone(x: int, y: int) -> Color:
	# Big flat flags, laid in rows, each its own warm gray.
	var row_h := 14
	var row := y / row_h
	var off := (row % 2) * 12
	var flag_w := 24
	var fx := (x + off) / flag_w
	var lx := (x + off) % flag_w
	var ly := y % row_h
	var n := _hash(fx, row, 72)
	var tone := c("aca08a").lerp(c("978b78"), n)
	if _hash(fx, row, 73) > 0.9:
		tone = c("b6ab96")
	if lx == flag_w - 1 or ly == row_h - 1:
		return c("6e6456")
	if lx == 0 or ly == 0:
		return tone.lightened(0.08)
	if _hash(x, y, 74) > 0.975:
		return tone.lightened(0.12)
	if _hash(x, y, 75) < 0.03:
		return tone.darkened(0.12)
	return tone


func _cobble(x: int, y: int) -> Color:
	# Rows of rounded stones, offset, each its own tone, with dark mortar.
	var row_h := 6
	var row := y / row_h
	var off := (row % 2) * 4
	var stone_w := 8
	var sx := (x + off) / stone_w
	var lx := (x + off) % stone_w
	var ly := y % row_h
	var n := _hash(sx, row, 11)
	var tone := c("b9a98d").lerp(c("9c8f7c"), n)
	if _hash(sx, row, 12) > 0.86:
		tone = c("c4b299")
	if _hash(sx, row, 13) < 0.1:
		tone = c("a0866a")
	# stone edges: mortar and a lit upper-left
	if lx == stone_w - 1 or ly == row_h - 1:
		return c("6a5f52")
	if lx == 0 or ly == 0:
		return tone.lightened(0.12)
	if (lx == 1 and ly == 1) or (lx == stone_w - 2 and ly == row_h - 2):
		return tone.lightened(0.05) if lx == 1 else tone.darkened(0.14)
	if _hash(x, y, 14) > 0.96:
		return tone.darkened(0.12)
	return tone


func _asphalt(x: int, y: int, parking: bool) -> Color:
	var f := _fine.get_noise_2d(x * 1.2, y * 1.2)
	var base := c("585863").lerp(c("4d4d58"), clampf(f + 0.5, 0.0, 1.0))
	var h := _hash(x, y, 15)
	if h > 0.985:
		return c("7c7c86")
	if h < 0.03:
		return c("40404a")
	var tile_y := y % T
	if parking:
		if x % 48 == 0 and (y / 16) % 2 == 0 and tile_y > 2 and tile_y < 14:
			return c("d8d8d0")
	else:
		# a dashed centre line down the middle of the road
		if tile_y == 7 and (x / 10) % 2 == 0:
			return c("e0c860")
	return base


func _cliff(x: int, y: int) -> Color:
	# Granite: warm sunlit rock, long dark water-streaks, cracks and ledges,
	# darker and cooler toward the foot.
	var streak := _fine.get_noise_2d(x * 0.9, y * 0.045)
	var panel := _patch.get_noise_2d(x * 0.7, y * 0.3)
	var t := clampf(float(y) / 80.0, 0.0, 1.0)
	var base := c("c8bca4").lerp(c("9a92a0"), clampf(panel * 1.4 + 0.5, 0.0, 1.0) * 0.6)
	if streak > 0.12:
		base = base.lerp(c("4e4858"), clampf((streak - 0.12) * 2.6, 0.0, 0.85))
	# cracks: thin dark verticals
	var crack := _hash(x / 5, 0, 16)
	if crack > 0.88 and (x % 5) == int(_hash(x / 5, 1, 16) * 5.0):
		base = base.darkened(0.3)
	# ledges: a dark line with a lit lip under it
	var ledge_y := int(_hash(x / 18, y / 26, 17) * 6.0)
	if y % 26 == ledge_y:
		base = base.darkened(0.32)
	elif y % 26 == ledge_y + 1:
		base = base.lightened(0.14)
	base = base.lerp(c("6a6478"), t * 0.5)
	if _hash(x, y, 27) > 0.985:
		base = base.lightened(0.18)
	return base


func _talus(x: int, y: int) -> Color:
	# Loose boulders: each a lit block with a dark underside, on a bed of scree.
	var f := _fine.get_noise_2d(x * 0.5, y * 0.5)
	var bed := c("8e8574").lerp(c("756d5e"), clampf(f + 0.5, 0.0, 1.0))
	var cell := 9
	var cx := x / cell
	var cy := y / cell
	var best := 1.0e9
	var bpx := 0.0
	var bpy := 0.0
	var bid := 0.0
	for j in range(-1, 2):
		for i in range(-1, 2):
			var gx := cx + i
			var gy := cy + j
			var px_x := (gx + _hash(gx, gy, 60)) * cell
			var px_y := (gy + _hash(gx, gy, 61)) * cell
			var d := (x - px_x) * (x - px_x) + (y - px_y) * (y - px_y) * 1.3
			if d < best:
				best = d
				bpx = px_x
				bpy = px_y
				bid = _hash(gx, gy, 62)
	var radius := 3.4 + bid * 2.6
	if bid < 0.22 or best > radius * radius:
		return bed.darkened(0.12) if best > radius * radius * 1.5 else bed
	var stone := c("c4bba6").lerp(c("9d9583"), bid)
	var rx := x - bpx
	var ry := y - bpy
	if best > radius * radius * 0.72:
		return stone.darkened(0.42)
	if rx + ry < -radius * 0.7:
		return stone.lightened(0.2)
	if rx + ry > radius * 0.8:
		return stone.darkened(0.22)
	return stone


func _falls(x: int, y: int) -> Color:
	# White water pouring down the wall in braided strands, blue in the shade.
	var strand := sin(x * 0.85 + _hash(x / 3, 0, 20) * 5.0) * 0.5 + 0.5
	var drop := 0.5 + 0.5 * sin(y * 0.22 - float(x % 5) * 1.7 + _hash(x, 1, 20) * 4.0)
	var white := c("f6fcff").lerp(c("a9d4ee"), (1.0 - strand) * 0.6)
	var col := _cliff(x, y).lerp(white, 0.86)
	col = col.lerp(c("8cbce0"), (1.0 - drop) * 0.25)
	if _hash(x, y / 2, 21) > 0.94:
		col = c("ffffff")
	return col


func _water(x: int, y: int) -> Color:
	var wave := sin(x * 0.22 + y * 0.6 + _patch.get_noise_2d(x * 2.0, y * 2.0) * 3.0)
	var wave2 := sin(x * 0.1 - y * 0.4)
	var base := c("4a95d0").lerp(c("3a7fbc"), clampf(wave * 0.5 + 0.5, 0.0, 1.0))
	base = base.lerp(c("5aa8de"), clampf(wave2 * 0.3, 0.0, 0.3))
	if wave > 0.94:
		return c("bfe8f8")
	if _hash(x / 2, y, 22) > 0.965:
		return c("8cc8ec")
	if wave < -0.9:
		return c("2f6aa8")
	return base


func _bridge(x: int, y: int) -> Color:
	var plank := (y / 4) % 2
	var base := c("a67a4c") if plank == 0 else c("94693f")
	if y % 4 == 0:
		base = c("7a5232")
	if _hash(x / 5, y / 4, 23) > 0.8:
		base = base.lightened(0.06)
	if x % 16 == 0 or x % 16 == 15:
		base = c("6a4a2e")
	return base


func _sand(x: int, y: int) -> Color:
	var f := _fine.get_noise_2d(x * 0.6, y * 0.6)
	var base := c("ecd9a4").lerp(c("dcc78a"), clampf(f + 0.5, 0.0, 1.0))
	if (x + y * 2) % 9 == 0 and _hash(x, y, 24) > 0.5:
		return base.darkened(0.08)
	if _hash(x, y, 25) > 0.985:
		return c("b09a62")
	return base


## Edges between materials: a dark rim on grass where it meets a path or
## paving, a light rim on the path, a bank on the river, shadow under the wall.
func _edges(x: int, y: int, m: int, col: Color) -> Color:
	var up := _m(x, y - 2)
	var down := _m(x, y + 2)
	var left := _m(x - 2, y)
	var right := _m(x + 2, y)
	var here_grass := _is_grass(m)
	var here_soft := m == Terrain.TRAIL or m == Terrain.CAMP or m == PATH_DIRT
	var neighbors := [up, down, left, right]
	if here_grass:
		for n: int in neighbors:
			if n == Terrain.TRAIL or n == Terrain.CAMP or n == PATH_DIRT:
				return col.darkened(0.22)
			if _is_hard(n) or n == Terrain.BRIDGE:
				return col.darkened(0.3)
			if n == Terrain.SAND:
				return col.darkened(0.06)
			if n == Terrain.RIVER or n == Terrain.LAKE:
				return c("8a7a46") if _hash(x, y, 26) > 0.4 else col.darkened(0.3)
	elif here_soft:
		for n: int in neighbors:
			if _is_grass(n):
				return col.lightened(0.1)
	elif _is_hard(m):
		for n: int in neighbors:
			if _is_grass(n) or n == Terrain.TRAIL or n == PATH_DIRT:
				return col.darkened(0.28)
	elif m == Terrain.RIVER or m == Terrain.LAKE:
		for n: int in neighbors:
			if n != Terrain.RIVER and n != Terrain.LAKE and n != Terrain.BRIDGE:
				return col.lerp(c("d8f0f8"), 0.55)
	elif m == Terrain.CLIFF:
		if down != Terrain.CLIFF and down != Terrain.FALLS:
			return col.darkened(0.34)
		if up != Terrain.CLIFF and up != Terrain.FALLS:
			return col.lightened(0.08)
	elif m == Terrain.TALUS:
		if up == Terrain.CLIFF:
			return col.darkened(0.3)
	return col


# ---------------------------------------------------------------- decals

## Small things painted on top: flowers, clover and pebbles.
func _decals(image: Image) -> void:
	for ty in _ht:
		for tx in _wt:
			var m: int = _kind[ty * _wt + tx]
			if m == Terrain.MEADOW or m == Terrain.WET_MEADOW:
				for i in 3:
					var rx := tx * T + int(_hash(tx, ty, 30 + i) * 14.0) + 1
					var ry := ty * T + int(_hash(tx, ty, 34 + i) * 13.0) + 2
					if _mat[ry * _w + rx] != Terrain.MEADOW and _mat[ry * _w + rx] != Terrain.WET_MEADOW:
						continue
					if _hash(tx, ty, 38 + i) > 0.32:
						continue
					_flower(image, rx, ry, int(_hash(tx, ty, 42 + i) * 5.0))
			elif m == Terrain.FOREST and _hash(tx, ty, 50) > 0.85:
				var rx2 := tx * T + int(_hash(tx, ty, 51) * 13.0) + 1
				var ry2 := ty * T + int(_hash(tx, ty, 52) * 13.0) + 1
				if _mat[ry2 * _w + rx2] == Terrain.FOREST:
					_fern(image, rx2, ry2)
			elif (m == Terrain.TRAIL or m == Terrain.CAMP) and _hash(tx, ty, 53) > 0.7:
				var rx3 := tx * T + int(_hash(tx, ty, 54) * 12.0) + 2
				var ry3 := ty * T + int(_hash(tx, ty, 55) * 12.0) + 2
				image.set_pixel(rx3, ry3, c("8a7458"))
				image.set_pixel(rx3 + 1, ry3, c("a89078"))


## A ring of stones around scorched earth, with log seats set around it.
func _firepit(image: Image, cx: int, cy: int) -> void:
	for y in range(-16, 17):
		for x in range(-24, 25):
			var d := sqrt(float(x * x) / 1.0 + float(y * y) * 1.6)
			var px_x := cx + x
			var py := cy + y
			if px_x < 0 or py < 0 or px_x >= _w or py >= _h:
				continue
			if d < 7.0:
				image.set_pixel(px_x, py, c("3a322c").lerp(c("564a3e"), _hash(px_x, py, 70) * 0.7))
			elif d < 11.0:
				var stone := c("a8a08e").lerp(c("7c7566"), _hash(px_x / 3, py / 3, 71))
				var ang := int((atan2(float(y), float(x)) + PI) * 4.0)
				if (int(d) + ang) % 3 == 0:
					stone = stone.darkened(0.3)
				elif d < 9.0 and (px_x + py) % 5 == 0:
					stone = stone.lightened(0.14)
				image.set_pixel(px_x, py, stone)
	# Log seats around the ring: rounded, lit from the upper left, with pale end rings.
	for seat in [[Vector2(-22, -2), Vector2(-9, 3)], [Vector2(9, -2), Vector2(22, 3)], [Vector2(-7, 12), Vector2(7, 17)], [Vector2(-7, -19), Vector2(7, -14)]]:
		var a_pos: Vector2 = seat[0]
		var b_pos: Vector2 = seat[1]
		for y in range(int(a_pos.y), int(b_pos.y) + 1):
			for x in range(int(a_pos.x), int(b_pos.x) + 1):
				var lx: int = cx + x
				var ly: int = cy + y
				if lx < 0 or ly < 0 or lx >= _w or ly >= _h:
					continue
				var t := float(y - int(a_pos.y)) / maxf(1.0, b_pos.y - a_pos.y)
				var log_col := c("b0824c")
				if t < 0.25:
					log_col = c("d0a06a")
				elif t > 0.7:
					log_col = c("6e4a2e")
				elif (x + y) % 4 == 0:
					log_col = c("a0764a")
				var edge := x == int(a_pos.x) or x == int(b_pos.x)
				if edge:
					log_col = c("e0c090") if x == int(a_pos.x) else c("5a3a22")
				image.set_pixel(lx, ly, log_col)
		# a dark rim under each log
		for x in range(int(a_pos.x), int(b_pos.x) + 1):
			var ry := cy + int(b_pos.y) + 1
			var rx := cx + x
			if rx >= 0 and ry >= 0 and rx < _w and ry < _h:
				image.set_pixel(rx, ry, Color(0.1, 0.07, 0.04, 0.8))


func _flower(image: Image, x: int, y: int, kind: int) -> void:
	var cols := [c("fff6d8"), c("ffd84a"), c("c9a0f0"), c("ff9cb8"), c("ffffff")]
	var col: Color = cols[kind % cols.size()]
	image.set_pixel(x, y + 1, c("4f8a3a"))
	image.set_pixel(x, y, col)
	if kind == 0 or kind == 3:
		image.set_pixel(x - 1, y, col.darkened(0.08))
		image.set_pixel(x + 1, y, col.darkened(0.08))
		image.set_pixel(x, y - 1, col.darkened(0.08))
		image.set_pixel(x, y, c("ffd84a"))


func _fern(image: Image, x: int, y: int) -> void:
	var g := c("4a7a3a")
	var l := c("6a9a4a")
	image.set_pixel(x, y, g)
	image.set_pixel(x - 1, y - 1, l)
	image.set_pixel(x + 1, y - 1, l)
	image.set_pixel(x, y - 1, g)
	image.set_pixel(x - 2, y, g)
	image.set_pixel(x + 2, y, g)
