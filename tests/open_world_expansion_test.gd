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
	for view_id in ["taft_point", "cathedral_pass", "hetch_hetchy"]:
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

	# On east to Glacier Point, then back to Taft Point
	var east: RegionDoor = world.region.entities.get_node_or_null("PohonoTrailEast")
	check(east != null and east.target_region == "glacier_point" and east.needs_hub == "glacier_point",
		"Taft Point has PohonoTrailEast to Glacier Point")
	east.interact(world.player)
	await _wait_region(world, "glacier_point")
	check(world.region.region_id == "glacier_point", "PohonoTrailEast arrives at Glacier Point")
	var back: RegionDoor = world.region.entities.get_node_or_null("PohonoTrailToTaft")
	check(back != null and back.target_region == "taft_point", "Glacier Point has PohonoTrailToTaft back to Taft Point")


func _check_cathedral_loop(world: Node) -> void:
	GameClock.season = GameClock.Season.SUMMER
	GameClock.minutes = 8 * 60
	await world.go_to_region("tuolumne_meadows", "cathedral_lakes_trailhead")
	await _settle(world)
	var trail: RegionDoor = world.region.entities.get_node_or_null("CathedralLakesTrail")
	check(trail != null and trail.target_region == "cathedral_lakes", "Tuolumne Meadows has CathedralLakesTrail")
	trail.interact(world.player)
	await _wait_region(world, "cathedral_lakes")
	check(world.region.region_id == "cathedral_lakes", "CathedralLakesTrail arrives at Cathedral Lakes")
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
