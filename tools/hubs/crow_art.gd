extends "res://tools/hubs/camp4_art.gd"
## Crow's Camp, up Tenaya Creek above Mirror Lake: the little stone cairn
## that marks where the use trail leaves the lakeshore, and the granite
## overhang Crow camps under (a dark undercut with a pad and a red bag, a
## candle lantern, and a string of faded prayer flags along the lip). Same
## ramps, light and rim as Camp 4. Written to assets/sprites/buildings/ as
## crow_*. Replace any PNG with hand-drawn art of the same size at any time.
##
## Every sprite is anchored at its bottom center.

const OVERHANG_SIZE := Vector2i(176, 112)
## How wide the overhang's solid base is, in px (the builder's footprint).
const OVERHANG_BASE := 150

const CROW_FILES := ["crow_cairn", "crow_overhang"]


func save_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_write(cairn(), "crow_cairn")
	_write(overhang(), "crow_overhang")


## Five flat stones stacked knee high, the biggest at the bottom, each lit
## on top and darker underneath.
func cairn() -> Image:
	var w := 22
	var h := 28
	var im := K.make(w, h)
	K.shadow(im, w / 2.0 + 1.0, h - 3.0, 9.0, 2.0, 0.3)
	var stones := [[11.0, 22.0, 8.5, 3.6], [10.5, 17.0, 7.0, 3.0], [11.5, 12.5, 5.5, 2.6], [10.5, 8.5, 4.2, 2.2], [11.0, 5.0, 2.8, 1.8]]
	for i in stones.size():
		var s: Array = stones[i]
		var cx: float = s[0]
		var cy: float = s[1]
		var rx: float = s[2]
		var ry: float = s[3]
		for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
			for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
				var d := Vector2((x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry)
				if d.length() > 1.0:
					continue
				# lit from the upper left; the underside falls into shadow
				var t := 0.55 - d.y * 0.32 - d.x * 0.14 + (K.hash2(x, y, 70 + i) - 0.5) * 0.12
				K.px(im, x, y, FloraArt.shade_c(gr, t, x, y))
	K.outline(im, RIM)
	return im


## A house-sized granite block leaning off the wall, undercut into a dry,
## dark shelter: Crow's pad and bag inside, a candle lantern, and prayer
## flags sagging along the lip.
func overhang() -> Image:
	var w := OVERHANG_SIZE.x
	var h := OVERHANG_SIZE.y
	var im := FloraArt.new().rock(w, h, 1975, 0.12, 0.7, false, 1.0)
	var base := h - 4
	var cx := w / 2.0
	var rx := 58.0
	var ry := 34.0
	# the undercut: darkest at the back, a little light at the mouth
	var cave := _ramp(["0e0c12", "17141c", "201c26", "2c2834", "3b3644"])
	for y in range(int(base - ry), base + 1):
		for x in range(int(cx - rx), int(cx + rx) + 1):
			var d := Vector2((x + 0.5 - cx) / rx, (y + 0.5 - base) / ry)
			if d.length() > 1.0 or im.get_pixel(x, y).a < 0.5:
				continue
			var t := clampf(0.15 + (y - (base - ry)) / ry * 0.55 - absf(d.x) * 0.2, 0.0, 1.0)
			K.px(im, x, y, at(cave, t + (FloraArt.bayer(x, y) - 0.5) * 0.15))
	# the lip: a lit edge of granite over the dark
	for x in range(int(cx - rx) + 2, int(cx + rx) - 1):
		var dx := (x + 0.5 - cx) / rx
		var y := int(base - ry * sqrt(maxf(0.0, 1.0 - dx * dx)))
		K.px(im, x, y - 1, gr[6])
		K.px(im, x, y - 2, gr[5])
	# the floor inside: a foam pad, the red bag, a stuff sack and a book
	var floor_y := base - 4
	poly(im, PackedVector2Array([Vector2(cx - 30, floor_y - 6), Vector2(cx + 4, floor_y - 6), Vector2(cx + 8, floor_y + 1), Vector2(cx - 34, floor_y + 1)]), Color("4a5a36"))
	var bag := _ramp(["4a1414", "6a1c1a", "922a22", "b8402c"])
	for y in range(floor_y - 5, floor_y + 1):
		for x in range(int(cx - 28), int(cx + 2)):
			var t := 0.7 - float(x - (cx - 28)) / 30.0 * 0.5 + (0.5 - float(y - floor_y + 5) / 6.0) * 0.2
			K.px(im, x, y, at(bag, t))
	for x in range(int(cx - 26), int(cx + 2), 4):
		K.vline(im, x, floor_y - 5, 6, bag[0])
	K.ellipse(im, cx + 14, floor_y - 2, 3.0, 2.4, Color("3a5a7a"))
	K.rect(im, int(cx + 20), floor_y - 2, 5, 3, Color("c8b890"))
	K.hline(im, int(cx + 20), floor_y - 2, 5, Color("e8dcc0"))
	# a candle lantern hanging from a cam in the roof, and its light
	var lx := int(cx + 30)
	var ly := int(base - ry * 0.55)
	K.vline(im, lx, ly - 6, 6, iron[2])
	K.rect(im, lx - 1, ly, 3, 4, iron[1])
	K.px(im, lx, ly + 1, Color("ffd890"))
	K.px(im, lx, ly + 2, Color("ffb050"))
	for y in range(ly - 8, ly + 14):
		for x in range(lx - 12, lx + 13):
			var p := im.get_pixel(x, y)
			if p.a < 0.5 or p.v > 0.35:
				continue
			var a := clampf(1.0 - Vector2(x - lx, (y - ly) * 1.3).length() / 12.0, 0.0, 1.0)
			a = floorf(a * 4.0 + FloraArt.bayer(x, y)) / 4.0
			if a > 0.0:
				K.px(im, x, y, p.lerp(Color("c88a4a"), a * 0.45))
	# prayer flags sagging along the lip, faded by the sun
	var flags := [Color("3a6ea6"), Color("e8e0d0"), Color("b8402c"), Color("4a8a4a"), Color("e0b040")]
	var a0 := Vector2(cx - rx + 8, base - ry * 0.62)
	var a1 := Vector2(cx + rx - 10, base - ry * 0.62)
	sag_line(im, a0, a1, 7.0, Color("8a7a5a"))
	var n := 13
	for i in n:
		var t := (i + 0.5) / n
		var p := a0.lerp(a1, t) + Vector2(0, sin(t * PI) * 7.0)
		var c: Color = flags[i % flags.size()]
		K.rect(im, int(p.x) - 1, int(p.y) + 1, 3, 3, c.lerp(Color("d8d0c0"), 0.25))
		K.px(im, int(p.x) + 1, int(p.y) + 3, c.darkened(0.3))
	K.outline(im, RIM)
	return im
