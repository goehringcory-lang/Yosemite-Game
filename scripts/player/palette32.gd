class_name Palette32
extends RefCounted
## The 32px art pass for a person, done in the game: what tools/art32 does to
## the sheets tools/npcgen paints (tools/art32/passes.py "characters" and
## "ui"), so a sheet painted while the game runs (the player's own look) comes
## out the same as the cast's shipped ones. Doubles the picture with Scale2x,
## maps every color onto the Valley Days palette, and rims each frame with a
## one-pixel outline in the darkest color of the ramp it borders.
##
##   var sheet := Palette32.character_sheet(FigurePainter.new().draw_sheet(look))
##   var faces := Palette32.snap(PortraitPainter.new().strip(look, "player"))
##
## The palette is tools/art32/palette.py's, in the same order; a test checks
## the default look comes out pixel for pixel as assets/sprites/player.png.

## name -> colors, dark to light (tools/art32/palette.py RAMPS).
const RAMPS := [
	["2b2a30", "47464d", "6a6a70", "93918f", "bdb8ae", "e4ddcc"], # granite
	["5e4a38", "86694b", "b0925f", "d6bd88"], # tan
	["12291d", "1d3f2b", "2c5c37", "437f45"], # pine
	["5c8f3c", "84b04a", "aecb62", "d3e48a"], # meadow
	["7e531c", "ad7a22", "d8a63b", "f1cf6a"], # oak
	["2a1b14", "47301f", "6b4829", "92693d"], # bark
	["142f47", "235679", "3a86a8", "63b3c6", "9fd8d9", "d6f1ee"], # merced
	["a84a1c", "d9772a", "f7a64a", "ffd48a"], # amber
	["6f5aa6", "d47a9b", "b3362b", "f5eee0"], # accent
	["15141c", "2d3050"], # night
]
## A frame of a walking sheet after doubling.
const CELL := Vector2i(32, 48)

static var _colors: Array[Color] = []
static var _labs: Array[Vector3] = []
## Palette index -> the index of its ramp's darkest color.
static var _darkest: PackedInt32Array = PackedInt32Array()
## 5-bit-a-channel color -> palette index, filled as colors turn up.
static var _lut: Dictionary = {}


static func _build() -> void:
	if not _colors.is_empty():
		return
	for ramp: Array in RAMPS:
		var first := _colors.size()
		for hex: String in ramp:
			var c := Color(hex)
			_colors.append(c)
			_labs.append(_lab(c.r8, c.g8, c.b8))
			_darkest.append(first)


static func _lin(v: float) -> float:
	v /= 255.0
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)


static func _f(t: float) -> float:
	return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0


static func _lab(r8: int, g8: int, b8: int) -> Vector3:
	var r := _lin(r8)
	var g := _lin(g8)
	var b := _lin(b8)
	var fx := _f((0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047)
	var fy := _f(0.2126 * r + 0.7152 * g + 0.0722 * b)
	var fz := _f((0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


## The palette index nearest [param c] (CIE Lab distance, lightness weighted
## a little more), after rounding to five bits a channel as the art pass does.
static func index_of(c: Color) -> int:
	_build()
	var qr := (c.r8 * 31 + 127) / 255
	var qg := (c.g8 * 31 + 127) / 255
	var qb := (c.b8 * 31 + 127) / 255
	var key := qr * 1024 + qg * 32 + qb
	if _lut.has(key):
		return _lut[key]
	var lab := _lab(qr * 255 / 31, qg * 255 / 31, qb * 255 / 31)
	var best := 0
	var best_d := INF
	for i in _labs.size():
		var p := _labs[i]
		var d := (lab.x - p.x) * (lab.x - p.x) * 1.2 + (lab.y - p.y) * (lab.y - p.y) + (lab.z - p.z) * (lab.z - p.z)
		if d < best_d:
			best = i
			best_d = d
	_lut[key] = best
	return best


## The palette color nearest [param c].
static func nearest(c: Color) -> Color:
	return _colors[index_of(c)]


## A copy of [param image] with every pixel on the palette; a pixel is fully
## there or not at all.
static func snap(image: Image) -> Image:
	_build()
	var out := Image.create_empty(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			var p := _colors[index_of(c)]
			out.set_pixel(x, y, Color(p.r, p.g, p.b, 1.0 if c.a8 >= 128 else 0.0))
	return out


## Scale2x (EPX): twice the size, the stair-steps on diagonals rounded off,
## no new colors.
static func scale2x(image: Image) -> Image:
	var w := image.get_width()
	var h := image.get_height()
	var out := Image.create_empty(w * 2, h * 2, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c := image.get_pixel(x, y)
			var up := image.get_pixel(x, maxi(y - 1, 0))
			var down := image.get_pixel(x, mini(y + 1, h - 1))
			var left := image.get_pixel(maxi(x - 1, 0), y)
			var right := image.get_pixel(mini(x + 1, w - 1), y)
			out.set_pixel(x * 2, y * 2, up if left == up and left != down and up != right else c)
			out.set_pixel(x * 2 + 1, y * 2, right if up == right and up != left and right != down else c)
			out.set_pixel(x * 2, y * 2 + 1, left if down == left and down != right and left != up else c)
			out.set_pixel(x * 2 + 1, y * 2 + 1, down if right == down and right != up and down != left else c)
	return out


## Rims every [param cell] of [param image] (already on the palette) with a
## one-pixel outline just outside the figure, in the darkest color of the
## ramp it borders; a frame's outline never spills into the next frame.
static func outline_cells(image: Image, cell := CELL) -> void:
	_build()
	var src := image.duplicate() as Image
	for cy in range(0, image.get_height() - cell.y + 1, cell.y):
		for cx in range(0, image.get_width() - cell.x + 1, cell.x):
			for y in cell.y:
				for x in cell.x:
					if src.get_pixel(cx + x, cy + y).a > 0.5:
						continue
					# the neighbour below or to the right (the shaded side)
					# first, then above, then left
					var from := Color(0, 0, 0, 0)
					for n: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
						var at := Vector2i(x, y) + n
						if at.x < 0 or at.y < 0 or at.x >= cell.x or at.y >= cell.y:
							continue
						var c := src.get_pixel(cx + at.x, cy + at.y)
						if c.a > 0.5:
							from = c
							break
					if from.a > 0.5:
						image.set_pixel(cx + x, cy + y, _colors[_darkest[index_of(from)]])


## A walking sheet as tools/npcgen paints it (16x24 frames) made into the
## 32x48 sheet the game shows.
static func character_sheet(sheet16: Image) -> Image:
	var out := snap(scale2x(sheet16))
	outline_cells(out)
	return out
