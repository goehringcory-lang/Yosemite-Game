extends AhwahneeStyle
## Builds Curry Village, the first place you walk into after the Lamon
## Homestead gate: the tent cabins, the Camp Curry plaza with its Registration
## Office, Pavilion, Store and Pizza Deck, the Mountain Shop, the pool and the
## amphitheater, and the old apple orchard on the way to your camp. The
## Store and the Mountain Shop have inside rooms of their own.
## Run from the project folder:
##
##   godot --headless --path . res://tools/hubs/build_curry.tscn
##
## It rewrites scenes/regions/curry_village.tscn, curry_store.tscn and
## curry_mountain_shop.tscn, the art in assets/sprites/curry/, the two shops'
## data and the store's foods. Put story NPCs in
## scenes/story/content/<region>.tscn (placed by marker name), not in the
## region scenes, so a rebuild keeps them.
##
## The layout is not to scale: it squeezes Curry Village's few hundred tent
## cabins into a few dozen, in the real order: the granite wall behind, the
## cabins below it, the Camp Curry buildings in the middle, Stoneman Meadow and
## the Merced in front.

const CurryArt = preload("res://tools/hubs/curry_ahwahnee_art.gd")
const HotelArt = preload("res://tools/hubs/ahwahnee_hotel_art.gd")
const ValleyLandArt = preload("res://tools/hubs/valley_land_art.gd")
const InteriorArt = preload("res://tools/hubs/interior_ahwahnee_art.gd")
const CS := "res://assets/sprites/curry/"
const I := "res://assets/sprites/curry/interiors/"
const VILLAGE_SCENE := "res://scenes/regions/curry_village.tscn"
const STORE_SCENE := "res://scenes/regions/curry_store.tscn"
const SHOP_SCENE := "res://scenes/regions/curry_mountain_shop.tscn"
const GEO := Vector2(-119.5728, 37.7385)

## The three curving rows of tent cabins: base y at x = 0, then how far the
## row swings and how fast.
const ROWS := [[14.0, 1.3, 0.085, 0.0], [19.6, 1.4, 0.07, 1.9], [25.2, 1.2, 0.09, 3.7]]
## The walk up the middle, kept clear of cabins.
const NO_TENT_X := Vector2(36.5, 43.5)

var _tents := 0
var _paths: Array = []   # winding paths for the ground painting
var _paint_kind := PackedInt32Array()  # the terrain before paths were marked in it


func _ready() -> void:
	print("== Curry Village art")
	CurryArt.new().save_all()
	InteriorArt.new().save_all()
	HotelArt.new().save_all()
	load_flora()
	_layout()
	import_assets()
	print("== data")
	_build_foods()
	_build_shops()
	print("== Curry Village region")
	_build_village()
	print("== Curry Store")
	_build_store()
	print("== Mountain Shop")
	_build_mountain_shop()
	print("Done")
	get_tree().quit()


# ---------------------------------------------------------------- data

func _build_foods() -> void:
	var sheet := texture(CS + "store_foods.png")
	var foods := [
		["pilot_bread", "Pilot Bread", "Big round crackers, hard as a board and just as durable. Climbers have carried them up walls since before the war.", 0],
		["cheddar_wedge", "Cheddar Wedge", "A wedge of sharp cheddar in wax paper. Rich, dense and worth its weight on a long pitch.", 1],
		["dried_apricots", "Dried Apricots", "Sun-dried and chewy. A little sweet, a little tart, and they keep for weeks.", 2],
		["beef_jerky", "Beef Jerky", "Salty strips that last a season in a pack. Chewy, and easy to eat on the move.", 3],
		["chocolate_bar", "Chocolate Bar", "A thick bar wrapped in foil. Melts in August, so keep it in the shade.", 4],
	]
	for food: Array in foods:
		var item := ItemData.new()
		item.id = food[0]
		item.display_name = food[1]
		item.description = food[2]
		var icon := AtlasTexture.new()
		icon.atlas = sheet
		icon.region = Rect2(food[3] * 16, 0, 16, 16)
		item.icon = icon
		save_resource(item, "res://data/food/%s.tres" % food[0])


func _offer(kind_name: String, id: String, price: int, requires := {}, max_owned := 0, amount := 1) -> ShopOffer:
	var offer := ShopOffer.new()
	offer.kind = kind_name
	offer.id = id
	offer.price = price
	offer.requires = requires
	offer.max_owned = max_owned
	offer.amount = amount
	return offer


func _shop(keeper: String, greeting: String, nothing_yet: String, offers: Array, talk_target := "") -> ShopData:
	var shop := ShopData.new()
	shop.keeper = keeper
	shop.talk_target = talk_target
	shop.greeting = greeting
	shop.nothing_yet = nothing_yet
	for offer: ShopOffer in offers:
		shop.offers.append(offer)
	return shop


## Prices are food energy. The store swaps fresh forage for food that keeps;
## the Mountain Shop rounds out a rack, but the piece that opens a new climbing
## tier still comes from a quest (docs/DESIGN.md).
func _build_shops() -> void:
	save_resource(_shop("Camp Curry Store clerk",
		"Morning! Fresh forage on the counter and I'll put food that keeps in your pack. Everything here travels well.",
		"We're all out. Deliveries come up the road tomorrow.",
		[_offer("item", "pilot_bread", 30), _offer("item", "dried_apricots", 26), _offer("item", "chocolate_bar", 36),
		_offer("item", "cheddar_wedge", 40), _offer("item", "beef_jerky", 46), _offer("item", "trail_mix", 40),
		_offer("item", "dried_apples", 20)]),
		"res://data/shops/curry_store.tres")
	# The clerk, Marty Kessler, is also a quest giver (data/characters/staff/).
	save_resource(_shop("Marty Kessler",
		"Welcome to the Mountain Shop. We outfit half the climbers in the Valley. Rope, cams, draws... we take food in trade, same as everyone up here.",
		"That's all I can trade you today. Once you've got a rope of your own, come back and I'll round out your rack.",
		[_offer("gear", "quickdraw", 28, {"rope": 1}, 12, 2),
		_offer("gear", "cam", 48, {"cam": 2}, 10),
		_offer("gear", "haul_bag", 76, {"aiders": 1}, 1),
		_offer("gear", "ascenders", 60, {"aiders": 1}, 1),
		_offer("gear", "portaledge", 130, {"haul_bag": 1, "ascenders": 1}, 1)], "mountain_shop"),
		"res://data/shops/curry_mountain_shop.tres")


# ---------------------------------------------------------------- Curry Village

func _row_y(row: Array, x: float) -> float:
	return row[0] + row[1] * sin(x * row[2] + row[3])


## Adds a winding path: painted as a smooth band and marked in the terrain
## grid so nothing grows on it.
func _add_path(points: Array, width: float, path_kind := "dirt") -> void:
	var pts := PackedVector2Array()
	for p: Vector2 in points:
		pts.append(p)
	_paths.append({"points": pts, "width": width, "kind": path_kind})
	var type := Terrain.PAVED if path_kind == "cobble" else Terrain.TRAIL
	for i in pts.size() - 1:
		var steps := int(pts[i].distance_to(pts[i + 1]) * 2.0) + 1
		for s in steps + 1:
			var q := pts[i].lerp(pts[i + 1], float(s) / steps)
			var r := width / 2.0
			for dy in range(int(-r) - 1, int(r) + 2):
				for dx in range(int(-r) - 1, int(r) + 2):
					if Vector2(dx, dy).length() <= r + 0.3:
						var tx := int(q.x) + dx
						var ty := int(q.y) + dy
						if tx >= 0 and ty >= 0 and tx < w and ty < h and not Terrain.is_solid(at(tx, ty)) and at(tx, ty) != Terrain.ROAD and at(tx, ty) != Terrain.PARKING and at(tx, ty) != Terrain.BUILT:
							put(tx, ty, type)
							no_trees[ty * w + tx] = 1


func _curve(points: Array, samples := 8) -> Array:
	# Catmull-Rom through the points, for paths that bend gently.
	var out: Array = []
	for i in points.size() - 1:
		var p0: Vector2 = points[maxi(i - 1, 0)]
		var p1: Vector2 = points[i]
		var p2: Vector2 = points[i + 1]
		var p3: Vector2 = points[mini(i + 2, points.size() - 1)]
		for s in samples:
			var t := float(s) / samples
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	out.append(points[-1])
	return out


func _layout() -> void:
	init_grid(100, 64, Terrain.FOREST)
	_paths.clear()
	rng.seed = 1899
	noise.seed = 1899
	noise.frequency = 0.12
	# The wall behind Camp Curry, with talus at its foot and Staircase Falls.
	for x in w:
		var base := 3 + int(noise.get_noise_1d(x * 3.0) * 1.5)
		fill(x, 0, x, base, Terrain.CLIFF)
		fill(x, base + 1, x, base + 2 + int(absf(noise.get_noise_1d(x * 5.0)) * 3.0), Terrain.TALUS)
	fill(70, 0, 72, 5, Terrain.FALLS)
	fill(69, 6, 73, 6, Terrain.TALUS)
	# The village green in the middle, with flagstones under the buildings.
	fill(26, 28, 78, 50, Terrain.MEADOW)
	fill(29, 31, 76, 36, Terrain.BUILT)
	# Parking and the road in.
	fill(3, 41, 23, 49, Terrain.PARKING)
	fill(0, 51, w - 1, 51, Terrain.ROAD)
	fill(22, 46, 24, 50, Terrain.ROAD)
	# Stoneman Meadow and the sand along the river.
	fill(0, 52, 99, 59, Terrain.MEADOW)
	fill(45, 55, 52, 57, Terrain.WET_MEADOW)
	fill(76, 60, 90, 60, Terrain.SAND)
	fill(10, 60, 22, 60, Terrain.SAND)
	# The old Lamon orchard on the way to the homestead gate.
	fill(79, 26, 99, 48, Terrain.MEADOW)
	# The Merced along the bottom.
	var water := PackedByteArray()
	water.resize(w * h)
	for x in w:
		var bank := 61 + int(noise.get_noise_1d(x * 2.0 + 40.0) * 1.2)
		for y in range(bank, h):
			water[y * w + x] = 1
	for k in w * h:
		if water[k]:
			kind[k] = Terrain.RIVER
	_paint_kind = kind.duplicate()
	# Cobbled walks around the village green.
	_add_path([Vector2(29, 37.6), Vector2(76, 37.6)], 2.0, "cobble")                # along the shop fronts
	_add_path(_curve([Vector2(40, 37.6), Vector2(40.6, 30), Vector2(40, 24), Vector2(40.8, 17), Vector2(40, 11)]), 2.6, "cobble")  # up between the cabins
	var ring: Array = []
	for i in 25:
		var a := TAU * i / 24.0
		ring.append(Vector2(52.0 + cos(a) * 13.0, 42.3 + sin(a) * 4.4))
	_add_path(ring, 1.7, "cobble")                                                    # around the fire pit
	_add_path([Vector2(52, 37.6), Vector2(52, 38.5)], 1.7, "cobble")
	_add_path(_curve([Vector2(40, 38), Vector2(41, 43), Vector2(40, 49)]), 2.0, "cobble")  # down to the pizza deck
	_add_path(_curve([Vector2(66, 38), Vector2(65.5, 43), Vector2(66, 49)]), 2.0, "cobble")  # down to the amphitheater
	_add_path(_curve([Vector2(24, 47), Vector2(28, 43.5), Vector2(34, 40), Vector2(38.5, 38.6)]), 2.4, "cobble")  # from the parking lot
	# Dirt paths: through the orchard, out to the meadow, and along the cabin rows.
	_add_path(_curve([Vector2(77, 38.2), Vector2(84, 39), Vector2(91, 37.6), Vector2(99, 38.2)]), 2.0)
	_add_path(_curve([Vector2(52, 47), Vector2(52.5, 50), Vector2(53, 53), Vector2(55, 58)]), 1.7)
	_add_path(_curve([Vector2(61, 41), Vector2(68, 44), Vector2(72, 47)]), 1.4)
	for row: Array in ROWS:
		var pts: Array = []
		for x in range(6, 84, 6):
			pts.append(Vector2(x, _row_y(row, x) + 1.6))
		_add_path(_curve(pts), 1.8)
	for cx in [9.0, 28.0, 59.0, 79.0]:
		var vpts: Array = []
		for y in range(9, 31, 4):
			vpts.append(Vector2(cx + sin(y * 0.4 + cx) * 0.8, y))
		_add_path(_curve(vpts), 1.6)
	_add_path(_curve([Vector2(6, 27), Vector2(6, 38), Vector2(5, 44)]), 1.6)
	# Keep trees and plants off paths, paving, roads, and water.
	for k in w * h:
		if water[k] or kind[k] in [Terrain.PARKING, Terrain.PAVED, Terrain.BUILT, Terrain.ROAD, Terrain.TRAIL]:
			no_trees[k] = 1
	clear_trees(28, 28, 78, 50)


func _build_village() -> void:
	start_region("CurryVillage", "curry_village", "Curry Village", GEO)
	paint_ground()
	# The village green is a mown lawn in the picture (it stays meadow in the
	# terrain grid, which drives foraging).
	var real_kind := kind.duplicate()
	for y in range(28, 51):
		for x in range(26, 79):
			if at(x, y) == Terrain.MEADOW:
				put(x, y, Terrain.LAWN)
	_save_ground_art("ground_curry_village", 1899)
	kind = real_kind
	_place_wall()
	_place_plaza()
	_place_cabins()
	_place_life()
	_place_orchard()
	_place_markers_and_exits()
	_dress_village()
	place_blockers()
	add_forage("curry_village", 3.0)
	pack(_root, VILLAGE_SCENE)


## The granite wall below Glacier Point, drawn for the cliff outline above,
## with Staircase Falls animated down it and mist where it lands.
func _place_wall() -> void:
	var prof := PackedInt32Array()
	prof.resize(w * T)
	for x in w:
		var rows := 0
		while rows < h and kind[rows * w + x] in [Terrain.CLIFF, Terrain.FALLS]:
			rows += 1
		for px_ in T:
			prof[x * T + px_] = rows * T
	var fall_cx := 71 * T + 8
	var fall_h := 6 * T
	ValleyLandArt.new().save_village(prof, fall_cx, CS, "curry", fall_h)
	import_assets()
	_backdrop("curry_wall", Vector2.ZERO, -8, CS)
	_animation("StaircaseFalls", "curry_fall", 8.0, Vector2(fall_cx - ValleyLandArt.FALL_W / 2.0, 0), -7, CS)
	_animation("FallMist", "curry_mist", 5.0, Vector2(fall_cx - 32, fall_h - 28 + 6), -6, CS)


## Trees, plants, rocks and logs: the same dressing as the Ahwahnee grounds,
## laid over this map's terrain.
func _dress_village() -> void:
	_reserve_entities(1, 2)
	var forest_table := [["tree_ponderosa", 4.0], ["tree_incense_cedar", 3.5], ["tree_black_oak", 3.2], ["tree_white_fir", 1.2], ["tree_dogwood", 1.4]]
	_fringe_trees([Terrain.FOREST], 3, 0.7, forest_table, 2, 22.0)
	_fringe_trees([Terrain.TALUS], 4, 0.4, [["tree_incense_cedar", 2.0], ["tree_snag", 0.6], ["tree_white_fir", 1.0]], 0, 30.0)
	_fringe_trees([Terrain.MEADOW], 8, 0.3, [["tree_black_oak", 3.0], ["tree_dogwood", 1.0]], 2, 70.0)
	# Stoneman Meadow and the old orchard: wildflowers and tall grass.
	var meadow := Rect2i(0, 52, 100, 8)
	_scatter_decor("plant_wildflowers", [Terrain.MEADOW], 55, meadow, 1)
	_scatter_decor("plant_lupine", [Terrain.MEADOW], 14, meadow, 1)
	_scatter_decor("plant_paintbrush", [Terrain.MEADOW], 8, meadow, 1)
	_scatter_decor("plant_tall_grass", [Terrain.MEADOW, Terrain.WET_MEADOW], 30, meadow, 1)
	_scatter_decor("plant_cattails", [Terrain.WET_MEADOW], 6, meadow, 0)
	var orchard := Rect2i(79, 26, 21, 23)
	_scatter_decor("plant_wildflowers", [Terrain.MEADOW], 30, orchard, 1)
	_scatter_decor("plant_tall_grass", [Terrain.MEADOW], 24, orchard, 1)
	# The forest floor between the cabins and along the wall.
	var all := Rect2i(0, 0, w, h)
	_scatter_decor("plant_fern", [Terrain.FOREST], 90, all, 1)
	_scatter_decor("plant_bracken", [Terrain.FOREST], 36, all, 1)
	_scatter_decor("plant_shrub", [Terrain.FOREST], 64, all, 2)
	_scatter_decor("plant_manzanita", [Terrain.TALUS], 8, Rect2i(0, 3, w, 10), 0)
	_scatter_decor("plant_mushrooms", [Terrain.FOREST], 8, all, 2)
	_scatter_decor("rock_granite", [Terrain.FOREST, Terrain.TALUS], 26, all, 2)
	_scatter_decor("rock_mossy", [Terrain.FOREST], 14, all, 2)
	_scatter_decor("rock_river", [Terrain.SAND], 14, all, 0)
	_scatter_decor("log_fallen", [Terrain.FOREST], 5, all, 2)
	_scatter_decor("tree_snag", [Terrain.FOREST], 3, all, 3)
	# Specimen oaks on the green for shade.
	for oak in [[31, 41, "a"], [70, 43, "b"], [56, 49, "c"], [77, 49, "a"], [27, 47, "b"]]:
		_prop("tree_black_oak_" + oak[2], foot(oak[0], oak[1]))
	_ambient("OrchardFireflies", "fireflies", Vector2(90, 38) * T, Vector2(18, 20) * T)


func _place_plaza() -> void:
	# The Camp Curry buildings, in a row along the top of the green. Two of
	# them have doors you can walk through.
	building("Registration", CS + "registration.png", 34, 35, "Registration Office",
		"Camp Curry's front desk, where every guest signs in. It stands about where David and Jennie Curry pitched their first seven tents in 1899.")
	building("Pavilion", CS + "pavilion.png", 46, 35, "Pavilion",
		"The Pavilion is Curry Village's big dining hall, with long tables and a menu that changes with the season. Its steep roof sheds the heavy Valley snows.")
	building("CurryStore", CS + "store.png", 56, 35, "Camp Curry Store",
		"Groceries, ice, postcards and camp supplies. Bring forage and the clerk will trade you food that keeps.", 12, 0)
	building("MountainShop", CS + "mountain_shop.png", 66, 35, "Mountain Shop",
		"The Mountain Shop outfits climbers for the Valley walls and hosts the Yosemite Mountaineering School. The ropes, cams and slings inside are for trade.", 14, 0)
	for glow in [["Registration", Vector2(0, -22), 60.0], ["Pavilion", Vector2(0, -22), 84.0], ["CurryStore", Vector2(0, -18), 46.0], ["MountainShop", Vector2(0, -20), 54.0]]:
		night_light(_entities.get_node(glow[0]), glow[1], glow[2], 0.9)
	# Smoke from the chimneys, mist at the foot of Staircase Falls, sparks over the fire pit.
	ambient(_entities.get_node("Registration"), "smoke", Vector2(-27, -62), Vector2(2, 1))
	ambient(_entities.get_node("Pavilion"), "smoke", Vector2(35, -64), Vector2(2, 1))
	ambient(_entities.get_node("MountainShop"), "smoke", Vector2(23, -64), Vector2(2, 1))
	ambient(_root, "mist", tile_pos(71, 6.2), Vector2(22, 5))
	ambient(_root, "fireflies", tile_pos(66, 56), Vector2(560, 44))
	var store_door := region_exit("ToStore", foot(56, 35) - Vector2(0, 4), Vector2(12, 6), "Camp Curry Store", "curry_store", "door")
	store_door.set("open_hour", 7)
	store_door.set("close_hour", 21)
	var shop_door := region_exit("ToMountainShop", foot(66, 35) - Vector2(0, 4), Vector2(14, 6), "Mountain Shop", "curry_mountain_shop", "door")
	shop_door.set("open_hour", 8)
	shop_door.set("close_hour", 18)
	# South of the green: the pizza deck, the pool, the amphitheater.
	building("PizzaDeck", CS + "pizza_deck.png", 40, 50, "Pizza Deck",
		"Wood-fired pizza on a deck under the wall, with a view across the green. A Curry Village favorite for a generation.", 0, 0, 0.5)
	var pool := decor("Pool", CS + "pool.png", foot(29, 49), Vector2(64, 30))
	var pool_sprite := pool.get_node("Sprite") as Sprite2D
	pool_sprite.set_script(load("res://scripts/world/seasonal_sprite.gd"))
	pool_sprite.set("winter_texture", texture(CS + "ice_rink.png"))
	building("Amphitheater", CS + "amphitheater.png", 66, 50, "Camp Curry Amphitheater",
		"Ranger programs and campfire talks are held here most summer evenings.", 0, 0, 0.2)
	sign_prop("FirefallBoard", CS + "firefall_board.png", foot(57, 48), Vector2(24, 6), "The Firefall",
		"Starting in the 1870s, embers from a bonfire were pushed off Glacier Point at nightfall, and Camp Curry crowds cheered from below. The show lapsed in the 1890s, and David Curry brought it back. David Curry's call went up to the rim: 'Hello, Glacier!' and then, 'Let the fire fall!' The Park Service ended it on January 25, 1968.")
	# The green's centre: a fire pit ringed by benches, the flag, lamps.
	var fire := instance_scene("res://scenes/story/station.tscn", Vector2(52 * T + 8, 42.3 * T + 8), "PlazaFirePit")
	fire.set("station", "campfire")
	fire.set("display_name", "Curry Village fire pit")
	night_light(fire, Vector2(0, -6), 70.0, 1.2, 0.35)
	ambient(fire, "sparks", Vector2(0, -8), Vector2(3, 1))
	animate(decor("Flagpole", CS + "flagpole.png", foot(45.5, 39), Vector2(6, 4)), 3, 2.5)
	for lamp in [[33, 38.6], [47, 38.6], [61, 38.6], [72, 38.6], [40.2, 44.5], [65.5, 44.5], [30, 45], [74, 46], [54.6, 47.5]]:
		_lamp("Lamp%d_%d" % [lamp[0], int(lamp[1] * 10)], lamp[0], lamp[1])
	for bench in [[46.5, 43.6, 0], [57.5, 43.6, 1], [52, 46.6, 2], [52, 39.6, 3]]:
		_prop("garden_bench", foot(bench[0], bench[1]) + Vector2(0, 2), "Bench%d" % bench[2])
	for planter in [[30, 36.2], [37.5, 36.2], [43, 36.2], [50, 36.2], [52.2, 36.2], [60.2, 36.2], [62, 36.2], [70, 36.2], [74.5, 36.2]]:
		decor("Planter%d" % int(planter[0] * 10), CS + "planter.png", foot(planter[0], planter[1]), Vector2(12, 5))
	decor("BikeRack", CS + "bike_rack.png", foot(46, 48.4), Vector2(30, 5))
	decor("Fountain", CS + "fountain.png", foot(74.5, 42), Vector2(10, 5))
	# Patio tables in front of the Pavilion and the pizza deck.
	for tbl in [[44, 40.6], [49, 40.8], [37, 47], [44.6, 47.6], [61, 41]]:
		decor("PatioTable%d" % int(tbl[0] * 10), CS + "patio_table.png", foot(tbl[0], tbl[1]), Vector2(14, 6))
	# Strings of lights between the lamp posts along the shop fronts.
	for span in [[33, 47], [47, 61], [61, 72]]:
		overhead("Lights%d" % span[0], CS + "string_lights_%d.png" % ((span[1] - span[0]) * T), Vector2((span[0] + span[1]) / 2.0 * T + 8, 38.6 * T + 8))


## A wrought-iron lamp, as at the Ahwahnee, with its dusk glow and a light
## that falls on the ground around it.
func _lamp(lamp_name: String, x: float, y: float) -> void:
	var post := decor(lamp_name, S + "lamp_wrought.png", foot(x, y), Vector2(6, 4))
	night_light(post, Vector2(0, -26), 50.0, 1.0)
	_glow("lamp_wrought_glow", foot(x, y) - Vector2(5, texture(S + "lamp_wrought.png").get_height()))


func _place_cabins() -> void:
	for ri in ROWS.size():
		var row: Array = ROWS[ri]
		var x := 8.0 + rng.randf() * 2.0
		while x <= 82.0:
			var tx := x + rng.randf_range(-0.7, 0.7)
			var pitch := 4.1 + rng.randf() * 1.2
			# Leave the middle walk, the connecting paths, and the falls' way clear.
			var blocked := (tx > NO_TENT_X.x and tx < NO_TENT_X.y)
			for cx in [9.0, 28.0, 59.0, 79.0]:
				if absf(tx - cx) < 3.0:
					blocked = true
			if blocked:
				x += 1.5
				continue
			var closed: bool = ri == 0 and tx > 60
			_cabin(tx, _row_y(row, tx) + rng.randf_range(-0.3, 0.5), _tents, closed)
			_tents += 1
			x += pitch
	# A block of cabins west of the green, above the parking lot.
	for ry in [30.6, 35.4, 39.8]:
		var wx := 8.0 + rng.randf()
		while wx < 24.0:
			_cabin(wx + rng.randf_range(-0.5, 0.5), ry + rng.randf_range(-0.3, 0.4), _tents, false)
			_tents += 1
			wx += 4.4 + rng.randf() * 0.8
	# Second-rank cabins tucked up among the trees behind the first row.
	for i in 12:
		var bx := 10.0 + i * 6.1 + rng.randf_range(-0.8, 0.8)
		if bx > NO_TENT_X.x - 3 and bx < NO_TENT_X.y + 3:
			continue
		if absf(bx - 28.0) < 3.0 or absf(bx - 59.0) < 3.0 or absf(bx - 79.0) < 3.0:
			continue
		_cabin(bx, 10.4 + rng.randf() * 0.8, _tents, bx > 60)
		_tents += 1
	# Wood cabins along the west and east edges.
	for spot in [[5, 28], [82, 27], [4, 34], [88, 28]]:
		var cabin := prop_body("Cabin%d_%d" % [spot[0], spot[1]], CS + "cabin_%s.png" % ["a", "b"][int(spot[0]) % 2], [base_rect(Vector2(34, 10))])
		cabin.position = foot(spot[0], spot[1])
		_entities.add_child(cabin)
	# The closed cabins: a rope, and a sign about the rockfalls.
	for i in 5:
		decor("CabinRope%d" % i, CS + "rope_fence.png", foot(62.5 + i * 3.6, 12.4), Vector2(14, 3))
	sign_prop("ClosedSign", CS + "trail_post_closed.png", foot(60, 13.5), Vector2(8, 4), "Cabins closed",
		"The cabins nearest the wall have stood empty since rockfalls. Granite slabs peel off the cliff without warning. In 2008 a fall from the wall above led the Park Service to close the cabins closest to it.")
	sign_prop("CabinRowsSign", CS + "trail_post_cabins.png", foot(38.2, 22), Vector2(8, 4), "Tent cabin rows",
		"Row after row of canvas tent cabins, each with a wood platform and a bed frame inside. In summer every one is booked. Curry Village started with seven tents in 1899.")
	# Woodpiles, coolers, stumps and clotheslines beside the tents.
	for i in 22:
		var cx := 8.0 + rng.randf() * 74.0
		var ri := int(rng.randf() * 3.0)
		var cy := _row_y(ROWS[ri], cx) + 2.9
		if cx > NO_TENT_X.x - 1 and cx < NO_TENT_X.y + 1:
			continue
		match rng.randi() % 4:
			0:
				decor("Woodpile%d" % i, CS + "woodpile.png", foot(cx, cy), Vector2(18, 6))
			1:
				decor("Cooler%d" % i, CS + "cooler.png", foot(cx, cy), Vector2(12, 5))
			2:
				decor("Stump%d" % i, CS + "stump.png", foot(cx, cy), Vector2(10, 5))
			3:
				decor("Clothesline%d" % i, CS + "clothesline.png", foot(cx, cy), Vector2(32, 5))
	for lamp in [[9, 17], [27, 22], [59, 17], [79, 22], [41.6, 22], [41.6, 14], [9, 27], [28, 27], [59, 27]]:
		_lamp("PathLamp%d_%d" % [lamp[0], int(lamp[1] * 10)], lamp[0], lamp[1])
	for bear in [[12, 22], [32, 17], [50, 26], [72, 23], [24, 28]]:
		decor("BearBox%d" % bear[0], "res://assets/sprites/buildings/bear_box.png", foot(bear[0], bear[1]), Vector2(14, 6))


func _cabin(tx: float, ty: float, index: int, closed: bool) -> void:
	var body := prop_body("TentCabin%d" % index, CS + "tent_cabin_%d.png" % (index % CurryArt.TENT_SPRITES), [Rect2(-15, -9, 30, 9)])
	body.position = foot(tx, ty)
	_entities.add_child(body)
	if not closed and rng.randf() < 0.55:
		night_light(body, Vector2(0, -20), 26.0, 0.7)
	if not closed and rng.randf() < 0.45:
		decor("Chair%d" % index, CS + "chair_%d.png" % (index % 4), foot(tx + 2.3, ty + 0.3), Vector2(8, 4))


func _place_cars() -> void:
	# Cars, wagons, a camper bus and a motor home in the lot: a slot every three tiles.
	var i := 0
	for row_y in [43.2, 47.6]:
		for slot in 6:
			if rng.randf() < 0.42:
				continue
			var px_x := (4.5 + slot * 3.0) * T + rng.randf_range(-3.0, 3.0)
			var car := prop_body("Car%d" % i, CS + "car_%d.png" % (rng.randi() % 12), [Rect2(-11, -30, 22, 30)])
			car.position = Vector2(px_x, (row_y + 1.0) * T + 6.0)
			_entities.add_child(car)
			i += 1


func _place_life() -> void:
	_place_cars()
	# The shuttle stop and the map kiosk at the parking lot.
	shuttle("ShuttleCurry", "Curry Village", foot(13, 50) + Vector2(0, -2))
	instance_scene("res://scenes/objects/travel_point.tscn", foot(18, 44), "Travel_CurryVillageParking").set("label", "Curry Village Parking")
	_arch()
	sign_prop("PoolSign", "res://assets/sprites/info_sign.png", foot(24, 44), Vector2(12, 4), "Swimming pool",
		"A stone deck, cold water, and a lot of kids on a hot afternoon. In winter the pool is drained and the deck becomes an ice rink.")
	sign_prop("ApronSign", CS + "trail_post_apron.png", foot(76, 9.5), Vector2(8, 4), "Glacier Point Apron",
		"A sweep of smooth granite slabs rises from behind the cabins toward Glacier Point, 3,200 feet above. The trail at the top corner climbs the talus to its foot.")
	sign_prop("StonemanSign", "res://assets/sprites/info_sign.png", foot(40, 54), Vector2(12, 4), "Stoneman Meadow",
		"In spring the meadow floods, and Half Dome shows up upside down in the pools. Stay on the trail: the grass here is easy to trample.")
	sign_prop("MercedSign", "res://assets/sprites/info_sign.png", foot(20, 58), Vector2(12, 4), "The Merced River",
		"The Merced flows from Yosemite's high country, through the Valley, and on to the San Joaquin. It is a National Wild and Scenic River.")
	sign_prop("GateSign", CS + "trail_post_home.png", foot(94, 36.2), Vector2(8, 4), "Lamon Homestead",
		"James Lamon's cabin and apple orchard stood near here in the 1860s. The gate ahead leads to your camp.")


## The Camp Curry arch over the way into the parking lot. Only its two posts
## are solid, so you walk under it.
func _arch() -> void:
	var body := prop_body("EntranceArch", CS + "entrance_sign.png", [Rect2(-33, -5, 7, 5), Rect2(26, -5, 7, 5)], Vector2(60, 14))
	body.set_script(load("res://scripts/objects/info_sign.gd"))
	body.set("title", "Camp Curry")
	body.set("text", "David and Jennie Curry opened Camp Curry in 1899 with seven tents and a promise of a clean bed and a hot supper at a price working families could pay. After David died in 1917 Jennie ran the camp for decades. Today it is called Curry Village.")
	body.position = foot(23, 49)
	_entities.add_child(body)


func _place_orchard() -> void:
	var i := 0
	for gy in [27, 30, 33, 42, 45, 48]:
		for gx in range(82, 98, 3):
			if gy in range(36, 41):
				continue
			var ox: float = gx + rng.randf_range(-0.6, 0.6)
			var oy: float = gy + rng.randf_range(-0.5, 0.5)
			_prop("tree_apple_old", foot(ox, oy), "AppleTree%d" % i)
			i += 1
	# A split-rail fence along the orchard's edge, with a gap at the gate.
	for fy in range(26, 48):
		if fy in range(36, 41):
			continue
		decor("OrchardFence%d" % fy, CS + "fence_v.png", foot(99.2, fy), Vector2(4, 4))


func _place_markers_and_exits() -> void:
	marker("arrival", 46, 40.5)
	marker("homestead", 94, 38)
	marker("shuttle", 13, 51)
	marker("store_door", 56, 36)
	marker("shop_door", 66, 36)
	marker("registration_porch", 34, 36)
	marker("plaza", 50, 40)
	marker("pavilion_door", 46, 37.3)
	marker("amphitheater", 66, 47.6)
	marker("pool_side", 29, 46.4)
	marker("apron_trailhead", 78, 10)
	marker("campsite_west", 16, 21)
	marker("campsite_center", 33, 21)
	marker("campsite_east", 50, 21)
	marker("orchard", 90, 37)
	marker("west_road", 2, 51)
	marker("east_road", 97, 51)
	place("Curry Village", 50, 36, 30)
	place("Camp Curry Plaza", 50, 41, 8)
	place("Tent cabins", 44, 20, 22)
	place("Stoneman Meadow", 62, 55, 16)
	place("Lamon Orchard", 90, 38, 10)
	place("Glacier Point Apron trail", 78, 10, 6)
	place("Merced River", 40, 62, 4, false)
	# Roads out, the way home, and the trail up to the Apron.
	region_exit("HomesteadGate", tile_pos(99, 38), Vector2(12, 60), "Lamon Homestead", "lamon_homestead", "gate")
	region_exit("WestRoad", tile_pos(0, 51), Vector2(12, 48), "Southside Drive west", "yosemite_valley", "curry_village")
	region_exit("EastRoad", tile_pos(99, 51), Vector2(12, 48), "Southside Drive east", "yosemite_valley", "happy_isles")
	region_exit("ApronTrail", tile_pos(79, 7), Vector2(48, 12), "Glacier Point Apron", "yosemite_valley", "apron_base")


# ---------------------------------------------------------------- interiors

## A piece of furniture standing with its base at pixel ([param px_x], [param base_y]).
func _furniture(piece_name: String, sprite: String, px_x: float, base_y: float, footprint: Vector2, frames := 1) -> void:
	var body := prop_body(piece_name, I + sprite, [base_rect(footprint)])
	body.position = Vector2(px_x, base_y)
	_entities.add_child(body)
	if frames > 1:
		animate(body, frames, 3.0)


## Walls all around a 30 x 17 room; [param wall_rows] deep at the back and a
## doorway two tiles wide in the middle of the front wall.
func _room_grid(wall_rows: int) -> void:
	init_grid(30, 17, Terrain.BUILT)
	fill(0, 0, 29, wall_rows - 1, Terrain.CLIFF)
	fill(0, 16, 29, 16, Terrain.CLIFF)
	fill(0, wall_rows, 0, 15, Terrain.CLIFF)
	fill(29, wall_rows, 29, 15, Terrain.CLIFF)
	fill(14, 16, 15, 16, Terrain.BUILT)


## The Camp Curry Store inside: a plank floor, shelves to the ceiling, a
## counter with the clerk, and produce out front.
func _build_store() -> void:
	_room_grid(4)
	start_region("CurryStore", "curry_store", "Camp Curry Store", GEO, true)
	paint_ground()
	_room_background(I + "store_room.png")
	_furniture("Counter", "store_counter.png", 240, 136, Vector2(120, 16))
	vendor("StoreClerk", "res://data/shops/curry_store.tres", Vector2(240, 110), Color(0.3, 0.5, 0.35), "res://assets/sprites/npcs/curry_store_clerk.png")
	_furniture("Stove", "store_stove.png", 40, 104, Vector2(18, 8), 2)
	_furniture("Chalkboard", "store_chalkboard.png", 84, 100, Vector2(20, 5))
	_furniture("Postcards", "postcard_rack.png", 408, 100, Vector2(12, 5))
	_furniture("Cooler", "store_cooler.png", 446, 104, Vector2(22, 8))
	_furniture("ShelfW1", "store_shelf.png", 74, 168, Vector2(44, 12))
	_furniture("ShelfW2", "store_shelf.png", 74, 226, Vector2(44, 12))
	_furniture("ShelfE1", "store_shelf.png", 406, 168, Vector2(44, 12))
	_furniture("ShelfE2", "store_shelf.png", 406, 226, Vector2(44, 12))
	_furniture("Produce1", "produce_table.png", 178, 196, Vector2(48, 12))
	_furniture("Produce2", "produce_table.png", 302, 196, Vector2(48, 12))
	_furniture("Barrels", "store_barrels.png", 446, 252, Vector2(30, 10))
	sign_prop("StoreNotice", "res://assets/sprites/info_sign.png", Vector2(150, 108), Vector2(12, 4), "Camp Curry Store",
		"Postcards, matches, film, ice and groceries since 1899. Bring a pack: the clerk trades food that keeps for forage that doesn't.")
	_marker_px("door", 240, 244)
	_marker_px("counter", 240, 148)
	_marker_px("customer", 244, 232)
	region_exit("ToCurry", Vector2(240, 268), Vector2(44, 10), "Curry Village", "curry_village", "store_door")
	place_blockers(false)
	pack(_root, STORE_SCENE)


## The Mountain Shop inside: ropes and cams on the walls, a practice wall,
## a glass case of hardware, and a counter run by the shop clerk.
func _build_mountain_shop() -> void:
	_room_grid(5)
	start_region("CurryMountainShop", "curry_mountain_shop", "Mountain Shop", GEO, true)
	paint_ground()
	_room_background(I + "shop_room.png")
	_furniture("Counter", "shop_counter.png", 386, 138, Vector2(96, 16))
	vendor("ShopClerk", "res://data/shops/curry_mountain_shop.tres", Vector2(386, 110), Color(0.3, 0.4, 0.55), "res://assets/sprites/npcs/curry_shop_clerk.png")
	_furniture("PracticeWall", "practice_wall.png", 76, 178, Vector2(70, 12))
	_furniture("CrashPad", "crash_pad.png", 76, 200, Vector2(66, 10))
	_furniture("GlassCase", "glass_case.png", 196, 208, Vector2(66, 14))
	_furniture("GlassCase2", "glass_case.png", 292, 208, Vector2(66, 14))
	_furniture("PackRack", "pack_rack.png", 444, 200, Vector2(30, 12))
	_furniture("Workbench", "workbench.png", 108, 250, Vector2(58, 12))
	_furniture("BootBench", "boot_bench.png", 352, 250, Vector2(38, 8))
	_furniture("Stove", "shop_stove.png", 444, 132, Vector2(18, 8), 2)
	_furniture("RopeBin", "rope_bin.png", 150, 124, Vector2(26, 8))
	_furniture("Stool", "stool.png", 350, 132, Vector2(10, 5))
	sign_prop("SchoolBoard", "res://assets/sprites/info_sign.png", Vector2(200, 110), Vector2(12, 4), "Mountaineering School",
		"The Yosemite Mountaineering School teaches from Curry Village: knots, belaying, and a first few pitches on the granite slabs. Sign up at the counter.")
	sign_prop("NoseNotice", "res://assets/sprites/info_sign.png", Vector2(250, 110), Vector2(12, 4), "The Nose, 1958",
		"A photograph of Warren Harding, Wayne Merry and George Whitmore at the top of El Capitan on November 12, 1958, after 47 days of climbing spread over 18 months.")
	_marker_px("door", 240, 244)
	_marker_px("counter", 386, 150)
	_marker_px("customer", 244, 190)
	region_exit("ToCurry", Vector2(240, 268), Vector2(44, 10), "Curry Village", "curry_village", "shop_door")
	place_blockers(false)
	pack(_root, SHOP_SCENE)


func _marker_px(marker_name: String, px_x: float, px_y: float) -> void:
	var m := Marker2D.new()
	m.name = marker_name
	m.position = Vector2(px_x, px_y)
	_markers.add_child(m)


## The room's painted floor and walls, one picture under everything else.
func _room_background(path: String) -> void:
	var sprite := Sprite2D.new()
	sprite.name = "Room"
	sprite.texture = texture(path)
	sprite.centered = false
	sprite.z_index = -8
	_root.add_child(sprite)
