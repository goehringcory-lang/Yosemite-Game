class_name EffortStub
extends EffortSystem
## Stand-in pump and gas until thread 4's land (and kept for tests): small
## holds and stretched moves pump you, feet on holds help, jugs and stances
## rest, food refills gas.

const ACTIONS := {
	&"rope_pull": [0.02, 0.0, 0], &"clip": [0.01, 0.0, 1], &"offer": [0.03, 0.0, 1],
	&"place": [0.02, 0.002, 1], &"chalk": [-0.02, 0.0, 1], &"fall": [0.08, 0.02, 5],
	&"eat": [0.0, 0.0, 3], &"rest": [0.0, 0.0, 2], &"special": [0.05, 0.01, 5],
}


func id() -> StringName:
	return &"effort"


func price(move: V2Move) -> void:
	var h := session.wall.hold(move.hold_id)
	var size := h.size if h else 0.5
	var c := V2Cost.new()
	c.pump = (0.02 + 0.05 * (1.0 - size) + 0.05 * move.strain - 0.02 * move.security) * session.mods.pump_mult
	c.gas = 0.004 * session.mods.gas_mult
	c.minutes = 1
	move.cost = c


func price_action(kind: StringName, _data := {}) -> V2Cost:
	var a: Array = ACTIONS.get(kind, [0.0, 0.0, 0])
	return V2Cost.make(float(a[0]) * session.mods.pump_mult, float(a[1]) * session.mods.gas_mult, int(a[2]))


func rest(kind: StringName) -> V2Cost:
	if kind == &"":
		return V2Cost.new()
	var back: float = {&"stance": 0.4, &"hang": 0.4, &"belay": 1.0}.get(kind, 0.25)
	session.effort.pump = maxf(0.0, session.effort.pump - back)
	session.bus.send(&"rested", [kind])
	session.bus.send(&"effort_changed", [session.effort])
	return price_action(&"rest")


func best_food() -> String:
	var db := _food_db()
	if db == null:
		return ""
	var foods: Array[String] = db.edible_in_inventory()
	return foods[0] if not foods.is_empty() else ""


func eat(food_id: String) -> bool:
	var db := _food_db()
	var inv: Node = Engine.get_main_loop().root.get_node_or_null("/root/Inventory") if Engine.get_main_loop() is SceneTree else null
	if db == null or inv == null or food_id == "" or not inv.remove(food_id, 1):
		return false
	var gas := float(db.energy(food_id)) / 100.0
	session.effort.gas = minf(session.effort.gas_cap, session.effort.gas + gas)
	session.bus.send(&"food_eaten", [food_id, gas])
	session.bus.send(&"effort_changed", [session.effort])
	return true


func _food_db() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/FoodDB") if Engine.get_main_loop() is SceneTree else null
