extends "res://tools/hubs/build_outer_hub.gd"
## Builds Hetch Hetchy Valley & Wapama Falls (3,800 ft, northwest corner of
## Yosemite, open year-round off Crane Flat and Evergreen Road).
##
## Run tools/hubs/rebuild_exploration_regions.sh to build, migrate onto the
## 32px grid, paint native 32px ground, dress wild clutter, and generate
## normal maps and water cells.
##
## Layout (west to east along the north wall of the Tuolumne canyon):
## - West end: O'Shaughnessy Dam overlook & parking lot, with the scenic
##   viewer looking east up the granite gorge toward Kolana Rock, Tueeulala
##   Fall, Wapama Falls, and Hetch Hetchy Dome (BinocularView "hetch_hetchy").
## - Along the south: the deep blue waters of Hetch Hetchy Reservoir.
## - Along the north: sheer granite canyon walls with Tueeulala Fall's mossy
##   alcove and Wapama Falls plunging down the cliff and thundering under the
##   trail's footbridge into the reservoir.
## - Mid-trail: Kolana Overlook, a sun-warmed foothill oak & granite bench
##   jutting toward the water (rainbow & brown trout fishing cove).
## - East end: Rancheria Falls Trailhead and backcountry camp in the oaks
##   and ponderosa pines.

const GEO := Vector2(-119.7880, 37.9478)
const W := 116
const H := 56
const WAPAMA_CREEK := [Vector2(74, 10), Vector2(74, 18), Vector2(74, 26), Vector2(73, 35)]
const TUEEULALA_CREEK := [Vector2(45, 9), Vector2(45, 14), Vector2(46, 17)]


func _ready() -> void:
	print("== Hetch Hetchy")
	load_flora()
	import_assets()
	_hetch_hetchy()
	print("Done")
	get_tree().quit()


func _hetch_layout() -> void:
	init_grid(W, H, Terrain.FOOTHILL)
	rng.seed = 1913
	noise.seed = 1913
	noise.frequency = 0.1
	# North granite canyon wall, deeper at Wapama Falls (x=74) and Tueeulala (x=45).
	for x in w:
		var depth := int(6.0 + noise.get_noise_1d(x * 2.5) * 1.6)
		if abs(x - 74) <= 4:
			depth = 8
		elif abs(x - 45) <= 3:
			depth = 7
		fill(x, 0, x, depth, Terrain.CLIFF)
		fill(x, depth + 1, x, depth + 2, Terrain.TALUS)
	# Wapama Falls channel on the cliff face.
	fill(73, 0, 75, 8, Terrain.FALLS)
	# Oak woodland & pine slopes on the lower canyon benches.
	_ellipse(30.0, 17.0, 12.0, 5.5, Terrain.FOREST, 0.3, [Terrain.FOOTHILL])
	_ellipse(98.0, 20.0, 14.0, 8.0, Terrain.FOREST, 0.25, [Terrain.FOOTHILL])
	_ellipse(60.0, 26.0, 10.0, 6.0, Terrain.GRANITE, 0.28, [Terrain.FOOTHILL])
	_ellipse(45.0, 16.0, 5.5, 4.0, Terrain.GRANITE, 0.25, [Terrain.FOOTHILL, Terrain.TALUS])
	_ellipse(86.0, 24.0, 6.0, 4.0, Terrain.GRANITE, 0.3, [Terrain.FOOTHILL])
	# Hetch Hetchy Reservoir filling the southern half of the canyon east of the dam.
	for x in range(21, w):
		var shore_y := int(34.0 + noise.get_noise_1d(x * 2.0 + 30.0) * 2.0)
		if x >= 54 and x <= 66:
			shore_y = 37 # Kolana Overlook juts out into the water
		elif x >= 88:
			shore_y = 35
		fill(x, shore_y - 1, x, shore_y, Terrain.SAND)
		fill(x, shore_y + 1, x, h - 1, Terrain.LAKE)
	# Below the dam (west of x=16, south of y=36): Tuolumne River canyon tailrace.
	for x in range(0, 18):
		fill(x, 38, x, h - 1, Terrain.CLIFF)
	# O'Shaughnessy Dam crest (x=17..21) and parking overlook (x=4..17).
	fill(17, 21, 21, 37, Terrain.PAVED)
	fill(5, 22, 16, 28, Terrain.PARKING)
	_path([Vector2(-1, 26), Vector2(6, 26)], 2, Terrain.ROAD)
	# Wapama Falls roaring creek + Tueeulala spring cascade.
	_water(WAPAMA_CREEK, 2, Terrain.CREEK, 0.25)
	_water(TUEEULALA_CREEK, 1, Terrain.CREEK, 0.2)
	# North-wall canyon trail from the dam past Tueeulala, over Wapama Falls footbridge,
	# to Rancheria Trailhead, plus spurs to Kolana Overlook and backcountry camp.
	_path([Vector2(18, 22), Vector2(30, 21), Vector2(45, 20), Vector2(60, 20), Vector2(74, 20), Vector2(88, 21), Vector2(102, 22)], 1, Terrain.TRAIL, 0.25)
	fill(71, 19, 77, 21, Terrain.BRIDGE) # Wapama Falls granite/timber footbridge
	_path([Vector2(60, 20), Vector2(60, 28), Vector2(60, 33)], 1, Terrain.TRAIL, 0.25)
	_path([Vector2(98, 22), Vector2(103, 16)], 1, Terrain.TRAIL, 0.2)
	_ellipse(104.0, 16.0, 4.5, 3.0, Terrain.GRANITE, 0.25, [Terrain.FOREST, Terrain.FOOTHILL])
	_mark_open()
	clear_trees(3, 18, 24, 38) # Dam, parking, viewer
	clear_trees(68, 12, 80, 32) # Wapama Falls & footbridge
	clear_trees(55, 27, 65, 36) # Kolana Overlook clear view
	clear_trees(99, 12, 109, 25) # Rancheria camp & trailhead


func _hetch_hetchy() -> void:
	_hetch_layout()
	start_region("HetchHetchy", "hetch_hetchy", "Hetch Hetchy", GEO)
	_root.hub_id = "yosemite_valley"
	paint_ground()
	_save_ground_art("ground_hetch_hetchy", 1913)
	_place_wall("hetch_hetchy", 1913, int(74 * T), 9, "WapamaFall")
	_place_hetch_features()
	_place_trails_hetch()
	_place_markers_hetch()
	_dress_hetch()
	_mark_oaks()
	_finish("hetch_hetchy", 2.4)


func _place_hetch_features() -> void:
	# Guardrail along the east edge of O'Shaughnessy Dam crest.
	for ry in [24, 28, 32, 35]:
		decor("DamRail%d" % ry, G + "rim_wall_v.png", foot(21, ry), Vector2(4, 14))
	# Scenic viewer on O'Shaughnessy Dam facing east up the flooded granite canyon.
	var viewer := decor("HetchHetchyViewer", G + "viewer.png", foot(19, 30), Vector2(6, 4))
	viewer.set_script(load("res://scripts/objects/scenic_viewer.gd"))
	viewer.set("view", "hetch_hetchy")
	viewer.set("facing", 75.0)
	_hitbox(viewer, Vector2(14, 22))

	# Travel kiosk & parked cars at the dam parking lot.
	instance_scene("res://scenes/objects/travel_point.tscn", foot(15, 23), "Travel_Hetch_Hetchy").set("label", "Hetch Hetchy Dam Parking")
	for car: Array in [[7, 23.6, 4], [11, 23.6, 1], [14, 27.2, 7]]:
		decor("Car%d_%d" % [int(car[0]), int(car[1])], C + "car_%d.png" % car[2], foot(car[0], car[1]), Vector2(24, 12))

	_info_sign("DamSign", foot(18, 25), "O'Shaughnessy Dam",
		"3,800 feet. Congress passed the Raker Act in 1913 to dam the Tuolumne River here for San Francisco's water supply, over John Muir's fierce opposition. The valley floor beneath the water once held oak groves and meadows much like Yosemite Valley.")
	_info_sign("TueeulalaSign", foot(46, 18), "Tueeulala Fall",
		"Drops 880 feet down the north granite wall in a slender, windblown ribbon. In spring snowmelt it shines silver against the dark cliff; by late summer only a dark streak remains on the rock.")
	_info_sign("WapamaSign", foot(70, 21), "Wapama Falls",
		"Over 1,000 feet of granite cascades pouring straight off the north rim into Hetch Hetchy. In peak spring runoff the spray soaks the footbridges and you can feel the thunder in the timber planks.")
	_info_sign("KolanaSign", foot(60, 31), "Kolana Overlook",
		"Across the water rises Kolana Rock, a sheer 1,900-foot granite dome mirrored in the reservoir. At this low elevation, redbud, buckeye, and black oaks bloom weeks before Yosemite Valley wakes from winter.")
	_info_sign("RancheriaSign", foot(98, 23), "Rancheria Falls Trailhead",
		"Beyond here the trail climbs past Tiltill Valley and Rancheria Falls into Yosemite's quiet northern backcountry, toward Lake Vernon, Laurel Lake, and the Grand Canyon of the Tuolumne.")

	# Picnic tables & bear box near the dam overlook, plus river boulders along Wapama Creek.
	_picnic_tables("Dam", [[24, 24], [27, 26]])
	_river_rocks(WAPAMA_CREEK, 6)
	for b: Array in [[42, 16], [56, 26], [64, 28], [84, 24], [91, 20]]:
		_prop(_pick("rock_granite"), foot(b[0], b[1]))

	# Backcountry camp in the oak-and-pine clearing past Wapama Falls.
	var camp := instance_scene("res://scenes/objects/backcountry_camp.tscn", foot(104, 16), "HetchHetchyCamp")
	camp.set("wake_spot", "camp")
	camp.set("place_name", "Hetch Hetchy")

	# Rainbow & brown trout fishing cove at Kolana Overlook.
	var fish := Node2D.new()
	fish.name = "WapamaCoveWater"
	fish.set_script(load("res://scripts/fishing/fishing_water.gd"))
	fish.position = foot(60, 39)
	fish.set("kind", "hole")
	fish.set("size", Vector2(140, 72))
	fish.set("title", "Hetch Hetchy Reservoir")
	_entities.add_child(fish)


func _place_trails_hetch() -> void:
	# Road back out to Crane Flat (year-round, no winter closure).
	_trail_door("HetchHetchyRoadBack", foot(10, 26),
		"Hetch Hetchy Road, back to Crane Flat",
		"crane_flat", "arrival", 35)


func _place_markers_hetch() -> void:
	marker("arrival", 12, 26)
	marker("dam", 19, 28)
	marker("tueeulala", 45, 20)
	marker("kolana", 60, 32)
	marker("wapama", 74, 20)
	marker("rancheria", 98, 22)
	marker("camp", 102, 16)
	place("Hetch Hetchy", 18, 26, 10)
	place("O'Shaughnessy Dam", 19, 30, 7)
	place("Tueeulala Fall", 45, 18, 7)
	place("Kolana Overlook", 60, 31, 8)
	place("Wapama Falls", 74, 19, 8)
	place("Rancheria Trailhead", 98, 21, 8)


func _dress_hetch() -> void:
	_reserve_entities(1, 3)
	var all := Rect2i(0, 0, w, h)
	_fringe_trees([Terrain.FOOTHILL], 3, 0.38, [
		["tree_black_oak", 2.8], ["tree_live_oak", 2.0], ["tree_gray_pine", 1.8],
		["tree_buckeye", 1.2], ["tree_redbud", 1.2], ["tree_snag", 0.2]], 1, 22.0)
	_fringe_trees([Terrain.FOREST], 2, 0.5, [
		["tree_ponderosa", 3.0], ["tree_black_oak", 2.5], ["tree_incense_cedar", 1.5], ["tree_snag", 0.2]], 1, 20.0)
	_fringe_trees([Terrain.GRANITE], 7, 0.14, [["tree_gray_pine", 1.5], ["tree_live_oak", 1.0]], 0, 38.0)
	_scatter_decor("plant_manzanita", [Terrain.FOOTHILL, Terrain.GRANITE], 24, all, 1)
	_scatter_decor("plant_shrub", [Terrain.FOOTHILL, Terrain.FOREST], 20, all, 2)
	_scatter_decor("plant_wildflowers", [Terrain.FOOTHILL], 20, all, 1)
	_scatter_decor("plant_lupine", [Terrain.FOOTHILL, Terrain.FOREST], 14, all, 1)
	_scatter_decor("plant_tall_grass", [Terrain.FOOTHILL, Terrain.SAND], 24, all, 0)
	_scatter_decor("rock_granite", [Terrain.GRANITE, Terrain.FOOTHILL], 26, all, 1)
	_scatter_decor("rock_river", [Terrain.SAND], 14, all, 0)
	_scatter_decor("log_fallen", [Terrain.FOREST, Terrain.FOOTHILL], 10, all, 2)
	_scatter_decor("log_stump", [Terrain.FOREST], 5, all, 2)
