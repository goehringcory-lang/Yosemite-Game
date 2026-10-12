extends RefCounted
## Pixel art for Curry Village: the Registration Office, Camp Curry Store,
## Mountain Shop, Pavilion, Pizza Deck and amphitheater, tent cabins and wood
## cabins, and the props that fill the camp. Drawn in code with PixelKit in a
## warm palette and a dark brown outline, in the same 3/4 view as the tiles:
## roof above, wall below, standing on its base. Written to
## assets/sprites/curry/. Replace any PNG with hand-drawn art of the same size.

const K = preload("res://tools/hubs/pixel_kit.gd")
const DIR := "res://assets/sprites/curry/"

# Camp Curry green, Mountain Shop slate, stained wood, canvas.
const GREEN_ROOF := "4c7a4a"
const SLATE_ROOF := "5f6b78"
const BROWN_ROOF := "8a5a3c"
const WOOD := "9a6c44"
const WOOD_DARK := "6e4a2e"
const CREAM := "eadcb4"
const CANVAS := "eee6cf"
## Tent cabins are drawn one by one so every plate carries its own number.
const TENT_SPRITES := 64


static func c(hex: String) -> Color:
	return Color(hex)


func save_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var sheets := {
		"registration": registration(), "store": store(), "mountain_shop": mountain_shop(),
		"pavilion": pavilion(), "pizza_deck": pizza_deck(), "amphitheater": amphitheater(),
		"entrance_sign": entrance_sign(), "apple_tree": apple_tree(), "firefall_board": firefall_board(),
		"gear_rack": gear_rack(), "flagpole": flagpole_sheet(), "lamp_post": lamp_post(), "bike_rack": bike_rack(),
		"woodpile": woodpile(), "clothesline": clothesline(), "bench": bench(), "planter": planter(),
		"trail_post_closed": trail_post("CLOSED", "", c("b03a2a")), "trail_post_cabins": trail_post("CABINS", "", c("4c7a4a")),
		"trail_post_apron": trail_post("APRON", "TRAIL", c("8a6440")), "trail_post_home": trail_post("HOME", "CAMP", c("8a6440")),
		"patio_table": patio_table(), "string_lights_224": string_lights(224), "string_lights_176": string_lights(176), "string_lights_112": string_lights(112), "cooler": cooler(), "fountain": fountain(), "pool": pool(), "ice_rink": ice_rink(),
		"fence_h": fence_h(), "fence_v": fence_v(), "rope_fence": rope_fence(), "stump": stump(),
		"cabin_a": wood_cabin(0), "cabin_b": wood_cabin(1),
	}
	for i in TENT_SPRITES:
		sheets["tent_cabin_%d" % i] = tent_cabin(i)
	var paints := [c("2f8fa8"), c("c8402e"), c("efe2b8"), c("3f6a4a"), c("d8a030"), c("5a6a8a"), c("8a3a3a"), c("b8b0a0")]
	for i in 12:
		sheets["car_%d" % i] = car(i % 5, paints[(i * 3) % paints.size()])
	sheets["store_foods"] = store_foods()
	for i in 4:
		sheets["chair_%d" % i] = chair(i)
		sheets["planter_%d" % i] = planter(i)
	for sprite_name: String in sheets:
		(sheets[sprite_name] as Image).save_png(ProjectSettings.globalize_path(DIR + sprite_name + ".png"))


# ---------------------------------------------------------------- common pieces

## The wall/roof silhouette shared by the buildings: roof seen from above with
## a lit ridge, then an eave shadow on the wall below. Returns wall_top.
func _roof_and_eave(im: Image, w: int, roof_h: int, roof: Color, seed_value: int, taper := 0.22) -> int:
	K.shingles(im, 0, 0, w, roof_h, roof, seed_value, taper)
	# eave: darker fascia and a soft shadow on the wall
	K.hline(im, 0, roof_h, w, roof.darkened(0.5))
	K.hline(im, 1, roof_h + 1, w - 2, Color(0, 0, 0, 0.32))
	K.hline(im, 1, roof_h + 2, w - 2, Color(0, 0, 0, 0.16))
	return roof_h + 1


func _ground_shadow(im: Image, w: int, h: int) -> void:
	K.shadow(im, w / 2.0, h - 1.5, w / 2.0 - 1.0, 2.2)


func _chimney(im: Image, x: int, top: int, h: int, stone: Color) -> void:
	K.stones(im, x, top, 7, h, stone, 11)
	K.rect(im, x - 1, top - 1, 9, 2, stone.darkened(0.3))
	K.hline(im, x - 1, top - 1, 9, stone.lightened(0.12))


# ---------------------------------------------------------------- buildings

## Camp Curry's Registration Office: a broad, low board-and-batten lodge with a
## porch, green shingles, and a clock over the door.
func registration() -> Image:
	var w := 88
	var h := 64
	var im := K.make(w, h)
	_ground_shadow(im, w, h)
	var roof_h := 26
	var wall_top := _roof_and_eave(im, w, roof_h, c(GREEN_ROOF), 3, 0.2)
	var wall_h := h - wall_top - 3
	K.boards(im, 3, wall_top, w - 6, wall_h, c("a67a4c"), 4)
	# stone foundation
	K.stones(im, 3, h - 8, w - 6, 6, c("8d857a"), 5)
	# porch: beam, posts, and a deck
	K.rect(im, 1, wall_top + 2, w - 2, 3, c("7a5232"))
	K.hline(im, 1, wall_top + 2, w - 2, c("a67a4c"))
	for px_x in [4, 24, 43, 62, 81]:
		K.rect(im, px_x, wall_top + 5, 3, wall_h - 8, c("7a5232"))
		K.vline(im, px_x, wall_top + 5, wall_h - 8, c("a67a4c"))
	K.rect(im, 1, h - 10, w - 2, 3, c("8a6440"))
	K.hline(im, 1, h - 10, w - 2, c("b58a58"))
	# windows between posts
	for wx in [9, 29, 56, 70]:
		K.window(im, wx, wall_top + 8, 8, 9, c("f0e6c8"), c("6a8caa"), c("d8b0a0"), c("4c7a4a"))
	# double door with a transom, under a clock
	K.door(im, w / 2 - 6, h - 24, 12, 15, c("7a4a2e"), c("f0e6c8"), true)
	K.rect(im, w / 2 - 6, h - 28, 12, 3, c("f2e2a0"))
	K.hline(im, w / 2 - 6, h - 28, 12, c("f0e6c8"))
	K.ellipse(im, w / 2.0, wall_top + 5.0, 3.6, 3.6, c("f0e6c8"))
	K.ellipse(im, w / 2.0, wall_top + 5.0, 2.6, 2.6, c("faf4e0"))
	K.vline(im, w / 2, wall_top + 3, 3, c("2a1f1a"))
	K.hline(im, w / 2, wall_top + 5, 2, c("2a1f1a"))
	# hanging sign
	K.sign_board(im, w / 2 - 22, wall_top - 10, 44, "REGISTRATION", c("4c6a48"), c("f4ecd0"), 9)
	K.vline(im, w / 2 - 20, wall_top - 12, 2, c("3a2c22"))
	K.vline(im, w / 2 + 19, wall_top - 12, 2, c("3a2c22"))
	_chimney(im, 14, 2, 13, c("8d857a"))
	K.lantern(im, 6, wall_top + 6)
	K.lantern(im, w - 7, wall_top + 6)
	K.outline(im)
	return im


## Camp Curry Store: groceries and gifts, with a striped awning, produce crates,
## and a chalkboard.
func store() -> Image:
	var w := 68
	var h := 58
	var im := K.make(w, h)
	_ground_shadow(im, w, h)
	var roof_h := 22
	var wall_top := _roof_and_eave(im, w, roof_h, c(GREEN_ROOF), 6, 0.24)
	K.lap(im, 3, wall_top, w - 6, h - wall_top - 3, c("efe3bb"), 8)
	K.stones(im, 3, h - 7, w - 6, 5, c("8d857a"), 9)
	# sign under the eave
	K.sign_board(im, w / 2 - 20, wall_top + 1, 40, "CURRY STORE", c("3c5a3c"), c("f4ecd0"), 9)
	# windows with displays either side of the door
	K.window(im, 8, wall_top + 13, 14, 12, c("6e4a2e"), c("8fb0c4"), Color(0, 0, 0, 0), Color(0, 0, 0, 0), true)
	K.window(im, w - 22, wall_top + 13, 14, 12, c("6e4a2e"), c("8fb0c4"), Color(0, 0, 0, 0), Color(0, 0, 0, 0), true)
	for jar in [[10, 22, "d8a040"], [14, 22, "c05a3a"], [18, 22, "8a6ad0"], [w - 20, 22, "d8a040"], [w - 16, 22, "5a9a4a"], [w - 12, 22, "c05a3a"]]:
		K.rect(im, jar[0], wall_top + jar[1] - 2, 2, 3, c(jar[2]))
	K.door(im, w / 2 - 5, h - 22, 10, 14, c("7a4a2e"), c("f4ecd0"), true)
	K.awning(im, 4, wall_top + 26, w - 8, 5, c("4c8a4a"), c("f2ecd6"))
	# produce crates and a chalkboard out front
	K.crate(im, 5, h - 12, 10, 7, c("b0824c"))
	for berry in [[7, h - 13], [9, h - 13], [11, h - 13], [13, h - 13]]:
		K.px(im, berry[0], berry[1], c("d04a3a"))
		K.px(im, berry[0] + 1, berry[1] - 1, c("e86a4a"))
	K.crate(im, w - 16, h - 12, 10, 7, c("b0824c"))
	for apple in [[w - 14, h - 13], [w - 12, h - 13], [w - 10, h - 13], [w - 8, h - 13]]:
		K.px(im, apple[0], apple[1], c("e0c050"))
		K.px(im, apple[0] + 1, apple[1] - 1, c("f0d870"))
	K.rect(im, w / 2 + 9, h - 14, 8, 9, c("2f3a34"))
	K.rect(im, w / 2 + 9, h - 14, 8, 1, c("8a6440"))
	K.hline(im, w / 2 + 10, h - 12, 5, c("e8e0c8"))
	K.hline(im, w / 2 + 10, h - 10, 6, c("e8e0c8"))
	K.hline(im, w / 2 + 10, h - 8, 4, c("e8e0c8"))
	K.lantern(im, 3, wall_top + 18)
	K.outline(im)
	return im


## The Mountain Shop: slate roof, dark timber over a stone base, a big display
## window full of gear, ropes coiled on the wall, and a carabiner sign.
func mountain_shop() -> Image:
	var w := 84
	var h := 66
	var im := K.make(w, h)
	_ground_shadow(im, w, h)
	var roof_h := 26
	var wall_top := _roof_and_eave(im, w, roof_h, c(SLATE_ROOF), 12, 0.26)
	K.boards(im, 3, wall_top, w - 6, h - wall_top - 3, c("5e4632"), 13)
	K.stones(im, 3, h - 14, w - 6, 12, c("8b8578"), 14)
	# timber framing
	for bx in [3, 27, 58, w - 6]:
		K.rect(im, bx, wall_top, 3, h - wall_top - 3, c("3e2c1e"))
		K.vline(im, bx, wall_top, h - wall_top - 3, c("6a4c34"))
	K.hline(im, 3, wall_top + 12, w - 6, c("3e2c1e"))
	# hanging sign with crossed axes
	K.rect(im, w / 2 - 29, wall_top - 12, 58, 12, c("2a3a44"))
	K.rect(im, w / 2 - 28, wall_top - 11, 56, 10, c("36505e"))
	K.text_centered(im, w / 2 - 28, 56, wall_top - 9, "MOUNTAIN SHOP", c("f4ecd0"), c("1c2a32"))
	K.hline(im, w / 2 - 28, wall_top - 11, 56, c("5a7a8a"))
	# carabiner motif each side of the sign
	for sx in [w / 2 - 37, w / 2 + 33]:
		K.rect(im, sx, wall_top - 10, 5, 8, c("b8c0c8"))
		K.rect(im, sx + 1, wall_top - 9, 3, 6, c("36505e"))
		K.px(im, sx + 4, wall_top - 7, c("e8eef2"))
		K.px(im, sx, wall_top - 4, c("8a929a"))
	# the big display window, left
	K.rect(im, 8, wall_top + 15, 30, 22, c("2e2016"))
	K.rect(im, 9, wall_top + 16, 28, 20, c("2a3a44"))
	K.rect(im, 9, wall_top + 16, 28, 20, c("8fb4c8"))
	for hx in [9, 23, 37]:
		K.vline(im, hx, wall_top + 16, 20, c("2e2016"))
	K.hline(im, 9, wall_top + 28, 28, c("2e2016"))
	K.rect(im, 9, wall_top + 16, 28, 2, c("b8d4e0"))
	# gear in the window: rope coils, a pack, cams on a rack
	K.ellipse(im, 15, wall_top + 32, 4, 3, c("c8402e"))
	K.ellipse(im, 15, wall_top + 32, 1.5, 1, c("8fb4c8"))
	K.ellipse(im, 15, wall_top + 32, 3.2, 2.2, c("e05a44"))
	K.ellipse(im, 15, wall_top + 32, 1.4, 0.8, c("8fb4c8"))
	K.rect(im, 22, wall_top + 26, 7, 10, c("3a78c0"))
	K.rect(im, 22, wall_top + 26, 7, 2, c("5a98e0"))
	K.rect(im, 24, wall_top + 30, 3, 3, c("2a5a90"))
	for cx in [31, 33, 35]:
		K.rect(im, cx, wall_top + 24, 1, 4, c("c0c4c8"))
		K.px(im, cx, wall_top + 28, c("e0a030"))
		K.px(im, cx, wall_top + 23, c("e04a3a"))
	for dx in [12, 16, 20, 24]:
		K.rect(im, dx, wall_top + 20, 1, 3, c("d8d8d0"))
		K.px(im, dx, wall_top + 23, c("e0a030"))
	K.hline(im, 9, wall_top + 34, 28, c("6e4a2e"))
	# door, right, with a rope coil hung beside it
	K.door(im, 56, h - 26, 12, 20, c("6a4228"), c("3e2c1e"), true)
	K.rect(im, 54, h - 6, 16, 2, c("8d857a"))
	K.ellipse(im, 74, wall_top + 24, 4.4, 5, c("c8402e"))
	K.ellipse(im, 74, wall_top + 24, 3.0, 3.6, c("e05a44"))
	K.ellipse(im, 74, wall_top + 24, 1.2, 1.6, c("5e4632"))
	K.px(im, 72, wall_top + 22, c("f08a70"))
	# window boxes, lanterns, and an ice axe on the wall
	K.lantern(im, 50, wall_top + 16)
	K.lantern(im, 5, wall_top + 16)
	K.vline(im, 46, wall_top + 16, 10, c("8a929a"))
	K.rect(im, 44, wall_top + 15, 5, 2, c("8a929a"))
	K.px(im, 44, wall_top + 17, c("8a929a"))
	# chimney with a stone cap
	_chimney(im, w - 20, 2, 12, c("8b8578"))
	K.outline(im)
	return im


## Pavilion: the big open dining hall, with lanterns strung across the front
## and tables in the warm dark inside.
func pavilion() -> Image:
	var w := 104
	var h := 66
	var im := K.make(w, h)
	_ground_shadow(im, w, h)
	var roof_h := 30
	var wall_top := _roof_and_eave(im, w, roof_h, c(BROWN_ROOF), 15, 0.2)
	# dark open interior
	K.rect(im, 4, wall_top, w - 8, h - wall_top - 4, c("3a2a1e"))
	K.rect(im, 4, wall_top, w - 8, 3, c("241812"))
	for tx in [10, 30, 50, 70]:
		K.rect(im, tx, h - 22, 14, 5, c("8a6440"))
		K.hline(im, tx, h - 22, 14, c("b58a58"))
		K.vline(im, tx + 1, h - 17, 6, c("5a3e28"))
		K.vline(im, tx + 12, h - 17, 6, c("5a3e28"))
		K.rect(im, tx + 5, h - 24, 4, 2, c("e8dcb8"))
	# warm lamplight glow
	for gx in range(6, w - 6, 8):
		K.rect(im, gx, wall_top + 4, 1, 6, c("3a2c22"))
		K.rect(im, gx - 1, wall_top + 9, 3, 3, c("ffd870"))
		K.px(im, gx, wall_top + 12, Color(1, 0.85, 0.4, 0.5))
	K.hline(im, 4, wall_top + 4, w - 8, c("3a2c22"))
	# rough log posts and a low stone wall
	for pxx in range(3, w - 3, 20):
		K.rect(im, pxx, wall_top, 4, h - wall_top - 4, c("7a5232"))
		K.vline(im, pxx, wall_top, h - wall_top - 4, c("b0824c"))
		K.vline(im, pxx + 3, wall_top, h - wall_top - 4, c("4e3220"))
	K.stones(im, 3, h - 8, w - 6, 6, c("8d857a"), 21)
	# entrance gap with steps and the sign
	K.rect(im, w / 2 - 8, h - 8, 16, 4, c("b0a692"))
	K.sign_board(im, w / 2 - 20, wall_top - 12, 40, "PAVILION", c("5a3a22"), c("f4ecd0"), 10)
	K.vline(im, w / 2 - 18, wall_top - 14, 2, c("3a2c22"))
	K.vline(im, w / 2 + 17, wall_top - 14, 2, c("3a2c22"))
	_chimney(im, w - 20, 2, 15, c("8d857a"))
	K.outline(im)
	return im


func pizza_deck() -> Image:
	var w := 64
	var h := 50
	var im := K.make(w, h)
	_ground_shadow(im, w, h)
	var roof_h := 18
	var wall_top := _roof_and_eave(im, w, roof_h, c("a64a38"), 17, 0.28)
	K.lap(im, 4, wall_top, w - 8, 14, c("d8c8a0"), 18)
	K.sign_board(im, w / 2 - 14, wall_top + 2, 28, "PIZZA", c("3c5a3c"), c("f4ecd0"), 8)
	K.rect(im, w / 2 - 5, wall_top + 12, 11, 5, c("5a3a2a"))
	K.rect(im, w / 2 - 4, wall_top + 13, 9, 3, c("d8702a"))
	K.px(im, w / 2, wall_top + 14, c("ffe090"))
	# the deck with rails and two umbrella tables
	K.rect(im, 2, h - 20, w - 4, 16, c("a07a4c"))
	for dy in range(0, 16, 3):
		K.hline(im, 2, h - 20 + dy, w - 4, c("8a6640"))
	K.hline(im, 2, h - 20, w - 4, c("c4996a"))
	K.rect(im, 2, h - 8, w - 4, 4, c("7a5232"))
	for rx in range(4, w - 2, 6):
		K.rect(im, rx, h - 10, 2, 6, c("5a3a22"))
	for tx in [10, 38]:
		K.ellipse(im, tx + 8, h - 15, 8, 3, c("d8442a"))
		K.ellipse(im, tx + 8, h - 15, 5, 1.6, c("f2ecd6"))
		K.ellipse(im, tx + 8, h - 16, 2, 1, c("e86a4a"))
		K.rect(im, tx + 8, h - 15, 1, 8, c("5a3a22"))
		K.ellipse(im, tx + 8, h - 9, 5, 2, c("8a6440"))
	K.outline(im)
	return im


func amphitheater() -> Image:
	var w := 96
	var h := 62
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 2.0, w / 2.0 - 2, 3.0)
	# stone terrace under everything
	K.rect(im, 0, 20, w, h - 21, c("b7ab94"))
	for y in range(20, h - 1, 5):
		K.hline(im, 0, y, w, c("a29782"))
	# the stage: a raised wood platform with a plank backdrop and curtains
	K.rect(im, 18, 2, 60, 22, c("5a3a22"))
	K.boards(im, 19, 3, 58, 13, c("946840"), 22, 5)
	K.rect(im, 19, 3, 9, 13, c("a83a3a"))
	K.rect(im, 68, 3, 9, 13, c("a83a3a"))
	for cx in [21, 24, 27, 70, 73, 76]:
		K.vline(im, cx, 3, 13, c("7a2a2a"))
	K.rect(im, 19, 0, 58, 4, c("4c7a4a"))
	K.text_centered(im, 19, 58, 0, "CAMP CURRY", c("f4ecd0"), c("2f4a30"))
	K.rect(im, 16, 16, 64, 7, c("b0824c"))
	K.hline(im, 16, 16, 64, c("d8aa78"))
	K.hline(im, 16, 22, 64, c("5a3a22"))
	K.lantern(im, 17, 12)
	K.lantern(im, 78, 12)
	# a stone aisle with steps down the middle
	K.rect(im, w / 2 - 4, 24, 8, h - 25, c("d2c8b0"))
	for y in range(26, h - 2, 4):
		K.hline(im, w / 2 - 4, y, 8, c("9c917c"))
	# benches: short lit boards in rows, with backs, on either side of the aisle
	for row in 5:
		var y := 28 + row * 6
		for side in [-1, 1]:
			var bx: int = w / 2 + side * 7
			var length := 34 + row * 2
			var x0: int = bx if side > 0 else bx - length
			for seg in range(0, length, 9):
				var sl := mini(8, length - seg)
				K.rect(im, x0 + seg, y, sl, 2, c("c4996a"))
				K.hline(im, x0 + seg, y, sl, c("e0b988"))
				K.hline(im, x0 + seg, y + 2, sl, c("6e4a2e"))
				K.px(im, x0 + seg + 1, y + 3, c("4a321e"))
				K.px(im, x0 + seg + sl - 2, y + 3, c("4a321e"))
	K.outline(im)
	return im


## The old arch over the road in: two log posts and a painted plank sign.
func entrance_sign() -> Image:
	var w := 72
	var h := 46
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 2.0, w / 2.0 - 3, 2.2)
	for pxx in [3, w - 8]:
		K.rect(im, pxx, 14, 5, h - 16, c("7a5232"))
		K.vline(im, pxx, 14, h - 16, c("b0824c"))
		K.vline(im, pxx + 4, 14, h - 16, c("4e3220"))
		K.rect(im, pxx - 2, h - 6, 9, 4, c("8d857a"))
		K.hline(im, pxx - 2, h - 6, 9, c("b0a692"))
	K.rect(im, 1, 1, w - 2, 19, c("4a3020"))
	K.rect(im, 2, 2, w - 4, 17, c("5c7a4c"))
	K.hline(im, 2, 2, w - 4, c("7c9a68"))
	K.text_centered(im, 2, w - 4, 5, "CAMP CURRY", c("f6ecd0"), c("2f4a30"))
	K.text_centered(im, 2, w - 4, 13, "EST 1899", c("e8d8a0"))
	K.rect(im, 14, 20, 2, 4, c("3a2c22"))
	K.rect(im, w - 16, 20, 2, 4, c("3a2c22"))
	K.lantern(im, 14, 23)
	K.lantern(im, w - 15, 23)
	K.outline(im)
	return im


func apple_tree() -> Image:
	var w := 36
	var h := 42
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 3.0, 12.0, 3.0)
	# gnarled trunk
	K.rect(im, w / 2 - 2, 22, 5, 17, c("6b4a2f"))
	K.vline(im, w / 2 - 2, 22, 17, c("8a6440"))
	K.vline(im, w / 2 + 2, 22, 17, c("4a321e"))
	K.rect(im, w / 2 - 5, 34, 4, 5, c("6b4a2f"))
	K.rect(im, w / 2 + 3, 35, 4, 4, c("4a321e"))
	# canopy: layered lit blobs
	var rng := RandomNumberGenerator.new()
	rng.seed = 1899
	for blob in [[18, 14, 13, 11], [10, 17, 8, 7], [26, 17, 8, 7], [18, 8, 8, 6]]:
		for y in range(blob[1] - blob[3], blob[1] + blob[3] + 1):
			for x in range(blob[0] - blob[2], blob[0] + blob[2] + 1):
				var dx: float = float(x - blob[0]) / blob[2]
				var dy: float = float(y - blob[1]) / blob[3]
				if dx * dx + dy * dy > 1.0:
					continue
				var lit: float = -dx * 0.6 - dy * 0.8 + rng.randf_range(-0.28, 0.28)
				K.px(im, x, y, c("9ad05a") if lit > 0.45 else (c("6ead44") if lit > -0.25 else c("467f34")))
	for apple in [[10, 16], [16, 11], [24, 15], [20, 20], [13, 22], [27, 22], [18, 15]]:
		K.px(im, apple[0], apple[1], c("d8342a"))
		K.px(im, apple[0] + 1, apple[1], c("f0604a"))
		K.px(im, apple[0], apple[1] + 1, c("a02420"))
	K.outline(im)
	return im


func firefall_board() -> Image:
	var w := 34
	var h := 34
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 2.0, 12.0, 2.0)
	K.rect(im, 5, 24, 3, 9, c("5a3a22"))
	K.rect(im, w - 8, 24, 3, 9, c("5a3a22"))
	K.rect(im, 1, 3, w - 2, 23, c("4a3020"))
	K.rect(im, 2, 4, w - 4, 21, c("22262e"))
	# a night painting: the wall, a ribbon of embers falling
	for i in 18:
		var x := 3 + i
		K.rect(im, x, 5, 1, 16, c("2c3140"))
	K.rect(im, 3, 5, 12, 4, c("3a4054"))
	K.rect(im, 20, 5, 11, 7, c("3a4054"))
	for k in 15:
		var y := 6 + k
		var ex := 18 + int(sin(k * 0.8) * 1.0)
		K.px(im, ex, y, c("ffb03a") if k % 3 else c("ffe070"))
		K.px(im, ex + 1, y + (k % 2), c("e8602a"))
	K.rect(im, 14, 5, 5, 2, c("ffe9a0"))
	K.px(im, 5, 22, c("f0d060"))
	K.px(im, 8, 21, c("f0d060"))
	K.hline(im, 4, 22, 26, c("14161c"))
	K.outline(im)
	return im


func gear_rack() -> Image:
	var w := 34
	var h := 26
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 2.0, 15.0, 2.0)
	K.rect(im, 2, 4, 3, 20, c("5a3a22"))
	K.rect(im, w - 5, 4, 3, 20, c("5a3a22"))
	K.rect(im, 1, 3, w - 2, 3, c("7a5232"))
	K.hline(im, 1, 3, w - 2, c("b0824c"))
	K.rect(im, 1, 14, w - 2, 2, c("6e4a2e"))
	# hung gear: ropes, slings, quickdraws, cams, a pack below
	for rx in [7, 14]:
		K.ellipse(im, rx, 10, 3, 4, c("c8402e"))
		K.ellipse(im, rx, 10, 1.3, 2, c("2a1f1a"))
	for sx in [20, 23, 26]:
		K.rect(im, sx, 6, 1, 6, c("c0c4c8"))
		K.px(im, sx, 12, c("e0a030"))
		K.px(im, sx, 5, c("3a78c0"))
	K.rect(im, 28, 6, 2, 8, c("3a9a5a"))
	for qx in [7, 11, 15, 19, 23, 27]:
		K.rect(im, qx, 17, 1, 3, c("c8c8c0"))
		K.px(im, qx, 20, c("d84a3a"))
	K.rect(im, 8, 19, 9, 5, c("d0702a"))
	K.rect(im, 8, 19, 9, 1, c("f0904a"))
	K.rect(im, 20, 19, 9, 5, c("3a78c0"))
	K.rect(im, 20, 19, 9, 1, c("5a98e0"))
	K.outline(im)
	return im


## Three frames of a flag in the breeze, side by side (24 px each).
func flagpole_sheet() -> Image:
	var sheet := K.make(72, 50)
	for f in 3:
		K.stamp(sheet, flagpole(f), f * 24, 0)
	return sheet


func flagpole(phase := 0) -> Image:
	var im := K.make(24, 50)
	K.shadow(im, 5.0, 47.0, 4.0, 1.4)
	K.rect(im, 4, 4, 2, 44, c("c8c4b8"))
	K.vline(im, 4, 4, 44, c("eeeae0"))
	K.ellipse(im, 5, 3, 1.6, 1.6, c("e0c060"))
	# the flag, mid-wave, rippling along a different phase in each frame
	# red and white stripes running along it, shaded where the cloth turns
	for x in 16:
		var wave := int(round(sin(x * 0.55 - phase * 2.1) * (0.6 + x * 0.09)))
		var turned := cos(x * 0.55 - phase * 2.1) < -0.3
		for row in 9:
			var red := row % 2 == 0
			var col := c("b8403c") if red else c("f2ece0")
			if turned:
				col = col.darkened(0.16)
			K.px(im, 6 + x, 6 + wave + row, col)
		if x > 0:
			K.px(im, 6 + x, 15 + wave, c("7a2a2a"))
	K.rect(im, 7, 8 + int(round(sin(-phase * 2.1) * 0.6)), 6, 5, c("2a3a7a"))
	for i in 3:
		K.px(im, 8 + i * 2, 9 + int(round(sin(-phase * 2.1) * 0.6)), c("f0f0f0"))
		K.px(im, 9 + i * 2, 11 + int(round(sin(-phase * 2.1) * 0.6)), c("f0f0f0"))
	K.rect(im, 2, 46, 6, 3, c("8d857a"))
	K.outline(im)
	return im


func lamp_post() -> Image:
	var im := K.make(12, 34)
	K.shadow(im, 6.0, 31.0, 4.0, 1.4)
	K.rect(im, 5, 10, 2, 22, c("2f3a34"))
	K.rect(im, 3, 30, 6, 2, c("2f3a34"))
	K.rect(im, 2, 3, 8, 8, c("2f3a34"))
	K.rect(im, 3, 4, 6, 6, c("ffe08a"))
	K.rect(im, 4, 5, 4, 3, c("fff4c0"))
	K.rect(im, 1, 2, 10, 2, c("4a3a2a"))
	K.px(im, 5, 1, c("4a3a2a"))
	K.outline(im)
	return im


func bike_rack() -> Image:
	var im := K.make(36, 20)
	K.shadow(im, 18.0, 17.0, 16.0, 1.8)
	K.rect(im, 2, 15, 32, 2, c("6a6a72"))
	K.hline(im, 2, 15, 32, c("9a9aa2"))
	for i in 3:
		var x := 4 + i * 10
		var frame: Color = [c("c8402e"), c("3a78c0"), c("e0b030")][i]
		K.ring(im, x + 2.5, 11.5, 3.3, 3.3, c("2a2a30"))
		K.ring(im, x + 7.5, 11.5, 3.3, 3.3, c("2a2a30"))
		K.px(im, x + 2, 11, c("c8c4b8"))
		K.px(im, x + 7, 11, c("c8c4b8"))
		for k in 5:
			K.px(im, x + 2 + k, 6 + (k if k < 3 else 6 - k) + 2, frame)
		K.vline(im, x + 5, 5, 4, frame)
		K.hline(im, x + 4, 4, 3, c("2a2a30"))
		K.hline(im, x + 1, 8, 3, c("2a2a30"))
	K.outline(im)
	return im


func woodpile() -> Image:
	var im := K.make(24, 16)
	K.shadow(im, 12.0, 14.0, 10.0, 1.6)
	for row in 3:
		for i in 5 - row:
			var x := 2 + i * 4 + row * 2
			K.ellipse(im, x + 2.0, 11.0 - row * 3.0, 2.2, 1.9, c("b0824c") if (i + row) % 2 else c("a07040"))
			K.px(im, x + 2, 11 - row * 3, c("e0c090"))
	K.rect(im, 1, 12, 22, 2, c("6e4a2e"))
	K.outline(im)
	return im


func clothesline() -> Image:
	var im := K.make(40, 26)
	K.shadow(im, 20.0, 24.0, 17.0, 1.6)
	for pxx in [3, 35]:
		K.rect(im, pxx, 4, 2, 20, c("6e4a2e"))
	K.hline(im, 4, 6, 32, c("e0d8c0"))
	K.px(im, 20, 7, c("e0d8c0"))
	var cloth := [[7, "c8402e", 8, 8], [17, "f2ecd6", 7, 10], [26, "3a78c0", 7, 7], [33, "e0b030", 3, 8]]
	for cl in cloth:
		K.rect(im, cl[0], 7, cl[2], cl[3], c(cl[1]))
		K.hline(im, cl[0], 7, cl[2], c(cl[1]).lightened(0.2))
		K.hline(im, cl[0], 7 + cl[3] - 1, cl[2], c(cl[1]).darkened(0.25))
	K.outline(im)
	return im


func bench() -> Image:
	var im := K.make(28, 14)
	K.shadow(im, 14.0, 12.0, 12.0, 1.6)
	K.rect(im, 2, 1, 24, 3, c("a0764a"))
	K.hline(im, 2, 1, 24, c("c4996a"))
	K.rect(im, 1, 5, 26, 3, c("b0824c"))
	K.hline(im, 1, 5, 26, c("d0a06a"))
	K.hline(im, 1, 8, 26, c("6e4a2e"))
	for lx in [3, 22]:
		K.rect(im, lx, 8, 3, 4, c("5a3a22"))
		K.rect(im, lx, 1, 2, 8, c("5a3a22"))
	K.outline(im)
	return im


func planter(_variant := 0) -> Image:
	var im := K.make(18, 20)
	K.shadow(im, 9.0, 18.0, 7.0, 1.6)
	K.barrel(im, 3, 9, 12, 9, c("9a6c44"))
	K.rect(im, 3, 8, 12, 2, c("6e4a2e"))
	for f in [[4, 4, "e04a6a"], [8, 2, "f2d25c"], [12, 4, "b06ad0"], [6, 6, "f2ecd6"], [10, 6, "e04a6a"], [14, 7, "f2d25c"]]:
		K.rect(im, f[0], f[1], 2, 2, c(f[2]))
		K.px(im, f[0], f[1] + 2, c("4a8a3a"))
	K.rect(im, 4, 7, 10, 2, c("5a9a44"))
	K.outline(im)
	return im


## A fingerpost with one or two painted boards.
func trail_post(top: String, bottom: String, board: Color) -> Image:
	var tw := maxi(K.text_width(top), K.text_width(bottom)) + 7
	var w := maxi(tw + 4, 24)
	var h := 36
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 3.0, 6.0, 1.4)
	K.rect(im, w / 2 - 1, 6, 3, h - 8, c("6e4a2e"))
	K.vline(im, w / 2 - 1, 6, h - 8, c("a0764a"))
	K.rect(im, w / 2 - 3, h - 5, 7, 2, c("8d857a"))
	var y := 4
	for label in [top, bottom]:
		if label == "":
			continue
		var bw := K.text_width(label) + 7
		var bx := (w - bw) / 2
		K.rect(im, bx, y, bw, 9, board.darkened(0.4))
		K.rect(im, bx + 1, y + 1, bw - 2, 7, board)
		K.hline(im, bx + 1, y + 1, bw - 2, board.lightened(0.2))
		K.px(im, bx + bw, y + 4, board.darkened(0.4))
		K.text(im, bx + 3, y + 2, label, c("f6ecd0"), board.darkened(0.35))
		y += 11
	K.outline(im)
	return im


## A round patio table under a striped umbrella, with two chairs.
func patio_table() -> Image:
	var im := K.make(28, 34)
	K.shadow(im, 14.0, 30.0, 11.0, 2.4)
	K.rect(im, 13, 12, 2, 18, c("6e4a2e"))
	K.ellipse(im, 14.0, 26.0, 8.0, 3.0, c("b0824c"))
	K.ellipse(im, 14.0, 25.4, 7.0, 2.4, c("d0a06a"))
	for chair in [[3, 27], [21, 27]]:
		K.rect(im, chair[0], chair[1] - 5, 4, 5, c("8a6440"))
		K.rect(im, chair[0], chair[1], 4, 2, c("a0764a"))
	# umbrella canopy: alternating wedges
	for row in 8:
		var half := 6 + row * 1.2
		for x in range(int(14 - half), int(14 + half) + 1):
			var stripe := ((x + 40) / 3) % 2 == 0
			var col := c("d8442a") if stripe else c("f2ecd6")
			if row == 7:
				col = col.darkened(0.2)
			elif row < 2:
				col = col.lightened(0.1)
			K.px(im, x, 2 + row, col)
	K.px(im, 14, 1, c("6e4a2e"))
	K.px(im, 14, 0, c("e0c060"))
	K.outline(im)
	return im


## Warm bulbs strung between two poles, sagging in the middle. Drawn over
## everything, so it hangs above the people walking under it.
func string_lights(w: int) -> Image:
	var im := K.make(w, 16)
	for x in w:
		var t := float(x) / (w - 1)
		var sag := int(sin(t * PI) * 7.0)
		K.px(im, x, 2 + sag, c("3a2c22"))
		if x % 10 == 5:
			K.px(im, x, 3 + sag, c("ffe07a"))
			K.px(im, x, 4 + sag, c("ffc850"))
			K.px(im, x - 1, 3 + sag, Color(1, 0.86, 0.4, 0.4))
			K.px(im, x + 1, 3 + sag, Color(1, 0.86, 0.4, 0.4))
	K.outline(im, Color(0.16, 0.12, 0.1, 0.55))
	return im


func cooler() -> Image:
	var im := K.make(16, 12)
	K.shadow(im, 8.0, 10.0, 7.0, 1.4)
	K.rect(im, 1, 3, 14, 7, c("3a78c0"))
	K.rect(im, 1, 3, 14, 2, c("f0ecdc"))
	K.rect(im, 1, 2, 14, 1, c("e8e4d4"))
	K.rect(im, 6, 1, 4, 1, c("2a5a90"))
	K.vline(im, 3, 5, 5, c("2a5a90"))
	K.vline(im, 12, 5, 5, c("2a5a90"))
	K.outline(im)
	return im


func fountain() -> Image:
	var im := K.make(16, 26)
	K.shadow(im, 8.0, 24.0, 6.0, 1.5)
	K.rect(im, 5, 8, 6, 15, c("8d857a"))
	K.vline(im, 5, 8, 15, c("b0a692"))
	K.rect(im, 3, 6, 10, 4, c("a09a8e"))
	K.hline(im, 3, 6, 10, c("cfc8b8"))
	K.rect(im, 4, 7, 8, 2, c("6aa8d8"))
	K.px(im, 8, 5, c("a9dcf0"))
	K.px(im, 8, 4, c("d0eef8"))
	K.rect(im, 12, 10, 3, 2, c("c0c4c8"))
	K.outline(im)
	return im


## The swimming pool: a deck and rippled water, with two loungers.
func pool() -> Image:
	var w := 76
	var h := 52
	var im := K.make(w, h)
	K.rect(im, 0, 0, w, h, c("c9bfa8"))
	for y in range(0, h, 4):
		K.hline(im, 0, y, w, c("bab098"))
	K.rect(im, 6, 6, w - 12, h - 20, c("f2f2ea"))
	K.rect(im, 8, 8, w - 16, h - 24, c("4a9ad4"))
	for y in range(8, h - 16):
		for x in range(8, w - 8):
			var wave := sin(x * 0.5 + y * 0.8) + sin(x * 0.2 - y * 0.6)
			if wave > 1.2:
				K.px(im, x, y, c("8cc8ec"))
			elif wave < -1.5:
				K.px(im, x, y, c("3a80bc"))
	K.hline(im, 8, 8, w - 16, c("2a6aa0"))
	K.hline(im, 8, h - 17, w - 16, c("7ac0e8"))
	# lounge chairs
	for lx in [10, 26]:
		K.rect(im, lx, h - 12, 12, 5, c("f2ecd6"))
		K.rect(im, lx, h - 12, 4, 5, c("d8442a"))
		K.hline(im, lx, h - 8, 12, c("b8b0a0"))
	K.px(im, w - 14, h - 10, c("e8b040"))
	K.ellipse(im, w - 14.0, h - 10.0, 3.0, 3.0, c("e8b040"))
	K.rect(im, w - 15, h - 10, 1, 8, c("6e4a2e"))
	K.outline(im)
	return im


func fence_h() -> Image:
	var im := K.make(16, 14)
	K.rect(im, 0, 5, 16, 2, c("a0764a"))
	K.hline(im, 0, 5, 16, c("c4996a"))
	K.rect(im, 0, 9, 16, 2, c("a0764a"))
	K.hline(im, 0, 9, 16, c("c4996a"))
	K.rect(im, 0, 7, 16, 1, c("6e4a2e"))
	K.rect(im, 0, 11, 16, 1, c("6e4a2e"))
	for pxx in [0, 14]:
		K.rect(im, pxx, 2, 2, 11, c("8a6440"))
		K.px(im, pxx, 2, c("c4996a"))
	K.outline(im)
	return im


func fence_v() -> Image:
	var im := K.make(8, 20)
	K.rect(im, 3, 2, 2, 17, c("a0764a"))
	K.vline(im, 3, 2, 17, c("c4996a"))
	K.rect(im, 2, 1, 4, 3, c("8a6440"))
	K.rect(im, 2, 16, 4, 3, c("8a6440"))
	K.outline(im)
	return im


## Rope strung between short posts, to keep visitors off cordoned ground.
func rope_fence() -> Image:
	var im := K.make(16, 14)
	for pxx in [0, 13]:
		K.rect(im, pxx, 3, 3, 9, c("d8d0b8"))
		K.hline(im, pxx, 3, 3, c("f4f0e0"))
	for x in 13:
		var sag := int(sin(float(x) / 13.0 * PI) * 2.0)
		K.px(im, 2 + x, 5 + sag, c("c8402e"))
	K.outline(im)
	return im


func stump() -> Image:
	var im := K.make(16, 14)
	K.shadow(im, 8.0, 12.0, 6.0, 1.5)
	K.ellipse(im, 8.0, 8.0, 5.5, 4.5, c("7a5232"))
	K.ellipse(im, 8.0, 6.5, 5.0, 3.6, c("d0a870"))
	K.ellipse(im, 8.0, 6.5, 3.0, 2.0, c("b88a58"))
	K.ellipse(im, 8.0, 6.5, 1.0, 0.7, c("8a6440"))
	# an axe stuck in it
	K.rect(im, 10, 1, 1, 6, c("8a6440"))
	K.rect(im, 9, 1, 3, 2, c("b8c0c8"))
	K.outline(im)
	return im


# ---------------------------------------------------------------- tent cabins and cabins

## A white canvas tent cabin on a wooden platform: a peaked canvas roof over
## a wood frame, a little fly over the door, guy ropes to stakes, a hanging
## number plate, and a chair or a cooler on the deck.
func tent_cabin(variant: int) -> Image:
	var w := 46
	var h := 48
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 3.0, w / 2.0 - 3.0, 2.6)
	var canvas := c(CANVAS)
	var trim: Color = [c("5f8a5a"), c("8a6a48"), c("4f7a9a"), c("a05a48")][(variant / 2) % 4]
	var x0 := 4
	var bw := w - 8
	# guy ropes and stakes
	for side in [0, 1]:
		var sx: int = 1 if side == 0 else w - 2
		var ex: int = x0 + 2 if side == 0 else w - x0 - 3
		for t in 14:
			var px_x: int = int(lerp(float(ex), float(sx), t / 13.0))
			var px_y: int = int(lerp(20.0, float(h - 7), t / 13.0))
			K.px(im, px_x, px_y, c("d8cdb0"))
		K.rect(im, sx - 1, h - 8, 2, 4, c("6e4a2e"))
	# deck
	K.rect(im, 2, h - 12, w - 4, 8, c("9a6c44"))
	K.hline(im, 2, h - 12, w - 4, c("c4996a"))
	for dx in range(2, w - 2, 5):
		K.vline(im, dx, h - 12, 8, c("7a5232"))
	K.hline(im, 2, h - 5, w - 4, c("5a3a22"))
	K.hline(im, 2, h - 4, w - 4, Color(0, 0, 0, 0.25))
	# front wall: canvas with vertical folds over corner posts
	var wall_top := 20
	var wall_h := h - 12 - wall_top
	K.rect(im, x0, wall_top, bw, wall_h, canvas)
	for fx in range(x0 + 3, x0 + bw - 2, 6):
		K.vline(im, fx, wall_top, wall_h, canvas.darkened(0.12))
		K.vline(im, fx + 1, wall_top, wall_h, canvas.lightened(0.06))
	K.rect(im, x0 + bw - 8, wall_top, 8, wall_h, canvas.darkened(0.06))
	K.hline(im, x0, h - 13, bw, canvas.darkened(0.22))
	for fx in [x0 - 1, x0 + bw - 2]:
		K.rect(im, fx, wall_top - 1, 3, wall_h + 2, c("7a5232"))
		K.vline(im, fx, wall_top - 1, wall_h + 2, c("b0824c"))
	# roof: two-tone canvas trapezoid, seams, a hem with scallops, ridge pole
	for y in wall_top:
		var t := float(y) / wall_top
		var inset := int((1.0 - t) * 11.0)
		for x in range(x0 - 2 + inset, x0 + bw + 2 - inset):
			var f := float(x - x0) / bw
			var tone := canvas.lightened(0.06 - f * 0.16)
			if y < 3:
				tone = tone.lightened(0.1)
			if (x - x0 - 3) % 9 == 0:
				tone = tone.darkened(0.13)
			K.px(im, x, y, tone)
	for x in range(x0 - 2, x0 + bw + 2):
		var hem := trim if ((x - x0) / 3) % 2 == 0 else trim.darkened(0.15)
		K.px(im, x, wall_top - 2, hem)
		K.px(im, x, wall_top - 1, hem.darkened(0.18))
	K.hline(im, x0, wall_top, bw, Color(0, 0, 0, 0.2))
	K.hline(im, x0 + 8, 0, bw - 16, c("7a5232"))
	K.hline(im, x0 + 8, 1, bw - 16, c("b0824c"))
	K.px(im, x0 + 7, 0, c("7a5232"))
	K.px(im, x0 + bw - 8, 0, c("7a5232"))
	# door: tied-back flaps around a dark screened opening
	var dx := w / 2 - 6
	K.rect(im, dx, wall_top + 3, 12, wall_h - 3, c("34291f"))
	K.rect(im, dx + 1, wall_top + 5, 10, wall_h - 6, c("564636"))
	for nx in range(dx + 2, dx + 10, 2):
		K.vline(im, nx, wall_top + 5, wall_h - 6, c("6a5a48"))
	K.rect(im, dx - 3, wall_top + 3, 3, wall_h - 3, canvas.darkened(0.16))
	K.rect(im, dx + 12, wall_top + 3, 3, wall_h - 3, canvas.darkened(0.16))
	K.px(im, dx + 1, wall_top + 7, c("d8c890"))
	# a small fly over the door on two poles
	for pole_x in [dx - 4, dx + 15]:
		K.rect(im, pole_x, wall_top + 6, 2, wall_h - 3, c("6e4a2e"))
	for row in 4:
		K.hline(im, dx - 6 - (3 - row) , wall_top + 3 + row, 12 + 12 + (3 - row) * 2, canvas.darkened(0.02 * row) if row < 3 else trim)
	# hanging number plate
	var plate := str(200 + variant * 3 + (variant / 7) * 2)
	K.rect(im, dx - 1, wall_top + 8, 14, 8, c("2f4a34"))
	K.rect(im, dx, wall_top + 9, 12, 6, c("3f6a4a"))
	K.text(im, dx + 1, wall_top + 9, plate, c("f6ecd0"))
	K.px(im, dx + 2, wall_top + 7, c("3a2c22"))
	K.px(im, dx + 9, wall_top + 7, c("3a2c22"))
	# a screened window on the left wall panel
	K.rect(im, x0 + 3, wall_top + 5, 7, 6, c("6e4a2e"))
	K.rect(im, x0 + 4, wall_top + 6, 5, 4, c("9fbcae"))
	K.px(im, x0 + 6, wall_top + 6, c("cfe4d8"))
	# steps
	K.rect(im, dx + 1, h - 8, 11, 3, c("b0824c"))
	K.hline(im, dx + 1, h - 8, 11, c("d8aa78"))
	# per-tent dressing on the deck
	match (variant * 3 + variant / 5) % 5:
		0:
			K.rect(im, w - 15, h - 19, 9, 7, c("d8442a"))
			K.rect(im, w - 15, h - 19, 9, 2, c("f0704a"))
			K.rect(im, w - 14, h - 13, 2, 3, c("8a2a1a"))
			K.rect(im, w - 8, h - 13, 2, 3, c("8a2a1a"))
		1:
			K.rect(im, 5, h - 17, 8, 5, c("3a78c0"))
			K.rect(im, 5, h - 17, 8, 2, c("f0ecdc"))
			K.rect(im, 14, h - 15, 5, 3, c("3a2a20"))
			K.px(im, 15, h - 16, c("e8dcc0"))
		2:
			K.lantern(im, w - 9, wall_top + 7)
			K.rect(im, w - 16, h - 19, 9, 7, c("3a78c0"))
			K.rect(im, w - 16, h - 19, 9, 2, c("5a98e0"))
		3:
			K.rect(im, 6, h - 18, 3, 6, c("3a2a20"))
			K.rect(im, 10, h - 18, 3, 6, c("3a2a20"))
			K.px(im, 7, h - 19, c("e8dcc0"))
			K.rect(im, w - 16, h - 19, 9, 7, c("3a9a5a"))
			K.rect(im, w - 16, h - 19, 9, 2, c("5aba7a"))
		4:
			K.rect(im, 4, h - 17, 10, 4, c("d8a040"))
			K.hline(im, 4, h - 17, 10, c("f0c870"))
			K.lantern(im, 9, wall_top + 8)
	K.outline(im)
	return im


## A small wood-sided cabin with a green shingle roof, a porch light, and a
## flower box.
func wood_cabin(variant: int) -> Image:
	var w := 42
	var h := 40
	var im := K.make(w, h)
	_ground_shadow(im, w, h)
	var roof_h := 16
	var wall_top := _roof_and_eave(im, w, roof_h, c(GREEN_ROOF) if variant == 0 else c(BROWN_ROOF), 30 + variant, 0.26)
	K.boards(im, 3, wall_top, w - 6, h - wall_top - 3, c("a67a4c") if variant == 0 else c("8f6a48"), 31 + variant)
	K.stones(im, 3, h - 6, w - 6, 4, c("8d857a"), 33)
	K.door(im, 6, h - 17, 9, 13, c("6e4a2e"), c("f0e6c8"), false)
	K.window(im, w - 18, wall_top + 5, 10, 8, c("f0e6c8"), c("6a8caa"), c("d8b0a0"), Color(0, 0, 0, 0))
	K.rect(im, w - 19, wall_top + 15, 12, 3, c("6e4a2e"))
	for f in [[w - 18, "e04a6a"], [w - 15, "f2d25c"], [w - 12, "e04a6a"], [w - 9, "f2ecd6"]]:
		K.px(im, f[0], wall_top + 14, c(f[1]))
	K.lantern(im, 19, wall_top + 8)
	K.text(im, 7, wall_top + 4, str(31 + variant * 4), c("f4ecd0"), c("3a2c22"))
	K.outline(im)
	return im


func chair(variant: int) -> Image:
	var im := K.make(14, 16)
	K.shadow(im, 7.0, 14.0, 5.0, 1.4)
	var col: Color = [c("d8442a"), c("3a9a5a"), c("3a78c0"), c("e0b030")][variant % 4]
	K.rect(im, 3, 2, 8, 8, col)
	K.rect(im, 3, 2, 8, 2, col.lightened(0.2))
	K.vline(im, 5, 3, 7, col.darkened(0.2))
	K.vline(im, 8, 3, 7, col.darkened(0.2))
	K.rect(im, 2, 9, 10, 3, col.darkened(0.1))
	K.hline(im, 2, 9, 10, col.lightened(0.14))
	K.rect(im, 2, 12, 2, 2, col.darkened(0.45))
	K.rect(im, 10, 12, 2, 2, col.darkened(0.45))
	K.rect(im, 1, 7, 2, 4, c("e8e0c8"))
	K.rect(im, 11, 7, 2, 4, c("e8e0c8"))
	K.outline(im)
	return im


## 16x16 icons: pilot bread, cheddar, dried apricots, jerky, chocolate, King Cobra.
func store_foods() -> Image:
	var im := K.make(96, 16)
	# pilot bread: a stack of pale round crackers
	for k in 3:
		K.ellipse(im, 8.0, 11.0 - k * 2.5, 6.0, 2.6, c("d8b878"))
		K.ellipse(im, 8.0, 10.4 - k * 2.5, 5.0, 1.8, c("ecd49c"))
		K.px(im, 6, 10 - k * 2, c("b08a54"))
		K.px(im, 10, 11 - k * 2, c("b08a54"))
	K.outline(im)
	# cheddar: a wedge in wax paper
	K.rect(im, 19, 6, 12, 8, c("f0b830"))
	K.rect(im, 19, 6, 12, 2, c("ffd860"))
	K.rect(im, 23, 3, 6, 3, c("f0b830"))
	K.rect(im, 22, 4, 2, 2, c("ffd860"))
	K.px(im, 26, 9, c("c88a1a"))
	K.px(im, 22, 11, c("c88a1a"))
	K.rect(im, 19, 12, 12, 2, c("e8e0c8"))
	# apricots: three orange halves
	for p in [[35, 9], [40, 6], [42, 11]]:
		K.ellipse(im, p[0] + 0.5, p[1] + 0.5, 3.6, 3.0, c("e88a2a"))
		K.ellipse(im, p[0] + 0.5, p[1] + 0.5, 1.4, 1.1, c("b8581a"))
		K.px(im, p[0] - 1, p[1] - 1, c("ffb860"))
	# jerky: a paper bag with dark strips
	K.rect(im, 51, 4, 10, 10, c("c89a58"))
	K.rect(im, 51, 4, 10, 2, c("e0b878"))
	K.rect(im, 52, 7, 8, 3, c("f0e6c8"))
	K.rect(im, 53, 8, 6, 1, c("a02a1a"))
	for k in 4:
		K.rect(im, 52 + k * 2, 2, 1, 3, c("6a3a22"))
	# chocolate: a foil-wrapped bar
	K.rect(im, 66, 5, 12, 8, c("5a3420"))
	K.rect(im, 66, 5, 12, 2, c("8a5a3a"))
	for x in range(68, 78, 3):
		K.vline(im, x, 7, 6, c("3a2010"))
	K.rect(im, 66, 10, 12, 3, c("c8a038"))
	K.px(im, 70, 11, c("f0d878"))
	# King Cobra: a tall black can with gold bands and a red label
	K.rect(im, 85, 3, 6, 11, c("22201e"))
	K.vline(im, 85, 4, 9, c("4a4642"))
	K.rect(im, 85, 3, 6, 1, c("c8ccd0"))
	K.rect(im, 85, 13, 6, 1, c("9aa0a6"))
	K.hline(im, 85, 6, 6, c("d8a830"))
	K.hline(im, 85, 10, 6, c("d8a830"))
	K.rect(im, 87, 7, 3, 3, c("c8281e"))
	K.px(im, 88, 8, c("f0d878"))
	K.px(im, 88, 2, c("9aa0a6"))
	K.outline(im)
	return im


## The pool's winter self: the deck swept, the water frozen, boards around it.
func ice_rink() -> Image:
	var w := 76
	var h := 52
	var im := K.make(w, h)
	K.rect(im, 0, 0, w, h, c("dfe6ec"))          # snowy deck
	for y in range(0, h, 4):
		K.hline(im, 0, y, w, c("d2dbe3"))
	K.rect(im, 4, 4, w - 8, h - 18, c("6a4a2e"))  # the boards
	K.rect(im, 5, 5, w - 10, h - 20, c("a0764a"))
	K.rect(im, 7, 7, w - 14, h - 24, c("bfe4f4"))  # the ice
	K.rect(im, 7, 7, w - 14, 3, c("e4f6fc"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 68
	for i in 9:
		var x0 := 10 + rng.randi() % (w - 30)
		var y0 := 12 + rng.randi() % (h - 36)
		for t in 14:
			K.px(im, x0 + t, y0 + int(sin(t * 0.5 + i) * 2.0), c("f4fbff"))
	for i in 5:
		var x1 := 10 + rng.randi() % (w - 20)
		var y1 := 11 + rng.randi() % (h - 30)
		K.px(im, x1, y1, c("8ec8e0"))
	# a bench and a warming barrel by the gate
	K.rect(im, 10, h - 13, 16, 4, c("b0824c"))
	K.hline(im, 10, h - 13, 16, c("d0a06a"))
	K.rect(im, 12, h - 9, 2, 4, c("5a3a22"))
	K.rect(im, 22, h - 9, 2, 4, c("5a3a22"))
	K.barrel(im, w - 20, h - 16, 8, 10, c("6a6a72"))
	K.rect(im, w - 19, h - 17, 6, 2, c("ff9a3a"))
	K.px(im, w - 17, h - 18, c("ffe070"))
	K.outline(im)
	return im


## A parked car seen from above and a little to the front, nose up. [param style]:
## 0 sedan, 1 station wagon, 2 pickup, 3 camper bus, 4 motor home.
func car(style: int, paint: Color) -> Image:
	var w := 28
	var h: int = [42, 46, 46, 40, 58][style]
	if style == 4:
		w = 32
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 3.0, w / 2.0 - 1.0, 3.0, 0.3)
	var glass := c("5f7f92")
	var glass_hi := c("a6c4d4")
	var body_w := w - 6
	var x0 := 3
	# wheels peeking out at the four corners
	for wy in [8, h - 14]:
		K.rect(im, x0 - 2, wy, 3, 7, c("1c1c20"))
		K.rect(im, x0 + body_w - 1, wy, 3, 7, c("1c1c20"))
	# body
	K.rect(im, x0, 3, body_w, h - 6, paint)
	K.rect(im, x0, 3, body_w, 2, paint.lightened(0.28))          # lit nose
	K.rect(im, x0 + 1, 2, body_w - 2, 1, paint.darkened(0.3))
	K.vline(im, x0, 5, h - 9, paint.lightened(0.14))
	K.vline(im, x0 + body_w - 1, 5, h - 9, paint.darkened(0.32))
	K.hline(im, x0, h - 4, body_w, paint.darkened(0.36))
	# lights and bumpers
	K.rect(im, x0 + 1, 4, 3, 2, c("ffe9a0"))
	K.rect(im, x0 + body_w - 4, 4, 3, 2, c("ffe9a0"))
	K.rect(im, x0 + 1, h - 6, 3, 2, c("d8402e"))
	K.rect(im, x0 + body_w - 4, h - 6, 3, 2, c("d8402e"))
	K.rect(im, x0 + 2, h - 4, body_w - 4, 2, c("c8c8c0"))
	K.rect(im, x0 + 2, 2, body_w - 4, 1, c("c8c8c0"))
	match style:
		0:
			K.rect(im, x0 + 2, 15, body_w - 4, 5, glass)                 # windshield
			K.hline(im, x0 + 3, 15, body_w - 6, glass_hi)
			K.rect(im, x0 + 1, 21, body_w - 2, 9, paint.lightened(0.1))  # roof
			K.hline(im, x0 + 1, 21, body_w - 2, paint.lightened(0.3))
			K.rect(im, x0 + 2, 31, body_w - 4, 4, glass.darkened(0.15))  # rear window
		1:
			K.rect(im, x0 + 2, 14, body_w - 4, 5, glass)
			K.hline(im, x0 + 3, 14, body_w - 6, glass_hi)
			K.rect(im, x0 + 1, 20, body_w - 2, 16, paint.lightened(0.1))
			K.hline(im, x0 + 1, 20, body_w - 2, paint.lightened(0.3))
			for rx in [x0 + 3, x0 + body_w - 5]:
				K.vline(im, rx, 21, 14, c("6e4a2e"))
			K.rect(im, x0 + 4, 24, body_w - 8, 8, c("8a6a48"))           # a luggage roll on the rack
			K.hline(im, x0 + 4, 24, body_w - 8, c("b0906a"))
			K.rect(im, x0 + 1, 8, 2, 8, c("946840"))                     # woodgrain side
			K.rect(im, x0 + body_w - 3, 8, 2, 8, c("946840"))
		2:
			K.rect(im, x0 + 2, 12, body_w - 4, 4, glass)
			K.hline(im, x0 + 3, 12, body_w - 6, glass_hi)
			K.rect(im, x0 + 1, 17, body_w - 2, 8, paint.lightened(0.1))  # cab roof
			K.rect(im, x0 + 2, 26, body_w - 4, 15, c("3a3026"))          # the bed
			K.rect(im, x0 + 2, 26, body_w - 4, 2, paint.darkened(0.2))
			K.rect(im, x0 + 4, 31, 8, 6, c("8a6a48"))                    # a crate in it
			K.hline(im, x0 + 4, 31, 8, c("b0906a"))
		3:
			K.rect(im, x0 + 1, 10, body_w - 2, 5, glass)
			K.vline(im, x0 + body_w / 2, 10, 5, paint)                   # split windshield
			K.hline(im, x0 + 2, 10, body_w - 4, glass_hi)
			K.rect(im, x0, 16, body_w, 20, c("efe6cf"))                  # cream roof
			K.hline(im, x0, 16, body_w, c("ffffff"))
			K.rect(im, x0 + 3, 20, body_w - 6, 3, c("d8d0b8"))
			K.rect(im, x0 + 6, 26, body_w - 12, 6, c("b8b0a0"))          # roof rack / surfboard
		4:
			K.rect(im, x0 + 1, 12, body_w - 2, 7, glass)
			K.hline(im, x0 + 2, 12, body_w - 4, glass_hi)
			K.rect(im, x0, 20, body_w, h - 26, c("f2ecd8"))              # white box
			K.hline(im, x0, 20, body_w, c("ffffff"))
			K.rect(im, x0, 30, body_w, 3, paint)                         # racing stripe
			K.rect(im, x0 + 4, 24, 8, 6, c("b8b0a0"))                    # roof air conditioner
			K.rect(im, x0 + body_w - 10, 40, 6, 8, c("d8d0b8"))
			K.rect(im, x0 + 4, 22, 2, h - 30, c("a89f8a"))               # ladder
	# The back of the car, seen from above and behind like the buildings:
	# a shaded rear panel with tail lights and a plate, the bumper, and the
	# rear tyres under it, so the car stands up instead of lying flat.
	var face := 8
	var top := h - 4 - face
	K.rect(im, x0, top, body_w, face, paint.darkened(0.22))
	K.hline(im, x0, top, body_w, paint.lightened(0.2))
	K.vline(im, x0, top, face, paint.darkened(0.08))
	K.vline(im, x0 + body_w - 1, top, face, paint.darkened(0.4))
	K.rect(im, x0 + 1, top + 2, 4, 3, c("d8402e"))
	K.px(im, x0 + 1, top + 2, c("ff8a6a"))
	K.rect(im, x0 + body_w - 5, top + 2, 4, 3, c("d8402e"))
	K.px(im, x0 + body_w - 5, top + 2, c("ff8a6a"))
	K.rect(im, x0 + body_w / 2 - 3, top + 3, 6, 3, c("efe6cf"))
	K.hline(im, x0 + body_w / 2 - 2, top + 4, 4, c("3a5a8a"))
	K.rect(im, x0 + 1, h - 5, body_w - 2, 2, c("c8c8c0"))
	K.hline(im, x0 + 1, h - 5, body_w - 2, c("f0f0ea"))
	K.rect(im, x0, h - 3, 5, 3, c("1c1c20"))
	K.rect(im, x0 + body_w - 5, h - 3, 5, 3, c("1c1c20"))
	K.outline(im)
	return im
