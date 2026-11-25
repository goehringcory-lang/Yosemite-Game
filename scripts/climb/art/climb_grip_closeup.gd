class_name ClimbGripCloseup
extends RefCounted
## Pixel-art close-ups of a hand (or foot) on its hold, 64x64, shown in a small
## panel beside the climber when a hold is taken: a crimp's tented knuckles, a
## jug's hooked fingers, a hand jam's taped back in a crack. The camera is behind
## the climber, so mostly we see the back of the hand. Light is from the upper
## left, every material has a lit tone, a base, a shade and a dark colored rim
## (never pure black); no anti-aliasing. The right hand is painted, the left is
## its mirror.

const SIZE := 64
const P := preload("res://scripts/climb/art/climb_paint.gd")
const TAPE := Color("f5eee0")
const TAPE_SHADE := Color("bdb8ae")
const SHOE := Color("b3362b")
const RUBBER := Color("2b2a30")

static var _cache := {}
# Palette for the panel being painted (set by image()).
static var _sk: Color
static var _sl: Color
static var _ss: Color
static var _sd: Color
static var _sr: Color
static var _r: Color
static var _rl: Color
static var _rh: Color
static var _rd: Color
static var _rdd: Color
static var _rk: Color
static var _chalk_rect := Rect2i(14, 10, 38, 34)
static var _mir := false


## A 64x64 RGBA close-up of a hand of [param shape] (HoldShape.HANDS) on its
## hold, or (foot = true) a foot of technique [param shape] (HoldShape.FEET).
## right = false mirrors it for the left hand/foot. [param rock] is the wall's
## mid color. [param chalk] adds chalk on the fingers.
static func image(shape: String, right: bool, rock: Color, chalk := false, foot := false) -> Image:
	var key := [shape, right, rock.to_html(), chalk, foot, ClimbSprites.SKIN.to_html(),
			ClimbSprites.SKIN_SHADE.to_html(), ClimbSprites.SKIN_LIT.to_html(), ClimbSprites.SHIRT.to_html(),
			ClimbSprites.PANTS.to_html()]
	if _cache.has(key):
		return _cache[key]
	var im := _paint(shape, right, rock, chalk, foot)
	_cache[key] = im
	return im


# ---------------------------------------------------------------- composition

static func _paint(shape: String, right: bool, rock: Color, chalk: bool, foot: bool) -> Image:
	_setup(rock)
	var ice := shape == "tool" and not foot
	var bg := P.make(SIZE, SIZE)
	var hand := P.make(SIZE, SIZE)
	var fg := P.make(SIZE, SIZE)
	_mir = false
	_chalk_rect = Rect2i(14, 10, 38, 34)
	if foot:
		match shape:
			"edge": _foot_edge(bg, hand, fg)
			"smear": _foot_smear(bg, hand, fg)
			"toe_jam": _foot_toe_jam(bg, hand, fg)
			_: _foot_step(bg, hand, fg)
	else:
		match shape:
			"jug": _jug(bg, hand, fg)
			"edge": _edge(bg, hand, fg)
			"crimp": _crimp(bg, hand, fg)
			"pinch": _pinch(bg, hand, fg)
			"sidepull": _side(bg, hand, fg, false)
			"gaston": _side(bg, hand, fg, true)
			"undercling": _undercling(bg, hand, fg)
			"palm": _palm(bg, hand, fg)
			"finger_jam": _finger_jam(bg, hand, fg)
			"hand_jam": _hand_jam(bg, hand, fg)
			"fist_jam": _fist_jam(bg, hand, fg)
			_: _tool(bg, hand, fg)
	if chalk and not foot and shape != "tool":
		_chalk(hand, _chalk_rect)
	var out := P.make(SIZE, SIZE)
	_grain(out, ice)
	P.stamp(out, bg, 0, 0)
	P.stamp(out, hand, 0, 0)
	P.stamp(out, fg, 0, 0)
	if not right:
		out.flip_x()
	_frame(out, ice)
	return out


static func _setup(rock: Color) -> void:
	_sk = ClimbSprites.SKIN
	_sl = ClimbSprites.SKIN_LIT.lightened(0.26)
	_ss = ClimbSprites.SKIN_SHADE.darkened(0.06)
	_sd = ClimbSprites.SKIN_SHADE.darkened(0.28)
	_sr = _dk(ClimbSprites.SKIN_SHADE, 0.6)
	_r = rock
	_rl = rock.lightened(0.18)
	_rh = rock.lightened(0.36)
	_rd = rock.darkened(0.22)
	_rdd = rock.darkened(0.42)
	_rk = _dk(rock, 0.66)


## A darker, more saturated, slightly warmer shade of [param c].
static func _dk(c: Color, amount: float) -> Color:
	var d := c.darkened(amount)
	return Color.from_hsv(fposmod(d.h - 0.012, 1.0), minf(1.0, d.s * 1.2 + 0.08), d.v)


## Granite: the wall color with a top-left light gradient, blotches, dark flecks
## and light specks. Ice: blue-white with faint streaks.
static func _grain(im: Image, ice := false) -> void:
	for y in SIZE:
		for x in SIZE:
			var g := float(x + y) / 126.0
			var col: Color
			if ice:
				col = Color("d9eef8").lerp(Color("8dbbd8"), g)
				var s := P.smooth_noise(x * 0.22, y * 0.1, 11)
				if s > 0.62:
					col = col.lightened(0.12)
				elif s < 0.3:
					col = col.darkened(0.08)
				var n := P.noise(x, y, 5)
				if n > 0.97:
					col = Color.WHITE
			else:
				col = _r.lightened(lerpf(0.12, -0.13, g))
				var b := P.smooth_noise(x * 0.18, y * 0.18, 3) - 0.5
				col = col.lightened(b * 0.18)
				var n := P.noise(x, y, 7)
				var c := P.noise(x >> 1, y >> 1, 9)
				if n < 0.07 or (c < 0.04 and n < 0.5):
					col = col.darkened(0.3)
				elif n > 0.95 or (c > 0.97 and n > 0.5):
					col = col.lightened(0.34)
				elif n > 0.88:
					col = col.lightened(0.1)
			im.set_pixel(x, y, col)


## A soft 1 px dark frame; the corners are cut.
static func _frame(im: Image, ice: bool) -> void:
	var f := _dk(Color("6a8aa8"), 0.7) if ice else _rk
	for i in SIZE:
		for p in [Vector2i(i, 0), Vector2i(i, SIZE - 1), Vector2i(0, i), Vector2i(SIZE - 1, i)]:
			im.set_pixelv(p, im.get_pixelv(p).lerp(f, 0.85))
	for p in [Vector2i(1, 1), Vector2i(SIZE - 2, 1), Vector2i(1, SIZE - 2), Vector2i(SIZE - 2, SIZE - 2)]:
		im.set_pixelv(p, im.get_pixelv(p).lerp(f, 0.5))
	for p in [Vector2i(0, 0), Vector2i(SIZE - 1, 0), Vector2i(0, SIZE - 1), Vector2i(SIZE - 1, SIZE - 1)]:
		im.set_pixelv(p, Color(0, 0, 0, 0))
	for p in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(SIZE - 2, 0), Vector2i(SIZE - 1, 1),
			Vector2i(0, SIZE - 2), Vector2i(1, SIZE - 1), Vector2i(SIZE - 1, SIZE - 2), Vector2i(SIZE - 2, SIZE - 1)]:
		im.set_pixelv(p, im.get_pixelv(p).lerp(f, 0.6))


static func _chalk(im: Image, r: Rect2i) -> void:
	var white := Color("f5eee0")
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := im.get_pixel(x, y)
			if c.a < 0.9 or c == _sr:
				continue
			var n := P.noise(x, y, 21)
			var fall := 1.0 - float(y - r.position.y) / float(r.size.y)
			if n < 0.28 + fall * 0.5:
				im.set_pixel(x, y, c.lerp(white, 0.78 if n < 0.18 + fall * 0.3 else 0.5))


# ------------------------------------------------------------------ primitives

static func _fill(im: Image, test: Callable, r: Rect2i, base: Color, lit: Color, shade: Color, rim := Color(0, 0, 0, 0)) -> void:
	r = r.grow(1).intersection(Rect2i(0, 0, SIZE, SIZE))
	var inside := {}
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if test.call(x, y):
				inside[Vector2i(x, y)] = true
	for p: Vector2i in inside:
		var col := base
		if not inside.has(p + Vector2i(-1, 0)) or not inside.has(p + Vector2i(0, -1)):
			col = lit
		if not inside.has(p + Vector2i(1, 0)) or not inside.has(p + Vector2i(0, 1)):
			col = shade
		if col == base and (not inside.has(p + Vector2i(2, 0)) or not inside.has(p + Vector2i(0, 2))) and base.a > 0.0:
			col = base.lerp(shade, 0.4)
		P.px(im, p.x, p.y, col)
	if rim.a > 0.0:
		for p: Vector2i in inside:
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if not inside.has(p + d):
					P.px(im, p.x + d.x, p.y + d.y, rim)


static func _v(x: float, y: float) -> Vector2:
	return Vector2(SIZE - 1 - x if _mir else x, y)


static func _cap(im: Image, a: Vector2, b: Vector2, w: float, base: Color, lit: Color, shade: Color, rim := Color(0, 0, 0, 0)) -> void:
	var r := Rect2i(Rect2(a, Vector2.ZERO).expand(b).grow(w * 0.5 + 1.0))
	var rad := w * 0.5
	var ab := b - a
	var l2 := maxf(ab.length_squared(), 0.0001)
	_fill(im, func(x: int, y: int) -> bool:
		var p := Vector2(x + 0.5, y + 0.5)
		var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
		return p.distance_to(a + ab * t) <= rad, r, base, lit, shade, rim)


static func _ell(im: Image, cx: float, cy: float, rx: float, ry: float, base: Color, lit: Color, shade: Color, rim := Color(0, 0, 0, 0)) -> void:
	var r := Rect2i(int(cx - rx) - 1, int(cy - ry) - 1, int(rx * 2) + 3, int(ry * 2) + 3)
	_fill(im, func(x: int, y: int) -> bool:
		var dx := (x + 0.5 - cx) / rx
		var dy := (y + 0.5 - cy) / ry
		return dx * dx + dy * dy <= 1.0, r, base, lit, shade, rim)


static func _poly(im: Image, pts: PackedVector2Array, base: Color, lit: Color, shade: Color, rim := Color(0, 0, 0, 0)) -> void:
	var bb := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		bb = bb.expand(p)
	_fill(im, func(x: int, y: int) -> bool:
		return Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), pts), Rect2i(bb), base, lit, shade, rim)


static func _box(im: Image, x: int, y: int, w: int, h: int, base: Color, lit: Color, shade: Color, rim := Color(0, 0, 0, 0)) -> void:
	_fill(im, func(px: int, py: int) -> bool:
		return px >= x and py >= y and px < x + w and py < y + h, Rect2i(x, y, w, h), base, lit, shade, rim)


static func _pts(arr: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, arr.size(), 2):
		out.append(_v(arr[i], arr[i + 1]))
	return out


# ---- materials

static func _scap(im: Image, a: Vector2, b: Vector2, w: float) -> void:
	_cap(im, a, b, w, _sk, _sl, _ss, _sr)


static func _sell(im: Image, cx: float, cy: float, rx: float, ry: float) -> void:
	_ell(im, cx, cy, rx, ry, _sk, _sl, _ss, _sr)


static func _spoly(im: Image, arr: Array) -> void:
	_poly(im, _pts(arr), _sk, _sl, _ss, _sr)


static func _hold_cap(im: Image, a: Vector2, b: Vector2, w: float) -> void:
	_cap(im, a, b, w, _rl, _rh, _rd, _rk)


static func _hold_poly(im: Image, arr: Array) -> void:
	_poly(im, _pts(arr), _rl, _rh, _rd, _rk)


static func _hold_ell(im: Image, cx: float, cy: float, rx: float, ry: float) -> void:
	_ell(im, cx, cy, rx, ry, _rl, _rh, _rd, _rk)


static func _tape_poly(im: Image, arr: Array) -> void:
	_poly(im, _pts(arr), TAPE, TAPE.lightened(0.3), TAPE_SHADE, Color("7c6f5e"))


static func _sleeve_poly(im: Image, arr: Array) -> void:
	var s := ClimbSprites.SHIRT
	_poly(im, _pts(arr), s, s.lightened(0.2), s.darkened(0.25), _dk(s, 0.6))


static func _sleeve_cap(im: Image, a: Vector2, b: Vector2, w: float) -> void:
	var s := ClimbSprites.SHIRT
	_cap(im, a, b, w, s, s.lightened(0.2), s.darkened(0.25), _dk(s, 0.6))


## Forearm coming up from the bottom edge with the sleeve cuff at the edge.
static func _arm_up(im: Image, x: float, top: float, w := 17.0) -> void:
	_scap(im, _v(x, 72), _v(x, top), w)
	_sleeve_poly(im, [x - w / 2 - 2, 57, x + w / 2 + 2, 57, x + w / 2 + 2, 66, x - w / 2 - 2, 66])
	var s := ClimbSprites.SHIRT
	for i in int(w) + 4:
		P.px(im, int(_v(x - w / 2 - 1 + i, 0).x), 59, s.lightened(0.34))
		P.px(im, int(_v(x - w / 2 - 1 + i, 0).x), 61, s.darkened(0.12))


## Skin the arm so it reads as muscle: a forearm tendon and a shadow.
static func _arm_detail(im: Image, x: float, y0: int, y1: int) -> void:
	for y in range(y0, y1):
		P.px(im, int(_v(x + 2, 0).x), y, _ss)
		if y % 3 != 0:
			P.px(im, int(_v(x - 3, 0).x), y, _sl)


static func _finger(im: Image, x: float, y0: float, y1: float, w := 5.0, bend := 0.0) -> void:
	_scap(im, _v(x, y0), _v(x + bend, y1), w)


## Knuckle highlight pixels and a tendon line between fingers.
static func _knuckles(im: Image, xs: Array, y: int) -> void:
	for x: float in xs:
		var px := int(_v(x, 0).x)
		P.px(im, px - 1, y, _sl.lightened(0.15))
		P.px(im, px, y, _sl.lightened(0.15))
		P.px(im, px + 1, y + 1, _ss)


# ------------------------------------------------------------------- the hands

static func _jug(B: Image, H: Image, F: Image) -> void:
	# A fat hold with a deep incut under its lip.
	_hold_poly(B, [-4, 8, 8, 4, 32, 2, 56, 4, 68, 8, 68, 40, 58, 46, 32, 48, 6, 46, -4, 40])
	for i in 12:
		P.px(B, int(P.noise(i, 3, 8) * 60) + 2, 28 + int(P.noise(i, 4, 8) * 16), _rd)
	_arm_up(H, 32, 48)
	_arm_detail(H, 32, 50, 57)
	_spoly(H, [20, 44, 22, 38, 42, 38, 44, 44, 42, 54, 40, 59, 24, 59, 22, 54])
	_scap(H, _v(21, 52), _v(14, 36), 6.0)
	_sell(H, 14.5, 35, 3.2, 3.0)
	for f in [[23.0, 12.0, -1.0], [29.0, 9.0, 0.0], [35.0, 11.0, 0.0], [41.0, 15.0, 1.0]]:
		_finger(H, f[0], 44, f[1], 5.0, f[2])
		P.px(H, int(_v(f[0], 0).x), 31, _ss)
		P.px(H, int(_v(f[0], 0).x) + 1, 31, _ss)
		P.px(H, int(_v(f[0], 0).x), 23, _ss)
	_knuckles(H, [23.0, 29.0, 35.0, 41.0], 41)
	# The lip curls over the fingertips; its shadow swallows them.
	for y in range(0, 22):
		var a := 1.0 if y < 14 else (1.0 - float(y - 14) / 9.0)
		for x in SIZE:
			var k := _rk if y < 15 else _rdd
			P.px(F, x, y, Color(k, a * 0.92))
	_hold_poly(F, [-4, -4, 68, -4, 68, 11, 58, 14, 32, 16, 6, 14, -4, 11])
	for i in 7:
		P.px(F, 6 + i * 9, 6 + i % 3, _rd)
	_chalk_rect = Rect2i(14, 12, 38, 24)


static func _edge(B: Image, H: Image, F: Image) -> void:
	# A flat edge, 4-5 px: lit top, dark shadow under it.
	_box(B, -2, 16, 68, 6, _rl, _rh, _rd, _rk)
	P.hline(B, 0, 23, 64, _rdd)
	P.hline(B, 0, 24, 64, _rd)
	_arm_up(H, 32, 50)
	_arm_detail(H, 32, 52, 57)
	_spoly(H, [20, 46, 22, 42, 42, 42, 44, 46, 42, 55, 40, 59, 24, 59, 22, 55])
	_scap(H, _v(21, 54), _v(13, 42), 6.0)
	for f in [[23.0, 20.0, -1.0], [29.0, 18.0, 0.0], [35.0, 19.0, 0.0], [41.0, 23.0, 1.0]]:
		_finger(H, f[0], 46, f[1], 5.0, f[2])
		P.px(H, int(_v(f[0], 0).x), f[1] + 4, _ss)
		P.hline(H, int(_v(f[0], 0).x) + (f[2] as int) - 1, int(f[1]) + 1, 3, Color("f1dcc6"))
	_knuckles(H, [23.0, 29.0, 35.0, 41.0], 44)
	_chalk_rect = Rect2i(14, 16, 38, 26)


static func _crimp(B: Image, H: Image, F: Image) -> void:
	# A tiny 2 px edge.
	_box(B, -2, 17, 68, 2, _rl, _rh, _rd, _rk)
	P.hline(B, 0, 20, 64, _rdd)
	P.hline(B, 0, 21, 64, _rd)
	_arm_up(H, 32, 52)
	_arm_detail(H, 32, 54, 57)
	_spoly(H, [19, 50, 21, 38, 43, 38, 45, 50, 42, 57, 40, 61, 24, 61, 22, 57])
	var ks := [[23.0, 33.0], [29.0, 31.0], [35.0, 31.0], [41.0, 33.0]]
	for k in ks:
		var kx := int(_v(k[0], 0).x)
		# fingertip pad on the edge, the middle bone dropping to the knuckle
		_ell(H, kx, 21, 2.6, 2.4, _ss, _sk, _sd, _sr)
		_cap(H, _v(k[0], 22), _v(k[0], k[1] - 2.0), 4.0, _sk, _sl, _ss, _sr)
	for k in ks:
		var kx := int(_v(k[0], 0).x)
		var ky: int = k[1]
		_ell(H, kx, ky + 1, 3.6, 3.6, _sk, _sl, _ss, _sr)
		P.hline(H, kx - 2, ky - 1, 4, _sl.lightened(0.4))
		P.hline(H, kx - 1, ky - 2, 3, _sl.lightened(0.55))
		P.hline(H, kx - 1, ky + 4, 4, _sd)
		P.hline(H, kx - 1, ky + 5, 4, _sd)
	# thumb wrapped over the index finger
	_scap(H, _v(19, 54), _v(25, 38), 6.0)
	_ell(H, _v(27, 0).x, 33, 3.8, 3.4, _sk, _sl, _ss, _sr)
	P.hline(H, int(_v(25, 0).x), 31, 3, _sl.lightened(0.5))
	P.px(H, int(_v(28, 0).x), 31, _sl.lightened(0.3))
	_chalk_rect = Rect2i(14, 18, 38, 22)


static func _pinch(B: Image, H: Image, F: Image) -> void:
	_scap(H, _v(36, 72), _v(36, 56), 17.0)
	_sleeve_poly(H, [25, 57, 47, 57, 47, 66, 25, 66])
	_spoly(H, [20, 56, 24, 48, 36, 46, 50, 34, 54, 40, 54, 52, 46, 59, 28, 59])
	# fingers stacked on the right, thumb on the left
	for i in 4:
		var y := 12.0 + i * 6.0
		_cap(H, _v(52, y + 12), _v(37, y), 5.0, _sk, _sl, _ss, _sr)
		P.px(H, int(_v(45, 0).x), int(y) + 6, _ss)
	_scap(H, _v(21, 56), _v(28, 28), 6.5)
	_ell(H, _v(28, 0).x, 27, 3.4, 3.0, _sk, _sl, _ss, _sr)
	P.hline(H, 26, 25, 3, _sl.lightened(0.5))
	P.px(H, 25, 40, _ss)
	# the rib in front: a rough knob of rock
	_poly(F, _pts([30, 6, 33, 3, 36, 3, 39, 6, 39, 46, 36, 50, 32, 50, 30, 46]), _rl, _rh, _rd, _rk)
	for y in range(8, 46, 3):
		P.px(F, 33 + (y % 2), y, _rd)
	_chalk_rect = Rect2i(30, 8, 24, 34)


static func _side(B: Image, H: Image, F: Image, gaston: bool) -> void:
	_mir = gaston
	var shaft := PackedVector2Array()
	_hold_poly(B, [-4, 2, 14, 2, 17, 6, 18, 50, 14, 54, -4, 54])
	for i in 6:
		P.vline(B, 10 + (i % 2) * 2, 6 + i * 8, 4, _rd)
	# forearm out of the lower right corner
	_scap(H, _v(46, 38), _v(76, 66), 15.0)
	_sleeve_cap(H, _v(62, 54), _v(84, 76), 19.0)
	_spoly(H, [34, 20, 40, 18, 48, 22, 50, 32, 49, 44, 42, 50, 34, 47, 32, 34])
	var rows := [22.0, 28.0, 34.0, 40.0] if not gaston else [20.0, 26.0, 32.0, 38.0]
	for y: float in rows:
		_cap(H, _v(40, y + 1), _v(20, y), 5.0, _sk, _sl, _ss, _sr)
		P.px(H, int(_v(30, 0).x), int(y) + 1, _ss)
		P.vline(H, int(_v(22, 0).x), int(y), 2, Color("f1dcc6"))
	if gaston:
		# thumb down
		_scap(H, _v(36, 44), _v(26, 52), 6.0)
		_sell(H, _v(26, 0).x, 51.5, 3.0, 3.0)
	else:
		_scap(H, _v(38, 20), _v(26, 12), 6.0)
		_sell(H, _v(26, 0).x, 12, 3.0, 3.0)
	_knuckles(H, [], 0)
	# the lip over the fingertips
	var lip_a := _v(17, 6)
	var lip_b := _v(17, 52)
	_hold_cap(F, lip_a, lip_b, 5.0)
	if gaston:
		# the edge faces away: the lip is on the far side
		pass
	_mir = false
	_chalk_rect = Rect2i(18, 16, 30, 30)
	if gaston:
		_chalk_rect = Rect2i(16, 14, 30, 30)


static func _undercling(B: Image, H: Image, F: Image) -> void:
	# An overhanging flake with a dark slot under it.
	_hold_poly(B, [-4, -4, 68, -4, 68, 14, 54, 19, 32, 21, 10, 19, -4, 14])
	for y in range(22, 36):
		var t := float(y - 22) / 14.0
		for x in SIZE:
			P.px(B, x, y, _rk.lerp(_rd, t * t))
	_arm_up(H, 32, 50)
	_arm_detail(H, 32, 52, 57)
	# the palm faces up: lighter, creased
	var pk := _sk.lightened(0.1)
	var pl := _sl.lightened(0.1)
	_poly(H, _pts([20, 46, 22, 40, 42, 40, 44, 46, 42, 54, 40, 59, 24, 59, 22, 54]), pk, pl, _ss, _sr)
	_ell(H, _v(26, 0).x, 49, 4.5, 3.5, pl, pl.lightened(0.1), pk)
	P.hline(H, 25, 45, 14, _ss)
	P.hline(H, 28, 49, 8, _ss)
	_scap(H, _v(21, 52), _v(15, 34), 6.0)
	for f in [[23.0, 26.0, -1.0], [29.0, 23.0, 0.0], [35.0, 24.0, 0.0], [41.0, 28.0, 1.0]]:
		_cap(H, _v(f[0], 42), _v(f[0] + f[2], f[1]), 5.0, pk, pl, _ss, _sr)
		P.hline(H, int(_v(f[0], 0).x) - 1, 38, 3, _ss)
		P.hline(H, int(_v(f[0], 0).x) - 1, 32, 3, _ss)
	# the flake's lip in front of the fingertips
	_hold_poly(F, [-4, -4, 68, -4, 68, 14, 54, 19, 32, 21, 10, 19, -4, 14])
	for x in SIZE:
		P.px(F, x, 22, Color(_rk, 0.6))
	_chalk_rect = Rect2i(16, 28, 34, 14)


static func _palm(B: Image, H: Image, F: Image) -> void:
	# A blank slab with friction dimples and a hairline.
	for i in 16:
		var x := int(P.noise(i, 1, 33) * 60) + 2
		var y := int(P.noise(i, 2, 33) * 60) + 2
		P.px(B, x, y, _rdd)
		P.px(B, x + 1, y + 1, _rh)
	P.line(B, Vector2(4, 12), Vector2(18, 20), _rd)
	P.line(B, Vector2(46, 8), Vector2(60, 16), _rd)
	P.px(B, 6, 14, _rh)
	# shadow of the palm on the slab
	_arm_up(H, 32, 56, 17.0)
	_spoly(H, [20, 48, 20, 36, 26, 30, 38, 30, 44, 36, 44, 48, 42, 56, 38, 60, 26, 60, 22, 56])
	_ell(H, 32, 55, 10, 5, _sk, _sl, _ss, _sr)
	_scap(H, _v(21, 48), _v(9, 36), 6.0)
	_sell(H, 8.5, 35.5, 3.3, 3.0)
	var fans := [[23.0, -0.5, 21.0], [29.0, -0.17, 24.0], [35.0, 0.17, 22.0], [41.0, 0.5, 17.0]]
	for f in fans:
		var base := _v(f[0], 34)
		var dir := Vector2(sin(f[1]), -cos(f[1]))
		var tip: Vector2 = base + dir * float(f[2])
		_cap(H, base, tip, 5.0, _sk, _sl, _ss, _sr)
		_ell(H, tip.x, tip.y, 2.5, 2.5, _sk, _sl, _ss, _sr)
		var mid: Vector2 = base + dir * (float(f[2]) * 0.5)
		P.px(H, int(mid.x), int(mid.y), _ss)
		P.px(H, int(tip.x), int(tip.y) - 1, Color("f1dcc6"))
		P.px(H, int(tip.x) + 1, int(tip.y) - 1, Color("f1dcc6"))
	_knuckles(H, [23.0, 29.0, 35.0, 41.0], 33)
	_chalk_rect = Rect2i(4, 6, 50, 34)


## A crack: dark slot of width [param w] from x with lit left lip, shaded right.
static func _slot(im: Image, x: int, w: int, walls: int) -> void:
	for y in SIZE:
		var wob := int(roundf((P.smooth_noise(y * 0.12, x * 0.3, 2) - 0.5) * 2.4))
		var sx := x + wob
		for i in range(1, walls + 1):
			var lit := _rh if i == 1 else _rl
			if walls > 1 and i == 2:
				lit = _rl
			P.px(im, sx - i, y, lit)
		for i in w:
			var t := float(i) / float(w - 1) if w > 1 else 0.0
			var k := _rdd.lerp(_rk, t * t)
			if P.noise(sx + i, y, 6) > 0.9:
				k = _rd
			P.px(im, sx + i, y, k)
		for i in range(walls):
			P.px(im, sx + w + i, y, _rd if i == 0 else _rdd.lerp(_rd, 0.5))
		P.px(im, sx - walls - 1, y, _rd)


static func _finger_jam(B: Image, H: Image, F: Image) -> void:
	_slot(B, 17, 4, 1)
	_arm_up(H, 46, 44, 15.0)
	_spoly(H, [36, 14, 44, 12, 52, 18, 52, 42, 44, 48, 36, 42, 34, 30])
	for i in 3:
		var y := 17.0 + i * 6.0
		_cap(H, _v(40, y), _v(20, y), 5.0, _sk, _sl, _ss, _sr)
		P.px(H, int(_v(30, 0).x), int(y), _ss)
		P.px(H, int(_v(30, 0).x), int(y) + 1, _ss)
	_scap(H, _v(40, 34), _v(37, 50), 6.0)
	_sell(H, _v(37, 0).x, 51, 3.0, 3.0)
	_tape_poly(H, [38, 16, 46, 14, 51, 20, 51, 38, 46, 42, 38, 40])
	for i in 4:
		P.hline(H, 40, 20 + i * 5, 10, TAPE_SHADE)
	P.vline(H, 40, 18, 22, TAPE.lightened(0.3))
	_slot(F, 17, 4, 1)
	_chalk_rect = Rect2i(22, 10, 18, 34)


static func _hand_jam(B: Image, H: Image, F: Image) -> void:
	_slot(B, 25, 14, 2)
	for y in range(6, 40):
		P.px(B, 27 + (y * 7) % 11, y, _rk)
	_arm_up(H, 32, 46, 15.0)
	_arm_detail(H, 32, 48, 56)
	# the hand went in: taped back of the hand with the thumb tucked across
	_spoly(H, [26, 46, 25, 30, 28, 20, 36, 20, 39, 30, 38, 46])
	_scap(H, _v(27, 30), _v(37, 25), 5.5)
	_sell(H, _v(37, 0).x, 25, 2.8, 2.8)
	P.px(H, int(_v(36, 0).x), 23, _sl.lightened(0.4))
	_tape_poly(H, [25, 33, 39, 33, 38, 44, 26, 44])
	P.hline(H, 26, 36, 12, TAPE_SHADE)
	P.hline(H, 26, 39, 12, TAPE_SHADE)
	P.vline(H, 27, 34, 9, TAPE.lightened(0.3))
	# knuckle ridge
	_sell(H, 32, 21, 5.5, 2.5)
	P.hline(H, 29, 20, 5, _sl.lightened(0.4))
	# slot's right wall in front of the hand edge
	_chalk_rect = Rect2i(24, 18, 16, 14)


static func _fist_jam(B: Image, H: Image, F: Image) -> void:
	_slot(B, 22, 20, 2)
	for y in range(4, 50, 3):
		P.px(B, 24 + (y * 5) % 17, y, _rk)
	_arm_up(H, 32, 46, 16.0)
	_arm_detail(H, 32, 48, 56)
	# the fist, turned sideways and wedged
	_ell(H, 32, 28, 11, 12, _sk, _sl, _ss, _sr)
	for i in 4:
		var y := 20.0 + i * 4.5
		_cap(H, _v(36, y), _v(24, y), 4.0, _sk, _sl, _ss, _sr)
		_ell(H, 24.5, y, 2.4, 2.4, _sk, _sl.lightened(0.1), _ss, _sr)
	_ell(H, 33, 36, 7, 3, _sk, _sl, _ss, _sr)
	P.hline(H, 30, 35, 6, _sl.lightened(0.3))
	_tape_poly(H, [23, 40, 41, 40, 40, 49, 24, 49])
	P.hline(H, 24, 43, 16, TAPE_SHADE)
	P.hline(H, 24, 46, 16, TAPE_SHADE)
	P.vline(H, 25, 41, 8, TAPE.lightened(0.3))
	_chalk_rect = Rect2i(22, 16, 22, 24)


static func _tool(B: Image, H: Image, F: Image) -> void:
	# Blue-white ice (the grain pass paints it) with fracture lines.
	var crack := Color("f4fbff")
	var deep := Color("5f8fb0")
	P.line(B, Vector2(26, 12), Vector2(14, 8), crack)
	P.line(B, Vector2(14, 8), Vector2(8, 0), crack)
	P.line(B, Vector2(38, 12), Vector2(50, 6), crack)
	P.line(B, Vector2(26, 13), Vector2(8, 20), deep)
	P.line(B, Vector2(38, 13), Vector2(58, 20), deep)
	P.line(B, Vector2(30, 10), Vector2(32, 0), deep)
	P.line(B, Vector2(50, 6), Vector2(56, 0), crack)
	var steel := Color("a9b4c0")
	var steel_rim := Color("2c3540")
	var sh := Color("2e2e36")
	# shaft
	_cap(H, Vector2(32, 14), Vector2(32, 60), 5.0, sh, sh.lightened(0.45), sh.darkened(0.3), Color("14141a"))
	# the steel head: a hammer on one side, the pick buried in the ice
	_cap(H, Vector2(26, 12), Vector2(40, 12), 5.0, steel, steel.lightened(0.45), steel.darkened(0.3), steel_rim)
	_cap(H, Vector2(26, 12), Vector2(19, 5), 3.0, steel, steel.lightened(0.45), steel.darkened(0.3), steel_rim)
	_cap(H, Vector2(19, 5), Vector2(16, 0), 2.0, steel, steel.lightened(0.45), steel.darkened(0.3), steel_rim)
	# orange leash looping off the shaft
	var o := Color("e87a22")
	var orim := Color("8a3a0c")
	_cap(H, Vector2(33, 22), Vector2(46, 28), 2.0, o, o.lightened(0.3), o.darkened(0.25), orim)
	_cap(H, Vector2(46, 28), Vector2(48, 44), 2.0, o, o.lightened(0.3), o.darkened(0.25), orim)
	# arm and glove
	var gl := Color("484a58")
	var gr := Color("16171d")
	_scap(H, _v(32, 72), _v(32, 48), 15.0)
	_sleeve_poly(H, [21, 57, 43, 57, 43, 66, 21, 66])
	_cap(H, Vector2(32, 54), Vector2(32, 46), 13.0, gl.darkened(0.1), gl.lightened(0.2), gl.darkened(0.35), gr)
	for i in 4:
		var y := 29.0 + i * 4.5
		_cap(H, Vector2(24, y), Vector2(39, y), 4.5, gl, gl.lightened(0.3), gl.darkened(0.3), gr)
		P.px(H, 38, int(y), gl.lightened(0.4))
	_cap(H, Vector2(26, 46), Vector2(36, 38), 5.0, gl.lightened(0.1), gl.lightened(0.38), gl.darkened(0.25), gr)
	P.hline(H, 25, 48, 14, gl.darkened(0.5))
	_chalk_rect = Rect2i(0, 0, 0, 0)


# -------------------------------------------------------------------- the feet

## The outline of a shoe: narrow heel, wide ball, a rounded toe.
static func _shoe_outline(heel: Vector2, toe: Vector2, w: float) -> PackedVector2Array:
	var d := (toe - heel).normalized()
	var n := Vector2(-d.y, d.x)
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var steps := 16
	for i in steps + 1:
		var t := float(i) / steps
		var c := heel.lerp(toe, t)
		var rnd := sqrt(clampf(minf(t / 0.12, (1.0 - t) / 0.16), 0.0, 1.0))
		var wd := w * 0.5 * (0.72 + 0.28 * smoothstep(0.0, 0.7, t)) * rnd
		left.append(c + n * wd)
		right.append(c - n * wd)
	right.reverse()
	left.append_array(right)
	return left


## A shoe seen from above and behind, heel to toe. The leg comes in at the heel.
static func _shoe(H: Image, heel: Vector2, toe: Vector2, w: float, strap := true) -> void:
	var d := (toe - heel).normalized()
	var n := Vector2(-d.y, d.x)
	var len := heel.distance_to(toe)
	var rub_rim := _dk(RUBBER, 0.6)
	# the leg: trouser cuff and ankle
	var pants := ClimbSprites.PANTS
	_cap(H, heel - d * 5.0, heel - d * 34.0, w * 0.92, pants, pants.lightened(0.2), pants.darkened(0.25), _dk(pants, 0.6))
	_cap(H, heel - d * 4.0, heel + d * 1.0, w * 0.6, _sk, _sl, _ss, _sr)
	# rubber rand all round, then the red upper on top
	_poly(H, _shoe_outline(heel - d * 1.5, toe + d * 1.5, w + 3.0), RUBBER, RUBBER.lightened(0.35), RUBBER.darkened(0.2), rub_rim)
	_poly(H, _shoe_outline(heel + d * 1.5, toe - d * 0.5, w - 1.0), SHOE, SHOE.lightened(0.3), SHOE.darkened(0.25), _dk(SHOE, 0.6))
	# a glint along the instep
	P.line(H, heel + d * (len * 0.5) - n * (w * 0.25), heel + d * (len * 0.8) - n * (w * 0.3), SHOE.lightened(0.45), 1)
	# toe rubber cap
	_cap(H, toe - d * 6.0, toe - d * 1.0, w - 3.0, RUBBER, RUBBER.lightened(0.4), RUBBER.darkened(0.2), rub_rim)
	# collar and heel cup
	_ell(H, heel.x + d.x * 4.0, heel.y + d.y * 4.0, w * 0.3, w * 0.2, _sk, _sl, _ss, _dk(SHOE, 0.7))
	if strap:
		var c := heel + d * (len * 0.45)
		var a := c + n * (w * 0.42)
		var b := c - n * (w * 0.42)
		P.line(H, a, b, RUBBER, 3)
		P.line(H, a - d, b - d, RUBBER.lightened(0.45), 1)
		P.px(H, int(b.x), int(b.y), Color("d8d2c4"))
		var c2 := c + d * 6.0
		P.line(H, c2 + n * (w * 0.36), c2 - n * (w * 0.36), SHOE.darkened(0.35), 1)


static func _foot_edge(B: Image, H: Image, F: Image) -> void:
	_box(B, -2, 26, 68, 4, _rl, _rh, _rd, _rk)
	P.hline(B, 0, 31, 64, _rdd)
	P.hline(B, 0, 32, 64, _rd)
	_shoe(H, Vector2(36, 58), Vector2(30, 20), 16.0)
	# the inside edge of the sole bites the edge: a bright rand line and a dent of shadow
	P.line(H, Vector2(21, 22), Vector2(22, 36), RUBBER.lightened(0.6), 1)
	P.hline(H, 20, 31, 5, RUBBER.lightened(0.7))
	P.hline(H, 22, 33, 14, Color(_rk, 0.5))
	_chalk_rect = Rect2i(0, 0, 0, 0)


static func _foot_smear(B: Image, H: Image, F: Image) -> void:
	for i in 16:
		var x := int(P.noise(i, 1, 33) * 60) + 2
		var y := int(P.noise(i, 2, 33) * 40) + 2
		P.px(B, x, y, _rdd)
		P.px(B, x + 1, y + 1, _rh)
	# scuff marks left by earlier smears
	for i in 3:
		P.line(B, Vector2(10 + i * 4, 8 + i * 2), Vector2(14 + i * 4, 20 + i * 2), _rh)
	for i in 4:
		P.line(B, Vector2(40 + i * 3, 4), Vector2(34 + i * 4, 18), _rh)
	_shoe(H, Vector2(24, 59), Vector2(38, 24), 18.0, true)
	# the dropped heel shows the pale, scuffed sole at the toe
	var pale := Color("7b7984")
	_ell(H, 38.5, 22, 9.0, 4.5, pale, pale.lightened(0.3), pale.darkened(0.2), _dk(RUBBER, 0.5))
	for i in 4:
		P.hline(H, 33 + i * 2, 20 + (i % 3) * 2, 3, Color("b4b1bb"))
	_chalk_rect = Rect2i(0, 0, 0, 0)


static func _foot_toe_jam(B: Image, H: Image, F: Image) -> void:
	_slot(B, 8, 11, 2)
	_shoe(H, Vector2(48, 44), Vector2(13, 31), 16.0, true)
	# the crack's lip hides the toe, half the shoe is jammed in
	_slot(F, 8, 11, 2)
	_hold_cap(F, Vector2(20, -4), Vector2(20, 20), 4.0)
	_hold_cap(F, Vector2(20, 42), Vector2(20, 70), 4.0)
	_chalk_rect = Rect2i(0, 0, 0, 0)


static func _foot_step(B: Image, H: Image, F: Image) -> void:
	# A broad ledge: lit top, dark back wall and front face.
	_box(B, -2, -2, 68, 10, _rdd, _rdd, _rdd)
	P.hline(B, 0, 8, 64, _rk)
	_box(B, -2, 9, 68, 44, _rl, _rh, _rl)
	P.hline(B, 0, 53, 64, _rd)
	_box(B, -2, 54, 68, 12, _rd, _rd, _rdd)
	for i in 14:
		var x := int(P.noise(i, 5, 44) * 60) + 2
		P.px(B, x, 12 + int(P.noise(i, 6, 44) * 38), _rd)
	_shoe(H, Vector2(32, 56), Vector2(32, 24), 17.0, true)
	_chalk_rect = Rect2i(0, 0, 0, 0)
