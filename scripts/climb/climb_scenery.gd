class_name ClimbScenery
extends RefCounted
## Paints the climbing screen's pictures: the sky and mountain layers behind
## the wall, the clouds, and the granite wall itself, in the game's pixel
## style (flat ramp shading, a dark rim, light from the upper left).
##
## Colors follow the time of day, so a dawn start is purple and pink, midday
## is blue, and an evening finish glows orange. Everything is drawn once into
## Images (per pitch, or when the light changes), not every frame.

const SCREEN := Vector2i(480, 270)

## Hour -> sky colors (top, middle, horizon), sun, and how the granite is lit.
const KEYS := [
	{"h": 0.0, "top": "0b1028", "mid": "18203f", "low": "2a3258", "sun": "e8e8f0", "rock": "5a6488", "rim": "8a94c0"},
	{"h": 5.0, "top": "141a3a", "mid": "2c2c58", "low": "4a3a6a", "sun": "f0e0f0", "rock": "6a6490", "rim": "a090c0"},
	{"h": 6.5, "top": "4a3c80", "mid": "a07cba", "low": "f6c8cc", "sun": "fff0d8", "rock": "8a74a8", "rim": "f0c0d8"},
	{"h": 9.0, "top": "3e7cc8", "mid": "86bce6", "low": "d6ecf4", "sun": "fffbe8", "rock": "8c8a86", "rim": "e8dcc0"},
	{"h": 16.0, "top": "3a74c0", "mid": "80b4e0", "low": "e0ecf0", "sun": "fff6d8", "rock": "8a8682", "rim": "f0dcb8"},
	{"h": 18.5, "top": "2a3a72", "mid": "7a78b0", "low": "f4b480", "sun": "ffd8a0", "rock": "6a6a88", "rim": "f8b880"},
	{"h": 20.0, "top": "141c44", "mid": "3a3a70", "low": "a86a7a", "sun": "f8a878", "rock": "4e5274", "rim": "c08090"},
	{"h": 24.0, "top": "0b1028", "mid": "18203f", "low": "2a3258", "sun": "e8e8f0", "rock": "5a6488", "rim": "8a94c0"},
]
## Ordered-dither threshold map, for soft steps between flat bands.
const BAYER := [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


## The palette for [param hour] (0-24, may run past 24 after midnight),
## blended between the nearest keys.
static func palette(hour: float) -> Dictionary:
	hour = fposmod(hour, 24.0)
	for i in KEYS.size() - 1:
		var a: Dictionary = KEYS[i]
		var b: Dictionary = KEYS[i + 1]
		if hour >= a.h and hour <= b.h:
			var t: float = (hour - a.h) / maxf(b.h - a.h, 0.001)
			var out := {}
			for key in ["top", "mid", "low", "sun", "rock", "rim"]:
				out[key] = Color(a[key]).lerp(Color(b[key]), t)
			out["night"] = hour < 5.5 or hour > 20.5
			out["hour"] = hour
			return out
	return palette(12.0)


## The sky: three colors stepped into flat bands with dithered seams, a sun
## (or moon), and stars at night.
static func sky(pal: Dictionary) -> Image:
	var im := Image.create_empty(SCREEN.x, SCREEN.y, false, Image.FORMAT_RGBA8)
	# The pattern repeats every 4 pixels across, so paint one 4-wide strip
	# and copy it along the sky.
	var strip := Image.create_empty(4, SCREEN.y, false, Image.FORMAT_RGBA8)
	var bands := 9
	for y in SCREEN.y:
		var t := y / float(SCREEN.y - 1)
		for x in 4:
			# Quantize, with a Bayer threshold so neighbouring bands interleave.
			var q: float = t * bands + (BAYER[y % 4][x] / 16.0 - 0.5) * 0.9
			var step := clampf(floorf(q) / bands, 0.0, 1.0)
			strip.set_pixel(x, y, _sky_at(pal, step))
	for x in range(0, SCREEN.x, 4):
		im.blit_rect(strip, Rect2i(0, 0, 4, SCREEN.y), Vector2i(x, 0))
	var hour: float = pal.hour
	if pal.night:
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		for i in 90:
			var p := Vector2i(rng.randi_range(0, SCREEN.x - 1), rng.randi_range(0, 150))
			im.set_pixelv(p, Color(1, 1, 0.95, rng.randf_range(0.4, 1.0)))
		_disc(im, Vector2i(410, 46), 7, Color("e8e8f0"), Color("b8bcd0"))
	else:
		# The sun climbs out of the east in the morning and drops west at night.
		var day_t := clampf((hour - 5.5) / 15.0, 0.0, 1.0)
		var sun := Vector2i(int(lerpf(440, 330, day_t)), int(150 - sin(day_t * PI) * 120))
		_glow(im, sun, 26, pal.sun)
		_disc(im, sun, 6, pal.sun, (pal.sun as Color).darkened(0.08))
	return im


static func _sky_at(pal: Dictionary, t: float) -> Color:
	if t < 0.5:
		return (pal.top as Color).lerp(pal.mid, t * 2.0)
	return (pal.mid as Color).lerp(pal.low, (t - 0.5) * 2.0)


static func _disc(im: Image, c: Vector2i, r: int, col: Color, shade: Color) -> void:
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			if x * x + y * y <= r * r and _inside(c + Vector2i(x, y)):
				im.set_pixelv(c + Vector2i(x, y), shade if x + y > r / 2 else col)


static func _glow(im: Image, c: Vector2i, r: int, col: Color) -> void:
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var p := c + Vector2i(x, y)
			var d := sqrt(x * x + y * y) / r
			if d < 1.0 and _inside(p):
				var a := (1.0 - d) * 0.35
				if BAYER[p.y % 4][p.x % 4] / 16.0 < a * 2.2:
					im.set_pixelv(p, im.get_pixelv(p).lerp(col, 0.35))


static func _inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < SCREEN.x and p.y < SCREEN.y


## Four ridgelines, far to near, each a silhouette that fades toward the sky
## color with distance. The farthest has a dome on it. Returned as separate
## images so they can slide at different speeds as you climb.
static func mountains(pal: Dictionary, seed_value: int) -> Array[Image]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var layers: Array[Image] = []
	var dark := (pal.top as Color).darkened(0.55)
	var specs := [
		{"base": 150, "amp": 46, "freq": 0.012, "fade": 0.28, "dome": true},
		{"base": 172, "amp": 34, "freq": 0.02, "fade": 0.45, "dome": false},
		{"base": 196, "amp": 26, "freq": 0.03, "fade": 0.62, "dome": false},
		{"base": 228, "amp": 14, "freq": 0.05, "fade": 0.82, "dome": false, "trees": true},
	]
	for spec: Dictionary in specs:
		var im := Image.create_empty(SCREEN.x, SCREEN.y + 80, false, Image.FORMAT_RGBA8)
		var col := (pal.low as Color).lerp(dark, spec.fade)
		var lit := col.lerp(pal.rim, 0.18)
		var p1 := rng.randf() * TAU
		var p2 := rng.randf() * TAU
		var p3 := rng.randf() * TAU
		for x in SCREEN.x:
			var f: float = spec.freq
			var top: float = spec.base - spec.amp * (0.55 * sin(x * f + p1) + 0.3 * sin(x * f * 2.3 + p2) + 0.15 * sin(x * f * 5.1 + p3))
			if spec.dome:
				# A granite dome with a sheer face, standing above the far ridge.
				# Rounded on the left, cut off sheer on the right, like Half Dome.
				var dx := (x - 420) / 40.0
				if dx > -1.2 and dx < 0.3:
					top = minf(top, 108.0 + 34.0 * dx * dx)
			if spec.get("trees", false) and int(x + p1 * 10) % 7 < 5:
				# A forested ridge: little pointed conifers along the top.
				var k := int(x + p1 * 10) % 7
				top -= [2, 5, 8, 5, 2][k]
			var y0 := int(top)
			im.fill_rect(Rect2i(x, y0, 1, im.get_height() - y0), col)
			# Sunlit slopes catch the light on the left of each rise.
			if x > 0 and spec.fade < 0.7:
				var prev: float = spec.base - spec.amp * (0.55 * sin((x - 1) * f + p1) + 0.3 * sin((x - 1) * f * 2.3 + p2) + 0.15 * sin((x - 1) * f * 5.1 + p3))
				if prev > top:
					im.fill_rect(Rect2i(x, y0, 1, 3), lit)
		layers.append(im)
	return layers


## A small puffy cloud, white on top and shaded underneath.
static func cloud(pal: Dictionary, seed_value: int) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var w := rng.randi_range(36, 64)
	var im := Image.create_empty(w, 22, false, Image.FORMAT_RGBA8)
	var lit := (pal.low as Color).lerp(Color.WHITE, 0.75)
	var shade := (pal.mid as Color).lerp(Color.WHITE, 0.35)
	var puffs := []
	for i in rng.randi_range(3, 5):
		puffs.append(Vector3(rng.randi_range(8, w - 8), rng.randi_range(9, 13), rng.randi_range(5, 9)))
	for y in 22:
		for x in w:
			for p: Vector3 in puffs:
				var d := Vector2(x - p.x, (y - p.y) * 1.3).length()
				if d <= p.z and y <= 17:
					im.set_pixel(x, y, shade if y > p.y + 1 else lit)
					break
	return im


## The granite wall for one pitch, from [param rows_below] rows under the belay
## ledge to [param rows_above] rows over the top ledge. Columnar facets with lit
## left edges and dark seams, joints, speckles and a few tufts of grass; the
## right-hand edge is ragged against the sky. Cracks, holds and ledges for the
## pitch are drawn on top (see [method paint_holds]).
static func wall(width: int, height: int, seed_value: int, pal: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var im := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	var rock: Color = pal.rock
	var rim: Color = pal.rim
	var seam := rock.darkened(0.45)
	# Facets: vertical bands, each broken by joints into blocks of slightly
	# different shades, like the columns in the reference pictures.
	var x := 0
	while x < width:
		var bw := rng.randi_range(9, 26)
		var y := 0
		while y < height:
			var bh := rng.randi_range(50, 170)
			var shade := rock.darkened(rng.randf_range(-0.06, 0.16))
			im.fill_rect(Rect2i(x, y, bw, bh), shade)
			# Light from the upper left: a lit strip on the left of each block.
			im.fill_rect(Rect2i(x, y, 2, bh), shade.lerp(rim, 0.35))
			im.fill_rect(Rect2i(x + 2, y, 1, bh), shade.lerp(rim, 0.15))
			# A darker shade in the right third, dithered into the face.
			for yy in range(y, mini(y + bh, height)):
				for xx in range(x + bw * 2 / 3, mini(x + bw - 1, width)):
					if BAYER[yy % 4][xx % 4] < 8 or xx > x + bw * 5 / 6:
						im.set_pixel(xx, yy, shade.darkened(0.1))
			# Joint across the block's top: a dark line with a lit lip below.
			im.fill_rect(Rect2i(x, y, bw, 1), seam)
			im.fill_rect(Rect2i(x, y + 1, bw, 1), shade.lerp(rim, 0.25))
			y += bh
		im.fill_rect(Rect2i(x + bw - 1, 0, 1, height), seam)
		x += bw
	# Speckles: feldspar glints and dark crystals.
	for i in width * height / 40:
		var p := Vector2i(rng.randi_range(0, width - 1), rng.randi_range(0, height - 1))
		var c := im.get_pixelv(p)
		im.set_pixelv(p, c.lightened(0.12) if rng.randf() < 0.5 else c.darkened(0.15))
	# Grass and shrub tufts in a few seams.
	for i in height / 60:
		var p := Vector2i(rng.randi_range(4, width - 30), rng.randi_range(4, height - 6))
		_tuft(im, p, rng)
	# The ragged right edge against the sky, with a lit rim and a dark outline.
	var edge := PackedInt32Array()
	edge.resize(height)
	var y := 0
	var ex := width - 10
	while y < height:
		var run := rng.randi_range(5, 18)
		ex = clampi(ex + rng.randi_range(-5, 5), width - 22, width - 2)
		for k in run:
			if y + k < height:
				edge[y + k] = ex + (1 if k % 6 == 0 else 0)
		y += run
	for yy in height:
		var e := edge[yy]
		im.fill_rect(Rect2i(e, yy, width - e, 1), Color(0, 0, 0, 0))
		im.fill_rect(Rect2i(maxi(e - 3, 0), yy, 2, 1), rim.lerp(rock, 0.3))
		im.set_pixel(maxi(e - 1, 0), yy, seam.darkened(0.3))
	return {"image": im, "edge": edge}


static func _tuft(im: Image, p: Vector2i, rng: RandomNumberGenerator) -> void:
	var greens := [Color("4a7a3a"), Color("6a9a48"), Color("365a2c")]
	for i in rng.randi_range(4, 8):
		var q := p + Vector2i(rng.randi_range(-3, 3), rng.randi_range(-2, 0))
		if q.x >= 0 and q.y >= 0 and q.x < im.get_width() and q.y < im.get_height():
			im.set_pixelv(q, greens[rng.randi() % greens.size()])


## Draws the pitch's ledges, cracks and holds onto [param im]. [param to_px]
## maps (row, column) to the hold's pixel center in the image. Holds are
## chalky nubs: big for easy ones, small for hard ones.
static func paint_holds(im: Image, state: ClimbState, to_px: Callable, pal: Dictionary, edge := PackedInt32Array()) -> void:
	var rim: Color = pal.rim
	var rock: Color = pal.rock
	var ledge_top := rock.lerp(rim, 0.5)
	var ledge := rock.darkened(0.05)
	var shadow := rock.darkened(0.5)
	for r in [0, state.top_row]:
		var c: Vector2 = to_px.call(r, 0)
		var y := int(c.y) + 6
		var w := im.get_width()
		if y >= 0 and y < edge.size():
			w = edge[y] + 4
		im.fill_rect(Rect2i(0, y, w, 5), ledge)
		im.fill_rect(Rect2i(0, y, w, 1), ledge_top)
		im.fill_rect(Rect2i(0, y + 5, w - 4, 2), shadow)
		var rng := RandomNumberGenerator.new()
		rng.seed = r * 31 + state.pitch
		for i in 5:
			_tuft(im, Vector2i(rng.randi_range(4, im.get_width() - 40), y - 1), rng)
	var base := 2 + state.route.pitches[mini(state.pitch, state.route.pitches.size() - 1)] * 2
	for r in range(1, state.top_row):
		for col: int in state.holds.get(r, {}):
			var hold: Dictionary = state.holds[r][col]
			var p := Vector2i(to_px.call(r, col))
			if hold.crack:
				# A seam splitting the face: dark, with a lit lip on the left.
				im.fill_rect(Rect2i(p.x + 3, p.y - 11, 2, 22), shadow)
				im.fill_rect(Rect2i(p.x + 2, p.y - 11, 1, 22), ledge_top)
			var hard: bool = hold.cost > base + 2
			var easy: bool = hold.cost <= base + 1
			var chalk := Color("efe6d6")
			var nub := Color("d9a066").lerp(rock, 0.25) if not hard else Color("b8865a").lerp(rock, 0.4)
			if easy:
				im.fill_rect(Rect2i(p.x - 3, p.y - 1, 6, 3), nub)
				im.fill_rect(Rect2i(p.x - 2, p.y - 2, 4, 1), chalk)
				im.fill_rect(Rect2i(p.x - 3, p.y + 2, 6, 1), shadow)
			elif hard:
				im.fill_rect(Rect2i(p.x - 1, p.y - 1, 3, 2), nub)
				im.fill_rect(Rect2i(p.x - 1, p.y + 1, 3, 1), shadow)
			else:
				im.fill_rect(Rect2i(p.x - 2, p.y - 1, 5, 2), nub)
				im.fill_rect(Rect2i(p.x - 1, p.y - 2, 3, 1), chalk)
				im.fill_rect(Rect2i(p.x - 2, p.y + 1, 5, 1), shadow)
