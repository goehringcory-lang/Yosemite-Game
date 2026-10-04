class_name TravelPoint
extends StaticBody2D
## A parking area or map kiosk. Interact to open the park map and travel to
## another hub.

@export var label := ""


func get_prompt() -> String:
	return "Travel from %s" % label if label != "" else "Travel"


func interact(_player: Player) -> void:
	get_tree().call_group("world", "open_travel_map", "")
