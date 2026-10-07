class_name RegionDoor
extends StaticBody2D
## A gate or trail into another region, such as the Lamon Homestead.
## Interact to go there.

@export var label := ""
@export var target_region := ""
@export var target_spawn := ""
## How long the walk takes, in game minutes. 0 for a gate.
@export var minutes := 0
## A seasonal closure in Park.SEASONAL (like "four_mile_trail") that shuts
## this way in winter. Empty if it's always open.
@export var closure := ""


func get_prompt() -> String:
	return "Go to %s" % label


func interact(_player: Player) -> void:
	if closure != "" and not Park.is_open(closure):
		get_tree().call_group("hud", "show_message", Park.SEASONAL[closure].why)
		return
	# Like driving, you must arrive by 1 AM.
	if minutes > 0 and GameClock.is_too_late_for(minutes):
		get_tree().call_group("hud", "show_message", "It's too late to start down the trail tonight.")
		return
	get_tree().call_group("world", "go_to_region", target_region, target_spawn, minutes)
