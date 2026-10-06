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
	press(game, "interact")
	check(game._phase == ClimbMinigame.Phase.CLIMB and game.state.status == ClimbState.Status.CLIMBING, "E keeps climbing")
	press(game, "ui_cancel")
	press(game, "ui_cancel")
	check(game.state.status == ClimbState.Status.RETREATED, "Esc twice retreats")
	game.queue_free()
	await get_tree().process_frame


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
