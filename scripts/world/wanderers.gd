class_name Wanderers
extends Node2D
## Big animals that wander by now and then as you go about outdoors (Bears,
## Deer). Walk around outside and every so often one comes in from the edge
## of the view, maybe with its young or a few more of its kind, stops to
## nose at the ground or graze, and goes off the other side; come too close
## and it looks up at you, then moves off, faster if you run at it. Getting a
## good look at one puts it in your field log (FieldLog). World adds one of
## each kind; each sets the numbers below in _init.

## The field log id.
var animal_id := ""
## Seconds of walking about outdoors between chances of one.
var check_every := 12.0
## The chance of one at each check in summer; season_chance scales it, by
## GameClock.Season: spring, summer, fall, winter.
var base_chance := 0.2
var season_chance := [1.0, 1.0, 1.0, 1.0]
## Hours they're about, and the busy hours at either end of the day, when
## the chance is half again as much.
var first_hour := 5
var last_hour := 22
var dawn := [5, 8]
var dusk := [17, 22]
## No new one this soon after the last went.
var cooldown_time := 60.0
var walk_speed := 30.0
var leave_speed := 60.0
var bolt_speed := 110.0
## Within notice_distance of the player one stops and looks for watch_time;
## running within bolt_distance sends it off at bolt_speed.
var notice_distance := 140.0
var bolt_distance := 110.0
var watch_time := 1.5
## This close and on screen is a good enough look to log one.
var spot_distance := 220.0
## Shown when one stops to look at you ("" for nothing).
var notice_message := ""
## How long one may wander before it heads off anyway.
var max_wander := 45.0
## How far outside the view one comes in.
const EDGE := 48.0

var _animals: Array[Wanderer] = []
var _walked := 0.0
var _cooldown := 0.0
var _rng := RandomNumberGenerator.new()
var _last_region: Node


func _ready() -> void:
	_rng.randomize()


func _world() -> Node:
	return get_parent()


func _region() -> Region:
	var world := _world()
	return world.region if world and "region" in world else null


func _player() -> Player:
	var world := _world()
	return world.player if world and "player" in world else null


## The ones about now (for tests).
func animals() -> Array[Wanderer]:
	return _animals


## True if one could be out here now: outdoors, in its hours.
func active() -> bool:
	var region := _region()
	if region == null or region.indoors:
		return false
	return GameClock.hour >= first_hour and GameClock.hour < last_hour


## The chance of one at a check, for the season, the hour and the place.
func chance() -> float:
	if not active():
		return 0.0
	var odds: float = base_chance * season_chance[GameClock.season]
	var hour := GameClock.hour
	var at_dawn: bool = hour >= dawn[0] and hour < dawn[1]
	var at_dusk: bool = hour >= dusk[0] and hour < dusk[1]
	if at_dawn or at_dusk:
		odds *= 1.5
	return minf(_place_odds(odds, at_dusk), 0.9)


## Lets a kind change the odds for the place it's in.
func _place_odds(odds: float, _at_dusk: bool) -> float:
	return odds


## A new animal of this kind, not yet placed.
func _new_animal() -> Wanderer:
	return Wanderer.new()


## Sends in a group headed from [param at] to [param to].
func _spawn_group(at: Vector2, to: Vector2) -> void:
	add_group(at, to, 0)


## Puts a leader of [param coat_row] at [param at], headed for [param to],
## with [param followers] behind it, each [param young] or not and of
## [param follower_coat] (-1 for the leader's) (for tests, and the spawner).
func add_group(at: Vector2, to: Vector2, coat_row := 0, followers := 0, young := true, follower_coat := -1) -> Wanderer:
	var region := _region()
	var lead := _make(at, to, coat_row, false, null, region)
	var back := (to - at).normalized() if to != at else Vector2.RIGHT
	for i in followers:
		var other := _make(at - back * (22.0 + 18.0 * i) + Vector2(0, 6.0 * (i * 2 - 1)), to,
				coat_row if follower_coat < 0 else follower_coat, young, lead, region)
		other.place = i
	return lead


func _make(at: Vector2, to: Vector2, coat_row: int, young: bool, leader: Wanderer, region: Region) -> Wanderer:
	var animal := _new_animal()
	animal.coat = coat_row
	animal.young = young
	animal.leader = leader
	animal.target = to
	animal.heading = (to - at).normalized() if to != at else Vector2.RIGHT
	animal.facing = 1 if animal.heading.x >= 0.0 else -1
	animal.speed = walk_speed
	animal.timer = _rng.randf_range(3.0, 7.0)
	if region and region.entities:
		region.entities.add_child(animal)
	else:
		add_child(animal)
	animal.global_position = at
	_animals.append(animal)
	return animal


func _clear() -> void:
	for animal in _animals:
		if is_instance_valid(animal):
			animal.queue_free()
	_animals.clear()


func _view() -> Rect2:
	var camera := get_viewport().get_camera_2d()
	var size := get_viewport_rect().size
	if camera == null:
		return Rect2(Vector2.ZERO, size)
	var extent := size / camera.zoom
	return Rect2(camera.get_screen_center_position() - extent / 2.0, extent)


## True if [param at] is open ground: nothing solid there.
func _open(at: Vector2) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = at
	query.collision_mask = 1
	query.collide_with_areas = false
	return get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()


func _running() -> bool:
	var walker := _player()
	return walker != null and walker.velocity != Vector2.ZERO and Input.is_action_pressed("run")


func _process(delta: float) -> void:
	var region := _region()
	if region != _last_region:
		_last_region = region
		_clear()
		_walked = 0.0
	_cooldown = maxf(_cooldown - delta, 0.0)
	var walker := _player()
	# a chance of one comes with walking about, not with standing still
	if walker and walker.velocity != Vector2.ZERO and _animals.is_empty() and _cooldown <= 0.0:
		_walked += delta
		if _walked >= check_every:
			_walked = 0.0
			if _rng.randf() < chance():
				_try_spawn()
	var player := walker.global_position if walker else Vector2.INF
	var running := _running()
	for animal in _animals:
		if is_instance_valid(animal):
			_update(animal, delta, player, running)
	_retire()


func _try_spawn() -> void:
	var region := _region()
	if region == null:
		return
	var view := _view()
	var bounds := region.get_bounds().grow(-16.0)
	var sides := [0, 1, 2, 3]
	sides.shuffle()
	for side: int in sides:
		for attempt in 4:
			var at: Vector2
			var to: Vector2
			match side:
				0: # in from the left, off to the right
					var y := _rng.randf_range(view.position.y + 60, view.end.y - 30)
					at = Vector2(view.position.x - EDGE, y)
					to = Vector2(view.end.x + EDGE, y + _rng.randf_range(-80, 80))
				1:
					var y := _rng.randf_range(view.position.y + 60, view.end.y - 30)
					at = Vector2(view.end.x + EDGE, y)
					to = Vector2(view.position.x - EDGE, y + _rng.randf_range(-80, 80))
				2: # down from the top
					var x := _rng.randf_range(view.position.x + 40, view.end.x - 40)
					at = Vector2(x, view.position.y - EDGE)
					to = Vector2(x + _rng.randf_range(-160, 160), view.end.y + EDGE)
				_:
					var x := _rng.randf_range(view.position.x + 40, view.end.x - 40)
					at = Vector2(x, view.end.y + EDGE)
					to = Vector2(x + _rng.randf_range(-160, 160), view.position.y - EDGE)
			if bounds.has_point(at) and _open(at):
				_spawn_group(at, to)
				return


## Picks an index from [param weights] (which add up to 1).
func _pick(weights: Array) -> int:
	var roll := _rng.randf()
	for i in weights.size():
		roll -= weights[i]
		if roll < 0.0:
			return i
	return 0


func _update(animal: Wanderer, delta: float, player: Vector2, running: bool) -> void:
	animal.age += delta
	animal.timer -= delta
	var pos := animal.global_position
	var near := pos.distance_to(player)
	if animal.leader:
		_follow(animal, delta)
		animal.queue_redraw()
		return
	if near < spot_distance and _view().has_point(pos) and active():
		FieldLog.spot(animal_id)
	# you're close: it looks up at you once, then goes; at a run, it bolts
	if running and near < bolt_distance and animal.speed < bolt_speed:
		_leave(animal, player, bolt_speed)
		Sound.play("rustle", -2.0, 0.1, 0.6)
	elif near < notice_distance and not animal.noticed:
		animal.noticed = true
		animal.state = "watch"
		animal.timer = watch_time
		animal.facing = 1 if player.x >= pos.x else -1
		if notice_message != "":
			get_tree().call_group("hud", "show_message", notice_message)
	match animal.state:
		"watch":
			if animal.timer <= 0.0:
				_leave(animal, player, leave_speed)
		"forage":
			if animal.timer <= 0.0:
				animal.state = "wander"
				animal.timer = _rng.randf_range(3.0, 7.0)
				animal.heading = (animal.target - pos).normalized()
		"wander":
			if pos.distance_to(animal.target) < 16.0 or animal.age > max_wander or not active():
				_leave(animal, player, walk_speed)
			elif animal.timer <= 0.0:
				animal.state = "forage"
				animal.timer = _rng.randf_range(1.5, 3.5)
			else:
				_walk(animal, delta, (animal.target - pos).normalized())
		"leave":
			_walk(animal, delta, animal.heading)
	animal.queue_redraw()


## Turns [param animal] away from the player and off it goes.
func _leave(animal: Wanderer, player: Vector2, speed: float) -> void:
	animal.state = "leave"
	animal.noticed = true
	animal.speed = speed
	var away := animal.global_position - player
	if not away.is_finite() or away.length() < 1.0:
		away = animal.target - animal.global_position
	animal.heading = away.normalized() if away != Vector2.ZERO else Vector2.RIGHT
	animal.facing = 1 if animal.heading.x >= 0.0 else -1


## A step along [param want], round anything in the way.
func _walk(animal: Wanderer, delta: float, want: Vector2) -> void:
	var step := animal.speed * delta
	for turn: float in [0.0, 0.6, -0.6, 1.2, -1.2, 1.9, -1.9]:
		var dir := want.rotated(turn)
		var next := animal.global_position + dir * step
		if _open(next):
			animal.global_position = next
			if animal.state == "leave":
				animal.heading = dir
			if absf(dir.x) > 0.2:
				animal.facing = 1 if dir.x > 0.0 else -1
			animal.steps += delta * animal.speed / walk_speed
			return
	# boxed in: stand and nose about a while, then try again
	if animal.state == "wander":
		animal.state = "forage"
		animal.timer = 1.0


## A follower keeps a little behind its leader and does what it does.
func _follow(animal: Wanderer, delta: float) -> void:
	var lead := animal.leader
	if not is_instance_valid(lead):
		animal.leader = null
		animal.state = "leave"
		return
	animal.state = lead.state
	animal.speed = lead.speed
	var behind := lead.global_position - Vector2(lead.facing * (28.0 + 18.0 * animal.place), -5.0 if animal.place % 2 == 0 else 3.0)
	var gap := behind - animal.global_position
	if gap.length() > 3.0:
		var speed := maxf(lead.speed, walk_speed) * (1.4 if gap.length() > 40.0 else 1.0)
		animal.global_position += gap.normalized() * minf(speed * delta, gap.length())
		animal.steps += delta * speed / walk_speed
		if animal.state != "leave":
			animal.state = "wander"
		if absf(gap.x) > 1.0:
			animal.facing = 1 if gap.x > 0.0 else -1
	else:
		animal.facing = lead.facing


## Ones that have gone off out of sight go for good.
func _retire() -> void:
	var view := _view().grow(EDGE * 3.0)
	var region := _region()
	var bounds := region.get_bounds().grow(EDGE * 2.0) if region else Rect2()
	var kept: Array[Wanderer] = []
	for animal in _animals:
		if not is_instance_valid(animal):
			continue
		var lead: Wanderer = animal.leader if animal.leader and is_instance_valid(animal.leader) else animal
		var gone := lead.state == "leave" and not view.has_point(lead.global_position)
		gone = gone or (region != null and not bounds.has_point(lead.global_position))
		if gone:
			animal.queue_free()
		else:
			kept.append(animal)
	if kept.size() < _animals.size() and kept.is_empty():
		_cooldown = cooldown_time
	_animals = kept
