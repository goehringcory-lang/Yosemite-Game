extends Node
## Saves a screenshot of climbing v2 falls and the partner (thread 7): a fall
## with a popped piece (the partner's line and the fall tag), or the belay
## card at the anchor. Needs a window (not --headless). Environment:
##   SHOT_MODE  fall (default) or belay
##   SHOT_OUT   the PNG (default user://climb_v2_falls.png)
## Run: SHOT_MODE=belay godot --path . res://tools/shots/climb_v2_falls_shot.tscn


func _env(key: String, fallback: String) -> String:
	return OS.get_environment(key) if OS.get_environment(key) != "" else fallback


func _ready() -> void:
	ClimbSystems.pin_stubs_except([&"falls"])
	var route := RouteData.new()
	route.id = "v2_fixture"
	route.display_name = "Fixture"
	route.protection = "bolts"
	route.pitches.assign([2, 2])
	var rack := V2Rack.new()
	rack.items.assign([
		{"id": "cam_1", "kind": "cam", "width_min": 4, "width_max": 4, "count": 2, "name": "#1"},
		{"id": "cam_2", "kind": "cam", "width_min": 5, "width_max": 5, "count": 1, "name": "#2"},
		{"id": "nut_mid", "kind": "nut", "width_min": 2, "width_max": 3, "count": 1, "name": "Nut"},
		{"id": "quickdraw", "kind": "draw", "width_min": -1, "width_max": -1, "count": 8, "name": "Quickdraw"},
	])
	var screen: ClimbScreenV2 = load("res://scenes/climb/climb_screen_v2.tscn").instantiate()
	screen.setup(route, 7, V2Modifiers.new(), rack)
	add_child(screen)
	await get_tree().process_frame
	var d := screen.director
	var s := screen.session
	var bot := ClimbV2TestBot.new(d)
	if _env("SHOT_MODE", "fall") == "belay":
		# Two extra pieces the partner will have opinions about.
		while not d.done and s.phase != &"belay" and bot.steps < 1500:
			bot.step()
			if s.phase == &"climb" and s.pieces.size() == 1 and s.pose.hip.y > 6.0:
				_piece(s, "nut_x", "nut_mid", &"nut", s.pose.hip + Vector2(0.4, 0.3), 0.15)
				_piece(s, "cam_x", "cam_2", &"cam", s.pose.hip + Vector2(0.4, 0.9), 0.55)
	else:
		while not d.done and bot.steps < 400 and not (s.phase == &"climb" and s.pose.hip.y > 8.0 and s.rope.clipped.size() >= 2):
			bot.step()
		var bad := _piece(s, "cam_x", "cam_1", &"cam", s.pose.hip + Vector2(0.3, -0.4), 0.1)
		bad.clipped = true
		s.rope.clipped.append(bad.id)
		d.take_fall()
	for i in 50:
		await get_tree().process_frame
	var path := _env("SHOT_OUT", "user://climb_v2_falls.png")
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))
	ClimbSystems.pins.clear()
	get_tree().quit()


func _piece(s: ClimbSession, id: String, gear_id: String, kind: StringName, pos: Vector2, quality: float) -> V2Piece:
	var p := V2Piece.new()
	p.id = id
	p.gear_id = gear_id
	p.kind = kind
	p.pos = pos
	p.quality = quality
	s.rack.take(gear_id)
	s.pieces[id] = p
	return p
