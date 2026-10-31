extends Node
## Saves screenshots of the climbing screen part-way up a route. Needs a window
## (not --headless). Environment:
##   SHOT_ROUTE   route id (default firefall_slab)
##   SHOT_PITCH   pitch to start on (default 0)
##   SHOT_HOURS   comma-separated game hours to shoot at (default 7,12,19)
##   SHOT_MOVES   moves to climb before each shot (default 5)
##   SHOT_INTRO   1 to shoot the route card instead of the climb
##   SHOT_SPECIAL cards to shoot instead: "crux", "pumped", "dyno", "result", "pause", "night"
##   SHOT_DIR     folder for the PNGs (default user://)
##   SHOT_UNLIT   1 to leave the wall unlit (ClimbLight off), as on Low
## The screenshot is the window's own size (3x the 480 x 270 screen).
## Run: SHOT_ROUTE=firefall_slab SHOT_HOURS=7,19 godot --path . res://tools/shots/climb_shot.tscn


func _env(key: String, fallback: String) -> String:
	return OS.get_environment(key) if OS.get_environment(key) != "" else fallback


func _ready() -> void:
	LitSprites.enabled = OS.get_environment("SHOT_UNLIT") != "1"
	var route: RouteData = load("res://data/routes/%s.tres" % _env("SHOT_ROUTE", "firefall_slab"))
	var dir := _env("SHOT_DIR", "user://")
	Gear.owned = {"climbing_shoes": 1, "chalk_bag": 1, "harness": 1, "quickdraw": 6, "rope": 1, "cam": 6}
	for id: String in route.required_gear:
		Gear.owned[id] = maxi(int(Gear.owned.get(id, 0)), int(route.required_gear[id]))
	Inventory.items.clear()
	Inventory.add("trail_mix", 2)
	Inventory.add("acorn_cake", 4)
	GameClock.paused = true
	for hour in _env("SHOT_HOURS", "7,12,19").split(","):
		GameClock.minutes = int(hour) * 60
		var game: ClimbMinigame = load("res://scenes/climb/climb_minigame.tscn").instantiate()
		game.setup(route, 4)
		game.state.pitch = int(_env("SHOT_PITCH", "0"))
		game.state._start_pitch()
		add_child(game)
		await get_tree().process_frame
		if _env("SHOT_INTRO", "0") == "1":
			for f in 40:
				await get_tree().process_frame
			_save(dir, route.id, "intro_" + hour)
			game.queue_free()
			await get_tree().process_frame
			continue
		game.skip_intro()
		for f in 3:
			await get_tree().process_frame
		if _env("SHOT_BANNER", "0") != "1":
			game._banner_age = 99.0
			game._speech_age = 99.0
		for i in int(_env("SHOT_MOVES", "5")):
			var before := Vector3i(game.state.col, game.state.row, game.state.pitch)
			game.state.protect()
			game.state.move(_cheapest(game.state))
			if not game.state.pending.is_empty():
				game._resolve_crux("good")
			game.state.protect()
			game._after_action(before)
			for f in 8:
				await get_tree().process_frame
		if game.state.row >= 2 and not game.state.chalked_this_pitch:
			game.state.chalk_up()
			game._events()
		match _env("SHOT_SPECIAL", ""):
			"crux":
				game.state.pending = {"kind": "timing", "name": "The crux", "window": 0.3}
				game._start_crux()
			"pumped":
				Inventory.add("trail_mix", 1)
				game.state.pending = {"kind": "timing", "name": "The crux", "window": 0.3, "pumped": true}
				game._start_pumped()
			"rhythm", "mash":
				game.state.pending = {"kind": _env("SHOT_SPECIAL", ""), "name": "The Narrows", "window": 0.3}
				game._start_crux()
				game._crux.done = 4
			"dyno":
				game.state.pending = {"kind": "dyno", "name": "Chicken wing dyno", "window": 0.22}
				game._start_crux()
				game._crux.holding = true
				game._crux.charge = game._crux.center - 0.1
				game._crux.speed = 0.0
			"storm":
				game.state.start_minutes = 15 * 60
				for k in 60:
					game._weather(0.05)
					game._fx.update(0.05)
			"result":
				game.state.status = ClimbState.Status.TOPPED_OUT
				game._phase = ClimbMinigame.Phase.RESULT
				game._result_age = 2.0
			"pause":
				game._phase = ClimbMinigame.Phase.PAUSE
			"night":
				game._night = {"night": 1, "place": "hanging", "meal": "an acorn cake"}
				game._phase = ClimbMinigame.Phase.NIGHT
				game._night_age = 2.0
		for f in 40:
			await get_tree().process_frame
		_save(dir, route.id, hour)
		game.queue_free()
		await get_tree().process_frame
	get_tree().quit()


func _save(dir: String, route_id: String, tag: String) -> void:
	var image := get_viewport().get_texture().get_image()
	# doubled like the other shots, so screens compare at one scale
	image.resize(image.get_width() * 2, image.get_height() * 2, Image.INTERPOLATE_NEAREST)
	image.save_png("%s/climb_%s_%s.png" % [dir, route_id, tag])


func _cheapest(state: ClimbState) -> int:
	var best := 0
	var best_cost := 9999
	for dx in [-1, 0, 1]:
		var r := state.row + 1
		if state.hold_at(r, state.col + dx).is_empty():
			continue
		var cost := state.move_cost(r, state.col + dx)
		if state.bolts.has(r) and absi(int(state.bolts[r]) - (state.col + dx)) > 1:
			cost += 20
		if cost < best_cost:
			best = dx
			best_cost = cost
	return best
