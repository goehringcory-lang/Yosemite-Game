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
	"apron": ["5f5a62", "807a80", "a29c98", "c8c0b2", "e8dfca"],
	"polished": ["58606a", "7a828c", "9ea2a8", "c4c6c4", "e6e4da"],
	"golden": ["62503e", "86705a", "b09a78", "d6c094", "f0e0b0"],
	"orange": ["63483a", "8a6a54", "b08c6a", "d6b088", "f0d0a0"],
	"dark": ["2e3040", "4c4e5e", "70727e", "9a9caa", "c4c6d0"],
	"pale": ["6a6460", "948c84", "bcb4a6", "e0d6c0", "f4ecd8"],
	"roof": ["34323e", "504e5a", "6e6c78", "908e98", "b4b2bc"],
	"elcap": ["4a4a52", "74747a", "a2a2a2", "c8c8c4", "e6e4da"],
	"arches": ["58545a", "7c7880", "9c9892", "c6bea8", "e6dcc0"],
	"dome": ["6e6a68", "98948e", "bcb8b0", "dcd8cc", "f2eee0"],
	"knobby": ["5a5448", "84806e", "b0aa98", "d4ccb4", "eee6cc"],
	"ice": ["5a7ab0", "86a6d0", "b8d0e8", "dceaf6", "f6fbff"],
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
	return result


# ---------------------------------------------------------------- the face

## The face: a relief map (stretched noise plus jointed plates) lit from the
## upper left, quantized to a few tones with ordered dither, then joints,
## stains, lichen and speckle on top.
static func _face(im: Image, c: Dictionary, rng: RandomNumberGenerator, style: String, deco: Array, state: ClimbState, rock_key: String) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var smooth := style == "slab" or style == "dike" or rock_key == "polished" or rock_key == "dome"
	var relief := _relief(w, h, rng.randi(), smooth)
	var lut: Array[Color] = []
	for i in 20:
		lut.append(tone(c, i * 0.25))
	var out := PackedByteArray()
	out.resize(w * h * 4)
	var k_light := 1.15 if not smooth else 0.8
	for y in h:
		var row := y * w
		for x in w:
			var i := row + x
			var xl := relief[i - 1] if x > 0 else relief[i]
			var xr := relief[i + 1] if x < w - 1 else relief[i]
			var yu := relief[i - w] if y > 0 else relief[i]
			var yd := relief[i + w] if y < h - 1 else relief[i]
			# Light from the upper left: surfaces facing left and up are lit.
			var s_light := ((xl - xr) * 0.8 + (yu - yd) * 0.55) / 255.0 * 6.0
			var sun := float(x) / w
			var t := 2.0 + s_light * k_light + (sun - 0.5) * 0.9 + (relief[i] / 255.0 - 0.5) * 0.9
			var bay: float = P.BAYER[y & 3][x & 3] / 16.0 - 0.5
			var idx := clampi(roundi((t + bay * 0.35) * 4.0), 0, 19)
			var col: Color = lut[idx]
			var o := i * 4
			out[o] = int(col.r8)
			out[o + 1] = int(col.g8)
			out[o + 2] = int(col.b8)
			out[o + 3] = 255
	im.set_data(w, h, false, Image.FORMAT_RGBA8, out)
	_joints(im, c, rng, smooth)
	_stains(im, c, rng, deco)
	_lichen(im, c, rng, deco, h)
	# Speckles: feldspar glints and dark crystals.
	for i in w * h / 90:
		var p := Vector2i(rng.randi_range(0, w - 1), rng.randi_range(0, h - 1))
		var col := im.get_pixelv(p)
		im.set_pixelv(p, col.lightened(0.14) if rng.randf() < 0.55 else col.darkened(0.18))


## A height map, 0..255 per pixel: fluted noise plus plates cut by joints.
static func _relief(w: int, h: int, seed_value: int, smooth: bool) -> PackedByteArray:
	var fbm := FastNoiseLite.new()
	fbm.seed = seed_value
	fbm.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fbm.frequency = 0.035 if not smooth else 0.02
	fbm.fractal_octaves = 4
	fbm.fractal_gain = 0.55
	var squash := 3 if not smooth else 2
	var a := fbm.get_image(w, maxi(h / squash, 8), false, false, true)
	a.resize(w, h, Image.INTERPOLATE_BILINEAR)
	var cells := FastNoiseLite.new()
	cells.seed = seed_value + 7
	cells.noise_type = FastNoiseLite.TYPE_CELLULAR
	cells.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	cells.cellular_jitter = 0.9
	cells.frequency = 0.016 if not smooth else 0.009
	cells.domain_warp_enabled = true
	cells.domain_warp_amplitude = 18.0
	cells.domain_warp_frequency = 0.02
	var b := cells.get_image(w, h, false, false, true)
	var da := a.get_data()
	var db := b.get_data()
	var out := PackedByteArray()
	out.resize(w * h)
	var wa := 0.62 if not smooth else 0.5
	for i in w * h:
		out[i] = int(da[i] * wa + db[i] * (1.0 - wa) * 0.7)
	return out


## Long hairline joints, wandering a little, with a lit lip on one side.
static func _joints(im: Image, c: Dictionary, rng: RandomNumberGenerator, smooth: bool) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var count := w / (60 if smooth else 34)
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
			im.set_pixel(xx - 1, yy, im.get_pixel(xx - 1, yy).lightened(0.12))
			if (k & 1) == 0:
				im.set_pixel(xx + 1, yy, im.get_pixel(xx + 1, yy).darkened(0.12))


## Dark water stains running down the rock, thin and dithered at the edges.
static func _stains(im: Image, c: Dictionary, rng: RandomNumberGenerator, deco: Array) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var heavy := "streaks" in deco
	var count := (w / 26 if heavy else w / 80)
	for i in count:
		var x := rng.randi_range(6, w - 40)
		var y := rng.randi_range(0, h - 120)
		var length := rng.randi_range(70, 240)
		var sw := rng.randi_range(1, 3)
		for k in length:
			var yy := y + k
			if yy >= h:
				break
			var drift := int(sin(k * 0.05 + i) * 1.4)
			var fade := 1.0 - float(k) / length
			for dx in range(-sw, sw + 1):
				var edge := absi(dx) == sw
				if edge and not P.dither(x + dx, yy, fade * 0.7):
					continue
				if not edge or P.dither(x + dx, yy, fade):
					var p := Vector2i(x + dx + drift, yy)
					if p.x >= 0 and p.x < w:
						im.set_pixelv(p, im.get_pixelv(p).lerp(c.streak, 0.55 * fade + 0.15))


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


## Big flakes standing off the face: a lit plate with a dark gap behind it.
static func _flakes(im: Image, c: Dictionary, rng: RandomNumberGenerator, state: ClimbState) -> void:
	var top := state.top_row
	for r in range(1, top, 3):
		var cols: Array = state.holds.get(r, {}).keys()
		if cols.is_empty():
			continue
		var cc: int = cols[0]
		var p := L.wall_px(top, r, cc)
		var fx := int(p.x) - 8
		var fy := int(p.y) - 30
		var fh := rng.randi_range(46, 80)
		var fw := rng.randi_range(8, 14)
		P.rect(im, fx - 1, fy, fw + 3, fh, c.seam)
		P.rect(im, fx, fy, fw, fh, tone(c, 2.9))
		P.rect(im, fx, fy, 2, fh, tone(c, 3.9))
		P.rect(im, fx + fw - 2, fy, 2, fh, tone(c, 1.8))
		P.rect(im, fx + fw + 1, fy + 2, 2, fh - 2, c.deep)
		P.hline(im, fx, fy, fw, tone(c, 4.0))


## The dike: a pale or dark ribbon of different rock snaking up the face,
## following the line the holds make.
static func _dike(im: Image, c: Dictionary, rng: RandomNumberGenerator, state: ClimbState) -> void:
	var top := state.top_row
	var pts: Array[Vector2] = []
	pts.append(L.wall_px(top, 0, 2) + Vector2(0, 40))
	for r in range(1, top):
		var cols: Array = state.holds[r].keys()
		for cc: int in cols:
			if state.holds[r][cc].get("dike", false):
				pts.append(L.wall_px(top, r, cc))
				break
	pts.append(L.wall_px(top, top, 2) + Vector2(0, -60))
	# Interpolate x for every y between points.
	var dark: Color = c.deep.lerp(c.shade, 0.35)
	var lit := tone(c, 1.3)
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var steps := int(absf(a.y - b.y)) + 1
		for k in steps:
			var t := float(k) / steps
			var p := a.lerp(b, t)
			var wob := sin(p.y * 0.07) * 1.5
			var x := int(p.x + wob)
			P.rect(im, x - 4, int(p.y), 9, 1, dark)
			P.px(im, x - 5, int(p.y), c.seam)
			P.px(im, x + 5, int(p.y), c.seam)
			P.px(im, x - 3, int(p.y), lit)
			if (int(p.y) + x) % 5 == 0:
				P.px(im, x + 1, int(p.y), tone(c, 1.0))


## Round granite knobs of feldspar scattered over the face (decoration; the
## holds are drawn as bigger knobs on top).
static func _knobs(im: Image, c: Dictionary, rng: RandomNumberGenerator) -> void:
	var w := im.get_width()
	var h := im.get_height()
	for i in w * h / 900:
		var x := rng.randi_range(4, w - 34)
		var y := rng.randi_range(4, h - 4)
		var r := rng.randi_range(2, 4)
		P.ellipse(im, x, y + 1, r + 1, r * 0.7 + 1, c.seam)
		P.shaded_ellipse(im, x, y, r, r * 0.7, tone(c, 2.9), tone(c, 4.0), tone(c, 1.5))


# ---------------------------------------------------------------- chimney

## Two walls close together, a dark slot between them, daylight at the top.
static func _chimney(im: Image, c: Dictionary, rng: RandomNumberGenerator, deco: Array, state: ClimbState) -> Dictionary:
	var w := im.get_width()
	var h := im.get_height()
	var left := int(L.GRID_X + 0.5 * L.COL_W) - 4
	var right := int(L.GRID_X + 3.5 * L.COL_W) + 4
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

static func _glacier(im: Image, c: Dictionary, rng: RandomNumberGenerator, style: String, deco: Array, state: ClimbState) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var snow := style == "snow"
	for yy in h:
		for xx in w:
			var n := P.smooth_noise(xx * 0.09, yy * 0.05, 3) + 0.5 * P.smooth_noise(xx * 0.23, yy * 0.17, 9)
			var t := 3.2 + (n - 0.75) * (1.1 if snow else 1.6)
			if not snow:
				t = 2.1 + (n - 0.75) * 1.6 + (xx / float(w) - 0.4) * 0.6
			im.set_pixel(xx, yy, tone(c, t))
	# Sun cups: little scoops in the snow, lit on one side.
	if snow:
		for i in w * h / 260:
			var x := rng.randi_range(4, w - 30)
			var y := rng.randi_range(4, h - 4)
			var r := rng.randi_range(3, 6)
			P.ellipse(im, x, y, r, r * 0.5, tone(c, 2.5))
			P.hline(im, x - r + 1, y + 1, r * 2 - 1, tone(c, 4.0))
			P.hline(im, x - r + 1, y - 1, r * 2 - 2, tone(c, 2.0))
	# Wind-sculpted ridges and blue ice windows.
	for i in h / 40:
		var y := rng.randi_range(0, h - 4)
		var x0 := rng.randi_range(0, w - 90)
		for k in rng.randi_range(30, 90):
			P.px(im, x0 + k, y + int(sin(k * 0.12 + i) * 2.0), tone(c, 4.1 if snow else 3.4))
	# Rubble blown onto the surface (moraine grit) and crevasses on the ice.
	if "moraine" in deco:
		for i in w * h / 700:
			var x := rng.randi_range(4, w - 30)
			var y := rng.randi_range(4, h - 4)
			P.rect(im, x, y, rng.randi_range(2, 4), rng.randi_range(1, 3), Color("6a6a70").lerp(c.tint, 0.2))
	if "crevasse" in deco:
		var top := state.top_row
		for r in range(1, top):
			if r % 3 == 0:
				var p := L.wall_px(top, r, 2)
				var gx := int(p.x) - 78
				var gy := int(p.y) - 4
				P.rect(im, gx, gy - 1, 160, 9, c.seam)
				P.rect(im, gx, gy, 160, 8, tone(c, 0.2))
				P.rect(im, gx + 6, gy + 2, 148, 5, c.deep)
				for k in 160:
					if (k + r) % 4 == 0:
						P.px(im, gx + k, gy - 1, tone(c, 4.4))
				# Icicles hanging in.
				for k in 12:
					P.vline(im, gx + 8 + k * 12, gy + 1, 2 + (k * 7 + r) % 3, tone(c, 3.6))
				# The bridge that carries the line across.
				var bx := int(L.wall_px(top, r, state.holds[r].keys()[0]).x) - 10
				P.rect(im, bx, gy - 2, 20, 12, tone(c, 3.8))
				P.rect(im, bx, gy - 2, 20, 1, tone(c, 4.6))
				P.rect(im, bx, gy + 9, 20, 1, tone(c, 2.6))


# ---------------------------------------------------------------- roof

## A roof pitch, side-on: the cliff on the left, a ceiling jutting out to the
## right with its crack, the lip, a ledge above it, and the belay ledge under
## the start. Returns {"image", "lip_x"}.
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
			var xl := relief[i - 1] if x > 0 else relief[i]
			var xr := relief[i + 1] if x < w - 1 else relief[i]
			var yu := relief[i - w] if y > 0 else relief[i]
			var yd := relief[i + w] if y < h - 1 else relief[i]
			var s_light := ((xl - xr) * 0.6 + (yu - yd) * 0.7) / 255.0 * 6.0
			var t := 1.9 + s_light * 1.0 + (relief[i] / 255.0 - 0.5) * 0.8
			# The underside of a roof sits in shade.
			if x >= wall_x and x < lip_x and depth_under < 22:
				t -= (22 - depth_under) * 0.045
			var bay: float = P.BAYER[y & 3][x & 3] / 16.0 - 0.5
			im.set_pixel(x, y, lut[clampi(roundi((t + bay * 0.35) * 4.0), 0, 19)])
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
	for y in h:
		P.px(im, lip_x + 120, y, Color(0, 0, 0, 0))
	# The cliff face on the left: lit edge, and the ledge you belay from.
	P.rect(im, wall_x - 2, 0, 2, h, c.seam)
	P.rect(im, wall_x - 4, 0, 2, h, tone(c, 3.8))
	var ledge_y := int(L.ROOF_Y) + 62
	P.rect(im, wall_x, ledge_y, 74, 3, tone(c, 3.6))
	P.rect(im, wall_x, ledge_y + 3, 74, 6, tone(c, 1.8))
	P.rect(im, wall_x, ledge_y + 9, 70, 2, c.deep)
	_stains(im, c, rng, ["streaks"])
	_lichen(im, c, rng, ["lichen"], h)
	# Stains and lichen only belong on rock.
	for y in h:
		for x in w:
			if mask[y * w + x] == 0:
				im.set_pixel(x, y, Color(0, 0, 0, 0))
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
	# Holds along it, and hanging stains.
	for r in range(1, top):
		for col: int in state.holds.get(r, {}):
			var p := Vector2i(L.roof_px(top, r, col))
			var hold: Dictionary = state.holds[r][col]
			P.rect(im, p.x - 3, p.y + 4, 7, 2, tone(c, 3.4))
			P.rect(im, p.x - 3, p.y + 6, 7, 1, c.deep)
			if hold.get("crux", false):
				for i in 5:
					P.px(im, p.x + rng.randi_range(-4, 4), p.y + rng.randi_range(2, 8), c.chalk)
	return {"image": im, "lip_x": lip_x, "ledge_y": ledge_y, "wall_x": wall_x, "shelf_top": shelf_top}


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


static func _crack_line(im: Image, c: Dictionary, a: Vector2, b: Vector2) -> void:
	var steps := int(a.distance_to(b)) + 1
	for k in steps:
		var p := a.lerp(b, float(k) / steps)
		var x := int(p.x)
		var y := int(p.y)
		P.px(im, x, y, c.deep)
		P.px(im, x - 1, y, tone(c, 3.6))
		P.px(im, x + 1, y, c.seam)


static func _ledge(im: Image, c: Dictionary, rng: RandomNumberGenerator, y: int, e: int, is_top: bool, style: String) -> void:
	var top_col := tone(c, 3.4)
	var face := tone(c, 1.8)
	if style == "snow" or style == "ice":
		top_col = tone(c, 4.4)
		face = tone(c, 3.0)
	# A shelf: lit top, thick front, dark underside and a shadow below.
	P.rect(im, 0, y, e, 2, top_col)
	P.rect(im, 0, y + 2, e, 4, face)
	P.rect(im, 0, y + 2, e, 1, tone(c, 3.0))
	P.rect(im, 0, y + 6, e - 3, 2, c.deep)
	P.rect(im, 0, y + 8, e - 5, 2, Color(0, 0, 0, 0.18))
	for i in 7:
		var x := rng.randi_range(2, maxi(e - 8, 4))
		P.rect(im, x, y + 2 + rng.randi_range(0, 3), 1, 1, c.seam)


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
		# A seam splitting the face: dark inside, a lit lip on the left.
		P.rect(im, p.x + 3, p.y - 11, 3, 22, c.seam)
		P.rect(im, p.x + 4, p.y - 10, 1, 20, c.deep)
		P.rect(im, p.x + 2, p.y - 11, 1, 22, tone(c, 3.8))
		P.rect(im, p.x + 6, p.y - 10, 1, 20, tone(c, 2.0))
	var chalk: Color = c.chalk
	match style:
		"knobs":
			var r := 3 if easy else 2
			P.ellipse(im, p.x, p.y + 1, r + 1, r * 0.8 + 1, c.seam)
			P.shaded_ellipse(im, p.x, p.y, r + 0.5, r * 0.8 + 0.5, tone(c, 3.0), tone(c, 4.2), tone(c, 1.8))
			P.px(im, p.x - 1, p.y - 1, chalk)
		"slab", "dike":
			# Smear marks: a tiny edge, a chalky smudge, a dimple.
			P.rect(im, p.x - 2, p.y, 5, 1, tone(c, 4.0))
			P.rect(im, p.x - 2, p.y + 1, 5, 1, c.deep)
			if not hard:
				P.px(im, p.x - 1, p.y - 1, chalk)
				P.px(im, p.x + 1, p.y - 1, chalk.darkened(0.1))
			if easy:
				P.rect(im, p.x - 3, p.y, 7, 1, tone(c, 4.2))
		_:
			if easy:
				P.rect(im, p.x - 3, p.y - 1, 6, 3, tone(c, 3.2))
				P.rect(im, p.x - 2, p.y - 2, 4, 1, chalk)
				P.rect(im, p.x - 3, p.y + 2, 6, 1, c.deep)
			elif hard:
				P.rect(im, p.x - 1, p.y - 1, 3, 2, tone(c, 3.0))
				P.rect(im, p.x - 1, p.y + 1, 3, 1, c.deep)
				P.px(im, p.x, p.y - 2, chalk)
			else:
				P.rect(im, p.x - 2, p.y - 1, 5, 2, tone(c, 3.2))
				P.rect(im, p.x - 1, p.y - 2, 3, 1, chalk)
				P.rect(im, p.x - 2, p.y + 1, 5, 1, c.deep)
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
