class_name ClimbSky
extends RefCounted
## The sky behind the climbing screen: colors that follow the game clock
## (purple and pink at dawn, blue at midday, orange at dusk, stars at night),
## a sun or moon, clouds, and a tint the other painters use to light the rock.
## Everything is drawn once into Images, not every frame.

const SCREEN := Vector2i(480, 270)

## Hour -> sky colors (top, middle, horizon), sun, and how the granite is lit.
const KEYS := [
	{"h": 0.0, "top": "0b1028", "mid": "18203f", "low": "2a3258", "sun": "e8e8f0", "rock": "5a6488", "rim": "8a94c0", "tint": "7a86c0", "lum": 0.55},
	{"h": 5.0, "top": "141a3a", "mid": "2c2c58", "low": "4a3a6a", "sun": "f0e0f0", "rock": "6a6490", "rim": "a090c0", "tint": "8a98d0", "lum": 0.62},
	{"h": 6.5, "top": "4a3c80", "mid": "a07cba", "low": "f6c8cc", "sun": "fff0d8", "rock": "8a74a8", "rim": "f0c0d8", "tint": "b4b8e4", "lum": 0.88},
	{"h": 8.0, "top": "4a78c4", "mid": "8ab8e0", "low": "e4dcec", "sun": "fffbe8", "rock": "8c8a96", "rim": "ece0d4", "tint": "e8e4f0", "lum": 1.0},
	{"h": 9.0, "top": "3e7cc8", "mid": "86bce6", "low": "d6ecf4", "sun": "fffbe8", "rock": "8c8a86", "rim": "e8dcc0", "tint": "fff4e0", "lum": 1.05},
	{"h": 16.0, "top": "3a74c0", "mid": "80b4e0", "low": "e0ecf0", "sun": "fff6d8", "rock": "8a8682", "rim": "f0dcb8", "tint": "fff0d4", "lum": 1.05},
	{"h": 17.5, "top": "3a68b4", "mid": "88a8d8", "low": "f0d4b0", "sun": "ffe8b8", "rock": "8a8480", "rim": "f4d0a0", "tint": "ffe0b8", "lum": 1.03},
	{"h": 18.5, "top": "2a3a72", "mid": "7a78b0", "low": "f4b480", "sun": "ffd8a0", "rock": "6a6a88", "rim": "f8b880", "tint": "ffb488", "lum": 0.98},
	{"h": 19.3, "top": "1e2a5c", "mid": "5c4c8c", "low": "e08a7a", "sun": "f8a070", "rock": "5a5878", "rim": "e89890", "tint": "e89a90", "lum": 0.86},
	{"h": 20.0, "top": "141c44", "mid": "3a3a70", "low": "a86a7a", "sun": "f8a878", "rock": "4e5274", "rim": "c08090", "tint": "a07ca0", "lum": 0.7},
	{"h": 24.0, "top": "0b1028", "mid": "18203f", "low": "2a3258", "sun": "e8e8f0", "rock": "5a6488", "rim": "8a94c0", "tint": "7a86c0", "lum": 0.55},
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
			for key in ["top", "mid", "low", "sun", "rock", "rim", "tint"]:
				out[key] = Color(a[key]).lerp(Color(b[key]), t)
			out["lum"] = lerpf(a.lum, b.lum, t)
			out["night"] = hour < 5.5 or hour > 20.5
			out["hour"] = hour
			# Alpenglow: the sunlit faces glow orange-pink at dusk and a cool
			# lavender at dawn; shadows stay as they are.
			var dusk := clampf(1.0 - absf(hour - 18.9) / 1.5, 0.0, 1.0)
			var dawn := clampf(1.0 - absf(hour - 6.4) / 1.1, 0.0, 1.0)
			out["glow"] = maxf(dusk, dawn * 0.7)
			out["glow_col"] = Color("ff8a52") if dusk >= dawn else Color("b8a4f0")
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


