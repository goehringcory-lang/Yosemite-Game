class_name ClimbReach
extends RefCounted
## One move on the climbing screen: hold a direction and a hand reaches for
## the hold; let go and it grabs. How well it lands depends on when you let
## go, and the hold decides how much that matters.
##
## A reach runs from 0 (the hand leaves) to 1 (the hand is on the hold) over
## [member duration] seconds. Let go inside the good band and the move is
## "good"; inside its small middle (the sweet spot) it's "perfect"; early or
## late, the hand slaps on "sloppy" (the move still happens). Hold on far
## past the hold and the hand grabs late by itself.
##
## The bands come from the hand technique (ClimbState.technique_at):
## - a jug catches anything from a tap to a slow reach (a tap is good);
## - an edge asks for a little care, a crimp for a lot;
## - a hand jam has a sweet spot where the hand sets in the crack;
## - a sloper only takes a late, deliberate hand.
## Alternating hands (clean) widens the bands, moving the same hand twice
## (a bump) narrows them, and pump narrows them and makes the hand shake.
## The Activity timing assist widens them (Settings.room) and slows the
## reach (Settings.pace), the same as every other check in the game.
##
## Like ClimbCheck, this holds no drawing and no input: the screen feeds it
## time and the release, and ClimbHud draws it.

## Per technique: seconds for the hand to reach the hold, where the sweet
## spot is (fraction of the reach), the good band's half-width, and the
## perfect band's half-width.
## Each feels different in the hand: a jug is a quick grab, a crimp snappy,
## an edge steady, a jam a slower twist-and-set, a sloper a slow press.
const TECHNIQUES := {
	"jug": {"duration": 0.25, "center": 0.85, "good": 0.85, "perfect": 0.2},
	"edge": {"duration": 0.40, "center": 0.9, "good": 0.42, "perfect": 0.12},
	"crimp": {"duration": 0.30, "center": 0.9, "good": 0.3, "perfect": 0.15},
	"jam": {"duration": 0.55, "center": 0.9, "good": 0.32, "perfect": 0.1},
	"sloper": {"duration": 0.62, "center": 0.95, "good": 0.22, "perfect": 0.08},
}
const CLEAN_BONUS := 1.15
const BUMP_PENALTY := 0.8
## Each point of pump takes this much off the good band, never more than
## PUMP_NARROW_MAX in all; it leaves the sweet spot alone, so pump can't
## spiral (sloppy grabs pump you, and pump makes grabs sloppy).
const PUMP_NARROW := 0.04
const PUMP_NARROW_MAX := 0.2
## Whatever narrows them, the bands are never under these, in seconds either
## side of the sweet spot: a key-up a frame or two late still counts.
const MIN_PERFECT_SECONDS := 0.045
const MIN_GOOD_SECONDS := 0.08
## Let go before this much of the reach on anything but a jug and the hand
## comes back: a slip of the finger, not a sloppy grab.
const CANCEL_BEFORE := 0.15
## Past the good band by this much, the hand grabs on its own (sloppy).
const OVERREACH := 0.35

var dx := 0
var hand := "match"
var technique := "edge"
var sequence := "clean"
var pump := 0
var duration := 0.38
var center := 0.9
var good := 0.4
var perfect := 0.09
## Seconds held so far.
var held := 0.0
var result := ""


func _init(p_dx: int, p_technique: String, p_sequence: String, p_pump := 0, room := 1.0, pace := 1.0) -> void:
	dx = p_dx
	hand = ClimbState.hand_for(dx)
	technique = p_technique if TECHNIQUES.has(p_technique) else "edge"
	sequence = p_sequence
	pump = p_pump
	var t: Dictionary = TECHNIQUES[technique]
	duration = float(t.duration) / maxf(pace, 0.1)
	center = float(t.center)
	var scale := room
	if sequence == "clean":
		scale *= CLEAN_BONUS
	elif sequence == "bump":
		scale *= BUMP_PENALTY
	good = maxf(float(t.good) * scale * (1.0 - minf(PUMP_NARROW * pump, PUMP_NARROW_MAX)), MIN_GOOD_SECONDS / duration)
	perfect = minf(maxf(float(t.perfect) * scale, MIN_PERFECT_SECONDS / duration), good)
	# A jug always takes a tap.
	if technique == "jug":
		good = maxf(good, center)


## 0 when the hand leaves, 1 when it's on the hold, and past 1 when you
## hang on too long.
func progress() -> float:
	return held / duration


func done() -> bool:
	return result != ""


## Moves the reach on. Returns true when it grabbed by itself (held too long).
func update(delta: float) -> bool:
	if done():
		return false
	held += delta
	if progress() > center + good + OVERREACH:
		result = "sloppy"
		return true
	return false


## Lets go: the hand grabs. Returns "perfect", "good" or "sloppy", or
## "cancel" when the hand had barely left (not on a jug: a tap takes a jug).
func release() -> String:
	if not done():
		if technique != "jug" and progress() < CANCEL_BEFORE:
			result = "cancel"
		else:
			result = grade(progress())
	return result


## What letting go at [param p] (a fraction of the reach) gives.
func grade(p: float) -> String:
	var off := absf(p - center)
	if off <= perfect:
		return "perfect"
	if off <= good:
		return "good"
	return "sloppy"


## The good band and the sweet spot as [from, to] fractions of the reach,
## for the drawing.
func good_band() -> Vector2:
	return Vector2(maxf(center - good, 0.0), center + good)


func perfect_band() -> Vector2:
	return Vector2(maxf(center - perfect, 0.0), center + perfect)


## How much the hand shakes (0..1): pump, and more on a bump.
func tremble() -> float:
	var t := clampf((pump - 2) / 4.0, 0.0, 1.0)
	if sequence == "bump":
		t = maxf(t, 0.25)
	return t
