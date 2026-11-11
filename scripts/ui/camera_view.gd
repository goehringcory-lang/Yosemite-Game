class_name CameraView
extends CanvasLayer
## Looking through the camera Ansel Adams lends you (see Photos).
##
## The camera key (F, or RB on a pad) raises it: the screen darkens round a
## frame, three to two like a print, and the walking keys move the frame
## about the view instead of you. Whatever stands inside it is named under
## the frame as you aim, like the binoculars at Glacier Point, with a gold
## note when the picture would be a new one for Ansel's list. The world
## doesn't stop for you: the deer walks on and the light goes.
##
## The shutter (interact) takes what the frame holds: one frame is drawn with
## the HUD, the viewfinder and the quest bubbles over people's heads hidden,
## the frame is cut out of it, sized to a print and toned for the film, and
## Photos puts it in the album. The print shows in the corner for a moment
## with its title and its stars.
##
## R (LB or the mouse wheel) changes the lens once you have more than one,
## T (X on a pad) the film, Tab (Y) opens the album, and Esc (B) or the
## camera key again puts the camera away. World adds one of these.

signal closed

const SCREEN := UiScale.SCREEN
## UI pixels a second the frame moves, and how much faster with run held.
const MOVE_SPEED := 96.0
const FAST := 2.4
## Seconds between looks at what the frame holds.
const LOOK_EVERY := 0.15
## Seconds the print just made stays in the corner.
const CARD_TIME := 3.2
## The room the hints at the foot of the screen keep clear of the frame.
const FOOT := 16.0
const INK := Color("2a1b14")
const PAPER := Color("f5eee0")
const GOLD := Color(1, 0.831, 0.541)
const SHADE := Color(0.05, 0.04, 0.06, 0.55)
const NO_CAMERA := "You have no camera. Ansel Adams lends one out, at Best's Studio in Yosemite Village."
const FULL := "The album is full (%d prints). Take one out to make room."

var _open := false
## The middle of the frame, in UI pixels.
var _center := SCREEN / 2.0
## What the frame holds now (Photos.observe), and the list entries a picture
## of it would be the first to answer.
var _view: Dictionary = {}
var _fresh: Array[Dictionary] = []
var _look := 0.0
## True from the shutter until the print is in the album.
var _busy := false

var _root: Control
var _finder: Control
var _status: Label
var _subject: Label
var _note: Label
var _hints: ButtonHints
var _flash: ColorRect
var _card: PanelContainer
var _card_print: TextureRect
var _card_title: Label
var _card_note: Label
var _card_stars: Control
var _card_stars_count := 0
var _card_tween: Tween
var _message_tween: Tween


func _ready() -> void:
	layer = 22
	UiScale.layer(self)
	add_to_group("camera_view")
	_root = Control.new()
	_root.name = "Viewfinder"
	UiScale.fit(_root)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)
	_finder = Control.new()
	UiScale.fit(_finder)
	_finder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_finder.draw.connect(_draw_finder)
	_root.add_child(_finder)
	_status = _text(GOLD)
	_status.position = Vector2(6, 3)
	_subject = _text(PAPER)
	_subject.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note = _text(GOLD)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hints = ButtonHints.new()
	_hints.add_theme_color_override("font_color", PAPER)
	_hints.add_theme_color_override("font_outline_color", INK)
	_hints.add_theme_constant_override("outline_size", 4)
	_hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hints.position = Vector2(0, SCREEN.y - FOOT + 1.0)
	_hints.size = Vector2(SCREEN.x, FOOT - 2.0)
	_root.add_child(_hints)
	_flash = ColorRect.new()
	UiScale.fit(_flash)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_build_card()
	GameClock.curfew_reached.connect(close.bind(true))


func _text(color: Color) -> Label:
	var label := Label.new()
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(label)
	return label


## The print that slides into the corner after the shutter: the picture in
## a white border, its title, its stars, and what it did for the list.
func _build_card() -> void:
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.visible = false
	add_child(_card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 1)
	_card.add_child(column)
	var mount := PanelContainer.new()
	mount.add_theme_stylebox_override("panel", PhotoAlbum.mount_style())
	mount.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(mount)
	_card_print = TextureRect.new()
	_card_print.custom_minimum_size = Vector2(Photos.PRINT_SIZE) / 3.0
	_card_print.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card_print.stretch_mode = TextureRect.STRETCH_SCALE
	mount.add_child(_card_print)
	_card_title = Label.new()
	_card_title.add_theme_color_override("font_color", GOLD)
	_card_title.custom_minimum_size.x = 124
	_card_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_card_title)
	_card_stars = Control.new()
	_card_stars.custom_minimum_size = Vector2(124, 10)
	_card_stars.draw.connect(func() -> void: PhotoAlbum.draw_stars(_card_stars, Vector2(0, 0), _card_stars_count))
	column.add_child(_card_stars)
	_card_note = Label.new()
	_card_note.add_theme_color_override("font_color", PhotoAlbum.DONE)
	_card_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_note.custom_minimum_size.x = 124
	column.add_child(_card_note)


func is_open() -> bool:
	return _open


## The lens on the camera (a key of Photos.LENS_FRAMES).
func lens() -> String:
	return Photos.lens if Photos.lens in Photos.lenses() else "normal"


## The frame on the menu screen, in UI pixels.
func frame_rect() -> Rect2:
	var size: Vector2 = Photos.LENS_FRAMES[lens()] / UiScale.FACTOR
	return Rect2((_center - size / 2.0).round(), size)


## The frame in the world, in global pixels: what a picture would hold.
func world_rect() -> Rect2:
	var frame := frame_rect()
	var in_view := Rect2(frame.position * UiScale.FACTOR, frame.size * UiScale.FACTOR)
	return get_viewport().get_canvas_transform().affine_inverse() * in_view


## What the frame holds, as of the last look.
func view() -> Dictionary:
	return _view


func open() -> void:
	if _open:
		return
	var player := _player()
	if player == null or not player.can_act:
		return
	_open = true
	player.can_act = false
	var hud := get_tree().get_first_node_in_group("hud") as HUD
	if hud and not hud.device_changed.is_connected(_refresh_hints):
		hud.device_changed.connect(_refresh_hints)
	_center = SCREEN / 2.0 + Vector2(0, -12)
	_clamp_frame()
	_root.visible = true
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.15)
	_note.text = ""
	_look_now()
	_refresh_hints()
	Sound.play("ui_open")


## Puts the camera away. [param free_player] is false when something else
## has taken hold of you (a conversation, a door): it lets go of you itself.
func close(free_player := true) -> void:
	if not _open:
		return
	_open = false
	_busy = false
	_root.visible = false
	_card.visible = false
	var album := _album()
	if album and album.is_open():
		album.close()
	var player := _player()
	if player and free_player:
		player.can_act = true
	Sound.play("ui_close")
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		if event.is_action_pressed("camera") and _can_raise():
			get_viewport().set_input_as_handled()
			if Photos.has_camera():
				open()
			else:
				get_tree().call_group("hud", "show_message", NO_CAMERA)
		return
	var album := _album()
	if album and album.is_open():
		return # the album has the keys while it's open
	if _busy:
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("camera") or event.is_action_pressed("pause"):
		close()
	elif _is_film(event):
		next_film()
	elif _lens_turn(event) != 0:
		next_lens(_lens_turn(event))
	elif _is_album(event):
		if album:
			album.open()
	elif MenuInput.confirm(event):
		shoot()
	else:
		return
	get_viewport().set_input_as_handled()


## True if the camera can come up: you're free to act, outside any menu or
## conversation, and World isn't moving you between places.
func _can_raise() -> bool:
	var player := _player()
	var world := get_tree().get_first_node_in_group("world")
	if player == null or not player.can_act or (world and world.get("_busy")):
		return false
	return get_tree().get_nodes_in_group("dialogue_box").is_empty()


func _is_film(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo and event.physical_keycode == KEY_T
	return event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_X


func _is_album(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_focus_next"):
		return true
	return event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y


## +1 or -1 for a lens change: R, LB, or the mouse wheel either way. (RB is
## the camera button, which puts it away.)
func _lens_turn(event: InputEvent) -> int:
	if event is InputEventKey:
		return 1 if event.pressed and not event.echo and event.physical_keycode == KEY_R else 0
	if event.is_action_pressed("tab_previous"):
		return 1
	return -1 if event.is_action_pressed("tab_next") else 0


## Changes to the next film.
func next_film() -> void:
	Photos.film = Photos.FILMS[(Photos.FILMS.find(Photos.film) + 1) % Photos.FILMS.size()]
	Sound.play("ui_move")
	_refresh_status()
	_refresh_hints()


## Fits the next lens (or the one before), if you have more than one.
func next_lens(step := 1) -> void:
	var have := Photos.lenses()
	if have.size() < 2:
		say("One lens for now. Ansel has others.")
		return
	Photos.lens = have[wrapi(have.find(lens()) + step, 0, have.size())]
	Sound.play("ui_move")
	_clamp_frame()
	_look_now()
	_refresh_hints()


## A line under the frame for a moment.
func say(text: String) -> void:
	_note.text = text
	_note.modulate.a = 1.0
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(2.4)
	_message_tween.tween_callback(func() -> void: _note.text = "")


func _process(delta: float) -> void:
	if not _open:
		return
	var world := get_tree().get_first_node_in_group("world")
	if world == null or world.get("_busy") or not get_tree().get_nodes_in_group("dialogue_box").is_empty():
		close(false) # a door, a drive or a conversation took over
		return
	# You stand still to take a picture, whatever else lets go of you.
	var player := _player()
	if player:
		player.can_act = false
	var album := _album()
	# The album covers the viewfinder while it's open.
	_root.visible = not (album and album.is_open())
	if not _root.visible:
		_card.visible = false
		return
	if not _busy:
		var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if move != Vector2.ZERO:
			_center += move * MOVE_SPEED * (FAST if Input.is_action_pressed("run") else 1.0) * delta
			_clamp_frame()
	_look -= delta
	if _look <= 0.0:
		_look_now()
	_place_labels()
	_finder.queue_redraw()


## Moves the frame by [param by] UI pixels (for tests and the stick alike).
func nudge(by: Vector2) -> void:
	_center += by
	_clamp_frame()
	_look_now()


func _clamp_frame() -> void:
	var half: Vector2 = Photos.LENS_FRAMES[lens()] / UiScale.FACTOR / 2.0
	_center.x = clampf(_center.x, half.x + 2.0, SCREEN.x - half.x - 2.0)
	_center.y = clampf(_center.y, half.y + 2.0, SCREEN.y - half.y - 2.0)


## Looks through the frame: names what's in it, and marks a picture the
## list hasn't had.
func _look_now() -> void:
	_look = LOOK_EVERY
	var player := _player()
	_view = Photos.observe(world_rect(), player.global_position) if player else {}
	_fresh = Photos.new_for_list(_view)
	var names := PackedStringArray()
	for subject: Dictionary in Photos.named_subjects(_view).slice(0, 3):
		names.append(subject.name)
	_subject.text = " · ".join(names)
	if _message_tween == null or not _message_tween.is_running():
		_note.text = "New for Ansel's list: %s" % _fresh[0].name if not _fresh.is_empty() else ""
	_refresh_status()
	_place_labels()


func _refresh_status() -> void:
	var light := str(Photos.LIGHTS.get(_view.get("light", ""), {}).get("name", ""))
	_status.text = "%s · %s film · %s · %d of %d prints" % [Photos.LENS_NAMES[lens()], Photos.FILM_NAMES[Photos.film],
		light.left(1).to_upper() + light.substr(1) if light != "" else "No light", Photos.album.size(), Photos.ALBUM_SIZE]


## The subject's name sits under the frame with the note for the list under
## that; over the frame when it's at the foot of the screen; and along the
## inside of its lower edge when it fills the screen (the wide lens).
func _place_labels() -> void:
	var frame := frame_rect()
	_subject.size = Vector2(SCREEN.x, 12)
	_note.size = Vector2(SCREEN.x, 12)
	var x := frame.get_center().x - SCREEN.x / 2.0
	if frame.end.y + 26.0 < SCREEN.y - FOOT:
		_subject.position = Vector2(x, frame.end.y + 2.0)
		_note.position = Vector2(x, frame.end.y + 14.0)
	elif frame.position.y >= 40.0:
		_subject.position = Vector2(x, frame.position.y - 14.0)
		_note.position = Vector2(x, frame.position.y - 26.0)
	else:
		_subject.position = Vector2(x, frame.end.y - 15.0)
		_note.position = Vector2(x, frame.end.y - 27.0)


func _refresh_hints() -> void:
	if not _open:
		return
	var tree := get_tree()
	var parts := PackedStringArray()
	parts.append("[%s] Shutter" % MenuInput.button(tree, "E", "A"))
	parts.append("[%s] Aim" % MenuInput.button(tree, "WASD", "Stick"))
	if Photos.lenses().size() > 1:
		parts.append("[%s] Lens" % MenuInput.button(tree, "R", "LB"))
	parts.append("[%s] Film" % MenuInput.button(tree, "T", "X"))
	parts.append("[%s] Album" % MenuInput.button(tree, "Tab", "Y"))
	parts.append("[%s] Put away" % MenuInput.button(tree, "Esc", "B"))
	_hints.text = "   ".join(parts)


## The viewfinder: the view outside the frame in shade, the frame's edge and
## corner brackets, faint lines at the thirds, and a mark at the middle.
func _draw_finder() -> void:
	var frame := frame_rect()
	_finder.draw_rect(Rect2(0, 0, SCREEN.x, frame.position.y), SHADE)
	_finder.draw_rect(Rect2(0, frame.end.y, SCREEN.x, SCREEN.y - frame.end.y), SHADE)
	_finder.draw_rect(Rect2(0, frame.position.y, frame.position.x, frame.size.y), SHADE)
	_finder.draw_rect(Rect2(frame.end.x, frame.position.y, SCREEN.x - frame.end.x, frame.size.y), SHADE)
	var thirds := Color(PAPER, 0.16)
	for i in [1, 2]:
		_finder.draw_rect(Rect2(frame.position.x + roundf(frame.size.x * i / 3.0), frame.position.y, 1, frame.size.y), thirds)
		_finder.draw_rect(Rect2(frame.position.x, frame.position.y + roundf(frame.size.y * i / 3.0), frame.size.x, 1), thirds)
	var edge := Color(GOLD if not _fresh.is_empty() else PAPER, 0.9)
	_finder.draw_rect(frame.grow(1.0), Color(INK, 0.8), false, 1.0)
	_finder.draw_rect(frame, Color(edge, 0.55), false, 1.0)
	var arm := minf(12.0, frame.size.y / 4.0)
	for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var at := frame.position + corner * (frame.size - Vector2.ONE)
		var dir := Vector2(1.0 - corner.x * 2.0, 1.0 - corner.y * 2.0)
		_finder.draw_rect(Rect2(at, Vector2(arm * dir.x, 1)).abs(), edge)
		_finder.draw_rect(Rect2(at, Vector2(1, arm * dir.y)).abs(), edge)
		_finder.draw_rect(Rect2(at + dir, Vector2((arm - 1.0) * dir.x, 1)).abs(), edge)
		_finder.draw_rect(Rect2(at + dir, Vector2(1, (arm - 1.0) * dir.y)).abs(), edge)
	var mid := frame.get_center().round()
	_finder.draw_rect(Rect2(mid.x - 3, mid.y, 7, 1), Color(edge, 0.7))
	_finder.draw_rect(Rect2(mid.x, mid.y - 3, 1, 7), Color(edge, 0.7))


# ---------------------------------------------------------------- the shutter

## Takes the picture in the frame and puts it in the album. Returns the
## photograph's record ({} if the album is full or there's nothing to see).
func shoot() -> Dictionary:
	if not _open or _busy:
		return {}
	if Photos.is_full():
		say(FULL % Photos.ALBUM_SIZE)
		Sound.play("ui_back")
		return {}
	_busy = true
	var frame := frame_rect()
	var player := _player()
	var seen := Photos.observe(world_rect(), player.global_position) if player else {}
	var image := await _capture(frame)
	if not _open:
		return {} # put away, or taken off somewhere, part way through
	var photo := Photos.develop(seen, image)
	_busy = false
	if photo.is_empty():
		return {}
	Sound.play("shutter", -2.0, 0.02)
	Rumble.play("clip")
	_flash.color.a = 0.55
	create_tween().tween_property(_flash, "color:a", 0.0, 0.3)
	_show_card(photo)
	_look_now()
	return photo


## Draws one frame with nothing over the world, and returns the part of it
## inside [param frame] (UI pixels) as a print: PRINT_SIZE, in the film's
## tones. Null where nothing is drawn (headless).
func _capture(frame: Rect2) -> Image:
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
		return null
	var hidden: Array[Node] = []
	var world := get_tree().get_first_node_in_group("world")
	var over: Array = get_tree().get_nodes_in_group("photo_hidden")
	over.append(self)
	over.append(world.hud if world and "hud" in world else null)
	for node in over:
		if node != null and node.visible:
			node.visible = false
			hidden.append(node)
	await RenderingServer.frame_post_draw
	var texture := get_viewport().get_texture()
	var shot := texture.get_image() if texture else null
	for node in hidden:
		if is_instance_valid(node):
			node.visible = true
	if shot == null or shot.is_empty():
		return null
	return print_from(shot, frame, get_viewport().get_stretch_transform(), Photos.film)


## Cuts [param frame] (UI pixels) out of [param shot], a picture of the
## whole window whose pixels [param stretch] maps the 960x540 view onto, and
## makes a print of it: first back to the view's own pixels (the window
## shows each one as a block), then to PRINT_SIZE (the wide lens halves,
## the long lens doubles), then toned for [param film].
static func print_from(shot: Image, frame: Rect2, stretch: Transform2D, film: String) -> Image:
	var in_view := Rect2(frame.position * UiScale.FACTOR, frame.size * UiScale.FACTOR)
	var pixels := Rect2i(stretch * in_view).intersection(Rect2i(Vector2i.ZERO, shot.get_size()))
	if pixels.size.x <= 0 or pixels.size.y <= 0:
		return null
	var print_image := shot.get_region(pixels)
	print_image.convert(Image.FORMAT_RGB8)
	var art := Vector2i(in_view.size)
	if print_image.get_size() != art:
		var whole := pixels.size.x % art.x == 0 and pixels.size.y % art.y == 0
		print_image.resize(art.x, art.y, Image.INTERPOLATE_NEAREST if whole else Image.INTERPOLATE_BILINEAR)
	if art != Photos.PRINT_SIZE:
		print_image.resize(Photos.PRINT_SIZE.x, Photos.PRINT_SIZE.y,
			Image.INTERPOLATE_BILINEAR if art.x > Photos.PRINT_SIZE.x else Image.INTERPOLATE_NEAREST)
	Photos.tone(print_image, film)
	return print_image


func _show_card(photo: Dictionary) -> void:
	_card_print.texture = Photos.texture(photo.id)
	_card_title.text = photo.title
	_card_stars_count = int(photo.stars)
	_card_stars.queue_redraw()
	var fresh: Array = photo.get("new", [])
	var names := PackedStringArray()
	for entry: Dictionary in fresh:
		names.append(entry.name)
	var notes := PackedStringArray()
	if not fresh.is_empty():
		notes.append("For Ansel's list: %s (%d of %d)" % [", ".join(names), Photos.listed_count(), Photos.SHOT_LIST.size()])
	var logged: Array = photo.get("logged", [])
	if not logged.is_empty():
		notes.append("New in the field log: %s" % ", ".join(PackedStringArray(logged)))
	_card_note.text = "\n".join(notes)
	_card_note.visible = _card_note.text != ""
	_card.visible = true
	_card.reset_size()
	var rest := Vector2(SCREEN.x - _card.get_combined_minimum_size().x - 6.0, 16.0)
	_card.position = rest + Vector2(40, 0)
	_card.modulate.a = 0.0
	if _card_tween:
		_card_tween.kill()
	_card_tween = create_tween()
	_card_tween.set_parallel()
	_card_tween.tween_property(_card, "position", rest, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_card_tween.tween_property(_card, "modulate:a", 1.0, 0.2)
	_card_tween.chain().tween_interval(CARD_TIME)
	_card_tween.chain().tween_property(_card, "modulate:a", 0.0, 0.4)
	_card_tween.chain().tween_callback(_card.hide)
	if not fresh.is_empty() or not logged.is_empty():
		Sound.play("item_get", -6.0, 0.0)


func _album() -> PhotoAlbum:
	return get_tree().get_first_node_in_group("photo_album") as PhotoAlbum


func _player() -> Player:
	var world := get_tree().get_first_node_in_group("world")
	return world.player if world and "player" in world else null
