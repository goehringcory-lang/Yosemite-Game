extends "res://tools/hubs/build_outer_hub.gd"
## Builds Tuolumne Meadows by hand, laid out like the real place, in the
## Ahwahnee look. Run tools/hubs/rebuild_tuolumne.sh, which runs this:
##
##   godot --headless --path . res://tools/hubs/build_tuolumne.tscn
##
## and then moves the scene and the art onto the game's 32px grid. It
## rewrites scenes/regions/tuolumne_meadows.tscn, the art in
## assets/sprites/tuolumne/ (tuolumne_art.gd), the lodgepoles
## (foothill_flora_art.gd) and the painted ground. Put story NPCs and climbs
## in scenes/story/content/tuolumne_meadows.tscn, not in the region scene, so
## a rebuild keeps them.
##
## The real layout, squeezed so it can be walked, north at the top: the
## great meadow at 8,600 feet with the Tuolumne River meandering west
## through it and the Dana Fork coming in from the east. On its north side
## Lembert Dome, with Dog Lake up the trail behind it, and Pothole Dome at
## the west end; Soda Springs, Parsons Memorial Lodge and the McCauley Cabin
## stand on the rise above the river, reached by a footbridge across the
## meadow or the old road from the Lembert Dome lot. The Tioga Road runs
## along the meadow's south side past the visitor center and the Cathedral
## Lakes trailhead, the store and grill in their canvas tent, the
## campground, and the canvas cabins of the Tuolumne Meadows Lodge, where
## the Lyell Canyon trail starts. South of the road, Fairview Dome, and
## Cathedral Peak at the end of its trail. Lodgepole pine everywhere on the
## granite sand, whitebark pine on the domes, willows on the wet meadow, and
## glacial erratics left lying in the grass.

const TuolumneArt = preload("res://tools/hubs/tuolumne_art.gd")
const TM := "res://assets/sprites/tuolumne/"
const GEO := Vector2(-119.3597, 37.8736)
## Each granite mass: [tile x of its foot's center, tile row of its foot].
const MASS_AT := {
	"lembert_dome": Vector2(112, 18),
	"pothole_dome": Vector2(18, 20),
	"fairview_dome": Vector2(7, 64),
	"cathedral_peak": Vector2(22, 80),
}
const RIVER := [Vector2(141, 26), Vector2(124, 28), Vector2(104, 25), Vector2(86, 30), Vector2(70, 27), Vector2(52, 31),
	Vector2(34, 28), Vector2(16, 31), Vector2(-1, 28)]
## The footbridge carries the meadow trail across the river at this column.
const BRIDGE_X := 63


func _ready() -> void:
	print("== Tuolumne art")
	TuolumneArt.new().save_all()
	load_flora()
	import_assets()
	print("== Tuolumne region")
	_tuolumne()
	print("Done")
	get_tree().quit()


## The Ahwahnee ground painter with the granite as smooth, glacier-polished
## slabs and needle duff in patches on the forest's granite sand.
func _save_ground_art(file_name: String, seed_value: int, rings := [], soils: Array[Rect2i] = []) -> Sprite2D:
	_painter = Ground.new()
	_painter.smooth_granite = true
	_painter.subalpine_duff = true
	var im := _painter.paint(kind, w, h, seed_value)
	im.save_png(ProjectSettings.globalize_path(S + file_name + ".png"))
	import_assets()
	var sprite := Sprite2D.new()
	sprite.name = "GroundArt"
	sprite.texture = texture(S + file_name + ".png")
	sprite.centered = false
	sprite.z_index = -9
	_root.add_child(sprite)
	_root.move_child(sprite, 0)
	_ground.visible = false
	return sprite


func _layout() -> void:
	init_grid(140, 86, Terrain.SUBALPINE)
	rng.seed = 1889
	noise.seed = 1889
	noise.frequency = 0.1
	# The meadow, wetter along the river.
	_ellipse(66, 28, 56, 15, Terrain.MEADOW, 0.25)
	for p: Array in [[40, 30, 9, 3], [76, 27, 10, 2.5], [98, 26, 8, 2.5], [22, 29, 6, 2]]:
		_ellipse(p[0], p[1], p[2], p[3], Terrain.WET_MEADOW, 0.3, [Terrain.MEADOW])
	# Polished granite round the domes and in slabs through the forest.
	for m: String in MASS_AT:
		var at_t: Vector2 = MASS_AT[m]
		var size: Vector3i = TuolumneArt.MASSES[m]
		_ellipse(at_t.x, at_t.y - size.z / 2.0 / T, size.x * 0.42 / T, size.z / 2.0 / T + 0.5, Terrain.GRANITE, 0.35)
	for slab: Array in [[48, 8, 4, 2], [86, 9, 5, 2], [132, 18, 3, 2], [60, 62, 4, 2], [116, 72, 4, 2], [44, 76, 3, 2], [6, 40, 3, 2]]:
		_ellipse(slab[0], slab[1], slab[2], slab[3], Terrain.GRANITE, 0.4, [Terrain.SUBALPINE])
	# The domes and Cathedral Peak themselves are solid rock.
	for m: String in MASS_AT:
		var at_t: Vector2 = MASS_AT[m]
		var size: Vector3i = TuolumneArt.MASSES[m]
		var rx := size.x * 0.3 / T
		var depth := size.z * 0.75 / T
		for y in range(int(at_t.y - depth), int(at_t.y)):
			var f := (at_t.y - y) / depth
			var half := rx * sqrt(maxf(0.0, 1.0 - f * f * 0.6))
			for x in range(int(at_t.x - half), int(at_t.x + half) + 1):
				put(x, y, Terrain.CLIFF)
	# Dog Lake, up behind Lembert Dome.
	_ellipse(131, 7, 5.5, 2.6, Terrain.LAKE, 0.2)
	# The Tuolumne and the Dana Fork, with gravel bars.
	_water(RIVER, 3, Terrain.RIVER, 0.5)
	_water([Vector2(141, 38), Vector2(130, 34), Vector2(118, 28)], 2, Terrain.RIVER, 0.5)
	# The Tioga Road along the meadow's south side, and the spur to the
	# Lembert Dome lot over the river.
	_path([Vector2(-1, 46), Vector2(40, 46), Vector2(80, 47), Vector2(110, 46), Vector2(141, 45)], 2, Terrain.ROAD)
	_path([Vector2(114, 46), Vector2(114, 21)], 2, Terrain.ROAD)
	for y in range(20, 40):
		for x in [114, 115]:
			if at(x, y) in [Terrain.RIVER, Terrain.SAND]:
				put(x, y, Terrain.BRIDGE)
	fill(106, 18, 121, 21, Terrain.PARKING)
	# The old road west from the lot to Soda Springs, and the trail to Dog Lake.
	_path([Vector2(107, 19), Vector2(96, 18), Vector2(82, 17), Vector2(70, 18)], 2, Terrain.TRAIL, 0.3)
	_path([Vector2(121, 19), Vector2(125, 14), Vector2(127, 9)], 1, Terrain.TRAIL, 0.4)
	# Soda Springs and Parsons Lodge on their rise: trampled ground.
	_ellipse(66, 16, 9, 4, Terrain.CAMP, 0.3, [Terrain.MEADOW, Terrain.SUBALPINE])
	# The meadow trail from the visitor center over the footbridge.
	_path([Vector2(52, 46), Vector2(56, 38), Vector2(BRIDGE_X, 32), Vector2(BRIDGE_X, 22), Vector2(65, 19)], 1, Terrain.TRAIL, 0.2)
	for y in range(18, 40):
		for x in [BRIDGE_X, BRIDGE_X + 1]:
			if at(x, y) in [Terrain.RIVER, Terrain.SAND]:
				put(x, y, Terrain.BRIDGE)
	# South of the road: the visitor center's lot, the store's, the campground
	# loops and the lodge.
	fill(35, 48, 44, 51, Terrain.PARKING)
	fill(90, 48, 99, 51, Terrain.PARKING)
	var sites := [[76, 58], [83, 57], [90, 59], [97, 57], [104, 58], [79, 66], [87, 67], [95, 66], [103, 67], [83, 74], [92, 75], [100, 74]]
	for s: Array in sites:
		fill(s[0] - 2, s[1] - 2, s[0] + 3, s[1] + 1, Terrain.CAMP)
	_path([Vector2(72, 47), Vector2(72, 62), Vector2(108, 62), Vector2(108, 70), Vector2(76, 70), Vector2(76, 78), Vector2(106, 78)], 1, Terrain.TRAIL, 0.3)
	_ellipse(129, 56, 10, 6, Terrain.CAMP, 0.3, [Terrain.SUBALPINE, Terrain.GRANITE])
	_path([Vector2(128, 47), Vector2(128, 52)], 1, Terrain.TRAIL)
	# Trails south: to Cathedral Peak round the east side of its base, and up
	# Lyell Canyon from the lodge.
	_path([Vector2(30, 47), Vector2(31, 58), Vector2(36, 70), Vector2(35, 82), Vector2(24, 82.5)], 1, Terrain.TRAIL, 0.4)
	_path([Vector2(133, 60), Vector2(134, 70), Vector2(137, 85)], 1, Terrain.TRAIL, 0.4)
	_mark_open()
	clear_trees(34, 44, 56, 54) # the visitor center
	clear_trees(80, 44, 100, 53) # the store
	clear_trees(56, 10, 76, 21) # Soda Springs
	clear_trees(104, 17, 122, 22) # the Lembert lot
	clear_trees(118, 48, 140, 63) # the lodge
	clear_trees(12, 76, 38, 85) # the foot of Cathedral Peak
	clear_trees(0, 62, 18, 70) # the foot of Fairview Dome


func _tuolumne() -> void:
	_layout()
	start_hub("TuolumneMeadows", "tuolumne_meadows", "Tuolumne Meadows", GEO)
	paint_ground()
	_save_ground_art("ground_tuolumne_meadows", 1889)
	_place_masses()
	_place_soda_springs()
	_place_road_south()
	_place_campground()
	_place_lodge()
	_place_roads()
	_place_markers()
	_dress_tuolumne()
	_finish("tuolumne_meadows", 3.0)


## The domes and Cathedral Peak, each standing on its solid base.
func _place_masses() -> void:
	for m: String in MASS_AT:
		var at_t: Vector2 = MASS_AT[m]
		decor(m.to_pascal_case(), TM + m + ".png", Vector2(at_t.x * T + T / 2.0, at_t.y * T))
	_info_sign("Sign_Lembert_Dome", foot(104, 20), "Lembert Dome",
		"Glaciers flowing west over Lembert Dome smoothed its gentle eastern side and plucked its western face into a steep cliff.")
	_info_sign("PotholeDomeSign", foot(25, 21), "Pothole Dome",
		"A low dome at the meadow's west end, polished smooth by the glacier that filled this basin 2,000 feet deep. Climb its easy back side for a view down the whole meadow.")
	_info_sign("FairviewSign", foot(14, 65), "Fairview Dome",
		"Its smooth north face is one of the great long climbs of the high country, nearly 1,000 feet of granite.")
	_info_sign("CathedralPeakSign", foot(28, 82), "Cathedral Peak",
		"10,911 feet. John Muir climbed it alone in 1869 and called its summit the first church he ever attended. The trail goes on past it to the Cathedral Lakes.")
	_info_sign("DogLakeSign", foot(127, 11), "Dog Lake",
		"A shallow lake on the plateau behind Lembert Dome, warm enough by August for a quick swim.")


func _place_soda_springs() -> void:
	decor("SodaSprings", TM + "soda_springs.png", foot(66, 17), Vector2(50, 8))
	_info_sign("Sign_Soda_Springs", foot(70, 18), "Soda Springs",
		"Cold, naturally carbonated water bubbles up here. Jean-Baptiste Lembert homesteaded this spot in 1885.")
	_lit("ParsonsLodge", TM, "parsons_lodge", 60, 15, "Parsons Memorial Lodge",
		"The Sierra Club built this lodge of local granite in 1915, in memory of club leader Edward Taylor Parsons.")
	_info_sign("Sign_Parsons_Memorial_Lodge", foot(56.5, 16), "Parsons Memorial Lodge",
		"The Sierra Club built this lodge of local granite in 1915, in memory of club leader Edward Taylor Parsons.")
	_lit("McCauleyCabin", TM, "mccauley_cabin", 73, 14, "McCauley Cabin",
		"A log cabin built by the McCauleys, who ran cattle in the meadows; later the rangers used it.")
	# The footbridge, lying over the river where the trail crosses.
	var rows := []
	for y in range(18, 40):
		if at(BRIDGE_X, y) == Terrain.BRIDGE:
			rows.append(y)
	if not rows.is_empty():
		var top: int = rows[0]
		var bottom: int = rows[-1]
		var sprite := _backdrop("footbridge", Vector2(BRIDGE_X * T + T - TuolumneArt.FOOTBRIDGE.x / 2.0, top * T - 6), -7, TM)
		sprite.scale.y = float((bottom - top + 1) * T + 12) / TuolumneArt.FOOTBRIDGE.y
	_info_sign("Sign_Tuolumne_River", foot(BRIDGE_X + 2, 34), "Tuolumne River",
		"The Dana and Lyell forks meet near here, carrying snowmelt from Mount Dana and Mount Lyell west toward Hetch Hetchy.")
	_info_sign("Sign_Tuolumne_Meadows", foot(56, 40), "Tuolumne Meadows",
		"8,600 feet. One of the largest high-elevation meadows in the Sierra Nevada. Snow covers it for much of the year.")


func _place_road_south() -> void:
	_lit("VisitorCenter", TM, "visitor_center", 48, 53, "Tuolumne Meadows Visitor Center",
		"Rangers, maps and wilderness permits for the high country. The road over Tioga Pass is open only from about June to November.")
	instance_scene("res://scenes/objects/travel_point.tscn", foot(36, 49), "Travel_Visitor_Center_Parking").set("label", "Visitor Center Parking")
	_info_sign("CathedralTrailSign", foot(28, 48), "Cathedral Lakes Trailhead",
		"Up through the lodgepoles to the Cathedral Lakes, under Cathedral Peak: 3.5 miles. This stretch is the John Muir Trail.")
	_lit("Store", TM, "store_tent", 86, 52, "Tuolumne Meadows Store",
		"Groceries, camp supplies and the grill, all under a canvas roof that comes down for the winter.")
	var CS_ := "res://assets/sprites/curry/"
	for c: Array in [[37.5, 50.6, 3], [41.5, 50.6, 8], [92, 50.6, 5], [96, 50.6, 0], [109, 20.6, 6], [117, 20.6, 10]]:
		decor("Car%d_%d" % [int(c[0]), int(c[1])], CS_ + "car_%d.png" % c[2], foot(c[0], c[1]), Vector2(24, 12))
	instance_scene("res://scenes/objects/travel_point.tscn", foot(120, 21), "Travel_Dog_Lake_Parking").set("label", "Dog Lake Parking")


func _place_campground() -> void:
	var tents := ["camp4_tent_dome_0", "camp4_tent_canvas", "camp4_tent_dome_1", "camp4_tent_dome_2", "camp4_tent_dome_3", "camp4_tent_dome_1"]
	var sites := [[76, 58], [83, 57], [90, 59], [97, 57], [104, 58], [79, 66], [87, 67], [95, 66], [103, 67], [83, 74], [92, 75], [100, 74]]
	for i in sites.size():
		var s: Array = sites[i]
		var tent: String = tents[i % tents.size()]
		decor("Tent%d" % i, B + tent + ".png", foot(s[0], s[1] - 1), Vector2(28, 8))
		decor("Table%d" % i, B + "camp4_table.png", foot(s[0] + 2, s[1] + 1), Vector2(30, 8))
		decor("BearBox%d" % i, B + "bear_box.png", foot(s[0] - 2, s[1] + 1), Vector2(14, 6))
		decor("FireRing%d" % i, B + "camp4_fire_ring_cold.png", foot(s[0] + 3, s[1] - 1), Vector2(10, 4))
	# lodgepoles between the sites, as the whole campground stands in them
	var pines := [[73, 55], [79.5, 54.5], [83, 56.5], [100, 56.5], [100.5, 54.5], [107, 56], [74, 65], [82.5, 64.5], [91, 64],
		[99, 64.5], [106, 66], [79.5, 73], [87.5, 72.5], [96, 72.5], [104, 73], [80, 80.5], [89, 80], [98, 80.5]]
	for i in pines.size():
		var pp: Array = pines[i]
		_prop("tree_lodgepole_" + "abc"[i % 3], foot(pp[0], pp[1]))
	_info_sign("CampgroundSign", foot(73, 49), "Tuolumne Meadows Campground",
		"Hundreds of sites under the lodgepoles. Nights are cold even in August, and the bears are clever: everything with a smell goes in the bear box.")


func _place_lodge() -> void:
	_lit("LodgeTent", TM, "lodge_tent", 129, 54, "Tuolumne Meadows Lodge",
		"Canvas tent cabins with wood stoves, and supper by lantern in the dining tent. It has looked much like this since the 1910s.")
	var cabins := [[121.5, 58, 2], [126.5, 60, 5], [132, 60, 8], [137, 58, 11], [123, 51, 14]]
	for c: Array in cabins:
		decor("TentCabin%d" % c[2], C + "tent_cabin_%d.png" % c[2], foot(c[0], c[1]), Vector2(40, 10))
	_info_sign("LyellTrailSign", foot(131, 62), "Lyell Canyon Trail",
		"The John Muir Trail heads up Lyell Canyon to Donohue Pass. Mount Lyell, the park's highest peak, holds its shrinking glacier at the head of the canyon.")


func _place_roads() -> void:
	region_exit("TiogaRoadWest", tile_pos(0, 46.5), Vector2(16, 40), "Tioga Road", "", "").set("travel_to", "yosemite_valley")
	_road_out("TiogaRoadEast", tile_pos(139, 45.5), Vector2(16, 40), "Tioga Road",
		"Tioga Road climbs east over Tioga Pass toward Lee Vining and Mono Lake.")


func _place_markers() -> void:
	marker("arrival", 40, 49.5)
	marker("cathedral_lakes_trailhead", 31, 49)
	marker("soda_springs", 66, 19.5)
	marker("lembert_dome", 108, 22)
	marker("tuolumne_lodge", 128, 57)
	marker("cathedral_peak", 22, 81.5)
	marker("lyell_trailhead", 133, 63)
	marker("meadow", 60, 36)
	place("Tuolumne Meadows", 66, 28, 40)
	place("Tuolumne Meadows Visitor Center", 46, 50, 6, false)
	place("Tuolumne Meadows Store", 86, 50, 5, false)
	place("Tuolumne Meadows Campground", 90, 66, 16, false)
	place("Tuolumne Meadows Lodge", 129, 56, 9)
	place("Soda Springs", 66, 17, 6)
	place("Parsons Memorial Lodge", 60, 14, 4, false)
	place("Lembert Dome", 112, 12, 10)
	place("Dog Lake", 131, 7, 7)
	place("Pothole Dome", 18, 17, 7)
	place("Cathedral Lakes Trailhead", 30, 49, 4, false)
	place("Cathedral Peak", 22, 76, 9)
	for label: Array in [["Fairview Dome", 7, 58], ["Tuolumne River", 30, 29]]:
		var p := Marker2D.new()
		p.set_script(load("res://scripts/world/place.gd"))
		p.name = (label[0] as String).replace(" ", "")
		p.position = tile_pos(label[1], label[2])
		p.set("display_name", label[0])
		p.set("radius", 0.0)
		p.set("show_banner", false)
		p.set("show_on_map", true)
		_places.add_child(p)


## Lodgepoles on the granite sand, whitebark pines on the domes' slopes,
## willows on the wet meadow and by the river, and erratic boulders the
## glacier dropped in the grass.
func _dress_tuolumne() -> void:
	_reserve_entities(1, 3)
	var all := Rect2i(0, 0, w, h)
	_fringe_trees([Terrain.SUBALPINE], 2, 0.62, [["tree_lodgepole", 6.0], ["tree_whitebark", 0.3], ["tree_snag", 0.2]], 1, 20.0)
	_fringe_trees([Terrain.GRANITE], 6, 0.35, [["tree_whitebark", 2.0], ["tree_lodgepole", 1.5]], 0, 34.0)
	_fringe_trees([Terrain.MEADOW], 9, 0.08, [["tree_lodgepole", 1.0]], 2, 80.0)
	_scatter_decor("plant_willow_low", [Terrain.WET_MEADOW, Terrain.SAND], 60, all, 0)
	_scatter_decor("plant_tall_grass", [Terrain.MEADOW, Terrain.WET_MEADOW], 90, all, 0)
	_scatter_decor("plant_wildflowers", [Terrain.MEADOW], 50, all, 1)
	_scatter_decor("plant_lupine", [Terrain.MEADOW], 20, all, 1)
	_scatter_decor("plant_paintbrush", [Terrain.MEADOW, Terrain.SUBALPINE], 16, all, 1)
	_scatter_decor("plant_cornlily", [Terrain.WET_MEADOW], 14, all, 0)
	_scatter_decor("rock_granite", [Terrain.MEADOW], 24, all, 1)
	_scatter_decor("rock_granite", [Terrain.SUBALPINE, Terrain.GRANITE], 40, all, 1)
	_scatter_decor("rock_river", [Terrain.SAND], 14, all, 0)
	_scatter_decor("log_fallen", [Terrain.SUBALPINE], 14, all, 2)
	_scatter_decor("log_stump", [Terrain.SUBALPINE], 6, all, 2)
	_scatter_decor("plant_shrub", [Terrain.SUBALPINE], 24, all, 2)
