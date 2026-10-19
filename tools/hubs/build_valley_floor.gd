extends AhwahneeStyle
## Builds the Valley floor between the hand-made areas, in the Ahwahnee look:
## four small areas of their own (El Capitan Meadow, Tunnel View, Happy Isles
## and Mirror Lake) and the short trail scenes that join every area to its
## neighbors. Each place is in one scene only; the trails between them are
## for walking, like the Stoneman Meadow trail.
##
##                         [drive: El Portal, Tuolumne]
##                                     |
##   [drive: Wawona] - Tunnel View     El Capitan Meadow
##                          |                 |
##                   Bridalveil Fall     Leidig Meadow
##                          |                 |
##                   Four Mile Trailhead - Yosemite Village - Ahwahnee Meadow - The Ahwahnee
##                                            |
##                                     Housekeeping Camp - Curry Village
##                                                              |
##                                Upper Pines - Happy Isles - Tenaya Creek - Mirror Lake
##
## Every road keeps its heading: leave a scene by its west edge and you come
## in at the east edge of the next. The wall of the Valley is always at the
## top of a scene ("behind"), as in Curry Village, whichever side of the
## Valley it really is. Run tools/hubs/rebuild_valley_floor.sh, which runs
##
##   godot --headless --path . res://tools/hubs/build_valley_floor.tscn
##
## and then moves the scenes and the art onto the game's 32px grid. It
## rewrites the scenes listed in SCENES, the walls and falls in
## assets/sprites/valley/ (valley_land_art.gd), Tunnel View's view, and the
## painted grounds in assets/sprites/ahwahnee/. Put story NPCs and climbs in
## scenes/story/content/<region>.tscn (placed by Marker name), not in the
## region scenes, so a rebuild keeps them.

const ValleyLandArt = preload("res://tools/hubs/valley_land_art.gd")
const ValleyArt = preload("res://tools/hubs/valley_art.gd")
const Camp4Art = preload("res://tools/hubs/camp4_art.gd")
const GlacierArt = preload("res://tools/hubs/glacier_art.gd")

const V := "res://assets/sprites/valley/"
const B := "res://assets/sprites/buildings/"
const G := "res://assets/sprites/glacier/"
## Curry Village's pictures are already on the 32px grid: give their
## footprints by hand, at the builder's 16px scale.
const C := "res://assets/sprites/curry/"
const DIR := "res://scenes/regions/"
const SCENES := ["el_capitan_meadow", "tunnel_view", "happy_isles", "mirror_lake", "leidig_meadow",
	"four_mile_trailhead", "bridalveil_fall", "housekeeping_camp", "ahwahnee_meadow", "upper_pines", "tenaya_creek"]

const FOREST_TABLE := [["tree_ponderosa", 4.0], ["tree_incense_cedar", 3.5], ["tree_black_oak", 2.5], ["tree_white_fir", 1.2], ["tree_dogwood", 1.0]]

## The fall's center in pixels (16px scale), or NO_FALL.
const NO_FALL := -10000


func _ready() -> void:
	print("== Valley floor art")
	ValleyArt.new().save_all()
	Camp4Art.new().save_all()
	GlacierArt.new().save_all()
	load_flora()
	import_assets()
	_el_capitan_meadow()
	_leidig_meadow()
	_four_mile_trailhead()
	_bridalveil_fall()
	_tunnel_view()
	_ahwahnee_meadow()
	_housekeeping_camp()
	_upper_pines()
	_happy_isles()
	_tenaya_creek()
	_mirror_lake()
	print("Done")
	get_tree().quit()


# ================================================================ helpers

func _begin(width: int, height: int, seed_value: int) -> void:
	init_grid(width, height, Terrain.FOREST)
	rng.seed = seed_value
	noise.seed = seed_value
	noise.frequency = 0.1


## The wall of the Valley across the top: solid rock down to about
## [param depth] rows (ragged), then a band of talus.
func _wall(depth: float, ragged := 2.0, talus := 2) -> void:
	for x in w:
		var base := int(depth + noise.get_noise_1d(x * 3.0) * ragged)
		fill(x, 0, x, base, Terrain.CLIFF)
		fill(x, base + 1, x, base + talus + int(absf(noise.get_noise_1d(x * 5.0 + 40.0)) * 2.0), Terrain.TALUS)


## The first walkable row under the wall at column [param x]: where a climb's
## sign stands.
func _foot_of_wall(x: int) -> int:
	var y := 0
	while y < h - 1 and at(x, y) in [Terrain.CLIFF, Terrain.TALUS, Terrain.FALLS]:
		y += 1
	return y


## A river or creek through [param points] (tiles), [param width] wide, with
## gravel bars along its banks.
func _water(points: Array, width: int, type := Terrain.RIVER, bars := 0.6) -> void:
	_path(points, width, type, 0.8)
	if bars <= 0.0:
		return
	for y in h:
		for x in w:
			if at(x, y) in [Terrain.FOREST, Terrain.MEADOW] and _any_kind(x, y, [type], 1) and rng.randf() < bars:
				put(x, y, Terrain.SAND)


## A footbridge or road bridge over the water between rows y0 and y1 at
## column x (as [param width] columns).
func _bridge(x: int, y0: int, y1: int, width := 2) -> void:
	for y in range(y0, y1 + 1):
		for dx in width:
			if at(x + dx, y) in [Terrain.RIVER, Terrain.CREEK, Terrain.SAND, Terrain.LAKE]:
				put(x + dx, y, Terrain.BRIDGE)


## Keeps trees off water, roads, walls and anything built.
func _mark_open() -> void:
	no_trees.resize(w * h)
	for y in h:
		for x in w:
			if at(x, y) in [Terrain.RIVER, Terrain.LAKE, Terrain.CREEK, Terrain.BRIDGE, Terrain.TRAIL, Terrain.ROAD,
					Terrain.PARKING, Terrain.PAVED, Terrain.SAND, Terrain.CLIFF, Terrain.TALUS, Terrain.FALLS, Terrain.CAMP]:
				no_trees[y * w + x] = 1


## Draws the wall picture for the cliff outline (valley_land_art.gd), and the
## fall down its gully if it has one.
func _place_wall(prefix: String, seed_offset: int, fall_cx := NO_FALL, fall_rows := 0, fall_name := "") -> void:
	var prof := PackedInt32Array()
	prof.resize(w * T)
	for x in w:
		var rows := 0
		while rows < h and kind[rows * w + x] in [Terrain.CLIFF, Terrain.FALLS]:
			rows += 1
		for px_ in T:
			prof[x * T + px_] = rows * T
	var art := ValleyLandArt.new()
	art.seed_offset = seed_offset
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(V))
	if fall_cx == NO_FALL:
		art.village_wall(prof, fall_cx).save_png(ProjectSettings.globalize_path(V + prefix + "_wall.png"))
	else:
		art.save_village(prof, fall_cx, V, prefix, fall_rows * T)
	import_assets()
	_backdrop(prefix + "_wall", Vector2.ZERO, -8, V)
	if fall_cx != NO_FALL:
		_animation(fall_name, prefix + "_fall", 8.0, Vector2(fall_cx - ValleyLandArt.FALL_W / 2.0, 0), -7, V)
		_animation(fall_name + "Mist", prefix + "_mist", 5.0, Vector2(fall_cx - 32, fall_rows * T - 28 + 6), -6, V)
		_ambient(fall_name + "Spray", "mist", Vector2(fall_cx, fall_rows * T + 4), Vector2(28, 6))


## A road off the map that opens the park map to drive somewhere.
func _drive_exit(exit_name: String, at_pos: Vector2, size: Vector2, label: String, travel_to: String) -> void:
	region_exit(exit_name, at_pos, size, label, "", "").set("travel_to", travel_to)


## A trail into another region, with its trailhead sign: interact to walk it.
func _trail_door(node_name: String, at_pos: Vector2, label: String, target_region: String, target_spawn: String, minutes: int) -> void:
	var door := instance_scene("res://scenes/objects/region_door.tscn", at_pos, node_name)
	door.set("label", label)
	door.set("target_region", target_region)
	door.set("target_spawn", target_spawn)
	door.set("minutes", minutes)


## The forest, the meadows, the water's edge and the talus, dressed like the
## Ahwahnee grounds.
func _dress(meadow_flowers := 60, forest_floor := 60) -> void:
	_reserve_entities(1, 3)
	var all := Rect2i(0, 0, w, h)
	_fringe_trees([Terrain.FOREST], 3, 0.7, FOREST_TABLE, 2, 22.0)
	_fringe_trees([Terrain.MEADOW, Terrain.WET_MEADOW], 8, 0.3, [["tree_black_oak", 3.0], ["tree_dogwood", 1.0], ["tree_ponderosa", 0.8]], 3, 60.0)
	_fringe_trees([Terrain.TALUS], 5, 0.4, [["tree_incense_cedar", 2.0], ["tree_snag", 0.6], ["tree_white_fir", 1.0]], 0, 30.0)
	_fringe_trees([Terrain.SAND], 6, 0.5, [["tree_willow", 1.0]], 0, 44.0)
	_fringe_trees([Terrain.SCRUB], 6, 0.35, [["tree_black_oak", 1.0], ["tree_ponderosa", 1.0]], 1, 40.0)
	_scatter_decor("plant_wildflowers", [Terrain.MEADOW], meadow_flowers, all, 1)
	_scatter_decor("plant_lupine", [Terrain.MEADOW], meadow_flowers / 4, all, 1)
	_scatter_decor("plant_tall_grass", [Terrain.MEADOW, Terrain.WET_MEADOW], meadow_flowers / 2, all, 1)
	_scatter_decor("plant_cornlily", [Terrain.WET_MEADOW], 10, all, 0)
	_scatter_decor("plant_cattails", [Terrain.SAND, Terrain.WET_MEADOW], 10, all, 0)
	_scatter_decor("plant_fern", [Terrain.FOREST], forest_floor, all, 1)
	_scatter_decor("plant_bracken", [Terrain.FOREST], forest_floor / 2, all, 1)
	_scatter_decor("plant_shrub", [Terrain.FOREST, Terrain.MEADOW], forest_floor / 2, all, 2)
	_scatter_decor("plant_manzanita", [Terrain.SCRUB], 30, all, 1)
	_scatter_decor("plant_mushrooms", [Terrain.FOREST], 6, all, 2)
	_scatter_decor("rock_granite", [Terrain.MEADOW, Terrain.FOREST, Terrain.SAND, Terrain.SCRUB], 16, all, 2)
	_scatter_decor("rock_mossy", [Terrain.FOREST], 8, all, 2)
	_scatter_decor("rock_river", [Terrain.SAND], 14, all, 0)
	_scatter_decor("log_fallen", [Terrain.FOREST, Terrain.MEADOW], 5, all, 2)
	_scatter_decor("log_stump", [Terrain.FOREST], 5, all, 2)
	_scatter_decor("tree_snag", [Terrain.FOREST], 2, all, 3)


## Rocks in the water, breaking the current, along [param points].
func _river_rocks(points: Array, n: int) -> void:
	for i in n:
		var a: Vector2 = points[rng.randi_range(0, points.size() - 2)]
		var b: Vector2 = points[points.find(a) + 1]
		var p := a.lerp(b, rng.randf())
		var c := Vector2i(p)
		if at(c.x, c.y) != Terrain.RIVER:
			continue
		_prop(_pick("rock_river"), Vector2(p.x * T + rng.randf_range(-4, 4), p.y * T + 12.0))


## Curry Village's tent cabins (32px pictures), on a numbered deck each.
func _tent_cabin(x: float, y: int, variant: int) -> void:
	decor("TentCabin%d" % variant, C + "tent_cabin_%d.png" % variant, foot(x, y), Vector2(40, 10))


func _finish(region_id: String, forage_scale: float) -> void:
	place_blockers()
	add_forage(region_id, forage_scale)
	for child in _root.get_children():
		_own(child, _root)
	pack(_root, DIR + region_id + ".tscn")
	print("  ", region_id)


# ================================================================ El Capitan Meadow

## El Capitan over its meadow, Northside Drive along its foot, and the
## Merced. The Nose starts at the toe of the buttress; the Nutcracker is on
## Manure Pile Buttress to the east. The road west leaves the Valley.
func _el_capitan_meadow() -> void:
	_begin(80, 46, 1958)
	_wall(10.0, 1.5, 3)
	# El Capitan's toe pushes out in the middle.
	for x in range(30, 50):
		var bulge := int(2.5 * (1.0 - absf(x - 40) / 10.0))
		fill(x, 0, x, 11 + bulge, Terrain.CLIFF)
		fill(x, 12 + bulge, x, 13 + bulge, Terrain.TALUS)
	_ellipse(42.0, 30.0, 27.0, 7.5, Terrain.MEADOW, 0.25)
	_ellipse(56.0, 31.0, 7.0, 3.0, Terrain.WET_MEADOW, 0.3, [Terrain.MEADOW])
	var river := [Vector2(-1, 40), Vector2(14, 41), Vector2(30, 39), Vector2(46, 41), Vector2(62, 40), Vector2(81, 42)]
	_water(river, 3)
	var road := [Vector2(-1, 21), Vector2(20, 21), Vector2(40, 20), Vector2(60, 21), Vector2(81, 21)]
	_path(road, 2, Terrain.ROAD)
	# Turnouts where climbers park and look up, and the trail to the Nose.
	fill(24, 18, 32, 19, Terrain.PARKING)
	_path([Vector2(40, 19), Vector2(40, 16), Vector2(40, _foot_of_wall(40))], 1, Terrain.TRAIL, 0.4)
	_path([Vector2(64, 20), Vector2(66, 17), Vector2(66, _foot_of_wall(66))], 1, Terrain.TRAIL, 0.4)
	# A path out into the meadow, to the river.
	_path([Vector2(48, 22), Vector2(47, 30), Vector2(45, 37)], 1, Terrain.TRAIL, 0.6)
	_mark_open()

	start_region("ElCapitanMeadow", "el_capitan_meadow", "El Capitan Meadow", Vector2(-119.6370, 37.7230))
	paint_ground()
	_save_ground_art("ground_el_capitan_meadow", 1958)
	_place_wall("el_capitan", 101)
	_info_sign("ElCapitanSign", foot(36, 21) + Vector2(0, -2), "El Capitan",
		"El Capitan rises about 3,000 feet from the Valley floor. Climbers first reached the top by the Nose in 1958, after 47 days of climbing spread over 18 months.")
	_info_sign("MeadowSign", foot(50, 23), "El Capitan Meadow",
		"Stand here with binoculars and look for climbers on the wall: tiny colored dots on the Nose, some of them days into their climb. At night their headlamps glow on the face.")
	_info_sign("MercedSign", foot(46, 37), "The Merced River",
		"The Merced flows from the high country through the Valley and on to the San Joaquin River. Congress named it a Wild and Scenic River in 1987.")
	shuttle("ShuttleElCapitan", "El Capitan Meadow", foot(22, 23))
	_dress(80, 50)
	marker("arrival", 30, 22)
	marker("shuttle", 22, 24)
	marker("east", 77, 21.5)
	marker("west", 2, 21.5)
	marker("meadow", 46, 30)
	marker("the_nose", 40, _foot_of_wall(40))
	marker("nutcracker", 66, _foot_of_wall(66))
	place("El Capitan Meadow", 42, 30, 20)
	place("El Capitan", 40, 5, 0)
	region_exit("ToLeidigMeadow", tile_pos(79.5, 21.5), Vector2(12, 48), "Northside Drive east", "leidig_meadow", "west")
	_drive_exit("NorthsideDriveWest", tile_pos(-0.5, 21.5), Vector2(12, 48), "Northside Drive west: El Portal Road and Big Oak Flat Road", "el_portal")
	_finish("el_capitan_meadow", 2.0)


# ================================================================ Leidig Meadow

## Northside Drive between El Capitan and Camp 4: Leidig Meadow under the
## Three Brothers, and the Merced beyond it.
func _leidig_meadow() -> void:
	_begin(64, 36, 1869)
	_wall(6.0, 2.0, 2)
	_ellipse(30.0, 22.0, 18.0, 6.0, Terrain.MEADOW, 0.3)
	_ellipse(22.0, 24.0, 6.0, 2.5, Terrain.WET_MEADOW, 0.3, [Terrain.MEADOW])
	var river := [Vector2(-1, 31), Vector2(16, 30), Vector2(32, 32), Vector2(48, 30), Vector2(65, 31)]
	_water(river, 3)
	_path([Vector2(-1, 14), Vector2(20, 14), Vector2(40, 13), Vector2(65, 14)], 2, Terrain.ROAD)
	_path([Vector2(52, 15), Vector2(50, 22), Vector2(46, 28)], 1, Terrain.TRAIL, 0.6)
	_mark_open()

	start_region("LeidigMeadow", "leidig_meadow", "Leidig Meadow", Vector2(-119.6000, 37.7410))
	paint_ground()
	_save_ground_art("ground_leidig_meadow", 1869)
	_place_wall("three_brothers", 102)
	_info_sign("LeidigSign", foot(28, 15), "Leidig Meadow",
		"Named for the Leidigs, who ran a hotel near here in the 1870s. Across the meadow: the Three Brothers to the north, and Sentinel Rock and Glacier Point to the south.")
	_info_sign("ThreeBrothersSign", foot(12, 15), "Three Brothers",
		"Three peaks stepping up one behind another, the highest Eagle Peak. In 1987 a rockfall here sent a cloud of granite dust across the Valley and closed Northside Drive.")
	_dress(70, 50)
	_river_rocks(river, 6)
	marker("arrival", 30, 14.5)
	marker("east", 61, 14.5)
	marker("west", 2, 14.5)
	marker("meadow", 30, 22)
	marker("river_bank", 46, 28)
	place("Leidig Meadow", 30, 22, 16)
	place("Three Brothers", 30, 2, 0)
	region_exit("ToVillage", tile_pos(63.5, 14.5), Vector2(12, 48), "Yosemite Village and Camp 4", "yosemite_village", "west_road")
	region_exit("ToElCapitan", tile_pos(-0.5, 14.5), Vector2(12, 48), "El Capitan Meadow", "el_capitan_meadow", "east")
	_finish("leidig_meadow", 2.0)


# ================================================================ Four Mile Trailhead

## Southside Drive west of the Village, under Sentinel Rock: the foot of the
## Four Mile Trail up to Glacier Point, Sentinel Beach on the Merced, and
## Sentinel Fall in its gully in spring.
func _four_mile_trailhead() -> void:
	_begin(64, 36, 1872)
	_wall(8.0, 2.0, 2)
	var fall_x := 14
	for y in range(0, 9):
		put(fall_x, y, Terrain.FALLS)
	var river := [Vector2(-1, 31), Vector2(20, 32), Vector2(40, 30), Vector2(65, 31)]
	_water(river, 3)
	_path([Vector2(-1, 22), Vector2(20, 22), Vector2(44, 21), Vector2(65, 22)], 2, Terrain.ROAD)
	# The trailhead's pullout and the trail up to the foot of the wall.
	fill(26, 18, 34, 20, Terrain.PARKING)
	_path([Vector2(30, 18), Vector2(30, 14), Vector2(32, _foot_of_wall(32))], 1, Terrain.TRAIL, 0.4)
	_path([Vector2(48, 21), Vector2(46, _foot_of_wall(46))], 1, Terrain.TRAIL, 0.4)
	# Sentinel Beach: a sandy bar with picnic tables.
	_ellipse(50.0, 28.0, 6.0, 2.0, Terrain.SAND)
	_path([Vector2(50, 23), Vector2(50, 27)], 1, Terrain.TRAIL)
	_ellipse(14.0, 26.0, 9.0, 3.0, Terrain.MEADOW, 0.3)
	_mark_open()

	start_region("FourMileTrailhead", "four_mile_trailhead", "Four Mile Trailhead", Vector2(-119.6030, 37.7330))
	paint_ground()
	_save_ground_art("ground_four_mile_trailhead", 1872)
	_place_wall("sentinel", 103, fall_x * T + T / 2, 9, "SentinelFall")
	_trail_door("FourMileTrail", foot(32, _foot_of_wall(32)), "Four Mile Trail, up to Glacier Point", "glacier_point", "four_mile_trailhead", 180)
	_info_sign("FourMileSign", foot(28, 18), "Four Mile Trail",
		"Up to Glacier Point in switchbacks along the wall, past Union Point: 4.8 miles and 3,200 feet of climbing. The toll trail built in 1872 was four miles, and the name stuck.")
	_info_sign("SentinelRockSign", foot(44, 20), "Sentinel Rock",
		"A granite obelisk 3,000 feet above the Valley. The Steck-Salathe route climbs its north face, a classic of 1950, up the Narrows and the Flying Buttress.")
	_info_sign("SentinelFallSign", foot(16, 21), "Sentinel Fall",
		"Sentinel Creek drops nearly 2,000 feet in steps beside Sentinel Rock. It runs in spring and is gone by midsummer.")
	for t: Array in [[47, 28], [53, 28]]:
		decor("PicnicTable%d" % t[0], B + "camp4_table.png", foot(t[0], t[1]), Vector2(30, 8))
	_dress(40, 60)
	_river_rocks(river, 5)
	marker("arrival", 36, 22.5)
	marker("east", 61, 22.5)
	marker("west", 2, 22.5)
	marker("trailhead", 30, 19)
	marker("steck_salathe", 46, _foot_of_wall(46))
	marker("beach", 50, 27)
	place("Four Mile Trailhead", 30, 18, 8)
	place("Sentinel Beach", 50, 28, 7)
	place("Sentinel Rock", 46, 2, 0)
	region_exit("ToVillage", tile_pos(63.5, 22.5), Vector2(12, 48), "Yosemite Village", "yosemite_village", "southside_west")
	region_exit("ToBridalveil", tile_pos(-0.5, 22.5), Vector2(12, 48), "Bridalveil Fall", "bridalveil_fall", "east")
	_finish("four_mile_trailhead", 2.0)


# ================================================================ Bridalveil Fall

## Southside Drive under Cathedral Rocks, with Bridalveil Fall blowing
## sideways down its gully and the creek running down to the Merced.
func _bridalveil_fall() -> void:
	_begin(64, 36, 1851)
	_wall(9.0, 2.0, 2)
	var fall_x := 22
	for y in range(0, 10):
		put(fall_x, y, Terrain.FALLS)
	var creek := [Vector2(fall_x, 10), Vector2(fall_x + 1, 16), Vector2(fall_x - 1, 24), Vector2(fall_x + 2, 31)]
	_water(creek, 2, Terrain.CREEK, 0.3)
	var river := [Vector2(-1, 32), Vector2(20, 32), Vector2(44, 31), Vector2(65, 33)]
	_water(river, 3)
	_path([Vector2(-1, 21), Vector2(18, 21), Vector2(40, 22), Vector2(65, 21)], 2, Terrain.ROAD)
	_bridge(fall_x - 1, 20, 23, 4)
	fill(28, 17, 36, 19, Terrain.PARKING)
	_path([Vector2(29, 17), Vector2(26, 13), Vector2(fall_x + 2, 11)], 1, Terrain.TRAIL, 0.5)
	_path([Vector2(48, 20), Vector2(50, _foot_of_wall(50))], 1, Terrain.TRAIL, 0.4)
	_mark_open()

	start_region("BridalveilFall", "bridalveil_fall", "Bridalveil Fall", Vector2(-119.6490, 37.7170))
	paint_ground()
	_save_ground_art("ground_bridalveil_fall", 1851)
	_place_wall("cathedral", 104, fall_x * T + T / 2, 10, "BridalveilFall")
	_info_sign("BridalveilSign", foot(27, 13), "Bridalveil Fall",
		"Bridalveil Fall drops 620 feet and flows all year. On windy days its spray blows sideways across the cliff. The Ahwahneechee called it Pohono.")
	_info_sign("CathedralSign", foot(46, 20), "Cathedral Rocks",
		"Three buttresses stepping up the south wall, with Higher and Lower Cathedral Spires standing free beside them. The Higher Spire was first climbed in 1934 by the Sierra Club's first rock climbers.")
	_dress(30, 70)
	_river_rocks(river, 5)
	marker("arrival", 36, 21.5)
	marker("east", 61, 21.5)
	marker("west", 2, 21.5)
	marker("fall_base", fall_x + 2, 12)
	marker("cathedral_spire", 50, _foot_of_wall(50))
	place("Bridalveil Fall", fall_x, 14, 9)
	place("Cathedral Rocks", 46, 3, 0)
	region_exit("ToFourMile", tile_pos(63.5, 21.5), Vector2(12, 48), "Southside Drive east", "four_mile_trailhead", "west")
	region_exit("ToTunnelView", tile_pos(-0.5, 21.5), Vector2(12, 48), "Wawona Road, up to Tunnel View", "tunnel_view", "east")
	_finish("bridalveil_fall", 2.0)


# ================================================================ Tunnel View

const TV_W := 64
const TV_H := 44
## The Valley floor below the view, in tiles (see GlacierArt.view_below):
## the Merced winding up the Valley through its meadows.
const TV_VIEW := {
	"rivers": [[Vector2(22, 19), Vector2(26, 14), Vector2(30, 10), Vector2(33, 6), Vector2(36, 2), Vector2(38, 0)]],
	"meadows": [Rect2(22, 11, 8, 4), Rect2(29, 5, 6, 3)],
}
## The walls standing up out of it, as GlacierArt._dome arguments: foot (in
## tiles), half width and height (pixels at 16px), and lean. El Capitan's
## great face on the left, Cathedral Rocks on the right, and Half Dome small
## and far away up the Valley between them, its sheer face to the left.
const TV_DOMES := [
	[Vector2(8, 19), 170.0, 210.0, 0.45],
	[Vector2(53, 19), 110.0, 190.0, -0.35],
	[Vector2(35, 7), 26.0, 42.0, -0.9],
]

var _tv_drop := PackedByteArray()


func _tv_is_drop(x: int, y: int) -> bool:
	return _tv_drop[clampi(y, 0, TV_H - 1) * TV_W + clampi(x, 0, TV_W - 1)] == 1


## The overlook at the east portal of the Wawona Tunnel: the Valley below to
## the north, the stone wall and the lot, and the tunnel through the ridge.
func _tunnel_view() -> void:
	_begin(TV_W, TV_H, 1933)
	_tv_drop.resize(TV_W * TV_H)
	for x in TV_W:
		var rim := 19 + int(noise.get_noise_1d(x * 2.0) * 2.0)
		for y in rim:
			_tv_drop[y * TV_W + x] = 1
			put(x, y, Terrain.CLIFF)
	# The ridge the tunnel runs through, along the bottom.
	for x in TV_W:
		var top := TV_H - 6 + int(noise.get_noise_1d(x * 3.0 + 90.0) * 1.5)
		fill(x, top, x, TV_H - 1, Terrain.TALUS)
	# Chaparral on the slopes either side, the lot in the middle.
	_ellipse(8.0, 28.0, 9.0, 7.0, Terrain.SCRUB, 0.4)
	_ellipse(56.0, 29.0, 9.0, 7.0, Terrain.SCRUB, 0.4)
	fill(20, 22, 46, 30, Terrain.PARKING)
	fill(22, 20, 44, 21, Terrain.PAVED)
	# Wawona Road: in from the east, past the lot, into the tunnel to the
	# southwest.
	_path([Vector2(65, 32), Vector2(50, 32), Vector2(30, 33), Vector2(14, 34), Vector2(6, 37), Vector2(4, TV_H - 6)], 2, Terrain.ROAD)
	for y in range(TV_H - 7, TV_H):
		fill(3, y, 6, y, Terrain.ROAD)
	_path([Vector2(54, 31), Vector2(58, _foot_of_talus(58))], 1, Terrain.TRAIL, 0.4)
	_mark_open()

	start_region("TunnelView", "tunnel_view", "Tunnel View", Vector2(-119.6772, 37.7156))
	paint_ground()
	_save_ground_art("ground_tunnel_view", 1933)
	var view := GlacierArt.new()
	var im := view.view_below(_tv_drop, TV_W, TV_H, TV_VIEW)
	for i in TV_DOMES.size():
		var d: Array = TV_DOMES[i]
		view._dome(im, _tv_drop, TV_W, (d[0] as Vector2) * T, d[1], d[2], d[3], 1933 + i)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(V))
	im.save_png(ProjectSettings.globalize_path(V + "tunnel_view_below.png"))
	import_assets()
	_backdrop("tunnel_view_below", Vector2.ZERO, -8, V)
	# Bridalveil Fall on Cathedral Rocks, across the view.
	var size: Vector2i = GlacierArt.FALLS["gp_illilouette"]
	var top := Vector2(47.0, 12.5) * T
	_animation("BridalveilFall", "gp_illilouette", 6.0, top - Vector2(size.x / 2.0, 0), -7, G)
	# The stone wall along the edge.
	for y in range(15, 23):
		for x in range(20, 47):
			if _tv_is_drop(x, y):
				continue
			if _tv_is_drop(x, y - 1):
				decor("RimWall%d_%d" % [x, y], G + "rim_wall_h.png", Vector2(x * T + T / 2.0, y * T + 5), Vector2(16, 4))
	_info_sign("TunnelViewSign", foot(33, 21), "Tunnel View",
		"This view opened with the Wawona Tunnel in 1933. El Capitan stands on the left, Bridalveil Fall on the right, and Half Dome in the distance.")
	_info_sign("WawonaTunnelSign", foot(10, 35), "Wawona Tunnel",
		"Four-fifths of a mile through the granite of Turtleback Dome, the longest highway tunnel in California when it opened in 1933.")
	instance_scene("res://scenes/objects/travel_point.tscn", foot(24, 29), "Travel_TunnelViewParking").set("label", "Tunnel View Parking")
	var cars := [[22, 25], [26, 25], [30, 25], [38, 25], [42, 25], [28, 29], [40, 29]]
	for i in cars.size():
		var car: Array = cars[i]
		decor("Car%d_%d" % [car[0], car[1]], C + "car_%d.png" % ((i * 5 + 3) % 12), foot(car[0], car[1]), Vector2(24, 12))
	_dress(10, 30)
	_scatter_decor("plant_manzanita", [Terrain.SCRUB], 30, Rect2i(0, 0, TV_W, TV_H), 1)
	marker("arrival", 34, 27)
	marker("east", 61, 32.5)
	marker("overlook", 33, 21)
	marker("separate_reality", 58, _foot_of_talus(58))
	place("Tunnel View", 33, 24, 14)
	place("El Capitan", 14, 9, 0)
	place("Half Dome", 31, 3, 0)
	place("Bridalveil Fall", 48, 12, 0)
	region_exit("ToBridalveil", tile_pos(64.5, 32.5), Vector2(12, 48), "Wawona Road, down to the Valley", "bridalveil_fall", "west")
	_drive_exit("WawonaTunnel", tile_pos(4.5, TV_H - 0.5), Vector2(64, 12), "Wawona Tunnel: Wawona Road and Glacier Point Road", "wawona")
	_finish("tunnel_view", 1.5)


## The first walkable row above the talus along the bottom, at column x.
func _foot_of_talus(x: int) -> int:
	var y := h - 1
	while y > 0 and at(x, y) == Terrain.TALUS:
		y -= 1
	return y


# ================================================================ Ahwahnee Meadow

## Northside Drive east of the Village, across Ahwahnee Meadow with its big
## black oaks (they drop acorns), under the Royal Arches side of the Valley.
func _ahwahnee_meadow() -> void:
	_begin(64, 36, 1927)
	_wall(6.0, 2.0, 2)
	_ellipse(34.0, 25.0, 20.0, 7.0, Terrain.MEADOW, 0.3)
	_ellipse(42.0, 27.0, 6.0, 2.5, Terrain.WET_MEADOW, 0.3, [Terrain.MEADOW])
	_path([Vector2(-1, 15), Vector2(20, 15), Vector2(44, 14), Vector2(65, 15)], 2, Terrain.ROAD)
	_path([Vector2(-1, 33), Vector2(30, 33), Vector2(65, 32)], 1, Terrain.TRAIL, 0.6)
	_path([Vector2(22, 16), Vector2(26, 24), Vector2(30, 33)], 1, Terrain.TRAIL, 0.6)
	_mark_open()
	# Room under the oaks.
	for o: Vector2i in [Vector2i(14, 24), Vector2i(20, 30), Vector2i(52, 22), Vector2i(56, 29)]:
		clear_trees(o.x - 3, o.y - 3, o.x + 3, o.y + 1)

	start_region("AhwahneeMeadow", "ahwahnee_meadow", "Ahwahnee Meadow", Vector2(-119.5790, 37.7470))
	paint_ground()
	_save_ground_art("ground_ahwahnee_meadow", 1927)
	_place_wall("royal_arches", 105)
	var oaks := [Vector2i(14, 24), Vector2i(20, 30), Vector2i(52, 22), Vector2i(56, 29)]
	for i in oaks.size():
		instance_scene("res://scenes/objects/black_oak.tscn", foot(oaks[i].x, oaks[i].y), "BlackOak%d" % (i + 1))
	_info_sign("AhwahneeMeadowSign", foot(30, 16), "Ahwahnee Meadow",
		"The Ahwahneechee lived in villages along the Valley's meadows, gathering acorns from the black oaks. Park staff now burn the meadows now and then, as they did, to keep the conifers from taking over.")
	_info_sign("BlackOakSign", foot(18, 27), "California Black Oak",
		"The oaks drop their acorns in fall. Ground and leached in running water, they were the Valley's main food.")
	_dress(70, 50)
	marker("arrival", 30, 15.5)
	marker("west", 2, 15.5)
	marker("east", 61, 15.5)
	marker("meadow", 34, 25)
	marker("oaks", 18, 27)
	place("Ahwahnee Meadow", 34, 25, 18)
	place("Royal Arches", 34, 2, 0)
	region_exit("ToVillage", tile_pos(-0.5, 15.5), Vector2(12, 48), "Yosemite Village", "yosemite_village", "east_road")
	region_exit("ToAhwahnee", tile_pos(63.5, 15.5), Vector2(12, 48), "The Ahwahnee", "the_ahwahnee", "west_road")
	_finish("ahwahnee_meadow", 2.0)


# ================================================================ Housekeeping Camp

## Southside Drive east of the Village: Housekeeping Camp's canvas-roofed
## cabins on the Merced, and its beach.
func _housekeeping_camp() -> void:
	_begin(64, 36, 1926)
	_wall(4.0, 1.5, 2)
	_path([Vector2(-1, 14), Vector2(20, 14), Vector2(44, 15), Vector2(65, 14)], 2, Terrain.ROAD)
	fill(10, 18, 46, 27, Terrain.CAMP)
	var river := [Vector2(-1, 31), Vector2(20, 31), Vector2(40, 30), Vector2(65, 32)]
	_water(river, 3, Terrain.RIVER, 0.9)
	_path([Vector2(28, 16), Vector2(28, 18)], 2, Terrain.TRAIL)
	_mark_open()

	start_region("HousekeepingCamp", "housekeeping_camp", "Housekeeping Camp", Vector2(-119.5800, 37.7420))
	paint_ground()
	_save_ground_art("ground_housekeeping_camp", 1926)
	_place_wall("housekeeping", 106)
	var n := 0
	for row: int in [21, 26]:
		for col in range(12, 46, 6):
			_tent_cabin(col + (2 if row == 26 else 0), row, (n * 11 + 4) % 64)
			n += 1
	for b: Array in [[16, 23], [28, 23], [40, 23]]:
		decor("BearBox%d" % b[0], B + "bear_box.png", foot(b[0], b[1]), Vector2(14, 6))
	_info_sign("HousekeepingSign", foot(26, 16), "Housekeeping Camp",
		"Canvas-roofed cabins with concrete walls on the bank of the Merced, rented since the 1920s for campers who brought their own bedding and cooked for themselves.")
	_dress(20, 50)
	_river_rocks(river, 6)
	marker("arrival", 30, 14.5)
	marker("west", 2, 14.5)
	marker("east", 61, 14.5)
	marker("camp", 28, 19)
	marker("beach", 34, 29)
	place("Housekeeping Camp", 28, 22, 14)
	region_exit("ToVillage", tile_pos(-0.5, 14.5), Vector2(12, 48), "Yosemite Village", "yosemite_village", "southside_east")
	region_exit("ToCurry", tile_pos(63.5, 14.5), Vector2(12, 48), "Curry Village", "curry_village", "west_road")
	_finish("housekeeping_camp", 2.0)


# ================================================================ Upper Pines

## The campground between Curry Village and Happy Isles: sites in the pines,
## each with its tent, picnic table and bear box.
func _upper_pines() -> void:
	_begin(64, 36, 1964)
	_wall(5.0, 1.5, 2)
	_path([Vector2(-1, 26), Vector2(20, 27), Vector2(44, 26), Vector2(65, 27)], 2, Terrain.ROAD)
	var river := [Vector2(-1, 33), Vector2(30, 33), Vector2(65, 34)]
	_water(river, 2)
	var sites := [[10, 13], [18, 12], [26, 14], [34, 12], [42, 13], [50, 12], [14, 20], [24, 21], [36, 20], [46, 21], [54, 19]]
	for s: Array in sites:
		fill(s[0] - 2, s[1] - 2, s[0] + 3, s[1] + 1, Terrain.CAMP)
	_path([Vector2(8, 26), Vector2(8, 16), Vector2(56, 16), Vector2(56, 26)], 1, Terrain.TRAIL, 0.3)
	_mark_open()

	start_region("UpperPines", "upper_pines", "Upper Pines", Vector2(-119.5650, 37.7350))
	paint_ground()
	_save_ground_art("ground_upper_pines", 1964)
	_place_wall("upper_pines", 107)
	var tents := ["camp4_tent_dome_0", "camp4_tent_canvas", "camp4_tent_dome_1", "camp4_tent_dome_2", "camp4_tent_dome_3", "camp4_tent_dome_0"]
	for i in sites.size():
		var s: Array = sites[i]
		var tent: String = tents[i % tents.size()]
		decor("Tent%d" % i, B + tent + ".png", foot(s[0], s[1] - 1), Vector2(28, 8))
		if _has(tent + "_glow", B):
			var tex := texture(B + tent + ".png")
			_glow(tent + "_glow", foot(s[0], s[1] - 1) - Vector2(tex.get_width() / 2.0, tex.get_height()), 1.0, B)
		decor("Table%d" % i, B + "camp4_table.png", foot(s[0] + 2, s[1] + 1), Vector2(30, 8))
		decor("BearBox%d" % i, B + "bear_box.png", foot(s[0] - 2, s[1] + 1), Vector2(14, 6))
	_info_sign("UpperPinesSign", foot(10, 25), "Upper Pines",
		"The Valley's biggest campground, under ponderosa pines and incense cedars. Keep every scrap of food in the bear box: black bears here know what a cooler looks like.")
	_dress(10, 60)
	marker("arrival", 30, 27.5)
	marker("west", 2, 27.5)
	marker("east", 61, 27.5)
	marker("campground", 30, 17)
	place("Upper Pines", 30, 17, 16)
	region_exit("ToCurry", tile_pos(-0.5, 27.5), Vector2(12, 48), "Curry Village", "curry_village", "east_road")
	region_exit("ToHappyIsles", tile_pos(63.5, 27.5), Vector2(12, 48), "Happy Isles", "happy_isles", "west")
	_finish("upper_pines", 2.0)


# ================================================================ Happy Isles

## Where the Merced comes out of its canyon and splits round two small
## islands, crossed by footbridges; the John Muir Trail and the Mist Trail
## start here, and Half Dome's Snake Dike is far up the wall above.
func _happy_isles() -> void:
	_begin(72, 44, 1915)
	_wall(8.0, 2.0, 3)
	var main := [Vector2(73, 22), Vector2(56, 22), Vector2(40, 24), Vector2(24, 23), Vector2(-1, 25)]
	_water(main, 3)
	var side := [Vector2(56, 24), Vector2(50, 30), Vector2(38, 31), Vector2(26, 29), Vector2(22, 25)]
	_water(side, 2)
	# The isles themselves stay forest; the footbridges cross both channels.
	_bridge(44, 22, 33, 2)
	_bridge(30, 21, 32, 2)
	_path([Vector2(-1, 38), Vector2(20, 38), Vector2(44, 37), Vector2(73, 38)], 2, Terrain.ROAD)
	_path([Vector2(31, 37), Vector2(31, 33)], 1, Terrain.TRAIL)
	_path([Vector2(45, 37), Vector2(45, 34)], 1, Terrain.TRAIL)
	# North of the river: the trailhead, and the trail along the wall.
	_path([Vector2(31, 20), Vector2(36, 15), Vector2(54, 14), Vector2(60, _foot_of_wall(60))], 1, Terrain.TRAIL, 0.5)
	_path([Vector2(45, 20), Vector2(46, 15)], 1, Terrain.TRAIL)
	fill(8, 34, 16, 36, Terrain.PARKING)
	_mark_open()

	start_region("HappyIsles", "happy_isles", "Happy Isles", Vector2(-119.5585, 37.7325))
	paint_ground()
	_save_ground_art("ground_happy_isles", 1915)
	_place_wall("happy_isles", 108)
	_trail_door("MistTrail", foot(56, 13), "Mist Trail and Panorama Trail, up to Glacier Point", "glacier_point", "panorama_trailhead", 300)
	_info_sign("HappyIslesSign", foot(24, 36), "Happy Isles",
		"The John Muir Trail starts here and runs about 211 miles to the summit of Mount Whitney.")
	_info_sign("MistTrailSign", foot(52, 13), "Mist Trail",
		"Up the Merced past Vernal Fall, 600 granite steps wet with spray, and on to the top of Nevada Fall. From there the Panorama Trail runs along the rim to Glacier Point.")
	_info_sign("RockfallSign", foot(38, 16), "The 1996 rockfall",
		"In July 1996 a slab of granite the size of a building broke off the wall above and hit the ground here at over 250 miles an hour. Its air blast flattened a thousand trees.")
	shuttle("ShuttleHappyIsles", "Happy Isles", foot(12, 37))
	_dress(20, 70)
	_river_rocks(main, 10)
	marker("arrival", 20, 37)
	marker("shuttle", 12, 38)
	marker("west", 2, 38.5)
	marker("east", 69, 38.5)
	marker("panorama", 54, 14)
	marker("isles", 38, 27)
	marker("snake_dike", 60, _foot_of_wall(60))
	place("Happy Isles", 36, 27, 16)
	place("Half Dome", 50, 3, 0)
	region_exit("ToUpperPines", tile_pos(-0.5, 38.5), Vector2(12, 48), "Upper Pines and Curry Village", "upper_pines", "east")
	region_exit("ToTenayaCreek", tile_pos(71.5, 38.5), Vector2(12, 48), "Tenaya Creek, to Mirror Lake", "tenaya_creek", "west")
	_finish("happy_isles", 2.0)


# ================================================================ Tenaya Creek

## The road and trail up Tenaya Creek from Happy Isles to Mirror Lake,
## through the oaks and boulders under the Half Dome side of the canyon.
func _tenaya_creek() -> void:
	_begin(64, 36, 1851 + 3)
	_wall(5.0, 2.0, 3)
	var creek := [Vector2(-1, 30), Vector2(16, 29), Vector2(32, 31), Vector2(48, 29), Vector2(65, 30)]
	_water(creek, 2, Terrain.CREEK, 0.4)
	_path([Vector2(-1, 22), Vector2(22, 21), Vector2(42, 22), Vector2(65, 21)], 2, Terrain.ROAD)
	_ellipse(30.0, 26.0, 8.0, 2.5, Terrain.MEADOW, 0.3)
	_mark_open()

	start_region("TenayaCreek", "tenaya_creek", "Tenaya Creek", Vector2(-119.5580, 37.7400))
	paint_ground()
	_save_ground_art("ground_tenaya_creek", 1854)
	_place_wall("tenaya", 109)
	_info_sign("TenayaCreekSign", foot(26, 20), "Tenaya Creek",
		"Tenaya Creek comes down Tenaya Canyon from Tenaya Lake, named for the Ahwahneechee leader Tenaya. It runs between Half Dome and Washington Column.")
	_dress(30, 80)
	_scatter_decor("rock_granite", [Terrain.FOREST], 14, Rect2i(0, 6, 64, 30), 1)
	marker("arrival", 30, 22)
	marker("west", 2, 22.5)
	marker("east", 61, 21.5)
	marker("creek", 30, 27)
	place("Tenaya Creek", 30, 25, 14)
	region_exit("ToHappyIsles", tile_pos(-0.5, 22.5), Vector2(12, 48), "Happy Isles", "happy_isles", "east")
	region_exit("ToMirrorLake", tile_pos(63.5, 21.5), Vector2(12, 48), "Mirror Lake", "mirror_lake", "west")
	_finish("tenaya_creek", 2.0)


# ================================================================ Mirror Lake

## Tenaya Creek's shallow lake under Half Dome and Mount Watkins, filling
## in with sand; a meadow by midsummer. Washington Column (Astroman) is on
## the wall.
func _mirror_lake() -> void:
	_begin(72, 44, 1880)
	_wall(10.0, 2.0, 3)
	_ellipse(38.0, 25.0, 15.0, 6.0, Terrain.WET_MEADOW, 0.25)
	_ellipse(38.0, 24.0, 12.0, 4.5, Terrain.LAKE, 0.2)
	_water([Vector2(73, 22), Vector2(56, 23), Vector2(50, 24)], 2, Terrain.CREEK, 0.3)
	_water([Vector2(26, 26), Vector2(18, 32), Vector2(10, 38), Vector2(-1, 40)], 2, Terrain.CREEK, 0.3)
	_ellipse(38.0, 31.0, 14.0, 2.0, Terrain.SAND, 0.3)
	_path([Vector2(-1, 37), Vector2(16, 36), Vector2(24, 33), Vector2(52, 32), Vector2(60, 26), Vector2(62, 18)], 2, Terrain.TRAIL, 0.4)
	_path([Vector2(14, 34), Vector2(12, _foot_of_wall(12))], 1, Terrain.TRAIL, 0.4)
	_bridge(14, 33, 38, 2)
	_mark_open()

	start_region("MirrorLake", "mirror_lake", "Mirror Lake", Vector2(-119.5480, 37.7460))
	paint_ground()
	_save_ground_art("ground_mirror_lake", 1880)
	_place_wall("mirror_lake", 110)
	_info_sign("MirrorLakeSign", foot(30, 33), "Mirror Lake",
		"Tenaya Creek forms this seasonal lake below Half Dome. It is slowly filling with sand and gravel, and by late summer it is often a meadow.")
	_info_sign("WashingtonColumnSign", foot(16, 33), "Washington Column",
		"The granite pillar beside the Royal Arches. Astroman climbs its east face: when John Bachar, Ron Kauk and John Long freed it in 1975, it was the hardest long free climb in the world.")
	shuttle("ShuttleMirrorLake", "Mirror Lake Trailhead", foot(6, 36))
	_dress(30, 60)
	marker("arrival", 10, 37)
	marker("shuttle", 6, 37)
	marker("west", 2, 37.5)
	marker("lakeshore", 38, 31)
	marker("astroman", 12, _foot_of_wall(12))
	place("Mirror Lake", 38, 25, 14)
	place("Half Dome", 50, 3, 0)
	region_exit("ToTenayaCreek", tile_pos(-0.5, 37.5), Vector2(12, 48), "Tenaya Creek, to Happy Isles", "tenaya_creek", "east")
	_finish("mirror_lake", 2.0)
