extends SceneTree
## Paints the black bears of scripts/world/bears.gd into
## assets/sprites/bears.png, in the style of the critters: shaded, lit from
## the upper left, with the dark rim every sprite has. They are painted at
## the 32px art's size, so they skip tools/art32.
##
##   godot --headless --path . -s res://tools/npcgen/bear_art.gd
##   godot --headless --path . --import
##
## One row per coat (Bears.COATS order), facing right: four 40x28 frames of a
## grown bear (walking, the other step, nose down at the ground, head up and
## looking round at you), then two 24x18 frames of a cub walking, set at the
## foot of a 24x28 cell; then two more of the bear (its legs passing under
## it mid-stride, and its nose shoved along the ground, rooting) and the
## cub's passing step. A black bear has no shoulder hump (a grizzly does),
## its rump stands a little higher than its shoulders, its ears are big and
## round, and its muzzle is tan whatever color the rest of it is.

const W := 40
const H := 28
const CUB := Vector2i(24, 18)
const OUT := "res://assets/sprites/bears.png"
const OUTLINE := Color("1e1612")
const EYE := Color("0c0a08")
const NOSE := Color("1a1410")
const CLAW := Color("d8ccb4")

## Coat, belly and leg shade, muzzle. Yosemite's bears are mostly brown or
## cinnamon; a few are blond, and fewer than you'd think are black.
const COATS := [
	{"id": "brown", "coat": "6a4428", "legs": "4a2e1a", "muzzle": "b08a60"},
	{"id": "cinnamon", "coat": "9a5a2c", "legs": "6e3e1e", "muzzle": "c89a6a"},
	{"id": "blond", "coat": "b88a54", "legs": "8a6438", "muzzle": "dcc08e"},
	{"id": "black", "coat": "2a2624", "legs": "1c1a18", "muzzle": "9a7a58"},
]

var im: Image


func _init() -> void:
	im = Image.create_empty(W * 6 + CUB.x * 3, H * COATS.size(), false, Image.FORMAT_RGBA8)
	for row in COATS.size():
		for frame in 4:
			_bear(COATS[row], frame, Vector2i(frame * W, row * H))
		for frame in 2:
			_cub(COATS[row], frame, Vector2i(W * 4 + frame * CUB.x, row * H + H - CUB.y))
		for frame in [4, 5]:
			_bear(COATS[row], frame, Vector2i(W * 4 + CUB.x * 2 + (frame - 4) * W, row * H))
		_cub(COATS[row], 2, Vector2i(W * 6 + CUB.x * 2, row * H + H - CUB.y))
	im.save_png(OUT)
	var preview := Image.create_empty(im.get_width(), im.get_height(), false, Image.FORMAT_RGBA8)
	preview.fill(Color("5a9a3e"))
	preview.blend_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i.ZERO)
	preview.resize(im.get_width() * 4, im.get_height() * 4, Image.INTERPOLATE_NEAREST)
	preview.save_png("res://docs/bears_preview.png")
	print("Bears written to %s. Run godot --headless --path . --import next." % OUT)
	quit()


func px(o: Vector2i, x: int, y: int, color: Color, size := Vector2i(W, H)) -> void:
	if x >= 0 and y >= 0 and x < size.x and y < size.y:
		im.set_pixel(o.x + x, o.y + y, color)


## A blob lit from the upper left, with a soft band of fur shading.
func blob(o: Vector2i, cx: float, cy: float, rx: float, ry: float, base: Color, size := Vector2i(W, H)) -> void:
	for y in range(floori(cy - ry), ceili(cy + ry) + 1):
		for x in range(floori(cx - rx), ceili(cx + rx) + 1):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy > 1.0:
				continue
			var lit := -dx * 0.5 - dy * 0.85
			var shade := base
			if lit > 0.6:
				shade = base.lightened(0.18)
			elif lit > 0.25:
				shade = base.lightened(0.07)
			elif lit < -0.55:
				shade = base.darkened(0.25)
			px(o, x, y, shade, size)


## A leg from [param top] down to the ground at [param foot_y], [param w] wide.
func leg(o: Vector2i, x: int, top: int, foot_y: int, w: int, color: Color, size := Vector2i(W, H)) -> void:
	for y in range(top, foot_y + 1):
		for i in w:
			px(o, x + i, y, color if i > 0 else color.lightened(0.08), size)
	for i in w:
		px(o, x + i, foot_y, color.darkened(0.2), size)


func outline(o: Vector2i, size: Vector2i) -> void:
	var edge: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			if im.get_pixel(o.x + x, o.y + y).a > 0.5:
				continue
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n := Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < size.x and n.y < size.y and im.get_pixel(o.x + n.x, o.y + n.y).a > 0.5:
					edge.append(Vector2i(x, y))
					break
	for p in edge:
		im.set_pixel(o.x + p.x, o.y + p.y, OUTLINE)


## Frame 0 and 1 walking, 2 nose down, 3 head up and turned to look at you,
## 4 the legs passing mid-stride, 5 rooting (nose down, shoved forward).
func _bear(look: Dictionary, frame: int, o: Vector2i) -> void:
	var coat := Color(look.coat)
	var legs := Color(look.legs)
	var foot := H - 2
	# the far legs first, a shade darker, then the body over their tops
	var stride := 0 if frame >= 2 else (2 if frame == 0 else -2)
	leg(o, 9 - stride, 16, foot, 4, legs.darkened(0.2))
	leg(o, 26 + stride, 16, foot, 4, legs.darkened(0.2))
	# the body: rump a little higher and rounder than the shoulders
	blob(o, 13.0, 13.0, 9.0, 7.0, coat)
	blob(o, 21.0, 14.0, 9.5, 6.5, coat)
	blob(o, 26.0, 15.0, 5.0, 5.5, coat)
	# a short tail at the rump
	px(o, 4, 11, coat.darkened(0.2))
	px(o, 3, 12, coat.darkened(0.2))
	# the near legs
	leg(o, 11 + stride, 17, foot, 5, legs)
	leg(o, 27 - stride, 17, foot, 5, legs)
	# the head: level, low to the ground, or up and turned
	var head := Vector2(34.5, 13.5)
	match frame:
		1:
			head = Vector2(34.5, 14.5)
		2:
			head = Vector2(34.5, 20.0)
		3:
			head = Vector2(33.0, 11.0)
		4:
			head = Vector2(34.5, 13.0)
		5:
			head = Vector2(35.0, 19.0)
	blob(o, head.x - 1.0, head.y, 4.6, 4.3, coat)
	# a darker ruff of fur where the head meets the shoulders
	if frame != 3:
		for y in range(int(head.y) - 3, int(head.y) + 4):
			px(o, int(head.x) - 5, y, coat.darkened(0.3))
	# ears: big and round, set on top
	blob(o, head.x - 3.2, head.y - 3.8, 1.7, 1.7, coat)
	if frame == 3:
		blob(o, head.x + 0.4, head.y - 4.0, 1.7, 1.7, coat)
	else:
		blob(o, head.x - 0.6, head.y - 4.2, 1.5, 1.5, coat.darkened(0.12))
	# the tan muzzle
	if frame == 3:
		blob(o, head.x + 1.2, head.y + 1.6, 2.4, 2.0, Color(look.muzzle))
	else:
		blob(o, head.x + 3.4, head.y + 0.8, 2.6, 2.0, Color(look.muzzle))
	outline(o, Vector2i(W, H))
	# the face goes on after the rim
	if frame == 3:
		px(o, int(head.x) - 2, int(head.y) - 1, EYE)
		px(o, int(head.x) + 2, int(head.y) - 1, EYE)
		px(o, int(head.x), int(head.y) + 1, NOSE)
		px(o, int(head.x) + 1, int(head.y) + 1, NOSE)
	else:
		px(o, int(head.x), int(head.y) - 1, EYE)
		px(o, int(head.x) + 5, int(head.y), NOSE)
		px(o, int(head.x) + 5, int(head.y) + 1, NOSE)
	# claws on the near front foot
	px(o, 30 - stride, foot, CLAW)
	px(o, 31 - stride, foot, CLAW)


## A cub: round, big-eared, all head and fluff. Frames 0 and 1 are its steps,
## 2 its legs passing between them.
func _cub(look: Dictionary, frame: int, o: Vector2i) -> void:
	var coat := Color(look.coat)
	var legs := Color(look.legs)
	var foot := CUB.y - 2
	var stride: int = [1, -1, 0][frame]
	leg(o, 6 - stride, 10, foot, 3, legs.darkened(0.2), CUB)
	leg(o, 15 + stride, 10, foot, 3, legs.darkened(0.2), CUB)
	blob(o, 10.0, 9.0, 7.0, 4.8, coat, CUB)
	leg(o, 7 + stride, 11, foot, 3, legs, CUB)
	leg(o, 15 - stride, 11, foot, 3, legs, CUB)
	var head := Vector2(18.0, 7.5 + (0.5 if frame == 1 else 0.0))
	blob(o, head.x, head.y, 3.6, 3.4, coat, CUB)
	blob(o, head.x - 2.2, head.y - 3.0, 1.4, 1.4, coat, CUB)
	blob(o, head.x + 2.2, head.y + 0.8, 1.8, 1.4, Color(look.muzzle), CUB)
	outline(o, CUB)
	px(o, int(head.x), int(head.y) - 1, EYE, CUB)
	px(o, int(head.x) + 3, int(head.y), NOSE, CUB)
