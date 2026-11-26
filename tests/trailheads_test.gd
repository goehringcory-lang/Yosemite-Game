extends Node
## Checks the ways between areas and earned fast travel: the travel graph
## (TravelNet) reaches every outdoor area from your cabin and back, prices
## trips by their real roads and trails, and keeps closures; Hetch Hetchy is
## a drive west from Crane Flat by Evergreen Road; trailheads are found by
## walking up to them (their signs are put down in the world); a trip goes to
## a found one only, moves the clock on by its minutes, refuses one that
## would end past the curfew, and the found ones are saved, with older saves
## given the ones in areas they've seen.
## Run: godot --headless --path . res://tests/trailheads_test.tscn
## Exit code is the number of failed checks.

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	SaveManager.save_path = "user://trailheads_test_save.json"
	SaveManager.delete_save()
	Settings.tips = false
	Park.open_world = true
	Engine.time_scale = 4.0

	_check_graph()
	_check_points()
	await _check_in_world()
	SaveManager.delete_save()
	get_tree().quit(failures)


func _check_graph() -> void:
	TravelNet.clear()
	var g := TravelNet.graph()
	check(g.size() >= 60, "the graph reads every area (%d)" % g.size())
	var cut_off: PackedStringArray = []
	var stuck: PackedStringArray = []
	for id: String in g:
		if g[id].indoors or id == "lamon_homestead":
			continue
		if TravelNet.route("lamon_homestead", id).is_empty():
			cut_off.append(id)
		if TravelNet.route(id, "lamon_homestead").is_empty():
			stuck.append(id)
	check(cut_off.is_empty(), "every outdoor area can be reached from your cabin%s" % (": not " + ", ".join(cut_off) if not cut_off.is_empty() else ""))
	check(stuck.is_empty(), "and every one has a way home%s" % (": not " + ", ".join(stuck) if not stuck.is_empty() else ""))

	var hetch := TravelNet.route("crane_flat", "hetch_hetchy")
	check(not hetch.is_empty() and hetch.steps.size() == 1 and "Evergreen Road" in str(hetch.via) and hetch.minutes == 35,
			"Hetch Hetchy is a 35 minute drive west from Crane Flat by Evergreen Road (%s)" % str(hetch.get("via", "")))
	var back := TravelNet.route("hetch_hetchy", "crane_flat")
	check(not back.is_empty() and back.steps[0].spawn == "west", "and the road back lands at Crane Flat's west end")

	var tuolumne := TravelNet.route("yosemite_village", "tuolumne_meadows")
	check(not tuolumne.is_empty() and tuolumne.minutes >= 60 and tuolumne.minutes <= 150 and tuolumne.miles > 30.0,
			"the Village to Tuolumne is a real drive (%d min, %s mi, by %s)" % [tuolumne.get("minutes", 0), str(tuolumne.get("miles", 0)), tuolumne.get("via", "")])
	var near := TravelNet.route("curry_village", "upper_pines")
	check(not near.is_empty() and near.minutes < 30, "Curry Village to Upper Pines is a short way (%d min)" % near.get("minutes", 0))
	check(TravelNet.route("curry_village", "curry_village").is_empty(), "no trip from a place to itself")

	# Closures hold once the world isn't open: winter shuts the Tioga Road.
	Park.open_world = false
	var season := GameClock.season
	GameClock.season = GameClock.Season.WINTER
	var winter := TravelNet.route("yosemite_village", "tuolumne_meadows")
	check(winter.is_empty(), "with the gates on, no way to Tuolumne in winter")
	var hetch_winter := TravelNet.route("crane_flat", "hetch_hetchy")
	check(not hetch_winter.is_empty(), "but Hetch Hetchy stays open all year")
	GameClock.season = season
	Park.open_world = true


func _check_points() -> void:
	var points := Trailheads.all()
	check(points.size() >= 20, "there are trailheads all over the park (%d)" % points.size())
	var bad: PackedStringArray = []
	var hubs := {}
	for point in points:
		var spot_ok: bool = TravelNet.has_region(point.region) and point.pos != Vector2.ZERO and point.lonlat.x < -119.0
		var route_ok: bool = point.region == "lamon_homestead" or not TravelNet.route("lamon_homestead", point.region).is_empty()
		if not spot_ok or not route_ok:
			bad.append(point.id)
		hubs[TravelNet.region_hub(point.region)] = true
	check(bad.is_empty(), "every trailhead has a place, a spot on the map and a way there%s" % (": not " + ", ".join(bad) if not bad.is_empty() else ""))
	for hub in ["yosemite_valley", "glacier_point", "wawona", "el_portal", "tuolumne_meadows"]:
		check(hubs.has(hub), "there's a trailhead in %s" % hub)
	check(Trailheads.is_known("home"), "your cabin is always a place to travel to")


func _check_in_world() -> void:
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	check(Trailheads.count_known() == 1, "a new game knows only your cabin (%d)" % Trailheads.count_known())

	# Walk up to a trailhead and it's found; its sign is in the world.
	GameClock.minutes = 9 * 60
	await world.go_to_region("upper_pines", "arrival")
	await _frames(20)
	var sign := world.region.entities.get_node_or_null("Trailhead_upper_pines") as TrailheadSign
	check(sign != null, "Upper Pines has its trailhead sign")
	check(not Trailheads.is_known("upper_pines"), "not found from across the campground")
	var point := Trailheads.get_point("upper_pines")
	world.player.global_position = world.region.to_global(point.pos + Vector2(0, 40))
	await _frames(30)
	check(Trailheads.is_known("upper_pines"), "found by walking up to it")
	check(sign != null and "Upper Pines" in sign.get_prompt(), "the sign offers to plan a trip (%s)" % (sign.get_prompt() if sign else ""))

	# A kiosk's point is found at the kiosk.
	var kiosk_point := Trailheads.point_at_node("curry_village", "Travel_CurryVillageParking")
	check(kiosk_point.get("id", "") == "curry_parking", "the Curry Village kiosk is a trailhead point")

	# Only found points can be traveled to.
	check(not await Trailheads.travel_to("tuolumne_vc"), "no trip to a trailhead you haven't found")
	check(world.region.region_id == "upper_pines", "...and you stay put")

	# A trip to a found point: the clock moves on by the route's minutes.
	Trailheads.register("tuolumne_vc", false)
	GameClock.minutes = 8 * 60
	var trip := Trailheads.trip_to("tuolumne_vc")
	check(not trip.is_empty() and trip.minutes > 60 and not trip.on_foot and not trip.too_late,
			"Upper Pines to Tuolumne is a drive (%d min, arrive %s)" % [trip.get("minutes", 0), trip.get("arrive", "")])
	var before: int = GameClock.minutes
	check(await Trailheads.travel_to("tuolumne_vc"), "the trip goes")
	await _frames(10)
	check(world.region.region_id == "tuolumne_meadows", "and arrives at Tuolumne Meadows")
	var landed: Vector2 = world.region.to_local(world.player.global_position)
	check(landed.distance_to(Trailheads.get_point("tuolumne_vc").pos) < 400.0, "beside the visitor center kiosk (%d px)" % landed.distance_to(Trailheads.get_point("tuolumne_vc").pos))
	check(GameClock.minutes - before >= trip.minutes and GameClock.minutes - before <= trip.minutes + 5,
			"the clock moved on by the trip (%d of %d min)" % [GameClock.minutes - before, trip.minutes])

	# Too late at night: the trip home is refused.
	GameClock.minutes = 23 * 60 + 30
	var late := Trailheads.trip_to("home")
	check(late.get("too_late", false), "a trip that would end past the curfew is too late")
	check(not await Trailheads.travel_to("home"), "...and refused")
	check(world.region.region_id == "tuolumne_meadows", "...so you stay at Tuolumne")

	# Saved and loaded.
	var saved := Trailheads.save_data()
	Trailheads.start_new_game()
	check(not Trailheads.is_known("tuolumne_vc"), "a new game forgets them")
	Trailheads.load_data(saved)
	check(Trailheads.is_known("tuolumne_vc") and Trailheads.is_known("upper_pines"), "a save keeps the found ones")

	# A save from before trailheads: the areas it has seen give their points.
	Trailheads.start_new_game()
	Discoveries.found["wawona/Wawona"] = true
	Trailheads._backfill()
	check(Trailheads.is_known("wawona_store") and Trailheads.is_known("mariposa_grove"), "an older save gets the trailheads in areas it has seen")
	check(not Trailheads.is_known("hetch_hetchy"), "...and not the others")
	world.queue_free()
	await get_tree().process_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
