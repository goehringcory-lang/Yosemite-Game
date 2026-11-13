extends Node
## Headless test of the road to the lost Guardian and the Guardian's camp:
## camp things arrive with their quests and stand at the homestead, the camp
## chest moves things in and out (food keeps its age, space runs out), the
## Journal's case board and camp page, the map's flags (QuestTarget), the
## winter the Tioga Road is shut (the Quests card and sleeping to the thaw),
## the gap in the talus as the leads come in, the late sightings, and the
## supper at camp after the cave.
## Run: godot --headless --path . res://tests/guardian_camp_test.tscn
## Exit code is the number of failed checks.

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	# These checks are about the gated progression, not the open world.
	Park.open_world = false
	SaveManager.save_path = "user://guardian_camp_test_save.json"
	SaveManager.delete_save()
	Engine.time_scale = 20.0
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().process_frame
	await get_tree().process_frame

	test_definitions()
	await test_homestead(world)
	test_rewards()
	test_chest()
	test_save_and_load()
	test_case_board()
	test_targets()
	test_snowed_in()
	await test_rest(world)
	test_gap()
	await test_feast(world)

	SaveManager.delete_save()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func new_game() -> void:
	NewGame.reset()
	GameClock.season = GameClock.Season.SPRING
	GameClock.day = 3
	GameClock.minutes = 9 * 60


func finish(ids: Array) -> void:
	for id: String in ids:
		QuestLog.active.erase(id)
		if not QuestLog.is_completed(id):
			QuestLog.completed.append(id)
	QuestLog.changed.emit()


func test_definitions() -> void:
	var ids := {}
	for piece: Dictionary in Camp.PIECES:
		check(not ids.has(piece.id), "camp thing %s is listed once" % piece.id)
		ids[piece.id] = true
		check(piece.quest == "" or QuestLog.get_quest(piece.quest) != null, "%s comes from a real quest (%s)" % [piece.id, piece.quest])
		var giver := QuestLog.get_character(piece.from) if piece.from != "" else null
		check(piece.from == "" or (giver != null and not giver.needs_tribal_review), "%s comes from someone who can give it (%s)" % [piece.id, piece.from])
		check(piece.text != "", "%s has something to read" % piece.id)
		check(Rect2(0, 0, 1280, 960).has_point(piece.pos), "%s stands on the homestead map" % piece.id)
	for keepsake: Dictionary in Camp.KEEPSAKES:
		var quest := QuestLog.get_quest(keepsake.quest)
		check(quest != null and quest.main_line, "the %s comes from the main line (%s)" % [keepsake.name, keepsake.quest])
	var main := QuestLog.QUESTS.filter(func(q: QuestData) -> bool: return q.main_line and q.id not in ["clark_register", "shop_guidebook", "shop_outfit"])
	check(main.all(func(q: QuestData) -> bool: return Camp.KEEPSAKES.any(func(k: Dictionary) -> bool: return k.quest == q.id)),
		"every main-line climb and the ending leave a keepsake")
	var food_swapped := 0
	for piece: Dictionary in Camp.PIECES:
		var quest := QuestLog.get_quest(piece.quest) if piece.quest != "" else null
		if quest and quest.reward_items.is_empty() and quest.reward_gear.is_empty() and quest.reward_recipes.is_empty():
			food_swapped += 1
	check(food_swapped >= 5, "some quests give a camp thing instead of food (%d)" % food_swapped)
	for entry: Array in GuardianFeast.LINES:
		var who := QuestLog.get_character(entry[0])
		check(who != null and not who.needs_tribal_review, "%s is at the supper, with a line of their own" % entry[0])


func test_homestead(world: Node) -> void:
	new_game()
	world._enter_region("lamon_homestead", "home")
	await get_tree().process_frame
	var bounds: Rect2 = world.region.get_bounds()
	for station in ["Campfire", "Chuckah", "BedrockMortar", "LeachingBasin"]:
		var node: Node2D = world.region.find_child(station, true, false)
		check(node != null and bounds.has_point(node.position), "the homestead's %s is on the map you can walk (%s)" % [station, node.position if node else "missing"])
	var chest: CampPiece = world.region.entities.get_node_or_null(CampPiece.node_name("chest"))
	check(chest != null, "the camp things are laid out at the homestead")
	check(chest != null and not chest.visible, "and the chest isn't there on the first day")
	var feast: Node = world.region.entities.get_node_or_null(GuardianFeast.NAME)
	check(feast != null and GuardianFeast.at(get_tree()) == null, "the supper is laid on at camp, and not yet")
	finish(["clark_register", "lamon_orchard"])
	await get_tree().process_frame
	check(chest != null and chest.visible, "Lamon's apple box turns up once his orchard is done")
	var tent: Node = world.region.entities.get_node_or_null("Tent")
	finish(["degnan_bread", "curry_starter"])
	check(tent != null and not tent.get_node("Sprite").visible, "Jennie Curry's canvas tent stands where the little one was")
	world._enter_region("curry_village", "homestead")
	await get_tree().process_frame
	check(world.region.entities.get_node_or_null(CampPiece.node_name("chest")) == null, "camp things only go up at the homestead")


func test_rewards() -> void:
	new_game()
	check(Camp.pieces().is_empty(), "a new camp has nothing in it")
	var line := ""
	var quest := QuestLog.get_quest("lamon_orchard")
	QuestLog.completed.append("clark_register")
	QuestLog.active["lamon_orchard"] = quest.steps.size() - 1
	line = QuestLog._give_rewards(quest)
	check(line.contains("For your camp: an apple-box chest"), "finishing Lamon's orchard says what it brings the camp (%s)" % line)
	finish(["partner_apron"])
	check(Camp.has("camp_chair") and Camp.has("keepsake_shelf") and Camp.keepsakes().size() == 1, "Wren's first climb brings a stool, the shelf, and its first keepsake")
	check(Camp.reward_line("partner_apron").contains("tick card"), "and the keepsake is in the reward line")
	check(not Camp.has("summit_cairn"), "no cairn before a summit")
	Achievements.summits = {"sentinel_rock": {"day": 1}}
	check(Camp.has("summit_cairn") and Camp.describe("summit_cairn").contains("Sentinel Rock"), "a summit starts the cairn, and it names them")
	Achievements.fish = {"brown_trout": {"count": 1, "biggest": 17, "trophies": 0}}
	finish(["greg_first_rod"])
	check(Camp.describe("fish_board").contains("17-inch"), "the fish board shows your biggest catch")
	finish(["leonard_belay"])
	Gear.add("rope")
	check(Camp.describe("gear_rack").contains("Rope"), "the gear rack shows your rope (%s)" % Camp.describe("gear_rack"))


func test_chest() -> void:
	new_game()
	finish(["clark_register", "lamon_orchard"])
	Inventory.add("lamon_apple", 5)
	var fresh := Larder.days_left("lamon_apple")
	# a night passes with the apples in the pack
	Larder._on_day_started()
	check(Larder.days_left("lamon_apple") == fresh - 1, "apples age in the pack")
	check(Camp.put_away("lamon_apple", 3) == 3 and Inventory.count("lamon_apple") == 2 and Camp.chest_count("lamon_apple") == 3, "three apples go in the chest")
	check(int(Camp.chest_batches.lamon_apple[0]) == fresh - 1, "keeping their age")
	Camp._age_food()
	check(int(Camp.chest_batches.lamon_apple[0]) == fresh - 2, "and they keep aging in there")
	check(Camp.take_out("lamon_apple", 3) == 3 and Inventory.count("lamon_apple") == 5 and not Camp.chest.has("lamon_apple"), "they come back out")
	check(Larder.batches.lamon_apple.count(fresh - 2) == 3, "no fresher than they went in (%s)" % str(Larder.batches.lamon_apple))
	# space runs out, until the bear box
	var kinds := 0
	for item: ItemData in ItemDB.forage_items():
		if kinds >= Camp.CHEST_SPACES:
			break
		Inventory.add(item.id, 1)
		kinds += Camp.put_away(item.id, 1)
	check(Camp.chest.size() == Camp.CHEST_SPACES, "the chest holds %d kinds of thing" % Camp.CHEST_SPACES)
	Inventory.add("chocolate_bar", 1)
	check(Camp.put_away("chocolate_bar", 1) == 0 and Inventory.count("chocolate_bar") == 1, "and not one more")
	finish(["hodges_bear_season"])
	check(Camp.chest_spaces() == Camp.CHEST_SPACES + Camp.BEAR_BOX_SPACES and Camp.put_away("chocolate_bar", 1) == 1, "the bear box makes room")
	var menu := CampPiece.chest_menu(false)
	check(menu.ids.size() == Camp.chest.size() and menu.options.back() == "Back", "the chest's menu lists what's in it, a page at a time")
	# spoiling in the chest
	Camp.chest_batches["lamon_apple"] = [1]
	Camp.chest["lamon_apple"] = 1
	Camp._age_food()
	check(not Camp.chest.has("lamon_apple") and Camp.last_spoiled.to_lower().contains("apple"), "food spoils in the chest too, and the morning says so")


func test_save_and_load() -> void:
	var saved := Camp.save_data()
	var kinds := Camp.chest.size()
	Camp.start_new_game()
	check(Camp.chest.is_empty(), "a new game empties the chest")
	Camp.load_data(JSON.parse_string(JSON.stringify(saved)))
	check(Camp.chest.size() == kinds, "the chest saves and loads (%d kinds)" % Camp.chest.size())


func test_case_board() -> void:
	new_game()
	finish(["clark_register"])
	var count := GuardianSearch.board_count()
	check(count.x == 1 and count.y == GuardianSearch.SIGHTINGS.size() + Herbarium.CLUES.size() - 1, "the case board counts every lead (%s)" % count)
	var blanks := GuardianSearch.board().filter(func(e: Dictionary) -> bool: return not e.found)
	check(blanks.all(func(e: Dictionary) -> bool: return str(e.get("hint", "")) != ""), "every blank says who might turn something up")
	for sighting: Dictionary in GuardianSearch.SIGHTINGS:
		var quest := QuestLog.get_quest(sighting.quest)
		check(quest != null and (quest.main_line or quest.press_line), "the sighting after %s is on the main line or the press book's" % sighting.quest)
	finish(["enid_press", "hodges_herbarium", "hodges_canyon", "enid_rim"])
	check(GuardianSearch.sightings().any(func(s: Dictionary) -> bool: return s.text.contains("snow plant")), "the press book's walk turns up a sighting of its own")


func test_targets() -> void:
	new_game()
	var target := QuestTarget.current()
	check(target.get("region") == "lamon_homestead" and target.get("hub") == "yosemite_valley", "the first flag is on Clark, at the homestead (%s)" % str(target))
	finish(["clark_register", "shop_guidebook", "shop_outfit"])
	QuestLog.active["partner_apron"] = QuestLog.get_quest("partner_apron").steps.size() - 1
	target = QuestTarget.current()
	check(target.get("route") == "firefall_slab" and target.get("region") == "curry_village", "a climb's flag is on its route (%s)" % str(target))
	var missing := PackedStringArray()
	for quest: QuestData in QuestLog.QUESTS:
		if (quest.main_line or quest.press_line) and quest.giver != "mountain_shop" and QuestTarget.region_of(quest.giver) == "":
			missing.append(quest.giver)
	check(missing.is_empty(), "everyone on the main line and the press book can be found on the map (%s)" % ", ".join(missing))
	QuestLog.active.clear()
	finish(QuestLog.QUESTS.filter(func(q: QuestData) -> bool: return q.id != QuestLog.FINALE_QUEST).map(func(q: QuestData) -> String: return q.id))
	QuestLog.final_entry = 0
	QuestLog.active[QuestLog.FINALE_QUEST] = 0
	target = QuestTarget.current()
	check(target.get("region") == "the_ahwahnee" and target.get("point") == "royal_arches", "the finale's flag is on the gap under the Royal Arches")


const UP_TO_THE_NOSE := ["clark_register", "shop_guidebook", "shop_outfit", "partner_apron", "leonard_belay", "eichorn_apron",
	"robbins_clean", "eichorn_spires", "salathe_steel", "johnson_astroman", "robbins_roof", "harding_summit"]


func test_snowed_in() -> void:
	new_game()
	finish(UP_TO_THE_NOSE)
	GameClock.season = GameClock.Season.FALL
	GameClock.day = 10
	check(not QuestLog.snowed_in(), "the road's open early in the fall")
	var objective: String = QuestLog.main_objective().get("objective", "")
	check(objective.contains("closes for winter on Fall 23"), "and Muir's card says it shuts soon (%s)" % objective)
	GameClock.day = 24
	check(QuestLog.snowed_in(), "after Fall 23 the story is snowed in")
	check(Park.nights_until_open("tioga_road") == 4 + 28 + 28 + 1, "the road opens Summer 1 (%d nights)" % Park.nights_until_open("tioga_road"))
	objective = QuestLog.main_objective().get("objective", "")
	check(objective.contains("Summer 1") and objective.contains("tent"), "the card says when it opens and offers the tent (%s)" % objective)
	check(QuestLog.things_to_do_now(3).size() > 0 and objective != "", "and names stories to get on with meanwhile: %s" % ", ".join(QuestLog.things_to_do_now(3)))
	finish(["muir_cathedral", "muir_glacier", "muir_cassiope"])
	check(not QuestLog.snowed_in(), "nothing's snowed in once the high country's done")


func test_rest(world: Node) -> void:
	new_game()
	world._enter_region("lamon_homestead", "home")
	await get_tree().process_frame
	finish(["harding_summit"])
	GameClock.season = GameClock.Season.FALL
	GameClock.day = 26
	var nights := Park.nights_until_open("tioga_road")
	await world.rest(nights)
	check(GameClock.season == GameClock.Season.SUMMER and GameClock.day == 1 and Park.is_open("tioga_road"),
		"sleeping through to the thaw wakes you on Summer 1 (%s %d)" % [GameClock.SEASON_NAMES[GameClock.season], GameClock.day])


func test_gap() -> void:
	new_game()
	check(GuardianGap.stage() == 0, "the gap is just a gap at first")
	check(GuardianGap.journal_line().contains("Nobody has said"), "and the case board doesn't know where to look")
	finish(["enid_press", "hodges_herbarium", "hodges_canyon", "clark_grove_sprigs"])
	check(GuardianGap.stage() == 1 and GuardianGap.journal_line().contains("Royal Arches"), "Clark's tin box sets cold air coming out of it")
	finish(["enid_full_press"])
	check(GuardianGap.stage() == 2, "the full press puts frost on it")
	QuestLog.active[QuestLog.FINALE_QUEST] = 0
	check(GuardianGap.stage() == 3, "and it opens for the finale")


func test_feast(world: Node) -> void:
	new_game()
	world._enter_region("lamon_homestead", "home")
	await get_tree().process_frame
	finish(QuestLog.QUESTS.filter(func(q: QuestData) -> bool: return not q.guardian_line).map(func(q: QuestData) -> String: return q.id))
	await get_tree().process_frame
	await get_tree().process_frame
	var feast := GuardianFeast.at(get_tree())
	check(feast != null, "after the cave there's a supper at camp")
	var guests := get_tree().get_nodes_in_group("feast_guest")
	check(guests.size() == GuardianFeast.LINES.size(), "everyone with a line is round the fire (%d)" % guests.size())
	check(guests.all(func(npc: NPC) -> bool: return npc.say_instead.size() == 1 and npc.quest_marker == null), "each with one thing to say and no errands")
	var sign: CampPiece = world.region.entities.get_node_or_null(CampPiece.node_name("guardian_sign"))
	check(sign != null and sign.visible, "and the sign is up: the Guardian's camp")
	await feast.finish()
	await get_tree().process_frame
	check(QuestLog.is_unlocked(GuardianFeast.FEAST_DONE) and GuardianFeast.at(get_tree()) == null, "turning in ends the supper")
	await get_tree().process_frame
	check(get_tree().get_nodes_in_group("feast_guest").all(func(n: Node) -> bool: return n.is_queued_for_deletion()), "and the guests go home")
