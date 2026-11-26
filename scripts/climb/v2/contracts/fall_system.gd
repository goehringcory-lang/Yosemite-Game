class_name FallSystem
extends ClimbSystem
## Interface (thread 7, falls and the partner). Judges risk, decides what a
## fall does (which pieces pop, how far, where you settle), and runs the
## belay: the partner cleans and grades your gear. Supplies the "fall" and
## "belay" phases. Rope works out fall geometry; falls never recomputes it.


func id() -> StringName:
	return &"falls"


## Fills move.risk, the chance the move fails, including move.crux_risk (pure).
func risk(move: V2Move) -> void:
	move.risk = 0.0


## Rolls whether [param move] fails, once, at commit.
func falls_now(move: V2Move) -> bool:
	return move.risk > 0.0 and session.rng_for(id()).randf() < move.risk


## Fills the outcome of [param fall] (geometry already set by rope): pops,
## drop, swing, landing, settle_pos, cost, partner line. Marks popped and
## loaded on pieces.
func resolve(fall: V2Fall) -> V2Fall:
	fall.drop_m = fall.length_m
	fall.settle_pos = fall.from_pos - Vector2(0, fall.length_m)
	return fall


## At the belay: the partner follows, cleans every placed piece back onto the
## rack and grades it. Returns [{piece_id, gear_id, grade, line}].
func clean_pitch() -> Array[Dictionary]:
	return []
