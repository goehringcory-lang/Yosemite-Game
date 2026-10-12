class_name ItemToasts
extends Control
## The little cards at the bottom left that say what you just got: the item's
## picture, its name, and how many. A second pickup of the same thing while
## its card is up adds to the count and bumps the card instead of stacking a
## new one. HUD makes one and feeds it from Inventory.added and Gear.added.

## Seconds a card stays before it fades.
const HOLD := 3.0
const FADE := 0.4
## Most cards at once; the oldest goes when another comes.
const MAX_CARDS := 4
const CARD_HEIGHT := 20.0
const GAP := 2.0
## Pixels the card slides in from the left.
const SLIDE := 24.0
const NAME_COLOR := Color(1.0, 0.92, 0.72)
const COUNT_COLOR := Color(1.0, 0.85, 0.5)

## Each entry: {"key", "card", "count", "label", "time"}.
var _cards: Array[Dictionary] = []
## Pixels from the bottom of the screen to the lowest card. HUD raises it
## while a conversation box covers the bottom of the screen.
var bottom_margin := 44.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## Shows (or adds to) the card for [param key].
func notify(key: String, icon: Texture2D, display_name: String, amount: int) -> void:
	if amount <= 0:
		return
	for entry in _cards:
		if entry.key == key and entry.time < HOLD:
			entry.count += amount
			entry.time = 0.0
			_set_text(entry, display_name)
			_bump(entry.card)
			return
	if _cards.size() >= MAX_CARDS:
		var oldest: Dictionary = _cards.pop_front()
		oldest.card.queue_free()
	var entry := {"key": key, "count": amount, "time": 0.0}
	entry.card = _make_card(icon, entry)
	_set_text(entry, display_name)
	add_child(entry.card)
	_cards.append(entry)
	_layout()


## Number of cards showing (for tests).
func count() -> int:
	return _cards.size()


## The text on the card for [param key], or "" (for tests).
func text_for(key: String) -> String:
	for entry in _cards:
		if entry.key == key:
			return entry.label.text
	return ""


func _make_card(icon: Texture2D, entry: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The theme's frame, a little slimmer so the cards don't crowd the screen.
	var style := card.get_theme_stylebox("panel").duplicate() as StyleBox
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	style.content_margin_right = 5.0
	card.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	card.add_child(row)
	var picture := TextureRect.new()
	picture.texture = icon
	picture.custom_minimum_size = Vector2(16, 16)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(picture)
	var label := Label.new()
	label.add_theme_color_override("font_color", NAME_COLOR)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	entry.label = label
	card.modulate.a = 0.0
	return card


func _set_text(entry: Dictionary, display_name: String) -> void:
	entry.label.text = display_name if entry.count == 1 else "%s  x%d" % [display_name, entry.count]


## A quick pop when a card's count goes up.
func _bump(card: Control) -> void:
	card.pivot_offset = card.size / 2.0
	var tween := card.create_tween()
	tween.tween_property(card, "scale", Vector2(1.12, 1.12), 0.06)
	tween.tween_property(card, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	var gone := false
	for entry in _cards:
		entry.time += delta
		var card: Control = entry.card
		var t: float = entry.time
		if t < 0.15:
			card.modulate.a = t / 0.15
		elif t < HOLD:
			card.modulate.a = 1.0
		else:
			card.modulate.a = maxf(0.0, 1.0 - (t - HOLD) / FADE)
			gone = gone or t >= HOLD + FADE
	if gone:
		for entry in _cards.filter(func(e: Dictionary) -> bool: return e.time >= HOLD + FADE):
			entry.card.queue_free()
			_cards.erase(entry)
	_layout()
	_slide(delta)


## Newest card at the bottom, older ones stacked above.
func _layout() -> void:
	var bottom := get_viewport_rect().size.y - bottom_margin
	for i in range(_cards.size() - 1, -1, -1):
		var card: Control = _cards[i].card
		var y := bottom - CARD_HEIGHT - (_cards.size() - 1 - i) * (CARD_HEIGHT + GAP)
		card.set_meta("target_y", y)
		if not card.has_meta("placed"):
			card.set_meta("placed", true)
			card.position = Vector2(4.0 - SLIDE, y)


## Eases each card toward its slot, sliding new ones in from the left.
func _slide(delta: float) -> void:
	var k := 1.0 - exp(-delta * 14.0)
	for entry in _cards:
		var card: Control = entry.card
		var target := Vector2(4.0, card.get_meta("target_y", card.position.y))
		card.position = card.position.lerp(target, k)
		card.size = card.get_combined_minimum_size()
