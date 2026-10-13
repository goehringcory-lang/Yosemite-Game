class_name Rustle
extends Node
## Ferns, bracken, shrubs and flowers sway when you brush past them, like the
## grass in Stardew Valley, with a soft rustle of leaves. The plants are the
## "Plant..." props the hub builders scatter (a body with a "Sprite" child
## whose origin is its base), so a skew bends the top and keeps the roots.
## World adds one.

## How near the player's feet must come (world pixels, across and up or down).
const REACH := Vector2(18, 12)
## Seconds a sway lasts, how far it leans (radians), and how fast it rocks.
const SWAY_TIME := 0.7
const LEAN := 0.32
const ROCKS := 3.0
## At most one rustle sound this often.
const SOUND_GAP := 0.12

## Plant sprite -> seconds left in its sway (and which way it leans).
var _swaying: Dictionary = {}
var _plants: Array[Sprite2D] = []
var _region: Node
var _sound_wait := 0.0
var _last_feet := Vector2.INF


## The plants in the current region (for tests).
func plant_count() -> int:
	return _plants.size()


func _process(delta: float) -> void:
	var world := get_parent()
	if world == null or not "region" in world or world.player == null:
		return
	if world.region != _region:
		_region = world.region
		_collect()
	_sound_wait -= delta
	var feet: Vector2 = world.player.global_position
	if feet.distance_squared_to(_last_feet) > 1.0:
		var moving_right := feet.x >= _last_feet.x if _last_feet != Vector2.INF else true
		_last_feet = feet
		for sprite in _plants:
			if not is_instance_valid(sprite):
				continue
			var base := sprite.global_position
			if absf(base.x - feet.x) <= REACH.x and absf(base.y - feet.y) <= REACH.y and not _swaying.has(sprite):
				brush(sprite, 1.0 if moving_right else -1.0)
	for sprite: Sprite2D in _swaying.keys():
		if not is_instance_valid(sprite):
			_swaying.erase(sprite)
			continue
		var sway: Dictionary = _swaying[sprite]
		sway.time -= delta
		if sway.time <= 0.0:
			sprite.skew = 0.0
			_swaying.erase(sprite)
			continue
		var t: float = 1.0 - sway.time / SWAY_TIME
		sprite.skew = sway.dir * LEAN * sin(t * TAU * ROCKS / 2.0) * (1.0 - t) * (1.0 - t)


## Sets [param sprite] swaying, leaning toward [param direction] (+1 right).
func brush(sprite: Sprite2D, direction := 1.0) -> void:
	_swaying[sprite] = {"time": SWAY_TIME, "dir": direction}
	if _sound_wait <= 0.0:
		_sound_wait = SOUND_GAP
		Sound.play("rustle", -6.0, 0.15)


## True while [param sprite] is swaying (for tests).
func is_swaying(sprite: Sprite2D) -> bool:
	return _swaying.has(sprite)


func _collect() -> void:
	_plants.clear()
	_swaying.clear()
	if _region == null or not "entities" in _region or _region.entities == null:
		return
	for child in _region.entities.get_children():
		if child.name.begins_with("Plant"):
			var sprite := child.get_node_or_null("Sprite") as Sprite2D
			if sprite:
				_plants.append(sprite)
