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
	test_font_setting()
	test_pause_card()
	await test_critters(world)
	await test_rustle(world)
	await test_location_fits(world)
	await test_screens_fit(world)
	# and again with the pixel font
	Settings.pixel_font = true
	Settings.apply_font()
	await get_tree().process_frame
	await test_screens_fit(world)
	Settings.pixel_font = false
	Settings.apply_font()
	await test_routines(world)
	await test_vendors_drawn(world)
	await test_detail_cards(world)
	test_friendship(world)
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
	var pause := get_tree().get_first_node_in_group("pause_menu")
	pause.open()
	world.hud._update_cover()
	check(not toasts.visible, "cards hide under the pause menu")
	pause.close()
	world.hud._update_cover()
	check(toasts.visible, "and come back after")


func test_portraits() -> void:
	var missing := []
	for character: CharacterData in QuestLog.CHARACTERS + QuestLog.STAFF:
		if Portraits.for_speaker(character.display_name) == null:
			missing.append(character.id)
	check(missing.is_empty(), "everyone in the cast has a portrait %s" % [missing])
	check(Portraits.for_speaker("Wren Alvarez") != null, "Wren has a portrait")
	check(Portraits.for_speaker("") == null, "narration has no portrait")
	check(Portraits.for_speaker("Camp Curry Store clerk") != null, "the store clerk has a portrait")
	var happy := Portraits.for_speaker("Wren Alvarez", "happy") as AtlasTexture
	var plain := Portraits.for_speaker("Wren Alvarez") as AtlasTexture
	check(happy != null and plain != null and happy.region != plain.region, "a happy face is a different picture")
	for mood: String in Portraits.MOODS:
		check(Portraits.for_speaker("Galen Clark", mood) != null, "Galen Clark has a %s face" % mood)
	var faceless := []
	for path in ["camp4_rack", "camp4_bigwall", "village_store", "curry_store", "curry_mountain_shop"]:
		var shop: ShopData = load("res://data/shops/%s.tres" % path)
		if Portraits.for_speaker(shop.keeper) == null:
			faceless.append(shop.keeper)
	check(faceless.is_empty(), "every shopkeeper has a portrait %s" % [faceless])
	check(Portraits.mood_for("Thank you, that's wonderful.") == "happy", "thanks read as happy")
	check(Portraits.mood_for("I'm sorry. We lost the whole grove.") == "sad", "a loss reads as sad")
	check(Portraits.mood_for("Oh! You found it?") == "surprised", "\"Oh!\" reads as surprised")
	check(Portraits.mood_for("The trail goes up past the falls.") == "neutral", "a plain line stays neutral")
	check(Portraits.mood_for("Never take the last one.") == "neutral", "advice isn't sad")
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
	GameClock.minutes = 15 * 60
	for season in 4:
		GameClock.season = season
		var afternoon := Sound.music_choice()
		check(afternoon in ["", Sound.SEASON_MUSIC_AFTERNOON[season]], "%s afternoons play a second piece (%s)" % [GameClock.SEASON_NAMES[season], afternoon])
	GameClock.season = GameClock.Season.SUMMER
	GameClock.minutes = 22 * 60
	check(Sound.music_choice() in ["", Sound.NIGHT_MUSIC], "the night piece after 8 PM")
	Sound.set_ambience("title")
	check(Sound.music_choice() == Sound.TITLE_MUSIC, "the title theme on the title screen")
	for piece: String in Sound.SEASON_MUSIC + Sound.SEASON_MUSIC_AFTERNOON + [Sound.NIGHT_MUSIC, Sound.TITLE_MUSIC]:
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
	var late := critters.add_bird("junco", world.player.global_position + Vector2(-80, 0))
	critters._process(0.016)
	check(late.state == "fly", "a bird still about after dark flies off")
	GameClock.minutes = 10 * 60
	if critters._outdoors_by_day():
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


func test_location_fits(world: Node) -> void:
	world.hud.set_location("Yosemite Valley · Curry Village · Glacier Point Apron trail")
	await get_tree().process_frame
	await get_tree().process_frame
	var banner: Rect2 = world.hud.location_panel.get_global_rect()
	var clock: Rect2 = world.hud.clock_panel.get_global_rect()
	check(not banner.intersects(clock), "a long place name keeps clear of the clock (%s)" % world.hud.location_label.text)
	check(world.hud.location_label.text.ends_with("Glacier Point Apron trail"), "and keeps the place you're in")


## Nothing runs off its panel or the screen: the travel map's description
## for every hub, the area map's hint line, and the Controls page.
func test_screens_fit(world: Node) -> void:
	var screen := get_viewport().get_visible_rect()
	world.open_travel_map()
	await get_tree().process_frame
	var map: ParkMap = world.park_map
	var too_tall := []
	for hub: String in ParkMap.HUB_ORDER:
		map._select(hub)
		await get_tree().process_frame
		if map._info_panel.get_combined_minimum_size().y > ParkMap.INFO_RECT.size.y:
			too_tall.append("%s %.0f" % [hub, map._info_panel.get_combined_minimum_size().y])
	check(too_tall.is_empty(), "every hub's travel note fits its panel %s" % [too_tall])
	map.close()
	world.open_map()
	await get_tree().process_frame
	check(map._area_hint.get_combined_minimum_size().x <= map._area_hint.size.x + 0.5, "the area map's hint fits its slot (%.0f of %.0f)" % [map._area_hint.get_combined_minimum_size().x, map._area_hint.size.x])
	map.close()
	await get_tree().process_frame
	var pause := get_tree().get_first_node_in_group("pause_menu")
	pause.open()
	pause._show_page(PauseMenu.Page.CONTROLS)
	await get_tree().process_frame
	await get_tree().process_frame
	var panel: Rect2 = pause._panel.get_global_rect()
	check(screen.encloses(panel), "the Controls page fits the screen (%s)" % panel)
	pause._show_page(PauseMenu.Page.SETTINGS)
	await get_tree().process_frame
	await get_tree().process_frame
	check(screen.encloses(pause._panel.get_global_rect()), "and so does Settings (%s)" % pause._panel.get_global_rect())
	pause.close()


## No shopkeeper is left as a plain placeholder figure.
func test_vendors_drawn(world: Node) -> void:
	var plain := []
	for region in ["yosemite_village", "curry_store", "curry_mountain_shop"]:
		await world.go_to_region(region, "arrival")
		for vendor in world.region.find_children("*", "Vendor", true, false):
			if vendor.sprite_sheet == null:
				plain.append("%s/%s" % [region, vendor.name])
	check(plain.is_empty(), "every shopkeeper is drawn from a sprite sheet %s" % [plain])
	await world.go_to_region("curry_village", "arrival")


func test_routines(world: Node) -> void:
	var visitor: NPC = null
	var local: NPC = null
	for node in world.region.find_children("*", "NPC", true, false):
		if node.character and node.character.visitor and visitor == null:
			visitor = node
		elif node.character and not node.character.visitor and local == null:
			local = node
	check(visitor != null and local != null, "Curry Village has visitors and locals")
	if visitor == null or local == null:
		return
	var saved := GameClock.minutes
	GameClock.minutes = 23 * 60
	visitor._routine_check = 0.0
	visitor._process(0.016)
	await get_tree().create_timer(1.0).timeout
	check(not visitor.is_out() and not visitor.visible, "visitors go home at night")
	check(not visitor.get_node("Hitbox").monitorable, "and can't be talked to while they're gone")
	check(local.is_out(), "people with stories to tell stay where you can find them")
	check(local.roam_radius() == 0.0, "and stand at their spot overnight")
	GameClock.minutes = 13 * 60
	check(local.roam_radius() >= NPC.STROLL, "they stroll about it through the middle of the day")
	GameClock.minutes = 19 * 60
	check(local.roam_radius() > 0.0 and local.roam_radius() < NPC.STROLL, "and keep nearer in the evening")
	GameClock.minutes = 23 * 60
	GameClock.minutes = 10 * 60
	visitor._routine_check = 0.0
	visitor._process(0.016)
	await get_tree().create_timer(1.0).timeout
	var rainy: bool = Weather.today().rain > 0.4
	check(visitor.visible or rainy, "and come back out in the morning")
	GameClock.minutes = saved


func test_rustle(world: Node) -> void:
	await world.go_to_region("curry_village", "arrival")
	var rustle: Rustle = null
	for child in world.get_children():
		if child is Rustle:
			rustle = child
	check(rustle != null, "plants can rustle")
	if rustle == null:
		return
	rustle._process(0.016)
	check(rustle.plant_count() > 20, "Curry Village's ferns and shrubs are found (%d)" % rustle.plant_count())
	var plant: Sprite2D = rustle._plants[0]
	# walk the player's feet into the plant
	world.player.global_position = plant.global_position + Vector2(-20, 0)
	rustle._process(0.016)
	world.player.global_position = plant.global_position + Vector2(2, 1)
	rustle._process(0.016)
	check(rustle.is_swaying(plant), "walking through a fern sets it swaying")
	rustle._process(0.1)
	check(absf(plant.skew) > 0.01, "it leans (skew %.2f)" % plant.skew)
	world.player.global_position = plant.global_position + Vector2(60, 0)
	for i in 10:
		rustle._process(0.1)
	check(not rustle.is_swaying(plant) and plant.skew == 0.0, "and settles back upright")


func test_friendship(world: Node) -> void:
	Friendship.start_new_game()
	check(Friendship.hearts("john_muir") == 0, "nobody knows you at the start")
	Friendship.note_talk("john_muir")
	Friendship.note_talk("john_muir")
	check(Friendship.points.john_muir == Friendship.TALK_POINTS, "talking counts once a day")
	check(Friendship.taste("john_muir", "dry_crusts") == "loved", "Muir loves dry crusts")
	check(Friendship.taste("john_muir", "trail_mix") == "liked", "and likes any good food")
	check(Friendship.taste("john_muir", "black_oak_acorn") == "plain", "raw acorns are just polite thanks")
	check(not Friendship.is_giftable("sequoia_cone") and not Friendship.is_giftable("model_a_axle"), "story things can't be given away")
	check(Friendship.is_giftable("wild_strawberry"), "forage can")
	Inventory.add("dry_crusts", 2)
	var hearts_before := Friendship.hearts("john_muir")
	var thanks := Friendship.give("john_muir", "dry_crusts")
	check(thanks != "" and Portraits.mood_for(thanks) != "neutral", "a loved gift gets warm thanks: %s" % thanks)
	check(Friendship.hearts("john_muir") == hearts_before + 0 or Friendship.points.john_muir == Friendship.TALK_POINTS + Friendship.LOVED_POINTS, "and loved points (%d)" % Friendship.points.john_muir)
	check(Inventory.count("dry_crusts") == 1, "the gift leaves your pack")
	check(not Friendship.can_gift("john_muir") and Friendship.give("john_muir", "dry_crusts") == "", "one gift a week")
	GameClock.day += Friendship.GIFT_EVERY
	check(Friendship.can_gift("john_muir"), "and another the week after")
	GameClock.day -= Friendship.GIFT_EVERY
	var gained := []
	Friendship.heart_gained.connect(func(id: String, n: int) -> void: gained.append([id, n]))
	Friendship.add("john_muir", 200)
	check(Friendship.hearts("john_muir") == 2 and gained.size() == 2, "hearts come one at a time (%s)" % [gained])
	Friendship.add("john_muir", 10000)
	check(Friendship.hearts("john_muir") == Friendship.MAX_HEARTS, "up to %d hearts" % Friendship.MAX_HEARTS)
	var quest := QuestLog.get_quest("clark_register")
	var clark_before := int(Friendship.points.get("galen_clark", 0))
	QuestLog.quest_completed.emit(quest)
	check(int(Friendship.points.get("galen_clark", 0)) == clark_before + Friendship.QUEST_POINTS, "finishing someone's quest warms them to you")
	var saved := Friendship.save_data()
	Friendship.start_new_game()
	Friendship.load_data(saved)
	check(Friendship.hearts("john_muir") == Friendship.MAX_HEARTS and not Friendship.can_gift("john_muir"), "hearts and gifts are saved")
	var bad := []
	for id: String in Friendship.LOVES:
		if QuestLog.get_character(id) == null:
			bad.append(id)
		for item: String in Friendship.LOVES[id]:
			if not Friendship.is_giftable(item):
				bad.append("%s:%s" % [id, item])
	check(bad.is_empty(), "every love is a real person and a real gift %s" % [bad])
	var missing := []
	for character: CharacterData in QuestLog.CHARACTERS + QuestLog.STAFF:
		if not Friendship.LOVES.has(character.id):
			missing.append(character.id)
	check(missing.is_empty(), "everyone has something they love %s" % [missing])
	var journal := get_tree().get_first_node_in_group("journal")
	journal.open()
	var found := false
	for child in journal._body.get_children():
		if child is HBoxContainer and child.get_children().any(func(n: Node) -> bool: return n is Label and n.text == "John Muir"):
			found = child.get_child_count() >= 1 + Friendship.MAX_HEARTS
	journal.close()
	check(found, "the Journal shows Muir's hearts")
	Inventory.remove("dry_crusts", Inventory.count("dry_crusts"))
	Friendship.start_new_game()


## Settings > Font swaps every screen to the pixel font and back, and is saved.
## The campfire and the shops show a card about the choice under the cursor:
## what goes in (short in red), energy, time; and it fits beside the list.
func test_detail_cards(world: Node) -> void:
	Recipes.learn("acorn_cake")
	if Inventory.count("leached_acorn_meal") > 0:
		Inventory.remove("leached_acorn_meal", Inventory.count("leached_acorn_meal"))
	var menu := Station.menu_for(Recipes.known_for("campfire"))
	check(menu.options.size() == menu.details.size() and menu.options[-1] == "Leave" and menu.details[-1] == null,
		"one card per dish, none for Leave")
	var cake: Dictionary = menu.details[menu.options.find("Acorn Cake")]
	check(cake.rows.any(func(row: Array) -> bool: return row[1].begins_with("Leached Acorn Meal") and row[2]),
		"a missing ingredient shows in red with what you have")
	check(cake.facts.contains("45 energy") and cake.facts.contains("Makes 2"), "and the dish's energy and yield: " + cake.facts)
	var box := DialogueBox.open(world.player)
	box.choose("Campfire. What will you make?", menu.options, "", [], menu.details)
	box.reveal_all()
	for i in 3:
		await get_tree().process_frame
	check(box._detail_panel.visible and box._detail_column.get_child_count() >= 3, "the card shows beside the list")
	var screen := Rect2(Vector2.ZERO, Vector2(480, 270))
	check(screen.encloses(box._panel.get_global_rect()), "and the box still fits the screen")
	box._cursor = menu.options.size() - 1
	box._refresh_options()
	check(box._detail_column.get_child_count() == 0, "Leave has an empty card")
	box.close()
	await get_tree().process_frame


## The pause menu's card shows your face and a tally of the game.
func test_pause_card() -> void:
	check(Portraits.for_speaker("You") != null, "the player has a portrait for the pause menu's card")
	var lines := PauseMenu.card_text()
	check(lines.size() == 5 and lines[0].begins_with("Food: ") and lines[2].begins_with("Friends: "), "and the card tallies food, gear, friends, quests and climbs")


func test_font_setting() -> void:
	var saved_path := Settings.path
	Settings.path = "user://polish_test_settings.cfg"
	Settings.load_settings()
	check(Settings.pixel_font, "letters are pixel letters by default, like the art")
	var theme := ThemeDB.get_project_theme()
	Settings.pixel_font = true
	Settings.apply_font()
	check(theme.default_font == Settings.ui_font(), "the pixel font goes on every themed screen")
	check(load("res://scripts/climb/art/climb_ui.gd").font() == Settings.ui_font(), "and on the climbing screen")
	# proportional, so "Village" doesn't read "Vi l lage"
	var pixel := Settings.ui_font()
	var narrow := pixel.get_string_size("i", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var wide := pixel.get_string_size("m", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	check(narrow * 2.0 < wide, "the pixel font sets an i narrower than an m (%.0f, %.0f)" % [narrow, wide])
	var one := pixel.get_string_size("1", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var eight := pixel.get_string_size("8", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	check(is_equal_approx(one, eight), "and its digits all one width, so the clock lines up (%.1f, %.1f)" % [one, eight])
	Settings.save()
	Settings.pixel_font = false
	Settings.load_settings()
	check(Settings.pixel_font, "the choice is saved")
	Settings.pixel_font = false
	Settings.apply_font()
	check(theme.default_font == Settings.ui_font() and not Settings.pixel_font, "and smooth letters come back")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	Settings.path = saved_path
	Settings.load_settings()
	check(FileAccess.file_exists(Credits.PIXEL_FONT_LICENSE), "the pixel font's license is in the project")
	check(Credits.licenses_bbcode().contains("DotGothic16"), "and on the Licenses page")


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
