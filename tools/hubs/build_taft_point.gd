extends "res://tools/hubs/build_outer_hub.gd"
## Builds Taft Point & The Fissures, on the South Rim between Glacier Point
## (Sentinel Dome) and Tunnel View along the Pohono Trail.
##
## Run tools/hubs/rebuild_exploration_regions.sh (which runs this builder,
## migrates onto the 32px grid, paints native 32px ground, dresses wild
## clutter, builds normal maps and water cells, and re-imports).
##
## Layout (west to east along Yosemite Valley's south rim, 7,503 ft):
## - Along the north edge, sheer granite rim overlooking El Capitan and
##   Yosemite Falls straight across the Valley, with the stone wall/railing
##   at Taft Point and a scenic viewer (BinocularView "taft_point").
## - East and west of the point, The Fissures: three deep parallel granite
##   chasms slicing back from the cliff edge, with narrow walkable granite
##   ledges between them.
## - West along the rim, Crocker Point: a wind-scoured granite shelf with
##   gnarled Jeffrey pines and open views down the canyon.
## - South of the rim, Roosevelt Meadow (a wet subalpine meadow and snowmelt
##   creek) framed by red fir and Jeffrey pine forest, with the Pohono Trail
##   linking Glacier Point in the east to Tunnel View in the west.

const GEO := Vector2(-119.6042, 37.7130)
const W := 96
const H := 56
const CREEK := [Vector2(54, 56), Vector2(52, 46), Vector2(48, 40), Vector2(42, 36), Vector2(36, 33)]


func _ready() -> void:
	print("== Taft Point")
	load_flora()
	import_assets()
	_taft_point()
	print("Done")
	get_tree().quit()


func _taft_layout() -> void:
	init_grid(W, H, Terrain.FIR)
	rng.seed = 1909
	noise.seed = 1909
	noise.frequency = 0.1
	# Sheer south rim along the north edge: cliff drop-off into Yosemite Valley.
	for x in w:
		var rim := 5.0 + noise.get_noise_1d(x * 3.0) * 1.4
		if x >= 44 and x <= 56:
			rim = 3.0 # Taft Point juts north out over the abyss
		elif x >= 12 and x <= 24:
			rim = 4.0 # Crocker Point promontory
		var depth := int(rim)
		fill(x, 0, x, depth, Terrain.CLIFF)
		fill(x, depth + 1, x, depth + 2, Terrain.GRANITE)
	# Broad bare granite shelves behind Taft Point, The Fissures, and Crocker Point.
	_ellipse(50.0, 12.0, 22.0, 9.0, Terrain.GRANITE, 0.22, [Terrain.FIR])
	_ellipse(18.0, 13.0, 11.0, 8.0, Terrain.GRANITE, 0.25, [Terrain.FIR])
	_ellipse(74.0, 14.0, 10.0, 6.0, Terrain.GRANITE, 0.3, [Terrain.FIR])
	# The Fissures: three dramatic parallel chasms cut deep into the granite
	# shelf, with solid walkable granite ledges left between and south of them.
	fill(37, 6, 38, 16, Terrain.CLIFF)
	fill(42, 5, 43, 15, Terrain.CLIFF)
	fill(61, 6, 62, 16, Terrain.CLIFF)
	# Talus rim edging the far ends of the fissures for crisp visual depth.
	for fx in [37, 38, 42, 43, 61, 62]:
		put(fx, 17, Terrain.GRANITE)
	# Roosevelt Meadow: a moist subalpine glade with snowmelt creek south of the rim.
	_ellipse(46.0, 41.0, 14.0, 7.0, Terrain.MEADOW, 0.25, [Terrain.FIR])
	_ellipse(47.0, 41.0, 8.0, 4.0, Terrain.WET_MEADOW, 0.3, [Terrain.MEADOW])
	_water(CREEK, 1, Terrain.CREEK, 0.25)
	# Pohono Trail running east-west, plus spurs to Taft Point, The Fissures,
	# Crocker Point, and a south backcountry clearing.
	_path([Vector2(4, 34), Vector2(18, 33), Vector2(34, 32), Vector2(50, 31), Vector2(68, 32), Vector2(92, 32)], 1, Terrain.TRAIL, 0.35)
	_path([Vector2(50, 31), Vector2(50, 22), Vector2(50, 12), Vector2(50, 6)], 1, Terrain.TRAIL, 0.25)
	_path([Vector2(50, 19), Vector2(40, 19), Vector2(34, 15)], 1, Terrain.TRAIL, 0.25)
	_path([Vector2(50, 19), Vector2(60, 19), Vector2(66, 15)], 1, Terrain.TRAIL, 0.25)
	_path([Vector2(18, 33), Vector2(18, 22), Vector2(18, 10)], 1, Terrain.TRAIL, 0.3)
	# Durable granite-grit camp clearing in the red firs southeast of Roosevelt Meadow.
	_ellipse(74.0, 44.0, 5.0, 3.5, Terrain.GRANITE, 0.25, [Terrain.FIR])
	_path([Vector2(70, 32), Vector2(72, 38), Vector2(74, 42)], 1, Terrain.TRAIL, 0.25)
	_mark_open()
	clear_trees(30, 3, 69, 21) # Taft Point & The Fissures bare granite
	clear_trees(10, 4, 27, 20) # Crocker Point bare rim
	clear_trees(3, 30, 13, 38) # west Pohono trailhead
	clear_trees(84, 28, 94, 36) # east Pohono trailhead
	clear_trees(69, 40, 80, 48) # backcountry camp clearing


func _taft_point() -> void:
	_taft_layout()
	start_region("TaftPoint", "taft_point", "Taft Point", GEO)
	_root.hub_id = "glacier_point"
	paint_ground()
	_save_ground_art("ground_taft_point", 1909)
	_place_wall("taft_point", 1909)
	_place_rim_features()
	_place_trails_taft()
	_place_markers_taft()
	_dress_taft()
	_finish("taft_point", 2.0)


func _place_rim_features() -> void:
	# Guardrail along the very tip of Taft Point, matching Glacier Point's railing.
	for rx in [46, 48, 52, 54]:
		decor("RimRail%d" % rx, G + "rim_wall_h.png", foot(rx, 5), Vector2(16, 4))
	# Scenic viewer at Taft Point facing El Capitan & Yosemite Falls across the Valley.
	var viewer := decor("TaftPointViewer", G + "viewer.png", foot(50, 6), Vector2(6, 4))
	viewer.set_script(load("res://scripts/objects/scenic_viewer.gd"))
	viewer.set("view", "taft_point")
	viewer.set("facing", 335.0)
	_hitbox(viewer, Vector2(14, 22))

	_info_sign("TaftPointSign", foot(54, 8), "Taft Point",
		"7,503 feet. Named for President William Howard Taft, who rode here on horseback with John Muir in October 1909 and stood looking straight across the 3,500-foot gulf at El Capitan and Yosemite Falls.")
	_info_sign("FissuresSign", foot(34, 15), "The Fissures",
		"Deep, vertical fractures split the granite back from the lip of the cliff, dropping hundreds of feet straight down. Water freezing in old joints pried these blocks apart millimeter by millimeter. Mind your footing along the ledges.")
	_info_sign("CrockerPointSign", foot(21, 10), "Crocker Point",
		"A quiet granite promontory west of Taft Point along the Pohono Trail. Below you, Bridalveil Fall catches the afternoon wind and El Capitan's southwest face glows orange in late sun.")
	_info_sign("RooseveltMeadowSign", foot(46, 33), "Roosevelt Meadow",
		"A high red-fir glade fed by snowmelt springs. In summer, corn lilies and shooting stars crowd the wet grass, and great gray owls slip out of the firs at dusk to hunt voles.")
	_info_sign("PohonoRimSign", foot(86, 30), "Pohono Trail",
		"Runs thirteen miles along the south rim of Yosemite Valley, from Glacier Point past Sentinel Dome, Taft Point, and Crocker Point all the way down to Wawona Tunnel.")

	# Wind-sculpted sentinel Jeffrey pine at Crocker Point, plus erratic granite boulders.
	decor("CrockerJeffrey", G + "sentinel_jeffrey.png", foot(14, 11), Vector2(12, 6))
	for b: Array in [[32, 10], [46, 13], [57, 11], [67, 11], [12, 16], [24, 15], [72, 15]]:
		_prop(_pick("rock_granite"), foot(b[0], b[1]))

	# Backcountry camp on the durable granite clearing southeast of Roosevelt Meadow.
	var camp := instance_scene("res://scenes/objects/backcountry_camp.tscn", foot(75, 44), "TaftPointCamp")
	camp.set("wake_spot", "camp")
	camp.set("place_name", "Taft Point")


func _place_trails_taft() -> void:
	# East to Glacier Point (Sentinel Dome Trailhead). Guarded when open_world is off.
	_trail_door("PohonoTrailEast", foot(91, 32),
		"Pohono Trail, east to Sentinel Dome and Glacier Point",
		"glacier_point", "sentinel_dome_trailhead", 45, "four_mile_trail",
		"The rim trail to Glacier Point opens once you've climbed the Glacier Point Apron above Curry Village.")
	# West down the Pohono Trail to Tunnel View.
	_trail_door("PohonoTrailWest", foot(5, 34),
		"Pohono Trail, down along the south rim to Tunnel View",
		"tunnel_view", "arrival", 110, "four_mile_trail")


func _place_markers_taft() -> void:
	marker("arrival", 50, 30)
	marker("east", 88, 32)
	marker("west", 8, 34)
	marker("overlook", 50, 8)
	marker("fissures", 35, 17)
	marker("crocker_point", 18, 12)
	marker("roosevelt_meadow", 46, 35)
	marker("camp", 73, 44)
	place("Taft Point", 50, 10, 10)
	place("The Fissures", 40, 13, 8)
	place("Crocker Point", 18, 12, 8)
	place("Roosevelt Meadow", 46, 40, 9)


func _dress_taft() -> void:
	_reserve_entities(1, 3)
	var all := Rect2i(0, 0, w, h)
	_fringe_trees([Terrain.FIR], 2, 0.55, [["tree_white_fir", 4.0], ["tree_lodgepole", 2.0], ["tree_snag", 0.35]], 1, 20.0)
	_fringe_trees([Terrain.GRANITE], 7, 0.16, [["tree_whitebark", 1.5], ["tree_lodgepole", 1.0]], 0, 42.0)
	_scatter_decor("plant_manzanita", [Terrain.GRANITE, Terrain.FIR], 22, all, 1)
	_scatter_decor("plant_shrub", [Terrain.FIR], 18, all, 2)
	_scatter_decor("plant_wildflowers", [Terrain.MEADOW], 18, all, 1)
	_scatter_decor("plant_lupine", [Terrain.MEADOW, Terrain.FIR], 14, all, 1)
	_scatter_decor("plant_paintbrush", [Terrain.GRANITE, Terrain.MEADOW], 14, all, 1)
	_scatter_decor("plant_cornlily", [Terrain.WET_MEADOW], 10, all, 0)
	_scatter_decor("plant_tall_grass", [Terrain.MEADOW, Terrain.WET_MEADOW], 26, all, 0)
	_scatter_decor("rock_granite", [Terrain.GRANITE], 26, all, 1)
	_scatter_decor("rock_granite", [Terrain.FIR], 14, all, 2)
	_scatter_decor("log_fallen", [Terrain.FIR], 12, all, 2)
	_scatter_decor("log_stump", [Terrain.FIR], 6, all, 2)
	_scatter_decor("plant_mushrooms", [Terrain.FIR], 8, all, 2)
