class_name TitleScreen
extends Control
## The first screen: the game's name over a painted view of the Valley, and
## Continue (when there is a save), New Game, Settings, Credits and Quit.
## Up/Down choose, E (A) or Enter selects. Settings opens the pause menu's
## Settings page on its own; Credits opens the credits.
##
## Behind it all is a pixel painting of the Valley (assets/ui/title_background.png):
## El Capitan, Half Dome far off, Bridalveil Fall, which shimmers.

const WORLD_SCENE := "res://scenes/world/world.tscn"
const SCREEN := Vector2(480, 270)
const BACKGROUND := "res://assets/ui/title_background.png"
## Where Bridalveil Fall is in the background, for the shimmer: the middle of
## the water at its lip and where it meets the mist, and its half width there.
const FALL_TOP := Vector2(437, 141)
const FALL_BOTTOM := Vector2(429, 203)
const FALL_HALF_WIDTH := Vector2(2.5, 4.0)

enum Option { CONTINUE, NEW_GAME, SETTINGS, CREDITS, QUIT }
const OPTION_NAMES := ["Continue", "New Game", "Settings", "Credits", "Quit"]
const NEW_GAME_CONFIRM := "Start over? Press again. (Your saved game is replaced when you first sleep.)"
const HEADING := Color(1, 0.831, 0.541)
const DIM := Color(0.961, 0.933, 0.878, 0.6)
const MENU_POS := Vector2(176, 128)
const MENU_WIDTH := 128.0

var _options: Array[int] = []
var _labels: Array[Label] = []
var _cursor := 0
var _confirm_new := false
var _starting := false
var _time := 0.0
var _shimmer: Control
var _menu: PanelContainer
var _hint: Label
var _footer: Label
var _footer_band: PanelContainer
var _fade: ColorRect
var _select_style: StyleBoxTexture
var _plain_style: StyleBoxEmpty
var _pause: PauseMenu
var _credits: Credits


func _ready() -> void:
	add_to_group("title_screen")
	size = SCREEN
	scale = Vector2(UiScale.FACTOR, UiScale.FACTOR)
	Settings.ensure_loaded()
	Settings.apply(get_window())
	_build_background()
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


func _build_background() -> void:
	var background := TextureRect.new()
	background.texture = load(BACKGROUND)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE # the painting is 32px-grade (960x540)
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.size = SCREEN
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	# Drawn on its own node so it stays above the background.
	_shimmer = Control.new()
	_shimmer.size = SCREEN
	_shimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shimmer.draw.connect(_draw_shimmer)
	add_child(_shimmer)


## The logo: the name in carved gold letters, a deep dark extrusion under
## them, a lighter gold on the top half of each letter like a sign catching
## the sun, and a small pixel divider above the tagline.
const LOGO_TOP := 22.0
const LOGO_SIZE := 38
const GOLD_LIGHT := Color("ffd48a")
const GOLD_DEEP := Color("d8a63b")
const LOGO_INK := Color("2a1b14")
const LOGO_EXTRUDE := Color("6b4829")


func _logo_label(text: String, color: Color, outline: int, at: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", LOGO_SIZE)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", LOGO_INK)
	label.add_theme_constant_override("outline_size", outline)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = at
	label.size = Vector2(SCREEN.x, 50)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _build_title() -> void:
	var name: String = ProjectSettings.get_setting("application/config/name")
	# the extrusion: the letters stacked downward in dark wood
	for dy in [4, 3, 2]:
		add_child(_logo_label(name, LOGO_EXTRUDE, 8, Vector2(0, LOGO_TOP + dy)))
	add_child(_logo_label(name, GOLD_DEEP, 6, Vector2(0, LOGO_TOP)))
	# the lit top half of each letter, clipped to the upper part of the line
	var lit := Control.new()
	lit.clip_contents = true
	lit.position = Vector2(0, LOGO_TOP)
	lit.size = Vector2(SCREEN.x, 27)
	lit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lit.add_child(_logo_label(name, GOLD_LIGHT, 0, Vector2.ZERO))
	add_child(lit)
	# a divider: two gold rules either side of a small diamond
	var divider := Control.new()
	divider.position = Vector2(SCREEN.x / 2.0 - 60, LOGO_TOP + 56)
	divider.size = Vector2(120, 5)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.draw.connect(func() -> void:
		for side in [Rect2(0, 2, 52, 1), Rect2(68, 2, 52, 1)]:
			divider.draw_rect(side.grow(1), LOGO_INK)
			divider.draw_rect(side, GOLD_DEEP)
		var d := PackedVector2Array([Vector2(60, -1), Vector2(64, 3), Vector2(60, 7), Vector2(56, 3)])
		divider.draw_colored_polygon(d, LOGO_INK)
		divider.draw_colored_polygon(PackedVector2Array([Vector2(60, 0), Vector2(63, 3), Vector2(60, 6), Vector2(57, 3)]), GOLD_LIGHT))
	add_child(divider)
	var tagline := Label.new()
	tagline.text = ProjectSettings.get_setting("application/config/description")
	_on_band(tagline, LOGO_TOP + 63)


## Sets [param label] on a soft dark band across the picture at [param y], so
## its letters stay crisp over the busy painting without a heavy outline.
func _on_band(label: Label, y: float) -> PanelContainer:
	var band := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.165, 0.106, 0.078, 0.62)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 0.0
	style.content_margin_bottom = 1.0
	band.add_theme_stylebox_override("panel", style)
	label.add_theme_color_override("font_outline_color", Color(0.165, 0.106, 0.078))
	label.add_theme_constant_override("outline_size", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	band.add_child(label)
	band.position.y = y
	# centred whenever it knows its width
	var centre := func() -> void: band.position.x = roundf((SCREEN.x - band.size.x) / 2.0)
	band.resized.connect(centre)
	add_child(band)
	centre.call_deferred()
	return band


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
	# a little more room under the last line, clear of the frame
	var frame := _menu.get_theme_stylebox("panel").duplicate() as StyleBox
	frame.content_margin_bottom = 7.0
	frame.content_margin_top = 5.0
	_menu.add_theme_stylebox_override("panel", frame)
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
	_hint.add_theme_color_override("font_outline_color", Color(0.165, 0.106, 0.078))
	_hint.add_theme_constant_override("outline_size", 2)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.position = Vector2(40, 228)
	_hint.size = Vector2(SCREEN.x - 80, 16)
	add_child(_hint)
	_footer = Label.new()
	_footer.add_theme_color_override("font_color", Color(0.961, 0.933, 0.878, 0.8))
	_footer_band = _on_band(_footer, SCREEN.y - 17)


## The options on the menu now, in order (Continue only with a save).
func options() -> Array[int]:
	return _options


func cursor_option() -> int:
	return _options[_cursor]


func _process(delta: float) -> void:
	_time += delta
	_shimmer.queue_redraw()


## Bridalveil shimmers, as on the climbing screen: three streams of bright
## flecks running down the water.
func _draw_shimmer() -> void:
	for y in range(int(FALL_TOP.y), int(FALL_BOTTOM.y), 3):
		var t := inverse_lerp(FALL_TOP.y, FALL_BOTTOM.y, y)
		var mid := lerpf(FALL_TOP.x, FALL_BOTTOM.x, t)
		var half := lerpf(FALL_HALF_WIDTH.x, FALL_HALF_WIDTH.y, t)
		for stream in 3:
			var phase := _time * 7.0 + y * 0.21 + stream * 1.1
			if fmod(phase, 3.0) >= 1.0:
				continue
			var x := mid + (stream - 1) * half * 0.7 + sin(_time * 3.0 + y * 0.3 + stream) * 1.2
			_shimmer.draw_rect(Rect2(Vector2(roundf(x), y), Vector2(1, 2)), Color(0.961, 0.933, 0.878, 0.8))


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
	_footer_band.visible = not covered
	for i in _labels.size():
		var chosen := i == _cursor
		_labels[i].text = "   " + OPTION_NAMES[_options[i]]
		MenuInput.mark(_labels[i], chosen)
		_labels[i].add_theme_color_override("font_color", HEADING if chosen else Color.WHITE)
		_labels[i].add_theme_stylebox_override("normal", _select_style if chosen else _plain_style)
	_hint.text = NEW_GAME_CONFIRM if _confirm_new else ""
	var tree := get_tree()
	_footer.text = "[%s] Choose   [%s] Select" % [MenuInput.button(tree, "Up/Down", "D-pad"), MenuInput.button(tree, "E", "A")]
