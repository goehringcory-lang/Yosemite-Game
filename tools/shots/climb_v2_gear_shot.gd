extends Node
## Saves a screenshot of v2 trad gear (thread 6): the climber part-way up the
## fixture pitch with the rack open at the hand crack. Needs a window (not
## --headless). Environment:
##   SHOT_PIECE   rack item to show (default cam_1): cam_075, cam_1, cam_2, nut_mid, nut_big
##   SHOT_OFFER   1 = offer it (show the lobes / the nut sliding), else held up beside
##   SHOT_SLIDE   presses of Down before offering (slides the spot down the crack)
##   SHOT_KNOW    comma list of mentor knowledge, e.g. "lobes,constrictions"
##   SHOT_PUMP    starting pump 0..1 (near 1 shows the warning)
##   SHOT_HIP     climb until the hips are this high, metres (default 3.9)
##   SHOT_OUT     the PNG (default user://climb_v2_gear.png)
## Run: SHOT_OFFER=1 godot --path . res://tools/shots/climb_v2_gear_shot.tscn


func _env(key: String, fallback: String) -> String:
	return OS.get_environment(key) if OS.get_environment(key) != "" else fallback


func _ready() -> void:
	ClimbSystems.pin_stubs_except([&"gear"])
	var route := RouteData.new()
	route.id = "v2_fixture"
	route.display_name = "Fixture"
	route.protection = "bolts"
	route.pitches.assign([2, 2])
	var rack := V2Rack.new()
	rack.items.assign([
		{"id": "nut_mid", "kind": "nut", "width_min": 2, "width_max": 3, "count": 1, "name": "Mid nuts", "color": Color("d08a3a")},
		{"id": "nut_big", "kind": "nut", "width_min": 3, "width_max": 4, "count": 1, "name": "Big nuts", "color": Color("9a6fb0")},
		{"id": "cam_075", "kind": "cam", "width_min": 3, "width_max": 3, "count": 1, "name": "Cam #0.75", "color": Color("5a9e4a")},
		{"id": "cam_1", "kind": "cam", "width_min": 4, "width_max": 4, "count": 2, "name": "Cam #1", "color": Color("c8382e")},
		{"id": "cam_2", "kind": "cam", "width_min": 5, "width_max": 5, "count": 1, "name": "Cam #2", "color": Color("e0b534")},
		{"id": "quickdraw", "kind": "draw", "width_min": -1, "width_max": -1, "count": 8, "name": "Quickdraw"},
	])
	var mods := V2Modifiers.new()
	mods.knowledge = PackedStringArray(_env("SHOT_KNOW", "").split(",", false))
	var screen: ClimbScreenV2 = load("res://scenes/climb/climb_screen_v2.tscn").instantiate()
	screen.setup(route, 7, mods, rack)
	add_child(screen)
	await get_tree().process_frame
	var d := screen.director
	var bot := ClimbV2TestBot.new(d)
	bot.place_from = -1.0
	var hip := float(_env("SHOT_HIP", "3.9"))
	for i in 80:
		if d.done or (d.session.phase == &"climb" and d.session.pose.hip.y >= hip):
			break
		bot.step()
	d.session.effort.pump = float(_env("SHOT_PUMP", "0.2"))
	d.handle_verb(&"rack", true)
	var ph := d.current as TradGear.PlacePhase
	if ph:
		var want := _env("SHOT_PIECE", "cam_1")
		for i in ph.entries.size():
			if ph.current_item() == want:
				break
			d.handle_verb(&"aim_right", true)
		for i in int(_env("SHOT_SLIDE", "0")):
			d.handle_verb(&"aim_down", true)
		if _env("SHOT_OFFER", "") == "1":
			d.handle_verb(&"commit", true)
	for i in 90:
		await get_tree().process_frame
	var path := _env("SHOT_OUT", "user://climb_v2_gear.png")
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))
	ClimbSystems.pins.clear()
	get_tree().quit()
