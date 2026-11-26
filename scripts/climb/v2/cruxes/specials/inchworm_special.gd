class_name InchwormSpecial
extends CruxSpecial
## A chimney or offwidth: slow, gassy, secure. You move one half of your body
## at a time while the other half holds you: the upper half (fists, a hand
## stack, an arm bar, a chicken wing, back and palms) then the lower (heel-
## toe, a knee bar, butterfly feet, back and foot). Moving the halves in turn
## isn't the choice; WHERE each half locks is. The crack is drawn as wide as
## it is and it flares and pinches as it goes: you aim the moving half at a
## spot along it, and a pinch makes a bomber lock where a flare makes a
## slippery one. A short shuffle to a good lock beats a long one to a bad
## lock. With both halves locked you can rest.
##
## One choice per section up front: which side goes in. Against the crack's
## lean every shuffle costs more; switching sides halfway is a big effort.

const T = preload("res://scripts/climb/v2/cruxes/crux_tuning.gd")

var _crack: V2Crack


func start() -> void:
	var s := session()
	var r := CruxReader.rect_of(spot)
	var x := s.pose.hip.x
	var c := _find_crack(r)
	if c:
		x = float(c.nearest(Vector2(x, r.position.y)).pos.x)
		var lean := c.points[c.points.size() - 1].x - c.points[0].x
		state = {"lean": signf(lean) if absf(lean) > 0.1 else (1.0 if noise("lean") > 0.5 else -1.0)}
	else:
		state = {"lean": 1.0 if noise("lean") > 0.5 else -1.0}
	var bottom := maxf(r.position.y, s.pose.hip.y - 0.4)
	state.merge({"stage": "side", "side": 0.0, "x": x, "bottom": bottom, "top": r.end.y, "upper": bottom + 1.0, "lower": bottom,
		"moving": "upper", "slips": 0, "last_q": 0.6, "wide": kind == &"chimney"}, true)


func _find_crack(r: Rect2) -> V2Crack:
	for c in session().wall.cracks:
		if c.kind in [&"offwidth", &"chimney"] or (c.widths.size() > 0 and c.widths[0] >= 6.0):
			if float(c.nearest(r.get_center()).distance) < 1.5:
				return c
	return null


func title() -> String:
	return str(spot.get("name", "The chimney" if kind == &"chimney" else "The offwidth"))


## Width of the crack at height [param y] (Camalot scale; 7 = #4). From the
## wall's crack if it has one, else a flaring, pinching profile made from
## the pitch.
func width_at(y: float) -> float:
	if _crack == null:
		_crack = _find_crack(CruxReader.rect_of(spot))
	if _crack:
		return _crack.width_near(Vector2(float(state.x), y))
	var base := 11.5 if bool(state.wide) else 8.4
	var u := y * 1.7
	var i := floori(u)
	var f := u - i
	var a := noise("w%d" % i)
	var b := noise("w%d" % (i + 1))
	return base + (lerpf(a, b, f * f * (3.0 - 2.0 * f)) - 0.5) * 3.2


## The best lock for the moving half at [param y]: {name, q}. q is 0..1 and
## is not shown as a number: you read it from the crack's shape.
func lock_at(half: String, y: float) -> Dictionary:
	var w := width_at(y)
	var locks: Array = T.LOCKS_UPPER if half == "upper" else T.LOCKS_LOWER
	var best := {"name": "", "q": 0.0}
	for l: Array in locks:
		var q := clampf(1.0 - absf(w - float(l[1])) / float(l[2]), 0.0, 1.0)
		if q > float(best.q):
			best = {"name": l[0], "q": q}
	# A pinch just above the lock seats it: the spot narrower than its neighbours.
	if width_at(y + 0.15) > w + 0.25 and width_at(y - 0.15) > w + 0.25:
		best.q = minf(1.0, float(best.q) + 0.25)
	return best


func options() -> Array:
	if state.stage == "side":
		return [{"id": "side", "side": -1.0, "label": "Left side in"}, {"id": "side", "side": 1.0, "label": "Right side in"}]
	var out := _shuffles(str(state.moving))
	if out.is_empty():
		# This half can't go further until the other one moves.
		out = _shuffles("lower" if str(state.moving) == "upper" else "upper")
	if float(state.last_q) >= 0.5:
		out.append({"id": "rest", "label": "Rest, both halves locked"})
	out.append({"id": "switch", "label": "Turn round: other side in"})
	return out


## The spots the [param half] can move to: up to an arm's (or a leg's)
## shuffle, keeping the body between its two locks.
func _shuffles(half: String) -> Array:
	var out: Array = []
	var from := float(state.upper) if half == "upper" else float(state.lower)
	var lo := from + T.WORM_SPOT_M
	var hi := from + T.WORM_REACH_M
	if half == "lower":
		hi = minf(hi, float(state.upper) - 0.4)
	else:
		hi = minf(hi, float(state.lower) + 1.4)
	var y := lo
	while y <= hi + 0.001:
		var l := lock_at(half, y)
		out.append({"id": "shuffle", "half": half, "y": y, "lock": l.name, "label": "%s up %.1f m: %s" % ["Reach" if half == "upper" else "Bring your legs", y - from, l.name]})
		y += T.WORM_SPOT_M
	return out


func preview(option: Dictionary) -> Dictionary:
	match str(option.id):
		"shuffle":
			return {"say": "", "y": option.y, "x": state.x}
		"side":
			return {"say": "Face %s" % ("left" if float(option.side) < 0.0 else "right")}
		"rest":
			return {"say": "Wedged in. Breathe."}
		"switch":
			return {"say": "Hard work in here"}
	return {}


func _side_mult() -> float:
	return T.WORM_WRONG_SIDE if float(state.side) != 0.0 and float(state.side) != float(state.lean) else 1.0


func apply(option: Dictionary) -> Dictionary:
	match str(option.id):
		"side":
			state.side = float(option.side)
			state.stage = "worm"
			return {"cost": [0.0, 0.004, 1], "say": "You wriggle in, %s side first." % ("left" if float(option.side) < 0.0 else "right"),
				"hang": hip_pos(), "tags": _tags(), "step": {"stage": "side", "side": state.side}}
		"shuffle":
			var half := str(option.half)
			var from := float(state.upper) if half == "upper" else float(state.lower)
			var y := float(option.y)
			var l := lock_at(half, y)
			var q := float(l.q)
			var dist := y - from
			var bad := (1.0 + (1.0 - q) * 1.5) * _side_mult()
			var c := [T.WORM_PUMP_PER_M * dist * bad, T.WORM_GAS_PER_M * dist * bad, 1 + roundi(dist * 3.0)]
			var say := "%s. Solid." % str(l.name).capitalize() if q >= 0.7 else "%s. It'll do." % str(l.name).capitalize()
			var slipped := q < T.WORM_SLIP_BELOW
			if slipped:
				# It won't lock: you slide back past where you started.
				state.slips = int(state.slips) + 1
				y = maxf(from - T.WORM_SLIP_M, float(state.bottom))
				if half == "lower":
					y = minf(y, float(state.upper) - 0.4)
				c[0] = float(c[0]) + 0.04
				say = "The %s won't lock there. You slide back." % str(l.name)
			if half == "upper":
				state.upper = y
			else:
				state.lower = y
			state.last_q = q
			# After a slip the same half tries again; otherwise the other moves.
			state.moving = half if slipped else ("lower" if half == "upper" else "upper")
			var fx := {"cost": c, "say": say, "hang": hip_pos(), "tags": _tags(),
				"step": {"stage": "shuffle", "half": half, "y": y, "lock": l.name, "slipped": q < T.WORM_SLIP_BELOW}}
			if float(state.upper) >= float(state.top) and float(state.lower) >= float(state.top) - 1.2:
				fx["done"] = true
				fx["ok"] = int(state.slips) == 0
				fx["say"] = "You squirm out of the top."
				fx["hang"] = Vector2(float(state.x), float(state.top) - 0.3)
				fx["tags"] = PackedStringArray()
			return fx
		"rest":
			return {"rest": &"stance", "say": "Wedged in. You breathe and shake out.", "step": {"stage": "rest"}}
		"switch":
			state.side = -float(state.side)
			return {"cost": [0.05, 0.03, 4], "say": "You thrash round to face the other way.", "hang": hip_pos(), "tags": _tags(), "step": {"stage": "switch", "side": state.side}}
	return {}


func hip_pos() -> Vector2:
	return Vector2(float(state.x), (float(state.upper) + float(state.lower)) * 0.5)


func _tags() -> PackedStringArray:
	return PackedStringArray([String(kind), "side_" + ("left" if float(state.side) < 0.0 else "right")])
