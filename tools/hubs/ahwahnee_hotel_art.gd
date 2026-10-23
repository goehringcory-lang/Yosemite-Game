extends RefCounted
## Pixel art for The Ahwahnee: the hotel itself (after Gilbert Stanley Underwood's
## 1927 design: granite ground story, stained-timber upper stories, the tall
## Great Lounge windows, a painted beam band, low shingle roofs, big stone
## chimneys, and a porte-cochere), plus its entrance sign, gate piers, and
## wrought-iron lamp. Drawn in code with PixelKit's helpers. Every material is a
## short tone ramp (granite, timber, stucco, shingle, glass) shaded from the
## upper left, with ordered-dither ambient occlusion under eaves and balconies.
## Replace any PNG with hand-drawn art of the same size at any time.
##
## ## Contract
## Written to assets/sprites/ahwahnee/, all RGBA, bottom-center anchored:
##   hotel.png             448x208  the whole hotel (front wall facing the viewer)
##   hotel_glow.png        448x208  lit windows, doorway and lanterns as soft warm
##                                  glows (additive layer for dusk), aligned to hotel.png
##   entrance_sign.png      52x32   boulders and timber sign reading THE AHWAHNEE
##   gate_post_a.png        16x40   stone gate pier with a lit iron lantern
##   gate_post_b.png        16x40   variant pier, lantern unlit
##   lamp_wrought.png       10x36   wrought-iron lamp post
##   lamp_wrought_glow.png  10x36   its glow (additive layer)
## The constants below say where things are inside hotel.png.

const K = preload("res://tools/hubs/pixel_kit.gd")
const DIR := "res://assets/sprites/ahwahnee/"

const HOTEL_SIZE := Vector2i(448, 208)
## Center of the front doors, from the sprite's left edge. The doors' bottom is at
## sprite y = HOTEL_DOOR_BOTTOM, and three steps lead down to y = 204.
const HOTEL_DOOR_X := 178
const HOTEL_DOOR_BOTTOM := 198
## The building's footprint on the ground: nothing walks into it.
const HOTEL_BODY := Rect2(2, 170, 444, 33)
## Where the building meets the ground (bottom of the steps). Put the sprite's y-sort
## origin here, not at the bottom edge, so the player stands in front of the doors.
const HOTEL_GROUND_Y := 204
## Center of the porte-cochere.
const HOTEL_PORTICO_X := 178

const BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

var granite: Array[Color] = []
var timber: Array[Color] = []
var stucco: Array[Color] = []
var roof: Array[Color] = []
var moss: Array[Color] = []
var warm: Array[Color] = []
var sky: Array[Color] = []
var leaf: Array[Color] = []
var iron: Array[Color] = []
## Glass rectangles that glow at dusk: [Rect2i, strength 0..1].
var windows: Array = []
## Copy of each window's glass as first drawn, and the finished hotel, so the
## glow skips glass that later drawing covered.
var glass_snap: Image
var hotel_final: Image
## Extra glow points: [Vector3i(x, y, radius), strength].
var lamps: Array = []


func _init() -> void:
	granite = _ramp(["3a342f", "544d46", "70685e", "8d8478", "a99f90", "c4b9a6", "dcd1bc"])
	timber = _ramp(["2c1b12", "47301f", "5e3d26", "7a4f31", "946540", "b08052"])
	stucco = _ramp(["6f5a40", "86704f", "9c8562", "b09b77", "c5b08a"])
	roof = _ramp(["2a2a22", "3a3c2c", "4d5238", "62684a", "7b815b", "989d76"])
	moss = _ramp(["45593a", "587040", "728a4a"])
	warm = _ramp(["3a2214", "5c351a", "82491f", "aa6428", "cf8534", "eea24a", "fcc768", "ffe6a0"])
	sky = _ramp(["4a5c6c", "64798b", "8499a8", "a8bac4", "cad7dc"])
	leaf = _ramp(["203a26", "2e5030", "406c38", "5c8a42", "80ac55", "a8cc72"])
	iron = _ramp(["1e1a1a", "2e2929", "48403c", "6b625b"])


static func _ramp(hexes: Array) -> Array[Color]:
	var out: Array[Color] = []
	for h in hexes:
		out.append(Color(h))
	return out


static func at(r: Array[Color], t: float) -> Color:
	return r[clampi(roundi(t * (r.size() - 1)), 0, r.size() - 1)]


func save_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	windows.clear()
	lamps.clear()
	var hotel_im := hotel()
	var glow_im := hotel_glow()
	var sheets := {
		"hotel": hotel_im, "hotel_glow": glow_im,
		"entrance_sign": entrance_sign(),
		"gate_post_a": gate_post(0), "gate_post_b": gate_post(1),
		"lamp_wrought": lamp(false), "lamp_wrought_glow": lamp(true),
	}
	for sprite_name: String in sheets:
		(sheets[sprite_name] as Image).save_png(ProjectSettings.globalize_path(DIR + sprite_name + ".png"))


# ---------------------------------------------------------------- helpers

static func vnoise(x: float, y: float, seed_value: int) -> float:
	var xi := floori(x)
	var yi := floori(y)
	var fx := x - xi
	var fy := y - yi
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := K.hash2(xi, yi, seed_value)
	var b := K.hash2(xi + 1, yi, seed_value)
	var c := K.hash2(xi, yi + 1, seed_value)
	var d := K.hash2(xi + 1, yi + 1, seed_value)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


## Mixes [param col] into an existing opaque pixel, leaving transparent ones alone.
static func tint_px(im: Image, x: int, y: int, col: Color, amount: float) -> void:
	if x < 0 or y < 0 or x >= im.get_width() or y >= im.get_height():
		return
	var p := im.get_pixel(x, y)
	if p.a < 0.5:
		return
	var m := p.lerp(col, amount)
	m.a = p.a
	im.set_pixel(x, y, m)


## Ordered-dither shading: coverage runs from [param cov0] to [param cov1] across
## the rectangle; covered pixels are pulled toward [param col] by [param strength].
static func shade(im: Image, x: int, y: int, w: int, h: int, col: Color, cov0: float, cov1: float, strength := 0.35, vertical := true) -> void:
	for yy in h:
		for xx in w:
			var t := float(yy) / maxi(1, h - 1) if vertical else float(xx) / maxi(1, w - 1)
			var cov := lerpf(cov0, cov1, t)
			var b := (BAYER[((y + yy) & 3) * 4 + ((x + xx) & 3)] + 0.5) / 16.0
			if cov > b:
				tint_px(im, x + xx, y + yy, col, strength)


static func fill_if(im: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	K.rect(im, x, y, w, h, col)


## A 1 px light line and a 1 px dark line, for beveled edges.
static func bevel(im: Image, x: int, y: int, w: int, h: int, light: Color, dark: Color) -> void:
	K.hline(im, x, y, w, light)
	K.vline(im, x, y, h, light)
	K.hline(im, x, y + h - 1, w, dark)
	K.vline(im, x + w - 1, y, h, dark)


# ---------------------------------------------------------------- materials

## One cut granite block: lit top and left edges, shadowed bottom and right,
## chisel speckle, and the odd pit.
func _block(im: Image, x: int, y: int, w: int, h: int, tone: float, sd: int) -> void:
	for by in h:
		for bx in w:
			var t := tone
			if by == 0:
				t += 0.2
			elif by >= h - 1:
				t -= 0.22
			if bx == 0:
				t += 0.12
			elif bx >= w - 1:
				t -= 0.16
			var n := K.hash2(x + bx, y + by, sd)
			t += (n - 0.5) * 0.16
			if n < 0.05:
				t -= 0.2
			t += (0.5 - float(bx) / w) * 0.1 + (0.5 - float(by) / h) * 0.08
			K.px(im, x + bx, y + by, granite[1 + clampi(roundi(t * 5.0), 0, 5)])
	# lichen and moss
	if K.hash2(x, y, sd + 11) < 0.12 and w > 6:
		var lx := x + 1 + int(K.hash2(x, y, sd + 12) * (w - 4))
		var ly := y + int(K.hash2(x, y, sd + 13) * 2.0)
		var lc := Color("a8a862") if K.hash2(x, y, sd + 14) < 0.6 else Color("c9924a")
		for i in 5:
			K.px(im, lx + int(K.hash2(i, x, sd) * 3.0), ly + int(K.hash2(i, y, sd) * 2.0), lc)


## Rough-cut ashlar: courses of varying height, blocks of varying length.
## [param bias] lightens or darkens the whole wall (0..1, 0.5 is middle).
func stone_wall(im: Image, x: int, y: int, w: int, h: int, sd: int, bias := 0.5, course_min := 5, course_var := 4, moss_base := true) -> void:
	K.rect(im, x, y, w, h, granite[0])
	var row_y := 0
	var ri := 0
	while row_y < h:
		var rh := course_min + int(K.hash2(ri, sd, 1) * course_var)
		if h - row_y - rh < 4:
			rh = h - row_y
		var sx := -int(K.hash2(ri, sd, 2) * 10.0)
		while sx < w:
			var sw := 9 + int(K.hash2(sx + 77, ri, sd) * 12.0)
			var x0 := maxi(sx, 0)
			var x1 := mini(sx + sw - 1, w)
			if x1 - x0 > 2:
				var tone := bias + (K.hash2(sx, ri, sd + 3) - 0.5) * 0.36
				_block(im, x + x0, y + row_y, x1 - x0, rh - 1, tone, sd + sx * 3 + ri)
			sx += sw
		row_y += rh
		ri += 1
	if moss_base:
		for xx in w:
			var depth := int(K.hash2(xx, sd, 21) * 4.0 * vnoise(xx * 0.15, 0.0, sd))
			for k in depth:
				K.px(im, x + xx, y + h - 1 - k, moss[clampi(k + int(K.hash2(xx, k, sd) * 2.0), 0, 2)].darkened(0.1))


## Vertical timber post, 3 px wide: lit left, shaded right, grain streaks.
func post(im: Image, x: int, y: int, h: int, sd: int, w := 3) -> void:
	for yy in h:
		for i in w:
			var idx := 4 if i == 0 else (1 if i == w - 1 else 3)
			var n := K.hash2(x + i, y + yy, sd)
			if n < 0.1:
				idx -= 1
			elif n > 0.92:
				idx += 1
			K.px(im, x + i, y + yy, timber[clampi(idx, 0, 5)])


## Horizontal beam, 3 px tall, with an AO shadow underneath.
func beam(im: Image, x: int, y: int, w: int, sd: int, h := 3) -> void:
	for xx in w:
		for i in h:
			var idx := 4 if i == 0 else (1 if i == h - 1 else 3)
			var n := K.hash2(x + xx, y + i, sd)
			if n < 0.1:
				idx -= 1
			elif n > 0.93:
				idx += 1
			K.px(im, x + xx, y + i, timber[clampi(idx, 0, 5)])
	shade(im, x, y + h, w, 3, timber[0], 1.0, 0.0, 0.4)


## Stained-concrete panels with timber posts and story beams.
func timber_wall(im: Image, x: int, y: int, w: int, h: int, sd: int, pitch := 16, story_h := 19, x_off := 0) -> void:
	for yy in h:
		for xx in w:
			var streak := K.hash2(x + xx, 0, sd + 1)
			var n := K.hash2(x + xx, y + yy, sd)
			var blotch := vnoise((x + xx) * 0.08, (y + yy) * 0.05, sd + 3)
			var t := 0.48 + (streak - 0.5) * 0.24 + (n - 0.5) * 0.16 + (blotch - 0.5) * 0.3
			t += (0.5 - float(yy) / h) * 0.06
			K.px(im, x + xx, y + yy, stucco[clampi(roundi(t * 4.0), 0, 4)])
	var px_ := x_off
	while px_ + 3 <= w:
		post(im, x + px_, y, h, sd + px_)
		px_ += pitch
	var by := 0
	while by <= h - 3:
		beam(im, x, y + by, w, sd + by)
		by += story_h


## Rafter tails under an eave.
func eave(im: Image, x: int, y: int, w: int) -> void:
	K.hline(im, x, y, w, timber[1])
	K.hline(im, x, y + 1, w, timber[2])
	for tx in range(x + 2, x + w - 2, 6):
		K.rect(im, tx, y + 1, 2, 2, timber[4])
		K.px(im, tx + 1, y + 2, timber[0])
	shade(im, x, y + 3, w, 7, timber[0], 1.0, 0.0, 0.42)


# ---------------------------------------------------------------- roofs

func shingle_col(gx: int, gy: int, sd: int, lit: float) -> Color:
	var ch := 4
	var ci := gy / ch
	var inrow := gy % ch
	var off := (ci % 2) * 3
	var shi := (gx + off) / 6
	var n := K.hash2(shi, ci, sd)
	var t := 0.3 + n * 0.5 + lit
	var col := roof[clampi(roundi(t * 5.0), 0, roof.size() - 1)]
	var mo := vnoise(gx * 0.11, gy * 0.13, sd + 7)
	if mo > 0.66 and n > 0.3:
		col = moss[clampi(roundi((mo - 0.66) * 8.0 + n - 0.4), 0, 2)]
	elif n < 0.13:
		col = Color("74674a") if n < 0.09 else Color("5c5238")
	if inrow == ch - 1:
		col = col.darkened(0.34)
	elif inrow == 0:
		col = col.lightened(0.06)
	if (gx + off) % 6 == 5 and inrow < ch - 1:
		col = col.darkened(0.18)
	if K.hash2(gx, gy, sd + 2) > 0.94:
		col = col.lightened(0.1)
	# hue shift: sunlit shingles warm toward ochre, shaded ones cool toward slate
	if lit > 0.02 and col.a > 0.5:
		col = col.lerp(Color("9c8a4a"), minf(0.3, lit * 1.5))
	elif lit < -0.04 and col.a > 0.5:
		col = col.lerp(Color("2b3040"), minf(0.3, -lit * 2.0))
	return col


## A hipped shingle roof seen from above: tapered toward the ridge, with a lit
## left hip, shaded right hip, and a fascia at the eave.
func shingle_roof(im: Image, x: int, y: int, w: int, h: int, sd: int, taper := 0.3) -> void:
	for row in h:
		var inset := int((h - 1 - row) * taper)
		var lit := 0.14 - float(row) / h * 0.22
		for sx in range(x + inset, x + w - inset):
			var col := shingle_col(sx - x, row, sd, lit)
			if sx == x + inset:
				col = col.lightened(0.3)
			elif sx == x + w - inset - 1:
				col = col.darkened(0.42)
			K.px(im, sx, y + row, col)
	var ridge_inset := int((h - 1) * taper)
	K.hline(im, x + ridge_inset, y, w - ridge_inset * 2, roof[5].lightened(0.25))
	K.hline(im, x + ridge_inset + 1, y + 1, w - ridge_inset * 2 - 2, roof[4].lightened(0.08))
	K.hline(im, x, y + h - 1, w, timber[0])
	K.hline(im, x, y + h - 2, w, roof[0])


## A cross gable facing the viewer: a shingled roof band chevron over a timber
## triangle with bargeboards, a king post, and a lit attic window.
func gable(im: Image, cx: int, base_y: int, half_w: int, apex_h: int, depth: int, sd: int, lit_win := true, win_w := 6) -> void:
	# roof slopes: the band above each sloping edge
	for x in range(cx - half_w, cx + half_w + 1):
		var edge := base_y - apex_h + int(absf(x - cx) * apex_h / float(half_w))
		var left := x < cx
		for y in range(edge - depth, edge):
			var lit := 0.12 if left else -0.14
			var col := shingle_col(x - cx + 200, y - (edge - depth), sd, lit)
			if y == edge - depth:
				col = col.lightened(0.25) if left else col.darkened(0.2)
			K.px(im, x, y, col)
	K.vline(im, cx, base_y - apex_h - depth, depth, roof[5].lightened(0.2))
	# face
	for x in range(cx - half_w, cx + half_w + 1):
		var edge := base_y - apex_h + int(absf(x - cx) * apex_h / float(half_w))
		for y in range(edge, base_y):
			var n := K.hash2(x, y, sd + 5)
			var t := 0.42 + n * 0.2 + float(y - edge) / apex_h * -0.06
			if (x - cx + 100) % 4 == 0:
				t -= 0.16
			K.px(im, x, y, stucco[clampi(roundi(t * 4.0), 0, 4)])
	# bargeboards
	for x in range(cx - half_w, cx + half_w + 1):
		var edge := base_y - apex_h + int(absf(x - cx) * apex_h / float(half_w))
		var left := x < cx
		K.px(im, x, edge, timber[4] if left else timber[2])
		K.px(im, x, edge + 1, timber[3] if left else timber[1])
		K.px(im, x, edge + 2, timber[1] if left else timber[0])
	# king post, struts, tie beam
	K.vline(im, cx, base_y - apex_h + 3, apex_h - 3, timber[3])
	for i in 6:
		var sx := int(i * half_w * 0.7 / 6.0)
		var sy := int(i * apex_h * 0.6 / 6.0)
		K.px(im, cx - 2 - sx, base_y - 3 - sy, timber[2])
		K.px(im, cx + 2 + sx, base_y - 3 - sy, timber[1])
	K.hline(im, cx - half_w, base_y - 2, half_w * 2 + 1, timber[2])
	K.hline(im, cx - half_w, base_y - 1, half_w * 2 + 1, timber[1])
	if lit_win and apex_h >= 12:
		var wy := base_y - apex_h + int(apex_h * 0.5)
		window(im, cx - win_w / 2, wy, win_w, mini(7, apex_h / 2 + 1), K.hash2(cx, base_y, sd) < 0.6, sd)
	shade(im, cx - half_w, base_y - 6, half_w * 2, 6, timber[0], 0.0, 0.7, 0.35)


func chimney(im: Image, x: int, top: int, h: int, sd: int) -> void:
	stone_wall(im, x, top, 12, h, sd, 0.55, 5, 3, false)
	shade(im, x + 6, top, 6, h, granite[0], 0.0, 0.8, 0.4, false)
	# coping and flue pots
	K.rect(im, x - 1, top - 2, 14, 3, granite[3])
	K.hline(im, x - 1, top - 2, 14, granite[6])
	K.hline(im, x - 1, top, 14, granite[1])
	K.rect(im, x + 2, top - 5, 3, 3, Color("8a5a3c"))
	K.rect(im, x + 7, top - 5, 3, 3, Color("7a4a30"))
	K.hline(im, x + 2, top - 5, 3, Color("b47a52"))
	K.hline(im, x + 7, top - 5, 3, Color("a06a44"))
	# saddle shadow where it meets the roof
	shade(im, x - 2, top + h - 4, 16, 4, roof[0], 0.0, 1.0, 0.5)


# ---------------------------------------------------------------- openings

## Records glass that glows at dusk.
func _register(im: Image, rect: Rect2i, strength: float) -> void:
	windows.append([rect, strength])
	if glass_snap == null or glass_snap.get_size() != im.get_size():
		glass_snap = K.make(im.get_width(), im.get_height())
	for yy in range(rect.position.y, rect.end.y):
		for xx in range(rect.position.x, rect.end.x):
			glass_snap.set_pixel(xx, yy, im.get_pixel(xx, yy))


## An ordinary sash window: frame, mullions, sky-reflecting or lit glass, sill.
func window(im: Image, x: int, y: int, w: int, h: int, lit: bool, sd: int) -> void:
	K.rect(im, x - 1, y - 1, w + 2, h + 2, timber[0])
	K.hline(im, x - 1, y - 1, w + 2, timber[2])
	for gy in h:
		for gx in w:
			var col: Color
			var v := float(gy) / maxi(1, h - 1)
			if lit:
				col = warm[clampi(roundi((0.85 - v * 0.55) * 7.0 + (K.hash2(gx, gy, sd) - 0.5) * 1.2), 1, 7)]
			else:
				col = sky[clampi(roundi((0.8 - v * 0.8) * 4.0 + (K.hash2(gx, gy, sd) - 0.5) * 1.0), 0, 4)].darkened(0.1 + v * 0.15)
			if (gx + gy) % 6 == 1 and gy < h - 3:
				col = col.lightened(0.16)
			K.px(im, x + gx, y + gy, col)
	if lit and w >= 8 and K.hash2(x, y, sd + 40) < 0.4:
		K.vline(im, x, y + 1, h - 2, Color("e8d8b0"))
		K.vline(im, x + w - 1, y + 1, h - 2, Color("d8c498"))
		K.px(im, x + 1, y + 1, Color("e8d8b0"))
		K.px(im, x + w - 2, y + 1, Color("d8c498"))
	if w >= 5:
		K.vline(im, x + w / 2, y, h, timber[1])
	if h >= 6:
		K.hline(im, x, y + h / 2, w, timber[1])
	K.hline(im, x, y, w, timber[0].lerp(warm[3] if lit else sky[1], 0.3))
	K.rect(im, x - 2, y + h + 1, w + 4, 1, granite[5])
	K.hline(im, x - 2, y + h + 2, w + 4, timber[0])
	shade(im, x - 1, y + h + 3, w + 2, 3, timber[0], 1.0, 0.0, 0.4)
	_register(im, Rect2i(x, y, w, h), 1.0 if lit else 0.55 + K.hash2(x, y, sd) * 0.45)


## A Great Lounge window: two stories tall, divided panes, warm interior with
## chandeliers, and a sky reflection across the upper panes.
func tall_window(im: Image, x: int, y: int, w: int, h: int, sd: int, round_top := true) -> void:
	# stone reveal and frame
	K.rect(im, x - 2, y - 2, w + 4, h + 3, granite[1])
	K.rect(im, x - 1, y - 1, w + 2, h + 1, timber[0])
	var gw := w
	var gh := h
	for gy in gh:
		for gx in gw:
			if round_top and gy < 2 and (gx < 2 - gy or gx >= gw - (2 - gy)):
				K.px(im, x + gx, y + gy, timber[0])
				continue
			var v := float(gy) / gh
			var t := 0.28 + (1.0 - v) * 0.5 + (K.hash2(gx, gy, sd) - 0.5) * 0.12
			# chandeliers glow near the top; dark furniture and floor at the bottom
			var d1 := Vector2(gx - gw * 0.5, gy - gh * 0.16).length()
			t += maxf(0.0, 1.0 - d1 / 5.0) * 0.4
			var d2 := Vector2(gx - gw * 0.5, gy - gh * 0.42).length()
			t += maxf(0.0, 1.0 - d2 / 4.0) * 0.18
			if gy > gh * 0.86:
				t -= 0.3
			if gy > gh * 0.8 and (gx / 3) % 2 == 0:
				t -= 0.1
			var col := warm[clampi(roundi(t * 7.0), 0, 7)]
			# sky reflection: a pale diagonal band, stronger in the transom
			var diag := (gx * 1.0 + gy * 0.55)
			var band := fmod(diag, 26.0)
			if band < 6.0:
				col = col.lerp(sky[clampi(roundi(3.0 - band * 0.2), 0, 4)], 0.42 if gy < gh * 0.3 else 0.24)
			K.px(im, x + gx, y + gy, col)
	# transom bar, muntins, mullions
	K.hline(im, x, y + int(gh * 0.3), gw, timber[1])
	K.hline(im, x, y + int(gh * 0.3) - 1, gw, timber[3])
	var rows := 5
	for r in range(1, rows):
		var ry := y + int(gh * 0.3) + int(r * gh * 0.7 / rows)
		K.hline(im, x, ry, gw, timber[1])
	K.vline(im, x + gw / 2, y, gh, timber[1])
	K.vline(im, x + gw / 2 - 1, y, gh, timber[3])
	for r in 3:
		K.vline(im, x + int((r + 1) * gw / 4.0), y, int(gh * 0.3), timber[1])
	# sill
	K.rect(im, x - 3, y + gh, gw + 6, 2, granite[5])
	K.hline(im, x - 3, y + gh + 1, gw + 6, granite[2])
	_register(im, Rect2i(x, y, gw, gh), 1.0)


func balcony(im: Image, cx: int, y: int, w: int) -> void:
	var x := cx - w / 2
	# rail seen against the wall: top rail, balusters
	K.hline(im, x, y - 5, w, timber[4])
	K.hline(im, x, y - 4, w, timber[2])
	for bx in range(x + 1, x + w - 1, 3):
		K.vline(im, bx, y - 3, 3, timber[3])
		K.px(im, bx, y - 3, timber[4])
	# floor slab
	K.hline(im, x - 1, y, w + 2, timber[4])
	K.rect(im, x - 1, y + 1, w + 2, 2, timber[2])
	K.hline(im, x - 1, y + 3, w + 2, timber[0])
	shade(im, x - 1, y + 4, w + 2, 4, timber[0], 1.0, 0.0, 0.45)


# ---------------------------------------------------------------- painted band

## The painted beam band: stepped diamonds in ochre, rust, and cream between
## turquoise bowties, on dark stained wood.
## The pattern follows the hotel's painted beams (tribal review passed).
func native_band(im: Image, x: int, y: int, w: int, sd: int) -> void:
	var motif := [
		".....OO.....",
		"....OOOO....",
		"T..OORROO..T",
		"TT.ORRCCRO.TT",
		"TT.ORRCCRO.TT",
		"T..OORROO..T",
		"....OOOO....",
		".....OO.....",
	]
	var pal := {
		"O": Color("d9a23e"), "R": Color("b0492a"), "C": Color("eee2c0"),
		"T": Color("3ca59a"), "K": Color("221710"),
	}
	# dark stained ground with grain
	for yy in 10:
		for xx in w:
			var idx := 0 if K.hash2(x + xx, yy, sd) > 0.15 else 1
			K.px(im, x + xx, y + yy, timber[idx].darkened(0.1))
	for xx in w:
		var u := xx % 12
		K.px(im, x + xx, y, pal["O"] if (xx / 2) % 2 == 0 else pal["R"])
		K.px(im, x + xx, y + 9, pal["R"] if (xx / 2) % 2 == 0 else pal["O"])
		for r in 8:
			var row: String = motif[r]
			var ch := row[u] if u < row.length() else "."
			if ch != ".":
				K.px(im, x + xx, y + 1 + r, pal[ch])
	# painted colors sit a little dulled and catch a lit top edge
	shade(im, x, y, w, 10, timber[0], 0.0, 0.35, 0.22)
	beam(im, x, y - 2, w, sd + 3, 2)
	K.hline(im, x, y + 10, w, timber[0])
	shade(im, x, y + 11, w, 4, timber[0], 1.0, 0.0, 0.4)


# ---------------------------------------------------------------- landscaping

func shrub(im: Image, cx: int, base_y: int, r: int, sd: int, flowers := false) -> void:
	K.shadow(im, cx, base_y, r * 1.1, 2.0, 0.3)
	for i in r * 3:
		var ang := K.hash2(i, sd, 1) * TAU
		var rad := K.hash2(i, sd, 2) * r * 0.55
		var bx := cx + cos(ang) * rad
		var by := base_y - r * 0.7 + sin(ang) * rad * 0.7
		var br := 2.0 + K.hash2(i, sd, 3) * r * 0.32
		for yy in range(floori(by - br), ceili(by + br) + 1):
			for xx in range(floori(bx - br), ceili(bx + br) + 1):
				var dx := (xx + 0.5 - bx) / br
				var dy := (yy + 0.5 - by) / br
				if dx * dx + dy * dy > 1.0:
					continue
				var lit := -dx * 0.5 - dy * 0.75 + (K.hash2(xx, yy, sd) - 0.5) * 0.5
				var idx := clampi(roundi(2.0 + lit * 2.6), 0, 5)
				K.px(im, xx, yy, leaf[idx])
	if flowers:
		for i in r:
			var fx := cx - r + int(K.hash2(i, sd, 8) * r * 2.0)
			var fy := base_y - r + int(K.hash2(i, sd, 9) * r * 1.2)
			# blooms come in small clumps of two, a few of them gold
			var fl := Color("f2c6d4") if K.hash2(i, sd, 10) < 0.5 else Color("f6f0e0")
			if K.hash2(i, sd, 11) < 0.2:
				fl = Color("f2c24a")
			K.px(im, fx, fy, fl)
			K.px(im, fx + 1, fy, fl.darkened(0.12))


## A tall, narrow evergreen shrub.
func _juniper(im: Image, cx: int, base_y: int, sd: int) -> void:
	K.shadow(im, cx, base_y, 5.0, 1.8, 0.3)
	for y in range(base_y - 17, base_y):
		var t := float(y - (base_y - 17)) / 17.0
		var half := 1.5 + t * 4.0 + (K.hash2(y, sd, 1) - 0.5) * 1.6
		for x in range(int(cx - half), int(cx + half) + 1):
			var lit := -(x - cx) / maxf(half, 1.0) * 0.6 + (0.5 - t) * 0.5 + (K.hash2(x, y, sd) - 0.5) * 0.7
			K.px(im, x, y, leaf[clampi(roundi(2.0 + lit * 2.2), 0, 4)].darkened(0.08))


# ---------------------------------------------------------------- wings

## A recessed wing or pavilion: timber stories over a stone ground story.
## kind: 0 = small windows below, 1 = tall dining windows below.
func wing(im: Image, x: int, w: int, roof_y: int, roof_h: int, wall_top: int, base_y: int, stone_h: int, kind: int, sd: int, gable_cx := -1) -> void:
	var timber_h := base_y - stone_h - wall_top
	timber_wall(im, x, wall_top, w, timber_h, sd, 16, 19, 3)
	var ground_y := wall_top + timber_h
	stone_wall(im, x, ground_y, w, stone_h, sd + 9, 0.52)
	shingle_roof(im, x, roof_y, w, roof_h, sd + 4, 0.34)
	eave(im, x, wall_top, w)
	# upper windows
	var stories := timber_h / 19
	var bays := (w - 3) / 16
	for s in stories:
		for b in bays:
			var wx := x + 3 + b * 16 + 5
			var lit := K.hash2(wx, s, sd) < 0.4
			window(im, wx, wall_top + s * 19 + 6, 8, 9, lit, sd + s * 7 + b)
			if (b + s) % 3 == 1 and s > 0:
				balcony(im, wx + 4, wall_top + s * 19 + 17, 14)
	# ground story
	if kind == 1:
		var n := (w - 8) / 16
		for i in n:
			tall_window(im, x + 6 + i * 16 + 2, ground_y + 6, 10, stone_h - 14, sd + i, true)
	else:
		var n2 := (w - 8) / 20
		for i in n2:
			window(im, x + 10 + i * 20, ground_y + 12, 9, 15, K.hash2(i, sd, 4) < 0.5, sd + i)
	native_band(im, x + 2, ground_y - 12, w - 4, sd + 5)
	if gable_cx >= 0:
		gable(im, x + gable_cx, wall_top, 18, 22, 12, sd + 30)
	# recessed: cooler and a little darker, with foundation
	K.rect(im, x, base_y - 3, w, 3, granite[1])
	K.hline(im, x, base_y - 3, w, granite[3])
	for yy in range(roof_y, base_y):
		for xx in range(x, x + w):
			tint_px(im, xx, yy, Color("5c6f88"), 0.12)
			tint_px(im, xx, yy, Color("1a1420"), 0.1)


# ---------------------------------------------------------------- the hotel

func hotel() -> Image:
	var w := HOTEL_SIZE.x
	var h := HOTEL_SIZE.y
	var im := K.make(w, h)
	windows.clear()
	lamps.clear()
	glass_snap = K.make(w, h)
	var base_y := 200

	# wings and pavilions, back to front
	wing(im, 2, 54, 78, 28, 106, 190, 52, 0, 101, 27)
	wing(im, 56, 56, 64, 28, 92, 194, 46, 0, 202)
	wing(im, 392, 54, 78, 28, 106, 190, 52, 0, 303, 27)
	wing(im, 336, 56, 64, 28, 92, 194, 46, 1, 404)
	# the center block shades the wings beside it
	shade(im, 96, 92, 16, 102, Color("120e18"), 0.0, 0.7, 0.28, false)
	shade(im, 336, 92, 16, 102, Color("120e18"), 0.7, 0.0, 0.28, false)

	# ---- central block
	var cx0 := 112
	var cx1 := 336
	var cw := cx1 - cx0
	var wall_top := 52
	# upper four stories in timber
	timber_wall(im, cx0, wall_top, cw, 76, 505, 16, 19, 14)
	# stone ground story
	var ground_top := 138
	stone_wall(im, cx0, ground_top, cw, base_y - ground_top, 606, 0.56)
	# painted band and lintel
	native_band(im, cx0 + 14, 128, cw - 28, 707)
	K.rect(im, cx0, 126, cw, 2, granite[4])
	K.hline(im, cx0, 126, cw, granite[6])
	K.rect(im, cx0, 138, cw, 3, granite[4])
	K.hline(im, cx0, 138, cw, granite[6])
	K.hline(im, cx0, 140, cw, granite[1])
	shade(im, cx0, 141, cw, 5, granite[0], 1.0, 0.0, 0.45)

	# eave shadow under the main roof (before the windows so glass stays clean)
	eave(im, cx0, wall_top, cw)

	# upper windows: 12 bays of 16 px between the pylons
	for s in 4:
		for b in 12:
			var wx := cx0 + 14 + b * 16 + 3 + 5 - 3
			var wy := wall_top + s * 19 + 6
			var lit := K.hash2(b, s, 808) < 0.42
			window(im, wx, wy, 8, 9, lit, 900 + b * 13 + s)
			if s in [1, 3] and (b + s) % 2 == 0:
				balcony(im, wx + 4, wy + 11, 14)

	# Great Lounge: four tall windows to the right of the portico
	for i in 4:
		tall_window(im, 232 + i * 24, 148, 16, 46, 1000 + i, true)
	# left of the portico: two tall stair windows
	tall_window(im, 128, 154, 8, 38, 1100, true)

	# pylons at each end of the center block: full-height granite buttresses
	for side in 2:
		var px_ := cx0 if side == 0 else cx1 - 14
		stone_wall(im, px_, wall_top - 2, 14, base_y - wall_top + 2, 1200 + side, 0.6 if side == 0 else 0.48, 6, 4)
		K.rect(im, px_ - 1, wall_top - 4, 16, 3, granite[4])
		K.hline(im, px_ - 1, wall_top - 4, 16, granite[6])
		K.hline(im, px_ - 1, wall_top - 2, 16, granite[1])
		shade(im, px_, wall_top, 14, 30, granite[0], 0.5, 0.0, 0.35)

	# main roof, cross gables, dormers, chimneys
	shingle_roof(im, cx0, 10, cw, 42, 55, 0.3)
	for gcx in [158, 224, 290]:
		gable(im, gcx, wall_top, 22, 24, 15, 60 + gcx)
	for dcx in [191, 257]:
		gable(im, dcx, wall_top - 2, 10, 13, 8, 80 + dcx, true, 4)
	chimney(im, 250, 3, 36, 71)
	chimney(im, 190, 6, 32, 72)
	chimney(im, 318, 8, 30, 73)
	chimney(im, 126, 12, 28, 74)

	# foundation course and shrubs
	K.rect(im, cx0, base_y - 4, cw, 4, granite[2])
	K.hline(im, cx0, base_y - 4, cw, granite[5])
	K.hline(im, cx0, base_y - 1, cw, granite[0])

	_portico(im)

	# iron sconces on the pylons
	for sx in [cx0 + 6, cx1 - 8]:
		for sy in [96, 176]:
			K.vline(im, sx, sy - 2, 3, iron[2])
			K.rect(im, sx - 1, sy + 1, 3, 4, iron[1])
			K.rect(im, sx, sy + 2, 1, 2, warm[6])
			lamps.append([Vector3i(sx, sy + 2, 7), 1.0])

	# planting strip along the base: clumps of different shrubs with gaps
	var sd := 3000
	var sx := 12
	while sx < 436:
		if sx > 150 and sx < 206:
			sx = 206
			continue
		var kind_roll := K.hash2(sx, sd, 5)
		var r := 4 + int(K.hash2(sx, sd, 3) * 4.0)
		var by := 205 - int(K.hash2(sx, sd, 2) * 3.0)
		if kind_roll < 0.16:
			_juniper(im, sx, by, sd + sx)
			sx += 8
		else:
			shrub(im, sx, by, r, sd + sx, kind_roll > 0.6)
			sx += r + 2 + int(K.hash2(sx, sd, 6) * 8.0)
	hotel_final = im
	K.outline(im)
	hotel_final = im
	return im


## The porte-cochere: stone piers under a timber canopy and shingle roof, a
## deep doorway with double doors and amber glass, lanterns, and steps.
func _portico(im: Image) -> void:
	var cx := HOTEL_PORTICO_X
	var doorway_x := cx - 22
	var doorway_w := 44
	var top := 158
	var bottom := 198
	# recess: dark warm interior with granite jambs
	K.rect(im, doorway_x, top, doorway_w, bottom - top, Color("241810"))
	for yy in bottom - top:
		var t := float(yy) / (bottom - top)
		shade(im, doorway_x, top + yy, doorway_w, 1, warm[2], t * 0.55, t * 0.55, 0.25)
	# sidelights
	for sx in [cx - 19, cx + 14]:
		window(im, sx, top + 12, 5, 24, true, 4000 + sx)
	# double doors with amber glass
	var dx := cx - 8
	var dy := bottom - 30
	K.rect(im, dx - 2, dy - 12, 20, 43, timber[0])
	K.rect(im, dx - 1, dy - 11, 18, 42, timber[1])
	for leaf_i in 2:
		var lx := dx + leaf_i * 8
		K.rect(im, lx, dy, 8, 30, timber[3])
		K.vline(im, lx, dy, 30, timber[4])
		K.vline(im, lx + 7, dy, 30, timber[1])
		K.rect(im, lx + 1, dy + 1, 6, 15, Color("d7913a"))
		for gy in 15:
			var col := warm[clampi(6 - gy / 3, 3, 7)]
			K.hline(im, lx + 1, dy + 1 + gy, 6, col)
		K.hline(im, lx + 1, dy + 8, 6, timber[1])
		K.vline(im, lx + 3, dy + 1, 15, timber[1])
		K.rect(im, lx + 1, dy + 18, 6, 10, timber[2])
		K.rect(im, lx + 2, dy + 19, 4, 8, timber[3])
		K.px(im, lx + (6 if leaf_i == 0 else 1), dy + 17, Color("e6c060"))
	_register(im, Rect2i(dx + 1, dy + 1, 6, 15), 1.0)
	_register(im, Rect2i(dx + 9, dy + 1, 6, 15), 1.0)
	# transom above the doors, with a small pattern
	K.rect(im, dx - 1, dy - 10, 18, 9, Color("d7913a"))
	for xx in 18:
		var col := warm[clampi(5 + int(K.hash2(xx, 5, 4100) * 3.0), 3, 7)]
		K.vline(im, dx - 1 + xx, dy - 10, 9, col)
	for i in 3:
		K.vline(im, dx + 4 + i * 5, dy - 10, 9, timber[1])
	K.hline(im, dx - 1, dy - 6, 18, timber[1])
	_register(im, Rect2i(dx - 1, dy - 10, 18, 9), 1.0)
	# steps
	for s in 3:
		var sy := bottom + s * 2
		var sw := 44 + s * 8
		var sx := cx - sw / 2
		K.rect(im, sx, sy, sw, 2, granite[4 - s])
		K.hline(im, sx, sy, sw, granite[6])
		K.hline(im, sx, sy + 1, sw, granite[2])
		for xx in range(sx, sx + sw):
			if K.hash2(xx, sy, 4200) < 0.2:
				K.px(im, xx, sy, granite[5])
	shade(im, cx - 26, bottom, 52, 3, timber[0], 1.0, 0.0, 0.35)

	# piers: battered stone with a lit face and a shaded flank
	for px_ in [cx - 38, cx + 22]:
		stone_wall(im, px_ + 2, top - 6, 14, bottom - top + 10, 4300 + px_, 0.6, 6, 4)
		# batter at the foot
		stone_wall(im, px_, bottom - 10, 18, 12, 4400 + px_, 0.58, 5, 3)
		K.rect(im, px_ - 1, bottom + 2, 20, 4, granite[3])
		K.hline(im, px_ - 1, bottom + 2, 20, granite[6])
		K.hline(im, px_ - 1, bottom + 5, 20, granite[1])
		shade(im, px_ + 10, top - 6, 6, bottom - top + 10, granite[0], 0.0, 0.85, 0.4, false)
	# timber canopy beams with exposed rafter ends
	var bx0 := cx - 46
	var bw := 92
	for yy in 12:
		var idx := 4 if yy < 2 else (3 if yy < 6 else (2 if yy < 10 else 1))
		K.hline(im, bx0, 146 + yy, bw, timber[idx])
	K.hline(im, bx0, 158, bw, timber[0])
	for xx in range(bx0 + 3, bx0 + bw - 3, 7):
		K.rect(im, xx, 149, 3, 3, timber[5])
		K.px(im, xx + 1, 151, timber[2])
	# carved brackets under the beam
	for side in 2:
		var bxx := cx - 32 if side == 0 else cx + 28
		for i in 5:
			K.hline(im, bxx + (i if side == 0 else -i), 158 + i, 4 - (i / 2), timber[2 if side == 0 else 1])
	shade(im, doorway_x, 159, doorway_w, 9, timber[0], 1.0, 0.0, 0.5)
	# canopy roof
	shingle_roof(im, bx0 - 4, 122, bw + 8, 25, 4500, 0.3)
	shade(im, bx0 - 4, 146, bw + 8, 1, roof[0], 1.0, 1.0, 0.5)
	# lanterns hanging from the beam
	for lx in [cx - 28, cx + 28]:
		K.vline(im, lx, 159, 3, iron[2])
		K.rect(im, lx - 2, 162, 5, 7, iron[1])
		K.rect(im, lx - 1, 163, 3, 5, warm[6])
		K.px(im, lx, 164, warm[7])
		K.hline(im, lx - 2, 161, 5, iron[3])
		K.px(im, lx, 169, iron[2])
		_register(im, Rect2i(lx - 1, 163, 3, 5), 1.0)
		lamps.append([Vector3i(lx, 165, 9), 1.0])


func hotel_glow() -> Image:
	var im := K.make(HOTEL_SIZE.x, HOTEL_SIZE.y)
	for entry: Array in windows:
		var r: Rect2i = entry[0]
		var strength: float = entry[1]
		# some of the windows that are dark by day stay dark at dusk too
		if strength < 1.0 and K.hash2(r.position.x, r.position.y, 77) < 0.28:
			continue
		# only glass that is still visible in the finished hotel glows
		var visible := 0
		var matches := {}
		for yy in range(r.position.y, r.end.y):
			for xx in range(r.position.x, r.end.x):
				if hotel_final.get_pixel(xx, yy) == glass_snap.get_pixel(xx, yy):
					visible += 1
					matches[Vector2i(xx, yy)] = true
		var ratio := float(visible) / (r.size.x * r.size.y)
		if ratio < 0.5:
			continue
		if ratio > 0.95:
			for ring in range(3, 0, -1):
				var a := (0.10 if ring == 3 else (0.16 if ring == 2 else 0.24)) * strength
				for yy in range(r.position.y - ring, r.end.y + ring):
					for xx in range(r.position.x - ring, r.end.x + ring):
						if not r.has_point(Vector2i(xx, yy)) and hotel_final.get_pixel(xx, yy).a > 0.5:
							K.px(im, xx, yy, Color(1.0, 0.72, 0.3, a))
		for p: Vector2i in matches:
			var t := float(p.y - r.position.y) / maxi(1, r.size.y - 1)
			K.px(im, p.x, p.y, Color(1.0, 0.8 - t * 0.12, 0.38, (0.62 - t * 0.2) * strength))
	for l: Array in lamps:
		var p: Vector3i = l[0]
		for yy in range(p.y - p.z, p.y + p.z + 1):
			for xx in range(p.x - p.z, p.x + p.z + 1):
				var d := Vector2(xx - p.x, yy - p.y).length() / p.z
				if d < 1.0:
					var a3 := pow(1.0 - d, 2.0) * 0.32
					if a3 > 0.03 and BAYER[(yy & 3) * 4 + (xx & 3)] / 16.0 < a3 * 3.2:
						K.px(im, xx, yy, Color(1.0, 0.78, 0.36, minf(a3 * 1.6, 0.55)))
	return im


# ---------------------------------------------------------------- small pieces

func boulder(im: Image, cx: float, cy: float, rx: float, ry: float, sd: int) -> void:
	for yy in range(floori(cy - ry), ceili(cy + ry) + 1):
		for xx in range(floori(cx - rx), ceili(cx + rx) + 1):
			var dx := (xx + 0.5 - cx) / rx
			var dy := (yy + 0.5 - cy) / ry
			if dx * dx + dy * dy > 1.0:
				continue
			var t := 0.58 - dx * 0.3 - dy * 0.42 + (K.hash2(xx, yy, sd) - 0.5) * 0.22
			t += (vnoise(xx * 0.25, yy * 0.25, sd) - 0.5) * 0.3
			if dy > 0.55:
				t -= 0.14
			K.px(im, xx, yy, granite[1 + clampi(roundi(t * 5.0), 0, 5)])
	# lichen fleck and a crack
	for i in 5:
		K.px(im, int(cx - rx * 0.4) + i, int(cy - ry * 0.5) + (i % 2), Color("a8a862"))
	for i in int(ry * 0.6):
		K.px(im, int(cx + rx * 0.2) + i / 2, int(cy - ry * 0.3) + i, granite[1])


func entrance_sign() -> Image:
	var w := 52
	var h := 32
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 2.5, 24.0, 2.6, 0.28)
	# boulders at each end
	boulder(im, 8, h - 8, 8, 6.5, 11)
	boulder(im, 44, h - 7, 8, 6, 12)
	boulder(im, 26, h - 4, 10, 3.5, 13)
	# posts
	for px_ in [10, 39]:
		post(im, px_, 12, 17, 20 + px_, 3)
	# board with routed border, nails, and letters
	K.rect(im, 4, 3, 44, 20, timber[0])
	K.rect(im, 5, 4, 42, 18, timber[3])
	for yy in 18:
		for xx in 42:
			var n := K.hash2(xx, yy, 31)
			var streak := K.hash2(xx / 2, 0, 32)
			var idx := 3
			if n < 0.1 or streak < 0.2:
				idx = 2
			elif n > 0.92:
				idx = 4
			K.px(im, 5 + xx, 4 + yy, timber[idx])
	bevel(im, 5, 4, 42, 18, timber[4], timber[1])
	K.rect(im, 7, 6, 38, 14, timber[2])
	K.rect(im, 8, 7, 36, 12, timber[1])
	for nx in [7, 44]:
		for ny in [5, 20]:
			K.px(im, nx, ny, granite[5])
	K.text_centered(im, 8, 36, 8, "THE", Color("d9a23e"), timber[0])
	K.text_centered(im, 8, 36, 14, "AHWAHNEE", Color("f0e2bc"), timber[0])
	# small painted accent
	for i in 9:
		K.px(im, 9 + i * 4, 7, Color("b0492a") if i % 2 == 0 else Color("3ca59a"))
	K.outline(im)
	return im


func gate_post(variant: int) -> Image:
	var w := 16
	var h := 40
	var im := K.make(w, h)
	K.shadow(im, 8, h - 2, 8, 2.2, 0.3)
	# shaft
	stone_wall(im, 2, 12, 12, 25, 60 + variant * 9, 0.56, 5, 3)
	shade(im, 9, 12, 5, 25, granite[0], 0.0, 0.8, 0.4, false)
	# battered foot and cap
	stone_wall(im, 1, 33, 14, 5, 70 + variant, 0.52, 5, 2)
	K.rect(im, 0, 36, 16, 3, granite[3])
	K.hline(im, 0, 36, 16, granite[6])
	K.hline(im, 0, 38, 16, granite[1])
	K.rect(im, 0, 10, 16, 3, granite[4])
	K.hline(im, 0, 10, 16, granite[6])
	K.hline(im, 0, 12, 16, granite[1])
	# pyramid
	for i in 3:
		K.hline(im, 3 + i, 7 + i * 1 - i, 10 - i * 2, granite[5 - i])
	K.rect(im, 3, 7, 10, 3, granite[4])
	K.hline(im, 3, 7, 10, granite[6])
	# iron lantern on top
	K.rect(im, 5, 2, 6, 6, iron[1])
	K.hline(im, 4, 1, 8, iron[3])
	K.px(im, 7, 0, iron[2])
	K.px(im, 8, 0, iron[2])
	var lit := variant == 0
	K.rect(im, 6, 3, 4, 4, warm[6] if lit else Color("6a6252"))
	if lit:
		K.px(im, 7, 4, warm[7])
		K.px(im, 6, 3, warm[7])
	else:
		K.px(im, 6, 3, Color("8a8272"))
	K.outline(im)
	return im


func lamp(glow_only: bool) -> Image:
	var w := 10
	var h := 36
	var im := K.make(w, h)
	if glow_only:
		for yy in h:
			for xx in w:
				var d := Vector2(xx - 4.5, yy - 7.0).length() / 9.0
				if d < 1.0:
					var a := pow(1.0 - d, 2.0) * 0.5
					if BAYER[(yy & 3) * 4 + (xx & 3)] / 16.0 < a * 2.4:
						K.px(im, xx, yy, Color(1.0, 0.78, 0.36, minf(a * 1.4, 0.6)))
		K.rect(im, 3, 4, 4, 6, Color(1.0, 0.85, 0.5, 0.75))
		return im
	K.shadow(im, 5, h - 2, 4, 1.6, 0.3)
	# plinth
	K.rect(im, 2, 31, 6, 4, granite[4])
	K.hline(im, 2, 31, 6, granite[6])
	K.hline(im, 2, 34, 6, granite[1])
	K.rect(im, 3, 29, 4, 2, granite[3])
	# post with collars
	for yy in range(13, 30):
		K.px(im, 4, yy, iron[3])
		K.px(im, 5, yy, iron[1])
	for cy in [16, 24, 28]:
		K.hline(im, 3, cy, 4, iron[2])
	# scroll arms
	for i in 3:
		K.px(im, 3 - i, 16 - i, iron[2])
		K.px(im, 6 + i, 16 - i, iron[1])
	K.px(im, 0, 14, iron[2])
	K.px(im, 9, 14, iron[1])
	# lantern
	K.rect(im, 2, 3, 6, 9, iron[1])
	K.rect(im, 3, 4, 4, 7, warm[6])
	K.rect(im, 3, 4, 4, 2, warm[7])
	K.hline(im, 3, 9, 4, warm[5])
	K.vline(im, 4, 4, 7, iron[2])
	K.hline(im, 1, 2, 8, iron[3])
	K.hline(im, 2, 1, 6, iron[2])
	K.px(im, 4, 0, iron[3])
	K.px(im, 5, 0, iron[2])
	K.hline(im, 2, 12, 6, iron[3])
	K.outline(im)
	return im
