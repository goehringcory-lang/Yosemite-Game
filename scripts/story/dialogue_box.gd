class_name DialogueBox
extends CanvasLayer
## The conversation box at the bottom of the screen. Shows lines one at a
## time and can offer a list of choices.
##
##   var box := DialogueBox.open(player)
##   await box.say(lines)             # lines: [{"speaker": "...", "text": "..."}]
##   var i := await box.choose("Build it?", ["Yes", "No"])   # -1 if cancelled
##   var i := await box.choose("Buy?", names, "Clerk", icons)  # a picture per option (or null)
##   box.close()
##
## Or, for a one-off conversation: DialogueBox.say_to(player, lines)
##
## Text appears letter by letter at the Text speed setting (Settings); confirm
## while it's still appearing shows the whole page, and confirm again goes on.

const NAME_COLOR := Color(1.0, 0.85, 0.5)
## Room left at the start of each option for the arrow (MenuInput.mark).
const CURSOR := "   "
const HINT_COLOR := Color(1, 1, 1, 0.6)
## The text's width with and without a portrait beside it.
const TEXT_WIDTH := 456.0
const TEXT_WIDTH_PORTRAIT := 404.0
## A talking blip every this many letters while a person's line types out.
const BLIP_EVERY := 3
## How far the box rises as it opens, in pixels, and how long it takes.
const OPEN_RISE := 8.0
const OPEN_TIME := 0.14
## How far the next arrow bobs, in pixels, and how many bobs a second.
const ARROW_BOB := 1.0
const ARROW_SPEED := 1.2

var _panel: PanelContainer
var _name_label: Label
var _text_label: Label
var _options_box: VBoxContainer
var _hint_label: Label
## Letters shown so far on this page (fractional while revealing).
var _shown := 0.0
var _hint_time := 0.0
var _options: PackedStringArray = []
## A picture for each option (or null), when the list has any: the shops'
## goods, the campfire's dishes.
var _icons: Array = []
var _cursor := 0
var _opened_frame := 0
## The brass tag the speaker's name sits on, the bar behind the chosen option,
## and the arrow that bobs when the page is waiting for E.
var _tag_style: StyleBoxTexture
var _select_style: StyleBoxTexture
var _plain_style: StyleBoxEmpty
var _arrow: TextureRect
var _hint_text_width := 0.0
## The speaker's face, in a frame at the right of the box.
var _portrait_frame: PanelContainer
var _portrait: TextureRect
## The speaker's voice pitch, and the last letter that blipped.
var _voice := 1.0
var _blipped := 0
var _speaker := ""
## 0 while waiting, 1 after confirm, -1 after cancel.
var _answer := 0


## Creates a box on top of everything and returns it.
static func open(from: Node) -> DialogueBox:
	var box := DialogueBox.new()
	from.get_tree().root.add_child(box)
	return box


## The screen row of the box's top edge, so the HUD can keep clear of it.
func top() -> float:
	return _panel.get_global_rect().position.y if _panel else 0.0


## Shows [param lines] with the player frozen, then closes the box.
static func say_to(player: Player, lines: Array) -> void:
	if lines.is_empty():
		return
	player.can_act = false
	var box := open(player)
	await box.say(lines)
	box.close()
	player.can_act = true


func _ready() -> void:
	layer = 30
	add_to_group("dialogue_box") # World waits for the box to close before passing the player out
	_opened_frame = Engine.get_process_frames()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# Sits on the bottom edge of the screen and grows upward, so a long list of
	# choices (the stores, a campfire with every recipe) never runs off the bottom.
	_panel = PanelContainer.new()
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 8.0
	_panel.offset_right = 472.0
	_panel.offset_top = -86.0
	_panel.offset_bottom = -8.0
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.custom_minimum_size = Vector2(464, 78)
	root.add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_panel.add_child(row)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 1)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	_portrait_frame = PanelContainer.new()
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("5a4634")
	frame.border_color = Color("c8a060")
	frame.set_border_width_all(1)
	frame.set_content_margin_all(1)
	frame.shadow_color = Color(0, 0, 0, 0.35)
	frame.shadow_offset = Vector2(1, 1)
	frame.shadow_size = 1
	_portrait_frame.add_theme_stylebox_override("panel", frame)
	_portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_portrait_frame.visible = false
	row.add_child(_portrait_frame)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(40, 40)
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait_frame.add_child(_portrait)
	_name_label = Label.new()
	_name_label.add_theme_color_override("font_color", NAME_COLOR)
	# a brass-edged tab on the box's top-left edge, the speaker's name sitting in it
	_tag_style = _style("res://assets/ui/tag.png", 4.0)
	_tag_style.content_margin_left = 4.0
	_tag_style.content_margin_right = 4.0
	_tag_style.expand_margin_top = 5.0
	_tag_style.expand_margin_left = 2.0
	_name_label.add_theme_stylebox_override("normal", _tag_style)
	_name_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN # the tab hugs the name
	column.add_child(_name_label)
	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
	column.add_child(_text_label)
	_options_box = VBoxContainer.new()
	_options_box.add_theme_constant_override("separation", 0)
	column.add_child(_options_box)
	# Pushes the hint to the bottom edge of the box.
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(filler)
	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint_label.add_theme_color_override("font_color", HINT_COLOR)
	column.add_child(_hint_label)
	# the next arrow: drawn over the box, just left of the "Next" hint
	_arrow = TextureRect.new()
	_arrow.texture = load("res://assets/ui/next.png")
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.visible = false
	root.add_child(_arrow)
	_select_style = _style("res://assets/ui/select.png", 2.0)
	_select_style.content_margin_left = 2.0
	_select_style.expand_margin_top = 1.0
	_select_style.expand_margin_bottom = 1.0
	_plain_style = StyleBoxEmpty.new()
	_plain_style.content_margin_left = 2.0
	var hud := get_tree().get_first_node_in_group("hud") as HUD
	if hud:
		hud.device_changed.connect(_refresh_hint)
	# The box rises into place as it opens.
	root.modulate.a = 0.0
	root.position.y = OPEN_RISE
	var tween := create_tween().set_parallel()
	tween.tween_property(root, "modulate:a", 1.0, OPEN_TIME)
	tween.tween_property(root, "position:y", 0.0, OPEN_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	Sound.play("ui_open", -2.0)


## A nine-slice style from a texture, with its corners [param margin] pixels in.
func _style(path: String, margin: float) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(path)
	style.texture_margin_left = margin
	style.texture_margin_top = margin
	style.texture_margin_right = margin
	style.texture_margin_bottom = margin
	return style


## Longest text shown at once. Longer lines are split at sentence breaks so
## they fit the box (about four lines of the pixel font).
const PAGE_CHARS := 220


func say(lines: Array) -> void:
	for line: Dictionary in lines:
		var mood: String = line.get("mood", Portraits.mood_for(line.get("text", "")))
		for page in pages(line.get("text", "")):
			_show(line.get("speaker", ""), page, [], mood)
			await _next_input()


## [param text] split into pages of at most [constant PAGE_CHARS], breaking
## after a sentence where it can and between words where it can't.
static func pages(text: String) -> PackedStringArray:
	var result := PackedStringArray()
	var rest := text.strip_edges()
	while rest.length() > PAGE_CHARS:
		var cut := -1
		for mark in [". ", "? ", "! ", ": ", "; "]:
			cut = maxi(cut, rest.rfind(mark, PAGE_CHARS))
		if cut < PAGE_CHARS / 3:
			cut = rest.rfind(" ", PAGE_CHARS)
		if cut <= 0:
			break
		result.append(rest.left(cut + 1).strip_edges())
		rest = rest.substr(cut + 1).strip_edges()
	result.append(rest)
	return result


## Returns the chosen option's index, or -1 if the player cancels.
func choose(prompt: String, options: Array, speaker := "", icons := []) -> int:
	_cursor = 0
	_icons = icons
	_show(speaker, prompt, options)
	var confirmed: bool = await _next_input()
	var picked := _cursor if confirmed else -1
	_icons = []
	_show("", "", [])
	return picked


func close() -> void:
	queue_free()


func _show(speaker: String, text: String, options: Array, mood := "neutral") -> void:
	_name_label.text = speaker
	_name_label.visible = speaker != ""
	var face := Portraits.for_speaker(speaker, mood)
	_portrait.texture = face
	_portrait_frame.visible = face != null
	_text_label.custom_minimum_size.x = TEXT_WIDTH_PORTRAIT if face else TEXT_WIDTH
	_speaker = speaker
	_voice = Portraits.voice_pitch(speaker)
	_blipped = 0
	_text_label.text = text
	_options = PackedStringArray(options)
	_shown = 0.0 if Settings.chars_per_second() > 0.0 else float(text.length())
	_text_label.visible_characters = -1 if is_revealed() else 0
	_hint_time = 0.0
	_refresh_options()
	_refresh_hint()


## True once the whole page is showing.
func is_revealed() -> bool:
	return _shown >= _text_label.text.length()


## Shows the rest of the page at once.
func reveal_all() -> void:
	_shown = float(_text_label.text.length())
	_text_label.visible_characters = -1
	_refresh_hint()


func _process(delta: float) -> void:
	if not is_revealed():
		_shown += delta * Settings.chars_per_second()
		if is_revealed():
			reveal_all()
		else:
			_text_label.visible_characters = int(_shown)
			_blip()
	elif _options.is_empty() and _hint_label.text != "":
		# The next arrow bobs beside "Next", so the box reads as waiting for you.
		_hint_time += delta
		_position_arrow()


## A soft syllable in the speaker's voice as their words type out. Narration
## (no speaker) types out silently.
func _blip() -> void:
	var at := int(_shown)
	if _speaker == "" or at - _blipped < BLIP_EVERY or at >= _text_label.text.length():
		return
	_blipped = at
	var letter := _text_label.text[at]
	if letter == " " or letter == "." or letter == ",":
		return
	Sound.play("talk", 0.0, 0.06, _voice)


## Shows the bobbing arrow just left of the "Next" hint, and hides it otherwise.
func _position_arrow() -> void:
	var waiting := _options.is_empty() and is_revealed() and _hint_label.text.ends_with("Next")
	_arrow.visible = waiting
	if not waiting:
		return
	var hint := _hint_label.get_global_rect()
	var bob := roundf(sin(_hint_time * TAU * ARROW_SPEED) * ARROW_BOB)
	_arrow.position = Vector2(hint.end.x - _hint_text_width - _arrow.size.x - 4.0, hint.position.y + (hint.size.y - _arrow.size.y) / 2.0 + bob).round()


## "[E] Next", or the choice controls, in the current device's buttons.
func _refresh_hint() -> void:
	_hint_label.modulate.a = 1.0
	var tree := get_tree()
	if _text_label.text == "" and _options.is_empty():
		_hint_label.text = ""
	elif not _options.is_empty():
		_hint_label.text = "[%s] Choose   [%s] OK   [%s] Cancel" % [
			MenuInput.button(tree, "Up/Down", "D-pad"), MenuInput.button(tree, "E", "A"), MenuInput.button(tree, "Esc", "B")]
	elif not is_revealed():
		_hint_label.text = "[%s] Skip" % MenuInput.button(tree, "E", "A")
	else:
		_hint_label.text = "[%s] Next" % MenuInput.button(tree, "E", "A")
	var font := _hint_label.get_theme_font("font")
	_hint_text_width = font.get_string_size(_hint_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _hint_label.get_theme_font_size("font_size")).x
	_arrow.visible = false


func _refresh_options() -> void:
	for child in _options_box.get_children():
		_options_box.remove_child(child)
		child.queue_free()
	var pictures := _icons.any(func(icon: Variant) -> bool: return icon != null)
	for i in _options.size():
		var label := Label.new()
		label.text = CURSOR + _options[i]
		MenuInput.mark(label, i == _cursor)
		if i == _cursor:
			label.add_theme_color_override("font_color", NAME_COLOR)
			label.add_theme_stylebox_override("normal", _select_style)
		else:
			label.add_theme_stylebox_override("normal", _plain_style)
		if not pictures:
			_options_box.add_child(label)
			continue
		# a picture after the cursor; options without one keep the column
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		var picture := TextureRect.new()
		picture.custom_minimum_size = Vector2(16, 16)
		picture.texture = _icons[i] if i < _icons.size() else null
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var cursor := Control.new()
		cursor.custom_minimum_size = Vector2(8, 14)
		MenuInput.mark(cursor, i == _cursor)
		label.text = _options[i]
		MenuInput.mark(label, false) # the arrow goes in its own column here
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(cursor)
		row.add_child(picture)
		row.add_child(label)
		# the highlight runs under the whole row, picture and all
		label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		var holder := PanelContainer.new()
		holder.add_theme_stylebox_override("panel", _select_style if i == _cursor else _plain_style)
		holder.add_child(row)
		_options_box.add_child(holder)


## Waits for confirm (true) or cancel (false).
func _next_input() -> bool:
	_answer = 0
	while _answer == 0:
		await get_tree().process_frame
	return _answer == 1


func _input(event: InputEvent) -> void:
	# Ignore the key press that opened the box.
	if Engine.get_process_frames() == _opened_frame:
		return
	if MenuInput.confirm(event):
		get_viewport().set_input_as_handled()
		if not is_revealed():
			reveal_all() # the first press finishes the page
		else:
			_answer = 1
			Sound.play("ui_select", -3.0)
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_answer = -1
		Sound.play("ui_back")
	elif not _options.is_empty() and (MenuInput.pressed(event, "move_up") or MenuInput.pressed(event, "ui_up")):
		get_viewport().set_input_as_handled()
		_cursor = wrapi(_cursor - 1, 0, _options.size())
		_refresh_options()
		Sound.play("ui_move")
	elif not _options.is_empty() and (MenuInput.pressed(event, "move_down") or MenuInput.pressed(event, "ui_down")):
		get_viewport().set_input_as_handled()
		_cursor = wrapi(_cursor + 1, 0, _options.size())
		_refresh_options()
		Sound.play("ui_move")


## For tests: act as if the player pressed confirm (true) or cancel (false).
func press(confirm := true) -> void:
	reveal_all()
	_answer = 1 if confirm else -1
