extends Node
## Headless test of the Easter eggs: the Firefall, the moonbow, the Camp 4 night
## details, the bear boxes, the conditional story notes, Crow's Camp, and Chongo. See
## docs/DESIGN.md ("Easter eggs").
## Run: godot --headless --path . res://tests/eggs_test.tscn
## Exit code is the number of failed checks. Uses its own save file.

const SUMMER := GameClock.Season.SUMMER
const SPRING := GameClock.Season.SPRING

var failures := 0
var world: Node


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func set_time(season: int, day: int, hour: int, minute := 0) -> void:
	GameClock.season = season
	GameClock.day = day
	GameClock.minutes = hour * 60 + minute


func _ready() -> void:
	await get_tree().process_frame
	SaveManager.save_path = "user://eggs_test_save.json"
	SaveManager.delete_save()
	test_clock()
	test_info_sign()
	test_muir_line()
	world = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(world)
	await get_tree().process_frame
	GameClock.paused = true
	await test_firefall()
	await test_village()
	await test_wawona()
	await test_bear_tracks()
	await test_crows_camp()
	await test_chongo()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func test_clock() -> void:
	check(is_equal_approx(GameClock.moon_phase(14), 0.5), "the moon is full on day 14")
	check(is_equal_approx(GameClock.moon_phase(28), 0.0), "the moon is new on day 28")
	check(GameClock.is_full_moon(13) and GameClock.is_full_moon(14) and GameClock.is_full_moon(15), "days 13 to 15 count as full moon")
	check(not GameClock.is_full_moon(12) and not GameClock.is_full_moon(16) and not GameClock.is_full_moon(1), "other days don't")
	set_time(SPRING, 14, 22)
	check(GameClock.hour_in_range(21, 2) and GameClock.hour_in_range(0, 4) == false, "hour ranges: 10 PM is in 9 PM-2 AM, not in midnight-4 AM")
	set_time(SPRING, 14, 25, 30)
	check(GameClock.hour == 1 and GameClock.hour_in_range(21, 2) and GameClock.hour_in_range(0, 4), "hour ranges wrap past midnight")
	set_time(SUMMER, 5, 21, 0)
	check(GameClock.is_firefall_time(), "firefall at 9:00 PM in summer")
	GameClock.minutes = 21 * 60 + 10
	check(GameClock.is_firefall_time(), "firefall still on at 9:10 PM")
	GameClock.minutes = 21 * 60 + 20
	check(not GameClock.is_firefall_time(), "firefall over by 9:20 PM")
	GameClock.minutes = 20 * 60 + 50
	check(not GameClock.is_firefall_time(), "no firefall at 8:50 PM")
	set_time(SPRING, 5, 21, 0)
	check(not GameClock.is_firefall_time(), "no firefall in spring")
	set_time(SPRING, 14, 21)
	check(GameClock.is_moonbow_time(), "moonbow on a spring full-moon night")
	set_time(SPRING, 10, 21)
	check(not GameClock.is_moonbow_time(), "no moonbow without a full moon")
	set_time(SUMMER, 14, 21)
	check(not GameClock.is_moonbow_time(), "no moonbow in summer")
	set_time(SPRING, 14, 12)
	check(not GameClock.is_moonbow_time(), "no moonbow at noon")


func test_info_sign() -> void:
	var plain := InfoSign.new()
	plain.text = "Plain."
	check(plain.current_text() == "Plain." and not plain.extra_active(), "a sign with no extra text is unchanged")
	var sign := InfoSign.new()
	sign.text = "Base."
	sign.extra_text = "Extra."
	sign.extra_hours = Vector2i(0, 4)
	sign.extra_season = SPRING
	sign.extra_full_moon = true
	set_time(SPRING, 14, 25)
	check(sign.current_text() == "Base.\n\nExtra.", "extra text shows when every condition holds")
	set_time(SUMMER, 14, 25)
	check(sign.current_text() == "Base.", "wrong season hides it")
	set_time(SPRING, 3, 25)
	check(sign.current_text() == "Base.", "no full moon hides it")
	set_time(SPRING, 14, 12)
	check(sign.current_text() == "Base.", "wrong hour hides it")
	var gated := InfoSign.new()
	gated.text = "Base."
	gated.extra_text = "Extra."
	gated.extra_after_quest = "tenaya_ahwahnee"
	QuestLog.start_new_game()
	check(gated.current_text() == "Base.", "a quest-gated note is hidden at first")
	QuestLog.completed.append("tenaya_ahwahnee")
	check(gated.current_text() == "Base.\n\nExtra.", "and shows once the quest is done")
	var called := InfoSign.new()
	called.text = "Base."
	called.extra_text = "Extra."
	called.extra_when = func(): return false
	check(not called.extra_active(), "extra_when can veto the extra text")
	for node in [plain, sign, gated, called]:
		node.free()
	QuestLog.start_new_game()


func test_muir_line() -> void:
	var muir := load("res://data/characters/john_muir.tres") as CharacterData
	check(muir.rare_lines.size() == 2 and muir.rare_after_quest == "muir_glacier", "Muir has two rare lines after his glacier quest")
	check(muir.idle_lines_for(true, 0.0) == muir.rare_lines, "a low roll gives the windstorm story")
	check(muir.idle_lines_for(true, 0.9) == muir.idle_lines, "a high roll gives the usual lines")
	check(muir.idle_lines_for(false, 0.0) == muir.idle_lines, "never before the quest is done")
	QuestLog.start_new_game()
	QuestLog.completed.append("muir_cathedral")
	var told := 0
	for i in 40:
		for line in QuestLog.talk_to("john_muir"):
			if "Yuba" in line.text:
				told += 1
	check(told == 0, "idle talks before the glacier quest never tell it")
	QuestLog.active.erase("muir_glacier") # he offered it above; finish it
	QuestLog.completed.append("muir_glacier")
	QuestLog.completed.append("muir_soda_springs") # and his campfire side story, so only idle talk is left
	told = 0
	var talks := 400
	for i in talks:
		for line in QuestLog.talk_to("john_muir"):
			if "Yuba" in line.text:
				told += 1
	check(told > talks * 0.1 and told < talks * 0.3, "after it, about 1 talk in 5 tells it (%d of %d)" % [told, talks])
	QuestLog.start_new_game()


func test_firefall() -> void:
	world._enter_region("curry_village", "plaza")
	await get_tree().process_frame
	var fall := world.region.find_child("Firefall", true, false) as Firefall
	check(fall != null and fall.get_parent() == world.region.entities, "the Curry Village overlay places the Firefall")
	var board := world.region.find_child("FirefallBoard", true, false) as InfoSign
	check(board != null, "the Firefall board is a sign")
	set_time(SUMMER, 5, 12)
	fall._process(0.0)
	check(not fall.visible, "no firefall at noon")
	set_time(SUMMER, 5, 21, 0)
	world.hud.message_label.text = ""
	fall._process(0.0)
	check(fall.visible, "the firefall starts at 9 PM in summer")
	check(world.hud.message_label.text == Firefall.MESSAGE, "someone calls up to the rim")
	check(fall.level == 0.0, "the embers wait for the call")
	fall._process(3.0)
	check(fall.level > 0.9, "then the glow builds")
	check("Let the fire fall" in board.current_text() and board.current_text().begins_with(board.text), "the board gets its extra line during the show")
	set_time(SUMMER, 5, 21, 10)
	check(board.extra_active(), "and still at 9:10 PM")
	set_time(SUMMER, 5, 21, 30)
	fall._process(10.0)
	fall._process(10.0)
	check(not fall.visible and fall.level == 0.0, "the firefall is gone after the show")
	check(board.current_text() == board.text, "and the board reads as before")
	set_time(SPRING, 5, 21, 0)
	fall._process(0.0)
	check(not fall.visible and board.current_text() == board.text, "nothing in spring")
	# The sign is the usual one when no condition is set (generated scene untouched).
	check(board.text.begins_with("Starting in the 1870s"), "the board's own text is kept")
	# Bear boxes in the village.
	var box: Node = world.region.find_child("BearBox12", true, false)
	check(box is InfoSign and box.has_method("interact") and box.get_node_or_null("Hitbox") != null, "Curry Village bear boxes can be read")
	check(box != null and "Black bears" in box.get("text") and "day and night" in box.get("text"), "the bear box says to store food")
	GameClock.minutes = 12 * 60
	GameClock.season = SPRING


func test_village() -> void:
	world._enter_region("yosemite_village", "lower_yosemite_fall")
	await get_tree().process_frame
	var bow := world.region.find_child("Moonbow", true, false) as Moonbow
	var fall_sign := world.region.find_child("LowerFallSign", true, false) as InfoSign
	check(bow != null and fall_sign != null, "the village has a moonbow and the Lower Fall sign")
	set_time(SPRING, 14, 22)
	bow._process(0.0)
	check(bow.visible, "a moonbow on a spring full-moon night at 10 PM")
	check("moonbow" in fall_sign.current_text() and fall_sign.current_text().begins_with(fall_sign.text), "the sign adds a line about it")
	set_time(SPRING, 14, 25, 30)
	bow._process(0.0)
	check(bow.visible and "moonbow" in fall_sign.current_text(), "still there at 1:30 AM")
	set_time(SPRING, 14, 20)
	bow._process(0.0)
	bow._process(10.0)
	check(not bow.visible and fall_sign.current_text() == fall_sign.text, "not before 9 PM")
	set_time(SPRING, 9, 22)
	bow._process(10.0)
	check(not bow.visible and fall_sign.current_text() == fall_sign.text, "not without a full moon")
	set_time(SUMMER, 14, 22)
	bow._process(10.0)
	check(not bow.visible, "not in summer")

	# Camp 4 after midnight.
	var boulder := world.region.find_child("ColumbiaBoulder", true, false) as InfoSign
	var lamp := boulder.get_node_or_null("Headlamp") as Headlamp
	check(lamp != null, "the Midnight Lightning boulder has a headlamp")
	set_time(SUMMER, 5, 25, 30)
	lamp._process(0.0)
	check("freshly chalked" in boulder.current_text() and boulder.current_text().begins_with(boulder.text), "the boulder sign has its past-midnight line at 1:30 AM")
	check(lamp.visible, "the headlamp glows on the ledge")
	set_time(SUMMER, 5, 22)
	lamp._process(0.0)
	check(boulder.current_text() == boulder.text and not lamp.visible, "not at 10 PM")
	set_time(SUMMER, 5, 12)
	lamp._process(0.0)
	check(boulder.current_text() == boulder.text and not lamp.visible, "not at noon")
	var box: Node = world.region.find_child("Site0BearBox", true, false)
	check(box is InfoSign and box.get_node_or_null("Hitbox") != null, "Camp 4 bear boxes can be read")
	GameClock.minutes = 12 * 60


func test_wawona() -> void:
	world._enter_region("wawona", "arrival")
	await get_tree().process_frame
	var clark := world.region.find_child("Sign_Clarks_Station", true, false) as InfoSign
	check(clark != null, "Wawona has Clark's Station sign")
	QuestLog.start_new_game()
	check(clark.current_text() == clark.text, "no note before Tenaya's story")
	QuestLog.completed.append("tenaya_ahwahnee")
	check("Write it at the front of the book" in clark.current_text() and clark.current_text().begins_with(clark.text), "the note is pinned in the window after Tenaya's story")
	QuestLog.start_new_game()


func test_bear_tracks() -> void:
	world._enter_region("lamon_homestead", "home")
	await get_tree().process_frame
	var tracks: String = world.BEAR_TRACKS_MESSAGE
	GameClock.paused = false
	set_time(SPRING, 3, 25, 50)
	world.hud.message_label.text = ""
	await world.sleep(true)
	check("passed out" in world.hud.message_label.text, "passing out shows the usual message first")
	await get_tree().create_timer(world.BEAR_TRACKS_DELAY + 0.5).timeout
	check(world.hud.message_label.text == tracks, "then bear tracks by the fence")
	check("zipped" in tracks and Inventory.items.is_empty(), "the pack was zipped, nothing lost")
	await world.sleep(false)
	await get_tree().create_timer(world.BEAR_TRACKS_DELAY + 0.5).timeout
	check(world.hud.message_label.text != tracks, "an ordinary night doesn't repeat it")
	SaveManager.delete_save()


func _find_box() -> DialogueBox:
	for child in get_tree().root.get_children():
		if child is DialogueBox and not child.is_queued_for_deletion():
			return child
	return null


func _trip_effects() -> Array:
	return get_tree().root.get_children().filter(func(n: Node) -> bool: return n is TripEffect and not n.is_queued_for_deletion())


## The secret up Tenaya Creek: the cairn at Mirror Lake, the way through the
## boulders, and Crow, his paper and his joint.
func test_crows_camp() -> void:
	world._enter_region("mirror_lake", "cairn")
	await get_tree().process_frame
	var cairn := world.region.find_child("Cairn", true, false) as InfoSign
	check(cairn != null and "cairn" in cairn.title.to_lower(), "a cairn stands on the Mirror Lake shore")
	var way: RegionExit = world.region.find_child("ToCrowsCamp", true, false)
	check(way != null and way.target_region == "crows_camp", "past it, a path leads up Tenaya Creek to Crow's Camp")
	world._enter_region("crows_camp", "west")
	await get_tree().process_frame
	check(world.region.region_id == "crows_camp", "the path comes out in Crow's Camp")
	var crow := world.region.find_child("Crow", true, false) as Crow
	check(crow != null and crow.character.id == "crow" and crow.character.visitor, "Crow camps there, a visitor, not in the Register")
	var box := world.region.entities.get_node_or_null("BearBox") as InfoSign
	check(box != null and "DON'T" in box.text, "his bear box can be read")
	var places: Array = world.region.get_places()
	check(places.all(func(p: Place) -> bool: return not p.show_on_map), "the camp isn't labelled on the map")
	set_time(SUMMER, 5, 23)
	check(crow.is_out(), "Crow is home at night too")
	GameClock.minutes = 12 * 60
	if crow == null:
		return
	# First meeting: say yes to the paper, then to the joint.
	QuestLog.heard_beats.erase(Crow.MET)
	Crow.paper_day = ""
	var player: Player = world.player
	Engine.time_scale = 8.0
	crow.interact(player)
	var tripped := false
	var hazed := false
	for i in 4000:
		await get_tree().process_frame
		var fx := _trip_effects()
		if not fx.is_empty():
			if fx.any(func(f: TripEffect) -> bool: return f.layer == 50 and f.intensity > 0.5):
				tripped = true
			if fx.any(func(f: TripEffect) -> bool: return f.layer == 49):
				hazed = true
		var dialogue := _find_box()
		if dialogue:
			dialogue._cursor = 0
			dialogue.press()
		elif not crow._talking:
			break
	Engine.time_scale = 1.0
	check(tripped, "the little piece of paper turns the screen psychedelic")
	check(hazed, "and the joint leaves a haze")
	check(Crow.has_met() and player.can_act and not crow._talking, "then he remembers you and lets you go")
	check(Crow.paper_day == Crow._today(), "one paper a day")
	for fx: TripEffect in _trip_effects():
		fx.free()


## Chongo, a different rock every day: where he turns up, that he stands by a
## boulder, selling you his physics book for a snack, and a lesson after.
func test_chongo() -> void:
	var places := {}
	for day in range(1, 29):
		var morning := Chongo.haunt("1-0-%d" % day, false)
		var afternoon := Chongo.haunt("1-0-%d" % day, true)
		places[morning] = true
		places[afternoon] = true
		if morning == afternoon or morning not in Chongo.HAUNTS or afternoon not in Chongo.HAUNTS:
			places["bad"] = true
	check(not places.has("bad"), "Chongo moves to another of his haunts every afternoon")
	check(places.size() >= 8, "he turns up all over the park over a season (%d places)" % places.size())
	set_time(SUMMER, 5, 6)
	check(Chongo.where_now() == "", "he isn't out before breakfast")
	GameClock.minutes = 21 * 60
	check(Chongo.where_now() == "", "or after dark")
	# Every haunt has boulders he can stand by.
	for id: String in Chongo.HAUNTS:
		world._enter_region(id)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var key := "test:" + id
		var spot := Chongo.pick_spot(world.region, key)
		var rocks := Chongo.boulders(world.region)
		check(not rocks.is_empty() and not spot.is_empty() and (spot.rock in rocks or spot.rock is Place) and WalkGrid.of(world.region).is_open(spot.at),
			"%s has a boulder he can stand by (%d rocks)" % [id, rocks.size()])
		check(not world.region.entities.has_node("Chongo"), "and he isn't in %s while he's off the clock" % id)
	# Find a summer morning he's in the Village, and go meet him.
	var day := 1
	while Chongo.haunt("1-1-%d" % day, false) != "yosemite_village" and day < 200:
		day += 1
	GameClock.year = 1
	set_time(SUMMER, day, 9)
	check(Chongo.where_now() == "yosemite_village", "some mornings he's in the Village")
	world._enter_region("yosemite_village")
	var chongo: Chongo = null
	for i in 10:
		await get_tree().physics_frame
		chongo = world.region.entities.get_node_or_null("Chongo") as Chongo
		if chongo:
			break
	check(chongo != null and chongo.character.visitor, "there he is, a visitor, not in the Register")
	if chongo == null:
		return
	check(chongo.rock in Chongo.boulders(world.region) or chongo.rock is Place, "standing by a boulder (or a named spot)")
	check(chongo.global_position.distance_to(chongo.rock.global_position) < 80.0 or chongo.rock is Place, "right next to it")
	var where := chongo.global_position
	world._enter_region("curry_village")
	await get_tree().physics_frame
	world._enter_region("yosemite_village")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var again := world.region.entities.get_node_or_null("Chongo") as Chongo
	check(again != null and again.global_position == where, "he's at the same rock when you come back")
	# Buy the book for a snack.
	QuestLog.heard_beats.erase(Chongo.MET)
	QuestLog.heard_beats.erase(Chongo.SOLD)
	for id in FoodDB.edible_in_inventory():
		Inventory.remove(id, Inventory.count(id))
	Inventory.remove(Chongo.BOOK, Inventory.count(Chongo.BOOK))
	var player: Player = world.player
	await _talk(again, player, 0)
	check(Chongo.has_met() and not Chongo.has_sold() and Inventory.count(Chongo.BOOK) == 0, "with no food, he can't sell you the book")
	Inventory.add("chocolate_bar")
	await _talk(again, player, 0)
	check(Chongo.has_sold() and Inventory.count(Chongo.BOOK) == 1, "he trades you his physics book")
	check(Inventory.count("chocolate_bar") == 0, "for a chocolate bar")
	check(ItemDB.get_item(Chongo.BOOK) != null and ItemDB.get_item(Chongo.BOOK).icon != null, "the book is an item with a picture")
	var spoken: Array[String] = []
	await _talk(again, player, 0, spoken)
	check(spoken.any(func(t: String) -> bool: return t.begins_with("Chapter")), "then he teaches you a page of it")
	check(player.can_act and not again._talking, "and lets you go")
	# Later he moves on to the afternoon's rock, somewhere else.
	GameClock.minutes = 14 * 60
	world._enter_region("curry_village")
	await get_tree().physics_frame
	world._enter_region("yosemite_village")
	await get_tree().physics_frame
	check(not world.region.entities.has_node("Chongo"), "in the afternoon he's gone to another rock")
	Inventory.remove(Chongo.BOOK)


## Talks to [param npc], picking [param option] at every choice, and collects
## what's said in [param spoken].
func _talk(npc: NPC, player: Player, option: int, spoken: Array[String] = []) -> void:
	Engine.time_scale = 8.0
	npc.interact(player)
	for i in 2000:
		await get_tree().process_frame
		var dialogue := _find_box()
		if dialogue:
			var text: String = dialogue._text_label.text
			if text != "" and (spoken.is_empty() or spoken[-1] != text):
				spoken.append(text)
			dialogue._cursor = option
			dialogue.press()
		elif not npc._talking:
			break
	Engine.time_scale = 1.0
