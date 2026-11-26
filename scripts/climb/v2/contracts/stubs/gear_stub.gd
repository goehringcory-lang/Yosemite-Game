class_name GearStub
extends GearSystem
## Stand-in trad gear until thread 6's lands (and kept for tests): offer a
## piece to the nearest crack, read the lobes (a cam sized for the crack sits
## in the middle, too small tips out, too big over-cams), a nut seats near a
## constriction. Supplies the "place" phase.

const PLACE_REACH := ClimbV2.ARM_M + 0.4


func id() -> StringName:
	return &"gear"


func placeable() -> Array[V2Crack]:
	return session.wall.cracks_within(session.pose.hip + Vector2(0, ClimbV2.TORSO_M), PLACE_REACH)


func offer(item_id: String, crack_id: String, at: Vector2) -> Dictionary:
	var item := session.rack.item(item_id)
	var crack := session.wall.crack(crack_id)
	if item.is_empty() or crack == null or int(item.count) <= 0:
		return {"fits": false, "lobes": "", "seated": false, "note": "nothing to place"}
	var near := crack.nearest(at)
	var w := float(near.width)
	var lo := float(item.width_min)
	var hi := float(item.width_max)
	if item.kind == "nut":
		var seated := false
		for i in crack.constrictions:
			if i < crack.points.size() and crack.points[i].distance_to(near.pos) < 0.4:
				seated = true
		var fits := w >= lo - 0.5 and w <= hi + 0.5
		return {"fits": fits and seated, "lobes": "", "seated": seated, "note": "it seats" if fits and seated else "it slides through"}
	var lobes := "sweet"
	if w > hi + 0.25:
		lobes = "tipped"
	elif w < lo - 0.25:
		lobes = "over"
	return {"fits": w >= lo - 1.0 and w <= hi + 1.0, "lobes": lobes, "seated": false, "note": ""}


func place(item_id: String, crack_id: String, at: Vector2) -> V2Piece:
	var reading := offer(item_id, crack_id, at)
	if not reading.fits or not session.rack.take(item_id):
		return null
	var crack := session.wall.crack(crack_id)
	var near := crack.nearest(at)
	var p := V2Piece.new()
	var n := session.note(id())
	n.placed = int(n.get("placed", 0)) + 1
	p.id = "placed%d_%d" % [session.pitch, n.placed]
	p.kind = StringName(str(session.rack.item(item_id).kind))
	p.pos = near.pos
	p.gear_id = item_id
	p.crack_id = crack_id
	p.width = float(near.width)
	p.quality = {"sweet": 0.9, "over": 0.6, "tipped": 0.25}.get(reading.lobes, 0.8)
	if reading.lobes != "" and reading.lobes != "sweet":
		p.tags.append("overcammed" if reading.lobes == "over" else "tipped")
	session.pieces[p.id] = p
	session.bus.send(&"piece_placed", [p.id])
	return p


func phases() -> Dictionary:
	return {&"place": PlacePhase.new()}


## The place phase: left/right picks a piece off the rack, up/down slides
## along the crack, commit offers it (read the lobes), commit again places
## it and opens the clip phase; cancel puts it back.
class PlacePhase extends ClimbPhase:
	var crack_id := ""
	var at := Vector2.ZERO
	var items: Array[Dictionary] = []
	var index := 0
	var reading := {}

	func enter(p_director: ClimbDirector, _args := {}) -> void:
		director = p_director
		name = &"place"
		var s := director.session
		var cracks: Array[V2Crack] = s.sys.gear.placeable()
		items = s.rack.of_kind("cam") + s.rack.of_kind("nut")
		if cracks.is_empty() or items.is_empty():
			director.go(&"climb")
			return
		crack_id = cracks[0].id
		at = cracks[0].nearest(s.pose.hip + Vector2(0, ClimbV2.TORSO_M + 0.3)).pos
		index = 0
		reading = {}
		director.use_hand(&"gear", at)

	func current_item() -> String:
		return str(items[index].id) if index < items.size() else ""

	func handle(verb: StringName, pressed: bool) -> bool:
		if not pressed:
			return false
		var s := director.session
		match verb:
			&"aim_left", &"aim_right":
				index = wrapi(index + (1 if verb == &"aim_right" else -1), 0, items.size())
				reading = {}
				return true
			&"aim_up", &"aim_down":
				var c := s.wall.crack(crack_id)
				at = c.nearest(at + Vector2(0, 0.2 if verb == &"aim_up" else -0.2)).pos
				reading = {}
				return true
			&"commit":
				if reading.is_empty():
					reading = s.sys.gear.offer(current_item(), crack_id, at)
					director.spend(s.sys.effort.price_action(&"offer"))
					s.bus.send(&"piece_offered", [current_item(), reading])
				else:
					var p: V2Piece = s.sys.gear.place(current_item(), crack_id, at)
					if p == null:
						reading = {}
						return true
					director.spend(s.sys.effort.price_action(&"place"))
					director.return_hand()
					director.go(&"clip", {"piece_id": p.id})
				return true
			&"cancel":
				s.bus.send(&"piece_cancelled", [current_item()])
				director.return_hand()
				director.go(&"climb")
				return true
		return false

	func hint() -> String:
		return "Left/Right picks a piece, Up/Down slides it, Space offers then places, Esc puts it back"
