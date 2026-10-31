extends Node
## Headless test of the player settings (scripts/ui/settings.gd) and the UI
## that uses them: saving and loading user://, bad values, the pause menu's
## Settings page driven by keys, pinned button prompts, the HUD hiding under
## the journal, and the dialogue box's text reveal and skip.
## Run: godot --headless --path . res://tests/settings_test.tscn
## Exit code is the number of failed checks. Uses its own settings and save files.

const TEST_PATH := "user://settings_test.cfg"

var failures := 0
var world: Node


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	await get_tree().process_frame
	Settings.path = TEST_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	test_persistence()
	test_bad_values()
	Settings.path = TEST_PATH
	test_graphics()
	Settings.path = TEST_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	Settings.load_settings()
	SaveManager.save_path = "user://settings_test_save.json"
	SaveManager.delete_save()
	world = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	GameClock.paused = true
	await test_pause_settings()
	test_pause_graphics()
	test_prompts()
	await test_book()
	await test_dialogue_reveal()
	world.queue_free()
	SaveManager.delete_save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func test_persistence() -> void:
	Settings.load_settings()
	check(Settings.text_speed == Settings.TextSpeed.NORMAL and not Settings.fullscreen and Settings.window_scale == 2
		and Settings.prompts == Settings.Prompts.AUTO, "no settings file gives the defaults")
	Settings.text_speed = Settings.TextSpeed.FAST
	Settings.fullscreen = true
	Settings.window_scale = 2
	Settings.prompts = Settings.Prompts.GAMEPAD
	check(Settings.save() == OK and FileAccess.file_exists(TEST_PATH), "settings save to user://")
	Settings.reset_defaults()
	check(Settings.text_speed == Settings.TextSpeed.NORMAL, "reset puts the defaults back")
	Settings.load_settings()
	check(Settings.text_speed == Settings.TextSpeed.FAST, "text speed loads back")
	check(Settings.fullscreen, "full screen loads back")
	check(Settings.window_scale == 2, "window size loads back")
	check(Settings.prompts == Settings.Prompts.GAMEPAD, "button prompts load back")
	check(Settings.chars_per_second() == 120.0, "Fast reveals 120 letters a second")
	Settings.text_speed = Settings.TextSpeed.INSTANT
	check(Settings.chars_per_second() == 0.0, "Instant shows a page at once")


## Graphics: Low writes the Compatibility renderer into the override file the
## project reads at start-up, High removes it, and the pause menu says a change
## waits for a restart.
func test_graphics() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	Settings.load_settings()
	var override := Settings.graphics_override_path()
	check(override != Settings.GRAPHICS_OVERRIDE, "a test keeps its own override file (%s)" % override)
	check(Settings.graphics == Settings.Graphics.HIGH, "graphics default to High")
	check(ProjectSettings.get_setting("rendering/renderer/rendering_method") == "forward_plus", "the project runs on Forward+")
	check(ProjectSettings.get_setting("application/config/project_settings_override") == Settings.GRAPHICS_OVERRIDE,
		"the project reads the graphics override file")
	Settings.graphics = Settings.Graphics.LOW
	Settings.save()
	var config := ConfigFile.new()
	check(config.load(override) == OK and config.get_value("rendering", "renderer/rendering_method", "") == "gl_compatibility",
		"Low writes the Compatibility renderer to the override file")
	Settings.reset_defaults()
	Settings.load_settings()
	check(Settings.graphics == Settings.Graphics.LOW, "Low loads back")
	Settings.graphics = Settings.Graphics.HIGH
	Settings.save()
	check(not FileAccess.file_exists(override), "High removes the override file")


## The pause menu's Graphics row steps between High and Low and says a change
## waits for a restart.
func test_pause_graphics() -> void:
	var pause: PauseMenu = get_tree().get_first_node_in_group("pause_menu")
	Settings._started_graphics = Settings.graphics
	check(pause._setting_value(PauseMenu.Setting.GRAPHICS) == "‹  High  ›", "the pause menu shows High")
	pause.change_setting(PauseMenu.Setting.GRAPHICS, 1)
	check(Settings.graphics == Settings.Graphics.LOW and pause._setting_value(PauseMenu.Setting.GRAPHICS) == "‹  Low (on restart)  ›",
		"a change shows it waits for a restart")
	pause.change_setting(PauseMenu.Setting.GRAPHICS, 1)
	check(Settings.graphics == Settings.Graphics.HIGH and not FileAccess.file_exists(Settings.graphics_override_path()),
		"and steps back to High, removing the override")


func test_bad_values() -> void:
	var config := ConfigFile.new()
	config.set_value("text", "speed", 99)
	config.set_value("display", "window_scale", -4)
	config.set_value("input", "prompts", 7)
	config.save(TEST_PATH)
	Settings.load_settings()
	check(Settings.text_speed == Settings.TextSpeed.INSTANT, "an out-of-range text speed is clamped (%d)" % Settings.text_speed)
	check(Settings.window_scale == Settings.MIN_SCALE, "an out-of-range window size is clamped (%d)" % Settings.window_scale)
	check(Settings.prompts == Settings.Prompts.GAMEPAD, "an out-of-range prompt mode is clamped")
	check(not Settings.fullscreen, "a missing key keeps its default")
	Settings.path = "user://no_such_dir/settings.cfg"
	Settings.load_settings()
	check(Settings.text_speed == Settings.TextSpeed.NORMAL, "an unreadable file gives the defaults")


func test_pause_settings() -> void:
	var pause: PauseMenu = get_tree().get_first_node_in_group("pause_menu")
	_press("pause")
	check(pause.is_open() and pause.page() == PauseMenu.Page.MAIN, "Esc opens the pause menu on its main page")
	_press("move_down")
	_press("move_down")
	_press("interact")
	check(pause.page() == PauseMenu.Page.SETTINGS, "Down twice then E opens Settings")
	_press("move_right")
	check(Settings.text_speed == Settings.TextSpeed.FAST, "Right raises the text speed")
	_press("move_left")
	_press("move_left")
	check(Settings.text_speed == Settings.TextSpeed.SLOW, "Left lowers it")
	check(_saved("text", "speed") == Settings.TextSpeed.SLOW, "the change is saved at once")
	_press("move_down")
	_press("move_down")
	_press("move_down")
	_press("move_right")
	check(Settings.prompts == Settings.Prompts.KEYBOARD, "Right steps the button prompts")
	_press("move_left")
	check(Settings.prompts == Settings.Prompts.AUTO, "Left steps them back to Auto")
	for i in 4: # Button prompts, up past Text speed, round to Back
		_press("move_up")
	check(pause._settings_cursor == PauseMenu.Setting.BACK, "the cursor wraps round to Back")
	_press("interact")
	check(pause.is_open() and pause.page() == PauseMenu.Page.MAIN and pause._cursor == PauseMenu.Option.SETTINGS, "Back returns to the main page on Settings")
	_press("move_down")
	_press("interact")
	check(pause.page() == PauseMenu.Page.CONTROLS, "Controls opens")
	_press("ui_cancel")
	check(pause.is_open() and pause.page() == PauseMenu.Page.MAIN, "Esc on a page goes back to the main page")
	_press("move_down")
	_press("interact")
	check(pause.is_open() and pause._confirm_quit, "Quit asks first instead of quitting")
	_press("move_up")
	check(not pause._confirm_quit, "moving away cancels the quit")
	await test_pause_save(pause)
	_press("ui_cancel")
	check(not pause.is_open() and world.player.can_act, "Esc on the main page resumes")
	check(pause._panel.visible, "the menu is closed at once but fades out")
	await get_tree().create_timer(0.4).timeout
	check(not pause._panel.visible, "and is gone once it has faded")
	await get_tree().process_frame


## Save game on the pause menu writes the save where the player stands, at the
## time of day it is.
func test_pause_save(pause: PauseMenu) -> void:
	SaveManager.delete_save()
	var spot: Vector2 = world.player.position + Vector2(8, 0)
	world.player.position = spot
	GameClock.minutes = 14 * 60 + 15
	for i in 2: # from Controls: Settings, Save game
		_press("move_up")
	check(pause._cursor == PauseMenu.Option.SAVE, "the cursor reaches Save game")
	_press("interact")
	check(SaveManager.has_save(), "Save game writes the save file")
	check(pause.is_open() and "Saved at" in pause._option_labels[PauseMenu.Option.SAVE].text, "the menu says it saved, and stays open")
	_press("move_down")
	_press("move_down")
	_press("move_down")
	_press("interact")
	check(pause._confirm_quit and pause._option_labels[PauseMenu.Option.QUIT].text.contains("Your game is saved"), "Quit says the game is saved")
	_press("move_up")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.save_path))
	var player_data: Dictionary = saved.nodes.get(str(world.player.name), {})
	check(is_equal_approx(float(player_data.get("x", 0.0)), spot.x), "the save holds where the player stands")
	check(int(saved.clock.minutes) == 14 * 60 + 15, "the save holds the time of day")


func test_prompts() -> void:
	var hud: HUD = world.hud
	hud._input(InputEventKey.new())
	Settings.prompts = Settings.Prompts.GAMEPAD
	hud.refresh_settings()
	check(hud.interact_button() == "A" and hud._status.text.contains("[Y] Journal"), "Gamepad prompts name gamepad buttons with a keyboard in use")
	Settings.prompts = Settings.Prompts.KEYBOARD
	hud._input(InputEventJoypadButton.new())
	check(hud.interact_button() == "E", "Keyboard prompts stay on the keyboard with a gamepad in use")
	Settings.prompts = Settings.Prompts.AUTO
	check(hud.interact_button() == "A", "Auto follows the gamepad")
	hud._input(InputEventKey.new())
	check(hud.interact_button() == "E" and MenuInput.button(get_tree(), "Esc", "B") == "Esc", "and the keyboard, in the menus too")


func test_book() -> void:
	var hud: HUD = world.hud
	await get_tree().process_frame
	check(hud._status.text == "[J] Journal  ·  [Q] Quests  ·  [B] Backpack", "the hint line names the three keys (%s)" % hud._status.text)
	check(get_viewport().get_visible_rect().encloses(hud.status_bar.get_global_rect()), "the hint line fits on screen")
	var journal: Journal = get_tree().get_first_node_in_group("journal")
	journal.open()
	await get_tree().process_frame
	check(hud.status_bar.modulate.a == 0.0 and hud.clock_panel.modulate.a == 0.0, "the HUD hides under the journal")
	check(journal._footer.text.contains("[J/Esc] Close"), "the journal's hint stays under the page (%s)" % journal._footer.text)
	check(get_viewport().get_visible_rect().encloses(journal._panel.get_global_rect()), "the journal fits on screen (%s)" % journal._panel.get_global_rect())
	Settings.prompts = Settings.Prompts.GAMEPAD
	hud.refresh_settings()
	check(journal._footer.text.contains("[LB/RB] Next tab") and journal._tab_labels[Journal.Tab.QUESTS].text == "Quests", "its hints follow the Button prompts setting (%s)" % journal._footer.text)
	Settings.prompts = Settings.Prompts.AUTO
	hud.refresh_settings()
	check(journal._tab_labels[Journal.Tab.QUESTS].text == "[Q] Quests", "and name the keys on a keyboard")
	journal.close()
	await get_tree().process_frame
	check(hud.status_bar.modulate.a == 1.0, "and comes back after")


func test_dialogue_reveal() -> void:
	Settings.text_speed = Settings.TextSpeed.SLOW
	var box := DialogueBox.open(self)
	var done := [false]
	var talk := func():
		await box.say([{"speaker": "Test", "text": "A long line that takes a while to appear at the slow speed."}])
		done[0] = true
	talk.call()
	await get_tree().process_frame
	await get_tree().process_frame
	check(not box.is_revealed() and box._text_label.visible_characters < 10, "slow text appears a letter at a time (%d)" % box._text_label.visible_characters)
	check(box._hint_label.text.contains("Skip"), "the hint offers to skip (%s)" % box._hint_label.text)
	_press("interact")
	await get_tree().process_frame
	check(box.is_revealed() and box._text_label.visible_characters == -1 and not done[0], "the first E shows the whole page and waits")
	check(box._hint_label.text.contains("Next"), "then the hint says Next (%s)" % box._hint_label.text)
	_press("interact")
	await get_tree().process_frame
	await get_tree().process_frame
	check(done[0], "the second E goes on")
	Settings.text_speed = Settings.TextSpeed.INSTANT
	box._show("Test", "All at once.", [])
	check(box.is_revealed(), "Instant shows the page at once")
	box.close()
	Settings.text_speed = Settings.TextSpeed.NORMAL


func _saved(section: String, key: String) -> Variant:
	var config := ConfigFile.new()
	config.load(Settings.path)
	return config.get_value(section, key)


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
