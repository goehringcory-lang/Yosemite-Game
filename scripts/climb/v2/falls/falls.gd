class_name ClimbFalls
extends FallSystem
## Falls and the partner (thread 7 of climbing v2). Falls are real but soft:
## the fall's length is honest (rope works out the geometry), a poor piece
## can pop (two at most on story routes), you swing, hit ledges, and on a
## story route you never hit the ground; you hang, shake out and get back on,
## paying pump and time. A fall never ends the climb.
##
## The partner belays, warns you during the lead (runouts, a back-clipped
## draw, the deck), says why you came off, and at the anchor follows, cleans
## every piece back onto the rack and grades it. Placement quality stays
## hidden: the partner's words and the next fall are how you learn it.
##
## Rules, in short (numbers in FallsTuning, shaped with Fable's advice):
##   - risk: a floor-gated sum of named causes (feet, strain, hold, pump,
##     wet, sequence, dyno). Solid moves never fail; pumped out always does.
##   - a hidden meter turns risk into falls without streaks of bad luck.
##   - a piece holds by its quality against the fall's severity (fall
##     factor, length, catch), with a narrow coin band; pops damp the next.
##   - back-clipped draws can let the rope out; cams that held walk, nuts
##     that held weld in.
##
## Scratch state lives in session.note(&"falls") as plain data (snapshots
## keep it): meter, threshold, cause, warned, seen, wear, welded,
## unclipped, last_fall, report, partner, since_line, pitch_falls.

const T := preload("res://scripts/climb/v2/falls/falls_tuning.gd")


func id() -> StringName:
	return &"falls"


func pitch_started() -> void:
	var n := _n()
	n.meter = 0.0
	n.threshold = _draw_threshold()
	n.cause = ""
	n.warned = {}
	n.seen = []
	n.wear = {}
	n.welded = []
	n.unclipped = []
	n.last_fall = {}
	n.report = []
	n.since_line = 0
	n.pitch_falls = 0
	n.junk_said = false
	if not n.has("partner"):
		n.partner = partner_name()


# ------------------------------------------------------------------- risk

## Each cause of a possible fall and its share of the risk (pure):
## feet, strain, hold, pump, wet, sequence, dyno.
func causes(move: V2Move) -> Dictionary:
	var t := {}
	if move == null or not move.valid or move.has_tag("rest"):
		return t
	var h := session.wall.hold(move.hold_id) if session.wall else null
	var size := h.size if h else 0.5
	var pump_after := clampf(session.effort.pump + (move.cost.pump if move.cost else 0.0), 0.0, 1.0)
	var k := T.PUMP_GAIN * smoothstep(T.PUMP_FROM, 1.0, pump_after)
	var feet := T.W_SECURITY * pow(1.0 - clampf(move.security, 0.0, 1.0), 2.0)
	var strain := T.W_STRAIN * pow(clampf(move.strain, 0.0, 1.0), 2.0)
	var hold := T.W_HOLD * pow(1.0 - clampf(size, 0.0, 1.0), 1.5)
	t[&"feet"] = feet * T.PUMP_FRESH
	t[&"strain"] = strain * T.PUMP_FRESH
	t[&"hold"] = hold * T.PUMP_FRESH
	t[&"pump"] = (feet + strain + hold) * k
	# The real effort system (thread 4) says how reliable small holds are now.
	if session.sys.effort.has_method("hold_factor"):
		var hf := float(session.sys.effort.call("hold_factor"))
		t[&"pump"] = float(t[&"pump"]) + T.SMALL_HOLD_PUMP * (1.0 - hf) * (1.0 - clampf(size, 0.0, 1.0))
	if h and (session.mods.wet > 0.3 or not session.wall.zones_at(h.pos, &"wet").is_empty()):
		t[&"wet"] = T.WET_SMALL if size < 0.3 else T.WET
	if move.crux_id != "" and not move.in_sequence:
		t[&"sequence"] = T.OUT_OF_SEQUENCE
	if move.has_tag("dyno") or move.has_tag("lunge"):
		t[&"dyno"] = T.DYNO + T.DYNO_OVERSHOOT * clampf((move.reach - 0.8) / 0.2, 0.0, 1.0)
	return t


func risk(move: V2Move) -> void:
	move.risk = risk_of(move)


## The chance [param move] fails, 0..1 (pure).
func risk_of(move: V2Move) -> float:
	if move == null or not move.valid or move.has_tag("rest"):
		return 0.0
	if _boxed(move):
		return 1.0
	var total := 0.0
	for v: float in causes(move).values():
		total += v
	if session.mods.assisted("relaxed"):
		total *= T.RELAXED
	if total < T.DEAD_ZONE:
		return 0.0
	return minf(total, T.RISK_CAP)


## Pumped out, or (with thread 4's effort) a move that leaves you boxed:
## effort shows the ghost red for these, and they always fail (pure).
func _boxed(move: V2Move) -> bool:
	if session.sys.effort.pumped_out():
		return true
	return session.sys.effort.has_method("will_fail") and bool(session.sys.effort.call("will_fail", move))


## The biggest cause of [param move]'s risk, or "" (pure).
func top_cause(move: V2Move) -> String:
	if move and move.valid and _boxed(move):
		return "pump"
	var best := ""
	var most := 0.0
	var t := causes(move)
	for c: StringName in t:
		if float(t[c]) > most:
			most = t[c]
			best = String(c)
	return best


## Rolls once at commit. Risky moves fill a hidden meter; you come off when
## it passes a threshold drawn after each fall, so a 20% move can't fail
## three times running and can't be passed fifteen times free. Solid moves
## calm the meter. When you stay on, the partner may say something.
func falls_now(move: V2Move) -> bool:
	var n := _n()
	var fell := false
	if move.risk >= 1.0:
		fell = true
	elif move.risk <= 0.0:
		n.meter = float(n.meter) * T.CALM
	else:
		n.meter = float(n.meter) + move.risk
		fell = float(n.meter) >= float(n.threshold)
	if fell:
		n.meter = 0.0
		n.threshold = _draw_threshold()
		n.cause = top_cause(move)
		return true
	_after_move(move)
	return false


func _draw_threshold() -> float:
	return session.rng_for(id()).randf_range(T.THRESHOLD_MIN, T.THRESHOLD_MAX)


# ------------------------------------------------------------ the pieces

## The quality the partner (and the next fall) see: the placement's quality
## plus what falls did to it (a cam that walked, a nut welded in). Pure.
func seen_quality(p: V2Piece) -> float:
	if p == null:
		return 0.0
	return clampf(p.quality + float((_n().get("wear", {}) as Dictionary).get(p.id, 0.0)), 0.0, 1.0)


## How hard a fall from [param from_pos] loads [param piece_id] if it
## catches, 0..1 (pure): fall factor, length, and sideways pull.
func severity(from_pos: Vector2, piece_id: String) -> float:
	var p := session.piece(piece_id)
	var drop := session.sys.rope.drop_to(from_pos, piece_id)
	var rope_out := maxf(1.0, from_pos.y - session.wall.start.y + session.rope.slack_m)
	var ff := minf(2.0, drop / rope_out)
	var sev := T.SEVERITY_BASE + T.SEVERITY_FF * ff + T.SEVERITY_DROP * drop
	sev *= T.SOFT_CATCH if session.mods.has_device else T.HARD_CATCH
	if p and absf(from_pos.x - p.pos.x) > T.SIDEWAYS_FROM_M:
		sev *= T.SIDEWAYS
	return clampf(sev, 0.0, 1.0)


## The chance a piece of [param quality] holds a fall of [param sev] (pure).
static func hold_chance(quality: float, sev: float) -> float:
	if quality >= T.BOMBER:
		return 1.0
	var margin := quality - sev
	if margin > T.BAND:
		return 1.0
	if margin < -T.BAND:
		return 0.0
	return clampf(0.5 + margin * 0.5 / T.BAND, 0.0, 1.0)


## The chance [param piece_id] holds a fall from [param from_pos] (pure;
## bolts and anchors always hold). For bots and tests.
func holds(piece_id: String, from_pos: Vector2, damp := 1.0) -> float:
	var p := session.piece(piece_id)
	if p == null or p.popped:
		return 0.0
	if p.kind == &"bolt" or p.kind == &"anchor":
		return 1.0
	return hold_chance(seen_quality(p), severity(from_pos, piece_id) * damp)


# ------------------------------------------------------------- the fall

func resolve(fall: V2Fall) -> V2Fall:
	var n := _n()
	var rng := session.rng_for(id())
	var max_pops := T.MAX_POPS_STORY if session.mods.story else T.MAX_POPS
	var unclipped: Array = []
	var damp := 1.0
	var caught := ""
	for piece_id in fall.chain:
		var p := session.piece(piece_id)
		if p == null or p.popped:
			continue
		if fall.popped.size() < max_pops:
			if p.back_clipped:
				var across := absf(fall.from_pos.x - p.pos.x) > T.ACROSS_DX
				if rng.randf() < (T.BACK_CLIP_ACROSS if across else T.BACK_CLIP_STRAIGHT):
					fall.popped.append(piece_id)
					unclipped.append(piece_id)
					continue
			var chance := holds(piece_id, fall.from_pos, damp)
			if chance <= 0.0 or (chance < 1.0 and rng.randf() >= chance):
				p.popped = true
				fall.popped.append(piece_id)
				damp *= T.ZIPPER_DAMP
				continue
		caught = piece_id
		p.loaded += 1
		_wear(p)
		break
	fall.caught_by = caught
	n.unclipped = unclipped
	_land(fall)
	fall.cost = session.sys.effort.price_action(&"fall", {"drop_m": fall.drop_m,
		"lands_on": String(fall.lands_on), "popped": fall.popped.size(), "hard": bool(n.get("hard", false))})
	fall.partner_line = _fall_line(fall)
	n.pitch_falls = int(n.get("pitch_falls", 0)) + 1
	n.since_line = 0
	n.last_fall = {"drop_m": snappedf(fall.drop_m, 0.1), "popped": Array(fall.popped), "unclipped": unclipped.duplicate(),
		"caught_by": caught, "caught_kind": String(session.piece(caught).kind) if session.piece(caught) else "belay",
		"lands_on": String(fall.lands_on), "swing_m": snappedf(fall.swing_m, 0.1), "cause": n.cause,
		"hard": bool(n.get("hard", false))}
	n.cause = ""
	return fall


## A cam that held walks a little; a nut that held gets welded in.
func _wear(p: V2Piece) -> void:
	if p.fixed:
		return
	var n := _n()
	var wear: Dictionary = n.wear
	if p.kind == &"cam":
		wear[p.id] = float(wear.get(p.id, 0.0)) - T.CAM_WALK
	elif p.kind == &"nut":
		wear[p.id] = float(wear.get(p.id, 0.0)) + T.NUT_WELD
		if not (n.welded as Array).has(p.id):
			(n.welded as Array).append(p.id)


## Where the fall ends: the drop, the swing toward the piece, a ledge in the
## way, and the ground (story routes: the partner takes in; never a deck).
func _land(fall: V2Fall) -> void:
	var n := _n()
	n.hard = false
	var catcher := session.piece(fall.caught_by)
	var pivot_x := catcher.pos.x if catcher else session.wall.start.x
	fall.drop_m = session.sys.rope.drop_to(fall.from_pos, fall.caught_by)
	fall.swing_m = absf(fall.from_pos.x - pivot_x)
	var x := pivot_x + (fall.from_pos.x - pivot_x) * T.SWING_LEFT
	var stretch := fall.drop_m * T.STRETCH
	var y := fall.from_pos.y - fall.drop_m - stretch * 0.5
	# A ledge in the fall line stops you on it.
	var ledge_top := -INF
	for z in session.wall.zones:
		if z.kind != &"ledge":
			continue
		var top := z.rect.end.y
		if fall.from_pos.x >= z.rect.position.x and fall.from_pos.x <= z.rect.end.x and top < fall.from_pos.y - 0.3 and top > y and top > ledge_top:
			ledge_top = top
	if ledge_top > -INF:
		fall.lands_on = &"ledge"
		fall.drop_m = fall.from_pos.y - ledge_top - T.LEDGE_STOP_M
		x = fall.from_pos.x
		y = ledge_top + ClimbV2.LEG_M
	var floor_y := session.wall.start.y + T.FLOOR_M
	if y < floor_y:
		if session.pitch > 0:
			# Below the belay you hang off the anchor; the ledge stops you.
			y = floor_y
		elif session.mods.story:
			# The partner runs back and takes in (up to TAKE_IN_M; story
			# routes keep the first piece low so that's enough) and stops
			# you a hand off the ground with a hard catch. Never a deck.
			n.hard = true
			y = floor_y
		else:
			fall.lands_on = &"ground"
			y = session.wall.start.y + ClimbV2.LEG_M + 0.05
			x = fall.from_pos.x
		fall.drop_m = maxf(0.0, fall.from_pos.y - y)
	fall.settle_pos = Vector2(x, y)


func _fall_line(fall: V2Fall) -> String:
	var n := _n()
	var rng := session.rng_for(id())
	var key: StringName = &"caught"
	var unclipped: Array = n.unclipped
	var pops := fall.popped.size() - unclipped.size()
	if fall.lands_on == &"ground":
		key = &"ground"
	elif fall.lands_on == &"ledge":
		key = &"ledge_hit"
	elif pops >= 2:
		key = &"zipper"
	elif pops == 1:
		key = &"popped"
	elif bool(n.get("hard", false)):
		key = &"short_rope"
	elif not unclipped.is_empty():
		key = &"unclipped"
	elif fall.caught_by == "":
		key = &"caught_belay"
	elif fall.drop_m >= T.BIG_FALL_M:
		key = &"caught_big"
	elif fall.swing_m >= 2.0:
		key = &"swing"
	var popped_name := ""
	for piece_id in fall.popped:
		if not unclipped.has(piece_id):
			popped_name = piece_name(session.piece(piece_id))
			break
	var line := PartnerLines.pick(key, rng, {"piece": popped_name, "m": "%.0f" % fall.drop_m})
	var cause: String = n.get("cause", "")
	if cause != "":
		var why := PartnerLines.pick(StringName("cause_" + cause), rng)
		if why != "":
			line += " " + why
	return line


# -------------------------------------------------------- the lead, talking

## After a move you stuck: safety calls first (a back-clip, the deck, a
## ledge, a runout), then one "you sure?" for junk gear, then the crux, then
## the odd bit of flavour. At most one line every CHATTER_GAP moves, except
## safety, which is said once per top piece.
func _after_move(move: V2Move) -> void:
	var n := _n()
	n.since_line = int(n.get("since_line", 0)) + 1
	var warned: Dictionary = n.warned
	var rng := session.rng_for(id())
	var top := session.rope.top_piece()
	for piece_id in session.rope.clipped:
		var p := session.piece(piece_id)
		if p and p.back_clipped and not warned.has("bc:" + piece_id):
			warned["bc:" + piece_id] = true
			_say(PartnerLines.pick(&"back_clip", rng))
			return
	var danger := danger_here()
	if danger != &"" and not warned.has("%s:%s" % [danger, top]):
		warned["%s:%s" % [danger, top]] = true
		_say(PartnerLines.pick(danger, rng))
		return
	var seen: Array = n.seen
	for piece_id: String in session.pieces:
		if seen.has(piece_id):
			continue
		seen.append(piece_id)
		if not bool(n.junk_said) and seen_quality(session.pieces[piece_id]) < T.JUNK:
			n.junk_said = true
			_say(PartnerLines.pick(&"junk", rng))
			return
	if int(n.since_line) < T.CHATTER_GAP:
		return
	if move.crux_id != "" and not warned.has("crux:" + move.crux_id):
		warned["crux:" + move.crux_id] = true
		_say(PartnerLines.pick(&"crux", rng))
		return
	if int(n.since_line) >= T.CHATTER_GAP * 2 and rng.randf() < T.FLAVOUR:
		_say(PartnerLines.pick(&"flavour", rng))


## What a fall from right here would do, if the top piece held (pure):
## &"deck", &"ledge", &"runout" or &"".
func danger_here() -> StringName:
	var from := session.pose.tie_in()
	var geo := session.sys.rope.fall_geometry(from)
	var low := from.y - geo.length_m
	for z in session.wall.zones:
		if z.kind == &"ledge" and from.x >= z.rect.position.x and from.x <= z.rect.end.x and z.rect.end.y < from.y - 0.3 and z.rect.end.y > low:
			return &"ledge"
	if session.pitch == 0 and from.y > 2.5 and low < session.wall.start.y + T.FLOOR_M:
		return &"deck"
	if geo.length_m >= T.RUNOUT_M:
		return &"runout"
	return &""


func _say(line: String) -> void:
	if line == "":
		return
	_n().since_line = 0
	session.bus.send(&"partner_said", [line])


# ------------------------------------------------------------ the belay

## The partner follows the pitch from the bottom, cleans every placed piece
## back onto the rack and grades it by what they found. Each row:
## {piece_id, gear_id, name, kind, grade, line, minutes, highlight}.
func clean_pitch() -> Array[Dictionary]:
	var rng := session.rng_for(id())
	var placed: Array[V2Piece] = []
	for p: V2Piece in session.pieces.values():
		placed.append(p)
	placed.sort_custom(func(a: V2Piece, b: V2Piece) -> bool: return a.pos.y < b.pos.y if a.pos.y != b.pos.y else a.id < b.id)
	var out: Array[Dictionary] = []
	for p in placed:
		var grade := grade_of(p)
		var group: StringName = p.kind if p.kind == &"cam" or p.kind == &"nut" else &"other"
		var minutes := T.CLEAN_MINUTES
		if grade == &"stuck":
			minutes += T.STUCK_MINUTES if p.tags.has("overcammed") else T.WELDED_MINUTES
		if p.gear_id != "":
			session.rack.give_back(p.gear_id)
		var name := piece_name(p)
		var line := PartnerLines.grade_line(grade, group, rng, {"piece": name})
		# Trad gear (thread 6) can word the verdict from what it knows about
		# the placement; what the fall did (popped, held, welded) stays ours.
		if not grade in [&"popped", &"held", &"stuck"] and session.sys.gear.has_method("grade_for"):
			var g: Variant = session.sys.gear.call("grade_for", p)
			if g is Dictionary and str(g.get("line", "")) != "":
				line = str(g.line)
		session.bus.send(&"piece_cleaned", [p.id, String(grade)])
		out.append({"piece_id": p.id, "gear_id": p.gear_id, "name": name, "kind": String(group),
			"grade": String(grade), "line": line,
			"minutes": minutes, "highlight": false, "quality": seen_quality(p)})
	_mark_highlights(out)
	_n().report = out.duplicate(true)
	return out


## The partner's word for [param p] (pure): bomber, good, walked, tipped,
## marginal, prayer, stuck, popped or held.
func grade_of(p: V2Piece) -> StringName:
	if p.popped:
		return &"popped"
	var q := seen_quality(p)
	if p.tags.has("overcammed") or (_n().get("welded", []) as Array).has(p.id):
		return &"stuck"
	if p.loaded > 0 and q >= T.GOOD:
		return &"held"
	if q >= T.BOMBER:
		return &"bomber"
	if p.tags.has("tipped"):
		return &"tipped"
	if q < T.GOOD and (p.tags.has("shallow") or p.tags.has("stretched")):
		return &"marginal"
	if q >= T.GOOD and not p.tags.has("walked"):
		return &"good"
	if q >= T.WALKED:
		return &"walked"
	if q >= T.MARGINAL:
		return &"marginal"
	return &"prayer"


## Full lines for the worst and best piece and anything that took a fall;
## the rest get their grade word only (grading twelve pieces is a slog).
static func _mark_highlights(rows: Array[Dictionary]) -> void:
	if rows.is_empty():
		return
	var worst := 0
	var best := 0
	for i in rows.size():
		if float(rows[i].quality) < float(rows[worst].quality) or rows[i].grade == "popped":
			worst = i
		if float(rows[i].quality) > float(rows[best].quality):
			best = i
	var picked := 0
	for i in rows.size():
		if rows[i].grade in ["popped", "held"] and picked < 2:
			rows[i].highlight = true
			picked += 1
	rows[worst].highlight = true
	rows[best].highlight = true


## The rack name for a piece ("#1", "Nut", "Bolt").
func piece_name(p: V2Piece) -> String:
	if p == null:
		return ""
	if p.gear_id != "":
		var it := session.rack.item(p.gear_id)
		if not it.is_empty():
			return str(it.get("name", p.gear_id))
		return p.gear_id
	return String(p.kind).capitalize()


## Who's on belay: the giver of the route's partner quest, or "" (the
## overlay then says "Partner").
func partner_name() -> String:
	var route := session.route
	var tree := Engine.get_main_loop() as SceneTree
	if route == null or tree == null or route.get("partner_quest") in [null, ""]:
		return ""
	var log := tree.root.get_node_or_null("/root/QuestLog")
	if log == null:
		return ""
	var quest: Variant = log.get_quest(route.partner_quest)
	var who: Variant = log.get_character(quest.giver) if quest else null
	return str(who.display_name) if who else ""


func _n() -> Dictionary:
	return session.note(id())


func phases() -> Dictionary:
	return {&"fall": FallPhase.new(), &"belay": BelayPhase.new()}


func make_overlay() -> Node:
	var o := FallsOverlay.new()
	o.bind(session)
	return o


## After a fall you hang on the rope: commit gets back on the rock, rest
## hangs and shakes out (as often as you like; it costs minutes), and cancel
## twice lowers you off (the climb ends, nothing lost).
class FallPhase extends ClimbPhase:
	var fall: V2Fall
	var shakes := 0
	var _lower_armed := false

	func enter(p_director: ClimbDirector, args := {}) -> void:
		director = p_director
		name = &"fall"
		fall = args.get("fall")
		shakes = 0
		_lower_armed = false
		var s := director.session
		var bus := s.bus
		bus.send(&"fall_started", [fall])
		var unclipped: Array = s.note(&"falls").get("unclipped", [])
		for piece_id in fall.popped:
			if not unclipped.has(piece_id):
				bus.send(&"piece_popped", [piece_id])
		bus.send(&"fall_caught", [fall])
		if fall.partner_line != "":
			bus.send(&"partner_said", [fall.partner_line])

	func handle(verb: StringName, pressed: bool) -> bool:
		if not pressed:
			return false
		if verb != &"cancel":
			_lower_armed = false
		match verb:
			&"commit":
				director.go(&"climb")
				return true
			&"rest":
				if director.rest(&"hang"):
					shakes += 1
					return true
				return false
			&"eat":
				return director.eat()
			&"cancel":
				if _lower_armed:
					director.retreat()
				else:
					_lower_armed = true
				return true
		return false

	func hint() -> String:
		if _lower_armed:
			return "Esc again to lower off. Space to get back on"
		return "Space: back on the rock   V: hang and shake out   E: eat   Esc: lower off"


## At the anchor: you rest, the partner follows and cleans, and tells you
## about the best and worst piece. Commit climbs on (or tops out).
class BelayPhase extends ClimbPhase:
	var report: Array[Dictionary] = []

	func enter(p_director: ClimbDirector, _args := {}) -> void:
		director = p_director
		name = &"belay"
		var s := director.session
		director.rest(&"belay")
		report = s.sys.falls.clean_pitch()
		var minutes := 0
		for r in report:
			minutes += int(r.minutes)
		director.spend(V2Cost.make(0.0, 0.0, minutes))
		var n := s.note(&"falls")
		var rng := s.rng_for(&"falls")
		s.bus.send(&"partner_said", [PartnerLines.pick(&"belay_fell" if int(n.get("pitch_falls", 0)) > 0 else &"belay_clean", rng)])
		for r in report:
			if r.highlight:
				s.bus.send(&"partner_said", [r.line])

	func handle(verb: StringName, pressed: bool) -> bool:
		if pressed and verb == &"commit":
			director.next_pitch()
			return true
		return false

	func hint() -> String:
		var last := director.session.pitch + 1 >= director.pitch_count()
		return "At the anchor. E eats, Space %s" % ("tops out" if last else "climbs the next pitch")
