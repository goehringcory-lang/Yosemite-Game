class_name ButtonHints
extends Label
## A hint line that draws each "[key]" in its text as a little pixel button,
## a keycap for the keyboard ("[E] OK", "[Up/Down] Choose") or the pad's own
## button ("[A] OK", "[LB/RB] Next tab", "[D-pad] Choose"), as cozy console
## games show their controls, instead of the name in brackets. Its text stays
## the plain string, so code and tests read it as before; only the drawing
## changes. Wraps like a Label when its autowrap is on.
##
## The same drawing is available to screens that draw their own HUD on a
## canvas (see [method draw_hint] and [method line_width]).

## Height of a button, in UI pixels.
const CAP_HEIGHT := 11
## Size of the name on a keycap.
const CAP_FONT_SIZE := 8
## Gap between a button and the word after it, and between two buttons
## of one hint ("[J/Esc]").
const CAP_GAP := 1.0
const PAIR_GAP := 1.0

const RIM := Color("2a1b14")
const KEY_TOP := Color("fbf3e2")
const KEY_FACE := Color("e9dcc0")
const KEY_LIP := Color("b89d72")
const PAD_FACE := Color("4d4652")
const PAD_TOP := Color("6d6573")
const PAD_LIP := Color("37313b")
const PAD_TEXT := Color("f5eee0")
const STICK_RING := Color("9a92a0")
const SHADOW := Color(0, 0, 0, 0.35)
## The pad's face buttons, in the colors most pads print on them.
const FACE_COLORS := {"A": Color("5c9a3c"), "B": Color("c0483a"), "X": Color("3f74b8"), "Y": Color("d8a63b")}
## Names drawn as one picture even though they hold a slash.
const WHOLE := ["Up/Down", "Left/Right", "D-pad L/R", "D-pad U/D"]

static var _pattern: RegEx


func _init() -> void:
	# Lay the text out (so the Label keeps its size and wrapping) but draw
	# none of it; _draw paints the words and buttons instead.
	visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	visible_characters = 0


var _measured := ""


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_READY:
		_fit_rows()
		_measured = ""


## Buttons can come out a pixel or two wider than the bracketed names the
## Label measures, so once the text changes the label widens to hold them,
## and a bubble or centered row sized to it still fits.
func _process(_delta: float) -> void:
	if text == _measured:
		return
	_measured = text
	var box := get_theme_stylebox("normal")
	var margins := box.get_margin(SIDE_LEFT) + box.get_margin(SIDE_RIGHT) if box else 0.0
	if autowrap_mode == TextServer.AUTOWRAP_OFF:
		custom_minimum_size.x = 0.0
		var label_width := get_minimum_size().x
		var needed := ceilf(content_width()) + margins
		if needed > label_width:
			custom_minimum_size.x = needed


## Makes each line at least a button tall, so buttons on a small font's
## lines don't run into the next line.
func _fit_rows() -> void:
	var font := get_theme_font("font")
	if font == null:
		return
	var height := font.get_height(get_theme_font_size("font_size"))
	custom_minimum_size.y = maxf(custom_minimum_size.y, CAP_HEIGHT + 1)
	if height < CAP_HEIGHT + 1 and not has_theme_constant_override("line_spacing"):
		add_theme_constant_override("line_spacing", int(ceilf(CAP_HEIGHT + 1 - height)))


func _draw() -> void:
	if text == "":
		return
	var font := get_theme_font("font")
	var font_size := get_theme_font_size("font_size")
	var color := get_theme_color("font_color")
	var outline := get_theme_constant("outline_size")
	var outline_color := get_theme_color("font_outline_color")
	var box := get_theme_stylebox("normal")
	var inner := Rect2(Vector2.ZERO, size)
	if box:
		inner = inner.grow_individual(-box.get_margin(SIDE_LEFT), -box.get_margin(SIDE_TOP), -box.get_margin(SIDE_RIGHT), -box.get_margin(SIDE_BOTTOM))
	var line_height := font.get_height(font_size) + get_theme_constant("line_spacing")
	var lines := layout(text, font, font_size, inner.size.x if autowrap_mode != TextServer.AUTOWRAP_OFF else INF)
	var pad := gamepad(get_tree())
	var total := line_height * lines.size()
	var y := inner.position.y
	match vertical_alignment:
		VERTICAL_ALIGNMENT_CENTER:
			y += floorf((inner.size.y - total) / 2.0)
		VERTICAL_ALIGNMENT_BOTTOM:
			y += inner.size.y - total
	for line: Array in lines:
		var width := _items_width(line, font, font_size)
		var x := inner.position.x
		match horizontal_alignment:
			HORIZONTAL_ALIGNMENT_CENTER:
				x += floorf((inner.size.x - width) / 2.0)
			HORIZONTAL_ALIGNMENT_RIGHT:
				x += inner.size.x - width
		_draw_items(self, line, font, font_size, Vector2(x, y), line_height, color, outline, outline_color, pad)
		y += line_height


## The width the hint takes on one line, drawn with its buttons.
func content_width() -> float:
	var font := get_theme_font("font")
	var font_size := get_theme_font_size("font_size")
	var widest := 0.0
	for line: Array in layout(text, font, font_size, INF):
		widest = maxf(widest, _items_width(line, font, font_size))
	return widest


## Draws [param hint] on [param ci] with its top left at [param at]: one line,
## for screens that draw their own HUD.
static func draw_hint(ci: CanvasItem, font: Font, font_size: int, hint: String, at: Vector2, color: Color, outline := 0, outline_color := Color.BLACK) -> void:
	var pad := gamepad(ci.get_tree() if ci.is_inside_tree() else null)
	for line: Array in layout(hint, font, font_size, INF):
		_draw_items(ci, line, font, font_size, at, font.get_height(font_size), color, outline, outline_color, pad)
		at.y += font.get_height(font_size)


## The width [param hint] takes on one line, with its buttons drawn.
static func line_width(font: Font, font_size: int, hint: String) -> float:
	var widest := 0.0
	for line: Array in layout(hint, font, font_size, INF):
		widest = maxf(widest, _items_width(line, font, font_size))
	return widest


## Splits [param hint] into lines of items: a word (with the spaces after
## it) is a String, a button is a Dictionary {"key": name}. Breaks lines at
## "\n" and, when a line would pass [param width], between items.
static func layout(hint: String, font: Font, font_size: int, width: float) -> Array:
	if _pattern == null:
		_pattern = RegEx.create_from_string("\\[([^\\]]+)\\]")
	var lines: Array = []
	for source in hint.split("\n"):
		var items: Array = []
		var at := 0
		for found in _pattern.search_all(source):
			_add_words(items, source.substr(at, found.get_start() - at))
			items.append({"key": found.get_string(1)})
			at = found.get_end()
		_add_words(items, source.substr(at))
		var line: Array = []
		var used := 0.0
		for item in items:
			var w := _item_width(item, font, font_size)
			if not line.is_empty() and used + w > width + 0.5:
				lines.append(line)
				line = []
				used = 0.0
				if item is String and item.strip_edges() == "":
					continue
			line.append(item)
			used += w
		lines.append(line)
	return lines


static func _add_words(items: Array, run: String) -> void:
	var word := ""
	for i in run.length():
		var ch := run[i]
		if ch != " " and word.ends_with(" "):
			items.append(word)
			word = ""
		word += ch
	if word != "":
		items.append(word)


static func _items_width(line: Array, font: Font, font_size: int) -> float:
	var width := 0.0
	for item in line:
		width += _item_width(item, font, font_size)
	# a line's trailing spaces don't count toward where it sits
	if not line.is_empty() and line[-1] is String:
		var last: String = line[-1]
		width -= font.get_string_size(last, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x - font.get_string_size(last.strip_edges(false, true), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return width


static func _item_width(item: Variant, font: Font, font_size: int) -> float:
	if item is String:
		return font.get_string_size(item, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return key_width(item.key, font) + CAP_GAP


static func _draw_items(ci: CanvasItem, line: Array, font: Font, font_size: int, at: Vector2, line_height: float, color: Color, outline: int, outline_color: Color, pad: bool) -> void:
	var x := at.x
	var ascent := font.get_ascent(font_size)
	var baseline := at.y + roundf((line_height - font.get_height(font_size)) / 2.0) + ascent
	for item in line:
		if item is String:
			if outline > 0:
				ci.draw_string_outline(font, Vector2(x, baseline), item, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, outline_color)
			ci.draw_string(font, Vector2(x, baseline), item, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
			x += font.get_string_size(item, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		else:
			var top := roundf(at.y + (line_height - CAP_HEIGHT) / 2.0)
			x += draw_key(ci, font, item.key, Vector2(roundf(x), top), pad) + CAP_GAP


# ---------------------------------------------------------------- the buttons


## True when hints name the pad's buttons, so "B" is the red face button
## rather than the B key.
static func gamepad(tree: SceneTree) -> bool:
	return MenuInput.button(tree, "k", "g") == "g"


## The parts one hint names: "J/Esc" is two keys, "Up/Down" is one picture.
static func _parts(key: String) -> PackedStringArray:
	if key in WHOLE:
		return PackedStringArray([key])
	return key.split("/")


## Width of the button(s) for [param key], in UI pixels.
static func key_width(key: String, font: Font) -> float:
	var width := 0.0
	var parts := _parts(key)
	for part in parts:
		width += _part_width(part, font)
	return width + PAIR_GAP * (parts.size() - 1)


static func _part_width(part: String, font: Font) -> float:
	match part:
		"Up/Down", "Left/Right":
			return 2.0 * 9.0 + PAIR_GAP
		"Arrows":
			return 15.0
		"D-pad", "D-pad L/R", "D-pad U/D", "Stick", "L stick", "R stick":
			return 11.0
	if part in FACE_COLORS:
		return 11.0
	return maxf(9.0, ceilf(font.get_string_size(part, HORIZONTAL_ALIGNMENT_LEFT, -1, CAP_FONT_SIZE).x) + 6.0)


## Draws the button(s) for [param key] with their top left at [param at];
## returns the width used.
static func draw_key(ci: CanvasItem, font: Font, key: String, at: Vector2, pad := false) -> float:
	var x := at.x
	var parts := _parts(key)
	for i in parts.size():
		var part := parts[i]
		var w := _part_width(part, font)
		var spot := Vector2(x, at.y)
		match part:
			"Up/Down":
				_keycap(ci, Rect2(spot, Vector2(9, CAP_HEIGHT)))
				_arrow(ci, spot + Vector2(2, 3), Vector2i.UP)
				_keycap(ci, Rect2(spot + Vector2(10, 0), Vector2(9, CAP_HEIGHT)))
				_arrow(ci, spot + Vector2(12, 3), Vector2i.DOWN)
			"Left/Right":
				_keycap(ci, Rect2(spot, Vector2(9, CAP_HEIGHT)))
				_arrow(ci, spot + Vector2(3, 2), Vector2i.LEFT)
				_keycap(ci, Rect2(spot + Vector2(10, 0), Vector2(9, CAP_HEIGHT)))
				_arrow(ci, spot + Vector2(13, 2), Vector2i.RIGHT)
			"Arrows":
				_keycap(ci, Rect2(spot, Vector2(w, CAP_HEIGHT)))
				_arrow(ci, spot + Vector2(2, 2), Vector2i.LEFT)
				_dot_arrows(ci, spot + Vector2(5, 1))
				_arrow(ci, spot + Vector2(11, 2), Vector2i.RIGHT)
			"A", "B", "X", "Y" when pad:
				_face_button(ci, spot, FACE_COLORS[part], part, font)
			"D-pad", "D-pad L/R", "D-pad U/D":
				_dpad(ci, spot, part)
			"Stick", "L stick", "R stick":
				_stick(ci, spot)
			"LB", "RB", "LT", "RT", "Back", "Start", "Menu", "View", "Select":
				_pill(ci, Rect2(spot, Vector2(w, CAP_HEIGHT)), part, font)
			_:
				_keycap(ci, Rect2(spot, Vector2(w, CAP_HEIGHT)))
				_cap_text(ci, font, part, Rect2(spot, Vector2(w, CAP_HEIGHT - 2)), RIM)
		x += w + PAIR_GAP
	return x - PAIR_GAP - at.x


## A keyboard key: a dark rim with its corners cut, a light top edge, the
## cream face and a darker lip under it, with a soft shadow below.
static func _keycap(ci: CanvasItem, r: Rect2) -> void:
	var p := r.position
	var w := r.size.x
	var h := r.size.y
	ci.draw_rect(Rect2(p + Vector2(1, h - 1), Vector2(w - 1, 1)), SHADOW)
	ci.draw_rect(Rect2(p + Vector2(1, 0), Vector2(w - 2, h - 1)), RIM)
	ci.draw_rect(Rect2(p + Vector2(0, 1), Vector2(w, h - 3)), RIM)
	ci.draw_rect(Rect2(p + Vector2(1, 1), Vector2(w - 2, h - 4)), KEY_FACE)
	ci.draw_rect(Rect2(p + Vector2(1, 1), Vector2(w - 2, 1)), KEY_TOP)
	ci.draw_rect(Rect2(p + Vector2(1, h - 4), Vector2(w - 2, 2)), KEY_LIP)


## A shoulder button or a small center button: a dark rounded pill.
static func _pill(ci: CanvasItem, r: Rect2, label: String, font: Font) -> void:
	var p := r.position
	var w := r.size.x
	var h := r.size.y
	ci.draw_rect(Rect2(p + Vector2(1, h - 1), Vector2(w - 1, 1)), SHADOW)
	ci.draw_rect(Rect2(p + Vector2(2, 0), Vector2(w - 4, h - 1)), RIM)
	ci.draw_rect(Rect2(p + Vector2(0, 2), Vector2(w, h - 5)), RIM)
	ci.draw_rect(Rect2(p + Vector2(1, 1), Vector2(w - 2, h - 3)), RIM)
	ci.draw_rect(Rect2(p + Vector2(2, 1), Vector2(w - 4, h - 3)), PAD_FACE)
	ci.draw_rect(Rect2(p + Vector2(1, 2), Vector2(w - 2, h - 5)), PAD_FACE)
	ci.draw_rect(Rect2(p + Vector2(2, 1), Vector2(w - 4, 1)), PAD_TOP)
	ci.draw_rect(Rect2(p + Vector2(2, h - 3), Vector2(w - 4, 1)), PAD_LIP)
	_cap_text(ci, font, label, Rect2(p, Vector2(w, h - 1)), PAD_TEXT)


## Half-widths of each row of an 11 px disc.
const DISC := [2, 3, 4, 5, 5, 5, 5, 5, 4, 3, 2]


static func _disc(ci: CanvasItem, at: Vector2, rim: Color, fill: Color, lip: Color) -> void:
	var c := at.x + 5.0
	for y in DISC.size():
		var hw: int = DISC[y]
		ci.draw_rect(Rect2(c - hw, at.y + y, hw * 2 + 1, 1), rim)
	for y in range(1, DISC.size() - 1):
		var hw: int = DISC[y] - 1
		ci.draw_rect(Rect2(c - hw, at.y + y, hw * 2 + 1, 1), lip if y >= 8 else fill)


## A face button: a colored disc with its letter.
static func _face_button(ci: CanvasItem, at: Vector2, color: Color, letter: String, font: Font) -> void:
	ci.draw_rect(Rect2(at + Vector2(3, 11), Vector2(5, 1)), SHADOW)
	_disc(ci, at, RIM, color, color.darkened(0.3))
	ci.draw_rect(Rect2(at + Vector2(3, 2), Vector2(2, 1)), color.lightened(0.35))
	_cap_text(ci, font, letter, Rect2(at, Vector2(11, 10)), PAD_TEXT)


## The thumbstick: a grey disc with a darker dip in it.
static func _stick(ci: CanvasItem, at: Vector2) -> void:
	_disc(ci, at, RIM, STICK_RING, PAD_TOP)
	ci.draw_rect(Rect2(at + Vector2(3, 4), Vector2(5, 3)), PAD_FACE)
	ci.draw_rect(Rect2(at + Vector2(4, 3), Vector2(3, 5)), PAD_FACE)
	ci.draw_rect(Rect2(at + Vector2(4, 4), Vector2(3, 1)), PAD_LIP)


## The D-pad: a dark cross, with the arms in use lit.
static func _dpad(ci: CanvasItem, at: Vector2, part: String) -> void:
	ci.draw_rect(Rect2(at + Vector2(3, 0), Vector2(5, 11)), RIM)
	ci.draw_rect(Rect2(at + Vector2(0, 3), Vector2(11, 5)), RIM)
	ci.draw_rect(Rect2(at + Vector2(4, 1), Vector2(3, 9)), PAD_TOP)
	ci.draw_rect(Rect2(at + Vector2(1, 4), Vector2(9, 3)), PAD_TOP)
	ci.draw_rect(Rect2(at + Vector2(4, 4), Vector2(3, 3)), PAD_FACE)
	var lit := PAD_TEXT
	if part != "D-pad L/R":
		ci.draw_rect(Rect2(at + Vector2(4, 1), Vector2(3, 2)), lit)
		ci.draw_rect(Rect2(at + Vector2(4, 8), Vector2(3, 2)), lit)
	if part != "D-pad U/D":
		ci.draw_rect(Rect2(at + Vector2(1, 4), Vector2(2, 3)), lit)
		ci.draw_rect(Rect2(at + Vector2(8, 4), Vector2(2, 3)), lit)


## A small solid arrow, 5x3 (up and down) or 3x5 (left and right), with its
## top left at [param at].
static func _arrow(ci: CanvasItem, at: Vector2, dir: Vector2i) -> void:
	for i in 3:
		match dir:
			Vector2i.UP:
				ci.draw_rect(Rect2(at + Vector2(2 - i, i), Vector2(1 + 2 * i, 1)), RIM)
			Vector2i.DOWN:
				ci.draw_rect(Rect2(at + Vector2(i, i), Vector2(5 - 2 * i, 1)), RIM)
			Vector2i.LEFT:
				ci.draw_rect(Rect2(at + Vector2(i, 2 - i), Vector2(1, 1 + 2 * i)), RIM)
			Vector2i.RIGHT:
				ci.draw_rect(Rect2(at + Vector2(i, i), Vector2(1, 5 - 2 * i)), RIM)


## Up and down arrows stacked, 5 wide, between the left and right ones.
static func _dot_arrows(ci: CanvasItem, at: Vector2) -> void:
	ci.draw_rect(Rect2(at + Vector2(2, 0), Vector2(1, 1)), RIM)
	ci.draw_rect(Rect2(at + Vector2(1, 1), Vector2(3, 1)), RIM)
	ci.draw_rect(Rect2(at + Vector2(1, 5), Vector2(3, 1)), RIM)
	ci.draw_rect(Rect2(at + Vector2(2, 6), Vector2(1, 1)), RIM)


static func _cap_text(ci: CanvasItem, font: Font, label: String, r: Rect2, color: Color) -> void:
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, CAP_FONT_SIZE).x
	var x := roundf(r.position.x + (r.size.x - w) / 2.0)
	var y := roundf(r.position.y + (r.size.y - font.get_height(CAP_FONT_SIZE)) / 2.0) + font.get_ascent(CAP_FONT_SIZE)
	ci.draw_string(font, Vector2(x, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, CAP_FONT_SIZE, color)
