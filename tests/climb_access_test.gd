extends Node
## Checks where the climbs are: the player can walk from the region's arrival
## spot to every climb's sign and use it, and every sign stands at the foot of
## a wall, not out in a meadow or inside the rock.
## Run: godot --headless --path . res://tests/climb_access_test.tscn
## Exit code is the number of failed checks.

const Terrain = preload("res://tools/mapgen/terrain.gd")
const CONTENT_DIR := "res://scenes/story/content/"
## The walk is tried on a grid this fine, so a one-tile gap still counts.
const STEP := 8.0
## A climb's hitbox (scenes/climb/climb_start.tscn).
const HITBOX := Rect2(-8, -11, 16, 14)
## Routes with no wall to stand under: the Lyell Glacier is a walk up Lyell
## Canyon, and its sign is at the trailhead by the Tuolumne lodge.
const NO_WALL := ["lyell_glacier"]

## The player's body and the reach of the interact button, read from
## scenes/player/player.tscn in _ready().
var body := Rect2()
var reach := 0.0
var reach_size := Vector2()
var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	_read_player()
	var seen := {}
	for file in DirAccess.get_files_at(CONTENT_DIR):
		if not file.ends_with(".tscn"):
			continue
		var region_id := file.get_basename()
		var hub := Park.get_hub(region_id)
		var region: Region = (load(hub.scene_path() if hub else "res://scenes/regions/%s.tscn" % region_id) as PackedScene).instantiate()
		add_child(region)
		StoryContent.attach(region)
		var climbs: Array = region.entities.get_children().filter(func(n: Node) -> bool: return n is ClimbStart)
		if not climbs.is_empty():
			# The tile and prop collisions reach the physics server a frame late.
			await get_tree().physics_frame
			await get_tree().physics_frame
			var walked := _walk(region)
			check(walked.size() > 500, "%s: the player can walk around from the arrival spot (%d steps)" % [region_id, walked.size()])
			for climb: ClimbStart in climbs:
				seen[climb.route.id] = true
				var label := "%s: %s" % [region_id, climb.route.display_name]
				check(_can_use(climb, walked), "%s can be walked to and used, at %s" % [label, climb.position])
				if climb.route.id not in NO_WALL:
					check(_at_wall(region, climb), "%s stands at the foot of a wall" % label)
		remove_child(region)
		region.free()
	var unplaced: Array[String] = []
	for route in Guidebook.routes():
		if not seen.has(route.id):
			unplaced.append(route.id)
	check(unplaced.is_empty(), "every route in the guidebook has a sign somewhere in the park %s" % [unplaced])
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


## The player's collision box and interaction area, from the player scene.
func _read_player() -> void:
	var player: Player = load("res://scenes/player/player.tscn").instantiate()
	var collision := player.get_node("Collision") as CollisionShape2D
	var size: Vector2 = (collision.shape as RectangleShape2D).size
	body = Rect2(collision.position - size / 2.0, size)
	var area := player.get_node("InteractionArea") as Area2D
	reach = area.position.length()
	reach_size = ((area.get_node("Shape") as CollisionShape2D).shape as RectangleShape2D).size
	player.free()


## Everywhere the player's body fits that can be walked to from the region's
## arrival spot, as grid points STEP apart.
func _walk(region: Region) -> Dictionary:
	var space := region.get_world_2d().direct_space_state
	var shape := RectangleShape2D.new()
	shape.size = body.size
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = 1
	var bounds := region.get_bounds()
	var start := region.get_spawn("arrival")
	if start == null:
		start = region.get_spawn("south_entry")
	var first := Vector2i((start.global_position / STEP).round())
	var walked := {first: true}
	var queue: Array[Vector2i] = [first]
	while not queue.is_empty():
		var at: Vector2i = queue.pop_back()
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = at + step
			var pos := Vector2(next) * STEP
			if walked.has(next) or not bounds.has_point(pos):
				continue
			query.transform = Transform2D(0.0, pos + body.get_center())
			if space.intersect_shape(query, 1).is_empty():
				walked[next] = true
				queue.append(next)
	return walked


## True if the player can stand somewhere in [param walked], face the climb's
## sign, and have it in reach.
func _can_use(climb: ClimbStart, walked: Dictionary) -> bool:
	var hitbox := Rect2(climb.global_position + HITBOX.position, HITBOX.size)
	var around := Vector2i((climb.global_position / STEP).round())
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var at := around + Vector2i(dx, dy)
			if not walked.has(at):
				continue
			for facing in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				if Rect2(Vector2(at) * STEP + facing * reach - reach_size / 2.0, reach_size).intersects(hitbox):
					return true
	return false


## True if the sign's tile, or one next to it, is cliff or talus. Hand-made
## hubs paint their ground as one picture, so there the wall is whatever
## Blocker tile the sign stands against.
func _at_wall(region: Region, climb: ClimbStart) -> bool:
	var ground := region.get_ground()
	var blocker: TileMapLayer = region.get_node_or_null("Blocker")
	var cell := ground.local_to_map(ground.to_local(climb.global_position))
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var near := cell + Vector2i(dx, dy)
			if region.map:
				if ground.get_cell_atlas_coords(near).y in [Terrain.CLIFF, Terrain.TALUS]:
					return true
			elif blocker and blocker.get_cell_source_id(near) != -1:
				return true
	return false
