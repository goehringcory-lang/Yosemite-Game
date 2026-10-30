class_name MuleDeer
extends Wanderer
## A mule deer out grazing (Deer), or a spotted fawn at its mother's heels.
## Startled, it goes off in great bounds.

## The sprites (tools/npcgen/deer_art.gd): a row per look (Deer.LOOKS), five
## 40x40 frames of a grown deer (two steps, grazing, looking at you,
## bounding), two 24x40 frames of a fawn, then three more of the deer (legs
## passing, chewing with an ear flicked back, tail flicked up) and the
## fawn's passing step.
const SHEET := preload("res://assets/sprites/deer.png")
const FRAME := Vector2(40, 40)
const FAWN_FRAME := Vector2(24, 40)
## Faster than this, it bounds.
const BOUND_SPEED := 80.0
## Its walk: a step, the legs passing, the other step, passing.
const WALK := [0, 5, 1, 5]
const FAWN_WALK := [0, 2, 1, 2]
## Grazing, it chews with an ear flicked back now and then; watching you,
## it flicks its tail up now and then.
const FLICK_EVERY := 1.7
const FLICK_TIME := 0.35


func bounding() -> bool:
	return speed > BOUND_SPEED and (state == "leave" or state == "wander")


func _draw() -> void:
	var step := int(steps * 8.0) % WALK.size()
	var flick := fmod(age, FLICK_EVERY) < FLICK_TIME
	if young:
		draw_shadow(10.0)
		var fawn: int = FAWN_WALK[step]
		if state == "forage" or state == "watch":
			fawn = 2
		draw_frame(SHEET, Rect2(_fawn_x(fawn), coat * FRAME.y, FAWN_FRAME.x, FAWN_FRAME.y))
		return
	var frame: int = WALK[step]
	var lift := 0.0
	if state == "forage":
		frame = 6 if flick else 2
	elif state == "watch":
		frame = 7 if flick else 3
	elif bounding():
		frame = 4
		lift = absf(sin(steps * 2.2)) * 7.0
	draw_shadow(20.0)
	draw_frame(SHEET, Rect2(_deer_x(frame), coat * FRAME.y, FRAME.x, FRAME.y), lift)


## Where deer frame [param frame] starts on the sheet (5 to 7 come after the
## fawn's first two).
static func _deer_x(frame: int) -> float:
	return frame * FRAME.x if frame < 5 else FRAME.x * 5 + FAWN_FRAME.x * 2 + (frame - 5) * FRAME.x


static func _fawn_x(frame: int) -> float:
	return FRAME.x * 5 + frame * FAWN_FRAME.x if frame < 2 else FRAME.x * 8 + FAWN_FRAME.x * 2
