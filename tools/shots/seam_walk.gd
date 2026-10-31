extends Node
## Walks the player over a seam between two regions (see Seam) in the real
## game and saves frames on the way, for checking it looks seamless.
## Needs a window. Environment:
##   SHOT_REGION  where to start (default yosemite_village)
##   SHOT_SPAWN   spawn to start from (default west_road)
##   SHOT_WALK    move_left / move_right / move_up / move_down (default move_left)
##   SHOT_HOUR    hour of day (default 12)
##   SHOT_DIR     folder for the PNGs (default user://)
## Run: godot --path . res://tools/shots/seam_walk.tscn


func _env(key: String, fallback: String) -> String:
	var value := OS.get_environment(key)
	return value if value != "" else fallback


func _ready() -> void:
	var dir := _env("SHOT_DIR", "user://")
	SaveManager.save_path = "user://seam_walk_save.json"
	SaveManager.delete_save()
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	GameClock.advance_minutes(maxi(0, (int(_env("SHOT_HOUR", "12")) - GameClock.hour) * 60))
	await world.go_to_region(_env("SHOT_REGION", "yosemite_village"), _env("SHOT_SPAWN", "west_road"))
	for i in 1200:
		if world.seam:
			break
		await get_tree().process_frame
	for i in 30:
		await get_tree().process_frame
	var action := _env("SHOT_WALK", "move_left")
	Input.action_press(action)
	var shot := 0
	var crossed_at := -1
	var from: String = world.region.region_id
	for i in 400:
		await get_tree().process_frame
		if world.region.region_id != from and crossed_at < 0:
			crossed_at = i
		if i % 12 == 0 or (crossed_at >= 0 and i - crossed_at <= 2):
			get_viewport().get_texture().get_image().save_png("%s/walk_%03d_%s.png" % [dir, shot, world.region.region_id])
			shot += 1
		if crossed_at >= 0 and i - crossed_at > 90:
			break
	Input.action_release(action)
	SaveManager.delete_save()
	get_tree().quit()
