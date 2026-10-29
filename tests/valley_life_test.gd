extends Node
## Headless test of the Valley's daily life: the Camp 4 bulletin board's
## notes (BoardRequests), the field log of birds and animals (FieldLog),
## the bears and deer that wander by (Bears, Deer),
## fishing (Fishing, FishingMinigame), the festivals (Festivals), with their Journal and Quests
## sections, the day's page, and saving.
## Run: godot --headless --path . res://tests/valley_life_test.tscn
## Exit code is the number of failed checks.

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	SaveManager.save_path = "user://valley_life_test_save.json"
	SaveManager.delete_save()
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().process_frame
	await get_tree().process_frame
	GameClock.paused = true

	test_board_definitions()
	test_board_posting()
	test_board_delivery()
	await test_board_object(world)
	test_field_log_definitions()
	await test_field_log_spotting(world)
	await test_bears(world)
	await test_deer(world)
	test_field_log_listening(world)
	test_fish_definitions()
	await test_minigame()
	await test_fishing_spot(world)
	test_landing_fish()
	test_festival_definitions()
	test_festival_day()
	await test_facelift(world)
	test_journal_and_day_log(world)
	test_save_and_load()

	SaveManager.delete_save()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func _journal_lines(which := Journal.Tab.JOURNAL) -> Array[String]:
	var journal: Journal = get_tree().get_first_node_in_group("journal")
	journal.open(which)
	var lines: Array[String] = []
	for node in journal._body.find_children("*", "Label", true, false):
		lines.append((node as Label).text.strip_edges())
	journal.close()
	return lines


## A dry day (Weather.today() keeps one answer a day).
func _fair_weather() -> void:
	Weather.today()
	Weather._today = {"snow": 0.0, "rain": 0.0, "clouds": 0.3}


func _has_line(lines: Array[String], part: String) -> bool:
	return lines.any(func(l: String) -> bool: return part in l)


func test_board_definitions() -> void:
	var ids := {}
	var native := ["tenaya", "maggie_howard", "lucy_telles", "maria_lebrado", "carrie_bethel"]
	for note: Dictionary in BoardRequests.NOTES:
		var ok: bool = not ids.has(note.id) and note.text != "" and note.thanks != "" and int(note.count) > 0
		ok = ok and QuestLog.get_character(note.giver) != null and not note.giver in native
		ok = ok and ItemDB.get_item(note.item) != null and not note.reward.is_empty() and not note.seasons.is_empty()
		for id: String in note.reward:
			ok = ok and ItemDB.get_item(id) != null
		ids[note.id] = true
		check(ok, "board note %s has a real giver, item and reward, and its own id" % note.id)
	for season in 4:
		check(BoardRequests.NOTES.any(func(n: Dictionary) -> bool: return season in n.seasons),
			"some note can go up in %s" % GameClock.SEASON_NAMES[season])


func test_board_posting() -> void:
	BoardRequests.start_new_game()
	Friendship.start_new_game()
	GameClock.season = GameClock.Season.SPRING
	check(BoardRequests.read().begins_with("Notes for partners"), "the board has nothing for you before you know anyone")
	check(BoardRequests.taken.is_empty(), "...and you take nothing down")
	# get to know Bridget Degnan and Jennie Curry
	Friendship.note_talk("bridget_degnan")
	Friendship.note_talk("jennie_curry")
	BoardRequests.posted_day = -1
	var text := BoardRequests.read()
	check(BoardRequests.taken.size() == 2, "two notes go up in a morning, one from each person you know (%s)" % [BoardRequests.taken.keys()])
	var givers := {}
	for id: String in BoardRequests.taken:
		var note := BoardRequests.get_note(id)
		givers[note.giver] = true
		check(GameClock.Season.SPRING in note.seasons, "%s is in season" % id)
	check(givers.has("bridget_degnan") and givers.has("jennie_curry"), "the notes are from the people you know")
	check("in your Quests" in text, "reading the board says the notes went in your Quests")
	check(BoardRequests.read().begins_with("Nothing new"), "reading again the same day finds nothing new")
	# the notes run out after LASTS days
	var saved := BoardRequests.taken.duplicate()
	for id: String in BoardRequests.taken:
		BoardRequests.taken[id] = Friendship.today() - BoardRequests.LASTS
	BoardRequests._expire()
	check(BoardRequests.taken.is_empty(), "notes come down once their days are up")
	BoardRequests.taken = saved


func test_board_delivery() -> void:
	var id := ""
	for key: String in BoardRequests.taken:
		if BoardRequests.get_note(key).giver == "bridget_degnan":
			id = key
	check(id != "", "Bridget has a note out")
	if id == "":
		return
	var note := BoardRequests.get_note(id)
	var entry: Dictionary = BoardRequests.open_notes().filter(func(e: Dictionary) -> bool: return e.note.id == id)[0]
	check(BoardRequests.objective(entry).begins_with("Bring ") and "Bridget Degnan" in BoardRequests.objective(entry),
		"the Quests line says what to bring and to whom (%s)" % BoardRequests.objective(entry))
	Inventory.start_new_game()
	Inventory.add(note.item, int(note.count) - 1)
	check(BoardRequests.deliver("bridget_degnan").is_empty() and BoardRequests.taken.has(id), "one short, nothing is handed over")
	Inventory.add(note.item, 1)
	var before := int(Friendship.points.get("bridget_degnan", 0))
	var lines := BoardRequests.deliver("bridget_degnan")
	check(lines.size() == 2 and lines[0].text == note.thanks and lines[1].text.begins_with("Board note done."), "handing it over gets her thanks and a reward line")
	check(Inventory.count(note.item) == 0 and not BoardRequests.taken.has(id) and BoardRequests.done == 1, "the things are taken and the note is done")
	for reward: String in note.reward:
		check(Inventory.count(reward) == int(note.reward[reward]), "you're given %s" % reward)
	check(int(Friendship.points.get("bridget_degnan", 0)) == before + BoardRequests.POINTS, "...and a little friendship")


func test_board_object(world: Node) -> void:
	world._enter_region("yosemite_village", "arrival")
	await get_tree().process_frame
	var board: Node = world.region.entities.get_node_or_null("RouteBoard")
	check(board is BulletinBoard, "the Camp 4 bulletin board can be read for notes")
	if board is BulletinBoard:
		BoardRequests.posted_day = -1
		board.interact(world.player)
		check(world.hud.info_panel.visible and "Climbers have found partners" in world.hud.info_text.text,
			"reading it shows the board's own notes too")


func test_field_log_definitions() -> void:
	var ids := {}
	for animal: Dictionary in FieldLog.ANIMALS:
		var ok: bool = not ids.has(animal.id) and animal.name != "" and animal.latin != "" and animal.note != "" and animal.hint != ""
		ok = ok and animal.how in ["seen", "heard", "tracks", "caught"] and not animal.seasons.is_empty()
		ids[animal.id] = true
		check(ok, "%s has a name, Latin name, how to find it and a note" % animal.id)
	for kind: String in Critters.BIRDS:
		check(ids.has(kind), "the %s on the ground is in the field log" % kind)
	for i in Critters.BUTTERFLY_KINDS:
		check(ids.has("butterfly_%d" % i), "butterfly %d is in the field log" % i)


func test_field_log_spotting(world: Node) -> void:
	FieldLog.start_new_game()
	_fair_weather()
	GameClock.minutes = 10 * 60
	var critters: Critters = world.find_children("*", "Critters", true, false)[0]
	var player: Player = world.player
	var bird := critters.add_bird("robin", player.global_position + Vector2(Critters.SPOT_DISTANCE + 60.0, 0))
	await get_tree().process_frame
	check(not FieldLog.has("robin"), "a robin far off isn't logged")
	bird.pos = player.global_position + Vector2(Critters.SPOT_DISTANCE - 20.0, 0)
	await get_tree().process_frame
	check(FieldLog.has("robin"), "walking up close logs it")
	check(world.hud.message_label.text.begins_with("Spotted: American Robin"), "...and says so (%s)" % world.hud.message_label.text)
	check(not FieldLog.spot("robin"), "a second robin isn't new")


func test_bears(world: Node) -> void:
	var bears: Bears = world.find_children("*", "Bears", true, false)[0]
	var player: Player = world.player
	check(not world.region.indoors, "the bear test starts outdoors (%s)" % world.region.region_id)
	_fair_weather()
	GameClock.minutes = 10 * 60
	GameClock.season = GameClock.Season.SUMMER
	var summer := bears.chance()
	check(summer > 0.0, "a bear may come by on a summer day")
	GameClock.season = GameClock.Season.FALL
	check(bears.chance() > summer, "...more often in fall, fattening up for winter")
	GameClock.season = GameClock.Season.WINTER
	check(bears.chance() < summer * 0.2, "...and hardly ever in winter")
	GameClock.season = GameClock.Season.SUMMER
	GameClock.minutes = 18 * 60
	check(bears.chance() > summer, "...and more at dusk than midday")
	GameClock.minutes = 23 * 60
	check(bears.chance() == 0.0 and not bears.active(), "none out in the dark of night")
	GameClock.minutes = 10 * 60
	var weights := 0.0
	for w: float in Bears.COAT_WEIGHTS:
		weights += w
	check(Bears.COATS.size() == Bears.COAT_WEIGHTS.size() and is_equal_approx(weights, 1.0), "every coat has a share")
	check(Bears.COAT_WEIGHTS[Bears.COATS.find("black")] < Bears.COAT_WEIGHTS[Bears.COATS.find("brown")] + Bears.COAT_WEIGHTS[Bears.COATS.find("cinnamon")],
		"most of Yosemite's black bears are brown or cinnamon")
	check(Bear.SHEET.get_height() == int(Bear.FRAME.y) * Bears.COATS.size(), "a row of sprites for each coat")

	# one walks by far off: it's in the field log once you get a look
	FieldLog.seen.erase("black_bear")
	var from := player.global_position + Vector2(-(Bears.SPOT_DISTANCE + 200.0), 0)
	var mom := bears.add_group(from, from + Vector2(600, 0), 1, 1)
	check(mom is Bear and bears.animals().size() == 2 and bears.animals()[1].young and bears.animals()[1].leader == mom, "a mother can bring a cub")
	check(mom.get_parent() == world.region.entities, "bears stand among the region's people and trees")
	bears._process(0.016)
	check(not FieldLog.has("black_bear"), "a bear well off isn't logged")
	mom.global_position = player.global_position + Vector2(Bears.NOTICE_DISTANCE + 60.0, 0)
	mom.target = mom.global_position + Vector2(400, 200)
	bears._process(0.016)
	check(FieldLog.has("black_bear"), "a bear in plain sight is logged")
	check(mom.state != "watch" and mom.state != "leave", "it goes on about its business while you keep your distance")
	# come close and it looks up, then goes off away from you
	mom.global_position = player.global_position + Vector2(Bears.NOTICE_DISTANCE - 30.0, 0)
	bears.animals()[1].global_position = mom.global_position + Vector2(24, 4)
	bears._process(0.016)
	check(mom.state == "watch" and mom.facing == -1, "close up, it stops and looks at you")
	check(world.hud.message_label.text == Bears.NOTICE_MESSAGE, "...and you're told to give it room")
	for i in 120:
		bears._process(0.016)
	check(mom.state == "leave" and mom.global_position.x > player.global_position.x + Bears.NOTICE_DISTANCE - 30.0, "then it ambles off away from you")
	var cub: Wanderer = bears.animals()[1]
	check(cub.global_position.distance_to(mom.global_position) < 60.0, "its cub keeps up")
	# out of sight, it's gone, and none comes along again right away
	mom.global_position = player.global_position + Vector2(4000, 0)
	bears._process(0.016)
	await get_tree().process_frame
	check(bears.animals().is_empty() and not is_instance_valid(cub), "a bear gone off out of sight is gone for good")
	check(bears._cooldown > 0.0, "...and the next one waits a while")
	# leaving the area takes the bears with it
	bears.add_group(player.global_position + Vector2(300, 0), player.global_position + Vector2(900, 0))
	bears._last_region = null
	bears._process(0.016)
	check(bears.animals().is_empty(), "a new area starts with no bears")
	bears._cooldown = 0.0
	FieldLog.seen.erase("black_bear")
	await get_tree().process_frame


func test_deer(world: Node) -> void:
	var deer: Deer = world.find_children("*", "Deer", true, false)[0]
	var bears: Bears = world.find_children("*", "Bears", true, false)[0]
	var player: Player = world.player
	_fair_weather()
	GameClock.minutes = 10 * 60
	for season in 4:
		GameClock.season = season
		check(deer.chance() > 0.0, "mule deer are about in season %d" % season)
	GameClock.season = GameClock.Season.WINTER
	check(deer.chance() > bears.chance() * 5.0, "...and in winter, when the bears are asleep")
	GameClock.season = GameClock.Season.SUMMER
	check(deer.chance() > bears.chance(), "deer come by more often than bears")
	GameClock.minutes = 22 * 60
	check(deer.chance() == 0.0, "none out at night")
	GameClock.minutes = 10 * 60
	check(Deer.look_for(false, GameClock.Season.SUMMER) == Deer.LOOKS.find("doe_summer") and Deer.look_for(true, GameClock.Season.WINTER) == Deer.LOOKS.find("buck_winter"),
		"reddish summer coats, gray winter ones, and bucks with antlers")
	check(MuleDeer.SHEET.get_height() == int(MuleDeer.FRAME.y) * Deer.LOOKS.size(), "a row of sprites for each look")

	FieldLog.seen.erase("mule_deer")
	var at := player.global_position + Vector2(Deer.NOTICE_DISTANCE + 50.0, 0)
	var doe := deer.add_group(at, at + Vector2(500, 0), 0, 2)
	check(doe is MuleDeer and deer.animals().size() == 3, "a doe with two fawns")
	deer._process(0.016)
	check(FieldLog.has("mule_deer"), "a deer in sight goes in the field log")
	doe.global_position = player.global_position + Vector2(Deer.NOTICE_DISTANCE - 20.0, 0)
	deer._process(0.016)
	check(doe.state == "watch", "close up, she stops and stares")
	for i in 90:
		deer._process(0.016)
	check(doe.state == "leave" and (doe as MuleDeer).bounding(), "then she bounds off")
	check((deer.animals()[1] as MuleDeer).speed > MuleDeer.BOUND_SPEED, "...and her fawns go with her")
	deer._last_region = null
	deer._process(0.016)
	deer._cooldown = 0.0
	await get_tree().process_frame


func test_field_log_listening(world: Node) -> void:
	GameClock.season = GameClock.Season.SUMMER
	GameClock.minutes = 10 * 60
	_fair_weather()
	check("mountain_chickadee" in FieldLog.audible() and not "great_horned_owl" in FieldLog.audible(), "by day you can hear a chickadee, not the owl")
	check(FieldLog.listen() == "mountain_chickadee" and FieldLog.has("mountain_chickadee"), "standing still logs the chickadee")
	GameClock.minutes = 22 * 60
	check(FieldLog.audible() == PackedStringArray(["great_horned_owl"]), "at night you hear the owl")
	GameClock.season = GameClock.Season.WINTER
	_fair_weather()
	check(FieldLog.audible().is_empty(), "...but not on a winter night, when the night ambience is quiet")
	GameClock.season = GameClock.Season.SUMMER
	_fair_weather()
	check(FieldLog.listen() == "great_horned_owl", "a summer night logs the owl")
	check(FieldLog.listen() == "", "nothing new to hear after that")
	FieldLog.spot("black_bear", false, "tracks")
	check(FieldLog.has("black_bear"), "bear tracks log a black bear")
	check(world.hud.message_label.text.begins_with("Found tracks of: American Black Bear"), "...and say they were tracks (%s)" % world.hud.message_label.text)


func test_fish_definitions() -> void:
	for fish: Dictionary in Fishing.FISH:
		var ok: bool = FieldLog.get_animal(fish.id).get("how", "") == "caught" and not fish.hubs.is_empty() and not fish.seasons.is_empty()
		if fish.keep != "":
			ok = ok and ItemDB.get_item(fish.keep) != null and FoodDB.is_food(fish.keep) and Cooking.INGREDIENTS.has(fish.keep)
		else:
			ok = ok and fish.release != ""
		check(ok, "%s is in the field log, and is kept for the pot or let go with a line" % fish.id)
	check(Fishing.get_fish("rainbow_trout").keep == "", "the Merced's rainbow trout are catch and release, as in the real Valley")
	check(not Fishing.fish_in("yosemite_valley", GameClock.Season.WINTER).is_empty(), "something bites in the Valley in winter")
	check(Fishing.fish_in("glacier_point", GameClock.Season.SUMMER).is_empty(), "nothing to fish for on Glacier Point")
	check(Cooking.dish_for(["brown_trout"]) == "camp_stew", "a trout in the pot makes a camp stew")
	var shop: ShopData = load("res://data/shops/curry_mountain_shop.tres")
	check(shop.offers.any(func(o: ShopOffer) -> bool: return o.id == "fly_rod" and o.requires.keys() == ["climbing_shoes"]), "the Mountain Shop trades a fly rod")


## Plays the reel with a hand that holds whenever the band is below the fish.
func _play(game: FishingMinigame, smart: bool) -> bool:
	var result: Array[bool] = []
	game.finished.connect(func(caught: bool) -> void: result.append(caught))
	for i in 3000:
		var hold := smart and game.band + FishingMinigame.BAND / 2.0 < game.fish_at
		if game.step(1.0 / 60.0, hold) == FishingMinigame.Phase.DONE:
			break
	return result == [true]


func test_minigame() -> void:
	var caught := 0
	var lost := 0
	for seed in 6:
		var game := FishingMinigame.new()
		add_child(game)
		game.set_process(false)
		game.start(Fishing.get_fish("rainbow_trout"), seed)
		if _play(game, true):
			caught += 1
		game.free()
		game = FishingMinigame.new()
		add_child(game)
		game.set_process(false)
		game.start(Fishing.get_fish("rainbow_trout"), seed)
		if not _play(game, false):
			lost += 1
		game.free()
	check(caught >= 5, "following the fish lands it (%d of 6)" % caught)
	check(lost == 6, "never reeling loses it (%d of 6)" % lost)
	var game := FishingMinigame.new()
	add_child(game)
	game.set_process(false)
	game.start(Fishing.get_fish("brown_trout"), 1)
	check(game.step(0.1, false) == FishingMinigame.Phase.WAIT, "you wait for a bite first")
	var gave_up := []
	game.finished.connect(func(c: bool) -> void: gave_up.append(c))
	game.give_up()
	check(gave_up == [false] and game.phase == FishingMinigame.Phase.DONE, "cancel gives up")
	game.free()
	await get_tree().process_frame


## A spot by the water in the current region: a walkable cell beside a water
## cell, with the way to face it. Empty if there's none.
func _bank(world: Node) -> Dictionary:
	var ground: TileMapLayer = Fishing._ground(world)
	for cell in ground.get_used_cells():
		var at := ground.to_global(ground.map_to_local(cell))
		if Fishing.is_water(ground, at):
			continue
		for facing in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if Fishing.is_water(ground, at + Vector2(facing) * Fishing.REACH[0]):
				return {"at": at, "facing": facing}
	return {}


func test_fishing_spot(world: Node) -> void:
	world._enter_region("yosemite_village", "arrival")
	await get_tree().process_frame
	GameClock.season = GameClock.Season.SUMMER
	var player: Player = world.player
	var bank := _bank(world)
	check(not bank.is_empty(), "the Merced runs through Yosemite Village")
	if bank.is_empty():
		return
	player.global_position = bank.at
	player.facing = bank.facing
	player.interaction_area.position = Vector2(bank.facing) * 24.0
	Gear.owned.erase(Fishing.ROD)
	check(not Fishing.can_fish(player), "no casting without a rod")
	Gear.add(Fishing.ROD)
	check(Fishing.can_fish(player), "with a rod, facing the river, you can cast")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var target := player.get_target()
	if target == player.fishing:
		check(Player.prompt_for(target) == "Fish", "the prompt says Fish")
	player.facing = -bank.facing
	check(not Fishing.can_fish(player) or Fishing.is_water(Fishing._ground(world), player.global_position - Vector2(bank.facing) * Fishing.REACH[0])
		or Fishing.is_water(Fishing._ground(world), player.global_position - Vector2(bank.facing) * Fishing.REACH[1]),
		"facing away from the water, there's nothing to cast into")


func test_landing_fish() -> void:
	var rod: Fishing = Fishing.new()
	add_child(rod)
	var before := Inventory.count("brown_trout")
	var text := rod.land(Fishing.get_fish("brown_trout"))
	check(Inventory.count("brown_trout") == before + 1 and FieldLog.has("brown_trout"), "a brown trout goes in your pack and your field log")
	check("new in your field log" in text, "...and the first one says it's new (%s)" % text)
	var count := Inventory.items.size()
	text = rod.land(Fishing.get_fish("rainbow_trout"))
	check(Inventory.items.size() == count and Inventory.count("rainbow_trout") == 0 and FieldLog.has("rainbow_trout"), "a rainbow trout is logged and let go")
	check("catch and release" in text, "...with a line on why (%s)" % text)
	rod.free()


func _on_day(festival: Dictionary, hour: int) -> void:
	GameClock.season = festival.season
	GameClock.day = festival.day
	GameClock.minutes = hour * 60


func test_festival_definitions() -> void:
	var seasons := {}
	var native := ["tenaya", "maggie_howard", "lucy_telles", "maria_lebrado", "carrie_bethel"]
	for festival: Dictionary in Festivals.FESTIVALS:
		var ok: bool = QuestLog.get_character(festival.host) != null and not festival.host in native and not festival.lines.is_empty()
		ok = ok and festival.day >= 1 and festival.day <= GameClock.DAYS_PER_SEASON and festival.hours[0] < festival.hours[1]
		for id: String in festival.reward:
			ok = ok and ItemDB.get_item(id) != null
		seasons[festival.season] = true
		check(ok, "%s has a real host, a day, hours, lines and a reward" % festival.name)
	check(seasons.size() == 4, "a festival every season")


func test_festival_day() -> void:
	Festivals.start_new_game()
	var walk := Festivals.get_festival("wildflower_walk")
	_on_day(walk, 7)
	check(Festivals.today() == walk and not Festivals.is_on(), "the Wildflower Walk is today, but not on before 9")
	check(Festivals.talk_to("enid_michael").is_empty(), "...so Enid has nothing for it yet")
	GameClock.minutes = 10 * 60
	check(Festivals.is_on(), "at 10 it's on")
	check(Festivals.talk_to("galen_clark").is_empty(), "only the host hosts")
	var before := int(Friendship.points.get("enid_michael", 0))
	var lines := Festivals.talk_to("enid_michael")
	check(lines.size() == walk.lines.size() + 1 and lines[-1].text.begins_with("The Wildflower Walk! Received"), "Enid leads the walk and gives you something")
	check(Inventory.count("spring_greens") >= 1 and int(Friendship.points.get("enid_michael", 0)) == before + int(walk.points), "...the reward and her friendship")
	check(Festivals.went_this_year("wildflower_walk") and Festivals.talk_to("enid_michael").is_empty(), "once a year")
	check(Festivals.talk_points(10) == 20, "talks count double on a festival day")
	GameClock.day = walk.day + 1
	check(Festivals.today().is_empty() and Festivals.talk_points(10) == 10, "...and not the day after")
	check(Festivals.days_until(walk) == 4 * GameClock.DAYS_PER_SEASON - 1, "next year's walk is nearly a year off")
	var lines_j := _journal_lines()
	check("Valley calendar" in lines_j and _has_line(lines_j, "The Fourth at Camp Curry · In "), "the Journal's calendar counts down to the next festivals")
	check(_has_line(lines_j, "Hosted by Jennie Curry"), "...and says who hosts")
	SaveManager.save_game()
	Festivals.start_new_game()
	SaveManager.load_game()
	check(Festivals.went_this_year("wildflower_walk"), "going to a festival survives a save")


func test_facelift(world: Node) -> void:
	var facelift := Festivals.get_festival("facelift")
	_on_day(facelift, 10)
	check(Festivals.litter_today("yosemite_valley") > 0 and Festivals.litter_today("wawona") == 0, "Facelift litter is in the Valley only")
	world._enter_region("yosemite_village", "arrival")
	var forage: ForageSpawner = world.forage
	await forage.respawn()
	var litter := forage.get_children().filter(func(c: Node) -> bool: return c is Forageable and c.item.id == Festivals.LITTER)
	check(litter.size() == Festivals.LITTER_PER_AREA, "litter turns up around Yosemite Village (%d)" % litter.size())
	Inventory.remove(Festivals.LITTER, Inventory.count(Festivals.LITTER))
	var forage_before := Perks.stat("forage")
	if not litter.is_empty():
		litter[0].interact(world.player)
		check(Inventory.count(Festivals.LITTER) == 1 and Perks.stat("forage") == forage_before, "picking up litter isn't a forage find")
	var lines := Festivals.talk_to("wren_alvarez")
	check(lines[-1].text.begins_with("Litter collected: "), "Wren asks for litter first (%s)" % lines[-1].text)
	check(not Festivals.went_this_year("facelift"), "...and that isn't the reward yet")
	Inventory.add(Festivals.LITTER, Festivals.LITTER_WANTED)
	lines = Festivals.talk_to("wren_alvarez")
	check(lines[-1].text.begins_with("The Yosemite Facelift! Received") and Inventory.count(Festivals.LITTER) == 0, "five pieces of litter earn Wren's reward")


func test_journal_and_day_log(world: Node) -> void:
	var lines := _journal_lines()
	check("Field log: %d of %d animals" % [FieldLog.count(), FieldLog.total()] in lines, "the Journal has the field log, with its count")
	check(_has_line(lines, "American Robin (Turdus migratorius)"), "a logged animal shows its Latin name")
	check(_has_line(lines, "Steller's Jay · All year. Open ground"), "one not yet logged shows when and where to look")
	var quests := _journal_lines(Journal.Tab.QUESTS)
	if not BoardRequests.taken.is_empty():
		check(_has_line(quests, "Notes from the Camp 4 board"), "the Quests tab lists the board's notes")
		check(_has_line(quests, "Bring "), "...with what to bring")
	check(world.day_log.animals.has("American Robin") and world.day_log.animals.has("Great Horned Owl"), "the day's page lists today's new animals (%s)" % [world.day_log.animals])


func test_save_and_load() -> void:
	var seen := FieldLog.seen.duplicate(true)
	var taken := BoardRequests.taken.duplicate()
	var done := BoardRequests.done
	SaveManager.save_game()
	FieldLog.start_new_game()
	BoardRequests.start_new_game()
	check(SaveManager.load_game(), "the save loads")
	check(FieldLog.seen == seen, "the field log survives a save")
	check(BoardRequests.taken == taken and BoardRequests.done == done, "the board notes you carry survive a save")
