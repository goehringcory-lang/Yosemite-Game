extends SceneTree
## Paints the mule deer of scripts/world/deer.gd into
## assets/sprites/deer.png, like the bears (tools/npcgen/bear_art.gd):
## shaded, lit from the upper left, with the dark rim, at the 32px art's size.
##
##   godot --headless --path . -s res://tools/npcgen/deer_art.gd
##   godot --headless --path . --import
##
## One row per look (Deer.LOOKS order), facing right: five 40x40 frames of a
## grown deer (walking, the other step, grazing, head up and looking at you,
## bounding), then two 24x40 frames of a spotted fawn walking. A mule deer
## has the big ears it's named for, a white rump patch, a thin white tail
## with a black tip, a white throat and a dark brow; a buck's antlers fork,
## and fork again. Their coats are reddish in summer and gray in winter.

const W := 40
const H := 40
const FAWN_W := 24
const OUT := "res://assets/sprites/deer.png"
const OUTLINE := Color("1e1612")
const EYE := Color("0c0a08")
const NOSE := Color("141010")
const WHITE := Color("ece6da")
const HOOF := Color("2a2220")
const ANTLER := Color("cbb48a")

const LOOKS := [
	{"id": "doe_summer", "coat": "a06a40", "buck": false},
	{"id": "doe_winter", "coat": "7e7266", "buck": false},
	{"id": "buck_summer", "coat": "946238", "buck": true},
	{"id": "buck_winter", "coat": "746a5e", "buck": true},
]

var im: Image


func _init() -> void:
	im = Image.create_empty(W * 5 + FAWN_W * 2, H * LOOKS.size(), false, Image.FORMAT_RGBA8)
	for row in LOOKS.size():
		for frame in 5:
			_deer(LOOKS[row], frame, Vector2i(frame * W, row * H))
		for frame in 2:
			_fawn(frame, Vector2i(W * 5 + frame * FAWN_W, row * H))
	im.save_png(OUT)
	var preview := Image.create_empty(im.get_width(), im.get_height(), false, Image.FORMAT_RGBA8)
	preview.fill(Color("5a9a3e"))
	preview.blend_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i.ZERO)
	preview.resize(im.get_width() * 4, im.get_height() * 4, Image.INTERPOLATE_NEAREST)
	preview.save_png("res://docs/deer_preview.png")
	print("Deer written to %s. Run godot --headless --path . --import next." % OUT)
	quit()


func px(o: Vector2i, x: int, y: int, color: Color, size := Vector2i(W, H)) -> void:
	if x >= 0 and y >= 0 and x < size.x and y < size.y:
		im.set_pixel(o.x + x, o.y + y, color)


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
				shade = base.lightened(0.16)
			elif lit < -0.55:
				shade = base.darkened(0.22)
			px(o, x, y, shade, size)


## A thick line from [param a] to [param b].
func line(o: Vector2i, a: Vector2, b: Vector2, color: Color, w := 1, size := Vector2i(W, H)) -> void:
	var n := maxi(int(a.distance_to(b) * 2.0), 1)
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		for j in w:
			px(o, int(p.x) + j, int(p.y), color, size)


## A slim leg: from the body at [param top] to a hoof at [param foot].
func leg(o: Vector2i, top: Vector2, foot: Vector2, color: Color, size := Vector2i(W, H)) -> void:
	line(o, top, foot, color, 2, size)
	px(o, int(foot.x), int(foot.y), HOOF, size)
	px(o, int(foot.x) + 1, int(foot.y), HOOF, size)


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


## Frames: 0 and 1 walking, 2 grazing, 3 head up looking at you, 4 bounding.
func _deer(look: Dictionary, frame: int, o: Vector2i) -> void:
	var coat := Color(look.coat)
	var legs := coat.darkened(0.12)
	var foot := H - 2
	var lift := 4 if frame == 4 else 0
	var body := Vector2(17.0, foot - 15.0 - lift)
	# legs: far pair darker, behind the body
	var s := 0 if frame >= 2 else (2 if frame == 0 else -2)
	if frame == 4:
		# all four hooves together under it, as a mule deer bounds (stotting)
		leg(o, Vector2(10, body.y + 3), Vector2(13, foot - lift), legs.darkened(0.2))
		leg(o, Vector2(24, body.y + 3), Vector2(21, foot - lift), legs.darkened(0.2))
	else:
		leg(o, Vector2(10, body.y + 3), Vector2(10 - s, foot), legs.darkened(0.2))
		leg(o, Vector2(24, body.y + 3), Vector2(24 + s, foot), legs.darkened(0.2))
	blob(o, body.x, body.y, 10.0, 5.2, coat)
	# the white rump patch, and the thin tail with its black tip
	blob(o, body.x - 8.5, body.y - 0.5, 2.2, 3.2, WHITE)
	px(o, int(body.x) - 11, int(body.y) - 2, WHITE)
	px(o, int(body.x) - 11, int(body.y) - 1, WHITE)
	px(o, int(body.x) - 11, int(body.y), EYE)
	# near legs
	if frame == 4:
		leg(o, Vector2(12, body.y + 3), Vector2(15, foot - lift), legs)
		leg(o, Vector2(25, body.y + 3), Vector2(23, foot - lift), legs)
	else:
		leg(o, Vector2(12, body.y + 3), Vector2(12 + s, foot), legs)
		leg(o, Vector2(25, body.y + 3), Vector2(25 - s, foot), legs)
	# neck and head
	var head := Vector2(31.0, foot - 26.0 - lift)
	match frame:
		2:
			head = Vector2(33.0, foot - 4.0)
		3:
			head = Vector2(30.0, foot - 28.0)
	var neck_base := Vector2(body.x + 7.0, body.y - 2.0)
	for i in 5:
		var t := i / 4.0
		blob(o, lerpf(neck_base.x, head.x - 1.5, t), lerpf(neck_base.y, head.y + 1.0, t), 2.6, 2.6, coat)
	if frame == 3:
		# looking round at you: a broad face, an ear out each side
		blob(o, head.x - 4.0, head.y - 3.0, 2.8, 1.6, coat)
		blob(o, head.x + 4.0, head.y - 3.0, 2.8, 1.6, coat)
		blob(o, head.x, head.y, 2.8, 3.2, coat)
		blob(o, head.x, head.y + 2.0, 1.8, 1.6, coat.lightened(0.12))
		blob(o, head.x, head.y + 4.6, 1.6, 1.0, WHITE)
	else:
		blob(o, head.x, head.y, 3.2, 2.5, coat)
		blob(o, head.x + 3.0, head.y + 0.8, 2.0, 1.6, coat.lightened(0.08))
		# the big ears, up and back
		blob(o, head.x - 2.6, head.y - 3.2, 1.6, 2.6, coat)
		if frame != 2:
			blob(o, head.x - 1.0 + (0.5 if frame == 1 else 0.0), head.y - 3.6, 1.4, 2.4, coat.darkened(0.1))
			blob(o, head.x - 0.5, head.y + 3.0, 1.4, 1.0, WHITE)
	if look.buck:
		_antlers(o, head, frame == 3)
	outline(o, Vector2i(W, H))
	# the face after the rim
	if frame == 3:
		px(o, int(head.x) - 2, int(head.y) - 1, EYE)
		px(o, int(head.x) + 1, int(head.y) - 1, EYE)
		px(o, int(head.x), int(head.y) + 2, NOSE)
		px(o, int(head.x) - 1, int(head.y) + 2, NOSE)
		px(o, int(head.x), int(head.y) - 2, coat.darkened(0.35))
	else:
		px(o, int(head.x), int(head.y) - 1, EYE)
		px(o, int(head.x) + 5, int(head.y) + 1, NOSE)
		px(o, int(head.x) + 1, int(head.y) - 2, coat.darkened(0.3))


## A buck's antlers: each beam forks, and the front tine forks again.
func _antlers(o: Vector2i, head: Vector2, facing_you: bool) -> void:
	var top := Vector2(head.x, head.y - 2.0)
	var sides := [-1, 1] if facing_you else [1]
	for side: int in sides:
		var beam := top + Vector2(side * 4.0 if facing_you else 2.0, -4.0)
		line(o, top, beam, ANTLER)
		var fork_a := beam + Vector2(side * 2.0 if facing_you else -2.0, -3.0)
		var fork_b := beam + Vector2(side * 3.0 if facing_you else 3.0, -2.0)
		line(o, beam, fork_a, ANTLER)
		line(o, beam, fork_b, ANTLER)
		line(o, fork_b, fork_b + Vector2(side if facing_you else 1.0, -2.0), ANTLER)
		line(o, fork_b, fork_b + Vector2(side * 2.0 if facing_you else 2.0, 0.0), ANTLER)


## A fawn: reddish, white-spotted, all legs and ears.
func _fawn(frame: int, o: Vector2i) -> void:
	var size := Vector2i(FAWN_W, H)
	var coat := Color("b0703e")
	var foot := H - 2
	var s := 1 if frame == 0 else -1
	var body := Vector2(10.0, foot - 10.0)
	leg(o, Vector2(6, body.y + 2), Vector2(6 - s, foot), coat.darkened(0.3), size)
	leg(o, Vector2(14, body.y + 2), Vector2(14 + s, foot), coat.darkened(0.3), size)
	blob(o, body.x, body.y, 6.0, 3.4, coat, size)
	leg(o, Vector2(7, body.y + 2), Vector2(7 + s, foot), coat.darkened(0.15), size)
	leg(o, Vector2(14, body.y + 2), Vector2(14 - s, foot), coat.darkened(0.15), size)
	var head := Vector2(18.5, body.y - 5.0)
	for i in 3:
		blob(o, lerpf(body.x + 4.0, head.x - 1.0, i / 2.0), lerpf(body.y - 1.0, head.y + 1.0, i / 2.0), 1.8, 1.8, coat, size)
	blob(o, head.x, head.y, 2.4, 2.0, coat, size)
	blob(o, head.x - 2.0, head.y - 2.6, 1.2, 2.0, coat, size)
	outline(o, size)
	for spot: Vector2i in [Vector2i(6, -1), Vector2i(9, -2), Vector2i(12, -1), Vector2i(8, 1), Vector2i(11, 1), Vector2i(14, -1)]:
		px(o, spot.x, int(body.y) + spot.y, WHITE, size)
	px(o, int(head.x), int(head.y) - 1, EYE, size)
	px(o, int(head.x) + 2, int(head.y), NOSE, size)
