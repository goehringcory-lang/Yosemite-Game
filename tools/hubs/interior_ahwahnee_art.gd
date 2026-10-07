extends "res://tools/hubs/interior_art.gd"
## The Camp Curry Store and Mountain Shop interiors with the Ahwahnee's
## materials on the room shells: stained-timber plank floors ramp-shaded and
## dithered (darker toward the walls, warm in the middle), window frames with
## a granite sill and the Valley's pines beyond, and wrought-iron lanterns.
## The furniture keeps interior_art.gd's drawings, so layouts, sizes and
## footprints don't change. Written to assets/sprites/curry/interiors/.

const ValleyArt = preload("res://tools/hubs/valley_art.gd")

var mat := ValleyArt.new()


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


## A window with a stained frame and granite sill, the Valley's pines beyond,
## and a soft shaft of sun across the floor.
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


## A wrought-iron lantern on a bracket, glowing warm.
func _sconce(im: Image, x: int, y: int) -> void:
	K.rect(im, x - 1, y - 1, 3, 1, mat.iron[3])
	K.rect(im, x - 2, y, 5, 6, mat.iron[1])
	K.rect(im, x - 1, y + 1, 3, 4, mat.warm[6])
	K.px(im, x, y + 1, mat.warm[7])
	K.px(im, x - 1, y + 1, mat.warm[7])
	K.hline(im, x - 2, y + 6, 5, mat.iron[3])
	for r in range(2, 9):
		K.ellipse(im, x, y + 3, r, r, Color(1, 0.84, 0.46, 0.05))


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


func store_room() -> Image:
	var im := super.store_room()
	_room_finish(im, 64)
	return im


func shop_room() -> Image:
	var im := super.shop_room()
	_room_finish(im, 80)
	return im


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
