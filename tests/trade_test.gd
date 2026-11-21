extends Node
## Checks trading with everything you carry (Barter, TradeValues, Market):
## every item has a trade value, no shop can be played for a profit
## (King Cobra at Camp 4 is the one small exception), buyers' tastes,
## seasons and freshness move prices, a buyer who's had a lot of one thing
## pays less for more of it and gets over it in a few days, change goes on a
## capped tab, quest and board-note things are never taken, and people who
## eat what you give them still want food.
## Run: godot --headless --path . res://tests/trade_test.tscn
## Exit code is the number of failed checks.

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	NewGame.reset()
	GameClock.load_data({})
	Larder.load_data({})
	_values()
	_no_profit_loops()
	_tastes_and_seasons()
	_paying()
	_gluts()
	_king_cobra()
	_reserved_and_food()
	_save()
	print("%d failure(s)" % failures)
	get_tree().quit(failures)


func _shop(name: String) -> ShopData:
	return load("res://data/shops/%s.tres" % name)


func _fresh_pack(items: Dictionary) -> void:
	Inventory.start_new_game()
	Larder.load_data({})
	Market.start_new_game()
	for id: String in items:
		Inventory.add(id, int(items[id]))


func _values() -> void:
	var missing := PackedStringArray()
	for item: ItemData in ItemDB.ITEMS:
		var food := FoodDB.FOODS.has(item.id)
		if food and item.id != "litter" and not TradeValues.tradeable(item.id):
			missing.append(item.id)
	check(missing.is_empty(), "every food, forage and fish has a trade value (missing: %s)" % ", ".join(missing))
	check(not TradeValues.tradeable("rental_shoes") and not TradeValues.tradeable("wilderness_permit") and not TradeValues.tradeable("litter"),
		"story things, permits and litter aren't for trade")
	check(TradeValues.tradeable("brown_trout") and TradeValues.tradeable("morel_mushroom") and TradeValues.tradeable("black_oak_acorn"),
		"raw trout, morels and acorns are worth something now (they were worth nothing as food)")
	check(is_equal_approx(TradeValues.base("wild_strawberry"), 10.0) and TradeValues.base("beef_jerky") > FoodDB.energy("beef_jerky"),
		"food is worth its energy, a little more if it keeps")
	check(TradeValues.base("king_cobra") == 20.0, "a can of King Cobra is worth 20")
	# Cooking adds a little worth, never a fortune.
	var pots := [["brown_trout", "sierra_onion"], ["wild_strawberry", "manzanita_berries", "california_blackberry"], ["morel_mushroom", "miners_lettuce"]]
	for pot: Array in pots:
		var meal := Cooking.meal_id(Cooking.result_for(pot))
		var inputs := 0.0
		for id: String in pot:
			inputs += TradeValues.base(id)
		var ratio := TradeValues.base(meal) / inputs
		check(ratio > 1.0 and ratio <= 1.4, "cooking %s adds worth, but not much (x%.2f)" % [" + ".join(pot), ratio])


func _no_profit_loops() -> void:
	# Whatever a shop sells, no buyer pays as much for it, in any season.
	var buyers: Array[ShopData] = []
	for path: String in TradeValues.SHOPS:
		buyers.append(load(path))
	var loops := PackedStringArray()
	for path: String in TradeValues.SHOPS:
		var data: ShopData = load(path)
		for offer in data.offers:
			if offer.kind != "item" or not offer.trade.is_empty() or offer.id == "king_cobra":
				continue
			for buyer in buyers:
				for season in 4:
					GameClock.season = season
					if TradeValues.worth_to(buyer, offer.id) >= offer.price:
						loops.append("%s from %s to %s" % [offer.id, Market.key_of(data), Market.key_of(buyer)])
	GameClock.season = GameClock.Season.SPRING
	check(loops.is_empty(), "nothing a shop sells is worth its price to anyone (%s)" % ", ".join(loops))
	var curry_cobra := TradeValues.cheapest_shelf_price("king_cobra")
	var climber := TradeValues.worth_to(_shop("camp4_rack"), "king_cobra")
	check(climber > curry_cobra and climber <= curry_cobra * 1.3,
		"a climber's first can is worth a bit more than the store's %d (%.0f), not a fortune" % [curry_cobra, climber])
	check(TradeValues.worth_to(_shop("curry_store"), "king_cobra") <= curry_cobra * 0.5, "the store buys cans back at half price at most")


func _tastes_and_seasons() -> void:
	GameClock.season = GameClock.Season.SPRING
	var store := _shop("curry_store")
	var marty := _shop("curry_mountain_shop")
	var greg := _shop("greg_flies")
	var climber := _shop("camp4_rack")
	check(TradeValues.worth_to(greg, "brown_trout") > TradeValues.worth_to(store, "brown_trout"), "Greg pays more for trout than the store")
	check(TradeValues.worth_to(climber, "chocolate_bar") > TradeValues.worth_to(marty, "chocolate_bar"), "climbers pay more for chocolate")
	check(TradeValues.worth_to(climber, "miners_lettuce") < TradeValues.worth_to(marty, "miners_lettuce"), "climbers don't want salad")
	check(TradeValues.worth_to(store, "pilot_bread") < TradeValues.worth_to(marty, "pilot_bread"), "the store buys its own goods back cheap")
	# Strawberries grow in spring: cheap now, dear in winter.
	var spring := TradeValues.worth_to(null, "wild_strawberry")
	GameClock.season = GameClock.Season.WINTER
	var winter := TradeValues.worth_to(null, "wild_strawberry")
	var hazel_winter := TradeValues.worth_to(null, "hazelnut")
	GameClock.season = GameClock.Season.FALL
	check(winter > spring, "forage is worth more out of season (%.1f in spring, %.1f in winter)" % [spring, winter])
	check(hazel_winter > TradeValues.worth_to(null, "hazelnut"), "hazelnuts laid by in fall are worth more in winter")
	GameClock.season = GameClock.Season.SPRING
	check(is_equal_approx(TradeValues.worth_to(null, "miners_lettuce", 1), TradeValues.worth_to(null, "miners_lettuce", 2) * TradeValues.LAST_DAY_FACTOR),
		"food on its last day trades for half")


func _paying() -> void:
	GameClock.season = GameClock.Season.SPRING
	var marty := _shop("curry_mountain_shop")
	_fresh_pack({"brown_trout": 2, "hazelnut": 3})
	var worth := Barter.purse(marty)
	check(worth > 0 and FoodDB.carried_energy() < worth, "trout you haven't cooked count toward what your pack is worth (%d)" % worth)
	var plan := Barter.plan(20, marty)
	check(not plan.is_empty() and plan.value >= 20, "a plan covers the price")
	var paid := Barter.pay(20, marty)
	check(not paid.is_empty() and Barter.purse(marty) < worth, "paying takes goods from the pack (%s)" % Barter.describe(paid))
	var tab := Market.tab("curry_mountain_shop")
	check(tab == int(plan.change) and tab <= Market.TAB_CAP, "what you overpay goes on your tab (%d)" % tab)
	if tab > 0:
		var before := Inventory.items.duplicate()
		var small := Barter.pay(tab, marty)
		check(small.get("tab", 0) == tab and Inventory.items == before and Market.tab("curry_mountain_shop") == 0, "a small price comes off the tab first")
	_fresh_pack({"pilot_bread": 10})
	Market.set_tab("curry_store", 500)
	check(Market.tab("curry_store") == Market.TAB_CAP, "a tab never holds more than %d" % Market.TAB_CAP)
	_fresh_pack({"miners_lettuce": 1})
	check(Barter.pay(100, marty).is_empty() and Inventory.count("miners_lettuce") == 1, "can't pay, nothing is taken")
	# The guidebook stays in reach on the first morning: a few berries.
	_fresh_pack({"wild_strawberry": 3})
	check(Barter.can_afford(20, marty), "three spring strawberries still buy Marty's guidebook")
	_fresh_pack({"miners_lettuce": 6})
	check(Barter.can_afford(30, _shop("curry_store")), "six miner's lettuce still buy the store's pilot bread")


func _gluts() -> void:
	GameClock.season = GameClock.Season.SPRING
	var store := _shop("village_store")
	_fresh_pack({"yampah": 12})
	var first := TradeValues.worth_to(store, "yampah")
	Barter.pay(10, store)
	var later := TradeValues.worth_to(store, "yampah")
	check(later < first, "the store pays less for yampah after taking some (%.1f, then %.1f)" % [first, later])
	check(TradeValues.worth_to(_shop("curry_store"), "yampah") == first, "the other store still pays full")
	for day in 4:
		GameClock.day_started.emit(day + 2, GameClock.season, 1)
	check(is_equal_approx(TradeValues.worth_to(store, "yampah"), first), "a few days later it pays full again")
	Market.took("village_store", "fresh", 9.0)
	check("fresh" in Market.full_up("village_store") and Vendor.full_up_line(store, {"miners_lettuce": 1}) != "",
		"a trader who's full up says so")
	check(Market.appetite("village_store", "fresh", 50.0) == Market.APPETITE_FLOOR, "a glut never makes a thing worthless")
	Market.start_new_game()


func _king_cobra() -> void:
	var climber := _shop("camp4_bigwall")
	_fresh_pack({"king_cobra": 4, "wild_strawberry": 6})
	var plan := Barter.plan(25, climber)
	check(plan.taken.has("king_cobra"), "climbers take King Cobra first (%s)" % Barter.describe(plan.taken))
	var cans := []
	for i in 4:
		cans.append(TradeValues.worth_to(climber, "king_cobra", 0, float(i)))
	check(cans[0] > cans[1] and cans[1] > cans[2] and cans[3] >= TradeValues.base("king_cobra") * 1.5 * Market.APPETITE_FLOOR - 0.01,
		"each can is worth less to the same climber (%s)" % str(cans))
	var store_plan := Barter.plan(20, _shop("curry_store"))
	check(not store_plan.taken.has("king_cobra"), "anyone else takes your cans last (%s)" % Barter.describe(store_plan.taken))
	_fresh_pack({"king_cobra": 4})
	var two := Barter.pay(45, climber)
	GameClock.day_started.emit(9, GameClock.season, 1)
	check(two.get("king_cobra", 0) == 2 and Market.appetite("camp4_bigwall", "cobra") < 1.0, "after two cans, a climber's still had enough the next morning")
	GameClock.day_started.emit(10, GameClock.season, 1)
	check(Market.appetite("camp4_bigwall", "cobra") == 1.0, "and is thirsty again the day after")


func _reserved_and_food() -> void:
	_fresh_pack({"wild_strawberry": 3, "trail_mix": 1})
	BoardRequests.taken = {"degnan_strawberries": Friendship.today()}
	check(Barter.goods().get("wild_strawberry", 0) == 0, "strawberries a board note asks for aren't for trade")
	var paid := Barter.pay(20, _shop("curry_mountain_shop"))
	check(Inventory.count("wild_strawberry") == 3 and not paid.has("wild_strawberry"), "paying leaves the board note's strawberries")
	BoardRequests.taken = {}
	_fresh_pack({"brown_trout": 3, "pilot_bread": 1})
	check(not Barter.can_afford_food(30) and Barter.can_afford(30), "raw trout trades, but it isn't supper for a hungry person")
	var fed := Barter.pay_food(20)
	check(fed.has("pilot_bread") and Inventory.count("brown_trout") == 3, "feeding someone takes food you can eat")


func _save() -> void:
	Market.start_new_game()
	Market.took("camp4_rack", "cobra", 2.0)
	Market.set_tab("curry_store", 7)
	var data: Dictionary = JSON.parse_string(JSON.stringify(Market.save_data()))
	Market.start_new_game()
	Market.load_data(data)
	check(Market.tab("curry_store") == 7 and is_equal_approx(Market.appetite("camp4_rack", "cobra"), 0.5), "tabs and gluts are saved")
