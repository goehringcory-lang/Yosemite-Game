class_name ClimbBot
extends RefCounted
## A careful climber for tests: it reads the whole pitch and works out the
## cheapest safe line (where to shake out and where to place gear included),
## chalks before cruxes, eats at belays, jugs fixed ropes, and aids a hard
## move only when it's nearly spent. It plays [ClimbState] directly, the way
## the screen does.
##
## With [member greedy] set it plays like someone who only reads the rings:
## the cheapest hold in reach, a piece whenever there's one to place, chalk
## straight away, and no shaking out. Tests check that this does clearly
## worse on the hard routes, so the line and the timing matter.

## Stamina at a belay below which the bot eats (if it has food).
var eat_below := 62
## A careful climber eats at a belay until it has the next pitch's cost plus this.
var eat_margin := 15
## Protect once the runout reaches this many moves.
var protect_at := 2
## Shake out on a jug once pump reaches this.
var shake_at := 3
var use_aid := true
var use_jug := true
var greedy := false
var guard_limit := 900
var moves := 0
## The plan for the current pitch: (r, c, pump, runout, cams) -> [cost, action].
var _plan := {}
var _plan_key := ""


func play(state: ClimbState) -> void:
	var guard := 0
	while state.status == ClimbState.Status.CLIMBING and guard < guard_limit:
		guard += 1
		if not state.pending.is_empty():
			state.resolve_crux("good")
			continue
		step(state)


## One decision: everything the bot does before a move, then the move.
func step(state: ClimbState) -> void:
	if state.is_at_belay():
		_eat(state)
	if greedy:
		_protect(state)
	else:
		_follow_plan(state)
	_chalk(state)
	var choice := _choose(state)
	var dx: int = choice.dx
	if choice.mode == "jug":
		state.jug(dx)
	elif choice.mode == "aid":
		state.aid_step(dx)
	else:
		state.move(dx)
	moves += 1


func _eat(state: ClimbState) -> void:
	# The state keeps a real meal for each night still to come. A careful
	# climber eats enough for the pitch it has read, with some to spare.
	var want := eat_below
	if not greedy:
		var plan := _best(state, state.row, state.col, state.pump, state.runout(), _cams(state))
		if plan.cost < 1.0e5:
			want = maxi(want, mini(int(plan.cost) + eat_margin, ClimbState.MAX_STAMINA))
	var guard := 0
	while state.stamina < want and guard < 6 and state.can_eat():
		guard += 1
		state.eat(state.next_food())


## Greedy only: a piece whenever there's one to place.
func _protect(state: ClimbState) -> void:
	if state.route.top_rope:
		return
	if state.can_clip():
		state.clip_bolt()
	elif state.can_place_cam():
		state.place_cam()


## Careful: protects and shakes out where the plan says to.
func _follow_plan(state: ClimbState) -> void:
	var a := _best(state, state.row, state.col, state.pump, state.runout(), _cams(state))
	if a.protect:
		if state.can_clip():
			state.clip_bolt()
		elif state.can_place_cam():
			state.place_cam()
	a = _best(state, state.row, state.col, state.pump, state.runout(), _cams(state))
	if a.shake and state.can_shake():
		state.shake_out()


func _chalk(state: ClimbState) -> void:
	if state.is_at_belay() or state.chalked_this_pitch or not state.has_chalk:
		return
	if greedy:
		state.chalk_up()
		return
	var cruxes := state.crux_rows()
	var next := state.row + 1
	if next in cruxes or (cruxes.is_empty() and state.stamina < 45):
		state.chalk_up()


## Picks the next move: the cheapest hold in reach (greedy), or the plan's.
func _choose(state: ClimbState) -> Dictionary:
	var best := {"dx": 0, "mode": "move"}
	var best_score := 1.0e9
	var plan_dx := 99
	if not greedy:
		plan_dx = int(_best(state, state.row, state.col, state.pump, state.runout(), _cams(state)).dx)
	for dx in [-1, 0, 1]:
		var r := state.row + 1
		var hold := state.hold_at(r, state.col + dx)
		if hold.is_empty():
			continue
		var mode := "move"
		var cost := float(state.move_cost(r, state.col + dx))
		if use_jug and state.can_jug(dx):
			mode = "jug"
			cost = ClimbState.JUG_STAMINA
		elif use_aid and state.can_aid(dx) and state.stamina - cost < 30:
			mode = "aid"
			cost = ClimbState.AID_STAMINA + 4.0
		var score := cost if plan_dx == 99 else (0.0 if dx == plan_dx else 100.0 + cost)
		if score < best_score:
			best_score = score
			best = {"dx": dx, "mode": mode}
	return best


func _cams(state: ClimbState) -> int:
	return mini(state.cams_left, 4)


## The best thing to do at (r, c) with this pump, runout and cams: whether to
## protect, whether to shake out, and which way to move, by the stamina it
## takes to reach the ledge. Never runs out far enough for a fall to end the
## climb. Planned once a pitch (the holds don't change).
func _best(state: ClimbState, r: int, c: int, pump: int, runout: int, cams: int) -> Dictionary:
	var key := "%d/%d/%s" % [state.pitch, state.nights_spent, str(state.holds.size())]
	if key != _plan_key:
		_plan_key = key
		_plan = {}
	return _solve(state, r, c, pump, runout, cams, true)


func _solve(state: ClimbState, r: int, c: int, pump: int, runout: int, cams: int, may_protect: bool) -> Dictionary:
	var memo := Vector4i(r * 8 + c, pump, runout * 2 + (1 if may_protect else 0), cams)
	if _plan.has(memo):
		return _plan[memo]
	var out := {"cost": 1.0e6, "dx": 0, "protect": false, "shake": false}
	if r >= state.top_row:
		out.cost = 0.0
		_plan[memo] = out
		return out
	var hold := state.hold_at(r, c)
	var stance: bool = hold.get("rest", false)
	var g: String = hold.get("grip", "step")
	# Protect here first?
	if may_protect and r > 0 and runout > 0 and not state.route.top_rope:
		var bolt := state.bolts.has(r) and absi(int(state.bolts[r]) - c) <= 1 and state.quickdraws_left > 0
		var crack: bool = hold.get("crack", false) and cams > 0
		if bolt or crack:
			var effort := 1 if stance else int(ClimbState.PROTECT_COST.get(g, 2))
			var after_pump := mini(pump + (1 if g == "crimp" and not stance else 0), ClimbState.PUMP_MAX)
			var sub := _solve(state, r, c, after_pump, 0, cams - (0 if bolt else 1), false)
			if sub.cost + effort < out.cost:
				out = {"cost": sub.cost + effort, "dx": sub.dx, "protect": true, "shake": sub.shake}
	# Shake out here?
	var shook := pump
	if r > 0 and pump > 0 and (g == "jug" or stance):
		shook = maxi(pump - ClimbState.SHAKE_PUMP, 0)
	for shake in ([false, true] if shook != pump else [false]):
		var p := shook if shake else pump
		for dx in [-1, 0, 1]:
			var next := state.hold_at(r + 1, c + dx)
			if next.is_empty():
				continue
			var k := runout + 1
			if state.route.top_rope or state.is_snow() or r + 1 >= state.top_row:
				k = 0
			if k >= ClimbState.DANGEROUS_RUNOUT:
				continue
			var cost: float
			var np := p
			if use_jug and state.has_ascenders and next.get("fixed", false):
				cost = ClimbState.JUG_STAMINA
				np = maxi(p - 1, 0)
			else:
				cost = float(int(next.cost))
				if cost > 0.0:
					if state.has_shoes and not state.is_snow():
						cost -= ClimbState.SHOE_BONUS
					cost = maxf(cost + p, 1.0)
				np = clampi(p + state.pump_change(next), 0, ClimbState.PUMP_MAX)
				if next.get("rest", false):
					np = 0
					cost -= ClimbState.REST_STANCE
			var sub := _solve(state, r + 1, c + dx, np, k, cams, true)
			if sub.cost + cost < out.cost:
				out = {"cost": sub.cost + cost, "dx": dx, "protect": false, "shake": shake}
	_plan[memo] = out
	return out


## True if a piece could go in at ([param r], [param c]): a crack with a cam
## left, or a fixed piece in reach with a draw left.
func _protectable(state: ClimbState, r: int, c: int) -> bool:
	if state.route.top_rope or r >= state.top_row:
		return true
	if state.cams_left > 0 and state.hold_at(r, c).get("crack", false):
		return true
	return state.quickdraws_left > 0 and state.bolts.has(r) and absi(int(state.bolts[r]) - c) <= 1
