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
	await test_weather_on_screen()
	await test_light()
	for r in Guidebook.routes():
		await play_route(r)
	print("\nOK: %d failure(s)" % failures)
	get_tree().quit(failures)


## On High graphics real light falls on the wall: the sun by day, the
## headlamp after dark. On Low the wall is drawn with everything else.
func test_light() -> void:
	var route: RouteData = load("res://data/routes/the_nose.tres")
	var game: ClimbMinigame = load("res://scenes/climb/climb_minigame.tscn").instantiate()
	game.setup(route, 6)
	game.state.conditions = WallWeather.CALM.duplicate()
	add_child(game)
	await get_tree().process_frame
	if not LitSprites.active():
		check(game._wall_view == null and game._light == null, "on Low the wall keeps its painted look")
		game.queue_free()
		return
	check(game._wall_view != null and game._wall_view.material is ShaderMaterial, "the wall is drawn with real light")
	check(game._wall_view.light_mask == LitSprites.LIT_LAYER, "only the wall is on the light layer")
	game._start_minutes = 8 * 60
	game._paint_scenery()
	await get_tree().process_frame
	check(game._light.sun.enabled and not game._light.headlamp.enabled, "the morning sun lights the wall, the headlamp is off")
	check(Vector2.DOWN.rotated(game._light.sun.rotation).x < 0.0, "the morning sun comes from the east (the right)")
	game._start_minutes = 23 * 60
	game._paint_scenery()
	await get_tree().process_frame
	check(game._light.headlamp.enabled and not game._light.sun.enabled, "after dark the headlamp lights the wall")
	check(game._light.headlamp.position.distance_to(game._torso()) < 30.0, "the headlamp is on the climber")
	game.queue_free()
	await get_tree().process_frame


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
	game.state.conditions = WallWeather.CALM.duplicate()
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
	game.state.conditions = WallWeather.CALM.duplicate()
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
	game.state.conditions = WallWeather.CALM.duplicate()
	add_child(game)
	await get_tree().process_frame
	press(game, "interact")
	check(game._phase == ClimbMinigame.Phase.INTRO, "a climb that would run past 2 AM doesn't start")
	game.queue_free()
	await get_tree().process_frame
	GameClock.minutes = 8 * 60


## A wet, windy, hot day and a high-country storm all draw, and the
## lightning ends the climb with the result card.
func test_weather_on_screen() -> void:
	var peak: RouteData = load("res://data/routes/cathedral_peak.tres")
	Gear.owned = {"climbing_shoes": 1, "chalk_bag": 1, "harness": 1, "quickdraw": 6, "rope": 1, "cam": 6}
	Inventory.items.clear()
	GameClock.paused = true
	GameClock.minutes = 14 * 60 + 40
	var game: ClimbMinigame = load("res://scenes/climb/climb_minigame.tscn").instantiate()
	game.setup(peak, 4)
	game.state.conditions = WallWeather.CALM.duplicate()
	game.state.conditions.merge({"storm_hour": 14.5, "lightning": true, "wind": true, "dry_hour": 24.0}, true)
	add_child(game)
	await get_tree().process_frame
	check(game._wall_tex.get_size() == Vector2(ClimbLayout.WALL_W, ClimbLayout.wall_height(game.state.top_row)), "the 32px wall reports the menu-grid size (%s)" % game._wall_tex.get_size())
	check(game._wall_tex.get_image().get_width() == ClimbLayout.WALL_W * 2, "...and holds twice the pixels")
	press(game, "interact")
	check(game.state.is_stormy() and game.state.is_windy() and game._wetness() == 1.0, "a stormy, windy day on the peak")
	for i in 20:
		await get_tree().process_frame
	game.state.minutes += 60
	var before := Vector3i(game.state.col, game.state.row, game.state.pitch)
	game.state.interactive = false
	game.state.move(0 if not game.state.hold_at(1, game.state.col).is_empty() else (-1 if not game.state.hold_at(1, game.state.col - 1).is_empty() else 1))
	game._after_action(before)
	check(game.state.status == ClimbState.Status.RETREATED, "the lightning sends you down on the screen")
	for i in 10:
		await get_tree().process_frame
	game._result_delay = 0.0
	for i in 3:
		await get_tree().process_frame
	check(game._phase == ClimbMinigame.Phase.RESULT, "...and the result card comes up")
	game.queue_free()
	await get_tree().process_frame
	# A hot summer afternoon on the Apron, with yesterday's rain still drying.
	var apron: RouteData = load("res://data/routes/glacier_point_apron.tres")
	GameClock.minutes = 13 * 60
	game = load("res://scenes/climb/climb_minigame.tscn").instantiate()
	game.setup(apron, 4)
	game.state.conditions = WallWeather.CALM.duplicate()
	game.state.conditions.merge({"hot": true, "dry_hour": 13.5}, true)
	add_child(game)
	await get_tree().process_frame
	press(game, "interact")
	check(game.state.is_hot() and game.state.is_wet() and game._wetness() > 0.0 and game._wetness() < 1.0, "a drying, hot face draws")
	for i in 20:
		await get_tree().process_frame
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
	game.state.conditions = WallWeather.CALM.duplicate()
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
	bot.step(game.state)