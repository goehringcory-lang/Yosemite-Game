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
