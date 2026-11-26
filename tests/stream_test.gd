extends Node
## Checks WorldStream, the open world's streaming face (docs/STREAMING.md):
## every walking exit on a map edge really meets the next area edge to edge
## (so new areas self-check), which areas are laid out and the signals as
## they come and go, positions across a seam, and the corridor clock (an
## area's walk_minutes pass as the player gets further along it, once).
## Run: godot --headless --path . res://tests/stream_test.tscn
## Exit code is the number of failed checks.

## Edge exits that cut on purpose rather than walk over: El Capitan Bridge
## crosses the river to a spot well inside Bridalveil Fall's map (see
## transitions_test ONE_WAY). Add one here only with a reason.
const CUTS := {"el_capitan_meadow": ["ToElCapBridge"]}

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	SaveManager.save_path = "user://stream_test_save.json"
	SaveManager.delete_save()
	_check_links()
	_check_corridor_specs()
	Engine.time_scale = 4.0
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	await _check_streaming(world)
	await _check_corridor(world)
	SaveManager.delete_save()
	get_tree().quit(failures)


func _check_links() -> void:
	var report := WorldStream.check_links()
	check(report.size() > 30, "found the areas' edge exits (%d)" % report.size())
	var bad := 0
	for entry in report:
		if not entry.ok and not entry.exit in CUTS.get(entry.region, []):
			bad += 1
			check(false, "%s: %s -> %s meets edge to edge (%s)" % [entry.region, entry.exit, entry.target, entry.why])
	check(bad == 0, "every walking exit on a map edge is a seam")


func _check_streaming(world: Node) -> void:
	var stream: WorldStream = world.stream
	var came: Array[String] = []
	var went: Array[String] = []
	stream.region_streamed_in.connect(func(r: Region) -> void: came.append(r.region_id))
	stream.region_streamed_out.connect(func(r: Region) -> void: went.append(r.region_id))
	await world.go_to_region("yosemite_village", "west_road")
	for i in 30:
		await get_tree().process_frame
	var laid := stream.loaded_regions().map(func(r: Region) -> String: return r.region_id)
	check(laid.size() == 2 and laid[0] == "yosemite_village" and "leidig_meadow" in laid,
			"beside the west edge, the Village and Leidig Meadow are laid out (%s)" % [laid])
	check("yosemite_village" in came and "leidig_meadow" in came, "and both were streamed in (%s)" % [came])
	var leidig: Region = world.seam.neighbor
	var spot := Vector2(100, 200)
	check(stream.to_current(leidig, spot).is_equal_approx(world.seam.offset + spot),
			"a spot in Leidig Meadow, in the Village's coordinates, is past the seam")
	check(stream.region_at(world.seam.offset + spot) == leidig, "and region_at finds it there")
	check(stream.to_current(world.region, spot) == spot, "the Village is at the origin")
	check(stream.player_lonlat() != Vector2.ZERO, "the player has a place on the park map")
	came.clear()
	went.clear()
	Input.action_press("move_left")
	for i in 900:
		if world.region.region_id == "leidig_meadow":
			break
		await get_tree().process_frame
	Input.action_release("move_left")
	await get_tree().process_frame
	check(world.region.region_id == "leidig_meadow", "walked over into Leidig Meadow")
	check(went.is_empty() and came.is_empty(), "crossing streams nothing in or out: both stay laid out (%s / %s)" % [came, went])
	check(stream.loaded_regions()[0] == world.region, "the area the player is in comes first")
	check(stream.to_current(world.region, spot) == spot, "and is at the origin now")
	# Walking away from the edge takes the Village away.
	world.player.global_position = world.region.to_global(world.region.get_bounds().get_center())
	for i in 30:
		await get_tree().process_frame
	check("yosemite_village" in went and not stream.is_streamed(world._regions["yosemite_village"]),
			"walking off, the Village is streamed out (%s)" % [went])
	# Indoors only the room is laid out.
	await world.go_to_region("welcome_center", "door")
	for i in 60:
		await get_tree().process_frame
	check(stream.loaded_regions().size() == 1 and stream.loaded_regions()[0].region_id == "welcome_center",
			"in a building only the room is laid out")


func _check_corridor(world: Node) -> void:
	var stream: WorldStream = world.stream
	await world.go_to_region("leidig_meadow", "arrival")
	for i in 30:
		await get_tree().process_frame
	var r: Region = world.region
	r.walk_minutes = 60
	stream._on_region_changed(r)
	var bounds := r.get_bounds()
	var wide := bounds.size.x >= bounds.size.y
	var length := maxf(bounds.size.x, bounds.size.y)
	var start := r.to_local(world.player.global_position)
	var axis := Vector2.RIGHT if wide else Vector2.DOWN
	var middle := bounds.get_center()
	var at_start := start * axis + middle * (Vector2.ONE - axis)
	var toward := 1.0 if start.dot(axis) < middle.dot(axis) else -1.0
	var clock: int = GameClock.minutes
	world.player.global_position = r.to_global(at_start)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var base := stream.corridor_minutes_paid()
	world.player.global_position = r.to_global(at_start + axis * toward * length * 0.5)
	for i in 3:
		await get_tree().physics_frame
	var paid := stream.corridor_minutes_paid() - base
	check(paid >= 28.0 and paid <= 31.0, "half way along a 60 minute corridor, about 30 minutes passed (%s)" % paid)
	check(GameClock.minutes - clock >= 28, "and the clock moved on by them (%d)" % (GameClock.minutes - clock))
	world.player.global_position = r.to_global(at_start)
	for i in 3:
		await get_tree().physics_frame
	check(is_equal_approx(stream.corridor_minutes_paid() - base, paid), "walking back over the same ground costs nothing more")
	r.walk_minutes = 0


## The corridor builder's spec check (tools/hubs/build_corridor.gd), which
## the area threads lean on before building.
func _check_corridor_specs() -> void:
	var builder = load("res://tools/hubs/build_corridor.gd")
	var good := {"id": "test_corridor", "name": "Test Trail", "hub": "glacier_point", "geo": [-119.6, 37.7],
		"size": [64, 36], "walk_minutes": 30, "ground": "fir",
		"ends": [{"side": "west", "at": 18, "target_region": "taft_point", "target_spawn": "east"},
			{"side": "east", "at": 20, "target_region": "glacier_point", "target_spawn": "west"}]}
	check(builder.check_spec(good).is_empty(), "a corridor spec with two ends checks out (%s)" % [builder.check_spec(good)])
	var bad := good.duplicate(true)
	bad.ends[1].side = "up"
	bad.ends[0].at = 1
	bad.erase("walk_minutes")
	check(builder.check_spec(bad).size() == 1, "a spec missing walk_minutes is turned away")
	bad.walk_minutes = 10
	check(builder.check_spec(bad).size() == 2, "and so are a bad side and an end in the corner (%s)" % [builder.check_spec(bad)])
