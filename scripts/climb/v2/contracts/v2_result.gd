class_name V2Result
extends RefCounted
## How a v2 climb went. Member names match the ClimbState fields
## Achievements, Perks and medals read (falls, aid_moves, perfect_cruxes,
## slipped_cruxes, nights_spent, minutes, route), so the cutover (thread 10)
## can hand this over in place of a ClimbState.

var route: RouteData
var success := false
## Minutes the climb took (the clock advances by this).
var minutes := 0
var falls := 0
var aid_moves := 0
## Crux zones climbed in sequence first go / not.
var perfect_cruxes := 0
var slipped_cruxes := 0
var nights_spent := 0
var pitches_done := 0
var moves := 0
var clips := 0
var back_clips := 0
## Every piece the leader placed: {gear_id, quality, grade (the partner's word)}.
var placements: Array[Dictionary] = []
var food_eaten: Array[String] = []


func to_dict() -> Dictionary:
	return {"route": route.id if route else "", "success": success, "minutes": minutes,
		"falls": falls, "aid_moves": aid_moves, "perfect_cruxes": perfect_cruxes,
		"slipped_cruxes": slipped_cruxes, "nights_spent": nights_spent,
		"pitches_done": pitches_done, "moves": moves, "clips": clips, "back_clips": back_clips,
		"placements": placements.duplicate(true), "food_eaten": food_eaten.duplicate()}


func load_dict(d: Dictionary) -> void:
	for key in ["minutes", "falls", "aid_moves", "perfect_cruxes", "slipped_cruxes",
			"nights_spent", "pitches_done", "moves", "clips", "back_clips"]:
		set(key, int(d.get(key, 0)))
	success = bool(d.get("success", false))
	placements.assign(d.get("placements", []))
	food_eaten.assign(d.get("food_eaten", []))
