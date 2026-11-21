extends Node
## Renders the ground around every hidden find (Finds), one PNG each, with the
## find showing (its season and hour set), for checking where they lie.
## Needs a window.
##   SHOT_DIR   folder for the PNGs (default user://)
##   SHOT_FINDS comma-separated find ids (default all)
##   SHOT_SIZE  "w,h" of each shot in world pixels (default 480,270)
## Run: xvfb-run -a godot --path . res://tools/shots/finds_shot.tscn


func _ready() -> void:
	var dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://"
	var only := OS.get_environment("SHOT_FINDS").split(",", false)
	var size := Vector2i(480, 270)
	if OS.get_environment("SHOT_SIZE") != "":
		var s := OS.get_environment("SHOT_SIZE").split(",")
		size = Vector2i(int(s[0]), int(s[1]))
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var camera := Camera2D.new()
	viewport.add_child(camera)
	GameClock.paused = true
	for find: Dictionary in Finds.all():
		if not only.is_empty() and not find.id in only:
			continue
		if not find.has("pos"):
			continue
		var seasons: Array = find.get("seasons", [])
		GameClock.season = Finds.SEASONS[seasons[0]] if not seasons.is_empty() else GameClock.Season.SUMMER
		var hours: Array = find.get("hours", [])
		GameClock.minutes = (int(hours[0]) + 1) * 60 if hours.size() == 2 else 12 * 60
		var region: Region = load("res://scenes/regions/%s.tscn" % find.region).instantiate()
		viewport.add_child(region)
		StoryContent.attach(region)
		camera.position = Vector2(find.pos[0], find.pos[1])
		for i in 10:
			await get_tree().process_frame
		viewport.get_texture().get_image().save_png("%s/find_%s.png" % [dir, find.id])
		print("shot ", find.id)
		viewport.remove_child(region)
		region.free()
	get_tree().quit()
