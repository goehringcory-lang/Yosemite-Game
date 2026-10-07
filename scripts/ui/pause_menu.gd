class_name PauseMenu
extends CanvasLayer
## Esc (gamepad Start) pauses the game and shows every control. World adds one.

signal closed

const CONTROLS := [
	["Walk", "WASD or arrow keys", "Left stick or D-pad"],
	["Talk, read, use", "E, Space, X, C, or click", "A or X"],
	["Park and area map", "M (Tab switches tabs)", "Back (LB/RB switch tabs)"],
	["Journal", "J", "Y"],
	["Pause and controls", "Esc", "Start"],
	["Back out of a menu", "Esc", "B"],
	["Menus: choose, confirm", "Up/Down, E or Enter", "Stick or D-pad, A"],
	["Climbing: move up", "W / Up (A, D: diagonal)", "Stick up / left / right"],
	["Climbing: place a cam or clip a bolt", "Space or C", "X"],
	["Climbing: eat, chalk up, retreat", "E / Esc", "A / B"],
	["Climbing: aid or jug", "Shift + arrow", "Y + stick"],
]
const OPTIONS := ["Resume", "Quit to desktop"]
const HEADING := Color(1.0, 0.85, 0.5)
const DIM := Color(1, 1, 1, 0.6)

var _panel: PanelContainer
var _option_labels: Array[Label] = []
var _cursor := 0
var _was_paused := false


func _ready() -> void:
	layer = 28
	add_to_group("pause_menu")
	_panel = PanelContainer.new()
	_panel.position = Vector2(30, 16)
	_panel.custom_minimum_size = Vector2(420, 238)
	_panel.visible = false
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	_panel.add_child(column)
	var title := Label.new()
	title.text = "Paused"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", HEADING)
	column.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 0)
	column.add_child(grid)
	for header in ["", "Keyboard and mouse", "Gamepad"]:
		grid.add_child(_label(header, HEADING))
	for row: Array in CONTROLS:
		grid.add_child(_label(row[0], HEADING))
		grid.add_child(_label(row[1]))
		grid.add_child(_label(row[2]))
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 4
	column.add_child(spacer)
	for option in OPTIONS:
		var label := _label(option)
		column.add_child(label)
		_option_labels.append(label)
	column.add_child(_label("Your game saves when you sleep in your tent.", DIM))


func is_open() -> bool:
	return _panel.visible


func open() -> void:
	if is_open():
		return
	_cursor = 0
	_refresh()
	_panel.visible = true
	_was_paused = GameClock.paused
	GameClock.paused = true
	_set_player_can_act(false)


func close() -> void:
	if not is_open():
		return
	_panel.visible = false
	GameClock.paused = _was_paused
	_set_player_can_act(true)
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		if event.is_action_pressed("pause") and _player_can_act():
			get_viewport().set_input_as_handled()
			var hud := get_tree().get_first_node_in_group("hud") as HUD
			if hud and hud.info_panel.visible:
				hud.hide_info() # Esc closes the sign you're reading first
			else:
				open()
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
	elif MenuInput.pressed(event, "move_up") or MenuInput.pressed(event, "ui_up"):
		_cursor = wrapi(_cursor - 1, 0, OPTIONS.size())
		_refresh()
	elif MenuInput.pressed(event, "move_down") or MenuInput.pressed(event, "ui_down"):
		_cursor = wrapi(_cursor + 1, 0, OPTIONS.size())
		_refresh()
	elif event.is_action_pressed("interact") or event.is_action_pressed("use_tool") or event.is_action_pressed("ui_accept"):
		if _cursor == 0:
			close()
		else:
			get_tree().quit()


func _refresh() -> void:
	for i in _option_labels.size():
		_option_labels[i].text = ("> " if i == _cursor else "  ") + OPTIONS[i]
		_option_labels[i].modulate = HEADING if i == _cursor else Color.WHITE


func _label(text: String, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	return label


func _player() -> Player:
	var world := get_tree().get_first_node_in_group("world")
	return world.player if world else null


func _player_can_act() -> bool:
	var player := _player()
	return player != null and player.can_act


func _set_player_can_act(value: bool) -> void:
	var player := _player()
	if player:
		player.can_act = value
