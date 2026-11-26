class_name BodySystem
extends ClimbSystem
## Interface (thread 3, controls and body): where the hands, feet and hips
## go. Owns session.pose. Supplies the "climb" phase (aiming, the hand swap,
## the body button, committing a move); the director handles the other climb
## verbs (rope, rack, rest, eat, cancel) before passing input on.
##
## Body writes geometry only (reach, strain, security, load); effort prices
## it and falls judges it.


func id() -> StringName:
	return &"body"


## The pose at the bottom of a pitch.
func start_pose(wall: V2Wall) -> V2Pose:
	var p := V2Pose.new()
	p.hip = wall.start + Vector2(0, 0.9)
	return p


## Hand holds [param hand] can reach from the current pose (query).
func reachable(_hand: StringName) -> Array[V2Hold]:
	return []


## The move of the next hand to [param hold_id] with the hips shifted by
## [param hip_shift] (the body button). Fills the body fields of a V2Move;
## must be pure (it runs on every aim change).
func preview(hold_id: String, hip_shift := Vector2.ZERO) -> V2Move:
	var m := V2Move.new()
	m.hold_id = hold_id
	m.hand = session.pose.next_hand
	m.from = session.pose.copy()
	m.to = session.pose.copy()
	m.hip = session.pose.hip + hip_shift
	m.valid = false
	m.reason = "no body system"
	return m


## Takes the move: session.pose becomes move.to and the next hand flips.
## Sends move_committed.
func commit(move: V2Move) -> void:
	session.pose = move.to.copy()
	session.bus.send(&"move_committed", [move])


## Swaps which hand moves next.
func swap_hand() -> void:
	session.pose.next_hand = session.pose.other_hand()
	session.bus.send(&"hand_swapped", [session.pose.next_hand])


## The pose hanging on the rope at [param pos] after a fall (or a take).
func settle(pos: Vector2) -> void:
	var p := V2Pose.new()
	p.hip = pos
	p.tags.append("hang")
	for l in V2Pose.LIMBS:
		p.limbs[l] = V2Limb.make(&"free", pos)
	session.pose = p


## What kind of rest the current pose gives ("" for none): jug, stance,
## kneebar, stem, jam, hang (on the rope) (query; effort decides how much it gives back).
func rest_kind() -> StringName:
	return &""


## The hand free to clip or place (the one on the better hold), or &"" if
## neither can let go (query).
func free_hand() -> StringName:
	return session.pose.other_hand()


## Puts [param hand] to a task ("rope", "gear", "chalk", "food") at
## [param at]; [method return_hand] puts it back on its hold.
func use_hand(hand: StringName, task: StringName, at: Vector2) -> void:
	session.note(id())["hand_was"] = (session.pose.limb(hand) as V2Limb).to_dict()
	session.note(id())["busy_hand"] = String(hand)
	session.pose.set_limb(hand, V2Limb.make(task, at))


func return_hand() -> void:
	var n := session.note(id())
	if n.has("busy_hand"):
		session.pose.set_limb(StringName(n.busy_hand), V2Limb.from_dict(n.hand_was))
		n.erase("busy_hand")
		n.erase("hand_was")


## True if a hand is on the pitch's top anchor hold.
func at_top() -> bool:
	for hand: StringName in [&"lh", &"rh"]:
		var l: V2Limb = session.pose.limb(hand)
		if l.kind == &"hold":
			var h := session.wall.hold(l.id)
			if h and h.has_tag("anchor"):
				return true
	return false
