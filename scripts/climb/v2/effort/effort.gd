class_name EffortV2
extends EffortSystem
## Pump, gas, water and food for climbing v2 (thread 4). Nothing drains in
## real time: every move and action has a price, worked out purely from the
## wall and the body, so the ghost of a move can show what it will cost.
##
## Pump (the forearms) prices how you hold on, not how many moves you make:
## the hold's kind and size, how much weight the hands carry (feet on and good
## body positions are cheaper), whether you pull the hold the way it wants,
## how stretched you are. Easy ground with the weight on your feet gives a
## little back. Pump never makes moves cost more: it changes what happens
## (bands: fresh, working, pumped, boxed) and the ghost shows it first.
##
## Deep pump: pump you gain while already over the red line partly sticks as
## a floor that shake-outs can't clear; only a no-hands stance, the rope or
## the belay works it off. Sprinting a crux pumped leaves a debt; pacing
## doesn't.
##
## Rests: each press shakes one arm out for a minute and wins back a share of
## the gap to the floor, so returns fall off on their own. Kneebars, stems and
## no-hands stances beat jugs (the arm still hanging on a jug pays).
##
## Gas (the day's energy, 1.0 = 100 food energy) is spent by moves and
## minutes and only food puts it back. Low gas makes rests worse, never moves
## dearer; out of gas the arms can't recover past half. Food by its energy:
## nibbles (berries) one-handed off a good hold, trail food at a real rest
## (half now, half over ten minutes), meals with both hands free (a stance,
## the rope or the belay) arriving over twenty minutes and making every
## shake-out better for the pitch. The cap drops a little each pitch and in a
## long day; only camp and sleep put it back.
##
## Water drains in the sun (dry arms pump faster) and is topped up at belays.
##
## Body signs for art, look and sound: session.notes.effort.signs (see
## EffortSigns), ghost_signs(move) for a previewed move.

const T = preload("res://scripts/climb/v2/effort/effort_tuning.gd")


func id() -> StringName:
	return &"effort"


func attach(p_session: ClimbSession) -> void:
	super(p_session)
	var n := _note()
	if not n.has("deep"):
		n.merge({"deep": 0.0, "digest": [], "meal_rest": false, "recent": 0.0,
			"since_chalk": 0, "clock": 0, "arm": "lh", "steadied": false})
	_publish()


func pitch_started() -> void:
	var n := _note()
	var e := session.effort
	if session.pitch > 0 and int(n.get("cap_pitch", 0)) < session.pitch:
		n["cap_pitch"] = session.pitch
		e.gas_cap = maxf(T.CAP_MIN, e.gas_cap - T.PITCH_CAP)
		e.gas = minf(e.gas, e.gas_cap)
	n["meal_rest"] = false
	_publish()


# ------------------------------------------------------------------ pricing (pure)

func price(move: V2Move) -> void:
	var c := V2Cost.new()
	move.cost = c
	var h := session.wall.hold(move.hold_id) if session.wall else null
	if h == null:
		return
	var to := move.to if move.to else session.pose
	var other_d := demand(h)
	var other: V2Limb = to.limb(&"lh" if move.hand == &"rh" else &"rh")
	if other.kind == &"hold":
		other_d = demand(session.wall.hold(other.id))
	var d := T.NEW_HOLD_SHARE * demand(h) + (1.0 - T.NEW_HOLD_SHARE) * other_d
	var hands := hand_load(move)
	var pump := d * 2.0 * hands * (T.STRAIN_A + T.STRAIN_B * move.strain)
	pump *= wrong_way(h, to.hip)
	pump *= pose_mult(to.tags)
	for tag: StringName in T.MOVE_TAG:
		if move.has_tag(tag):
			pump *= float(T.MOVE_TAG[tag])
	pump = minf(T.MOVE_CAP, pump) * pump_mult()
	if hands < T.EASY_HANDS and h.size >= T.EASY_SIZE and move.strain < 0.3 and not move.has_tag("dyno"):
		pump = -T.EASY_BACK
	var gas := T.GAS_MOVE + T.GAS_STRAIN * move.strain
	for tag: StringName in T.GAS_TAG:
		if move.has_tag(tag):
			gas *= float(T.GAS_TAG[tag])
	# Off the crux's beta (cruxes sets crux_cost, contract v2): dearer.
	var crux := float(move.get("crux_cost")) if move.get("crux_cost") != null else 1.0
	c.pump = pump * crux if pump > 0.0 else pump
	c.minutes = 1
	c.gas = gas * crux * session.mods.gas_mult + c.minutes * T.GAS_PER_MINUTE


func price_action(kind: StringName, data := {}) -> V2Cost:
	var a: Array = T.ACTIONS.get(kind, [0.0, 0.0, 0])
	var pump := float(a[0])
	var gas := float(a[1])
	var minutes := int(a[2])
	if kind in T.TAXED and session.phase != &"belay":
		# The hold the hanging hand is on (gear passes it), else both hands' holds.
		var h := session.wall.hold(str(data.get("hand_hold", ""))) if session.wall and data.has("hand_hold") else null
		if session.pose.tags.has("hang"):
			pass
		elif h:
			pump += T.HANG_TAX * demand(h)
		else:
			pump += T.HANG_TAX * held_demand()
	if kind == &"rope_pull" and int(data.get("arms", 1)) > T.OVERHEAD_ARMS:
		pump *= T.OVERHEAD_MULT
	if kind == &"fall":
		gas += T.FALL_GAS_PER_M * float(data.get("drop_m", 0.0))
	if pump > 0.0:
		pump *= pump_mult()
	return V2Cost.make(pump, gas * session.mods.gas_mult + minutes * T.GAS_PER_MINUTE, minutes)


## How hard [param h] is to hang on to: the pump of a move onto it with half
## the weight on the hands and no strain, before the multipliers. Pure.
func demand(h: V2Hold) -> float:
	if h == null:
		return 0.0
	var d := T.BASE * float(T.GRIP.get(h.kind, 1.0)) * (T.SIZE_A - T.SIZE_B * clampf(h.size, 0.0, 1.0))
	var m := session.mods
	if h.size < 0.5 and m.wet > 0.0:
		d *= 1.0 + T.WET_MULT * m.wet
	if not m.has_chalk and h.kind in [&"crimp", &"sloper", &"pinch"]:
		d *= T.NO_CHALK_MULT
	if m.cold > 0.0 and h.kind in [&"crimp", &"jam"]:
		d *= 1.0 + T.COLD_MULT * m.cold
	return d


## The share of the weight on the hands after [param move] (0.5 if body
## didn't say).
func hand_load(move: V2Move) -> float:
	if move.load.is_empty():
		return 0.5
	return clampf(float(move.load.get(&"lh", move.load.get("lh", 0.0))) + float(move.load.get(&"rh", move.load.get("rh", 0.0))), 0.0, 1.0)


## Up to WRONG_WAY when the body hangs off [param h] against its pull.
func wrong_way(h: V2Hold, hip: Vector2) -> float:
	var v := hip - h.pos
	if v.length() < 0.05 or h.pull.length() < 0.01 or h.kind == &"stance":
		return 1.0
	var dot := h.pull.normalized().dot(v.normalized())
	return lerpf(T.WRONG_WAY, 1.0, clampf(dot, 0.0, 1.0))


func pose_mult(tags: PackedStringArray) -> float:
	var m := 1.0
	for tag: StringName in T.POSE:
		if tags.has(tag):
			m *= float(T.POSE[tag])
	return maxf(T.POSE_FLOOR, m)


## What everything costs in pump right now: the day's multiplier, assists and
## being thirsty.
func pump_mult() -> float:
	var m := session.mods.pump_mult
	if session.mods.assisted("relaxed"):
		m *= T.RELAXED
	var dry := 1.0 - clampf(session.effort.water / T.DRY_FROM, 0.0, 1.0)
	return m * lerpf(1.0, T.DRY_MULT, dry)


## The average demand of the holds the hands are on (0 hanging on the rope
## or with no hand on a hold).
func held_demand() -> float:
	if session.pose.tags.has("hang"):
		return 0.0
	var total := 0.0
	var n := 0
	for hand: StringName in [&"lh", &"rh"]:
		var l: V2Limb = session.pose.limb(hand)
		if l.kind == &"hold":
			total += demand(session.wall.hold(l.id))
			n += 1
	return total / n if n > 0 else 0.0


# ------------------------------------------------------------------ state queries (pure)

## fresh, working, pumped or boxed for [param pump] (now if -1).
func band(pump := -1.0) -> StringName:
	return EffortSigns.band(session.effort.pump if pump < 0.0 else pump)


## The deep pump floor no shake-out can clear.
func deep() -> float:
	return float(_note().get("deep", 0.0))


## How reliable small holds are at [param pump] (now if -1): 1 until the
## pumped band, falling to 0 at full pump. For falls (thread 7).
func hold_factor(pump := -1.0) -> float:
	var p := session.effort.pump if pump < 0.0 else pump
	return 1.0 - smoothstep(T.PUMPED, 1.0, p)


## True if [param move] will fail at the pump it leaves you with: boxed and
## straining, or boxed and off a jug. The ghost shows it before you commit;
## falls (thread 7) can read it. Pure.
func will_fail(move: V2Move) -> bool:
	var after := pump_after(move)
	if after < T.BOXED:
		return false
	if move.has_tag("rest"):
		return false
	var h := session.wall.hold(move.hold_id)
	return move.strain > T.BOXED_STRAIN or h == null or h.size < T.BOXED_SIZE


## The pump after [param move] (priced first).
func pump_after(move: V2Move) -> float:
	var c := move.cost if move.cost else V2Cost.new()
	if c.pump >= 0.0:
		return minf(1.0, session.effort.pump + c.pump * _scale())
	return maxf(minf(session.effort.pump, floor_now()), session.effort.pump + c.pump)


## The lowest the pump can go here by easy ground or rests right now.
func floor_now() -> float:
	var f := deep()
	if session.effort.gas <= 0.001:
		f = maxf(f, T.BONK_FLOOR)
	return f


## The pump a rest press of [param kind] would win back now (0: spent).
func rest_gain(kind: StringName) -> float:
	if kind == &"":
		return 0.0
	var e := session.effort
	if kind == &"belay":
		return maxf(0.0, e.pump - deep() * 0.5)
	var r: Array = T.RESTS.get(kind, [0.25, 0.25])
	var rate := float(r[0])
	var fl := maxf(floor_now(), float(r[1]))
	if e.gas / maxf(e.gas_cap, 0.01) < T.LOW_GAS:
		rate *= T.LOW_GAS_REST
		fl += T.LOW_GAS_FLOOR
	if _note().get("meal_rest", false):
		rate = minf(0.9, rate * T.MEAL_REST)
	var gain := rate * (e.pump - fl)
	if kind == &"jug":
		gain -= T.JUG_HOLD_COST
	return gain if gain >= T.REST_MIN else 0.0


## What a rest press here would win back (body's rest_kind, or the belay).
func rest_left() -> float:
	return rest_gain(_where())


## The signs a previewed [param move] would leave the body with (the ghost's
## arms tremble by them; "fail" says the move won't go). Pure.
func ghost_signs(move: V2Move) -> Dictionary:
	var e := session.effort.copy()
	e.pump = pump_after(move)
	var s := EffortSigns.make(e, _note(), session.mods, 0.0, false)
	s["fail"] = 1.0 if will_fail(move) else 0.0
	s["unreliable"] = 1.0 - hold_factor(e.pump)
	return s


## The current signs (also in session.notes.effort.signs).
func signs() -> Dictionary:
	return _note().get("signs", {})


## Which food class [param food_id] is: nibble, trail or meal ("" not food).
func food_class(food_id: String) -> StringName:
	var db := _food_db()
	if db == null or not db.is_edible(food_id):
		return &""
	var energy := int(db.energy(food_id))
	if energy <= T.NIBBLE:
		return &"nibble"
	return &"meal" if energy >= T.MEAL else &"trail"


## True if [param food_id] can be eaten where you are now. Pure.
func can_eat_here(food_id: String) -> bool:
	match food_class(food_id):
		&"nibble":
			return _where() != &"" or _best_hand_hold() >= T.EAT_HOLD
		&"trail":
			return _where() in T.TRAIL_RESTS
		&"meal":
			return _where() in T.MEAL_RESTS
	return false


func best_food() -> String:
	var db := _food_db()
	if db == null:
		return ""
	var e := session.effort
	var gap := e.gas_cap - e.gas
	var want_steady := e.pump >= T.WORKING
	var fits := ""
	var smallest := ""
	for food: String in db.edible_in_inventory():
		if not can_eat_here(food):
			continue
		var gas := float(db.energy(food)) / 100.0
		if gap < T.EAT_GAP and not (want_steady and food_class(food) == &"nibble"):
			continue
		if fits == "" and gas <= gap + 0.02:
			fits = food
		smallest = food
	return fits if fits != "" else smallest


# ------------------------------------------------------------------ mutators

func apply(cost: V2Cost) -> void:
	var e := session.effort
	var n := _note()
	if cost.pump > 0.0:
		var before := e.pump
		e.pump = minf(1.0, e.pump + cost.pump * _scale())
		var over := e.pump - maxf(before, T.DEEP_FROM)
		if over > 0.0:
			n["deep"] = minf(e.pump, deep() + T.DEEP_SHARE * over)
		n["steadied"] = false
	elif cost.pump < 0.0:
		e.pump = maxf(minf(e.pump, floor_now()), e.pump + cost.pump)
	e.gas = clampf(e.gas - cost.gas, 0.0, e.gas_cap)
	if cost.minutes > 0:
		_pass_minutes(cost.minutes)
	n["recent"] = lerpf(float(n.get("recent", 0.0)), maxf(0.0, cost.pump) + cost.gas, 0.3)
	if cost.pump > 0.0:
		n["since_chalk"] = int(n.get("since_chalk", 0)) + 1
	_publish()
	session.bus.send(&"effort_changed", [e])


func rest(kind: StringName) -> V2Cost:
	if kind == &"":
		return V2Cost.new()
	var e := session.effort
	var n := _note()
	var minutes := T.REST_MINUTES
	if kind == &"belay":
		e.pump = deep() * 0.5
		n["deep"] = deep() * 0.5
		e.water = 1.0
		minutes = T.BELAY_MINUTES
	else:
		var gain := rest_gain(kind)
		e.pump = maxf(0.0, e.pump - gain)
		if kind == &"stance":
			n["deep"] = maxf(0.0, deep() - T.STANCE_DEEP)
		n["arm"] = "rh" if n.get("arm", "lh") == "lh" else "lh"
	n["since_chalk"] = 0 if session.mods.has_chalk else int(n.get("since_chalk", 0))
	n["steadied"] = false
	session.bus.send(&"rested", [kind])
	_publish()
	session.bus.send(&"effort_changed", [e])
	return V2Cost.make(0.0, minutes * T.GAS_PER_MINUTE, minutes)


func eat(food_id: String) -> bool:
	var db := _food_db()
	var inv := _inventory()
	if db == null or inv == null or food_id == "" or not can_eat_here(food_id):
		return false
	if not inv.remove(food_id, 1):
		return false
	var e := session.effort
	var n := _note()
	var gas := float(db.energy(food_id)) / 100.0
	var cls := food_class(food_id)
	var now := gas
	match cls:
		&"nibble":
			e.pump = maxf(minf(e.pump, floor_now()), e.pump - T.NIBBLE_STEADY)
			n["steadied"] = true
		&"trail":
			now = gas * T.TRAIL_NOW
			_digest(gas - now, T.TRAIL_MINUTES)
		&"meal":
			now = 0.0
			_digest(gas, T.MEAL_MINUTES)
			n["meal_rest"] = true
	e.gas = minf(e.gas_cap, e.gas + now)
	n["last_food"] = food_id
	_publish()
	session.bus.send(&"food_eaten", [food_id, gas])
	session.bus.send(&"effort_changed", [e])
	return true


# ------------------------------------------------------------------ the overlay

func make_overlay() -> Node:
	var o := EffortOverlay.new()
	o.session = session
	return o


# ------------------------------------------------------------------ inside

## Pump costs scale: none (kept for the assists to come).
func _scale() -> float:
	return 1.0


func _where() -> StringName:
	if session.phase == &"belay":
		return &"belay"
	return session.sys.body.rest_kind() if session.sys.body else &""


func _best_hand_hold() -> float:
	var best := 0.0
	for hand: StringName in [&"lh", &"rh"]:
		var l: V2Limb = session.pose.limb(hand)
		if l.kind == &"hold" and session.wall:
			var h := session.wall.hold(l.id)
			if h:
				best = maxf(best, h.size)
	return best


func _digest(gas: float, minutes: int) -> void:
	if gas <= 0.0 or minutes <= 0:
		return
	(_note()["digest"] as Array).append([gas / minutes, minutes])


func _pass_minutes(minutes: int) -> void:
	var e := session.effort
	var n := _note()
	var left: Array = []
	for d: Array in n.get("digest", []):
		var m := mini(minutes, int(d[1]))
		e.gas = minf(e.gas_cap, e.gas + float(d[0]) * m)
		if int(d[1]) - m > 0:
			left.append([d[0], int(d[1]) - m])
	n["digest"] = left
	var sun := session.mods.sun
	e.water = maxf(0.0, e.water - minutes * lerpf(T.WATER_SHADE, T.WATER_SUN, sun))
	var before := int(n.get("clock", 0))
	var after := before + minutes
	n["clock"] = after
	var hours := maxi(0, (after - T.DAY_MINUTES) / 60) - maxi(0, (before - T.DAY_MINUTES) / 60)
	if after > T.DAY_MINUTES and hours > 0:
		e.gas_cap = maxf(T.CAP_MIN, e.gas_cap - T.HOUR_CAP * hours)
		e.gas = minf(e.gas, e.gas_cap)


func _publish() -> void:
	var n := _note()
	var has_food := false
	var db := _food_db()
	if db and _inventory():
		has_food = not db.edible_in_inventory().is_empty()
	var rl := rest_left() if session.wall and session.sys.body else 0.0
	n["signs"] = EffortSigns.make(session.effort, n, session.mods, rl, has_food)


func _note() -> Dictionary:
	return session.note(id())


func _food_db() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("/root/FoodDB") if tree else null


func _inventory() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("/root/Inventory") if tree else null
