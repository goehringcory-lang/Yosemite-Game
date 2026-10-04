class_name ClimbStart
extends StaticBody2D
## The base of a climbing route. Interact to check your gear and food, then
## start the climbing minigame.

const MINIGAME := preload("res://scenes/climb/climb_minigame.tscn")

signal climb_finished(route: RouteData, success: bool)

@export var route: RouteData


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	# Placeholder: a rope coiled at the base of the wall.
	draw_arc(Vector2(0, -4), 5.0, 0, TAU, 12, Color(0.85, 0.3, 0.25), 2.0)
	draw_arc(Vector2(0, -4), 2.5, 0, TAU, 10, Color(0.85, 0.3, 0.25), 1.0)


func interact(player: Player) -> void:
	if not Guidebook.has_book():
		DialogueBox.say_to(player, [{"speaker": "", "text": "%s. You don't know this route yet. Pick up a climbing guidebook at the Mountain Shop in Curry Village, so you have a tick list to log it in." % route.display_name}])
		return
	var missing := Gear.missing(route.required_gear)
	if not missing.is_empty():
		DialogueBox.say_to(player, [{"speaker": "", "text": "%s (%s). You need more gear to climb this: %s." % [
			route.display_name, route.grade, ", ".join(missing)]}])
		return
	var info := "%s, %s, %d pitch%s" % [route.display_name, route.grade, route.pitches.size(), "" if route.pitches.size() == 1 else "es"]
	if route.nights > 0:
		info += ", %d night%s on the wall" % [route.nights, "" if route.nights == 1 else "s"]
	if QuestLog.has_climbed(route.id):
		info += " (already ticked)"
	info += ". You're carrying %d energy of food." % FoodDB.carried_energy()
	player.can_act = false
	var box := DialogueBox.open(player)
	var choice := await box.choose(info, ["Climb", "Not yet"])
	box.close()
	if choice != 0:
		player.can_act = true
		return
	await climb(player)


func climb(player: Player) -> void:
	player.can_act = false
	var was_paused := GameClock.paused
	GameClock.paused = true
	var minigame: ClimbMinigame = MINIGAME.instantiate()
	minigame.setup(route)
	player.get_tree().root.add_child(minigame)
	var result: Array = await minigame.finished
	var success: bool = result[0]
	GameClock.paused = was_paused
	GameClock.advance_minutes(result[1])
	var report: Array[Dictionary] = []
	if success and QuestLog.record_climb(route.id):
		report = QuestLog.tick_report(route.id)
	player.can_act = true
	climb_finished.emit(route, success)
	if not report.is_empty():
		await DialogueBox.say_to(player, report)
	if success and route.destination_hub != "":
		_travel_to_top()


## Unlocks the hub at the top of the route and moves the player there.
func _travel_to_top() -> void:
	Park.unlock_hub(route.destination_hub)
	get_tree().call_group("world", "go_to_region", route.destination_hub, route.destination_spawn)
