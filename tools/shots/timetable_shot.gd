extends Node
## Photographs a town over a sped-up stretch of the day, to watch the people
## who keep a timetable walk between their stops. Needs a window.
## Environment:
##   SHOT_DIR     folder for the PNGs (default user://)
##   SHOT_REGION  town (default curry_village)
##   SHOT_SPOT    where to stand (default plaza)
##   SHOT_FROM    clock time to start, in minutes past midnight (default 595)
## Run: SHOT_DIR=/tmp/shots xvfb-run -a godot --path . res://tools/shots/timetable_shot.tscn


func _ready() -> void:
	SaveManager.save_path = "user://timetable_shot_save.json"
	SaveManager.delete_save()
	var env := func(key: String, fallback: String) -> String:
		return OS.get_environment(key) if OS.get_environment(key) != "" else fallback
	var dir: String = env.call("SHOT_DIR", "user://")
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	GameClock.minutes = int(env.call("SHOT_FROM", "595"))
	await world.go_to_region(env.call("SHOT_REGION", "curry_village"), env.call("SHOT_SPOT", "plaza"))
	world.player.can_act = false
	# ten clock minutes every 0.7 s
	GameClock.seconds_per_tick = 0.7
	for i in 12:
		await get_tree().create_timer(1.5).timeout
		var image := get_viewport().get_texture().get_image()
		image.save_png("%s/timetable_%02d.png" % [dir, i])
	get_tree().quit()
