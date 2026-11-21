extends Node
## Checks that arriving somewhere lands settled: through a door, after a
## faded trip, waking up and loading a save, the view is already where it
## stays on the first frame (no slide from the place left behind, no glide
## of the drawn player across the gap), and through a door the player faces
## on into the new place, away from the way back.
## Run: godot --headless --path . res://tests/arrival_test.tscn
## Exit code is the number of failed checks.

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


## Watches the view for [param frames] frames, the player standing still:
## how far it moved from where it was on the first one, and whether the
## camera stayed on the drawn player.
func _watch(world: Node, frames := 40) -> Dictionary:
	var camera: Camera2D = world._camera()
	var first := camera.get_screen_center_position()
	var drift := 0.0
	var glided := camera.position.length()
	for i in frames:
		await get_tree().process_frame
		drift = maxf(drift, camera.get_screen_center_position().distance_to(first))
		glided = maxf(glided, camera.position.length())
	return {"drift": drift, "glided": glided}


func _ready() -> void:
	SaveManager.save_path = "user://arrival_test_save.json"
	SaveManager.delete_save()
	Settings.tips = false
	Park.open_world = true
	Engine.time_scale = 1.0
	# One physics tick a frame, as on a screen keeping up at 60 Hz: then a
	# tick lands between the swap and the next frame, which is what glided
	# the drawn player (and the camera on it) from the old place.
	Engine.max_physics_steps_per_frame = 1
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	for i in 5:
		await get_tree().process_frame
	GameClock.minutes = 11 * 60
	var camera: Camera2D = world._camera()

	# Doors between rooms far apart on their maps.
	for way in [["ahwahnee_lobby", "arrival", "ahwahnee_dining_room", "from_lobby"],
			["ahwahnee_great_lounge", "arrival", "ahwahnee_solarium", "door"],
			["yosemite_village", "arrival", "curry_village", "arrival"]]:
		await world.go_to_region(way[0], way[1])
		for i in 10:
			await get_tree().process_frame
		await world.go_to_region(way[2], way[3])
		var got := await _watch(world)
		check(got.drift < 1.0, "into %s the view doesn't move after arriving (%.1f px)" % [way[2], got.drift])
		check(got.glided < 1.0, "...and the drawn player doesn't glide in from the room left (%.1f px)" % got.glided)

	# A swap just before a physics tick (a door walked into on the tick, a
	# frame on a real screen): the tick must not glide the player across.
	await world.go_to_region("ahwahnee_lobby", "arrival")
	for i in 10:
		await get_tree().process_frame
	await get_tree().physics_frame
	world._enter_region("ahwahnee_dining_room", "from_lobby")
	var ticked := await _watch(world)
	check(ticked.drift < 1.0 and ticked.glided < 1.0, "swapped just before a tick, the view stays put (%.1f px, glide %.1f px)" % [ticked.drift, ticked.glided])

	# Through the dining room door from the lobby, facing on into the room.
	await world.go_to_region("ahwahnee_lobby", "arrival")
	world.player.facing = Vector2i.UP
	await world.go_to_region("ahwahnee_dining_room", "from_lobby")
	var back: Node2D = null
	for node in world.region.find_children("*", "", true, false):
		if (node is RegionDoor or node is RegionExit) and node.target_region == "ahwahnee_lobby":
			if back == null or node.global_position.distance_to(world.player.global_position) < back.global_position.distance_to(world.player.global_position):
				back = node
	if back:
		var away: Vector2 = world.player.global_position - back.global_position
		check(Vector2(world.player.facing).dot(away) > 0.0, "through a door the player faces away from the way back (facing %s)" % world.player.facing)

	# A trip that fades.
	world.journeys = false
	await world.go_to_region("happy_isles", "arrival")
	for i in 10:
		await get_tree().process_frame
	world.go_to_region("glacier_point", "arrival", 30)
	while world.region.region_id != "glacier_point":
		await get_tree().process_frame
	var faded := await _watch(world, 90)
	check(faded.drift < 1.0, "after a faded trip the view doesn't slide in as it lifts (%.1f px)" % faded.drift)
	while world._busy:
		await get_tree().process_frame

	# Waking up at home from somewhere else.
	await world.go_to_region("glacier_point", "arrival")
	world.sleep()
	while world.region.region_id != Park.HOME_REGION:
		await get_tree().process_frame
	var woke := await _watch(world, 30)
	check(woke.drift < 1.0, "waking up at home the view is already there (%.1f px)" % woke.drift)
	while world._busy:
		await get_tree().process_frame

	# Loading a save made far from the spawn it falls back to.
	await world.go_to_region("curry_village", "arrival")
	world.player.global_position += Vector2(600, 0)
	await world._unstick_player()
	for i in 10:
		await get_tree().process_frame
	var saved_at: Vector2 = world.player.global_position
	SaveManager.save_game()
	world.queue_free()
	await get_tree().process_frame
	world = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	camera = world._camera()
	check(world.player.global_position.distance_to(saved_at) < 1.0, "the save puts the player back where they were")
	var loaded := await _watch(world, 30)
	check(loaded.drift < 1.0, "loading a save the view starts out there, not at the spawn (%.1f px)" % loaded.drift)

	SaveManager.delete_save()
	get_tree().quit(failures)
