class_name HUD
extends CanvasLayer
## On-screen info: date, time, a status strip (food, gear, journal key),
## messages, what you're carrying, where you are, signs you're reading,
## and screen fades.

## Walking this far (pixels) from a sign closes it.
const INFO_CLOSE_DISTANCE := 24.0
## Gap (pixels) between the message and the sign panel it sits above.
const MESSAGE_GAP := 2.0
## Groups of the screens that hide the HUD while they're open.
const COVERING_GROUPS := ["journal", "pause_menu", "park_map"]

var _player: Player
var _status: Label
var _message_tween: Tween
var _info_anchor := Vector2.ZERO
## True while a menu, map or conversation covers the screen.
var _covered := false

@onready var date_label: Label = %DateLabel
@onready var time_label: Label = %TimeLabel
@onready var status_bar: HBoxContainer = %StatusBar
@onready var message_label: Label = %MessageLabel
@onready var fade: ColorRect = %Fade
@onready var bag_panel: PanelContainer = %BagPanel
@onready var bag_list: VBoxContainer = %BagList
@onready var location_label: Label = %LocationLabel
@onready var info_panel: PanelContainer = %InfoPanel
@onready var info_title: Label = %InfoTitle
@onready var info_text: Label = %InfoText
@onready var prompt_panel: PanelContainer = %PromptPanel
@onready var prompt_label: Label = %PromptLabel
@onready var clock_panel: PanelContainer = $ClockPanel
@onready var location_panel: PanelContainer = %LocationPanel

## True after the last input came from a gamepad, so prompts name its buttons.
var _gamepad := false


func _ready() -> void:
	add_to_group("hud")
	message_label.modulate.a = 0.0
	GameClock.time_changed.connect(_refresh_clock.unbind(2))
	GameClock.day_started.connect(_refresh_clock.unbind(3))
	Inventory.changed.connect(_refresh_status)
	Inventory.changed.connect(_refresh_bag)
	Gear.changed.connect(_refresh_status)
	var panel := PanelContainer.new()
	_status = Label.new()
	panel.add_child(_status)
	status_bar.add_child(panel)


func bind_player(player: Player) -> void:
	_player = player
	_refresh_clock()
	_refresh_status()
	_refresh_bag()


func show_message(text: String) -> void:
	message_label.text = text
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_property(message_label, "modulate:a", 1.0, 0.2)
	_message_tween.tween_interval(2.5)
	_message_tween.tween_property(message_label, "modulate:a", 0.0, 0.6)


## The location banner at the top of the screen.
func set_location(text: String) -> void:
	location_label.text = text


## Shows a sign's text until the player walks away from it.
func show_info(title: String, text: String) -> void:
	info_title.text = title
	info_text.text = text
	info_panel.visible = true
	info_panel.set_deferred("size", Vector2.ZERO) # shrink to fit
	if _player:
		_info_anchor = _player.global_position


func hide_info() -> void:
	info_panel.visible = false


func _process(_delta: float) -> void:
	if info_panel.visible and _player and _player.global_position.distance_to(_info_anchor) > INFO_CLOSE_DISTANCE:
		hide_info()
	_update_cover()
	_update_message_position()
	_update_prompt()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		_gamepad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		_gamepad = false


func _unhandled_input(event: InputEvent) -> void:
	if info_panel.visible and event.is_action_pressed("ui_cancel"):
		hide_info()
		get_viewport().set_input_as_handled()


## Hides the HUD while the journal, pause menu, map or a conversation is open.
func _update_cover() -> void:
	var covered := not get_tree().get_nodes_in_group("dialogue_box").is_empty()
	for group: String in COVERING_GROUPS:
		var screen := get_tree().get_first_node_in_group(group)
		if screen and screen.is_open():
			covered = true
	if covered == _covered:
		return
	_covered = covered
	var alpha := 0.0 if covered else 1.0
	for panel: Control in [clock_panel, location_panel, status_bar, bag_panel, info_panel]:
		panel.modulate.a = alpha
	message_label.visible = not covered


## The pickup message sits at the bottom left, or above the sign panel while one is open.
func _update_message_position() -> void:
	var bottom := -26.0
	if info_panel.visible:
		bottom = -30.0 - maxf(info_panel.size.y, info_panel.get_combined_minimum_size().y) - MESSAGE_GAP
	message_label.offset_bottom = bottom
	message_label.offset_top = bottom - 12.0


## The name of the interact button on the current device.
func interact_button() -> String:
	return "A" if _gamepad else "E"


## Shows "E  Talk to ..." above the player when something usable is in front of them.
func _update_prompt() -> void:
	var target: Node = null
	if _player and _player.can_act and not info_panel.visible and _player.is_inside_tree():
		target = _player.get_target()
	prompt_panel.visible = target != null
	if target == null:
		return
	prompt_label.text = "%s  %s" % [interact_button(), Player.prompt_for(target)]
	prompt_panel.size = Vector2.ZERO
	var screen := _player.get_global_transform_with_canvas().origin
	var size := prompt_panel.get_combined_minimum_size()
	prompt_panel.position = (screen + Vector2(-size.x / 2.0, -46)).clamp(Vector2(2, 2), get_viewport().get_visible_rect().size - size - Vector2(2, 2)).round()


func fade_to_black() -> void:
	await create_tween().tween_property(fade, "color:a", 1.0, 0.6).finished


func fade_from_black() -> void:
	await create_tween().tween_property(fade, "color:a", 0.0, 0.6).finished


func _refresh_clock() -> void:
	date_label.text = "%s, Year %d" % [GameClock.get_date_string(), GameClock.year]
	time_label.text = GameClock.get_time_string()


func _refresh_status() -> void:
	var pieces := 0
	for id: String in Gear.owned:
		pieces += Gear.count(id)
	_status.text = "Food %d energy  ·  Gear %d  ·  J: Journal" % [FoodDB.carried_energy(), pieces]


## Lists carried forage and food.
func _refresh_bag() -> void:
	for child in bag_list.get_children():
		bag_list.remove_child(child)
		child.queue_free()
	var ids := Inventory.items.keys().filter(func(id): return ItemDB.get_item(id) != null)
	ids.sort_custom(func(a, b): return ItemDB.get_item(a).display_name < ItemDB.get_item(b).display_name)
	for id: String in ids:
		var item := ItemDB.get_item(id)
		var row := HBoxContainer.new()
		var icon := TextureRect.new()
		icon.texture = item.icon
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		var label := Label.new()
		label.text = "%s x%d" % [item.display_name, Inventory.count(id)]
		row.add_child(icon)
		row.add_child(label)
		bag_list.add_child(row)
	bag_panel.visible = not ids.is_empty()
	bag_panel.set_deferred("size", Vector2.ZERO) # shrink to fit
