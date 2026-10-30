extends Node
## Plays the first night out and Half Dome: the permit and the bear canister
## from Ranger Hodges, the trail up from Happy Isles to Little Yosemite
## Valley, sleeping out in the backcountry camp (you wake up there, and the
## bears get whatever isn't in the canister), the cables up the back of the
## Dome (the meter, the crowds, and when they're shut), the summit Snake Dike
## tops out on, the Diving Board's afternoon light, and the three quests.
## Run: godot --headless --path . res://tests/half_dome_test.tscn
## Exit code is the number of failed checks. Uses its own save file.

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func said(lines: Array[Dictionary], text: String) -> bool:
	return lines.any(func(l: Dictionary) -> bool: return text in l.text)


func _ready() -> void:
	await get_tree().process_frame
	SaveManager.save_path = "user://half_dome_test_save.json"
	SaveManager.delete_save()
	var world = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(world)
	await get_tree().process_frame
	GameClock.paused = true
	test_data()
	test_cables_meter()
	test_cables_closed()
	test_night_out()
	test_quests()
	await test_places(world)
	await test_sleep_out(world)
	SaveManager.delete_save()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func _fresh() -> void:
	Inventory.start_new_game()
	Gear.start_new_game()
	QuestLog.start_new_game()
	FieldLog.start_new_game()


func test_data() -> void:
	var canister := Gear.get_gear(Backcountry.CANISTER)
	check(canister != null and canister.icon != null, "the bear canister is gear, with an icon")
	var permit := ItemDB.get_item(Backcountry.PERMIT)
	check(permit != null and permit.icon != null, "the wilderness permit is an item, with an icon")
	for id in ["hodges_first_night", "anderson_cables", "ansel_diving_board"]:
		check(QuestLog.get_quest(id) != null and RegisterPages.HISTORY.has(id), "%s is a quest with a Register note" % id)
	var snake: RouteData = load("res://data/routes/snake_dike.tres")
	check(snake.destination() == "half_dome" and snake.destination_hub == "", "Snake Dike tops out on Half Dome without unlocking a hub")
	check(Park.SEASONAL.has("half_dome_cables"), "the cables come down for the winter")


func _game(crowd: String) -> CablesMinigame:
	var game := CablesMinigame.new()
	add_child(game)
	game.set_process(false)
	game.start(crowd, 7)
	return game


## Waits out the meter opening, then pulls: on the green's middle, near its
## edge, or off it.
func _pull(game: CablesMinigame, result: String) -> void:
	game.step(CablesMinigame.GRACE + 0.01)
	var half := game.window() / 2.0
	match result:
		"perfect":
			game.meter_pos = game.meter_center
		"good":
			game.meter_pos = game.meter_center + half * 0.8
		_:
			game.meter_pos = clampf(game.meter_center + half + 0.06, 0.0, 1.0)
	game.press()


func test_cables_meter() -> void:
	check(CablesMinigame.crowd_for(6.5, GameClock.Season.SUMMER) == "dawn", "at first light you have the cables to yourself")
	check(CablesMinigame.crowd_for(12.0, GameClock.Season.SUMMER) == "crowded", "a summer noon has a line on the cables")
	check(CablesMinigame.crowd_for(12.0, GameClock.Season.FALL) == "quiet", "a fall noon is quiet")
	var dawn := _game("dawn")
	var crowded := _game("crowded")
	check(dawn.window() > crowded.window(), "the green is wider at dawn than in a crowd")
	crowded.free()
	for i in CablesMinigame.BOARDS:
		_pull(dawn, "perfect")
	check(dawn.outcome == "summit" and dawn.board == CablesMinigame.BOARDS, "clean pulls all the way up reach the top")
	check(dawn.grip >= 1.0, "clean pulls keep your grip")
	dawn.free()
	var tired := _game("quiet")
	_pull(tired, "good")
	check(tired.board == 1 and tired.grip < 1.0, "a good pull goes up a board and costs a little grip")
	_pull(tired, "miss")
	check(tired.board == 1 and tired.last_stop == "miss", "a missed pull slips and doesn't climb")
	for i in 5:
		_pull(tired, "miss")
	check(tired.outcome == "backed_down", "run out of grip and you back down to the foot")
	tired.free()
	var quit := _game("quiet")
	quit.give_up()
	check(quit.outcome == "gave_up", "you can climb back down any time")
	quit.free()


func test_cables_closed() -> void:
	_fresh()
	GameClock.season = GameClock.Season.SUMMER
	GameClock.day = 10
	check(HalfDomeCables.closed_reason().contains("permit") or HalfDomeCables.closed_reason().contains("Rain"), "without a permit the cables are off limits")
	Inventory.add(Backcountry.PERMIT)
	# find a dry summer day
	for d in range(1, 29):
		GameClock.day = d
		if float(Weather.today().get("rain", 0.0)) <= 0.0:
			break
	check(HalfDomeCables.closed_reason() == "", "with a permit, on a dry summer day, the cables are open")
	GameClock.season = GameClock.Season.WINTER
	check(HalfDomeCables.closed_reason() == Park.SEASONAL["half_dome_cables"].why, "in winter the posts are down")
	GameClock.season = GameClock.Season.SPRING
	GameClock.day = 1
	check(not Park.is_open("half_dome_cables"), "in early spring they're still down")
	GameClock.day = 26
	check(Park.is_open("half_dome_cables"), "they go up in late May")


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	return rng


func test_night_out() -> void:
	_fresh()
	Inventory.add("pilot_bread", 4)
	var line := Backcountry.night_out(_rng())
	check(Inventory.count("pilot_bread") == 2 and line.contains("bear"), "with no canister, a bear eats half the food in your pack")
	check(not QuestLog.is_unlocked(Backcountry.NIGHT_OUT), "and the night doesn't count for Ranger Hodges")
	_fresh()
	Gear.add(Backcountry.CANISTER)
	Inventory.add("pilot_bread", 6)
	Inventory.add("beef_jerky", 4)
	Backcountry.night_out(_rng())
	check(Inventory.count("pilot_bread") == 6 and Inventory.count("beef_jerky") == 4, "everything fits in the canister, and it's all there in the morning")
	check(QuestLog.is_unlocked(Backcountry.NIGHT_OUT), "a night with your food in the canister counts")
	Inventory.add("pilot_bread", 10)
	var before := FoodDB.carried_energy()
	line = Backcountry.night_out(_rng())
	var total := Inventory.count("pilot_bread") + Inventory.count("beef_jerky")
	check(total < 20 and total >= Backcountry.CANISTER_HOLDS and FoodDB.carried_energy() < before, "an overfull canister leaves food out, and a bear finds it (%d of 20 left)" % total)
	check(line.contains("canister was full"), "the morning says the canister was full")


func test_quests() -> void:
	_fresh()
	QuestLog.completed.append_array(["hodges_patrol", "anderson_half_dome", "ansel_monolith"])
	var lines := QuestLog.talk_to("clare_hodges")
	check(QuestLog.active.has("hodges_first_night"), "Ranger Hodges offers the first night out")
	Inventory.add("pilot_bread", 4)
	lines = QuestLog.talk_to("clare_hodges")
	check(Backcountry.has_permit() and Backcountry.has_canister(), "show her two days' food and she hands over the permit and a canister")
	QuestLog.talk_to("george_anderson")
	check(not QuestLog.active.has("anderson_cables"), "Anderson's cables wait for the first night out")
	Backcountry.mark(Backcountry.NIGHT_OUT)
	lines = QuestLog.talk_to("clare_hodges")
	lines = QuestLog.talk_to("clare_hodges") if QuestLog.active.has("hodges_first_night") else lines
	check(QuestLog.is_completed("hodges_first_night"), "a night out finishes The First Night Out")
	QuestLog.talk_to("george_anderson")
	check(QuestLog.active.has("anderson_cables"), "then Anderson sends you up the cables")
	Backcountry.mark(Backcountry.CABLES)
	QuestLog.talk_to("george_anderson")
	check(QuestLog.is_completed("anderson_cables"), "going up the cables finishes Anderson's Cables")
	QuestLog.talk_to("ansel_adams")
	check(QuestLog.active.has("ansel_diving_board"), "Ansel Adams sends you to the Diving Board")
	GameClock.minutes = 11 * 60
	check(not DivingBoard.face_lit(), "at eleven the face is in flat light")
	GameClock.minutes = 16 * 60
	check(DivingBoard.face_lit(), "at four the light is on the face")
	Backcountry.mark(Backcountry.DIVING_BOARD)
	QuestLog.talk_to("ansel_adams")
	check(QuestLog.is_completed("ansel_diving_board"), "the afternoon light finishes The Diving Board")
	GameClock.minutes = GameClock.DAY_START_HOUR * 60


func _find(region: Region, type_name: String) -> Array:
	return region.find_children("*", "", true, false).filter(func(n: Node) -> bool:
		return n.get_script() != null and n.get_script().get_global_name() == type_name)


func test_places(world: Node) -> void:
	world._enter_region("happy_isles", "arrival")
	await get_tree().physics_frame
	var doors: Array = world.region.find_children("*", "RegionDoor", true, false).filter(func(d: RegionDoor) -> bool:
		return d.target_region == "little_yosemite_valley")
	check(doors.size() == 1 and doors[0].closure == "mist_trail", "a trail from Happy Isles goes up to Little Yosemite Valley, shut for snow in winter")
	world._enter_region("little_yosemite_valley", "jmt")
	await get_tree().physics_frame
	check(world.region.hub_id == "yosemite_valley", "Little Yosemite Valley is part of the Valley")
	check(_find(world.region, "BackcountryCamp").size() == 1, "it has a backcountry camp")
	check(world.region.find_children("*", "Station", true, false).size() >= 1, "and a fire ring to cook at")
	check(world.region.get_spawn("camp") != null, "and a spot to wake up in")
	world._enter_region("half_dome", "trailhead")
	await get_tree().physics_frame
	var cables: Array = world.region.find_children("*", "HalfDomeCables", true, false)
	var up: Array = cables.filter(func(c: HalfDomeCables) -> bool: return c.up and c.target_spawn == "summit")
	var down: Array = cables.filter(func(c: HalfDomeCables) -> bool: return not c.up and c.target_spawn == "cables_foot")
	check(up.size() == 1 and down.size() == 1, "the cables go up from the saddle and down from the summit")
	for spot in ["summit", "cables_foot", "snake_dike_top", "diving_board"]:
		check(world.region.get_spawn(spot) != null, "Half Dome has a %s spot" % spot)
	check(_find(world.region, "DivingBoard").size() == 1 and _find(world.region, "SummitMoment").size() == 1, "the Diving Board and the summit view are there")


func test_sleep_out(world: Node) -> void:
	_fresh()
	Gear.add(Backcountry.CANISTER)
	Inventory.add(Backcountry.PERMIT)
	Inventory.add("pilot_bread", 3)
	world._enter_region("little_yosemite_valley", "camp")
	await get_tree().physics_frame
	var date := [GameClock.season, GameClock.day]
	await world.sleep(false, "camp")
	check(world.region.region_id == "little_yosemite_valley", "sleeping out, you wake up in Little Yosemite Valley")
	check([GameClock.season, GameClock.day] != date, "and it's the next day")
	check(world.player.global_position.distance_to(world.region.get_spawn("camp").global_position) < 64.0, "beside your tent")
	check(Inventory.count("pilot_bread") == 3 and QuestLog.is_unlocked(Backcountry.NIGHT_OUT), "with your food safe in the canister")
	var saved := SaveManager.peek_node(world.name)
	check(str(saved.get("region", "")) == "little_yosemite_valley", "and the game saved there")
	await world.sleep()
	check(world.region.region_id == Park.HOME_REGION, "the tent at home still takes you home")
