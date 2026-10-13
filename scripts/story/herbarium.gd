extends Node
## The press book: the plants the player has pressed (or, for the ones that
## mustn't be picked, sketched), and the clues it gathers about the lost
## Guardian. Enid Michael hands over the plant press in The Plant Press (the
## "plant_press" unlock); the press book's quests (QuestData.press_line) run
## beside the climbing tick list, and the finale needs both.
##
## To add a plant: add it to PLANTS, give it the next free frame in
## tools/plants/plant_art.gd, and rebuild the sheet:
##   godot --headless --path . -s res://tools/plants/plant_art.gd
## PlantSpawner puts a few of each where it grows (see "grows").

signal changed
## Sent when a plant goes into the book for the first time.
signal pressed_plant(id: String)

const ABILITY := "plant_press"
const SHEET := "res://assets/sprites/plants.png"
const SHEET_COLUMNS := 8
const FRAME := 16
const SPRING := 1
const SUMMER := 2
const FALL := 4
const WINTER := 8
const GROWING := SPRING | SUMMER | FALL
const ALL_YEAR := SPRING | SUMMER | FALL | WINTER
## The hand-made areas on the Valley floor all count as Yosemite Valley.
const VALLEY := "yosemite_valley"
const VALLEY_AREAS := ["yosemite_valley", "yosemite_village", "curry_village", "the_ahwahnee", "ahwahnee_trail", "lamon_homestead"]
const HUB_NAMES := {"yosemite_valley": "the Valley floor", "el_portal": "El Portal", "wawona": "Wawona",
	"glacier_point": "Glacier Point", "tuolumne_meadows": "Tuolumne Meadows"}
const HABITAT_NAMES := {ItemData.Habitat.MEADOW: "open meadow", ItemData.Habitat.OAK_WOODLAND: "under the black oaks",
	ItemData.Habitat.CHAPARRAL: "dry brush", ItemData.Habitat.RIVERSIDE: "the water's edge",
	ItemData.Habitat.FOREST: "conifer shade", ItemData.Habitat.HIGH_COUNTRY: "high granite sand"}

## Every plant in the press book, in book order (the Valley floor, then down
## the canyon, the big trees, the rim, and the high country).
##   "note":      one or two lines of natural history, shown when it's found
##   "seasons":   when a specimen can be found (a mask of SPRING..WINTER)
##   "habitat":   an ItemData.Habitat
##   "grows":     region id -> a named spot it grows near ("" = anywhere there)
##   "protected": too rare to pick. The player sketches it instead.
## The frame in plants.png is the plant's place in this list.
const PLANTS: Array[Dictionary] = [
	{"id": "black_oak", "name": "California Black Oak", "latin": "Quercus kelloggii",
		"note": "Deep-lobed leaves with a bristle at each tip. Pink in spring, gold in fall.",
		"seasons": GROWING, "habitat": ItemData.Habitat.OAK_WOODLAND,
		"grows": {"lamon_homestead": "", "yosemite_valley": ""}},
	{"id": "incense_cedar", "name": "Incense-cedar", "latin": "Calocedrus decurrens",
		"note": "Flat sprays of scale leaves, and red bark in long strips. Smells like a pencil.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.FOREST,
		"grows": {"curry_village": "campsite_center", "yosemite_village": "yosemite_museum", "yosemite_valley": ""}},
	{"id": "ponderosa_pine", "name": "Ponderosa Pine", "latin": "Pinus ponderosa",
		"note": "Needles in threes, as long as your hand. Old bark breaks into yellow plates.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.FOREST,
		"grows": {"yosemite_valley": "", "yosemite_village": "camp_4", "ahwahnee_trail": "north_entry"}},
	{"id": "canyon_live_oak", "name": "Canyon Live Oak", "latin": "Quercus chrysolepis",
		"note": "Evergreen. Holly-edged leaves and smooth ones on the same twig, gold dust underneath.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.FOREST,
		"grows": {"the_ahwahnee": "cascade", "yosemite_valley": ""}},
	{"id": "greenleaf_manzanita", "name": "Greenleaf Manzanita", "latin": "Arctostaphylos patula",
		"note": "Smooth red bark, cool to the touch, and stiff round leaves held edge-on to the sun.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.CHAPARRAL,
		"grows": {"yosemite_valley": "", "glacier_point": "washburn_point", "lamon_homestead": ""}},
	{"id": "western_azalea", "name": "Western Azalea", "latin": "Rhododendron occidentale",
		"note": "White flowers splashed with yellow, sweet as cloves. It blooms along the Merced in June.",
		"seasons": SPRING | SUMMER, "habitat": ItemData.Habitat.RIVERSIDE,
		"grows": {"ahwahnee_trail": "river_bank", "yosemite_village": "", "yosemite_valley": ""}},
	{"id": "showy_milkweed", "name": "Showy Milkweed", "latin": "Asclepias speciosa",
		"note": "Pink starry globes on a felted stalk. Monarch caterpillars eat nothing else.",
		"seasons": GROWING, "habitat": ItemData.Habitat.MEADOW,
		"grows": {"yosemite_village": "cooks_meadow", "the_ahwahnee": "ahwahnee_meadow", "curry_village": ""}},
	{"id": "broadleaf_lupine", "name": "Broadleaf Lupine", "latin": "Lupinus latifolius",
		"note": "Blue-violet spires and leaves like an open hand. A drop of dew sits in each palm.",
		"seasons": SPRING | SUMMER, "habitat": ItemData.Habitat.MEADOW,
		"grows": {"the_ahwahnee": "ahwahnee_meadow", "ahwahnee_trail": "meadow", "yosemite_valley": ""}},
	{"id": "bracken_fern", "name": "Western Bracken Fern", "latin": "Pteridium aquilinum",
		"note": "Fiddleheads in spring, waist-high fronds by summer, rust-brown by October.",
		"seasons": GROWING, "habitat": ItemData.Habitat.MEADOW,
		"grows": {"lamon_homestead": "", "ahwahnee_trail": "meadow", "curry_village": ""}},
	{"id": "pacific_dogwood", "name": "Mountain Dogwood", "latin": "Cornus nuttallii",
		"note": "The white 'petals' are bracts round a button of tiny flowers. The leaves turn rose in fall.",
		"seasons": GROWING, "habitat": ItemData.Habitat.FOREST,
		"grows": {"the_ahwahnee": "cascade", "wawona": "mariposa_grove", "yosemite_valley": ""}},
	# Down the canyon: the foothills at El Portal.
	{"id": "western_redbud", "name": "Western Redbud", "latin": "Cercis occidentalis",
		"note": "Magenta flowers on bare twigs in March, then heart-shaped leaves and pods that hang all winter.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.MEADOW,
		"grows": {"el_portal": "arch_rock"}},
	{"id": "california_poppy", "name": "California Poppy", "latin": "Eschscholzia californica",
		"note": "Four orange petals that fold shut at dusk and on cloudy days.",
		"seasons": SPRING | SUMMER, "habitat": ItemData.Habitat.MEADOW,
		"grows": {"el_portal": "railroad"}},
	{"id": "california_buckeye", "name": "California Buckeye", "latin": "Aesculus californica",
		"note": "First tree to leaf out and first to drop its leaves, by midsummer. The big seeds hang on bare.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.MEADOW,
		"grows": {"el_portal": "arrival"}},
	{"id": "gray_pine", "name": "Gray Pine", "latin": "Pinus sabiniana",
		"note": "Thin gray-green needles you can see the sky through, a forked trunk, and cones the size of your head.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.MEADOW,
		"grows": {"el_portal": "yosemite_view_lodge"}},
	# The big trees: Wawona and the Mariposa Grove.
	{"id": "giant_sequoia", "name": "Giant Sequoia", "latin": "Sequoiadendron giganteum",
		"note": "Awl-shaped scales on rope-like twigs. The largest tree on earth grows from a seed like an oat flake.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.FOREST,
		"grows": {"wawona": "grizzly_giant"}},
	{"id": "sugar_pine", "name": "Sugar Pine", "latin": "Pinus lambertiana",
		"note": "Needles in fives and the longest cones of any pine, hung from the tips of level branches.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.FOREST,
		"grows": {"wawona": "mariposa_grove", "glacier_point": "arrival"}},
	{"id": "mountain_misery", "name": "Mountain Misery", "latin": "Chamaebatia foliolosa",
		"note": "Ferny, sticky, knee-high and pungent. It carpets the pine woods and tars your trousers.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.FOREST,
		"grows": {"wawona": "history_center"}},
	# The rim: Glacier Point and Sentinel Dome.
	{"id": "jeffrey_pine", "name": "Jeffrey Pine", "latin": "Pinus jeffreyi",
		"note": "Like a ponderosa, but put your nose in the bark: vanilla. The cone's prickles turn in.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.FOREST,
		"grows": {"glacier_point": "sentinel_dome"}},
	{"id": "red_fir", "name": "California Red Fir", "latin": "Abies magnifica",
		"note": "Stiff blue-green needles that curve up like a hockey stick, and cones that stand upright.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.FOREST,
		"grows": {"glacier_point": "washburn_point"}},
	{"id": "pinemat_manzanita", "name": "Pinemat Manzanita", "latin": "Arctostaphylos nevadensis",
		"note": "A manzanita that lies down: a green mat over the granite under the firs and pines.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.FOREST,
		"grows": {"glacier_point": "sentinel_dome"}},
	{"id": "snow_plant", "name": "Snow Plant", "latin": "Sarcodes sanguinea", "protected": true,
		"note": "All scarlet, no green. It lives on the fungi at the pines' roots and comes up as the snow goes.",
		"seasons": SPRING | SUMMER, "habitat": ItemData.Habitat.FOREST,
		"grows": {"glacier_point": "arrival"}},
	# The high country: Tuolumne Meadows.
	{"id": "lodgepole_pine", "name": "Lodgepole Pine", "latin": "Pinus contorta",
		"note": "Needles in twos, bark in thin scales like cornflakes. It rings every high meadow.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.HIGH_COUNTRY,
		"grows": {"tuolumne_meadows": "arrival"}},
	{"id": "sierra_juniper", "name": "Sierra Juniper", "latin": "Juniperus grandis",
		"note": "Cinnamon bark and a trunk as thick as it is tall, rooted in a crack in a granite dome.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.HIGH_COUNTRY,
		"grows": {"tuolumne_meadows": "lembert_dome"}},
	{"id": "white_heather", "name": "White Mountain Heather", "latin": "Cassiope mertensiana",
		"note": "Cassiope: tiny white bells on red stalks, over leaves pressed tight as braid. Muir's favorite.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.HIGH_COUNTRY,
		"grows": {"tuolumne_meadows": "cathedral_lakes_trailhead"}},
	{"id": "alpine_shooting_star", "name": "Alpine Shooting Star", "latin": "Primula tetrandra",
		"note": "Magenta petals swept back from a dark point, like something falling. It likes wet feet.",
		"seasons": SUMMER, "habitat": ItemData.Habitat.MEADOW,
		"grows": {"tuolumne_meadows": "soda_springs"}},
	{"id": "lemmons_paintbrush", "name": "Lemmon's Paintbrush", "latin": "Castilleja lemmonii",
		"note": "Purple-pink brushes ankle high in the meadow grass. It taps its neighbors' roots.",
		"seasons": SUMMER | FALL, "habitat": ItemData.Habitat.MEADOW,
		"grows": {"tuolumne_meadows": "tuolumne_lodge"}},
]

## What the press book's quests turn up about the lost Guardian, in order.
## Each is shown in the Journal once its quest is done.
const CLUES: Array[Dictionary] = [
	{"quest": "enid_press", "text": "The press came with a stack of old sheets. Each is labeled \"Collected for the Guardian of Yosemite\" and each is empty: just the faint outline of a plant."},
	{"quest": "hodges_herbarium", "text": "Ranger Hodges has the name of every Guardian the State appointed until 1906. None of them left these sheets."},
	{"quest": "hodges_canyon", "text": "The labels name places from El Portal to the Tuolumne. Whoever the Guardian was meant to walk the whole park."},
	{"quest": "clark_grove_sprigs", "text": "Clark never knew who the labels meant. He remembers a gap in the talus under the Royal Arches, and a tin box he left alone."},
	{"quest": "enid_rim", "text": "Enid laid your Jeffrey pine on an old sheet. It fits its outline needle for needle."},
	{"quest": "muir_cassiope", "text": "Muir: \"A guardian who gathers and never signs. I should like to meet that one.\""},
	{"quest": "enid_full_press", "text": "Every outline is filled, and every one by you. One sheet is left with no outline at all."},
	{"quest": "lost_guardian", "text": "The last sheet holds a mirror. The lost Guardian was you all along."},
]

## Plant id -> {"where": region display name, "date": "Spring 3, Year 1"}.
var pressed: Dictionary = {}

var _by_id: Dictionary = {}
var _icons: Dictionary = {}


func _ready() -> void:
	add_to_group("persist")
	for i in PLANTS.size():
		_by_id[PLANTS[i].id] = i


func start_new_game() -> void:
	pressed = {}
	changed.emit()


## True once Enid Michael has handed over the plant press.
func has_press() -> bool:
	return QuestLog.is_unlocked(ABILITY)


## The plant's entry in PLANTS, or {} if there's no such plant.
func get_plant(id: String) -> Dictionary:
	return PLANTS[_by_id[id]] if _by_id.has(id) else {}


func has(id: String) -> bool:
	return pressed.has(id)


func has_all(ids: Array) -> bool:
	return ids.all(func(id: String) -> bool: return pressed.has(id))


## How many plants are in the book; with [param hub], only those that grow there.
func count(hub := "") -> int:
	if hub == "":
		return pressed.size()
	var n := 0
	for id: String in pressed:
		if hub in hubs_of(get_plant(id)):
			n += 1
	return n


## How many of the book's plants grow in [param hub] at all.
func total(hub := "") -> int:
	if hub == "":
		return PLANTS.size()
	return PLANTS.filter(func(plant: Dictionary) -> bool: return hub in hubs_of(plant)).size()


## The hubs [param plant] grows in (the Valley's smaller areas count as the Valley).
static func hubs_of(plant: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for region_id: String in plant.get("grows", {}):
		var hub: String = VALLEY if region_id in VALLEY_AREAS else region_id
		if not hub in result:
			result.append(hub)
	return result


static func in_season(plant: Dictionary, season: int) -> bool:
	return int(plant.seasons) & (1 << season) != 0


## Puts a plant in the book. Returns true the first time.
func press(id: String, where := "") -> bool:
	if not _by_id.has(id) or pressed.has(id):
		return false
	pressed[id] = {"where": where, "date": GameClock.get_date_string()}
	changed.emit()
	pressed_plant.emit(id)
	return true


## The plant's 16x16 drawing, from the sheet tools/plants/plant_art.gd makes.
func icon(id: String) -> Texture2D:
	if not _by_id.has(id):
		return null
	if not _icons.has(id):
		var index: int = _by_id[id]
		var atlas := AtlasTexture.new()
		atlas.atlas = load(SHEET)
		atlas.region = Rect2(index % SHEET_COLUMNS * FRAME, index / SHEET_COLUMNS * FRAME, FRAME, FRAME)
		_icons[id] = atlas
	return _icons[id]


## Where and when to look for a plant, for a page of the book that's still
## empty: "Conifer shade at Glacier Point. Spring and summer."
func hint(plant: Dictionary) -> String:
	var places := PackedStringArray()
	for hub in hubs_of(plant):
		places.append(HUB_NAMES.get(hub, hub))
	var habitat: String = HABITAT_NAMES.get(plant.habitat, "open ground")
	return "%s, %s. %s." % [habitat[0].to_upper() + habitat.substr(1), " and ".join(places), seasons_text(int(plant.seasons))]


static func seasons_text(mask: int) -> String:
	if mask == ALL_YEAR:
		return "All year"
	var names := PackedStringArray()
	for i in 4:
		if mask & (1 << i) != 0:
			names.append(["Spring", "Summer", "Fall", "Winter"][i])
	if names.size() <= 1:
		return "".join(names) + " only"
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + names[names.size() - 1].to_lower()


## What the press book's quests have turned up about the lost Guardian.
func clues() -> PackedStringArray:
	var result := PackedStringArray()
	for clue: Dictionary in CLUES:
		if QuestLog.is_completed(clue.quest):
			result.append(clue.text)
	return result


func save_data() -> Dictionary:
	return {"pressed": pressed}


func load_data(data: Dictionary) -> void:
	pressed = {}
	var saved: Dictionary = data.get("pressed", {})
	for id in saved:
		if _by_id.has(str(id)):
			pressed[str(id)] = saved[id]
	changed.emit()
