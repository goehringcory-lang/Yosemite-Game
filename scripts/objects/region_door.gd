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
## A quest id: the way is only open once that quest is under way or done
## (the gap in the talus, which Clark sends you to at the very end).
@export var needs_quest := ""
## Shown instead of going in while [member needs_quest] hasn't started.
@export_multiline var locked_text := ""


func get_prompt() -> String:
	if needs_quest != "" and not (QuestLog.active.has(needs_quest) or QuestLog.is_completed(needs_quest)):
		return "Look at %s" % label
	return "Go to %s" % label


func interact(_player: Player) -> void:
	if needs_quest != "" and not (QuestLog.active.has(needs_quest) or QuestLog.is_completed(needs_quest)):
		get_tree().call_group("hud", "show_message", locked_text)
		return
	if closure != "" and not Park.is_open(closure):
		get_tree().call_group("hud", "show_message", Park.SEASONAL[closure].why)
		return
	# Like driving, you must arrive by 1 AM.
	if minutes > 0 and GameClock.is_too_late_for(minutes):
		get_tree().call_group("hud", "show_message", "It's too late to start down the trail tonight.")
		return
	get_tree().call_group("world", "go_to_region", target_region, target_spawn, minutes)
