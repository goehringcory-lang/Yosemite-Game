class_name Breath
extends Node2D
## Breath in the cold: on a cold morning or any winter day (Seasons.cold) the
## player and the people about the Valley breathe out a small white puff
## every few seconds, more often while they hurry along. Each puff is a few
## dithered blobs that drift out the way the face is turned, rise, swell and
## fade. Only outdoors, never right by a campfire. World adds one.
##
## Drawn by hand in world space, a few dozen quads at most, the same on both
## renderers.

## Seconds between breaths standing still, at the least and the most, and
## how much quicker they come while walking.
const GAP := Vector2(2.6, 4.2)
const WALKING := 0.6
## How long a puff lasts, seconds.
const LIFE := 1.8
## Where the mouth is, from the feet (the people are 32x48 sprites drawn with
## their feet at the origin).
const MOUTH := Vector2(0, -24)
## Characters further than this from the view's centre don't breathe (world
## pixels), to keep the work small.
const REACH := 360.0
## No breath this close to a campfire's warmth (world pixels).
const FIRE_WARM := 56.0
## Most puffs at once.
const MAX_PUFFS := 24

## Puff: [position, drift velocity, age].
var _puffs: Array = []
## Character -> [seconds to the next breath, last position].
var _who := {}
var _rng := RandomNumberGenerator.new()
var _on := false
var _fires_local: Array[Vector2] = []
var _fires_loaded := false
var _region: Node


func _ready() -> void:
	name = "Breath"
	z_index = 19
	z_as_relative = false
	_rng.randomize()


## How many puffs are in the air (for tests).
func puff_count() -> int:
	return _puffs.size()


func _process(delta: float) -> void:
	var world := get_parent()
	if world == null or not "region" in world:
		return
	var region: Node = world.region
	var on: bool = region != null and not region.indoors and Seasons.cold()
	if on != _on:
		_on = on
		if not on:
			_puffs.clear()
			_who.clear()
			queue_redraw()
	if region != _region:
		_region = region
		_fires_loaded = false
		_fires_local = []
		_who.clear()
	if _who.size() > 64:
		for id: int in _who.keys():
			if not is_instance_id_valid(id):
				_who.erase(id)
	if on:
		if not _fires_loaded:
			_fires_loaded = true
			_fires_local = _campfires_local(region)
		var centre := _view_centre()
		if world.player and world.player.is_visible_in_tree():
			_tick(world.player, delta, centre)
		for walker: Node in get_tree().get_nodes_in_group(Footprints.GROUP):
			if walker is NPC and (walker as Node2D).is_visible_in_tree():
				_tick(walker, delta, centre)
	if _puffs.is_empty():
		return
	for i in range(_puffs.size() - 1, -1, -1):
		var p: Array = _puffs[i]
		p[2] += delta
		if p[2] >= LIFE:
			_puffs.remove_at(i)
			continue
		var v: Vector2 = p[1]
		p[0] += v * delta
		# slows as it spreads, and rises
		p[1] = v * (1.0 - 1.6 * delta) + Vector2(0, -6.0 * delta)
	queue_redraw()


func _tick(who: Node2D, delta: float, centre: Vector2) -> void:
	var at := who.global_position
	if at.distance_squared_to(centre) > REACH * REACH:
		return
	var id := who.get_instance_id()
	var state: Array = _who.get(id, [])
	if state.is_empty():
		state = [_rng.randf_range(0.0, GAP.y), at]
		_who[id] = state
	var moving: bool = at.distance_squared_to(state[1]) > 0.01
	state[1] = at
	state[0] -= delta * (1.0 / WALKING if moving else 1.0)
	if state[0] > 0.0:
		return
	state[0] = _rng.randf_range(GAP.x, GAP.y)
	if _near_fire(at):
		return
	var facing: Vector2 = Vector2(who.get("facing")) if who.get("facing") != null else Vector2.DOWN
	exhale(at, facing)


## Breathes a puff out of the mouth of someone standing at [param feet],
## facing [param facing].
## Nothing while it isn't cold.
func exhale(feet: Vector2, facing: Vector2) -> void:
	if not _on:
		return
	var dir := facing.normalized() if facing != Vector2.ZERO else Vector2.DOWN
	# facing away, the breath would be drawn over the back of the head
	if dir.y < -0.7:
		return
	var mouth := feet + MOUTH + Vector2(dir.x * 7.0, maxf(dir.y, 0.0) * 3.0 + minf(dir.y, 0.0) * 2.0)
	for k in 3:
		if _puffs.size() >= MAX_PUFFS:
			_puffs.pop_front()
		var spread := Vector2(_rng.randf_range(-3.0, 3.0), _rng.randf_range(-3.0, 1.0))
		_puffs.append([mouth + dir * float(k), dir * (10.0 + 2.0 * k) + spread, -0.06 * k])


func _draw() -> void:
	for p: Array in _puffs:
		var age: float = p[2]
		if age < 0.0:
			continue
		var t := age / LIFE
		# swells, then thins out; dithered in whole pixels, faint (cozy, not
		# smoke)
		var r := mini(2 + int(t * 3.0), 4)
		var a := 0.75 * (1.0 - t * t)
		var c := Color(1.0, 1.0, 1.0, a)
		# a cool rim along the underside, so the puff shows against snow too
		var rim := Color(0.66, 0.74, 0.9, a * 0.9)
		var at: Vector2 = (p[0] as Vector2).floor()
		# a round blob in whole pixels, a row at a time
		for dy in range(-r, r + 1):
			var w := floori(sqrt(float(r * r - dy * dy)))
			if dy <= 0:
				draw_rect(Rect2(at + Vector2(-w, dy), Vector2(2 * w + 1, 1)), c)
			elif dy >= r - 1 or w < 1:
				draw_rect(Rect2(at + Vector2(-w, dy), Vector2(2 * w + 1, 1)), rim)
			else:
				draw_rect(Rect2(at + Vector2(-w + 1, dy), Vector2(2 * w - 1, 1)), c)
				draw_rect(Rect2(at + Vector2(-w, dy), Vector2.ONE), rim)
				draw_rect(Rect2(at + Vector2(w, dy), Vector2.ONE), rim)


func _near_fire(at: Vector2) -> bool:
	if _fires_local.is_empty():
		return false
	var local_at := (_region as Node2D).to_local(at) if _region is Node2D else at
	for f in _fires_local:
		if f.distance_squared_to(local_at) < FIRE_WARM * FIRE_WARM:
			return true
	return false


## Where the campfires are in [param region], cached in region-local pixels
## (sprites whose art is a campfire, a fire pit or a lit fire ring; not
## woodpiles or cold rings).
static func _campfires_local(region: Node) -> Array[Vector2]:
	if region == null:
		return []
	if region.has_meta("breath_fires_local"):
		return region.get_meta("breath_fires_local")
	var out: Array[Vector2] = []
	var as_2d := region as Node2D
	for node in region.find_children("*", "Sprite2D", true, false):
		var sprite := node as Sprite2D
		var tex := sprite.texture
		var file := tex.resource_path.get_file() if tex else ""
		if file.contains("campfire") or file.contains("fire_pit") or (file.contains("fire_ring") and not file.contains("cold")):
			out.append(as_2d.to_local(sprite.global_position) if as_2d else sprite.global_position)
	region.set_meta("breath_fires_local", out)
	return out


func _view_centre() -> Vector2:
	var camera := get_viewport().get_camera_2d()
	return camera.get_screen_center_position() if camera else Vector2.ZERO
