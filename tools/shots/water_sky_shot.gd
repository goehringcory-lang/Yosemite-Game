extends Node
## Screenshots of the living water and sky: the river's reflections, the
## sky's colour on it and the stars after dark, waterfall spray and its
## rainbow, and the night sky on the climbing screen.
## Needs a window (not --headless). Environment:
##   SHOT_DIR     folder for the PNGs (default user://)
##   SHOT_REGION  region id (default yosemite_village)
##   SHOT_AT      "x,y" where to stand, world pixels (default the Lower Fall)
##   SHOT_SEASON  0-3 (default 0, spring)
##   SHOT_HOURS   comma-separated game hours (default 10,18.8,22)
##   SHOT_NAME    name prefix (default water)
## Run: SHOT_DIR=/tmp/shots xvfb-run -a godot --path . res://tools/shots/water_sky_shot.tscn


func _env(key: String, fallback: String) -> String:
	return OS.get_environment(key) if OS.get_environment(key) != "" else fallback


func _ready() -> void:
	SaveManager.save_path = "user://water_sky_shot_save.json"
	SaveManager.delete_save()
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	GameClock.season = int(_env("SHOT_SEASON", "0"))
	GameClock.day = 20
	GameClock.paused = true
	# a clear day
	Weather.today()
	Weather._today = {"snow": 0.0, "rain": 0.0, "clouds": 0.2}
	var dir := _env("SHOT_DIR", "user://")
	if _env("SHOT_PLAIN", "") != "":
		for node in world.get_children():
			if node is WaterSurface:
				node.queue_free()
	world._enter_region(_env("SHOT_REGION", "yosemite_village"), "arrival")
	for i in 6:
		await get_tree().process_frame
	var at := _env("SHOT_AT", "1520,470").split(",")
	world.player.global_position = Vector2(float(at[0]), float(at[1]))
	world.player.facing = Vector2i.UP
	for hour in _env("SHOT_HOURS", "10,18.8,22").split(","):
		GameClock.minutes = int(float(hour) * 60.0)
		for i in 10:
			await get_tree().process_frame
		for bow in world.region.find_children("*", "FallSpray", true, false):
			bow.level = 1.0 if bow.rainbow_time() else 0.0
		for i in 30:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [dir, _env("SHOT_NAME", "water"), hour])
	get_tree().quit()
