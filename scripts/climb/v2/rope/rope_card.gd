class_name RopeCard
extends Control
## The rope's HUD card (thread 5), bottom right of the climbing screen. While
## climbing: a small strip with the drag and how far you'd fall right now.
## While clipping: the piece, the pulls (pips), the gate against the line
## above, draw or sling, the pump the pulls will cost, and warnings. Reads
## the session; never changes it.

const W := 270.0
const INK := Color("f2e6c8")
const DIM := Color(0.95, 0.9, 0.78, 0.55)
const PANEL := Color(0.07, 0.09, 0.12, 0.82)
const EDGE := Color(0.95, 0.9, 0.78, 0.18)
const WARN := Color("ff8a5c")
const GOOD := Color("9fd88a")
const ROPE := Color("e8b04a")

var rope: ClimbRope


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var parent_size := get_parent_area_size() if get_parent() is Control else Vector2(960, 540)
	size = parent_size


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if rope == null or rope.session == null or rope.session.wall == null:
		return
	var s := rope.session
	if s.phase == &"clip" and s.rope.pulling_for != "":
		_draw_clip(s)
	elif s.phase == &"climb":
		_draw_strip(s)


func _font() -> Font:
	return ThemeDB.fallback_font


func _text(at: Vector2, text: String, color := INK, font_size := 13) -> void:
	draw_string(_font(), at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _panel(rect: Rect2) -> void:
	draw_rect(rect, PANEL)
	draw_rect(rect, EDGE, false, 1.0)


func _name(p: V2Piece) -> String:
	match p.kind:
		&"bolt":
			return "Bolt"
		&"pin":
			return "Old pin"
		&"anchor":
			return "Anchor"
	var item := rope.session.rack.item(p.gear_id)
	return str(item.get("name", p.gear_id.capitalize()))


func _drag_bar(at: Vector2, drag: float) -> void:
	for i in 5:
		var on := drag > (i + 0.5) / 5.0
		var c := WARN if on and i >= 3 else (ROPE if on else EDGE)
		draw_rect(Rect2(at + Vector2(i * 9, 0), Vector2(7, 8)), c)


func _draw_strip(s: ClimbSession) -> void:
	var rect := Rect2(size.x - W - 12, size.y - 62, W, 50)
	_panel(rect)
	var o := rect.position + Vector2(10, 18)
	_text(o, "Rope", DIM, 12)
	_text(o + Vector2(40, 0), "%d clipped" % rope.chain().size(), INK, 12)
	_text(o + Vector2(130, 0), "drag", DIM, 12)
	_drag_bar(o + Vector2(164, -8), s.rope.drag)
	var f := rope.fall_preview()
	var by := s.piece(f.caught_by)
	var line := "Fall now: %.1f m" % f.drop_m
	line += " onto %s" % _name(by).to_lower() if by else " onto the belay"
	var warn: bool = not (f.rolls as PackedStringArray).is_empty()
	_text(o + Vector2(0, 20), line + ("  (rope rolls out of one!)" if warn else ""), WARN if warn else INK, 12)


func _draw_clip(s: ClimbSession) -> void:
	var h := rope.hang()
	var p := s.piece(h.get("piece", ""))
	if p == null:
		return
	var rect := Rect2(size.x - W - 12, size.y - 150, W, 138)
	_panel(rect)
	var o := rect.position + Vector2(10, 20)
	var what := "Re-clipping" if h.fixing else "Clipping"
	var on := "long sling" if h.long else ("quickdraw" if p.fixed else "its own sling")
	_text(o, "%s %s" % [what, _name(p).to_lower()], INK, 14)
	_text(o + Vector2(0, 17), "on a " + on, DIM, 12)
	# Pulls: one pip per arm-length, filled as you pull.
	var need := rope.arms_needed(s.rope.pulling_for)
	_text(o + Vector2(0, 40), "Pulls", DIM, 12)
	for i in need:
		var c := Vector2(o.x + 52 + i * 18, o.y + 36)
		if i < s.rope.arms_pulled:
			draw_circle(c, 5.5, ROPE)
		else:
			draw_arc(c, 5.5, 0, TAU, 16, ROPE, 1.5)
	# The gate against the line above.
	var gx := o.x + 150
	_text(Vector2(gx, o.y + 40), "Gate", DIM, 12)
	_arrow(Vector2(gx + 50, o.y + 36), int(h.gate), INK)
	var line := rope.line_dir(p)
	_text(o + Vector2(0, 62), "Line", DIM, 12)
	if line == 0:
		_text(o + Vector2(52, 62), "straight up", INK, 12)
	else:
		_arrow(Vector2(o.x + 62, o.y + 58), line, DIM)
	# Pump the pulls will cost.
	var fc := rope.pump_forecast()
	var red := fc[1] >= 1.0
	_text(Vector2(gx, o.y + 62), "Pump", DIM, 12)
	_text(Vector2(gx + 40, o.y + 62), "%d→%d" % [roundi(fc[0] * 100), roundi(minf(fc[1], 1.0) * 100)], WARN if red else INK, 12)
	var note := ""
	var color := GOOD
	if rope.too_high():
		note = "Out of reach on a short draw"
		color = WARN
	elif red:
		note = "You'll pump out before it's clipped"
		color = WARN
	elif rope.warns_back_clip():
		note = "Gate faces your line: back-clipped"
		color = WARN
	elif rope.cross_body():
		note = "Cross-body clip: costs more pump"
		color = ROPE
	else:
		note = "Clean clip"
	_text(o + Vector2(0, 86), note, color, 13)
	var f := rope.fall_preview()
	_text(o + Vector2(0, 106), "Blow it now: %.1f m fall" % f.drop_m, DIM, 12)


func _arrow(at: Vector2, dir: int, color: Color) -> void:
	var d := float(dir)
	draw_line(at - Vector2(9 * d, 0), at + Vector2(9 * d, 0), color, 2.0)
	draw_line(at + Vector2(9 * d, 0), at + Vector2(4 * d, -4), color, 2.0)
	draw_line(at + Vector2(9 * d, 0), at + Vector2(4 * d, 4), color, 2.0)
