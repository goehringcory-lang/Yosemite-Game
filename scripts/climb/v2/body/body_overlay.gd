class_name BodyOverlay
extends Control
## The body's HUD on the v2 climbing screen (thread 3): light marks on the
## rock, no meters. It reads the session and the aim phase and never changes
## them.
##   - a faint ring on every hold the next hand could use, with a tick for
##     the way it pulls; the aimed hold's ring is bright and coloured by the
##     move: calm (white), strained (amber), breaking (orange), can't (red);
##   - a small L or R by the hand that moves next;
##   - a word or two for the body position ("flag", "drop knee") beside the
##     aimed hold, or why it can't go;
##   - while the hips are shifted or the body button is held: the hips' path
##     from neutral and a plumb line from the centre of mass, solid when the
##     feet and hand hold it, broken when it would barn-door.
## Colours follow the shared strain tiers (BodyTuning.STRAIN_*), the same
## ones art trembles by, so the ring and the ghost agree.

const CALM := Color("eef4ff")
const STRAINED := Color("f2c46a")
const BREAKING := Color("f08a4b")
const CANT := Color("e0584a")
const FAINT := Color(1, 1, 1, 0.28)

var body: ClimbBody
var _t := 0.0
var _world: Node2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var n: Node = get_parent()
	while n and _world == null:
		var w: Variant = n.get("world") if "world" in n else null
		if w is Node2D:
			_world = w
		n = n.get_parent()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## A wall position on this overlay.
func to_overlay(wall_pos: Vector2) -> Vector2:
	var p := ClimberView.px(wall_pos)
	if _world:
		p = _world.get_transform() * p
	return p - global_position


func _zoom() -> float:
	return _world.scale.x if _world else 1.0


## The ring colour for a previewed move.
static func tone(move: V2Move) -> Color:
	if move == null or not move.valid:
		return CANT
	if move.strain >= BodyTuning.STRAIN_BREAKING:
		return BREAKING
	if move.strain >= BodyTuning.STRAIN_CALM or move.has_tag("barndoor"):
		return STRAINED
	return CALM


func _draw() -> void:
	if body == null or body.session == null or body.session.wall == null:
		return
	var s := body.session
	var phase := body.aim_phase()
	if phase == null or s.phase != &"climb" or phase.director == null:
		return
	var z := _zoom()
	var font := get_theme_default_font()
	# Every hold the next hand could use.
	for hid in phase.aim_set:
		if hid == phase.aimed:
			continue
		var h := s.wall.hold(hid)
		if h == null:
			continue
		var at := to_overlay(h.pos)
		draw_arc(at, 8.0 * z, 0.0, TAU, 20, FAINT, 1.0, true)
		_pull_tick(at, h, FAINT, z)
	# The aimed hold.
	var move := phase.move
	var aimed := s.wall.hold(phase.aimed)
	if aimed:
		var at := to_overlay(aimed.pos)
		var col := tone(move)
		var pulse := 1.0 + 0.08 * sin(_t * 4.0)
		draw_arc(at, 11.0 * z * pulse, 0.0, TAU, 28, col, 2.0, true)
		_pull_tick(at, aimed, col, z)
		var label := ""
		var sub := ""
		if move and not move.valid:
			label = "can't"
			sub = move.reason
			if phase.fix != "":
				sub += ": try " + phase.fix
		elif move:
			label = ", ".join(ClimbBody.technique_words(move).slice(0, 2))
		if label != "":
			_text(font, at + Vector2(16, -6) * z, label, col, 13)
		if sub != "":
			_text(font, at + Vector2(16, 9) * z, sub, Color(col, 0.85), 11)
	# The hand that moves next.
	var hand: V2Limb = s.pose.limb(s.pose.next_hand)
	var mark := to_overlay(hand.pos) + Vector2(-14 if s.pose.next_hand == &"lh" else 6, -14) * z
	draw_circle(mark + Vector2(4, -4), 7.0, Color(0.1, 0.12, 0.16, 0.7))
	_text(font, mark + Vector2(0, 0), "L" if s.pose.next_hand == &"lh" else "R", CALM, 11)
	# The hips and the plumb line.
	if phase.body_held or phase.hip_shift != Vector2.ZERO:
		var base := body.base_hip()
		var hip := base + phase.hip_shift
		draw_line(to_overlay(base), to_overlay(hip), Color(1, 1, 1, 0.5), 1.0, true)
		draw_circle(to_overlay(base), 2.5, Color(1, 1, 1, 0.5))
		draw_circle(to_overlay(hip), 4.0, tone(move))
		var lean := (aimed.pos.x - hip.x) * BodyTuning.REACH_LEAN if aimed else 0.0
		var com := hip + Vector2(lean, ClimbV2.TORSO_M * 0.3)
		var foot_y := hip.y - ClimbV2.LEG_M
		var barn := move != null and move.has_tag("barndoor")
		var a := to_overlay(com)
		var b := to_overlay(Vector2(com.x, foot_y))
		if barn:
			var n := 6
			for i in n:
				if i % 2 == 0:
					draw_line(a.lerp(b, float(i) / n), a.lerp(b, float(i + 1) / n), STRAINED, 1.0, true)
		else:
			draw_line(a, b, Color(1, 1, 1, 0.35), 1.0, true)


func _pull_tick(at: Vector2, h: V2Hold, col: Color, z: float) -> void:
	var p := h.pull.normalized() if h.pull.length() > 0.01 else Vector2.DOWN
	var d := Vector2(p.x, -p.y)
	draw_line(at + d * 4.0 * z, at + d * 9.0 * z, col, 1.5, true)


func _text(font: Font, at: Vector2, text: String, col: Color, size: int) -> void:
	if font == null:
		return
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color(0.08, 0.09, 0.12, 0.8))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
