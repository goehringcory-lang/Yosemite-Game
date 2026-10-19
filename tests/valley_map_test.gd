extends Node
## Checks the illustrated Yosemite Valley map: M opens it, the labels fit and
## don't overlap, the cursor can reach every place, the player's spot lands on
## the picture, and the shuttle stops are chosen on it.
## Run: godot --headless --path . res://tests/valley_map_test.tscn
## Set MAP_SHOT=/some/dir to also save screenshots (needs a window, not --headless).
## Exit code is the number of failed checks.

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	SaveManager.save_path = "user://valley_map_test_save.json"
	SaveManager.delete_save()
	Engine.time_scale = 20.0
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var map: ParkMap = world.park_map

	await world.go_to_region(Park.HOME_REGION, Park.HOME_SPAWN)
	_press("map")
	await get_tree().process_frame
	check(map.visible and map._tab == ParkMap.Tab.AREA, "M opens the illustrated Valley map first")
	check(not map._view.is_empty() and map._relief != null, "the map's view data and relief loaded")
	check(map._points.size() >= 20, "the map has %d labeled places" % map._points.size())
	await _shot("area_lamon")

	_check_labels(map)
	_check_projection(map)
	_check_cursor(map)

	# The cursor starts at the place nearest the player: the homestead.
	check(map._points[map._cursor].id == "lamon_homestead", "the cursor starts at %s" % map._points[map._cursor].id)
	_press("ui_focus_next")
	check(map._tab == ParkMap.Tab.PARK, "Tab switches to the park map")
	_press("ui_focus_next")
	check(map._tab == ParkMap.Tab.AREA, "Tab switches back")
	_press("map")
	check(not map.visible and world.player.can_act, "M closes the map and resumes the game")

	# From the Village hub and from home, the cursor starts at a place near the player.
	map.close()
	await world.go_to_region("yosemite_village", "arrival")
	_press("map")
	check(map.visible and map._tab == ParkMap.Tab.AREA, "M opens the Valley map in the Village too")
	var near: Dictionary = map._points[map._cursor]
	check(near.id in ["yosemite_village", "camp_4", "cooks_meadow", "lower_yosemite_fall", "ahwahnee"], "in the Village the cursor starts at %s" % near.id)
	_press("map")
	await world.go_to_region(Park.HOME_REGION, Park.HOME_SPAWN)
	_press("map")
	check(map.visible and map._points[map._cursor].id == "lamon_homestead", "at home the cursor starts at the homestead (%s)" % map._points[map._cursor].id)
	_press("map")
	await world.go_to_region(Park.HOME_REGION, Park.HOME_SPAWN)

	# A kiosk opens the park map to travel, with Tab to the Valley map.
	world.open_travel_map("")
	check(map._tab == ParkMap.Tab.PARK, "a kiosk opens the park map for travel")
	map.close()

	# Choosing a shuttle stop on the map.
	var before := GameClock.minutes
	world.open_shuttle_map("Curry Village")
	await get_tree().process_frame
	check(map.visible and map._shuttle_from == "Curry Village" and map._points[map._cursor].get("stop", "") == "Curry Village",
		"the shuttle map starts on the stop you are at")
	await _shot("area_shuttle")
	map._ride()
	check(map.visible, "riding to the stop you are at does nothing")
	for i in map._points.size():
		if map._points[i].get("stop", "") == "Happy Isles":
			map._cursor = i
	map._ride()
	await get_tree().create_timer(2.5).timeout
	check(world.region.region_id == "happy_isles" and world.player.position == world.region.get_spawn("shuttle").position,
		"choosing Happy Isles on the map rides there")
	check(GameClock.minutes - before == ShuttleStop.RIDE_MINUTES, "the ride takes %d minutes" % ShuttleStop.RIDE_MINUTES)
	for stop: Dictionary in ShuttleStop.STOPS:
		var found := false
		for point: Dictionary in map._points:
			found = found or point.get("stop", "") == stop.name
		check(found, "shuttle stop %s is on the map" % stop.name)

	world.free()
	SaveManager.delete_save()
	get_tree().quit(failures)


## Every sign sits inside the picture and none overlap.
func _check_labels(map: ParkMap) -> void:
	var font := map._area_canvas.get_theme_default_font()
	var rects: Array[Rect2] = []
	var bad := PackedStringArray()
	for point: Dictionary in map._points:
		var icon := 7.0 if point.tier in ["landmark", "fall"] else (8.0 if point.tier == "home" else 0.0)
		var width := ceilf(font.get_string_size(point.name, HORIZONTAL_ALIGNMENT_LEFT, -1, ParkMap.FONT_SIZE).x) + 7.0 + icon
		var rect := Rect2(map._label_pos(point) - Vector2(width, 12.0) / 2.0, Vector2(width, 12.0))
		if not Rect2(Vector2.ZERO, map._area_rect.size).encloses(rect):
			bad.append("%s is off the picture" % point.name)
		for i in rects.size():
			if rects[i].grow(1).intersects(rect):
				bad.append("%s overlaps a neighbor" % point.name)
		rects.append(rect)
		if OS.get_environment("MAP_DEBUG") != "":
			print("  %s  x %d..%d  y %d..%d" % [point.name, rect.position.x, rect.end.x, rect.position.y, rect.end.y])
	check(bad.is_empty(), "all signs fit and none overlap %s" % ", ".join(bad))


## The player's real position lands on the same spot the picture was drawn for.
func _check_projection(map: ParkMap) -> void:
	var home := Vector2(-119.5672, 37.7352)
	var placed := map._view_point(home)
	var anchor := Vector2.ZERO
	for point: Dictionary in map._points:
		if point.id == "lamon_homestead":
			anchor = map._v2(point.anchor)
	check(placed.distance_to(anchor) <= 1.5, "the relief lift matches the picture (%s vs %s)" % [placed, anchor])
	var el_cap := map._view_point(Vector2(-119.6376, 37.7342))
	check(el_cap.y < map._view_point(Vector2(-119.6376, 37.7300)).y, "tall ground is drawn higher up")


## From the start, the arrow keys can reach every place.
func _check_cursor(map: ParkMap) -> void:
	var start := map._cursor
	var seen := {start: true}
	var frontier := [start]
	while not frontier.is_empty():
		var at: int = frontier.pop_back()
		for dir: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			map._cursor = at
			map._move_cursor(dir)
			if not seen.has(map._cursor):
				seen[map._cursor] = true
				frontier.append(map._cursor)
	check(seen.size() == map._points.size(), "the arrow keys reach all %d places (%d)" % [map._points.size(), seen.size()])
	map._cursor = start


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	var release := InputEventAction.new()
	release.action = action
	Input.parse_input_event(release)
	Input.flush_buffered_events()


func _shot(name: String) -> void:
	var dir := OS.get_environment("MAP_SHOT")
	if dir == "" or DisplayServer.get_name() == "headless":
		return
	for i in 3:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])
