extends "res://tools/hubs/valley_art.gd"
## Wawona pixel art in the Ahwahnee's style (the ramps, upper-left light and
## dark rim of valley_art.gd): the white Wawona Hotel (1879) with its two
## tiers of verandas, the cottages round it, Thomas Hill's Studio (1886), the
## Wawona Store, the Wawona Covered Bridge (1857, covered 1875), the Yosemite
## History Center's buildings (a log homestead cabin, the Wells Fargo office,
## the jail, the blacksmith's shop, an artist's studio) and a Concord
## stagecoach, the golf course's flags and the split-rail fences, and in the
## Mariposa Grove the welcome plaza, its shuttle, and the grove museum cabin.
## Written to assets/sprites/wawona/ at 16px scale;
## tools/hubs/rebuild_wawona.sh moves them onto the 32px grid. The big trees
## are in foothill_flora_art.gd.

const WW_OUT := "res://assets/sprites/wawona/"
## The covered bridge's span and deck, in px: the bridge picture is
## BRIDGE_LEN wide and its deck BRIDGE_DECK deep.
const BRIDGE_LEN := 112
const BRIDGE_DECK := 24

## White-painted siding and trim, dark to light.
var white: Array[Color] = []


func _init() -> void:
	super._init()
	white = _ramp(["7e7c80", "a4a19c", "c4bfb4", "dcd6c8", "eee9dc", "faf7ee"])


func save_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WW_OUT))
	var charcoal := ["22262a", "30363a", "424a4e", "566064", "6e787a", "8a9494"]
	var green := ["1c2a22", "2a4030", "3a5640", "4d6e50", "658a64", "84a67c"]
	var brown := ["2e2218", "4a3422", "644630", "7e5c3e", "9a7650", "b89468"]
	var shake := ["2a2622", "3e3832", "564e44", "6e6456", "887c6a", "a49882"]
	_pair("hotel", white_house(212, 108, true, 1879, "WAWONA HOTEL", charcoal, 5))
	_pair("cottage_two", white_house(132, 96, true, 1884, "", charcoal, 3))
	_pair("cottage_one", white_house(104, 62, false, 1876, "", charcoal, 3))
	_pair("hill_studio", white_house(64, 60, false, 1886, "HILL'S STUDIO", green, 1))
	_pair("store", building("", {"size": Vector2i(76, 46), "wall": "board", "tone": 3, "label": "WAWONA STORE", "seed": 1932,
		"roof": green, "windows": [12, 24, 52, 64], "gable": 38, "porch": true, "goods": true, "scale": VILLAGE_SCALE}))
	_pair("homestead_cabin", building("", {"size": Vector2i(48, 38), "wall": "timber", "seed": 1879, "roof": shake, "windows": [11], "chimney": 38,
		"dark": true, "scale": 1.3}))
	_pair("wells_fargo", building("", {"size": Vector2i(44, 40), "wall": "board", "tone": 2, "label": "WELLS FARGO", "seed": 1852,
		"roof": brown, "windows": [9, 35], "gable": 22, "porch": true, "scale": 1.3}))
	_pair("jail", building("", {"size": Vector2i(34, 32), "wall": "board", "tone": 1, "label": "JAIL", "seed": 1901,
		"roof": shake, "windows": [], "dark": true, "scale": 1.3}))
	_pair("blacksmith", building("", {"size": Vector2i(50, 38), "wall": "board", "tone": 1, "label": "BLACKSMITH", "seed": 1890,
		"roof": shake, "windows": [9], "chimney": 40, "scale": 1.3}))
	_pair("artist_studio", building("", {"size": Vector2i(46, 40), "wall": "board", "tone": 4, "label": "STUDIO", "seed": 1900,
		"roof": brown, "windows": [9, 37], "gable": 23, "porch": true, "scale": 1.3}))
	_pair("grove_museum", building("", {"size": Vector2i(46, 38), "wall": "timber", "label": "GROVE MUSEUM", "seed": 1930,
		"roof": shake, "windows": [9, 37], "porch": true, "scale": 1.3}))
	_pair("welcome_plaza", building("", {"size": Vector2i(72, 40), "wall": "stone_timber", "label": "MARIPOSA GROVE", "seed": 2018,
		"roof": green, "windows": [10, 22, 50, 62], "gable": 36, "low": true, "scale": VILLAGE_SCALE}))
	_ww_write(bridge_back(), "bridge_back")
	_ww_write(bridge_front(), "bridge_front")
	_ww_write(stagecoach(), "stagecoach")
	_ww_write(golf_flag(), "golf_flag")
	_ww_write(rail_fence(true), "fence_h")
	_ww_write(rail_fence(false), "fence_v")
	_ww_write(grove_shuttle(), "grove_shuttle")
	_ww_write(hitching_rail(), "hitching_rail")


func _pair(sprite_name: String, built: Array) -> void:
	_ww_write(built[0], sprite_name)
	_ww_write(built[1], sprite_name + "_glow")


func _ww_write(im: Image, sprite_name: String) -> void:
	im.save_png(ProjectSettings.globalize_path(WW_OUT + sprite_name + ".png"))


# ---------------------------------------------------------------- white frame buildings

## Painted lap siding: narrow horizontal boards, each lit along its top edge
## with a shadow line under it.
func white_lap(im: Image, x: int, y: int, w: int, h: int, sd: int) -> void:
	for yy in h:
		var row := yy % 3
		for xx in w:
			var t := 0.7 + (0.5 - float(xx) / w) * 0.12 + (K.hash2(xx / 7, yy / 3, sd) - 0.5) * 0.06
			var idx := clampi(roundi(t * 5.0), 0, 5)
			if row == 0:
				idx = mini(5, idx + 1)
			elif row == 2:
				idx = maxi(1, idx - 2)
			K.px(im, x + xx, y + yy, white[idx])


## A white post of a veranda, lit on its left.
func white_post(im: Image, x: int, y: int, h: int) -> void:
	K.vline(im, x, y, h, white[5])
	K.vline(im, x + 1, y, h, white[3])
	K.vline(im, x + 2, y, h, white[1])


## A veranda railing: a white top rail and balusters, gaps at [param skip].
func white_rail(im: Image, x: int, y: int, w: int, h: int, skip := Vector2i(-1, -1)) -> void:
	for xx in range(x, x + w):
		if xx >= skip.x and xx < skip.y:
			continue
		K.px(im, xx, y, white[5])
		K.px(im, xx, y + 1, white[2])
		if xx % 2 == 0:
			K.vline(im, xx, y + 2, h - 2, white[4])
		K.px(im, xx, y + h - 1, white[2])


## The Wawona Hotel's buildings: white frame houses under low hipped roofs,
## wrapped in verandas: one tier for a cottage, two (an upper gallery on the
## posts of the lower) for the hotel. Returns [sprite, glow].
func white_house(w: int, h: int, two_story: bool, sd: int, label: String, roof_hex: Array, bays: int) -> Array:
	windows.clear()
	glass_snap = null
	var im := K.make(w, h)
	var base_roof := roof
	var base_timber := timber
	roof = _ramp(roof_hex)
	K.shadow(im, w / 2.0, h - 2.5, w / 2.0 - 1.0, 2.8, 0.3)
	var roof_h := int(h * (0.3 if two_story else 0.36))
	var wall_top := roof_h + 1
	var found := 5
	var deck := h - found - 2
	var story := (deck - wall_top) / (2 if two_story else 1)
	# the siding, and a shaded band under each veranda roof
	white_lap(im, 3, wall_top, w - 6, deck - wall_top, sd)
	stone_wall(im, 1, h - found - 1, w - 2, found, sd + 100, 0.5, 3, 2, true)
	# windows: tall sashes with dark-green shutters, a bay at a time
	var door_cx := w / 2
	timber = white
	for f in (2 if two_story else 1):
		var fy := wall_top + f * story
		for b in bays * 2:
			var wx := 10 + b * (w - 20) / (bays * 2 - 1) - 3
			if absi(wx + 3 - door_cx) < 8:
				continue
			_vb_window(im, wx, fy + 5, 6, story - 11, K.hash2(b, f + sd, 5) < 0.5, sd + b * 7 + f)
			K.rect(im, wx - 3, fy + 4, 2, story - 9, Color("2e4a36"))
			K.rect(im, wx + 7, fy + 4, 2, story - 9, Color("2e4a36"))
	timber = base_timber
	# the front door, double, with a transom
	plank_door(im, door_cx, deck, mini(story - 4, 16), sd + 500, 10)
	timber = white
	K.rect(im, door_cx - 5, deck - mini(story - 4, 16) - 4, 10, 2, sky[3])
	# the veranda(s): roof shade, posts the full height, rails, and the gallery floor
	shade(im, 3, wall_top, w - 6, 6, Color("1e1834"), 0.9, 0.0, 0.45)
	var n_posts := maxi(3, w / 18)
	for k in n_posts + 1:
		white_post(im, 2 + k * (w - 7) / n_posts, wall_top, deck - wall_top)
	if two_story:
		var gy := wall_top + story
		for xx in range(2, w - 2):
			K.px(im, xx, gy, white[4])
			K.px(im, xx, gy + 1, white[1])
		shade(im, 3, gy + 2, w - 6, 5, Color("1e1834"), 0.8, 0.0, 0.4)
		white_rail(im, 3, gy - 7, w - 6, 7)
	white_rail(im, 3, deck - 7, w - 6, 7, Vector2i(door_cx - 9, door_cx + 9))
	# the deck and the front steps
	for xx in range(2, w - 2):
		K.px(im, xx, deck, white[3] if xx % 6 else white[2])
		K.px(im, xx, deck + 1, white[1])
	for s in 2:
		K.rect(im, door_cx - 9 - s * 2, deck + 2 + s * 2, 18 + s * 4, 2, granite[5 - s])
		K.hline(im, door_cx - 9 - s * 2, deck + 2 + s * 2, 18 + s * 4, granite[6])
	timber = base_timber
	# a low hipped roof, a central gable, and chimneys
	_vb_roof(im, 0, 2, w, roof_h - 1, sd + 200, 0.22)
	_vb_eave(im, 0, roof_h - 1, w)
	if two_story and w > 150:
		timber = white
		gable(im, door_cx, roof_h, 22, roof_h - 6, 3, sd + 300, true, 6)
		timber = base_timber
	for cxp in [int(w * 0.2), int(w * 0.8)]:
		chimney(im, cxp, 4, maxi(5, roof_h - 12), sd + cxp)
	if label != "":
		sign_board(im, door_cx, wall_top + story - 9 if two_story else wall_top + 2, label)
	shade(im, w - 8, wall_top, 7, deck - wall_top, Color("4a4a60"), 0.0, 0.7, 0.3, false)
	K.outline(im, Color("2a2420"))
	var glow := _glow_image(im, w, h)
	roof = base_roof
	return [im, glow]


# ---------------------------------------------------------------- the covered bridge

## The back half of the Wawona Covered Bridge, cut away so the walk through
## it shows: the long shake roof, the far wall of weathered sugar pine
## boards with its little windows of daylight, and the portal frame at each
## end. Stand it at the north edge of the deck; the player walks in front.
func bridge_back() -> Image:
	var w := BRIDGE_LEN
	var h := 58
	var sd := 1857
	var im := K.make(w, h)
	var base_roof := roof
	roof = _ramp(["2a2622", "3e3832", "564e44", "6e6456", "887c6a", "a49882"])
	var grey := _ramp(["2e2a26", "47403a", "625850", "7e7266", "998c7c", "b4a692"])
	var wall_top := 22
	# the far wall: vertical boards gone silver-brown
	for xx in range(4, w - 4):
		for yy in range(wall_top, h):
			var board := xx / 4
			var t := 0.4 + (K.hash2(board, sd, 3) - 0.5) * 0.3 + (K.hash2(xx, yy / 5, sd) - 0.5) * 0.08 - float(yy - wall_top) / (h - wall_top) * 0.15
			if xx % 4 == 0:
				t -= 0.18
			K.px(im, xx, yy, grey[clampi(roundi(t * 5.0), 0, 5)])
	# daylight through the window slots
	for wx in range(16, w - 16, 20):
		K.rect(im, wx, wall_top + 8, 6, 5, Color("c8dce0"))
		K.hline(im, wx, wall_top + 12, 6, Color("8ab070"))
		K.rect(im, wx - 1, wall_top + 7, 8, 1, grey[0])
	# the floor beams' shadow at the foot of the wall
	shade(im, 4, h - 6, w - 8, 6, Color("1a1410"), 0.0, 1.0, 0.5)
	# trusses: the diagonal braces of the Howe truss inside
	for k in range(0, w - 8, 16):
		FloraArt.line(im, 6 + k, h - 2, 6 + k + 14, wall_top + 2, grey[1])
		FloraArt.line(im, 7 + k, h - 2, 7 + k + 14, wall_top + 2, grey[3])
	# the roof: long shake courses seen from above and the front
	_vb_roof(im, 0, 2, w, wall_top - 3, sd + 200, 0.0)
	_vb_eave(im, 0, wall_top - 2, w)
	# the portals: posts and the gable boards at each end
	for side in [0, 1]:
		var px0 := 0 if side == 0 else w - 5
		for xx in 5:
			for yy in range(wall_top - 2, h):
				K.px(im, px0 + xx, yy, grey[4 - xx if side == 0 else 1 + xx / 2])
	roof = base_roof
	K.outline(im, Color("1e1a16"))
	return im


## The near side of the covered bridge, cut away to a low rail and the
## sill beam, standing at the south edge of the deck.
func bridge_front() -> Image:
	var w := BRIDGE_LEN
	var h := 12
	var im := K.make(w, h)
	var grey := _ramp(["2e2a26", "47403a", "625850", "7e7266", "998c7c", "b4a692"])
	for xx in w:
		K.px(im, xx, 2, grey[4])
		K.px(im, xx, 3, grey[2])
		for yy in range(7, 11):
			K.px(im, xx, yy, grey[3 if yy == 7 else (2 if yy < 10 else 0)])
		if xx % 8 == 0 or xx < 5 or xx > w - 6:
			K.vline(im, xx, 2, 6, grey[3])
	K.outline(im, Color("1e1a16"))
	return im


# ---------------------------------------------------------------- props

## A Concord stagecoach like the ones that ran from Wawona to the Valley:
## a maroon body slung on leather thoroughbraces, yellow wheels, the
## driver's box up front and baggage on the roof.
func stagecoach() -> Image:
	var w := 62
	var h := 40
	var sd := 1875
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 2.5, w / 2.0 - 4.0, 2.4, 0.3)
	var body := _ramp(["2a0e10", "461618", "641e20", "822a2a", "9e3c36", "b8564a"])
	# the body, rounded at the bottom
	for xx in range(14, 48):
		for yy in range(10, 28):
			var u := float(xx - 14) / 34.0
			if yy > 24 and (u < 0.1 or u > 0.9):
				continue
			var t := 0.55 - u * 0.25 + (0.5 - float(yy - 10) / 18.0) * 0.2
			K.px(im, 14 + int(u * 34.0), yy, body[clampi(roundi(t * 5.0), 0, 5)])
	K.hline(im, 14, 10, 34, Color("d8b04a"))
	K.hline(im, 15, 26, 32, Color("d8b04a"))
	for wx in [20, 36]:
		K.rect(im, wx, 13, 7, 6, Color("1a1412"))
		K.hline(im, wx, 13, 7, Color("3a2a22"))
	K.text(im, 21, 21, "U.S. MAIL", Color("e8c860"), body[0])
	# the driver's box and footboard, and baggage on the roof under a tarp
	K.rect(im, 6, 8, 9, 3, Color("2a1e18"))
	K.rect(im, 4, 14, 8, 2, Color("2a1e18"))
	K.rect(im, 18, 5, 26, 5, Color("6a5a40"))
	K.hline(im, 18, 5, 26, Color("8a7a58"))
	K.rect(im, 46, 12, 7, 12, Color("3a2a20"))
	# wheels: big at the back, smaller in front, yellow spokes
	for wh: Array in [[46, 30, 8.5], [16, 31, 6.5]]:
		var wx: float = wh[0]
		var wy: float = wh[1]
		var r: float = wh[2]
		K.ring(im, wx, wy, r, r, Color("2a1e14"))
		K.ring(im, wx, wy, r - 1.0, r - 1.0, Color("c8962a"))
		for k in 8:
			var a := k * TAU / 8.0
			FloraArt.line(im, wx, wy, wx + cos(a) * (r - 1.5), wy + sin(a) * (r - 1.5), Color("e0b448"))
		K.rect(im, int(wx) - 1, int(wy) - 1, 2, 2, Color("3a2a1c"))
	# the pole out front
	K.hline(im, 0, 30, 10, Color("4a3a28"))
	K.outline(im, Color("1e1210"))
	return im


## A flag on the golf course's green.
func golf_flag() -> Image:
	var w := 14
	var h := 30
	var im := K.make(w, h)
	K.ellipse(im, 4.0, h - 4.0, 4.0, 1.6, Color(0.1, 0.12, 0.08, 0.35))
	K.vline(im, 3, 3, h - 6, Color("f0ece0"))
	K.vline(im, 4, 3, h - 6, Color("9a968c"))
	for yy in 6:
		for xx in 8 - yy / 2:
			K.px(im, 5 + xx, 3 + yy, Color("d8402a") if xx > 0 else Color("a82a1e"))
	K.px(im, 3, h - 3, Color("1e1a14"))
	return im


## A split-rail fence: [param horizontal] draws a 32 px run along x,
## otherwise a 16 px wide piece that stacks along y.
func rail_fence(horizontal: bool) -> Image:
	var wood := _ramp(["2e2418", "4a3a28", "665238", "84704e", "a08c66"])
	if horizontal:
		var im := K.make(32, 18)
		for py in [6, 11]:
			for xx in 32:
				K.px(im, xx, py, wood[3])
				K.px(im, xx, py + 1, wood[1])
		for px_ in [1, 17]:
			K.rect(im, px_, 3, 3, 13, wood[2])
			K.vline(im, px_, 3, 13, wood[4])
			K.vline(im, px_ + 2, 3, 13, wood[0])
		K.outline(im, Color("1e1a14"))
		return im
	var im2 := K.make(16, 32)
	K.rect(im2, 6, 2, 3, 28, wood[3])
	K.vline(im2, 6, 2, 28, wood[4])
	K.vline(im2, 8, 2, 28, wood[1])
	for py in [4, 20]:
		K.rect(im2, 5, py, 5, 8, wood[2])
		K.vline(im2, 5, py, 8, wood[4])
	K.outline(im2, Color("1e1a14"))
	return im2


## The Mariposa Grove shuttle: a green-and-cream bus at the plaza.
func grove_shuttle() -> Image:
	var w := 72
	var h := 32
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 2.5, w / 2.0 - 3.0, 2.4, 0.3)
	var green := _ramp(["14281c", "1e3a28", "2a5034", "3a6844", "4e8056", "6a9a6c"])
	for xx in range(3, w - 3):
		for yy in range(4, h - 8):
			var t := 0.6 - float(xx) / w * 0.2
			var col := green[clampi(roundi(t * 5.0), 0, 5)]
			if yy > 14:
				col = white[4] if xx < w - 10 else white[2]
			K.px(im, xx, yy, col)
	K.hline(im, 4, 4, w - 8, green[5])
	for wx in range(8, w - 12, 9):
		K.rect(im, wx, 7, 7, 6, sky[2])
		K.px(im, wx + 1, 8, sky[4])
	K.rect(im, w - 10, 6, 6, 14, Color("1e2a30"))
	for wx in [14, w - 16]:
		K.ellipse(im, wx, h - 7, 4.0, 4.0, Color("1e1e20"))
		K.px(im, wx, h - 7, Color("8a8a8e"))
	K.text(im, 12, 16, "GROVE SHUTTLE", green[1], Color(0, 0, 0, 0))
	K.outline(im, Color("101814"))
	return im


## A hitching rail for the stage horses.
func hitching_rail() -> Image:
	var im := K.make(34, 14)
	var wood := _ramp(["2e2418", "4a3a28", "665238", "84704e", "a08c66"])
	K.hline(im, 1, 4, 32, wood[3])
	K.hline(im, 1, 5, 32, wood[1])
	for px_ in [3, 29]:
		K.rect(im, px_, 4, 3, 9, wood[2])
		K.vline(im, px_, 4, 9, wood[4])
	K.outline(im, Color("1e1a14"))
	return im
