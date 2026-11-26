extends Node
## Hidden finds off the beaten path: a cam stuck at the foot of El Capitan, a
## six-pack of King Cobra cooling in a Camp 4 creek, a railroad spike on the
## old El Portal grade. Each lies somewhere away from the roads and trails,
## only half showing (FindSpot: the thing itself in the grass, and now and
## then a cool blue twinkle unlike a forage find's gold one), and can be taken
## once. Some only show at the right time: in the right seasons, or at night.
##
## Nothing points at them. The Logbook's Finds page counts them area by area
## once you've found one there, and passes on a rumor or two you've "heard"
## about finds in areas you've already walked into, which say roughly where
## to look and when (never the spot).
##
## The list is res://data/park/finds.json. Each find: id (saved, never
## change it), region, pos (in the region's own pixels), title, text (shown
## when you take it), rumor, reward ({item or gear id: count}), and optional
## seasons (GameClock.Season names) and hours ([from, to), wrapping midnight).
## tools/discovery/find_spots.tscn suggests open, off-path spots for new
## finds; tests/finds_test.tscn checks each one can be walked to.

signal found_one(find: Dictionary)
signal changed

const DATA := "res://data/park/finds.json"
const SEASONS := {"spring": GameClock.Season.SPRING, "summer": GameClock.Season.SUMMER,
	"fall": GameClock.Season.FALL, "winter": GameClock.Season.WINTER}
## How many rumors the Logbook passes on at once.
const RUMORS := 3

## Find id -> the day it was found (GameClock.day_count style "Y/S/D" text).
var found: Dictionary = {}

var _finds: Array[Dictionary] = []
var _by_id: Dictionary = {}


func _ready() -> void:
	add_to_group("persist")
	_load()


func start_new_game() -> void:
	found.clear()
	changed.emit()


func all() -> Array[Dictionary]:
	return _finds


func get_find(id: String) -> Dictionary:
	return _by_id.get(id, {})


func total() -> int:
	return _finds.size()


func count() -> int:
	return found.size()


func is_found(id: String) -> bool:
	return found.has(id)


## The finds in [param region_id], in the list's order.
func in_region(region_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for find in _finds:
		if find.region == region_id:
			result.append(find)
	return result


## Is [param find] lying there right now (its season and hours)?
static func is_out(find: Dictionary) -> bool:
	var seasons: Array = find.get("seasons", [])
	if not seasons.is_empty():
		var any := false
		for name: String in seasons:
			if SEASONS.get(name, -1) == GameClock.season:
				any = true
		if not any:
			return false
	var hours: Array = find.get("hours", [])
	if hours.size() == 2 and not GameClock.hour_in_range(int(hours[0]), int(hours[1])):
		return false
	return true


## Takes find [param id]: hands over its reward and marks it found. False if
## it was found already or isn't a find.
func take(id: String) -> bool:
	if found.has(id) or not _by_id.has(id):
		return false
	var find: Dictionary = _by_id[id]
	found[id] = "%d/%d/%d" % [GameClock.year, GameClock.season, GameClock.day]
	for reward_id: String in find.get("reward", {}):
		var amount := int(find.reward[reward_id])
		if Gear.get_gear(reward_id):
			Gear.add(reward_id, amount)
		else:
			Inventory.add(reward_id, amount)
	found_one.emit(find)
	changed.emit()
	return true


## What a find gives, for its card: "1 Cam", "3 King Cobras".
static func reward_text(find: Dictionary) -> String:
	var parts := PackedStringArray()
	for reward_id: String in find.get("reward", {}):
		var amount := int(find.reward[reward_id])
		var gear: GearData = Gear.get_gear(reward_id)
		var item: ItemData = ItemDB.get_item(reward_id) if gear == null else null
		var name := gear.display_name if gear else (item.display_name if item else reward_id)
		parts.append(ItemDB.count_name(amount, name))
	return ", ".join(parts)


## The icon a find shows on the ground: its first reward's.
static func icon_of(find: Dictionary) -> Texture2D:
	for reward_id: String in find.get("reward", {}):
		var gear: GearData = Gear.get_gear(reward_id)
		if gear:
			return gear.icon
		var item: ItemData = ItemDB.get_item(reward_id)
		if item:
			return item.icon
	return null


## A gear cache (Vistas): seen glinting from a vista, which passes on its
## rumor; otherwise it lies like any find.
static func is_cache(find: Dictionary) -> bool:
	return bool(find.get("cache", false)) and str(find.get("vista", "")) != ""


## How many hidden-find rumors the Logbook passes on at once.
func rumor_limit() -> int:
	return RUMORS + (2 if Perks.has("trail_sense") else 0)


## The lines about caches seen glinting from a vista you've taken in, then up
## to rumor_limit() hints about finds not yet found, in areas you've walked into.
## The same few stay until one is found, so they don't shuffle each visit.
func rumors() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	# a gear cache's line comes from its vista, once you've taken in the view
	for find in _finds:
		if is_cache(find) and not found.has(find.id) and Vistas.is_surveyed(str(find.vista)):
			result.append(find)
	var limit := rumor_limit() + result.size()
	for find in _finds:
		if result.size() >= limit:
			break
		if found.has(find.id) or str(find.get("rumor", "")) == "" or is_cache(find):
			continue
		if Discoveries.is_found(Discoveries.key_for(find.region, _region_name(find.region))):
			result.append(find)
	return result


## An area's own name on the place list (its first entry).
func _region_name(region_id: String) -> String:
	for place: Dictionary in Discoveries.places():
		if place.region == region_id:
			return place.name
	return ""


## Adds a FindSpot for every find in [param region] not yet found (StoryContent).
func dress(region: Region) -> void:
	if region.indoors:
		return
	for find in in_region(region.region_id):
		if found.has(find.id) or not find.has("pos"):
			continue
		var spot := FindSpot.new()
		spot.find_id = find.id
		spot.name = "Find_" + find.id
		spot.position = Vector2(find.pos[0], find.pos[1])
		region.entities.add_child(spot)


func save_data() -> Dictionary:
	return {"found": found.duplicate()}


func load_data(data: Dictionary) -> void:
	found.clear()
	var saved = data.get("found", {})
	if saved is Dictionary:
		for id in saved:
			found[str(id)] = str(saved[id])
	# (spots already laid out for finds now found see to themselves: FindSpot)
	changed.emit()


func _load() -> void:
	if not FileAccess.file_exists(DATA):
		push_error("No finds list at %s" % DATA)
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Could not read %s" % DATA)
		return
	for entry: Dictionary in data.get("finds", []):
		_finds.append(entry)
		_by_id[str(entry.id)] = entry
