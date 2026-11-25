extends Node2D
## Lays out every grip close-up (12 hand shapes, right then left, and the 4 feet)
## for a look. Run (needs a window):
##   SHOT_DIR=/tmp/gc [ZOOM=2] [CHALK=1] godot --path . res://tools/shots/grip_closeups.tscn
## Writes grip_closeups.png into SHOT_DIR (default user://). ZOOM=2 draws only
## the right hands and the right feet at 2x. CHALK=1 chalks every other hand.

const ROCK := Color("9a8f84")

## Kept alive: a texture freed mid-draw paints white.
var _texs := {}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()
	for i in 4:
		await get_tree().process_frame
	var dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://"
	var im := get_viewport().get_texture().get_image()
	im.save_png(dir + "/grip_closeups.png")
	get_tree().quit()



func _tex(shape: String, right: bool, rock: Color, chalk := false, foot := false, at := Vector2.ZERO) -> void:
	var key := [shape, right, chalk, foot, rock]
	if not _texs.has(key):
		_texs[key] = ImageTexture.create_from_image(ClimbGripCloseup.image(shape, right, rock, chalk, foot))
	draw_texture(_texs[key], at)


func _draw() -> void:
	draw_rect(Rect2(0, 0, 960, 540), Color("4a4540"))
	var chalk := OS.get_environment("CHALK") != ""
	var zoom := OS.get_environment("ZOOM") == "2"
	var step := 66.0
	if zoom:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(2, 2))
		# 12 right hands in 2 rows of 6 cannot fit 2x with feet: hands only, feet below.
		step = 70.0
	for i in HoldShape.HANDS.size():
		var shape: String = HoldShape.HANDS[i]
		var x := 3.0 + (i % 6) * step
		var y := 3.0 + (i / 6) * step * (1.0 if zoom else 2.0)
		_tex(shape, true, ROCK, chalk and i % 2 == 0, false, Vector2(x, y))
		if not zoom:
			_tex(shape, false, ROCK, chalk and i % 2 == 0, false, Vector2(x, y + 66.0))
	for i in HoldShape.FEET.size():
		var shape: String = HoldShape.FEET[i]
		if zoom:
			_tex(shape, true, ROCK, false, true, Vector2(3.0 + i * step, 3.0 + 2 * step))
		else:
			var x := 3.0 + 6 * step + (i % 2) * step
			var y := 3.0 + (i / 2) * 66.0 * 2.0
			_tex(shape, true, ROCK, false, true, Vector2(x, y))
			_tex(shape, false, ROCK, false, true, Vector2(x, y + 66.0))
