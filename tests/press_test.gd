extends Node
## Headless test of the press book: the plants and where they grow, the plant
## press and its quests beside the tick list, the Press Book tab, and the
## finale in the Guardian's cave.
## Run: godot --headless --path . res://tests/press_test.tscn
## Uses its own save file, so it never touches a real save.
## Exit code is the number of failed checks.

const PRESS_ORDER := ["enid_press", "hodges_herbarium", "hodges_canyon", "clark_grove_sprigs", "enid_rim", "muir_cassiope", "enid_full_press"]
const REGIONS := ["lamon_homestead", "curry_village", "ahwahnee_trail", "the_ahwahnee", "yosemite_village",
	"yosemite_valley", "el_portal", "wawona", "glacier_point", "tuolumne_meadows"]

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	await get_tree().process_frame
	SaveManager.save_path = "user://press_test_save.json"
	SaveManager.delete_save()
	_check_plants()
	_check_quests()
	_play_press_line()
	_play_finale()
	await _check_world()
	await _check_growth()
	SaveManager.delete_save()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func new_game() -> void:
	Inventory.start_new_game()
	Gear.start_new_game()
	Recipes.start_new_game()
	QuestLog.start_new_game()
	Herbarium.start_new_game()
	GameClock.season = GameClock.Season.SPRING


func said(lines: Array, text: String) -> bool:
	return lines.any(func(l: Dictionary) -> bool: return text in l.text)


## Talks to someone until they've offered [param quest_id]: their side stories
## come up first, one a conversation.
func talk_until(character_id: String, quest_id: String) -> void:
	for i in 5:
		if not QuestLog.active.has(quest_id):
			QuestLog.talk_to(character_id)


## Presses the first [param n] plants that grow in [param hub] and aren't in the book.
func press_from(hub: String, n: int) -> void:
	for plant: Dictionary in Herbarium.PLANTS:
		if n > 0 and hub in Herbarium.hubs_of(plant) and Herbarium.press(plant.id, hub):
			n -= 1


## Every plant is complete, has a drawing, and grows in a region that exists.
func _check_plants() -> void:
	var ids := {}
	var sheet: Texture2D = load(Herbarium.SHEET)
	check(sheet != null and sheet.get_width() / Herbarium.FRAME * (sheet.get_height() / Herbarium.FRAME) >= Herbarium.PLANTS.size(),
		"the plant sheet has a frame for every plant")
	var image := sheet.get_image()
	var problems: Array[String] = []
	for plant: Dictionary in Herbarium.PLANTS:
		if ids.has(plant.id):
			problems.append("%s twice" % plant.id)
		ids[plant.id] = true
		for key in ["name", "latin", "note"]:
			if str(plant.get(key, "")) == "":
				problems.append("%s has no %s" % [plant.id, key])
		# The Press Book shows a note on two lines.
		if str(plant.note).length() > 110:
			problems.append("%s's note is too long (%d)" % [plant.id, str(plant.note).length()])
		if int(plant.seasons) == 0 or plant.grows.is_empty():
			problems.append("%s never grows" % plant.id)
		for region_id: String in plant.grows:
			if not ResourceLoader.exists("res://scenes/regions/%s.tscn" % region_id):
				problems.append("%s grows in a missing region %s" % [plant.id, region_id])
		for hub in Herbarium.hubs_of(plant):
			if not Herbarium.HUB_NAMES.has(hub):
				problems.append("%s grows in unnamed hub %s" % [plant.id, hub])
		var icon := Herbarium.icon(plant.id) as AtlasTexture
		var drawn := false
		for y in Herbarium.FRAME:
			for x in Herbarium.FRAME:
				drawn = drawn or image.get_pixel(int(icon.region.position.x) + x, int(icon.region.position.y) + y).a > 0.5
		if not drawn:
			problems.append("%s has no drawing" % plant.id)
	check(problems.is_empty(), "every plant has a name, a note, a drawing and a place to grow %s" % [problems])
	check(Herbarium.PLANTS.size() >= 24, "the press book has its plants (%d)" % Herbarium.PLANTS.size())
	for hub: String in Herbarium.HUB_NAMES:
		check(Herbarium.total(hub) >= 4, "%s has at least four plants (%d)" % [hub, Herbarium.total(hub)])
	check(Herbarium.PLANTS.any(func(p: Dictionary) -> bool: return p.get("protected", false)), "at least one plant is sketched, not picked")
	check(Herbarium.hint(Herbarium.get_plant("snow_plant")) == "Conifer shade, Glacier Point. Spring and summer.",
		"an empty page says where and when to look (%s)" % Herbarium.hint(Herbarium.get_plant("snow_plant")))
	check(Herbarium.seasons_text(Herbarium.ALL_YEAR) == "All year" and Herbarium.seasons_text(Herbarium.SUMMER) == "Summer only", "seasons read plainly")


## The press book's quests ask for plants that exist, in numbers that can be found.
func _check_quests() -> void:
	var press: Array = QuestLog.QUESTS.filter(func(q: QuestData) -> bool: return q.press_line)
	check(press.map(func(q: QuestData) -> String: return q.id) == PRESS_ORDER, "the press book has its seven quests, in order")
	for quest: QuestData in press:
		check(not quest.main_line and QuestLog.get_character(quest.giver) != null, "%s is a press-book quest with a giver" % quest.id)
		var pressed_steps := quest.steps.filter(func(s: Dictionary) -> bool: return s.type == "pressed")
		check(not pressed_steps.is_empty(), "%s asks for plants" % quest.id)
		for step: Dictionary in pressed_steps:
			var hub: String = step.get("hub", "")
			var known: bool = step.get("plants", []).all(func(id: String) -> bool: return not Herbarium.get_plant(id).is_empty())
			# In winter fewer plants are up, and the quest must still be possible.
			var in_winter := Herbarium.PLANTS.filter(func(p: Dictionary) -> bool:
				return (hub == "" or hub in Herbarium.hubs_of(p)) and Herbarium.in_season(p, GameClock.Season.SUMMER)).size()
			check(known and (hub == "" or Herbarium.HUB_NAMES.has(hub)) and int(step.get("count", 0)) <= in_winter,
				"%s asks for plants that exist, in numbers that grow there" % quest.id)
	var giver_kinds := {}
	for quest: QuestData in press:
		giver_kinds[quest.giver] = true
	check(giver_kinds.size() >= 4, "several naturalists and rangers ask for plants (%d)" % giver_kinds.size())
	var finale := QuestLog.get_quest(QuestLog.FINALE_QUEST)
	check(finale != null and finale.main_line and "clark_last_page" in finale.requires and PRESS_ORDER[-1] in finale.requires,
		"the finale needs the last page and the full press")
	for clue: Dictionary in Herbarium.CLUES:
		check(QuestLog.get_quest(clue.quest) != null, "the clue after %s belongs to a real quest" % clue.quest)


## Enid's press, and the plants for Hodges, Clark and Muir, to the full press.
func _play_press_line() -> void:
	new_game()
	check(not Herbarium.has_press() and QuestLog.press_objective().is_empty() == false and "Enid Michael" in QuestLog.press_objective().objective,
		"before the press, the journal says who has plants to ask for (%s)" % QuestLog.press_objective().get("objective", ""))
	check(QuestLog.available_from("enid_michael") == null, "Enid waits until Clark has given you the Register")
	QuestLog.completed.append("clark_register")
	check("Museum garden" in QuestLog.press_objective().objective, "early on she's at the Museum garden (%s)" % QuestLog.press_objective().objective)
	var lines := QuestLog.talk_to("enid_michael")
	check(QuestLog.active.has("enid_press") and Herbarium.has_press() and said(lines, "Received the plant press"),
		"Enid Michael hands over the plant press as her quest starts")
	check(said(lines, "Collected for the Guardian of Yosemite"), "and the mystery of the old labels begins")
	check(Herbarium.clues().is_empty(), "no clues yet")
	Herbarium.press("incense_cedar", "Curry Village")
	check(not Herbarium.press("incense_cedar") and Herbarium.count() == 1 and Herbarium.count("yosemite_valley") == 1 and Herbarium.count("wawona") == 0,
		"a plant goes in the book once, under the place it grows")
	check("1 of 3 pressed" in QuestLog.objective_text(QuestLog.get_quest("enid_press")), "the objective counts what's pressed (%s)" % QuestLog.objective_text(QuestLog.get_quest("enid_press")))
	lines = QuestLog.talk_to("enid_michael")
	check(QuestLog.active.has("enid_press") and said(lines, "single sprig"), "one plant isn't three: she reminds you")
	press_from("el_portal", 2)
	QuestLog.talk_to("enid_michael")
	check(QuestLog.active.has("enid_press"), "plants from the canyon don't count for the Valley floor")
	press_from("yosemite_valley", 2)
	lines = QuestLog.talk_to("enid_michael")
	check(QuestLog.is_completed("enid_press") and Inventory.count("dried_apples") == 2, "three Valley plants finish The Plant Press")
	check(said(lines, "New in the Register: a page from Enid Michael") and Herbarium.clues().size() == 1, "it writes a Register page and the first clue")

	# The press book doesn't hold up a giver's other stories, or the other way round.
	QuestLog.completed.append_array(["shop_guidebook", "shop_outfit", "partner_apron", "leonard_belay", "eichorn_apron"])
	check(QuestLog.get_character("enid_michael").home_now(QuestLog.is_completed) == "Sentinel Dome", "once the rim is open, Enid is up at Sentinel Dome")
	QuestLog.talk_to("clare_hodges")
	check(QuestLog.active.has("hodges_patrol") or QuestLog.active.has("hodges_herbarium"), "Hodges has something for you")
	QuestLog.talk_to("clare_hodges")
	check(QuestLog.active.has("hodges_patrol") and QuestLog.active.has("hodges_herbarium"), "her side story and her herbarium run side by side")
	check(QuestLog.press_objective().quest.id == "hodges_herbarium" and "still to find: Canyon Live Oak" in QuestLog.press_objective().objective,
		"the journal names the plants still to find (%s)" % QuestLog.press_objective().objective)
	Herbarium.press("canyon_live_oak")
	press_from("yosemite_valley", 2)
	lines = QuestLog.talk_to("clare_hodges")
	check(QuestLog.is_completed("hodges_herbarium") and said(lines, "1906"), "cedar, live oak and six plants: Hodges has no Guardian by that name")
	QuestLog.talk_to("clare_hodges")
	check(QuestLog.active.has("hodges_canyon"), "then she sends you down the canyon")
	press_from("el_portal", 1)
	QuestLog.talk_to("clare_hodges")
	check(QuestLog.is_completed("hodges_canyon"), "three foothill plants finish Down the Canyon")
	talk_until("galen_clark", "clark_grove_sprigs")
	check(QuestLog.active.has("clark_grove_sprigs"), "and Clark asks for the grove's plants")
	Herbarium.press("giant_sequoia", "Grizzly Giant")
	Herbarium.press("sugar_pine", "Mariposa Grove")
	lines = QuestLog.talk_to("galen_clark")
	check(QuestLog.is_completed("clark_grove_sprigs") and said(lines, "tin box"), "Clark remembers a gap in the talus and a tin box")
	lines = QuestLog.talk_to("enid_michael")
	check(QuestLog.active.has("enid_rim") or QuestLog.active.has("enid_leave_some"), "Enid has something for you at the rim")
	QuestLog.talk_to("enid_michael")
	check(QuestLog.active.has("enid_rim"), "Above the Rim starts")
	Herbarium.press("snow_plant", "Glacier Point")
	Herbarium.press("jeffrey_pine", "Sentinel Dome")
	lines = QuestLog.talk_to("enid_michael")
	check(QuestLog.is_completed("enid_rim") and said(lines, "needle for needle"), "Jeffrey pine and three rim plants (the sketched snow plant counts)")
	check(QuestLog.available_from("john_muir") == null or QuestLog.available_from("john_muir").id != "muir_cassiope", "Muir's heather waits on the road to Tuolumne")
	check("has plants to ask for once" in QuestLog.press_objective().objective, "and the journal says what it's waiting on (%s)" % QuestLog.press_objective().objective)
	QuestLog.completed.append_array(["robbins_clean", "eichorn_spires", "salathe_steel", "johnson_astroman", "robbins_roof", "harding_summit", "muir_cathedral"])
	QuestLog.active.clear()
	check(QuestLog.available_from("john_muir").id in ["muir_glacier", "muir_cassiope"], "Muir has his glacier and his heather for you")
	QuestLog.completed.append("muir_glacier")
	talk_until("john_muir", "muir_cassiope")
	check(QuestLog.active.has("muir_cassiope"), "Cassiope starts")
	Herbarium.press("white_heather", "Tuolumne Meadows")
	press_from("tuolumne_meadows", 3)
	lines = QuestLog.talk_to("john_muir")
	check(QuestLog.is_completed("muir_cassiope") and Inventory.count("dry_crusts") == 3, "Cassiope and four high-country plants")
	talk_until("enid_michael", "enid_full_press")
	check(QuestLog.active.has("enid_full_press"), "The Full Press starts")
	check(not QuestLog.is_completed("enid_full_press") and Herbarium.count() < 20, "it wants twenty plants, and you have %d" % Herbarium.count())
	for plant: Dictionary in Herbarium.PLANTS:
		if Herbarium.count() < 20:
			Herbarium.press(plant.id)
	lines = QuestLog.talk_to("enid_michael")
	check(QuestLog.is_completed("enid_full_press") and said(lines, "no outline on it at all"), "twenty plants fill every outline but one")
	check(Herbarium.clues().size() == PRESS_ORDER.size(), "every press-book quest leaves a clue (%d)" % Herbarium.clues().size())
	check(RegisterPages.written().filter(func(p: Dictionary) -> bool: return p.by == "Enid Michael").size() >= 1, "Enid's page is in the Register")
	var saved := Herbarium.save_data()
	Herbarium.start_new_game()
	check(Herbarium.count() == 0, "a new game empties the press book")
	Herbarium.load_data(saved)
	check(Herbarium.count() == 20 and Herbarium.pressed.jeffrey_pine.where == "Sentinel Dome", "the press book is saved, with where each plant was found")


## The finale: the last page, the gap in the talus, and the mirror.
func _play_finale() -> void:
	check(QuestLog.available_from("galen_clark") == null or QuestLog.available_from("galen_clark").id != QuestLog.FINALE_QUEST,
		"the full press alone doesn't open the finale")
	QuestLog.active.clear()
	QuestLog.completed.append_array(["lebrado_villages", "lucy_basket", "tenaya_ahwahnee", "clark_big_trees", "clark_last_page"])
	check(QuestLog.final_entry_pending() and QuestLog.available_from("galen_clark") == null, "nor does the last page until it's written")
	check(QuestLog.main_objective().is_empty(), "the journal asks for the last page first")
	var lines := QuestLog.write_final_entry(0)
	check(lines.back().text == QuestLog.AFTER_EPILOGUE and "Collected for the Guardian" in lines.back().text, "the Register ends, and the mystery doesn't")
	check(QuestLog.main_objective().quest.id == QuestLog.FINALE_QUEST and "Galen Clark" in QuestLog.main_objective().objective, "then the journal sends you to Clark")

	var door: RegionDoor = load("res://scenes/objects/region_door.tscn").instantiate()
	door.label = "the gap in the talus"
	door.needs_quest = QuestLog.FINALE_QUEST
	check(door.get_prompt() == "Look at the gap in the talus", "the gap in the talus is shut until Clark sends you")
	lines = QuestLog.talk_to("galen_clark")
	check(QuestLog.active.has(QuestLog.FINALE_QUEST) and said(lines, "Royal Arches"), "Clark sends you under the Royal Arches")
	check(door.get_prompt() == "Go to the gap in the talus", "and the gap opens")
	door.free()
	check(said(QuestLog.talk_to("galen_clark"), "cold air") and not QuestLog.is_completed(QuestLog.FINALE_QUEST), "talking to Clark again doesn't end it")
	check(GuardianMirror.gathering_lines().all(func(l: Dictionary) -> bool: return l.text != ""), "everyone has something to say in the cave")
	check(said(GuardianMirror.gathering_lines(), "It was you all along"), "they tell you it was you all along")
	check(said(GuardianMirror.gathering_lines(), "pending tribal review"), "Native people's words in the finale wait on tribal review")
	lines = QuestLog.find_guardian()
	check(QuestLog.is_completed(QuestLog.FINALE_QUEST) and QuestLog.is_unlocked(QuestLog.GUARDIAN_FOUND) and said(lines, "Welcome, Guardian"),
		"looking in the mirror finds the lost Guardian")
	check(said(lines, "New in the Register: a page from The lost Guardian") and QuestLog.is_unlocked("guardian"), "the last sheet goes in the Register")
	check(QuestLog.find_guardian().is_empty(), "the Guardian is found once")
	check(Herbarium.clues().size() == Herbarium.CLUES.size(), "the last clue is the answer")
	check(said(GuardianMirror.closing_lines(), "The end of Valley Days"), "the game says the story is over")
	lines = QuestLog.talk_to("galen_clark")
	check(lines.size() == 2 and lines[0].text == QuestLog.AFTER_FINALE[0], "afterwards Clark calls you Guardian")
	check(QuestLog.main_objective().is_empty() and QuestLog.press_objective().is_empty(), "and nothing is left on either list")


## In the real World: plants stand in the homestead, pressing one works, the
## Press Book tab shows it, and the cave holds the mirror and the crowd.
func _check_world() -> void:
	new_game()
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(world)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var player: Player = world.player
	var plants: PlantSpawner = world.region.entities.get_node_or_null("Plants_lamon_homestead")
	check(plants != null and plants.growing().has("bracken_fern") and plants.growing().has("black_oak"), "plants grow at the homestead from the first morning")
	var fern: PlantSpecimen = null
	for child: PlantSpecimen in plants.get_children():
		if child.plant_id == "bracken_fern":
			fern = child
	check(fern.get_prompt() == "Look at the Western Bracken Fern", "without a press you can only look")
	fern.interact(player)
	check(not Herbarium.has("bracken_fern") and world.hud.info_panel.visible and "Enid Michael" in world.hud.info_text.text,
		"looking at a plant tells you who has a press")
	check(not fern.is_wanted(), "and nothing glints yet")
	QuestLog.unlocks.append(Herbarium.ABILITY)
	QuestLog.changed.emit()
	check(fern.get_prompt() == "Press a sprig of Western Bracken Fern" and fern.is_wanted() and fern.is_processing(),
		"with the press, a plant you don't have glints, and you can take a sprig")
	fern.interact(player)
	check(Herbarium.has("bracken_fern") and Herbarium.pressed.bracken_fern.where != "" and is_instance_valid(fern) and fern.is_inside_tree(),
		"pressing takes a sprig and leaves the plant (found at %s)" % Herbarium.pressed.bracken_fern.get("where", ""))
	check("Pressed: Western Bracken Fern" in world.hud.info_title.text and "1 of %d" % Herbarium.total() in world.hud.info_text.text, "and says what you found")
	fern.interact(player)
	check(Herbarium.count() == 1 and not fern.is_wanted() and not fern.is_processing(), "the same plant isn't pressed twice, and it stops glinting")
	var spots := {}
	for child: PlantSpecimen in plants.get_children():
		spots[child.cell] = child.plant_id
	await plants.grow()
	var same := plants.get_children().all(func(child: PlantSpecimen) -> bool: return spots.get(child.cell) == child.plant_id)
	check(same and plants.get_child_count() == spots.size(), "plants come up in the same places every day")

	# The Press Book tab.
	var journal: Journal = get_tree().get_first_node_in_group("journal")
	check(InputMap.has_action("press_book"), "the Press Book has a key")
	journal.open(Journal.Tab.PRESS)
	check(journal.tab() == Journal.Tab.PRESS and journal._slots.size() == Herbarium.PLANTS.size() and journal._detail.visible,
		"the Press Book shows a slot for every plant (%d)" % journal._slots.size())
	var texts: Array = journal._body.get_children().filter(func(n: Node) -> bool: return n is Label).map(func(n: Label) -> String: return n.text)
	check(texts.has("The Valley floor (1 of %d)" % Herbarium.total("yosemite_valley")) and texts.has("The lost Guardian"),
		"grouped by where they grow, with the lost Guardian's clues below")
	var fern_slot := journal._slot_items.find_custom(func(item: Dictionary) -> bool: return item.name == "Western Bracken Fern")
	check(fern_slot >= 0 and not journal._slot_items[fern_slot].dim and "Found at" in journal._slot_items[fern_slot].description, "a pressed plant shows where you found it")
	check(journal._slot_items[0].dim and journal._slot_items[0].description.begins_with("Look in: "), "an empty page says where to look (%s)" % journal._slot_items[0].description)
	journal.show_tab(Journal.Tab.QUESTS)
	texts = journal._body.get_children().filter(func(n: Node) -> bool: return n is Label).map(func(n: Label) -> String: return n.text)
	check(texts[0] == "Main story" and texts.any(func(t: String) -> bool: return t.begins_with("The press book (1 of")), "the Quests tab carries the press book beside the main story")
	journal.close()

	# Enid at the Museum garden, then at Sentinel Dome.
	world._enter_region("yosemite_village", "arrival")
	await get_tree().process_frame
	var enid: NPC = world.region.find_child("EnidMichaelGarden", true, false)
	check(enid != null and enid.is_here() and enid.visible, "Enid Michael keeps the Museum garden at first")
	QuestLog.completed.append("eichorn_apron")
	QuestLog.changed.emit()
	check(not enid.is_here() and not enid.visible, "and leaves it for Sentinel Dome when the rim opens")

	# The gap in the talus, and the cave.
	world._enter_region("the_ahwahnee", "cave_mouth")
	await get_tree().process_frame
	var mouth: RegionDoor = world.region.find_child("GuardianCaveMouth", true, false)
	check(mouth != null and mouth.target_region == "guardian_cave" and world.region.get_spawn("cave_mouth") != null, "the gap in the talus is under the Royal Arches")
	check(mouth.get_node("Sprite").texture.resource_path.ends_with("cave_mouth.png"), "and looks like a gap in the rocks")
	world._enter_region("guardian_cave", "door")
	await get_tree().process_frame
	var mirror: GuardianMirror = world.region.find_child("GuardianMirror", true, false)
	check(world.region.indoors and mirror != null and world.region.get_spawn("door") != null, "the cave holds the looking-glass")
	mirror.gather()
	var crowd := get_tree().get_nodes_in_group("guardian_crowd")
	check(crowd.size() == QuestLog.CHARACTERS.size() + QuestLog.STAFF.size(), "everyone in the story gathers behind you (%d)" % crowd.size())
	var blocker: TileMapLayer = world.region.get_node("Blocker")
	check(crowd.all(func(npc: NPC) -> bool: return blocker.get_cell_source_id(blocker.local_to_map(blocker.to_local(npc.global_position))) == -1 and npc.roam_radius() == 0.0),
		"standing on the cave floor, and standing still")
	check(crowd.all(func(npc: NPC) -> bool: return npc.quest_marker == null), "with no errands over their heads")
	mirror.gather()
	check(get_tree().get_nodes_in_group("guardian_crowd").size() == crowd.size(), "they gather once")
	world.queue_free()
	await get_tree().process_frame


## Every plant comes up in every region it's said to grow in, in each of its seasons.
func _check_growth() -> void:
	var missing: Array[String] = []
	for region_id: String in REGIONS:
		var region: Region = load("res://scenes/regions/%s.tscn" % region_id).instantiate()
		add_child(region)
		StoryContent.attach(region)
		await get_tree().physics_frame
		var plants := PlantSpawner.attach(region)
		if plants == null:
			missing.append("%s has no plants" % region_id)
			region.free()
			continue
		for season in 4:
			GameClock.season = season
			await plants.grow()
			var growing := plants.growing()
			for plant: Dictionary in Herbarium.PLANTS:
				var should: bool = plant.grows.has(region_id) and Herbarium.in_season(plant, season)
				if should != growing.has(plant.id):
					missing.append("%s in %s, season %d" % [plant.id, region_id, season])
		region.free()
	GameClock.season = GameClock.Season.SPRING
	check(missing.is_empty(), "every plant grows where and when the press book says %s" % [missing])
