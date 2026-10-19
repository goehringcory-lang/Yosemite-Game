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
## A hub id: the way is only open once that hub is unlocked (the Ledge Trail
## to Glacier Point opens when you've climbed the Apron).
@export var needs_hub := ""
## Shown instead of going in while the way is locked.
@export_multiline var locked_text := ""


## Is the way open yet (its quest under way, its hub unlocked)?
func is_unlocked() -> bool:
	if needs_quest != "" and not (QuestLog.active.has(needs_quest) or QuestLog.is_completed(needs_quest)):
		return false
	return needs_hub == "" or Park.is_hub_unlocked(needs_hub)


func get_prompt() -> String:
	if not is_unlocked():
		return "Look at %s" % label
	return "Go to %s" % label


func interact(_player: Player) -> void:
	if not is_unlocked():
		get_tree().call_group("hud", "show_message", locked_text)
		return
	if closure != "" and not Park.is_open(closure):
		get_tree().call_group("hud", "show_message", Park.SEASONAL[closure].why)
		return
	# Like driving, you must arrive by 1 AM.
	if minutes > 0 and GameClock.is_too_late_for(minutes):
		get_tree().call_group("hud", "show_message", "It's too late to start on the trail tonight.")
		return
	get_tree().call_group("world", "go_to_region", target_region, target_spawn, minutes)
