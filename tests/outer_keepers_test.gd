extends Node
## Headless test of the Outer Keepers storylines (Thomas Hill in Wawona,
## François Matthes at Glacier Point, Arthur Bellamy in El Portal):
## cast definitions, overlays, seasonal quest arcs, Register pages and margin
## notes, heart scenes, SmallTalk, and all four major mechanical payoffs
## (Painter's Warmth film tone, Thomas Hill's oil study +25% gift bonus,
## Granite Reader climbing perk, and El Portal Express Supply tiers).
## Run: godot --headless --path . res://tests/outer_keepers_test.tscn
## Exit code is the number of failed checks.

const APRON := preload("res://data/routes/glacier_point_apron.tres")
const FREIGHT_SHOP := preload("res://data/shops/el_portal_freight.tres")

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	await get_tree().process_frame
	test_cast_and_scenes()
	test_thomas_hill_arc()
	test_francois_matthes_arc()
	test_arthur_bellamy_arc()
	test_finale_and_social()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func fresh(season: int = GameClock.Season.SPRING, hour: int = 10) -> void:
	NewGame.reset()
	GameClock.season = season
	GameClock.day = 3
	GameClock.minutes = hour * 60
	QuestLog.completed.append("clark_register")
	QuestLog.changed.emit()


func test_cast_and_scenes() -> void:
	var hill := QuestLog.get_character("thomas_hill")
	var matthes := QuestLog.get_character("francois_matthes")
	var bellamy := QuestLog.get_character("arthur_bellamy")
	check(hill != null and hill in QuestLog.CHARACTERS and not hill.staff and not hill.sources.is_empty(),
		"Thomas Hill is a documented historical character in CHARACTERS")
	check(matthes != null and matthes in QuestLog.CHARACTERS and not matthes.staff and not matthes.sources.is_empty(),
		"François Matthes is a documented historical character in CHARACTERS")
	check(bellamy != null and bellamy in QuestLog.STAFF and bellamy.staff and not (bellamy in QuestLog.CHARACTERS),
		"Arthur Bellamy is an invented staff character in STAFF")

	for who in [hill, matthes, bellamy]:
		var tex: Texture2D = who.sprite_sheet
		check(tex != null and tex.get_width() >= 96 and tex.get_height() >= 192,
			"%s has a 32px-upgraded sprite sheet (%dx%d)" % [who.id, tex.get_width() if tex else 0, tex.get_height() if tex else 0])
		var portrait_path := "res://assets/sprites/portraits/%s.png" % who.id
		check(ResourceLoader.exists(portrait_path) and load(portrait_path) != null, "%s has a portrait" % who.id)

	for pair in [
		["res://scenes/story/content/hill_studio.tscn", "ThomasHill"],
		["res://scenes/story/content/geology_hut.tscn", "FrancoisMatthes"],
		["res://scenes/story/content/el_portal_post_office.tscn", "ArthurBellamy"],
	]:
		var packed: PackedScene = load(pair[0])
		check(packed != null, "overlay scene loads: %s" % pair[0])
		if packed:
			var inst := packed.instantiate()
			var node := inst.get_node_or_null(pair[1])
			check(node != null, "%s places %s" % [pair[0], pair[1]])
			inst.free()


func test_thomas_hill_arc() -> void:
	# Painter's Light: Spring/Summer only
	fresh(GameClock.Season.FALL, 11)
	check(not ("warmth" in Photos.available_films()), "Painter's warmth film is locked at game start")
	QuestLog.talk_to("thomas_hill")
	check(not QuestLog.active.has("hill_painters_light"), "hill_painters_light does not start in Fall")

	GameClock.season = GameClock.Season.SPRING
	QuestLog.talk_to("thomas_hill")
	check(QuestLog.active.has("hill_painters_light"), "hill_painters_light starts in Spring")
	Inventory.add("wild_strawberry", 3)
	QuestLog.talk_to("thomas_hill")
	check(QuestLog.active.get("hill_painters_light") == 1 and Inventory.count("wild_strawberry") == 0,
		"wild strawberries advance hill_painters_light")
	QuestLog.talk_to("ansel_adams")
	check(QuestLog.active.get("hill_painters_light") == 2, "talking to Ansel Adams advances hill_painters_light")
	QuestLog.talk_to("thomas_hill")
	check(QuestLog.is_completed("hill_painters_light"), "returning to Thomas Hill completes hill_painters_light")
	check(QuestLog.is_unlocked("warmth_film") and "warmth" in Photos.available_films(),
		"hill_painters_light unlocks Painter's warmth film")

	# Verify warmth toning warms midtone pixels while preserving color
	var img := Image.create_empty(4, 4, false, Image.FORMAT_RGB8)
	img.fill(Color8(120, 110, 140))
	Photos.tone(img, "warmth")
	var px := img.get_pixel(0, 0)
	check(px.r8 > 120 and px.b8 < 140 and px.r8 != px.g8,
		"Photos.tone('warmth') warms pixels in color (%d, %d, %d)" % [px.r8, px.g8, px.b8])

	# Verify Register page, Ansel margin note, and HISTORY note
	QuestLog.completed.append("ansel_brownie")
	var hill_pages := RegisterPages.written().filter(func(p: Dictionary) -> bool: return p.by == "Thomas Hill")
	check(hill_pages.size() == 1 and hill_pages[0].history != "", "hill_painters_light writes a Register page with HISTORY note")
	var has_ansel_margin := false
	for note: String in hill_pages[0].notes:
		if "Ansel Adams:" in note:
			has_ansel_margin = true
	check(has_ansel_margin, "Ansel Adams leaves a margin note on Thomas Hill's Register page")

	# The Last Canvas: Fall/Winter only, awards hill_study camp piece (+25% gifts)
	QuestLog.talk_to("thomas_hill")
	check(not QuestLog.active.has("hill_last_canvas"), "hill_last_canvas does not start in Spring")

	# Baseline loved gift points before hill_study
	Inventory.add("bread_pudding", 2)
	var before_pts := int(Friendship.points.get("thomas_hill", 0))
	Friendship.give("thomas_hill", "bread_pudding")
	var plain_delta := int(Friendship.points.get("thomas_hill", 0)) - before_pts
	check(plain_delta == Friendship.LOVED_POINTS,
		"baseline loved gift gives %d points (got %d)" % [Friendship.LOVED_POINTS, plain_delta])

	GameClock.season = GameClock.Season.FALL
	GameClock.day = 5
	GameClock.minutes = 10 * 60
	QuestLog.talk_to("thomas_hill")
	check(QuestLog.active.has("hill_last_canvas"), "hill_last_canvas starts in Fall")
	Inventory.add("toyon_berries", 3)
	QuestLog.talk_to("thomas_hill")
	check(QuestLog.active.get("hill_last_canvas") == 1, "toyon berries advance hill_last_canvas")
	GameClock.minutes = 15 * 60
	QuestLog.talk_to("thomas_hill")
	check(QuestLog.is_completed("hill_last_canvas"), "afternoon studio visit completes hill_last_canvas")
	check(Camp.has("hill_study"), "hill_last_canvas unlocks Thomas Hill's oil study at camp")

	# Gift bonus (+25%) with hill_study at camp
	GameClock.day = 6
	var before_boost := int(Friendship.points.get("thomas_hill", 0))
	Friendship.give("thomas_hill", "bread_pudding")
	var boosted_delta := int(Friendship.points.get("thomas_hill", 0)) - before_boost
	var expected_boost := roundi(Friendship.LOVED_POINTS * 1.25)
	check(boosted_delta == expected_boost,
		"hill_study boosts loved gift by +25%% (%d -> %d)" % [expected_boost, boosted_delta])


func test_francois_matthes_arc() -> void:
	fresh(GameClock.Season.SPRING, 10)
	check(not Perks.has("granite_reader"), "granite_reader perk starts locked")

	# Baseline climb metrics before granite_reader
	var base_state := ClimbState.new(APRON, 2, 7)
	var base_window := base_state.crux_window()
	var crimp_hold := {"grip": "crimp", "crux": false}
	var base_pump := base_state.pump_change(crimp_hold)

	# Reading the Ice: any season
	QuestLog.talk_to("francois_matthes")
	check(QuestLog.active.has("matthes_reading_ice"), "matthes_reading_ice starts in Spring")
	QuestLog.talk_to("john_muir")
	check(QuestLog.active.get("matthes_reading_ice") == 1, "talking to John Muir advances matthes_reading_ice")
	Inventory.add("trail_mix", 2)
	QuestLog.talk_to("francois_matthes")
	check(QuestLog.is_completed("matthes_reading_ice"), "bringing trail food completes matthes_reading_ice")

	# Check Matthes margin note on muir_glacier
	QuestLog.completed.append("muir_glacier")
	var muir_pages := RegisterPages.written().filter(func(p: Dictionary) -> bool: return "Glaciers made this valley" in p.text)
	var has_matthes_note := false
	if not muir_pages.is_empty():
		for note: String in muir_pages[0].notes:
			if "François Matthes" in note:
				has_matthes_note = true
	check(has_matthes_note, "matthes_reading_ice adds François Matthes's margin note on Muir's glacier page")

	# The Glacial Erratic: Summer/Fall only
	QuestLog.talk_to("francois_matthes")
	check(not QuestLog.active.has("matthes_glacial_erratic"), "matthes_glacial_erratic does not start in Spring")

	GameClock.season = GameClock.Season.SUMMER
	GameClock.minutes = 10 * 60
	QuestLog.talk_to("francois_matthes")
	check(QuestLog.active.has("matthes_glacial_erratic"), "matthes_glacial_erratic starts in Summer")
	QuestLog.record_climb("glacier_point_apron")
	QuestLog.talk_to("francois_matthes")
	check(QuestLog.active.get("matthes_glacial_erratic") == 1, "reporting Glacier Point Apron advances matthes_glacial_erratic")
	GameClock.minutes = 15 * 60
	QuestLog.talk_to("francois_matthes")
	check(QuestLog.is_completed("matthes_glacial_erratic"), "afternoon shadow study completes matthes_glacial_erratic")
	check(Perks.has("granite_reader"), "matthes_glacial_erratic unlocks granite_reader perk")

	var boosted_state := ClimbState.new(APRON, 2, 7)
	var boosted_window := boosted_state.crux_window()
	var boosted_pump := boosted_state.pump_change(crimp_hold)
	check(is_equal_approx(boosted_window - base_window, 0.04),
		"granite_reader widens crux_window by +0.04 (%.3f -> %.3f)" % [base_window, boosted_window])
	check(base_pump > 0 and boosted_pump == base_pump - 1,
		"granite_reader reduces positive pump_change by 1 (%d -> %d)" % [base_pump, boosted_pump])


func test_arthur_bellamy_arc() -> void:
	fresh(GameClock.Season.SUMMER, 10)
	Gear.add("harness")
	Gear.add("rope")
	check(Vendor.offers_open(FREIGHT_SHOP).is_empty(),
		"El Portal Express Supply has 0 open offers before bellamy_first_bloom")

	# First Bloom: Spring only
	QuestLog.talk_to("arthur_bellamy")
	check(not QuestLog.active.has("bellamy_first_bloom"), "bellamy_first_bloom does not start in Summer")

	GameClock.season = GameClock.Season.SPRING
	QuestLog.talk_to("arthur_bellamy")
	check(QuestLog.active.has("bellamy_first_bloom"), "bellamy_first_bloom starts in Spring")
	Inventory.add("miners_lettuce", 3)
	QuestLog.talk_to("arthur_bellamy")
	check(QuestLog.active.get("bellamy_first_bloom") == 1, "miner's lettuce advances bellamy_first_bloom")
	QuestLog.talk_to("bridget_degnan")
	check(QuestLog.active.get("bellamy_first_bloom") == 2, "telling Bridget Degnan advances bellamy_first_bloom")
	QuestLog.talk_to("arthur_bellamy")
	check(QuestLog.is_completed("bellamy_first_bloom"), "returning to Arthur Bellamy completes bellamy_first_bloom")

	var tier1 := Vendor.offers_open(FREIGHT_SHOP)
	check(tier1.size() == 4, "bellamy_first_bloom unlocks 4 Tier 1 freight offers (got %d)" % tier1.size())

	# The Winter Train: Winter only
	QuestLog.talk_to("arthur_bellamy")
	check(not QuestLog.active.has("bellamy_winter_train"), "bellamy_winter_train does not start in Spring")

	GameClock.season = GameClock.Season.WINTER
	GameClock.minutes = 11 * 60
	QuestLog.talk_to("arthur_bellamy")
	check(QuestLog.active.has("bellamy_winter_train"), "bellamy_winter_train starts in Winter")
	Inventory.add("wood_rose_hips", 3)
	QuestLog.talk_to("arthur_bellamy")
	check(QuestLog.active.get("bellamy_winter_train") == 1, "wood rose hips advance bellamy_winter_train")
	GameClock.minutes = 18 * 60
	QuestLog.talk_to("arthur_bellamy")
	check(QuestLog.is_completed("bellamy_winter_train"), "evening manifest check completes bellamy_winter_train")

	var tier2 := Vendor.offers_open(FREIGHT_SHOP)
	check(tier2.size() == 7, "bellamy_winter_train unlocks all 7 Express Supply offers (got %d)" % tier2.size())


func test_finale_and_social() -> void:
	for id: String in ["thomas_hill", "francois_matthes", "arthur_bellamy"]:
		check(HeartScenes.SCENES.has(id) and HeartScenes.SCENES[id].has(3) and HeartScenes.SCENES[id].has(5),
			"%s has 3-heart and 5-heart scenes" % id)
		check(SmallTalk.all_lines(id).size() >= 10,
			"%s has full seasonal/everyday SmallTalk lines (%d)" % [id, SmallTalk.all_lines(id).size()])
		check(GuardianMirror.GATHERING.any(func(e: Array) -> bool: return e[0] == id),
			"%s speaks in GuardianMirror.GATHERING" % id)
		check(GuardianFeast.LINES.any(func(e: Array) -> bool: return e[0] == id),
			"%s speaks at GuardianFeast" % id)
	check(GuardianFeast.SEATS.size() >= GuardianFeast.LINES.size(),
		"GuardianFeast has enough seats (%d) for all guests (%d)" % [GuardianFeast.SEATS.size(), GuardianFeast.LINES.size()])
