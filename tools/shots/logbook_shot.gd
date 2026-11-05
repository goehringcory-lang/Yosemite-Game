extends Node
## Saves screenshots of the Journal's Logbook tab (achievements and the
## collection log) partway through a game: a few summits, sends and fish.
## Needs a window (not --headless). Environment:
##   SHOT_DIR    folder for the PNGs (default user://)
##   SHOT_SCALE  integer upscale (default 2)
## Run: SHOT_DIR=/tmp/shots xvfb-run -a godot --path . res://tools/shots/logbook_shot.tscn


func _snap(dir: String, scale: int, shot_name: String) -> void:
	for i in 8:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	if scale > 1:
		image.resize(image.get_width() * scale, image.get_height() * scale, Image.INTERPOLATE_NEAREST)
	image.save_png("%s/logbook_%s.png" % [dir, shot_name])


func _send(route_id: String, falls: int, minutes: int) -> void:
	var route: RouteData = load("res://data/routes/%s.tres" % route_id)
	var state := ClimbState.new(route, 8)
	state.falls = falls
	state.minutes = minutes
	Achievements.sent(route, state)
	QuestLog.record_climb(route_id)


func _ready() -> void:
	SaveManager.save_path = "user://logbook_shot_save.json"
	SaveManager.delete_save()
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	GameClock.minutes = 11 * 60
	GameClock.paused = true
	var dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://"
	var scale := int(OS.get_environment("SHOT_SCALE")) if OS.get_environment("SHOT_SCALE") != "" else 2
	await world.go_to_region("curry_village", "arrival")
	for i in 12:
		await get_tree().process_frame
	Backcountry.mark(Guidebook.ABILITY)
	_send("swan_slab", 0, 70)
	_send("firefall_slab", 2, 140)
	GameClock.day = 6
	_send("firefall_slab", 0, 95)
	_send("glacier_point_apron", 1, 300)
	GameClock.day = 14
	_send("higher_cathedral_spire", 3, 420)
	GameClock.season = 1
	GameClock.day = 3
	Backcountry.mark(Backcountry.SUMMIT)
	Backcountry.mark(Backcountry.CABLES)
	var rod: Fishing = Fishing.new()
	add_child(rod)
	for spec: Array in [["rainbow_trout", 11, false], ["rainbow_trout", 16, true], ["brown_trout", 19, false], ["rainbow_trout", 8, false]]:
		var one := Fishing.get_fish(spec[0]).duplicate()
		one["length"] = spec[1]
		one["trophy"] = spec[2]
		rod.land(one)
	rod.free()
	for id in ["stellers_jay", "robin", "quail", "mule_deer", "mountain_chickadee"]:
		FieldLog.spot(id, true)
	Achievements.pending_toasts().clear()
	Perks.pending_toasts().clear()
	world.hud.message_label.modulate.a = 0.0
	var journal: Journal = get_tree().get_first_node_in_group("journal")
	journal.open(Journal.Tab.LOGBOOK)
	await _snap(dir, scale, "achievements")
	for name in ["summits", "sends", "fish"]:
		journal.scroll_by(200)
		await _snap(dir, scale, name)
	get_tree().quit()
