class_name PlayerLook
extends RefCounted
## Who you are: the name and look you chose when the game began (the
## character screen, scripts/ui/character_creator.gd). The look is a choice
## for each of PARTS; from it the game paints your walking sheet and your
## portrait the way the cast's were painted (FigurePainter, PortraitPainter,
## then the 32px pass in Palette32), and the climbing screen takes its
## colors. Saved with each game (SaveManager); a game saved before this
## loads as the look everyone had then, which is also where the screen
## starts, and that look uses the shipped pictures as they are.
##
##   PlayerLook.sheet()             # your walking sheet, a Texture2D
##   PlayerLook.face("happy")       # your portrait in a mood
##   PlayerLook.display_name()      # your name, or "You" if you gave none
##   PlayerLook.set_choice("hat", 2)

const DEFAULT_SHEET := "res://assets/sprites/player.png"
const DEFAULT_FACES := "res://assets/sprites/portraits/player.png"
const MAX_NAME := 12
## Names the "Surprise me" row deals out.
const NAMES := ["Alder", "Aspen", "Bay", "Briar", "Cedar", "Dana", "Fern", "Juniper", "Lark", "Linden",
	"Manzanita", "Merced", "Robin", "Rowan", "Sage", "Sierra", "Sorrel", "Tioga", "Willow", "Wren"]

## Each part of the look, in the order the screen lists them: its id, the
## name on the row, and its options as [name, value]. The first option of
## every part is the look the game shipped with. Colors are picked to stay
## apart once they're on the game's palette.
const PARTS := [
	{"id": "skin", "name": "Skin", "options": [
		["Fair", "e0ac7e"], ["Light", "f0c8a0"], ["Tan", "c8905e"], ["Brown", "a8703f"], ["Deep", "7e4c2a"]]},
	{"id": "hair_style", "name": "Hair", "options": [
		["Short", "short"], ["Long", "long"], ["Braid", "braid"], ["Bun", "bun"], ["Wild", "wild"], ["Shaved", "bald"]]},
	{"id": "hair", "name": "Hair color", "options": [
		["Brown", "5a3a22"], ["Black", "1a1410"], ["Dark brown", "3a2a1a"], ["Auburn", "8a4a2a"],
		["Red", "b85a24"], ["Blond", "d8b060"], ["Gray", "93918f"], ["White", "e8e4dc"]]},
	{"id": "beard", "name": "Beard", "options": [
		["None", "none"], ["Mustache", "mustache"], ["Goatee", "goatee"], ["Short", "short"], ["Long", "long"]]},
	{"id": "glasses", "name": "Glasses", "options": [["No", false], ["Yes", true]]},
	{"id": "hat", "name": "Hat", "options": [
		["Wide brim", "wide"], ["Ranger", "campaign"], ["Cap", "cap"], ["Beanie", "beanie"],
		["Fedora", "fedora"], ["Headband", "headband"], ["None", "none"]]},
	{"id": "hat_color", "name": "Hat color", "options": [
		["Brown", "7a5232"], ["Straw", "c8a860"], ["Pine", "2c5c37"], ["River", "235679"],
		["Poppy", "b3362b"], ["Granite", "6a6a70"], ["Charcoal", "2b2a30"]]},
	{"id": "top_style", "name": "Shirt", "options": [
		["Work shirt", "shirt"], ["Plaid", "plaid"], ["Stripes", "stripes"], ["Sweater", "sweater"],
		["Vest", "vest"], ["Jacket", "jacket"], ["Suspenders", "suspenders"]]},
	{"id": "top", "name": "Shirt color", "options": [
		["Sage", "6b7d4a"], ["Meadow", "84b04a"], ["River", "3a86a8"], ["Deep blue", "235679"],
		["Poppy", "b3362b"], ["Amber", "d9772a"], ["Gold", "d8a63b"], ["Lupine", "6f5aa6"],
		["Rose", "d47a9b"], ["Cream", "e4ddcc"], ["Granite", "6a6a70"]]},
	{"id": "bottom_style", "name": "Legs", "options": [
		["Trousers", "pants"], ["Knickers", "knickers"], ["Skirt", "skirt"]]},
	{"id": "bottom", "name": "Legs color", "options": [
		["Navy", "3b4660"], ["Bark", "5e4a38"], ["Khaki", "b0925f"], ["Charcoal", "47464d"],
		["Pine", "1d3f2b"], ["Canvas", "bdb8ae"]]},
	{"id": "pack_color", "name": "Pack", "options": [
		["Leather", "8a5a30"], ["Pine", "2c5c37"], ["River", "235679"], ["Poppy", "b3362b"], ["Granite", "6a6a70"]]},
]

## Part id -> the option chosen (an index into that part's options).
static var choice: Dictionary = {}
## The name you gave, or "" for none.
static var player_name := ""
## Counts every change, so whoever shows the look knows to fetch it again.
static var version := 0

static var _painted_for := -1
static var _sheet: Texture2D
static var _faces: Texture2D
static var _face_cache: Dictionary = {}


## The part with [param id], or {}.
static func part(id: String) -> Dictionary:
	for p: Dictionary in PARTS:
		if p.id == id:
			return p
	return {}


## The option chosen for [param id] (0, the shipped look, if never set).
static func chosen(id: String) -> int:
	var p := part(id)
	if p.is_empty():
		return 0
	return clampi(int(choice.get(id, 0)), 0, p.options.size() - 1)


## The chosen option's name, for the screen's row.
static func chosen_name(id: String) -> String:
	var p := part(id)
	return "" if p.is_empty() else str(p.options[chosen(id)][0])


static func chosen_value(id: String) -> Variant:
	var p := part(id)
	return null if p.is_empty() else p.options[chosen(id)][1]


## Chooses option [param index] of part [param id] (wrapping round).
static func set_choice(id: String, index: int) -> void:
	var p := part(id)
	if p.is_empty():
		return
	index = wrapi(index, 0, p.options.size())
	if index == chosen(id) and choice.has(id):
		return
	choice[id] = index
	version += 1


## Sets your name: trimmed, without line breaks, at most MAX_NAME letters.
static func set_player_name(text: String) -> void:
	var clean := text.replace("\n", " ").replace("\t", " ").replace("[", "").replace("]", "").strip_edges().left(MAX_NAME).strip_edges()
	if clean != player_name:
		player_name = clean
		version += 1


## Your name where a speaker or a card needs one.
static func display_name() -> String:
	return player_name if player_name != "" else "You"


## Back to the shipped look and no name.
static func reset() -> void:
	choice.clear()
	player_name = ""
	version += 1


## True while every part is the shipped look's, so the shipped pictures do.
static func is_default() -> bool:
	for p: Dictionary in PARTS:
		if chosen(p.id) != 0:
			return false
	return true


## A look and a name out of the hat ("Surprise me"). Beards and glasses turn
## up less often than not, and a hat more often than not.
static func randomize_look(rng: RandomNumberGenerator = null) -> void:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	for p: Dictionary in PARTS:
		var n: int = p.options.size()
		var pick := rng.randi_range(0, n - 1)
		match p.id:
			"beard":
				pick = 0 if rng.randf() < 0.7 else rng.randi_range(1, n - 1)
			"glasses":
				pick = 1 if rng.randf() < 0.2 else 0
			"hat":
				pick = n - 1 if rng.randf() < 0.25 else rng.randi_range(0, n - 2)
		choice[p.id] = pick
	player_name = NAMES[rng.randi_range(0, NAMES.size() - 1)]
	version += 1


## The look as the painters read it (the keys in tools/npcgen/looks.gd).
static func look() -> Dictionary:
	var out := {"shoes": "3a2a20", "pack": "pack"}
	for p: Dictionary in PARTS:
		out[p.id] = chosen_value(p.id)
	if not out.glasses:
		out.erase("glasses")
	var hat_color := Color(str(out.hat_color))
	out["hat_band"] = "3a2a20" if chosen("hat_color") == 0 else hat_color.darkened(0.45).to_html(false)
	if out.hat == "none":
		out.erase("hat")
	# the second color of a patterned shirt: lighter on a dark one, darker
	# on a light one, so the pattern shows whatever the color
	var top := Color(str(out.top))
	if out.top_style != "shirt":
		out["top2"] = (top.lightened(0.45) if top.get_luminance() < 0.3 else top.darkened(0.4)).to_html(false)
	return out


## The climbing screen's colors for you (ClimbSprites.DEFAULT_COLORS's keys),
## each on the game's palette; {} while you wear the shipped look.
static func climb_colors() -> Dictionary:
	if is_default():
		return {}
	var hat := str(chosen_value("hat"))
	var skin := Palette32.nearest(Color(str(chosen_value("skin"))))
	var hair := Palette32.nearest(Color(str(chosen_value("hair"))))
	if str(chosen_value("hair_style")) == "bald":
		hair = skin
	var kind := "none"
	if hat in ["wide", "campaign", "fedora"]:
		kind = "brim"
	elif hat in ["cap", "beanie"]:
		kind = "dome"
	return {
		"skin": skin,
		"skin_shade": Palette32.nearest(Color(str(chosen_value("skin"))).darkened(0.25)),
		"shirt": Palette32.nearest(Color(str(chosen_value("top")))),
		"pants": Palette32.nearest(Color(str(chosen_value("bottom")))),
		"hair": hair,
		"hat": Palette32.nearest(Color(str(chosen_value("hat_color")))),
		"hat_kind": kind,
	}


## Your color for part [param id] ("top", "skin", ...) on the palette, for
## the small figures drawn in code; [param shipped] while that part is the
## shipped look's, so those figures stay as they were drawn.
static func tint(id: String, shipped: String) -> Color:
	if chosen(id) == 0:
		return Color(shipped)
	return Palette32.nearest(Color(str(chosen_value(id))))


## [param base] (a look as ClimbSprites.belayer reads it) in your colors.
static func belayer_look(base: Dictionary) -> Dictionary:
	if is_default():
		return base
	var out := base.duplicate()
	out["id"] = "player%d" % version
	for pair: Array in [["skin", "skin"], ["hair", "hair"], ["top", "top"], ["bottom", "bottom"], ["hat", "hat_color"]]:
		out[pair[0]] = str(chosen_value(pair[1]))
	var hat := str(chosen_value("hat"))
	if hat in ["none", "headband"]:
		out.erase("hat")
		out.erase("hat_kind")
	out["long"] = str(chosen_value("hair_style")) in ["long", "braid"]
	out["bald"] = str(chosen_value("hair_style")) == "bald"
	return out


static func _paint() -> void:
	if _painted_for == version:
		return
	_painted_for = version
	_face_cache.clear()
	if is_default():
		_sheet = load(DEFAULT_SHEET)
		_faces = load(DEFAULT_FACES)
		return
	var mine := look()
	_sheet = ImageTexture.create_from_image(Palette32.character_sheet(FigurePainter.new().draw_sheet(mine)))
	_faces = ImageTexture.create_from_image(Palette32.snap(PortraitPainter.new().strip(mine, "player")))


## Your walking sheet (32x48 frames; see CharacterSheet).
static func sheet() -> Texture2D:
	_paint()
	return _sheet


## Your portrait in [param mood] (one of Portraits.MOODS).
static func face(mood := "neutral") -> Texture2D:
	_paint()
	if not _face_cache.has(mood):
		var side := _faces.get_height()
		var atlas := AtlasTexture.new()
		atlas.atlas = _faces
		atlas.region = Rect2(maxi(0, Portraits.MOODS.find(mood)) * side, 0, side, side)
		_face_cache[mood] = atlas
	return _face_cache[mood]


static func save_data() -> Dictionary:
	var parts := {}
	for p: Dictionary in PARTS:
		# by value, so a save still reads right if options are added or moved
		parts[p.id] = chosen_value(p.id)
	return {"name": player_name, "look": parts}


static func load_data(data: Dictionary) -> void:
	choice.clear()
	player_name = ""
	set_player_name(str(data.get("name", "")))
	var parts: Dictionary = data.get("look", {}) if typeof(data.get("look")) == TYPE_DICTIONARY else {}
	for p: Dictionary in PARTS:
		if not parts.has(p.id):
			continue
		for i in p.options.size():
			if typeof(p.options[i][1]) == typeof(parts[p.id]) and p.options[i][1] == parts[p.id]:
				choice[p.id] = i
				break
	version += 1
