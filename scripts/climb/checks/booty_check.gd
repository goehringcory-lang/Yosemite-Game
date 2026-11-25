class_name BootyCheck
extends ClimbCheck
## Working a stuck piece out of a crack: booty. Somebody walked a cam deep
## into the rock, or set a nut so hard they had to leave it, and it's yours if
## you can get it out.
##
## The nut tool rocks back and forth across the bar (the marker). Press Space
## (or E) as it crosses the green to knock the piece a little looser; three
## good knocks and it comes free. A knock outside the green jars your hand and
## costs a moment. All the while you're hanging on, so the time is your grip.

const NEED := 3
const WINDOW := 0.22
const MAX_WINDOW := 0.45
const SPEED := 1.0
## Seconds a knock outside the green costs.
const MISS_COST := 0.8

var pos := 0.0
var dir := 1.0
var speed := SPEED
var window := WINDOW
## Where the green sits; it moves after each good knock (the piece shifts).
var center := 0.5
var knocks := 0
var misses := 0
var _rng := RandomNumberGenerator.new()


func _init(grip_seconds: float, pace := 1.0, room := 1.0, seed := 0) -> void:
	time_total = grip_seconds
	time_left = grip_seconds
	speed = SPEED * pace
	window = minf(WINDOW * room, MAX_WINDOW)
	_rng.seed = seed
	center = _rng.randf_range(0.3, 0.7)


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
	if is_done() or not action in ["tool", "interact", "up"]:
		return
	if judge(pos, center, window) == "slip":
		misses += 1
		time_left -= MISS_COST
		events.append({"type": "knock", "good": false})
		return
	knocks += 1
	events.append({"type": "knock", "good": true, "knocks": knocks})
	if knocks >= NEED:
		_finish("perfect" if misses == 0 else "good", "free")
		return
	center = clampf(center + _rng.randf_range(-0.3, 0.3), 0.2, 0.8)
