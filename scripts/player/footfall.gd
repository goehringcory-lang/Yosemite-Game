class_name Footfall
extends Node2D
## Little touches as the player moves: a puff of dust and a footstep sound at
## each step (kicked-up snow on snowy days, a splash when it rains, boards and
## no dust indoors), and on cold mornings and all winter, a breath of fog in
## front of their face. Pixel puffs in a small pool, drawn in world space so
## they stay where they were made. Player adds one as a child.

## Pixels walked between steps (the walk cycle's footfalls).
const STEP_DISTANCE := 20.0
const PUFF_LIFE := 0.45
const BREATH_LIFE := 1.1
const BREATH_EVERY := 2.4
const MAX_PUFFS := 12

## Each puff: [position, age, kind (0 dust, 1 breath), color, direction].
var _puffs: Array = []
var _walked := 0.0
var _left := false
var _breath_timer := 1.0
var _last := Vector2.ZERO
var _breath: Node2D


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
	visible = not _puffs.is_empty()
	if visible:
		queue_redraw()
		_breath.queue_redraw()


func _step(at: Vector2) -> void:
	_step_sound()
	if _indoors():
		return
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
	_add([at, 0.0, 0, color, Vector2.ZERO])


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
	var node := get_parent()
	while node and not node is Region:
		node = node.get_parent()
	return node != null and (node as Region).indoors


func _draw() -> void:
	for puff: Array in _puffs:
		if puff[2] != 0:
			continue
		var t: float = puff[1] / PUFF_LIFE
		var p: Vector2 = (puff[0] as Vector2).floor()
		var c: Color = puff[3]
		c.a *= 1.0 - t
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
