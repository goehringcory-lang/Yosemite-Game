extends Node
## Checks the open-world map: the Park map's fog clears as you walk and
## arrive (MapFog), a high lookout clears the country around it, a save keeps
## it and an old save is seeded from what it had discovered; the first
## arrival in an area brings up its title card; stamps go down and come up;
## tracking points the way (Tracker), straight at a spot in the same area and
## through the right way out toward another; and the Park map's cursor,
## zoom and stamp picker work.
## Run: godot --headless --path . res://tests/map_fog_test.tscn
## Exit code is the number of failed checks.

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _key(action: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _tracker(world: Node) -> Tracker:
	for node in world.hud.find_children("*", "Control", true, false):
		if node is Tracker:
			return node
	return null


func _ready() -> void:
	SaveManager.save_path = "user://map_fog_test_save.json"
	SaveManager.delete_save()
	Settings.tips = false
	Settings.wayfinding = true
	Settings.arrival_titles = true
	Engine.time_scale = 4.0
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame

	# --- the fog itself
	MapFog.start_new_game()
	check(MapFog.seen_fraction() == 0.0, "a new game's park map is all fog")
	var village := Vector2(-119.5885, 37.7486)
	var fresh := MapFog.reveal(village, 500.0)
	check(fresh > 0 and MapFog.is_seen_at(village), "walking clears the map around you (%d px)" % fresh)
	check(not MapFog.is_seen_at(Vector2(-119.36, 37.875)), "Tuolumne stays fogged")
	check(MapFog.reveal(village, 500.0) == 0, "clearing the same spot again clears nothing new")
	var road := MapFog.reveal_path(PackedVector2Array([village, Vector2(-119.36, 37.875)]), 300.0)
	check(road > 20 and MapFog.is_seen_at(village.lerp(Vector2(-119.36, 37.875), 0.5)), "a trip clears a ribbon along the way (%d px)" % road)
	var image := MapFog.fog_image((load("res://assets/map/park_map.png") as Texture2D).get_image())
	var c := Vector2i(MapFog.to_cell(village))
	check(image.get_pixelv(c).a == 0.0 and image.get_pixel(5, 5).a == 1.0, "the fog picture is clear where seen and parchment elsewhere")

	# --- walking about: arriving somewhere new
	MapFog.start_new_game()
	await world.go_to_region("el_capitan_meadow", "arrival")
	for i in 30:
		await get_tree().process_frame
	MapFog.walk(world.region, world.region.to_local(world.player.global_position))
	check(MapFog.visited.has("el_capitan_meadow"), "walking into an area records it on the map")
	check(MapFog.is_seen_at(MapFog.region_lonlat("el_capitan_meadow")), "and clears the map around it")
	check(world.hud.arrival_title.is_showing(), "its name comes up across the screen the first time")
	check(MapFog.subtitle_for("el_capitan_meadow", "yosemite_valley") == "Yosemite Valley", "under it, the part of the park it's in")
	var before := MapFog.seen_fraction()
	await world.go_to_region("glacier_point", "arrival")
	for i in 10:
		await get_tree().process_frame
	MapFog.walk(world.region, world.region.to_local(world.player.global_position))
	check(MapFog.seen_fraction() > before + 0.01 and MapFog.is_seen_at(Vector2(-119.53, 37.746)), "a high lookout clears the country all around (Half Dome too)")

	# --- saving
	var saved := MapFog.save_data()
	var seen_then := MapFog.seen_fraction()
	MapFog.start_new_game()
	MapFog.load_data(JSON.parse_string(JSON.stringify(saved)))
	check(is_equal_approx(MapFog.seen_fraction(), seen_then) and MapFog.visited.has("glacier_point"), "a save keeps the map as it was")
	# a save from before the fog
	Discoveries.start_new_game()
	Discoveries.found[Discoveries.key_for("mirror_lake", MapFog.region_name("mirror_lake"))] = true
	MapFog.load_data({})
	await get_tree().process_frame
	await get_tree().process_frame
	check(MapFog.visited.has("mirror_lake") and MapFog.is_seen_at(MapFog.region_lonlat("mirror_lake")), "an old save's map is cleared around what it had found")

	# --- stamps and tracking
	MapFog.start_new_game()
	check(MapFog.add_stamp("fish", Vector2(-119.57, 37.74)) and MapFog.stamps.size() == 1, "a stamp goes down")
	check(not MapFog.add_stamp("dragon", village), "only the known kinds of stamp")
	for i in MapFog.MAX_STAMPS:
		MapFog.add_stamp("star", village)
	check(MapFog.stamps.size() == MapFog.MAX_STAMPS, "the map holds %d stamps at most" % MapFog.MAX_STAMPS)
	var stamp := {"kind": "stamp", "id": "0", "label": "Fishing spot", "lonlat": Vector2(-119.57, 37.74), "region": ""}
	check(MapFog.track(stamp) and MapFog.is_tracked(stamp), "a stamp can be tracked")
	check(not MapFog.track(stamp) and MapFog.tracked.is_empty(), "tracking it again stops")
	MapFog.track(stamp)
	MapFog.remove_stamp(0)
	check(MapFog.tracked.is_empty() and MapFog.stamps.size() == MapFog.MAX_STAMPS - 1, "taking a tracked stamp up stops tracking it")

	# --- the tracker in the world
	check(Tracker.distance_text(340.0) == "340 m" and Tracker.distance_text(2400.0) == "2.4 km", "distances read nicely")
	check(Tracker.short_label("Ledge Trail, down to Curry Village") == "Ledge Trail", "exit names are cut to the trail's name")
	await world.go_to_region("curry_village", "arrival")
	for i in 30:
		await get_tree().process_frame
	var region: Region = world.region
	var spot := region.get_bounds().get_center() + Vector2(600, 0)
	check(Tracker.local_of(region, Wayfinding.lonlat_of(region, spot)).distance_to(spot) < 1.0, "a map position and its longitude/latitude go both ways")
	var tracker := _tracker(world)
	check(tracker != null, "the HUD has a tracker")
	MapFog.track({"kind": "stamp", "id": "x", "label": "Star", "lonlat": Wayfinding.lonlat_of(region, spot), "region": ""})
	var sign := tracker.point(world)
	check(not sign.is_empty() and str(sign.via).ends_with("m"), "a stamp in this area: the sign gives the distance (%s)" % sign.get("via", ""))
	var toward: Vector2 = region.to_global(spot) - world.player.global_position
	check(sign.get("dir", Vector2.ZERO).dot(toward.normalized()) > 0.7 or sign.get("on_screen", false), "and points at it")
	var glacier := MapFog.region_lonlat("glacier_point")
	MapFog.track({"kind": "area", "id": "glacier_point", "label": "Glacier Point", "lonlat": glacier, "region": "glacier_point"})
	var exit := Tracker.best_exit(region, glacier, "glacier_point")
	check(exit.get("to", "") == "glacier_point", "toward Glacier Point, Curry Village's way out is the trail up (%s)" % exit.get("label", ""))
	sign = tracker.point(world)
	check(str(sign.get("via", "")).begins_with("via "), "the sign names the way (%s)" % sign.get("via", ""))
	MapFog.track({"kind": "area", "id": "curry_village", "label": "Curry Village", "lonlat": MapFog.region_lonlat("curry_village"), "region": "curry_village"})
	tracker.point(world)
	check(MapFog.tracked.is_empty(), "reaching a tracked area stops tracking it")

	# --- the park map
	MapFog.start_new_game()
	MapFog.walk(region, region.to_local(world.player.global_position))
	world.open_map()
	var map: ParkMap = world.park_map
	map._unhandled_input(_key("ui_focus_next"))
	check(map._tab == ParkMap.Tab.PARK and map._looking(), "Tab shows the park map, looking around")
	check(map._fog_rect.texture != null, "the fog is drawn on it")
	map._hover_nearest()
	check(map._hover.get("kind", "") in ["area", "hub", "trailhead"], "the cursor starts on where you are (%s)" % map._hover.get("label", ""))
	map._cursor_at = Vector2(20, 230)
	map._hover_nearest()
	check(map._hover.is_empty(), "out on bare map the cursor is on nothing")
	map._unhandled_input(_key("interact"))
	check(map._picking, "[E] on bare map opens the stamp picker")
	map._unhandled_input(_key("move_right"))
	map._unhandled_input(_key("interact"))
	check(not map._picking and MapFog.stamps.size() == 1 and MapFog.stamps[0].kind == MapFog.STAMPS[1], "choosing one puts it down there")
	map._hover_nearest()
	check(map._hover.get("kind", "") == "stamp", "the cursor is on the new stamp")
	map._unhandled_input(_key("interact"))
	check(MapFog.tracked.get("kind", "") == "stamp", "[E] on it tracks it")
	map._unhandled_input(_key("use_tool"))
	check(MapFog.stamps.is_empty() and MapFog.tracked.is_empty(), "[Space] takes it up")
	map._unhandled_input(_key("assist"))
	check(map._zoom == 2 and map._park_layers.scale == Vector2(2, 2), "[Shift] zooms in")
	map._unhandled_input(_key("assist"))
	check(map._zoom == 1, "and out")
	check(map._info_panel.get_combined_minimum_size().y <= ParkMap.INFO_RECT.size.y, "the note fits its panel")
	map.close()

	Engine.time_scale = 1.0
	SaveManager.delete_save()
	print("%d failure(s)" % failures)
	get_tree().quit(failures)
