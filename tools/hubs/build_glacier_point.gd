extends AhwahneeStyle
## Builds Glacier Point by hand, laid out like the real one, in the Ahwahnee
## look. Run tools/hubs/rebuild_glacier_point.sh, which runs this:
##
##   godot --headless --path . res://tools/hubs/build_glacier_point.tscn
##
## and then moves the scene and the art onto the game's 32px grid. It
## rewrites scenes/regions/glacier_point.tscn, the art in
## assets/sprites/glacier/ (glacier_art.gd), and the painted ground
## assets/sprites/ahwahnee/ground_glacier_point.png. Put story NPCs in
## scenes/story/content/glacier_point.tscn (placed by Marker name), not in the
## region scene, so a rebuild keeps them.
##
## The real layout, squeezed so it can be walked: the overlook on its
## granite point at the north, railed in, with Overhanging Rock jutting off
## its west side and the Valley floor 3,200 feet below; the paved walk south
## past the Geology Hut (1924) on its knob, the site of the Glacier Point
## Hotel and McCauley's Mountain House (burned in 1969), and the stone
## amphitheater, to the snack stand, the restrooms and the parking lot at the
## end of Glacier Point Road. The Four Mile Trail leaves west along the north
## rim, crossing Sentinel Creek above Sentinel Fall; the Panorama Trail drops
## off the east rim toward Illilouette and Nevada Falls; the Pohono Trail runs
## southwest to Sentinel Dome, with the fallen Jeffrey pine on its summit.
## Coming in, the road passes the Sentinel Dome trailhead, then Washburn
## Point on the east rim. To the north and east the map falls away: Half
## Dome, Liberty Cap, and Vernal, Nevada and Illilouette falls stand across
## the canyon. The forest is red fir and Jeffrey pine, with lodgepole and
## silver snags, and manzanita and huckleberry oak on the rocky rims.

const GlacierArt = preload("res://tools/hubs/glacier_art.gd")

const W := 112
const H := 76
const SCENE := "res://scenes/regions/glacier_point.tscn"
const G := "res://assets/sprites/glacier/"
const GEO := Vector2(-119.5738, 37.7306)

## The rim. North of NORTH_RIM (per column) and east of EAST_RIM (per row)
## the map drops away. [x, first land row] and [y, last land column].
const NORTH_RIM := [[0, 16], [12, 14], [24, 13], [36, 14], [46, 13], [51, 11], [54, 8], [57, 5], [60, 3],
	[64, 2], [67, 3], [70, 6], [72, 10], [W, 12]]
const EAST_RIM := [[0, 71], [8, 71], [12, 73], [18, 75], [24, 78], [30, 80], [36, 82], [42, 85], [48, 89],
	[52, 93], [55, 99], [58, 101], [61, 99], [63, 95], [68, 96], [H, 99]]

## Landmarks across the canyon, in tiles (see GlacierArt.view_below).
## Placed so each overlook frames its real view on screen: Half Dome across
## from the point, Curry Village straight below it, and from Washburn Point,
## Nevada Fall under Liberty Cap with Mount Broderick beside it, Vernal Fall
## below, and Illilouette Fall off to the right.
const VIEW := {
	"half_dome": Vector2(78, 19),
	"broderick": Vector2(103.5, 54),
	"liberty_cap": Vector2(108.5, 54.5),
	"curry": Vector2(76, 4),
	"rivers": [
		# the Merced over Nevada and Vernal falls, into the gorge under Washburn
		[Vector2(107, 56.4), Vector2(104.5, 57.6), Vector2(103, 58), Vector2(103, 59.6), Vector2(101.8, 61.5)],
		# and out of it at Happy Isles, down through the Valley below the point
		[Vector2(98, 52), Vector2(95, 48), Vector2(90, 40), Vector2(86, 28), Vector2(81, 16), Vector2(77, 6), Vector2(68, 1),
			Vector2(56, 0.5), Vector2(46, 5), Vector2(30, 7), Vector2(14, 6), Vector2(0, 8)],
		# the Illilouette, from its fall to the Merced
		[Vector2(108, 64.4), Vector2(105, 63.2), Vector2(101.8, 61.5)],
	],
	"meadows": [Rect2(70, 1, 5, 2), Rect2(38, 2, 9, 4), Rect2(16, 4, 7, 3)],
}
## Falls over the view: [sprite prefix, top center in tiles, mist].
const FALL_AT := [["gp_nevada", Vector2(107, 53.9), true], ["gp_vernal", Vector2(103, 58), true],
	["gp_illilouette", Vector2(108, 62.5), false]]

var drop := PackedByteArray()


func _ready() -> void:
	w = W
	h = H
	print("== Glacier Point art")
	load_flora()
	GlacierArt.new().save_all()
	import_assets()
	print("== Glacier Point region")
	_build_region()
	print("Done")
	get_tree().quit()


# ---------------------------------------------------------------- the rim trees

## The rim trees are Glacier Point's own (glacier_art.gd); everything else
## comes from the Ahwahnee flora.
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


## The Ahwahnee ground painter with Glacier Point's smooth granite and red
## fir duff (AhwahneeStyle._save_ground_art, with those two switched on).
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

static func _rim(points: Array, at_value: float) -> float:
	for i in points.size() - 1:
		var a: Array = points[i]
		var b: Array = points[i + 1]
		if at_value <= b[0]:
			return lerpf(a[1], b[1], (at_value - a[0]) / float(b[0] - a[0]))
	return points[-1][1]


func _is_drop(x: int, y: int) -> bool:
	return drop[clampi(y, 0, H - 1) * W + clampi(x, 0, W - 1)] == 1


func _layout() -> void:
	init_grid(W, H, Terrain.FIR)
	rng.seed = 7214
	noise.seed = 7214
	noise.frequency = 0.09
	drop.resize(W * H)
	drop.fill(0)
	for y in H:
		for x in W:
			var north := _rim(NORTH_RIM, x) + noise.get_noise_1d(x * 4.0) * 0.8
			var east := _rim(EAST_RIM, y) + noise.get_noise_1d(y * 4.0 + 90.0) * 0.8
			if y < north or x > east:
				drop[y * W + x] = 1
				put(x, y, Terrain.CLIFF)

	# Manzanita and huckleberry oak on the rocky ground along the rims.
	for y in H:
		for x in W:
			if _is_drop(x, y):
				continue
			var near := 0
			for r in range(1, 5):
				if _is_drop(x - r, y) or _is_drop(x + r, y) or _is_drop(x, y - r) or _is_drop(x, y + r):
					near = r
					break
			if near > 0 and near + noise.get_noise_2d(x * 2.0, y * 2.0) * 3.0 < 3.5:
				put(x, y, Terrain.SCRUB)
	# Granite: the point itself, Sentinel Dome and its rocky skirt, Washburn
	# Point, and slabs breaking through the forest.
	_ellipse(18, 50, 15, 12, Terrain.SCRUB, 0.3, [Terrain.FIR])
	_ellipse(18, 50, 11, 9, Terrain.GRANITE, 0.15, [Terrain.FIR, Terrain.SCRUB])
	_ellipse(63, 7, 10, 8, Terrain.GRANITE, 0.2, [Terrain.FIR, Terrain.SCRUB])
	_ellipse(69, 18, 4, 3, Terrain.GRANITE, 0.3, [Terrain.FIR, Terrain.SCRUB])
	_ellipse(98, 57, 5, 4, Terrain.GRANITE, 0.3, [Terrain.FIR, Terrain.SCRUB])
	for slab: Array in [[30, 24, 3, 2], [8, 30, 3, 2], [44, 60, 4, 2], [84, 64, 3, 2], [26, 68, 3, 2], [58, 62, 2, 2], [78, 44, 2, 2]]:
		_ellipse(slab[0], slab[1], slab[2], slab[3], Terrain.GRANITE, 0.4, [Terrain.FIR, Terrain.SCRUB])
	# Sentinel Creek, from the forest south of the dome to the north rim,
	# where it goes over as Sentinel Fall, with a boggy seep beside it.
	_ellipse(11, 40, 3, 2, Terrain.WET_MEADOW, 0.3, [Terrain.FIR, Terrain.SCRUB])
	_ellipse(12, 60, 4, 3, Terrain.MEADOW, 0.3, [Terrain.FIR])
	_path([Vector2(6, 75), Vector2(7, 62), Vector2(9, 48), Vector2(8, 32), Vector2(10, 14)], 1, Terrain.CREEK, 0.6)

	# The overlook plaza at the tip, and the walk south to the snack stand.
	_path([Vector2(56, 40), Vector2(57, 32), Vector2(60, 22), Vector2(62, 14), Vector2(62, 9)], 2, Terrain.PAVED, 0.3)
	_ellipse(63, 9, 4, 3, Terrain.PAVED, 0.1, [Terrain.GRANITE, Terrain.SCRUB, Terrain.FIR])
	_path([Vector2(61, 19), Vector2(68, 20)], 2, Terrain.PAVED) # to the Geology Hut
	_path([Vector2(59, 27), Vector2(64, 30), Vector2(72, 31)], 2, Terrain.PAVED) # past the hotel site to the amphitheater
	_ellipse(76, 35, 5.5, 4.5, Terrain.CAMP, 0.15, [Terrain.FIR, Terrain.SCRUB, Terrain.GRANITE]) # the amphitheater
	fill(36, 37, 63, 42, Terrain.PAVED) # the plaza by the snack stand
	fill(40, 45, 68, 55, Terrain.PARKING)
	fill(52, 43, 56, 44, Terrain.PAVED)

	# Glacier Point Road: in from the south past the Sentinel Dome trailhead
	# and Washburn Point, then down to the lot.
	_path([Vector2(36, 75), Vector2(44, 71), Vector2(60, 70), Vector2(80, 68), Vector2(89, 62), Vector2(88, 56),
		Vector2(78, 52), Vector2(68, 50)], 3, Terrain.ROAD)
	fill(38, 66, 46, 69, Terrain.PARKING) # Sentinel Dome trailhead
	fill(89, 54, 95, 60, Terrain.PARKING) # Washburn Point
	fill(95, 55, 98, 58, Terrain.PAVED)

	# Trails.
	_path([Vector2(39, 37), Vector2(34, 27), Vector2(26, 20), Vector2(14, 19), Vector2(2, 19)], 1, Terrain.TRAIL, 0.4) # Four Mile
	_path([Vector2(62, 32), Vector2(70, 39), Vector2(78, 42), Vector2(83, 42)], 1, Terrain.TRAIL, 0.3) # Panorama
	_path([Vector2(40, 38), Vector2(32, 36), Vector2(26, 44), Vector2(22, 47)], 1, Terrain.TRAIL, 0.4) # Pohono, to the dome
	_path([Vector2(40, 66), Vector2(33, 62), Vector2(26, 57), Vector2(21, 53)], 1, Terrain.TRAIL, 0.4) # Sentinel Dome trail
	_path([Vector2(10, 52), Vector2(2, 54)], 1, Terrain.TRAIL, 0.4) # Pohono, on west to Taft Point

	# Keep the rim itself clear of everything the walk paints, and keep trees
	# off the paving, roads and trails.
	for k in W * H:
		if drop[k]:
			kind[k] = Terrain.CLIFF
	for k in W * H:
		if kind[k] in [Terrain.PAVED, Terrain.PARKING, Terrain.ROAD, Terrain.TRAIL, Terrain.BUILT, Terrain.CREEK, Terrain.CLIFF]:
			no_trees[k] = 1
	clear_trees(52, 0, 74, 14) # the overlook
	clear_trees(34, 30, 66, 44) # the plaza and the buildings
	clear_trees(62, 22, 82, 40) # the hotel site and the amphitheater
	clear_trees(12, 43, 24, 50) # the dome's summit


# ---------------------------------------------------------------- scene

func _build_region() -> void:
	_layout()
	start_region("GlacierPoint", "glacier_point", "Glacier Point", GEO)
	_root.hub_id = "glacier_point"
	paint_ground()
	_save_ground_art("ground_glacier_point", 7214)
	_place_view()
	_place_overlook()
	_place_walk()
	_place_lot()
	_place_rim_trails()
	_place_markers_and_places()
	_dress()
	place_blockers()
	add_forage("glacier_point", 2.5)
	for child in _root.get_children():
		_own(child, _root)
	pack(_root, SCENE)


## The view over the edge: one picture behind everything, and the falls.
func _place_view() -> void:
	var im := GlacierArt.new().view_below(drop, W, H, VIEW)
	im.save_png(ProjectSettings.globalize_path(G + "view_below.png"))
	import_assets()
	_backdrop("view_below", Vector2.ZERO, -8, G)
	for f: Array in FALL_AT:
		var size: Vector2i = GlacierArt.FALLS[f[0]]
		var top: Vector2 = f[1] * T
		_animation(f[0].to_pascal_case(), f[0], 6.0, top - Vector2(size.x / 2.0, 0), -7, G)
		if f[2]:
			_ambient(f[0].to_pascal_case() + "Mist", "mist", top + Vector2(0, size.y), Vector2(10, 4))


## A run of parapet and pipe railing along every edge of the overlook (and of
## Washburn Point) that looks over the drop.
func _rail(x0: int, y0: int, x1: int, y1: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if _is_drop(x, y):
				continue
			if _is_drop(x, y - 1):
				decor("RimWall%d_%d" % [x, y], G + "rim_wall_h.png", Vector2(x * T + T / 2.0, y * T + 5), Vector2(16, 4))
			if _is_drop(x + 1, y):
				decor("RimWallE%d_%d" % [x, y], G + "rim_wall_v.png", Vector2(x * T + T - 3, (y + 1) * T), Vector2(6, 14))
			elif _is_drop(x - 1, y):
				decor("RimWallW%d_%d" % [x, y], G + "rim_wall_v.png", Vector2(x * T + 3, (y + 1) * T), Vector2(6, 14))


func _place_overlook() -> void:
	_rail(50, 0, 74, 16)
	# Overhanging Rock, off the west side of the point.
	decor("OverhangingRock", G + "overhanging_rock.png", Vector2(55 * T, 7 * T + 2))
	_info("OverhangingRockInfo", foot(56, 8), Vector2(24, 16), "Overhanging Rock",
		"A slab of granite jutting out from the point, 3,000 feet above the Valley floor. In old photographs people stand, dance and even do handstands on its tip. It has been closed to visitors for years: enjoy it from behind the railing.")
	_info_sign("GlacierPointSign", foot(60, 10), "Glacier Point",
		"7,214 feet. The Valley floor is 3,200 feet straight down. Across the canyon: Half Dome, and to its right Liberty Cap and Nevada Fall, with Vernal Fall below. Below you, Curry Village and the Merced.")
	_info_sign("HalfDomeSign", foot(66, 6), "Half Dome",
		"8,842 feet, 4,800 feet above the Valley. Its sheer northwest face broke away along vertical cracks in the granite, and the glaciers below carried the fallen rock off. The cables up its back go up in late May.")
	for v: Array in [[59, 6], [63, 4], [68, 7]]:
		decor("Viewer%d" % v[0], G + "viewer.png", foot(v[0], v[1]), Vector2(6, 4))
	# The Firefall: McCauley's crew pushed the embers off just east of here.
	_info_sign("FirefallSign", foot(69, 11), "The Firefall",
		"On summer nights from 1872 until 1968, glowing embers of red fir bark were pushed off this cliff, and fell like a waterfall of fire to the cheers from Camp Curry below. James McCauley of the Mountain House began it. The Park Service ended it because it wasn't a natural event.")


func _place_walk() -> void:
	# The Geology Hut on its knob, looking at Half Dome.
	var hut := decor("GeologyHut", G + "geology_hut.png", foot(70, 18), Vector2(52, 10))
	hut.set_script(load("res://scripts/objects/info_sign.gd"))
	hut.set("title", "Geology Hut")
	hut.set("text", "Built in 1924 of the granite it stands on, so visitors could read the canyon below. Glaciers flowed down the Merced and Tenaya canyons below you, deepening and widening them into the U-shaped Valley.")
	_hitbox(hut, Vector2(58, 24))
	# The site of the hotel and the Mountain House.
	decor("HotelRuin", G + "hotel_ruin.png", foot(67.5, 27))
	_info_sign("HotelSign", foot(62, 27), "Glacier Point Hotel",
		"James McCauley's Mountain House opened here in 1878, and the grander Glacier Point Hotel beside it in 1917. Both burned in August 1969, and only their footings are left.")
	# The amphitheater: a stage with the canyon behind it, benches in rows.
	decor("AmphiStage", G + "amphi_stage.png", foot(76, 31), Vector2(40, 10))
	for row in 4:
		# each row a little wider than the last, in an arc round the stage
		for side in [-1, 1]:
			var bx: float = 76.0 + side * (1.3 + row * 0.35)
			var by: float = 33.2 + row * 1.25 - absf(row - 1.5) * 0.1
			decor("Bench%d_%d" % [row, side], G + "amphi_bench.png", foot(bx, by) + Vector2(side * 4 * row, 0), Vector2(26, 4))
	_info_sign("AmphitheaterSign", foot(72, 37), "Glacier Point Amphitheater",
		"Rangers give talks here on summer evenings and lead star parties at night. At 7,214 feet, far from town lights, the Milky Way rises right over Half Dome.")
	# The snack stand and the restrooms on the plaza, picnic tables in front.
	_lit_building("SnackStand", "snack_stand", 50, 37, "Glacier Point Gifts & Snacks",
		"Ice cream, sandwiches and hot coffee, maps and postcards. Open when the road is, May to November.")
	_lit_building("Restrooms", "restrooms", 41, 37, "Restrooms", "Flush toilets and water.")
	var B := "res://assets/sprites/buildings/"
	for t: Array in [[46, 41], [58, 40], [61, 42]]:
		decor("PicnicTable%d" % t[0], B + "camp4_table.png", foot(t[0], t[1]), Vector2(32, 8))
	for p: Array in [[37, 41], [61, 13], [65, 13], [58, 24]]:
		_prop("garden_bench", foot(p[0], p[1]) + Vector2(0, 2))
	decor("BearBox", B + "bear_box.png", foot(44, 42), Vector2(14, 6))


func _place_lot() -> void:
	instance_scene("res://scenes/objects/travel_point.tscn", foot(54, 43), "Travel_GlacierPointParking").set("label", "Glacier Point Parking")
	var CS_ := "res://assets/sprites/curry/"
	var cars := [[42, 47], [44, 47], [48, 47], [52, 47], [58, 47], [62, 47], [66, 47],
		[43, 53], [47, 53], [49, 53], [55, 53], [61, 53], [63, 53], [91, 56], [93, 59], [40, 68], [44, 68]]
	for i in cars.size():
		var car: Array = cars[i]
		decor("Car%d_%d" % [car[0], car[1]], CS_ + "car_%d.png" % ((i * 7 + car[0]) % 12), foot(car[0], car[1]), Vector2(24, 12))
	# Washburn Point: a railed pullout on the rim, and its sign.
	_rail(88, 48, 104, 64)
	_info_sign("WashburnSign", foot(96, 56), "Washburn Point",
		"The best view of Vernal and Nevada Falls, one above the other on the Merced, with Liberty Cap beside Nevada Fall and Half Dome in profile above. Illilouette Fall drops into its gorge to the right.")
	instance_scene("res://scenes/objects/travel_point.tscn", foot(43, 65), "Travel_SentinelDomeTrailhead").set("label", "Sentinel Dome Trailhead")
	region_exit("GlacierPointRoad", tile_pos(37, H - 1), Vector2(48, 16), "Glacier Point Road", "", "").set("travel_to", "yosemite_valley")


## A building with its windows lit after dark.
func _lit_building(node_name: String, sprite_name: String, tile_x: float, base_y: int, title: String, text: String) -> void:
	var body := building(node_name, G + sprite_name + ".png", tile_x, base_y, title, text)
	var tex := (body.get_node("Sprite") as Sprite2D).texture
	_glow(sprite_name + "_glow", body.position - Vector2(tex.get_width() / 2.0, tex.get_height()), 1.0, G)


## A trail into another region, with its trailhead sign.
func _trail_door(node_name: String, at_pos: Vector2, label: String, target_region: String, target_spawn: String, minutes: int, closure := "") -> void:
	var door := instance_scene("res://scenes/objects/region_door.tscn", at_pos, node_name)
	door.set("label", label)
	door.set("target_region", target_region)
	door.set("target_spawn", target_spawn)
	door.set("minutes", minutes)
	door.set("closure", closure)


func _place_rim_trails() -> void:
	# No winter closure from the top: a climber who tops out the Apron before
	# the road opens can always walk down.
	_trail_door("FourMileTrail", foot(3, 19), "Four Mile Trail, down to the Valley", "yosemite_valley", "four_mile_trailhead", 120)
	_trail_door("PanoramaTrail", foot(83, 42), "Panorama Trail, down to Happy Isles", "yosemite_valley", "happy_isles", 240)
	# The Ledge Trail tops out by the Mountain House footings (Curry Village's
	# end opens once you've climbed the Apron).
	_trail_door("LedgeTrail", foot(73, 26), "Ledge Trail, down to Curry Village", "curry_village", "ledge_trailhead", 120)
	_info_sign("FourMileSign", foot(39, 35), "Four Mile Trail",
		"Down to the Valley floor along the rim and then in switchbacks, past Union Point. It's 4.8 miles now; the toll trail built in 1872 was four.")
	_info_sign("PanoramaSign", foot(63, 33), "Panorama Trail",
		"Along the rim of Illilouette Gorge, past Illilouette Fall, to the top of Nevada Fall, then down the Mist Trail beside Vernal Fall to Happy Isles. A long day: 8.5 miles.")
	_info_sign("SentinelCreekSign", foot(11, 21), "Sentinel Creek",
		"The creek runs off the rim just north of here as Sentinel Fall, which drops nearly 2,000 feet in steps in spring and is gone by midsummer.")
	_info_sign("PohonoSign", foot(4, 52), "Pohono Trail",
		"West along the rim to Taft Point and its fissures, deep cracks in the granite you can look straight down, and on to Dewey and Inspiration Points.")
	decor("TrailPost", G + "trail_post.png", foot(38, 39), Vector2(4, 3))
	# Sentinel Dome and the fallen Jeffrey pine on its summit.
	decor("SentinelJeffrey", G + "sentinel_jeffrey.png", foot(18, 47), Vector2(60, 6))
	_info("SentinelJeffreyInfo", foot(18, 47), Vector2(64, 18), "The Sentinel Dome Jeffrey pine",
		"The most photographed tree in Yosemite: Ansel Adams photographed it in 1940, bent by the wind. The drought of 1976 and 1977 killed it, and it fell in August 2003. It still lies where it fell.")
	_info_sign("SentinelDomeSign", foot(21, 54), "Sentinel Dome",
		"8,122 feet, a bare granite dome higher than Glacier Point, with a view all the way round: El Capitan, Yosemite Falls, Half Dome, Clouds Rest and the High Sierra.")
	_info_sign("SentinelTrailheadSign", foot(38, 64), "Sentinel Dome Trailhead",
		"Sentinel Dome, 1.1 miles. Taft Point, 1.1 miles the other way.")


func _place_markers_and_places() -> void:
	marker("arrival", 54, 45)
	marker("apron_top", 66, 12)
	marker("washburn_point", 96, 57)
	marker("sentinel_dome", 20, 51)
	marker("sentinel_dome_trailhead", 42, 66)
	marker("geology_hut", 69, 20)
	marker("amphitheater", 76, 36)
	marker("hotel_site", 64, 28)
	marker("snack_stand", 50, 39)
	marker("four_mile_trailhead", 4, 19)
	marker("panorama_trailhead", 81, 42)
	marker("ledge_trail_top", 72, 27)
	marker("road_south", 37, 74)
	place("Glacier Point", 63, 9, 9)
	place("Overhanging Rock", 55, 8, 2, false)
	place("Geology Hut", 70, 18, 3)
	place("Glacier Point Hotel site", 66, 27, 3, false)
	place("Glacier Point Amphitheater", 76, 34, 4)
	place("Glacier Point Parking", 54, 50, 9, false)
	place("Washburn Point", 96, 57, 5)
	place("Sentinel Dome", 18, 50, 11)
	place("Sentinel Dome Trailhead", 42, 67, 3, false)
	place("Sentinel Creek", 9, 40, 2, false)
	for label: Array in [["Half Dome", 84, 10], ["Liberty Cap", 108, 52], ["Mount Broderick", 103, 52], ["Nevada Fall", 107, 55],
			["Vernal Fall", 103, 59], ["Illilouette Fall", 108, 63], ["Curry Village", 76, 4]]:
		var p := Marker2D.new()
		p.set_script(load("res://scripts/world/place.gd"))
		p.name = (label[0] as String).replace(" ", "")
		p.position = tile_pos(label[1], label[2])
		p.set("display_name", label[0])
		p.set("radius", 0.0)
		p.set("show_banner", false)
		p.set("show_on_map", true)
		_places.add_child(p)


## The rim forest: red fir and Jeffrey pine with some lodgepole and snags,
## Jeffrey pines rooted in the granite, manzanita and huckleberry oak on the
## rocky ground, and logs and rocks on the duff.
func _dress() -> void:
	_reserve_entities(1, 3)
	_fringe_trees([Terrain.FIR], 3, 0.72, [["gp_red_fir", 5.0], ["gp_jeffrey", 2.5], ["gp_lodgepole", 1.0], ["gp_snag", 0.4], ["tree_white_fir", 1.0]], 1, 22.0)
	_fringe_trees([Terrain.SCRUB], 5, 0.45, [["gp_jeffrey", 2.0], ["gp_red_fir", 0.6], ["gp_snag", 0.5]], 1, 30.0)
	_fringe_trees([Terrain.GRANITE], 7, 0.3, [["gp_jeffrey", 1.0]], 1, 40.0)
	_fringe_trees([Terrain.MEADOW, Terrain.WET_MEADOW], 5, 0.3, [["gp_lodgepole", 1.0]], 1, 30.0)
	var all := Rect2i(0, 0, W, H)
	_scatter_decor("plant_manzanita", [Terrain.SCRUB], 70, all, 1)
	_scatter_decor("plant_shrub", [Terrain.SCRUB, Terrain.FIR], 50, all, 1)
	_scatter_decor("rock_granite", [Terrain.GRANITE, Terrain.SCRUB, Terrain.FIR], 60, all, 1)
	_scatter_decor("log_fallen", [Terrain.FIR], 14, all, 2)
	_scatter_decor("log_stump", [Terrain.FIR], 8, all, 1)
	_scatter_decor("plant_mushrooms", [Terrain.FIR], 6, all, 2)
	_scatter_decor("plant_wildflowers", [Terrain.MEADOW, Terrain.SCRUB], 16, all, 1)
	_scatter_decor("plant_lupine", [Terrain.MEADOW], 8, all, 1)
	_scatter_decor("plant_cornlily", [Terrain.MEADOW, Terrain.WET_MEADOW], 10, all, 0)
	_scatter_decor("plant_fern", [Terrain.WET_MEADOW], 6, all, 0)
