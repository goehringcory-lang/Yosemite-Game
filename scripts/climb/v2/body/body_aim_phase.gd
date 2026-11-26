class_name BodyAimPhase
extends ClimbPhase
## The "climb" phase of v2 (thread 3): aim the next hand, shape the body,
## commit. Nothing here runs on a clock; the wall waits for you.
##
##   - arrows aim among the holds the next hand could use (the overlay rings
##     them); the aim is kept per hand, so swapping back finds it again;
##   - holding the body button turns the arrows into the hips: each press
##     steps the hips 0.15 m on the lattice. The aim stays pinned (a hold that
##     a shift puts out of reach shows as "can't", it is never re-aimed), and
##     letting go of the button doesn't move it. A tap of the body button
##     with no arrow puts the hips back to neutral;
##   - swap gives the move to the other hand; the body only swaps by itself
##     when the next hand has nowhere to go (and says so on the bus);
##   - commit takes the previewed move through the director.
## The director answers rope, rack, rest, eat and cancel before this sees them.

const DIRS := {&"aim_up": Vector2(0, 1), &"aim_down": Vector2(0, -1), &"aim_left": Vector2(-1, 0), &"aim_right": Vector2(1, 0)}

var body: ClimbBody
var aimed := ""
var hip_shift := Vector2.ZERO
var body_held := false
## Ids the next hand can aim at this turn (valid or not).
var aim_set: Array[String] = []
var move: V2Move
## True when the body passed the move to the other hand itself this turn.
var auto_swapped := false
## The fix for a move that can't go ("hips up and left"), "" when none or
## hidden (hints off, or inside a crux).
var fix := ""

var _shifted_while_held := false
var _memory := {}
var _turn_pose := {}


func enter(p_director: ClimbDirector, _args := {}) -> void:
	director = p_director
	name = &"climb"
	body_held = false
	_new_turn()


func refresh() -> void:
	var now := director.session.pose.to_dict()
	if now != _turn_pose:
		_new_turn()
	else:
		_rebuild_set()
		_preview()


func handle(verb: StringName, pressed: bool) -> bool:
	var s := director.session
	if verb == &"body":
		if pressed:
			body_held = true
			_shifted_while_held = false
		elif body_held:
			body_held = false
			if not _shifted_while_held and hip_shift != Vector2.ZERO:
				set_hip_shift(Vector2.ZERO)
		return true
	if not pressed:
		return false
	if DIRS.has(verb):
		var dir: Vector2 = DIRS[verb]
		if body_held:
			_shifted_while_held = true
			set_hip_shift(hip_shift + dir * BodyTuning.HIP_STEP)
		else:
			aim_toward(dir)
		return true
	match verb:
		&"swap":
			_memory[String(s.pose.next_hand)] = aimed
			body.swap_hand()
			auto_swapped = false
			_turn_pose = s.pose.to_dict()
			if hip_shift != Vector2.ZERO:
				hip_shift = Vector2.ZERO
				s.bus.send(&"hip_changed", [body.base_hip()])
			_rebuild_set()
			_pick_aim(String(_memory.get(String(s.pose.next_hand), "")))
			return true
		&"commit":
			# Priced fresh: a rest or food since the aim changes the cost.
			_preview()
			if move and move.valid:
				director.commit(move)
			return true
	return false


## Moves the hips to [param shift] (snapped to the lattice); the aim stays.
func set_hip_shift(shift: Vector2) -> void:
	var snapped := ClimbBody.clamp_shift(shift)
	if snapped == hip_shift:
		return
	hip_shift = snapped
	director.session.bus.send(&"hip_changed", [body.base_hip() + hip_shift])
	_preview()


## Aims at [param hold_id] if the next hand can use it (mouse, bots, tests).
func aim_at(hold_id: String) -> bool:
	if not hold_id in aim_set:
		return false
	_set_aim(hold_id)
	return true


## Aims at the hold that lies best in [param dir] from the current aim:
## mostly angle, then distance, with a wider fallback so no hold in a
## cluster is unreachable by arrows.
func aim_toward(dir: Vector2) -> void:
	var s := director.session
	var current := s.wall.hold(aimed)
	var from: Vector2 = current.pos if current else (s.pose.limb(s.pose.next_hand) as V2Limb).pos
	var best := ""
	var best_score := -INF
	for pass_min: float in [0.35, -0.1]:
		for hid in aim_set:
			if hid == aimed:
				continue
			var h := s.wall.hold(hid)
			var d := h.pos - from
			if d.length() < 0.01:
				continue
			var c := d.normalized().dot(dir)
			if c < pass_min:
				continue
			var score := c * 2.0 - d.length() * 0.6
			if score > best_score or (score == best_score and hid < best):
				best_score = score
				best = hid
		if best != "":
			break
	if best != "":
		_set_aim(best)


func hint() -> String:
	var parts := PackedStringArray()
	if move and not move.valid and move.reason != "":
		var why := move.reason[0].to_upper() + move.reason.substr(1)
		parts.append(why + (" (try %s)" % fix if fix != "" else ""))
	elif move:
		var words := ClimbBody.technique_words(move)
		if not words.is_empty():
			parts.append(", ".join(words.slice(0, 2)))
	var hand := "left" if director.session.pose.next_hand == &"lh" else "right"
	if auto_swapped:
		parts.append("%s hand goes (the other had nowhere to go)" % hand.capitalize())
	else:
		parts.append("%s hand next" % hand.capitalize())
	parts.append("Arrows aim, Space moves, hold Shift + arrows for hips (tap Shift to reset), Z swaps hand")
	return ". ".join(parts)


# ---------------------------------------------------------------- the turn

func _new_turn() -> void:
	var s := director.session
	hip_shift = Vector2.ZERO
	auto_swapped = false
	_turn_pose = s.pose.to_dict()
	_memory.clear()
	_rebuild_set()
	if not _has_any_move():
		body.swap_hand()
		_rebuild_set()
		if _has_any_move():
			auto_swapped = true
		else:
			body.swap_hand()
			_rebuild_set()
	_turn_pose = s.pose.to_dict()
	_pick_aim("")


func _rebuild_set() -> void:
	var s := director.session
	aim_set.clear()
	for h in body.reachable(s.pose.next_hand):
		aim_set.append(h.id)
	aim_set.sort()


## True if the next hand has a valid move to another hold at some hip shift.
func _has_any_move() -> bool:
	var s := director.session
	var own: V2Limb = s.pose.limb(s.pose.next_hand)
	var others: Array[String] = []
	for hid in aim_set:
		if own.kind != &"hold" or own.id != hid:
			others.append(hid)
	for hid in others:
		if body.preview(hid).valid:
			return true
	for hid in others:
		if body.suggest_shift(hid)[1] != null:
			return true
	return false


## Aims at [param prefer] if it's in the set, else the best next hold.
func _pick_aim(prefer: String) -> void:
	if prefer != "" and prefer in aim_set:
		_set_aim(prefer)
		return
	_set_aim(best_aim())


## The hold a climber would most likely want next (query): the most upward
## progress for the least strain at neutral hips, then any that a hip shift
## makes possible, then the nearest.
func best_aim() -> String:
	var s := director.session
	var high := s.pose.high_point()
	var base := body.base_hip()
	var own: V2Limb = s.pose.limb(s.pose.next_hand)
	var best := ""
	var best_score := -INF
	for neutral_only: bool in [true, false]:
		for hid in aim_set:
			if own.kind == &"hold" and own.id == hid:
				continue
			var m := body.preview(hid)
			if not m.valid:
				if neutral_only:
					continue
				if _in_crux(hid) or not ClimbBody.hip_hints:
					# No solving the puzzle for the player: plain height.
					var hh := s.wall.hold(hid)
					if hh.pos.y - high > best_score:
						best_score = hh.pos.y - high
						best = hid
					continue
				m = body.suggest_shift(hid)[1]
				if m == null:
					continue
			var h := s.wall.hold(hid)
			var score := (h.pos.y - high) + 0.6 * m.security - 0.6 * m.strain - 0.15 * absf(h.pos.x - base.x)
			if score > best_score or (score == best_score and hid < best):
				best_score = score
				best = hid
		if best != "":
			return best
	return aim_set[0] if not aim_set.is_empty() else ""


func _set_aim(hold_id: String) -> void:
	aimed = hold_id
	_memory[String(director.session.pose.next_hand)] = hold_id
	director.session.bus.send(&"aim_changed", [aimed])
	_preview()


func _preview() -> void:
	fix = ""
	if aimed == "":
		move = null
		return
	move = director.preview(aimed, hip_shift)
	if not move.valid and ClimbBody.hip_hints and not _in_crux(aimed):
		var best: Array = body.suggest_shift(aimed)
		if best[1] != null:
			fix = describe_shift(best[0] - hip_shift)
	director.session.bus.send(&"move_previewed", [move])


func _in_crux(hold_id: String) -> bool:
	var h := director.session.wall.hold(hold_id)
	return h != null and not director.session.wall.zones_at(h.pos, &"crux").is_empty()


## "hips up and left" for a shift.
static func describe_shift(d: Vector2) -> String:
	var words := PackedStringArray()
	if d.y > 0.01:
		words.append("up")
	elif d.y < -0.01:
		words.append("down")
	if d.x > 0.01:
		words.append("right")
	elif d.x < -0.01:
		words.append("left")
	if words.is_empty():
		return ""
	return "hips " + " and ".join(words)
