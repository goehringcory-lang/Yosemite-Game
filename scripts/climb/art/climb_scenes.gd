class_name ClimbScenes
extends RefCounted
## The two ends of a route, painted into the wall picture: the ground at the
## foot of the first pitch (Camp Curry's tent cabins, Camp 4's boulders and
## tents, El Capitan Meadow, the Ahwahnee's lawn, the moraine under Lyell...)
## and the summit above the last pitch (the Glacier Point rim, the Spire's
## pinnacle, the top of El Capitan...). Everything is lit by the time-of-day
## palette and painted with the light coming from the upper left.

const P := preload("res://scripts/climb/art/climb_paint.gd")
const L := preload("res://scripts/climb/art/climb_layout.gd")
const DARK := Color("2a1b14")
## Right limit of the ground (where the wall picture ends) for the current paint.
static var _xr := 296

const EARTH := {
	"curry": ["2a3420", "42562c", "5e7a3a", "88a850"],
	"camp4": ["3a3224", "5a4c34", "7a6a46", "9c8a5c"],
	"valley_forest": ["1e2a1c", "32482a", "4a6a36", "6e9444"],
	"bridalveil_talus": ["3a3630", "56524a", "76705e", "9a9276"],
	"mist_wall": ["202c2a", "344a42", "4c6a58", "6e9070"],
	"el_cap_meadow": ["44521e", "627a2c", "88a040", "b8c468"],
	"ahwahnee": ["24401e", "3a6428", "58903a", "82bc52"],
	"half_dome_forest": ["222e1e", "384a2a", "546c3a", "78964a"],
	"tuolumne": ["3e4a2c", "5e7036", "86964a", "b4bc6c"],
	"moraine": ["5c5e70", "7c7e92", "a2a6ba", "ccd0e0"],
}


static func _lit(col: Color, pal: Dictionary) -> Color:
	var tint: Color = pal.get("tint", Color.WHITE)
	var lum: float = pal.get("lum", 1.0)
	var t := col.lerp(Color(col.r * tint.r, col.g * tint.g, col.b * tint.b), 0.7)
	return Color(clampf(t.r * lum, 0, 1), clampf(t.g * lum, 0, 1), clampf(t.b * lum, 0, 1), col.a)


## A window's glass: sky-blue by day, lamp-yellow in the dark.
static func _glass(pal: Dictionary, hex := "ffd070") -> Color:
	var n := ClimbProps.night_amount(pal)
	return _lit(Color("3a86a8"), pal).lerp(ClimbProps.glow(hex, pal), clampf(n * 2.2, 0.0, 1.0))


## A pool of lamp light on the ground (only visible when it's dark).
static func _light_pool(im: Image, x: int, y: int, rx: float, pal: Dictionary, hex := "ffc860") -> void:
	var n := ClimbProps.night_amount(pal)
	if n < 0.08:
		return
	var col := Color(hex)
	P.ellipse(im, x, y, rx, rx * 0.32, Color(col.r, col.g, col.b, 0.1 * n))
	P.ellipse(im, x, y, rx * 0.6, rx * 0.2, Color(col.r, col.g, col.b, 0.14 * n))


static func _ramp(kind: String, pal: Dictionary) -> Array[Color]:
	var out: Array[Color] = []
	var ramp: Array = EARTH.get(kind, EARTH.valley_forest)
	for hx: String in ramp:
		out.append(_lit(Color(hx), pal))
	return out


## A horizontal strip of path or road between x0 and x1.
static func _band(im: Image, x0: int, x1: int, ya: int, hh: int, cols: Array[Color], rng: RandomNumberGenerator, wob: float, speck: int) -> void:
	for x in range(x0, x1):
		var o := int(roundf(sin(x * 0.05) * wob + sin(x * 0.13 + 2.0) * wob * 0.5))
		im.fill_rect(Rect2i(x, ya + o, 1, hh), cols[1])
		im.set_pixel(x, ya + o, cols[2])
		im.set_pixel(x, ya + o + hh - 1, cols[0])
	for i in speck:
		var x := rng.randi_range(x0, x1 - 1)
		var o := int(roundf(sin(x * 0.05) * wob + sin(x * 0.13 + 2.0) * wob * 0.5))
		P.px(im, x, ya + o + rng.randi_range(1, maxi(hh - 2, 1)), cols[rng.randi_range(0, 2)])


static func _stamp(im: Image, t: Image, x: int, y: int) -> void:
	P.outline(t, DARK)
	P.stamp(im, t, x, y)


# ------------------------------------------------------------------ the ground

## Paints the ground under the belay ledge of pitch one.
static func paint_base(im: Image, kind: String, state: ClimbState, pal: Dictionary, edge: PackedInt32Array, seed_value: int) -> void:
	if kind == "":
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 5
	var w := im.get_width()
	var y0 := int(L.wall_px(state.top_row, 0, 0).y) + 7
	_xr = mini(int(edge[mini(y0 + 20, edge.size() - 1)]) + 2, w - 1)
	var cols := _ramp(kind, pal)
	var rock_like: bool = kind in ["bridalveil_talus", "moraine"]
	var rkey := "apron"
	if kind == "moraine":
		rkey = "dark"
	elif kind == "tuolumne":
		rkey = "polished"
	var rc := ClimbRock.colors(rkey, pal)
	_foot_shadow(im, y0, edge, pal)
	_ground(im, y0, cols, edge, kind, rng, rock_like)
	match kind:
		"curry":
			_curry(im, y0, pal, rng, rc)
		"camp4":
			_camp4(im, y0, pal, rng, rc)
		"valley_forest":
			_forest(im, y0, pal, rng, rc, false)
		"half_dome_forest":
			_forest(im, y0, pal, rng, rc, true)
		"ahwahnee":
			_ahwahnee(im, y0, pal, rng, rc)
		"el_cap_meadow":
			_meadow(im, y0, pal, rng, rc)
		"tuolumne":
			_tuolumne(im, y0, pal, rng, rc)
		"moraine":
			_moraine(im, y0, pal, rng, rc)
		"bridalveil_talus":
			_talus(im, y0, pal, rng, rc, false)
		"mist_wall":
			_talus(im, y0, pal, rng, rc, true)


## Darkens the rock just above the ground a little: contact shadow.
static func _foot_shadow(im: Image, y0: int, edge: PackedInt32Array, pal: Dictionary) -> void:
	var w := im.get_width()
	var alphas: Array[float] = [0.08, 0.12, 0.17, 0.24, 0.32]
	for k in alphas.size():
		var y := y0 - alphas.size() + k
		var dark := Color(0.04, 0.03, 0.1, alphas[k])
		for x in range(0, mini(edge[y] if y < edge.size() else w, w)):
			im.set_pixel(x, y, im.get_pixel(x, y).blend(dark))


static func _ground(im: Image, y0: int, cols: Array[Color], edge: PackedInt32Array, kind: String, rng: RandomNumberGenerator, rock_like: bool) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var lim := 0
	for x in w:
		var gy := y0 + int(roundf(sin(x * 0.045 + 1.0) * 1.5 + sin(x * 0.11) * 1.0))
		var e := w
		if gy < edge.size():
			e = edge[gy] + 4
		if x > e:
			continue
		lim = x
		im.fill_rect(Rect2i(x, gy, 1, h - gy), cols[1])
		im.fill_rect(Rect2i(x, gy, 1, 2), cols[3])
		im.fill_rect(Rect2i(x, gy + 2, 1, 2), cols[2])
		if not rock_like:
			if rng.randf() < 0.45:
				P.px(im, x, gy - 1, cols[3])
			if rng.randf() < 0.14:
				P.px(im, x, gy - 2, cols[2])
	# A deeper, shadowed foreground, stepped in with a dither.
	for y in range(y0 + 44, y0 + 56):
		var t := float(y - (y0 + 44)) / 12.0
		for x in range(0, lim):
			if P.dither(x, y, t):
				im.set_pixel(x, y, cols[0])
	im.fill_rect(Rect2i(0, y0 + 56, lim + 1, h - (y0 + 56)), cols[0])
	# Lighter patches and darker pockets.
	for i in 12:
		var x := rng.randi_range(6, lim - 6)
		var y := y0 + rng.randi_range(8, 70)
		var rx := rng.randf_range(6, 18)
		var shade := cols[2] if y < y0 + 50 else cols[1]
		P.ellipse(im, x, y, rx, 1.6, shade)
		P.ellipse(im, x - 2, y - 1, rx * 0.6, 0.8, cols[3] if y < y0 + 50 else cols[2])
	for i in 520:
		var x := rng.randi_range(0, lim)
		var y := rng.randi_range(y0 + 4, y0 + 100)
		var k := rng.randi_range(0, 3)
		P.px(im, x, y, cols[k])
		if rng.randf() < 0.3:
			P.px(im, x + 1, y, cols[maxi(k - 1, 0)])
	if kind in ["curry", "ahwahnee", "el_cap_meadow", "valley_forest", "half_dome_forest", "tuolumne"]:
		for x in range(2, lim, 5):
			var y := y0 + rng.randi_range(10, 80)
			P.px(im, x, y, cols[3])
			P.px(im, x, y - 1, cols[2])


# ----------------------------------------------------------------- Camp Curry

static func _curry(im: Image, y0: int, pal: Dictionary, rng: RandomNumberGenerator, rc: Dictionary) -> void:
	var c := ClimbRock.colors("apron", pal)
	ClimbProps.grass_row(im, 0, _xr, y0 + 4, rng, pal, 4, false, 3)
	# Far trees: incense cedar, black oak and a Douglas-fir.
	ClimbProps.oak(im, 8, y0 + 14, 74, rng, c)
	ClimbProps.pine(im, _xr, y0 + 22, 80, rng, c)
	ClimbProps.oak(im, 286, y0 + 20, 50, rng, c)
	# Beaten earth path between the cabins.
	var dirt: Array[Color] = [_lit(Color("6b4829"), pal), _lit(Color("92693d"), pal), _lit(Color("b0925f"), pal)]
	_band(im, 0, _xr, y0 + 38, 11, dirt, rng, 2.0, 60)
	_tent_cabin(im, 4, y0 + 18, pal, true, "12")
	_tent_cabin(im, 226, y0 + 37, pal, false, "14")
	_light_pool(im, 28, y0 + 22, 30, pal)
	ClimbProps.board_sign(im, 56, y0 + 14, "CAMP CURRY", pal, 11)
	# Firewood, a lantern post and flower borders.
	_woodpile(im, 112, y0 + 24, pal)
	_lamp_post(im, 122, y0 + 32, pal)
	for i in 7:
		ClimbProps.flowers(im, 54 + i * 6, y0 + 20 + (i % 2), rng, pal)
	ClimbProps.flowers(im, 214, y0 + 22, rng, pal)
	ClimbProps.flowers(im, 280, y0 + 28, rng, pal)
	# Two guests strolling to the dining pavilion.
	ClimbProps.person(im, 150, y0 + 46, pal, {"shirt": Color("b3362b"), "hat": Color("d8a63b"), "dir": 1})
	ClimbProps.person(im, 164, y0 + 47, pal, {"shirt": Color("6f5aa6"), "pants": Color("5e4a38"), "dir": 1, "hair": Color("d8a63b")})
	ClimbProps.picnic_table(im, 190, y0 + 30, 20, pal)
	for i in 3:
		ClimbProps.fern(im, 40 + i * 70 + rng.randi_range(-6, 6), y0 + 62 + (i % 2) * 6, 7, pal)


## A Camp Curry tent cabin: white canvas over a timber frame on a wood deck.
static func _tent_cabin(im: Image, x: int, y: int, pal: Dictionary, lit_window: bool, number: String) -> void:
	var t := P.make(54, 40)
	var canvas := _lit(Color("e4ddcc"), pal)
	var shade := canvas.darkened(0.2)
	var wood := _lit(Color("6b4829"), pal)
	var wood_d := wood.darkened(0.3)
	var ox := 4
	var oy := 38
	# Wood deck and frame.
	P.rect(t, ox - 2, oy - 2, 48, 2, wood_d)
	P.rect(t, ox - 2, oy - 3, 48, 1, wood.lightened(0.2))
	# Canvas walls with seams, lit on the left and shaded on the right.
	P.rect(t, ox, oy - 17, 44, 14, canvas)
	for k in range(7, 44, 7):
		P.vline(t, ox + k, oy - 17, 14, shade)
	P.rect(t, ox, oy - 17, 3, 14, canvas.lightened(0.14))
	P.rect(t, ox + 38, oy - 17, 6, 14, shade)
	P.rect(t, ox, oy - 9, 44, 6, wood)
	P.rect(t, ox, oy - 9, 44, 1, wood.lightened(0.25))
	for k in range(4, 44, 6):
		P.vline(t, ox + k, oy - 8, 5, wood_d)
	P.rect(t, ox, oy - 17, 2, 14, wood_d)
	P.rect(t, ox + 42, oy - 17, 2, 14, wood_d)
	# Gable roof (the canvas fly), with a ridge pole and eaves.
	for k in 14:
		var half := 24 - (13 - k) - 1 + 1
		half = 8 + k * 16 / 14 + 2
		var col := canvas.lightened(0.1) if k < 4 else canvas
		P.rect(t, ox + 22 - half, oy - 32 + k, half * 2, 1, col)
		P.px(t, ox + 22 - half, oy - 32 + k, canvas.lightened(0.22))
		P.px(t, ox + 21 + half, oy - 32 + k, shade)
	P.rect(t, ox + 22, oy - 32, 11, 14, canvas.lerp(shade, 0.35))
	for k in range(3, 14, 4):
		P.hline(t, ox + 22 - (8 + k + 2), oy - 32 + k, 8, shade)
	P.rect(t, ox + 20, oy - 34, 4, 2, wood)
	P.rect(t, ox - 6, oy - 18, 56, 1, wood_d)
	P.rect(t, ox - 6, oy - 19, 56, 1, canvas.darkened(0.08))
	# Door with a screen, window with a flap, cabin number.
	P.rect(t, ox + 18, oy - 15, 9, 13, _lit(Color("47301f"), pal))
	P.rect(t, ox + 19, oy - 14, 7, 11, _lit(Color("5e4a38"), pal))
	P.rect(t, ox + 20, oy - 13, 5, 9, _glass(pal) if lit_window else _lit(Color("47301f"), pal))
	P.vline(t, ox + 22, oy - 14, 11, wood_d)
	P.rect(t, ox + 31, oy - 14, 7, 6, wood_d)
	P.rect(t, ox + 32, oy - 13, 5, 4, _glass(pal))
	P.vline(t, ox + 34, oy - 13, 4, wood)
	P.rect(t, ox + 8, oy - 14, 5, 4, _lit(Color("f5eee0"), pal))
	ClimbProps.text(t, ox + 9, oy - 13, number.substr(number.length() - 1), _lit(Color("6b4829"), pal))
	# Stovepipe.
	P.rect(t, ox + 33, oy - 38, 2, 8, _lit(Color("47464d"), pal))
	P.rect(t, ox + 32, oy - 38, 4, 1, _lit(Color("6a6a70"), pal))
	# Porch step.
	P.rect(t, ox + 17, oy - 2, 11, 2, wood.lightened(0.15))
	ClimbProps.shadow(im, x + 28, y + 1, 30, 2.5, 0.3)
	_stamp(im, t, x - 6, y - 40)


static func _woodpile(im: Image, x: int, y: int, pal: Dictionary) -> void:
	var wood := _lit(Color("92693d"), pal)
	ClimbProps.shadow(im, x + 8, y + 1, 11, 1.5, 0.3)
	P.rect(im, x - 1, y - 8, 18, 9, DARK)
	for r in 3:
		for k in 5 - (r % 2):
			var xx := x + k * 3 + (r % 2) * 2
			P.rect(im, xx, y - 7 + r * 3, 3, 3, wood if (k + r) % 2 == 0 else wood.darkened(0.15))
			P.px(im, xx + 1, y - 6 + r * 3, _lit(Color("d6bd88"), pal))


static func _lamp_post(im: Image, x: int, y: int, pal: Dictionary) -> void:
	P.rect(im, x - 1, y - 20, 2, 20, DARK)
	P.rect(im, x - 3, y - 25, 7, 5, DARK)
	P.rect(im, x - 2, y - 24, 5, 3, ClimbProps.glow("ffd070", pal))
	P.rect(im, x - 4, y - 26, 9, 1, DARK)
	_light_pool(im, x, y + 1, 24, pal)


# -------------------------------------------------------------------- Camp 4

static func _camp4(im: Image, y0: int, pal: Dictionary, rng: RandomNumberGenerator, rc: Dictionary) -> void:
	var c := ClimbRock.colors("apron", pal)
	# Black oaks and incense cedars all around.
	ClimbProps.oak(im, 6, y0 + 24, 80, rng, c)
	ClimbProps.pine(im, 292, y0 + 24, 76, rng, c)
	ClimbProps.oak(im, 286, y0 + 18, 52, rng, c)
	# The famous boulders with chalk and a crash pad.
	ClimbProps.boulder(im, 236, y0 + 30, 17, 11, rc, rng, false)
	_chalk(im, 232, y0 + 22, pal, rng)
	ClimbProps.boulder(im, 52, y0 + 32, 13, 8, rc, rng, true)
	P.rect(im, 266, y0 + 36, 16, 6, DARK)
	P.rect(im, 267, y0 + 37, 14, 4, _lit(Color("b3362b"), pal))
	P.rect(im, 267, y0 + 37, 14, 1, _lit(Color("d9772a"), pal))
	P.rect(im, 273, y0 + 37, 1, 4, _lit(Color("2d3050"), pal))
	# Tents.
	ClimbProps.dome_tent(im, 30, y0 + 20, 32, 18, Color("d9772a"), pal)
	ClimbProps.dome_tent(im, 86, y0 + 28, 28, 15, Color("6f5aa6"), pal)
	# A bear box, the camp sign and a picnic table.
	_bear_box(im, 126, y0 + 24, pal)
	ClimbProps.board_sign(im, 150, y0 + 26, "CAMP 4", pal, 10)
	ClimbProps.picnic_table(im, 180, y0 + 36, 22, pal)
	_fire_ring(im, 216, y0 + 46, pal, rng, rc)
	for i in 3:
		ClimbProps.log_pile(im, 150 + i * 4, y0 + 52 + i * 4, 12, pal)
	ClimbProps.person(im, 112, y0 + 42, pal, {"shirt": Color("437f45"), "hat": Color("ad7a22"), "dir": 1, "pack": Color("b3362b")})
	for i in 4:
		ClimbProps.fern(im, 30 + i * 60, y0 + 64 + (i % 2) * 5, 6, pal)
	ClimbProps.grass_row(im, 0, _xr, y0 + 4, rng, pal, 5, true, 2)


static func _chalk(im: Image, x: int, y: int, pal: Dictionary, rng: RandomNumberGenerator) -> void:
	var ch := _lit(Color("f5eee0"), pal)
	for i in 12:
		P.px(im, x + rng.randi_range(-4, 8), y + rng.randi_range(-4, 5), ch)
	P.rect(im, x + 4, y - 6, 2, 3, ch)


static func _bear_box(im: Image, x: int, y: int, pal: Dictionary) -> void:
	var m := _lit(Color("93918f"), pal)
	ClimbProps.shadow(im, x + 11, y + 1, 14, 2, 0.3)
	P.rect(im, x - 1, y - 14, 24, 15, DARK)
	P.rect(im, x, y - 13, 22, 13, m)
	P.rect(im, x, y - 13, 22, 2, m.lightened(0.25))
	P.rect(im, x + 18, y - 13, 4, 13, m.darkened(0.2))
	P.rect(im, x + 2, y - 10, 16, 8, m.darkened(0.12))
	P.rect(im, x + 14, y - 6, 2, 1, _lit(Color("d8a63b"), pal))
	ClimbProps.text(im, x + 3, y - 8, "BEAR", _lit(Color("e4ddcc"), pal))


static func _fire_ring(im: Image, x: int, y: int, pal: Dictionary, rng: RandomNumberGenerator, rc: Dictionary) -> void:
	var n := ClimbProps.night_amount(pal)
	P.ellipse(im, x, y, 11, 4.4, DARK)
	P.ellipse(im, x, y, 9, 3, _lit(Color("2a1b14"), pal))
	for i in 8:
		var a := float(i) / 8.0 * TAU
		var sx := x + cos(a) * 9.0
		var sy := y + sin(a) * 3.4
		P.ellipse(im, sx, sy, 2.4, 1.8, ClimbRock.tone(rc, 2.0))
		P.px(im, int(sx) - 1, int(sy) - 1, ClimbRock.tone(rc, 3.8))
	# Embers; a real flame once it is dark.
	P.rect(im, x - 3, y - 1, 6, 2, _lit(Color("d9772a"), pal).lerp(Color("d9772a"), n))
	if n > 0.3:
		P.ellipse(im, x, y + 1, 26.0 * n, 7.0 * n, Color(1.0, 0.65, 0.25, 0.1 * n))
		for k in 7:
			var fw := 4 - k / 2
			P.rect(im, x - fw / 2, y - 2 - k, maxi(fw, 1), 1, Color("f1cf6a") if k < 3 else Color("d9772a"))
	else:
		P.rect(im, x - 2, y - 3, 4, 2, _lit(Color("47301f"), pal))


# ------------------------------------------------------------------ forests

static func _forest(im: Image, y0: int, pal: Dictionary, rng: RandomNumberGenerator, rc: Dictionary, half_dome: bool) -> void:
	var c := ClimbRock.colors("apron", pal)
	# Tall conifers set back, then the ones on the sides, in front.
	var back: Array[int] = [30, 80]
	for x in back:
		ClimbProps.pine(im, x, y0 + 14, rng.randi_range(54, 70), rng, c)
	ClimbProps.pine(im, 6, y0 + 30, 88, rng, c)
	ClimbProps.pine(im, 292, y0 + 30, 84, rng, c)
	if half_dome:
		ClimbProps.pine(im, 276, y0 + 24, 66, rng, c)
	else:
		ClimbProps.oak(im, 280, y0 + 24, 52, rng, c)
	# Mossy boulders and a fallen log.
	ClimbProps.boulder(im, 230, y0 + 34, 12, 7, rc, rng, true)
	ClimbProps.boulder(im, 62, y0 + 42, 9, 5, rc, rng, true)
	ClimbProps.log_pile(im, 150, y0 + 38, 30, pal)
	for i in 6:
		ClimbProps.fern(im, 20 + i * 48 + rng.randi_range(-8, 8), y0 + 30 + rng.randi_range(0, 40), rng.randi_range(5, 8), pal)
	if half_dome:
		# The John Muir Trail: a signpost, a backpack and a hiker.
		var tr: Array[Color] = [_lit(Color("5e4a38"), pal), _lit(Color("86694b"), pal), _lit(Color("b0925f"), pal)]
		_band(im, 0, _xr, y0 + 26, 8, tr, rng, 3.0, 50)
		ClimbProps.board_sign(im, 102, y0 + 30, "HALF DOME 8", pal, 11)
		ClimbProps.person(im, 190, y0 + 44, pal, {"shirt": Color("d8a63b"), "pants": Color("2c5c37"), "hat": Color("e4ddcc"), "dir": -1, "pack": Color("6f5aa6")})
		for i in 2:
			ClimbProps.fern(im, 130 + i * 30, y0 + 52, 6, pal)
	else:
		ClimbProps.board_sign(im, 98, y0 + 30, "TRAIL", pal, 10)
		for i in 5:
			ClimbProps.flowers(im, 130 + i * 18 + rng.randi_range(-5, 5), y0 + 48 + rng.randi_range(0, 18), rng, pal)
	_dapple(im, y0, pal, rng)


## Soft patches of sunlight through the branches, by day.
static func _dapple(im: Image, y0: int, pal: Dictionary, rng: RandomNumberGenerator) -> void:
	var lum: float = pal.get("lum", 1.0)
	if lum < 0.85:
		return
	for i in 7:
		var x := rng.randi_range(20, 280)
		var y := y0 + rng.randi_range(14, 70)
		P.ellipse(im, x, y, rng.randf_range(5, 11), 1.8, Color(1, 0.831, 0.541, 0.16))


# ------------------------------------------------------------ Ahwahnee Hotel

static func _ahwahnee(im: Image, y0: int, pal: Dictionary, rng: RandomNumberGenerator, rc: Dictionary) -> void:
	var c := ClimbRock.colors("apron", pal)
	ClimbProps.pine(im, 292, y0 + 22, 82, rng, c)
	ClimbProps.oak(im, 284, y0 + 20, 52, rng, c)
	_hotel(im, 2, y0 + 24, pal, rng)
	# Gravel path up to the door, with box hedges and lamps.
	var gravel: Array[Color] = [_lit(Color("93918f"), pal), _lit(Color("bdb8ae"), pal), _lit(Color("e4ddcc"), pal)]
	for k in 70:
		var hw := 5 + k / 4
		var yy := y0 + 25 + k
		P.rect(im, 59 - hw, yy, hw * 2, 1, gravel[1])
		P.px(im, 59 - hw, yy, gravel[2])
		P.px(im, 58 + hw, yy, gravel[0])
		if rng.randf() < 0.35:
			P.px(im, 59 - hw + rng.randi_range(0, hw * 2 - 1), yy, gravel[rng.randi_range(0, 2)])
	for sx in [-1, 1]:
		var hx: int = 59 + sx * 15
		var hedge: Array[Color] = [_lit(Color("2c5c37"), pal), _lit(Color("437f45"), pal), _lit(Color("5c8f3c"), pal)]
		P.rect(im, hx - 12, y0 + 24, 24, 7, DARK)
		P.rect(im, hx - 11, y0 + 24, 22, 6, hedge[1])
		P.rect(im, hx - 11, y0 + 24, 22, 2, hedge[2])
		P.rect(im, hx - 11, y0 + 29, 22, 1, hedge[0])
		for i in 3:
			P.px(im, hx - 8 + i * 8, y0 + 26, _lit(Color("e4ddcc"), pal))
	_lamp_post(im, 30, y0 + 44, pal)
	_lamp_post(im, 92, y0 + 44, pal)
	# Rose beds and a couple on the lawn.
	for i in 6:
		ClimbProps.flowers(im, 8 + i * 5, y0 + 30, rng, pal)
	for i in 5:
		ClimbProps.flowers(im, 104 + i * 4, y0 + 30, rng, pal)
	ClimbProps.person(im, 120, y0 + 56, pal, {"shirt": Color("f5eee0"), "pants": Color("5e4a38"), "hat": Color("d6bd88"), "dir": -1})
	ClimbProps.person(im, 129, y0 + 57, pal, {"shirt": Color("d47a9b"), "pants": Color("47464d"), "dir": -1, "hair": Color("d8a63b")})
	ClimbProps.picnic_table(im, 190, y0 + 46, 22, pal)
	ClimbProps.shrub(im, 220, y0 + 34, 7, rng, pal, true)
	ClimbProps.grass_row(im, 0, _xr, y0 + 4, rng, pal, 5, false, 2)


## The Ahwahnee: a long granite-and-sugar-pine hall with a green-brown roof,
## a taller gabled middle, stone chimneys and rows of lit windows.
static func _hotel(im: Image, x: int, yb: int, pal: Dictionary, rng: RandomNumberGenerator) -> void:
	var stone := _lit(Color("bdb8ae"), pal)
	var stone_l := stone.lightened(0.18)
	var stone_d := stone.darkened(0.28)
	var timber := _lit(Color("6b4829"), pal)
	var roof := _lit(Color("2c5c37"), pal)
	var roof_l := roof.lightened(0.2)
	var roof_d := roof.darkened(0.3)
	var w := 112
	var body_h := 30
	var top := yb - body_h
	# Silhouette in dark first, so the whole building reads as outlined.
	P.rect(im, x - 5, top - 14, w + 10, 15, DARK)
	P.rect(im, x - 1, top - 1, w + 2, body_h + 3, DARK)
	P.rect(im, x + 43, top - 31, 28, 20, DARK)
	# Walls: coursed granite blocks.
	P.rect(im, x, top, w, body_h, stone)
	for r in range(0, body_h, 5):
		P.hline(im, x, top + r, w, stone_d)
		for k in range((r / 5) % 2 * 4, w, 9):
			P.vline(im, x + k, top + r, 5, stone_d)
	P.rect(im, x, top, w, 2, stone_l)
	P.rect(im, x, yb - 3, w, 3, stone_d)
	# Timber band and trim between the floors.
	P.rect(im, x, top + 12, w, 3, timber)
	P.rect(im, x, top + 12, w, 1, timber.lightened(0.3))
	for k in range(4, w, 12):
		P.rect(im, x + k, top + 9, 2, 6, timber)
	# Roof: a low hip of dark green-brown shingles.
	for k in 12:
		var inset := k
		var yy := top - 1 - k
		P.rect(im, x - 4 + inset, yy, w + 8 - inset * 2, 1, roof_l if k == 11 else (roof if k % 3 != 2 else roof_d))
		P.px(im, x - 4 + inset, yy, roof_l)
		P.px(im, x + w + 3 - inset, yy, roof_d)
	P.rect(im, x - 4, top - 1, w + 8, 1, roof_d)
	# The tall middle with a gable roof and the grand entrance.
	var mx := x + 44
	P.rect(im, mx, top - 22, 26, 22, stone)
	for r in range(0, 22, 5):
		P.hline(im, mx, top - 22 + r, 26, stone_d)
		for k in range((r / 5) % 2 * 4, 26, 9):
			P.vline(im, mx + k, top - 22 + r, 5, stone_d)
	P.rect(im, mx, top - 22, 2, 22, stone_l)
	P.rect(im, mx + 24, top - 22, 2, 22, stone_d)
	for k in 12:
		P.rect(im, mx - 2 + k, top - 22 - 12 + k, 30 - k * 2, 1, roof if k % 3 != 2 else roof_d)
		P.px(im, mx - 2 + k, top - 22 - 12 + k, roof_l)
	P.rect(im, mx + 10, top - 34, 6, 1, roof_l)
	# Windows: tall arches in the great lounge, small panes above and below.
	var glass := _glass(pal)
	for i in 3:
		var ax := mx + 3 + i * 7
		P.rect(im, ax, top + 7, 5, 18, DARK)
		P.rect(im, ax + 1, top + 8, 3, 16, glass)
		P.px(im, ax + 1, top + 8, DARK)
		P.px(im, ax + 3, top + 8, DARK)
		P.vline(im, ax + 2, top + 9, 15, timber)
	P.rect(im, mx + 8, top - 18, 10, 10, DARK)
	P.rect(im, mx + 9, top - 17, 8, 8, glass)
	P.vline(im, mx + 12, top - 17, 8, timber)
	P.vline(im, mx + 14, top - 17, 8, timber)
	P.hline(im, mx + 9, top - 13, 8, timber)
	var wins: Array[int] = [6, 18, 30, 80, 92, 104]
	for k in wins.size():
		var wx := x + wins[k]
		for row in 2:
			var wy := top + 3 + row * 14 if row == 0 else top + 17
			var on := ClimbProps.night_amount(pal) < 0.2 or rng.randf() < 0.75
			P.rect(im, wx, wy, 5, 7, DARK)
			P.rect(im, wx + 1, wy + 1, 3, 5, glass if on else _lit(Color("235679"), pal))
			P.hline(im, wx + 1, wy + 3, 3, timber)
	# Stone chimneys.
	for cx in [x + 14, x + 98]:
		P.rect(im, cx - 4, top - 24, 9, 14, DARK)
		P.rect(im, cx - 3, top - 23, 7, 13, stone)
		P.rect(im, cx - 3, top - 23, 2, 13, stone_l)
		P.rect(im, cx - 5, top - 25, 11, 2, stone_d)
		P.px(im, cx, top - 20, stone_d)
		P.px(im, cx + 2, top - 16, stone_d)
	# The door.
	P.rect(im, x + 54, yb - 10, 9, 10, DARK)
	P.rect(im, x + 55, yb - 9, 7, 9, _glass(pal))
	P.vline(im, x + 58, yb - 9, 9, timber)
	P.rect(im, x + 52, yb - 11, 13, 2, timber)
	_light_pool(im, x + 59, yb + 3, 28, pal)


# ----------------------------------------------------------- El Capitan Meadow

static func _meadow(im: Image, y0: int, pal: Dictionary, rng: RandomNumberGenerator, rc: Dictionary) -> void:
	var c := ClimbRock.colors("apron", pal)
	ClimbProps.oak(im, 12, y0 + 18, 66, rng, c)
	ClimbProps.pine(im, 294, y0 + 20, 74, rng, c)
	ClimbProps.oak(im, 284, y0 + 16, 44, rng, c)
	# Northside Drive across the foreground, with a dashed yellow line.
	var asphalt: Array[Color] = [_lit(Color("2b2a30"), pal), _lit(Color("47464d"), pal), _lit(Color("6a6a70"), pal)]
	_band(im, 0, _xr, y0 + 56, 14, asphalt, rng, 0.0, 70)
	for x in range(6, _xr, 18):
		P.rect(im, x, y0 + 63, 9, 1, _lit(Color("d8a63b"), pal))
	P.hline(im, 0, y0 + 69, _xr, _lit(Color("bdb8ae"), pal))
	# Parked cars on the shoulder.
	ClimbProps.car(im, 74, y0 + 55, Color("b3362b"), pal, 1, true)
	ClimbProps.car(im, 230, y0 + 56, Color("6f5aa6"), pal, -1)
	ClimbProps.car(im, 276, y0 + 57, Color("e4ddcc"), pal, -1, true)
	# A split-rail fence along the meadow edge.
	var rail := _lit(Color("92693d"), pal)
	for x in range(2, _xr, 16):
		P.rect(im, x, y0 + 24, 2, 11, DARK)
		P.rect(im, x, y0 + 24, 1, 10, rail)
	for k in 2:
		P.rect(im, 0, y0 + 27 + k * 4, _xr, 2, DARK)
		P.rect(im, 0, y0 + 27 + k * 4, _xr, 1, rail.lightened(0.2))
	# Visitors with binoculars and a spotting scope, all looking up.
	var shirts: Array[Color] = [Color("b3362b"), Color("6f5aa6"), Color("d8a63b"), Color("84b04a")]
	var xs: Array[int] = [112, 134, 166, 188, 208]
	for i in xs.size():
		ClimbProps.person(im, xs[i], y0 + 42 + (i % 2) * 3, pal, {"shirt": shirts[i % 4], "bino": i % 2 == 0, "dir": 1, "hat": Color("e4ddcc") if i % 3 == 0 else Color("47301f")})
	ClimbProps.tripod(im, 150, y0 + 45, pal, 1)
	ClimbProps.person(im, 154, y0 + 46, pal, {"shirt": Color("f5eee0"), "dir": 1, "pack": Color("6b4829"), "hair": Color("d8a63b")})
	ClimbProps.board_sign(im, 28, y0 + 32, "EL CAP", pal, 9)
	# Tall meadow grass and wildflowers.
	for i in 14:
		var gy := y0 + 10 + i * 4
		if gy > y0 + 50 and gy < y0 + 74:
			continue
		ClimbProps.grass_row(im, 0, _xr, gy, rng, pal, 12, i % 3 == 0, 4)
	for i in 14:
		var fy := y0 + rng.randi_range(38, 100)
		if fy > y0 + 50 and fy < y0 + 74:
			continue
		ClimbProps.flowers(im, rng.randi_range(4, 292), fy, rng, pal)


# -------------------------------------------------------------------- Tuolumne

static func _tuolumne(im: Image, y0: int, pal: Dictionary, rng: RandomNumberGenerator, rc: Dictionary) -> void:
	var c := ClimbRock.colors("apron", pal)
	# Granite slabs in the meadow, with cracks and lichen.
	for i in 3:
		var sx := 80 + i * 70 + rng.randi_range(-10, 10)
		var sy := y0 + 40 + i % 2 * 12
		var rx := rng.randi_range(26, 38)
		P.ellipse(im, sx, sy + 1, rx + 1, 6.5, DARK)
		P.shaded_ellipse(im, sx, sy, rx, 5.5, ClimbRock.tone(rc, 2.6), ClimbRock.tone(rc, 3.6), ClimbRock.tone(rc, 1.6))
		P.line(im, Vector2(sx - 6, sy - 3), Vector2(sx + 5, sy + 2), ClimbRock.tone(rc, 1.0))
		for k in 6:
			P.px(im, sx + rng.randi_range(-rx + 4, rx - 4), sy + rng.randi_range(-3, 3), ClimbRock.tone(rc, 3.9))
		P.px(im, sx - 8, sy - 2, rc.lichen_o)
		P.px(im, sx + 9, sy + 1, rc.lichen_y)
	# Tuolumne River, a ribbon of blue across the foreground.
	var water: Array[Color] = [_lit(Color("235679"), pal), _lit(Color("3a86a8"), pal), _lit(Color("9fd8d9"), pal)]
	_band(im, 0, _xr, y0 + 72, 9, water, rng, 4.0, 40)
	# Lodgepoles and whitebarks; the tall ones are out at the sides.
	var back: Array[int] = [14, 28, 280, 294]
	for x in back:
		ClimbProps.lodgepole(im, x, y0 + 28 + rng.randi_range(-4, 10), rng.randi_range(58, 80), rng, c)
	ClimbProps.gnarled(im, 262, y0 + 34, 20, rng, c)
	ClimbProps.lodgepole(im, 62, y0 + 20, 48, rng, c)
	ClimbProps.gnarled(im, 100, y0 + 62, 16, rng, c)
	ClimbProps.boulder(im, 244, y0 + 56, 11, 6, rc, rng, false)
	# Trail sign and a hiker reading it.
	ClimbProps.board_sign(im, 106, y0 + 28, "CATHEDRAL PK", pal, 11)
	ClimbProps.person(im, 170, y0 + 30, pal, {"shirt": Color("3a86a8"), "pants": Color("5e4a38"), "hat": Color("d6bd88"), "dir": -1, "pack": Color("b3362b")})
	for i in 9:
		ClimbProps.flowers(im, rng.randi_range(8, 290), y0 + rng.randi_range(16, 96), rng, pal)
	ClimbProps.shrub(im, 220, y0 + 34, 5, rng, pal, false)
	ClimbProps.grass_row(im, 0, _xr, y0 + 4, rng, pal, 4, true, 2)


# --------------------------------------------------------------------- moraine

static func _snow(im: Image, x: int, y: int, rx: float, ry: float, pal: Dictionary) -> void:
	P.ellipse(im, x, y + 1, rx + 1, ry + 1, _lit(Color("3a86a8"), pal))
	P.shaded_ellipse(im, x, y, rx, ry, _lit(Color("d6f1ee"), pal), _lit(Color("f5eee0"), pal), _lit(Color("63b3c6"), pal))
	P.ellipse(im, x + rx * 0.3, y + ry * 0.4, rx * 0.35, ry * 0.25, _lit(Color("9fd8d9"), pal))


static func _moraine(im: Image, y0: int, pal: Dictionary, rng: RandomNumberGenerator, rc: Dictionary) -> void:
	var gray: Array[Color] = [_lit(Color("47464d"), pal), _lit(Color("6a6a70"), pal), _lit(Color("93918f"), pal), _lit(Color("bdb8ae"), pal)]
	# Rubble: loose stones with a lit top-left edge.
	for i in 90:
		var rx := rng.randi_range(4, 292)
		var ry := y0 + rng.randi_range(4, 100)
		var rw := rng.randi_range(2, 5)
		var rh := rng.randi_range(1, 3)
		P.rect(im, rx, ry, rw + 1, rh + 1, gray[0])
		P.rect(im, rx, ry, rw, rh, gray[rng.randi_range(1, 2)])
		P.px(im, rx, ry, gray[3])
	# A meltwater tarn with floating ice.
	var wx := 96
	var wy := y0 + 60
	P.ellipse(im, wx, wy + 1, 34, 8.5, _lit(Color("235679"), pal))
	P.ellipse(im, wx, wy, 33, 7.5, _lit(Color("3a86a8"), pal))
	P.ellipse(im, wx - 4, wy - 2, 24, 4, _lit(Color("63b3c6"), pal))
	for k in 5:
		P.rect(im, wx - 20 + k * 9 + rng.randi_range(-2, 2), wy - 3 + rng.randi_range(0, 5), 4, 2, _lit(Color("d6f1ee"), pal))
	# Snow patches and the climbers' gear stuck in them.
	_snow(im, 214, y0 + 32, 26, 6, pal)
	_snow(im, 40, y0 + 36, 20, 5, pal)
	_snow(im, 160, y0 + 78, 22, 4.4, pal)
	_snow(im, 274, y0 + 56, 14, 4, pal)
	ClimbProps.ice_axe(im, 206, y0 + 32, pal, 1)
	ClimbProps.ice_axe(im, 224, y0 + 33, pal, -1)
	# Boulders, a cairn, a tent and a rope coil.
	for i in 5:
		ClimbProps.boulder(im, rng.randi_range(120, 290), y0 + rng.randi_range(44, 90), rng.randf_range(6, 13), rng.randf_range(4, 8), rc, rng, false)
	ClimbProps.boulder(im, 8, y0 + 30, 15, 12, rc, rng, false)
	ClimbProps.boulder(im, 292, y0 + 22, 14, 14, rc, rng, false)
	ClimbProps.dome_tent(im, 66, y0 + 32, 30, 17, Color("d8a63b"), pal)
	ClimbProps.cairn(im, 264, y0 + 34, rc, 3)
	var rope := _lit(Color("b3362b"), pal)
	P.ellipse(im, 140, y0 + 40, 6, 3, DARK)
	P.ellipse(im, 140, y0 + 40, 5, 2.2, rope)
	P.ellipse(im, 140, y0 + 40, 2.5, 1, DARK)
	P.px(im, 137, y0 + 39, rope.lightened(0.3))
	for i in 4:
		P.rect(im, 20 + i * 70 + rng.randi_range(-10, 10), y0 + rng.randi_range(60, 90), 3, 2, _lit(Color("bdb8ae"), pal))


# ---------------------------------------------------------------------- talus

static func _talus(im: Image, y0: int, pal: Dictionary, rng: RandomNumberGenerator, rc0: Dictionary, wet: bool) -> void:
	var c := ClimbRock.colors("apron", pal)
	var rc := ClimbRock.colors("dark" if wet else "arches", pal)
	ClimbProps.pine(im, 6, y0 + 30, 86, rng, c)
	ClimbProps.pine(im, 292, y0 + 28, 80, rng, c)
	if wet:
		ClimbProps.pine(im, 30, y0 + 14, 56, rng, c)
		ClimbProps.oak(im, 284, y0 + 20, 48, rng, c)
	else:
		ClimbProps.oak(im, 284, y0 + 22, 52, rng, c)
		ClimbProps.pine(im, 34, y0 + 16, 60, rng, c)
	# A boulder field, big ones low and in front.
	var n := 17
	for i in n:
		var by := y0 + 14 + i * 7 + rng.randi_range(0, 4)
		var bx := rng.randi_range(8, 290)
		if by < y0 + 36 and bx > 100 and bx < 250:
			bx = [30, 70, 270, 290][rng.randi_range(0, 3)]
		var br := rng.randf_range(6, 8 + i * 1.2)
		ClimbProps.boulder(im, bx, by, br, br * 0.62, rc, rng, wet or rng.randf() < 0.3)
	for i in 6:
		ClimbProps.fern(im, rng.randi_range(10, 290), y0 + rng.randi_range(20, 90), rng.randi_range(5, 8), pal)
	if wet:
		# A creek of snowmelt, and spray drifting off the wall.
		var water: Array[Color] = [_lit(Color("235679"), pal), _lit(Color("3a86a8"), pal), _lit(Color("9fd8d9"), pal)]
		_band(im, 0, _xr, y0 + 78, 8, water, rng, 3.0, 30)
		for i in 5:
			P.ellipse(im, rng.randi_range(0, 120) + i * 30, y0 - rng.randi_range(0, 14), rng.randf_range(16, 32), rng.randf_range(5, 9), Color(0.839, 0.945, 0.933, 0.1))
		ClimbProps.board_sign(im, 98, y0 + 26, "MIST TRAIL", pal, 10)
		# Stone steps of the trail, edged with a pole rail.
		for k in 5:
			P.rect(im, 36 + k * 3, y0 + 52 + k * 3, 16, 3, ClimbRock.tone(rc, 2.5))
			P.rect(im, 36 + k * 3, y0 + 52 + k * 3, 16, 1, ClimbRock.tone(rc, 3.7))
	else:
		ClimbProps.board_sign(im, 98, y0 + 26, "CATHEDRAL", pal, 10)
		for i in 5:
			ClimbProps.shrub(im, rng.randi_range(10, 290), y0 + rng.randi_range(40, 90), rng.randi_range(4, 6), rng, pal, true)


# ------------------------------------------------------------------- finishes

## Paints what's above the last ledge: cuts the wall away to a summit shape
## and dresses it.
static func paint_finish(im: Image, kind: String, state: ClimbState, pal: Dictionary, edge: PackedInt32Array, seed_value: int) -> void:
	if kind == "":
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 9
	var w := im.get_width()
	var y_top := int(L.wall_px(state.top_row, state.top_row, 0).y) + 7
	var cx := int(L.GRID_X + 2.5 * L.COL_W)
	var c := ClimbRock.colors("apron", pal)
	var e := w
	if y_top < edge.size():
		e = mini(edge[y_top], w)
	var top := _profile(kind, y_top, cx, w, seed_value)
	_cut(im, top, c, e)
	var sx := cx
	match kind:
		"rim":
			_rim(im, top, y_top, pal, rng, w, e)
		"tree_ledge":
			_tree_ledge(im, top, pal, rng, c, e)
		"anchor":
			_anchor(im, top, y_top, pal, rng, c, e)
		"chimney_top":
			_terrace(im, top, pal, rng, c, e, "chimney")
		"arches_top":
			_terrace(im, top, pal, rng, c, e, "arches")
		"column_top":
			_terrace(im, top, pal, rng, c, e, "column")
		"el_cap_top":
			_el_cap(im, top, pal, rng, c, e)
		"spire_top":
			_shade_slope(im, top, y_top, cx + 2, cx + 60, c)
			_summit(im, top, y_top, cx, pal, rng, c, false)
		"peak_summit":
			_shade_slope(im, top, y_top, cx + 4, cx + 70, c)
			_summit(im, top, y_top, cx, pal, rng, c, true)
		"dome_top":
			_dome(im, top, y_top, cx, pal, rng, c, e)
		"glacier_ridge":
			_ridge(im, top, y_top, cx, pal, rng, c, e)
		"roof_lip":
			_terrace(im, top, pal, rng, c, e, "roof")
	var _unused := sx


## The height of the rock's upper edge in every column (y of the first row of
## rock), by summit type. Everything above it is cleared to the sky.
static func _profile(kind: String, y_top: int, cx: int, w: int, seed_value: int) -> PackedInt32Array:
	var top := PackedInt32Array()
	top.resize(w)
	for x in w:
		var n := P.smooth_noise(x * 0.07, 3.0, seed_value) - 0.5
		var n2 := P.smooth_noise(x * 0.025, 7.0, seed_value) - 0.5
		var y := y_top - 12 + int(roundf(n * 3.0))
		match kind:
			"tree_ledge", "anchor", "chimney_top", "arches_top":
				y = y_top - 22 + int(roundf(n * 4.0 + n2 * 6.0))
			"column_top":
				y = y_top - 24 + int(roundf(n2 * 22.0 + n * 3.0))
			"el_cap_top":
				y = y_top - 22 + int(roundf(n2 * 20.0 + n * 2.0))
			"spire_top":
				y = y_top - 3
				var dx := absf(x - cx)
				var hh := (56.0 - dx) / 0.52
				if hh > 0.0:
					hh = minf(hh, 92.0) + n * 10.0 + sin(x * 0.4) * 1.5
					if dx < 4.0:
						hh = 92.0 + (4.0 - dx) * 1.5
					y = y_top - 3 - int(hh)
			"peak_summit":
				y = y_top - 3
				var dxp := float(x - cx)
				var hp := (68.0 - absf(dxp)) / 0.62
				if hp > 0.0:
					hp = minf(hp, 92.0) + n * 8.0
					if dxp > 0.0 and dxp < 10.0:
						hp = 92.0
					elif dxp <= 0.0 and dxp > -8.0:
						hp = 85.0
					y = y_top - 3 - int(hp)
			"dome_top":
				var u := (x - (cx - 24)) / 170.0
				var hd := 58.0
				if u > 0.0:
					hd = 58.0 * sqrt(maxf(1.0 - u * u, 0.0))
				else:
					hd = 58.0 + u * 22.0
				y = y_top - 4 - int(hd) + int(roundf(n * 2.0))
			"glacier_ridge":
				var hg := 84.0 - maxf(0.0, x - 132.0) * 0.5 + n * 6.0
				y = y_top - 6 - maxi(int(hg), 0)
		top[x] = clampi(y, 0, y_top)
	return top


## Clears the sky above [param top] and gives the cut edge an outline and a
## lit top-left / shaded lower-right bevel.
static func _cut(im: Image, top: PackedInt32Array, c: Dictionary, e: int) -> void:
	var w := im.get_width()
	for x in w:
		if top[x] > 0:
			im.fill_rect(Rect2i(x, 0, 1, top[x]), Color(0.082, 0.078, 0.11, 0))
	var seam: Color = c.seam
	var hi := ClimbRock.tone(c, 3.9)
	var lo := ClimbRock.tone(c, 1.2)
	for x in range(0, mini(e + 6, w)):
		var t := top[x]
		var l := top[maxi(x - 1, 0)]
		var r := top[mini(x + 1, w - 1)]
		var d := r - l
		# Outline in the air next to the rock.
		var y_hi := mini(mini(l, r), t)
		for y in range(y_hi, t):
			P.px(im, x, y, seam)
		P.px(im, x, t - 1, seam)
		# Bevel: lit where the edge rises to the right, shaded where it falls.
		if d < -1:
			for k in 3:
				P.px(im, x, t + k, hi if k == 0 else ClimbRock.tone(c, 3.4 - k * 0.3))
		elif d > 1:
			for k in 6:
				if P.dither(x, t + k, 1.0 - k / 6.0):
					P.px(im, x, t + k, lo)
			P.px(im, x, t, ClimbRock.tone(c, 2.6))
		else:
			P.px(im, x, t, hi)
			P.px(im, x, t + 1, ClimbRock.tone(c, 3.3))


## Shades the right-hand (away from the light) side of a summit: a dithered
## darkening that grows toward the outer edge, plus a few crack lines.
static func _shade_slope(im: Image, top: PackedInt32Array, y_top: int, x0: int, x1: int, c: Dictionary) -> void:
	var dark: Color = c.deep
	dark = Color(dark.r, dark.g, dark.b, 0.34)
	for x in range(x0, mini(x1, top.size())):
		var t := clampf(float(x - x0) / float(x1 - x0), 0.0, 1.0)
		for y in range(top[x] + 2, y_top):
			if P.dither(x, y, t * 0.9):
				im.set_pixel(x, y, im.get_pixel(x, y).blend(dark))


static func _ytop(top: PackedInt32Array, x: int) -> int:
	return top[clampi(x, 0, top.size() - 1)]


## A strip of grass, dry tufts and lichen along the top of the cliff.
static func _rim_turf(im: Image, top: PackedInt32Array, x0: int, x1: int, pal: Dictionary, rng: RandomNumberGenerator, dry := false) -> void:
	for x in range(x0, x1):
		var y := _ytop(top, x)
		var g := _lit(Color("5c8f3c") if not dry else Color("b0925f"), pal)
		if rng.randf() < 0.55:
			P.px(im, x, y - 1, g)
			if rng.randf() < 0.3:
				P.px(im, x, y - 2, g.lightened(0.15))
		if rng.randf() < 0.08:
			P.px(im, x, y + 2, _lit(Color("f7a64a"), pal))


# ---- Glacier Point

static func _rim(im: Image, top: PackedInt32Array, y_top: int, pal: Dictionary, rng: RandomNumberGenerator, w: int, e: int) -> void:
	var stone := _lit(Color("b0925f"), pal)
	var stone_l := stone.lightened(0.22)
	var stone_d := stone.darkened(0.28)
	var iron := _lit(Color("2b2a30"), pal)
	var c := ClimbRock.colors("apron", pal)
	var ye := _ytop(top, 100)
	var x0 := 6
	var x1 := e - 4
	# Pines and the Glacier Point hut behind the wall.
	ClimbProps.pine(im, 16, ye + 2, 54, rng, c)
	ClimbProps.pine(im, 48, ye + 2, 42, rng, c)
	ClimbProps.pine(im, x1 - 6, ye + 2, 58, rng, c)
	_hut(im, x1 - 74, ye + 2, pal)
	# The low stone parapet: coursed blocks.
	var wt := ye - 11
	P.rect(im, x0 - 1, wt - 1, x1 - x0 + 2, 13, DARK)
	P.rect(im, x0, wt, x1 - x0, 12, stone)
	for r in range(0, 12, 4):
		P.hline(im, x0, wt + r, x1 - x0, stone_d)
		for k in range((r / 4) % 2 * 5, x1 - x0, 11):
			P.vline(im, x0 + k, wt + r, 4, stone_d)
	P.rect(im, x0, wt, x1 - x0, 2, stone_l)
	P.rect(im, x0, wt + 10, x1 - x0, 2, stone_d)
	# The iron picket fence along the parapet.
	for x in range(x0 + 2, x1 - 2, 6):
		P.rect(im, x, wt - 15, 1, 15, iron)
		P.px(im, x, wt - 16, iron.lightened(0.35))
		P.px(im, x - 1, wt - 15, iron)
		P.px(im, x + 1, wt - 15, iron)
	P.rect(im, x0, wt - 12, x1 - x0, 1, iron)
	P.rect(im, x0, wt - 4, x1 - x0, 1, iron)
	for x in range(x0, x1, 48):
		P.rect(im, x, wt - 18, 3, 18, stone)
		P.rect(im, x, wt - 18, 3, 2, stone_l)
		P.rect(im, x, wt - 19, 3, 1, DARK)
	# The thin tourist crowd, leaning on the fence and waving down.
	var shirts: Array[Color] = [Color("b3362b"), Color("6f5aa6"), Color("d8a63b"), Color("84b04a"), Color("f5eee0"), Color("d47a9b")]
	var hats: Array[Color] = [Color("d6bd88"), Color("47301f"), Color("b3362b"), Color("7e531c")]
	var xs: Array[int] = [30, 66, 116, 150, 188, 226]
	for i in xs.size():
		var o := {"shirt": shirts[i % shirts.size()], "dir": 1 if i % 2 == 0 else -1, "wave": i % 2 == 0, "pants": Color("47464d") if i % 3 else Color("86694b")}
		if i % 2 == 1:
			o["hat"] = hats[i % hats.size()]
		ClimbProps.person(im, xs[i], wt + 1, pal, o)
	# A child on someone's shoulders, and a kid holding a camera.
	P.rect(im, 119, wt - 20, 3, 3, _lit(Color("d6bd88"), pal))
	P.rect(im, 118, wt - 23, 5, 2, _lit(Color("b3362b"), pal))
	_rim_turf(im, top, x0, e, pal, rng)


## A stone-and-timber hut: the Glacier Point trading post.
static func _hut(im: Image, x: int, y: int, pal: Dictionary) -> void:
	var stone := _lit(Color("b0925f"), pal)
	var roof := _lit(Color("5e4a38"), pal)
	var timber := _lit(Color("6b4829"), pal)
	P.rect(im, x - 1, y - 21, 60, 22, DARK)
	P.rect(im, x, y - 20, 58, 20, stone)
	for r in range(0, 20, 4):
		P.hline(im, x, y - 20 + r, 58, stone.darkened(0.25))
	for k in 7:
		P.rect(im, x - 3 + k, y - 28 + k, 64 - k * 2, 1, roof if k % 2 == 0 else roof.darkened(0.2))
	P.rect(im, x - 3, y - 21, 64, 2, roof.darkened(0.3))
	P.rect(im, x + 4, y - 14, 8, 8, DARK)
	P.rect(im, x + 5, y - 13, 6, 6, _glass(pal))
	P.rect(im, x + 24, y - 12, 10, 12, timber)
	P.rect(im, x + 38, y - 14, 8, 8, DARK)
	P.rect(im, x + 39, y - 13, 6, 6, _glass(pal))
	P.rect(im, x + 46, y - 36, 5, 10, stone)
	P.rect(im, x + 45, y - 37, 7, 2, stone.darkened(0.3))


# ---- ledges and terraces

static func _tree_ledge(im: Image, top: PackedInt32Array, pal: Dictionary, rng: RandomNumberGenerator, c: Dictionary, e: int) -> void:
	ClimbProps.pine(im, 26, _ytop(top, 26) + 3, 56, rng, c)
	ClimbProps.oak(im, 60, _ytop(top, 60) + 3, 44, rng, c)
	ClimbProps.pine(im, e - 30, _ytop(top, e - 30) + 3, 62, rng, c)
	ClimbProps.pine(im, e - 62, _ytop(top, e - 62) + 3, 40, rng, c)
	ClimbProps.shrub(im, 100, _ytop(top, 100) + 3, 5, rng, pal, true)
	ClimbProps.shrub(im, e - 90, _ytop(top, e - 90) + 3, 6, rng, pal, true)
	# A sling around the biggest tree, the climbers' anchor.
	var tx := 26
	var ty := _ytop(top, tx) + 1
	P.hline(im, tx - 2, ty - 6, 5, _lit(Color("d8a63b"), pal))
	P.px(im, tx - 2, ty - 5, _lit(Color("d8a63b"), pal))
	P.rect(im, tx - 1, ty - 4, 3, 2, _lit(Color("bdb8ae"), pal))
	for i in 4:
		ClimbProps.flowers(im, 130 + i * 20, _ytop(top, 130 + i * 20) + 1, rng, pal)
	_rim_turf(im, top, 0, e, pal, rng)


static func _anchor(im: Image, top: PackedInt32Array, y_top: int, pal: Dictionary, rng: RandomNumberGenerator, c: Dictionary, e: int) -> void:
	# Swan Slab's top: a two-bolt anchor with chains and a rappel ring, the
	# walk-off trail sign, and oaks to sit under.
	ClimbProps.oak(im, 22, _ytop(top, 22) + 3, 56, rng, c)
	ClimbProps.pine(im, e - 24, _ytop(top, e - 24) + 3, 60, rng, c)
	ClimbProps.oak(im, e - 56, _ytop(top, e - 56) + 3, 40, rng, c)
	var steel := _lit(Color("bdb8ae"), pal)
	var steel_d := _lit(Color("6a6a70"), pal)
	for i in 2:
		var bx := 177 + i * 32
		var by := y_top - 15
		P.rect(im, bx - 2, by - 1, 6, 5, DARK)
		P.rect(im, bx - 1, by, 4, 3, steel)
		P.px(im, bx - 1, by, steel.lightened(0.3))
		P.px(im, bx + 2, by + 2, steel_d)
		P.line(im, Vector2(bx + 1, by + 3), Vector2(193, y_top - 18 + i * 0), steel_d)
	P.ellipse(im, 193, y_top - 19, 4, 3, DARK)
	P.ellipse(im, 193, y_top - 19, 3, 2, steel)
	P.ellipse(im, 193, y_top - 19, 1.5, 1, DARK)
	ClimbProps.board_sign(im, 112, _ytop(top, 112) + 4, "CAMP 4 >", pal, 8)
	for i in 3:
		ClimbProps.fern(im, 60 + i * 20, _ytop(top, 60 + i * 20) + 2, 5, pal)
	_rim_turf(im, top, 0, e, pal, rng, true)


static func _terrace(im: Image, top: PackedInt32Array, pal: Dictionary, rng: RandomNumberGenerator, c: Dictionary, e: int, style: String) -> void:
	# Forested terraces above the walls: pines, oaks and manzanita.
	var xs: Array[int] = [20, 52, 88, 150, 205, e - 60, e - 30]
	for i in xs.size():
		var x := xs[i]
		var y := _ytop(top, x) + 3
		var hgt := rng.randi_range(30, 54)
		if style == "arches" and i % 3 == 1:
			ClimbProps.oak(im, x, y, hgt, rng, c)
		elif style == "column" and i % 2 == 1:
			ClimbProps.gnarled(im, x, y, hgt / 2 + 6, rng, c)
		else:
			ClimbProps.pine(im, x, y, hgt, rng, c)
	for i in 4:
		var sx := 36 + i * 52 + rng.randi_range(-6, 6)
		ClimbProps.shrub(im, sx, _ytop(top, sx) + 3, rng.randi_range(4, 7), rng, pal, true)
	match style:
		"column":
			# Gear dropped at the summit: packs, a water bottle and a rope coil.
			var gx := 112
			var gy := _ytop(top, gx) + 2
			P.rect(im, gx - 1, gy - 9, 10, 10, DARK)
			P.rect(im, gx, gy - 8, 8, 8, _lit(Color("6f5aa6"), pal))
			P.rect(im, gx, gy - 8, 8, 2, _lit(Color("6f5aa6"), pal))
			P.rect(im, gx + 11, gy - 7, 9, 8, DARK)
			P.rect(im, gx + 12, gy - 6, 7, 6, _lit(Color("b3362b"), pal))
			P.ellipse(im, gx + 28, gy - 1, 5, 2.5, DARK)
			P.ellipse(im, gx + 28, gy - 1, 4, 1.7, _lit(Color("d8a63b"), pal))
			ClimbProps.person(im, 138, _ytop(top, 138) + 1, pal, {"shirt": Color("437f45"), "wave": true, "hat": Color("d8a63b"), "dir": -1})
		"arches":
			ClimbProps.board_sign(im, 108, _ytop(top, 108) + 4, "N DOME", pal, 8)
		"chimney":
			# The mouth of the chimney: a dark notch the climbers pop out of.
			var mx := 168
			P.rect(im, mx - 6, _ytop(top, mx) + 2, 12, 8, _lit(Color("15141c"), pal))
		"roof":
			pass
	_rim_turf(im, top, 0, e, pal, rng)


static func _el_cap(im: Image, top: PackedInt32Array, pal: Dictionary, rng: RandomNumberGenerator, c: Dictionary, e: int) -> void:
	# The summit of El Capitan: a long granite plateau, a few Jeffrey pines and
	# junipers, two climbers celebrating, and the long drop behind you.
	ClimbProps.pine(im, 24, _ytop(top, 24) + 3, 54, rng, c)
	ClimbProps.gnarled(im, 62, _ytop(top, 62) + 3, 22, rng, c)
	ClimbProps.pine(im, 96, _ytop(top, 96) + 3, 40, rng, c)
	ClimbProps.pine(im, e - 24, _ytop(top, e - 24) + 3, 62, rng, c)
	ClimbProps.gnarled(im, e - 64, _ytop(top, e - 64) + 3, 20, rng, c)
	var hx := 176
	var hy := _ytop(top, hx) + 2
	ClimbProps.person(im, hx, hy, pal, {"shirt": Color("b3362b"), "wave": true, "hat": Color("d8a63b"), "dir": 1})
	ClimbProps.person(im, hx + 12, hy, pal, {"shirt": Color("3a86a8"), "wave": true, "dir": -1, "pants": Color("47464d")})
	# A fluttering flag on a pole.
	var fx := 222
	var fy := _ytop(top, fx) + 2
	P.rect(im, fx, fy - 26, 1, 26, _lit(Color("6b4829"), pal))
	P.rect(im, fx + 1, fy - 26, 9, 5, _lit(Color("b3362b"), pal))
	P.rect(im, fx + 1, fy - 26, 9, 1, _lit(Color("d9772a"), pal))
	P.px(im, fx + 10, fy - 24, _lit(Color("b3362b"), pal))
	ClimbProps.cairn(im, 130, _ytop(top, 130) + 2, c, 2)
	for i in 8:
		var gx := rng.randi_range(8, e - 10)
		ClimbProps.tuft(im, gx, _ytop(top, gx) + 1, rng, pal, true)
	_rim_turf(im, top, 0, e, pal, rng, true)


# ---- spires, domes and ridges

static func _summit(im: Image, top: PackedInt32Array, y_top: int, cx: int, pal: Dictionary, rng: RandomNumberGenerator, c: Dictionary, peak: bool) -> void:
	# Lichen and cracks on the pinnacle, then a cairn on the top block.
	for i in 22:
		var y := y_top - rng.randi_range(8, 96)
		var x := cx + rng.randi_range(-20, 20)
		if x > 0 and x < top.size() and y > _ytop(top, x) + 4:
			P.px(im, x, y, c.lichen_o if i % 3 == 0 else c.lichen_g)
	var tx := cx + (4 if peak else 0)
	var ty := _ytop(top, tx)
	ClimbProps.cairn(im, tx, ty + 1, c, 2 if peak else 1)
	# Slings and a rappel anchor on the horn just below.
	var sling := _lit(Color("d8a63b"), pal)
	var rx := cx - (8 if peak else 6)
	var ry := _ytop(top, rx) + 5
	P.rect(im, rx, ry, 4, 2, sling)
	P.vline(im, rx + 1, ry + 2, 7, sling)
	P.rect(im, rx, ry + 9, 3, 2, _lit(Color("bdb8ae"), pal))
	P.px(im, rx + 4, ry + 3, sling)
	P.px(im, rx + 5, ry + 4, sling)
	if peak:
		# The summit register in an ammo can, and a marmot-sized pine below.
		P.rect(im, tx + 8, ty - 4, 6, 4, DARK)
		P.rect(im, tx + 9, ty - 3, 4, 2, _lit(Color("437f45"), pal))
		var gx := cx - 36
		ClimbProps.gnarled(im, gx, _ytop(top, gx) + 4, 14, rng, c)
	else:
		# A tuft of krummholz clinging to the ledge below.
		var kx := cx + 24
		ClimbProps.ledge_plant(im, kx, _ytop(top, kx) + 3, ["krummholz"], rng, c)
	var rim := 18
	for i in 5:
		var x := 6 + i * 8
		ClimbProps.tuft(im, x, y_top - 4, rng, pal, true)
	var _u := rim


static func _dome(im: Image, top: PackedInt32Array, y_top: int, cx: int, pal: Dictionary, rng: RandomNumberGenerator, c: Dictionary, e: int) -> void:
	# Half Dome's rounded top: stunted pines in the cracks, and the cables
	# running down the far shoulder with tiny hikers on them.
	for i in 6:
		var x := 20 + i * 26 + rng.randi_range(-6, 6)
		if x < cx + 20:
			ClimbProps.gnarled(im, x, _ytop(top, x) + 3, rng.randi_range(10, 18), rng, c)
	var iron := _lit(Color("2b2a30"), pal)
	var x0 := cx + 30
	var prev_x := x0
	for x in range(x0, e - 8, 3):
		var y := _ytop(top, x)
		if (x - x0) % 12 == 0:
			P.rect(im, x, y - 7, 1, 7, iron)
			P.px(im, x, y - 8, iron.lightened(0.4))
		P.px(im, x, y - 6, iron)
		P.px(im, x, y - 3, iron)
		P.px(im, x + 1, _ytop(top, x + 1) - 6, iron)
		P.px(im, x + 1, _ytop(top, x + 1) - 3, iron)
		prev_x = x
	var sh: Array[Color] = [Color("d8a63b"), Color("b3362b"), Color("3a86a8")]
	for i in 3:
		var hx := cx + 62 + i * 22
		ClimbProps.person(im, hx, _ytop(top, hx) - 1, pal, {"shirt": sh[i], "hat": Color("e4ddcc"), "dir": 1 if i != 1 else -1, "pack": Color("2c5c37"), "wave": i == 2})
	# Summit gear and a plaque; the Visor of the Diving Board sticks out left.
	ClimbProps.cairn(im, cx - 40, _ytop(top, cx - 40) + 1, c, 1)
	var _u := prev_x
	_rim_turf(im, top, 0, e, pal, rng, true)


static func _ridge(im: Image, top: PackedInt32Array, y_top: int, cx: int, pal: Dictionary, rng: RandomNumberGenerator, c: Dictionary, e: int) -> void:
	# A snowy ridge: a thick cornice along the crest, rime, and ice axes.
	var snow := _lit(Color("d6f1ee"), pal)
	var snow_s := _lit(Color("63b3c6"), pal)
	var snow_m := _lit(Color("d6f1ee"), pal)
	for x in range(0, mini(e + 6, top.size())):
		var t := top[x]
		var d := top[mini(x + 1, top.size() - 1)] - top[maxi(x - 1, 0)]
		var depth := 5 + int(P.noise(x / 3, 1, 4) * 3.0)
		for k in depth:
			var col := snow if k < 2 else (snow_m if k < depth - 2 else snow_s)
			if d > 1 and k > 1:
				col = snow_s if k > 2 else snow_m
			P.px(im, x, t + k, col)
		# A dripping lip on the cornice.
		if P.noise(x, 5, 9) < 0.14:
			P.px(im, x, t + depth, snow_m)
			P.px(im, x, t + depth + 1, snow_s)
	# Windblown snow patches below the crest.
	for i in 8:
		var sx := rng.randi_range(10, e - 10)
		var sy := _ytop(top, sx) + rng.randi_range(14, 60)
		P.ellipse(im, sx, sy, rng.randf_range(6, 14), 2.2, snow_m)
		P.ellipse(im, sx - 2, sy - 1, 4, 1.0, snow)
	# Axes planted in the summit snow and a flag of cloth.
	var ax := 60
	var ay := _ytop(top, ax) + 2
	ClimbProps.ice_axe(im, ax, ay, pal, 1)
	ClimbProps.ice_axe(im, ax + 10, ay + 1, pal, -1)
	P.rect(im, ax + 20, ay - 24, 1, 24, _lit(Color("6b4829"), pal))
	P.rect(im, ax + 21, ay - 24, 8, 5, _lit(Color("b3362b"), pal))
	P.px(im, ax + 29, ay - 22, _lit(Color("b3362b"), pal))
	ClimbProps.cairn(im, 108, _ytop(top, 108) + 2, c, 1)
