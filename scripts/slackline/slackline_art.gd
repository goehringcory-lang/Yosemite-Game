class_name SlacklineArt
extends RefCounted
## The pictures behind the Camp 4 slackline screen, painted in code with the
## climbing screen's kit (ClimbSky, ClimbLandscape, ClimbProps) so the light
## matches the hour: the sky and the far walls across the Valley (Glacier
## Point, Sentinel Rock and Cathedral Rocks, as you see them from Camp 4),
## the campground under its pines, and the two trees each line is strung
## between. Each picture is painted once when the screen opens or the line
## changes; the minigame draws the moving parts on top.

const P := preload("res://scripts/climb/art/climb_paint.gd")
const SCREEN := Vector2i(480, 270)
## The campground floor, the same for every line.
const GROUND_Y := 232
const DARK := Color("2a1b14")
## What you see across the Valley from Camp 4 (ClimbLandscape landmarks).
const VIEW := [
	{"k": "glacier_point", "x": 420, "s": 1.3, "l": 0},
	{"k": "sentinel_rock", "x": 330, "s": 1.05, "l": 1},
	{"k": "cathedral_rocks", "x": 150, "s": 1.0, "l": 1},
	{"k": "sierra_crest", "x": 300, "s": 1.0, "l": 2},
]
## Who's watching from the boulders and tables: a ClimbProfiles.BELAYERS
## look, where their feet are, and whether they're sitting.
const CROWD := [
	{"look": "wren_alvarez", "at": Vector2(176, 246), "sit": true},
	{"look": "warren_harding", "at": Vector2(238, 258), "sit": true},
	{"look": "beverly_johnson", "at": Vector2(300, 252), "sit": false},
	{"look": "royal_robbins", "at": Vector2(384, 262), "sit": true},
]
## Where the campfire burns (the minigame draws its flames).
const FIRE := Vector2(214, 246)
## The stump at the far end of the Camp 4 line, where the six-pack sits.
const STUMP_X := 462.0


## The whole still background for [param pal] (a ClimbSky palette): sky, far
## walls, the forest round Camp 4, the boulders, tents and the dirt. Without
## [param camp] it's a quiet clearing anywhere in the park: the same woods,
## with no tents, table, fire ring or crash pads.
static func backdrop(pal: Dictionary, seed_value: int, camp := true) -> Image:
	var im := ClimbSky.sky(pal)
	var land := ClimbLandscape.build({"view": VIEW}, pal, seed_value)
	# The three skyline layers, as they look from the ground. The last layer
	# is the valley floor seen from above, which isn't wanted down here.
	for i in 3:
		var layer: Dictionary = land.layers[i]
		var src: Image = layer.image
		im.blend_rect(src, Rect2i(0, 0, src.get_width(), src.get_height()), Vector2i(0, -int(layer.pad) - 40))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var rc := ClimbRock.colors("apron", pal)
	var haze := (pal.low as Color).lerp(pal.mid, 0.45)
	# The far edge of the campground: a hazy wall of pines.
	for i in 26:
		var x := i * 19 + rng.randi_range(-6, 6)
		ClimbProps.pine(im, x, GROUND_Y - 26 + rng.randi_range(-3, 3), rng.randi_range(70, 104), rng, pal)
	P.rect(im, 0, 120, SCREEN.x, GROUND_Y - 120, Color(haze, 0.32))
	# The shady forest floor under them, with trunks going back into the dark.
	var floor_dk := ClimbProps._lit(Color("1d3326"), pal)
	var floor_md := ClimbProps._lit(Color("2c4a30"), pal)
	for y in range(GROUND_Y - 30, GROUND_Y):
		var t := float(y - (GROUND_Y - 30)) / 30.0
		for x in SCREEN.x:
			# a soft dithered edge on top, then solid shade
			if t > 0.2 or P.dither(x, y, t * 5.0):
				im.set_pixel(x, y, floor_dk if t > 0.5 else floor_md)
	for i in 40:
		var x := rng.randi_range(0, SCREEN.x - 2)
		var top := GROUND_Y - rng.randi_range(26, 44)
		P.rect(im, x, top, 2, GROUND_Y - top, ClimbProps._lit(Color("47301f"), pal).lerp(floor_dk, 0.4))
	# Nearer pines and black oaks, darker and crisper.
	for i in 13:
		var x := i * 38 + rng.randi_range(-10, 10)
		if i % 4 == 1:
			ClimbProps.oak(im, x, GROUND_Y - 4, rng.randi_range(50, 64), rng, pal)
		else:
			ClimbProps.pine(im, x, GROUND_Y - 6 + rng.randi_range(-2, 2), rng.randi_range(84, 120), rng, pal)
	_ground(im, pal, rng)
	if not camp:
		ClimbProps.boulder(im, 148, GROUND_Y + 10, 9, 6, rc, rng, false)
		ClimbProps.boulder(im, 430, GROUND_Y + 6, 12, 7, rc, rng, true)
		return im
	# Talus and boulders at the back, with chalk on the big one.
	_big_boulder(im, 92, GROUND_Y + 4, rc, pal, rng)
	ClimbProps.boulder(im, 30, GROUND_Y + 8, 16, 9, rc, rng, true)
	ClimbProps.boulder(im, 148, GROUND_Y + 10, 9, 6, rc, rng, false)
	ClimbProps.boulder(im, 430, GROUND_Y + 6, 12, 7, rc, rng, true)
	# Tents, a picnic table, the fire ring and a stack of firewood.
	ClimbProps.dome_tent(im, 318, GROUND_Y + 2, 34, 20, Color("d9772a"), pal)
	ClimbProps.ridge_tent(im, 360, GROUND_Y + 4, 30, 18, Color("bdb8ae"), pal)
	ClimbProps.dome_tent(im, 268, GROUND_Y + 6, 26, 15, Color("6f5aa6"), pal)
	ClimbProps.picnic_table(im, 222, GROUND_Y + 8, 28, pal)
	_fire_ring(im, int(FIRE.x), int(FIRE.y), pal, rc)
	ClimbProps.log_pile(im, 182, GROUND_Y + 18, 14, pal)
	ClimbProps.log_pile(im, 186, GROUND_Y + 14, 12, pal)
	# Crash pads leaning on the big boulder, red and blue.
	P.rect(im, 118, GROUND_Y - 6, 14, 12, DARK)
	P.rect(im, 119, GROUND_Y - 5, 12, 10, ClimbProps._lit(Color("b3362b"), pal))
	P.rect(im, 119, GROUND_Y - 5, 12, 1, ClimbProps._lit(Color("d9772a"), pal))
	P.rect(im, 64, GROUND_Y - 2, 12, 9, DARK)
	P.rect(im, 65, GROUND_Y - 1, 10, 7, ClimbProps._lit(Color("3a5a8a"), pal))
	return im


## Dirt and duff under the pines: bands of brown, needles, pine cones, and a
## worn path along the line where everyone walks back to the start.
static func _ground(im: Image, pal: Dictionary, rng: RandomNumberGenerator) -> void:
	var cols: Array[Color] = []
	for hx: String in ["3a3224", "5a4c34", "7a6a46", "9c8a5c"]:
		cols.append(ClimbProps._lit(Color(hx), pal))
	var h := SCREEN.y - GROUND_Y
	for y in h:
		var t := float(y) / h
		for x in SCREEN.x:
			var n := P.smooth_noise(x * 0.07, y * 0.3, 11)
			var v := 1.6 + t * 0.9 + (n - 0.5) * 1.1
			# the path: a lighter, packed strip
			if y > 12 and y < 22:
				v += 0.6
			var k := clampi(int(v + (P.BAYER[y % 4][x % 4] / 16.0 - 0.5) * 0.8), 0, 3)
			im.set_pixel(x, GROUND_Y + y, cols[3 - k])
	# the line where the dirt meets the forest floor behind
	P.rect(im, 0, GROUND_Y, SCREEN.x, 1, cols[0])
	# needles and cones
	for i in 220:
		var x := rng.randi_range(0, SCREEN.x - 3)
		var y := rng.randi_range(GROUND_Y + 2, SCREEN.y - 1)
		P.rect(im, x, y, rng.randi_range(2, 3), 1, cols[rng.randi_range(0, 1)])
	for i in 9:
		var x := rng.randi_range(4, SCREEN.x - 6)
		var y := rng.randi_range(GROUND_Y + 4, SCREEN.y - 4)
		P.rect(im, x, y, 3, 2, ClimbProps._lit(Color("6b4829"), pal))
		P.px(im, x, y, ClimbProps._lit(Color("92693d"), pal))
	ClimbProps.grass_row(im, 0, SCREEN.x, GROUND_Y + 1, rng, pal, 6, true, 2)


## A big block like Columbia Boulder, settled into the dirt and chalked up
## its face, with the lightning bolt beside the start.
static func _big_boulder(im: Image, x: int, y: int, rc: Dictionary, pal: Dictionary, rng: RandomNumberGenerator) -> void:
	ClimbProps.boulder(im, x + 22, y - 10, 24, 16, rc, rng, false)
	ClimbProps.boulder(im, x - 4, y - 18, 36, 24, rc, rng, true)
	_bury(im, x - 44, x + 50, y - 2, pal)
	var ch := ClimbProps._lit(Color("f5eee0"), pal)
	for i in 16:
		P.px(im, x - 8 + rng.randi_range(-6, 14), y - 30 + rng.randi_range(-10, 14), ch)
	var bolt := [Vector2(x + 14, y - 34), Vector2(x + 10, y - 26), Vector2(x + 15, y - 26), Vector2(x + 10, y - 16)]
	for i in bolt.size() - 1:
		P.line(im, bolt[i], bolt[i + 1], ch)


## Dirt piled over the foot of a rock from [param x0] to [param x1], from
## row [param y] down, with a ragged top.
static func _bury(im: Image, x0: int, x1: int, y: int, pal: Dictionary) -> void:
	var dirt := ClimbProps._lit(Color("7a6a46"), pal)
	var lip := ClimbProps._lit(Color("9c8a5c"), pal)
	for x in range(maxi(x0, 0), mini(x1, SCREEN.x)):
		var top := y + int(P.noise(x, y, 3) * 3.0)
		P.rect(im, x, top, 1, 8, dirt)
		P.px(im, x, top, lip)


static func _fire_ring(im: Image, x: int, y: int, pal: Dictionary, rc: Dictionary) -> void:
	P.ellipse(im, x, y, 12, 4.6, DARK)
	P.ellipse(im, x, y, 10, 3.2, ClimbProps._lit(Color("2a1b14"), pal))
	for i in 9:
		var a := float(i) / 9.0 * TAU
		var sx := x + cos(a) * 10.0
		var sy := y + sin(a) * 3.6
		P.ellipse(im, sx, sy, 2.6, 1.9, ClimbRock.tone(rc, 2.0))
		P.px(im, int(sx) - 1, int(sy) - 1, ClimbRock.tone(rc, 3.8))


# ---------------------------------------------------------------- the trees

## One of the two trees a line is strung between, as {"image", "foot"}:
## "foot" is where the trunk's center meets the ground in the image.
## [param young] paints a slim pine with its whole crown in view (the short
## line's); otherwise a big ponderosa whose crown is above the screen.
static func tree(pal: Dictionary, young: bool, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var bark := ClimbProps._lit(Color("6b4829"), pal)
	var bark_lit := ClimbProps._lit(Color("b0925f"), pal)
	var bark_dark := ClimbProps._lit(Color("47301f"), pal)
	var plate := ClimbProps._lit(Color("ad7a22"), pal)
	if young:
		var im := P.make(90, 170)
		var foot := Vector2(45, 166)
		ClimbProps.shadow(im, 45, 167, 14, 2.0, 0.35)
		ClimbProps.pine(im, 45, 120, 116, rng, pal)
		P.rect(im, 40, 60, 10, 107, DARK)
		P.rect(im, 41, 60, 8, 107, bark)
		P.rect(im, 41, 60, 2, 107, bark_lit)
		P.rect(im, 47, 60, 2, 107, bark_dark)
		for y in range(66, 164, 9):
			P.rect(im, 42 + (y / 9) % 2, y, 4, 1, bark_dark)
		# the crown hangs back over the trunk's top
		ClimbProps.pine(im, 45, 100, 90, rng, pal)
		# a dark edge, so it stands out against the forest behind
		P.outline(im, DARK)
		return {"image": im, "foot": foot}
	var im := P.make(120, GROUND_Y + 10)
	var foot := Vector2(60, GROUND_Y)
	ClimbProps.shadow(im, 60, GROUND_Y + 1, 22, 2.5, 0.4)
	# low boughs reaching out of the top of the screen
	for b in [[-1, 18, 46], [1, 34, 44], [-1, 58, 36], [1, 76, 30]]:
		_bough(im, 60, int(b[1]), int(b[0]), int(b[2]), pal, rng)
	# the trunk: puzzle-piece plates of cinnamon bark in dark furrows, lit
	# from the left and falling into shade on the right
	P.rect(im, 49, 0, 22, GROUND_Y, DARK)
	P.rect(im, 50, 0, 20, GROUND_Y, bark_dark)
	var y := rng.randi_range(-8, 0)
	while y < GROUND_Y:
		var x := 50 + rng.randi_range(-3, 0)
		while x < 70:
			var pw := rng.randi_range(5, 10)
			var ph := rng.randi_range(8, 16)
			var py := y + rng.randi_range(-2, 2)
			var x0 := maxi(x + 1, 51)
			var x1 := mini(x + pw - 1, 69)
			if x1 > x0:
				var across := (float(x0 + x1) / 2.0 - 50.0) / 20.0
				var col := plate.lerp(bark, clampf(across * 1.4, 0.0, 1.0))
				if across > 0.7:
					col = bark.lerp(bark_dark, 0.35)
				P.rect(im, x0, py + 1, x1 - x0, ph - 2, col)
				P.rect(im, x0, py + 1, x1 - x0, 1, col.lightened(0.18))
				P.rect(im, x0, py + ph - 2, x1 - x0, 1, col.darkened(0.18))
			x += pw
		y += rng.randi_range(9, 14)
	P.rect(im, 50, 0, 1, GROUND_Y, bark_lit)
	P.rect(im, 68, 0, 2, GROUND_Y, bark_dark)
	# roots flaring into the dirt
	P.rect(im, 42, GROUND_Y - 6, 36, 8, DARK)
	P.rect(im, 43, GROUND_Y - 5, 34, 6, bark)
	P.rect(im, 43, GROUND_Y - 5, 12, 2, plate)
	P.rect(im, 66, GROUND_Y - 4, 11, 5, bark_dark)
	P.outline(im, DARK)
	return {"image": im, "foot": foot}


## A ponderosa bough: a dark branch with tufts of long needles, sunlit on
## top.
static func _bough(im: Image, x: int, y: int, dir: int, length: int, pal: Dictionary, rng: RandomNumberGenerator) -> void:
	var g := ClimbProps._ramp(ClimbProps.PINE, pal)
	var end := x + dir * length
	P.line(im, Vector2(x, y + 4), Vector2(end, y), ClimbProps._lit(Color("47301f"), pal), 2)
	var tufts: Array[Vector2] = []
	for k in 5:
		tufts.append(Vector2(x + dir * (12 + k * (length - 10) / 5.0), y + 1 - k * 0.6 + rng.randi_range(-2, 2)))
	for t in tufts:
		P.blob(im, int(t.x), int(t.y), 6, g[0], rng, 4)
		P.blob(im, int(t.x) - 1, int(t.y) - 2, 4, g[1], rng, 3)
		P.blob(im, int(t.x) - 2, int(t.y) - 3, 2, g[2], rng, 2)
	# needle tips sticking out of the tufts
	for t in tufts:
		for n in 6:
			var a := rng.randf_range(-PI, 0.2)
			var r := rng.randf_range(6.0, 9.0)
			P.px(im, int(t.x + cos(a) * r), int(t.y + sin(a) * r), g[1 if n % 2 == 0 else 2])


## The King Cobra stump at the end of the Camp 4 line, with the six-pack on
## it unless [param taken].
static func stump(pal: Dictionary, taken: bool) -> Image:
	var im := P.make(32, 40)
	var bark := ClimbProps._lit(Color("6b4829"), pal)
	var wood := ClimbProps._lit(Color("d6bd88"), pal)
	ClimbProps.shadow(im, 16, 38, 13, 2.0, 0.35)
	P.rect(im, 2, 22, 28, 17, DARK)
	P.rect(im, 3, 23, 26, 15, bark)
	P.rect(im, 3, 23, 6, 15, bark.lightened(0.18))
	P.rect(im, 24, 23, 5, 15, bark.darkened(0.25))
	P.ellipse(im, 16, 23, 13, 3, DARK)
	P.ellipse(im, 16, 23, 12, 2, wood)
	P.ellipse(im, 16, 23, 6, 1, wood.darkened(0.15))
	if taken:
		return im
	var can := ClimbProps._lit(Color("2b2a30"), pal)
	var band := ClimbProps._lit(Color("d8a63b"), pal)
	for i in 6:
		var cx := 5 + (i % 3) * 7 + (3 if i >= 3 else 0)
		var cy := 8 - (2 if i >= 3 else 0)
		P.rect(im, cx - 1, cy - 1, 7, 15, DARK)
		P.rect(im, cx, cy, 5, 13, can)
		P.rect(im, cx, cy + 4, 5, 3, band)
		P.rect(im, cx + 1, cy, 1, 13, can.lightened(0.25))
		P.rect(im, cx, cy, 5, 1, ClimbProps._lit(Color("bdb8ae"), pal))
	# the plastic rings holding them together
	P.rect(im, 4, 16, 24, 1, Color(0.9, 0.9, 0.85, 0.5))
	return im
