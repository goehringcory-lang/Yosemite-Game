extends RefCounted
## Pixel art for the insides of Curry Village's shops: the Camp Curry Store
## and the Mountain Shop. Each room is one 480x272 picture (30x17 tiles, the
## size of the screen) under the furniture, and each piece of furniture is its
## own sprite so the player can walk around it. Drawn in code with PixelKit.
## Written to assets/sprites/curry/interiors/.

const K = preload("res://tools/hubs/pixel_kit.gd")
const DIR := "res://assets/sprites/curry/interiors/"
const W := 480
const H := 272


static func c(hex: String) -> Color:
	return Color(hex)


func save_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var images := {
		"store_room": store_room(), "shop_room": shop_room(),
		"store_counter": store_counter(), "store_shelf": store_shelf(), "produce_table": produce_table(),
		"store_stove": stove_sheet(), "store_cooler": cooler(), "store_chalkboard": chalkboard(),
		"store_barrels": barrels(), "postcard_rack": postcard_rack(),
		"shop_counter": shop_counter(), "practice_wall": practice_wall(), "crash_pad": crash_pad(),
		"glass_case": glass_case(), "pack_rack": pack_rack(), "workbench": workbench(),
		"boot_bench": boot_bench(), "shop_stove": stove_sheet(), "rope_bin": rope_bin(), "stool": stool(),
	}
	for image_name: String in images:
		(images[image_name] as Image).save_png(ProjectSettings.globalize_path(DIR + image_name + ".png"))


# ---------------------------------------------------------------- room shells

## Horizontal plank flooring with worn lanes and knots.
func _floor(im: Image, y0: int, y1: int, base: Color, seed_value: int) -> void:
	for y in range(y0, y1):
		var row := (y - y0) / 8
		var in_row := (y - y0) % 8
		for x in W:
			var plank := (x + (row % 3) * 37) / 64
			var n := K.hash2(plank, row, seed_value)
			var tone := base.lightened((n - 0.5) * 0.16)
			if in_row == 0:
				tone = tone.darkened(0.3)
			elif in_row == 1:
				tone = tone.lightened(0.07)
			elif in_row == 7:
				tone = tone.darkened(0.08)
			if (x + (row % 3) * 37) % 64 == 0:
				tone = tone.darkened(0.3)
			K.px(im, x, y, tone)
		# grain flecks
		for i in 10:
			var gx := int(K.hash2(i, y, seed_value + 4) * W)
			if in_row > 1 and in_row < 7 and K.hash2(gx, y, seed_value + 5) > 0.72:
				K.px(im, gx, y, base.darkened(0.12))
				K.px(im, gx + 1, y, base.darkened(0.08))
		# a knot now and then
	for i in 26:
		var kx := int(K.hash2(i, 3, seed_value) * W)
		var ky := y0 + int(K.hash2(i, 4, seed_value) * (y1 - y0 - 4)) + 2
		K.ellipse(im, kx, ky, 1.8, 1.2, base.darkened(0.22))
		K.px(im, kx, ky, base.darkened(0.36))


## A rag rug: woven bands and a fringe.
func _rug(im: Image, x: int, y: int, w: int, h: int, a: Color, b: Color, edge: Color) -> void:
	K.rect(im, x - 1, y - 1, w + 2, h + 2, edge.darkened(0.4))
	K.rect(im, x, y, w, h, edge)
	K.rect(im, x + 3, y + 3, w - 6, h - 6, a)
	for by in range(y + 5, y + h - 5, 4):
		K.hline(im, x + 5, by, w - 10, b)
	for bx in range(x + 8, x + w - 8, 16):
		K.rect(im, bx, y + 6, 4, h - 12, b.darkened(0.1))
	for fx in range(x, x + w, 2):
		K.px(im, fx, y - 2, edge.lightened(0.2))
		K.px(im, fx, y + h + 1, edge.lightened(0.2))


## A window of light on the wall and a soft shaft of it across the floor.
func _window_light(im: Image, x: int, y: int, w: int, h: int, floor_y: int, floor_h: int, dx: int) -> void:
	K.rect(im, x - 2, y - 2, w + 4, h + 4, c("4a3020"))
	K.rect(im, x, y, w, h, c("bfe0f0"))
	K.rect(im, x, y, w, 3, c("e8f6fb"))
	K.vline(im, x + w / 2, y, h, c("4a3020"))
	K.hline(im, x, y + h / 2, w, c("4a3020"))
	K.rect(im, x - 3, y + h + 2, w + 6, 2, c("8a6440"))
	# distant pines through the glass
	for tx in range(x + 2, x + w - 2, 6):
		K.rect(im, tx, y + h - 8, 3, 8, c("5a8a5a"))
		K.rect(im, tx + 1, y + h - 12, 1, 4, c("5a8a5a"))
	# the shaft on the floor: a lit parallelogram fading with distance
	for yy in floor_h:
		var t := float(yy) / floor_h
		var shift := int(dx * t)
		for xx in w:
			var alpha := 0.16 * (1.0 - t * 0.6)
			K.px(im, x + xx + shift, floor_y + yy, Color(1, 0.96, 0.78, alpha))


func _sconce(im: Image, x: int, y: int) -> void:
	K.rect(im, x - 1, y, 3, 6, c("3a2c22"))
	K.rect(im, x - 2, y + 2, 5, 3, c("ffd870"))
	K.px(im, x, y + 3, c("fff4c0"))
	for r in range(2, 8):
		K.ellipse(im, x, y + 3, r, r, Color(1, 0.86, 0.5, 0.05))


func _jar(im: Image, x: int, y: int, col: Color) -> void:
	K.rect(im, x, y + 1, 4, 5, col)
	K.rect(im, x, y + 1, 1, 5, col.lightened(0.28))
	K.rect(im, x + 1, y, 2, 1, c("c8b078"))
	K.px(im, x + 3, y + 5, col.darkened(0.3))


func _can(im: Image, x: int, y: int, col: Color) -> void:
	K.rect(im, x, y, 3, 5, col)
	K.rect(im, x, y, 3, 1, c("d8d8d0"))
	K.px(im, x + 1, y + 2, c("f4ecd0"))


func _box(im: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	K.rect(im, x, y, w, h, col)
	K.hline(im, x, y, w, col.lightened(0.2))
	K.vline(im, x + w - 1, y, h, col.darkened(0.25))
	K.rect(im, x + 1, y + h / 2 - 1, w - 2, 2, col.lightened(0.34))


func _loaf(im: Image, x: int, y: int) -> void:
	K.ellipse(im, x + 3, y + 3, 4, 2.6, c("b8783a"))
	K.ellipse(im, x + 2.5, y + 2.4, 3, 1.6, c("d89a52"))
	K.px(im, x + 1, y + 2, c("f0c078"))
	K.px(im, x + 4, y + 3, c("8a5228"))


# ---------------------------------------------------------------- the store

func store_room() -> Image:
	var im := K.make(W, H)
	_floor(im, 64, H - 16, c("b58a56"), 41)
	# Back wall: cream lap siding over a dark green wainscot.
	K.lap(im, 0, 0, W, 44, c("e6d8b0"), 42)
	K.boards(im, 0, 44, W, 20, c("4a6a4a"), 43, 5)
	K.hline(im, 0, 43, W, c("2f4a34"))
	K.hline(im, 0, 44, W, c("7a9a70"))
	K.rect(im, 0, 63, W, 2, c("2a1f1a"))
	K.rect(im, 0, 62, W, 1, c("8a6440"))
	# Side walls.
	for sx in [0, W - 16]:
		K.boards(im, sx, 0, 16, H, c("9a6c44"), 44, 4)
		K.rect(im, sx + (15 if sx == 0 else 0), 0, 1, H, c("2a1f1a"))
	# Bottom (front) wall with the door gap at the middle, and its windows.
	K.boards(im, 0, H - 16, W, 16, c("8a6440"), 45, 4)
	K.hline(im, 0, H - 16, W, c("2a1f1a"))
	K.rect(im, 216, H - 16, 48, 16, c("6a4a30"))
	K.rect(im, 220, H - 16, 40, 16, c("3a2a20"))
	K.rect(im, 216, H - 18, 48, 2, c("f4ecd0"))
	K.rect(im, 218, H - 4, 44, 4, c("7a3a2a"))   # a rag mat
	K.hline(im, 218, H - 4, 44, c("c0806a"))
	# Two paned windows on the back wall with light falling across the floor.
	_window_light(im, 44, 8, 34, 26, 70, 80, 34)
	_window_light(im, 402, 8, 34, 26, 70, 80, -34)
	# The shelving painted along the back wall: two long shelves of goods.
	for shelf_y in [22, 44]:
		K.rect(im, 96, shelf_y + 10, 288, 3, c("6e4a2e"))
		K.hline(im, 96, shelf_y + 10, 288, c("b0824c"))
		K.rect(im, 96, shelf_y + 13, 288, 1, c("3a2a1e"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1899
	for sx in range(100, 380, 6):
		var kind := rng.randi() % 5
		var tone: Color = [c("c8402e"), c("d8a040"), c("5a9a4a"), c("8a6ad0"), c("3a78c0"), c("e0c060")][rng.randi() % 6]
		if kind == 0:
			_jar(im, sx, 26, tone)
		elif kind == 1:
			_can(im, sx, 27, tone)
		elif kind == 2:
			_box(im, sx, 24, 5, 8, tone)
		elif kind == 3:
			_jar(im, sx, 26, tone.darkened(0.15))
		else:
			_can(im, sx, 27, tone.darkened(0.1))
	for sx in range(100, 380, 6):
		var kind := rng.randi() % 6
		var tone: Color = [c("c8402e"), c("d8a040"), c("5a9a4a"), c("e8e0c0"), c("3a78c0")][rng.randi() % 5]
		if kind == 0:
			_loaf(im, sx, 47)
		elif kind == 1 or kind == 2:
			_can(im, sx, 49, tone)
		elif kind == 3:
			_box(im, sx, 46, 5, 8, tone)
		else:
			_jar(im, sx, 48, tone)
	# Hanging: dried peppers, garlic, a coil of rope, a basket, a pan.
	for hx in [110, 150, 200, 260, 300, 340]:
		K.vline(im, hx, 0, 6, c("6a5a3a"))
		for k in 4:
			K.ellipse(im, hx + (k % 2) * 2 - 1, 8 + k * 2, 1.5, 2.0, [c("c8402e"), c("b02a1a"), c("d8602e"), c("c8402e")][k])
	K.ellipse(im, 100, 16, 6, 7, c("b0824c"))
	K.ellipse(im, 100, 16, 4, 5, c("8a6440"))
	# Sconces.
	_sconce(im, 88, 16)
	_sconce(im, 392, 16)
	_sconce(im, 20, 20)
	_sconce(im, W - 20, 20)
	# A big rug under the produce tables.
	_rug(im, 132, 148, 216, 60, c("8a2f2f"), c("e8d8a8"), c("2f4a34"))
	# A little wear and a soft shadow along the walls.
	K.rect(im, 16, 64, W - 32, 3, Color(0, 0, 0, 0.22))
	K.rect(im, 16, 67, W - 32, 2, Color(0, 0, 0, 0.1))
	K.rect(im, 16, 64, 3, H - 80, Color(0, 0, 0, 0.16))
	K.rect(im, W - 19, 64, 3, H - 80, Color(0, 0, 0, 0.16))
	return im


func store_counter() -> Image:
	var w := 128
	var h := 38
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 2.0, w / 2.0 - 3.0, 2.4)
	# top
	K.rect(im, 2, 6, w - 4, 6, c("d0a06a"))
	K.hline(im, 2, 6, w - 4, c("f0c890"))
	K.hline(im, 2, 11, w - 4, c("8a6440"))
	# front: paneled
	K.rect(im, 3, 12, w - 6, 22, c("7a5232"))
	for px_x in range(6, w - 8, 18):
		K.rect(im, px_x, 15, 15, 16, c("946840"))
		K.hline(im, px_x, 15, 15, c("b0824c"))
		K.hline(im, px_x, 30, 15, c("5a3a22"))
	K.hline(im, 3, 33, w - 6, c("3e2a1c"))
	# on the counter: scale, scale pans, jar of candy, ledger, bell, basket of eggs
	K.rect(im, 12, 1, 2, 6, c("3a2c22"))
	K.hline(im, 6, 2, 14, c("b0a062"))
	K.rect(im, 5, 3, 4, 2, c("d8c878"))
	K.rect(im, 17, 3, 4, 2, c("d8c878"))
	_jar(im, 40, 0, c("e05a8a"))
	_jar(im, 46, 0, c("e0c060"))
	K.rect(im, 60, 2, 12, 4, c("f0e6c8"))
	K.hline(im, 60, 2, 12, c("ffffff"))
	K.vline(im, 66, 2, 4, c("8a6a48"))
	K.rect(im, 86, 3, 4, 3, c("d8b040"))
	K.px(im, 88, 2, c("ffe070"))
	K.ellipse(im, 106, 4, 6, 3, c("b0824c"))
	for e in [[103, 3], [106, 2], [109, 3], [105, 5], [108, 5]]:
		K.px(im, e[0], e[1], c("f4ecd0"))
	K.outline(im)
	return im


func store_shelf() -> Image:
	var w := 50
	var h := 46
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 2.0, w / 2.0 - 2.0, 2.0)
	K.rect(im, 1, 2, w - 2, h - 8, c("8a6440"))
	K.rect(im, 2, 3, w - 4, h - 10, c("5a3e28"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for level in 3:
		var y := 4 + level * 12
		K.rect(im, 2, y + 9, w - 4, 2, c("a0764a"))
		K.hline(im, 2, y + 9, w - 4, c("d0a06a"))
		for x in range(4, w - 6, 6):
			var tone: Color = [c("c8402e"), c("d8a040"), c("5a9a4a"), c("8a6ad0"), c("3a78c0"), c("e8e0c0")][rng.randi() % 6]
			match rng.randi() % 4:
				0:
					_jar(im, x, y + 2, tone)
				1:
					_can(im, x, y + 3, tone)
				2:
					_box(im, x, y + 1, 5, 8, tone)
				_:
					_can(im, x + 1, y + 3, tone.darkened(0.1))
	K.rect(im, 0, h - 8, 3, 6, c("6e4a2e"))
	K.rect(im, w - 3, h - 8, 3, 6, c("6e4a2e"))
	K.outline(im)
	return im


func produce_table() -> Image:
	var w := 54
	var h := 34
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 2.0, w / 2.0 - 2.0, 2.0)
	K.rect(im, 2, 14, w - 4, 4, c("b0824c"))
	K.hline(im, 2, 14, w - 4, c("d0a06a"))
	for lx in [4, w - 8]:
		K.rect(im, lx, 18, 4, 14, c("6e4a2e"))
	# crates on the table, each heaped with something
	var heaps := [["c8402e", "e86a4a"], ["e0c050", "f4dc78"], ["5a9a4a", "80c064"]]
	for i in 3:
		var cx := 3 + i * 17
		K.crate(im, cx, 6, 15, 9, c("c0904e"))
		for k in 6:
			var hx := cx + 2 + k * 2
			var hy := 3 + (k % 2)
			K.ellipse(im, hx, hy + 2, 2.0, 2.0, c(heaps[i][0]))
			K.px(im, hx - 1, hy + 1, c(heaps[i][1]))
	K.outline(im)
	return im


## Two frames side by side: the stove's fire low, then high.
func stove_sheet() -> Image:
	var sheet := K.make(48, 44)
	K.stamp(sheet, stove(false), 0, 0)
	K.stamp(sheet, stove(true), 24, 0)
	return sheet


func stove(high := false) -> Image:
	var w := 24
	var h := 44
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 2.0, 9.0, 1.8)
	# stovepipe rising into the ceiling
	K.rect(im, 10, 0, 4, 18, c("3a3a42"))
	K.vline(im, 10, 0, 18, c("6a6a74"))
	K.rect(im, 9, 12, 6, 2, c("2a2a32"))
	# the belly
	K.ellipse(im, 12.0, 28.0, 8.0, 9.0, c("4a4a54"))
	K.ellipse(im, 11.0, 26.0, 5.5, 6.5, c("62626e"))
	K.rect(im, 6, 21, 12, 2, c("2a2a32"))
	K.rect(im, 9, 27, 6, 5, c("1a1a1e"))
	if high:
		K.rect(im, 10, 28, 4, 4, c("ffb03a"))
		K.rect(im, 11, 27, 2, 2, c("ffe070"))
		K.px(im, 12, 26, c("ffd060"))
	else:
		K.rect(im, 10, 30, 4, 2, c("ff8a2a"))
		K.px(im, 11, 30, c("ffd060"))
	K.rect(im, 5, 37, 3, 5, c("2a2a32"))
	K.rect(im, 16, 37, 3, 5, c("2a2a32"))
	# a coffee pot on top
	K.rect(im, 4, 16, 6, 5, c("3a5a8a"))
	K.rect(im, 4, 16, 6, 1, c("6a8aba"))
	K.px(im, 3, 18, c("3a5a8a"))
	K.outline(im)
	return im


func cooler() -> Image:
	var im := K.make(30, 30)
	K.shadow(im, 15.0, 28.0, 12.0, 1.8)
	K.rect(im, 2, 8, 26, 19, c("d8d4c4"))
	K.rect(im, 2, 8, 26, 3, c("f4f0e0"))
	K.hline(im, 2, 26, 26, c("9a968a"))
	K.rect(im, 4, 12, 22, 12, c("e8e4d4"))
	K.rect(im, 12, 6, 6, 3, c("3a3a42"))
	K.text(im, 7, 15, "ICE", c("3a78c0"))
	K.rect(im, 3, 24, 3, 4, c("6a4a30"))
	K.rect(im, 24, 24, 3, 4, c("6a4a30"))
	K.outline(im)
	return im


func chalkboard() -> Image:
	var im := K.make(28, 40)
	K.shadow(im, 14.0, 38.0, 10.0, 1.6)
	K.rect(im, 3, 30, 3, 8, c("5a3a22"))
	K.rect(im, 22, 30, 3, 8, c("5a3a22"))
	K.rect(im, 2, 2, 24, 30, c("6e4a2e"))
	K.rect(im, 4, 4, 20, 26, c("2f3a34"))
	K.text(im, 5, 6, "TODAY", c("f4ecd0"))
	K.hline(im, 5, 13, 18, c("8a9a90"))
	K.text(im, 5, 16, "PIE", c("e8d8a0"))
	K.text(im, 5, 22, "BREAD", c("e8d8a0"))
	K.outline(im)
	return im


func barrels() -> Image:
	var im := K.make(36, 30)
	K.shadow(im, 18.0, 28.0, 15.0, 1.8)
	K.barrel(im, 3, 6, 13, 20, c("a0764a"))
	K.barrel(im, 20, 8, 13, 18, c("946840"))
	K.ellipse(im, 9.5, 6.0, 6.0, 2.2, c("d8b880"))
	K.ellipse(im, 26.5, 8.0, 6.0, 2.2, c("d8b880"))
	# a scoop of crackers and a flour sack
	K.rect(im, 6, 4, 6, 2, c("e8c878"))
	K.outline(im)
	return im


func postcard_rack() -> Image:
	var im := K.make(20, 40)
	K.shadow(im, 10.0, 38.0, 7.0, 1.4)
	K.rect(im, 9, 12, 2, 26, c("5a3a22"))
	K.rect(im, 5, 36, 10, 2, c("5a3a22"))
	for row in 3:
		var y := 3 + row * 9
		K.rect(im, 3, y, 14, 8, c("3a2c22"))
		for k in 3:
			var card: Color = [c("5a98d0"), c("e8c860"), c("6ab86a"), c("d8604a")][(row + k) % 4]
			K.rect(im, 4 + k * 4, y + 1, 3, 6, card)
			K.px(im, 5 + k * 4, y + 2, c("f4ecd0"))
	K.outline(im)
	return im


# ---------------------------------------------------------------- the mountain shop

func shop_room() -> Image:
	var im := K.make(W, H)
	_floor(im, 80, H - 16, c("8e6440"), 51)
	# Back wall: plaster above a dark timber wainscot.
	K.rect(im, 0, 0, W, 80, c("d6c9aa"))
	for y in range(0, 60, 6):
		K.hline(im, 0, y, W, c("cdbf9d"))
	K.boards(im, 0, 60, W, 20, c("4a3628"), 52, 6)
	K.hline(im, 0, 59, W, c("2a1f1a"))
	K.hline(im, 0, 60, W, c("7a5c42"))
	K.rect(im, 0, 79, W, 2, c("2a1f1a"))
	# Exposed beams across the plaster.
	for bx in range(0, W, 96):
		K.rect(im, bx, 0, 6, 60, c("4e3826"))
		K.vline(im, bx, 0, 60, c("7a5c42"))
	K.rect(im, 0, 0, W, 5, c("4e3826"))
	K.hline(im, 0, 5, W, c("2a1f1a"))
	# The rope wall: a rack of colorful coiled ropes on pegs, left.
	K.rect(im, 22, 10, 138, 46, c("5a4432"))
	K.rect(im, 24, 12, 134, 42, c("3e2c1e"))
	var rope_cols := ["c8402e", "3a78c0", "e0b030", "3a9a5a", "8a4ad0", "e07a2a", "2aa8a0", "d84a8a"]
	for i in 8:
		var rx := 30 + (i % 4) * 32
		var ry := 16 + (i / 4) * 20
		K.ellipse(im, rx + 12, ry + 8, 11, 8, c(rope_cols[i]))
		K.ellipse(im, rx + 12, ry + 8, 8, 5.4, c(rope_cols[i]).lightened(0.14))
		K.ellipse(im, rx + 12, ry + 8, 4.6, 2.8, c("3e2c1e"))
		for k in 3:
			K.ring(im, rx + 12, ry + 8, 9.0 - k * 2.0, 6.4 - k * 1.4, c(rope_cols[i]).darkened(0.22))
		K.px(im, rx + 10, ry + 4, c("ffffff"))
	# The shoe wall: rows of climbing shoes on shelves, right.
	K.rect(im, 296, 10, 150, 46, c("5a4432"))
	K.rect(im, 298, 12, 146, 42, c("3e2c1e"))
	for shelf in 3:
		var sy := 22 + shelf * 12
		K.rect(im, 298, sy + 8, 146, 2, c("8a6440"))
		for sx in range(302, 440, 12):
			var col: String = ["c8402e", "3a78c0", "e0b030", "3a9a5a", "d8d8d0", "e07a2a"][int(K.hash2(sx, shelf, 9) * 6.0)]
			K.rect(im, sx, sy + 3, 9, 5, c(col))
			K.rect(im, sx + 6, sy + 1, 3, 4, c(col).darkened(0.2))
			K.hline(im, sx, sy + 7, 9, c("2a1f1a"))
			K.px(im, sx + 2, sy + 4, c("ffffff"))
	# The framed wall map and photographs.
	K.rect(im, 176, 8, 104, 56, c("6a4a30"))
	K.rect(im, 178, 10, 100, 52, c("e6d8a8"))
	for i in 5:
		var pts := [[184, 52], [210, 40], [232, 46], [252, 26], [270, 30]]
		if i > 0:
			var a: Array = pts[i - 1]
			var b: Array = pts[i]
			for t in 16:
				K.px(im, int(lerp(a[0], b[0], t / 15.0)), int(lerp(a[1], b[1], t / 15.0)), c("6a4a30"))
	K.rect(im, 236, 14, 32, 18, c("d0c090"))
	for cx in range(184, 270, 10):
		K.rect(im, cx, 28 + int(K.hash2(cx, 1, 8) * 10.0), 8, 20, c("b0a070"))
	K.text(im, 194, 14, "EL CAP", c("3a2a1e"))
	for pic in [[168, 18, 14, 18], [284, 18, 12, 16], [22, 60, 0, 0]]:
		if pic[2] > 0:
			K.rect(im, pic[0], pic[1], pic[2], pic[3], c("4a3020"))
			K.rect(im, pic[0] + 1, pic[1] + 1, pic[2] - 2, pic[3] - 2, c("c8c0b0"))
			K.rect(im, pic[0] + 3, pic[1] + 6, pic[2] - 6, pic[3] - 10, c("6a7a8a"))
	# Side walls, front wall, door gap.
	for sx in [0, W - 16]:
		K.boards(im, sx, 0, 16, H, c("6a4a32"), 53, 4)
		K.rect(im, sx + (15 if sx == 0 else 0), 0, 1, H, c("2a1f1a"))
	K.boards(im, 0, H - 16, W, 16, c("5a4030"), 54, 4)
	K.hline(im, 0, H - 16, W, c("2a1f1a"))
	K.rect(im, 216, H - 16, 48, 16, c("4a3020"))
	K.rect(im, 220, H - 16, 40, 16, c("3a2a20"))
	K.rect(im, 216, H - 18, 48, 2, c("e8dcc0"))
	K.rect(im, 218, H - 4, 44, 4, c("3a5a8a"))
	K.hline(im, 218, H - 4, 44, c("6a8aba"))
	# Windows and the light they throw.
	_window_light(im, 40, 70, 30, 24, 96, 90, 30)
	# A rug down the middle, and lantern sconces.
	_rug(im, 148, 170, 190, 64, c("3a5a8a"), c("e8d8a8"), c("6a3a2a"))
	_sconce(im, 168, 14)
	_sconce(im, 286, 14)
	_sconce(im, 20, 26)
	_sconce(im, W - 20, 26)
	K.rect(im, 16, 80, W - 32, 3, Color(0, 0, 0, 0.22))
	K.rect(im, 16, 83, W - 32, 2, Color(0, 0, 0, 0.1))
	K.rect(im, 16, 80, 3, H - 96, Color(0, 0, 0, 0.16))
	K.rect(im, W - 19, 80, 3, H - 96, Color(0, 0, 0, 0.16))
	return im


func shop_counter() -> Image:
	var w := 100
	var h := 40
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 2.0, w / 2.0 - 3.0, 2.4)
	K.rect(im, 2, 6, w - 4, 6, c("c0906a"))
	K.hline(im, 2, 6, w - 4, c("e8b88a"))
	K.hline(im, 2, 11, w - 4, c("7a5232"))
	K.rect(im, 3, 12, w - 6, 24, c("4a3628"))
	for px_x in range(6, w - 8, 16):
		K.rect(im, px_x, 15, 13, 18, c("5e4632"))
		K.hline(im, px_x, 15, 13, c("7a5c42"))
		K.hline(im, px_x, 32, 13, c("3a2a1e"))
	K.hline(im, 3, 35, w - 6, c("2a1f1a"))
	# on the counter: ledger, a rope coil, a carabiner dish, an ice axe leaning
	K.rect(im, 10, 2, 12, 4, c("f0e6c8"))
	K.hline(im, 10, 2, 12, c("ffffff"))
	K.vline(im, 16, 2, 4, c("8a6a48"))
	K.ellipse(im, 34, 4, 6, 3.4, c("c8402e"))
	K.ellipse(im, 34, 4, 2.4, 1.2, c("4a3628"))
	K.ellipse(im, 52, 4, 6, 2.6, c("6a6a72"))
	for k in 5:
		K.rect(im, 48 + k * 2, 2, 1, 3, [c("d8442a"), c("3a78c0"), c("e0b030"), c("3a9a5a"), c("c8c8c0")][k])
	K.rect(im, 72, 0, 1, 8, c("8a6440"))
	K.rect(im, 70, 0, 5, 2, c("b8c0c8"))
	K.rect(im, 84, 2, 6, 4, c("e8d8a0"))
	K.text(im, 85, 2, "YMS", c("3a2a1e"))
	K.outline(im)
	return im


func practice_wall() -> Image:
	var w := 78
	var h := 96
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 2.0, w / 2.0 - 2.0, 2.4)
	K.rect(im, 2, 2, w - 4, h - 8, c("3e2c1e"))
	# plywood panels with a few angles
	K.rect(im, 4, 4, w - 8, h - 12, c("b8a078"))
	for by in range(4, h - 8, 24):
		K.hline(im, 4, by, w - 8, c("6a5a3a"))
	K.vline(im, w / 2, 4, h - 12, c("6a5a3a"))
	# the pattern of holds
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var cols := ["e0402e", "3a78c0", "e0b030", "3a9a5a", "d84a8a", "8a4ad0", "f2f2e8"]
	for i in 26:
		var hx := 8 + rng.randi() % (w - 20)
		var hy := 8 + rng.randi() % (h - 24)
		var col: Color = c(cols[rng.randi() % cols.size()])
		K.rect(im, hx, hy, 4, 3, col)
		K.hline(im, hx, hy, 4, col.lightened(0.3))
		K.hline(im, hx, hy + 3, 4, col.darkened(0.4))
		if i % 3 == 0:
			K.px(im, hx + 1, hy - 2, c("f4f0e0"))  # chalk
			K.px(im, hx + 2, hy - 1, c("f4f0e0"))
	# painted route line and grades
	for i in 8:
		K.px(im, 16 + i * 2, 74 - i * 7, c("c8402e"))
	K.text(im, 6, h - 16, "5.7", c("3a2a1e"))
	K.rect(im, 0, h - 8, w, 4, c("6a4a32"))
	K.outline(im)
	return im


func crash_pad() -> Image:
	var w := 72
	var h := 16
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 1.5, w / 2.0 - 2.0, 1.6)
	K.rect(im, 1, 2, w - 2, 11, c("3a78c0"))
	K.rect(im, 1, 2, w - 2, 3, c("5a98e0"))
	K.hline(im, 1, 12, w - 2, c("2a5a90"))
	for x in range(8, w - 6, 16):
		K.vline(im, x, 3, 9, c("2a5a90"))
	# a gold maker's patch with a stitched border (lettering this small
	# read as scribbles)
	K.rect(im, 30, 5, 12, 4, c("e0b030"))
	K.hline(im, 30, 5, 12, c("f4d870"))
	K.px(im, 32, 7, c("8a6a20"))
	K.px(im, 35, 7, c("8a6a20"))
	K.px(im, 38, 7, c("8a6a20"))
	K.outline(im)
	return im


func glass_case() -> Image:
	var w := 72
	var h := 40
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 2.0, w / 2.0 - 3.0, 2.2)
	K.rect(im, 2, 12, w - 4, 24, c("4a3628"))
	K.rect(im, 2, 12, w - 4, 2, c("7a5c42"))
	# glass top with gear laid out under it
	K.rect(im, 4, 14, w - 8, 18, c("2a3a44"))
	K.rect(im, 5, 15, w - 10, 16, c("3a5060"))
	# cams in a row, quickdraws, carabiners
	for i in 7:
		var x := 8 + i * 8
		K.rect(im, x, 18, 1, 6, c("c0c4c8"))
		K.rect(im, x - 1, 16, 3, 3, [c("e0402e"), c("3a78c0"), c("e0b030"), c("3a9a5a"), c("8a4ad0"), c("e07a2a"), c("d84a8a")][i])
		K.px(im, x, 24, c("6a6a72"))
	for i in 6:
		var x := 10 + i * 9
		K.rect(im, x, 26, 6, 1, c("d8d8d0"))
		K.rect(im, x, 27, 1, 3, [c("d8442a"), c("3a78c0")][i % 2])
		K.rect(im, x + 5, 27, 1, 3, c("d8d8d0"))
	# glass sheen
	K.hline(im, 6, 14, w - 12, Color(1, 1, 1, 0.35))
	for x in range(12, w - 10, 14):
		K.px(im, x, 15, Color(1, 1, 1, 0.5))
		K.px(im, x + 1, 16, Color(1, 1, 1, 0.4))
	K.rect(im, 2, 33, w - 4, 3, c("5e4632"))
	K.rect(im, 0, 36, 4, 3, c("2a1f1a"))
	K.rect(im, w - 4, 36, 4, 3, c("2a1f1a"))
	K.outline(im)
	return im


func pack_rack() -> Image:
	var w := 36
	var h := 54
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 2.0, 13.0, 1.8)
	K.rect(im, 2, 2, 3, 48, c("5a3a22"))
	K.rect(im, w - 5, 2, 3, 48, c("5a3a22"))
	for level in 3:
		var y := 6 + level * 15
		K.rect(im, 1, y + 11, w - 2, 2, c("7a5232"))
		K.hline(im, 1, y + 11, w - 2, c("b0824c"))
		var col: Array = [[c("d0702a"), c("e8904a")], [c("3a78c0"), c("5a98e0")], [c("3a9a5a"), c("5aba7a")]][level]
		K.rect(im, 5, y + 1, 11, 10, col[0])
		K.rect(im, 5, y + 1, 11, 2, col[1])
		K.rect(im, 7, y + 5, 7, 4, col[0].darkened(0.25))
		K.rect(im, 19, y + 2, 10, 9, col[0].darkened(0.1))
		K.rect(im, 19, y + 2, 10, 2, col[1])
		K.px(im, 24, y + 6, c("e0c060"))
	K.outline(im)
	return im


func workbench() -> Image:
	var w := 64
	var h := 40
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 2.0, w / 2.0 - 2.0, 2.0)
	K.rect(im, 2, 12, w - 4, 6, c("b0824c"))
	K.hline(im, 2, 12, w - 4, c("d0a06a"))
	for lx in [4, w - 8]:
		K.rect(im, lx, 18, 4, 20, c("6e4a2e"))
	K.rect(im, 4, 28, w - 8, 3, c("8a6440"))
	# a rope being cut to length, a hot knife, tape, a tape measure
	K.ellipse(im, 18, 9, 10, 4, c("3a78c0"))
	K.ellipse(im, 18, 9, 7, 2.6, c("5a98e0"))
	K.rect(im, 30, 6, 16, 3, c("3a78c0"))
	K.rect(im, 47, 5, 4, 5, c("6a6a72"))
	K.rect(im, 54, 6, 6, 5, c("e0b030"))
	K.px(im, 56, 8, c("3a2a1e"))
	K.rect(im, 14, 20, 10, 6, c("4a3628"))
	K.rect(im, 40, 20, 12, 8, c("d8442a"))
	K.outline(im)
	return im


func boot_bench() -> Image:
	var w := 44
	var h := 26
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 2.0, w / 2.0 - 2.0, 1.8)
	K.rect(im, 2, 6, w - 4, 5, c("a0764a"))
	K.hline(im, 2, 6, w - 4, c("c4996a"))
	for lx in [4, w - 8]:
		K.rect(im, lx, 11, 4, 12, c("6e4a2e"))
	# a pair of shoes and a foot-measuring stand
	K.rect(im, 8, 3, 7, 4, c("d8442a"))
	K.rect(im, 12, 1, 3, 3, c("a02a1a"))
	K.rect(im, 18, 3, 7, 4, c("d8442a"))
	K.rect(im, 30, 4, 10, 3, c("8d857a"))
	K.rect(im, 30, 2, 2, 3, c("8d857a"))
	K.outline(im)
	return im


func rope_bin() -> Image:
	var im := K.make(30, 30)
	K.shadow(im, 15.0, 28.0, 12.0, 1.8)
	K.rect(im, 3, 12, 24, 15, c("8a6440"))
	K.hline(im, 3, 12, 24, c("b58a58"))
	K.hline(im, 3, 26, 24, c("4e3220"))
	for k in 4:
		K.vline(im, 6 + k * 6, 12, 15, c("6e4a2e"))
	for k in 4:
		K.ellipse(im, 7 + k * 5, 10, 4.2, 3.2, [c("c8402e"), c("3a78c0"), c("e0b030"), c("3a9a5a")][k])
		K.ellipse(im, 7 + k * 5, 10, 1.6, 1.2, c("3e2c1e"))
	K.outline(im)
	return im


func stool() -> Image:
	var im := K.make(14, 18)
	K.shadow(im, 7.0, 16.0, 5.0, 1.2)
	K.ellipse(im, 7.0, 6.0, 5.5, 3.0, c("c0906a"))
	K.ellipse(im, 7.0, 5.4, 4.5, 2.2, c("d8aa7c"))
	K.rect(im, 3, 7, 2, 9, c("6e4a2e"))
	K.rect(im, 9, 7, 2, 9, c("6e4a2e"))
	K.hline(im, 3, 12, 8, c("5a3a22"))
	K.outline(im)
	return im
