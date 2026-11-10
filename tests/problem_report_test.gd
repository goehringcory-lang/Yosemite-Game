extends Node
## Headless test of Report a problem (ProblemReport): F8 and the pause menu
## row open the card and hold the game, Esc closes it as it was, and saving
## writes one zip with the note, where you were, the save and the log.
## Run: godot --headless --path . res://tests/problem_report_test.tscn
## Exit code is the number of failed checks. Uses its own folder and save.

const TEST_DIR := "user://problem_report_test"

var failures := 0
var world: Node


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	await get_tree().process_frame
	ProblemReport.dir = TEST_DIR
	_clear()
	SaveManager.save_path = "user://problem_report_test_save.json"
	SaveManager.delete_save()
	world = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	await test_card()
	test_zip()
	get_tree().paused = false
	world.queue_free()
	SaveManager.delete_save()
	_clear()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func _clear() -> void:
	var path := ProjectSettings.globalize_path(TEST_DIR)
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path + "/" + f)
	DirAccess.remove_absolute(path)


func _key(code: Key) -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = code
	key.physical_keycode = code
	key.pressed = true
	return key


func _reports() -> PackedStringArray:
	return DirAccess.get_files_at(ProjectSettings.globalize_path(TEST_DIR))


func test_card() -> void:
	var report := get_tree().get_first_node_in_group("problem_report") as ProblemReport
	var pause := get_tree().get_first_node_in_group("pause_menu") as PauseMenu
	check(report != null and pause != null, "the world has Report a problem")
	if report == null or pause == null:
		return
	report._input(_key(KEY_F8))
	await get_tree().process_frame
	check(report.is_open() and report._card.visible and get_tree().paused, "F8 opens the card and holds the game")
	report._input(_key(KEY_ESCAPE))
	check(not report.is_open() and not get_tree().paused and _reports().is_empty(), "Esc closes it, writes nothing, and the game carries on")
	pause.open()
	pause._cursor = PauseMenu.Option.REPORT
	pause._main_input(_key(KEY_ENTER))
	await get_tree().process_frame
	await get_tree().process_frame
	check(report.is_open() and not pause._panel.visible, "the pause menu's row opens it, the menu out of the picture")
	report._note.text = "The bear walked through a wall"
	report.save()
	check(report._saved and report._path != "" and _reports().size() == 1, "saving writes one report")
	check(not report._note.visible and report._what.text.ends_with(".zip"), "and the card says where it is")
	report._input(_key(KEY_ESCAPE))
	check(not report.is_open() and pause.is_open() and pause._panel.visible and get_tree().paused == false, "closing goes back to the pause menu")
	pause.close()
	var look := get_tree().get_first_node_in_group("look_away") as LookAway
	world.player.can_act = false
	look.away()
	report._input(_key(KEY_F8))
	check(not report.is_open(), "it doesn't open over the Paused card")
	look.carry_on()
	world.player.can_act = true


func test_zip() -> void:
	var report := get_tree().get_first_node_in_group("problem_report") as ProblemReport
	SaveManager.save_game()
	var shot := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	shot.fill(Color.RED)
	var path := report.write("Stuck on the ledge", shot)
	check(path != "" and FileAccess.file_exists(path), "write() makes a zip")
	var zip := ZIPReader.new()
	check(zip.open(ProjectSettings.globalize_path(path)) == OK, "that opens")
	var files := zip.get_files()
	check("report.txt" in files and "screenshot.png" in files and "save.json" in files, "with the note, the picture and the save")
	var text := zip.read_file("report.txt").get_string_from_utf8()
	check(text.contains("What happened: Stuck on the ledge"), "the note is in it")
	check(text.contains("Area: ") and text.contains("Date and time: ") and text.contains("Quests under way: "), "and where and when you were, and your quests")
	check(text.contains("System: ") and text.contains("Activity timing: "), "and the computer and the settings")
	var png := Image.new()
	check(png.load_png_from_buffer(zip.read_file("screenshot.png")) == OK and png.get_pixel(0, 0) == Color.RED, "the picture is the one taken")
	check(zip.read_file("save.json").size() == FileAccess.get_file_as_bytes(SaveManager.save_path).size(), "the save is the slot's")
	zip.close()
	check(report.text("   ").contains("(no note)"), "an empty note says so")
	var again := report.write("", null)
	check(again != path and FileAccess.file_exists(again), "a second report in the same second gets its own file")
