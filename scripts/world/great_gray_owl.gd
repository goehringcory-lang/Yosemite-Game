class_name GreatGrayOwl
extends Wanderer
## A great gray owl (Owls). Wandering or leaving, it glides low over the
## grass with slow beats of its broad wings (seen from above); foraging, it
## has dropped onto a vole and sits in the grass, turning its face about to
## listen; watching, it looks at you. Painted on WildlifeSheet.

const SIT := 0
const LISTEN := 1
const WINGS_UP := 2
const WINGS_DOWN := 3
const PLUNGE := 4
## How high it flies over the grass.
const FLY_HEIGHT := 12.0
## How long the drop onto a vole shows.
const PLUNGE_TIME := 0.5

var _state_was := ""
var _in_state := 0.0


func _process(delta: float) -> void:
	if state != _state_was:
		_state_was = state
		_in_state = 0.0
	_in_state += delta


func flying() -> bool:
	return state == "wander" or state == "leave"


func _draw() -> void:
	if flying():
		# a soft shadow on the grass under it, the owl a little above
		draw_rect(Rect2(-9, -3, 18, 3), Color(0, 0, 0, 0.12))
		var frame := WINGS_UP if int(age * 2.2) % 2 == 0 else WINGS_DOWN
		WildlifeSheet.draw(self, "great_gray_owl", frame, Vector2(0, -FLY_HEIGHT + 16.0), facing)
		return
	draw_shadow(14.0)
	var frame := SIT
	if state == "forage":
		if _in_state < PLUNGE_TIME:
			frame = PLUNGE
		elif fmod(_in_state, 2.4) > 1.2:
			frame = LISTEN
	WildlifeSheet.draw(self, "great_gray_owl", frame, Vector2.ZERO, facing)
