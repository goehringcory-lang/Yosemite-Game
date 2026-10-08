extends "res://tools/hubs/interior_art.gd"
## The Camp Curry Store and Mountain Shop interiors with the Ahwahnee's
## materials on the room shells: stained-timber plank floors ramp-shaded and
## dithered (darker toward the walls, warm in the middle), window frames with
## a granite sill and the Valley's pines beyond, wrought-iron lanterns whose
## light pools on the walls and floor, wainscoting with raised panels, and
## shelves stocked with colorful jars, tins and boxes. Tones are hue-shifted
## (shadows cool, lights warm). The room walls, doors and windows keep their
## places, and the furniture keeps interior_art.gd's sizes and footprints.
## Written to assets/sprites/curry/interiors/.

const ValleyArt = preload("res://tools/hubs/valley_art.gd")

var mat := ValleyArt.new()


## Shifts [param col]: [param light] lightens or darkens it, and [param warm]
## pulls the hue toward yellow (warm > 0) or toward blue (warm < 0), the short
## way round the color wheel.
func _tone(col: Color, light: float, warm: float) -> Color:
	var target := 0.12 if warm > 0.0 else 0.58
	var d := fposmod(target - col.h + 0.5, 1.0) - 0.5
	var hue := fposmod(col.h + d * clampf(absf(warm) * 0.22, 0.0, 0.22), 1.0)
	var sat := clampf(col.s + (0.03 if light > 0.0 else 0.0), 0.0, 1.0)
	return Color.from_hsv(hue, sat, clampf(col.v + light, 0.0, 1.0), col.a)


## Stained plank flooring: courses of boards with staggered joints, a lit
## edge on every board, and shade where the floor meets the walls.
func _floor(im: Image, y0: int, y1: int, base: Color, seed_value: int) -> void:
	var bias := base.get_luminance() - 0.36
	for y in range(y0, y1):
		var row := (y - y0) / 8
		var in_row := (y - y0) % 8
		for x in W:
			var shift := (row % 3) * 37
			var plank := (x + shift) / 64
			var n := K.hash2(plank, row, seed_value)
			var t := 0.5 + bias * 1.3 + (n - 0.5) * 0.22 + (K.hash2(x / 3, y / 2, seed_value + 6) - 0.5) * 0.05
			var idx := roundi(t * 5.0)
			if in_row == 0:
				idx = 0
			elif in_row == 1:
				idx += 1
			elif in_row == 7:
				idx -= 1
			if (x + shift) % 64 == 0:
				idx = 0
			K.px(im, x, y, mat.timber[clampi(idx, 0, 5)])
		for i in 10:
			var gx := int(K.hash2(i, y, seed_value + 4) * W)
			if in_row > 1 and in_row < 7 and K.hash2(gx, y, seed_value + 5) > 0.72:
				K.px(im, gx, y, mat.timber[1])
				K.px(im, gx + 1, y, mat.timber[2])
	for i in 26:
		var kx := int(K.hash2(i, 3, seed_value) * W)
		var ky := y0 + int(K.hash2(i, 4, seed_value) * (y1 - y0 - 4)) + 2
		K.ellipse(im, kx, ky, 1.8, 1.2, mat.timber[1])
		K.px(im, kx, ky, mat.timber[0])
	# ambient occlusion along the walls, and a soft warm pool in the middle
	ValleyArt.shade(im, 0, y0, W, 14, mat.timber[0], 1.0, 0.0, 0.42)
	ValleyArt.shade(im, 0, y0, 14, y1 - y0, mat.timber[0], 1.0, 0.0, 0.36, false)
	ValleyArt.shade(im, W - 14, y0, 14, y1 - y0, mat.timber[0], 0.0, 1.0, 0.36, false)


## Lap siding with a lit top edge on each board and a dark seam under it.
func _lap(im: Image, x: int, y: int, w: int, h: int, base: Color, sd: int) -> void:
	for row in range(0, h, 4):
		var tone := _tone(base, (K.hash2(row, sd, 1) - 0.5) * 0.05, 0.5)
		K.rect(im, x, y + row, w, 3, tone)
		K.hline(im, x, y + row, w, tone.lightened(0.1))
		K.hline(im, x, y + row + 3, w, _tone(base, -0.2, -0.6))
	for i in int(w / 30.0):
		var gx := x + int(K.hash2(i, sd, 7) * w)
		var gy := y + int(K.hash2(i, sd, 8) * h)
		K.hline(im, gx, gy, 4, _tone(base, -0.12, -0.4))


## Vertical boards in a warm tone, with a lit edge and a shaded seam.
func _vboards(im: Image, x: int, y: int, w: int, h: int, base: Color, sd: int, board := 4) -> void:
	for xx in w:
		var b := xx / board
		var ib := xx % board
		var tone := _tone(base, (K.hash2(b, sd, 3) - 0.5) * 0.08, 0.4)
		if ib == 0:
			tone = tone.lightened(0.07)
		elif ib == board - 1:
			tone = _tone(base, -0.2, -0.6)
		for yy in h:
			var n := K.hash2(x + xx, yy / 4, sd + 2)
			var col := tone.darkened(0.05) if n > 0.9 else tone
			K.px(im, x + xx, y + yy, col)


## A wainscot: vertical boards in a deep green with raised panels, a chair rail
## on top, and a dark baseboard.
func _wainscot(im: Image, x: int, y: int, w: int, h: int, base: Color, sd: int) -> void:
	_vboards(im, x, y, w, h, base, sd, 5)
	for px_x in range(x + 6, x + w - 10, 40):
		K.rect(im, px_x, y + 4, 30, h - 8, _tone(base, -0.08, -0.4))
		K.hline(im, px_x, y + 4, 30, _tone(base, 0.1, 0.6))
		K.vline(im, px_x, y + 4, h - 8, _tone(base, 0.06, 0.4))
		K.hline(im, px_x, y + h - 5, 30, _tone(base, -0.2, -0.8))
	K.hline(im, x, y, w, _tone(base, 0.16, 0.8))
	K.hline(im, x, y + h - 2, w, _tone(base, -0.26, -1.0))


## A soft pool of lantern light, falling off with the square of distance.
func _pool(im: Image, cx: int, cy: int, r: int, strength: float) -> void:
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			var d := Vector2(x - cx, y - cy).length() / float(r)
			if d >= 1.0:
				continue
			var a := strength * (1.0 - d) * (1.0 - d)
			K.px(im, x, y, Color(1.0, 0.84, 0.5, a))


## Jars, tins and boxes for the shelves: each a readable color with a label.
func _stock_jar(im: Image, x: int, y: int, col: Color) -> void:
	K.rect(im, x, y + 2, 4, 6, col)
	K.vline(im, x, y + 2, 6, col.lightened(0.3))
	K.vline(im, x + 3, y + 2, 6, col.darkened(0.3))
	K.rect(im, x + 1, y, 2, 2, c("c8b078"))
	K.hline(im, x, y + 4, 4, c("f4ecd0"))


func _stock_can(im: Image, x: int, y: int, col: Color) -> void:
	K.rect(im, x, y + 1, 3, 5, col)
	K.hline(im, x, y + 1, 3, c("d8d8d0"))
	K.hline(im, x, y + 3, 3, c("f4ecd0"))
	K.px(im, x + 2, y + 5, col.darkened(0.3))


func _stock_box(im: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	K.rect(im, x, y, w, h, col)
	K.hline(im, x, y, w, col.lightened(0.22))
	K.vline(im, x + w - 1, y, h, col.darkened(0.3))
	K.rect(im, x + 1, y + h / 2 - 1, w - 2, 2, c("f4ecd0"))


## A wrought-iron lantern on a bracket, glowing warm, with its light falling on
## the wall around it and a brighter pool on the floor below.
func _sconce(im: Image, x: int, y: int) -> void:
	_pool(im, x, y + 8, 30, 0.1)
	K.rect(im, x - 1, y - 1, 3, 1, mat.iron[3])
	K.rect(im, x - 2, y, 5, 6, mat.iron[1])
	K.vline(im, x - 2, y, 6, mat.iron[3])
	K.rect(im, x - 1, y + 1, 3, 4, mat.warm[6])
	K.px(im, x, y + 1, mat.warm[7])
	K.px(im, x - 1, y + 1, mat.warm[7])
	K.hline(im, x - 2, y + 6, 5, mat.iron[3])
	for r in range(2, 11):
		K.ellipse(im, x, y + 3, r, r, Color(1, 0.84, 0.46, 0.035 * (11 - r) / 9.0))


## A window of light on the wall with a stained frame, a granite sill, the
## Valley's pines beyond, and a soft shaft of sun across the floor.
func _window_light(im: Image, x: int, y: int, w: int, h: int, floor_y: int, floor_h: int, dx: int) -> void:
	K.rect(im, x - 2, y - 2, w + 4, h + 4, mat.timber[0])
	K.hline(im, x - 2, y - 2, w + 4, mat.timber[3])
	for yy in h:
		for xx in w:
			var v := float(yy) / h
			K.px(im, x + xx, y + yy, mat.sky[clampi(roundi((0.95 - v * 0.7) * 4.0 + (K.hash2(xx, yy, 3) - 0.5) * 0.8), 0, 4)])
	for tx in range(x + 2, x + w - 2, 6):
		K.rect(im, tx, y + h - 8, 3, 8, mat.leaf[2])
		K.rect(im, tx + 1, y + h - 12, 1, 4, mat.leaf[2])
		K.px(im, tx, y + h - 8, mat.leaf[4])
	K.vline(im, x + w / 2, y, h, mat.timber[1])
	K.hline(im, x, y + h / 2, w, mat.timber[1])
	K.rect(im, x - 3, y + h + 2, w + 6, 2, mat.granite[5])
	K.hline(im, x - 3, y + h + 2, w + 6, mat.granite[6])
	for yy in floor_h:
		var t := float(yy) / floor_h
		var shift := int(dx * t)
		for xx in w:
			K.px(im, x + xx + shift, floor_y + yy, Color(1, 0.94, 0.72, 0.18 * (1.0 - t * 0.6)))


# ---------------------------------------------------------------- finishing

func save_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var rooms := {"store_room": store_room(), "shop_room": shop_room()}
	var props := {
		"store_counter": store_counter(), "store_shelf": store_shelf(), "produce_table": produce_table(),
		"store_stove": stove_sheet(), "store_cooler": cooler(), "store_chalkboard": chalkboard(),
		"store_barrels": barrels(), "postcard_rack": postcard_rack(),
		"shop_counter": shop_counter(), "practice_wall": practice_wall(), "crash_pad": crash_pad(),
		"glass_case": glass_case(), "pack_rack": pack_rack(), "workbench": workbench(),
		"boot_bench": boot_bench(), "shop_stove": stove_sheet(), "rope_bin": rope_bin(), "stool": stool(),
	}
	for image_name: String in rooms:
		(rooms[image_name] as Image).save_png(ProjectSettings.globalize_path(DIR + image_name + ".png"))
	for image_name: String in props:
		var im: Image = props[image_name]
		# The stove sheets are animation frames side by side: leave them be.
		if not image_name.ends_with("stove"):
			_light_prop(im)
		im.save_png(ProjectSettings.globalize_path(DIR + image_name + ".png"))


## Lights a furniture sprite from the upper left: a lit top and left edge, a
## shaded base and right edge, so a flat block reads as a solid object.
func _light_prop(im: Image) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var src := im.duplicate() as Image
	var top := h
	var bottom := 0
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.5:
				top = mini(top, y)
				bottom = maxi(bottom, y)
	if bottom <= top:
		return
	for y in range(top, bottom + 1):
		var t := float(y - top) / float(bottom - top)
		for x in w:
			var col := src.get_pixel(x, y)
			if col.a < 0.5:
				continue
			var dark := col.get_luminance() < 0.1 # the outline
			if dark:
				continue
			col = col.lightened(0.1 * (1.0 - t * 1.6)) if t < 0.62 else col.darkened(0.14 * (t - 0.62) / 0.38)
			var left_edge := x == 0 or src.get_pixel(x - 1, y).a < 0.5 or src.get_pixel(x - 1, y).get_luminance() < 0.1
			var right_edge := x == w - 1 or src.get_pixel(x + 1, y).a < 0.5 or src.get_pixel(x + 1, y).get_luminance() < 0.1
			if left_edge:
				col = col.lightened(0.1)
			elif right_edge:
				col = col.darkened(0.12)
			im.set_pixel(x, y, col)


## Room-wide light: the back wall brightens toward the middle and falls off
## into the corners, a beam of shadow runs under the ceiling line, and the
## whole room gets a warm lamp-lit center with darker edges.
func _room_finish(im: Image, wall_h: int) -> void:
	for y in H:
		for x in W:
			var dx := (x - W / 2.0) / (W / 2.0)
			var dy := (y - H * 0.55) / (H * 0.55)
			var v := clampf(dx * dx * 0.55 + dy * dy * 0.45, 0.0, 1.5)
			var col := im.get_pixel(x, y)
			# vignette
			col = col.darkened(clampf((v - 0.35) * 0.32, 0.0, 0.28))
			# warm lamplight toward the middle of the room
			if v < 0.6:
				col = col.lerp(Color(1.0, 0.86, 0.55), (0.6 - v) * 0.07)
			# the wall dims toward the ceiling and brightens at the wainscot
			if y < wall_h:
				var t := float(y) / wall_h
				col = col.darkened((1.0 - t) * 0.12)
				if y > wall_h - 6:
					col = col.lightened(0.04)
			im.set_pixel(x, y, col)
	# soft shadow cast by the ceiling beam
	for y in range(0, 7):
		for x in range(16, W - 16):
			K.px(im, x, y, Color(0, 0, 0, 0.16 * (1.0 - float(y) / 7.0)))


## A woven rug: a dark border, a patterned field of lozenges, a lit pile
## edge, fringe, and a soft shadow on the floor around it.
func _rug(im: Image, x: int, y: int, w: int, h: int, a: Color, b: Color, edge: Color) -> void:
	for i in 4:
		for sx in range(x - 2 + i / 2, x + 2 + w):
			K.px(im, sx, y + h + 1 + i, Color(0, 0, 0, 0.12 - i * 0.025))
	K.rect(im, x - 1, y - 1, w + 2, h + 2, edge.darkened(0.5))
	K.rect(im, x, y, w, h, edge)
	K.rect(im, x + 2, y + 2, w - 4, h - 4, edge.darkened(0.18))
	K.rect(im, x + 4, y + 4, w - 8, h - 8, a.darkened(0.12))
	K.rect(im, x + 5, y + 5, w - 10, h - 10, a)
	# border stripe
	K.rect(im, x + 3, y + 3, w - 6, 1, b.darkened(0.1))
	K.rect(im, x + 3, y + h - 4, w - 6, 1, b.darkened(0.1))
	K.rect(im, x + 3, y + 3, 1, h - 6, b.darkened(0.1))
	K.rect(im, x + w - 4, y + 3, 1, h - 6, b.darkened(0.1))
	# field: rows of lozenges, with a weave grain
	var cell := 12
	for cy in range(y + 8, y + h - 8, cell):
		for cx in range(x + 8, x + w - 8, cell):
			var mx := cx + cell / 2
			var my := cy + cell / 2
			var alt := ((cx - x) / cell + (cy - y) / cell) % 2 == 0
			for d in 5:
				var col := b if alt else a.lightened(0.18)
				K.hline(im, mx - (4 - d), my - d, (4 - d) * 2 + 1, col)
				K.hline(im, mx - (4 - d), my + d, (4 - d) * 2 + 1, col)
			K.px(im, mx, my, edge)
	for gy in range(y + 5, y + h - 5):
		for gx in range(x + 5, x + w - 5):
			if (gx + gy) % 2 == 0 and K.hash2(gx, gy, 17) < 0.35:
				var base := im.get_pixel(gx, gy)
				im.set_pixel(gx, gy, base.darkened(0.06))
	# lit pile on the top and left, shaded bottom and right
	K.hline(im, x, y, w, edge.lightened(0.25))
	K.vline(im, x, y, h, edge.lightened(0.12))
	K.hline(im, x, y + h - 1, w, edge.darkened(0.3))
	# fringe
	for fx in range(x + 1, x + w - 1, 3):
		K.rect(im, fx, y - 3, 1, 2, b.darkened(0.05))
		K.rect(im, fx, y + h + 1, 1, 2, b.darkened(0.2))


# ---------------------------------------------------------------- the store

func store_room() -> Image:
	var im := K.make(W, H)
	_floor(im, 64, H - 16, c("b58a56"), 41)
	# back wall: cream lap siding over a green wainscot with raised panels
	_lap(im, 0, 0, W, 44, c("e6d8b0"), 42)
	_wainscot(im, 0, 44, W, 20, c("4a6a4a"), 43)
	K.hline(im, 0, 43, W, c("2f4a34"))
	K.rect(im, 0, 63, W, 2, c("2a1f1a"))
	K.rect(im, 0, 62, W, 1, c("8a6440"))
	# side walls
	for sx in [0, W - 16]:
		_vboards(im, sx, 0, 16, H, c("9a6c44"), 44, 4)
		K.rect(im, sx + (15 if sx == 0 else 0), 0, 1, H, c("2a1f1a"))
	# front wall with the door gap and its windows
	_vboards(im, 0, H - 16, W, 16, c("8a6440"), 45, 4)
	K.hline(im, 0, H - 16, W, c("2a1f1a"))
	K.rect(im, 216, H - 16, 48, 16, c("6a4a30"))
	K.rect(im, 220, H - 16, 40, 16, c("3a2a20"))
	K.rect(im, 216, H - 18, 48, 2, c("f4ecd0"))
	K.rect(im, 218, H - 4, 44, 4, c("7a3a2a"))
	K.hline(im, 218, H - 4, 44, c("c0806a"))
	# two paned windows on the back wall with light falling across the floor
	_window_light(im, 44, 8, 34, 26, 70, 80, 34)
	_window_light(im, 402, 8, 34, 26, 70, 80, -34)
	# two long shelves of goods along the back wall
	for shelf_y in [22, 44]:
		K.rect(im, 96, shelf_y + 10, 288, 3, c("6e4a2e"))
		K.hline(im, 96, shelf_y + 10, 288, c("c8925e"))
		K.rect(im, 96, shelf_y + 13, 288, 1, c("3a2a1e"))
		K.rect(im, 100, shelf_y + 13, 3, 3, c("3a2a1e"))
		K.rect(im, 380, shelf_y + 13, 3, 3, c("3a2a1e"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1899
	var colors: Array[Color] = [c("c8402e"), c("d8a040"), c("5a9a4a"), c("8a6ad0"), c("3a78c0"), c("e0c060")]
	for sx in range(100, 380, 6):
		var kind := rng.randi() % 5
		var tone: Color = colors[rng.randi() % 6]
		if kind == 0:
			_stock_jar(im, sx, 24, tone)
		elif kind == 1:
			_stock_can(im, sx, 26, tone)
		elif kind == 2:
			_stock_box(im, sx, 24, 5, 8, tone)
		elif kind == 3:
			_stock_jar(im, sx, 24, tone.darkened(0.15))
		else:
			_stock_can(im, sx, 26, tone.darkened(0.1))
	for sx in range(100, 380, 6):
		var kind := rng.randi() % 6
		var tone: Color = [c("c8402e"), c("d8a040"), c("5a9a4a"), c("e8e0c0"), c("3a78c0")][rng.randi() % 5]
		if kind == 0:
			_loaf(im, sx, 47)
		elif kind == 1 or kind == 2:
			_stock_can(im, sx, 48, tone)
		elif kind == 3:
			_stock_box(im, sx, 46, 5, 8, tone)
		else:
			_stock_jar(im, sx, 46, tone)
	# hanging: dried peppers, garlic, a coil of rope, a basket, a pan
	for hx in [110, 150, 200, 260, 300, 340]:
		K.vline(im, hx, 0, 6, c("6a5a3a"))
		for k in 4:
			K.ellipse(im, hx + (k % 2) * 2 - 1, 8 + k * 2, 1.5, 2.0, [c("c8402e"), c("b02a1a"), c("d8602e"), c("c8402e")][k])
	K.ellipse(im, 100, 16, 6, 7, c("b0824c"))
	K.ellipse(im, 100, 16, 4, 5, c("8a6440"))
	# sconces, each with its own pool of light
	_sconce(im, 88, 16)
	_sconce(im, 392, 16)
	_sconce(im, 20, 20)
	_sconce(im, W - 20, 20)
	# a big patterned rug under the produce tables
	_rug(im, 132, 148, 216, 60, c("8a2f2f"), c("e8d8a8"), c("2f4a34"))
	# a little wear and a soft shadow along the walls
	K.rect(im, 16, 64, W - 32, 3, Color(0, 0, 0, 0.22))
	K.rect(im, 16, 67, W - 32, 2, Color(0, 0, 0, 0.1))
	K.rect(im, 16, 64, 3, H - 80, Color(0, 0, 0, 0.16))
	K.rect(im, W - 19, 64, 3, H - 80, Color(0, 0, 0, 0.16))
	_room_finish(im, 64)
	return im


## The shelf unit that stands on the store floor: stained uprights, three
## shelves of jars, tins and boxes, and a shadow under it.
func store_shelf() -> Image:
	var w := 50
	var h := 46
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 2.0, w / 2.0 - 2.0, 2.0, 0.3)
	_vboards(im, 1, 2, w - 2, h - 8, c("7a5232"), 401, 4)
	K.rect(im, 2, 3, w - 4, h - 10, c("5a3e28"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var colors: Array[Color] = [c("c8402e"), c("d8a040"), c("5a9a4a"), c("8a6ad0"), c("3a78c0"), c("e8e0c0")]
	for level in 3:
		var y := 4 + level * 12
		K.rect(im, 2, y + 9, w - 4, 2, c("a0764a"))
		K.hline(im, 2, y + 9, w - 4, c("d8a870"))
		K.hline(im, 2, y + 10, w - 4, c("5a3a22"))
		for x in range(4, w - 6, 6):
			var tone: Color = colors[rng.randi() % 6]
			match rng.randi() % 4:
				0:
					_stock_jar(im, x, y, tone)
				1:
					_stock_can(im, x, y + 2, tone)
				2:
					_stock_box(im, x, y + 1, 5, 8, tone)
				_:
					_stock_can(im, x + 1, y + 2, tone.darkened(0.1))
	K.rect(im, 0, h - 8, 3, 6, c("6e4a2e"))
	K.rect(im, w - 3, h - 8, 3, 6, c("6e4a2e"))
	K.outline(im)
	return im


# ---------------------------------------------------------------- the mountain shop

func shop_room() -> Image:
	var im := K.make(W, H)
	_floor(im, 80, H - 16, c("8e6440"), 51)
	# back wall: warm plaster above a dark timber wainscot
	K.rect(im, 0, 0, W, 80, c("d6c9aa"))
	for y in range(0, 60, 6):
		K.hline(im, 0, y, W, _tone(c("d6c9aa"), -0.07, -0.5))
		K.hline(im, 0, y + 1, W, _tone(c("d6c9aa"), 0.05, 0.5))
	_wainscot(im, 0, 60, W, 20, c("4a3628"), 52)
	K.hline(im, 0, 59, W, c("2a1f1a"))
	K.hline(im, 0, 60, W, c("7a5c42"))
	K.rect(im, 0, 79, W, 2, c("2a1f1a"))
	# exposed beams across the plaster
	for bx in range(0, W, 96):
		K.rect(im, bx, 0, 6, 60, c("4e3826"))
		K.vline(im, bx, 0, 60, c("7a5c42"))
		K.vline(im, bx + 5, 0, 60, c("2a1f1a"))
	K.rect(im, 0, 0, W, 5, c("4e3826"))
	K.hline(im, 0, 5, W, c("2a1f1a"))
	# the rope wall: a rack of colorful coiled ropes on pegs, left
	K.rect(im, 22, 10, 138, 46, c("5a4432"))
	K.rect(im, 24, 12, 134, 42, c("3e2c1e"))
	var rope_cols := ["c8402e", "3a78c0", "e0b030", "3a9a5a", "8a4ad0", "e07a2a", "2aa8a0", "d84a8a"]
	for i in 8:
		var rx := 30 + (i % 4) * 32
		var ry := 16 + (i / 4) * 20
		K.ellipse(im, rx + 12, ry + 8, 11, 8, c(rope_cols[i]).darkened(0.1))
		K.ellipse(im, rx + 11, ry + 7, 8, 5.4, c(rope_cols[i]).lightened(0.12))
		K.ellipse(im, rx + 12, ry + 8, 4.6, 2.8, c("3e2c1e"))
		for k in 3:
			K.ring(im, rx + 12, ry + 8, 9.0 - k * 2.0, 6.4 - k * 1.4, c(rope_cols[i]).darkened(0.22))
		K.px(im, rx + 10, ry + 4, c("ffffff"))
	# the shoe wall: rows of climbing shoes on shelves, right
	K.rect(im, 296, 10, 150, 46, c("5a4432"))
	K.rect(im, 298, 12, 146, 42, c("3e2c1e"))
	for shelf in 3:
		var sy := 22 + shelf * 12
		K.rect(im, 298, sy + 8, 146, 2, c("8a6440"))
		K.hline(im, 298, sy + 8, 146, c("c09060"))
		for sx in range(302, 440, 12):
			var col: String = ["c8402e", "3a78c0", "e0b030", "3a9a5a", "d8d8d0", "e07a2a"][int(K.hash2(sx, shelf, 9) * 6.0)]
			K.rect(im, sx, sy + 3, 9, 5, c(col))
			K.rect(im, sx + 6, sy + 1, 3, 4, c(col).darkened(0.2))
			K.hline(im, sx, sy + 7, 9, c("2a1f1a"))
			K.px(im, sx + 2, sy + 4, c("ffffff"))
	# the framed wall map and photographs
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
	for pic in [[168, 18, 14, 18], [284, 18, 12, 16]]:
		K.rect(im, pic[0], pic[1], pic[2], pic[3], c("4a3020"))
		K.rect(im, pic[0] + 1, pic[1] + 1, pic[2] - 2, pic[3] - 2, c("c8c0b0"))
		K.rect(im, pic[0] + 3, pic[1] + 6, pic[2] - 6, pic[3] - 10, c("6a7a8a"))
	# side walls, front wall, door gap
	for sx in [0, W - 16]:
		_vboards(im, sx, 0, 16, H, c("6a4a32"), 53, 4)
		K.rect(im, sx + (15 if sx == 0 else 0), 0, 1, H, c("2a1f1a"))
	_vboards(im, 0, H - 16, W, 16, c("5a4030"), 54, 4)
	K.hline(im, 0, H - 16, W, c("2a1f1a"))
	K.rect(im, 216, H - 16, 48, 16, c("4a3020"))
	K.rect(im, 220, H - 16, 40, 16, c("3a2a20"))
	K.rect(im, 216, H - 18, 48, 2, c("e8dcc0"))
	K.rect(im, 218, H - 4, 44, 4, c("3a5a8a"))
	K.hline(im, 218, H - 4, 44, c("6a8aba"))
	# windows and the light they throw
	_window_light(im, 40, 70, 30, 24, 96, 90, 30)
	# a rug down the middle, and lantern sconces
	_rug(im, 148, 170, 190, 64, c("3a5a8a"), c("e8d8a8"), c("6a3a2a"))
	_sconce(im, 168, 14)
	_sconce(im, 286, 14)
	_sconce(im, 20, 26)
	_sconce(im, W - 20, 26)
	K.rect(im, 16, 80, W - 32, 3, Color(0, 0, 0, 0.22))
	K.rect(im, 16, 83, W - 32, 2, Color(0, 0, 0, 0.1))
	K.rect(im, 16, 80, 3, H - 96, Color(0, 0, 0, 0.16))
	K.rect(im, W - 19, 80, 3, H - 96, Color(0, 0, 0, 0.16))
	_room_finish(im, 80)
	return im
