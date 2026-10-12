extends AhwahneeStyle
## Builds the Yosemite Valley central hub: Yosemite Village and Camp 4 at
## walking scale, with their stores, the Indian Village, the gear traders,
## the creek and river bridges, and exits back to the full Valley map.
## Run from the project folder:
##
##   godot --headless --path . res://tools/hubs/build_hubs.tscn
##
## It rewrites scenes/regions/yosemite_village.tscn, the art in
## assets/sprites/buildings/ (valley_art.gd draws the buildings and street
## props, camp4_art.gd Camp 4's boulders, tents, fire rings and camp gear,
## valley_land_art.gd the wall of the Valley and Lower Yosemite Fall, all in
## the Ahwahnee's style), the painted ground in assets/sprites/ahwahnee/, the
## shuttle stop scene, the store foods, and the shop data. Trees, plants,
## rocks and logs are the Ahwahnee sprites (see ahwahnee_style.gd). Put story
## NPCs in scenes/story/content/yosemite_village.tscn (placed by Marker name),
## not in the region scene, so a rebuild keeps them.
##
## The layout is not to scale: it squeezes the 1.5 km from Camp 4 to the
## Village into one walkable map, keeping the real order of things west to
## east and north (the Valley wall) to south (the Merced).

const HubArt = preload("res://tools/hubs/hub_art.gd")
const ValleyArt = preload("res://tools/hubs/valley_art.gd")
const Camp4Art = preload("res://tools/hubs/camp4_art.gd")
const ValleyLandArt = preload("res://tools/hubs/valley_land_art.gd")
const HotelArt = preload("res://tools/hubs/ahwahnee_hotel_art.gd")

const W := 100
const H := 60
const SCENE := "res://scenes/regions/yosemite_village.tscn"
const SHUTTLE_SCENE := "res://scenes/objects/shuttle_stop.tscn"
const B := "res://assets/sprites/buildings/"
const GEO := Vector2(-119.5873, 37.7475)

## Where Lower Yosemite Fall lands: the fall tiles are x 43..45, rows 0..7.
const FALL_CX := 44 * 16 + 8
const FALL_ROWS := 8


func _ready() -> void:
	w = W
	h = H
	print("== Yosemite Village art")
	HubArt.new().save_all()
	HotelArt.new().save_all()
	ValleyArt.new().save_all()
	Camp4Art.new().save_all()
	load_flora()
	import_assets()
	print("== data")
	_build_store_foods()
	_build_shops()
	_build_shuttle_scene()
	print("== Yosemite Village region")
	_build_region()
	print("Done")
	get_tree().quit()


func _save(res: Resource, path: String) -> void:
	save_resource(res, path)


func _texture(path: String) -> Texture2D:
	return texture(path)


# ---------------------------------------------------------------- data

func _build_store_foods() -> void:
	var sheet := _texture(HubArt.ITEM_ICONS)
	var foods := [
		["trail_mix", "Trail Mix", "Nuts, raisins, and oats from the Village Store. Light to carry and slow to spoil.", 0],
		["dried_apples", "Dried Apples", "Rings of dried apple. Apples have grown in the Valley since the homesteaders' orchards of the 1860s.", 1],
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
		_save(item, "res://data/food/%s.tres" % food[0])


func _offer(kind_name: String, id: String, price: int, requires := {}, max_owned := 0, amount := 1) -> ShopOffer:
	var offer := ShopOffer.new()
	offer.kind = kind_name
	offer.id = id
	offer.price = price
	offer.requires = requires
	offer.max_owned = max_owned
	offer.amount = amount
	return offer


func _shop(keeper: String, greeting: String, nothing_yet: String, offers: Array) -> ShopData:
	var shop := ShopData.new()
	shop.keeper = keeper
	shop.greeting = greeting
	shop.nothing_yet = nothing_yet
	for offer: ShopOffer in offers:
		shop.offers.append(offer)
	return shop


## Prices are in food energy. Trades round out a rack; the piece that opens
## a new climbing tier comes from quests (docs/DESIGN.md).
func _build_shops() -> void:
	_save(_shop("Village Store clerk",
		"Welcome to the Village Store. We'll swap you trail food that keeps for your fresh forage.",
		"We're sold out today.",
		[_offer("item", "trail_mix", 40), _offer("item", "dried_apples", 20)]),
		"res://data/shops/village_store.tres")
	_save(_shop("Camp 4 climber",
		"Hey. Rope, cams, draws... everything's for trade, and I'm always hungry.",
		"Come back once you've got a rope and a couple of cams. Then I can help fill out your rack.",
		[_offer("gear", "cam", 50, {"cam": 2}, 6),
		_offer("gear", "quickdraw", 30, {"rope": 1}, 8, 2),
		_offer("gear", "belay_device", 40, {"rope": 1, "harness": 1}, 1)]),
		"res://data/shops/camp4_rack.tres")
	_save(_shop("Big-wall climber",
		"Just down off El Cap. Everything I hauled up there is for trade, for food.",
		"Big-wall gear won't do you any good until someone teaches you to aid climb.",
		[_offer("gear", "haul_bag", 80, {"aiders": 1}, 1),
		_offer("gear", "cam", 55, {"cam": 4}, 8),
		_offer("gear", "portaledge", 140, {"ascenders": 1, "haul_bag": 1}, 1)]),
		"res://data/shops/camp4_bigwall.tres")


## The shuttle stop sign, used here, at the homestead, and in the Valley map.
func _build_shuttle_scene() -> void:
	var body := _prop_body("ShuttleStop", B + "shuttle_stop.png", Vector2(6, 4), Vector2(16, 26))
	body.set_script(load("res://scripts/objects/shuttle_stop.gd"))
	pack(body, SHUTTLE_SCENE)


# ---------------------------------------------------------------- layout

func _put(x: int, y: int, type: int) -> void:
	if x >= 0 and y >= 0 and x < W and y < H:
		kind[y * W + x] = type


func _at(x: int, y: int) -> int:
	return kind[clampi(y, 0, H - 1) * W + clampi(x, 0, W - 1)]


func _rect(x0: int, y0: int, x1: int, y1: int, type: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			_put(x, y, type)


func _clear_trees(x0: int, y0: int, x1: int, y1: int) -> void:
	for y in range(maxi(y0, 0), mini(y1, H - 1) + 1):
		for x in range(maxi(x0, 0), mini(x1, W - 1) + 1):
			no_trees[y * W + x] = 1


func _layout() -> void:
	kind.resize(W * H)
	kind.fill(Terrain.FOREST)
	no_trees.resize(W * H)
	var path := PackedByteArray()
	path.resize(W * H)
	rng.seed = 1851
	noise.seed = 1851
	noise.frequency = 0.12
	# The north wall of the Valley, with talus at its foot.
	for x in W:
		var base := 4 + int(noise.get_noise_1d(x * 3.0) * 2.0)
		_rect(x, 0, x, base, Terrain.CLIFF)
		_rect(x, base + 1, x, base + 2 + int(absf(noise.get_noise_1d(x * 5.0)) * 3.0), Terrain.TALUS)

	# Camp 4: walk-in campground at the foot of the wall, and its parking.
	_rect(3, 10, 33, 30, Terrain.CAMP)
	_rect(20, 32, 32, 36, Terrain.PARKING)
	# Keep the shared fire and Columbia Boulder in the open.
	_clear_trees(13, 17, 22, 26)
	_clear_trees(4, 9, 15, 16)
	# Yosemite Valley Lodge, between Camp 4 and the creek.
	_rect(34, 26, 42, 35, Terrain.PAVED)
	# The Indian Village behind the museum, in the oaks.
	_rect(50, 9, 66, 17, Terrain.FOREST)
	_clear_trees(50, 10, 66, 17)
	# The Village: a pedestrian mall, the plaza by the store, the parking lot.
	_rect(48, 19, 95, 21, Terrain.PAVED)
	_rect(62, 22, 82, 31, Terrain.PAVED)
	_rect(88, 22, 89, 30, Terrain.PAVED)
	_rect(82, 31, 96, 36, Terrain.PARKING)
	_rect(62, 32, 63, 37, Terrain.PAVED)
	# Cook's Meadow between the road and the river.
	_rect(46, 39, 97, 47, Terrain.MEADOW)
	_rect(52, 43, 58, 45, Terrain.WET_MEADOW)
	_rect(84, 42, 90, 44, Terrain.WET_MEADOW)
	_rect(8, 47, 18, 47, Terrain.SAND)
	_rect(76, 47, 86, 47, Terrain.SAND)

	# Roads and trails (remembered so crossings with water become bridges).
	var paths := [
		[Terrain.ROAD, 0, 38, W - 1, 38], # Northside Drive
		[Terrain.ROAD, 0, 56, W - 1, 56], # Southside Drive
		[Terrain.ROAD, 71, 38, 71, H - 1], # Sentinel Drive and Sentinel Bridge
		[Terrain.ROAD, 26, 37, 27, 37], # Camp 4 parking
		[Terrain.ROAD, 89, 37, 90, 37], # Village parking
		[Terrain.PAVED, 38, 36, 38, 37], # Lodge walk
		[Terrain.TRAIL, 15, 31, 15, 37], # Camp 4 walk-in path
		[Terrain.TRAIL, 33, 20, 49, 20], # Camp 4 to the Village, over the creek
		[Terrain.TRAIL, 47, 10, 47, 19], # to the base of Lower Yosemite Fall
		[Terrain.TRAIL, 46, 10, 48, 10],
		[Terrain.TRAIL, 51, 14, 65, 14], # Indian Village loop
		[Terrain.TRAIL, 58, 15, 58, 18],
		[Terrain.BRIDGE, 60, 39, 60, 47], # Cook's Meadow boardwalk
		[Terrain.TRAIL, 60, 48, 60, 52], # boardwalk down to the river and across
		[Terrain.TRAIL, 61, 47, 70, 47],
		[Terrain.TRAIL, 22, 39, 22, 55], # Swinging Bridge trail
	]
	for p: Array in paths:
		_rect(p[1], p[2], p[3], p[4], p[0])
		for y in range(p[2], p[4] + 1):
			for x in range(p[1], p[3] + 1):
				path[y * W + x] = 1

	# Water goes last: Lower Yosemite Fall, Yosemite Creek, and the Merced.
	var water := PackedByteArray()
	water.resize(W * H)
	for y in range(0, 8):
		for x in range(43, 46):
			_put(x, y, Terrain.FALLS)
	for y in range(8, 10):
		for x in range(42, 47):
			water[y * W + x] = 1
	var prev_x := 44
	for y in range(10, 49):
		var x := 44 if y < 17 or (y >= 28 and y < 37) else 45
		water[y * W + x] = 1
		water[y * W + prev_x] = 1
		prev_x = x
	for x in W:
		var bank := 48 + int(noise.get_noise_1d(x * 2.0 + 40.0) * 1.5)
		for y in range(bank, bank + 3):
			water[y * W + x] = 1
	for k in W * H:
		if not water[k]:
			continue
		# Where a road or trail meets water, build a bridge.
		kind[k] = Terrain.BRIDGE if path[k] else Terrain.RIVER
	_rect(40, 8, 41, 10, Terrain.GRANITE)
	_rect(47, 8, 48, 9, Terrain.GRANITE)

	# Keep trees and plants off paths, paving, and water.
	for k in W * H:
		if path[k] or water[k] or kind[k] in [Terrain.PARKING, Terrain.PAVED]:
			no_trees[k] = 1
	_clear_trees(34, 24, 42, 36)
	_clear_trees(62, 10, 96, 31)


# ---------------------------------------------------------------- scene

func _build_region() -> void:
	_layout()
	start_region("YosemiteVillage", "yosemite_village", "Yosemite Village", GEO)
	paint_ground()
	_save_ground_art("ground_yosemite_village", 1851)
	_place_wall()

	_place_buildings()
	_place_camp_4()
	_place_village_life()
	_place_markers_and_places()
	_place_exits()
	_dress_village()
	place_blockers()
	add_forage("yosemite_village", 2.0)

	for child in _root.get_children():
		_own(child, _root)
	pack(_root, SCENE)


func _tile_pos(x: float, y: float) -> Vector2:
	return Vector2(x * T + T / 2.0, y * T + T / 2.0)


## A static prop: a sprite standing on its base, with a collision footprint.
func _prop_body(prop_name: String, texture: String, footprint: Vector2, hitbox := Vector2.ZERO) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = prop_name
	body.collision_mask = 0
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = _texture(texture)
	sprite.offset = Vector2(0, -sprite.texture.get_height() / 2.0)
	body.add_child(sprite)
	if footprint.x > 0:
		var shape := CollisionShape2D.new()
		shape.name = "Collision"
		var rect := RectangleShape2D.new()
		rect.size = footprint
		shape.shape = rect
		shape.position = Vector2(0, -footprint.y / 2.0)
		body.add_child(shape)
	if hitbox.x > 0:
		var area := Area2D.new()
		area.name = "Hitbox"
		area.collision_layer = 4
		area.collision_mask = 0
		area.monitoring = false
		var hit := CollisionShape2D.new()
		hit.name = "Shape"
		var hit_rect := RectangleShape2D.new()
		hit_rect.size = hitbox
		hit.shape = hit_rect
		hit.position = Vector2(0, -hitbox.y / 2.0)
		area.add_child(hit)
		body.add_child(area)
	return body


## A prop you can read about: interact to see its title and text.
func _sign_prop(prop_name: String, texture: String, at: Vector2, footprint: Vector2, title: String, text: String) -> StaticBody2D:
	var tex := _texture(texture)
	var body := _prop_body(prop_name, texture, footprint, Vector2(footprint.x + 6, footprint.y + 10))
	body.set_script(load("res://scripts/objects/info_sign.gd"))
	body.set("title", title)
	body.set("text", text)
	body.position = at
	_entities.add_child(body)
	assert(tex != null)
	return body


func _decor(prop_name: String, texture: String, at: Vector2, footprint: Vector2) -> void:
	var body := _prop_body(prop_name, texture, footprint)
	body.position = at
	_entities.add_child(body)


## A building: its footprint blocks the whole wall, and interacting at the
## front reads its sign.
func _building(prop_name: String, sprite_name: String, tile_x: float, base_y: int, title: String, text: String) -> void:
	var tex := _texture(B + sprite_name + ".png")
	var footprint := Vector2(tex.get_width() - 4, tex.get_height() * 0.38)
	_sign_prop(prop_name, B + sprite_name + ".png", Vector2(tile_x * T + T / 2.0, base_y * T), footprint, title, text)
	_glow_building(sprite_name, tile_x, base_y)


func _instance(path: String, at: Vector2, node_name: String) -> Node2D:
	var node: Node2D = (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	node.name = node_name
	node.position = at
	_entities.add_child(node)
	return node


func _place_buildings() -> void:
	_building("VillageStore", "village_store", 72, 30, "Village Store",
		"The Valley's general store: groceries, supplies, and gifts. Trade fresh forage here for trail food that keeps.")
	_building("WelcomeCenter", "welcome_center", 79, 18, "Yosemite Valley Welcome Center",
		"Maps, trail conditions, road closures, and Junior Ranger booklets.")
	_building("YosemiteMuseum", "museum", 69, 18, "Yosemite Museum",
		"The museum opened in 1926 and shows the Valley's art and cultural history. The Indian Village stands behind it.")
	_building("BestsStudio", "bests_studio", 86, 18, "Best's Studio",
		"Harry Best opened a painting studio in the Valley in 1902. His daughter Virginia married Ansel Adams, and the studio became The Ansel Adams Gallery.")
	_building("Degnans", "degnans", 86, 30, "Degnan's",
		"John and Bridget Degnan came to the Valley in 1884. Bridget sold bread from her porch before they opened a bakery and store, and her bread was famous with visitors.")
	_building("WildernessCenter", "wilderness_center", 93, 18, "Wilderness Center",
		"Rangers issue wilderness permits and check the trail conditions here.")
	_building("ValleyLodge", "valley_lodge", 38, 32, "Yosemite Valley Lodge",
		"The lodge stands near the foot of Yosemite Falls, a short walk from Camp 4.")


## Camp 4 as it is laid out on the ground: walk-in sites under the pines,
## each with its tents, a picnic table, a bear box and a steel fire ring,
## around a shared fire; Columbia Boulder at the back by the talus, with
## Midnight Lightning chalked on its face; a slackline, the gear traders, the
## bulletin board where the walk-in path arrives, and a van in the lot.
const CAMP4_SITES := [
	# [tile x, tile y, tents [[kind, dx, dy]...], table, fire ring lit]
	[5, 20, [["canvas", -14, -26]], "cook", true],
	[5, 27, [["dome_0", -16, -24], ["tarp", 16, -28]], "", false],
	[12, 20, [["dome_2", -12, -24]], "rack", false],
	[9, 28, [["canvas", -14, -26]], "", true],
	[21, 28, [["dome_1", -12, -24]], "cook", true],
	[28, 26, [["canvas", -18, -26], ["dome_3", 18, -24]], "", false],
	[31, 29, [["tarp", -12, -26]], "rack", false],
	[31, 16, [["dome_0", -10, -24]], "", true],
	[16, 14, [["canvas", -16, -26]], "cook", false],
]


func _place_camp_4() -> void:
	# Columbia Boulder and the chalk of Midnight Lightning on its south face.
	var columbia_at := foot(9, 14)
	decor("ColumbiaBoulderRock", B + "camp4_columbia_boulder.png", columbia_at, Vector2(104, 16))
	_info("ColumbiaBoulder", columbia_at + Vector2(-40, 0), Vector2(40, 26), "Columbia Boulder",
		"A house-sized block of granite that came down from the wall above, long ago. Climbers have practiced hard moves on the Camp 4 boulders since the 1950s, and Columbia Boulder is the most famous of them.")
	_info("MidnightLightning", columbia_at + Vector2(Camp4Art.BOLT_AT.x, 0), Vector2(38, 26), "Midnight Lightning",
		"The chalk lightning bolt marks Midnight Lightning, the boulder problem up this overhanging face. Ron Kauk made the first ascent in 1978. Graded V8, it was one of the hardest boulder problems in the world, and the mantel onto the top still turns most climbers back. Climbers keep the bolt redrawn.")
	decor("CrashPad", B + "camp4_crash_pad.png", columbia_at + Vector2(10, 14))
	decor("WarmupBoulder", B + "camp4_boulder.png", foot(26, 12), Vector2(46, 12))

	# The campsites.
	for i in CAMP4_SITES.size():
		var site: Array = CAMP4_SITES[i]
		var at_pos := foot(site[0], site[1])
		for t: Array in site[2]:
			_camp_tent("Site%dTent%s" % [i, t[0].capitalize().replace(" ", "")], t[0], at_pos + Vector2(t[1], t[2]))
		var table_sprite: String = "camp4_table" + ("_" + site[3] if site[3] != "" else "")
		var table := decor("Site%dTable" % i, B + table_sprite + ".png", at_pos + Vector2(8, 0), Vector2(32, 8))
		if site[3] == "cook":
			night_light(table, Vector2(9, -18), 26.0, 0.8, 0.1)
			_glow(table_sprite + "_glow", at_pos + Vector2(8 - 18, -26), 1.0, B)
		decor("Site%dBearBox" % i, B + "bear_box.png", at_pos + Vector2(34, -8), Vector2(14, 6))
		_fire_ring("Site%dFireRing" % i, at_pos + Vector2(-14, 24), site[4])

	# The shared fire, where people cook, with stumps to sit on.
	var fire := _instance("res://scenes/story/station.tscn", _tile_pos(17, 21), "Camp4FireRing")
	fire.set("station", "campfire")
	fire.set("display_name", "Camp 4 fire ring")
	fire.set("texture", texture(B + "camp4_fire_ring.png"))
	fire.set("frames", Camp4Art.FIRE_FRAMES)
	fire.set("fps", 8.0)
	fire.set("ground_inset", Camp4Art.FIRE_INSET)
	fire.set("body_size", Vector2(24, 8))
	fire.set("reach_size", Vector2(28, 16))
	ambient(fire, "smoke", Vector2(0, -16), Vector2(2, 1))
	for stump in [Vector2(-24, 2), Vector2(24, 6)]:
		_prop("log_stump", _tile_pos(17, 21) + stump)

	# A slackline between two pines: Camp 4 climbers started walking slack
	# lines here on rest days in the early 1980s.
	var slack_at := foot(24.5, 20)
	_prop(_pick("tree_ponderosa"), slack_at + Vector2(-Camp4Art.SLACK_SPAN / 2.0, 0))
	_prop(_pick("tree_ponderosa"), slack_at + Vector2(Camp4Art.SLACK_SPAN / 2.0, 0))
	decor("Slackline", B + "camp4_slackline.png", slack_at + Vector2(0, 2))
	_info("SlacklineInfo", slack_at + Vector2(0, 4), Vector2(40, 10), "Slackline",
		"Flat webbing strung between two pines. Camp 4 climbers began walking slack chains and lines here on rest days in the early 1980s, and slacklining spread around the world from this campground.")

	# Notes for partners and rides where the walk-in path arrives, and the sign.
	sign_prop("RouteBoard", B + "camp4_board.png", foot(13.5, 30), Vector2(36, 6), "Camp 4 bulletin board",
		"Notes pinned three deep: partners wanted for Royal Arches, a rack for trade, rides to the Tuolumne, and a weather report for the week. Climbers have found partners on this board for generations.")
	sign_prop("Camp4Sign", B + "camp4_sign.png", _tile_pos(31, 21), Vector2(36, 5), "Camp 4",
		"Climbers have camped here since the 1950s, the golden age of big-wall climbing, when Royal Robbins, Warren Harding and their friends lived here for whole seasons. In the late 1990s climbers fought a plan to build lodging on the site, and Camp 4 was added to the National Register of Historic Places in 2003.")
	_info("OldCanvasTent", foot(5, 20) + Vector2(-14, -22), Vector2(36, 14), "Canvas wall tent",
		"In the 1950s and 60s climbers lived in Camp 4 for months at a time in canvas tents like this one, or under tarps, on almost no money, between climbs on the big walls.")

	# Gear traders with their gear spread out on tarps.
	decor("TarpRack", B + "camp4_tarp_rack.png", _tile_pos(22, 17) + Vector2(0, 4))
	_vendor("RackTrader", "res://data/shops/camp4_rack.tres", _tile_pos(24, 17) + Vector2(0, 2), Color(0.8, 0.45, 0.2))
	decor("TarpBigWall", B + "camp4_tarp_bigwall.png", _tile_pos(11, 25) + Vector2(0, 4))
	_vendor("BigWallTrader", "res://data/shops/camp4_bigwall.tres", _tile_pos(13, 25) + Vector2(0, 2), Color(0.35, 0.5, 0.75))
	decor("Van", B + "camp4_van.png", foot(30, 34), Vector2(54, 10))
	_shuttle("ShuttleCamp4", "Camp 4", _tile_pos(24, 37) + Vector2(0, 4))

	# Pine needles and cones over the camp's dirt.
	for i in 24:
		var tx := rng.randi_range(4, 32)
		var ty := rng.randi_range(11, 30)
		if at(tx, ty) != Terrain.CAMP:
			continue
		_backdrop("camp4_duff_%d" % (i % 3), Vector2(tx * T - 12 + rng.randf_range(0, 8), ty * T - 6 + rng.randf_range(0, 8)), -8, B)


## A tent at a campsite; most have a lantern lit inside after dark.
func _camp_tent(node_name: String, kind_name: String, at_pos: Vector2) -> void:
	var sprite := "camp4_tent_" + kind_name
	var tex := texture(B + sprite + ".png")
	decor(node_name, B + sprite + ".png", at_pos + Vector2(0, 4), Vector2(tex.get_width() - 10, 8))
	if _has(sprite + "_glow", B) and rng.randf() > 0.25:
		_glow(sprite + "_glow", at_pos + Vector2(-tex.get_width() / 2.0, 4 - tex.get_height()), 0.9, B)


## A campsite's steel fire ring. A lit one burns, smokes and throws sparks,
## and lights the ground around it after dark.
func _fire_ring(node_name: String, at_pos: Vector2, lit: bool) -> void:
	var sprite := "camp4_fire_ring" if lit else "camp4_fire_ring_cold"
	var ring := decor(node_name, B + sprite + ".png", at_pos + Vector2(0, Camp4Art.FIRE_INSET), Vector2(22, 6))
	if not lit:
		return
	animate(ring, Camp4Art.FIRE_FRAMES, 8.0)
	night_light(ring, Vector2(0, -10), 60.0, 0.9, 0.35)
	ambient(ring, "sparks", Vector2(0, -14), Vector2(3, 1))
	ambient(ring, "smoke", Vector2(0, -18), Vector2(2, 1))


## Each trader's walking sheet (tools/npcgen), by node name.
const VENDOR_SHEETS := {
	"RackTrader": "res://assets/sprites/npcs/camp4_rack_trader.png",
	"BigWallTrader": "res://assets/sprites/npcs/camp4_bigwall_trader.png",
	"StoreClerk": "res://assets/sprites/npcs/village_store_clerk.png",
}


func _vendor(node_name: String, shop_path: String, at: Vector2, color: Color) -> void:
	var vendor := StaticBody2D.new()
	vendor.name = node_name
	vendor.collision_mask = 0
	vendor.set_script(load("res://scripts/shop/vendor.gd"))
	vendor.set("shop", load(shop_path))
	vendor.set("color", color)
	if VENDOR_SHEETS.has(node_name):
		vendor.set("sprite_sheet", load(VENDOR_SHEETS[node_name]))
	vendor.position = at
	var shape := CollisionShape2D.new()
	shape.name = "Collision"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8, 4)
	shape.shape = rect
	shape.position = Vector2(0, -2)
	vendor.add_child(shape)
	var area := Area2D.new()
	area.name = "Hitbox"
	area.collision_layer = 4
	area.collision_mask = 0
	area.monitoring = false
	var hit := CollisionShape2D.new()
	hit.name = "Shape"
	var hit_rect := RectangleShape2D.new()
	hit_rect.size = Vector2(14, 22)
	hit.shape = hit_rect
	hit.position = Vector2(0, -11)
	area.add_child(hit)
	vendor.add_child(area)
	_entities.add_child(vendor)


func _shuttle(node_name: String, stop: String, at: Vector2) -> void:
	var node := _instance(SHUTTLE_SCENE, at, node_name)
	node.set("stop_name", stop)


func _place_village_life() -> void:
	# The Indian Village: umachas, an acorn granary, and a grinding rock.
	# TRIBAL REVIEW NEEDED: these descriptions are placeholders until the
	# associated tribes have reviewed them (docs/DESIGN.md).
	var homes := [[53, 12], [57, 11], [62, 12], [55, 16], [64, 16]]
	for i in homes.size():
		var h: Array = homes[i]
		_sign_prop("Umacha%d" % i, B + "umacha.png", _tile_pos(h[0], h[1]) + Vector2(0, 6), Vector2(24, 8), "Umacha",
			"A cone-shaped home of incense-cedar bark slabs laid over a frame of poles. Families in Yosemite Valley lived in umachas like this one.")
	_sign_prop("Chuckah", B + "chuckah.png", _tile_pos(60, 16) + Vector2(0, 6), Vector2(12, 6), "Chuckah",
		"An acorn granary: a tall woven store on poles under a thatched cap. It keeps a family's acorns dry and away from animals through the year.")
	var mortar := _instance("res://scenes/story/station.tscn", _tile_pos(52, 17) + Vector2(0, 4), "GrindingRock")
	mortar.set("station", "mortar")
	mortar.set("display_name", "Grinding rock")
	mortar.set("texture", texture("res://assets/sprites/lamon/mortar_slab.png"))
	mortar.set("ground_inset", 5)
	mortar.set("body_size", Vector2(50, 10))
	mortar.set("reach_size", Vector2(60, 26))
	_sign_prop("IndianVillageSign", "res://assets/sprites/info_sign.png", _tile_pos(58, 18) + Vector2(0, 4), Vector2(12, 4), "Indian Village",
		"This village behind the Yosemite Museum shows how Native families lived in the Valley: bark homes, acorn granaries, and grinding rocks worn into the granite. The Southern Sierra Miwuk and neighboring peoples still live and work in and around Yosemite today. [Placeholder pending tribal review.]")
	# The Village Store clerk trades trail food for forage.
	_vendor("StoreClerk", "res://data/shops/village_store.tres", _tile_pos(72, 31) + Vector2(0, 2), Color(0.3, 0.5, 0.35))
	_instance("res://scenes/objects/travel_point.tscn", _tile_pos(92, 33) + Vector2(0, 4), "Travel_YosemiteVillageParking").set("label", "Yosemite Village Parking")
	_shuttle("ShuttleVillage", "Yosemite Village", _tile_pos(64, 37) + Vector2(0, 4))
	_sign_prop("LowerFallSign", "res://assets/sprites/info_sign.png", _tile_pos(49, 11) + Vector2(0, 4), Vector2(12, 4), "Lower Yosemite Fall",
		"Lower Yosemite Fall drops 320 feet. It roars with snowmelt in late spring and can dry to a trickle by late summer.")
	_sign_prop("CooksMeadowSign", "res://assets/sprites/info_sign.png", _tile_pos(61, 40) + Vector2(0, 4), Vector2(12, 4), "Cook's Meadow",
		"From the boardwalk you can see Yosemite Falls to the north and Half Dome to the east. Stay on the boardwalk: meadows here are easily trampled.")
	_sign_prop("SwingingBridgeSign", "res://assets/sprites/info_sign.png", _tile_pos(23, 45) + Vector2(0, 4), Vector2(12, 4), "Swinging Bridge",
		"This footbridge crosses the Merced to the south side of the Valley, near the Four Mile Trailhead.")


func _marker(marker_name: String, x: float, y: float) -> void:
	var marker := Marker2D.new()
	marker.name = marker_name
	marker.position = _tile_pos(x, y)
	_markers.add_child(marker)


func _place(place_name: String, x: float, y: float, radius_tiles: float, label := true) -> void:
	var place := Marker2D.new()
	place.set_script(load("res://scripts/world/place.gd"))
	place.name = place_name.replace(" ", "").replace("'", "")
	place.position = _tile_pos(x, y)
	place.set("display_name", place_name)
	place.set("radius", radius_tiles * T)
	place.set("show_on_map", label)
	_places.add_child(place)


func _place_markers_and_places() -> void:
	# Spawn points and spots for story NPCs (found with Region.get_spawn).
	_marker("arrival", 90, 34)
	_marker("camp_4", 20, 20)
	_marker("camp_4_fire", 18, 22)
	_marker("shuttle_camp_4", 24, 36)
	_marker("shuttle_village", 64, 36)
	_marker("lower_yosemite_fall", 47, 12)
	_marker("cooks_meadow", 62, 42)
	_marker("indian_village", 58, 15)
	_marker("village_store", 72, 31)
	_marker("degnans_bakery", 86, 31)
	_marker("bests_studio", 86, 19)
	_marker("yosemite_museum", 69, 19)
	_marker("ranger_station", 93, 19)
	_marker("welcome_center", 79, 19)
	_marker("valley_lodge", 38, 33)
	_marker("west_road", 2, 38)
	_marker("east_road", 97, 38)
	_marker("south_road", 71, 57)
	_marker("southside_west", 2, 56)
	_marker("southside_east", 97, 56)
	_place("Camp 4", 18, 20, 16)
	_place("Yosemite Valley Lodge", 38, 30, 7)
	_place("Lower Yosemite Fall", 46, 9, 5)
	_place("Indian Village", 58, 13, 8)
	_place("Yosemite Village", 80, 25, 16)
	_place("Village Store", 72, 29, 4, false)
	_place("Cook's Meadow", 70, 43, 14)
	_place("Merced River", 50, 49, 3, false)
	_place("Sentinel Bridge", 71, 49, 3)
	_place("Swinging Bridge", 22, 49, 3)


## Roads out of the hub lead back onto the full Valley map.
func _place_exits() -> void:
	var exits := [
		["NorthsideWest", Vector2i(0, 38), "northside_west", "Northside Drive west", true],
		["NorthsideEast", Vector2i(W - 1, 38), "the_ahwahnee", "Northside Drive east", true],
		["SentinelSouth", Vector2i(71, H - 1), "southside_sentinel", "Southside Drive", false],
		["SouthsideWest", Vector2i(0, 56), "four_mile_trailhead", "Southside Drive west", true],
		["SouthsideEast", Vector2i(W - 1, 56), "curry_village", "Southside Drive east", true],
	]
	for e: Array in exits:
		var area := Area2D.new()
		area.set_script(load("res://scripts/world/region_exit.gd"))
		area.name = e[0]
		area.position = _tile_pos(e[1].x, e[1].y)
		area.set("label", e[3])
		area.set("target_region", "yosemite_valley")
		area.set("target_spawn", e[2])
		var shape := CollisionShape2D.new()
		shape.name = "Shape"
		var rect := RectangleShape2D.new()
		rect.size = Vector2(12, 16) if e[4] else Vector2(16, 12)
		shape.shape = rect
		area.add_child(shape)
		_exits.add_child(area)


# ---------------------------------------------------------------- Ahwahnee dressing

## Sprite names of the buildings and where their top-left corner sits.
func _glow_building(sprite_name: String, tile_x: float, base_y: int) -> void:
	var tex := texture(B + sprite_name + ".png")
	_glow(sprite_name + "_glow", Vector2(tile_x * T + T / 2.0 - tex.get_width() / 2.0, base_y * T - tex.get_height()), 1.0, B)


## The wall of the Valley drawn for the cliff outline, with Lower Yosemite
## Fall animated down its gully and mist where it lands.
func _place_wall() -> void:
	var prof := PackedInt32Array()
	prof.resize(W * T)
	for x in W:
		var rows := 0
		while rows < H and kind[rows * W + x] in [Terrain.CLIFF, Terrain.FALLS]:
			rows += 1
		for px_ in T:
			prof[x * T + px_] = rows * T
	ValleyLandArt.new().save_village(prof, FALL_CX)
	import_assets()
	_backdrop("village_wall", Vector2.ZERO, -8, B)
	_animation("LowerYosemiteFall", "village_fall", 8.0, Vector2(FALL_CX - ValleyLandArt.FALL_W / 2.0, 0), -7, B)
	_animation("FallMist", "village_mist", 5.0, Vector2(FALL_CX - 32, FALL_ROWS * T - 28 + 6), -6, B)
	_ambient("FallSpray", "mist", Vector2(FALL_CX, FALL_ROWS * T + 4), Vector2(28, 6))


## Trees, plants, rocks, logs and the hotel's wrought-iron lamps: the same
## dressing as the Ahwahnee grounds, laid over this map's terrain.
func _dress_village() -> void:
	_reserve_entities(1)
	var forest_table := [["tree_ponderosa", 4.0], ["tree_incense_cedar", 3.5], ["tree_black_oak", 3.2], ["tree_white_fir", 1.2], ["tree_dogwood", 1.4]]
	_fringe_trees([Terrain.FOREST], 3, 0.7, forest_table, 2, 22.0)
	_fringe_trees([Terrain.CAMP], 4, 0.5, [["tree_ponderosa", 3.0], ["tree_black_oak", 3.0], ["tree_incense_cedar", 2.0]], 1, 34.0)
	_fringe_trees([Terrain.TALUS], 4, 0.4, [["tree_incense_cedar", 2.0], ["tree_snag", 0.6], ["tree_white_fir", 1.0]], 0, 30.0)
	_fringe_trees([Terrain.MEADOW], 8, 0.3, [["tree_black_oak", 3.0], ["tree_dogwood", 1.0]], 2, 70.0)
	# Cook's Meadow: wildflowers, tall grass and lupine in drifts.
	var meadow := Rect2i(46, 39, 52, 9)
	_scatter_decor("plant_wildflowers", [Terrain.MEADOW], 60, meadow, 1)
	_scatter_decor("plant_lupine", [Terrain.MEADOW], 18, meadow, 1)
	_scatter_decor("plant_paintbrush", [Terrain.MEADOW], 10, meadow, 1)
	_scatter_decor("plant_tall_grass", [Terrain.MEADOW, Terrain.WET_MEADOW], 40, meadow, 1)
	_scatter_decor("plant_cattails", [Terrain.WET_MEADOW], 6, meadow, 0)
	# The forest floor.
	var all := Rect2i(0, 0, W, H)
	_scatter_decor("plant_fern", [Terrain.FOREST], 90, all, 1)
	_scatter_decor("plant_bracken", [Terrain.FOREST], 40, all, 1)
	_scatter_decor("plant_shrub", [Terrain.FOREST, Terrain.CAMP], 70, all, 2)
	_scatter_decor("plant_manzanita", [Terrain.TALUS], 8, Rect2i(0, 4, W, 10), 0)
	_scatter_decor("plant_mushrooms", [Terrain.FOREST], 10, all, 2)
	_scatter_decor("rock_granite", [Terrain.FOREST, Terrain.CAMP, Terrain.MEADOW], 26, all, 2)
	_scatter_decor("rock_mossy", [Terrain.FOREST], 14, all, 2)
	_scatter_decor("rock_river", [Terrain.SAND], 20, all, 0)
	_scatter_decor("log_fallen", [Terrain.FOREST], 6, all, 2)
	_scatter_decor("tree_snag", [Terrain.FOREST], 4, all, 3)
	# Boulders and ferns where the fall lands.
	for i in 8:
		_prop(_pick("rock_granite" if i % 2 == 0 else "rock_mossy"), Vector2(FALL_CX + rng.randf_range(-60.0, 60.0), FALL_ROWS * T + rng.randf_range(8.0, 40.0)))
	for i in 10:
		_prop(_pick("plant_fern"), Vector2(FALL_CX + rng.randf_range(-72.0, 72.0), FALL_ROWS * T + rng.randf_range(0.0, 44.0)))
	# Wrought-iron lamps along the Village mall, the plaza and the lodge walk,
	# and benches where people sit.
	var lamps := [[52, 22], [60, 22], [68, 22], [76, 22], [84, 22], [92, 22], [64, 32], [76, 32], [38, 37], [34, 22], [42, 22]]
	for l: Array in lamps:
		if _has("lamp_wrought"):
			decor("Lamp%d_%d" % [l[0], l[1]], S + "lamp_wrought.png", foot(l[0], l[1]), Vector2(6, 4))
			_glow("lamp_wrought_glow", foot(l[0], l[1]) - Vector2(5, texture(S + "lamp_wrought.png").get_height()))
	for p in [[56, 22], [72, 22], [88, 22], [66, 31], [78, 31], [58, 41], [62, 45], [36, 28], [41, 33]]:
		_prop("garden_bench", foot(p[0], p[1]) + Vector2(0, 2))
	for p in [[50, 22], [94, 22], [63, 23], [81, 23]]:
		_prop(_pick("garden_urn"), foot(p[0], p[1]) + Vector2(0, -2))
	# Cars parked nose-in along the edges of the Village lot, leaving the
	# walk from Degnan's door to the road and the shuttle kiosk clear.
	var cars := [[82, 32, 0], [82, 35, 3], [95, 32, 7], [95, 35, 1]]
	for car: Array in cars:
		decor("Car%d_%d" % [car[0], car[1]], "res://assets/sprites/curry/car_%d.png" % car[2], foot(car[0], car[1]), Vector2(24, 12))
	_ambient("MeadowFireflies", "fireflies", Vector2(72, 43) * T, Vector2(24, 4) * T)
	_ambient("CreekFireflies", "fireflies", Vector2(46, 28) * T, Vector2(3, 14) * T)
