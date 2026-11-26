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
const MARGIN := 24.0

## Kind of each flake (an index into KINDS) and its state.
const KINDS := ["snow", "rain", "petal", "leaf", "fluff", "firefly", "mote"]

var _pos := PackedVector2Array()
var _kind := PackedInt32Array()
## Per flake: fall speed scale (depth: nearer is bigger and faster), sway phase.
var _depth := PackedFloat32Array()
var _phase := PackedFloat32Array()
var _color := PackedColorArray()
## How far each one has faded in (0 to 1). A kind that comes or goes with
## the light during the day (fireflies at dusk, motes in the afternoon sun)
## fades over FADE seconds instead of every flake jumping at once.
var _fade := PackedFloat32Array()
## Kinds (KINDS indices) on their way out, fading to nothing.
var _leaving := {}
## The day part of the last key: a new day starts the air afresh.
var _day_key := -1
const FADE := 2.5
var _time := 0.0
var _key := -1
var _view := Rect2()
var _tint: CanvasModulate
var _fireflies: Node2D
var _has_fireflies := false
var _had_fireflies := false

static var _today_date := -1
static var _today_key := "":
	set(v):
		_today_key = v
		if v == "":
			_today_date = -1
static var _today := {}
## today() up high or down the canyon: worked out from _today at _local_ft.
static var _local := {}
static var _local_ft := -1
static var _local_base := {}


## Today's weather where you are, from the date: {snow, rain, clouds} each
## 0..1. Snow and rain are how hard it's coming down; clouds is how much of
## the sky is covered (overcast when it rains or snows). The park shares one
## storm a day (on_day, the Valley floor's weather); up high and down the
## canyon it falls as Climate.localize says (snow on Tuolumne when the Valley
## gets rain). On the Valley floor this is the park's own dictionary.
## The high country's summer afternoon shower is apart: see [method shower].
static func today() -> Dictionary:
	var base := park_today()
	var ft := Climate.elevation()
	if ft >= Climate.RAIN_BELOW_FT and ft < Climate.MOUNTAIN_FT:
		return base
	if ft != _local_ft or not is_same(base, _local_base):
		_local_ft = ft
		_local_base = base
		_local = Climate.localize(base, GameClock.season, GameClock.day, ft)
	return _local


## The park's weather today, the Valley floor's (see [method on_day]).
static func park_today() -> Dictionary:
	var date := (GameClock.year * 4 + GameClock.season) * 64 + GameClock.day
	if date == _today_date:
		return _today
	_today_date = date
	_today = on_day(GameClock.year, GameClock.season, GameClock.day)
	return _today


## Today's weather in [param region_id] (whose hub is [param hub_id]),
## wherever you are: for things that happen in a place of their own (the
## people out walking there, the cables on Half Dome).
static func at(region_id: String, hub_id := "") -> Dictionary:
	var ft := Climate.elevation(region_id, hub_id)
	return Climate.localize(park_today(), GameClock.season, GameClock.day, ft)


## How hard the high country's summer afternoon storm is raining where you
## are now (0 to 1; see Climate.shower). Rain from it adds to today().rain.
static func shower() -> float:
	return Climate.shower()


## How hard it's raining where you are now: the day's rain and any passing
## storm.
static func rain_now() -> float:
	return maxf(float(today().rain), shower())


## The weather on any date, worked out the way [method today] does (the
## climbing screen asks about yesterday: rock stays wet after rain, and
## Seasons reads back through the winter to see how much snow has built up).
static func on_day(year: int, season: int, day: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("weather:%d:%d:%d" % [year, season, day])
	var roll := rng.randf()
	var strength := rng.randf_range(0.45, 1.0)
	var clouds := rng.randf_range(0.15, 0.6)
	var snow := 0.0
	var rain := 0.0
	match season:
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
	return {"snow": snow, "rain": rain, "clouds": clouds}


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
	var world := get_parent()
	if world and world.has_signal("seam_crossed"):
		world.seam_crossed.connect(shift)


## Moves every flake by [param by], with the world over a seam, so the snow
## falls on where it was instead of the whole sky jumping at once.
func shift(by: Vector2) -> void:
	for i in _pos.size():
		_pos[i] += by
	_view.position += by


func _process(delta: float) -> void:
	var outdoors := _outdoors()
	visible = outdoors
	if not outdoors:
		return
	_view = _camera_view()
	var dark_flag := 1 if _darkness() > 0.35 else 0
	var motes_flag := 1 if _motes_on() else 0
	# the place (up high it snows when it rains below) and any passing storm
	var shower_flag := roundi(shower() * 4.0)
	var key := hash([(GameClock.year * 4 + GameClock.season) * 64 + GameClock.day, dark_flag, motes_flag,
		Climate.elevation(), shower_flag])
	if key != _key:
		_key = key
		_populate(dark_flag, motes_flag)
	_time += delta
	_fade_kinds(delta)
	var wind := 8.0 + 10.0 * sin(_time * 0.13) + 4.0 * sin(_time * 0.41 + 1.0)
	var area := _view.grow(MARGIN)
	var ax := area.position.x
	var ay := area.position.y
	var aw := area.size.x
	var ah := area.size.y
	for i in _pos.size():
		var p := _pos[i]
		var d := _depth[i]
		var ph := _phase[i]
		var vx := 0.0
		var vy := 0.0
		match _kind[i]:
			0: # snow: slow, swaying
				vx = wind * 0.6 + sin(_time * 1.3 + ph) * 10.0
				vy = 18.0 + 18.0 * d
			1: # rain: fast slanted streaks
				vx = wind * 3.0 + 36.0
				vy = 300.0 + 120.0 * d
			2: # petals: flutter on the breeze
				vx = wind * 1.4 + sin(_time * 2.1 + ph) * 18.0
				vy = 12.0 + 10.0 * d + cos(_time * 2.1 + ph) * 6.0
			3: # leaves: swing side to side as they fall
				vx = wind * 1.2 + sin(_time * 1.6 + ph) * 28.0
				vy = 16.0 + 16.0 * d
			4: # fluff: hangs in the air
				vx = wind * 0.8 + sin(_time * 0.7 + ph) * 6.0
				vy = sin(_time * 0.9 + ph * 2.0) * 6.0 - 1.2
			5: # fireflies: slow wandering loops
				vx = cos(_time * 0.6 + ph) * 12.0
				vy = sin(_time * 0.8 + ph * 1.7) * 8.0
			6: # light motes: barely moving, drifting up through the sun
				vx = wind * 0.3 + cos(_time * 0.4 + ph) * 8.0
				vy = sin(_time * 0.5 + ph * 1.3) * 6.0 - 2.4
		# Wrap round the view, in world space.
		_pos[i] = Vector2(ax + fposmod(p.x + vx * delta - ax, aw), ay + fposmod(p.y + vy * delta - ay, ah))
	queue_redraw()
	if _has_fireflies:
		_had_fireflies = true
		_fireflies.queue_redraw()
	elif _had_fireflies:
		_had_fireflies = false
		_fireflies.queue_redraw()


## Rebuilds the flakes for the day (and for dusk, when the fireflies come out).
func _populate(dark_flag: int, motes_flag: int) -> void:
	var w := today()
	var counts := {}
	match GameClock.season:
		GameClock.Season.SPRING:
			counts["petal"] = 1.0
			if motes_flag == 1:
				counts["mote"] = 0.65
		GameClock.Season.SUMMER:
			if dark_flag == 1:
				counts["firefly"] = 1.0
			else:
				counts["fluff"] = 1.0
				if motes_flag == 1:
					counts["mote"] = 1.0
		GameClock.Season.FALL:
			counts["leaf"] = 1.0
			if motes_flag == 1:
				counts["mote"] = 0.75
	if w.snow > 0.0:
		counts["snow"] = w.snow
	if w.snow > 0.0:
		counts.erase("petal")
		counts.erase("fluff")
	var rain := maxf(float(w.rain), shower())
	if rain > 0.0:
		counts["rain"] = rain
		counts.erase("petal")
	var day_key := (GameClock.year * 4 + GameClock.season) * 64 + GameClock.day
	# Later in the same day (the light changed): keep what still belongs in
	# the air, fade out what doesn't and fade in what's new.
	var same_day := day_key == _day_key and not _pos.is_empty()
	_day_key = day_key
	var have := {}
	if same_day:
		for i in _pos.size():
			var kind_name: String = KINDS[_kind[i]]
			if counts.has(kind_name):
				_leaving.erase(_kind[i])
				have[kind_name] = true
			else:
				_leaving[_kind[i]] = true
	else:
		_pos.clear()
		_kind.clear()
		_depth.clear()
		_phase.clear()
		_color.clear()
		_fade.clear()
		_leaving.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%d:%d:%d:%d" % [GameClock.year, GameClock.season, GameClock.day, dark_flag, motes_flag])
	var area := _view.grow(MARGIN)
	for kind_name: String in counts:
		# wanted again: none of its flakes should fade out (even if it had
		# all gone already)
		var kind_idx := KINDS.find(kind_name)
		_leaving.erase(kind_idx)
		if have.has(kind_name):
			continue
		# Low graphics: half as many, for slower computers
		var share := 0.5 if Settings.low() else 1.0
		var n := mini(int(COUNTS[kind_name] * float(counts[kind_name]) * share), MAX_FLAKES - _pos.size())
		for i in n:
			_pos.append(area.position + Vector2(rng.randf() * area.size.x, rng.randf() * area.size.y))
			_kind.append(kind_idx)
			_depth.append(rng.randf())
			_phase.append(rng.randf() * TAU)
			_color.append(_color_for(kind_name, rng))
			_fade.append(0.0 if same_day else 1.0)
	_recheck_fireflies()


func _recheck_fireflies() -> void:
	_has_fireflies = false
	for i in _kind.size():
		if _kind[i] == 5:
			_has_fireflies = true
			return


## Fades each flake towards in (or out, for a kind that's leaving), and lets
## go of those that have faded out.
func _fade_kinds(delta: float) -> void:
	var step := delta / FADE
	var removed := false
	var i := _pos.size() - 1
	while i >= 0:
		if _leaving.has(_kind[i]):
			_fade[i] -= step
			if _fade[i] <= 0.0:
				_pos.remove_at(i)
				_kind.remove_at(i)
				_depth.remove_at(i)
				_phase.remove_at(i)
				_color.remove_at(i)
				_fade.remove_at(i)
				removed = true
		elif _fade[i] < 1.0:
			_fade[i] = minf(_fade[i] + step, 1.0)
		i -= 1
	if removed:
		_recheck_fireflies()


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
		c.a *= _fade[i]
		var d := _depth[i]
		match _kind[i]:
			0:
				if d > 0.94:
					# The nearest flakes: a soft plus.
					draw_rect(Rect2(p + Vector2(-2, 0), Vector2(6, 2)), c)
					draw_rect(Rect2(p + Vector2(0, -2), Vector2(2, 6)), c)
				elif d > 0.6:
					draw_rect(Rect2(p, Vector2(4, 4)), c)
				else:
					draw_rect(Rect2(p, Vector2(2, 2)), c)
			1:
				# A tapered rain streak along the fall direction, with occasional ground splash ticks.
				draw_rect(Rect2(p, Vector2(2, 2)), c)
				draw_rect(Rect2(p + Vector2(-2, -4), Vector2(2, 2)), Color(c, c.a * 0.85))
				if d > 0.45:
					draw_rect(Rect2(p + Vector2(-2, -8), Vector2(2, 2)), Color(c, c.a * 0.5))
				if d > 0.82 and fposmod(_time * 4.5 + _phase[i] * 3.0, 1.0) < 0.16:
					var sp := Color(0.86, 0.93, 1.0, c.a * 0.85)
					draw_rect(Rect2(p + Vector2(-2, 2), Vector2(2, 2)), sp)
					draw_rect(Rect2(p + Vector2(2, 2), Vector2(2, 2)), sp)
			2:
				# Petals turn over: sunlit edge + blush shadow, then edge-on.
				if fmod(_time * 2.0 + _phase[i], TAU) < PI:
					draw_rect(Rect2(p, Vector2(4, 4)), c)
					draw_rect(Rect2(p, Vector2(2, 2)), c.lightened(0.22))
					draw_rect(Rect2(p + Vector2(2, 2), Vector2(2, 2)), c.darkened(0.16))
				else:
					draw_rect(Rect2(p, Vector2(4, 2)), c.darkened(0.08))
			3:
				# Leaves tumble through three shapes, with a darker vein.
				var vein := c.darkened(0.35)
				match int(fposmod(_time * 3.0 + _phase[i] * 2.0, 3.0)):
					0:
						draw_rect(Rect2(p, Vector2(6, 4)), c)
						draw_rect(Rect2(p + Vector2(0, 2), Vector2(4, 2)), vein)
					1:
						draw_rect(Rect2(p, Vector2(4, 4)), c)
						draw_rect(Rect2(p + Vector2(2, 2), Vector2(2, 2)), vein)
					_:
						draw_rect(Rect2(p, Vector2(2, 6)), c)
						draw_rect(Rect2(p + Vector2(0, 4), Vector2(2, 2)), vein)
			4:
				var twinkle := 0.6 + 0.4 * sin(_time * 3.0 + _phase[i] * 5.0)
				draw_rect(Rect2(p, Vector2(2, 2)), Color(c, c.a * twinkle))
			6:
				# A fleck of sunlight: a pixel that catches the light now and then.
				var shine := clampf(0.5 + 0.5 * sin(_time * 1.1 + _phase[i] * 4.0), 0.0, 1.0)
				draw_rect(Rect2(p, Vector2(2, 2)), Color(c, c.a * shine))


func _draw_fireflies() -> void:
	for i in _pos.size():
		if _kind[i] != 5:
			continue
		# Each one blinks on its own slow beat.
		var blink := clampf(sin(_time * 1.7 + _phase[i] * 3.0) * 1.6 - 0.2, 0.0, 1.0) * _fade[i]
		if blink <= 0.0:
			continue
		var p := _pos[i].floor()
		_fireflies.draw_rect(Rect2(p, Vector2(2, 2)), Color(0.95, 1.0, 0.52, blink))
		var halo := Color(0.68, 0.82, 0.16, blink * 0.44)
		_fireflies.draw_rect(Rect2(p + Vector2(-2, 0), Vector2(6, 2)), halo)
		_fireflies.draw_rect(Rect2(p + Vector2(0, -2), Vector2(2, 6)), halo)
		# A faint golden outer glow on the corners, so the glow is round, not a plus.
		var corner := Color(0.62, 0.72, 0.12, blink * 0.18)
		for d in [Vector2(-2, -2), Vector2(2, -2), Vector2(-2, 2), Vector2(2, 2)]:
			_fireflies.draw_rect(Rect2(p + d, Vector2(2, 2)), corner)


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


## True on fair sunlit hours (spring, summer and fall), when warm light motes
## drift through the Valley air.
func _motes_on() -> bool:
	var w := today()
	return GameClock.season != GameClock.Season.WINTER and _darkness() <= 0.35 \
			and w.rain <= 0.0 and w.snow <= 0.0 and w.clouds < 0.7 \
			and GameClock.hour >= 8 and GameClock.hour < 19


## 0 in daylight, 1 at full night, from the world's day and night tint.
func _darkness() -> float:
	if _tint == null:
		_tint = get_parent().get_node_or_null("DayNight") as CanvasModulate
		if _tint == null:
			return 0.0
	var lum := (_tint.color.r + _tint.color.g + _tint.color.b) / 3.0
	return clampf((0.9 - lum) / 0.45, 0.0, 1.0)
