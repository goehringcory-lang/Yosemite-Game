extends Node
## Checks the people who keep a timetable (NPC.timetable) and the towns
## they walk through: each town is dressed with its clutter, the walk grid
## routes round buildings (and the clutter), every stop in each town is reachable from every
## other, and a visitor walks to each stop when its time comes, walks home
## at night and goes in, and comes back out of home in the morning.
## Run: godot --headless --path . res://tests/timetable_test.tscn
## Exit code is the number of failed checks.

const TOWNS := ["curry_village", "yosemite_village"]

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	SaveManager.save_path = "user://timetable_test_save.json"
	SaveManager.delete_save()
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	GameClock.paused = true
	for town: String in TOWNS:
		GameClock.minutes = 9 * 60 + 15
		await world.go_to_region(town, "arrival")
		for i in 3:
			await get_tree().physics_frame
		await test_town(world)
	SaveManager.delete_save()
	print("OK: %d failure(s)" % failures if failures == 0 else "FAILED: %d failure(s)" % failures)
	get_tree().quit(failures)


func _keepers(region: Region) -> Array[NPC]:
	var out: Array[NPC] = []
	for node in region.find_children("*", "NPC", true, false):
		if not (node as NPC).timetable.is_empty():
			out.append(node)
	return out


func test_town(world: Node) -> void:
	var region: Region = world.region
	var town := region.region_id
	var start := Time.get_ticks_msec()
	var grid := WalkGrid.of(region)
	print("      walk grid for %s built in %d ms" % [town, Time.get_ticks_msec() - start])
	var dressing := region.get_node_or_null("Entities/Dressing")
	check(dressing != null and dressing.get_child_count() >= 15, "%s is dressed with the town clutter (%d pieces)" % [town, dressing.get_child_count() if dressing else 0])
	var keepers := _keepers(region)
	check(keepers.size() >= 4, "%s has people keeping a timetable (%d)" % [town, keepers.size()])
	# Every stop anyone keeps is reachable from every other.
	var spots := {}
	for npc in keepers:
		for stop: Array in NPC.parse_timetable(npc.timetable):
			check(region.get_spawn(stop[1]) != null, "%s: %s's stop '%s' is a spot" % [town, npc.name, stop[1]])
			spots[stop[1]] = true
	var bad := []
	for a: String in spots:
		for b: String in spots:
			if a >= b or region.get_spawn(a) == null or region.get_spawn(b) == null:
				continue
			var to := region.get_spawn(b).global_position
			var path := grid.route(grid.nearest_open(region.get_spawn(a).global_position), to)
			if path.is_empty() or path[path.size() - 1].distance_to(to) > 64.0:
				bad.append("%s-%s" % [a, b])
			else:
				for p in path:
					if not grid.is_open(p):
						bad.append("%s-%s (through a wall)" % [a, b])
						break
	check(bad.is_empty(), "%s: every stop can be walked to from every other %s" % [town, bad])
	# One person's day, sped up.
	var npc: NPC = keepers[0]
	var stops := NPC.parse_timetable(npc.timetable)
	npc.travel_speed = 480.0
	for i in range(1, mini(stops.size(), 4)):
		GameClock.minutes = stops[i][0] + 5
		var spot: Vector2 = region.get_spawn(stops[i][1]).global_position
		npc._routine_check = 0.0
		npc._process(0.016)
		check(npc.is_travelling() or npc.global_position.distance_to(spot) < 64.0, "%s: %s sets off for %s at its hour" % [town, npc.name, stops[i][1]])
		await _until(func() -> bool: return not npc.is_travelling(), 20.0)
		check(npc.global_position.distance_to(spot) < 64.0, "%s: %s gets to %s (%d px away)" % [town, npc.name, stops[i][1], npc.global_position.distance_to(spot)])
	# Home at night: they walk there, then go in.
	GameClock.minutes = 23 * 60
	npc._routine_check = 0.0
	npc._process(0.016)
	var home: Vector2 = region.get_spawn(stops[0][1]).global_position
	await _until(func() -> bool: return not npc.visible, 20.0)
	check(not npc.visible and npc.global_position.distance_to(home) < 64.0, "%s: %s walks home and goes in at night" % [town, npc.name])
	# Out again in the morning, from home.
	GameClock.minutes = stops[0][0] + 10
	npc._routine_check = 0.0
	npc._process(0.016)
	await get_tree().create_timer(1.0).timeout
	var rainy: bool = Weather.today().rain > 0.4
	check(rainy or (npc.visible and npc.global_position.distance_to(home) < 64.0), "%s: %s comes out of home in the morning" % [town, npc.name])
	npc.travel_speed = NPC.TRAVEL_SPEED


func _until(done: Callable, seconds: float) -> void:
	var left := seconds
	while left > 0.0 and not done.call():
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()
