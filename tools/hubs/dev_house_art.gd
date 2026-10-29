extends SceneTree
## Paints the house on the hill behind the El Portal Market (an Easter egg,
## placed in scenes/story/content/el_portal.tscn) into
## assets/sprites/el_portal/dev_house.png and dev_house_glow.png. Like the
## bears it is painted at the 32px art's size, so it skips tools/art32, in
## the look of the town's buildings: chunky slate roof tiles, lit from the
## upper left, with the dark rim every sprite has.
##
##   godot --headless --path . -s res://tools/hubs/dev_house_art.gd
##   godot --headless --path . --import
##
## A sage-green clapboard cottage on a knoll of gold grass, its earth bank
## held up with rocks and climbed by stone steps to the gate of a brown
## picket fence. On the front: a bay window, and to its right the living
## room window, where someone sits at a laptop with the Valley on its screen
## (granite, pines and a river) and a mug going cold beside it. Then the
## door under a porch light, and a stone chimney.

const W := 200
const H := 188
const OUT := "res://assets/sprites/el_portal/dev_house.png"
const GLOW_OUT := "res://assets/sprites/el_portal/dev_house_glow.png"
const OUTLINE := Color("231a16")

## The wall, foundation and yard, in px from the image's top left.
const WALL := Rect2i(36, 58, 128, 50)
const FOUND_Y := 108
const YARD_TOP := 106
const BANK_TOP := 134
const BANK_BOTTOM := 182
## The bay (the front pane between its two angled sides), the living room
## window's glass, the door.
const BAY := Rect2i(46, 70, 42, 34)
const LIVING := Rect2i(100, 74, 28, 22)
const DOOR := Rect2i(140, 80, 14, 28)
const GATE := Rect2i(91, 120, 18, 14)

var roof := _ramp(["1e2128", "2c313a", "3c434e", "4f5866", "66707e", "838d9a"])
var siding := _ramp(["2e3628", "434e3a", "5a684c", "72825e", "8c9c74", "a8b68e"])
var trim := _ramp(["6e6656", "8a8270", "b0a68e", "d2c8ac", "e8e0c6"])
var wood := _ramp(["2e2016", "4a3220", "66462c", "82603a", "9c7a4c", "b8946a"])
var earth := _ramp(["3a2a1c", "523c26", "6e5232", "8a6a42", "a68656", "c0a06c"])
var grass := _ramp(["5e5a2a", "7a7436", "968e44", "b0a652", "c8bc66", "dccf7e"])
var stone := _ramp(["34383e", "484e56", "5e666e", "7a828a", "9aa2a8", "bcc2c4"])

var im: Image
var glow: Image


func _init() -> void:
	im = Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	glow = Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	_shadow()
	_knoll()
	_steps()
	_roof()
	_chimney()
	_walls()
	_bay_window()
	_living_window()
	_door()
	_fence()
	_mailbox()
	_outline()
	im.save_png(OUT)
	glow.save_png(GLOW_OUT)
	var preview := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	preview.fill(Color("b0a254"))
	preview.blend_rect(im, Rect2i(0, 0, W, H), Vector2i.ZERO)
	preview.resize(W * 4, H * 4, Image.INTERPOLATE_NEAREST)
	preview.save_png("res://docs/dev_house_preview.png")
	print("House written to %s. Run godot --headless --path . --import next." % OUT)
	quit()


static func _ramp(hexes: Array) -> Array[Color]:
	var out: Array[Color] = []
	for h: String in hexes:
		out.append(Color(h))
	return out


## A steady 0..1 noise for texture and dithering.
static func hash2(x: int, y: int, s: int) -> float:
	var n := (x * 374761393 + y * 668265263 + s * 2147483647) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float(n & 0xffff) / 65535.0


func px(x: int, y: int, c: Color, on := im) -> void:
	if x >= 0 and y >= 0 and x < W and y < H:
		on.set_pixel(x, y, c)


func rect(x: int, y: int, w: int, h: int, c: Color, on := im) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			px(xx, yy, c, on)


func hline(x: int, y: int, w: int, c: Color) -> void:
	rect(x, y, w, 1, c)


func vline(x: int, y: int, h: int, c: Color) -> void:
	rect(x, y, 1, h, c)


## Darkens what's already painted, for cast shadows.
func shade(x: int, y: int, w: int, h: int, amount: float) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if xx >= 0 and yy >= 0 and xx < W and yy < H and im.get_pixel(xx, yy).a > 0.5:
				im.set_pixel(xx, yy, im.get_pixel(xx, yy).darkened(amount))


func _shadow() -> void:
	for y in range(BANK_BOTTOM - 4, H):
		for x in W:
			var dx := (x + 0.5 - W / 2.0) / (W / 2.0 - 2.0)
			var dy := (y + 0.5 - (BANK_BOTTOM + 1.0)) / 5.0
			if dx * dx + dy * dy <= 1.0:
				px(x, y, Color(0.1, 0.07, 0.04, 0.32))


## The half-width of the knoll at row [param y]: its top is an oval of yard,
## its earth bank flares a little toward the bottom.
func _knoll_half(y: int) -> float:
	if y < BANK_TOP:
		var t := float(BANK_TOP - y) / float(BANK_TOP - YARD_TOP + 4)
		return 92.0 * sqrt(maxf(0.0, 1.0 - t * t * t))
	var b := float(y - BANK_TOP) / float(BANK_BOTTOM - BANK_TOP)
	var round_off := 6.0 * pow(b, 4.0)
	return 92.0 + b * 4.0 - round_off


func _knoll() -> void:
	var cx := W / 2.0
	for y in range(YARD_TOP - 4, BANK_BOTTOM + 1):
		var half := _knoll_half(y)
		for x in W:
			var dx := x + 0.5 - cx
			if absf(dx) > half:
				continue
			var n := hash2(x, y, 31)
			if y < BANK_TOP:
				# gold grass on top, lighter toward the upper left
				var lit := 3 - int(dx / 40.0) + (1 if n > 0.8 else 0) - (1 if n < 0.15 else 0)
				px(x, y, grass[clampi(lit, 1, 5)])
				if hash2(x, y, 7) > 0.93:
					px(x, y - 1, grass[4])
			else:
				# the bank: earth, lit on its left flank and on its upper lip
				var b := float(y - BANK_TOP) / float(BANK_BOTTOM - BANK_TOP)
				var lit := 3.6 - b * 2.2 - dx / 70.0
				lit += (0.6 if n > 0.75 else 0.0) - (0.6 if n < 0.2 else 0.0)
				px(x, y, earth[clampi(int(lit), 0, 5)])
	# dry grass draping over the lip of the bank
	for x in W:
		var half := _knoll_half(BANK_TOP)
		if absf(x + 0.5 - cx) > half - 1:
			continue
		var drop := int(hash2(x, 0, 11) * 4.0)
		for i in drop:
			px(x, BANK_TOP + i, grass[2] if i < drop - 1 else grass[1])
		px(x, BANK_TOP - 1, grass[4] if x < cx else grass[3])
	# rocks set into the bank to hold it, lit from the upper left
	for r: Array in [[18, 152, 8, 5], [40, 166, 10, 6], [62, 146, 6, 4], [134, 159, 9, 5], [158, 145, 7, 5], [176, 166, 9, 6], [30, 176, 6, 3], [150, 176, 7, 3], [120, 171, 6, 4], [66, 172, 5, 3]]:
		_rock(r[0], r[1], r[2], r[3])
	# tufts of grass on the bank
	for i in 26:
		var x := 6 + int(hash2(i, 3, 5) * (W - 12))
		var y := BANK_TOP + 6 + int(hash2(i, 4, 5) * (BANK_BOTTOM - BANK_TOP - 9))
		if absf(x - cx) < 14 or absf(x + 0.5 - cx) > _knoll_half(y) - 3:
			continue
		px(x, y, grass[3])
		px(x - 1, y + 1, grass[2])
		px(x + 1, y + 1, grass[2])
		px(x, y + 1, grass[1])


func _rock(cx: int, cy: int, rx: int, ry: int) -> void:
	for y in range(cy - ry, cy + ry + 1):
		for x in range(cx - rx, cx + rx + 1):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy > 1.0:
				continue
			var lit := -dx * 0.55 - dy * 0.8
			var i := 3 if lit > 0.45 else (2 if lit > -0.2 else 1)
			if lit > 0.75:
				i = 4
			px(x, y, stone[i])
	for x in range(cx - rx + 1, cx + rx):
		px(x, cy + ry, earth[0])


## Flagstone steps up the middle of the bank to the gate, and a stone path
## across the yard to the door.
func _steps() -> void:
	var x0 := W / 2 - 9
	var steps := 6
	var rise := (BANK_BOTTOM - BANK_TOP) / steps
	for s in steps:
		var y := BANK_TOP + s * rise
		var inset := steps - 1 - s
		rect(x0 - inset + 1, y, 18 + inset * 2 - 2, 2, stone[4])
		rect(x0 - inset + 1, y + 2, 18 + inset * 2 - 2, rise - 2, stone[2])
		hline(x0 - inset + 1, y + rise - 1, 18 + inset * 2 - 2, stone[1])
		px(x0 - inset + 1, y, stone[5])
		vline(x0 - inset, y, rise, earth[0])
		vline(x0 + 18 + inset - 1, y, rise, earth[0])
	# the path: a few flagstones from the gate to the door step
	for f: Array in [[96, 130, 8, 3], [104, 126, 7, 3], [114, 123, 8, 2], [124, 120, 8, 2], [134, 117, 8, 2], [143, 113, 9, 2]]:
		rect(f[0], f[1], f[2], f[3], stone[3])
		hline(f[0], f[1], f[2], stone[4])
		hline(f[0] + 1, f[1] + f[3], f[2] - 1, grass[1])


func _chimney() -> void:
	var x := 140
	var w := 12
	for y in range(2, 26):
		for xx in range(x, x + w):
			var course := (y / 3) % 2
			var mortar := (y % 3 == 0) or ((xx - x + course * 3) % 6 == 0)
			var lit := 3 if xx < x + 4 else (2 if xx < x + 9 else 1)
			px(xx, y, stone[lit - 1] if mortar else stone[lit + (1 if hash2(xx, y, 4) > 0.8 else 0)])
	rect(x - 1, 2, w + 2, 2, stone[4])
	hline(x - 1, 4, w + 2, stone[1])
	rect(x + 3, 0, 6, 2, stone[0])


## Chunky slate tiles, like the market's, rounded in at the top corners,
## over a cream fascia.
func _roof() -> void:
	var top := 10
	var eave := WALL.position.y
	var left := WALL.position.x - 8
	var right := WALL.end.x + 8
	var row_h := 5
	for y in range(top, eave):
		var inset := maxi(0, 6 - (y - top)) * 2 / 3
		var row := (y - top) / row_h
		var in_row := (y - top) % row_h
		for x in range(left + inset, right - inset):
			var off := (row % 2) * 5
			var tile := (x - left + off) / 10
			var tile_x := (x - left + off) % 10
			var jitter := hash2(tile, row, 17)
			var lit := 4.2 - float(x - left) / float(right - left) * 2.6 - float(y - top) / float(eave - top) * 0.8
			lit += (jitter - 0.5) * 1.6
			var c := roof[clampi(int(lit), 1, 5)]
			if in_row == 0:
				c = c.lightened(0.12)
			elif in_row == row_h - 1 or tile_x == 0:
				c = roof[0]
			px(x, y, c)
	# the shadow of the chimney, which stands on the upper slope
	shade(152, 14, 4, 12, 0.3)
	# moss here and there, as on the market
	for m: Array in [[52, 18], [118, 26], [84, 40], [160, 46]]:
		for i in 6:
			var mx: int = m[0] + int(hash2(i, m[1], 9) * 5.0) - 2
			var my: int = m[1] + int(hash2(m[0], i, 9) * 3.0) - 1
			px(mx, my, Color("4f7a3a"))
			px(mx + 1, my, Color("6a9448") if i % 2 == 0 else Color("4f7a3a"))
	# the fascia and the shadow the eave throws on the wall
	hline(left, eave - 2, right - left, trim[3])
	hline(left, eave - 1, right - left, trim[1])


func _walls() -> void:
	var x0 := WALL.position.x
	for y in range(WALL.position.y, FOUND_Y):
		var board := (y - WALL.position.y) % 4
		for x in range(x0, WALL.end.x):
			var lit := 4 - int(float(x - x0) / WALL.size.x * 2.2)
			if board == 3:
				lit -= 2
			elif board == 0:
				lit += 1
			if hash2(x, y, 23) > 0.94:
				lit -= 1
			px(x, y, siding[clampi(lit, 0, 5)])
	# corner boards
	for cx in [x0, WALL.end.x - 3]:
		rect(cx, WALL.position.y, 3, FOUND_Y - WALL.position.y, trim[2] if cx == x0 else trim[1])
	# the stone foundation
	for y in range(FOUND_Y, FOUND_Y + 4):
		for x in range(x0 - 1, WALL.end.x + 1):
			var joint := y == FOUND_Y + 1 and (x / 5) % 2 == 0 or (x + (y - FOUND_Y) * 3) % 7 == 0
			px(x, y, stone[1] if joint else stone[3 if x < 100 else 2])
	shade(x0, WALL.position.y, WALL.size.x, 4, 0.35)
	shade(WALL.end.x - 10, WALL.position.y, 10, FOUND_Y - WALL.position.y + 4, 0.18)


## A pane of glass by day: the sky's reflection and a white glint.
func _glass(r: Rect2i, curtain := true, strength := 0.75) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var t := float(y - r.position.y) / r.size.y
			var c := Color("6d8fa8").lerp(Color("2e3f52"), t)
			if (x - r.position.x) + (y - r.position.y) * 1 in [3, 4, 9]:
				c = c.lightened(0.35)
			px(x, y, c)
	if curtain:
		rect(r.position.x, r.position.y, 2, r.size.y, Color("e8dcc0"))
		vline(r.position.x + 2, r.position.y, r.size.y, Color("c4b494"))
	_lit_glow(r, strength)


## The warm lamplight one rect of glass gives off at night.
func _lit_glow(r: Rect2i, strength: float) -> void:
	for ring in range(3, 0, -1):
		var a := (0.10 if ring == 3 else (0.16 if ring == 2 else 0.24)) * strength
		for y in range(r.position.y - ring, r.end.y + ring):
			for x in range(r.position.x - ring, r.end.x + ring):
				if not r.has_point(Vector2i(x, y)) and glow.get_pixel(clampi(x, 0, W - 1), clampi(y, 0, H - 1)).a < a:
					px(x, y, Color(1.0, 0.72, 0.3, a), glow)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var t := float(y - r.position.y) / maxi(1, r.size.y - 1)
			px(x, y, Color(1.0, 0.8 - t * 0.12, 0.38, (0.62 - t * 0.2) * strength), glow)


## Three sides of glass standing out from the wall under a little hipped
## roof, on a paneled base.
func _bay_window() -> void:
	var r := BAY
	var side := 6
	# the cap roof
	for y in range(r.position.y - 7, r.position.y):
		var inset := (r.position.y - 1 - y) * 3 / 2
		for x in range(r.position.x - 3 + inset, r.end.x + 3 - inset):
			var lit := 4 - int(float(x - r.position.x) / r.size.x * 3.0)
			px(x, y, roof[clampi(lit - (1 if (y - r.position.y) % 3 == 0 else 0), 1, 5)])
	hline(r.position.x - 3, r.position.y - 1, r.size.x + 6, trim[3])
	shade(r.position.x - 3, r.position.y, r.size.x + 6, 1, 0.3)
	# the frame
	rect(r.position.x, r.position.y, r.size.x, r.size.y - 8, trim[3])
	# the paneled base under the sill
	var base_y := r.end.y - 8
	rect(r.position.x, base_y, r.size.x, 8, siding[3])
	hline(r.position.x, base_y, r.size.x, trim[4])
	hline(r.position.x, base_y + 1, r.size.x, trim[1])
	for px_ in [r.position.x + side + 4, r.position.x + r.size.x / 2 - 2, r.end.x - side - 8]:
		rect(px_, base_y + 3, 5, 3, siding[2])
		hline(px_, base_y + 3, 5, siding[1])
	rect(r.position.x, base_y, side, 8, siding[4])
	rect(r.end.x - side, base_y, side, 8, siding[1])
	hline(r.position.x, r.end.y - 1, r.size.x, siding[0])
	# the glass: the left side lit, the front in two panes, the right in shade
	var gy := r.position.y + 2
	var gh := base_y - gy - 1
	_glass(Rect2i(r.position.x + 1, gy, side - 2, gh), false)
	var fx := r.position.x + side
	var fw := r.size.x - side * 2
	_glass(Rect2i(fx + 1, gy, fw / 2 - 2, gh))
	_glass(Rect2i(fx + fw / 2 + 1, gy, fw / 2 - 2, gh))
	_glass(Rect2i(r.end.x - side + 1, gy, side - 2, gh), false)
	shade(r.end.x - side, gy, side, gh, 0.3)
	# the angled corners of the bay
	vline(fx - 1, r.position.y, base_y - r.position.y + 8, trim[2])
	vline(fx + fw, r.position.y, base_y - r.position.y + 8, trim[1])
	# a plant on the sill
	rect(fx + 4, base_y - 3, 4, 2, Color("9a5a3a"))
	px(fx + 5, base_y - 4, Color("4f7a3a"))
	px(fx + 6, base_y - 5, Color("6a9448"))
	px(fx + 4, base_y - 5, Color("4f7a3a"))


## The living room window, looking in on a lamplit room: someone in a
## flannel shirt hunched over a laptop at a desk, the screen lit with a
## little pixel valley (a granite wall, pines, the river and a walker on the
## trail), a mug beside it, and a poster of Half Dome on the wall.
func _living_window() -> void:
	var r := LIVING
	rect(r.position.x - 2, r.position.y - 2, r.size.x + 4, r.size.y + 4, trim[3])
	hline(r.position.x - 2, r.position.y - 2, r.size.x + 4, trim[4])
	vline(r.end.x + 1, r.position.y - 2, r.size.y + 4, trim[1])
	# the room: a warm wall, darker at the corners
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var dx := absf(x + 0.5 - (r.position.x + r.size.x * 0.4)) / r.size.x
			var dy := float(y - r.position.y) / r.size.y
			px(x, y, Color("6e5440").darkened(dx * 0.6 + dy * 0.15))
	# Half Dome on the wall
	var p := Vector2i(r.position.x + 2, r.position.y + 2)
	rect(p.x, p.y, 8, 6, Color("2a1e16"))
	rect(p.x + 1, p.y + 1, 6, 4, Color("c89a6a"))
	for i in 4:
		vline(p.x + 2 + i, p.y + 2 + (1 if i == 0 or i == 3 else 0), 3 - (1 if i == 0 or i == 3 else 0), Color("5a4a44"))
	vline(p.x + 5, p.y + 2, 3, Color("8a7a70"))
	# a lamp in the far corner throwing light down the wall
	var lamp := Vector2i(r.end.x - 3, r.position.y + 3)
	rect(lamp.x - 1, lamp.y, 3, 2, Color("f0d090"))
	vline(lamp.x, lamp.y + 2, 9, Color("3a2a20"))
	for y in range(lamp.y + 2, lamp.y + 7):
		for x in range(lamp.x - (y - lamp.y), lamp.x + 1):
			if x >= r.position.x and im.get_pixel(x, y).a > 0.5:
				px(x, y, im.get_pixel(x, y).lightened(0.12))
	# the chair back
	rect(r.end.x - 7, r.position.y + 9, 3, 10, Color("3a2a20"))
	vline(r.end.x - 7, r.position.y + 9, 10, Color("5a4232"))
	# the person, in profile facing left: hair, face lit by the screen,
	# shoulders in red flannel, an arm out to the keys
	var head := Vector2i(r.position.x + 17, r.position.y + 6)
	rect(head.x, head.y, 5, 4, Color("3a2618"))
	rect(head.x - 1, head.y + 1, 2, 3, Color("d8b498"))
	px(head.x - 2, head.y + 2, Color("c8a088"))
	px(head.x - 1, head.y + 2, Color("1c1a24"))
	px(head.x, head.y + 4, Color("c8a088"))
	px(head.x + 1, head.y + 4, Color("b08870"))
	var body := Vector2i(head.x - 1, head.y + 5)
	for y in range(body.y, body.y + 8):
		for x in range(body.x, body.x + 7):
			var plaid := ((x + y) % 3 == 0) or (y - body.y) % 3 == 1
			var c := Color("8a3a30") if not plaid else Color("6a2a24")
			if x == body.x:
				c = c.lightened(0.15)
			px(x, y, c)
	rect(body.x - 6, body.y + 4, 6, 2, Color("7a342c"))
	px(body.x - 7, body.y + 5, Color("d8b498"))
	# the desk
	var desk_y := r.end.y - 6
	rect(r.position.x, desk_y, r.size.x, 2, Color("b08a5c"))
	hline(r.position.x, desk_y, r.size.x, Color("c8a272"))
	rect(r.position.x, desk_y + 2, r.size.x, 4, Color("4a3424"))
	vline(r.position.x + 3, desk_y + 2, 4, Color("3a2818"))
	vline(r.end.x - 4, desk_y + 2, 4, Color("3a2818"))
	# the laptop: its base on the desk and its lid turned toward us a little
	var lap := Vector2i(r.position.x + 5, desk_y)
	hline(lap.x - 1, lap.y - 1, 12, Color("9aa0a8"))
	hline(lap.x, lap.y, 10, Color("5a6068"))
	var scr := Rect2i(lap.x, lap.y - 10, 9, 8)
	rect(scr.position.x - 1, scr.position.y - 1, scr.size.x + 2, scr.size.y + 2, Color("1e2228"))
	for y in range(scr.position.y, scr.end.y):
		for x in range(scr.position.x, scr.end.x):
			var sx := x - scr.position.x
			var sy := y - scr.position.y
			var c := Color("8ec4ea") if sy < 3 else Color("5a9a3e")
			if sx < 4 and sy >= 6 - sx and sy < 6:
				c = Color("9aa2a8")
			if sx < 4 and sy > 0 and sy < 6 and sy >= 4 - sx:
				c = Color("c4c8c8") if sy < 3 else Color("9aa2a8")
			if sy == 6 and sx > 1:
				c = Color("4a8ac8")
			if sy == 5 and sx >= 6:
				c = Color("2e5a2e")
			px(x, y, c)
	px(scr.position.x + 6, scr.position.y + 4, Color("e04838"))
	px(scr.position.x + 6, scr.position.y + 3, Color("e8c8a0"))
	# the mug
	rect(r.position.x + 1, desk_y - 3, 2, 3, Color("e8e0c6"))
	px(r.position.x + 3, desk_y - 2, Color("e8e0c6"))
	px(r.position.x + 1, desk_y - 5, Color(1, 1, 1, 0.5))
	px(r.position.x + 2, desk_y - 6, Color(1, 1, 1, 0.4))
	# a glint on the glass
	for i in 4:
		px(r.position.x + 12 + i, r.position.y + 3 - i + 3, Color(1, 1, 1, 0.0).lerp(Color("dce8f0"), 0.35).blend(im.get_pixel(r.position.x + 12 + i, r.position.y + 6 - i)))
	# a thin mullion and the sill, with a box of geraniums under it
	hline(r.position.x - 3, r.end.y + 2, r.size.x + 6, trim[4])
	hline(r.position.x - 3, r.end.y + 3, r.size.x + 6, trim[1])
	rect(r.position.x - 1, r.end.y + 4, r.size.x + 2, 4, wood[2])
	hline(r.position.x - 1, r.end.y + 4, r.size.x + 2, wood[3])
	for x in range(r.position.x, r.end.x, 3):
		px(x, r.end.y + 3, Color("4f7a3a"))
		px(x + 1, r.end.y + 2, Color("d84848") if x % 2 == 0 else Color("e87890"))
		px(x + 1, r.end.y + 3, Color("6a9448"))
	# at night: lamplight, and the screen's blue-white glow on the person
	_lit_glow(r, 0.8)
	for y in range(scr.position.y - 1, scr.end.y + 1):
		for x in range(scr.position.x - 1, scr.end.x + 3):
			px(x, y, Color(0.75, 0.88, 1.0, 0.7), glow)


func _door() -> void:
	var r := DOOR
	rect(r.position.x - 2, r.position.y - 2, r.size.x + 4, r.size.y + 2, trim[3])
	vline(r.end.x + 1, r.position.y - 2, r.size.y + 2, trim[1])
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var lit := 4 - int(float(x - r.position.x) / r.size.x * 2.5)
			px(x, y, wood[clampi(lit - (1 if (x - r.position.x) % 4 == 0 else 0), 1, 5)])
	for pr: Rect2i in [Rect2i(r.position.x + 2, r.position.y + 3, r.size.x - 4, 9), Rect2i(r.position.x + 2, r.position.y + 15, r.size.x - 4, 10)]:
		rect(pr.position.x, pr.position.y, pr.size.x, pr.size.y, wood[2])
		hline(pr.position.x, pr.position.y, pr.size.x, wood[1])
		vline(pr.position.x, pr.position.y, pr.size.y, wood[1])
	px(r.end.x - 3, r.position.y + 14, Color("e0c060"))
	# the step and the porch light
	rect(r.position.x - 3, FOUND_Y, r.size.x + 6, 4, stone[3])
	hline(r.position.x - 3, FOUND_Y, r.size.x + 6, stone[5])
	var lamp := Vector2i(r.end.x + 4, r.position.y + 2)
	rect(lamp.x, lamp.y, 3, 4, Color("2a2420"))
	px(lamp.x + 1, lamp.y + 1, Color("f8e0a0"))
	px(lamp.x + 1, lamp.y + 2, Color("f0c870"))
	_lit_glow(Rect2i(lamp.x + 1, lamp.y + 1, 1, 2), 1.0)


## A brown picket fence along the front of the yard with a gate at the top
## of the steps.
func _fence() -> void:
	var y0 := GATE.position.y
	var y1 := GATE.end.y
	var half := _knoll_half(y1)
	var x_from := int(W / 2.0 - half) + 6
	var x_to := int(W / 2.0 + half) - 6
	# the front rails, then the pickets over them
	for x in range(x_from, x_to):
		if x >= GATE.position.x and x < GATE.end.x:
			continue
		px(x, y0 + 3, wood[1])
		px(x, y0 + 9, wood[1])
	for x in range(x_from, x_to, 3):
		if x >= GATE.position.x - 1 and x < GATE.end.x:
			continue
		var c1 := wood[4] if x < W / 2 else wood[3]
		vline(x, y0 + 1, y1 - y0 - 1, c1)
		vline(x + 1, y0 + 1, y1 - y0 - 1, wood[2])
		px(x, y0, wood[5])
		px(x + 1, y0, wood[3])
		px(x, y1 - 1, wood[1])
		px(x + 1, y1 - 1, wood[0])
	# fat posts at each end and either side of the gate, with caps
	for x in [x_from - 1, GATE.position.x - 3, GATE.end.x, x_to - 1]:
		rect(x, y0 - 3, 3, y1 - y0 + 3, wood[3])
		vline(x, y0 - 3, y1 - y0 + 3, wood[4])
		vline(x + 2, y0 - 3, y1 - y0 + 3, wood[1])
		rect(x - 1, y0 - 4, 5, 2, wood[5])
	# the gate, standing a little open
	for x in range(GATE.position.x + 1, GATE.position.x + 10, 3):
		vline(x, y0 + 2, y1 - y0 - 3, wood[4])
		vline(x + 1, y0 + 2, y1 - y0 - 3, wood[2])
	hline(GATE.position.x, y0 + 4, 11, wood[2])
	hline(GATE.position.x, y0 + 9, 11, wood[2])
	for i in 6:
		px(GATE.position.x + 2 + i, y0 + 4 + i, wood[1])


func _mailbox() -> void:
	var x := W / 2 - 22
	var y := BANK_BOTTOM - 14
	rect(x + 3, y + 5, 2, 10, wood[2])
	vline(x + 3, y + 5, 10, wood[3])
	rect(x, y, 8, 5, Color("3a3e44"))
	hline(x + 1, y, 6, Color("6a7078"))
	vline(x + 7, y + 1, 4, Color("24272c"))
	rect(x + 8, y - 2, 1, 3, Color("c84838"))


func _outline() -> void:
	var edge: Array[Vector2i] = []
	for y in H:
		for x in W:
			if im.get_pixel(x, y).a > 0.5:
				continue
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n := Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < W and n.y < H and im.get_pixel(n.x, n.y).a > 0.5:
					edge.append(Vector2i(x, y))
					break
	for p in edge:
		im.set_pixel(p.x, p.y, OUTLINE)
