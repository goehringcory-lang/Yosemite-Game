class_name Bear
extends Wanderer
## A black bear out wandering (Bears), or a cub at its mother's heels.

## The sprites (tools/npcgen/bear_art.gd): a row per coat, four 40x28 frames
## of a grown bear (two steps, nose down, looking at you), two 24x28 frames
## of a cub, then two more of the bear (legs passing, rooting) and the cub's
## passing step.
const SHEET := preload("res://assets/sprites/bears.png")
const FRAME := Vector2(40, 28)
const CUB_FRAME := Vector2(24, 28)
## Its walk, as frames: a step, the legs passing, the other step, passing
## (4 is the bear's passing frame; a cub's is its own third).
const WALK := [0, 4, 1, 4]
const CUB_WALK := [0, 2, 1, 2]
## Nose down, it roots about: shoving its nose along every so long.
const ROOT_EVERY := 1.3
const ROOT_TIME := 0.45


func _draw() -> void:
	var step := int(steps * 8.0) % WALK.size()
	draw_shadow(14.0 if young else 26.0)
	if young:
		var cub: int = CUB_WALK[step]
		if state == "forage" or state == "watch":
			cub = 2
		draw_frame(SHEET, Rect2(_cub_x(cub), coat * FRAME.y, CUB_FRAME.x, CUB_FRAME.y))
		return
	var frame: int = WALK[step]
	if state == "forage":
		frame = 5 if fmod(age, ROOT_EVERY) < ROOT_TIME else 2
	elif state == "watch":
		frame = 3
	draw_frame(SHEET, Rect2(_bear_x(frame), coat * FRAME.y, FRAME.x, FRAME.y))


## Where bear frame [param frame] starts on the sheet (4 and 5 come after
## the cub's first two).
static func _bear_x(frame: int) -> float:
	return frame * FRAME.x if frame < 4 else FRAME.x * 4 + CUB_FRAME.x * 2 + (frame - 4) * FRAME.x


static func _cub_x(frame: int) -> float:
	return FRAME.x * 4 + frame * CUB_FRAME.x if frame < 2 else FRAME.x * 6 + CUB_FRAME.x * 2
