extends Node
## The climbing gear the player owns, as gear id -> count, and where it is:
## in your gear bag, or hanging on the gear rack at camp (the cache).
##
## The bag holds BAG_ROOM of bulk (BULK: a rope is 4, a cam 1, a chalk bag
## nothing), and a haul bag in it adds HAUL_BAG_ROOM for the wall kit. Climbs,
## the fly rod and the bear canister only count what's in the bag
## ([method carried], [method missing_packed]); owning something
## ([method count], [method has_all]) is what shops and quests ask about.
## New gear that won't fit goes to the cache, and the rack at camp
## (CampPiece) packs and unpacks the bag. Tests that set [member owned]
## straight away have it all in the bag.
##
## To add gear: create a GearData resource in res://data/gear/ and add it
## to GEAR below. Quests hand it out through their reward_gear.

signal changed
## Sent when the player gets new gear, so the HUD can show it.
signal added(id: String, amount: int)
## Sent when new gear didn't fit in the bag and went to camp instead.
signal sent_to_camp(id: String, amount: int)

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
	# Camp anywhere: worn while it's in your bag (Backpacking, quest "hodges_pack_setup").
	preload("res://data/gear/backpacking_pack.tres"),
	# For winter: the Mountain Shop's down jacket (Warmth, quest "shop_puffy").
	preload("res://data/gear/puffy_jacket.tres"),
	# The camera Ansel Adams lends you, and his other lenses (Photos).
	preload("res://data/gear/camera.tres"),
	preload("res://data/gear/camera_lenses.tres"),
	# Utility trail headlamp earned by helping around the park (Perks).
	preload("res://data/gear/headlamp.tres"),
]

## You arrive with approach shoes. The Mountain Shop fits you with your
## first climbing kit (see the "shop_outfit" quest).
const STARTING_GEAR := {"approach_shoes": 1}

## How much room each piece takes in the gear bag. Anything not listed (the
## shoes on your feet, a chalk bag, a belay device, flies, the haul bag
## itself, Ansel's camera) takes none.
const BULK := {
	"rope": 4, "harness": 1, "climbing_shoes": 1, "cam": 1, "quickdraw": 1,
	"aiders": 1, "ascenders": 1, "portaledge": 4, "ice_axe": 2, "crampons": 2,
	"fly_rod": 2, "bear_canister": 3,
}
## The gear bag's room, and how much more a haul bag carries.
const BAG_ROOM := 24
const HAUL_BAG_ROOM := 12
## The order "Pack what fits" fills the bag in: the climbing kit first.
const PACK_ORDER := ["harness", "climbing_shoes", "rope", "cam", "quickdraw", "haul_bag",
	"aiders", "ascenders", "portaledge", "ice_axe", "crampons", "fly_rod", "bear_canister"]

var owned: Dictionary = {}
## What hangs on the gear rack at camp: gear id -> count (part of [member owned]).
var cached: Dictionary = {}

var _by_id: Dictionary = {}


func _ready() -> void:
	add_to_group("persist")
	for gear: GearData in GEAR:
		_by_id[gear.id] = gear


func start_new_game() -> void:
	owned = STARTING_GEAR.duplicate()
	cached = {}
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
	# what doesn't fit in the bag goes to the rack at camp
	var over := bag_used() - bag_room()
	var sent := 0
	if over > 0 and bulk(id) > 0:
		sent = mini(amount, ceili(over / float(bulk(id))))
		cached[id] = cached_count(id) + sent
	changed.emit()
	added.emit(id, amount)
	if sent > 0:
		sent_to_camp.emit(id, sent)


## Takes [param amount] of [param id] away (sold to a climber, GearSale):
## from the rack at camp first, where the spares hang, then the bag.
## Returns how many were taken.
func remove(id: String, amount := 1) -> int:
	var taken := mini(amount, count(id))
	if taken <= 0:
		return 0
	var from_rack := mini(taken, cached_count(id))
	if from_rack > 0:
		cached[id] = cached_count(id) - from_rack
		if cached[id] <= 0:
			cached.erase(id)
	owned[id] = count(id) - taken
	if owned[id] <= 0:
		owned.erase(id)
	changed.emit()
	return taken


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
		result.append(_short(short, count(id), name))
	return result


# ---------------------------------------------------------------- the bag

static func bulk(id: String) -> int:
	return int(BULK.get(id, 0))


## How many of [param id] hang on the rack at camp.
func cached_count(id: String) -> int:
	return mini(int(cached.get(id, 0)), count(id))


## How many of [param id] are in your gear bag.
func carried(id: String) -> int:
	return count(id) - cached_count(id)


## Everything in the bag, as gear id -> count (like [member owned]).
func carried_all() -> Dictionary:
	var kit := {}
	for id: String in owned:
		if carried(id) > 0:
			kit[id] = carried(id)
	return kit


func bag_room() -> int:
	return BAG_ROOM + (HAUL_BAG_ROOM if carried("haul_bag") > 0 else 0) + int(Perks.bonus("clean_pack"))


func bag_used() -> int:
	var used := 0
	for id: String in owned:
		used += carried(id) * bulk(id)
	return used


## True if anything hangs at camp.
func any_cached() -> bool:
	for id: String in cached:
		if cached_count(id) > 0:
			return true
	return false


## Takes up to [param amount] of [param id] off the rack into the bag, as
## many as fit; returns how many went in.
func pack(id: String, amount := 1) -> int:
	var n := mini(amount, cached_count(id))
	if bulk(id) > 0:
		n = mini(n, maxi(0, (bag_room() - bag_used()) / bulk(id)))
	if n <= 0:
		return 0
	cached[id] = cached_count(id) - n
	if cached[id] <= 0:
		cached.erase(id)
	changed.emit()
	return n


## Hangs up to [param amount] of [param id] from the bag on the rack; returns
## how many. The haul bag stays while the wall kit in it wouldn't fit without it.
func unpack(id: String, amount := 1) -> int:
	var n := mini(amount, carried(id))
	if id == "haul_bag" and n > 0 and bag_used() > BAG_ROOM:
		return 0
	if n <= 0:
		return 0
	cached[id] = cached_count(id) + n
	changed.emit()
	return n


## Packs everything that fits, climbing kit first; returns how many pieces.
func pack_all() -> int:
	var moved := 0
	var order: Array = PACK_ORDER.duplicate()
	for gear: GearData in GEAR:
		if not gear.id in order:
			order.append(gear.id)
	for id: String in order:
		moved += pack(id, cached_count(id))
	return moved


## Hangs everything up but what you'd want anyway (shoes on your feet, the
## chalk bag, flies: whatever takes no room); returns how many pieces.
func unpack_all() -> int:
	var moved := 0
	for id: String in owned.keys():
		if bulk(id) > 0:
			moved += unpack(id, carried(id))
	moved += unpack("haul_bag", carried("haul_bag"))
	return moved


## Packs the bag for a climb: hangs up what [param required] doesn't need,
## packs what it does (and a haul bag to carry it, if that helps), then fills
## what room is left. True if everything it needs is in the bag.
func pack_for(required: Dictionary) -> bool:
	unpack_all()
	var need := 0
	for id: String in required:
		need += int(required[id]) * bulk(id)
	if need > BAG_ROOM or required.has("haul_bag"):
		pack("haul_bag", 1)
	for id: String in PACK_ORDER:
		if required.has(id):
			pack(id, int(required[id]) - carried(id))
	for id: String in required:
		pack(id, int(required[id]) - carried(id))
	var ok := packed_all(required)
	pack_all()
	return ok


## True if the bag holds everything in [param required].
func packed_all(required: Dictionary) -> bool:
	return missing_packed(required).is_empty()


## Like [method missing], for what's in the bag.
func missing_packed(required: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	for id: String in required:
		var short := int(required[id]) - carried(id)
		if short <= 0:
			continue
		var name := get_gear(id).display_name if get_gear(id) else id
		result.append(_short(short, carried(id), name))
	return result


## The line a climb says when gear it needs is
## on the rack at camp, not in the bag: "Your rope and 2 cams are on the gear
## rack at camp." Empty if none of it is there.
func at_camp_line(required: Dictionary) -> String:
	var parts := PackedStringArray()
	var pieces := 0
	for id: String in required:
		var short := mini(int(required[id]) - carried(id), cached_count(id))
		if short <= 0:
			continue
		pieces += short
		var name := get_gear(id).display_name if get_gear(id) else id
		parts.append(("your " + name.to_lower()) if short == 1 and count(id) == 1 else ItemDB.count_name(short, name.to_lower()))
	if parts.is_empty():
		return ""
	var what := parts[0] if parts.size() == 1 else ", ".join(parts.slice(0, parts.size() - 1)) + " and " + parts[parts.size() - 1]
	return "%s %s on the gear rack at camp." % [what.left(1).to_upper() + what.substr(1), "are" if pieces > 1 else "is"]


## "Rope", or "2 more Cams": [param short] of [param name] still wanted,
## with [param have] already there.
static func _short(short: int, have: int, name: String) -> String:
	if short == 1 and have == 0:
		return name
	return "%d more %s" % [short, name if short == 1 else ItemDB.count_name(short, name).substr(str(short).length() + 1)]


func save_data() -> Dictionary:
	return {"owned": owned, "cached": cached}


func load_data(data: Dictionary) -> void:
	owned = {}
	var saved: Dictionary = data.get("owned", {})
	for id in saved:
		owned[str(id)] = int(saved[id])
	# a save from before the bag: everything is in it (over its room, maybe,
	# until you next pack at the rack)
	cached = {}
	var hung: Dictionary = data.get("cached", {})
	for id in hung:
		if int(hung[id]) > 0:
			cached[str(id)] = int(hung[id])
	changed.emit()
