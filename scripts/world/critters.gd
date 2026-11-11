class_name Critters
extends Node2D
## The little lives around you outdoors, like Stardew Valley's: birds that
## hop and peck about on open ground and flutter off when you come close, and
## butterflies drifting over the meadows on fair spring and summer days. They
## are a few pixels each, drawn here, and come and go around the view; none in
## the rain, after dark, or indoors. World adds one.
##
## The birds are the Valley's own: Steller's jays and dark-eyed juncos all
## year, robins from spring to fall, California quail in little coveys,
## acorn woodpeckers down among the Valley's oaks, and Clark's nutcrackers up
## in the high country.
##
## Squirrels too, each where it lives: western gray squirrels in the Valley's
## oaks and pines, California ground squirrels on open ground below the high
## country, Douglas squirrels (chickarees) in the conifer forests up high and
## at Wawona, and golden-mantled ground squirrels among the high granite. The
## ground squirrels sleep through the winter. A squirrel sits up to nibble,
## scampers a little way, sits up again, and dashes off when you come close.

## Most birds and butterflies about at once.
const MAX_BIRDS := 5
const MAX_BUTTERFLIES := 4
const MAX_SQUIRRELS := 2
## How close the player can come before a squirrel dashes off.
const SQUIRREL_FLEE := 70.0
const SQUIRREL_RUN := 70.0
const SQUIRREL_FLEE_SPEED := 190.0
## Seconds between tries at adding one while there are fewer.
const SPAWN_EVERY := 2.5
## How close the player can come before a bird takes off.
const FLEE_DISTANCE := 60.0
## Walk (not run) this close to a bird, or a butterfly, and it goes in your
## field log (FieldLog).
const SPOT_DISTANCE := 110.0
const SPOT_BUTTERFLY := 80.0
## Birds keep this far from the player when they land.
const SPAWN_CLEAR := 140.0
const FLY_SPEED := 180.0
const HOP := 12.0

## The sprites (tools/npcgen/critter_art.gd): a row of 24x22 frames per
## bird (standing, pecking, wings up, wings down), facing right, and a row of
## 16x16 butterfly pairs (open, closed) under them.
const SHEET := preload("res://assets/sprites/critters.png")
const FRAME := Vector2(24, 22)
## Each bird: its row on the sheet (or -1 for one painted on
## WildlifeSheet), the seasons it's about, and where (see _lives_here).
const BIRDS := {
	"stellers_jay": {"row": 0, "seasons": [0, 1, 2, 3]},
	"junco": {"row": 1, "seasons": [0, 2, 3]},
	"robin": {"row": 2, "seasons": [0, 1, 2]},
	"quail": {"row": 3, "seasons": [0, 1, 2, 3]},
	"acorn_woodpecker": {"row": -1, "seasons": [0, 1, 2, 3], "where": "low"},
	"clarks_nutcracker": {"row": -1, "seasons": [0, 1, 2, 3], "where": "high"},
}
## The rows of birds on SHEET, above the butterflies.
const SHEET_BIRD_ROWS := 4
## Each squirrel (painted on WildlifeSheet): the seasons it's out and where.
const SQUIRRELS := {
	"western_gray_squirrel": {"seasons": [0, 1, 2, 3], "where": "low"},
	"california_ground_squirrel": {"seasons": [0, 1, 2], "where": "low", "also": ["glacier_point", "wawona"]},
	"douglas_squirrel": {"seasons": [0, 1, 2, 3], "where": "high", "also": ["wawona"]},
	"golden_mantled_ground_squirrel": {"seasons": [0, 1, 2], "where": "high"},
}
## The high country, above the Valley's oaks: where the nutcrackers, the
## chickarees and the golden-mantled ground squirrels live.
const HIGH_REGIONS := ["tuolumne_meadows", "tuolumne_lodge", "glacier_point", "half_dome", "little_yosemite_valley",
	"crane_flat", "big_oak_flat_junction"]
## Butterflies of the Valley: western tiger swallowtail, California sister,
## Lorquin's admiral, a cabbage white (their columns on the sheet).
const BUTTERFLY_KINDS := 4

## Each critter: {kind, pos, vel, state, time, ...}.
var _birds: Array[Dictionary] = []
var _flies: Array[Dictionary] = []
var _squirrels: Array[Dictionary] = []
var _spawn_timer := 1.0
var _rng := RandomNumberGenerator.new()
var _last_region: Node


func _ready() -> void:
	z_index = 4
	_rng.randomize()
	add_to_group("photo_subjects")


## What a camera pointed this way sees (Photos): every bird, squirrel and
## butterfly about, where it's drawn.
func photo_subjects() -> Array:
	var out := []
	for bird in _birds:
		out.append({"kind": "animal", "id": bird.kind, "name": str(FieldLog.get_animal(bird.kind).get("name", "A bird")), "at": to_global(bird.pos + Vector2(0, -8))})
	for squirrel in _squirrels:
		out.append({"kind": "animal", "id": squirrel.kind, "name": str(FieldLog.get_animal(squirrel.kind).get("name", "A squirrel")), "at": to_global(squirrel.pos + Vector2(0, -8))})
	for fly in _flies:
		var id := "butterfly_%d" % fly.wings
		out.append({"kind": "animal", "id": id, "name": str(FieldLog.get_animal(id).get("name", "A butterfly")), "at": to_global(fly.pos)})
	return out


## Puts a bird of [param kind] at [param at] (for tests).
func add_bird(kind: String, at: Vector2) -> Dictionary:
	var bird := {"kind": kind, "pos": at, "vel": Vector2.ZERO, "state": "peck", "time": 1.0, "facing": 1, "hop": 0.0, "flap": 0.0}
	_birds.append(bird)
	return bird


## Puts a squirrel of [param kind] at [param at] (for tests).
func add_squirrel(kind: String, at: Vector2) -> Dictionary:
	var squirrel := {"kind": kind, "pos": at, "vel": Vector2.ZERO, "state": "sit", "time": 1.5, "facing": 1, "steps": 0.0, "alert": false}
	_squirrels.append(squirrel)
	return squirrel


## How many of each are about (for tests).
func counts() -> Dictionary:
	return {"birds": _birds.size(), "butterflies": _flies.size(), "squirrels": _squirrels.size()}


## True if a bird or squirrel of [param info] (an entry of BIRDS or
## SQUIRRELS) lives in [param region_id]: "where" is "low" for below the
## high country, "high" for HIGH_REGIONS, or absent for anywhere; "also"
## names more places.
static func lives_in(info: Dictionary, region_id: String) -> bool:
	if region_id in info.get("also", []):
		return true
	match info.get("where", ""):
		"low":
			return not region_id in HIGH_REGIONS and not region_id.begins_with("tuolumne")
		"high":
			return region_id in HIGH_REGIONS or region_id.begins_with("tuolumne")
	return true


func _region_id() -> String:
	var world := _world()
	var region: Region = world.region if world and "region" in world else null
	return region.region_id if region else ""


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
		_squirrels.clear()
		_spawn_timer = 0.8
	var active := _outdoors_by_day()
	if active:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = SPAWN_EVERY
			_try_spawn()
	var view := _view().grow(80.0)
	var player := _player_position()
	if not active:
		# dusk, rain or indoors: the birds still about fly off, quietly
		for bird in _birds:
			if bird.state != "fly":
				_take_off(bird, bird.pos + Vector2(_rng.randf_range(-8.0, 8.0), 12.0), false)
	for bird in _birds:
		_update_bird(bird, delta, player)
	for fly in _flies:
		_update_butterfly(fly, delta, active)
	for squirrel in _squirrels:
		_update_squirrel(squirrel, delta, player, active)
	if active and not _running():
		_spot(player)
	_birds = _birds.filter(func(b: Dictionary) -> bool: return view.has_point(b.pos) or b.state != "fly")
	_flies = _flies.filter(func(f: Dictionary) -> bool: return view.grow(80.0).has_point(f.pos))
	# birds left behind off screen go quietly
	_birds = _birds.filter(func(b: Dictionary) -> bool: return view.grow(160.0).has_point(b.pos))
	_squirrels = _squirrels.filter(func(q: Dictionary) -> bool: return view.has_point(q.pos) or (q.state != "flee" and view.grow(160.0).has_point(q.pos)))
	queue_redraw()


func _running() -> bool:
	var world := _world()
	var walker: Player = world.player if world and "player" in world else null
	return walker != null and walker.velocity != Vector2.ZERO and Input.is_action_pressed("run")


## Logs the birds and butterflies close enough to get a good look at.
func _spot(player: Vector2) -> void:
	for bird in _birds:
		if bird.state != "fly" and bird.pos.distance_to(player) < SPOT_DISTANCE:
			FieldLog.spot(bird.kind)
	for fly in _flies:
		if fly.pos.distance_to(player) < SPOT_BUTTERFLY:
			FieldLog.spot("butterfly_%d" % fly.wings)
	for squirrel in _squirrels:
		if squirrel.state != "flee" and squirrel.pos.distance_to(player) < SPOT_DISTANCE:
			FieldLog.spot(squirrel.kind)


func _try_spawn() -> void:
	var view := _view()
	var player := _player_position()
	var season := GameClock.season
	var here := _region_id()
	if _birds.size() < MAX_BIRDS and _rng.randf() < 0.7:
		var kinds := []
		for kind: String in BIRDS:
			if season in BIRDS[kind].seasons and lives_in(BIRDS[kind], here):
				kinds.append(kind)
		var kind: String = kinds[_rng.randi() % kinds.size()]
		var flock := 3 if kind == "quail" else (2 if kind == "junco" else 1)
		var at := Vector2(_rng.randf_range(view.position.x + 32, view.end.x - 32), _rng.randf_range(view.position.y + 48, view.end.y - 32))
		if at.distance_to(player) > SPAWN_CLEAR:
			for i in mini(flock, MAX_BIRDS - _birds.size()):
				# a flock spreads out a little, never one bird on another
				var spot := at + Vector2((i - flock / 2.0) * 22.0 + _rng.randf_range(-4, 4), _rng.randf_range(-10, 10))
				if _open(spot):
					_birds.append({"kind": kind, "pos": spot, "vel": Vector2.ZERO, "state": "peck",
						"time": _rng.randf_range(0.5, 2.0), "facing": 1 if _rng.randf() < 0.5 else -1, "hop": 0.0, "flap": 0.0})
	if _squirrels.size() < MAX_SQUIRRELS and _rng.randf() < 0.35:
		var kinds := []
		for kind: String in SQUIRRELS:
			if season in SQUIRRELS[kind].seasons and lives_in(SQUIRRELS[kind], here):
				kinds.append(kind)
		if not kinds.is_empty():
			var at := Vector2(_rng.randf_range(view.position.x + 32, view.end.x - 32), _rng.randf_range(view.position.y + 48, view.end.y - 32))
			if at.distance_to(player) > SPAWN_CLEAR and _open(at):
				var squirrel := add_squirrel(kinds[_rng.randi() % kinds.size()], at)
				squirrel.facing = 1 if _rng.randf() < 0.5 else -1
				squirrel.time = _rng.randf_range(1.0, 3.0)
	var warm := season == GameClock.Season.SPRING or season == GameClock.Season.SUMMER
	if warm and _flies.size() < MAX_BUTTERFLIES and _rng.randf() < 0.5:
		var from_left := _rng.randf() < 0.5
		var y := _rng.randf_range(view.position.y + 40, view.end.y - 40)
		_flies.append({"pos": Vector2(view.position.x - 16 if from_left else view.end.x + 16, y),
			"vel": Vector2(_rng.randf_range(16, 32) * (1 if from_left else -1), 0), "time": _rng.randf() * 10.0,
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
			bird.vel.y -= 60.0 * delta


func _take_off(bird: Dictionary, player: Vector2, loud := true) -> void:
	bird.state = "fly"
	var away: Vector2 = (bird.pos - player).normalized()
	if away == Vector2.ZERO:
		away = Vector2.RIGHT
	bird.vel = (away + Vector2(0, -0.8)).normalized() * FLY_SPEED * _rng.randf_range(0.8, 1.2)
	bird.facing = 1 if bird.vel.x >= 0.0 else -1
	# a covey goes up together
	for other in _birds:
		if other != bird and other.state != "fly" and other.kind == bird.kind and other.pos.distance_to(bird.pos) < 48.0:
			other.state = "fly"
			other.vel = (bird.vel.rotated(_rng.randf_range(-0.4, 0.4))) * _rng.randf_range(0.9, 1.1)
			other.facing = bird.facing
	if loud:
		Sound.play("flutter", -4.0, 0.15)


## A squirrel sits up and nibbles, looks about, scampers a little way and
## sits up again; come close and it dashes off, away from you, at a run.
func _update_squirrel(squirrel: Dictionary, delta: float, player: Vector2, active: bool) -> void:
	squirrel.time -= delta
	match squirrel.state:
		"sit":
			if squirrel.pos.distance_to(player) < SQUIRREL_FLEE or not active:
				_squirrel_flee(squirrel, player)
				return
			if squirrel.time <= 0.0:
				if _rng.randf() < 0.5:
					var step := Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.6, 0.6)).normalized() * _rng.randf_range(24.0, 56.0)
					if _open(squirrel.pos + step) and (squirrel.pos + step).distance_to(player) > SQUIRREL_FLEE + 10.0:
						squirrel.state = "run"
						squirrel.vel = step.normalized() * SQUIRREL_RUN
						squirrel.time = step.length() / SQUIRREL_RUN
						squirrel.facing = 1 if step.x >= 0.0 else -1
						return
				squirrel.alert = not squirrel.alert
				squirrel.time = _rng.randf_range(0.8, 2.4)
		"run", "flee":
			var next: Vector2 = squirrel.pos + squirrel.vel * delta
			if squirrel.state == "run" and not _open(next):
				squirrel.state = "sit"
				squirrel.time = 1.0
				return
			squirrel.pos = next
			squirrel.steps += delta
			if squirrel.state == "run":
				if squirrel.pos.distance_to(player) < SQUIRREL_FLEE:
					_squirrel_flee(squirrel, player)
				elif squirrel.time <= 0.0:
					squirrel.state = "sit"
					squirrel.alert = true
					squirrel.time = _rng.randf_range(1.0, 2.5)


func _squirrel_flee(squirrel: Dictionary, player: Vector2) -> void:
	squirrel.state = "flee"
	var away: Vector2 = (squirrel.pos - player).normalized()
	if away == Vector2.ZERO or not away.is_finite():
		away = Vector2.RIGHT
	squirrel.vel = away * SQUIRREL_FLEE_SPEED
	squirrel.facing = 1 if away.x >= 0.0 else -1
	Sound.play("rustle", -10.0, 0.2, 1.6)


func _update_butterfly(fly: Dictionary, delta: float, active: bool) -> void:
	fly.time += delta
	var wobble := Vector2(0, sin(fly.time * 2.3 + fly.seed) * 28.0 + sin(fly.time * 5.1) * 12.0)
	fly.pos += (fly.vel + wobble) * delta
	if not active:
		fly.vel.y -= 40.0 * delta # off they go at dusk or in the rain


func _draw() -> void:
	for squirrel in _squirrels:
		_draw_squirrel(squirrel)
	for bird in _birds:
		_draw_bird(bird)
	for fly in _flies:
		var at: Vector2 = fly.pos
		var open := int(fly.time * 10.0) % 2 == 0
		# a faint shadow on the ground below
		draw_rect(Rect2((at + Vector2(-2, 18)).round(), Vector2(6, 2)), Color(0, 0, 0, 0.16))
		var src := Rect2((int(fly.wings) * 2 + (0 if open else 1)) * 16, SHEET_BIRD_ROWS * FRAME.y + 2, 16, 16)
		draw_texture_rect_region(SHEET, Rect2((at - Vector2(8, 8)).round(), Vector2(16, 16)), src)


func _draw_bird(bird: Dictionary) -> void:
	var at: Vector2 = bird.pos
	var flying: bool = bird.state == "fly"
	var frame := 0
	var lift := 0.0
	if flying:
		frame = 2 + int(bird.flap * 12.0) % 2
	elif bird.state == "hop":
		lift = -sin(clampf(bird.hop / 0.18, 0.0, 1.0) * PI) * 6.0
	elif bird.get("pecked", 0.0) > 0.0:
		frame = 1
	# a shadow on the ground while it's on the ground
	if not flying:
		draw_rect(Rect2((at + Vector2(-6, -2)).round(), Vector2(12, 2)), Color(0, 0, 0, 0.2))
		draw_rect(Rect2((at + Vector2(-4, 0)).round(), Vector2(8, 2)), Color(0, 0, 0, 0.12))
	var row: int = BIRDS[bird.kind].row
	if row < 0:
		WildlifeSheet.draw(self, bird.kind, frame, at + Vector2(0, lift), bird.facing)
		return
	var src := Rect2(frame * FRAME.x, row * FRAME.y, FRAME.x, FRAME.y)
	# feet on [param at]; mirrored when facing left
	draw_set_transform((at + Vector2(0, lift)).round(), 0.0, Vector2(bird.facing, 1))
	draw_texture_rect_region(SHEET, Rect2(-FRAME.x / 2.0, -FRAME.y + 2, FRAME.x, FRAME.y), src)
	draw_set_transform(Vector2.ZERO)


func _draw_squirrel(squirrel: Dictionary) -> void:
	var at: Vector2 = squirrel.pos
	var frame := 1 if squirrel.alert else 0
	if squirrel.state != "sit":
		frame = 2 + int(squirrel.steps * 12.0) % 2
	draw_rect(Rect2((at + Vector2(-6, -2)).round(), Vector2(12, 2)), Color(0, 0, 0, 0.2))
	WildlifeSheet.draw(self, squirrel.kind, frame, at, squirrel.facing)
