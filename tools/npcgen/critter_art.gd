extends SceneTree
## Paints the little birds and butterflies of scripts/world/critters.gd into
## assets/sprites/critters.png, in the style of the people: shaded, lit from
## the upper left, with the dark rim every sprite has.
##
##   godot --headless --path . -s res://tools/npcgen/critter_art.gd
##   godot --headless --path . --import
##
## One row per bird (Critters.BIRD_ROWS order), facing right, in 12x11 frames:
## standing, pecking, wings up, wings down. The last row holds the
## butterflies, one 8x8 pair (wings open, wings closed) per kind.

const W := 12
const H := 11
const OUT := "res://assets/sprites/critters.png"
## The sheet is wide enough for the butterflies' row (four pairs of 8x8).
const SHEET_W := 64
const OUTLINE := Color("2a1f1a")
const EYE := Color("101010")
const GLINT := Color("fbf6ea")
const LEGS := Color("5a4030")

## size: body half-width and half-height; extra: crest or plume.
const BIRDS := [
	{"id": "stellers_jay", "body": "2f5aa8", "head": "1c1c2a", "breast": "4a7ac8", "wing": "24488a", "tail": "1e3a78", "beak": "1a1a1a", "size": [3.6, 2.3], "crest": true},
	{"id": "junco", "body": "8a7464", "head": "34343c", "breast": "ece8e0", "wing": "5a5050", "tail": "3a3a40", "beak": "e8c8b0", "size": [2.8, 2.0]},
	{"id": "robin", "body": "5a5250", "head": "2a2626", "breast": "d8602a", "wing": "484040", "tail": "2e2a2a", "beak": "e0b030", "size": [3.3, 2.3]},
	{"id": "quail", "body": "7a7a86", "head": "4a3a30", "breast": "b89a70", "wing": "6a5a48", "tail": "5a5a64", "beak": "2a2a2a", "size": [3.4, 2.6], "plume": true},
]
## Butterflies: wing color, wing edge, as in Critters.WINGS.
const WINGS := [
	["f0d040", "2a2420"],
	["e88a30", "2a2a30"],
	["3a3440", "f0a040"],
	["f4f0e8", "8a8a8a"],
]

var im: Image


func _init() -> void:
	im = Image.create_empty(SHEET_W, H * (BIRDS.size() + 1), false, Image.FORMAT_RGBA8)
	for row in BIRDS.size():
		for frame in 4:
			_bird(BIRDS[row], frame, Vector2i(frame * W, row * H))
	for kind in WINGS.size():
		for frame in 2:
			_butterfly(WINGS[kind], frame == 0, Vector2i((kind * 2 + frame) * 8, BIRDS.size() * H + 1))
	im.save_png(OUT)
	var preview := Image.create_empty(im.get_width(), im.get_height(), false, Image.FORMAT_RGBA8)
	preview.fill(Color("5a9a3e"))
	preview.blend_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i.ZERO)
	preview.resize(im.get_width() * 8, im.get_height() * 8, Image.INTERPOLATE_NEAREST)
	preview.save_png("res://docs/critters_preview.png")
	print("Critters written to %s. Run godot --headless --path . --import next." % OUT)
	quit()


func c(hex: String) -> Color:
	return Color(hex)


func px(o: Vector2i, x: int, y: int, color: Color, region := Vector2i(W, H)) -> void:
	if x >= 0 and y >= 0 and x < region.x and y < region.y:
		im.set_pixel(o.x + x, o.y + y, color)


## A blob lit from the upper left.
func blob(o: Vector2i, cx: float, cy: float, rx: float, ry: float, base: Color, region := Vector2i(W, H)) -> void:
	for y in range(floori(cy - ry), ceili(cy + ry) + 1):
		for x in range(floori(cx - rx), ceili(cx + rx) + 1):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy > 1.0:
				continue
			var lit := -dx * 0.6 - dy * 0.8
			var shade := base.lightened(0.15) if lit > 0.55 else (base.darkened(0.2) if lit < -0.5 else base)
			px(o, x, y, shade, region)


func outline(o: Vector2i, size: Vector2i) -> void:
	var edge: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			if im.get_pixel(o.x + x, o.y + y).a > 0.5:
				continue
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n := Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < size.x and n.y < size.y and im.get_pixel(o.x + n.x, o.y + n.y).a > 0.5 \
						and im.get_pixel(o.x + n.x, o.y + n.y) != EYE and im.get_pixel(o.x + n.x, o.y + n.y) != LEGS:
					edge.append(Vector2i(x, y))
					break
	for p in edge:
		im.set_pixel(o.x + p.x, o.y + p.y, OUTLINE)


## Frame 0 standing, 1 pecking (head down), 2 wings up, 3 wings down.
func _bird(look: Dictionary, frame: int, o: Vector2i) -> void:
	var size: Array = look.size
	var rx: float = size[0]
	var ry: float = size[1]
	var flying := frame >= 2
	var body_y := 7.0 if not flying else 6.0
	# tail, angled up behind
	for i in 3:
		px(o, 1 + i, int(body_y) - 1 + (1 if i == 2 else 0), c(look.tail))
	px(o, 1, int(body_y) - 2, c(look.tail))
	# body, breast underneath
	blob(o, 5.5, body_y, rx, ry, c(look.body))
	blob(o, 6.3, body_y + 0.8, rx * 0.6, ry * 0.6, c(look.breast))
	# head: up and forward, or down at the ground
	var head := Vector2(8.3, body_y - 2.4) if frame != 1 else Vector2(8.8, body_y + 0.6)
	blob(o, head.x, head.y, 1.9, 1.8, c(look.head))
	var eye := Vector2i(int(head.x) + 0, int(head.y) - 1)
	px(o, eye.x, eye.y, EYE)
	# the beak
	px(o, int(head.x) + 2, int(head.y) + (0 if frame != 1 else 1), c(look.beak))
	if frame != 1:
		px(o, int(head.x) + 2, int(head.y) - 0, c(look.beak))
	if look.get("crest", false):
		px(o, int(head.x) - 1, int(head.y) - 2, c(look.head))
		px(o, int(head.x) - 2, int(head.y) - 3, c(look.head))
	if look.get("plume", false):
		px(o, int(head.x), int(head.y) - 2, c("2a2020"))
		px(o, int(head.x) + 1, int(head.y) - 3, c("2a2020"))
	# the wing: folded on the side, or beating
	match frame:
		0, 1:
			for x in range(4, 7):
				px(o, x, int(body_y) - 1, c(look.wing))
			px(o, 5, int(body_y), c(look.wing))
		2:
			for i in 4:
				px(o, 4 + i / 2, int(body_y) - 2 - i, c(look.wing))
				px(o, 5 + i / 2, int(body_y) - 2 - i, c(look.wing).lightened(0.15))
		3:
			for i in 3:
				px(o, 4 + i, int(body_y) + 1 + i / 2, c(look.wing))
				px(o, 5 + i, int(body_y) + 2 + i / 2, c(look.wing).darkened(0.15))
	outline(o, Vector2i(W, H))
	# legs go on after the rim, thin and dark
	if not flying:
		px(o, 5, int(body_y + ry) + 1, LEGS)
		px(o, 7, int(body_y + ry) + 1, LEGS)


func _butterfly(colors: Array, open: bool, o: Vector2i) -> void:
	var wing := c(colors[0])
	var edge := c(colors[1])
	var region := Vector2i(8, 8)
	if open:
		blob(o, 2.2, 2.6, 2.0, 2.0, wing, region)
		blob(o, 5.8, 2.6, 2.0, 2.0, wing, region)
		blob(o, 2.6, 5.4, 1.4, 1.3, wing.darkened(0.1), region)
		blob(o, 5.4, 5.4, 1.4, 1.3, wing.darkened(0.1), region)
		px(o, 1, 1, edge, region)
		px(o, 6, 1, edge, region)
		px(o, 1, 3, edge, region)
		px(o, 6, 3, edge, region)
	else:
		blob(o, 4.0, 3.0, 1.0, 2.4, wing, region)
		px(o, 4, 1, edge, region)
	for y in range(2, 7):
		px(o, 4 if open else 3, y, c("2a2420"), region)
