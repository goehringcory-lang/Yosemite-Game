extends RefCounted
## Landscape art for the Ahwahnee grounds and the trail to them: the granite
## wall of Royal Arches and Washington Column with the Royal Arch Cascade, and
## the granite Stoneman Bridge over the Merced. Drawn in code (height-field
## lighting, ordered dithering, hand-placed trees) into assets/sprites/ahwahnee/.
## Replace any PNG with hand-drawn art of the same size at any time.
##
## ## Contract
## All files are written to res://assets/sprites/ahwahnee/ by save_all().
##
## royal_arches_wall.png  1536 x 224 (WALL_SIZE). The valley wall seen from the
##   front, light from the upper left. Draw it with its top edge at the top of
##   the map (y = 0); the top ~14 px is a forest rim. The bottom ~40 px is an
##   irregular skirt of talus, boulders, conifers and ferns with transparent
##   gaps, so paint forest ground underneath.
## cascade_0.png .. cascade_5.png  64 x 202 (CASCADE_SIZE), CASCADE_FRAMES = 6,
##   loop at ~8 fps. Transparent background. Draw each frame at CASCADE_POS
##   (top-left, in wall pixels) on top of the wall. The ribbon of water is
##   centered on chan_x(y), a gully painted into the wall.
## mist_0.png .. mist_3.png  64 x 32, MIST_FRAMES = 4, loop at ~5 fps. Soft
##   spray for the plunge pool. Center each frame's bottom middle (32, 28) on
##   POOL_POS (wall pixels) = where the water lands.
##   The wall itself already has a small painted pool at POOL_POS; the builder
##   puts a stream heading south from there.
## stoneman_bridge_back.png   320 x 144 (BRIDGE_SIZE). The whole bridge.
##   Ground layer: drawn under the player. Runs east-west; the river flows
##   north-south under it. The top 32 px are headroom for the lamp posts.
## stoneman_bridge_front.png  320 x 88. Only the rows from BRIDGE_FRONT_Y down,
##   full width. Draw it at the same left edge and BRIDGE_FRONT_Y lower than the
##   back image's top, y-sorted at the south parapet so it overlaps the player's
##   feet. (The pixels are identical to the back image's rows.)
## Bridge constants:
##   BRIDGE_DECK    Rect2i(0, 32, 320, 32): the walkable lane including both
##                  parapets (north parapet rows 32..40, road 40..56, south
##                  parapet rows 56..64).
##   PARAPET_H      8: the builder blocks the top and bottom 8 px of the deck.
##   BRIDGE_RIVER_X (64, 256): x range of open water. Paint river tiles across
##                  it, north and south of the bridge. Land (trail) is outside.
##   BRIDGE_FRONT_Y 56.
##   The deck spans the full sprite width; the road continues on land at both
##   ends. The river fades into the sprite's bottom edge (rows 136..144).

const K = preload("res://tools/hubs/pixel_kit.gd")
const DIR := "res://assets/sprites/ahwahnee/"

const WALL_SIZE := Vector2i(1536, 224)
const CASCADE_POS := Vector2i(150, 6)
const CASCADE_SIZE := Vector2i(64, 202)
const CASCADE_FRAMES := 6
const POOL_POS := Vector2i(182, 208)
const MIST_FRAMES := 4

const BRIDGE_SIZE := Vector2i(320, 144)
const BRIDGE_DECK := Rect2i(0, 32, 320, 32)
const PARAPET_H := 8
const BRIDGE_RIVER_X := Vector2i(64, 256)
const BRIDGE_FRONT_Y := 56

## Granite, dark to light: cool violet shade to warm cream sunlight.
const GRANITE := ["262a3c", "363a4e", "4b4d5f", "62626e", "7b7a80", "948e88", "ada496", "c4b9a2", "d9cdb2", "ece2c6"]
const STONE := ["3a3a48", "54545f", "6e6c72", "88847f", "a49d91", "bcb3a2", "d0c6b0", "e2d8c0", "f0e8d0"]
const GREENS := ["17291f", "1f3b2b", "2b5236", "3a6a3f", "4d8047", "6e9a55", "93b567"]
const WATER := ["27525f", "2f6a78", "3a808a", "4f9aa0", "78bcb8", "a4d8d2", "bfe6e0", "e4f6f2"]
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

## Arch recesses on the wall: center x, top y, half width, half height, base y, depth.
const ARCHES := [
	[330, 84, 72, 64, 262, 22.0],
	[505, 34, 86, 80, 250, 26.0],
	[700, 74, 112, 96, 272, 32.0],
	[885, 22, 96, 88, 214, 28.0],
	[1042, 70, 82, 74, 252, 26.0],
	[1112, -18, 78, 82, 126, 22.0],
	[610, -34, 70, 72, 104, 18.0],
	[792, -50, 70, 80, 44, 16.0],
]


func save_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var sheets := {"royal_arches_wall": wall()}
	for i in CASCADE_FRAMES:
		sheets["cascade_%d" % i] = cascade_frame(i)
	for i in MIST_FRAMES:
		sheets["mist_%d" % i] = mist_frame(i)
	var bridge := bridge_image()
	sheets["stoneman_bridge_back"] = bridge
	sheets["stoneman_bridge_front"] = bridge.get_region(Rect2i(0, BRIDGE_FRONT_Y, BRIDGE_SIZE.x, BRIDGE_SIZE.y - BRIDGE_FRONT_Y))
	for sprite_name: String in sheets:
		(sheets[sprite_name] as Image).save_png(ProjectSettings.globalize_path(DIR + sprite_name + ".png"))


# ---------------------------------------------------------------- helpers

static func _noise(seed_value: int, octaves := 1) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 1.0
	if octaves > 1:
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
		n.fractal_octaves = octaves
		n.fractal_gain = 0.5
	else:
		n.fractal_type = FastNoiseLite.FRACTAL_NONE
	return n


static func _cols(hexes: Array) -> Array[Color]:
	var out: Array[Color] = []
	for h: String in hexes:
		out.append(Color(h))
	return out


static func _bayer(x: int, y: int) -> float:
	return (float(BAYER[(y & 3) * 4 + (x & 3)]) + 0.5) / 16.0


## Picks from a dark-to-light ramp for a value 0..1, with ordered dithering
## between neighbouring tones. [param band] narrows the dithered zone.
static func _ramp(ramp: Array[Color], s: float, x: int, y: int, band := 0.5) -> Color:
	var t := clampf(s, 0.0, 1.0) * (ramp.size() - 1)
	var i := int(floor(t))
	if i >= ramp.size() - 1:
		return ramp[ramp.size() - 1]
	var f := t - i
	f = smoothstep(0.5 - band * 0.5, 0.5 + band * 0.5, f)
	return ramp[i + 1] if f > _bayer(x, y) else ramp[i]


static func chan_x(y: float) -> float:
	return 182.0 + 9.0 * sin(y * 0.031 + 0.6) + 4.0 * sin(y * 0.087 + 2.0)


static func _sat(v: float) -> float:
	return clampf(v, 0.0, 1.0)


## A shaded blob lit from the upper left: boulders, shrubs, tree crowns.
static func _blob(im: Image, cx: float, cy: float, rx: float, ry: float, ramp: Array[Color], seed_value: int, grain := 0.3, flat := 0.0) -> void:
	for y in range(floori(cy - ry) - 1, ceili(cy + ry) + 2):
		for x in range(floori(cx - rx) - 1, ceili(cx + rx) + 2):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			var wob := (K.hash2(x, y, seed_value) - 0.5) * 0.14
			var d2 := dx * dx + dy * dy + wob
			if d2 > 1.0:
				continue
			var nz := sqrt(maxf(0.0, 1.0 - dx * dx - dy * dy))
			var light := 0.5 + (-dx * 0.55 - dy * 0.65) * (1.0 - flat) * 0.6 + nz * 0.15
			light += (K.hash2(x * 3 + 1, y * 3 + 2, seed_value + 5) - 0.5) * grain
			if d2 > 0.82:
				light -= 0.18
			K.px(im, x, y, _ramp(ramp, light, x, y, 0.7))


static func _boulder(im: Image, cx: float, cy: float, rx: float, ry: float, seed_value: int) -> void:
	var ramp := _cols(GRANITE)
	var warm := K.hash2(seed_value, 1, 1) * 0.16
	K.ellipse(im, cx + rx * 0.2, cy + ry * 0.8, rx * 1.1, ry * 0.42, Color(0.04, 0.05, 0.06, 0.42))
	for y in range(floori(cy - ry) - 1, ceili(cy + ry) + 2):
		for x in range(floori(cx - rx) - 1, ceili(cx + rx) + 2):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			# a lumpy, slightly angular outline
			var ang := atan2(dy, dx)
			var lump := 1.0 + sin(ang * 3.0 + seed_value) * 0.08 + sin(ang * 5.0 + seed_value * 2.0) * 0.05
			var d2 := (dx * dx + dy * dy) / (lump * lump)
			if d2 > 1.0:
				continue
			var light := 0.55 + (-dx * 0.5 - dy * 0.75) * 0.5 - d2 * 0.12 + warm
			light += (K.hash2(x, y, seed_value + 5) - 0.5) * 0.22
			# a facet break: top plane bright, right side dark
			if dy < -0.35 and dx < 0.4:
				light += 0.12
			if dx > 0.45:
				light -= 0.16
			if d2 > 0.86:
				light -= 0.16
			light = floorf(light * 5.0) / 5.0 + 0.05
			K.px(im, x, y, _ramp(ramp, light, x, y, 0.4))
	if rx > 6.0:
		var a2 := K.hash2(seed_value, 3, 3) * 2.0 - 1.0
		for i in int(rx * 0.7):
			K.px(im, int(cx - rx * 0.2 + i), int(cy - ry * 0.1 + i * a2 * 0.6), Color("3a3c4c"))
	for i in int(rx * 1.2):
		var mx := cx + (K.hash2(i, seed_value, 7) - 0.5) * rx * 1.3
		var my := cy - ry * (0.4 + K.hash2(i, seed_value, 8) * 0.4)
		if K.hash2(i, seed_value, 9) < 0.5:
			K.px(im, int(mx), int(my), Color("5c7a48") if K.hash2(i, seed_value, 1) < 0.6 else Color("7c9a58"))


static func _conifer(im: Image, cx: int, base_y: int, h: int, hw: float, seed_value: int, cedar := false) -> void:
	var ramp := _cols(GREENS)
	var trunk_h := maxi(3, h / 6)
	var trunk := Color("5a3a28")
	for ty in trunk_h + 2:
		K.px(im, cx, base_y - ty, trunk)
		if hw > 4.5:
			K.px(im, cx + 1, base_y - ty, trunk.darkened(0.3))
	var crown_top := base_y - h
	var crown_bot := base_y - trunk_h + 2
	var rows := crown_bot - crown_top
	for r in rows:
		var t := float(r) / maxf(rows, 1.0)
		var tier := float(r % 6) / 6.0
		var w := hw * pow(t, 0.8 if not cedar else 0.55) * (0.72 + 0.28 * (1.0 - tier))
		w += (K.hash2(r, seed_value, 5) - 0.5) * 1.8
		w = maxf(w, 0.6)
		var y := crown_top + r
		for x in range(int(round(cx - w)), int(round(cx + w)) + 1):
			var lx := (x - cx) / maxf(w, 1.0)
			var light := 0.58 - lx * 0.36 - tier * 0.3 - t * 0.08 + (K.hash2(x, y, seed_value) - 0.5) * 0.4
			if absf(lx) > 0.86:
				light -= 0.12
			K.px(im, x, y, _ramp(ramp, light, x, y, 0.45))


static func _shrub(im: Image, cx: float, base_y: float, size: float, seed_value: int, manzanita := false) -> void:
	var ramp := _cols(GREENS)
	if manzanita:
		ramp = _cols(["2a3a2a", "3e5a3a", "587a48", "7c9a58", "a8b878"])
		for i in 4:
			var bx := cx + (i - 1.5) * size * 0.35
			K.vline(im, int(bx), int(base_y - size * 0.6), int(size * 0.6), Color("7a3a2a"))
	_blob(im, cx, base_y - size * 0.45, size * 0.9, size * 0.6, ramp, seed_value, 0.5)
	if manzanita:
		for i in 3:
			K.px(im, int(cx - size * 0.5 + K.hash2(i, seed_value, 2) * size), int(base_y - size * 0.7 - K.hash2(i, seed_value, 4) * size * 0.3), Color("d8a0a0"))


static func _fern(im: Image, cx: int, base_y: int, size: int, seed_value: int) -> void:
	var ramp := _cols(GREENS)
	for f in 5:
		var a := (f - 2) * 0.55 + (K.hash2(f, seed_value, 1) - 0.5) * 0.3
		for i in size:
			var t := float(i) / size
			var x := cx + int(sin(a) * i * 0.9)
			var y := base_y - int(cos(a * 0.6) * i * 0.7) + int(t * t * size * 0.6)
			K.px(im, x, y, _ramp(ramp, 0.45 + t * 0.4 - absf(a) * 0.05, x, y, 0.4))


# ---------------------------------------------------------------- the wall

func wall() -> Image:
	var W := WALL_SIZE.x
	var Hh := WALL_SIZE.y
	var n_base := _noise(11, 2)
	var n_fine := _noise(12)
	var n_join := _noise(13, 3)
	var n_streak := _noise(14, 2)
	var n_wet := _noise(15, 2)
	var n_lichen := _noise(16, 3)
	var n_crack := _noise(17, 3)
	var n_warp := _noise(18, 2)
	var n_shade := _noise(19, 2)
	var n_prof := _noise(20, 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242

	var prof := PackedInt32Array()
	prof.resize(W)
	for x in W:
		prof[x] = 184 + int(n_prof.get_noise_1d(x * 0.02) * 12.0 + sin(x * 0.05) * 3.0)

	# ---- height field
	var hgt := PackedFloat32Array()
	hgt.resize(W * Hh)
	var wetv := PackedFloat32Array()
	wetv.resize(W * Hh)
	var shade_add := PackedFloat32Array()
	shade_add.resize(W * Hh)
	for y in Hh:
		for x in W:
			var wx := x + n_warp.get_noise_2d(x * 0.008, y * 0.008) * 7.0
			var wy := y + n_warp.get_noise_2d(x * 0.008 + 50.0, y * 0.008 + 50.0) * 7.0
			var h := n_base.get_noise_2d(wx * 0.007, wy * 0.011) * 6.0
			h += n_join.get_noise_2d(wx * 0.035, wy * 0.004) * 1.1
			h += n_fine.get_noise_2d(x * 0.35, y * 0.35) * 0.3
			for a: Array in ARCHES:
				var rx: float = a[2]
				var cxa: float = a[0]
				if absf(wx - cxa) > rx * 2.5:
					continue
				var ry: float = a[3]
				var cy: float = float(a[1]) + ry
				var dx := (wx - cxa) / rx
				var u := 0.0
				if wy >= cy:
					u = absf(dx)
				else:
					var dy := (wy - cy) / ry
					u = sqrt(dx * dx + dy * dy)
				u += n_fine.get_noise_2d(wx * 0.03, wy * 0.03 + 9.0) * 0.03
				var inside := 1.0 - smoothstep(0.9, 1.0, u)
				var floor_fade := 1.0 - smoothstep(float(a[4]) - 8.0, float(a[4]) + 2.0, wy)
				var depth: float = a[5]
				h -= depth * inside * floor_fade * (0.62 + 0.38 * (1.0 - minf(u, 1.0) * minf(u, 1.0)))
				if u > 0.95 and u < 2.5:
					var s := (u - 0.95) * 3.6
					var saw := smoothstep(0.55, 0.96, s - floorf(s))
					h += 4.2 * saw * (1.0 - smoothstep(1.5, 2.5, u))
			# Washington Column, a smooth rounded buttress on the right
			if wx > 1230.0:
				var p := maxf(0.0, 1.0 - pow((wx - 1425.0) / 195.0, 2.0))
				h += 52.0 * p - 9.0 * exp(-pow((wx - 1236.0) / 7.0, 2.0))
				h += n_join.get_noise_2d(wx * 0.11, wy * 0.004) * 1.2 * p
			# The Royal Arch Cascade's gully
			var dc := absf(x - chan_x(y))
			h -= 13.0 * (1.0 - smoothstep(5.0, 17.0, dc))
			wetv[y * W + x] = exp(-pow(dc / 30.0, 2.0))
			hgt[y * W + x] = h

	# ---- ledges: a lit lip, a dark underside, and a cast shadow
	var ledges: Array = []
	for i in 26:
		ledges.append([rng.randi_range(20, W - 140), rng.randi_range(22, 80), rng.randi_range(26, 168)])
	var lip := [0.6, 1.8, 2.4, 2.6, 0.8, 0.0]
	for l: Array in ledges:
		var lx: int = l[0]
		var ll: int = l[1]
		var ly: int = l[2]
		for x in range(lx, mini(lx + ll, W)):
			var t := float(x - lx) / ll
			var taper := pow(sin(t * PI), 0.5)
			var jit := int(n_fine.get_noise_2d(x * 0.05 + ly, ly * 0.3) * 4.5)
			for dy in range(-3, 3):
				var y := ly + dy + jit
				if y >= 0 and y < Hh:
					hgt[y * W + x] += taper * lip[dy + 3]
			for dy in range(2, 10):
				var y2 := ly + dy + jit
				if y2 >= 0 and y2 < Hh:
					shade_add[y2 * W + x] -= 0.09 * taper * (1.0 - float(dy - 2) / 8.0)

	# ---- lighting
	var im := Image.create_empty(W, Hh, false, Image.FORMAT_RGBA8)
	var ramp := _cols(GRANITE)
	var orange := _cols(["6a4a2a", "8f6a34", "b98a44", "d8ad5c", "e8c878"])
	var gray_green := _cols(["5a6456", "7a8672", "9aa48c", "b6bda4"])
	var blue_black := Color("242838")
	var lx_l := -0.62
	var ly_l := -0.55
	var lz_l := 0.56
	for y in Hh:
		for x in W:
			var i := y * W + x
			var xm := maxi(x - 1, 0)
			var xp := mini(x + 1, W - 1)
			var ym := maxi(y - 1, 0)
			var yp := mini(y + 1, Hh - 1)
			var hx := (hgt[y * W + xp] - hgt[y * W + xm]) * 0.5
			var hy := (hgt[yp * W + x] - hgt[ym * W + x]) * 0.5
			var inv := 1.0 / sqrt(hx * hx + hy * hy + 1.0)
			var d := (-hx * lx_l - hy * ly_l + lz_l) * inv
			var s := 0.26 + 0.78 * _sat(d)
			# cavities are darker (ambient occlusion)
			var x4a := maxi(x - 5, 0)
			var x4b := mini(x + 5, W - 1)
			var y4a := maxi(y - 5, 0)
			var y4b := mini(y + 5, Hh - 1)
			var cav := (hgt[y * W + x4a] + hgt[y * W + x4b] + hgt[y4a * W + x] + hgt[y4b * W + x]) * 0.25 - hgt[i]
			s -= _sat(cav * 0.03) * 0.4
			s += shade_add[i]
			# grain comes in small clusters, not per-pixel static
			s += (K.hash2(x / 3, y / 3, 31) - 0.5) * 0.05
			# big sun and shade patches, and a darker foot
			var sh := n_shade.get_noise_2d(x * 0.0045, y * 0.006)
			s -= maxf(0.0, sh - 0.02) * 0.65
			s *= 0.9 + 0.1 * (1.0 - float(y) / Hh)
			s -= 0.2 * (1.0 - smoothstep(4.0, 38.0, y))
			s -= 0.32 * smoothstep(float(prof[x]) - 34.0, float(prof[x]) + 4.0, y)
			# water stains: black streaks, heavier in the gully
			var wx := x + n_warp.get_noise_2d(x * 0.02, y * 0.02) * 8.0
			var streak := n_streak.get_noise_2d(wx * 0.16, y * 0.0045)
			var wetmask := 0.25 + 0.75 * smoothstep(-0.25, 0.45, n_wet.get_noise_2d(x * 0.007, y * 0.009))
			var stain := smoothstep(0.34, 0.5, streak) * wetmask
			stain = maxf(stain, wetv[i] * 0.85)
			s -= stain * 0.27
			# cracks and sheeting joints
			var cv := absf(n_crack.get_noise_2d(wx * 0.02, y * 0.005))
			var ch := absf(n_crack.get_noise_2d(x * 0.004 + 30.0, y * 0.022))
			if cv < 0.0045 or ch < 0.0016:
				s -= 0.22
			var col := _ramp(ramp, s, x, y, 0.3)
			# hue shift: lit faces warm toward cream, shade cools toward blue-violet
			if s > 0.7 and stain < 0.2:
				col = col.lerp(Color("eadfc4"), minf(0.35, (s - 0.7) * 0.9))
			elif s < 0.38:
				col = col.lerp(Color("2a2f4c"), minf(0.4, (0.38 - s) * 0.9))
			if stain > 0.25:
				col = col.lerp(blue_black, minf(0.45, (stain - 0.25) * 0.8))
			# lichen on the lit faces, in clumps
			var lich := n_lichen.get_noise_2d(x * 0.05, y * 0.05)
			if lich > 0.4 and s > 0.5 and stain < 0.3 and d > 0.5:
				col = _ramp(orange, s * 0.85 + (K.hash2(x / 2, y / 2, 5) - 0.5) * 0.3, x, y, 0.3) if lich > 0.5 else col.lerp(Color("c9a05a"), 0.3)
			elif lich < -0.42 and s > 0.4 and stain < 0.3:
				col = _ramp(gray_green, s + (K.hash2(x / 2, y / 2, 6) - 0.5) * 0.3, x, y, 0.3)
			im.set_pixel(x, y, col)

	# ---- dressing: vegetation on the ledges, the rim, the skirt, the pool
	for l: Array in ledges:
		var lx: int = l[0]
		var ll: int = l[1]
		var ly: int = l[2]
		if ly < 22:
			continue
		var count := ll / 26
		for k in count:
			var vx := lx + int((k + 0.5 + (rng.randf() - 0.5) * 0.6) / count * ll)
			if absf(vx - chan_x(ly)) < 16.0:
				continue
			var base_y := ly - 1
			var roll := rng.randf()
			var sd := rng.randi()
			if roll < 0.4:
				_conifer(im, vx, base_y, rng.randi_range(9, 17), rng.randf_range(3.0, 4.6), sd)
			elif roll < 0.6:
				_conifer(im, vx, base_y, rng.randi_range(12, 19), rng.randf_range(2.0, 2.8), sd, true)
			elif roll < 0.85:
				_shrub(im, vx, base_y, rng.randf_range(3.0, 5.0), sd, rng.randf() < 0.5)
			else:
				_fern(im, vx, base_y, rng.randi_range(4, 6), sd)

	# the forest rim on the plateau, with a notch where the creek spills
	var rim := PackedInt32Array()
	rim.resize(W)
	for x in W:
		rim[x] = 6 + int((n_prof.get_noise_1d(x * 0.05 + 200.0) + 1.0) * 5.0)
		for y in rim[x]:
			var t := K.hash2(x, y, 44)
			var col := _ramp(_cols(GREENS), 0.15 + t * 0.25 + (1.0 - float(y) / rim[x]) * 0.0, x, y, 0.5)
			if absf(x - chan_x(6.0)) > 5.0:
				im.set_pixel(x, y, col)
	var x_t := 0
	while x_t < W:
		var hh := rng.randi_range(22, 40)
		var hw := rng.randf_range(4.0, 7.0)
		if absf(x_t - chan_x(6.0)) > 16.0:
			_conifer(im, x_t, rim[clampi(x_t, 0, W - 1)] + rng.randi_range(0, 4), hh, hw, rng.randi(), rng.randf() < 0.3)
		x_t += rng.randi_range(5, 11)
	# creek lip and the dark notch it flows over
	for y in range(0, 10):
		for x in range(int(chan_x(6.0)) - 6, int(chan_x(6.0)) + 7):
			var t := 1.0 - absf(x - chan_x(6.0)) / 7.0
			if y < 4:
				K.px(im, x, y, Color("2b2f40"))
			elif K.hash2(x, y, 3) < t:
				K.px(im, x, y, Color("34394e"))

	_skirt(im, prof, rng, n_prof)
	_pool(im, rng)
	return im


func _skirt(im: Image, prof: PackedInt32Array, rng: RandomNumberGenerator, n_prof: FastNoiseLite) -> void:
	var W := WALL_SIZE.x
	var Hh := WALL_SIZE.y
	var gravel := _cols(["3a3a40", "56524e", "746d64", "8f867a", "aca08e", "c6b9a2"])
	# cut the rock at the profile, then scatter talus that thins toward the bottom
	for x in W:
		for y in range(prof[x], Hh):
			im.set_pixel(x, y, Color(0, 0, 0, 0))
		for y in range(maxi(prof[x] - 4, 0), Hh):
			var below := float(y - prof[x])
			var dens := 1.0 - smoothstep(-2.0, 38.0, below) * 0.93
			var cell := K.hash2(x / 2, y / 2, 91) * 0.7 + K.hash2(x, y, 92) * 0.3
			if cell < dens:
				var light := 0.5 + (K.hash2(x, y, 93) - 0.5) * 0.9 - (below / 90.0)
				im.set_pixel(x, y, _ramp(gravel, light, x, y, 0.5))
	# boulders, far to near
	var boulders: Array = []
	for i in 150:
		var bx := rng.randi_range(0, W - 1)
		boulders.append([bx, prof[bx] + rng.randi_range(-2, 34), 3.0 + pow(rng.randf(), 2.4) * 11.0])
	boulders.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1])
	var trees: Array = []
	for i in 46:
		var tx := rng.randi_range(4, W - 4)
		if tx > 118 and tx < 250:
			continue
		trees.append([tx, mini(prof[tx] + rng.randi_range(8, 34), Hh - 2), rng.randi_range(26, 54), rng.randf_range(5.0, 8.5), rng.randf() < 0.3])
	trees.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1])
	for b: Array in boulders:
		if b[1] < prof[b[0]] + 14:
			_boulder(im, b[0], b[1], b[2], b[2] * 0.72, rng.randi())
	for t: Array in trees:
		K.shadow(im, t[0] + 2, t[1] + 1, t[3] * 0.8, 2.5, 0.3)
		_conifer(im, t[0], t[1], t[2], t[3], rng.randi(), t[4])
	for b: Array in boulders:
		if b[1] >= prof[b[0]] + 14:
			_boulder(im, b[0], b[1], b[2], b[2] * 0.72, rng.randi())
	for i in 90:
		var fx := rng.randi_range(0, W - 1)
		if fx > 130 and fx < 235:
			continue
		var fy := mini(prof[fx] + rng.randi_range(4, 38), Hh - 1)
		if rng.randf() < 0.55:
			_fern(im, fx, fy, rng.randi_range(4, 7), rng.randi())
		else:
			_shrub(im, fx, fy, rng.randf_range(3.0, 6.0), rng.randi(), rng.randf() < 0.4)


## The plunge pool where the cascade lands, ringed with wet rock.
func _pool(im: Image, rng: RandomNumberGenerator) -> void:
	var p := POOL_POS
	var water := _cols(WATER)
	# dark wet rock apron
	_blob(im, p.x, p.y - 2, 30, 9, _cols(["1e2230", "2d3245", "444a5e", "5a6076"]), 71, 0.3, 0.8)
	for i in 14:
		var a := i / 14.0 * TAU
		_boulder(im, p.x + cos(a) * 24, p.y + 1 + sin(a) * 5, rng.randf_range(3.5, 7.0), rng.randf_range(2.5, 4.5), rng.randi())
	# the pool itself
	for y in range(p.y - 5, p.y + 6):
		for x in range(p.x - 20, p.x + 21):
			var dx := (x - p.x) / 19.0
			var dy := (y - p.y) / 4.6
			var d2 := dx * dx + dy * dy
			if d2 <= 1.0:
				var v := 0.28 + (1.0 - d2) * 0.28 + (K.hash2(x, y / 2, 77) - 0.5) * 0.25
				if dy < -0.3:
					v -= 0.1
				var col := _ramp(water, v, x, y, 0.4)
				if d2 > 0.75 and K.hash2(x, y, 78) < 0.5:
					col = Color("e4f6f2")
				K.px(im, x, y, col)
	for i in 6:
		var fx := p.x - 13 + i * 5 + rng.randi_range(-1, 1)
		K.px(im, fx, p.y + rng.randi_range(-2, 2), Color("f4fcfa"))
	for i in 9:
		_fern(im, p.x - 30 + i * 7, p.y + 6 + rng.randi_range(-1, 3), rng.randi_range(4, 6), rng.randi())


# ---------------------------------------------------------------- the cascade

static func _vnoise(cell_x: int, y: float, cell_h: float, period: int, seed_value: int) -> float:
	var yc := y / cell_h
	var i0 := int(floor(yc))
	var f := yc - i0
	f = f * f * (3.0 - 2.0 * f)
	var a := K.hash2(cell_x, posmod(i0, period), seed_value)
	var b := K.hash2(cell_x, posmod(i0 + 1, period), seed_value)
	return lerpf(a, b, f)


## One frame of the ribbon of water. The pattern repeats every 48 px of flow,
## and one frame moves it 8 px.
func cascade_frame(frame: int) -> Image:
	var W := CASCADE_SIZE.x
	var Hh := CASCADE_SIZE.y
	var im := K.make(W, Hh)
	var shift := frame * 8.0
	var tones := _cols(["4f80a6", "6ea0c4", "9ccce4", "cfeaf6", "f2fbff", "ffffff"])
	var ledge_ys := [50, 94, 133, 171]
	for y in Hh:
		var Y := float(y + CASCADE_POS.y)
		var cx := chan_x(Y) - CASCADE_POS.x
		var w := 3.0 + 3.0 * smoothstep(0.0, 40.0, Y) + 0.6 * sin(Y * 0.19)
		var lip_glow := 0.0
		for ly: int in ledge_ys:
			var t := Y - ly
			if t >= 0.0 and t < 26.0:
				w += 3.6 * smoothstep(0.0, 9.0, t) * (1.0 - smoothstep(9.0, 26.0, t))
			if absf(t) < 3.0:
				lip_glow = 1.0 - absf(t) / 3.0
				w += 0.9
		if Y > 186.0:
			w += (Y - 186.0) * 0.5
		var flow_y := float(y) - shift
		for x in W:
			var d := absf(x - cx)
			var ex := (K.hash2(x, posmod(int(flow_y), 48), 12) - 0.5) * 1.6
			var cover := w + ex - d
			if cover > 0.0:
				var cell := int(floor(x * 0.55))
				var v := _vnoise(cell, flow_y, 6.0, 8, 21) * 0.5 + _vnoise(cell + 40, flow_y, 12.0, 4, 22) * 0.3 + _vnoise(int(x * 0.9) + 90, flow_y, 3.0, 16, 23) * 0.2
				var prof_c := 1.0 - pow(d / maxf(w, 1.0), 2.0) * 0.7
				# a fast, thin layer of white streaks riding the flow
				var fast := _vnoise(int(x * 0.7) + 140, flow_y * 1.6, 2.5, 24, 24)
				if fast > 0.6:
					v += 1.1 * (fast - 0.6)
				v = v * 0.95 + prof_c * 0.24 + lip_glow * 0.3 - 0.08
				# the bright core of the sheet, brightest down the middle
				var core := 1.0 - clampf(d / maxf(w, 1.0), 0.0, 1.0)
				v += 0.16 * core * core
				v -= 0.22 * ((x - cx) / maxf(w, 1.0)) # right side in shade
				if d > w - 1.2:
					v -= 0.22 # a blue rim where the water meets the dark slab
				if Y > 190.0:
					v += (Y - 190.0) * 0.03
				var col := _ramp(tones, v, x, y, 0.5)
				if cover < 1.0:
					col.a = 0.55
				im.set_pixel(x, y, col)
			elif cover > -3.2:
				# spray to the sides, moving with the flow
				var fall := posmod(int(flow_y), 48)
				if K.hash2(x, fall, 33) < 0.11 * (1.0 + lip_glow) and K.hash2(x + 7, fall + 3, 34) < 0.7:
					im.set_pixel(x, y, Color(0.86, 0.95, 1.0, 0.55 if cover > -1.6 else 0.35))
			# foam splashing around the plunge, in clumps that move with the frame
			if Y > 186.0 and cover > -5.0 and cover <= 1.0:
				var fc := K.hash2(int(x / 2), int(Y / 2) + frame * 3, 36)
				if fc < 0.5 * (1.0 - absf(cover) / 5.0):
					im.set_pixel(x, y, Color("f2fbff") if fc < 0.2 else Color("cfeaf6"))
	return im


func mist_frame(frame: int) -> Image:
	var im := K.make(64, 32)
	for i in 11:
		var phase := K.hash2(i, 5, 60)
		var t := fposmod(frame / float(MIST_FRAMES) + phase, 1.0)
		var px := 32.0 + (K.hash2(i, 6, 61) - 0.5) * 34.0
		var py := 27.0 - t * 22.0
		var r := 4.0 + t * 6.0 + K.hash2(i, 7, 62) * 3.0
		var strength := sin(t * PI) * 0.5
		for y in range(int(py - r), int(py + r) + 1):
			for x in range(int(px - r * 1.4), int(px + r * 1.4) + 1):
				var dx := (x - px) / (r * 1.4)
				var dy := (y - py) / r
				var d := dx * dx + dy * dy
				if d < 1.0:
					var a := (1.0 - d) * strength
					var level := 0.0
					if a > 0.28:
						level = 0.5
					elif a > 0.14:
						level = 0.3
					elif a > 0.06 and _bayer(x, y) < 0.5:
						level = 0.16
					if level > 0.0:
						K.px(im, x, y, Color(0.92, 0.97, 1.0, level))
	return im


# ---------------------------------------------------------------- Stoneman Bridge

## Rock-faced ashlar: courses of hewn granite blocks with mortar, a lit top and
## left edge on every block, and chisel texture.
static func _ashlar(im: Image, x0: int, y0: int, w: int, h: int, seed_value: int, tone := 0.55, course_lo := 7, course_hi := 9) -> void:
	var ramp := _cols(STONE)
	var y := 0
	var ci := 0
	while y < h:
		var ch := mini(course_lo + int(K.hash2(ci, seed_value, 1) * (course_hi - course_lo + 1)), h - y)
		var x := -int(K.hash2(ci, seed_value, 2) * 16.0)
		while x < w:
			var bw := 11 + int(K.hash2(x + 100, ci, seed_value) * 13.0)
			var base := tone + (K.hash2(x, ci, seed_value + 3) - 0.5) * 0.2
			for py in ch:
				for px in bw:
					var gx := x + px
					if gx < 0 or gx >= w:
						continue
					var s := base
					var u := float(px) / bw
					var v := float(py) / ch
					if py == 0:
						s += 0.13
					elif py >= ch - 1:
						s = 0.05
					elif py >= ch - 2:
						s -= 0.14
					if px == 0:
						s += 0.08
					elif px >= bw - 1:
						s = 0.05
					elif px >= bw - 2:
						s -= 0.1
					if py > 0 and py < ch - 2 and px > 0 and px < bw - 2:
						var bump := K.hash2((gx) / 2, (y + py) / 2, seed_value + 9) - 0.5
						s += bump * 0.2 + (0.5 - u) * 0.06 + (0.5 - v) * 0.06
						if K.hash2(gx, y + py, seed_value + 11) < 0.045:
							s -= 0.18
						elif K.hash2(gx, y + py, seed_value + 12) < 0.03:
							s += 0.16
					im.set_pixel(x0 + gx, y0 + y + py, _ramp(ramp, s, gx, y + py, 0.6))
			x += bw
		y += ch
		ci += 1


static func _water_px(x: int, y: int, dark := 1.0, t_off := 0.0) -> Color:
	var ramp := _cols(WATER)
	var wave := sin(x * 0.21 + y * 0.9 + t_off) * 0.5 + sin(x * 0.07 - y * 0.5) * 0.5
	var v := 0.42 + wave * 0.12 + (K.hash2(x / 2, y, 70) - 0.5) * 0.2
	# horizontal ripple highlights
	if (y + int(sin(x * 0.11) * 2.0)) % 4 == 0 and K.hash2(x / 3, y, 71) < 0.45:
		v += 0.28
	return _ramp(ramp, v * dark, x, y, 0.5)


func bridge_image() -> Image:
	var W := BRIDGE_SIZE.x
	var Hh := BRIDGE_SIZE.y
	var im := K.make(W, Hh)
	var stone := _cols(STONE)
	var water := _cols(WATER)
	var face_top := 64
	var water_y := 128
	var river := BRIDGE_RIVER_X
	var span := 52
	var pier := 18
	var arch_cx: Array[int] = []
	for i in 3:
		arch_cx.append(river.x + span / 2 + i * (span + pier))
	var crown := 88
	var radius := 27
	var circ_cy := crown + radius
	var spring := 110

	# --- river in front of the bridge and shadow on it
	for y in range(water_y, Hh):
		for x in range(river.x, river.y):
			var dark := 0.62 + 0.38 * smoothstep(water_y, water_y + 14.0, y)
			var c := _water_px(x, y, dark)
			c.a = 1.0 - smoothstep(Hh - 9.0, Hh - 1.0, y)
			if c.a > 0.0:
				im.set_pixel(x, y, c)
	# bank stones at the abutment feet
	for side in 2:
		var bx := 0 if side == 0 else river.y
		for y in range(water_y - 2, water_y + 8):
			for x in range(bx, bx + 64):
				var fall := (y - water_y) / 8.0
				var edge := 0.0
				if side == 0:
					edge = river.x + 6 - (x - bx) * 0.0
				var tone := 0.45 + (K.hash2(x / 3, y / 2, 80) - 0.5) * 0.3 - fall * 0.2
				if K.hash2(x, y, 81) < 1.0 - smoothstep(0.0, 1.0, fall) * 0.9 and y >= water_y:
					im.set_pixel(x, y, _ramp(stone, tone, x, y, 0.6))

	# --- the face: courses of granite from parapet to waterline
	_ashlar(im, 0, face_top, W, water_y - face_top, 7)
	# string course under the parapet
	for x in W:
		im.set_pixel(x, 76, _ramp(stone, 0.85, x, 76, 0.3))
		im.set_pixel(x, 77, _ramp(stone, 0.72, x, 77, 0.3))
		im.set_pixel(x, 78, _ramp(stone, 0.22, x, 78, 0.3))
		im.set_pixel(x, 79, _ramp(stone, 0.32, x, 79, 0.3))
		im.set_pixel(x, 80, _ramp(stone, 0.4, x, 80, 0.3))
	# faint hue shift: shade the face toward the waterline, and moss along it
	for y in range(face_top, water_y):
		var t := float(y - face_top) / (water_y - face_top)
		for x in W:
			var c := im.get_pixel(x, y)
			if c.a == 0.0:
				continue
			c = c.darkened(t * 0.22)
			c = c.lerp(Color("4a5a78"), t * 0.1)
			if y > water_y - 5:
				c = c.darkened(0.18)
			if y > water_y - 9 and K.hash2(x / 2, y, 82) < (y - (water_y - 9)) / 14.0 * 0.6:
				c = c.lerp(Color("4f7a44"), 0.6)
			im.set_pixel(x, y, c)

	# --- the three arches
	for ax in arch_cx:
		for y in range(crown - 8, water_y + 1):
			for x in range(ax - radius - 8, ax + radius + 9):
				var dx := x - ax
				var inside := false
				var ring := false
				var dist := 0.0
				if y < spring:
					dist = sqrt(float(dx * dx + (y - circ_cy) * (y - circ_cy)))
					inside = dist < radius
					ring = not inside and dist < radius + 5.0
				else:
					inside = absi(dx) <= radius - 1
					ring = not inside and absi(dx) <= radius + 1
				if inside:
					im.set_pixel(x, y, _tunnel_px(x, y, ax, crown, circ_cy, spring, radius, water_y))
				elif ring and y < spring:
					# voussoirs: a ring of wedge stones with radial joints
					var ang := atan2(float(y - circ_cy), float(dx))
					var seg := int(floor(ang / 0.16))
					var frac := ang / 0.16 - seg
					var s := 0.78 + (K.hash2(seg, ax, 90) - 0.5) * 0.14
					if dist < radius + 1.0:
						s -= 0.28
					elif dist > radius + 4.0:
						s -= 0.16
					if frac < 0.09:
						s = 0.16
					elif frac > 0.9:
						s += 0.06
					s += (K.hash2(x, y, 91) - 0.5) * 0.08
					im.set_pixel(x, y, _ramp(stone, s, x, y, 0.5))
		# keystone
		for y in range(crown - 10, crown - 2):
			for x in range(ax - 4, ax + 5):
				var s2 := 0.9 - float(y - (crown - 10)) * 0.02
				if x == ax - 4 or y == crown - 3:
					s2 = 0.3
				elif x == ax + 4:
					s2 = 0.42
				im.set_pixel(x, y, _ramp(stone, s2 + (K.hash2(x, y, 92) - 0.5) * 0.06, x, y, 0.4))
		# a shadow under the keystone and ring where the string course overhangs
		for x in range(ax - radius - 4, ax + radius + 5):
			var c := im.get_pixel(x, 81)
			im.set_pixel(x, 81, c.darkened(0.25))
	# piers: a shaded left and lit right edge to read as cutwaters
	for i in 4:
		var px := river.x + i * (span + pier) - pier / 2 - (0 if i > 0 else 0)
		if i == 0 or i == 3:
			continue
	# vines hanging from the parapet at both ends
	for side in 2:
		for i in 6:
			var vx := (6 + i * 7) if side == 0 else (W - 8 - i * 7)
			var len := 7 + int(K.hash2(i, side, 95) * 15.0)
			for k in len:
				var vy := 64 + k
				var vcol := Color("3f6a3c") if K.hash2(vx, vy, 96) < 0.6 else Color("5f8a4a")
				if k > len - 3:
					vcol = Color("7aa055")
				K.px(im, vx + int(sin(k * 0.6 + i) * 1.2), vy, vcol)
				if k % 3 == 1:
					K.px(im, vx + int(sin(k * 0.6 + i) * 1.2) + 1, vy, vcol.lightened(0.15))

	# --- foam and swirls at the piers, and the ground shadow on the banks
	for i in 4:
		var fx := river.x + i * (span + pier) - pier / 2
		if i == 0:
			fx = river.x
		elif i == 3:
			fx = river.y
		else:
			fx = river.x + i * span + (i - 1) * pier + pier / 2
		for y in range(water_y - 3, water_y + 10):
			for x in range(fx - 15, fx + 16):
				var dx := (x - fx) / 14.0
				var dy := (y - (water_y + 2)) / 6.0
				var d := dx * dx + dy * dy
				if d < 1.0 and x >= river.x - 1 and x <= river.y:
					if K.hash2(x, y, 100) < (1.0 - d) * 0.75 + 0.05 and (y + x / 3) % 3 != 0:
						var a := 1.0 - smoothstep(Hh - 9.0, Hh - 1.0, y)
						var c := Color("e4f6f2") if K.hash2(x, y, 101) < 0.6 else Color("bfe6e0")
						c.a = a
						if a > 0.0 and im.get_pixel(x, y).a > 0.0 or y >= water_y:
							K.px(im, x, y, c)

	# --- the deck: parapets and a gravel road
	_deck(im, W)
	# stone lamp posts on the north parapet at both ends
	for px in [8, W - 20]:
		_lamp_post(im, px, 34)
	# low finials on the south parapet ends
	for px in [6, W - 18]:
		_pier_cap(im, px, 55)
	return im


func _tunnel_px(x: int, y: int, ax: int, crown: int, circ_cy: int, spring: int, radius: int, water_y: int) -> Color:
	var stone := _cols(STONE)
	# far end of the tunnel: a smaller, higher arch of daylight
	var fx := x - ax
	var fdist := sqrt(float(fx * fx + (y - (circ_cy + 3)) * (y - (circ_cy + 3))))
	var far_r := radius * 0.7
	var in_far := false
	if y < spring + 2:
		in_far = fdist < far_r
	else:
		in_far = absi(fx) < far_r - 1.0
	if y >= 115:
		# water under the bridge: darker, with reflected light and ripples
		var dark := 0.42 + 0.3 * (1.0 - smoothstep(112.0, water_y, y)) if not in_far else 0.62
		var c := _water_px(x, y, dark, 1.3)
		if y == 116 or y == 117:
			c = c.darkened(0.25)
		return c
	if in_far:
		# the far bank in daylight: dark trees over a hazy, glittering river
		var g := K.hash2(x, y, 110)
		if y < 96:
			return _ramp(_cols(GREENS), 0.2 + (g - 0.5) * 0.3 + (y - 90) * 0.01, x, y, 0.5)
		if y < 104:
			return _ramp(_cols(GREENS), 0.4 + (g - 0.5) * 0.4, x, y, 0.5)
		var t := (y - 104) / 12.0
		var c := _ramp(_cols(WATER), 0.38 + t * 0.22 + (g - 0.5) * 0.2, x, y, 0.5)
		if K.hash2(x, y, 114) < 0.06:
			c = Color("e4f6f2")
		return c
	# the vault's soffit: dark stone, a little lighter toward the far end
	var edge := clampf((fdist - far_r) / (radius - far_r), 0.0, 1.0)
	var s := 0.05 + (1.0 - edge) * 0.18 + (K.hash2(x, y, 113) - 0.5) * 0.06
	# a lit patch on the bottom of the soffit from the reflected water
	s += smoothstep(104.0, 116.0, float(y)) * 0.12
	return _ramp(stone, s, x, y, 0.5)


func _deck(im: Image, W: int) -> void:
	var stone := _cols(STONE)
	var deck_y := BRIDGE_DECK.position.y
	# the road: compacted gravel
	var road := _cols(["6a5238", "82663f", "9c7e50", "b59a68", "cdb582"])
	for y in range(deck_y + 8, deck_y + 24):
		for x in W:
			var t := (y - (deck_y + 8)) / 15.0
			var s := 0.5 + (K.hash2(x, y, 120) - 0.5) * 0.3
			s += (0.12 - absf(t - 0.5) * 0.24)
			if K.hash2(x, y, 121) < 0.03:
				s += 0.3
			elif K.hash2(x, y, 122) < 0.04:
				s -= 0.28
			# wheel-worn lanes
			if absf(t - 0.35) < 0.08 or absf(t - 0.7) < 0.08:
				s += 0.07
			# cast shadow of the north parapet
			s -= 0.28 * (1.0 - smoothstep(0.0, 0.3, t))
			im.set_pixel(x, y, _ramp(road, s, x, y, 0.5))
	# expansion joints over the piers
	for jx in [64, 82, 134, 152, 204, 222, 256]:
		for y in range(deck_y + 8, deck_y + 24):
			K.px(im, jx, y, Color("4c463c"))
			K.px(im, jx + 1, y, Color("bfb49e"))

	# north parapet: a rounded cap on top, and the inner face toward us
	for x in W:
		var cap_i := x / 14
		var local := x % 14
		for y in range(deck_y, deck_y + 4):
			var t := y - deck_y
			var s := 0.86 - t * 0.04 + (K.hash2(cap_i, 3, 130) - 0.5) * 0.12
			if local == 0:
				s = 0.3
			elif local == 1:
				s += 0.06
			if t == 0:
				s += 0.08
			im.set_pixel(x, y, _ramp(stone, s + (K.hash2(x, y, 131) - 0.5) * 0.06, x, y, 0.5))
	for y in range(deck_y + 4, deck_y + 8):
		for x in W:
			var t := y - (deck_y + 4)
			var s := 0.48 - t * 0.06 + (K.hash2(x / 3, 2, 132) - 0.5) * 0.14
			if t == 3:
				s = 0.16
			if x % 14 == 0:
				s -= 0.18
			im.set_pixel(x, y, _ramp(stone, s + (K.hash2(x, y, 133) - 0.5) * 0.1, x, y, 0.5))

	# south parapet: we see its top and the projecting cap
	for x in W:
		var cap_i := (x + 7) / 14
		var local := (x + 7) % 14
		for y in range(deck_y + 24, deck_y + 32):
			var t := y - (deck_y + 24)
			var s := 0.0
			if t < 5:
				s = 0.9 - t * 0.03 + (K.hash2(cap_i, 4, 134) - 0.5) * 0.1
				if t == 0:
					s += 0.07
			elif t == 5:
				s = 0.66
			else:
				s = 0.22 if t == 6 else 0.18
			if local == 0 and t < 5:
				s = 0.3
			elif local == 1 and t < 5:
				s += 0.05
			im.set_pixel(x, y, _ramp(stone, s + (K.hash2(x, y, 135) - 0.5) * 0.05, x, y, 0.5))
	# the wall below the cap gets a strong shadow from the projecting cap
	for x in W:
		for y in range(deck_y + 32, deck_y + 35):
			var c := im.get_pixel(x, y)
			im.set_pixel(x, y, c.darkened(0.3 - (y - (deck_y + 32)) * 0.08))


func _lamp_post(im: Image, px: int, base_y: int) -> void:
	var stone := _cols(STONE)
	var post_top := 12
	# masonry post 12 wide
	for y in range(post_top, base_y + 3):
		for x in range(px, px + 12):
			var t := float(y - post_top) / (base_y + 3 - post_top)
			var s := 0.62 + (K.hash2(x, y, 140) - 0.5) * 0.2 - t * 0.06
			if x == px:
				s += 0.2
			elif x >= px + 10:
				s -= 0.25
			if (y - post_top) % 5 == 4:
				s -= 0.3
			im.set_pixel(x, y, _ramp(stone, s, x, y, 0.6))
	# capstone
	for x in range(px - 1, px + 13):
		for y in range(post_top - 2, post_top + 1):
			var s := 0.9 - (y - (post_top - 2)) * 0.1
			if x == px - 1 or x == px + 12:
				s = 0.4
			im.set_pixel(x, y, _ramp(stone, s, x, y, 0.4))
	# iron lantern
	var cx := px + 6
	for y in range(3, 11):
		for x in range(cx - 3, cx + 4):
			var glass := x > cx - 3 and x < cx + 3 and y > 4 and y < 10
			var c := Color("2f2a2a")
			if glass:
				c = Color("ffe08a") if x <= cx else Color("f0b85a")
				if y == 5:
					c = Color("fff2b8")
			im.set_pixel(x, y, c)
	for x in range(cx - 4, cx + 5):
		K.px(im, x, 2, Color("2f2a2a"))
	K.px(im, cx, 1, Color("2f2a2a"))
	# warm glow around the flame
	for dy in range(-3, 4):
		for dx in range(-5, 6):
			if absf(dx) + absf(dy) * 1.4 < 6.0 and im.get_pixel(cx + dx, 7 + dy).a == 0.0:
				K.px(im, cx + dx, 7 + dy, Color(1.0, 0.85, 0.45, 0.09))


func _pier_cap(im: Image, px: int, top_y: int) -> void:
	var stone := _cols(STONE)
	for y in range(top_y, top_y + 9):
		for x in range(px, px + 12):
			var t := y - top_y
			var s := 0.85 - t * 0.05 + (K.hash2(x, y, 150) - 0.5) * 0.1
			if x == px:
				s += 0.08
			elif x == px + 11:
				s -= 0.28
			if t >= 6:
				s = 0.26
			im.set_pixel(x, y, _ramp(stone, s, x, y, 0.5))
