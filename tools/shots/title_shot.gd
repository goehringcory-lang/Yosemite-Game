extends Node
## Saves screenshots of the title screen: its opening (logo dropping in),
## the menu (with Continue) with ravens crossing, the New Game question, its
## Settings page, both pages of the credits, the pause menu's Quit to title
## question, and the end credits rolling.
## Needs a window (not --headless). Environment:
##   SHOT_DIR    folder for the PNGs (default user://)
##   SHOT_SCALE  integer upscale (default 2)
## Run: SHOT_DIR=/tmp/shots godot --path . res://tools/shots/title_shot.tscn


func _snap(dir: String, scale: int, shot_name: String) -> void:
	for i in 8:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	if scale > 1:
		image.resize(image.get_width() * scale, image.get_height() * scale, Image.INTERPOLATE_NEAREST)
	image.save_png("%s/ui_%s.png" % [dir, shot_name])


func _ready() -> void:
	# A save on disk, so the menu offers Continue.
	SaveManager.save_path = "user://title_shot_save.json"
	FileAccess.open(SaveManager.save_path, FileAccess.WRITE).store_string("{}")
	var dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://"
	var scale := int(OS.get_environment("SHOT_SCALE")) if OS.get_environment("SHOT_SCALE") != "" else 2
	var title: TitleScreen = load("res://scenes/ui/title_screen.tscn").instantiate()
	add_child(title)
	await get_tree().create_timer(0.55).timeout
	await _snap(dir, scale, "title_opening")
	title.finish_intro()
	var sky: TitleSky = title.find_children("*", "TitleSky", true, false)[0]
	sky.send_ravens(30.0)
	sky._time += 8.0 # the ravens across the sky, the clouds on their way
	sky._ravens.start = sky._time - 9.0
	await _snap(dir, scale, "title")
	title.select(TitleScreen.Option.NEW_GAME)
	await _snap(dir, scale, "title_new_game")
	title._confirm_new = false
	title.select(TitleScreen.Option.SETTINGS)
	await _snap(dir, scale, "title_settings")
	title._pause.close()
	title.select(TitleScreen.Option.CREDITS)
	await _snap(dir, scale, "credits")
	title._credits._show_page(Credits.Page.LICENSES)
	await _snap(dir, scale, "credits_licenses")
	title._credits.close()
	title._pause.open()
	title._pause._cursor = PauseMenu.Option.QUIT_TITLE
	title._pause._confirm_quit = true
	title._pause._refresh()
	await _snap(dir, scale, "pause_quit_title")
	title._pause.close()
	var roll := EndCredits.roll(get_tree())
	await get_tree().create_timer(EndCredits.FADE_IN * 1.6).timeout
	roll._scroll = 330.0
	await _snap(dir, scale, "end_credits")
	roll._scroll = roll._end
	await _snap(dir, scale, "end_credits_last")
	SaveManager.delete_save()
	get_tree().quit()
