extends SceneTree
## Draws the placeholder pixel art for every person in the game: one 48×96
## sheet per character, in the same layout as assets/sprites/player.png
## (16×24 frames; columns stand / step A / step B, rows down / up / left /
## right). Also draws the icons for story items (assets/sprites/story_items.png)
## and a preview lineup of the whole cast (docs/cast_lineup.png).
##
##   godot --headless --path . -s res://tools/npcgen/npcgen.gd
##   godot --headless --path . --import      # so Godot picks up new PNGs
##
## Each look is a Dictionary in tools/npcgen/looks.gd. Replace any PNG with
## hand-drawn art in the same layout at any time; the game only reads the PNG.

const Looks = preload("res://tools/npcgen/looks.gd")

const FW := 16
const FH := 24
const OUT_DIR := "res://assets/sprites/npcs/"
const ITEMS_PNG := "res://assets/sprites/story_items.png"
const LINEUP_PNG := "res://docs/cast_lineup.png"
const OUTLINE := Color("2a1f1a")
const SHOE := "3a2a20"

enum Facing { DOWN, UP, LEFT, RIGHT }

var im: Image
## Top-left of the frame being drawn.
var ox := 0
var oy := 0


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var sheets: Array[Image] = []
	for id: String in Looks.LOOKS:
		var sheet := draw_sheet(Looks.LOOKS[id])
		sheet.save_png(ProjectSettings.globalize_path(OUT_DIR + id + ".png"))
		sheets.append(sheet)
		print("drew ", id)
	draw_items().save_png(ProjectSettings.globalize_path(ITEMS_PNG))
	draw_lineup(sheets).save_png(ProjectSettings.globalize_path(LINEUP_PNG))
	print("done: %d characters" % sheets.size())
	quit()


# ---------------------------------------------------------------- helpers

func col(v) -> Color:
	return v if v is Color else Color(str(v))


## Fills a rect in frame coordinates.
func rect(x: int, y: int, w: int, h: int, c) -> void:
	var r := Rect2i(ox + x, oy + y, w, h).intersection(Rect2i(ox, oy, FW, FH))
	if r.size.x > 0 and r.size.y > 0:
		im.fill_rect(r, col(c))


func px(x: int, y: int, c) -> void:
	if x >= 0 and y >= 0 and x < FW and y < FH:
		im.set_pixel(ox + x, oy + y, col(c))


func darker(c, amount := 0.25) -> Color:
	return col(c).darkened(amount)


func lighter(c, amount := 0.2) -> Color:
	return col(c).lightened(amount)


## A 1px dark outline around everything drawn in the current frame.
func outline_frame() -> void:
	var edge: Array[Vector2i] = []
	for y in FH:
		for x in FW:
			if im.get_pixel(ox + x, oy + y).a > 0.5:
				continue
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n := Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < FW and n.y < FH and im.get_pixel(ox + n.x, oy + n.y).a > 0.5:
					edge.append(Vector2i(x, y))
					break
	for p in edge:
		im.set_pixel(ox + p.x, oy + p.y, OUTLINE)


# ---------------------------------------------------------------- sheet

func draw_sheet(look: Dictionary) -> Image:
	im = Image.create_empty(FW * 3, FH * 4, false, Image.FORMAT_RGBA8)
	for step in 3:
		for facing in [Facing.DOWN, Facing.UP, Facing.LEFT]:
			ox = step * FW
			oy = facing * FH
			draw_figure(look, facing, step)
			outline_frame()
		# Right is the left frame mirrored.
		var left := im.get_region(Rect2i(step * FW, Facing.LEFT * FH, FW, FH))
		left.flip_x()
		im.blit_rect(left, Rect2i(0, 0, FW, FH), Vector2i(step * FW, Facing.RIGHT * FH))
	return im


func draw_figure(look: Dictionary, facing: int, step: int) -> void:
	var side := facing == Facing.LEFT
	var skin = look.get("skin", "e0ac7e")
	var top = look.get("top", "6b7d4a")
	var bottom = look.get("bottom", "3b4660")
	var bottom_style: String = look.get("bottom_style", "pants")
	var shoes = look.get("shoes", SHOE)
	var hair = look.get("hair", "4a3020")
	var accessories: Array = look.get("carry", [])
	# Arm swing: on step A the left arm leads, on step B the right.
	var swing_l := 1 if step == 1 else 0
	var swing_r := 1 if step == 2 else 0

	# Things worn on the back go behind the body.
	if facing != Facing.UP:
		_back_items(look, facing, true)

	# Long hair falls behind the shoulders.
	if look.get("hair_style", "short") in ["long", "braid"] and facing != Facing.UP:
		if side:
			rect(8, 7, 3, 7 if look.hair_style == "long" else 5, hair)
			if look.hair_style == "braid":
				rect(9, 12, 1, 4, hair)
		else:
			rect(4, 7, 8, 6, hair)

	# ---- legs and skirt
	var skirt := bottom_style in ["dress", "skirt", "coat_long"]
	var skirt_col = top if bottom_style == "dress" else bottom
	if side:
		var back_leg := darker(bottom, 0.2)
		if step == 0:
			rect(6, 18, 4, 4, bottom)
			rect(6, 22, 5, 1, shoes)
		else:
			var fwd := 1 if step == 1 else -1
			rect(7 - fwd, 18, 2, 4, back_leg)
			rect(7 + fwd, 18, 2, 4, bottom)
			rect(6 - fwd, 22, 3, 1, shoes)
			rect(6 + fwd, 22, 3, 1, shoes)
	else:
		var lift_l := 1 if step == 1 else 0
		var lift_r := 1 if step == 2 else 0
		rect(5, 18, 3, 4 - lift_l, bottom)
		rect(8, 18, 3, 4 - lift_r, bottom)
		rect(10, 18, 1, 4 - lift_r, darker(bottom, 0.15))
		rect(5, 22 - lift_l, 3, 1, shoes)
		rect(8, 22 - lift_r, 3, 1, shoes)
		if bottom_style == "knickers":
			rect(5, 20 - lift_l, 3, 2, look.get("socks", "8a8a7a"))
			rect(8, 20 - lift_r, 3, 2, look.get("socks", "8a8a7a"))
	if skirt:
		var hem := 21 if bottom_style != "coat_long" else 20
		if side:
			rect(5, 17, 6, hem - 16, skirt_col)
			rect(10, 17, 1, hem - 16, darker(skirt_col, 0.15))
		else:
			rect(4, 17, 8, hem - 16, skirt_col)
			rect(11, 17, 1, hem - 16, darker(skirt_col, 0.15))
			if bottom_style != "coat_long":
				rect(3, 20, 10, 2, skirt_col)
				rect(12, 20, 1, 2, darker(skirt_col, 0.15))
			else:
				rect(7, 17, 2, hem - 16, darker(skirt_col, 0.3))

	# ---- torso
	if side:
		rect(5, 12, 6, 6, top)
		rect(10, 12, 1, 6, darker(top, 0.15))
	else:
		rect(4, 12, 8, 6, top)
		rect(11, 12, 1, 6, darker(top, 0.15))
	_torso_details(look, facing)

	# ---- arms
	var sleeve := darker(top, 0.12) if not look.has("sleeve") else col(look.sleeve)
	if side:
		rect(7, 12 + swing_l, 2, 5, sleeve)
		rect(7, 17 + swing_l, 2, 1, skin)
	else:
		rect(3, 12 + swing_l, 1, 5, sleeve)
		rect(12, 12 + swing_r, 1, 5, darker(sleeve, 0.1))
		px(3, 17 + swing_l, skin)
		px(12, 17 + swing_r, skin)

	# ---- head
	if side:
		rect(5, 5, 6, 7, skin)
		px(4, 8, skin) # nose
		rect(10, 6, 1, 5, darker(skin, 0.12))
	else:
		rect(5, 5, 6, 7, skin)
		rect(10, 5, 1, 7, darker(skin, 0.1))
	_hair(look, facing)
	if facing != Facing.UP:
		var eye = look.get("eyes", "2a1f1a")
		if side:
			px(6, 8, eye)
		else:
			px(6, 8, eye)
			px(9, 8, eye)
		if look.get("glasses", false):
			if side:
				rect(5, 8, 3, 1, "c8c8c8")
				px(6, 8, eye)
			else:
				rect(5, 8, 6, 1, "c8c8c8")
				px(6, 8, eye)
				px(9, 8, eye)
	_beard(look, facing)
	_hat(look, facing)

	if facing == Facing.UP:
		_back_items(look, facing, false)
	_carry(accessories, facing, swing_r, swing_l, skin)


func _hair(look: Dictionary, facing: int) -> void:
	var style: String = look.get("hair_style", "short")
	var hair = look.get("hair", "4a3020")
	var side := facing == Facing.LEFT
	if style == "none":
		return
	if style == "bald":
		if facing == Facing.UP:
			rect(5, 8, 6, 3, hair)
		elif side:
			rect(9, 7, 2, 3, hair)
		else:
			px(5, 7, hair)
			px(10, 7, hair)
		return
	if facing == Facing.UP:
		rect(5, 4, 6, 8, hair)
		if style in ["long", "braid"]:
			rect(4, 6, 8, 7 if style == "long" else 5, hair)
			if style == "braid":
				rect(7, 11, 2, 5, hair)
				px(7, 16, look.get("tie", "b03030"))
		if style == "bun":
			rect(6, 3, 4, 3, hair)
		return
	if side:
		rect(5, 4, 6, 2, hair)
		rect(8, 5, 3, 4, hair)
		if style == "bun":
			rect(9, 3, 3, 3, hair)
		if style in ["long", "braid"]:
			rect(9, 6, 2, 6, hair)
		return
	rect(5, 4, 6, 2, hair)
	px(5, 6, hair)
	px(10, 6, hair)
	if style in ["long", "braid", "bun"]:
		px(5, 7, hair)
		px(10, 7, hair)
	if style == "bun":
		rect(6, 2, 4, 2, hair)
	if style == "wild":
		rect(4, 4, 8, 2, hair)
		rect(4, 6, 1, 4, hair)
		rect(11, 6, 1, 4, hair)


func _beard(look: Dictionary, facing: int) -> void:
	var beard: String = look.get("beard", "none")
	if beard == "none" or facing == Facing.UP:
		return
	var c = look.get("beard_color", look.get("hair", "4a3020"))
	var side := facing == Facing.LEFT
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


func _hat(look: Dictionary, facing: int) -> void:
	var hat: String = look.get("hat", "none")
	if hat == "none":
		return
	var c = look.get("hat_color", "6b4a2a")
	var band = look.get("hat_band", darker(c, 0.35))
	var side := facing == Facing.LEFT
	match hat:
		"wide":
			rect(5, 1, 6, 3, c)
			rect(5, 3, 6, 1, band)
			rect(2, 4, 12, 1, c)
			rect(3, 5, 10, 0, c)
		"campaign":
			# The pinched "Montana peak" of the ranger hat.
			rect(7, 0, 2, 1, c)
			rect(6, 1, 4, 1, c)
			rect(5, 2, 6, 2, c)
			rect(5, 3, 6, 1, band)
			rect(2, 4, 12, 1, c)
		"fedora":
			rect(5, 2, 6, 2, c)
			px(7, 1, c)
			px(8, 1, c)
			rect(5, 3, 6, 1, band)
			rect(3 if not side else 2, 4, 10 if not side else 11, 1, c)
		"bowler":
			rect(6, 1, 4, 1, c)
			rect(5, 2, 6, 2, c)
			rect(4, 4, 8, 1, c)
		"top":
			rect(6, 0, 4, 4, c)
			rect(6, 3, 4, 1, band)
			rect(4, 4, 8, 1, c)
		"cap":
			rect(5, 3, 6, 2, c)
			if facing == Facing.DOWN:
				rect(5, 5, 6, 1, darker(c, 0.2))
			elif side:
				rect(2, 5, 4, 1, darker(c, 0.2))
		"painter_cap":
			rect(5, 3, 6, 2, c)
			if facing == Facing.DOWN:
				rect(5, 5, 6, 1, darker(c, 0.15))
			elif side:
				rect(3, 5, 3, 1, darker(c, 0.15))
		"beanie":
			rect(5, 2, 6, 3, c)
			rect(5, 4, 6, 1, darker(c, 0.2))
			px(7, 1, lighter(c))
			px(8, 1, lighter(c))
		"bonnet":
			if facing == Facing.UP:
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
			if facing == Facing.UP:
				rect(5, 3, 6, 6, c)
				rect(7, 9, 2, 2, darker(c, 0.2))
			elif side:
				rect(5, 3, 6, 3, c)
				rect(8, 5, 3, 4, c)
				px(11, 8, darker(c, 0.2))
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
			rect(5, 2, 6, 3, c)
			rect(4, 4, 8, 1, c)
			px(6, 2, lighter(c, 0.3))


func _torso_details(look: Dictionary, facing: int) -> void:
	var style: String = look.get("top_style", "shirt")
	var top = look.get("top", "6b7d4a")
	var alt = look.get("top2", darker(top, 0.35))
	var side := facing == Facing.LEFT
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
			rect(4 if not side else 5, 17, 8 if not side else 6, 1, alt)
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
	var side := facing == Facing.LEFT
	match pack:
		"pack", "frame_pack", "haul_bag":
			var tall := 7 if pack == "pack" else 9
			var top_y := 11 if pack == "pack" else 9
			if facing == Facing.UP and not behind:
				rect(4, top_y, 8, tall, c)
				rect(4, top_y + 2, 8, 1, darker(c, 0.3))
				if pack == "frame_pack":
					rect(4, 8, 1, 12, "9a9a9a")
					rect(11, 8, 1, 12, "9a9a9a")
				if pack == "haul_bag":
					rect(6, top_y - 1, 4, 1, "d8c898")
			elif side and behind:
				rect(10, top_y, 3, tall, c)
				if pack == "frame_pack":
					rect(13, 8, 1, 12, "9a9a9a")
			elif facing == Facing.DOWN and behind:
				# Just the straps show from the front.
				pass
	if facing == Facing.DOWN and not behind:
		return


## Things carried in the hand or worn over the clothes.
func _carry(items: Array, facing: int, swing_r: int, swing_l: int, skin) -> void:
	var side := facing == Facing.LEFT
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

## 16×16 icons for story items, in the order of Looks.ITEMS.
func draw_items() -> Image:
	im = Image.create_empty(16 * Looks.ITEMS.size(), 16, false, Image.FORMAT_RGBA8)
	for i in Looks.ITEMS.size():
		ox = i * 16
		oy = 0
		match Looks.ITEMS[i]:
			"lamon_apple":
				rect(4, 5, 8, 8, "c83030")
				rect(5, 4, 6, 10, "c83030")
				rect(10, 6, 2, 6, "9a2020")
				rect(5, 6, 2, 2, "e87070")
				rect(7, 2, 1, 3, "5a3a1a")
				rect(8, 2, 3, 2, "5a9a30")
			"degnan_loaf":
				rect(2, 7, 12, 6, "b0783a")
				rect(3, 6, 10, 1, "b0783a")
				rect(3, 12, 10, 1, "8a5a2a")
				for x in [4, 7, 10]:
					rect(x, 7, 2, 1, "e0b070")
			"pine_nuts":
				for p in [Vector2i(3, 8), Vector2i(7, 5), Vector2i(11, 8), Vector2i(7, 10)]:
					rect(p.x, p.y, 2, 3, "8a5a3a")
					px(p.x, p.y + 3, "6a4028")
					px(p.x, p.y, "c89a6a")
			"model_a_axle":
				rect(2, 7, 12, 2, "6a6a70")
				rect(2, 7, 12, 1, "9a9aa0")
				rect(1, 5, 2, 6, "4a4a50")
				rect(13, 5, 2, 6, "4a4a50")
				px(6, 8, "8a5a3a")
				px(10, 7, "8a5a3a")
			"anderson_eyebolt":
				rect(7, 6, 2, 8, "7a7a80")
				rect(5, 2, 6, 5, "7a7a80")
				rect(6, 3, 4, 3, Color(0, 0, 0, 0))
				px(8, 13, "5a4a3a")
			"sourdough_starter":
				rect(4, 4, 8, 10, "c8c0b0")
				rect(4, 4, 8, 2, "7a5a3a")
				rect(5, 7, 6, 5, "f0e8d0")
		outline_frame16()
	return im


func outline_frame16() -> void:
	var edge: Array[Vector2i] = []
	for y in 16:
		for x in 16:
			if im.get_pixel(ox + x, y).a > 0.5:
				continue
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n := Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < 16 and n.y < 16 and im.get_pixel(ox + n.x, n.y).a > 0.5:
					edge.append(Vector2i(x, y))
					break
	for p in edge:
		im.set_pixel(ox + p.x, p.y, OUTLINE)


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
