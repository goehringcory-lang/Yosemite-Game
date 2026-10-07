extends "res://tools/hubs/curry_art.gd"
## Curry Village's buildings, cabins and entrance arch redrawn in the
## Ahwahnee's style: the hotel's materials (cut-granite footings with moss,
## stained timber and plaster, mossy shingle roofs, painted signs), ramp-shaded
## and ordered-dithered, light from the upper left, dark rim. Everything else
## in the camp keeps curry_art.gd's version. Every sprite keeps its size and
## where its doors and signs sit, so the village scene needs no changes.
## Written to assets/sprites/curry/ by save_all(). Replace any PNG with
## hand-drawn art of the same size at any time.

const ValleyArt = preload("res://tools/hubs/valley_art.gd")
const RIM := Color("231a16")

## Roof ramps, dark to light.
const GREEN_RAMP := ["1f3326", "2c4631", "3c5d3f", "4f7650", "698f62", "88aa7c"]
const SLATE_RAMP := ["22262c", "30363e", "444c56", "5a6470", "76818c", "98a3ac"]
const BROWN_RAMP := ["2c1c14", "46301f", "62432a", "7d5636", "9a7048", "b88c60"]
const RED_RAMP := ["2e1814", "4e2a20", "6e3a2a", "8c4c36", "aa6448", "c68260"]
const CANVAS_RAMP := ["6a6c76", "8e8d92", "b0aaa0", "cec6b0", "e6dec6", "f6f0dc"]

var mat := ValleyArt.new()


## Runs [param draw] with the roof ramp swapped in for the shingles.
func _with_roof(ramp: Array, draw: Callable) -> void:
	var saved := mat.roof
	mat.roof = mat._ramp(ramp)
	draw.call()
	mat.roof = saved


func _foundation(im: Image, w: int, h: int, fh: int, sd: int) -> void:
	mat.stone_wall(im, 2, h - fh - 1, w - 4, fh, sd, 0.5, 3, 3, true)
	K.hline(im, 2, h - fh - 1, w - 4, mat.granite[5])


func _shade_right(im: Image, x: int, y: int, w: int, h: int) -> void:
	ValleyArt.shade(im, x + w - 9, y, 8, h, mat.timber[0], 0.0, 0.85, 0.34, false)
	ValleyArt.shade(im, x, y + 2, 4, h, mat.granite[6], 0.5, 0.0, 0.1, false)


# ---------------------------------------------------------------- buildings

## The Registration Office: a broad lodge of stained board-and-batten under a
## moss-green shingle roof, with a posted porch, a clock, and a chimney.
func _base_registration() -> Image:
	var w := 88
	var h := 64
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 2.5, w / 2.0 - 1.0, 2.6, 0.3)
	var roof_h := 26
	var wall_top := roof_h + 1
	mat.board_wall(im, 3, wall_top, w - 6, h - wall_top - 8, 71, 3)
	_foundation(im, w, h, 7, 72)
	_with_roof(GREEN_RAMP, func() -> void:
		mat.shingle_roof(im, 0, 2, w, roof_h - 1, 73, 0.2)
		mat.gable(im, 44, wall_top - 1, 16, 15, 3, 74, true, 6)
		mat.chimney(im, 14, 8, 12, 75))
	mat.eave(im, 0, wall_top - 2, w)
	# porch: beam, posts, deck
	mat.beam(im, 1, wall_top + 2, w - 2, 76, 3)
	for px_x in [4, 24, 43, 62, 81]:
		mat.post(im, px_x, wall_top + 5, h - wall_top - 15, 77 + px_x, 3)
	for yy in 3:
		K.hline(im, 1, h - 10 + yy, w - 2, mat.timber[4 - yy])
	for wx in [10, 30, 57, 71]:
		mat.window(im, wx, wall_top + 9, 7, 9, K.hash2(wx, 5, 5) < 0.6, 80 + wx)
	mat.plank_door(im, w / 2, h - 9, 15, 81, 12)
	# the clock over the door
	K.ellipse(im, w / 2.0, wall_top + 5.0, 3.8, 3.8, mat.timber[0])
	K.ellipse(im, w / 2.0, wall_top + 5.0, 3.0, 3.0, Color("f0e6c8"))
	K.vline(im, w / 2, wall_top + 3, 3, RIM)
	K.hline(im, w / 2, wall_top + 5, 2, RIM)
	mat.sign_board(im, w / 2, wall_top - 12, "REGISTRATION")
	_shade_right(im, 3, wall_top, w - 6, h - wall_top - 8)
	K.outline(im, RIM)
	return im


## The Camp Curry Store: cream plaster, lit display windows, a striped awning,
## produce crates and a chalkboard.
func _base_store() -> Image:
	var w := 68
	var h := 58
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 2.5, w / 2.0 - 1.0, 2.6, 0.3)
	var roof_h := 22
	var wall_top := roof_h + 1
	mat.stucco_wall(im, 3, wall_top, w - 6, h - wall_top - 7, 91)
	_foundation(im, w, h, 6, 92)
	_with_roof(GREEN_RAMP, func() -> void:
		mat.shingle_roof(im, 0, 2, w, roof_h - 1, 93, 0.24)
		mat.chimney(im, 48, 7, 8, 94))
	mat.eave(im, 0, wall_top - 2, w)
	mat.sign_board(im, w / 2, wall_top + 1, "CURRY STORE")
	for wx in [8, w - 22]:
		mat.window(im, wx, wall_top + 14, 12, 10, true, 95 + wx)
	for jar in [[10, 20, "d8a040"], [14, 20, "c05a3a"], [18, 20, "8a6ad0"], [w - 20, 20, "d8a040"], [w - 16, 20, "5a9a4a"], [w - 12, 20, "c05a3a"]]:
		K.rect(im, jar[0], wall_top + jar[1] + 2, 2, 3, Color(jar[2]))
	mat.plank_door(im, w / 2, h - 8, 14, 96, 10)
	mat.awning(im, 4, wall_top + 26, w - 8, 5, Color("4f7a4a"), Color("eadfba"))
	# crates of produce and a chalkboard out front
	for crate in [[5, "d04a3a"], [w - 16, "e0c050"]]:
		K.rect(im, crate[0], h - 13, 10, 7, mat.timber[3])
		K.hline(im, crate[0], h - 13, 10, mat.timber[5])
		K.hline(im, crate[0], h - 7, 10, mat.timber[0])
		for k in 4:
			K.px(im, crate[0] + 1 + k * 2, h - 14, Color(crate[1]))
			K.px(im, crate[0] + 2 + k * 2, h - 15, Color(crate[1]).lightened(0.2))
	K.rect(im, w / 2 + 9, h - 14, 8, 9, mat.timber[0])
	K.rect(im, w / 2 + 10, h - 13, 6, 7, Color("2d3a34"))
	for k in 3:
		K.hline(im, w / 2 + 11, h - 12 + k * 2, 5 - k, Color("e8e0c8"))
	_shade_right(im, 3, wall_top, w - 6, h - wall_top - 7)
	K.outline(im, RIM)
	return im


## The Mountain Shop: slate roof, dark timber over a tall granite base, a
## big display window full of gear, and a rope coil by the door.
func _base_mountain_shop() -> Image:
	var w := 84
	var h := 66
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 2.5, w / 2.0 - 1.0, 2.6, 0.3)
	var roof_h := 26
	var wall_top := roof_h + 1
	mat.board_wall(im, 3, wall_top, w - 6, h - wall_top - 12, 111, 2, Color(0.1, 0.12, 0.2, 0.22))
	mat.stone_wall(im, 2, h - 14, w - 4, 13, 112, 0.52, 4, 3, true)
	K.hline(im, 2, h - 14, w - 4, mat.granite[5])
	_with_roof(SLATE_RAMP, func() -> void:
		mat.shingle_roof(im, 0, 2, w, roof_h - 1, 113, 0.26)
		mat.chimney(im, w - 22, 7, 10, 114))
	mat.eave(im, 0, wall_top - 2, w)
	for bx in [3, 27, w - 6]:
		mat.post(im, bx, wall_top, h - wall_top - 12, 115 + bx, 3)
	mat.sign_board(im, w / 2, wall_top - 12, "MOUNTAIN SHOP", Color("e8ecf0"))
	# the big display window, left of the door
	var wx := 8
	var wy := wall_top + 6
	K.rect(im, wx - 1, wy - 1, 30, 22, mat.timber[0])
	for yy in 20:
		for xx in 28:
			var v := float(yy) / 20.0
			K.px(im, wx + xx, wy + yy, mat.sky[clampi(roundi((0.9 - v * 0.9) * 4.0 + (K.hash2(xx, yy, 5) - 0.5)), 0, 4)].darkened(0.04 + v * 0.1))
	for hx in [14, 22]:
		K.vline(im, wx + hx, wy, 20, mat.timber[1])
	K.hline(im, wx, wy + 12, 28, mat.timber[1])
	K.rect(im, wx, wy + 20, 28, 1, mat.timber[0])
	# gear inside: rope coils, a pack, cams
	K.ellipse(im, wx + 6, wy + 15, 4, 3, Color("b03a2a"))
	K.ellipse(im, wx + 6, wy + 15, 2.4, 1.8, Color("d85a44"))
	K.ellipse(im, wx + 6, wy + 15, 1.0, 0.8, mat.sky[2])
	K.rect(im, wx + 13, wy + 8, 7, 10, Color("3a6aa8"))
	K.rect(im, wx + 13, wy + 8, 7, 2, Color("5a8ac8"))
	K.rect(im, wx + 15, wy + 12, 3, 3, Color("2a4a78"))
	for cx in [22, 24, 26]:
		K.rect(im, wx + cx, wy + 6, 1, 4, mat.granite[6])
		K.px(im, wx + cx, wy + 10, mat.warm[5])
		K.px(im, wx + cx, wy + 5, Color("d84a3a"))
	K.hline(im, wx, wy + 18, 28, mat.timber[2])
	mat.window(im, w - 18, wall_top + 7, 8, 9, K.hash2(w, 3, 3) < 0.7, 116)
	mat.plank_door(im, w / 2, h - 14, 20, 117, 14)
	# a rope coil by the door and an ice axe on the wall
	K.ellipse(im, w / 2.0 + 15.0, wall_top + 24.0, 4.4, 5.0, Color("a8372a"))
	K.ellipse(im, w / 2.0 + 15.0, wall_top + 24.0, 3.0, 3.6, Color("d05a44"))
	K.ellipse(im, w / 2.0 + 15.0, wall_top + 24.0, 1.2, 1.6, mat.timber[2])
	K.vline(im, 48, wall_top + 16, 10, mat.granite[5])
	K.rect(im, 46, wall_top + 15, 5, 2, mat.granite[5])
	_shade_right(im, 3, wall_top, w - 6, h - wall_top - 12)
	K.outline(im, RIM)
	return im


## The Pavilion: the open dining hall under a big shingle roof, with lanterns
## across the front, tables in the warm dark inside, and a stone base.
func _base_pavilion() -> Image:
	var w := 104
	var h := 66
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 2.5, w / 2.0 - 1.0, 2.6, 0.3)
	var roof_h := 30
	var wall_top := roof_h + 1
	# dark open interior with tables
	K.rect(im, 4, wall_top, w - 8, h - wall_top - 6, Color("2c2018"))
	ValleyArt.shade(im, 4, wall_top, w - 8, h - wall_top - 6, Color("120c08"), 1.0, 0.1, 0.5)
	for tx in [10, 30, 50, 70]:
		K.rect(im, tx, h - 23, 14, 5, mat.timber[3])
		K.hline(im, tx, h - 23, 14, mat.timber[5])
		K.hline(im, tx, h - 19, 14, mat.timber[0])
		K.vline(im, tx + 1, h - 18, 6, mat.timber[1])
		K.vline(im, tx + 12, h - 18, 6, mat.timber[1])
		K.rect(im, tx + 5, h - 25, 4, 2, Color("e8dcb8"))
	for gx in range(7, w - 6, 8):
		K.vline(im, gx, wall_top + 3, 6, mat.iron[2])
		K.rect(im, gx - 1, wall_top + 8, 3, 3, mat.warm[6])
		K.px(im, gx, wall_top + 8, mat.warm[7])
		K.px(im, gx, wall_top + 11, Color(1, 0.85, 0.4, 0.5))
	mat.beam(im, 4, wall_top, w - 8, 121, 3)
	# log posts
	for pxx in range(3, w - 3, 20):
		mat.post(im, pxx, wall_top, h - wall_top - 6, 122 + pxx, 4)
	mat.stone_wall(im, 2, h - 8, w - 4, 7, 123, 0.5, 3, 3, true)
	K.hline(im, 2, h - 8, w - 4, mat.granite[5])
	_with_roof(BROWN_RAMP, func() -> void:
		mat.shingle_roof(im, 0, 2, w, roof_h - 1, 124, 0.2)
		mat.gable(im, 52, wall_top - 1, 18, 17, 3, 125, true, 7)
		mat.chimney(im, w - 22, 8, 12, 126))
	mat.eave(im, 0, wall_top - 2, w)
	# the way in: steps and the sign
	K.rect(im, w / 2 - 8, h - 8, 16, 4, mat.granite[4])
	K.hline(im, w / 2 - 8, h - 8, 16, mat.granite[6])
	mat.sign_board(im, w / 2, wall_top - 12, "PAVILION")
	_shade_right(im, 3, wall_top, w - 6, h - wall_top - 6)
	K.outline(im, RIM)
	return im


func _base_pizza_deck() -> Image:
	var w := 64
	var h := 50
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 2.5, w / 2.0 - 1.0, 2.6, 0.3)
	var roof_h := 18
	var wall_top := roof_h + 1
	mat.stucco_wall(im, 4, wall_top, w - 8, 14, 131)
	_with_roof(RED_RAMP, func() -> void:
		mat.shingle_roof(im, 0, 2, w, roof_h - 1, 132, 0.28))
	mat.eave(im, 0, wall_top - 2, w)
	mat.sign_board(im, w / 2, wall_top + 2, "PIZZA")
	# the wood-fired oven mouth
	K.rect(im, w / 2 - 5, wall_top + 11, 11, 5, mat.granite[1])
	K.rect(im, w / 2 - 4, wall_top + 12, 9, 3, mat.warm[4])
	K.px(im, w / 2, wall_top + 13, mat.warm[7])
	# the deck with rails and two umbrella tables
	for yy in 16:
		for xx in w - 4:
			var n := K.hash2(xx, yy, 133)
			var idx := 3 if (yy / 3) % 2 == 0 else 2
			K.px(im, 2 + xx, h - 20 + yy, mat.timber[clampi(idx + (1 if n > 0.9 else 0) - (1 if n < 0.08 else 0), 0, 5)])
	K.hline(im, 2, h - 20, w - 4, mat.timber[5])
	for rx in range(4, w - 2, 6):
		mat.post(im, rx, h - 11, 7, 134 + rx, 2)
	K.hline(im, 2, h - 12, w - 4, mat.timber[4])
	K.hline(im, 2, h - 11, w - 4, mat.timber[1])
	for tx in [10, 38]:
		K.ellipse(im, tx + 8, h - 15, 8, 3, Color("b8382a"))
		K.ellipse(im, tx + 8, h - 15, 5, 1.6, Color("eadfba"))
		K.ellipse(im, tx + 8, h - 16, 2, 1, Color("d8583a"))
		K.rect(im, tx + 8, h - 15, 1, 8, mat.timber[1])
		K.ellipse(im, tx + 8, h - 9, 5, 2, mat.timber[3])
	_shade_right(im, 4, wall_top, w - 8, 14)
	K.outline(im, RIM)
	return im


func amphitheater() -> Image:
	var w := 96
	var h := 62
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 2.0, w / 2.0 - 2.0, 3.0, 0.3)
	# granite terrace under everything
	mat.stone_wall(im, 0, 20, w, h - 21, 141, 0.62, 5, 3, false)
	# the stage: a raised timber platform with a plank backdrop and curtains
	K.rect(im, 18, 2, 60, 22, mat.timber[0])
	mat.board_wall(im, 19, 3, 58, 13, 142, 3)
	for cx in [19, 68]:
		for yy in 13:
			for xx in 9:
				var n := K.hash2(xx, yy, 143)
				K.px(im, cx + xx, 3 + yy, Color("8a2e2a").lerp(Color("5a1c1a"), float(xx % 3) / 3.0 * 0.6 + n * 0.2))
	K.rect(im, 19, 0, 58, 4, mat.leaf[1])
	K.hline(im, 19, 0, 58, mat.leaf[3])
	K.text_centered(im, 19, 58, 0, "CAMP CURRY", Color("f0e2bc"), mat.leaf[0])
	K.rect(im, 16, 16, 64, 7, mat.timber[3])
	K.hline(im, 16, 16, 64, mat.timber[5])
	K.hline(im, 16, 22, 64, mat.timber[0])
	# a stone aisle down the middle
	K.rect(im, w / 2 - 4, 24, 8, h - 25, mat.granite[5])
	for y in range(26, h - 2, 4):
		K.hline(im, w / 2 - 4, y, 8, mat.granite[3])
	# benches in rows, on either side
	for row in 5:
		var y := 28 + row * 6
		for side in [-1, 1]:
			var bx: int = w / 2 + side * 7
			var length := 34 + row * 2
			var x0: int = bx if side > 0 else bx - length
			for seg in range(0, length, 9):
				var sl := mini(8, length - seg)
				K.rect(im, x0 + seg, y, sl, 2, mat.timber[4])
				K.hline(im, x0 + seg, y, sl, mat.timber[5])
				K.hline(im, x0 + seg, y + 2, sl, mat.timber[1])
				K.px(im, x0 + seg + 1, y + 3, mat.timber[0])
				K.px(im, x0 + seg + sl - 2, y + 3, mat.timber[0])
	K.outline(im, RIM)
	return im


## The old arch over the way in: two stone-footed log posts under a painted
## plank sign, with lanterns.
func entrance_sign() -> Image:
	var w := 72
	var h := 46
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 2.0, w / 2.0 - 3.0, 2.4, 0.3)
	for pxx in [3, w - 8]:
		mat.post(im, pxx, 14, h - 16, 150 + pxx, 5)
		mat.stone_wall(im, pxx - 2, h - 7, 9, 5, 151 + pxx, 0.52, 3, 2, true)
	K.rect(im, 1, 1, w - 2, 19, mat.timber[0])
	for yy in 17:
		for xx in w - 4:
			var n := K.hash2(xx, yy, 152)
			K.px(im, 2 + xx, 2 + yy, mat.leaf[1 if n > 0.1 else 0].lerp(mat.leaf[2], 0.3))
	K.hline(im, 2, 2, w - 4, mat.leaf[4])
	K.rect(im, 1, 1, w - 2, 1, mat.timber[4])
	K.text_centered(im, 2, w - 4, 5, "CAMP CURRY", Color("f0e2bc"), mat.timber[0])
	K.text_centered(im, 2, w - 4, 13, "EST 1899", Color("d9a23e"), mat.timber[0])
	for i in 14:
		K.px(im, 4 + i * 5, 3, Color("b0492a") if i % 2 == 0 else Color("3ca59a"))
	for lx in [14, w - 15]:
		K.rect(im, lx, 20, 2, 4, mat.iron[1])
		K.rect(im, lx - 1, 23, 4, 5, mat.iron[1])
		K.rect(im, lx, 24, 2, 3, mat.warm[6])
		K.px(im, lx, 24, mat.warm[7])
	K.outline(im, RIM)
	return im


# ---------------------------------------------------------------- cabins

## A tent cabin: canvas over a timber frame on a plank deck, with a door
## flap, a numbered plate, and something on the deck that varies by tent.
func tent_cabin(variant: int) -> Image:
	var w := 46
	var h := 48
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 3.0, w / 2.0 - 3.0, 2.6, 0.3)
	var canvas := mat._ramp(CANVAS_RAMP)
	var trim: Color = [Color("4f7a4a"), Color("8a6a48"), Color("4a6f90"), Color("9a5444")][(variant / 2) % 4]
	var x0 := 4
	var bw := w - 8
	# guy ropes and stakes
	for side in [0, 1]:
		var sx: int = 1 if side == 0 else w - 2
		var ex: int = x0 + 2 if side == 0 else w - x0 - 3
		for t in 14:
			K.px(im, int(lerpf(float(ex), float(sx), t / 13.0)), int(lerpf(20.0, float(h - 7), t / 13.0)), Color("c8bea4"))
		K.rect(im, sx - 1, h - 8, 2, 4, mat.timber[1])
	# plank deck
	for yy in 8:
		for xx in w - 4:
			var n := K.hash2(xx, yy, 160 + variant)
			var idx := 3 + (1 if xx % 6 == 0 else 0) - (1 if n < 0.1 else 0)
			K.px(im, 2 + xx, h - 12 + yy, mat.timber[clampi(idx - (1 if yy > 5 else 0), 0, 5)])
	K.hline(im, 2, h - 12, w - 4, mat.timber[5])
	K.hline(im, 2, h - 5, w - 4, mat.timber[0])
	ValleyArt.shade(im, 2, h - 4, w - 4, 3, mat.timber[0], 1.0, 0.0, 0.4)
	# canvas front wall with folds, over corner posts
	var wall_top := 20
	var wall_h := h - 12 - wall_top
	for yy in wall_h:
		for xx in bw:
			var u := float(xx) / bw
			var t := 0.78 - u * 0.34 + (K.hash2(xx, yy, 161) - 0.5) * 0.08
			if (xx - 3) % 6 == 0:
				t -= 0.14
			elif (xx - 3) % 6 == 1:
				t += 0.05
			K.px(im, x0 + xx, wall_top + yy, canvas[clampi(roundi(t * 5.0), 0, 5)])
	K.hline(im, x0, h - 13, bw, canvas[1])
	for fx in [x0 - 1, x0 + bw - 2]:
		mat.post(im, fx, wall_top - 1, wall_h + 2, 162 + fx, 3)
	# roof: two-tone canvas, seams, scalloped trim, ridge pole
	for y in wall_top:
		var t := float(y) / wall_top
		var inset := int((1.0 - t) * 11.0)
		for x in range(x0 - 2 + inset, x0 + bw + 2 - inset):
			var f := float(x - x0) / bw
			var tone := 0.82 - f * 0.4 + (1.0 - t) * 0.06 + (K.hash2(x, y, 163) - 0.5) * 0.06
			if (x - x0 - 3) % 9 == 0:
				tone -= 0.14
			if x == x0 - 2 + inset:
				tone += 0.12
			K.px(im, x, y, canvas[clampi(roundi(tone * 5.0), 0, 5)])
	# worn canvas: darker, stained lower corners and eave, a lit seam beside each
	# dark one, pine-needle litter and a stitched patch
	for y in wall_top:
		var t2 := float(y) / wall_top
		var inset2 := int((1.0 - t2) * 11.0)
		for x in range(x0 - 2 + inset2, x0 + bw + 2 - inset2):
			var col := im.get_pixel(x, y)
			if (x - x0 - 3) % 9 == 1:
				col = col.lightened(0.06)
			var stain := smoothstep(0.55, 1.0, t2) * (0.1 + 0.18 * K.hash2(x / 4, y / 3, 170 + variant))
			if x < x0 + 5 or x > x0 + bw - 6:
				stain += 0.05
			col = col.darkened(stain)
			if K.hash2(x, y, 171 + variant) > 0.985 and t2 > 0.3:
				col = mat.leaf[1] if K.hash2(x, y, 172) > 0.5 else mat.timber[2]
			im.set_pixel(x, y, col)
	# sag creases running from the ridge toward the corners
	for side in [-1, 1]:
		for k in 12:
			var cx2: int = w / 2 + side * (3 + k)
			var cy2: int = 2 + k
			if cx2 > x0 - 2 and cx2 < x0 + bw + 2 and cy2 < wall_top - 2:
				im.set_pixel(cx2, cy2, im.get_pixel(cx2, cy2).darkened(0.12))
	if variant % 3 == 0:
		var px0 := x0 + 8 + (variant % 4) * 4
		K.rect(im, px0, 9, 7, 5, canvas[4])
		for sx in range(px0, px0 + 7, 2):
			K.px(im, sx, 9, canvas[1])
			K.px(im, sx, 13, canvas[1])
		K.vline(im, px0, 9, 5, canvas[1])
		K.vline(im, px0 + 6, 9, 5, canvas[1])
	if variant % 4 == 1:
		# a stovepipe with a cap and flashing
		var sx2 := w - 15
		K.rect(im, sx2, 1, 3, 9, mat.iron[1])
		K.vline(im, sx2, 1, 9, mat.iron[3])
		K.rect(im, sx2 - 1, 0, 5, 2, mat.iron[2])
		K.rect(im, sx2 - 1, 9, 5, 2, mat.iron[0])
	for x in range(x0 - 2, x0 + bw + 2):
		var hem := trim if ((x - x0) / 3) % 2 == 0 else trim.darkened(0.2)
		K.px(im, x, wall_top - 2, hem)
		K.px(im, x, wall_top - 1, hem.darkened(0.25))
	ValleyArt.shade(im, x0, wall_top, bw, 4, mat.timber[0], 1.0, 0.0, 0.34)
	K.hline(im, x0 + 8, 0, bw - 16, mat.timber[4])
	K.hline(im, x0 + 8, 1, bw - 16, mat.timber[2])
	# door: tied-back flaps around a dark screened opening
	var dx := w / 2 - 6
	K.rect(im, dx, wall_top + 3, 12, wall_h - 3, mat.timber[0])
	K.rect(im, dx + 1, wall_top + 5, 10, wall_h - 6, Color("3a2e24"))
	for nx in range(dx + 2, dx + 10, 2):
		K.vline(im, nx, wall_top + 5, wall_h - 6, Color("4e4032"))
	K.rect(im, dx - 3, wall_top + 3, 3, wall_h - 3, canvas[2])
	K.rect(im, dx + 12, wall_top + 3, 3, wall_h - 3, canvas[1])
	for pole_x in [dx - 4, dx + 15]:
		mat.post(im, pole_x, wall_top + 6, wall_h - 3, 164 + pole_x, 2)
	for row in 4:
		K.hline(im, dx - 6 - (3 - row), wall_top + 3 + row, 24 + (3 - row) * 2, canvas[3] if row < 3 else trim)
	# hanging number plate: stained board, warm lettering
	var plate := str(200 + variant * 3 + (variant / 7) * 2)
	K.rect(im, dx - 1, wall_top + 8, 14, 8, mat.timber[0])
	K.rect(im, dx, wall_top + 9, 12, 6, mat.leaf[1])
	K.hline(im, dx, wall_top + 9, 12, mat.leaf[3])
	K.text(im, dx + 1, wall_top + 9, plate, Color("f0e2bc"))
	K.px(im, dx + 2, wall_top + 7, mat.iron[1])
	K.px(im, dx + 9, wall_top + 7, mat.iron[1])
	# a screened window on the left wall panel
	K.rect(im, x0 + 3, wall_top + 5, 7, 6, mat.timber[1])
	K.rect(im, x0 + 4, wall_top + 6, 5, 4, Color("9fbcae"))
	K.px(im, x0 + 6, wall_top + 6, Color("cfe4d8"))
	# steps
	K.rect(im, dx + 1, h - 8, 11, 3, mat.granite[4])
	K.hline(im, dx + 1, h - 8, 11, mat.granite[6])
	# per-tent dressing on the deck
	match (variant * 3 + variant / 5) % 5:
		0:
			K.rect(im, w - 15, h - 19, 9, 7, Color("c0402a"))
			K.rect(im, w - 15, h - 19, 9, 2, Color("e0684a"))
			K.rect(im, w - 14, h - 13, 2, 3, Color("7a2418"))
			K.rect(im, w - 8, h - 13, 2, 3, Color("7a2418"))
		1:
			K.rect(im, 5, h - 17, 8, 5, Color("3a70b0"))
			K.rect(im, 5, h - 17, 8, 2, Color("eee8d8"))
			K.rect(im, 14, h - 15, 5, 3, mat.timber[0])
			K.px(im, 15, h - 16, Color("e8dcc0"))
		2:
			K.rect(im, w - 9, wall_top + 6, 3, 5, mat.iron[1])
			K.rect(im, w - 8, wall_top + 7, 1, 3, mat.warm[6])
			K.rect(im, w - 16, h - 19, 9, 7, Color("3a70b0"))
			K.rect(im, w - 16, h - 19, 9, 2, Color("5a90d0"))
		3:
			K.rect(im, 6, h - 18, 3, 6, mat.timber[0])
			K.rect(im, 10, h - 18, 3, 6, mat.timber[0])
			K.px(im, 7, h - 19, Color("e8dcc0"))
			K.rect(im, w - 16, h - 19, 9, 7, Color("3a8a56"))
			K.rect(im, w - 16, h - 19, 9, 2, Color("58aa74"))
		4:
			K.rect(im, 4, h - 17, 10, 4, mat.warm[4])
			K.hline(im, 4, h - 17, 10, mat.warm[6])
			K.rect(im, 8, wall_top + 7, 3, 5, mat.iron[1])
			K.rect(im, 9, wall_top + 8, 1, 3, mat.warm[6])
	_shade_right(im, x0, wall_top, bw, wall_h)
	K.outline(im, RIM)
	return im


## A small wood cabin: stained boards on a granite footing under a shingle
## roof, with a porch light and a flower box.
func _base_wood_cabin(variant: int) -> Image:
	var w := 42
	var h := 40
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 2.5, w / 2.0 - 1.0, 2.4, 0.3)
	var roof_h := 16
	var wall_top := roof_h + 1
	mat.board_wall(im, 3, wall_top, w - 6, h - wall_top - 6, 171 + variant, 3 if variant == 0 else 2)
	_foundation(im, w, h, 5, 172 + variant)
	_with_roof(GREEN_RAMP if variant == 0 else BROWN_RAMP, func() -> void:
		mat.shingle_roof(im, 0, 2, w, roof_h - 1, 173 + variant, 0.26))
	mat.eave(im, 0, wall_top - 2, w)
	mat.plank_door(im, 11, h - 6, 13, 174, 9)
	mat.window(im, w - 18, wall_top + 5, 8, 8, K.hash2(variant, 9, 9) < 0.6, 175)
	K.rect(im, w - 19, wall_top + 15, 12, 3, mat.timber[1])
	K.hline(im, w - 19, wall_top + 15, 12, mat.timber[4])
	for f in [[w - 18, "e04a6a"], [w - 15, "f2d25c"], [w - 12, "e04a6a"], [w - 9, "f2ecd6"]]:
		K.px(im, f[0], wall_top + 14, Color(f[1]))
		K.px(im, f[0], wall_top + 13, Color(f[1]).lightened(0.2))
	K.text(im, 7, wall_top + 3, str(31 + variant * 4), Color("f0e2bc"), mat.timber[0])
	_shade_right(im, 3, wall_top, w - 6, h - wall_top - 6)
	K.outline(im, RIM)
	return im


# ---------------------------------------------------------------- finishing

## Weathering and lived-in detail shared by the camp's buildings: pale lichen
## and moss patches on the roof, a lit ridge, rain streaks down the wall under
## the eaves, and a bleached sun-side edge. [param wall_top] is the first wall
## row; [param seed_value] varies the patches between buildings.
func _weather(im: Image, wall_top: int, seed_value: int) -> void:
	var w := im.get_width()
	var h := im.get_height()
	for y in range(2, wall_top - 2):
		for x in w:
			var c := im.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var n := K.hash2(x / 3, y / 2, seed_value)
			if n > 0.965:
				im.set_pixel(x, y, c.lerp(mat.moss[2], 0.55))
			elif n < 0.03:
				im.set_pixel(x, y, c.lerp(Color("b8c0a0"), 0.35))
	# the topmost opaque pixel of each column is the ridge or eave line: light it
	for x in w:
		for y in range(0, h):
			var c := im.get_pixel(x, y)
			if c.a > 0.5:
				if y < wall_top - 4 and c.get_luminance() > 0.12:
					im.set_pixel(x, y, c.lightened(0.08))
				break
	# rain streaks under the eave
	for x in range(5, w - 5):
		if K.hash2(x, seed_value, 3) > 0.82:
			var len := 3 + int(K.hash2(x, seed_value, 4) * 7.0)
			for k in len:
				var y := wall_top + 1 + k
				var c := im.get_pixel(x, y)
				if c.a > 0.5 and y < h - 8:
					im.set_pixel(x, y, c.darkened(0.08 * (1.0 - float(k) / len) + 0.02))
	# moss creeping up from the footing
	for x in range(3, w - 3):
		var up := 1 + int(K.hash2(x, seed_value, 5) * 3.0)
		for k in up:
			var y := h - 9 - k
			var c := im.get_pixel(x, y)
			if c.a > 0.5 and K.hash2(x, y, seed_value) > 0.4:
				im.set_pixel(x, y, c.lerp(mat.moss[1], 0.5))


## A hanging lantern on a bracket and a little glow, for porches.
func _porch_lamp(im: Image, x: int, y: int) -> void:
	K.hline(im, x - 2, y - 2, 3, mat.iron[2])
	K.vline(im, x, y - 2, 2, mat.iron[2])
	K.rect(im, x - 1, y, 3, 4, mat.iron[1])
	K.rect(im, x, y + 1, 1, 2, mat.warm[6])
	K.px(im, x, y + 1, mat.warm[7])
	K.hline(im, x - 1, y + 4, 3, mat.iron[3])
	for dy in range(-1, 7):
		for dx in range(-3, 4):
			if absf(dx) + absf(dy - 2) <= 3 and im.get_pixel(x + dx, y + dy).a > 0.5 and (dx != 0 or dy < 0 or dy > 3):
				var c := im.get_pixel(x + dx, y + dy)
				im.set_pixel(x + dx, y + dy, c.lerp(Color(1, 0.85, 0.5), 0.12))


func registration() -> Image:
	var im := _base_registration()
	_weather(im, 27, 701)
	_porch_lamp(im, 10, 38)
	_porch_lamp(im, 78, 38)
	_hanging_flowers(im, 24, 36, Color("e04a6a"))
	_hanging_flowers(im, 62, 36, Color("f2d25c"))
	return im


func store() -> Image:
	var im := _base_store()
	_weather(im, 23, 702)
	_porch_lamp(im, 31, 24)
	return im


func mountain_shop() -> Image:
	var im := _base_mountain_shop()
	_weather(im, 27, 703)
	_porch_lamp(im, 52, 38)
	return im


func pavilion() -> Image:
	var im := _base_pavilion()
	_weather(im, 31, 704)
	return im


func pizza_deck() -> Image:
	var im := _base_pizza_deck()
	_weather(im, 19, 705)
	return im


## A hanging basket of flowers from a porch beam.
func _hanging_flowers(im: Image, x: int, y: int, bloom: Color) -> void:
	K.vline(im, x, y - 3, 3, mat.iron[2])
	K.rect(im, x - 3, y, 7, 3, mat.timber[1])
	K.hline(im, x - 3, y, 7, mat.timber[4])
	for k in 7:
		K.px(im, x - 3 + k, y - 1, mat.leaf[3])
		if K.hash2(k, x, 9) > 0.35:
			K.px(im, x - 3 + k, y - 2, bloom if k % 2 == 0 else bloom.lightened(0.3))
	for k in 5:
		K.px(im, x - 2 + k, y + 3, mat.leaf[2])
		if k % 2 == 0:
			K.px(im, x - 2 + k, y + 4, mat.leaf[3])


## The small wood cabins get a stone chimney with smoke-stained cap, a log
## step, a stack of split firewood, and a porch lantern beside the door.
func wood_cabin(variant: int) -> Image:
	var im := _base_wood_cabin(variant)
	_weather(im, 17, 710 + variant)
	var w := im.get_width()
	var h := im.get_height()
	# chimney on the right of the roof
	var cx := w - 12
	for y in range(2, 14):
		for x in range(cx, cx + 5):
			if im.get_pixel(x, y).a < 0.5 or y < 9:
				var u := float(x - cx) / 4.0
				var tone := clampf(0.7 - u * 0.5 + (K.hash2(x, y, 90) - 0.5) * 0.3, 0.0, 0.99)
				var col: Color = mat.granite[clampi(int(tone * 6.0), 1, 6)]
				if (y + (x / 2)) % 4 == 0:
					col = col.darkened(0.18)
				im.set_pixel(x, y, col)
	K.hline(im, cx - 1, 2, 7, mat.granite[6])
	K.hline(im, cx - 1, 3, 7, mat.granite[1])
	K.rect(im, cx + 1, 1, 3, 1, Color(0.8, 0.8, 0.84, 0.5))
	# a short stack of split firewood tucked at the left corner
	for row in 2:
		for col_i in 2:
			var lx := 1 + col_i * 3 + (row % 2)
			var ly := h - 8 - row * 3
			K.rect(im, lx, ly, 3, 3, mat.timber[3 - (row + col_i) % 2])
			K.px(im, lx + 1, ly + 1, mat.timber[5])
			K.hline(im, lx, ly + 2, 3, mat.timber[0])
	# log step and porch lamp
	K.rect(im, 8, h - 5, 7, 2, mat.timber[2])
	K.hline(im, 8, h - 5, 7, mat.timber[5])
	_porch_lamp(im, 19, 24)
	K.outline(im, RIM)
	return im
