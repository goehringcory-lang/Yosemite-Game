extends Node
## Exploring the park: every named place outdoors (each area, and the spots
## named inside it, like Sentinel Beach or the Yosemite Medical Clinic) is
## undiscovered until you first walk into it. The first time, a card says so
## with the tally ("Discovered: Sentinel Beach, 12 of 140"), the Valley's area
## map turns its "?" into the place's name, and the Logbook counts it.
##
## From a high lookout (VIEWPOINTS: Tunnel View, Glacier Point, the top of
## Half Dome) the whole Valley lies spread out below, so arriving at one puts
## every place's name on the Valley's area map, still to be walked to.
##
## The list of places is res://data/park/places.json, written by
## tools/discovery/list_places.tscn from the region scenes and their story
## overlays: run it again after adding or renaming a Place.

signal discovered(entry: Dictionary)
signal changed

const DATA := "res://data/park/places.json"
## Regions whose view takes in the whole Valley.
const VIEWPOINTS := ["tunnel_view", "glacier_point", "half_dome"]

## Keys ("region_id/Place Name") of the places found so far.
var found: Dictionary = {}
## Seen the Valley from above: every place shows on its area map.
var valley_seen := false

## Every place, in the list's order: {key, name, region, hub}.
var _places: Array[Dictionary] = []
var _by_key: Dictionary = {}
## Display name -> keys with that name, for the area map's signs.
var _by_name: Dictionary = {}


func _ready() -> void:
	add_to_group("persist")
	_load_places()


func start_new_game() -> void:
	found.clear()
	valley_seen = false
	changed.emit()


func total() -> int:
	return _places.size()


func count() -> int:
	return found.size()


func places() -> Array[Dictionary]:
	return _places


static func key_for(region_id: String, place_name: String) -> String:
	return "%s/%s" % [region_id, place_name]


func is_found(key: String) -> bool:
	return found.has(key)


## Has a place by this name been walked to, anywhere?
func is_name_found(place_name: String) -> bool:
	for key: String in _by_name.get(place_name, []):
		if found.has(key):
			return true
	return false


## Is this name on the list at all (so the area map should hide it until found)?
func is_listed_name(place_name: String) -> bool:
	return _by_name.has(place_name)


## Called as the player walks about: finds the region and the place they're
## in, if they're new. Returns the entries found this time.
func visit(region: Region, place: Place) -> Array[Dictionary]:
	var fresh: Array[Dictionary] = []
	if region == null or region.indoors:
		return fresh
	var keys := [key_for(region.region_id, region.display_name)]
	if place and place.radius > 0.0:
		keys.append(key_for(region.region_id, place.display_name))
	for key: String in keys:
		if _by_key.has(key) and not found.has(key):
			found[key] = true
			var entry: Dictionary = _by_key[key].duplicate()
			entry["count"] = found.size()
			entry["total"] = _places.size()
			fresh.append(entry)
			discovered.emit(entry)
	if region.region_id in VIEWPOINTS and not valley_seen:
		valley_seen = true
		fresh.append({"viewpoint": true, "name": region.display_name})
	if not fresh.is_empty():
		changed.emit()
	return fresh


func save_data() -> Dictionary:
	return {"found": found.keys(), "valley_seen": valley_seen}


func load_data(data: Dictionary) -> void:
	found.clear()
	for key in data.get("found", []):
		found[str(key)] = true
	valley_seen = bool(data.get("valley_seen", false))
	changed.emit()


func _load_places() -> void:
	if not FileAccess.file_exists(DATA):
		push_warning("No place list yet. Run tools/discovery/list_places.tscn to build %s." % DATA)
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Could not read %s" % DATA)
		return
	for entry: Dictionary in data.get("places", []):
		var place := {"key": str(entry.key), "name": str(entry.name), "region": str(entry.region), "hub": str(entry.hub)}
		_places.append(place)
		_by_key[place.key] = place
		(_by_name.get_or_add(place.name, []) as Array).append(place.key)


## A small folded park map, for the discovery card.
static func icon() -> Texture2D:
	var im := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var ink := Color("3a2a1c")
	var paper := [Color("e8d8b0"), Color("d4c08e"), Color("e8d8b0")]
	for panel in 3:
		for y in range(2 + (panel % 2), 14 + (panel % 2)):
			for x in range(1 + panel * 5, 6 + panel * 5):
				im.set_pixel(x, y, paper[panel])
	# a trail across the panels, and a red pin
	for x in range(2, 15):
		var y := 9 - int(round(sin(x * 0.7) * 2.0))
		im.set_pixel(x, y, Color("6e8a52"))
	for p in [Vector2i(10, 4), Vector2i(9, 5), Vector2i(10, 5), Vector2i(11, 5), Vector2i(10, 6), Vector2i(10, 7)]:
		im.set_pixelv(p, Color("b8402e"))
	# outline
	for y in 16:
		for x in 16:
			if im.get_pixel(x, y).a == 0.0:
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n := Vector2i(x, y) + d
					if n.x >= 0 and n.y >= 0 and n.x < 16 and n.y < 16 and im.get_pixelv(n).a > 0.0 and im.get_pixelv(n) != ink:
						im.set_pixel(x, y, ink)
						break
	return ImageTexture.create_from_image(im)
