class_name Falcons
extends Node2D
## Peregrine falcons over the big cliffs. Under El Capitan, the Cathedral
## Rocks, Glacier Point and the walls round the Valley, look up now and then
## and one comes sailing over high on pointed wings, circles, then folds its
## wings and stoops on a bird below, faster than anything else alive (well
## over 200 miles an hour), and swings back up and away. It's seen from
## above, like the birds on the ground, with its shadow far below on the
## Valley floor. Seeing one puts it in your field log (FieldLog). World adds
## one of these.
##
## Peregrines nearly vanished from California in the 1970s, poisoned by DDT.
## Climbers and biologists helped bring them back, and the Valley's walls
## have nesting pairs again; in spring the park closes some climbing routes
## near their nests.

## The places under the big walls where they hunt.
const CLIFFS := ["el_capitan_meadow", "bridalveil_fall", "tunnel_view", "glacier_point", "leidig_meadow",
	"yosemite_village", "half_dome", "ahwahnee_meadow", "mirror_lake", "four_mile_trailhead"]
## Seconds outdoors under the cliffs between chances of one, and the chance,
## by GameClock.Season (spring, when they nest and feed young, the most).
const CHECK_EVERY := 14.0
const SEASON_CHANCE := [0.45, 0.35, 0.3, 0.2]
## No new one this soon after the last went.
const COOLDOWN := 70.0
const SOAR_HEIGHT := 150.0
const SOAR_SPEED := 70.0
const STOOP_SPEED := 340.0
## This long on screen is a good enough look to log one.
const SPOT_TIME := 1.2
const SPRITE_ID := "peregrine_falcon"

## Each falcon: {pos (the ground under it), height, vel, state ("soar",
## "stoop", "climb" or "leave"), time, seen, flap}.
var _falcons: Array[Dictionary] = []
## The bird it's after, and the puff of feathers when it strikes.
var _prey: Array[Dictionary] = []
var _puffs: Array[Dictionary] = []
var _timer := CHECK_EVERY * 0.5
var _cooldown := 0.0
var _rng := RandomNumberGenerator.new()
var _last_region: Node


func _ready() -> void:
	z_index = 30
	_rng.randomize()


func _world() -> Node:
	return get_parent()


func _region() -> Region:
	var world := _world()
	return world.region if world and "region" in world else null


## The ones about now (for tests).
func falcons() -> Array[Dictionary]:
	return _falcons


## True if one could be out over this place now: outdoors under the cliffs,
## by day, not in a downpour.
func active() -> bool:
	var region := _region()
	if region == null or region.indoors or not region.region_id in CLIFFS:
		return false
	if Weather.today().rain > 0.5:
		return false
	return GameClock.hour >= 7 and GameClock.hour < 19


func chance() -> float:
	return SEASON_CHANCE[GameClock.season] if active() else 0.0


func _view() -> Rect2:
	var camera := get_viewport().get_camera_2d()
	var size := get_viewport_rect().size
	if camera == null:
		return Rect2(Vector2.ZERO, size)
	var extent := size / camera.zoom
	return Rect2(camera.get_screen_center_position() - extent / 2.0, extent)


## Sends one in over the view now (for tests, and the timer).
func send_one() -> Dictionary:
	var view := _view()
	var from_left := _rng.randf() < 0.5
	var y := _rng.randf_range(view.position.y + view.size.y * 0.45, view.end.y + 40.0)
	var falcon := {"pos": Vector2(view.position.x - 60.0 if from_left else view.end.x + 60.0, y), "height": SOAR_HEIGHT,
		"vel": Vector2(SOAR_SPEED * (1.0 if from_left else -1.0), _rng.randf_range(-12.0, 12.0)), "state": "soar",
		"time": _rng.randf_range(2.5, 4.5), "seen": 0.0, "flap": 0.0, "turn": _rng.randf_range(-0.35, 0.35)}
	_falcons.append(falcon)
	return falcon


func _process(delta: float) -> void:
	var region := _region()
	if region != _last_region:
		_last_region = region
		_falcons.clear()
		_prey.clear()
		_puffs.clear()
		_timer = CHECK_EVERY * 0.5
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _falcons.is_empty() and _cooldown <= 0.0 and active():
		_timer -= delta
		if _timer <= 0.0:
			_timer = CHECK_EVERY
			if _rng.randf() < chance():
				send_one()
	var view := _view()
	for falcon in _falcons:
		_update(falcon, delta, view)
	for bird in _prey:
		bird.pos += bird.vel * delta
		bird.flap += delta
	for puff in _puffs:
		puff.time += delta
	_puffs = _puffs.filter(func(p: Dictionary) -> bool: return p.time < 1.4)
	_prey = _prey.filter(func(b: Dictionary) -> bool: return view.grow(80.0).has_point(b.pos) and not b.get("caught", false))
	var before := _falcons.size()
	_falcons = _falcons.filter(func(f: Dictionary) -> bool: return f.state != "leave" or view.grow(120.0).has_point(f.pos - Vector2(0, f.height)))
	if before > 0 and _falcons.is_empty():
		_cooldown = COOLDOWN
	queue_redraw()


func _update(falcon: Dictionary, delta: float, view: Rect2) -> void:
	falcon.time -= delta
	falcon.flap += delta
	var shown: Vector2 = falcon.pos - Vector2(0, falcon.height)
	if view.has_point(shown) and active():
		falcon.seen += delta
		if falcon.seen >= SPOT_TIME or falcon.state == "stoop":
			FieldLog.spot("peregrine_falcon")
	match falcon.state:
		"soar":
			# wide, lazy circles high over the meadow
			falcon.vel = falcon.vel.rotated(falcon.turn * delta)
			falcon.pos += falcon.vel * delta
			if falcon.time <= 0.0:
				_pick_prey(falcon, view)
		"stoop":
			var bird: Dictionary = falcon.target
			var aim: Vector2 = bird.pos + bird.vel * 0.15
			var to: Vector2 = aim - shown
			if to.length() < 10.0:
				# the strike: a puff of feathers, and back up it goes
				bird.caught = _rng.randf() < 0.5
				_puffs.append({"pos": bird.pos, "time": 0.0})
				falcon.state = "climb"
				falcon.time = 1.6
				falcon.vel = Vector2(signf(falcon.vel.x if falcon.vel.x != 0.0 else 1.0) * SOAR_SPEED * 1.6, 0)
				return
			var step := to.normalized() * minf(STOOP_SPEED * delta, to.length())
			# the dive is mostly height lost, a little ground covered; it
			# shows just where it's headed either way
			falcon.height = maxf(falcon.height - step.y * 0.9, 18.0)
			falcon.pos = shown + step + Vector2(0, falcon.height)
			falcon.vel = to.normalized() * STOOP_SPEED
		"climb":
			falcon.height = minf(falcon.height + 90.0 * delta, SOAR_HEIGHT)
			falcon.pos += falcon.vel * delta
			if falcon.time <= 0.0:
				falcon.state = "leave"
				falcon.vel = falcon.vel.normalized() * SOAR_SPEED * 1.8
		"leave":
			falcon.pos += falcon.vel * delta
			falcon.height = minf(falcon.height + 40.0 * delta, SOAR_HEIGHT * 1.3)


## Sends a bird (a white-throated swift or a band-tailed pigeon) across below
## it, and the falcon folds its wings after it.
func _pick_prey(falcon: Dictionary, view: Rect2) -> void:
	var shown: Vector2 = falcon.pos - Vector2(0, falcon.height)
	var ahead := signf(falcon.vel.x) if falcon.vel.x != 0.0 else 1.0
	var at := Vector2(clampf(shown.x + ahead * 120.0, view.position.x + 40.0, view.end.x - 40.0), clampf(shown.y + 130.0, view.position.y + 60.0, view.end.y - 50.0))
	var bird := {"pos": at, "vel": Vector2(-ahead * 90.0, _rng.randf_range(-20.0, 20.0)), "flap": 0.0}
	_prey.append(bird)
	falcon.state = "stoop"
	falcon.target = bird
	Sound.play("slack_gust", -14.0, 0.1, 1.7)


func _draw() -> void:
	for bird in _prey:
		var at: Vector2 = bird.pos.round()
		var flap := int(bird.flap * 14.0) % 2
		var col := Color(0.12, 0.11, 0.14, 0.9)
		draw_rect(Rect2(at, Vector2(2, 1)), col)
		draw_rect(Rect2(at + Vector2(-2, -flap), Vector2(2, 1)), col)
		draw_rect(Rect2(at + Vector2(2, -flap), Vector2(2, 1)), col)
	for puff in _puffs:
		var t: float = puff.time
		for i in 7:
			var dir := Vector2.RIGHT.rotated(i * TAU / 7.0 + 0.4)
			var at: Vector2 = puff.pos + dir * (4.0 + t * 14.0) + Vector2(0, t * t * 10.0)
			draw_rect(Rect2(at.round(), Vector2(1, 1)), Color(0.94, 0.92, 0.88, clampf(1.2 - t, 0.0, 1.0)))
	for falcon in _falcons:
		var height: float = falcon.height
		# its shadow on the ground far below, fainter the higher it is
		var fade := clampf(1.0 - height / (SOAR_HEIGHT * 1.4), 0.15, 0.6)
		draw_rect(Rect2((falcon.pos + Vector2(-5, -1)).round(), Vector2(10, 2)), Color(0, 0, 0, 0.25 * fade))
		var frame := 0
		match falcon.state:
			"stoop":
				frame = 2
			"climb":
				frame = 1 if int(falcon.flap * 9.0) % 2 == 0 else 3
			_:
				# a few quick beats, then a long glide
				if fmod(falcon.flap, 3.0) < 0.6:
					frame = 1 if int(falcon.flap * 9.0) % 2 == 0 else 3
		var facing := 1 if falcon.vel.x >= 0.0 else -1
		var shown: Vector2 = falcon.pos - Vector2(0, height)
		# the sprite's body is on the cell's middle row; aim it along its flight
		var angle := 0.0
		if falcon.state == "stoop":
			var dir: Vector2 = falcon.vel.normalized()
			angle = atan2(dir.y, absf(dir.x)) * facing
		draw_set_transform(shown.round(), angle, Vector2(facing, 1))
		draw_texture_rect_region(WildlifeSheet.sheet(), Rect2(-WildlifeSheet.CELL.x / 2.0 - 4.0, -16.0, WildlifeSheet.CELL.x, WildlifeSheet.CELL.y),
			WildlifeSheet.region(SPRITE_ID, frame))
		draw_set_transform(Vector2.ZERO)
