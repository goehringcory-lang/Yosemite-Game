extends Node2D
## Lays out the full-density climber (ClimberHD) in every hand shape and foot
## technique, at the climbing screen's scale (two screen pixels to a grid
## pixel), and in a few whole-body poses. Run (needs a window):
##   godot --path . res://tools/shots/climber_hands.tscn
## Writes climber_hands.png into SHOT_DIR (default user://).

const KIT := {"climbing_shoes": 1, "chalk_bag": 1, "harness": 1, "quickdraw": 6, "cam": 5, "belay_device": 1}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()
	for i in 4:
		await get_tree().process_frame
	var dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://"
	get_viewport().get_texture().get_image().save_png(dir + "/climber_hands.png")
	get_tree().quit()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(2, 2))
	draw_rect(Rect2(0, 0, 480, 270), Color("8c8a86"))
	var x := 0.0
	var y := 0.0
	for shape: String in HoldShape.HANDS:
		var pose := ClimbSprites.stance(0)
		pose["gr"] = shape
		pose["gl"] = shape
		pose["ftr"] = HoldShape.FEET[(x / 48) as int % HoldShape.FEET.size()]
		pose["ftl"] = pose.ftr
		draw_texture(ClimbSprites.climber(pose, KIT, {"snow": shape == "tool"} if shape != "tool" else {"snow": true}), Vector2(x - 4, y))
		ClimbUI.ink(self, Vector2(x + 4, y + 66), HoldShape.label(shape) + " / " + str(pose.ftr), ClimbUI.INK, 6)
		x += 48
		if x > 440:
			x = 0
			y += 76
	var poses := [ClimbSprites.stand_pose(), ClimbSprites.fall_pose(), ClimbSprites.hang_pose(), ClimbSprites.cheer_pose(), ClimbSprites.style_pose("flake", 0), ClimbSprites.style_pose("crack", 1), ClimbSprites.rest_pose()]
	for p: Dictionary in poses:
		draw_texture(ClimbSprites.climber(p, KIT), Vector2(x - 4, y))
		x += 48
		if x > 440:
			x = 0
			y += 76
