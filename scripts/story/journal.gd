class_name Journal
extends CanvasLayer
## The Guardian's Register: a page showing your active quests, climbing gear,
## the food in your pack, and what's in your chuckah. Press J (gamepad Y) to open or close it.
##
## World adds one of these. It pauses the clock while it's open.

const HEADING := Color(1.0, 0.85, 0.5)
const DIM := Color(1, 1, 1, 0.6)

var _panel: PanelContainer
var _body: VBoxContainer


func _ready() -> void:
	layer = 25
	add_to_group("journal")
	_panel = PanelContainer.new()
	_panel.position = Vector2(40, 20)
	_panel.custom_minimum_size = Vector2(400, 230)
	_panel.visible = false
	add_child(_panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(392, 222)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 0)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)


func is_open() -> bool:
	return _panel.visible


func open() -> void:
	if is_open():
		return
	_refresh()
	_panel.visible = true
	GameClock.paused = true
	_set_player_can_act(false)


func close() -> void:
	if not is_open():
		return
	_panel.visible = false
	GameClock.paused = false
	_set_player_can_act(true)


func _unhandled_input(event: InputEvent) -> void:
	var toggle := event.is_action_pressed("journal")
	if is_open() and (toggle or event.is_action_pressed("ui_cancel")):
		close()
		get_viewport().set_input_as_handled()
	elif toggle and _player_can_act():
		open()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_heading("The Guardian's Register")

	_heading("Quests")
	var objectives := QuestLog.objectives()
	if objectives.is_empty():
		_line("No open quests. Talk to people around the valley.", DIM)
	for text in objectives:
		_line("- " + text)

	_heading("Climbing gear")
	var any_gear := false
	for item: GearData in Gear.GEAR:
		var n := Gear.count(item.id)
		if n > 0:
			_gear_line(item, n)
			any_gear = true
	if not any_gear:
		_line("None yet.", DIM)

	_heading("Food in your pack (%d energy)" % FoodDB.carried_energy())
	var foods := FoodDB.edible_in_inventory()
	if foods.is_empty():
		_line("Nothing ready to eat. Forage, or cook at a campfire.", DIM)
	for id in foods:
		var item := ItemDB.get_item(id)
		var name := item.display_name if item else id
		var days := Larder.days_left(id)
		var keeps := "keeps %d day%s" % [days, "" if days == 1 else "s"] if days > 0 else "keeps"
		_line("- %s x%d: %d energy each, %s" % [name, Inventory.count(id), FoodDB.energy(id), keeps])

	if Granary.chuckahs_built > 0:
		_heading("Chuckah")
		_line("%d of %d acorns stored. They won't spoil." % [Granary.acorns, Granary.capacity])

	var climbed := PackedStringArray()
	for id in QuestLog.climbed:
		climbed.append(id.capitalize())
	if not climbed.is_empty():
		_heading("Climbs")
		_line(", ".join(climbed))

	_line("")
	_line("J or Esc to close (gamepad: Y or B)", DIM)


func _gear_line(item: GearData, count: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	if item.icon:
		var icon := TextureRect.new()
		icon.texture = item.icon
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(icon)
	var label := Label.new()
	label.text = item.display_name if count == 1 else "%d %s" % [count, item.display_name]
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	_body.add_child(row)


func _heading(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", HEADING)
	_body.add_child(label)


func _line(text: String, color := Color.WHITE) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(384, 0)
	label.add_theme_color_override("font_color", color)
	_body.add_child(label)


func _player() -> Player:
	var world := get_tree().get_first_node_in_group("world")
	return world.player if world else null


func _player_can_act() -> bool:
	var player := _player()
	return player == null or player.can_act


func _set_player_can_act(value: bool) -> void:
	var player := _player()
	if player:
		player.can_act = value
