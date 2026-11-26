extends Node
## Saves a screenshot of the v2 climbing screen part-way up a pitch, with the
## next move's ghost showing. Needs a window (not --headless). Environment:
##   SHOT_ROUTE   route id (default: the frozen fixture pitch, v2_fixture)
##   SHOT_STEPS   scripted-climber steps before the shot (default 30)
##   SHOT_OUT     the PNG (default user://climb_v2.png)
## Run: SHOT_STEPS=40 godot --path . res://tools/shots/climb_v2_shot.tscn


func _env(key: String, fallback: String) -> String:
	return OS.get_environment(key) if OS.get_environment(key) != "" else fallback


func _ready() -> void:
	var route_id := _env("SHOT_ROUTE", "v2_fixture")
	var route: RouteData
	if route_id == "v2_fixture":
		route = RouteData.new()
		route.id = route_id
		route.display_name = "Fixture"
		route.protection = "bolts"
	else:
		route = load("res://data/routes/%s.tres" % route_id)
	var rack := V2Rack.new()
	rack.items.assign([
		{"id": "cam_1", "kind": "cam", "width_min": 4, "width_max": 4, "count": 1, "name": "#1"},
		{"id": "quickdraw", "kind": "draw", "width_min": -1, "width_max": -1, "count": 8, "name": "Quickdraw"},
	])
	var screen: ClimbScreenV2 = load("res://scenes/climb/climb_screen_v2.tscn").instantiate()
	screen.setup(route, 7, V2Modifiers.new(), rack)
	add_child(screen)
	await get_tree().process_frame
	var bot := ClimbV2TestBot.new(screen.director)
	for i in int(_env("SHOT_STEPS", "30")):
		if screen.director.done:
			break
		bot.step()
	if screen.session.phase == &"climb":
		screen.director.handle_verb(&"aim_up", true)
	for i in 90:
		await get_tree().process_frame
	var path := _env("SHOT_OUT", "user://climb_v2.png")
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))
	get_tree().quit()
