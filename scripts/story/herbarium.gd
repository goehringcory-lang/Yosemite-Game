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
const FRAME := 32
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
## How rare a plant is. Rarer plants grow in fewer patches, and glint gold.
const COMMON := 0
const UNCOMMON := 1
const RARE := 2
const VERY_RARE := 3
const RARITY_NAMES := ["Common", "Uncommon", "Rare", "Very rare"]
## How many patches of a plant grow in each region it grows in, by rarity.
const PATCHES := [3, 2, 1, 1]
const HABITAT_NAMES := {ItemData.Habitat.MEADOW: "open meadow", ItemData.Habitat.OAK_WOODLAND: "under the black oaks",
	ItemData.Habitat.CHAPARRAL: "dry brush", ItemData.Habitat.RIVERSIDE: "the water's edge",
	ItemData.Habitat.FOREST: "conifer shade", ItemData.Habitat.HIGH_COUNTRY: "high granite sand"}

## Every plant in the press book, in book order (the Valley floor, then down
## the canyon, the big trees, the rim, and the high country).
##   "note":      one or two lines of natural history, shown when it's found
##   "seasons":   when a specimen can be found (a mask of SPRING..WINTER)
##   "habitat":   an ItemData.Habitat
##   "grows":     region id -> a named spot it grows near ("" = anywhere there)
##   "rarity":    COMMON (the default), UNCOMMON, RARE or VERY_RARE: how many
##                patches of it grow in each region (see PATCHES)
##   "protected": not to be picked. The player sketches it instead, and
##                "sketch" says why (by default, that it's too rare to pick).
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
	{"id": "white_alder", "name": "White Alder", "latin": "Alnus rhombifolia",
		"note": "Toothed leaves and tiny woody cones like pine cones for a doll. Its roots hold the riverbank.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.RIVERSIDE,
		"grows": {"ahwahnee_trail": "river_bank", "yosemite_valley": ""}},
	{"id": "black_cottonwood", "name": "Black Cottonwood", "latin": "Populus trichocarpa",
		"note": "Sticky buds that smell of balsam, and in June the air along the river fills with its fluff.",
		"seasons": GROWING, "habitat": ItemData.Habitat.RIVERSIDE,
		"grows": {"yosemite_village": "", "yosemite_valley": ""}},
	{"id": "shining_willow", "name": "Shining Willow", "latin": "Salix lasiandra",
		"note": "Long glossy leaves, pale underneath. Every gravel bar on the Merced has a thicket of it.",
		"seasons": GROWING, "habitat": ItemData.Habitat.RIVERSIDE,
		"grows": {"curry_village": "", "yosemite_valley": ""}},
	{"id": "scouring_rush", "name": "Scouring Rush", "latin": "Equisetum hyemale",
		"note": "Jointed green tubes, gritty with silica. Campers scoured their pots with it.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.RIVERSIDE,
		"grows": {"curry_village": "", "ahwahnee_trail": "bridge_west"}},
	{"id": "white_fir", "name": "White Fir", "latin": "Abies concolor",
		"note": "Soft flat needles, blue-gray and two inches long. Bruise one: it smells of citrus.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.FOREST,
		"grows": {"curry_village": "", "yosemite_valley": "", "wawona": ""}},
	{"id": "douglas_fir", "name": "Douglas-fir", "latin": "Pseudotsuga menziesii",
		"note": "Not a true fir. Its cones have three-pointed bracts, like a mouse's hind legs and tail.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.FOREST, "rarity": UNCOMMON,
		"grows": {"yosemite_village": "lower_yosemite_fall", "yosemite_valley": ""}},
	{"id": "bigleaf_maple", "name": "Bigleaf Maple", "latin": "Acer macrophyllum",
		"note": "Leaves as wide as a dinner plate, and paired seeds that spin down like propellers.",
		"seasons": GROWING, "habitat": ItemData.Habitat.FOREST, "rarity": UNCOMMON,
		"grows": {"the_ahwahnee": "cascade", "yosemite_valley": ""}},
	{"id": "california_bay", "name": "California Bay", "latin": "Umbellularia californica",
		"note": "Crush a leaf and step back: it's sharper than kitchen bay, and it'll make your head ache.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.FOREST, "rarity": UNCOMMON,
		"grows": {"the_ahwahnee": "", "yosemite_valley": ""}},
	{"id": "thimbleberry", "name": "Thimbleberry", "latin": "Rubus parviflorus",
		"note": "Soft maple-shaped leaves, white flowers, and a red berry that sits on your fingertip.",
		"seasons": GROWING, "habitat": ItemData.Habitat.FOREST,
		"grows": {"yosemite_village": "", "the_ahwahnee": ""}},
	{"id": "wood_rose", "name": "Wood Rose", "latin": "Rosa gymnocarpa",
		"note": "A small pink rose in the pine shade. Its hips drop their sepals, so they look bald.",
		"seasons": GROWING, "habitat": ItemData.Habitat.FOREST,
		"grows": {"ahwahnee_trail": "", "curry_village": ""}},
	{"id": "deer_brush", "name": "Deer Brush", "latin": "Ceanothus integerrimus",
		"note": "Clouds of white and powder-blue flowers in May. Deer browse it to the nub.",
		"seasons": GROWING, "habitat": ItemData.Habitat.CHAPARRAL,
		"grows": {"yosemite_valley": "", "lamon_homestead": "", "wawona": ""}},
	{"id": "mugwort", "name": "Mugwort", "latin": "Artemisia douglasiana",
		"note": "Gray-backed leaves with a sage smell. Rub some on your hands after you brush poison oak.",
		"seasons": GROWING, "habitat": ItemData.Habitat.MEADOW,
		"grows": {"lamon_homestead": "", "yosemite_valley": ""}},
	{"id": "common_yarrow", "name": "Common Yarrow", "latin": "Achillea millefolium",
		"note": "Flat white flower heads over leaves as fine as feathers. It grows from the Valley to the crest.",
		"seasons": GROWING, "habitat": ItemData.Habitat.MEADOW,
		"grows": {"lamon_homestead": "", "the_ahwahnee": "ahwahnee_meadow", "tuolumne_meadows": "tuolumne_lodge"}},
	{"id": "western_buttercup", "name": "Western Buttercup", "latin": "Ranunculus occidentalis",
		"note": "Petals so glossy they shine back at the sun. Hold one under your chin.",
		"seasons": SPRING, "habitat": ItemData.Habitat.MEADOW,
		"grows": {"ahwahnee_trail": "meadow", "yosemite_village": "cooks_meadow"}},
	{"id": "blue_eyed_grass", "name": "Blue-eyed Grass", "latin": "Sisyrinchium bellum",
		"note": "Not a grass but an iris: six blue petals with a yellow eye, on a flat green blade.",
		"seasons": SPRING, "habitat": ItemData.Habitat.MEADOW,
		"grows": {"the_ahwahnee": "ahwahnee_meadow", "el_portal": "railroad"}},
	{"id": "california_goldenrod", "name": "California Goldenrod", "latin": "Solidago velutina",
		"note": "Plumes of tiny yellow flowers when the meadows go dry. The last bees of the year work it.",
		"seasons": SUMMER | FALL, "habitat": ItemData.Habitat.MEADOW,
		"grows": {"yosemite_village": "cooks_meadow", "yosemite_valley": ""}},
	{"id": "spreading_dogbane", "name": "Spreading Dogbane", "latin": "Apocynum androsaemifolium",
		"note": "Little pink bells on red stems, and milky sap. Its fibers made the best cordage.",
		"seasons": SUMMER, "habitat": ItemData.Habitat.MEADOW,
		"grows": {"yosemite_valley": "el_capitan_meadow"}},
	{"id": "sticky_cinquefoil", "name": "Sticky Cinquefoil", "latin": "Drymocallis glandulosa",
		"note": "Five pale yellow petals like a strawberry's cousin, and leaves sticky to the touch.",
		"seasons": SUMMER, "habitat": ItemData.Habitat.MEADOW,
		"grows": {"yosemite_village": "", "curry_village": ""}},
	{"id": "evening_primrose", "name": "Hooker's Evening Primrose", "latin": "Oenothera elata",
		"note": "Tall stalks of yellow cups that open at dusk, for the moths, and wilt by noon.",
		"seasons": SUMMER, "habitat": ItemData.Habitat.MEADOW, "rarity": UNCOMMON,
		"grows": {"yosemite_village": "cooks_meadow", "yosemite_valley": ""}},
	{"id": "sneezeweed", "name": "Bigelow's Sneezeweed", "latin": "Helenium bigelovii",
		"note": "A brown dome ringed with yellow rays that point down like a skirt. It wants wet meadow.",
		"seasons": SUMMER, "habitat": ItemData.Habitat.MEADOW, "rarity": UNCOMMON,
		"grows": {"ahwahnee_trail": "meadow", "wawona": ""}},
	{"id": "california_rose", "name": "California Wild Rose", "latin": "Rosa californica",
		"note": "Pink roses along the ditches in June, and red hips all winter for the birds.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.RIVERSIDE,
		"grows": {"lamon_homestead": ""}},
	{"id": "broadleaf_cattail", "name": "Broadleaf Cattail", "latin": "Typha latifolia",
		"note": "Brown velvet sausages on tall stalks. In winter they burst into fluff that lines the birds' nests.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.RIVERSIDE,
		"grows": {"lamon_homestead": ""}},
	{"id": "seep_monkeyflower", "name": "Seep-spring Monkeyflower", "latin": "Erythranthe guttata",
		"note": "Yellow snapdragon faces with red freckles in the throat, wherever water seeps from rock.",
		"seasons": SPRING | SUMMER, "habitat": ItemData.Habitat.RIVERSIDE,
		"grows": {"curry_village": "", "tuolumne_meadows": "soda_springs"}},
	{"id": "crimson_columbine", "name": "Crimson Columbine", "latin": "Aquilegia formosa",
		"note": "Red spurs with yellow skirts, nodding over the spray. Hummingbirds sip the spur tips.",
		"seasons": SPRING | SUMMER, "habitat": ItemData.Habitat.RIVERSIDE, "rarity": UNCOMMON,
		"grows": {"yosemite_village": "lower_yosemite_fall", "glacier_point": ""}},
	{"id": "maidenhair_fern", "name": "Five-finger Maidenhair", "latin": "Adiantum aleuticum",
		"note": "Black wiry stems and fronds spread like a hand, in the spray at the foot of the falls.",
		"seasons": GROWING, "habitat": ItemData.Habitat.RIVERSIDE, "rarity": UNCOMMON,
		"grows": {"yosemite_village": "lower_yosemite_fall", "the_ahwahnee": "cascade"}},
	{"id": "indian_rhubarb", "name": "Indian Rhubarb", "latin": "Darmera peltata",
		"note": "Pink flowers on bare stalks first, then leaves like umbrellas standing in the stream.",
		"seasons": SPRING | SUMMER, "habitat": ItemData.Habitat.RIVERSIDE, "rarity": UNCOMMON,
		"grows": {"yosemite_valley": "happy_isles", "wawona": ""}},
	{"id": "chokecherry", "name": "Western Chokecherry", "latin": "Prunus virginiana",
		"note": "Bottlebrushes of white flowers, then dark cherries so sour they pucker your whole face.",
		"seasons": GROWING, "habitat": ItemData.Habitat.RIVERSIDE, "rarity": UNCOMMON,
		"grows": {"yosemite_valley": "mirror_lake"}},
	{"id": "leopard_lily", "name": "Leopard Lily", "latin": "Lilium pardalinum",
		"note": "Orange turk's-caps spotted maroon, petals swept back, on stalks taller than you.",
		"seasons": SUMMER, "habitat": ItemData.Habitat.RIVERSIDE, "rarity": RARE,
		"grows": {"yosemite_valley": "happy_isles", "the_ahwahnee": "cascade"}},
	{"id": "stream_orchid", "name": "Stream Orchid", "latin": "Epipactis gigantea",
		"note": "Little green-and-rust orchids along a dripping wall. Look close: a face in every flower.",
		"seasons": SUMMER, "habitat": ItemData.Habitat.RIVERSIDE, "rarity": RARE,
		"grows": {"yosemite_valley": "happy_isles"}},
	{"id": "hazelnut", "name": "California Hazelnut", "latin": "Corylus cornuta",
		"note": "Soft, fuzzy leaves and nuts in a bristly husk. Its straight shoots were basket rods.",
		"seasons": GROWING, "habitat": ItemData.Habitat.FOREST, "rarity": UNCOMMON,
		"grows": {"yosemite_valley": "", "wawona": "mariposa_grove"}},
	{"id": "poison_oak", "name": "Western Poison Oak", "latin": "Toxicodendron diversilobum",
		"note": "Leaves of three, glossy, red in fall. Every part of it, even bare winter twigs, will blister you.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.OAK_WOODLAND, "protected": true,
		"sketch": "You'd rather not touch it. You draw it from a careful step away.",
		"grows": {"yosemite_valley": "", "el_portal": ""}},
	{"id": "oregon_grape", "name": "Oregon-grape", "latin": "Berberis aquifolium",
		"note": "Holly-like leaflets and sour blue berries. The yellow inner bark made a dye.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.FOREST,
		"grows": {"yosemite_valley": "", "wawona": "wawona_hotel"}},
	{"id": "deergrass", "name": "Deergrass", "latin": "Muhlenbergia rigens",
		"note": "Big fountain-shaped clumps. The long straight flower stalks are the foundation of a basket coil.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.MEADOW, "rarity": UNCOMMON,
		"grows": {"yosemite_valley": "", "wawona": ""}},
	{"id": "wild_ginger", "name": "Hartweg's Wild Ginger", "latin": "Asarum hartwegii",
		"note": "Heart-shaped leaves veined silver, and a brown three-tailed flower hidden underneath.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.FOREST, "rarity": UNCOMMON,
		"grows": {"yosemite_valley": "", "wawona": "mariposa_grove"}},
	{"id": "california_fuchsia", "name": "California Fuchsia", "latin": "Epilobium canum",
		"note": "Scarlet trumpets on dry ledges at the very end of summer, the hummingbirds' last meal.",
		"seasons": SUMMER | FALL, "habitat": ItemData.Habitat.CHAPARRAL, "rarity": UNCOMMON,
		"grows": {"yosemite_valley": "", "glacier_point": ""}},
	{"id": "mountain_lady_slipper", "name": "Mountain Lady's Slipper", "latin": "Cypripedium montanum",
		"note": "A white pouch under twisted brown petals. A seed needs one fungus, and years, to grow.",
		"seasons": SPRING | SUMMER, "habitat": ItemData.Habitat.FOREST, "rarity": VERY_RARE, "protected": true,
		"grows": {"yosemite_valley": ""}},
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
	{"id": "interior_live_oak", "name": "Interior Live Oak", "latin": "Quercus wislizeni",
		"note": "Glossy green leaves on both sides, and acorns that take two years to ripen.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.OAK_WOODLAND,
		"grows": {"el_portal": ""}},
	{"id": "blue_oak", "name": "Blue Oak", "latin": "Quercus douglasii",
		"note": "Wavy leaves with a blue cast, on the hottest, driest slopes. It drops them to wait out drought.",
		"seasons": GROWING, "habitat": ItemData.Habitat.OAK_WOODLAND, "rarity": UNCOMMON,
		"grows": {"el_portal": "arrival"}},
	{"id": "whiteleaf_manzanita", "name": "Whiteleaf Manzanita", "latin": "Arctostaphylos viscida",
		"note": "Chalky gray-white leaves, sticky twigs, and pink bells in late winter before anything else.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.CHAPARRAL,
		"grows": {"el_portal": ""}},
	{"id": "toyon", "name": "Toyon", "latin": "Heteromeles arbutifolia",
		"note": "Leathery toothed leaves and red berries at Christmas, so it's called California holly.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.CHAPARRAL,
		"grows": {"el_portal": "yosemite_view_lodge"}},
	{"id": "chamise", "name": "Chamise", "latin": "Adenostoma fasciculatum",
		"note": "Needle leaves in bundles and a froth of white flowers. It burns hot and sprouts right back.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.CHAPARRAL,
		"grows": {"el_portal": ""}},
	{"id": "yerba_santa", "name": "Yerba Santa", "latin": "Eriodictyon californicum",
		"note": "Long leaves, varnished on top and felted below. Steeped, it was a tea for colds.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.CHAPARRAL,
		"grows": {"el_portal": "arch_rock"}},
	{"id": "bush_monkeyflower", "name": "Sticky Monkeyflower", "latin": "Diplacus aurantiacus",
		"note": "Apricot trumpets on a sticky shrub that holds on to the hottest rock in the canyon.",
		"seasons": SPRING | SUMMER, "habitat": ItemData.Habitat.CHAPARRAL,
		"grows": {"el_portal": ""}},
	{"id": "blue_elderberry", "name": "Blue Elderberry", "latin": "Sambucus nigra ssp. caerulea",
		"note": "Flat cream flower heads, then dusty blue berries. Its hollow stems made clapper sticks.",
		"seasons": GROWING, "habitat": ItemData.Habitat.RIVERSIDE,
		"grows": {"el_portal": ""}},
	{"id": "wild_grape", "name": "California Wild Grape", "latin": "Vitis californica",
		"note": "A vine that climbs the alders to their tops. Small sour grapes, and leaves gone scarlet in fall.",
		"seasons": GROWING, "habitat": ItemData.Habitat.RIVERSIDE, "rarity": UNCOMMON,
		"grows": {"el_portal": "railroad"}},
	{"id": "spicebush", "name": "Western Spicebush", "latin": "Calycanthus occidentalis",
		"note": "Maroon flowers that smell of old wine, along the creek. Crushed, the leaves smell of spice.",
		"seasons": GROWING, "habitat": ItemData.Habitat.RIVERSIDE, "rarity": UNCOMMON,
		"grows": {"el_portal": "yosemite_view_lodge"}},
	{"id": "elegant_clarkia", "name": "Elegant Clarkia", "latin": "Clarkia unguiculata",
		"note": "Pink petals on thin stalks, like little spoons. Named for William Clark, of Lewis and Clark.",
		"seasons": SPRING | SUMMER, "habitat": ItemData.Habitat.MEADOW,
		"grows": {"el_portal": "railroad"}},
	{"id": "blue_dicks", "name": "Blue Dicks", "latin": "Dipterostemon capitatus",
		"note": "A tight head of violet flowers on a bare stalk. The corm was dug and eaten in spring.",
		"seasons": SPRING, "habitat": ItemData.Habitat.MEADOW,
		"grows": {"el_portal": "arch_rock"}},
	{"id": "harvest_brodiaea", "name": "Harvest Brodiaea", "latin": "Brodiaea elegans",
		"note": "Deep violet funnels that open after the grass has gone gold, when the harvest comes in.",
		"seasons": SUMMER, "habitat": ItemData.Habitat.MEADOW,
		"grows": {"el_portal": ""}},
	{"id": "chinese_houses", "name": "Chinese Houses", "latin": "Collinsia heterophylla",
		"note": "Whorls of purple-and-white flowers stacked up the stem like the tiers of a pagoda.",
		"seasons": SPRING, "habitat": ItemData.Habitat.MEADOW, "rarity": UNCOMMON,
		"grows": {"el_portal": "yosemite_view_lodge"}},
	{"id": "fiesta_flower", "name": "Fiesta Flower", "latin": "Pholistoma auritum",
		"note": "Lavender saucers on a sprawling stem with tiny hooks. It catches on your sleeves.",
		"seasons": SPRING, "habitat": ItemData.Habitat.FOREST, "rarity": UNCOMMON,
		"grows": {"el_portal": ""}},
	{"id": "soap_plant", "name": "Soap Plant", "latin": "Chlorogalum pomeridianum",
		"note": "Wavy leaves and a bulb in a hairy coat. Crushed in water it lathers; the fibers made brushes.",
		"seasons": SPRING | SUMMER, "habitat": ItemData.Habitat.OAK_WOODLAND, "rarity": UNCOMMON,
		"grows": {"el_portal": ""}},
	{"id": "coffee_fern", "name": "Coffee Fern", "latin": "Pellaea andromedifolia",
		"note": "Stiff blue-green beads of fronds that curl up in drought and wait for rain.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.CHAPARRAL, "rarity": UNCOMMON,
		"grows": {"el_portal": "arch_rock"}},
	{"id": "pacific_madrone", "name": "Pacific Madrone", "latin": "Arbutus menziesii",
		"note": "Red bark that peels in curls to show green beneath, and orange berries in fall.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.FOREST, "rarity": UNCOMMON,
		"grows": {"el_portal": "arch_rock"}},
	{"id": "superb_mariposa_lily", "name": "Superb Mariposa Lily", "latin": "Calochortus superbus",
		"note": "Three cupped petals painted with a dark eyespot, like a butterfly's wing. 'Mariposa.'",
		"seasons": SPRING | SUMMER, "habitat": ItemData.Habitat.MEADOW, "rarity": RARE,
		"grows": {"el_portal": "railroad", "wawona": ""}},
	{"id": "congdons_lewisia", "name": "Congdon's Lewisia", "latin": "Lewisia congdonii",
		"note": "Pink-striped flowers on wet cliffs of the Merced canyon, and almost nowhere else on earth.",
		"seasons": SPRING, "habitat": ItemData.Habitat.CHAPARRAL, "rarity": VERY_RARE, "protected": true,
		"grows": {"el_portal": "arch_rock"}},
	{"id": "yosemite_onion", "name": "Yosemite Onion", "latin": "Allium yosemitense",
		"note": "A pale pink onion on bare granite sand. Found only in the hills around Yosemite.",
		"seasons": SPRING, "habitat": ItemData.Habitat.CHAPARRAL, "rarity": VERY_RARE, "protected": true,
		"grows": {"el_portal": ""}},
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
	{"id": "common_camas", "name": "Common Camas", "latin": "Camassia quamash",
		"note": "Starry blue flowers over a wet meadow. The bulbs were dug, pit-roasted, and eaten.",
		"seasons": SPRING, "habitat": ItemData.Habitat.MEADOW, "rarity": UNCOMMON,
		"grows": {"wawona": ""}},
	{"id": "sierra_plum", "name": "Sierra Plum", "latin": "Prunus subcordata",
		"note": "A thorny little plum tree, white with blossom in April, with tart red fruit by August.",
		"seasons": GROWING, "habitat": ItemData.Habitat.OAK_WOODLAND, "rarity": UNCOMMON,
		"grows": {"wawona": "wawona_hotel"}},
	{"id": "pacific_starflower", "name": "Pacific Starflower", "latin": "Lysimachia latifolia",
		"note": "A pink star held up over a whorl of leaves on a stem as thin as thread.",
		"seasons": SPRING | SUMMER, "habitat": ItemData.Habitat.FOREST, "rarity": UNCOMMON,
		"grows": {"wawona": "mariposa_grove"}},
	{"id": "washington_lily", "name": "Washington Lily", "latin": "Lilium washingtonianum",
		"note": "White trumpets that smell like a perfume shop and blush purple as they age.",
		"seasons": SUMMER, "habitat": ItemData.Habitat.FOREST, "rarity": RARE,
		"grows": {"wawona": ""}},
	{"id": "spotted_coralroot", "name": "Spotted Coralroot", "latin": "Corallorhiza maculata",
		"note": "A leafless orchid, all red-brown stem and tiny spotted flowers. It feeds on fungi.",
		"seasons": SPRING | SUMMER, "habitat": ItemData.Habitat.FOREST, "rarity": RARE, "protected": true,
		"grows": {"wawona": "mariposa_grove"}},
	{"id": "sugar_stick", "name": "Sugar Stick", "latin": "Allotropa virgata",
		"note": "A white stalk striped red like a peppermint stick, with no green at all. Seldom seen.",
		"seasons": SUMMER, "habitat": ItemData.Habitat.FOREST, "rarity": VERY_RARE, "protected": true,
		"grows": {"wawona": "grizzly_giant"}},
	{"id": "yosemite_ivesia", "name": "Yosemite Ivesia", "latin": "Ivesia unguiculata",
		"note": "Tiny white flowers on wet meadow edges, found only in the Sierra near Yosemite.",
		"seasons": SUMMER, "habitat": ItemData.Habitat.MEADOW, "rarity": VERY_RARE, "protected": true,
		"grows": {"wawona": ""}},
	{"id": "bolanders_clover", "name": "Bolander's Clover", "latin": "Trifolium bolanderi",
		"note": "A creeping clover with pale pink heads. Only a few meadows in the world have it.",
		"seasons": SUMMER, "habitat": ItemData.Habitat.MEADOW, "rarity": VERY_RARE, "protected": true,
		"grows": {"wawona": ""}},
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
	{"id": "snow_plant", "name": "Snow Plant", "latin": "Sarcodes sanguinea", "rarity": RARE, "protected": true,
		"note": "All scarlet, no green. It lives on the fungi at the pines' roots and comes up as the snow goes.",
		"seasons": SPRING | SUMMER, "habitat": ItemData.Habitat.FOREST,
		"grows": {"glacier_point": "arrival"}},
	{"id": "huckleberry_oak", "name": "Huckleberry Oak", "latin": "Quercus vacciniifolia",
		"note": "An oak that never grows past your waist: a tangle of small leaves over the granite.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.CHAPARRAL,
		"grows": {"glacier_point": "washburn_point"}},
	{"id": "bush_chinquapin", "name": "Bush Chinquapin", "latin": "Chrysolepis sempervirens",
		"note": "Leaves gold-dusted underneath and nuts in a burr as spiny as a sea urchin.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.CHAPARRAL,
		"grows": {"glacier_point": ""}},
	{"id": "mountain_whitethorn", "name": "Mountain Whitethorn", "latin": "Ceanothus cordulatus",
		"note": "Flat-topped, gray-green and thorny, with white flowers that smell of honey.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.CHAPARRAL,
		"grows": {"glacier_point": "sentinel_dome"}},
	{"id": "sulphur_buckwheat", "name": "Sulphur Buckwheat", "latin": "Eriogonum umbellatum",
		"note": "Balls of yellow flowers held up over a mat of leaves, turning rust as they dry.",
		"seasons": SUMMER | FALL, "habitat": ItemData.Habitat.CHAPARRAL,
		"grows": {"glacier_point": "sentinel_dome"}},
	{"id": "scarlet_gilia", "name": "Scarlet Gilia", "latin": "Ipomopsis aggregata",
		"note": "Red trumpets flecked with white, for hummingbirds. Later in summer the moths take over.",
		"seasons": SUMMER, "habitat": ItemData.Habitat.CHAPARRAL,
		"grows": {"glacier_point": ""}},
	{"id": "tobacco_brush", "name": "Tobacco Brush", "latin": "Ceanothus velutinus",
		"note": "Glossy, varnished leaves that smell of cinnamon on a hot day. Its seeds wait for fire.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.CHAPARRAL, "rarity": UNCOMMON,
		"grows": {"glacier_point": "washburn_point"}},
	{"id": "mountain_pride", "name": "Mountain Pride", "latin": "Penstemon newberryi",
		"note": "Hot-pink tubes spilling out of a crack in bare granite, as if the rock were blooming.",
		"seasons": SUMMER, "habitat": ItemData.Habitat.CHAPARRAL, "rarity": UNCOMMON,
		"grows": {"glacier_point": "sentinel_dome"}},
	{"id": "ocean_spray", "name": "Mountain Spray", "latin": "Holodiscus microphyllus",
		"note": "Cream plumes of tiny flowers that fade to brown and stay on all winter.",
		"seasons": SUMMER, "habitat": ItemData.Habitat.CHAPARRAL, "rarity": UNCOMMON,
		"grows": {"glacier_point": "apron_top"}},
	{"id": "western_white_pine", "name": "Western White Pine", "latin": "Pinus monticola",
		"note": "Soft blue-green needles in fives and long slender cones. Its bark breaks in checkers.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.FOREST, "rarity": UNCOMMON,
		"grows": {"glacier_point": "sentinel_dome"}},
	{"id": "sierra_currant", "name": "Sierra Currant", "latin": "Ribes nevadense",
		"note": "Rosy pink tassels of flowers by the springs, and blue-black berries dusted white.",
		"seasons": GROWING, "habitat": ItemData.Habitat.RIVERSIDE, "rarity": UNCOMMON,
		"grows": {"glacier_point": ""}},
	{"id": "sierra_gooseberry", "name": "Sierra Gooseberry", "latin": "Ribes roezlii",
		"note": "Purple berries covered in prickles, on a shrub that's all thorns. Bears eat them anyway.",
		"seasons": GROWING, "habitat": ItemData.Habitat.FOREST, "rarity": UNCOMMON,
		"grows": {"glacier_point": "arrival"}},
	{"id": "pinedrops", "name": "Pinedrops", "latin": "Pterospora andromedea",
		"note": "A sticky red-brown stalk hung with cream bells. No green, no leaves: it feeds on fungi.",
		"seasons": SUMMER, "habitat": ItemData.Habitat.FOREST, "rarity": RARE,
		"grows": {"glacier_point": "washburn_point", "wawona": ""}},
	{"id": "yosemite_bog_orchid", "name": "Yosemite Bog Orchid", "latin": "Platanthera yosemitensis",
		"note": "Greenish flowers that smell like sweaty feet. It grows in a few wet meadows here and nowhere else.",
		"seasons": SUMMER, "habitat": ItemData.Habitat.RIVERSIDE, "rarity": VERY_RARE, "protected": true,
		"grows": {"glacier_point": ""}},
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
	{"id": "red_heather", "name": "Red Mountain Heather", "latin": "Phyllodoce breweri",
		"note": "Rose-pink saucers over needle-thin leaves, a mat of it along every granite seep.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.HIGH_COUNTRY,
		"grows": {"tuolumne_meadows": "cathedral_lakes_trailhead"}},
	{"id": "pussypaws", "name": "Pussypaws", "latin": "Calyptridium umbellatum",
		"note": "Fuzzy pink pads on granite sand. They lie down in the cool of morning and rise in the heat.",
		"seasons": SUMMER, "habitat": ItemData.Habitat.HIGH_COUNTRY,
		"grows": {"tuolumne_meadows": "lembert_dome"}},
	{"id": "mule_ears", "name": "Mountain Mule Ears", "latin": "Wyethia mollis",
		"note": "Big woolly leaves like a mule's ears and yellow sunflowers. The leaves rattle in the wind.",
		"seasons": SUMMER, "habitat": ItemData.Habitat.HIGH_COUNTRY,
		"grows": {"tuolumne_meadows": ""}},
	{"id": "corn_lily", "name": "Corn Lily", "latin": "Veratrum californicum",
		"note": "Pleated leaves on stalks head-high, like corn in the meadow. Every part of it is poison.",
		"seasons": SUMMER, "habitat": ItemData.Habitat.MEADOW,
		"grows": {"tuolumne_meadows": "soda_springs"}},
	{"id": "shorthair_sedge", "name": "Shorthair Sedge", "latin": "Carex filifolia var. erostrata",
		"note": "The fine green turf of the meadow itself. Sedges have edges: roll a stem, it's three-sided.",
		"seasons": GROWING, "habitat": ItemData.Habitat.MEADOW,
		"grows": {"tuolumne_meadows": ""}},
	{"id": "fireweed", "name": "Fireweed", "latin": "Chamaenerion angustifolium",
		"note": "Magenta spires that come up first after a burn. By fall the pods spill silky seed.",
		"seasons": SUMMER | FALL, "habitat": ItemData.Habitat.MEADOW,
		"grows": {"tuolumne_meadows": "tuolumne_lodge"}},
	{"id": "lemmons_willow", "name": "Lemmon's Willow", "latin": "Salix lemmonii",
		"note": "A shrubby willow in thickets by the Tuolumne. Its catkins feed the first bees of the year.",
		"seasons": GROWING, "habitat": ItemData.Habitat.RIVERSIDE,
		"grows": {"tuolumne_meadows": ""}},
	{"id": "mountain_hemlock", "name": "Mountain Hemlock", "latin": "Tsuga mertensiana",
		"note": "Its top always nods over, as if bowing. Muir thought it the most beautiful conifer of all.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.HIGH_COUNTRY, "rarity": UNCOMMON,
		"grows": {"tuolumne_meadows": "cathedral_lakes_trailhead"}},
	{"id": "quaking_aspen", "name": "Quaking Aspen", "latin": "Populus tremuloides",
		"note": "Round leaves on flat stalks that shiver in the lightest air, then turn gold all at once.",
		"seasons": GROWING, "habitat": ItemData.Habitat.RIVERSIDE, "rarity": UNCOMMON,
		"grows": {"tuolumne_meadows": "lembert_dome"}},
	{"id": "labrador_tea", "name": "Western Labrador Tea", "latin": "Rhododendron columbianum",
		"note": "White flower clusters over leathery leaves rolled under at the edges, in cold bogs.",
		"seasons": SUMMER, "habitat": ItemData.Habitat.RIVERSIDE, "rarity": UNCOMMON,
		"grows": {"tuolumne_meadows": ""}},
	{"id": "alpine_laurel", "name": "Alpine Laurel", "latin": "Kalmia microphylla",
		"note": "Pink cups whose stamens are tucked in like sprung traps. A bee lands, and they flick pollen.",
		"seasons": SUMMER, "habitat": ItemData.Habitat.RIVERSIDE, "rarity": UNCOMMON,
		"grows": {"tuolumne_meadows": "soda_springs"}},
	{"id": "elephants_head", "name": "Elephant's Head", "latin": "Pedicularis groenlandica",
		"note": "Look close at the pink spike: every flower is a tiny elephant, trunk and ears and all.",
		"seasons": SUMMER, "habitat": ItemData.Habitat.MEADOW, "rarity": UNCOMMON,
		"grows": {"tuolumne_meadows": "soda_springs"}},
	{"id": "lewis_monkeyflower", "name": "Lewis's Monkeyflower", "latin": "Erythranthe lewisii",
		"note": "Rose-pink faces with yellow-haired throats along the cold streams. Bumblebees crawl right in.",
		"seasons": SUMMER, "habitat": ItemData.Habitat.RIVERSIDE, "rarity": UNCOMMON,
		"grows": {"tuolumne_meadows": "", "glacier_point": ""}},
	{"id": "dwarf_bilberry", "name": "Dwarf Bilberry", "latin": "Vaccinium cespitosum",
		"note": "Ankle-high, with pink urns for flowers and blue berries by August, if the bears leave any.",
		"seasons": SUMMER | FALL, "habitat": ItemData.Habitat.MEADOW, "rarity": UNCOMMON,
		"grows": {"tuolumne_meadows": "tuolumne_lodge"}},
	{"id": "leichtlins_mariposa", "name": "Leichtlin's Mariposa Lily", "latin": "Calochortus leichtlinii",
		"note": "Three white petals each with a black spot over yellow, on dry granite gravel.",
		"seasons": SUMMER, "habitat": ItemData.Habitat.HIGH_COUNTRY, "rarity": UNCOMMON,
		"grows": {"tuolumne_meadows": "lembert_dome"}},
	{"id": "whitebark_pine", "name": "Whitebark Pine", "latin": "Pinus albicaulis",
		"note": "Wind-bent at timberline. Nutcrackers bury its seeds by the thousand and forget a few.",
		"seasons": ALL_YEAR, "habitat": ItemData.Habitat.HIGH_COUNTRY, "rarity": RARE,
		"grows": {"tuolumne_meadows": "lembert_dome"}},
	{"id": "sierra_gentian", "name": "Sierra Gentian", "latin": "Gentianopsis holopetala",
		"note": "Deep blue trumpets that twist shut at night and in shade, late in a meadow's summer.",
		"seasons": SUMMER | FALL, "habitat": ItemData.Habitat.MEADOW, "rarity": RARE,
		"grows": {"tuolumne_meadows": "soda_springs"}},
	{"id": "explorers_gentian", "name": "Explorer's Gentian", "latin": "Gentiana calycosa",
		"note": "One blue-violet bell per stem, by a cold creek. Find it and you're far from the road.",
		"seasons": SUMMER | FALL, "habitat": ItemData.Habitat.RIVERSIDE, "rarity": RARE,
		"grows": {"tuolumne_meadows": "cathedral_lakes_trailhead"}},
	{"id": "white_bog_orchid", "name": "White Bog Orchid", "latin": "Platanthera dilatata",
		"note": "A spike of small white orchids that smell of cloves, standing in the wettest meadow.",
		"seasons": SUMMER, "habitat": ItemData.Habitat.MEADOW, "rarity": UNCOMMON,
		"grows": {"tuolumne_meadows": "soda_springs"}},
	{"id": "sierra_primrose", "name": "Sierra Primrose", "latin": "Primula suffrutescens",
		"note": "Magenta primroses with yellow eyes, wedged in granite cracks where the snow lies late.",
		"seasons": SUMMER, "habitat": ItemData.Habitat.HIGH_COUNTRY, "rarity": RARE,
		"grows": {"tuolumne_meadows": "cathedral_lakes_trailhead"}},
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


## COMMON, UNCOMMON, RARE or VERY_RARE.
static func rarity(plant: Dictionary) -> int:
	return int(plant.get("rarity", COMMON))


static func rarity_name(plant: Dictionary) -> String:
	return RARITY_NAMES[rarity(plant)]


## How many patches of [param plant] grow in each region it grows in.
static func patches(plant: Dictionary) -> int:
	return PATCHES[rarity(plant)]


## What the player writes instead of pressing a protected plant.
static func sketch_reason(plant: Dictionary) -> String:
	return plant.get("sketch", "Too rare to pick. You draw it in the press book and leave it standing.")


## How many plants of [param at_least] rarity or rarer are in the book, and
## how many there are: [found, total].
func rare_count(at_least := RARE) -> Array[int]:
	var found := 0
	var all := 0
	for plant: Dictionary in PLANTS:
		if rarity(plant) >= at_least:
			all += 1
			found += int(pressed.has(plant.id))
	return [found, all]


## Puts a plant in the book. Returns true the first time.
func press(id: String, where := "") -> bool:
	if not _by_id.has(id) or pressed.has(id):
		return false
	pressed[id] = {"where": where, "date": GameClock.get_date_string()}
	changed.emit()
	pressed_plant.emit(id)
	return true


## The plant's 32x32 drawing, from the sheet tools/plants/plant_art.gd makes.
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
