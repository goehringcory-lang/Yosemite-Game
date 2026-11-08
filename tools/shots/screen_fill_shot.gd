extends Node
## Photographs the whole screen, borders and all, with the game in full
## screen, to see how it fills screens of different sizes (Settings.stretch).
## Needs a display the size of the screen to test, such as xvfb's:
##   SHOT_FILL=fill xvfb-run -a -s "-screen 0 2560x1440x24" godot --path . res://tools/shots/screen_fill_shot.tscn
##   (1280x800 is a Steam Deck)
## Environment:
##   SHOT_FILL    fill (the default) or pixel_perfect
##   SHOT_LOW     1 for Low graphics (run with --rendering-method gl_compatibility)
##   SHOT_REGION  region id (default curry_village)
##   SHOT_SPAWN   spawn name (default arrival)
##   SHOT_HOUR    game hour (default 10)
##   SHOT_DIR     folder for the PNG (default user://)


func _ready() -> void:
	Settings.path = "user://screen_fill_shot.cfg"
	Settings.load_settings()
	var fill := OS.get_environment("SHOT_FILL") if OS.get_environment("SHOT_FILL") != "" else "fill"
	Settings.set_fullscreen_choice(2 if fill == "pixel_perfect" else 1)
	Settings.graphics = Settings.Graphics.LOW if OS.get_environment("SHOT_LOW") == "1" else Settings.Graphics.HIGH
	Settings.save()
	Settings.apply(get_window())
	# xvfb has no window manager to make a window full screen, so cover the
	# screen with it the way full screen does
	var screen := DisplayServer.screen_get_size(0)
	get_window().borderless = true
	get_window().position = Vector2i.ZERO
	get_window().size = screen
	SaveManager.save_path = "user://screen_fill_shot_save.json"
	SaveManager.delete_save()
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var region := OS.get_environment("SHOT_REGION") if OS.get_environment("SHOT_REGION") != "" else "curry_village"
	var spawn := OS.get_environment("SHOT_SPAWN") if OS.get_environment("SHOT_SPAWN") != "" else "arrival"
	await world.go_to_region(region, spawn)
	GameClock.minutes = (int(OS.get_environment("SHOT_HOUR")) if OS.get_environment("SHOT_HOUR") != "" else 10) * 60
	GameClock.paused = true
	for i in 40:
		await get_tree().process_frame
	var dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://"
	var image := DisplayServer.screen_get_image(0)
	if image:
		var low := "_low" if Settings.low() else ""
		image.save_png("%s/screen_fill_%s%s_%dx%d.png" % [dir, fill, low, screen.x, screen.y])
	print("screen %s, window %s, stretch %s" % [screen, get_window().size, get_window().content_scale_stretch])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.graphics_override_path()))
	SaveManager.delete_save()
	get_tree().quit()
