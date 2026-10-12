class_name Portraits
extends RefCounted
## The face shown beside what someone says. Portraits are painted by
## tools/npcgen/portraits.gd and named after the person's walking sheet, so
## the speaker's display name is looked up among the characters in
## data/characters/ (staff and visitors too).
##
##   Portraits.for_speaker("Wren Alvarez")             # a Texture2D, or null
##   Portraits.for_speaker("Wren Alvarez", "happy")    # one of MOODS
##
## Each portrait file is a strip of four faces, one per mood. A line in a
## conversation can name its mood ({"speaker", "text", "mood"}); otherwise
## mood_for() reads it from the words.

const CHARACTER_DIR := "res://data/characters/"
const MOODS := ["neutral", "happy", "sad", "surprised"]
## Faces are square, as tall as their strip (see for_speaker).
## Words that make a line sad or glad (whole words, any case).
const SAD_WORDS := ["sorry", "lost", "died", "dead", "miss", "missed", "afraid", "worried", "worry",
	"sad", "tired", "grief", "burned", "hurt", "fear", "lonely", "ruined", "broken", "gone forever"]
const GLAD_WORDS := ["thank", "thanks", "wonderful", "glad", "great", "love", "beautiful", "perfect", "good",
	"fine", "ha", "haha", "welcome", "congratulations", "proud", "happy", "best", "well done"]
const SURPRISE_STARTS := ["oh!", "oh,", "what?", "wow", "really?", "goodness", "well!", "my!", "look!", "whoa"]
const PORTRAIT_DIR := "res://assets/sprites/portraits/"
## Speakers who aren't characters (shopkeepers named in data/shops/), by the
## portrait they use.
const EXTRA := {
	"Camp Curry Store clerk": "curry_store_clerk",
	"Village Store clerk": "village_store_clerk",
	"Camp 4 climber": "camp4_rack_trader",
	"Big-wall climber": "camp4_bigwall_trader",
	# the player, on the pause menu's card
	"You": "player",
}

## Display name -> portrait name, built on first use.
static var _names: Dictionary = {}
static var _cache: Dictionary = {}
static var _sheets: Dictionary = {}


## The speaker's face in [param mood] (one of MOODS), or null.
static func for_speaker(speaker: String, mood := "neutral") -> Texture2D:
	if speaker == "":
		return null
	if _names.is_empty():
		_index(CHARACTER_DIR)
		for extra: String in EXTRA:
			_names[extra] = EXTRA[extra]
	var portrait: String = _names.get(speaker, "")
	if portrait == "":
		return null
	var key := portrait + ":" + mood
	if not _cache.has(key):
		if not _sheets.has(portrait):
			var path := PORTRAIT_DIR + portrait + ".png"
			_sheets[portrait] = load(path) if ResourceLoader.exists(path) else null
		var sheet: Texture2D = _sheets[portrait]
		if sheet == null:
			_cache[key] = null
		else:
			var face := AtlasTexture.new()
			face.atlas = sheet
			var index := maxi(0, MOODS.find(mood))
			# faces are square, as tall as the strip
			var side := sheet.get_height()
			# an older single-face file has only the neutral face
			if sheet.get_width() < side * MOODS.size():
				index = 0
			face.region = Rect2(index * side, 0, side, side)
			_cache[key] = face
	return _cache[key]


## The mood a line reads as, from its words: surprised if it opens with "Oh!"
## or the like, sad if it has words of loss or worry, happy if it exclaims or
## has words of thanks and gladness, and otherwise neutral.
static func mood_for(text: String) -> String:
	var lower := text.strip_edges().to_lower()
	if lower == "":
		return "neutral"
	for start: String in SURPRISE_STARTS:
		if lower.begins_with(start):
			return "surprised"
	var words := PackedStringArray()
	for word in lower.replace("'", " ").split(" ", false):
		words.append(word.strip_edges().trim_suffix(".").trim_suffix(",").trim_suffix("!").trim_suffix("?").trim_suffix(";").trim_suffix(":"))
	for word: String in SAD_WORDS:
		if word.contains(" ") and lower.contains(word) or word in words:
			return "sad"
	if "!" in lower:
		return "happy"
	for word: String in GLAD_WORDS:
		if word.contains(" ") and lower.contains(word) or word in words:
			return "happy"
	return "neutral"


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
