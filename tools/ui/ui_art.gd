extends Node
## Draws the UI's art into assets/ui. The nine-slice panel is a warm wooden
## frame: a carved two-tone bevel lit from the upper left, wood grain along
## every rail, a brass line and brass corner fittings round a deep brown inset,
## with a soft drop shadow down and to the right. Its variants are a lighter
## banner and a plaque with planks inside. Also draws the beveled portrait
## frame, recessed inventory slots (plain and chosen), nested cards, active and
## idle tabs, the slim prompt pill, menu highlight bar, and bobbing next arrow.
##   godot --headless --path . res://tools/ui/ui_art.tscn
## The theme (assets/ui/theme.tres) stretches the panels with an 8 px margin.

const SIZE := 32
## The frame's own size. The columns and rows past it are the drop shadow.
const FRAME := 30
## Pixels in from the frame's edge where the inset starts.
const INSET := 6
## The nine-slice margin the theme keeps unstretched.
const STRETCH_MARGIN := 8

const OUTLINE := "150d07"
const OUTLINE_LIT := "2e1d0f"
const BEVEL_LIT := "e2b372"
const BEVEL_MID := "b5814a"
const BEVEL_SHADE := "774a28"
const BODY_LIT := "a36e3e"
const BODY_MID := "815331"
const BODY_SHADE := "57381f"
const LIP_LIT := "634125"
const LIP_SHADE := "36210f"
const BRASS_HI := "fae49e"
const BRASS_LIT := "ecca80"
const BRASS_MID := "d4a852"
const BRASS_SHADE := "966e31"
const INSET_SHADE := "120b07"
const INSET_LIGHT := "4d3624"
const SHADOW := Color(0.04, 0.02, 0.01)
const STUD := {"o": "241509", "h": "fff0ba", "b": "ddb45c", "s": "8a662b"}
const PLANK_A := "4c311a"
const PLANK_B := "402816"
const PLANK_TOP := "624024"
const PLANK_SEAM := "23150b"


func _ready() -> void:
	var panel := _blank()
	_frame(panel, Color("2e1f14"), Color("231a14"), false)
	_shadow(panel)
	_save(panel, "panel")
	# the same panel with a lighter interior, for banners over busy ground
	var banner := _blank()
	_frame(banner, Color("463120"), Color("37281b"), false)
	_shadow(banner)
	_save(banner, "panel_banner")
	# the clock and place-name plaques: wooden planks inside the same frame
	var plaque := _blank()
	_frame(plaque, Color(PLANK_A), Color(PLANK_B), true)
	_shadow(plaque)
	_save(plaque, "plaque")
	var tag := Image.create_empty(12, 12, false, Image.FORMAT_RGBA8)
	_tag(tag)
	_save(tag, "tag")
	var tab_idle := Image.create_empty(12, 12, false, Image.FORMAT_RGBA8)
	_tab_idle(tab_idle)
	_save(tab_idle, "tab_idle")
	var portrait := Image.create_empty(24, 24, false, Image.FORMAT_RGBA8)
	_portrait_frame(portrait)
	_save(portrait, "portrait_frame")
	var slot := Image.create_empty(20, 20, false, Image.FORMAT_RGBA8)
	_slot(slot, false)
	_save(slot, "slot")
	var slot_chosen := Image.create_empty(20, 20, false, Image.FORMAT_RGBA8)
	_slot(slot_chosen, true)
	_save(slot_chosen, "slot_chosen")
	var card := Image.create_empty(20, 20, false, Image.FORMAT_RGBA8)
	_card(card)
	_save(card, "card")
	var pill := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	_prompt_pill(pill)
	_save(pill, "prompt_pill")
	var select := Image.create_empty(10, 9, false, Image.FORMAT_RGBA8)
	_select(select)
	_save(select, "select")
	var next := Image.create_empty(9, 6, false, Image.FORMAT_RGBA8)
	_next(next)
	_save(next, "next")
	print("ui art painted")
	get_tree().quit()


func _blank() -> Image:
	return Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)


func _save(im: Image, name: String) -> void:
	var path := ProjectSettings.globalize_path("res://assets/ui/%s.png" % name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	im.save_png(path)


## The frame: outline, bevel, wood body, brass line and the inset. The top-left
## half of each ring is lit and the bottom-right half sits in shade.
func _frame(im: Image, top: Color, bottom: Color, planks: bool) -> void:
	var last := FRAME - 1
	for y in FRAME:
		for x in FRAME:
			var cx := mini(x, last - x)
			var cy := mini(y, last - y)
			var r := mini(cx, cy)
			if cx + cy <= 1:
				continue # the chamfered corner sits outside the frame
			# t runs from 0 at the lit upper-left corner to 1 at the shaded lower-right
			var t := float(x + y) / float(2 * last)
			var lit := t < 0.4
			var shade := t > 0.6
			var color := Color(0, 0, 0, 0)
			match r:
				0:
					color = Color(OUTLINE_LIT if t < 0.45 else OUTLINE)
				1:
					color = Color(BEVEL_LIT if lit else (BEVEL_SHADE if shade else BEVEL_MID))
					if cx == 2 and cy == 1 or cx == 1 and cy == 2:
						color = color.lightened(0.08) if lit else color.darkened(0.08)
				2:
					color = Color(BODY_LIT if lit else (BODY_SHADE if shade else BODY_MID))
					# wood grain along both horizontal and vertical rails
					if cy < cx and (x * 7 + 3) % 17 < 3:
						color = color.darkened(0.14)
					elif cx < cy and (y * 11 + 5) % 17 < 3:
						color = color.darkened(0.14)
				3:
					color = Color(LIP_LIT if lit else LIP_SHADE)
				4:
					color = Color(BRASS_HI if t < 0.18 else (BRASS_LIT if lit else (BRASS_SHADE if shade else BRASS_MID)))
				5:
					# the inset's edge: a dark trench on the lit side, a warm catch on the other
					color = Color(INSET_SHADE if lit else (INSET_LIGHT if shade else BODY_SHADE))
				_:
					color = _inside(x, y, top, bottom, planks)
			im.set_pixel(x, y, color)
	_studs(im)


## One pixel of the inset: a subtle recessed bevel inside the 8 px unstretched
## margin over a flat fill (test_panel_stretch checks that [8..24, 8..24] is
## one color so no band stretches across the text), or wooden planks.
func _inside(x: int, y: int, top: Color, bottom: Color, planks: bool) -> Color:
	if not planks:
		# Keep the entire [8..24, 8..24] stretched center strictly flat bottom.
		if x < STRETCH_MARGIN or y < STRETCH_MARGIN:
			if y == INSET or x == INSET:
				return bottom.darkened(0.28)
			return top if y < STRETCH_MARGIN else bottom.darkened(0.1)
		if x >= FRAME - 2 or y >= FRAME - 2:
			return bottom.lightened(0.07)
		return bottom
	var row := y - INSET
	var course := row / 6
	if row % 6 == 0:
		return Color(PLANK_SEAM)
	if row % 6 == 1:
		return Color(PLANK_TOP)
	var base := Color(PLANK_A if course % 2 == 0 else PLANK_B)
	# Subtle horizontal wood grain streaks on the planks
	if (x * 5 + course * 13) % 19 < 2:
		base = base.darkened(0.12)
	elif (x * 9 + course * 7) % 23 == 0:
		base = base.lightened(0.08)
	return base


## Brass corner studs with diagonal clasp accents in the four corners.
func _studs(im: Image) -> void:
	var pattern := [
		["o", "h", "o"],
		["h", "b", "s"],
		["o", "s", "o"],
	]
	for origin: Vector2i in [Vector2i(1, 1), Vector2i(FRAME - 4, 1), Vector2i(1, FRAME - 4), Vector2i(FRAME - 4, FRAME - 4)]:
		for dy in 3:
			for dx in 3:
				im.set_pixel(origin.x + dx, origin.y + dy, Color(STUD[pattern[dy][dx]]))
	# tiny inner brass corner bracket catches at ring 4
	for p: Vector2i in [Vector2i(4, 4), Vector2i(FRAME - 5, 4), Vector2i(4, FRAME - 5), Vector2i(FRAME - 5, FRAME - 5)]:
		im.set_pixelv(p, Color(BRASS_HI))


## A soft drop shadow: two steps down and to the right of the frame.
func _shadow(im: Image) -> void:
	for y in range(2, SIZE):
		for x in range(2, SIZE):
			if x < FRAME and y < FRAME:
				continue
			var d := maxi(x, y) - (FRAME - 1)
			var alpha := 0.52 if d == 1 else 0.22
			im.set_pixel(x, y, Color(SHADOW.r, SHADOW.g, SHADOW.b, alpha))


## A small brass-edged active tab plate. Its top row is the lit brass edge and
## its bottom row the warm gold accent that connects to the page below.
func _tag(im: Image) -> void:
	for y in 12:
		for x in 12:
			if (x == 0 or x == 11) and y == 0:
				continue # chamfer top corners slightly
			var color := Color("5b3821")
			if x == 0 or x == 11:
				color = Color(OUTLINE)
			elif y == 0:
				color = Color(BRASS_HI if x < 9 else BRASS_LIT)
			elif y == 11:
				color = Color(BRASS_MID)
			elif y == 1:
				color = Color("865a34")
			elif x == 1:
				color = Color("764d2c")
			elif x == 10:
				color = Color("432917")
			elif y == 10:
				color = Color("462b19")
			im.set_pixel(x, y, color)


## A recessed darker wood tab for inactive book tabs, tucked behind the rule.
func _tab_idle(im: Image) -> void:
	for y in 12:
		for x in 12:
			if (x == 0 or x == 11) and y == 0:
				continue
			var color := Color("332116")
			if x == 0 or x == 11:
				color = Color(OUTLINE)
			elif y == 0:
				color = Color("7a5837")
			elif y == 1:
				color = Color("48301f")
			elif y == 11:
				color = Color("1b110b")
			elif x == 10:
				color = Color("261810")
			im.set_pixel(x, y, color)


## A carved cedar-and-brass portrait frame (24x24, 6 px nine-slice margin)
## with a warm matte backdrop inside, so portraits read as framed paintings.
func _portrait_frame(im: Image) -> void:
	var n := 24
	var last := n - 1
	for y in n:
		for x in n:
			var cx := mini(x, last - x)
			var cy := mini(y, last - y)
			var r := mini(cx, cy)
			if cx + cy == 0:
				continue # 1px chamfered outer corners
			var t := float(x + y) / float(2 * last)
			var lit := t < 0.48
			var color := Color("5c4634")
			match r:
				0:
					color = Color(OUTLINE)
				1:
					color = Color(BEVEL_LIT if lit else BEVEL_SHADE)
					if (x == 1 or x == last - 1) and (y == 1 or y == last - 1):
						color = Color(BRASS_HI if lit else BRASS_MID)
				2:
					color = Color(BRASS_LIT if lit else BRASS_SHADE)
				3:
					# inner recessed shadow top/left, faint warm edge bottom/right
					color = Color("3a291d") if (x == 3 or y == 3) else Color("6e5540")
				_:
					# soft vertical vignette inside the warm portrait matte
					var v := float(y - 4) / float(n - 8)
					color = Color("6a523e").lerp(Color("4e3a2b"), v)
			im.set_pixel(x, y, color)


## A recessed wooden/parchment inventory or collection slot (20x20, 4 px margin).
## Chosen slots get a warm glowing gold-and-amber rim instead of harsh white.
func _slot(im: Image, chosen: bool) -> void:
	var n := 20
	var last := n - 1
	for y in n:
		for x in n:
			var cx := mini(x, last - x)
			var cy := mini(y, last - y)
			var r := mini(cx, cy)
			var color: Color
			if not chosen:
				if cx + cy == 0:
					continue
				match r:
					0:
						color = Color("2a1b14")
					1:
						# recessed well: darker upper-left lip, warm sunlit lower-right
						color = Color("6b4b2d") if (x == 1 or y == 1) else Color("cfaf76")
					2:
						color = Color("907346") if (x == 2 or y == 2) else Color("b89a64")
					_:
						color = Color("a98c5a")
			else:
				if cx + cy == 0:
					continue
				match r:
					0:
						color = Color("2a1b14")
					1:
						# luminous warm gold rim with bright corner glints
						if cx <= 2 and cy <= 2:
							color = Color("fff3c4")
						elif x == 1 or y == 1:
							color = Color("ffd878")
						else:
							color = Color("e09a36")
					2:
						color = Color("b86f24") if (x == 2 or y == 2) else Color("f2cb74")
					_:
						color = Color("d8bc86")
			im.set_pixel(x, y, color)


## A subtle recessed dark-wood nested card (20x20, 5 px margin) for quest
## entries, shop/campfire details, and pause/settings side cards.
func _card(im: Image) -> void:
	var n := 20
	var last := n - 1
	for y in n:
		for x in n:
			var cx := mini(x, last - x)
			var cy := mini(y, last - y)
			var r := mini(cx, cy)
			if cx + cy == 0:
				continue
			var color := Color("1a120d")
			match r:
				0:
					color = Color("130c08")
				1:
					if cx == 1 and cy == 1:
						color = Color("b68c48") # tiny brass corner pin
					elif x == 1 or y == 1:
						color = Color("4a3322")
					else:
						color = Color("6b4d32")
				2:
					color = Color("140d09") if (x == 2 or y == 2) else Color("2b1e15")
				_:
					color = Color("1b130e")
			im.set_pixel(x, y, color)


## A crisp pixel-art beveled pill (16x16, 4 px margin) for the world interact
## prompt and floating HUD notices.
func _prompt_pill(im: Image) -> void:
	var n := 16
	var last := n - 1
	for y in n:
		for x in n:
			var cx := mini(x, last - x)
			var cy := mini(y, last - y)
			var r := mini(cx, cy)
			if cx + cy <= 1:
				continue
			var lit := (x + y) < last
			var color := Color(0.13, 0.085, 0.06, 0.9)
			match r:
				0:
					color = Color("1a1009")
				1:
					color = Color("c99d58" if lit else "6d4c2a")
				2:
					color = Color("3a2618" if lit else "1a110b")
			im.set_pixel(x, y, color)


## A translucent gold bar for the chosen menu row, with a bright left accent.
func _select(im: Image) -> void:
	for y in 9:
		for x in 10:
			var color := Color(0.88, 0.72, 0.38, 0.22)
			if x == 0:
				color = Color(0.98, 0.89, 0.62, 0.95)
			elif x == 1:
				color = Color(0.92, 0.76, 0.42, 0.55)
			elif y == 0:
				color = Color(0.96, 0.85, 0.56, 0.48)
			elif y == 8:
				color = Color(0.55, 0.38, 0.16, 0.45)
			im.set_pixel(x, y, color)


## A small downward arrow with a dark outline, for "more to come" in dialogue.
func _next(im: Image) -> void:
	var mask := ["#######", ".#####.", "..###..", "...#..."]
	var fill := ["fae49e", "f1cf6a", "d8a63b", "ad7a22"]
	for y in 6:
		for x in 9:
			if _arrow_filled(mask, x - 1, y - 1):
				var row := y - 1
				im.set_pixel(x, y, Color(fill[row]))
			elif _arrow_filled(mask, x - 1, y - 2) or _arrow_filled(mask, x - 1, y) \
					or _arrow_filled(mask, x - 2, y - 1) or _arrow_filled(mask, x, y - 1):
				im.set_pixel(x, y, Color(OUTLINE_LIT))


func _arrow_filled(mask: Array, x: int, y: int) -> bool:
	if y < 0 or y >= mask.size() or x < 0 or x >= mask[0].length():
		return false
	return mask[y][x] == "#"
