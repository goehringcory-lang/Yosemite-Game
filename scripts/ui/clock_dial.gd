class_name ClockDial
extends Control
## The little window of sky on the clock, like Stardew Valley's dial: the sun
## climbs over Half Dome and sets as the day goes by, the moon follows it at
## night with the stars out, the sky turns from dawn to day to dusk, Half Dome
## and the Valley pines follow the seasons, and the day's weather shows as
## drifting clouds, rain or snow. HUD puts it beside the date.

const W := 34
const H := 22
## The sun crosses from 6 AM to 8 PM; the moon from 8 PM to 6 AM.
const SUN_RISE := 6.0
const SUN_SET := 20.0
const FRAME := Color("241509")
const BEVEL_LIT := Color("ecca80")
const BEVEL_SHADE := Color("774a28")
const NIGHT := Color("2d3050")
const DAWN := Color("b0925f")
const DAY := Color("63b3c6")
const GOLDEN := Color("ffd48a")
const DUSK := Color("d9772a")
const GRANITE := Color("47464d")
const GRANITE_LIT := Color("6a6a70")
const GRANITE_SNOW := Color("dfe8f2")
const PINES := Color("1d3f2b")
const PINES_LIT := Color("2f5d3c")
const PINES_FALL := Color("c97b2c")
const PINES_SPRING := Color("f2b8c6")
const SUN := Color("f1cf6a")
const SUN_CORE := Color("fff8e6")
const MOON := Color("e4f6f4")
const STARS := [Vector2i(5, 4), Vector2i(11, 7), Vector2i(17, 3), Vector2i(24, 6), Vector2i(29, 4), Vector2i(8, 10), Vector2i(27, 10)]
## Half Dome's skyline from the Valley floor, one height a column.
## The sheer face is on the left, the rounded back falls away to the right.
const SKYLINE := [2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 6, 13, 14, 14, 14, 14, 13, 13, 12, 11, 10, 9, 8, 7, 7, 6, 6, 5, 5, 4, 4, 3, 3, 2]

var _time := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameClock.time_changed.connect(queue_redraw.unbind(2))
	GameClock.day_started.connect(queue_redraw.unbind(3))


func _process(delta: float) -> void:
	_time += delta
	# Stars twinkle at night; clouds drift gently; rain and snow fall.
	var weather := Weather.today()
	var wet := float(weather.get("rain", 0.0)) > 0.0 or float(weather.get("snow", 0.0)) > 0.0
	if wet:
		if int(_time * 6.0) != int((_time - delta) * 6.0):
			queue_redraw()
	elif _hour() >= SUN_SET or _hour() < SUN_RISE:
		if int(_time * 4.0) != int((_time - delta) * 4.0):
			queue_redraw()
	elif float(weather.get("clouds", 0.0)) > 0.45:
		if int(_time * 2.0) != int((_time - delta) * 2.0):
			queue_redraw()


## The hour as a number that runs past midnight (25.5 is 1:30 AM).
static func _hour() -> float:
	return GameClock.minutes / 60.0


## The sky's color at [param hour].
static func sky_color(hour: float) -> Color:
	var h := fposmod(hour, 24.0)
	if h < 5.0 or h >= 21.5:
		return NIGHT
	if h < 6.5:
		return NIGHT.lerp(DAWN, smoothstep(5.0, 6.5, h))
	if h < 8.5:
		return DAWN.lerp(DAY, smoothstep(6.5, 8.5, h))
	if h < 18.0:
		return DAY
	if h < 19.0:
		return DAY.lerp(GOLDEN, smoothstep(18.0, 19.0, h))
	if h < 20.0:
		return GOLDEN.lerp(DUSK, smoothstep(19.0, 20.0, h))
	return DUSK.lerp(NIGHT, smoothstep(20.0, 21.5, h))


## Where the sun or moon sits at [param hour], in the dial's pixels.
static func body_position(hour: float) -> Vector2:
	var t: float
	if hour >= SUN_RISE and hour < SUN_SET:
		t = (hour - SUN_RISE) / (SUN_SET - SUN_RISE)
	else:
		t = fposmod(hour - SUN_SET, 24.0) / (24.0 - SUN_SET + SUN_RISE)
	var angle := PI * (1.0 - t)
	return Vector2(W / 2.0 + cos(angle) * 13.0, 17.0 - sin(angle) * 13.0)


func _px(x: int, y: int, color: Color) -> void:
	if x >= 2 and y >= 2 and x < W - 2 and y < H - 2:
		draw_rect(Rect2(x, y, 1, 1), color)


func _disc(center: Vector2, r: float, color: Color) -> void:
	for y in range(floori(center.y - r), ceili(center.y + r) + 1):
		for x in range(floori(center.x - r), ceili(center.x + r) + 1):
			if Vector2(x + 0.5, y + 0.5).distance_to(center) <= r:
				_px(x, y, color)


func _draw() -> void:
	var hour := _hour()
	var night := hour >= SUN_SET or hour < SUN_RISE
	var sky := sky_color(hour)
	var weather := Weather.today()
	var clouds: float = weather.get("clouds", 0.0)
	if clouds >= 1.0:
		sky = sky.lerp(Color("93918f") if not night else Color("2b2a30"), 0.55)
	# Outer dark wood outline + inner beveled brass window frame.
	draw_rect(Rect2(0, 0, W, H), FRAME)
	draw_rect(Rect2(1, 1, W - 2, 1), BEVEL_LIT)
	draw_rect(Rect2(1, 1, 1, H - 2), BEVEL_LIT)
	draw_rect(Rect2(1, H - 2, W - 2, 1), BEVEL_SHADE)
	draw_rect(Rect2(W - 2, 1, 1, H - 2), BEVEL_SHADE)
	# Three-band dithered atmospheric sky gradient: deep zenith -> mid sky -> warm horizon.
	var zenith := sky.darkened(0.24 if not night else 0.32)
	var horizon := sky.lightened(0.22 if not night else 0.08)
	if not night and (hour < 8.5 or hour > 17.5):
		horizon = horizon.lerp(GOLDEN, 0.35)
	for y in range(2, H - 2):
		var v := float(y - 2) / float(H - 5)
		for x in range(2, W - 2):
			var c := sky
			if v < 0.28:
				c = zenith
			elif v < 0.38 and (x + y) % 2 == 0:
				c = zenith
			elif v > 0.72:
				c = horizon
			elif v > 0.62 and (x + y) % 2 == 0:
				c = horizon
			_px(x, y, c)
	if night and clouds < 1.0:
		for i in STARS.size():
			var star: Vector2i = STARS[i]
			var phase := sin(_time * 2.0 + i * 1.7)
			if phase > -0.35:
				var alpha := 0.95 if phase > 0.4 else 0.65
				_px(star.x, star.y, Color(0.98, 0.95, 0.88, alpha))
				if phase > 0.75 and i % 2 == 0:
					_px(star.x - 1, star.y, Color(0.85, 0.92, 1.0, 0.35))
					_px(star.x + 1, star.y, Color(0.85, 0.92, 1.0, 0.35))
	# The sun or crescent moon on its arc.
	var body := body_position(hour)
	if night:
		_disc(body, 2.6, MOON)
		_disc(body + Vector2(1.2, -0.6), 2.0, zenith if body.y < 8.0 else sky)
	else:
		# Soft warm sun halo when clear.
		if clouds < 0.8:
			_disc(body, 4.0, Color(SUN, 0.25))
		_disc(body, 2.9, SUN.darkened(0.08))
		_disc(body, 2.1, SUN)
		_disc(body + Vector2(-0.6, -0.6), 1.0, SUN_CORE)
	if clouds >= 1.0 or clouds > 0.45:
		var drift := fposmod(_time * 0.5, float(W - 4))
		_cloud(Vector2(2.0 + fposmod(21.0 + drift, float(W - 4)), 5.0), night)
		if clouds >= 1.0:
			_cloud(Vector2(2.0 + fposmod(7.0 + drift * 0.7, float(W - 4)), 7.0), night)
	# Half Dome and the Valley pines, subtly answering the season.
	var season := GameClock.season
	var snowy := season == GameClock.Season.WINTER or float(weather.get("snow", 0.0)) > 0.0
	for x in range(2, W - 2):
		var height: int = SKYLINE[x]
		var top_y := H - 2 - height
		for y in range(top_y, H - 2):
			var crown := y == top_y
			var sunset_face := x == 11 and hour > 16.0 and hour < SUN_SET
			var c := GRANITE
			if snowy and (crown or (y == top_y + 1 and x >= 11 and x <= 17)):
				c = GRANITE_SNOW
			elif sunset_face:
				c = GOLDEN.lerp(DUSK, 0.35)
			elif crown or (x == 11 and not night):
				c = GRANITE_LIT
			elif x > 18 and y > top_y + 2:
				c = GRANITE.darkened(0.14)
			_px(x, y, c.darkened(0.38 if night else 0.0))
	for x in range(2, W - 2, 3):
		var tree := 2 + (x * 7) % 3
		for y in range(H - 2 - tree, H - 2):
			var tip := y == H - 2 - tree
			var leaf := PINES_LIT if tip else PINES
			if snowy and tip:
				leaf = GRANITE_SNOW
			elif season == GameClock.Season.FALL and tip and (x % 2 == 0):
				leaf = PINES_FALL
			elif season == GameClock.Season.SPRING and tip and (x % 6 == 2):
				leaf = PINES_SPRING
			leaf = leaf.darkened(0.35 if night else 0.0)
			_px(x, y, leaf)
			if y > H - 1 - tree:
				_px(x - 1, y, PINES.darkened(0.35 if night else 0.0))
	# Rain or snow over everything.
	var rain: float = weather.get("rain", 0.0)
	var snow: float = weather.get("snow", 0.0)
	if rain > 0.0 or snow > 0.0:
		var fall := int(_time * 6.0)
		for i in 9:
			var x := 3 + (i * 11) % (W - 6)
			var y := 3 + (i * 5 + fall) % (H - 6)
			if rain > 0.0:
				_px(x, y, Color("8cd2e6"))
				_px(x, y + 1, Color("63b3c6"))
			else:
				_px(x, y, Color.WHITE)
	# Subtle 1px inner top shadow under the brass bezel so the sky sits recessed.
	draw_rect(Rect2(2, 2, W - 4, 1), Color(0.06, 0.04, 0.03, 0.25))


func _cloud(at: Vector2, night: bool) -> void:
	var color := Color("f5eee0") if not night else Color("6a6a70")
	var shade := Color("d6d0c4") if not night else Color("4a4a55")
	_disc(at + Vector2(0, 0.7), 2.2, shade)
	_disc(at, 2.3, color)
	_disc(at + Vector2(3, 0.6), 1.9, color)
	_disc(at + Vector2(-3, 0.8), 1.7, color)
