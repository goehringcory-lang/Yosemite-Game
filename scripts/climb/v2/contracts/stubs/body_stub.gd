class_name BodyStub
extends BodySystem
## Stand-in body until thread 3's lands (and kept for tests): reach from the
## shoulder, hips hang below the hands, feet take the nearest foothold.
## The "climb" phase aims among reachable holds with the arrows, the body
## button shifts the hips, commit moves.

## How far a hand gets from the shoulder, with a little body movement.
const REACH := ClimbV2.ARM_M + 0.7


func id() -> StringName:
	return &"body"


func start_pose(wall: V2Wall) -> V2Pose:
	var p := V2Pose.new()
	p.hip = wall.start + Vector2(0, 0.95)
	var hands: Array[V2Hold] = []
	for h in wall.holds_within(p.hip + Vector2(0, ClimbV2.TORSO_M), REACH):
		if h.pos.y > p.hip.y:
			hands.append(h)
	hands.sort_custom(func(a: V2Hold, b: V2Hold) -> bool: return a.pos.y < b.pos.y)
	for i in 2:
		var hand: StringName = [&"lh", &"rh"][i]
		if i < hands.size():
			p.set_limb(hand, V2Limb.make(&"hold", hands[i].pos, hands[i].id))
		else:
			p.set_limb(hand, V2Limb.make(&"free", p.hip + Vector2(-0.3 + 0.6 * i, 0.6)))
	p.next_hand = &"lh" if (p.limb(&"lh") as V2Limb).pos.y <= (p.limb(&"rh") as V2Limb).pos.y else &"rh"
	p.set_limb(&"lf", V2Limb.make(&"smear", wall.start + Vector2(-0.2, 0)))
	p.set_limb(&"rf", V2Limb.make(&"smear", wall.start + Vector2(0.2, 0)))
	return p


func shoulder(pose: V2Pose = null) -> Vector2:
	return (pose if pose else session.pose).hip + Vector2(0, ClimbV2.TORSO_M)


func reachable(hand: StringName) -> Array[V2Hold]:
	var pose := session.pose
	var held := [(pose.limb(&"lh") as V2Limb).id, (pose.limb(&"rh") as V2Limb).id]
	var other: V2Limb = pose.limb(&"lh" if hand == &"rh" else &"rh")
	var out: Array[V2Hold] = []
	for h in session.wall.holds_within(shoulder(), REACH):
		if h.id in held or h.pos.y < shoulder().y - 0.9:
			continue
		if other.kind == &"hold" and h.pos.distance_to(other.pos) > REACH:
			continue
		out.append(h)
	return out


func preview(hold_id: String, hip_shift := Vector2.ZERO) -> V2Move:
	var m := V2Move.new()
	var pose := session.pose
	m.hand = pose.next_hand
	m.hold_id = hold_id
	m.from = pose.copy()
	m.to = pose.copy()
	var h := session.wall.hold(hold_id)
	if h == null or not h.hand:
		m.valid = false
		m.reason = "no hold"
		m.hip = pose.hip
		return m
	m.to.set_limb(m.hand, V2Limb.make(&"hold", h.pos, h.id))
	var other: V2Limb = m.to.limb(m.to.other_hand())
	var mid := (h.pos + other.pos) * 0.5 if other.kind == &"hold" else h.pos
	m.hip = mid - Vector2(0, ClimbV2.TORSO_M + 0.4) + hip_shift
	m.to.hip = m.hip
	m.to.tags = PackedStringArray()
	for foot: StringName in [&"lf", &"rf"]:
		var side := -0.25 if foot == &"lf" else 0.25
		var want := m.hip + Vector2(side, -ClimbV2.LEG_M + 0.1)
		var feet := session.wall.holds_within(want, 0.45, false, true)
		if not feet.is_empty() and feet[0].pos.y < m.hip.y - 0.2:
			m.to.set_limb(foot, V2Limb.make(&"hold", feet[0].pos, feet[0].id))
		else:
			m.to.set_limb(foot, V2Limb.make(&"smear", want))
	m.to.next_hand = m.to.other_hand()
	m.reach = h.pos.distance_to(shoulder()) / REACH
	m.valid = m.reach <= 1.0
	if not m.valid:
		m.reason = "too far"
	m.strain = clampf((m.reach - 0.55) * 2.0, 0.0, 1.0)
	var on_feet := 0
	for foot: StringName in [&"lf", &"rf"]:
		if (m.to.limb(foot) as V2Limb).kind == &"hold":
			on_feet += 1
	m.security = clampf(h.size * 0.6 + on_feet * 0.2, 0.0, 1.0)
	m.load = {&"lh": 0.25, &"rh": 0.25, &"lf": 0.25, &"rf": 0.25}
	if h.kind == &"jug" and m.reach > 0.9:
		m.tags.append("lunge")
	return m


func commit(move: V2Move) -> void:
	session.pose = move.to.copy()
	session.bus.send(&"move_committed", [move])


func rest_kind() -> StringName:
	if session.pose.tags.has("hang"):
		return &"hang"
	for hand: StringName in [&"lh", &"rh"]:
		var l: V2Limb = session.pose.limb(hand)
		if l.kind == &"hold":
			var h := session.wall.hold(l.id)
			if h and (h.kind == &"jug" or h.kind == &"horn" or h.kind == &"stance"):
				return h.kind
	if not session.wall.zones_at(session.pose.hip, &"rest").is_empty():
		return &"stance"
	return &""


func free_hand() -> StringName:
	var lh: V2Limb = session.pose.limb(&"lh")
	var rh: V2Limb = session.pose.limb(&"rh")
	var ls := session.wall.hold(lh.id).size if lh.kind == &"hold" and session.wall.hold(lh.id) else 0.0
	var rs := session.wall.hold(rh.id).size if rh.kind == &"hold" and session.wall.hold(rh.id) else 0.0
	return &"lh" if ls < rs else &"rh"


func phases() -> Dictionary:
	return {&"climb": AimPhase.new()}


## The climb phase: arrows aim among the next hand's reachable holds, the
## body button (held) with arrows shifts the hips, swap changes hands,
## commit takes the move.
class AimPhase extends ClimbPhase:
	var aimed := ""
	var hip_shift := Vector2.ZERO
	var body_held := false
	var move: V2Move

	func enter(p_director: ClimbDirector, _args := {}) -> void:
		director = p_director
		name = &"climb"
		aimed = ""
		hip_shift = Vector2.ZERO
		_reaim(Vector2.UP)

	func refresh() -> void:
		hip_shift = Vector2.ZERO
		aimed = ""
		_reaim(Vector2.UP)

	func handle(verb: StringName, pressed: bool) -> bool:
		var s := director.session
		if verb == &"body":
			body_held = pressed
			return true
		if not pressed:
			return false
		match verb:
			&"aim_up", &"aim_down", &"aim_left", &"aim_right":
				var dir: Vector2 = {&"aim_up": Vector2(0, 1), &"aim_down": Vector2(0, -1), &"aim_left": Vector2(-1, 0), &"aim_right": Vector2(1, 0)}[verb]
				if body_held:
					hip_shift = (hip_shift + dir * 0.15).clamp(Vector2(-0.45, -0.45), Vector2(0.45, 0.3))
					s.bus.send(&"hip_changed", [s.pose.hip + hip_shift])
					_preview()
				else:
					_reaim(dir)
				return true
			&"swap":
				s.sys.body.swap_hand()
				_reaim(Vector2.UP)
				return true
			&"commit":
				if move and move.valid:
					director.commit(move)
				return true
		return false

	## Aims at the reachable hold furthest in [param dir] from the current aim
	## (or from the moving hand).
	func _reaim(dir: Vector2) -> void:
		var s := director.session
		var holds: Array[V2Hold] = s.sys.body.reachable(s.pose.next_hand)
		if holds.is_empty():
			aimed = ""
			move = null
			s.bus.send(&"aim_changed", [""])
			return
		var from: Vector2 = (s.pose.limb(s.pose.next_hand) as V2Limb).pos
		var current := s.wall.hold(aimed)
		if current and current in holds:
			from = current.pos
		var best: V2Hold = null
		var best_score := -INF
		for h in holds:
			if current and h == current:
				continue
			var d := h.pos - from
			var score := d.normalized().dot(dir) * 2.0 - d.length() * 0.3 if d.length() > 0.01 else -9.0
			if current == null:
				score = h.pos.y * (1.0 if dir.y >= 0 else -1.0) + h.pos.x * dir.x
			if score > best_score:
				best_score = score
				best = h
		if best == null:
			best = current if current else holds[0]
		aimed = best.id
		s.bus.send(&"aim_changed", [aimed])
		_preview()

	func _preview() -> void:
		if aimed == "":
			return
		move = director.preview(aimed, hip_shift)
		director.session.bus.send(&"move_previewed", [move])

	func hint() -> String:
		return "Arrows aim, Space moves, Shift + arrows shift hips, Z swaps hands"
