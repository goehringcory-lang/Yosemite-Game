extends "res://tools/hubs/build_outer_hub.gd"
## Builds Wawona by hand, laid out like the real one, in the Ahwahnee look.
## Run tools/hubs/rebuild_wawona.sh, which runs this:
##
##   godot --headless --path . res://tools/hubs/build_wawona.tscn
##
## and then moves the scene and the art onto the game's 32px grid. It
## rewrites scenes/regions/wawona.tscn, the art in assets/sprites/wawona/
## (wawona_art.gd), the Big Trees (foothill_flora_art.gd) and the painted
## ground. Put story NPCs and items in scenes/story/content/wawona.tscn, not
## in the region scene, so a rebuild keeps them.
##
## The real layout, squeezed so it can be walked, north at the top: the
## Wawona Road (Highway 41) comes down from the Valley and crosses the South
## Fork of the Merced. By the river are the Wawona Store and, over the
## Wawona Covered Bridge, the Yosemite History Center's cabins, office, jail
## and blacksmith's shop, with a stagecoach. Across the river the white
## Wawona Hotel (1879) stands on the site of Galen Clark's station, with its
## lawn and fountain, its cottages and Thomas Hill's studio, looking across
## the road at Wawona Meadow and the golf course (1918). Down the road
## south is the Mariposa Grove: the welcome plaza and its shuttle, then the
## trail up through the giant sequoias past the Fallen Monarch, the Bachelor
## and Three Graces, the Grizzly Giant and the California Tunnel Tree to the
## grove museum. The forest is ponderosa and sugar pine, incense cedar,
## white fir and black oak, with dogwood in the grove.

const WawonaArt = preload("res://tools/hubs/wawona_art.gd")
const WW := "res://assets/sprites/wawona/"
const GEO := Vector2(-119.6555, 37.5366)
## The covered bridge's deck: tile rows and the columns it spans.
const DECK_Y := 15
const DECK_X := Vector2i(59, 66)
## The grove, where the giant sequoias grow.
const GROVE := Rect2i(70, 60, 58, 40)


func _ready() -> void:
	print("== Wawona art")
	WawonaArt.new().save_all()
	load_flora()
	import_assets()
	print("== Wawona region")
	_wawona()
	print("Done")
	get_tree().quit()


func _layout() -> void:
	init_grid(128, 100, Terrain.FOREST)
	rng.seed = 1856
	noise.seed = 1856
	noise.frequency = 0.1
	# Wawona Meadow, with the golf course's fairways and greens in it.
	_ellipse(82, 46, 36, 13, Terrain.MEADOW, 0.25)
	_ellipse(100, 52, 8, 3, Terrain.WET_MEADOW, 0.3, [Terrain.MEADOW])
	_ellipse(70, 50, 6, 2.5, Terrain.WET_MEADOW, 0.3, [Terrain.MEADOW])
	for f: Array in [[60, 41, 7, 2.2], [78, 46, 8, 2.4], [96, 42, 7, 2.2], [88, 53, 6, 2.0]]:
		_ellipse(f[0], f[1], f[2], f[3], Terrain.LAWN, 0.15, [Terrain.MEADOW, Terrain.WET_MEADOW])
	# Sunny, rocky slopes of manzanita and deer brush: north of the History
	# Center, and on the ridge west of the grove road.
	_ellipse(108, 20, 11, 6, Terrain.SCRUB, 0.35)
	_ellipse(14, 76, 8, 10, Terrain.SCRUB, 0.35)
	# The South Fork: down from the northeast, then west under the highway.
	_water([Vector2(63, -1), Vector2(63, 8), Vector2(62, 16), Vector2(62, 21), Vector2(57, 25), Vector2(46, 25), Vector2(38, 25),
		Vector2(26, 24), Vector2(12, 26), Vector2(-1, 25)], 3, Terrain.RIVER, 0.6)
	# The hotel's lawn, in front of it and round the cottages.
	fill(4, 33, 36, 58, Terrain.LAWN)
	# The Wawona Road, over the river on its bridge.
	_path([Vector2(40, -1), Vector2(40, 25), Vector2(40, 62), Vector2(41, 99)], 2, Terrain.ROAD)
	for y in range(20, 30):
		for x in [40, 41]:
			if at(x, y) in [Terrain.RIVER, Terrain.SAND]:
				put(x, y, Terrain.BRIDGE)
	# The store's lot, and the walk to the covered bridge and over it.
	fill(43, 17, 57, 20, Terrain.PARKING)
	_path([Vector2(56, 17), Vector2(58, DECK_Y)], 2, Terrain.TRAIL)
	for x in range(DECK_X.x, DECK_X.y + 1):
		for y in [DECK_Y, DECK_Y + 1]:
			put(x, y, Terrain.BRIDGE if at(x, y) in [Terrain.RIVER, Terrain.SAND] else Terrain.TRAIL)
	# The History Center: a dirt yard among the cabins.
	_ellipse(76, 13, 10, 6, Terrain.CAMP, 0.2, [Terrain.FOREST, Terrain.SAND])
	_path([Vector2(66, DECK_Y), Vector2(70, 14)], 2, Terrain.TRAIL)
	# The hotel's drive and walks.
	_path([Vector2(22, 37), Vector2(22, 40), Vector2(39, 40)], 2, Terrain.PAVED)
	_path([Vector2(14, 44), Vector2(30, 44)], 1, Terrain.PAVED)
	# The meadow loop, round the south side of the meadow.
	_path([Vector2(42, 36), Vector2(56, 58), Vector2(80, 61), Vector2(104, 59), Vector2(118, 48)], 1, Terrain.TRAIL, 0.5)
	# Down to the grove: the plaza's lot and the trail up through the trees.
	_path([Vector2(41, 62), Vector2(50, 66), Vector2(58, 68)], 2, Terrain.ROAD)
	fill(56, 66, 74, 71, Terrain.PARKING)
	_path([Vector2(74, 69), Vector2(80, 72), Vector2(88, 72), Vector2(92, 82), Vector2(99, 89), Vector2(108, 87),
		Vector2(108, 80), Vector2(114, 74), Vector2(118, 68)], 1, Terrain.TRAIL, 0.3)
	_mark_open()
	for k in w * h:
		if kind[k] == Terrain.LAWN:
			no_trees[k] = 1
	clear_trees(42, 6, 88, 22) # the store and the History Center
	clear_trees(2, 28, 38, 64) # the hotel
	clear_trees(54, 61, 76, 72) # the plaza
	clear_trees(74, 76, 90, 84) # in front of the Fallen Monarch
	clear_trees(94, 86, 114, 97) # in front of the Grizzly Giant and the Tunnel Tree


func _wawona() -> void:
	_layout()
	start_hub("Wawona", "wawona", "Wawona", GEO)
	paint_ground()
	_save_ground_art("ground_wawona", 1856)
	_place_store_and_bridge()
	_place_history_center()
	_place_hotel()
	_place_meadow()
	_place_grove()
	_place_roads()
	_place_markers()
	_dress_wawona()
	_mark_oaks()
	_finish("wawona", 3.0)


func _place_store_and_bridge() -> void:
	_lit("Store", WW, "store", 50, 17, "Wawona Store",
		"Groceries, ice cream and camping supplies, and the gas station across the road. The Pioneer Gift Shop is next door.")
	instance_scene("res://scenes/objects/travel_point.tscn", foot(44.5, 18), "Travel_Wawona_Store").set("label", "Wawona Store")
	var CS_ := "res://assets/sprites/curry/"
	for c: Array in [[45.5, 19.6, 4], [47.5, 19.6, 9], [55.5, 19.6, 1]]:
		decor("Car%d" % c[0], CS_ + "car_%d.png" % c[2], foot(c[0], c[1]), Vector2(24, 12))
	# The covered bridge: its far wall and roof behind the deck, its rail in front.
	var cx := (DECK_X.x + DECK_X.y + 1) / 2.0 * T
	decor("CoveredBridge", WW + "bridge_back.png", Vector2(cx, DECK_Y * T))
	decor("CoveredBridgeRail", WW + "bridge_front.png", Vector2(cx, (DECK_Y + 2) * T + 2))
	_info_sign("Sign_Wawona_Covered_Bridge", foot(57, DECK_Y + 2), "Wawona Covered Bridge",
		"Galen Clark built a bridge across the South Fork here in 1857. The Washburn brothers, who ran the hotel, covered it in 1875.")


func _place_history_center() -> void:
	var buildings := [
		["HomesteadCabin", "homestead_cabin", 69.5, 9, "Hodgdon Homestead Cabin",
			"A settler's log cabin from the high meadows to the north, moved here with the other buildings."],
		["WellsFargo", "wells_fargo", 75.5, 9, "Wells Fargo Office",
			"Stage passengers bought tickets and sent letters and gold here. The stages ran from Wawona to the Valley until cars took over the road."],
		["ArtistStudio", "artist_studio", 81.5, 9, "Artist's Studio",
			"Painters came to Yosemite from the 1850s on, and their pictures brought the visitors."],
		["Blacksmith", "blacksmith", 79.5, 19, "Blacksmith's Shop",
			"The smith shod the stage horses and mended the coaches' iron."],
		["Jail", "jail", 85, 15, "Jail",
			"A one-room lockup for the park's troublemakers in the days when the Army ran Yosemite."],
	]
	for b: Array in buildings:
		_lit(b[0], WW, b[1], b[2], b[3], b[4], b[5])
	decor("Stagecoach", WW + "stagecoach.png", foot(73, 14), Vector2(48, 8))
	_info("StagecoachInfo", foot(73, 14), Vector2(56, 24), "Stagecoach",
		"A Concord coach like the ones that carried travelers and the mail up the Wawona Road to the Valley, a long, dusty day.")
	decor("HitchingRail", WW + "hitching_rail.png", foot(77.5, 14), Vector2(30, 4))
	_info_sign("Sign_Yosemite_History_Center", foot(69, 16), "Yosemite History Center",
		"These cabins and buildings were moved here from around the park to tell the story of its early years.")


func _place_hotel() -> void:
	_lit("WawonaHotel", WW, "hotel", 22, 36, "Wawona Hotel",
		"The main building opened in 1879. Guests first arrived here by stagecoach. The hotel is a National Historic Landmark.")
	_lit("HillStudio", WW, "hill_studio", 6.5, 36, "Thomas Hill's Studio",
		"The landscape painter Thomas Hill kept his studio here from 1886; his daughter had married one of the Washburns, who ran the hotel.")
	_lit("ClarkCottage", WW, "cottage_one", 29, 53, "Clark Cottage",
		"The oldest of the hotel's buildings, from 1876, with a veranda all along the front.")
	_lit("WashburnCottage", WW, "cottage_two", 13, 53, "Washburn Cottage",
		"One of the hotel's cottages. The Washburn brothers built the place up over thirty years.")
	_prop("garden_fountain", foot(22, 42))
	for b: Array in [[17, 40.5], [27, 40.5], [9, 46], [35, 46]]:
		_prop("garden_bench", foot(b[0], b[1]) + Vector2(0, 2))
	_info_sign("Sign_Wawona_Hotel", foot(26, 38), "Wawona Hotel",
		"The main building opened in 1879. Guests first arrived here by stagecoach. The hotel is a National Historic Landmark.")
	_info_sign("Sign_Clarks_Station", foot(17, 38), "Clark's Station",
		"Galen Clark homesteaded here in 1856 and kept a way station for travelers. In 1866 he became the first Guardian of the Yosemite Grant.")
	# black oaks round the lawn, where the plums grow
	for p: Array in [[3, 31, "a"], [37, 31, "b"], [3, 48, "c"], [37, 50, "a"], [20, 57, "b"]]:
		_prop("tree_black_oak_" + p[2], foot(p[0], p[1]))


func _place_meadow() -> void:
	for g: Array in [[61, 41], [79, 46], [97, 42], [89, 53]]:
		decor("GolfFlag%d" % g[0], WW + "golf_flag.png", foot(g[0], g[1]), Vector2(2, 2))
	_info_sign("GolfSign", foot(46, 37), "Wawona Golf Course",
		"Nine holes laid out in the meadow in 1918, one of the first golf courses in the Sierra. Sheep once grazed here, and the meadow is still ringed by split-rail fence.")
	_info_sign("MeadowSign", foot(56, 57), "Wawona Meadow",
		"A loop of three and a half miles goes all the way round the meadow. The name Wawona is said to come from a Miwok word for the big trees, or for the owl that guards them.")
	# split-rail fence along the road and the north side of the meadow, with gaps
	for y in range(35, 58, 2):
		if y in [39, 41, 47, 49]:
			continue
		decor("FenceW%d" % y, WW + "fence_v.png", foot(43, y), Vector2(4, 4))
	for x in range(46, 74, 2):
		if x in [52, 54]:
			continue
		decor("FenceN%d" % x, WW + "fence_h.png", foot(x, 33), Vector2(32, 4))


func _place_grove() -> void:
	_lit("WelcomePlaza", WW, "welcome_plaza", 65, 65, "Mariposa Grove Welcome Plaza",
		"Shuttles run from here up into the grove in summer. The road to the big trees was closed to cars in 2018 to protect their roots.")
	decor("GroveShuttle", WW + "grove_shuttle.png", foot(69, 70), Vector2(64, 10))
	instance_scene("res://scenes/objects/travel_point.tscn", foot(59, 68), "Travel_Mariposa_Grove_Welcome_Plaza").set("label", "Mariposa Grove Welcome Plaza")
	_info_sign("Sign_Mariposa_Grove", foot(74, 67), "Mariposa Grove",
		"About 500 mature giant sequoias grow in this grove, the largest in Yosemite. It was protected in 1864, together with Yosemite Valley, in the Yosemite Grant.")
	# The named trees along the trail.
	_prop("tree_fallen_monarch", foot(80, 77))
	_info_sign("FallenMonarchSign", foot(86, 74), "The Fallen Monarch",
		"This sequoia fell hundreds of years ago, and its wood is so full of tannin that it has hardly rotted. In 1899 a troop of cavalry and their horses posed standing on top of it.")
	_prop("tree_sequoia_giant_a", foot(88, 79), "Bachelor")
	for i in 3:
		_prop("tree_sequoia_giant_c", foot(94.5 + i * 2.6, 77.5 + (i % 2) * 0.8), "ThreeGraces%d" % i)
	_info_sign("ThreeGracesSign", foot(91, 81), "The Bachelor and Three Graces",
		"Three sequoias grow so close their roots are bound together, and if one falls, all three will. The Bachelor stands a little apart.")
	_prop("tree_grizzly_giant", foot(101, 87), "GrizzlyGiant")
	_info_sign("Sign_Grizzly_Giant", foot(97, 89), "Grizzly Giant",
		"One of the oldest sequoias in the grove, estimated at about 2,000 years old, and around 209 feet tall.")
	_prop("tree_tunnel", foot(108, 84), "CaliforniaTunnelTree")
	_info_sign("Sign_California_Tunnel_Tree", foot(111, 86), "California Tunnel Tree",
		"A tunnel was cut through this living sequoia in 1895 so stagecoaches could drive through. The tree is still alive, and you can walk through it.")
	_lit("GroveMuseum", WW, "grove_museum", 118, 67, "Mariposa Grove Museum",
		"A log cabin in the upper grove, like the one Galen Clark kept here when he was the grove's Guardian.")
	# More giants through the grove, spaced as they grow, in clumps.
	var giants: Array[Vector2] = [Vector2(88, 79), Vector2(101, 87), Vector2(108, 84)]
	for i in 3:
		giants.append(Vector2(94.5 + i * 2.6, 77.5))
	# keep clear of the Fallen Monarch's length and the museum
	for x in range(76, 86, 3):
		giants.append(Vector2(x, 77))
	giants.append(Vector2(118, 67))
	var tries := 0
	var placed := 0
	# (none in the grove's top rows, where their crowns would stand over the meadow)
	while placed < 18 and tries < 600:
		tries += 1
		var p := Vector2(rng.randi_range(GROVE.position.x + 2, GROVE.end.x - 3), rng.randi_range(GROVE.position.y + 13, GROVE.end.y - 2))
		var t := Vector2i(p)
		if at(t.x, t.y) != Terrain.FOREST or no_trees[t.y * w + t.x] or _any_kind(t.x, t.y, [Terrain.TRAIL, Terrain.PARKING, Terrain.ROAD], 2):
			continue
		if giants.any(func(g: Vector2) -> bool: return g.distance_to(p) < 6.5) or Rect2(72, 76, 18, 16).has_point(p) or Rect2(93, 86, 23, 14).has_point(p) or Rect2(110, 66, 16, 12).has_point(p):
			continue
		giants.append(p)
		_prop("tree_sequoia_giant_" + "abc"[rng.randi() % 3], foot(p.x, p.y))
		placed += 1


func _place_roads() -> void:
	region_exit("WawonaRoadNorth", tile_pos(40.5, 0), Vector2(40, 16), "Wawona Road", "", "").set("travel_to", "yosemite_valley")
	_road_out("WawonaRoadSouth", tile_pos(41.5, 99), Vector2(40, 16), "Wawona Road",
		"Highway 41 continues south to Oakhurst, outside the park.")


func _place_markers() -> void:
	marker("arrival", 50, 19.5)
	marker("wawona_hotel", 22, 43)
	marker("history_center", 75, 15)
	marker("mariposa_grove", 64, 69)
	marker("grizzly_giant", 100, 89.5)
	marker("meadow", 80, 50)
	marker("covered_bridge", 57, 18)
	place("Wawona Hotel", 22, 40, 9)
	place("Yosemite History Center", 76, 13, 9)
	place("Wawona Covered Bridge", 62, DECK_Y, 3, false)
	place("Wawona Store", 50, 18, 5, false)
	place("Wawona Meadow", 82, 47, 22)
	place("Mariposa Grove", 98, 80, 24)
	place("Mariposa Grove Welcome Plaza", 65, 68, 7, false)
	place("Grizzly Giant", 101, 88, 4, false)
	place("California Tunnel Tree", 108, 85, 3, false)
	place("Mariposa Grove Museum", 118, 68, 4, false)
	var river := Marker2D.new()
	river.set_script(load("res://scripts/world/place.gd"))
	river.name = "SouthForkMercedRiver"
	river.position = tile_pos(20, 25)
	river.set("display_name", "South Fork Merced River")
	river.set("radius", 0.0)
	river.set("show_banner", false)
	river.set("show_on_map", true)
	_places.add_child(river)


## Mixed conifer forest round Wawona and through the grove, black oaks at
## the meadow's edge, willows along the river.
func _dress_wawona() -> void:
	_reserve_entities(1, 3)
	var all := Rect2i(0, 0, w, h)
	_fringe_trees([Terrain.FOREST], 3, 0.62, [["tree_ponderosa", 3.0], ["tree_incense_cedar", 3.0], ["tree_sugar_pine", 1.6],
		["tree_white_fir", 1.4], ["tree_black_oak", 1.6], ["tree_dogwood", 0.8]], 2, 24.0)
	_fringe_trees([Terrain.MEADOW, Terrain.WET_MEADOW], 9, 0.3, [["tree_black_oak", 3.0], ["tree_ponderosa", 1.0]], 3, 64.0)
	_fringe_trees([Terrain.SAND], 6, 0.5, [["tree_willow", 1.0], ["tree_alder", 1.0]], 0, 44.0)
	_fringe_trees([Terrain.SCRUB], 6, 0.4, [["tree_ponderosa", 1.0], ["tree_black_oak", 1.0], ["tree_live_oak", 0.6]], 1, 40.0)
	_scatter_decor("plant_manzanita", [Terrain.SCRUB], 40, all, 0)
	_scatter_decor("plant_chamise", [Terrain.SCRUB], 20, all, 0)
	_scatter_decor("rock_granite", [Terrain.SCRUB], 10, all, 1)
	_scatter_decor("plant_wildflowers", [Terrain.MEADOW], 70, all, 1)
	_scatter_decor("plant_lupine", [Terrain.MEADOW], 20, all, 1)
	_scatter_decor("plant_tall_grass", [Terrain.MEADOW, Terrain.WET_MEADOW], 50, all, 1)
	_scatter_decor("plant_cornlily", [Terrain.WET_MEADOW], 12, all, 0)
	_scatter_decor("plant_fern", [Terrain.FOREST], 70, all, 1)
	_scatter_decor("plant_bracken", [Terrain.FOREST], 40, all, 1)
	_scatter_decor("plant_shrub", [Terrain.FOREST], 30, all, 2)
	_scatter_decor("plant_mushrooms", [Terrain.FOREST], 8, all, 2)
	_scatter_decor("rock_granite", [Terrain.FOREST, Terrain.MEADOW], 14, all, 2)
	_scatter_decor("rock_river", [Terrain.SAND], 16, all, 0)
	_scatter_decor("log_fallen", [Terrain.FOREST], 10, all, 2)
	_scatter_decor("log_stump", [Terrain.FOREST], 6, all, 2)
	_scatter_decor("plant_cattails", [Terrain.SAND, Terrain.WET_MEADOW], 8, all, 0)
