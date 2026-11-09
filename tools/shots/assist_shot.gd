extends Node
## Saves screenshots of the assist options: the Settings page on Activity
## timing and on Hold to tap, and the same climbing crux at Standard and at
## Gentle, then a crux of quick taps with Hold to tap on. Uses its own
## settings file.
## Needs a window (not --headless). Environment:
##   SHOT_DIR    folder for the PNGs (default user://)
##   SHOT_SCALE  integer upscale (default 2)
## Run: SHOT_DIR=/tmp/shots godot --path . res://tools/shots/assist_shot.tscn


func _snap(dir: String, scale: int, shot_name: String) -> void:
	for i in 10:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	if scale > 1:
		image.resize(image.get_width() * scale, image.get_height() * scale, Image.INTERPOLATE_NEAREST)
	image.save_png("%s/assist_%s.png" % [dir, shot_name])


func _ready() -> void:
	Settings.path = "user://assist_shot_settings.cfg"
	Settings.load_settings()
	Settings.reset_defaults()
	var dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://"
	var scale := int(OS.get_environment("SHOT_SCALE")) if OS.get_environment("SHOT_SCALE") != "" else 2
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	GameClock.minutes = 11 * 60
	GameClock.paused = true
	await world.go_to_region("curry_village", "arrival")
	for i in 12:
		await get_tree().process_frame
	var pause: PauseMenu = get_tree().get_first_node_in_group("pause_menu")
	pause.open()
	pause._show_page(PauseMenu.Page.SETTINGS)
	pause.change_setting(PauseMenu.Setting.TIMING, 1)
	pause._settings_cursor = PauseMenu.Setting.TIMING
	pause._refresh()
	await _snap(dir, scale, "settings_timing")
	pause.change_setting(PauseMenu.Setting.HOLD_TAPS, 1)
	pause._settings_cursor = PauseMenu.Setting.BACK
	pause._refresh()
	await _snap(dir, scale, "settings_bottom")
	pause._settings_cursor = PauseMenu.Setting.HOLD_TAPS
	pause._refresh()
	await _snap(dir, scale, "settings_hold")
	pause.close()
	world.queue_free()
	await get_tree().process_frame
	Gear.owned = {"climbing_shoes": 1, "chalk_bag": 1, "harness": 1, "quickdraw": 6, "rope": 1}
	for shot: Array in [[Settings.Timing.STANDARD, false, "timing", "crux_standard"], [Settings.Timing.GENTLE, false, "timing", "crux_gentle"], [Settings.Timing.STANDARD, true, "mash", "crux_hold"]]:
		Settings.timing = shot[0]
		Settings.hold_taps = shot[1]
		var game: ClimbMinigame = load("res://scenes/climb/climb_minigame.tscn").instantiate()
		game.setup(load("res://data/routes/firefall_slab.tres"), 3)
		game.state.conditions = WallWeather.CALM.duplicate()
		add_child(game)
		await get_tree().process_frame
		var ev := InputEventAction.new()
		ev.action = "use_tool"
		ev.pressed = true
		game._input(ev)
		game.state.pending = {"kind": shot[2], "name": "The bulge", "window": game.state.crux_window(), "row": 3, "cell": Vector2i(2, 3)}
		game._start_crux()
		game.set_process(false)
		if shot[2] == "timing":
			game._crux.center = 0.5
			game._crux.pos = 0.2
		else:
			game._crux.done = 3
		game._canvas.queue_redraw()
		await _snap(dir, scale, shot[3])
		game.queue_free()
		await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	get_tree().quit()
