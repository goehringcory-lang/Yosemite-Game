extends Node
## Screenshots of the ground and people reacting to the weather: tracks in
## the snow and breath in the cold (the player walks a loop first, so there
## is a trail), and wet ground with puddles in the rain. Needs a window (not
## --headless). Environment:
##   SHOT_DIR      folder for the PNGs (default user://)
##   SHOT_REGION   region id (default curry_village)
##   SHOT_SPAWN    spawn to start from (default arrival)
##   SHOT_SEASON   0 spring, 1 summer, 2 fall, 3 winter (default 3)
##   SHOT_DAY      day of the season (default 14: deep snow, a clear day)
##   SHOT_HOUR     game hour (default 9)
##   SHOT_WALK     world pixels to walk in a loop before the shot (default 260)
##   SHOT_NAME     file name (default <region>_<season>_<day>)
##   SHOT_SCALE    integer upscale for the saved PNG (default 1)
## Run with a fixed frame rate, so a slow software renderer doesn't age the
## tracks while the player walks:
## SHOT_DIR=/tmp/shots xvfb-run -a godot --path . --fixed-fps 30 res://tools/shots/weather_fx_shot.tscn


func _env(key: String, fallback: String) -> String:
	return OS.get_environment(key) if OS.get_environment(key) != "" else fallback


func _ready() -> void:
	SaveManager.save_path = "user://weather_fx_shot_save.json"
	SaveManager.delete_save()
	Wind.enabled = false
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	GameClock.season = int(_env("SHOT_SEASON", "3"))
	GameClock.day = int(_env("SHOT_DAY", "14"))
	GameClock.minutes = int(float(_env("SHOT_HOUR", "9")) * 60.0)
	GameClock.paused = true
	var region_id := _env("SHOT_REGION", "curry_village")
	await world.go_to_region(region_id, _env("SHOT_SPAWN", "arrival"))
	world.hud.visible = false
	GameClock.paused = true
	var player: Node2D = world.player
	var start := player.global_position
	var walk := float(_env("SHOT_WALK", "260"))
	# a lap round a box, at walking pace, then back to the start
	var corners := [start, start + Vector2(walk * 0.3, 0), start + Vector2(walk * 0.3, walk * 0.2), start + Vector2(0, walk * 0.2), start + Vector2(0, 8)]
	if walk > 0.0:
		for c in range(1, corners.size()):
			var from: Vector2 = corners[c - 1]
			var to: Vector2 = corners[c]
			var dir := (to - from).normalized()
			player.facing = Vector2i(roundi(dir.x), roundi(dir.y))
			var steps := int(from.distance_to(to) / 1.5)
			for i in steps:
				player.global_position = from.lerp(to, float(i + 1) / steps)
				await get_tree().process_frame
		player.facing = Vector2i.LEFT
	player.get_node("Camera").reset_smoothing()
	# a moment for breath and rings to be mid-air
	for i in 30:
		await get_tree().process_frame
	var breath := world.get_node_or_null("Breath")
	if breath and Seasons.cold():
		breath.exhale(player.global_position, Vector2(player.facing))
	await get_tree().create_timer(0.9).timeout
	var image := get_viewport().get_texture().get_image()
	var scale := int(_env("SHOT_SCALE", "1"))
	if scale > 1:
		image.resize(image.get_width() * scale, image.get_height() * scale, Image.INTERPOLATE_NEAREST)
	var dir_out := _env("SHOT_DIR", "user://")
	var name_out := _env("SHOT_NAME", "%s_%d_%d" % [region_id, GameClock.season, GameClock.day])
	image.save_png("%s/%s.png" % [dir_out, name_out])
	get_tree().quit()
