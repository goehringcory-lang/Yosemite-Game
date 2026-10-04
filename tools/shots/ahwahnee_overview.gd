extends Node
## Renders a whole region in one picture (no player, no day/night tint), for
## checking a layout. Needs a window (not --headless). Environment:
##   SHOT_REGION  region id (default the_ahwahnee)
##   SHOT_OUT     PNG path (default user://overview.png)
##   SHOT_SCALE   integer downscale divisor (default 1)
## Run: SHOT_REGION=ahwahnee_trail godot --path . res://tools/shots/ahwahnee_overview.tscn


func _ready() -> void:
	var id := OS.get_environment("SHOT_REGION") if OS.get_environment("SHOT_REGION") != "" else "the_ahwahnee"
	var out := OS.get_environment("SHOT_OUT") if OS.get_environment("SHOT_OUT") != "" else "user://overview.png"
	var div := int(OS.get_environment("SHOT_SCALE")) if OS.get_environment("SHOT_SCALE") != "" else 1
	var region: Region = load("res://scenes/regions/%s.tscn" % id).instantiate()
	var size := Vector2i(region.get_ground().get_used_rect().size * 16) if region.get_ground() else Vector2i(1024, 1024)
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	add_child(viewport)
	viewport.add_child(region)
	var camera := Camera2D.new()
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	viewport.add_child(camera)
	for i in 6:
		await get_tree().process_frame
	var image := viewport.get_texture().get_image()
	if div > 1:
		image.resize(image.get_width() / div, image.get_height() / div, Image.INTERPOLATE_NEAREST)
	image.save_png(out if out.begins_with("res://") or out.begins_with("user://") else out)
	print("saved ", out, " ", image.get_size())
	get_tree().quit()
