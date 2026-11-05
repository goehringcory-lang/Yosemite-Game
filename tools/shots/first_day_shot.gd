extends Node
## Screenshots of the guided first day (FirstDay): the card under the clock
## on the first lesson, the arrow at the screen's edge and over a find, the
## card turning green when a lesson is done, and the evening's tent.
## Needs a window (not --headless):
##   SHOT_DIR=/tmp/shots xvfb-run -a godot --path . res://tools/shots/first_day_shot.tscn
## SHOT_PAD=1 names the gamepad's buttons.


func _snap(dir: String, shot_name: String, frames := 30) -> void:
	for i in frames:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	image.save_png("%s/first_day_%s.png" % [dir, shot_name])


func _ready() -> void:
	SaveManager.save_path = "user://first_day_shot_save.json"
	SaveManager.delete_save()
	Settings.ensure_loaded()
	Settings.prompts = Settings.Prompts.GAMEPAD if OS.get_environment("SHOT_PAD") == "1" else Settings.Prompts.KEYBOARD
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	GameClock.minutes = 8 * 60
	GameClock.paused = true
	var dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://"
	var guide: FirstDay = world.get_node("FirstDay")
	await _snap(dir, "1_walk", 60)
	guide.mark("walk")
	await _snap(dir, "2_walk_done", 3)
	await _snap(dir, "3_talk", 90)
	QuestLog.talk_to("galen_clark")
	guide.mark("talk")
	await _snap(dir, "4_gather", 120)
	# off to one side, so the arrow points from the edge
	world.player.global_position += Vector2(0, 520)
	await _snap(dir, "5_gather_edge", 40)
	for id in ["gather", "backpack", "quests", "run", "head_out", "map"]:
		guide.mark(id)
	GameClock.minutes = 20 * 60 + 30
	world.player.global_position += Vector2(0, -520)
	await _snap(dir, "6_sleep", 120)
	SaveManager.delete_save()
	get_tree().quit()
