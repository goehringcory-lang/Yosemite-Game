class_name ShuttleStop
extends StaticBody2D
## A stop on the free Yosemite Valley shuttle. Interact to ride to any other
## stop. A ride takes a few minutes of game time.

## Every stop on the loop: its name, and the region and spawn point it drops you at.
const STOPS := [
	{"name": "Yosemite Village", "region": "yosemite_village", "spawn": "shuttle_village"},
	{"name": "Camp 4", "region": "yosemite_village", "spawn": "shuttle_camp_4"},
	{"name": "Lamon Homestead (Curry orchard)", "region": "lamon_homestead", "spawn": "shuttle"},
	{"name": "Curry Village", "region": "curry_village", "spawn": "shuttle"},
	{"name": "Happy Isles", "region": "yosemite_valley", "spawn": "happy_isles"},
	{"name": "Mirror Lake Trailhead", "region": "yosemite_valley", "spawn": "mirror_lake"},
	{"name": "El Capitan Meadow", "region": "yosemite_valley", "spawn": "el_capitan_meadow"},
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
