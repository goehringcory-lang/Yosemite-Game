extends Node
## Checks the ways in and out of every region: from the region's arrival spot
## the player can walk into every exit, walk up to and use every trail sign,
## building door, shuttle stop, map kiosk and Guardian's Year work spot, and
## reach every spot that a way into the region lands on. So no road or
## doorway ends at an edge of the map with its exit off to one side, no trail
## marker stands where you can't get to it, and no way in drops you somewhere
## you can't get out of.
## Then it fits the regions together like puzzle pieces: every region has a
## way in and a way out, and from every region you can get to every other one
## by its roads, trails and doors, the Valley shuttle, the park map's drives
## and the climbs that top out somewhere new.
## Run: godot --headless --path . res://tests/exit_access_test.tscn
## Exit code is the number of failed checks.

const REGIONS_DIR := "res://scenes/regions/"
## The walk is tried on a grid this fine, so a one-tile gap still counts.
const STEP := 8.0
## A landing spot counts as reached if the walk passes this close to it (the
## world nudges a player who lands in a bush to the nearest open ground).
const LANDING_SLACK := 16.0

## The player's body and the reach of the interact button, read from
## scenes/player/player.tscn in _ready().
var body := Rect2()
var reach_size := Vector2()
var reach := 0.0
var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	_read_player()
	var landings := _landing_spots()
	var ways := {}
	for file in DirAccess.get_files_at(REGIONS_DIR):
		if not file.ends_with(".tscn"):
			continue
		var region_id := file.get_basename()
		var region: Region = (load(REGIONS_DIR + file) as PackedScene).instantiate()
		add_child(region)
		# The building doors and the story's trail signs are added on the first visit.
		StoryContent.attach(region)
		var exits: Array = region.find_children("*", "RegionExit", true, false)
		var uses: Array = region.find_children("*", "", true, false).filter(func(n: Node) -> bool:
			return n is RegionDoor or n is ShuttleStop or n is TravelPoint or n is WorkSpot)
		ways[region_id] = _ways_out(region)
		var start := _start(region)
		check(start != null, "%s: has a spot to start from" % region_id)
		check(not exits.is_empty() or not uses.is_empty(), "%s: has a way out" % region_id)
		if start:
			# The tile and prop collisions reach the physics server a frame late.
			await get_tree().physics_frame
			await get_tree().physics_frame
			var walked := _walk(region, start)
			# A way between two parts of one region (the cables up Half Dome)
			# joins them: walk on from where it comes out.
			var joined := true
			while joined:
				joined = false
				for door: Node2D in uses:
					if door is RegionDoor and door.target_region == region_id and _can_use(door, walked):
						var there := region.get_spawn(door.target_spawn)
						if there and not _near_walked(there.global_position, walked):
							walked.merge(_walk(region, there))
							joined = true
			for exit: RegionExit in exits:
				check(_can_reach(exit, walked), "%s: %s (%s) can be walked into, at %s"
					% [region_id, exit.name, exit.label, exit.position])
			for target: Node2D in uses:
				check(_can_use(target, walked), "%s: %s (%s) can be walked up to and used, at %s"
					% [region_id, target.name, Player.prompt_for(target), target.position])
			for spot_name: String in landings.get(region_id, {}):
				var spot := region.get_spawn(spot_name)
				check(spot != null and _near_walked(spot.global_position, walked),
					"%s: the way in to %s lands where the exits can be walked to" % [region_id, spot_name])
		remove_child(region)
		region.free()
	_check_park_joins_up(ways)
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


## The regions you can get to straight from [param region]: through its exits
## and doors, by the shuttle, by a road that drives on to another hub, by
## driving from a kiosk or a road out of the hub,
## and up a climb that tops out in another hub.
func _ways_out(region: Region) -> Dictionary:
	var out := {}
	for node in region.find_children("*", "", true, false):
		if (node is RegionExit or node is RegionDoor) and node.target_region != "":
			out[node.target_region] = true
		elif node is RegionExit and node.drive_to != "":
			var hub := Park.get_hub(node.drive_to)
			out[hub.arrival_region if hub.arrival_region != "" else hub.id] = true
		elif (node is RegionExit and node.travel_to != "") or node is TravelPoint:
			for leg in Park.legs_from(region.hub_id):
				var hub := Park.get_hub(leg.to)
				out[hub.arrival_region if hub.arrival_region != "" else hub.id] = true
		elif node is ShuttleStop:
			for stop: Dictionary in node.destinations():
				out[stop.region] = true
		elif node is ClimbStart and node.route and node.route.destination() != "":
			out[node.route.destination()] = true
	return out


## Every region has a way in and a way out, and every region can be reached
## from every other (with the locked hubs open and the roads clear).
func _check_park_joins_up(ways: Dictionary) -> void:
	var ins := {}
	for from: String in ways:
		for to: String in ways[from]:
			check(ways.has(to), "%s: a way out leads to %s, which is a region" % [from, to])
			if to != from:
				ins[to] = true
	for id: String in ways:
		check(ins.has(id), "%s: has a way in from another region" % id)
		check(not (ways[id] as Dictionary).is_empty(), "%s: has a way out to another region" % id)
	var cut_off := PackedStringArray()
	for id: String in ways:
		var reached := {id: true}
		var queue: Array[String] = [id]
		while not queue.is_empty():
			var at: String = queue.pop_back()
			for next: String in ways.get(at, {}):
				if not reached.has(next):
					reached[next] = true
					queue.append(next)
		var missing := (ways.keys() as Array).filter(func(other: String) -> bool: return not reached.has(other))
		if not missing.is_empty():
			cut_off.append("%s can't reach %s" % [id, ", ".join(PackedStringArray(missing))])
	check(cut_off.is_empty(), "all %d regions join up: from each one you can get to every other (%s)"
		% [ways.size(), "; ".join(cut_off)])


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


## Every spot something lands the player on, by region: the far ends of
## roads, trails and doors, the shuttle stops, the end of a climb that tops
## out somewhere new, a drive's arrival and home.
func _landing_spots() -> Dictionary:
	var spots := {}
	var add := func(region_id: String, spot: String) -> void:
		if not spots.has(region_id):
			spots[region_id] = {}
		spots[region_id][spot] = true
	for file in DirAccess.get_files_at(REGIONS_DIR):
		if not file.ends_with(".tscn"):
			continue
		var region_id := file.get_basename()
		for path in [REGIONS_DIR + file, StoryContent.path_for(region_id), StoryContent.doors_path_for(region_id)]:
			if not ResourceLoader.exists(path):
				continue
			var scene: Node = (load(path) as PackedScene).instantiate()
			for node in scene.find_children("*", "", true, false):
				if (node is RegionExit or node is RegionDoor) and node.target_region != "":
					add.call(node.target_region, node.target_spawn)
				# a building's second door: coming back out lands beside it
				if node is BuildingDoor and node.exit_spawn != "":
					add.call(region_id, node.exit_spawn)
			scene.free()
	for stop: Dictionary in ShuttleStop.STOPS:
		add.call(stop.region, stop.spawn)
	for route in Guidebook.routes():
		if route.destination() != "":
			add.call(route.destination(), route.destination_spawn)
	for hub in ParkAtlas.HUBS:
		for leg in Park.legs_from(hub.id):
			var there := Park.get_hub(leg.to)
			add.call(there.arrival_region if there.arrival_region != "" else there.id, leg.spawn)
	add.call(Park.HOME_REGION, Park.HOME_SPAWN)
	return spots


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
	shape.size = body.size
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = 1
	var bounds := region.get_bounds()
	var walked := {}
	var queue: Array[Vector2i] = []
	# A spawn can sit a little inside a bush; the world nudges the player out
	# of it, so start from the nearest open spot.
	var first := Vector2i((start.global_position / STEP).round())
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


## True if the player's body, standing somewhere in [param walked], overlaps
## the exit's trigger.
func _can_reach(exit: RegionExit, walked: Dictionary) -> bool:
	for shape_node in exit.find_children("*", "CollisionShape2D", false, false):
		var rect: Rect2 = shape_node.global_transform * (shape_node as CollisionShape2D).shape.get_rect()
		var lo := Vector2i(((rect.position - body.end) / STEP).floor()) - Vector2i.ONE
		var hi := Vector2i(((rect.end - body.position) / STEP).ceil()) + Vector2i.ONE
		for y in range(lo.y, hi.y + 1):
			for x in range(lo.x, hi.x + 1):
				var at := Vector2i(x, y)
				if walked.has(at) and Rect2(Vector2(at) * STEP + body.position, body.size).intersects(rect):
					return true
	return false


## True if the player can stand somewhere in [param walked], face
## [param target], and have its hitbox in reach of the interact button.
func _can_use(target: Node2D, walked: Dictionary) -> bool:
	var hitboxes: Array[Rect2] = []
	for area in target.find_children("*", "Area2D", false, false):
		for shape_node in area.find_children("*", "CollisionShape2D", false, false):
			var shape := (shape_node as CollisionShape2D).shape
			if shape is RectangleShape2D:
				hitboxes.append(shape_node.global_transform * shape.get_rect())
	if hitboxes.is_empty():
		return false
	var around := Vector2i((target.global_position / STEP).round())
	var span := ceili((reach + reach_size.length() + 64.0) / STEP)
	for dy in range(-span, span + 1):
		for dx in range(-span, span + 1):
			var at := around + Vector2i(dx, dy)
			if not walked.has(at):
				continue
			for facing in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				var area := Rect2(Vector2(at) * STEP + facing * reach - reach_size / 2.0, reach_size)
				for hitbox in hitboxes:
					if area.intersects(hitbox):
						return true
	return false


## True if the walk passes within LANDING_SLACK of [param pos].
func _near_walked(pos: Vector2, walked: Dictionary) -> bool:
	var around := Vector2i((pos / STEP).round())
	var span := ceili(LANDING_SLACK / STEP)
	for dy in range(-span, span + 1):
		for dx in range(-span, span + 1):
			var at := around + Vector2i(dx, dy)
			if walked.has(at) and (Vector2(at) * STEP).distance_to(pos) <= LANDING_SLACK:
				return true
	return false
