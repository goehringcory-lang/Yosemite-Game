extends Node
## Plays fly fishing: the cast meter (a back cast and a forward cast, each
## stopped in the green, and what each kind of stop does), the flies and
## what they change, and Greg, Curry Village's fishing guide: his quest for
## your first rod, his fly trades for food and fish, and where he goes in a
## day. The reel itself is in tests/valley_life_test.gd.
## Run: godot --headless --path . res://tests/fishing_test.tscn
## Exit code is the number of failed checks. Uses its own save file.

const QUEST := "greg_first_rod"
const GREG := "greg"

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func said(lines: Array[Dictionary], text: String) -> bool:
	return lines.any(func(l: Dictionary) -> bool: return text in l.text)


func _ready() -> void:
	await get_tree().process_frame
	SaveManager.save_path = "user://fishing_test_save.json"
	SaveManager.delete_save()
	var world = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(world)
	await get_tree().process_frame
	GameClock.paused = true
	test_meter()
	test_casts()
	test_flies()
	test_greg_data()
	test_greg_quest()
	test_greg_trades()
	await test_greg_in_camp(world)
	SaveManager.delete_save()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func _game(seed: int, fly := {}) -> FishingMinigame:
	var game := FishingMinigame.new()
	add_child(game)
	game.set_process(false)
	game.start(Fishing.get_fish("brown_trout"), seed, fly)
	return game


## Lets the meter open, then stops it: in the middle of the green
## ("perfect"), near its edge ("good") or off it ("miss").
func _cast(game: FishingMinigame, result: String) -> void:
	game.step(FishingMinigame.UNROLL + 0.01, false)
	var half := game.window() / 2.0
	match result:
		"perfect":
			game.meter_pos = game.meter_center
		"good":
			game.meter_pos = game.meter_center + half * 0.8
		_:
			game.meter_pos = game.meter_center + half + 0.08
	game.press()


## Steps through the wait until the fly is taken (REEL) or the cast ends.
func _drift(game: FishingMinigame) -> FishingMinigame.Phase:
	for i in 600:
		var phase := game.step(1.0 / 60.0, false)
		if phase != FishingMinigame.Phase.WAIT:
			return phase
	return game.phase


func test_meter() -> void:
	var game := _game(3)
	check(game.phase == FishingMinigame.Phase.BACK_CAST, "a cast starts with the back cast")
	game.meter_pos = game.meter_center
	game.press()
	check(game.back_cast == "", "a press as the meter opens doesn't count (no double taps)")
	game.step(FishingMinigame.GRACE + 0.01, false)
	var start := game.meter_pos
	game.step(0.1, false)
	check(game.meter_pos > start, "then the marker sweeps along the bar")
	var half := game.window() / 2.0
	check(game.judge(game.meter_center) == "perfect" and game.judge(game.meter_center + half * FishingMinigame.PERFECT_SHARE * 0.9) == "perfect",
		"the middle of the green is a perfect stop")
	check(game.judge(game.meter_center - half * 0.9) == "good", "the rest of the green is a good one")
	check(game.judge(game.meter_center + half + 0.02) == "miss", "outside the green is a miss")
	check(game.meter_center - half >= 0.2 and game.meter_center + half <= 0.8, "the green never sits hard against an end")
	game.free()
	# holding the loop in the air forever drops the line
	game = _game(4)
	game.step(FishingMinigame.GRACE + 0.01, false)
	for i in 2000:
		if game.step(1.0 / 60.0, false) != FishingMinigame.Phase.BACK_CAST:
			break
	check(game.back_cast == "miss" and game.outcome == "snagged", "wait out the meter and the back cast is a miss")
	game.free()
	game = _game(5)
	game.step(FishingMinigame.GRACE + 0.01, false)
	game.step(0.2, false)
	game.meter_pos = game.meter_center
	game.press()
	check(game.phase == FishingMinigame.Phase.FORWARD_CAST, "a stop in the green moves on to the forward cast")
	var before := game.meter_pos
	game.step(FishingMinigame.UNROLL * 0.5, false)
	check(game.meter_pos == before and game.forward_cast == "", "which waits while the line unrolls behind you")
	game.free()


func test_casts() -> void:
	# two perfect stops: a fish always rises, takes the fly soon, and the hook sets hard
	var rose := 0
	var hard := 0
	for seed in 12:
		var game := _game(seed)
		_cast(game, "perfect")
		_cast(game, "perfect")
		if game.rises and _drift(game) == FishingMinigame.Phase.REEL:
			rose += 1
			if is_equal_approx(game.line, FishingMinigame.HOOK_SET[4]):
				hard += 1
		game.free()
	check(rose == 12, "two perfect casts always bring a fish up (%d of 12)" % rose)
	check(hard == 12 and FishingMinigame.HOOK_SET[4] > FishingMinigame.HOOK_SET[2], "and set the hook hard, so the line starts well along")
	# a missed back cast hangs up behind you; a missed forward cast spooks the pool
	var game := _game(1)
	var ended := []
	game.finished.connect(func(caught: bool) -> void: ended.append(caught))
	_cast(game, "miss")
	check(game.phase == FishingMinigame.Phase.DONE and game.outcome == "snagged" and game.forward_cast == "" and ended == [false],
		"a missed back cast snags the willows, and that's the cast")
	game.free()
	game = _game(1)
	_cast(game, "good")
	_cast(game, "miss")
	check(game.phase == FishingMinigame.Phase.DONE and game.outcome == "spooked", "a missed forward cast slaps the water and spooks the fish")
	check(Fishing.MISSES.has("snagged") and Fishing.MISSES.has("spooked") and Fishing.MISSES.has("no_rise"), "and the HUD says which went wrong")
	game.free()
	# two good stops only sometimes do; a perfect and a good, more often
	var good_rises := 0
	var mixed_rises := 0
	var no_rise := 0
	for seed in 60:
		game = _game(100 + seed)
		_cast(game, "good")
		_cast(game, "good")
		if game.rises:
			good_rises += 1
		elif _drift(game) == FishingMinigame.Phase.DONE and game.outcome == "no_rise":
			no_rise += 1
		game.free()
		game = _game(300 + seed)
		_cast(game, "perfect")
		_cast(game, "good")
		if game.rises:
			mixed_rises += 1
		game.free()
	check(good_rises > 10 and good_rises < 40, "two good casts bring a fish up only some of the time (%d of 60)" % good_rises)
	check(mixed_rises > good_rises, "a perfect and a good do better (%d against %d)" % [mixed_rises, good_rises])
	check(no_rise == 60 - good_rises, "and a cast nothing rose to drifts out and ends (%d)" % no_rise)
	check(FishingMinigame.BITE_CHANCE[4] == 1.0 and FishingMinigame.BITE_CHANCE[1] == 0.0, "the odds run from nothing to certain")


func test_flies() -> void:
	Gear.start_new_game()
	check(Fishing.tied_fly().is_empty(), "with only the rod, the plain fly is tied on")
	for fly: Dictionary in Fishing.FLIES:
		var gear := Gear.get_gear(fly.id)
		check(gear != null and gear.icon != null and gear.icon.get_size() == Vector2(64, 64) and gear.description != "", "%s is gear with a picture" % fly.id)
	Gear.add("elk_hair_caddis")
	Gear.add("woolly_bugger")
	var tied := Fishing.tied_fly()
	check(tied.get("id", "") == "woolly_bugger" and tied.get("name", "") == "Woolly Bugger", "the best fly you own is the one tied on")
	var plain := _game(7)
	var bugger := _game(7, tied)
	check(bugger.window() > plain.window(), "a better fly widens the green")
	var just_off := plain.meter_center + plain.window() / 2.0 + 0.01
	check(plain.judge(just_off) == "miss" and bugger.judge(just_off) == "good", "so a stop just off the plain fly's green is good with it")
	check(bugger.bite_chance(2) > plain.bite_chance(2) and bugger.bite_chance(1) == 0.0 and bugger.bite_chance(4) == 1.0,
		"it brings more fish up to a fair cast, but never to a missed one")
	plain.free()
	_cast(bugger, "perfect")
	_cast(bugger, "good")
	if bugger.rises and _drift(bugger) == FishingMinigame.Phase.REEL:
		check(bugger.line > FishingMinigame.HOOK_SET[3], "and sets the hook harder")
	bugger.free()
	var brown := Fishing.get_fish("brown_trout")
	check(Fishing.weight_for(brown, tied) == brown.weight * 2 and Fishing.weight_for(brown, {}) == brown.weight, "the bugger brings up browns twice as often")
	var rod := Fishing.new()
	add_child(rod)
	var browns := 0
	for i in 400:
		if rod.pick("yosemite_valley", GameClock.Season.SUMMER, tied).id == "brown_trout":
			browns += 1
	var plain_browns := 0
	for i in 400:
		if rod.pick("yosemite_valley", GameClock.Season.SUMMER).id == "brown_trout":
			plain_browns += 1
	check(browns > plain_browns + 40, "more browns on the bugger than on the plain fly (%d against %d)" % [browns, plain_browns])
	rod.free()
	Gear.start_new_game()


func test_greg_data() -> void:
	var greg := QuestLog.get_character(GREG)
	var quest := QuestLog.get_quest(QUEST)
	check(greg != null and greg.staff and not greg.visitor and greg in QuestLog.STAFF and greg.display_name == "Greg", "Greg is invented Curry Village staff, not in the Register")
	check(quest != null and quest.giver == GREG and not quest.main_line and quest.requires.is_empty(), "his quest is a side story you can start any time")
	check(Portraits.for_speaker("Greg") != null, "Greg has a portrait")
	check(Friendship.LOVES.has(GREG) and GuardianMirror.GATHERING.any(func(e: Array) -> bool: return e[0] == GREG), "he has favorite gifts and a line in the cave")
	check(ItemDB.get_item("greg_fly_box") != null, "his fly box is an item")
	var shop: ShopData = load("res://data/shops/greg_flies.tres")
	check(shop.offers.size() == 3 and shop.offers.all(func(o: ShopOffer) -> bool: return Fishing.FLIES.any(func(f: Dictionary) -> bool: return f.id == o.id)), "he trades the flies")
	check(shop.offers.filter(func(o: ShopOffer) -> bool: return not o.trade.is_empty()).size() == 2, "two of them for fish")


func test_greg_quest() -> void:
	Inventory.items.clear()
	Gear.start_new_game()
	QuestLog.start_new_game()
	check(QuestLog.marker_for(GREG) == "!", "Greg has a ! from the start")
	var lines := QuestLog.talk_to(GREG)
	check(QuestLog.active.get(QUEST, -1) == 0 and said(lines, "fly box"), "he's lost his fly box")
	lines = QuestLog.talk_to(GREG)
	check(QuestLog.active.get(QUEST, -1) == 0 and Gear.count(Fishing.ROD) == 0, "no rod until you find it")
	Inventory.add("greg_fly_box")
	lines = QuestLog.talk_to(GREG)
	check(Gear.count(Fishing.ROD) == 1 and Inventory.count("greg_fly_box") == 0, "bring it back and he gives you his old rod")
	check(said(lines, "Back cast first") and said(lines, "Two clean stops"), "and tells you how to cast")
	check(QuestLog.active.get(QUEST, -1) == 1 and said(lines, "brown trout"), "then asks to see a brown trout")
	Inventory.add("rainbow_trout" if ItemDB.get_item("rainbow_trout") else "trail_mix")
	lines = QuestLog.talk_to(GREG)
	check(QuestLog.active.get(QUEST, -1) == 1, "nothing else will do")
	Inventory.add("brown_trout")
	lines = QuestLog.talk_to(GREG)
	check(QuestLog.is_completed(QUEST) and Inventory.count("brown_trout") == 0, "bring him one and the quest is done")
	check(Gear.count("elk_hair_caddis") == 1 and Fishing.tied_fly().get("id", "") == "elk_hair_caddis", "he gives you an elk hair caddis, and it's tied on")
	lines = QuestLog.talk_to(GREG)
	check(not lines.is_empty() and QuestLog.marker_for(GREG) == "", "after that he just chats")


func test_greg_trades() -> void:
	var shop: ShopData = load("res://data/shops/greg_flies.tres")
	Inventory.items.clear()
	var open := Vendor.offers_open(shop)
	check(open.size() == 1 and open[0].id == "parachute_adams", "after the caddis, he offers a parachute adams")
	check(Vendor.cost_of(open[0]) == "costs %d" % open[0].price, "for food")
	check(Vendor.trade_for(open[0]).is_empty() and Gear.count("parachute_adams") == 0, "no food, no fly")
	Inventory.add("trail_mix", 2)
	check(not Vendor.trade_for(open[0]).is_empty() and Gear.count("parachute_adams") == 1, "food enough and it's yours")
	open = Vendor.offers_open(shop)
	check(open.size() == 1 and open[0].id == "woolly_bugger" and Vendor.cost_of(open[0]) == "for 2 Brown Trout", "next a woolly bugger, for two brown trout")
	Inventory.add("brown_trout")
	check(not Vendor.can_pay(open[0]) and Vendor.trade_for(open[0]).is_empty() and Inventory.count("brown_trout") == 1, "one trout won't do")
	var card := Vendor.card_of(open[0])
	check(card.rows.size() == 1 and card.rows[0][2] == true and "you have 1" in card.rows[0][1], "and the card says what you're short")
	Inventory.add("brown_trout")
	var paid := Vendor.trade_for(open[0])
	check(paid == {"brown_trout": 2} and Inventory.count("brown_trout") == 0 and Gear.count("woolly_bugger") == 1, "two and it's a swap")
	open = Vendor.offers_open(shop)
	check(open.size() == 1 and open[0].id == "royal_wulff" and open[0].trade.has("brook_trout"), "last, his Royal Wulff, for brook trout from Tuolumne")
	Inventory.add("brook_trout", 2)
	Vendor.trade_for(open[0])
	check(Gear.count("royal_wulff") == 1 and Vendor.offers_open(shop).is_empty(), "then he's traded you every fly he has")
	check(Fishing.tied_fly().get("id", "") == "royal_wulff", "and the Royal Wulff is tied on")


func test_greg_in_camp(world: Node) -> void:
	await world.go_to_region("curry_village", "arrival")
	await get_tree().process_frame
	var greg: NPC = null
	for node in world.region.find_children("*", "NPC", true, false):
		if node.character and node.character.id == GREG:
			greg = node
	check(greg != null and greg.shop != null and greg.shop.resource_path.ends_with("greg_flies.tres"), "Greg is in Curry Village, with his flies to trade")
	if greg == null:
		return
	var stops := NPC.parse_timetable(greg.timetable)
	var spots := {}
	for stop: Array in stops:
		spots[stop[1]] = true
		check(world.region.get_spawn(stop[1]) != null, "his stop '%s' is a spot in camp" % stop[1])
	check(spots.size() >= 7, "and he's all over the camp in a day (%d places)" % spots.size())
	greg._stops = stops
	check(stops[greg.stop_index(6 * 60 + 30)][1] == "river_bank" and stops[greg.stop_index(18 * 60)][1] == "river_bank", "on the river at dawn and dusk")
	var ground: TileMapLayer = Fishing._ground(world)
	var bank: Vector2 = world.region.get_spawn("river_bank").global_position
	var near := false
	for d in [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]:
		for reach in [32.0, 48.0, 64.0, 96.0]:
			near = near or Fishing.is_water(ground, bank + d * reach)
	check(near and not Fishing.is_water(ground, bank) and WalkGrid.of(world.region).is_open(bank), "his spot on the bank is dry ground beside the Merced")
	var box: StoryPickup = world.region.find_child("GregFlyBox", true, false)
	check(box != null and box.item_id == "greg_fly_box" and not Fishing.is_water(ground, box.global_position), "his fly box lies on the bank")
