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
	test_stretch()
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
	test_graphics_watch()
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
	check(not Settings.pixel_perfect and Settings.fullscreen_choice() == 1, "full screen fills the screen by default")
	check(Settings.window_scale == 2, "window size loads back")
	check(Settings.prompts == Settings.Prompts.GAMEPAD, "button prompts load back")
	check(Settings.chars_per_second() == 120.0, "Fast reveals 120 letters a second")
	Settings.text_speed = Settings.TextSpeed.INSTANT
	check(Settings.chars_per_second() == 0.0, "Instant shows a page at once")


## Filling the screen: the picture grows in any step, so a 2560x1440 screen
## or a Steam Deck is covered edge to edge; Pixel perfect full screen keeps
## whole steps (2x, 3x), with a border where the screen isn't a multiple.
func test_stretch() -> void:
	check(ProjectSettings.get_setting("display/window/stretch/scale_mode") == "fractional",
		"the project scales the picture to fill the window, not in whole steps only")
	check(ProjectSettings.get_setting("display/window/stretch/mode") == "canvas_items", "and still draws at the window's size")
	Settings.reset_defaults()
	check(Settings.stretch() == Window.CONTENT_SCALE_STRETCH_FRACTIONAL, "a window fills")
	Settings.set_fullscreen_choice(1)
	check(Settings.fullscreen and not Settings.pixel_perfect and Settings.stretch() == Window.CONTENT_SCALE_STRETCH_FRACTIONAL,
		"Fill: full screen, covered edge to edge")
	Settings.set_fullscreen_choice(2)
	check(Settings.fullscreen and Settings.pixel_perfect and Settings.stretch() == Window.CONTENT_SCALE_STRETCH_INTEGER,
		"Pixel perfect: full screen in whole steps")
	Settings.save()
	Settings.reset_defaults()
	Settings.load_settings()
	check(Settings.fullscreen_choice() == 2, "Pixel perfect loads back")
	Settings.set_fullscreen_choice(0)
	check(not Settings.fullscreen and not Settings.pixel_perfect and Settings.stretch() == Window.CONTENT_SCALE_STRETCH_FRACTIONAL,
		"Off: a window, which always fills")
	Settings.save()


## Graphics: Low writes the Compatibility renderer into the override file the
## project reads at start-up, High removes it, and the pause menu says a change
## waits for a restart.
func test_graphics() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	Settings.load_settings()
	var override := Settings.graphics_override_path()
	check(override != Settings.GRAPHICS_OVERRIDE, "a test keeps its own override file (%s)" % override)
	check(Settings.graphics == Settings.Graphics.AUTO and not Settings.low(), "graphics default to Auto, which starts as High")
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
	# Auto: High until it finds the computer slow, then Low
	Settings.graphics = Settings.Graphics.AUTO
	Settings.auto_low = true
	Settings.save()
	check(Settings.low() and Settings.graphics_name() == "Auto (Low)", "Auto on a slow computer is Low")
	check(config.load(override) == OK and config.get_value("rendering", "renderer/rendering_method", "") == "gl_compatibility",
		"and starts next time on the Compatibility renderer")
	Settings.reset_defaults()
	Settings.load_settings()
	check(Settings.graphics == Settings.Graphics.AUTO and Settings.auto_low, "Auto's finding loads back")
	Settings.auto_low = false
	Settings.save()
	check(not FileAccess.file_exists(override) and Settings.graphics_name() == "Auto (High)", "Auto on a fast computer is High")
	# settings from before Auto: High becomes Auto, Low stays Low
	var old := ConfigFile.new()
	old.set_value("display", "graphics", 0)
	old.save(TEST_PATH)
	Settings.load_settings()
	check(Settings.graphics == Settings.Graphics.AUTO, "an old High setting becomes Auto")
	old.set_value("display", "graphics", 1)
	old.save(TEST_PATH)
	Settings.load_settings()
	check(Settings.graphics == Settings.Graphics.LOW, "an old Low setting stays Low")
	Settings.graphics = Settings.Graphics.AUTO
	Settings.save()


## The pause menu's Graphics row steps Auto, High, Low and says a renderer
## change waits for a restart.
func test_pause_graphics() -> void:
	var pause: PauseMenu = get_tree().get_first_node_in_group("pause_menu")
	# Full screen: Off, Fill, Pixel perfect, and round again
	Settings.set_fullscreen_choice(0)
	check(pause._setting_value(PauseMenu.Setting.FULLSCREEN) == "‹  Off  ›", "the pause menu shows full screen Off")
	pause.change_setting(PauseMenu.Setting.FULLSCREEN, 1)
	check(Settings.fullscreen and pause._setting_value(PauseMenu.Setting.FULLSCREEN) == "‹  Fill  ›", "then Fill")
	pause.change_setting(PauseMenu.Setting.FULLSCREEN, 1)
	check(Settings.pixel_perfect and pause._setting_value(PauseMenu.Setting.FULLSCREEN) == "‹  Pixel perfect  ›", "then Pixel perfect")
	check(_saved("display", "pixel_perfect") == true, "which is saved at once")
	pause.change_setting(PauseMenu.Setting.FULLSCREEN, 1)
	check(not Settings.fullscreen and not Settings.pixel_perfect, "and round to Off")
	pause.change_setting(PauseMenu.Setting.FULLSCREEN, -1)
	check(Settings.fullscreen_choice() == 2, "Left steps back to Pixel perfect")
	Settings.set_fullscreen_choice(0)
	Settings.save()
	Settings.graphics = Settings.Graphics.AUTO
	Settings.auto_low = false
	Settings._started_renderer = Settings.renderer()
	check(pause._setting_value(PauseMenu.Setting.GRAPHICS) == "‹  Auto (High)  ›", "the pause menu shows Auto (High)")
	pause.change_setting(PauseMenu.Setting.GRAPHICS, 1)
	check(Settings.graphics == Settings.Graphics.HIGH and pause._setting_value(PauseMenu.Setting.GRAPHICS) == "‹  High  ›",
		"then High, with nothing to wait for")
	pause.change_setting(PauseMenu.Setting.GRAPHICS, 1)
	check(Settings.graphics == Settings.Graphics.LOW and pause._setting_value(PauseMenu.Setting.GRAPHICS) == "‹  Low (on restart)  ›",
		"Low shows it waits for a restart")
	pause.change_setting(PauseMenu.Setting.GRAPHICS, 1)
	check(Settings.graphics == Settings.Graphics.AUTO and not FileAccess.file_exists(Settings.graphics_override_path()),
		"and steps back round to Auto, removing the override")


## GraphicsWatch: the typical frame decides, so one long hitch doesn't count.
func test_graphics_watch() -> void:
	var frames := PackedFloat32Array([16.0, 17.0, 16.5, 400.0, 16.2])
	check(GraphicsWatch.median(frames) < GraphicsWatch.SLOW_MS, "one long hitch isn't a slow computer")
	frames = PackedFloat32Array([33.0, 34.0, 16.0, 33.5, 35.0])
	check(GraphicsWatch.median(frames) > GraphicsWatch.SLOW_MS, "steady 30 frames a second is")


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
	pause.change_setting(PauseMenu.Setting.TIMING, 1)
	check(Settings.timing == Settings.Timing.RELAXED and pause._setting_value(PauseMenu.Setting.TIMING).contains("Relaxed"), "Activity timing steps to Relaxed")
	pause.change_setting(PauseMenu.Setting.TIMING, 1)
	check(Settings.timing == Settings.Timing.GENTLE, "...and on to Gentle")
	check(_saved("assist", "timing") == Settings.Timing.GENTLE, "the timing is saved at once")
	pause.change_setting(PauseMenu.Setting.TIMING, 1)
	check(Settings.timing == Settings.Timing.STANDARD, "...and round to Standard")
	pause.change_setting(PauseMenu.Setting.HOLD_TAPS, 1)
	check(Settings.hold_taps and pause._setting_value(PauseMenu.Setting.HOLD_TAPS).contains("On") and _saved("assist", "hold_taps") == true, "Hold to tap turns on and is saved")
	pause.change_setting(PauseMenu.Setting.HOLD_TAPS, 1)
	check(not Settings.hold_taps, "...and off again")
	check(Settings.vibration and pause._setting_value(PauseMenu.Setting.VIBRATION).contains("On"), "Vibration starts on")
	pause.change_setting(PauseMenu.Setting.VIBRATION, 1)
	check(not Settings.vibration and _saved("input", "vibration") == false, "Vibration turns off and is saved")
	pause.change_setting(PauseMenu.Setting.VIBRATION, 1)
	pause.change_setting(PauseMenu.Setting.PAUSE_AWAY, 1)
	check(not Settings.pause_away and pause._setting_value(PauseMenu.Setting.PAUSE_AWAY).contains("Off") and _saved("input", "pause_away") == false, "Pause when away turns off and is saved")
	pause.change_setting(PauseMenu.Setting.PAUSE_AWAY, 1)
	check(Settings.vibration and Settings.pause_away, "...and both back on")
	check(Settings.wind and pause._setting_value(PauseMenu.Setting.WIND).contains("On") and Wind.strength_now() > 0.0, "Wind starts on")
	pause.change_setting(PauseMenu.Setting.WIND, 1)
	check(not Settings.wind and _saved("display", "wind") == false and Wind.strength_now() == 0.0, "Wind turns off, is saved, and the air is still")
	pause.change_setting(PauseMenu.Setting.WIND, 1)
	check(Settings.wind, "...and on again")
	await get_tree().process_frame
	check(pause._panel.get_combined_minimum_size().y <= UiScale.SCREEN.y - 8.0, "the settings page fits on the screen")
	check(pause.settings_shown() == Vector2i(0, PauseMenu.SETTINGS_SHOWN) and pause._more_label.text == "More below.", "it shows the first rows and says there are more")
	for i in 4: # Button prompts, up past Text speed, round to Back
		_press("move_up")
	check(pause._settings_cursor == PauseMenu.Setting.BACK, "the cursor wraps round to Back")
	check(pause.settings_shown().x == PauseMenu.Setting.size() - PauseMenu.SETTINGS_SHOWN and pause._setting_names[PauseMenu.Setting.BACK].get_parent().visible and pause._more_label.text == "More above.", "...and the list scrolls to it")
	_press("interact")
	check(pause.is_open() and pause.page() == PauseMenu.Page.MAIN and pause._cursor == PauseMenu.Option.SETTINGS, "Back returns to the main page on Settings")
	_press("move_down")
	_press("interact")
	check(pause.page() == PauseMenu.Page.CONTROLS, "Controls opens")
	test_rebind(pause)
	_press("ui_cancel")
	check(pause.is_open() and pause.page() == PauseMenu.Page.MAIN, "Esc on a page goes back to the main page")
	_press("move_down")
	_press("interact")
	check(pause._cursor == PauseMenu.Option.LOOK and pause._creator != null and pause._creator.is_open(), "Your look opens the character screen")
	_press("ui_cancel")
	check(pause.is_open() and pause.page() == PauseMenu.Page.MAIN and not pause._creator.is_open(), "and Esc there comes back to the main page")
	_press("move_down")
	_press("move_down") # past Report a problem (tests/problem_report_test)
	_press("interact")
	check(pause.is_open() and pause._confirm_quit, "Quit asks first instead of quitting")
	_press("move_up")
	check(not pause._confirm_quit, "moving away cancels the quit")
	_press("move_up")
	_press("move_up")
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
	check(pause.page() == PauseMenu.Page.SLOTS and pause._slot_mode == PauseMenu.SlotMode.SAVE and pause._slot_cursor == 0,
		"Save game opens the save slots, on the slot being played")
	_press("interact")
	check(SaveManager.has_save(), "E on the slot writes the save file")
	check(pause.is_open() and "Saved in slot 1 at" in pause._slot_note.text and pause._slot_details[0].text.contains("saved "), "the page says it saved, and the menu stays open (%s)" % pause._slot_note.text)
	check(SaveManager.slot_info(1).get("place", "") != "", "the save notes where you are for the slot list")
	# saving over another game asks first, then moves this game to that slot
	FileAccess.open(SaveManager.slot_path(2), FileAccess.WRITE).store_string("{}")
	_press("move_down")
	_press("interact")
	check(pause._slot_confirm == 2 and SaveManager.slot == 1, "saving over another game asks first")
	_press("interact")
	check(SaveManager.slot == 2 and SaveManager.slot_info(2).has("date"), "pressing again saves there, and the game goes on in slot 2")
	SaveManager.delete_slot(2)
	SaveManager.slot = 1
	_press("ui_cancel")
	check(pause.page() == PauseMenu.Page.MAIN and pause._cursor == PauseMenu.Option.SAVE, "Esc goes back to the main page on Save game")
	_press("move_down")
	_press("move_down")
	_press("move_down")
	check(pause._cursor == PauseMenu.Option.LOOK, "Your look comes after Controls")
	_press("move_down")
	check(pause._cursor == PauseMenu.Option.REPORT, "then Report a problem")
	_press("move_down")
	check(pause._cursor == PauseMenu.Option.QUIT_TITLE, "Quit to title comes before Quit to desktop")
	_press("interact")
	check(pause._confirm_quit and pause._option_labels[PauseMenu.Option.QUIT_TITLE].text.contains("Your game is saved"), "Quit to title asks first, and says the game is saved")
	check(pause.is_open() and get_tree().current_scene != null, "and stays in the game until asked again")
	_press("move_down")
	check(not pause._confirm_quit, "moving on forgets the question")
	_press("interact")
	check(pause._confirm_quit and pause._option_labels[PauseMenu.Option.QUIT].text.contains("Your game is saved"), "Quit says the game is saved")
	check(not pause._option_labels[PauseMenu.Option.QUIT_TITLE].text.contains("?"), "and only the chosen line asks")
	_press("move_up")
	_press("move_up")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.save_path))
	var player_data: Dictionary = saved.nodes.get(str(world.player.name), {})
	check(is_equal_approx(float(player_data.get("x", 0.0)), spot.x), "the save holds where the player stands")
	check(int(saved.clock.minutes) == 14 * 60 + 15, "the save holds the time of day")


## The Controls page: E on a key waits for the next key, which takes over
## the action (and the hints); a key in use swaps; Esc keeps the old key; the
## menus' keys can't be taken; Reset puts everything back.
func test_rebind(pause: PauseMenu) -> void:
	var interact := Settings.BINDINGS.map(func(b: Dictionary) -> String: return b.id).find("interact")
	for i in interact:
		_press("move_down")
	_press("interact")
	check(pause._listening == interact, "E on a control waits for a key")
	_key(KEY_ESCAPE)
	check(pause._listening == -1 and Settings.key_for("interact") == KEY_E and pause.is_open(), "Esc keeps the old key, and the menu open")
	_press("interact")
	_key(KEY_F)
	check(Settings.key_for("interact") == KEY_F and _has_key("interact", KEY_F) and not _has_key("interact", KEY_E), "a new key takes over Talk")
	check(_has_key("interact", KEY_X), "and the action's other key stays")
	check(world.hud.prompt("E", "A") == "F" and MenuInput.button(get_tree(), "[J] Journal  [E] Talk", "A") == "[J] Journal  [F] Talk", "hints name the new key")
	check(_saved("keys", "interact") == KEY_F, "the key is saved")
	_press("interact")
	_key(KEY_G)
	check(Settings.key_for("interact") == KEY_G and Settings.key_for("gift") == KEY_F, "a key another control had swaps over")
	_press("interact")
	_key(KEY_TAB)
	check(Settings.key_for("interact") == KEY_G and pause._control_note.text == PauseMenu.RESERVED_TEXT, "the menus' keys can't be taken")
	Settings.load_settings()
	check(Settings.key_for("interact") == KEY_G and _has_key("interact", KEY_G), "changed keys load back")
	for i in Settings.BINDINGS.size() - interact:
		_press("move_down")
	check(pause._controls_cursor == Settings.BINDINGS.size(), "the cursor reaches Reset keys")
	_press("interact")
	check(Settings.keys.is_empty() and _has_key("interact", KEY_E) and _has_key("gift", KEY_G), "Reset keys puts every key back")
	check(world.hud.prompt("E", "A") == "E", "and the hints with them")


func _has_key(action: String, physical: int) -> bool:
	return InputMap.action_get_events(action).any(func(e: InputEvent) -> bool: return e is InputEventKey and e.physical_keycode == physical)


func _key(physical: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = physical
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()


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
