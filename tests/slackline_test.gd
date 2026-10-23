extends Node
## Headless test of the Camp 4 slacklines: the balance rules on each line,
## the warnings before a buck or a gust, flow, tricks and medals, the screen
## (picking a line, the six-pack of King Cobra for the first full walk of the
## Camp 4 line and only the first, best scores, the long line opening), the
## Slackliner's Feet perk, and the sign at Camp 4 that opens it all.
## Run: godot --headless --path . res://tests/slackline_test.tscn
## Exit code is the number of failed checks. Uses its own save file.

const DT := 1.0 / 60.0
const SWAN_SLAB := preload("res://data/routes/swan_slab.tres")
const KIT := {"climbing_shoes": 1, "chalk_bag": 1, "quickdraw": 5, "belay_device": 1}

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
	Perks.start_new_game()
	test_rules()
	test_warnings()
	test_flow_and_tricks()
	test_medals()
	await test_screen()
	test_perk()
	await test_camp_4()
	SaveManager.delete_save()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


## A steady hand: push against the lean, and against the way it's moving.
static func balance(state: SlacklineState) -> float:
	return clampf(-(state.lean * 2.5 + state.lean_speed * 0.8), -1.0, 1.0)


## Walks [param state] to the end with [param pilot] and returns the status.
## [param tricks] starts every trick it can.
static func run(state: SlacklineState, pilot: Callable, tricks := false) -> int:
	for i in int(200.0 / DT):
		if tricks and state.can_trick():
			state.start_trick()
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
	for l: Dictionary in SlacklineState.LINES:
		var wins := 0
		for seed in 20:
			var s := SlacklineState.new(seed, l.id)
			if run(s, balance) == SlacklineState.Status.WALKED:
				wins += 1
		check(wins == 20, "a steady hand walks %s every time (%d/20)" % [l.name, wins])
	var times := []
	for l: Dictionary in SlacklineState.LINES:
		var timed := SlacklineState.new(3, l.id)
		run(timed, balance)
		times.append(timed.time)
		check(timed.time >= float(l.walk_time) and timed.time < float(l.walk_time) * 2.0, "%s takes about %d seconds (%.1f)" % [l.name, int(l.walk_time), timed.time])
	check(times[0] < times[1] and times[1] < times[2], "each line is longer than the last")
	check(is_equal_approx(SlacklineState.new(4).sag(), 0.0), "the line doesn't sag at the tree")
	check(SlacklineState.line_by_id("nope").id == "camp4", "an unknown line is the Camp 4 line")


func test_warnings() -> void:
	# a buck is felt coming, on the side it throws you
	var s := SlacklineState.new(5)
	s.progress = 0.3
	var seen := {}
	for i in int(20.0 / DT):
		var w := s.warning()
		s.step(DT, balance(s))
		for e in s.take_events():
			if e.kind == "buck" and not w.is_empty() and w.kind == "buck":
				seen[w.side == e.side] = true
		if s.status != SlacklineState.Status.WALKING:
			break
	check(seen.get(true, false) and not seen.get(false, false), "every buck is warned of, on the side it throws you")
	# only the long line gusts
	var calm := SlacklineState.new(6, "camp4")
	var windy := SlacklineState.new(6, "long")
	var gusts := [0, 0]
	for st in [calm, windy]:
		st.progress = 0.2
		for i in int(30.0 / DT):
			st.step(DT, balance(st))
			for e in st.take_events():
				if e.kind == "gust":
					gusts[0 if st == calm else 1] += 1
			if st.status != SlacklineState.Status.WALKING:
				break
	check(gusts[0] == 0 and gusts[1] >= 2, "the wind blows on the long line only (%d gusts in 30 s)" % gusts[1])
	# leaning into a warned buck before it lands keeps you steadier
	var met := _buck_test(true)
	var ignored := _buck_test(false)
	check(met < ignored, "meeting a buck you were warned of keeps you steadier (%.2f vs %.2f)" % [met, ignored])


## How far a hard buck throws you, with or without leaning into it early.
func _buck_test(meet: bool) -> float:
	var s := SlacklineState.new(7)
	s.progress = 0.5
	s.lean = 0.0
	s.lean_speed = 0.0
	s._buck_side = 1.0
	s._buck_kick = 1.2
	s._next_buck = SlacklineState.BUCK_WARN
	var worst := 0.0
	for i in int(1.2 / DT):
		var push := balance(s)
		var w := s.warning()
		# the last moments before it lands: lean against it
		if meet and not w.is_empty() and float(w.t) > 0.6:
			push = -1.0
		s.step(DT, push)
		worst = maxf(worst, absf(s.lean))
	return worst


func test_flow_and_tricks() -> void:
	var s := SlacklineState.new(8, "short")
	check(s.flow() == 1, "flow starts at x1")
	s.steady_time = SlacklineState.FLOW_STEPS[0]
	check(s.flow() == 2, "steady for a while: x2")
	s.steady_time = SlacklineState.FLOW_STEPS[1]
	check(s.flow() == 3, "and longer: x3")
	s.lean = SlacklineState.STEADY_LEAN + 0.05
	s._score_balance(DT)
	check(s.flow() == 1 and s.wobbles == 1, "a wobble starts flow over")
	# tricks need you steady, and some way along
	var t := SlacklineState.new(9, "camp4")
	check(not t.start_trick(), "no trick on the first steps")
	t.progress = 0.3
	t.lean = SlacklineState.CENTER + 0.05
	check(not t.start_trick(), "no trick while you're wobbling")
	t.lean = 0.0
	t.lean_speed = 0.0
	t.steady_time = SlacklineState.FLOW_STEPS[0]
	check(t.start_trick() and t.trick.id == "drop_knee", "steady: the first trick is a drop knee")
	var at := t.progress
	while not t.trick.is_empty():
		t.step(DT, balance(t))
	check(is_equal_approx(t.progress, at), "you don't walk on during a trick")
	check(t.tricks_landed == 1 and t.trick_points == 150 * 2, "landed at x2 flow: %d points" % t.trick_points)
	check(not t.can_trick(), "a rest before the next")
	var events := t.take_events().map(func(e: Dictionary) -> String: return e.kind)
	check("trick" in events, "landing a trick is an event")
	# bailing a trick when you wobble
	var b := SlacklineState.new(10, "camp4")
	b.progress = 0.3
	b.lean = 0.0
	b.lean_speed = 0.0
	b.start_trick()
	b.lean = SlacklineState.STEADY_LEAN + 0.02
	b.step(DT, 0.0)
	check(b.trick.is_empty() and b.tricks_landed == 0 and b.next_trick == 0, "wobble mid-trick and you bail it")
	# spacing: tricks can't be strung forever
	var most := 0
	for seed in 10:
		var r := SlacklineState.new(seed, "camp4")
		run(r, balance, true)
		most = maxi(most, r.tricks_landed)
	check(most > 2 and most <= int(1.0 / SlacklineState.TRICK_SPACING) + 1, "a line holds a handful of tricks, not endless ones (%d)" % most)


func test_medals() -> void:
	var l := SlacklineState.line_by_id("camp4")
	check(SlacklineState.medal_for(l, 99999, false) == 0, "no medal without crossing")
	check(SlacklineState.medal_for(l, 0, true) == 1, "crossing is bronze")
	check(SlacklineState.medal_for(l, l.silver, true) == 2 and SlacklineState.medal_for(l, l.gold, true) == 3, "silver and gold by score")
	for line: Dictionary in SlacklineState.LINES:
		var plain := 0
		var trick := 0
		for seed in 10:
			var a := SlacklineState.new(seed, line.id)
			run(a, balance)
			plain = maxi(plain, a.medal())
			var b := SlacklineState.new(seed, line.id)
			run(b, balance, true)
			trick = maxi(trick, b.medal())
		check(plain < 3 and trick == 3, "%s: steady walking alone isn't gold, tricks with flow are (%d, %d)" % [line.name, plain, trick])


func test_screen() -> void:
	var before := Inventory.count("king_cobra")
	var screen: SlacklineMinigame = load("res://scripts/slackline/slackline_minigame.gd").new()
	screen.setup(7)
	get_tree().root.add_child(screen)
	await get_tree().process_frame
	check(not screen.walked and screen.attempts == 0 and screen._phase == SlacklineMinigame.Phase.SELECT, "the screen opens on the line picker")
	check(SlacklineState.LINES[screen._chosen].id == "short", "it offers the short line first")
	check(not SlacklineMinigame.is_open("long") and not screen.begin("long"), "the long line isn't strung yet")
	check(screen.begin("camp4") and screen._phase == SlacklineMinigame.Phase.READY, "picking the Camp 4 line steps you on")
	screen.go()
	await _walk(screen)
	check(screen.walked and screen.won_prize and screen.prize_now, "walking the whole line wins")
	check(Inventory.count("king_cobra") == before + 6, "a six-pack of King Cobra (%d)" % (Inventory.count("king_cobra") - before))
	check(QuestLog.is_unlocked(SlacklineMinigame.WON), "and it's remembered in the save")
	check(screen._phase == SlacklineMinigame.Phase.RESULT and screen.last_medal >= 1, "the results card shows a medal")
	check(SlacklineMinigame.best_for("camp4") == screen.state.score and screen.new_best, "the score is kept as the best (%d)" % SlacklineMinigame.best_for("camp4"))
	check(SlacklineMinigame.medal_for("camp4") == screen.last_medal, "and the medal")
	check(SlacklineMinigame.is_open("long"), "the long line opens")
	check(Perks.stat("slackline_crossings") == 1, "the crossing is counted")
	screen.begin("camp4")
	screen.go()
	await _walk(screen)
	check(Inventory.count("king_cobra") == before + 6 and not screen.prize_now, "walking it again doesn't give another six-pack")
	# a worse walk doesn't lower the best
	var best := SlacklineMinigame.best_for("camp4")
	screen.begin("camp4")
	screen.go()
	screen._process(DT)
	Input.action_press("ui_cancel")
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	screen._input(esc)
	Input.action_release("ui_cancel")
	check(screen.state.status == SlacklineState.Status.FELL, "Esc steps off the line")
	for i in 120:
		screen._process(DT)
	check(screen._phase == SlacklineMinigame.Phase.RESULT and screen.last_medal == 0, "stepping off is no medal")
	check(SlacklineMinigame.best_for("camp4") == best, "and doesn't touch the best")
	var result := [null]
	screen.finished.connect(func(walked: bool) -> void: result[0] = walked)
	check(screen.minutes() == 3 * SlacklineMinigame.MINUTES_PER_WALK, "three walks took %d minutes" % screen.minutes())
	screen.leave()
	check(result[0] == true, "leaving reports the line walked")
	await get_tree().process_frame

	var again: SlacklineMinigame = load("res://scripts/slackline/slackline_minigame.gd").new()
	get_tree().root.add_child(again)
	await get_tree().process_frame
	check(again.walked, "next visit, the line's already been walked")
	check(again.begin("long"), "and the long line can be walked")
	again.leave()
	await get_tree().process_frame


## Walks the screen's line with a steady hand, the way the screen does each
## frame, until the walk ends.
func _walk(screen: SlacklineMinigame) -> void:
	var s := screen.state
	for i in int(200.0 / DT):
		if s.can_trick():
			s.start_trick()
		s.step(DT, balance(s))
		for e in s.take_events():
			screen._on_event(e)
		if s.status != SlacklineState.Status.WALKING:
			break
	await get_tree().process_frame


func test_perk() -> void:
	var swan := ClimbState.new(SWAN_SLAB, 2, 7, KIT)
	var costs := _slab_costs(swan)
	Perks.note("slackline_crossings", 5 - Perks.stat("slackline_crossings") - 1)
	check(not Perks.has("slackliners_feet"), "4 crossings isn't enough for Slackliner's Feet")
	Perks.note("slackline_crossings")
	check(Perks.has("slackliners_feet"), "the 5th crossing earns Slackliner's Feet")
	var after := _slab_costs(ClimbState.new(SWAN_SLAB, 2, 7, KIT))
	var ok := true
	for i in costs.size():
		ok = ok and after[i] == maxi(costs[i] - 1, 1)
	check(ok and not costs.is_empty(), "Slackliner's Feet: slab moves cost 1 less (%s, was %s)" % [after, costs])
	check(not Perks.record("slackline_best_short", 0) and Perks.record("slackline_best_short", 10) and not Perks.record("slackline_best_short", 5),
		"Perks.record keeps the highest")


## What each hold on the first rows of [param state]'s pitch costs.
func _slab_costs(state: ClimbState) -> Array[int]:
	var out: Array[int] = []
	for r in range(1, 4):
		for c in 5:
			if not state.hold_at(r, c).is_empty():
				out.append(state.move_cost(r, c))
	return out


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
