class_name TravelPoint
extends StaticBody2D
## A parking area or map kiosk. Interact to plan a trip to any trailhead,
## campground or parking area you've found (Trailheads), or open the park
## map to drive to another hub. A kiosk that isn't a trailhead point opens
## the map as before.

@export var label := ""


func get_prompt() -> String:
	return "Travel from %s" % label if label != "" else "Travel"


func interact(player: Player) -> void:
	var region := _region()
	var point: Dictionary = Trailheads.point_at_node(region.region_id, name) if region else {}
	if point.is_empty():
		get_tree().call_group("world", "open_travel_map", "")
		return
	Trailheads.plan_trip(player, point.id, true)


func _region() -> Region:
	var node := get_parent()
	while node and not node is Region:
		node = node.get_parent()
	return node as Region
