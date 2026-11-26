class_name CruxSystem
extends ClimbSystem
## Interface (thread 8, cruxes and big-wall moments). A crux is wall data (a
## "crux" V2Zone whose data holds the sequence) plus [method constrain] on
## the normal move pipeline: no separate move logic. Specials (King Swing,
## nailing, hauling, chimneys, offwidths) are the "special" phase.


func id() -> StringName:
	return &"cruxes"


## The crux zone at [param pos], or null.
func zone_at(pos: Vector2) -> V2Zone:
	var zones := session.wall.zones_at(pos, &"crux")
	return zones[0] if not zones.is_empty() else null


## Marks the crux fields of [param move] (crux_id, in_sequence, tags) and may
## make it invalid. Pure: writes only to the move.
func constrain(_move: V2Move) -> void:
	pass


## A move was committed: track the sequence, send crux_entered/crux_sent.
func committed(_move: V2Move) -> void:
	pass


## A special that runs at the belay once the pitch is led ("" for none), e.g.
## "haul". The director opens the special phase with {"kind", "belay": true}
## instead of the belay; that phase calls director.go(&"belay") when done.
func belay_special() -> StringName:
	return &""


## A special move that starts here ("" for none): swing, nail, haul,
## chimney, offwidth.
func special_at(_pos: Vector2) -> StringName:
	return &""
