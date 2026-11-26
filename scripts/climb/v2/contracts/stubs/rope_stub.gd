class_name RopeStub
extends RopeSystem
## Stand-in rope until thread 5's lands (and kept for tests): pull an
## arm-length at a time (a piece at the waist takes one pull, one overhead
## up to three), each pull lets out slack; clipping takes it back. No
## back-clips, no drag. Supplies the "clip" phase.

## How far from the shoulder a hand can clip.
const CLIP_REACH := ClimbV2.ARM_M + 0.5


func id() -> StringName:
	return &"rope"


func clippable() -> Array[V2Piece]:
	var shoulder := session.pose.hip + Vector2(0, ClimbV2.TORSO_M)
	var out: Array[V2Piece] = []
	for p in session.all_pieces():
		if not p.clipped and not p.popped and p.pos.distance_to(shoulder) <= CLIP_REACH:
			out.append(p)
	out.sort_custom(func(a: V2Piece, b: V2Piece) -> bool: return a.pos.distance_to(shoulder) < b.pos.distance_to(shoulder))
	return out


func arms_needed(piece_id: String) -> int:
	var p := session.piece(piece_id)
	if p == null:
		return 1
	return clampi(ceili((p.pos.y - session.pose.tie_in().y) / ClimbV2.ARM_PULL_M) + 1, 1, 3)


func start_clip(piece_id: String) -> bool:
	var p := session.piece(piece_id)
	if p == null or p.clipped:
		return false
	# Bolts, pins and anchors take a draw; cams and nuts have their own sling.
	if p.fixed and not session.rack.take("quickdraw"):
		return false
	session.rope.pulling_for = piece_id
	session.rope.arms_pulled = 0
	return true


func pull() -> bool:
	var r := session.rope
	if r.pulling_for == "":
		return false
	var needed := arms_needed(r.pulling_for)
	if r.arms_pulled < needed:
		r.arms_pulled += 1
		r.slack_m += ClimbV2.ARM_PULL_M
		session.bus.send(&"rope_pulled", [r.arms_pulled, needed])
	return r.arms_pulled >= needed


func clip() -> bool:
	var r := session.rope
	var p := session.piece(r.pulling_for)
	if p == null or r.arms_pulled < arms_needed(r.pulling_for):
		return false
	p.clipped = true
	r.clipped.append(p.id)
	r.slack_m = maxf(0.0, r.slack_m - r.arms_pulled * ClimbV2.ARM_PULL_M)
	r.pulling_for = ""
	r.arms_pulled = 0
	session.bus.send(&"clipped", [p.id, false])
	return true


func cancel_clip() -> void:
	var r := session.rope
	var p := session.piece(r.pulling_for)
	if p and p.fixed:
		session.rack.give_back("quickdraw")
	r.pulling_for = ""
	r.arms_pulled = 0


func fall_geometry(from_pos: Vector2) -> V2Fall:
	var f := V2Fall.new()
	f.from_pos = from_pos
	f.slack_m = session.rope.slack_m
	var chain: Array[V2Piece] = []
	for id in session.rope.clipped:
		var p := session.piece(id)
		if p and not p.popped:
			chain.append(p)
	chain.sort_custom(func(a: V2Piece, b: V2Piece) -> bool: return a.pos.y > b.pos.y)
	for p in chain:
		f.chain.append(p.id)
	f.length_m = drop_to(from_pos, f.chain[0] if not f.chain.is_empty() else "")
	return f


func remove(piece_id: String) -> void:
	var p := session.piece(piece_id)
	if p:
		p.clipped = false
	var i := session.rope.clipped.find(piece_id)
	if i >= 0:
		session.rope.clipped.remove_at(i)
		session.bus.send(&"unclipped", [piece_id])


func phases() -> Dictionary:
	return {&"clip": ClipPhase.new()}


## The clip phase: rope pulls an arm-length (each costs pump), commit clips
## once there's enough, cancel drops it.
class ClipPhase extends ClimbPhase:
	func enter(p_director: ClimbDirector, args := {}) -> void:
		director = p_director
		name = &"clip"
		var s := director.session
		var piece_id: String = args.get("piece_id", "")
		if not s.sys.rope.start_clip(piece_id):
			director.go(&"climb")
			return
		director.use_hand(&"rope", s.piece(piece_id).pos)

	func handle(verb: StringName, pressed: bool) -> bool:
		if not pressed:
			return false
		var s := director.session
		match verb:
			&"rope":
				if s.rope.arms_pulled < s.sys.rope.arms_needed(s.rope.pulling_for):
					director.spend(s.sys.effort.price_action(&"rope_pull", {"arms": s.rope.arms_pulled + 1}))
					s.sys.rope.pull()
				return true
			&"commit":
				if s.sys.rope.clip():
					director.spend(s.sys.effort.price_action(&"clip"))
					director.return_hand()
					director.go(&"climb")
				return true
			&"cancel":
				s.sys.rope.cancel_clip()
				director.return_hand()
				director.go(&"climb")
				return true
		return false

	func hint() -> String:
		return "R pulls up rope, Space clips, Esc lets it go"
