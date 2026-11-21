extends RefCounted
## Where the player can walk in a region, for placing and checking hidden
## finds (Finds): tools/discovery/find_spots.tscn suggests spots with it and
## tests/finds_test.tscn checks every find can be walked up to and lies off
## the path. Works like tests/exit_access_test.gd's walk: the player's body
## tried on a grid STEP apart, from the region's arrival spot.

const Terrain := preload("res://scripts/world/terrain.gd")
const STEP := 8.0
## Ground the player is meant to stay on: roads, trails, paths, camps, yards.
const PATHS := [Terrain.ROAD, Terrain.PARKING, Terrain.BRIDGE, Terrain.TRAIL, Terrain.PAVED, Terrain.CAMP, Terrain.BUILT]
## The terrain tiles' source on a generated map's Ground layer.
const SOURCE_TERRAIN := 1

var body := Rect2()


func _init() -> void:
	var player: Node = load("res://scenes/player/player.tscn").instantiate()
	var collision := player.get_node("Collision") as CollisionShape2D
	var size: Vector2 = (collision.shape as RectangleShape2D).size
	body = Rect2(collision.position - size / 2.0, size)
	player.free()


## The arrival spot, or failing that the first spawn.
static func start_of(region: Region) -> Marker2D:
	for spawn_name in ["arrival", "south_entry", "door"]:
		var spawn := region.get_spawn(spawn_name)
		if spawn:
			return spawn
	for parent_path in ["Markers", "Map/Spawns", "Spawns"]:
		var parent := region.get_node_or_null(parent_path)
		if parent:
			for child in parent.get_children():
				if child is Marker2D:
					return child
	return null


## Every grid point (in STEP units) the player's body fits on that can be
## walked to from [param from]. The region must be in the tree, a couple of
## physics frames after it was added.
func walk(region: Region, from: Vector2) -> Dictionary:
	var space := region.get_world_2d().direct_space_state
	var shape := RectangleShape2D.new()
	shape.size = body.size
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = 1
	var bounds := region.get_bounds()
	var walked := {}
	var queue: Array[Vector2i] = []
	var first := Vector2i((from / STEP).round())
	for radius in range(0, 4):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var at := first + Vector2i(dx, dy)
				query.transform = Transform2D(0.0, Vector2(at) * STEP + body.get_center())
				if queue.is_empty() and space.intersect_shape(query, 1).is_empty():
					walked[at] = true
					queue.append(at)
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


## True if the walk reaches within [param slack] px of [param pos].
static func reaches(walked: Dictionary, pos: Vector2, slack := 24.0) -> bool:
	var around := Vector2i((pos / STEP).round())
	var span := ceili(slack / STEP)
	for dy in range(-span, span + 1):
		for dx in range(-span, span + 1):
			var at := around + Vector2i(dx, dy)
			if walked.has(at) and (Vector2(at) * STEP).distance_to(pos) <= slack:
				return true
	return false


## Ground cell -> how many cells it is from the nearest road, trail or path
## tile (0 on one). Maps painted by hand have no terrain tiles: every cell is
## then left out, and the caller treats a missing cell as far.
static func path_distance(ground: TileMapLayer) -> Dictionary:
	var dist := {}
	var queue: Array[Vector2i] = []
	var cells := ground.get_used_cells()
	var used := {}
	for cell in cells:
		used[cell] = true
		if ground.get_cell_source_id(cell) == SOURCE_TERRAIN and ground.get_cell_atlas_coords(cell).y in PATHS:
			dist[cell] = 0
			queue.append(cell)
	var head := 0
	while head < queue.size():
		var at := queue[head]
		head += 1
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = at + step
			if used.has(next) and not dist.has(next):
				dist[next] = int(dist[at]) + 1
				queue.append(next)
	return dist
