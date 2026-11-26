class_name HaulSpecial
extends CruxSpecial
## Hauling the bag up a big-wall pitch from the anchor. Not fifty presses:
## one choice hauls the bag up to the next lip (the gas it costs is the
## weight of the food and water you packed), and the decisions come at the
## lips, where the bag snags. A small edge flicks free with a sharp arm pull,
## if the bag isn't too heavy. Otherwise you let it back down and haul again
## at a better angle, or ask your partner to climb over and free it, which
## always works and takes a while. Under a roof, only the partner can.

const T := CruxTuning


func start() -> void:
	var s := session()
	var w := s.wall
	var height := maxf(w.top.y - w.start.y, 5.0)
	var lips: Array = []
	# Flakes and roofs the wall marks first.
	for z in w.zones:
		if z.kind == &"ledge" or z.data.get("lip", false):
			lips.append({"y": z.rect.end.y - w.start.y, "size": float(z.data.get("lip_size", 1.0)), "name": str(z.data.get("name", "a ledge"))})
	if lips.is_empty():
		var n := 1 if int(_diff()) <= 3 else 2
		for i in n:
			lips.append({"y": height * (0.3 + 0.45 * float(i) / maxf(1, n - 1) if n > 1 else 0.55) + (noise("lip%d" % i) - 0.5) * 2.0,
				"size": [0.6, 1.0, 1.0, 2.0][int(noise("lips%d" % i) * 3.99)] if w.style != &"roof" else 2.0,
				"name": "a flake"})
	for l: Dictionary in lips:
		l.name = {0.6: "a small edge", 1.0: "a flake", 2.0: "a roof"}.get(float(l.size), str(l.name))
	lips.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.y) < float(b.y))
	var weight := 1.0 + 0.35 * float(s.route.nights if s.route else 0)
	state = {"stage": "haul", "bag": 0.0, "height": height, "lips": lips, "lip": 0, "stuck": false, "jammed": false,
		"weight": weight, "fumbles": 0}


func _diff() -> int:
	var r := session().route
	if r == null or r.pitches.is_empty():
		return 2
	return r.pitches[mini(session().pitch, r.pitches.size() - 1)]


func title() -> String:
	return "Haul the bag"


func lip() -> Dictionary:
	var lips: Array = state.lips
	return lips[int(state.lip)] if int(state.lip) < lips.size() else {}


func options() -> Array:
	if not bool(state.stuck):
		var l := lip()
		return [{"id": "haul", "label": "Haul to %s" % (l.name if not l.is_empty() else "the anchor")}]
	var out: Array = []
	if not bool(state.jammed) and float(lip().size) < 2.0:
		out.append({"id": "flick", "label": "Flick it over the lip"})
	if float(lip().size) < 2.0:
		out.append({"id": "back", "label": "Let it down and haul again"})
	out.append({"id": "partner", "label": "Ask your partner to free it"})
	return out


func preview(option: Dictionary) -> Dictionary:
	match str(option.id):
		"haul":
			var to := float(lip().y) if not lip().is_empty() else float(state.height)
			return {"say": "%.0f m of hauling" % maxf(to - float(state.bag), 0.0), "to": to}
		"flick":
			return {"say": "A sharp arm pull (pumpy)"}
		"back":
			return {"say": "Slow, but it comes free"}
		"partner":
			return {"say": "Sure, and it takes a while"}
	return {}


func apply(option: Dictionary) -> Dictionary:
	match str(option.id):
		"haul":
			var l := lip()
			var to := float(l.y) if not l.is_empty() else float(state.height)
			var dist := maxf(to - float(state.bag), 0.0)
			state.bag = to
			var c := [0.0, dist * T.HAUL_GAS_PER_M * float(state.weight), roundi(dist * T.HAUL_MIN_PER_M * float(state.weight))]
			if l.is_empty():
				return {"cost": c, "say": "The bag docks at the anchor.", "done": true, "ok": int(state.fumbles) == 0, "step": {"stage": "docked", "bag": to}}
			state.stuck = true
			return {"cost": c, "say": "The bag snags under %s." % l.name, "step": {"stage": "snag", "bag": to, "lip": l}}
		"flick":
			var l := lip()
			if float(l.size) * float(state.weight) < T.FLICK_LIMIT:
				return _freed(cost(T.FLICK_COST), "A sharp pull and it flips over the lip.")
			state.jammed = true
			state.fumbles = int(state.fumbles) + 1
			return {"cost": cost(T.FLICK_COST), "say": "Too heavy. It jams harder.", "step": {"stage": "jammed"}}
		"back":
			return _freed(cost(T.BACK_OFF_COST), "You let it down a little and haul it past at a new angle.")
		"partner":
			if float(lip().size) < 2.0:
				state.fumbles = int(state.fumbles) + 1
			return _freed([0.0, 0.0, T.PARTNER_FREE_MIN], "Your partner swings over and shoves it free.")
	return {}


func _freed(c: Array, say: String) -> Dictionary:
	state.stuck = false
	state.jammed = false
	state.lip = int(state.lip) + 1
	state.bag = float(state.bag) + 0.4
	return {"cost": c, "say": say, "step": {"stage": "freed", "bag": state.bag}}
