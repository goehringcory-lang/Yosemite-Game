extends "res://tools/hubs/build_outer_hub.gd"
## Builds Hetch Hetchy Valley & Wapama Falls (3,800 ft, northwest corner of
## Yosemite, open year-round off Crane Flat and Evergreen Road).
##
## Run tools/hubs/rebuild_hetch_hetchy.sh to build, migrate onto the
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
const W := 146
const H := 56
const WAPAMA_CREEK := [Vector2(74, 10), Vector2(74, 18), Vector2(74, 26), Vector2(73, 35)]
const TUEEULALA_CREEK := [Vector2(45, 9), Vector2(45, 14), Vector2(46, 17)]
const RANCHERIA_CREEK := [Vector2(134, 10), Vector2(134, 15), Vector2(132, 20), Vector2(133, 27), Vector2(131, 35)]
## O'Shaughnessy Dam: its crest runs north-south between the granite knob
## the trail tunnels through and the south abutment.
const DAM_X0 := 17
const DAM_X1 := 21
const DAM_TOP := 19
const DAM_BOTTOM := 44
## The knob at the dam's north end, and the lit tunnel through it.
const KNOB := Rect2i(22, 9, 8, 16)
const TUNNEL_Y := 19
const SOUTH_SHORE := 48

var _drop := PackedByteArray()


func _ready() -> void:
	print("== Hetch Hetchy")
	load_flora()
	import_assets()
	_hetch_hetchy()
	print("Done")
	get_tree().quit()


func _is_drop(x: int, y: int) -> bool:
	return _drop[clampi(y, 0, h - 1) * w + clampi(x, 0, w - 1)] == 1


func _hetch_layout() -> void:
	init_grid(W, H, Terrain.FOOTHILL)
	rng.seed = 1913
	noise.seed = 1913
	noise.frequency = 0.1
	_drop.resize(W * H)
	# North granite canyon wall, deeper at Wapama Falls (x=74), Tueeulala
	# (x=45) and Rancheria Falls (x=134).
	for x in w:
		var depth := int(6.0 + noise.get_noise_1d(x * 2.5) * 1.6)
		if abs(x - 74) <= 4:
			depth = 8
		elif abs(x - 45) <= 3:
			depth = 7
		elif abs(x - 134) <= 3:
			depth = 8
		fill(x, 0, x, depth, Terrain.CLIFF)
		fill(x, depth + 1, x, depth + 2, Terrain.TALUS)
	# Wapama Falls channel on the cliff face.
	fill(73, 0, 75, 8, Terrain.FALLS)
	# Oak woodland & pine slopes on the lower canyon benches.
	_ellipse(36.0, 17.0, 9.0, 5.0, Terrain.FOREST, 0.3, [Terrain.FOOTHILL])
	_ellipse(98.0, 20.0, 14.0, 8.0, Terrain.FOREST, 0.25, [Terrain.FOOTHILL])
	_ellipse(124.0, 16.0, 8.0, 5.0, Terrain.FOREST, 0.25, [Terrain.FOOTHILL])
	_ellipse(60.0, 26.0, 10.0, 6.0, Terrain.GRANITE, 0.28, [Terrain.FOOTHILL])
	_ellipse(45.0, 16.0, 5.5, 4.0, Terrain.GRANITE, 0.25, [Terrain.FOOTHILL, Terrain.TALUS])
	_ellipse(86.0, 24.0, 6.0, 4.0, Terrain.GRANITE, 0.3, [Terrain.FOOTHILL])
	_ellipse(137.0, 24.0, 6.0, 5.0, Terrain.GRANITE, 0.25, [Terrain.FOOTHILL])
	# Hetch Hetchy Reservoir: from the dam's east face to the far end of the
	# canyon, with the south shore (Kolana Rock's foot) along the bottom.
	for x in range(DAM_X1 + 1, w):
		var shore_y := int(34.0 + noise.get_noise_1d(x * 2.0 + 30.0) * 2.0)
		if x >= 54 and x <= 66:
			shore_y = 37 # Kolana Overlook juts out into the water
		elif x >= 88:
			shore_y = 35
		if x < KNOB.end.x + 2:
			shore_y = KNOB.end.y # the bay against the dam, under the knob
		var south := SOUTH_SHORE + int(noise.get_noise_1d(x * 1.7 + 200.0) * 2.5)
		fill(x, shore_y - 1, x, shore_y, Terrain.SAND)
		fill(x, shore_y + 1, x, south - 1, Terrain.LAKE)
		fill(x, south, x, south, Terrain.SAND)
		fill(x, south + 1, x, h - 1, Terrain.FOOTHILL)
	# The far shore, out of reach across the water: Kolana Rock's granite
	# shoulders and oak-and-pine slopes.
	_ellipse(64.0, 55.0, 13.0, 4.5, Terrain.GRANITE, 0.3, [Terrain.FOOTHILL])
	_ellipse(36.0, 54.0, 7.0, 3.0, Terrain.GRANITE, 0.3, [Terrain.FOOTHILL])
	_ellipse(104.0, 55.0, 9.0, 3.5, Terrain.GRANITE, 0.3, [Terrain.FOOTHILL])
	_ellipse(84.0, 54.0, 10.0, 3.0, Terrain.FOREST, 0.3, [Terrain.FOOTHILL])
	_ellipse(128.0, 54.0, 12.0, 3.0, Terrain.FOREST, 0.3, [Terrain.FOOTHILL])
	# The granite knob at the dam's north end, joined to the wall.
	fill(KNOB.position.x, 0, KNOB.end.x - 1, KNOB.end.y - 1, Terrain.CLIFF)
	# O'Shaughnessy Dam crest, a walkway between the reservoir and the drop.
	fill(DAM_X0, DAM_TOP, DAM_X1, DAM_BOTTOM, Terrain.PAVED)
	# The tunnel through the knob (the trail's way east), dark under the roof
	# the dressing hangs over it.
	fill(KNOB.position.x, TUNNEL_Y, KNOB.end.x - 1, TUNNEL_Y + 1, Terrain.PAVED)
	# The south abutment, where the dam meets Kolana's side of the canyon.
	fill(DAM_X0, DAM_BOTTOM + 1, DAM_X1 + 1, h - 1, Terrain.CLIFF)
	# Below the dam: the drop into the Tuolumne gorge, west of the crest and
	# south of the parking lot.
	for y in range(30, h):
		var lip := 16 if y < DAM_BOTTOM + 1 else 17
		for x in range(0, lip + 1):
			put(x, y, Terrain.CLIFF)
			_drop[y * w + x] = 1
	# Hetch Hetchy Road in from the entrance station (west edge), and the
	# parking overlook.
	fill(5, 22, 16, 28, Terrain.PARKING)
	_path([Vector2(-1, 26), Vector2(6, 26)], 2, Terrain.ROAD)
	# Wapama Falls roaring creek, Tueeulala spring cascade, Rancheria Creek.
	_water(WAPAMA_CREEK, 2, Terrain.CREEK, 0.25)
	_water(TUEEULALA_CREEK, 1, Terrain.CREEK, 0.2)
	_water(RANCHERIA_CREEK, 2, Terrain.CREEK, 0.25)
	# Granite pools under Rancheria Falls.
	_ellipse(133.0, 13.0, 3.0, 1.6, Terrain.LAKE, 0.0, [Terrain.CREEK, Terrain.TALUS, Terrain.FOOTHILL, Terrain.FOREST])
	_ellipse(132.5, 23.0, 2.5, 1.4, Terrain.LAKE, 0.0, [Terrain.CREEK, Terrain.FOOTHILL, Terrain.GRANITE, Terrain.FOREST])
	# North-wall trail from the tunnel past Tueeulala, over Wapama Falls'
	# footbridge, to Rancheria Trailhead and on up to Rancheria Falls, plus
	# spurs to Kolana Overlook and the backcountry camp.
	_path([Vector2(KNOB.end.x, 20), Vector2(36, 21), Vector2(45, 20), Vector2(60, 20), Vector2(74, 20), Vector2(88, 21), Vector2(102, 22),
		Vector2(112, 23), Vector2(122, 22), Vector2(130, 21), Vector2(136, 21)], 1, Terrain.TRAIL, 0.25)
	fill(71, 19, 77, 21, Terrain.BRIDGE) # Wapama Falls granite/timber footbridge
	_bridge(131, 20, 22, 3) # Rancheria Creek footbridge
	_path([Vector2(60, 20), Vector2(60, 28), Vector2(60, 33)], 1, Terrain.TRAIL, 0.25)
	_path([Vector2(122, 22), Vector2(126, 24), Vector2(127, 26)], 1, Terrain.TRAIL, 0.2)
	_path([Vector2(130, 21), Vector2(131, 17), Vector2(132, 15)], 1, Terrain.TRAIL, 0.2)
	_ellipse(127.0, 27.0, 4.5, 3.0, Terrain.GRANITE, 0.25, [Terrain.FOREST, Terrain.FOOTHILL])
	_mark_open()
	clear_trees(0, 18, 24, 31) # Entrance, parking, dam
	clear_trees(68, 12, 80, 32) # Wapama Falls & footbridge
	clear_trees(55, 27, 65, 36) # Kolana Overlook clear view
	clear_trees(95, 18, 103, 25) # Rancheria trailhead
	clear_trees(122, 23, 133, 31) # backcountry camp
	clear_trees(128, 10, 140, 24) # Rancheria Falls & pools


func _hetch_hetchy() -> void:
	_hetch_layout()
	start_region("HetchHetchy", "hetch_hetchy", "Hetch Hetchy", GEO)
	_root.hub_id = "yosemite_valley"
	paint_ground()
	_save_ground_art("ground_hetch_hetchy", 1913)
	_place_wall("hetch_hetchy", 1913, int(74 * T), 9, "WapamaFall")
	_place_gorge()
	_place_hetch_features()
	_place_trails_hetch()
	_place_markers_hetch()
	_dress_hetch()
	_mark_oaks()
	_finish("hetch_hetchy", 2.4)


## The drop below the dam: the lit lip and the cliff's shadow
## (GlacierArt.view_below), over a painting of the Tuolumne gorge with the
## outlet jets thundering out of the dam's foot (tools/hubs/hetch_hetchy_gorge.py).
func _place_gorge() -> void:
	var im := GlacierArt.new().view_below(_drop, W, H)
	im.save_png(ProjectSettings.globalize_path(V + "hetch_hetchy_below.png"))
	import_assets()
	_vista(_backdrop("hetch_hetchy_below", Vector2.ZERO, -8, V), GORGE, GORGE_ANCHOR, GORGE_OFFSET, GORGE_PARALLAX, GORGE_JETS)


## The painting under the dam, and where the camera's top-left is when the
## player stands mid-crest (see _vista and assets/shaders/vista.gdshader).
const GORGE := "res://assets/sprites/valley/hetch_hetchy_gorge.png"
const GORGE_ANCHOR := Vector2(144, 770)
const GORGE_OFFSET := Vector2(0, 0)
const GORGE_PARALLAX := Vector2(0.15, 0.25)
## The outlet jets in the painting: top xy, bottom xy, half widths.
const GORGE_JETS := [[Vector2(396, 330), Vector2(318, 420), Vector2(3, 10)], [Vector2(398, 392), Vector2(344, 470), Vector2(2, 7)]]


func _place_hetch_features() -> void:
	# Parapets down both sides of O'Shaughnessy Dam's crest: the reservoir
	# on the east, the drop into the gorge on the west.
	for ry in range(DAM_TOP + 2, DAM_BOTTOM + 1, 3):
		decor("DamRail%d" % ry, G + "rim_wall_v.png", foot(DAM_X1 + 0.6, ry), Vector2(4, 14))
		if ry > 29:
			decor("DamRailWest%d" % ry, G + "rim_wall_v.png", foot(DAM_X0 - 0.6, ry), Vector2(4, 14))
	# The stone wall along the lip south of the parking lot.
	for x in range(4, DAM_X0):
		if _is_drop(x, 30) and not _is_drop(x, 29):
			decor("GorgeWall%d" % x, G + "rim_wall_h.png", Vector2(x * T + T / 2.0, 30 * T + 5), Vector2(16, 4))
	# Scenic viewer on O'Shaughnessy Dam facing east up the flooded granite canyon.
	var viewer := decor("HetchHetchyViewer", G + "viewer.png", foot(19, 30), Vector2(6, 4))
	viewer.set_script(load("res://scripts/objects/scenic_viewer.gd"))
	viewer.set("view", "hetch_hetchy")
	viewer.set("facing", 75.0)
	_hitbox(viewer, Vector2(14, 22))
	# Spray boiling up out of the gorge from the outlet jets.
	_ambient("OutletSpray", "mist", foot(14, 36), Vector2(40, 18))

	# Hetch Hetchy Entrance Station on the road in, open daylight hours only.
	_lit("HetchHetchyEntrance", V, "hetch_hetchy_entrance", 3.0, 25, "Hetch Hetchy Entrance Station",
		"Hetch Hetchy Road is open daylight hours only; the gate here closes at night. No boats, no swimming and no wading in the reservoir: it is drinking water for 2.7 million people around San Francisco Bay.")

	# Travel kiosk & parked cars at the dam parking lot.
	instance_scene("res://scenes/objects/travel_point.tscn", foot(15, 23), "Travel_Hetch_Hetchy").set("label", "Hetch Hetchy Dam Parking")
	for car: Array in [[7, 23.6, 4], [11, 23.6, 1], [14, 27.2, 7]]:
		decor("Car%d_%d" % [int(car[0]), int(car[1])], C + "car_%d.png" % car[2], foot(car[0], car[1]), Vector2(24, 12))

	_info_sign("DamSign", foot(18, 25), "O'Shaughnessy Dam",
		"3,800 feet. Congress passed the Raker Act in 1913 to dam the Tuolumne River here for San Francisco's water supply, over John Muir's fierce opposition. The dam was finished in 1923 and raised 85 feet in 1938. The valley floor beneath the water once held oak groves and meadows much like Yosemite Valley.")
	_info_sign("TunnelSign", foot(20.2, 21), "Wapama Tunnel",
		"Blasted through the granite at the dam's north end for the trail to Wapama Falls and Rancheria. Lamps light it; mind the drip from the ceiling in spring.")
	_info_sign("TueeulalaSign", foot(46, 18), "Tueeulala Fall",
		"Drops 880 feet down the north granite wall in a slender, windblown ribbon. In spring snowmelt it shines silver against the dark cliff; by late summer only a dark streak remains on the rock.")
	_info_sign("WapamaSign", foot(70, 21), "Wapama Falls",
		"Over 1,000 feet of granite cascades pouring straight off the north rim into Hetch Hetchy. In peak spring runoff the spray soaks the footbridges and you can feel the thunder in the timber planks.")
	_info_sign("KolanaSign", foot(60, 31), "Kolana Overlook",
		"Across the water rises Kolana Rock, a sheer 1,900-foot granite dome mirrored in the reservoir. At this low elevation, redbud, buckeye, and black oaks bloom weeks before Yosemite Valley wakes from winter.")
	_info_sign("RancheriaSign", foot(98, 23), "Rancheria Falls Trailhead",
		"Beyond here the trail climbs past Tiltill Valley and Rancheria Falls into Yosemite's quiet northern backcountry, toward Lake Vernon, Laurel Lake, and the Grand Canyon of the Tuolumne.")
	_info_sign("RancheriaFallsSign", foot(130, 19), "Rancheria Falls",
		"Six and a half miles from the dam, Rancheria Creek slides down broad granite steps into clear pools. Backpackers camp in the pines below; a swim in the creek pools (not the reservoir) is the reward on a hot afternoon.")

	# Tueeulala's ribbon and Rancheria's cascade on the north wall (the same
	# falling-water frames as Wapama, narrower; seasonal_falls.gd dries
	# Tueeulala by late summer).
	var tue := _animation("TueeulalaFall", "hetch_hetchy_fall", 7.0, Vector2(45 * T + T / 2.0 - ValleyLandArt.FALL_W / 4.0, 0), -7, V)
	if tue:
		tue.scale = Vector2(0.5, 1.0)
	_animation("TueeulalaFallMist", "hetch_hetchy_mist", 4.0, Vector2(45 * T - 24, 8 * T - 12), -6, V)
	var ran := _animation("RancheriaFall", "hetch_hetchy_fall", 9.0, Vector2(134 * T + T / 2.0 - ValleyLandArt.FALL_W * 0.35, 0), -7, V)
	if ran:
		ran.scale = Vector2(0.7, 1.0)
	_animation("RancheriaFallMist", "hetch_hetchy_mist", 5.0, Vector2(134 * T - 24, 9 * T - 12), -6, V)
	_ambient("RancheriaFallSpray", "mist", foot(133, 12), Vector2(26, 6))

	# Picnic tables & bear box near the dam overlook, plus river boulders along Wapama Creek.
	_picnic_tables("Dam", [[8, 20], [12, 20]])
	_river_rocks(WAPAMA_CREEK, 6)
	_river_rocks(RANCHERIA_CREEK, 8)
	for b: Array in [[42, 16], [56, 26], [64, 28], [84, 24], [91, 20], [110, 26], [118, 27], [138, 26], [140, 18]]:
		_prop(_pick("rock_granite"), foot(b[0], b[1]))

	# Backcountry camp in the pines below Rancheria Falls.
	var camp := instance_scene("res://scenes/objects/backcountry_camp.tscn", foot(127, 26), "HetchHetchyCamp")
	camp.set("wake_spot", "camp")
	camp.set("place_name", "Rancheria Falls")

	# Rainbow & brown trout fishing cove at Kolana Overlook (shore only).
	var fish := Node2D.new()
	fish.name = "WapamaCoveWater"
	fish.set_script(load("res://scripts/fishing/fishing_water.gd"))
	fish.position = foot(60, 39)
	fish.set("kind", "hole")
	fish.set("size", Vector2(140, 72))
	fish.set("title", "Hetch Hetchy Reservoir")
	_entities.add_child(fish)
	# Rancheria Creek's pools under the falls.
	var pools := Node2D.new()
	pools.name = "RancheriaPools"
	pools.set_script(load("res://scripts/fishing/fishing_water.gd"))
	pools.position = foot(132.5, 23)
	pools.set("kind", "rapids")
	pools.set("size", Vector2(72, 40))
	pools.set("title", "Rancheria Creek Pools")
	_entities.add_child(pools)


func _place_trails_hetch() -> void:
	# Hetch Hetchy Road back out past the entrance station, Evergreen Road,
	# to Big Oak Flat Road and on to Crane Flat (year-round, no winter closure;
	# Crane Flat's west road lands here at road_in).
	_long_road("HetchHetchyRoadOut", tile_pos(0.5, 26.5), Vector2(12, 56),
		"Hetch Hetchy Road and Evergreen Road", "crane_flat", "west", 35, 16.0)


func _place_markers_hetch() -> void:
	marker("arrival", 12, 26)
	# (up off the road beside the station: within 200 px of the way back,
	# but not in line with it, so walking on west after arriving stays put)
	marker("road_in", 5, 22.5)
	marker("entrance", 5, 25)
	marker("dam", 19, 28)
	marker("tunnel", 25, 20)
	marker("tueeulala", 45, 20)
	marker("kolana", 60, 32)
	marker("wapama", 74, 20)
	marker("rancheria", 98, 22)
	marker("camp", 126, 24)
	marker("rancheria_falls", 131, 19)
	place("Hetch Hetchy", 18, 26, 10)
	place("O'Shaughnessy Dam", 19, 32, 7)
	place("Tueeulala Fall", 45, 18, 7)
	place("Kolana Overlook", 60, 31, 8)
	place("Wapama Falls", 74, 19, 8)
	place("Rancheria Trailhead", 98, 21, 8)
	place("Rancheria Falls", 132, 19, 9)


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
