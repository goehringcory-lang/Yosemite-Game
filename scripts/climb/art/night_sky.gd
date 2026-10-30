class_name NightSky
extends RefCounted
## The night sky over the Sierra, shared by the climbing, slackline and bivy
## screens: the Milky Way rising out of the southern horizon (bright star
## clouds, the dark dust lane of the Great Rift splitting it, a warm glow
## toward the galaxy's centre), and stars of every brightness and colour,
## thickest along the band. [method paint] lays the still part into a sky
## Image once; [method draw] adds the moving part every frame: the bright
## stars twinkling and now and then a shooting star. Both fade in with
## [param amount] (0 day, 1 full night), so the first stars come out at dusk.
## Everything is whole pixels and dithered, never blurred.

const P := preload("res://scripts/climb/art/climb_paint.gd")
## The band's centre line across a 480 x 270 sky: rising steeply out of the
## ridges (where the galaxy's centre sits low in the south) through the open
## sky to the right of the wall, which every screen leaves clear.
const BAND_FROM := Vector2(280, 250)
const BAND_TO := Vector2(480, -30)
const BAND_HALF := 34.0

## Star colours: blue-white, white, pale gold, orange.
const STAR_COLS := [Color("cfe2ff"), Color("f5f2ea"), Color("f3dfa8"), Color("f0a878")]


## Lays the Milky Way and the still stars into [param im] above row
## [param bottom] (the horizon), at [param amount] of their full strength.
static func paint(im: Image, amount: float, bottom := 200, seed_value := 77) -> void:
	if amount <= 0.02:
		return
	var w := im.get_width()
	bottom = mini(bottom, im.get_height())
	var axis := (BAND_TO - BAND_FROM).normalized()
	var normal := Vector2(-axis.y, axis.x)
	var core := Color("dfe4f0")
	var warm := Color("f0d8b0")
	for y in bottom:
		for x in w:
			var p := Vector2(x, y) - BAND_FROM
			var across := p.dot(normal)
			if absf(across) > BAND_HALF * 1.7:
				continue
			var along := p.dot(axis) / (BAND_TO - BAND_FROM).length()
			# clumpy star clouds: two scales of hashed value noise
			var clump := _vnoise(x / 9.0, y / 9.0, seed_value) * 0.6 + _vnoise(x / 3.5, y / 3.5, seed_value + 5) * 0.4
			var width := BAND_HALF * (1.15 - along * 0.45)
			var g := exp(-pow(across / width, 2.0) * 2.2)
			# the Great Rift: a dark lane just off the centre line, broken up
			var rift := exp(-pow((across - 4.0 + sin(along * 9.0) * 5.0) / (width * 0.22), 2.0)) * smoothstep(0.08, 0.3, along) * (1.0 - smoothstep(0.75, 0.95, along))
			var light := g * (0.35 + clump * 0.9) - rift * (0.55 + _vnoise(x / 5.0, y / 5.0, seed_value + 9) * 0.5)
			# brightest low down, toward the galaxy's centre
			light *= lerpf(1.35, 0.6, clampf(along, 0.0, 1.0)) * amount
			if light <= 0.05:
				continue
			# three flat steps, dithered into each other
			var n: float = (P.BAYER[y & 3][x & 3] + 0.5) / 16.0
			var step := floorf(light * 3.0 + n - 0.5) / 3.0
			if step <= 0.0:
				continue
			var col := core.lerp(warm, clampf(0.45 - along, 0.0, 0.45) * 1.6)
			var base := im.get_pixel(x, y)
			im.set_pixel(x, y, base.lerp(col, clampf(step * 0.42, 0.0, 0.48)))
	# the stars: many faint ones, packed tighter along the band, and a few
	# bright ones with a cross of light
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in 900:
		var x := rng.randi_range(0, w - 1)
		var y := rng.randi_range(0, bottom - 1)
		var across := absf((Vector2(x, y) - BAND_FROM).dot(normal))
		var in_band := exp(-pow(across / BAND_HALF, 2.0) * 1.5)
		# away from the band, most candidates are dropped
		if rng.randf() > 0.22 + in_band * 0.78:
			continue
		var mag := rng.randf()
		var col: Color = STAR_COLS[_pick_colour(rng.randf())]
		# fainter near the horizon, where the air is thick
		var a := (0.3 + mag * mag * 0.7) * amount * clampf((bottom - y) / 40.0, 0.25, 1.0)
		var base := im.get_pixel(x, y)
		im.set_pixel(x, y, base.lerp(col, clampf(a, 0.0, 1.0)))


## The stars that twinkle and the odd shooting star, drawn each frame over the
## painted sky. [param time] in seconds; only above row [param bottom].
static func draw(ci: CanvasItem, time: float, amount: float, bottom := 200, seed_value := 77, width := 480) -> void:
	if amount <= 0.02:
		return
	for i in 46:
		var x := floorf(P.noise(i, 1, seed_value) * width)
		var y := floorf(pow(P.noise(i, 2, seed_value), 1.3) * bottom)
		var speed := 0.7 + P.noise(i, 3, seed_value) * 2.6
		var tw := 0.5 + 0.5 * sin(time * speed + i * 1.7) * sin(time * speed * 0.37 + i)
		var col: Color = STAR_COLS[_pick_colour(P.noise(i, 4, seed_value))]
		var a := (0.35 + 0.65 * tw) * amount * clampf((bottom - y) / 40.0, 0.25, 1.0)
		ci.draw_rect(Rect2(x, y, 1, 1), Color(col, a))
		# the brightest few flare into a little cross as they twinkle
		if i % 7 == 0 and tw > 0.55:
			var arm := Color(col, a * 0.45)
			ci.draw_rect(Rect2(x - 1, y, 1, 1), arm)
			ci.draw_rect(Rect2(x + 1, y, 1, 1), arm)
			ci.draw_rect(Rect2(x, y - 1, 1, 1), arm)
			ci.draw_rect(Rect2(x, y + 1, 1, 1), arm)
	# A shooting star every so often, in a different place each time.
	var period := 9.0
	var k := floorf(time / period)
	var ph := time - k * period
	var dur := 0.8
	if ph < dur and P.noise(int(k), 7, seed_value) < 0.75:
		var p := ph / dur
		var from := Vector2(60.0 + P.noise(int(k), 8, seed_value) * (width - 120.0), 14.0 + P.noise(int(k), 9, seed_value) * bottom * 0.4)
		var dir := Vector2(-1.0 if P.noise(int(k), 10, seed_value) < 0.5 else 1.0, 0.45).normalized()
		var head := from + dir * p * 90.0
		for j in 14:
			var at := (head - dir * j).floor()
			var fade := (1.0 - j / 14.0) * (1.0 - p * 0.7) * amount
			ci.draw_rect(Rect2(at, Vector2.ONE), Color(1, 0.97, 0.88, 0.9 * fade))


static func _pick_colour(r: float) -> int:
	if r < 0.3:
		return 0
	if r < 0.8:
		return 1
	if r < 0.94:
		return 2
	return 3


## Smooth hashed value noise in 0..1.
static func _vnoise(x: float, y: float, seed_value: int) -> float:
	var ix := int(floor(x))
	var iy := int(floor(y))
	var fx := x - ix
	var fy := y - iy
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := lerpf(P.noise(ix, iy, seed_value), P.noise(ix + 1, iy, seed_value), fx)
	var b := lerpf(P.noise(ix, iy + 1, seed_value), P.noise(ix + 1, iy + 1, seed_value), fx)
	return lerpf(a, b, fy)
