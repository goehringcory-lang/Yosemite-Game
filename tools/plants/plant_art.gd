extends Node
## Draws the press book's plants (Herbarium.PLANTS), one 16x16 frame each, in
## book order, to assets/sprites/plants.png. The same drawing stands in the
## world and fills the plant's slot in the Press Book. Run from the project
## folder, then import:
##
##   godot --headless --path . res://tools/plants/plant_art.tscn
##   godot --headless --path . --import
##
## A plant with no drawing here gets a plain green sprig, and the tool says so.

const K = preload("res://tools/hubs/pixel_kit.gd")
const S := 16
const BARK := Color("6b4a2e")
const TWIG := Color("7a5a3a")
const GREEN := Color("4f8a3c")


func _ready() -> void:
	var plants: Array[Dictionary] = Herbarium.PLANTS
	var columns: int = Herbarium.SHEET_COLUMNS
	var sheet := K.make(columns * S, ceili(float(plants.size()) / columns) * S)
	for i in plants.size():
		var id: String = plants[i].id
		var frame: Image
		if has_method("_" + id):
			frame = call("_" + id)
		else:
			print("no drawing for %s: using a plain sprig" % id)
			frame = _broadleaf(GREEN, Vector2(2.2, 1.4), TWIG)
		K.outline(frame)
		K.stamp(sheet, frame, i % columns * S, i / columns * S)
	sheet.save_png(ProjectSettings.globalize_path(Herbarium.SHEET))
	print("drew %d plants to %s" % [plants.size(), Herbarium.SHEET])
	# A look at the sheet four times the size, for checking the drawings.
	var preview := OS.get_environment("PLANT_PREVIEW")
	if preview != "":
		var big := sheet.duplicate() as Image
		big.resize(sheet.get_width() * 4, sheet.get_height() * 4, Image.INTERPOLATE_NEAREST)
		var backed := Image.create_empty(big.get_width(), big.get_height(), false, Image.FORMAT_RGBA8)
		backed.fill(Color("8fae6a"))
		backed.blend_rect(big, Rect2i(Vector2i.ZERO, big.get_size()), Vector2i.ZERO)
		backed.save_png(preview)
	get_tree().quit()


# ---------------------------------------------------------------- strokes

## A line of pixels from (x0, y0) to (x1, y1).
func _seg(im: Image, x0: float, y0: float, x1: float, y1: float, col: Color) -> void:
	var steps := int(maxf(absf(x1 - x0), absf(y1 - y0))) + 1
	for i in steps + 1:
		var t := float(i) / steps
		K.px(im, int(round(lerpf(x0, x1, t))), int(round(lerpf(y0, y1, t))), col)


## A forked twig rising from the ground. Returns its three tips.
func _twig(im: Image, col: Color) -> Array[Vector2]:
	_seg(im, 8, 15, 8, 9, col)
	_seg(im, 8, 12, 4, 8, col)
	_seg(im, 8, 11, 12, 7, col)
	return [Vector2(8, 8), Vector2(4, 7), Vector2(12, 6)]


# ---------------------------------------------------------------- kinds of plant

## A pine or fir sprig: fans of needles at each tip, and maybe a cone.
## [param droop] bends the needles down (long pine needles hang).
func _conifer(needle: Color, length: float, droop := 0.0, cone := Color(0, 0, 0, 0), cone_size := Vector2(1.6, 2.4), upright := false) -> Image:
	var im := K.make(S, S)
	for tip in _twig(im, BARK):
		for i in 5:
			var a := -PI / 2.0 + (i - 2) * 0.55
			var end := tip + Vector2(cos(a), sin(a) + droop * absf(cos(a))) * length
			_seg(im, tip.x, tip.y, end.x, end.y, needle if i % 2 == 0 else needle.darkened(0.22))
	if cone.a > 0.0:
		var cy := 9.0 - cone_size.y if upright else 11.0 + cone_size.y * 0.5
		K.ellipse(im, 11.5, cy, cone_size.x, cone_size.y, cone)
		K.px(im, 11, int(cy), cone.lightened(0.25))
	return im


## Scale leaves in flat sprays (cedar, sequoia, juniper): short thick fans.
func _spray(leaf: Color, bark: Color, berry := Color(0, 0, 0, 0), flat := true) -> Image:
	var im := K.make(S, S)
	for tip in _twig(im, bark):
		for i in 5:
			var a := -PI / 2.0 + (i - 2) * (0.5 if flat else 0.75)
			var end := tip + Vector2(cos(a), sin(a)) * (4.0 if flat else 3.0)
			_seg(im, tip.x, tip.y, end.x, end.y, leaf if i % 2 == 0 else leaf.lightened(0.18))
			_seg(im, tip.x + 1, tip.y, end.x + 1, end.y, leaf.darkened(0.15))
	if berry.a > 0.0:
		for at in [Vector2i(6, 9), Vector2i(11, 8), Vector2i(9, 5)]:
			K.px(im, at.x, at.y, berry)
	return im


## A leafy sprig: a twig with a leaf at each tip and down its sides.
func _broadleaf(leaf: Color, size: Vector2, twig: Color, underside := Color(0, 0, 0, 0)) -> Image:
	var im := K.make(S, S)
	var tips := _twig(im, twig)
	for at in tips + [Vector2(5.5, 11), Vector2(11, 10.5), Vector2(7, 5)]:
		K.ellipse(im, at.x, at.y, size.x, size.y, leaf)
		K.px(im, int(at.x), int(at.y), (underside if underside.a > 0.0 else leaf.lightened(0.2)))
	return im


## A low mound of small leaves on red stems (the manzanitas).
func _mound(leaf: Color, stem: Color, height: float, bell := Color(0, 0, 0, 0)) -> Image:
	var im := K.make(S, S)
	for x in [4, 8, 12]:
		_seg(im, 8, 15, x, 15.0 - height, stem)
	for i in 14:
		var at := Vector2(2.5 + K.hash2(i, 1, 9) * 11.0, 15.0 - height - 1.5 + K.hash2(i, 2, 9) * height)
		K.ellipse(im, at.x, at.y, 1.5, 1.1, leaf if i % 3 else leaf.lightened(0.2))
	if bell.a > 0.0:
		for at in [Vector2i(5, 11), Vector2i(10, 12), Vector2i(8, 9)]:
			K.px(im, at.x, at.y, bell)
	return im


## A wildflower: stems with a flower head on each, and leaves at the foot.
## Each head is [x, y, radius]; [param eye] is the flower's center.
func _flower(petal: Color, heads: Array, stem: Color, leaf: Color, eye := Color(0, 0, 0, 0)) -> Image:
	var im := K.make(S, S)
	for head: Array in heads:
		_seg(im, 8, 15, head[0], head[1], stem)
	K.ellipse(im, 5.5, 13.5, 2.2, 1.2, leaf)
	K.ellipse(im, 10.5, 13.0, 2.2, 1.2, leaf.darkened(0.12))
	for head: Array in heads:
		K.ellipse(im, head[0] + 0.5, head[1] + 0.5, head[2], head[2], petal)
		K.px(im, int(head[0]), int(head[1]) - 1, petal.lightened(0.3))
		if eye.a > 0.0:
			K.px(im, int(head[0]), int(head[1]), eye)
	return im


## A spike of small flowers up a stem (lupine, paintbrush, snow plant).
func _spike(petal: Color, tip: Color, stem: Color, leaf: Color, spikes := [8]) -> Image:
	var im := K.make(S, S)
	for x: int in spikes:
		_seg(im, x, 15, x, 4, stem)
		for y in range(3, 11):
			var wide := 1 if y < 5 else 2
			var col := tip if y < 5 else (petal if y % 2 else petal.darkened(0.18))
			K.rect(im, x - wide + 1, y, wide * 2 - 1, 1, col)
	if leaf.a > 0.0:
		for at in [Vector2(4.5, 13.0), Vector2(11.5, 13.5), Vector2(8.0, 14.0)]:
			K.ellipse(im, at.x, at.y, 2.4, 1.0, leaf)
	return im


# ---------------------------------------------------------------- the plants

func _black_oak() -> Image:
	# Deep-lobed leaves: a leaf with notches cut into each side.
	var im := _broadleaf(Color("5c9a3e"), Vector2(2.6, 1.8), BARK)
	for at in [Vector2i(3, 7), Vector2i(5, 7), Vector2i(11, 6), Vector2i(13, 6), Vector2i(7, 8), Vector2i(9, 8)]:
		K.px(im, at.x, at.y + 1, Color(0, 0, 0, 0))
		im.set_pixel(at.x, at.y + 1, Color(0, 0, 0, 0))
	K.ellipse(im, 9.5, 13.5, 1.2, 1.4, Color("9a6a34")) # an acorn
	K.hline(im, 8, 12, 3, Color("6b4a2e"))
	return im


func _incense_cedar() -> Image:
	return _spray(Color("5f9440"), Color("a5532f"))


func _ponderosa_pine() -> Image:
	return _conifer(Color("4c8440"), 5.5, 0.35, Color("8a5a30"), Vector2(1.8, 2.2))


func _canyon_live_oak() -> Image:
	return _broadleaf(Color("3f7040"), Vector2(2.0, 1.3), BARK, Color("d0b050"))


func _greenleaf_manzanita() -> Image:
	return _mound(Color("7fae4e"), Color("a23a2a"), 8.0, Color("f0c8d0"))


func _western_azalea() -> Image:
	return _flower(Color("f6f1ea"), [[4, 6, 2.2], [11, 5, 2.2], [8, 8, 1.8]], TWIG, Color("4f8a3c"), Color("f0c040"))


func _showy_milkweed() -> Image:
	var im := _flower(Color("e39ab4"), [[8, 5, 2.8]], Color("9ab08a"), Color("9ab890"))
	K.ellipse(im, 4.5, 10.0, 2.4, 1.2, Color("9ab890"))
	K.ellipse(im, 11.5, 9.0, 2.4, 1.2, Color("8aa880"))
	for at in [Vector2i(7, 4), Vector2i(9, 6), Vector2i(8, 3)]:
		K.px(im, at.x, at.y, Color("f6dce6"))
	return im


func _broadleaf_lupine() -> Image:
	return _spike(Color("6a6ad0"), Color("b8b0f0"), Color("5a8a4a"), Color("5f9a50"), [6, 10])


func _bracken_fern() -> Image:
	var im := K.make(S, S)
	var frond := Color("5a9a48")
	for side in [-1, 0, 1]:
		var top := Vector2(8 + side * 5, 4 + absi(side) * 2)
		_seg(im, 8, 15, top.x, top.y, Color("6a7a3a"))
		for i in 5:
			var t := float(i) / 5.0
			var mid := Vector2(8, 15).lerp(top, 0.25 + t * 0.75)
			var reach := 3.0 * (1.0 - t) + 1.0
			_seg(im, mid.x - reach, mid.y + 1, mid.x + reach, mid.y - 1 if side == 0 else mid.y + 1, frond if i % 2 else frond.lightened(0.15))
	return im


func _pacific_dogwood() -> Image:
	return _flower(Color("f4efe2"), [[4, 6, 2.4], [11, 5, 2.4]], BARK, Color("5a9648"), Color("9ab040"))


func _western_redbud() -> Image:
	var im := K.make(S, S)
	for tip in _twig(im, Color("5a4034")):
		for i in 5:
			K.px(im, int(tip.x) + [0, 1, -1, 1, -1][i], int(tip.y) + [0, 1, 2, 3, 4][i], Color("d84a9a") if i % 2 else Color("ee7ab8"))
	K.ellipse(im, 11.0, 11.5, 2.0, 1.6, Color("5f9a50")) # a heart-shaped leaf
	K.px(im, 11, 10, Color(0, 0, 0, 0))
	im.set_pixel(11, 10, Color(0, 0, 0, 0))
	return im


func _california_poppy() -> Image:
	var im := _flower(Color("f08a1c"), [[5, 7, 2.3], [11, 5, 2.3]], Color("7a9a6a"), Color("8aa890"), Color("f8c030"))
	for at in [Vector2i(4, 13), Vector2i(7, 12), Vector2i(12, 13)]:
		K.px(im, at.x, at.y, Color("a0b8a0")) # feathery gray-green leaves
	return im


func _california_buckeye() -> Image:
	var im := _broadleaf(Color("6aa04a"), Vector2(2.6, 1.2), Color("9a9080"))
	K.ellipse(im, 5.0, 12.0, 1.8, 1.8, Color("a8642c")) # the big seed
	K.px(im, 5, 12, Color("e8d0a0"))
	return im


func _gray_pine() -> Image:
	return _conifer(Color("8aa08a"), 6.0, 0.45, Color("7a5630"), Vector2(2.2, 2.6))


func _giant_sequoia() -> Image:
	var im := _spray(Color("4a8650"), Color("a04a2a"), Color(0, 0, 0, 0), false)
	K.ellipse(im, 11.0, 11.5, 1.6, 2.0, Color("6a9a4a")) # the egg-sized green cone
	K.px(im, 11, 11, Color("9aba6a"))
	return im


func _sugar_pine() -> Image:
	var im := _conifer(Color("3f7a52"), 4.0, 0.1)
	K.rect(im, 11, 9, 2, 7, Color("b08040")) # the long hanging cone
	for y in [10, 12, 14]:
		K.px(im, 11, y, Color("7a5628"))
	return im


func _mountain_misery() -> Image:
	var im := _mound(Color("4f7a3a"), Color("5a4630"), 5.0)
	for at in [Vector2i(5, 9), Vector2i(10, 8), Vector2i(8, 11)]:
		K.px(im, at.x, at.y, Color("f4f0e4")) # small white strawberry-like flowers
	return im


func _jeffrey_pine() -> Image:
	return _conifer(Color("4a7e68"), 5.5, 0.3, Color("9a6a3a"), Vector2(2.0, 2.6))


func _red_fir() -> Image:
	return _conifer(Color("5a8a90"), 3.0, -0.25, Color("8a6a90"), Vector2(1.6, 2.8), true)


func _pinemat_manzanita() -> Image:
	return _mound(Color("5f9a48"), Color("8a3a2a"), 3.5, Color("f4e0e0"))


func _snow_plant() -> Image:
	var im := _spike(Color("d8281c"), Color("f06040"), Color("b82018"), Color(0, 0, 0, 0))
	K.rect(im, 6, 10, 5, 5, Color("c8241a")) # fleshy all the way down, and no leaves
	K.px(im, 7, 12, Color("f06a4a"))
	K.px(im, 9, 9, Color("f06a4a"))
	return im


func _lodgepole_pine() -> Image:
	return _conifer(Color("5a8a3a"), 3.0, 0.0, Color("8a6a4a"), Vector2(1.3, 1.5))


func _sierra_juniper() -> Image:
	return _spray(Color("6a9a70"), Color("b06a3a"), Color("6a80b0"), false)


func _white_heather() -> Image:
	# A low mat of leaves pressed tight as braid, red stalks, nodding white bells.
	var im := _mound(Color("3f6a3a"), Color("4a5a34"), 4.0)
	for x in [3, 7, 11]:
		_seg(im, x, 10, x + 1, 7, Color("b0403a"))
		K.px(im, x + 1, 6, Color("f6f4ee"))
		K.px(im, x + 2, 7, Color("f6f4ee"))
		K.px(im, x + 2, 6, Color("e0dcd0"))
	return im


func _alpine_shooting_star() -> Image:
	var im := K.make(S, S)
	_seg(im, 8, 15, 8, 5, Color("7a8a5a"))
	K.ellipse(im, 5.5, 14.0, 2.6, 1.0, Color("5f9a50"))
	K.ellipse(im, 10.5, 14.0, 2.6, 1.0, Color("4f8a44"))
	for head in [Vector2i(5, 6), Vector2i(11, 5), Vector2i(8, 3)]:
		_seg(im, 8, 6, head.x, head.y, Color("7a8a5a"))
		# swept-back petals over a dark point
		K.px(im, head.x, head.y - 1, Color("d850b0"))
		K.px(im, head.x - 1, head.y - 2, Color("e878c8"))
		K.px(im, head.x + 1, head.y - 2, Color("e878c8"))
		K.px(im, head.x, head.y, Color("f4e060"))
		K.px(im, head.x, head.y + 1, Color("3a2030"))
	return im


func _lemmons_paintbrush() -> Image:
	return _spike(Color("c84a90"), Color("e880b8"), Color("6a8a4a"), Color("6a9a50"), [5, 9, 12])
