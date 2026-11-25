extends Node
## Booty on the wall: stuck pieces in the cracks of the routes, there to be
## found on the climbing screen. Somebody walked a cam too deep, or set a nut
## too hard, and left it; work it free (BootyCheck) and it goes on your rack
## for good. Each can be found once a game.
##
## The list is res://data/climb/wall_booty.json: id (saved, never change it),
## route, pitch (from 0), row (on the line), gear (a Gear id), width (the
## crack), name and text. Booty at the foot of the walls is a hidden find
## (Finds) instead.

signal found_one(booty: Dictionary)
signal changed

const DATA := "res://data/climb/wall_booty.json"

## Booty id -> the day it was found ("Y/S/D").
var found: Dictionary = {}

var _all: Array[Dictionary] = []


func _ready() -> void:
	add_to_group("persist")
	_load()


func start_new_game() -> void:
	found.clear()
	changed.emit()


func all() -> Array[Dictionary]:
	return _all


func is_found(id: String) -> bool:
	return found.has(id)


## The booty on [param route_id] nobody's taken yet, for ClimbState.set_booty.
func waiting(route_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b in _all:
		if b.route == route_id and not found.has(b.id):
			out.append(b)
	return out


## Takes [param booty]: its piece goes on your rack. False if it was found
## already. A size Gear doesn't know yet comes as a plain cam.
func take(booty: Dictionary) -> bool:
	var id := str(booty.get("id", ""))
	if id == "" or found.has(id):
		return false
	found[id] = "%d/%d/%d" % [GameClock.year, GameClock.season, GameClock.day]
	var gear_id := str(booty.get("gear", "cam"))
	if Gear.get_gear(gear_id) == null:
		gear_id = "cam"
	Gear.add(gear_id)
	found_one.emit(booty)
	changed.emit()
	return true


func save_data() -> Dictionary:
	return {"found": found.duplicate()}


func load_data(data: Dictionary) -> void:
	found.clear()
	var saved = data.get("found", {})
	if saved is Dictionary:
		for id in saved:
			found[str(id)] = str(saved[id])
	changed.emit()


func _load() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(DATA)) if FileAccess.file_exists(DATA) else null
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Could not read %s" % DATA)
		return
	for entry: Dictionary in data.get("booty", []):
		entry["id"] = str(entry.id)
		entry["pitch"] = int(entry.get("pitch", 0))
		entry["row"] = int(entry.get("row", 0))
		if entry.has("width"):
			entry["width"] = int(entry.width)
		_all.append(entry)
