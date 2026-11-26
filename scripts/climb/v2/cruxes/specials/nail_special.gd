class_name NailSpecial
extends CruxSpecial
## Nailing up a line of pin scars on a hard-aid pitch. Each scar is drawn on
## the rock as wide as it is; you pick a pin from your iron for it, then
## drive it a tap at a time and listen. A pin that fits sings higher each tap
## until it rings; one too small clacks in loose; one too big pings and
## stops half in (tie it off); a shallow scar thunks flat when the pin
## bottoms out. Then you choose: bounce-test it (a minute, and you find out
## now) or step straight up in your aiders (quicker, but if it pops you drop
## onto your last piece and the pin is gone).
##
## The puzzle is the iron: a pitch has more scars that want a size than you
## carry pins of it. Tie-offs, a size off, back-cleaning the pin below to
## reuse it, or a skyhook as the last resort are the compromises.

const T := CruxTuning


func start() -> void:
	var r := CruxReader.rect_of(spot)
	var s := session()
	var n := clampi(roundi(r.size.y / 0.75), 2, 5)
	var x := s.pose.hip.x
	var cs := s.wall.cracks_within(Vector2(x, r.get_center().y), 1.2)
	if not cs.is_empty():
		x = float(cs[0].nearest(Vector2(x, r.get_center().y)).pos.x)
	var iron := {}
	for id: String in T.IRON:
		var it: Array = T.IRON[id]
		iron[id] = {"name": it[0], "min": it[1], "max": it[2], "count": it[3]}
	# Pins on the rack (if the gear tent racked any) count instead.
	for item in s.rack.of_kind("pin"):
		iron[str(item.id)] = {"name": str(item.get("name", item.id)), "min": float(item.width_min), "max": float(item.width_max), "count": int(item.count)}
	var ids := iron.keys()
	var scars: Array = []
	for i in n:
		var y := r.position.y + (i + 0.5) * r.size.y / n
		# Most scars want the middle sizes, so those run out first.
		var pick: String = ids[clampi(int(noise("scar%d" % i) * 2.0 + (1 if i % 2 == 0 else 0)), 0, ids.size() - 1)]
		var want: Dictionary = iron[pick]
		var w := lerpf(float(want.min), float(want.max), 0.25 + 0.5 * noise("w%d" % i))
		var depth := 0.55 if noise("d%d" % i) > 0.72 else 1.0
		scars.append({"pos": [x + (noise("x%d" % i) - 0.5) * 0.2, y], "width": w, "depth": depth})
	state = {"stage": "pick", "scar": 0, "scars": scars, "iron": iron, "placed": [], "pin": {}, "pops": 0, "lost": 0}


func title() -> String:
	return str(spot.get("name", "Pin scars"))


func scar() -> Dictionary:
	return state.scars[int(state.scar)]


func options() -> Array:
	var out: Array = []
	match str(state.stage):
		"pick":
			for id: String in state.iron:
				var it: Dictionary = state.iron[id]
				if int(it.count) > 0:
					out.append({"id": "pin", "pin": id, "label": "%s (%d)" % [it.name, int(it.count)]})
			if not (state.placed as Array).is_empty():
				out.append({"id": "backclean", "label": "Back-clean the pin below"})
			out.append({"id": "hook", "label": "Skyhook it"})
		"drive":
			var pin: Dictionary = state.pin
			if not bool(pin.get("stopped", false)) and int(pin.taps) < T.MAX_TAPS:
				out.append({"id": "tap", "label": "Tap it"})
			out.append({"id": "test", "label": "Bounce-test it"} if not bool(pin.get("tested", false)) else {"id": "step", "label": "Step up"})
			if not bool(pin.get("tested", false)):
				out.append({"id": "step", "label": "Step up without testing"})
			out.append({"id": "pull", "label": "Pull it and pick another"})
	return out


## How a pin of [param pin_id] sits in the current scar: "snug", "loose"
## (too small) or "tight" (too big).
func fit(pin_id: String) -> String:
	var it: Dictionary = state.iron[pin_id]
	var w := float(scar().width)
	if w < float(it.min):
		return "tight"
	if w > float(it.max):
		return "loose"
	return "snug"


func preview(option: Dictionary) -> Dictionary:
	match str(option.id):
		"pin":
			return {"say": "Offer the %s to the scar" % state.iron[str(option.pin)].name}
		"tap":
			return {"say": "Drive it deeper"}
		"test":
			return {"say": "Bounce on it before you trust it (1 min)"}
		"step":
			return {"say": "Stand up in your aiders on it"}
		"backclean":
			return {"say": "Knock out the pin below to use it again"}
		"hook":
			return {"say": "Balance a hook on an edge: quick, and a prayer"}
		"pull":
			return {"say": "Knock it back out"}
	return {}


func apply(option: Dictionary) -> Dictionary:
	match str(option.id):
		"pin":
			var it: Dictionary = state.iron[str(option.pin)]
			it.count = int(it.count) - 1
			state.pin = {"id": str(option.pin), "fit": fit(str(option.pin)), "depth": 0.0, "taps": 0, "quality": 0.0, "tested": false, "stopped": false}
			state.stage = "drive"
			return _tap()
		"tap":
			return _tap()
		"test":
			var pin: Dictionary = state.pin
			pin.tested = true
			if not _holds(pin):
				# Popped in the test: back in your hand, no harm done.
				state.iron[str(pin.id)].count = int(state.iron[str(pin.id)].count) + 1
				state.pin = {}
				state.stage = "pick"
				return {"cost": cost(T.TEST_COST), "say": "It rips out as you bounce. Good thing you tested.", "step": {"stage": "test", "held": false}}
			return {"cost": cost(T.TEST_COST), "say": "You bounce hard. It holds.", "step": {"stage": "test", "held": true}}
		"step":
			return _step_up()
		"pull":
			var pin: Dictionary = state.pin
			state.iron[str(pin.id)].count = int(state.iron[str(pin.id)].count) + 1
			state.pin = {}
			state.stage = "pick"
			return {"cost": [0.005, 0.0, 1], "say": "You knock it out.", "step": {"stage": "pull"}}
		"backclean":
			var placed: Array = state.placed
			var p: Dictionary = placed.pop_back()
			if state.iron.has(str(p.id)):
				state.iron[str(p.id)].count = int(state.iron[str(p.id)].count) + 1
			return {"cost": [0.02, 0.004, 2], "say": "You lean down and knock out the %s." % _name(str(p.id)), "step": {"stage": "backclean", "pin": p.id}}
		"hook":
			state.pin = {"id": "hook", "fit": "hook", "depth": 1.0, "taps": 0, "quality": 0.3, "tested": false, "stopped": true}
			state.stage = "drive"
			return {"cost": [0.01, 0.0, 1], "say": "The hook teeters on a flake edge.", "step": {"stage": "hook"}}
	return {}


func _name(id: String) -> String:
	return str(state.iron[id].name) if state.iron.has(id) else id


## One hammer blow. What you hear is how the pin sits.
func _tap() -> Dictionary:
	var pin: Dictionary = state.pin
	var sc := scar()
	pin.taps = int(pin.taps) + 1
	var tone := ""
	var say := ""
	match str(pin.fit):
		"snug":
			pin.depth = float(pin.depth) + T.TAP_SNUG
			if float(pin.depth) >= T.RING_DEPTH:
				tone = "ring"
				say = "It rings!" if int(pin.taps) <= 3 else "Still ringing. It's set."
			else:
				tone = "rising"
				say = "The note climbs."
		"loose":
			pin.depth = float(pin.depth) + T.TAP_LOOSE
			tone = "clack"
			say = "A dull clack. It slides in too easily."
		"tight":
			pin.depth = minf(float(pin.depth) + T.TAP_TIGHT, T.TIGHT_STALL)
			tone = "ping"
			say = "A sharp ping." if float(pin.depth) < T.TIGHT_STALL else "Ping, ping. It won't go further: tie it off."
			if float(pin.depth) >= T.TIGHT_STALL:
				pin.stopped = true
	if float(pin.depth) >= float(sc.depth):
		pin.depth = float(sc.depth)
		pin.stopped = true
		tone = "thunk"
		say = "A flat thunk: it's bottomed out. Tie it off."
	pin.depth = minf(float(pin.depth), 1.0)
	if float(pin.depth) >= 1.0:
		pin.stopped = true
	pin.quality = _quality(pin)
	return {"cost": cost(T.TAP_COST), "say": say, "step": {"stage": "tap", "tone": tone, "depth": pin.depth, "pin": pin.id}}


func _quality(pin: Dictionary) -> float:
	var d := float(pin.depth)
	match str(pin.fit):
		"snug":
			return 0.92 if d >= T.RING_DEPTH else 0.35 + 0.5 * d
		"loose":
			return 0.15 + 0.15 * d
		"tight":
			return 0.3 + 0.2 * d
	return float(pin.get("quality", 0.3))


## Whether the pin holds your weight. Rolled once, the first time it's
## weighted, so a test tells you the truth about stepping up.
func _holds(pin: Dictionary) -> bool:
	if not pin.has("holds"):
		var q := float(pin.quality)
		var pop := clampf(pow(1.0 - q, 2.0) * 1.1, 0.0, 0.95)
		pin["holds"] = rng().randf() >= pop
	return bool(pin.holds)


func _step_up() -> Dictionary:
	var pin: Dictionary = state.pin
	var sc := scar()
	if not _holds(pin):
		state.pops = int(state.pops) + 1
		state.lost = int(state.lost) + 1
		state.pin = {}
		state.stage = "pick"
		var below := V2Data.vec((state.placed as Array).back().pos) if not (state.placed as Array).is_empty() else session().pose.hip
		return {"cost": cost(T.POP_DROP_COST), "say": "It pops! You drop onto your last piece. The pin's gone.",
			"hang": below - Vector2(0, 0.2), "tags": PackedStringArray(["hang", "aid"]), "step": {"stage": "popped"}}
	(state.placed as Array).append({"id": pin.id, "pos": sc.pos, "quality": pin.quality})
	state.pin = {}
	state.scar = int(state.scar) + 1
	var at := V2Data.vec(sc.pos)
	var fx := {"cost": cost(T.STEP_COST), "aid": 1, "hang": at - Vector2(0, 0.15), "tags": PackedStringArray(["aid"]),
		"step": {"stage": "stepped", "pos": sc.pos}}
	if int(state.scar) >= (state.scars as Array).size():
		fx["done"] = true
		fx["ok"] = int(state.pops) == 0
		fx["say"] = "Last pin. You top-step and reach free rock."
	else:
		state.stage = "pick"
		fx["say"] = "You stand up in your aiders."
	return fx
