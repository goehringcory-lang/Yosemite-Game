extends Node
## Headless test of the four seasonal festivity & natural-event quests, their
## signature recipes, Register pages, permanent perks, and functional camp
## pieces.
## Run: godot --headless --path . res://tests/seasonal_events_test.tscn
## Exit code is the number of failed checks.

const SEASONAL_QUESTS := [
	"enid_spring_moonbow",
	"curry_summer_firefall",
	"lamon_fall_meadow",
	"ansel_winter_horsetail",
]
const APRON := preload("res://data/routes/glacier_point_apron.tres")
const CAMP4_SHOP := preload("res://data/shops/camp4_rack.tres")
const VILLAGE_STORE := preload("res://data/shops/village_store.tres")

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	SaveManager.save_path = "user://seasonal_events_test_save.json"
	SaveManager.delete_save()
	await get_tree().process_frame
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().process_frame
	await get_tree().process_frame

	test_definitions()
	await test_spring_moonbow(world)
	test_summer_firefall()
	await test_fall_meadow(world)
	test_winter_horsetail()
	test_recipes_and_save()

	SaveManager.delete_save()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func reset_state(season := GameClock.Season.SPRING, day := 5, hour := 10) -> void:
	NewGame.reset()
	GameClock.paused = true
	GameClock.year = 1
	GameClock.season = season
	GameClock.day = day
	GameClock.minutes = hour * 60


func said(lines: Array[Dictionary], needle: String) -> bool:
	return lines.any(func(l: Dictionary) -> bool: return needle.to_lower() in str(l.text).to_lower())


func test_definitions() -> void:
	var expected_seasons := [
		GameClock.Season.SPRING,
		GameClock.Season.SUMMER,
		GameClock.Season.FALL,
		GameClock.Season.WINTER,
	]
	for i in SEASONAL_QUESTS.size():
		var id: String = SEASONAL_QUESTS[i]
		var q := QuestLog.get_quest(id)
		check(q != null and not q.main_line, "%s is registered as a side quest" % id)
		check(q.is_offered_in(expected_seasons[i]) and not q.is_offered_in((expected_seasons[i] + 1) % 4),
			"%s is offered only in %s" % [id, GameClock.SEASON_NAMES[expected_seasons[i]]])
		var pages := RegisterPages.PAGES.filter(func(p: Dictionary) -> bool: return p.quest == id)
		var hist: String = RegisterPages.HISTORY.get(id, "")
		check(pages.size() == 1 and "Real:" in hist and "Dramatized:" in hist,
			"%s writes a Register page with Real/Dramatized history note" % id)
	for dish in ["wildflower_honey_cake", "curry_cobbler", "autumn_hand_pie", "bracebridge_wassail"]:
		var item := ItemDB.get_item(dish)
		check(item != null and item.icon != null and FoodDB.is_edible(dish) and Recipes.get_recipe(dish) != null,
			"%s has item, icon, food stats, and campfire recipe" % dish)
	check(ItemDB.count_name(2, "Bracebridge Spiced Wassail") == "2 Bracebridge Spiced Wassail",
		"Wassail formats cleanly as a mass noun")


func test_spring_moonbow(world: Node) -> void:
	reset_state(GameClock.Season.SUMMER, 5, 10)
	QuestLog.completed.append_array(["clark_register", "eichorn_apron", "enid_leave_some", "enid_dawn_chorus",
		"enid_press", "hodges_herbarium", "hodges_canyon", "clark_grove_sprigs", "enid_rim", "muir_cassiope", "enid_full_press"])
	var lines := QuestLog.talk_to("enid_michael")
	check(not QuestLog.active.has("enid_spring_moonbow") and said(lines, "spring"),
		"in summer Enid says Moonbow and High Water belongs to spring")

	GameClock.season = GameClock.Season.SPRING
	lines = QuestLog.talk_to("enid_michael")
	check(QuestLog.active.has("enid_spring_moonbow"), "in spring Enid offers Moonbow and High Water")
	Inventory.add("miners_lettuce", 3)
	QuestLog.talk_to("enid_michael")
	check(Inventory.count("miners_lettuce") == 0 and QuestLog.current_step(QuestLog.get_quest("enid_spring_moonbow")).get("target") == "clare_hodges",
		"Enid takes miner's lettuce and sends you to Ranger Hodges")
	QuestLog.talk_to("clare_hodges")
	check(QuestLog.current_step(QuestLog.get_quest("enid_spring_moonbow")).get("ability") == "saw_moonbow",
		"Hodges tells you to watch the spring moonbow")
	QuestLog.mark_event("saw_moonbow")
	lines = QuestLog.talk_to("enid_michael")
	check(QuestLog.is_completed("enid_spring_moonbow"), "reporting the moonbow completes the spring quest")
	check(Recipes.knows("wildflower_honey_cake") and Inventory.count("wildflower_honey_cake") == 2,
		"spring quest rewards Wildflower Honey Cake recipe and 2 cakes")
	check(Perks.has("botanists_glint") and Camp.has("field_table"),
		"spring quest unlocks Botanist's Glint perk and Pressed-Flower Field Table")
	check(said(lines, "Botanist's Glint") and said(lines, "pressed-flower field table"),
		"spring reward line announces both camp piece and perk")

	# Botanist's Glint spawns an extra forage item each morning.
	var forage: ForageSpawner = world.forage
	Perks.earned.erase("botanists_glint")
	await forage.respawn()
	var base_count := forage.get_child_count()
	Perks.check(false)
	await forage.respawn()
	check(forage.get_child_count() == base_count + 1,
		"Botanist's Glint spawns 1 extra wild find each morning (%d vs %d)" % [forage.get_child_count(), base_count])

	# Pressed-Flower Field Table cuts camp chest aging in half.
	QuestLog.completed.append("lamon_orchard")
	Inventory.add("lamon_apple", 2)
	Camp.put_away("lamon_apple", 2)
	var before_days: int = Camp.chest_batches["lamon_apple"][0]
	Camp._age_food()
	var after_one: int = Camp.chest_batches["lamon_apple"][0]
	Camp._age_food()
	var after_two: int = Camp.chest_batches["lamon_apple"][0]
	check(after_one == before_days and after_two == before_days - 1,
		"Pressed-Flower Field Table ages camp chest food every other night (%d -> %d -> %d)" % [before_days, after_one, after_two])


func test_summer_firefall() -> void:
	reset_state(GameClock.Season.SPRING, 5, 10)
	QuestLog.completed.append_array(["clark_register", "degnan_bread", "curry_starter", "eichorn_apron", "mccauley_firefall"])
	var lines := QuestLog.talk_to("jennie_curry")
	check(not QuestLog.active.has("curry_summer_firefall") and said(lines, "summer"),
		"in spring Jennie Curry says Let the Fire Fall waits for summer")

	var base_leg := Park.best_leg("yosemite_valley", "tuolumne_meadows")
	var base_minutes := int(base_leg.minutes)

	var before_climb := ClimbState.new(APRON, 2, 7)
	before_climb.stamina = 40
	before_climb._finish_pitch()
	var base_belay_rest := before_climb.stamina - 40

	GameClock.season = GameClock.Season.SUMMER
	QuestLog.talk_to("jennie_curry")
	check(QuestLog.active.has("curry_summer_firefall"), "in summer Jennie Curry offers Let the Fire Fall")
	Inventory.add("california_blackberry", 3)
	QuestLog.talk_to("jennie_curry")
	QuestLog.talk_to("james_mccauley")
	QuestLog.mark_event("saw_firefall")
	lines = QuestLog.talk_to("jennie_curry")
	check(QuestLog.is_completed("curry_summer_firefall"), "reporting the Firefall completes the summer quest")
	check(Recipes.knows("curry_cobbler") and Inventory.count("curry_cobbler") == 2,
		"summer quest rewards Camp Curry Berry Cobbler recipe and 2 cobblers")
	check(Perks.has("high_country_timing") and Camp.has("string_lights"),
		"summer quest unlocks High-Country Timing perk and Camp Curry String Lights")

	var fast_leg := Park.best_leg("yosemite_valley", "tuolumne_meadows")
	check(int(fast_leg.minutes) < base_minutes,
		"High-Country Timing cuts hub travel time (%d min vs %d min)" % [int(fast_leg.minutes), base_minutes])

	var after_climb := ClimbState.new(APRON, 2, 7)
	after_climb.stamina = 40
	after_climb._finish_pitch()
	check(after_climb.stamina - 40 == base_belay_rest + Camp.STRING_LIGHTS_REST,
		"Camp Curry String Lights adds +%d stamina on belay rest (%d vs %d)" % [Camp.STRING_LIGHTS_REST, after_climb.stamina - 40, base_belay_rest])


func test_fall_meadow(world: Node) -> void:
	reset_state(GameClock.Season.SUMMER, 5, 10)
	QuestLog.completed.append_array(["clark_register", "lamon_orchard", "eichorn_apron", "lamon_winter"])
	var lines := QuestLog.talk_to("james_lamon")
	check(not QuestLog.active.has("lamon_fall_meadow") and said(lines, "fall"),
		"in summer Lamon says After the Flood, Before the Snow waits for fall")

	var base_bag := Gear.bag_room()
	var base_climber_val := TradeValues.worth_to(CAMP4_SHOP, "chocolate_bar")
	var base_store_val := TradeValues.worth_to(VILLAGE_STORE, "chocolate_bar")

	GameClock.season = GameClock.Season.FALL
	QuestLog.talk_to("james_lamon")
	check(QuestLog.active.has("lamon_fall_meadow"), "in fall Lamon offers After the Flood, Before the Snow")
	Inventory.add("hazelnut", 3)
	QuestLog.talk_to("james_lamon")
	QuestLog.talk_to("wren_alvarez")
	world._enter_region("mirror_lake", "arrival")
	await get_tree().process_frame
	check(QuestLog.is_unlocked("saw_dry_mirror_lake"), "visiting Mirror Lake in fall records saw_dry_mirror_lake")
	QuestLog.talk_to("james_lamon")
	check(QuestLog.is_completed("lamon_fall_meadow"), "reporting back finishes the fall quest")
	check(Recipes.knows("autumn_hand_pie") and Inventory.count("autumn_hand_pie") == 2,
		"fall quest rewards Chanterelle Hand Pie recipe and 2 pies")
	check(Perks.has("clean_pack") and Camp.has("workbench"),
		"fall quest unlocks Clean Pack perk and Trail-Crew Workbench")
	check(Gear.bag_room() == base_bag + 4, "Clean Pack adds +4 bulk to Gear.bag_room() (%d vs %d)" % [Gear.bag_room(), base_bag])
	var boosted_climber := TradeValues.worth_to(CAMP4_SHOP, "chocolate_bar")
	var boosted_store := TradeValues.worth_to(VILLAGE_STORE, "chocolate_bar")
	check(is_equal_approx(boosted_climber, base_climber_val * 1.15) and is_equal_approx(boosted_store, base_store_val),
		"Trail-Crew Workbench adds +15%% barter value with climbers only (%.2f vs %.2f)" % [boosted_climber, base_climber_val])


func test_winter_horsetail() -> void:
	reset_state(GameClock.Season.FALL, 5, 10)
	QuestLog.completed.append_array(["clark_register", "ansel_brownie", "ansel_portfolio", "ansel_monolith",
		"ansel_diving_board", "ansel_high_country", "ansel_exhibition"])
	var lines := QuestLog.talk_to("ansel_adams")
	check(not QuestLog.active.has("ansel_winter_horsetail") and said(lines, "winter"),
		"in fall Ansel says Fire on the Granite, Feast in the Hall waits for winter")

	GameClock.season = GameClock.Season.WINTER
	Warmth.outdoors = true
	var cold_before := Warmth.speed_factor()
	var sun := Sun.times()
	GameClock.minutes = int((sun.x + Photos.GOLDEN_HOURS + 0.25) * 60.0)
	var light_before := Photos.light_now(false)

	QuestLog.talk_to("ansel_adams")
	check(QuestLog.active.has("ansel_winter_horsetail"), "in winter Ansel offers Fire on the Granite, Feast in the Hall")
	Inventory.add("wood_rose_hips", 3)
	QuestLog.talk_to("ansel_adams")
	QuestLog.talk_to("ahwahnee_chef")
	QuestLog.mark_event("saw_horsetail")
	QuestLog.talk_to("ansel_adams")
	check(QuestLog.is_completed("ansel_winter_horsetail"), "reporting Horsetail Fall finishes the winter quest")
	check(Recipes.knows("bracebridge_wassail") and Inventory.count("bracebridge_wassail") == 2,
		"winter quest rewards Bracebridge Spiced Wassail recipe and 2 mugs")
	check(Perks.has("winter_hearth") and Camp.has("hearth_kettle"),
		"winter quest unlocks Winter Hearth perk and Ahwahnee Hearth Kettle")
	check(Warmth.speed_factor() > cold_before,
		"Winter Hearth halves winter cold slowdown (%.3f vs %.3f)" % [Warmth.speed_factor(), cold_before])
	check(light_before == "morning" and Photos.light_now(false) == "first_light",
		"Winter Hearth widens the golden-hour light window (%s -> %s)" % [light_before, Photos.light_now(false)])

	# Hearth kettle pours one free mug of wassail per day.
	var mugs_before := Inventory.count("bracebridge_wassail")
	check(Camp.can_pour_kettle() and Camp.pour_kettle() and Inventory.count("bracebridge_wassail") == mugs_before + 1,
		"Ahwahnee Hearth Kettle pours a free mug of spiced wassail")
	check(not Camp.can_pour_kettle() and not Camp.pour_kettle(),
		"hearth kettle only pours once per day")
	GameClock.start_new_day()
	check(Camp.can_pour_kettle(), "hearth kettle simmers fresh again the next morning")


func test_recipes_and_save() -> void:
	reset_state(GameClock.Season.SPRING, 5, 10)
	for id in ["wildflower_honey_cake", "curry_cobbler", "autumn_hand_pie", "bracebridge_wassail"]:
		Recipes.learn(id)
		var r := Recipes.get_recipe(id)
		for inp: String in r.inputs:
			Inventory.add(inp, int(r.inputs[inp]))
		check(Recipes.make(r) and Inventory.count(id) == r.output_count,
			"crafting %s yields %d" % [id, r.output_count])

	# Persistence of kettle_day and seasonal unlocks/perks across save/load.
	QuestLog.completed.append_array(SEASONAL_QUESTS)
	QuestLog.mark_event("saw_moonbow")
	Perks.check(false)
	Camp.pour_kettle()
	SaveManager.save_game()
	NewGame.reset()
	check(SaveManager.load_game(), "seasonal state saves and loads")
	check(Perks.has("botanists_glint") and Perks.has("high_country_timing") and Perks.has("clean_pack") and Perks.has("winter_hearth"),
		"all four seasonal perks persist across save/load")
	check(not Camp.can_pour_kettle(), "hearth kettle daily pour state persists across save/load")
