extends Node
## Headless test of the story systems: quests, gear, food, the chuckah,
## recipes, and the climbing minigame.
## Run: godot --headless --path . res://tests/story_test.tscn
## Exit code is the number of failed checks.

const APRON := preload("res://data/routes/glacier_point_apron.tres")
const SWAN := preload("res://data/routes/swan_slab.tres")

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
	var lines := QuestLog.talk_to("dick_leonard")
	check(QuestLog.active.has("leonard_belay") and lines.size() == 4, "Dick Leonard offers his quest")
	lines = QuestLog.talk_to("dick_leonard")
	check(lines.size() == 1 and "Swan Slab" in lines[0].text, "reminder while the step isn't done")
	var state := ClimbState.new(SWAN, Gear.count("cam"), 1)
	play(state)
	check(state.status == ClimbState.Status.TOPPED_OUT, "Swan Slab top rope always tops out")
	QuestLog.record_climb("swan_slab")
	QuestLog.talk_to("dick_leonard")
	check(QuestLog.active.get("leonard_belay") == 1, "climbing Swan Slab advances to the food step")
	Inventory.add("miners_lettuce", 4)
	lines = QuestLog.talk_to("dick_leonard")
	check(QuestLog.is_completed("leonard_belay"), "carrying 32 energy of lettuce finishes the quest")
	check(Gear.count("rope") == 1 and Gear.count("harness") == 1 and Gear.count("cam") == 2, "reward: rope, harness, 2 cams")
	check("Received Rope, Harness, 2 Cams" in lines[-1].text, "reward line: %s" % lines[-1].text)
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
	var hungry := 0
	for seed in 20:
		var state := ClimbState.new(APRON, 2, seed)
		play(state, false)
		if state.status == ClimbState.Status.TOPPED_OUT:
			hungry += 1
	check(hungry < tops, "climbing without eating is harder (%d of 20 topped out)" % hungry)


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

	var minigame: ClimbMinigame = load("res://scenes/climb/climb_minigame.tscn").instantiate()
	minigame.setup(APRON, 3)
	add_child(minigame)
	await get_tree().process_frame
	await get_tree().process_frame
	check(minigame.state.route == APRON, "climbing screen opens and draws")
	var done := [false]
	minigame.finished.connect(func(_s, _m): done[0] = true)
	minigame.state.retreat()
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
