extends "res://tools/hubs/build_outer_hub.gd"
## Builds El Portal by hand, laid out like the real one, in the Ahwahnee
## look. Run tools/hubs/rebuild_el_portal.sh, which runs this:
##
##   godot --headless --path . res://tools/hubs/build_el_portal.tscn
##
## and then moves the scene and the art onto the game's 32px grid. It
## rewrites scenes/regions/el_portal.tscn, the art in
## assets/sprites/el_portal/ (el_portal_art.gd), the foothill trees
## (foothill_flora_art.gd), the canyon wall and the painted ground. Put story
## NPCs and items in scenes/story/content/el_portal.tscn, not in the region
## scene, so a rebuild keeps them.
##
## The real layout, squeezed so it can be walked, west (left) to east, with
## the canyon's north wall at the top as in every Valley scene: Highway 140
## comes up the Merced River canyon past the Yosemite View Lodge on the river,
## then Rancheria Flat and the town: the El Portal Market and the post office
## on the north side of the road, the park's staff houses, and across the
## road the old railroad yard where the Yosemite Valley Railroad ended
## (1907-1945), with the site of the Hotel Del Portal. East of town the river
## runs over granite boulders past a gravel beach; then the road turns up the
## canyon past the Arch Rock entrance station and threads between the two
## boulders of Arch Rock. At 2,000 feet it's foothill country: gold grass
## with blue and interior live oaks, gray pines and buckeyes, redbud and
## chaparral (chamise, toyon, whiteleaf manzanita) on the slopes, and white
## alders and willows along the river.

const ElPortalArt = preload("res://tools/hubs/el_portal_art.gd")
const EP := "res://assets/sprites/el_portal/"
const GEO := Vector2(-119.7843, 37.6747)


func _ready() -> void:
	print("== El Portal art")
	ElPortalArt.new().save_all()
	load_flora()
	import_assets()
	print("== El Portal region")
	_el_portal()
	print("Done")
	get_tree().quit()


func _layout() -> void:
	init_grid(124, 54, Terrain.FOOTHILL)
	rng.seed = 1907
	noise.seed = 1907
	noise.frequency = 0.1
	# Chaparral on the steep slopes above the town and across the river.
	for x in w:
		fill(x, 0, x, 13 + int(noise.get_noise_1d(x * 2.0) * 3.0), Terrain.SCRUB)
		fill(x, 48 + int(noise.get_noise_1d(x * 2.0 + 60.0) * 2.0), x, h - 1, Terrain.SCRUB)
	# The shady, north-facing slope across the river holds a strip of forest
	# (live oak, ponderosa, incense cedar and madrone), and so does the
	# ravine beside Arch Rock.
	for x in w:
		fill(x, 46 + int(noise.get_noise_1d(x * 2.0 + 30.0) * 1.5), x, 50 + int(noise.get_noise_1d(x * 2.0 + 90.0) * 2.0), Terrain.FOREST)
	_ellipse(119, 13, 4.5, 4, Terrain.FOREST, 0.3, [Terrain.SCRUB, Terrain.FOOTHILL])
	# The canyon's north wall, deeper at the east end where Arch Rock sits in it.
	_wall(6.0, 2.0, 1)
	for x in range(100, w):
		var deep := 6
		fill(x, 0, x, deep, Terrain.CLIFF)
		put(x, deep + 1, Terrain.TALUS)
	# The Merced, flowing west, with gravel bars and the beach east of town.
	var river := [Vector2(125, 42), Vector2(110, 43), Vector2(96, 41), Vector2(84, 43), Vector2(70, 42), Vector2(52, 43),
		Vector2(34, 41), Vector2(18, 42), Vector2(-1, 41)]
	_path(river, 4, Terrain.RIVER, 0.8)
	for y in h:
		for x in w:
			if at(x, y) in [Terrain.FOOTHILL, Terrain.SCRUB] and _any_kind(x, y, [Terrain.RIVER], 1) and rng.randf() < 0.7:
				put(x, y, Terrain.SAND)
	_ellipse(91, 39.5, 8, 2.2, Terrain.SAND, 0.3, [Terrain.FOOTHILL])
	# Highway 140 along the north bank, then up the canyon to Arch Rock.
	_path([Vector2(-1, 26), Vector2(60, 26), Vector2(100, 26), Vector2(106, 24), Vector2(109.5, 20), Vector2(111, 14), Vector2(111, 7)], 2, Terrain.ROAD)
	fill(110, 7, 112, 8, Terrain.ROAD)
	# The market's lot and the post office's.
	fill(45, 23, 66, 25, Terrain.PARKING)
	# The lodge: a drive down from the road, and its lot along the river.
	_path([Vector2(5, 27), Vector2(5, 34)], 2, Terrain.ROAD)
	fill(3, 34, 30, 36, Terrain.PARKING)
	# The railroad yard: packed dirt across the road from the market.
	_ellipse(53, 33, 16, 4.5, Terrain.CAMP, 0.25, [Terrain.FOOTHILL])
	_path([Vector2(52, 28), Vector2(52, 30)], 1, Terrain.TRAIL)
	# Footpaths: down to the beach, and behind the houses.
	_path([Vector2(88, 28), Vector2(90, 34), Vector2(91, 38)], 1, Terrain.TRAIL, 0.5)
	_path([Vector2(28, 21), Vector2(44, 21)], 1, Terrain.TRAIL, 0.4)
	_path([Vector2(68, 22), Vector2(88, 22)], 1, Terrain.TRAIL, 0.4)
	_mark_open()
	clear_trees(26, 14, 92, 25) # the town
	clear_trees(49, 10, 56, 16) # the knoll behind the market (the house in the story overlay)
	clear_trees(36, 28, 70, 38) # the railroad yard
	clear_trees(2, 27, 32, 37) # the lodge
	clear_trees(100, 6, 116, 26) # the entrance and Arch Rock
	clear_trees(83, 36, 99, 41) # the beach


func _el_portal() -> void:
	_layout()
	start_hub("ElPortal", "el_portal", "El Portal", GEO)
	paint_ground()
	_save_ground_art("ground_el_portal", 1907)
	_place_wall("el_portal", 111)
	_place_town()
	_place_yard()
	_place_lodge()
	_place_river()
	_place_arch_rock()
	_place_markers()
	_dress_foothills()
	_mark_oaks()
	_finish("el_portal", 3.0)


func _place_town() -> void:
	_lit("Market", EP, "market", 52, 22, "El Portal Market",
		"Groceries, supplies, and gas. There is no gas station in Yosemite Valley, 15 miles up the road.")
	for x in [48.5, 55.5]:
		decor("GasPump%d" % int(x), EP + "gas_pump.png", foot(x, 23), Vector2(8, 4))
	_info_sign("Sign_El_Portal_Market", foot(57, 23), "El Portal Market",
		"Groceries, supplies, and gas. There is no gas station in Yosemite Valley, 15 miles up the road.")
	instance_scene("res://scenes/objects/travel_point.tscn", foot(46, 24), "Travel_El_Portal_Market").set("label", "El Portal Market")
	_lit("PostOffice", EP, "post_office", 63, 22, "El Portal Post Office",
		"Most of the people who live in El Portal work for the park, and their mail comes here. In the railroad days the mail came up the canyon on the train.")
	decor("Flagpole", EP + "flagpole.png", foot(59.5, 21) + Vector2(-4, 0), Vector2(4, 3))
	decor("Mailboxes", EP + "mailboxes.png", foot(67, 23), Vector2(26, 4))
	# Staff houses on Rancheria Flat and east of the post office.
	var houses := [[31.5, 21, "house_a"], [37.5, 21, "house_b"], [71.5, 21, "house_c"], [77.5, 21, "house_a"], [83.5, 21, "house_b"]]
	for i in houses.size():
		var hs: Array = houses[i]
		_lit("House%d" % i, EP, hs[2], hs[0], hs[1], "A staff house",
			"Rangers, trail crews and the people who keep the park running live in El Portal, below the Valley.")
	_info_sign("RancheriaFlatSign", foot(34.5, 23), "Rancheria Flat",
		"A rancheria was a Native village, and the flat is named for one that stood here on the river. Now park families live along it.")
	var CS_ := "res://assets/sprites/curry/"
	for c: Array in [[47, 24.6, 3], [50, 24.6, 7], [61, 24.6, 10]]:
		decor("Car%d" % c[0], CS_ + "car_%d.png" % c[2], foot(c[0], c[1]), Vector2(24, 12))


func _place_yard() -> void:
	# A long stretch of track across the yard, the caboose standing on it.
	for i in 5:
		_backdrop("track", Vector2((38 + i * 6) * T, 33 * T + 2), -8, EP).name = "Track%d" % i
	decor("Caboose", EP + "caboose.png", Vector2(44 * T, 34 * T + 1), Vector2(56, 8))
	_info("CabooseInfo", Vector2(44 * T, 34 * T + 1), Vector2(64, 24), "Railroad car",
		"A caboose like the ones at the tail of the Yosemite Valley Railroad's trains. The line was abandoned in 1945 and its rails were torn up for scrap.")
	decor("FreightPlatform", EP + "freight_platform.png", foot(56, 32), Vector2(60, 8))
	decor("ModelA", EP + "model_a.png", foot(40.5, 36), Vector2(30, 8))
	_info("ModelAInfo", foot(40.5, 36), Vector2(40, 18), "A rusted Model A",
		"An old Model A Ford, left to rust beside the tracks. Its fenders have gone to flakes, but the steel underneath is good steel.")
	_info_sign("Sign_Yosemite_Valley_Railroad", foot(50, 30), "Yosemite Valley Railroad",
		"From 1907 to 1945, trains ran 78 miles from Merced up the Merced River canyon to El Portal. Travelers rode the last miles into the Valley by stage, and later by bus.")
	_info_sign("DelPortalSign", foot(63, 30), "Hotel Del Portal",
		"The railroad built a hotel here in 1907 for travelers at the end of the line, where they slept before the stage ride up to the Valley. It burned in 1917.")


func _place_lodge() -> void:
	_lit("Lodge", EP, "lodge", 11, 33, "Yosemite View Lodge",
		"Rooms along the Merced, just below the park. Guests come down to the river to swim and fish in the summer.")
	_lit("LodgeB", EP, "lodge", 22, 33, "Yosemite View Lodge",
		"Every room has a balcony over the river.")
	var CS_ := "res://assets/sprites/curry/"
	for c: Array in [[8, 35.6, 2], [13, 35.6, 5], [19, 35.6, 8], [27, 35.6, 11]]:
		decor("LodgeCar%d" % c[0], CS_ + "car_%d.png" % c[2], foot(c[0], c[1]), Vector2(24, 12))


func _place_river() -> void:
	var boulders := [[86, 42, "a"], [89.5, 43.5, "b"], [93, 41.5, "c"], [97, 43, "a"], [74, 43, "b"], [60, 42.5, "c"],
		[26, 41.5, "b"], [116, 43, "a"], [104, 42.5, "c"]]
	for i in boulders.size():
		var b: Array = boulders[i]
		decor("RiverBoulder%d" % i, EP + "river_boulder_%s.png" % b[2], foot(b[0], b[1]), Vector2(30, 8) if b[2] != "c" else Vector2(20, 6))
	_info_sign("Sign_Merced_River_Canyon", foot(90, 37), "Merced River Canyon",
		"Between Yosemite Valley and El Portal, the Merced River drops about 2,000 feet through the narrow Merced Gorge.")
	_info_sign("BeachSign", foot(94, 38), "The river beach",
		"By late summer the Merced runs low and warm over these boulders, and people come to swim. In spring it's snowmelt, fast and cold: stay out of it.")
	_info_sign("FoothillSign", foot(40, 24), "Foothill woodland",
		"El Portal is 2,000 feet below the Valley and much hotter and drier. Blue oaks, live oaks, gray pines and buckeyes grow here, and redbud blooms magenta in March, weeks before spring reaches the Valley.")


func _place_arch_rock() -> void:
	# The two boulders over the road, solid either side of the gap.
	var gap := ElPortalArt.ARCH_GAP / 2.0
	_solid("ArchRock", EP + "arch_rock.png", Vector2(112 * T, 8 * T), [Rect2(-84, -28, 84 - gap, 28), Rect2(gap, -28, 84 - gap, 28)])
	_info_sign("Sign_Arch_Rock", foot(108.5, 9), "Arch Rock",
		"The road squeezes between two huge fallen boulders here. This entrance opened in 1926 with the All-Year Highway, today's Highway 140.")
	_lit("EntranceStation", EP, "entrance_station", 107.5, 18, "Arch Rock Entrance Station",
		"Rangers take the entrance fee here and hand out the park map. Yosemite Valley is about 10 miles up the road.")
	decor("ParkSign", EP + "park_sign.png", foot(104.5, 23), Vector2(104, 6))
	region_exit("ElPortalRoad", Vector2(112 * T, 7.5 * T), Vector2(30, 14), "El Portal Road", "", "").set("travel_to", "yosemite_valley")
	_road_out("Highway140West", tile_pos(-0.5, 26.5), Vector2(12, 40), "Central Yosemite Highway",
		"Highway 140 continues west to Mariposa and Merced, outside the park.")


func _place_markers() -> void:
	marker("arrival", 52, 24.5)
	marker("railroad", 51, 31)
	marker("arch_rock", 106, 13)
	marker("yosemite_view_lodge", 16, 37)
	marker("beach", 91, 38)
	marker("rancheria_flat", 34, 24)
	place("El Portal", 56, 25, 20)
	place("El Portal Market", 52, 23, 5)
	place("Yosemite Valley Railroad", 50, 33, 7)
	place("Yosemite View Lodge", 16, 33, 10)
	place("Rancheria Flat", 34, 21, 7)
	place("Arch Rock Entrance", 109, 14, 9)
	var river := Marker2D.new()
	river.set_script(load("res://scripts/world/place.gd"))
	river.name = "MercedRiver"
	river.position = tile_pos(78, 42)
	river.set("display_name", "Merced River")
	river.set("radius", 0.0)
	river.set("show_banner", false)
	river.set("show_on_map", true)
	_places.add_child(river)


## The foothill woodland: oaks, gray pines and buckeyes on the gold grass,
## chaparral with redbud on the slopes, alders and willows on the river.
func _dress_foothills() -> void:
	_reserve_entities(1, 3)
	var all := Rect2i(0, 0, w, h)
	# a few oaks kept close to the market and the yard, where the press book
	# sends you for the blue oak and the soap plant
	for p: Array in [[43, 18, "tree_blue_oak_a"], [48, 17, "tree_live_oak_a"], [58, 16, "tree_blue_oak_b"], [68, 18, "tree_live_oak_b"],
			[36, 30, "tree_live_oak_b"], [70, 34, "tree_blue_oak_a"], [46, 38, "tree_buckeye"]]:
		_prop(p[2], foot(p[0], p[1]))
	_fringe_trees([Terrain.FOOTHILL], 4, 0.75, [["tree_blue_oak", 3.0], ["tree_live_oak", 3.5], ["tree_gray_pine", 1.6], ["tree_buckeye", 1.4]], 1, 30.0)
	_fringe_trees([Terrain.SCRUB], 4, 0.7, [["tree_gray_pine", 2.0], ["tree_live_oak", 3.0], ["tree_redbud", 0.6]], 1, 28.0)
	_fringe_trees([Terrain.FOREST], 3, 0.7, [["tree_live_oak", 3.0], ["tree_ponderosa", 1.5], ["tree_incense_cedar", 1.2], ["tree_black_oak", 1.0]], 1, 24.0)
	_fringe_trees([Terrain.SAND], 5, 0.55, [["tree_alder", 2.0], ["tree_willow", 1.0]], 0, 40.0)
	_fringe_trees([Terrain.TALUS], 5, 0.35, [["tree_gray_pine", 1.0], ["tree_live_oak", 1.0]], 0, 30.0)
	_scatter_decor("plant_chamise", [Terrain.SCRUB], 190, all, 0)
	_scatter_decor("plant_toyon", [Terrain.SCRUB, Terrain.FOOTHILL], 50, all, 1)
	_scatter_decor("plant_manzanita", [Terrain.SCRUB], 60, all, 0)
	_scatter_decor("tree_redbud", [Terrain.SCRUB, Terrain.FOOTHILL], 8, all, 2)
	_scatter_decor("plant_tall_grass", [Terrain.FOOTHILL], 110, all, 1)
	_scatter_decor("plant_wildflowers", [Terrain.FOOTHILL], 24, all, 1)
	_scatter_decor("plant_shrub", [Terrain.FOOTHILL, Terrain.SAND, Terrain.FOREST], 24, all, 1)
	_scatter_decor("plant_fern", [Terrain.FOREST], 16, all, 1)
	_scatter_decor("rock_granite", [Terrain.SCRUB, Terrain.FOOTHILL], 18, all, 1)
	_scatter_decor("rock_river", [Terrain.SAND], 24, all, 0)
	_scatter_decor("plant_cattails", [Terrain.SAND], 8, all, 0)
	_scatter_decor("log_fallen", [Terrain.FOOTHILL, Terrain.SAND], 4, all, 2)
