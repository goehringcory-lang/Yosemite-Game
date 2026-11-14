extends Node
## Screenshots of the Valley as one open place: walking over Leidig Meadow
## into El Capitan Meadow well away from Northside Drive (the whole shared
## edge is open now, not just the road), and the signposts at the screen's
## edge pointing to the landmarks and to places not yet found (Wayfinding).
## Needs a window (not --headless):
##   SHOT_DIR=/tmp/shots xvfb-run -a godot --path . res://tools/shots/open_world_shot.tscn


func _env(key: String, fallback: String) -> String:
	return OS.get_environment(key) if OS.get_environment(key) != "" else fallback


func _snap(dir: String, shot_name: String, frames := 30) -> void:
	for i in frames:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/open_world_%s.png" % [dir, shot_name])


## Goes to [param id] at [param spawn] at noon on a summer day, the clock
## stopped, then puts the player at [param at] (pixels in the region).
func _go(world: Node, id: String, spawn: String, at := Vector2.INF) -> void:
	GameClock.season = GameClock.Season.SUMMER
	GameClock.day = 3
	GameClock.minutes = 12 * 60
	await world.go_to_region(id, spawn)
	GameClock.paused = true
	GameClock.minutes = 12 * 60
	GameClock._elapsed = 0.0
	GameClock.time_changed.emit(GameClock.hour, GameClock.minute)
	if at != Vector2.INF:
		world.player.global_position = world.region.to_global(at)
		(world.player.get_node("Camera") as Camera2D).reset_smoothing()
	for i in 30:
		await get_tree().physics_frame


## Walks [param action] until the player is in another region (or for
## [param frames] ticks), then [param more] ticks on.
func _walk(world: Node, action: String, frames: int, more := 0) -> void:
	var from: String = world.region.region_id
	Input.action_press(action)
	for i in frames:
		await get_tree().physics_frame
		if world.region.region_id != from:
			break
	for i in more:
		await get_tree().physics_frame
	Input.action_release(action)


func _ready() -> void:
	SaveManager.save_path = "user://open_world_shot_save.json"
	SaveManager.delete_save()
	Settings.tips = false
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var dir := _env("SHOT_DIR", "user://")
	Engine.time_scale = 1.0

	# Over the grass from Leidig Meadow into El Capitan Meadow, 500 px south
	# of the road, by the river: before the edge, and over it.
	await _go(world, "leidig_meadow", "arrival", Vector2(330, 992))
	while not world._region_ready("el_capitan_meadow"):
		await get_tree().process_frame
	await _walk(world, "move_left", 60)
	await _snap(dir, "meadow_edge", 10)
	await _walk(world, "move_left", 900, 25)
	await _snap(dir, "meadow_across", 10)
	print("crossed into ", world.region.region_id, " at ", world.region.to_local(world.player.global_position), " seam ", world.seam.neighbor.region_id if world.seam else "none", " ", world.seam.span if world.seam else Vector2.ZERO)

	# The signposts: from Yosemite Village and from El Capitan Meadow.
	Settings.wayfinding = true
	await _go(world, "yosemite_village", "arrival")
	await _snap(dir, "signs_village", 300)
	await _go(world, "el_capitan_meadow", "arrival")
	await _snap(dir, "signs_el_capitan", 300)
	await _go(world, "curry_village", "arrival")
	await _snap(dir, "signs_curry", 300)
	get_tree().quit()

