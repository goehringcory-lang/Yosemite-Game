class_name V2Effort
extends RefCounted
## How tired the climber is. Written only by effort (thread 4); every other
## system reads it. Nothing drains in real time: moves, clips and placements
## spend it, rests and food give it back.

## Forearm pump, 0 fresh to 1 can't hold on.
var pump := 0.0
## Whole-day energy, 0 empty to [member gas_cap]. Only food refills it.
var gas := 1.0
## The ceiling gas can be refilled to (real meals raise it, a long day lowers it).
var gas_cap := 1.0
## Water, 0..1 (hot sunny pitches drink it).
var water := 1.0


func copy() -> V2Effort:
	var e := V2Effort.new()
	e.pump = pump
	e.gas = gas
	e.gas_cap = gas_cap
	e.water = water
	return e


func to_dict() -> Dictionary:
	return {"pump": pump, "gas": gas, "gas_cap": gas_cap, "water": water}


static func from_dict(d: Dictionary) -> V2Effort:
	var e := V2Effort.new()
	e.pump = float(d.get("pump", 0.0))
	e.gas = float(d.get("gas", 1.0))
	e.gas_cap = float(d.get("gas_cap", 1.0))
	e.water = float(d.get("water", 1.0))
	return e
