class_name Bobcat
extends Wanderer
## A bobcat out hunting (Bobcats). Walking, it pads along; foraging, it
## crouches low and creeps, then pounces at the end; watching, it freezes
## and looks straight at you. Painted on WildlifeSheet.

## Its walk, as frames: a step, the legs passing, the other step, passing.
const WALK := [0, 1, 2, 1]
const STALK := 3
const LOOK := 4
const POUNCE := 5
## How long the pounce lasts, at the end of a stalk.
const POUNCE_TIME := 0.35

var _state_was := ""
var _in_state := 0.0


func _process(delta: float) -> void:
	if state != _state_was:
		_state_was = state
		_in_state = 0.0
	_in_state += delta


func _draw() -> void:
	draw_shadow(22.0)
	var frame: int = WALK[int(steps * 7.0) % WALK.size()]
	var lift := 0.0
	match state:
		"watch":
			frame = LOOK
		"forage":
			# creeping up on a vole, a slow step at a time, then the spring
			frame = STALK
			if timer < POUNCE_TIME:
				frame = POUNCE
				lift = sin(clampf(timer / POUNCE_TIME, 0.0, 1.0) * PI) * 6.0
	WildlifeSheet.draw(self, "bobcat", frame, Vector2(0, -lift), facing)
