class_name SummitMoment
extends Node2D
## The top of Half Dome. The first time you walk out onto it, by the cables
## or off the end of Snake Dike, the view down the Valley plays
## (Backcountry.SUMMIT_VIEW) and the summit is marked (Backcountry.SUMMIT).

## How close you have to come, in pixels.
@export var radius := 320.0

var _check := 0.0


func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0 or QuestLog.is_unlocked(Backcountry.SUMMIT):
		return
	_check = 0.25
	var world := get_tree().get_first_node_in_group("world")
	if world == null or world.get("_busy") or not "player" in world:
		return
	var player: Player = world.player
	if player == null or not player.can_act or player.global_position.distance_to(global_position) > radius:
		return
	for box in get_tree().get_nodes_in_group("dialogue_box"):
		if not box.is_queued_for_deletion():
			return
	Backcountry.mark(Backcountry.SUMMIT)
	Backcountry.show_view(player, Backcountry.SUMMIT_VIEW, Backcountry.SUMMIT_WORDS)
