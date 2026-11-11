class_name PhotoAlbum
extends CanvasLayer
## The photograph album (see Photos), in two pages:
##   Album: your prints as a sheet of small ones, with the chosen print at
##          its real size beside them: its title, where and when it was
##          made, the light, the film and lens, and its stars. E looks at it
##          on its own, twice the size, with everything that was in the
##          frame named under it; Delete (X on a pad) takes it out of the
##          album, asking first.
##   Ansel's list: the pictures Ansel Adams would like to see, by group,
##          ticked as you make them, each with where to stand until then.
## Tab (LB/RB) turns the page; Esc (B) closes it.
##
## It opens from the viewfinder (Tab, or Y on a pad), so a new print is one
## key away, and the Journal's first page says how many you've made. World
## adds one of these. It pauses the clock while it's open.

enum Page { ALBUM, LIST }

const PAGE_NAMES := ["Album", "Ansel's list"]
const HEADING := Color(1, 0.831, 0.541)
const DIM := Color(0.961, 0.933, 0.878, 0.6)
const RULE := Color(0.945, 0.812, 0.416, 0.45)
const DONE := Color(0.827, 0.894, 0.541)
const PANEL_POS := Vector2(30, 16)
const PANEL_SIZE := Vector2(420, 238)
const LINE_WIDTH := 396
## A small print on the sheet, and how many across.
const THUMB := Vector2(54, 36)
const COLUMNS := 3
## The chosen print, at one screen pixel to one pixel of the picture.
const BIG := Vector2(180, 120)
## How far the list's lines are set in, to clear their checkboxes.
const INDENT := 12
const SCROLL_STEP := 24
const REPEAT_DELAY := 0.35
const REPEAT_EVERY := 0.06
## A star, drawn in pixels: "#" the rim, "=" the gold.
const STAR := [
	"....#....",
	"...#=#...",
	"...#=#...",
	"####=####",
	"#=======#",
	".#=====#.",
	"..#===#..",
	".#==#==#.",
	".##...##.",
]

var _panel: PanelContainer
var _page := Page.ALBUM
var _tab_labels: Array[Label] = []
var _tab_style: StyleBoxTexture
var _plain_style: StyleBoxEmpty
var _album_page: HBoxContainer
var _sheet_scroll: ScrollContainer
var _sheet: GridContainer
var _thumbs: Array[PanelContainer] = []
var _empty: Label
var _big: TextureRect
var _title: Label
var _where: Label
var _when: Label
var _made: Label
var _stars: Control
var _stars_count := 0
var _subjects: Label
var _list_scroll: ScrollContainer
var _list_body: VBoxContainer
var _footer: ButtonHints
var _look: Control
var _look_print: TextureRect
var _cursor := 0
var _open := false
## True while the delete question is up.
var _asking := false
var _repeat := 0.0
var _was_paused := false

static var _star_full: Texture2D
static var _star_empty: Texture2D


func _ready() -> void:
	layer = 26
	UiScale.layer(self)
	add_to_group("photo_album")
	_build_styles()
	_panel = PanelContainer.new()
	_panel.position = PANEL_POS
	_panel.custom_minimum_size = PANEL_SIZE
	_panel.size = PANEL_SIZE
	_panel.visible = false
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	_panel.add_child(column)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	column.add_child(tabs)
	for i in PAGE_NAMES.size():
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.gui_input.connect(_on_tab_input.bind(i))
		tabs.add_child(label)
		_tab_labels.append(label)
	_build_album_page(column)
	_build_list_page(column)
	_footer = ButtonHints.new()
	_footer.add_theme_color_override("font_color", DIM)
	column.add_child(_footer)
	_build_look()
	Photos.changed.connect(func() -> void:
		if _open:
			_refresh())


func _build_styles() -> void:
	_tab_style = StyleBoxTexture.new()
	_tab_style.texture = load("res://assets/ui/tag.png")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_tab_style.set_texture_margin(side, 4.0)
	_tab_style.content_margin_left = 6.0
	_tab_style.content_margin_right = 6.0
	_plain_style = StyleBoxEmpty.new()
	_plain_style.content_margin_left = 6.0
	_plain_style.content_margin_right = 6.0


## The sheet of small prints on the left, the chosen one and what's written
## on its back on the right.
func _build_album_page(column: VBoxContainer) -> void:
	_album_page = HBoxContainer.new()
	_album_page.add_theme_constant_override("separation", 10)
	_album_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_album_page)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = COLUMNS * (THUMB.x + 6) + 12
	_album_page.add_child(left)
	_sheet_scroll = ScrollContainer.new()
	_sheet_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sheet_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(_sheet_scroll)
	_sheet = GridContainer.new()
	_sheet.columns = COLUMNS
	_sheet.add_theme_constant_override("h_separation", 2)
	_sheet.add_theme_constant_override("v_separation", 2)
	_sheet_scroll.add_child(_sheet)
	_empty = Label.new()
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.custom_minimum_size.x = COLUMNS * (THUMB.x + 6)
	_empty.add_theme_color_override("font_color", DIM)
	_empty.text = "No photographs yet. Raise the camera, put something in the frame, and press the shutter."
	left.add_child(_empty)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_album_page.add_child(right)
	var mount := PanelContainer.new()
	mount.add_theme_stylebox_override("panel", mount_style())
	mount.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	right.add_child(mount)
	_big = TextureRect.new()
	_big.custom_minimum_size = BIG
	_big.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_big.stretch_mode = TextureRect.STRETCH_SCALE
	_big.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mount.add_child(_big)
	var gap := Control.new()
	gap.custom_minimum_size.y = 3
	right.add_child(gap)
	var heading := HBoxContainer.new()
	right.add_child(heading)
	_title = Label.new()
	_title.add_theme_color_override("font_color", HEADING)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	heading.add_child(_title)
	_stars = Control.new()
	_stars.custom_minimum_size = Vector2(32, 10)
	_stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_stars.draw.connect(func() -> void: draw_stars(_stars, Vector2.ZERO, _stars_count))
	heading.add_child(_stars)
	_where = _back_line(right, Color.WHITE)
	_when = _back_line(right, DIM)
	_made = _back_line(right, DIM)


func _back_line(parent: Control, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_color_override("font_color", color)
	label.custom_minimum_size.x = BIG.x + 4
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	parent.add_child(label)
	return label


func _build_list_page(column: VBoxContainer) -> void:
	_list_scroll = ScrollContainer.new()
	_list_scroll.custom_minimum_size.x = LINE_WIDTH + 8
	_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_scroll.visible = false
	column.add_child(_list_scroll)
	_list_body = VBoxContainer.new()
	_list_body.add_theme_constant_override("separation", 0)
	_list_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_scroll.add_child(_list_body)


## The print on its own over a dark screen, twice its size.
func _build_look() -> void:
	_look = ColorRect.new()
	(_look as ColorRect).color = Color(0.05, 0.04, 0.06, 0.92)
	UiScale.fit(_look)
	_look.visible = false
	add_child(_look)
	var mount := PanelContainer.new()
	mount.add_theme_stylebox_override("panel", mount_style(3.0))
	_look.add_child(mount)
	_look_print = TextureRect.new()
	_look_print.custom_minimum_size = BIG * 2.0
	_look_print.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_look_print.stretch_mode = TextureRect.STRETCH_SCALE
	_look_print.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mount.add_child(_look_print)
	mount.position = Vector2(roundf((UiScale.SCREEN.x - BIG.x * 2.0 - 6.0) / 2.0), 4.0)
	# what was in the frame, under the print
	_subjects = Label.new()
	_subjects.add_theme_color_override("font_color", DIM)
	_subjects.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subjects.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_subjects.position = Vector2(8, BIG.y * 2.0 + 12.0)
	_subjects.size = Vector2(UiScale.SCREEN.x - 16.0, 12.0)
	_look.add_child(_subjects)


## The white border a print is mounted in.
static func mount_style(border := 2.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f5eee0")
	style.border_color = Color("2a1b14")
	style.set_border_width_all(1)
	style.set_content_margin_all(border)
	style.anti_aliasing = false
	return style


## A gold star, or the dark outline of one.
static func star_texture(filled: bool) -> Texture2D:
	if _star_full == null:
		for full in [true, false]:
			var im := Image.create_empty(9, 9, false, Image.FORMAT_RGBA8)
			for y in STAR.size():
				for x in 9:
					match STAR[y][x]:
						"#":
							im.set_pixel(x, y, Color("2a1b14") if full else Color(0.961, 0.933, 0.878, 0.45))
						"=":
							if full:
								im.set_pixel(x, y, Color("ffd48a") if y < 5 else Color("d8a63b"))
			if full:
				_star_full = ImageTexture.create_from_image(im)
			else:
				_star_empty = ImageTexture.create_from_image(im)
	return _star_full if filled else _star_empty


## Draws three stars on [param ci] from [param at], [param count] of them gold.
static func draw_stars(ci: CanvasItem, at: Vector2, count: int) -> void:
	for i in 3:
		ci.draw_texture(star_texture(i < count), at + Vector2(i * 10, 0))


func is_open() -> bool:
	return _open


func page() -> Page:
	return _page


## The print under the cursor ({} with an empty album).
func chosen() -> Dictionary:
	return Photos.album[_cursor] if _cursor >= 0 and _cursor < Photos.album.size() else {}


func is_looking() -> bool:
	return _look.visible


func is_asking() -> bool:
	return _asking


## Opens the album on [param which], at the newest print.
func open(which := Page.ALBUM) -> void:
	if _open:
		show_page(which)
		return
	var hud := get_tree().get_first_node_in_group("hud") as HUD
	if hud and not hud.device_changed.is_connected(_refresh_hints):
		hud.device_changed.connect(_refresh_hints)
	_open = true
	_asking = false
	_look.visible = false
	_cursor = maxi(Photos.album.size() - 1, 0)
	_was_paused = GameClock.paused
	GameClock.paused = true
	_page = which
	_refresh()
	MenuInput.pop_in(_panel)
	_scroll_to_cursor.call_deferred()


func close() -> void:
	if not _open:
		return
	_open = false
	_asking = false
	_look.visible = false
	MenuInput.pop_out(_panel)
	Sound.play("ui_close")
	GameClock.paused = _was_paused


func show_page(which: Page) -> void:
	if which != _page:
		MenuInput.fade_page(_album_page if which == Page.ALBUM else _list_scroll)
	_page = which
	_asking = false
	_refresh()
	_repeat = REPEAT_DELAY


func _on_tab_input(event: InputEvent, which: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and which != _page:
		show_page(which as Page)


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	get_viewport().set_input_as_handled()
	if _look.visible:
		if event.is_action_pressed("ui_cancel") or MenuInput.confirm(event):
			_look.visible = false
			Sound.play("ui_back")
		return
	if _asking:
		if MenuInput.confirm(event) or _is_delete(event):
			remove_chosen()
		elif event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed):
			_asking = false
			_refresh_hints()
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		close()
		return
	var turn := _tab_turn(event)
	if turn != 0:
		show_page(wrapi(_page + turn, 0, Page.size()) as Page)
		Sound.play("ui_move")
	elif _page == Page.ALBUM:
		var step := Vector2i(MenuInput.horizontal(event), MenuInput.vertical(event))
		if step != Vector2i.ZERO:
			move_cursor(step)
		elif _is_delete(event):
			ask_remove()
		elif MenuInput.confirm(event):
			look()
	else:
		var step := MenuInput.vertical(event)
		if step != 0:
			scroll_by(step * SCROLL_STEP)
			_repeat = REPEAT_DELAY


func _tab_turn(event: InputEvent) -> int:
	if event.is_action_pressed("ui_focus_prev") or (event is InputEventJoypadButton and event.is_action_pressed("tab_previous")):
		return -1
	if event.is_action_pressed("ui_focus_next") or (event is InputEventJoypadButton and event.is_action_pressed("tab_next")):
		return 1
	return 0


## Delete or Backspace, or X on a pad.
func _is_delete(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo and event.keycode in [KEY_DELETE, KEY_BACKSPACE]
	return event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_X


func _process(delta: float) -> void:
	if not _open or _page != Page.LIST:
		return
	var held := int(Input.is_action_pressed("move_down") or Input.is_action_pressed("ui_down")) \
			- int(Input.is_action_pressed("move_up") or Input.is_action_pressed("ui_up"))
	if held == 0:
		_repeat = REPEAT_DELAY
		return
	_repeat -= delta
	if _repeat <= 0.0:
		_repeat = REPEAT_EVERY
		scroll_by(held * SCROLL_STEP)


func scroll_by(pixels: int) -> void:
	_list_scroll.scroll_vertical = maxi(0, _list_scroll.scroll_vertical + pixels)


## Moves the cursor a print left or right, or a row up or down.
func move_cursor(step: Vector2i) -> void:
	if Photos.album.is_empty():
		return
	var target := clampi(_cursor + step.x + step.y * COLUMNS, 0, Photos.album.size() - 1)
	if step.y != 0 and absi(target - _cursor) < COLUMNS and (target / COLUMNS) == (_cursor / COLUMNS):
		return # no row that way
	if target == _cursor:
		return
	_cursor = target
	Sound.play("ui_move")
	_refresh_cursor()
	_scroll_to_cursor()


func _scroll_to_cursor() -> void:
	if _cursor >= 0 and _cursor < _thumbs.size():
		_sheet_scroll.ensure_control_visible(_thumbs[_cursor])


## Shows the chosen print on its own, twice the size.
func look() -> void:
	var photo := chosen()
	if photo.is_empty():
		return
	_look_print.texture = Photos.texture(photo.id)
	var subjects: Array = photo.get("subjects", [])
	_subjects.text = "%s  ·  In the frame: %s" % [photo.title, ", ".join(PackedStringArray(subjects))] if subjects.size() > 1 else str(photo.title)
	_look.visible = true
	Sound.play("ui_select")


## Asks before the chosen print is taken out.
func ask_remove() -> void:
	if chosen().is_empty():
		return
	_asking = true
	Sound.play("ui_select")
	_refresh_hints()


## Takes the chosen print out of the album.
func remove_chosen() -> void:
	var photo := chosen()
	_asking = false
	if photo.is_empty():
		return
	Photos.remove(photo.id) # Photos.changed refreshes the page
	Sound.play("ui_back")


func _refresh() -> void:
	_album_page.visible = _page == Page.ALBUM
	_list_scroll.visible = _page == Page.LIST
	if _page == Page.ALBUM:
		_refresh_sheet()
	else:
		_refresh_list()
	_refresh_hints()


func _refresh_sheet() -> void:
	for child in _sheet.get_children():
		_sheet.remove_child(child)
		child.queue_free()
	_thumbs.clear()
	_cursor = clampi(_cursor, 0, maxi(Photos.album.size() - 1, 0))
	for i in Photos.album.size():
		var photo: Dictionary = Photos.album[i]
		var slot := PanelContainer.new()
		slot.mouse_filter = Control.MOUSE_FILTER_PASS
		slot.gui_input.connect(_on_thumb_input.bind(i))
		var picture := TextureRect.new()
		picture.texture = Photos.texture(photo.id)
		picture.custom_minimum_size = THUMB
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_SCALE
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(picture)
		_sheet.add_child(slot)
		_thumbs.append(slot)
	_empty.visible = Photos.album.is_empty()
	_sheet_scroll.visible = not Photos.album.is_empty()
	_refresh_cursor()


func _on_thumb_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_cursor = index
		_refresh_cursor()


## Marks the print under the cursor and writes out its back.
func _refresh_cursor() -> void:
	for i in _thumbs.size():
		var style := mount_style(1.0)
		if i == _cursor:
			style.border_color = HEADING
			style.set_border_width_all(2)
			style.set_content_margin_all(1.0)
		else:
			style.bg_color = Color("47301f")
			style.set_content_margin_all(2.0)
		_thumbs[i].add_theme_stylebox_override("panel", style)
	var photo := chosen()
	_big.texture = Photos.texture(photo.id) if not photo.is_empty() else null
	_big.get_parent().visible = not photo.is_empty()
	_stars.visible = not photo.is_empty()
	if photo.is_empty():
		_title.text = ""
		_where.text = ""
		_when.text = ""
		_made.text = ""
		return
	_title.text = photo.title
	_stars_count = int(photo.stars)
	_stars.queue_redraw()
	_where.text = photo.where
	_when.text = Photos.caption(photo)
	_made.text = "%s, %s film" % [Photos.LENS_NAMES.get(photo.lens, "Normal lens"), str(Photos.FILM_NAMES.get(photo.film, "Color")).to_lower()]


## Ansel's list, by group: a tick and the note for each picture made, a box
## and where to stand for each one still to make.
func _refresh_list() -> void:
	for child in _list_body.get_children():
		_list_body.remove_child(child)
		child.queue_free()
	for group: String in Photos.GROUPS:
		var entries := Photos.in_group(group)
		_heading("%s (%d of %d)" % [group, Photos.listed_in(group), entries.size()])
		for entry: Dictionary in entries:
			if Photos.is_listed(entry.id):
				var when := Achievements.day_text(int(Photos.listed[entry.id].get("day", -1)))
				_check_line(true, entry.name + (" · %s" % when if when != "" else ""), DONE)
				_line(entry.note, DIM)
			else:
				_check_line(false, "%s · %s" % [entry.name, entry.hint], Color.WHITE)
	var gap := Control.new()
	gap.custom_minimum_size.y = 5
	_list_body.add_child(gap)
	if Photos.listed_count() == Photos.SHOT_LIST.size():
		_line("Every picture on the list. \"The whole valley, on paper,\" Ansel says.", DONE)
	else:
		_line("One photograph can answer more than one line: a deer under El Capitan at sunset is three.", DIM)


func _heading(text: String) -> void:
	if _list_body.get_child_count() > 0:
		var gap := Control.new()
		gap.custom_minimum_size.y = 5
		_list_body.add_child(gap)
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", HEADING)
	_list_body.add_child(label)
	var rule := ColorRect.new()
	rule.color = RULE
	rule.custom_minimum_size = Vector2(LINE_WIDTH, 1)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_list_body.add_child(rule)
	var under := Control.new()
	under.custom_minimum_size.y = 2
	_list_body.add_child(under)


## A line with a checkbox before it, the box level with its first line.
func _check_line(ticked: bool, text: String, color: Color) -> void:
	_boxed_line(MenuInput.checkbox_texture(ticked), text, color)


## A line set in under the checkboxes (a note on the line above).
func _line(text: String, color: Color) -> void:
	_boxed_line(null, text, color)


func _boxed_line(box: Texture2D, text: String, color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(INDENT, 0)
	row.add_child(holder)
	if box:
		var icon := TextureRect.new()
		icon.texture = box
		icon.position = Vector2(2, 2)
		icon.size = box.get_size()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(icon)
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(LINE_WIDTH - INDENT - 4, 0)
	label.add_theme_color_override("font_color", color)
	row.add_child(label)
	_list_body.add_child(row)


func _refresh_hints() -> void:
	var tree := get_tree()
	var gamepad := MenuInput.button(tree, "k", "g") == "g"
	var counts := ["%d of %d" % [Photos.album.size(), Photos.ALBUM_SIZE], "%d of %d" % [Photos.listed_count(), Photos.SHOT_LIST.size()]]
	for i in _tab_labels.size():
		var label := _tab_labels[i]
		label.text = "%s (%s)" % [PAGE_NAMES[i], counts[i]]
		label.add_theme_color_override("font_color", HEADING if i == _page else DIM)
		label.add_theme_stylebox_override("normal", _tab_style if i == _page else _plain_style)
	var turn := "[%s] %s" % [MenuInput.button(tree, "Tab", "LB/RB"), PAGE_NAMES[1 - _page]]
	var shut := "[%s] Close" % MenuInput.button(tree, "Esc", "B")
	if _asking:
		_footer.text = "Take this print out for good?   [%s] Take it out   [%s] Keep it" % [
			MenuInput.button(tree, "E", "A"), MenuInput.button(tree, "Esc", "B")]
	elif _page == Page.LIST:
		_footer.text = "[%s] Scroll   %s   %s" % [MenuInput.button(tree, "Up/Down", "Stick"), turn, shut]
	elif Photos.album.is_empty():
		_footer.text = "%s   %s" % [turn, shut]
	else:
		_footer.text = "[%s] Choose   [%s] Look   [%s] Take out   %s   %s" % [MenuInput.button(tree, "Arrows", "Stick"),
			MenuInput.button(tree, "E", "A"), "X" if gamepad else "Del", turn, shut]
