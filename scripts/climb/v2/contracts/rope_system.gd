class_name RopeSystem
extends ClimbSystem
## Interface (thread 5, rope and clipping). Owns session.rope and the clip
## fields of pieces. Every clip goes through rope, bolts and placed gear the
## same way (gear places a piece unclipped, then the director opens the
## "clip" phase for it). Supplies the "clip" phase.


func id() -> StringName:
	return &"rope"


## Unclipped pieces you could clip from here, nearest first (query).
func clippable() -> Array[V2Piece]:
	return []


## Arm-lengths of rope you'd pull up to clip [param piece_id] (query).
func arms_needed(_piece_id: String) -> int:
	return 1


## Starts clipping [param piece_id] (takes a draw or sling from the rack).
func start_clip(_piece_id: String) -> bool:
	return false


## Pulls one arm-length. True once there's enough rope to clip.
func pull() -> bool:
	return false


## Clips the rope in. Sends clipped (or back-clipped). False if you can't yet.
func clip() -> bool:
	return false


## Drops the rope you pulled (slack stays out until you clip or climb).
func cancel_clip() -> void:
	pass


## The fall from [param from_pos] as rope sees it: fills the geometry fields
## of a V2Fall (chain, slack, length). Pure. Falls fills in the rest.
func fall_geometry(from_pos: Vector2) -> V2Fall:
	var f := V2Fall.new()
	f.from_pos = from_pos
	f.length_m = from_pos.y * 2.0
	return f


## How far a fall from [param from_pos] drops if [param piece_id] catches
## it ("" = the belay): twice the height above it, plus slack and stretch.
## Pure. Falls uses it when pieces above pop.
func drop_to(from_pos: Vector2, piece_id: String) -> float:
	var p := session.piece(piece_id) if piece_id != "" else null
	var below := p.pos.y if p else 0.0
	return maxf(0.0, (from_pos.y - below) * 2.0) + session.rope.slack_m


## Unclips a piece that pulled out in a fall (the director calls this).
func remove(_piece_id: String) -> void:
	pass


## The pitch is over: the rope is pulled through to the new belay.
func reset_for_pitch() -> void:
	session.rope = V2Rope.new()
