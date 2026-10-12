class_name Portraits
extends RefCounted
## The face shown beside what someone says. Portraits are painted by
## tools/npcgen/portraits.gd and named after the person's walking sheet, so
## the speaker's display name is looked up among the characters in
## data/characters/ (staff and visitors too).
##
##   Portraits.for_speaker("Wren Alvarez")   # a Texture2D, or null

const CHARACTER_DIR := "res://data/characters/"
const PORTRAIT_DIR := "res://assets/sprites/portraits/"
## Speakers who aren't characters (shopkeepers named in data/shops/), by the
## portrait they use.
const EXTRA := {
	"Camp Curry Store clerk": "curry_store_clerk",
}

## Display name -> portrait name, built on first use.
static var _names: Dictionary = {}
static var _cache: Dictionary = {}


static func for_speaker(speaker: String) -> Texture2D:
	if speaker == "":
		return null
	if _names.is_empty():
		_index(CHARACTER_DIR)
		for extra: String in EXTRA:
			_names[extra] = EXTRA[extra]
	var portrait: String = _names.get(speaker, "")
	if portrait == "":
		return null
	if not _cache.has(portrait):
		var path := PORTRAIT_DIR + portrait + ".png"
		_cache[portrait] = load(path) if ResourceLoader.exists(path) else null
	return _cache[portrait]


## A speaking voice for [param speaker]: a pitch for the talking blip that is
## the same every time for the same person.
static func voice_pitch(speaker: String) -> float:
	var h := hash(speaker)
	return 0.78 + float(absi(h) % 1000) / 1000.0 * 0.55


static func _index(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_index(dir_path + sub + "/")
	for file in dir.get_files():
		# Exported games list text resources as name.tres.remap.
		file = file.trim_suffix(".remap")
		if not file.ends_with(".tres"):
			continue
		var data := load(dir_path + file) as CharacterData
		if data and data.sprite_sheet and data.display_name != "":
			_names[data.display_name] = data.sprite_sheet.resource_path.get_file().get_basename()
