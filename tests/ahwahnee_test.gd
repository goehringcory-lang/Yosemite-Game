extends Node
## Checks the walk from the Lamon Homestead to the Ahwahnee: the homestead's
## north gate, the Stoneman Meadow trail (forest, meadow, the Merced, Stoneman
## Bridge) and the hotel grounds. Every spot is reachable on foot, the bridge
## can be walked (and its parapets and the river keep you on it), the hotel
## opens into its lobby, and the cascade and night glow are in place.
## Run: godot --headless --path . res://tests/ahwahnee_test.tscn
## Exit code is the number of failed checks.

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	SaveManager.save_path = "user://ahwahnee_test_save.json"
	SaveManager.delete_save()
	Engine.time_scale = 8.0
	GameClock.seconds_per_tick = 1000000.0 # the walk must not run into the 2 AM curfew
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	world.player.can_act = true

	# The homestead's north gate.
	var home: Region = world.region
	check(home.region_id == "lamon_homestead", "a new game starts at the homestead")
	var north: RegionExit = home.get_node_or_null("Exits/NorthToAhwahnee")
	check(north != null and north.target_region == "ahwahnee_trail" and north.target_spawn == "south_entry", "the homestead has a north gate to the Stoneman Meadow trail")
	check(home.get_spawn("north_gate") != null, "the homestead has a north_gate spot to return to")
	check(home.get_node_or_null("Exits/ToCurryVillage") != null, "the way west to Curry Village is untouched")
	var gate_tile := Vector2i(north.position / 32.0)
	check(home.get_ground().get_cell_source_id(gate_tile) != -1, "the gate opening has ground under it")
	world.player.global_position = north.global_position + Vector2(0, 30)
	Input.action_press("move_up")
	for i in 90:
		await get_tree().physics_frame
	Input.action_release("move_up")
	await get_tree().create_timer(2.0).timeout
	check(world.region.region_id == "ahwahnee_trail", "walking through the north gate leads onto the trail (now in %s)" % world.region.region_id)

	# The trail.
	var trail: Region = world.region
	check(trail.display_name == "Stoneman Meadow" and trail.hub_id == "yosemite_valley", "the trail is Stoneman Meadow, part of the Valley")
	check(trail.get_node_or_null("GroundArt") != null, "the trail has its painted ground")
	for spawn_name in ["south_entry", "north_entry", "bridge_west", "bridge_east", "meadow", "river_bank"]:
		check(trail.get_spawn(spawn_name) != null, "the trail has a %s spot" % spawn_name)
	var open := _walkable_cells(trail)
	# The deck's 16 px lane is finer than the tile grid this check works on.
	for c in trail.get_ground().get_used_cells():
		if trail.get_ground().get_cell_source_id(c) == 1 and trail.get_ground().get_cell_atlas_coords(c).y == 18:
			open[c] = true
	var reached := _flood(open, Vector2i(trail.get_spawn("south_entry").position / 32.0))
	for spawn_name in ["north_entry", "bridge_west", "bridge_east", "meadow", "river_bank"]:
		check(reached.has(Vector2i(trail.get_spawn(spawn_name).position / 32.0)), "%s is reachable on foot from the trail's south end" % spawn_name)
	var north_exit: RegionExit = trail.get_node("Exits/ToAhwahnee")
	check(reached.has(Vector2i(north_exit.position / 32.0) + Vector2i(0, 2)), "the trail's north exit is reachable on foot")
	var west_end := Vector2i(trail.get_spawn("bridge_west").position / 32.0)
	check(not reached.has(Vector2i(west_end.x + 4, west_end.y - 3)), "you can't wade into the river north of the bridge")

	# Walk the whole trail for real, from the south end to the bridge.
	world.player.global_position = trail.get_spawn("south_entry").global_position
	await get_tree().physics_frame
	var west_trail := [Vector2(13, 76), Vector2(16, 70), Vector2(21, 64), Vector2(24, 58), Vector2(25, 51), Vector2(23, 45), Vector2(23, 39), Vector2(26, 34.5)]
	var walked_trail := true
	for wp: Vector2 in west_trail:
		walked_trail = walked_trail and await _walk_to(world.player, wp * 32.0 + Vector2(16, 16))
	walked_trail = walked_trail and await _walk_to(world.player, trail.get_spawn("bridge_west").global_position)
	check(walked_trail, "the player can walk the trail from the south end up through the meadow to the bridge (ended at %s)" % world.player.global_position)

	# Walk the bridge for real: physics, parapets, and all.
	world.player.global_position = trail.get_spawn("bridge_west").global_position
	await get_tree().physics_frame
	var ok := await _walk_to(world.player, trail.get_spawn("bridge_east").global_position)
	check(ok, "the player can walk across Stoneman Bridge (ended at %s)" % world.player.global_position)
	var deck_y: float = trail.get_spawn("bridge_east").global_position.y
	Input.action_press("move_up")
	for i in 40:
		await get_tree().physics_frame
	Input.action_release("move_up")
	check(world.player.global_position.y > deck_y - 30.0, "the north parapet stops you from walking off the bridge (y %.0f, deck %.0f)" % [world.player.global_position.y, deck_y])
	world.player.global_position = trail.get_spawn("bridge_west").global_position + Vector2(96, 0)
	await get_tree().physics_frame
	Input.action_press("move_down")
	for i in 60:
		await get_tree().physics_frame
	Input.action_release("move_down")
	check(world.player.global_position.y < deck_y + 30.0, "the south parapet keeps you out of the arches (y %.0f, deck %.0f)" % [world.player.global_position.y, deck_y])

	var east_trail := [Vector2(59, 27), Vector2(59, 20), Vector2(62, 13), Vector2(62, 6)]
	world.player.global_position = trail.get_spawn("bridge_east").global_position
	await get_tree().physics_frame
	var walked_north := true
	for wp: Vector2 in east_trail:
		walked_north = walked_north and await _walk_to(world.player, wp * 32.0 + Vector2(16, 16))
	check(walked_north, "the player can walk the far bank's trail north from the bridge (ended at %s)" % world.player.global_position)

	# Off the trail's north end and into the grounds.
	world.player.global_position = north_exit.global_position + Vector2(0, 48)
	Input.action_press("move_up")
	for i in 60:
		await get_tree().physics_frame
	Input.action_release("move_up")
	await get_tree().create_timer(2.0).timeout
	check(world.region.region_id == "the_ahwahnee", "the trail's north end leads to the Ahwahnee (now in %s)" % world.region.region_id)

	# The grounds.
	var grounds: Region = world.region
	check(grounds.display_name == "The Ahwahnee", "the region is The Ahwahnee")
	for spawn_name in ["south_entry", "west_road", "front_door", "entrance_circle", "rose_garden", "tea_lawn", "ahwahnee_meadow", "cascade"]:
		check(grounds.get_spawn(spawn_name) != null, "the grounds have a %s spot" % spawn_name)
	check(grounds.find_child("Ahwahnee", true, false) != null, "the hotel is there")
	check(grounds.get_node_or_null("RoyalArchesWall") != null, "the Royal Arches stand behind it")
	var cascade: AnimatedSprite2D = grounds.get_node_or_null("RoyalArchCascade")
	check(cascade != null and cascade.sprite_frames.get_frame_count("default") >= 4 and cascade.is_playing(), "the Royal Arch Cascade is animated")
	check(grounds.get_node_or_null("HotelGlow") != null, "the hotel has its evening glow")
	open = _walkable_cells(grounds)
	reached = _flood(open, Vector2i(grounds.get_spawn("south_entry").position / 32.0))
	for spawn_name in ["west_road", "front_door", "entrance_circle", "rose_garden", "tea_lawn", "ahwahnee_meadow", "cascade"]:
		check(reached.has(Vector2i(grounds.get_spawn(spawn_name).position / 32.0)), "%s is reachable on foot from the trail" % spawn_name)
	var to_bridge: RegionExit = grounds.get_node("Exits/ToStonemanBridge")
	check(to_bridge.target_region == "ahwahnee_trail" and to_bridge.target_spawn == "north_entry", "the drive's foot leads back to the bridge")
	var west_exit: RegionExit = grounds.get_node("Exits/NorthsideDriveWest")
	check(west_exit.target_region == "ahwahnee_meadow" and west_exit.target_spawn == "east", "the west road leads across Ahwahnee Meadow")

	# The front doors tell the hotel's story and open into the lobby; the
	# walls around them are solid.
	var door: InfoSign = grounds.find_child("MainEntrance", true, false)
	check(door != null and door.title == "The Ahwahnee" and door.text.contains("1927"), "the main entrance has the hotel's story")
	var front: BuildingDoor = grounds.find_child("DoorToAhwahneeLobby", true, false)
	check(front != null and front.target_region == "ahwahnee_lobby" and grounds.get_spawn("ahwahnee_lobby_door") != null,
		"the front doors lead into the lobby")
	world.player.global_position = grounds.get_spawn("front_door").global_position
	await get_tree().physics_frame
	var start_y: float = world.player.global_position.y
	Input.action_press("move_up")
	for i in 120:
		await get_tree().physics_frame
	Input.action_release("move_up")
	check(world.player.global_position.y > 34 * 32, "the hotel's front wall stops you (feet at y %.0f, wall base %d)" % [world.player.global_position.y, 34 * 32])
	# Around the hotel's back: the cliff stops you too.
	world.player.global_position = Vector2(grounds.get_spawn("front_door").global_position.x, 15 * 32 + 16)
	await get_tree().physics_frame
	Input.action_press("move_up")
	for i in 90:
		await get_tree().physics_frame
	Input.action_release("move_up")
	check(world.player.global_position.y > 12 * 32, "the foot of the cliff stops you (y %.0f)" % world.player.global_position.y)

	# Back through the west road and the bridge.
	world.player.global_position = grounds.get_spawn("south_entry").global_position
	await get_tree().physics_frame
	var door_spot: Vector2 = grounds.get_spawn("front_door").global_position + Vector2(0, 40)
	var around_circle := [Vector2(door_spot.x, 50 * 32), Vector2(door_spot.x + 11 * 32, 46 * 32), Vector2(door_spot.x + 11 * 32, 39 * 32), door_spot]
	var walked := true
	for wp: Vector2 in around_circle:
		walked = walked and await _walk_to(world.player, wp)
	check(walked, "the player can walk from the gate around the fountain to the front door (ended at %s)" % world.player.global_position)

	world.free()
	SaveManager.delete_save()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


## Holds the movement keys toward [param target] until the player is within
## a few pixels or gives up.
func _walk_to(player: Player, target: Vector2, max_frames := 1500) -> bool:
	for i in max_frames:
		var d := target - player.global_position
		if d.length() < 10.0:
			break
		Input.action_release("move_left")
		Input.action_release("move_right")
		Input.action_release("move_up")
		Input.action_release("move_down")
		if d.x < -6.0:
			Input.action_press("move_left")
		elif d.x > 6.0:
			Input.action_press("move_right")
		if d.y < -6.0:
			Input.action_press("move_up")
		elif d.y > 6.0:
			Input.action_press("move_down")
		await get_tree().physics_frame
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)
	return (target - player.global_position).length() < 16.0


func _walkable_cells(region: Region) -> Dictionary:
	var ground := region.get_ground()
	var blocker: TileMapLayer = region.get_node("Blocker")
	var solid := [8, 9, 10, 11, 12, 14] # cliff, talus, scree, river, lake, falls
	var open := {}
	for c in ground.get_used_cells():
		if blocker.get_cell_source_id(c) == -1 and not (ground.get_cell_source_id(c) == 1 and ground.get_cell_atlas_coords(c).y in solid):
			open[c] = true
	for body in region.find_children("*", "StaticBody2D", true, false):
		if body is ShuttleStop or body is Vendor:
			continue
		for shape_node in body.get_children():
			var shape := shape_node as CollisionShape2D
			if shape and shape.shape is RectangleShape2D and not shape.disabled:
				var center: Vector2 = (body as Node2D).global_position + shape.position
				var rect := Rect2(center - shape.shape.size / 2.0, shape.shape.size)
				for y in range(floori(rect.position.y / 32.0), floori(rect.end.y / 32.0) + 1):
					for x in range(floori(rect.position.x / 32.0), floori(rect.end.x / 32.0) + 1):
						if rect.grow(-minf(6.0, minf(rect.size.x, rect.size.y) / 3.0)).intersects(Rect2(x * 32, y * 32, 32, 32)):
							open.erase(Vector2i(x, y))
	return open


func _flood(open: Dictionary, start: Vector2i) -> Dictionary:
	var reached := {start: true}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if open.has(c + d) and not reached.has(c + d):
				reached[c + d] = true
				queue.append(c + d)
	return reached
