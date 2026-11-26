extends "res://tools/hubs/build_valley_floor.gd"
## Builds Illilouette Gorge, a stop on the Panorama Trail between Glacier
## Point and the top of Nevada Fall, in the Glacier Point look (red fir and
## Jeffrey pine on duff, smooth granite). Run tools/hubs/rebuild_rim_country.sh, which runs
##
##   godot --headless --path . res://tools/hubs/build_illilouette.tscn
##
## and moves it onto the 32px grid. It rewrites scenes/regions/illilouette.tscn,
## its painted ground assets/sprites/ahwahnee/ground_illilouette.png, and the
## drop, assets/sprites/glacier/illilouette_view.png, which shows the right of
## Glacier Point's painting (Half Dome, Liberty Cap and the falls of the
## Merced). Its north edge meets Glacier Point's south edge: the Panorama
## Trail walks straight across (Glacier Point's column 88 is NORTH_COL here)
## with no fade, and east of the trail the rim drops away on both sides. Put story NPCs in
## scenes/story/content/illilouette.tscn (placed by Marker name), not in the
## region scene, so a rebuild keeps them.
##
## The real trail, squeezed so it can be walked. The Panorama Trail comes in
## at the top (north) edge from Glacier Point and switchbacks down through
## red fir and Jeffrey pine to a granite lip above Illilouette Fall, which
## drops into its gorge to the north-east. Below the fall the trail follows
## Illilouette Creek downstream, crosses it on a footbridge, and climbs the
## far side to Panorama Point, a granite shoulder with Half Dome across the
## canyon. It runs on east to the top of Nevada Fall, with Liberty Cap's dome
## beside it, where the Mist Trail goes down to Happy Isles and the John Muir
## Trail goes on to Little Yosemite Valley.

const GlacierVistaArt = preload("res://tools/hubs/glacier_vista_art.gd")

const GEO_ILLILOUETTE := Vector2(-119.5600, 37.7180)
const MAP_W := 90
const MAP_H := 60
## Illilouette Creek, from the foot of the fall south through the map.
const CREEK_PTS := [Vector2(56, 12), Vector2(53, 19), Vector2(48, 26), Vector2(45, 31), Vector2(44, 38),
	Vector2(46, 46), Vector2(44, 53), Vector2(45, 59)]
const BRIDGE_ROWS := [31, 32]
## The Panorama Trail's column on the north edge (Glacier Point's column 88).
const NORTH_COL := 10

var drop := PackedByteArray()


func _ready() -> void:
	print("== Illilouette")
	load_flora()
	import_assets()
	print("== Illilouette region")
	_illilouette()
	print("Done")
	get_tree().quit()


# ---------------------------------------------------------------- the trees

## The red fir and Jeffrey pine are Glacier Point's own (glacier_art.gd);
## everything else comes from the Ahwahnee flora.
func _variants(prefix: String) -> Array:
	if prefix.begins_with("gp_"):
		return GlacierArt.GP_TREES.filter(func(n: String) -> bool: return n.begins_with(prefix))
	return super._variants(prefix)


func _prop(sprite_name: String, at_pos: Vector2, node_name := "") -> StaticBody2D:
	if not sprite_name.begins_with("gp_"):
		return super._prop(sprite_name, at_pos, node_name)
	var body := decor(node_name if node_name != "" else sprite_name.to_pascal_case() + str(_entities.get_child_count()),
		G + sprite_name + ".png", at_pos, GlacierArt.GP_TRUNKS.get(sprite_name, Vector2(4, 3)))
	(body.get_node("Sprite") as Sprite2D).offset.y += 2
	return body


## The Ahwahnee ground painter with smooth granite and red fir duff.
func _save_ground_art(file_name: String, seed_value: int, rings := [], soils: Array[Rect2i] = []) -> Sprite2D:
	_painter = Ground.new()
	_painter.rings = rings
	_painter.soils = soils
	_painter.smooth_granite = true
	_painter.fir_duff = true
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


# ---------------------------------------------------------------- layout

func _layout() -> void:
	init_grid(MAP_W, MAP_H, Terrain.FIR)
	rng.seed = 5560
	noise.seed = 5560
	noise.frequency = 0.09
	# Illilouette Gorge, the drop along the north-east: sheer rock down to
	# row 6 to 11, ragged, shallower to the east.
	# West of it, as far as the trail, a strip of rim drops away to the
	# north, as Glacier Point's south-east does just across the edge.
	for x in range(NORTH_COL + 12, MAP_W):
		var depth := int(10.5 - (x - 50) * 0.1 + noise.get_noise_1d(x * 4.0) * 1.5)
		if x < 50:
			depth = int(1.5 + (x - NORTH_COL - 12) * 0.12 + noise.get_noise_1d(x * 4.0) * 0.8)
		fill(x, 0, x, depth, Terrain.CLIFF)
	# The gorge of the Merced below Nevada Fall, off the south-east corner.
	for y in range(46, MAP_H):
		var east := int(85.0 + noise.get_noise_1d(y * 4.0 + 90.0) * 1.2 + (y - 46) * 0.05)
		fill(east, y, MAP_W - 1, y, Terrain.CLIFF)
	# Manzanita and huckleberry oak round the rock, and a wet seep by the creek.
	_ellipse(46, 13, 10, 7, Terrain.SCRUB, 0.3, [Terrain.FIR])
	_ellipse(68, 27, 11, 8, Terrain.SCRUB, 0.3, [Terrain.FIR])
	_ellipse(80, 29, 9, 9, Terrain.SCRUB, 0.3, [Terrain.FIR])
	_ellipse(46, 40, 4, 6, Terrain.WET_MEADOW, 0.3, [Terrain.FIR])
	_ellipse(30, 42, 5, 3, Terrain.MEADOW, 0.3, [Terrain.FIR])
	# Granite: the lip over the fall, Panorama Point, Liberty Cap, and slabs
	# breaking through the forest.
	_ellipse(46, 13, 7, 4.5, Terrain.GRANITE, 0.2, [Terrain.FIR, Terrain.SCRUB])
	_ellipse(68, 27, 7, 5, Terrain.GRANITE, 0.2, [Terrain.FIR, Terrain.SCRUB])
	_ellipse(80, 29, 5, 6, Terrain.GRANITE, 0.2, [Terrain.FIR, Terrain.SCRUB])
	for slab: Array in [[22, 26, 3, 2], [14, 44, 4, 2], [58, 44, 3, 2], [30, 54, 3, 2], [74, 50, 3, 2], [20, 8, 2, 2]]:
		_ellipse(slab[0], slab[1], slab[2], slab[3], Terrain.GRANITE, 0.4, [Terrain.FIR, Terrain.SCRUB])
	# The Panorama Trail: in from Glacier Point at the north edge, switchbacks
	# down to the lip over the fall.
	_path([Vector2(NORTH_COL, 0), Vector2(NORTH_COL, 4), Vector2(15, 8), Vector2(8, 12), Vector2(17, 16), Vector2(25, 14),
		Vector2(31, 19), Vector2(38, 15), Vector2(46, 13)], 1, Terrain.TRAIL, 0.3)
	# Down the west bank, across the footbridge, and up to Panorama Point.
	_path([Vector2(46, 13), Vector2(40, 18), Vector2(38, 24), Vector2(37, 31), Vector2(48, 31), Vector2(60, 32),
		Vector2(64, 30), Vector2(68, 27)], 1, Terrain.TRAIL, 0.3)
	# A straight two-row run over the bridge, so the crossing never kinks.
	_path([Vector2(37, 31), Vector2(60, 31)], 1, Terrain.TRAIL, 0.0)
	_path([Vector2(37, 32), Vector2(60, 32)], 1, Terrain.TRAIL, 0.0)
	# On east to the top of Nevada Fall, and the fork to the John Muir Trail.
	_path([Vector2(68, 27), Vector2(74, 30), Vector2(80, 36), Vector2(84, 40), Vector2(88, 40)], 1, Terrain.TRAIL, 0.3)
	_path([Vector2(80, 36), Vector2(84, 35), Vector2(88, 35)], 1, Terrain.TRAIL, 0.3)
	# The creek, laid over the trail where they cross, then a footbridge
	# over it: so the crossing is always walkable.
	_path(CREEK_PTS, 3, Terrain.CREEK, 0.3)
	for x in range(38, 56):
		for y: int in BRIDGE_ROWS:
			if at(x, y) == Terrain.CREEK:
				put(x, y, Terrain.BRIDGE)
	_mark_open()
	drop.resize(MAP_W * MAP_H)
	for k in MAP_W * MAP_H:
		drop[k] = 1 if kind[k] == Terrain.CLIFF else 0
	clear_trees(NORTH_COL - 3, 0, NORTH_COL + 3, 4) # the seam
	clear_trees(38, 8, 52, 18) # the lip over the fall
	clear_trees(36, 29, 54, 35) # the footbridge
	clear_trees(60, 22, 76, 33) # Panorama Point
	clear_trees(76, 28, 89, 42) # the top of Nevada Fall


# ---------------------------------------------------------------- scene

func _illilouette() -> void:
	_layout()
	start_region("Illilouette", "illilouette", "Illilouette Gorge", GEO_ILLILOUETTE)
	_root.hub_id = "glacier_point"
	# the creek's current lines drift south, downstream (seasonal_ground.gdshader)
	_root.set_meta("water_flow", Vector2(0.0, 9.0))
	paint_ground()
	_save_ground_art("ground_illilouette", 5560)
	_place_view()
	_place_overlook()
	_place_crossing()
	_place_panorama()
	_place_exits()
	_place_markers_and_places()
	_dress_illilouette()
	_finish("illilouette", 2.0)


## The drop shows the right of Glacier Point's painting, held still across
## the screen: Half Dome, Liberty Cap, and Nevada and Vernal Falls.
func _place_view() -> void:
	var im := GlacierArt.new().view_below(drop, MAP_W, MAP_H)
	im.save_png(ProjectSettings.globalize_path(G + "illilouette_view.png"))
	import_assets()
	var falls := []
	for f: Array in GlacierVistaArt.VISTA_FALLS:
		falls.append([f[0] * 2.0, f[1] * 2.0, f[2] * 2.0])
	_vista(_backdrop("illilouette_view", Vector2.ZERO, -8, G), G + "vista.png", Vector2.ZERO, Vector2(660, 0), Vector2(0.0, 0.05), falls)


func _place_overlook() -> void:
	_info_sign("IllilouetteFallSign", foot(44, 15), "Illilouette Fall",
		"370 feet. Illilouette Creek drains the Clark Range to the south-east and goes over the lip of this gorge in a single plume. It is the biggest tributary of the Merced, and its canyon was cut by its own small glaciers, not the great ice of the Valley.")
	_ambient("IllilouetteFallSpray", "mist", Vector2(57 * T, 12 * T), Vector2(28, 6))
	_info_sign("PanoramaTrailSign", foot(11, 3), "Panorama Trail",
		"From Glacier Point down through red fir and Jeffrey pine, across Illilouette Creek, past Panorama Point to the top of Nevada Fall. Carry water: there is none on the ridge.")


func _place_crossing() -> void:
	_info_sign("IllilouetteBridgeSign", foot(41, 30), "Illilouette Creek Bridge",
		"The footbridge crosses the creek just downstream of the fall. In early summer the snowmelt runs fast and cold under it; by fall the creek is a trickle over the cobbles.")
	_creek_rocks()


## Rocks in the creek, breaking the current, clear of the bridge.
func _creek_rocks() -> void:
	for i in 8:
		var idx := rng.randi_range(0, CREEK_PTS.size() - 2)
		var a: Vector2 = CREEK_PTS[idx]
		var b: Vector2 = CREEK_PTS[idx + 1]
		var p := a.lerp(b, rng.randf())
		var c := Vector2i(p)
		if at(c.x, c.y) != Terrain.CREEK or (c.y in BRIDGE_ROWS):
			continue
		_prop(_pick("rock_river"), Vector2(p.x * T + rng.randf_range(-4, 4), p.y * T + 12.0))


func _place_panorama() -> void:
	_info_sign("PanoramaPointSign", foot(66, 29), "Panorama Point",
		"Half Dome stands across the canyon, with Mount Broderick and Liberty Cap in front of it, and below, the Merced falling over Nevada and Vernal Falls.")
	_info_sign("LibertyCapSign", foot(79, 33), "Liberty Cap",
		"A granite dome beside Nevada Fall, rounded by the glacier that rode over it. Early visitors thought its shape looked like a Phrygian cap, the old cap of liberty.")
	_info_sign("NevadaFallSign", foot(83, 37), "Top of Nevada Fall",
		"594 feet. The Merced River drops over a granite step and slides down a slab before it falls. The Mist Trail goes down beside it to Vernal Fall and Happy Isles; the John Muir Trail goes on to Little Yosemite Valley. Stay back from the edge: the current above the fall is swift.")


func _place_exits() -> void:
	# The Panorama Trail's way back to Glacier Point, off the north edge.
	region_exit("PanoramaNorth", tile_pos(NORTH_COL, -0.5), Vector2(48, 12), "Panorama Trail, up to Glacier Point",
		"glacier_point", "panorama_south")
	_trail_door("MistTrailDown", foot(87, 40), "Mist Trail, down past Nevada and Vernal Falls to Happy Isles",
		"happy_isles", "panorama", 150, "mist_trail")
	_trail_door("JohnMuirTrailEast", foot(87, 35), "John Muir Trail, to Little Yosemite Valley",
		"little_yosemite_valley", "jmt", 20)


func _place_markers_and_places() -> void:
	marker("north", 10, 2)
	marker("arrival", 10, 4)
	marker("illilouette_overlook", 46, 13)
	marker("bridge", 44, 31)
	marker("panorama_point", 68, 27)
	marker("nevada_fall_top", 82, 38)
	place("Illilouette Fall", 52, 11, 9)
	place("Illilouette Creek Bridge", 44, 31, 4)
	place("Panorama Point", 68, 27, 6)
	place("Top of Nevada Fall", 82, 38, 6)
	for label: Array in [["Half Dome", 70, 22], ["Liberty Cap", 80, 29]]:
		var p := Marker2D.new()
		p.set_script(load("res://scripts/world/place.gd"))
		p.name = (label[0] as String).replace(" ", "")
		p.position = tile_pos(label[1], label[2])
		p.set("display_name", label[0])
		p.set("radius", 0.0)
		p.set("show_banner", false)
		p.set("show_on_map", true)
		_places.add_child(p)


## The red fir and Jeffrey pine forest, with white fir; Jeffrey pines rooted
## in the granite, manzanita and huckleberry oak on the rocky ground, ferns
## and corn lilies by the creek, logs and rocks on the duff.
func _dress_illilouette() -> void:
	_reserve_entities(1, 3)
	var all := Rect2i(0, 0, w, h)
	_fringe_trees([Terrain.FIR], 3, 0.72, [["gp_red_fir", 5.0], ["gp_jeffrey", 2.5], ["gp_lodgepole", 1.0], ["gp_snag", 0.4], ["tree_white_fir", 1.0]], 1, 22.0)
	_fringe_trees([Terrain.SCRUB], 5, 0.45, [["gp_jeffrey", 2.0], ["gp_red_fir", 0.6], ["gp_snag", 0.5]], 1, 30.0)
	_fringe_trees([Terrain.GRANITE], 7, 0.3, [["gp_jeffrey", 1.0]], 1, 40.0)
	_fringe_trees([Terrain.MEADOW, Terrain.WET_MEADOW], 5, 0.3, [["gp_lodgepole", 1.0]], 1, 30.0)
	_scatter_decor("plant_manzanita", [Terrain.SCRUB], 50, all, 1)
	_scatter_decor("plant_shrub", [Terrain.SCRUB, Terrain.FIR], 40, all, 1)
	_scatter_decor("rock_granite", [Terrain.GRANITE, Terrain.SCRUB, Terrain.FIR], 50, all, 1)
	_scatter_decor("log_fallen", [Terrain.FIR], 12, all, 2)
	_scatter_decor("log_stump", [Terrain.FIR], 6, all, 1)
	_scatter_decor("plant_mushrooms", [Terrain.FIR], 6, all, 2)
	_scatter_decor("plant_wildflowers", [Terrain.MEADOW, Terrain.SCRUB], 16, all, 1)
	_scatter_decor("plant_lupine", [Terrain.MEADOW], 8, all, 1)
	_scatter_decor("plant_cornlily", [Terrain.MEADOW, Terrain.WET_MEADOW], 10, all, 0)
	_scatter_decor("plant_fern", [Terrain.WET_MEADOW], 8, all, 0)
	_scatter_decor("plant_cattails", [Terrain.WET_MEADOW], 4, all, 0)
