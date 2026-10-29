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


## Flat-topped clusters of tiny flowers on branching stems (yarrow,
## elderberry, buckwheat). Each head is [x, y, width].
func _umbel(flower: Color, heads: Array, stem: Color, leaf: Color) -> Image:
	var im := K.make(S, S)
	for head: Array in heads:
		_seg(im, 8, 15, head[0], head[1] + 1, stem)
	K.ellipse(im, 5.0, 13.0, 2.4, 1.1, leaf)
	K.ellipse(im, 11.0, 12.5, 2.4, 1.1, leaf.darkened(0.12))
	for head: Array in heads:
		K.ellipse(im, head[0] + 0.5, head[1] + 0.5, head[2], 1.4, flower)
		for i in 3:
			K.px(im, int(head[0]) - 1 + i, int(head[1]) - 1, flower.lightened(0.25) if i % 2 else flower.darkened(0.12))
	return im


## Bells nodding from an arching stem (lilies of the shade, saprophytes,
## heaths). [param bells] is how many hang down the arch.
func _bells(bell: Color, stem: Color, leaf: Color, bells := 4, mouth := Color(0, 0, 0, 0)) -> Image:
	var im := K.make(S, S)
	_seg(im, 6, 15, 6, 4, stem)
	_seg(im, 6, 4, 12, 3, stem)
	if leaf.a > 0.0:
		K.ellipse(im, 4.0, 12.5, 2.2, 1.0, leaf)
		K.ellipse(im, 9.0, 13.0, 2.4, 1.0, leaf.darkened(0.12))
	for i in bells:
		var x := 7 + i * 5 / maxi(bells - 1, 1)
		var y := 5 + (i % 2)
		K.rect(im, x, y, 2, 2, bell)
		K.px(im, x, y + 2, mouth if mouth.a > 0.0 else bell.darkened(0.2))
	return im


## A tuft of blades (grasses, sedges, rushes). [param head] tops some blades
## with a seed head or a cattail.
func _tuft(blade: Color, head := Color(0, 0, 0, 0), head_size := Vector2(0.9, 1.6), blades := 7) -> Image:
	var im := K.make(S, S)
	for i in blades:
		var t := float(i) / (blades - 1)
		var top := Vector2(2.0 + t * 12.0, 3.0 + absf(t - 0.5) * 8.0)
		_seg(im, 8, 15, top.x, top.y, blade if i % 2 else blade.lightened(0.15))
	if head.a > 0.0:
		for x in [5, 8, 11]:
			K.ellipse(im, x + 0.5, 4.0 + absf(x - 8) * 0.6, head_size.x, head_size.y, head)
	return im


## Fern fronds fanned from the ground. [param fronds] is how many.
func _frond(frond: Color, stem: Color, fronds := 3, spread := 5.0) -> Image:
	var im := K.make(S, S)
	for f in fronds:
		var side := lerpf(-1.0, 1.0, float(f) / maxi(fronds - 1, 1))
		var top := Vector2(8 + side * spread, 3 + absf(side) * 3)
		_seg(im, 8, 15, top.x, top.y, stem)
		for i in 5:
			var t := float(i) / 5.0
			var mid := Vector2(8, 15).lerp(top, 0.3 + t * 0.7)
			var reach := 2.4 * (1.0 - t) + 0.8
			_seg(im, mid.x - reach, mid.y, mid.x + reach, mid.y, frond if i % 2 else frond.lightened(0.15))
	return im


## A big trumpet or cup flower on a tall stem, with whorled leaves (lilies).
## [param spot] freckles the petals.
func _lily(petal: Color, spot: Color, stem: Color, leaf: Color, heads := [[5, 4], [11, 6]]) -> Image:
	var im := K.make(S, S)
	_seg(im, 8, 15, 8, 6, stem)
	for y in [10, 13]:
		_seg(im, 5, y, 11, y - 1, leaf)
	for head: Array in heads:
		_seg(im, 8, 7, head[0], head[1] + 2, stem)
		K.ellipse(im, head[0] + 0.5, head[1] + 0.5, 2.4, 1.8, petal)
		K.px(im, head[0] - 2, head[1] - 1, petal.lightened(0.2))
		K.px(im, head[0] + 2, head[1] - 1, petal.lightened(0.2))
		if spot.a > 0.0:
			K.px(im, head[0], head[1], spot)
			K.px(im, head[0] + 1, head[1] + 1, spot)
	return im


## A low rosette of leaves with short-stalked flowers (granite and cliff
## plants: lewisia, pussypaws, primrose).
func _rosette(leaf: Color, petal: Color, eye := Color(0, 0, 0, 0), flowers := 3) -> Image:
	var im := K.make(S, S)
	for i in 6:
		var a := PI + float(i) / 5.0 * PI
		K.ellipse(im, 8.0 + cos(a) * 3.5, 13.5 + sin(a) * 1.2, 2.0, 1.0, leaf if i % 2 else leaf.lightened(0.15))
	for i in flowers:
		var at := Vector2(4.0 + i * 8.0 / maxi(flowers - 1, 1), 8.0 + (i % 2) * 2.0)
		_seg(im, 8, 13, at.x, at.y + 1, leaf.darkened(0.2))
		K.ellipse(im, at.x + 0.5, at.y + 0.5, 1.8, 1.6, petal)
		if eye.a > 0.0:
			K.px(im, int(at.x), int(at.y), eye)
	return im


## Berries or fruit dotted onto a drawing.
func _dots(im: Image, col: Color, at: Array) -> Image:
	for p: Vector2i in at:
		K.px(im, p.x, p.y, col)
		K.px(im, p.x + 1, p.y, col.darkened(0.2))
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


# The Valley floor's trees, shrubs and wildflowers.

func _white_alder() -> Image:
	var im := _broadleaf(Color("4f8a44"), Vector2(2.0, 1.6), Color("8a8a7a"))
	for at in [Vector2i(12, 11), Vector2i(13, 13)]:
		K.rect(im, at.x, at.y, 1, 2, Color("6a4a30")) # the little woody cones
	return im


func _black_cottonwood() -> Image:
	var im := _broadleaf(Color("5a9a48"), Vector2(2.2, 1.8), Color("9a9484"), Color("c8d0b0"))
	return _dots(im, Color("f6f4ee"), [Vector2i(3, 4), Vector2i(13, 3), Vector2i(10, 2)]) # the fluff


func _shining_willow() -> Image:
	return _broadleaf(Color("5f9a40"), Vector2(2.8, 0.9), Color("a07a3a"), Color("b8c8a0"))


func _scouring_rush() -> Image:
	var im := K.make(S, S)
	for x in [5, 8, 11]:
		_seg(im, x, 15, x, 3 + absi(x - 8), Color("4f8a50"))
		for y in range(5 + absi(x - 8), 15, 3):
			K.px(im, x, y, Color("2a3a2a")) # the joints
		K.px(im, x, 2 + absi(x - 8), Color("6a5a3a"))
	return im


func _white_fir() -> Image:
	return _conifer(Color("7a9aa0"), 3.5, -0.1)


func _douglas_fir() -> Image:
	var im := _conifer(Color("3f7a48"), 3.0, 0.15, Color("9a6a40"), Vector2(1.4, 2.2))
	K.px(im, 10, 11, Color("d8c890")) # the mouse's tail
	K.px(im, 12, 12, Color("d8c890"))
	return im


func _bigleaf_maple() -> Image:
	var im := _broadleaf(Color("6aa040"), Vector2(3.0, 2.2), BARK)
	return _dots(im, Color("c8b070"), [Vector2i(3, 12), Vector2i(12, 13)]) # the winged seeds


func _california_bay() -> Image:
	return _broadleaf(Color("3f7a44"), Vector2(2.6, 1.0), Color("6a7a4a"), Color("8ab06a"))


func _thimbleberry() -> Image:
	var im := _broadleaf(Color("6aaa48"), Vector2(2.6, 2.0), Color("8a7050"))
	return _dots(im, Color("d83030"), [Vector2i(7, 11), Vector2i(12, 8)])


func _wood_rose() -> Image:
	var im := _broadleaf(Color("5a9048"), Vector2(1.4, 1.0), Color("8a4a3a"))
	for at in [Vector2(4, 7), Vector2(12, 6)]:
		K.ellipse(im, at.x + 0.5, at.y + 0.5, 1.6, 1.6, Color("e888a8"))
		K.px(im, int(at.x), int(at.y), Color("f0d040"))
	return im


func _deer_brush() -> Image:
	return _umbel(Color("e8ecf6"), [[4, 5, 2.0], [11, 4, 2.2], [8, 7, 1.6]], Color("6a8a5a"), Color("5a9a48"))


func _mugwort() -> Image:
	return _broadleaf(Color("7a9a70"), Vector2(2.2, 1.0), Color("6a7a5a"), Color("c8d0c0"))


func _common_yarrow() -> Image:
	var im := _umbel(Color("f4f0e4"), [[5, 5, 2.4], [11, 6, 2.0]], Color("6a8a5a"), Color("6a9a50"))
	for at in [Vector2i(4, 12), Vector2i(6, 13), Vector2i(11, 12), Vector2i(10, 13)]:
		K.px(im, at.x, at.y, Color("8ab070")) # feathery leaves
	return im


func _western_buttercup() -> Image:
	return _flower(Color("f8d020"), [[5, 7, 1.8], [11, 5, 1.8], [8, 9, 1.4]], Color("6a9a4a"), Color("5a9a48"), Color("fff8a0"))


func _blue_eyed_grass() -> Image:
	var im := _tuft(Color("5a9a48"), Color(0, 0, 0, 0), Vector2.ONE, 5)
	for at in [Vector2(5, 5), Vector2(11, 6)]:
		K.ellipse(im, at.x + 0.5, at.y + 0.5, 1.8, 1.8, Color("5a60c8"))
		K.px(im, int(at.x), int(at.y), Color("f0d040"))
	return im


func _california_goldenrod() -> Image:
	return _spike(Color("e8c020"), Color("f6e070"), Color("6a8a4a"), Color("6a9a50"), [5, 9, 12])


func _spreading_dogbane() -> Image:
	var im := _broadleaf(Color("5a9048"), Vector2(1.8, 1.1), Color("a04838"))
	return _dots(im, Color("f0b0c0"), [Vector2i(3, 6), Vector2i(11, 5), Vector2i(7, 4)])


func _sticky_cinquefoil() -> Image:
	return _flower(Color("f0e090"), [[5, 6, 1.8], [11, 5, 1.8], [8, 8, 1.6]], Color("6a8a4a"), Color("5a8a40"), Color("e0b030"))


func _common_camas() -> Image:
	return _spike(Color("6070d8"), Color("a0a8f0"), Color("5a8a4a"), Color("6aa058"), [8])


func _evening_primrose() -> Image:
	var im := _spike(Color("6a9a50"), Color("6a9a50"), Color("8a7a4a"), Color("6a9a50"), [8])
	for at in [Vector2(5, 4), Vector2(11, 5)]:
		K.ellipse(im, at.x + 0.5, at.y + 0.5, 2.0, 1.8, Color("f6e040"))
	return im


func _sneezeweed() -> Image:
	var im := _flower(Color("f0c020"), [[5, 6, 2.2], [11, 5, 2.2]], Color("6a8a4a"), Color("5a9a48"))
	for head in [Vector2i(5, 5), Vector2i(11, 4)]:
		K.rect(im, head.x, head.y, 2, 2, Color("5a3a20")) # the brown dome
	return im


func _california_rose() -> Image:
	var im := _broadleaf(Color("5a9048"), Vector2(1.6, 1.1), Color("7a4a34"))
	K.ellipse(im, 4.5, 7.5, 1.8, 1.8, Color("f098b8"))
	K.px(im, 4, 7, Color("f0d040"))
	return _dots(im, Color("d03a2a"), [Vector2i(11, 9), Vector2i(12, 6)]) # hips


func _broadleaf_cattail() -> Image:
	return _tuft(Color("6a9a4a"), Color("6a4228"), Vector2(1.1, 2.2), 7)


func _seep_monkeyflower() -> Image:
	var im := _flower(Color("f8d020"), [[5, 6, 2.0], [11, 5, 2.0]], Color("6a9a4a"), Color("5aa048"))
	return _dots(im, Color("c03a20"), [Vector2i(5, 7), Vector2i(11, 6)])


func _crimson_columbine() -> Image:
	var im := _bells(Color("d8302a"), Color("6a8a5a"), Color("6a9a70"), 3, Color("f0d040"))
	return _dots(im, Color("e85040"), [Vector2i(8, 4), Vector2i(13, 4)]) # the spurs


func _maidenhair_fern() -> Image:
	var im := _frond(Color("6ab050"), Color("2a2420"), 5, 5.5)
	return im


func _indian_rhubarb() -> Image:
	var im := K.make(S, S)
	for x in [5, 11]:
		_seg(im, x, 15, x, 7, Color("8a5a4a"))
	K.ellipse(im, 5.0, 6.0, 4.0, 1.6, Color("4f9040")) # umbrella leaves
	K.ellipse(im, 11.5, 7.0, 3.6, 1.4, Color("5aa048"))
	K.ellipse(im, 8.5, 3.0, 1.6, 1.4, Color("f0a0c0"))
	return im


func _chokecherry() -> Image:
	var im := _broadleaf(Color("4f8a40"), Vector2(2.0, 1.3), BARK)
	return _dots(im, Color("3a1828"), [Vector2i(3, 11), Vector2i(4, 12), Vector2i(12, 11), Vector2i(12, 13)])


func _hazelnut() -> Image:
	var im := _broadleaf(Color("6aa048"), Vector2(2.2, 1.8), Color("8a6a4a"))
	K.ellipse(im, 11.5, 12.5, 1.4, 1.4, Color("9ab060")) # the bristly husk
	K.px(im, 11, 12, Color("a07040"))
	return im


func _leopard_lily() -> Image:
	return _lily(Color("f07a20"), Color("6a1a1a"), Color("5a8a3a"), Color("5a9a48"))


func _stream_orchid() -> Image:
	var im := _spike(Color("9aa060"), Color("b8b878"), Color("6a8a4a"), Color("5a9a48"), [8])
	return _dots(im, Color("b8582a"), [Vector2i(7, 6), Vector2i(8, 8), Vector2i(7, 10)])


func _mountain_lady_slipper() -> Image:
	var im := K.make(S, S)
	_seg(im, 8, 15, 8, 6, Color("5a8a4a"))
	K.ellipse(im, 6.0, 11.0, 2.0, 1.2, Color("5a9a48"))
	K.ellipse(im, 10.5, 9.0, 2.0, 1.2, Color("4f8a40"))
	K.ellipse(im, 8.5, 6.5, 1.8, 1.6, Color("f6f4ee")) # the pouch
	_seg(im, 7, 5, 4, 2, Color("6a4a28")) # twisted petals
	_seg(im, 9, 5, 12, 2, Color("6a4a28"))
	K.px(im, 8, 4, Color("6a4a28"))
	return im


# Down the canyon: El Portal's foothill plants.

func _interior_live_oak() -> Image:
	var im := _broadleaf(Color("3f7a3a"), Vector2(1.8, 1.2), BARK)
	K.ellipse(im, 4.5, 13.0, 1.0, 1.4, Color("8a6a34"))
	return im


func _blue_oak() -> Image:
	var im := _broadleaf(Color("7a9a90"), Vector2(2.2, 1.6), Color("a0a090"))
	K.ellipse(im, 11.5, 13.0, 1.0, 1.4, Color("9a7034"))
	return im


func _whiteleaf_manzanita() -> Image:
	return _mound(Color("a8b8a0"), Color("a23a2a"), 8.0, Color("f8c8d0"))


func _toyon() -> Image:
	var im := _broadleaf(Color("3f7a3a"), Vector2(2.4, 1.0), BARK)
	return _dots(im, Color("e02a20"), [Vector2i(6, 6), Vector2i(7, 7), Vector2i(10, 8), Vector2i(11, 9)])


func _chamise() -> Image:
	var im := _conifer(Color("5a7a40"), 2.5, 0.0)
	return _dots(im, Color("f4f0e4"), [Vector2i(8, 5), Vector2i(4, 4), Vector2i(12, 3)])


func _yerba_santa() -> Image:
	return _broadleaf(Color("4a7a3a"), Vector2(2.8, 0.9), Color("6a5a40"), Color("c8c8b0"))


func _bush_monkeyflower() -> Image:
	return _flower(Color("f0a050"), [[4, 6, 1.8], [11, 5, 1.8], [8, 8, 1.6]], Color("4a6a3a"), Color("3f7a3a"), Color("f8d080"))


func _poison_oak() -> Image:
	var im := K.make(S, S)
	var tips := _twig(im, Color("8a6a4a"))
	for tip in tips:
		for d in [Vector2(-1.8, 0.6), Vector2(1.8, 0.6), Vector2(0, -1.4)]: # leaves of three
			K.ellipse(im, tip.x + d.x, tip.y + d.y, 1.4, 1.1, Color("c84a2a") if tip.x > 10 else Color("4f9a3a"))
	return im


func _blue_elderberry() -> Image:
	var im := _umbel(Color("6878a8"), [[5, 5, 2.4], [11, 6, 2.2]], Color("8a8a6a"), Color("5a9a48"))
	return _dots(im, Color("a8b8d8"), [Vector2i(4, 4), Vector2i(10, 5)]) # the dusty bloom


func _wild_grape() -> Image:
	var im := _broadleaf(Color("5a9a40"), Vector2(2.6, 2.0), Color("7a5a3a"))
	for at in [Vector2i(11, 10), Vector2i(12, 10), Vector2i(11, 11), Vector2i(12, 12), Vector2i(11, 12)]:
		K.px(im, at.x, at.y, Color("4a3060"))
	return im


func _spicebush() -> Image:
	var im := _broadleaf(Color("4f8a40"), Vector2(2.4, 1.4), BARK)
	for at in [Vector2(4, 7), Vector2(12, 6)]:
		K.ellipse(im, at.x + 0.5, at.y + 0.5, 1.8, 1.8, Color("8a2a3a"))
		K.px(im, int(at.x), int(at.y), Color("c05a5a"))
	return im


func _elegant_clarkia() -> Image:
	return _flower(Color("e070b0"), [[4, 5, 1.6], [8, 3, 1.6], [12, 6, 1.6]], Color("8a5a4a"), Color("6a9a50"))


func _blue_dicks() -> Image:
	var im := _tuft(Color("6a9a4a"), Color(0, 0, 0, 0), Vector2.ONE, 4)
	K.ellipse(im, 8.5, 3.5, 2.2, 2.0, Color("8a6ad0"))
	K.px(im, 8, 2, Color("b8a0f0"))
	return im


func _harvest_brodiaea() -> Image:
	return _flower(Color("6040b8"), [[5, 4, 1.8], [11, 4, 1.8], [8, 3, 1.6]], Color("8a9a5a"), Color("c8b070"))


func _chinese_houses() -> Image:
	var im := K.make(S, S)
	_seg(im, 8, 15, 8, 3, Color("5a8a4a"))
	for y in [4, 7, 10]:
		K.rect(im, 5, y, 3, 2, Color("8a58c0"))
		K.rect(im, 9, y, 3, 2, Color("f0ecf6"))
	return im


func _fiesta_flower() -> Image:
	return _flower(Color("b8a0e0"), [[4, 7, 1.8], [11, 6, 1.8], [8, 9, 1.4]], Color("6a9a50"), Color("5a9a48"), Color("f6f4ee"))


func _soap_plant() -> Image:
	var im := _tuft(Color("5a8a48"), Color(0, 0, 0, 0), Vector2.ONE, 6)
	K.ellipse(im, 8.0, 14.0, 2.0, 1.6, Color("6a4a30")) # the hairy bulb
	return _dots(im, Color("f6f4ee"), [Vector2i(4, 5), Vector2i(12, 4), Vector2i(8, 2)])


func _coffee_fern() -> Image:
	return _frond(Color("6a8a80"), Color("5a3a2a"), 3, 4.0)


func _pacific_madrone() -> Image:
	var im := _broadleaf(Color("3f7a3a"), Vector2(2.4, 1.3), Color("c05030"))
	return _dots(im, Color("f08030"), [Vector2i(11, 11), Vector2i(12, 12)])


func _superb_mariposa_lily() -> Image:
	return _lily(Color("f4ecf4"), Color("5a2a5a"), Color("7a9a5a"), Color("7a9a5a"), [[5, 5], [11, 4]])


func _congdons_lewisia() -> Image:
	var im := _rosette(Color("4a8a50"), Color("f0b0c8"), Color("d8508a"))
	return im


func _yosemite_onion() -> Image:
	var im := K.make(S, S)
	for x in [5, 11]:
		_seg(im, 8, 15, x, 9, Color("6a9a50"))
	_seg(im, 8, 15, 8, 6, Color("6a9a50"))
	K.ellipse(im, 8.5, 4.5, 2.6, 2.0, Color("f0c8d8"))
	return _dots(im, Color("d890b0"), [Vector2i(7, 4), Vector2i(9, 3)])


# The big trees: Wawona and the Mariposa Grove.

func _oregon_grape() -> Image:
	var im := _broadleaf(Color("3f7a44"), Vector2(1.8, 1.2), BARK, Color("8ab070"))
	return _dots(im, Color("40508a"), [Vector2i(10, 12), Vector2i(11, 13), Vector2i(12, 12)])


func _sierra_plum() -> Image:
	var im := _broadleaf(Color("5a9048"), Vector2(1.8, 1.4), Color("5a3a2a"))
	return _dots(im, Color("d03a3a"), [Vector2i(5, 12), Vector2i(12, 11)])


func _deergrass() -> Image:
	return _tuft(Color("9a9a60"), Color("c8b888"), Vector2(0.6, 2.0), 9)


func _wild_ginger() -> Image:
	var im := K.make(S, S)
	for at in [Vector2(5, 11), Vector2(11, 10), Vector2(8, 13)]:
		K.ellipse(im, at.x, at.y, 2.6, 2.2, Color("3f7a40"))
		K.px(im, int(at.x), int(at.y), Color("a8c8a8")) # silver veins
	K.ellipse(im, 8.0, 14.5, 1.4, 1.0, Color("6a2a2a")) # the hidden flower
	return im


func _pacific_starflower() -> Image:
	var im := K.make(S, S)
	_seg(im, 8, 15, 8, 6, Color("6a8a4a"))
	for a in 5:
		var ang := float(a) / 5.0 * TAU
		_seg(im, 8, 9, 8 + cos(ang) * 4.0, 9 + sin(ang) * 1.6, Color("5aa048"))
	K.ellipse(im, 8.5, 4.5, 1.8, 1.8, Color("f0a8c8"))
	return im


func _washington_lily() -> Image:
	return _lily(Color("f8f4f0"), Color("b08ac0"), Color("5a8a3a"), Color("5a9a48"))


func _spotted_coralroot() -> Image:
	var im := _spike(Color("b04a3a"), Color("c86a50"), Color("a8402a"), Color(0, 0, 0, 0), [8])
	return _dots(im, Color("f6f4ee"), [Vector2i(7, 6), Vector2i(8, 9)])


func _sugar_stick() -> Image:
	var im := _spike(Color("f6f4ee"), Color("f0d0d0"), Color("f0ece4"), Color(0, 0, 0, 0), [8])
	for y in range(4, 15, 2):
		K.px(im, 8, y, Color("c8302a")) # the peppermint stripes
	return im


func _yosemite_ivesia() -> Image:
	return _rosette(Color("6a9a50"), Color("f6f4ee"), Color("e0d080"), 4)


func _bolanders_clover() -> Image:
	return _flower(Color("f0c0d0"), [[5, 8, 1.8], [11, 7, 1.8]], Color("6a8a4a"), Color("5a9a48"), Color("d890a8"))


# The rim: Glacier Point and Sentinel Dome.

func _huckleberry_oak() -> Image:
	return _mound(Color("4a7a40"), Color("6a5a40"), 5.0)


func _bush_chinquapin() -> Image:
	var im := _mound(Color("5a8a40"), Color("6a5a40"), 6.0, Color("d0b050"))
	K.ellipse(im, 11.5, 9.5, 1.6, 1.6, Color("c8a048")) # the spiny burr
	return im


func _mountain_whitethorn() -> Image:
	var im := _mound(Color("8aa090"), Color("a0a090"), 5.0)
	return _dots(im, Color("f6f4ee"), [Vector2i(4, 9), Vector2i(8, 8), Vector2i(12, 9)])


func _sulphur_buckwheat() -> Image:
	return _umbel(Color("f0d030"), [[5, 7, 2.0], [11, 6, 2.0]], Color("9a9a6a"), Color("9ab08a"))


func _scarlet_gilia() -> Image:
	return _spike(Color("e0302a"), Color("f06a4a"), Color("6a8a4a"), Color("6a9a50"), [6, 10])


func _tobacco_brush() -> Image:
	var im := _broadleaf(Color("3f7a44"), Vector2(2.0, 1.4), Color("6a5a40"), Color("a0d090"))
	return _dots(im, Color("f6f4ee"), [Vector2i(4, 5), Vector2i(12, 4)])


func _mountain_pride() -> Image:
	return _flower(Color("e0408a"), [[4, 7, 1.8], [11, 6, 1.8], [8, 9, 1.6]], Color("5a7a4a"), Color("4f8a40"))


func _california_fuchsia() -> Image:
	var im := _flower(Color("e83a20"), [[4, 6, 1.4], [8, 4, 1.4], [12, 6, 1.4]], Color("8a9a7a"), Color("9ab090"))
	return _dots(im, Color("f8a080"), [Vector2i(4, 5), Vector2i(8, 3)])


func _ocean_spray() -> Image:
	return _spike(Color("f0e8d0"), Color("f8f4e8"), Color("8a6a4a"), Color("5a8a40"), [5, 11])


func _western_white_pine() -> Image:
	var im := _conifer(Color("6a9a90"), 4.0, 0.2)
	K.rect(im, 11, 9, 2, 6, Color("a07848"))
	return im


func _sierra_currant() -> Image:
	var im := _broadleaf(Color("6aa048"), Vector2(2.0, 1.6), Color("8a6a4a"))
	return _dots(im, Color("f08ab0"), [Vector2i(5, 9), Vector2i(5, 10), Vector2i(11, 8), Vector2i(11, 9)])


func _sierra_gooseberry() -> Image:
	var im := _broadleaf(Color("5a9048"), Vector2(1.8, 1.4), Color("8a6a4a"))
	for at in [Vector2(5, 12), Vector2(12, 11)]:
		K.ellipse(im, at.x + 0.5, at.y + 0.5, 1.4, 1.4, Color("7a2a5a"))
		K.px(im, int(at.x) - 1, int(at.y) - 1, Color("c8a0b0")) # prickles
	return im


func _pinedrops() -> Image:
	var im := _spike(Color("f0e0b0"), Color("c87a4a"), Color("a0502a"), Color(0, 0, 0, 0), [8])
	return im


func _yosemite_bog_orchid() -> Image:
	return _spike(Color("a0c070"), Color("c8d898"), Color("5a8a4a"), Color("5a9a48"), [8])


# The high country: Tuolumne Meadows.

func _red_heather() -> Image:
	var im := _mound(Color("3f6a3a"), Color("4a5a34"), 4.0)
	return _dots(im, Color("e070a0"), [Vector2i(3, 8), Vector2i(7, 7), Vector2i(11, 8), Vector2i(9, 9)])


func _pussypaws() -> Image:
	return _rosette(Color("4a7a40"), Color("e8a8b8"), Color("f8d8e0"), 3)


func _mule_ears() -> Image:
	var im := _flower(Color("f0c820"), [[5, 4, 2.0], [11, 4, 2.0]], Color("7a9a5a"), Color("a0b090"), Color("c09030"))
	K.ellipse(im, 4.0, 11.0, 2.0, 3.0, Color("a0b090")) # the woolly ears
	K.ellipse(im, 12.0, 11.0, 2.0, 3.0, Color("90a080"))
	return im


func _corn_lily() -> Image:
	var im := _broadleaf(Color("6aa050"), Vector2(2.6, 1.4), Color("6a9a4a"))
	K.rect(im, 7, 1, 2, 4, Color("e8ecd0")) # the flower plume
	return im


func _shorthair_sedge() -> Image:
	return _tuft(Color("5a8a40"), Color("6a5a3a"), Vector2(0.6, 1.2), 9)


func _fireweed() -> Image:
	return _spike(Color("d0408a"), Color("e878b0"), Color("8a4a4a"), Color("5a9048"), [6, 10])


func _lemmons_willow() -> Image:
	var im := _broadleaf(Color("6a9a50"), Vector2(2.4, 0.9), Color("8a4a3a"), Color("c8d0a8"))
	return _dots(im, Color("e8e0a0"), [Vector2i(3, 9), Vector2i(12, 8)]) # catkins


func _mountain_hemlock() -> Image:
	var im := _conifer(Color("4a7a6a"), 2.5, 0.4, Color("8a5a6a"), Vector2(1.2, 1.8))
	_seg(im, 8, 8, 10, 6, Color("4a7a6a")) # the nodding leader
	return im


func _quaking_aspen() -> Image:
	var im := K.make(S, S)
	var tips := _twig(im, Color("d8d8c8"))
	for at in tips + [Vector2(5.5, 11), Vector2(11, 10.5)]:
		K.ellipse(im, at.x, at.y, 1.8, 1.8, Color("e8c030") if at.x > 9 else Color("7ab048"))
	return im


func _labrador_tea() -> Image:
	return _umbel(Color("f6f4ee"), [[5, 5, 2.0], [11, 5, 2.0]], Color("6a5a40"), Color("3f6a3a"))


func _alpine_laurel() -> Image:
	return _flower(Color("e888b8"), [[5, 6, 1.6], [11, 5, 1.6], [8, 4, 1.4]], Color("6a5a40"), Color("3f7a44"), Color("b04880"))


func _elephants_head() -> Image:
	var im := _spike(Color("e070a8"), Color("f0a0c8"), Color("8a4a5a"), Color("6a9a50"), [8])
	return _dots(im, Color("f8c8e0"), [Vector2i(6, 6), Vector2i(10, 8)]) # trunks


func _lewis_monkeyflower() -> Image:
	return _flower(Color("e878a8"), [[5, 6, 2.0], [11, 5, 2.0]], Color("6a9a4a"), Color("5aa048"), Color("f0d040"))


func _dwarf_bilberry() -> Image:
	var im := _mound(Color("5a9a48"), Color("8a5a3a"), 4.0)
	return _dots(im, Color("4a5a9a"), [Vector2i(4, 12), Vector2i(9, 11), Vector2i(12, 12)])


func _leichtlins_mariposa() -> Image:
	return _lily(Color("f6f4ee"), Color("2a2020"), Color("8a9a6a"), Color("8a9a6a"), [[5, 5], [11, 4]])


func _miners_lettuce() -> Image:
	var im := _rosette(Color("5aa048"), Color("6aa848"), Color(0, 0, 0, 0), 3)
	return _dots(im, Color("f4f0e4"), [Vector2i(4, 8), Vector2i(8, 10), Vector2i(12, 8)]) # flowers in the saucers


func _mountain_strawberry() -> Image:
	var im := _rosette(Color("4f8a3c"), Color("f4f0e4"), Color("f0d040"), 2)
	return _dots(im, Color("e02a30"), [Vector2i(7, 11), Vector2i(10, 12)])


func _sierra_onion() -> Image:
	var im := _tuft(Color("6a9a4a"), Color(0, 0, 0, 0), Vector2.ONE, 4)
	_seg(im, 8, 15, 8, 4, Color("6a9a4a"))
	K.ellipse(im, 8.5, 3.5, 2.4, 2.0, Color("e8a0c0"))
	return _dots(im, Color("f8d0e0"), [Vector2i(7, 2), Vector2i(9, 4)])


func _yampah() -> Image:
	return _umbel(Color("f4f0e4"), [[5, 4, 2.0], [11, 5, 1.8], [8, 6, 1.4]], Color("6a8a4a"), Color("6a9a50"))


func _yerba_buena() -> Image:
	var im := _mound(Color("4f8a3c"), Color("6a8a4a"), 4.0)
	return _dots(im, Color("f4f0e4"), [Vector2i(5, 11), Vector2i(10, 12)])


func _coyote_mint() -> Image:
	return _flower(Color("b8a0d8"), [[5, 5, 2.0], [11, 4, 2.0], [8, 7, 1.6]], Color("7a8a6a"), Color("8aa070"), Color("f4f0e4"))


func _california_blackberry() -> Image:
	var im := _broadleaf(Color("4f8a3c"), Vector2(1.8, 1.3), Color("6a4a3a"))
	return _dots(im, Color("2a1a30"), [Vector2i(4, 9), Vector2i(11, 9), Vector2i(8, 5)])


func _whitebark_raspberry() -> Image:
	var im := _broadleaf(Color("5a9048"), Vector2(2.0, 1.4), Color("e0dcd0"))
	return _dots(im, Color("4a2a68"), [Vector2i(5, 10), Vector2i(12, 9)])


func _cow_clover() -> Image:
	var im := _flower(Color("c0508a"), [[5, 5, 2.0], [11, 6, 2.0]], Color("6a9a4a"), Color("4f8a3c"))
	return _dots(im, Color("e8a0c8"), [Vector2i(5, 4), Vector2i(11, 5)])


func _whitebark_pine() -> Image:
	var im := _conifer(Color("4a7a50"), 2.8, 0.0, Color("6a4a5a"), Vector2(1.6, 1.8))
	return im


func _sierra_gentian() -> Image:
	return _flower(Color("3a50c8"), [[5, 5, 1.8], [11, 6, 1.8]], Color("6a8a4a"), Color("5a9a48"), Color("8aa0f0"))


func _explorers_gentian() -> Image:
	var im := _bells(Color("4a40b8"), Color("6a8a4a"), Color("5a9a48"), 2)
	return im


func _white_bog_orchid() -> Image:
	return _spike(Color("f6f4ee"), Color("f8f8f0"), Color("5a8a4a"), Color("5aa048"), [8])


func _sierra_primrose() -> Image:
	return _rosette(Color("3f7a44"), Color("d040a0"), Color("f0d040"), 3)
