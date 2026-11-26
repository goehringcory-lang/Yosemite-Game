class_name ClimbBody
extends BodySystem
## The v2 body (thread 3, controls and body): where the hands, feet and hips
## go, and how hard a move is on the body. Owns session.pose.
##
## How a move works (CONTRACTS.md, "The move pipeline"):
##   - the next hand is picked for you (the lower hand after each move); the
##     swap verb overrides it, and it only swaps itself when that hand has
##     nowhere to go;
##   - the hips start from a natural hang under the hands and the body button
##     moves them on a small lattice in wall space (BodyTuning.HIP_MIN..MAX,
##     0.15 m steps). Nothing about a shift is a "mode": the feet are placed
##     for those hips (keeping the feet you're on when they still reach) and
##     the techniques fall out of the geometry: a flag when the centre of
##     mass swings outside the support and a leg is free to counter it, a
##     drop-knee or backstep when the hips turn toward the target, a layback
##     when the hips lean off sideways pulls, a stem when the feet straddle
##     the hips, a high step when a foot is up near the hips;
##   - the staying arm pays for lock-offs (hips high = bent arm), the
##     reaching arm pays for stretch, and a centre of mass the hands and feet
##     can't hold is a barn door. So a neutral hip is fine on easy ground and
##     the right shift makes a hard move cheap.
## The pose of a move (move.to) is the pose at the moment the hand arrives;
## committing makes it the session's pose. A move to the hold the next hand
## is already on is a reposition: hips and feet only.
##
## preview() and every query are pure: no session changes, no random draws.

## Shows "Shift hips up" style fixes under a move that can't go. Never shown
## inside a crux (that would solve the puzzle). An assist setting for thread 10.
static var hip_hints := true

var _phase: BodyAimPhase


func id() -> StringName:
	return &"body"


func phases() -> Dictionary:
	_phase = BodyAimPhase.new()
	_phase.body = self
	return {&"climb": _phase}


func make_overlay() -> Node:
	var o := BodyOverlay.new()
	o.body = self
	return o


## The climb phase this body supplies (null before phases()).
func aim_phase() -> BodyAimPhase:
	return _phase


# ---------------------------------------------------------------- the pose

func start_pose(wall: V2Wall) -> V2Pose:
	var p := V2Pose.new()
	var stand := wall.start + Vector2(0, 0.95)
	var shoulder_y := stand.y + ClimbV2.TORSO_M
	var hands: Array[V2Hold] = []
	for h in wall.holds_within(stand + Vector2(0, ClimbV2.TORSO_M), BodyTuning.REACH_M + 0.3):
		if h.pos.y > shoulder_y - 0.4:
			hands.append(h)
	hands.sort_custom(func(a: V2Hold, b: V2Hold) -> bool: return a.pos.y < b.pos.y or (a.pos.y == b.pos.y and a.id < b.id))
	if hands.size() >= 2 and hands[1].pos.x < hands[0].pos.x:
		var low := hands[0]
		hands[0] = hands[1]
		hands[1] = low
	for i in 2:
		var hand: StringName = [&"lh", &"rh"][i]
		if i < hands.size():
			p.set_limb(hand, V2Limb.make(&"hold", hands[i].pos, hands[i].id))
		else:
			p.set_limb(hand, V2Limb.make(&"free", stand + Vector2(-0.3 + 0.6 * i, 0.6)))
	p.hip = _natural_hip(p, wall)
	var feet := _pick_feet(wall, p, p.hip, 0.0)
	p.set_limb(&"lf", feet.lf)
	p.set_limb(&"rf", feet.rf)
	p.next_hand = _lower_hand(p, &"lh")
	return p


## Where the hips start for a move of [param hand] (default: the next hand)
## before any shift (query): standing up on the feet with the staying hand a
## little above its shoulder, the arm comfortably bent. With no hand to stay
## on (hanging on the rope) it is the natural hang.
func base_hip(pose: V2Pose = null, hand: StringName = &"") -> Vector2:
	var p := pose if pose else session.pose
	var who := hand if hand != &"" else p.next_hand
	return _launch_hip(p, who, session.wall)


func _launch_hip(pose: V2Pose, hand: StringName, wall: V2Wall) -> Vector2:
	var stay: V2Limb = pose.limb(_other(hand))
	if stay.kind != &"hold" or pose.tags.has("hang"):
		return _natural_hip(pose, wall)
	var own: V2Limb = pose.limb(hand)
	var mid_x := (stay.pos.x + own.pos.x) * 0.5 if own.kind == &"hold" else stay.pos.x + (0.12 if hand == &"rh" else -0.12)
	var hip := Vector2(mid_x, stay.pos.y - ClimbV2.TORSO_M - BodyTuning.STAY_ABOVE)
	if pose.tags.has("layback"):
		hip.x = lerpf(hip.x, pose.hip.x, 0.4)
	hip.y = maxf(hip.y, wall.start.y + 0.75)
	return Vector2(snappedf(hip.x, 0.001), snappedf(hip.y, 0.001))


## The shoulder of [param hand] with the hips at [param hip].
static func shoulder(hip: Vector2, hand: StringName) -> Vector2:
	return hip + Vector2(-BodyTuning.SHOULDER_HALF if hand == &"lh" else BodyTuning.SHOULDER_HALF, ClimbV2.TORSO_M)


func reachable(hand: StringName) -> Array[V2Hold]:
	var pose := session.pose
	var base := base_hip(pose, hand)
	var reach := BodyTuning.REACH_M * BodyTuning.SHOW_MAX + 0.45
	var other := _other(hand)
	var other_limb: V2Limb = pose.limb(other)
	var own: V2Limb = pose.limb(hand)
	var out: Array[V2Hold] = []
	for h in session.wall.holds_within(shoulder(base, hand), reach):
		if h.pos.y < base.y - BodyTuning.BELOW_HIP and not _mantle_hold(h):
			continue
		if other_limb.kind == &"hold" and other_limb.id == h.id and h.size < BodyTuning.MATCH_SIZE and own.id != h.id:
			continue
		out.append(h)
	return out


## The move of the next hand to [param hold_id] with the hips shifted by
## [param hip_shift] from [method base_hip] (pure).
func preview(hold_id: String, hip_shift := Vector2.ZERO) -> V2Move:
	return _solve(session.pose, session.pose.next_hand, hold_id, hip_shift)


func commit(move: V2Move) -> void:
	session.pose = move.to.copy()
	session.bus.send(&"move_committed", [move])


func swap_hand() -> void:
	session.pose.next_hand = session.pose.other_hand()
	session.bus.send(&"hand_swapped", [session.pose.next_hand])


func rest_kind() -> StringName:
	var pose := session.pose
	if pose.tags.has("hang"):
		return &"hang"
	var feet_on := 0
	for foot: StringName in [&"lf", &"rf"]:
		var l: V2Limb = pose.limb(foot)
		if l.on_rock():
			feet_on += 1
		if l.kind == &"hold":
			var fh := session.wall.hold(l.id)
			if fh and fh.has_tag("kneebar") and _hands_on(pose) >= 1:
				return &"kneebar"
	if feet_on == 0:
		return &""
	if pose.tags.has("stem"):
		return &"stem"
	var best: StringName = &""
	for hand: StringName in [&"lh", &"rh"]:
		var l: V2Limb = pose.limb(hand)
		if l.kind != &"hold":
			continue
		var h := session.wall.hold(l.id)
		if h == null:
			continue
		if h.kind == &"stance":
			return &"stance"
		if (h.kind == &"jug" or h.kind == &"horn") and h.size >= 0.8:
			best = h.kind
		elif h.kind == &"jam" and best == &"" and _jam_quality(h, pose.hip) >= 0.85:
			best = &"jam"
	if best != &"":
		return best
	for foot: StringName in [&"lf", &"rf"]:
		var l: V2Limb = pose.limb(foot)
		var fh := session.wall.hold(l.id) if l.kind == &"hold" else null
		if fh and fh.kind == &"stance":
			return &"stance"
	if not session.wall.zones_at(pose.hip, &"rest").is_empty():
		return &"stance"
	return &""


## The hand to let go with for a clip or a placement: the one whose release
## leaves the body held best (three-limb security), or &"" if neither can.
func free_hand() -> StringName:
	var pose := session.pose
	var best: StringName = &""
	var best_sec := -1.0
	for hand: StringName in [&"lh", &"rh"]:
		var stay: V2Limb = pose.limb(_other(hand))
		if (pose.limb(hand) as V2Limb).kind != &"hold":
			return hand
		var sec := hold_security(pose, _other(hand))
		if stay.kind == &"hold" and sec > best_sec:
			best_sec = sec
			best = hand
	return best if best_sec >= 0.12 else &""


## How well [param pose] is held on by [param hand] and the feet alone, 0..1
## (query): the other hand let go to clip, place, chalk or eat.
func hold_security(pose: V2Pose, hand: StringName) -> float:
	var l: V2Limb = pose.limb(hand)
	var h := session.wall.hold(l.id) if l.kind == &"hold" else null
	var grip := _grip(h, pose.hip) if h else 0.0
	var feet := _feet_quality(pose)
	return clampf(0.6 * grip + 0.4 * feet, 0.0, 1.0)


## How good [param hand]'s hold is from where the hips are, 0..1 (query).
func grip_of(hand: StringName) -> float:
	var l: V2Limb = session.pose.limb(hand)
	var h := session.wall.hold(l.id) if l.kind == &"hold" else null
	return _grip(h, session.pose.hip) if h else 0.0


## The hip shift that makes the move to [param hold_id] easiest (pure): the
## valid lattice cell with the best security for the least strain, ties to
## the smallest shift. Returns [shift, move].
func suggest_shift(hold_id: String, hand: StringName = &"") -> Array:
	var who := hand if hand != &"" else session.pose.next_hand
	var best_move: V2Move = null
	var best_shift := Vector2.ZERO
	var best_score := -INF
	for cell in lattice():
		var m := _solve(session.pose, who, hold_id, cell)
		if not m.valid:
			continue
		var score := m.security - 0.9 * m.strain - 0.02 * cell.length()
		if score > best_score + 0.0001:
			best_score = score
			best_move = m
			best_shift = cell
	return [best_shift, best_move]


## Every hip shift the body button can reach, neutral first.
static func lattice() -> Array[Vector2]:
	var out: Array[Vector2] = [Vector2.ZERO]
	var step := BodyTuning.HIP_STEP
	var x := BodyTuning.HIP_MIN.x
	while x <= BodyTuning.HIP_MAX.x + 0.001:
		var y := BodyTuning.HIP_MIN.y
		while y <= BodyTuning.HIP_MAX.y + 0.001:
			var c := Vector2(snappedf(x, 0.01), snappedf(y, 0.01))
			if c != Vector2.ZERO:
				out.append(c)
			y += step
		x += step
	return out


## Snaps a hip shift onto the lattice.
static func clamp_shift(shift: Vector2) -> Vector2:
	var s := (shift / BodyTuning.HIP_STEP).round() * BodyTuning.HIP_STEP
	return Vector2(snappedf(s.x, 0.01), snappedf(s.y, 0.01)).clamp(BodyTuning.HIP_MIN, BodyTuning.HIP_MAX)


## The words for a move's body position, most telling first, for the HUD:
## "flag", "drop knee", "layback", "hand jam"...
static func technique_words(move: V2Move) -> PackedStringArray:
	var out := PackedStringArray()
	var names := {"reposition": "reposition", "dyno": "dyno", "lunge": "lunge", "mantle": "mantle",
		"match": "match", "cross": "cross through", "flag": "flag", "dropknee": "drop knee",
		"backstep": "backstep", "layback": "layback", "stem": "stem", "heelhook": "heel hook",
		"highstep": "high step", "barndoor": "barn door", "finger_jam": "finger jam",
		"hand_jam": "hand jam", "fist_jam": "fist jam", "offwidth": "arm bar", "feetcut": "feet cut",
		"lockoff": "lock-off"}
	for tag: String in ["reposition", "dyno", "lunge", "mantle", "match", "cross", "barndoor", "flag",
			"dropknee", "backstep", "layback", "stem", "heelhook", "highstep", "finger_jam", "hand_jam",
			"fist_jam", "offwidth", "lockoff", "feetcut"]:
		if move.has_tag(tag):
			out.append(names[tag])
	return out


# ---------------------------------------------------------------- the solver

func _solve(pose: V2Pose, hand: StringName, hold_id: String, hip_shift: Vector2) -> V2Move:
	var wall := session.wall
	var m := V2Move.new()
	m.hand = hand
	m.hold_id = hold_id
	m.from = pose.copy()
	m.to = pose.copy()
	m.to.tags = PackedStringArray()
	var shift := clamp_shift(hip_shift)
	var base := _launch_hip(pose, hand, wall)
	var L := base + shift
	m.hip = L
	var h := wall.hold(hold_id)
	if h == null or not h.hand:
		return _invalid(m, "no hold")
	var other := _other(hand)
	var own: V2Limb = pose.limb(hand)
	var stay: V2Limb = pose.limb(other)
	var stay_hold := wall.hold(stay.id) if stay.kind == &"hold" else null
	var hanging := pose.tags.has("hang") or _hands_on(pose) == 0
	var reposition := own.kind == &"hold" and own.id == hold_id
	if reposition and shift == Vector2.ZERO:
		return _invalid(m, "already there")
	if reposition:
		m.tags.append("reposition")
	var matching := stay_hold != null and stay_hold.id == hold_id and not reposition
	if matching:
		m.tags.append("match")
		if h.size < BodyTuning.MATCH_SIZE:
			return _invalid(m, "too small to match")
	if h.pos.y < L.y - BodyTuning.BELOW_HIP and not _mantle_hold(h) and not reposition:
		return _invalid(m, "too low")

	# --- the feet for these hips (kept where they still reach); leaning off
	# a sideways pull walks them up high, as in a layback
	var lift := shift.y
	if not reposition and _side_pull(h, L) != 0:
		lift += 0.25
	var feet := _pick_feet(wall, pose, L, lift)
	var lf: V2Limb = feet.lf
	var rf: V2Limb = feet.rf

	# --- turning the hips toward the target
	var dir := 0
	if absf(h.pos.x - base.x) >= 0.15:
		dir = 1 if h.pos.x > base.x else -1
	var turned := dir != 0 and absf(shift.x) >= 0.15 and signf(shift.x) == dir and not reposition
	var reach_bonus := 0.0
	var outside: V2Limb = rf if dir > 0 else lf
	if turned:
		m.to.facing = dir
		if outside.kind == &"hold" and outside.pos.y >= L.y - BodyTuning.KNEE_DROP:
			m.tags.append("dropknee")
			reach_bonus = BodyTuning.TURN_REACH
		elif outside.kind == &"hold":
			m.tags.append("backstep")
			reach_bonus = BodyTuning.BACKSTEP_REACH

	# --- reach from the moving shoulder
	var sh := shoulder(L, hand)
	if dir != 0 and reach_bonus > 0.0:
		sh.x += reach_bonus * dir
	var dist := h.pos.distance_to(sh)
	m.reach = 0.0 if reposition else dist / BodyTuning.REACH_M
	# Sitting low to throw: the legs drive the body back up, so a dyno is
	# measured from standing height.
	var preloaded := shift.y <= BodyTuning.DYNO_PRELOAD + 0.001
	var throw_sh := Vector2(sh.x, sh.y - shift.y)
	var throw_reach := h.pos.distance_to(throw_sh) / BodyTuning.REACH_M
	if not reposition:
		if hand == &"rh" and stay.kind == &"hold" and h.pos.x < stay.pos.x - 0.1:
			m.tags.append("cross")
		elif hand == &"lh" and stay.kind == &"hold" and h.pos.x > stay.pos.x + 0.1:
			m.tags.append("cross")
	var mantle := _mantle_hold(h) and h.pos.y <= sh.y + 0.15 and not reposition
	if mantle:
		m.tags.append("mantle")

	# --- can the staying arm hold on from these hips?
	var lockoff := 0.0
	if stay.kind == &"hold" and not reposition:
		var ssh := shoulder(L, other)
		if stay.pos.distance_to(ssh) > BodyTuning.REACH_M * 1.02:
			return _invalid(m, "can't keep the other hand on", feet)
		lockoff = clampf((ssh.y + BodyTuning.LOCKOFF_FROM - stay.pos.y) / BodyTuning.LOCKOFF_SPAN, 0.0, 1.0)
	elif stay.kind != &"hold" and not hanging and not reposition:
		return _invalid(m, "the other hand is busy", feet)
	if reposition:
		for held: StringName in [&"lh", &"rh"]:
			var l: V2Limb = pose.limb(held)
			if l.kind == &"hold" and l.pos.distance_to(shoulder(L, held)) > BodyTuning.REACH_M * 1.02:
				return _invalid(m, "can't reach the holds from there", feet)
	if lockoff > 0.6:
		m.tags.append("lockoff")

	# --- reach bands: lunge, dyno, too far
	var grab_hip := L
	if m.reach > 1.0:
		if m.reach <= BodyTuning.LUNGE_MAX and h.size >= BodyTuning.LUNGE_MIN_SIZE:
			m.tags.append("lunge")
		elif preloaded and throw_reach > BodyTuning.LUNGE_MAX * 0.95 and throw_reach <= BodyTuning.DYNO_MAX and h.size >= BodyTuning.DYNO_MIN_SIZE:
			m.tags.append("dyno")
			m.reach = throw_reach
			sh = throw_sh
			dist = h.pos.distance_to(sh)
		else:
			var why := "too far"
			var from_standing := m.reach if not preloaded else throw_reach
			if from_standing <= BodyTuning.DYNO_MAX and h.size >= BodyTuning.DYNO_MIN_SIZE and not preloaded:
				why = "too far: sit the hips low to throw for it"
			elif from_standing <= BodyTuning.DYNO_MAX and h.size < BodyTuning.DYNO_MIN_SIZE:
				why = "too far, and too small to throw for"
			return _invalid(m, why, feet)
		# The body travels with the hand: the hips arrive higher.
		grab_hip = L + (h.pos - sh).normalized() * (dist - BodyTuning.REACH_M)
		var rf2 := _keep_or_cut(rf, grab_hip, &"rf")
		var lf2 := _keep_or_cut(lf, grab_hip, &"lf")
		if (lf2.kind == &"free" and lf.on_rock()) or (rf2.kind == &"free" and rf.on_rock()):
			m.tags.append("feetcut")
		lf = lf2
		rf = rf2
	if mantle:
		grab_hip = Vector2(h.pos.x, h.pos.y - 0.2)

	# --- balance: does the support hold the centre of mass?
	# The reaching arm and the lean carry the centre of mass toward the hold.
	var com := L + Vector2((h.pos.x - L.x) * BodyTuning.REACH_LEAN if not reposition else 0.0, ClimbV2.TORSO_M * 0.3)
	var span := _support_span(wall, lf, rf, stay if not reposition else null, com)
	var swing := 0.0
	var side := 0
	if not span.is_empty():
		if com.x < span[0] - BodyTuning.BALANCE_SLACK:
			swing = span[0] - com.x
			side = -1
		elif com.x > span[1] + BodyTuning.BALANCE_SLACK:
			swing = com.x - span[1]
			side = 1
	elif not hanging and not reposition:
		swing = 0.3
	if swing > 0.0 and side != 0:
		# A free leg counters the swing: it flags back across the support.
		var free_foot: StringName = &""
		if lf.kind == &"free":
			free_foot = &"lf"
		elif rf.kind == &"free":
			free_foot = &"rf"
		if free_foot != &"":
			var flag := V2Limb.make(&"free", L + Vector2(-side * 0.55, -0.5))
			if free_foot == &"lf":
				lf = flag
			else:
				rf = flag
			m.tags.append("flag")
			swing = maxf(0.0, swing - BodyTuning.FLAG_COUNTER)
		if swing > BodyTuning.BALANCE_SLACK:
			m.tags.append("barndoor")

	# --- techniques from the geometry
	var feet_on: Array[V2Limb] = []
	for f in [lf, rf]:
		if (f as V2Limb).on_rock():
			feet_on.append(f)
	var high_step := false
	for f in feet_on:
		if f.kind == &"hold" and f.pos.y >= L.y - BodyTuning.HIGH_STEP:
			high_step = true
			var fh := wall.hold(f.id)
			if fh and fh.has_tag("heel") and f.pos.y >= L.y - 0.1:
				m.tags.append("heelhook")
	if high_step:
		m.tags.append("highstep")
		# Standing on a high foot, the legs lift the body: the staying arm
		# hardly has to lock off.
		lockoff *= BodyTuning.HIGH_STEP_LOCKOFF
		if m.tags.has("lockoff") and lockoff <= 0.6:
			m.tags.remove_at(m.tags.find("lockoff"))
	if feet_on.size() == 2 and absf(lf.pos.x - rf.pos.x) >= BodyTuning.STEM_SPAN and minf(lf.pos.x, rf.pos.x) < L.x and maxf(lf.pos.x, rf.pos.x) > L.x:
		m.tags.append("stem")
	var target_jam := _jam_tag(h, grab_hip)
	if target_jam != "":
		m.tags.append(target_jam)
	if _layback(h, stay_hold if not reposition else null, grab_hip, feet_on, wall):
		m.tags.append("layback")

	# --- the numbers
	var feet_q := _feet_quality_of(lf, rf, wall)
	var feet_share := _feet_share(wall.angle, feet_q, m.tags)
	var hold_on := 0.6 if hanging else (_grip(stay_hold, L) if stay_hold else 0.0)
	if reposition:
		hold_on = maxf(grip_hold(pose.limb(&"lh"), L), grip_hold(pose.limb(&"rh"), L))
	var target_grip := _grip(h, grab_hip)
	var sec := BodyTuning.SEC_HOLD_ON * hold_on + BodyTuning.SEC_FEET * feet_q + BodyTuning.SEC_TARGET * target_grip
	if m.has_tag("barndoor"):
		sec -= BodyTuning.SEC_BARN * swing
	if m.has_tag("layback") or m.has_tag("stem"):
		sec += 0.08
	if m.has_tag("lunge"):
		var over := (m.reach - 1.0) / (BodyTuning.LUNGE_MAX - 1.0)
		sec *= 1.0 - 0.45 * over * over
	elif m.has_tag("dyno"):
		var over := (m.reach - BodyTuning.LUNGE_MAX) / (BodyTuning.DYNO_MAX - BodyTuning.LUNGE_MAX)
		sec *= 0.6 - 0.3 * over * over
	m.security = clampf(sec, 0.0, 1.0)

	var strain := maxf(0.0, m.reach - BodyTuning.STRAIN_REACH_FROM) * BodyTuning.STRAIN_REACH
	strain += lockoff * BodyTuning.STRAIN_LOCKOFF * (1.0 - 0.6 * feet_share)
	if m.has_tag("cross"):
		strain += BodyTuning.STRAIN_CROSS
	if high_step:
		strain += BodyTuning.STRAIN_HIGH_STEP
	if m.has_tag("barndoor"):
		strain += swing * BodyTuning.STRAIN_BARN
	if feet_on.is_empty():
		strain += BodyTuning.STRAIN_FEET_CUT * clampf(0.5 + wall.angle / 60.0, 0.3, 1.0)
	if m.has_tag("dropknee"):
		strain += BodyTuning.STRAIN_DROPKNEE
	elif m.has_tag("backstep"):
		strain += BodyTuning.STRAIN_BACKSTEP
	strain += BodyTuning.STRAIN_STEEP * clampf(wall.angle / 60.0, 0.0, 1.0)
	m.strain = clampf(strain, 0.0, 1.0)

	# Weight during the move: the feet take their share, the staying hand the rest.
	var load := {&"lh": 0.0, &"rh": 0.0, &"lf": 0.0, &"rf": 0.0}
	var ql := _foot_q(lf, wall)
	var qr := _foot_q(rf, wall)
	if ql + qr > 0.0:
		load[&"lf"] = feet_share * ql / (ql + qr)
		load[&"rf"] = feet_share * qr / (ql + qr)
	else:
		feet_share = 0.0
	if reposition:
		load[&"lh"] = (1.0 - feet_share) * 0.5
		load[&"rh"] = (1.0 - feet_share) * 0.5
	elif hanging and stay.kind != &"hold":
		load[hand] = 1.0 - feet_share
	else:
		load[other] = 1.0 - feet_share
	m.load = load

	# --- the pose when the hand arrives
	m.to.hip = grab_hip
	if not reposition:
		m.to.set_limb(hand, V2Limb.make(&"hold", h.pos, h.id))
	m.to.set_limb(&"lf", lf)
	m.to.set_limb(&"rf", rf)
	for tag in ["flag", "dropknee", "backstep", "layback", "stem", "highstep", "heelhook"]:
		if m.has_tag(tag):
			m.to.tags.append(tag)
	if target_jam != "":
		m.to.tags.append("jam")
	if m.to.facing == 0 and m.has_tag("layback"):
		m.to.facing = 1 if h.pull.x > 0.0 else -1
	m.to.next_hand = pose.next_hand if reposition else _lower_hand(m.to, other)
	m.valid = true
	return m


func _invalid(m: V2Move, why: String, feet := {}) -> V2Move:
	m.valid = false
	m.reason = why
	if not feet.is_empty():
		m.to.set_limb(&"lf", feet.lf)
		m.to.set_limb(&"rf", feet.rf)
	m.to.hip = m.hip
	return m


static func _hands_on(pose: V2Pose) -> int:
	var n := 0
	for hand: StringName in [&"lh", &"rh"]:
		if (pose.limb(hand) as V2Limb).kind == &"hold":
			n += 1
	return n


func _other(hand: StringName) -> StringName:
	return &"lh" if hand == &"rh" else &"rh"


## The hand that goes next after a move: the lower one (on a tie, [param tie]).
func _lower_hand(pose: V2Pose, tie: StringName) -> StringName:
	var l: V2Limb = pose.limb(&"lh")
	var r: V2Limb = pose.limb(&"rh")
	if l.kind != &"hold" and r.kind == &"hold":
		return &"lh"
	if r.kind != &"hold" and l.kind == &"hold":
		return &"rh"
	if absf(l.pos.y - r.pos.y) < 0.05:
		return tie
	return &"lh" if l.pos.y < r.pos.y else &"rh"


## The hips hanging naturally under [param pose]'s hands: shoulders under
## the hands' middle, raised until each hand is comfortably in reach, never
## below standing on the ground.
func _natural_hip(pose: V2Pose, wall: V2Wall) -> Vector2:
	var held: Array[StringName] = []
	for hand: StringName in [&"lh", &"rh"]:
		if (pose.limb(hand) as V2Limb).kind == &"hold":
			held.append(hand)
	if held.is_empty():
		return pose.hip
	var mid := Vector2.ZERO
	for hand in held:
		mid += (pose.limb(hand) as V2Limb).pos
	mid /= held.size()
	var hip := mid - Vector2(0, ClimbV2.TORSO_M + BodyTuning.HANG_DROP)
	if held.size() == 1:
		hip.x += 0.12 if held[0] == &"lh" else -0.12
	for hand in held:
		var p: Vector2 = (pose.limb(hand) as V2Limb).pos
		var sx := hip.x + (-BodyTuning.SHOULDER_HALF if hand == &"lh" else BodyTuning.SHOULDER_HALF)
		var dx := absf(p.x - sx)
		var r := BodyTuning.REACH_M * 0.9
		var need := p.y - sqrt(maxf(0.0, r * r - dx * dx)) - ClimbV2.TORSO_M
		hip.y = maxf(hip.y, need)
	hip.y = maxf(hip.y, wall.start.y + 0.75)
	return Vector2(snappedf(hip.x, 0.001), snappedf(hip.y, 0.001))


func _mantle_hold(h: V2Hold) -> bool:
	return h.kind == &"stance" or h.has_tag("mantle")


# ---------------------------------------------------------------- feet

## Feet for hips at [param hip]: each foot keeps its hold if it still reaches,
## else takes the best foothold in leg reach (ties by hold id), else smears
## (slabs and vertical walls) or hangs free. [param lift] > 0 (hips up) looks
## for higher feet; < 0 (sitting) lower ones. {lf, rf}.
func _pick_feet(wall: V2Wall, pose: V2Pose, hip: Vector2, lift: float) -> Dictionary:
	var want_drop := 0.7 - clampf(lift, -0.3, 0.3) * 1.2
	var opts := {}
	for foot: StringName in [&"lf", &"rf"]:
		opts[foot] = _foot_options(wall, pose, hip, foot, want_drop)
	# The foot with the better best option picks first; a small hold takes one foot.
	var order: Array[StringName] = [&"lf", &"rf"]
	var lb: float = opts[&"lf"][0][0] if not opts[&"lf"].is_empty() else -INF
	var rb: float = opts[&"rf"][0][0] if not opts[&"rf"].is_empty() else -INF
	if rb > lb:
		order = [&"rf", &"lf"]
	var out := {}
	var taken := ""
	for foot in order:
		var chosen: V2Limb = null
		for o: Array in opts[foot]:
			var hid: String = o[1]
			if hid == taken and hid != "ground":
				var th := wall.hold(hid)
				if th == null or th.size < 0.7:
					continue
			chosen = o[2]
			break
		if chosen == null:
			chosen = _smear_or_free(wall, hip, foot)
		out[foot] = chosen
		taken = chosen.id
	return out


## Scored options for one foot: [[score, hold id, limb], ...] best first.
func _foot_options(wall: V2Wall, pose: V2Pose, hip: Vector2, foot: StringName, want_drop: float) -> Array:
	var side := -1.0 if foot == &"lf" else 1.0
	var root := hip + Vector2(side * 0.1, 0)
	var current: V2Limb = pose.limb(foot)
	var opts := []
	for f in wall.holds_within(root, BodyTuning.LEG_REACH_M, false, true):
		var heel := f.has_tag("heel")
		if f.pos.y > hip.y - 0.05 and not (heel and f.pos.y <= hip.y + 0.35):
			continue
		var q := _foot_hold_quality(f, wall)
		var score := q
		score -= absf(f.pos.y - (hip.y - want_drop)) * 1.1
		score -= absf(f.pos.x - (hip.x + side * 0.22)) * 0.8
		if current.kind == &"hold" and current.id == f.id:
			score += BodyTuning.FOOT_KEEP
		opts.append([score, f.id, V2Limb.make(&"hold", f.pos, f.id)])
	# The ground at the bottom of the pitch.
	if hip.y - BodyTuning.LEG_REACH_M <= wall.start.y + 0.02:
		var g := Vector2(hip.x + side * 0.2, wall.start.y)
		var score := 1.0 - absf(g.y - (hip.y - want_drop)) * 0.3
		opts.append([score, "ground", V2Limb.make(&"smear", g, "ground")])
	opts.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]) or (float(a[0]) == float(b[0]) and str(a[1]) < str(b[1])))
	return opts


func _smear_or_free(wall: V2Wall, hip: Vector2, foot: StringName) -> V2Limb:
	var side := -1.0 if foot == &"lf" else 1.0
	var at := hip + Vector2(side * 0.25, -0.75)
	if wall.angle <= 15.0 and at.y >= wall.start.y:
		return V2Limb.make(&"smear", at)
	return V2Limb.make(&"free", hip + Vector2(side * 0.2, -0.7))


## A foot that no longer reaches [param hip] comes off.
func _keep_or_cut(f: V2Limb, hip: Vector2, foot: StringName) -> V2Limb:
	if not f.on_rock():
		return f
	var side := -1.0 if foot == &"lf" else 1.0
	if f.pos.distance_to(hip + Vector2(side * 0.1, 0)) <= BodyTuning.LEG_REACH_M:
		return f
	return V2Limb.make(&"free", hip + Vector2(side * 0.2, -0.75))


func _foot_hold_quality(f: V2Hold, wall: V2Wall) -> float:
	if f.kind == &"jam" and f.crack_id != "":
		var c := wall.crack(f.crack_id)
		if c:
			return BodyTuning.curve(BodyTuning.FOOT_JAM, c.width_near(f.pos))
	if f.kind == &"stance":
		return 1.0
	return clampf(f.size, 0.0, 1.0)


func _foot_q(f: V2Limb, wall: V2Wall) -> float:
	match f.kind:
		&"hold":
			var h := wall.hold(f.id)
			return _foot_hold_quality(h, wall) if h else 0.0
		&"smear":
			if f.id == "ground":
				return 1.0
			return clampf(BodyTuning.SMEAR_VERTICAL - wall.angle / 40.0, 0.0, 0.8)
	return 0.0


func _feet_quality_of(lf: V2Limb, rf: V2Limb, wall: V2Wall) -> float:
	var q := _foot_q(lf, wall) + _foot_q(rf, wall)
	return clampf(q / 1.1, 0.0, 1.0)


func _feet_quality(pose: V2Pose) -> float:
	return _feet_quality_of(pose.limb(&"lf"), pose.limb(&"rf"), session.wall)


func _feet_share(angle: float, feet_q: float, tags: PackedStringArray) -> float:
	var share := BodyTuning.curve(BodyTuning.FEET_SHARE, angle) * clampf(feet_q * 1.3, 0.0, 1.0)
	if tags.has("stem") or tags.has("layback"):
		share += 0.12
	if tags.has("heelhook"):
		share += 0.08
	return clampf(share, 0.0, 0.85)


# ---------------------------------------------------------------- hands

## The x range the centre of mass can sit over without swinging: feet on
## rock, plus the staying hand if its pull holds the body where it is.
func _support_span(wall: V2Wall, lf: V2Limb, rf: V2Limb, stay: V2Limb, com: Vector2) -> Array:
	var xs: Array[float] = []
	for f in [lf, rf]:
		if (f as V2Limb).on_rock():
			xs.append((f as V2Limb).pos.x)
	if stay and stay.kind == &"hold":
		var h := wall.hold(stay.id)
		if h and _align(h, com) >= BodyTuning.ANCHOR_ALIGN:
			xs.append(h.pos.x)
	if xs.is_empty():
		return []
	return [xs.min(), xs.max()]


## How well the body hangs in [param h]'s pull from hips at [param hip]: 1 =
## right in line (a jug straight overhead), 0 = across it, < 0 = against it.
func _align(h: V2Hold, hip: Vector2) -> float:
	var body := hip + Vector2(0, ClimbV2.TORSO_M * 0.5)
	var d := body - h.pos
	if d.length() < 0.01:
		return 1.0
	return d.normalized().dot(h.pull.normalized() if h.pull.length() > 0.01 else Vector2.DOWN)


func grip_hold(l: V2Limb, hip: Vector2) -> float:
	if l.kind != &"hold":
		return 0.0
	var h := session.wall.hold(l.id)
	return _grip(h, hip) if h else 0.0


## How well a hand holds [param h] with the hips at [param hip], 0..1: the
## hold's size, how well the body lines up with its pull, and for a crack
## spot how well the width takes a hand (or a layback when the hips lean off).
func _grip(h: V2Hold, hip: Vector2) -> float:
	if h == null:
		return 0.0
	var wall := session.wall
	if h.kind == &"jam" and h.crack_id != "":
		if absf(hip.x - h.pos.x) < 0.15:
			return _jam_quality(h, hip)
		# Leaning off the crack: a layback on its edge.
		var lean := clampf(absf(hip.x - h.pos.x) / 0.4, 0.0, 1.0)
		return maxf(_jam_quality(h, hip) * (1.0 - lean), 0.45 + 0.25 * lean)
	var a := clampf(_align(h, hip), 0.0, 1.0)
	var steep := clampf(wall.angle, 0.0, 60.0)
	match h.kind:
		&"jug", &"horn", &"stance":
			return clampf(h.size * (0.6 + 0.4 * a), 0.0, 1.0)
		&"sloper":
			return clampf(h.size * (0.25 + 0.75 * a * a) * (1.0 - steep / 80.0), 0.0, 1.0)
		&"pinch":
			return clampf(h.size * (0.6 + 0.4 * a), 0.0, 1.0)
	return clampf(h.size * (0.35 + 0.65 * a), 0.0, 1.0)


func _jam_quality(h: V2Hold, _hip: Vector2) -> float:
	var c := session.wall.crack(h.crack_id)
	var width := c.width_near(h.pos) if c else 4.0
	var q := BodyTuning.curve(BodyTuning.JAM, width)
	if c:
		q *= 1.0 - 0.4 * clampf(c.flare, 0.0, 1.0)
	return q


## "hand_jam" etc. when the hand goes into [param h] square to the crack.
func _jam_tag(h: V2Hold, hip: Vector2) -> String:
	if h.kind != &"jam" or h.crack_id == "" or absf(hip.x - h.pos.x) >= 0.15:
		return ""
	var c := session.wall.crack(h.crack_id)
	var width := c.width_near(h.pos) if c else 4.0
	var kind := BodyTuning.jam_kind(width)
	return "offwidth" if kind == &"offwidth" else String(kind) + "_jam"


## A layback: both hands pull sideways the same way (a crack edge counts when
## the hips lean off it), the hips sit on the pull side, a foot is up high.
func _layback(h: V2Hold, stay: V2Hold, hip: Vector2, feet_on: Array[V2Limb], wall: V2Wall) -> bool:
	var px := _side_pull(h, hip)
	if px == 0:
		return false
	if stay and _side_pull(stay, hip) != px:
		return false
	var high := false
	for f in feet_on:
		if f.pos.y >= hip.y - 0.6:
			high = true
	return high


## The sideways direction a hold pulls (-1, 0, 1), from where the hips are.
func _side_pull(h: V2Hold, hip: Vector2) -> int:
	if h.kind == &"jam" and h.crack_id != "":
		if absf(hip.x - h.pos.x) < 0.15:
			return 0
		return 1 if hip.x > h.pos.x else -1
	if absf(h.pull.x) < BodyTuning.SIDE_PULL:
		return 0
	var side := 1 if h.pull.x > 0.0 else -1
	# The hips must sit where the hold pulls them.
	if signf(hip.x - h.pos.x) != side:
		return 0
	return side
