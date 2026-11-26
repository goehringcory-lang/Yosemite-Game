class_name HetchyVigil
extends Node
## Watches for the player standing at Kolana Overlook at dusk while John
## Muir's "The Valley Under the Water" is active (see QuestLog "unlocked"
## steps). Added to the Hetch Hetchy region by EasterEggs.

const QUEST := "muir_valley_under_water"
const EVENT := "saw_hetchy_dusk"
const SPOT := "kolana"
const FROM_HOUR := 17
const TO_HOUR := 22
const REACH := 112.0
const NOTE := "The reservoir goes glass-still, and the cliffs hold the last light. Under the water, a meadow and a river. Tell John Muir what you saw."

var region: Region
var _wait := 0.0


func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = 0.4
	if region == null or not QuestLog.active.has(QUEST) or QuestLog.is_unlocked(EVENT):
		return
	if not GameClock.hour_in_range(FROM_HOUR, TO_HOUR):
		return
	var spot := region.get_spawn(SPOT)
	var world := get_tree().get_first_node_in_group("world")
	if spot == null or world == null or world.get("player") == null:
		return
	if (world.player.global_position - spot.global_position).length() <= REACH:
		QuestLog.mark_event(EVENT, NOTE)
