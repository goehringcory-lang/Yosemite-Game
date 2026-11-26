extends Node
## The Landmark log: the park's big named features (walls, domes, peaks,
## falls, lakes), as opposed to the places you walk into (Discoveries).
##
## A landmark is first *sighted*, from a vista (Vistas.survey): the Logbook
## gets its name, where you first saw it from, and a line on how it looks from
## afar. Walking to its foot or its top (one of its "visit" areas) *visits*
## it, and the Logbook's entry opens up into a short naturalist's note.
## Nothing is listed until it's sighted or visited: the log fills in like a
## sketchbook, not a checklist.
##
## The list is res://data/park/landmarks.json: id (saved, never change it),
## name, hub, kind, visit (region ids), seen (the far-off line) and note.

signal sighted_one(landmark: Dictionary, from: String)
signal visited_one(landmark: Dictionary)
signal changed

const DATA := "res://data/park/landmarks.json"

## Landmark id -> the vista it was first sighted from (its title).
var sighted: Dictionary = {}
## Landmark id -> true, once walked to.
var visited: Dictionary = {}

var _list: Array[Dictionary] = []
var _by_id: Dictionary = {}
## region_id -> landmark ids you reach by walking in there.
var _by_region: Dictionary = {}


func _ready() -> void:
	add_to_group("persist")
	_load()


func start_new_game() -> void:
	sighted.clear()
	visited.clear()
	changed.emit()


func all() -> Array[Dictionary]:
	return _list


func get_landmark(id: String) -> Dictionary:
	return _by_id.get(id, {})


func total() -> int:
	return _list.size()


func is_sighted(id: String) -> bool:
	return sighted.has(id)


func is_visited(id: String) -> bool:
	return visited.has(id)


## Known at all (sighted or visited): only these show in the Logbook.
func is_known(id: String) -> bool:
	return sighted.has(id) or visited.has(id)


func known_count() -> int:
	var n := 0
	for landmark in _list:
		if is_known(landmark.id):
			n += 1
	return n


func visited_count() -> int:
	return visited.size()


## Sighted from vista [param from] (its title). True if it's new.
func sight(id: String, from: String) -> bool:
	if not _by_id.has(id) or sighted.has(id):
		return false
	sighted[id] = from
	sighted_one.emit(_by_id[id], from)
	changed.emit()
	return true


## The player is in [param region_id] (World, as they walk): visits the
## landmarks there not yet visited. Returns them.
func visit_region(region_id: String) -> Array[Dictionary]:
	var fresh: Array[Dictionary] = []
	for id: String in _by_region.get(region_id, []):
		if not visited.has(id):
			visited[id] = true
			fresh.append(_by_id[id])
			visited_one.emit(_by_id[id])
	if not fresh.is_empty():
		changed.emit()
	return fresh


func save_data() -> Dictionary:
	return {"sighted": sighted.duplicate(), "visited": visited.keys()}


func load_data(data: Dictionary) -> void:
	sighted.clear()
	visited.clear()
	var seen = data.get("sighted", {})
	if seen is Dictionary:
		for id in seen:
			sighted[str(id)] = str(seen[id])
	for id in data.get("visited", []):
		visited[str(id)] = true
	changed.emit()


func _load() -> void:
	if not FileAccess.file_exists(DATA):
		push_error("No landmark list at %s" % DATA)
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Could not read %s" % DATA)
		return
	for entry: Dictionary in data.get("landmarks", []):
		_list.append(entry)
		_by_id[str(entry.id)] = entry
		for region_id in entry.get("visit", []):
			(_by_region.get_or_add(str(region_id), []) as Array).append(str(entry.id))
