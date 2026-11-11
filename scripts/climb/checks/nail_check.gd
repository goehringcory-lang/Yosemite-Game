class_name NailCheck
extends ClimbCheck
## Nailing a piton on an aid move, the way Salathé and Harding climbed the
## walls: drive a pin into the crack, clip your aiders to it and stand up.
##
## The hammer swings back and forth (the gold marker); press Space to strike.
## The higher the swing when you strike, the harder the blow. Each blow drives
## the pin deeper, and it rings higher as it seats. When it's in the green,
## step onto it (Up or E). Dead in the middle of the green is a perfect
## placement, and the move goes quickly. Drive it past the green and it's
## over-driven: it holds, but you'll fight to clean it. Step onto it short of
## the green and it pops out. Run out of time and you step on whatever you've
## got.

## The green starts this deep (the pin's depth runs 0 to 1).
const SEAT_FROM := 0.55
## A blow at the bottom of the swing drives the pin this far, and at the top
## this far.
const DRIVE_MIN := 0.05
const DRIVE_MAX := 0.3
## The green's width can't be more than this, so it stays on the bar.
const MAX_WINDOW := 0.4

## How deep the pin is, 0 (just started) to 1 (all the way in).
var depth := 0.0
## Where the hammer is in its swing, 0 (low) to 1 (high), and which way it's going.
var swing := 0.0
var swing_dir := 1.0
## Hammer swings a second (bar lengths, like the crux meter's marker).
var swing_speed := 1.0
## The green's width, in depth.
var window := 0.2
var strikes := 0


## [param p_window] is ClimbState.nail_window(); [param seconds] the time you
## get; [param p_swing_speed] how fast the hammer swings (Settings.pace() is
## already in it).
func _init(p_window: float, seconds: float, p_swing_speed := 1.0) -> void:
	window = clampf(p_window, 0.05, MAX_WINDOW)
	time_total = seconds
	time_left = seconds
	swing_speed = p_swing_speed


func step(delta: float, _held: Dictionary) -> void:
	if is_done():
		return
	elapsed += delta
	time_left -= delta
	swing += swing_dir * swing_speed * delta
	if swing >= 1.0:
		swing = 1.0
		swing_dir = -1.0
	elif swing <= 0.0:
		swing = 0.0
		swing_dir = 1.0
	if time_left <= 0.0:
		_weight()


func press(action: String) -> void:
	if is_done():
		return
	if action == "tool":
		strike()
	elif action in ["up", "interact"]:
		_weight()


## One blow of the hammer, as hard as the swing is high.
func strike() -> void:
	if is_done():
		return
	strikes += 1
	depth = minf(depth + drive(swing), 1.0)
	events.append({"type": "strike", "depth": depth, "power": swing})
	if depth > seat_to():
		_finish("over", "over")


## How far a blow with the hammer at [param at] drives the pin.
static func drive(at: float) -> float:
	return lerpf(DRIVE_MIN, DRIVE_MAX, clampf(at, 0.0, 1.0))


func seat_from() -> float:
	return SEAT_FROM


func seat_to() -> float:
	return SEAT_FROM + window


func center() -> float:
	return SEAT_FROM + window / 2.0


## Steps onto the pin. Before the first blow there's nothing to stand on yet,
## so Up does nothing.
func _weight() -> void:
	if is_done():
		return
	if strikes == 0 and time_left > 0.0:
		return
	var how := judge(depth, center(), window)
	_finish(how, "popped" if how == "slip" else "seated")
