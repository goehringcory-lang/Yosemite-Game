class_name CruxOverlay
extends Control
## Thread 8's overlay on the v2 climbing screen. It only reads the session
## and listens to the bus. It draws, on the rock where they are:
##   - the tells on the ghost that say a crux move is wrong before you
##     commit: hips swinging out (a barn-door), a foot skating on a smear,
##     crossed wrists, a dyno's jump line (pose tells, not meters);
##   - a small card with a crux's name (and its beta, if a mentor taught you
##     to read it), and what you learned from the last crux move;
##   - the specials: the swing's rope, arc and the ghost of the next peak and
##     the kick-off spots; the pin scars, pins and the pin you're driving; the
##     haul line, bag and lips; the chimney or offwidth walls and your locks.

const INK := Color("f2e6c8")
const SHADOW := Color(0, 0, 0, 0.55)
const GHOST := Color(0.95, 0.92, 0.8, 0.55)
const WARN := Color("e8a050")
const SAY_SECONDS := 4.5

var session: ClimbSession
var _move: V2Move
var _said := ""
var _said_t := 0.0
var _world: Node2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if get_parent():
		size = get_parent().size
	if session:
		session.bus.move_previewed.connect(func(m: V2Move) -> void: _move = m)
		session.bus.move_committed.connect(func(_m: V2Move) -> void: _move = null)
		session.bus.phase_changed.connect(func(_a: StringName, _b: StringName) -> void: _move = null)


func _process(delta: float) -> void:
	if session == null:
		return
	var n: Dictionary = session.notes.get(&"cruxes", {})
	var said := str(n.get("said", ""))
	var sp: Dictionary = n.get("special", {})
	if not sp.is_empty():
		said = str(sp.get("say", ""))
	if said != _said:
		_said = said
		_said_t = SAY_SECONDS if said != "" else 0.0
	_said_t = maxf(0.0, _said_t - delta)
	queue_redraw()


## Wall metres to this overlay's pixels, through the screen's camera.
func at(pos: Vector2) -> Vector2:
	if _world == null:
		var p := get_parent()
		while p and not ("world" in p):
			p = p.get_parent()
		if p:
			_world = p.get("world")
	var local := ClimberView.px(pos)
	return _world.get_transform() * local if _world else size * 0.5 + local - ClimberView.px(session.pose.hip)


func metres() -> float:
	return ClimbV2.PX_PER_M * (_world.scale.x if _world else 1.0)


func _draw() -> void:
	if session == null or session.wall == null:
		return
	var n: Dictionary = session.notes.get(&"cruxes", {})
	var sp: Dictionary = n.get("special", {})
	if not sp.is_empty() and session.phase == &"special":
		_draw_special(sp)
	elif session.phase == &"climb":
		_draw_tells()
		_draw_card(n)
	if _said_t > 0.0 and _said != "":
		var a := clampf(_said_t, 0.0, 1.0)
		_text(Vector2(size.x * 0.5, 64), _said, Color(INK, a), 15, true)


func _text(pos: Vector2, s: String, col: Color, fsize := 13, centre := false) -> void:
	var font := get_theme_default_font()
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	var p := pos - Vector2(w * 0.5 if centre else 0.0, 0)
	draw_string(font, p + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(SHADOW, col.a * SHADOW.a))
	draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


# ------------------------------------------------------------ crux moves

func _draw_card(n: Dictionary) -> void:
	var hip := session.pose.hip
	for s: Dictionary in n.get("spots", []):
		if str(s.kind) in CruxReader.SPECIALS or n.has("sent:" + str(s.id)):
			continue
		var r := CruxReader.rect_of(s)
		if hip.y < r.position.y - 2.5 or hip.y > r.end.y:
			continue
		_text(Vector2(size.x * 0.5, 30), str(s.name), INK, 16, true)
		if str(s.get("beta", "")) != "" and (session.mods.knows("beta") or session.mods.knows("route:" + session.route_id)):
			_text(Vector2(size.x * 0.5, 46), str(s.beta), Color(INK, 0.8), 12, true)
		return


## True once the real climber art (thread 9) is in: it acts the tells out
## on the ghost itself, so these marks would double up.
func _art_shows_tells() -> bool:
	var p := get_parent()
	while p and not ("climber" in p):
		p = p.get_parent()
	var c: Object = p.get("climber") if p else null
	var script: Script = c.get_script() if c else null
	return script != null and not script.resource_path.contains("/stubs/")


## The tells on the ghost for a crux move that's off: drawn at the ghost's
## hips, feet and hands, so you see it before you commit.
func _draw_tells() -> void:
	var m := _move
	if m == null or m.crux_id == "" or m.to == null or _art_shows_tells():
		return
	var hip := at(m.to.hip)
	var u := metres()
	for tag in m.tags:
		if tag.begins_with("crux_miss:hip_x"):
			# Barn-door: the hips swing out and away.
			var dir := -1.0 if tag.ends_with("x1") else 1.0
			draw_arc(hip + Vector2(dir * 0.1 * u, 0), 0.32 * u, PI * 0.5 - dir * 0.2, PI * 0.5 + dir * 1.1, 10, Color(WARN, 0.7), 2.0)
		elif tag == "crux_miss:hip_y-1":
			draw_line(hip + Vector2(-0.15 * u, -0.1 * u), hip + Vector2(0.15 * u, -0.1 * u), Color(WARN, 0.6), 2.0)
		elif tag == "crux_miss:hip_y1":
			draw_line(hip + Vector2(-0.15 * u, 0.12 * u), hip + Vector2(0.15 * u, 0.12 * u), Color(WARN, 0.6), 2.0)
		elif tag.begins_with("crux_miss:foot"):
			for f: StringName in [&"lf", &"rf"]:
				var l: V2Limb = m.to.limb(f)
				if l.kind != &"hold":
					var p := at(l.pos)
					for i in 3:
						draw_line(p + Vector2(-5 + i * 5, 2), p + Vector2(-8 + i * 5, 9), Color(WARN, 0.7), 1.5)
		elif tag.begins_with("crux_miss:hand"):
			var l: V2Limb = m.to.limb(m.hand)
			var p := at(l.pos)
			draw_line(p + Vector2(-5, -5), p + Vector2(5, 5), Color(WARN, 0.8), 2.0)
			draw_line(p + Vector2(-5, 5), p + Vector2(5, -5), Color(WARN, 0.8), 2.0)
	if m.has_tag("dyno"):
		var h := session.wall.hold(m.hold_id)
		if h:
			var a := at(m.from.limb(m.hand).pos if m.from else m.to.hip)
			var b := at(h.pos)
			var mid := (a + b) * 0.5 + Vector2(0, -0.4 * u)
			var prev := a
			for i in range(1, 11):
				var t := i / 10.0
				var q := a.lerp(mid, t).lerp(mid.lerp(b, t), t)
				if i % 2 == 0:
					draw_line(prev, q, GHOST, 1.5)
				prev = q


# ---------------------------------------------------------------- specials

func _special(sp: Dictionary) -> CruxSpecial:
	var sys := session.sys.cruxes as CruxesV2
	return sys.make_special(StringName(str(sp.kind)), sp.spot, sp.state) if sys else null


func _draw_special(sp: Dictionary) -> void:
	var special := _special(sp)
	if special == null:
		return
	var opts := special.options()
	var chosen: Dictionary = opts[clampi(int(sp.get("sel", 0)), 0, opts.size() - 1)] if not opts.is_empty() else {}
	var p := special.preview(chosen)
	match special.kind:
		&"swing":
			_draw_swing(special as SwingSpecial, chosen, p)
		&"nail":
			_draw_nail(special as NailSpecial, chosen)
		&"haul":
			_draw_haul(special as HaulSpecial)
		&"chimney", &"offwidth":
			_draw_worm(special as InchwormSpecial, chosen)
	_text(Vector2(size.x * 0.5, 30), special.title(), INK, 16, true)


func _draw_swing(s: SwingSpecial, chosen: Dictionary, p: Dictionary) -> void:
	var st := s.state
	var pivot := V2Data.vec(st.pivot)
	var u := metres()
	draw_circle(at(pivot), 3.0, Color("bdb8ae"))
	for k: Dictionary in st.spots:
		var kp := at(V2Data.vec(k.pos))
		match str(k.footing):
			"wet":
				draw_line(kp + Vector2(0, -10), kp + Vector2(0, 12), Color(0.15, 0.2, 0.25, 0.7), 5.0)
			"polished":
				draw_line(kp + Vector2(-6, -3), kp + Vector2(6, 3), Color(1, 1, 1, 0.45), 2.0)
			"dirty":
				draw_circle(kp, 4.0, Color(0.35, 0.3, 0.2, 0.6))
			_:
				draw_line(kp + Vector2(-6, 0), kp + Vector2(6, 0), Color(0.95, 0.9, 0.8, 0.7), 2.0)
		if chosen.get("spot", "") == k.id:
			draw_arc(kp, 8.0, 0, TAU, 16, GHOST, 1.5)
	var target := Vector2(pivot.x + float(st.side) * float(st.d), float(V2Data.vec(st.target).y))
	draw_arc(at(target), 0.25 * u, 0, TAU, 16, Color(0.9, 0.8, 0.5, 0.35), 1.5)
	if st.stage == "lower":
		if p.has("land"):
			var land := V2Data.vec(p.land)
			_dashed(at(pivot), at(land), GHOST)
			draw_circle(at(land), 4.0, GHOST)
		return
	# The rope to you, the arc you swing on, and the ghost of the next peak.
	draw_line(at(pivot), at(session.pose.hip + Vector2(0, 0.1)), Color("c8382e"), 2.0)
	var r := float(st.rope) * u
	var c := at(pivot)
	draw_arc(c, r, PI * 0.5 - 1.1, PI * 0.5 + 1.1, 32, Color(1, 1, 1, 0.12), 1.0)
	if p.has("pos"):
		var g := at(V2Data.vec(p.pos))
		_dashed(c, g, GHOST)
		draw_circle(g, 6.0, Color(GHOST, 0.35))
		draw_arc(g, 6.0, 0, TAU, 16, GHOST, 1.5)


func _draw_nail(s: NailSpecial, chosen: Dictionary) -> void:
	var st := s.state
	var u := metres()
	for i in (st.scars as Array).size():
		var sc: Dictionary = st.scars[i]
		var p := at(V2Data.vec(sc.pos))
		# A scar's gap shows its width; its length, how deep it goes.
		var w := clampf(1.5 + (float(sc.width) + 3.0) * 0.9, 1.0, 6.0)
		var len := 0.12 * u + 0.1 * u * float(sc.depth)
		draw_line(p + Vector2(0, -len * 0.5), p + Vector2(0, len * 0.5), Color(0.1, 0.08, 0.07, 0.9), w)
		if i == int(st.scar):
			draw_arc(p, len * 0.7, 0, TAU, 20, Color(GHOST, 0.4), 1.0)
	for pl: Dictionary in st.placed:
		_pin(at(V2Data.vec(pl.pos)), 1.0, Color("bdb8ae"))
	var pin: Dictionary = st.pin
	if not pin.is_empty() and int(st.scar) < (st.scars as Array).size():
		_pin(at(V2Data.vec(s.scar().pos)), float(pin.depth), Color("d8d4ca"))
	elif str(chosen.get("id", "")) == "pin" and int(st.scar) < (st.scars as Array).size():
		_pin(at(V2Data.vec(s.scar().pos)), 0.0, GHOST)


func _pin(p: Vector2, depth: float, col: Color) -> void:
	var out := (1.0 - depth) * 10.0 + 3.0
	draw_line(p, p + Vector2(out, 0), col, 2.0)
	draw_arc(p + Vector2(out + 3, 0), 3.0, 0, TAU, 10, col, 1.5)


func _draw_haul(s: HaulSpecial) -> void:
	var st := s.state
	var w := session.wall
	var u := metres()
	var anchor := at(w.top + Vector2(0, 0.2))
	var bag := at(Vector2(w.top.x + 0.3, w.start.y + float(st.bag)))
	for l: Dictionary in st.lips:
		var ly := at(Vector2(w.top.x, w.start.y + float(l.y)))
		var half := (0.3 + 0.35 * float(l.size)) * u
		draw_line(ly + Vector2(-half, 0), ly + Vector2(half, 0), Color(0.85, 0.8, 0.7, 0.8), 3.0 if float(l.size) < 2.0 else 6.0)
	draw_line(anchor, bag, Color("e8c050"), 1.5)
	draw_rect(Rect2(bag - Vector2(0.14, 0.0) * u, Vector2(0.28, 0.45) * u), Color("6a4a2a"))
	draw_rect(Rect2(bag - Vector2(0.14, 0.0) * u, Vector2(0.28, 0.45) * u), Color(0, 0, 0, 0.6), false, 1.0)
	if bool(st.stuck):
		draw_arc(bag + Vector2(0, 0.22 * u), 0.35 * u, 0, TAU, 20, Color(WARN, 0.6), 1.5)


func _draw_worm(s: InchwormSpecial, chosen: Dictionary) -> void:
	var st := s.state
	var u := metres()
	var x := float(st.x)
	var y := float(st.bottom) - 0.5
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	while y <= float(st.top) + 0.8:
		var half := clampf(s.width_at(y) * 0.045, 0.12, 0.7)
		left.append(at(Vector2(x - half, y)))
		right.append(at(Vector2(x + half, y)))
		y += 0.1
	draw_polyline(left, Color(0.12, 0.1, 0.09, 0.9), 3.0)
	draw_polyline(right, Color(0.12, 0.1, 0.09, 0.9), 3.0)
	for half_name: String in ["upper", "lower"]:
		var hy := float(st[half_name])
		draw_circle(at(Vector2(x, hy)), 4.0, Color("e8c050") if half_name == st.moving else Color("bdb8ae"))
	if str(chosen.get("id", "")) == "shuffle":
		draw_arc(at(Vector2(x, float(chosen.y))), 0.18 * u, 0, TAU, 16, GHOST, 1.5)


func _dashed(a: Vector2, b: Vector2, col: Color) -> void:
	var n := maxi(2, int(a.distance_to(b) / 8.0))
	for i in n:
		if i % 2 == 0:
			draw_line(a.lerp(b, float(i) / n), a.lerp(b, float(i + 1) / n), col, 1.5)
