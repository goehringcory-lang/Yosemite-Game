extends "res://tools/hubs/curry_art.gd"
## Curry Village's buildings, cabins, props and entrance arch redrawn in the
## Ahwahnee's style: the hotel's materials (cut-granite footings with moss,
## stained timber and plaster, mossy shingle roofs, painted signs), ramp-shaded
## and ordered-dithered, light from the upper left, dark rim. Shingles, planks,
## windows, signs and awnings are drawn here with hue-shifted tones (shadows
## cool toward violet, lights warm toward yellow). Everything else in the camp
## keeps curry_art.gd's version. Every sprite keeps its size and where its doors
## and signs sit, so the village scene needs no changes.
## Written to assets/sprites/curry/ by save_all(). Replace any PNG with
## hand-drawn art of the same size at any time.

const ValleyArt = preload("res://tools/hubs/valley_art.gd")
const RIM := Color("231a16")

## Roof ramps for the gable and chimney code, dark to light.
const GREEN_RAMP := ["1f3326", "2c4631", "3c5d3f", "4f7650", "698f62", "88aa7c"]
const SLATE_RAMP := ["22262c", "30363e", "444c56", "5a6470", "76818c", "98a3ac"]
const BROWN_RAMP := ["2c1c14", "46301f", "62432a", "7d5636", "9a7048", "b88c60"]
const RED_RAMP := ["2e1814", "4e2a20", "6e3a2a", "8c4c36", "aa6448", "c68260"]
const CANVAS_RAMP := ["6a6c76", "8e8d92", "b0aaa0", "cec6b0", "e6dec6", "f6f0dc"]
## Base colors for the shingles and their five-step hue-shifted ramps.
const GREEN_BASE := Color("4f7650")
const SLATE_BASE := Color("5a6470")
const BROWN_BASE := Color("8a5c3a")
const RED_BASE := Color("a85a40")
const PLANK_BASE := Color("9a7048")
const MOSS := Color("5f8f4a")

var mat := ValleyArt.new()


## Runs [param draw] with the roof ramp swapped in for the gables.
func _with_roof(ramp: Array, draw: Callable) -> void:
	var saved := mat.roof
	mat.roof = mat._ramp(ramp)
	draw.call()
	mat.roof = saved


## Shifts [param col]: [param light] lightens or darkens it, and [param warm]
## pulls the hue toward yellow (warm > 0, lights) or toward blue-violet
## (warm < 0, shadows), the shorter way round the color wheel.
func _tone(col: Color, light: float, warm: float) -> Color:
	var target := 0.12 if warm > 0.0 else 0.58
	var d := fposmod(target - col.h + 0.5, 1.0) - 0.5
	var hue := fposmod(col.h + d * clampf(absf(warm) * 0.22, 0.0, 0.22), 1.0)
	var sat := clampf(col.s + (0.03 if light > 0.0 else 0.0), 0.0, 1.0)
	return Color.from_hsv(hue, sat, clampf(col.v + light, 0.0, 1.0), col.a)


## A five-step ramp from [param base]: deep shadow, shade, base, light, lit edge.
func _ramp5(base: Color) -> Array[Color]:
	var out: Array[Color] = []
	out.append(_tone(base, -0.26, -1.0))
	out.append(_tone(base, -0.13, -0.6))
	out.append(base)
	out.append(_tone(base, 0.1, 0.6))
	out.append(_tone(base, 0.2, 1.0))
	return out


## Shingle courses in hue-shifted tabs: each tab lit on its upper-left corner
## and dark along its lower seam, courses stepping down the roof, a few moss
## clusters on the lower courses, a lit ridge cap, and a dark fascia at the eave.
func _shingles(im: Image, x: int, y: int, w: int, h: int, ramp: Array[Color], sd: int, taper: float) -> void:
	var course := 3
	for row in h:
		var inset := int((h - 1 - row) * taper)
		var ci := row / course
		var inr := row % course
		var off := (ci % 2) * 3
		for sx in range(x + inset, x + w - inset):
			var tab := (sx - x + off) / 5
			var n := K.hash2(tab, ci, sd)
			var idx := 1 + int(n * 3.0)
			if inr == 0:
				idx += 1
			if inr == course - 1:
				idx = 0
			if sx - x - inset < 2:
				idx += 1
			if sx >= x + w - inset - 2:
				idx -= 1
			if (sx - x + off) % 5 == 4 and inr < course - 1:
				idx = maxi(0, idx - 1)
			var col := ramp[clampi(idx, 0, 4)]
			if ci >= 1 and row > h * 0.4 and inr == 1 and K.hash2(sx / 2, ci, sd + 7) > 0.9:
				col = MOSS.lerp(ramp[2], 0.25)
			K.px(im, sx, y + row, col)
	var ri := int((h - 1) * taper)
	K.hline(im, x + ri, y, w - ri * 2, _tone(ramp[4], 0.1, 1.0))
	K.hline(im, x + ri + 1, y + 1, w - ri * 2 - 2, ramp[3])
	K.hline(im, x, y + h - 1, w, ramp[0].darkened(0.25))


## Stained vertical planks: a lit left edge and shaded right edge on every
## board, grain as short dashes in clusters, and a few knots.
func _planks(im: Image, x: int, y: int, w: int, h: int, base: Color, sd: int, board := 5) -> void:
	var ramp := _ramp5(base)
	for xx in w:
		var b := xx / board
		var ib := xx % board
		var btone := 1 + int(K.hash2(b, sd, 3) * 3.0)
		if ib == 0:
			btone += 1
		if ib == board - 1:
			btone = 0
		for yy in h:
			var idx := btone
			var gs := K.hash2(b * 7 + ib, yy / 3, sd + 5)
			if gs > 0.86:
				idx -= 1
			elif gs < 0.1:
				idx += 1
			if yy > h * 0.85:
				idx -= 1
			K.px(im, x + xx, y + yy, ramp[clampi(idx, 0, 4)])
	for k in maxi(1, w * h / 160):
		var kx := x + 2 + int(K.hash2(k, sd, 11) * (w - 4))
		var ky := y + 2 + int(K.hash2(k, sd, 12) * (h - 4))
		K.hline(im, kx, ky, 2, ramp[0])
		K.px(im, kx, ky + 1, ramp[1])


## A horizontal board of [param h] rows, lit on top and shaded at the bottom.
func _slat(im: Image, x: int, y: int, w: int, h: int, ramp: Array[Color], sd: int) -> void:
	for yy in h:
		var idx := 2
		if yy == 0:
			idx = 4
		elif yy == h - 1:
			idx = 0
		for xx in w:
			var col := ramp[idx]
			if K.hash2(xx, yy, sd) > 0.9 and yy > 0 and yy < h - 1:
				col = ramp[clampi(idx - 1, 0, 4)]
			K.px(im, x + xx, y + yy, col)
	if w > 4:
		K.px(im, x + w / 3, y + h - 1, ramp[0].darkened(0.2))


## A sash window: a dark timber frame lit along its top, mullions, sky glass
## with a glint (or warm lamplight with a shade when lit), and a granite sill.
func _window(im: Image, x: int, y: int, w: int, h: int, lit: bool, sd: int) -> void:
	K.rect(im, x - 2, y - 2, w + 4, h + 4, mat.timber[0])
	K.rect(im, x - 1, y - 1, w + 2, h + 2, mat.timber[3])
	K.hline(im, x - 1, y - 1, w + 2, mat.timber[4])
	for gy in h:
		var v := float(gy) / maxf(1.0, float(h - 1))
		for gx in w:
			var n := K.hash2(gx, gy, sd)
			var col: Color
			if lit:
				col = mat.warm[clampi(roundi((0.9 - v * 0.6) * 6.0 + (n - 0.5) * 0.8) + 1, 1, 7)]
			else:
				col = mat.sky[clampi(roundi((0.95 - v * 0.75) * 4.0 + (n - 0.5) * 0.6), 0, 4)]
				if gy >= h - 3:
					col = mat.leaf[1] if gx % 4 != 2 else mat.leaf[2]
			K.px(im, x + gx, y + gy, col)
	if lit:
		K.hline(im, x, y, w, mat.timber[0])
		K.rect(im, x + w / 2 - 1, y + h / 3, 2, 2, mat.warm[7])
	else:
		K.px(im, x + 1, y + 2, Color(1, 1, 1, 0.85))
		K.px(im, x + 2, y + 3, Color(1, 1, 1, 0.55))
	K.vline(im, x + w / 2, y, h, mat.timber[2])
	K.hline(im, x, y + h / 2, w, mat.timber[2])
	K.rect(im, x - 3, y + h + 1, w + 6, 2, mat.granite[5])
	K.hline(im, x - 3, y + h + 1, w + 6, mat.granite[6])
	K.hline(im, x - 3, y + h + 3, w + 6, Color(0, 0, 0, 0.25))


## A carved board sign: a dark routed edge, a lit bevel on top and left, a
## shaded bottom, nail heads, and crisp lettering with a drop shadow.
func _sign(im: Image, cx: int, y: int, text: String, ink := Color("f0e2bc")) -> void:
	var w := K.text_width(text) + 8
	var x := cx - w / 2
	K.rect(im, x, y, w, 9, mat.timber[0])
	K.rect(im, x + 1, y + 1, w - 2, 7, mat.timber[2])
	K.hline(im, x + 1, y + 1, w - 2, mat.timber[4])
	K.vline(im, x + 1, y + 1, 7, mat.timber[3])
	K.hline(im, x + 1, y + 7, w - 2, mat.timber[1])
	for k in 4:
		K.hline(im, x + 3 + k * 9 % (w - 8), y + 4 + (k % 2), 3, mat.timber[1])
	K.px(im, x + 2, y + 4, mat.iron[2])
	K.px(im, x + w - 3, y + 4, mat.iron[2])
	K.text(im, x + 4, y + 2, text, ink, mat.timber[0])


## A striped fabric awning with folds: each fold a lit face and a dark crease,
## a scalloped valance and a soft shadow under it.
func _awning(im: Image, x: int, y: int, w: int, depth: int, a: Color, b: Color) -> void:
	for row in depth:
		for ax in w:
			var stripe := (ax / 4) % 2 == 0
			var col := a if stripe else b
			var fold := (ax + 2) % 6
			if fold == 0:
				col = col.darkened(0.16)
			elif fold == 1:
				col = col.lightened(0.12)
			col = col.lightened(0.08 - float(row) / depth * 0.2)
			if row == depth - 1:
				col = col.darkened(0.18)
			K.px(im, x + ax, y + row, col)
	for ax in range(0, w, 6):
		var stripe := (ax / 4) % 2 == 0
		var col := (a if stripe else b).darkened(0.24)
		K.hline(im, x + ax + 1, y + depth, 4, col)
		K.hline(im, x + ax + 2, y + depth + 1, 2, col)
	K.rect(im, x + 1, y + depth + 2, w - 2, 1, Color(0, 0, 0, 0.18))


## Hue-shifted horizontal deck boards with dark seams and grain.
func _deck(im: Image, x: int, y: int, w: int, h: int, base: Color, sd: int) -> void:
	var ramp := _ramp5(base)
	for yy in h:
		var board := yy / 3
		var iy := yy % 3
		for xx in w:
			var idx := 2 + int(K.hash2(board, sd, 2) * 2.0)
			if iy == 0:
				idx += 1
			elif iy == 2:
				idx = 0
			if K.hash2(xx / 4 + board * 9, yy, sd + 3) > 0.84:
				idx -= 1
			K.px(im, x + xx, y + yy, ramp[clampi(idx, 0, 4)])


## A round market umbrella seen from the front: a canopy of wedge stripes, lit
## on its upper left, with a cooler, darker underside and a shaded rim.
func _umbrella(im: Image, cx: float, cy: float, rx: float, dome_h: float, a: Color, b: Color) -> void:
	var rim_h := maxf(1.2, rx * 0.2)
	for x in range(floori(cx - rx) - 1, ceili(cx + rx) + 2):
		var dx := (x + 0.5 - cx) / rx
		if absf(dx) > 1.0:
			continue
		var round_k := sqrt(1.0 - dx * dx)
		# the dome's silhouette, the front rim, and a scalloped hem below the rim
		var top_y := cy - dome_h * round_k
		var rim_y := cy + rim_h * round_k
		var lobe := fposmod((dx + 1.0) * 4.0, 1.0)
		var hem_y := rim_y + 0.6 + 0.7 * sin(lobe * PI)
		# red and white wedges follow the dome's meridians: they bunch at the
		# top and spread toward the rim
		var theta := asin(clampf(dx, -1.0, 1.0))
		var k := clampi(floori((theta / (PI / 2.0) + 1.0) * 4.0), 0, 7)
		var stripe := a if k % 2 == 0 else b
		for y in range(floori(top_y), ceili(hem_y) + 1):
			var fy := float(y) + 0.5
			if fy < top_y or fy > hem_y:
				continue
			var col := stripe
			if fy > rim_y:
				# the underside band visible at the rim: darker and cooler
				col = _tone(stripe, -0.2, -0.6)
			elif dx < -0.2 and fy < cy - dome_h * 0.35:
				# lit on the upper left
				col = _tone(stripe, 0.12, 0.6)
			elif dx > 0.45:
				col = _tone(stripe, -0.08, -0.3)
			if y == floori(top_y):
				col = col.darkened(0.12)
			K.px(im, x, y, col)


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
	_planks(im, 3, wall_top, w - 6, h - wall_top - 8, PLANK_BASE, 71)
	_foundation(im, w, h, 7, 72)
	_shingles(im, 0, 2, w, roof_h - 1, _ramp5(GREEN_BASE), 73, 0.2)
	_with_roof(GREEN_RAMP, func() -> void:
		mat.gable(im, 44, wall_top - 1, 16, 15, 3, 74, true, 6)
		mat.chimney(im, 14, 8, 12, 75))
	mat.eave(im, 0, wall_top - 2, w)
	# porch: beam, posts, deck
	mat.beam(im, 1, wall_top + 2, w - 2, 76, 3)
	for px_x in [4, 24, 43, 62, 81]:
		mat.post(im, px_x, wall_top + 5, h - wall_top - 15, 77 + px_x, 3)
	_deck(im, 1, h - 10, w - 2, 3, Color("b08a5c"), 78)
	for wx in [10, 30, 57, 71]:
		_window(im, wx, wall_top + 9, 7, 9, K.hash2(wx, 5, 5) < 0.6, 80 + wx)
	mat.plank_door(im, w / 2, h - 9, 15, 81, 12)
	# the clock over the door
	K.ellipse(im, w / 2.0, wall_top + 5.0, 3.8, 3.8, mat.timber[0])
	K.ellipse(im, w / 2.0, wall_top + 5.0, 3.0, 3.0, Color("f0e6c8"))
	K.vline(im, w / 2, wall_top + 3, 3, RIM)
	K.hline(im, w / 2, wall_top + 5, 2, RIM)
	_sign(im, w / 2, wall_top - 12, "REGISTRATION")
	_shade_right(im, 3, wall_top, w - 6, h - wall_top - 8)
	K.outline(im, RIM)
	return im


func _foundation(im: Image, w: int, h: int, fh: int, sd: int) -> void:
	mat.stone_wall(im, 2, h - fh - 1, w - 4, fh, sd, 0.5, 3, 3, true)
	K.hline(im, 2, h - fh - 1, w - 4, mat.granite[5])


func _shade_right(im: Image, x: int, y: int, w: int, h: int) -> void:
	ValleyArt.shade(im, x + w - 9, y, 8, h, mat.timber[0], 0.0, 0.85, 0.34, false)
	ValleyArt.shade(im, x, y + 2, 4, h, mat.granite[6], 0.5, 0.0, 0.1, false)


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
	_shingles(im, 0, 2, w, roof_h - 1, _ramp5(GREEN_BASE), 93, 0.24)
	_with_roof(GREEN_RAMP, func() -> void:
		mat.chimney(im, 48, 7, 8, 94))
	mat.eave(im, 0, wall_top - 2, w)
	_sign(im, w / 2, wall_top + 1, "CURRY STORE", Color("f4ecd0"))
	for wx in [8, w - 22]:
		_window(im, wx, wall_top + 14, 12, 10, true, 95 + wx)
	for jar in [[10, 20, "d8a040"], [14, 20, "c05a3a"], [18, 20, "8a6ad0"], [w - 20, 20, "d8a040"], [w - 16, 20, "5a9a4a"], [w - 12, 20, "c05a3a"]]:
		K.rect(im, jar[0], wall_top + jar[1] + 2, 2, 3, Color(jar[2]))
		K.px(im, jar[0], wall_top + jar[1] + 1, Color(jar[2]).lightened(0.3))
	mat.plank_door(im, w / 2, h - 8, 14, 96, 10)
	_awning(im, 4, wall_top + 26, w - 8, 5, Color("4f7a4a"), Color("eadfba"))
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
	K.hline(im, w / 2 + 10, h - 13, 6, Color("4a5a50"))
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
	_planks(im, 3, wall_top, w - 6, h - wall_top - 12, Color("6a4c36"), 111, 6)
	mat.stone_wall(im, 2, h - 14, w - 4, 13, 112, 0.52, 4, 3, true)
	K.hline(im, 2, h - 14, w - 4, mat.granite[5])
	_shingles(im, 0, 2, w, roof_h - 1, _ramp5(SLATE_BASE), 113, 0.26)
	_with_roof(SLATE_RAMP, func() -> void:
		mat.chimney(im, w - 22, 7, 10, 114))
	mat.eave(im, 0, wall_top - 2, w)
	for bx in [3, 27, w - 6]:
		mat.post(im, bx, wall_top, h - wall_top - 12, 115 + bx, 3)
	_sign(im, w / 2, wall_top - 12, "MOUNTAIN SHOP", Color("e8ecf0"))
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
	_window(im, w - 18, wall_top + 7, 8, 9, K.hash2(w, 3, 3) < 0.7, 116)
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
		_slat(im, tx, h - 23, 14, 3, _ramp5(PLANK_BASE), 120 + tx)
		K.vline(im, tx + 1, h - 20, 6, Color("4e3220"))
		K.vline(im, tx + 12, h - 20, 6, Color("4e3220"))
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
	_shingles(im, 0, 2, w, roof_h - 1, _ramp5(BROWN_BASE), 124, 0.2)
	_with_roof(BROWN_RAMP, func() -> void:
		mat.gable(im, 52, wall_top - 1, 18, 17, 3, 125, true, 7)
		mat.chimney(im, w - 22, 8, 12, 126))
	mat.eave(im, 0, wall_top - 2, w)
	# the way in: steps and the sign
	K.rect(im, w / 2 - 8, h - 8, 16, 4, mat.granite[4])
	K.hline(im, w / 2 - 8, h - 8, 16, mat.granite[6])
	_sign(im, w / 2, wall_top - 12, "PAVILION")
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
	_shingles(im, 0, 2, w, roof_h - 1, _ramp5(RED_BASE), 132, 0.28)
	mat.eave(im, 0, wall_top - 2, w)
	_sign(im, w / 2, wall_top + 2, "PIZZA")
	# the wood-fired oven mouth
	K.rect(im, w / 2 - 5, wall_top + 11, 11, 5, mat.granite[1])
	K.rect(im, w / 2 - 4, wall_top + 12, 9, 3, mat.warm[4])
	K.px(im, w / 2, wall_top + 13, mat.warm[7])
	# the deck with rails and two umbrella tables
	_deck(im, 2, h - 20, w - 4, 16, PLANK_BASE, 133)
	K.hline(im, 2, h - 20, w - 4, mat.timber[5])
	for rx in range(4, w - 2, 6):
		mat.post(im, rx, h - 11, 7, 134 + rx, 2)
	K.hline(im, 2, h - 12, w - 4, mat.timber[4])
	K.hline(im, 2, h - 11, w - 4, mat.timber[1])
	for tx in [10, 38]:
		K.ellipse(im, tx + 8, h - 9, 5, 2, mat.timber[0])
		K.rect(im, tx + 8, h - 15, 1, 7, mat.timber[1])
		_umbrella(im, tx + 8.0, h - 15.0, 8.0, 5.0, Color("c8402e"), Color("eadfba"))
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
	_planks(im, 19, 3, 58, 13, Color("8a6440"), 142, 5)
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
				_slat(im, x0 + seg, y, sl, 3, _ramp5(PLANK_BASE), 150 + row * 7 + seg)
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


# ---------------------------------------------------------------- props

## A bench of stained slats on two posts: a slatted back, a seat, and a dark
## contact shadow under the legs.
func bench() -> Image:
	var im := K.make(28, 14)
	K.shadow(im, 14.0, 12.5, 12.0, 1.4, 0.3)
	var ramp := _ramp5(Color("a0764a"))
	_slat(im, 2, 0, 24, 2, ramp, 201)
	_slat(im, 2, 2, 24, 2, ramp, 202)
	K.rect(im, 2, 0, 2, 6, ramp[1])
	K.rect(im, 23, 0, 2, 6, ramp[1])
	_slat(im, 1, 5, 26, 3, ramp, 203)
	K.hline(im, 1, 8, 26, ramp[0])
	for lx in [3, 22]:
		K.rect(im, lx, 9, 3, 3, ramp[1])
		K.px(im, lx, 12, ramp[0])
		K.px(im, lx + 1, 12, ramp[0])
	K.outline(im)
	return im


## A wooden tub full of flowers: staves with a lit edge, iron hoops, dark soil,
## leaf clumps, and blooms in clusters of two to four pixels.
func planter() -> Image:
	var im := K.make(18, 20)
	K.shadow(im, 9.0, 18.0, 7.0, 1.6, 0.3)
	var ramp := _ramp5(Color("9a6c44"))
	for by in 9:
		for xx in 12:
			var idx := 2
			if xx <= 1:
				idx = 4
			elif xx >= 10:
				idx = 0
			if xx % 3 == 0 and xx > 0:
				idx = 1
			if by == 8:
				idx = 0
			K.px(im, 3 + xx, 9 + by, ramp[idx])
	for hoop_y in [10, 15]:
		K.hline(im, 3, hoop_y, 12, Color("5a5a62"))
		K.px(im, 4, hoop_y, Color("8a8a92"))
	K.rect(im, 2, 7, 14, 2, Color("c4996a"))
	K.hline(im, 2, 7, 14, Color("e0b888"))
	K.hline(im, 3, 8, 12, Color("3a2418"))
	# leafy clumps spilling over the rim
	for lf in [[3, 6], [7, 5], [11, 6], [14, 7]]:
		K.ellipse(im, lf[0] + 0.5, lf[1] + 0.5, 2.2, 1.6, Color("3f7a3a"))
		K.px(im, lf[0], lf[1] - 1, Color("7ab860"))
	# blooms in clusters
	for f in [[4, 3, "e04a6a"], [8, 2, "f2d25c"], [12, 3, "b06ad0"], [6, 5, "f2ecd6"], [10, 5, "e04a6a"], [14, 4, "f2d25c"], [2, 4, "b06ad0"], [16, 5, "e8704a"]]:
		var col := Color(f[2])
		K.rect(im, f[0] - 1, f[1] - 1, 3, 2, col)
		K.px(im, f[0] - 1, f[1] - 1, col.lightened(0.3))
		K.px(im, f[0], f[1] - 1, col.lightened(0.15))
		K.px(im, f[0] + 1, f[1], col.darkened(0.25))
	K.outline(im)
	return im


## A round patio table under a striped umbrella, with two chairs.
func patio_table() -> Image:
	var im := K.make(28, 34)
	K.shadow(im, 14.0, 31.0, 11.0, 2.2, 0.3)
	K.rect(im, 13, 14, 2, 17, Color("5a3a22"))
	K.vline(im, 13, 14, 17, Color("9a6c44"))
	for chair in [[2, 25], [22, 25]]:
		_slat(im, chair[0], chair[1], 4, 2, _ramp5(Color("8a6440")), 210 + chair[0])
		K.rect(im, chair[0], chair[1] + 2, 4, 4, Color("6e4a2e"))
	# the table top: a lit disc with a dark rim and a foot
	K.ellipse(im, 14.0, 26.0, 8.0, 2.8, Color("6e4a2e"))
	K.ellipse(im, 14.0, 25.4, 7.4, 2.2, Color("c8945e"))
	K.hline(im, 9, 24, 8, Color("e0b888"))
	K.ellipse(im, 14.0, 31.0, 4.0, 1.2, Color("5a3a22"))
	# umbrella canopy, lit on the upper left with a shaded underside
	_umbrella(im, 14.0, 13.0, 12.0, 7.0, Color("d8442a"), Color("f2ecd6"))
	K.px(im, 13, 15, Color("5a3a22"))
	K.outline(im)
	return im


## Warm bulbs strung between two poles, sagging in the middle. Drawn over
## everything, so it hangs above the people walking under it.
func string_lights(w: int) -> Image:
	var im := K.make(w, 16)
	for x in w:
		var t := float(x) / (w - 1)
		var sag := int(sin(t * PI) * 7.0)
		K.px(im, x, 2 + sag, Color("3a2c22"))
		if x % 10 == 5:
			K.px(im, x, 4 + sag, Color("ffe07a"))
			K.px(im, x, 5 + sag, Color("ffc850"))
			K.px(im, x - 1, 4 + sag, Color(1, 0.86, 0.4, 0.45))
			K.px(im, x + 1, 4 + sag, Color(1, 0.86, 0.4, 0.45))
			K.px(im, x, 3 + sag, Color("fff4c0"))
	K.outline(im, Color(0.16, 0.12, 0.1, 0.55))
	return im


## A cast-iron lamp post with a caged lantern: a warm glass, a lit cap, a
## flared base, and a soft halo around the glass.
func lamp_post() -> Image:
	var im := K.make(12, 34)
	K.shadow(im, 6.0, 31.0, 4.0, 1.4, 0.3)
	var iron := _ramp5(Color("3a4440"))
	for yy in 20:
		K.rect(im, 5, 10 + yy, 1, 1, iron[3])
		K.rect(im, 6, 10 + yy, 1, 1, iron[1])
	K.rect(im, 3, 30, 6, 2, iron[2])
	K.hline(im, 3, 30, 6, iron[4])
	K.rect(im, 2, 32, 8, 1, iron[0])
	# the halo, then the cage and glass
	for hy in range(3, 10):
		K.px(im, 1, hy, Color(1, 0.85, 0.4, 0.2))
		K.px(im, 10, hy, Color(1, 0.85, 0.4, 0.2))
	K.rect(im, 2, 3, 8, 8, iron[1])
	K.rect(im, 3, 4, 6, 6, Color("ffe08a"))
	K.rect(im, 4, 5, 4, 3, Color("fff4c0"))
	K.vline(im, 3, 4, 6, Color("ffd060"))
	K.hline(im, 3, 4, 6, iron[4])
	K.rect(im, 2, 3, 8, 1, iron[4])
	K.rect(im, 1, 1, 10, 2, iron[2])
	K.hline(im, 1, 1, 10, iron[4])
	K.px(im, 5, 0, iron[1])
	K.px(im, 6, 0, iron[1])
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
	_planks(im, 3, wall_top, w - 6, h - wall_top - 6, PLANK_BASE if variant == 0 else Color("8f6a48"), 171 + variant, 4)
	_foundation(im, w, h, 5, 172 + variant)
	_shingles(im, 0, 2, w, roof_h - 1, _ramp5(GREEN_BASE if variant == 0 else BROWN_BASE), 173 + variant, 0.26)
	mat.eave(im, 0, wall_top - 2, w)
	mat.plank_door(im, 11, h - 6, 13, 174, 9)
	_window(im, w - 18, wall_top + 5, 8, 8, K.hash2(variant, 9, 9) < 0.6, 175)
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
