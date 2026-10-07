extends Node
## Headless test of the player settings (scripts/ui/settings.gd) and the UI
## that uses them: saving and loading user://, bad values, the pause menu's
## Settings page driven by keys, the goal panel, pinned button prompts, and
## the dialogue box's text reveal and skip.
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
	test_prompts()
	await test_objective()
	await test_dialogue_reveal()
	world.queue_free()
	SaveManager.delete_save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func test_persistence() -> void:
	Settings.load_settings()
	check(Settings.text_speed == Settings.TextSpeed.NORMAL and not Settings.fullscreen and Settings.window_scale == 3
		and Settings.show_objective and Settings.prompts == Settings.Prompts.AUTO, "no settings file gives the defaults")
	Settings.text_speed = Settings.TextSpeed.FAST
	Settings.fullscreen = true
	Settings.window_scale = 2
	Settings.show_objective = false
	Settings.prompts = Settings.Prompts.GAMEPAD
	check(Settings.save() == OK and FileAccess.file_exists(TEST_PATH), "settings save to user://")
	Settings.reset_defaults()
	check(Settings.text_speed == Settings.TextSpeed.NORMAL, "reset puts the defaults back")
	Settings.load_settings()
	check(Settings.text_speed == Settings.TextSpeed.FAST, "text speed loads back")
	check(Settings.fullscreen, "full screen loads back")
	check(Settings.window_scale == 2, "window size loads back")
	check(not Settings.show_objective, "the goal panel setting loads back")
	check(Settings.prompts == Settings.Prompts.GAMEPAD, "button prompts load back")
	check(Settings.chars_per_second() == 120.0, "Fast reveals 120 letters a second")
	Settings.text_speed = Settings.TextSpeed.INSTANT
	check(Settings.chars_per_second() == 0.0, "Instant shows a page at once")


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
	check(Settings.show_objective, "a missing key keeps its default")
	Settings.path = "user://no_such_dir/settings.cfg"
	Settings.load_settings()
	check(Settings.text_speed == Settings.TextSpeed.NORMAL, "an unreadable file gives the defaults")


func test_pause_settings() -> void:
	var pause: PauseMenu = get_tree().get_first_node_in_group("pause_menu")
	_press("pause")
	check(pause.is_open() and pause.page() == PauseMenu.Page.MAIN, "Esc opens the pause menu on its main page")
	_press("move_down")
	_press("interact")
	check(pause.page() == PauseMenu.Page.SETTINGS, "Down then E opens Settings")
	_press("move_right")
	check(Settings.text_speed == Settings.TextSpeed.FAST, "Right raises the text speed")
	_press("move_left")
	_press("move_left")
	check(Settings.text_speed == Settings.TextSpeed.SLOW, "Left lowers it")
	check(_saved("text", "speed") == Settings.TextSpeed.SLOW, "the change is saved at once")
	_press("move_down")
	_press("move_down")
	_press("move_down")
	_press("interact")
	check(not Settings.show_objective and _saved("hud", "show_objective") == false, "E toggles the goal panel off and saves it")
	_press("interact")
	check(Settings.show_objective, "and back on")
	_press("move_down")
	_press("move_right")
	check(Settings.prompts == Settings.Prompts.KEYBOARD, "Right steps the button prompts")
	_press("move_left")
	check(Settings.prompts == Settings.Prompts.AUTO, "Left steps them back to Auto")
	for i in 5: # Button prompts, up past Text speed, round to Back
		_press("move_up")
	check(pause._settings_cursor == PauseMenu.Setting.BACK, "the cursor wraps round to Back")
	_press("interact")
	check(pause.is_open() and pause.page() == PauseMenu.Page.MAIN and pause._cursor == 1, "Back returns to the main page on Settings")
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
	_press("ui_cancel")
	check(not pause.is_open() and world.player.can_act, "Esc on the main page resumes")
	await get_tree().process_frame


func test_prompts() -> void:
	var hud: HUD = world.hud
	hud._input(InputEventKey.new())
	Settings.prompts = Settings.Prompts.GAMEPAD
	hud.refresh_settings()
	check(hud.interact_button() == "A" and hud._status.text.contains("Y: Journal"), "Gamepad prompts name gamepad buttons with a keyboard in use")
	Settings.prompts = Settings.Prompts.KEYBOARD
	hud._input(InputEventJoypadButton.new())
	check(hud.interact_button() == "E", "Keyboard prompts stay on the keyboard with a gamepad in use")
	Settings.prompts = Settings.Prompts.AUTO
	check(hud.interact_button() == "A", "Auto follows the gamepad")
	hud._input(InputEventKey.new())
	check(hud.interact_button() == "E" and MenuInput.button(get_tree(), "Esc", "B") == "Esc", "and the keyboard, in the menus too")


func test_objective() -> void:
	var hud: HUD = world.hud
	Settings.show_objective = true
	hud.refresh_objective()
	await get_tree().process_frame
	await get_tree().process_frame
	var text := HUD.objective_text()
	check(text != "" and hud.objective_label.text == text, "the goal panel shows the next step (%s)" % text)
	check(hud.objective_panel.visible, "the goal panel is visible")
	var screen := get_viewport().get_visible_rect()
	var rect := hud.objective_panel.get_global_rect()
	check(screen.encloses(rect), "the goal panel fits on screen (%s)" % rect)
	check(rect.position.y >= hud.clock_panel.get_global_rect().end.y, "the goal panel sits under the clock")
	check(rect.size.x <= HUD.OBJECTIVE_WIDTH + 16, "the goal panel stays narrow (%.0f)" % rect.size.x)
	Settings.show_objective = false
	hud.refresh_objective()
	check(not hud.objective_panel.visible, "turning the setting off hides it")
	Settings.show_objective = true
	hud.refresh_objective()
	var journal: Journal = get_tree().get_first_node_in_group("journal")
	journal.open()
	await get_tree().process_frame
	check(hud.objective_panel.modulate.a == 0.0, "the goal panel hides under the journal")
	check(journal._footer.text.contains("[J/Esc] Close"), "the journal's hint stays under the page (%s)" % journal._footer.text)
	journal.close()
	await get_tree().process_frame
	check(hud.objective_panel.modulate.a == 1.0, "and comes back after")


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
