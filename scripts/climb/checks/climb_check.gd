class_name ClimbCheck
extends RefCounted
## The rules of one of the climbing screen's longer skill checks, with no
## drawing or input, so tests can play them: the King Swing (SwingCheck),
## nailing a piton on an aid move (NailCheck), hauling the bag at a belay
## (HaulCheck) and a layback up a flake (LaybackCheck).
##
## ClimbState.make_check builds the one its pending check asks for. The screen
## feeds it the keys held each frame ([method step]) and each key pressed
## ([method press]), and once [member result] is set hands it to
## ClimbState.resolve_crux, which does what it means for the climb.

## A press this close to the middle of the green, as a share of half its
## width, is a perfect one (as on the crux meter).
const PERFECT_SHARE := 0.38

## "" until the check is decided; then "perfect", "good" or "slip", or
## "over" for an over-driven piton.
var result := ""
## Why it went the way it did, for the screen's banner and tests ("short",
## "slam", "popped", "sloppy", "barn_door"...).
var detail := ""
## Seconds left, and how many there were to begin with.
var time_left := 0.0
var time_total := 0.0
## Seconds the check has been running.
var elapsed := 0.0
## Things that happened since the screen last looked: {"type": String, ...}.
var events: Array[Dictionary] = []


## One frame. [param held] has the keys held down: "left", "right", "up" and
## "pull" (Space or E).
func step(_delta: float, _held: Dictionary) -> void:
	pass


## A key pressed: "left", "right", "up", "tool" (Space) or "interact" (E).
func press(_action: String) -> void:
	pass


func is_done() -> bool:
	return result != ""


## Takes the events the screen hasn't seen yet.
func take_events() -> Array[Dictionary]:
	var out := events.duplicate()
	events.clear()
	return out


## Where [param value] falls against a green [param window] wide around
## [param center]: "perfect" in its middle, "good" in it, "slip" outside.
static func judge(value: float, center: float, window: float) -> String:
	var off := absf(value - center)
	var half := window / 2.0
	if off <= half * PERFECT_SHARE:
		return "perfect"
	return "good" if off <= half else "slip"


func _finish(how: String, why: String) -> void:
	if result != "":
		return
	result = how
	detail = why
	events.append({"type": "done", "result": how, "detail": why})
