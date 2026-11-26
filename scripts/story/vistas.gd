extends Node
## Vistas: the park's high lookouts (Tunnel View, Glacier Point, Sentinel
## Dome, Olmsted Point, the Crane Flat fire lookout...), like the towers of a
## big open-world game. Each is a spot in its area (VistaSpot: a railing, a
## survey benchmark, a lookout's catwalk) where you stop and "take in the
## view": a panorama (VistaView) pans across what you can really see from
## there and names it, one landmark at a time.
##
## Taking in a view, the first time:
## - puts the place names of the areas below on the area map (Discoveries
##   .sight_regions), and fills in the park map around it (MapFog, if the
##   map has it),
## - sights its landmarks in the Landmark log (Landmarks),
## - and writes a line in the Logbook about something that caught the light
##   down below: a gear cache (a find in finds.json with "vista": this id),
##   never pinned on a map.
## Then the peak-finder: which one is that? Name it right for a stamp.
##
## The list is res://data/park/vistas.json (see its _note).

signal surveyed_one(vista: Dictionary)
signal changed

const DATA := "res://data/park/vistas.json"

## Vista id -> the day it was first taken in ("Y/S/D").
var surveyed: Dictionary = {}
## Vista id -> true once its peak-finder question was answered right.
var named: Dictionary = {}

var _vistas: Array[Dictionary] = []
var _by_id: Dictionary = {}


func _ready() -> void:
	add_to_group("persist")
	_load()


func start_new_game() -> void:
	surveyed.clear()
	named.clear()
	changed.emit()


func all() -> Array[Dictionary]:
	return _vistas


func get_vista(id: String) -> Dictionary:
	return _by_id.get(id, {})


func total() -> int:
	return _vistas.size()


func count() -> int:
	return surveyed.size()


func is_surveyed(id: String) -> bool:
	return surveyed.has(id)


func is_named(id: String) -> bool:
	return named.has(id)


func named_count() -> int:
	return named.size()


func in_region(region_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for vista in _vistas:
		if vista.region == region_id:
			result.append(vista)
	return result


## Takes in vista [param id]: sights its areas and landmarks, opens the park
## map around it, and hints its cache. Returns what was new:
## {first, places (areas newly on the map), landmarks (ids newly sighted)}.
## Safe to call again: a second look changes nothing.
func survey(id: String) -> Dictionary:
	var result := {"first": false, "places": 0, "landmarks": []}
	if not _by_id.has(id):
		return result
	var vista: Dictionary = _by_id[id]
	if not surveyed.has(id):
		surveyed[id] = "%d/%d/%d" % [GameClock.year, GameClock.season, GameClock.day]
		result.first = true
	result.places = Discoveries.sight_regions(vista.get("sights", []))
	for landmark_id in vista.get("landmarks", []):
		if Landmarks.sight(str(landmark_id), str(vista.title)):
			(result.landmarks as Array).append(str(landmark_id))
	_reveal_map(vista)
	if result.first:
		surveyed_one.emit(vista)
		changed.emit()
	return result


## The park map's fog (the map thread's MapFog autoload), if this build has it.
func _reveal_map(vista: Dictionary) -> void:
	var fog := get_node_or_null("/root/MapFog")
	var lonlat: Array = vista.get("lonlat", [])
	if fog and fog.has_method("reveal") and lonlat.size() == 2:
		fog.reveal(Vector2(float(lonlat[0]), float(lonlat[1])), float(vista.get("radius_m", 5000.0)))


## The peak-finder's question for [param id]: {answer, options} with the
## right name and two others from the same view, shuffled by the vista's id
## (so a second try asks the same way). Empty if it has none.
func quiz(id: String) -> Dictionary:
	var vista := get_vista(id)
	var answer := str(vista.get("quiz", ""))
	if answer == "":
		return {}
	var others: Array[String] = []
	# (other heights in the same view: not the river or the lake below)
	for landmark_id in vista.get("landmarks", []):
		var kind := str(Landmarks.get_landmark(str(landmark_id)).get("kind", ""))
		if str(landmark_id) != answer and not kind in ["river", "lake", "meadow", "canyon", "grove", "dam"]:
			others.append(str(landmark_id))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	# a view with few heights in it borrows names from elsewhere in the park
	if others.size() < 2:
		var spare: Array[String] = []
		for landmark: Dictionary in Landmarks.all():
			if str(landmark.kind) in ["dome", "peak"] and str(landmark.id) != answer and not str(landmark.id) in others:
				spare.append(str(landmark.id))
		while others.size() < 2 and not spare.is_empty():
			others.append(spare.pop_at(rng.randi_range(0, spare.size() - 1)))
	var options: Array[String] = [answer]
	while options.size() < 3 and not others.is_empty():
		options.append(others.pop_at(rng.randi_range(0, others.size() - 1)))
	for i in range(options.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := options[i]
		options[i] = options[j]
		options[j] = t
	return {"answer": answer, "options": options}


## Answers the peak-finder: true if [param landmark_id] is right.
func answer(id: String, landmark_id: String) -> bool:
	var right := str(get_vista(id).get("quiz", "")) == landmark_id
	if right and not named.has(id):
		named[id] = true
		changed.emit()
	return right


## Adds a VistaSpot for each vista in [param region] (StoryContent).
func dress(region: Region) -> void:
	if region.indoors:
		return
	for vista in in_region(region.region_id):
		if not vista.has("pos"):
			continue
		var spot := VistaSpot.new()
		spot.vista_id = vista.id
		spot.name = "Vista_" + vista.id
		spot.position = Vector2(vista.pos[0], vista.pos[1])
		region.entities.add_child(spot)


func save_data() -> Dictionary:
	return {"surveyed": surveyed.duplicate(), "named": named.keys()}


func load_data(data: Dictionary) -> void:
	surveyed.clear()
	named.clear()
	var saved = data.get("surveyed", {})
	if saved is Dictionary:
		for id in saved:
			surveyed[str(id)] = str(saved[id])
	for id in data.get("named", []):
		named[str(id)] = true
	changed.emit()


func _load() -> void:
	if not FileAccess.file_exists(DATA):
		push_error("No vista list at %s" % DATA)
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Could not read %s" % DATA)
		return
	for entry: Dictionary in data.get("vistas", []):
		_vistas.append(entry)
		_by_id[str(entry.id)] = entry
