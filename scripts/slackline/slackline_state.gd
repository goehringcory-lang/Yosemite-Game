class_name SlacklineState
extends RefCounted
## The rules of the Camp 4 slackline, apart from its drawing so tests can walk
## it. You walk on by yourself; the line tips you one way or the other, and the
## arrow keys lean you back. Lean too far and you step off.
##
## Balance works like an upside-down pendulum: the further you lean, the faster
## you tip ([member TIP]), the line damps a little of it ([member DAMP]), and
## your arms push back ([member PUSH]). Every so often the line bucks under
## you, harder toward the middle where it sags most.

enum Status { WALKING, FELL, WALKED }

## How fast a lean grows on its own.
const TIP := 2.4
const DAMP := 1.6
## How hard holding an arrow key pushes you back upright.
const PUSH := 4.5
## Seconds to walk the whole line at a steady pace.
const WALK_TIME := 22.0
## Past this lean you stop to steady yourself instead of stepping on.
const STEADY_LEAN := 0.55
## The line bucks every BUCK_GAP seconds or so, by up to BUCK_KICK.
const BUCK_GAP := Vector2(0.7, 1.8)
const BUCK_KICK := Vector2(0.35, 1.3)
## The first steps off the tree are calm, so you can find your feet.
const CALM_START := 0.06

var status := Status.WALKING
## -1 (all the way left, falling) to 1 (all the way right, falling).
var lean := 0.0
var lean_speed := 0.0
## 0 at the first tree, 1 at the far one.
var progress := 0.0
var time := 0.0
## The side you fell to: -1 left, 1 right (0 while you're on the line).
var fell_to := 0
var _next_buck := 1.0
var _rng := RandomNumberGenerator.new()


func _init(seed := -1) -> void:
	if seed >= 0:
		_rng.seed = seed
	else:
		_rng.randomize()
	_next_buck = _rng.randf_range(BUCK_GAP.x, BUCK_GAP.y)
	# never perfectly upright, or there'd be nothing to catch at first
	lean = _rng.randf_range(0.04, 0.08) * (1.0 if _rng.randf() < 0.5 else -1.0)


## How much the line sags and bounces where you stand: 0 at the trees, 1 in
## the middle.
func sag() -> float:
	return sin(progress * PI)


## Moves time on by [param delta] seconds. [param push] is the player's input:
## -1 holding left, 1 holding right, 0 neither (or both).
func step(delta: float, push: float) -> void:
	if status != Status.WALKING:
		return
	time += delta
	if progress > CALM_START:
		_next_buck -= delta
		if _next_buck <= 0.0:
			_next_buck = _rng.randf_range(BUCK_GAP.x, BUCK_GAP.y) * (1.0 - 0.3 * sag())
			var kick := _rng.randf_range(BUCK_KICK.x, BUCK_KICK.y) * (0.45 + 0.55 * sag())
			# the line mostly throws you further the way you're already going
			var side := signf(lean) if _rng.randf() < 0.65 and lean != 0.0 else (1.0 if _rng.randf() < 0.5 else -1.0)
			lean_speed += kick * side
	# a constant small shiver, more in the middle
	lean_speed += _rng.randf_range(-1.0, 1.0) * 0.6 * delta * (0.5 + sag())
	var accel := TIP * lean - DAMP * lean_speed + PUSH * clampf(push, -1.0, 1.0)
	lean_speed += accel * delta
	lean += lean_speed * delta
	if absf(lean) >= 1.0:
		lean = signf(lean)
		fell_to = int(signf(lean))
		status = Status.FELL
		return
	if absf(lean) < STEADY_LEAN:
		progress = minf(1.0, progress + delta / WALK_TIME)
	if progress >= 1.0:
		status = Status.WALKED


## How far along you got, as a whole percent.
func percent() -> int:
	return int(floor(progress * 100.0))
