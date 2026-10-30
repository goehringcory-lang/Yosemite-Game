extends SceneTree
## Draws the placeholder pixel art for every person in the game: one 208×96
## sheet per character, in the same layout as assets/sprites/player.png
## (16×24 frames; rows down / up / left / right, and a column per pose in
## COLUMNS: stand, the two walking steps, a blink, two running strides,
## crouching, arms up, reaching out, carrying someone on your back (standing
## and two steps) and talking). The first three columns are the original
## stand / step A / step B, so a sheet cut down to them still works. Also draws the player sheet (assets/sprites/player.png), the icons
## for story items (assets/sprites/story_items.png) and a preview lineup of the
## whole cast (docs/cast_lineup.png).
##
##   godot --headless --path . -s res://tools/npcgen/npcgen.gd
##   godot --headless --path . --import      # so Godot picks up new PNGs
##
## Each look is a Dictionary in tools/npcgen/looks.gd. Replace any PNG with
## hand-drawn art in the same layout at any time; the game only reads the PNG.
##
## Style: a big head (hair included ~10 px), 2 px eyes with a light glint, a
## blush and 1 px nose and mouth. Front views get explicit 3-tone clothes and
## skin; every view is then lit from the upper left in screen space, so right
## views are drawn mirrored but shaded the same way. The outline is a dark
## shade of the touching colour, lighter on top and left. On step frames the
## upper body rises 1 px, and a soft oval shadow sits under the feet.

const Looks = preload("res://tools/npcgen/looks.gd")

const FW := 16
const FH := 24
const OUT_DIR := "res://assets/sprites/npcs/"
const PLAYER_PNG := "res://assets/sprites/player.png"
const ITEMS_PNG := "res://assets/sprites/story_items.png"
const LINEUP_PNG := "res://docs/cast_lineup.png"
const OUTLINE := Color("2a1f1a")
const SHOE := "3a2a20"
const SHADOW := Color("1c1830")
const BLUSH := Color("e07a70")
const MOUTH := Color("9a4a44")
const GLINT := Color("fbf6ea")
const NEIGHBOURS := [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0)]
## The sheet's columns, left to right, as [pose, step]. The game reads them by
## index (CharacterSheet.Col), so add new poses at the end.
const COLUMNS := [
	["walk", 0], ["walk", 1], ["walk", 2], ["blink", 0], ["run", 1], ["run", 2],
	["crouch", 0], ["arms_up", 0], ["reach", 0], ["carry", 0], ["carry", 1], ["carry", 2],
	["talk", 0],
]
## What stays on in poses that use both hands: worn things, not held ones.
const WORN := ["rope", "chalk_bag"]

enum Facing { DOWN, UP, LEFT, RIGHT }

var im: Image
## Top-left of the frame being drawn.
var ox := 0
var oy := 0
## Vertical offset of the upper body inside the frame: -1 on a step, so the body bobs.
var dy := 0
## Sideways offset of the upper body, toward the way a side view faces when
## negative: leaning into a run, a crouch or a load.
var dx := 0
## True while drawing a right-facing frame: geometry is mirrored, shading is not.
var mirror := false
var skin_c := Color("e0ac7e")


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var sheets: Array[Image] = []
	for id: String in Looks.LOOKS:
		var sheet := draw_sheet(Looks.LOOKS[id])
		sheet.save_png(ProjectSettings.globalize_path(OUT_DIR + id + ".png"))
		sheets.append(sheet)
		print("drew ", id)
	draw_sheet(Looks.PLAYER).save_png(ProjectSettings.globalize_path(PLAYER_PNG))
	draw_items().save_png(ProjectSettings.globalize_path(ITEMS_PNG))
	draw_lineup(sheets).save_png(ProjectSettings.globalize_path(LINEUP_PNG))
	print("done: %d characters" % sheets.size())
	quit()


# ---------------------------------------------------------------- helpers

func col(v) -> Color:
	return v if v is Color else Color(str(v))


## Side views (left and right) share one drawing, mirrored for the right.
func is_side(facing: int) -> bool:
	return facing == Facing.LEFT or facing == Facing.RIGHT


## Fills a rect in frame coordinates (upper-body rects follow the bob).
func rect(x: int, y: int, w: int, h: int, c) -> void:
	x += dx
	var xx := FW - x - w if mirror else x
	var r := Rect2i(ox + xx, oy + dy + y, w, h).intersection(Rect2i(ox, oy, FW, FH))
	if r.size.x > 0 and r.size.y > 0:
		im.fill_rect(r, col(c))


func px(x: int, y: int, c) -> void:
	x += dx
	var xx := FW - 1 - x if mirror else x
	var yy := y + dy
	if xx >= 0 and yy >= 0 and xx < FW and yy < FH:
		im.set_pixel(ox + xx, oy + yy, col(c))


func darker(c, amount := 0.25) -> Color:
	return col(c).darkened(amount)


func lighter(c, amount := 0.2) -> Color:
	return col(c).lightened(amount)


## Moves a colour's hue toward target by amt (0..1 of the way round the wheel).
func shift_hue(c: Color, target: float, amt: float) -> Color:
	var d := target - c.h
	if d > 0.5:
		d -= 1.0
	elif d < -0.5:
		d += 1.0
	return Color.from_hsv(fposmod(c.h + d * amt, 1.0), c.s, c.v, c.a)


## A tone of c for shading. k > 0 lifts toward warm yellow light, k < 0 darkens
## toward cool blue-violet shadow. k runs from -1 (deep shadow) to 1 (glint).
func tone(c, k: float) -> Color:
	var base := col(c)
	if k >= 0.0:
		return shift_hue(base.lightened(k * 0.3), 0.13, k * 0.12)
	var shade := base.darkened(-k * 0.55)
	shade = Color.from_hsv(shade.h, minf(1.0, shade.s * 1.08), shade.v, shade.a)
	return shift_hue(shade, 0.68, -k * 0.12)


## The outline colour for an edge of a sprite coloured src. Edges facing up
## or left are lit, so they get a lighter, warmer line.
func outline_of(src: Color, lit: bool) -> Color:
	var o := src.darkened(0.5 if lit else 0.72)
	return shift_hue(o, 0.68, 0.06)


## Lights the edges that face the upper left and shades the ones that face
## away, so flat colour blocks read as rounded forms. Works in screen space,
## so mirrored frames are lit from the same side. Call before the outline.
func shade_frame() -> void:
	var src := im.get_region(Rect2i(ox, oy, FW, FH))
	for y in FH:
		for x in FW:
			var c := src.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var up := y == 0 or src.get_pixel(x, y - 1).a < 0.5
			var left := x == 0 or src.get_pixel(x - 1, y).a < 0.5
			var down := y == FH - 1 or src.get_pixel(x, y + 1).a < 0.5
			var right := x == FW - 1 or src.get_pixel(x + 1, y).a < 0.5
			if up:
				c = c.lightened(0.16)
			elif left:
				c = c.lightened(0.08)
			if down:
				c = c.darkened(0.14)
			elif right:
				c = c.darkened(0.1)
			im.set_pixel(ox + x, oy + y, c)


## Outlines the transparent pixels that touch the sprite in the w×h region at
## (x0, y0), in a dark shade of the touching colour.
func outline_region(x0: int, y0: int, w: int, h: int) -> void:
	var paint: Array = []
	for y in h:
		for x in w:
			if im.get_pixel(x0 + x, y0 + y).a > 0.5:
				continue
			var src := Color(0, 0, 0, 0)
			var lit := false
			for i in 4:
				var n: Vector2i = Vector2i(x, y) + NEIGHBOURS[i]
				if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h:
					continue
				var nc := im.get_pixel(x0 + n.x, y0 + n.y)
				if nc.a > 0.5:
					if src.a == 0.0:
						src = nc
					if i >= 2:
						lit = true
			if src.a > 0.0:
				paint.append([Vector2i(x0 + x, y0 + y), outline_of(src, lit)])
	for p: Array in paint:
		im.set_pixel(p[0].x, p[0].y, p[1])


## A 1px outline around everything drawn in the current frame.
func outline_frame() -> void:
	outline_region(ox, oy, FW, FH)


## A soft ground shadow under the feet, drawn behind the figure.
func ground_shadow() -> void:
	for y in range(21, 24):
		for x in range(2, 14):
			var dx := (x + 0.5 - 8.0) / 6.2
			var dy_s := (y + 0.5 - 22.4) / 1.6
			if dx * dx + dy_s * dy_s <= 1.0 and im.get_pixel(ox + x, oy + y).a < 0.5:
				im.set_pixel(ox + x, oy + y, Color(SHADOW.r, SHADOW.g, SHADOW.b, 0.3))


# ---------------------------------------------------------------- sheet

func draw_sheet(look: Dictionary) -> Image:
	im = Image.create_empty(FW * COLUMNS.size(), FH * 4, false, Image.FORMAT_RGBA8)
	for column in COLUMNS.size():
		for facing in [Facing.DOWN, Facing.UP, Facing.LEFT, Facing.RIGHT]:
			ox = column * FW
			oy = facing * FH
			draw_figure(look, facing, COLUMNS[column][1], COLUMNS[column][0])
			shade_frame()
			outline_frame()
			ground_shadow()
	return im


## One frame of [param look] facing [param facing]. [param pose] is "walk"
## (step 0 standing, 1 and 2 the steps), "blink", "talk", "run", "crouch",
## "arms_up", "reach" or "carry" (see COLUMNS).
func draw_figure(look: Dictionary, facing: int, step: int, pose := "walk") -> void:
	var side := is_side(facing)
	var back := facing == Facing.UP
	mirror = facing == Facing.RIGHT
	var skin := col(look.get("skin", "e0ac7e"))
	skin_c = skin
	var top := col(look.get("top", "6b7d4a"))
	var bottom := col(look.get("bottom", "3b4660"))
	var bottom_style: String = look.get("bottom_style", "pants")
	var shoes := col(look.get("shoes", SHOE))
	var hair := col(look.get("hair", "4a3020"))
	var accessories: Array = look.get("carry", [])
	if pose in ["crouch", "arms_up", "reach", "carry"]:
		# Both hands are busy: only what's worn stays on.
		accessories = accessories.filter(func(item: String) -> bool: return item in WORN)
	# Arm swing: on step A the left arm leads, on step B the right.
	var swing_l := 1 if step == 1 else 0
	var swing_r := 1 if step == 2 else 0
	# The upper body rises a pixel on each step; the feet stay on the ground.
	var bob := -1 if step != 0 else 0
	# Leaning: into a run, down into a crouch, under someone on your back.
	var lean := 0
	match pose:
		"run":
			lean = -1 if side else 0
		"crouch":
			bob = 2
			lean = -1 if side else 0
		"carry":
			bob = 1 if step == 0 else 0
			lean = -1 if side else 0

	# ---- back items and long hair, behind the body
	dy = bob
	dx = lean
	if facing != Facing.UP:
		_back_items(look, facing, true)
	if look.get("hair_style", "short") in ["long", "braid"] and not back:
		if side:
			rect(8, 7, 3, 7 if look.hair_style == "long" else 5, hair)
			if look.hair_style == "braid":
				rect(9, 12, 1, 4, hair)
		else:
			rect(4, 7, 8, 6, hair)

	# ---- legs and skirt (dy 0: the feet do not bob)
	dy = 0
	dx = 0
	var skirt := bottom_style in ["dress", "skirt", "coat_long"]
	if pose == "crouch":
		_crouch_legs(look, facing, bottom, shoes)
	elif pose == "run":
		_run_legs(look, facing, step, bottom, shoes)
	elif side:
		var back_leg := tone(bottom, -0.4)
		if step == 0:
			rect(6, 17, 4, 4, bottom)
			rect(5, 21, 5, 1, shoes)
		else:
			var fwd := 1 if step == 1 else -1
			rect(7 - fwd, 17, 2, 4, back_leg)
			rect(7 + fwd, 17, 2, 4, bottom)
			rect(6 - fwd, 21, 3, 1, shoes)
			rect(6 + fwd, 21, 3, 1, shoes)
	else:
		var lift_l := 1 if step == 1 else 0
		var lift_r := 1 if step == 2 else 0
		rect(5, 17, 1, 4 - lift_l, tone(bottom, 0.12))
		rect(6, 17, 1, 4 - lift_l, bottom)
		rect(7, 17, 1, 4 - lift_l, tone(bottom, -0.35))
		rect(8, 17, 2, 4 - lift_r, bottom)
		rect(10, 17, 1, 4 - lift_r, tone(bottom, -0.35))
		rect(5, 21 - lift_l, 3, 1, shoes)
		rect(8, 21 - lift_r, 3, 1, shoes)
		rect(7, 21 - lift_l, 1, 1, tone(shoes, -0.3))
		rect(10, 21 - lift_r, 1, 1, tone(shoes, -0.3))
		if bottom_style == "knickers":
			var socks = look.get("socks", "8a8a7a")
			rect(5, 19 - lift_l, 3, 2, socks)
			rect(8, 19 - lift_r, 3, 2, socks)
	if skirt and pose == "crouch":
		# Gathered over the knees.
		var skirt_col := top if bottom_style == "dress" else bottom
		rect(3, 18, 10 if not side else 8, 3, skirt_col)
		rect(3, 18, 1, 3, tone(skirt_col, 0.15))
		rect(12 if not side else 10, 18, 1, 3, tone(skirt_col, -0.3))
	elif skirt:
		var skirt_col := top if bottom_style == "dress" else bottom
		if side:
			rect(5, 17, 6, 4, skirt_col)
		else:
			rect(4, 17, 8, 4, skirt_col)
			rect(4, 17, 1, 4, tone(skirt_col, 0.15))
			rect(10, 17, 2, 4, tone(skirt_col, -0.3))
			if bottom_style != "coat_long":
				rect(3, 19, 10, 2, skirt_col)
				rect(12, 19, 1, 2, tone(skirt_col, -0.3))
			else:
				rect(7, 17, 2, 4, tone(skirt_col, -0.2))

	# ---- torso: lit left, base, shaded right, darker belt at the bottom
	dy = bob
	dx = lean
	if side:
		rect(5, 12, 6, 6, top)
	else:
		rect(4, 12, 8, 6, top)
		rect(4, 12, 2, 6, tone(top, 0.14))
		rect(10, 12, 2, 6, tone(top, -0.3))
	if not look.has("belt"):
		rect(4 if not side else 5, 17, 8 if not side else 6, 1, tone(top, -0.55))
	_torso_details(look, facing)

	# ---- arms: darker sleeve, skin hands
	var sleeve := tone(top, -0.2) if not look.has("sleeve") else col(look.sleeve)
	if pose in ["run", "crouch", "arms_up", "reach", "carry"]:
		_pose_arms(look, facing, step, pose, sleeve, skin)
	elif side:
		rect(7, 12 + swing_l, 2, 5, sleeve)
		rect(7, 17 + swing_l, 2, 1, skin)
	else:
		rect(3, 12 + swing_l, 1, 5, tone(sleeve, 0.1))
		rect(12, 12 + swing_r, 1, 5, tone(sleeve, -0.3))
		px(3, 17 + swing_l, skin)
		px(12, 17 + swing_r, tone(skin, -0.12))
	if look.has("tattoos") and pose in ["walk", "blink", "talk"]:
		var ink := col(look.tattoos)
		if side:
			px(7, 13 + swing_l, ink)
			px(8, 15 + swing_l, ink)
		else:
			px(3, 13 + swing_l, ink)
			px(3, 15 + swing_l, ink)
			px(12, 14 + swing_r, ink)
			px(12, 16 + swing_r, ink)

	# ---- head: a big round face, 10 px tall with the hair
	var skin_lit := tone(skin, 0.12)
	var skin_shade := tone(skin, -0.22)
	var style: String = look.get("hair_style", "short")
	if back:
		if style == "bald":
			rect(5, 2, 6, 8, skin)
			rect(4, 5, 1, 4, hair)
			rect(11, 5, 1, 4, tone(hair, -0.3))
		else:
			# A rounded crown: a 4 px dome over the full-width back of the head.
			rect(6, 2, 4, 1, hair)
			rect(4, 3, 8, 7, hair)
			rect(6, 2, 2, 1, tone(hair, 0.3))
			rect(10, 3, 2, 6, tone(hair, -0.3))
		rect(5, 10, 6, 2, skin_shade)
	elif side:
		rect(5, 2, 6, 3, skin)
		rect(5, 5, 5, 6, skin)
		rect(5, 11, 4, 1, skin)
		rect(10, 5, 1, 6, skin_shade)
		px(4, 8, skin_shade) # the nose
	else:
		rect(5, 2, 6, 3, skin)
		rect(5, 5, 6, 6, skin)
		rect(4, 7, 1, 3, skin)
		rect(11, 7, 1, 3, skin_shade)
		rect(5, 5, 1, 6, skin_lit)
		rect(10, 5, 1, 6, skin_shade)
		rect(5, 11, 6, 1, skin)
		px(10, 11, skin_shade)
	_hair(look, facing)
	if not back:
		_face(look, facing, skin, skin_shade, pose)
	_beard(look, facing)
	_hat(look, facing)

	# ---- back items seen from behind, and anything carried
	dy = bob
	if back:
		_back_items(look, facing, false)
	_carry(accessories, facing, swing_r, swing_l, skin)
	if pose == "arms_up":
		# Hands up beside the hat brim, in front of everything.
		_pose_arms(look, facing, step, "hands_up", sleeve, skin)
	dy = 0
	dx = 0
	mirror = false


## Running legs: a long stride with the trailing foot kicked up off the
## ground (front and back views lift a foot higher than a walk does).
func _run_legs(look: Dictionary, facing: int, step: int, bottom: Color, shoes: Color) -> void:
	if is_side(facing):
		var fwd := -2 if step == 1 else 2
		var back_leg := tone(bottom, -0.4)
		# the trailing leg bends, its foot up behind
		rect(7 - fwd, 17, 2, 3, back_leg)
		rect(6 - fwd, 20, 3, 1, shoes)
		rect(7 + fwd, 17, 2, 4, bottom)
		rect(6 + fwd, 21, 3, 1, shoes)
		return
	var lift_l := 2 if step == 1 else 0
	var lift_r := 2 if step == 2 else 0
	rect(5, 17, 1, 4 - lift_l, tone(bottom, 0.12))
	rect(6, 17, 1, 4 - lift_l, bottom)
	rect(7, 17, 1, 4 - lift_l, tone(bottom, -0.35))
	rect(8, 17, 2, 4 - lift_r, bottom)
	rect(10, 17, 1, 4 - lift_r, tone(bottom, -0.35))
	rect(5, 21 - lift_l, 3, 1, shoes)
	rect(8, 21 - lift_r, 3, 1, shoes)
	if look.get("bottom_style", "pants") == "knickers":
		var socks = look.get("socks", "8a8a7a")
		rect(5, 19 - lift_l, 3, 2, socks)
		rect(8, 19 - lift_r, 3, 2, socks)


## Crouching to the ground: knees bent out in front (or to either side, seen
## from the front or behind), the upper body two pixels lower.
func _crouch_legs(look: Dictionary, facing: int, bottom: Color, shoes: Color) -> void:
	if is_side(facing):
		var back_leg := tone(bottom, -0.4)
		# the back knee down, the front thigh level and its shin upright
		rect(8, 19, 3, 2, back_leg)
		rect(10, 21, 3, 1, shoes)
		rect(4, 18, 5, 2, bottom)
		rect(4, 20, 2, 1, bottom)
		rect(3, 21, 3, 1, shoes)
		return
	rect(4, 19, 3, 2, tone(bottom, 0.12))
	rect(9, 19, 3, 2, tone(bottom, -0.2))
	rect(6, 19, 4, 1, bottom)
	rect(4, 21, 3, 1, shoes)
	rect(9, 21, 3, 1, shoes)
	if look.get("bottom_style", "pants") == "knickers":
		var socks = look.get("socks", "8a8a7a")
		rect(4, 20, 3, 1, socks)
		rect(9, 20, 3, 1, socks)


## The arms for the poses that aren't a walk: pumping in a run, reaching to
## the ground, raised overhead, held out in front, or holding someone on your
## back. "hands_up" is the front view's raised hands, drawn last.
func _pose_arms(_look: Dictionary, facing: int, step: int, pose: String, sleeve: Color, skin: Color) -> void:
	var side := is_side(facing)
	var lit := tone(sleeve, 0.1)
	var shade := tone(sleeve, -0.3)
	var skin_dark := tone(skin, -0.12)
	match pose:
		"run":
			if side:
				if step == 1:
					# the near arm pumps forward, bent up at the elbow
					rect(6, 12, 2, 3, sleeve)
					rect(4, 13, 2, 2, sleeve)
					px(3, 13, skin)
				else:
					rect(8, 12, 2, 3, sleeve)
					rect(10, 14, 2, 2, sleeve)
					px(12, 15, skin)
			else:
				var up_l := 3 if step == 1 else 0
				var up_r := 3 if step == 2 else 0
				rect(3, 12, 1, 5 - up_l, lit)
				rect(12, 12, 1, 5 - up_r, shade)
				px(3, 17 - up_l, skin)
				px(12, 17 - up_r, skin_dark)
		"crouch":
			if side:
				# reaching down to the ground in front
				rect(5, 12, 2, 3, sleeve)
				rect(3, 14, 2, 3, sleeve)
				rect(3, 17, 2, 1, skin)
			else:
				rect(3, 12, 1, 3, lit)
				rect(12, 12, 1, 3, shade)
				rect(4, 15, 1, 2, lit)
				rect(11, 15, 1, 2, shade)
				if facing == Facing.DOWN:
					px(5, 17, skin)
					px(10, 17, skin_dark)
		"arms_up":
			# raised after the head is drawn (see "hands_up")
			pass
		"hands_up":
			if side:
				# one arm up behind the head (a back cast, a stretch)
				rect(10, 4, 2, 9, sleeve)
				rect(11, 4, 1, 9, shade)
				rect(10, 3, 2, 1, skin)
				return
			rect(3, 4, 1, 8, lit)
			rect(12, 4, 1, 8, shade)
			px(3, 3, skin)
			px(12, 3, skin_dark)
		"reach":
			if side:
				# held straight out in front at the shoulder
				rect(3, 12, 5, 2, sleeve)
				rect(2, 12, 1, 2, skin)
			elif facing == Facing.DOWN:
				# both hands out toward you
				rect(3, 12, 1, 2, lit)
				rect(12, 12, 1, 2, shade)
				rect(4, 14, 2, 1, sleeve)
				rect(10, 14, 2, 1, sleeve)
				px(6, 14, skin)
				px(9, 14, skin_dark)
			else:
				rect(3, 11, 1, 3, lit)
				rect(12, 11, 1, 3, shade)
		"carry":
			if side:
				# bent back to hold the legs of whoever rides on you
				rect(8, 12, 2, 3, sleeve)
				rect(10, 14, 2, 1, sleeve)
				px(12, 14, skin)
			elif facing == Facing.DOWN:
				rect(3, 12, 1, 4, lit)
				rect(12, 12, 1, 4, shade)
				px(3, 16, skin)
				px(12, 16, skin_dark)
			else:
				rect(3, 12, 1, 3, lit)
				rect(12, 12, 1, 3, shade)
				px(4, 15, skin)
				px(11, 15, skin_dark)


## Eyes with a light glint, blush, nose and mouth, and optional glasses.
## Eyes closed on a "blink" frame, the mouth open on a "talk" frame.
func _face(look: Dictionary, facing: int, skin: Color, skin_shade: Color, pose := "walk") -> void:
	var eye := col(look.get("eyes", "2a1f1a"))
	var blush := skin.lerp(BLUSH, 0.45)
	var mouth := skin.lerp(MOUTH, 0.6)
	var shut := pose == "blink"
	var lid := tone(skin, -0.45)
	var open_mouth := mouth.darkened(0.45)
	if is_side(facing):
		px(6, 7, skin if shut else GLINT)
		px(6, 8, lid if shut else eye)
		px(6, 9, blush)
		px(5, 10, open_mouth if pose == "talk" else mouth)
		if pose == "talk":
			px(6, 10, mouth)
	else:
		for ex in [6, 9]:
			px(ex, 7, skin if shut else GLINT)
			px(ex, 8, lid if shut else eye)
		px(5, 9, blush)
		px(10, 9, blush)
		px(7, 9, skin_shade)
		px(7, 10, open_mouth if pose == "talk" else mouth)
		if pose == "talk":
			px(8, 10, mouth)
	if look.get("glasses", false):
		var g := Color("c8c8c8")
		if is_side(facing):
			rect(5, 6, 3, 1, g)
		else:
			rect(5, 6, 6, 1, g)


func _hair(look: Dictionary, facing: int) -> void:
	var style: String = look.get("hair_style", "short")
	var hair := col(look.get("hair", "4a3020"))
	var hi := tone(hair, 0.3)
	var sh := tone(hair, -0.3)
	var dp := tone(hair, -0.55)
	var side := is_side(facing)
	var back := facing == Facing.UP
	if style == "none":
		return
	if style == "bald":
		if back:
			return
		if side:
			rect(9, 3, 2, 3, hair)
		else:
			rect(4, 3, 1, 3, hair)
			rect(11, 3, 1, 3, sh)
		return
	if back:
		if style in ["long", "braid"]:
			rect(4, 6, 8, 7 if style == "long" else 5, hair)
			if style == "braid":
				rect(7, 11, 2, 5, hair)
				px(7, 16, look.get("tie", "b03030"))
		if style == "bun":
			rect(6, 1, 4, 2, hair)
		if style == "wild":
			rect(3, 3, 1, 5, hair)
			rect(12, 3, 1, 5, hair)
		return
	if side:
		# Rounded dome, a lit streak on the top, hair falling behind the head.
		rect(6, 2, 4, 1, hair)
		rect(5, 3, 6, 2, hair)
		rect(6, 2, 2, 1, hi)
		rect(7, 3, 2, 1, hi)
		rect(5, 5, 2, 1, hair)
		rect(9, 5, 2, 5, hair)
		rect(9, 3, 2, 2, sh)
		rect(10, 5, 1, 5, sh)
		if style == "bun":
			rect(8, 1, 3, 2, hair)
			px(9, 1, hi)
		if style in ["long", "braid"]:
			rect(9, 5, 2, 7 if style == "long" else 6, hair)
		if style == "wild":
			rect(5, 1, 2, 1, hair)
		return
	# Front: a rounded dome (4 px, then 6, then 8 px wide), a lit streak, a
	# fringe, and sideburns.
	rect(6, 2, 4, 1, hair)
	rect(4, 3, 8, 2, hair)
	rect(6, 2, 2, 1, hi)
	rect(5, 3, 2, 1, hi)
	rect(10, 3, 2, 2, sh)
	rect(4, 5, 2, 2, hair)
	rect(10, 5, 2, 2, sh)
	rect(6, 5, 4, 1, dp)
	if style == "long":
		rect(4, 5, 1, 6, hair)
		rect(11, 5, 1, 6, sh)
	if style in ["long", "braid"]:
		rect(4, 7, 1, 2, hair)
	if style == "bun":
		rect(6, 1, 4, 2, hair)
		px(7, 1, hi)
	if style == "wild":
		rect(3, 2, 1, 3, hair)
		rect(12, 2, 1, 3, hair)
		rect(6, 1, 2, 1, hair)


func _beard(look: Dictionary, facing: int) -> void:
	var beard: String = look.get("beard", "none")
	if beard == "none" or facing == Facing.UP:
		return
	var c = look.get("beard_color", look.get("hair", "4a3020"))
	var side := is_side(facing)
	match beard:
		"mustache":
			if side:
				rect(4, 9, 3, 1, c)
			else:
				rect(6, 9, 4, 1, c)
		"goatee":
			if side:
				rect(4, 9, 3, 1, c)
				rect(5, 10, 2, 2, c)
			else:
				rect(6, 9, 4, 1, c)
				rect(7, 10, 2, 2, c)
		"short":
			if side:
				rect(4, 9, 4, 3, c)
				rect(8, 8, 2, 3, c)
			else:
				rect(5, 9, 6, 3, c)
				rect(5, 8, 1, 1, c)
				rect(10, 8, 1, 1, c)
				px(7, 9, darker(c, 0.3))
				px(8, 9, darker(c, 0.3))
		"long":
			if side:
				rect(4, 9, 4, 3, c)
				rect(8, 8, 2, 3, c)
				rect(4, 12, 3, 3, c)
				px(5, 15, c)
			else:
				rect(5, 9, 6, 3, c)
				rect(5, 8, 1, 1, c)
				rect(10, 8, 1, 1, c)
				rect(6, 12, 4, 3, c)
				rect(7, 15, 2, 1, c)
				px(7, 9, darker(c, 0.3))
				px(8, 9, darker(c, 0.3))


## A hat with a lit left side, a shaded right side and a darker band. Brims
## throw a shadow across the forehead.
func _hat(look: Dictionary, facing: int) -> void:
	var hat: String = look.get("hat", "none")
	if hat == "none":
		return
	var c := col(look.get("hat_color", "6b4a2a"))
	var band := col(look.get("hat_band", tone(c, -0.45)))
	var side := is_side(facing)
	var back := facing == Facing.UP
	match hat:
		"wide":
			_crown(5, 1, 6, 3, c)
			rect(5, 3, 6, 1, band)
			_brim(2, 12, c)
		"campaign":
			# The pinched "Montana peak" of the ranger hat.
			_crown(5, 2, 6, 2, c)
			rect(7, 1, 2, 1, c)
			rect(5, 3, 6, 1, band)
			_brim(2, 12, c)
		"fedora":
			_crown(5, 2, 6, 2, c)
			px(7, 1, c)
			px(8, 1, c)
			rect(5, 3, 6, 1, band)
			if side:
				_brim(2, 11, c)
			else:
				_brim(3, 10, c)
		"bowler":
			_crown(5, 2, 6, 2, c)
			rect(6, 1, 4, 1, c)
			_brim(4, 8, c)
		"top":
			_crown(6, 1, 4, 3, c)
			rect(6, 3, 4, 1, band)
			_brim(4, 8, c)
		"cap":
			_crown(5, 2, 6, 3, c)
			if facing == Facing.DOWN:
				rect(5, 5, 6, 1, tone(c, -0.3))
			elif side:
				rect(2, 5, 4, 1, tone(c, -0.3))
		"toque":
			# A chef's tall white hat: a pleated band and a puff over it.
			_crown(4, 0, 8, 3, c)
			rect(5, 3, 6, 2, tone(c, -0.12))
			px(7, 3, tone(c, -0.3))
			px(9, 3, tone(c, -0.3))
		"painter_cap":
			_crown(5, 2, 6, 3, c)
			if facing == Facing.DOWN:
				rect(5, 5, 6, 1, tone(c, -0.25))
			elif side:
				rect(3, 5, 3, 1, tone(c, -0.25))
		"beanie":
			_crown(5, 1, 6, 3, c)
			rect(5, 4, 6, 1, tone(c, -0.3))
			px(7, 1, tone(c, 0.35))
			px(8, 1, tone(c, 0.35))
		"bonnet":
			if back:
				rect(4, 3, 8, 6, c)
			elif side:
				rect(5, 3, 7, 3, c)
				rect(9, 5, 3, 5, c)
				rect(3, 4, 3, 1, c)
			else:
				rect(4, 3, 8, 3, c)
				rect(4, 5, 1, 5, c)
				rect(11, 5, 1, 5, c)
		"scarf":
			# A headscarf tied at the back.
			if back:
				rect(5, 3, 6, 6, c)
				rect(7, 9, 2, 2, tone(c, -0.3))
			elif side:
				rect(5, 3, 6, 3, c)
				rect(8, 5, 3, 4, c)
				px(11, 8, tone(c, -0.3))
			else:
				rect(5, 3, 6, 3, c)
				px(5, 6, c)
				px(10, 6, c)
		"headband":
			if side:
				rect(5, 5, 6, 1, c)
				px(11, 6, c)
			else:
				rect(5, 5, 6, 1, c)
		"helmet":
			_crown(5, 1, 6, 3, c)
			rect(4, 4, 8, 1, c)
			px(6, 2, lighter(c, 0.3))
	if not back and hat in ["wide", "campaign", "fedora", "bowler", "top"]:
		# The brim's shadow falls across the forehead.
		rect(5, 5, 6, 1, tone(skin_c, -0.3))


## A crown with a lit left column and a shaded right column.
func _crown(x: int, y: int, w: int, h: int, c: Color) -> void:
	rect(x, y, w, h, c)
	rect(x, y, 1, h, tone(c, 0.2))
	rect(x + w - 1, y, 1, h, tone(c, -0.3))


## A brim one row tall, lit at the left end and shaded at the right.
func _brim(x: int, w: int, c: Color) -> void:
	rect(x, 4, w, 1, c)
	rect(x, 4, 2, 1, tone(c, 0.2))
	rect(x + w - 2, 4, 2, 1, tone(c, -0.3))


func _torso_details(look: Dictionary, facing: int) -> void:
	var style: String = look.get("top_style", "shirt")
	var top = look.get("top", "6b7d4a")
	var alt = look.get("top2", darker(top, 0.35))
	var side := is_side(facing)
	var back := facing == Facing.UP
	match style:
		"vest":
			if side:
				rect(8, 12, 3, 6, alt)
			elif not back:
				rect(4, 12, 2, 6, alt)
				rect(10, 12, 2, 6, alt)
			else:
				rect(4, 12, 8, 6, alt)
		"suspenders":
			if not side:
				rect(5, 12, 1, 6, alt)
				rect(10, 12, 1, 6, alt)
			else:
				rect(7, 12, 1, 6, alt)
		"jacket":
			if not side and not back:
				rect(7, 12, 2, 6, alt)
				px(6, 12, lighter(top))
				px(9, 12, lighter(top))
		"plaid":
			for y in range(12, 18):
				for x in range(4, 12):
					if (x + y) % 3 == 0 or y % 3 == 0:
						if (not side or (x >= 5 and x <= 10)):
							px(x, y, alt)
		"sweater":
			if not side and not back:
				rect(6, 12, 4, 1, alt)
			rect(4 if not side else 5, 16, 8 if not side else 6, 1, alt)
		"coat":
			if not side and not back:
				rect(7, 12, 2, 6, alt)
		"shawl":
			if side:
				rect(5, 12, 6, 3, alt)
			else:
				rect(3, 12, 10, 3, alt)
				if not back:
					rect(7, 15, 2, 1, alt)
		"blouse":
			if not side and not back:
				rect(6, 12, 4, 1, alt)
				px(7, 13, alt)
				px(8, 13, alt)
		"stripes":
			for y in range(12, 18):
				if y % 2 == 0:
					rect(4 if not side else 5, y, 8 if not side else 6, 1, alt)
	if look.has("collar") and not back:
		if side:
			rect(5, 12, 2, 1, look.collar)
		else:
			rect(6, 12, 4, 1, look.collar)
	if look.has("belt"):
		if side:
			rect(5, 17, 6, 1, look.belt)
		else:
			rect(4, 17, 8, 1, look.belt)
	if look.has("apron") and not back:
		var a = look.apron
		if side:
			rect(4, 13, 2, 8, a)
		else:
			rect(5, 13, 6, 8, a)
			px(5, 12, a)
			px(10, 12, a)
	if look.get("badge", false) and not back and not side:
		px(9, 13, "e8c040")
	if look.has("bandana") and not back:
		if side:
			rect(5, 11, 3, 1, look.bandana)
		else:
			rect(6, 11, 4, 1, look.bandana)
			px(7, 12, look.bandana)
			px(8, 12, look.bandana)


## Packs, rope coils, and haul bags: drawn behind the body, or over it when
## seen from behind.
func _back_items(look: Dictionary, facing: int, behind: bool) -> void:
	var pack: String = look.get("pack", "none")
	if pack == "none":
		return
	var c = look.get("pack_color", "7a5a3a")
	var side := is_side(facing)
	match pack:
		"pack", "frame_pack", "haul_bag":
			var tall := 7 if pack == "pack" else 9
			var top_y := 11 if pack == "pack" else 9
			if facing == Facing.UP and not behind:
				rect(4, top_y, 8, tall, c)
				rect(4, top_y, 2, tall, lighter(c, 0.12))
				rect(4, top_y + 2, 8, 1, darker(c, 0.3))
				if pack == "frame_pack":
					rect(4, 8, 1, 12, "9a9a9a")
					rect(11, 8, 1, 12, "9a9a9a")
				if pack == "haul_bag":
					rect(6, top_y - 1, 4, 1, "d8c898")
			elif side and behind:
				rect(10, top_y, 3, tall, c)
				rect(10, top_y, 1, tall, tone(c, -0.3))
				if pack == "frame_pack":
					rect(13, 8, 1, 12, "9a9a9a")
			elif facing == Facing.DOWN and behind:
				# Just the straps show from the front.
				pass
	if facing == Facing.DOWN and not behind:
		return


## Things carried in the hand or worn over the clothes.
func _carry(items: Array, facing: int, swing_r: int, swing_l: int, skin) -> void:
	var side := is_side(facing)
	var back := facing == Facing.UP
	# Hand positions for this frame.
	var hx := 12 if facing == Facing.DOWN else (3 if back else 7)
	var hy := 17 + (swing_r if facing == Facing.DOWN else swing_l)
	for item: String in items:
		match item:
			"rope":
				# A coil slung across the chest.
				var r := "d8c070"
				if side:
					rect(5, 12, 4, 1, r)
					rect(4, 13, 1, 4, r)
					rect(9, 13, 1, 4, r)
					rect(5, 17, 4, 1, r)
				elif back:
					for i in 6:
						px(10 - i, 12 + i, r)
				else:
					for i in 6:
						px(5 + i, 12 + i, r)
					px(4, 12, r)
			"chalk_bag":
				if not side:
					rect(10 if not back else 5, 17, 2, 2, "e8e8e0")
				else:
					rect(10, 17, 2, 2, "e8e8e0")
			"book":
				rect(hx - (1 if side else 0), hy - 2, 2, 3, "8a2a2a")
				px(hx - (1 if side else 0), hy - 2, "d8c8a0")
			"register":
				rect(hx - (1 if side else 0), hy - 3, 3, 4, "5a3a22")
				rect(hx - (1 if side else 0), hy - 1, 3, 1, "c8a060")
			"basket":
				var bx := hx - 1 if not side else hx - 2
				rect(bx, hy - 1, 4, 3, "b08850")
				rect(bx, hy - 1, 4, 1, "7a5a30")
				px(bx + 1, hy + 1, "7a5a30")
				px(bx + 3, hy, "7a5a30")
			"loaf":
				rect(hx - (2 if side else 0), hy - 1, 3, 2, "b0783a")
				px(hx - (1 if side else -1), hy - 1, "d8a860")
			"hammer":
				rect(hx, hy - 5, 1, 6, "7a5a3a")
				rect(hx - 1, hy - 6, 3, 1, "8a8a8a")
			"drill":
				rect(hx, hy - 4, 1, 5, "9a9aa0")
				px(hx, hy - 5, "d0d0d8")
			"camera":
				rect(hx - (2 if side else 1), hy - 3, 3, 3, "2a2a2a")
				px(hx - (1 if side else 0), hy - 2, "8ab0d0")
			"stick":
				rect(hx, hy - 6, 1, 12, "6a4a2a")
			"cane":
				rect(hx, hy, 1, 6, "5a3a22")
				px(hx - 1, hy, "5a3a22")
			"parasol":
				if side:
					rect(10, hy - 12, 1, 12, "5a3a22")
					rect(8, hy - 14, 7, 2, "e0a0b0")
					rect(9, hy - 15, 5, 1, "e0a0b0")
				elif not back:
					rect(hx, hy - 12, 1, 12, "5a3a22")
					rect(hx - 3, hy - 14, 7, 2, "e0a0b0")
					rect(hx - 2, hy - 15, 5, 1, "e0a0b0")
				else:
					rect(hx - 3, hy - 14, 7, 3, "e0a0b0")
			"suitcase":
				rect(hx - (2 if side else 1), hy, 4, 3, "7a4a2a")
				px(hx - (1 if side else 0), hy - 1, "3a2a1a")
			"rod":
				for i in 12:
					px(hx + (i / 4 if not side else 3 + i / 4), hy - i, "6a5a3a")
			"shovel":
				rect(hx, hy - 7, 1, 10, "7a5a3a")
				rect(hx - 1, hy + 3, 3, 2, "8a8a90")
			"notebook":
				rect(hx - (1 if side else 0), hy - 2, 2, 3, "d8d0b0")
			"apple":
				px(hx, hy - 1, "c83030")
				px(hx, hy - 2, "5a8a30")
			"lantern":
				rect(hx - (1 if side else 0), hy, 2, 3, "e8c050")
				px(hx - (1 if side else 0), hy - 1, "3a3a3a")
			"acorn":
				px(hx, hy - 1, "8a5a2a")
				px(hx, hy - 2, "5a4020")
			"map":
				rect(hx - (2 if side else 0), hy - 2, 3, 3, "e8e0c0")
				px(hx - (1 if side else 1), hy - 1, "6a8a5a")


# ---------------------------------------------------------------- items

## 16×16 icons for story items, in the order of Looks.ITEMS. Each has three
## tones lit from the upper left, a dark coloured outline, and a glint.
func draw_items() -> Image:
	im = Image.create_empty(16 * Looks.ITEMS.size(), 16, false, Image.FORMAT_RGBA8)
	dy = 0
	mirror = false
	for i in Looks.ITEMS.size():
		ox = i * 16
		oy = 0
		match Looks.ITEMS[i]:
			"lamon_apple":
				var r := Color("c83030")
				rect(4, 5, 8, 9, r)
				rect(3, 6, 10, 7, r)
				rect(5, 14, 6, 1, r)
				rect(4, 6, 2, 6, tone(r, 0.3))
				rect(10, 7, 2, 7, tone(r, -0.4))
				rect(5, 13, 6, 1, tone(r, -0.4))
				px(5, 7, GLINT)
				px(5, 8, tone(r, 0.5))
				rect(7, 2, 1, 3, "5a3a1a")
				rect(8, 2, 3, 2, "5a9a30")
				px(8, 2, "7ac040")
				px(10, 3, "3a7a20")
			"degnan_loaf":
				var b := Color("b0783a")
				rect(2, 7, 12, 6, b)
				rect(3, 6, 10, 1, b)
				rect(2, 7, 12, 1, tone(b, 0.25))
				rect(3, 12, 10, 1, tone(b, -0.35))
				rect(12, 8, 1, 4, tone(b, -0.35))
				for x in [4, 7, 10]:
					rect(x, 8, 2, 1, tone(b, 0.45))
				px(4, 9, GLINT)
			"pine_nuts":
				for p in [Vector2i(3, 8), Vector2i(7, 5), Vector2i(11, 8), Vector2i(7, 10)]:
					var n := Color("8a5a3a")
					rect(p.x, p.y, 2, 3, n)
					rect(p.x, p.y, 1, 2, tone(n, 0.3))
					rect(p.x + 1, p.y + 1, 1, 2, tone(n, -0.35))
					px(p.x, p.y + 2, tone(n, -0.5))
				px(7, 5, GLINT)
			"model_a_axle":
				rect(2, 7, 12, 2, "6a6a70")
				rect(2, 7, 12, 1, "9a9aa0")
				rect(2, 8, 12, 1, "4a4a52")
				rect(1, 5, 2, 6, "4a4a50")
				rect(13, 5, 2, 6, "34343a")
				rect(1, 5, 1, 2, "7a7a84")
				px(6, 8, "8a5a3a")
				px(10, 7, "8a5a3a")
				px(4, 7, GLINT)
			"anderson_eyebolt":
				var m := Color("7a7a80")
				rect(5, 2, 6, 5, m)
				rect(6, 3, 4, 3, Color(0, 0, 0, 0))
				rect(7, 6, 2, 8, m)
				rect(5, 2, 1, 5, tone(m, 0.3))
				rect(7, 6, 1, 8, tone(m, 0.3))
				rect(10, 2, 1, 5, tone(m, -0.35))
				rect(8, 6, 1, 8, tone(m, -0.35))
				px(7, 9, tone(m, -0.5))
				px(8, 11, tone(m, -0.5))
				px(5, 3, GLINT)
				px(8, 13, "5a4a3a")
			"sourdough_starter":
				var g := Color("d8d0c0")
				rect(4, 4, 8, 2, "7a5a3a")
				rect(4, 4, 2, 2, tone(Color("7a5a3a"), 0.3))
				rect(4, 6, 8, 8, g)
				rect(10, 6, 2, 8, tone(g, -0.3))
				rect(5, 7, 5, 5, "f0e8d0")
				rect(9, 7, 1, 5, tone(Color("f0e8d0"), -0.2))
				px(5, 7, GLINT)
			"rental_shoes":
				# A pair of rental climbing shoes tied together by the laces, with a shop tag.
				var s := Color("c8502e")
				rect(1, 7, 7, 4, s)
				rect(1, 10, 8, 2, "222226")
				rect(8, 9, 7, 3, s)
				rect(8, 12, 7, 1, "222226")
				rect(1, 7, 7, 1, tone(s, 0.3))
				rect(8, 9, 7, 1, tone(s, 0.3))
				rect(8, 11, 7, 1, tone(s, -0.35))
				px(4, 8, "f0e8d8")
				px(11, 10, "f0e8d8")
				px(2, 8, GLINT)
				rect(6, 3, 1, 5, "f0e8d8")
				rect(9, 4, 4, 3, "e8dcb0")
				px(10, 5, "5a3a24")
		outline_frame16()
	return im


## Outlines the 16×16 item icon at ox.
func outline_frame16() -> void:
	outline_region(ox, 0, 16, 16)


# ---------------------------------------------------------------- preview

## Every character facing down, standing, at 4× on a light background.
func draw_lineup(sheets: Array[Image]) -> Image:
	const S := 4
	const PER_ROW := 8
	var rows := ceili(sheets.size() / float(PER_ROW))
	var out := Image.create_empty(PER_ROW * (FW + 4) * S, rows * (FH + 4) * S, false, Image.FORMAT_RGBA8)
	out.fill(Color("e8e0cc"))
	for i in sheets.size():
		var frame := sheets[i].get_region(Rect2i(0, 0, FW, FH))
		frame.resize(FW * S, FH * S, Image.INTERPOLATE_NEAREST)
		var at := Vector2i((i % PER_ROW) * (FW + 4) * S + 2 * S, (i / PER_ROW) * (FH + 4) * S + 2 * S)
		out.blend_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), at)
	return out
