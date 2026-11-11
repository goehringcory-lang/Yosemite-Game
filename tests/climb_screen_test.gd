extends Node
## Plays every route on the real climbing screen, frame by frame, the way a
## player would (a bot presses the keys' actions through the screen's own
## handlers, resolves crux checks and nights), and checks it tops out, draws
## every phase without errors, and reports once.
## Run (it needs a window): xvfb-run -a godot --path . res://tests/climb_screen_test.tscn

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	await get_tree().process_frame
	await test_controls()
	await test_checks_on_screen()
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
	check(game._light.sun_on and not game._light.headlamp.enabled, "the morning sun lights the wall, the headlamp is off")
	check(game._light.sun_travel.x < 0.0, "the morning sun comes from the east (the right)")
	game._start_minutes = 23 * 60
	game._paint_scenery()
	await get_tree().process_frame
	check(game._light.headlamp.enabled and not game._light.sun_on, "after dark the headlamp lights the wall")
	check(game._light.headlamp.position.distance_to(game._torso()) < 30.0, "the headlamp is on the climber")
	check(game._light.headlamp.range_layer_min == game.layer and game._light.headlamp.range_layer_max == game.layer, "the headlamp reaches the climbing screen's canvas layer")
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
	# A chicken wing dyno: hold to sink onto the wing, let go in the green.
	game.state.pending = {"kind": "dyno", "name": "Chicken wing dyno", "window": 0.3, "row": 3, "cell": Vector2i(2, 3)}
	game._start_crux()
	game._update_crux(ClimbMinigame.CRUX_GRACE + 0.05)
	press(game, "use_tool")
	game._update_crux(0.05)
	check(game._crux.holding and game._crux.charge > 0.0, "holding Space sinks onto the chicken wing")
	game._crux.charge = game._crux.center
	release(game, "use_tool")
	check(game._phase == ClimbMinigame.Phase.CLIMB and game.state.perfect_cruxes == 2, "let go in the green and you lunge to the slot")
	# Hold on too long and the wing slips out.
	Inventory.add("dried_apples", 1)
	game.state.pending = {"kind": "dyno", "name": "Chicken wing dyno", "window": 0.3, "row": 3, "cell": Vector2i(2, 3)}
	game._start_crux()
	game._update_crux(ClimbMinigame.CRUX_GRACE + 0.05)
	press(game, "move_up")
	game._update_crux(2.0)
	check(game._crux.kind == "pumped" and game.state.slipped_cruxes == 3, "sink too far on the wing and you miss the dyno")
	game._update_crux(ClimbMinigame.CRUX_GRACE + 0.05)
	press(game, "interact")
	check(game._crux.kind == "dyno" and not game._crux.holding, "eating brings the dyno back")
	# Hold to tap (Settings): a crux of quick taps answers to one long press.
	Settings.ensure_loaded()
	game.state.pending = {"kind": "mash", "name": "The offwidth", "need": 6, "row": 3, "cell": Vector2i(2, 3)}
	game._start_crux()
	game._update_crux(ClimbMinigame.CRUX_GRACE + 0.05)
	Input.action_press("move_up")
	game._update_crux(1.0)
	check(game._crux.kind == "mash" and game._crux.done == 0, "holding Up does nothing with Hold to tap off")
	Settings.hold_taps = true
	game._update_crux(0.25)
	check(game._crux.done == 1, "with it on, the held key taps by itself")
	Input.action_release("move_up")
	game._crux.done = 0
	game._crux.hold = 0.0
	game.hold_crux(0.5, true)
	check(game._crux.done == 2, "with it on, holding Up taps four times a second")
	game.hold_crux(0.2, false)
	game.hold_crux(0.2, true)
	check(game._crux.done == 2, "letting go starts the count again")
	game.hold_crux(1.0, true)
	check(game._phase == ClimbMinigame.Phase.CLIMB, "...and a long hold finishes the crux")
	game.state.pending = {"kind": "rhythm", "name": "The layback", "row": 3, "cell": Vector2i(2, 3)}
	game._start_crux()
	game._update_crux(ClimbMinigame.CRUX_GRACE + 0.05)
	var before_left: float = game._crux.time_left
	press(game, "move_right")
	check(game._crux.done == 1 and is_equal_approx(game._crux.time_left, before_left), "with it on, the wrong side still counts on a left-right crux")
	game.hold_crux(2.0, true)
	check(game._phase == ClimbMinigame.Phase.CLIMB, "...and holding a side finishes it")
	Settings.hold_taps = false
	game.state.pending = {}
	game._phase = ClimbMinigame.Phase.CLIMB
	game._crux = {}
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
	var kinds := {}
	while not done[0] and steps < 4000:
		steps += 1
		phases[game._phase] = true
		if game._phase == ClimbMinigame.Phase.CRUX:
			kinds[game._crux.get("kind", "")] = true
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
		check(kinds.has("haul"), "%s: the bag was hauled at the belays" % r.id)
	if r.id == "the_nose":
		check(kinds.has("swing") and kinds.has("layback"), "%s: the King Swing and the flakes' laybacks played (%s)" % [r.id, kinds.keys()])
	if is_instance_valid(game):
		game.queue_free()
	await get_tree().process_frame


## A new screen on the Nose with the big-wall rack, past the route card.
func _nose_screen(seed := 6) -> ClimbMinigame:
	var nose: RouteData = load("res://data/routes/the_nose.tres")
	Gear.owned = {"climbing_shoes": 1, "chalk_bag": 1, "harness": 1, "quickdraw": 6, "rope": 1, "cam": 10, "aiders": 2, "ascenders": 2, "haul_bag": 1, "portaledge": 1}
	Inventory.items.clear()
	Inventory.add("acorn_cake", 4)
	Inventory.add("trail_mix", 4)
	GameClock.paused = true
	GameClock.minutes = 8 * 60
	var game: ClimbMinigame = load("res://scenes/climb/climb_minigame.tscn").instantiate()
	game.setup(nose, seed)
	game.state.conditions = WallWeather.CALM.duplicate()
	add_child(game)
	game.skip_intro()
	return game


## Climbs the screen's state until [param predicate] holds, answering cruxes.
func _climb_until(game: ClimbMinigame, predicate: Callable) -> bool:
	var s := game.state
	for i in 300:
		if predicate.call(s):
			return true
		if not s.pending.is_empty():
			s.resolve_crux("good")
			continue
		s.stamina = ClimbState.MAX_STAMINA
		for d in [0, -1, 1]:
			if not s.hold_at(s.row + 1, s.col + d).is_empty():
				s.move(d)
				break
	return false


## Runs [param frames] of a ClimbCheck on the screen, holding what
## [param pilot] says (and letting it press keys through the screen).
func _drive(game: ClimbMinigame, pilot: Callable, frames := 1200) -> void:
	for i in frames:
		if game._phase != ClimbMinigame.Phase.CRUX or not game._crux.has("check"):
			return
		var held: Dictionary = pilot.call(game._crux.check)
		game.step_check(1.0 / 60.0, held)
		if i % 20 == 0:
			await get_tree().process_frame


## The swing, the layback, the piton and the haul on the real screen: they
## start, take the keys, draw, and hand their result back to the climb.
func test_checks_on_screen() -> void:
	# The King Swing: the panel's up, the climber's out on the rope, Space grabs.
	var game := _nose_screen()
	await get_tree().process_frame
	game.state.pending = {"kind": "swing", "name": "King Swing", "window": 0.25, "row": 3, "cell": Vector2i(2, 3), "index": 1, "count": 1}
	game._start_crux()
	check(game._crux.get("check") is SwingCheck, "the King Swing is played by its own rules on the screen")
	game._update_crux(ClimbMinigame.CRUX_GRACE + 0.05)
	var hanging := game._torso()
	for i in 40:
		game.step_check(1.0 / 60.0, {"right": true})
	await get_tree().process_frame
	check(game._torso().x > hanging.x + 4.0, "the climber swings out across the wall (%.0f to %.0f)" % [hanging.x, game._torso().x])
	await _drive(game, func(sw: SwingCheck) -> Dictionary:
		if sw.angle >= sw.green_from() + sw.window * 0.2 and absf(sw.speed) < 0.15:
			press(game, "use_tool")
			return {}
		if sw.amplitude() < SwingCheck.TARGET + 0.02:
			return {"right": sw.speed >= 0.0, "left": sw.speed < 0.0}
		return {})
	check(game._phase == ClimbMinigame.Phase.CLIMB and game.state.pending.is_empty() and game._crux_result in ["perfect", "good"],
		"Space at the top of the swing grabs the crack (%s)" % game._crux_result)
	# A grab that's short says so, and you eat before the next try.
	game.state.pending = {"kind": "swing", "name": "King Swing", "window": 0.25, "row": 3, "cell": Vector2i(2, 3), "index": 1, "count": 1}
	game._start_crux()
	game._update_crux(ClimbMinigame.CRUX_GRACE + 0.05)
	press(game, "use_tool")
	await get_tree().process_frame
	check(game._crux.get("kind", "") == "pumped" and game._crux_result == "slip_short", "a grab too soon misses, and says why (%s)" % game._crux_result)
	game._update_crux(ClimbMinigame.CRUX_GRACE + 0.05)
	press(game, "interact")
	check(game._crux.get("check") is SwingCheck and game._crux.check.angle == 0.0, "after eating, the swing starts again from hanging")
	game.queue_free()
	await get_tree().process_frame

	# A layback: Space pulls, Up steps.
	game = _nose_screen()
	await get_tree().process_frame
	game.state.pending = {"kind": "layback", "name": "The layback", "window": 0.22, "row": 3, "cell": Vector2i(2, 3), "index": 1, "count": 2}
	game._start_crux()
	game._update_crux(ClimbMinigame.CRUX_GRACE + 0.05)
	check(game._crux.get("check") is LaybackCheck, "a layback is played by its own rules")
	var steps0 := game._step
	await _drive(game, func(l: LaybackCheck) -> Dictionary:
		if l.tension >= (l.band_from() + l.band_to()) / 2.0:
			press(game, "move_up")
			return {}
		return {"pull": true})
	check(game._phase == ClimbMinigame.Phase.CLIMB and game._crux_result == "perfect" and game._step >= steps0 + LaybackCheck.NEED,
		"pulling into the green and stepping walks up the flake (%s)" % game._crux_result)
	# With Hold to tap, holding Up steps whenever the tension's right.
	Settings.hold_taps = true
	game.state.pending = {"kind": "layback", "name": "The layback", "window": 0.22, "row": 3, "cell": Vector2i(2, 3), "index": 1, "count": 2}
	game._start_crux()
	game._update_crux(ClimbMinigame.CRUX_GRACE + 0.05)
	var feather := [true]
	await _drive(game, func(l: LaybackCheck) -> Dictionary:
		# pull up into the green, then ease off a little, and keep holding Up
		if l.tension > l.band_to() - 0.02:
			feather[0] = false
		elif l.tension < l.band_from() + 0.04:
			feather[0] = true
		return {"pull": feather[0], "up": true})
	check(game._phase == ClimbMinigame.Phase.CLIMB and game._crux_result in ["perfect", "good"], "with Hold to tap, holding Up steps in the green (%s)" % game._crux_result)
	Settings.hold_taps = false
	game.queue_free()
	await get_tree().process_frame

	# An aid move on the Great Roof: Shift + an arrow nails a pin first.
	game = _nose_screen(7)
	await get_tree().process_frame
	game.state.pitch = 6
	game.state._start_pitch()
	game._new_pitch()
	var aid_dx := [99]
	var found := _climb_until(game, func(s: ClimbState) -> bool:
		for d in [0, -1, 1]:
			if s.can_aid(d):
				aid_dx[0] = d
				return s.pending.is_empty()
		return false)
	check(found, "there's a move to aid on the Great Roof")
	game._move_t = 1.0
	var row := game.state.row
	Input.action_press("assist")
	press(game, {-1: "move_left", 0: "move_up", 1: "move_right"}[aid_dx[0]])
	Input.action_release("assist")
	check(game._phase == ClimbMinigame.Phase.CRUX and game._crux.get("check") is NailCheck and game.state.row == row, "Shift + an arrow on a hard move means nailing a pin first")
	await get_tree().process_frame
	game._update_crux(ClimbMinigame.CRUX_GRACE + 0.05)
	await _drive(game, func(n: NailCheck) -> Dictionary:
		var need := n.center() - n.depth
		if absf(need) <= n.window * 0.1:
			press(game, "move_up")
		elif need >= NailCheck.drive(1.0):
			if n.swing >= 0.97:
				press(game, "use_tool")
		elif need >= NailCheck.drive(0.0):
			if absf(n.swing - (need - NailCheck.DRIVE_MIN) / (NailCheck.DRIVE_MAX - NailCheck.DRIVE_MIN)) <= 0.02:
				press(game, "use_tool")
		else:
			press(game, "move_up")
		return {})
	check(game._phase == ClimbMinigame.Phase.CLIMB and game.state.row == row + 1 and game.state.aid_moves == 1 and game._crux_result in ["nail_perfect", "nail_good"],
		"Space drives it, Up steps onto it, and the move goes (%s)" % game._crux_result)
	check(game.state.protection.back().hw == "pin", "the nailed pin is on the rope")
	await get_tree().process_frame
	game.queue_free()
	await get_tree().process_frame

	# The haul at the top of the first pitch: hold Space, let go, wiggle a snag.
	game = _nose_screen(3)
	await get_tree().process_frame
	_climb_until(game, func(s: ClimbState) -> bool: return s.row == s.top_row - 1 and s.pending.is_empty())
	var before := Vector3i(game.state.col, game.state.row, game.state.pitch)
	for d in [0, -1, 1]:
		if not game.state.hold_at(game.state.row + 1, game.state.col + d).is_empty():
			game.state.move(d)
			break
	game._after_action(before)
	check(game._phase == ClimbMinigame.Phase.CRUX and game._crux.get("check") is HaulCheck and game.state.pitch == 0, "at the belay the bag waits to be hauled")
	game._update_crux(ClimbMinigame.CRUX_GRACE + 0.05)
	Settings.hold_taps = true
	await _drive(game, func(h: HaulCheck) -> Dictionary:
		if h.snag >= 0:
			return {"left": true}
		if h.stroke >= 1.0 or (h.stroke > 0.0 and not h._was_pulling):
			return {}
		return {"pull": true})
	Settings.hold_taps = false
	check(game.state.pitch == 1 and game.state.pending.is_empty() and game._crux_result.begins_with("haul_"), "the bag comes up, Hold to tap wiggles it free, and the next pitch starts (%s)" % game._crux_result)
	await get_tree().process_frame
	game.queue_free()
	await get_tree().process_frame


func press(game: ClimbMinigame, action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	game._input(ev)


func release(game: ClimbMinigame, action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = false
	game._input(ev)


## One decision, using the rules directly (like the bot in climb_bot.gd).
func bot_step(game: ClimbMinigame, bot: ClimbBot) -> void:
	bot.step(game.state)