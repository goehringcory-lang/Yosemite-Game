class_name Bear
extends Wanderer
## A black bear out wandering (Bears), or a cub at its mother's heels.

## The sprites (tools/npcgen/bear_art.gd): a row per coat, four 40x28 frames
## of a grown bear (two steps, nose down, looking at you), then two 24x28
## frames of a cub.
const SHEET := preload("res://assets/sprites/bears.png")
const FRAME := Vector2(40, 28)
const CUB_FRAME := Vector2(24, 28)


func _draw() -> void:
	var frame := 2 if state == "forage" else (3 if state == "watch" else int(steps * 4.0) % 2)
	draw_shadow(14.0 if young else 26.0)
	if young:
		draw_frame(SHEET, Rect2(FRAME.x * 4 + (frame % 2) * CUB_FRAME.x, coat * FRAME.y, CUB_FRAME.x, CUB_FRAME.y))
	else:
		draw_frame(SHEET, Rect2(frame * FRAME.x, coat * FRAME.y, FRAME.x, FRAME.y))
