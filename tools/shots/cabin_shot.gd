extends Node
## Renders your cabin (Cabin outside, CabinRoom inside) at a stage of the
## story, for checking how it grows. Needs a window.
## Environment:
##   SHOT_STAGE  "start" (a new game), "early" (Lamon's roof and bed, the
##               table, the window box), "middle" (through the Nose) or
##               "end" (every quest). Default "end".
##   SHOT_HOUR   the hour (default 10)
##   SHOT_DIR    folder for the PNGs (default user://)
## Writes cabin_<stage>_outside.png and cabin_<stage>_inside.png.
## Run: xvfb-run godot --path . res://tools/shots/cabin_shot.tscn

const EARLY := ["clark_register", "lamon_orchard", "degnan_bread", "enid_press", "matthes_reading_ice", "shop_guidebook"]


func _ready() -> void:
	var dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://"
	var stage := OS.get_environment("SHOT_STAGE") if OS.get_environment("SHOT_STAGE") != "" else "end"
	var hour := int(OS.get_environment("SHOT_HOUR")) if OS.get_environment("SHOT_HOUR") != "" else 10
	NewGame.reset()
	GameClock.minutes = hour * 60
	if stage == "early":
		QuestLog.completed.assign(EARLY)
	elif stage == "middle":
		QuestLog.completed.assign(EARLY + preload("res://tools/shots/camp_shot.gd").MIDDLE
			+ ["clark_big_trees", "anderson_half_dome", "mccauley_firefall", "hodges_first_night", "lamon_winter"])
	elif stage == "end":
		for quest: QuestData in QuestLog.QUESTS:
			QuestLog.completed.append(quest.id)
	Camp.changed.emit()
	await _shoot("lamon_homestead", Vector2(Cabin.POS.x - 340, Cabin.POS.y - 230), "%s/cabin_%s_outside.png" % [dir, stage])
	await _shoot(Cabin.ROOM_REGION, Vector2(-96, -40), "%s/cabin_%s_inside.png" % [dir, stage])
	get_tree().quit()


func _shoot(region_id: String, at: Vector2, path: String) -> void:
	var region: Region = load("res://scenes/regions/%s.tscn" % region_id).instantiate()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(680, 420) if not region.indoors else Vector2i(960, 464)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	viewport.add_child(region)
	StoryContent.attach(region)
	var camera := Camera2D.new()
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	camera.position = at
	viewport.add_child(camera)
	for i in 10:
		await get_tree().process_frame
	viewport.get_texture().get_image().save_png(path)
	viewport.queue_free()
