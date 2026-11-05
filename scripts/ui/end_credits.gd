class_name EndCredits
extends CanvasLayer
## The credits roll at the end of the story, after the looking-glass in the
## Guardian's cave (GuardianMirror). The screen fades to the title painting,
## dimmed, with the title music, and the credits drift up over it: the game's
## name, everyone in the Register, the people of the valley the story made up,
## then who made the game and the data, font and engine it uses (Credits),
## and "Thank you for playing." Then it fades back to the cave, where the
## Guardian's Year begins.
## Hold E (A) to roll faster; Esc (B) skips to the end.
## The credits on the title screen (Credits) carry the same lines and the
## license texts; this roll is for the moment the story ends.

signal finished

const SCREEN := Vector2(480, 270)
const HEADING := Color(1, 0.831, 0.541)
const TEXT := Color(0.961, 0.933, 0.878)
const DIM := Color(0.961, 0.933, 0.878, 0.55)
const INK := Color(0.165, 0.106, 0.078)
## Pixels a second the roll climbs, and how many times faster while E is held.
const SPEED := 16.0
const FAST := 5.0
const FADE_IN := 1.2
const FADE_OUT := 1.0
## Seconds the last line holds in the middle of the screen before the fade.
const HOLD_END := 3.0
const LAST_LINE := "Thank you for playing."

var _shade: ColorRect
var _picture: TextureRect
var _roll: VBoxContainer
var _last: Label
var _footer: Label
var _scroll := 0.0
## Where the roll stops: the last line in the middle of the screen.
var _end := INF
var _hold := HOLD_END
var _done := false
var _was_paused := false
var _was_ambience := ""


## Starts the roll over the running game and returns it; await its
## finished signal.
static func roll(tree: SceneTree) -> EndCredits:
	var credits := EndCredits.new()
	tree.root.add_child(credits)
	return credits


func _ready() -> void:
	layer = 40
	UiScale.layer(self)
	add_to_group("end_credits")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_was_paused = GameClock.paused
	GameClock.paused = true
	_was_ambience = Sound.ambience()
	Sound.set_ambience("title")
	_shade = ColorRect.new()
	_shade.color = Color(0, 0, 0, 0)
	_shade.size = SCREEN
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_picture = TextureRect.new()
	_picture.texture = load(TitleScreen.BACKGROUND)
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_SCALE
	_picture.size = SCREEN
	_picture.modulate = Color(0.32, 0.3, 0.36, 0.0)
	add_child(_picture)
	_roll = VBoxContainer.new()
	_roll.add_theme_constant_override("separation", 1)
	_roll.custom_minimum_size.x = SCREEN.x
	_roll.position = Vector2(0, SCREEN.y)
	add_child(_roll)
	_build_roll()
	_footer = ButtonHints.new()
	_footer.add_theme_color_override("font_color", DIM)
	_footer.position = Vector2(8, SCREEN.y - 16)
	_footer.text = footer_text(get_tree())
	_footer.modulate.a = 0.0
	add_child(_footer)
	var fade := create_tween().set_parallel(true)
	fade.tween_property(_shade, "color:a", 1.0, FADE_IN * 0.5)
	fade.tween_property(_picture, "modulate:a", 1.0, FADE_IN).set_delay(FADE_IN * 0.5)
	fade.tween_property(_footer, "modulate:a", 1.0, FADE_IN).set_delay(FADE_IN)
	_measure.call_deferred()


## The names in the roll's Register section: everyone in the Register whose
## part isn't waiting on tribal review, in the Register's order.
static func register_names() -> PackedStringArray:
	var names := PackedStringArray()
	for character: CharacterData in QuestLog.CHARACTERS:
		if not character.needs_tribal_review and character.display_name != "":
			names.append(character.display_name)
	return names


## The people the story made up (the climbers, rangers and naturalists
## working in the valley now).
static func staff_names() -> PackedStringArray:
	var names := PackedStringArray()
	for character: CharacterData in QuestLog.STAFF:
		if character.display_name != "":
			names.append(character.display_name)
	return names


## Every line of the roll, as [kind, text]: "title", "heading", "line", "gap".
static func lines() -> Array:
	var out: Array = []
	out.append(["title", ProjectSettings.get_setting("application/config/name")])
	out.append(["line", "The Guardian's Register"])
	out.append(["gap", ""])
	out.append(["heading", "In the Register"])
	for name in register_names():
		out.append(["line", name])
	out.append(["gap", ""])
	out.append(["heading", "And in the valley today"])
	for name in staff_names():
		out.append(["line", name])
	for entry: Array in Credits.CREDITS:
		var heading: String = entry[0]
		if heading == "":
			continue # the tagline and the thank-you; the roll has its own
		out.append(["gap", ""])
		out.append(["heading", heading])
		for line: String in entry[1]:
			out.append(["line", line])
	out.append(["gap", ""])
	out.append(["gap", ""])
	out.append(["last", LAST_LINE])
	return out


func _build_roll() -> void:
	for entry: Array in lines():
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.custom_minimum_size.x = SCREEN.x
		label.add_theme_color_override("font_outline_color", INK)
		label.add_theme_constant_override("outline_size", 2)
		match entry[0]:
			"title":
				label.add_theme_font_size_override("font_size", 30)
				label.add_theme_color_override("font_color", HEADING)
				label.add_theme_constant_override("outline_size", 6)
			"heading":
				label.add_theme_color_override("font_color", HEADING)
			"gap":
				label.custom_minimum_size.y = 12
			"last":
				label.add_theme_font_size_override("font_size", 16)
				label.add_theme_color_override("font_color", HEADING)
				_last = label
			_:
				label.add_theme_color_override("font_color", TEXT)
		label.text = entry[1]
		_roll.add_child(label)


## Once the roll has its size: where to stop so the last line sits mid-screen.
func _measure() -> void:
	_roll.reset_size()
	_end = _last.position.y + _last.size.y / 2.0 + SCREEN.y / 2.0


func is_rolling() -> bool:
	return not _done


## How far the roll has climbed, in pixels.
func scrolled() -> float:
	return _scroll


func _process(delta: float) -> void:
	if _done:
		return
	if _scroll < _end:
		var speed := SPEED * (FAST if Input.is_action_pressed("interact") or Input.is_action_pressed("ui_accept") else 1.0)
		_scroll = minf(_scroll + speed * delta, _end)
	else:
		_hold -= delta
		if _hold <= 0.0:
			skip()
			return
	_roll.position.y = roundf(SCREEN.y - _scroll)


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	get_viewport().set_input_as_handled() # the game waits under the roll
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		skip()


## Ends the roll: fades back to the game, then emits finished and goes.
func skip() -> void:
	if _done:
		return
	_done = true
	var fade := create_tween().set_parallel(true)
	for node: CanvasItem in [_roll, _picture, _footer]:
		fade.tween_property(node, "modulate:a", 0.0, FADE_OUT * 0.5)
	fade.chain().tween_property(_shade, "color:a", 0.0, FADE_OUT * 0.5)
	await fade.finished
	GameClock.paused = _was_paused
	Sound.set_ambience(_was_ambience)
	finished.emit()
	queue_free()


static func footer_text(tree: SceneTree) -> String:
	return "[%s] Faster   [%s] Skip" % [MenuInput.button(tree, "E", "A"), MenuInput.button(tree, "Esc", "B")]
