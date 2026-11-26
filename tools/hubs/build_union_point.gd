extends "res://tools/hubs/build_glacier_point.gd"
## Builds the upper Four Mile Trail and Union Point, west of Glacier Point on
## the south rim, in Glacier Point's look (its rim trees, smooth granite and
## red fir duff, and its painted view over the drop). Run
## tools/hubs/rebuild_rim_country.sh, which runs this:
##
##   godot --headless --path . res://tools/hubs/build_union_point.tscn
##
## and then moves the scene and the art onto the game's 32px grid. It writes
## scenes/regions/union_point.tscn, assets/sprites/glacier/union_point_view.png
## and the painted ground assets/sprites/ahwahnee/ground_union_point.png.
##
## The map is joined to Glacier Point at its east edge: the Four Mile Trail
## walks straight across from Glacier Point's west edge (row 19 there is row
## EAST_ROW here), no fade. Its rim lines up with Glacier Point's (first land
## row 16 at Glacier Point's x=0, so RIM ends at 16 + ROW_SHIFT).
##
## West from Glacier Point the trail follows the rim through red fir past
## Union Point, a granite knob that juts out over the Valley with Yosemite
## Falls straight across. Then it goes over the edge into the switchbacks:
## a steep slope of scree, manzanita and old Jeffrey pines that the trail
## zigzags down, to the lower switchbacks door at the top left, which goes on
## down to the Four Mile trailhead by Sentinel Beach.

const UW := 100
const UH := 40
const USCENE := "res://scenes/regions/union_point.tscn"
const UGEO := Vector2(-119.5880, 37.7300)
## Glacier Point row = this map's row + ROW_SHIFT, along the shared edge.
const ROW_SHIFT := -18
## The Four Mile Trail's row on this map's east edge (Glacier Point row 19).
const EAST_ROW := 37

## [x, first land row]: north of it the map drops away.
const RIM := [[0, 4], [26, 4], [34, 6], [40, 13], [46, 15], [51, 11], [54, 7], [57, 5], [60, 6],
	[63, 10], [66, 18], [72, 24], [80, 29], [88, 32], [94, 33], [UW, 34]]

## The trail: along the rim from Glacier Point, past the Union Point spur,
## and down the switchbacks.
const TRAIL := [Vector2(99, 37), Vector2(90, 36), Vector2(80, 33), Vector2(72, 29), Vector2(65, 24),
	Vector2(58, 21), Vector2(50, 21), Vector2(42, 20), Vector2(36, 22)]
const SWITCHBACKS := [Vector2(36, 22), Vector2(14, 21), Vector2(30, 16), Vector2(10, 14), Vector2(26, 10),
	Vector2(10, 7), Vector2(8, 5)]
const UNION_SPUR := [Vector2(58, 21), Vector2(57, 15), Vector2(57, 9)]


func _ready() -> void:
	w = UW
	h = UH
	print("== Union Point")
	load_flora()
	import_assets()
	_build_union_point()
	print("Done")
	get_tree().quit()


func _u_drop(x: int, y: int) -> bool:
	if x < 0 or x >= UW:
		return false
	return drop[clampi(y, 0, UH - 1) * UW + x] == 1


func _union_layout() -> void:
	init_grid(UW, UH, Terrain.FIR)
	rng.seed = 1872
	noise.seed = 1872
	noise.frequency = 0.09
	drop.resize(UW * UH)
	drop.fill(0)
	for y in UH:
		for x in UW:
			# Keep the last columns exactly on Glacier Point's rim so the seam meets.
			var wobble := 0.0 if x >= UW - 3 else noise.get_noise_1d(x * 4.0) * 0.8
			if y < _rim(RIM, x) + wobble:
				drop[y * UW + x] = 1
				put(x, y, Terrain.CLIFF)

	# The switchbacks: a steep slope of scree and scrub under the rim, with
	# granite ribs, the firs thinning out on it.
	for y in UH:
		for x in UW:
			if _u_drop(x, y):
				continue
			var slope := x < 40 and y < 27 + noise.get_noise_1d(x * 3.0 + 40.0) * 2.0
			if slope:
				put(x, y, Terrain.SCRUB)
				continue
			var near := 0
			for r in range(1, 5):
				if _u_drop(x - r, y) or _u_drop(x + r, y) or _u_drop(x, y - r):
					near = r
					break
			if near > 0 and near + noise.get_noise_2d(x * 2.0, y * 2.0) * 3.0 < 3.5:
				put(x, y, Terrain.SCRUB)
	for rib: Array in [[20, 18, 4, 2], [6, 10, 3, 2], [30, 8, 3, 2], [18, 25, 3, 1]]:
		_ellipse(rib[0], rib[1], rib[2], rib[3], Terrain.GRANITE, 0.35, [Terrain.SCRUB])
	# Union Point: a granite knob over the Valley, and slabs in the forest.
	_ellipse(57, 9, 5, 5, Terrain.GRANITE, 0.2, [Terrain.FIR, Terrain.SCRUB])
	for slab: Array in [[78, 36, 3, 2], [68, 33, 2, 2], [46, 30, 3, 2], [86, 38, 2, 1]]:
		_ellipse(slab[0], slab[1], slab[2], slab[3], Terrain.GRANITE, 0.4, [Terrain.FIR, Terrain.SCRUB])
	# A spring seep in the firs below Union Point.
	_ellipse(50, 30, 3, 2, Terrain.WET_MEADOW, 0.3, [Terrain.FIR])
	_ellipse(51, 31, 4, 3, Terrain.MEADOW, 0.3, [Terrain.FIR])

	_path(TRAIL, 1, Terrain.TRAIL, 0.3)
	_path(SWITCHBACKS, 1, Terrain.TRAIL, 0.25)
	_path(UNION_SPUR, 1, Terrain.TRAIL, 0.2)
	# The trail runs straight off the east edge on Glacier Point's row.
	fill(UW - 4, EAST_ROW, UW - 1, EAST_ROW, Terrain.TRAIL)

	for k in UW * UH:
		if drop[k]:
			kind[k] = Terrain.CLIFF
	for k in UW * UH:
		if kind[k] in [Terrain.TRAIL, Terrain.CREEK, Terrain.CLIFF]:
			no_trees[k] = 1
	clear_trees(52, 3, 62, 14) # Union Point
	clear_trees(UW - 6, EAST_ROW - 2, UW - 1, EAST_ROW + 2) # the seam
	clear_trees(5, 3, 12, 7) # the lower switchbacks door


func _build_union_point() -> void:
	_union_layout()
	start_region("UnionPoint", "union_point", "Four Mile Trail", UGEO)
	_root.hub_id = "glacier_point"
	paint_ground()
	_save_ground_art("ground_union_point", 1872)
	_place_union_view()
	_place_union_point()
	_place_union_trails()
	_place_union_markers()
	_dress_union()
	place_blockers()
	add_forage("union_point", 1.5)
	for child in _root.get_children():
		_own(child, _root)
	pack(_root, USCENE)


## The drop shows the left of Glacier Point's painting (Yosemite Falls, the
## Village and the Merced), held still across the screen (no sideways
## parallax), lined up with Glacier Point's at the shared edge: Glacier
## Point's painting starts at its pixel 4 at its own west edge.
func _place_union_view() -> void:
	var im := GlacierArt.new().view_below(drop, UW, UH)
	im.save_png(ProjectSettings.globalize_path(G + "union_point_view.png"))
	import_assets()
	var falls := []
	for f: Array in GlacierVistaArt.VISTA_FALLS:
		falls.append([f[0] * 2.0, f[1] * 2.0, f[2] * 2.0])
	# The camera's top-left when the camera's at the east edge, on the rim.
	var anchor := Vector2((UW * T) - 480.0, -ROW_SHIFT * T)
	_vista(_backdrop("union_point_view", Vector2.ZERO, -8, G), G + "vista.png", anchor, Vector2(4, 0), Vector2(0.0, 0.05), falls)


## Railing round the tip of Union Point, like Glacier Point's.
func _union_rail(x0: int, y0: int, x1: int, y1: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if _u_drop(x, y):
				continue
			if _u_drop(x, y - 1):
				decor("RimWall%d_%d" % [x, y], G + "rim_wall_h.png", Vector2(x * T + T / 2.0, y * T + 5), Vector2(16, 4))
			if _u_drop(x + 1, y):
				decor("RimWallE%d_%d" % [x, y], G + "rim_wall_v.png", Vector2(x * T + T - 3, (y + 1) * T), Vector2(6, 14))
			elif _u_drop(x - 1, y):
				decor("RimWallW%d_%d" % [x, y], G + "rim_wall_v.png", Vector2(x * T + 3, (y + 1) * T), Vector2(6, 14))


func _place_union_point() -> void:
	_union_rail(53, 4, 61, 9)
	var viewer := decor("UnionPointViewer", G + "viewer.png", foot(57, 7), Vector2(6, 4))
	viewer.set_script(load("res://scripts/objects/scenic_viewer.gd"))
	viewer.set("view", "union_point")
	viewer.set("facing", 0.0)
	_hitbox(viewer, Vector2(14, 22))
	_info_sign("UnionPointSign", foot(59, 10), "Union Point",
		"6,316 feet, a knob of granite on the Four Mile Trail with the Valley floor 2,300 feet below. Yosemite Falls is straight across, all three drops of it, and Sentinel Rock stands just to the west.")
	_info_sign("FourMileHistorySign", foot(70, 30), "The Four Mile Trail",
		"James McCauley and John Conway built it as a toll trail in 1871 and 1872: a dollar to ride up to Glacier Point. McCauley kept it, and later his Mountain House at the top.")
	_info_sign("SwitchbacksSign", foot(37, 23), "The switchbacks",
		"From here the trail goes over the rim and zigzags down the face. Mind the loose scree, and give way to hikers coming up: it's 3,200 feet from the Valley.")
	decor("TrailPost", G + "trail_post.png", foot(96, 36), Vector2(4, 3))
	decor("SentinelJeffrey", G + "sentinel_jeffrey.png", foot(30, 12), Vector2(60, 6))
	for b: Array in [[24, 18], [12, 12], [32, 6], [55, 13], [61, 12], [76, 34], [44, 27], [16, 23]]:
		_prop(_pick("rock_granite"), foot(b[0], b[1]))


func _place_union_trails() -> void:
	# Straight across into Glacier Point, along its Four Mile Trail.
	region_exit("FourMileTrailEast", tile_pos(UW - 1, EAST_ROW), Vector2(12, 48), "Glacier Point",
		"glacier_point", "four_mile_trailhead")
	# Down the lower switchbacks to the Valley. The trail shuts in winter
	# from the bottom; from up here you can always walk down.
	_trail_door("FourMileTrailDown", foot(8, 5), "Four Mile Trail, down the switchbacks to Sentinel Beach",
		"four_mile_trailhead", "four_mile_trail", 45)


func _place_union_markers() -> void:
	marker("arrival", 92, 36)
	marker("east", 96, EAST_ROW)
	marker("union_point", 57, 11)
	marker("switchbacks", 30, 17)
	marker("switchbacks_top", 9, 7)
	marker("seep", 50, 31)
	place("Union Point", 57, 9, 6)
	place("Four Mile switchbacks", 22, 14, 10)
	for label: Array in [["Yosemite Falls", 57, 0], ["Sentinel Rock", 40, 2]]:
		var p := Marker2D.new()
		p.set_script(load("res://scripts/world/place.gd"))
		p.name = (label[0] as String).replace(" ", "")
		p.position = tile_pos(label[1], label[2])
		p.set("display_name", label[0])
		p.set("radius", 0.0)
		p.set("show_banner", false)
		p.set("show_on_map", true)
		_places.add_child(p)


func _dress_union() -> void:
	_reserve_entities(1, 3)
	_fringe_trees([Terrain.FIR], 3, 0.72, [["gp_red_fir", 5.0], ["gp_jeffrey", 2.5], ["gp_lodgepole", 1.0], ["gp_snag", 0.4], ["tree_white_fir", 1.0]], 1, 22.0)
	_fringe_trees([Terrain.SCRUB], 5, 0.35, [["gp_jeffrey", 2.0], ["gp_snag", 0.6]], 1, 30.0)
	_fringe_trees([Terrain.GRANITE], 7, 0.25, [["gp_jeffrey", 1.0]], 1, 40.0)
	var all := Rect2i(0, 0, UW, UH)
	_scatter_decor("plant_manzanita", [Terrain.SCRUB], 60, all, 1)
	_scatter_decor("plant_shrub", [Terrain.SCRUB, Terrain.FIR], 30, all, 1)
	_scatter_decor("rock_granite", [Terrain.GRANITE, Terrain.SCRUB], 50, all, 1)
	_scatter_decor("log_fallen", [Terrain.FIR], 8, all, 2)
	_scatter_decor("log_stump", [Terrain.FIR], 4, all, 1)
	_scatter_decor("plant_wildflowers", [Terrain.MEADOW, Terrain.SCRUB], 14, all, 1)
	_scatter_decor("plant_cornlily", [Terrain.MEADOW, Terrain.WET_MEADOW], 6, all, 0)
	_scatter_decor("plant_fern", [Terrain.WET_MEADOW], 5, all, 0)
