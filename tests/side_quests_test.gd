extends Node
## Plays the side stories that hang on the calendar and the clock: the
## seasonal errands (Hodges in fall, Degnan in winter), the hour-of-day
## visits (Enid Michael at dawn, Muir after dark), and Clark's errand to the
## Mariposa Grove. Also checks their Register pages say what's real.
## Run: godot --headless --path . res://tests/side_quests_test.tscn
## Exit code is the number of failed checks.

const NEW_QUESTS := ["clark_big_trees", "enid_dawn_chorus", "hodges_bear_season", "degnan_snowbound", "muir_soda_springs"]

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	await get_tree().process_frame
	_check_data()
	_play_big_trees()
	_play_dawn_chorus()
	_play_bear_season()
	_play_snowbound()
	_play_soda_springs()
	_check_register()
	_check_recipes()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func new_game(season := GameClock.Season.SUMMER, hour := 12) -> void:
	Inventory.start_new_game()
	Inventory.items.clear()
	Gear.start_new_game()
	Granary.start_new_game()
	Recipes.start_new_game()
	QuestLog.start_new_game()
	set_clock(season, hour)


func set_clock(season: int, hour: int) -> void:
	GameClock.paused = true
	GameClock.season = season
	GameClock.day = 5
	# Minutes run past midnight until you sleep, so 1 AM is 25 * 60.
	GameClock.minutes = (hour if hour >= GameClock.DAY_START_HOUR else hour + 24) * 60


func said(lines: Array[Dictionary], text: String) -> bool:
	return lines.any(func(l: Dictionary) -> bool: return text in l.text)


func _check_data() -> void:
	for id: String in NEW_QUESTS:
		var quest := QuestLog.get_quest(id)
		check(quest != null and not quest.main_line, "%s is a side story" % id)
		var page := RegisterPages.PAGES.filter(func(p: Dictionary) -> bool: return p.quest == id)
		check(page.size() == 1 and "Real" in str(page[0].get("history", "")) and "Dramatized" in str(page[0].get("history", "")),
			"%s has a Register page that says what's real and what's dramatized" % id)
	check(QuestLog.get_quest("hodges_bear_season").is_offered_in(GameClock.Season.FALL)
		and not QuestLog.get_quest("hodges_bear_season").is_offered_in(GameClock.Season.SUMMER), "Bear Season is a fall errand")
	check(QuestLog.get_quest("degnan_snowbound").is_offered_in(GameClock.Season.WINTER)
		and not QuestLog.get_quest("degnan_snowbound").is_offered_in(GameClock.Season.SPRING), "Snowbound is a winter errand")
	check(QuestLog.get_quest("clark_big_trees").is_offered_in(GameClock.Season.WINTER), "a quest with no seasons ticked is offered all year")
	# The one-of-a-kind items lie at Wawona and El Portal.
	var found := {}
	for hub in ["wawona", "el_portal"]:
		var overlay: Node = load(StoryContent.path_for(hub)).instantiate()
		for pickup in overlay.find_children("*", "StoryPickup", true, false):
			found[pickup.item_id] = hub
		overlay.free()
	check(found.get("sequoia_cone") == "wawona", "the sequoia cone lies in the Mariposa Grove at Wawona")
	check(found.get("flour_sack") == "el_portal", "Degnan's flour waits at the El Portal railyard")
	for id in ["sequoia_cone", "flour_sack"]:
		check(ItemDB.get_item(id) != null and ItemDB.get_item(id).icon != null, "%s has an icon to lie on the ground with" % id)


func _play_big_trees() -> void:
	new_game()
	check(QuestLog.available_from("galen_clark").id == "clark_register", "Clark's first errand is still the guidebook")
	QuestLog.completed.append_array(["clark_register", "leonard_belay"])
	QuestLog.talk_to("galen_clark")
	check(QuestLog.active.has("clark_big_trees"), "after Swan Slab, Clark sends you to the big trees")
	var lines := QuestLog.talk_to("galen_clark")
	check(said(lines, "Grizzly Giant"), "until you have a cone, he tells you where to look")
	Inventory.add("sequoia_cone")
	lines = QuestLog.talk_to("galen_clark")
	check(QuestLog.is_completed("clark_big_trees") and Inventory.count("sequoia_cone") == 0, "Clark takes the cone")
	check(Inventory.count("pilot_bread") == 2 and Inventory.count("dried_apricots") == 2, "and feeds you for the road, like Clark's Station")


func _play_dawn_chorus() -> void:
	new_game(GameClock.Season.SUMMER, 14)
	QuestLog.completed.append_array(["eichorn_apron", "enid_leave_some"])
	QuestLog.talk_to("enid_michael")
	check(QuestLog.active.has("enid_dawn_chorus"), "Enid Michael asks you to count birds with her")
	var lines := QuestLog.talk_to("enid_michael")
	check(QuestLog.current_step(QuestLog.get_quest("enid_dawn_chorus")).type == "time" and said(lines, "before ten"),
		"in the afternoon she asks you back in the morning")
	set_clock(GameClock.Season.SUMMER, 7)
	lines = QuestLog.talk_to("enid_michael")
	check(said(lines, "chickadee") and QuestLog.current_step(QuestLog.get_quest("enid_dawn_chorus")).get("target") == "clare_hodges",
		"at 7 AM you count the dawn chorus, then take the count to Hodges")
	QuestLog.talk_to("clare_hodges")
	set_clock(GameClock.Season.SUMMER, 15)
	QuestLog.talk_to("enid_michael")
	check(QuestLog.is_completed("enid_dawn_chorus") and Recipes.knows("spring_greens"), "back at Sentinel Dome she teaches spring greens")


func _play_bear_season() -> void:
	new_game(GameClock.Season.SUMMER)
	QuestLog.completed.append_array(["eichorn_apron", "hodges_patrol", "tabuce_acorns", "tabuce_chuckah"])
	var lines := QuestLog.talk_to("clare_hodges")
	check(not QuestLog.active.has("hodges_bear_season") and said(lines, "fall"), "in summer Hodges says to come back in the fall")
	set_clock(GameClock.Season.FALL, 10)
	QuestLog.talk_to("clare_hodges")
	check(QuestLog.active.has("hodges_bear_season"), "in fall she starts Bear Season")
	Granary.acorns = 12
	QuestLog.talk_to("clare_hodges")
	check(QuestLog.current_step(QuestLog.get_quest("hodges_bear_season")).type == "stored", "twelve stored acorns aren't enough")
	Granary.acorns = 20
	QuestLog.talk_to("clare_hodges")
	lines = QuestLog.talk_to("james_lamon")
	check(said(lines, "sow and two cubs"), "Lamon has bears in his orchard")
	set_clock(GameClock.Season.WINTER, 10)
	QuestLog.talk_to("clare_hodges")
	check(QuestLog.is_completed("hodges_bear_season") and Inventory.count("beef_jerky") == 3,
		"a quest started in fall can be finished after the season turns")


func _play_snowbound() -> void:
	new_game(GameClock.Season.FALL)
	QuestLog.completed.append_array(["clark_register", "degnan_bread", "curry_starter", "eichorn_apron", "enid_leave_some"])
	var lines := QuestLog.talk_to("bridget_degnan")
	check(not QuestLog.active.has("degnan_snowbound") and said(lines, "snow"), "before winter Bridget Degnan asks you to come back when it snows")
	set_clock(GameClock.Season.WINTER, 9)
	QuestLog.talk_to("bridget_degnan")
	check(QuestLog.active.has("degnan_snowbound"), "in winter she sends you for the flour")
	Inventory.add("flour_sack")
	QuestLog.talk_to("bridget_degnan")
	check(Inventory.count("flour_sack") == 0 and QuestLog.current_step(QuestLog.get_quest("degnan_snowbound")).get("item") == "toasted_toyon",
		"she takes the flour, then wants toasted toyon")
	Inventory.add("toyon_berries", 4)
	Recipes.learn("toasted_toyon")
	var toyon := Recipes.get_recipe("toasted_toyon")
	while Inventory.count("toasted_toyon") < 1 and Recipes.make(toyon):
		pass
	QuestLog.talk_to("bridget_degnan")
	check(QuestLog.is_completed("degnan_snowbound") and Recipes.knows("bread_pudding") and Inventory.count("degnan_loaf") == 2,
		"toasted toyon finishes Snowbound: the pudding recipe and two loaves")


func _play_soda_springs() -> void:
	new_game(GameClock.Season.SUMMER, 15)
	QuestLog.completed.append_array(["harding_summit", "muir_cathedral"])
	QuestLog.active["muir_glacier"] = 0 # the main line is underway too
	QuestLog.talk_to("john_muir")
	check(not QuestLog.active.has("muir_soda_springs"), "Muir waits until his glacier is done before asking you to supper")
	QuestLog.active.erase("muir_glacier")
	QuestLog.completed.append("muir_glacier")
	QuestLog.talk_to("john_muir")
	check(QuestLog.active.has("muir_soda_springs"), "then he asks you to bring supper")
	Inventory.add("pine_nuts", 2)
	var lines := QuestLog.talk_to("john_muir")
	check(QuestLog.active["muir_soda_springs"] == 1 and Inventory.count("pine_nuts") == 0 and said(lines, "after dark"),
		"supper is shared, and the fire waits for dark")
	set_clock(GameClock.Season.SUMMER, 1)
	lines = QuestLog.talk_to("john_muir")
	check(QuestLog.is_completed("muir_soda_springs") and said(lines, "1890"), "at 1 AM, by the fire, Muir tells how the park began")
	check(Recipes.knows("dry_crusts") and Inventory.count("degnan_loaf") == 2, "and teaches you to dry bread his way")


func _check_register() -> void:
	QuestLog.completed.assign(NEW_QUESTS)
	var pages := RegisterPages.written()
	check(pages.size() == NEW_QUESTS.size(), "each new side story writes one Register page (%d)" % pages.size())
	for page: Dictionary in pages:
		var notes := " ".join(page.notes)
		check("Register note: Real" in notes and "Dramatized" in notes, "%s's page carries a note on what's real" % page.by)
	var hodges := pages.filter(func(p: Dictionary) -> bool: return p.by == "Clare Marie Hodges")
	check(hodges.size() == 1 and hodges[0].notes.size() == 2, "Hodges's page has Lamon's margin note and the history note")


func _check_recipes() -> void:
	new_game()
	Recipes.learn("dry_crusts")
	Recipes.learn("bread_pudding")
	Recipes.learn("spring_greens")
	Inventory.add("degnan_loaf", 2)
	Inventory.add("lamon_apple", 2)
	Inventory.add("miners_lettuce", 3)
	Inventory.add("sierra_onion", 1)
	check(Recipes.make(Recipes.get_recipe("dry_crusts")) and Inventory.count("dry_crusts") == 3, "one loaf dries into three crusts")
	check(FoodDB.shelf_life("dry_crusts") > FoodDB.shelf_life("degnan_loaf") * 5
		and FoodDB.energy("dry_crusts") * 3 >= FoodDB.energy("degnan_loaf"), "dry crusts keep far longer and lose no energy")
	check(Recipes.make(Recipes.get_recipe("bread_pudding")) and Inventory.count("bread_pudding") == 2, "a loaf and two apples make two puddings")
	check(FoodDB.energy("bread_pudding") * 2 > FoodDB.energy("degnan_loaf") + 2 * FoodDB.energy("lamon_apple"),
		"pudding is worth more than its ingredients")
	check(Recipes.make(Recipes.get_recipe("spring_greens")) and FoodDB.energy("spring_greens") > 3 * FoodDB.energy("miners_lettuce") + FoodDB.energy("sierra_onion"),
		"cooked greens beat the raw leaves")
	for id in ["dry_crusts", "bread_pudding", "spring_greens"]:
		check(ItemDB.get_item(id) != null and FoodDB.is_edible(id), "%s is a registered food" % id)
