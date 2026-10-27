extends Node
## Checks the ways out of every region: the player can walk from the region's
## arrival spot into every exit, so no road or doorway ends at an edge of the
## map with its exit off to one side.
## Run: godot --headless --path . res://tests/exit_access_test.tscn
## Exit code is the number of failed checks.

const REGIONS_DIR := "res://scenes/regions/"
## The walk is tried on a grid this fine, so a one-tile gap still counts.
const STEP := 8.0
## The player's body (scenes/player/player.tscn).
const BODY := Rect2(-5, -6, 10, 6)

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	for file in DirAccess.get_files_at(REGIONS_DIR):
		if not file.ends_with(".tscn"):
			continue
		var region_id := file.get_basename()
		var region: Region = (load(REGIONS_DIR + file) as PackedScene).instantiate()
		add_child(region)
		var exits: Array = region.find_children("*", "RegionExit", true, false)
		var start := _start(region)
		if start and not exits.is_empty():
			# The tile and prop collisions reach the physics server a frame late.
			await get_tree().physics_frame
			await get_tree().physics_frame
			var walked := _walk(region, start)
			for exit: RegionExit in exits:
				check(_can_reach(exit, walked), "%s: %s (%s) can be walked into, at %s"
					% [region_id, exit.name, exit.label, exit.position])
		remove_child(region)
		region.free()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


## Where the walk starts: the arrival spot, or failing that the first spawn.
func _start(region: Region) -> Marker2D:
	for spawn_name in ["arrival", "south_entry", "door"]:
		var spawn := region.get_spawn(spawn_name)
		if spawn:
			return spawn
	var markers := region.get_node_or_null("Markers")
	if markers:
		for child in markers.get_children():
			if child is Marker2D:
				return child
	return null


## Everywhere the player's body fits that can be walked to from [param start],
## as grid points STEP apart.
func _walk(region: Region, start: Marker2D) -> Dictionary:
	var space := region.get_world_2d().direct_space_state
	var shape := RectangleShape2D.new()
	shape.size = BODY.size
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = 1
	var bounds := region.get_bounds()
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
			query.transform = Transform2D(0.0, pos + BODY.get_center())
			if space.intersect_shape(query, 1).is_empty():
				walked[next] = true
				queue.append(next)
	return walked


## True if the player's body, standing somewhere in [param walked], overlaps
## the exit's trigger.
func _can_reach(exit: RegionExit, walked: Dictionary) -> bool:
	for shape_node in exit.find_children("*", "CollisionShape2D", false, false):
		var rect: Rect2 = shape_node.global_transform * (shape_node as CollisionShape2D).shape.get_rect()
		var lo := Vector2i(((rect.position - BODY.end) / STEP).floor()) - Vector2i.ONE
		var hi := Vector2i(((rect.end - BODY.position) / STEP).ceil()) + Vector2i.ONE
		for y in range(lo.y, hi.y + 1):
			for x in range(lo.x, hi.x + 1):
				var at := Vector2i(x, y)
				if walked.has(at) and Rect2(Vector2(at) * STEP + BODY.position, BODY.size).intersects(rect):
					return true
	return false
