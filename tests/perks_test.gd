extends Node
## Headless test of the perks: each one's unlock condition, its effect where
## it's hooked in (walking, forage, cooking, food, the climbing rules), the
## "New perk" message and Journal section, and saving and loading.
## Run: godot --headless --path . res://tests/perks_test.tscn
## Exit code is the number of failed checks.

const APRON := preload("res://data/routes/glacier_point_apron.tres")
const FLOUR := preload("res://data/recipes/acorn_flour.tres")
const CAKE := preload("res://data/recipes/acorn_cake.tres")
const TEA := preload("res://data/recipes/yerba_buena_tea.tres")
const KIT := {"climbing_shoes": 1, "chalk_bag": 1, "quickdraw": 5, "belay_device": 1}

var failures := 0
var _signalled: Array[String] = []


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	SaveManager.save_path = "user://perks_test_save.json"
	SaveManager.delete_save()
	Engine.time_scale = 20.0
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().process_frame
	await get_tree().process_frame
	Perks.unlocked.connect(func(perk: Dictionary) -> void: _signalled.append(perk.id))

	test_definitions()
	test_fresh_game(world)
	await test_muirs_stride(world)
	await test_enids_eye(world)
	test_tabuce_and_trail_cook()
	test_lamons_cellar()
	test_climbing_perks()
	await test_toast_and_journal(world)
	test_save_and_load()

	SaveManager.delete_save()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func test_definitions() -> void:
	check(Perks.PERKS.size() >= 6 and Perks.PERKS.size() <= 10, "6 to 10 perks (%d)" % Perks.PERKS.size())
	var ids := {}
	for perk: Dictionary in Perks.PERKS:
		ids[perk.id] = true
		var unlock: Dictionary = perk.unlock
		var ok: bool = perk.name != "" and perk.how != "" and perk.effect != "" and perk.flavor != "" and float(perk.amount) > 0.0
		if unlock.has("quest"):
			ok = ok and QuestLog.get_quest(unlock.quest) != null
		else:
			ok = ok and int(unlock.count) > 1
		check(ok, "%s has an unlock, an effect, a history line and a real quest or count" % perk.name)
	check(ids.size() == Perks.PERKS.size(), "perk ids are unique")


func test_fresh_game(world: Node) -> void:
	check(Perks.earned.is_empty() and Perks.stats.is_empty(), "a new game starts with no perks")
	for perk: Dictionary in Perks.PERKS:
		check(Perks.bonus(perk.id) == 0.0, "%s does nothing until it's earned" % perk.name)
	check(Perks.recipe_minutes(FLOUR) == FLOUR.minutes, "the mortar takes its usual time")
	var lines := _journal_lines()
	check("Perks: what the valley taught you (0 of %d)" % Perks.PERKS.size() in lines, "the Journal has a Perks section")
	check("Enid's Eye: Pick up 25 wild plants and berries. (0 of 25)" in lines, "a perk to earn says how, with progress")
	check(lines.any(func(l: String) -> bool: return l.begins_with("Lamon's Cellar:") and not "of 1)" in l), "a quest perk shows no count")


## The text of every line on the Journal page.
func _journal_lines() -> Array[String]:
	var journal: Journal = get_tree().get_first_node_in_group("journal")
	journal.open()
	var lines: Array[String] = []
	for label in journal._body.get_children():
		if label is Label:
			lines.append(label.text.strip_edges()) # checkbox lines leave room for the box
	journal.close()
	return lines


func test_muirs_stride(world: Node) -> void:
	var player: Player = world.player
	var speed := await _walk_speed(player)
	check(is_equal_approx(speed, Player.SPEED), "walking speed starts at %d (%.1f)" % [Player.SPEED, speed])
	for i in 13:
		GameClock.start_new_day()
	check(not Perks.has("muirs_stride") and Perks.stat("mornings") == 13, "13 mornings isn't enough for Muir's Stride")
	GameClock.start_new_day()
	check(Perks.has("muirs_stride") and "muirs_stride" in _signalled, "the 14th morning earns Muir's Stride (and says so)")
	speed = await _walk_speed(player)
	check(speed > Player.SPEED and speed <= Player.SPEED * 1.1, "Muir's Stride: a little faster (%.1f)" % speed)


func _walk_speed(player: Player) -> float:
	Input.action_press("move_right")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var speed := player.velocity.length()
	Input.action_release("move_right")
	await get_tree().physics_frame
	return speed


func test_enids_eye(world: Node) -> void:
	var forage: ForageSpawner = world.forage
	GameClock.season = GameClock.Season.SPRING
	await forage.respawn()
	var usual := forage.get_child_count()
	Perks.note("forage", 24)
	check(not Perks.has("enids_eye"), "24 finds isn't enough for Enid's Eye")
	# Picking one up for real counts too.
	var find: Forageable = forage.get_child(0)
	find.interact(world.player)
	check(Perks.stat("forage") == 25 and Perks.has("enids_eye"), "the 25th find earns Enid's Eye")
	await forage.respawn()
	check(forage.get_child_count() == usual + 1, "Enid's Eye: one more find each morning (%d, usually %d)" % [forage.get_child_count(), usual])
	var in_season := true
	for f: Forageable in forage.get_children():
		in_season = in_season and f.item.is_forageable_in(GameClock.season)
	check(in_season, "the extra find is in season")


func test_tabuce_and_trail_cook() -> void:
	var start := GameClock.minutes
	for i in 2:
		_make(CAKE)
	check(not Perks.has("tabuces_patience"), "two acorn meals isn't enough for Tabuce's Patience")
	check(GameClock.minutes - start == CAKE.minutes * 2, "cooking takes its usual time before the perk")
	_make(CAKE)
	check(Perks.has("tabuces_patience"), "the third acorn meal earns Tabuce's Patience")
	check(Perks.recipe_minutes(FLOUR) == 45 and Perks.recipe_minutes(CAKE) == CAKE.minutes and Perks.recipe_minutes(TEA) == TEA.minutes,
		"Tabuce's Patience: the mortar takes 45 min, not 60; the campfire is unchanged")
	start = GameClock.minutes
	_make(FLOUR)
	check(GameClock.minutes - start == 45, "grinding acorn flour now takes 45 minutes")
	# 4 dishes made so far; Trail Cook needs 12.
	for i in 7:
		_make(TEA)
	check(not Perks.has("trail_cook"), "11 dishes isn't enough for Trail Cook")
	_make(TEA)
	check(Perks.has("trail_cook"), "the 12th dish earns Trail Cook")


func _make(recipe: RecipeData) -> void:
	for id: String in recipe.inputs:
		Inventory.add(id, int(recipe.inputs[id]))
	Recipes.make(recipe)


func test_lamons_cellar() -> void:
	check(FoodDB.shelf_life("wild_strawberry") == 2, "strawberries keep 2 days")
	QuestLog.completed.append("lamon_winter")
	QuestLog.changed.emit()
	check(Perks.has("lamons_cellar"), "finishing Lamon's winter story earns Lamon's Cellar")
	check(FoodDB.shelf_life("wild_strawberry") == 3 and FoodDB.shelf_life("pilot_bread") == 61, "Lamon's Cellar: food keeps one more day")
	check(FoodDB.shelf_life("black_oak_acorn") == 15 and FoodDB.shelf_life("not_a_food") == 0, "foods that never spoil still never spoil")
	Inventory.remove("wild_strawberry", Inventory.count("wild_strawberry"))
	Inventory.add("wild_strawberry")
	check(Larder.days_left("wild_strawberry") == 3, "a fresh find keeps 3 days in the pack")
	Inventory.remove("wild_strawberry")


func test_climbing_perks() -> void:
	# Before: one pitch's rest, a crux window and a move, without the climbing perks.
	Inventory.add("acorn_cake", 2)
	var before := _climb_sample()

	QuestLog.completed.append("leonard_belay")
	QuestLog.changed.emit()
	check(Perks.has("leonards_belay"), "learning to belay from Dick Leonard earns Leonard's Belay")
	Perks.note("perfect_cruxes", 4)
	check(not Perks.has("steady_breath"), "4 perfect cruxes isn't enough for Steady Breath")
	Perks.note("perfect_cruxes")
	check(Perks.has("steady_breath"), "the 5th perfect crux earns Steady Breath")
	for id in ["firefall_slab", "swan_slab", "glacier_point_apron", "nutcracker", "higher_cathedral_spire"]:
		QuestLog.record_climb(id)
	check(not Perks.has("light_rack"), "5 ticks isn't enough for Light Rack")
	QuestLog.record_climb("royal_arches")
	check(Perks.has("light_rack"), "the 6th tick earns Light Rack")

	var after := _climb_sample()
	check(after.rest == before.rest + 3, "Leonard's Belay: 3 more stamina at a belay ledge (%d vs %d)" % [after.rest, before.rest])
	check(is_equal_approx(after.window, before.window + 0.03), "Steady Breath: a slightly wider crux (%.2f vs %.2f)" % [after.window, before.window])
	check(before.move_minutes == ClimbState.MINUTES_PER_MOVE and after.move_minutes == ClimbState.MINUTES_PER_MOVE - 1,
		"Light Rack: a move takes %d minutes, not %d" % [after.move_minutes, before.move_minutes])
	check(after.ate == FoodDB.energy("acorn_cake") + 2, "Trail Cook: an acorn cake on the wall gives 2 more (%d, not %d)" % [after.ate, FoodDB.energy("acorn_cake")])
	# Gentle: an unprepared climber with every perk still can't skip the gear.
	var bare := ClimbState.new(APRON, 2, 7, {})
	var shod := ClimbState.new(APRON, 2, 7, KIT)
	check(shod.crux_window() > bare.crux_window(), "gear still matters more than perks")


## Plays a few rules on a fixed Apron wall and returns what they gave.
func _climb_sample() -> Dictionary:
	var state := ClimbState.new(APRON, 2, 7, KIT)
	var result := {"window": state.crux_window()}
	for dx in [0, -1, 1]:
		if not state.hold_at(1, state.col + dx).is_empty():
			state.move(dx)
			break
	result.move_minutes = state.minutes
	state = ClimbState.new(APRON, 2, 7, KIT)
	state.stamina = 40
	state.eat("acorn_cake")
	result.ate = state.stamina - 40
	state.stamina = 40
	state._finish_pitch()
	result.rest = state.stamina - 40
	return result


func test_toast_and_journal(world: Node) -> void:
	check(not Perks.pending_toasts().is_empty() and Perks.pending_toasts()[0].begins_with("New perk: "),
		"earning a perk queues a \"New perk\" message (%s)" % [Perks.pending_toasts()])
	GameClock.paused = false
	var shown := false
	for i in 200:
		await get_tree().process_frame
		if world.hud.message_label.text.begins_with("New perk: "):
			shown = true
			break
	check(shown, "the message shows on the HUD (%s)" % world.hud.message_label.text)

	var lines := _journal_lines()
	check("Perks: what the valley taught you (%d of %d)" % [Perks.earned.size(), Perks.PERKS.size()] in lines, "the Journal counts your perks")
	check("Muir's Stride: You walk a little faster." in lines, "an earned perk shows its effect")
	check(lines.any(func(l: String) -> bool: return "John Muir walked" in l), "...and its line of history")
	check(lines.any(func(l: String) -> bool: return "Tabuce" in l) and not lines.any(func(l: String) -> bool: return "Tabuce" in l and "tribal review" in l), "Tabuce's perk is listed, with no review flag")


func test_save_and_load() -> void:
	var earned := Perks.earned.duplicate()
	var stats := Perks.stats.duplicate()
	SaveManager.save_game()
	Perks.start_new_game()
	check(Perks.earned.is_empty() and Perks.bonus("muirs_stride") == 0.0, "starting over forgets the perks")
	check(SaveManager.load_game(), "the save loads")
	check(Perks.earned == earned and Perks.stats == stats, "perks and their counts survive a save (%s)" % [Perks.earned])
	check(Perks.pending_toasts().is_empty(), "loading a save doesn't announce old perks again")
	# A save from before perks catches up quietly on what was already done.
	Perks.load_data({})
	check(Perks.has("lamons_cellar") and Perks.has("light_rack") and not Perks.has("muirs_stride") and Perks.pending_toasts().is_empty(),
		"an older save earns the perks its quests and ticks already earned, without messages")
