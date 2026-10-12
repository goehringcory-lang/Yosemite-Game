extends Node
## Headless test of the game-feel touches: every item has an icon, the item
## cards stack and count, everyone who speaks has a portrait and a voice, the
## quest bubbles, the clock dial's sky, the music that fits the hour, season
## and weather, and the day's page at bedtime.
## Run: godot --headless --path . res://tests/polish_test.tscn
## Exit code is the number of failed checks.

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	SaveManager.save_path = "user://polish_test_save.json"
	SaveManager.delete_save()
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().process_frame
	await get_tree().process_frame

	test_item_icons()
	test_toasts(world)
	test_portraits()
	test_markers()
	test_dial()
	test_music()
	await test_day_log(world)
	SaveManager.delete_save()
	print("OK: %d failure(s)" % failures if failures == 0 else "FAILED: %d failure(s)" % failures)
	get_tree().quit(failures)


func test_item_icons() -> void:
	var missing := []
	for item: ItemData in ItemDB.ITEMS:
		if item.icon == null:
			missing.append(item.id)
	check(missing.is_empty(), "every item has an icon %s" % [missing])


func test_toasts(world: Node) -> void:
	var toasts: ItemToasts = world.hud.toasts
	var before := toasts.count()
	Inventory.add("wild_strawberry")
	Inventory.add("wild_strawberry")
	check(toasts.count() == before + 1, "two strawberries share one card")
	check(toasts.text_for("wild_strawberry").ends_with("x2"), "the card counts them: %s" % toasts.text_for("wild_strawberry"))
	Gear.add("cam")
	check(toasts.text_for("gear:cam") == "Cam", "new gear gets a card of its own")
	for id in ["miners_lettuce", "sierra_onion", "yampah", "black_oak_acorn", "acorn_cake", "trail_mix"]:
		Inventory.add(id)
	check(toasts.count() <= ItemToasts.MAX_CARDS, "no more than %d cards at once" % ItemToasts.MAX_CARDS)


func test_portraits() -> void:
	var missing := []
	for character: CharacterData in QuestLog.CHARACTERS + QuestLog.STAFF:
		if Portraits.for_speaker(character.display_name) == null:
			missing.append(character.id)
	check(missing.is_empty(), "everyone in the cast has a portrait %s" % [missing])
	check(Portraits.for_speaker("Wren Alvarez") != null, "Wren has a portrait")
	check(Portraits.for_speaker("") == null, "narration has no portrait")
	check(Portraits.for_speaker("Camp Curry Store clerk") != null, "the store clerk has a portrait")
	check(is_equal_approx(Portraits.voice_pitch("Galen Clark"), Portraits.voice_pitch("Galen Clark")), "a voice is the same every time")
	check(Portraits.voice_pitch("Galen Clark") != Portraits.voice_pitch("Wren Alvarez"), "people sound different")
	var lo := 10.0
	var hi := 0.0
	for character: CharacterData in QuestLog.CHARACTERS:
		lo = minf(lo, Portraits.voice_pitch(character.display_name))
		hi = maxf(hi, Portraits.voice_pitch(character.display_name))
	check(lo >= 0.75 and hi <= 1.35, "voices stay in a pleasant range (%.2f to %.2f)" % [lo, hi])


func test_markers() -> void:
	QuestLog.start_new_game()
	var clark := QuestLog.available_from("galen_clark")
	check(clark != null, "Galen Clark has the first quest")
	check(QuestLog.marker_for("galen_clark") == "!", "so he wears a !")
	check(QuestLog.marker_for("mountain_shop") == "", "Marty has nothing until the Register's done")
	QuestLog.talk_to("galen_clark")
	check(QuestLog.marker_for("galen_clark") != "!", "taking the quest clears the !")
	# A "return" step finishes as soon as you talk to the giver: a ?
	var found_question := false
	for quest: QuestData in QuestLog.QUESTS:
		for i in quest.steps.size():
			if quest.steps[i].get("type") == "return":
				QuestLog.active = {quest.id: i}
				found_question = QuestLog.marker_for(quest.giver) == "?"
				break
		if found_question:
			break
	check(found_question, "a quest ready to hand in shows a ?")
	QuestLog.start_new_game()


func test_dial() -> void:
	check(ClockDial.body_position(6.0).x <= 5.0, "the sun rises on the left")
	check(ClockDial.body_position(13.0).y < ClockDial.body_position(7.0).y, "the sun is high at midday")
	check(ClockDial.body_position(19.9).x > ClockDial.W - 5.0, "and sets on the right")
	check(ClockDial.body_position(25.0).y < 10.0, "the moon is up at 1 AM")
	check(ClockDial.sky_color(13.0) == ClockDial.DAY, "a blue sky by day")
	check(ClockDial.sky_color(23.0) == ClockDial.NIGHT, "a night sky at 11 PM")
	check(ClockDial.SKYLINE.size() == ClockDial.W, "the skyline fills the dial")


func test_music() -> void:
	var mode := Sound.ambience()
	Sound.set_ambience("world")
	var saved_minutes := GameClock.minutes
	var saved_season := GameClock.season
	GameClock.minutes = 10 * 60
	for season in 4:
		GameClock.season = season
		var choice := Sound.music_choice()
		var rainy: bool = Weather.today().rain > 0.4
		check(choice == ("" if rainy else Sound.SEASON_MUSIC[season]), "%s mornings play %s" % [GameClock.SEASON_NAMES[season], choice if choice != "" else "nothing (rain)"])
	GameClock.season = GameClock.Season.SUMMER
	GameClock.minutes = 22 * 60
	check(Sound.music_choice() in ["", Sound.NIGHT_MUSIC], "the night piece after 8 PM")
	Sound.set_ambience("title")
	check(Sound.music_choice() == Sound.TITLE_MUSIC, "the title theme on the title screen")
	for piece: String in Sound.SEASON_MUSIC + [Sound.NIGHT_MUSIC, Sound.TITLE_MUSIC]:
		check(ResourceLoader.exists(Sound.DIR + piece + ".wav"), "%s is built" % piece)
	Settings.ensure_loaded()
	check(Settings.music_volume >= 0 and Settings.music_volume <= Settings.MAX_VOLUME, "music has a volume setting")
	check(AudioServer.get_bus_index(Sound.BUS_MUSIC) >= 0, "music has its own bus")
	GameClock.minutes = saved_minutes
	GameClock.season = saved_season
	Sound.set_ambience(mode)


func test_day_log(world: Node) -> void:
	var log: DayLog = world.day_log
	log.clear()
	check(log.is_empty(), "a new day starts with an empty page")
	Inventory.add("miners_lettuce", 3)
	Gear.add("quickdraw", 2)
	QuestLog.record_climb("glacier_point_apron")
	check(log.items.get("miners_lettuce", 0) == 3, "the page counts what you found")
	check(log.gear.get("quickdraw", 0) == 2, "and new gear")
	check(not log.ticks.is_empty(), "and first ascents: %s" % [log.ticks])
	var saved := log.save_data()
	log.clear()
	log.load_data(saved)
	check(log.items.get("miners_lettuce", 0) == 3 and log.ticks.size() == 1, "the page is saved with the game")
	var page := DaySummary.open(world, log)
	await get_tree().process_frame
	check(page.is_inside_tree(), "the page opens")
	var closed := [false]
	page.closed.connect(func() -> void: closed[0] = true)
	page.press() # show all
	page.press() # sleep
	check(closed[0], "pressing twice goes to sleep")
	GameClock.start_new_day()
	check(log.is_empty(), "the page starts over in the morning")
