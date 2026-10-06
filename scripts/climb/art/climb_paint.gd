class_name ClimbPaint
extends RefCounted
## Small pixel-painting helpers shared by the climbing screen's painters:
## rectangles, lines, ellipses, blobs, 1 px outlines and cheap hashed noise.
## All coordinates are whole pixels; everything clips to the image.

const OUTLINE := Color("2a1f1a")
const BAYER := [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


static func make(w: int, h: int) -> Image:
	return Image.create_empty(w, h, false, Image.FORMAT_RGBA8)


static func px(im: Image, x: int, y: int, col: Color) -> void:
	if x >= 0 and y >= 0 and x < im.get_width() and y < im.get_height():
		if col.a < 1.0:
			im.set_pixel(x, y, im.get_pixel(x, y).blend(col))
		else:
			im.set_pixel(x, y, col)


static func rect(im: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	var r := Rect2i(x, y, w, h).intersection(Rect2i(Vector2i.ZERO, im.get_size()))
	if r.size.x > 0 and r.size.y > 0:
		if col.a < 1.0:
			for yy in range(r.position.y, r.end.y):
				for xx in range(r.position.x, r.end.x):
					im.set_pixel(xx, yy, im.get_pixel(xx, yy).blend(col))
		else:
			im.fill_rect(r, col)


static func hline(im: Image, x: int, y: int, w: int, col: Color) -> void:
	rect(im, x, y, w, 1, col)


static func vline(im: Image, x: int, y: int, h: int, col: Color) -> void:
	rect(im, x, y, 1, h, col)


## A line of [param width] pixels (Bresenham, stamped).
static func line(im: Image, a: Vector2, b: Vector2, col: Color, width := 1) -> void:
	var x0 := roundi(a.x)
	var y0 := roundi(a.y)
	var x1 := roundi(b.x)
	var y1 := roundi(b.y)
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	while true:
		if width <= 1:
			px(im, x0, y0, col)
		else:
			var off := -(width - 1) / 2
			rect(im, x0 + off, y0 + off, width, width, col)
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


static func ellipse(im: Image, cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	for y in range(floori(cy - ry), ceili(cy + ry) + 1):
		for x in range(floori(cx - rx), ceili(cx + rx) + 1):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				px(im, x, y, col)


## A filled ellipse lit from the upper left: [param lit] on the top-left
## crescent, [param dark] on the lower-right crescent.
static func shaded_ellipse(im: Image, cx: float, cy: float, rx: float, ry: float, col: Color, lit: Color, dark: Color) -> void:
	for y in range(floori(cy - ry), ceili(cy + ry) + 1):
		for x in range(floori(cx - rx), ceili(cx + rx) + 1):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			var d := dx * dx + dy * dy
			if d <= 1.0:
				var shade := dx * 0.6 + dy * 0.8
				px(im, x, y, lit if shade < -0.45 else (dark if shade > 0.45 else col))


## A 1 px outline on the transparent pixels touching opaque ones.
static func outline(im: Image, col := OUTLINE, diagonals := false) -> void:
	var edge: Array[Vector2i] = []
	var w := im.get_width()
	var h := im.get_height()
	var dirs: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	if diagonals:
		dirs.append_array([Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)])
	for y in h:
		for x in w:
			if im.get_pixel(x, y).a > 0.1:
				continue
			for d in dirs:
				var n := Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < w and n.y < h and im.get_pixel(n.x, n.y).a > 0.5 and im.get_pixel(n.x, n.y) != col:
					edge.append(Vector2i(x, y))
					break
	for p in edge:
		im.set_pixelv(p, col)


## Stamps [param src] onto [param im] with alpha.
static func stamp(im: Image, src: Image, x: int, y: int) -> void:
	for sy in src.get_height():
		for sx in src.get_width():
			var col := src.get_pixel(sx, sy)
			if col.a > 0.0:
				px(im, x + sx, y + sy, col)


## Hashed noise in 0..1: stable for the same (x, y, seed).
static func noise(x: int, y: int, seed_value := 0) -> float:
	var h := (x * 374761393 + y * 668265263 + seed_value * 2147483647) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65535.0


## Smooth value noise (bilinear over a hashed lattice), 0..1.
static func smooth_noise(x: float, y: float, seed_value := 0) -> float:
	var x0 := floori(x)
	var y0 := floori(y)
	var fx := x - x0
	var fy := y - y0
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := noise(x0, y0, seed_value)
	var b := noise(x0 + 1, y0, seed_value)
	var c := noise(x0, y0 + 1, seed_value)
	var d := noise(x0 + 1, y0 + 1, seed_value)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


## Ordered-dither: true if [param t] (0..1) passes the Bayer threshold at (x, y).
static func dither(x: int, y: int, t: float) -> bool:
	return (BAYER[y & 3][x & 3] + 0.5) / 16.0 < t


## Blends two colors by a ramp step: ramp is an Array of Colors, [param t] 0..1.
static func ramp(colors: Array, t: float) -> Color:
	t = clampf(t, 0.0, 0.9999)
	return colors[int(t * colors.size())]


static func shade(col: Color, amount: float) -> Color:
	return col.darkened(amount) if amount >= 0.0 else col.lightened(-amount)


## A lumpy blob of [param col] (for shrubs, lichen, snow): circles stacked.
static func blob(im: Image, cx: int, cy: int, r: int, col: Color, rng: RandomNumberGenerator, lumps := 4) -> void:
	ellipse(im, cx, cy, r, maxf(r * 0.7, 1.0), col)
	for i in lumps:
		var a := rng.randf() * TAU
		var d := r * rng.randf_range(0.4, 0.9)
		ellipse(im, cx + cos(a) * d, cy + sin(a) * d * 0.7, maxf(r * 0.5, 1.0), maxf(r * 0.4, 1.0), col)
