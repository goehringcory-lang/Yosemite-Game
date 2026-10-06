extends Node2D
## Lays out the climber (bare, starter kit, full rack, glacier kit) and every
## belayer for a look. Run (needs a window): godot --path . res://tools/shots/climb_figures.tscn
## Writes climb_figures.png into SHOT_DIR (default user://).


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()
	for i in 4:
		await get_tree().process_frame
	var dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://"
	var im := get_viewport().get_texture().get_image()
	im.save_png(dir + "/climb_figures.png")
	get_tree().quit()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 480, 270), Color("8c8a86"))
	var kits := [
		{},
		{"climbing_shoes": 1, "chalk_bag": 1, "harness": 1, "quickdraw": 5},
		{"climbing_shoes": 1, "chalk_bag": 1, "harness": 1, "quickdraw": 6, "cam": 5, "belay_device": 1, "rope": 1},
		{"climbing_shoes": 1, "chalk_bag": 1, "harness": 1, "quickdraw": 6, "cam": 8, "belay_device": 1, "aiders": 2, "portaledge": 1},
	]
	var x := 6.0
	for i in kits.size():
		for step in 2:
			draw_texture(ClimbSprites.climber(ClimbSprites.stance(step), kits[i], {"portaledge": i == 3, "aiders": i == 3}), Vector2(x, 4))
			x += 48
	var snow_kit := {"climbing_shoes": 1, "harness": 1, "ice_axe": 1, "crampons": 1, "quickdraw": 2}
	draw_texture(ClimbSprites.climber(ClimbSprites.stance(0), snow_kit, {"snow": true}), Vector2(x, 4))
	x = 6.0
	var ids := ClimbProfiles.BELAYERS.keys()
	for id: String in ids:
		var look: Dictionary = ClimbProfiles.BELAYERS[id].duplicate()
		look["id"] = id
		draw_texture(ClimbSprites.belayer(look, "belay", 0), Vector2(x, 70))
		draw_texture(ClimbSprites.belayer(look, "sit", 0), Vector2(x, 130))
		x += 44
	for i in 4:
		draw_texture(ClimbSprites.hardware("cam", i), Vector2(6 + i * 14, 200))
	draw_texture(ClimbSprites.hardware("draw"), Vector2(70, 200))
	draw_texture(ClimbSprites.hardware("pin_draw"), Vector2(84, 200))
