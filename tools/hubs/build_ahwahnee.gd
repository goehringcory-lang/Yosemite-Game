extends AhwahneeStyle
## Builds the walk from the Lamon Homestead to the Ahwahnee Hotel:
##
##   Lamon Homestead --north gate--> Stoneman Meadow trail (forest, meadow,
##   the Merced, Stoneman Bridge) --north--> The Ahwahnee (the hotel grounds
##   under the Royal Arches, with the Royal Arch Cascade).
##
## Run from the project folder:
##
##   godot --headless --path . res://tools/hubs/build_ahwahnee.tscn
##
## It rewrites scenes/regions/ahwahnee_trail.tscn and the_ahwahnee.tscn, the
## art in assets/sprites/ahwahnee/ (ahwahnee_hotel_art.gd, ahwahnee_land_art.gd,
## ahwahnee_flora_art.gd draw the sprites; ahwahnee_ground.gd paints the
## ground of both regions), and adds a north gate to the homestead the first
## time it runs. Put story NPCs in scenes/story/content/<region>.tscn (placed
## by marker name), not in the region scenes, so a rebuild keeps them.
##
## The layout is not to scale. The hotel itself has no inside yet: its doors
## are an interpretive sign.

const TRAIL_SCENE := "res://scenes/regions/ahwahnee_trail.tscn"
const GROUNDS_SCENE := "res://scenes/regions/the_ahwahnee.tscn"
const HOMESTEAD_SCENE := "res://scenes/regions/lamon_homestead.tscn"
const GEO_TRAIL := Vector2(-119.5760, 37.7440)
const GEO_HOTEL := Vector2(-119.5745, 37.7465)

var _hotel_consts := {}
var _land_consts := {}


func _ready() -> void:
	print("== Ahwahnee art")
	_load_art()
	import_assets()
	print("== Stoneman Meadow trail")
	_build_trail()
	print("== The Ahwahnee grounds")
	_build_grounds()
	print("== Homestead north gate")
	_patch_homestead()
	print("Done")
	get_tree().quit()


func _load_art() -> void:
	load_flora()
	var mods := [
		["res://tools/hubs/ahwahnee_hotel_art.gd", "_hotel_consts"],
		["res://tools/hubs/ahwahnee_land_art.gd", "_land_consts"],
	]
	for m: Array in mods:
		if not ResourceLoader.exists(m[0]):
			push_warning("Missing art module " + m[0])
			continue
		var script: GDScript = load(m[0])
		script.new().save_all()
		set(m[1], script.get_script_constant_map())


# ================================================================ TRAIL

const TW := 72
const TH := 84
const DECK_ROW := 32

var _trail_bridge_x0 := 30
var _trail_river_x0 := 40
var _trail_river_w := 12


func _trail_cx(y: float) -> float:
	var away := _smooth(0.0, 12.0, absf(y - 33.0) - 4.0)
	return _trail_river_x0 + _trail_river_w / 2.0 + away * (3.5 * sin((y - 33.0) * 0.07) + 1.6 * sin(y * 0.21))


func _layout_trail() -> void:
	init_grid(TW, TH, Terrain.FOREST)
	rng.seed = 1927
	noise.seed = 1927
	noise.frequency = 0.1
	var bridge_size: Vector2i = _land_consts.get("BRIDGE_SIZE", Vector2i(256, 112))
	var deck: Rect2i = _land_consts.get("BRIDGE_DECK", Rect2i(0, 48, 256, 32))
	var river_x: Vector2i = _land_consts.get("BRIDGE_RIVER_X", Vector2i(80, 176))
	_trail_river_w = (river_x.y - river_x.x) / T
	_trail_river_x0 = 40
	_trail_bridge_x0 = _trail_river_x0 - river_x.x / T
	var deck_tiles_x := bridge_size.x / T

	# Stoneman Meadow, west of the river.
	_ellipse(21.0, 37.0, 15.5, 21.0, Terrain.MEADOW, 0.3)
	_ellipse(30.0, 36.0, 6.0, 13.0, Terrain.WET_MEADOW, 0.35, [Terrain.MEADOW])
	# A small clearing on the far bank.
	_ellipse(62.0, 19.0, 6.0, 8.0, Terrain.MEADOW, 0.35)

	# The Merced, running north to south past the bridge.
	for y in TH:
		var cx := _trail_cx(y)
		var half := _trail_river_w / 2.0 + (0.0 if absf(y - 33.0) < 6.0 else noise.get_noise_1d(y * 1.5) * 0.9)
		for x in TW:
			if absf(x + 0.5 - cx) < half:
				put(x, y, Terrain.RIVER)
	# Gravel bars and banks.
	for y in TH:
		for x in TW:
			if at(x, y) in [Terrain.MEADOW, Terrain.FOREST, Terrain.WET_MEADOW] and _any_kind(x, y, [Terrain.RIVER], 1):
				if absf(y - DECK_ROW) > 3 and rng.randf() < 0.8:
					put(x, y, Terrain.SAND)

	# The trail: south forest, up into the meadow, to the bridge, and north.
	var west := [Vector2(13, 83), Vector2(13, 76), Vector2(16, 70), Vector2(21, 64), Vector2(24, 58), Vector2(25, 51),
		Vector2(23, 45), Vector2(23, 39), Vector2(26, 34.5), Vector2(_trail_bridge_x0 + 1, DECK_ROW)]
	_path(west, 2, Terrain.TRAIL, 0.9)
	var east_start := Vector2(_trail_bridge_x0 + deck_tiles_x - 2, DECK_ROW)
	var east := [east_start, Vector2(_trail_river_x0 + _trail_river_w + 7, DECK_ROW - 1), Vector2(59, 27), Vector2(59, 20),
		Vector2(62, 13), Vector2(62, 6), Vector2(63, 0)]
	_path(east, 2, Terrain.TRAIL, 0.8)
	# A spur down to the gravel bar for a look at the river.
	_path([Vector2(25, 46), Vector2(30, 47), Vector2(34, 48)], 1, Terrain.TRAIL, 0.4)
	# The deck itself.
	for ty in [DECK_ROW, DECK_ROW + 1]:
		for tx in range(_trail_bridge_x0, _trail_bridge_x0 + deck_tiles_x):
			put(tx, ty, Terrain.BRIDGE)
	# The bridge covers the trail's ends: make sure the ground under the
	# sprite (other than the river and deck) is dry.
	for ty in range(DECK_ROW - deck.position.y / T, DECK_ROW - deck.position.y / T + bridge_size.y / T):
		for tx in range(_trail_bridge_x0, _trail_bridge_x0 + deck_tiles_x):
			if tx * T >= (_trail_bridge_x0 * T + river_x.x) and tx * T < (_trail_bridge_x0 * T + river_x.y):
				if at(tx, ty) != Terrain.BRIDGE:
					put(tx, ty, Terrain.RIVER)
			elif at(tx, ty) in [Terrain.FOREST, Terrain.RIVER]:
				put(tx, ty, Terrain.SAND if (ty - DECK_ROW) < 3 else Terrain.MEADOW)

	# Under the bridge's stone face, on the land at either end: solid.
	for ty in range(DECK_ROW + 2, DECK_ROW - deck.position.y / T + bridge_size.y / T):
		for tx in range(_trail_bridge_x0, _trail_bridge_x0 + deck_tiles_x):
			var px_in := (tx - _trail_bridge_x0) * T
			if px_in < river_x.x or px_in >= river_x.y:
				put(tx, ty, Terrain.TALUS)

	# Trees keep off water, paths, and the open meadow.
	no_trees.resize(TW * TH)
	no_trees.fill(0)
	for y in TH:
		for x in TW:
			if at(x, y) in [Terrain.RIVER, Terrain.BRIDGE, Terrain.TRAIL, Terrain.SAND]:
				no_trees[y * TW + x] = 1


func _build_trail() -> void:
	_layout_trail()
	start_region("AhwahneeTrail", "ahwahnee_trail", "Stoneman Meadow", GEO_TRAIL)
	paint_ground()
	_save_ground_art("ground_trail", 1927)
	var bridge_size: Vector2i = _land_consts.get("BRIDGE_SIZE", Vector2i(256, 112))
	var deck: Rect2i = _land_consts.get("BRIDGE_DECK", Rect2i(0, 48, 256, 32))
	var front_y: int = _land_consts.get("BRIDGE_FRONT_Y", 80)
	var parapet: int = _land_consts.get("PARAPET_H", 8)
	var origin := Vector2(_trail_bridge_x0 * T, (DECK_ROW * T) - deck.position.y)

	_backdrop("stoneman_bridge_back", origin, -8)
	if _has("stoneman_bridge_front"):
		var front := Sprite2D.new()
		front.name = "BridgeFront"
		front.texture = texture(S + "stoneman_bridge_front.png")
		front.centered = false
		var deck_south := origin.y + deck.position.y + deck.size.y
		front.position = Vector2(origin.x, deck_south)
		front.offset = Vector2(0, front_y - deck.position.y - deck.size.y)
		_entities.add_child(front)
	# Parapets are solid (the river tiles beside the deck are blocked too).
	var wall := StaticBody2D.new()
	wall.name = "BridgeParapets"
	wall.collision_mask = 0
	wall.position = Vector2.ZERO
	_footprint_shape(wall, "North", Rect2(origin.x, origin.y + deck.position.y, deck.size.x, parapet))
	_footprint_shape(wall, "South", Rect2(origin.x, origin.y + deck.position.y + deck.size.y - parapet, deck.size.x, parapet))
	_entities.add_child(wall)

	_trail_props()
	_ambient("MeadowFireflies", "fireflies", Vector2(20, 38) * T, Vector2(9, 11) * T)
	_ambient("BankFireflies", "fireflies", Vector2(60, 16) * T, Vector2(5, 9) * T)
	_trail_markers_and_exits()
	place_blockers()
	add_forage("ahwahnee_trail", 2.0)
	for child in _root.get_children():
		_own(child, _root)
	pack(_root, TRAIL_SCENE)


func _trail_props() -> void:
	# Interpretive signs.
	_info_sign("StonemanMeadowSign", tile_pos(22, 49) + Vector2(0, 4), "Stoneman Meadow",
		"This meadow lies between the trees and the Merced River. Deer graze here at dawn and dusk, and in early summer it fills with lupine and shooting stars. Stay on the trail: meadow grasses are easily trampled.")
	_info_sign("StonemanBridgeSign", tile_pos(_trail_bridge_x0 - 1, DECK_ROW - 1) + Vector2(0, 6), "Stoneman Bridge",
		"This granite bridge was built in 1933 and carries the trail over the Merced with three graceful stone arches. The Ahwahnee Hotel stands beyond it, under the cliffs.")
	_info_sign("MercedOverlook", tile_pos(35, 47) + Vector2(0, 6), "The Merced River",
		"The Merced begins as snowmelt high above the Valley, drops over Nevada and Vernal Falls, and slides through the Valley floor here, slow and clear in late summer.")

	# Scenery. Trees first (they reserve nothing), then decoration.
	var forest_table := [["tree_ponderosa", 4.0], ["tree_incense_cedar", 3.5], ["tree_black_oak", 3.0], ["tree_white_fir", 1.2], ["tree_dogwood", 1.0]]
	_fringe_trees([Terrain.FOREST], 3, 0.72, forest_table, 2, 22.0)
	_fringe_trees([Terrain.MEADOW, Terrain.WET_MEADOW], 8, 0.32, [["tree_black_oak", 3.0], ["tree_dogwood", 1.0], ["tree_ponderosa", 0.8]], 3, 60.0)
	# Willows along the water.
	_fringe_trees([Terrain.SAND], 5, 0.6, [["tree_willow", 1.0]], 0, 44.0)
	# Meadow and forest-floor decoration.
	_scatter_decor("plant_wildflowers", [Terrain.MEADOW], 90, Rect2i(4, 14, 30, 44), 1)
	_scatter_decor("plant_lupine", [Terrain.MEADOW], 30, Rect2i(4, 14, 32, 44), 1)
	_scatter_decor("plant_tall_grass", [Terrain.MEADOW, Terrain.WET_MEADOW], 45, Rect2i(4, 14, 34, 44), 1)
	_scatter_decor("plant_cornlily", [Terrain.WET_MEADOW], 14, Rect2i(24, 20, 14, 30), 0)
	_scatter_decor("plant_cattails", [Terrain.SAND, Terrain.WET_MEADOW], 14, Rect2i(28, 10, 20, 70), 0)
	_scatter_decor("plant_fern", [Terrain.FOREST], 80, Rect2i(0, 56, 40, 28), 1)
	_scatter_decor("plant_bracken", [Terrain.FOREST], 40, Rect2i(0, 50, 64, 34), 1)
	_scatter_decor("plant_shrub", [Terrain.FOREST, Terrain.MEADOW], 40, Rect2i(0, 8, 64, 76), 2)
	_scatter_decor("plant_mushrooms", [Terrain.FOREST], 10, Rect2i(0, 56, 64, 28), 2)
	_scatter_decor("rock_granite", [Terrain.MEADOW, Terrain.FOREST, Terrain.SAND], 16, Rect2i(0, 8, 64, 76), 2)
	_scatter_decor("rock_mossy", [Terrain.FOREST], 8, Rect2i(0, 44, 64, 40), 2)
	_scatter_decor("rock_river", [Terrain.SAND], 18, Rect2i(26, 6, 30, 76), 0)
	_scatter_decor("log_fallen", [Terrain.FOREST, Terrain.MEADOW], 6, Rect2i(0, 10, 64, 74), 2)
	_scatter_decor("log_stump", [Terrain.FOREST], 6, Rect2i(0, 40, 64, 44), 2)
	_scatter_decor("tree_snag", [Terrain.FOREST], 3, Rect2i(0, 40, 64, 44), 3)
	# Rocks in the river itself, breaking the current.
	for i in 9:
		var ry := rng.randi_range(4, 78)
		if absf(ry - DECK_ROW) < 7:
			continue
		var cx := _trail_cx(ry)
		_prop(_pick("rock_river"), Vector2((cx + rng.randf_range(-1.5, 1.5)) * T, ry * T + 12.0))
	# A bench and a picnic spot with a view of the water.
	if _has("garden_bench"):
		_prop("garden_bench", foot(31, 46))
		_prop("garden_bench", foot(_trail_river_x0 + _trail_river_w + 3, DECK_ROW - 4))


func _trail_markers_and_exits() -> void:
	marker("south_entry", 13, 81)
	marker("north_entry", 63, 2)
	marker("bridge_west", _trail_bridge_x0 + 1, DECK_ROW + 0.5)
	marker("bridge_east", _trail_bridge_x0 + 18, DECK_ROW + 0.5)
	marker("meadow", 22, 40)
	marker("river_bank", 33, 47)
	place("Stoneman Meadow", 22, 37, 19)
	place("Merced River", 46, 50, 8, false)
	place("Stoneman Bridge", _trail_river_x0 + _trail_river_w / 2.0, DECK_ROW + 0.5, 9)
	place("Far bank", 62, 14, 12, false)
	region_exit("ToHomestead", tile_pos(13.5, TH - 0.5), Vector2(48, 12), "Lamon Homestead", "lamon_homestead", "north_gate")
	region_exit("ToAhwahnee", tile_pos(63.5, 0.0), Vector2(48, 12), "The Ahwahnee", "the_ahwahnee", "south_entry")


# ================================================================ GROUNDS

const GW := 96
const GH := 64
const HOTEL_BASE_ROW := 34
const HOTEL_CENTER_X := 52

var _ring: Array = []
var _soils: Array[Rect2i] = []
var _bed_spots: Array[Vector2] = [] # feet of the flower-bed sprites, in pixels
var _hotel_pos := Vector2.ZERO # top-left of the hotel sprite in pixels
var _door_x := 0.0 # px, world x of the front door
var _cx := 46 # tile x of the portico and the entrance circle


func _layout_grounds() -> void:
	init_grid(GW, GH, Terrain.FOREST)
	rng.seed = 1927
	noise.seed = 4471
	noise.frequency = 0.1
	_soils.clear()
	_bed_spots.clear()
	var size: Vector2i = _hotel_consts.get("HOTEL_SIZE", Vector2i(448, 200))
	var ground_y: int = _hotel_consts.get("HOTEL_GROUND_Y", size.y - 4)
	_hotel_pos = Vector2(HOTEL_CENTER_X * T + 8 - size.x / 2.0, HOTEL_BASE_ROW * T - ground_y)
	_door_x = _hotel_pos.x + float(_hotel_consts.get("HOTEL_DOOR_X", 150))
	_cx = int(_door_x / T)

	# The wall of the Valley, and the talus at its foot.
	fill(0, 0, GW - 1, 12, Terrain.CLIFF)
	fill(0, 13, GW - 1, 13, Terrain.TALUS)
	# Lawns: the great front lawn, the tea lawn west, the rose garden east.
	_ellipse(56.0, 45.0, 28.0, 13.5, Terrain.LAWN, 0.18)
	_ellipse(29.0, 41.0, 10.0, 8.0, Terrain.LAWN, 0.25)
	fill(61, 36, 77, 49, Terrain.LAWN)
	# The Ahwahnee Meadow, east of the hotel.
	_ellipse(89.0, 42.0, 9.5, 20.0, Terrain.MEADOW, 0.3)
	# The hotel's stone terrace along its front, and the forecourt.
	fill(int(_hotel_pos.x / T) + 1, HOTEL_BASE_ROW, int((_hotel_pos.x + size.x) / T) - 1, HOTEL_BASE_ROW + 1, Terrain.PAVED)
	fill(_cx - 5, HOTEL_BASE_ROW, _cx + 5, HOTEL_BASE_ROW + 2, Terrain.PAVED)
	# The entrance circle: a gravel ring around a lawn island.
	_ellipse(_cx + 0.5, 42.0, 10.5, 5.6, Terrain.PARKING)
	_ellipse(_cx + 0.5, 42.0, 7.3, 3.2, Terrain.LAWN)
	_ring = [(_cx + 0.5) * T, 42.0 * T, 10.5 * T, 5.6 * T, 7.3 * T, 3.2 * T]
	# The drive south, and the road in from the west.
	fill(_cx - 1, 46, _cx + 1, GH - 1, Terrain.PARKING)
	fill(0, 57, _cx, 59, Terrain.ROAD)
	fill(_cx - 1, 57, _cx + 1, 59, Terrain.PARKING)
	# Garden paths: from the terrace to the rose garden and the tea lawn.
	_path([Vector2(_cx + 11, 40), Vector2(62, 40), Vector2(68, 40)], 2, Terrain.PAVED)
	fill(62, 37, 76, 37, Terrain.PAVED)
	fill(62, 47, 76, 47, Terrain.PAVED)
	fill(62, 37, 62, 47, Terrain.PAVED)
	fill(76, 37, 76, 47, Terrain.PAVED)
	fill(69, 37, 69, 47, Terrain.PAVED)
	fill(62, 42, 76, 42, Terrain.PAVED)
	fill(68, 41, 70, 43, Terrain.PAVED)
	# Beds in the rose garden: one in each quarter, with soil to match.
	for q: Vector2i in [Vector2i(63, 38), Vector2i(70, 38), Vector2i(63, 43), Vector2i(70, 43)]:
		var mid := Vector2((q.x + 3) * T, (q.y + 2) * T)
		_bed_spots.append(mid + Vector2(0, 12))
		_soils.append(Rect2i(int(mid.x) - 28, int(mid.y) - 14, 56, 28))
	# Tea lawn terrace west.
	fill(24, 38, 34, 45, Terrain.PAVED)
	_path([Vector2(_cx - 9, 40), Vector2(34, 40)], 2, Terrain.PAVED)
	# Royal Arch Creek: from the plunge pool at the base of the cascade,
	# south through the woods, and out the west edge.
	var pool: Vector2i = _land_consts.get("POOL_POS", Vector2i(416, 210))
	var px := pool.x / T
	fill(px - 1, 13, px, 14, Terrain.LAKE)
	fill(px - 3, 15, px + 2, 16, Terrain.LAKE)
	var cx := float(px)
	var cy := 17
	while cy < 34:
		var c := cx + sin(cy * 0.35) * 1.4
		fill(int(c), cy, int(c) + 1, cy, Terrain.CREEK)
		cx = lerpf(cx, 8.0, 0.045)
		cy += 1
	_path([Vector2(cx, 34), Vector2(6, 35), Vector2(0, 36)], 2, Terrain.CREEK, 0.4)
	for y in range(0, GH):
		for x in GW:
			if at(x, y) in [Terrain.RIVER, Terrain.LAKE, Terrain.CREEK, Terrain.PARKING, Terrain.ROAD, Terrain.PAVED, Terrain.LAWN, Terrain.CLIFF, Terrain.TALUS]:
				no_trees[y * GW + x] = 1
	# Behind and beside the hotel: keep the sprite's shadow free of trees.
	no_trees.resize(GW * GH)
	for y in range(20, HOTEL_BASE_ROW + 1):
		for x in range(int(_hotel_pos.x / T) - 1, int((_hotel_pos.x + size.x) / T) + 2):
			no_trees[y * GW + x] = 1


func _build_grounds() -> void:
	_layout_grounds()
	start_region("TheAhwahnee", "the_ahwahnee", "The Ahwahnee", GEO_HOTEL)
	paint_ground()
	_save_ground_art("ground_hotel", 1927, [_ring], _soils)

	# The wall of the Valley with the Royal Arches, and the cascade.
	_backdrop("royal_arches_wall", Vector2.ZERO, -8)
	_cascade()

	_place_hotel()
	_grounds_gardens()
	_grounds_scenery()
	_ambient("MeadowFireflies", "fireflies", Vector2(89, 42) * T, Vector2(6, 12) * T)
	_ambient("CascadeSpray", "mist", Vector2(_land_consts.get("POOL_POS", Vector2i(182, 208))) + Vector2(0, 8), Vector2(28, 6))
	_grounds_markers_and_exits()
	place_blockers()
	add_forage("the_ahwahnee", 2.0)
	for child in _root.get_children():
		_own(child, _root)
	pack(_root, GROUNDS_SCENE)


func _cascade() -> void:
	var pos: Vector2i = _land_consts.get("CASCADE_POS", Vector2i(400, 20))
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", 8.0)
	frames.set_animation_loop("default", true)
	var n := 0
	while _has("cascade_%d" % n):
		frames.add_frame("default", texture(S + "cascade_%d.png" % n))
		n += 1
	if n > 0:
		var anim := AnimatedSprite2D.new()
		anim.name = "RoyalArchCascade"
		anim.sprite_frames = frames
		anim.centered = false
		anim.position = Vector2(pos)
		anim.z_index = -7
		anim.autoplay = "default"
		_root.add_child(anim)
	var pool: Vector2i = _land_consts.get("POOL_POS", Vector2i(416, 210))
	var m := 0
	var mist := SpriteFrames.new()
	mist.set_animation_speed("default", 5.0)
	mist.set_animation_loop("default", true)
	while _has("mist_%d" % m):
		mist.add_frame("default", texture(S + "mist_%d.png" % m))
		m += 1
	if m > 0:
		var puff := AnimatedSprite2D.new()
		puff.name = "CascadeMist"
		puff.sprite_frames = mist
		puff.centered = false
		puff.position = Vector2(pool) - Vector2(32, 28)
		puff.z_index = -6
		puff.autoplay = "default"
		puff.modulate = Color(1, 1, 1, 0.85)
		_root.add_child(puff)


func _place_hotel() -> void:
	var size: Vector2i = _hotel_consts.get("HOTEL_SIZE", Vector2i(448, 200))
	var body_rect: Rect2 = _hotel_consts.get("HOTEL_BODY", Rect2(8, size.y - 60, size.x - 16, 60))
	if not _has("hotel"):
		return
	# The hotel stands at the bottom center of its sprite; footprint is in
	# sprite pixels from its top-left.
	var ground_y: int = _hotel_consts.get("HOTEL_GROUND_Y", size.y - 4)
	var base := Vector2(_hotel_pos.x + size.x / 2.0, HOTEL_BASE_ROW * T)
	var local := Rect2(body_rect.position - Vector2(size.x / 2.0, ground_y), body_rect.size)
	var body := prop_body("Ahwahnee", S + "hotel.png", [local], Vector2.ZERO)
	(body.get_node("Sprite") as Sprite2D).offset.y = size.y / 2.0 - ground_y
	body.position = base
	_entities.add_child(body)
	_glow("hotel_glow", _hotel_pos)
	# Its doors read as a sign: you can't go in yet.
	_info("MainEntrance", Vector2(_door_x, HOTEL_BASE_ROW * T + 22), Vector2(56, 30), "The Ahwahnee",
		"The Ahwahnee opened in July 1927. Its architect, Gilbert Stanley Underwood, built it of granite, steel, and concrete stained to look like redwood, so that it would fit under the cliffs and never burn like the wooden hotels before it. The painted patterns on its beams and the stained glass inside were designed for it. It is a National Historic Landmark. The great doors are closed for now.")


func _grounds_gardens() -> void:
	# Fountain in the entrance circle.
	_prop("garden_fountain", foot(_cx, 42) + Vector2(0, -2), "EntranceFountain")
	# Gate posts and the hotel's sign at the foot of the drive.
	if _has("gate_post_a"):
		decor("GatePostWest", S + "gate_post_a.png", foot(_cx - 2, 62), Vector2(12, 6))
		decor("GatePostEast", S + "gate_post_b.png", foot(_cx + 2, 62), Vector2(12, 6))
	if _has("entrance_sign"):
		sign_prop("HotelSign", S + "entrance_sign.png", foot(_cx + 5, 62) + Vector2(0, -2), Vector2(30, 6), "The Ahwahnee",
			"The Ahwahnee Hotel. Guests have come up this drive since 1927.")
	# Lamps along the drive and terrace.
	var lamps := [[_cx - 4, 55], [_cx + 4, 55], [_cx - 4, 49], [_cx + 4, 49], [_cx - 12, 37], [_cx + 12, 37], [_cx - 8, 36], [_cx + 8, 36], [_cx + 11, 38], [_cx - 11, 38]]
	for l: Array in lamps:
		if _has("lamp_wrought"):
			decor("Lamp%d_%d" % [l[0], l[1]], S + "lamp_wrought.png", foot(l[0], l[1]), Vector2(6, 4))
			_glow("lamp_wrought_glow", foot(l[0], l[1]) - Vector2(5, _tex_h("lamp_wrought")))
	# The terrace: urns and topiary framing the doors, hedges in front.
	for dx in [-6, -3, 3, 6]:
		_prop(_pick("garden_urn"), foot(_cx + dx, HOTEL_BASE_ROW + 2) + Vector2(0, -2))
	for dx in [-8, 8]:
		_prop("garden_topiary", foot(_cx + dx, HOTEL_BASE_ROW + 2))
	# Hedge rows along the front of the great lawn and around the island.
	var hx0 := int(_hotel_pos.x / T) + 1
	for x in range(hx0, hx0 + 28, 2):
		if absi(x - _cx) > 6 and at(x, HOTEL_BASE_ROW + 3) == Terrain.LAWN:
			_prop("garden_hedge_h", foot(x, HOTEL_BASE_ROW + 3))
	# Rose garden: hedges on the outside of the path square, beds inside.
	for x in range(61, 78, 2):
		_prop("garden_hedge_h", foot(x, 36))
		_prop("garden_hedge_h", foot(x, 49))
	_prop("garden_arbor", foot(62, 43), "RoseArbor")
	_prop("garden_sundial", foot(69, 43), "Sundial")
	var bed_names := ["garden_flowerbed_a", "garden_flowerbed_b", "garden_flowerbed_c", "garden_flowerbed_a"]
	for i in _bed_spots.size():
		_prop(bed_names[i], _bed_spots[i])
	_prop("garden_bench", foot(65, 36) + Vector2(0, 2))
	_prop("garden_bench", foot(73, 48) + Vector2(0, 2))
	_prop("garden_birdbath", foot(76, 41))
	# The tea lawn: café tables under umbrellas, benches, urns.
	for p in [Vector2(26, 41), Vector2(31, 41), Vector2(28, 45)]:
		_prop("garden_table_umbrella", foot(p.x, p.y), "TeaTable%d" % int(p.x))
	_prop("garden_bench", foot(25, 37))
	_prop("garden_urn_a", foot(24, 39))
	_prop("garden_urn_b", foot(34, 39))
	# Signs.
	_info_sign("RoyalArchesSign", tile_pos(36, 34) + Vector2(0, 6), "Royal Arches",
		"The cliff behind the hotel is the Royal Arches, a stack of huge curved steps in the granite. Long routes climb up the Arches, and Camp 4 climbers speak of them with respect. To the right, the smooth wall is Washington Column.")
	_info_sign("CascadeSign", tile_pos(15, 19) + Vector2(0, 6), "Royal Arch Cascade",
		"Royal Arch Creek slides down the cliff in spring and early summer. By late summer it dries to a dark streak on the granite.")
	_info_sign("AhwahneeMeadowSign", tile_pos(81, 40) + Vector2(0, 6), "Ahwahnee Meadow",
		"The meadow east of the hotel is one of the best places in the Valley to watch the light change on the cliffs. Please stay on the trail.")


func _tex_h(sprite_name: String) -> int:
	return texture(S + sprite_name + ".png").get_height()


func _grounds_scenery() -> void:
	var forest_table := [["tree_ponderosa", 4.0], ["tree_incense_cedar", 3.5], ["tree_black_oak", 3.0], ["tree_white_fir", 1.2], ["tree_dogwood", 1.4]]
	_fringe_trees([Terrain.FOREST], 3, 0.7, forest_table, 2, 22.0)
	# Specimen trees framing the great lawn, each with room around it.
	var specimens := [["tree_black_oak_a", 32, 53], ["tree_dogwood_bloom_a", 33, 37], ["tree_black_oak_b", 78, 53], ["tree_dogwood_bloom_b", 81, 37],
		["tree_ponderosa_b", 85, 34], ["tree_black_oak_c", 24, 52], ["tree_dogwood_bloom_a", 58, 53], ["tree_ponderosa_a", 36, 54]]
	for sp: Array in specimens:
		_prop(sp[0], foot(sp[1], sp[2]))
	_fringe_trees([Terrain.MEADOW], 7, 0.5, [["tree_black_oak", 3.0], ["tree_dogwood", 1.0], ["tree_ponderosa", 1.0]], 2, 55.0)
	_scatter_decor("plant_wildflowers", [Terrain.MEADOW], 70, Rect2i(78, 22, 18, 40), 1)
	_scatter_decor("plant_lupine", [Terrain.MEADOW], 25, Rect2i(78, 22, 18, 40), 1)
	_scatter_decor("plant_tall_grass", [Terrain.MEADOW, Terrain.FOREST], 30, Rect2i(78, 22, 18, 40), 1)
	_scatter_decor("plant_fern", [Terrain.FOREST], 60, Rect2i(0, 16, GW, 46), 1)
	_scatter_decor("plant_bracken", [Terrain.FOREST], 30, Rect2i(0, 16, GW, 46), 1)
	_scatter_decor("plant_shrub", [Terrain.FOREST], 50, Rect2i(0, 16, GW, 46), 2)
	_scatter_decor("plant_cornlily", [Terrain.CREEK], 6, Rect2i(0, 16, 30, 24), 0)
	_scatter_decor("plant_mushrooms", [Terrain.FOREST], 8, Rect2i(0, 16, GW, 46), 2)
	_scatter_decor("rock_granite", [Terrain.FOREST, Terrain.MEADOW], 24, Rect2i(0, 14, GW, 48), 2)
	_scatter_decor("rock_mossy", [Terrain.FOREST], 12, Rect2i(0, 14, GW, 48), 2)
	_scatter_decor("rock_river", [Terrain.FOREST], 8, Rect2i(0, 16, 32, 22), 0)
	_scatter_decor("log_fallen", [Terrain.FOREST], 5, Rect2i(0, 16, GW, 46), 2)
	_scatter_decor("tree_snag", [Terrain.FOREST], 3, Rect2i(0, 16, GW, 46), 3)
	# Boulders and ferns around the plunge pool.
	var pool: Vector2i = _land_consts.get("POOL_POS", Vector2i(416, 210))
	for i in 10:
		_prop(_pick("rock_granite" if i % 2 == 0 else "rock_mossy"), Vector2(pool.x + rng.randf_range(-70.0, 70.0), 14 * T + rng.randf_range(20.0, 46.0)))
	for i in 12:
		_prop(_pick("plant_fern"), Vector2(pool.x + rng.randf_range(-80.0, 80.0), 16 * T + rng.randf_range(8.0, 60.0)))
	# Stepping stones across the creek where the tea-lawn path crosses it.
	for i in 5:
		_prop("rock_river_b", Vector2(9 * T + i * 12, 35 * T + 10 + (i % 2) * 3))


func _grounds_markers_and_exits() -> void:
	marker("south_entry", _cx, 61)
	marker("west_road", 3, 58)
	marker("front_door", _cx, HOTEL_BASE_ROW + 3)
	marker("entrance_circle", _cx, 46)
	marker("rose_garden", 69, 40)
	marker("tea_lawn", 28, 41)
	marker("ahwahnee_meadow", 88, 42)
	marker("cascade", int(_land_consts.get("POOL_POS", Vector2i(416, 210)).x / T), 18)
	place("The Ahwahnee", _cx, 38, 22)
	place("Entrance Circle", _cx, 42, 8, false)
	place("Rose Garden", 69, 42, 8)
	place("Tea Lawn", 28, 41, 7, false)
	place("Ahwahnee Meadow", 89, 42, 12)
	place("Royal Arch Cascade", int(_land_consts.get("POOL_POS", Vector2i(416, 210)).x / T), 17, 9)
	place("Royal Arches", 58, 8, 30)
	region_exit("ToStonemanBridge", tile_pos(_cx + 0.5, GH - 0.5), Vector2(64, 12), "Stoneman Bridge", "ahwahnee_trail", "north_entry")
	region_exit("NorthsideDriveWest", tile_pos(0, 58), Vector2(12, 56), "Northside Drive", "yosemite_valley", "the_ahwahnee")


# ================================================================ HOMESTEAD

## Opens a north gate in the homestead's hedge line, links it to the trail,
## and lays a dirt path up to it. Runs safely more than once: it only adds
## what is missing.
func _patch_homestead() -> void:
	var packed: PackedScene = load(HOMESTEAD_SCENE)
	var root: Node = packed.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var changed := false
	var ground: TileMapLayer = root.get_node("Ground")
	# The dirt of the east-west path is the pattern for the trail to the gate.
	var dirt_src := ground.get_cell_source_id(Vector2i(20, 11))
	var dirt_atlas := ground.get_cell_atlas_coords(Vector2i(20, 11))
	for x in [9, 10]:
		var src := ground.get_cell_source_id(Vector2i(x, 1))
		var atlas := ground.get_cell_atlas_coords(Vector2i(x, 1))
		# Open the top row of the hedge line.
		if ground.get_cell_source_id(Vector2i(x, 0)) != src or ground.get_cell_atlas_coords(Vector2i(x, 0)) != atlas:
			if ground.get_cell_atlas_coords(Vector2i(x, 0)) != dirt_atlas:
				ground.set_cell(Vector2i(x, 0), src, atlas)
				changed = true
	for y in range(0, 6):
		for x in [9, 10]:
			if ground.get_cell_atlas_coords(Vector2i(x, y)) != dirt_atlas:
				ground.set_cell(Vector2i(x, y), dirt_src, dirt_atlas)
				changed = true
	if not root.has_node("Exits/NorthToAhwahnee"):
		var exit_area := Area2D.new()
		exit_area.name = "NorthToAhwahnee"
		exit_area.set_script(load("res://scripts/world/region_exit.gd"))
		exit_area.position = Vector2(160, 6)
		exit_area.set("label", "The Ahwahnee")
		exit_area.set("target_region", "ahwahnee_trail")
		exit_area.set("target_spawn", "south_entry")
		var shape := CollisionShape2D.new()
		shape.name = "Shape"
		var r := RectangleShape2D.new()
		r.size = Vector2(28, 10)
		shape.shape = r
		exit_area.add_child(shape)
		root.get_node("Exits").add_child(exit_area)
		var spawn := Marker2D.new()
		spawn.name = "north_gate"
		spawn.position = Vector2(160, 30)
		root.get_node("Spawns").add_child(spawn)
		var door: Node2D = (load("res://scenes/objects/region_door.tscn") as PackedScene).instantiate()
		door.name = "NorthTrailSign"
		door.position = Vector2(184, 22)
		door.set("label", "The Ahwahnee")
		door.set("target_region", "ahwahnee_trail")
		door.set("target_spawn", "south_entry")
		root.get_node("Entities").add_child(door)
		exit_area.owner = root
		shape.owner = root
		spawn.owner = root
		door.owner = root
		changed = true
	if not changed:
		print("the homestead already has its north gate")
		root.free()
		return
	var out := PackedScene.new()
	assert(out.pack(root) == OK)
	save_resource(out, HOMESTEAD_SCENE)
	root.free()
