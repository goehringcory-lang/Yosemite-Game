class_name V2Fall
extends RefCounted
## A fall. Rope (thread 5) works out the geometry ([method RopeSystem.fall_geometry]:
## the first block of fields); falls (thread 7) decides what happens (the
## second block). Art and look play it back; they never change it.

# --- rope: geometry
## Where the climber came off.
var from_pos := Vector2.ZERO
## Clipped pieces the fall loads, top first.
var chain := PackedStringArray()
## Slack out when it happened, metres.
var slack_m := 0.0
## How far you'd drop if the top piece holds (twice the height above it,
## plus slack and stretch).
var length_m := 0.0

# --- falls: outcome
## Pieces that pulled out (at most two on story routes), top first.
var popped := PackedStringArray()
## The piece that caught you ("" = the belay).
var caught_by := ""
## How far you dropped after any pops, metres.
var drop_m := 0.0
## Sideways swing (a traverse above the piece), metres.
var swing_m := 0.0
## "" (hung on the rope), "ledge" (hit something), "ground" (non-story only).
var lands_on: StringName = &""
## Where you end up hanging.
var settle_pos := Vector2.ZERO
var cost := V2Cost.new()
## What the partner says.
var partner_line := ""


func to_dict() -> Dictionary:
	return {"from_pos": [from_pos.x, from_pos.y], "chain": Array(chain), "slack_m": slack_m,
		"length_m": length_m, "popped": Array(popped), "caught_by": caught_by, "drop_m": drop_m,
		"swing_m": swing_m, "lands_on": String(lands_on), "settle_pos": [settle_pos.x, settle_pos.y],
		"cost": cost.to_dict(), "partner_line": partner_line}
