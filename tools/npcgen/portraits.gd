extends SceneTree
## Paints a 40x40 head-and-shoulders portrait of everyone in the cast, from the
## same look data as their walking sprites (tools/npcgen/looks.gd), for the
## conversation box. Each one is saved under the name of the person's sprite
## sheet, so assets/sprites/npcs/wren_alvarez.png gets
## assets/sprites/portraits/wren_alvarez.png, and the player gets player.png.
## Each file is a strip of four 40x40 faces, one per mood in MOODS order
## (neutral, happy, sad, surprised); the conversation box picks one per line.
## Also writes docs/cast_portraits.png (every neutral face side by side) and
## docs/portrait_moods.png (a few people in all four moods).
##
##   godot --headless --path . -s res://tools/npcgen/portraits.gd
##   godot --headless --path . --import

const Looks = preload("res://tools/npcgen/looks.gd")

## Faces are laid out on a 40-dot grid (S) and painted at K pixels a dot,
## so the round shapes (head, hair, hats, shoulders) are shaded at the full
## 80 pixels the conversation box shows, while eyes, brows and mouths keep
## their crisp two-pixel dots.
const S := 40
const K := 2
const R := S * K
const OUT_DIR := "res://assets/sprites/portraits/"
const SHEET_PNG := "res://docs/cast_portraits.png"
const OUTLINE := Color("2a1f1a")
const BLUSH := Color("e07a70")
const MOUTH := Color("9a4a44")
const GLINT := Color("fbf6ea")
const EYE_WHITE := Color("f4eee2")
## Must match Portraits.MOODS.
const MOODS := ["neutral", "happy", "sad", "surprised"]

var im: Image
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var ids: Array = Looks.LOOKS.keys()
	ids.sort()
	var all: Array[Image] = []
	var strips: Dictionary = {}
	for id: String in ids:
		var strip := _strip(Looks.LOOKS[id], id)
		strip.save_png(OUT_DIR + id + ".png")
		all.append(strip.get_region(Rect2i(0, 0, R, R)))
		strips[id] = strip
	var player := _strip(Looks.PLAYER, "player")
	player.save_png(OUT_DIR + "player.png")
	all.append(player.get_region(Rect2i(0, 0, R, R)))
	_save_sheet(all)
	_save_moods([strips.galen_clark, strips.wren_alvarez, strips.maria_lebrado, strips.warren_harding])
	print("%d portraits written to %s. Run godot --headless --path . --import next." % [all.size(), OUT_DIR])
	quit()


## Every mood of one person, side by side.
func _strip(look: Dictionary, id: String) -> Image:
	var strip := Image.create_empty(R * MOODS.size(), R, false, Image.FORMAT_RGBA8)
	for i in MOODS.size():
		strip.blit_rect(paint(look, id, MOODS[i]), Rect2i(0, 0, R, R), Vector2i(i * R, 0))
	return strip


func _save_moods(strips: Array) -> void:
	var sheet := Image.create_empty(R * MOODS.size() + 8, strips.size() * (R + 4) + 4, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("e8dfcc"))
	for r in strips.size():
		for i in MOODS.size():
			sheet.fill_rect(Rect2i(4 + i * R, 4 + r * (R + 4), R - 2, R), Color("6a5440"))
		sheet.blend_rect(strips[r], Rect2i(0, 0, R * MOODS.size(), R), Vector2i(4, 4 + r * (R + 4)))
	sheet.resize(sheet.get_width() * 2, sheet.get_height() * 2, Image.INTERPOLATE_NEAREST)
	sheet.save_png("res://docs/portrait_moods.png")


func _save_sheet(all: Array[Image]) -> void:
	var cols := 10
	var rows := ceili(all.size() / float(cols))
	var sheet := Image.create_empty(cols * (R + 4) + 4, rows * (R + 4) + 4, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("e8dfcc"))
	for i in all.size():
		var at := Vector2i(4 + (i % cols) * (R + 4), 4 + (i / cols) * (R + 4))
		sheet.fill_rect(Rect2i(at, Vector2i(R, R)), Color("6a5440"))
		sheet.blend_rect(all[i], Rect2i(0, 0, R, R), at)
	sheet.resize(sheet.get_width() * 2, sheet.get_height() * 2, Image.INTERPOLATE_NEAREST)
	sheet.save_png(SHEET_PNG)


# ------------------------------------------------------------ helpers

func col(v) -> Color:
	return v if v is Color else Color(str(v))


func px(x: int, y: int, c) -> void:
	if x >= 0 and y >= 0 and x < S and y < S:
		im.fill_rect(Rect2i(x * K, y * K, K, K), col(c))


## The color at dot ([param x], [param y]).
func at(x: int, y: int) -> Color:
	return im.get_pixel(x * K, y * K)


func rect(x: int, y: int, w: int, h: int, c) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			px(xx, yy, c)


func darker(c, k := 0.22) -> Color:
	return col(c).darkened(k)


func lighter(c, k := 0.18) -> Color:
	return col(c).lightened(k)


## An ellipse lit from the upper left: a light rim up there, shade on the
## lower right. [param from_y] clips off everything above that row.
func shaded(cx: float, cy: float, rx: float, ry: float, c, from_y := -100, to_y := 100) -> void:
	var base := col(c)
	# walked in pixels, not dots, so curves and shading are as fine as the
	# picture is
	for y in range(maxi(floori((cy - ry) * K), from_y * K), mini(ceili((cy + ry) * K) + 1, (to_y + 1) * K)):
		for x in range(floori((cx - rx) * K), ceili((cx + rx) * K) + 1):
			var dx := ((x + 0.5) / K - cx) / rx
			var dy := ((y + 0.5) / K - cy) / ry
			var d := dx * dx + dy * dy
			if d > 1.0:
				continue
			var lit := -dx * 0.7 - dy * 0.6
			var shade := base
			# five tones: a deep shadow at the far edge, the shadow with a
			# checkered (dithered) step into it, the base, a light, and a
			# small shine where the light falls straightest
			if lit < -0.78:
				shade = darker(base, 0.32)
			elif lit < -0.42:
				shade = darker(base, 0.18)
			elif lit < -0.28 and (x + y) % 2 == 0:
				shade = darker(base, 0.18)
			elif lit > 0.82 and d > 0.45:
				shade = lighter(base, 0.24)
			elif lit > 0.5 and d > 0.3:
				shade = lighter(base, 0.12)
			if x >= 0 and y >= 0 and x < R and y < R:
				im.set_pixel(x, y, shade)


## Light from the upper left on the whole silhouette: a lit edge where the
## figure meets the air above or to the left, and shadow where it meets it
## below or to the right, so hair, hats and shirts read as round instead of
## flat fills. Only the outer edge is touched, never eyes or mouths.
func _rim_light() -> void:
	_form_shade()
	var src := im.duplicate() as Image
	for y in R:
		for x in R:
			var c := src.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var air_up := y < K or src.get_pixel(x, y - K).a < 0.5
			var air_left := x < K or src.get_pixel(x - K, y).a < 0.5
			var air_down := y >= R - K or src.get_pixel(x, y + K).a < 0.5
			var air_right := x >= R - K or src.get_pixel(x + K, y).a < 0.5
			if (air_up or air_left) and not (air_down or air_right):
				im.set_pixel(x, y, c.lightened(0.16))
			elif (air_down or air_right) and not (air_up or air_left) and y < R - 1:
				im.set_pixel(x, y, c.darkened(0.2))


## Rounds the wide flat fills (shirts, hat crowns, hair): along each row, a
## run of one color darkens over its far third, through a dithered step, and
## lightens a touch at its near end.
func _form_shade() -> void:
	var src := im.duplicate() as Image
	for y in R:
		var x := 0
		while x < R:
			var c := src.get_pixel(x, y)
			var end := x + 1
			while end < R and src.get_pixel(end, y) == c:
				end += 1
			var run := end - x
			if c.a > 0.5 and run >= 12:
				for i in run:
					var t := float(i) / run
					var at := x + i
					if t > 0.72 or (t > 0.62 and (at + y) % 2 == 0):
						im.set_pixel(at, y, c.darkened(0.14))
					elif t < 0.12:
						im.set_pixel(at, y, c.lightened(0.07))
			x = end


func outline() -> void:
	var edge: Array[Vector2i] = []
	for y in R:
		for x in R:
			if im.get_pixel(x, y).a > 0.5:
				continue
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n := Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < R and n.y < R and im.get_pixel(n.x, n.y).a > 0.5:
					edge.append(Vector2i(x, y))
					break
	for p in edge:
		im.set_pixelv(p, OUTLINE)


# ------------------------------------------------------------ the portrait

func paint(look: Dictionary, id: String, mood := "neutral") -> Image:
	im = Image.create_empty(R, R, false, Image.FORMAT_RGBA8)
	_rng.seed = hash(id)
	var skin := col(look.get("skin", Looks.SKIN_FAIR))
	var hair := col(look.get("hair", "4a3020"))
	var style: String = look.get("hair_style", "short")
	var hat: String = look.get("hat", "")
	if style == "long" or style == "braid":
		_hair_back(hair, style)
	_torso(look)
	_neck(skin)
	if look.has("bandana"):
		_bandana(col(look.bandana))
	_head(skin)
	_face(look, skin, mood)
	_hair_front(hair, style, hat != "" and hat not in ["headband", "scarf", "bonnet"])
	if look.get("beard", "none") != "none":
		_beard(look.beard, col(look.get("beard_color", hair)))
	if hat != "":
		_hat(hat, col(look.get("hat_color", "5a4a3a")), col(look.get("hat_band", darker(look.get("hat_color", "5a4a3a"), 0.4))), hair)
	if look.get("glasses", false):
		_glasses()
	_mouth(mood, skin)
	_rim_light()
	# a rim as heavy as one dot (two pixels), like every sprite in the game
	for i in K:
		outline()
	return im


## Long hair or a braid, behind the shoulders.
func _hair_back(hair: Color, style: String) -> void:
	if style == "long":
		shaded(20, 22, 11, 14, hair, 10, 37)
	else:
		shaded(20, 18, 10, 10, hair)
		# the braid over the right shoulder
		for i in 5:
			shaded(27 + (i % 2), 26 + i * 3, 2.2, 2.0, hair if i % 2 == 0 else darker(hair, 0.15))


func _torso(look: Dictionary) -> void:
	var top := col(look.get("top", "6a6a6a"))
	var top2 := col(look.get("top2", darker(top, 0.3)))
	var top_style: String = look.get("top_style", "shirt")
	# shoulders: a wide rounded block from y 30 down off the bottom edge
	for y in range(29, S):
		var inset := maxi(0, 3 - (y - 29))
		for x in range(5 + inset, 35 - inset):
			var c := top
			if x > 28 - inset:
				c = darker(top, 0.18)
			elif x < 9 and y < 33:
				c = lighter(top, 0.1)
			px(x, y, c)
	match top_style:
		"plaid":
			for y in range(29, S):
				for x in range(5, 35):
					if at(x, y).a > 0.5 and (x % 4 == 0 or y % 4 == 1):
						px(x, y, top2 if (x % 4 == 0) != (y % 4 == 1) else darker(top2, 0.25))
		"stripes":
			for y in range(30, S, 3):
				for x in range(5, 35):
					if at(x, y).a > 0.5:
						px(x, y, top2)
		"suspenders":
			rect(12, 29, 2, 11, top2)
			rect(26, 29, 2, 11, top2)
		"vest":
			var sleeve := col(look.get("sleeve", "e0d8c8"))
			rect(5, 31, 7, 9, sleeve)
			rect(28, 31, 7, 9, darker(sleeve, 0.15))
			rect(12, 29, 16, 11, top2)
			rect(19, 30, 2, 10, darker(top2, 0.3))
			px(17, 34, GLINT)
			px(17, 37, GLINT)
		"jacket", "coat":
			# lapels in a V, the shirt showing between
			for i in 7:
				rect(15 + i / 2, 29 + i, 1, 1, top2)
				rect(24 - i / 2, 29 + i, 1, 1, top2)
			rect(18, 29, 4, 6, look.get("collar", "e8e0d0") if top_style == "coat" else top2)
			rect(17, 29, 1, 8, darker(top, 0.3))
			rect(22, 29, 1, 8, darker(top, 0.3))
		"shawl":
			for y in range(29, S):
				for x in range(5, 35):
					if at(x, y).a > 0.5 and absi(x - 20) > (y - 28) * 1.2:
						px(x, y, top2 if (x + y) % 4 else darker(top2, 0.2))
		"blouse":
			rect(16, 29, 8, 2, top2)
			px(15, 30, top2)
			px(24, 30, top2)
			for x in [17, 19, 21, 23]:
				px(x, 31, darker(top2, 0.15))
		"sweater":
			rect(15, 29, 10, 2, top2)
			for x in range(6, 34, 2):
				px(x, 39, darker(top, 0.25))
		_:
			# a shirt collar
			var collar := col(look.get("collar", lighter(top, 0.25)))
			for i in 3:
				rect(16 + i, 29 + i, 1, 1, collar)
				rect(23 - i, 29 + i, 1, 1, collar)
			rect(19, 32, 2, 8, darker(top, 0.15))
	if look.has("apron"):
		var apron := col(look.apron)
		rect(14, 35, 12, 5, apron)
		rect(14, 35, 12, 1, darker(apron, 0.1))
	if look.get("badge", false):
		var gold := col(look.badge) if look.badge is String else Color("e0c060")
		rect(10, 33, 2, 2, gold)
		px(10, 33, GLINT)


func _neck(skin: Color) -> void:
	rect(17, 25, 6, 6, darker(skin, 0.15))
	rect(17, 25, 2, 4, darker(skin, 0.08))


func _bandana(c: Color) -> void:
	for i in 4:
		rect(16 + i, 28 + i, 8 - i * 2, 1, c if i < 3 else darker(c, 0.2))
	rect(15, 28, 10, 1, darker(c, 0.15))


func _head(skin: Color) -> void:
	# ears, then the face
	shaded(11.5, 19, 1.8, 2.5, skin)
	shaded(28.5, 19, 1.8, 2.5, darker(skin, 0.12))
	shaded(20, 17.5, 8.6, 10, skin)
	# a softer jaw
	px(12, 24, Color(0, 0, 0, 0))
	px(27, 24, Color(0, 0, 0, 0))


func _face(look: Dictionary, skin: Color, mood: String) -> void:
	var eyes := col(look.get("eyes", "2a1f1a"))
	var brow := darker(col(look.get("hair", "4a3020")), 0.15)
	if look.get("hair_style", "") == "bald" or col(look.get("hair", "4a3020")).get_luminance() > 0.6:
		brow = darker(skin, 0.35)
	# brows: level, raised (happy, surprised), or tilted up in the middle (sad)
	match mood:
		"happy", "surprised":
			rect(15, 15, 3, 1, brow)
			rect(22, 15, 3, 1, brow)
		"sad":
			rect(15, 16, 2, 1, brow)
			px(17, 15, brow)
			px(22, 15, brow)
			rect(23, 16, 2, 1, brow)
		_:
			rect(15, 16, 3, 1, brow)
			rect(22, 16, 3, 1, brow)
	# eyes: a white, the iris, a glint; wide when surprised, cast down when sad,
	# and creased into happy arcs
	for x0 in [15, 22]:
		match mood:
			"happy":
				rect(x0, 19, 3, 1, eyes)
				px(x0 + 1, 18, eyes)
			"surprised":
				rect(x0, 17, 3, 3, EYE_WHITE)
				rect(x0 + 1, 18, 1, 2, eyes)
				px(x0 + 1, 18, GLINT)
			"sad":
				rect(x0, 18, 3, 2, EYE_WHITE)
				rect(x0 + 1, 19, 2, 1, eyes)
				rect(x0, 18, 3, 1, darker(skin, 0.15))
			_:
				rect(x0, 18, 3, 2, EYE_WHITE)
				rect(x0 + 1, 18, 2, 2, eyes)
				px(x0 + 1, 18, GLINT)
	# nose and its shadow
	px(20, 20, darker(skin, 0.12))
	px(20, 21, darker(skin, 0.2))
	px(21, 21, darker(skin, 0.28))
	# blush, warmer when happy; the mouth comes last (see _mouth)
	var blush := BLUSH.lerp(skin, 0.15 if mood == "happy" else 0.4)
	px(14, 22, blush)
	px(26, 22, blush)
	if mood == "happy":
		px(13, 22, blush.lerp(skin, 0.5))
		px(27, 22, blush.lerp(skin, 0.5))


## The mouth, drawn over any beard so the mood always shows.
func _mouth(mood: String, skin: Color) -> void:
	match mood:
		"happy":
			rect(18, 24, 4, 1, MOUTH)
			px(17, 23, MOUTH)
			px(22, 23, MOUTH)
			rect(18, 23, 4, 1, Color("f4eee2"))
		"sad":
			rect(18, 23, 4, 1, MOUTH)
			px(17, 24, MOUTH)
			px(22, 24, MOUTH)
		"surprised":
			rect(19, 23, 2, 2, darker(MOUTH, 0.35))
			px(18, 23, MOUTH)
			px(21, 23, MOUTH)
		_:
			rect(18, 23, 4, 1, MOUTH)
			px(17, 22, darker(skin, 0.18))
			px(22, 22, darker(skin, 0.18))


func _hair_front(hair: Color, style: String, under_hat: bool) -> void:
	match style:
		"bald":
			# a fringe round the sides, a shine on top
			rect(11, 15, 2, 5, hair)
			rect(27, 15, 2, 5, darker(hair, 0.15))
			if not under_hat:
				px(16, 10, lighter(Color("ffffff"), 0.0).lerp(hair, 0.3))
			return
		"wild":
			for i in 9:
				var x: float = 10 + i * 2.5
				shaded(x, 9 + _rng.randf_range(-1.5, 1.5), 3.2, 3.6, hair)
			shaded(20, 11, 10, 5, hair, -100, 14)
			rect(11, 12, 2, 8, hair)
			rect(27, 12, 2, 8, darker(hair, 0.15))
			return
	# the cap of hair over the forehead, with a side part
	shaded(20, 13, 9.6, 6.5, hair, -100, 14)
	for x in range(12, 29):
		var y := 14 + (1 if x < 18 else 0) + (1 if x > 25 else 0)
		px(x, y, hair if x != 18 else darker(hair, 0.2))
	rect(11, 13, 2, 6, hair)
	rect(27, 13, 2, 6, darker(hair, 0.15))
	px(15, 10, lighter(hair, 0.2))
	px(16, 9, lighter(hair, 0.2))
	match style:
		"long":
			rect(10, 17, 3, 12, hair)
			rect(27, 17, 3, 12, darker(hair, 0.15))
		"bun":
			if not under_hat:
				shaded(20, 5.5, 4, 3.4, hair)
				px(19, 4, lighter(hair, 0.2))


func _beard(kind: String, c: Color) -> void:
	match kind:
		"mustache":
			rect(17, 22, 6, 1, c)
			px(16, 23, c)
			px(23, 23, darker(c, 0.15))
		"goatee":
			rect(17, 22, 6, 1, c)
			rect(18, 24, 4, 3, c)
			px(19, 27, darker(c, 0.15))
		"short", "long":
			var bottom := 28 if kind == "short" else 36
			for y in range(19, bottom):
				var half: float = 9.0 if y < 25 else 9 - (y - 24) * (1 if kind == "short" else 0.5)
				for x in range(int(20 - half), int(20 + half)):
					if y < 22 and absi(x - 20) < 7:
						continue # cheeks stay bare above the mustache
					var strand := c if x < 24 else darker(c, 0.15)
					if (x * 2 + y) % 5 == 0:
						strand = darker(strand, 0.18)
					px(x, y, strand)
			rect(17, 22, 6, 1, darker(c, 0.1))
			if kind == "long":
				for y in range(27, 36, 3):
					px(18 + y % 4, y, lighter(c, 0.15))


func _hat(kind: String, c: Color, band: Color, _hair: Color) -> void:
	match kind:
		"wide", "campaign":
			shaded(20, 12, 15, 2.6, c)
			rect(5, 12, 30, 1, darker(c, 0.25))
			shaded(20, 7, 7.5, 5, c, -100, 11)
			rect(13, 10, 14, 1, band)
			if kind == "campaign":
				# the Montana pinch
				px(20, 2, Color(0, 0, 0, 0))
				px(18, 3, darker(c, 0.3))
				px(22, 3, darker(c, 0.3))
				px(20, 4, darker(c, 0.3))
		"fedora":
			shaded(20, 12, 12, 2.2, c)
			shaded(20, 8, 7.5, 4.5, c, -100, 11)
			px(20, 4, darker(c, 0.3))
			px(20, 5, darker(c, 0.3))
			rect(13, 10, 14, 1, band)
		"bowler":
			shaded(20, 12, 10.5, 1.8, c)
			shaded(20, 9, 8, 6, c, -100, 11)
			rect(12, 11, 16, 1, band)
			px(16, 5, lighter(c, 0.3))
		"top":
			shaded(20, 12, 11, 1.8, c)
			rect(13, 1, 14, 11, c)
			rect(24, 1, 3, 11, darker(c, 0.15))
			rect(13, 9, 14, 2, band)
		"cap":
			shaded(20, 11, 9.6, 6, c, -100, 13)
			rect(13, 13, 14, 2, darker(c, 0.3))
			rect(12, 14, 16, 1, darker(c, 0.4))
			px(20, 5, darker(c, 0.2))
		"painter_cap":
			shaded(20, 11, 9.4, 5, c, -100, 13)
			rect(14, 12, 12, 2, darker(c, 0.2))
		"beanie":
			shaded(20, 10.5, 9.8, 7.5, c, -100, 14)
			for x in range(11, 30):
				px(x, 13, darker(c, 0.2) if x % 2 else c)
				px(x, 14, darker(c, 0.3) if x % 2 else darker(c, 0.1))
			shaded(20, 2.5, 2.2, 2, lighter(c, 0.1))
		"bonnet":
			for y in range(5, 26):
				var half: float = 11.5 if y > 9 else 11.5 - (9 - y) * 1.2
				for x in range(int(20 - half), int(20 + half)):
					var dx := absi(x - 20)
					if y > 11 and dx < 9:
						continue
					px(x, y, c if x < 26 else darker(c, 0.15))
			rect(12, 11, 16, 1, darker(c, 0.2))
			rect(18, 26, 4, 3, band)
		"scarf":
			shaded(20, 12, 10, 7.5, c, -100, 15)
			for x in range(11, 30):
				px(x, 15, darker(c, 0.2))
			rect(27, 15, 3, 4, darker(c, 0.15))
			for x in range(13, 28, 4):
				px(x, 11, lighter(c, 0.2))
		"headband":
			rect(11, 12, 18, 2, c)
			rect(11, 13, 18, 1, darker(c, 0.2))
			rect(28, 13, 2, 4, darker(c, 0.1))
		"helmet":
			shaded(20, 11, 10.5, 7.5, c, -100, 14)
			rect(10, 14, 20, 1, darker(c, 0.3))


func _glasses() -> void:
	for x0 in [14, 21]:
		rect(x0, 17, 5, 1, OUTLINE)
		rect(x0, 20, 5, 1, OUTLINE)
		px(x0, 18, OUTLINE)
		px(x0, 19, OUTLINE)
		px(x0 + 4, 18, OUTLINE)
		px(x0 + 4, 19, OUTLINE)
	rect(19, 18, 2, 1, OUTLINE)
