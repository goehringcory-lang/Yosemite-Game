class_name V2Rack
extends RefCounted
## What's on the harness for this climb: cams, nuts, draws, slings. Built by
## the director from Gear when the climb starts. Changed only through
## [method take] and [method give_back]: rope takes draws and slings, gear
## takes cams and nuts, the partner gives pieces back when cleaning at the
## belay (see CONTRACTS.md).

## Each item: {id, kind (cam|nut|draw|sling|offset|pin), width_min,
## width_max, count, name, color}. Racked order = harness order (the gear
## tent decides it): earlier items come to hand faster.
var items: Array[Dictionary] = []


## Fills the rack from what you carry (Gear.rack_carried()) plus draws and
## slings. [param draws] -1 counts the quickdraws you carry.
static func from_gear(draws := -1, slings := 4) -> V2Rack:
	var r := V2Rack.new()
	var gear: Node = Engine.get_main_loop().root.get_node_or_null("/root/Gear") if Engine.get_main_loop() is SceneTree else null
	if gear and gear.has_method("rack_carried"):
		for item: Dictionary in gear.rack_carried():
			r.items.append(item.duplicate())
	if draws < 0:
		draws = int(gear.carried("quickdraw")) if gear and gear.has_method("carried") else 8
	r.items.append({"id": "quickdraw", "kind": "draw", "width_min": -1, "width_max": -1, "count": draws, "name": "Quickdraw"})
	r.items.append({"id": "sling", "kind": "sling", "width_min": -1, "width_max": -1, "count": slings, "name": "Sling"})
	return r


func count(item_id: String) -> int:
	for item in items:
		if item.id == item_id:
			return int(item.count)
	return 0


func item(item_id: String) -> Dictionary:
	for it in items:
		if it.id == item_id:
			return it
	return {}


## Items of [param kind] with any left.
func of_kind(kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for it in items:
		if it.kind == kind and int(it.count) > 0:
			out.append(it)
	return out


## Takes one [param item_id] off the harness. False if none is left.
func take(item_id: String) -> bool:
	for it in items:
		if it.id == item_id and int(it.count) > 0:
			it.count = int(it.count) - 1
			return true
	return false


## Puts one back (cleaned at the belay, or a piece that popped and stayed on
## the rope).
func give_back(item_id: String) -> void:
	for it in items:
		if it.id == item_id:
			it.count = int(it.count) + 1
			return


func to_dict() -> Dictionary:
	var out := []
	for it in items:
		var d := it.duplicate()
		if d.has("color"):
			d.color = (d.color as Color).to_html() if d.color is Color else d.color
		out.append(d)
	return {"items": out}


static func from_dict(d: Dictionary) -> V2Rack:
	var r := V2Rack.new()
	for it: Dictionary in d.get("items", []):
		r.items.append(it.duplicate())
	return r
