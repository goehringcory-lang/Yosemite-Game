extends Node2D
## Every skyline landmark on one sheet, at midday. Needs a window.
##   HOUR  game hour (default 12)
## Writes climb_landmarks.png into SHOT_DIR.

var _cells: Array = []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var pal := ClimbSky.palette(float(OS.get_environment("HOUR") if OS.get_environment("HOUR") != "" else "12"))
	var sky := ImageTexture.create_from_image(ClimbSky.sky(pal))
	var kinds := ClimbLandscape.LANDMARKS.keys()
	for kind: String in kinds:
		var profile := {"view": [{"k": kind, "x": 240, "s": 1.0, "l": 1}]}
		var land := ClimbLandscape.build(profile, pal, 7)
		var im: Image = land.layers[1].image
		var region := im.get_region(Rect2i(130, ClimbLandscape.PAD + 40, 220, 170))
		_cells.append({"name": kind, "tex": ImageTexture.create_from_image(region)})
	var sky_tex := sky
	var dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://"
	var per_page := 6
	for page in ceili(_cells.size() / float(per_page)):
		set_meta("page", page)
		set_meta("sky", sky_tex)
		queue_redraw()
		for i in 3:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s/climb_landmarks_%d.png" % [dir, page])
	get_tree().quit()


func _draw() -> void:
	var page: int = get_meta("page", 0)
	for i in 6:
		var idx := page * 6 + i
		if idx >= _cells.size():
			break
		var cell: Dictionary = _cells[idx]
		var ox := (i % 3) * 160
		var oy := (i / 3) * 135
		draw_texture_rect_region(get_meta("sky"), Rect2(ox, oy, 160, 135), Rect2(0, 60, 160, 135))
		draw_texture_rect_region(cell.tex, Rect2(ox, oy, 160, 135), Rect2(30, 10, 160, 135))
		draw_string(ClimbUI.font(), Vector2(ox + 4, oy + 10), cell.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
