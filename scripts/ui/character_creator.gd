class_name CharacterCreator
extends CanvasLayer
## "Who's arriving?": the screen where you make your own character before a
## new game starts (the title screen opens it once a slot is picked). A row
## for your name and one for each part of the look (PlayerLook.PARTS), then
## "Surprise me" and "Start". Up/Down choose a row, Left/Right change it,
## E (A) on Name types one in (Left/Right there deal names out, for a
## gamepad), Esc (B) goes back to the title. Beside the rows you stand as
## you'll be seen: your portrait, and your figure walking on the spot and
## turning round.
##
##   creator.open()                  # a new game: starts from the shipped look
##   creator.open(true)              # in a game (the pause menu's "Your
##                                   # look"): starts from the look you have,
##                                   # and Esc puts it back
##   creator.done / creator.cancelled

signal done
signal cancelled

const HEADING := Color(1, 0.831, 0.541)
const DIM := Color(0.961, 0.933, 0.878, 0.6)
const PANEL_POS := Vector2(30, 16)
const PANEL_SIZE := Vector2(420, 238)
## Rows of the look on screen at once; that part of the list scrolls with
## the cursor. "Surprise me" and "Start" stay in view under it.
const ROWS_SHOWN := 10
## The rows that never scroll away, at the end of the list.
const PINNED := 2
const NAME_WIDTH := 96.0
## Every row is this tall, the one being typed in too, so nothing shifts.
const ROW_HEIGHT := 14.0
const LIST_WIDTH := 236.0
## Parts whose options are colors, so their row shows a swatch.
const COLOR_PARTS := ["skin", "hair", "hat_color", "top", "bottom", "pack_color"]
## Seconds your figure faces each way, and between its steps.
const TURN_EVERY := 1.6
const STEP_EVERY := 0.18
const FACINGS := [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT]

enum Row { NAME, PART, SURPRISE, START }

## Each row: {"kind": Row, "id": part id (PART rows)}.
var _rows: Array[Dictionary] = []
var _lines: Array[HBoxContainer] = []
var _names: Array[Label] = []
var _values: Array[Label] = []
var _swatches: Array[ColorRect] = []
var _cursor := 0
var _top := 0
var _open := false
var _panel: PanelContainer
var _name_edit: LineEdit
var _editing := false
## True when opened in a game, to change the look you have.
var _changing := false
## The look and name to go back to if that's cancelled (PlayerLook.save_data).
var _before: Dictionary = {}
var _title: Label
var _face: TextureRect
var _figure: TextureRect
var _figure_frame := AtlasTexture.new()
var _caption: Label
var _more: Label
var _footer: Label
var _select_style: StyleBoxTexture
var _plain_style: StyleBoxEmpty
var _time := 0.0
## The PlayerLook.version the preview shows.
var _shown := -1
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	layer = 30
	UiScale.layer(self)
	add_to_group("character_creator")
	_rng.randomize()
	_rows.append({"kind": Row.NAME})
	for part: Dictionary in PlayerLook.PARTS:
		_rows.append({"kind": Row.PART, "id": part.id})
	_rows.append({"kind": Row.SURPRISE})
	_rows.append({"kind": Row.START})
	_select_style = StyleBoxTexture.new()
	_select_style.texture = load("res://assets/ui/select.png")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_select_style.set_texture_margin(side, 2.0)
	_select_style.content_margin_left = 2.0
	# no taller than a plain line, so the list doesn't shift under the cursor
	_select_style.content_margin_top = 0.0
	_select_style.content_margin_bottom = 0.0
	_plain_style = StyleBoxEmpty.new()
	_plain_style.content_margin_left = 2.0
	_build()


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.position = PANEL_POS
	_panel.custom_minimum_size = PANEL_SIZE
	_panel.size = PANEL_SIZE
	_panel.visible = false
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	_panel.add_child(column)
	var title := Label.new()
	_title = title
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", HEADING)
	var tag := StyleBoxTexture.new()
	tag.texture = load("res://assets/ui/tag.png")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		tag.set_texture_margin(side, 4.0)
	tag.content_margin_left = 6.0
	tag.content_margin_right = 6.0
	tag.expand_margin_top = 5.0
	tag.expand_margin_left = 2.0
	title.add_theme_stylebox_override("normal", tag)
	title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(title)
	var both := HBoxContainer.new()
	both.add_theme_constant_override("separation", 10)
	both.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(both)
	both.add_child(_build_list())
	both.add_child(_build_preview())
	_footer = ButtonHints.new()
	_footer.modulate = DIM
	column.add_child(_footer)


func _build_list() -> Control:
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)
	list.custom_minimum_size.x = LIST_WIDTH
	for i in _rows.size():
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 4)
		line.custom_minimum_size.y = ROW_HEIGHT
		var row_name := Label.new()
		row_name.custom_minimum_size.x = NAME_WIDTH
		line.add_child(row_name)
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(8, 8)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.visible = false
		line.add_child(swatch)
		var value := Label.new()
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(value)
		if _rows[i].kind == Row.NAME:
			_name_edit = LineEdit.new()
			_name_edit.max_length = PlayerLook.MAX_NAME
			_name_edit.placeholder_text = "Type a name"
			_name_edit.custom_minimum_size.x = 110
			_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_name_edit.visible = false
			_name_edit.context_menu_enabled = false
			_name_edit.custom_minimum_size.y = ROW_HEIGHT
			_name_edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_name_edit.add_theme_constant_override("minimum_character_width", 0)
			# a slim field, the height of a line of the list
			for state: String in ["normal", "focus"]:
				var field := StyleBoxFlat.new()
				field.bg_color = Color("15141c")
				field.border_color = HEADING if state == "focus" else Color("b0925f")
				field.set_border_width_all(1)
				field.content_margin_left = 3.0
				field.content_margin_right = 3.0
				field.content_margin_top = 0.0
				field.content_margin_bottom = 0.0
				_name_edit.add_theme_stylebox_override(state, field)
			_name_edit.text_submitted.connect(func(_text: String) -> void: _finish_name(true))
			# clicking away keeps what was typed, as Enter does
			_name_edit.focus_exited.connect(func() -> void: _finish_name(true))
			line.add_child(_name_edit)
		if i == _rows.size() - PINNED:
			_more = Label.new()
			_more.add_theme_color_override("font_color", DIM)
			_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			list.add_child(_more)
		list.add_child(line)
		_lines.append(line)
		_names.append(row_name)
		_values.append(value)
		_swatches.append(swatch)
	return list


func _build_preview() -> Control:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.082, 0.078, 0.11, 0.2)
	style.border_color = Color(0.69, 0.573, 0.373, 0.55)
	style.border_width_left = 1
	style.content_margin_left = 10.0
	style.content_margin_right = 4.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	card.add_theme_stylebox_override("panel", style)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(column)
	var frame := PanelContainer.new()
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color("5e4a38")
	frame_style.border_color = Color("b0925f")
	frame_style.set_border_width_all(1)
	frame_style.set_content_margin_all(1)
	frame.add_theme_stylebox_override("panel", frame_style)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_face = TextureRect.new()
	_face.custom_minimum_size = Vector2(80, 80)
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(_face)
	column.add_child(frame)
	# a patch of meadow to stand on, so the figure reads as in the world
	var ground := PanelContainer.new()
	var ground_style := StyleBoxFlat.new()
	ground_style.bg_color = Color("84b04a")
	ground_style.border_color = Color("5c8f3c")
	ground_style.set_border_width_all(1)
	ground_style.set_content_margin_all(3)
	ground.add_theme_stylebox_override("panel", ground_style)
	ground.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_figure = TextureRect.new()
	# three screen pixels to one of the sheet's (the menus are drawn at 2x)
	_figure.custom_minimum_size = Vector2(CharacterSheet.FRAME) * 1.5
	_figure.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_figure.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_figure.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_figure.texture = _figure_frame
	ground.add_child(_figure)
	column.add_child(ground)
	_caption = Label.new()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_color_override("font_color", HEADING)
	column.add_child(_caption)
	return card


func is_open() -> bool:
	return _open


## Opens the screen with the cursor on Name: for a new game on the shipped
## look with no name, or ([param changing]) on the look and name you have.
func open(changing := false) -> void:
	_changing = changing
	if changing:
		_before = PlayerLook.save_data()
	else:
		PlayerLook.reset()
	_title.text = "Your look" if changing else "Who's arriving?"
	_cursor = 0
	_top = 0
	_open = true
	_panel.visible = true
	MenuInput.pop_in(_panel)
	_refresh()


func close() -> void:
	if not _open:
		return
	_finish_name(false)
	_open = false
	MenuInput.pop_out(_panel)


## The row under the cursor (a Row).
func row() -> int:
	return _rows[_cursor].kind


## Moves the cursor to the row for part [param id], or to the first row of
## [param kind] when [param id] is "".
func go_to(kind: int, id := "") -> void:
	for i in _rows.size():
		if _rows[i].kind == kind and (id == "" or _rows[i].get("id", "") == id):
			_cursor = i
			_refresh()
			return


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	get_viewport().set_input_as_handled()
	if _editing:
		if event.is_action_pressed("ui_cancel"):
			_finish_name(false)
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		Sound.play("ui_back")
		if _changing:
			PlayerLook.load_data(_before)
		else:
			PlayerLook.reset()
		close()
		cancelled.emit()
		return
	var step := MenuInput.vertical(event)
	if step != 0:
		_cursor = wrapi(_cursor + step, 0, _rows.size())
		Sound.play("ui_move")
		_refresh()
		return
	var turn := MenuInput.horizontal(event)
	if turn != 0:
		change(turn)
	elif MenuInput.confirm(event):
		select()


## Left/Right on the row under the cursor: the next or last option of a
## part, or another name out of the hat.
func change(turn: int) -> void:
	var here: Dictionary = _rows[_cursor]
	match here.kind:
		Row.PART:
			PlayerLook.set_choice(here.id, PlayerLook.chosen(here.id) + turn)
			Sound.play("ui_move")
		Row.NAME:
			var at := PlayerLook.NAMES.find(PlayerLook.player_name)
			PlayerLook.set_player_name(PlayerLook.NAMES[wrapi(at + turn, 0, PlayerLook.NAMES.size())])
			Sound.play("ui_move")
	_refresh()


## E (A) on the row under the cursor.
func select() -> void:
	var here: Dictionary = _rows[_cursor]
	MenuInput.press(_names[_cursor])
	match here.kind:
		Row.NAME:
			Sound.play("ui_select")
			_start_name()
		Row.PART:
			change(1)
		Row.SURPRISE:
			Sound.play("ui_select")
			PlayerLook.randomize_look(_rng)
			_refresh()
		Row.START:
			Sound.play("ui_select")
			close()
			done.emit()


func _start_name() -> void:
	_editing = true
	_name_edit.text = PlayerLook.player_name
	_name_edit.visible = true
	_values[0].visible = false
	_name_edit.grab_focus()
	_name_edit.caret_column = _name_edit.text.length()
	_refresh()


## Ends typing, keeping what was typed if [param keep].
func _finish_name(keep: bool) -> void:
	if not _editing:
		return
	_editing = false
	if keep:
		PlayerLook.set_player_name(_name_edit.text)
	_name_edit.release_focus()
	_name_edit.visible = false
	_values[0].visible = true
	Sound.play("ui_select" if keep else "ui_back")
	_refresh()


func _process(delta: float) -> void:
	if not _open:
		return
	_time += delta
	if _shown != PlayerLook.version:
		_shown = PlayerLook.version
		_face.texture = PlayerLook.face("happy")
		_figure_frame.atlas = PlayerLook.sheet()
		_caption.text = PlayerLook.player_name
	if _figure_frame.atlas == null:
		return
	# walking on the spot, turning to face each way in turn
	var facing: Vector2i = FACINGS[int(_time / TURN_EVERY) % FACINGS.size()]
	var step := int(_time / STEP_EVERY) % 4
	var col: int = [CharacterSheet.Col.STAND, CharacterSheet.Col.STEP_A, CharacterSheet.Col.STAND, CharacterSheet.Col.STEP_B][step]
	_figure_frame.region = CharacterSheet.region(_figure_frame.atlas, facing, col)


func _refresh() -> void:
	# the window of rows follows the cursor
	var scrolling := _rows.size() - PINNED
	if _cursor < scrolling:
		_top = clampi(_top, maxi(_cursor - ROWS_SHOWN + 1, 0), mini(_cursor, maxi(scrolling - ROWS_SHOWN, 0)))
	for i in _rows.size():
		var here: Dictionary = _rows[i]
		var chosen := i == _cursor
		_lines[i].visible = i >= scrolling or (i >= _top and i < _top + ROWS_SHOWN)
		var text := ""
		var value := ""
		_swatches[i].visible = false
		match here.kind:
			Row.NAME:
				text = "Name"
				value = PlayerLook.player_name if PlayerLook.player_name != "" else "(none yet)"
			Row.PART:
				text = str(PlayerLook.part(here.id).name)
				value = PlayerLook.chosen_name(here.id)
				if here.id in COLOR_PARTS:
					_swatches[i].visible = true
					_swatches[i].color = Palette32.nearest(Color(str(PlayerLook.chosen_value(here.id))))
			Row.SURPRISE:
				text = "Surprise me"
			Row.START:
				text = "Done" if _changing else "Start"
		_names[i].text = "   " + text
		MenuInput.mark(_names[i], chosen)
		_names[i].add_theme_color_override("font_color", HEADING if chosen else Color.WHITE)
		_names[i].add_theme_stylebox_override("normal", _select_style if chosen else _plain_style)
		_values[i].text = value
		_values[i].add_theme_color_override("font_color", HEADING if chosen else Color.WHITE)
		_values[i].modulate = DIM if here.kind == Row.NAME and PlayerLook.player_name == "" else Color.WHITE
	_more.text = "More below" if _top + ROWS_SHOWN < scrolling else ("More above" if _top > 0 else "")
	_footer.text = _footer_text()


func _footer_text() -> String:
	var tree := get_tree()
	if tree == null:
		return ""
	if _editing:
		return "Type your name   [Enter] Done   [Esc] Cancel"
	var choose := MenuInput.button(tree, "Up/Down", "D-pad")
	var turn := MenuInput.button(tree, "Left/Right", "D-pad L/R")
	var ok := MenuInput.button(tree, "E", "A")
	var back := MenuInput.button(tree, "Esc", "B")
	match _rows[_cursor].kind:
		Row.NAME:
			return "[%s] Choose   [%s] Type a name   [%s] Pick one   [%s] Back" % [choose, ok, turn, back]
		Row.PART:
			return "[%s] Choose   [%s] Change   [%s] Back" % [choose, turn, back]
	return "[%s] Choose   [%s] Select   [%s] Back" % [choose, ok, back]
