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
	# A trail sign with a grade plate (green easy, red hard, blue for ice) and
	# a coil of rope at its foot.
	var yds := Guidebook.yds(route.grade) if route else 0.0
	var plate := Color("15141c") if route and route.boulder else Color("3a86a8")
	if yds > 0.0:
		plate = Color("84b04a") if yds < 7.5 else (Color("d8a63b") if yds < 10.5 else (Color("d9772a") if yds < 12.5 else Color("b3362b")))
	var wood := Color("6b4829")
	draw_rect(Rect2(-1, -15, 3, 15), Color("2a1b14"))
	draw_rect(Rect2(0, -14, 1, 14), wood)
	draw_rect(Rect2(-7, -16, 15, 8), Color("2a1b14"))
	draw_rect(Rect2(-6, -15, 13, 6), plate)
	draw_rect(Rect2(-6, -15, 13, 1), plate.lightened(0.4))
	draw_rect(Rect2(-6, -10, 13, 1), plate.darkened(0.3))
	# the rope: a flat coil in pixels, lit on top, with its tail trailing off
	var rope := Color(0.702, 0.212, 0.169)
	draw_rect(Rect2(3, -6, 9, 6), Color("2a1b14"))
	draw_rect(Rect2(2, -5, 11, 4), Color("2a1b14"))
	draw_rect(Rect2(3, -5, 9, 4), rope.darkened(0.25))
	draw_rect(Rect2(4, -5, 7, 1), rope.lightened(0.25))
	draw_rect(Rect2(3, -3, 9, 1), rope)
	draw_rect(Rect2(5, -4, 5, 1), Color("2a1b14"))
	draw_rect(Rect2(12, -2, 3, 1), rope)
	draw_rect(Rect2(12, -1, 3, 1), Color("2a1b14"))


func interact(player: Player) -> void:
	if not Guidebook.has_book():
		DialogueBox.say_to(player, [{"speaker": "", "text": "%s. You don't know this route yet. Pick up a climbing guidebook at the Mountain Shop in Curry Village, so you have a tick list to log it in." % route.display_name}])
		return
	var partner := partner_name()
	if route.partner_quest != "" and not has_partner():
		DialogueBox.say_to(player, [{"speaker": "", "text": "%s (%s). You can't lead this alone: you need a partner with a rope to belay you. %s" % [
			route.display_name, route.grade, "%s is looking for one." % partner if partner != "" else "Ask around."]}])
		return
	var missing := Gear.missing(route.required_gear)
	if not missing.is_empty():
		DialogueBox.say_to(player, [{"speaker": "", "text": "%s (%s). You need more gear to climb this: %s." % [
			route.display_name, route.grade, ", ".join(missing)]}])
		return
	if ClimbState.starts_too_late(route, GameClock.minutes):
		DialogueBox.say_to(player, [{"speaker": "", "text": "%s (%s). You'd still be on the wall at 2 AM. Start in the morning." % [route.display_name, route.grade]}])
		return
	var place: String = ClimbProfiles.get_profile(route.id).get("place", "")
	var info := "%s, %s, %s" % [route.display_name, route.grade, route.pitch_text()]
	if place != "":
		info += " (%s)" % place
	if route.nights > 0:
		info += ", %d night%s on the wall" % [route.nights, "" if route.nights == 1 else "s"]
	if partner != "":
		info += ", %s on belay" % partner
	if QuestLog.has_climbed(route.id):
		info += " (already ticked)"
	var today: Array[String] = []
	for line: Array in WallWeather.forecast(route, WallWeather.today(route.id)):
		today.append(line[0])
	info += ". Today: %s. You're carrying %d energy of food." % [", ".join(today).to_lower(), FoodDB.carried_energy()]
	player.can_act = false
	var box := DialogueBox.open(player)
	var choice := await box.choose(info, ["Climb", "Not yet"])
	box.close()
	if choice != 0:
		player.can_act = true
		return
	await climb(player)


func climb(player: Player) -> void:
	# Cached now: if the climb ends past the curfew the player is sent home and
	# this node leaves the tree before the climb is over.
	var tree := player.get_tree()
	player.can_act = false
	var was_paused := GameClock.paused
	GameClock.paused = true
	var minigame: ClimbMinigame = MINIGAME.instantiate()
	minigame.setup(route)
	tree.root.add_child(minigame)
	var state := minigame.state
	var result: Array = await minigame.finished
	var success: bool = result[0]
	GameClock.paused = was_paused
	Perks.note("perfect_cruxes", state.perfect_cruxes)
	var report: Array[Dictionary] = []
	if success and QuestLog.record_climb(route.id):
		report = QuestLog.tick_report(route.id)
	player.can_act = true
	climb_finished.emit(route, success)
	if not report.is_empty():
		await DialogueBox.say_to(player, report)
	if success and route.destination_hub != "":
		Park.unlock_hub(route.destination_hub)
	# The nights on the wall are new days. Time passes last: a climb that ran
	# past 2 AM ends with the player passed out and sent home, not at the top.
	var passed_out := GameClock.advance_through_nights(result[1], state.nights_spent)
	if success and route.destination() != "" and not passed_out:
		tree.call_group("world", "go_to_region", route.destination(), route.destination_spawn)


## True if the route needs no partner, or your partner's quest is underway or done.
func has_partner() -> bool:
	var quest := route.partner_quest
	return quest == "" or QuestLog.active.has(quest) or QuestLog.is_completed(quest)


## The display name of the person who belays you here, or "".
func partner_name() -> String:
	var quest := QuestLog.get_quest(route.partner_quest) if route.partner_quest != "" else null
	var who := QuestLog.get_character(quest.giver) if quest else null
	return who.display_name if who else ""
