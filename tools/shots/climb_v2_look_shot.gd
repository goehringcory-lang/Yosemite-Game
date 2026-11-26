extends Node
## Saves a still of the climbing v2 look (thread 10): the lit wall, the
## valley past the arete, the camera framing a climber part-way up.
## Needs a window (not --headless). Environment:
##   SHOT_ROUTE   route id (default v2_fixture, the frozen fixture pitch)
##   SHOT_STEPS   scripted-climber steps before the shot (default 25; 0 =
##                the read view at the start of the pitch)
##   SHOT_HOUR    the hour to light it at (default 10)
##   SHOT_WET     0..1 rain on the rock (default 0)
##   SHOT_WAIT    frames to let the camera ease before the picture (default 90)
##   SHOT_REAL    "1" = use every thread's real system; else only look is real
##   SHOT_OUT     the PNG (default user://climb_v2_look.png)
## Run: SHOT_HOUR=19 xvfb-run godot --path . res://tools/shots/climb_v2_look_shot.tscn


func _env(key: String, fallback: String) -> String:
	return OS.get_environment(key) if OS.get_environment(key) != "" else fallback


func _ready() -> void:
	if _env("SHOT_REAL", "0") != "1":
		ClimbSystems.pin_stubs_except([&"look"])
	ClimbLookLive.force_hour = float(_env("SHOT_HOUR", "10"))
	var route_id := _env("SHOT_ROUTE", "v2_fixture")
	var route: RouteData
	if route_id == "v2_fixture":
		route = RouteData.new()
		route.id = route_id
		route.display_name = "Fixture"
		route.protection = "bolts"
		route.pitches.assign([2, 2])
	else:
		route = load("res://data/routes/%s.tres" % route_id)
	var rack := V2Rack.new()
	rack.items.assign([
		{"id": "cam_1", "kind": "cam", "width_min": 4, "width_max": 4, "count": 1, "name": "#1"},
		{"id": "quickdraw", "kind": "draw", "width_min": -1, "width_max": -1, "count": 8, "name": "Quickdraw"},
	])
	var mods := V2Modifiers.new()
	mods.wet = float(_env("SHOT_WET", "0"))
	var screen: ClimbScreenV2 = load("res://scenes/climb/climb_screen_v2.tscn").instantiate()
	screen.setup(route, 7, mods, rack)
	add_child(screen)
	await get_tree().process_frame
	var bot := ClimbV2TestBot.new(screen.director)
	for i in int(_env("SHOT_STEPS", "25")):
		if screen.director.done:
			break
		bot.step()
	if screen.session.phase == &"climb":
		screen.director.handle_verb(&"aim_up", true)
	var look := screen.look as ClimbLookLive
	if look:
		look.sound.mute = true
		look.settle()
	for i in int(_env("SHOT_WAIT", "90")):
		await get_tree().process_frame
	var path := _env("SHOT_OUT", "user://climb_v2_look.png")
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))
	ClimbLookLive.force_hour = -1.0
	ClimbSystems.pins.clear()
	get_tree().quit()
