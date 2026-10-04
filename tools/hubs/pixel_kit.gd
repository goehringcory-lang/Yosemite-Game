class_name PixelKit
extends RefCounted
## Drawing helpers for the hand-made hubs' pixel art (Curry Village and its
## shops): shingle roofs, board walls, windows, awnings, tiny lettering, and a
## 1 px outline pass. Everything is drawn in code, in a warm Stardew-like
## palette with a dark brown outline; replace any PNG with hand-drawn art of
## the same size at any time.

const OUTLINE := Color("2a1f1a")

## 3x5 letters for painted signs. '#' is paint.
const FONT := {
	"A": [".#.", "#.#", "###", "#.#", "#.#"], "B": ["##.", "#.#", "##.", "#.#", "##."],
	"C": [".##", "#..", "#..", "#..", ".##"], "D": ["##.", "#.#", "#.#", "#.#", "##."],
	"E": ["###", "#..", "##.", "#..", "###"], "F": ["###", "#..", "##.", "#..", "#.."],
	"G": [".##", "#..", "#.#", "#.#", ".##"], "H": ["#.#", "#.#", "###", "#.#", "#.#"],
	"I": ["###", ".#.", ".#.", ".#.", "###"], "J": ["..#", "..#", "..#", "#.#", ".#."],
	"K": ["#.#", "#.#", "##.", "#.#", "#.#"], "L": ["#..", "#..", "#..", "#..", "###"],
	"M": ["#.#", "###", "###", "#.#", "#.#"], "N": ["##.", "#.#", "#.#", "#.#", "#.#"],
	"O": [".#.", "#.#", "#.#", "#.#", ".#."], "P": ["##.", "#.#", "##.", "#..", "#.."],
	"Q": [".#.", "#.#", "#.#", "###", ".##"], "R": ["##.", "#.#", "##.", "#.#", "#.#"],
	"S": [".##", "#..", ".#.", "..#", "##."], "T": ["###", ".#.", ".#.", ".#.", ".#."],
	"U": ["#.#", "#.#", "#.#", "#.#", "###"], "V": ["#.#", "#.#", "#.#", "#.#", ".#."],
	"W": ["#.#", "#.#", "###", "###", "#.#"], "X": ["#.#", "#.#", ".#.", "#.#", "#.#"],
	"Y": ["#.#", "#.#", ".#.", ".#.", ".#."], "Z": ["###", "..#", ".#.", "#..", "###"],
	"0": ["###", "#.#", "#.#", "#.#", "###"], "1": [".#.", "##.", ".#.", ".#.", "###"],
	"2": ["##.", "..#", ".#.", "#..", "###"], "3": ["##.", "..#", ".#.", "..#", "##."],
	"4": ["#.#", "#.#", "###", "..#", "..#"], "5": ["###", "#..", "##.", "..#", "##."],
	"6": [".##", "#..", "###", "#.#", "###"], "7": ["###", "..#", ".#.", ".#.", ".#."],
	"8": ["###", "#.#", "###", "#.#", "###"], "9": ["###", "#.#", "###", "..#", "##."],
	"-": ["...", "...", "###", "...", "..."], ".": ["...", "...", "...", "...", ".#."],
	"&": [".#.", "#.#", ".##", "#.#", ".##"], "'": [".#.", ".#.", "...", "...", "..."],
	"!": [".#.", ".#.", ".#.", "...", ".#."], " ": ["", "", "", "", ""],
}


static func c(hex: String) -> Color:
	return Color(hex)


static func make(w: int, h: int) -> Image:
	return Image.create_empty(w, h, false, Image.FORMAT_RGBA8)


static func rect(im: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	var r := Rect2i(x, y, w, h).intersection(Rect2i(Vector2i.ZERO, im.get_size()))
	if r.size.x > 0 and r.size.y > 0:
		im.fill_rect(r, col)


static func px(im: Image, x: int, y: int, col: Color) -> void:
	if x >= 0 and y >= 0 and x < im.get_width() and y < im.get_height():
		if col.a < 1.0:
			im.set_pixel(x, y, im.get_pixel(x, y).blend(col))
		else:
			im.set_pixel(x, y, col)


static func hline(im: Image, x: int, y: int, w: int, col: Color) -> void:
	rect(im, x, y, w, 1, col)


static func vline(im: Image, x: int, y: int, h: int, col: Color) -> void:
	rect(im, x, y, 1, h, col)


## A filled ellipse.
static func ellipse(im: Image, cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	for y in range(floori(cy - ry), ceili(cy + ry) + 1):
		for x in range(floori(cx - rx), ceili(cx + rx) + 1):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				px(im, x, y, col)


## The outline of an ellipse, one pixel thick.
static func ring(im: Image, cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	var steps := int((rx + ry) * 4.0)
	for i in steps:
		var a := TAU * float(i) / steps
		px(im, int(round(cx + cos(a) * rx)), int(round(cy + sin(a) * ry)), col)


static func shadow(im: Image, cx: float, cy: float, rx: float, ry: float, alpha := 0.24) -> void:
	ellipse(im, cx, cy, rx, ry, Color(0.05, 0.03, 0.02, alpha))


## Copies [param src] onto [param im] at ([param x], [param y]).
static func stamp(im: Image, src: Image, x: int, y: int) -> void:
	for sy in src.get_height():
		for sx in src.get_width():
			var col := src.get_pixel(sx, sy)
			if col.a > 0.0:
				px(im, x + sx, y + sy, col)


## A 1 px outline around everything opaque, drawn on the transparent pixels
## touching it. Call last.
static func outline(im: Image, col := OUTLINE) -> void:
	var edge: Array[Vector2i] = []
	var w := im.get_width()
	var h := im.get_height()
	for y in h:
		for x in w:
			if im.get_pixel(x, y).a > 0.5:
				continue
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n := Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < w and n.y < h and im.get_pixel(n.x, n.y).a > 0.5 and im.get_pixel(n.x, n.y) != col:
					edge.append(Vector2i(x, y))
					break
	for p in edge:
		im.set_pixelv(p, col)


static func hash2(x: int, y: int, seed_value := 0) -> float:
	var h := (x * 374761393 + y * 668265263 + seed_value * 2147483647) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65535.0


static func mix(a: Color, b: Color, t: float) -> Color:
	return a.lerp(b, t)


## Width in pixels of [param text] set in the 3x5 font.
static func text_width(text: String) -> int:
	var w := 0
	for ch in text:
		var g: Array = FONT.get(ch, FONT[" "])
		w += (3 if g[0] != "" else 2) + 1
	return maxi(0, w - 1)


## Paints [param text] with its top-left at ([param x], [param y]). A shadow
## color drops it one pixel down for legibility on busy boards.
static func text(im: Image, x: int, y: int, text_value: String, col: Color, shadow_col := Color(0, 0, 0, 0)) -> void:
	var cx := x
	for ch in text_value.to_upper():
		var g: Array = FONT.get(ch, FONT[" "])
		var gw := 3 if g[0] != "" else 2
		if g[0] != "":
			for gy in 5:
				for gx in 3:
					if g[gy][gx] == "#":
						if shadow_col.a > 0.0:
							px(im, cx + gx, y + gy + 1, shadow_col)
						px(im, cx + gx, y + gy, col)
		cx += gw + 1


## Text centered in [param box_w] pixels starting at [param x].
static func text_centered(im: Image, x: int, box_w: int, y: int, text_value: String, col: Color, shadow_col := Color(0, 0, 0, 0)) -> void:
	text(im, x + (box_w - text_width(text_value.to_upper())) / 2, y, text_value, col, shadow_col)


# ---------------------------------------------------------------- materials

## Shingle courses: rows of overlapping shingles with tone variation, a dark
## lower edge on each course, and a lit ridge. [param taper] narrows the roof
## toward the top (0 = rectangle).
static func shingles(im: Image, x: int, y: int, w: int, h: int, base: Color, seed_value := 1, taper := 0.0, course := 3) -> void:
	var dark := base.darkened(0.28)
	var light := base.lightened(0.16)
	for row in h:
		var inset := int((h - 1 - row) * taper)
		var ry := y + row
		var course_i := row / course
		var in_course := row % course
		for sx in range(x + inset, x + w - inset):
			var col := base
			var off := (course_i % 2) * 2
			var shingle := (sx - x + off) / 4
			var n := hash2(shingle, course_i, seed_value)
			if n < 0.28:
				col = dark.lerp(base, 0.55)
			elif n > 0.74:
				col = light
			if in_course == course - 1:
				col = col.darkened(0.3)
			elif in_course == 0 and course_i > 0:
				col = col.lightened(0.05)
			if (sx - x + off) % 4 == 3 and in_course < course - 1:
				col = col.darkened(0.16)
			px(im, sx, ry, col)
	# ridge
	var ridge_inset := int((h - 1) * taper)
	hline(im, x + ridge_inset, y, w - ridge_inset * 2, base.lightened(0.34))


## Vertical board-and-batten siding with a light edge on every board.
static func boards(im: Image, x: int, y: int, w: int, h: int, base: Color, seed_value := 2, board_w := 4) -> void:
	var dark := base.darkened(0.24)
	var light := base.lightened(0.1)
	for bx in range(0, w, board_w):
		var tone := base
		var n := hash2(bx / board_w, seed_value, 9)
		if n < 0.3:
			tone = base.darkened(0.07)
		elif n > 0.75:
			tone = base.lightened(0.06)
		rect(im, x + bx, y, mini(board_w, w - bx), h, tone)
		vline(im, x + bx, y, h, dark)
		if bx + 1 < w:
			vline(im, x + bx + 1, y, h, light)
	# a few nail heads and knots
	for i in int(w * h / 90.0):
		var kx := x + int(hash2(i, seed_value, 3) * w)
		var ky := y + int(hash2(i, seed_value, 4) * h)
		px(im, kx, ky, dark)


## Horizontal lap siding.
static func lap(im: Image, x: int, y: int, w: int, h: int, base: Color, seed_value := 5) -> void:
	for row in range(0, h, 3):
		var tone := base.lightened(0.04 * float(hash2(row, seed_value, 1) - 0.5))
		rect(im, x, y + row, w, 2, tone)
		hline(im, x, y + row + 2, w, base.darkened(0.26))
		if row + 3 > h:
			break


## Stacked stone with mortar, for foundations and chimneys.
static func stones(im: Image, x: int, y: int, w: int, h: int, base: Color, seed_value := 7) -> void:
	var mortar := base.darkened(0.36)
	rect(im, x, y, w, h, mortar)
	var row_y := 0
	var row_i := 0
	while row_y < h:
		var rh := 3 + int(hash2(row_i, seed_value, 1) * 2.0)
		var sx := -int(hash2(row_i, seed_value, 2) * 4.0)
		while sx < w:
			var sw := 4 + int(hash2(sx + 50, row_i, seed_value) * 4.0)
			var tone := base.lightened((hash2(sx, row_i, seed_value + 3) - 0.5) * 0.22)
			var x0 := maxi(sx, 0)
			var x1 := mini(sx + sw - 1, w)
			var y1 := mini(rh - 1, h - row_y)
			rect(im, x + x0, y + row_y, x1 - x0, y1, tone)
			hline(im, x + x0, y + row_y, x1 - x0, tone.lightened(0.14))
			sx += sw
		row_y += rh
		row_i += 1


static func window(im: Image, x: int, y: int, w: int, h: int, frame: Color, glass: Color, curtain := Color(0, 0, 0, 0), shutter := Color(0, 0, 0, 0), lit := false) -> void:
	if shutter.a > 0.0:
		rect(im, x - 3, y, 3, h, shutter)
		rect(im, x + w, y, 3, h, shutter)
		for sy in range(y + 1, y + h, 2):
			hline(im, x - 3, sy, 3, shutter.darkened(0.25))
			hline(im, x + w, sy, 3, shutter.darkened(0.25))
	rect(im, x - 1, y - 1, w + 2, h + 2, frame)
	var pane := glass.lightened(0.2) if lit else glass
	rect(im, x, y, w, h, pane)
	rect(im, x, y, w, 1, pane.lightened(0.18))
	if w >= 5:
		vline(im, x + w / 2, y, h, frame)
	if h >= 6:
		hline(im, x, y + h / 2, w, frame)
	if curtain.a > 0.0:
		rect(im, x, y, maxi(1, w / 4), h - 1, curtain)
		rect(im, x + w - maxi(1, w / 4), y, maxi(1, w / 4), h - 1, curtain)
	# sill
	rect(im, x - 2, y + h + 1, w + 4, 1, frame.lightened(0.18))
	hline(im, x - 2, y + h + 2, w + 4, Color(0, 0, 0, 0.2))


static func door(im: Image, x: int, y: int, w: int, h: int, wood: Color, frame: Color, glass := false) -> void:
	rect(im, x - 1, y - 1, w + 2, h + 1, frame)
	rect(im, x, y, w, h, wood)
	vline(im, x + w / 2, y, h, wood.darkened(0.3))
	hline(im, x, y + 1, w, wood.lightened(0.14))
	if glass:
		rect(im, x + 1, y + 2, w / 2 - 1, h / 3, c("f2e2a0"))
		rect(im, x + w / 2 + 1, y + 2, w / 2 - 1, h / 3, c("f2e2a0"))
	else:
		rect(im, x + 1, y + 2, w / 2 - 1, h / 2 - 1, wood.darkened(0.16))
		rect(im, x + w / 2 + 1, y + 2, w / 2 - 1, h / 2 - 1, wood.darkened(0.16))
	px(im, x + w / 2 - 1, y + h / 2 + 1, c("e0c060"))
	# step
	rect(im, x - 2, y + h, w + 4, 2, c("8a8072"))
	hline(im, x - 2, y + h, w + 4, c("b0a692"))


## Striped awning with a scalloped edge.
static func awning(im: Image, x: int, y: int, w: int, depth: int, a: Color, b: Color) -> void:
	for row in depth:
		var inset := int((depth - 1 - row) * 0.0)
		for ax in range(x + inset, x + w - inset):
			var stripe := ((ax - x) / 4) % 2 == 0
			var col := a if stripe else b
			if row == depth - 1:
				col = col.darkened(0.2)
			elif row == 0:
				col = col.lightened(0.14)
			px(im, ax, y + row, col)
	for ax in range(x, x + w, 4):
		var stripe := ((ax - x) / 4) % 2 == 0
		var col := (a if stripe else b).darkened(0.2)
		px(im, ax + 1, y + depth, col)
		px(im, ax + 2, y + depth, col)
	rect(im, x, y + depth + 1, w, 1, Color(0, 0, 0, 0.18))


## A painted sign board: dark edge, board color, centered lettering.
static func sign_board(im: Image, x: int, y: int, w: int, label: String, board: Color, ink: Color, h := 9) -> void:
	rect(im, x, y, w, h, board.darkened(0.42))
	rect(im, x + 1, y + 1, w - 2, h - 2, board)
	hline(im, x + 1, y + 1, w - 2, board.lightened(0.16))
	text_centered(im, x, w, y + (h - 5) / 2 + 0, label, ink, board.darkened(0.3))


static func lantern(im: Image, x: int, y: int, on := true) -> void:
	px(im, x, y, c("3a2c22"))
	rect(im, x - 1, y + 1, 3, 4, c("3a2c22"))
	rect(im, x, y + 2, 1, 2, c("ffd870") if on else c("9a8a5a"))
	if on:
		px(im, x - 1, y + 3, Color(1, 0.85, 0.4, 0.35))
		px(im, x + 1, y + 3, Color(1, 0.85, 0.4, 0.35))


static func crate(im: Image, x: int, y: int, w: int, h: int, wood: Color) -> void:
	rect(im, x, y, w, h, wood)
	hline(im, x, y, w, wood.lightened(0.18))
	hline(im, x, y + h - 1, w, wood.darkened(0.32))
	vline(im, x, y, h, wood.darkened(0.18))
	vline(im, x + w - 1, y, h, wood.darkened(0.3))
	hline(im, x, y + h / 2, w, wood.darkened(0.2))


static func barrel(im: Image, x: int, y: int, w: int, h: int, wood: Color) -> void:
	for by in h:
		var t := float(by) / maxi(1, h - 1)
		var bulge := int(sin(t * PI) * 1.0)
		rect(im, x - bulge, y + by, w + bulge * 2, 1, wood)
	vline(im, x, y, h, wood.lightened(0.15))
	vline(im, x + w - 1, y, h, wood.darkened(0.25))
	hline(im, x - 1, y + 2, w + 2, wood.darkened(0.4))
	hline(im, x - 1, y + h - 3, w + 2, wood.darkened(0.4))
