extends Node
## Checks the trip map (Journey): a drive or a long trail plays on the park
## map instead of fading to black, along the real road or the trail's bends,
## moves the clock on by exactly the trip, lands in the right place and gives
## control back; a key skips it; the setting turns it off. Also checks that
## the signposts (Wayfinding) now point the way outside the Valley too.
## Run: godot --headless --path . res://tests/journey_test.tscn
## Exit code is the number of failed checks.

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _journey(world: Node) -> Journey:
	for child in world.get_children():
		if child is Journey and not child.is_queued_for_deletion():
			return child
	return null


func _ready() -> void:
	SaveManager.save_path = "user://journey_test_save.json"
	SaveManager.delete_save()
	Settings.tips = false
	Settings.journeys = true
	Park.open_world = true
	Engine.time_scale = 4.0

	# The road and the trail the map draws.
	var crane := Vector2(-119.8000, 37.7530)
	var tenaya := Vector2(-119.4560, 37.8300)
	var road := Journey.road_between(crane, tenaya)
	check(road.size() > 20, "Crane Flat to Tenaya Lake follows the Tioga Road (%d points)" % road.size())
	check(road.size() > 0 and road[0].distance_to(crane) < road[0].distance_to(tenaya), "...in the direction of travel")
	var trail := Journey.route_lonlats({"from": Vector2(-119.558, 37.732), "to": Vector2(-119.5735, 37.7302),
			"from_region": "happy_isles", "to_region": "glacier_point", "on_foot": true})
	check(trail.size() == 6, "the Mist and Panorama Trails bend by Vernal and Nevada Falls (%d points)" % trail.size())
	var straight := Journey.route_lonlats({"from": crane, "to": tenaya, "on_foot": true})
	check(straight.size() == 2, "a trail with no known bends goes straight")
	check(is_equal_approx(Journey.ease_trip(0.0), 0.0) and is_equal_approx(Journey.ease_trip(1.0), 1.0) and Journey.ease_trip(0.5) > Journey.ease_trip(0.4), "the marker runs from start to end without going back")
	check(Journey.clock_text(13 * 60 + 5) == "1:05 PM" and Journey.clock_text(0) == "12:00 AM", "the map's clock reads like the HUD's")
	check(Journey.place_name("tenaya_lake") != "", "regions have a name for the map (%s)" % Journey.place_name("tenaya_lake"))

	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	world.journeys_headless = true

	# Drive from Crane Flat up the Tioga Road to Tenaya Lake on the map.
	await world.go_to_region("crane_flat", "south", 20, {"title": "Big Oak Flat Road", "miles": 9.0})
	check(world.region.region_id == "crane_flat", "a drive on the map arrives (Crane Flat)")
	var before: int = GameClock.minutes
	world.go_to_region("tenaya_lake", "west", 55, {"title": "Tioga Road", "miles": 31.0})
	await get_tree().process_frame
	var journey := _journey(world)
	check(journey != null, "the trip plays on the park map, not a black screen")
	check(world.hud.fade.color.a == 0.0, "...and the screen isn't faded")
	check(GameClock.paused and not world.player.can_act, "the clock and the player wait while it plays")
	var shown_tenaya := false
	var passed_olmsted := false
	for i in 600:
		if journey == null or not is_instance_valid(journey) or not world._busy:
			break
		if journey._running:
			for sight: Dictionary in journey._sights:
				shown_tenaya = shown_tenaya or sight.name == "Tenaya Lake"
				passed_olmsted = passed_olmsted or (sight.name == "Olmsted Point" and sight.at.distance_to(journey._marker().at) < Journey.PASSING)
		await get_tree().process_frame
	check(not world._busy, "the trip ends")
	check(world.region.region_id == "tenaya_lake", "...at Tenaya Lake")
	check(GameClock.minutes - before == 55, "the clock moved on by the whole drive, once (%d)" % (GameClock.minutes - before))
	check(shown_tenaya, "Tenaya Lake is named on the map")
	check(passed_olmsted, "the marker passes Olmsted Point on the way")
	await get_tree().process_frame
	check(_journey(world) == null, "the map lifts and is gone")
	check(not GameClock.paused and world.player.can_act, "control comes back")

	# A key skips the rest of the trip.
	before = GameClock.minutes
	world.go_to_region("tuolumne_meadows", "west", 15, {"title": "Tioga Road", "miles": 8.0})
	journey = null
	for i in 600:
		await get_tree().process_frame
		journey = _journey(world)
		if journey and journey._running:
			break
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	var started := Time.get_ticks_msec()
	Input.parse_input_event(key)
	await get_tree().process_frame
	await get_tree().process_frame
	var skipped: bool = journey != null and is_instance_valid(journey) and journey._skip
	while world._busy and Time.get_ticks_msec() - started < 20000:
		await get_tree().process_frame
	check(skipped, "a key skips the trip map")
	check(world.region.region_id == "tuolumne_meadows" and GameClock.minutes - before == 15, "...and still arrives with the full time gone")

	# Signposts outside the Valley: Clouds Rest from Tenaya Lake, not from
	# the Valley floor; Tenaya Peak isn't signed over its own lake.
	var lake: Region = world._get_region("tenaya_lake")
	world.add_child(lake)
	var signs := Wayfinding.new()
	var names := []
	for landmark: Dictionary in signs._landmarks(lake, lake.get_bounds().get_center()):
		names.append(landmark.text)
	check("Clouds Rest" in names, "Clouds Rest is signposted at Tenaya Lake (%s)" % [names])
	check(not ("Tenaya Peak" in names), "...but not Tenaya Peak, which stands over it")
	world.remove_child(lake)
	var curry: Region = world._get_region("curry_village")
	world.add_child(curry)
	names.clear()
	for landmark: Dictionary in signs._landmarks(curry, curry.get_bounds().get_center()):
		names.append(landmark.text)
	check(not ("Clouds Rest" in names), "the high country's landmarks stay off the Valley floor (%s)" % [names])
	world.remove_child(curry)
	signs.free()

	# The setting puts the fade back.
	Settings.journeys = false
	before = GameClock.minutes
	world.go_to_region("tenaya_lake", "east", 15)
	await get_tree().process_frame
	check(_journey(world) == null, "with Trip map off, trips fade as before")
	while world._busy:
		await get_tree().process_frame
	check(world.region.region_id == "tenaya_lake" and GameClock.minutes - before == 15, "...and still arrive")
	Settings.journeys = true

	SaveManager.delete_save()
	print("journey_test: %d failure(s)" % failures)
	get_tree().quit(failures)
