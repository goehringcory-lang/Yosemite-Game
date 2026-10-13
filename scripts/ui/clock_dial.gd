class_name ClockDial
extends Control
## The little window of sky on the clock, like Stardew Valley's dial: the sun
## climbs over Half Dome and sets as the day goes by, the moon follows it at
## night with the stars out, the sky turns from dawn to day to dusk, and the
## day's weather shows as clouds, rain or snow. HUD puts it beside the date.

const W := 34
const H := 22
## The sun crosses from 6 AM to 8 PM; the moon from 8 PM to 6 AM.
const SUN_RISE := 6.0
const SUN_SET := 20.0
const FRAME := Color("2a1b14")
const NIGHT := Color("2d3050")
const DAWN := Color("b0925f")
const DAY := Color("63b3c6")
const GOLDEN := Color("ffd48a")
const DUSK := Color("d9772a")
const GRANITE := Color("47464d")
const GRANITE_LIT := Color("6a6a70")
const PINES := Color("1d3f2b")
const SUN := Color("f1cf6a")
const SUN_CORE := Color("f5eee0")
const MOON := Color("d6f1ee")
const STARS := [Vector2i(5, 4), Vector2i(11, 7), Vector2i(17, 3), Vector2i(24, 6), Vector2i(29, 3), Vector2i(8, 10), Vector2i(27, 10)]
## Half Dome's skyline from the Valley floor, one height a column.
## The sheer face is on the left, the rounded back falls away to the right.
const SKYLINE := [2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 6, 13, 14, 14, 14, 14, 13, 13, 12, 11, 10, 9, 8, 7, 7, 6, 6, 5, 5, 4, 4, 3, 3, 2]

var _time := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameClock.time_changed.connect(queue_redraw.unbind(2))


func _process(delta: float) -> void:
	# The stars twinkle, so redraw now and then at night.
	_time += delta
	if _hour() >= SUN_SET or _hour() < SUN_RISE:
		if int(_time * 4.0) != int((_time - delta) * 4.0):
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
	if x >= 1 and y >= 1 and x < W - 1 and y < H - 1:
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
	# the frame and the sky, a band of glow low down
	draw_rect(Rect2(0, 0, W, H), FRAME)
	draw_rect(Rect2(1, 1, W - 2, H - 2), sky)
	draw_rect(Rect2(1, H - 9, W - 2, 4), sky.lightened(0.12 if not night else 0.05))
	if night and clouds < 1.0:
		for i in STARS.size():
			var star: Vector2i = STARS[i]
			var twinkle := sin(_time * 2.0 + i * 1.7) > -0.3
			if twinkle:
				_px(star.x, star.y, Color(0.961, 0.933, 0.878, 0.85))
	# the sun or the moon on its arc
	var body := body_position(hour)
	if night:
		_disc(body, 2.6, MOON)
		_disc(body + Vector2(1.2, -0.6), 2.0, sky) # a crescent
	else:
		_disc(body, 3.0, SUN.darkened(0.08))
		_disc(body, 2.2, SUN)
		_disc(body + Vector2(-0.6, -0.6), 1.0, SUN_CORE)
	if clouds >= 1.0 or clouds > 0.45:
		_cloud(Vector2(23, 5), night)
		if clouds >= 1.0:
			_cloud(Vector2(9, 6), night)
	# Half Dome and the pines in front of it
	for x in range(1, W - 1):
		var height: int = SKYLINE[x]
		for y in range(H - 1 - height, H - 1):
			# the face catches the evening light; the crown is lit by day
			var lit := y == H - 1 - height or (x == 11 and hour > 16.0 and hour < SUN_SET)
			_px(x, y, (GRANITE_LIT if lit else GRANITE).darkened(0.35 if night else 0.0))
	for x in range(1, W - 1, 3):
		var tree := 2 + (x * 7) % 3
		for y in range(H - 1 - tree, H - 1):
			_px(x, y, PINES.darkened(0.3 if night else 0.0))
			if y > H - tree:
				_px(x - 1, y, PINES.darkened(0.3 if night else 0.0))
	# rain or snow over everything
	var rain: float = weather.get("rain", 0.0)
	var snow: float = weather.get("snow", 0.0)
	if rain > 0.0 or snow > 0.0:
		var fall := int(_time * 6.0)
		for i in 9:
			var x := 3 + (i * 11) % (W - 6)
			var y := 3 + (i * 5 + fall) % (H - 6)
			if rain > 0.0:
				_px(x, y, Color("63b3c6"))
				_px(x, y + 1, Color("63b3c6"))
			else:
				_px(x, y, Color.WHITE)


func _cloud(at: Vector2, night: bool) -> void:
	var color := Color("f5eee0") if not night else Color("6a6a70")
	_disc(at, 2.4, color)
	_disc(at + Vector2(3, 0.6), 2.0, color)
	_disc(at + Vector2(-3, 0.8), 1.8, color)
