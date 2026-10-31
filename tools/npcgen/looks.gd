extends RefCounted
## How each person looks, for tools/npcgen/npcgen.gd. Keys match the
## character id (data/characters/<id>.tres) or visitor id.
##
## Looks follow each person's era and documented photographs where they
## exist. Native people are drawn in the everyday clothes they wore in
## photographs of their time, never regalia. Their looks have been reviewed
## with the associated tribes, like their dialogue.
##
## Keys (all optional):
##   skin, hair, eyes           hex colors
##   hair_style                 short, long, braid, bun, bald, wild, none
##   beard                      none, mustache, goatee, short, long (+ beard_color)
##   hat                        wide, campaign, fedora, bowler, top, cap, painter_cap,
##                              beanie, bonnet, scarf, headband, helmet, toque (+ hat_color, hat_band)
##   top, top2                  shirt color, accent color
##   top_style                  shirt, vest, suspenders, jacket, plaid, sweater, coat,
##                              shawl, blouse, stripes
##   bottom, bottom_style       pants, knickers, skirt, dress (uses top color), coat_long
##   shoes, socks, sleeve, collar, belt, apron, bandana, badge, glasses
##   tattoos                    ink color, on bare arms (set sleeve to the skin)
##   pack                       pack, frame_pack, haul_bag (+ pack_color)
##   carry                      rope, chalk_bag, book, register, basket, loaf, hammer,
##                              drill, camera, stick, cane, parasol, suitcase, rod, shovel,
##                              notebook, apple, lantern, acorn, map

const SKIN_LIGHT := "f0c8a0"
const SKIN_FAIR := "e0ac7e"
const SKIN_TAN := "c8905e"
const SKIN_BROWN := "a8703f"
const SKIN_DEEP := "7e4c2a"

## The player: a ranger-naturalist's wide hat, a green work shirt and a small
## pack. Drawn to assets/sprites/player.png (not a character id, so it is not
## in LOOKS).
const PLAYER := {
	"skin": SKIN_FAIR, "hair": "5a3a22", "hat": "wide", "hat_color": "7a5232", "hat_band": "3a2a20",
	"top": "6b7d4a", "top_style": "shirt", "bottom": "3b4660", "shoes": "3a2a20",
	"pack": "pack", "pack_color": "8a5a30",
}

const LOOKS := {
	# ------------------------------------------------ Valley floor, Chapter 1
	"galen_clark": {
		"skin": SKIN_FAIR, "hair": "e8e4dc", "beard": "long", "hat": "wide", "hat_color": "3a3230",
		"top": "3a3a42", "top_style": "coat", "top2": "22222a", "bottom": "3a3a42", "bottom_style": "coat_long",
		"collar": "e8e0d0", "carry": ["register"],
	},
	"james_lamon": {
		"skin": SKIN_FAIR, "hair": "6a4a2a", "beard": "short", "hat": "wide", "hat_color": "c8a860",
		"top": "a83a2a", "top_style": "suspenders", "top2": "4a3020", "bottom": "5a4a3a", "carry": ["apple"],
	},
	"tenaya": {
		"skin": SKIN_BROWN, "hair": "1a1410", "hair_style": "long",
		"top": "8a6a48", "top_style": "shirt", "bottom": "5a4632", "shoes": "6a4a30",
	},
	"maggie_howard": {
		"skin": SKIN_BROWN, "hair": "2a2220", "hat": "scarf", "hat_color": "a83838",
		"top": "3a4a7a", "top_style": "blouse", "top2": "e0d8c8", "bottom_style": "dress",
		"apron": "d8d0c0", "carry": ["acorn"],
	},
	"bridget_degnan": {
		"skin": SKIN_LIGHT, "hair": "8a4a2a", "hair_style": "bun",
		"top": "4a6a8a", "top_style": "blouse", "top2": "e8e8e0", "bottom_style": "dress",
		"apron": "f0ece0", "carry": ["loaf"],
	},
	"dick_leonard": {
		"skin": SKIN_FAIR, "hair": "3a2a1a",
		"top": "5a738f", "top_style": "shirt", "bottom": "a89870", "bottom_style": "knickers",
		"socks": "7a6a5a", "carry": ["rope"],
	},
	"jules_eichorn": {
		"skin": SKIN_FAIR, "hair": "8a6a3a",
		"top": "7a7a72", "top_style": "sweater", "top2": "5a5a52", "bottom": "b0a078", "bottom_style": "knickers",
		"socks": "8a3a2a", "carry": ["rope"],
	},
	"bestor_robinson": {
		"skin": SKIN_FAIR, "hair": "4a3a2a", "hat": "fedora", "hat_color": "6a5a48", "glasses": true,
		"top": "b09a70", "top_style": "jacket", "top2": "8a7650", "bottom": "6a5a48", "carry": ["hammer"],
	},
	"jennie_curry": {
		"skin": SKIN_LIGHT, "hair": "b0aaa0", "hair_style": "bun",
		"top": "2a2a38", "top_style": "blouse", "top2": "f0ece0", "bottom_style": "dress", "collar": "f0ece0",
		"carry": ["lantern"],
	},
	"george_anderson": {
		"skin": SKIN_FAIR, "hair": "8a5a2a", "beard": "short", "hat": "cap", "hat_color": "2a3040",
		"top": "7a2a2a", "top_style": "shirt", "bottom": "3a3a48", "belt": "3a2a1a", "carry": ["drill"],
	},
	"clare_hodges": {
		"skin": SKIN_LIGHT, "hair": "6a4028", "hair_style": "bun", "hat": "campaign", "hat_color": "8a7048",
		"top": "7a7248", "top_style": "jacket", "top2": "5a5434", "bottom": "7a7248", "badge": true,
		"belt": "4a3020", "shoes": "4a3020",
	},
	"ansel_adams": {
		"skin": SKIN_FAIR, "hair": "5a5048", "beard": "short", "beard_color": "8a8278", "hat": "campaign",
		"hat_color": "4a4038", "top": "3a3a38", "top_style": "jacket", "top2": "6a6a60", "bottom": "5a5a52",
		"carry": ["camera"],
	},
	"lucy_telles": {
		"skin": SKIN_BROWN, "hair": "1e1814", "hair_style": "bun",
		"top": "7a3a4a", "top_style": "blouse", "top2": "d8c8b8", "bottom_style": "dress",
		"apron": "c8c0a8", "carry": ["basket"],
	},
	"maria_lebrado": {
		"skin": SKIN_BROWN, "hair": "c8c4bc", "hair_style": "bun",
		"top": "2a2a30", "top_style": "shawl", "top2": "6a4a5a", "bottom_style": "dress", "carry": ["cane"],
	},
	# ------------------------------------------------ The rim, Chapter 2
	"james_mccauley": {
		"skin": SKIN_FAIR, "hair": "5a3a22", "beard": "mustache", "hat": "bowler", "hat_color": "2a2420",
		"top": "e0d8c8", "top_style": "vest", "top2": "4a3a3a", "bottom": "3a3430", "sleeve": "d8d0c0",
	},
	"enid_michael": {
		"skin": SKIN_LIGHT, "hair": "5a4030", "hair_style": "bun", "hat": "wide", "hat_color": "c8b080",
		"top": "a8a078", "top_style": "blouse", "top2": "e8e0c8", "bottom": "7a6a48", "bottom_style": "skirt",
		"carry": ["notebook"],
	},
	# ------------------------------------------------ Camp 4, Chapters 3–4
	"royal_robbins": {
		"skin": SKIN_FAIR, "hair": "4a3a2a", "hat": "painter_cap", "hat_color": "e8e8e0", "glasses": true,
		"top": "5a7aa0", "top_style": "shirt", "bottom": "d8d0b8", "carry": ["rope", "chalk_bag"],
	},
	"john_salathe": {
		"skin": SKIN_FAIR, "hair": "a8a098", "hair_style": "bald",
		"top": "8a8a7a", "top_style": "shirt", "bottom": "4a4a48", "apron": "5a3a22", "carry": ["hammer"],
	},
	"warren_harding": {
		"skin": SKIN_FAIR, "hair": "2a2018", "hair_style": "wild", "beard": "goatee",
		"top": "a83a2a", "top_style": "plaid", "top2": "3a1a1a", "bottom": "4a5068", "pack": "haul_bag",
		"pack_color": "5a6a3a", "carry": ["hammer"],
	},
	"beverly_johnson": {
		"skin": SKIN_LIGHT, "hair": "d8b060", "hair_style": "long",
		"top": "c84a3a", "top_style": "jacket", "top2": "8a2a22", "bottom": "3a4a6a", "bandana": "3a6a9a",
		"carry": ["rope", "chalk_bag"],
	},
	# ------------------------------------------------ High country, Chapter 5
	"john_muir": {
		"skin": SKIN_FAIR, "hair": "8a6040", "beard": "long", "beard_color": "9a7050",
		"top": "6a5a48", "top_style": "coat", "top2": "4a3e30", "bottom": "5a5040", "carry": ["stick"],
	},
	"carrie_bethel": {
		"skin": SKIN_BROWN, "hair": "221a16", "hat": "scarf", "hat_color": "3a6a5a",
		"top": "6a4a7a", "top_style": "blouse", "top2": "d8d0c0", "bottom_style": "dress", "carry": ["basket"],
	},

	# ------------------------------------------------ Visitors (not quest givers)
	# Everyday people from each era who walk the trails and roads. They are
	# the only people in the game who aren't historical figures, so they never
	# give quests or stand in for anyone real, and none of them is Native.
	"visitor_stage_lady": {
		"skin": SKIN_LIGHT, "hair": "6a4028", "hat": "bonnet", "hat_color": "e0d0b0",
		"top": "7a4a6a", "top_style": "blouse", "top2": "f0e8e0", "bottom_style": "dress", "carry": ["parasol"],
	},
	"visitor_stage_gent": {
		"skin": SKIN_FAIR, "hair": "3a2a1a", "beard": "mustache", "hat": "top", "hat_color": "2a2626",
		"top": "c8b890", "top_style": "coat", "top2": "a89870", "bottom": "c8b890", "bottom_style": "coat_long",
		"carry": ["suitcase"],
	},
	"visitor_motorist": {
		"skin": SKIN_TAN, "hair": "2a2018", "hat": "cap", "hat_color": "8a7a60",
		"top": "d8ccb0", "top_style": "coat", "top2": "b0a488", "bottom": "d8ccb0", "bottom_style": "coat_long",
		"carry": ["map"],
	},
	"visitor_ccc_worker": {
		"skin": SKIN_DEEP, "hair": "1a1410", "hat": "campaign", "hat_color": "7a6a48",
		"top": "8a7a50", "top_style": "shirt", "bottom": "6a5a3a", "belt": "3a2a1a", "carry": ["shovel"],
	},
	"visitor_camper": {
		"skin": SKIN_FAIR, "hair": "c8a060", "hat": "cap", "hat_color": "3a5a8a",
		"top": "3a6a4a", "top_style": "plaid", "top2": "1a3a2a", "bottom": "3a4a6a", "carry": ["lantern"],
	},
	"visitor_angler": {
		"skin": SKIN_TAN, "hair": "5a4a3a", "hat": "fedora", "hat_color": "7a7a5a",
		"top": "8a8a6a", "top_style": "vest", "top2": "5a6a4a", "bottom": "4a4a3a", "carry": ["rod"],
	},
	"visitor_backpacker": {
		"skin": SKIN_BROWN, "hair": "2a1a14", "hat": "beanie", "hat_color": "c86a2a",
		"top": "4a6a8a", "top_style": "shirt", "bottom": "8a6a4a", "pack": "frame_pack", "pack_color": "c8a030",
		"carry": ["stick"],
	},
	"visitor_dirtbag": {
		"skin": SKIN_FAIR, "hair": "a8783a", "hair_style": "long", "hat": "headband", "hat_color": "c83a3a",
		"top": "e0d8c0", "top_style": "stripes", "top2": "4a6a9a", "bottom": "e8e0c8", "carry": ["rope", "chalk_bag"],
	},
	# Crow, who camps up Tenaya Creek where nobody goes: a black tank top over
	# arms inked to the wrist, a beanie, and a beard.
	"crow": {
		"skin": SKIN_TAN, "hair": "2a2018", "beard": "goatee", "beard_color": "2a2018",
		"hat": "beanie", "hat_color": "6a7a3a", "top": "26262a", "top_style": "shirt", "sleeve": SKIN_TAN,
		"collar": "26262a", "bottom": "4a5a6e", "shoes": "4a3a2a", "tattoos": "2a3550",
	},
	"visitor_rail_passenger": {
		"skin": SKIN_TAN, "hair": "3a2a20", "hat": "bowler", "hat_color": "3a3a3a",
		"top": "4a4a58", "top_style": "jacket", "top2": "e0e0d8", "bottom": "4a4a58", "carry": ["suitcase"],
	},
	# ------------------------------------------------ Curry Village shopkeepers (unnamed)
	"curry_store_clerk": {
		"skin": SKIN_LIGHT, "hair": "5a3a24", "hair_style": "short",
		"top": "efe8d8", "top_style": "shirt", "top2": "3c6a44", "sleeve": "3c6a44", "collar": "3c6a44",
		"bottom": "4a4038", "apron": "3f7a4a", "shoes": "3a2a20",
	},
	"curry_shop_clerk": {
		"skin": SKIN_TAN, "hair": "2a1a14", "hat": "beanie", "hat_color": "c8402e",
		"top": "3a6a8a", "top_style": "jacket", "top2": "27485e", "bottom": "8a6a48", "bottom_style": "pants",
		"beard": "short", "beard_color": "2a1a14", "carry": ["rope"],
	},
	# ------------------------------------------------ Gear traders and the Village Store (unnamed)
	"camp4_rack_trader": {
		"skin": SKIN_TAN, "hair": "6a4a2a", "hair_style": "long", "hat": "headband", "hat_color": "e8a030",
		"top": "e8dcc0", "top_style": "stripes", "top2": "c8402e", "bottom": "5a6a8a", "bottom_style": "pants",
		"carry": ["rope", "chalk_bag"],
	},
	"camp4_bigwall_trader": {
		"skin": SKIN_FAIR, "hair": "3a2a1a", "beard": "short", "hat": "beanie", "hat_color": "3a5a8a",
		"top": "6a7a4a", "top_style": "plaid", "top2": "3a4a2a", "bottom": "6a5a48", "pack": "haul_bag",
		"pack_color": "c86a2a", "carry": ["hammer"],
	},
	"village_store_clerk": {
		"skin": SKIN_BROWN, "hair": "2a1a14", "hair_style": "bun",
		"top": "e8e4d8", "top_style": "shirt", "top2": "8a3a2a", "sleeve": "8a3a2a", "collar": "8a3a2a",
		"bottom": "4a4038", "apron": "8a3a2a", "shoes": "3a2a20",
	},
	# ------------------------------------------------ Mountain Shop staff (invented, not historical)
	"wren_alvarez": {
		"skin": SKIN_TAN, "hair": "3a2418", "hair_style": "braid", "hat": "headband", "hat_color": "e8b040",
		"top": "4a8a8a", "top_style": "shirt", "top2": "2f6464", "bottom": "7a6a52", "bottom_style": "knickers",
		"socks": "c8402e", "shoes": "c8502e", "pack": "pack", "pack_color": "8a5a3a", "carry": ["rope"],
	},
	# ------------------------------------------------ Curry Village's fishing guide (invented, not historical)
	"greg": {
		"skin": SKIN_FAIR, "hair": "8a5a2a", "hat": "cap", "hat_color": "c8a030",
		"beard": "short", "beard_color": "8a5a2a",
		"top": "c8b88a", "top_style": "vest", "top2": "4a6a8a", "bottom": "5a6a4a", "shoes": "4a5a3a",
		"carry": ["rod"],
	},
	# ------------------------------------------------ The Camp 4 rescue site (invented, not historical)
	# The team wears the yellow search and rescue shirt, as Yosemite's
	# rescuers do, so you can pick them out across a meadow.
	"jo_tolliver": {
		"skin": SKIN_BROWN, "hair": "2a1a14", "hair_style": "short", "hat": "helmet", "hat_color": "d84a2a",
		"top": "e8b820", "top_style": "shirt", "top2": "b88a10", "bottom": "4a5a6a", "bottom_style": "pants",
		"shoes": "3a2a20", "pack": "pack", "pack_color": "3a5a8a", "carry": ["rope"],
	},
	"mateo_reyes": {
		"skin": SKIN_TAN, "hair": "1a1410", "hair_style": "short", "beard": "short", "beard_color": "1a1410",
		"hat": "cap", "hat_color": "3a4a3a",
		"top": "e8b820", "top_style": "shirt", "top2": "b88a10", "bottom": "5a6a4a", "belt": "3a2a1a",
		"shoes": "4a3020", "carry": ["notebook"],
	},
	"visitor_sar_volunteer": {
		"skin": SKIN_FAIR, "hair": "8a5a2a", "hair_style": "bun", "hat": "helmet", "hat_color": "e8e0d0",
		"top": "e8b820", "top_style": "shirt", "top2": "b88a10", "bottom": "4a4a52",
		"shoes": "3a2a20", "pack": "pack", "pack_color": "c8402e", "carry": ["rope"],
	},
	"visitor_sar_hauler": {
		"skin": SKIN_DEEP, "hair": "1a1410", "hat": "beanie", "hat_color": "2a3a4a",
		"top": "e8b820", "top_style": "shirt", "top2": "b88a10", "bottom": "6a5a42",
		"shoes": "4a3020", "pack": "frame_pack", "pack_color": "3a5a8a", "carry": ["map"],
	},
	# ------------------------------------------------ Ahwahnee staff (invented, not historical)
	"ahwahnee_chef": {
		"skin": SKIN_FAIR, "hair": "4a3a2e", "beard": "mustache", "beard_color": "4a3a2e",
		"hat": "toque", "hat_color": "f5eee0",
		"top": "f0ece0", "top_style": "jacket", "top2": "d8d2c0", "collar": "b3362b",
		"bottom": "3a3a42", "apron": "e8e4d8", "shoes": "2a1f1a",
	},
	# ------------------------------------------------ Curry Village visitors
	"visitor_pavilion_cook": {
		"skin": SKIN_FAIR, "hair": "5a4030", "hat": "cap", "hat_color": "f0ece0",
		"top": "f0ece0", "top_style": "shirt", "top2": "d8d2c0", "bottom": "4a4a52", "apron": "e8e4d8", "carry": ["loaf"],
	},
	"visitor_ranger": {
		"skin": SKIN_TAN, "hair": "3a2a1a", "hat": "campaign", "hat_color": "7a6a48",
		"top": "6a7a4a", "top_style": "shirt", "top2": "4a5a34", "bottom": "8a7a5a", "belt": "3a2a1a", "badge": "e0c060",
		"carry": ["notebook"],
	},
	"visitor_tourist": {
		"skin": SKIN_LIGHT, "hair": "8a5a2a", "hat": "fedora", "hat_color": "c8b88a",
		"top": "e8dcc0", "top_style": "vest", "top2": "6a8aa0", "bottom": "6a5a4a", "bottom_style": "knickers", "socks": "8a7a6a",
		"carry": ["camera"],
	},
	"visitor_shop_climber": {
		"skin": SKIN_BROWN, "hair": "1a1410", "hat": "beanie", "hat_color": "3a9a5a",
		"top": "c8402e", "top_style": "jacket", "top2": "8a2a1a", "bottom": "5a5a6a", "shoes": "d8d0c0",
		"carry": ["chalk_bag"],
	},
	"visitor_store_shopper": {
		"skin": SKIN_FAIR, "hair": "7a3a1a", "hair_style": "bun",
		"top": "6a8aa0", "top_style": "blouse", "top2": "e8e4d8", "bottom_style": "skirt", "bottom": "5a4a3a", "carry": ["basket"],
	},
	"visitor_painter": {
		"skin": SKIN_LIGHT, "hair": "8a3a1a", "hair_style": "bun", "hat": "wide", "hat_color": "e0d0a0",
		"top": "e8e0d0", "top_style": "blouse", "top2": "6a8aa0", "bottom": "5a6a8a", "bottom_style": "skirt",
		"carry": ["notebook"],
	},
	# ------------------------------------------------ Townsfolk who keep a timetable (invented)
	# Curry Village's lifeguard and housekeeper, and Yosemite Village's
	# postmaster, baker and photographer: everyday people with somewhere to be.
	"visitor_lifeguard": {
		"skin": SKIN_BROWN, "hair": "2a1a14", "hair_style": "short", "hat": "cap", "hat_color": "c8402e",
		"top": "f0ece0", "top_style": "shirt", "top2": "c8402e", "collar": "c8402e", "bottom": "c8402e",
		"shoes": "d8d0c0",
	},
	"visitor_housekeeper": {
		"skin": SKIN_DEEP, "hair": "1a1410", "hair_style": "bun",
		"top": "8aa0b8", "top_style": "blouse", "top2": "e8e4d8", "apron": "f0ece0", "bottom_style": "skirt",
		"bottom": "4a4a58", "carry": ["basket"],
	},
	"visitor_postmaster": {
		"skin": SKIN_FAIR, "hair": "5a4030", "beard": "mustache", "beard_color": "5a4030", "hat": "cap",
		"hat_color": "3e4c62", "top": "3e4c62", "top_style": "jacket", "top2": "2c374a", "bottom": "3e4c62",
		"badge": "e0c060", "carry": ["book"],
	},
	"visitor_baker": {
		"skin": SKIN_TAN, "hair": "2a2018", "beard": "mustache", "beard_color": "2a2018", "hat": "painter_cap",
		"hat_color": "f0ece0", "top": "f0ece0", "top_style": "shirt", "top2": "d8d2c0", "apron": "e8e4d8",
		"bottom": "6a5a4a", "carry": ["loaf"],
	},
	"visitor_photographer": {
		"skin": SKIN_BROWN, "hair": "2a1a14", "hair_style": "long", "glasses": true,
		"top": "b0603a", "top_style": "sweater", "top2": "8a4a2a", "bottom": "4a5a6e", "bottom_style": "pants",
		"shoes": "4a3a2a", "carry": ["camera"],
	},
}

## Icons in assets/sprites/story_items.png, left to right.
const ITEMS := [
	"lamon_apple",
	"degnan_loaf",
	"pine_nuts",
	"model_a_axle",
	"anderson_eyebolt",
	"sourdough_starter",
	"rental_shoes",
]
