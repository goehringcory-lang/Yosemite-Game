class_name Footfall
extends Node2D
## Little touches as the player moves: a puff of dust and a footstep sound at
## each step (kicked-up snow on snowy days, a splash when it rains, boards and
## no dust indoors), and on cold mornings and all winter, a breath of fog in
## front of their face. Pixel puffs in a small pool, drawn in world space so
## they stay where they were made. Where snow lies on the ground
## (Seasons.snow_cover), each step also leaves a boot print that stays for
## the rest of the day, unless fresh snow fills it in. Running kicks up a
## bigger spray. Player adds one as a child, and so does everyone walking
## about (NPC), [member quiet]: their steps make no sound.

## Pixels walked between steps (the walk cycle's footfalls).
const STEP_DISTANCE := 20.0
const PUFF_LIFE := 0.45
const BREATH_LIFE := 1.1
const BREATH_EVERY := 2.4
const MAX_PUFFS := 12
## Boot prints kept at once (the oldest go first), the snow it takes to hold
## them, and how long fresh snow takes to fill one in, in seconds.
const MAX_PRINTS := 240
const PRINT_SNOW := 0.3
const PRINT_FILL := 90.0

## Each puff: [position, age, kind (0 dust, 1 breath, 2 a running kick),
## color, direction].
var _puffs: Array = []
var _walked := 0.0
var _left := false
var _breath_timer := 1.0
var _last := Vector2.ZERO
var _breath: Node2D
## Each print: [position, region id, left foot, age in seconds].
var _prints: Array = []
var _prints_day := ""
var _print_layer: Node2D
## No footstep sounds (for other people's feet).
var quiet := false
## Faster than this (pixels a second), the feet kick up a spray.
const RUN_SPEED := 220.0
var _running := false


func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO
	# Step puffs lie on the ground, under people and props.
	z_index = -5
	z_as_relative = false
	_breath = Node2D.new()
	_breath.name = "Breath"
	_breath.z_index = 5
	_breath.z_as_relative = false
	_breath.draw.connect(_draw_breath)
	add_child(_breath)
	# Prints sit flat in the snow, under the puffs.
	_print_layer = Node2D.new()
	_print_layer.name = "Prints"
	_print_layer.z_index = -6
	_print_layer.z_as_relative = false
	_print_layer.draw.connect(_draw_prints)
	add_child(_print_layer)
	_last = _body().global_position if _body() else Vector2.ZERO


func _body() -> Node2D:
	return get_parent() as Node2D


func _process(delta: float) -> void:
	var body := _body()
	if body == null:
		return
	var feet := body.global_position
	var moved := feet.distance_to(_last)
	_last = feet
	_running = delta > 0.0 and moved / delta > RUN_SPEED
	# A jump (a door, a spawn) is not a step.
	if moved > 0.0 and moved < 16.0:
		_walked += moved
		if _walked >= STEP_DISTANCE:
			_walked = 0.0
			_left = not _left
			_step(feet + Vector2(-4 if _left else 4, 0))
	_breath_timer -= delta
	if _breath_timer <= 0.0:
		_breath_timer = BREATH_EVERY + randf() * 0.6
		if _cold():
			var facing: Vector2i = body.get("facing") if "facing" in body else Vector2i.DOWN
			var mouth := feet + Vector2(0, -32) + Vector2(facing) * Vector2(10, 4)
			_add([mouth, 0.0, 1, Color(0.95, 0.97, 1.0, 0.55), Vector2(facing.x * 8.0, -6.0)])
	var i := 0
	while i < _puffs.size():
		var puff: Array = _puffs[i]
		puff[1] += delta
		if puff[1] >= (BREATH_LIFE if puff[2] == 1 else PUFF_LIFE):
			_puffs.remove_at(i)
		else:
			i += 1
	_age_prints(delta)
	visible = not _puffs.is_empty() or not _prints.is_empty()
	if visible:
		queue_redraw()
		_breath.queue_redraw()
		_print_layer.queue_redraw()


func _step(at: Vector2) -> void:
	if not quiet:
		_step_sound()
	if _indoors():
		return
	if Seasons.snow_cover() >= PRINT_SNOW:
		var region := _region()
		_prints.append([at.floor(), region.region_id if region else "", _left, 0.0])
		if _prints.size() > MAX_PRINTS:
			_prints.pop_front()
	var color := Color(0.8, 0.72, 0.56, 0.6)
	var weather := Weather.today()
	if weather.rain > 0.0:
		color = Color(0.8, 0.88, 1.0, 0.65)
	elif weather.snow > 0.0:
		color = Color(0.96, 0.98, 1.0, 0.8)
	elif GameClock.season == GameClock.Season.WINTER:
		return # frozen ground: no dust
	elif GameClock.season == GameClock.Season.SPRING:
		color.a = 0.4 # damp spring earth
	var behind := Vector2.ZERO
	if _running and _body() and "facing" in _body():
		behind = -Vector2(_body().get("facing"))
	_add([at, 0.0, 2 if _running else 0, color, behind])


## A footstep: boards indoors, a crunch in snow or on winter ground, a squelch
## in the rain, and dirt and duff the rest of the time.
func _step_sound() -> void:
	var surface := "step_dirt"
	var weather := Weather.today()
	if _indoors():
		surface = "step_wood"
	elif weather.snow > 0.0 or GameClock.season == GameClock.Season.WINTER:
		surface = "step_snow"
	elif weather.rain > 0.0:
		surface = "step_wet"
	Sound.play(surface, -9.0, 0.08)


func _add(puff: Array) -> void:
	if _puffs.size() >= MAX_PUFFS:
		_puffs.pop_front()
	_puffs.append(puff)
	visible = true


func _cold() -> bool:
	if _indoors():
		return false
	var hour := GameClock.hour
	match GameClock.season:
		GameClock.Season.WINTER:
			return true
		GameClock.Season.FALL, GameClock.Season.SPRING:
			return hour < 9 or hour >= 21
	return false


func _indoors() -> bool:
	var region := _region()
	return region != null and region.indoors


func _region() -> Region:
	var node := get_parent()
	while node and not node is Region:
		node = node.get_parent()
	return node as Region


## Prints last the day; falling snow fills them in.
func _age_prints(delta: float) -> void:
	var today := "%d:%d:%d" % [GameClock.year, GameClock.season, GameClock.day]
	if today != _prints_day:
		_prints_day = today
		_prints.clear()
	if _prints.is_empty() or Weather.today().snow <= 0.0:
		return
	var i := 0
	while i < _prints.size():
		_prints[i][3] += delta
		if _prints[i][3] >= PRINT_FILL:
			_prints.remove_at(i)
		else:
			i += 1


## Each boot print: a sole and a heel pressed into the snow, in shadow blue.
func _draw_prints() -> void:
	var region := _region()
	var here := region.region_id if region else ""
	for mark: Array in _prints:
		if mark[1] != here:
			continue
		var p: Vector2 = mark[0]
		var c := Color(0.62, 0.71, 0.86, 0.75 * (1.0 - mark[3] / PRINT_FILL))
		var x := -2.0 if mark[2] else 0.0
		_print_layer.draw_rect(Rect2(p + Vector2(x, -6), Vector2(4, 4)), c)
		_print_layer.draw_rect(Rect2(p + Vector2(x, 0), Vector2(4, 2)), c)


func _draw() -> void:
	for puff: Array in _puffs:
		if puff[2] == 1:
			continue
		var t: float = puff[1] / PUFF_LIFE
		var p: Vector2 = (puff[0] as Vector2).floor()
		var c: Color = puff[3]
		c.a *= 1.0 - t
		if puff[2] == 2:
			# a running kick: a spray flung back off the toe, arcing down
			var back: Vector2 = puff[4]
			for i in 4:
				var fly := back * (4.0 + i * 3.0) * (0.4 + t) + Vector2((i - 1.5) * 3.0, -8.0 * t * (1.0 - t) * (2.0 + i))
				draw_rect(Rect2((p + fly).floor(), Vector2(2, 2)), c)
			continue
		# Three motes spreading out from the heel and settling.
		var spread := floorf(1.0 + t * 3.0) * 2.0
		var lift := floorf(t * 2.0) * 2.0
		draw_rect(Rect2(p + Vector2(-spread, -lift), Vector2(2, 2)), c)
		draw_rect(Rect2(p + Vector2(spread, -lift), Vector2(2, 2)), c)
		if t < 0.5:
			draw_rect(Rect2(p + Vector2(0, -2 - lift), Vector2(2, 2)), c)


func _draw_breath() -> void:
	for puff: Array in _puffs:
		if puff[2] != 1:
			continue
		var t: float = puff[1] / BREATH_LIFE
		var p: Vector2 = ((puff[0] as Vector2) + (puff[4] as Vector2) * t).floor()
		var c: Color = puff[3]
		c.a *= 1.0 - t
		# A little cloud that grows from one pixel to a soft plus.
		_breath.draw_rect(Rect2(p, Vector2(2, 2)), c)
		if t > 0.15:
			_breath.draw_rect(Rect2(p + Vector2(-2, 0), Vector2(6, 2)), Color(c, c.a * 0.7))
		if t > 0.4:
			_breath.draw_rect(Rect2(p + Vector2(0, -2), Vector2(2, 6)), Color(c, c.a * 0.5))
