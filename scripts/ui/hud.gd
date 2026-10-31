class_name HUD
extends CanvasLayer
## On-screen info: date, time, where you are, a hint line naming the keys for
## the Journal, Quests and Backpack (which hold everything else), messages,
## signs you're reading, and screen fades.

## Walking this far (pixels) from a sign closes it.
const INFO_CLOSE_DISTANCE := 24.0
## Gap (pixels) between the message and the sign panel it sits above.
const MESSAGE_GAP := 2.0
## Groups of the screens that hide the HUD while they're open.
## Seconds the place name stays up after you arrive.
const LOCATION_SHOWN := 4.0
## Seconds the hint line naming the book's keys stays up after you arrive
## somewhere or close a menu, before it fades to leave the view clear.
const HINTS_SHOWN := 8.0
## Seconds the wipe between places takes each way.
const WIPE_TIME := 0.5
## The wipe's color: the deep night of the palette, not flat black.
const WIPE_COLOR := Color(0.067, 0.059, 0.09)
const COVERING_GROUPS := ["journal", "pause_menu", "park_map", "day_summary"]

var _player: Player
## The food energy you carry, under the time.
var food_label: Label
var _location_text := ""
var _location_tween: Tween
var _hints_tween: Tween
var _status: Label
## The "you got this" cards at the top left.
var toasts: ItemToasts
## The menu-sized root every HUD element sits under (see UiScale).
var _screen: Control
## Darkens the world behind the pause menu and the book.
var _dim: ColorRect
var _message_tween: Tween
var _info_anchor := Vector2.ZERO
## True while a menu, map or conversation covers the screen.
var _covered := false
## What the use prompt names, so a new target fades its prompt in.
var _prompt_target: Node

## Sent when the player switches between keyboard and gamepad, so screens
## showing button names can refresh them.
signal device_changed

@onready var date_label: Label = %DateLabel
@onready var time_label: Label = %TimeLabel
@onready var status_bar: HBoxContainer = %StatusBar
@onready var message_label: Label = %MessageLabel
@onready var fade: ColorRect = %Fade
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
	UiScale.layer(self)
	_screen = UiScale.wrap_children(self)
	message_label.modulate.a = 0.0
	var wipe := ShaderMaterial.new()
	wipe.shader = preload("res://assets/shaders/pixel_wipe.gdshader")
	wipe.set_shader_parameter("rect_size", UiScale.SCREEN)
	fade.material = wipe
	fade.color = Color(WIPE_COLOR, fade.color.a)
	GameClock.time_changed.connect(_refresh_clock.unbind(2))
	GameClock.day_started.connect(_refresh_clock.unbind(3))
	device_changed.connect(_refresh_status)
	_dim = ColorRect.new()
	_dim.color = Color(0.082, 0.078, 0.11, 0)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(_dim)
	_screen.move_child(_dim, 0)
	# Messages ("You fell asleep at...", what a find is) sit on a dark card
	# rather than floating over the world.
	var card := StyleBoxFlat.new()
	card.bg_color = Color(0.165, 0.106, 0.078, 0.72)
	card.border_color = Color(0.573, 0.412, 0.239, 0.9)
	card.set_border_width_all(1)
	card.set_content_margin_all(3)
	card.content_margin_left = 5
	card.content_margin_right = 5
	message_label.add_theme_stylebox_override("normal", card)
	toasts = ItemToasts.new()
	_screen.add_child(toasts)
	_screen.move_child(toasts, fade.get_index()) # under the fade, so the black covers it
	Inventory.added.connect(_on_item_added)
	Gear.added.connect(_on_gear_added)
	QuestLog.quest_completed.connect(func(_quest: QuestData) -> void: Sound.play("quest_done", 0.0, 0.0))
	var panel := PanelContainer.new()
	_status = ButtonHints.new()
	panel.add_child(_status)
	status_bar.add_child(panel)
	# The clock and the place name are wooden plaques; the hint line keeps the plain frame.
	var plaque := clock_panel.get_theme_stylebox("panel", "PanelContainer").duplicate() as StyleBoxTexture
	plaque.texture = load("res://assets/ui/plaque.png")
	clock_panel.add_theme_stylebox_override("panel", plaque)
	# The sky dial sits on the time's row, under the date, so the plaque
	# grows down rather than out toward the place name.
	var labels := time_label.get_parent()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	labels.add_child(row)
	labels.move_child(row, time_label.get_index())
	labels.remove_child(time_label)
	var dial := ClockDial.new()
	dial.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dial)
	time_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(right)
	right.add_child(time_label)
	# The food you carry, which is what you trade with, under the time, as
	# Stardew Valley keeps your gold under its clock.
	var purse := HBoxContainer.new()
	purse.alignment = BoxContainer.ALIGNMENT_END
	purse.add_theme_constant_override("separation", 2)
	var apple := TextureRect.new()
	var fruit := ItemDB.get_item("lamon_apple")
	apple.texture = fruit.icon if fruit else null
	apple.custom_minimum_size = Vector2(12, 12)
	apple.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	apple.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	apple.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	purse.add_child(apple)
	food_label = Label.new()
	food_label.add_theme_color_override("font_color", Color(1, 0.831, 0.541))
	food_label.tooltip_text = "Food energy you carry (what you trade with)"
	purse.add_child(food_label)
	right.add_child(purse)
	Inventory.changed.connect(_refresh_food)
	_refresh_food()
	location_panel.add_theme_stylebox_override("panel", plaque)
	# The use prompt is a slim bubble, not a full frame, so it doesn't cover
	# the person or the sign you're facing.
	var bubble := StyleBoxFlat.new()
	bubble.bg_color = Color(0.165, 0.106, 0.078, 0.82)
	bubble.border_color = Color(0.69, 0.573, 0.373, 0.9)
	bubble.set_border_width_all(1)
	bubble.set_corner_radius_all(2)
	bubble.content_margin_left = 4.0
	bubble.content_margin_right = 4.0
	bubble.content_margin_top = 0.0
	bubble.content_margin_bottom = 1.0
	prompt_panel.add_theme_stylebox_override("panel", bubble)


func bind_player(player: Player) -> void:
	_player = player
	_refresh_clock()
	_refresh_status()


## Call after the player changes a setting, so prompts follow it.
func refresh_settings() -> void:
	device_changed.emit()


func show_message(text: String) -> void:
	message_label.text = text
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_property(message_label, "modulate:a", 1.0, 0.2)
	_message_tween.tween_interval(2.5)
	_message_tween.tween_property(message_label, "modulate:a", 0.0, 0.6)


func _on_item_added(id: String, amount: int) -> void:
	var item := ItemDB.get_item(id)
	if item:
		toasts.notify(id, item.icon, item.display_name, amount)
		Sound.play("pickup", 0.0, 0.08)


## New gear is a bigger moment than a berry: it gets the brighter chime.
func _on_gear_added(id: String, amount: int) -> void:
	var gear := Gear.get_gear(id)
	if gear:
		# a cam shows its size: the newest one on the rack (CamSizes)
		var icon := CamSizes.icon(Gear.count(id) - 1) if id == "cam" else gear.icon
		toasts.notify("gear:" + id, icon, gear.display_name, amount)
		Sound.play("item_get", 0.0, 0.0)


## The location banner at the top of the screen.
## Parts of a long name ("Yosemite Valley · Curry Village · ...") are dropped
## from the front until it fits between the screen's left side and the clock.
func set_location(text: String) -> void:
	if text == _location_text:
		return
	_location_text = text
	_show_location_banner()
	var parts := text.split(" · ")
	# the banner is centered, so its right edge is half its width past the middle
	var middle := UiScale.SCREEN.x / 2.0
	var clock_left := clock_panel.get_global_rect().position.x
	var room := 2.0 * (clock_left - 4.0 - middle)
	location_label.text = " · ".join(parts)
	while parts.size() > 1 and location_panel.get_combined_minimum_size().x > room:
		parts.remove_at(0)
		location_label.text = " · ".join(parts)
	# keep it centered at its new width
	var width := roundf(location_panel.get_combined_minimum_size().x / 2.0) * 2.0
	location_panel.offset_left = -width / 2.0
	location_panel.offset_right = width / 2.0


## The place name shows as you arrive, then fades after a few seconds, as
## in Stardew Valley; it comes back each time you go somewhere new.
func _show_location_banner() -> void:
	if _location_tween:
		_location_tween.kill()
	location_panel.modulate.a = 1.0
	_location_tween = create_tween()
	_location_tween.tween_interval(LOCATION_SHOWN)
	_location_tween.tween_property(location_panel, "modulate:a", 0.0, 0.8)
	_show_hints()


## Brings the hint line up for a while, then fades it, as cozy games keep
## their screen clear once you know the keys.
func _show_hints() -> void:
	if _hints_tween:
		_hints_tween.kill()
	if _covered:
		return
	status_bar.modulate.a = 1.0
	_hints_tween = create_tween()
	_hints_tween.tween_interval(HINTS_SHOWN)
	_hints_tween.tween_property(status_bar, "modulate:a", 0.0, 0.8)


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
	# Cards drop below the place name while it's up, if it reaches over them.
	toasts.top_margin = 4.0
	var banner := location_panel.get_rect()
	if location_panel.modulate.a > 0.0 and banner.position.x < 4.0 + ItemToasts.CARD_WIDTH:
		toasts.top_margin = banner.end.y + 2.0
	if info_panel.visible and _player and _player.global_position.distance_to(_info_anchor) > INFO_CLOSE_DISTANCE:
		hide_info()
	_update_cover()
	_update_message_position()
	_update_prompt()


func _input(event: InputEvent) -> void:
	var was_gamepad := _gamepad
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		_gamepad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		_gamepad = false
	if _gamepad != was_gamepad:
		device_changed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if info_panel.visible and event.is_action_pressed("ui_cancel"):
		hide_info()
		get_viewport().set_input_as_handled()


## Hides the HUD while the journal, pause menu, map or a conversation is open.
func _update_cover() -> void:
	var covered := not get_tree().get_nodes_in_group("dialogue_box").is_empty()
	var menu := false
	for group: String in COVERING_GROUPS:
		var screen := get_tree().get_first_node_in_group(group)
		if screen and screen.is_open():
			menu = true
	# Cards hide under a menu, and during a conversation unless they're
	# fresh (what you just bought or cooked), so they don't sit over the
	# person you're talking to.
	toasts.visible = not menu and (not covered or toasts.has_fresh())
	_dim.color.a = move_toward(_dim.color.a, 0.42 if menu else 0.0, get_process_delta_time() * 3.0)
	covered = covered or menu
	if covered == _covered:
		return
	_covered = covered
	var alpha := 0.0 if covered else 1.0
	for panel: Control in [clock_panel, location_panel, info_panel]:
		panel.modulate.a = alpha
	message_label.visible = not covered
	if covered:
		if _hints_tween:
			_hints_tween.kill()
		status_bar.modulate.a = 0.0
	else:
		_show_hints()


## The pickup message sits at the bottom left, or above the sign panel while one is open.
func _update_message_position() -> void:
	var bottom := -26.0
	if info_panel.visible:
		bottom = -30.0 - maxf(info_panel.size.y, info_panel.get_combined_minimum_size().y) - MESSAGE_GAP
	message_label.offset_bottom = bottom
	message_label.offset_top = bottom - 12.0


## The name of the interact button on the current device.
func interact_button() -> String:
	return prompt("E", "A")


## Picks the button name to show for the current device: [param keyboard] or [param gamepad].
## The Button prompts setting can pin it to one device.
func prompt(keyboard: String, gamepad: String) -> String:
	match Settings.prompts:
		Settings.Prompts.KEYBOARD:
			return keyboard
		Settings.Prompts.GAMEPAD:
			return gamepad
	return gamepad if _gamepad else keyboard


## Shows "E  Talk to ..." above the player when something usable is in front of them.
func _update_prompt() -> void:
	var target: Node = null
	if _player and _player.can_act and not info_panel.visible and _player.is_inside_tree():
		target = _player.get_target()
	prompt_panel.visible = target != null
	if target != _prompt_target:
		_prompt_target = target
		if target:
			prompt_panel.modulate.a = 0.0
			create_tween().tween_property(prompt_panel, "modulate:a", 1.0, 0.12)
	if target == null:
		return
	prompt_label.text = "[%s] %s" % [interact_button(), Player.prompt_for(target)]
	if target.has_method("can_receive_gift") and target.can_receive_gift():
		prompt_label.text += "   [%s] Give a gift" % prompt("G", "LB")
	prompt_panel.size = Vector2.ZERO
	var screen := UiScale.from_view(_player.get_global_transform_with_canvas().origin)
	# Above whichever head is higher, so it never covers the person you face.
	if target is CanvasItem:
		screen.y = minf(screen.y, UiScale.from_view((target as CanvasItem).get_global_transform_with_canvas().origin).y)
	var size := prompt_panel.get_combined_minimum_size()
	prompt_panel.position = (screen + Vector2(-size.x / 2.0, -40)).clamp(Vector2(2, 2), UiScale.SCREEN - size - Vector2(2, 2)).round()


## Covers the screen with the pixel-diamond wipe (see pixel_wipe.gdshader).
func fade_to_black() -> void:
	await create_tween().tween_property(fade, "color:a", 1.0, WIPE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).finished


## Wipes the cover away the same way, a touch slower, so the new place opens up.
func fade_from_black() -> void:
	await create_tween().tween_property(fade, "color:a", 0.0, WIPE_TIME * 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).finished


func _refresh_food() -> void:
	food_label.text = "%d energy" % Barter.purse()


func _refresh_clock() -> void:
	if food_label:
		_refresh_food()
	date_label.text = "%s, Year %d" % [GameClock.get_date_string(), GameClock.year]
	time_label.text = GameClock.get_time_string()


## The main story's next step, or what to do when there isn't one (the pause
## menu shows it). Empty when there's nothing to point at.
static func objective_text() -> String:
	var main := QuestLog.main_objective()
	if not main.is_empty():
		return main.objective
	if not QuestLog.has_guidebook():
		return "Pick up a climbing guidebook at the Mountain Shop in Curry Village."
	if QuestLog.final_entry_pending():
		return "Talk to Galen Clark and write your last page."
	var year := QuestLog.guardian_objective()
	if not year.is_empty():
		return year.objective
	return ""


## The hint line: the keys that open the book's three tabs. A gamepad opens
## it with Y and turns the tabs from there.
func _refresh_status() -> void:
	_status.text = prompt("[J] Journal  ·  [Q] Quests  ·  [B] Backpack", "[Y] Journal, Quests, Backpack")
