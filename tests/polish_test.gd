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
	test_tuning()
	await test_critters(world)
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


## Renders single plucked notes from the music builder and measures their
## pitch and loudness, so the strings stay in tune with the pad and the tune,
## and no note of an arpeggio drops out.
func test_tuning() -> void:
	var builder: Object = load("res://tools/audio/build_music.gd").new()
	builder._rng.seed = 1
	var rate: int = builder.RATE
	var worst := 0.0
	var worst_note := 0
	var quietest := INF
	var loudest := 0.0
	var jump := 1.0
	var last := 0.0
	for note in range(43, 97, 3):
		var hz: float = builder.midi_hz(note)
		var buf := PackedFloat32Array()
		buf.resize(int(0.5 * rate))
		builder._pluck(buf, 0.0, hz, 0.3, 0.998, 3200.0, false)
		var cents := _pitch_cents(buf, rate, hz)
		if absf(cents) > absf(worst):
			worst = cents
			worst_note = note
		var energy := 0.0
		for i in range(int(0.02 * rate), int(0.2 * rate)):
			energy += buf[i] * buf[i]
		var rms := sqrt(energy / (0.18 * rate))
		# the notes the pieces pluck, MIDI 50 to 90 (see PIECES)
		if note >= 49 and note <= 91:
			quietest = minf(quietest, rms)
			loudest = maxf(loudest, rms)
			if last > 0.0:
				jump = maxf(jump, maxf(rms / last, last / rms))
			last = rms
	check(absf(worst) < 6.0, "plucked strings are in tune: worst %+.1f cents (MIDI %d)" % [worst, worst_note])
	check(loudest / quietest < 4.5, "plucked notes taper gently with pitch: loudest %.1f times the quietest" % (loudest / quietest))
	check(jump < 1.6, "no plucked note drops out next to its neighbors: biggest step %.2fx" % jump)


## How far [param buf]'s pitch is from [param hz], in cents: the strongest of
## a fine scan of frequencies around it (a windowed Goertzel at each).
func _pitch_cents(buf: PackedFloat32Array, rate: int, hz: float) -> float:
	var from := int(0.05 * rate)
	var span := 2048
	var best := 0.0
	var best_power := -1.0
	for step in range(-40, 41):
		var cents := step * 1.5
		var f := hz * pow(2.0, cents / 1200.0)
		var w := TAU * f / rate
		var coeff := 2.0 * cos(w)
		var s1 := 0.0
		var s2 := 0.0
		for i in span:
			var window := 0.5 - 0.5 * cos(TAU * i / span)
			var s0 := buf[from + i] * window + coeff * s1 - s2
			s2 = s1
			s1 = s0
		var power := s1 * s1 + s2 * s2 - coeff * s1 * s2
		if power > best_power:
			best_power = power
			best = cents
	return best


func test_critters(world: Node) -> void:
	var critters: Critters = null
	for child in world.get_children():
		if child is Critters:
			critters = child
	check(critters != null, "the world has birds and butterflies")
	if critters == null:
		return
	var saved_minutes := GameClock.minutes
	var saved_season := GameClock.season
	GameClock.minutes = 10 * 60
	GameClock.season = GameClock.Season.SUMMER
	var rainy: bool = Weather.today().rain > 0.0
	check(critters._outdoors_by_day() == (not world.region.indoors and not rainy), "out by day in fair weather outdoors")
	GameClock.minutes = 22 * 60
	check(not critters._outdoors_by_day(), "not after dark")
	GameClock.minutes = 10 * 60
	var bird := critters.add_bird("robin", world.player.global_position + Vector2(80, 0))
	critters._process(0.016)
	check(bird.state != "fly", "a bird keeps pecking while you're far off")
	bird.pos = world.player.global_position + Vector2(Critters.FLEE_DISTANCE - 6.0, 0)
	critters._process(0.016)
	check(bird.state == "fly" and bird.vel.x > 0.0, "and flies off away from you when you come close")
	var winter_kinds := []
	for kind: String in Critters.BIRDS:
		if GameClock.Season.WINTER in Critters.BIRDS[kind].seasons:
			winter_kinds.append(kind)
	check(not "robin" in winter_kinds and "junco" in winter_kinds, "juncos stay the winter, robins don't")
	GameClock.minutes = saved_minutes
	GameClock.season = saved_season
	await get_tree().process_frame


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
