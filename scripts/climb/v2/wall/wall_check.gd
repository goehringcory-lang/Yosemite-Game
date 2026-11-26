class_name WallCheck
extends RefCounted
## Proves a v2 wall is sound: every pitch has a climbable line from the belay
## to the anchor, a protectable line (no runout longer than the plan allows),
## sane cracks (widths on the Camalot scale, constrictions where the crack
## really narrows), crux zones whose sequence has holds, and nothing outside
## the wall. tests/climb_v2_wall_test runs it on every pitch of every route.

## Longest hand-to-hand move the line may ask for, metres. Below the body
## stub's reach (ClimbV2.ARM_M + 0.7) so a stricter real body still fits.
const MAX_STEP := 1.2
## The search uses this share of the body stub's reach, so a slightly
## shorter real body still fits.
const REACH_MARGIN := 0.97
## The longest stretch without protection a pitch may have unless its plan
## says otherwise ("runout"), metres.
const RUNOUT := 4.0
## The first protection must be this low, so a slip off the first moves
## doesn't reach the ground (unless the first bolt is the plan's runout).
const FIRST_PRO := 3.5
## How far from the line a piece can be and still protect it, metres.
const PRO_REACH := 1.3
## Hand holds this close together are drawn on top of each other.
const OVERLAP := 0.08


## Every problem found on [param wall], as readable lines ("" -> sound).
static func problems(wall: V2Wall) -> PackedStringArray:
	var out := PackedStringArray()
	var tag := "%s p%d" % [wall.route_id, wall.pitch + 1]
	_check_bounds(wall, tag, out)
	_check_ids(wall, tag, out)
	_check_cracks(wall, tag, out)
	_check_climbable(wall, tag, out)
	_check_protection(wall, tag, out)
	_check_cruxes(wall, tag, out)
	return out


static func _check_bounds(wall: V2Wall, tag: String, out: PackedStringArray) -> void:
	var r := Rect2(Vector2(-0.01, -0.01), wall.size + Vector2(0.02, 0.02))
	for h in wall.holds:
		if not r.has_point(h.pos):
			out.append("%s: hold %s at %s is off the wall" % [tag, h.id, h.pos])
		if h.size < 0.0 or h.size > 1.0:
			out.append("%s: hold %s size %.2f is outside 0..1" % [tag, h.id, h.size])
		if not h.kind in V2Hold.KINDS:
			out.append("%s: hold %s has unknown kind %s" % [tag, h.id, h.kind])
	for p in wall.fixed:
		if not r.has_point(p.pos):
			out.append("%s: %s %s is off the wall" % [tag, p.kind, p.id])
	if wall.anchor() == null and not wall.info.get("boulder", false):
		out.append("%s: no anchor" % tag)
	if wall.hold("anchor_hold") == null:
		out.append("%s: no top hold" % tag)


static func _check_ids(wall: V2Wall, tag: String, out: PackedStringArray) -> void:
	var seen := {}
	for h in wall.holds:
		if seen.has(h.id):
			out.append("%s: two holds called %s" % [tag, h.id])
		seen[h.id] = true
	seen.clear()
	for p in wall.fixed:
		if seen.has(p.id):
			out.append("%s: two pieces called %s" % [tag, p.id])
		seen[p.id] = true
	var hands: Array[V2Hold] = []
	for h in wall.holds:
		if h.hand:
			hands.append(h)
	for i in hands.size():
		for j in range(i + 1, hands.size()):
			if hands[i].pos.distance_to(hands[j].pos) < OVERLAP:
				out.append("%s: holds %s and %s overlap" % [tag, hands[i].id, hands[j].id])


static func _check_cracks(wall: V2Wall, tag: String, out: PackedStringArray) -> void:
	for c in wall.cracks:
		if c.points.size() < 2:
			out.append("%s: crack %s has fewer than 2 points" % [tag, c.id])
			continue
		if c.widths.size() != c.points.size():
			out.append("%s: crack %s has %d widths for %d points" % [tag, c.id, c.widths.size(), c.points.size()])
		for i in c.points.size() - 1:
			if c.points[i + 1].y < c.points[i].y - 0.01:
				out.append("%s: crack %s runs downward at point %d" % [tag, c.id, i + 1])
		for wd in c.widths:
			if wd < 0.0 or wd > ClimbRack.MAX_WIDTH:
				out.append("%s: crack %s width %.2f is off the Camalot scale" % [tag, c.id, wd])
		for i in c.constrictions:
			if i <= 0 or i >= c.points.size():
				out.append("%s: crack %s constriction %d is not a point above the bottom" % [tag, c.id, i])
			elif c.widths[i - 1] >= c.widths[i]:
				out.append("%s: crack %s doesn't narrow below constriction %d" % [tag, c.id, i])


## A path of hand holds from the start to the top, each move within MAX_STEP.
static func _check_climbable(wall: V2Wall, tag: String, out: PackedStringArray) -> void:
	var path := climb_path(wall)
	if path.is_empty():
		out.append("%s: no climbable line from the belay to the anchor (stuck at %.1f m)" % [tag, highest_reached(wall)])
	elif not search(wall, Callable(), false).has("path"):
		out.append("%s: no way up without swinging (the free way round is missing)" % tag)


## The holds a hand moves to, in order, on the fewest moves from the belay
## to the anchor hold, or [] if there's no way up. The search is over both
## hands (left, right) with the body stub's reach: the hips hang below the
## hands, the shoulder is TORSO_M above the hips, a hand reaches REACH from
## the shoulder and from the other hand, hands take turns (or swap), and
## a swing crux carries the climber from its jump-off jug to its landing.
static func climb_path(wall: V2Wall) -> Array[V2Hold]:
	return _search(wall).get("path", [] as Array[V2Hold])


## The highest hand hold the search reached (for error messages).
static func highest_reached(wall: V2Wall) -> float:
	return float(_search(wall).get("high", 0.0))


## Searches for a way up. Returns {"path" (if one), "high" (highest hand
## hold reached), "best" (the hold furthest on, by [param along], a
## Callable(Vector2) -> float, or height)}.
static func search(wall: V2Wall, along := Callable(), swings := true) -> Dictionary:
	return _search(wall, along, "", swings)


## The fewest moves from hands on [param lh_id] and [param rh_id] to the
## top, as the states after each move: [[lh id, rh id], ...]. [] if there's
## no way (or a hand isn't on a hold). Bots follow it.
## [param swings] false keeps off swing cruxes (the free way round), for a
## body that can't swing yet.
static func plan(wall: V2Wall, lh_id: String, rh_id: String, swings := true) -> Array:
	if wall.hold(lh_id) == null or wall.hold(rh_id) == null:
		return []
	return _search(wall, Callable(), "%s|%s" % [lh_id, rh_id], swings).get("states", [])


static func _search(wall: V2Wall, along := Callable(), from_state := "", use_swings := true) -> Dictionary:
	var hands: Array[V2Hold] = []
	for h in wall.holds:
		if h.hand:
			hands.append(h)
	var reach := BodyStub.REACH * REACH_MARGIN
	var hip := wall.start + Vector2(0, 0.95)
	var shoulder := hip + Vector2(0, ClimbV2.TORSO_M)
	var firsts: Array[V2Hold] = []
	for h in hands:
		if h.pos.y > hip.y and h.pos.distance_to(shoulder) <= BodyStub.REACH:
			firsts.append(h)
	firsts.sort_custom(func(a: V2Hold, b: V2Hold) -> bool: return a.pos.y < b.pos.y)
	if firsts.size() < 2:
		return {"high": firsts[0].pos.y if firsts.size() == 1 else 0.0}
	var goal := wall.hold("anchor_hold")
	var swings := {}
	for z in wall.zones:
		if use_swings and z.kind == &"crux" and z.data.has("from") and z.data.has("to"):
			swings[str(z.data.from)] = wall.hold(str(z.data.to))
	# How far up the climb a hold is: its height, or for a hold on a
	# traverse, how far along the traverse ([param along], if given).
	var progress := func(h: V2Hold) -> float: return along.call(h.pos) if along.is_valid() else h.pos.y
	# A state is "<lh id>|<rh id>"; prev maps a state to [previous state, hold moved to].
	var start := from_state if from_state != "" else "%s|%s" % [firsts[0].id, firsts[1].id]
	var prev := {start: null}
	var queue: Array[String] = [start]
	var high := 0.0
	var best: V2Hold = firsts[1]
	while not queue.is_empty():
		var state: String = queue.pop_front()
		var ids := state.split("|")
		var lh := wall.hold(ids[0])
		var rh := wall.hold(ids[1])
		high = maxf(high, maxf(lh.pos.y, rh.pos.y))
		for h: V2Hold in [lh, rh]:
			if progress.call(h) > progress.call(best):
				best = h
		if lh == goal or rh == goal:
			var path: Array[V2Hold] = []
			var states := []
			var at: Variant = state
			while prev[at] != null:
				path.push_front(prev[at][1])
				states.push_front(Array((at as String).split("|")))
				at = prev[at][0]
			return {"path": path, "states": states, "high": high, "best": best}
		var next: Array[String] = []
		for landing: V2Hold in [swings.get(lh.id), swings.get(rh.id)]:
			if landing:
				next.append("%s|%s" % [landing.id, landing.id])
		var sh := (lh.pos + rh.pos) * 0.5 - Vector2(0, 0.95) + Vector2(0, ClimbV2.TORSO_M)
		for h in hands:
			if h == lh or h == rh or h.pos.y < sh.y - 0.9 or h.pos.distance_to(sh) > reach:
				continue
			if h.pos.distance_to(rh.pos) <= reach:
				next.append("%s|%s" % [h.id, rh.id])
			if h.pos.distance_to(lh.pos) <= reach:
				next.append("%s|%s" % [lh.id, h.id])
		for n in next:
			if not prev.has(n):
				var moved := n.split("|")
				prev[n] = [state, wall.hold(moved[0] if moved[0] != ids[0] else moved[1])]
				queue.append(n)
	return {"high": high, "best": best}


## Heights (metres) along the line where the leader can clip or place
## something: bolts, pins, a crack the rack fits, a horn to sling.
static func protection_heights(wall: V2Wall) -> Array[float]:
	var path := climb_path(wall)
	var ys: Array[float] = []
	var near_line := func(pos: Vector2) -> bool:
		for h in path:
			if h.pos.distance_to(pos) <= PRO_REACH:
				return true
		return path.is_empty()
	for p in wall.fixed:
		if p.kind != &"anchor" and near_line.call(p.pos):
			ys.append(p.pos.y)
	for c in wall.cracks:
		var length := c.length()
		var t := 0.0
		while t <= length:
			var pos := _crack_point(c, t)
			var width := c.width_near(pos)
			if width >= 0.0 and width <= ClimbRack.MAX_WIDTH and near_line.call(pos):
				ys.append(pos.y)
			t += 0.3
	for h in wall.holds:
		if h.has_tag("slingable") and near_line.call(h.pos):
			ys.append(h.pos.y)
	ys.sort()
	return ys


static func _crack_point(c: V2Crack, t: float) -> Vector2:
	var run := 0.0
	for i in c.points.size() - 1:
		var seg := c.points[i].distance_to(c.points[i + 1])
		if t <= run + seg:
			return c.points[i].lerp(c.points[i + 1], 0.0 if seg <= 0.0 else (t - run) / seg)
		run += seg
	return c.points[c.points.size() - 1]


## The longest stretch of the line with nothing to protect it, metres.
static func longest_runout(wall: V2Wall) -> float:
	var ys := protection_heights(wall)
	var last := 0.0
	var worst := 0.0
	for y in ys:
		worst = maxf(worst, y - last)
		last = maxf(last, y)
	return maxf(worst, wall.top.y - last)


static func _check_protection(wall: V2Wall, tag: String, out: PackedStringArray) -> void:
	if wall.info.get("top_rope", false) or wall.info.get("boulder", false) or wall.info.get("unprotected", false):
		return
	var allowed := float(wall.info.get("runout", RUNOUT))
	var ys := protection_heights(wall)
	if ys.is_empty():
		out.append("%s: nothing to protect the pitch with" % tag)
		return
	if ys[0] > maxf(FIRST_PRO, allowed):
		out.append("%s: first protection is %.1f m up (ground fall)" % [tag, ys[0]])
	var worst := longest_runout(wall)
	if worst > allowed + 0.01:
		out.append("%s: a %.1f m runout (the plan allows %.1f)" % [tag, worst, allowed])


static func _check_cruxes(wall: V2Wall, tag: String, out: PackedStringArray) -> void:
	for z in wall.zones:
		if z.kind != &"crux":
			continue
		var seq: Array = z.data.get("sequence", [])
		for hand: Variant in seq:
			if not str(hand) in ["lh", "rh"]:
				out.append("%s: crux %s sequence has %s (lh or rh only)" % [tag, z.id, hand])
		var in_zone := 0
		for h in wall.holds:
			if h.hand and z.has_point(h.pos):
				in_zone += 1
		if in_zone < seq.size():
			out.append("%s: crux %s has %d holds for a %d-move sequence" % [tag, z.id, in_zone, seq.size()])
		if not Rect2(Vector2.ZERO, wall.size).encloses(z.rect.grow(-0.01)) and not Rect2(Vector2(-2, 0), wall.size + Vector2(4, 0)).encloses(z.rect):
			out.append("%s: crux %s is off the wall" % [tag, z.id])


## True if [param wall] has a climbable line (tools and tests).
static func _check_climbable_ok(wall: V2Wall) -> bool:
	return not climb_path(wall).is_empty()
