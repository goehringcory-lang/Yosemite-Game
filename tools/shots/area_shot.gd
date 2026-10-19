extends Node
## Renders rectangles of a region with its story overlay, without the player
## or the day/night tint, for checking part of a big map. Needs a window.
## Environment:
##   SHOT_REGION  region id
##   SHOT_RECTS   "name:x,y,w,h;..." in world pixels
##   SHOT_DIR     folder for the PNGs (default user://)
## Run: SHOT_REGION=yosemite_valley SHOT_RECTS="village:4500,800,1600,1100" godot --path . res://tools/shots/area_shot.tscn


func _ready() -> void:
	var dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://"
	var region: Region = load("res://scenes/regions/%s.tscn" % OS.get_environment("SHOT_REGION")).instantiate()
	var viewport := SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	viewport.add_child(region)
	StoryContent.attach(region)
	var camera := Camera2D.new()
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	viewport.add_child(camera)
	for spec in OS.get_environment("SHOT_RECTS").split(";"):
		var parts := spec.split(":")
		var r := parts[1].split(",")
		viewport.size = Vector2i(int(r[2]), int(r[3]))
		camera.position = Vector2(float(r[0]), float(r[1]))
		for i in 8:
			await get_tree().process_frame
		viewport.get_texture().get_image().save_png("%s/%s.png" % [dir, parts[0]])
	get_tree().quit()
