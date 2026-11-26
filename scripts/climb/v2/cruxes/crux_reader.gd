class_name CruxReader
extends RefCounted
## Reads a pitch for its cruxes (thread 8): where each crux spot is, what
## kind it is, and what each crux hold asks of the body. Static and pure, so
## the crux system, bots and tests all read a pitch the same way.
##
## A crux spot is a plain Dictionary (it lives in session notes, so it must
## be plain data):
##   id, kind, name, beta, rect [x, y, w, h], preset, sequence, data
## kind: "sequence" or "dyno" (played in the normal climb controls), or a
## special: "swing", "nail", "chimney", "offwidth".
## preset (sequence spots): "", "layback", "mantel", "slab", "roof".

const SPECIALS := ["swing", "nail", "chimney", "offwidth"]
const PRESETS := ["layback", "mantel", "slab", "roof"]


## Every crux spot on [param wall]: the wall's own crux zones and
## special-tagged holds first; if it has none, the old route profile's crux
## rows for [param route] pitch [param pitch], placed at their height.
static func spots_for(wall: V2Wall, route: RouteData, pitch: int) -> Array:
	var spots: Array = []
	for z in wall.zones:
		if z.kind == &"crux":
			spots.append(_from_zone(z, wall))
	for h in wall.holds:
		for tag in h.tags:
			if tag.begins_with("special:"):
				var kind := tag.trim_prefix("special:")
				spots.append({"id": "hold_" + h.id, "kind": kind, "name": _special_name(kind), "beta": "",
					"rect": V2Data.rect_arr(Rect2(h.pos - Vector2(0.4, 0.4), Vector2(0.8, 0.8 + CruxTuning.SPOT_HALF_M * 2.0))),
					"preset": "", "sequence": [], "data": {}})
	if spots.is_empty() and route != null:
		spots = _from_profile(wall, route, pitch)
	return spots


static func _from_zone(z: V2Zone, wall: V2Wall) -> Dictionary:
	var d := z.data
	var kind := str(d.get("special", d.get("kind", "")))
	var preset := str(d.get("preset", ""))
	if kind in PRESETS:
		preset = kind
		kind = "sequence"
	if kind == "":
		kind = "sequence"
		if preset == "":
			preset = _preset_for_style(String(wall.style))
	return {"id": z.id, "kind": kind, "name": str(d.get("name", "The crux")), "beta": str(d.get("beta", "")),
		"rect": V2Data.rect_arr(z.rect), "preset": preset, "sequence": (d.get("sequence", []) as Array).duplicate(true),
		"data": d.duplicate(true)}


## The old profile's crux rows (ClimbProfiles), turned into spots: a row's
## share of the pitch's moves is its share of the pitch's height.
static func _from_profile(wall: V2Wall, route: RouteData, pitch: int) -> Array:
	var out: Array = []
	if route.pitches.is_empty() or ClimbProfiles.get_profile(route.id).is_empty():
		return out
	var spec := ClimbProfiles.pitch_spec(route, pitch)
	var rows := maxi(1, int(spec.rows))
	var style := str(spec.style)
	var base := wall.start.y
	var span := wall.top.y - wall.start.y
	var crux_rows: Array = spec.get("cruxes", [])
	for row: int in crux_rows:
		var c := ClimbProfiles.crux_at(spec, row)
		var y := base + span * clampf(float(row) / rows, 0.15, 0.9)
		var kind := _kind_for(str(c.get("kind", "timing")), str(c.get("name", "")), style, bool(spec.get("hard_aid", false)))
		var half := CruxTuning.SPOT_HALF_M * (1.6 if kind in ["chimney", "offwidth", "nail"] else 1.0)
		var preset := ""
		if kind == "sequence":
			preset = "layback" if str(c.get("kind", "")) == "layback" else ("mantel" if str(c.get("name", "")).to_lower().contains("mantel") else _preset_for_style(style))
		out.append({"id": "p%d_r%d" % [pitch, row], "kind": kind, "name": str(c.get("name", "The crux")),
			"beta": str(spec.get("beta", "")), "rect": V2Data.rect_arr(Rect2(0.0, y - half, wall.size.x, half * 2.0)),
			"preset": preset, "sequence": [], "data": {}})
	# A chimney pitch with no crux row still has its squeeze: a section from
	# a third of the way up.
	if style == "chimney" and out.is_empty():
		out.append({"id": "p%d_chimney" % pitch, "kind": "chimney", "name": str(spec.get("name", "The chimney")),
			"beta": str(spec.get("beta", "")), "rect": V2Data.rect_arr(Rect2(0.0, base + span * 0.3, wall.size.x, span * 0.3)),
			"preset": "", "sequence": [], "data": {}})
	return out


## The old crux kinds as v2 ones: no timing, rhythm or mash survives.
static func _kind_for(old: String, name: String, style: String, hard_aid: bool) -> String:
	if hard_aid:
		return "nail"
	match old:
		"swing":
			return "swing"
		"dyno":
			return "dyno"
	if style == "chimney":
		return "offwidth" if name.to_lower().contains("slot") or old == "rhythm" and name.to_lower().contains("harding") else "chimney"
	return "sequence"


static func _preset_for_style(style: String) -> String:
	match style:
		"slab", "dike", "knobs":
			return "slab"
		"flake":
			return "layback"
		"roof":
			return "roof"
	return ""


static func _special_name(kind: String) -> String:
	return {"swing": "The pendulum", "nail": "Pin scars", "chimney": "The chimney", "offwidth": "The offwidth"}.get(kind, "The crux")


static func rect_of(spot: Dictionary) -> Rect2:
	return V2Data.rect(spot.rect)


## The crux spot (sequence or dyno) holding [param pos], or {}.
static func climb_spot_at(spots: Array, pos: Vector2) -> Dictionary:
	for s: Dictionary in spots:
		if not str(s.kind) in SPECIALS and rect_of(s).has_point(pos):
			return s
	return {}


## The key hold of a spot (a dyno's target, a mantel's shelf): the highest
## hand hold inside it, or a hold the wall tagged "key" or "dyno".
static func key_hold(spot: Dictionary, wall: V2Wall) -> String:
	var r := rect_of(spot)
	var best: V2Hold = null
	for h in wall.holds:
		if not h.hand or not r.has_point(h.pos):
			continue
		if h.has_tag("key") or h.has_tag("dyno"):
			return h.id
		if best == null or h.pos.y > best.pos.y:
			best = h
	return best.id if best else ""


## What [param hold] asks of a move onto it, in spot [param spot]: a list of
## demands, each {id: "hand"|"hip"|"foot"|"beta", ...}:
##   hand: {want: "lh"|"rh"}       the hand the hold faces
##   hip:  {x: -1|0|1, y: -1|0|1}  hips shifted that way by the body button
##   foot: {n: 1|2}                feet on footholds (not smears)
##   beta: {step: Dictionary}      an authored step of the zone's sequence
## [param step] is how many moves you've made in the spot (for authored beta).
static func demands(hold: V2Hold, spot: Dictionary, wall: V2Wall, step := 0) -> Array:
	var out: Array = []
	var px := signf(hold.pull.x) if absf(hold.pull.x) > 0.3 else 0.0
	match hold.kind:
		&"sidepull":
			if px != 0.0:
				out.append({"id": "hand", "want": "rh" if px > 0.0 else "lh"})
				out.append({"id": "hip", "x": int(-px), "y": 0})
		&"gaston":
			if px != 0.0:
				out.append({"id": "hand", "want": "rh" if px > 0.0 else "lh"})
				out.append({"id": "hip", "x": int(px), "y": 0})
		&"undercling":
			out.append({"id": "hip", "x": 0, "y": -1})
			out.append({"id": "foot", "n": 1})
		&"sloper":
			out.append({"id": "hip", "x": 0, "y": -1})
		&"crimp", &"pocket":
			out.append({"id": "foot", "n": 1})
	var is_key := key_hold(spot, wall) == hold.id
	match str(spot.get("preset", "")):
		"layback":
			var c := _nearest_crack(wall, hold.pos)
			if c != null:
				var away := -signf(float(c.nearest(hold.pos).pos.x) - hold.pos.x)
				if away == 0.0:
					away = -1.0
				_set_hip(out, int(away), 0)
			_set_foot(out, 2)
		"mantel":
			if is_key:
				_set_hip(out, 0, 1)
		"slab":
			_set_hip(out, 0, 1)
		"roof":
			_set_foot(out, 2)
	if str(spot.kind) == "dyno" and is_key:
		_set_hip(out, 0, -1)
		_set_foot(out, 2)
	var seq: Array = spot.get("sequence", [])
	if step < seq.size():
		var s: Variant = seq[step]
		var st: Dictionary = s if s is Dictionary else {"hand": str(s)}
		out.append({"id": "beta", "step": st})
	return out


static func _set_hip(list: Array, x: int, y: int) -> void:
	for d: Dictionary in list:
		if d.id == "hip":
			if x != 0:
				d.x = x
			if y != 0:
				d.y = y
			return
	list.append({"id": "hip", "x": x, "y": y})


static func _set_foot(list: Array, n: int) -> void:
	for d: Dictionary in list:
		if d.id == "foot":
			d.n = maxi(int(d.n), n)
			return
	list.append({"id": "foot", "n": n})


static func _nearest_crack(wall: V2Wall, pos: Vector2) -> V2Crack:
	var cs := wall.cracks_within(pos, 1.5)
	return cs[0] if not cs.is_empty() else null


## Feet on footholds in [param pose].
static func feet_on(pose: V2Pose) -> int:
	var n := 0
	for f: StringName in [&"lf", &"rf"]:
		if (pose.limb(f) as V2Limb).kind == &"hold":
			n += 1
	return n


## Which demands [param move] misses. [param shift] is how far the move's
## hips are from where the body would put them on its own (the body
## button). Returns the missed demands, each with a "line" (what the
## climber learns from it).
static func misses(move: V2Move, list: Array, shift: Vector2) -> Array:
	var out: Array = []
	var th := CruxTuning.SHIFT_M
	for d: Dictionary in list:
		var miss := false
		var line := ""
		match str(d.id):
			"hand":
				miss = String(move.hand) != str(d.want)
				line = "Crossed up. That hold faces your %s hand." % ("right" if d.want == "rh" else "left")
			"hip":
				var x := int(d.get("x", 0))
				var y := int(d.get("y", 0))
				if x != 0 and shift.x * x < th:
					miss = true
					line = "Square to it, and you barn-door. Lean your hips %s." % ("right" if x > 0 else "left")
				elif y < 0 and shift.y > -th:
					miss = true
					line = "Hips too high. Sink low under it."
				elif y > 0 and shift.y < th:
					miss = true
					line = "Stand up on it: hips up over your feet."
			"foot":
				miss = feet_on(move.to) < int(d.n)
				line = "A foot skated off the smear. That move wants %s." % ("a foothold" if int(d.n) == 1 else "both feet on")
			"beta":
				var st: Dictionary = d.step
				if st.has("hand") and String(move.hand) != str(st.hand):
					miss = true
				var hip := str(st.get("hip", ""))
				if hip == "low" and shift.y > -th or hip == "high" and shift.y < th \
						or hip == "left" and shift.x > -th or hip == "right" and shift.x < th:
					miss = true
				if st.has("feet") and feet_on(move.to) < int(st.feet):
					miss = true
				line = "Not the beta. %s" % str(st.get("say", "The guidebook does it another way."))
		if miss:
			var m := d.duplicate()
			m["line"] = line
			out.append(m)
	return out
