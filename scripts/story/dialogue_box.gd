class_name DialogueBox
extends CanvasLayer
## The conversation box at the bottom of the screen. Shows lines one at a
## time and can offer a list of choices.
##
##   var box := DialogueBox.open(player)
##   await box.say(lines)             # lines: [{"speaker": "...", "text": "..."}]
##   var i := await box.choose("Build it?", ["Yes", "No"])   # -1 if cancelled
##   box.close()
##
## Or, for a one-off conversation: DialogueBox.say_to(player, lines)

const NAME_COLOR := Color(1.0, 0.85, 0.5)
const CURSOR := "> "

var _name_label: Label
var _text_label: Label
var _options_box: VBoxContainer
var _options: PackedStringArray = []
var _cursor := 0
var _opened_frame := 0
## 0 while waiting, 1 after confirm, -1 after cancel.
var _answer := 0


## Creates a box on top of everything and returns it.
static func open(from: Node) -> DialogueBox:
	var box := DialogueBox.new()
	from.get_tree().root.add_child(box)
	return box


## Shows [param lines] with the player frozen, then closes the box.
static func say_to(player: Player, lines: Array) -> void:
	if lines.is_empty():
		return
	player.can_act = false
	var box := open(player)
	await box.say(lines)
	box.close()
	player.can_act = true


func _ready() -> void:
	layer = 30
	add_to_group("dialogue_box")
	_opened_frame = Engine.get_process_frames()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var panel := PanelContainer.new()
	panel.position = Vector2(8, 184)
	panel.custom_minimum_size = Vector2(464, 78)
	root.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 1)
	panel.add_child(column)
	_name_label = Label.new()
	_name_label.add_theme_color_override("font_color", NAME_COLOR)
	column.add_child(_name_label)
	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(456, 0)
	column.add_child(_text_label)
	_options_box = VBoxContainer.new()
	_options_box.add_theme_constant_override("separation", 0)
	column.add_child(_options_box)


func say(lines: Array) -> void:
	for line: Dictionary in lines:
		_show(line.get("speaker", ""), line.get("text", ""), [])
		await _next_input()


## Returns the chosen option's index, or -1 if the player cancels.
func choose(prompt: String, options: Array, speaker := "") -> int:
	_cursor = 0
	_show(speaker, prompt, options)
	var confirmed: bool = await _next_input()
	var picked := _cursor if confirmed else -1
	_show("", "", [])
	return picked


func close() -> void:
	queue_free()


func _show(speaker: String, text: String, options: Array) -> void:
	_name_label.text = speaker
	_name_label.visible = speaker != ""
	_text_label.text = text
	_options = PackedStringArray(options)
	_refresh_options()


func _refresh_options() -> void:
	for child in _options_box.get_children():
		_options_box.remove_child(child)
		child.queue_free()
	for i in _options.size():
		var label := Label.new()
		label.text = (CURSOR if i == _cursor else "  ") + _options[i]
		if i == _cursor:
			label.add_theme_color_override("font_color", NAME_COLOR)
		_options_box.add_child(label)


## Waits for confirm (true) or cancel (false).
func _next_input() -> bool:
	_answer = 0
	while _answer == 0:
		await get_tree().process_frame
	return _answer == 1


func _input(event: InputEvent) -> void:
	# Ignore the key press that opened the box.
	if Engine.get_process_frames() == _opened_frame:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("use_tool") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_answer = 1
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_answer = -1
	elif not _options.is_empty() and (event.is_action_pressed("move_up") or event.is_action_pressed("ui_up")):
		get_viewport().set_input_as_handled()
		_cursor = wrapi(_cursor - 1, 0, _options.size())
		_refresh_options()
	elif not _options.is_empty() and (event.is_action_pressed("move_down") or event.is_action_pressed("ui_down")):
		get_viewport().set_input_as_handled()
		_cursor = wrapi(_cursor + 1, 0, _options.size())
		_refresh_options()


## For tests: act as if the player pressed confirm (true) or cancel (false).
func press(confirm := true) -> void:
	_answer = 1 if confirm else -1
