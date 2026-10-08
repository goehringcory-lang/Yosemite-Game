class_name PauseMenu
extends CanvasLayer
## Esc (gamepad Start) pauses the game. World adds one. Three pages:
##   Main: Resume, Settings, Controls, Quit, and your current goal
##   Settings: text speed, full screen, window size, the goal panel, button prompts
##   Controls: every control, keyboard and gamepad
## Up/Down choose, E (A) selects, Left/Right change a setting, Esc (B) goes back.

signal closed

enum Page { MAIN, SETTINGS, CONTROLS }

const CONTROLS := [
	["Walk", "WASD or arrow keys", "Left stick or D-pad"],
	["Talk, read, use", "E, Space, X, C, or click", "A or X"],
	["Park and area map", "M (Tab switches tabs)", "Back (LB/RB switch tabs)"],
	["Journal", "J", "Y"],
	["Pause, settings", "Esc", "Start"],
	["Back out of a menu", "Esc", "B"],
	["Menus: choose, confirm", "Up/Down, E or Enter", "Stick or D-pad, A"],
	["Dialogue: show all, next", "E (twice)", "A (twice)"],
	["Climbing: move up", "W / Up (A, D: diagonal)", "Stick up / left / right"],
	["Climbing: place a cam or clip a bolt", "Space or C", "X"],
	["Climbing: eat, chalk up, retreat", "E / Esc", "A / B"],
	["Climbing: aid or jug", "Shift + arrow", "Y + stick"],
]
const OPTIONS := ["Resume", "Settings", "Controls", "Quit to desktop"]
const QUIT_CONFIRM := "Quit? Progress since you last slept is lost. Press again to quit."
enum Setting { TEXT_SPEED, FULLSCREEN, WINDOW_SIZE, OBJECTIVE, PROMPTS, BACK }
const SETTING_NAMES := ["Text speed", "Full screen", "Window size", "Goal on screen", "Button prompts", "Back"]
const SETTING_HELP := [
	"How fast conversations appear. Press E (A) to show a page at once.",
	"Fill the screen. The picture stays sharp in whole-pixel steps.",
	"The window's size, in whole steps of 480 x 270.",
	"Show your next main-story step under the clock.",
	"Which buttons hints name. Auto follows the last device you used.",
	"Back to the pause menu.",
]
## A line that plays at the chosen text speed while Text speed is selected.
const SPEED_SAMPLE := "Sample: The granite glows gold at dusk."
const HEADING := Color(1.0, 0.85, 0.5)
const DIM := Color(1, 1, 1, 0.6)
const PANEL_POS := Vector2(30, 16)
const PANEL_SIZE := Vector2(420, 238)
const NAME_WIDTH := 96

var _panel: PanelContainer
var _title: Label
var _footer: Label
var _pages: Array[Control] = []
var _page := Page.MAIN
var _option_labels: Array[Label] = []
var _goal_label: Label
var _setting_names: Array[Label] = []
var _setting_values: Array[Label] = []
var _help_label: Label
var _sample_label: Label
var _sample_shown := 0.0
var _device_headers: Array[Label] = []
var _cursor := 0
var _settings_cursor := 0
var _confirm_quit := false
var _was_paused := false
## The brass tab the page title sits on, the bar behind the chosen row, and the
## plain style every other row gets (it keeps the rows' text in the same place).
var _title_style: StyleBoxTexture
var _select_style: StyleBoxTexture
var _plain_style: StyleBoxEmpty


func _ready() -> void:
	layer = 28
	add_to_group("pause_menu")
	Settings.ensure_loaded()
	Settings.apply(get_window())
	_panel = PanelContainer.new()
	_panel.position = PANEL_POS
	_panel.custom_minimum_size = PANEL_SIZE
	_panel.size = PANEL_SIZE
	_panel.visible = false
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	_panel.add_child(column)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 20)
	_title.add_theme_color_override("font_color", HEADING)
	# a brass tab on the panel's top-left edge, the page's name sitting in it
	_title_style = _style("res://assets/ui/tag.png", 4.0)
	_title_style.content_margin_left = 6.0
	_title_style.content_margin_right = 6.0
	_title_style.expand_margin_top = 5.0
	_title_style.expand_margin_left = 2.0
	_title.add_theme_stylebox_override("normal", _title_style)
	_title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN # the tab hugs the title
	column.add_child(_title)
	_select_style = _style("res://assets/ui/select.png", 2.0)
	_select_style.content_margin_left = 2.0
	_select_style.expand_margin_top = 1.0
	_select_style.expand_margin_bottom = 1.0
	_plain_style = StyleBoxEmpty.new()
	_plain_style.content_margin_left = 2.0
	_pages.append(_build_main())
	_pages.append(_build_settings())
	_pages.append(_build_controls())
	for page in _pages:
		column.add_child(page)
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(filler)
	_footer = _label("", DIM)
	column.add_child(_footer)


## A nine-slice style from a texture, with its corners [param margin] pixels in.
func _style(path: String, margin: float) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(path)
	style.texture_margin_left = margin
	style.texture_margin_top = margin
	style.texture_margin_right = margin
	style.texture_margin_bottom = margin
	return style


func _build_main() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 2)
	for option in OPTIONS:
		var label := _label(option)
		page.add_child(label)
		_option_labels.append(label)
	page.add_child(_spacer(8))
	page.add_child(_label("Goal", HEADING))
	_goal_label = _label("")
	_goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_goal_label.custom_minimum_size.x = PANEL_SIZE.x - 16
	page.add_child(_goal_label)
	page.add_child(_spacer(4))
	page.add_child(_label("Your game saves when you sleep in your tent.", DIM))
	return page


func _build_settings() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 2)
	for i in SETTING_NAMES.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var name_label := _label(SETTING_NAMES[i])
		name_label.custom_minimum_size.x = NAME_WIDTH
		row.add_child(name_label)
		var value := _label("")
		row.add_child(value)
		page.add_child(row)
		_setting_names.append(name_label)
		_setting_values.append(value)
	page.add_child(_spacer(6))
	_help_label = _label("", DIM)
	_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help_label.custom_minimum_size.x = PANEL_SIZE.x - 16
	page.add_child(_help_label)
	_sample_label = _label(SPEED_SAMPLE)
	page.add_child(_sample_label)
	page.add_child(_spacer(2))
	page.add_child(_label("Settings save as soon as you change them.", DIM))
	return page


func _build_controls() -> Control:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 0)
	grid.add_child(_label(""))
	for header in ["Keyboard and mouse", "Gamepad"]:
		var label := _label(header, HEADING)
		grid.add_child(label)
		_device_headers.append(label)
	for row: Array in CONTROLS:
		grid.add_child(_label(row[0], HEADING))
		grid.add_child(_label(row[1]))
		grid.add_child(_label(row[2]))
	return grid


func is_open() -> bool:
	return _panel.visible


func open() -> void:
	if is_open():
		return
	_cursor = 0
	_confirm_quit = false
	var hud := get_tree().get_first_node_in_group("hud") as HUD
	if hud and not hud.device_changed.is_connected(_refresh):
		hud.device_changed.connect(_refresh)
	_show_page(Page.MAIN)
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


## The page showing now (Page.MAIN, SETTINGS or CONTROLS).
func page() -> Page:
	return _page


func _show_page(which: Page) -> void:
	_page = which
	for i in _pages.size():
		_pages[i].visible = i == which
	_title.text = ["Paused", "Settings", "Controls"][which]
	if which == Page.SETTINGS:
		_settings_cursor = 0
		_restart_sample()
	_refresh()


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
		if _page == Page.MAIN:
			close()
		else:
			_cursor = OPTIONS.find(["", "Settings", "Controls"][_page])
			_show_page(Page.MAIN)
		return
	match _page:
		Page.MAIN:
			_main_input(event)
		Page.SETTINGS:
			_settings_input(event)


func _main_input(event: InputEvent) -> void:
	var step := MenuInput.vertical(event)
	if step != 0:
		_cursor = wrapi(_cursor + step, 0, OPTIONS.size())
		_confirm_quit = false
		_refresh()
	elif MenuInput.confirm(event):
		match _cursor:
			0:
				close()
			1:
				_show_page(Page.SETTINGS)
			2:
				_show_page(Page.CONTROLS)
			3:
				if _confirm_quit:
					get_tree().quit()
				else:
					_confirm_quit = true
					_refresh()


func _settings_input(event: InputEvent) -> void:
	var step := MenuInput.vertical(event)
	if step != 0:
		_settings_cursor = wrapi(_settings_cursor + step, 0, SETTING_NAMES.size())
		_restart_sample()
		_refresh()
		return
	var change := MenuInput.horizontal(event)
	if change == 0 and MenuInput.confirm(event):
		if _settings_cursor == Setting.BACK:
			_cursor = OPTIONS.find("Settings")
			_show_page(Page.MAIN)
			return
		change = 1
	if change != 0:
		change_setting(_settings_cursor, change)


## Steps setting [param which] (a Setting) by [param step], then saves and applies it.
func change_setting(which: int, step: int) -> void:
	match which:
		Setting.TEXT_SPEED:
			Settings.text_speed = wrapi(Settings.text_speed + step, 0, Settings.TextSpeed.size()) as Settings.TextSpeed
			_restart_sample()
		Setting.FULLSCREEN:
			Settings.fullscreen = not Settings.fullscreen
		Setting.WINDOW_SIZE:
			if Settings.fullscreen:
				return
			Settings.window_scale = clampi(Settings.window_scale + step, Settings.MIN_SCALE, Settings.max_window_scale())
		Setting.OBJECTIVE:
			Settings.show_objective = not Settings.show_objective
		Setting.PROMPTS:
			Settings.prompts = wrapi(Settings.prompts + step, 0, Settings.Prompts.size()) as Settings.Prompts
		_:
			return
	Settings.save()
	Settings.apply(get_window())
	var hud := get_tree().get_first_node_in_group("hud") as HUD
	if hud:
		hud.refresh_settings()
	_refresh()


func _process(delta: float) -> void:
	if not is_open() or _page != Page.SETTINGS or not _sample_label.visible:
		return
	var cps := Settings.chars_per_second()
	if cps <= 0.0 or _sample_shown >= SPEED_SAMPLE.length():
		_sample_label.visible_characters = -1
		return
	_sample_shown += delta * cps
	_sample_label.visible_characters = int(_sample_shown)


func _restart_sample() -> void:
	_sample_shown = 0.0
	_sample_label.visible_characters = 0 if Settings.chars_per_second() > 0.0 else -1


func _refresh() -> void:
	for i in _option_labels.size():
		var text: String = OPTIONS[i]
		if i == 3 and _confirm_quit:
			text = QUIT_CONFIRM
		_set_choice(_option_labels[i], text, i == _cursor)
	_goal_label.text = HUD.objective_text() if HUD.objective_text() != "" else "Explore, and talk to people around the valley."
	for i in _setting_names.size():
		_set_choice(_setting_names[i], SETTING_NAMES[i], i == _settings_cursor)
		_setting_values[i].text = _setting_value(i)
		_setting_values[i].modulate = DIM if i == Setting.WINDOW_SIZE and Settings.fullscreen else Color.WHITE
	_help_label.text = SETTING_HELP[_settings_cursor]
	_sample_label.visible = _settings_cursor == Setting.TEXT_SPEED
	# Mark the column for the device in use, in words as well as color.
	var gamepad := MenuInput.button(get_tree(), "k", "g") == "g"
	_device_headers[0].text = "Keyboard and mouse" + ("" if gamepad else " (in use)")
	_device_headers[1].text = "Gamepad" + (" (in use)" if gamepad else "")
	_device_headers[0].modulate = DIM if gamepad else Color.WHITE
	_device_headers[1].modulate = Color.WHITE if gamepad else DIM
	_footer.text = _footer_text()


## "< Normal >" for a setting's current value.
func _setting_value(which: int) -> String:
	var value := ""
	match which:
		Setting.TEXT_SPEED:
			value = Settings.TEXT_SPEED_NAMES[Settings.text_speed]
		Setting.FULLSCREEN:
			value = "On" if Settings.fullscreen else "Off"
		Setting.WINDOW_SIZE:
			if Settings.fullscreen:
				return "(full screen)"
			value = "%dx  (%d x %d)" % [Settings.window_scale, Settings.BASE_SIZE.x * Settings.window_scale, Settings.BASE_SIZE.y * Settings.window_scale]
		Setting.OBJECTIVE:
			value = "On" if Settings.show_objective else "Off"
		Setting.PROMPTS:
			value = Settings.PROMPT_NAMES[Settings.prompts]
		_:
			return ""
	return "<  %s  >" % value


func _footer_text() -> String:
	var tree := get_tree()
	var choose := MenuInput.button(tree, "Up/Down", "D-pad")
	var ok := MenuInput.button(tree, "E", "A")
	var back := MenuInput.button(tree, "Esc", "B")
	match _page:
		Page.SETTINGS:
			return "[%s] Choose   [%s] Change   [%s] Back" % [choose, MenuInput.button(tree, "Left/Right", "D-pad L/R"), back]
		Page.CONTROLS:
			return "[%s] Back" % back
	return "[%s] Choose   [%s] Select   [%s] Resume" % [choose, ok, back]


## A menu line: "> ", gold and a highlight bar when chosen, so it shows without the color too.
func _set_choice(label: Label, text: String, chosen: bool) -> void:
	label.text = ("> " if chosen else "  ") + text
	label.add_theme_color_override("font_color", HEADING if chosen else Color.WHITE)
	label.add_theme_stylebox_override("normal", _select_style if chosen else _plain_style)


func _label(text: String, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	return label


func _spacer(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	return spacer


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
