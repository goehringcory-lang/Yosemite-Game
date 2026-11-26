class_name EffortSystem
extends ClimbSystem
## Interface (thread 4, pump, gas and food). Owns session.effort and prices
## everything: moves (from body's geometry) and other actions (a rope pull,
## a cam offered, a fall). Minutes in a cost are added to the clock by the
## director.

## Action kinds [method price_action] knows: rope_pull, clip, offer, place,
## chalk, fall, eat, rest, special.


func id() -> StringName:
	return &"effort"


## Fills move.cost from the move's geometry, with pump and gas multiplied by
## move.crux_cost. Pure.
func price(move: V2Move) -> void:
	move.cost = V2Cost.new()


## The cost of a non-move action of [param kind]; [param data] gives details
## (e.g. {"hand_hold": hold_id, "arms": 2}). Pure.
func price_action(_kind: StringName, _data := {}) -> V2Cost:
	return V2Cost.new()


## Spends pump and gas (minutes are the director's). Sends effort_changed.
func apply(cost: V2Cost) -> void:
	session.effort.pump = clampf(session.effort.pump + cost.pump, 0.0, 1.0)
	session.effort.gas = clampf(session.effort.gas - cost.gas, 0.0, session.effort.gas_cap)
	session.bus.send(&"effort_changed", [session.effort])


## Rests in a pose of [param kind] (BodySystem.rest_kind). Returns what the
## rest cost in time (minutes; pump usually comes back).
func rest(_kind: StringName) -> V2Cost:
	return V2Cost.new()


## Eats [param food_id] from the pack. False if it can't be eaten here.
func eat(_food_id: String) -> bool:
	return false


## The food worth eating now, or "" (query; the HUD and the eat verb use it).
func best_food() -> String:
	return ""


## True when the forearms are done: the next hard move or any hang will fail.
func pumped_out() -> bool:
	return session.effort.pump >= 1.0
