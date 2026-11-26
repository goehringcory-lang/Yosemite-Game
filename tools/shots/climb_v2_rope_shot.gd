extends Node
## Saves a screenshot of v2 rope work (thread 5): the clip card part-way
## through pulling up rope, or the rope strip while climbing. Needs a window.
##   SHOT_MODE  clip (default) or strip
##   SHOT_OUT   the PNG (default user://climb_v2_rope.png)
## Run: xvfb-run godot --path . res://tools/shots/climb_v2_rope_shot.tscn


func _env(key: String, fallback: String) -> String:
	return OS.get_environment(key) if OS.get_environment(key) != "" else fallback


func _ready() -> void:
	ClimbSystems.pin_stubs_except([&"rope"])
	var route := RouteData.new()
	route.id = "v2_fixture"
	route.display_name = "Fixture"
	route.protection = "bolts"
	route.pitches.assign([2, 2])
	var rack := V2Rack.new()
	rack.items.assign([
		{"id": "cam_1", "kind": "cam", "width_min": 4, "width_max": 4, "count": 1, "name": "#1"},
		{"id": "quickdraw", "kind": "draw", "width_min": -1, "width_max": -1, "count": 8, "name": "Quickdraw"},
		{"id": "sling", "kind": "sling", "width_min": -1, "width_max": -1, "count": 2, "name": "Sling"},
	])
	var screen: ClimbScreenV2 = load("res://scenes/climb/climb_screen_v2.tscn").instantiate()
	screen.setup(route, 7, V2Modifiers.new(), rack)
	add_child(screen)
	await get_tree().process_frame
	var d := screen.director
	var s := screen.session
	var bot := ClimbV2TestBot.new(d)
	while not d.done and bot.steps < 300 and not (s.phase == &"climb" and s.pose.hip.y > 5.5):
		bot.step()
	s.effort.pump = 0.42
	if _env("SHOT_MODE", "clip") == "clip":
		d.handle_verb(&"rope", true)
		d.handle_verb(&"rope", true)
	for i in 60:
		await get_tree().process_frame
	var path := _env("SHOT_OUT", "user://climb_v2_rope.png")
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path), " phase ", s.phase, " hip ", s.pose.hip)
	ClimbSystems.pins.clear()
	get_tree().quit()
