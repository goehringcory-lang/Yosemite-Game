extends Node
## Saves a screenshot of the v2 climbing screen with the body's controls
## showing: the rings on the holds the next hand could use, the aimed hold,
## the technique word and, with SHOT_HIP, the hips shifted with the plumb
## line. Needs a window (not --headless). Environment:
##   SHOT_ROUTE   route id (default: the frozen fixture pitch, v2_fixture)
##   SHOT_MOVES   moves the body bot makes first (default 6)
##   SHOT_AIM     hold id to aim at (default: the body's own pick)
##   SHOT_HIP     hip shift "x,y" in metres, e.g. "-0.15,0" (default none)
##   SHOT_ZOOM    camera zoom (default 1.6)
##   SHOT_OUT     the PNG (default user://climb_v2_body.png)
## Run: SHOT_HIP=-0.15,0.15 xvfb-run godot --path . res://tools/shots/climb_v2_body_shot.tscn


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
		route.pitches.assign([2, 2])
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
	var d := screen.director
	var bot := ClimbV2BodyBot.new(d)
	bot.place_from = -1.0
	var want := int(_env("SHOT_MOVES", "6"))
	var guard := 0
	while bot.moves < want and not d.done and guard < 400:
		bot.step()
		guard += 1
	while d.session.phase != &"climb" and not d.done and guard < 450:
		d.handle_verb(&"commit", true)
		guard += 1
	var phase := d.current as BodyAimPhase
	if phase:
		var aim := _env("SHOT_AIM", "")
		if aim != "":
			phase.aim_at(aim)
		var hip := _env("SHOT_HIP", "")
		if hip != "":
			var xy := hip.split(",")
			d.handle_verb(&"body", true)
			phase.set_hip_shift(Vector2(float(xy[0]), float(xy[1])))
	var zoom := float(_env("SHOT_ZOOM", "1.6"))
	for i in 90:
		if screen.look and "_zoom" in screen.look:
			screen.look.set("_zoom", zoom)
		await get_tree().process_frame
	var path := _env("SHOT_OUT", "user://climb_v2_body.png")
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))
	get_tree().quit()
