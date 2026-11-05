extends SceneTree
## Paints the wildlife added after the first birds and big animals into
## assets/sprites/wildlife.png: the squirrels and the two new ground birds
## of scripts/world/critters.gd, the peregrine falcon (Falcons), the great
## gray owl (Owls), the bobcat (Bobcats), and the pictures the Wildlife
## journal uses for the birds you only hear. They are painted at the 32px
## art's size, in the bears' style (shaded, lit from the upper left, with
## the dark rim every sprite has), so they skip tools/art32.
##
##   godot --headless --path . -s res://tools/npcgen/wildlife_art.gd
##   godot --headless --path . --import
##
## Every cell is 40x32 with the animal's feet on row 30 (WildlifeSheet has
## the rows and frames). Everything faces right.

const Sheet := preload("res://scripts/world/wildlife_sheet.gd")
const W := 40
const H := 32
const FOOT := 30
const OUT := "res://assets/sprites/wildlife.png"
const OUTLINE := Color("1e1612")
const EYE := Color("0c0a08")
const NOSE := Color("2a1a18")
const GLINT := Color("fbf6ea")

## Squirrels: coat, belly, tail, tail fringe, legs, and markings.
const SQUIRRELS := {
	"western_gray_squirrel": {"coat": "8a8c92", "belly": "eeeae2", "tail": "8e9096", "fringe": "e4e2de", "legs": "6a6c72", "bushy": 3.3, "size": 1.0},
	"california_ground_squirrel": {"coat": "8e7458", "belly": "c8b494", "tail": "7e6650", "fringe": "b8a688", "legs": "6a5440", "bushy": 2.1, "size": 0.95, "mottle": "c4ac88", "mantle": "aaa69e"},
	"douglas_squirrel": {"coat": "6e5e48", "belly": "e0a050", "tail": "4e4234", "fringe": "c8b090", "legs": "54473a", "bushy": 2.6, "size": 0.82, "side": "2a2420"},
	"golden_mantled_ground_squirrel": {"coat": "8a7a64", "belly": "d8c8a8", "tail": "7a6a56", "fringe": "b8a890", "legs": "64584a", "bushy": 1.9, "size": 0.8, "head": "c4883e", "stripes": true},
}
## The two new birds, in the critters' frames (standing, pecking, wings up,
## wings down), painted at twice their size.
const BIRDS := {
	"acorn_woodpecker": {"body": "1e1c22", "head": "1e1c22", "breast": "eeeae0", "wing": "18161c", "tail": "18161c", "beak": "3a3a40",
		"cap": "d02a28", "face": "f2eed8", "throat": "e8d888", "size": [6.4, 4.2], "patch": "f4f2ea"},
	"clarks_nutcracker": {"body": "8e9094", "head": "9a9ca0", "breast": "a4a6aa", "wing": "1c1c22", "tail": "2a2a30", "tail_edge": "f0f0ec", "beak": "1a1a1a",
		"face": "e0e0dc", "size": [7.2, 4.6], "patch": "f0f0ec", "long_beak": true},
}

var im: Image


func _init() -> void:
	im = Image.create_empty(W * Sheet.COLUMNS, H * Sheet.ROWS.size(), false, Image.FORMAT_RGBA8)
	for id: String in SQUIRRELS:
		for frame in 4:
			_squirrel(SQUIRRELS[id], frame, _cell(id, frame))
	for id: String in BIRDS:
		for frame in 4:
			_bird(BIRDS[id], frame, _cell(id, frame))
	for frame in 5:
		_falcon(frame, _cell("peregrine_falcon", frame))
	for frame in 5:
		_owl(frame, _cell("great_gray_owl", frame))
	for frame in 7:
		_bobcat(frame, _cell("bobcat", frame))
	_chickadee(_cell("mountain_chickadee", 0))
	_horned_owl(_cell("great_horned_owl", 0))
	_fish(_cell("rainbow_trout", 0), {"back": "5e6e44", "side": "b8bca0", "stripe": "d8788a", "belly": "e6e8e2", "spots": true})
	_fish(_cell("sacramento_sucker", 0), {"back": "5a5038", "side": "8a7c58", "belly": "d8d0b0", "sucker": true})
	im.save_png(OUT)
	var preview := Image.create_empty(im.get_width(), im.get_height(), false, Image.FORMAT_RGBA8)
	preview.fill(Color("5a9a3e"))
	preview.blend_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i.ZERO)
	preview.resize(im.get_width() * 4, im.get_height() * 4, Image.INTERPOLATE_NEAREST)
	preview.save_png("res://docs/wildlife_preview.png")
	print("Wildlife written to %s. Run godot --headless --path . --import next." % OUT)
	quit()


func _cell(id: String, frame: int) -> Vector2i:
	return Vector2i(frame * W, Sheet.row(id) * H)


func px(o: Vector2i, x: int, y: int, color: Color) -> void:
	if x >= 0 and y >= 0 and x < W and y < H:
		im.set_pixel(o.x + x, o.y + y, color)


## A blob lit from the upper left.
func blob(o: Vector2i, cx: float, cy: float, rx: float, ry: float, base: Color) -> void:
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
			px(o, x, y, shade)


## A filled polygon, a little lighter along its top.
func poly(o: Vector2i, points: PackedVector2Array, base: Color) -> void:
	var box := Rect2(points[0], Vector2.ZERO)
	for p in points:
		box = box.expand(p)
	for y in range(floori(box.position.y), ceili(box.end.y) + 1):
		for x in range(floori(box.position.x), ceili(box.end.x) + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), points):
				var t := (y + 0.5 - box.position.y) / maxf(box.size.y, 1.0)
				px(o, x, y, base.lightened(0.1) if t < 0.3 else (base.darkened(0.15) if t > 0.75 else base))


## A one pixel line from [param a] to [param b].
func line(o: Vector2i, a: Vector2, b: Vector2, color: Color) -> void:
	var steps := int(maxf(absf(b.x - a.x), absf(b.y - a.y))) + 1
	for i in steps + 1:
		var p := a.lerp(b, float(i) / steps)
		px(o, int(p.x), int(p.y), color)


## A leg from [param top] down to [param foot_y], [param w] wide.
func leg(o: Vector2i, x: int, top: int, foot_y: int, w: int, color: Color) -> void:
	for y in range(top, foot_y + 1):
		for i in w:
			px(o, x + i, y, color if i > 0 else color.lightened(0.08))
	for i in w:
		px(o, x + i, foot_y, color.darkened(0.2))


func outline(o: Vector2i) -> void:
	var edge: Array[Vector2i] = []
	for y in H:
		for x in W:
			if im.get_pixel(o.x + x, o.y + y).a > 0.5:
				continue
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n := Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < W and n.y < H and im.get_pixel(o.x + n.x, o.y + n.y).a > 0.5:
					edge.append(Vector2i(x, y))
					break
	for p in edge:
		im.set_pixel(o.x + p.x, o.y + p.y, OUTLINE)


## A bushy tail as a chain of blobs from [param a] through [param mid] to
## [param b], [param r] thick, with a pale fringe.
func tail(o: Vector2i, a: Vector2, mid: Vector2, b: Vector2, r: float, look: Dictionary) -> void:
	for i in 9:
		var t := i / 8.0
		var p := a.lerp(mid, t).lerp(mid.lerp(b, t), t)
		blob(o, p.x, p.y, r + 0.6, r + 0.6, Color(look.fringe))
	for i in 9:
		var t := i / 8.0
		var p := a.lerp(mid, t).lerp(mid.lerp(b, t), t)
		blob(o, p.x, p.y, r * 0.8, r * 0.8, Color(look.tail))


# ------------------------------------------------------------- squirrels

## Frame 0 sitting up nibbling, 1 sitting up on the alert, 2 and 3 bounding.
func _squirrel(look: Dictionary, frame: int, o: Vector2i) -> void:
	var s: float = look.size
	var coat := Color(look.coat)
	var legs := Color(look.legs)
	var belly := Color(look.belly)
	var bushy: float = look.bushy
	var cx := 20.0
	var head: Vector2
	var face_right := true
	if frame <= 1:
		# the tail curls up behind, the body sits upright on its haunches
		var up := 1.0 if frame == 1 else 0.0
		tail(o, Vector2(cx - 4 * s, FOOT - 3), Vector2(cx - 6 * s - bushy * 0.5, FOOT - 10 * s), Vector2(cx - 9 * s - bushy * 0.5, FOOT - 17 * s - up * 2), bushy * s, look)
		blob(o, cx - 1 * s, FOOT - 4 * s, 5.0 * s, 4.6 * s, coat)
		blob(o, cx + 1.5 * s, FOOT - 9.5 * s - up, 4.0 * s, 5.6 * s, coat)
		blob(o, cx + 2.6 * s, FOOT - 8.5 * s - up, 1.8 * s, 3.8 * s, belly)
		head = Vector2(cx + 3.0 * s, FOOT - 16.0 * s - up)
		blob(o, head.x, head.y, 3.4 * s, 3.0 * s, Color(look.get("head", look.coat)))
		blob(o, head.x - 1.2 * s, head.y - 3.0 * s, 1.1, 1.3, Color(look.get("head", look.coat)).darkened(0.1))
		# the hind foot flat on the ground, and the paws
		for x in range(int(cx - 1 * s), int(cx + 4 * s)):
			px(o, x, FOOT, legs)
		if frame == 0:
			blob(o, head.x + 2.2 * s, head.y + 3.2 * s, 1.4, 1.3, legs)
		else:
			blob(o, cx + 3.4 * s, FOOT - 9.0 * s, 1.1, 1.6, legs)
	else:
		var bunched := frame == 3
		var body_y := FOOT - (5.5 if bunched else 4.5) * s
		if bunched:
			tail(o, Vector2(cx - 5 * s, body_y - 1), Vector2(cx - 11 * s, body_y - 4 * s), Vector2(cx - 9 * s, body_y - 11 * s), bushy * s, look)
		else:
			tail(o, Vector2(cx - 6 * s, body_y), Vector2(cx - 12 * s, body_y - 2 * s), Vector2(cx - 17 * s, body_y - 5 * s), bushy * s, look)
		var reach := 1.0 if bunched else 3.0
		leg(o, int(cx - (2 if bunched else 7) * s), int(body_y), FOOT, 2, legs.darkened(0.15))
		leg(o, int(cx + (2 if bunched else 6) * s), int(body_y), FOOT, 2, legs.darkened(0.15))
		blob(o, cx, body_y, (5.0 if bunched else 7.0) * s, (3.6 if bunched else 3.0) * s, coat)
		blob(o, cx + 1, body_y + 1.6 * s, (3.4 if bunched else 5.0) * s, 1.2 * s, belly)
		leg(o, int(cx - (1 if bunched else 6) * s), int(body_y + 1), FOOT, 2, legs)
		leg(o, int(cx + (reach + 2) * s), int(body_y + 1), FOOT, 2, legs)
		head = Vector2(cx + (6.5 if bunched else 8.5) * s, body_y - 2.0 * s)
		blob(o, head.x, head.y, 3.2 * s, 2.7 * s, Color(look.get("head", look.coat)))
		blob(o, head.x - 1.4 * s, head.y - 2.6 * s, 1.0, 1.2, Color(look.get("head", look.coat)).darkened(0.1))
	if look.has("mottle"):
		# a ground squirrel's speckled back and silvery shoulders
		var rng := RandomNumberGenerator.new()
		rng.seed = 7 + frame
		for i in 22:
			var p := Vector2(rng.randf_range(cx - 6 * s, cx + 4 * s), rng.randf_range(FOOT - 14 * s, FOOT - 2))
			if im.get_pixel(o.x + int(p.x), o.y + int(p.y)) .is_equal_approx(coat) or im.get_pixel(o.x + int(p.x), o.y + int(p.y)).is_equal_approx(coat.lightened(0.07)):
				px(o, int(p.x), int(p.y), Color(look.mottle))
		blob(o, head.x - 2.5 * s, head.y + 2.5 * s, 1.6, 1.4, Color(look.mantle))
	outline(o)
	# the face, and markings over the rim
	px(o, int(head.x) + 1, int(head.y) - 1, EYE)
	px(o, int(head.x) + 1, int(head.y) - 2, GLINT if face_right else EYE)
	px(o, int(head.x + 3.2 * look.size), int(head.y), NOSE)
	if look.has("side"):
		# a Douglas squirrel's black line between back and orange belly
		if frame <= 1:
			line(o, Vector2(cx - 0.5, FOOT - 13 * look.size), Vector2(cx - 1, FOOT - 4), Color(look.side))
		else:
			line(o, Vector2(cx - 4 * look.size, FOOT - 4.5 * look.size), Vector2(cx + 4 * look.size, FOOT - 4.5 * look.size), Color(look.side))
	if look.get("stripes", false):
		# golden-mantled: a white stripe edged in black down each side
		var a := Vector2(cx + 1, FOOT - 13 * look.size) if frame <= 1 else Vector2(cx - 4 * look.size, FOOT - 6.5 * look.size)
		var b := Vector2(cx - 2, FOOT - 3) if frame <= 1 else Vector2(cx + 4 * look.size, FOOT - 6.5 * look.size)
		var across := Vector2(1, 0) if frame <= 1 else Vector2(0, 1)
		line(o, a - across, b - across, Color("1e1a16"))
		line(o, a, b, Color("f0ece0"))
		line(o, a + across, b + across, Color("1e1a16"))
	if frame == 0:
		px(o, int(head.x + 2.6 * look.size), int(head.y + 3.0 * look.size), Color("7a5430")) # an acorn


# ------------------------------------------------------------- birds

## The critters' bird at twice the size: 0 standing, 1 pecking, 2 wings up,
## 3 wings down.
func _bird(look: Dictionary, frame: int, o: Vector2i) -> void:
	var size: Array = look.size
	var rx: float = size[0]
	var ry: float = size[1]
	var flying := frame >= 2
	var body_y := 24.0 if not flying else 21.0
	var cx := 19.0
	# tail, angled up behind
	poly(o, PackedVector2Array([Vector2(cx - 3, body_y - 2), Vector2(cx - 12, body_y - 6), Vector2(cx - 12, body_y - 3), Vector2(cx - 3, body_y + 2)]), Color(look.tail))
	if look.has("tail_edge"):
		line(o, Vector2(cx - 12, body_y - 3), Vector2(cx - 4, body_y + 1), Color(look.tail_edge))
	blob(o, cx, body_y, rx, ry, Color(look.body))
	blob(o, cx + 1.6, body_y + 1.6, rx * 0.6, ry * 0.6, Color(look.breast))
	var head := Vector2(cx + 5.0, body_y - 5.0) if frame != 1 else Vector2(cx + 6.0, body_y + 1.0)
	blob(o, head.x, head.y, 3.8, 3.6, Color(look.head))
	if look.has("face"):
		blob(o, head.x + 1.2, head.y + 0.6, 2.2, 1.8, Color(look.face))
	if look.has("cap"):
		blob(o, head.x - 0.4, head.y - 2.4, 2.6, 1.5, Color(look.cap))
	if look.has("throat"):
		px(o, int(head.x) + 1, int(head.y) + 3, Color(look.throat))
		px(o, int(head.x) + 2, int(head.y) + 3, Color(look.throat))
	# the wing: folded on the side, or beating
	var wing := Color(look.wing)
	match frame:
		0, 1:
			blob(o, cx - 1.5, body_y - 0.8, rx * 0.7, ry * 0.55, wing)
			if look.has("patch"):
				px(o, int(cx) - 4, int(body_y) - 1, Color(look.patch))
				px(o, int(cx) - 3, int(body_y) - 1, Color(look.patch))
		2:
			poly(o, PackedVector2Array([Vector2(cx - 4, body_y - 1), Vector2(cx - 3, body_y - 11), Vector2(cx + 2, body_y - 9), Vector2(cx + 2, body_y - 1)]), wing)
			if look.has("patch"):
				blob(o, cx - 0.5, body_y - 7, 1.2, 1.2, Color(look.patch))
		3:
			poly(o, PackedVector2Array([Vector2(cx - 4, body_y), Vector2(cx - 3, body_y + 8), Vector2(cx + 2, body_y + 7), Vector2(cx + 2, body_y)]), wing.darkened(0.1))
			if look.has("patch"):
				blob(o, cx - 0.5, body_y + 4, 1.2, 1.2, Color(look.patch))
	outline(o)
	# the eye, the beak, and the legs go on after the rim
	px(o, int(head.x) + 1, int(head.y) - 1, EYE)
	if look.has("cap"):
		px(o, int(head.x) + 1, int(head.y) - 1, Color("f4f0d8")) # a woodpecker's pale eye
		px(o, int(head.x) + 2, int(head.y) - 1, EYE)
	var beak_len := 4 if look.get("long_beak", false) else 3
	for i in beak_len:
		px(o, int(head.x) + 4 + i, int(head.y) + (i / 2 if frame == 1 else 0), Color(look.beak))
		if i < beak_len - 1:
			px(o, int(head.x) + 4 + i, int(head.y) + 1 + (i / 2 if frame == 1 else 0), Color(look.beak).lightened(0.2))
	if not flying:
		for y in range(int(body_y + ry), FOOT + 1):
			px(o, int(cx) - 1, y, Color("3a3030"))
			px(o, int(cx) + 2, y, Color("3a3030"))


# ------------------------------------------------------------- peregrine falcon

## Seen from above as it flies (the overworld looks down on it): 0 gliding,
## wings swept, 1 wings up on the beat, 2 stooping with wings folded, 3 wings
## down on the beat; 4 perched, from the side.
func _falcon(frame: int, o: Vector2i) -> void:
	var back := Color("5a6878")
	var wing := Color("4c5868")
	var tips := Color("2a3038")
	var helmet := Color("22262e")
	var cy := 16.0
	match frame:
		0, 1, 3:
			var span: float = [14.0, 9.0, 0.0, 12.0][frame]
			var sweep: float = [9.0, 4.0, 0.0, 6.0][frame]
			for side in [-1.0, 1.0]:
				var tip := Vector2(21 - sweep, cy + side * span)
				poly(o, PackedVector2Array([Vector2(24, cy + side * 1), Vector2(22.5, cy + side * span * 0.55), tip, Vector2(tip.x - 1.5, tip.y - side * 1), Vector2(18, cy + side * span * 0.45), Vector2(17, cy + side * 1)]), wing)
				line(o, tip, tip.lerp(Vector2(22.5, cy + side * span * 0.55), 0.45), tips)
			poly(o, PackedVector2Array([Vector2(14, cy - 1.5), Vector2(6, cy - 3.0), Vector2(6, cy + 3.0), Vector2(14, cy + 1.5)]), back.darkened(0.1))
			blob(o, 19.5, cy, 6.5, 2.6, back)
			blob(o, 26.5, cy, 2.6, 2.3, helmet)
			outline(o)
			px(o, 29, int(cy), Color("e8c040"))
			px(o, 27, int(cy) - 1, Color("e8c040"))
			for x in [8, 10, 12]:
				px(o, x, int(cy), tips) # bars on the tail
		2:
			# a teardrop: wings folded tight along the body
			poly(o, PackedVector2Array([Vector2(25, cy - 1.5), Vector2(11, cy - 4), Vector2(8, cy - 3), Vector2(23, cy + 0.5)]), wing)
			poly(o, PackedVector2Array([Vector2(25, cy + 1.5), Vector2(11, cy + 4), Vector2(8, cy + 3), Vector2(23, cy - 0.5)]), wing.darkened(0.1))
			poly(o, PackedVector2Array([Vector2(13, cy - 1), Vector2(7, cy - 1.5), Vector2(7, cy + 1.5), Vector2(13, cy + 1)]), back.darkened(0.15))
			blob(o, 19.0, cy, 7.0, 2.3, back)
			blob(o, 27.0, cy, 2.4, 2.1, helmet)
			outline(o)
			px(o, 29, int(cy), Color("e8c040"))
		4:
			# perched upright: slate back, pale barred breast, dark helmet
			# and the black "mustache" under the eye
			poly(o, PackedVector2Array([Vector2(17, 22), Vector2(15, FOOT), Vector2(19, FOOT), Vector2(21, 22)]), back.darkened(0.2))
			blob(o, 19.0, 21.0, 5.0, 7.5, back)
			blob(o, 21.0, 22.0, 3.0, 6.0, Color("e8e2d4"))
			blob(o, 20.0, 12.0, 3.6, 3.4, helmet)
			blob(o, 21.6, 13.4, 1.6, 1.6, Color("f0ece4"))
			outline(o)
			for y in range(18, 28, 2):
				px(o, 21, y, Color("8a8a90"))
				px(o, 22, y + 1, Color("8a8a90"))
			px(o, 21, 11, Color("e8c040"))
			px(o, 22, 11, EYE)
			px(o, 21, 13, helmet)
			px(o, 21, 14, helmet)
			px(o, 24, 12, Color("e8c040"))
			px(o, 24, 13, Color("2a2a2a"))
			px(o, 19, FOOT, Color("e8c040"))
			px(o, 21, FOOT, Color("e8c040"))


# ------------------------------------------------------------- great gray owl

## 0 sitting in the grass, its great round face to you; 1 the face turned to
## listen; 2 wings up and 3 wings down, from above as it glides low; 4 the
## plunge, wings up and talons down into the grass.
func _owl(frame: int, o: Vector2i) -> void:
	var gray := Color("8a8a86")
	var dark := Color("5e5e5a")
	var disk := Color("b4b4ae")
	var rng := RandomNumberGenerator.new()
	rng.seed = 31 + frame
	match frame:
		0, 1, 4:
			if frame == 4:
				for side in [-1.0, 1.0]:
					poly(o, PackedVector2Array([Vector2(20 + side * 3, 14), Vector2(20 + side * 17, 4), Vector2(20 + side * 18, 9), Vector2(20 + side * 13, 18), Vector2(20 + side * 4, 22)]), gray)
			blob(o, 20.0, 22.0, 6.8, 8.0, gray)
			var face := Vector2(20.0 if frame != 1 else 21.0, 13.0 if frame != 4 else 15.0)
			blob(o, face.x, face.y, 6.6, 5.8, gray.darkened(0.05))
			blob(o, face.x, face.y + 0.4, 5.6, 4.8, disk)
			# streaks down the breast and mottling on the wings
			for i in 26:
				var p := Vector2(rng.randf_range(14, 26), rng.randf_range(19, 29))
				if im.get_pixel(o.x + int(p.x), o.y + int(p.y)).a > 0.5:
					px(o, int(p.x), int(p.y), dark if i % 3 else Color("c8c8c2"))
			if frame == 4:
				# talons reaching down into the grass
				line(o, Vector2(18, 28), Vector2(17, FOOT), Color("3a3430"))
				line(o, Vector2(22, 28), Vector2(23, FOOT), Color("3a3430"))
			outline(o)
			# rings round the face, little yellow eyes, the white "bow tie"
			for a in range(0, 360, 20):
				var r := Vector2(cos(deg_to_rad(a)) * 3.6, sin(deg_to_rad(a)) * 3.0)
				px(o, int(face.x + r.x), int(face.y + 0.4 + r.y), Color("8e8e88"))
			if frame == 1:
				px(o, int(face.x) + 1, int(face.y) - 1, Color("e8d040"))
				px(o, int(face.x) + 2, int(face.y) - 1, EYE)
				px(o, int(face.x) + 4, int(face.y) + 1, Color("e8d888"))
			else:
				for side in [-1, 1]:
					px(o, int(face.x) + side * 2, int(face.y) - 1, Color("e8d040"))
					px(o, int(face.x) + side * 2 + (0 if side < 0 else -1) + (1 if side < 0 else 0), int(face.y) - 1, Color("e8d040"))
					px(o, int(face.x) + side * 2, int(face.y), EYE)
				px(o, int(face.x), int(face.y) + 1, Color("e8d888"))
				px(o, int(face.x), int(face.y) + 2, Color("e8d888"))
			var tie := int(face.y) + 6
			for x in [-3, -2, 2, 3]:
				px(o, int(face.x) + x, tie, Color("f4f4f0"))
			px(o, int(face.x), tie, Color("1e1e1e"))
		2, 3:
			var span := 13.0 if frame == 2 else 11.0
			for side in [-1.0, 1.0]:
				poly(o, PackedVector2Array([Vector2(24, 16 + side * 1), Vector2(24, 16 + side * span * 0.7), Vector2(21, 16 + side * span),
					Vector2(16, 16 + side * span), Vector2(14, 16 + side * span * 0.6), Vector2(15, 16 + side * 1)]), gray)
				for f in 3:
					px(o, 16 + f * 2, int(16 + side * (span - 0.5)), dark) # fingered tips
			poly(o, PackedVector2Array([Vector2(14, 14), Vector2(8, 13), Vector2(8, 19), Vector2(14, 18)]), gray.darkened(0.1))
			blob(o, 19.0, 16.0, 6.0, 3.6, gray)
			blob(o, 26.0, 16.0, 3.8, 3.8, gray.darkened(0.05))
			for i in 24:
				var p := Vector2(rng.randf_range(10, 28), rng.randf_range(4, 28))
				if im.get_pixel(o.x + int(p.x), o.y + int(p.y)).a > 0.5:
					px(o, int(p.x), int(p.y), dark if i % 2 else Color("b0b0aa"))
			outline(o)


# ------------------------------------------------------------- bobcat

## 0 and 2 walking, 1 the legs passing, 3 crouched and stalking, 4 frozen,
## looking straight at you, 5 the pounce, 6 sitting.
func _bobcat(frame: int, o: Vector2i) -> void:
	var coat := Color("b08a5c")
	var legs := Color("94724c")
	var belly := Color("e6d8c0")
	var spot := Color("5a3e28")
	var head := Vector2(31.0, 15.0)
	var front := true
	match frame:
		0, 1, 2:
			var stride: int = [2, 0, -2][frame]
			leg(o, 10 - stride, 20, FOOT, 2, legs.darkened(0.2))
			leg(o, 25 + stride, 20, FOOT, 2, legs.darkened(0.2))
			_bob_tail(o, Vector2(8, 17))
			blob(o, 12.0, 19.5, 4.6, 4.4, coat)
			blob(o, 19.0, 20.0, 8.0, 3.8, coat)
			blob(o, 25.5, 19.5, 4.0, 4.6, coat)
			blob(o, 19.0, 23.0, 6.0, 1.4, belly)
			leg(o, 12 + stride, 21, FOOT, 2, legs)
			leg(o, 26 - stride, 21, FOOT, 2, legs)
			head = Vector2(31.0, 15.0 + (1.0 if frame == 1 else 0.0))
		3:
			# low to the ground, shoulders up, head out, every step slow
			leg(o, 9, 24, FOOT, 2, legs.darkened(0.2))
			leg(o, 26, 23, FOOT, 2, legs.darkened(0.2))
			_bob_tail(o, Vector2(7, 22))
			blob(o, 11.0, 24.0, 4.6, 4.0, coat)
			blob(o, 18.5, 25.0, 8.0, 3.2, coat)
			blob(o, 25.0, 22.5, 4.0, 4.0, coat)
			blob(o, 18.5, 27.0, 6.0, 1.0, belly)
			leg(o, 13, 26, FOOT, 2, legs)
			leg(o, 28, 24, FOOT, 2, legs)
			head = Vector2(32.0, 21.0)
		4:
			leg(o, 10, 20, FOOT, 2, legs.darkened(0.2))
			leg(o, 25, 20, FOOT, 2, legs.darkened(0.2))
			_bob_tail(o, Vector2(8, 17))
			blob(o, 12.0, 19.5, 4.6, 4.4, coat)
			blob(o, 19.0, 20.0, 8.0, 3.8, coat)
			blob(o, 25.5, 19.5, 4.0, 4.6, coat)
			blob(o, 19.0, 23.0, 6.0, 1.4, belly)
			leg(o, 12, 21, FOOT, 2, legs)
			leg(o, 26, 21, FOOT, 2, legs)
			head = Vector2(30.0, 14.0)
			front = false
		5:
			# springing: stretched out in the air, forepaws reaching
			_bob_tail(o, Vector2(8, 22))
			line(o, Vector2(9, 24), Vector2(3, 28), legs.darkened(0.1))
			line(o, Vector2(10, 24), Vector2(4, 28), legs.darkened(0.1))
			blob(o, 12.0, 22.0, 4.6, 4.0, coat)
			blob(o, 19.0, 19.0, 8.0, 3.8, coat)
			blob(o, 25.0, 16.5, 4.0, 4.0, coat)
			blob(o, 19.0, 21.5, 6.0, 1.2, belly)
			line(o, Vector2(27, 19), Vector2(34, 21), legs)
			line(o, Vector2(27, 20), Vector2(34, 22), legs)
			head = Vector2(31.0, 13.0)
		6:
			# sitting up, tail round its feet
			_bob_tail(o, Vector2(13, 28))
			blob(o, 18.0, 25.0, 6.0, 5.0, coat)
			blob(o, 22.5, 19.0, 4.2, 6.0, coat)
			blob(o, 24.0, 21.0, 2.2, 4.0, belly)
			leg(o, 23, 22, FOOT, 2, legs)
			leg(o, 26, 22, FOOT, 2, legs.darkened(0.1))
			head = Vector2(25.5, 11.0)
	# spots along the flanks
	var rng := RandomNumberGenerator.new()
	rng.seed = 51
	for i in 26:
		var p := Vector2(rng.randf_range(7, 30), rng.randf_range(14, 28))
		var c := im.get_pixel(o.x + int(p.x), o.y + int(p.y))
		if c.a > 0.5 and (c.is_equal_approx(coat) or c.is_equal_approx(coat.lightened(0.07)) or c.is_equal_approx(coat.darkened(0.25))):
			px(o, int(p.x), int(p.y), spot)
	# the head: a round face with a ruff of cheek fur and tufted ears
	blob(o, head.x, head.y, 4.0, 3.6, coat)
	if front:
		blob(o, head.x - 1.6, head.y - 3.8, 1.4, 2.0, coat.darkened(0.1))
		blob(o, head.x + 0.8, head.y - 3.8, 1.3, 1.8, coat)
		blob(o, head.x + 3.0, head.y + 1.2, 2.0, 1.5, belly)
		blob(o, head.x - 2.2, head.y + 2.4, 1.6, 1.4, belly)
	else:
		blob(o, head.x - 2.6, head.y - 3.6, 1.4, 2.0, coat)
		blob(o, head.x + 2.6, head.y - 3.6, 1.4, 2.0, coat)
		blob(o, head.x, head.y + 1.6, 2.4, 1.6, belly)
		blob(o, head.x - 3.6, head.y + 2.0, 1.4, 1.6, belly)
		blob(o, head.x + 3.6, head.y + 2.0, 1.4, 1.6, belly)
	outline(o)
	# ear tufts, eyes and nose over the rim
	if front:
		px(o, int(head.x) - 2, int(head.y) - 6, OUTLINE)
		px(o, int(head.x) + 1, int(head.y) - 6, OUTLINE)
		px(o, int(head.x) + 1, int(head.y) - 1, Color("c8c040"))
		px(o, int(head.x) + 2, int(head.y) - 1, EYE)
		px(o, int(head.x) + 4, int(head.y), NOSE)
		px(o, int(head.x) - 1, int(head.y), spot)
	else:
		px(o, int(head.x) - 3, int(head.y) - 6, OUTLINE)
		px(o, int(head.x) + 3, int(head.y) - 6, OUTLINE)
		for side in [-1, 1]:
			px(o, int(head.x) + side * 2 - (1 if side > 0 else 0), int(head.y) - 1, Color("c8c040"))
		px(o, int(head.x) - 2, int(head.y) - 1, EYE)
		px(o, int(head.x) + 1, int(head.y) - 1, EYE)
		px(o, int(head.x), int(head.y) + 1, NOSE)
		px(o, int(head.x) - 1, int(head.y) + 1, NOSE)


## A bobcat's short tail, black on top at the tip, white under it.
func _bob_tail(o: Vector2i, at: Vector2) -> void:
	blob(o, at.x, at.y, 2.6, 1.6, Color("a07e54"))
	px(o, int(at.x) - 2, int(at.y) - 1, Color("1e1612"))
	px(o, int(at.x) - 1, int(at.y) - 1, Color("1e1612"))
	px(o, int(at.x) - 1, int(at.y) + 1, Color("f0ece0"))


# ------------------------------------------------------------- heard, not seen

## The Wildlife journal's pictures for the birds you only hear.
func _chickadee(o: Vector2i) -> void:
	poly(o, PackedVector2Array([Vector2(16, 22), Vector2(9, 26), Vector2(10, 28), Vector2(17, 25)]), Color("6e7074"))
	blob(o, 19.0, 23.0, 5.4, 4.0, Color("8a8c90"))
	blob(o, 20.5, 25.0, 3.6, 2.4, Color("e4e0d4"))
	blob(o, 23.0, 18.0, 3.4, 3.2, Color("1c1c20"))
	blob(o, 23.6, 18.6, 2.0, 1.4, Color("f2f0ea"))
	blob(o, 17.5, 22.5, 3.4, 2.0, Color("6a6c70"))
	outline(o)
	px(o, 22, 16, Color("f2f0ea")) # the white eyebrow
	px(o, 23, 16, Color("f2f0ea"))
	px(o, 24, 17, EYE)
	px(o, 27, 18, Color("2a2a2a"))
	for y in range(27, FOOT + 1):
		px(o, 18, y, Color("3a3030"))
		px(o, 21, y, Color("3a3030"))


func _horned_owl(o: Vector2i) -> void:
	var brown := Color("7a5e40")
	blob(o, 20.0, 21.0, 6.4, 8.6, brown)
	blob(o, 20.0, 23.0, 4.2, 6.0, Color("b89a70"))
	blob(o, 20.0, 12.0, 5.6, 4.6, brown)
	blob(o, 20.0, 12.6, 4.2, 3.4, Color("c88a4a"))
	blob(o, 16.4, 7.0, 1.2, 2.2, brown) # the "horns", tufts of feathers
	blob(o, 23.6, 7.0, 1.2, 2.2, brown)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 30:
		var p := Vector2(rng.randf_range(14, 26), rng.randf_range(18, 29))
		if im.get_pixel(o.x + int(p.x), o.y + int(p.y)).a > 0.5:
			px(o, int(p.x), int(p.y), Color("4a3826"))
	outline(o)
	for side in [-1, 1]:
		px(o, 20 + side * 2, 12, Color("f0b030"))
		px(o, 20 + side * 2 - (1 if side > 0 else 0) + (1 if side < 0 else 0), 12, Color("f0b030"))
		px(o, 20 + side * 2, 12, EYE)
	px(o, 20, 14, Color("3a3430"))
	for x in range(17, 24):
		px(o, x, 17, Color("f0ece0")) # the white throat


## A fish from the side, for the Wildlife journal: a rainbow trout with its
## rosy stripe and black spots, or a sucker with its soft, downturned mouth.
func _fish(o: Vector2i, look: Dictionary) -> void:
	var cy := 18.0
	# the tail fin, and the fins on the back and belly
	poly(o, PackedVector2Array([Vector2(8, cy), Vector2(2, cy - 5), Vector2(4, cy), Vector2(2, cy + 5)]), Color(look.back))
	poly(o, PackedVector2Array([Vector2(17, cy - 3), Vector2(20, cy - 7), Vector2(23, cy - 3)]), Color(look.back))
	poly(o, PackedVector2Array([Vector2(13, cy + 2), Vector2(15, cy + 6), Vector2(18, cy + 2)]), Color(look.side))
	blob(o, 19.0, cy, 13.0, 4.2, Color(look.side))
	blob(o, 19.0, cy - 1.8, 12.0, 2.0, Color(look.back))
	blob(o, 20.0, cy + 2.2, 10.0, 1.6, Color(look.belly))
	outline(o)
	if look.has("stripe"):
		line(o, Vector2(9, cy), Vector2(29, cy + 0.5), Color(look.stripe))
	if look.get("spots", false):
		for p: Vector2i in [Vector2i(5, 15), Vector2i(10, 16), Vector2i(14, 15), Vector2i(18, 15), Vector2i(22, 16), Vector2i(12, 20), Vector2i(3, 18), Vector2i(26, 15)]:
			px(o, p.x, p.y, Color("1e1a16"))
	px(o, 28, int(cy) - 1, EYE)
	if look.get("sucker", false):
		px(o, 31, int(cy) + 2, Color("c8a888"))
		px(o, 30, int(cy) + 3, Color("c8a888"))
