class_name V2Cost
extends RefCounted
## What an action spends: pump, gas and minutes. Effort (thread 4) prices
## actions and applies costs; anything else that costs (a rope pull, a cam
## offered, a fall) asks effort to price it.

var pump := 0.0
var gas := 0.0
var minutes := 0


static func make(p_pump := 0.0, p_gas := 0.0, p_minutes := 0) -> V2Cost:
	var c := V2Cost.new()
	c.pump = p_pump
	c.gas = p_gas
	c.minutes = p_minutes
	return c


func plus(other: V2Cost) -> V2Cost:
	return make(pump + other.pump, gas + other.gas, minutes + other.minutes)


func to_dict() -> Dictionary:
	return {"pump": pump, "gas": gas, "minutes": minutes}


static func from_dict(d: Dictionary) -> V2Cost:
	return make(float(d.get("pump", 0.0)), float(d.get("gas", 0.0)), int(d.get("minutes", 0)))
