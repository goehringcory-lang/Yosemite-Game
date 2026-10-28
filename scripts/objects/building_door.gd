class_name BuildingDoor
extends RegionDoor
## The front door of a building you can go into, or a door between two of its
## rooms. Unlike a gate it has no picture of its own (the building is drawn
## with its door) and nothing solid: face the door and interact to go in.
## The building's doors are placed by tools/hubs/build_interiors.gd in
## scenes/story/doors/<region>.tscn.

## Opening hours, in 24-hour time, from [member open_hour] up to (not
## including) [member close_hour]. The defaults never close.
@export_range(0, 24) var open_hour := 0
@export_range(0, 24) var close_hour := 24
## The spot outside this door, when it isn't the one the room's way out leads
## to (a building's second door into the same lobby): leaving the room puts
## you back here, by the door you came in.
@export var exit_spawn := ""

## Standing in front of a door, the door wins over the building's own sign
## (see Player.get_target).
var interact_priority := 1


func get_prompt() -> String:
	if not is_unlocked():
		return "Look at %s" % label
	return "Enter: %s" % label


func is_open_now() -> bool:
	return GameClock.hour >= open_hour and GameClock.hour < close_hour


func interact(player: Player) -> void:
	if is_unlocked() and not is_open_now():
		get_tree().call_group("hud", "show_message", "%s is closed. It's open from %s to %s." % [label,
			RegionExit._clock_text(open_hour), RegionExit._clock_text(close_hour)])
		return
	if is_unlocked():
		get_tree().call_group("world", "remember_door", self)
	super.interact(player)
