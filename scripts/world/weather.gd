class_name Weather
extends Node2D
## What falls through the air outdoors: snow in winter, apple-blossom petals
## and the odd spring shower, drifting cottonwood fluff and warm light motes
## in the summer afternoon sun, fireflies on summer nights, tumbling leaves and
## an autumn rain now and then.
##
## Each day's weather comes from the date (see [method today]), so it's the
## same after a reload and other systems (DayNight, CloudShadows) can ask for
## it. Flakes are simulated by hand, a few dozen points, and drawn as whole
## pixels in world space. They wrap round the camera's view, so walking moves
## you through the snow instead of dragging it along. Hidden indoors.

## How many of each, at full strength.
const COUNTS := {"snow": 130, "rain": 55, "petal": 30, "leaf": 30, "fluff": 12, "firefly": 12, "mote": 24}
## Most flakes on screen at once, whatever the weather. Keeps the draw cost
## flat and the view clear enough to see the player.
const MAX_FLAKES := 140
## Extra room round the view, so flakes don't pop in at the edges.
const MARGIN := 12.0

## Kind of each flake (an index into KINDS) and its state.
const KINDS := ["snow", "rain", "petal", "leaf", "fluff", "firefly", "mote"]

var _pos := PackedVector2Array()
var _kind := PackedInt32Array()
## Per flake: fall speed scale (depth: nearer is bigger and faster), sway phase.
var _depth := PackedFloat32Array()
var _phase := PackedFloat32Array()
var _color := PackedColorArray()
var _time := 0.0
var _key := ""
var _view := Rect2()
var _tint: CanvasModulate
var _fireflies: Node2D

static var _today_key := ""
static var _today := {}


## Today's weather, from the date: {snow, rain, clouds} each 0..1. Snow and
## rain are how hard it's coming down; clouds is how much of the sky is
## covered (overcast when it rains or snows).
static func today() -> Dictionary:
	var key := "weather:%d:%d:%d" % [GameClock.year, GameClock.season, GameClock.day]
	if key == _today_key:
		return _today
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var roll := rng.randf()
	var strength := rng.randf_range(0.45, 1.0)
	var clouds := rng.randf_range(0.15, 0.6)
	var snow := 0.0
	var rain := 0.0
	match GameClock.season:
		GameClock.Season.SPRING:
			if roll < 0.18:
				rain = strength
		GameClock.Season.SUMMER:
			clouds *= 0.6
		GameClock.Season.FALL:
			if roll < 0.15:
				rain = strength
		GameClock.Season.WINTER:
			if roll < 0.6:
				snow = strength
	if snow > 0.0 or rain > 0.0:
		clouds = 1.0
	_today_key = key
	_today = {"snow": snow, "rain": rain, "clouds": clouds}
	return _today


func _ready() -> void:
	z_index = 20
	z_as_relative = false
	# Fireflies glow: additive and drawn bright, so the night tint can't
	# smother them.
	_fireflies = Node2D.new()
	_fireflies.name = "Fireflies"
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_fireflies.material = add
	_fireflies.modulate = Color(1.9, 1.9, 1.9)
	_fireflies.draw.connect(_draw_fireflies)
	add_child(_fireflies)


func _process(delta: float) -> void:
	var outdoors := _outdoors()
	visible = outdoors
	if not outdoors:
		return
	_view = _camera_view()
	var key := "%d:%d:%d:%d:%d" % [GameClock.year, GameClock.season, GameClock.day, int(_darkness() > 0.35), int(_motes_on())]
	if key != _key:
		_key = key
		_populate()
	_time += delta
	var wind := 4.0 + 5.0 * sin(_time * 0.13) + 2.0 * sin(_time * 0.41 + 1.0)
	var area := _view.grow(MARGIN)
	for i in _pos.size():
		var p := _pos[i]
		var d := _depth[i]
		var ph := _phase[i]
		var v := Vector2.ZERO
		match _kind[i]:
			0: # snow: slow, swaying
				v = Vector2(wind * 0.6 + sin(_time * 1.3 + ph) * 5.0, 9.0 + 9.0 * d)
			1: # rain: fast slanted streaks
				v = Vector2(wind * 3.0 + 18.0, 150.0 + 60.0 * d)
			2: # petals: flutter on the breeze
				v = Vector2(wind * 1.4 + sin(_time * 2.1 + ph) * 9.0, 6.0 + 5.0 * d + cos(_time * 2.1 + ph) * 3.0)
			3: # leaves: swing side to side as they fall
				v = Vector2(wind * 1.2 + sin(_time * 1.6 + ph) * 14.0, 8.0 + 8.0 * d)
			4: # fluff: hangs in the air
				v = Vector2(wind * 0.8 + sin(_time * 0.7 + ph) * 3.0, sin(_time * 0.9 + ph * 2.0) * 3.0 - 0.6)
			5: # fireflies: slow wandering loops
				v = Vector2(cos(_time * 0.6 + ph) * 6.0, sin(_time * 0.8 + ph * 1.7) * 4.0)
			6: # light motes: barely moving, drifting up through the sun
				v = Vector2(wind * 0.3 + cos(_time * 0.4 + ph) * 4.0, sin(_time * 0.5 + ph * 1.3) * 3.0 - 1.2)
		p += v * delta
		# Wrap round the view, in world space.
		p = area.position + Vector2(fposmod(p.x - area.position.x, area.size.x), fposmod(p.y - area.position.y, area.size.y))
		_pos[i] = p
	queue_redraw()
	_fireflies.queue_redraw()


## Rebuilds the flakes for the day (and for dusk, when the fireflies come out).
func _populate() -> void:
	var w := today()
	var counts := {}
	match GameClock.season:
		GameClock.Season.SPRING:
			counts["petal"] = 1.0
		GameClock.Season.SUMMER:
			if _darkness() > 0.35:
				counts["firefly"] = 1.0
			else:
				counts["fluff"] = 1.0
				if _motes_on():
					counts["mote"] = 1.0
		GameClock.Season.FALL:
			counts["leaf"] = 1.0
	if w.snow > 0.0:
		counts["snow"] = w.snow
	if w.rain > 0.0:
		counts["rain"] = w.rain
		counts.erase("petal")
	_pos.clear()
	_kind.clear()
	_depth.clear()
	_phase.clear()
	_color.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_key)
	var area := _view.grow(MARGIN)
	for kind_name: String in counts:
		var n := mini(int(COUNTS[kind_name] * float(counts[kind_name])), MAX_FLAKES - _pos.size())
		for i in n:
			_pos.append(area.position + Vector2(rng.randf() * area.size.x, rng.randf() * area.size.y))
			_kind.append(KINDS.find(kind_name))
			_depth.append(rng.randf())
			_phase.append(rng.randf() * TAU)
			_color.append(_color_for(kind_name, rng))


func _color_for(kind_name: String, rng: RandomNumberGenerator) -> Color:
	match kind_name:
		"snow":
			return Color(1.0, 1.0, 1.0, rng.randf_range(0.85, 1.0))
		"rain":
			return Color(0.78, 0.86, 0.98, rng.randf_range(0.35, 0.6))
		"petal":
			return [Color(0.99, 0.86, 0.9), Color(1.0, 0.95, 0.96), Color(0.96, 0.74, 0.82)][rng.randi() % 3]
		"leaf":
			return [Color(0.93, 0.66, 0.2), Color(0.85, 0.42, 0.16), Color(0.72, 0.28, 0.14), Color(0.95, 0.8, 0.3)][rng.randi() % 4]
		"fluff":
			return Color(1.0, 0.98, 0.9, 0.85)
		"mote":
			return Color(1.0, 0.9, 0.55, rng.randf_range(0.55, 0.9))
	return Color(1.0, 0.95, 0.5)


func _draw() -> void:
	for i in _pos.size():
		var p := _pos[i].floor()
		var c := _color[i]
		var d := _depth[i]
		match _kind[i]:
			0:
				if d > 0.94:
					# The nearest flakes: a soft plus.
					draw_rect(Rect2(p + Vector2(-1, 0), Vector2(3, 1)), c)
					draw_rect(Rect2(p + Vector2(0, -1), Vector2(1, 3)), c)
				elif d > 0.6:
					draw_rect(Rect2(p, Vector2(2, 2)), c)
				else:
					draw_rect(Rect2(p, Vector2.ONE), c)
			1:
				# A thin streak along the fall direction.
				draw_rect(Rect2(p, Vector2.ONE), c)
				draw_rect(Rect2(p + Vector2(-1, -2), Vector2.ONE), c)
				if d > 0.5:
					draw_rect(Rect2(p + Vector2(-1, -4), Vector2.ONE), Color(c, c.a * 0.6))
			2:
				# Petals turn over: wide, then edge-on.
				if fmod(_time * 2.0 + _phase[i], TAU) < PI:
					draw_rect(Rect2(p, Vector2(2, 2)), c)
					draw_rect(Rect2(p + Vector2(1, 1), Vector2.ONE), c.darkened(0.15))
				else:
					draw_rect(Rect2(p, Vector2(2, 1)), c.darkened(0.08))
			3:
				# Leaves tumble through three shapes, with a darker vein.
				var vein := c.darkened(0.35)
				match int(fposmod(_time * 3.0 + _phase[i] * 2.0, 3.0)):
					0:
						draw_rect(Rect2(p, Vector2(3, 2)), c)
						draw_rect(Rect2(p + Vector2(0, 1), Vector2(2, 1)), vein)
					1:
						draw_rect(Rect2(p, Vector2(2, 2)), c)
						draw_rect(Rect2(p + Vector2(1, 1), Vector2.ONE), vein)
					_:
						draw_rect(Rect2(p, Vector2(1, 3)), c)
						draw_rect(Rect2(p + Vector2(0, 2), Vector2.ONE), vein)
			4:
				var twinkle := 0.6 + 0.4 * sin(_time * 3.0 + _phase[i] * 5.0)
				draw_rect(Rect2(p, Vector2.ONE), Color(c, c.a * twinkle))
			6:
				# A fleck of sunlight: a pixel that catches the light now and then.
				var shine := clampf(0.5 + 0.5 * sin(_time * 1.1 + _phase[i] * 4.0), 0.0, 1.0)
				draw_rect(Rect2(p, Vector2.ONE), Color(c, c.a * shine))


func _draw_fireflies() -> void:
	for i in _pos.size():
		if _kind[i] != 5:
			continue
		# Each one blinks on its own slow beat.
		var blink := clampf(sin(_time * 1.7 + _phase[i] * 3.0) * 1.6 - 0.2, 0.0, 1.0)
		if blink <= 0.0:
			continue
		var p := _pos[i].floor()
		_fireflies.draw_rect(Rect2(p, Vector2.ONE), Color(0.85, 1.0, 0.3, blink))
		var halo := Color(0.55, 0.7, 0.12, blink * 0.4)
		_fireflies.draw_rect(Rect2(p + Vector2(-1, 0), Vector2(3, 1)), halo)
		_fireflies.draw_rect(Rect2(p + Vector2(0, -1), Vector2(1, 3)), halo)
		# A faint outer glow on the corners, so the glow is round, not a plus.
		var corner := Color(0.5, 0.66, 0.1, blink * 0.14)
		for d in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			_fireflies.draw_rect(Rect2(p + d, Vector2.ONE), corner)


func _camera_view() -> Rect2:
	var size := get_viewport_rect().size
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return Rect2(Vector2.ZERO, size)
	size /= camera.zoom
	return Rect2(camera.get_screen_center_position() - size / 2.0, size)


func _outdoors() -> bool:
	var world := get_parent()
	if world and "region" in world and world.region:
		return not world.region.indoors
	return true


## True in the summer afternoon sun, when the light motes drift about.
func _motes_on() -> bool:
	return GameClock.season == GameClock.Season.SUMMER and _darkness() <= 0.35 \
			and GameClock.hour >= 12 and GameClock.hour < 18


## 0 in daylight, 1 at full night, from the world's day and night tint.
func _darkness() -> float:
	if _tint == null:
		_tint = get_parent().get_node_or_null("DayNight") as CanvasModulate
		if _tint == null:
			return 0.0
	var lum := (_tint.color.r + _tint.color.g + _tint.color.b) / 3.0
	return clampf((0.9 - lum) / 0.45, 0.0, 1.0)
