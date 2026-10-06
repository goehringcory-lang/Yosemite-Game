extends Node2D
## Lays out the climber (bare, starter kit, full rack, glacier kit, poses) and
## every belayer for a look. Run (needs a window):
##   SHEET=a|b1|b2|c godot --path . res://tools/shots/climb_figures.tscn
## a = climbers and gear, b1/b2 = belayers (5 each), c = poses and chimney.
## Writes climb_figures_<sheet>.png into SHOT_DIR (default user://).

var sheet := "a"


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if OS.get_environment("SHEET") != "":
		sheet = OS.get_environment("SHEET")
	queue_redraw()
	for i in 4:
		await get_tree().process_frame
	var dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://"
	var im := get_viewport().get_texture().get_image()
	im.save_png(dir + "/climb_figures_%s.png" % sheet)
	im.save_png(dir + "/climb_figures.png")
	get_tree().quit()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 480, 270), Color("8c8a86"))
	match sheet:
		"a":
			_sheet_a()
		"b1":
			_sheet_b(0)
		"b2":
			_sheet_b(5)
		"c":
			_sheet_c()


func _sheet_a() -> void:
	var kits := [
		{},
		{"climbing_shoes": 1, "chalk_bag": 1, "harness": 1, "quickdraw": 5},
		{"climbing_shoes": 1, "chalk_bag": 1, "harness": 1, "quickdraw": 6, "cam": 5, "belay_device": 1, "rope": 1},
		{"climbing_shoes": 1, "chalk_bag": 1, "harness": 1, "quickdraw": 6, "cam": 8, "belay_device": 1, "aiders": 2, "portaledge": 1},
	]
	var x := 2.0
	for i in kits.size():
		for step in 2:
			draw_texture(ClimbSprites.climber(ClimbSprites.stance(step), kits[i], {"portaledge": i == 3, "aiders": i == 3}), Vector2(x, 0))
			x += 56
	var snow_kit := {"climbing_shoes": 1, "harness": 1, "ice_axe": 1, "crampons": 1, "quickdraw": 2}
	draw_texture(ClimbSprites.climber(ClimbSprites.stance(0), snow_kit, {"snow": true}), Vector2(330, 70))
	# Hardware, large icons.
	for i in 5:
		draw_texture(ClimbSprites.hardware("cam", i), Vector2(6 + i * 14, 80))
	draw_texture(ClimbSprites.hardware("draw"), Vector2(80, 80))
	draw_texture(ClimbSprites.hardware("pin_draw"), Vector2(94, 80))
	draw_texture(ClimbSprites.hardware("bolt"), Vector2(108, 80))
	var ids := ["cam", "quickdraw", "climbing_shoes", "approach_shoes", "chalk_bag", "rope", "harness", "belay_device", "aiders", "ascenders", "haul_bag", "portaledge", "ice_axe", "crampons", "food", "chalk", "pin", "star", "check"]
	for i in ids.size():
		draw_texture(ClimbUI.icon_texture(ids[i]), Vector2(6 + (i % 10) * 14, 104 + (i / 10) * 14))
	for i in 6:
		ClimbUI.slot(self, Vector2(6 + i * 22, 140), ids[i], i, i == 5, i == 2)
	ClimbUI.panel(self, Rect2(150, 80, 120, 60))
	ClimbUI.ink(self, Vector2(160, 100), "Parchment panel", ClimbUI.INK, 10)
	ClimbUI.bar(self, Rect2(160, 118, 90, 6), 0.6, ClimbUI.GOOD, ClimbUI.GOOD_DARK)
	ClimbUI.energy_bar(self, Rect2(290, 90, 10, 50), 0.6, false, 0.0)


func _sheet_b(first: int) -> void:
	var ids := ClimbProfiles.BELAYERS.keys()
	var modes := [["belay", 0], ["belay", 1], ["belay", 2], ["look_up", 0], ["anchor", 0], ["sit", 0], ["cheer", 0], ["cheer", 1]]
	for r in 5:
		var id: String = ids[first + r]
		var look: Dictionary = ClimbProfiles.BELAYERS[id].duplicate()
		look["id"] = id
		for m in modes.size():
			draw_texture(ClimbSprites.belayer(look, modes[m][0], modes[m][1]), Vector2(2 + m * 56, 2 + r * 54))


func _sheet_c() -> void:
	var kit := {"climbing_shoes": 1, "chalk_bag": 1, "harness": 1, "quickdraw": 4, "cam": 4, "belay_device": 1}
	var poses := [ClimbSprites.stance(0), ClimbSprites.fall_pose(), ClimbSprites.hang_pose(), ClimbSprites.cheer_pose(), ClimbSprites.chalk_pose(0), ClimbSprites.protect_pose(0), ClimbSprites.eat_pose(), ClimbSprites.rest_pose()]
	for i in poses.size():
		draw_texture(ClimbSprites.climber(poses[i], kit), Vector2(2 + i * 58, 0))
	draw_texture(ClimbSprites.climber(ClimbSprites.roof_pose(0), kit), Vector2(2, 70))
	draw_texture(ClimbSprites.climber(ClimbSprites.roof_pose(1), kit), Vector2(60, 70))
	draw_rect(Rect2(125, 70, 6, 64), Color("5a5a60"))
	draw_rect(Rect2(154, 70, 6, 64), Color("5a5a60"))
	draw_texture(ClimbSprites.climber(ClimbSprites.chimney_pose(-1), kit), Vector2(131 + 6 - 28, 70))
	draw_rect(Rect2(225, 70, 6, 64), Color("5a5a60"))
	draw_rect(Rect2(254, 70, 6, 64), Color("5a5a60"))
	draw_texture(ClimbSprites.climber(ClimbSprites.chimney_pose(1), kit), Vector2(254 - 6 - 28, 70))
	draw_texture(ClimbSprites.climber(ClimbSprites.stand_pose(), kit), Vector2(300, 70))
