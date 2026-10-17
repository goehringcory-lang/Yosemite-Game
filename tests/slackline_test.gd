extends Node
## Headless test of the Camp 4 slackline: the balance rules, the six-pack of
## King Cobra for the first full walk (and only the first), and the sign at
## Camp 4 that opens it.
## Run: godot --headless --path . res://tests/slackline_test.tscn
## Exit code is the number of failed checks. Uses its own save file.

const DT := 1.0 / 60.0

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	await get_tree().process_frame
	SaveManager.save_path = "user://slackline_test_save.json"
	SaveManager.delete_save()
	Inventory.start_new_game()
	QuestLog.start_new_game()
	test_rules()
	await test_screen()
	await test_camp_4()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


## A steady hand: push against the lean, and against the way it's moving.
static func balance(state: SlacklineState) -> float:
	return clampf(-(state.lean * 2.5 + state.lean_speed * 0.8), -1.0, 1.0)


## Walks [param state] to the end with [param pilot] and returns the status.
static func run(state: SlacklineState, pilot: Callable) -> int:
	for i in int(SlacklineState.WALK_TIME * 4.0 / DT):
		state.step(DT, pilot.call(state))
		if state.status != SlacklineState.Status.WALKING:
			break
	return state.status


func test_rules() -> void:
	var idle := SlacklineState.new(1)
	check(run(idle, func(_s: SlacklineState) -> float: return 0.0) == SlacklineState.Status.FELL, "hands off, you fall")
	check(idle.progress < 0.5 and absf(idle.lean) == 1.0 and idle.fell_to != 0, "and early, off to one side (%d%%)" % idle.percent())
	var wrong := SlacklineState.new(2)
	check(run(wrong, func(s: SlacklineState) -> float: return signf(s.lean)) == SlacklineState.Status.FELL, "leaning into the tip throws you off faster")
	var wins := 0
	for seed in 20:
		var s := SlacklineState.new(seed)
		if run(s, balance) == SlacklineState.Status.WALKED:
			wins += 1
	check(wins == 20, "a steady hand walks the whole line every time (%d/20)" % wins)
	var timed := SlacklineState.new(3)
	run(timed, balance)
	check(timed.time >= SlacklineState.WALK_TIME and timed.time < SlacklineState.WALK_TIME * 2.0, "a walk takes about %d seconds (%.1f)" % [int(SlacklineState.WALK_TIME), timed.time])
	check(is_equal_approx(SlacklineState.new(4).sag(), 0.0), "the line doesn't sag at the tree")


func test_screen() -> void:
	var before := Inventory.count("king_cobra")
	var screen: SlacklineMinigame = load("res://scripts/slackline/slackline_minigame.gd").new()
	screen.setup(7)
	get_tree().root.add_child(screen)
	await get_tree().process_frame
	check(not screen.walked and screen.attempts == 0, "the screen opens on the intro card")
	screen.begin()
	run(screen.state, balance)
	screen._process(DT)
	check(screen.walked and screen.won_prize, "walking the whole line wins")
	check(Inventory.count("king_cobra") == before + 6, "a six-pack of King Cobra (%d)" % (Inventory.count("king_cobra") - before))
	check(QuestLog.is_unlocked(SlacklineMinigame.WON), "and it's remembered in the save")
	screen.begin()
	run(screen.state, balance)
	screen._process(DT)
	check(Inventory.count("king_cobra") == before + 6, "walking it again doesn't give another six-pack")
	var result := [null]
	screen.finished.connect(func(walked: bool) -> void: result[0] = walked)
	check(screen.minutes() == 2 * SlacklineMinigame.MINUTES_PER_WALK, "two walks took %d minutes" % screen.minutes())
	screen.leave()
	check(result[0] == true, "leaving reports the line walked")
	await get_tree().process_frame

	var again: SlacklineMinigame = load("res://scripts/slackline/slackline_minigame.gd").new()
	get_tree().root.add_child(again)
	await get_tree().process_frame
	check(again.walked, "next visit, the line's already been walked")
	again.leave()
	await get_tree().process_frame


func test_camp_4() -> void:
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(world)
	await get_tree().process_frame
	GameClock.paused = true
	world._enter_region("yosemite_village", "camp_4")
	await get_tree().process_frame
	var spot: Node = world.region.find_child("SlacklineInfo", true, false)
	check(spot is SlacklineSpot, "the Camp 4 slackline can be walked")
	if spot is SlacklineSpot:
		check(spot.title == "Slackline" and "Camp 4" in spot.text, "and it keeps its sign")
		check(spot.get_prompt() == "Walk: Slackline", "the prompt says so")
	var lines: PackedStringArray = load("res://data/characters/visitors/visitor_dirtbag.tres").idle_lines
	check(Array(lines).any(func(l: String) -> bool: return "six-pack" in l), "a Camp 4 climber mentions the six-pack")
	world.queue_free()
	await get_tree().process_frame
