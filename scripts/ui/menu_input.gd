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
					im.set_pixel(x, y, Color("2a1b14"))
				"=":
					im.set_pixel(x, y, Color("ffd48a") if y < 4 else Color("d8a63b"))
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


static var _boxes: Dictionary = {}


## A small checkbox, ticked or empty, for lists like the guidebook's.
static func checkbox_texture(ticked: bool) -> Texture2D:
	if _boxes.has(ticked):
		return _boxes[ticked]
	var im := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	var rim := Color("2a1b14")
	for y in range(0, 8):
		for x in range(0, 8):
			var edge := x == 0 or y == 0 or x == 7 or y == 7
			im.set_pixel(x, y, rim if edge else Color("e4ddcc") if ticked else Color("5e4a38"))
	if ticked:
		for p in [Vector2i(2, 4), Vector2i(3, 5), Vector2i(4, 4), Vector2i(5, 3), Vector2i(6, 2), Vector2i(2, 3), Vector2i(3, 4)]:
			im.set_pixelv(p, Color("5c8f3c"))
	_boxes[ticked] = ImageTexture.create_from_image(im)
	return _boxes[ticked]


## Puts a picture at the left (or, with [param right], the right) of
## [param label], vertically centered; its text should leave room for it.
static func badge(label: Control, texture: Texture2D, right := false, flip := false) -> void:
	var icon := label.get_node_or_null("Badge") as TextureRect
	if icon == null:
		icon = TextureRect.new()
		icon.name = "Badge"
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_child(icon)
	icon.texture = texture
	icon.flip_v = flip
	var size := texture.get_size() if texture else Vector2.ZERO
	icon.anchor_top = 0.5
	icon.anchor_bottom = 0.5
	icon.anchor_left = 1.0 if right else 0.0
	icon.anchor_right = icon.anchor_left
	icon.offset_left = -size.x if right else 1.0
	icon.offset_right = 0.0 if right else 1.0 + size.x
	icon.offset_top = -size.y / 2.0
	icon.offset_bottom = size.y / 2.0
	icon.visible = texture != null


## A strip over the top or bottom edge of [param holder] that fades a
## scrolling page into the panel behind it, solid over its outer third so a
## row cut off at the edge never shows as a sliver of half letters. The
## colors are the theme panel's paper at its top and bottom. Starts hidden;
## show it while there's more page past that edge. [param right_gap] leaves a
## scroll bar clear.
static func edge_fade(holder: Control, top: bool, right_gap := 0.0) -> TextureRect:
	var gradient := Gradient.new()
	var paper := Color(37 / 255.0, 27 / 255.0, 20 / 255.0) if not top else Color(52 / 255.0, 36 / 255.0, 22 / 255.0)
	gradient.set_color(0, Color(paper, 1.0 if top else 0.0))
	gradient.set_color(1, Color(paper, 0.0 if top else 1.0))
	gradient.add_point(0.35 if top else 0.65, Color(paper, 1.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	texture.width = 4
	texture.height = 16
	var fade := TextureRect.new()
	fade.texture = texture
	fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.anchor_right = 1.0
	fade.offset_right = -right_gap
	if top:
		fade.offset_bottom = 8.0
	else:
		fade.anchor_top = 1.0
		fade.anchor_bottom = 1.0
		fade.offset_top = -18.0
	fade.visible = false
	holder.add_child(fade)
	return fade
