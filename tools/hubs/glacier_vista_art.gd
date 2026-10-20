extends "res://tools/hubs/glacier_art.gd"
## The painting seen over the edge at Glacier Point, in the spirit of the
## title painting: not a map of the Valley floor from above but the view as
## you'd paint it standing at the railing. Sky and summer cumulus, the High
## Sierra on the horizon, Clouds Rest, Half Dome across the canyon with its
## sheer face lit and the shells of its back, the north wall of the Valley
## with Yosemite Falls, Royal Arches and North Dome, the forest and meadows of
## the floor with the Merced winding through, and lower down to the right,
## for Washburn Point, Mount Broderick and Liberty Cap with Nevada Fall beside
## it, Vernal Fall in the gorge below and Illilouette Fall in its cleft.
##
## It is drawn at 16px scale and is bigger than the screen: the game shows it
## through the drop (scripts/world/vista.gd) and slides it a little as you
## walk, so the tip of the point frames Half Dome and Washburn Point frames
## the falls. Written to assets/sprites/glacier/vista.png; the 32px upgrade
## gives it the title painting's palette dither (tools/art32/passes.py).

const VISTA_SIZE := Vector2i(820, 500)
## The falls in the painting, for the shimmer: top and bottom of each, in
## painting pixels at 16px scale, and the half width at the top and bottom.
const VISTA_FALLS := [
	[Vector2(150, 30), Vector2(152, 128), Vector2(1.5, 3.5)], # Upper Yosemite Fall
	[Vector2(154, 136), Vector2(156, 160), Vector2(0.8, 1.2)], # the Middle Cascades
	[Vector2(157, 170), Vector2(158, 198), Vector2(1.2, 2.2)], # Lower Yosemite Fall
	[Vector2(758, 300), Vector2(760, 344), Vector2(2.5, 4.5)], # Nevada Fall
	[Vector2(690, 381), Vector2(690, 402), Vector2(2.5, 3.0)], # Vernal Fall
	[Vector2(800, 352), Vector2(801, 392), Vector2(1.0, 2.0)], # Illilouette Fall
]

const SKY := [Color("235679"), Color("3a86a8"), Color("9fd8d9")]
const CLOUD := [Color("7088a2"), Color("a6b8c8"), Color("e8eef0"), Color("f5eee0")]
const RANGE := [Color("5c5f8c"), Color("7088a2"), Color("a6b8c8"), Color("eef2f4")]
const WARM := Color("d6bd88")
const LEAF := [Color("12291d"), Color("1d3f2b"), Color("2c5c37"), Color("437f45"), Color("5c8f3c")]
const GRASS := [Color("5c8f3c"), Color("84b04a"), Color("aecb62")]
const WATER := [Color("3a86a8"), Color("63b3c6"), Color("9fd8d9"), Color("d6f1ee")]
const HORIZON := Color("63b3c6")

var _v: Image
var _sd := 9100


func vista() -> Image:
	_v = K.make(VISTA_SIZE.x, VISTA_SIZE.y)
	_sky()
	_clouds()
	_high_sierra()
	_clouds_rest()
	_north_wall()
	_half_dome_face_on()
	_floor()
	_panorama_cliff()
	_dome_at(650.0, 282.0, 372.0, 50.0, 0.2, 0.35, _sd + 40) # Mount Broderick
	_dome_at(716.0, 236.0, 372.0, 46.0, 0.7, 0.3, _sd + 41) # Liberty Cap
	_gorge()
	for f: Array in VISTA_FALLS:
		_fall(f[0], f[1], f[2])
	_near_forest()
	return _v


# ---------------------------------------------------------------- helpers

func _put(x: int, y: int, col: Color) -> void:
	if x >= 0 and y >= 0 and x < VISTA_SIZE.x and y < VISTA_SIZE.y:
		_v.set_pixel(x, y, col)


func _fbm(x: float, y: float, sd: int) -> float:
	return vnoise(x, y, sd) * 0.55 + vnoise(x * 2.1, y * 2.1, sd + 1) * 0.3 + vnoise(x * 4.3, y * 4.3, sd + 2) * 0.15


## A color along [param ramp] at [param t] (0 to 1), blended between steps;
## the upgrade's dither turns the blends back into palette pixels.
static func _along(ramp: Array, t: float) -> Color:
	var f := clampf(t, 0.0, 1.0) * (ramp.size() - 1)
	var i := mini(int(f), ramp.size() - 2)
	return (ramp[i] as Color).lerp(ramp[i + 1], f - i)


## Distance haze: everything far off goes toward the pale horizon.
## Kept light, so the colors stay near the palette and the upgrade's dither
## stays calm.
static func _haze(col: Color, amount: float) -> Color:
	return col.lerp(HORIZON, clampf(amount * 0.5, 0.0, 1.0))


# ---------------------------------------------------------------- the sky

func _sky() -> void:
	for y in VISTA_SIZE.y:
		var t := clampf(y / 210.0, 0.0, 1.0)
		var col: Color = SKY[0].lerp(SKY[1], minf(t * 1.6, 1.0)) if t < 0.62 else SKY[1].lerp(SKY[2], (t - 0.62) / 0.38)
		for x in VISTA_SIZE.x:
			_v.set_pixel(x, y, col)


## Summer cumulus: a few big heaps with flat grey bottoms, their tops lit
## from the sun on the left and lavender shade underneath.
const CUMULUS := [Vector3(120, 70, 70), Vector3(300, 50, 55), Vector3(470, 84, 48), Vector3(690, 60, 80), Vector3(810, 96, 40)]


func _cloud_d(x: float, y: float) -> float:
	var best := -1.0
	for c: Vector3 in CUMULUS:
		var base := c.y + c.z * 0.18
		if y > base:
			continue
		var q := Vector2((x - c.x) / c.z, (y - base) / (c.z * 0.55))
		var lump := (_fbm(x * 0.03, y * 0.05, _sd + 3) - 0.5) * 0.9
		best = maxf(best, 1.0 - q.length() + lump)
	return best


func _clouds() -> void:
	for y in range(0, 160):
		for x in VISTA_SIZE.x:
			var d := _cloud_d(x, y)
			if d <= 0.0:
				continue
			var lit := _cloud_d(x - 3, y - 4)
			var col: Color
			if lit < d - 0.05:
				col = CLOUD[3] # the sunlit rim
			elif lit < d + 0.02:
				col = CLOUD[2]
			else:
				col = CLOUD[2].lerp(CLOUD[1], clampf((lit - d) * 6.0, 0.0, 1.0))
			# the flat, shaded underside
			for c: Vector3 in CUMULUS:
				var base := c.y + c.z * 0.18
				if absf(x - c.x) < c.z * 1.4 and y > base - c.z * 0.16 and y <= base:
					col = col.lerp(CLOUD[0], 0.55)
			if d < 0.04:
				col = col.lerp(_v.get_pixel(x, y), 0.4)
			_v.set_pixel(x, y, col)


# ---------------------------------------------------------------- far off

## The crest of the Sierra along the horizon: ridged, hazy blue-violet, with
## snow lying in the gullies and on the north faces.
func _high_sierra() -> void:
	for x in VISTA_SIZE.x:
		var ridge := 1.0 - absf(vnoise(x * 0.018, 1.0, _sd + 5) * 2.0 - 1.0)
		var peaks := ridge * 26.0 + vnoise(x * 0.06, 2.0, _sd + 6) * 10.0 + vnoise(x * 0.2, 3.0, _sd + 7) * 3.0
		var top := int(156.0 - peaks)
		var slope := (vnoise((x + 1) * 0.018, 1.0, _sd + 5) - vnoise((x - 1) * 0.018, 1.0, _sd + 5))
		for y in range(top, 262):
			var depth := y - top
			var col: Color = RANGE[1] if slope > 0.0 else RANGE[0]
			if depth < 2:
				col = RANGE[2]
			var snow := vnoise(x * 0.25, y * 0.18, _sd + 8)
			if depth < 18 - int((156 - top) * 0.1) and snow > 0.5 - depth * 0.012:
				col = RANGE[3] if slope > -0.01 else RANGE[2]
			_v.set_pixel(x, y, _haze(col, 0.35 + depth * 0.004))


## Clouds Rest, the long ridge climbing behind Half Dome from the left.
func _clouds_rest() -> void:
	# and the forested ridges of the Merced's canyon, far off to the right
	for x in range(640, VISTA_SIZE.x):
		var top := int(206.0 - (x - 640) * 0.08 + (vnoise(x * 0.05, 12.0, _sd + 11) - 0.5) * 10.0)
		for y in range(top, 262):
			var col := _along([LEAF[1], LEAF[2], LEAF[3]], 0.4 + (vnoise(x * 0.15, y * 0.15, _sd + 12) - 0.5) * 0.8 - (y - top) * 0.01)
			if y - top < 1:
				col = LEAF[3]
			_v.set_pixel(x, y, _haze(col, 0.7))
	for x in range(300, 600):
		var t := (x - 300) / 300.0
		var top := int(lerpf(178.0, 112.0, pow(t, 0.8)) + (vnoise(x * 0.08, 4.0, _sd + 9) - 0.5) * 5.0)
		for y in range(top, 240):
			var depth := y - top
			var tex := vnoise(x * 0.3, y * 0.12, _sd + 10)
			var col := _along(SHADE, 0.55 - depth * 0.006 + (tex - 0.5) * 0.25)
			if depth > 30 and K.hash2(x, y, _sd + 11) > 0.7 - depth * 0.004:
				col = LEAF[2]
			_v.set_pixel(x, y, _haze(col, 0.42))


# ---------------------------------------------------------------- the walls

## Granite in the afternoon: warm where the sun reaches, cool lavender-grey in
## shade. [param t] runs from deep shade (0) to full sun (1).
const SHADE := [Color("2d3050"), Color("47464d"), Color("6a6a70"), Color("8d8c9a"), Color("bdb8ae"), Color("d6bd88"), Color("e4ddcc")]


## The north wall of the Valley: Yosemite Point's cliff with the falls, the
## low cleft of Indian Canyon, then Royal Arches under North Dome, and the
## mouth of Tenaya Canyon before Half Dome.
func _north_top(x: float) -> float:
	var n := (vnoise(x * 0.05, 5.0, _sd + 12) - 0.5) * 8.0
	if x < 40.0:
		return 40.0 + n
	if x < 250.0:
		return 24.0 + n + smoothstep(225.0, 250.0, x) * 10.0
	if x < 300.0:
		return lerpf(36.0, 74.0, smoothstep(250.0, 300.0, x)) + n
	if x < 360.0:
		return lerpf(74.0, 64.0, (x - 300.0) / 60.0) + n * 0.5
	if x < 470.0:
		# North Dome, a rounded hump on the rim
		var u := (x - 418.0) / 52.0
		return minf(70.0 + n * 0.5, 50.0 + u * u * 26.0)
	return lerpf(72.0, 176.0, smoothstep(470.0, 525.0, x)) + n * 0.5


func _north_wall() -> void:
	for x in 530:
		var top := int(_north_top(x))
		var shade_side := _north_top(x + 3.0) < _north_top(x - 3.0) - 1.5
		for y in range(top, 262):
			var depth := y - top
			# buttresses and gullies: each buttress lit on its left flank
			var broad := vnoise(x * 0.045, y * 0.006, _sd + 18)
			var turn := vnoise((x + 3) * 0.045, y * 0.006, _sd + 18) - vnoise((x - 3) * 0.045, y * 0.006, _sd + 18)
			var streak := vnoise(x * 0.6, y * 0.02, _sd + 14)
			# lit high up, shading down into the forest's shadow at the foot
			var t := 0.72 - depth * 0.0026 + (broad - 0.5) * 0.3 + turn * 2.2 + (streak - 0.5) * 0.16
			if shade_side:
				t -= 0.25
			var col := _along(SHADE, t)
			if streak < 0.24:
				col = _along(SHADE, t - 0.28) # dark water streaks
			if depth < 2:
				col = SHADE[6] if not shade_side else SHADE[4]
			# Royal Arches: great curved overhangs, dark under each lip
			if x > 318 and x < 440:
				var ax := (x - 378.0) / 60.0
				var arc := fmod(y - 96.0 + ax * ax * 40.0, 15.0)
				if y > 98 and y < 200:
					if arc < 1.2:
						col = SHADE[1]
					elif arc < 3.0:
						col = _along(SHADE, t - 0.15)
			# ledges with trees, more of them low down
			var ledge := vnoise(x * 0.1, y * 0.3, _sd + 15)
			if ledge > 0.88 - depth * 0.0016 and K.hash2(x / 2, y / 2, _sd + 16) > 0.5:
				col = LEAF[1] if K.hash2(x, y, _sd + 17) > 0.45 else LEAF[2]
			_v.set_pixel(x, y, _haze(col, 0.28))
		# a fringe of trees along the rim
		if K.hash2(x, 0, _sd + 19) > 0.55:
			_conifer(x, top + 1, 2 + int(K.hash2(x, 1, _sd + 19) * 3.0), 0.35)


## Half Dome from Glacier Point: the sheer face on the left, nearly edge on
## and in cool shade, the summit, and the great curved back falling away to
## the right in the sun, in broad shells; its lower slopes broken and wooded.
const HD_FACE := 548.0
const HD_TOP := 46.0


func _hd_top(x: float) -> float:
	if x < HD_FACE:
		return 200.0 - (x - 486.0) * 0.55 # the shoulder below the face
	if x < HD_FACE + 26.0:
		return HD_TOP + 6.0 * pow(1.0 - (x - HD_FACE) / 26.0, 2.0) # the lip, rounding off
	var u := (x - HD_FACE - 26.0) / 175.0
	return HD_TOP + pow(u, 2.1) * 160.0


func _half_dome_face_on() -> void:
	for x in range(486, 740):
		var top := _hd_top(x)
		for y in range(int(top), 262):
			var depth := y - top
			var col: Color
			var face_w := 12.0 + (y - HD_TOP) * 0.1
			var on_face := x >= HD_FACE and x < HD_FACE + face_w and y < 158.0
			var lower := y > 172.0 + (vnoise(x * 0.06, 3.0, _sd + 28) - 0.5) * 24.0 - maxf(0.0, 600.0 - x) * 0.3 or x < HD_FACE
			if on_face:
				# the face, edge on, in shade with long dark streaks
				var streak := vnoise(x * 0.9, y * 0.035, _sd + 20)
				col = _along(SHADE, 0.28 + (x - HD_FACE) / face_w * 0.22 + (streak - 0.5) * 0.4)
				if x < HD_FACE + 1.5:
					col = SHADE[3] # its sunlit edge against the sky
			elif lower:
				# the lower slopes: forest, with outcrops of shaded granite
				var rock := vnoise(x * 0.08, y * 0.1, _sd + 21) + (150.0 - y) * 0.004
				if rock > 0.58:
					col = _along(SHADE, 0.35 + (rock - 0.58) * 1.5 + (vnoise(x * 0.4, y * 0.1, _sd + 22) - 0.5) * 0.2)
				else:
					col = _along([LEAF[0], LEAF[1], LEAF[2]], 0.3 + (vnoise(x * 0.2, y * 0.2, _sd + 23) - 0.4) * 0.9)
			else:
				# the back: sunlit and curving away, in a few broad shells
				var u := clampf((x - HD_FACE) / 190.0, 0.0, 1.0)
				var t := 1.0 - u * 0.5 - depth * 0.0028 + (vnoise(x * 0.05, y * 0.05, _sd + 25) - 0.5) * 0.12
				var shell := fmod(depth * 0.04 + vnoise(x * 0.02, y * 0.03, _sd + 24) * 1.6, 1.0)
				var broken := vnoise(x * 0.09, y * 0.09, _sd + 26)
				if shell < 0.05 and broken > 0.45:
					t -= 0.32
				elif shell < 0.2:
					t += 0.06
				col = _along(SHADE, t)
				if depth < 1.5:
					col = SHADE[6]
			_v.set_pixel(x, y, _haze(col, 0.16 + maxf(0.0, (y - 150.0) * 0.0015)))
	# trees standing on the lower shoulders
	for i in 90:
		var tx := 486 + int(K.hash2(i, 1, _sd + 27) * 250.0)
		var ty := int(maxf(_hd_top(tx), 168.0)) + 4 + int(K.hash2(i, 2, _sd + 27) * 70.0)
		_conifer(tx, ty, 3 + int(K.hash2(i, 3, _sd + 27) * 3.0), 0.25)


# ---------------------------------------------------------------- the floor

## The floor of the Valley and the canyon below: forest, meadows and the
## Merced, the trees growing bigger as they come nearer (lower).
const MERCED := [Vector2(690, 404), Vector2(650, 428), Vector2(580, 424), Vector2(500, 392), Vector2(420, 352),
	Vector2(340, 318), Vector2(240, 296), Vector2(130, 282), Vector2(0, 276)]
const MEADOWS := [Vector3(250, 270, 40), Vector3(400, 306, 44), Vector3(110, 266, 30), Vector3(520, 350, 36), Vector3(300, 290, 22)]


func _floor_top(x: int) -> int:
	return 244 + int(vnoise(x * 0.04, 7.0, _sd + 30) * 10.0)


func _nearness(y: float) -> float:
	return clampf((y - 240.0) / 260.0, 0.0, 1.0)


func _meadow(x: float, y: float) -> float:
	var best := -1.0
	var near := _nearness(y)
	for m: Vector3 in MEADOWS:
		var q := Vector2((x - m.x) / m.z, (y - m.y) / (m.z * (0.18 + near * 0.25)))
		best = maxf(best, 1.0 - q.length() + (vnoise(x * 0.08, y * 0.16, _sd + 32) - 0.5) * 0.5)
	return best


func _floor() -> void:
	# the ground under the trees, in groves of light and shade
	for x in VISTA_SIZE.x:
		for y in range(_floor_top(x), VISTA_SIZE.y):
			var near := _nearness(y)
			var grove := _fbm(x * 0.018, y * 0.04, _sd + 31)
			var col := _along([LEAF[0], LEAF[1], LEAF[2]], 0.2 + (grove - 0.5) * 1.2)
			if _meadow(x, y) > 0.0:
				col = _along([LEAF[3], GRASS[0], GRASS[1]], 0.2 + vnoise(x * 0.15, y * 0.3, _sd + 33) * 0.7)
			_v.set_pixel(x, y, _haze(col, 0.45 - near * 0.42))
	# the Merced, catching the sky
	for x in VISTA_SIZE.x:
		for y2 in range(240, VISTA_SIZE.y):
			var near := _nearness(y2)
			var d := _dist_to_line(Vector2(x, y2), MERCED, 1.0)
			var w := lerpf(1.2, 5.0, near)
			if d < w + 1.5:
				var col: Color = LEAF[0] if d >= w else (WATER[2] if K.hash2(x / 3, y2, _sd + 38) > 0.55 else WATER[1])
				_v.set_pixel(x, y2, _haze(col, 0.4 - near * 0.38))
	# the trees, back to front, rows growing taller
	var y := 240.0
	var row := 0
	while y < VISTA_SIZE.y + 14:
		var near := _nearness(y)
		var h := lerpf(4.0, 16.0, near)
		var x := -4.0 + K.hash2(row, 0, _sd + 34) * h
		while x < VISTA_SIZE.x + 4:
			var yy := int(y + (K.hash2(int(x), row, _sd + 35) - 0.5) * h * 0.6)
			var open := _meadow(x, yy) > 0.12 or _dist_to_line(Vector2(x, yy), MERCED, 1.0) < lerpf(2.0, 7.0, near)
			var grove := _fbm(x * 0.018, yy * 0.04, _sd + 31)
			if yy >= _floor_top(int(x)) + 2 and not open and K.hash2(int(x), row, _sd + 36) < 0.45 + grove:
				var th := int(h * (0.7 + K.hash2(int(x), row, _sd + 37) * 0.6))
				_conifer(int(x), yy, th, 0.45 - near * 0.42)
			x += h * (0.45 + K.hash2(int(x), row, _sd + 38) * 0.5)
		y += h * 0.4
		row += 1


## A conifer [param h] pixels tall with its foot at ([param x], [param y]):
## a ragged spire of tiers, lit on the left, shaded on the right.
func _conifer(x: int, y: int, h: int, haze_amount: float) -> void:
	h = maxi(h, 3)
	var dark := _haze(LEAF[0], haze_amount)
	var mid := _haze(LEAF[1], haze_amount)
	var light := _haze(LEAF[2], haze_amount)
	var lit := _haze(LEAF[3], haze_amount)
	for r in h:
		var yy := y - h + r
		var tier := r % 3
		var half := int((r + 1) * 0.34 + (0.7 if tier == 2 else 0.0))
		for dx in range(-half, half + 1):
			var col := mid
			if dx < 0:
				col = lit if (dx == -half and tier == 2) else light
			if dx > 0 and (dx == half or tier == 0):
				col = dark
			if r == 0:
				col = light
			_put(x + dx, yy, col)
	_put(x, y, dark)


# ---------------------------------------------------------------- Washburn's view

## Panorama Cliff behind the falls, with the cleft Illilouette Fall drops into.
func _panorama_cliff() -> void:
	for x in range(728, VISTA_SIZE.x):
		var top := int(262.0 - (x - 728) * 0.15 + (vnoise(x * 0.08, 8.0, _sd + 42) - 0.5) * 6.0)
		for y in range(top, 420):
			var depth := y - top
			var streak := vnoise(x * 0.5, y * 0.03, _sd + 43)
			var col := _along(SHADE, 0.75 - depth * 0.004 + (streak - 0.5) * 0.4)
			if absf(x - 800.5) < 5.0 - depth * 0.02 and y > 345:
				col = SHADE[1] # the cleft
			if depth < 1:
				col = SHADE[6]
			var ledge := vnoise(x * 0.12, y * 0.3, _sd + 44)
			if ledge > 0.72 and K.hash2(x / 2, y / 2, _sd + 45) > 0.3:
				col = LEAF[1]
			_v.set_pixel(x, y, _haze(col, 0.12))


## A granite dome standing out of the forest: its top at ([param cx],
## [param top]), its foot at [param base], [param rx] wide each side, its
## steep side to the left by [param lean].
func _dome_at(cx: float, top: float, base: float, rx: float, lean: float, haze_amount: float, sd: int) -> void:
	var ht := base - top
	for x in range(int(cx - rx * 1.4), int(cx + rx * 1.4) + 1):
		var dx := (x - cx) / rx
		var s := dx * (1.0 + lean) if dx < 0.0 else dx * (1.0 - lean * 0.4)
		if absf(s) >= 1.0:
			continue
		var y0 := base - ht * pow(1.0 - s * s, 0.45)
		for y in range(int(y0), int(base)):
			var depth := y - y0
			var t := 0.95 - (dx + 1.0) * 0.28 - depth * 0.004 + (vnoise(x * 0.3, y * 0.06, sd) - 0.5) * 0.18
			var shell := fmod(depth * 0.05 + vnoise(x * 0.04, y * 0.04, sd + 3) * 1.4, 1.0)
			if shell < 0.06 and vnoise(x * 0.1, y * 0.1, sd + 4) > 0.5:
				t -= 0.25
			var col := _along(SHADE, t)
			if depth < 1.2:
				col = SHADE[6] if dx < 0.3 else SHADE[4]
			var hgt := (base - y) / ht
			if hgt < 0.3 and K.hash2(x / 2, y / 2, sd + 1) > hgt * 3.0:
				col = LEAF[1] if K.hash2(x, y, sd + 2) > 0.5 else LEAF[2]
			_v.set_pixel(x, y, _haze(col, haze_amount * 0.4))


## The gorge of the Merced below the falls: the cliff band Vernal Fall pours
## over.
func _gorge() -> void:
	for x in range(646, 736):
		var top := 374 + int((vnoise(x * 0.1, 9.0, _sd + 46) - 0.5) * 5.0) + int(absf(x - 690.0) * 0.06)
		for y in range(top, 410):
			var col := _along(SHADE, 0.62 - (y - top) * 0.012 + (vnoise(x * 0.4, y * 0.08, _sd + 47) - 0.5) * 0.3)
			if y == top:
				col = SHADE[6]
			_v.set_pixel(x, y, col)


## A waterfall from [param a] to [param b]: a white column with blue-white
## streaks, wider at the foot, and its mist.
func _fall(a: Vector2, b: Vector2, half: Vector2) -> void:
	for y in range(int(a.y), int(b.y) + 1):
		var t := inverse_lerp(a.y, b.y, y)
		var mid := lerpf(a.x, b.x, t)
		var w := lerpf(half.x, half.y, t)
		for x in range(int(mid - w - 1), int(mid + w + 2)):
			var e := absf(x + 0.5 - mid) / w
			if e > 1.0:
				continue
			var col: Color = WATER[3] if vnoise(x * 0.8, y * 0.15, _sd + 50) > 0.4 else CLOUD[2]
			if e > 0.75:
				col = WATER[2]
			_put(x, y, col)
	# the mist at the foot
	for i in 50:
		var mx := b.x + (K.hash2(i, 1, int(b.x)) - 0.5) * half.y * 5.0
		var my := b.y - 2.0 + K.hash2(i, 2, int(b.x)) * half.y * 1.8
		_put(int(mx), int(my), CLOUD[2] if i % 3 else WATER[3])


## The nearest forest, along the bottom right, in front of the domes' feet.
func _near_forest() -> void:
	var y := 346.0
	var row := 0
	while y < VISTA_SIZE.y + 16:
		var near := _nearness(y)
		var h := lerpf(4.0, 16.0, near)
		var x := 600.0 + K.hash2(row, 3, _sd + 60) * h
		while x < VISTA_SIZE.x + 4:
			var yy := int(y + (K.hash2(int(x), row, _sd + 61) - 0.5) * h * 0.5)
			var clear := absf(x - 690.0) < 10.0 and yy < 414 # keep Vernal Fall clear
			clear = clear or (absf(x - 760.0) < 8.0 and yy < 350) or (absf(x - 800.0) < 6.0 and yy < 396)
			if not clear and K.hash2(int(x), row, _sd + 62) > 0.2:
				_conifer(int(x), yy, int(h * (0.8 + K.hash2(int(x), row, _sd + 63) * 0.5)), 0.08 - near * 0.08)
			x += h * (0.5 + K.hash2(int(x), row, _sd + 64) * 0.5)
		y += h * 0.42
		row += 1
