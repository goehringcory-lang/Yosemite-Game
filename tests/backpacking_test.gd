extends Node
## Headless test of camping anywhere with the backpacking pack (Backpacking):
## Hodges's "Leave No Trace" quest after The First Night Out, Marty fitting
## the pack, the pack showing on your walking sheet while it's in your bag,
## "Make camp" in the evening on open ground, the Leave No Trace checks
## (food in the canister, back from water, off the trail, off the meadow, a
## fire only in a ring), waking up where you camped, and the wilderness
## ranger who takes your food and fines you after a bad camp.
## Run: godot --headless --path . res://tests/backpacking_test.tscn
## Exit code is the number of failed checks. Uses its own save file.

const Terrain := preload("res://scripts/world/terrain.gd")

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func said(lines: Array[Dictionary], text: String) -> bool:
	return lines.any(func(l: Dictionary) -> bool: return text in l.text)


func _ready() -> void:
	Park.open_world = false
	await get_tree().process_frame
	SaveManager.save_path = "user://backpacking_test_save.json"
	SaveManager.delete_save()
	var world = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(world)
	await get_tree().process_frame
	GameClock.paused = true
	test_data()
	test_quest()
	test_sheet()
	await test_offer(world)
	await test_checks(world)
	await test_clean_camp(world)
	await test_ranger(world)
	SaveManager.delete_save()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func _fresh() -> void:
	NewGame.reset()
	GameClock.season = GameClock.Season.SUMMER
	GameClock.day = 5
	GameClock.minutes = 10 * 60


func test_data() -> void:
	var quest := QuestLog.get_quest(Backpacking.QUEST)
	check(quest != null and quest.giver == "clare_hodges" and "hodges_first_night" in quest.requires, "Hodges gives Leave No Trace after The First Night Out")
	var pack := Gear.get_gear(Backpacking.PACK)
	check(pack != null and pack.icon != null, "the backpacking pack is gear, with an icon")
	check(Gear.bulk(Backpacking.PACK) == 0, "and it takes no room in the bag (it is the bag)")
	var ranger := load(Backpacking.RANGER_DATA) as CharacterData
	check(ranger != null and ranger.display_name == Backpacking.RANGER and ranger.sprite_sheet != null, "the wilderness ranger has a walking sheet")
	check(CharacterSheet.has_poses(ranger.sprite_sheet), "with every pose")
	check(Portraits.for_speaker(Backpacking.RANGER) != null, "and a portrait")
	for id: String in Backpacking.PROBLEMS:
		check(Backpacking.WARNINGS.has(id) and Backpacking.LESSONS.has(id), "%s has a warning and a lesson" % id)


func test_quest() -> void:
	_fresh()
	QuestLog.completed.append_array(["hodges_patrol", "hodges_first_night"])
	var lines := QuestLog.talk_to("clare_hodges")
	check(QuestLog.active.has(Backpacking.QUEST), "talking to Hodges starts Leave No Trace")
	check(said(lines, "Mountain Shop"), "and she sends you to the Mountain Shop")
	check(not Backpacking.worn(), "no pack yet")
	QuestLog.talk_to("mountain_shop")
	check(Gear.count(Backpacking.PACK) == 1 and Backpacking.worn(), "Marty fits the pack, and you're wearing it")
	check(QuestLog.active.get(Backpacking.QUEST) == 1, "on to the night out")
	QuestLog.talk_to("clare_hodges")
	check(QuestLog.active.get(Backpacking.QUEST) == 1, "nothing to turn in before a clean camp")
	Backpacking.mark(Backpacking.CLEAN_CAMP)
	QuestLog.talk_to("clare_hodges")
	QuestLog.talk_to("clare_hodges")
	check(QuestLog.is_completed(Backpacking.QUEST), "after a clean camp, Hodges finishes it")
	Gear.unpack(Backpacking.PACK)
	check(not Backpacking.worn(), "hung on the rack, the pack is off")
	check(CampPiece.rack_menu(false).get("actions", []).has(Backpacking.PACK) == false, "and isn't offered to hang up again")
	Gear.pack(Backpacking.PACK)
	check(Backpacking.worn(), "packed again, it's back on")
	check(CampPiece.rack_menu(false).get("actions", []).has(Backpacking.PACK), "the rack offers to hang it up")


func test_sheet() -> void:
	_fresh()
	var plain := PlayerLook.sheet().get_image()
	Gear.add(Backpacking.PACK)
	var packed := PlayerLook.sheet().get_image()
	check(plain.get_size() == packed.get_size(), "the sheet with the pack is the same size")
	check(plain.get_data() != packed.get_data(), "and the pack shows on it")
	Gear.unpack(Backpacking.PACK)
	check(PlayerLook.sheet().get_image().get_data() == plain.get_data(), "taken off, it's the shipped sheet again")


## A cell of [param region]'s ground for which [param want] is true, as a
## position in the middle of it, or null.
func _find_spot(region: Region, want: Callable) -> Variant:
	var ground := region.get_ground()
	var bounds := region.get_bounds().grow(-Backpacking.EDGE_MARGIN - 32.0)
	for cell in ground.get_used_cells():
		var at := ground.to_global(ground.map_to_local(cell))
		if bounds.has_point(ground.to_local(at)) and want.call(ground, at):
			return at
	return null


func _clean(region: Region) -> Callable:
	return func(ground: TileMapLayer, at: Vector2) -> bool:
		var type := Backpacking.type_at(ground, at)
		return not Terrain.is_solid(type) and type >= 0 and type != Terrain.CREEK \
			and Backpacking.problems(region, at).is_empty()


func test_offer(world: Node) -> void:
	_fresh()
	world._enter_region("little_yosemite_valley", "camp")
	await get_tree().physics_frame
	var player: Player = world.player
	player.can_act = true
	GameClock.minutes = 20 * 60
	check(not Backpacking.can_offer(player), "no pack, no Make camp")
	Gear.add(Backpacking.PACK)
	check(Backpacking.can_offer(player), "with the pack on, at 8 PM, you can make camp")
	GameClock.minutes = 14 * 60
	check(not Backpacking.can_offer(player), "but not in the afternoon")
	GameClock.minutes = 1 * 60
	check(Backpacking.can_offer(player), "and still at 1 AM")
	world._enter_region(Park.HOME_REGION, Park.HOME_SPAWN)
	await get_tree().physics_frame
	GameClock.minutes = 20 * 60
	check(not Backpacking.can_offer(player), "not at home, where your tent already is")
	world._enter_region("little_yosemite_valley", "camp")
	await get_tree().physics_frame
	GameClock.season = GameClock.Season.WINTER
	check(Backpacking.refusal(world.region, world.player.global_position) != "", "in winter, no tent out")
	GameClock.season = GameClock.Season.SUMMER
	check(Backpacking.refusal(world.region, world.region.get_bounds().position + Vector2(4, 4)) != "", "not at the edge of the map")


func test_checks(world: Node) -> void:
	_fresh()
	Gear.add(Backpacking.PACK)
	world._enter_region("little_yosemite_valley", "camp")
	await get_tree().physics_frame
	var region: Region = world.region
	var clean = _find_spot(region, _clean(region))
	check(clean != null, "Little Yosemite Valley has somewhere to camp cleanly")
	var by_water = _find_spot(region, func(g: TileMapLayer, at: Vector2) -> bool:
		return not Terrain.is_solid(Backpacking.type_at(g, at)) and Backpacking.type_at(g, at) >= 0 \
			and Backpacking.near_type(g, at, Backpacking.WATER, Backpacking.WATER_REACH) \
			and not Backpacking.near_type(g, at, Backpacking.WATER, 8.0))
	check(by_water != null and "water" in Backpacking.problems(region, by_water), "a bank by the river is too close to water")
	var on_trail = _find_spot(region, func(g: TileMapLayer, at: Vector2) -> bool: return Backpacking.type_at(g, at) == Terrain.TRAIL)
	check(on_trail != null and "trail" in Backpacking.problems(region, on_trail), "the trail is no place to sleep")
	var meadow = _find_spot(world.region, func(g: TileMapLayer, at: Vector2) -> bool: return Backpacking.type_at(g, at) == Terrain.MEADOW)
	if meadow == null:
		world._enter_region("tuolumne_meadows", "")
		await get_tree().physics_frame
		meadow = _find_spot(world.region, func(g: TileMapLayer, at: Vector2) -> bool: return Backpacking.type_at(g, at) in Backpacking.MEADOWS)
	check(meadow != null and "meadow" in Backpacking.problems(world.region, meadow), "a meadow isn't durable ground")
	world._enter_region("little_yosemite_valley", "camp")
	await get_tree().physics_frame
	region = world.region
	if clean != null:
		check("fire" in Backpacking.problems(region, clean, true), "a new fire, away from any ring, breaks the rules")
		check(not Backpacking.problems(region, clean).has("food"), "no food at all is fine")
		Inventory.add("pilot_bread", 3)
		check("food" in Backpacking.problems(region, clean), "food and no canister is not")
		Gear.add(Backcountry.CANISTER)
		check(Backpacking.problems(region, clean).is_empty(), "with the canister, it's clean")
		Inventory.add("trail_mix", Backcountry.CANISTER_HOLDS)
		check("food" in Backpacking.problems(region, clean), "but not more food than the canister holds")
		check(Backpacking.preview(region, clean).contains(Backpacking.WARNINGS.food), "and the box says so before you sleep")


func test_clean_camp(world: Node) -> void:
	_fresh()
	Gear.add(Backpacking.PACK)
	Gear.add(Backcountry.CANISTER)
	Inventory.add(Backcountry.PERMIT)
	Inventory.add("pilot_bread", 3)
	world._enter_region("little_yosemite_valley", "camp")
	await get_tree().physics_frame
	var at = _find_spot(world.region, _clean(world.region))
	if at == null:
		check(false, "found a clean spot to camp")
		return
	world.player.global_position = at
	GameClock.minutes = 21 * 60
	var date := [GameClock.season, GameClock.day]
	await world.camp_out(at, Backpacking.problems(world.region, at))
	check(world.region.region_id == "little_yosemite_valley", "you wake up in the same area")
	check(world.player.global_position.distance_to(at) < 40.0, "on the spot where you camped")
	check([GameClock.season, GameClock.day] != date, "the next day")
	check(Inventory.count("pilot_bread") == 3, "with your food safe")
	check(QuestLog.is_unlocked(Backpacking.CLEAN_CAMP), "and a clean camp counts for Hodges")
	check(world.region.entities.find_child("WildernessRanger", true, false) == null, "no ranger")
	var saved := SaveManager.peek_node(world.name)
	check(str(saved.get("region", "")) == "little_yosemite_valley", "the game saved there")


func test_ranger(world: Node) -> void:
	_fresh()
	Gear.add(Backpacking.PACK)
	Inventory.add("pilot_bread", 4)
	Inventory.add("trail_mix", 2)
	Inventory.add("wilderness_permit")
	Inventory.add("rusty_piton", 6)
	world._enter_region("little_yosemite_valley", "camp")
	await get_tree().physics_frame
	var at = _find_spot(world.region, func(g: TileMapLayer, at: Vector2) -> bool: return Backpacking.type_at(g, at) == Terrain.TRAIL)
	if at == null:
		check(false, "found a trail to camp on")
		return
	world.player.global_position = at
	GameClock.minutes = 21 * 60
	var found := Backpacking.problems(world.region, at, true)
	check(found.has("food") and found.has("trail") and found.has("fire"), "on the trail, food loose, a new fire: three problems")
	var trade_goods := Barter.purse()
	var done := [false]
	var run := func() -> void:
		await world.camp_out(at, found)
		done[0] = true
	run.call()
	var saw_ranger := false
	var spoken: Array[String] = []
	for i in 4000:
		await get_tree().process_frame
		if world.region.entities.find_child("WildernessRanger", true, false):
			saw_ranger = true
		var box := _find_box()
		if box:
			var text: String = box._text_label.text
			if text != "" and (spoken.is_empty() or spoken[-1] != text):
				spoken.append(text)
			box.press()
		elif done[0]:
			break
	check(done[0], "the morning finishes")
	check(saw_ranger, "you wake up beside the ranger")
	check(world.player.global_position.distance_to(at) < 40.0, "where you camped")
	var all := "\n".join(spoken)
	check(all.contains("trail") and all.contains("canister") and all.contains("ring"), "who tells you each thing you did wrong")
	check(all.contains("Leave No Trace"), "and about Leave No Trace")
	var food_left := 0
	for id: String in Inventory.items:
		if FoodDB.is_food(id):
			food_left += Inventory.count(id)
	check(food_left == 0, "and takes all your food")
	check(Inventory.count("wilderness_permit") == 1, "but not your permit")
	check(Gear.count(Backpacking.PACK) == 1, "or your pack")
	check(not QuestLog.is_unlocked(Backpacking.CLEAN_CAMP), "a bad camp doesn't count for Hodges")
	await get_tree().create_timer(2.5).timeout
	await get_tree().process_frame
	check(world.region.entities.find_child("WildernessRanger", true, false) == null, "then the ranger walks off")
	check(Inventory.count("rusty_piton") < 6 and all.contains("fine"), "and fines you, in goods (%d worth to trade before)" % trade_goods)
	check(Backpacking.fine_for(3) == 30 and Backpacking.fine_for(9) == Backpacking.FINE_CAP, "the fine is 10 a problem, capped")


func _find_box() -> DialogueBox:
	for child in get_tree().root.get_children():
		if child is DialogueBox and not child.is_queued_for_deletion():
			return child
	return null
