class_name MuleDeer
extends Wanderer
## A mule deer out grazing (Deer), or a spotted fawn at its mother's heels.
## Startled, it goes off in great bounds.

## The sprites (tools/npcgen/deer_art.gd): a row per look (Deer.LOOKS), five
## 40x40 frames of a grown deer (two steps, grazing, looking at you,
## bounding), then two 24x40 frames of a fawn.
const SHEET := preload("res://assets/sprites/deer.png")
const FRAME := Vector2(40, 40)
const FAWN_FRAME := Vector2(24, 40)
## Faster than this, it bounds.
const BOUND_SPEED := 80.0


func bounding() -> bool:
	return speed > BOUND_SPEED and (state == "leave" or state == "wander")


func _draw() -> void:
	var frame := 2 if state == "forage" else (3 if state == "watch" else int(steps * 4.0) % 2)
	var lift := 0.0
	if bounding() and not young:
		frame = 4
		lift = absf(sin(steps * 2.2)) * 7.0
	draw_shadow(10.0 if young else 20.0)
	if young:
		draw_frame(SHEET, Rect2(FRAME.x * 5 + (frame % 2) * FAWN_FRAME.x, coat * FRAME.y, FAWN_FRAME.x, FAWN_FRAME.y))
	else:
		draw_frame(SHEET, Rect2(frame * FRAME.x, coat * FRAME.y, FRAME.x, FRAME.y), lift)
