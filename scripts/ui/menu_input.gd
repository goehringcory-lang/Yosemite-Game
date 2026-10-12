class_name MenuInput
extends RefCounted
## Input helpers shared by the menus.


## True when [param event] is a fresh press of [param action] ("move_up",
## "ui_down", ...). A key or button press counts once, but a held analog stick
## sends a motion event every frame it is past the deadzone, so a joypad axis
## only counts on the frame it crosses it. Without this one flick of the stick
## moves a menu cursor many steps.
static func pressed(event: InputEvent, action: StringName) -> bool:
	if not event.is_action_pressed(action):
		return false
	return not event is InputEventJoypadMotion or Input.is_action_just_pressed(action)


## The name to show for a control on the device in use: [param keyboard] or
## [param gamepad] (see HUD.prompt). Menus use it so every hint follows the
## same keyboard/gamepad switch and the Button prompts setting.
static func button(tree: SceneTree, keyboard: String, gamepad: String) -> String:
	var hud: HUD = null
	if tree:
		hud = tree.get_first_node_in_group("hud") as HUD
	if hud:
		return hud.prompt(keyboard, gamepad)
	Settings.ensure_loaded()
	return gamepad if Settings.prompts == Settings.Prompts.GAMEPAD else keyboard


## True for a fresh press of confirm (interact, use, or Enter).
static func confirm(event: InputEvent) -> bool:
	return event.is_action_pressed("interact") or event.is_action_pressed("use_tool") or event.is_action_pressed("ui_accept")


## -1, 0 or +1 for a fresh Up/Down press (keys, D-pad, or a stick flick).
static func vertical(event: InputEvent) -> int:
	if pressed(event, "move_up") or pressed(event, "ui_up"):
		return -1
	if pressed(event, "move_down") or pressed(event, "ui_down"):
		return 1
	return 0


## -1, 0 or +1 for a fresh Left/Right press.
static func horizontal(event: InputEvent) -> int:
	if pressed(event, "move_left") or pressed(event, "ui_left"):
		return -1
	if pressed(event, "move_right") or pressed(event, "ui_right"):
		return 1
	return 0


## Opens [param panel] with a quick fade and grow and the page swish, so
## menus don't just blink into place.
static func pop_in(panel: Control) -> void:
	panel.pivot_offset = panel.size / 2.0
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.96, 0.96)
	var tween := panel.create_tween().set_parallel()
	tween.tween_property(panel, "modulate:a", 1.0, 0.12)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sound.play("ui_open")


## The pointer beside the chosen line of a menu: a small gold arrow with a
## dark rim, drawn once.
static var _cursor: ImageTexture
const CURSOR_SHAPE := [
	"#....",
	"##...",
	"#=#..",
	"#==#.",
	"#==#.",
	"#=#..",
	"##...",
	"#....",
]


static func cursor_texture() -> Texture2D:
	if _cursor:
		return _cursor
	var im := Image.create_empty(5, 8, false, Image.FORMAT_RGBA8)
	for y in CURSOR_SHAPE.size():
		for x in 5:
			match CURSOR_SHAPE[y][x]:
				"#":
					im.set_pixel(x, y, Color("2a1f1a"))
				"=":
					im.set_pixel(x, y, Color("ffe08a") if y < 4 else Color("e0a040"))
	_cursor = ImageTexture.create_from_image(im)
	return _cursor


## Shows the arrow at the left of [param label] when [param chosen] (the
## label's text should start with two spaces to leave it room).
static func mark(label: Control, chosen: bool) -> void:
	var arrow := label.get_node_or_null("Cursor") as TextureRect
	if arrow == null:
		if not chosen:
			return
		arrow = TextureRect.new()
		arrow.name = "Cursor"
		arrow.texture = cursor_texture()
		arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		arrow.anchor_top = 0.5
		arrow.anchor_bottom = 0.5
		arrow.offset_left = 1.0
		arrow.offset_right = 6.0
		arrow.offset_top = -4.0
		arrow.offset_bottom = 4.0
		label.add_child(arrow)
	arrow.visible = chosen
