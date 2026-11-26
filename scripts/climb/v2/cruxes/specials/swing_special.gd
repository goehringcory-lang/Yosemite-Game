class_name SwingSpecial
extends CruxSpecial
## The King Swing (and every pendulum): lowered out on the rope from a piece,
## you run back and forth across the wall to swing wider, then grab the far
## crack at the top of a swing.
##
## Played in steps, no clock. First the big decision: how far to lower out.
## More rope reaches the crack with less running, but lands you lower on it
## (more to climb back up). Then each swing you pick where to kick off from:
## spots drawn on the rock (a good edge, a dirty patch, a polished streak, a
## wet stripe) that push you hard or let your feet skate. The ghost shows
## where the next swing would peak. Every swing loses reach and your legs
## tire, so there are only a handful of good swings in you. At a peak in
## reach of the crack you aim at a hold there and grab it; a peak far past
## it slams you into the corner.

const T = preload("res://scripts/climb/v2/cruxes/crux_tuning.gd")


func start() -> void:
	var s := session()
	var w := s.wall
	var pivot := s.pose.tie_in() + Vector2(0, 1.2)
	var data: Dictionary = spot.get("data", {})
	var side := -1.0 if pivot.x > w.size.x * 0.5 else 1.0
	var target: Vector2
	var free_grab := false
	# The far crack: the hand hold furthest across, below the pivot (cracks
	# win ties), unless the wall names the target.
	var best: V2Hold = null
	var best_score := 0.0
	for h in w.holds:
		if not h.hand or h.pos.y > pivot.y - 0.5 or h.pos.y < pivot.y - 6.0 or h.has_tag("anchor"):
			continue
		var score := absf(h.pos.x - pivot.x) + (0.4 if h.kind == &"jam" or h.crack_id != "" else 0.0)
		if score > best_score:
			best_score = score
			best = h
	if data.has("target"):
		target = V2Data.vec(data.target)
	elif best != null and absf(best.pos.x - pivot.x) >= 0.8:
		target = best.pos
	else:
		var far_x := clampf(pivot.x + side * maxf(w.size.x * 0.6, 2.4), 0.4, w.size.x - 0.4)
		target = Vector2(far_x, pivot.y - 1.5)
		free_grab = true
	side = signf(target.x - pivot.x) if target.x != pivot.x else side
	var d := absf(target.x - pivot.x)
	# The least rope that reaches: the crack at 60 degrees out.
	var base := maxf(d / sin(deg_to_rad(60.0)), 1.5)
	# The rope lengths worth lowering out: each one puts a hold on the far
	# crack right on the arc (the rope as long as the hold is far away).
	var ropes: Array = []
	if not free_grab:
		var line: Array[float] = []
		for h in w.holds:
			if h.hand and absf(h.pos.x - target.x) < 0.6 and h.pos.y < pivot.y - 0.3 and h.pos.y > pivot.y - 9.0:
				var r := h.pos.distance_to(pivot)
				if r >= d * 1.02:
					line.append(r)
		line.sort()
		for r in line:
			if ropes.is_empty() or r - float(ropes.back()) >= 0.6:
				ropes.append(r)
		if ropes.size() > 3:
			ropes = [ropes[0], ropes[ropes.size() / 2], ropes.back()]
	if ropes.is_empty():
		for extra: float in T.SWING_LOWER_OPTIONS:
			ropes.append(base + extra)
	state = {"stage": "lower", "pivot": V2Data.arr(pivot), "side": side, "d": d, "target_y": target.y,
		"base": base, "rope": float(ropes[0]), "ropes": ropes, "peak": 0.0, "free_grab": free_grab, "target": V2Data.arr(target),
		"kicks": 0, "slams": 0, "misses": 0, "spots": []}


## Where you can kick off: footholds on the near side under the pivot, or
## features drawn from the pitch when there are none.
func _kick_spots(pivot: Vector2, side: float, r: float) -> Array:
	var w := session().wall
	var out: Array = []
	for h in w.holds:
		if not h.foot or h.hand and h.kind == &"jug":
			continue
		var dx := (h.pos.x - pivot.x) * side
		var far := h.pos.distance_to(pivot)
		if dx > 0.3 or dx < -3.0 or far < r - 1.0 or far > r + 0.3:
			continue
		var footing := "edge"
		if h.has_tag("polished"):
			footing = "polished"
		elif h.size < 0.35:
			footing = "dirty"
		elif h.kind == &"edge" and h.size > 0.7:
			footing = "flake"
		if not w.zones_at(h.pos, &"wet").is_empty():
			footing = "wet"
		out.append({"id": h.id, "pos": V2Data.arr(h.pos), "footing": footing})
		if out.size() >= 4:
			break
	if out.size() < 3:
		var kinds := ["edge", "polished", "dirty", "crystal", "wet"]
		var i := out.size()
		while out.size() < 3:
			var f: String = kinds[int(noise("kick%d" % i) * kinds.size()) % kinds.size()]
			if i == 0 and f in ["wet", "polished"]:
				f = "edge"
			var ang := (0.15 + 0.22 * i) * -side
			out.append({"id": "kick%d" % i, "pos": V2Data.arr(pivot + Vector2(sin(ang), -cos(ang)) * (r - 0.4)), "footing": f})
			i += 1
	return out


func title() -> String:
	return str(spot.get("name", "The pendulum"))


func rope_options() -> Array:
	var out: Array = []
	for r: float in state.ropes:
		out.append({"id": "lower", "rope": r, "label": "Lower out %.0f m and swing" % r})
	return out


## Holds within grab reach of the current peak on the crack side.
func grab_holds(peak: float) -> Array:
	var p := peak_pos(peak)
	var out: Array = []
	for h in session().wall.holds_within(p, T.SWING_GRAB_M):
		out.append(h.id)
	return out


## Where a swing that reaches [param peak] metres out tops out (wall metres).
func peak_pos(peak: float) -> Vector2:
	var pivot := V2Data.vec(state.pivot)
	var r := float(state.rope)
	var x := minf(peak, r * 0.98)
	return pivot + Vector2(float(state.side) * x, -sqrt(maxf(r * r - x * x, 0.0)))


## The peak the next swing reaches when you kick off a spot of [param footing].
func next_peak(footing: String) -> float:
	var q: float = T.FOOTING.get(footing, 0.6)
	var stretch := sqrt(float(state.rope) / float(state.base))
	var kick := T.SWING_KICK_M * q * pow(T.SWING_TIRE, int(state.kicks)) * stretch
	return float(state.peak) * T.SWING_DECAY + kick


func in_reach(peak: float) -> bool:
	var d := float(state.d)
	return peak >= d - T.SWING_GRAB_M and peak <= d + T.SWING_SLAM_M and (bool(state.free_grab) or not grab_holds(peak).is_empty())


func options() -> Array:
	if state.stage == "lower":
		return rope_options()
	var out: Array = []
	if in_reach(float(state.peak)):
		var ids := grab_holds(float(state.peak))
		if ids.is_empty():
			ids = [""]
		for id: String in ids:
			out.append({"id": "grab", "hold": id, "label": "Grab the crack"})
	for s: Dictionary in state.spots:
		out.append({"id": "kick", "spot": s.id, "footing": s.footing, "label": "Kick off the %s" % _footing_name(str(s.footing))})
	return out


static func _footing_name(f: String) -> String:
	return {"edge": "edge", "flake": "flake", "crystal": "crystals", "dirty": "dirty patch", "polished": "polished streak", "wet": "wet stripe"}.get(f, f)


func preview(option: Dictionary) -> Dictionary:
	match str(option.id):
		"lower":
			var keep := float(state.rope)
			state.rope = float(option.rope)
			var land := peak_pos(float(state.d))
			state.rope = keep
			return {"say": "You'd land at %.0f m" % land.y, "land": V2Data.arr(land)}
		"kick":
			var p := next_peak(str(option.footing))
			var d := float(state.d)
			var say := "Short of the crack"
			if p > d + T.SWING_SLAM_M:
				say = "Too hard: you'd slam the corner"
			elif in_reach(p):
				say = "In reach of the crack"
			return {"peak": p, "pos": V2Data.arr(peak_pos(p)), "say": say}
		"grab":
			return {"say": "in reach at the top of this swing", "pos": V2Data.arr(_grab_pos(option))}
	return {}


func apply(option: Dictionary) -> Dictionary:
	match str(option.id):
		"lower":
			state.rope = float(option.rope)
			state.stage = "swing"
			state.spots = _kick_spots(V2Data.vec(state.pivot), float(state.side), float(state.rope))
			var extra := maxf(float(state.rope) - float(state.base), 0.0)
			return {"cost": [0.0, 0.0, T.SWING_LOWER_MINUTES + int(extra)], "say": "Lowered out. Now run.",
				"hang": peak_pos(0.0), "tags": PackedStringArray(["hang", "swing"]),
				"step": {"stage": "lowered", "rope": state.rope}}
		"kick":
			var p := next_peak(str(option.footing))
			state.kicks = int(state.kicks) + 1
			var c := cost(T.SWING_KICK_COST)
			var say := "You run and swing out."
			if str(option.footing) in ["wet", "polished"]:
				say = "Your feet skate on the %s." % _footing_name(str(option.footing))
			if p > float(state.d) + T.SWING_SLAM_M:
				p *= 0.5
				state.slams = int(state.slams) + 1
				c = _add(c, cost(T.SWING_SLAM_COST))
				say = "Too hard! You slam into the corner."
			state.peak = p
			return {"cost": c, "say": say, "hang": peak_pos(p), "tags": PackedStringArray(["hang", "swing"]),
				"step": {"stage": "swing", "peak": p, "footing": option.footing, "pos": V2Data.arr(peak_pos(p))}}
		"grab":
			var pump := session().effort.pump
			var miss_chance := clampf((pump - 0.7) * 2.0, 0.0, 0.8)
			if miss_chance > 0.0 and rng().randf() < miss_chance:
				state.misses = int(state.misses) + 1
				state.peak = float(state.peak) * T.SWING_DECAY
				return {"cost": cost(T.SWING_MISS_COST), "say": "Your pumped fingers slip off. Back across you go.",
					"hang": peak_pos(float(state.peak)), "tags": PackedStringArray(["hang", "swing"]),
					"step": {"stage": "missed", "peak": state.peak}}
			var at := _grab_pos(option)
			var clean := int(state.slams) == 0 and int(state.misses) == 0
			return {"cost": cost(T.SWING_GRAB_COST), "say": "Got it! You're across.", "done": true, "ok": clean,
				"hang": at - Vector2(0, ClimbV2.TORSO_M + 0.35), "tags": PackedStringArray(["swing_landed"]),
				"step": {"stage": "grabbed", "hold": str(option.hold), "pos": V2Data.arr(at)}}
	return {}


func _grab_pos(option: Dictionary) -> Vector2:
	var h := session().wall.hold(str(option.get("hold", "")))
	return h.pos if h else peak_pos(float(state.peak))


static func _add(a: Array, b: Array) -> Array:
	return [float(a[0]) + float(b[0]), float(a[1]) + float(b[1]), int(a[2]) + int(b[2])]
