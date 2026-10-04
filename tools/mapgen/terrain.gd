extends RefCounted
## Terrain and flora types shared by the map generator scripts.
## Each terrain type is one row of assets/sprites/terrain.png (4 variants per
## row); each flora type is one 32x48 frame of assets/sprites/flora.png.

enum {
	FOREST, # mixed-conifer forest floor (Valley, Wawona)
	MEADOW,
	WET_MEADOW,
	FOOTHILL, # golden grass and oak woodland (El Portal)
	FIR, # red fir / Jeffrey pine forest floor (Glacier Point)
	SUBALPINE, # lodgepole forest on granite sand (Tuolumne)
	SCRUB, # chaparral and manzanita
	GRANITE, # walkable granite slab
	CLIFF,
	TALUS,
	SCREE,
	RIVER,
	LAKE,
	CREEK, # shallow and walkable
	FALLS,
	SAND,
	ROAD,
	PARKING,
	BRIDGE,
	TRAIL,
	PAVED, # paved foot and bike paths
	CAMP, # campground dirt
	SNOW,
	ALPINE,
	LAWN, # mowed grass (Wawona golf course)
	BUILT, # ground around buildings
	COUNT,
}

const NAMES := ["forest", "meadow", "wet_meadow", "foothill", "fir", "subalpine", "scrub",
	"granite", "cliff", "talus", "scree", "river", "lake", "creek", "falls", "sand", "road",
	"parking", "bridge", "trail", "paved", "camp", "snow", "alpine", "lawn", "built"]

## Types the player can't walk on.
const SOLID := [CLIFF, TALUS, SCREE, RIVER, LAKE, FALLS]
## Natural ground that gets hillshade tinting (roads and water stay flat).
const SHADED := [FOREST, MEADOW, WET_MEADOW, FOOTHILL, FIR, SUBALPINE, SCRUB, GRANITE,
	CLIFF, TALUS, SCREE, SNOW, ALPINE, CAMP, SAND]
## Hillshade alternatives: 0 normal, 1 sunlit, 2 shaded, 3 deep shade.
const SHADE_MODULATE := [Color(1, 1, 1), Color(1.1, 1.08, 1.04), Color(0.84, 0.85, 0.9), Color(0.68, 0.7, 0.78)]

enum Flora {
	PONDEROSA, INCENSE_CEDAR, BLACK_OAK_TRUNK, WHITE_FIR, DOGWOOD, SNAG, RED_FIR, JEFFREY_PINE,
	LODGEPOLE, WHITEBARK, HEMLOCK, GRAY_PINE, LIVE_OAK, MANZANITA, SHRUB, SEQUOIA,
	SUGAR_PINE, BOULDER, ERRATIC, TENT_CABIN, CABIN, HOUSE, LODGE, WHITE_HOUSE,
	CAMP_TENT, WILLOW, BLACK_OAK_CANOPY, COUNT,
}
const FLORA_COLUMNS := 8
const FLORA_FRAME := Vector2i(32, 48)

## Collision rectangle (relative to the cell center) for each flora type;
## empty means no collision. Cells are 16x16, centered on (0, 0).
const FLORA_COLLISION := {
	Flora.PONDEROSA: Rect2(-2, 2, 4, 5),
	Flora.INCENSE_CEDAR: Rect2(-2, 2, 4, 5),
	Flora.BLACK_OAK_TRUNK: Rect2(-3, 2, 6, 5),
	Flora.WHITE_FIR: Rect2(-2, 2, 4, 5),
	Flora.DOGWOOD: Rect2(-2, 3, 4, 4),
	Flora.SNAG: Rect2(-2, 2, 4, 5),
	Flora.RED_FIR: Rect2(-2, 2, 4, 5),
	Flora.JEFFREY_PINE: Rect2(-2, 2, 4, 5),
	Flora.LODGEPOLE: Rect2(-2, 3, 4, 4),
	Flora.WHITEBARK: Rect2(-3, 2, 6, 5),
	Flora.HEMLOCK: Rect2(-2, 2, 4, 5),
	Flora.GRAY_PINE: Rect2(-2, 2, 4, 5),
	Flora.LIVE_OAK: Rect2(-3, 2, 6, 5),
	Flora.MANZANITA: Rect2(-5, 1, 10, 6),
	Flora.SHRUB: Rect2(-5, 1, 10, 6),
	Flora.SEQUOIA: Rect2(-5, 0, 10, 7),
	Flora.SUGAR_PINE: Rect2(-3, 2, 6, 5),
	Flora.BOULDER: Rect2(-6, -1, 12, 8),
	Flora.ERRATIC: Rect2(-7, -3, 14, 10),
	Flora.TENT_CABIN: Rect2(-7, -4, 14, 11),
	Flora.CABIN: Rect2(-7, -4, 14, 11),
	Flora.HOUSE: Rect2(-8, -4, 16, 11),
	Flora.LODGE: Rect2(-8, -5, 16, 12),
	Flora.WHITE_HOUSE: Rect2(-8, -4, 16, 11),
	Flora.CAMP_TENT: Rect2(-5, 0, 10, 6),
	Flora.WILLOW: Rect2(-4, 2, 8, 5),
	Flora.BLACK_OAK_CANOPY: Rect2(),
}


static func frame_coords(flora: int) -> Vector2i:
	return Vector2i(flora % FLORA_COLUMNS, flora / FLORA_COLUMNS)


static func is_solid(type: int) -> bool:
	return type in SOLID
