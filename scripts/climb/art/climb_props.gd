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


## A black oak or a rounded broadleaf tree.
static func oak(im: Image, x: int, y: int, h: int, rng: RandomNumberGenerator, c: Dictionary) -> void:
	var g := _ramp(OAK, c)
	P.rect(im, x - 1, y - h / 3, 3, h / 3, _lit(BARK, c))
	P.rect(im, x - 1, y - h / 3, 1, h / 3, _lit(BARK_LIT, c))
	var r := h * 0.36
	P.ellipse(im, x, y - h * 0.62, r * 1.1, r, g[0])
	P.ellipse(im, x - 1, y - h * 0.66, r * 1.0, r * 0.9, g[1])
	for i in 6:
		var a := rng.randf() * TAU
		P.ellipse(im, x + cos(a) * r * 0.6, y - h * 0.66 + sin(a) * r * 0.5, r * 0.4, r * 0.34, g[2])
	P.ellipse(im, x - r * 0.35, y - h * 0.8, r * 0.4, r * 0.3, g[3])


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
