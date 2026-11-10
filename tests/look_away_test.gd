extends Node
## Headless test of controller rumble (Rumble) and pausing when the window
## stops being in front (LookAway): rumble only goes to a gamepad in use and
## the Vibration setting turns it off; looking away opens the pause menu when
## you're out walking, holds the whole game under a Paused card when you're
## in the middle of something, and does nothing with the setting off.
## Run: godot --headless --path . res://tests/look_away_test.tscn
## Exit code is the number of failed checks. Uses its own settings and save.

const TEST_PATH := "user://look_away_test.cfg"

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
	Settings.load_settings()
	Settings.reset_defaults()
	SaveManager.save_path = "user://look_away_test_save.json"
	SaveManager.delete_save()
	test_rumble()
	world = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	test_look_away()
	get_tree().paused = false
	world.queue_free()
	SaveManager.delete_save()
	Settings.reset_defaults()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func _key() -> InputEventKey:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	key.keycode = KEY_E
	key.pressed = true
	return key


func _button(device: int) -> InputEventJoypadButton:
	var button := InputEventJoypadButton.new()
	button.device = device
	button.button_index = JOY_BUTTON_A
	button.pressed = true
	return button


func test_rumble() -> void:
	check(Settings.vibration and Settings.pause_away, "vibration and pause when away start on")
	Rumble.pad = -1
	Rumble.count = 0
	Rumble.play("fall")
	check(not Rumble.active() and Rumble.count == 0, "nothing rumbles while you're on the keyboard")
	Rumble.note(_button(1))
	check(Rumble.active() and Rumble.pad == 1, "pressing a gamepad button makes it the one that rumbles")
	Rumble.play("fall")
	check(Rumble.count == 1 and Rumble.last == "fall", "a fall rumbles it")
	Rumble.play("no such cue")
	check(Rumble.count == 1, "an unknown cue does nothing")
	var stick := InputEventJoypadMotion.new()
	stick.device = 1
	stick.axis_value = 0.1
	Rumble.note(_key())
	Rumble.note(stick)
	check(Rumble.pad == -1, "a key moves it back to the keyboard, and a resting stick doesn't count")
	Rumble.note(_button(0))
	Settings.vibration = false
	Rumble.play("fall")
	check(not Rumble.active() and Rumble.count == 1, "Vibration off: no rumble")
	Settings.vibration = true
	check(Settings.save() == OK, "the settings save")
	Settings.vibration = false
	Settings.pause_away = false
	Settings.load_settings()
	check(Settings.vibration and Settings.pause_away, "and load back")
	for cue: String in Rumble.CUES:
		var c: Array = Rumble.CUES[cue]
		if c.size() != 3 or c[0] < 0.0 or c[0] > 1.0 or c[1] < 0.0 or c[1] > 1.0 or c[2] <= 0.0 or c[2] > 0.5:
			check(false, "cue %s is a short rumble within the motors' range" % cue)
	Rumble.pad = -1


func test_look_away() -> void:
	var look := get_tree().get_first_node_in_group("look_away") as LookAway
	var pause := get_tree().get_first_node_in_group("pause_menu") as PauseMenu
	var player: Player = world.player
	check(look != null and pause != null, "the world has the look-away pause")
	if look == null or pause == null:
		return
	GameClock.paused = false
	player.can_act = true
	Settings.pause_away = false
	look.away()
	check(not pause.is_open() and not get_tree().paused and not GameClock.paused, "with Pause when away off, looking away changes nothing")
	Settings.pause_away = true
	look.away()
	check(pause.is_open() and GameClock.paused and not look.is_holding() and not get_tree().paused, "out walking, looking away opens the pause menu and stops the clock")
	look.away()
	check(pause.is_open() and not look.is_holding(), "looking away again with the menu open changes nothing")
	pause.close()
	check(not GameClock.paused and player.can_act, "closing the menu carries on")
	# in the middle of something (a climb, a conversation): the player can't act
	player.can_act = false
	look.away()
	check(look.is_holding() and get_tree().paused and look._card.visible and not pause.is_open(), "in the middle of something, the whole game holds under the Paused card")
	look._input(_key())
	check(look.is_holding(), "a press before the window is back doesn't carry on")
	look.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	var up := _key()
	up.pressed = false
	look._input(up)
	check(look.is_holding(), "letting a key go doesn't either")
	look._input(_button(0))
	check(not look.is_holding() and not get_tree().paused and not look._card.visible, "back at the window, a button carries on")
	check(not player.can_act, "and what you were doing is as you left it")
	player.can_act = true
