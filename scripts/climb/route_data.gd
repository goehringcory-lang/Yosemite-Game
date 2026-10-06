class_name RouteData
extends Resource
## A real climbing route. Its gear requirements gate where the player can go,
## and finishing it can take them to a new part of the park.

@export var id: String
@export var display_name: String
## Shown to the player, for example "5.9 slab".
@export var grade: String
@export_multiline var description: String
## Who first climbed it and when, if known.
@export var first_ascent: String
## Gear id -> count needed to start.
@export var required_gear: Dictionary = {}

@export_group("Guidebook")
## The guidebook section this route is listed under, for example "Curry Village".
@export var guide_chapter := ""
## Where it falls in the guidebook, lowest first.
@export var guide_order := 100
## A line of beta shown beside the route in the tick list.
@export var guide_tip := ""

@export_group("Climb")
## Difficulty of each pitch, 1 (easy) to 5 (very hard). One entry per pitch.
@export var pitches: Array[int] = [1]
## Moves from one belay ledge to the next.
@export var moves_per_pitch := 8
## Nights spent on the wall. Each night the climber needs a real meal.
@export var nights := 0
## Top-roped practice: someone belays from above, so falls are always safe
## and no cams are needed.
@export var top_rope := false
## How a leader protects the route: "cams" in cracks, or "bolts" already in
## the rock, which take a quickdraw each. A bolted pitch has one bolt every
## [constant ClimbState.BOLT_SPACING] moves, so it needs that many draws.
@export_enum("cams", "bolts") var protection := "cams"
## Height of the whole climb in feet, for the climbing screen's altimeter.
## 0 guesses 150 feet a pitch.
@export var height_ft := 0

@export_group("Partner")
## A quest whose giver is your partner on this route: they bring the rope and
## belay. The route can only be started while that quest is underway or done.
@export var partner_quest := ""

@export_group("Destination")
## Hub to unlock and travel to at the top. Empty for climbs you walk off.
@export var destination_hub: String
## Spawn marker in that hub.
@export var destination_spawn: String


## The climb's height in feet (see [member height_ft]).
func total_height_ft() -> int:
	return height_ft if height_ft > 0 else pitches.size() * 150
