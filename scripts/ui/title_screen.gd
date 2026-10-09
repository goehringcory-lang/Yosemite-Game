class_name TitleScreen
extends Control
## The first screen: the game's name over a painted view of the Valley, and
## Continue (when there is a save), New Game, Settings, Credits and Quit.
## Up/Down choose, E (A) or Enter selects. Settings opens the pause menu's
## Settings page on its own; Credits opens the credits.
##
## The view is painted when the screen opens by the climbing screen's painters
## (climb_sky.gd, climb_landscape.gd), the way the Valley looks from the Tunnel
## View at golden hour: El Capitan, Half Dome far off, Bridalveil Fall.

const WORLD_SCENE := "res://scenes/world/world.tscn"
const SCREEN := Vector2(480, 270)
const HOUR := 18.4
const VIEW := {
	"ground": "valley_forest",
	"view": [
		{"k": "sierra_crest", "x": 250, "s": 1.0, "l": 2},
		{"k": "half_dome", "x": 336, "s": 0.85, "l": 0},
		{"k": "el_capitan", "x": 84, "s": 1.35, "l": 1},
		{"k": "cathedral_rocks", "x": 440, "s": 1.1, "l": 1},
		{"k": "bridalveil", "x": 392, "s": 1.0, "l": 1},
	],
}
## How far up the wall the view is painted from (0 is the climbing screen's
## first move, 1 the top): sets how high the landmarks stand.
const VIEW_HEIGHT := 0.55
const SEED := 1864 # the year of the Yosemite Grant

enum Option { CONTINUE, NEW_GAME, SETTINGS, CREDITS, QUIT }
const OPTION_NAMES := ["Continue", "New Game", "Settings", "Credits", "Quit"]
const NEW_GAME_CONFIRM := "Start over? Press again. (Your saved game is replaced when you first sleep.)"
const HEADING := Color(1.0, 0.85, 0.5)
const DIM := Color(1, 1, 1, 0.6)
const MENU_POS := Vector2(176, 128)
const MENU_WIDTH := 128.0

var _options: Array[int] = []
var _labels: Array[Label] = []
var _cursor := 0
var _confirm_new := false
var _starting := false
var _time := 0.0
var _sky: Texture2D
var _layers: Array[Dictionary] = []
var _falls: Array[Dictionary] = []
var _clouds: Array[Texture2D] = []
var _menu: PanelContainer
var _hint: Label
var _footer: Label
var _fade: ColorRect
var _select_style: StyleBoxTexture
var _plain_style: StyleBoxEmpty
var _pause: PauseMenu
var _credits: Credits


func _ready() -> void:
	add_to_group("title_screen")
	size = SCREEN
	Settings.ensure_loaded()
	Settings.apply(get_window())
	_paint_view()
	_build_title()
	_build_menu()
	_pause = PauseMenu.new()
	_pause.closed.connect(_refresh)
	add_child(_pause)
	_credits = Credits.new()
	_credits.closed.connect(_refresh)
	add_child(_credits)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.size = SCREEN
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 0.6)
	Sound.set_ambience("title")
	_refresh()


func _paint_view() -> void:
	var pal := ClimbSky.palette(HOUR)
	_sky = ImageTexture.create_from_image(ClimbSky.sky(pal))
	var land := ClimbLandscape.build(VIEW, pal, SEED)
	for layer: Dictionary in land.layers:
		_layers.append({"tex": ImageTexture.create_from_image(layer.image), "sink": layer.sink, "pad": layer.pad})
	_falls = land.falls
	for i in 3:
		_clouds.append(ImageTexture.create_from_image(ClimbSky.cloud(pal, SEED + i)))


func _build_title() -> void:
	var title := Label.new()
	title.text = ProjectSettings.get_setting("application/config/name")
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", HEADING)
	title.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.06))
	title.add_theme_constant_override("outline_size", 6)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 26)
	title.size = Vector2(SCREEN.x, 48)
	add_child(title)
	var tagline := Label.new()
	tagline.text = ProjectSettings.get_setting("application/config/description")
	tagline.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.06))
	tagline.add_theme_constant_override("outline_size", 4)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.position = Vector2(0, 72)
	tagline.size = Vector2(SCREEN.x, 16)
	add_child(tagline)


func _build_menu() -> void:
	_select_style = StyleBoxTexture.new()
	_select_style.texture = load("res://assets/ui/select.png")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_select_style.set_texture_margin(side, 2.0)
	_select_style.content_margin_left = 2.0
	_select_style.expand_margin_top = 1.0
	_select_style.expand_margin_bottom = 1.0
	_plain_style = StyleBoxEmpty.new()
	_plain_style.content_margin_left = 2.0
	_menu = PanelContainer.new()
	_menu.position = MENU_POS
	_menu.custom_minimum_size.x = MENU_WIDTH
	add_child(_menu)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	_menu.add_child(column)
	if SaveManager.has_save():
		_options.append(Option.CONTINUE)
	_options.append_array([Option.NEW_GAME, Option.SETTINGS, Option.CREDITS, Option.QUIT])
	for option in _options:
		var label := Label.new()
		column.add_child(label)
		_labels.append(label)
	_hint = Label.new()
	_hint.add_theme_color_override("font_color", HEADING)
	_hint.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.06))
	_hint.add_theme_constant_override("outline_size", 4)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.position = Vector2(40, 228)
	_hint.size = Vector2(SCREEN.x - 80, 16)
	add_child(_hint)
	_footer = Label.new()
	_footer.modulate = DIM
	_footer.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.06))
	_footer.add_theme_constant_override("outline_size", 4)
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer.position = Vector2(0, SCREEN.y - 18)
	_footer.size = Vector2(SCREEN.x, 16)
	add_child(_footer)


## The options on the menu now, in order (Continue only with a save).
func options() -> Array[int]:
	return _options


func cursor_option() -> int:
	return _options[_cursor]


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	draw_texture(_sky, Vector2.ZERO)
	for i in _clouds.size():
		var x := fposmod(60.0 + i * 170.0 + _time * (2.0 + i * 1.2), SCREEN.x + 140.0) - 70.0
		draw_texture(_clouds[i], Vector2(x, 14.0 + i * 22.0).round(), Color(1, 1, 1, 0.9))
	for layer: Dictionary in _layers:
		draw_texture(layer.tex, Vector2(0, roundf(VIEW_HEIGHT * layer.sink) - layer.pad))
	# Bridalveil shimmers, as on the climbing screen.
	for f: Dictionary in _falls:
		var layer: Dictionary = _layers[f.layer]
		var off: float = roundf(VIEW_HEIGHT * layer.sink) - float(layer.pad)
		for y in range(int(f.y0) + 2, int(f.y1), 3):
			var pos := Vector2(f.x + 1 + int(sin(_time * 3.0 + y * 0.3) * 1.2), y + off)
			if fmod(_time * 7.0 + y * 0.21, 3.0) < 1.0:
				draw_rect(Rect2(pos, Vector2(1, 2)), Color(1, 1, 1, 0.8))


func _unhandled_input(event: InputEvent) -> void:
	if _starting or _pause.is_open() or _credits.is_open():
		return
	var step := MenuInput.vertical(event)
	if step != 0:
		get_viewport().set_input_as_handled()
		_cursor = wrapi(_cursor + step, 0, _options.size())
		_confirm_new = false
		Sound.play("ui_move")
		_refresh()
	elif MenuInput.confirm(event):
		get_viewport().set_input_as_handled()
		select(cursor_option())
	elif event.is_action_pressed("ui_cancel") and _confirm_new:
		get_viewport().set_input_as_handled()
		_confirm_new = false
		Sound.play("ui_back")
		_refresh()


## Does what the menu option does (Option.CONTINUE, NEW_GAME, ...).
func select(option: int) -> void:
	_cursor = maxi(_options.find(option), 0)
	match option:
		Option.CONTINUE:
			Sound.play("ui_select")
			_start()
		Option.NEW_GAME:
			Sound.play("ui_select")
			if SaveManager.has_save() and not _confirm_new:
				_confirm_new = true
				_refresh()
				return
			SaveManager.start_fresh()
			_start()
		Option.SETTINGS:
			Sound.play("ui_select")
			_pause.open_settings()
		Option.CREDITS:
			Sound.play("ui_select")
			_credits.open()
		Option.QUIT:
			get_tree().quit()
	_refresh()


func _start() -> void:
	_starting = true
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.5)
	await tween.finished
	get_tree().change_scene_to_file(WORLD_SCENE)


func _refresh() -> void:
	var covered := _pause.is_open() or _credits.is_open()
	_menu.visible = not covered
	_hint.visible = not covered
	_footer.visible = not covered
	for i in _labels.size():
		var chosen := i == _cursor
		_labels[i].text = ("> " if chosen else "  ") + OPTION_NAMES[_options[i]]
		_labels[i].add_theme_color_override("font_color", HEADING if chosen else Color.WHITE)
		_labels[i].add_theme_stylebox_override("normal", _select_style if chosen else _plain_style)
	_hint.text = NEW_GAME_CONFIRM if _confirm_new else ""
	var tree := get_tree()
	_footer.text = "[%s] Choose   [%s] Select" % [MenuInput.button(tree, "Up/Down", "D-pad"), MenuInput.button(tree, "E", "A")]
