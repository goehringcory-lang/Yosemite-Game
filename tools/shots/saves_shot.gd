extends Node
## Saves screenshots of the save slots and the Controls page: the pause menu's
## Saves page with two games in it, the title screen's Load game, the
## Settings page with its way to Controls, and Controls with a changed key and
## one waiting for a key. Uses its own save and settings files.
## Needs a window (not --headless). Environment:
##   SHOT_DIR    folder for the PNGs (default user://)
##   SHOT_SCALE  integer upscale (default 2)
## Run: SHOT_DIR=/tmp/shots godot --path . res://tools/shots/saves_shot.tscn


func _snap(dir: String, scale: int, shot_name: String) -> void:
	for i in 10:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	if scale > 1:
		image.resize(image.get_width() * scale, image.get_height() * scale, Image.INTERPOLATE_NEAREST)
	image.save_png("%s/saves_%s.png" % [dir, shot_name])


func _ready() -> void:
	Settings.path = "user://saves_shot_settings.cfg"
	Settings.load_settings()
	SaveManager.save_path = "user://saves_shot_save.json"
	for n in range(1, SaveManager.SLOTS + 1):
		SaveManager.delete_slot(n)
	var dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://"
	var scale := int(OS.get_environment("SHOT_SCALE")) if OS.get_environment("SHOT_SCALE") != "" else 2
	# another game in slot 3, from the week before
	FileAccess.open(SaveManager.slot_path(3), FileAccess.WRITE).store_string(JSON.stringify({
		"clock": {"day": 9, "season": 2, "year": 1, "minutes": 18 * 60 + 40},
		"summary": {"place": "Tuolumne Meadows", "saved_at": int(Time.get_unix_time_from_system()) - 7 * 86400}}))
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	GameClock.minutes = 11 * 60
	GameClock.paused = true
	await world.go_to_region("curry_village", "arrival")
	for i in 12:
		await get_tree().process_frame
	SaveManager.save_game()
	var pause: PauseMenu = get_tree().get_first_node_in_group("pause_menu")
	pause.open()
	pause._show_slots(PauseMenu.SlotMode.SAVE)
	pause.choose_slot(1)
	await _snap(dir, scale, "pause_slots")
	pause._show_page(PauseMenu.Page.SETTINGS)
	pause._settings_cursor = PauseMenu.Setting.CONTROLS
	pause._refresh()
	await _snap(dir, scale, "settings")
	pause._show_page(PauseMenu.Page.CONTROLS)
	pause.bind_key(Settings.BINDINGS.map(func(b: Dictionary) -> String: return b.id).find("interact"), KEY_F)
	pause._controls_cursor = 7
	pause._listening = 7
	pause._refresh()
	await _snap(dir, scale, "controls")
	pause._listening = -1
	pause.reset_keys()
	pause.close()
	world.queue_free()
	await get_tree().process_frame
	var title: TitleScreen = load("res://scenes/ui/title_screen.tscn").instantiate()
	add_child(title)
	for i in 40:
		await get_tree().process_frame
	await _snap(dir, scale, "title")
	title.select(TitleScreen.Option.LOAD)
	await _snap(dir, scale, "title_load")
	title._pause.close()
	for n in range(1, SaveManager.SLOTS + 1):
		SaveManager.delete_slot(n)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	get_tree().quit()
