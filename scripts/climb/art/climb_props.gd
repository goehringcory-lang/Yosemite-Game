class_name ClimbProps
extends RefCounted
## Plants and scenery painted onto the wall picture: trees and shrubs on the
## ledges, and (see the second half) the ground at the foot of each route and
## the summit scenery above its last pitch.

const P := preload("res://scripts/climb/art/climb_paint.gd")
const L := preload("res://scripts/climb/art/climb_layout.gd")

const BARK := Color("5a3a24")
const BARK_LIT := Color("8a5e3a")
const PINE := ["1f4a2c", "2e6a3a", "428a48", "6aae5a"]
const OAK := ["2a4a24", "3e6a2e", "5a8a3a", "84b04e"]
const MANZ := ["3a5a30", "567a3e", "78a050", "a0c870"]


static func _lit(col: Color, c: Dictionary) -> Color:
	var tint: Color = c.get("tint", Color.WHITE)
	var lum: float = c.get("lum", 1.0)
	var t := col.lerp(Color(col.r * tint.r, col.g * tint.g, col.b * tint.b), 0.7)
	return Color(clampf(t.r * lum, 0, 1), clampf(t.g * lum, 0, 1), clampf(t.b * lum, 0, 1), col.a)


static func _ramp(list: Array, c: Dictionary) -> Array[Color]:
	var out: Array[Color] = []
	for h: String in list:
		out.append(_lit(Color(h), c))
	return out


## A conifer, base at ([param x], [param y]), [param h] pixels tall.
static func pine(im: Image, x: int, y: int, h: int, rng: RandomNumberGenerator, c: Dictionary, snowy := false) -> void:
	var g := _ramp(PINE, c)
	var trunk_h := maxi(h / 6, 2)
	P.rect(im, x - 1, y - trunk_h, 2, trunk_h, _lit(BARK, c))
	P.px(im, x - 1, y - trunk_h, _lit(BARK_LIT, c))
	var tiers := maxi(h / 6, 3)
	for t in tiers:
		var ty := y - trunk_h - t * (h - trunk_h) / tiers
		var tw := maxi(int((tiers - t) * (h * 0.5) / tiers) + 1, 2)
		for k in range(0, 5):
			var yy := ty - k
			var rw := maxi(tw - k * tw / 5 - rng.randi_range(0, 1), 1)
			P.rect(im, x - rw, yy, rw * 2 + 1, 1, g[1] if k < 3 else g[0])
			P.px(im, x - rw, yy, g[3] if k < 2 else g[2])
			P.px(im, x - rw + 1, yy, g[2])
			P.px(im, x + rw, yy, g[0])
		if snowy:
			P.rect(im, x - tw + 1, ty - 4, tw * 2 - 1, 1, Color("eef4fa"))
	P.px(im, x, y - h, g[3])
	P.px(im, x, y - h + 1, g[2])


## A black oak or a rounded broadleaf tree: a clumpy canopy of outlined lobes,
## lit from the upper left, on a forked trunk.
static func oak(im: Image, x: int, y: int, h: int, rng: RandomNumberGenerator, c: Dictionary) -> void:
	var g := _ramp(OAK, c)
	var bark := _lit(BARK, c)
	var bark_l := _lit(BARK_LIT, c)
	var th := maxi(h * 2 / 5, 6)
	# Trunk with a root flare and a fork up into the crown.
	P.rect(im, x - 3, y - 2, 7, 2, DARK)
	P.rect(im, x - 2, y - th, 5, th, DARK)
	P.rect(im, x - 1, y - th, 3, th, bark)
	P.vline(im, x - 1, y - th, th, bark_l)
	P.vline(im, x + 1, y - th, th, bark.darkened(0.3))
	P.rect(im, x - 2, y - 2, 5, 1, bark)
	var r := h * 0.34
	var cy := y - h * 0.6
	# Lobes of the canopy (offsets in units of r), back (high) ones first.
	var lobes: Array[Vector3] = [
		Vector3(0.0, -0.55, 0.62), Vector3(-0.62, -0.25, 0.56), Vector3(0.62, -0.28, 0.56),
		Vector3(-0.78, 0.2, 0.5), Vector3(0.8, 0.2, 0.5), Vector3(-0.3, 0.1, 0.62),
		Vector3(0.35, 0.18, 0.6), Vector3(0.0, 0.5, 0.5),
	]
	for lobe in lobes:
		var lx := x + lobe.x * r + rng.randf_range(-0.5, 0.5)
		var ly := cy + lobe.y * r
		var lr := lobe.z * r * 1.15
		P.ellipse(im, lx, ly, lr + 1.0, lr * 0.9 + 1.0, DARK)
		P.shaded_ellipse(im, lx, ly, lr, lr * 0.9, g[1], g[2], g[0])
		P.ellipse(im, lx - lr * 0.3, ly - lr * 0.35, lr * 0.4, lr * 0.28, g[3])
	for i in int(r):
		var a := rng.randf() * TAU
		var d := rng.randf() * r * 0.9
		P.px(im, x + int(cos(a) * d), int(cy + sin(a) * d * 0.8), g[3] if cos(a) + sin(a) < 0 else g[0])
	# Branches showing through under the crown.
	P.px(im, x - 2, y - th - 1, bark)
	P.px(im, x + 2, y - th - 1, bark.darkened(0.2))


## A rounded shrub (manzanita, huckleberry oak), often with berries.
static func shrub(im: Image, x: int, y: int, r: int, rng: RandomNumberGenerator, c: Dictionary, berries := false) -> void:
	var g := _ramp(MANZ, c)
	P.ellipse(im, x, y - r * 0.6, r * 1.1, r * 0.8, g[0])
	P.ellipse(im, x - 1, y - r * 0.7, r, r * 0.7, g[1])
	for i in 4:
		P.ellipse(im, x + rng.randi_range(-r, r) * 0.6, y - r * 0.8 + rng.randi_range(-r, r) * 0.2, r * 0.4, r * 0.3, g[2])
	P.px(im, x - r / 2, y - r, g[3])
	if berries:
		for i in 4:
			P.px(im, x + rng.randi_range(-r, r), y - rng.randi_range(r / 2, r), _lit(Color("c8402e"), c))


static func tuft(im: Image, x: int, y: int, rng: RandomNumberGenerator, c: Dictionary, dry := false) -> void:
	var cols := [_lit(Color("4a7a3a"), c), _lit(Color("6a9a48"), c), _lit(Color("365a2c"), c)]
	if dry:
		cols = [_lit(Color("b8a060"), c), _lit(Color("d8c07a"), c), _lit(Color("8a7440"), c)]
	for i in rng.randi_range(5, 9):
		var q := Vector2i(x + rng.randi_range(-3, 3), y - rng.randi_range(0, 3))
		P.px(im, q.x, q.y, cols[rng.randi() % cols.size()])
		if rng.randf() < 0.4:
			P.px(im, q.x, q.y - 1, cols[1])


static func flowers(im: Image, x: int, y: int, rng: RandomNumberGenerator, c: Dictionary) -> void:
	tuft(im, x, y, rng, c)
	var cols := [Color("f06a4a"), Color("f0c040"), Color("c870d8"), Color("f4f0e6")]
	for i in 4:
		P.px(im, x + rng.randi_range(-3, 3), y - rng.randi_range(1, 4), _lit(cols[rng.randi() % cols.size()], c))


## Whatever grows on a ledge, picked by the pitch's decoration hints.
static func ledge_plant(im: Image, x: int, y: int, deco: Array, rng: RandomNumberGenerator, c: Dictionary) -> void:
	if "tree" in deco and rng.randf() < 0.6:
		pine(im, x, y, rng.randi_range(18, 30), rng, c)
	elif "krummholz" in deco:
		var g := _ramp(PINE, c)
		P.ellipse(im, x, y - 3, 6, 3, g[0])
		P.ellipse(im, x - 1, y - 4, 5, 2.5, g[1])
		P.px(im, x - 3, y - 5, g[3])
	elif "manzanita" in deco and rng.randf() < 0.7:
		shrub(im, x, y, rng.randi_range(4, 7), rng, c, true)
	elif "flowers" in deco and rng.randf() < 0.6:
		flowers(im, x, y, rng, c)
	else:
		tuft(im, x, y, rng, c)


# ---------------------------------------------------------------- scenery bits
# Small things for the ground and summit scenes: a pixel font for signs,
# people, boulders, tents, tables, cars, tripods, cairns. All of them take the
# lighting dictionary [param c] (ClimbSky.palette or ClimbRock.colors).

const DARK := Color("2a1f1a")
const FONT := {
	"A": "111101111101101", "B": "110101110101110", "C": "111100100100111", "D": "110101101101110",
	"E": "111100110100111", "F": "111100110100100", "G": "111100101101111", "H": "101101111101101",
	"I": "111010010010111", "J": "001001001101111", "K": "101101110101101", "L": "100100100100111",
	"M": "101111111101101", "N": "110101101101101", "O": "111101101101111", "P": "111101111100100",
	"Q": "111101101111001", "R": "110101110101101", "S": "111100111001111", "T": "111010010010010",
	"U": "101101101101111", "V": "101101101101010", "W": "101101111111101", "X": "101101010101101",
	"Y": "101101010010010", "Z": "111001010100111", "0": "111101101101111", "1": "010110010010111",
	"2": "111001111100111", "3": "111001111001111", "4": "101101111001001", "5": "111100111001111",
	"6": "111100111101111", "7": "111001001001001", "8": "111101111101111", "9": "111101111001111",
	".": "000000000000010", "-": "000000111000000", ">": "100010001010100", "<": "001010100010001",
}


## A color that glows when it is dark out: [param hex] lit by the time of day,
## drifting to its full brightness as the light drops (lit windows, fires).
static func glow(hex: String, c: Dictionary) -> Color:
	var lum: float = c.get("lum", 1.0)
	var n := clampf((1.0 - lum) / 0.4, 0.0, 1.0)
	return _lit(Color(hex), c).lerp(Color(hex), n)


## How dark it is, 0 by day to 1 in the dark.
static func night_amount(c: Dictionary) -> float:
	var lum: float = c.get("lum", 1.0)
	return clampf((0.98 - lum) / 0.3, 0.0, 1.0)


## Text in a 3 x 5 pixel font ([param x], [param y] is the top-left).
static func text(im: Image, x: int, y: int, s: String, col: Color) -> void:
	for i in s.length():
		var g: String = FONT.get(s[i], "")
		if g == "":
			continue
		for k in 15:
			if g[k] == "1":
				P.px(im, x + i * 4 + k % 3, y + k / 3, col)


static func text_width(s: String) -> int:
	return s.length() * 4 - 1


## A soft dark patch on the ground under something (light is from the upper
## left, so the shadow leans right).
static func shadow(im: Image, x: float, y: float, rx: float, ry := 2.0, alpha := 0.3) -> void:
	P.ellipse(im, x + rx * 0.25, y, rx, ry, Color(0.05, 0.04, 0.1, alpha))


## A wooden board sign on two posts, with [param s] painted on it. The posts
## end at [param y].
static func board_sign(im: Image, x: int, y: int, s: String, c: Dictionary, post := 12) -> void:
	var wood := _lit(Color("8a5a2e"), c)
	var w := text_width(s) + 6
	var top := y - post - 9
	P.rect(im, x + 2, y - post, 2, post, _lit(Color("5a3a1c"), c))
	P.rect(im, x + w - 4, y - post, 2, post, _lit(Color("5a3a1c"), c))
	P.rect(im, x - 1, top - 1, w + 2, 11, DARK)
	P.rect(im, x, top, w, 9, wood)
	P.rect(im, x, top, w, 1, wood.lightened(0.25))
	P.rect(im, x, top + 8, w, 1, wood.darkened(0.3))
	P.px(im, x + 1, top + 1, DARK)
	P.px(im, x + w - 2, top + 1, DARK)
	text(im, x + 3, top + 2, s, _lit(Color("f6e4b0"), c))


## A little person, about 16 px tall, feet at ([param x], [param y]). Options:
## shirt, pants, hat (Color), skin, hair, dir (1 or -1), bino, wave, pack.
static func person(im: Image, x: int, y: int, c: Dictionary, o := {}) -> void:
	var t := P.make(16, 20)
	var shirt := _lit(o.get("shirt", Color("c84a3a")), c)
	var pants := _lit(o.get("pants", Color("4a5068")), c)
	var skin := _lit(o.get("skin", Color("e0ac7e")), c)
	var hair := _lit(o.get("hair", Color("4a3020")), c)
	var boot := _lit(Color("3a2a22"), c)
	P.rect(t, 6, 13, 2, 5, pants)
	P.rect(t, 8, 13, 2, 5, pants.darkened(0.2))
	P.rect(t, 6, 17, 2, 1, boot)
	P.rect(t, 8, 17, 2, 1, boot)
	if o.has("pack"):
		var pk := _lit(o.pack as Color, c)
		P.rect(t, 4, 8, 2, 6, pk)
		P.rect(t, 4, 8, 1, 6, pk.lightened(0.2))
	P.rect(t, 6, 8, 4, 6, shirt)
	P.rect(t, 6, 8, 1, 6, shirt.lightened(0.18))
	P.rect(t, 9, 8, 1, 6, shirt.darkened(0.2))
	P.rect(t, 6, 13, 4, 1, _lit(Color("5a3a22"), c))
	if o.get("wave", false):
		P.rect(t, 10, 4, 1, 5, shirt.darkened(0.1))
		P.rect(t, 10, 2, 1, 2, skin)
		P.rect(t, 5, 9, 1, 4, shirt.darkened(0.1))
	elif o.get("bino", false):
		P.rect(t, 10, 6, 1, 4, shirt.darkened(0.1))
		P.rect(t, 5, 9, 1, 3, shirt.darkened(0.1))
		P.rect(t, 9, 4, 2, 2, DARK)
	else:
		P.rect(t, 10, 9, 1, 4, shirt.darkened(0.1))
		P.rect(t, 5, 9, 1, 4, shirt.darkened(0.1))
		P.px(t, 10, 13, skin)
		P.px(t, 5, 13, skin)
	P.rect(t, 6, 4, 4, 4, skin)
	P.rect(t, 6, 4, 4, 1, hair)
	P.px(t, 6, 5, hair)
	P.px(t, 9, 6, skin.darkened(0.15))
	if o.has("hat"):
		var hat := _lit(o.hat as Color, c)
		P.rect(t, 5, 3, 6, 1, hat.lightened(0.1))
		P.rect(t, 6, 2, 4, 1, hat)
		P.rect(t, 6, 3, 4, 1, hat.darkened(0.1))
	P.outline(t, DARK)
	if o.get("dir", 1) < 0:
		t.flip_x()
	P.stamp(im, t, x - 8, y - 17)


## A boulder: outlined, lit from the upper left, with a crack and some moss.
static func boulder(im: Image, x: int, y: int, rx: float, ry: float, rc: Dictionary, rng: RandomNumberGenerator, mossy := false) -> void:
	shadow(im, x + 1, y + ry * 0.7, rx * 1.05, maxf(ry * 0.35, 1.5), 0.32)
	P.ellipse(im, x, y, rx + 1, ry + 1, DARK)
	P.shaded_ellipse(im, x, y, rx, ry, ClimbRock.tone(rc, 2.2), ClimbRock.tone(rc, 3.6), ClimbRock.tone(rc, 1.1))
	P.ellipse(im, x - rx * 0.25, y - ry * 0.35, rx * 0.35, ry * 0.25, ClimbRock.tone(rc, 3.9))
	if rx > 6:
		var cx := x + rng.randi_range(-2, 2)
		P.line(im, Vector2(cx, y - ry * 0.4), Vector2(cx + rng.randi_range(-3, 3), y + ry * 0.6), ClimbRock.tone(rc, 0.9))
	if mossy:
		var m: Color = rc.moss
		for i in int(rx):
			P.px(im, x + rng.randi_range(-int(rx * 0.8), int(rx * 0.8)), y - int(ry * 0.8) + rng.randi_range(0, 2), m)


## Grass blades along a line, a few pixels tall.
static func grass_row(im: Image, x0: int, x1: int, y: int, rng: RandomNumberGenerator, c: Dictionary, step := 3, dry := false, tall := 3) -> void:
	var cols := [_lit(Color("3a6a30"), c), _lit(Color("5a8a3e"), c), _lit(Color("84b04e"), c)]
	if dry:
		cols = [_lit(Color("8a7440"), c), _lit(Color("b8a060"), c), _lit(Color("e0cc82"), c)]
	for x in range(x0, x1, step):
		var xx := x + rng.randi_range(0, step - 1)
		var hh := rng.randi_range(1, tall)
		var lean := rng.randi_range(-1, 1)
		for k in hh:
			P.px(im, xx + (lean if k == hh - 1 else 0), y - k, cols[1 if k < hh - 1 else 2])
		P.px(im, xx, y, cols[0])


## A fern: a fan of arcing fronds.
static func fern(im: Image, x: int, y: int, r: int, c: Dictionary) -> void:
	var g := _ramp(["2c5a2c", "3e7a38", "5c9a48", "86c062"], c)
	for k in range(-3, 4):
		var a := -PI / 2.0 + k * 0.32
		var l := float(r) * (1.0 - absf(k) * 0.1)
		for s in range(1, int(l) + 1):
			var t := float(s) / l
			var px := x + cos(a) * s
			var py := y + sin(a) * s + t * t * r * 0.5
			P.px(im, int(px), int(py), g[2] if k <= 0 else g[1])
			if s % 2 == 0:
				P.px(im, int(px), int(py) + 1, g[0])
	P.px(im, x - r / 2, y - r + 1, g[3])


## A lodgepole pine: straight pale trunk, narrow ragged crown on the top half.
static func lodgepole(im: Image, x: int, y: int, h: int, rng: RandomNumberGenerator, c: Dictionary) -> void:
	var g := _ramp(PINE, c)
	var bark := _lit(Color("a07a52"), c)
	P.rect(im, x - 1, y - h, 3, h, DARK)
	P.rect(im, x - 1 + 1, y - h + 1, 1, h - 1, bark)
	P.vline(im, x, y - h + 1, h - 1, bark)
	P.vline(im, x - 1, y - h + 1, h - 1, bark.lightened(0.15))
	P.vline(im, x + 1, y - h + 1, h - 1, bark.darkened(0.25))
	var crown := int(h * 0.55)
	var top := y - h
	for k in crown:
		var rw := 1 + int(k * 0.2) + (1 if k % 5 < 2 else 0) + rng.randi_range(0, 1)
		rw = mini(rw, 9)
		var yy := top + k
		P.rect(im, x - rw - 1, yy, rw * 2 + 3, 1, DARK if k % 4 == 3 else g[1])
		P.rect(im, x - rw, yy, rw * 2 + 1, 1, g[1] if k % 4 != 3 else g[0])
		P.px(im, x - rw, yy, g[2] if k % 4 < 2 else g[1])
		P.px(im, x - rw + 1, yy, g[3] if k % 4 == 0 else g[2])
		P.px(im, x + rw, yy, g[0])
	P.px(im, x, top - 1, g[2])
	P.px(im, x, top - 2, g[3])


## A wind-twisted whitebark pine or juniper: leaning trunk, flat tufted crown.
static func gnarled(im: Image, x: int, y: int, h: int, rng: RandomNumberGenerator, c: Dictionary) -> void:
	var g := _ramp(PINE, c)
	var bark := _lit(Color("6a5240"), c)
	var lean := 1 if rng.randf() < 0.5 else -1
	for k in h:
		var xx := x + int(sin(k * 0.45) * 2.0) + lean * k / 6
		P.rect(im, xx - 1, y - k, 3 if k < h / 3 else 2, 1, bark)
		P.px(im, xx - 1, y - k, bark.lightened(0.25))
	var tx := x + lean * h / 6
	for i in 3:
		var ox := (i - 1) * 6
		var up := absi(i - 1) * 2
		P.ellipse(im, tx + ox, y - h + 3 - up, 6, 3.4, g[0])
		P.ellipse(im, tx + ox - 1, y - h + 2 - up, 5, 2.6, g[1])
		P.ellipse(im, tx + ox - 2, y - h + 1 - up, 3, 1.4, g[2])
	P.px(im, tx - 3, y - h, g[3])


## A fallen log.
static func log_pile(im: Image, x: int, y: int, length: int, c: Dictionary) -> void:
	var bark := _lit(Color("6a4428"), c)
	shadow(im, x + length / 2.0, y + 1, length / 2.0 + 1, 1.5, 0.3)
	P.rect(im, x - 1, y - 5, length + 2, 7, DARK)
	P.rect(im, x, y - 4, length, 5, bark)
	P.rect(im, x, y - 4, length, 1, bark.lightened(0.3))
	P.rect(im, x, y, length, 1, bark.darkened(0.3))
	for k in range(3, length - 2, 5):
		P.px(im, x + k, y - 2, bark.darkened(0.25))
	P.ellipse(im, x, y - 2, 2.5, 3, _lit(Color("d8b080"), c))
	P.px(im, x, y - 2, bark)


## A cairn of stacked stones, [param h] stones tall.
static func cairn(im: Image, x: int, y: int, rc: Dictionary, h := 3) -> void:
	shadow(im, x + 1, y, 6, 1.5, 0.3)
	var widths := [7, 6, 5, 4, 3, 2]
	for i in mini(h + 1, widths.size()):
		var w: int = widths[i]
		var yy := y - 3 - i * 3
		P.rect(im, x - w, yy - 1, w * 2, 4, DARK)
		P.rect(im, x - w + 1, yy, w * 2 - 2, 3, ClimbRock.tone(rc, 2.0 + (i % 2) * 0.5))
		P.rect(im, x - w + 1, yy, w * 2 - 2, 1, ClimbRock.tone(rc, 3.6))
		P.px(im, x + w - 2, yy + 2, ClimbRock.tone(rc, 1.2))


## An ice axe stuck in the snow at ([param x], [param y]).
static func ice_axe(im: Image, x: int, y: int, c: Dictionary, lean := 1) -> void:
	var shaft := _lit(Color("d8452e"), c)
	var steel := _lit(Color("d0d8e4"), c)
	for k in 17:
		var sx := x + lean * k / 6
		P.px(im, sx, y - k, DARK if k > 14 else shaft)
		P.px(im, sx + 1, y - k, shaft.darkened(0.3) if k > 1 else DARK)
		P.px(im, sx - 1, y - k, DARK)
	var hx := x + lean * 17 / 6
	P.rect(im, hx - 4, y - 19, 8, 3, DARK)
	P.rect(im, hx - 3, y - 18, 6, 1, steel)
	P.px(im, hx - 4, y - 17, steel.darkened(0.2))
	P.px(im, hx + 3, y - 17, steel.darkened(0.2))
	P.px(im, hx - 3, y - 19, steel.lightened(0.2))


## A dome tent seen from the side, door facing the viewer.
static func dome_tent(im: Image, x: int, y: int, w: int, h: int, color: Color, c: Dictionary) -> void:
	var col := _lit(color, c)
	var lit := col.lightened(0.28)
	var dark := col.darkened(0.3)
	shadow(im, x + 2, y, w / 2.0 + 3, 2.5, 0.32)
	var halves: Array[int] = []
	for k in h:
		var t := float(k + 1) / h
		halves.append(int(sqrt(maxf(1.0 - pow(1.0 - t, 2.0), 0.0)) * w / 2.0) + 1)
	for k in h:
		P.rect(im, x - halves[k] - 1, y - h + 1 + k, halves[k] * 2 + 3, 1, DARK)
	P.rect(im, x - w / 2 - 1, y + 1, w + 3, 1, DARK)
	for k in h:
		var half := halves[k]
		var yy := y - h + 1 + k
		P.rect(im, x - half, yy, half * 2 + 1, 1, col)
		P.rect(im, x - half, yy, mini(half, 3), 1, lit)
		P.rect(im, x + half - 2, yy, 3, 1, dark)
	var door := _lit(Color("2a2430"), c).lerp(Color("f0a850"), night_amount(c) * 0.9)
	P.rect(im, x - 3, y - h / 2, 7, h / 2 + 1, door)
	P.rect(im, x - 3, y - h / 2, 7, 1, dark)
	P.vline(im, x, y - h / 2, h / 2 + 1, dark)
	P.hline(im, x - w / 4, y - h + 3, w / 2, lit)


## A canvas ridge tent (a-frame), door facing the viewer.
static func ridge_tent(im: Image, x: int, y: int, w: int, h: int, color: Color, c: Dictionary) -> void:
	var col := _lit(color, c)
	var dark := col.darkened(0.28)
	shadow(im, x + 3, y, w / 2.0 + 4, 2.5, 0.32)
	for k in h:
		var half := int((float(k) + 1.0) / h * w / 2.0)
		P.rect(im, x - half - 1, y - h + 1 + k, half * 2 + 3, 1, DARK)
	P.rect(im, x - w / 2 - 1, y + 1, w + 3, 1, DARK)
	for k in h:
		var half := int((float(k) + 1.0) / h * w / 2.0)
		var yy := y - h + 1 + k
		P.rect(im, x - half, yy, half * 2 + 1, 1, col)
		P.px(im, x - half, yy, col.lightened(0.3))
		P.rect(im, x + 1, yy, half, 1, dark)
	P.rect(im, x - 2, y - h / 2, 5, h / 2 + 1, _lit(Color("2a2430"), c).lerp(Color("f0a850"), night_amount(c) * 0.9))
	P.vline(im, x, y - h - 1, 2, _lit(Color("a07a4a"), c))


## A picnic table with benches, [param w] wide.
static func picnic_table(im: Image, x: int, y: int, w: int, c: Dictionary) -> void:
	var wood := _lit(Color("9a6a38"), c)
	shadow(im, x + w / 2.0 + 2, y + 1, w / 2.0 + 3, 2.0, 0.3)
	P.line(im, Vector2(x + 3, y), Vector2(x + 6, y - 7), DARK)
	P.line(im, Vector2(x + 9, y), Vector2(x + 6, y - 7), DARK)
	P.line(im, Vector2(x + w - 4, y), Vector2(x + w - 7, y - 7), DARK)
	P.line(im, Vector2(x + w - 10, y), Vector2(x + w - 7, y - 7), DARK)
	P.rect(im, x - 1, y - 4, w + 2, 3, DARK)
	P.rect(im, x, y - 3, w, 1, wood)
	P.rect(im, x, y - 2, w, 1, wood.darkened(0.35))
	P.rect(im, x + 1, y - 9, w - 2, 3, DARK)
	P.rect(im, x + 2, y - 8, w - 4, 1, wood.lightened(0.25))
	P.rect(im, x + 2, y - 7, w - 4, 1, wood)
	for k in range(5, w - 3, 7):
		P.px(im, x + k, y - 8, wood.darkened(0.2))


## A small side-view car ([param dir] 1 faces right).
static func car(im: Image, x: int, y: int, body: Color, c: Dictionary, dir := 1, wagon := false) -> void:
	var t := P.make(40, 20)
	var col := _lit(body, c)
	var glass := _lit(Color("a8c8e0"), c)
	var tire := _lit(Color("1c1a20"), c)
	P.rect(t, 2, 8, 34, 6, col)
	P.rect(t, 2, 8, 34, 1, col.lightened(0.3))
	P.rect(t, 2, 13, 34, 1, col.darkened(0.3))
	if wagon:
		P.rect(t, 7, 3, 24, 5, col)
		P.rect(t, 7, 3, 24, 1, col.lightened(0.3))
		P.rect(t, 9, 4, 6, 4, glass)
		P.rect(t, 16, 4, 6, 4, glass)
		P.rect(t, 23, 4, 6, 4, glass)
	else:
		P.rect(t, 9, 3, 17, 5, col)
		P.rect(t, 9, 3, 17, 1, col.lightened(0.3))
		P.rect(t, 11, 4, 6, 4, glass)
		P.rect(t, 18, 4, 6, 4, glass)
	P.px(t, 35, 9, _lit(Color("fff0b0"), c))
	P.px(t, 2, 9, _lit(Color("c83020"), c))
	P.rect(t, 6, 12, 7, 6, tire)
	P.rect(t, 25, 12, 7, 6, tire)
	P.rect(t, 8, 14, 3, 3, _lit(Color("a0a4b0"), c))
	P.rect(t, 27, 14, 3, 3, _lit(Color("a0a4b0"), c))
	P.outline(t, DARK)
	if dir < 0:
		t.flip_x()
	shadow(im, x + 1, y, 20, 2.0, 0.34)
	P.stamp(im, t, x - 20, y - 18)


## A tripod with a spotting scope, [param dir] 1 aims up and to the right.
static func tripod(im: Image, x: int, y: int, c: Dictionary, dir := 1) -> void:
	var leg := _lit(Color("2a2a30"), c)
	P.line(im, Vector2(x, y - 8), Vector2(x - 3, y), leg)
	P.line(im, Vector2(x, y - 8), Vector2(x + 3, y), leg)
	P.line(im, Vector2(x, y - 8), Vector2(x, y), leg)
	P.line(im, Vector2(x, y - 9), Vector2(x + 5 * dir, y - 14), _lit(Color("6a7080"), c), 2)
	P.px(im, x + 5 * dir, y - 15, _lit(Color("c8d0dc"), c))


## A string of bright pennants hung between two points.
static func bunting(im: Image, a: Vector2, b: Vector2, c: Dictionary) -> void:
	var cols := [Color("d8452e"), Color("e8c040"), Color("4a78c8"), Color("7ac24a")]
	var n := int(absf(b.x - a.x) / 5.0)
	for i in n + 1:
		var t := float(i) / maxf(n, 1)
		var px := lerpf(a.x, b.x, t)
		var py := lerpf(a.y, b.y, t) + sin(t * PI) * 5.0
		P.px(im, int(px), int(py), DARK)
		P.rect(im, int(px), int(py) + 1, 2, 3, _lit(cols[i % 4], c))
