extends Node
## Saves and loads the game as JSON in user://.
##
## Any node in the "persist" group that implements save_data() -> Dictionary
## and load_data(data: Dictionary) is saved automatically, keyed by node name.
## That includes nodes in regions the player has left (World keeps them in
## memory) and saved data for regions not visited yet this session, so give
## persist nodes names that are unique across regions.
## On Linux the file lives in ~/.local/share/godot/app_userdata/Valley Days/
## (a save from when the game was called Yosemite Game is copied over; see
## OldUserDir).

## How many save slots there are. Each slot is its own game.
const SLOTS := 3
const SAVE_VERSION := 1

## Slot 1's file. Slots 2 and 3 sit beside it (save_2.json, save_3.json), so a
## save from before there were slots is slot 1.
var base_path := "user://save.json"
## The slot the game saves to and loads from (1 to SLOTS). The title screen
## picks it; saving into another slot from the pause menu moves the game there.
var slot := 1
## The current slot's file. Tests point this at a separate file so they never
## touch a real save; setting it picks slot 1 of that file.
var save_path: String:
	get:
		return slot_path(slot)
	set(value):
		base_path = value
		slot = 1


func _init() -> void:
	OldUserDir.migrate()

## Saved data for persist nodes that weren't in the tree when the game
## loaded, by node name. World hands it over with restore() once they appear.
var _pending: Dictionary = {}
## True after New Game on the title screen: World starts fresh and ignores the
## old save, which stays on disk until the first night's sleep replaces it.
var _fresh := false


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


## The file for save slot [param n] (1 to SLOTS).
func slot_path(n: int) -> String:
	if n <= 1:
		return base_path
	return "%s_%d.%s" % [base_path.get_basename(), n, base_path.get_extension()]


func slot_used(n: int) -> bool:
	return FileAccess.file_exists(slot_path(n))


## True when any slot holds a game.
func any_save() -> bool:
	for n in range(1, SLOTS + 1):
		if slot_used(n):
			return true
	return false


## The slot saved most recently, for Continue (0 when there is no save that
## can be read).
func latest_slot() -> int:
	var best := 0
	var best_time := -1
	for n in range(1, SLOTS + 1):
		var info := slot_info(n)
		if info.is_empty() or info.get("broken", false):
			continue
		var at := int(info.get("saved_at", 0))
		if at <= 0:
			at = FileAccess.get_modified_time(slot_path(n))
		if at > best_time:
			best = n
			best_time = at
	return best


## The first slot with no game in it (0 when all are used).
func first_empty_slot() -> int:
	for n in range(1, SLOTS + 1):
		if not slot_used(n):
			return n
	return 0


## What the save menus show about slot [param n]: {} when it's empty, else
## "date" ("Spring 4 (Thu), Year 1"), "time" ("2:15 PM"), "place", and
## "saved_at" (Unix time; 0 for a save from before slots). A save file that
## can't be read gives {"broken": true}.
func slot_info(n: int) -> Dictionary:
	if not slot_used(n):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(slot_path(n)))
	if typeof(data) != TYPE_DICTIONARY:
		return {"broken": true}
	var clock: Dictionary = data.get("clock", {}) if typeof(data.get("clock")) == TYPE_DICTIONARY else {}
	var season := clampi(int(clock.get("season", 0)), 0, GameClock.SEASON_NAMES.size() - 1)
	var day := maxi(int(clock.get("day", 1)), 1)
	var minutes := int(clock.get("minutes", GameClock.DAY_START_HOUR * 60))
	var hour := (minutes / 60) % 24
	var h12 := 12 if hour % 12 == 0 else hour % 12
	var summary: Dictionary = data.get("summary", {}) if typeof(data.get("summary")) == TYPE_DICTIONARY else {}
	return {
		"date": "%s %d (%s), Year %d" % [GameClock.SEASON_NAMES[season], day, GameClock.WEEKDAY_NAMES[(day - 1) % 7], maxi(int(clock.get("year", 1)), 1)],
		"time": "%d:%02d %s" % [h12, minutes % 60, "AM" if hour < 12 else "PM"],
		"place": str(summary.get("place", "")),
		"name": str(summary.get("name", "")),
		"saved_at": int(summary.get("saved_at", 0)),
	}


## Removes the game in slot [param n].
func delete_slot(n: int) -> void:
	if slot_used(n):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path(n)))


## Makes the next World start a new game even though a save exists.
func start_fresh() -> void:
	_fresh = true


## Takes start_fresh() back (New Game was backed out of before it began).
func cancel_fresh() -> void:
	_fresh = false


## Returns false if the file couldn't be written.
func save_game() -> bool:
	var nodes := _pending.duplicate()
	for node in _persist_nodes():
		nodes[node.name] = node.save_data()
	var data := {
		"version": SAVE_VERSION,
		"clock": GameClock.save_data(),
		"inventory": Inventory.save_data(),
		"player": PlayerLook.save_data(),
		"nodes": nodes,
		"summary": _summary(),
	}
	# Written beside the save first and only then moved over it, so a crash,
	# a quit or a full disk part way through leaves the last good save as it
	# was (a broken save starts a new game, which the next sleep saves over).
	var text := JSON.stringify(data, "\t")
	var temp := save_path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		push_error("Could not write save file: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(text)
	file.close()
	if FileAccess.get_file_as_string(temp) != text:
		push_error("Could not write save file: the copy on disk is incomplete (is the disk full?)")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp))
		return false
	var moved := DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(save_path))
	if moved != OK:
		push_error("Could not write save file: %s" % error_string(moved))
		return false
	_fresh = false
	return true


## Returns false if there is no valid save, so the caller can start a new game.
func load_game() -> bool:
	if _fresh or not has_save():
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("Save file is corrupt; starting a new game.")
		return false
	GameClock.load_data(data.get("clock", {}))
	Inventory.load_data(data.get("inventory", {}))
	# a game saved before you could choose a look loads as the look it had
	PlayerLook.load_data(data.get("player", {}) if typeof(data.get("player")) == TYPE_DICTIONARY else {})
	var nodes: Dictionary = data.get("nodes", {})
	_pending = nodes.duplicate()
	for node in get_tree().get_nodes_in_group("persist"):
		if nodes.has(node.name):
			node.load_data(nodes[node.name])
			_pending.erase(node.name)
	return true


## Reads one node's saved data without loading the game. World uses it to
## load the saved region before anything else.
func peek_node(node_name: String) -> Dictionary:
	if _fresh or not has_save():
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	var nodes: Dictionary = data.get("nodes", {})
	var node_data = nodes.get(node_name, {})
	return node_data if typeof(node_data) == TYPE_DICTIONARY else {}


## Loads saved data into persist nodes under [param root] that weren't in
## the tree at load time (for example a region entered for the first time).
func restore(root: Node) -> void:
	for node in root.find_children("*", "", true, false):
		if node.is_in_group("persist") and _pending.has(node.name):
			node.load_data(_pending[node.name])
			_pending.erase(node.name)


## Forgets saved data that hasn't been restored yet, for a new game.
func clear_pending() -> void:
	_pending.clear()


## A little about the game for the save menus, so they needn't load it.
func _summary() -> Dictionary:
	var summary := {"saved_at": int(Time.get_unix_time_from_system()), "name": PlayerLook.player_name}
	var world := get_tree().get_first_node_in_group("world")
	if world and world.has_method("location_name"):
		summary["place"] = world.location_name()
	return summary


func _persist_nodes() -> Array[Node]:
	var result: Array[Node] = get_tree().get_nodes_in_group("persist")
	for provider in get_tree().get_nodes_in_group("persist_provider"):
		result.append_array(provider.get_offstage_persist_nodes())
	return result


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
