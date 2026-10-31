extends AhwahneeStyle
## Builds the Yosemite Valley central hub: Yosemite Village and Camp 4 at
## walking scale, with their stores, the Indian Village, the gear traders,
## the creek and river bridges, and roads out to the trail scenes between
## the Valley's areas.
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
## east and north (the Valley wall) to south (the Merced). The Village itself
## follows the real one: the Welcome Center, Museum, Best's Studio (now the
## Ansel Adams Gallery), Wilderness Center and Post Office along the north side
## of the pedestrian mall, the Indian Village behind the Museum, the cemetery
## across from it, Degnan's and the Village Store round a plaza at the east
## end with the store's lot beside it; the Lodge south of Northside Drive and
## west of Yosemite Creek; Cook's Meadow between the creek and Sentinel Drive,
## the Camp 6 day-use lot east of it, and the Chapel on Southside Drive.
##
## Rebuild onto the game's 32px grid with tools/hubs/rebuild_village.sh.

const HubArt = preload("res://tools/hubs/hub_art.gd")
const ValleyArt = preload("res://tools/hubs/valley_art.gd")
const Camp4Art = preload("res://tools/hubs/camp4_art.gd")
const ValleyLandArt = preload("res://tools/hubs/valley_land_art.gd")
const HotelArt = preload("res://tools/hubs/ahwahnee_hotel_art.gd")

const W := 120
const H := 64
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
	# Yosemite Valley Lodge: south of Northside Drive, west of the creek.
	_rect(32, 40, 43, 46, Terrain.PAVED)
	_rect(25, 40, 31, 44, Terrain.PARKING)
	# The Indian Village behind the museum, in the oaks.
	_rect(50, 9, 68, 18, Terrain.FOREST)
	_clear_trees(50, 10, 68, 18)
	# The Village: the pedestrian mall with its buildings along the north side,
	# a plaza at the east end in front of Degnan's and the Village Store, and
	# the store's parking lot east of it.
	_rect(50, 23, 92, 25, Terrain.PAVED)
	_rect(66, 26, 68, 31, Terrain.PAVED)
	_rect(95, 26, 97, 32, Terrain.PAVED)
	_rect(66, 32, 98, 36, Terrain.PAVED)
	_rect(100, 24, 116, 36, Terrain.PARKING)
	# A paved walk from each door down to the mall, so no door opens onto grass.
	for door_x in [56, 64, 72, 79, 86]:
		_rect(door_x - 1, 22, door_x + 1, 22, Terrain.PAVED)
	# Yosemite Cemetery, across the mall from the museum, under the trees.
	_rect(53, 27, 63, 35, Terrain.FOREST)
	_clear_trees(53, 26, 63, 35)
	# Cook's Meadow, between Yosemite Creek and Sentinel Drive.
	_rect(47, 40, 81, 49, Terrain.MEADOW)
	_rect(51, 43, 56, 45, Terrain.WET_MEADOW)
	_rect(69, 42, 75, 44, Terrain.WET_MEADOW)
	# Camp 6, the Village's day-use lot, east of Sentinel Drive.
	_rect(88, 40, 112, 46, Terrain.PARKING)
	# The Chapel's forecourt on Southside Drive.
	_rect(74, 59, 78, 59, Terrain.PAVED)
	_rect(8, 49, 18, 49, Terrain.SAND)
	_rect(62, 49, 72, 49, Terrain.SAND)

	# Roads and trails (remembered so crossings with water become bridges).
	var paths := [
		[Terrain.ROAD, 0, 38, W - 1, 38], # Northside Drive
		[Terrain.ROAD, 0, 60, W - 1, 60], # Southside Drive
		[Terrain.ROAD, 84, 39, 84, 60], # Sentinel Drive and Sentinel Bridge, ending at Southside Drive
		[Terrain.ROAD, 26, 37, 27, 37], # Camp 4 parking
		[Terrain.ROAD, 28, 39, 29, 39], # Lodge parking
		[Terrain.ROAD, 51, 26, 52, 37], # Village Drive to the Welcome Center stop
		[Terrain.ROAD, 108, 37, 109, 37], # Village Store parking
		[Terrain.ROAD, 100, 39, 101, 39], # Camp 6 parking
		[Terrain.PAVED, 37, 39, 38, 39], # Lodge walk
		[Terrain.TRAIL, 15, 31, 15, 37], # Camp 4 walk-in path
		[Terrain.TRAIL, 33, 20, 47, 20], # Camp 4 to the fall trail, over the creek
		[Terrain.TRAIL, 47, 10, 47, 37], # Lower Yosemite Fall trail
		[Terrain.TRAIL, 46, 10, 48, 10],
		[Terrain.TRAIL, 48, 24, 49, 24], # fall trail to the mall
		[Terrain.TRAIL, 51, 14, 66, 14], # Indian Village loop
		[Terrain.TRAIL, 60, 15, 60, 22],
		[Terrain.TRAIL, 58, 26, 58, 27], # into the cemetery
		[Terrain.BRIDGE, 57, 39, 57, 46], # Cook's Meadow boardwalk
		[Terrain.TRAIL, 57, 47, 83, 47], # boardwalk on to Sentinel Bridge
		[Terrain.TRAIL, 22, 39, 22, 59], # Swinging Bridge trail
		[Terrain.TRAIL, 23, 47, 31, 47], # Lodge to the Swinging Bridge trail
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
	for y in range(10, 51):
		var x := 44 if y < 17 or (y >= 28 and y < 37) else 45
		water[y * W + x] = 1
		water[y * W + prev_x] = 1
		prev_x = x
	for x in W:
		var bank := 50 + int(noise.get_noise_1d(x * 2.0 + 40.0) * 1.5)
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
	_clear_trees(25, 39, 44, 47)
	_clear_trees(64, 19, 99, 37)
	_clear_trees(50, 19, 53, 37)
	_clear_trees(72, 54, 80, 59)


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
	# the town clutter (tools/hubs/dress_towns.gd), in world pixels already
	instance_scene("res://scenes/regions/dressing/yosemite_village.tscn", Vector2.ZERO, "Dressing")
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
	# The north side of the mall, west to east.
	_building("WelcomeCenter", "welcome_center", 56, 22, "Yosemite Valley Welcome Center",
		"Maps, trail conditions, road closures, and Junior Ranger booklets. The Lower Yosemite Fall trail and the Cook's Meadow boardwalk both start close by.")
	_building("YosemiteMuseum", "museum", 64, 22, "Yosemite Museum",
		"The museum opened in 1926 and shows the Valley's art and cultural history. Its ground floor is laid up from Valley granite. The Indian Village stands behind it.")
	_building("BestsStudio", "bests_studio", 72, 22, "Best's Studio",
		"Harry Best opened a painting studio in the Valley in 1902. His daughter Virginia married Ansel Adams, and the studio became The Ansel Adams Gallery.")
	_building("WildernessCenter", "wilderness_center", 79, 22, "Wilderness Center",
		"Rangers issue wilderness permits and check the trail conditions here.")
	_building("PostOffice", "post_office", 86, 22, "Yosemite Valley Post Office",
		"The Valley's post office. Mail sent from here is postmarked Yosemite National Park.")
	# Degnan's and the Village Store round the plaza at the east end.
	_building("Degnans", "degnans", 73, 32, "Degnan's",
		"John and Bridget Degnan came to the Valley in 1884. Bridget sold bread from her porch before they opened a bakery and store, and her bread was famous with visitors.")
	_building("VillageStore", "village_store", 90, 33, "Village Store",
		"The Valley's general store: groceries, supplies, and gifts. Trade fresh forage here for trail food that keeps.")
	# South of Northside Drive and the river.
	_building("ValleyLodge", "valley_lodge", 38, 45, "Yosemite Valley Lodge",
		"The lodge stands near the foot of Yosemite Falls, across Northside Drive from the Lower Yosemite Fall trail and a short walk from Camp 4.")
	_building("YosemiteChapel", "chapel", 76, 59, "Yosemite Chapel",
		"Yosemite Chapel was built in 1879 near the old village, and moved here, across the river from Cook's Meadow, in 1901. It is the oldest building in Yosemite Valley still in use.")
	# Flags at the Welcome Center and the Post Office.
	var CS_ := "res://assets/sprites/curry/"
	animate(decor("WelcomeFlagpole", CS_ + "flagpole.png", foot(52, 21), Vector2(6, 4)), 3, 2.5)
	animate(decor("PostOfficeFlagpole", CS_ + "flagpole.png", foot(90, 21), Vector2(6, 4)), 3, 2.5)


## Yosemite Cemetery: a low picket fence round the plot with its gate toward
## the mall, granite and wooden headstones under the oaks, and Galen Clark's
## grave with the giant sequoias he planted round it.
func _place_cemetery() -> void:
	var CS_ := "res://assets/sprites/curry/"
	for x in range(53, 64):
		if x < 57 or x > 59:
			decor("CemeteryFenceN%d" % x, CS_ + "fence_h.png", foot(x, 27), Vector2(16, 4))
		decor("CemeteryFenceS%d" % x, CS_ + "fence_h.png", foot(x, 35), Vector2(16, 4))
	for y in range(28, 36):
		decor("CemeteryFenceW%d" % y, CS_ + "fence_v.png", foot(52.8, y), Vector2(6, 16))
		decor("CemeteryFenceE%d" % y, CS_ + "fence_v.png", foot(63.2, y), Vector2(6, 16))
	_sign_prop("CemeterySign", "res://assets/sprites/info_sign.png", foot(56, 27) + Vector2(0, -4), Vector2(12, 4), "Yosemite Cemetery",
		"People of the Valley have been buried here since the 1870s: Native families who lived here, early settlers, and park workers. Some graves are marked with granite, some with wood, and some not at all.")
	var stones := [[54, 29, 0], [54, 31.5, 1], [54, 34, 2], [56.5, 34, 0], [58.5, 34, 1], [61, 34, 2], [62.5, 34, 0]]
	for st: Array in stones:
		decor("Headstone%d_%d" % [roundi(st[0] * 10), roundi(st[1] * 10)], B + "headstone_%d.png" % st[2], foot(st[0], st[1]), Vector2(10, 4))
	# Galen Clark's grave, ringed by his sequoias.
	_sign_prop("ClarkGrave", B + "headstone_clark.png", foot(59, 31), Vector2(16, 4), "Galen Clark",
		"Galen Clark, 1814 to 1910, the first Guardian of Yosemite. He chose this plot himself and planted the giant sequoia seedlings around it years before he died.")
	for at_pos in [foot(56.5, 31), foot(61.5, 31), foot(59, 29)]:
		decor("Sequoia%d" % _entities.get_child_count(), B + "tree_sequoia.png", at_pos, Vector2(10, 6))
	_prop("tree_dogwood_bloom_a", foot(62.5, 32))


## Camp 4 as it is laid out on the ground: walk-in sites under the pines,
## each with its tents, a picnic table, a bear box and a steel fire ring,
## around a shared fire; Columbia Boulder at the back by the talus, with
## Midnight Lightning chalked on its face, and the search and rescue site
## beside it (in the story overlay); a slackline, the gear traders, the
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
	# The back corner by the talus, east of Columbia Boulder, is the search
	# and rescue site's tent cabins and cache (the Yosemite Village story
	# overlay), so no walk-in site there.
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
		"Notes pinned three deep: partners wanted for Royal Arches, a rack for trade, rides to the Tuolumne, and a weather report for the week. Climbers have found partners on this board for generations.",
		"res://scripts/objects/bulletin_board.gd")
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
	# These descriptions have been reviewed with the associated tribes.
	var homes := [[53, 12], [57, 11], [63, 11], [55, 16], [66, 15]]
	for i in homes.size():
		var h: Array = homes[i]
		_sign_prop("Umacha%d" % i, B + "umacha.png", _tile_pos(h[0], h[1]) + Vector2(0, 6), Vector2(24, 8), "Umacha",
			"A cone-shaped home of incense-cedar bark slabs laid over a frame of poles. Families in Yosemite Valley lived in umachas like this one.")
	_sign_prop("Chuckah", B + "chuckah.png", _tile_pos(62, 16) + Vector2(0, 6), Vector2(12, 6), "Chuckah",
		"An acorn granary: a tall woven store on poles under a thatched cap. It keeps a family's acorns dry and away from animals through the year.")
	var mortar := _instance("res://scenes/story/station.tscn", _tile_pos(52, 17) + Vector2(0, 4), "GrindingRock")
	mortar.set("station", "mortar")
	mortar.set("display_name", "Grinding rock")
	mortar.set("texture", texture("res://assets/sprites/lamon/mortar_slab.png"))
	mortar.set("ground_inset", 5)
	mortar.set("body_size", Vector2(50, 10))
	mortar.set("reach_size", Vector2(60, 26))
	_sign_prop("IndianVillageSign", "res://assets/sprites/info_sign.png", _tile_pos(61, 18) + Vector2(0, 4), Vector2(12, 4), "Indian Village",
		"This village behind the Yosemite Museum shows how Native families lived in the Valley: bark homes, acorn granaries, and grinding rocks worn into the granite. The Southern Sierra Miwuk and neighboring peoples still live and work in and around Yosemite today.")
	_place_cemetery()
	# The Village Store clerk trades trail food for forage.
	_vendor("StoreClerk", "res://data/shops/village_store.tres", _tile_pos(90, 34) + Vector2(0, 2), Color(0.3, 0.5, 0.35))
	_instance("res://scenes/objects/travel_point.tscn", _tile_pos(98, 41) + Vector2(0, 4), "Travel_YosemiteVillageParking").set("label", "Yosemite Village Parking")
	_shuttle("ShuttleVillage", "Yosemite Village", _tile_pos(50, 26) + Vector2(0, 4))
	_sign_prop("LowerFallSign", "res://assets/sprites/info_sign.png", _tile_pos(49, 11) + Vector2(0, 4), Vector2(12, 4), "Lower Yosemite Fall",
		"Lower Yosemite Fall drops 320 feet. It roars with snowmelt in late spring and can dry to a trickle by late summer.")
	_sign_prop("LowerFallTrailhead", "res://assets/sprites/info_sign.png", _tile_pos(48, 36) + Vector2(0, 4), Vector2(12, 4), "Lower Yosemite Fall Trail",
		"A short walk north to the foot of Lower Yosemite Fall, with the creek alongside. In spring the spray reaches the bridge.")
	_sign_prop("CooksMeadowSign", "res://assets/sprites/info_sign.png", _tile_pos(58, 40) + Vector2(0, 4), Vector2(12, 4), "Cook's Meadow",
		"From the boardwalk you can see Yosemite Falls to the north and Half Dome to the east. Stay on the boardwalk: meadows here are easily trampled.")
	_sign_prop("SentinelBridgeSign", "res://assets/sprites/info_sign.png", _tile_pos(82, 45) + Vector2(0, 4), Vector2(12, 4), "Sentinel Bridge",
		"Look upriver: Half Dome stands over the Merced, and on a still morning it is mirrored in the water. It is one of the most photographed views in the park.")
	_sign_prop("SwingingBridgeSign", "res://assets/sprites/info_sign.png", _tile_pos(23, 47) + Vector2(0, 4), Vector2(12, 4), "Swinging Bridge",
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
	_marker("arrival", 99, 43)
	_marker("camp_4", 20, 20)
	_marker("camp_4_fire", 18, 22)
	_marker("sar_site", 18, 15)
	_marker("shuttle_camp_4", 24, 36)
	_marker("shuttle_village", 50, 25)
	_marker("lower_yosemite_fall", 47, 12)
	_marker("cooks_meadow", 59, 42)
	_marker("indian_village", 60, 15)
	_marker("village_store", 90, 34)
	_marker("degnans_bakery", 73, 33)
	_marker("bests_studio", 72, 23)
	_marker("yosemite_museum", 64, 23)
	_marker("ranger_station", 79, 23)
	_marker("welcome_center", 56, 23)
	_marker("post_office", 86, 23)
	_marker("cemetery", 58, 30)
	_marker("chapel", 76, 60)
	# Beside the lodge door, not on its step: three visitors start the day here.
	_marker("valley_lodge", 41, 46)
	_marker("west_road", 2, 38)
	_marker("east_road", W - 3, 38)
	_marker("southside_west", 2, 60)
	_marker("southside_east", W - 3, 60)
	_place("Camp 4", 18, 20, 16)
	_place("Yosemite Valley Lodge", 38, 43, 6)
	_place("Lower Yosemite Fall", 46, 9, 5)
	_place("Indian Village", 59, 13, 7)
	_place("Yosemite Village", 76, 26, 16)
	_place("Village Store", 90, 31, 4, false)
	_place("Yosemite Cemetery", 58, 31, 4)
	_place("Cook's Meadow", 64, 44, 13)
	_place("Camp 6 parking", 100, 43, 7, false)
	_place("Merced River", 50, 51, 3, false)
	_place("Sentinel Bridge", 84, 51, 3)
	_place("Swinging Bridge", 22, 51, 3)
	_place("Yosemite Chapel", 76, 56, 3)


## Roads out of the hub lead onto the trail scenes between the Valley's
## areas (tools/hubs/build_valley_floor.gd).
func _place_exits() -> void:
	var exits := [
		["NorthsideWest", Vector2i(0, 38), "leidig_meadow", "east", "Northside Drive west", true],
		["NorthsideEast", Vector2i(W - 1, 38), "ahwahnee_meadow", "west", "Northside Drive east", true],
		["SouthsideWest", Vector2i(0, 60), "four_mile_trailhead", "east", "Southside Drive west", true],
		["SouthsideEast", Vector2i(W - 1, 60), "housekeeping_camp", "west", "Southside Drive east", true],
	]
	for e: Array in exits:
		var area := Area2D.new()
		area.set_script(load("res://scripts/world/region_exit.gd"))
		area.name = e[0]
		area.position = _tile_pos(e[1].x, e[1].y)
		area.set("label", e[4])
		area.set("target_region", e[2])
		area.set("target_spawn", e[3])
		var shape := CollisionShape2D.new()
		shape.name = "Shape"
		var rect := RectangleShape2D.new()
		rect.size = Vector2(12, 16) if e[5] else Vector2(16, 12)
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
	var meadow := Rect2i(47, 40, 35, 10)
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
	# Wrought-iron lamps along the mall, round the plaza, at the lodge and the
	# Welcome Center stop, and benches where people sit.
	var lamps := [[53, 26], [61, 26], [69, 26], [77, 26], [85, 26], [92, 26], [65, 36], [78, 37], [93, 37],
		[34, 22], [42, 22], [33, 47], [43, 47], [50, 31], [99, 37]]
	for l: Array in lamps:
		if _has("lamp_wrought"):
			decor("Lamp%d_%d" % [l[0], l[1]], S + "lamp_wrought.png", foot(l[0], l[1]), Vector2(6, 4))
			_glow("lamp_wrought_glow", foot(l[0], l[1]) - Vector2(5, texture(S + "lamp_wrought.png").get_height()))
	for p in [[73, 26], [81, 26], [89, 26], [80, 36], [86, 37], [36, 47], [40, 47], [55, 41], [62, 48]]:
		_prop("garden_bench", foot(p[0], p[1]) + Vector2(0, 2))
	for p in [[50, 22], [91, 23], [65, 27], [69, 27]]:
		_prop(_pick("garden_urn"), foot(p[0], p[1]) + Vector2(0, -2))
	# Flower barrels either side of each door, umbrella tables on Degnan's
	# patio, and a bike rack by the store, so the Village looks lived in.
	var CS_ := "res://assets/sprites/curry/"
	for door: Array in [[56, 21], [64, 21], [72, 21], [79, 21], [86, 21], [73, 31], [90, 32]]:
		for side in [-2, 2]:
			# each door's pair matches, and the doors differ
			decor("Planter%d_%d_%d" % [door[0], door[1], side], CS_ + "planter_%d.png" % ((door[0] + door[1]) % 4), foot(door[0] + side, door[1] + 1) + Vector2(0, -2), Vector2(12, 6))
	for t in [[69, 34], [77, 34]]:
		decor("PatioTable%d" % t[0], CS_ + "patio_table.png", foot(t[0], t[1]), Vector2(20, 8))
	decor("BikeRack", CS_ + "bike_rack.png", foot(96, 34), Vector2(30, 6))
	# Shade trees left standing round the plaza and through Camp 6, as in the
	# real Village.
	for at_pos in [foot(83, 35), foot(70, 28) + Vector2(8, 0)]:
		_prop("tree_black_oak_a", at_pos)
	_prop("tree_dogwood_bloom_b", foot(78, 29))
	_prop("tree_incense_cedar_a", foot(81, 29))
	for x in [93, 101, 107]:
		_prop(_pick("tree_ponderosa"), foot(x, 44) + Vector2(8, 0))
	_prop("tree_black_oak_b", foot(106, 30) + Vector2(8, 0))
	# Cars parked nose-in in rows: the Village Store lot and Camp 6.
	var cars := [[101, 27], [103, 27], [107, 27], [111, 27], [113, 27], [102, 32], [104, 32], [110, 32], [114, 32],
		[89, 42], [91, 42], [95, 42], [103, 42], [105, 42], [109, 42], [92, 46], [96, 46], [104, 46], [106, 46], [110, 46],
		[26, 43], [30, 43]]
	for i in cars.size():
		var car: Array = cars[i]
		decor("Car%d_%d" % [car[0], car[1]], CS_ + "car_%d.png" % ((i * 5 + car[0]) % 12), foot(car[0], car[1]), Vector2(24, 12))
	_ambient("MeadowFireflies", "fireflies", Vector2(64, 44) * T, Vector2(16, 4) * T)
	_ambient("CreekFireflies", "fireflies", Vector2(46, 30) * T, Vector2(3, 14) * T)
