extends Node
## Headless test of the title screen (scripts/ui/title_screen.gd) and the
## credits (scripts/ui/credits.gd): the menu with and without a save, New Game
## asking before it starts over, Settings and Credits opening and closing by
## keys, the credits carrying the required map data and license notices, and
## SaveManager starting fresh without losing the old save.
## Run: godot --headless --path . res://tests/title_test.tscn
## Exit code is the number of failed checks. Uses its own save and settings files.

const SAVE_PATH := "user://title_test_save.json"
const SETTINGS_PATH := "user://title_test_settings.cfg"

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	await get_tree().process_frame
	Settings.path = SETTINGS_PATH
	Settings.load_settings()
	SaveManager.save_path = SAVE_PATH
	SaveManager.delete_save()
	test_project()
	test_credits_text()
	await test_without_save()
	await test_with_save()
	await test_fresh_start()
	await test_slots()
	SaveManager.delete_save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func test_project() -> void:
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/ui/title_screen.tscn", "the game opens on the title screen")
	check(ResourceLoader.exists(TitleScreen.WORLD_SCENE), "the title screen's world scene exists")


func test_credits_text() -> void:
	var credits := Credits.credits_bbcode()
	check(credits.contains("Map data © OpenStreetMap contributors") and credits.contains("Open Database License (ODbL)"), "the credits carry the OpenStreetMap credit the ODbL requires")
	check(credits.contains("USGS 3D Elevation Program"), "the credits name the elevation data")
	check(credits.contains("Noto Sans") and credits.contains("SIL Open Font License"), "the credits name the font and its license")
	check(credits.contains("Godot Engine"), "the credits name the engine")
	var licenses := Credits.licenses_bbcode()
	check(licenses.contains("Permission is hereby granted"), "the Licenses page has Godot's license text")
	check(licenses.contains("Noto Project Authors") and licenses.contains("SIL OPEN FONT LICENSE Version 1.1"), "the Licenses page has the font's full license")
	check(licenses.contains("FreeType"), "the Licenses page lists the libraries built into Godot")
	check(FileAccess.file_exists(Credits.FONT_LICENSE), "the font's license file is in the project")


func _open_title() -> TitleScreen:
	var title: TitleScreen = load("res://scenes/ui/title_screen.tscn").instantiate()
	add_child(title)
	await get_tree().process_frame
	return title


func test_without_save() -> void:
	var title := await _open_title()
	check(TitleScreen.Option.CONTINUE not in title.options(), "with no save there is no Continue")
	check(title.cursor_option() == TitleScreen.Option.NEW_GAME, "and the cursor starts on New Game")
	check(Sound.ambience() == "title", "the title screen plays its ambience")
	_press("move_up")
	check(title.cursor_option() == TitleScreen.Option.QUIT, "Up from the top wraps round to Quit")
	_press("move_down")
	_press("move_down")
	_press("interact")
	check(title._pause.is_open() and title._pause.page() == PauseMenu.Page.SETTINGS, "Settings opens the Settings page on its own")
	check(not title._menu.visible, "and the title menu hides under it")
	_press("move_right")
	check(Settings.text_speed == Settings.TextSpeed.FAST, "the Settings page works from the title screen")
	for i in PauseMenu.Setting.CONTROLS:
		_press("move_down")
	_press("interact")
	check(title._pause.page() == PauseMenu.Page.CONTROLS, "Controls opens from the Settings page")
	_press("ui_cancel")
	check(title._pause.page() == PauseMenu.Page.SETTINGS and title._pause._settings_cursor == PauseMenu.Setting.CONTROLS, "and Esc goes back to Settings")
	_press("move_down")
	_press("interact")
	check(not title._pause.is_open() and title._menu.visible, "Back on Settings returns to the title menu")
	_press("interact")
	_press("ui_cancel")
	check(not title._pause.is_open(), "and so does Esc")
	_press("move_down")
	_press("interact")
	check(title._credits.is_open() and title._credits.page() == Credits.Page.CREDITS, "Credits opens the credits")
	_press("move_right")
	check(title._credits.page() == Credits.Page.LICENSES, "Right turns to the Licenses page")
	_press("move_left")
	check(title._credits.page() == Credits.Page.CREDITS, "Left turns back")
	_press("ui_cancel")
	check(not title._credits.is_open() and title._menu.visible, "Esc closes the credits")
	title.queue_free()
	await get_tree().process_frame


func test_with_save() -> void:
	FileAccess.open(SAVE_PATH, FileAccess.WRITE).store_string("{}")
	var title := await _open_title()
	check(title.options()[0] == TitleScreen.Option.CONTINUE, "with a save, Continue comes first")
	check(title.options()[1] == TitleScreen.Option.LOAD, "then Load game")
	check(title.cursor_option() == TitleScreen.Option.CONTINUE, "and the cursor starts on it")
	_press("move_down")
	_press("move_down")
	_press("interact")
	check(title._pause.is_open() and title._pause.page() == PauseMenu.Page.SLOTS and title._pause._slot_mode == PauseMenu.SlotMode.NEW,
		"New Game opens the save slots to pick one")
	check(title._pause._slot_cursor == 1, "the cursor starts on the first empty slot")
	check(not SaveManager._fresh and not title._starting, "and nothing changes yet")
	_press("move_up")
	_press("interact")
	check(title._pause._slot_confirm == 1 and not title._starting, "starting over in a used slot asks first")
	_press("ui_cancel")
	check(not title._pause.is_open() and title._menu.visible and not SaveManager._fresh, "Esc takes it back to the title menu")
	_press("move_up")
	_press("interact")
	check(title._pause.is_open() and title._pause._slot_mode == PauseMenu.SlotMode.LOAD and title._pause._slot_cursor == 0,
		"Load game opens the slots on the newest save")
	_press("move_down")
	_press("interact")
	check(title._pause.is_open() and not title._starting, "an empty slot doesn't load")
	_press("ui_cancel")
	title.queue_free()
	await get_tree().process_frame


## Three slots, each its own file: slot 1 is the old save.json, Continue picks
## the newest, and the menus show the date and place without loading.
func test_slots() -> void:
	SaveManager.save_path = SAVE_PATH
	for n in range(1, SaveManager.SLOTS + 1):
		SaveManager.delete_slot(n)
	check(SaveManager.slot_path(1) == SAVE_PATH, "slot 1 is the save file from before slots")
	check(SaveManager.slot_path(2) != SAVE_PATH and SaveManager.slot_path(2).ends_with("_2.json"), "slot 2 has its own file (%s)" % SaveManager.slot_path(2))
	check(not SaveManager.any_save() and SaveManager.latest_slot() == 0 and SaveManager.first_empty_slot() == 1, "no slots used at first")
	FileAccess.open(SaveManager.slot_path(1), FileAccess.WRITE).store_string(JSON.stringify({"clock": {"day": 4, "season": 1, "year": 2, "minutes": 14 * 60 + 15},
		"summary": {"place": "Curry Village", "saved_at": 1000}}))
	FileAccess.open(SaveManager.slot_path(3), FileAccess.WRITE).store_string(JSON.stringify({"clock": {"day": 1}, "summary": {"saved_at": 2000}}))
	var info := SaveManager.slot_info(1)
	check(info.get("date") == "Summer 4 (Thu), Year 2" and info.get("time") == "2:15 PM" and info.get("place") == "Curry Village",
		"a slot's date, time and place read from its file (%s)" % info)
	check(SaveManager.slot_info(2).is_empty() and SaveManager.first_empty_slot() == 2, "an empty slot has nothing to show")
	check(SaveManager.latest_slot() == 3, "the newest save is the one Continue picks")
	FileAccess.open(SaveManager.slot_path(2), FileAccess.WRITE).store_string("not json")
	check(SaveManager.slot_info(2).get("broken", false), "a broken file says so instead of crashing")
	SaveManager.slot = 3
	check(SaveManager.save_path == SaveManager.slot_path(3) and SaveManager.has_save(), "the current slot is what saves and loads")
	var title := await _open_title()
	title.select(TitleScreen.Option.CONTINUE)
	check(SaveManager.slot == 3 and title._starting, "Continue carries on the newest game")
	title.queue_free()
	await get_tree().process_frame
	for n in range(1, SaveManager.SLOTS + 1):
		SaveManager.delete_slot(n)
	SaveManager.save_path = SAVE_PATH


func test_fresh_start() -> void:
	FileAccess.open(SAVE_PATH, FileAccess.WRITE).store_string(JSON.stringify({"nodes": {"World": {"region": "wawona"}}}))
	check(SaveManager.peek_node("World").get("region") == "wawona", "a save is there to start with")
	SaveManager.start_fresh()
	check(SaveManager.peek_node("World").is_empty() and not SaveManager.load_game(), "after New Game the old save isn't loaded")
	check(SaveManager.has_save(), "but it stays on disk until the first sleep")
	var world: Node = load(TitleScreen.WORLD_SCENE).instantiate()
	add_child(world)
	await get_tree().process_frame
	check(world.region.region_id == Park.HOME_REGION, "the new game starts at home (%s)" % world.region.region_id)
	SaveManager.save_game()
	check(not SaveManager._fresh and SaveManager.load_game(), "the first save is the new game's, and loads again")
	world.queue_free()
	await get_tree().process_frame


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	var release := InputEventAction.new()
	release.action = action
	Input.parse_input_event(release)
	Input.flush_buffered_events()
