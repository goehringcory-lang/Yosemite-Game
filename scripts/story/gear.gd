extends Node
## The climbing gear the player owns, as gear id -> count.
##
## To add gear: create a GearData resource in res://data/gear/ and add it
## to GEAR below. Quests hand it out through their reward_gear.

signal changed
## Sent when the player gets new gear, so the HUD can show it.
signal added(id: String, amount: int)

const GEAR: Array[GearData] = [
	preload("res://data/gear/approach_shoes.tres"),
	preload("res://data/gear/climbing_shoes.tres"),
	preload("res://data/gear/chalk_bag.tres"),
	preload("res://data/gear/rope.tres"),
	preload("res://data/gear/harness.tres"),
	preload("res://data/gear/cam.tres"),
	preload("res://data/gear/quickdraw.tres"),
	preload("res://data/gear/belay_device.tres"),
	preload("res://data/gear/aiders.tres"),
	preload("res://data/gear/ascenders.tres"),
	preload("res://data/gear/haul_bag.tres"),
	preload("res://data/gear/portaledge.tres"),
	preload("res://data/gear/ice_axe.tres"),
	preload("res://data/gear/crampons.tres"),
	# Not climbing gear: a rod for the rivers, and Greg's flies (Fishing).
	preload("res://data/gear/fly_rod.tres"),
	preload("res://data/gear/elk_hair_caddis.tres"),
	preload("res://data/gear/parachute_adams.tres"),
	preload("res://data/gear/woolly_bugger.tres"),
	preload("res://data/gear/royal_wulff.tres"),
	# For nights out in the backcountry (Backcountry).
	preload("res://data/gear/bear_canister.tres"),
]

## You arrive with approach shoes. The Mountain Shop fits you with your
## first climbing kit (see the "shop_outfit" quest).
const STARTING_GEAR := {"approach_shoes": 1}

var owned: Dictionary = {}

var _by_id: Dictionary = {}


func _ready() -> void:
	add_to_group("persist")
	for gear: GearData in GEAR:
		_by_id[gear.id] = gear


func start_new_game() -> void:
	owned = STARTING_GEAR.duplicate()
	changed.emit()


func get_gear(id: String) -> GearData:
	return _by_id.get(id)


func count(id: String) -> int:
	return owned.get(id, 0)


func add(id: String, amount := 1) -> void:
	if get_gear(id) == null:
		push_error("Unknown gear id: %s" % id)
		return
	owned[id] = count(id) + amount
	changed.emit()
	added.emit(id, amount)


## True if the player owns everything in [param required] (gear id -> count).
func has_all(required: Dictionary) -> bool:
	return missing(required).is_empty()


## Human-readable list of what's missing, like ["Rope", "2 more Cams"].
func missing(required: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	for id: String in required:
		var short := int(required[id]) - count(id)
		if short <= 0:
			continue
		var name := get_gear(id).display_name if get_gear(id) else id
		result.append(name if short == 1 and count(id) == 0 else "%d more %s" % [short, name])
	return result


func save_data() -> Dictionary:
	return {"owned": owned}


func load_data(data: Dictionary) -> void:
	owned = {}
	var saved: Dictionary = data.get("owned", {})
	for id in saved:
		owned[str(id)] = int(saved[id])
	changed.emit()
