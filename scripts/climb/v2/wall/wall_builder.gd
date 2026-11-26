class_name WallBuilder
extends RefCounted
## Turns one pitch plan (WallPlan) into a V2Wall: the holds along the line,
## the cracks with their widths and constrictions, bolts, old pins, rests,
## ledges, crux zones and the anchor. Everything is deterministic: the route
## and pitch pick the random numbers, so a route is the same rock every time
## you climb it (you can learn it, and mentors can tell you about it).
##
## Hold placement follows the plan's line. Hands alternate either side of it,
## an arm's spacing apart; feet sit between them. Where a crack runs beside
## the line the hand holds are jams in it, sized by the crack's width. Crux
## bands are laid out from their hand sequence: a hold for the left hand sits
## left of the line, two moves in a row with one hand step up the same side,
## so the sequence is something you can read in the rock.

## Hand-hold spacing along the line by style, metres (harder pitches a bit more).
const STEP := {"slab": 0.48, "crack": 0.5, "flake": 0.5, "chimney": 0.45, "roof": 0.55,
	"dike": 0.5, "knobs": 0.5, "face": 0.52, "snow": 0.5, "ice": 0.5}
## Hold kinds by style, with weights.
const KINDS := {
	"slab": {"edge": 4, "crimp": 2, "sloper": 3, "pocket": 1},
	"crack": {"edge": 3, "sidepull": 2, "crimp": 1, "jug": 1},
	"flake": {"sidepull": 4, "edge": 2, "jug": 1},
	"chimney": {"edge": 3, "sidepull": 2, "gaston": 2},
	"roof": {"undercling": 3, "jug": 1, "pinch": 1},
	"dike": {"edge": 3, "jug": 1, "pinch": 2},
	"knobs": {"horn": 3, "pinch": 2, "jug": 1, "edge": 1},
	"face": {"edge": 3, "crimp": 2, "jug": 1, "pinch": 1, "sidepull": 1},
	"snow": {"edge": 1},
	"ice": {"edge": 1},
}
## What a crux band's holds become, by style.
const CRUX_KINDS := {
	"slab": ["sloper", "crimp", "edge"], "crack": ["crimp", "pinch", "gaston"],
	"flake": ["sidepull", "crimp"], "chimney": ["gaston", "sidepull"], "roof": ["undercling", "pinch"],
	"dike": ["crimp", "edge"], "knobs": ["pinch", "edge"], "face": ["crimp", "sloper", "pinch"],
	"snow": ["edge"], "ice": ["edge"],
}
## Metres of line between shake-out jugs on an easy pitch; each grade of
## difficulty adds 0.6.
const SHAKEOUT_GAP := 2.2
## Most holds the gap bridger may add to a pitch.
const MAX_BRIDGES := 40
## Longest step between crux holds along the line, metres.
const CRUX_STEP := 0.6
## How far from the line a crack can be and still be what the hands climb.
const JAM_REACH := 0.75
## Space left above the top hold for the anchor; the wall's margin.
const TOP_MARGIN := 1.5


## Builds the wall for one pitch plan.
static func build(plan: Dictionary, route_id: String, pitch: int) -> V2Wall:
	var b := _Build.new(plan, route_id, pitch)
	return b.run()


class _Build:
	var plan: Dictionary
	var w := V2Wall.new()
	var rng := RandomNumberGenerator.new()
	var line: Array[Vector2] = []
	var height := 16.0
	var diff := 2
	var cruxes: Array = []
	var n_hand := 0
	var n_foot := 0

	func _init(p_plan: Dictionary, route_id: String, pitch: int) -> void:
		plan = p_plan
		w.route_id = route_id
		w.pitch = pitch
		rng.seed = hash("%s:%d" % [route_id, pitch])

	func run() -> V2Wall:
		height = float(plan.get("height", 16.0))
		diff = int(plan.get("diff", 2))
		var width := float(plan.get("width", 8.0))
		w.size = Vector2(width, height + TOP_MARGIN)
		w.style = StringName(str(plan.get("style", "face")))
		w.rock = str(plan.get("rock", ""))
		w.angle = float(plan.get("angle", 0.0))
		for pt: Variant in plan.get("line", [[width * 0.5, 0.0], [width * 0.5, height]]):
			line.append(V2Data.vec(pt))
		w.start = Vector2(line[0].x, 0.0)
		w.top = Vector2(line[line.size() - 1].x, height)
		cruxes = plan.get("cruxes", [])
		_info()
		_cracks()
		_line_holds()
		_crux_holds()
		_rests()
		_ledges()
		_horns()
		_extra_holds()
		_top()
		_fixed()
		_zones()
		_dedupe()
		_bridge_gaps()
		return w

	## Where the generated line leaves a move the body can't make (a crack
	## snapped two holds together, a crux ends awkwardly), adds a hold
	## further along the line, until WallCheck finds a way to the top.
	func _bridge_gaps() -> void:
		var along := func(p: Vector2) -> float: return _project(p)
		for i in MAX_BRIDGES:
			# The free way must go too (a body that can't swing yet climbs it).
			var found := WallCheck.search(w, along, false)
			if found.has("path"):
				return
			var best: V2Hold = found.get("best")
			var d := (_project(best.pos) if best else 1.4) + 0.5
			var at := _at(minf(d, _length()))
			var pos: Vector2 = at[0]
			if pos.y > height - 0.3:
				pos = w.top - Vector2(0, 0.5)
			var h := _make_hand(pos + Vector2(0.18 if i % 2 == 0 else -0.18, 0), style_at(pos.y), 1.0, false)
			h.id = "b%d" % i
			var swing := _swing_at(_project(pos))
			if not swing.is_empty():
				# Part of the free way round a swing: tiny, as the rest of it.
				h.kind = &"crimp"
				h.size = 0.1
				h.tags = PackedStringArray(["crux:" + str(swing.get("id", "")), "free_variation"])
			w.holds.append(h)

	## The crux's kind for the crux system: dyno, layback, mantel, slab or
	## roof (from "kind", else from its hip and the rock), or "".
	func crux_kind(c: Dictionary) -> String:
		if c.has("kind"):
			return str(c.kind)
		match str(c.get("hip", "")):
			"lunge":
				return "dyno"
			"layback":
				return "layback"
			"mantel":
				return "mantel"
			"undercling", "heel":
				return "roof"
		var style := style_at(_at(_crux_span(c).x)[0].y)
		if style == "slab" or str(c.get("hip", "")) == "smear":
			return "slab"
		if style == "roof":
			return "roof"
		return ""

	## The crux's special: swing (a pendulum too), nail (an aid crux),
	## chimney or offwidth (from its hip), or "".
	func crux_special(c: Dictionary) -> String:
		var special := str(c.get("special", ""))
		if special == "pendulum":
			return "swing"
		if special != "":
			return special
		if c.get("aid", false):
			return "nail"
		if str(c.get("hip", "")) in ["chimney", "offwidth"]:
			return str(c.hip)
		return ""

	## The swing crux whose stretch covers distance [param d], or {}.
	func _swing_at(d: float) -> Dictionary:
		for c: Dictionary in cruxes:
			var span := _crux_span(c)
			if crux_special(c) == "swing" and d >= span.x and d <= span.y:
				return c
		return {}

	## Distance along the line of the point on it nearest [param p].
	func _project(p: Vector2) -> float:
		var run := 0.0
		var best := 0.0
		var best_dist := INF
		for i in line.size() - 1:
			var a := line[i]
			var b := line[i + 1]
			var seg := a.distance_to(b)
			var f := 0.0 if seg <= 0.0 else clampf((p - a).dot(b - a) / (seg * seg), 0.0, 1.0)
			var dist := p.distance_to(a.lerp(b, f))
			if dist < best_dist:
				best_dist = dist
				best = run + seg * f
			run += seg
		return best

	## Drops generated hand holds that landed on top of another hold (two
	## jams snapped to one spot, a line hold under a crux exit). Authored,
	## crux, rest and ledge holds always stay.
	func _dedupe() -> void:
		var kept: Array[V2Hold] = []
		var keep := func(h: V2Hold) -> bool:
			return not (h.id.begins_with("h") or h.id.begins_with("o")) or not h.hand
		for h in w.holds:
			if keep.call(h):
				kept.append(h)
		for h in w.holds:
			if keep.call(h):
				continue
			var clash := false
			for k in kept:
				if k.hand and k.pos.distance_to(h.pos) < 0.15:
					clash = true
					break
			if not clash:
				kept.append(h)
		# Keep the original order (ids stay stable; views draw in order).
		var order := {}
		for i in w.holds.size():
			order[w.holds[i]] = i
		kept.sort_custom(func(a: V2Hold, b: V2Hold) -> bool: return order[a] < order[b])
		w.holds = kept

	# --- Info -------------------------------------------------------------

	func _info() -> void:
		var info := {"name": plan.get("name", ""), "beta": plan.get("beta", ""), "diff": float(diff),
			"belay": plan.get("belay", "ledge"), "height": height}
		for key in ["grade", "bivy", "fixed_rope", "aid", "sections", "top_rope", "boulder", "runout",
				"unprotected", "read", "mentor", "real"]:
			if plan.has(key):
				info[key] = plan[key]
		w.info = info

	# --- Cracks -----------------------------------------------------------

	func _cracks() -> void:
		for c: Dictionary in plan.get("cracks", []):
			w.cracks.append(V2Crack.from_dict(c))
		# A flake is a crack with an edge you layback on.
		for f: Dictionary in plan.get("flakes", []):
			var d := f.duplicate(true)
			d["kind"] = "flake"
			var tags: Array = d.get("tags", [])
			tags.append("flake")
			tags.append("side:" + str(f.get("side", "right")))
			d["tags"] = tags
			if not d.has("constrictions"):
				d["constrictions"] = WallPlan._constrictions(d.get("widths", []))
			w.cracks.append(V2Crack.from_dict(d))

	## The crack the hands follow near [param pos], or null.
	func _crack_near(pos: Vector2) -> V2Crack:
		var best: V2Crack = null
		var best_d := JAM_REACH
		for c in w.cracks:
			if c.tags.has("no_jams"):
				continue
			var near := c.nearest(pos)
			var top := c.points[c.points.size() - 1].y
			var bottom := c.points[0].y
			if pos.y < bottom - 0.2 or pos.y > top + 0.2:
				continue
			if float(near.distance) < best_d:
				best = c
				best_d = float(near.distance)
		return best

	# --- The line ---------------------------------------------------------

	func _length() -> float:
		var total := 0.0
		for i in line.size() - 1:
			total += line[i].distance_to(line[i + 1])
		return total

	## Point and unit direction at distance [param d] along the line.
	func _at(d: float) -> Array:
		var run := 0.0
		for i in line.size() - 1:
			var seg := line[i].distance_to(line[i + 1])
			if d <= run + seg or i == line.size() - 2:
				var f := 0.0 if seg <= 0.0 else clampf((d - run) / seg, 0.0, 1.0)
				return [line[i].lerp(line[i + 1], f), (line[i + 1] - line[i]).normalized()]
			run += seg
		return [line[line.size() - 1], Vector2.UP]

	func style_at(y: float) -> String:
		for s: Dictionary in plan.get("sections", []):
			if y >= float(s.get("from", 0.0)) and y < float(s.get("to", 0.0)) and s.has("style"):
				return str(s["style"])
		return String(w.style)

	## The crux whose stretch of line covers distance [param d], or {}.
	func _in_crux(d: float) -> Dictionary:
		for c: Dictionary in cruxes:
			var span := _crux_span(c)
			if d >= span.x - 0.1 and d <= span.y + 0.1:
				return c
		return {}

	## A crux's stretch of the line as distances along it: its "d0"/"d1" if
	## given (for roofs and traverses), else where the line crosses its
	## "from"/"to" heights.
	func _crux_span(c: Dictionary) -> Vector2:
		if c.has("d0"):
			return Vector2(float(c.d0), float(c.get("d1", float(c.d0) + 2.0)))
		var y0 := float(c.get("from", 0.0))
		return Vector2(_d_at_y(y0), _d_at_y(float(c.get("to", y0 + 2.0))))

	func _pick(table: Dictionary) -> String:
		var total := 0
		for k: String in table:
			total += int(table[k])
		var r := rng.randi_range(1, total)
		for k: String in table:
			r -= int(table[k])
			if r <= 0:
				return k
		return table.keys()[0]

	## Lays hand holds, option holds and feet up the line, outside crux bands.
	func _line_holds() -> void:
		var total := _length()
		var d := 1.45
		var side := -1.0
		var last_y := -1.0
		var last_rest_y := 0.0
		while d < total:
			var at := _at(d)
			var pos: Vector2 = at[0]
			var dir: Vector2 = at[1]
			if pos.y > height - 0.45:
				break
			var style := style_at(pos.y)
			var step := float(STEP.get(style, 0.5)) + 0.025 * diff + rng.randf_range(-0.04, 0.04)
			if not _in_crux(d).is_empty():
				d += step
				continue
			var normal := Vector2(dir.y, -dir.x) if dir.y >= 0.0 else Vector2(-dir.y, dir.x)
			if normal.x < 0.0:
				normal = -normal
			var off := 0.3 + rng.randf_range(0.0, 0.12)
			var hp := pos + normal * side * off
			var made := _hand_at(hp, style, side)
			# A shake-out every few metres (further apart on harder
			# pitches): a jug or a big flake edge to hang off and rest.
			if pos.y - last_rest_y >= SHAKEOUT_GAP + 0.6 * diff and not made.has_tag("roof"):
				made.kind = &"horn" if style == "knobs" else &"jug"
				made.size = 0.9
				made.crack_id = ""
				made.pull = Vector2(0, -1)
				made.tags.append("shakeout")
				last_rest_y = pos.y
			elif made.kind in [&"jug", &"horn", &"stance"]:
				last_rest_y = pos.y
			# An option further out on the same side every few moves: another
			# way to go, wider and often better or worse than the line's hold.
			if rng.randf() < 0.45:
				var op := pos + normal * side * rng.randf_range(0.8, 1.0) + dir * rng.randf_range(0.05, 0.3)
				if op.x > 0.3 and op.x < w.size.x - 0.3 and not _crowded(op, 0.3):
					var oh := _make_hand(op, style, side, false)
					oh.id = "o%d" % n_hand
					oh.tags.append("option")
					w.holds.append(oh)
			# A foot between this hand and the last.
			var fp := pos + normal * side * -0.15 + Vector2(0, -0.25)
			if fp.y > 0.2:
				_foot_at(fp, style)
			last_y = pos.y
			side = -side
			d += step
		# Feet up from the ground to the first hands.
		for y: float in [0.35, 0.8]:
			_foot_at(Vector2(w.start.x + (-0.25 if y < 0.5 else 0.25), y), style_at(y))

	func _hand_at(pos: Vector2, style: String, side: float) -> V2Hold:
		var h := _make_hand(pos, style, side)
		w.holds.append(h)
		return h

	## True if a hand hold is already within [param r] of [param pos].
	func _crowded(pos: Vector2, r: float) -> bool:
		for h in w.holds:
			if h.hand and h.pos.distance_to(pos) < r:
				return true
		return false

	func _make_hand(pos: Vector2, style: String, side: float, jams := true) -> V2Hold:
		var h := V2Hold.new()
		h.id = "h%d" % n_hand
		n_hand += 1
		h.pos = _round(pos)
		var crack := _crack_near(pos) if jams and style in ["crack", "flake", "chimney", "roof"] else null
		if crack and rng.randf() < 0.85:
			var near := crack.nearest(pos)
			h.pos = _round(near.pos)
			h.kind = &"jam"
			h.crack_id = crack.id
			h.size = _jam_size(float(near.width))
			if crack.kind == &"flake" or crack.tags.has("flake"):
				# Layback the flake: pull sideways off its edge.
				h.kind = &"sidepull"
				var flake_side := -1.0 if crack.tags.has("side:left") else 1.0
				h.pull = Vector2(flake_side, -0.3).normalized()
				h.size = clampf(_jam_size(float(near.width)) + 0.05, 0.2, 0.9)
				h.tags.append("layback")
			if float(near.width) >= 6.5:
				h.tags.append("offwidth")
			if style == "roof":
				h.tags.append("roof")
		else:
			h.kind = StringName(_pick(KINDS.get(style, KINDS.face)))
			h.size = _size_for(h.kind)
			h.pull = _pull_for(h.kind, side)
			if style == "chimney":
				h.tags.append("chimney")
			elif style == "roof":
				h.tags.append("roof")
			elif style == "snow" or style == "ice":
				h.tags.append("axe")
				h.size = 0.7 if style == "snow" else 0.55
			if h.kind == &"horn":
				h.tags.append("slingable")
		return h

	func _foot_at(pos: Vector2, style: String) -> void:
		var f := V2Hold.new()
		f.id = "f%d" % n_foot
		n_foot += 1
		f.pos = _round(pos)
		f.hand = false
		f.kind = &"edge"
		f.size = clampf(0.55 - 0.05 * diff + rng.randf_range(-0.08, 0.08), 0.15, 0.7)
		match style:
			"slab":
				f.tags.append("smear")
				f.size = clampf(f.size - 0.1, 0.1, 0.5)
			"chimney":
				f.tags.append("chimney")
			"roof":
				f.tags.append("heel" if rng.randf() < 0.5 else "toe")
			"snow":
				f.kind = &"stance"
				f.tags.append("step")
				f.size = 0.6
			"ice":
				f.tags.append("frontpoint")
			"knobs", "dike":
				f.size = clampf(f.size + 0.15, 0.2, 0.8)
		var crack := _crack_near(pos)
		if crack and style in ["crack", "chimney"] and rng.randf() < 0.5:
			f.pos = _round(crack.nearest(pos).pos)
			f.kind = &"jam"
			f.crack_id = crack.id
		w.holds.append(f)

	func _jam_size(width: float) -> float:
		# Hands (#0.75-#2) are the best jams; thin fingers and offwidth the worst.
		if width < 0.75:
			return 0.3
		if width < 2.5:
			return 0.5
		if width < 5.5:
			return 0.8
		if width < 6.5:
			return 0.6
		return 0.35

	func _size_for(kind: StringName) -> float:
		var base := {&"jug": 0.95, &"edge": 0.6, &"crimp": 0.35, &"sloper": 0.45, &"pinch": 0.5,
			&"pocket": 0.5, &"undercling": 0.6, &"sidepull": 0.6, &"gaston": 0.5, &"horn": 0.8}
		var s: float = base.get(kind, 0.55)
		return clampf(snappedf(s - 0.04 * (diff - 2) + rng.randf_range(-0.07, 0.07), 0.01), 0.1, 1.0)

	func _pull_for(kind: StringName, side: float) -> Vector2:
		match kind:
			&"sidepull":
				return Vector2(side, -0.25).normalized()
			&"gaston":
				return Vector2(-side, -0.2).normalized()
			&"undercling":
				return Vector2(0, 1)
		return Vector2(0, -1)

	func _round(v: Vector2) -> Vector2:
		return Vector2(snappedf(v.x, 0.01), snappedf(v.y, 0.01))

	# --- Cruxes -----------------------------------------------------------

	## Crux bands: holds placed from the hand sequence, worse than the rest,
	## with a good hold at the exit and one tempting decoy. A swing crux
	## (special "swing" or "pendulum") is a jug to swing from and one to land
	## on, with blank rock between but for a line of tiny holds: the hard
	## free way round.
	func _crux_holds() -> void:
		for c: Dictionary in cruxes:
			var span := _crux_span(c)
			var start: Vector2 = _at(span.x)[0]
			var style := style_at(start.y)
			var cid := str(c.get("id", "crux"))
			var hip := str(c.get("hip", ""))
			var special := crux_special(c)
			var tags := PackedStringArray(["crux:" + cid])
			if hip != "":
				tags.append("hip:" + hip)
			var made: Array[V2Hold] = []
			if special == "swing":
				made.append_array(_swing_holds(c, span, tags))
			elif c.has("holds"):
				var i := 0
				for hd: Dictionary in c.holds:
					var h := V2Hold.from_dict(hd)
					if h.id == "":
						h.id = "%s_%d" % [cid, i]
					h.tags.append_array(tags)
					made.append(h)
					i += 1
			else:
				made.append_array(_sequence_holds(c, span, style, tags))
			if special != "swing":
				# The jug at the exit, so a sent crux feels like one.
				var exit_hold := V2Hold.new()
				exit_hold.id = "%s_exit" % cid
				var exit_at: Vector2 = _at(minf(span.y + 0.45, _length()))[0]
				exit_hold.pos = _round(Vector2(exit_at.x, minf(exit_at.y, height - 0.5)))
				exit_hold.kind = &"jug"
				exit_hold.size = 0.9
				exit_hold.tags = PackedStringArray(["crux_exit"])
				made.append(exit_hold)
				# A special (nailing, a chimney or offwidth to inchworm) starts
				# on the crux's first hold.
				if special != "":
					for h in made:
						if h.hand and not h.has_tag("decoy"):
							h.tags.append("special:" + special)
							break
			# A dyno's target: the hold you jump to.
			if crux_kind(c) == "dyno":
				for i in range(made.size() - 1, -1, -1):
					if made[i].hand and made[i].has_tag("crux:" + cid) and not made[i].has_tag("decoy"):
						made[i].tags.append("dyno")
						break
			w.holds.append_array(made)
			_crux_zone(c, made)

	func _sequence_holds(c: Dictionary, span: Vector2, style: String, tags: PackedStringArray) -> Array[V2Hold]:
		var out: Array[V2Hold] = []
		var cid := str(c.get("id", "crux"))
		var hip := str(c.get("hip", ""))
		var seq: Array = (c.get("sequence", ["rh", "lh", "rh"]) as Array).duplicate()
		# A long crux repeats its sequence so no move is longer than CRUX_STEP
		# (the zone's data gets the whole of it).
		var want := ceili((span.y - span.x) / CRUX_STEP)
		var base := seq.duplicate()
		while seq.size() < want:
			seq.append(base[seq.size() % base.size()])
		c["sequence"] = seq
		var n := maxi(1, seq.size())
		var last_side := 0.0
		var kinds: Array = c.get("kinds", CRUX_KINDS.get(style, CRUX_KINDS.face))
		for i in n:
			var hand := str(seq[i])
			var side := -1.0 if hand == "lh" else 1.0
			var at := _at(lerpf(span.x, span.y, (float(i) + 0.5) / float(n)))
			var on_line: Vector2 = at[0]
			# Left of the line for the left hand (above it on a rightward
			# traverse), right for the right; a second move with the same
			# hand reaches a little further out.
			var left := Vector2(-(at[1] as Vector2).y, (at[1] as Vector2).x)
			if left == Vector2.ZERO:
				left = Vector2.LEFT
			var h := V2Hold.new()
			h.id = "%s_%d" % [cid, i]
			h.pos = _round(on_line - left * side * (0.35 + (0.12 if side == last_side else 0.0)))
			var crack := _crack_near(h.pos) if style in ["crack", "flake", "roof", "chimney"] else null
			var near_crack := crack.nearest(h.pos) if crack else {}
			if crack and i % 2 == 0 and not out.any(func(o: V2Hold) -> bool: return o.pos.distance_to(near_crack.pos) < 0.2):
				var near := near_crack
				h.pos = _round(near.pos)
				h.kind = &"jam"
				h.crack_id = crack.id
				h.size = clampf(_jam_size(float(near.width)) - 0.25, 0.15, 0.6)
			else:
				h.kind = StringName(kinds[i % kinds.size()])
				h.size = clampf(_size_for(h.kind) * 0.6, 0.12, 0.5)
				h.pull = _pull_for(h.kind, side)
			h.foot = false
			h.tags = tags.duplicate()
			h.tags.append("seq:%d:%s" % [i, hand])
			out.append(h)
			last_side = side
		# One tempting hold on the wrong side: big-looking, badly placed.
		var mid: Vector2 = _at(lerpf(span.x, span.y, 0.55))[0]
		var decoy := V2Hold.new()
		decoy.id = "%s_decoy" % cid
		decoy.pos = _round(Vector2(clampf(mid.x - (1.0 if str(seq[0]) == "rh" else -1.0) * 0.95, 0.3, w.size.x - 0.3), mid.y))
		decoy.kind = &"sloper"
		decoy.size = 0.4
		decoy.foot = false
		decoy.tags = tags.duplicate()
		decoy.tags.append("decoy")
		out.append(decoy)
		# Feet through the band: small, so the hips matter.
		var d := span.x
		var k := 0
		while d < span.y:
			var fp: Vector2 = _at(d)[0]
			var f := V2Hold.new()
			f.id = "%s_f%d" % [cid, k]
			f.pos = _round(fp + Vector2(rng.randf_range(-0.25, 0.25), -0.3))
			f.hand = false
			f.size = clampf(0.3 - 0.03 * diff, 0.1, 0.4)
			f.tags = tags.duplicate()
			if hip in ["flag", "drop_knee", "heel", "stem", "kneebar", "smear", "high_step"]:
				f.tags.append(hip)
			out.append(f)
			d += 0.55
			k += 1
		return out

	func _swing_holds(c: Dictionary, span: Vector2, tags: PackedStringArray) -> Array[V2Hold]:
		var out: Array[V2Hold] = []
		var cid := str(c.get("id", "crux"))
		var special := "swing"
		var from := V2Hold.new()
		from.id = "%s_from" % cid
		from.pos = _round(_at(span.x)[0])
		from.kind = &"jug"
		from.size = 0.9
		from.tags = tags.duplicate()
		from.tags.append("special:" + special)
		from.tags.append("swing_from")
		out.append(from)
		var to := V2Hold.new()
		to.id = "%s_to" % cid
		to.pos = _round(_at(span.y)[0])
		to.kind = &"jam" if _crack_near(to.pos) else &"edge"
		var crack := _crack_near(to.pos)
		if crack:
			to.pos = _round(crack.nearest(to.pos).pos)
			to.crack_id = crack.id
		to.size = 0.7
		to.tags = tags.duplicate()
		to.tags.append("swing_to")
		out.append(to)
		# The free way round: tiny holds a long way apart, under the swing.
		var d := span.x + 0.9
		var k := 0
		while d < span.y - 0.6:
			var h := V2Hold.new()
			h.id = "%s_free%d" % [cid, k]
			h.pos = _round(_at(d)[0] + Vector2(0, -0.6 + 0.2 * (k % 2)))
			h.kind = &"crimp"
			h.size = 0.1
			h.tags = tags.duplicate()
			h.tags.append("free_variation")
			out.append(h)
			d += 0.9
			k += 1
		return out

	## The crux's zone: the box round its holds, with its puzzle as data.
	func _crux_zone(c: Dictionary, made: Array[V2Hold]) -> void:
		var z := V2Zone.new()
		z.id = str(c.get("id", "crux"))
		z.kind = &"crux"
		var box := Rect2(made[0].pos, Vector2.ZERO) if not made.is_empty() else Rect2(_at(_crux_span(c).x)[0], Vector2.ZERO)
		for h in made:
			if h.has_tag("crux_exit"):
				continue
			box = box.expand(h.pos)
		z.rect = box.grow(0.3)
		# The crux system's format (cruxes/CRUXES.md, "Wall data"): name,
		# beta, kind, special, sequence, target; plus hip, read, aid here.
		var data := {"name": c.get("name", "The crux"), "sequence": c.get("sequence", [])}
		for key in ["hip", "beta", "aid", "grade", "read", "lip", "lip_size"]:
			if c.has(key):
				data[key] = c[key]
		if not data.has("beta") and c.has("read"):
			data["beta"] = c["read"]
		var kind := crux_kind(c)
		if kind != "":
			data["kind"] = kind
		var special := crux_special(c)
		if special != "":
			data["special"] = special
		if special == "swing":
			data["from"] = "%s_from" % z.id
			data["to"] = "%s_to" % z.id
			var to := made.filter(func(h: V2Hold) -> bool: return h.has_tag("swing_to"))
			if not to.is_empty():
				data["target"] = [to[0].pos.x, to[0].pos.y]
			data.erase("sequence")
		z.data = data
		w.zones.append(z)

	## Distance along the line where it first reaches height [param y].
	func _d_at_y(y: float) -> float:
		var run := 0.0
		for i in line.size() - 1:
			var a := line[i]
			var b := line[i + 1]
			var seg := a.distance_to(b)
			if y <= maxf(a.y, b.y) and absf(b.y - a.y) > 0.001:
				return run + seg * clampf((y - a.y) / (b.y - a.y), 0.0, 1.0)
			run += seg
		return run

	func _line_arr() -> Array:
		var out := []
		for p in line:
			out.append([p.x, p.y])
		return out

	# --- Rests, ledges, horns, extras ------------------------------------------

	func _rests() -> void:
		var i := 0
		for r: Dictionary in plan.get("rests", []):
			var y := float(r.get("y", 0.0))
			var x := float(r.get("x", WallPlan.line_x(_line_arr(), y)))
			var stance := V2Hold.new()
			stance.id = "rest%d" % i
			stance.pos = _round(Vector2(x, y))
			stance.kind = StringName(str(r.get("kind", "stance")))
			stance.size = 1.0
			stance.tags = PackedStringArray(["rest"])
			w.holds.append(stance)
			var jug := V2Hold.new()
			jug.id = "rest%d_jug" % i
			jug.pos = _round(Vector2(x + 0.3, y + 1.3))
			jug.kind = &"jug"
			jug.size = 0.95
			jug.tags = PackedStringArray(["rest"])
			w.holds.append(jug)
			var z := V2Zone.new()
			z.id = "rest%d" % i
			z.kind = &"rest"
			z.rect = Rect2(x - 1.2, y - 0.3, 2.4, 2.4)
			z.data = {"kind": str(r.get("kind", "stance")), "name": r.get("name", "")}
			w.zones.append(z)
			i += 1

	func _ledges() -> void:
		var i := 0
		for l: Dictionary in plan.get("ledges", []):
			var y := float(l.get("y", 0.0))
			var x0 := float(l.get("x0", WallPlan.line_x(_line_arr(), y) - 1.5))
			var x1 := float(l.get("x1", WallPlan.line_x(_line_arr(), y) + 1.5))
			var z := V2Zone.new()
			z.id = "ledge%d" % i
			z.kind = &"ledge"
			z.rect = Rect2(x0, y - 0.2, x1 - x0, 2.2)
			z.data = {"name": l.get("name", ""), "bivy": l.get("bivy", false)}
			w.zones.append(z)
			var x := x0 + 0.4
			var k := 0
			while x < x1:
				var s := V2Hold.new()
				s.id = "ledge%d_%d" % [i, k]
				s.pos = _round(Vector2(x, y))
				s.kind = &"stance"
				s.size = 1.0
				s.tags = PackedStringArray(["ledge"])
				w.holds.append(s)
				x += 0.8
				k += 1
			i += 1

	func _horns() -> void:
		var i := 0
		for entry: Variant in plan.get("horns", []):
			# A height, or {"y", "x"?, "tags"?} (e.g. tags ["chockstone"]).
			var hd: Dictionary = entry if entry is Dictionary else {"y": entry}
			var y := float(hd.get("y", 0.0))
			var h := V2Hold.new()
			h.id = "horn%d" % i
			h.pos = _round(Vector2(float(hd.get("x", WallPlan.line_x(_line_arr(), y) + (0.55 if i % 2 == 0 else -0.55))), y))
			h.kind = &"horn"
			h.size = 0.85
			h.tags = PackedStringArray(["slingable"])
			h.tags.append_array(PackedStringArray(hd.get("tags", [])))
			w.holds.append(h)
			i += 1

	func _extra_holds() -> void:
		var i := 0
		for hd: Dictionary in plan.get("holds", []):
			var h := V2Hold.from_dict(hd)
			if h.id == "":
				h.id = "x%d" % i
			w.holds.append(h)
			i += 1

	# --- The top and the fixed gear ----------------------------------------

	func _top() -> void:
		var top := V2Hold.new()
		top.id = "anchor_hold"
		top.pos = w.top
		top.kind = &"jug"
		top.size = 1.0
		top.tags = PackedStringArray(["anchor"])
		w.holds.append(top)
		if not plan.get("boulder", false):
			var anchor := V2Piece.new()
			anchor.id = "anchor"
			anchor.kind = &"anchor"
			anchor.pos = w.top + Vector2(0, 0.3)
			anchor.fixed = true
			var belay := str(plan.get("belay", "ledge"))
			anchor.tags = PackedStringArray([belay])
			w.fixed.append(anchor)
			if belay == "ledge" or belay == "tree" or belay == "top":
				var z := V2Zone.new()
				z.id = "belay_ledge"
				z.kind = &"ledge"
				z.rect = Rect2(w.top.x - 1.5, height - 0.3, 3.0, TOP_MARGIN + 0.3)
				z.data = {"belay": belay}
				w.zones.append(z)

	func _fixed() -> void:
		if plan.get("boulder", false):
			return
		var k := 0
		for y: float in plan.get("bolts", []):
			var p := V2Piece.new()
			p.id = "bolt%d" % k
			p.kind = &"bolt"
			p.pos = _round(Vector2(WallPlan.line_x(_line_arr(), y) + 0.25, y))
			p.fixed = true
			w.fixed.append(p)
			k += 1
		k = 0
		for pin: Dictionary in plan.get("pins", []):
			var y := float(pin.get("y", 0.0))
			var p := V2Piece.new()
			p.id = "pin%d" % k
			p.kind = StringName(str(pin.get("kind", "pin")))
			p.pos = _round(Vector2(float(pin.get("x", WallPlan.line_x(_line_arr(), y) - 0.3)), y))
			p.fixed = true
			p.quality = float(pin.get("quality", 0.7 if p.kind == &"pin" else 1.0))
			p.tags = PackedStringArray(pin.get("tags", []))
			w.fixed.append(p)
			k += 1

	func _zones() -> void:
		var i := 0
		for zd: Dictionary in plan.get("zones", []):
			var z := V2Zone.from_dict(zd)
			if z.id == "":
				z.id = "%s%d" % [z.kind, i]
			w.zones.append(z)
			i += 1
