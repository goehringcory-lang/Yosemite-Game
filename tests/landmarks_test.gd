extends Node
## Checks that the camera looks up at the landmarks: at the foot of El
## Capitan the screen reaches the rim (so the Nose and Horsetail Fall are in
## view) with the player still on screen, out in the meadow it doesn't tilt,
## and rooms never tilt. Also checks the Yosemite Falls backdrop above the
## Village, the High Sierra skyline above Tuolumne Meadows (and its winter
## snow), Unicorn Peak, and the views placed by story overlays.
## Run: godot --headless --path . res://tests/landmarks_test.tscn
## Exit code is the number of failed checks. Uses its own save file.

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	await get_tree().process_frame
	SaveManager.save_path = "user://landmarks_test_save.json"
	SaveManager.delete_save()
	var world = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(world)
	await get_tree().process_frame
	GameClock.paused = true
	await test_el_capitan(world)
	await test_yosemite_falls(world)
	await test_tuolumne(world)
	SaveManager.delete_save()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


## Puts the player at [param spot] and lets the tilt settle.
func _stand(world: Node, spot: Vector2) -> void:
	world.player.global_position = spot
	world.player.get_node("Camera").reset_smoothing()
	var framing: LandmarkFraming = world.get_node("LandmarkFraming")
	for i in 3:
		await get_tree().process_frame
	framing.tilt = framing.target_tilt(world.player.get_node("Camera"), spot)
	await get_tree().process_frame


func _screen_top(world: Node) -> float:
	var camera: Camera2D = world.player.get_node("Camera")
	return camera.get_screen_center_position().y - camera.get_viewport_rect().size.y / 2.0


func test_el_capitan(world: Node) -> void:
	await world.go_to_region("el_capitan_meadow", "the_nose")
	var framing: LandmarkFraming = world.get_node_or_null("LandmarkFraming")
	check(framing != null, "the World has a LandmarkFraming")
	if framing == null:
		return
	var nose: Vector2 = world.region.get_spawn("the_nose").global_position
	await _stand(world, nose)
	var camera: Camera2D = world.player.get_node("Camera")
	check(camera.offset.y < -100.0, "at the foot of El Capitan the camera tilts up (offset %d)" % camera.offset.y)
	check(_screen_top(world) < 100.0, "the screen reaches up to El Capitan's summit (top at %d)" % _screen_top(world))
	var height := camera.get_viewport_rect().size.y
	check(nose.y - _screen_top(world) <= height - LandmarkFraming.MARGIN + 1.0, "the player stays on screen, above the margin")
	var meadow := Vector2(nose.x, world.region.get_bounds().end.y - 200.0)
	await _stand(world, meadow)
	# (under a pixel: the view is nudged onto the screen's pixels)
	check(absf(camera.offset.y) < 1.0, "down by the river the camera doesn't tilt (offset %.2f)" % camera.offset.y)
	await world.go_to_region("curry_store", "arrival")
	await _stand(world, world.player.global_position)
	check(absf(camera.offset.y) < 1.0, "rooms don't tilt (offset %.2f)" % camera.offset.y)


func test_yosemite_falls(world: Node) -> void:
	await world.go_to_region("yosemite_village", "lower_yosemite_fall")
	var region: Node = world.region
	var backdrop := region.find_child("UpperFallsBackdrop", true, false) as Sprite2D
	var upper := region.find_child("UpperYosemiteFall", true, false) as AnimatedSprite2D
	check(backdrop != null and backdrop.position.y < 0.0, "the Village hangs the upper cliff above the map")
	check(upper is BackdropFall, "Upper Yosemite Fall is on it")
	var view: LandmarkView = null
	for node in get_tree().get_nodes_in_group("landmark_views"):
		if node is LandmarkView and node.landmark == "Yosemite Falls" and region.is_ancestor_of(node):
			view = node
	check(view != null, "the Lower Fall trail has a view of the whole of Yosemite Falls")
	if backdrop == null or view == null:
		return
	check(is_equal_approx(view.top, backdrop.position.y), "the view reaches the top of the backdrop and no further")
	await _stand(world, Vector2(1472, 304))
	check(_screen_top(world) < -150.0, "at the foot of the Lower Fall the screen reaches the rim above it (top at %d)" % _screen_top(world))
	check(_screen_top(world) >= view.top - 0.5, "the screen never goes above the backdrop")
	var falls: SeasonalFalls = null
	for child in region.get_children():
		if child is SeasonalFalls:
			falls = child
	check(falls != null and upper in falls._falls, "Upper Yosemite Fall runs and dries with the Lower Fall")


func test_tuolumne(world: Node) -> void:
	GameClock.season = GameClock.Season.SUMMER
	await world.go_to_region("tuolumne_meadows", "arrival")
	var region: Node = world.region
	var sky := region.find_child("HighSierraBackdrop", true, false) as SeasonalBackdrop
	check(sky != null and sky.position.y < 0.0, "Tuolumne hangs the High Sierra skyline above the map")
	if sky == null:
		return
	check(sky.texture != null and sky.texture.resource_path.ends_with("skyline_summer.png"), "in summer the far peaks wear their summer snow")
	check(sky.texture.get_width() >= region.get_bounds().size.x, "the skyline spans the whole map")
	var view: LandmarkView = null
	for node in get_tree().get_nodes_in_group("landmark_views"):
		if node is LandmarkView and node.landmark == "high_sierra" and region.is_ancestor_of(node):
			view = node
	check(view != null and view.top >= sky.position.y, "the view up at the skyline stays on the backdrop")
	await _stand(world, Vector2(3900, 200))
	check(_screen_top(world) < -200.0, "at the north edge the screen looks up at the peaks (top at %d)" % _screen_top(world))
	if view:
		check(_screen_top(world) >= view.top - 0.5, "the screen never goes above the skyline")
	await _stand(world, Vector2(2400, 1500))
	check(_screen_top(world) >= -0.5, "out in the meadow the camera doesn't look up")
	GameClock.season = GameClock.Season.WINTER
	sky._dress()
	check(sky.texture.resource_path.ends_with("skyline_winter.png"), "in winter the peaks are deep in snow")
	GameClock.season = GameClock.Season.SPRING
	var unicorn := region.find_child("UnicornPeak", true, false) as Node2D
	check(unicorn != null and unicorn.get_parent().get_parent() == region.entities, "Unicorn Peak stands among the meadow's things, sorted with them")
	var cathedral := region.find_child("CathedralPeak", true, false) as Node2D
	if unicorn and cathedral:
		check(unicorn.global_position.y < cathedral.global_position.y, "Unicorn Peak stands behind Cathedral Peak")
