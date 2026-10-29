extends Node
## Headless test of the summer berries and fall mushrooms, and of cooking in
## the pot (Cooking): which dish the ingredients make, that cooking is worth
## more than eating raw, effects (and two effects cancelling), the meal as an
## item (name, picture, energy, spoiling, saving), the pot's menu, and what
## each effect does on a climb.
## Run: godot --headless --path . res://tests/cooking_test.tscn
## Exit code is the number of failed checks.

const APRON := preload("res://data/routes/glacier_point_apron.tres")
const NEW_FORAGE := ["california_blackberry", "whitebark_raspberry", "thimbleberry", "sierra_gooseberry",
	"sierra_bilberry", "wood_rose_hips", "chanterelle", "king_bolete", "coyote_mint",
	"hazelnut", "whitebark_pine_nuts", "hedgehog_mushroom", "cattail_root", "blue_dicks_corm",
	"cow_clover", "sierra_plum", "chokecherry"]

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	await get_tree().process_frame
	_empty_pack()
	Cooking.start_new_game()
	test_new_forage()
	test_balance()
	test_ingredients()
	test_dishes()
	test_effects()
	test_cook()
	test_meal_item()
	test_pot_menu()
	test_climb_effects()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func _empty_pack() -> void:
	Inventory.items.clear()
	Inventory.changed.emit()


func test_new_forage() -> void:
	var foraged := ItemDB.forage_items().map(func(item: ItemData) -> String: return item.id)
	for id: String in NEW_FORAGE:
		var item := ItemDB.get_item(id)
		check(item != null and item.icon != null and id in foraged and item.forage_seasons != 0,
			"%s is wild forage with a picture" % id)
		check(FoodDB.is_food(id) and FoodDB.shelf_life(id) > 0, "%s is food that spoils" % id)
	check(ItemDB.get_item("california_blackberry").is_forageable_in(GameClock.Season.SUMMER)
		and ItemDB.get_item("california_blackberry").habitat == ItemData.Habitat.RIVERSIDE, "blackberries ripen in summer by the river")
	check(ItemDB.get_item("whitebark_raspberry").is_forageable_in(GameClock.Season.SUMMER), "raspberries ripen in summer")
	check(ItemDB.get_item("wood_rose_hips").is_forageable_in(GameClock.Season.WINTER), "rose hips hang on into winter")
	check(FoodDB.is_edible("california_blackberry") and not FoodDB.is_edible("king_bolete"), "berries are good raw, boletes need cooking")
	check(ItemDB.count_name(2, "California Blackberry") == "2 California Blackberries", "two blackberries")

	for id: String in NEW_FORAGE:
		check(Cooking.can_cook_with(id), "%s can go in the pot" % id)
	check(ItemDB.count_name(3, "Cow Clover") == "3 Cow Clover" and ItemDB.count_name(2, "Chokecherry") == "2 Chokecherries", "clover and chokecherries count right")


## Forage against what quests, board notes and the winter ask for.
func test_balance() -> void:
	var acorn := ItemDB.get_item("black_oak_acorn")
	check(acorn.forage_count(GameClock.Season.FALL) == 4 and acorn.forage_count(GameClock.Season.WINTER) == 2
		and acorn.forage_count(GameClock.Season.SPRING) == 0, "acorns drop in fall, and a few are left under the oaks in winter")
	check(ItemDB.get_item("manzanita_berries").is_forageable_in(GameClock.Season.FALL), "manzanita berries hang on into fall (James Lamon's winter stores)")
	var winter := ItemDB.forage_items().filter(func(item: ItemData) -> bool:
		return item.is_forageable_in(GameClock.Season.WINTER) and item.habitat in [ItemData.Habitat.FOREST, ItemData.Habitat.RIVERSIDE])
	check(winter.size() >= 2, "the Valley's woods and riverbanks have something to find in winter (%d)" % winter.size())
	# Harding's Nose prep: 4 batches of acorn cakes (32 acorns) and 20 stored,
	# all from one chuckah outside the fall.
	var harding := QuestLog.get_quest("harding_summit")
	var stored := 0
	for step: Dictionary in harding.steps:
		if step.type == "stored":
			stored = int(step.count)
	check(stored + 4 * 2 * 4 <= Granary.CAPACITY_PER_CHUCKAH, "one chuckah holds enough acorns for Harding's cakes and reserve")
	for note: Dictionary in BoardRequests.NOTES:
		var item := ItemDB.get_item(note.item)
		var grows: bool = note.seasons.all(func(season: int) -> bool: return item.is_forageable_in(season))
		check(item != null and grows, "board note %s asks for something in season" % note.id)
		if item.habitat == ItemData.Habitat.HIGH_COUNTRY:
			check(note.get("hub", "") == "tuolumne_meadows", "board note %s waits until Tuolumne is open" % note.id)


func test_ingredients() -> void:
	for id: String in Cooking.INGREDIENTS:
		check(ItemDB.get_item(id) != null and FoodDB.is_food(id), "pot ingredient %s is a real food" % id)
		var effect := Cooking.effect_of(id)
		check(effect == "" or Cooking.EFFECTS.has(effect), "%s's effect is a real one" % id)
		if FoodDB.is_edible(id):
			check(Cooking.cooked_energy(id) > FoodDB.energy(id), "%s is worth more cooked (%d) than raw (%d)" % [
				id, Cooking.cooked_energy(id), FoodDB.energy(id)])
	check(not Cooking.can_cook_with("acorn_cake") and not Cooking.can_cook_with("rental_shoes"),
		"a cooked dish and a pair of shoes don't go in the pot")
	for dish: String in Cooking.DISHES:
		check(Cooking.dish_icon(dish) != null and int(Cooking.DISHES[dish].keeps) > 0, "%s has a picture and keeps" % dish)


func test_dishes() -> void:
	var cases := [
		[["california_blackberry", "california_blackberry", "whitebark_raspberry"], "simmered_berries"],
		[["california_blackberry", "whitebark_raspberry", "wild_strawberry"], "berry_medley"],
		[["lamon_apple", "lamon_apple"], "baked_fruit"],
		[["miners_lettuce", "miners_lettuce"], "wilted_greens"],
		[["yampah", "sierra_onion"], "root_hash"],
		[["morel_mushroom", "chanterelle"], "mushroom_skewer"],
		[["morel_mushroom", "miners_lettuce"], "mushroom_saute"],
		[["yerba_buena", "coyote_mint"], "herb_tea"],
		[["leached_acorn_meal", "california_blackberry"], "berry_acorn_cakes"],
		[["degnan_loaf", "whitebark_raspberry"], "berry_cobbler"],
		[["leached_acorn_meal", "king_bolete"], "mountain_flatbread"],
		[["beef_jerky", "yampah", "sierra_onion"], "camp_stew"],
		[["pine_nuts", "thimbleberry"], "nut_berry_bars"],
		[["pine_nuts"], "roasted_pine_nuts"],
		[["chocolate_bar", "wild_strawberry"], "chocolate_berries"],
		[["california_blackberry", "morel_mushroom"], "foragers_hash"],
		[["black_oak_acorn", "california_blackberry"], "bitter_mush"],
		[["morel_mushroom", "yerba_buena"], "mushroom_skewer"], # herbs only season it
	]
	for c: Array in cases:
		check(Cooking.dish_for(c[0]) == c[1], "%s make %s (%s)" % [c[0], c[1], Cooking.dish_for(c[0])])
	var berries := ["california_blackberry", "california_blackberry", "california_blackberry", "california_blackberry", "california_blackberry"]
	var stew := Cooking.result_for(berries)
	check(stew.energy > 5 * FoodDB.energy("california_blackberry"),
		"five blackberries cooked (%d) beat five eaten raw (%d)" % [stew.energy, 5 * FoodDB.energy("california_blackberry")])
	check(stew.energy >= ClimbState.BIVY_MEAL_ENERGY, "and make a night's meal on a big wall")
	check(int(Cooking.DISHES.simmered_berries.keeps) > FoodDB.shelf_life("california_blackberry"), "and keep longer than fresh berries")
	var mixed := Cooking.result_for(["california_blackberry", "whitebark_raspberry"])
	check(mixed.energy == Cooking.cooked_energy("california_blackberry") + Cooking.cooked_energy("whitebark_raspberry") + Cooking.VARIETY_BONUS,
		"mixing two kinds adds a variety bonus (%d)" % mixed.energy)
	check(Cooking.result_for(["black_oak_acorn", "beef_jerky"]).energy == Cooking.BITTER_ENERGY, "raw acorns ruin even jerky")


func test_effects() -> void:
	var tea := Cooking.result_for(["yerba_buena", "yerba_buena"])
	check(tea.effect == "steady" and tea.moves == 2 * Cooking.MOVES_PER_POTENCY, "two yerba buena: Steady for %d moves" % tea.moves)
	var strong := Cooking.result_for(["coyote_mint", "coyote_mint", "coyote_mint", "coyote_mint", "coyote_mint"])
	check(strong.moves == Cooking.MAX_EFFECT_MOVES, "an effect tops out at %d moves" % Cooking.MAX_EFFECT_MOVES)
	var cancel := Cooking.result_for(["coyote_mint", "thimbleberry"])
	check(cancel.effect == "" and cancel.moves == 0, "Steady and Nimble in one pot cancel out")
	var hearty := Cooking.result_for(["king_bolete", "morel_mushroom"])
	check(hearty.effect == "hearty", "a king bolete makes it hearty")
	var plain := Cooking.result_for(["california_blackberry", "whitebark_raspberry"])
	check(plain.effect == "", "plain berries have no effect")
	check(Cooking.meal_name(tea) == "Steady Wild Mint Tea" and Cooking.meal_name(plain) == "Simmered Berries", "an effect names the dish")


func test_cook() -> void:
	_empty_pack()
	Inventory.add("california_blackberry", 4)
	Inventory.add("sierra_bilberry", 1)
	var before := GameClock.minutes
	check(Cooking.cook([]) == "" and Cooking.cook(["acorn_cake"]) == "", "an empty pot, or a cooked dish, makes nothing")
	check(Cooking.cook(["california_blackberry", "california_blackberry", "california_blackberry", "california_blackberry", "california_blackberry"]) == "",
		"you can't cook berries you don't have")
	check(Inventory.count("california_blackberry") == 4, "...and nothing is used")
	var pot := ["california_blackberry", "california_blackberry", "sierra_bilberry"]
	check(not Cooking.knows_dish("simmered_berries"), "simmered berries aren't in the cookbook yet")
	var meal := Cooking.cook(pot)
	check(meal != "" and Inventory.count(meal) == 1, "the pot makes a meal (%s)" % meal)
	check(Inventory.count("california_blackberry") == 2 and Inventory.count("sierra_bilberry") == 0, "and uses what went in")
	check(Cooking.knows_dish("simmered_berries") and int(Cooking.discovered.simmered_berries.made) == 1, "the dish goes in the cookbook")
	check(GameClock.minutes != before, "cooking takes time")
	Inventory.add("sierra_bilberry", 1)
	check(Cooking.cook(pot) == meal and Inventory.count(meal) == 2, "the same pot makes the same meal, and they stack")
	check(Cooking.cook(["california_blackberry", "california_blackberry", "california_blackberry", "california_blackberry", "california_blackberry", "california_blackberry"]) == "",
		"the pot holds %d at most" % Cooking.POT_SIZE)


func test_meal_item() -> void:
	_empty_pack()
	Inventory.add("king_bolete", 1)
	Inventory.add("chanterelle", 1)
	var meal := Cooking.cook(["king_bolete", "chanterelle"])
	var item := ItemDB.get_item(meal)
	check(item != null and item.display_name == "Hearty Mushroom Skewer" and item.icon != null, "the meal is an item: %s" % (item.display_name if item else "null"))
	check(FoodDB.is_food(meal) and FoodDB.is_edible(meal) and FoodDB.energy(meal) == Cooking.result_for(["king_bolete", "chanterelle"]).energy,
		"with its energy (%d)" % FoodDB.energy(meal))
	check(meal in FoodDB.edible_in_inventory() and FoodDB.carried_energy() == FoodDB.energy(meal), "it counts as food in the pack")
	check(Cooking.parse("meal.no_such_dish.10.none.0").is_empty() and ItemDB.get_item("meal.bad") == null, "a made-up meal id is nothing")
	# saving: the id says it all
	var saved: Dictionary = JSON.parse_string(JSON.stringify(Inventory.save_data()))
	var book: Dictionary = JSON.parse_string(JSON.stringify(Cooking.save_data()))
	_empty_pack()
	Cooking.start_new_game()
	Inventory.load_data(saved)
	Cooking.load_data(book)
	check(Inventory.count(meal) == 1 and Cooking.knows_dish("mushroom_skewer") and Cooking.knows_dish("simmered_berries"),
		"meals and the cookbook survive a save")
	# spoiling
	var keeps := FoodDB.shelf_life(meal)
	check(keeps == int(Cooking.DISHES.mushroom_skewer.keeps), "a skewer keeps %d days" % keeps)
	for i in keeps:
		GameClock.day_started.emit(10 + i, 0, 1)
	check(Inventory.count(meal) == 0, "and then it spoils")


func test_pot_menu() -> void:
	_empty_pack()
	for id in ["california_blackberry", "whitebark_raspberry", "thimbleberry", "sierra_gooseberry", "sierra_bilberry",
			"wood_rose_hips", "chanterelle", "yampah"]:
		Inventory.add(id, 2)
	var menu := Station.pot_menu([])
	check(menu.actions.count("more") == 1 and menu.actions.filter(func(a: String) -> bool: return a.begins_with("add:")).size() == Station.POT_PAGE,
		"eight ingredients run onto a second page")
	check(not "cook" in menu.actions and menu.actions.back() == "leave", "an empty pot can't be cooked")
	var second := Station.pot_menu([], 1)
	check(second.actions.filter(func(a: String) -> bool: return a.begins_with("add:")).size() == 2, "the second page has the rest")
	var pot := ["california_blackberry", "california_blackberry"]
	menu = Station.pot_menu(pot)
	check(not "add:california_blackberry" in menu.actions, "both blackberries are in the pot, so none are left to add")
	var cook: int = menu.actions.find("cook")
	check(cook >= 0 and menu.details[cook].title == "Simmered Berries", "a dish you know shows its name before you cook it")
	menu = Station.pot_menu(["chanterelle", "yampah"])
	cook = menu.actions.find("cook")
	check(menu.details[cook].title == "Something new" and menu.icons[cook] == null, "a new dish keeps its secret")
	menu = Station.pot_menu(["california_blackberry", "california_blackberry", "whitebark_raspberry", "whitebark_raspberry", "thimbleberry"])
	check(not menu.actions.any(func(a: String) -> bool: return a.begins_with("add:")), "a full pot takes no more")
	menu = Station.pot_menu(["thimbleberry", "sierra_bilberry"])
	check("cancel" in menu.details[menu.actions.find("cook")].note, "the preview warns that two effects cancel")
	check(Station.pot_prompt(pot) == "In the pot: 2 California Blackberries (2 of 5).", Station.pot_prompt(pot))
	var line := Station.cooked_line(Cooking.meal_id(Cooking.result_for(["coyote_mint", "yampah", "yampah"])), true)
	check("Steady for 10 moves" in line and "cookbook" in line, line)


func test_climb_effects() -> void:
	_empty_pack()
	var state := ClimbState.new(APRON, 2, 7)
	var crimp := {"grip": "crimp"}
	var pumped := state.pump_change(crimp)
	var window := state.crux_window()
	var hold := Vector2i(-1, -1)
	for c in ClimbState.COLUMNS:
		if state.move_cost(1, c) >= 2:
			hold = Vector2i(c, 1)
			break
	var cost := state.move_cost(hold.y, hold.x)
	var steady := Cooking.meal_id(Cooking.result_for(["coyote_mint", "yampah"]))
	Inventory.add(steady)
	state.stamina = 50
	state.eat(steady)
	check(state.boosts.get("steady", 0) == 10 and "Steady" in state.message, "eating a Steady meal: %s" % state.message)
	check(state.pump_change(crimp) == pumped - 1, "Steady: a crimp pumps you 1 less")
	state.boosts["keen"] = 5
	check(is_equal_approx(state.crux_window(), window + ClimbState.KEEN_WINDOW), "Keen: a wider green on the crux")
	state.boosts["nimble"] = 5
	check(hold.x >= 0 and state.move_cost(hold.y, hold.x) == cost - 1, "Nimble: a move costs 1 less (%d vs %d)" % [state.move_cost(hold.y, hold.x), cost])
	var dx := hold.x - state.col
	if absi(dx) <= 1:
		state.move(dx)
		check(state.boosts.steady == 9 and state.boosts.keen == 4, "every move wears an effect down")
	state.boosts = {"keen": 1}
	state._wear_off_boosts()
	check(state.boosts.is_empty(), "and it wears off")

	var hearty := Cooking.meal_id(Cooking.result_for(["king_bolete"]))
	Inventory.add(hearty)
	state = ClimbState.new(APRON, 2, 7)
	state.stamina = 20
	state.pump = 4
	state.eat(hearty)
	check(state.stamina == ClimbState.MAX_STAMINA and state.pump == 0, "Hearty: stamina all the way up")

	# A cold bivy: a Warming meal (picked over a plain one) keeps you warm.
	_empty_pack()
	var warming := Cooking.meal_id(Cooking.result_for(["sierra_onion", "sierra_onion", "yampah", "yampah"]))
	var plain := Cooking.meal_id(Cooking.result_for(["california_blackberry", "california_blackberry", "california_blackberry"]))
	check(FoodDB.energy(warming) >= ClimbState.BIVY_MEAL_ENERGY and FoodDB.energy(plain) >= ClimbState.BIVY_MEAL_ENERGY, "both are night's meals")
	Inventory.add(warming)
	Inventory.add(plain)
	state = ClimbState.new(APRON, 2, 7)
	state._bivy("hanging")
	check(Inventory.count(warming) == 0 and Inventory.count(plain) == 1, "a cold night picks the Warming meal")
	check(state.stamina == ClimbState.MAX_STAMINA, "and you wake warm and rested")
	state = ClimbState.new(APRON, 2, 7)
	state._bivy("hanging")
	check(state.stamina == ClimbState.COLD_NIGHT_STAMINA, "a plain meal on a cold night leaves you chilled")
