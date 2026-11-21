extends Node
## Headless test of trading with climbers (GearSale): every piece of gear has
## a trade value, you can sell spares to the Camp 4 climbers and Marty but
## never what your hardest route needs, they pay in food and never in King
## Cobra, the piece a climber is after pays full value, King Cobra swaps
## work once a day, and a can shared over a new route gets a gift. Save and
## load keeps it.
## Run: godot --headless --path . res://tests/climber_trades_test.tscn
## Exit code is the number of failed checks.

const RACK := preload("res://data/shops/camp4_rack.tres")
const BIGWALL := preload("res://data/shops/camp4_bigwall.tres")
const MARTY := preload("res://data/shops/curry_mountain_shop.tres")

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	SaveManager.save_path = "user://climber_trades_test_save.json"
	SaveManager.delete_save()
	test_values()
	test_floor()
	test_selling()
	test_wants()
	test_can_swaps()
	test_toast()
	test_save_and_load()
	SaveManager.delete_save()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func new_game() -> void:
	NewGame.reset()
	GameClock.year = 1
	GameClock.season = GameClock.Season.SUMMER
	GameClock.day = 5


func test_values() -> void:
	for gear: GearData in Gear.GEAR:
		if gear.keepsake:
			check(gear.trade_value == 0, "%s is a keepsake, worth nothing in trade" % gear.id)
		else:
			check(gear.trade_value > 0, "%s has a trade value (%d)" % [gear.id, gear.trade_value])
	check(Gear.get_gear("portaledge").trade_value > Gear.get_gear("cam").trade_value
		and Gear.get_gear("cam").trade_value > Gear.get_gear("quickdraw").trade_value, "a portaledge is worth more than a cam, a cam more than a draw")
	for data: ShopData in [RACK, BIGWALL, MARTY]:
		for id in data.buys_gear:
			check(Gear.get_gear(id) != null, "%s buys real gear (%s)" % [data.keeper, id])
		check(not GearSale.CAN in data.pays_with, "%s never pays in King Cobra" % data.keeper)
		for id in data.pays_with:
			check(FoodDB.energy(id) > 0 and FoodDB.shelf_life(id) >= 12, "%s pays with food that keeps (%s)" % [data.keeper, id])


func test_floor() -> void:
	new_game()
	check(GearSale.keep_floor("rope") == 1 and GearSale.keep_floor("cam") == 10 and GearSale.keep_floor("quickdraw") == 6,
		"you always keep a rope, 10 cams and 6 draws (the Nose)")
	check(GearSale.keep_floor("aiders") == 2 and GearSale.keep_floor("portaledge") == 1, "and the wall kit")
	Gear.owned = {"rope": 1, "harness": 1, "cam": 12, "quickdraw": 9, "climbing_shoes": 1}
	check(GearSale.spare("rope") == 0, "your only rope isn't spare")
	check(GearSale.spare("cam") == 2 and GearSale.spare("quickdraw") == 3, "2 cams and 3 draws are spare")
	check(GearSale.spare("camera") == 0, "Ansel's camera is never for sale")
	Gear.owned["camera"] = 1
	check(GearSale.spare("camera") == 0, "even when you have it")


func test_selling() -> void:
	new_game()
	Gear.owned = {"rope": 2, "harness": 1, "cam": 11, "quickdraw": 7, "climbing_shoes": 1}
	Gear.cached = {"cam": 1}
	Inventory.items = {}
	var sale := GearSale.sellable(RACK)
	check(sale.get("cam", 0) == 1 and sale.get("quickdraw", 0) == 1 and not sale.has("rope"), "the Camp 4 climber buys spare cams and draws, not ropes (%s)" % sale)
	check(GearSale.sellable(BIGWALL).get("rope", 0) == 1, "the big-wall climber takes a spare rope")
	var price := GearSale.price(RACK, "cam") if GearSale.wanted(RACK) != "cam" else roundi(Gear.get_gear("cam").trade_value * RACK.buy_rate)
	check(price < Gear.get_gear("cam").trade_value, "used, a cam fetches less than it's worth (%d)" % price)
	var energy_before := FoodDB.carried_energy()
	var expect := GearSale.price(RACK, "cam")
	var got := GearSale.sell(RACK, "cam")
	check(not got.is_empty() and Gear.count("cam") == 10 and Gear.cached_count("cam") == 0, "selling a cam takes the spare off the rack (%s)" % got)
	var paid := FoodDB.carried_energy() - energy_before
	check(paid >= expect and paid < expect + 20, "and pays its price in food (%d for %d)" % [paid, expect])
	check(GearSale.sell(RACK, "cam").is_empty() and Gear.count("cam") == 10, "the 10th cam stays")
	check(GearSale.sell(RACK, "rope").is_empty(), "the Camp 4 climber won't take a rope")
	check(Inventory.count(GearSale.CAN) == 0, "no King Cobra comes back")
	# buying then selling back loses food: no loop
	for offer in MARTY.offers:
		if offer.id == "cam":
			check(GearSale.price(MARTY, "cam") < offer.price and GearSale.price(RACK, "cam") <= offer.price, "nobody buys a cam for more than Marty sells one")
	var food := GearSale.payment(33, PackedStringArray(["beef_jerky", "dried_apples"]))
	var total := 0
	for id: String in food:
		total += FoodDB.energy(id) * int(food[id])
	check(total >= 33 and total < 33 + 15, "payment covers the price without much over (%s)" % food)


func test_wants() -> void:
	new_game()
	var seen := {}
	for d in range(1, 28):
		GameClock.day = d
		seen[GearSale.wanted(RACK)] = true
	check(seen.size() >= 3 and not seen.has(""), "the Camp 4 climber wants different pieces across a season (%s)" % str(seen.keys()))
	for id: String in seen:
		check(id in RACK.buys_gear and GearSale.keep_floor(id) < 99, "%s is something they buy" % id)
	GameClock.day = 4
	var a := GearSale.wanted(RACK)
	GameClock.day = 5
	check(GearSale.wanted(RACK) == a or GearSale.today() % GearSale.WANT_DAYS == 0, "a want lasts a few days")
	check(GearSale.wanted(MARTY) == "", "Marty doesn't go after anything")
	var want := GearSale.wanted(RACK)
	check(GearSale.price(RACK, want) == Gear.get_gear(want).trade_value, "the wanted piece pays full value (%s)" % want)


func test_can_swaps() -> void:
	new_game()
	Gear.owned = {"rope": 1, "harness": 1, "cam": 2, "quickdraw": 5, "climbing_shoes": 1}
	Inventory.items = {GearSale.CAN: 3}
	var swap: ShopOffer = null
	for offer in Vendor.offers_open(RACK):
		if offer.id == "cam" and offer.trade.has(GearSale.CAN):
			swap = offer
	check(swap != null and swap.once_a_day, "the Camp 4 climber swaps a cam for King Cobra")
	check(Vendor.cost_of(swap).contains("King Cobra"), "priced in cans (%s)" % Vendor.cost_of(swap))
	var vendor := Vendor.new()
	vendor.shop = RACK
	var paid := vendor.buy(swap)
	check(not paid.is_empty() and Gear.count("cam") == 3 and Inventory.count(GearSale.CAN) == 3 - int(swap.trade[GearSale.CAN]), "the swap takes cans and gives a cam")
	check(not swap in Vendor.offers_open(RACK), "once a day")
	GameClock.start_new_day()
	check(swap in Vendor.offers_open(RACK), "back the next day")
	vendor.free()
	for offer in BIGWALL.offers:
		if offer.trade.has(GearSale.CAN):
			check(not offer.requires.is_empty(), "big-wall can swap for %s still needs gear you got from a quest" % offer.id)


func test_toast() -> void:
	new_game()
	Inventory.items = {}
	check(GearSale.toast_route() == null, "nothing to toast before a route")
	QuestLog.record_climb("swan_slab")
	var route := GearSale.toast_route()
	check(route != null and route.id == "swan_slab", "Swan Slab is ready to toast")
	check(GearSale.toast(route).is_empty(), "not without a can")
	Inventory.add(GearSale.CAN, 2)
	var draws := Gear.count("quickdraw")
	var gift := GearSale.toast(route)
	check(gift.get("gear", "") == "quickdraw" and Gear.count("quickdraw") == draws + 2 and Inventory.count(GearSale.CAN) == 1, "the first toast gets 2 quickdraws for one can")
	check(GearSale.toast_route() == null and GearSale.toast(route).is_empty(), "one toast per route")
	check(GearSale.gift_name(gift) != "", "the gift has a name (%s)" % GearSale.gift_name(gift))


func test_save_and_load() -> void:
	new_game()
	GearSale.toasted = ["swan_slab"]
	GearSale.swaps_on = {"Camp 4 climber/cam": GearSale.today()}
	var saved := GearSale.save_data()
	GearSale.start_new_game()
	check(GearSale.toasted.is_empty(), "a new game forgets the toasts")
	GearSale.load_data(JSON.parse_string(JSON.stringify(saved)))
	check(GearSale.toasted == ["swan_slab"] and int(GearSale.swaps_on.get("Camp 4 climber/cam", -1)) == GearSale.today(), "save and load keeps toasts and today's swaps")
