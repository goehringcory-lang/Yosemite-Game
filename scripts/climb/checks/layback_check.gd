class_name LaybackCheck
extends ClimbCheck
## A layback up a flake: hands pulling on the edge of the flake, feet pressed
## flat against the wall, the two pushing against each other. Pull too little
## and your feet skate off and you swing out like a door on its hinges (a
## barn door); pull too hard and your forearms burn out.
##
## Hold Space (or E) to pull: the tension rises while you hold and eases off
## when you let go. Tap Up to walk your feet up a step. A step only holds with
## the tension in the green; each one eases the tension a little, and the
## green creeps up as the flake steepens. Over-gripping (above the green)
## fills the strain bar, and a full bar pumps you off. Six steps get you up
## it; get there with little strain for a perfect.

## Tension rises this fast while you pull and falls this fast when you don't
## (its range is 0 to 1).
const RISE := 0.9
const FALL := 1.3
## The green starts at this tension, and creeps up this much each step.
const BAND_FROM := 0.42
const BAND_CLIMB := 0.03
## A step eases the tension this much.
const STEP_DROP := 0.15
## The green's width in tension for each 1.0 of the crux window, and its widest.
const WINDOW_SCALE := 1.1
const MAX_WINDOW := 0.4
## Strain a second of over-gripping, and recovered a second otherwise.
const STRAIN_RATE := 0.8
const STRAIN_RECOVER := 0.12
## A step taken over-gripping jars you this much more.
const STEP_STRAIN := 0.15
## Steps to the top of the flake.
const NEED := 6
## Most strain left at the top for a perfect.
const PERFECT_STRAIN := 0.3
## Out of time with this share of the steps done, you scrape up it.
const SCRAPE_SHARE := 0.6

var tension := 0.0
var strain := 0.0
var steps := 0
## The green's width, in tension.
var window := 0.22
var pace := 1.0


## [param crux_window] is ClimbState.crux_window(); [param seconds] the time
## you get; [param p_pace] Settings.pace() (it slows the tension down).
func _init(crux_window: float, seconds: float, p_pace := 1.0) -> void:
	window = minf(crux_window * WINDOW_SCALE, MAX_WINDOW)
	time_total = seconds
	time_left = seconds
	pace = p_pace


func step(delta: float, held: Dictionary) -> void:
	if is_done():
		return
	elapsed += delta
	# The clock runs at the check's pace, so the Timing assist that slows the
	# tension down never leaves you less time for it.
	time_left -= delta * pace
	var dt := delta * pace
	if held.get("pull", false):
		tension = minf(tension + RISE * dt, 1.0)
	else:
		tension = maxf(tension - FALL * dt, 0.0)
	if tension > band_to():
		strain += STRAIN_RATE * dt
	else:
		strain = maxf(strain - STRAIN_RECOVER * dt, 0.0)
	if strain >= 1.0:
		_finish("slip", "pumped")
	elif time_left <= 0.0:
		_finish("good" if steps >= NEED * SCRAPE_SHARE else "slip", "scraped" if steps >= NEED * SCRAPE_SHARE else "time")


func press(action: String) -> void:
	if is_done() or action != "up":
		return
	step_up()


## Walks your feet up a step: it holds with the tension in the green or above.
func step_up() -> void:
	if is_done():
		return
	if tension < band_from():
		_finish("slip", "barn_door")
		return
	if tension > band_to():
		strain += STEP_STRAIN
	steps += 1
	tension = maxf(tension - STEP_DROP, 0.0)
	events.append({"type": "step", "steps": steps})
	if strain >= 1.0:
		_finish("slip", "pumped")
	elif steps >= NEED:
		_finish("perfect" if strain < PERFECT_STRAIN else "good", "sent")


## True with the tension in the green, where a step holds cleanly.
func in_band() -> bool:
	return tension >= band_from() and tension <= band_to()


func band_from() -> float:
	return BAND_FROM + BAND_CLIMB * steps


func band_to() -> float:
	return band_from() + window
