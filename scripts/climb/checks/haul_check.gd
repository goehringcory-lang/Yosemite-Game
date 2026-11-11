class_name HaulCheck
extends ClimbCheck
## Hauling the bag at a belay on a big wall: the bag with the water, the food
## and the portaledge hangs on its own rope below you, and you haul it up to
## the anchor before you lead on.
##
## Hold Space (or E) to pull a stroke, then let go so the ratchet holds the
## bag while your arms reset. Hanging on at the end of a stroke only strains
## you. Now and then the bag snags under a flake: pulling against it is wasted
## strength, so stop and alternate Left and Right to wiggle it free. A quick,
## clean haul saves daylight; a slow, sloppy one costs time and energy. It
## always gets there in the end: if it takes too long, your partner helps.

## A stroke goes from your arms out to your chest at this rate (a second and
## a bit each), and resets this fast once you let go.
const STROKE_SPEED := 1.6
const RESET_SPEED := 5.0
## A full stroke brings the bag up this far (its height runs 0 to 1).
const GAIN := 0.2
## Alternations of Left and Right that free a snag.
const WIGGLES := 4
## Seconds for a clean haul, a fair one, and when your partner takes over.
## The Timing assist (Settings.room()) gives you more of each.
const CLEAN_SECONDS := 7.0
const GOOD_SECONDS := 11.0
const LIMIT_SECONDS := 20.0
## Strain a second of pulling against a snag, and of hanging on at the end
## of a stroke.
const STRAIN_SNAG := 1.5
const STRAIN_END := 0.5
## Most strain for a clean haul, and for a fair one.
const CLEAN_STRAIN := 0.4
const GOOD_STRAIN := 1.5

## The bag's height, 0 (where it hung) to 1 (at the anchor).
var height := 0.0
## How far through a stroke your arms are, 0 to 1.
var stroke := 0.0
## How much strength you've wasted.
var strain := 0.0
## Where the bag snags on the way up (heights), the one it's caught on now
## (-1 if none), and the ones freed.
var snags: Array[float] = []
var snag := -1
var freed := {}
var wiggles := 0
## The side of the last wiggle: -1 left, 1 right, 0 none yet.
var last_side := 0
var pace := 1.0
var clean_seconds := CLEAN_SECONDS
var good_seconds := GOOD_SECONDS
var _was_pulling := false


## [param snag_count] snags on the way up (ClimbState.haul_snags());
## [param room] is Settings.room() and [param p_pace] Settings.pace().
func _init(snag_count: int, room := 1.0, p_pace := 1.0) -> void:
	for i in snag_count:
		snags.append((i + 1.0) / (snag_count + 1.0) + 0.05)
	clean_seconds = CLEAN_SECONDS * room
	good_seconds = GOOD_SECONDS * room
	time_total = LIMIT_SECONDS * room
	time_left = time_total
	pace = p_pace


func step(delta: float, held: Dictionary) -> void:
	if is_done():
		return
	elapsed += delta
	time_left -= delta
	var dt := delta * pace
	var pulling: bool = held.get("pull", false)
	if snag >= 0:
		if pulling:
			strain += STRAIN_SNAG * dt
		else:
			stroke = maxf(stroke - RESET_SPEED * dt, 0.0)
	elif pulling:
		if stroke >= 1.0:
			strain += STRAIN_END * dt
		else:
			var ds := minf(STROKE_SPEED * dt, 1.0 - stroke)
			stroke += ds
			var before := height
			height = minf(height + GAIN * ds, 1.0)
			for i in snags.size():
				if not freed.has(i) and before < snags[i] and height >= snags[i]:
					height = snags[i]
					snag = i
					wiggles = 0
					last_side = 0
					events.append({"type": "snag"})
					break
			if height >= 1.0:
				_finish_haul()
				return
	else:
		if _was_pulling and stroke > 0.0:
			# The ratchet clicks over as you let go: the bag stays put.
			events.append({"type": "stroke"})
		stroke = maxf(stroke - RESET_SPEED * dt, 0.0)
	_was_pulling = pulling
	if time_left <= 0.0:
		_finish("slip", "partner")


func press(action: String) -> void:
	if is_done() or snag < 0 or not action in ["left", "right"]:
		return
	var side := -1 if action == "left" else 1
	if side == last_side:
		return
	last_side = side
	wiggles += 1
	events.append({"type": "wiggle", "side": side})
	if wiggles >= WIGGLES:
		freed[snag] = true
		snag = -1
		events.append({"type": "free"})


## The side to wiggle next: the other one from last time.
func next_side() -> String:
	return "left" if last_side >= 0 else "right"


func _finish_haul() -> void:
	if elapsed <= clean_seconds and strain < CLEAN_STRAIN:
		_finish("perfect", "clean")
	elif elapsed <= good_seconds and strain < GOOD_STRAIN:
		_finish("good", "hauled")
	else:
		_finish("slip", "sloppy")
