extends "res://tools/hubs/interior_ahwahnee_art.gd"
## Pixel art for the insides of the park's buildings (the Village, the
## Ahwahnee's rooms, Wawona, El Portal, Glacier Point and Tuolumne), in the
## same Ahwahnee materials as the Camp Curry Store and the Mountain Shop:
## ramp-shaded stained timber, cut granite, lamp-lit plaster, hue-shifted
## tones and a dark rim on every piece of furniture.
##
## A room is described by a spec (see ROOMS in build_interiors.gd): its size,
## its floor, its back wall and what hangs on it, its rugs and its doors. It is
## painted as one picture under everything else. Each piece of furniture is a
## sprite of its own, named after its kind and look, so rooms share them.
## Drawn at the 16px scale and upgraded to 32px by tools/art32/upgrade.py.
## Written to assets/sprites/interiors/.

const OUT := "res://assets/sprites/interiors/"


# ---------------------------------------------------------------- rooms

## Paints the room [param spec] describes: rw x rh pixels, the back wall
## [code]rows[/code] tiles deep, walls one tile thick round the rest.
func room(spec: Dictionary) -> Image:
	var size: Vector2i = spec.size
	var rw := size.x * 16
	var rh := size.y * 16
	var wall_h: int = spec.rows * 16
	var sd: int = spec.get("seed", 7)
	var im := K.make(rw, rh)
	var fl: Array = spec.floor
	floor_paint(im, 0, wall_h, rw, rh - wall_h, fl[0], c(fl[1]), sd, c(fl[2]) if fl.size() > 2 else Color.BLACK)
	var wall: Array = spec.wall
	wall_paint(im, 0, 0, rw, wall_h, wall[0], c(wall[1]), sd + 1)
	if spec.has("wainscot"):
		_wainscot(im, 0, wall_h - 18, rw, 18, c(spec.wainscot), sd + 2)
	K.hline(im, 0, wall_h - 1, rw, c("2a1f1a"))
	K.hline(im, 0, wall_h - 2, rw, _tone(c(wall[1]), -0.25, -0.6))
	if spec.get("beams", false):
		_ceiling_beams(im, rw, wall_h, c(wall[1]))
	for d: Array in spec.get("deco", []):
		deco(im, d, wall_h, sd)
	for r: Array in spec.get("rugs", []):
		_rug(im, r[0], r[1], r[2], r[3], c(r[4]), c(r[5]), c(r[6]))
	# side and front walls, and the openings in them
	var side: String = spec.get("side", "8a6440")
	for sx in [0, rw - 16]:
		if wall[0] == "granite" or wall[0] == "stone":
			mat.stone_wall(im, sx, 0, 16, rh, sd + 5, 0.55, 5, 4, false)
		elif wall[0] == "canvas":
			_canvas(im, sx, 0, 16, rh, c(side), sd + 5)
		else:
			_vboards(im, sx, 0, 16, rh, c(side), sd + 5, 4)
		K.rect(im, sx + (15 if sx == 0 else 0), wall_h, 1, rh - wall_h, c("2a1f1a"))
	_vboards(im, 0, rh - 16, rw, 16, _tone(c(side), -0.06, 0.0), sd + 6, 4)
	K.hline(im, 0, rh - 16, rw, c("2a1f1a"))
	for door: Dictionary in spec.get("doors", []):
		match door.side:
			"front":
				_front_gap(im, rw / 2, rh, c(spec.get("mat", "7a3a2a")))
			"left":
				_side_gap(im, 0, int(door.row) * 16, true)
			"right":
				_side_gap(im, rw - 16, int(door.row) * 16, false)
			"back":
				arch_door(im, int(door.x), wall_h, door.get("look", "wood"))
	# contact shadow where the floor meets the walls
	K.rect(im, 16, wall_h, rw - 32, 3, Color(0, 0, 0, 0.22))
	K.rect(im, 16, wall_h + 3, rw - 32, 2, Color(0, 0, 0, 0.1))
	K.rect(im, 16, wall_h, 3, rh - wall_h - 16, Color(0, 0, 0, 0.16))
	K.rect(im, rw - 19, wall_h, 3, rh - wall_h - 16, Color(0, 0, 0, 0.16))
	finish(im, wall_h, spec.get("light", 1.0))
	return im


func floor_paint(im: Image, x0: int, y0: int, w: int, h: int, kind: String, base: Color, sd: int, alt: Color) -> void:
	match kind:
		"planks":
			_planks(im, x0, y0, w, h, base, sd)
		"stone":
			_flagstones(im, x0, y0, w, h, base, sd)
		"tile":
			_checker(im, x0, y0, w, h, base, base.lerp(alt, 0.5), 8)
		"slate":
			_checker(im, x0, y0, w, h, base, base.darkened(0.12), 12)
			for y in range(y0, y0 + h, 12):
				K.hline(im, x0, y, w, base.darkened(0.3))
		"carpet":
			_carpet(im, x0, y0, w, h, base, alt, sd)
		"dirt":
			_dirt(im, x0, y0, w, h, base, sd)
		_:
			K.rect(im, x0, y0, w, h, base)
			for i in w * h / 40:
				var px_x := x0 + int(K.hash2(i, 1, sd) * w)
				var px_y := y0 + int(K.hash2(i, 2, sd) * h)
				K.px(im, px_x, px_y, base.darkened(0.06) if i % 2 else base.lightened(0.05))
	# a warm pool of light in the middle of the floor, darker toward the walls
	ValleyArt.shade(im, x0, y0, w, 12, base.darkened(0.6), 1.0, 0.0, 0.4)


func _planks(im: Image, x0: int, y0: int, w: int, h: int, base: Color, sd: int) -> void:
	for y in range(y0, y0 + h):
		var row := (y - y0) / 6
		var in_row := (y - y0) % 6
		for x in range(x0, x0 + w):
			var shift := (row % 3) * 23
			var n := K.hash2((x + shift) / 40, row, sd)
			var tone := _tone(base, (n - 0.5) * 0.12 + (K.hash2(x / 3, y / 2, sd + 6) - 0.5) * 0.03, 0.3)
			if in_row == 0 or (x + shift) % 40 == 0:
				tone = _tone(base, -0.2, -0.5)
			elif in_row == 1:
				tone = tone.lightened(0.06)
			elif in_row == 5:
				tone = tone.darkened(0.06)
			K.px(im, x, y, tone)
	for i in w * h / 700:
		var kx := x0 + int(K.hash2(i, 3, sd) * w)
		var ky := y0 + 2 + int(K.hash2(i, 4, sd) * (h - 4))
		K.ellipse(im, kx, ky, 1.8, 1.2, base.darkened(0.2))


## Granite flagstones, laid in rows of uneven slabs with dark grout.
func _flagstones(im: Image, x0: int, y0: int, w: int, h: int, base: Color, sd: int) -> void:
	K.rect(im, x0, y0, w, h, base.darkened(0.45))
	var y := y0
	var row := 0
	while y < y0 + h:
		var sh := 9 + int(K.hash2(row, sd, 1) * 5.0)
		var x := x0 - int(K.hash2(row, sd, 2) * 12.0)
		while x < x0 + w:
			var sw := 12 + int(K.hash2(x, row, sd) * 14.0)
			var tone := _tone(base, (K.hash2(x, row, sd + 3) - 0.5) * 0.16, 0.2)
			for yy in sh - 1:
				for xx in sw - 1:
					var col := tone
					if yy == 0 or xx == 0:
						col = tone.lightened(0.08)
					elif yy == sh - 2 or xx == sw - 2:
						col = tone.darkened(0.1)
					elif K.hash2(x + xx, y + yy, sd) > 0.93:
						col = tone.darkened(0.06)
					if x + xx >= x0 and y + yy < y0 + h:
						K.px(im, x + xx, y + yy, col)
			x += sw
		y += sh
		row += 1


func _checker(im: Image, x0: int, y0: int, w: int, h: int, a: Color, b: Color, cell: int) -> void:
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			var odd := ((x - x0) / cell + (y - y0) / cell) % 2 == 1
			var col := b if odd else a
			if (x - x0) % cell == 0 or (y - y0) % cell == 0:
				col = col.darkened(0.08)
			K.px(im, x, y, col)


## Wall-to-wall carpet with a woven border pattern.
func _carpet(im: Image, x0: int, y0: int, w: int, h: int, base: Color, accent: Color, sd: int) -> void:
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			var n := K.hash2(x / 2, y / 2, sd)
			var col := base.darkened(0.05) if n > 0.6 else base
			if (x + y) % 2 == 0 and n < 0.15:
				col = base.lightened(0.05)
			K.px(im, x, y, col)
	if accent != Color.BLACK:
		for x in range(x0 + 24, x0 + w - 24, 8):
			for k in 3:
				K.hline(im, x - k, y0 + 8 + k, 1 + k * 2, accent)
				K.hline(im, x - k, y0 + h - 26 - k, 1 + k * 2, accent)


func _dirt(im: Image, x0: int, y0: int, w: int, h: int, base: Color, sd: int) -> void:
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			var col := base
			var n := K.hash2(x, y, sd)
			if n > 0.93:
				col = _tone(base, -0.08, -0.3)
			elif n < 0.05:
				col = _tone(base, 0.06, 0.3)
			K.px(im, x, y, col)


## The back wall: [param kind] is logs, plaster, lap, boards, granite, stone,
## stucco or canvas.
func wall_paint(im: Image, x: int, y: int, w: int, h: int, kind: String, base: Color, sd: int) -> void:
	match kind:
		"logs":
			for row in range(0, h, 7):
				var tone := _tone(base, (K.hash2(row, sd, 1) - 0.5) * 0.08, 0.3)
				for k in 7:
					var t: float = [0.12, 0.08, 0.02, -0.04, -0.1, -0.18, -0.3][k]
					K.hline(im, x, y + row + k, w, _tone(tone, t, 0.4 if t > 0 else -0.4))
				K.hline(im, x, y + row + 6, w, c("c8b890").darkened(0.3))
				for i in w / 50:
					var gx := x + int(K.hash2(i, row, sd) * w)
					K.hline(im, gx, y + row + 3, 6, _tone(tone, -0.12, -0.3))
				for jx in range(int(K.hash2(row, sd, 3) * 90.0), w, 90):
					K.ellipse(im, x + jx, y + row + 3, 3.0, 3.0, _tone(tone, 0.08, 0.5))
					K.ring(im, x + jx, y + row + 3, 2.0, 2.0, _tone(tone, -0.1, -0.3))
		"plaster", "stucco":
			K.rect(im, x, y, w, h, base)
			for yy in h:
				for xx in w:
					var n := K.hash2(x + xx, y + yy, sd)
					if n > 0.9:
						K.px(im, x + xx, y + yy, _tone(base, -0.05, -0.3))
					elif n < 0.06 and kind == "stucco":
						K.px(im, x + xx, y + yy, _tone(base, 0.05, 0.4))
		"lap":
			_lap(im, x, y, w, h, base, sd)
		"boards":
			_vboards(im, x, y, w, h, base, sd, 5)
		"granite", "stone":
			mat.stone_wall(im, x, y, w, h, sd, 0.55 if kind == "granite" else 0.42, 6, 5, false)
		"canvas":
			_canvas(im, x, y, w, h, base, sd)
		_:
			K.rect(im, x, y, w, h, base)


## Canvas stretched over a frame: vertical seams, sag and a pole every so often.
func _canvas(im: Image, x: int, y: int, w: int, h: int, base: Color, sd: int) -> void:
	K.rect(im, x, y, w, h, base)
	for yy in h:
		for xx in w:
			if K.hash2(x + xx, y + yy, sd) > 0.92:
				K.px(im, x + xx, y + yy, _tone(base, -0.05, -0.3))
	for sx in range(x + 24, x + w, 48):
		K.vline(im, sx, y, h, _tone(base, -0.12, -0.4))
		K.vline(im, sx + 1, y, h, _tone(base, 0.05, 0.3))
	for px_x in range(x + 8, x + w, 96):
		K.rect(im, px_x, y, 3, h, c("6a4a30"))
		K.vline(im, px_x, y, h, c("9a7448"))


## Rafters crossing under the ceiling line: a beam along the top and posts
## down the wall.
func _ceiling_beams(im: Image, rw: int, wall_h: int, base: Color) -> void:
	K.rect(im, 0, 0, rw, 5, mat.timber[1])
	K.hline(im, 0, 0, rw, mat.timber[3])
	K.hline(im, 0, 5, rw, c("2a1f1a"))
	for bx in range(30, rw - 20, 96):
		K.rect(im, bx, 0, 5, wall_h - 18, mat.timber[2])
		K.vline(im, bx, 0, wall_h - 18, mat.timber[4])
		K.vline(im, bx + 4, 0, wall_h - 18, mat.timber[0])


## The doorway in the front wall, with its threshold and a mat.
func _front_gap(im: Image, cx: int, rh: int, mat_col: Color) -> void:
	K.rect(im, cx - 24, rh - 16, 48, 16, c("4a3020"))
	K.rect(im, cx - 20, rh - 16, 40, 16, c("2a1f18"))
	K.rect(im, cx - 24, rh - 18, 48, 2, c("e8dcc0"))
	K.rect(im, cx - 22, rh - 4, 44, 4, mat_col)
	K.hline(im, cx - 22, rh - 4, 44, mat_col.lightened(0.3))


## An opening two tiles tall in a side wall, onto the next room.
func _side_gap(im: Image, x: int, y: int, left: bool) -> void:
	K.rect(im, x, y - 4, 16, 36, c("4a3020"))
	K.rect(im, x + (0 if left else 4), y, 12, 32, c("1e1712"))
	K.rect(im, x + (12 if left else 0), y, 4, 32, Color(1.0, 0.85, 0.55, 0.18))
	K.hline(im, x, y - 4, 16, c("8a6440"))


## A door in the back wall onto another room: an arch of stained timber or
## granite, panelled doors or an elevator's brass gate.
func arch_door(im: Image, cx: int, wall_h: int, look: String) -> void:
	var dw := 24
	var dh := 34
	var x := cx - dw / 2
	var y := wall_h - dh
	if look == "stone":
		mat.stone_wall(im, x - 6, y - 8, dw + 12, dh + 8, cx, 0.62, 4, 3, false)
	else:
		K.rect(im, x - 4, y - 6, dw + 8, dh + 6, mat.timber[1])
		K.hline(im, x - 4, y - 6, dw + 8, mat.timber[4])
	K.ellipse(im, cx, y + 4, dw / 2.0, 6.0, c("1e1712"))
	K.rect(im, x, y + 4, dw, dh - 4, c("1e1712"))
	match look:
		"elevator":
			K.rect(im, x + 1, y + 4, dw - 2, dh - 5, c("8a6a2a"))
			for gx in range(x + 2, x + dw - 2, 3):
				K.vline(im, gx, y + 5, dh - 7, c("e0b850"))
			for gy in [y + 10, y + 20]:
				K.hline(im, x + 1, gy, dw - 2, c("c89a3a"))
			K.ellipse(im, cx, y - 2, 4.0, 2.0, c("e0b850"))
		"open":
			ValleyArt.shade(im, x, y + 4, dw, dh - 4, c("ffd890"), 0.4, 0.0, 0.25)
		_:
			for k in 2:
				var px_x := x + 1 + k * (dw / 2)
				K.rect(im, px_x, y + 4, dw / 2 - 1, dh - 5, mat.timber[3 - k])
				K.rect(im, px_x + 2, y + 8, dw / 2 - 5, 10, mat.timber[2 - k])
				K.rect(im, px_x + 2, y + 21, dw / 2 - 5, 9, mat.timber[2 - k])
			K.px(im, cx - 2, y + 20, c("e0b850"))
			K.px(im, cx + 1, y + 20, c("e0b850"))
	K.rect(im, x - 2, wall_h - 2, dw + 4, 2, mat.granite[5])


## Lamplight over the whole room: darker corners and a wall that dims toward
## the ceiling, both in ordered dither so the palette doesn't band them.
## [param light] < 1 makes a dimmer room.
func finish(im: Image, wall_h: int, light: float) -> void:
	var rw := im.get_width()
	var rh := im.get_height()
	for y in rh:
		for x in rw:
			var dx := (x - rw / 2.0) / (rw / 2.0)
			var dy := (y - rh * 0.55) / (rh * 0.55)
			var v := clampf(dx * dx * 0.55 + dy * dy * 0.45, 0.0, 1.5)
			var cover := clampf((v - 0.45) * 0.9 + (1.0 - light) * 1.2, 0.0, 0.9)
			if y < wall_h:
				cover = maxf(cover, (1.0 - float(y) / wall_h) * 0.5)
			var b := (ValleyArt.BAYER[(y & 3) * 4 + (x & 3)] + 0.5) / 16.0
			if cover > b:
				var col := im.get_pixel(x, y)
				im.set_pixel(x, y, _tone(col, -0.07, -0.4))
	for y in 6:
		for x in range(16, rw - 16):
			K.px(im, x, y, Color(0, 0, 0, 0.14 * (1.0 - y / 6.0)))


# ---------------------------------------------------------------- wall decor

## One thing on the back wall, by its kind (the first entry of [param d]).
func deco(im: Image, d: Array, wall_h: int, sd: int) -> void:
	match d[0]:
		"window":
			_window_light(im, d[1], d[2], d[3], d[4], wall_h + 2, d[5] if d.size() > 5 else 60, d[6] if d.size() > 6 else 0)
		"tall_window":
			tall_window(im, d[1], d[2], wall_h, d[3] if d.size() > 3 else "valley")
		"frame":
			frame(im, d[1], d[2], d[3], d[4], d[5], sd + d[1])
		"stained":
			stained_glass(im, d[1], d[2], d[3], d[4], sd + d[1])
		"lancet":
			lancet(im, d[1], d[2], d[3], d[4])
		"band":
			pattern_band(im, d[1], d[2], im.get_width(), d[3] if d.size() > 3 else ["8a2f2f", "e8d8a8", "2f4a34", "c89a3a"])
		"mural":
			mural(im, d[1], d[2], d[3], d[4])
		"sign":
			_wall_sign(im, d[1], d[2], d[3], c(d[4]) if d.size() > 4 else c("4a3020"))
		"sconce":
			_sconce(im, d[1], d[2])
		"clock":
			_clock(im, d[1], d[2])
		"shelf":
			_wall_shelf(im, d[1], d[2], d[3], d[4], sd + d[1])
		"pegs":
			_pegs(im, d[1], d[2], d[3], d[4])
		"pboxes":
			_po_boxes(im, d[1], d[2], d[3], d[4])
		"bars":
			_bars(im, d[1], d[2], d[3], wall_h)
		"cross":
			K.rect(im, d[1] - 1, d[2], 3, 16, c("c8a050"))
			K.rect(im, d[1] - 5, d[2] + 4, 11, 3, c("c8a050"))
			K.vline(im, d[1] - 1, d[2], 16, c("f0d080"))
		"flag":
			_flag(im, d[1], d[2])
		"baskets":
			_basket_shelf(im, d[1], d[2], d[3], sd + d[1])
		"poster":
			frame(im, d[1], d[2], d[3], d[4], "poster", sd + d[1])
		"board":
			_notice_board(im, d[1], d[2], d[3], d[4], sd + d[1])
		"antlers":
			_antlers(im, d[1], d[2])
		"rack":
			_tool_rack(im, d[1], d[2], d[3])


## A floor-to-ceiling window looking out on [param view]: the Valley's walls
## (valley), Half Dome and the high country (dome), forest (forest) or a
## meadow (meadow), with mullions and a shaft of light on the floor.
func tall_window(im: Image, x: int, w: int, wall_h: int, view: String) -> void:
	var y := 6
	var h := wall_h - 8
	K.rect(im, x - 3, y - 3, w + 6, h + 4, mat.timber[0])
	for yy in h:
		for xx in w:
			var v := float(yy) / h
			var col: Color = mat.sky[clampi(roundi((1.0 - v * 0.8) * 4.0 + (K.hash2(xx, yy, 5) - 0.5) * 0.7), 0, 4)]
			var gx := float(x + xx)
			var ridge := 0.0
			match view:
				"dome":
					var dome := 1.0 - pow((gx - x - w * 0.6) / (w * 0.32), 2.0)
					ridge = 0.55 - maxf(dome, 0.0) * 0.4
				"valley":
					ridge = 0.38 + 0.12 * sin(gx * 0.05) + 0.06 * sin(gx * 0.17)
				"meadow":
					ridge = 0.7 + 0.06 * sin(gx * 0.08)
				_:
					ridge = 0.5
			if v > ridge and view != "forest":
				col = mat.granite[clampi(5 - int((v - ridge) * 8.0) + (1 if int(gx) % 7 < 3 else 0), 2, 6)]
			if v > 0.72:
				col = mat.leaf[clampi(1 + int(K.hash2(int(gx) / 3, yy / 4, 9) * 3.0), 0, 5)]
				if view == "meadow" and v > 0.85:
					col = c("a8b860") if K.hash2(int(gx), yy, 3) > 0.3 else c("c8c070")
			if view == "forest" and K.hash2(int(gx) / 6, 1, 4) > 0.4 and v > 0.2 + K.hash2(int(gx) / 6, 2, 4) * 0.4:
				col = mat.leaf[clampi(int(K.hash2(int(gx), yy / 3, 6) * 3.0), 0, 5)]
			K.px(im, x + xx, y + yy, col)
	for mx in range(x, x + w + 1, maxi(8, w / 3)):
		K.vline(im, mini(mx, x + w - 1), y, h, mat.timber[1])
	for my in range(y + 10, y + h, 16):
		K.hline(im, x, my, w, mat.timber[1])
	K.rect(im, x - 3, wall_h - 3, w + 6, 2, mat.granite[5])
	for yy in 44:
		var t := yy / 44.0
		for xx in w:
			K.px(im, x + xx + int(t * 16.0), wall_h + yy, Color(1, 0.94, 0.72, 0.16 * (1.0 - t)))


## A framed picture: a landscape painting (painting), a black-and-white
## photograph (photo), a map (map), a portrait (portrait), a menu (menu), a
## wanted poster (wanted) or a printed poster (poster).
func frame(im: Image, x: int, y: int, w: int, h: int, kind: String, sd: int) -> void:
	var frame_col := c("c89a3a") if kind == "painting" or kind == "portrait" else c("3a2a1e")
	if kind == "wanted" or kind == "poster" or kind == "menu":
		frame_col = c("2a1f1a")
	K.rect(im, x - 2, y - 2, w + 4, h + 4, frame_col)
	K.hline(im, x - 2, y - 2, w + 4, frame_col.lightened(0.3))
	K.rect(im, x + w + 2, y, 1, h + 3, Color(0, 0, 0, 0.25))
	match kind:
		"painting", "photo":
			var mono := kind == "photo"
			for yy in h:
				for xx in w:
					var v := float(yy) / h
					var ridge := 0.45 + 0.18 * sin((xx + sd) * 0.21) * sin((xx + sd) * 0.07)
					var col: Color
					if v < ridge:
						col = c("a8c4d8").lerp(c("f0d8a8"), v)
					elif v < 0.78:
						col = mat.granite[clampi(5 - int((v - ridge) * 10.0), 2, 6)]
					else:
						col = mat.leaf[clampi(2 + int(K.hash2(xx / 2, yy, sd) * 2.0), 0, 5)]
					if mono:
						var l := col.get_luminance()
						col = Color(l, l, l * 0.96)
					K.px(im, x + xx, y + yy, col)
			if K.hash2(sd, 1, 2) > 0.5 and w > 10:
				# a waterfall down the cliff
				K.vline(im, x + w / 3, y + int(h * 0.4), int(h * 0.38), c("f4f4f0"))
		"portrait":
			K.rect(im, x, y, w, h, c("4a3a2a"))
			K.ellipse(im, x + w / 2.0, y + h * 0.4, w * 0.22, h * 0.2, c("d8b090"))
			K.rect(im, x + w / 4, y + int(h * 0.62), w / 2, h - int(h * 0.62), c("2a2a3a"))
		"map":
			K.rect(im, x, y, w, h, c("e6d8a8"))
			for i in 8:
				var px_x := x + int(K.hash2(i, sd, 1) * w)
				var py := y + int(K.hash2(i, sd, 2) * h)
				K.ellipse(im, px_x, py, 3.0 + K.hash2(i, sd, 3) * 4.0, 2.0 + K.hash2(i, sd, 4) * 3.0, c("b8c890"))
			for xx in w:
				K.px(im, x + xx, y + h / 2 + int(sin(xx * 0.3) * 3.0), c("5a8ac0"))
			K.px(im, x + w / 2, y + h / 3, c("c8402e"))
		"menu", "notice":
			K.rect(im, x, y, w, h, c("2e3a30") if kind == "menu" else c("f0e6c8"))
			for ly in range(y + 3, y + h - 2, 3):
				K.hline(im, x + 2, ly, int(w * (0.5 + K.hash2(ly, sd, 1) * 0.4)), c("e8e0c8") if kind == "menu" else c("6a5a4a"))
		"wanted":
			K.rect(im, x, y, w, h, c("e8d8a8"))
			K.text(im, x + 1, y + 1, "WANTED", c("3a2a1e"))
			K.ellipse(im, x + w / 2.0, y + h * 0.55, w * 0.2, h * 0.18, c("6a5a4a"))
		"poster":
			var hue := K.hash2(sd, 3, 3)
			K.rect(im, x, y, w, h, Color.from_hsv(hue, 0.35, 0.85))
			K.rect(im, x + 2, y + 2, w - 4, h / 2, Color.from_hsv(fposmod(hue + 0.5, 1.0), 0.4, 0.6))
			K.hline(im, x + 2, y + h - 4, w - 4, c("2a1f1a"))


## Stained glass in the Ahwahnee's manner: a grid of small panes in reds,
## golds, greens and blues set in lead, a stepped pattern in the middle.
func stained_glass(im: Image, x: int, y: int, w: int, h: int, sd: int) -> void:
	var cols := ["c8402e", "e0a040", "3a8a5a", "3a68a8", "e8d8a8", "8a2f2f"]
	K.rect(im, x - 2, y - 2, w + 4, h + 4, mat.timber[0])
	for yy in range(0, h, 4):
		for xx in range(0, w, 4):
			var dx := absi(xx + 2 - w / 2)
			var dy := absi(yy + 2 - h / 2)
			var step := (dx + dy) / 6
			var col := c(cols[(step + int(K.hash2(xx / 8, yy / 8, sd) * 1.5)) % cols.size()])
			K.rect(im, x + xx, y + yy, 3, 3, col.lightened(0.1))
			K.px(im, x + xx, y + yy, col.lightened(0.3))
	for yy in range(0, h, 4):
		K.hline(im, x, y + yy + 3, w, c("2a2420"))
	for xx in range(0, w, 4):
		K.vline(im, x + xx + 3, y, h, c("2a2420"))
	for r in range(2, 12):
		K.ellipse(im, x + w / 2.0, y + h + 12, w * 0.5 + r, 6.0, Color(1, 0.8, 0.5, 0.012))


## A pointed (lancet) window of colored glass, as in the Chapel.
func lancet(im: Image, x: int, y: int, w: int, h: int) -> void:
	K.rect(im, x - 2, y + w / 2, w + 4, h - w / 2 + 2, mat.timber[0])
	K.ellipse(im, x + w / 2.0, y + w / 2.0 + 1, w / 2.0 + 2, w / 2.0 + 2, mat.timber[0])
	for yy in h:
		for xx in w:
			var top := absf(xx + 0.5 - w / 2.0) * 1.2
			if yy < w / 2 and yy < w / 2 - (w / 2.0 - top) * 0.9:
				continue
			var col := c(["3a68a8", "5a8ac8", "c8402e", "e0a040"][(xx / 2 + yy / 3) % 4]) if yy % 6 else c("2a2420")
			K.px(im, x + xx, y + yy, col)
	K.vline(im, x + w / 2, y + 2, h - 2, c("2a2420"))


## A band of painted pattern across the wall: stepped diamonds in the
## Ahwahnee's colors (Native-inspired, flagged for tribal review with the
## hotel's painted beams).
func pattern_band(im: Image, y: int, h: int, w: int, cols: Array) -> void:
	K.rect(im, 0, y, w, h, c(cols[0]))
	K.hline(im, 0, y, w, c(cols[1]))
	K.hline(im, 0, y + h - 1, w, c(cols[1]))
	var mid := y + h / 2
	for cx in range(8, w, 16):
		for k in h / 2 - 1:
			K.hline(im, cx - (h / 2 - 2 - k), mid - k, (h / 2 - 2 - k) * 2 + 1, c(cols[2 + (k % 2)]))
			K.hline(im, cx - (h / 2 - 2 - k), mid + k, (h / 2 - 2 - k) * 2 + 1, c(cols[2 + (k % 2)]))


## A painted mural of the Valley's walls and forests, in soft flat colors.
func mural(im: Image, x: int, y: int, w: int, h: int) -> void:
	K.rect(im, x - 3, y - 3, w + 6, h + 6, mat.timber[1])
	for yy in h:
		for xx in w:
			var v := float(yy) / h
			var col := c("c8d8d0").lerp(c("e8d8b0"), v)
			var r1 := 0.35 + 0.2 * sin(xx * 0.04 + 1.0)
			var r2 := 0.55 + 0.1 * sin(xx * 0.09)
			if v > r1:
				col = c("9a98a0")
			if v > r2:
				col = c("6a8a6a")
			if v > 0.8:
				col = c("4a6a4a") if (xx / 4) % 2 else c("587a52")
			if v > r1 and v < r2 and (xx + yy) % 9 == 0:
				col = c("b8b6bc")
			K.px(im, x + xx, y + yy, col)
	for tx in range(x + 4, x + w, 11):
		var th := 10 + int(K.hash2(tx, 1, 3) * 10.0)
		for k in th:
			K.hline(im, tx - k / 4, y + h - th + k, k / 2 + 1, c("2e4a34"))


func _wall_sign(im: Image, cx: int, y: int, text_value: String, board: Color) -> void:
	var tw := K.text_width(text_value) + 8
	K.rect(im, cx - tw / 2, y, tw, 9, board)
	K.hline(im, cx - tw / 2, y, tw, board.lightened(0.25))
	K.hline(im, cx - tw / 2, y + 8, tw, board.darkened(0.4))
	K.text_centered(im, cx - tw / 2, tw, y + 2, text_value, c("f0e2bc"), board.darkened(0.5))


func _clock(im: Image, x: int, y: int) -> void:
	K.ellipse(im, x, y, 5.0, 5.0, mat.timber[1])
	K.ellipse(im, x, y, 4.0, 4.0, c("f0e8d0"))
	K.vline(im, x, y - 3, 3, c("2a1f1a"))
	K.hline(im, x, y, 3, c("2a1f1a"))


## A shelf on the wall stocked with [param goods]: jars and tins (goods),
## books (books), pots and plates (crockery) or rocks and cones (specimens).
func _wall_shelf(im: Image, x: int, y: int, w: int, goods: String, sd: int) -> void:
	K.rect(im, x, y + 9, w, 3, c("6e4a2e"))
	K.hline(im, x, y + 9, w, c("c8925e"))
	K.rect(im, x + 2, y + 12, 2, 3, c("3a2a1e"))
	K.rect(im, x + w - 4, y + 12, 2, 3, c("3a2a1e"))
	var colors := [c("c8402e"), c("d8a040"), c("5a9a4a"), c("8a6ad0"), c("3a78c0"), c("e8e0c0")]
	var gx := x + 2
	var i := 0
	while gx < x + w - 5:
		var tone: Color = colors[int(K.hash2(i, sd, 1) * 6.0) % 6]
		match goods:
			"books":
				var bh := 6 + int(K.hash2(i, sd, 2) * 3.0)
				K.rect(im, gx, y + 9 - bh, 2, bh, tone.darkened(0.15))
				K.vline(im, gx, y + 9 - bh, bh, tone.lightened(0.15))
				gx += 2
			"crockery":
				K.ellipse(im, gx + 2, y + 6, 2.5, 3.0, c("e8e4d8") if i % 2 else c("5a7aa8"))
				gx += 5
			"specimens":
				K.ellipse(im, gx + 2, y + 7, 2.5, 2.0, mat.granite[3 + i % 3] if i % 3 else c("8a5a2a"))
				gx += 6
			_:
				if i % 3 == 0:
					_stock_jar(im, gx, y + 1, tone)
				elif i % 3 == 1:
					_stock_can(im, gx, y + 3, tone)
				else:
					_stock_box(im, gx, y + 1, 5, 8, tone)
				gx += 6
		i += 1


## Tools hanging on pegs: tongs and hammers (smithy), ropes (ropes), pans
## (kitchen) or coats and hats (coats).
func _pegs(im: Image, x: int, y: int, w: int, kind: String) -> void:
	K.rect(im, x, y, w, 3, mat.timber[2])
	K.hline(im, x, y, w, mat.timber[4])
	var i := 0
	for px_x in range(x + 5, x + w - 4, 10):
		K.px(im, px_x, y + 3, c("2a2a2a"))
		match kind:
			"smithy":
				if i % 2 == 0:
					K.vline(im, px_x, y + 4, 12, mat.iron[2])
					K.vline(im, px_x + 2, y + 4, 12, mat.iron[2])
					K.px(im, px_x + 1, y + 4, mat.iron[3])
				else:
					K.vline(im, px_x, y + 4, 10, mat.timber[3])
					K.rect(im, px_x - 2, y + 13, 5, 3, mat.iron[2])
			"ropes":
				K.ring(im, px_x, y + 9, 4.0, 5.0, c(["c8402e", "3a78c0", "e0b030"][i % 3]))
			"kitchen":
				K.ellipse(im, px_x, y + 9, 4.0, 4.0, mat.iron[1 + i % 2])
				K.vline(im, px_x, y + 3, 3, mat.iron[2])
			"coats":
				K.rect(im, px_x - 3, y + 4, 7, 14, c(["5a3a2a", "3a4a6a", "6a5a3a"][i % 3]))
				K.ellipse(im, px_x, y + 3, 4.0, 2.0, c("4a3020"))
		i += 1


func _po_boxes(im: Image, x: int, y: int, w: int, h: int) -> void:
	K.rect(im, x - 2, y - 2, w + 4, h + 4, mat.timber[1])
	for by in range(y, y + h - 5, 7):
		for bx in range(x, x + w - 5, 7):
			K.rect(im, bx, by, 6, 6, c("b08840"))
			K.rect(im, bx + 1, by + 1, 4, 3, c("4a3a2a"))
			K.px(im, bx + 4, by + 4, c("f0d070"))
			K.hline(im, bx, by, 6, c("e0c070"))


## Iron bars across the back of a cell, from the floor to the ceiling.
func _bars(im: Image, x: int, w: int, y_top: int, wall_h: int) -> void:
	K.rect(im, x, y_top, w, wall_h - y_top, c("1e1a18"))
	K.rect(im, x + 2, y_top + 2, w - 4, wall_h - y_top - 2, c("3a3028"))
	for bx in range(x, x + w, 4):
		K.vline(im, bx, y_top, wall_h - y_top, mat.iron[3])
		K.vline(im, bx + 1, y_top, wall_h - y_top, mat.iron[1])
	K.hline(im, x, y_top + 4, w, mat.iron[2])


func _flag(im: Image, x: int, y: int) -> void:
	K.vline(im, x, y, 30, c("c8a050"))
	K.rect(im, x + 1, y + 1, 18, 11, c("e8e4dc"))
	for k in range(0, 11, 2):
		K.hline(im, x + 1, y + 1 + k, 18, c("b83a3a"))
	K.rect(im, x + 1, y + 1, 8, 6, c("3a4a8a"))


## Woven baskets on a shelf (the Museum's Miwok and Paiute collection).
func _basket_shelf(im: Image, x: int, y: int, w: int, sd: int) -> void:
	K.rect(im, x, y + 14, w, 3, c("6e4a2e"))
	K.hline(im, x, y + 14, w, c("c8925e"))
	var bx := x + 3
	var i := 0
	while bx < x + w - 10:
		var bw := 8 + int(K.hash2(i, sd, 1) * 6.0)
		var bh := 7 + int(K.hash2(i, sd, 2) * 6.0)
		for yy in bh:
			var t := float(yy) / bh
			var half := bw / 2.0 * (0.7 + 0.3 * sin(t * PI))
			for xx in range(-int(half), int(half) + 1):
				var band := (yy / 2) % 3
				var col := c("c8a060") if band != 1 else c("6a3a20")
				if band == 1 and (xx + yy) % 4 == 0:
					col = c("2a1a10")
				K.px(im, x + int(bx - x + bw / 2.0) + xx, y + 14 - bh + yy, col)
		bx += bw + 3
		i += 1


func _notice_board(im: Image, x: int, y: int, w: int, h: int, sd: int) -> void:
	K.rect(im, x - 2, y - 2, w + 4, h + 4, mat.timber[1])
	K.rect(im, x, y, w, h, c("b08a5a"))
	for i in w * h / 90:
		var nx := x + 1 + int(K.hash2(i, sd, 1) * (w - 9))
		var ny := y + 1 + int(K.hash2(i, sd, 2) * (h - 8))
		K.rect(im, nx, ny, 8, 7, [c("f0e8d0"), c("e8d070"), c("c8e0f0"), c("f0c8c0")][i % 4])
		K.px(im, nx + 3, ny, c("c8402e"))
		K.hline(im, nx + 1, ny + 3, 5, c("8a8070"))


func _antlers(im: Image, x: int, y: int) -> void:
	K.rect(im, x - 4, y, 9, 6, mat.timber[2])
	for side in [-1, 1]:
		for k in 8:
			K.px(im, x + side * (2 + k), y - k / 2, c("e8dcc0"))
		K.px(im, x + side * 5, y - 4, c("e8dcc0"))
		K.px(im, x + side * 8, y - 6, c("e8dcc0"))


## A rack of trail and park goods (gift shops): T-shirts in a row.
func _tool_rack(im: Image, x: int, y: int, w: int) -> void:
	K.hline(im, x, y, w, mat.iron[2])
	for i in range(0, w - 8, 9):
		var col := c(["3a6a4a", "c8a050", "3a5a8a", "a84a3a", "e8e0d0"][(i / 9) % 5])
		K.rect(im, x + i + 1, y + 2, 8, 10, col)
		K.rect(im, x + i, y + 2, 10, 3, col)
		K.px(im, x + i + 4, y + 1, mat.iron[3])


# ---------------------------------------------------------------- furniture

## The sprite for one piece of furniture: [param kind] picks the drawing and
## [param o] its look. Every piece is lit from the upper left and outlined.
func prop(kind: String, o: Dictionary) -> Image:
	var im: Image = call("_p_" + kind, o)
	if frames_of(kind) == 1:
		_light_prop(im)
	return im


## How many animation frames sit side by side in a kind's sheet.
static func frames_of(kind: String) -> int:
	return 2 if kind in ["stove", "forge", "hearth"] else 1


## The file a piece is saved as: its kind, and its look if it has one.
static func prop_file(kind: String, o: Dictionary) -> String:
	return kind + ("_" + str(o.look) if o.has("look") else "")


func _wood(o: Dictionary) -> Color:
	return c(o.get("wood", "7a5232"))


func _p_counter(o: Dictionary) -> Image:
	var w: int = o.get("w", 96)
	var h := 30
	var im := K.make(w, h)
	var wood := _wood(o)
	K.shadow(im, w / 2.0, h - 2.0, w / 2.0 - 2.0, 2.0, 0.3)
	_vboards(im, 1, 10, w - 2, h - 12, wood, w, 5)
	for px_x in range(6, w - 12, 24):
		K.rect(im, px_x, 13, 18, h - 18, _tone(wood, -0.08, -0.4))
		K.hline(im, px_x, 13, 18, _tone(wood, 0.1, 0.5))
	var top := c(o.get("top", "a0764a"))
	K.rect(im, 0, 6, w, 5, top)
	K.hline(im, 0, 6, w, top.lightened(0.25))
	K.hline(im, 0, 10, w, top.darkened(0.35))
	if o.get("register", false):
		K.rect(im, w - 22, 0, 12, 7, c("8a6a3a"))
		K.rect(im, w - 21, 1, 10, 3, c("c8a050"))
		K.rect(im, w - 20, 0, 8, 1, c("f0d070"))
	if o.get("bell", false):
		K.ellipse(im, 12, 5, 2.5, 2.0, c("e0b850"))
		K.px(im, 12, 2, c("f0d070"))
	if o.get("books", false):
		K.rect(im, w / 2 - 10, 2, 16, 5, c("4a3a2a"))
		K.rect(im, w / 2 - 9, 3, 14, 3, c("f0e8d0"))
	for item: String in o.get("items", []):
		var ix := 10 + int(K.hash2(item.length(), w, 3) * (w - 40))
		match item:
			"pastries":
				for k in 4:
					K.ellipse(im, ix + k * 5, 4, 2.5, 1.8, c("d8a050").darkened(k * 0.05))
			"jars":
				for k in 3:
					_stock_jar(im, ix + k * 5, -1, c(["c8402e", "e0a040", "5a9a4a"][k]))
			"cups":
				for k in 3:
					K.rect(im, ix + k * 4, 3, 3, 3, c("e8e4d8"))
			"scale":
				K.rect(im, ix, 2, 10, 4, c("c8a050"))
				K.rect(im, ix + 3, 0, 4, 2, c("8a6a2a"))
			"lamp":
				K.rect(im, ix, 0, 3, 6, c("c8a050"))
				K.ellipse(im, ix + 1, 0, 3.0, 2.0, c("ffd890"))
	K.outline(im)
	return im


func _p_bookcase(o: Dictionary) -> Image:
	var w: int = o.get("w", 34)
	var h: int = o.get("h", 48)
	var im := K.make(w, h)
	var wood := _wood(o)
	K.shadow(im, w / 2.0, h - 2.0, w / 2.0 - 1.0, 2.0, 0.3)
	K.rect(im, 0, 0, w, h - 2, wood)
	K.rect(im, 2, 2, w - 4, h - 6, wood.darkened(0.35))
	for row in range(2, h - 6, 11):
		K.rect(im, 2, row + 9, w - 4, 2, wood.lightened(0.1))
		var bx := 3
		var i := row
		while bx < w - 4:
			var bh := 6 + int(K.hash2(bx, i, w) * 3.0)
			var col := Color.from_hsv(K.hash2(bx, row, 3), 0.45, 0.55 + K.hash2(bx, row, 4) * 0.2)
			if o.get("look", "") == "curios" and bx % 9 < 3:
				K.ellipse(im, bx + 2, row + 6, 2.0, 2.5, mat.granite[4])
				bx += 5
				continue
			K.rect(im, bx, row + 9 - bh, 2, bh, col)
			K.vline(im, bx, row + 9 - bh, bh, col.lightened(0.2))
			bx += 2 + (1 if K.hash2(bx, row, 5) > 0.8 else 0)
	K.hline(im, 0, 0, w, wood.lightened(0.25))
	K.outline(im)
	return im


func _p_table_round(o: Dictionary) -> Image:
	var w: int = o.get("w", 30)
	var im := K.make(w, 22)
	var cloth := c(o.get("cloth", "e8e0c8"))
	K.shadow(im, w / 2.0, 20.0, w / 2.0 - 2.0, 2.0, 0.3)
	K.rect(im, w / 2 - 2, 10, 4, 10, _wood(o))
	K.ellipse(im, w / 2.0, 8.0, w / 2.0 - 1.0, 5.0, cloth.darkened(0.2))
	K.ellipse(im, w / 2.0, 7.0, w / 2.0 - 1.0, 5.0, cloth)
	K.rect(im, 2, 7, w - 4, 6, cloth.darkened(0.12))
	K.ellipse(im, w / 2.0, 6.0, w / 2.0 - 3.0, 3.5, cloth.lightened(0.1))
	_table_items(im, w, 5, o)
	K.outline(im)
	return im


func _table_items(im: Image, w: int, y: int, o: Dictionary) -> void:
	match o.get("set", ""):
		"dinner":
			for px_x in range(6, w - 4, 10):
				K.ellipse(im, px_x, y, 2.5, 1.5, c("f8f4ec"))
				K.px(im, px_x - 3, y, c("c8c8c0"))
			K.rect(im, w / 2, y - 6, 1, 5, c("f0e8d0"))
			K.px(im, w / 2, y - 7, c("ffd060"))
		"tea":
			K.rect(im, w / 2 - 2, y - 3, 5, 4, c("e8e4d8"))
			K.px(im, w / 2 + 3, y - 2, c("e8e4d8"))
			K.ellipse(im, w / 2 - 7, y + 1, 2.0, 1.0, c("e8e4d8"))
		"vase":
			K.rect(im, w / 2 - 1, y - 4, 3, 4, c("5a7aa8"))
			K.px(im, w / 2 - 1, y - 6, c("e04a6a"))
			K.px(im, w / 2 + 1, y - 7, c("e0c040"))
			K.px(im, w / 2, y - 6, c("5a9a4a"))
		"pizza":
			K.ellipse(im, w / 2.0, y, 5.0, 2.5, c("e0a040"))
			K.px(im, w / 2 - 2, y, c("c8402e"))
			K.px(im, w / 2 + 2, y - 1, c("c8402e"))
		"papers":
			K.rect(im, w / 2 - 4, y - 2, 7, 4, c("f0e8d0"))
			K.rect(im, w / 2 + 4, y - 2, 4, 3, c("c8a050"))


func _p_table_long(o: Dictionary) -> Image:
	var w: int = o.get("w", 80)
	var im := K.make(w, 22)
	var wood := _wood(o)
	K.shadow(im, w / 2.0, 20.0, w / 2.0 - 2.0, 2.0, 0.3)
	for lx in [3, w - 6]:
		K.rect(im, lx, 10, 3, 10, wood.darkened(0.25))
	var cloth := c(o.get("cloth", "")) if o.has("cloth") else wood
	K.rect(im, 0, 3, w, 8, cloth)
	K.hline(im, 0, 3, w, cloth.lightened(0.2))
	K.rect(im, 0, 10, w, 3, cloth.darkened(0.2))
	if not o.has("cloth"):
		for gx in range(6, w, 13):
			K.hline(im, gx, 6, 5, wood.darkened(0.1))
	_table_items(im, w, 6, o)
	if o.get("set", "") == "dinner":
		for cx in range(w / 4, w, w / 4):
			K.rect(im, cx, -1, 1, 5, c("f0e8d0"))
			K.px(im, cx, 0, c("ffd060"))
	K.outline(im)
	return im


func _p_chair(o: Dictionary) -> Image:
	var im := K.make(12, 18)
	var wood := _wood(o)
	K.shadow(im, 6.0, 16.0, 5.0, 1.5, 0.25)
	K.rect(im, 2, 0, 8, 9, wood)
	K.rect(im, 3, 1, 6, 6, c(o.get("seat", "8a3a2a")))
	K.rect(im, 1, 9, 10, 3, wood.lightened(0.1))
	K.rect(im, 2, 12, 2, 5, wood.darkened(0.2))
	K.rect(im, 8, 12, 2, 5, wood.darkened(0.2))
	K.outline(im)
	return im


func _p_bench(o: Dictionary) -> Image:
	var w: int = o.get("w", 40)
	var im := K.make(w, 16)
	var wood := _wood(o)
	K.shadow(im, w / 2.0, 14.0, w / 2.0 - 2.0, 1.5, 0.25)
	if o.get("back", false):
		K.rect(im, 1, 0, w - 2, 5, wood.darkened(0.08))
		K.hline(im, 1, 0, w - 2, wood.lightened(0.2))
	K.rect(im, 0, 6, w, 4, wood)
	K.hline(im, 0, 6, w, wood.lightened(0.25))
	for lx in [2, w - 5]:
		K.rect(im, lx, 10, 3, 5, wood.darkened(0.25))
	K.outline(im)
	return im


func _p_pew(o: Dictionary) -> Image:
	var w: int = o.get("w", 64)
	var im := K.make(w, 20)
	var wood := _wood(o)
	K.shadow(im, w / 2.0, 18.0, w / 2.0 - 2.0, 1.5, 0.3)
	K.rect(im, 0, 0, w, 9, wood.darkened(0.1))
	K.hline(im, 0, 0, w, wood.lightened(0.25))
	for px_x in range(4, w - 6, 12):
		K.rect(im, px_x, 2, 9, 5, wood.darkened(0.2))
	K.rect(im, 0, 9, w, 4, wood)
	K.hline(im, 0, 9, w, wood.lightened(0.15))
	K.rect(im, 0, 0, 3, 18, wood.darkened(0.15))
	K.rect(im, w - 3, 0, 3, 18, wood.darkened(0.15))
	K.outline(im)
	return im


func _p_sofa(o: Dictionary) -> Image:
	var w: int = o.get("w", 48)
	var im := K.make(w, 22)
	var col := c(o.get("color", "8a3a2a"))
	K.shadow(im, w / 2.0, 20.0, w / 2.0 - 2.0, 2.0, 0.3)
	K.rect(im, 2, 0, w - 4, 11, col.darkened(0.12))
	K.hline(im, 2, 0, w - 4, col.lightened(0.15))
	for px_x in range(6, w - 8, 14):
		K.rect(im, px_x, 2, 11, 7, col.lightened(0.04))
	K.rect(im, 0, 8, 6, 11, col.darkened(0.2))
	K.rect(im, w - 6, 8, 6, 11, col.darkened(0.2))
	K.rect(im, 5, 11, w - 10, 6, col)
	K.hline(im, 5, 11, w - 10, col.lightened(0.2))
	K.rect(im, 2, 19, 2, 2, mat.timber[1])
	K.rect(im, w - 4, 19, 2, 2, mat.timber[1])
	if o.get("pattern", false):
		for px_x in range(8, w - 8, 6):
			K.px(im, px_x, 4, c("e8d8a8"))
			K.px(im, px_x + 2, 13, c("e8d8a8"))
	K.outline(im)
	return im


func _p_armchair(o: Dictionary) -> Image:
	var o2 := o.duplicate()
	o2.w = 20
	return _p_sofa(o2)


func _p_coffee_table(o: Dictionary) -> Image:
	var im := K.make(30, 14)
	var wood := _wood(o)
	K.shadow(im, 15.0, 12.0, 13.0, 1.5, 0.25)
	K.rect(im, 0, 2, 30, 6, wood)
	K.hline(im, 0, 2, 30, wood.lightened(0.25))
	K.rect(im, 2, 8, 2, 4, wood.darkened(0.25))
	K.rect(im, 26, 8, 2, 4, wood.darkened(0.25))
	K.rect(im, 8, 0, 8, 3, c("3a5a8a"))
	K.rect(im, 18, 1, 5, 2, c("c8402e"))
	K.outline(im)
	return im


## A glass case of [param contents]: baskets, minerals, photographs,
## pastries, ice cream, artifacts, books or gifts.
func _p_case(o: Dictionary) -> Image:
	var w: int = o.get("w", 48)
	var im := K.make(w, 30)
	var wood := _wood(o)
	K.shadow(im, w / 2.0, 28.0, w / 2.0 - 2.0, 2.0, 0.3)
	_vboards(im, 1, 14, w - 2, 14, wood, w + 3, 4)
	K.rect(im, 1, 2, w - 2, 12, c("bcd8dc"))
	K.rect(im, 2, 3, w - 4, 10, c("d8eef0").darkened(0.12))
	var contents: String = o.get("contents", "artifacts")
	for i in range(0, (w - 8) / 7):
		var gx := 4 + i * 7
		match contents:
			"baskets":
				K.ellipse(im, gx + 3, 9, 3.0, 3.0, c("c8a060"))
				K.hline(im, gx, 9, 7, c("6a3a20"))
			"minerals":
				K.ellipse(im, gx + 3, 10, 2.5, 2.0, [mat.granite[5], c("c8a8e0"), c("e8e0d0"), c("8a5a3a")][i % 4])
			"photos":
				K.rect(im, gx, 5, 6, 7, c("e8e4dc"))
				K.rect(im, gx + 1, 6, 4, 5, c("6a6a6a").lightened(K.hash2(i, w, 2) * 0.3))
			"pastries":
				K.ellipse(im, gx + 3, 10, 3.0, 2.0, [c("d8a050"), c("8a4a2a"), c("e8c890")][i % 3])
				K.px(im, gx + 2, 9, c("f0e0c0"))
			"icecream":
				K.rect(im, gx, 7, 6, 5, [c("f0e8d8"), c("8a5a3a"), c("f0a8b8"), c("b8e0b0")][i % 4])
				K.hline(im, gx, 7, 6, Color(1, 1, 1, 0.6))
			"books":
				K.rect(im, gx, 6, 5, 6, Color.from_hsv(K.hash2(i, w, 1), 0.4, 0.6))
			"gifts":
				_stock_box(im, gx, 5, 5, 7, [c("c8402e"), c("3a78c0"), c("e0a040"), c("5a9a4a")][i % 4])
			_:
				K.ellipse(im, gx + 3, 10, 2.5, 2.0, [c("c8a060"), mat.granite[4], c("8a5a3a")][i % 3])
				K.px(im, gx + 3, 7, c("e8e0c8"))
	K.hline(im, 1, 2, w - 2, c("ffffff"))
	K.px(im, 4, 4, c("ffffff"))
	K.px(im, 5, 5, c("ffffff"))
	K.hline(im, 0, 14, w, wood.lightened(0.2))
	K.outline(im)
	return im


func _p_easel(o: Dictionary) -> Image:
	var im := K.make(26, 44)
	K.shadow(im, 13.0, 42.0, 10.0, 1.5, 0.25)
	K.vline(im, 5, 6, 37, mat.timber[3])
	K.vline(im, 20, 6, 37, mat.timber[3])
	K.vline(im, 13, 2, 38, mat.timber[2])
	K.rect(im, 3, 26, 20, 2, mat.timber[4])
	frame(im, 3, 4, 20, 20, o.get("painting", "painting"), 26)
	K.outline(im)
	return im


func _p_piano(o: Dictionary) -> Image:
	var grand: bool = o.get("grand", false)
	var w := 44 if grand else 36
	var im := K.make(w, 34)
	var body := c(o.get("color", "2a1f1a"))
	K.shadow(im, w / 2.0, 32.0, w / 2.0 - 1.0, 2.0, 0.3)
	if grand:
		K.ellipse(im, w * 0.6, 12.0, w * 0.4, 9.0, body)
		K.rect(im, 2, 6, w - 10, 14, body)
		K.rect(im, 2, 20, w - 4, 4, body.lightened(0.08))
		for k in range(4, w - 6, 2):
			K.px(im, k, 21, c("f4f0e8"))
			if k % 6 != 0:
				K.px(im, k, 22, c("f4f0e8"))
		K.rect(im, 6, 0, 2, 8, body.lightened(0.2))
	else:
		K.rect(im, 0, 0, w, 22, body)
		K.hline(im, 0, 0, w, body.lightened(0.25))
		K.rect(im, 3, 4, w - 6, 8, body.lightened(0.08))
		K.rect(im, 0, 14, w, 4, body.lightened(0.1))
		for k in range(1, w - 1, 2):
			K.px(im, k, 15, c("f4f0e8"))
			if k % 6 != 0:
				K.px(im, k, 16, c("f4f0e8"))
		K.rect(im, w / 2 - 4, 2, 8, 6, c("f0e8d0"))
	for lx in [3, w - 6]:
		K.rect(im, lx, 24, 3, 8, body)
	K.outline(im)
	return im


func _p_desk(o: Dictionary) -> Image:
	var w: int = o.get("w", 40)
	var im := K.make(w, 26)
	var wood := _wood(o)
	K.shadow(im, w / 2.0, 24.0, w / 2.0 - 2.0, 2.0, 0.3)
	K.rect(im, 0, 6, w, 5, wood.lightened(0.08))
	K.hline(im, 0, 6, w, wood.lightened(0.3))
	K.rect(im, 1, 11, 12, 13, wood)
	K.rect(im, w - 13, 11, 12, 13, wood)
	for dy in [13, 18]:
		K.hline(im, 2, dy, 10, wood.darkened(0.3))
		K.px(im, 7, dy + 2, c("e0b850"))
		K.hline(im, w - 12, dy, 10, wood.darkened(0.3))
	match o.get("items", "papers"):
		"typewriter":
			K.rect(im, w / 2 - 6, 1, 12, 6, c("2a2a2a"))
			K.rect(im, w / 2 - 4, 0, 8, 2, c("f0e8d0"))
		"telegraph":
			K.rect(im, w / 2 - 4, 3, 8, 3, c("c8a050"))
			K.vline(im, w / 2, 0, 3, mat.iron[2])
		"lamp":
			K.rect(im, w - 10, 0, 2, 7, c("c8a050"))
			K.ellipse(im, w - 9, 0, 4.0, 2.0, c("3a7a4a"))
			K.rect(im, 6, 4, 10, 3, c("f0e8d0"))
		_:
			K.rect(im, 6, 4, 10, 3, c("f0e8d0"))
			K.rect(im, w - 14, 3, 4, 4, c("3a3a4a"))
	K.outline(im)
	return im


func _p_bed(o: Dictionary) -> Image:
	var im := K.make(34, 44)
	var wood := _wood(o)
	var cover := c(o.get("color", "8a2f2f"))
	K.shadow(im, 17.0, 42.0, 15.0, 2.0, 0.3)
	K.rect(im, 0, 0, 34, 10, wood)
	K.hline(im, 0, 0, 34, wood.lightened(0.25))
	K.rect(im, 2, 8, 30, 32, c("f0ece0"))
	K.rect(im, 4, 9, 12, 6, c("fbf8f0"))
	K.rect(im, 18, 9, 12, 6, c("fbf8f0"))
	K.rect(im, 2, 17, 30, 23, cover)
	K.hline(im, 2, 17, 30, cover.lightened(0.25))
	for yy in range(21, 38, 6):
		for xx in range(5, 30, 6):
			K.px(im, xx, yy, c("e8d8a8"))
	K.rect(im, 0, 38, 34, 4, wood.darkened(0.1))
	K.outline(im)
	return im


func _p_cot(o: Dictionary) -> Image:
	var im := K.make(20, 36)
	K.shadow(im, 10.0, 34.0, 9.0, 1.5, 0.25)
	K.rect(im, 1, 2, 18, 30, mat.iron[2])
	K.rect(im, 2, 3, 16, 28, c(o.get("color", "6a6a4a")))
	K.rect(im, 3, 4, 14, 5, c("e8e4d8"))
	K.rect(im, 1, 32, 2, 3, mat.iron[1])
	K.rect(im, 17, 32, 2, 3, mat.iron[1])
	K.outline(im)
	return im


func _p_dresser(o: Dictionary) -> Image:
	var w: int = o.get("w", 28)
	var im := K.make(w, 30)
	var wood := _wood(o)
	K.shadow(im, w / 2.0, 28.0, w / 2.0 - 1.0, 2.0, 0.3)
	K.rect(im, 0, 6, w, 21, wood)
	K.hline(im, 0, 6, w, wood.lightened(0.25))
	for dy in [10, 16, 22]:
		K.hline(im, 2, dy, w - 4, wood.darkened(0.3))
		K.px(im, w / 2, dy + 2, c("e0b850"))
	if o.get("mirror", false):
		K.rect(im, w / 2 - 6, 0, 12, 7, wood.darkened(0.1))
		K.rect(im, w / 2 - 5, 1, 10, 5, c("c8dce0"))
	else:
		K.rect(im, w / 2 - 3, 1, 6, 5, c("e8e4d8"))
		K.rect(im, w / 2 - 2, 0, 4, 1, c("5a7aa8"))
	K.outline(im)
	return im


func _p_pulpit(o: Dictionary) -> Image:
	var im := K.make(20, 34)
	var wood := _wood(o)
	K.shadow(im, 10.0, 32.0, 8.0, 1.5, 0.3)
	K.rect(im, 3, 8, 14, 24, wood)
	K.rect(im, 1, 4, 18, 5, wood.lightened(0.1))
	K.hline(im, 1, 4, 18, wood.lightened(0.3))
	K.rect(im, 6, 2, 8, 3, c("f0e8d0"))
	K.rect(im, 9, 14, 2, 10, c("c8a050"))
	K.rect(im, 6, 17, 8, 2, c("c8a050"))
	K.outline(im)
	return im


func _p_plant(o: Dictionary) -> Image:
	var im := K.make(18, 28)
	K.shadow(im, 9.0, 26.0, 6.0, 1.5, 0.25)
	K.rect(im, 4, 18, 10, 8, c(o.get("pot", "a85a3a")))
	K.hline(im, 3, 18, 12, c(o.get("pot", "a85a3a")).lightened(0.2))
	for k in 9:
		var a := -PI * 0.9 + k * PI * 0.8 / 8.0
		for r in 10:
			K.px(im, 9 + int(cos(a) * r), 17 + int(sin(a) * r * 1.3), mat.leaf[2 + (r % 3)])
	K.outline(im)
	return im


func _p_lamp(_o: Dictionary) -> Image:
	var im := K.make(14, 40)
	K.shadow(im, 7.0, 38.0, 5.0, 1.5, 0.25)
	K.vline(im, 7, 10, 27, mat.iron[2])
	K.rect(im, 4, 36, 7, 2, mat.iron[1])
	for yy in 10:
		K.hline(im, 7 - (3 + yy / 3), yy, (3 + yy / 3) * 2 + 1, c("e8c890") if yy < 8 else c("c89a5a"))
	_pool(im, 7, 6, 7, 0.3)
	K.outline(im)
	return im


## A model of the park's relief on a table: granite domes, green valleys,
## and the river.
func _p_relief(o: Dictionary) -> Image:
	var w: int = o.get("w", 56)
	var im := K.make(w, 30)
	var wood := _wood(o)
	K.shadow(im, w / 2.0, 28.0, w / 2.0 - 2.0, 2.0, 0.3)
	K.rect(im, 0, 14, w, 12, wood)
	K.hline(im, 0, 14, w, wood.lightened(0.2))
	for yy in 13:
		for xx in w - 4:
			var hgt := ValleyArt.vnoise(xx * 0.12, yy * 0.3, w)
			var col: Color = mat.leaf[2] if hgt < 0.45 else mat.granite[clampi(int(hgt * 7.0), 2, 6)]
			if absi(yy - 6 - int(sin(xx * 0.2) * 2.0)) < 1:
				col = c("5a8ac0")
			K.px(im, 2 + xx, 1 + yy, col)
	K.outline(im)
	return im


func _p_anvil(_o: Dictionary) -> Image:
	var im := K.make(24, 20)
	K.shadow(im, 12.0, 18.0, 9.0, 1.5, 0.3)
	K.rect(im, 7, 10, 10, 8, mat.timber[2])
	K.rect(im, 3, 4, 18, 5, mat.iron[2])
	K.hline(im, 3, 4, 18, mat.iron[3].lightened(0.2))
	K.rect(im, 0, 5, 4, 2, mat.iron[2])
	K.rect(im, 8, 8, 8, 3, mat.iron[1])
	K.outline(im)
	return im


## Two frames: the forge's coals dull, then bright.
func _p_forge(_o: Dictionary) -> Image:
	var sheet := K.make(80, 50)
	for f in 2:
		var im := K.make(40, 50)
		K.shadow(im, 20.0, 48.0, 17.0, 2.0, 0.3)
		mat.stone_wall(im, 2, 22, 36, 24, 1890, 0.4, 4, 3, false)
		K.rect(im, 14, 0, 12, 24, c("4a3a32"))
		K.vline(im, 14, 0, 24, c("6a5a50"))
		K.rect(im, 6, 20, 28, 5, mat.iron[1])
		for k in 12:
			var cx := 8 + int(K.hash2(k, f, 3) * 24.0)
			K.px(im, cx, 21 + k % 3, [c("ff8a2a"), c("ffd060"), c("c8402e")][(k + f) % 3])
		if f == 1:
			_pool(im, 20, 20, 14, 0.25)
		K.outline(im)
		K.stamp(sheet, im, f * 40, 0)
	return sheet


## Two frames: a big granite fireplace on the back wall, the fire low then
## high. [code]w[/code] sets its width.
func _p_hearth(o: Dictionary) -> Image:
	var w: int = o.get("w", 56)
	var h: int = o.get("h", 64)
	var sheet := K.make(w * 2, h)
	for f in 2:
		var im := K.make(w, h)
		mat.stone_wall(im, 0, 0, w, h - 2, w + 7, 0.6, 5, 4, false)
		K.rect(im, w / 2 - w / 4 - 2, h - 28, w / 2 + 4, 4, mat.granite[6])
		K.rect(im, w / 2 - w / 4, h - 24, w / 2, 22, c("1a1412"))
		ValleyArt.shade(im, w / 2 - w / 4, h - 24, w / 2, 22, c("3a2418"), 0.0, 0.8, 0.6)
		for k in 3:
			K.rect(im, w / 2 - 8 + k * 5, h - 6, 6, 3, mat.timber[1 + k % 2])
		var flames := 5 + f * 2
		for k in flames:
			var fx := w / 2 - 8 + int(K.hash2(k, f, 4) * 16.0)
			var fh := 4 + int(K.hash2(k, f, 5) * (8.0 + f * 4.0))
			for yy in fh:
				K.px(im, fx, h - 6 - yy, [c("ffe070"), c("ffb03a"), c("ff7a2a"), c("c8402e")][mini(3, yy * 4 / fh)])
		_pool(im, w / 2, h - 8, w / 3, 0.18 + f * 0.08)
		K.hline(im, 0, 0, w, mat.granite[6])
		K.rect(im, 0, h - 2, w, 2, mat.granite[2])
		K.outline(im)
		K.stamp(sheet, im, f * w, 0)
	return sheet


func _p_column(o: Dictionary) -> Image:
	var h: int = o.get("h", 70)
	var im := K.make(16, h)
	K.shadow(im, 8.0, h - 2.0, 7.0, 2.0, 0.3)
	if o.get("look", "") == "log":
		for yy in h - 4:
			for xx in 12:
				var t: float = [0.12, 0.1, 0.06, 0.03, 0.0, -0.02, -0.05, -0.08, -0.12, -0.16, -0.22, -0.3][xx]
				K.px(im, 2 + xx, yy, _tone(c("7a5232"), t + (K.hash2(xx, yy / 3, 4) - 0.5) * 0.05, 0.3))
	else:
		mat.stone_wall(im, 1, 0, 14, h - 3, h, 0.6, 5, 3, false)
	K.rect(im, 0, h - 5, 16, 3, mat.granite[3])
	K.outline(im)
	return im


func _p_safe(_o: Dictionary) -> Image:
	var im := K.make(22, 26)
	K.shadow(im, 11.0, 24.0, 9.0, 1.5, 0.3)
	K.rect(im, 1, 2, 20, 21, c("3a4a3a"))
	K.hline(im, 1, 2, 20, c("6a7a6a"))
	K.rect(im, 4, 5, 14, 15, c("2e3a2e"))
	K.ring(im, 11, 12, 3.0, 3.0, c("c8a050"))
	K.px(im, 11, 12, c("f0d070"))
	K.text(im, 5, 6, "WF", c("c8a050"))
	K.outline(im)
	return im


func _p_coat_rack(_o: Dictionary) -> Image:
	var im := K.make(16, 40)
	K.shadow(im, 8.0, 38.0, 5.0, 1.5, 0.25)
	K.vline(im, 8, 2, 35, mat.timber[3])
	K.rect(im, 4, 36, 9, 2, mat.timber[2])
	K.rect(im, 2, 6, 6, 14, c("5a3a2a"))
	K.rect(im, 9, 4, 5, 10, c("3a4a6a"))
	K.ellipse(im, 8, 2, 5.0, 2.0, c("6a5a3a"))
	K.outline(im)
	return im


func _p_crates(_o: Dictionary) -> Image:
	var im := K.make(32, 30)
	K.shadow(im, 16.0, 28.0, 14.0, 2.0, 0.3)
	K.crate(im, 1, 12, 16, 15, c("a07a4a"))
	K.crate(im, 15, 14, 15, 13, c("8a6a3a"))
	K.crate(im, 6, 0, 14, 13, c("b08a5a"))
	K.outline(im)
	return im


func _p_trunk(o: Dictionary) -> Image:
	var im := K.make(26, 18)
	var col := c(o.get("color", "6a4a2a"))
	K.shadow(im, 13.0, 16.0, 11.0, 1.5, 0.3)
	K.rect(im, 1, 4, 24, 11, col)
	K.ellipse(im, 13, 5, 12.0, 3.0, col.lightened(0.1))
	for bx in [5, 19]:
		K.vline(im, bx, 2, 13, c("c8a050"))
	K.rect(im, 11, 8, 4, 3, c("e0b850"))
	K.outline(im)
	return im


func _p_luggage(_o: Dictionary) -> Image:
	var im := K.make(28, 34)
	K.shadow(im, 14.0, 32.0, 12.0, 1.5, 0.3)
	K.vline(im, 3, 0, 30, c("c8a050"))
	K.vline(im, 24, 0, 30, c("c8a050"))
	K.ellipse(im, 13.5, 1, 11.0, 2.0, c("e0b850"))
	K.rect(im, 2, 26, 24, 3, c("8a2f2f"))
	K.rect(im, 5, 14, 18, 12, c("6a4a2a"))
	K.rect(im, 7, 6, 12, 8, c("3a5a6a"))
	K.rect(im, 4, 30, 3, 3, mat.iron[1])
	K.rect(im, 21, 30, 3, 3, mat.iron[1])
	K.outline(im)
	return im


func _p_telescope(_o: Dictionary) -> Image:
	var im := K.make(20, 36)
	K.shadow(im, 10.0, 34.0, 8.0, 1.5, 0.25)
	for k in 3:
		var a: float = [-0.4, 0.4, 0.0][k]
		for r in 16:
			K.px(im, 10 + int(sin(a) * r), 18 + r, mat.iron[2])
	for k in 14:
		K.px(im, 4 + k, 12 - k / 2, c("c8a050"))
		K.px(im, 4 + k, 13 - k / 2, c("8a6a2a"))
	K.outline(im)
	return im


func _p_canisters(_o: Dictionary) -> Image:
	var im := K.make(40, 30)
	K.shadow(im, 20.0, 28.0, 18.0, 1.5, 0.3)
	K.rect(im, 0, 4, 40, 3, mat.timber[3])
	K.rect(im, 0, 16, 40, 3, mat.timber[3])
	K.rect(im, 1, 4, 2, 24, mat.timber[2])
	K.rect(im, 37, 4, 2, 24, mat.timber[2])
	for row in [0, 12]:
		for cx in range(5, 36, 8):
			K.rect(im, cx, row - 1 + 6, 6, 9, c("2a2a2e"))
			K.hline(im, cx, row + 5, 6, c("6a6a74"))
			K.rect(im, cx, row + 8, 6, 2, c("e0a040"))
	K.outline(im)
	return im


func _p_basket(o: Dictionary) -> Image:
	var big: bool = o.get("big", false)
	var w := 18 if big else 12
	var h := 22 if big else 14
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 2.0, w / 2.0 - 1.0, 1.5, 0.25)
	for yy in h - 3:
		var t := float(yy) / (h - 3)
		var half := (w / 2.0 - 1.0) * (0.55 + 0.45 * t) if big else (w / 2.0 - 1.0) * (0.8 + 0.2 * sin(t * PI))
		for xx in range(-int(half), int(half) + 1):
			var band := (yy / 2) % 4
			var col := c("c8a060") if band < 2 else (c("6a3a20") if band == 2 else c("a07a40"))
			if band == 2 and (xx + yy) % 3 == 0:
				col = c("2a1a10")
			K.px(im, w / 2 + xx, yy + 1, col)
	K.outline(im)
	return im


func _p_washstand(_o: Dictionary) -> Image:
	var im := K.make(20, 26)
	K.shadow(im, 10.0, 24.0, 8.0, 1.5, 0.25)
	K.rect(im, 1, 8, 18, 15, mat.timber[3])
	K.hline(im, 1, 8, 18, mat.timber[5])
	K.ellipse(im, 10, 7, 7.0, 2.5, c("e8e4d8"))
	K.rect(im, 7, 1, 6, 6, c("e8e4d8"))
	K.px(im, 13, 2, c("e8e4d8"))
	K.outline(im)
	return im


func _p_rack(o: Dictionary) -> Image:
	var w: int = o.get("w", 36)
	var im := K.make(w, 34)
	K.shadow(im, w / 2.0, 32.0, w / 2.0 - 2.0, 1.5, 0.25)
	K.vline(im, 1, 2, 30, mat.iron[2])
	K.vline(im, w - 2, 2, 30, mat.iron[2])
	_tool_rack(im, 1, 3, w - 2)
	K.hline(im, 1, 31, w - 2, mat.iron[1])
	K.outline(im)
	return im


func _p_spinner(o: Dictionary) -> Image:
	# a spinning rack of postcards or maps
	var im := K.make(18, 40)
	K.shadow(im, 9.0, 38.0, 7.0, 1.5, 0.25)
	K.vline(im, 9, 26, 12, mat.iron[2])
	K.rect(im, 5, 36, 9, 2, mat.iron[1])
	for row in 3:
		for k in 3:
			var col := Color.from_hsv(K.hash2(row, k, o.get("w", 3)), 0.35, 0.85)
			K.rect(im, 2 + k * 5, 2 + row * 8, 4, 7, col)
			K.hline(im, 2 + k * 5, 2 + row * 8, 4, c("ffffff"))
	K.outline(im)
	return im


func _p_stool(_o: Dictionary) -> Image:
	return stool()


func _p_stove(_o: Dictionary) -> Image:
	return stove_sheet()


func _p_shelf(_o: Dictionary) -> Image:
	return store_shelf()


func _p_cooler(_o: Dictionary) -> Image:
	return cooler()


func _p_barrels(_o: Dictionary) -> Image:
	return barrels()


func _p_postcards(_o: Dictionary) -> Image:
	return postcard_rack()


func _p_chalkboard(_o: Dictionary) -> Image:
	return chalkboard()


func _p_workbench(_o: Dictionary) -> Image:
	return workbench()


## A free-standing exhibit panel on two legs: a picture over lines of text.
func _p_panel(o: Dictionary) -> Image:
	var im := K.make(30, 36)
	K.shadow(im, 15.0, 34.0, 12.0, 1.5, 0.25)
	K.rect(im, 4, 22, 2, 12, mat.timber[2])
	K.rect(im, 24, 22, 2, 12, mat.timber[2])
	K.rect(im, 0, 0, 30, 24, c(o.get("color", "4a3a2a")))
	K.rect(im, 2, 2, 26, 20, c("e8dcc0"))
	frame(im, 4, 4, 22, 9, o.get("picture", "photo"), 30)
	for ly in range(15, 21, 2):
		K.hline(im, 4, ly, 18 + int(K.hash2(ly, 3, 1) * 4.0), c("6a5a4a"))
	K.outline(im)
	return im
