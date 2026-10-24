extends Node
## Headless test of Glacier Point's viewers (BinocularView, ScenicViewer):
## the panorama's compass runs one way and agrees with every landmark's
## bearing, every landmark can be found and named from the railing, a name
## takes a steady hand, names are kept in the save, the screen opens and
## closes, and the three viewers on the point can be stepped up to.
## Run: godot --headless --path . res://tests/binocular_test.tscn
## Exit code is the number of failed checks. Uses its own save file.

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	await get_tree().process_frame
	SaveManager.save_path = "user://binocular_test_save.json"
	SaveManager.delete_save()
	Park.start_new_game()
	GameClock.season = GameClock.Season.SUMMER
	GameClock.minutes = 11 * 60
	test_scale()
	await test_view()
	await test_viewers()
	SaveManager.delete_save()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func test_scale() -> void:
	var view: Dictionary = BinocularView.VIEWS.glacier_point
	var scale := BinocularView.make_scale(view)
	var rising := true
	for i in scale.size() - 1:
		rising = rising and scale[i + 1] > scale[i]
	check(rising, "the panorama's compass runs one way, west round to the southeast")
	var ordered := true
	var last := -INF
	var ids := {}
	for t: Dictionary in view.targets:
		ids[t.id] = true
		check(t.has("name") and t.has("stat") and t.has("mi") and t.has("text") and t.get("text", "").length() <= 230,
			"%s has a name, numbers and a line that fits the plaque" % t.id)
		if t.has("floor") or t.has("floor_river"):
			continue
		var b := BinocularView.unwrap(t.bearing)
		ordered = ordered and b >= last
		last = b
	check(ordered, "the skyline's landmarks are listed west to east")
	check(ids.size() == view.targets.size(), "every landmark has its own id")
	for kind in ["mt_hoffmann", "mt_watkins", "mt_starr_king", "mt_clark", "mt_florence", "vernal_fall", "illilouette_fall", "north_rim"]:
		check(ClimbLandscape.LANDMARKS.has(kind), "the skyline painter knows %s" % kind)


func test_view() -> void:
	var view := BinocularView.new()
	view.setup("glacier_point", 65.0)
	add_child(view)
	var waited := 0
	while not view._ready_to_draw and waited < 600:
		await get_tree().process_frame
		waited += 1
	check(view._ready_to_draw, "the panorama paints")
	check(absf(view.bearing_at(view.pan_x) - 65.0) < 0.5, "the viewer starts pointed where it faces (%.1f)" % view.bearing_at(view.pan_x))
	# The compass agrees with each landmark: x and bearing round-trip.
	var agrees := true
	for t: Dictionary in view._targets:
		agrees = agrees and absf(view.bearing_at(view.x_at(t.bearing)) - t.bearing) < 0.2
	check(agrees, "every landmark's bearing reads the same on the compass")
	# Every landmark can be found: point at it and it's in the crosshairs.
	for i in view._targets.size():
		var t: Dictionary = view._targets[i]
		view.pan_x = view.x_at(t.bearing)
		view.tilt = 0.75 if t.has("floor") or t.has("floor_river") else 0.0
		view._clamp_view()
		view._update_focus(0.0)
		check(view.focus == i, "%s can be found in the crosshairs (got %s)" % [t.name, view._targets[view.focus].name if view.focus >= 0 else "nothing"])
	# A name takes a steady hand, then sticks.
	Park.spotted_peaks.clear()
	var hd := -1
	for i in view._targets.size():
		if view._targets[i].id == "half_dome":
			hd = i
	view.pan_x = view.x_at(65.0)
	view.tilt = 0.0
	view.focus = -1
	view._vel = Vector2.ZERO
	view._update_focus(0.1)
	check(view.focus == hd and not view.is_spotted(hd), "Half Dome isn't named at a glance")
	view._vel = Vector2(400, 0)
	view._update_focus(1.0)
	check(not view.is_spotted(hd), "nor while swinging past it")
	view._vel = Vector2.ZERO
	for k in 8:
		view._update_focus(0.1)
	check(view.is_spotted(hd) and view.spotted_count() == 1, "held steady, it's named")
	var saved := Park.save_data()
	Park.start_new_game()
	check(Park.spotted_peaks.is_empty(), "a new game starts with nothing named")
	Park.load_data(saved)
	check(Park.spotted_peaks.has("half_dome"), "names are kept in the save")
	# Zoom, and leaving.
	view._set_zoom(1)
	check(view.zoom_index == 1, "it zooms to 16x")
	var closed := [false]
	view.finished.connect(func() -> void: closed[0] = true)
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	Input.parse_input_event(esc)
	for k in 60:
		await get_tree().process_frame
	check(closed[0], "Esc closes it")


func test_viewers() -> void:
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(world)
	await get_tree().process_frame
	GameClock.paused = true
	world._enter_region("glacier_point", "arrival")
	await get_tree().process_frame
	var viewers: Array[Node] = []
	for name in ["Viewer59", "Viewer63", "Viewer68"]:
		var v: Node = world.region.find_child(name, true, false)
		if v is ScenicViewer:
			viewers.append(v)
	check(viewers.size() == 3, "the three viewers on the point can be looked through")
	if viewers.size() == 3:
		check(viewers[1].facing == 65.0 and viewers[0].facing == 330.0 and viewers[2].facing == 100.0,
			"each points its own way: the falls, Half Dome, the Merced")
		check(viewers[1].get_prompt() == "Look: Binoculars", "the prompt says so")
		# Step up to the one on the tip, facing it.
		var player: Player = world.player
		player.can_act = true
		player.global_position = viewers[1].global_position + Vector2(0, 30)
		player.facing = Vector2i.UP
		player.interaction_area.position = Vector2(player.facing) * 24.0
		for k in 4:
			await get_tree().physics_frame
		check(player.get_target() == viewers[1], "standing in front of it, it's what you'd use")
		viewers[1].interact(player)
		await get_tree().process_frame
		var open := get_tree().root.get_children().filter(func(n: Node) -> bool: return n is BinocularView)
		check(open.size() == 1 and not player.can_act, "using it opens the binoculars and holds the player")
		if open.size() == 1:
			(open[0] as BinocularView).close()
			for k in 90:
				await get_tree().process_frame
			check(player.can_act, "leaving gives the player back")
	world.queue_free()
	await get_tree().process_frame
