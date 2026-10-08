extends "res://tools/hubs/valley_art.gd"
## The larger buildings of the generated hubs, in the Ahwahnee's style: lodges
## of a few set widths (log walls with cut ends, a granite foot, mossy shingles,
## a cross gable, a stone chimney and a lamp by the door) and the Wawona Hotel
## (long, white, two stories, a veranda on each floor with lit columns and a
## balustrade, and a crisp green roof). Written to assets/sprites/hub_buildings/,
## each with a "_glow" picture of its lit windows. Every window is drawn as day
## glass, so nothing looks lit at noon; the glow comes up after dark.
##
## Every sprite is anchored at its bottom center. Hub_buildings.gd places them.
##   godot --headless --path . res://tools/mapgen/rebuild_buildings.tscn -- paint

const DIR_OUT := "res://assets/sprites/hub_buildings/"
const LODGE_WIDTHS := [48, 72, 104]
const HOTEL_WIDTHS := [96, 128]
const HOTEL_HEIGHT := 70
const DAY_GLASS := Color("56707f")
const GLINT := Color("e8f2f4")
const WARM_GLASS := Color("ffd27a")
const WHITE := ["8c8678", "aaa496", "c8c2b2", "dedacc", "eeeae0", "fbf8f0"]
const WHITE_SHADE := Color("7e8594")
const HOTEL_ROOF := ["16281e", "223c2c", "30543c", "416e4e", "578a64", "76a682"]
const SHUTTER := Color("3a5a46")
const DECK := Color("bba78f")
const DECK_EDGE := Color("5e564c")
const CURTAIN := [Color("b5654a"), Color("c9965c"), Color("6f8a6a")]

## Set while the hotel is drawn: white clapboard, crisp shingles, white windows.
var hotel_mode := false
## Set while the hotel roof is drawn: green shingles with no moss.
var crisp_roof := false


func save_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR_OUT))
	for w: int in LODGE_WIDTHS:
		_save_pair(lodge(w), "lodge_%d" % w)
	for w: int in HOTEL_WIDTHS:
		_save_pair(wawona_hotel(w), "hotel_%d" % w)


func _save_pair(built: Array, sprite_name: String) -> void:
	built[0].save_png(ProjectSettings.globalize_path(DIR_OUT + sprite_name + ".png"))
	built[1].save_png(ProjectSettings.globalize_path(DIR_OUT + sprite_name + "_glow.png"))


# ---------------------------------------------------------------- roofs

## Hue-shifted shading: shadows drift toward blue, the lit tones toward gold.
static func _cool(c: Color) -> Color:
	var lum := c.get_luminance()
	if lum < 0.28:
		return c.lerp(Color("1d2a3c"), 0.25)
	if lum > 0.42:
		return c.lerp(Color("f2d27a"), 0.12)
	return c


func shingle_col(gx: int, gy: int, sd: int, lit: float) -> Color:
	if crisp_roof:
		return _cool(_crisp_shingle(gx, gy, sd, lit))
	return _cool(super(gx, gy, sd, lit))


## A green shingle roof with no moss: short tabs in staggered courses, each
## course shadowed along its lower edge and each tab lit on its left.
func _crisp_shingle(gx: int, gy: int, sd: int, lit: float) -> Color:
	var ch := 3
	var ci := gy / ch
	var inrow := gy % ch
	var off := (ci % 2) * 3
	var tab := (gx + off) / 6
	var n := K.hash2(tab, ci, sd)
	var t := 0.45 + n * 0.35 + lit
	var col := roof[clampi(roundi(t * 5.0), 0, roof.size() - 1)]
	if inrow == ch - 1:
		col = col.darkened(0.3)
	elif inrow == 0:
		col = col.lightened(0.08)
	if (gx + off) % 6 == 5:
		col = col.darkened(0.16)
	if K.hash2(gx, gy, sd + 2) > 0.95:
		col = col.lightened(0.1)
	return col


## The shingle roof, with a row of ridge caps along its top edge.
func shingle_roof(im: Image, x: int, y: int, w: int, h: int, sd: int, taper := 0.3) -> void:
	super(im, x, y, w, h, sd, taper)
	var inset := int((h - 1) * taper)
	var cx := x + inset
	while cx < x + w - inset - 2:
		K.px(im, cx, y, roof[5].lightened(0.3))
		K.px(im, cx + 1, y, roof[5].lightened(0.12))
		K.px(im, cx + 2, y, roof[3].darkened(0.1))
		cx += 4


## A deeper shadow under the rafters, on the wall below.
func eave(im: Image, x: int, y: int, w: int) -> void:
	super(im, x, y, w)
	shade(im, x, y + 10, w, 4, timber[0], 0.9, 0.0, 0.3)


## A stone chimney with black soot at the flue mouths and streaked down the stack.
func chimney(im: Image, x: int, top: int, h: int, sd: int) -> void:
	super(im, x, top, h, sd)
	var soot := Color(0.1, 0.085, 0.075)
	for k in 2:
		var fx := x + 3 + k * 5
		K.hline(im, fx, top - 5, 3, soot)
	for yy in range(top, mini(top + h, top + 10)):
		for xx in range(x + 1, x + 11):
			var s := K.hash2(xx, yy, sd + 60)
			if s > 0.5 - float(yy - top) * 0.05:
				K.px(im, xx, yy, Color(0.1, 0.085, 0.075, 0.4))


# ---------------------------------------------------------------- walls

## Horizontal logs for the lodges: three rows to a log, lit on top, dark
## seam under each, grain streaks, and a round cut end on both corners.
func log_wall(im: Image, x: int, y: int, w: int, h: int, sd: int) -> void:
	var yy := 0
	var course := 0
	while yy < h:
		var ch := mini(3, h - yy)
		var top := y + yy
		for xx in w:
			var n := K.hash2(xx / 4, course, sd)
			for ry in ch:
				var idx := 3
				if ry == 0:
					idx = 4
				elif ry == ch - 1:
					idx = 1
				if ry == 1 and n > 0.72:
					idx += 1
				elif ry == 1 and n < 0.18:
					idx -= 1
				if xx < 2:
					idx += 1
				elif xx >= w - 3:
					idx -= 1
				K.px(im, x + xx, top + ry, timber[clampi(idx, 0, 5)])
		K.hline(im, x, top + ch - 1, w, timber[0])
		# round cut ends at both corners: the end grain with a ring
		for ex in [x, x + w - 1]:
			K.px(im, ex, top, timber[5] if ex == x else timber[4])
			K.px(im, ex, top + ch - 1, timber[0])
		K.px(im, x + 1, top + 1, timber[2])
		yy += ch
		course += 1


func _wall(im: Image, style: String, x: int, y: int, w: int, h: int, sd: int, o: Dictionary) -> void:
	if style == "timber":
		log_wall(im, x, y, w, h, sd)
	else:
		super(im, style, x, y, w, h, sd, o)


# ---------------------------------------------------------------- openings

## Every window is day glass; the glow picture lights it. Lodges get a
## timber sash with a sky glint, cloth curtains on some, and a sill. The hotel
## gets its own white frame and green shutters.
func window(im: Image, x: int, y: int, w: int, h: int, _lit: bool, sd: int) -> void:
	if hotel_mode:
		_hotel_window(im, x, y, w, h, sd)
		return
	K.rect(im, x - 1, y - 1, w + 2, h + 2, timber[0])
	K.hline(im, x - 1, y - 1, w + 2, timber[3])
	K.vline(im, x - 1, y - 1, h + 2, timber[2])
	_glass(im, x, y, w, h, sd, timber[1])
	if w >= 8 and K.hash2(x, y, sd + 40) < 0.6:
		var cloth: Color = CURTAIN[int(K.hash2(x, y, sd + 41) * CURTAIN.size())]
		K.vline(im, x, y, h - 1, cloth)
		K.vline(im, x + w - 1, y, h - 1, cloth.darkened(0.25))
	K.hline(im, x, y, w, timber[0].lerp(GLINT, 0.25))
	K.rect(im, x - 2, y + h + 1, w + 4, 1, granite[5])
	K.hline(im, x - 2, y + h + 2, w + 4, timber[0])
	shade(im, x - 1, y + h + 3, w + 2, 3, timber[0], 1.0, 0.0, 0.4)
	_register(im, Rect2i(x, y, w, h), 0.55 + K.hash2(x, y, sd) * 0.45)


## Glass with a sky gradient (paler at the top), a glint in the top-left pane
## and the muntins.
func _glass(im: Image, x: int, y: int, w: int, h: int, sd: int, frame: Color) -> void:
	for gy in h:
		for gx in w:
			var v := float(gy) / maxi(1, h - 1)
			var n := K.hash2(gx, gy, sd)
			var t := (0.9 - v * 0.75) * 4.0 + (n - 0.5) * 0.9
			K.px(im, x + gx, y + gy, sky[clampi(roundi(t), 0, 4)].darkened(0.1 + v * 0.12))
	if w >= 5:
		K.vline(im, x + w / 2, y, h, frame)
	if h >= 6:
		K.hline(im, x, y + h / 2, w, frame)
	K.px(im, x + 1, y + 1, GLINT)
	if w >= 6:
		K.px(im, x + 2, y + 1, GLINT.darkened(0.15))


## A hotel window: white frame, green louvred shutters, glass, lit sill.
func _hotel_window(im: Image, x: int, y: int, w: int, h: int, sd: int) -> void:
	for sx in [x - 3, x + w + 1]:
		K.rect(im, sx, y, 2, h, SHUTTER)
		for sy in range(y + 1, y + h, 2):
			K.hline(im, sx, sy, 2, SHUTTER.darkened(0.3))
	K.rect(im, x - 1, y - 1, w + 2, h + 2, WHITE[2])
	K.hline(im, x - 1, y - 1, w + 2, WHITE[5])
	_glass(im, x, y, w, h, sd, WHITE[2])
	K.hline(im, x - 2, y + h + 1, w + 4, WHITE[5])
	K.hline(im, x - 2, y + h + 2, w + 4, WHITE[1])
	shade(im, x - 1, y + h + 3, w + 2, 2, WHITE_SHADE, 1.0, 0.0, 0.3)
	_register(im, Rect2i(x, y, w, h), 0.7 + K.hash2(x, y, sd) * 0.3)


## A front door in a lintel, with a step, for the lodges' lamp to hang by.
func _door_lamp(im: Image, lx: int, ly: int) -> void:
	K.rect(im, lx - 1, ly - 1, 3, 1, iron[3])
	K.rect(im, lx - 1, ly, 3, 4, iron[1])
	K.rect(im, lx, ly + 1, 1, 2, WARM_GLASS)
	K.px(im, lx, ly + 1, Color("fff1c0"))
	K.hline(im, lx - 1, ly + 4, 3, iron[3])
	_register(im, Rect2i(lx, ly + 1, 1, 2), 1.0)


## Lodge touches: a lamp by the door and shrubs at the foot of each corner.
func _dress(im: Image, o: Dictionary, sd: int, wall_top: int, win_h: int, door_cx: int, awning: bool) -> void:
	super(im, o, sd, wall_top, win_h, door_cx, awning)
	if not o.get("dark", false):
		return
	var h := im.get_height()
	var w := im.get_width()
	_door_lamp(im, door_cx + 7, wall_top + 5)
	if w >= 48:
		shrub(im, 3, h - 5, 3, sd + 1, true)
		shrub(im, w - 4, h - 5, 3, sd + 2, true)


# ---------------------------------------------------------------- hotel veranda parts

## Boards for a veranda floor: two rows, a dark edge and the shadow it casts.
func _deck(im: Image, y: int, w: int, sd: int) -> void:
	for xx in w:
		var seam := xx % 6 == 0
		var tone := DECK.lightened(0.06 * (K.hash2(xx / 6, y, sd) - 0.5) * 2.0)
		K.px(im, xx, y, tone.lightened(0.1))
		K.px(im, xx, y + 1, DECK.darkened(0.45) if seam else tone.darkened(0.1))
	K.hline(im, 0, y + 2, w, DECK_EDGE)
	K.hline(im, 0, y + 3, w, Color(0, 0, 0, 0.3))
	K.hline(im, 0, y + 4, w, Color(0, 0, 0, 0.14))


## A balustrade: a lit top rail, square balusters with a cast shadow each, and
## a bottom rail on the deck.
func _balustrade(im: Image, top: int, w: int) -> void:
	K.hline(im, 0, top, w, WHITE[5])
	K.hline(im, 0, top + 1, w, WHITE[3])
	for bx in range(1, w - 2, 2):
		K.vline(im, bx, top + 2, 2, WHITE[4])
		K.vline(im, bx + 1, top + 2, 2, Color(0.25, 0.27, 0.36, 0.14))
	K.hline(im, 0, top + 4, w, WHITE[2])


## A square column, lit on its left, with a capital and base and the shadow it
## throws on the wall to its right.
func _column(im: Image, x: int, top: int, base_y: int, sd: int) -> void:
	for yy in range(top + 2, base_y - 2):
		K.px(im, x, yy, WHITE[5] if K.hash2(yy, sd, 1) > 0.15 else WHITE[4])
		K.px(im, x + 1, yy, WHITE[4])
		K.px(im, x + 2, yy, WHITE[2])
		K.px(im, x + 3, yy, Color(0, 0, 0, 0.2))
	K.rect(im, x - 1, top, 5, 2, WHITE[4])
	K.hline(im, x - 1, top, 5, WHITE[5])
	K.hline(im, x - 1, top + 1, 5, WHITE[2])
	K.rect(im, x - 1, base_y - 2, 5, 2, WHITE[3])
	K.hline(im, x - 1, base_y - 2, 5, WHITE[5])
	K.hline(im, x - 1, base_y - 1, 5, WHITE[1])


# ---------------------------------------------------------------- buildings

## Returns [sprite, glow]: a timber lodge [param w] pixels wide.
func lodge(w: int) -> Array:
	var h := lodge_height(w)
	var door := w / 2
	var wins: Array = []
	for wx in range(10, w - 6, 14 if w > 48 else 12):
		if absi(wx - door) > 9:
			wins.append(wx)
	var o := {"size": Vector2i(w, h), "wall": "timber", "seed": 90 + w, "dark": true, "windows": wins,
		"chimney": int(w * 0.8) - 6, "pitch": 12}
	if w >= 72:
		o["gable"] = w / 4 + 2
	return building("", o)


static func lodge_height(w: int) -> int:
	return 38 if w <= 48 else (42 if w <= 72 else 46)


## Returns [sprite, glow]: the Wawona Hotel, [param w] pixels wide. Two
## stories of white clapboard, a veranda on each floor (lit columns, a
## balustrade and a deck, all with shadow under them), a green shingle roof
## with a pedimented center and two chimneys, and a stone footing.
func wawona_hotel(w: int) -> Array:
	var h := HOTEL_HEIGHT
	var sd := 301 + w
	var base_timber := timber
	var base_stucco := stucco
	var base_roof := roof
	timber = _ramp(WHITE)
	stucco = _ramp(WHITE)
	roof = _ramp(HOTEL_ROOF)
	windows.clear()
	glass_snap = null
	hotel_mode = true
	crisp_roof = true
	var im := K.make(w, h)
	var cx := w / 2
	var up_top := 28
	var up_win := 31
	var deck_up := 46
	var low_top := 49
	var low_win := 50
	var rail_low := 57
	var deck_low := 62
	var found := 66
	K.shadow(im, w / 2.0, h - 2.5, w / 2.0 - 1.0, 2.6, 0.3)

	# Walls: clapboard down to the footing, lit corner boards and a cool shade on the right.
	K.lap(im, 1, up_top, w - 2, found - up_top, WHITE[3], sd)
	K.rect(im, 1, up_top, 2, found - up_top, WHITE[5])
	K.rect(im, w - 3, up_top, 2, found - up_top, WHITE[1])
	shade(im, w - 12, up_top, 11, found - up_top, WHITE_SHADE, 0.0, 0.8, 0.3, false)
	stone_wall(im, 1, found, w - 2, h - found, sd + 2, 0.5, 3, 2, true)
	K.hline(im, 1, found, w - 2, granite[5])
	# The shadow under each deck falls on the wall below it.
	shade(im, 2, deck_up + 3, w - 4, 5, WHITE_SHADE, 1.0, 0.0, 0.4)
	shade(im, 2, deck_low + 3, w - 4, 3, WHITE_SHADE, 1.0, 0.0, 0.4)

	# Roof, a pedimented center over the entrance, and two chimneys.
	shingle_roof(im, 0, 6, w, 20, sd + 3, 0.1)
	eave(im, 0, up_top - 2, w)
	gable(im, cx, up_top, mini(16, w / 6), 14, 3, sd + 4, true, 6)
	for chx in [w / 5, w - w / 5 - 12]:
		chimney(im, chx, 7, 12, sd + chx)

	# Windows: one to a bay, none in the door bay, with the columns between them.
	var bay := 16
	for k in range(-(cx / bay), cx / bay + 1):
		var wx := cx + k * bay - 2
		if k == 0 or wx < 6 or wx > w - 10:
			continue
		_hotel_window(im, wx, up_win, 5, 8, sd + k)
		_hotel_window(im, wx, low_win, 5, 6, sd + k + 50)
	K.door(im, cx - 3, 35, 6, 10, Color("3a5a48"), WHITE[5], false)
	K.door(im, cx - 3, 52, 6, 9, Color("3a5a48"), WHITE[5], false)

	# Balustrades, then decks, then the columns standing on them.
	_balustrade(im, 41, w)
	_balustrade(im, rail_low, w)
	_deck(im, deck_up, w, sd + deck_up)
	_deck(im, deck_low, w, sd + deck_low)
	for k in range(-(cx / bay) - 1, cx / bay + 2):
		var col_x := cx + k * bay + 7
		if col_x < 2 or col_x + 3 > w - 2:
			continue
		_column(im, col_x, up_top, deck_up, sd + col_x)
		_column(im, col_x, low_top, deck_low, sd + col_x + 9)

	# Shrubs at the corners of the footing.
	shrub(im, 4, deck_low + 3, 3, sd + 5, true)
	shrub(im, w - 5, deck_low + 3, 3, sd + 6, true)

	shade(im, w - 9, up_top, 8, found - up_top, granite[0], 0.0, 0.85, 0.3, false)
	K.outline(im, Color("231a16"))
	var glow := _glow_image(im, w, h)
	timber = base_timber
	stucco = base_stucco
	roof = base_roof
	hotel_mode = false
	crisp_roof = false
	return [im, glow]
