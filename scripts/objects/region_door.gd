class_name RegionDoor
extends StaticBody2D
## A gate or trail into another region, such as the Lamon Homestead.
## Interact to go there.

@export var label := ""
@export var target_region := ""
@export var target_spawn := ""


func get_prompt() -> String:
	return "Go to %s" % label


func interact(_player: Player) -> void:
	get_tree().call_group("world", "go_to_region", target_region, target_spawn)
