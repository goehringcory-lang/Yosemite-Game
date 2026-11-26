class_name ClimbRope
extends RopeSystem
## Rope and clipping (thread 5 of climbing v2). Owns session.rope, each
## piece's clipped / back_clipped / sling_m, and the "clip" phase. Numbers
## are in rope_tuning.gd. Analytic, no physics and no random draws.
##
## How a clip works:
##   - R near a bolt or a placed piece hangs a draw on it (or uses the piece's
##     own sling). The card shows the pulls it takes, the gate, the line above,
##     the pump it will cost and how far you'd fall right now.
##   - Left/Right turns the gate. It starts facing away from the hand you clip
##     with; turning it the other way is a cross-body clip (more pump). Up/Down
##     picks a short draw or a long sling (less drag, longer fall, reaches a
##     higher bolt).
##   - R or Space pulls up an arm-length of rope; the last pull is the clip.
##     The pulls needed come from the geometry: the rope the new path needs,
##     less slack already out, over what one pull fetches (less with drag).
##     Clipping overhead takes up to 3 pulls; rope past that is extra pump.
##   - Pump out mid-pull and you come off holding the slack. Esc drops the
##     rope and the belayer takes the slack back in.
##   - A gate facing your line is a back-clip: fall while above it and off to
##     the gate side and the rope rolls out of it (it doesn't catch). R near a
##     back-clipped piece re-clips it.
##   - Drag comes from the bends the rope makes through each carabiner (long
##     slings let it run straight), plus carabiners and rope weight.
##
## Rope listens to its own bus for moves, the hip button and falls to keep
## its slack and drag current; it changes only rope-owned fields there.

const T := preload("res://scripts/climb/v2/rope/rope_tuning.gd")

var _clip_phase: ClipPhase


func id() -> StringName:
	return &"rope"


func attach(p_session: ClimbSession) -> void:
	super(p_session)
	var bus := session.bus
	bus.move_committed.connect(_on_moved.unbind(1))
	bus.hip_changed.connect(_on_moved.unbind(1))
	bus.fall_started.connect(_on_fall_started)
	bus.fall_caught.connect(_on_fall_caught)


func _n() -> Dictionary:
	return session.note(id())


# ------------------------------------------------------------------ geometry

## Where the rope starts: the lower belay.
func belay() -> Vector2:
	return session.wall.start if session.wall else Vector2.ZERO


## Clipped pieces still on the rope, in the order the rope runs through them.
func chain() -> Array[V2Piece]:
	var out: Array[V2Piece] = []
	for piece_id in session.rope.clipped:
		var p := session.piece(piece_id)
		if p and not p.popped:
			out.append(p)
	return out


## The rope's path from the belay through every clipped carabiner to the
## tie-in (query). A carabiner on a sling swings up to its sling length
## toward the straight line between its neighbours: that's why you extend.
func path_points(to: Vector2 = Vector2.INF) -> PackedVector2Array:
	if to == Vector2.INF:
		to = session.pose.tie_in()
	var pieces := chain()
	var raw := PackedVector2Array([belay()])
	for p in pieces:
		raw.append(p.pos)
	raw.append(to)
	var out := PackedVector2Array([raw[0]])
	for i in range(1, raw.size() - 1):
		out.append(_biner(raw[i], raw[i - 1], raw[i + 1], pieces[i - 1].sling_m))
	out.append(raw[raw.size() - 1])
	return out


func _biner(at: Vector2, prev: Vector2, next: Vector2, sling: float) -> Vector2:
	var c := Geometry2D.get_closest_point_to_segment(at, prev, next)
	var d := c - at
	return at + d.limit_length(sling) if d.length() > 0.01 else at


## Rope in the system from the belay to the tie-in along the path (query).
func rope_used(points := PackedVector2Array()) -> float:
	if points.is_empty():
		points = path_points()
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	return total


## Rope drag for [param points] (default: the rope as it runs now), 0..1.
func drag_for(points := PackedVector2Array()) -> float:
	if points.is_empty():
		points = path_points()
	var bend := 0.0
	var tie := points[points.size() - 1]
	for i in range(1, points.size() - 1):
		var a := points[i] - points[i - 1]
		var b := points[i + 1] - points[i]
		if a.length() < 0.01 or b.length() < 0.01:
			continue
		var theta := absf(a.angle_to(b))
		# Climbing below your top piece doesn't drag like a zig-zag does.
		if i == points.size() - 2 and tie.y < points[i].y:
			theta = minf(theta, PI * 0.5)
		if rad_to_deg(theta) >= T.DRAG_MIN_BEND_DEG:
			bend += theta
	var biners := points.size() - 2
	var k := T.DRAG_MU * bend + T.DRAG_PER_BINER * biners + T.DRAG_PER_M * rope_used(points)
	return clampf(1.0 - exp(-k), 0.0, 1.0)


## How sharply the rope bends through [param piece_id], radians (query).
## Falls can use it: a sharp bend lifts an unextended nut or cam out.
func bend_at(piece_id: String) -> float:
	var points := path_points()
	var pieces := chain()
	for i in pieces.size():
		if pieces[i].id == piece_id:
			var a := points[i + 1] - points[i]
			var b := points[i + 2] - points[i + 1]
			return absf(a.angle_to(b)) if a.length() > 0.01 and b.length() > 0.01 else 0.0
	return 0.0


## Rope one arm-length pull fetches with the drag there is now.
func fetch_m() -> float:
	return ClimbV2.ARM_PULL_M * (1.0 - T.DRAG_FETCH_LOSS * session.rope.drag)


## Which way the route goes above [param p]: -1 left, 1 right, 0 straight
## up (query). The next bolt above, else the top.
func line_dir(p: V2Piece) -> int:
	var target := session.wall.top if session.wall else p.pos + Vector2(0, 5)
	var best := INF
	for q in session.all_pieces():
		if q != p and q.fixed and q.pos.y > p.pos.y + 0.5 and q.pos.y - p.pos.y < best:
			best = q.pos.y - p.pos.y
			target = q.pos
	var dx := target.x - p.pos.x
	var dy := maxf(target.y - p.pos.y, 0.1)
	if absf(dx) < T.LINE_DEADBAND * dy and absf(dx) < T.LINE_MAX_DX:
		return 0
	return 1 if dx > 0.0 else -1


## Which way [param piece_id]'s gate faces: -1 left, 1 right (0 unknown).
func gate_of(piece_id: String) -> int:
	return int((_n().get("gates", {}) as Dictionary).get(piece_id, 0))


# ------------------------------------------------------------------ clipping

func clippable() -> Array[V2Piece]:
	var tie := session.pose.tie_in()
	var floor_y := -INF
	var top := chain()
	if not top.is_empty():
		floor_y = top[top.size() - 1].pos.y - 0.2
	var extend := T.LONG_M - T.DRAW_M if session.rack.count("sling") > 0 else 0.0
	var fresh: Array[V2Piece] = []
	var fixes: Array[V2Piece] = []
	for p in session.all_pieces():
		if p.popped:
			continue
		var reach := T.REACH_M + extend
		if p.clipped:
			if p.back_clipped and p.pos.distance_to(tie) <= T.REACH_M + p.sling_m:
				fixes.append(p)
		elif p.pos.y >= floor_y and (p.pos - Vector2(0, T.DRAW_M)).distance_to(tie) <= reach:
			fresh.append(p)
	var nearest := func(a: V2Piece, b: V2Piece) -> bool: return a.pos.distance_to(tie) < b.pos.distance_to(tie)
	fresh.sort_custom(nearest)
	fixes.sort_custom(nearest)
	return fresh + fixes


## The clip in progress ({} when none): piece, item, long, gate, hand, need,
## overflow, slack0, fixing.
func hang() -> Dictionary:
	return _n().get("hang", {})


func _sling_m(p: V2Piece, long: bool) -> float:
	if long:
		return T.LONG_M
	return T.DRAW_M if p.fixed else T.OWN_SLING_M


## Pulls for a clip of [param p] on a sling of [param sling] (query):
## {need, overflow, extra_m}.
func pull_plan(p: V2Piece, sling: float) -> Dictionary:
	var tie := session.pose.tie_in()
	var top := chain()
	var last := belay() if top.is_empty() else top[top.size() - 1].pos
	var biner := p.pos - Vector2(0, sling * 0.5)
	var extra := last.distance_to(biner) + biner.distance_to(tie) - last.distance_to(tie)
	var short := maxf(0.0, extra - session.rope.slack_m)
	var raw := short / fetch_m()
	return {"need": clampi(ceili(raw - T.PULL_SLOP), 1, T.MAX_PULLS),
		"overflow": maxf(0.0, raw - T.MAX_PULLS), "extra_m": extra}


func arms_needed(piece_id: String) -> int:
	var h := hang()
	if h.get("piece", "") == piece_id:
		return int(h.need)
	var p := session.piece(piece_id)
	if p == null:
		return 1
	return int(pull_plan(p, _sling_m(p, false)).need)


## True while the carabiner (on the chosen sling) hangs out of reach (query).
func too_high() -> bool:
	var h := hang()
	var p := session.piece(h.get("piece", ""))
	if p == null:
		return false
	return (p.pos - Vector2(0, _sling_m(p, h.long))).distance_to(session.pose.tie_in()) > T.REACH_M + 0.001


func start_clip(piece_id: String) -> bool:
	var p := session.piece(piece_id)
	if p == null or p.popped or session.rope.pulling_for != "":
		return false
	var fixing := p.clipped
	if fixing and not p.back_clipped:
		return false
	var item := ""
	var long := false
	if not fixing:
		var short_reach := (p.pos - Vector2(0, T.DRAW_M)).distance_to(session.pose.tie_in()) <= T.REACH_M
		if p.fixed:
			if (short_reach or session.rack.count("sling") == 0) and session.rack.count("quickdraw") > 0:
				item = "quickdraw"
			elif session.rack.count("sling") > 0:
				item = "sling"
			else:
				return false
		elif not short_reach and session.rack.count("sling") > 0:
			item = "sling"
		if item != "" and not session.rack.take(item):
			return false
		long = item == "sling"
	var hand := session.sys.body.free_hand()
	var h := {"piece": piece_id, "item": item, "long": long, "hand": String(hand),
		"gate": -gate_of(piece_id) if fixing else _natural_gate(hand), "slack0": session.rope.slack_m, "fixing": fixing}
	_n()["hang"] = h
	_replan()
	session.rope.pulling_for = piece_id
	session.rope.arms_pulled = 0
	return true


## The gate faces away from the hand that clips (the natural way to hang it).
func _natural_gate(hand: StringName) -> int:
	return 1 if hand == &"lh" else -1


func _replan() -> void:
	var h := hang()
	var p := session.piece(h.piece)
	var plan := pull_plan(p, _sling_m(p, h.long))
	h.need = 1 if h.fixing else plan.need
	h.overflow = 0.0 if h.fixing else plan.overflow


## Turns the gate to face [param side] (-1 left, 1 right).
func set_gate(side: int) -> void:
	var h := hang()
	if not h.is_empty() and side != 0:
		h.gate = signi(side)


## True if the gate faces the clipping hand: a cross-body clip (query).
func cross_body() -> bool:
	var h := hang()
	return not h.is_empty() and int(h.gate) != _natural_gate(StringName(h.hand))


## True if the gate faces the way the route goes above (query).
func warns_back_clip() -> bool:
	var h := hang()
	var p := session.piece(h.get("piece", ""))
	if p == null:
		return false
	var line := line_dir(p)
	return line != 0 and int(h.gate) == line


## Switches between a short draw (or the piece's own sling) and a long
## sling. False if the rack has none to give.
func set_long(long: bool) -> bool:
	var h := hang()
	if h.is_empty() or h.fixing or bool(h.long) == long:
		return false
	var p := session.piece(h.piece)
	if long:
		if not session.rack.take("sling"):
			return false
		if h.item == "quickdraw":
			session.rack.give_back("quickdraw")
		h.item = "sling"
	else:
		if p.fixed:
			if not session.rack.take("quickdraw"):
				return false
			h.item = "quickdraw"
		else:
			h.item = ""
		session.rack.give_back("sling")
	h.long = long
	_replan()
	return true


## What the next pull costs (query): rope_pull, plus clip on the last one.
## Effort gets the stance: arms, drag, cross_body, overhead_frac, hand_hold
## (the hold the other hand hangs from) and overflow (rope past 3 pulls).
func pull_cost(arm: int) -> V2Cost:
	var h := hang()
	var p := session.piece(h.get("piece", ""))
	var tie := session.pose.tie_in()
	var data := {"arms": arm, "drag": session.rope.drag, "cross_body": cross_body(),
		"overhead_frac": clampf((p.pos.y - tie.y) / 1.2, 0.0, 1.0) if p else 0.0,
		"hand_hold": _holding_hold(), "overflow": 0.0}
	var last := arm >= int(h.get("need", 1))
	if last:
		data.overflow = float(h.get("overflow", 0.0))
	var c := session.sys.effort.price_action(&"rope_pull", data)
	if last:
		c = c.plus(session.sys.effort.price_action(&"clip", data))
	return c


## The hold the hand that isn't clipping hangs from, or "".
func _holding_hold() -> String:
	var h := hang()
	var hand: StringName = &"rh" if h.get("hand", "lh") == "lh" else &"lh"
	var l: V2Limb = session.pose.limb(hand)
	return l.id if l and l.kind == &"hold" else ""


## Pump before and after every pull still to come (query): [now, after].
func pump_forecast() -> Array[float]:
	var now := session.effort.pump
	var after := now
	var h := hang()
	for arm in range(session.rope.arms_pulled + 1, int(h.get("need", 1)) + 1):
		after += pull_cost(arm).pump
	return [now, after]


func pull() -> bool:
	var r := session.rope
	if r.pulling_for == "":
		return false
	var needed := arms_needed(r.pulling_for)
	if r.arms_pulled < needed:
		r.arms_pulled += 1
		r.slack_m += fetch_m()
		session.bus.send(&"rope_pulled", [r.arms_pulled, needed])
	return r.arms_pulled >= needed


func clip() -> bool:
	var r := session.rope
	var h := hang()
	var p := session.piece(r.pulling_for)
	if p == null or h.is_empty() or r.arms_pulled < arms_needed(r.pulling_for):
		return false
	var gates: Dictionary = _n().get("gates", {})
	gates[p.id] = int(h.gate)
	_n()["gates"] = gates
	var back := warns_back_clip()
	if not h.fixing:
		var extra: float = pull_plan(p, _sling_m(p, h.long)).extra_m
		p.sling_m = _sling_m(p, h.long)
		p.clipped = true
		r.clipped.append(p.id)
		r.slack_m = maxf(0.0, r.slack_m - extra)
	else:
		r.slack_m = float(h.slack0)
	p.back_clipped = back
	r.pulling_for = ""
	r.arms_pulled = 0
	_n().erase("hang")
	_update()
	session.bus.send(&"clipped", [p.id, back])
	return true


func cancel_clip() -> void:
	var r := session.rope
	var h := hang()
	if h.get("item", "") != "":
		session.rack.give_back(h.item)
	r.pulling_for = ""
	r.arms_pulled = 0
	_n().erase("hang")


## Lets go of the rope you pulled: the belayer takes the slack back in.
func bail() -> void:
	var s0 := float(hang().get("slack0", session.rope.slack_m))
	cancel_clip()
	session.rope.slack_m = s0


## Clips the first bolt from the ground (a stick-clip): story routes start
## that way, the honest reason they have no ground falls.
func pitch_started() -> void:
	if session.pitch != 0 or not session.mods.story or session.wall == null:
		return
	var low: V2Piece = null
	for p in session.wall.fixed:
		if p.kind == &"bolt" and p.pos.y <= T.STICK_CLIP_MAX_Y and (low == null or p.pos.y < low.pos.y):
			low = p
	if low == null or not session.rack.take("quickdraw"):
		return
	var gate := -line_dir(low)
	var gates: Dictionary = _n().get("gates", {})
	gates[low.id] = gate if gate != 0 else 1
	_n()["gates"] = gates
	low.clipped = true
	low.sling_m = T.DRAW_M
	session.rope.clipped.append(low.id)
	_update()
	session.bus.send(&"clipped", [low.id, false])


# ------------------------------------------------------------------ falls

## Pieces the rope would roll out of in a fall from [param from_pos] (query):
## gate facing the climber, who is above it and off to that side. Never the
## last piece left on a story route.
func rolled_out(from_pos: Vector2) -> PackedStringArray:
	var out := PackedStringArray()
	var pieces := chain()
	pieces.reverse()
	for p in pieces:
		if out.size() >= T.MAX_ROLLS:
			break
		var gate := gate_of(p.id)
		if gate == 0 or p.kind == &"anchor" or from_pos.y <= p.pos.y:
			continue
		if (from_pos.x - p.pos.x) * gate > T.ROLL_SIDE_M:
			if session.mods.story and pieces.size() - out.size() <= 1:
				break
			out.append(p.id)
	return out


func fall_geometry(from_pos: Vector2) -> V2Fall:
	var f := V2Fall.new()
	f.from_pos = from_pos
	f.slack_m = session.rope.slack_m
	var rolled := rolled_out(from_pos)
	var holding: Array[V2Piece] = []
	for p in chain():
		if not p.id in rolled:
			holding.append(p)
	holding.sort_custom(func(a: V2Piece, b: V2Piece) -> bool: return a.pos.y - a.sling_m > b.pos.y - b.sling_m)
	for p in holding:
		f.chain.append(p.id)
	f.length_m = drop_to(from_pos, f.chain[0] if not f.chain.is_empty() else "")
	return f


## Twice the height above the loaded carabiner (a sling hangs it lower), plus
## slack, plus stretch: rope out * (base + fall factor), softened less when
## drag binds the rope, plus the belayer's give.
func drop_to(from_pos: Vector2, piece_id: String) -> float:
	var p := session.piece(piece_id) if piece_id != "" else null
	var catch_y := p.pos.y - p.sling_m if p else belay().y
	var above := maxf(0.0, from_pos.y - catch_y)
	var out := rope_used(path_points(from_pos)) + session.rope.slack_m
	var ff := 2.0 * above / maxf(out, 1.0)
	var stretch := out * (T.STRETCH_BASE + T.STRETCH_FF * minf(ff, 1.0)) * (1.0 - 0.5 * session.rope.drag)
	return 2.0 * above + session.rope.slack_m + stretch + T.BELAYER_GIVE_M


## How far you'd fall from where you are now, and what catches you (query).
func fall_preview() -> Dictionary:
	var f := fall_geometry(session.pose.tie_in())
	var rolled := rolled_out(session.pose.tie_in())
	return {"drop_m": f.length_m, "caught_by": f.chain[0] if not f.chain.is_empty() else "",
		"rolls": rolled}


func remove(piece_id: String) -> void:
	var p := session.piece(piece_id)
	if p:
		p.clipped = false
		p.back_clipped = false
	var i := session.rope.clipped.find(piece_id)
	if i >= 0:
		session.rope.clipped.remove_at(i)
		(_n().get("gates", {}) as Dictionary).erase(piece_id)
		_update()
		session.bus.send(&"unclipped", [piece_id])


func reset_for_pitch() -> void:
	session.rope = V2Rope.new()
	session.notes.erase(id())


func phases() -> Dictionary:
	_clip_phase = ClipPhase.new()
	return {&"clip": _clip_phase}


func make_overlay() -> Node:
	var card := RopeCard.new()
	card.rope = self
	return card


# ------------------------------------------------------------------ upkeep

func _update() -> void:
	session.rope.drag = drag_for()
	_n()["used"] = rope_used()


## A move or the hip button: climbing up uses the slack, then the belayer
## takes in some of what's left.
func _on_moved() -> void:
	if session == null or session.wall == null:
		return
	var used := rope_used()
	var rise := used - float(_n().get("used", used))
	var r := session.rope
	r.slack_m = maxf(0.0, r.slack_m - maxf(0.0, rise)) * T.BELAYER_TAKE
	if r.slack_m < T.SLACK_GONE_M:
		r.slack_m = 0.0
	_update()


## The rope rolled out of back-clipped pieces the fall left off its chain.
func _on_fall_started(fall: V2Fall) -> void:
	if session == null:
		return
	for piece_id in session.rope.clipped.duplicate():
		var p := session.piece(piece_id)
		if p and not p.popped and p.kind != &"anchor" and not piece_id in fall.chain:
			remove(piece_id)


func _on_fall_caught(_fall: V2Fall) -> void:
	if session == null:
		return
	session.rope.slack_m = 0.0
	_update()


## The clip phase. Entering hangs the draw (the R that opened it does
## that); Left/Right turns the gate, Up/Down picks draw or sling, R or
## Space pulls an arm-length (the last pull clips), Esc lets the rope go.
## Pumping out before the clip is in is a fall with the slack out.
class ClipPhase extends ClimbPhase:
	var _opened := false

	func enter(p_director: ClimbDirector, args := {}) -> void:
		director = p_director
		name = &"clip"
		var s := director.session
		var piece_id: String = args.get("piece_id", "")
		if not s.sys.rope.start_clip(piece_id):
			director.go(&"climb")
			return
		_opened = true
		director.use_hand(&"rope", s.piece(piece_id).pos)

	func handle(verb: StringName, pressed: bool) -> bool:
		if not pressed:
			return false
		var s := director.session
		var rope: ClimbRope = s.sys.rope
		match verb:
			&"rope", &"commit":
				if _opened and verb == &"rope" and s.rope.arms_pulled == 0:
					# The R that opened the clip hung the draw.
					_opened = false
					return true
				_opened = false
				if rope.too_high():
					return true
				var arm := s.rope.arms_pulled + 1
				director.spend(rope.pull_cost(arm))
				var done := rope.pull()
				if done:
					rope.clip()
					director.return_hand()
					director.go(&"climb")
				elif s.sys.effort.pumped_out():
					director.take_fall()
				return true
			&"aim_left", &"aim_right":
				_opened = false
				rope.set_gate(-1 if verb == &"aim_left" else 1)
				return true
			&"aim_up", &"aim_down":
				_opened = false
				rope.set_long(verb == &"aim_up")
				return true
			&"cancel":
				rope.bail()
				director.return_hand()
				director.go(&"climb")
				return true
		return false

	func hint() -> String:
		var s := director.session if director else null
		if s == null or s.rope.pulling_for == "":
			return ""
		var rope: ClimbRope = s.sys.rope
		if rope.too_high():
			return "Too high to reach. Up for a long sling, or Esc and climb higher"
		var left := rope.arms_needed(s.rope.pulling_for) - s.rope.arms_pulled
		return "R pulls rope (%d to go), Left/Right turns the gate, Up/Down draw or sling, Esc drops it" % left
