extends Node
## Headless test of PR 2's park-wide reward function:
## - Trail Sense (25 places): -15% hub travel time + 2 more hidden-find rumors
## - Park Walker (60 places): +8% walking speed stacked with Muir's Stride
## - Quiet Step (10 animals): halved bird/squirrel spook distance, +30% spot range
## - Master Fly Box (10 fish caught): bigger fish/trophy curve + 10 min casts
## - Gallery Eye (8 shot-list photos): +15% store trade value + +10 Village Store tab on 3-star prints
## - Night Trail (5 happenings): grants wearable Trail Headlamp, night light, +1h late travel
## - Richer Happenings and Festivals payouts + save/load persistence.
## Run: godot --headless --path . res://tests/reward_function_test.tscn

const VILLAGE_STORE := preload("res://data/shops/village_store.tres")
const CAMP4_RACK := preload("res://data/shops/camp4_rack.tres")

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	SaveManager.save_path = "user://reward_function_test_save.json"
	SaveManager.delete_save()
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().process_frame
	await get_tree().process_frame
	GameClock.paused = true

	await test_trail_sense_and_park_walker(world)
	test_quiet_step()
	test_master_fly_box()
	test_gallery_eye()
	test_night_trail_and_headlamp(world)
	test_upgraded_happenings_and_festivals()
	test_save_and_load()

	SaveManager.delete_save()
	_clear_photos()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func _clear_photos() -> void:
	var folder := DirAccess.open(Photos.dir())
	if folder == null:
		return
	for file in folder.get_files():
		folder.remove(file)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Photos.dir()))


func test_trail_sense_and_park_walker(world: Node) -> void:
	NewGame.reset()
	Park.unlock_hub("glacier_point")
	var base_legs := Park.legs_from("yosemite_valley")
	var gp_before := 0
	for leg in base_legs:
		if leg.to == "glacier_point":
			gp_before = int(leg.minutes)
	check(gp_before > 0, "Glacier Point leg has a baseline travel time (%d min)" % gp_before)
	check(Finds.rumor_limit() == Finds.RUMORS, "rumor limit starts at %d" % Finds.RUMORS)

	# Discover 25 named places -> Trail Sense
	for i in 24:
		Discoveries.found["test_place_%d" % i] = true
	Discoveries.changed.emit()
	check(not Perks.has("trail_sense"), "24 places is not yet enough for Trail Sense")
	Discoveries.found["test_place_24"] = true
	Discoveries.changed.emit()
	check(Perks.has("trail_sense"), "25 discovered places earns Trail Sense")

	var faster_legs := Park.legs_from("yosemite_valley")
	var gp_after := 0
	for leg in faster_legs:
		if leg.to == "glacier_point":
			gp_after = int(leg.minutes)
	check(gp_after < gp_before and gp_after == maxi(1, roundi(gp_before * (1.0 - Perks.bonus("trail_sense")))),
		"Trail Sense reduces hub travel time by 15%% (%d -> %d min)" % [gp_before, gp_after])
	check(Finds.rumor_limit() == Finds.RUMORS + 2, "Trail Sense adds 2 hidden-find rumors (%d)" % Finds.rumor_limit())

	# Discover 60 named places -> Park Walker
	for i in range(25, 60):
		Discoveries.found["test_place_%d" % i] = true
	Discoveries.changed.emit()
	check(Perks.has("park_walker"), "60 discovered places earns Park Walker")

	# Verify Park Walker stacks with Muir's Stride on player speed
	var player: Player = world.player
	Input.action_press("move_right")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var walker_speed := player.velocity.length()
	Input.action_release("move_right")
	await get_tree().physics_frame
	check(walker_speed > Player.SPEED * 1.05, "Park Walker boosts walking speed (%.1f vs %.1f)" % [walker_speed, Player.SPEED])

	Perks.note("mornings", 14)
	check(Perks.has("muirs_stride"), "14 mornings earns Muir's Stride")
	Input.action_press("move_right")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var stacked_speed := player.velocity.length()
	Input.action_release("move_right")
	await get_tree().physics_frame
	check(stacked_speed > walker_speed + 5.0, "Park Walker stacks with Muir's Stride (%.1f > %.1f)" % [stacked_speed, walker_speed])


func test_quiet_step() -> void:
	NewGame.reset()
	check(is_equal_approx(Critters.flee_distance(), Critters.FLEE_DISTANCE), "bird flee distance starts at default")
	check(is_equal_approx(Critters.squirrel_flee(), Critters.SQUIRREL_FLEE), "squirrel flee distance starts at default")
	check(is_equal_approx(Critters.spot_distance(), Critters.SPOT_DISTANCE), "spot distance starts at default")
	check(is_equal_approx(Critters.spot_butterfly(), Critters.SPOT_BUTTERFLY), "butterfly spot distance starts at default")

	var animals := FieldLog.ANIMALS
	for i in 9:
		FieldLog.spot(animals[i].id, true)
	check(not Perks.has("quiet_step"), "9 animals is not yet enough for Quiet Step")
	FieldLog.spot(animals[9].id, true)
	check(Perks.has("quiet_step"), "10 wildlife log entries earns Quiet Step")
	check(is_equal_approx(Critters.flee_distance(), Critters.FLEE_DISTANCE * 0.5),
		"Quiet Step halves bird spook distance (%.1f)" % Critters.flee_distance())
	check(is_equal_approx(Critters.squirrel_flee(), Critters.SQUIRREL_FLEE * 0.5),
		"Quiet Step halves squirrel spook distance (%.1f)" % Critters.squirrel_flee())
	check(is_equal_approx(Critters.spot_distance(), Critters.SPOT_DISTANCE * 1.3),
		"Quiet Step widens spotting range by 30%% (%.1f)" % Critters.spot_distance())
	check(is_equal_approx(Critters.spot_butterfly(), Critters.SPOT_BUTTERFLY * 1.3),
		"Quiet Step widens butterfly spotting range by 30%% (%.1f)" % Critters.spot_butterfly())


func test_master_fly_box() -> void:
	NewGame.reset()
	var trout := Fishing.get_fish("brown_trout")
	var before := Fishing.hooked(trout, "run", 0.7)
	check(Fishing.cast_minutes() == Fishing.CAST_MINUTES, "casts start at %d minutes" % Fishing.CAST_MINUTES)
	check(not before.trophy, "0.7 roll in a run is not a trophy before Master Fly Box")

	for i in 9:
		Achievements.caught({"id": "brown_trout", "length": 14, "trophy": false})
	check(not Perks.has("master_fly_box"), "9 fish caught is not yet enough for Master Fly Box")
	Achievements.caught({"id": "brown_trout", "length": 15, "trophy": false})
	check(Perks.has("master_fly_box"), "10 fish caught earns Master Fly Box")
	check(Fishing.cast_minutes() == 10, "Master Fly Box cuts cast time to 10 minutes")

	var after := Fishing.hooked(trout, "run", 0.7)
	check(after.length > before.length, "Master Fly Box increases fish length on the same roll (%d vs %d in)" % [after.length, before.length])
	var hole_before_share := pow(0.65, float(Fishing.SIZE_POWER["hole"]))
	var hole_after := Fishing.hooked(trout, "hole", 0.65)
	check(hole_before_share < Fishing.TROPHY and hole_after.trophy,
		"Master Fly Box boosts trophy odds in deep pools")


func test_gallery_eye() -> void:
	NewGame.reset()
	var base_store := TradeValues.worth_to(VILLAGE_STORE, "morel_mushroom")
	var base_climber := TradeValues.worth_to(CAMP4_RACK, "morel_mushroom")

	for i in 7:
		Photos.listed[Photos.SHOT_LIST[i].id] = {"day": 1, "title": "Test %d" % i}
	Photos.changed.emit()
	check(not Perks.has("gallery_eye"), "7 shot-list entries is not yet enough for Gallery Eye")
	Photos.listed[Photos.SHOT_LIST[7].id] = {"day": 1, "title": "Test 7"}
	Photos.changed.emit()
	check(Perks.has("gallery_eye"), "8 shot-list entries earns Gallery Eye")

	var boosted_store := TradeValues.worth_to(VILLAGE_STORE, "morel_mushroom")
	var after_climber := TradeValues.worth_to(CAMP4_RACK, "morel_mushroom")
	check(is_equal_approx(boosted_store, base_store * 1.15),
		"Gallery Eye boosts store trade value by 15%% (%.2f -> %.2f)" % [base_store, boosted_store])
	check(is_equal_approx(after_climber, base_climber),
		"Gallery Eye leaves non-store climber trade value unchanged")

	# 3-star photograph earns +10 Village Store tab credit; 1-star earns none
	Market.set_tab("village_store", 0)
	var one_star_view := {"region": "el_capitan_meadow", "region_name": "El Capitan Meadow", "where": "El Capitan Meadow",
		"indoors": false, "season": GameClock.Season.SUMMER, "light": "midday", "snow": false, "rain": false, "subjects": []}
	var p1 := Photos.develop(one_star_view)
	check(int(p1.stars) == 1 and int(p1.get("gallery_credit", 0)) == 0 and Market.tab("village_store") == 0,
		"1-star photo earns no Gallery Eye tab credit")

	var three_star_view := {"region": "el_capitan_meadow", "region_name": "El Capitan Meadow", "where": "El Capitan Meadow",
		"indoors": false, "season": GameClock.Season.SUMMER, "light": "last_light", "snow": false, "rain": false,
		"subjects": [{"kind": "animal", "id": "black_bear", "name": "American Black Bear", "at": Vector2.ZERO}]}
	var p3 := Photos.develop(three_star_view)
	check(int(p3.stars) == 3 and int(p3.get("gallery_credit", 0)) == 10 and Market.tab("village_store") == 10,
		"3-star photo earns +10 Village Store tab credit (%d)" % Market.tab("village_store"))


func test_night_trail_and_headlamp(world: Node) -> void:
	NewGame.reset()
	var headlamp := Gear.get_gear("headlamp")
	check(headlamp != null and headlamp.keepsake, "Trail Headlamp gear exists as a keepsake")
	check(Gear.count("headlamp") == 0, "player starts without Trail Headlamp")

	var player: Player = world.player
	var lamp: Node2D = player.get_node_or_null("HeadlampLight")
	check(lamp != null and not lamp.visible, "player has HeadlampLight, hidden without headlamp")

	# Travel cutoff before headlamp: 12:15 AM + 60 min = 1:15 AM (past 1 AM cutoff)
	GameClock.minutes = 24 * 60 + 15
	check(GameClock.is_too_late_for(60), "at 12:15 AM, a 60 min trip is too late without headlamp")

	for i in 4:
		Happenings.seen[Happenings.HAPPENINGS[i].id] = 1
	Happenings.changed.emit()
	check(not Perks.has("night_trail"), "4 happenings is not yet enough for Night Trail")

	Happenings.seen[Happenings.HAPPENINGS[4].id] = 1
	Happenings.changed.emit()
	check(Perks.has("night_trail"), "5 happenings earns Night Trail")
	check(Gear.count("headlamp") == 1, "Night Trail grants the wearable Trail Headlamp")
	check(lamp != null and lamp.visible, "HeadlampLight activates once Trail Headlamp is owned")
	check(not GameClock.is_too_late_for(60), "Trail Headlamp lets you depart an hour later (12:15 AM + 60 min allowed)")


func test_upgraded_happenings_and_festivals() -> void:
	var multi_happenings := 0
	for h: Dictionary in Happenings.HAPPENINGS:
		var total_items := 0
		for id: String in h.reward:
			total_items += int(h.reward[id])
		if total_items >= 2:
			multi_happenings += 1
	check(multi_happenings == Happenings.HAPPENINGS.size(),
		"every happening gives a meaningful multi-item reward (%d/%d)" % [multi_happenings, Happenings.HAPPENINGS.size()])

	for f: Dictionary in Festivals.FESTIVALS:
		check(int(f.points) >= 100 and f.reward.size() >= 3,
			"%s awards at least 100 friendship and 3+ items (%d pts, %d kinds)" % [f.name, int(f.points), f.reward.size()])


func test_save_and_load() -> void:
	# Earn a few new perks and verify persistence across save/load
	NewGame.reset()
	for i in 25:
		Discoveries.found["p_%d" % i] = true
	Discoveries.changed.emit()
	for i in 5:
		Happenings.seen[Happenings.HAPPENINGS[i].id] = 1
	Happenings.changed.emit()
	check(Perks.has("trail_sense") and Perks.has("night_trail") and Gear.count("headlamp") == 1,
		"earned Trail Sense and Night Trail before save")
	SaveManager.save_game()
	NewGame.reset()
	check(not Perks.has("trail_sense") and not Perks.has("night_trail") and Gear.count("headlamp") == 0,
		"NewGame clears milestone perks and headlamp")
	check(SaveManager.load_game(), "save loads cleanly")
	check(Perks.has("trail_sense") and Perks.has("night_trail") and Gear.count("headlamp") == 1,
		"milestone perks and Trail Headlamp survive save/load")
