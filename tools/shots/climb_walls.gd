extends Node2D
## Paints pitches of rock without the rest of the screen, to judge the walls.
##   WALLS  comma list of route:pitch (default firefall_slab:0)
##   HOUR   game hour for the light (default 12)
## Writes wall_<route>_<pitch>.png into SHOT_DIR. Needs a window.

var _tex: Texture2D
var _crop := Vector2.ZERO


func _env(key: String, fallback: String) -> String:
	return OS.get_environment(key) if OS.get_environment(key) != "" else fallback


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var dir := _env("SHOT_DIR", "user://")
	var pal := ClimbSky.palette(float(_env("HOUR", "12")))
	for item in _env("WALLS", "firefall_slab:0").split(","):
		var parts := item.split(":")
		var route: RouteData = load("res://data/routes/%s.tres" % parts[0])
		var state := ClimbState.new(route, 6, 4, {"quickdraw": 6, "cam": 6, "climbing_shoes": 1})
		state.pitch = int(parts[1])
		state._start_pitch()
		var rock: String = ClimbProfiles.get_profile(route.id).get("rock", "apron")
		var t0 := Time.get_ticks_msec()
		var wall := ClimbRock.paint(state, rock, pal, 1234)
		print("painted %s:%s in %d ms" % [parts[0], parts[1], Time.get_ticks_msec() - t0])
		_tex = ImageTexture.create_from_image(wall.image)
		_crop = Vector2(0, ClimbLayout.wall_px(state.top_row, 3, 0).y - 160)
		queue_redraw()
		for i in 3:
			await get_tree().process_frame
		var im := get_viewport().get_texture().get_image()
		im.save_png("%s/wall_%s_%s.png" % [dir, parts[0], parts[1]])
	get_tree().quit()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 480, 270), Color("4a78b8"))
	draw_texture(_tex, -_crop)
