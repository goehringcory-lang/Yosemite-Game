extends Node
## Plays every route on the real climbing screen, frame by frame, the way a
## player would (a bot presses the keys' actions through the screen's own
## handlers, resolves crux checks and nights), and checks it tops out, draws
## every phase without errors, and reports once.
## Run: godot --headless --path . res://tests/climb_screen_test.tscn

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	await get_tree().process_frame
	await test_controls()
	for r in Guidebook.routes():
		await play_route(r)
	print("\nOK: %d failure(s)" % failures)
	get_tree().quit(failures)


## The keys do what they say: arrows climb, Space protects, Shift + arrow jugs
## a fixed rope, E chalks, and Esc asks before retreating.
func test_controls() -> void:
	var nose: RouteData = load("res://data/routes/the_nose.tres")
	Gear.owned = {"climbing_shoes": 1, "chalk_bag": 1, "harness": 1, "quickdraw": 6, "rope": 1, "cam": 10, "aiders": 2, "ascenders": 2, "haul_bag": 1, "portaledge": 1}
	Inventory.items.clear()
	Inventory.add("acorn_cake", 4)
	GameClock.paused = true
	var game: ClimbMinigame = load("res://scenes/climb/climb_minigame.tscn").instantiate()
	game.setup(nose, 6)
	add_child(game)
	await get_tree().process_frame
	check(game._phase == ClimbMinigame.Phase.INTRO, "the route card comes first")
	press(game, "move_up")
	check(game.state.row == 0, "nothing moves while the card is up")
	press(game, "interact")
	check(game._phase == ClimbMinigame.Phase.CLIMB, "E starts the climb")
	press(game, "interact")
	check(Inventory.count("acorn_cake") == 4 and game.state.stamina == ClimbState.MAX_STAMINA, "a second tap of E doesn't eat at full stamina")
	game._move_t = 1.0
	Input.action_press("assist")
	var before := game.state.jug_moves
	for a in ["move_up", "move_left", "move_right"]:
		game._move_t = 1.0
		press(game, a)
		if game.state.jug_moves > before:
			break
	Input.action_release("assist")
	check(game.state.jug_moves == before + 1, "Shift + an arrow jugs the Nose's fixed rope")
	game._move_t = 1.0
	var row := game.state.row
	var moved := false
	for a in ["move_up", "move_left", "move_right"]:
		game._move_t = 1.0
		press(game, a)
		moved = moved or game.state.row > row
		if moved:
			break
	check(moved, "an arrow climbs")
	game._move_t = 1.0
	press(game, "interact")
	check(game.state.chalked_this_pitch, "E chalks up on the wall")
	press(game, "ui_cancel")
	check(game._phase == ClimbMinigame.Phase.PAUSE, "Esc asks before retreating")
	press(game, "ui_cancel")
	check(game._phase == ClimbMinigame.Phase.CLIMB and game.state.status == ClimbState.Status.CLIMBING, "Esc again keeps climbing")
	var finished := [false]
	game.finished.connect(func(_ok, _minutes): finished[0] = true)
	press(game, "ui_cancel")
	press(game, "interact")
	check(game.state.status == ClimbState.Status.RETREATED, "Esc, then E, retreats")
	# The result card can't be skipped: not while the retreat plays, and not in its first half second.
	press(game, "interact")
	press(game, "ui_cancel")
	check(not finished[0] and game._phase != ClimbMinigame.Phase.RESULT, "taps during the retreat don't skip the result card")
	game._result_delay = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	check(game._phase == ClimbMinigame.Phase.RESULT, "the result card comes up")
	press(game, "interact")
	check(not finished[0], "a tap right as the result card comes up doesn't dismiss it")
	game._result_age = 1.0
	press(game, "use_tool")
	check(finished[0], "Space leaves the result card")
	game.queue_free()
	await get_tree().process_frame
	await test_screen_details()


## Smaller screen behavior: Space on the route card, the crux meter's grace,
## the late-start card, and the toolbar next to the hints.
func test_screen_details() -> void:
	var firefall: RouteData = load("res://data/routes/firefall_slab.tres")
	Gear.owned = {"climbing_shoes": 1, "chalk_bag": 1, "harness": 1, "quickdraw": 6, "rope": 1}
	Inventory.items.clear()
	GameClock.paused = true
	GameClock.minutes = 8 * 60
	var game: ClimbMinigame = load("res://scenes/climb/climb_minigame.tscn").instantiate()
	game.setup(firefall, 3)
	add_child(game)
	await get_tree().process_frame
	press(game, "use_tool")
	check(game._phase == ClimbMinigame.Phase.CLIMB, "Space starts the climb from the route card")
	# A second Up right after stepping onto a crux doesn't spend the check.
	game.state.pending = {"kind": "timing", "name": "The bulge", "window": 0.3, "row": 3, "cell": Vector2i(2, 3)}
	game._start_crux()
	press(game, "move_up")
	check(game._phase == ClimbMinigame.Phase.CRUX and game.state.slipped_cruxes == 0, "the crux meter ignores a double-tap at first")
	game._update_crux(ClimbMinigame.CRUX_GRACE + 0.05)
	press(game, "move_up")
	check(game._phase == ClimbMinigame.Phase.CLIMB, "...and answers after the grace")
	# Miss the green with food in the pack: the meter waits until you eat.
	Inventory.add("dried_apples", 1)
	game.state.pending = {"kind": "timing", "name": "The bulge", "window": 0.3, "row": 3, "cell": Vector2i(2, 3)}
	game._start_crux()
	game._update_crux(ClimbMinigame.CRUX_GRACE + 0.05)
	game._crux.pos = 0.0
	game._crux.center = 0.6
	press(game, "use_tool")
	check(game._phase == ClimbMinigame.Phase.CRUX and game._crux.kind == "pumped" and game.state.slipped_cruxes == 2, "a miss with food in the pack leaves you pumped")
	game._update_crux(ClimbMinigame.CRUX_GRACE + 0.05)
	press(game, "use_tool")
	check(game._crux.kind == "pumped" and Inventory.count("dried_apples") == 1, "Space doesn't eat by accident")
	press(game, "interact")
	check(game._crux.kind == "timing" and Inventory.count("dried_apples") == 0, "E eats and brings the meter back")
	game._update_crux(ClimbMinigame.CRUX_GRACE + 0.05)
	game._crux.pos = game._crux.center
	press(game, "use_tool")
	check(game._phase == ClimbMinigame.Phase.CLIMB and game.state.perfect_cruxes == 1, "stop in the green and you climb on")
	Inventory.items.clear()
	game.queue_free()
	await get_tree().process_frame
	# Starting a day climb at 11:30 PM isn't allowed from the route card either.
	GameClock.minutes = 23 * 60 + 30
	game = load("res://scenes/climb/climb_minigame.tscn").instantiate()
	game.setup(firefall, 3)
	add_child(game)
	await get_tree().process_frame
	press(game, "interact")
	check(game._phase == ClimbMinigame.Phase.INTRO, "a climb that would run past 2 AM doesn't start")
	game.queue_free()
	await get_tree().process_frame
	GameClock.minutes = 8 * 60


func play_route(r: RouteData) -> void:
	var kit := {"climbing_shoes": 1, "chalk_bag": 1, "harness": 1, "quickdraw": 5, "rope": 1}
	for id: String in r.required_gear:
		kit[id] = maxi(int(kit.get(id, 0)), int(r.required_gear[id]))
	Gear.owned = kit
	Inventory.items.clear()
	Inventory.add("acorn_cake", 8)
	GameClock.paused = true
	GameClock.minutes = 8 * 60
	var game: ClimbMinigame = load("res://scenes/climb/climb_minigame.tscn").instantiate()
	game.setup(r, 2)
	add_child(game)
	var done := [false, false, 0]
	game.finished.connect(func(ok, minutes): done[0] = true; done[1] = ok; done[2] = minutes)
	await get_tree().process_frame
	await get_tree().process_frame
	# The route card, then the climb.
	press(game, "interact")
	var bot := ClimbBot.new()
	var steps := 0
	var phases := {}
	while not done[0] and steps < 4000:
		steps += 1
		phases[game._phase] = true
		match game._phase:
			ClimbMinigame.Phase.CRUX:
				game._resolve_crux("perfect" if steps % 3 == 0 else "good")
			ClimbMinigame.Phase.NIGHT:
				game._night_age = 2.0
				press(game, "interact")
			ClimbMinigame.Phase.RESULT:
				game._result_age = 1.0
				press(game, "interact")
			ClimbMinigame.Phase.CLIMB:
				if game.state.status == ClimbState.Status.CLIMBING and game._move_t >= 0.6:
					var before := Vector3i(game.state.col, game.state.row, game.state.pitch)
					bot_step(game, bot)
					game._after_action(before)
				elif game.state.status != ClimbState.Status.CLIMBING:
					game._result_delay = 0.0
					await get_tree().process_frame
			ClimbMinigame.Phase.INTRO, ClimbMinigame.Phase.PAUSE:
				press(game, "interact")
		await get_tree().process_frame
	check(done[0] and done[1], "%s: topped out on the real screen (%d steps)" % [r.id, steps])
	check(done[2] > 0, "%s: the climb reports its time (%d min)" % [r.id, done[2]])
	check(phases.has(ClimbMinigame.Phase.RESULT), "%s: the result card showed" % r.id)
	if r.nights > 0:
		check(phases.has(ClimbMinigame.Phase.NIGHT), "%s: the nights on the wall played" % r.id)
	if is_instance_valid(game):
		game.queue_free()
	await get_tree().process_frame


func press(game: ClimbMinigame, action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	game._input(ev)


## One decision, using the rules directly (like the bot in climb_bot.gd).
func bot_step(game: ClimbMinigame, bot: ClimbBot) -> void:
	var s := game.state
	if s.is_at_belay():
		bot._eat(s)
	bot._protect(s)
	bot._chalk(s)
	var choice := bot._choose(s)
	var dx: int = choice.dx
	if choice.mode == "jug":
		s.jug(dx)
	elif choice.mode == "aid":
		s.aid_step(dx)
	else:
		s.move(dx)
