extends Node
## Measures how each arrival settles: goes through the park's doors, gates
## and zero-minute exits (and a few faded and mapped trips) with the player
## standing still, and logs where the view is every frame from the moment
## the new place shows. Standing still, the view should not move at all once
## the place shows; any glide or jump is a camera that arrived unsettled.
## Prints one line per arrival and a summary of the worst.
## Needs a window (doors only wipe there):
##   VK_ICD_FILENAMES=/opt/lavapipe/lvp_icd.json xvfb-run -a godot --path . res://tools/perf/arrival_probe.tscn
## ARRIVAL_ONLY=<region id> limits it to arrivals into that region;
## ARRIVAL_LIMIT=<n> to the first n.

## Frames watched after the new place shows.
const WATCH := 150


func _env(key: String, fallback: String) -> String:
	return OS.get_environment(key) if OS.get_environment(key) != "" else fallback


func _ways() -> Array:
	var ways := []
	var seen := {}
	var dir := DirAccess.open("res://scenes/regions")
	var files := Array(dir.get_files()).filter(func(f: String) -> bool: return f.ends_with(".tscn"))
	files.sort()
	for file in files:
		var from: String = file.get_basename()
		var scene: PackedScene = load("res://scenes/regions/" + file)
		var made := scene.instantiate()
		for node in made.find_children("*", "", true, false):
			var target := ""
			var spawn := ""
			if node is RegionDoor and node.minutes == 0:
				target = node.target_region
				spawn = node.target_spawn
			elif node is RegionExit and node.minutes == 0 and node.target_region != "" and node.drive_to == "" and node.travel_to == "":
				target = node.target_region
				spawn = node.target_spawn
			if target == "" or not ResourceLoader.exists("res://scenes/regions/%s.tscn" % target):
				continue
			var key := "%s:%s" % [target, spawn]
			if seen.has(key):
				continue
			seen[key] = true
			ways.append({"from": from, "to": target, "spawn": spawn})
		made.free()
	return ways


func _view(world: Node) -> Vector2:
	var camera: Camera2D = world._camera()
	return camera.get_screen_center_position()


## Goes [param way] and logs the view each frame from when the new place
## shows; returns {drift, first_step, steps}.
func _measure(world: Node, way: Dictionary, minutes: int, info: Dictionary) -> Dictionary:
	world.go_to_region(way.to, way.spawn, minutes, info)
	var views: Array[Vector2] = []
	var shown := false
	var frames := 0
	while frames < 4000:
		await get_tree().process_frame
		frames += 1
		if not shown:
			# the new place shows once World swaps it in (under a door's
			# wipe, a fade's lift, or the map's lift)
			if world.region.region_id == way.to and world.player.get_parent() == world.region.entities:
				shown = true
		if shown:
			views.append(_view(world))
			if views.size() >= WATCH and not world._busy:
				break
	var last: Vector2 = views[-1]
	var drift := 0.0
	var biggest := 0.0
	var moving := 0
	for i in views.size():
		drift = maxf(drift, views[i].distance_to(last))
		if i > 0:
			var step := views[i].distance_to(views[i - 1])
			biggest = maxf(biggest, step)
			if step > 0.01:
				moving = i
	return {"drift": drift, "step": biggest, "settled_at": moving, "frames": views.size()}


func _ready() -> void:
	SaveManager.save_path = "user://arrival_probe_save.json"
	SaveManager.delete_save()
	Settings.tips = false
	Park.open_world = true
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	for i in 10:
		await get_tree().process_frame
	Engine.time_scale = 1.0
	# one physics tick a frame, as on a 60 Hz screen keeping up (lavapipe
	# is slow enough to run several, which hides glides from the tick)
	Engine.max_physics_steps_per_frame = 1
	GameClock.minutes = 11 * 60
	var ways := _ways()
	var only := _env("ARRIVAL_ONLY", "")
	if only != "":
		ways = ways.filter(func(w: Dictionary) -> bool: return w.to == only)
	var limit := int(_env("ARRIVAL_LIMIT", "0"))
	if limit > 0:
		ways.resize(mini(limit, ways.size()))
	var worst := []
	for way in ways:
		# start from where that way is, so seams and limits are as in play
		Settings.journeys = false
		world.journeys = false
		await world.go_to_region(way.from, "arrival")
		for i in 30:
			await get_tree().process_frame
		GameClock.minutes = 11 * 60
		var got := await _measure(world, way, 0, {})
		print("ARRIVAL door %s -> %s:%s drift=%.1f step=%.1f settled_at=%d" % [way.from, way.to, way.spawn, got.drift, got.step, got.settled_at])
		worst.append([got.drift, "door %s -> %s:%s" % [way.from, way.to, way.spawn]])
	# a faded trip and a mapped one
	for mapped in [false, true]:
		Settings.journeys = mapped
		world.journeys = mapped
		world.journeys_headless = mapped
		for way in [{"from": "crane_flat", "to": "tenaya_lake", "spawn": "west"}, {"from": "happy_isles", "to": "glacier_point", "spawn": "arrival"}, {"from": "yosemite_village", "to": "curry_village", "spawn": "arrival"}]:
			Settings.journeys = false
			world.journeys = false
			await world.go_to_region(way.from, "arrival")
			Settings.journeys = mapped
			world.journeys = mapped
			for i in 30:
				await get_tree().process_frame
			GameClock.minutes = 9 * 60
			var got := await _measure(world, way, 30, {"title": "Probe"})
			var kind := "map" if mapped else "fade"
			print("ARRIVAL %s %s -> %s:%s drift=%.1f step=%.1f settled_at=%d" % [kind, way.from, way.to, way.spawn, got.drift, got.step, got.settled_at])
			worst.append([got.drift, "%s %s -> %s:%s" % [kind, way.from, way.to, way.spawn]])
	worst.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var moved := worst.filter(func(w: Array) -> bool: return w[0] > 0.5)
	print("ARRIVAL SUMMARY %d arrivals, %d moved after showing" % [worst.size(), moved.size()])
	for w in moved.slice(0, 25):
		print("  %.1f px  %s" % [w[0], w[1]])
	SaveManager.delete_save()
	get_tree().quit()
