class_name FallsOverlay
extends Control
## The partner on screen (thread 7): their words in a speech pill at the
## bottom left, a short tag after a fall (how far, what popped, what caught
## you), and the belay card at the anchor (each piece cleaned and the
## partner's word for it). Never a quality bar: grades are the partner's
## verdict after the fact. Reads the session and listens to the bus; it
## never changes anything.

const TEXT := Color("f2e6c8")
const NAME := Color("f0c060")
const DIM := Color("b8ab90")
## Grade word -> colour on the belay card.
const GRADE_COLORS := {
	"bomber": Color("9ad28a"), "held": Color("9ad28a"), "good": Color("cfe0a0"),
	"walked": Color("e8c070"), "tipped": Color("e8a060"), "marginal": Color("e89060"),
	"prayer": Color("e07060"), "popped": Color("e07060"), "stuck": Color("90b8e0"),
}
const GRADE_WORDS := {
	"bomber": "bomber", "held": "held a fall", "good": "good", "walked": "walked",
	"tipped": "tipped out", "marginal": "marginal", "prayer": "a prayer",
	"popped": "popped", "stuck": "stuck",
}
## Seconds a line stays up: a floor plus a little per character.
const LINE_MIN := 2.4
const LINE_PER_CHAR := 0.045
const QUEUE_MAX := 5
## The widest a line gets before it wraps, pixels.
const LINE_WIDTH := 340.0

var session: ClimbSession
## Lines waiting to be said (the first is showing).
var queue: Array[String] = []

var _bubble := PanelContainer.new()
var _who := Label.new()
var _line := Label.new()
var _tag := PanelContainer.new()
var _tag_label := Label.new()
var _card := PanelContainer.new()
var _card_rows := VBoxContainer.new()
var _card_title := Label.new()
var _card_foot := Label.new()
var _line_left := 0.0
var _tag_left := 0.0


func bind(p_session: ClimbSession) -> void:
	session = p_session
	var bus := session.bus
	bus.partner_said.connect(_on_partner_said)
	bus.fall_started.connect(_on_fall_started)
	bus.fall_caught.connect(_on_fall_caught)
	bus.phase_changed.connect(_on_phase_changed)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var size_now := get_viewport().get_visible_rect().size if get_viewport() else Vector2(960, 540)
	size = size_now
	# The speech pill.
	_bubble.add_theme_stylebox_override("panel", MenuInput.nine_slice("res://assets/ui/prompt_pill.png", 4.0, 10.0, 6.0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_who.add_theme_color_override("font_color", NAME)
	_line.add_theme_color_override("font_color", TEXT)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size = Vector2(LINE_WIDTH, 0)
	row.add_child(_who)
	row.add_child(_line)
	_bubble.add_child(row)
	_bubble.position = Vector2(12, size_now.y - 92)
	_bubble.modulate.a = 0.0
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bubble)
	# The fall tag, top middle.
	_tag.add_theme_stylebox_override("panel", MenuInput.nine_slice("res://assets/ui/tag.png", 4.0, 10.0, 4.0))
	_tag_label.add_theme_color_override("font_color", TEXT)
	_tag.add_child(_tag_label)
	_tag.modulate.a = 0.0
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tag)
	# The belay card, right side.
	_card.add_theme_stylebox_override("panel", MenuInput.nine_slice("res://assets/ui/card.png", 5.0, 14.0, 10.0))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	_card_title.add_theme_color_override("font_color", NAME)
	_card_foot.add_theme_color_override("font_color", DIM)
	col.add_child(_card_title)
	col.add_child(_card_rows)
	col.add_child(_card_foot)
	_card.add_child(col)
	_card.custom_minimum_size = Vector2(240, 0)
	_card.visible = false
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)


func _process(delta: float) -> void:
	# Presentation only: fades and line timing.
	if not queue.is_empty():
		_line_left -= delta
		_bubble.modulate.a = minf(1.0, _bubble.modulate.a + delta * 6.0)
		if _line_left <= 0.0:
			queue.pop_front()
			_show_next()
	else:
		_bubble.modulate.a = maxf(0.0, _bubble.modulate.a - delta * 3.0)
	if _tag_left > 0.0:
		_tag_left -= delta
		_tag.modulate.a = minf(1.0, _tag.modulate.a + delta * 6.0)
	else:
		_tag.modulate.a = maxf(0.0, _tag.modulate.a - delta * 2.0)


## The name shown on the pill.
func partner_label() -> String:
	var who := str(session.note(&"falls").get("partner", "")) if session else ""
	return who if who != "" else "Partner"


func _on_partner_said(line: String) -> void:
	if line == "":
		return
	if queue.size() >= QUEUE_MAX:
		queue.remove_at(1)
	queue.append(line)
	if queue.size() == 1:
		_show_next()


func _show_next() -> void:
	if queue.is_empty():
		return
	_who.text = partner_label()
	_line.text = queue[0]
	var font := _line.get_theme_font("font")
	var font_size := _line.get_theme_font_size("font_size")
	_line.custom_minimum_size.x = minf(LINE_WIDTH, font.get_string_size(queue[0], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 2.0) if font else LINE_WIDTH
	_line_left = LINE_MIN + LINE_PER_CHAR * queue[0].length()
	_bubble.reset_size()


## "Fell 4.2 m · #1 popped · caught by a bolt".
static func fall_text(f: Dictionary, names := {}) -> String:
	var parts: Array[String] = ["Fell %.1f m" % float(f.get("drop_m", 0.0))]
	for piece_id: String in f.get("popped", []):
		var nm: String = names.get(piece_id, "a piece")
		parts.append(("%s unclipped" if (f.get("unclipped", []) as Array).has(piece_id) else "%s popped") % nm)
	match str(f.get("lands_on", "")):
		"ledge":
			parts.append("hit a ledge")
		"ground":
			parts.append("on the ground")
		_:
			var kind := str(f.get("caught_kind", "belay"))
			parts.append("caught on the belay" if kind == "belay" else "caught by the %s" % kind)
	return "  ·  ".join(parts)


## A fall cuts off whatever the partner was saying: the catch comes first.
func _on_fall_started(_fall: V2Fall) -> void:
	queue.clear()
	_bubble.modulate.a = 0.0


func _on_fall_caught(_fall: V2Fall) -> void:
	var f: Dictionary = session.note(&"falls").get("last_fall", {})
	var names := {}
	for piece_id: String in f.get("popped", []):
		names[piece_id] = session.sys.falls.piece_name(session.piece(piece_id)) if session.sys.falls is ClimbFalls else piece_id
	_tag_label.text = fall_text(f, names)
	_tag.reset_size()
	_tag.position = Vector2((size.x - _tag.size.x) * 0.5, 14)
	_tag_left = 3.5


func _on_phase_changed(_from: StringName, to: StringName) -> void:
	if to == &"belay":
		# The belay phase cleans after this event goes out: fill next frame.
		# Its lines come next, so older chatter makes way.
		queue.clear()
		_card.visible = true
		_fill_card.call_deferred()
	else:
		_card.visible = false


func _fill_card() -> void:
	for c in _card_rows.get_children():
		c.queue_free()
	var report: Array = session.note(&"falls").get("report", [])
	_card_title.text = "Pitch %d cleaned" % (session.pitch + 1)
	var minutes := 0
	if report.is_empty():
		var none := Label.new()
		none.text = "Nothing to clean: all fixed gear."
		none.add_theme_color_override("font_color", DIM)
		_card_rows.add_child(none)
	for r: Dictionary in report:
		minutes += int(r.get("minutes", 0))
		var row := HBoxContainer.new()
		var nm := Label.new()
		nm.text = str(r.get("name", "?"))
		nm.add_theme_color_override("font_color", TEXT)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var grade := Label.new()
		var g := str(r.get("grade", ""))
		grade.text = GRADE_WORDS.get(g, g)
		grade.add_theme_color_override("font_color", GRADE_COLORS.get(g, TEXT))
		row.add_child(nm)
		row.add_child(grade)
		_card_rows.add_child(row)
	_card_foot.text = "%d min to follow and clean" % minutes if minutes > 0 else "Rest up, eat, then climb on"
	_card.reset_size()
	_card.position = Vector2(size.x - _card.size.x - 16, 70)
