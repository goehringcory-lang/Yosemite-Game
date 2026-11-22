extends Node
## Headless test of PR 3: backcountry foot traverse (LYV <-> Tenaya Lake),
## Tenaya Lake camp & brook trout basin, outer-hub Travelers (Tuolumne & Wawona),
## regional BulletinBoards & outer-hub BoardRequests, outer-hub Rescues, and the
## Search-and-Rescue Pack canister capacity payoff.
## Run: godot --headless --path . res://tests/backcountry_hubs_test.tscn

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	SaveManager.save_path = "user://backcountry_hubs_test_save.json"
	SaveManager.delete_save()
	Engine.time_scale = 20.0
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().process_frame
	await get_tree().process_frame
	GameClock.paused = true

	await test_sunrise_traverse_and_tenaya_content(world)
	await test_regional_boards(world)
	test_outer_hub_travelers()
	test_outer_hub_rescues_and_sar_pack()

	SaveManager.delete_save()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func test_sunrise_traverse_and_tenaya_content(world: Node) -> void:
	NewGame.reset()
	GameClock.season = GameClock.Season.SUMMER
	GameClock.day = 5
	GameClock.minutes = 9 * 60

	await world.go_to_region("little_yosemite_valley", "half_dome_trail")
	var up: RegionDoor = world.region.entities.get_node_or_null("SunriseTrailUp")
	check(up != null and up.target_region == "tenaya_lake" and up.target_spawn == "sunrise_trailhead" and up.closure == "tioga_road",
		"LYV has SunriseTrailUp leading to Tenaya Lake (tioga_road seasonal closure)")

	# Closed in winter
	GameClock.season = GameClock.Season.WINTER
	up.interact(world.player)
	await get_tree().process_frame
	check(world.region.region_id == "little_yosemite_valley", "Sunrise Trail is shut in winter")

	# Open in summer: walk through to Tenaya Lake
	GameClock.season = GameClock.Season.SUMMER
	GameClock.minutes = 9 * 60
	var before := GameClock.minutes
	up.interact(world.player)
	for i in 600:
		await get_tree().process_frame
		if not world._busy and world.region.region_id == "tenaya_lake":
			break
	check(world.region.region_id == "tenaya_lake", "Sunrise Trail walks on foot from LYV to Tenaya Lake")
	check(GameClock.minutes - before == up.minutes, "Sunrise Trail hike takes %d minutes (%d)" % [up.minutes, GameClock.minutes - before])

	# Tenaya Lake content: SunriseTrailDown, BackcountryCamp, TenayaLakeBasin
	var down: RegionDoor = world.region.entities.get_node_or_null("SunriseTrailDown")
	var camp: BackcountryCamp = world.region.entities.get_node_or_null("TenayaCamp")
	var water: FishingWater = world.region.entities.get_node_or_null("TenayaLakeBasin")
	check(down != null and down.target_region == "little_yosemite_valley" and down.target_spawn == "half_dome_trail",
		"Tenaya Lake has SunriseTrailDown back to LYV")
	check(camp != null and camp.wake_spot == "sunrise_trailhead" and camp.place_name == "Tenaya Lake",
		"Tenaya Lake has a backcountry camp site at Sunrise Trailhead")
	check(Backcountry.is_backcountry("tenaya_lake"), "Tenaya Lake counts as a backcountry region")
	check(water != null and water.kind == "hole" and water.title == "Tenaya Lake Basin",
		"Tenaya Lake has a brook trout deep-water basin")


func test_regional_boards(world: Node) -> void:
	await world.go_to_region("tuolumne_meadows", "arrival")
	var t_board: Node = world.region.entities.get_node_or_null("TuolumneBoard")
	check(t_board is BulletinBoard, "Tuolumne Meadows has a working BulletinBoard")
	if t_board is BulletinBoard:
		t_board.interact(world.player)
		check(world.hud.info_panel.visible and "Tuolumne Meadows Trailhead Board" in world.hud.info_title.text,
			"reading TuolumneBoard opens the board panel")
		world.hud.hide_info()

	await world.go_to_region("wawona", "wawona_hotel")
	var w_board: Node = world.region.entities.get_node_or_null("WawonaBoard")
	check(w_board is BulletinBoard, "Wawona has a working BulletinBoard")
	if w_board is BulletinBoard:
		w_board.interact(world.player)
		check(world.hud.info_panel.visible and "Wawona Bulletin Board" in world.hud.info_title.text,
			"reading WawonaBoard opens the board panel")
		world.hud.hide_info()

	for id in ["kochakji_bilberries", "kochakji_brook_trout", "clark_wawona_plums", "hodges_wawona_boletes"]:
		var note := BoardRequests.get_note(id)
		check(not note.is_empty() and note.has("hub"), "outer-hub board note %s is registered (%s)" % [id, note.get("hub", "")])


func test_outer_hub_travelers() -> void:
	for id in ["traveler_thru_hiker", "traveler_wawona_walker"]:
		check(Travelers.PLANS.has(id), "%s is in Travelers.PLANS" % id)
		var dry := Travelers.day_of(id, GameClock.Season.SUMMER, false)
		var wet := Travelers.day_of(id, GameClock.Season.SUMMER, true)
		check(dry.size() >= 4, "%s has a full dry summer schedule (%d segments)" % [id, dry.size()])
		check(wet.size() == 1 and wet[0].get("rest", false), "%s takes a rest day in the rain" % id)


func test_outer_hub_rescues_and_sar_pack() -> void:
	NewGame.reset()
	QuestLog.completed.append_array([Rescues.JOIN_QUEST, Rescues.FIRST_QUEST])
	GameClock.season = GameClock.Season.SUMMER

	# Outer-hub calls stay gated until hubs unlock (when gated progression is on)
	var was_open := Park.open_world
	Park.open_world = false
	var locked_ids := Rescues.eligible().map(func(c: Dictionary) -> String: return c.id)
	check(not "tenaya_lake_hypothermia" in locked_ids and not "cathedral_peak_stranded" in locked_ids,
		"outer-hub Tuolumne rescue calls wait until Tuolumne Meadows is unlocked")

	Park.unlock_hub("tuolumne_meadows")
	Park.unlock_hub("wawona")
	Park.open_world = was_open
	QuestLog.climbed.append("cathedral_peak")
	Weather.today()
	Weather._today = {"snow": 0.0, "rain": 0.0, "clouds": 0.2}
	var open_ids := Rescues.eligible().map(func(c: Dictionary) -> String: return c.id)
	check("tenaya_lake_hypothermia" in open_ids and "cathedral_peak_stranded" in open_ids and "wawona_grove_lost" in open_ids,
		"unlocking Tuolumne & Wawona opens their rescue calls")

	GameClock.season = GameClock.Season.WINTER
	var winter_ids := Rescues.eligible().map(func(c: Dictionary) -> String: return c.id)
	check("crane_flat_snowbound" in winter_ids, "Crane Flat snowbound call comes in winter")

	# Search-and-Rescue Pack canister upgrade after 3 rescues
	check(Backcountry.canister_capacity() == Backcountry.CANISTER_HOLDS,
		"bear canister holds %d items before 3 rescues" % Backcountry.CANISTER_HOLDS)
	for i in 2:
		Rescues.begin("four_mile_overdue")
		Rescues.stage = Rescues.active_call().stages.size() - 1
		Rescues.talk_to(Rescues.LEAD)
	check(Backcountry.canister_capacity() == Backcountry.CANISTER_HOLDS,
		"2 rescues is not yet enough for the Search-and-Rescue Pack")

	Rescues.begin("wawona_grove_lost")
	Rescues.stage = Rescues.active_call().stages.size() - 1
	var lines := Rescues.talk_to(Rescues.LEAD)
	check(lines.any(func(l: Dictionary) -> bool: return "Search-and-Rescue Pack" in l.text),
		"3rd rescue announces the Search-and-Rescue Pack upgrade")
	check(Backcountry.canister_capacity() == Backcountry.SAR_CANISTER_HOLDS,
		"bear canister capacity expands to %d items after 3 rescues" % Backcountry.SAR_CANISTER_HOLDS)

	# 18 food items stay 100% safe overnight with the upgraded canister!
	Inventory.items.clear()
	Inventory.add("trail_mix", 18)
	Gear.add(Backcountry.CANISTER)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	Backcountry.night_out(rng)
	check(Inventory.count("trail_mix") == 18,
		"18 items survive a backcountry night untouched in the upgraded 20-item canister")
