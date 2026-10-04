extends Node
## Saves and loads the game as JSON in user://.
##
## Any node in the "persist" group that implements save_data() -> Dictionary
## and load_data(data: Dictionary) is saved automatically, keyed by node name.
## That includes nodes in regions the player has left (World keeps them in
## memory) and saved data for regions not visited yet this session, so give
## persist nodes names that are unique across regions.
## On Linux the file lives in ~/.local/share/godot/app_userdata/Yosemite Game/

## Tests point this at a separate file so they never touch a real save.
var save_path := "user://save.json"
const SAVE_VERSION := 1

## Saved data for persist nodes that weren't in the tree when the game
## loaded, by node name. World hands it over with restore() once they appear.
var _pending: Dictionary = {}


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func save_game() -> void:
	var nodes := _pending.duplicate()
	for node in _persist_nodes():
		nodes[node.name] = node.save_data()
	var data := {
		"version": SAVE_VERSION,
		"clock": GameClock.save_data(),
		"inventory": Inventory.save_data(),
		"nodes": nodes,
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write save file: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data, "\t"))


## Returns false if there is no valid save, so the caller can start a new game.
func load_game() -> bool:
	if not has_save():
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("Save file is corrupt; starting a new game.")
		return false
	GameClock.load_data(data.get("clock", {}))
	Inventory.load_data(data.get("inventory", {}))
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
	if not has_save():
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


func _persist_nodes() -> Array[Node]:
	var result: Array[Node] = get_tree().get_nodes_in_group("persist")
	for provider in get_tree().get_nodes_in_group("persist_provider"):
		result.append_array(provider.get_offstage_persist_nodes())
	return result


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
