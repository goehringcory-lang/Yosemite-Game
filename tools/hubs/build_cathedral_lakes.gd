extends "res://tools/hubs/build_outer_hub.gd"
## Builds Cathedral Lakes (Lower & Upper Cathedral Lake and Cathedral Pass
## Overlook), at 9,288-9,585 ft along the John Muir Trail between Tuolumne
## Meadows and Tenaya Lake.
##
## Run tools/hubs/rebuild_exploration_regions.sh to build, migrate onto the
## 32px grid, paint native 32px ground, dress wild clutter, and generate
## normal maps and water cells.

const GEO := Vector2(-119.4190, 37.8400)
const W := 108
const H := 64
const STREAM := [Vector2(66, 28), Vector2(58, 31), Vector2(52, 33), Vector2(45, 31), Vector2(40, 30)]


func _ready() -> void:
	print("== Cathedral Lakes")
	load_flora()
	import_assets()
	_cathedral_lakes()
	print("Done")
	get_tree().quit()


func _cathedral_layout() -> void:
	init_grid(W, H, Terrain.SUBALPINE)
	rng.seed = 1869
	noise.seed = 1869
	noise.frequency = 0.1
	# North wall: granite flank of Cathedral Peak (west-center) and Echo Peaks (east),
	# with an open gap at x=25..35 where the John Muir Trail arrives from Tuolumne.
	for x in w:
		if x >= 25 and x <= 35:
			continue
		var depth := int(5.0 + noise.get_noise_1d(x * 3.0) * 1.6)
		if x > 56:
			depth += 2
		fill(x, 0, x, depth, Terrain.CLIFF)
		fill(x, depth + 1, x, depth + 2, Terrain.TALUS)
	# Polished alpine granite benches surrounding both lakes and Cathedral Pass Overlook.
	_ellipse(28.0, 29.0, 19.0, 12.0, Terrain.GRANITE, 0.25, [Terrain.SUBALPINE])
	_ellipse(80.0, 25.0, 19.0, 11.5, Terrain.GRANITE, 0.25, [Terrain.SUBALPINE])
	_ellipse(54.0, 50.0, 13.0, 7.0, Terrain.GRANITE, 0.22, [Terrain.SUBALPINE])
	_ellipse(14.0, 48.0, 6.0, 4.0, Terrain.GRANITE, 0.3, [Terrain.SUBALPINE])
	# Medlicott Meadow: sedge & wet alpine meadow between the two lakes.
	_ellipse(54.0, 33.0, 12.0, 9.0, Terrain.MEADOW, 0.25, [Terrain.SUBALPINE, Terrain.GRANITE])
	_ellipse(53.0, 32.0, 7.0, 4.5, Terrain.WET_MEADOW, 0.3, [Terrain.MEADOW])
	# Sandy shore rings, then Lower Cathedral Lake (west) and Upper Cathedral Lake (east).
	var shore := [Terrain.SUBALPINE, Terrain.GRANITE, Terrain.MEADOW, Terrain.SAND]
	_ellipse(28.0, 29.5, 14.5, 8.5, Terrain.SAND, 0.2, shore)
	_ellipse(28.0, 29.0, 13.0, 7.2, Terrain.LAKE, 0.22, shore)
	_ellipse(80.0, 25.5, 14.0, 8.0, Terrain.SAND, 0.2, shore)
	_ellipse(80.0, 25.0, 12.5, 6.8, Terrain.LAKE, 0.22, shore)
	# Snowmelt stream linking Upper and Lower basins, bridged by the JMT.
	_water(STREAM, 1, Terrain.CREEK, 0.25)
	_bridge(52, 31, 35, 2)
	# John Muir Trail north-south, plus loops to Lower shore, Upper shore, camp, and Pass Overlook.
	_path([Vector2(30, -1), Vector2(30, 14), Vector2(44, 18), Vector2(52, 26), Vector2(52, 42), Vector2(54, 52), Vector2(54, 61)], 1, Terrain.TRAIL, 0.3)
	_path([Vector2(44, 18), Vector2(34, 20), Vector2(22, 20)], 1, Terrain.TRAIL, 0.25)
	_path([Vector2(52, 26), Vector2(62, 20), Vector2(72, 17)], 1, Terrain.TRAIL, 0.25)
	_path([Vector2(52, 40), Vector2(34, 41), Vector2(18, 45), Vector2(14, 48)], 1, Terrain.TRAIL, 0.3)
	_path([Vector2(52, 40), Vector2(70, 38), Vector2(82, 35)], 1, Terrain.TRAIL, 0.3)
	_mark_open()
	clear_trees(24, 0, 37, 15) # North JMT pass
	clear_trees(46, 44, 63, 62) # Cathedral Pass Overlook & South JMT trailhead
	clear_trees(10, 43, 20, 53) # Backcountry camp clearing
	clear_trees(14, 19, 44, 39) # Lower Lake shore
	clear_trees(66, 16, 95, 36) # Upper Lake shore


func _cathedral_lakes() -> void:
	_cathedral_layout()
	start_region("CathedralLakes", "cathedral_lakes", "Cathedral Lakes", GEO)
	_root.hub_id = "tuolumne_meadows"
	paint_ground()
	_save_ground_art("ground_cathedral_lakes", 1869)
	_place_wall("cathedral_lakes", 1869)
	_place_cathedral_features()
	_place_trails_cathedral()
	_place_markers_cathedral()
	_dress_cathedral()
	_finish("cathedral_lakes", 2.2)


func _place_cathedral_features() -> void:
	# Scenic viewer at Cathedral Pass Overlook (looking north/east/south across High Sierra).
	var viewer := decor("CathedralPassViewer", G + "viewer.png", foot(54, 48), Vector2(6, 4))
	viewer.set_script(load("res://scripts/objects/scenic_viewer.gd"))
	viewer.set("view", "cathedral_pass")
	viewer.set("facing", 20.0)
	_hitbox(viewer, Vector2(14, 22))

	_info_sign("CathedralLakesSign", foot(34, 15), "Cathedral Lakes",
		"9,288 to 9,585 feet. Two glacial tarns cupped in granite beneath the fluted spires of Cathedral Peak and Echo Peaks. The John Muir Trail climbs here out of Tuolumne Meadows on its way south to Cathedral Pass and Mount Whitney.")
	_info_sign("CathedralPeakSign", foot(22, 20), "Cathedral Peak",
		"10,911 feet. John Muir made the first ascent alone in September 1869, calling it 'a temple displaying Nature's best masonry and architecture.' Its sharp southeast buttress is one of the finest alpine climbs in the Sierra.")
	_info_sign("UpperLakeSign", foot(74, 36), "Upper Cathedral Lake",
		"The higher basin, tucked under the jagged crest of Echo Peaks. Even in late July, snowbanks linger in the north-facing chutes above the water, and whitebark pines twist along the rocky shore.")
	_info_sign("MedlicottMeadowSign", foot(55, 30), "Medlicott Meadow",
		"A fragile alpine sedge meadow linking the two lakes. Keep to the trail and granite benches here: at 9,500 feet the growing season lasts barely two months.")
	_info_sign("CathedralPassSign", foot(58, 50), "Cathedral Pass Overlook",
		"9,700 feet on the divide between the Tuolumne and Merced drainages. North stands Cathedral Peak; south drop the Sunrise Lakes and Tenaya Canyon toward Half Dome.")

	# Glacial erratics & granite boulders around the basins.
	for b: Array in [[16, 23], [38, 22], [20, 38], [67, 20], [92, 22], [88, 35], [48, 49], [60, 49]]:
		_prop(_pick("rock_granite"), foot(b[0], b[1]))

	# Backcountry camp tucked in the lodgepole/granite clearing southwest of Lower Lake.
	var camp := instance_scene("res://scenes/objects/backcountry_camp.tscn", foot(14, 48), "CathedralCamp")
	camp.set("wake_spot", "camp")
	camp.set("place_name", "Cathedral Lakes")

	# Alpine brook trout fishing hole in Lower Cathedral Lake (accessible from the south/east shore).
	var fish := Node2D.new()
	fish.name = "LowerCathedralLakeWater"
	fish.set_script(load("res://scripts/fishing/fishing_water.gd"))
	fish.position = foot(28, 34)
	fish.set("kind", "hole")
	fish.set("size", Vector2(120, 64))
	fish.set("title", "Lower Cathedral Lake")
	_entities.add_child(fish)


func _place_trails_cathedral() -> void:
	# North down the JMT to Tuolumne Meadows, which lies beside this map's
	# north edge (a seam, scripts/world/seam.gd): walk straight on, no trip.
	region_exit("JMTNorth", tile_pos(30, 0), Vector2(64, 16),
		"John Muir Trail, down to Tuolumne Meadows", "tuolumne_meadows", "cathedral_lakes_trail")
	# South over Cathedral Pass to Tenaya Lake (Sunrise Lakes Trailhead).
	_trail_door("JMTSouth", foot(54, 60),
		"John Muir Trail, south over Cathedral Pass to Tenaya Lake",
		"tenaya_lake", "sunrise_trailhead", 85, "tioga_road")


func _place_markers_cathedral() -> void:
	marker("arrival", 30, 12)
	marker("north", 30, 8)
	marker("south", 54, 57)
	marker("lower_lake", 28, 39)
	marker("upper_lake", 78, 36)
	marker("meadow", 54, 35)
	marker("overlook", 54, 51)
	marker("camp", 16, 48)
	place("Cathedral Lakes", 32, 16, 9)
	place("Lower Cathedral Lake", 28, 30, 13)
	place("Upper Cathedral Lake", 80, 26, 13)
	place("Medlicott Meadow", 54, 33, 8)
	place("Cathedral Pass Overlook", 54, 50, 8)


func _dress_cathedral() -> void:
	_reserve_entities(1, 3)
	var all := Rect2i(0, 0, w, h)
	_fringe_trees([Terrain.SUBALPINE], 2, 0.52, [["tree_lodgepole", 5.0], ["tree_whitebark", 1.2], ["tree_snag", 0.3]], 1, 20.0)
	_fringe_trees([Terrain.GRANITE], 7, 0.16, [["tree_whitebark", 2.2], ["tree_lodgepole", 0.8]], 0, 40.0)
	_scatter_decor("plant_willow_low", [Terrain.WET_MEADOW, Terrain.SAND], 24, all, 0)
	_scatter_decor("plant_tall_grass", [Terrain.MEADOW, Terrain.WET_MEADOW], 30, all, 0)
	_scatter_decor("plant_wildflowers", [Terrain.MEADOW], 18, all, 1)
	_scatter_decor("plant_lupine", [Terrain.MEADOW, Terrain.SUBALPINE], 16, all, 1)
	_scatter_decor("plant_paintbrush", [Terrain.MEADOW, Terrain.SUBALPINE, Terrain.GRANITE], 18, all, 1)
	_scatter_decor("plant_cornlily", [Terrain.WET_MEADOW], 8, all, 0)
	_scatter_decor("rock_granite", [Terrain.GRANITE], 30, all, 1)
	_scatter_decor("rock_granite", [Terrain.SUBALPINE], 16, all, 1)
	_scatter_decor("rock_river", [Terrain.SAND], 12, all, 0)
	_scatter_decor("log_fallen", [Terrain.SUBALPINE], 8, all, 2)
	_scatter_decor("log_stump", [Terrain.SUBALPINE], 4, all, 2)
	_scatter_decor("plant_shrub", [Terrain.SUBALPINE], 14, all, 2)
	_scatter_decor("plant_manzanita", [Terrain.GRANITE], 8, all, 1)
