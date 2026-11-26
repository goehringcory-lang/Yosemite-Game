extends "res://tools/hubs/build_outer_hub.gd"
## Builds Glen Aulin (about 7,800 feet), north of Tuolumne Meadows where the
## Tuolumne River tumbles down its granite gorge: Tuolumne Falls, White
## Cascade into its deep green pool, and the canvas tent cabins of the Glen
## Aulin High Sierra Camp, with Conness Creek joining.
##
## North is at the top. The river comes in from the east edge, runs west
## over granite slabs, spills down Tuolumne Falls (x=62), passes under the
## trail's footbridge, and reaches the round pool under White Cascade (on
## the north wall, x=28). The camp stands on the pool's east side; the river
## leaves by the west edge. The trail from Tuolumne Meadows (the Glen Aulin
## Trail, here the John Muir Trail's old line past Soda Springs) arrives
## straight off the south edge at column 62 (a seam, scripts/world/seam.gd).
##
## Run tools/hubs/rebuild_glen_aulin.sh to build, migrate onto the 32px
## grid, paint native 32px ground, dress wild clutter, and generate normal
## maps and water cells.

const TM := "res://assets/sprites/tuolumne/"
const GEO := Vector2(-119.4220, 37.9100)
const W := 100
const H := 64
const RIVER := [Vector2(100, 43), Vector2(88, 44), Vector2(76, 42), Vector2(66, 40), Vector2(62, 40), Vector2(56, 38),
	Vector2(50, 34), Vector2(44, 30), Vector2(38, 27), Vector2(34, 24)]
const OUTLET := [Vector2(24, 22), Vector2(16, 19), Vector2(8, 16), Vector2(-1, 14)]
const CONNESS := [Vector2(40, 11), Vector2(37, 14), Vector2(34, 17)]
const FALL_X := 28
const FALL_ROWS := 11


func _ready() -> void:
	print("== Glen Aulin")
	load_flora()
	import_assets()
	_glen_aulin()
	print("Done")
	get_tree().quit()


func _glen_layout() -> void:
	init_grid(W, H, Terrain.SUBALPINE)
	rng.seed = 1910
	noise.seed = 1910
	noise.frequency = 0.1
	# North wall: the granite wall of the gorge, deeper behind White Cascade.
	for x in w:
		var depth := int(6.0 + noise.get_noise_1d(x * 3.0) * 1.6)
		if abs(x - FALL_X) <= 5:
			depth = FALL_ROWS - 1
		fill(x, 0, x, depth, Terrain.CLIFF)
		fill(x, depth + 1, x, depth + 2, Terrain.TALUS)
	fill(FALL_X - 1, 0, FALL_X + 1, FALL_ROWS - 1, Terrain.FALLS)
	# Polished granite slabs, along the river and round the rim.
	_ellipse(62.0, 41.0, 12.0, 5.0, Terrain.GRANITE, 0.28, [Terrain.SUBALPINE])
	_ellipse(82.0, 43.0, 14.0, 5.5, Terrain.GRANITE, 0.28, [Terrain.SUBALPINE])
	_ellipse(50.0, 34.0, 8.0, 5.0, Terrain.GRANITE, 0.28, [Terrain.SUBALPINE])
	_ellipse(20.0, 22.0, 10.0, 7.0, Terrain.GRANITE, 0.28, [Terrain.SUBALPINE])
	_ellipse(6.0, 30.0, 7.0, 9.0, Terrain.GRANITE, 0.3, [Terrain.SUBALPINE])
	_ellipse(92.0, 22.0, 9.0, 8.0, Terrain.GRANITE, 0.3, [Terrain.SUBALPINE])
	_ellipse(14.0, 56.0, 12.0, 6.0, Terrain.GRANITE, 0.3, [Terrain.SUBALPINE])
	_ellipse(88.0, 58.0, 12.0, 6.0, Terrain.GRANITE, 0.3, [Terrain.SUBALPINE])
	_ellipse(40.0, 52.0, 8.0, 5.0, Terrain.GRANITE, 0.3, [Terrain.SUBALPINE])
	# A damp sedge flat at the camp.
	_ellipse(44.0, 20.0, 9.0, 5.0, Terrain.MEADOW, 0.3, [Terrain.SUBALPINE, Terrain.GRANITE])
	# The pool under White Cascade, ringed in sand and granite.
	var shore := [Terrain.SUBALPINE, Terrain.GRANITE, Terrain.MEADOW, Terrain.SAND, Terrain.TALUS]
	_ellipse(28.0, 21.5, 10.0, 8.0, Terrain.SAND, 0.2, shore)
	_ellipse(28.0, 21.5, 8.5, 6.8, Terrain.LAKE, 0.22, shore)
	# The river, Tuolumne Falls, the outlet, and Conness Creek.
	_water(RIVER, 2, Terrain.RIVER, 0.35)
	for x in range(60, 65):
		for y in h:
			if at(x, y) == Terrain.RIVER:
				put(x, y, Terrain.FALLS)
	_water(OUTLET, 2, Terrain.RIVER, 0.35)
	_water(CONNESS, 1, Terrain.CREEK, 0.2)
	var water_before := kind.duplicate()
	# The trail: up from the south edge at column 62, over the footbridge
	# below the falls, then along the north bank to camp.
	_path([Vector2(62, 64), Vector2(62, 52), Vector2(58, 46), Vector2(55, 42), Vector2(55, 34), Vector2(52, 29), Vector2(47, 25), Vector2(41, 21)], 1, Terrain.TRAIL, 0.25)
	_path([Vector2(47, 25), Vector2(52, 20), Vector2(53, 17)], 1, Terrain.TRAIL, 0.2)
	# The deck goes back over the water the trail line crossed.
	for y in range(33, 43):
		for dx in 2:
			if water_before[y * w + 55 + dx] in [Terrain.RIVER, Terrain.SAND]:
				put(55 + dx, y, Terrain.BRIDGE)
	_mark_open()
	clear_trees(57, 46, 67, 63) # the trail in from the south edge
	clear_trees(52, 30, 59, 44) # footbridge
	clear_trees(36, 13, 56, 27) # the camp
	clear_trees(57, 36, 67, 44) # Tuolumne Falls


func _glen_aulin() -> void:
	_glen_layout()
	start_region("GlenAulin", "glen_aulin", "Glen Aulin", GEO)
	_root.hub_id = "tuolumne_meadows"
	paint_ground()
	_save_ground_art("ground_glen_aulin", 1910)
	_place_wall("glen_aulin", 1910, int(FALL_X * T), FALL_ROWS, "WhiteCascade")
	_place_tuolumne_falls()
	_place_glen_features()
	_place_trails_glen()
	_place_markers_glen()
	_dress_glen()
	_finish("glen_aulin", 2.0)


## Tuolumne Falls: the cascade's white water, laid along the river's flow
## (the wall fall's frames turned on their side, faded at both ends by
## tools/hubs/glen_aulin_rapids.py), with spray at its foot.
func _place_tuolumne_falls() -> void:
	var cascade := _animation("TuolumneFalls", "glen_aulin_rapids", 8.0, Vector2(62.5 * T, 40.5 * T), -5, V)
	if cascade:
		cascade.centered = true
		cascade.rotation = PI / 2.0
		cascade.scale = Vector2(1.0, 0.5)
	_ambient("TuolumneFallsSpray", "mist", Vector2(60.0 * T, 40.5 * T), Vector2(28, 10))


func _place_glen_features() -> void:
	# The camp: canvas tent cabins and the dining tent on the pool's east side.
	# The dining tent is the largest cabin; a firewood rack, an ice chest and a bench stand by it.
	decor("FirewoodRack", TM + "firewood_rack.png", foot(46.5, 19), Vector2(24, 8))
	decor("IceChest", TM + "ice_chest.png", foot(43.5, 20), Vector2(16, 8))
	decor("PorchBench", TM + "porch_bench.png", foot(38.5, 21), Vector2(24, 8))
	for c: Array in [[41, 22.5, 2], [45.5, 23.5, 5], [50, 22.5, 8], [41.5, 17, 11], [49.5, 17.5, 14], [45.5, 17, 20]]:
		decor("TentCabin%d" % c[2], C + "tent_cabin_%d.png" % c[2], foot(c[0], c[1]), Vector2(40, 10))

	_info_sign("TuolumneFallsSign", foot(63, 44), "Tuolumne Falls",
		"A wide cascade, about 100 feet in all, where the Tuolumne River slides and splashes down a broad face of granite. The footbridge just below puts you close enough to feel the spray.")
	_info_sign("WhiteCascadeSign", foot(34, 26), "White Cascade",
		"The river churns over a last ledge of granite and pours into a deep green pool. Glaciers scooped the basin; the water has been polishing the rock ever since.")
	_info_sign("GlenAulinSign", foot(39, 24), "Glen Aulin High Sierra Camp",
		"At 7,800 feet, canvas tent cabins by the pool: one of the park's High Sierra Camps, a long day's walk from Tuolumne Meadows. Glen Aulin is a Scottish word for a beautiful valley.")
	_info_sign("ConnessCreekSign", foot(37, 17), "Conness Creek",
		"Snowmelt from the slopes of Mount Conness comes down this little creek to join the Tuolumne at the pool. The water is clear and very cold.")

	# Granite boulders and river rocks.
	for b: Array in [[10, 24], [18, 13], [48, 12], [60, 30], [70, 36], [76, 48], [92, 36], [30, 40], [72, 58], [52, 56]]:
		_prop(_pick("rock_granite"), foot(b[0], b[1]))
	_river_rocks(RIVER, 10)

	# Backcountry camp in the lodgepoles north of the trail.
	var camp := instance_scene("res://scenes/objects/backcountry_camp.tscn", foot(54, 16), "GlenAulinCamp")
	camp.set("wake_spot", "camp")
	camp.set("place_name", "Glen Aulin")

	# Trout in the pool.
	var fish := Node2D.new()
	fish.name = "GlenAulinPoolWater"
	fish.set_script(load("res://scripts/fishing/fishing_water.gd"))
	fish.position = foot(28, 25)
	fish.set("kind", "hole")
	fish.set("size", Vector2(130, 70))
	fish.set("title", "Glen Aulin Pool")
	_entities.add_child(fish)


func _place_trails_glen() -> void:
	# The Glen Aulin Trail runs off the south edge, down to Tuolumne Meadows
	# (a seam: the Meadows' map lies beside this one).
	region_exit("ToTuolumne", tile_pos(62, H - 0.5), Vector2(64, 16), "Glen Aulin Trail, to Tuolumne Meadows", "tuolumne_meadows", "glen_aulin_trail")


func _place_markers_glen() -> void:
	marker("arrival", 62, H - 2.5)
	marker("south", 62, H - 2.5)
	marker("camp", 52, 21)
	marker("pool", 36, 23)
	marker("tuolumne_falls", 60, 44)
	marker("white_cascade", 28, 13)
	place("Glen Aulin", 44, 21, 12)
	place("Glen Aulin Pool", 28, 22, 9)
	place("White Cascade", 28, 14, 7)
	place("Tuolumne Falls", 62, 41, 8)
	place("Glen Aulin Trail", 62, 56, 8)


func _dress_glen() -> void:
	_reserve_entities(1, 3)
	var all := Rect2i(0, 0, w, h)
	_fringe_trees([Terrain.SUBALPINE], 2, 0.6, [["tree_lodgepole", 6.0], ["tree_ponderosa", 0.8], ["tree_whitebark", 1.0], ["tree_snag", 0.3]], 1, 20.0)
	_fringe_trees([Terrain.GRANITE], 6, 0.3, [["tree_whitebark", 2.0], ["tree_lodgepole", 1.2], ["tree_ponderosa", 0.5]], 0, 36.0)
	_fringe_trees([Terrain.MEADOW, Terrain.SAND], 7, 0.25, [["tree_lodgepole", 1.0]], 1, 40.0)
	_scatter_decor("plant_willow_low", [Terrain.SAND], 20, all, 0)
	_scatter_decor("plant_tall_grass", [Terrain.MEADOW], 20, all, 0)
	_scatter_decor("plant_wildflowers", [Terrain.MEADOW], 14, all, 1)
	_scatter_decor("plant_lupine", [Terrain.MEADOW, Terrain.SUBALPINE], 12, all, 1)
	_scatter_decor("plant_paintbrush", [Terrain.MEADOW, Terrain.SUBALPINE, Terrain.GRANITE], 14, all, 1)
	_scatter_decor("rock_granite", [Terrain.GRANITE], 30, all, 1)
	_scatter_decor("rock_granite", [Terrain.SUBALPINE], 16, all, 1)
	_scatter_decor("rock_river", [Terrain.SAND], 14, all, 0)
	_scatter_decor("log_fallen", [Terrain.SUBALPINE], 8, all, 2)
	_scatter_decor("log_stump", [Terrain.SUBALPINE], 4, all, 2)
	_scatter_decor("plant_shrub", [Terrain.SUBALPINE], 14, all, 2)
	_scatter_decor("plant_manzanita", [Terrain.GRANITE], 8, all, 1)
