class_name ShuttleStop
extends StaticBody2D
## A stop on the free Yosemite Valley shuttle. Interact to ride to any other
## stop. A ride takes a few minutes of game time.

## Every stop on the loop, in the order the real Valleywide shuttle runs
## (the NPS shuttle map numbers them 1 to 19; the numbers are in the
## comments): its name, and the region and spawn point it drops you at.
## The Lamon Homestead stop is the game's own, for your camp. Degnan's and
## the Museum (4 and 5) share the Village stop here, and Curry Village has
## one stop for both directions (14 and 19).
const STOPS := [
	{"name": "Yosemite Village", "region": "yosemite_village", "spawn": "shuttle_village"}, # 1-2
	{"name": "The Ahwahnee", "region": "the_ahwahnee", "spawn": "entrance_circle"}, # 3
	{"name": "Lower Yosemite Fall", "region": "yosemite_village", "spawn": "shuttle_lower_fall"}, # 6
	{"name": "Camp 4", "region": "yosemite_village", "spawn": "shuttle_camp_4"}, # 7, Yosemite Valley Lodge & Camp 4
	{"name": "El Capitan Picnic Area", "region": "leidig_meadow", "spawn": "shuttle"}, # 8
	{"name": "El Capitan Meadow", "region": "el_capitan_meadow", "spawn": "shuttle"}, # 9
	{"name": "Cathedral Beach", "region": "bridalveil_fall", "spawn": "shuttle"}, # 10
	{"name": "Four Mile Trailhead", "region": "four_mile_trailhead", "spawn": "shuttle"}, # 11
	{"name": "Housekeeping Camp", "region": "housekeeping_camp", "spawn": "shuttle"}, # 12
	{"name": "Lamon Homestead (Curry orchard)", "region": "lamon_homestead", "spawn": "shuttle"},
	{"name": "Curry Village", "region": "curry_village", "spawn": "shuttle"}, # 14
	{"name": "Upper Pines Campground", "region": "upper_pines", "spawn": "shuttle"}, # 15
	{"name": "Happy Isles", "region": "happy_isles", "spawn": "shuttle"}, # 16
	{"name": "Mirror Lake Trailhead", "region": "mirror_lake", "spawn": "shuttle"}, # 17
	{"name": "Lower Pines Campground", "region": "upper_pines", "spawn": "shuttle_lower_pines"}, # 18
]
const RIDE_MINUTES := 15

## This stop's name in STOPS, so it isn't offered as a destination.
@export var stop_name := ""


func get_prompt() -> String:
	return "Ride the Valley shuttle"


func destinations() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for stop: Dictionary in STOPS:
		if stop.name != stop_name:
			result.append(stop)
	return result


func interact(_player: Player) -> void:
	if GameClock.is_too_late_for(RIDE_MINUTES):
		get_tree().call_group("hud", "show_message", "The shuttle has stopped running for the night.")
		return
	# The Valley map shows where each stop is; pick one there.
	get_tree().call_group("world", "open_shuttle_map", stop_name)


func ride(stop: Dictionary) -> void:
	get_tree().call_group("world", "go_to_region", stop.region, stop.spawn, RIDE_MINUTES)
