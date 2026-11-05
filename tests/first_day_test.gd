extends Node
## Headless test of the guided first day (FirstDay): a new game starts it on
## "walk", each lesson is marked off by doing it and hands over to the next,
## the card names the right buttons and the arrow finds what a lesson is
## about, the evening lessons wait for evening, the Tips setting hides it, and
## a save keeps it (an older save, from before the guide, loads finished).
## Run: godot --headless --path . res://tests/first_day_test.tscn
## Exit code is the number of failed checks.

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	SaveManager.save_path = "user://first_day_test_save.json"
	SaveManager.delete_save()
	Settings.prompts = Settings.Prompts.KEYBOARD
	Engine.time_scale = 8.0
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var guide: FirstDay = world.get_node("FirstDay")

	check(FirstDay.new().is_over(), "a guide that never started (an older save) is already over")
	check(not guide.is_over(), "a new game starts the first day")
	await _frames(3)
	check(guide.current() == "walk", "the first lesson is walking (got %s)" % guide.current())
	check(guide.text_for("walk") == "[WASD] Walk around camp", "it names the walking keys")
	Settings.prompts = Settings.Prompts.GAMEPAD
	check(guide.text_for("walk") == "[Stick] Walk around camp", "and the stick on a gamepad")
	check(guide.text_for("backpack") == "[Y] then [RB] Backpack", "and the pad's way into the backpack")
	Settings.prompts = Settings.Prompts.KEYBOARD
	check(guide._card != null and guide._card.modulate.a >= 0.0, "the card is built under the clock")

	# walking marks "walk"
	Input.action_press("move_left")
	await _seconds(1.5)
	Input.action_release("move_left")
	check("walk" in guide.done, "walking a few steps finishes the first lesson (walked %.0f px, can act %s)" % [guide._walked, world.player.can_act])
	await _seconds(1.4)
	check(guide.current() == "talk", "then it's Galen Clark (got %s)" % guide.current())
	await _seconds(0.5)
	var clark: Node = guide._target
	check(clark is NPC and clark.character.id == "galen_clark", "and the arrow finds Clark")

	QuestLog.talk_to("galen_clark")
	await _seconds(1.4)
	check("talk" in guide.done, "hearing Clark out finishes it")
	check(guide.current() == "gather", "then gathering food (got %s)" % guide.current())
	await _seconds(0.5)
	check(guide._target is Forageable, "and the arrow finds something to pick up")
	var start := Perks.stat("forage")
	check(guide.text_for("gather").ends_with("%d/3" % mini(start, 3)), "the card counts what's gathered")
	Perks.note("forage", 3)
	await _seconds(1.4)
	check(guide.current() == "backpack", "three finds, then the backpack (got %s)" % guide.current())
	var journal: Journal = get_tree().get_first_node_in_group("journal")
	journal.open(Journal.Tab.BACKPACK)
	await _frames(3)
	check("backpack" in guide.done, "opening the backpack finishes it")
	check(guide._card.modulate.a < 0.5 or not guide._shown(), "the card stays out of the way of the book")
	journal.show_tab(Journal.Tab.QUESTS)
	await _frames(3)
	check("quests" in guide.done, "and the Quests tab the next one")
	journal.close()
	await _seconds(1.4)
	check(guide.current() == "run", "then running (got %s)" % guide.current())
	check(guide.text_for("run") == "Hold [Shift] to run", "with the run key")
	Input.action_press("run")
	Input.action_press("move_right")
	await _seconds(2.5)
	Input.action_release("move_right")
	Input.action_release("run")
	check("run" in guide.done, "running a moment finishes it")
	await _seconds(1.4)
	check(guide.current() == "head_out", "then the way to Curry Village (got %s)" % guide.current())
	await _seconds(0.5)
	check(guide._target is RegionExit and guide._target.target_region == "curry_village", "and the arrow finds the gate")

	# the evening lessons wait for evening
	check(not guide._ready_for("sleep"), "bed waits for the evening")
	GameClock.minutes = FirstDay.BED_HOUR * 60 + 5
	check(guide._ready_for("sleep"), "and comes up after %d:00" % FirstDay.BED_HOUR)
	check(guide.text_for("sleep") == "[E] Sleep in your tent", "at home it's the tent")
	check(guide._find_target("sleep") != null, "and the arrow finds the tent")
	GameClock.day_started.emit(GameClock.day + 1, GameClock.season, GameClock.year)
	check("sleep" in guide.done, "a new morning finishes it")
	check(not guide._ready_for("fish"), "fishing waits for a rod")
	Gear.add(Fishing.ROD)
	check(guide._ready_for("fish"), "and comes up once there is one")
	Perks.note("casts")
	await _frames(2)
	check("fish" in guide.done, "a cast finishes it")

	# Tips off hides the card
	Settings.tips = false
	await _frames(3)
	check(not guide._shown(), "with Tips off the card isn't shown")
	Settings.tips = true

	# saved and loaded
	var saved := guide.save_data()
	var fresh := FirstDay.new()
	fresh.start_new_game()
	fresh.load_data(saved)
	check(fresh.done == guide.done, "a save keeps the lessons done")
	fresh.load_data({})
	check(fresh.is_over(), "an empty entry loads as finished")
	fresh.free()
	for id in FirstDay.LESSONS:
		guide.mark(id)
	await _seconds(1.5)
	check(guide.is_over() and guide.current() == "", "once every lesson is done the guide is over")

	SaveManager.delete_save()
	print("OK: %d failure(s)" % failures if failures == 0 else "FAILED: %d failure(s)" % failures)
	get_tree().quit(failures)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout
