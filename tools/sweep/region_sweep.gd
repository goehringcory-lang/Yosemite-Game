extends Node
## Visits every region in the park in each season, by day and by night, and
## lets each run for a moment, so any script error, missing node or bad
## resource a region throws shows up in the log. Prints one line per visit.
## Environment:
##   SWEEP_REGIONS  comma-separated region ids (default: every region scene)
##   SWEEP_SEASONS  comma-separated seasons, 0 spring to 3 winter (default all)
##   SWEEP_HOURS    comma-separated hours (default 10,22)
## Run: godot --headless --path . res://tools/sweep/region_sweep.tscn 2>&1 | grep -B2 -A6 -E "ERROR|WARNING"
## With a window it runs on the real renderers too, for example Low's:
##   xvfb-run -a godot --path . --rendering-method gl_compatibility res://tools/sweep/region_sweep.tscn
## (Headless, the seasonal ground shader logs a harmless "custom_samplers"
## error: the dummy renderer can't compile it. The real renderers don't.)

const REGION_DIR := "res://scenes/regions/"


func _env_list(key: String, fallback: Array) -> Array:
	var raw := OS.get_environment(key)
	return fallback if raw == "" else Array(raw.split(","))


func _ready() -> void:
	SaveManager.save_path = "user://region_sweep_save.json"
	SaveManager.delete_save()
	var all: Array = []
	for file in DirAccess.get_files_at(REGION_DIR):
		if file.ends_with(".tscn"):
			all.append(file.get_basename())
	var regions := _env_list("SWEEP_REGIONS", all)
	var seasons := _env_list("SWEEP_SEASONS", [0, 1, 2, 3])
	var hours := _env_list("SWEEP_HOURS", [10, 22])
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	for season in seasons:
		GameClock.season = int(season)
		for hour in hours:
			for id: String in regions:
				GameClock.minutes = int(hour) * 60
				var t := Time.get_ticks_msec()
				world._enter_region(id, "")
				for i in 20:
					await get_tree().physics_frame
				print("visited %s season %s hour %s (%d ms)" % [id, season, hour, Time.get_ticks_msec() - t])
	print("SWEEP DONE")
	get_tree().quit()
