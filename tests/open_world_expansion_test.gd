extends Node
## Tests the expanded open world and exploration opportunities:
## - Taft Point & The Fissures (Pohono Trail loop between Tunnel View and Glacier Point)
## - Cathedral Lakes (John Muir Trail loop between Tuolumne Meadows and Tenaya Lake)
## - Hetch Hetchy Valley & Wapama Falls (year-round northwest canyon off Crane Flat)
## - Panoramic binocular viewers, backcountry camps, fishing waters, hidden finds,
##   happenings, flora, wildlife habitats, and Easter eggs across the new regions.
## Run: godot --headless --path . res://tests/open_world_expansion_test.tscn
## Exit code is the number of failed checks.

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	SaveManager.save_path = "user://open_world_expansion_test_save.json"
	SaveManager.delete_save()
	Engine.time_scale = 20.0
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().process_frame
	await get_tree().process_frame
	GameClock.paused = true

	_check_world_registrations()
	_check_binocular_views()
	await _check_pohono_loop(world)
	await _check_rim_south(world)
	await _check_cathedral_loop(world)
	await _check_hetch_hetchy(world)
	_check_finds_and_happenings()

	SaveManager.delete_save()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func _check_world_registrations() -> void:
	for id in ["taft_point", "cathedral_lakes", "hetch_hetchy"]:
		check(Backcountry.is_backcountry(id), "%s is a backcountry region" % id)
		check(id in Bobcats.MEADOWS, "%s is a bobcat meadow" % id)
	check(HighCountry.is_high("cathedral_lakes"), "Cathedral Lakes gets high-country air and weather")
	check("taft_point" in Discoveries.VIEWPOINTS, "Taft Point is a Valley-overlooking viewpoint")
	check("taft_point" in Falcons.CLIFFS and "hetch_hetchy" in Falcons.CLIFFS, "Peregrines hunt Taft Point and Hetch Hetchy cliffs")
	check("taft_point" in Owls.MEADOWS, "Great gray owls hunt Taft Point's Roosevelt Meadow")
	check("taft_point" in Critters.HIGH_REGIONS and "cathedral_lakes" in Critters.HIGH_REGIONS, "High-country critters inhabit Taft Point and Cathedral Lakes")
	# Flora registered in all three regions
	for id in ["taft_point", "cathedral_lakes", "hetch_hetchy"]:
		var plants := Herbarium.PLANTS.filter(func(p: Dictionary) -> bool: return p.grows.has(id))
		check(plants.size() >= 5, "%s grows %d press-book plants (at least 5)" % [id, plants.size()])


func _check_binocular_views() -> void:
	for view_id in ["taft_point", "union_point", "cathedral_pass", "hetch_hetchy"]:
		check(BinocularView.VIEWS.has(view_id), "BinocularView has '%s' panorama" % view_id)
		var spec: Dictionary = BinocularView.VIEWS[view_id]
		var scale := BinocularView.make_scale(spec)
		var rising := true
		for i in scale.size() - 1:
			rising = rising and scale[i + 1] > scale[i]
		check(rising, "%s compass scale rises monotonically" % view_id)
		var ordered := true
		var last := -INF
		var ids := {}
		for t: Dictionary in spec.targets:
			ids[t.id] = true
			var b := BinocularView.unwrap(float(t.bearing))
			ordered = ordered and b >= float(spec.from) and b <= float(spec.to) and b > last
			last = b
		check(ordered and ids.size() == spec.targets.size() and spec.targets.size() >= 5,
			"%s targets are in compass order with unique ids (%d targets)" % [view_id, spec.targets.size()])


func _check_pohono_loop(world: Node) -> void:
	NewGame.reset()
	GameClock.season = GameClock.Season.SUMMER
	GameClock.minutes = 8 * 60
	Discoveries.start_new_game()

	# Tunnel View -> Taft Point -> Glacier Point
	await world.go_to_region("tunnel_view", "arrival")
	await _settle(world)
	var up: RegionDoor = world.region.entities.get_node_or_null("PohonoTrailUp")
	check(up != null and up.target_region == "taft_point", "Tunnel View has PohonoTrailUp to Taft Point")
	up.interact(world.player)
	await _wait_region(world, "taft_point")
	check(world.region.region_id == "taft_point", "PohonoTrailUp arrives at Taft Point")
	for _i in 3:
		await get_tree().process_frame
	check(Discoveries.valley_seen, "arriving at Taft Point reveals the Valley map")
	check(world.region.entities.get_node_or_null("TaftPointViewer") is ScenicViewer, "Taft Point has its scenic viewer")
	check(world.region.entities.get_node_or_null("TaftPointCamp") is BackcountryCamp, "Taft Point has a backcountry camp")
	var fissures := world.region.find_child("FissuresSign", true, false) as InfoSign
	check(fissures != null and fissures.extra_text != "", "Taft Point's Fissures sign has its spring falcon Easter egg")

	# On east along the rim: the Pohono Trail walks straight over the map
	# edge into Glacier Point (a seam, no fade), and back.
	var east := world.region.find_child("PohonoTrailEast", true, false) as RegionExit
	check(east != null and east.target_region == "glacier_point" and east.minutes == 0,
		"Taft Point's Pohono Trail walks on east into Glacier Point")
	await world.go_to_region("glacier_point", east.target_spawn if east else "pohono_west")
	await _settle(world)
	check(world.region.region_id == "glacier_point", "the Pohono Trail arrives at Glacier Point")
	var back := world.region.find_child("PohonoTrailWest", true, false) as RegionExit
	check(back != null and back.target_region == "taft_point" and back.minutes == 0,
		"Glacier Point's Pohono Trail walks on west to Taft Point")

	# The Four Mile Trail: west from Glacier Point into Union Point, and down
	# the switchbacks to the Valley.
	var four_mile := world.region.find_child("FourMileTrailWest", true, false) as RegionExit
	check(four_mile != null and four_mile.target_region == "union_point" and four_mile.minutes == 0,
		"Glacier Point's Four Mile Trail walks on west to Union Point")
	await world.go_to_region("union_point", "east")
	await _settle(world)
	check(world.region.region_id == "union_point", "the Four Mile Trail arrives at Union Point")
	check(world.region.hub_id == "glacier_point", "Union Point counts under Glacier Point")
	check(world.region.entities.get_node_or_null("UnionPointViewer") is ScenicViewer, "Union Point has its scenic viewer")
	check(BinocularView.VIEWS.has("union_point"), "Union Point's viewer has a view")
	var down: RegionDoor = world.region.entities.get_node_or_null("FourMileTrailDown")
	check(down != null and down.target_region == "four_mile_trailhead" and down.minutes > 0,
		"Union Point's switchbacks go on down to the Four Mile trailhead")
	down.interact(world.player)
	await _wait_region(world, "four_mile_trailhead")
	check(world.region.region_id == "four_mile_trailhead", "the switchbacks arrive at the Four Mile trailhead")
	var up_again: RegionDoor = world.region.entities.get_node_or_null("FourMileTrail")
	check(up_again != null and up_again.target_region == "union_point", "the Four Mile trailhead leads up to Union Point")


func _check_rim_south(world: Node) -> void:
	GameClock.season = GameClock.Season.SUMMER
	GameClock.minutes = 8 * 60
	await world.go_to_region("glacier_point", "panorama_south")
	await _settle(world)
	# The Panorama Trail walks off Glacier Point's south edge into Illilouette Gorge.
	var panorama := world.region.find_child("PanoramaTrailSouth", true, false) as RegionExit
	check(panorama != null and panorama.target_region == "illilouette" and panorama.minutes == 0,
		"Glacier Point's Panorama Trail walks on south into Illilouette Gorge")
	var road := world.region.find_child("GlacierPointRoad", true, false) as RegionExit
	check(road != null and road.target_region == "bridalveil_creek" and road.minutes == 0,
		"Glacier Point Road walks on south into Bridalveil Creek")
	check(world.region.find_child("Travel_GlacierPointParking", true, false) is TravelPoint,
		"you can still drive from Glacier Point's lot")
	await world.go_to_region("illilouette", "north")
	await _settle(world)
	check(world.region.region_id == "illilouette" and world.region.hub_id == "glacier_point", "Illilouette Gorge counts under Glacier Point")
	check(world.region.walk_minutes > 0, "walking the Panorama Trail takes clock time")
	var mist: RegionDoor = world.region.entities.get_node_or_null("MistTrailDown")
	check(mist != null and mist.target_region == "happy_isles", "the top of Nevada Fall has the Mist Trail down to Happy Isles")
	var jmt: RegionDoor = world.region.entities.get_node_or_null("JohnMuirTrailEast")
	check(jmt != null and jmt.target_region == "little_yosemite_valley", "the top of Nevada Fall has the John Muir Trail on to Little Yosemite Valley")
	await world.go_to_region("bridalveil_creek", "north")
	await _settle(world)
	check(world.region.region_id == "bridalveil_creek" and world.region.hub_id == "glacier_point", "Bridalveil Creek counts under Glacier Point")
	var drive := world.region.find_child("GlacierPointRoadSouth", true, false) as RegionExit
	check(drive != null and drive.travel_to == "yosemite_valley", "the drive back to the Valley leaves from Bridalveil Creek")
	var mono: RegionDoor = world.region.entities.get_node_or_null("MonoMeadowTrail")
	check(mono != null and mono.target_region == "illilouette", "the Mono Meadow trail goes down to Illilouette Creek")


func _check_cathedral_loop(world: Node) -> void:
	GameClock.season = GameClock.Season.SUMMER
	GameClock.minutes = 8 * 60
	# The John Muir Trail walks straight on off Tuolumne's south edge into
	# Cathedral Lakes: an edge seam, no timed trip.
	await world.go_to_region("tuolumne_meadows", "cathedral_lakes_trail")
	await _settle(world)
	var trail: RegionExit = world.region.get_node_or_null("Exits/JMTSouth")
	check(trail != null and trail.target_region == "cathedral_lakes" and trail.minutes == 0,
		"Tuolumne Meadows' John Muir Trail walks on to Cathedral Lakes")
	for _i in 120:
		if world.seam != null and world.seam.neighbor.region_id == "cathedral_lakes":
			break
		await get_tree().process_frame
	check(world.seam != null and world.seam.neighbor.region_id == "cathedral_lakes",
		"Cathedral Lakes is laid out beside Tuolumne at the trail")
	Input.action_press("move_down")
	await _wait_region(world, "cathedral_lakes")
	Input.action_release("move_down")
	check(world.region.region_id == "cathedral_lakes", "the John Muir Trail arrives at Cathedral Lakes")
	var north: RegionExit = world.region.get_node_or_null("Exits/JMTNorth")
	check(north != null and north.target_region == "tuolumne_meadows" and north.minutes == 0,
		"Cathedral Lakes' John Muir Trail walks back down to Tuolumne")
	check(world.region.entities.get_node_or_null("CathedralPassViewer") is ScenicViewer, "Cathedral Lakes has its scenic viewer")
	check(world.region.entities.get_node_or_null("CathedralCamp") is BackcountryCamp, "Cathedral Lakes has a backcountry camp")
	var water: FishingWater = world.region.entities.get_node_or_null("LowerCathedralLakeWater")
	check(water != null and water.kind == "hole", "Lower Cathedral Lake has brook trout fishing water")

	# Continue south over Cathedral Pass to Tenaya Lake
	var south: RegionDoor = world.region.entities.get_node_or_null("JMTSouth")
	check(south != null and south.target_region == "tenaya_lake", "Cathedral Lakes has JMTSouth to Tenaya Lake")
	south.interact(world.player)
	await _wait_region(world, "tenaya_lake")
	check(world.region.region_id == "tenaya_lake", "JMTSouth arrives at Tenaya Lake")
	var north_back: RegionDoor = world.region.entities.get_node_or_null("CathedralPassTrail")
	check(north_back != null and north_back.target_region == "cathedral_lakes", "Tenaya Lake has CathedralPassTrail back to Cathedral Lakes")


func _check_hetch_hetchy(world: Node) -> void:
	# Hetch Hetchy is low-elevation and open all year, even in winter with open_world off.
	var was_open := Park.open_world
	Park.open_world = false
	GameClock.season = GameClock.Season.WINTER
	GameClock.minutes = 9 * 60
	await world.go_to_region("crane_flat", "arrival")
	await _settle(world)
	# Evergreen Road leaves Big Oak Flat Road west of Crane Flat, by the entrance.
	var road: RegionExit = world.region.find_child("BigOakFlatRoadWest", true, false)
	check(road != null and road.target_region == "hetch_hetchy" and road.minutes > 0,
		"Crane Flat's road west drives on to Hetch Hetchy, all year")
	world.use_exit(road)
	await _wait_region(world, "hetch_hetchy")
	check(world.region.region_id == "hetch_hetchy", "Hetch Hetchy can be visited in winter")
	check(world.region.entities.get_node_or_null("HetchHetchyViewer") is ScenicViewer, "Hetch Hetchy has its dam scenic viewer")
	check(world.region.entities.get_node_or_null("HetchHetchyCamp") is BackcountryCamp, "Hetch Hetchy has a backcountry camp")
	check(world.region.entities.get_node_or_null("WapamaCoveWater") is FishingWater, "Hetch Hetchy has fishing water")
	check(world.region.find_children("*", "TravelPoint", true, false).size() >= 1, "Hetch Hetchy has a TravelPoint kiosk")
	var dam := world.region.find_child("DamSign", true, false) as InfoSign
	check(dam != null and dam.extra_text != "", "Hetch Hetchy Dam sign has its evening Muir Easter egg")
	Park.open_world = was_open


func _check_finds_and_happenings() -> void:
	check(Finds.total() >= 30, "hidden finds expanded to %d (at least 30)" % Finds.total())
	for id in ["taft_fissures_stash", "taft_crocker_piton", "cathedral_jmt_rations", "cathedral_caddis_fly",
			"hetch_dam_insulator", "hetch_wapama_stash", "tenaya_creek_fly", "upper_pines_tin"]:
		var f := Finds.get_find(id)
		check(not f.is_empty() and f.has("pos"), "find %s is registered and placed" % id)
	for id in ["taft_fissures_sunset", "taft_pohono_hiker", "cathedral_lost_map", "cathedral_alpenglow",
			"hetch_muir_question", "hetch_wapama_roar"]:
		check(Happenings.HAPPENINGS.any(func(h: Dictionary) -> bool: return h.id == id),
			"happening %s is registered" % id)


func _settle(world: Node) -> void:
	await get_tree().process_frame
	while world._busy:
		await get_tree().process_frame


func _wait_region(world: Node, expected: String) -> void:
	for _i in 600:
		await get_tree().process_frame
		if not world._busy and world.region and world.region.region_id == expected:
			break
