extends Node
## Headless test of the 5 quality-of-life upgrades:
##   1. Auto-run setting (Settings.auto_run + PauseMenu)
##   2. Remembered gift favorites (Friendship.known_loves + GiftGiving + Journal)
##   3. Campfire pot "Same as last time" quick-fill (Cooking.last_pot + Station.pot_menu)
##   4. Overnight spoilage warning before sleeping (Larder.spoiling_tonight + Tent)
##   5. Backpack spoilage/reservation notes & makeable-first station recipes
## Run: godot --headless --path . res://tests/qol_test.tscn
## Exit code is the number of failed checks.

const SETTINGS_PATH := "user://qol_test_settings.cfg"

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	await get_tree().process_frame
	Settings.path = SETTINGS_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	SaveManager.save_path = "user://qol_test_save.json"
	SaveManager.delete_save()

	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	GameClock.paused = true

	test_auto_run()
	test_remembered_favorites(world)
	test_repeat_pot()
	await test_spoilage_warning(world)
	test_backpack_and_recipes(world)

	world.queue_free()
	SaveManager.delete_save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func _empty_pack() -> void:
	Inventory.items.clear()
	Inventory.changed.emit()
	Larder.load_data({})


func test_auto_run() -> void:
	Settings.load_settings()
	check(not Settings.auto_run, "auto-run defaults to off")
	var pause: PauseMenu = get_tree().get_first_node_in_group("pause_menu")
	check(pause._setting_value(PauseMenu.Setting.AUTO_RUN) == "‹  Off  ›", "pause menu shows Auto-run Off")
	pause.change_setting(PauseMenu.Setting.AUTO_RUN, 1)
	check(Settings.auto_run and pause._setting_value(PauseMenu.Setting.AUTO_RUN) == "‹  On  ›", "toggling Auto-run turns it on")
	Settings.reset_defaults()
	check(not Settings.auto_run, "reset_defaults puts auto-run back to off")
	Settings.load_settings()
	check(Settings.auto_run, "auto-run persists in settings.cfg")
	pause.change_setting(PauseMenu.Setting.AUTO_RUN, 1)
	check(not Settings.auto_run, "and toggles back off")


func test_remembered_favorites(world: Node) -> void:
	_empty_pack()
	Friendship.start_new_game()
	Inventory.add("yerba_buena_tea", 2)
	Inventory.add("roasted_morels", 1)
	check(not Friendship.knows_love("galen_clark", "yerba_buena_tea"), "a favorite isn't known before gifting it")
	check(not GiftGiving.choice_label("galen_clark", "yerba_buena_tea").contains("Favorite"), "undiscovered favorite isn't tagged in gift menu")

	var thanks := Friendship.give("galen_clark", "yerba_buena_tea")
	check(thanks != "" and Friendship.knows_love("galen_clark", "yerba_buena_tea"), "gifting a loved item records it in known_loves")
	check(not Friendship.knows_love("galen_clark", "roasted_morels"), "other loved items stay undiscovered")
	check(GiftGiving.choice_label("galen_clark", "yerba_buena_tea").contains("Favorite"), "discovered favorite is tagged in gift menu")
	check(not GiftGiving.choice_label("galen_clark", "roasted_morels").contains("Favorite"), "undiscovered favorite stays untagged")

	# Survives save/load
	var saved: Dictionary = JSON.parse_string(JSON.stringify(Friendship.save_data()))
	Friendship.start_new_game()
	check(Friendship.known_loves_for("galen_clark").is_empty(), "start_new_game clears known_loves")
	Friendship.load_data(saved)
	check(Friendship.knows_love("galen_clark", "yerba_buena_tea"), "known_loves survives save/load")

	# Shows in Journal Friends list
	var journal: Journal = world.get_node_or_null("Journal")
	if journal == null:
		journal = get_tree().get_first_node_in_group("journal")
	journal.open(Journal.Tab.JOURNAL)
	var texts := PackedStringArray()
	for child in journal._body.get_children():
		if child is Label:
			texts.append(child.text)
	journal.close()
	check(Array(texts).any(func(t: String) -> bool: return "Loves:" in t and "Yerba Buena Tea" in t),
		"Friends section in Journal lists discovered favorites")


func test_repeat_pot() -> void:
	_empty_pack()
	Cooking.start_new_game()
	Inventory.add("california_blackberry", 4)
	Inventory.add("whitebark_raspberry", 2)
	check(not Cooking.can_repeat_last_pot(), "nothing to repeat before cooking")
	check(not "repeat" in Station.pot_menu([]).actions, "no Same as last time before cooking")

	var pot := ["california_blackberry", "california_blackberry", "whitebark_raspberry"]
	var meal := Cooking.cook(pot)
	check(meal != "" and Cooking.last_pot == pot, "cooking remembers the last pot")
	check(Cooking.can_repeat_last_pot(), "can_repeat_last_pot is true when enough ingredients remain")

	var menu := Station.pot_menu([])
	check(menu.actions.size() > 0 and menu.actions[0] == "repeat" and menu.options[0] == "Same as last time",
		"Same as last time appears at the top of the empty pot menu")
	check(menu.details[0] != null and menu.details[0].title == "Simmered Berries",
		"Same as last time carries the dish preview card")
	check(not "repeat" in Station.pot_menu(["california_blackberry"]).actions,
		"Same as last time hides once the pot already has ingredients")

	# Cook it a second time: now 0 blackberries left, so can_repeat_last_pot becomes false
	Cooking.cook(Cooking.last_pot)
	check(not Cooking.can_repeat_last_pot(), "can_repeat_last_pot turns false when out of ingredients")
	check(not "repeat" in Station.pot_menu([]).actions, "and Same as last time disappears from the menu")


func test_spoilage_warning(world: Node) -> void:
	_empty_pack()
	Inventory.add("lamon_apple", 2)
	check(Larder.spoiling_tonight().is_empty() and Larder.spoiling_summary() == "",
		"fresh apples don't spoil tonight")

	var tent: Node = world.region.entities.get_node_or_null("Tent")
	var slept := [false]
	var on_sleep := func() -> void: slept[0] = true
	tent.sleep_requested.connect(on_sleep, CONNECT_ONE_SHOT)
	# Disconnect world's real sleep handler briefly or test on a standalone Tent instance
	var test_tent: Node = load("res://scenes/objects/tent.tscn").instantiate()
	add_child(test_tent)
	var test_slept := [false]
	test_tent.sleep_requested.connect(func() -> void: test_slept[0] = true)
	test_tent.interact(world.player)
	check(test_slept[0], "tent sleeps immediately when nothing spoils tonight")

	# Now set 2 strawberries to spoil tonight (1 day left)
	Inventory.add("wild_strawberry", 2)
	Larder.batches["wild_strawberry"] = [1, 1]
	check(Larder.spoiling_tonight().get("wild_strawberry", 0) == 2, "spoiling_tonight counts units with 1 day left")
	check(Larder.spoiling_summary() == "2 Wild Strawberries", "spoiling_summary formats cleanly (%s)" % Larder.spoiling_summary())

	test_slept[0] = false
	test_tent.interact(world.player)
	await get_tree().process_frame
	var box: DialogueBox = get_tree().get_first_node_in_group("dialogue_box")
	check(box != null and "2 Wild Strawberries" in box._text_label.text and not test_slept[0],
		"tent warns before sleeping when food will spoil tonight")
	if box:
		# Cancel ("Not yet") should not sleep
		box._answer = -1
		await get_tree().process_frame
		await get_tree().process_frame
	check(not test_slept[0], "backing out of the warning cancels sleep")
	test_tent.queue_free()


func test_backpack_and_recipes(world: Node) -> void:
	_empty_pack()
	Inventory.add("wild_strawberry", 3)
	Larder.batches["wild_strawberry"] = [1, 3, 3]
	var journal: Journal = get_tree().get_first_node_in_group("journal")
	var slot := journal._carried("wild_strawberry")
	check("spoils tonight" in slot.facts, "Backpack labels 1-day-left food as spoils tonight (%s)" % slot.facts)

	# Reserved note for a board request (degnan_strawberries asks for 3 wild_strawberry)
	BoardRequests.start_new_game()
	BoardRequests.taken["degnan_strawberries"] = Friendship.today()
	var reserved_slot := journal._carried("wild_strawberry")
	check("3 needed for a board note" in reserved_slot.facts,
		"Backpack tags items reserved for a board note (%s)" % reserved_slot.facts)
	BoardRequests.start_new_game()

	# Makeable-first recipe sorting
	_empty_pack()
	Recipes.learn("acorn_cake")
	Recipes.learn("yerba_buena_tea")
	Inventory.add("yerba_buena", 2)
	var known := Recipes.known_for("campfire")
	var sorted := Station.sorted_recipes(known)
	check(sorted.size() >= 2 and Recipes.can_make(sorted[0]) and sorted[0].id == "yerba_buena_tea",
		"Station.sorted_recipes puts makeable recipes ahead of unmakeable ones")
