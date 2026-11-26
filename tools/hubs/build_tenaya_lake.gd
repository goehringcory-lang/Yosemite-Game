extends "res://tools/hubs/build_tuolumne.gd"
## Builds Tenaya Lake and Olmsted Point, the stop on the Tioga Road between
## Crane Flat and Tuolumne Meadows, in the high country's look (the
## Tuolumne ground painter, lodgepoles and whitebark pines on polished
## granite). Run tools/hubs/rebuild_tenaya_lake.sh, which runs this:
##
##   godot --headless --path . res://tools/hubs/build_tenaya_lake.tscn
##
## and then moves the scene and the art onto the game's 32px grid. It
## rewrites scenes/regions/tenaya_lake.tscn, its painted ground and its wall.
## Put story NPCs in scenes/story/content/tenaya_lake.tscn, not in the
## region scene, so a rebuild keeps them.
##
## The real layout, squeezed so it can be walked. As in the Valley scenes,
## the far side is at the top ("behind") whichever way it really lies: the
## Tioga Road runs along the bottom, west to east. At the west end, Olmsted
## Point: a bare granite dome strewn with the boulders the glacier dropped,
## its rim falling away into Tenaya Canyon, with Clouds Rest and the back of
## Half Dome beyond (look through the viewer: BinocularView "olmsted_point").
## East of it the lake, 8,150 feet up in its glacier-scoured basin under the
## granite of Tenaya Peak, with Tenaya Creek leaving its west end for the
## canyon and Mirror Lake far below, and the Sunrise Lakes trailhead beside
## the outlet. At the east end, the sand of East Beach and its picnic tables.
## Lodgepoles on the granite sand between the road and the water.

const GEO_TENAYA := Vector2(-119.4560, 37.8325)
const LAKE_C := Vector2(64.0, 19.0)
const LAKE_R := Vector2(24.0, 8.0)
## Tenaya Creek, out of the lake's west end and away to the canyon.
const OUTLET := [Vector2(41, 20), Vector2(36, 18), Vector2(31, 14), Vector2(28, 9), Vector2(27, 3)]
const ROAD := [Vector2(-1, 36), Vector2(8, 35), Vector2(24, 36), Vector2(40, 37), Vector2(64, 37), Vector2(84, 37), Vector2(101, 38)]


func _ready() -> void:
	print("== Tenaya Lake")
	load_flora()
	import_assets()
	_tenaya_lake()
	print("Done")
	get_tree().quit()


func _tenaya_layout() -> void:
	init_grid(100, 46, Terrain.SUBALPINE)
	rng.seed = 1851
	noise.seed = 1851
	noise.frequency = 0.1
	# The far side: the rim of Tenaya Canyon behind Olmsted Point, low, and
	# Tenaya Peak's granite rising over the lake, with talus at its foot.
	for x in w:
		var rim := 1.5 + noise.get_noise_1d(x * 4.0) * 1.0
		var peak := 7.0 + noise.get_noise_1d(x * 3.0 + 50.0) * 1.5
		var depth := int(lerpf(rim, peak, smoothstep(30.0, 42.0, x)))
		# Olmsted Point's rim is the lip of the canyon, not a wall.
		if x < 26:
			depth = 0
		fill(x, 0, x, depth, Terrain.CLIFF)
		if x > 36:
			fill(x, depth + 1, x, depth + 1 + int(absf(noise.get_noise_1d(x * 5.0 + 40.0)) * 2.5), Terrain.TALUS)
	# Olmsted Point: a dome of bare, polished granite, and more slabs east
	# along the shore and below the road (the apron of Polly Dome).
	_ellipse(15.0, 15.0, 17.0, 14.0, Terrain.GRANITE, 0.25, [Terrain.SUBALPINE])
	for slab: Array in [[36, 26, 5, 2.5], [52, 30, 4, 1.8], [74, 30, 3, 1.5], [56, 44, 16, 3.5], [88, 44, 8, 2.5], [22, 44, 7, 2.5]]:
		_ellipse(slab[0], slab[1], slab[2], slab[3], Terrain.GRANITE, 0.35, [Terrain.SUBALPINE])
	# East Beach: a crescent of sand round the lake's east end, and a strip
	# of sedge meadow behind it where Tenaya Creek comes in.
	_ellipse(85.0, 22.0, 8.0, 9.0, Terrain.SAND, 0.2, [Terrain.SUBALPINE, Terrain.GRANITE])
	_ellipse(91.0, 30.0, 6.0, 3.0, Terrain.MEADOW, 0.3, [Terrain.SUBALPINE])
	_ellipse(46.0, 29.0, 5.0, 2.0, Terrain.WET_MEADOW, 0.3, [Terrain.SUBALPINE])
	# The lake, and a thin sandy rim on its near shore.
	_ellipse(LAKE_C.x, LAKE_C.y + 1.0, LAKE_R.x + 1.0, LAKE_R.y + 1.0, Terrain.SAND, 0.25, [Terrain.SUBALPINE, Terrain.GRANITE])
	# Long and a little crooked, deeper bays at either end.
	var shore := [Terrain.SUBALPINE, Terrain.GRANITE, Terrain.SAND, Terrain.TALUS]
	_ellipse(LAKE_C.x, LAKE_C.y, LAKE_R.x, LAKE_R.y, Terrain.LAKE, 0.25, shore)
	_ellipse(LAKE_C.x - 13.0, LAKE_C.y + 2.5, 9.0, 6.0, Terrain.LAKE, 0.3, shore)
	_ellipse(LAKE_C.x + 12.0, LAKE_C.y - 2.0, 11.0, 6.0, Terrain.LAKE, 0.3, shore)
	_water(OUTLET, 2, Terrain.CREEK, 0.3)
	# The lake narrows into its outlet: deep water a little way down the
	# channel before the creek turns shallow over the rocks.
	_path([Vector2(42, 20.5), Vector2(38, 19), Vector2(35.5, 17)], 2, Terrain.LAKE, 0.2)
	# Where the creek goes over the lip into the canyon, a notch in the rock.
	for x in range(26, 30):
		for y in range(0, 4):
			if at(x, y) in [Terrain.CLIFF, Terrain.TALUS]:
				put(x, y, Terrain.CREEK if x in [27, 28] else Terrain.GRANITE)
	# The Tioga Road, the Olmsted Point lot, the trailhead lot at the lake's
	# west end and the beach lot.
	_path(ROAD, 2, Terrain.ROAD)
	fill(9, 32, 21, 34, Terrain.PARKING)
	fill(31, 33, 37, 35, Terrain.PARKING)
	fill(84, 33, 94, 35, Terrain.PARKING)
	# Up the dome from the lot to the rim; the Sunrise Lakes trail to the
	# outlet; the beach path.
	_path([Vector2(15, 32), Vector2(14, 26), Vector2(12, 18), Vector2(13, 10), Vector2(14, 5)], 1, Terrain.TRAIL, 0.4)
	_path([Vector2(34, 33), Vector2(35, 28), Vector2(38, 24), Vector2(37, 20)], 1, Terrain.TRAIL, 0.4)
	_path([Vector2(89, 33), Vector2(88, 30), Vector2(87, 27)], 1, Terrain.TRAIL, 0.3)
	_mark_open()
	clear_trees(8, 30, 23, 35) # the Olmsted lot
	clear_trees(82, 30, 96, 36) # the beach lot
	clear_trees(4, 2, 26, 12) # the top of the dome: bare rock and boulders


func _tenaya_lake() -> void:
	_tenaya_layout()
	# The lake lies in the high country, with Tuolumne Meadows: its hub
	# (the drives, the map, Fishing.FISH's brook trout).
	start_region("TenayaLake", "tenaya_lake", "Tenaya Lake", GEO_TENAYA)
	_root.hub_id = "tuolumne_meadows"
	paint_ground()
	_save_ground_art("ground_tenaya_lake", 1851)
	_place_wall("tenaya_lake", 1851)
	_place_olmsted()
	_place_lake()
	_place_roads_tenaya()
	_place_markers_tenaya()
	_dress_tenaya()
	_finish("tenaya_lake", 2.0)


## The overlook on Olmsted Point: the viewer on the rim, the erratics, and
## the signs.
func _place_olmsted() -> void:
	var viewer := decor("OlmstedViewer", G + "viewer.png", foot(14, 5), Vector2(6, 4))
	viewer.set_script(load("res://scripts/objects/scenic_viewer.gd"))
	viewer.set("view", "olmsted_point")
	viewer.set("facing", 205.0)
	_hitbox(viewer, Vector2(14, 22))
	_info_sign("OlmstedPointSign", foot(17, 7), "Olmsted Point",
		"8,400 feet. Down Tenaya Canyon to the south, Clouds Rest's long granite back, and past its shoulder the far side of Half Dome, rounded where the Valley sees it sheer. Named for Frederick Law Olmsted, who chaired the first commission to manage Yosemite in 1864, and his son, who served on the park's advisory board.")
	_info_sign("ErraticsSign", foot(8, 15), "Glacial erratics",
		"The boulders lying loose on this bare dome rode here on the ice. The glacier that filled Tenaya Canyon dragged them from the high country to the east, polished the granite under them, and melted away about 15,000 years ago, setting them down where they stand.")
	_info_sign("ExfoliationSign", foot(21, 22), "Sheets of granite",
		"Look for curved slabs peeling off the dome like the layers of an onion. Granite that cooled deep underground swells as the rock above it wears away, and cracks off in shells parallel to its surface. That is how the domes got their shape.")
	_info_sign("OlmstedLotSign", foot(10, 31), "Olmsted Point",
		"A short walk up the granite to the overlook: Clouds Rest, Half Dome and Tenaya Canyon to the south, Tenaya Lake to the east. Stay back from the rim.")
	# Big erratics on the dome: boulders left on the bare rock.
	for b: Array in [[6, 9], [10, 13], [20, 11], [24, 16], [5, 21], [18, 19], [9, 25], [26, 25], [3, 14]]:
		_prop(_pick("rock_granite"), foot(b[0], b[1]))


func _place_lake() -> void:
	_info_sign("TenayaLakeSign", foot(60, 30), "Tenaya Lake",
		"8,150 feet. The ice that flowed down from Tuolumne Meadows scoured this basin out of solid granite, and the lake filled it when the glacier melted. Tenaya Creek leaves its west end and runs down Tenaya Canyon all the way to Mirror Lake in the Valley.")
	_info_sign("PollyDomeSign", foot(48, 38), "Polly Dome and Stately Pleasure Dome",
		"The bare domes above the road on the lake's north side. Stately Pleasure Dome rises straight out of the water beside the road, and its slabs have been climbed since the 1960s. Pywiack Dome stands alone past the lake's east end.")
	_info_sign("SunriseTrailSign", foot(32, 32), "Sunrise Lakes Trailhead",
		"Across Tenaya Creek and up the granite: about 3.5 miles to the Sunrise Lakes and 5 to Sunrise High Sierra Camp, or about 7 south to the top of Clouds Rest. The John Muir Trail passes Sunrise on its way from the Valley to Tuolumne Meadows.")
	_info_sign("TenayaCreekOutletSign", foot(29, 19), "Tenaya Creek",
		"The lake's outlet. In early summer the snowmelt pours out deep and cold here; by fall you can step across on the rocks.")
	_info_sign("EastBeachSign", foot(90, 32), "East Beach",
		"Fine granite sand on the lake's east shore. The water is snowmelt, bracing even in August, and shallow a long way out. Swim, paddle, and keep your food in the bear box.")
	# The lots' map boards: drive anywhere in the park from here.
	instance_scene("res://scenes/objects/travel_point.tscn", foot(92, 33), "Travel_East_Beach").set("label", "East Beach Parking")
	instance_scene("res://scenes/objects/travel_point.tscn", foot(20, 31), "Travel_Olmsted_Point").set("label", "Olmsted Point Parking")
	_picnic_tables("Beach", [[89, 24], [92, 27], [86, 29], [93, 22]])
	for car: Array in [[86, 34.6, 4], [90, 34.6, 7], [13, 33.6, 1], [18, 33.6, 10], [33, 34.6, 3]]:
		decor("Car%d_%d" % [int(car[0]), int(car[1])], C + "car_%d.png" % car[2], foot(car[0], car[1]), Vector2(24, 12))
	_river_rocks(OUTLET, 6)


func _place_roads_tenaya() -> void:
	# West, back down the Tioga Road to Crane Flat; the drive's closure and
	# lock hold as on the map (RegionExit.drive_to with stop_region).
	_drive_on("TiogaRoadWest", tile_pos(-0.5, 35.5), Vector2(12, 48), "Tioga Road", "yosemite_valley", 55, 30.0)
	var west := _exits.get_node("TiogaRoadWest")
	west.set("stop_region", "crane_flat")
	west.set("stop_spawn", "east")
	# East, on along the lake to Tuolumne Meadows: the same high country, laid
	# beside this map at the road (a seam), so you walk on with no trip.
	region_exit("TiogaRoadEast", tile_pos(99.5, 37.5), Vector2(12, 48), "Tioga Road, to Tuolumne Meadows", "tuolumne_meadows", "west")


func _place_markers_tenaya() -> void:
	marker("arrival", 88, 33)
	marker("west", 2, 35.5)
	marker("east", 97, 37.5)
	marker("olmsted_point", 15, 31)
	marker("overlook", 13, 7)
	marker("east_beach", 88, 25)
	marker("sunrise_trailhead", 34, 33)
	marker("outlet", 33, 21)
	place("Tenaya Lake", 64, 19, 20)
	place("Olmsted Point", 14, 13, 12)
	place("East Beach", 88, 24, 7)
	place("Sunrise Lakes Trailhead", 34, 32, 4, false)
	for label: Array in [["Tenaya Canyon", 12, 1], ["Tenaya Peak", 66, 3], ["Polly Dome", 50, 45]]:
		var p := Marker2D.new()
		p.set_script(load("res://scripts/world/place.gd"))
		p.name = (label[0] as String).replace(" ", "")
		p.position = tile_pos(label[1], label[2])
		p.set("display_name", label[0])
		p.set("radius", 0.0)
		p.set("show_banner", false)
		p.set("show_on_map", true)
		_places.add_child(p)


## Lodgepoles on the granite sand, whitebark pines and a few lodgepoles
## clinging in the cracks of the slabs, willows by the beach and the creek,
## and boulders on the granite.
func _dress_tenaya() -> void:
	_reserve_entities(1, 3)
	var all := Rect2i(0, 0, w, h)
	_fringe_trees([Terrain.SUBALPINE], 2, 0.6, [["tree_lodgepole", 6.0], ["tree_whitebark", 0.4], ["tree_snag", 0.2]], 1, 20.0)
	_fringe_trees([Terrain.GRANITE], 6, 0.22, [["tree_whitebark", 2.0], ["tree_lodgepole", 1.0]], 0, 40.0)
	_fringe_trees([Terrain.MEADOW, Terrain.WET_MEADOW], 9, 0.1, [["tree_lodgepole", 1.0]], 2, 80.0)
	_scatter_decor("plant_willow_low", [Terrain.WET_MEADOW, Terrain.SAND], 26, all, 0)
	_scatter_decor("plant_tall_grass", [Terrain.MEADOW, Terrain.WET_MEADOW], 30, all, 0)
	_scatter_decor("plant_wildflowers", [Terrain.MEADOW], 14, all, 1)
	_scatter_decor("plant_lupine", [Terrain.MEADOW, Terrain.SUBALPINE], 10, all, 1)
	_scatter_decor("plant_paintbrush", [Terrain.MEADOW, Terrain.SUBALPINE, Terrain.GRANITE], 14, all, 1)
	_scatter_decor("plant_cornlily", [Terrain.WET_MEADOW], 6, all, 0)
	_scatter_decor("rock_granite", [Terrain.GRANITE], 34, all, 1)
	_scatter_decor("rock_granite", [Terrain.SUBALPINE], 18, all, 1)
	_scatter_decor("rock_river", [Terrain.SAND], 10, all, 0)
	_scatter_decor("log_fallen", [Terrain.SUBALPINE], 8, all, 2)
	_scatter_decor("log_stump", [Terrain.SUBALPINE], 4, all, 2)
	_scatter_decor("plant_shrub", [Terrain.SUBALPINE], 16, all, 2)
	_scatter_decor("plant_manzanita", [Terrain.GRANITE], 10, all, 1)
