extends Node
## Headless test of "Down Before the Snow": Marty's down puffy quest (offered
## summer to winter, not spring), the torn jacket at Camp 4, the mending and
## the trade, and what the jacket does (Warmth): slower walking out in the
## winter cold without it, the late-fall nudges, and on the wall a warm bivy
## and no slush. Save and load keeps it.
## Run: godot --headless --path . res://tests/puffy_test.tscn
## Exit code is the number of failed checks.

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	SaveManager.save_path = "user://puffy_test_save.json"
	SaveManager.delete_save()
	test_definitions()
	test_offered()
	test_quest()
	test_cold()
	test_nudges()
	test_climbing()
	test_save_and_load()
	SaveManager.delete_save()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func new_game(season: int, day := 3) -> void:
	NewGame.reset()
	GameClock.season = season
	GameClock.day = day
	GameClock.minutes = 10 * 60
	Warmth.outdoors = true
	for id in ["clark_register", "shop_guidebook", "shop_outfit"]:
		QuestLog.completed.append(id)


func test_definitions() -> void:
	var quest := QuestLog.get_quest(Warmth.QUEST)
	check(quest != null and quest.giver == "mountain_shop", "Marty gives Down Before the Snow")
	check(Gear.get_gear(Warmth.JACKET) != null and Gear.get_gear(Warmth.JACKET).icon != null, "the puffy is gear, with an icon")
	check(ItemDB.get_item("torn_puffy") != null and ItemDB.get_item("torn_puffy").icon != null, "the torn puffy is an item, with an icon")
	var overlay: Node = load("res://scenes/story/content/yosemite_village.tscn").instantiate()
	var pickup := overlay.get_node_or_null("Camp4TornPuffy") as StoryPickup
	check(pickup != null and pickup.item_id == "torn_puffy", "the torn puffy lies at Camp 4")
	overlay.free()


func test_offered() -> void:
	new_game(GameClock.Season.SPRING)
	check(QuestLog.available_from("mountain_shop") == null, "not offered in spring")
	check(QuestLog.waiting_for_season("mountain_shop") == QuestLog.get_quest(Warmth.QUEST), "in spring Marty says to come back")
	for season in [GameClock.Season.SUMMER, GameClock.Season.FALL, GameClock.Season.WINTER]:
		GameClock.season = season
		check(QuestLog.available_from("mountain_shop") == QuestLog.get_quest(Warmth.QUEST), "offered in %s" % GameClock.SEASON_NAMES[season])
	NewGame.reset()
	GameClock.season = GameClock.Season.FALL
	check(QuestLog.available_from("mountain_shop") != QuestLog.get_quest(Warmth.QUEST), "not before the first kit")


func test_quest() -> void:
	new_game(GameClock.Season.FALL)
	QuestLog.talk_to("mountain_shop")
	check(QuestLog.active.has(Warmth.QUEST), "talking to Marty starts it")
	QuestLog.talk_to("mountain_shop")
	check(QuestLog.active.get(Warmth.QUEST) == 0, "nothing turns in without the jacket")
	Inventory.add("torn_puffy")
	QuestLog.talk_to("mountain_shop")
	check(QuestLog.active.get(Warmth.QUEST) == 1 and Inventory.count("torn_puffy") == 0, "the torn puffy is handed over")
	Inventory.add("wood_rose_hips", 3)
	QuestLog.talk_to("mountain_shop")
	check(QuestLog.active.get(Warmth.QUEST) == 2 and Inventory.count("wood_rose_hips") == 0, "the rose hips are handed over")
	check(not Warmth.has_jacket(), "no jacket before the trade")
	Inventory.add("trail_mix", 2)
	QuestLog.talk_to("mountain_shop")
	check(Warmth.has_jacket() and QuestLog.is_completed(Warmth.QUEST), "food worth 50 energy buys the mended puffy")
	check(Inventory.count("trail_mix") == 0, "the trade takes the food")


func test_cold() -> void:
	new_game(GameClock.Season.FALL)
	check(Warmth.speed_factor() == 1.0 and not Warmth.is_cold(), "fall isn't cold")
	GameClock.season = GameClock.Season.WINTER
	check(Warmth.is_cold() and Warmth.speed_factor() == Warmth.COLD_SPEED, "outdoors in winter without a jacket you walk slower")
	Warmth.outdoors = false
	check(not Warmth.is_cold() and Warmth.speed_factor() == 1.0, "indoors it's warm")
	Warmth.outdoors = true
	Gear.add(Warmth.JACKET)
	check(not Warmth.is_cold() and Warmth.speed_factor() == 1.0, "with the puffy the winter cold doesn't slow you")
	check(Emote.GLYPHS.has("cold"), "there's a shiver bubble")


func test_nudges() -> void:
	new_game(GameClock.Season.FALL)
	check(Warmth.morning_note(GameClock.Season.FALL, 14) == "", "no nudge on an ordinary morning")
	check(Warmth.morning_note(GameClock.Season.FALL, 15) != "" and Warmth.morning_note(GameClock.Season.FALL, 24) != "", "nudges on fall 15 and 24")
	check(Warmth.morning_note(GameClock.Season.WINTER, 1) != "", "a note on the first morning of winter")
	check(Warmth.morning_note(GameClock.Season.WINTER, 2) == "", "and only the first")
	Gear.add(Warmth.JACKET)
	check(Warmth.morning_note(GameClock.Season.FALL, 15) == "", "no nudges once you have it")
	NewGame.reset()
	check(Warmth.morning_note(GameClock.Season.FALL, 15) == "", "no nudges before Marty has fitted you out")


func test_climbing() -> void:
	new_game(GameClock.Season.WINTER)
	var lyell: RouteData = load("res://data/routes/lyell_glacier.tres")
	var kit := {"ice_axe": 1, "crampons": 1, "rope": 1, "harness": 1}
	var dawn := ClimbState.new(lyell, 0, 2, kit)
	dawn.start_minutes = 6 * 60
	var cold := ClimbState.new(lyell, 0, 2, kit)
	cold.start_minutes = 13 * 60
	var warm_kit := kit.duplicate()
	warm_kit[Warmth.JACKET] = 1
	var warm := ClimbState.new(lyell, 0, 2, warm_kit)
	warm.start_minutes = 13 * 60
	check(warm.has_puffy and not cold.has_puffy, "the climb knows about the jacket")
	var c: int = dawn.holds[1].keys()[0]
	check(cold.move_cost(1, c) == dawn.move_cost(1, c) + 1, "afternoon slush costs 1 more without the puffy")
	check(warm.move_cost(1, c) == dawn.move_cost(1, c), "and nothing more with it")

	# A cold night on the wall (no portaledge), with a meal that isn't Warming.
	Inventory.items.clear()
	Inventory.add("beef_jerky", 2)
	var night := ClimbState.new(lyell, 0, 2, kit)
	night._bivy("wall")
	check(night.stamina == ClimbState.COLD_NIGHT_STAMINA and "down jacket" in night.message, "a cold bivy without the puffy leaves you stiff (%d)" % night.stamina)
	var cozy := ClimbState.new(lyell, 0, 2, warm_kit)
	cozy._bivy("wall")
	check(cozy.stamina == ClimbState.MAX_STAMINA and "puffy" in cozy.message, "in the puffy you wake up rested (%d)" % cozy.stamina)
	Inventory.items.clear()


func test_save_and_load() -> void:
	new_game(GameClock.Season.WINTER)
	Gear.add(Warmth.JACKET)
	QuestLog.completed.append(Warmth.QUEST)
	SaveManager.save_game()
	NewGame.reset()
	check(not Warmth.has_jacket(), "a new game has no jacket")
	SaveManager.load_game()
	check(Warmth.has_jacket() and QuestLog.is_completed(Warmth.QUEST), "the jacket and the quest survive a save and load")
