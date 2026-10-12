class_name OldUserDir
## The game was called "Yosemite Game" before it was named Valley Days, and
## Godot keeps a game's files in a folder named after it. On the first run
## under the new name this copies the save and settings across, so nobody
## loses their game. It never overwrites a file already in the new folder.

const OLD_NAME := "Yosemite Game"
const FILES := ["save.json", "settings.cfg"]

static var _done := false


static func migrate() -> void:
	if _done:
		return
	_done = true
	var new_dir := OS.get_user_data_dir()
	var old_dir := new_dir.get_base_dir().path_join(OLD_NAME)
	if old_dir == new_dir or not DirAccess.dir_exists_absolute(old_dir):
		return
	for file: String in FILES:
		var from := old_dir.path_join(file)
		var to := new_dir.path_join(file)
		if FileAccess.file_exists(from) and not FileAccess.file_exists(to):
			DirAccess.copy_absolute(from, to)
