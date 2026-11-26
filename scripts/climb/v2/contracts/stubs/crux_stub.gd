class_name CruxStub
extends CruxSystem
## Stand-in cruxes until thread 8's land (and kept for tests): a crux zone's
## data may list "sequence", the hands in order (["rh", "lh", ...]); a move
## out of order is marked, and topping the zone sends crux_sent. A wall hold
## tagged "special:<kind>" (swing, nail, haul...) opens a placeholder special
## phase that one commit gets through.


func id() -> StringName:
	return &"cruxes"


func pitch_started() -> void:
	session.notes[id()] = {}


func constrain(move: V2Move) -> void:
	var h := session.wall.hold(move.hold_id)
	if h == null:
		return
	var zone := zone_at(h.pos)
	if zone == null:
		return
	move.crux_id = zone.id
	var seq: Array = zone.data.get("sequence", [])
	var done := int(session.note(id()).get("step:" + zone.id, 0))
	if done < seq.size():
		move.in_sequence = str(seq[done]) == String(move.hand)
	move.tags.append("crux")


func committed(move: V2Move) -> void:
	var n := session.note(id())
	var h := session.wall.hold(move.hold_id)
	if move.crux_id != "":
		if not n.has("in:" + move.crux_id):
			n["in:" + move.crux_id] = true
			n["clean:" + move.crux_id] = true
			session.bus.send(&"crux_entered", [move.crux_id])
		n["step:" + move.crux_id] = int(n.get("step:" + move.crux_id, 0)) + 1
		if not move.in_sequence:
			n["clean:" + move.crux_id] = false
	for z in session.wall.zones:
		if z.kind == &"crux" and n.has("in:" + z.id) and not n.has("sent:" + z.id) and h and h.pos.y > z.rect.end.y:
			n["sent:" + z.id] = true
			session.bus.send(&"crux_sent", [z.id, bool(n.get("clean:" + z.id, true))])


func special_at(pos: Vector2) -> StringName:
	for h in session.wall.holds_within(pos, 0.05):
		for tag in h.tags:
			if tag.begins_with("special:"):
				return StringName(tag.trim_prefix("special:"))
	return &""


func phases() -> Dictionary:
	return {&"special": SpecialPhase.new()}


class SpecialPhase extends ClimbPhase:
	var kind: StringName = &""
	var at_belay := false

	func enter(p_director: ClimbDirector, args := {}) -> void:
		director = p_director
		name = &"special"
		kind = args.get("kind", &"")
		at_belay = bool(args.get("belay", false))
		director.session.bus.send(&"special_started", [kind])

	func handle(verb: StringName, pressed: bool) -> bool:
		if pressed and verb == &"commit":
			director.spend(director.session.sys.effort.price_action(&"special"))
			director.session.bus.send(&"special_step", [kind, {}])
			director.session.bus.send(&"special_finished", [kind, true])
			director.go(&"belay" if at_belay else &"climb")
			return true
		return false

	func hint() -> String:
		return "Space to do the %s" % kind
