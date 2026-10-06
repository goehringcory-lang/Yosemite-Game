extends Node
## Saves screenshots of the climbing screen part-way up a route. Needs a window
## (not --headless). Environment:
##   SHOT_ROUTE  route id (default firefall_slab)
##   SHOT_HOURS  comma-separated game hours to shoot at (default 7,12,19)
##   SHOT_MOVES  moves to climb before each shot (default 5)
##   SHOT_DIR    folder for the PNGs (default user://)
##   SHOT_SCALE  integer upscale for the saved PNG (default 2)
## Run: SHOT_ROUTE=firefall_slab godot --path . res://tools/shots/climb_shot.tscn


func _env(key: String, fallback: String) -> String:
	return OS.get_environment(key) if OS.get_environment(key) != "" else fallback


func _ready() -> void:
	var route: RouteData = load("res://data/routes/%s.tres" % _env("SHOT_ROUTE", "firefall_slab"))
	var dir := _env("SHOT_DIR", "user://")
	var scale := int(_env("SHOT_SCALE", "2"))
	Gear.owned = {"climbing_shoes": 1, "chalk_bag": 1, "harness": 1, "quickdraw": 5, "rope": 1, "cam": 4}
	Inventory.add("trail_mix", 2)
	GameClock.paused = true
	for hour in _env("SHOT_HOURS", "7,12,19").split(","):
		GameClock.minutes = int(hour) * 60
		var game: ClimbMinigame = load("res://scenes/climb/climb_minigame.tscn").instantiate()
		game.setup(route, 4)
		add_child(game)
		await get_tree().process_frame
		for i in int(_env("SHOT_MOVES", "5")):
			var before := Vector3i(game.state.col, game.state.row, game.state.pitch)
			game.state.protect()
			game.state.move(_cheapest(game.state))
			game.state.protect()
			game._after_action(before)
			for f in 6:
				await get_tree().process_frame
		if game.state.row >= 2 and not game.state.chalked_this_pitch:
			game.state.chalk_up()
		for f in 30:
			await get_tree().process_frame
		var image := get_viewport().get_texture().get_image()
		if scale > 1:
			image.resize(image.get_width() * scale, image.get_height() * scale, Image.INTERPOLATE_NEAREST)
		image.save_png("%s/climb_%s_%s.png" % [dir, route.id, hour])
		game.queue_free()
		await get_tree().process_frame
	get_tree().quit()


func _cheapest(state: ClimbState) -> int:
	var best := 0
	var best_cost := 9999
	for dx in [-1, 0, 1]:
		var r := state.row + 1
		if state.hold_at(r, state.col + dx).is_empty():
			continue
		# Stay near the bolt line on bolted routes.
		var cost := state.move_cost(r, state.col + dx)
		if state.bolts.has(r) and absi(int(state.bolts[r]) - (state.col + dx)) > 1:
			cost += 20
		if cost < best_cost:
			best = dx
			best_cost = cost
	return best
