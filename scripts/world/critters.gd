class_name Critters
extends Node2D
## The little lives around you outdoors, like Stardew Valley's: birds that
## hop and peck about on open ground and flutter off when you come close, and
## butterflies drifting over the meadows on fair spring and summer days. They
## are a few pixels each, drawn here, and come and go around the view; none in
## the rain, after dark, or indoors. World adds one.
##
## The birds are the Valley's own: Steller's jays and dark-eyed juncos all
## year, robins from spring to fall, and California quail in little coveys.

## Most birds and butterflies about at once.
const MAX_BIRDS := 5
const MAX_BUTTERFLIES := 4
## Seconds between tries at adding one while there are fewer.
const SPAWN_EVERY := 2.5
## How close the player can come before a bird takes off.
const FLEE_DISTANCE := 30.0
## Birds keep this far from the player when they land.
const SPAWN_CLEAR := 70.0
const FLY_SPEED := 90.0
const HOP := 6.0

## The sprites (tools/npcgen/critter_art.gd): a row of 12x11 frames per
## bird (standing, pecking, wings up, wings down), facing right, and a row of
## 8x8 butterfly pairs (open, closed) under them.
const SHEET := preload("res://assets/sprites/critters.png")
const FRAME := Vector2(12, 11)
## Each bird: its row on the sheet, and the seasons it's about.
const BIRDS := {
	"stellers_jay": {"row": 0, "seasons": [0, 1, 2, 3]},
	"junco": {"row": 1, "seasons": [0, 2, 3]},
	"robin": {"row": 2, "seasons": [0, 1, 2]},
	"quail": {"row": 3, "seasons": [0, 1, 2, 3]},
}
## Butterflies of the Valley: western tiger swallowtail, California sister,
## Lorquin's admiral, a cabbage white (their columns on the sheet).
const BUTTERFLY_KINDS := 4

## Each critter: {kind, pos, vel, state, time, ...}.
var _birds: Array[Dictionary] = []
var _flies: Array[Dictionary] = []
var _spawn_timer := 1.0
var _rng := RandomNumberGenerator.new()
var _last_region: Node


func _ready() -> void:
	z_index = 4
	_rng.randomize()


## Puts a bird of [param kind] at [param at] (for tests).
func add_bird(kind: String, at: Vector2) -> Dictionary:
	var bird := {"kind": kind, "pos": at, "vel": Vector2.ZERO, "state": "peck", "time": 1.0, "facing": 1, "hop": 0.0, "flap": 0.0}
	_birds.append(bird)
	return bird


## How many of each are about (for tests).
func counts() -> Dictionary:
	return {"birds": _birds.size(), "butterflies": _flies.size()}


func _world() -> Node:
	return get_parent()


func _outdoors_by_day() -> bool:
	var world := _world()
	var region: Region = world.region if world and "region" in world else null
	if region == null or region.indoors:
		return false
	if Weather.today().rain > 0.0:
		return false
	var hour := GameClock.hour
	return hour >= 6 and hour < 19


func _view() -> Rect2:
	var camera := get_viewport().get_camera_2d()
	var size := get_viewport_rect().size
	if camera == null:
		return Rect2(Vector2.ZERO, size)
	var zoom := camera.zoom
	var extent := size / zoom
	return Rect2(camera.get_screen_center_position() - extent / 2.0, extent)


func _player_position() -> Vector2:
	var world := _world()
	return world.player.global_position if world and "player" in world and world.player else Vector2.INF


## True if [param at] is open ground: nothing solid there.
func _open(at: Vector2) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = at
	query.collision_mask = 1
	query.collide_with_areas = false
	return get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()


func _process(delta: float) -> void:
	var world := _world()
	if world and "region" in world and world.region != _last_region:
		_last_region = world.region
		_birds.clear()
		_flies.clear()
		_spawn_timer = 0.8
	var active := _outdoors_by_day()
	if active:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = SPAWN_EVERY
			_try_spawn()
	var view := _view().grow(40.0)
	var player := _player_position()
	if not active:
		# dusk, rain or indoors: the birds still about fly off, quietly
		for bird in _birds:
			if bird.state != "fly":
				_take_off(bird, bird.pos + Vector2(_rng.randf_range(-4.0, 4.0), 6.0), false)
	for bird in _birds:
		_update_bird(bird, delta, player)
	for fly in _flies:
		_update_butterfly(fly, delta, active)
	_birds = _birds.filter(func(b: Dictionary) -> bool: return view.has_point(b.pos) or b.state != "fly")
	_flies = _flies.filter(func(f: Dictionary) -> bool: return view.grow(40.0).has_point(f.pos))
	# birds left behind off screen go quietly
	_birds = _birds.filter(func(b: Dictionary) -> bool: return view.grow(80.0).has_point(b.pos))
	queue_redraw()


func _try_spawn() -> void:
	var view := _view()
	var player := _player_position()
	var season := GameClock.season
	if _birds.size() < MAX_BIRDS and _rng.randf() < 0.7:
		var kinds := []
		for kind: String in BIRDS:
			if season in BIRDS[kind].seasons:
				kinds.append(kind)
		var kind: String = kinds[_rng.randi() % kinds.size()]
		var flock := 3 if kind == "quail" else (2 if kind == "junco" else 1)
		var at := Vector2(_rng.randf_range(view.position.x + 16, view.end.x - 16), _rng.randf_range(view.position.y + 24, view.end.y - 16))
		if at.distance_to(player) > SPAWN_CLEAR:
			for i in mini(flock, MAX_BIRDS - _birds.size()):
				# a flock spreads out a little, never one bird on another
				var spot := at + Vector2((i - flock / 2.0) * 11.0 + _rng.randf_range(-2, 2), _rng.randf_range(-5, 5))
				if _open(spot):
					_birds.append({"kind": kind, "pos": spot, "vel": Vector2.ZERO, "state": "peck",
						"time": _rng.randf_range(0.5, 2.0), "facing": 1 if _rng.randf() < 0.5 else -1, "hop": 0.0, "flap": 0.0})
	var warm := season == GameClock.Season.SPRING or season == GameClock.Season.SUMMER
	if warm and _flies.size() < MAX_BUTTERFLIES and _rng.randf() < 0.5:
		var from_left := _rng.randf() < 0.5
		var y := _rng.randf_range(view.position.y + 20, view.end.y - 20)
		_flies.append({"pos": Vector2(view.position.x - 8 if from_left else view.end.x + 8, y),
			"vel": Vector2(_rng.randf_range(8, 16) * (1 if from_left else -1), 0), "time": _rng.randf() * 10.0,
			"wings": _rng.randi() % BUTTERFLY_KINDS, "seed": _rng.randf() * TAU})


func _update_bird(bird: Dictionary, delta: float, player: Vector2) -> void:
	bird.time -= delta
	bird.flap += delta
	match bird.state:
		"peck", "hop":
			if bird.pos.distance_to(player) < FLEE_DISTANCE:
				_take_off(bird, player)
				return
			if bird.state == "hop":
				bird.hop += delta
				var t: float = bird.hop / 0.18
				bird.pos += bird.vel * delta
				if t >= 1.0:
					bird.state = "peck"
					bird.vel = Vector2.ZERO
			elif bird.time <= 0.0:
				# a hop to somewhere near, or a peck at the ground
				bird.time = _rng.randf_range(0.6, 2.2)
				if _rng.randf() < 0.55:
					var step := Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.5, 0.5)).normalized() * HOP
					if _open(bird.pos + step):
						bird.state = "hop"
						bird.hop = 0.0
						bird.vel = step / 0.18
						bird.facing = 1 if step.x >= 0.0 else -1
				else:
					bird.pecked = 0.25
			if bird.get("pecked", 0.0) > 0.0:
				bird.pecked = bird.pecked - delta
		"fly":
			bird.pos += bird.vel * delta
			bird.vel.y -= 30.0 * delta


func _take_off(bird: Dictionary, player: Vector2, loud := true) -> void:
	bird.state = "fly"
	var away: Vector2 = (bird.pos - player).normalized()
	if away == Vector2.ZERO:
		away = Vector2.RIGHT
	bird.vel = (away + Vector2(0, -0.8)).normalized() * FLY_SPEED * _rng.randf_range(0.8, 1.2)
	bird.facing = 1 if bird.vel.x >= 0.0 else -1
	# a covey goes up together
	for other in _birds:
		if other != bird and other.state != "fly" and other.kind == bird.kind and other.pos.distance_to(bird.pos) < 24.0:
			other.state = "fly"
			other.vel = (bird.vel.rotated(_rng.randf_range(-0.4, 0.4))) * _rng.randf_range(0.9, 1.1)
			other.facing = bird.facing
	if loud:
		Sound.play("flutter", -4.0, 0.15)


func _update_butterfly(fly: Dictionary, delta: float, active: bool) -> void:
	fly.time += delta
	var wobble := Vector2(0, sin(fly.time * 2.3 + fly.seed) * 14.0 + sin(fly.time * 5.1) * 6.0)
	fly.pos += (fly.vel + wobble) * delta
	if not active:
		fly.vel.y -= 20.0 * delta # off they go at dusk or in the rain


func _draw() -> void:
	for bird in _birds:
		_draw_bird(bird)
	for fly in _flies:
		var at: Vector2 = fly.pos
		var open := int(fly.time * 10.0) % 2 == 0
		# a faint shadow on the ground below
		draw_rect(Rect2((at + Vector2(-1, 9)).round(), Vector2(3, 1)), Color(0, 0, 0, 0.16))
		var src := Rect2((int(fly.wings) * 2 + (0 if open else 1)) * 8, BIRDS.size() * FRAME.y + 1, 8, 8)
		draw_texture_rect_region(SHEET, Rect2((at - Vector2(4, 4)).round(), Vector2(8, 8)), src)


func _draw_bird(bird: Dictionary) -> void:
	var at: Vector2 = bird.pos
	var flying: bool = bird.state == "fly"
	var frame := 0
	var lift := 0.0
	if flying:
		frame = 2 + int(bird.flap * 12.0) % 2
	elif bird.state == "hop":
		lift = -sin(clampf(bird.hop / 0.18, 0.0, 1.0) * PI) * 3.0
	elif bird.get("pecked", 0.0) > 0.0:
		frame = 1
	# a shadow on the ground while it's on the ground
	if not flying:
		draw_rect(Rect2((at + Vector2(-3, -1)).round(), Vector2(6, 1)), Color(0, 0, 0, 0.2))
		draw_rect(Rect2((at + Vector2(-2, 0)).round(), Vector2(4, 1)), Color(0, 0, 0, 0.12))
	var row: int = BIRDS[bird.kind].row
	var src := Rect2(frame * FRAME.x, row * FRAME.y, FRAME.x, FRAME.y)
	# feet on [param at]; mirrored when facing left
	draw_set_transform((at + Vector2(0, lift)).round(), 0.0, Vector2(bird.facing, 1))
	draw_texture_rect_region(SHEET, Rect2(-FRAME.x / 2.0, -FRAME.y + 1, FRAME.x, FRAME.y), src)
	draw_set_transform(Vector2.ZERO)
