class_name GearSystem
extends ClimbSystem
## Interface (thread 6, trad gear). Places cams, nuts, offsets and slings;
## owns the placement fields of the pieces it makes. A placed piece starts
## unclipped: the director then opens rope's "clip" phase for it. Supplies
## the "place" phase. Never shows a quality bar: the reading is what the
## climber sees (lobes, a seated nut), quality stays hidden.


func id() -> StringName:
	return &"gear"


## Cracks the free hand can reach to place in, nearest first (query).
func placeable() -> Array[V2Crack]:
	return []


## True if the rack verb has anything to do here: a crack in reach (the
## default), or more (an old pin to tug-test, stuck booty to work free).
## The director opens the place phase only when this is true. Pure.
func can_rack() -> bool:
	return not placeable().is_empty()


## How [param piece] was placed, in the gear's own words, for the partner's
## grading at the belay (falls reads it): e.g. {"grade": "bomber", "line":
## "...", "why": "tipped"}. {} = no opinion (falls grades by quality). Pure.
func grade_for(_piece: V2Piece) -> Dictionary:
	return {}


## What you see offering rack item [param item_id] at [param at] in crack
## [param crack_id] (query): {fits: bool, lobes: "tipped"|"sweet"|"over"|"",
## seated: bool (nuts), note: String}. The pump it costs is priced by
## effort ("offer") and spent by the place phase through the director.
func offer(_item_id: String, _crack_id: String, _at: Vector2) -> Dictionary:
	return {"fits": false, "lobes": "", "seated": false, "note": ""}


## Places it: takes the item off the rack and adds an unclipped V2Piece to
## session.pieces. Sends piece_placed. Null if it won't go.
func place(_item_id: String, _crack_id: String, _at: Vector2) -> V2Piece:
	return null
