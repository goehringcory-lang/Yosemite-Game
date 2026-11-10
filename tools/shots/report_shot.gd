extends Node
## Saves screenshots of Report a problem: the card with a note typed, and the
## card once the report is saved; and keeps the report's own screenshot, to
## check it is the game without the card. Uses its own folder and save.
## Needs a window (not --headless). Environment:
##   SHOT_DIR    folder for the PNGs (default user://)
##   SHOT_SCALE  integer upscale (default 2)
## Run: SHOT_DIR=/tmp/shots godot --path . res://tools/shots/report_shot.tscn


func _snap(dir: String, scale: int, shot_name: String) -> void:
	for i in 10:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	if scale > 1:
		image.resize(image.get_width() * scale, image.get_height() * scale, Image.INTERPOLATE_NEAREST)
	image.save_png("%s/report_%s.png" % [dir, shot_name])


func _ready() -> void:
	ProblemReport.dir = "user://report_shot"
	SaveManager.save_path = "user://report_shot_save.json"
	var dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://"
	var scale := int(OS.get_environment("SHOT_SCALE")) if OS.get_environment("SHOT_SCALE") != "" else 2
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	GameClock.minutes = 11 * 60
	GameClock.paused = true
	await world.go_to_region("curry_village", "arrival")
	for i in 12:
		await get_tree().process_frame
	var report: ProblemReport = get_tree().get_first_node_in_group("problem_report")
	await report.open()
	report._note.text = "The bear walked through the store wall"
	await _snap(dir, scale, "card")
	report._shot.save_png("%s/report_taken.png" % dir)
	report.save()
	await _snap(dir, scale, "saved")
	report.close()
	get_tree().quit()
