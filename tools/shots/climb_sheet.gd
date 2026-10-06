extends Node2D
## Draws the climbing screen's UI kit (panels, bars, icons, text) on one sheet.
## Run (needs a window): godot --path . res://tools/shots/climb_sheet.tscn
## Writes climb_sheet.png into SHOT_DIR (default user://).


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()
	for i in 4:
		await get_tree().process_frame
	var dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://"
	var im := get_viewport().get_texture().get_image()
	im.resize(im.get_width() * 3, im.get_height() * 3, Image.INTERPOLATE_NEAREST)
	im.save_png(dir + "/climb_sheet.png")
	get_tree().quit()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 480, 270), Color("5a7a9a"))
	var x := 8.0
	for id in ClimbUI.ICONS:
		ClimbUI.slot(self, Vector2(x, 8), id, 3)
		x += 22
		if x > 440:
			break
	ClimbUI.panel(self, Rect2(8, 40, 150, 60))
	ClimbUI.ink(self, Vector2(16, 56), "The Nose  5.13 free")
	ClimbUI.ink(self, Vector2(16, 70), "Pitch 4: Texas Flake", ClimbUI.INK_SOFT)
	ClimbUI.text(self, Vector2(170, 56), "Stamina 68   Food 60   Topped out!")
	ClimbUI.text(self, Vector2(170, 70), "Crimp it. Hold for the lip.", ClimbUI.GOLD, 10)
	ClimbUI.energy_bar(self, Rect2(440, 150, 10, 80), 0.7, false, 0.0)
	ClimbUI.energy_bar(self, Rect2(460, 150, 10, 80), 0.2, true, 0.0)
	ClimbUI.bar(self, Rect2(10, 120, 100, 6), 0.6, ClimbUI.GOOD, ClimbUI.GOOD_DARK)
	for s in [8, 10, 12, 16]:
		ClimbUI.text(self, Vector2(170, 100 + (s - 8) * 4 + 0), "Pitch 2/5 Stamina 68 Gear: 3 cams (size %d)" % s, ClimbUI.CREAM, s)
