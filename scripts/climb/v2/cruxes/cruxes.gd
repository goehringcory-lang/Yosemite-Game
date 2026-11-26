class_name CruxesV2
extends CruxSystem
## Thread 8: cruxes and big-wall moments for climbing v2.
##
## Cruxes are sequence puzzles in the normal climb controls. A crux spot (the
## wall's crux zones, or the old route profile's crux rows placed at their
## height) asks each move onto its holds for the right hand, the right hip
## position (the body button) and the right feet, read from the holds
## themselves: a sidepull wants the hand it faces and the hips leaned off
## it, an undercling or a sloper wants the hips low, a crimp wants a foot on,
## a layback leans away from its crack, a mantel presses the hips up, a slab
## stands tall, a dyno is launched from bent legs with both feet on. Nothing
## is pass/fail and nothing is timed: a miss costs (crux_cost multiplies the
## pump and gas effort charges; crux_risk adds to the chance falls rolls),
## each kind of miss in its own way, and the move's tags say what was wrong
## so the ghost can show it before you commit.
##
## Specials (the "special" phase) are the King Swing, nailing pin scars,
## chimneys and offwidths, and hauling the bag at the belay: see specials/.
## See CRUXES.md beside this file.

const T = preload("res://scripts/climb/v2/cruxes/crux_tuning.gd")
const SPECIAL_SCRIPTS := {
	&"swing": preload("res://scripts/climb/v2/cruxes/specials/swing_special.gd"),
	&"nail": preload("res://scripts/climb/v2/cruxes/specials/nail_special.gd"),
	&"haul": preload("res://scripts/climb/v2/cruxes/specials/haul_special.gd"),
	&"chimney": preload("res://scripts/climb/v2/cruxes/specials/inchworm_special.gd"),
	&"offwidth": preload("res://scripts/climb/v2/cruxes/specials/inchworm_special.gd"),
}


func id() -> StringName:
	return &"cruxes"


func pitch_started() -> void:
	var n := {"spots": CruxReader.spots_for(session.wall, session.route, session.pitch)}
	n["bag"] = _has_haul_bag()
	session.notes[id()] = n


func _has_haul_bag() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var gear: Node = tree.root.get_node_or_null("/root/Gear") if tree else null
	if gear and gear.has_method("carried"):
		return int(gear.carried("haul_bag")) > 0
	return true


## Read-only view of this system's notes (queries must not create them).
func notes() -> Dictionary:
	return session.notes.get(id(), {})


func spots() -> Array:
	return notes().get("spots", [])


func spot(spot_id: String) -> Dictionary:
	for s: Dictionary in spots():
		if s.id == spot_id:
			return s
	return {}


## The crux zone at [param pos]: the wall's own zone, else a V2Zone made
## from the spot (so callers of the interface see profile cruxes too).
func zone_at(pos: Vector2) -> V2Zone:
	var z := super.zone_at(pos)
	if z:
		return z
	for s: Dictionary in spots():
		if CruxReader.rect_of(s).has_point(pos):
			var made := V2Zone.new()
			made.id = s.id
			made.kind = &"crux"
			made.rect = CruxReader.rect_of(s)
			made.data = {"kind": s.kind, "name": s.name, "sequence": s.sequence}
			return made
	return null


# ------------------------------------------------------------ crux puzzles

func constrain(move: V2Move) -> void:
	var h := session.wall.hold(move.hold_id)
	if h == null:
		return
	var n := notes()
	var s := CruxReader.climb_spot_at(n.get("spots", []), h.pos)
	if s.is_empty():
		return
	move.crux_id = s.id
	move.tags.append("crux")
	move.tags.append("crux:" + str(s.kind))
	var step := int(n.get("step:" + str(s.id), 0))
	var list := CruxReader.demands(h, s, session.wall, step)
	var neutral := session.sys.body.preview(move.hold_id, Vector2.ZERO)
	var shift := move.hip - neutral.hip if neutral and neutral.valid else Vector2.ZERO
	var missed := CruxReader.misses(move, list, shift)
	var cost := T.ON_BETA_COST + float(n.get("carry", 0.0))
	var risk := 0.0
	for m: Dictionary in missed:
		var w: Dictionary = {"hand": T.MISS_HAND, "hip": T.MISS_HIP, "foot": T.MISS_FOOT}.get(str(m.id), T.MISS_BETA)
		cost += float(w.cost)
		risk += float(w.risk)
		move.tags.append(miss_tag(m))
	if str(s.kind) == "dyno" and CruxReader.key_hold(s, session.wall) == h.id:
		if not move.has_tag("dyno"):
			move.tags.append("dyno")
		var pump := session.effort.pump
		risk += T.DYNO_BASE_RISK + T.DYNO_PUMP_RISK * pump * pump + T.DYNO_INSECURE_RISK * (1.0 - move.security)
		if not missed.is_empty():
			risk += T.DYNO_BAD_LAUNCH_RISK
	move.in_sequence = missed.is_empty()
	move.crux_cost = minf(cost, T.COST_CAP)
	move.crux_risk = clampf(risk, 0.0, 0.95)


## A compact tag for a missed demand: crux_miss:hand_rh, crux_miss:hip_x-1,
## crux_miss:hip_y1, crux_miss:foot_2, crux_miss:beta. Art reads these to
## show the tell on the ghost (barn-door, a skating foot, crossed arms).
static func miss_tag(m: Dictionary) -> String:
	match str(m.id):
		"hand":
			return "crux_miss:hand_" + str(m.want)
		"hip":
			if int(m.get("x", 0)) != 0:
				return "crux_miss:hip_x%d" % int(m.x)
			return "crux_miss:hip_y%d" % int(m.get("y", 0))
		"foot":
			return "crux_miss:foot_%d" % int(m.n)
	return "crux_miss:beta"


## What the climber learns from a missed demand's tag (said after the move).
static func line_for(tag: String) -> String:
	var t := tag.trim_prefix("crux_miss:")
	if t.begins_with("hand_"):
		return "Crossed up. That hold faces your %s hand." % ("right" if t.ends_with("rh") else "left")
	if t.begins_with("hip_x"):
		return "You barn-doored. Lean your hips %s off it." % ("right" if t.ends_with("x1") else "left")
	if t == "hip_y-1":
		return "Hips too high. Sink low first."
	if t == "hip_y1":
		return "Stand up on it: hips up over your feet."
	if t.begins_with("foot_"):
		return "A foot skated. That move wants %s." % ("both feet on holds" if t.ends_with("2") else "a foothold")
	return "Not the beta. There's a better way through."


func committed(move: V2Move) -> void:
	var n := session.note(id())
	var h := session.wall.hold(move.hold_id)
	if h:
		n["last_hold"] = V2Data.arr(h.pos)
	n.erase("said")
	if move.crux_id != "":
		var key := move.crux_id
		if not n.has("in:" + key):
			n["in:" + key] = true
			n["clean:" + key] = true
			session.bus.send(&"crux_entered", [key])
		n["step:" + key] = int(n.get("step:" + key, 0)) + 1
		var carry := 0.0
		var lines: Array = []
		for tag in move.tags:
			if tag.begins_with("crux_miss:"):
				lines.append(line_for(tag))
				if tag.begins_with("crux_miss:hand"):
					carry = T.MISS_HAND.carry
		if not move.in_sequence:
			n["clean:" + key] = false
		if not lines.is_empty():
			n["said"] = lines[0]
		elif move.has_tag("dyno"):
			n["said"] = "Stuck it!"
		n["carry"] = carry
	else:
		n["carry"] = 0.0
	if h == null:
		return
	for s: Dictionary in n.get("spots", []):
		var key := str(s.id)
		if n.has("in:" + key) and not n.has("sent:" + key) and h.pos.y > CruxReader.rect_of(s).end.y and not str(s.kind) in CruxReader.SPECIALS:
			n["sent:" + key] = true
			session.bus.send(&"crux_sent", [key, bool(n.get("clean:" + key, true))])


# ---------------------------------------------------------------- specials

func special_at(pos: Vector2) -> StringName:
	var s := special_spot_at(pos)
	return StringName(str(s.kind)) if not s.is_empty() else &""


## The unfinished special spot at [param pos], or {}.
func special_spot_at(pos: Vector2) -> Dictionary:
	var n := notes()
	for s: Dictionary in n.get("spots", []):
		if str(s.kind) in CruxReader.SPECIALS and not n.has("done:" + str(s.id)):
			var r := CruxReader.rect_of(s)
			if r.has_point(pos) or (pos.y >= r.position.y and pos.y <= r.end.y and str(s.kind) != "swing"):
				return s
	return {}


## Hauling at the belay of a big-wall pitch with more to come.
func belay_special() -> StringName:
	var n := notes()
	if session.route == null or session.route.nights <= 0 or not bool(n.get("bag", false)) or n.has("hauled"):
		return &""
	if session.pitch + 1 >= session.sys.wall.pitch_count(session.route):
		return &""
	return &"haul"


## A fresh special of [param kind] at [param spot_data].
func make_special(kind: StringName, spot_data: Dictionary, saved := {}) -> CruxSpecial:
	var script: GDScript = SPECIAL_SCRIPTS.get(kind)
	if script == null:
		return null
	var sp: CruxSpecial = script.new()
	sp.kind = kind
	sp.setup(self, spot_data, saved)
	return sp


## Marks a special done (phase calls this through its own system).
func finish_special(sp: CruxSpecial, ok: bool) -> void:
	var n := session.note(id())
	n.erase("special")
	if sp.kind == &"haul":
		n["hauled"] = true
		return
	var key := str(sp.spot.get("id", ""))
	n["done:" + key] = true
	session.bus.send(&"crux_sent", [key, ok])


func save_special(sp: CruxSpecial, sel: int, say: String) -> void:
	var n := session.note(id())
	n["special"] = {"kind": String(sp.kind), "spot": sp.spot.duplicate(true), "state": sp.state.duplicate(true), "sel": sel, "say": say}


func phases() -> Dictionary:
	return {&"special": CruxSpecialPhase.new()}


func make_overlay() -> Node:
	var o := CruxOverlay.new()
	o.session = session
	return o
