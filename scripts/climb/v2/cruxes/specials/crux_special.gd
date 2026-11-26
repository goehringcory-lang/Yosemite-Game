class_name CruxSpecial
extends RefCounted
## One big-wall moment played in the "special" phase (thread 8): the King
## Swing, nailing pin scars, hauling the bag, a chimney or offwidth. No bars,
## no clock: at each step the special offers a few choices (the arrows pick
## one, the ghost shows what it would do, commit does it). Its state is
## plain data in [member state], kept in session notes so snapshots hold it.
##
## [method apply] returns what happened as an effect dictionary the phase
## carries out through the director:
##   cost   [pump, gas, minutes] to spend
##   say    a line for the caption (what you feel or hear)
##   step   data for the special_step event (look, sound and art react)
##   hang   Vector2: the body hangs there now (director.hang_at)
##   tags   pose tags for the hang
##   aid    aid moves to count
##   rest   a rest kind for director.rest
##   done   true when the special is over; ok = clean

var kind: StringName = &""
var spot: Dictionary = {}
var state: Dictionary = {}
## The crux system (read-only use: session, wall, rng).
var sys: CruxSystem


func setup(p_sys: CruxSystem, p_spot: Dictionary, saved := {}) -> void:
	sys = p_sys
	spot = p_spot
	if saved.is_empty():
		start()
	else:
		state = saved.duplicate(true)


## Builds [member state] for a fresh start.
func start() -> void:
	pass


## The choices right now: [{id, label, ...}]. Never empty while not done.
func options() -> Array:
	return []


## What [param option] would do, without doing it (pure): for the ghost and
## the hint. Keys are special-specific; "say" is a short description.
func preview(_option: Dictionary) -> Dictionary:
	return {}


## Does [param option]. Draws randomness only from the cruxes stream.
func apply(_option: Dictionary) -> Dictionary:
	return {"done": true, "ok": true}


## The special's name for the caption.
func title() -> String:
	return str(spot.get("name", kind))


func session() -> ClimbSession:
	return sys.session


func rng() -> RandomNumberGenerator:
	return sys.session.rng_for(&"cruxes")


static func cost(a: Array) -> Array:
	return [float(a[0]), float(a[1]), int(a[2])]


## A number from 0..1 that is always the same for [param key] on this
## pitch (for laying out scars, lips and footing without using the rng).
func noise(key: String) -> float:
	var s := sys.session
	return float(hash([s.seed, s.route_id, s.pitch, key]) & 0xffff) / 65535.0
