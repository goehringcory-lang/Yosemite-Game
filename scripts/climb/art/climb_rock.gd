class_name ClimbRock
extends RefCounted
## Paints one pitch of rock: the face, its stains and lichen, the cracks, flakes,
## dikes, knobs, chimney walls or glacier ice the pitch's style calls for, then
## the holds, ledges and fixed gear on top. Each route has its own granite
## (colors below), lit by the time of day.
##
## Light comes from the upper left, and the sunlit rim of the wall is its
## right-hand edge against the sky. Everything is painted once per pitch into
## an Image; only sparkle and gear are drawn on top while you climb.

const P := preload("res://scripts/climb/art/climb_paint.gd")
const L := preload("res://scripts/climb/art/climb_layout.gd")

## Daylight ramps, dark to light: deep, shade, base, lit, highlight.
const ROCKS := {
	"apron": ["56525e", "7c7884", "a29ea8", "cac6cc", "ece8ec"],
	"polished": ["4e5864", "727e8c", "9aa4b0", "c4cad0", "e8ecee"],
	"golden": ["5a4430", "82603e", "ac8654", "d6ac70", "f2d492"],
	"orange": ["5c3a30", "86543e", "b27a54", "daa270", "f6ca92"],
	"dark": ["262a3c", "44485c", "6a6e82", "9498ac", "c0c4d6"],
	"pale": ["6c665e", "968e82", "c4bcac", "e6dec8", "faf4e0"],
	"roof": ["2e2c3a", "4c4a5a", "6c6a7c", "908e9e", "b6b4c4"],
	"elcap": ["3e3e4c", "6a6a7a", "9e9ea4", "cacac6", "eeeadc"],
	"arches": ["54505a", "787480", "a09c98", "ccc4b0", "ece2c6"],
	"dome": ["68646a", "928e96", "bcb8bc", "e0dcd8", "f6f2ea"],
	"knobby": ["564e44", "7e7662", "aca088", "d4c8a6", "f0e6c4"],
	"ice": ["4a6ca8", "7a9ccc", "b0cce6", "dcecf8", "f8fcff"],
}

const STREAK := Color("2e2a34")
const LICHEN_ORANGE := Color("d8943a")
const LICHEN_YELLOW := Color("c8c050")
const LICHEN_GREEN := Color("8aa85a")
const MOSS := Color("5a7a3a")


## The rock colors for [param rock_key] lit by [param pal] (ClimbSky.palette):
## deep, shade, base, lit, hi, plus seam (dark joints) and stain colors.
static func colors(rock_key: String, pal: Dictionary) -> Dictionary:
	var hexes: Array = ROCKS.get(rock_key, ROCKS.apron)
	var tint: Color = pal.get("tint", Color.WHITE)
	var lum: float = pal.get("lum", 1.0)
	var out := {}
	var names := ["deep", "shade", "base", "lit", "hi"]
	for i in names.size():
		out[names[i]] = _light(Color(hexes[i]), tint, lum)
	# Alpenglow lights the sunlit tones (base, lit, highlight) more than the shade.
	var glow: float = pal.get("glow", 0.0)
	if glow > 0.0:
		var glow_col: Color = pal.get("glow_col", Color.WHITE)
		for i in range(2, 5):
			var col: Color = out[names[i]]
			var v := col.r * 0.3 + col.g * 0.55 + col.b * 0.15
			out[names[i]] = col.lerp(Color(glow_col.r * v * 1.3, glow_col.g * v * 1.3, glow_col.b * v * 1.3).clamp(), glow * [0.18, 0.32, 0.45][i - 2])
	# Hue shift: the shadows drift toward blue-violet and the lights toward
	# warm cream, so the granite reads as lit stone rather than grey paint.
	# The violet is kept to the deepest tone; mid-tones stay neutral granite.
	out["deep"] = (out["deep"] as Color).lerp(Color("3c3c6e"), 0.3)
	out["shade"] = (out["shade"] as Color).lerp(Color("4a4870"), 0.08)
	out["lit"] = (out["lit"] as Color).lerp(Color("ffe6b4"), 0.1)
	out["hi"] = (out["hi"] as Color).lerp(Color("fff4d8"), 0.18)
	out["seam"] = _light(Color(hexes[0]).darkened(0.35), tint, lum)
	out["streak"] = _light(STREAK, tint, lum)
	out["lichen_o"] = _light(LICHEN_ORANGE, tint, lum)
	out["lichen_y"] = _light(LICHEN_YELLOW, tint, lum)
	out["lichen_g"] = _light(LICHEN_GREEN, tint, lum)
	out["moss"] = _light(MOSS, tint, lum)
	out["chalk"] = _light(Color("efe6d6"), tint, minf(lum + 0.1, 1.1))
	out["tint"] = tint
	out["lum"] = lum
	return out


static func _light(c: Color, tint: Color, lum: float) -> Color:
	var t := c.lerp(Color(c.r * tint.r, c.g * tint.g, c.b * tint.b), 0.75)
	return Color(clampf(t.r * lum, 0, 1), clampf(t.g * lum, 0, 1), clampf(t.b * lum, 0, 1), 1.0)


## A ramp color by index 0..4 with an optional nudge: the painters pick
## tones by number so a whole wall stays within a few colors.
static func tone(c: Dictionary, index: float) -> Color:
	var names := ["deep", "shade", "base", "lit", "hi"]
	var i := clampi(floori(index), 0, 4)
	var j := clampi(i + 1, 0, 4)
	var f := index - floorf(index)
	return (c[names[i]] as Color).lerp(c[names[j]], f)


## Paints the wall picture for the pitch in [param state]. Returns
## {"image": Image, "edge": PackedInt32Array, "gap": Rect2i}.
static func paint(state: ClimbState, rock_key: String, pal: Dictionary, seed_value: int) -> Dictionary:
	var spec := state.spec
	var style: String = spec.get("style", "crack")
	var deco: Array = spec.get("deco", [])
	var w := L.WALL_W
	var h := L.wall_height(state.top_row)
	var c := colors(rock_key, pal)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var im := P.make(w, h)
	var result := {"gap": Rect2i()}
	match style:
		"snow", "ice":
			_glacier(im, c, rng, style, deco, state)
			result["edge"] = _ragged_edge(im, c, rng, true)
		"chimney":
			result = _chimney(im, c, rng, deco, state)
		"roof":
			# Roofs have their own picture (see paint_roof); this is the wall
			# above the lip, drawn plain.
			_face(im, c, rng, "crack", deco, state, rock_key)
			result["edge"] = _ragged_edge(im, c, rng, false)
		_:
			_face(im, c, rng, style, deco, state, rock_key)
			result["edge"] = _ragged_edge(im, c, rng, false)
	result["image"] = im
	var edge: PackedInt32Array = result.edge
	_features(im, c, rng, state, style, deco, edge)
	_paint_holds(im, c, rng, state, style, edge)
	if style not in ["chimney", "snow", "ice"] and edge.size() == h:
		_finish(im, edge)
	return result


## Last pass over the finished wall: a gentle contrast curve with warm lights
## and cool shadows, the face turning away into shade toward the corner on the
## right, and a soft fall-off at the left screen edge.
static func _finish(im: Image, edge: PackedInt32Array) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var data := im.get_data()
	# Most of the face gets the plain 0.93 shade, and the wall is painted in a
	# few hundred colors, so each color's result is worked out once.
	var plain := {}
	for y in h:
		var e := edge[y]
		var row := y * w * 4
		for x in range(0, mini(e + 1, w)):
			var o := row + x * 4
			var px := data.decode_u32(o)
			if px >> 24 < 128:
				continue
			var shade := 0.93
			var turn := float(x - (e - 22)) / 18.0
			if turn <= 0.0 and x >= 16:
				var rgb: int = plain.get(px & 0xffffff, -1)
				if rgb < 0:
					rgb = _finish_rgb(px, shade)
					plain[px & 0xffffff] = rgb
				data.encode_u32(o, rgb | (px & 0xff000000))
				continue
			if turn > 0.0:
				shade -= minf(turn, 1.0) * 0.14
			if x < 16:
				shade -= (16.0 - x) / 16.0 * 0.1
			data.encode_u32(o, _finish_rgb(px, shade) | (px & 0xff000000))
	im.set_data(w, h, false, Image.FORMAT_RGBA8, data)


## _finish()'s curve for one pixel (RGBA8 packed little-endian, as
## decode_u32 reads it): returns the new red, green and blue, packed the same.
static func _finish_rgb(px: int, shade: float) -> int:
	var r := (px & 0xff) / 255.0
	var g := ((px >> 8) & 0xff) / 255.0
	var b := ((px >> 16) & 0xff) / 255.0
	var lum := r * 0.3 + g * 0.55 + b * 0.15
	var k := 1.1
	# warm the lights, cool the shadows
	var warm := (lum - 0.5) * 0.05
	r = ((r - 0.5) * k + 0.5 + warm) * shade
	g = ((g - 0.5) * k + 0.5 + warm * 0.4) * shade
	b = ((b - 0.5) * k + 0.5 - warm) * shade
	return int(clampf(r, 0.0, 1.0) * 255.0) | int(clampf(g, 0.0, 1.0) * 255.0) << 8 | int(clampf(b, 0.0, 1.0) * 255.0) << 16


# ---------------------------------------------------------------- the face

## The face: a relief map (stretched noise plus jointed plates) lit from the
## upper left, quantized to a few tones with ordered dither, then joints,
## stains, lichen and speckle on top.
static func _face(im: Image, c: Dictionary, rng: RandomNumberGenerator, style: String, deco: Array, state: ClimbState, rock_key: String) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var smooth := style == "slab" or style == "dike" or rock_key == "polished" or rock_key == "dome"
	var relief := _relief(w, h, rng.randi(), smooth)
	var lut := _packed_tones(c)
	var out := PackedByteArray()
	out.resize(w * h * 4)
	var k_light := 1.45 if not smooth else 1.0
	# The terms of the shading that depend on one input each, worked out once
	# (the same arithmetic as per pixel, so the picture doesn't change).
	var light_x := _scaled_diffs(0.8)
	var light_y := _scaled_diffs(0.55)
	# The broad light: the upper left of the face is lit and the lower right
	# falls off, so every plate reads as lit from the same side.
	var sun_x := PackedFloat64Array()
	sun_x.resize(w)
	for x in w:
		sun_x[x] = (0.5 - float(x) / w) * 0.26
	var sun_y := PackedFloat64Array()
	sun_y.resize(h)
	for y in h:
		sun_y[y] = (0.5 - float(y) / h) * 0.16
	var height := PackedFloat64Array()
	height.resize(256)
	for v in 256:
		height[v] = (v / 255.0 - 0.5) * 1.2
	var bayer := _bayer_terms(0.03)
	for y in h:
		var row := y * w
		var brow := (y & 3) << 2
		var up := y > 2
		var down := y < h - 3
		for x in w:
			var i := row + x
			var here := relief[i]
			var xl := relief[i - 3] if x > 2 else here
			var xr := relief[i + 3] if x < w - 3 else here
			var yu := relief[i - 3 * w] if up else here
			var yd := relief[i + 3 * w] if down else here
			# Light from the upper left: surfaces facing left and up are lit.
			var s_light := (light_x[xl - xr + 255] + light_y[yu - yd + 255]) / 255.0 * 4.0
			var t := 2.0 + s_light * k_light + sun_x[x] + sun_y[y] + height[here]
			out.encode_u32(i * 4, lut[clampi(roundi((t + bayer[brow | (x & 3)]) * 3.0) * 4 / 3, 0, 19)])
	im.set_data(w, h, false, Image.FORMAT_RGBA8, out)
	_joints(im, c, rng, smooth)
	_stains(im, c, rng, deco)
	_lichen(im, c, rng, deco, h)
	# Feldspar glints and dark crystals, in small clusters of two or three
	# pixels, so the grain reads as stone and not as static.
	for i in w * h / 420:
		var p := Vector2i(rng.randi_range(0, w - 1), rng.randi_range(0, h - 1))
		var bright := rng.randf() < 0.55
		var offs: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]
		for k in rng.randi_range(2, 3):
			var q: Vector2i = p + offs[k]
			if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h:
				continue
			var col := im.get_pixelv(q)
			im.set_pixelv(q, col.lightened(0.12) if bright else col.darkened(0.16))


## The 20 quarter-steps of the rock ramp as opaque RGBA8 pixels, packed for
## PackedByteArray.encode_u32.
static func _packed_tones(c: Dictionary) -> PackedInt64Array:
	var lut := PackedInt64Array()
	for i in 20:
		var col := tone(c, i * 0.25)
		lut.append(col.r8 | col.g8 << 8 | col.b8 << 16 | 255 << 24)
	return lut


## [param k] times every difference of two relief values (-255..255), indexed
## by the difference + 255.
static func _scaled_diffs(k: float) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	out.resize(511)
	for d in range(-255, 256):
		out[d + 255] = d * k
	return out


## The ordered-dither offset times [param k] for each (x & 3, y & 3), indexed
## by (y & 3) * 4 + (x & 3).
static func _bayer_terms(k: float) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	out.resize(16)
	for yy in 4:
		for xx in 4:
			var bay: float = P.BAYER[yy][xx] / 16.0 - 0.5
			out[yy * 4 + xx] = bay * k
	return out


## A height map, 0..255 per pixel: fluted noise plus plates cut by joints.
static func _relief(w: int, h: int, seed_value: int, smooth: bool) -> PackedByteArray:
	var fbm := FastNoiseLite.new()
	fbm.seed = seed_value
	fbm.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fbm.frequency = 0.015 if not smooth else 0.011
	fbm.fractal_octaves = 2
	fbm.fractal_gain = 0.4
	var squash := 3 if not smooth else 2
	var a := fbm.get_image(w, maxi(h / squash, 8), false, false, true)
	a.resize(w, h, Image.INTERPOLATE_BILINEAR)
	var cells := FastNoiseLite.new()
	cells.seed = seed_value + 7
	cells.noise_type = FastNoiseLite.TYPE_CELLULAR
	cells.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	cells.cellular_jitter = 0.9
	cells.frequency = 0.014 if not smooth else 0.008
	cells.domain_warp_enabled = true
	cells.domain_warp_amplitude = 18.0
	cells.domain_warp_frequency = 0.02
	var b := cells.get_image(w, h, false, false, true)
	var da := a.get_data()
	var db := b.get_data()
	var out := PackedByteArray()
	out.resize(w * h)
	var wa := 0.5 if not smooth else 0.42
	# Each source is a byte, so weigh the 256 values once.
	var weigh_a := PackedFloat64Array()
	var weigh_b := PackedFloat64Array()
	weigh_a.resize(256)
	weigh_b.resize(256)
	for v in 256:
		weigh_a[v] = v * wa
		weigh_b[v] = v * (1.0 - wa) * 0.9
	for i in w * h:
		out[i] = int(weigh_a[da[i]] + weigh_b[db[i]])
	return out


## Long hairline joints, wandering a little, with a lit lip on one side.
static func _joints(im: Image, c: Dictionary, rng: RandomNumberGenerator, smooth: bool) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var count := w / (60 if smooth else 48)
	for i in count:
		var x := float(rng.randi_range(4, w - 36))
		var y := rng.randi_range(-40, h - 80)
		var length := rng.randi_range(120, 420)
		var slant := rng.randf_range(-0.12, 0.12)
		var phase := rng.randf() * TAU
		for k in length:
			var yy := y + k
			if yy < 0 or yy >= h:
				continue
			var xx := int(x + slant * k + sin(k * 0.045 + phase) * 2.0)
			if xx < 1 or xx >= w - 30:
				continue
			# Break the line into runs so it reads as a joint, not a wire.
			if int((k + i * 13) / 37) % 5 == 4:
				continue
			im.set_pixel(xx, yy, c.seam)
			im.set_pixel(xx - 1, yy, im.get_pixel(xx - 1, yy).lightened(0.16))
			im.set_pixel(xx + 1, yy, im.get_pixel(xx + 1, yy).darkened(0.1))


## Dark water stains running down the rock, thin and dithered at the edges.
static func _stains(im: Image, c: Dictionary, rng: RandomNumberGenerator, deco: Array) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var heavy := "streaks" in deco
	var count := (w / 30 if heavy else w / 110)
	for i in count:
		var x := rng.randi_range(6, w - 40)
		var y := rng.randi_range(0, h - 120)
		var length := rng.randi_range(70, 240)
		var sw := rng.randi_range(1, 2)
		for k in length:
			var yy := y + k
			if yy >= h:
				break
			var drift := int(sin(k * 0.05 + i) * 1.4)
			var fade := 1.0 - float(k) / length
			for dx in range(-sw, sw + 1):
				var p := Vector2i(x + dx + drift, yy)
				if p.x >= 0 and p.x < w and not (absi(dx) == sw and not P.dither(x + dx, yy, fade * 0.6)):
					im.set_pixelv(p, im.get_pixelv(p).lerp(c.streak, 0.36 * fade + 0.1))


static func _lichen(im: Image, c: Dictionary, rng: RandomNumberGenerator, deco: Array, h: int) -> void:
	var w := im.get_width()
	var patches := h / 70
	if "lichen" in deco:
		patches = h / 28
	for i in patches:
		var cx := rng.randi_range(8, w - 40)
		var cy := rng.randi_range(8, h - 8)
		var col: Color = [c.lichen_o, c.lichen_y, c.lichen_g, c.lichen_o][rng.randi() % 4]
		for k in rng.randi_range(8, 22):
			var p := Vector2i(cx + rng.randi_range(-5, 5), cy + rng.randi_range(-3, 3))
			if p.x >= 0 and p.x < w and p.y >= 0 and p.y < h:
				im.set_pixelv(p, col if rng.randf() < 0.75 else col.darkened(0.2))
		if rng.randf() < 0.4:
			im.set_pixel(clampi(cx, 0, w - 1), clampi(cy - 2, 0, h - 1), col.lightened(0.3))


## The ragged right-hand edge of the wall against the sky, with a lit rim and a
## dark outline.
static func _ragged_edge(im: Image, c: Dictionary, rng: RandomNumberGenerator, soft: bool) -> PackedInt32Array:
	var w := im.get_width()
	var h := im.get_height()
	var edge := PackedInt32Array()
	edge.resize(h)
	var y := 0
	var ex := w - 12
	while y < h:
		var run := rng.randi_range(5, 18)
		ex = clampi(ex + rng.randi_range(-5, 5), w - 26, w - 3)
		for k in run:
			if y + k < h:
				edge[y + k] = ex + (1 if k % 6 == 0 else 0)
		y += run
	for yy in h:
		var e := edge[yy]
		im.fill_rect(Rect2i(e, yy, w - e, 1), Color(0, 0, 0, 0))
		im.fill_rect(Rect2i(maxi(e - 4, 0), yy, 3, 1), tone(c, 3.6))
		im.set_pixel(maxi(e - 1, 0), yy, c.seam.darkened(0.3))
	return edge


# ---------------------------------------------------------------- features

static func _features(im: Image, c: Dictionary, rng: RandomNumberGenerator, state: ClimbState, style: String, deco: Array, edge: PackedInt32Array) -> void:
	var top := state.top_row
	if "corner" in deco:
		_corner(im, c, rng, state)
	if "flake" in deco or style == "flake":
		_flakes(im, c, rng, state)
	if style == "dike":
		_dike(im, c, rng, state)
	if style == "knobs":
		_knobs(im, c, rng)
	if "roof" in deco and style != "roof":
		pass
	# Trees and shrubs growing from the rock at the ledges and cracks.
	var ledge_y := int(L.wall_px(top, 0, 0).y) + 6
	var top_y := int(L.wall_px(top, top, 0).y) + 6
	if "tree" in deco or "krummholz" in deco or "manzanita" in deco or "flowers" in deco:
		for i in 6:
			var x := rng.randi_range(6, int(edge[ledge_y]) - 34 if ledge_y < edge.size() else 200)
			var y := ledge_y if i < 3 else top_y
			ClimbProps.ledge_plant(im, x, y, deco, rng, c)


## Two planes meeting in an inside corner: lit on the left, shaded on the right,
## a dark crack down the seam.
static func _corner(im: Image, c: Dictionary, rng: RandomNumberGenerator, state: ClimbState) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var seam_x := int(L.GRID_X + 2.5 * L.COL_W)
	for yy in h:
		for xx in range(0, w - 28):
			if xx > seam_x and P.dither(xx, yy, 0.55):
				var col := im.get_pixel(xx, yy)
				im.set_pixel(xx, yy, col.darkened(0.2))
			elif xx <= seam_x and xx > seam_x - 40 and P.dither(xx, yy, 0.3):
				var col2 := im.get_pixel(xx, yy)
				im.set_pixel(xx, yy, col2.lightened(0.12))
	P.rect(im, seam_x - 1, 0, 4, h, c.seam)
	P.rect(im, seam_x - 2, 0, 1, h, tone(c, 3.8))
	P.rect(im, seam_x + 3, 0, 1, h, c.deep)


## Big flakes standing off the face: a tapered lit plate with a dark gap
## behind it, leaning a little.
static func _flakes(im: Image, c: Dictionary, rng: RandomNumberGenerator, state: ClimbState) -> void:
	var top := state.top_row
	for r in range(1, top, 3):
		var cols: Array = state.holds.get(r, {}).keys()
		if cols.is_empty():
			continue
		var cc: int = cols[0]
		var p := L.wall_px(top, r, cc)
		_flake_shape(im, c, int(p.x) - 6, int(p.y) + 26, rng.randi_range(56, 92), rng.randi_range(8, 13), rng.randf_range(-0.12, 0.12))


static func _flake_shape(im: Image, c: Dictionary, x: int, bottom_y: int, height: int, max_w: int, lean: float) -> void:
	var w_main := maxi(int(max_w * 0.6), 4)
	for k in height:
		var t := float(k) / height
		# Square body, pointed ends.
		var taper := minf(minf(t, 1.0 - t) * 7.0, 1.0)
		var half := maxi(int(w_main * (0.35 + 0.65 * taper)), 1)
		var cx := x + int(lean * (height - k))
		var y := bottom_y - k
		P.rect(im, cx - half - 1, y, half * 2 + 4, 1, c.seam)
		P.rect(im, cx - half, y, half * 2 + 1, 1, tone(c, 2.5))
		P.rect(im, cx - half, y, mini(2, half + 1), 1, tone(c, 3.6))
		P.rect(im, cx + half - 1, y, 2, 1, tone(c, 1.6))
		P.px(im, cx + half + 1, y, c.deep)
		P.px(im, cx + half + 2, y, c.deep)
	var tx := x + int(lean * height)
	P.rect(im, tx - 2, bottom_y - height, 5, 1, tone(c, 3.9))


## The dike: a ribbon of different rock snaking up the face, following the
## line the holds make, drawn as a smooth curve with ragged, lit edges.
static func _dike(im: Image, c: Dictionary, rng: RandomNumberGenerator, state: ClimbState) -> void:
	var top := state.top_row
	var xs := PackedFloat32Array()
	var ys := PackedFloat32Array()
	var p0 := L.wall_px(top, 0, 2)
	xs.append(p0.x)
	ys.append(p0.y + 70)
	for r in range(1, top):
		for cc: int in state.holds[r].keys():
			if state.holds[r][cc].get("dike", false):
				var p := L.wall_px(top, r, cc)
				xs.append(p.x)
				ys.append(p.y)
				break
	var pt := L.wall_px(top, top, 2)
	xs.append(pt.x)
	ys.append(pt.y - 100)
	var dark: Color = c.deep.lerp(c.shade, 0.45)
	var mid := tone(c, 1.2)
	var lit := tone(c, 2.6)
	var y_start := int(ys[ys.size() - 1])
	var y_end := int(ys[0])
	for y in range(y_start, y_end):
		# Find the segment this y falls in and ease between its points.
		var seg := 0
		for i in range(ys.size() - 1):
			if y <= ys[i] and y >= ys[i + 1]:
				seg = i
				break
		var t := inverse_lerp(ys[seg], ys[seg + 1], float(y))
		t = t * t * (3.0 - 2.0 * t)
		var x := lerpf(xs[seg], xs[seg + 1], t) + sin(y * 0.05) * 2.0
		var wobble := int(P.noise(y / 3, 0, 4) * 3.0)
		var half := 5 + wobble
		P.rect(im, int(x) - half - 1, y, half * 2 + 3, 1, c.seam)
		P.rect(im, int(x) - half, y, half * 2 + 1, 1, dark)
		P.rect(im, int(x) - half, y, 2, 1, mid)
		P.px(im, int(x) - half, y, lit)
		P.rect(im, int(x) + half - 2, y, 2, 1, c.deep)
		if P.noise(int(x), y, 8) < 0.12:
			P.px(im, int(x) + int(P.noise(y, 3, 8) * 6.0) - 3, y, mid)


## Round granite knobs of feldspar standing out of the face, in loose
## clusters (decoration; the holds are drawn as bigger knobs on top).
static func _knobs(im: Image, c: Dictionary, rng: RandomNumberGenerator) -> void:
	var w := im.get_width()
	var h := im.get_height()
	for k in w * h / 5200:
		var cx := rng.randi_range(8, w - 40)
		var cy := rng.randi_range(8, h - 8)
		for i in rng.randi_range(2, 5):
			var x := cx + rng.randi_range(-12, 12)
			var y := cy + rng.randi_range(-9, 9)
			var r := rng.randi_range(2, 4)
			P.ellipse(im, x + 1, y + 2, r + 1, r * 0.7 + 1, c.seam)
			P.shaded_ellipse(im, x, y, r, r * 0.7, tone(c, 2.9), tone(c, 4.1), tone(c, 1.6))
	# Salt-and-pepper crystals of the coarse porphyritic granite.
	for i in w * h / 55:
		var p := Vector2i(rng.randi_range(0, w - 1), rng.randi_range(0, h - 1))
		var col := im.get_pixelv(p)
		im.set_pixelv(p, col.lightened(0.22) if rng.randf() < 0.5 else col.darkened(0.28))


# ---------------------------------------------------------------- chimney

## Two walls close together, a dark slot between them, daylight at the top.
static func _chimney(im: Image, c: Dictionary, rng: RandomNumberGenerator, deco: Array, state: ClimbState) -> Dictionary:
	var w := im.get_width()
	var h := im.get_height()
	var left := int(L.CHIMNEY_X) - L.CHIMNEY_HALF
	var right := int(L.CHIMNEY_X) + L.CHIMNEY_HALF
	# Both walls are ordinary granite; the right-hand one is in shadow.
	_face(im, c, rng, "crack", deco, state, "dark")
	for yy in h:
		for xx in range(right, w):
			if P.dither(xx, yy, 0.5) or xx < right + 3:
				im.set_pixel(xx, yy, im.get_pixel(xx, yy).darkened(0.22))
	# The slot: dark rock receding, with a pale seam of light far above.
	for yy in h:
		for xx in range(left, right):
			var depth := 1.0 - absf((xx - (left + right) * 0.5) / ((right - left) * 0.5))
			var t := 0.2 + depth * 0.9 + P.smooth_noise(xx * 0.2, yy * 0.05, 2) * 0.5
			var q := roundi((t + (P.BAYER[yy & 3][xx & 3] / 16.0 - 0.5) * 0.4) * 2.0) / 2.0
			im.set_pixel(xx, yy, tone(c, clampf(q, 0.0, 3.0)))
	# The lips of each wall, lit on the left wall's edge, and a shadow cast
	# into the slot.
	P.rect(im, left - 3, 0, 3, h, tone(c, 3.9))
	P.rect(im, left, 0, 2, h, c.seam)
	P.rect(im, left + 2, 0, 3, h, Color(0, 0, 0, 0.25))
	P.rect(im, right - 2, 0, 2, h, c.seam)
	P.rect(im, right, 0, 1, h, c.seam)
	P.rect(im, right + 1, 0, 1, h, tone(c, 2.4))
	_stains(im, c, rng, deco)
	var edge := _ragged_edge(im, c, rng, false)
	return {"edge": edge, "gap": Rect2i(left, 0, right - left, h)}


static func _face_into(im: Image, c: Dictionary, rng: RandomNumberGenerator, r: Rect2i, base_tone: float, side: int) -> void:
	var y := r.position.y
	while y < r.end.y:
		var bh := rng.randi_range(46, 120)
		var t := base_tone + rng.randf_range(-0.4, 0.4)
		im.fill_rect(Rect2i(r.position.x, y, r.size.x, mini(bh, r.end.y - y)), tone(c, t))
		im.fill_rect(Rect2i(r.position.x, y, r.size.x, 1), c.seam)
		im.fill_rect(Rect2i(r.position.x, y + 1, r.size.x, 1), tone(c, t + 0.9))
		y += bh
	for yy in range(r.position.y, r.end.y):
		for xx in range(r.position.x, r.end.x):
			if P.noise(xx, yy, 5) < 0.06:
				var col := im.get_pixel(xx, yy)
				im.set_pixel(xx, yy, col.lightened(0.15) if P.noise(xx, yy, 6) > 0.5 else col.darkened(0.2))


# ---------------------------------------------------------------- glacier

## Snow and ice, lit like the rock: broad sastrugi and sun cups for snow,
## bubbled blue ice with white fractures, crevasses with snow bridges.
static func _glacier(im: Image, c: Dictionary, rng: RandomNumberGenerator, style: String, deco: Array, state: ClimbState) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var snow := style == "snow"
	var relief := _relief(w, h, rng.randi(), true)
	var lut := _packed_tones(c)
	var out := PackedByteArray()
	out.resize(w * h * 4)
	# Per-input terms worked out once, as in _face().
	var light := _scaled_diffs(0.7)
	var height := PackedFloat64Array()
	height.resize(256)
	for v in 256:
		height[v] = (v / 255.0 - 0.5) * 0.7
	var across := PackedFloat64Array()
	across.resize(w)
	for x in w:
		across[x] = (float(x) / w - 0.5) * 0.5
	var bayer := _bayer_terms(0.14)
	var base := 2.1 if snow else 1.7
	var band_k := 0.8 if snow else 0.35
	var light_k := 1.0 if snow else 1.2
	for y in h:
		var brow := (y & 3) << 2
		for x in w:
			var i := y * w + x
			var here := relief[i]
			var xl := relief[i - 3] if x > 2 else here
			var xr := relief[i + 3] if x < w - 3 else here
			var yu := relief[i - 3 * w] if y > 2 else here
			var yd := relief[i + 3 * w] if y < h - 3 else here
			var s_light := (light[xl - xr + 255] + light[yu - yd + 255]) / 255.0 * 4.0
			# Broad blue-white bands across the face, so it reads as layered snow
			# and ice rather than a white sheet.
			var band := sin(y * 0.05 + sin(x * 0.018 + y * 0.004) * 1.6) * band_k
			var t := base + band + s_light * light_k + height[here] + across[x]
			out.encode_u32(i * 4, lut[clampi(roundi((t + bayer[brow | (x & 3)]) * 3.0) * 4 / 3, 0, 19)])
	im.set_data(w, h, false, Image.FORMAT_RGBA8, out)
	if not snow:
		# White fractures through the ice, and trapped air bubbles.
		for i in h / 24:
			var x := float(rng.randi_range(8, w - 50))
			var y := rng.randi_range(0, h)
			for k in rng.randi_range(14, 44):
				x += rng.randf_range(-1.4, 1.8)
				y += rng.randi_range(0, 1) - (1 if rng.randf() < 0.2 else 0)
				P.px(im, int(x), y, tone(c, 4.6))
				if k % 4 == 0:
					P.px(im, int(x) + 1, y + 1, tone(c, 1.0))
		for i in w * h / 4200:
			var p := Vector2i(rng.randi_range(2, w - 32), rng.randi_range(2, h - 2))
			P.ellipse(im, p.x, p.y, 1.5, 1.0, tone(c, 4.4))
	else:
		# Sun cups and wind ridges.
		for i in w * h / 900:
			var x := rng.randi_range(4, w - 30)
			var y := rng.randi_range(4, h - 4)
			var r := rng.randi_range(3, 6)
			P.ellipse(im, x, y, r, r * 0.5, tone(c, 2.8))
			P.hline(im, x - r + 1, y - 1, r * 2 - 2, tone(c, 2.3))
			P.hline(im, x - r + 1, y + 1, r * 2 - 2, tone(c, 4.4))
		for i in h / 36:
			var y := rng.randi_range(0, h - 4)
			var x0 := rng.randi_range(0, w - 90)
			for k in rng.randi_range(30, 90):
				P.px(im, x0 + k, y + int(sin(k * 0.12 + i) * 2.0), tone(c, 4.4))
	# A few crevasse lines: thin blue cracks wandering across the face.
	for i in maxi(h / 240, 2):
		var x := rng.randi_range(0, w - 120)
		var y := rng.randi_range(8, h - 8)
		var phase := rng.randf_range(0.0, 6.0)
		for k in rng.randi_range(60, 150):
			var yy := y + int(sin(k * 0.05 + phase) * 3.0 + k * 0.04)
			P.px(im, x + k, yy, tone(c, 0.9))
			P.px(im, x + k, yy + 1, tone(c, 4.2))
			if k % 7 == 0:
				P.px(im, x + k, yy - 1, tone(c, 1.6))
	if "moraine" in deco:
		# Rubble from the rock above, in drifts at the foot of the snow, with a
		# lit top to each stone.
		var rock := Color("6a6a70").lerp(c.tint, 0.2)
		for i in w * 150 / 1100:
			var x := rng.randi_range(4, w - 30)
			var y := rng.randi_range(h - 150, h - 4)
			var sw := rng.randi_range(2, 5)
			var sh := rng.randi_range(2, 3)
			P.rect(im, x, y, sw, sh, rock)
			P.rect(im, x, y, sw, 1, rock.lightened(0.3))
			P.rect(im, x, y + sh, sw, 1, rock.darkened(0.3))
	if "crevasse" in deco:
		var top := state.top_row
		for r in range(1, top):
			if r % 3 == 0:
				var p := L.wall_px(top, r, 2)
				var gx := int(p.x) - 86
				var gy := int(p.y) - 5
				# A curved slot, blue in the depths, with a lit upper lip.
				for k in 172:
					var arc := int(sin(k * 0.027 + r) * 3.0)
					var depth_t := sin(float(k) / 172.0 * PI)
					var hh := 3 + int(depth_t * 6.0)
					P.rect(im, gx + k, gy + arc - 1, 1, hh + 2, c.seam)
					P.rect(im, gx + k, gy + arc, 1, hh, tone(c, 0.3 + depth_t * 0.6))
					P.px(im, gx + k, gy + arc - 2, tone(c, 4.6))
					if k % 5 == 0:
						P.px(im, gx + k, gy + arc + hh, tone(c, 3.6))
				# The snow bridge carrying the line across.
				var bx := int(L.wall_px(top, r, state.holds[r].keys()[0]).x) - 12
				P.rect(im, bx, gy - 3, 24, 13, tone(c, 3.8))
				P.rect(im, bx, gy - 3, 24, 2, tone(c, 4.8))
				P.rect(im, bx, gy + 8, 24, 2, tone(c, 2.8))
				P.rect(im, bx - 1, gy - 3, 1, 13, c.seam)
				P.rect(im, bx + 24, gy - 3, 1, 13, c.seam)


# ---------------------------------------------------------------- roof

## A roof pitch, side-on: the cliff on the left, a ceiling jutting out to the
## right with its crack, the lip, a ledge above it, and the belay ledge under
## the start. Returns {"image", "lip_x", ...}.
static func paint_roof(state: ClimbState, rock_key: String, pal: Dictionary, seed_value: int) -> Dictionary:
	var top := state.top_row
	var w := L.roof_width(top)
	var h := int(L.SCREEN.y)
	var c := colors(rock_key, pal)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var im := P.make(w, h)
	var relief := _relief(w, h, rng.randi(), false)
	var wall_x := int(L.roof_px(top, 0, 2).x) - 26
	var lip_x := int(L.roof_px(top, top - 1, 2).x) + 14
	var shelf_top := int(L.ROOF_Y - L.ROOF_TOP_LIFT) - 2
	var lut: Array[Color] = []
	for i in 20:
		lut.append(tone(c, i * 0.25))
	var mask := PackedByteArray()
	mask.resize(w * h)
	for y in h:
		for x in w:
			var under := int(L.ROOF_Y + 14 + sin(x * 0.07) * 2.0 + P.noise(x / 3, 0, 2) * 3.0)
			var inside := false
			var depth_under := 0
			if x < wall_x:
				inside = true
			elif x < lip_x:
				inside = y < under
				depth_under = under - y
			elif x < lip_x + 120:
				# Beyond the lip: a shelf, thinner, stepped up.
				inside = y >= shelf_top and y < under - 22 + (x - lip_x) / 4
			if not inside:
				continue
			var i := y * w + x
			mask[i] = 1
			var xl := relief[i - 3] if x > 2 else relief[i]
			var xr := relief[i + 3] if x < w - 3 else relief[i]
			var yu := relief[i - 3 * w] if y > 2 else relief[i]
			var yd := relief[i + 3 * w] if y < h - 3 else relief[i]
			var s_light := ((xl - xr) * 0.6 + (yu - yd) * 0.7) / 255.0 * 4.0
			var t := 1.9 + s_light * 1.2 + (relief[i] / 255.0 - 0.5) * 1.0
			# The underside of a roof sits in shade.
			if x >= wall_x and x < lip_x and depth_under < 22:
				t -= (22 - depth_under) * 0.045
			var bay: float = P.BAYER[y & 3][x & 3] / 16.0 - 0.5
			im.set_pixel(x, y, lut[clampi(roundi((t + bay * 0.16) * 3.0) * 4 / 3, 0, 19)])
	# The edge of the rock: a dark outline, and a lit rim on the lip and shelf.
	for x in range(wall_x, w):
		var under := int(L.ROOF_Y + 14 + sin(x * 0.07) * 2.0 + P.noise(x / 3, 0, 2) * 3.0)
		if x < lip_x:
			P.rect(im, x, under, 1, 1, c.seam)
			P.px(im, x, under - 1, c.deep)
		elif x < lip_x + 120:
			var sh_under := under - 22 + (x - lip_x) / 4
			P.px(im, x, sh_under, c.seam)
			P.px(im, x, shelf_top, tone(c, 4.0))
			P.px(im, x, shelf_top + 1, tone(c, 3.4))
			P.px(im, x, shelf_top - 1, c.seam)
	# The cliff face on the left: lit edge, and the ledge you belay from.
	P.rect(im, wall_x - 2, 0, 2, h, c.seam)
	P.rect(im, wall_x - 4, 0, 2, h, tone(c, 3.8))
	_stains(im, c, rng, ["streaks"])
	_lichen(im, c, rng, ["lichen"], h)
	# Stains and lichen only belong on rock.
	var data := im.get_data()
	for i in w * h:
		if mask[i] == 0:
			data.encode_u32(i * 4, 0)
	im.set_data(w, h, false, Image.FORMAT_RGBA8, data)
	var ledge_y := int(L.ROOF_Y) + 62
	_ledge(im, c, rng, ledge_y, wall_x + 74, false, "crack")
	# The crack along the ceiling: a dark slit with a lit lip below.
	var x0 := int(L.roof_px(top, 0, 2).x)
	var x1 := int(L.roof_px(top, top - 1, 2).x)
	for x in range(x0, x1 + 8):
		var yy := int(L.ROOF_Y) + int(sin(x * 0.11) * 1.0)
		P.px(im, x, yy - 2, c.seam)
		P.px(im, x, yy - 1, c.deep)
		P.px(im, x, yy, c.deep)
		P.px(im, x, yy + 1, tone(c, 3.7))
		P.px(im, x, yy + 2, c.seam if x % 3 == 0 else tone(c, 1.5))
	# Holds along it, and chalk where the crux is.
	for r in range(1, top):
		for col: int in state.holds.get(r, {}):
			var p := Vector2i(L.roof_px(top, r, col))
			var hold: Dictionary = state.holds[r][col]
			P.rect(im, p.x - 3, p.y + 4, 7, 2, tone(c, 3.4))
			P.rect(im, p.x - 3, p.y + 6, 7, 1, c.deep)
			if hold.get("crux", false):
				for i in 5:
					P.px(im, p.x + rng.randi_range(-4, 4), p.y + rng.randi_range(2, 8), c.chalk)
	return {"image": im, "lip_x": lip_x, "ledge_y": ledge_y + 1, "wall_x": wall_x, "shelf_top": shelf_top}


# ---------------------------------------------------------------- holds

static func _paint_holds(im: Image, c: Dictionary, rng: RandomNumberGenerator, state: ClimbState, style: String, edge: PackedInt32Array) -> void:
	var top := state.top_row
	var w := im.get_width()
	# Belay ledges at the bottom and the top of the pitch.
	for r in [0, top]:
		var p := L.wall_px(top, r, 0)
		var y := int(p.y) + 7
		var e := w
		if y >= 0 and y < edge.size():
			e = edge[y] + 4
		_ledge(im, c, rng, y, e, r == top, style)
	if style == "chimney":
		# Footholds on alternating walls, one per row, and the odd chockstone.
		var lx := int(L.CHIMNEY_X) - L.CHIMNEY_HALF
		var rx := int(L.CHIMNEY_X) + L.CHIMNEY_HALF
		for r in range(1, top):
			var y := int(L.wall_px(top, r, 0).y)
			if r % 2 == 0:
				P.rect(im, lx, y, 6, 2, tone(c, 3.6))
				P.rect(im, lx, y + 2, 6, 1, c.deep)
			else:
				P.rect(im, rx - 5, y, 6, 2, tone(c, 3.0))
				P.rect(im, rx - 5, y + 2, 6, 1, c.deep)
			if state.holds[r].values().any(func(hd): return hd.get("crux", false)):
				for i in 6:
					P.px(im, int(L.CHIMNEY_X) + rng.randi_range(-10, 10), y + rng.randi_range(-4, 4), c.chalk)
		return
	var base := 2 + int(state.spec.diff) + 1
	for r in range(1, top):
		for col: int in state.holds.get(r, {}):
			var hold: Dictionary = state.holds[r][col]
			var p := Vector2i(L.wall_px(top, r, col))
			_hold(im, c, rng, p, hold, base, style)
	# Cracks join up where two crack holds are within reach.
	if style != "snow" and style != "ice":
		for r in range(1, top - 1):
			for col: int in state.holds.get(r, {}):
				if not state.holds[r][col].crack:
					continue
				for dx in [-1, 0, 1]:
					if state.holds.get(r + 1, {}).get(col + dx, {}).get("crack", false):
						var a := L.wall_px(top, r, col)
						var b := L.wall_px(top, r + 1, col + dx)
						_crack_line(im, c, a + Vector2(3, -9), b + Vector2(3, 9))
						break


## A crack running from [param a] to [param b]: meandering, a dark core, a lit
## lip on the left and a shaded one on the right, pinching at the ends.
static func _crack_line(im: Image, c: Dictionary, a: Vector2, b: Vector2) -> void:
	var steps := int(a.distance_to(b)) + 1
	for k in steps:
		var t := float(k) / steps
		var p := a.lerp(b, t)
		var x := int(p.x + sin(p.y * 0.21) * 1.0)
		var y := int(p.y)
		var wide := 1 + int(sin(t * PI) * 1.2)
		P.px(im, x - 1, y, tone(c, 4.0))
		P.rect(im, x, y, wide, 1, c.seam.darkened(0.2))
		P.px(im, x + wide, y, c.seam)
		P.px(im, x + wide + 1, y, tone(c, 1.9))


## A belay ledge: a rough shelf with a lit, uneven top, a chipped front, a dark
## underside, rubble and a tuft or two. At the top it carries the anchor.
static func _ledge(im: Image, c: Dictionary, rng: RandomNumberGenerator, y: int, e: int, is_top: bool, style: String) -> void:
	var top_col := tone(c, 3.6)
	var face := tone(c, 2.1)
	var low := tone(c, 1.3)
	if style == "snow" or style == "ice":
		top_col = tone(c, 4.5)
		face = tone(c, 3.2)
		low = tone(c, 2.2)
	for x in range(0, e):
		var jy := int(P.smooth_noise(x * 0.09, 1.0, 6) * 3.0)
		var thick := 5 + int(P.smooth_noise(x * 0.06, 4.0, 7) * 4.0)
		P.px(im, x, y + jy - 1, c.seam)
		P.px(im, x, y + jy, top_col)
		P.px(im, x, y + jy + 1, top_col.darkened(0.08))
		P.rect(im, x, y + jy + 2, 1, thick - 2, face)
		P.px(im, x, y + jy + 2, tone(c, 3.0))
		P.px(im, x, y + jy + thick, low)
		P.px(im, x, y + jy + thick + 1, c.deep)
		P.px(im, x, y + jy + thick + 2, Color(0, 0, 0, 0.3))
		if P.noise(x, 3, 9) < 0.06:
			P.px(im, x, y + jy + 3, c.seam)
	for i in 5:
		var x := rng.randi_range(4, maxi(e - 10, 6))
		P.rect(im, x, y - 2, rng.randi_range(2, 3), 2, tone(c, 2.6))
		P.px(im, x, y - 2, tone(c, 3.6))
	if is_top:
		# Anchor bolts with a shiny chain.
		for i in 2:
			var bx := int(L.GRID_X + 1.6 * L.COL_W) + i * 26
			P.rect(im, bx, y - 3, 3, 3, Color("c8ccd4"))
			P.px(im, bx, y - 3, Color("f4f6fa"))
			P.px(im, bx + 1, y - 1, Color("505868"))


static func _hold(im: Image, c: Dictionary, rng: RandomNumberGenerator, p: Vector2i, hold: Dictionary, base: int, style: String) -> void:
	var cost: int = hold.cost
	var hard: bool = hold.get("hard", false)
	var easy := cost <= base
	if style == "snow" or style == "ice":
		# A kicked step in the snow, or a chipped hold in the ice.
		var col := tone(c, 1.6)
		P.rect(im, p.x - 4, p.y - 1, 9, 3, col)
		P.rect(im, p.x - 4, p.y - 1, 9, 1, c.deep)
		P.rect(im, p.x - 3, p.y + 2, 7, 1, tone(c, 4.4))
		if style == "ice":
			P.px(im, p.x - 2, p.y, tone(c, 4.8))
			P.px(im, p.x + 2, p.y + 1, tone(c, 4.8))
		return
	if hold.crack:
		_crack_line(im, c, Vector2(p.x + 3, p.y - 12), Vector2(p.x + 3, p.y + 12))
	var chalk: Color = c.chalk
	match style:
		"knobs":
			var r := 3 if easy else 2
			P.ellipse(im, p.x, p.y + 1, r + 1, r * 0.8 + 1, c.seam)
			P.shaded_ellipse(im, p.x, p.y, r + 0.5, r * 0.8 + 0.5, tone(c, 3.0), tone(c, 4.2), tone(c, 1.8))
			P.px(im, p.x - 1, p.y - 1, chalk)
		"slab", "dike":
			# Smear marks: a lit edge with its shadow under it, and a chalky
			# smudge over it where hands have been, big enough to read at a
			# glance.
			P.rect(im, p.x - 3, p.y, 7, 1, tone(c, 4.7))
			P.rect(im, p.x - 3, p.y + 1, 7, 1, c.seam)
			P.rect(im, p.x - 2, p.y + 2, 5, 1, c.seam.lerp(tone(c, 2.0), 0.5))
			if not hard:
				P.rect(im, p.x - 2, p.y - 1, 4, 1, chalk)
				P.px(im, p.x + 2, p.y - 1, chalk.darkened(0.1))
				P.px(im, p.x - 1, p.y - 2, chalk.darkened(0.15))
			if easy:
				P.rect(im, p.x - 4, p.y, 9, 1, tone(c, 4.2))
				P.px(im, p.x - 4, p.y + 1, c.seam)
				P.px(im, p.x + 4, p.y + 1, c.seam)
		_:
			if easy:
				P.rect(im, p.x - 3, p.y - 1, 6, 3, tone(c, 3.8))
				P.rect(im, p.x - 2, p.y - 2, 4, 1, chalk)
				P.rect(im, p.x - 3, p.y - 1, 6, 1, tone(c, 4.6))
				P.rect(im, p.x - 3, p.y + 2, 6, 1, c.seam)
			elif hard:
				P.rect(im, p.x - 1, p.y - 1, 3, 2, tone(c, 3.3))
				P.rect(im, p.x - 1, p.y - 1, 3, 1, tone(c, 4.3))
				P.rect(im, p.x - 1, p.y + 1, 3, 1, c.seam)
				P.px(im, p.x, p.y - 2, chalk)
			else:
				P.rect(im, p.x - 2, p.y - 1, 5, 2, tone(c, 3.8))
				P.rect(im, p.x - 1, p.y - 2, 3, 1, chalk)
				P.rect(im, p.x - 2, p.y - 1, 5, 1, tone(c, 4.6))
				P.rect(im, p.x - 2, p.y + 1, 5, 1, c.seam)
	if hold.get("rest", false):
		# A good stance: a flat shelf you can stand on.
		P.rect(im, p.x - 10, p.y + 4, 21, 2, tone(c, 3.8))
		P.rect(im, p.x - 10, p.y + 6, 21, 2, c.seam)
	if hold.get("fixed", false):
		P.rect(im, p.x - 9, p.y - 3, 2, 8, Color("e8c040"))
		P.rect(im, p.x - 9, p.y - 3, 1, 8, Color("f8e080"))
	if hold.get("crux", false):
		# A chalky scar where everybody pulls.
		for i in 6:
			P.px(im, p.x + rng.randi_range(-4, 4), p.y + rng.randi_range(-3, 3), chalk)
