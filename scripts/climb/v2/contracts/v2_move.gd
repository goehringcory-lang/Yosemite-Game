class_name V2Move
extends RefCounted
## A proposed move: one hand to one hold, with a hip position. Built by the
## move pipeline every time the aim changes (so building one must be pure:
## no state changes, no random draws), and committed when the player commits.
##
## Pipeline (ClimbDirector.preview): body.preview fills the geometry ->
## cruxes.constrain may mark it -> effort.price fills [member cost] ->
## falls.risk fills [member risk]. Each stage writes only its own fields.

# --- body (thread 3)
var hand: StringName = &"rh"
var hold_id := ""
var hip := Vector2.ZERO
var from: V2Pose
var to: V2Pose
## How far the hand stretches, 0 (easy) to 1 (full span). Over 1 = can't.
var reach := 0.0
## How hard the position is on the body, 0..1 (art trembles the ghost by it).
var strain := 0.0
## How well the body is held on, 0 (barn door) to 1 (locked in).
var security := 1.0
## Share of weight on each limb (lh/rh/lf/rf -> 0..1), for effort and art.
var load := {}
var valid := true
## Why it isn't valid, for the HUD: "too far", "no feet"...
var reason := ""
## dyno | lunge | match | cross | mantle | ... (body); crux tags (cruxes).
var tags := PackedStringArray()

# --- cruxes (thread 8)
## The crux zone it's in, and whether it follows the zone's sequence.
var crux_id := ""
var in_sequence := true
## What the crux beta does to this move: effort multiplies its pump and gas by
## [member crux_cost] (1 on beta, up to ~2.5 off it), and falls adds
## [member crux_risk] to its fall chance (a dyno thrown from a bad pose).
var crux_cost := 1.0
var crux_risk := 0.0

# --- effort (thread 4)
var cost := V2Cost.new()

# --- falls (thread 7)
## Chance the move fails and you fall, 0..1 (rolled at commit, once).
var risk := 0.0


func has_tag(tag: String) -> bool:
	return tags.has(tag)


func to_dict() -> Dictionary:
	return {"hand": String(hand), "hold_id": hold_id, "hip": [hip.x, hip.y],
		"from": from.to_dict() if from else {}, "to": to.to_dict() if to else {},
		"reach": reach, "strain": strain, "security": security, "load": load.duplicate(),
		"valid": valid, "reason": reason, "tags": Array(tags), "crux_id": crux_id,
		"in_sequence": in_sequence, "crux_cost": crux_cost, "crux_risk": crux_risk, "cost": cost.to_dict(), "risk": risk}
