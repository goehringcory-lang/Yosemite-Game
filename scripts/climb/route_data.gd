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

@export_group("Destination")
## Hub to unlock and travel to at the top. Empty for climbs you walk off.
@export var destination_hub: String
## Spawn marker in that hub.
@export var destination_spawn: String
