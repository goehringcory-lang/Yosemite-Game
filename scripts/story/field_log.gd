extends Node
## Your field log (autoload "FieldLog"): the birds, butterflies and other
## animals and fish you've seen, heard or caught, as in Alba or Animal Crossing's critterpedia.
## It sits in the Journal beside the friends and the tick list.
##
## You log a bird, a squirrel or a butterfly by walking (not running) up
## close enough to get a good look before it's off (Critters calls spot()).
## A peregrine falcon (Falcons) you log by watching one over the big walls
## for a moment, or from a climb (ClimbMinigame); a great gray owl (Owls) or
## a bobcat (Bobcats), rare as they are, by getting a look as it passes. Some animals
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

## Every animal in the log: its group ("bird", "mammal", "butterfly" or
## "fish"), its name, Latin name, how you come by it ("seen",
## "heard", "tracks" or "caught", on a fly rod: see Fishing), the seasons (GameClock.Season) it's about, where and
## when to look, and a line of natural history. The ids of the seen ones are
## Critters' kinds; the butterflies are "butterfly_<column on the sheet>".
const ANIMALS := [
	{"id": "stellers_jay", "group": "bird", "name": "Steller's Jay", "latin": "Cyanocitta stelleri", "how": "seen", "seasons": [0, 1, 2, 3],
		"hint": "Open ground by day, all year.",
		"note": "A loud, crested blue jay of the conifer forest. It can mimic a red-tailed hawk well enough to scatter the other birds from a picnic table."},
	{"id": "junco", "group": "bird", "name": "Dark-eyed Junco", "latin": "Junco hyemalis", "how": "seen", "seasons": [0, 2, 3],
		"hint": "Open ground by day, from fall to spring.",
		"note": "Flashes white tail feathers as it flies. The Sierra's are the Oregon form, with a black hood; in summer many move upslope to nest."},
	{"id": "robin", "group": "bird", "name": "American Robin", "latin": "Turdus migratorius", "how": "seen", "seasons": [0, 1, 2],
		"hint": "Lawns and meadows by day, from spring to fall.",
		"note": "Runs, stops and cocks its head over the meadow, watching for worms. Robins nest as high as the timberline here."},
	{"id": "quail", "group": "bird", "name": "California Quail", "latin": "Callipepla californica", "how": "seen", "seasons": [0, 1, 2, 3],
		"hint": "Little coveys on open ground by day, all year.",
		"note": "California's state bird, with a black topknot that nods as it walks. A covey keeps in touch with soft calls and bursts up together."},
	{"id": "butterfly_0", "group": "butterfly", "name": "Western Tiger Swallowtail", "latin": "Papilio rutulus", "how": "seen", "seasons": [0, 1],
		"hint": "Drifting over on fair spring and summer days.",
		"note": "A big yellow butterfly striped in black. Males gather on damp sand by streams to sip salts."},
	{"id": "butterfly_1", "group": "butterfly", "name": "California Sister", "latin": "Adelpha californica", "how": "seen", "seasons": [0, 1],
		"hint": "Drifting over on fair spring and summer days.",
		"note": "Black wings with an orange patch at each tip, said to look like a nun's habit. Its caterpillars feed on oaks."},
	{"id": "butterfly_2", "group": "butterfly", "name": "Lorquin's Admiral", "latin": "Limenitis lorquini", "how": "seen", "seasons": [0, 1],
		"hint": "Drifting over on fair spring and summer days.",
		"note": "Like the California Sister but with a white band. It guards a perch and chases off birds much bigger than itself. Its caterpillars eat willow."},
	{"id": "butterfly_3", "group": "butterfly", "name": "Cabbage White", "latin": "Pieris rapae", "how": "seen", "seasons": [0, 1],
		"hint": "Drifting over on fair spring and summer days.",
		"note": "Not from here at all: it came from Europe in the 1860s and spread across the continent on garden cabbages."},
	{"id": "mountain_chickadee", "group": "bird", "name": "Mountain Chickadee", "latin": "Poecile gambeli", "how": "heard", "seasons": [0, 1, 2, 3],
		"hint": "Stand still outdoors by day and listen.",
		"note": "Sings a clear \"fee-bee-bee\" from the pines. A white eyebrow sets it apart from the chickadees of the lowlands."},
	{"id": "great_horned_owl", "group": "bird", "name": "Great Horned Owl", "latin": "Bubo virginianus", "how": "heard", "seasons": [0, 1, 2],
		"hint": "Stand still outdoors after dark and listen.",
		"note": "Its deep \"hoo, hoo-hoo, hoo, hoo\" carries across the meadows at night. It hunts anything from beetles to skunks."},
	{"id": "rainbow_trout", "group": "fish", "name": "Rainbow Trout", "latin": "Oncorhynchus mykiss", "how": "caught", "seasons": [0, 1, 2, 3],
		"hint": "Fish the Merced in the Valley, El Portal or Wawona. They hold in fast water, so try the rapids.",
		"note": "The Merced's own trout, with a rosy stripe down each side. In the Valley it's catch and release, so it goes back in the river."},
	{"id": "brown_trout", "group": "fish", "name": "Brown Trout", "latin": "Salmo trutta", "how": "caught", "seasons": [0, 1, 2, 3],
		"hint": "Fish the Merced in the Valley, El Portal or Wawona. The big ones lie deep in the holes.",
		"note": "Brought from Europe and stocked in California rivers from the 1890s. It's wary, and fights hard; you may keep it."},
	{"id": "sacramento_sucker", "group": "fish", "name": "Sacramento Sucker", "latin": "Catostomus occidentalis", "how": "caught", "seasons": [0, 1, 2],
		"hint": "Fish the deep, slow holes of the Merced or the South Fork, spring to fall.",
		"note": "A native fish that vacuums algae and insects off the river stones with its soft, downturned lips."},
	{"id": "brook_trout", "group": "fish", "name": "Brook Trout", "latin": "Salvelinus fontinalis", "how": "caught", "seasons": [0, 1, 2],
		"hint": "Fish the Tuolumne and the high-country creeks, spring to fall.",
		"note": "Not a trout at all but a char from the eastern states. Most high Sierra waters had no fish until people packed these up in cans."},
	{"id": "acorn_woodpecker", "group": "bird", "name": "Acorn Woodpecker", "latin": "Melanerpes formicivorus", "how": "seen", "seasons": [0, 1, 2, 3],
		"hint": "Under the Valley's oaks by day, all year.",
		"note": "A clown-faced woodpecker that lives in family groups. They drill a tree full of holes and wedge an acorn in each, a granary that can hold thousands."},
	{"id": "clarks_nutcracker", "group": "bird", "name": "Clark's Nutcracker", "latin": "Nucifraga columbiana", "how": "seen", "seasons": [0, 1, 2, 3],
		"hint": "Open ground in the high country by day: Tuolumne, Glacier Point, Half Dome, Crane Flat.",
		"note": "A gray jay of the high pines with black and white wings. It buries tens of thousands of whitebark pine seeds each fall and finds most of them again under the snow."},
	{"id": "peregrine_falcon", "group": "bird", "name": "Peregrine Falcon", "latin": "Falco peregrinus", "how": "seen", "seasons": [0, 1, 2, 3],
		"hint": "Look up under the big walls by day: El Capitan, the Cathedral Rocks, Glacier Point, Half Dome. Or watch for one from a long climb.",
		"note": "The fastest animal alive: it folds its wings and stoops on other birds at over 200 miles an hour. DDT all but wiped peregrines out of California by the 1970s; now pairs nest on the Valley's walls again, and climbers keep off routes near their nests in spring."},
	{"id": "great_gray_owl", "group": "bird", "name": "Great Gray Owl", "latin": "Strix nebulosa yosemitensis", "how": "seen", "seasons": [0, 1, 2, 3],
		"hint": "Hunting the meadows at Crane Flat, Wawona and along the Big Oak Flat Road, most at dawn and dusk.",
		"note": "The biggest owl in North America by length, with a face like a satellite dish. Only a couple of hundred live in California, nearly all in and around Yosemite. It hunts voles by ear, even under a foot of snow."},
	{"id": "western_gray_squirrel", "group": "mammal", "name": "Western Gray Squirrel", "latin": "Sciurus griseus", "how": "seen", "seasons": [0, 1, 2, 3],
		"hint": "Among the Valley's oaks and pines by day, all year.",
		"note": "A big silver-gray tree squirrel with a white belly and a plume of a tail. It buries acorns one at a time all fall, and the ones it forgets grow into oaks."},
	{"id": "california_ground_squirrel", "group": "mammal", "name": "California Ground Squirrel", "latin": "Otospermophilus beecheyi", "how": "seen", "seasons": [0, 1, 2],
		"hint": "Open ground in the Valley, at Glacier Point and Wawona, from spring to fall. They sleep through the winter.",
		"note": "Speckled brown with a silvery cape. Please don't feed them: they bite more visitors than any other animal in the park, and a squirrel fed by people gets sick on it."},
	{"id": "douglas_squirrel", "group": "mammal", "name": "Douglas Squirrel", "latin": "Tamiasciurus douglasii", "how": "seen", "seasons": [0, 1, 2, 3],
		"hint": "In the conifer forests up high and at Wawona, all year.",
		"note": "The chickaree: a small squirrel with an orange belly and a scolding chatter. It cuts green cones and stores them in damp heaps, and John Muir called it the \"master forester\" for the trees that grow from them."},
	{"id": "golden_mantled_ground_squirrel", "group": "mammal", "name": "Golden-mantled Ground Squirrel", "latin": "Callospermophilus lateralis", "how": "seen", "seasons": [0, 1, 2],
		"hint": "Among the high country's granite, from spring to fall: Tuolumne, Glacier Point, Half Dome.",
		"note": "Often taken for a chipmunk, but it has no stripes on its face, only its coppery head and a white stripe down each side. It fattens all summer and sleeps under the snow all winter."},
	{"id": "bobcat", "group": "mammal", "name": "Bobcat", "latin": "Lynx rufus", "how": "seen", "seasons": [0, 1, 2, 3],
		"hint": "Rare and shy. Walk the meadows at dawn and dusk, and in winter, when they hunt voles under the snow.",
		"note": "Twice the size of a house cat, with a short bobbed tail and tufted ears. It hunts by stealth, frozen still for minutes before it pounces. Bobcats live all over the park; seeing one is luck."},
	{"id": "mule_deer", "group": "mammal", "name": "Mule Deer", "latin": "Odocoileus hemionus", "how": "seen", "seasons": [0, 1, 2, 3],
		"hint": "Grazing their way across the meadows and woods, most often at dawn and dusk. Fawns in summer, bucks in antlers in fall.",
		"note": "Named for its big, mule-like ears. Startled, it bounds off on all four feet at once. Deer here seem tame, but they kick and gore: rangers say they hurt more visitors than bears do."},
	{"id": "black_bear", "group": "mammal", "name": "American Black Bear", "latin": "Ursus americanus", "how": "seen", "seasons": [0, 1, 2, 3],
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


## The groups in the order the Wildlife journal shows them.
const GROUPS := ["bird", "mammal", "butterfly", "fish"]
const GROUP_NAMES := {"bird": "Birds", "mammal": "Mammals", "butterfly": "Butterflies", "fish": "Fish"}


## How many of [param group] you've logged.
func count_in(group: String) -> int:
	var n := 0
	for animal: Dictionary in ANIMALS:
		if animal.group == group and seen.has(animal.id):
			n += 1
	return n


## How many animals [param group] has in all.
func total_in(group: String) -> int:
	return ANIMALS.filter(func(a: Dictionary) -> bool: return a.group == group).size()


## The animals of [param group], in log order.
func in_group(group: String) -> Array:
	return ANIMALS.filter(func(a: Dictionary) -> bool: return a.group == group)


## A picture of animal [param id] for the Wildlife journal: its sprite
## from the critters, the big animals or WildlifeSheet, or a fish's icon.
func icon(id: String) -> Texture2D:
	if WildlifeSheet.has(id):
		return WildlifeSheet.icon(id)
	var atlas := AtlasTexture.new()
	if Critters.BIRDS.has(id):
		atlas.atlas = Critters.SHEET
		atlas.region = Rect2(0, int(Critters.BIRDS[id].row) * Critters.FRAME.y, Critters.FRAME.x, Critters.FRAME.y)
	elif id.begins_with("butterfly_"):
		atlas.atlas = Critters.SHEET
		atlas.region = Rect2(int(id.trim_prefix("butterfly_")) * 32, Critters.SHEET_BIRD_ROWS * Critters.FRAME.y + 2, 16, 16)
	elif id == "black_bear":
		atlas.atlas = Bear.SHEET
		atlas.region = Rect2(0, 0, Bear.FRAME.x, Bear.FRAME.y)
	elif id == "mule_deer":
		atlas.atlas = MuleDeer.SHEET
		atlas.region = Rect2(MuleDeer.FRAME.x * 3, MuleDeer.FRAME.y * 2, MuleDeer.FRAME.x, MuleDeer.FRAME.y)
	else:
		var item := ItemDB.get_item(id)
		return item.icon if item else null
	return atlas


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
		get_tree().call_group("hud", "show_message", "%s: %s. It's in your Wildlife journal (N)." % [verb, animal.name])
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
