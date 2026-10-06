class_name ClimbBot
extends RefCounted
## A careful climber for tests: it reads the next few rows, protects when the
## runout grows, chalks before cruxes, eats at belays, jugs fixed ropes, and
## aids a hard move only when it's nearly spent. It plays [ClimbState]
## directly, the way the screen does.

## Stamina at a belay below which the bot eats (if it has food).
var eat_below := 62
## Protect once the runout reaches this many moves.
var protect_at := 2
var use_aid := true
var use_jug := true
var guard_limit := 900
var moves := 0


func play(state: ClimbState) -> void:
	var guard := 0
	while state.status == ClimbState.Status.CLIMBING and guard < guard_limit:
		guard += 1
		if not state.pending.is_empty():
			state.resolve_crux("good")
			continue
		if state.is_at_belay():
			_eat(state)
		_protect(state)
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
	var foods := FoodDB.edible_in_inventory()
	if foods.is_empty():
		return
	# Keep a meal for the night on a wall.
	var guard := 0
	while state.stamina < eat_below and guard < 6 and not foods.is_empty():
		guard += 1
		foods.sort_custom(func(a, b): return FoodDB.energy(a) < FoodDB.energy(b))
		var pick: String = foods[0]
		if state.route.nights > state.nights_spent and FoodDB.energy(pick) >= ClimbState.BIVY_MEAL_ENERGY:
			var meals := 0
			for id in foods:
				if FoodDB.energy(id) >= ClimbState.BIVY_MEAL_ENERGY:
					meals += 1
			if meals <= state.route.nights - state.nights_spent:
				break
		state.eat(pick)
		foods = FoodDB.edible_in_inventory()


func _protect(state: ClimbState) -> void:
	if state.route.top_rope:
		return
	if state.can_clip() and (state.runout() >= 1 or state.is_bolted()):
		state.clip_bolt()
	elif state.runout() >= protect_at and state.can_place_cam():
		state.place_cam()


func _chalk(state: ClimbState) -> void:
	if state.is_at_belay() or state.chalked_this_pitch or not state.has_chalk:
		return
	var crux := state.crux_row()
	var next := state.row + 1
	if (crux > 0 and next == crux - 0) or (crux == 0 and state.stamina < 45):
		state.chalk_up()


## Picks the next move by looking three rows ahead for the cheapest line that
## keeps cracks and bolts within reach.
func _choose(state: ClimbState) -> Dictionary:
	var best := {"dx": 0, "mode": "move"}
	var best_score := 1.0e9
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
		var score := cost + _lookahead(state, r, state.col + dx, 2)
		score += _protection_pull(state, r, state.col + dx)
		if hold.get("rest", false):
			score -= 4.0
		if score < best_score:
			best_score = score
			best = {"dx": dx, "mode": mode}
	return best


func _lookahead(state: ClimbState, r: int, c: int, depth: int) -> float:
	if depth == 0 or r + 1 > state.top_row:
		return 0.0
	var best := 1.0e6
	for dx in [-1, 0, 1]:
		var hold := state.hold_at(r + 1, c + dx)
		if hold.is_empty():
			continue
		var cost := float(hold.cost) * 0.9
		best = minf(best, cost + _lookahead(state, r + 1, c + dx, depth - 1))
	return 0.0 if best >= 1.0e6 else best


## Pulls toward the bolt line on bolted pitches, and toward cracks when the
## runout is long and there are cams left.
func _protection_pull(state: ClimbState, r: int, c: int) -> float:
	var pull := 0.0
	if not state.bolts.is_empty() and state.quickdraws_left > 0:
		var upcoming := r if state.bolts.has(r) else r + 1
		if state.bolts.has(upcoming) and not (Vector2i(int(state.bolts[upcoming]), upcoming) in state.clipped_bolts):
			pull += 6.0 * maxi(absi(int(state.bolts[upcoming]) - c) - 1, 0)
	if state.cams_left > 0 and state.runout() + (r - state.row) >= protect_at:
		if not state.hold_at(r, c).get("crack", false):
			pull += 2.5
	return pull
