extends Node
## Stands in a region for a few seconds so the wind can be filmed: the trees
## and plants swaying and a gust crossing the grass (see scripts/world/wind.gd).
## Run it with Godot's movie writer, which needs a window (not --headless).
## Environment:
##   SHOT_REGION   region id, e.g. el_capitan_meadow
##   SHOT_SPAWN    spawn name, or "name@x:y" for a tile spot (default arrival)
##   SHOT_HOUR     game hour (default 12)
##   SHOT_SEASON   0 spring, 1 summer, 2 fall, 3 winter (default 1)
##   SHOT_SECONDS  how long to film (default 12)
##   SHOT_WIND     0 to still the air, for a "before" (default 1)
## Run: SHOT_REGION=el_capitan_meadow xvfb-run -a godot --path . --write-movie /tmp/wind.avi --fixed-fps 30 res://tools/shots/wind_shot.tscn


func _env(key: String, fallback: String) -> String:
	return OS.get_environment(key) if OS.get_environment(key) != "" else fallback


func _ready() -> void:
	Wind.enabled = _env("SHOT_WIND", "1") != "0"
	SaveManager.save_path = "user://wind_shot_save.json"
	SaveManager.delete_save()
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	GameClock.minutes = int(float(_env("SHOT_HOUR", "12")) * 60.0)
	GameClock.season = int(_env("SHOT_SEASON", "1"))
	GameClock.paused = true
	var at := _env("SHOT_SPAWN", "arrival").split("@")
	await world.go_to_region(_env("SHOT_REGION", "el_capitan_meadow"), at[0])
	if at.size() > 1:
		var xy := at[1].split(":")
		world.player.global_position = Vector2(float(xy[0]), float(xy[1])) * 32.0
		world.player.get_node("Camera").reset_smoothing()
	world.hud.visible = false
	GameClock.paused = true
	await get_tree().create_timer(float(_env("SHOT_SECONDS", "12"))).timeout
	get_tree().quit()
