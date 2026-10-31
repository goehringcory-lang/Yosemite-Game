extends "res://tools/hubs/camp4_art.gd"
## The search and rescue site at the back of Camp 4, in Camp 4's look (same
## ramps, light from the upper left, dark rim). Yosemite's rescue volunteers
## live here through the season in a row of canvas tent cabins: wood frames
## on raised plank platforms, canvas walls and roofs, and a wood stove each,
## its pipe through the roof. Beside them: the rescue cache shed with its
## radio mast, ropes and helmets on pegs, a Stokes basket litter on
## sawhorses with the big wheel for trail carries, a line of yellow team
## shirts drying, and a routed sign. Written to assets/sprites/buildings/ as
## camp4_sar_*, at the 16px scale like the rest of Camp 4, then upgraded
## with `python3 tools/art32/upgrade.py --fresh` on just these files.
##
## Every sprite is anchored at its bottom center. The tent cabins and the
## cache get a "<name>_glow" picture of lamplight for after dark.
##
## Preview: godot --headless --path . -s res://tools/hubs/preview_sar_site_art.gd

const SAR_FILES := [
	"camp4_sar_cabin_0", "camp4_sar_cabin_0_glow", "camp4_sar_cabin_1", "camp4_sar_cabin_1_glow",
	"camp4_sar_cabin_2", "camp4_sar_cabin_2_glow",
	"camp4_sar_cache", "camp4_sar_cache_glow", "camp4_sar_litter", "camp4_sar_shirts", "camp4_sar_sign",
]
## The team's shirt yellow: [shadow, mid, light].
const SHIRT := ["b88a10", "e8b820", "f8dc5a"]
const LITTER := ["9a3412", "d8541e", "f08a3a"]


func save_sar() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for v in 3:
		var cabin := tent_cabin(v)
		_write(cabin, "camp4_sar_cabin_%d" % v)
		_write(cabin_glow(cabin, v), "camp4_sar_cabin_%d_glow" % v)
	var cache := rescue_cache()
	_write(cache, "camp4_sar_cache")
	_write(cache_glow(cache), "camp4_sar_cache_glow")
	_write(litter_rack(), "camp4_sar_litter")
	_write(shirt_line(), "camp4_sar_shirts")
	_write(sar_sign(), "camp4_sar_sign")


# ---------------------------------------------------------------- tent cabins

## Where a tent cabin's front wall is, for its glow.
const CABIN_W := 46
const CABIN_H := 42
const CABIN_WALL := Rect2i(7, 17, 32, 12)
const CABIN_WINDOW := Rect2i(24, 20, 11, 5)


## A canvas tent cabin, long side to the camp: a plank platform on short
## posts with two steps up, a canvas wall on a wood frame, the roof's canvas
## sloping up to the ridge, and a stovepipe with a rain cap. A wood door with
## a screen panel, a window with its canvas flap rolled up, and the cabin's
## number by the door. Variant 0 has a helmet and a pack out on the deck,
## variant 1 its door open, a coiled rope on the rail and boots by the door,
## and variant 2 a stack of split wood for the stove.
func tent_cabin(v: int) -> Image:
	var w := CABIN_W
	var h := CABIN_H
	var im := K.make(w, h)
	K.shadow(im, 23, h - 4.0, 22.0, 3.4, 0.3)
	var deck_top := 29
	var deck_front := 31
	var ground := 37
	# posts under the platform, in its shade
	for px_ in [5, 16, 29, 40]:
		K.rect(im, px_, deck_front + 3, 2, ground - deck_front - 3, timber[1])
		K.px(im, px_, deck_front + 3, timber[2])
	K.rect(im, 4, deck_front + 3, 38, 1, Color(0.06, 0.04, 0.03, 0.5))
	# the platform: its top in front of the wall, and the plank rim
	_planks(im, 3, deck_top, 40, 2, 4)
	_planks(im, 3, deck_front, 40, 3, 3)
	K.hline(im, 3, deck_front + 2, 40, timber[1])
	# roof: the canvas slopes from the eave up to the ridge, lit from the left
	var ridge_y := 5
	var eave_y := 15
	var roof_pts := PackedVector2Array([Vector2(8, ridge_y), Vector2(38, ridge_y), Vector2(43, eave_y), Vector2(3, eave_y)])
	_canvas_fill(im, roof_pts, 0.8, 21 + v)
	for sx in [13, 23, 33]:
		for y in range(ridge_y + 1, eave_y):
			tint_px(im, sx + int((y - ridge_y) * 0.1), y, canvas[2], 0.45)
	K.hline(im, 8, ridge_y, 31, canvas[5])
	# the gable ends, just visible, in shade
	poly(im, PackedVector2Array([Vector2(38, ridge_y), Vector2(43, eave_y), Vector2(40, eave_y)]), canvas[1])
	poly(im, PackedVector2Array([Vector2(8, ridge_y), Vector2(3, eave_y), Vector2(6, eave_y)]), canvas[3])
	# the eave: a hem of doubled canvas and the shadow it throws on the wall
	K.hline(im, 3, eave_y, 41, canvas[4])
	K.hline(im, 3, eave_y + 1, 41, canvas[2])
	# the front wall
	_canvas_fill(im, PackedVector2Array([Vector2(6, eave_y + 2), Vector2(40, eave_y + 2), Vector2(40, deck_top), Vector2(6, deck_top)]), 0.56, 23 + v)
	shade(im, 6, eave_y + 2, 34, 3, canvas[0], 0.8, 0.0, 0.35)
	# the wood frame at the corners and along the bottom
	K.vline(im, 6, eave_y + 1, deck_top - eave_y - 1, timber[4])
	K.vline(im, 39, eave_y + 1, deck_top - eave_y - 1, timber[2])
	K.hline(im, 6, deck_top - 1, 34, timber[2])
	# dust splashed up the canvas
	for x in range(7, 39):
		for y in range(deck_top - 3, deck_top - 1):
			if K.hash2(x, y, 31 + v) > 0.4 + (deck_top - 1 - y) * 0.2:
				tint_px(im, x, y, Color("6a4a2c"), 0.35)
	# the door, with a screen panel, and the cabin's number
	var door := Rect2i(11, 18, 7, 11)
	K.rect(im, door.position.x - 1, door.position.y - 1, door.size.x + 2, door.size.y + 1, timber[1])
	if v == 1:
		K.rect(im, door.position.x, door.position.y, door.size.x, door.size.y, Color("1c140e"))
		K.rect(im, door.position.x + 1, door.position.y + 5, 3, door.size.y - 5, Color("2a1e14"))
		# the door swung out against the wall
		K.rect(im, door.position.x - 4, door.position.y, 3, door.size.y, timber[3])
		K.vline(im, door.position.x - 4, door.position.y, door.size.y, timber[4])
	else:
		for y in range(door.position.y, door.end.y):
			for x in range(door.position.x, door.end.x):
				K.px(im, x, y, timber[3 if x < door.position.x + 3 else 2])
		K.rect(im, door.position.x + 1, door.position.y + 1, door.size.x - 2, 3, Color("4a5560"))
		K.hline(im, door.position.x + 1, door.position.y + 1, 2, Color("7a8a94"))
		K.px(im, door.end.x - 2, door.position.y + 5, Color("d8c070"))
	K.rect(im, door.end.x + 1, door.position.y + 1, 3, 4, Color("eae2c8"))
	_digit(im, door.end.x + 1, door.position.y + 1, [3, 7, 5][v])
	# the window: dark screen under the canvas flap rolled up and tied
	var win := CABIN_WINDOW
	K.rect(im, win.position.x, win.position.y, win.size.x, win.size.y, Color("2a3038"))
	for x in range(win.position.x, win.end.x, 2):
		K.vline(im, x, win.position.y, win.size.y, Color("343c46"))
	K.hline(im, win.position.x, win.position.y, win.size.x, Color("4a5560"))
	K.rect(im, win.position.x - 1, win.position.y - 2, win.size.x + 2, 2, canvas[4])
	K.hline(im, win.position.x - 1, win.position.y - 1, win.size.x + 2, canvas[2])
	for tx in [win.position.x + 1, win.end.x - 2]:
		K.vline(im, tx, win.position.y - 2, 3, Color("6a4a2c"))
	# the stovepipe, through a tin collar in the roof, with its rain cap
	var pipe_x := 31
	K.rect(im, pipe_x - 1, 9, 5, 2, Color("8a8a8a"))
	K.rect(im, pipe_x, 2, 3, 8, iron[1])
	K.vline(im, pipe_x, 2, 8, iron[3])
	K.rect(im, pipe_x - 1, 1, 5, 1, iron[2])
	K.hline(im, pipe_x - 1, 0, 5, iron[3])
	# steps up to the door
	_planks(im, door.position.x - 1, deck_front + 2, door.size.x + 2, 2, 4)
	_planks(im, door.position.x, ground - 2, door.size.x, 2, 3)
	K.vline(im, door.position.x - 1, deck_front + 4, 3, timber[1])
	K.vline(im, door.end.x, deck_front + 4, 3, timber[1])
	# what's left out on the deck
	if v == 0:
		# a red helmet and a blue pack against the wall
		K.ellipse(im, 30, 28, 2.2, 1.6, Color("c8302a"))
		K.px(im, 29, 27, Color("f06a50"))
		K.rect(im, 34, 25, 4, 5, Color("2f5a8a"))
		K.hline(im, 34, 25, 4, Color("5a8ac0"))
		K.vline(im, 37, 25, 5, Color("22446a"))
	elif v == 1:
		# a coiled rope hung on the corner, boots by the door
		K.ring(im, 38, 24, 2.5, 3.0, Color("2f7a8a"))
		K.ring(im, 38, 24, 1.5, 2.0, Color("4aa0b0"))
		K.rect(im, 20, 27, 2, 2, Color("5a3a22"))
		K.rect(im, 23, 27, 2, 2, Color("4a2e1a"))
	else:
		# split wood stacked against the wall, cut ends out
		for row in 3:
			for i in 4 - row:
				var lx := 31 + i * 2 + row
				var ly := 27 - row * 2
				K.rect(im, lx, ly, 2, 2, timber[4])
				K.px(im, lx, ly, timber[5])
				K.px(im, lx + 1, ly + 1, timber[2])
	K.outline(im, RIM)
	return im


## A digit from the 3x5 font in dark paint on the number board.
func _digit(im: Image, x: int, y: int, n: int) -> void:
	var g: Array = K.FONT.get(str(n % 10), K.FONT[" "])
	for gy in 3:
		for gx in 3:
			# squash the 5 rows into 3 so it fits the little board
			var row: String = g[[0, 2, 4][gy]]
			if row[gx] == "#":
				K.px(im, x + gx, y + gy, Color("2a2420"))


## Lamplight through a cabin's canvas wall and window after dark.
func cabin_glow(src: Image, v: int) -> Image:
	var im := fabric_glow(src, CABIN_WALL)
	var win := CABIN_WINDOW
	for y in range(win.position.y, win.end.y):
		for x in range(win.position.x, win.end.x):
			K.px(im, x, y, Color(1.0, 0.78, 0.38, 0.75))
	if v == 1:
		for y in range(18, 29):
			for x in range(11, 18):
				K.px(im, x, y, Color(1.0, 0.72, 0.32, 0.6))
	return im


# ---------------------------------------------------------------- the cache

const CACHE_W := 54
const CACHE_H := 50


## The rescue cache: a board-and-batten shed with a shingled roof and a radio
## mast, its double doors open on ropes coiled on pegs, helmets on a shelf,
## packs and a stack of blue rope bags, with a lamp over the door and a
## routed SAR CACHE board.
func rescue_cache() -> Image:
	var w := CACHE_W
	var h := CACHE_H
	var im := K.make(w, h)
	K.shadow(im, 27, h - 4.0, 25.0, 3.6, 0.3)
	var wall_top := 17
	var base := h - 6
	# the radio mast on the back of the roof, guyed
	var mast := 44
	K.vline(im, mast, 0, 14, iron[3])
	K.vline(im, mast + 1, 0, 14, iron[1])
	for y in [2, 6, 10]:
		K.hline(im, mast - 1, y, 4, iron[2])
	K.px(im, mast, 0, Color("e04030"))
	line(im, Vector2(mast, 1), Vector2(mast + 7, 12), Color("8a8478"))
	# the roof
	shingle_roof(im, 2, 5, w - 4, wall_top - 5, 61, 0.35)
	# board-and-batten walls
	for y in range(wall_top, base):
		for x in range(4, w - 4):
			var idx := 3 - int(float(x - 4) / (w - 8) * 1.6)
			if (x - 4) % 5 == 0:
				idx += 1
			elif (x - 4) % 5 == 4:
				idx -= 1
			if K.hash2(x, y / 3, 63) > 0.9:
				idx -= 1
			K.px(im, x, y, timber[clampi(idx, 0, 5)])
	shade(im, 4, wall_top, w - 8, 3, timber[0], 0.9, 0.0, 0.4)
	K.vline(im, 4, wall_top, base - wall_top, timber[4])
	K.vline(im, w - 5, wall_top, base - wall_top, timber[1])
	# the open doorway and what's inside
	var door := Rect2i(17, 25, 20, base - 25)
	K.rect(im, door.position.x, door.position.y, door.size.x, door.size.y, Color("1a120c"))
	# a shelf of helmets
	K.hline(im, door.position.x + 1, door.position.y + 4, door.size.x - 2, timber[2])
	var helmets := [Color("d8402a"), Color("e8b820"), Color("d8402a"), Color("e8e0d0"), Color("e8b820")]
	for i in helmets.size():
		var hx := door.position.x + 2 + i * 4
		K.rect(im, hx, door.position.y + 2, 3, 2, helmets[i])
		K.px(im, hx, door.position.y + 2, (helmets[i] as Color).lightened(0.3))
	# ropes coiled on pegs
	var ropes := [[Color("2f7a8a"), Color("4aa0b0")], [Color("c8402e"), Color("e86a4a")], [Color("4a8a3a"), Color("7ab45a")]]
	for i in ropes.size():
		var rx := door.position.x + 4 + i * 6
		K.px(im, rx, door.position.y + 6, timber[4])
		K.ring(im, rx, door.position.y + 10, 2.2, 3.2, ropes[i][0])
		K.ring(im, rx, door.position.y + 10, 1.2, 2.2, ropes[i][1])
	# rope bags and a pack on the floor
	K.rect(im, door.position.x + 2, base - 4, 4, 4, Color("2f5a8a"))
	K.hline(im, door.position.x + 2, base - 4, 4, Color("5a8ac0"))
	K.rect(im, door.position.x + 7, base - 3, 4, 3, Color("2f5a8a"))
	K.rect(im, door.end.x - 6, base - 5, 4, 5, Color("c86a2a"))
	K.hline(im, door.end.x - 6, base - 5, 4, Color("e89a5a"))
	# the doors swung open against the wall
	for side in [-1, 1]:
		var dx: int = door.position.x - 5 if side < 0 else door.end.x + 1
		for y in range(door.position.y, base):
			for x in range(dx, dx + 4):
				K.px(im, x, y, timber[3 if side < 0 else 2])
		K.vline(im, dx + (0 if side < 0 else 3), door.position.y, door.size.y, timber[1])
		line(im, Vector2(dx, door.position.y + 1), Vector2(dx + 3, base - 2), timber[1])
	# the frame and the routed board over the door
	K.hline(im, door.position.x - 1, door.position.y - 1, door.size.x + 2, timber[1])
	var brown := Color("573522")
	K.sign_board(im, door.position.x - 3, wall_top + 1, door.size.x + 6, "SAR CACHE", brown, Color("eadcb2"), 7)
	# the lamp over the door
	K.rect(im, door.end.x + 6, wall_top + 3, 3, 3, iron[1])
	K.px(im, door.end.x + 7, wall_top + 4, Color("ffe6a0"))
	# a concrete stoop
	K.rect(im, door.position.x - 2, base, door.size.x + 4, 2, gr[4])
	K.hline(im, door.position.x - 2, base, door.size.x + 4, gr[6])
	K.hline(im, door.position.x - 2, base + 1, door.size.x + 4, gr[2])
	K.outline(im, RIM)
	return im


func cache_glow(src: Image) -> Image:
	var im := K.make(src.get_width(), src.get_height())
	var lamp := Vector2(43.5, 21.5)
	for ring_ in range(6, 0, -1):
		K.ellipse(im, lamp.x, lamp.y + 1, ring_ + 1.5, ring_ + 1.0, Color(1.0, 0.78, 0.36, 0.05 + (6 - ring_) * 0.05))
	K.rect(im, 43, 21, 1, 1, Color(1.0, 0.92, 0.6, 0.9))
	# light from a bulb inside, falling out of the doorway
	for y in range(26, CACHE_H - 6):
		for x in range(18, 36):
			var a := 0.38 - float(y - 26) / 30.0 * 0.2
			a = floorf(a * 6.0 + FloraArt.bayer(x, y)) / 6.0
			if a > 0.0:
				K.px(im, x, y, Color(1.0, 0.76, 0.36, a))
	return im


# ---------------------------------------------------------------- litter, shirts, sign

## An orange Stokes basket litter on two sawhorses, its wire mesh showing,
## with the big single wheel used for long trail carries leaning beside it.
func litter_rack() -> Image:
	var w := 44
	var h := 24
	var im := K.make(w, h)
	K.shadow(im, 22, h - 3.0, 20.0, 2.6, 0.28)
	var orange := _ramp(LITTER)
	# sawhorses
	for sx in [8, 26]:
		line(im, Vector2(sx - 2, h - 3), Vector2(sx + 1, 11), timber[2])
		line(im, Vector2(sx + 4, h - 3), Vector2(sx + 1, 11), timber[1])
		K.rect(im, sx - 2, 10, 7, 2, timber[4])
		K.hline(im, sx - 2, 11, 7, timber[2])
	# the basket: an orange rail around a wire mesh tub, head end raised
	var body := Rect2i(3, 4, 32, 7)
	for y in range(body.position.y, body.end.y):
		for x in range(body.position.x, body.end.x):
			var mesh := (x + y) % 3 == 0 or (x - y) % 3 == 0
			K.px(im, x, y, Color("8a8a84") if mesh else Color("3a3632"))
	K.hline(im, body.position.x, body.position.y, body.size.x, orange[2])
	K.hline(im, body.position.x, body.end.y - 1, body.size.x, orange[0])
	K.vline(im, body.position.x, body.position.y, body.size.y, orange[1])
	K.vline(im, body.end.x - 1, body.position.y, body.size.y, orange[0])
	for x in range(body.position.x + 6, body.end.x - 1, 6):
		K.vline(im, x, body.position.y, body.size.y, orange[1])
	# the head end's shield and a red strap across
	K.rect(im, body.end.x - 5, body.position.y + 1, 4, body.size.y - 2, orange[1])
	K.vline(im, body.end.x - 5, body.position.y + 1, body.size.y - 2, orange[2])
	K.vline(im, 16, body.position.y, body.size.y, Color("b02a20"))
	# the wheel, leaning
	K.ring(im, 39, 13, 4.0, 6.0, Color("2a2a2a"))
	K.ring(im, 39, 13, 3.0, 5.0, Color("4a4a4a"))
	K.rect(im, 38, 12, 2, 2, Color("b0b0b0"))
	line(im, Vector2(39, 13), Vector2(36, 6), Color("8a8a8a"))
	K.outline(im, RIM)
	return im


## A line strung between two poles with the team's yellow shirts drying on
## it, and a helmet hung on one pole.
func shirt_line() -> Image:
	var w := 46
	var h := 30
	var im := K.make(w, h)
	K.shadow(im, 23, h - 3.0, 21.0, 2.2, 0.22)
	for px_ in [3, 41]:
		post(im, px_, 5, h - 7, 800 + px_, 2)
		K.hline(im, px_ - 1, 5, 4, timber[4])
	sag_line(im, Vector2(4, 6), Vector2(42, 6), 3.0, Color("d8cfb4"))
	var yellow := _ramp(SHIRT)
	for i in 3:
		var cx := 12 + i * 11
		var top := 7 + int(sin(float(cx - 4) / 38.0 * PI) * 3.0)
		# a T-shirt pinned by its shoulders: sleeves, then the body
		K.rect(im, cx - 4, top, 9, 3, yellow[1])
		K.rect(im, cx - 3, top + 3, 7, 6, yellow[1])
		K.hline(im, cx - 4, top, 9, yellow[2])
		K.vline(im, cx - 3, top + 1, 8, yellow[2])
		K.vline(im, cx + 3, top + 3, 6, yellow[0])
		K.hline(im, cx - 3, top + 8, 7, yellow[0])
		K.rect(im, cx - 1, top, 3, 1, yellow[0])
		# the team's lettering across the chest
		K.hline(im, cx - 2, top + 4, 5, Color("2a2420").lerp(yellow[0], 0.35))
		# clothespins
		K.px(im, cx - 3, top - 1, Color("c8b088"))
		K.px(im, cx + 3, top - 1, Color("c8b088"))
	# a red helmet on the right pole
	K.ellipse(im, 42, 4, 2.4, 1.8, Color("c8302a"))
	K.px(im, 41, 3, Color("f06a50"))
	K.outline(im, RIM)
	return im


## The routed Park Service sign at the edge of the site.
func sar_sign() -> Image:
	var w := 50
	var h := 36
	var im := K.make(w, h)
	K.shadow(im, 25, h - 3.0, 21.0, 2.4, 0.3)
	for px_ in [9, 39]:
		post(im, px_, 22, 11, 900 + px_, 3)
	var brown := _ramp(["2e1c12", "42291a", "573522", "6a4330", "7e543e"])
	K.rect(im, 2, 2, 46, 21, brown[0])
	for yy in 19:
		for xx in 44:
			K.px(im, 3 + xx, 3 + yy, brown[2] if K.hash2(xx, yy / 2, 93) > 0.15 else brown[1])
	K.hline(im, 3, 3, 44, brown[4])
	K.vline(im, 3, 3, 19, brown[3])
	K.hline(im, 3, 21, 44, brown[1])
	var cream := Color("eadcb2")
	big_text(im, 3 + (44 - big_text_width("SAR")) / 2, 4, "SAR", cream, brown[0])
	K.text_centered(im, 3, 44, 15, "RESCUE SITE", cream.darkened(0.06), brown[0])
	K.outline(im, RIM)
	return im
