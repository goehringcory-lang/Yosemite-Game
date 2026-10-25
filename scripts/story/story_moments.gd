class_name StoryMoments
extends Node
## The story's big moments, shown rather than told. Each time one of the
## Guardian sightings comes true (GuardianSearch.SIGHTINGS: the main-line
## quest it follows is done), the next time you're free (not in a
## conversation, a menu, a climb or a trip) the screen letterboxes and shows
## the moment as its witness saw it (StoryVista): Lamon looking up from his
## orchard at a speck on the Apron at sunrise, a headlamp on the Nose at
## night, the figure in Ansel Adams's print. Each plays once; the Journal
## keeps the words, as before.
##
## The words are the sighting's own (GuardianSearch.SIGHTINGS), so nothing
## new is put in anyone's mouth, and like the sightings these never come from
## Native characters. World adds one; it saves which moments were seen.

## Seconds the player has to be free before a moment starts, so it doesn't
## cut in on the end of a conversation or the arrival at a new place.
const SETTLE := 1.2

## Quest id -> the scene: title (on the top band), from (where the witness
## was), hour (the light), view (skyline landmarks, as in ClimbProfiles),
## ground (the valley floor's look), figure ({"x", "down", "l"}: where you
## are on a landmark), figure_kind (climber, headlamp, stakes, or wreck: the
## car lying in the near grass at wreck_x),
## foreground, photograph, rise_from / rise_to (how far the view rises).
const MOMENTS := {
	"partner_apron": {
		"title": "Sunrise on the Glacier Point Apron", "from": "from his orchard", "hour": 6.3,
		"view": [{"k": "glacier_point", "x": 250, "s": 1.5, "l": 1}, {"k": "half_dome", "x": 430, "s": 0.9, "l": 0},
			{"k": "sierra_crest", "x": 240, "s": 1.0, "l": 2}],
		"ground": "valley_forest", "figure": {"x": 292, "down": 0.5, "l": 1}, "foreground": "orchard",
	},
	"eichorn_apron": {
		"title": "Up the Apron to the rim", "from": "at Camp Curry", "hour": 10.5,
		"view": [{"k": "glacier_point", "x": 240, "s": 1.7, "l": 1}, {"k": "half_dome", "x": 440, "s": 0.8, "l": 0}],
		"ground": "curry", "figure": {"x": 250, "down": 0.08, "l": 1}, "foreground": "tents",
	},
	"robbins_clean": {
		"title": "Nutcracker, without a scratch", "from": "at the bakery", "hour": 15.5,
		"view": [{"k": "three_brothers", "x": 250, "s": 1.4, "l": 1}, {"k": "el_capitan", "x": 70, "s": 0.8, "l": 0},
			{"k": "yosemite_falls", "x": 430, "s": 0.8, "l": 0}],
		"ground": "valley_forest", "figure": {"x": 272, "down": 0.45, "l": 1}, "foreground": "pines",
	},
	"salathe_steel": {
		"title": "The wreck at El Portal", "from": "on her rounds", "hour": 17.0, "mood": "neutral",
		"view": [{"k": "cathedral_rocks", "x": 120, "s": 0.8, "l": 0}, {"k": "mt_broderick", "x": 380, "s": 1.2, "l": 1}],
		"ground": "valley_forest", "figure_kind": "wreck", "wreck_x": 300.0,
		"rise_from": 0.2, "rise_to": 0.35,
	},
	"johnson_astroman": {
		"title": "A figure on Washington Column", "from": "in his darkroom", "hour": 18.7, "photograph": true,
		"view": [{"k": "washington_column", "x": 240, "s": 1.9, "l": 1}, {"k": "half_dome", "x": 420, "s": 1.1, "l": 0},
			{"k": "north_dome", "x": 90, "s": 1.0, "l": 0}],
		"ground": "valley_forest", "figure": {"x": 232, "down": 0.3, "l": 1},
	},
	"harding_summit": {
		"title": "A headlamp on the Nose", "from": "at the Mountain Shop", "hour": 22.5,
		"view": [{"k": "el_capitan", "x": 240, "s": 1.7, "l": 1}, {"k": "cathedral_rocks", "x": 440, "s": 0.8, "l": 0}],
		"ground": "el_cap_meadow", "figure": {"x": 240, "down": 0.35, "l": 1}, "figure_kind": "headlamp", "foreground": "pines",
	},
	"muir_glacier": {
		"title": "A climber on the Lyell ice", "from": "with the sheepherders", "hour": 9.0, "alpine": true,
		"view": [{"k": "mt_lyell", "x": 250, "s": 1.9, "l": 1}, {"k": "mt_maclure", "x": 420, "s": 1.0, "l": 0},
			{"k": "sierra_crest", "x": 240, "s": 1.0, "l": 2}],
		"ground": "moraine", "figure": {"x": 262, "down": 0.55, "l": 1}, "figure_kind": "stakes",
	},
}

## Moments seen (quest ids), and those waiting their turn.
var seen: PackedStringArray = []
var waiting: PackedStringArray = []
var _free_for := 0.0
var _playing: StoryVista


func _ready() -> void:
	name = "StoryMoments"
	add_to_group("persist")
	QuestLog.quest_completed.connect(_on_quest_completed)


func _on_quest_completed(quest: QuestData) -> void:
	if MOMENTS.has(quest.id) and quest.id not in seen and quest.id not in waiting:
		waiting.append(quest.id)


## The sighting's words for [param quest_id]: {"who", "text"}, or {}.
static func words_for(quest_id: String) -> Dictionary:
	for sighting: Dictionary in GuardianSearch.SIGHTINGS:
		if sighting.quest == quest_id:
			var who := QuestLog.get_character(sighting.who)
			return {"who": who.display_name if who else String(sighting.who), "text": sighting.text}
	return {}


func _process(delta: float) -> void:
	if waiting.is_empty() or _playing != null:
		return
	if not _player_is_free():
		_free_for = 0.0
		return
	_free_for += delta
	if _free_for >= SETTLE:
		_free_for = 0.0
		play(waiting[0])


## True when nothing else has the player: they can move, no conversation or
## menu is open, the game isn't paused, and World isn't mid-trip.
func _player_is_free() -> bool:
	var world := get_parent()
	if world == null or not "player" in world or world.player == null or not world.player.can_act:
		return false
	if get_tree().paused or world.get("_busy"):
		return false
	for box in get_tree().get_nodes_in_group("dialogue_box"):
		if not box.is_queued_for_deletion():
			return false
	return true


## Plays the moment for [param quest_id] now, and marks it seen.
func play(quest_id: String) -> void:
	if quest_id in waiting:
		waiting.remove_at(waiting.find(quest_id))
	if quest_id not in seen:
		seen.append(quest_id)
	var words := words_for(quest_id)
	if words.is_empty() or not MOMENTS.has(quest_id):
		return
	var world := get_parent()
	var player: Player = world.player if world and "player" in world else null
	if player:
		player.can_act = false
	var was_paused := GameClock.paused
	GameClock.paused = true
	_playing = StoryVista.new()
	_playing.setup(MOMENTS[quest_id], words)
	add_child(_playing)
	await _playing.finished
	_playing = null
	GameClock.paused = was_paused
	if player and is_instance_valid(player):
		player.can_act = true


func save_data() -> Dictionary:
	return {"seen": Array(seen), "waiting": Array(waiting)}


func load_data(data: Dictionary) -> void:
	seen = PackedStringArray(data.get("seen", []))
	waiting = PackedStringArray(data.get("waiting", []))
