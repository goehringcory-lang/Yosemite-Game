class_name ClipCheck
extends ClimbCheck
## Clipping a bolt from a bad hold: one hand on a crimp (or pumped), the other
## pulls up a bight of rope and snaps it into the quickdraw.
##
## The bight swings up toward the draw's gate and back down (the marker).
## Press Space, Up or E as it reaches the gate (the green) to clip. Miss and
## you fumble: the rope drops, and you can try again from where you hang. Off
## a jug or an edge you clip without thinking; this only comes up when it's
## hard.

const WINDOW := 0.24
const CENTER := 0.78
const MAX_WINDOW := 0.5
## The bight comes up and drops back this many bar lengths a second.
const SPEED := 1.1

## Where the bight of rope is, 0 (at your harness) to 1 (past the gate).
var pos := 0.0
var dir := 1.0
var speed := SPEED
var window := WINDOW


## [param grip_seconds] is how long your hold lets you hang there.
func _init(grip_seconds: float, pace := 1.0, room := 1.0) -> void:
	time_total = grip_seconds
	time_left = grip_seconds
	speed = SPEED * pace
	window = minf(WINDOW * room, MAX_WINDOW)


func step(delta: float, _held: Dictionary) -> void:
	if is_done():
		return
	elapsed += delta
	time_left -= delta
	pos += dir * speed * delta
	if pos >= 1.0:
		pos = 1.0
		dir = -1.0
	elif pos <= 0.0:
		pos = 0.0
		dir = 1.0
	if time_left <= 0.0:
		_finish("slip", "grip")


func press(action: String) -> void:
	if is_done() or not action in ["tool", "up", "interact"]:
		return
	var how := judge(pos, CENTER, window)
	events.append({"type": "clip_try", "result": how})
	_finish(how, "clipped" if how != "slip" else "fumble")
