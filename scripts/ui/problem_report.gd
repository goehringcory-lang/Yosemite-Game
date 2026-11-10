class_name ProblemReport
extends CanvasLayer
## Report a problem: F8 anywhere in the game, or "Report a problem" in the
## pause menu. The game holds still, you type what happened (or nothing), and
## it writes one zip to the reports folder beside the saves, to send to
## whoever gave you the build. Nothing leaves the computer by itself.
##
## The zip holds: screenshot.png (the game as it was when you pressed the
## key), report.txt (your note, where and when you were, your quests, the
## computer and the settings), save.json (the saved game in your slot, if
## there is one) and godot.log (the game's own log of this session, where a
## script error would show). World adds one.
##
##   report.open()                    # the card
##   var path := report.write("note") # straight to a zip; "" if it failed

const DIR := "user://reports"
const KEY := KEY_F8
const TITLE := "Report a problem"
const ASK := "What happened? A few words help. You can leave it empty."
const WHAT := "Saves a picture of the screen, this note, your saved game and the game's log into one file on this computer. Nothing is sent anywhere."
const DONE := "Saved. Thank you! Send this file to whoever gave you the game:"
const FAILED := "The report couldn't be saved."
const CARD_WIDTH := 300.0
const NOTE_LENGTH := 400

## Where reports go. Tests point this at their own folder.
static var dir := DIR

var _card: PanelContainer
var _ask: Label
var _note: LineEdit
var _what: Label
var _footer: Label
var _open := false
## True once the zip is written and the card shows where it went.
var _saved := false
var _path := ""
var _shot: Image
## The tree was already paused when the card opened (leave it so).
var _was_paused := false
## The pause menu was open under the card (hidden for the picture).
var _pause_panel: Control


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("problem_report")
	UiScale.layer(self)
	_card = PanelContainer.new()
	_card.custom_minimum_size.x = CARD_WIDTH
	_card.visible = false
	add_child(_card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	_card.add_child(column)
	var title := Label.new()
	title.text = TITLE
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", PauseMenu.HEADING)
	column.add_child(title)
	_ask = _wrapped(ASK)
	column.add_child(_ask)
	_note = LineEdit.new()
	_note.max_length = NOTE_LENGTH
	_note.context_menu_enabled = false
	_note.text_submitted.connect(func(_text: String) -> void: save())
	column.add_child(_note)
	_what = _wrapped(WHAT)
	_what.add_theme_color_override("font_color", PauseMenu.DIM)
	column.add_child(_what)
	_footer = ButtonHints.new()
	_footer.add_theme_color_override("font_color", PauseMenu.DIM)
	column.add_child(_footer)


func _wrapped(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = CARD_WIDTH - 16.0
	return label


func is_open() -> bool:
	return _open


## Takes the picture, holds the game, and shows the card.
func open() -> void:
	if _open:
		return
	var look := get_tree().get_first_node_in_group("look_away") as LookAway
	if look and look.is_holding():
		return
	_open = true
	_saved = false
	_path = ""
	# the picture is of the game, not of the menu you came through
	var pause := get_tree().get_first_node_in_group("pause_menu") as PauseMenu
	_pause_panel = pause._panel if pause and pause.is_open() else null
	if _pause_panel:
		_pause_panel.visible = false
		await RenderingServer.frame_post_draw
	_shot = _screenshot()
	_was_paused = get_tree().paused
	get_tree().paused = true
	Rumble.stop()
	_note.text = ""
	_note.visible = true
	_ask.text = ASK
	_what.text = WHAT
	_card.visible = true
	_refresh()
	_note.grab_focus()
	Sound.play("ui_open")


func _screenshot() -> Image:
	if DisplayServer.get_name() == "headless":
		return null
	var texture := get_viewport().get_texture()
	return texture.get_image() if texture else null


## Writes the report with what's typed and shows where it went.
func save() -> void:
	if not _open or _saved:
		return
	_path = write(_note.text, _shot)
	_saved = true
	_note.release_focus()
	_note.visible = false
	_ask.text = FAILED if _path == "" else DONE
	_what.text = "" if _path == "" else ProjectSettings.globalize_path(_path)
	Sound.play("ui_select" if _path != "" else "ui_back")
	_refresh()


func close() -> void:
	if not _open:
		return
	_open = false
	_card.visible = false
	_note.release_focus()
	_shot = null
	get_tree().paused = _was_paused
	if _pause_panel and is_instance_valid(_pause_panel):
		_pause_panel.visible = true
	_pause_panel = null
	Sound.play("ui_close")


func _refresh() -> void:
	var tree := get_tree()
	var back := MenuInput.button(tree, "Esc", "B")
	if not _saved:
		_footer.text = "[%s] Save the report   [%s] Cancel" % [MenuInput.button(tree, "Enter", "A"), back]
	elif _path == "":
		_footer.text = "[%s] Back to the game" % back
	else:
		_footer.text = "[%s] Show the file   [%s] Back to the game" % [MenuInput.button(tree, "Enter", "A"), back]
	_card.reset_size()
	_card.position = ((UiScale.SCREEN - _card.get_combined_minimum_size()) / 2.0).round()


func _input(event: InputEvent) -> void:
	if not _open:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY:
			get_viewport().set_input_as_handled()
			open()
		return
	if not event.is_pressed() or event.is_echo():
		return
	var yes: bool = (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A) \
		or (_saved and event is InputEventKey and event.keycode in [KEY_ENTER, KEY_KP_ENTER])
	var no: bool = (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_B) \
		or (event is InputEventKey and event.keycode == KEY_ESCAPE)
	if no:
		get_viewport().set_input_as_handled()
		close()
	elif yes:
		get_viewport().set_input_as_handled()
		if not _saved:
			save()
		else:
			if _path != "":
				OS.shell_show_in_file_manager(ProjectSettings.globalize_path(_path))
			close()


func _exit_tree() -> void:
	if _open:
		get_tree().paused = _was_paused


# ---------------------------------------------------------------- the report

## Writes a report zip with [param note] and [param shot] (may be null) and
## returns its path, or "" if it couldn't be written.
func write(note: String, shot: Image = null) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var path := "%s/valley_days_report_%s.zip" % [dir, stamp]
	var n := 2
	while FileAccess.file_exists(path):
		path = "%s/valley_days_report_%s_%d.zip" % [dir, stamp, n]
		n += 1
	var zip := ZIPPacker.new()
	if zip.open(ProjectSettings.globalize_path(path)) != OK:
		return ""
	_add(zip, "report.txt", text(note).to_utf8_buffer())
	if shot != null and not shot.is_empty():
		_add(zip, "screenshot.png", shot.save_png_to_buffer())
	if FileAccess.file_exists(SaveManager.save_path):
		_add(zip, "save.json", FileAccess.get_file_as_bytes(SaveManager.save_path))
	var log_path := str(ProjectSettings.get_setting("debug/file_logging/log_path", "user://logs/godot.log"))
	if FileAccess.file_exists(log_path):
		_add(zip, "godot.log", FileAccess.get_file_as_bytes(log_path))
	return path if zip.close() == OK else ""


func _add(zip: ZIPPacker, name: String, bytes: PackedByteArray) -> void:
	if zip.start_file(name) == OK:
		zip.write_file(bytes)
		zip.close_file()


## report.txt: the note, then where the game was and what it's running on.
func text(note: String) -> String:
	var lines := PackedStringArray()
	lines.append("Valley Days problem report")
	lines.append("")
	lines.append("What happened: " + (note.strip_edges() if note.strip_edges() != "" else "(no note)"))
	lines.append("")
	lines.append("Written: " + Time.get_datetime_string_from_system(false, true))
	lines.append("Game version: " + str(ProjectSettings.get_setting("application/config/version", "")) + (" (debug build)" if OS.is_debug_build() else ""))
	lines.append("Engine: " + str(Engine.get_version_info().get("string", "")))
	lines.append("")
	lines.append("In the game")
	lines.append("  Date and time: %s, %s" % [GameClock.get_date_string(), GameClock.get_time_string()])
	var world := get_tree().get_first_node_in_group("world") if is_inside_tree() else null
	if world:
		var region: Region = world.region
		if region:
			lines.append("  Area: %s (%s)" % [region.display_name, region.region_id])
		var player: Player = world.player
		if player:
			lines.append("  Standing at: %d, %d   can act: %s" % [int(player.global_position.x), int(player.global_position.y), player.can_act])
	lines.append("  Save slot: %d" % SaveManager.slot)
	var goal := QuestLog.main_objective()
	if not goal.is_empty():
		lines.append("  Main goal: " + str(goal.get("objective", "")))
	var quests := PackedStringArray()
	for id: String in QuestLog.active:
		quests.append("%s (step %s)" % [id, str(QuestLog.active[id])])
	lines.append("  Quests under way: " + (", ".join(quests) if not quests.is_empty() else "none"))
	lines.append("")
	lines.append("The computer")
	lines.append("  System: %s (%s)" % [OS.get_name(), OS.get_distribution_name()])
	lines.append("  Processor: %s" % OS.get_processor_name())
	lines.append("  Graphics: %s, %s" % [RenderingServer.get_video_adapter_name(), Settings.renderer()])
	if is_inside_tree():
		lines.append("  Window: %d x %d" % [get_window().size.x, get_window().size.y])
	lines.append("  Controller in use: %s" % (Input.get_joy_name(Rumble.pad) if Rumble.pad >= 0 else "no, keyboard"))
	lines.append("")
	lines.append("Settings")
	lines.append("  Graphics: %s   Full screen: %s   Pixel font: %s" % [Settings.graphics_name(), Settings.fullscreen, Settings.pixel_font])
	lines.append("  Activity timing: %s   Hold to tap: %s   Text speed: %s" % [Settings.TIMING_NAMES[Settings.timing], Settings.hold_taps, Settings.TEXT_SPEED_NAMES[Settings.text_speed]])
	lines.append("  Vibration: %s   Pause when away: %s" % [Settings.vibration, Settings.pause_away])
	return "\n".join(lines) + "\n"
