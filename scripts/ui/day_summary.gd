class_name DaySummary
extends CanvasLayer
## The page that comes up when you go to sleep, like Stardew Valley's end of
## the day: the date, then what the day brought (from DayLog), counted out
## one by one with a soft tick: things found and given, new gear, first
## ascents, finished quests, perks, recipes, dishes. Press the interact
## button (or cancel) to sleep.
##
##   var page := DaySummary.open(world, log)
##   await page.closed

signal closed

const PANEL_SIZE := Vector2(320, 0)
const HEADING := Color(1.0, 0.85, 0.5)
const DIM := Color(1, 1, 1, 0.6)
## Seconds between each thing counted out.
const STEP := 0.09
const ICON := Vector2(16, 16)

var _panel: PanelContainer
var _column: VBoxContainer
var _footer: Label
## Controls still to reveal, in order.
var _queue: Array[Control] = []
var _reveal_time := 0.0
var _opened_frame := 0
var _done := false


## Builds the page for [param log] over everything, and returns it.
static func open(from: Node, log: DayLog) -> DaySummary:
	var page := DaySummary.new()
	page._build(log)
	from.get_tree().root.add_child(page)
	return page


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_opened_frame = Engine.get_process_frames()
	Sound.play("ui_open")


func _build(log: DayLog) -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = PANEL_SIZE
	center.add_child(_panel)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 2)
	_panel.add_child(_column)
	var title := _label("%s, Year %d" % [GameClock.get_date_string(), GameClock.year], HEADING)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(title)
	var sub := _label("The day's page", DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(sub)
	if log == null or log.is_empty():
		var quiet := _label("A quiet day in the Valley.")
		quiet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_column.add_child(quiet)
		_hide(quiet)
	else:
		_chips("Found and given", log.items, func(id: String) -> Array:
			var item := ItemDB.get_item(id)
			return [item.icon, item.display_name] if item else [null, id])
		_chips("New gear", log.gear, func(id: String) -> Array:
			var piece := Gear.get_gear(id)
			return [piece.icon, piece.display_name] if piece else [null, id])
		_list("First ascents", log.ticks)
		_list("Quests finished", log.quests)
		_list("Perks learned", log.perks)
		_list("Recipes learned", log.recipes)
		if log.dishes > 0:
			_list("At the fire", PackedStringArray(["%d %s cooked" % [log.dishes, "dish" if log.dishes == 1 else "dishes"]]))
	_footer = _label("", DIM)
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_footer.modulate.a = 0.0
	_column.add_child(_footer)
	_panel.modulate.a = 0.0


func _label(text: String, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	return label


func _section(heading: String) -> void:
	var label := _label(heading, HEADING)
	_column.add_child(label)
	_hide(label)


## One line: the heading, then the names after it, wrapping if need be.
func _list(heading: String, names: PackedStringArray) -> void:
	if names.is_empty():
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(_label(heading, HEADING))
	var text := _label("  ·  ".join(names))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	_column.add_child(row)
	_hide(row)


## A row of icons with counts, wrapping as needed. [param describe] turns an
## id into [icon, name].
func _chips(heading: String, counts: Dictionary, describe: Callable) -> void:
	if counts.is_empty():
		return
	_section(heading)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 2)
	flow.custom_minimum_size.x = PANEL_SIZE.x - 16
	_column.add_child(flow)
	for id: String in counts:
		var info: Array = describe.call(id)
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 2)
		chip.tooltip_text = info[1]
		if info[0]:
			var picture := TextureRect.new()
			picture.texture = info[0]
			picture.custom_minimum_size = ICON
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			chip.add_child(picture)
			chip.add_child(_label("x%d" % counts[id]))
		else:
			chip.add_child(_label("%s x%d" % [info[1], counts[id]]))
		flow.add_child(chip)
		_hide(chip)


func _hide(control: Control) -> void:
	control.modulate.a = 0.0
	_queue.append(control)


func _process(delta: float) -> void:
	_panel.modulate.a = minf(1.0, _panel.modulate.a + delta * 5.0)
	if _queue.is_empty():
		if not _done:
			_done = true
			_footer.text = "[%s] Sleep" % MenuInput.button(get_tree(), "E", "A")
			create_tween().tween_property(_footer, "modulate:a", 1.0, 0.3)
		return
	_reveal_time -= delta
	if _reveal_time <= 0.0:
		_reveal_time = STEP
		var next: Control = _queue.pop_front()
		create_tween().tween_property(next, "modulate:a", 1.0, 0.15)
		Sound.play("ui_move", -4.0, 0.1)


## Shows everything at once (the first press), then closes (the second).
func press() -> void:
	if not _queue.is_empty():
		for control in _queue:
			control.modulate.a = 1.0
		_queue.clear()
		return
	Sound.play("ui_select")
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if Engine.get_process_frames() == _opened_frame:
		return
	if MenuInput.confirm(event) or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		press()
