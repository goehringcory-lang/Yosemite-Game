extends Node
## Your field log (autoload "FieldLog"): the birds, butterflies and other
## animals and fish you've seen, heard or caught, as in Alba or Animal Crossing's critterpedia.
## It sits in the Journal beside the friends and the tick list.
##
## You log a bird or a butterfly by walking (not running) up close enough to
## get a good look before it flies off (Critters calls spot()). Some animals
## you only hear: stand still a few seconds outdoors and listen, by day for a
## mountain chickadee or at night for a great horned owl, the same calls the
## ambience plays. A mule deer (Deer) or a black bear (Bears) you log by
## getting a look at one as it wanders by, a bear also by its tracks after a
## night out, and fish by
## catching them on a fly rod (Fishing).

signal changed
## Sent the first time you log [param id].
signal logged(id: String)

## Seconds of standing still outdoors before you hear something.
const LISTEN_SECONDS := 4.0

## Every animal in the log: its name, Latin name, how you come by it ("seen",
## "heard", "tracks" or "caught", on a fly rod: see Fishing), the seasons (GameClock.Season) it's about, where and
## when to look, and a line of natural history. The ids of the seen ones are
## Critters' kinds; the butterflies are "butterfly_<column on the sheet>".
const ANIMALS := [
	{"id": "stellers_jay", "name": "Steller's Jay", "latin": "Cyanocitta stelleri", "how": "seen", "seasons": [0, 1, 2, 3],
		"hint": "Open ground by day, all year.",
		"note": "A loud, crested blue jay of the conifer forest. It can mimic a red-tailed hawk well enough to scatter the other birds from a picnic table."},
	{"id": "junco", "name": "Dark-eyed Junco", "latin": "Junco hyemalis", "how": "seen", "seasons": [0, 2, 3],
		"hint": "Open ground by day, from fall to spring.",
		"note": "Flashes white tail feathers as it flies. The Sierra's are the Oregon form, with a black hood; in summer many move upslope to nest."},
	{"id": "robin", "name": "American Robin", "latin": "Turdus migratorius", "how": "seen", "seasons": [0, 1, 2],
		"hint": "Lawns and meadows by day, from spring to fall.",
		"note": "Runs, stops and cocks its head over the meadow, watching for worms. Robins nest as high as the timberline here."},
	{"id": "quail", "name": "California Quail", "latin": "Callipepla californica", "how": "seen", "seasons": [0, 1, 2, 3],
		"hint": "Little coveys on open ground by day, all year.",
		"note": "California's state bird, with a black topknot that nods as it walks. A covey keeps in touch with soft calls and bursts up together."},
	{"id": "butterfly_0", "name": "Western Tiger Swallowtail", "latin": "Papilio rutulus", "how": "seen", "seasons": [0, 1],
		"hint": "Drifting over on fair spring and summer days.",
		"note": "A big yellow butterfly striped in black. Males gather on damp sand by streams to sip salts."},
	{"id": "butterfly_1", "name": "California Sister", "latin": "Adelpha californica", "how": "seen", "seasons": [0, 1],
		"hint": "Drifting over on fair spring and summer days.",
		"note": "Black wings with an orange patch at each tip, said to look like a nun's habit. Its caterpillars feed on oaks."},
	{"id": "butterfly_2", "name": "Lorquin's Admiral", "latin": "Limenitis lorquini", "how": "seen", "seasons": [0, 1],
		"hint": "Drifting over on fair spring and summer days.",
		"note": "Like the California Sister but with a white band. It guards a perch and chases off birds much bigger than itself. Its caterpillars eat willow."},
	{"id": "butterfly_3", "name": "Cabbage White", "latin": "Pieris rapae", "how": "seen", "seasons": [0, 1],
		"hint": "Drifting over on fair spring and summer days.",
		"note": "Not from here at all: it came from Europe in the 1860s and spread across the continent on garden cabbages."},
	{"id": "mountain_chickadee", "name": "Mountain Chickadee", "latin": "Poecile gambeli", "how": "heard", "seasons": [0, 1, 2, 3],
		"hint": "Stand still outdoors by day and listen.",
		"note": "Sings a clear \"fee-bee-bee\" from the pines. A white eyebrow sets it apart from the chickadees of the lowlands."},
	{"id": "great_horned_owl", "name": "Great Horned Owl", "latin": "Bubo virginianus", "how": "heard", "seasons": [0, 1, 2],
		"hint": "Stand still outdoors after dark and listen.",
		"note": "Its deep \"hoo, hoo-hoo, hoo, hoo\" carries across the meadows at night. It hunts anything from beetles to skunks."},
	{"id": "rainbow_trout", "name": "Rainbow Trout", "latin": "Oncorhynchus mykiss", "how": "caught", "seasons": [0, 1, 2, 3],
		"hint": "Fish the Merced in the Valley, El Portal or Wawona. They hold in fast water, so try the rapids.",
		"note": "The Merced's own trout, with a rosy stripe down each side. In the Valley it's catch and release, so it goes back in the river."},
	{"id": "brown_trout", "name": "Brown Trout", "latin": "Salmo trutta", "how": "caught", "seasons": [0, 1, 2, 3],
		"hint": "Fish the Merced in the Valley, El Portal or Wawona. The big ones lie deep in the holes.",
		"note": "Brought from Europe and stocked in California rivers from the 1890s. It's wary, and fights hard; you may keep it."},
	{"id": "sacramento_sucker", "name": "Sacramento Sucker", "latin": "Catostomus occidentalis", "how": "caught", "seasons": [0, 1, 2],
		"hint": "Fish the deep, slow holes of the Merced or the South Fork, spring to fall.",
		"note": "A native fish that vacuums algae and insects off the river stones with its soft, downturned lips."},
	{"id": "brook_trout", "name": "Brook Trout", "latin": "Salvelinus fontinalis", "how": "caught", "seasons": [0, 1, 2],
		"hint": "Fish the Tuolumne and the high-country creeks, spring to fall.",
		"note": "Not a trout at all but a char from the eastern states. Most high Sierra waters had no fish until people packed these up in cans."},
	{"id": "mule_deer", "name": "Mule Deer", "latin": "Odocoileus hemionus", "how": "seen", "seasons": [0, 1, 2, 3],
		"hint": "Grazing their way across the meadows and woods, most often at dawn and dusk. Fawns in summer, bucks in antlers in fall.",
		"note": "Named for its big, mule-like ears. Startled, it bounds off on all four feet at once. Deer here seem tame, but they kick and gore: rangers say they hurt more visitors than bears do."},
	{"id": "black_bear", "name": "American Black Bear", "latin": "Ursus americanus", "how": "seen", "seasons": [0, 1, 2, 3],
		"hint": "One may wander by anywhere outdoors, most often at dawn and dusk, and in fall. Or stay out too late and look for tracks the next morning.",
		"note": "Most of Yosemite's bears are brown or cinnamon, not black. There are no grizzlies left: the last one in Yosemite was killed in 1895."},
]

## Animal id -> {"day": Friendship.today(), "where": place name} when you
## first logged it.
var seen: Dictionary = {}

var _still := 0.0


func _ready() -> void:
	add_to_group("persist")


func start_new_game() -> void:
	seen = {}
	_still = 0.0
	changed.emit()


func get_animal(id: String) -> Dictionary:
	for animal: Dictionary in ANIMALS:
		if animal.id == id:
			return animal
	return {}


func has(id: String) -> bool:
	return seen.has(id)


func count() -> int:
	return seen.size()


func total() -> int:
	return ANIMALS.size()


## Logs [param id] if it's new, with a note at the bottom of the screen
## (unless [param quiet], when the caller says so itself). [param how]
## overrides the animal's own "how" for the note (a bear's "tracks").
## Returns true if it was new.
func spot(id: String, quiet := false, how := "") -> bool:
	var animal := get_animal(id)
	if animal.is_empty() or seen.has(id):
		return false
	seen[id] = {"day": Friendship.today(), "where": _place()}
	if not quiet:
		var verb: String = {"seen": "Spotted", "heard": "Heard", "tracks": "Found tracks of"}.get(how if how != "" else animal.how, "Logged")
		get_tree().call_group("hud", "show_message", "%s: %s. It's in your field log (J)." % [verb, animal.name])
		Sound.play("item_get", -6.0, 0.0)
	logged.emit(id)
	changed.emit()
	return true


## The animals you can hear right now outdoors, out of the heavy rain: the
## chickadee by day, and the owl at night in the seasons the ambience has it.
func audible() -> PackedStringArray:
	var out := PackedStringArray()
	var world := get_tree().get_first_node_in_group("world")
	var region: Region = world.region if world and "region" in world else null
	if region == null or region.indoors or Weather.today().rain > 0.5:
		return out
	var hour := GameClock.hour
	var night := hour >= 21 or hour < 5
	for animal: Dictionary in ANIMALS:
		if animal.how != "heard" or not GameClock.season in animal.seasons:
			continue
		var by_night: bool = animal.id == "great_horned_owl"
		if by_night == night and (night or (hour >= 7 and hour < 19)):
			out.append(animal.id)
	return out


func _process(delta: float) -> void:
	var world := get_tree().get_first_node_in_group("world")
	var player: Player = world.player if world and "player" in world else null
	if player == null or not player.can_act or player.velocity != Vector2.ZERO:
		_still = 0.0
		return
	_still += delta
	if _still < LISTEN_SECONDS:
		return
	_still = 0.0
	listen()


## Standing still and listening: logs the first new animal you can hear.
## Returns its id, or "".
func listen() -> String:
	for id in audible():
		if not seen.has(id):
			spot(id)
			return id
	return ""


func _place() -> String:
	var world := get_tree().get_first_node_in_group("world")
	var region: Region = world.region if world and "region" in world else null
	if region == null:
		return ""
	return region.display_name if region.display_name != "" else region.region_id.capitalize()


## "Spring, Summer" for the Journal.
static func seasons_text(seasons: Array) -> String:
	if seasons.size() == 4:
		return "All year"
	var names := PackedStringArray()
	for season: int in seasons:
		names.append(GameClock.SEASON_NAMES[season])
	return ", ".join(names)


func save_data() -> Dictionary:
	return {"seen": seen}


func load_data(data: Dictionary) -> void:
	seen = {}
	var saved: Dictionary = data.get("seen", {})
	for key in saved:
		var entry = saved[key]
		seen[str(key)] = {"day": int(entry.get("day", 0)), "where": str(entry.get("where", ""))} if entry is Dictionary else {"day": 0, "where": ""}
	changed.emit()
