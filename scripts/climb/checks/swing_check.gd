class_name SwingCheck
extends ClimbCheck
## The King Swing on the Nose and the Pendulum on Royal Arches: lowered out on
## the rope, you run back and forth across the face and swing like a
## pendulum, a little wider each time, until you can grab the crack off to the
## right at the top of a swing.
##
## Hold Left or Right to run. Running the way you're swinging pumps the swing
## up; running against it brakes. Press Space (or E, or Up) to grab. Grab with
## the crack in reach (the green) and you're across; grab right at the top of
## the swing, dead on the crack, for a perfect. Grab short of it and you miss;
## keep pumping past it and you slam into the corner beyond. Run out of time
## and your legs are gone.

## The pendulum's natural rate in radians a second: a swing out and back in
## about 2.2 seconds.
const OMEGA := 2.86
## How fast the swing dies away when you stop running.
const DAMPING := 0.25
## What running adds, in radians a second squared.
const RUN := 1.2
## The crack, in radians out from hanging straight down, to the right.
const TARGET := 0.95
## Swing this far out, either way, and you slam into the corner.
const SLAM := 1.4
## The green's width in radians for each 1.0 of the crux window.
const WINDOW_SCALE := 1.2
## The widest the green gets, so it never reaches the corner.
const MAX_WINDOW := 0.5
## In the wind, gusts push the rope about this hard.
const GUST := 0.6
## Physics steps no longer than this, so the swing stays smooth at any frame rate.
const SUBSTEP := 0.01

## Radians out from straight down (right is positive), and how fast it changes.
var angle := 0.0
var speed := 0.0
## The green, in radians, centered on [constant TARGET].
var window := 0.24
var pace := 1.0
var windy := false
## Swings started so far (each time you pass the bottom), for the HUD and sound.
var swings := 0


## [param crux_window] is ClimbState.crux_window(); [param seconds] the time
## you get; [param p_pace] Settings.pace() (it slows the swing down).
func _init(crux_window: float, seconds: float, p_pace := 1.0, p_windy := false) -> void:
	window = minf(crux_window * WINDOW_SCALE, MAX_WINDOW)
	time_total = seconds
	time_left = seconds
	pace = p_pace
	windy = p_windy


func step(delta: float, held: Dictionary) -> void:
	if is_done():
		return
	elapsed += delta
	# The clock runs at the check's pace, so the Timing assist that slows the
	# swing down never leaves you less time for it.
	time_left -= delta * pace
	var push := (1.0 if held.get("right", false) else 0.0) - (1.0 if held.get("left", false) else 0.0)
	var gust := GUST * sin(elapsed * 1.7) * sin(elapsed * 0.6 + 1.0) if windy else 0.0
	var dt := delta * pace
	var n := maxi(1, ceili(dt / SUBSTEP))
	var h := dt / n
	for i in n:
		var before := angle
		speed += (-OMEGA * OMEGA * sin(angle) - DAMPING * speed + RUN * push + gust) * h
		angle += speed * h
		if signf(before) != signf(angle) and before != 0.0:
			swings += 1
			events.append({"type": "swish", "speed": absf(speed)})
	if absf(angle) >= SLAM:
		_finish("slip", "slam")
	elif time_left <= 0.0:
		_finish("slip", "time")


func press(action: String) -> void:
	if is_done() or not action in ["tool", "interact", "up"]:
		return
	var how := judge(angle, TARGET, window)
	if how == "slip":
		_finish("slip", "short" if angle < TARGET else "past")
	else:
		_finish(how, "grabbed")


## How far out this swing will go, in radians, if you stop running now: the
## height its energy would carry it to.
func amplitude() -> float:
	var energy := 0.5 * speed * speed + OMEGA * OMEGA * (1.0 - cos(angle))
	return acos(clampf(1.0 - energy / (OMEGA * OMEGA), -1.0, 1.0))


## The green's edges, in radians.
func green_from() -> float:
	return TARGET - window / 2.0


func green_to() -> float:
	return TARGET + window / 2.0
