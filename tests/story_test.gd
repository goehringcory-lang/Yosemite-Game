extends Node
## Headless test of the story systems: quests, gear, food, the chuckah,
## recipes, and the climbing minigame.
## Run: godot --headless --path . res://tests/story_test.tscn
## Exit code is the number of failed checks.

const APRON := preload("res://data/routes/glacier_point_apron.tres")
const SWAN := preload("res://data/routes/swan_slab.tres")
const FIREFALL := preload("res://data/routes/firefall_slab.tres")

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	await get_tree().process_frame # let the root finish adding scenes
	new_game()
	test_leonard_quest()
	test_climb_rules()
	test_apron_is_climbable()
	test_tabuce_and_acorns()
	test_spoilage()
	test_save_round_trip()
	test_firefall_slab()
	test_pay_step()
	test_register_notes()
	test_story_beats()
	test_last_page_waiting()
	await test_dialogue_and_minigame_scenes()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func new_game() -> void:
	Inventory.start_new_game()
	Inventory.items.clear()
	Inventory.changed.emit()
	Gear.start_new_game()
	Granary.start_new_game()
	Recipes.start_new_game()
	QuestLog.start_new_game()


func test_leonard_quest() -> void:
	check(not Gear.has_all(APRON.required_gear), "can't climb the Apron with starting gear")
	check(Gear.missing(APRON.required_gear).size() == 3, "missing rope, harness, cams: %s" % [Gear.missing(APRON.required_gear)])
	Gear.add("harness") # from the Mountain Shop's first kit
	check(QuestLog.talk_to("dick_leonard").size() > 0 and not QuestLog.active.has("leonard_belay"),
		"Leonard won't start the lessons before you have the guidebook")
	QuestLog.unlocks.append("guidebook")
	QuestLog.completed.append_array(["clark_register", "shop_guidebook", "shop_outfit"])
	check(QuestLog.talk_to("dick_leonard").size() > 0 and not QuestLog.active.has("leonard_belay"),
		"Leonard waits until you've climbed with Wren")
	QuestLog.completed.append("partner_apron")
	var lines := QuestLog.talk_to("dick_leonard")
	check(QuestLog.active.has("leonard_belay") and lines.size() == 4, "Dick Leonard offers his quest")
	lines = QuestLog.talk_to("dick_leonard")
	check(lines.size() == 1 and "food" in lines[0].text, "reminder while the step isn't done")
	Inventory.add("miners_lettuce", 4)
	QuestLog.talk_to("dick_leonard")
	check(QuestLog.active.get("leonard_belay") == 1, "trail food advances to the climb")
	check(not QuestLog.is_completed("leonard_belay"), "the quest can't finish without the climb")
	var state := ClimbState.new(SWAN, Gear.count("cam"), 1)
	play(state)
	check(state.status == ClimbState.Status.TOPPED_OUT, "Swan Slab top rope always tops out")
	check(QuestLog.record_climb("swan_slab") and not QuestLog.record_climb("swan_slab"), "the tick is recorded once")
	check("Tell Dick Leonard" in QuestLog.objective_text(QuestLog.get_quest("leonard_belay")), "the journal says who to tell after a tick")
	check(QuestLog.tick_report("swan_slab").size() == 2, "the tick report names the waiting quest")
	lines = QuestLog.talk_to("dick_leonard")
	check(QuestLog.is_completed("leonard_belay"), "reporting the tick finishes the quest")
	check(Gear.count("rope") == 1 and Gear.count("harness") == 1 and Gear.count("cam") == 2, "reward: rope, 2 cams")
	check("Received Rope, 2 Cams" in lines[-1].text, "reward line: %s" % lines[-1].text)
	check(Gear.has_all(APRON.required_gear), "now geared for the Apron")
	check(Inventory.count("miners_lettuce") == 4, "have_food steps don't take the food")


func test_climb_rules() -> void:
	var state := ClimbState.new(APRON, 2, 7)
	check(state.cams_left == 2 and state.row == 0, "pitch starts at the belay with 2 cams")
	check(not state.move(5), "can't move to a column with no hold")
	# Fall one move above the belay: short fall, caught.
	var dx := first_reachable(state)
	state.move(dx)
	state.stamina = 1
	var dx2 := first_reachable(state)
	state.move(dx2)
	check(state.status == ClimbState.Status.CLIMBING and state.falls == 1 and state.row == 0, "short fall is caught by the belay")
	# A long runout ends the climb.
	state = ClimbState.new(APRON, 0, 7)
	for i in ClimbState.DANGEROUS_RUNOUT:
		state.stamina = 100
		state.move(first_reachable(state))
	state.stamina = 1
	state.move(first_reachable(state))
	check(state.status == ClimbState.Status.RETREATED, "falling far above protection ends the climb")
	# Cams need a crack.
	state = ClimbState.new(APRON, 2, 7)
	var placed := false
	while state.row < state.top_row - 1 and not placed:
		state.stamina = 100
		state.move(first_reachable(state))
		if state.hold_at(state.row, state.col).crack:
			placed = state.place_cam()
			check(placed and state.protection_row == state.row and state.cams_left == 1, "cam placed in a crack")
		else:
			check(not state.place_cam(), "no cam without a crack (row %d)" % state.row)
	# Eating only at belays.
	state = ClimbState.new(APRON, 2, 7)
	Inventory.add("acorn_cake", 1)
	state.stamina = 40
	check(state.eat("acorn_cake") and state.stamina == 85, "eating an acorn cake at the belay restores 45")
	state.move(first_reachable(state))
	Inventory.add("acorn_cake", 1)
	check(not state.eat("acorn_cake"), "can't eat off the ledge")
	Inventory.remove("acorn_cake")


func test_apron_is_climbable() -> void:
	var tops := 0
	for seed in 20:
		Inventory.add("acorn_cake", 3)
		var state := ClimbState.new(APRON, 2, seed)
		play(state)
		if state.status == ClimbState.Status.TOPPED_OUT:
			tops += 1
		Inventory.remove("acorn_cake", Inventory.count("acorn_cake"))
	check(tops >= 18, "a careful climber with food tops out the Apron (%d of 20)" % tops)
	# Food matters on a longer route: Nutcracker is five pitches.
	var nutcracker: RouteData = load("res://data/routes/nutcracker.tres")
	var kit := {"rope": 1, "harness": 1, "cam": 4, "quickdraw": 5, "climbing_shoes": 1, "chalk_bag": 1}
	var fed := 0
	var hungry := 0
	for seed in 20:
		Inventory.add("trail_mix", 2)
		var state := ClimbState.new(nutcracker, 4, seed, kit)
		play(state)
		fed += 1 if state.status == ClimbState.Status.TOPPED_OUT else 0
		Inventory.items.erase("trail_mix")
		var empty := ClimbState.new(nutcracker, 4, seed, kit)
		play(empty, false)
		hungry += 1 if empty.status == ClimbState.Status.TOPPED_OUT else 0
	check(hungry < fed, "climbing a long route without food is harder (%d fed, %d hungry of 20)" % [fed, hungry])


## Firefall Slab: bolted friction. You clip bolts with quickdraws, climbing
## shoes and chalk make moves cheaper, and Wren has to be your partner.
func test_firefall_slab() -> void:
	var kit := {"climbing_shoes": 1, "chalk_bag": 1, "harness": 1, "quickdraw": 5}
	var state := ClimbState.new(FIREFALL, 0, 11, kit)
	check(state.is_bolted() and state.bolts_per_pitch() == 5, "Firefall Slab has 5 bolts a pitch (%d)" % state.bolts_per_pitch())
	check(state.bolts_per_pitch() <= int(FIREFALL.required_gear.quickdraw), "the route asks for enough draws to clip every bolt")
	var cracks := 0
	for r in state.holds:
		for c in state.holds[r]:
			if state.holds[r][c].crack:
				cracks += 1
	check(cracks == 0 and not state.can_place_cam(), "a bolted slab has no cracks for cams")
	# Climbing shoes take a point off every move.
	var bare := ClimbState.new(FIREFALL, 0, 11, {"quickdraw": 5})
	var r1: int = bare.holds[1].keys()[0]
	check(state.move_cost(1, r1) == maxi(int(bare.holds[1][r1].cost) - ClimbState.SHOE_BONUS, 1), "climbing shoes make moves cheaper")
	# Follow the bolt line, clipping as you go.
	while state.row < ClimbState.BOLT_FIRST:
		state.stamina = 100
		state.move(int(state.bolts.get(state.row + 1, state.col + _toward(state, state.row + 1))) - state.col)
	check(state.can_clip() and state.clip_bolt(), "you can clip the first bolt from the line")
	check(state.quickdraws_left == 4 and state.protection_row == state.row and state.protection.back().kind == "draw", "a quickdraw goes on the bolt")
	check(not state.clip_bolt() and state.quickdraws_left == 4, "a bolt is only clipped once")
	# Chalk: once a pitch, off the ledge.
	var next := Vector2i(state.col + _toward(state, state.row + 1), state.row + 1)
	var before := state.move_cost(next.y, next.x)
	check(state.chalk_up() and state.chalk_moves == ClimbState.CHALK_MOVES, "chalking up on the wall")
	var after := state.move_cost(next.y, next.x)
	check(after < before or after == 1, "chalk makes the next move cheaper (%d -> %d)" % [before, after])
	check(not state.chalk_up(), "only once a pitch")
	var no_chalk := ClimbState.new(FIREFALL, 0, 11, {"quickdraw": 5})
	no_chalk.move(first_reachable(no_chalk))
	check(not no_chalk.chalk_up(), "no chalk bag, no chalk")
	# A fall is caught by the quickdraw.
	state.stamina = 1
	state.move(first_reachable(state))
	check(state.status == ClimbState.Status.CLIMBING and state.falls == 1 and "quickdraw" in state.message, "a fall is caught by your quickdraw (%s)" % state.message)
	# A careful climber who clips every bolt tops out.
	var tops := 0
	for seed in 20:
		Inventory.add("trail_mix", 1)
		var s2 := ClimbState.new(FIREFALL, 0, seed, kit)
		play_bolts(s2)
		if s2.status == ClimbState.Status.TOPPED_OUT:
			tops += 1
		if Inventory.count("trail_mix") > 0:
			Inventory.remove("trail_mix", Inventory.count("trail_mix"))
	check(tops >= 19, "clipping every bolt, Firefall Slab goes (%d of 20)" % tops)
	# Wren has to be your partner.
	QuestLog.start_new_game()
	QuestLog.unlocks.append("guidebook")
	var start: ClimbStart = load("res://scenes/climb/climb_start.tscn").instantiate()
	start.route = FIREFALL
	check(not start.has_partner() and start.partner_name() == "Wren Alvarez", "you can't start Firefall Slab without a partner")
	QuestLog.active["partner_apron"] = 0
	check(start.has_partner(), "with Wren's quest underway, Wren belays you")
	start.free()
	QuestLog.active.erase("partner_apron")


func _toward(state: ClimbState, r: int) -> int:
	for dx in [0, -1, 1]:
		if not state.hold_at(r, state.col + dx).is_empty():
			return dx
	return 0


## A bot for bolted routes: keeps near the bolt line and clips every bolt.
func play_bolts(state: ClimbState) -> void:
	var guard := 0
	while state.status == ClimbState.Status.CLIMBING and guard < 500:
		guard += 1
		if state.is_at_belay() and state.stamina < 60:
			var foods := FoodDB.edible_in_inventory()
			if not foods.is_empty():
				state.eat(foods[0])
		if state.can_clip():
			state.clip_bolt()
		var r := state.row + 1
		var best := 0
		var best_score := 9999
		for dx in [-1, 0, 1]:
			if state.hold_at(r, state.col + dx).is_empty():
				continue
			var score := state.move_cost(r, state.col + dx)
			var next_bolt := r + 1 if state.bolts.has(r + 1) else r
			if state.bolts.has(next_bolt):
				score += 10 * absi(int(state.bolts[next_bolt]) - (state.col + dx))
			if score < best_score:
				best = dx
				best_score = score
		state.move(best)


## A "pay" step takes the food when you turn it in.
func test_pay_step() -> void:
	QuestLog.start_new_game()
	Inventory.items.clear()
	QuestLog.completed.append("clark_register")
	QuestLog.talk_to("mountain_shop", "Marty Kessler")
	QuestLog.talk_to("jennie_curry")
	Inventory.add("lamon_apple", 1)
	QuestLog.talk_to("mountain_shop", "Marty Kessler")
	check(not QuestLog.has_guidebook() and Inventory.count("lamon_apple") == 1, "not enough food: nothing is taken")
	Inventory.add("lamon_apple", 2)
	var lines := QuestLog.talk_to("mountain_shop", "Marty Kessler")
	check(QuestLog.has_guidebook() and Inventory.count("lamon_apple") == 1, "20 energy buys the guidebook: 2 apples go")
	check(lines.any(func(l): return l.text.begins_with("You hand over 2 Lamon")), "the trade is announced")
	Inventory.items.clear()


## Every story that writes a Register page ends with a Register note saying
## what's documented and what's dramatized (STORY.md).
func test_register_notes() -> void:
	for page: Dictionary in RegisterPages.PAGES:
		check(QuestLog.get_quest(page.quest) != null, "Register page %s comes from a real quest" % page.by)
		check(RegisterPages.HISTORY.has(page.quest), "%s's page (%s) has a Register note" % [page.by, page.quest])
		if page.get("review", false):
			check("tribal review" in RegisterPages.HISTORY.get(page.quest, ""), "%s's Register note is flagged for tribal review" % page.by)
	for quest_id: String in RegisterPages.HISTORY:
		check(QuestLog.get_quest(quest_id) != null, "Register note %s belongs to a real quest" % quest_id)
	# Finishing a quest writes its page, with the note, before the rewards.
	new_game()
	QuestLog.completed.append_array(["clark_register", "shop_guidebook", "shop_outfit", "partner_apron"])
	QuestLog.talk_to("dick_leonard")
	Inventory.add("miners_lettuce", 4)
	QuestLog.talk_to("dick_leonard")
	QuestLog.record_climb("swan_slab")
	var lines := QuestLog.talk_to("dick_leonard")
	var texts := lines.map(func(l: Dictionary) -> String: return l.text)
	var note := texts.find("Register note: " + RegisterPages.HISTORY.leonard_belay)
	check(texts.has("New in the Register: a page from Dick Leonard.") and note >= 0, "Leonard's page goes in the Register with its note")
	check(note >= 0 and lines[-1].text.begins_with("Quest complete") and note < lines.size() - 1, "the note comes before the rewards")
	var page: Dictionary = RegisterPages.written().filter(func(p: Dictionary) -> bool: return p.by == "Dick Leonard")[0]
	check(page.history == RegisterPages.HISTORY.leonard_belay and page.notes[-1].begins_with("Register note: "), "the journal page carries the note too")
	# A quest with two pages names both, and its note goes on the first only.
	check(RegisterPages.on_completed("clark_last_page")[0].text.contains(" and "), "the last page names both blank pages")
	check(RegisterPages.on_completed("degnan_bread").size() == 2 and RegisterPages.on_completed("shop_outfit").is_empty(),
		"only Register stories get a page (the Mountain Shop isn't in the Register)")
	new_game()


## Between quests, people react to the main line once (the latest news
## only), and remember it in the save; after the last page, they say goodbye.
func test_story_beats() -> void:
	for character: CharacterData in QuestLog.CHARACTERS + QuestLog.STAFF:
		for beat: Dictionary in character.story_beats:
			check(QuestLog.get_quest(beat.after) != null and QuestLog.get_quest(beat.after).main_line and not beat.lines.is_empty(),
				"%s's beat after %s follows a main-line quest" % [character.id, beat.after])
		check(not (character.needs_tribal_review and not character.story_beats.is_empty()), "%s has no unreviewed story beats" % character.id)
	new_game()
	var clark := QuestLog.get_character("galen_clark")
	var idle := QuestLog.talk_to("galen_clark") # starts The Guidebook
	QuestLog.active.erase("clark_register")
	QuestLog.completed.append_array(["clark_register", "shop_guidebook"])
	var first := QuestLog.talk_to("galen_clark")
	check(first.size() == 1 and "two books" in first[0].text, "Clark has news after the guidebook")
	var second := QuestLog.talk_to("galen_clark")
	check(second.size() > 0 and String(second[0].text) in clark.idle_lines, "and then goes back to his usual lines")
	QuestLog.completed.append_array(["shop_outfit", "partner_apron", "leonard_belay", "eichorn_apron"])
	QuestLog.completed.append("clark_big_trees") # his side story would be offered first
	var news := QuestLog.talk_to("galen_clark")
	check(news.size() > 0 and "Glacier Point" in news[0].text, "skipping ahead, Clark only has the latest news (%s)" % news[0].text)
	var saved := QuestLog.save_data()
	QuestLog.start_new_game()
	QuestLog.load_data(saved)
	check(QuestLog.heard_beats.has("galen_clark:eichorn_apron"), "heard news is saved")
	check(String(QuestLog.talk_to("galen_clark")[0].text) in clark.idle_lines, "and isn't repeated after loading")
	QuestLog.completed.append("clark_last_page")
	var goodbye := QuestLog.talk_to("dick_leonard")
	check(goodbye.size() == 2 and "held the rope" in goodbye[1].text, "after the last page, Leonard says goodbye")
	check(idle.size() > 0, "Clark starts the story")
	new_game()


## Back from the glacier, Clark names whoever the last page still waits on,
## one at a time, instead of going quiet. Before that he doesn't nag.
func test_last_page_waiting() -> void:
	new_game()
	var clark := QuestLog.get_character("galen_clark")
	QuestLog.completed.append("clark_register")
	check(String(QuestLog.talk_to("galen_clark")[0].text) in clark.idle_lines, "early on, Clark doesn't hint at the last page")
	QuestLog.completed.append("muir_glacier")
	QuestLog.heard_beats.append("galen_clark:muir_glacier")
	check("Tenaya Creek" in QuestLog.talk_to("galen_clark")[0].text, "after the glacier, Clark sends you to Tenaya first")
	QuestLog.completed.append("tenaya_ahwahnee")
	check("granddaughter" in QuestLog.talk_to("galen_clark")[0].text, "then to Maria Lebrado")
	QuestLog.completed.append("lebrado_villages")
	check("Lucy Telles" in QuestLog.talk_to("galen_clark")[0].text, "then to Lucy Telles")
	QuestLog.completed.append("lucy_basket")
	QuestLog.talk_to("galen_clark")
	check(QuestLog.active.has("clark_last_page"), "and with everyone heard, he offers the last page")
	QuestLog.completed.append_array(["clark_last_page", "lost_guardian"])
	QuestLog.completed.append_array(["enid_press", "hodges_herbarium", "enid_leave_some", "enid_rim", "enid_dawn_chorus", "enid_full_press"])
	var enid := QuestLog.talk_to("enid_michael")
	check(enid.size() == 2 and "Guardian" in enid[1].text, "after the finale, Enid Michael calls you Guardian")
	new_game()

func test_tabuce_and_acorns() -> void:
	QuestLog.talk_to("maggie_howard")
	check(QuestLog.active.has("tabuce_acorns"), "Tabuce offers the acorn quest")
	Inventory.add("black_oak_acorn", 12)
	QuestLog.talk_to("maggie_howard")
	check(QuestLog.is_completed("tabuce_acorns") and QuestLog.is_unlocked("chuckah"), "12 acorns: quest done, chuckah unlocked")
	check(Inventory.count("black_oak_acorn") == 12, "the acorns stay with you")
	QuestLog.talk_to("maggie_howard")
	check(QuestLog.active.has("tabuce_chuckah"), "second quest follows")
	check(Granary.deposit_all() == 0, "can't store acorns before building a chuckah")
	Granary.build_chuckah()
	QuestLog.talk_to("maggie_howard")
	check(QuestLog.active.get("tabuce_chuckah") == 1, "building advances to storing")
	check(Granary.deposit_all() == 12 and Inventory.count("black_oak_acorn") == 0, "12 acorns stored")
	QuestLog.talk_to("maggie_howard")
	check(QuestLog.is_completed("tabuce_chuckah") and Recipes.knows("acorn_cake"), "quest done, acorn recipes learned")
	# The acorn chain
	check(Granary.withdraw(8) == 8, "take 8 acorns out")
	var flour := Recipes.get_recipe("acorn_flour")
	var leach := Recipes.get_recipe("leached_acorn_meal")
	var cake := Recipes.get_recipe("acorn_cake")
	check(not Recipes.make(cake), "can't make cakes without meal")
	var start := GameClock.minutes
	Recipes.make(flour)
	Recipes.make(flour)
	Recipes.make(leach)
	Recipes.make(leach)
	check(Recipes.make(cake) and Inventory.count("acorn_cake") == 2, "acorns → flour → leached meal → 2 acorn cakes")
	check(GameClock.minutes - start == 60 + 60 + 120 + 120 + 90, "cooking takes time")
	check(FoodDB.energy("acorn_cake") > FoodDB.energy("miners_lettuce") * 3, "acorn cakes are real climbing food")
	check(Recipes.known_for("mortar").size() == 1, "one recipe at the mortar")


func test_spoilage() -> void:
	Inventory.remove("miners_lettuce", Inventory.count("miners_lettuce"))
	Inventory.add("miners_lettuce", 3)
	Inventory.add("black_oak_acorn", 2)
	GameClock.day_started.emit(2, 0, 1)
	check(Inventory.count("miners_lettuce") == 3, "lettuce is fine after one night")
	Inventory.add("miners_lettuce", 1) # a fresh one
	GameClock.day_started.emit(3, 0, 1)
	check(Inventory.count("miners_lettuce") == 1, "old lettuce spoils after two nights, the fresh one stays")
	check(Inventory.count("black_oak_acorn") == 2 and Larder.days_left("black_oak_acorn") == 12, "acorns in the pack keep 14 days")
	var stored := Granary.acorns
	for i in 30:
		GameClock.day_started.emit(4 + i, 0, 1)
	check(Granary.acorns == stored, "acorns in the chuckah never spoil")
	check(Inventory.count("black_oak_acorn") == 0, "acorns carried for a month spoil")
	check(Inventory.count("acorn_cake") == 0, "even acorn cakes spoil eventually")


func test_save_round_trip() -> void:
	Inventory.add("wild_strawberry", 2)
	var saved := {}
	for node: Node in [Gear, Granary, Recipes, QuestLog, Larder]:
		saved[node.name] = JSON.parse_string(JSON.stringify(node.save_data()))
	var gear_before := Gear.owned.duplicate()
	var stored := Granary.acorns
	new_game()
	Inventory.add("wild_strawberry", 2)
	for node: Node in [Gear, Granary, Recipes, QuestLog, Larder]:
		node.load_data(saved[node.name])
	check(Gear.owned == gear_before and Granary.acorns == stored, "gear and granary survive a save")
	check(QuestLog.is_completed("leonard_belay") and QuestLog.has_climbed("swan_slab") and QuestLog.is_unlocked("chuckah"), "quests survive a save")
	check(Recipes.knows("acorn_cake") and Recipes.times_made.get("acorn_cake") == 1, "recipes survive a save")
	check(Larder.days_left("wild_strawberry") == 2, "freshness survives a save")


func test_dialogue_and_minigame_scenes() -> void:
	var player: Player = load("res://scenes/player/player.tscn").instantiate()
	add_child(player)
	var npc: NPC = load("res://scenes/story/npc.tscn").instantiate()
	npc.character = QuestLog.get_character("dick_leonard")
	add_child(npc)
	npc.interact(player)
	await get_tree().process_frame
	var box: DialogueBox = find_box()
	check(box != null and not player.can_act, "talking opens a dialogue box and freezes the player")
	for i in 5:
		if find_box() == null:
			break
		find_box().press()
		await get_tree().process_frame
		await get_tree().process_frame
	check(find_box() == null and player.can_act, "dialogue closes and the player can move again")

	var box2 := DialogueBox.open(self)
	var result := [null]
	var ask := func(): result[0] = await box2.choose("Climb?", ["Climb", "Not yet"])
	ask.call()
	await get_tree().process_frame
	box2._cursor = 1
	box2.press()
	await get_tree().process_frame
	await get_tree().process_frame
	check(result[0] == 1, "choose() returns the picked option")
	box2.close()

	# One flick of the analog stick moves a menu cursor one step, not one per frame.
	var box3 := DialogueBox.open(self)
	box3.choose("Pick one", ["A", "B", "C", "D"])
	await get_tree().process_frame
	await get_tree().process_frame
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_Y
	for value in [1.0, 1.0, 0.9, 0.0, 1.0, 1.0]:
		stick.axis_value = value
		Input.parse_input_event(stick)
		Input.flush_buffered_events()
		await get_tree().process_frame
	check(box3._cursor == 2, "two stick flicks move the menu cursor two steps (at %d)" % box3._cursor)
	box3.press(false)
	await get_tree().process_frame
	box3.close()

	# A long list of choices (the stores, a campfire) stays on screen.
	var box4 := DialogueBox.open(self)
	var options := []
	for i in 9:
		options.append("Option %d for 12 food energy" % (i + 1))
	box4.choose("You're carrying 30 energy of food. What do you want?", options, "Clerk")
	await get_tree().process_frame
	await get_tree().process_frame
	var screen := get_viewport().get_visible_rect()
	var panel_rect := box4._panel.get_global_rect()
	var last_option: Control = box4._options_box.get_child(options.size() - 1)
	check(screen.encloses(panel_rect), "the dialogue box with 9 options fits the screen (%s)" % panel_rect)
	check(last_option.get_global_rect().end.y <= screen.end.y, "the last option is on screen (bottom %.0f)" % last_option.get_global_rect().end.y)
	box4.press(false)
	await get_tree().process_frame
	box4.close()

	var minigame: ClimbMinigame = load("res://scenes/climb/climb_minigame.tscn").instantiate()
	minigame.setup(APRON, 3)
	add_child(minigame)
	await get_tree().process_frame
	await get_tree().process_frame
	check(minigame.state.route == APRON, "climbing screen opens and draws")
	var done := [false]
	minigame.finished.connect(func(_s, _m): done[0] = true)
	minigame.state.retreat()
	minigame._events()
	# The result card comes up after the retreat plays, and can't be skipped at once.
	minigame._result_delay = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	minigame._result_age = 1.0
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	minigame._input(ev)
	check(done[0], "leaving the climbing screen reports the result")
	player.queue_free()
	npc.queue_free()


func find_box() -> DialogueBox:
	for child in get_tree().root.get_children():
		if child is DialogueBox and not child.is_queued_for_deletion():
			return child
	return null


## A simple bot: takes the cheapest reachable hold, places cams in cracks
## once it's two moves above protection, and eats at belays when tired.
func play(state: ClimbState, eats := true) -> void:
	var guard := 0
	while state.status == ClimbState.Status.CLIMBING and guard < 500:
		guard += 1
		if eats and state.is_at_belay() and state.stamina < 60:
			var foods := FoodDB.edible_in_inventory()
			if not foods.is_empty():
				state.eat(foods[0])
		if state.runout() >= 1 and state.hold_at(state.row, state.col).get("crack", false) and state.cams_left > 0:
			state.place_cam()
		state.move(cheapest_reachable(state))


func first_reachable(state: ClimbState) -> int:
	for dx in [0, -1, 1]:
		if not state.hold_at(state.row + 1, state.col + dx).is_empty():
			return dx
	return 0


func cheapest_reachable(state: ClimbState) -> int:
	var best := 0
	var best_score := 9999.0
	for dx in [-1, 0, 1]:
		var hold := state.hold_at(state.row + 1, state.col + dx)
		if hold.is_empty():
			continue
		# Prefer cracks when running out, otherwise cheap holds.
		var score: float = hold.cost - (6.0 if hold.crack and state.runout() >= 1 and state.cams_left > 0 else 0.0)
		if score < best_score:
			best = dx
			best_score = score
	return best
