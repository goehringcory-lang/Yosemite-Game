extends "res://tools/hubs/build_outer_hub.gd"
## Builds Bridalveil Creek, a stop on Glacier Point Road in the red fir and
## lodgepole forest at about 7,000 feet, between Chinquapin and Glacier Point.
##
## Run tools/hubs/rebuild_rim_country.sh (which runs this builder,
## migrates onto the 32px grid, paints native 32px ground, dresses wild
## clutter, builds normal maps and water cells, and re-imports).
##
## Layout (Glacier Point Road runs north to south-west through the map):
## - Glacier Point Road enters on the north edge (walk on to Glacier Point) and
##   leaves on the south edge as the long drive back to the Valley, past
##   Badger Pass and Chinquapin.
## - West of the road, McGurk Meadow, a wet subalpine meadow, with the old
##   McGurk cabin at its edge, reached by a short trail from the road.
## - East of the road, Bridalveil Creek Campground in the firs, and the creek
##   itself, running north-west across the road under a bridge.
## - On the east side, the Mono Meadow trailhead, with the trail down to
##   Illilouette Creek.

const GEO := Vector2(-119.6230, 37.6630)
const W := 72
const H := 56
const TM := "res://assets/sprites/tuolumne/"
const ROAD_LINE := [Vector2(37, 0), Vector2(37, 10), Vector2(34, 18), Vector2(28, 28), Vector2(24, 40), Vector2(20, H - 1)]
const CREEK := [Vector2(71, 36), Vector2(62, 31), Vector2(52, 27), Vector2(43, 24), Vector2(35, 20), Vector2(26, 14),
	Vector2(16, 9), Vector2(6, 5), Vector2(-1, 3)]
const CAMP_SITES := [[46, 11], [52, 10], [58, 12], [48, 16], [55, 16]]


func _ready() -> void:
	print("== Bridalveil Creek")
	load_flora()
	import_assets()
	_bridalveil_creek()
	print("Done")
	get_tree().quit()


func _bridalveil_layout() -> void:
	init_grid(W, H, Terrain.FIR)
	rng.seed = 1890
	noise.seed = 1890
	noise.frequency = 0.1
	# McGurk Meadow: a wet subalpine meadow west of the road.
	_ellipse(12.0, 40.0, 10.0, 7.0, Terrain.MEADOW, 0.25, [Terrain.FIR])
	_ellipse(12.0, 41.0, 6.0, 3.5, Terrain.WET_MEADOW, 0.3, [Terrain.MEADOW])
	# Mono Meadow, small and wet, at the east end of the trail.
	_ellipse(60.0, 47.0, 8.0, 4.0, Terrain.MEADOW, 0.25, [Terrain.FIR])
	_ellipse(60.0, 47.0, 4.0, 2.0, Terrain.WET_MEADOW, 0.3, [Terrain.MEADOW])
	# Bridalveil Creek, shallow and walkable, flowing north-west.
	_water(CREEK, 1, Terrain.CREEK, 0.25)
	var creek_before := kind.duplicate()
	# Glacier Point Road, three tiles wide, laid over the creek as a bridge deck.
	_path(ROAD_LINE, 3, Terrain.ROAD)
	for k in w * h:
		if creek_before[k] == Terrain.CREEK and kind[k] == Terrain.ROAD:
			kind[k] = Terrain.BRIDGE
	# Bridalveil Creek Campground: a dirt clearing in the firs east of the road.
	_ellipse(52.0, 13.0, 10.0, 7.0, Terrain.CAMP, 0.25, [Terrain.FIR])
	_path([Vector2(39, 9), Vector2(44, 11)], 2, Terrain.TRAIL, 0.2)
	# McGurk Meadow trail: a short trail west off the road to the cabin.
	_path([Vector2(26, 32), Vector2(21, 33), Vector2(17, 34), Vector2(16, 34)], 1, Terrain.TRAIL, 0.25)
	# Mono Meadow trailhead lot beside the road, and the trail east to the meadow.
	fill(27, 40, 31, 44, Terrain.PARKING)
	_path([Vector2(31, 42), Vector2(42, 42), Vector2(52, 42), Vector2(62, 41), Vector2(65, 41)], 1, Terrain.TRAIL, 0.3)
	_mark_open()
	clear_trees(5, 28, 24, 48) # McGurk Meadow and its cabin
	clear_trees(40, 5, 64, 20) # the campground
	clear_trees(26, 38, 32, 46) # trailhead lot
	clear_trees(50, 42, 70, 52) # Mono Meadow


func _bridalveil_creek() -> void:
	_bridalveil_layout()
	start_region("BridalveilCreek", "bridalveil_creek", "Bridalveil Creek", GEO)
	_root.hub_id = "glacier_point"
	paint_ground()
	_save_ground_art("ground_bridalveil_creek", 1890)
	_place_features_bridalveil()
	_place_exits_bridalveil()
	_place_markers_bridalveil()
	_dress_bridalveil()
	_finish("bridalveil_creek", 2.0)


func _place_features_bridalveil() -> void:
	# The old McGurk cabin at the north edge of its meadow, a ruin kept by the park.
	building("McGurkCabin", TM + "mccauley_cabin.png", 16, 32, "McGurk Meadow Cabin",
		"John McGurk's log cabin, built in the 1890s at the edge of this meadow. He ran stock here in the summers, as sheepmen and cattlemen did across the high Sierra before and after the park was set aside. The roof is long gone, but the logs still stand.")
	_info_sign("McGurkMeadowSign", foot(19, 35), "McGurk Meadow",
		"A wet subalpine meadow at about 7,000 feet. Before the park took over its care, sheep and cattle grazed these meadows each summer. Now corn lilies, shooting stars and Pacific tree frogs have it back, and mule deer graze at dusk.")
	_info_sign("BridalveilCreekSign", foot(41, 22), "Bridalveil Creek",
		"This small creek gathers snowmelt from the meadows and ridges here, then runs down to the lip of the Valley, where it leaps 620 feet as Bridalveil Fall.")
	_info_sign("BridalveilCampgroundSign", foot(42, 12), "Bridalveil Creek Campground",
		"A forest campground of red fir and lodgepole pine at 7,200 feet, open in summer. Store your food in the bear boxes, always.")
	_info_sign("MonoMeadowSign", foot(30, 45), "Mono Meadow Trailhead",
		"The trail runs east through the forest to Mono Meadow, then drops into the canyon of Illilouette Creek. Sierra Miwok and Mono Paiute travelers used routes like this one across the high country.")
	_info_sign("GlacierRoadSign", foot(41, 3), "Glacier Point Road",
		"The road climbs about sixteen miles from Chinquapin past Badger Pass to Glacier Point, and the snow closes it each winter.")
	# Campsites: a tent, a table and a bear box each, and cold fire rings.
	_campsites("BridalveilCamp", CAMP_SITES)
	for i in 3:
		var s: Array = CAMP_SITES[i]
		decor("BridalveilFireRing%d" % i, "res://assets/sprites/buildings/camp4_fire_ring_cold.png", foot(s[0] + 3, s[1] - 1), Vector2(10, 4))
	# Erratic granite boulders in the meadows and forest.
	for b: Array in [[8, 44], [17, 46], [44, 36], [57, 38], [66, 50], [34, 30]]:
		_prop(_pick("rock_granite"), foot(b[0], b[1]))


func _place_exits_bridalveil() -> void:
	# North on foot to Glacier Point.
	region_exit("GlacierPointRoadNorth", tile_pos(37, -0.5), Vector2(48, 12), "Glacier Point Road, north to Glacier Point",
		"glacier_point", "road_south")
	# South, the long drive back to the Valley, past Chinquapin and Badger Pass.
	region_exit("GlacierPointRoadSouth", tile_pos(21, H - 1), Vector2(48, 16), "Glacier Point Road", "", "").set("travel_to", "yosemite_valley")
	# East down to Illilouette Creek.
	_trail_door("MonoMeadowTrail", foot(66, 41), "Mono Meadow Trail, down to Illilouette Creek",
		"illilouette", "bridge", 60)


func _place_markers_bridalveil() -> void:
	marker("north", 37, 2)
	marker("south", 20, H - 3)
	marker("arrival", 38, 6)
	marker("mcgurk_meadow", 14, 36)
	marker("campground", 50, 14)
	marker("mono_meadow", 62, 42)
	place("McGurk Meadow", 12, 40, 10)
	place("Bridalveil Creek Campground", 52, 13, 10)
	place("Mono Meadow Trailhead", 58, 44, 9)


func _dress_bridalveil() -> void:
	_reserve_entities(1, 3)
	var all := Rect2i(0, 0, w, h)
	# Lodgepole and red fir forest (white fir and snags stand in for red fir).
	_fringe_trees([Terrain.FIR], 2, 0.6, [["tree_lodgepole", 4.0], ["tree_white_fir", 3.0], ["tree_snag", 0.35]], 1, 20.0)
	_fringe_trees([Terrain.MEADOW, Terrain.WET_MEADOW], 8, 0.25, [["tree_lodgepole", 3.0], ["tree_white_fir", 1.0]], 3, 50.0)
	_fringe_trees([Terrain.CAMP], 4, 0.4, [["tree_lodgepole", 3.0], ["tree_white_fir", 1.0]], 2, 30.0)
	_scatter_decor("plant_shrub", [Terrain.FIR], 18, all, 2)
	_scatter_decor("plant_manzanita", [Terrain.FIR], 10, all, 2)
	_scatter_decor("plant_wildflowers", [Terrain.MEADOW], 20, all, 1)
	_scatter_decor("plant_lupine", [Terrain.MEADOW, Terrain.FIR], 12, all, 1)
	_scatter_decor("plant_cornlily", [Terrain.WET_MEADOW], 12, all, 0)
	_scatter_decor("plant_tall_grass", [Terrain.MEADOW, Terrain.WET_MEADOW], 30, all, 0)
	_scatter_decor("plant_cattails", [Terrain.WET_MEADOW], 6, all, 0)
	_scatter_decor("rock_granite", [Terrain.FIR], 12, all, 2)
	_scatter_decor("log_fallen", [Terrain.FIR], 12, all, 2)
	_scatter_decor("log_stump", [Terrain.FIR], 6, all, 2)
	_scatter_decor("plant_mushrooms", [Terrain.FIR], 8, all, 2)
