extends Node
## Checks Curry Village, the first place you walk into after the Lamon
## Homestead gate: you arrive from the gate, every door and road is reachable
## on foot, the Camp Curry Store and the Mountain Shop have insides with
## shopkeepers who trade food for goods (without ever handing out the gear
## that opens a climbing tier), people live there, and the lamps come on at night.
## Run: godot --headless --path . res://tools/hubs/../../tests/curry_village_test.tscn
##   i.e. godot --headless --path . res://tests/curry_village_test.tscn
## Exit code is the number of failed checks.

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	SaveManager.save_path = "user://curry_test_save.json"
	SaveManager.delete_save()
	Engine.time_scale = 20.0
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame

	# The homestead gate leads into Curry Village.
	check(world.region.region_id == Park.HOME_REGION, "a new game starts at the Lamon Homestead")
	var gate: RegionExit = world.region.find_child("ToCurryVillage", true, false)
	check(gate != null and gate.target_region == "curry_village" and gate.target_spawn == "homestead", "the homestead's gate leads to Curry Village")
	var sign_door: RegionDoor = world.region.find_child("GateSign", true, false)
	check(sign_door != null and sign_door.target_region == "curry_village", "the gate sign goes to Curry Village too")
	world.use_exit(gate)
	await get_tree().create_timer(2.5).timeout
	check(world.region.region_id == "curry_village", "walking through the gate arrives in Curry Village")
	check(world.player.position.distance_to(world.region.get_spawn("homestead").position) < 4.0, "you arrive at the orchard gate")
	check(world.hud.location_label.text.contains("Curry Village"), "the location banner names it (%s)" % world.hud.location_label.text)

	var region: Region = world.region
	_check_region(region)
	await _check_night(world, region)
	_check_map(world, region)

	# Shop hours: the doors are locked at night and open by day.
	var store_exit: RegionExit = region.get_node("Exits/ToStore")
	var shop_exit: RegionExit = region.get_node("Exits/ToMountainShop")
	GameClock.paused = true
	GameClock.minutes = 12 * 60
	check(store_exit.is_open_now() and shop_exit.is_open_now(), "both shops are open at noon")
	GameClock.minutes = 19 * 60
	check(store_exit.is_open_now() and not shop_exit.is_open_now(), "the Mountain Shop is closed at 7 PM but the store is open")
	GameClock.minutes = 23 * 60
	check(not store_exit.is_open_now(), "the store is closed at 11 PM")
	check(store_exit.closed_message().contains("7 AM") and store_exit.closed_message().contains("9 PM"), "the sign says when it opens (%s)" % store_exit.closed_message())
	world.use_exit(store_exit)
	await get_tree().create_timer(1.0).timeout
	check(world.region.region_id == "curry_village", "walking into a closed door goes nowhere")
	GameClock.minutes = 12 * 60
	GameClock.paused = false

	# The Camp Curry Store.
	await world.go_to_region("curry_store", "door")
	check(world.region.region_id == "curry_store" and world.region.indoors, "the store is an inside room")
	check(not world.get_node("DayNight").visible, "the day and night tint is off indoors")
	var store: Region = world.region
	_check_inside(store, "store")
	var clerk: Vendor = store.find_child("StoreClerk", true, false)
	check(clerk != null and clerk.sprite_sheet != null, "the store has a clerk with a sprite")
	Inventory.add("miners_lettuce", 6)
	var offer := _offer(clerk, "pilot_bread")
	check(offer != null, "the store trades pilot bread")
	var paid := clerk.buy(offer)
	check(not paid.is_empty() and Inventory.count("pilot_bread") == 1, "forage buys pilot bread (paid %s)" % paid)
	check(Inventory.count("miners_lettuce") < 6, "the forage was used up")
	for offer2: ShopOffer in clerk.shop.offers:
		var item := ItemDB.get_item(offer2.id)
		check(item != null and item.icon != null and FoodDB.energy(offer2.id) > 0, "%s is a real food with an icon" % offer2.id)
		check(offer2.price > FoodDB.energy(offer2.id), "%s costs more energy than it gives" % offer2.id)

	# The Mountain Shop.
	await world.go_to_region("curry_mountain_shop", "door")
	check(world.region.region_id == "curry_mountain_shop" and world.region.indoors, "the Mountain Shop is an inside room")
	var shop_room: Region = world.region
	_check_inside(shop_room, "Mountain Shop")
	var keeper: Vendor = shop_room.find_child("ShopClerk", true, false)
	check(keeper != null and keeper.sprite_sheet != null, "the Mountain Shop has a clerk with a sprite")
	check(keeper.available_offers().is_empty(), "with starting gear the shop has nothing to trade yet")
	Gear.add("rope")
	Gear.add("harness")
	var stock := keeper.available_offers().map(func(o: ShopOffer) -> String: return o.id)
	check("quickdraw" in stock and not "belay_device" in stock, "a rope brings out quickdraws, but the belay device comes from Royal Robbins %s" % [stock])
	check(not ("cam" in stock), "cams only come once you have two: the shop can't hand you a tier")
	var apron: RouteData = load("res://data/routes/glacier_point_apron.tres")
	Inventory.add("trail_mix", 10)
	for _i in 6:
		for o in keeper.available_offers():
			keeper.buy(o)
	check(not Gear.has_all(apron.required_gear), "shopping alone can't open the Glacier Point Apron")
	check(Gear.count("quickdraw") > 0, "food buys quickdraws")
	Gear.add("cam", 2)
	check("cam" in keeper.available_offers().map(func(o: ShopOffer) -> String: return o.id), "with two cams, the shop sells more")
	for o: ShopOffer in keeper.shop.offers:
		check(not o.requires.is_empty(), "%s always needs gear you already own" % o.id)

	# Standing at the counter, you can talk to the clerk.
	world.player.global_position = keeper.global_position + Vector2(0, 40)
	world.player.interaction_area.position = Vector2(0, -12)
	for _i in 4:
		await get_tree().physics_frame
	var talks: bool = world.player.interaction_area.get_overlapping_areas().any(func(a: Area2D) -> bool: return a.get_parent() == keeper)
	check(talks, "from in front of the counter, the Mountain Shop clerk is in reach")

	world.free()
	SaveManager.delete_save()
	get_tree().quit(failures)


func _offer(vendor: Vendor, id: String) -> ShopOffer:
	for o: ShopOffer in vendor.shop.offers:
		if o.id == id:
			return o
	return null


## Spawns, doors and signs exist and can be walked to from the orchard gate.
func _check_region(region: Region) -> void:
	for spawn in ["arrival", "homestead", "shuttle", "store_door", "shop_door", "registration_porch", "plaza", "apron_trailhead", "west_road", "east_road", "campsite_west", "campsite_center", "campsite_east"]:
		check(region.get_spawn(spawn) != null, "Curry Village has a %s spot" % spawn)
	var ground := region.get_ground()
	check(ground.get_used_rect().size == Vector2i(100, 64), "the village is 100 x 64 tiles")
	var painting := region.get_node_or_null("GroundArt") as Sprite2D
	check(painting != null and painting.texture.get_size() == Vector2(1600, 1024), "the ground is one painted picture")
	check(not ground.visible, "the tile ground underneath stays hidden")
	var tents := region.find_children("TentCabin*", "StaticBody2D", true, false)
	check(tents.size() >= 48, "the camp has its tent cabins (%d)" % tents.size())
	check(region.find_children("AppleTree*", "StaticBody2D", true, false).size() >= 20, "the old orchard has its apple trees")
	for prop in ["Registration", "Pavilion", "CurryStore", "MountainShop", "PizzaDeck", "Amphitheater", "Pool", "FirefallBoard", "Flagpole", "EntranceArch"]:
		check(region.find_child(prop, true, false) != null, "%s is there" % prop)
	var open := _walkable(region)
	var start := Vector2i(region.get_spawn("homestead").position / 16.0)
	var reached := _flood(open, start)
	var unreachable := PackedStringArray()
	for spawn in ["arrival", "shuttle", "store_door", "shop_door", "registration_porch", "plaza", "apron_trailhead", "west_road", "east_road", "campsite_west", "campsite_center", "campsite_east"]:
		if not reached.has(Vector2i(region.get_spawn(spawn).position / 16.0)):
			unreachable.append(spawn)
	check(unreachable.is_empty(), "every spot can be walked to from the gate %s" % unreachable)
	var exits := PackedStringArray()
	for exit: Area2D in region.get_node("Exits").get_children():
		var near := false
		var cell := Vector2i(exit.position / 16.0)
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				near = near or reached.has(cell + Vector2i(dx, dy))
		if not near:
			exits.append(exit.name)
	check(exits.is_empty(), "every door and road exit can be reached %s" % exits)
	var signs := PackedStringArray()
	for info: InfoSign in region.find_children("*", "InfoSign", true, false):
		var cell := Vector2i(info.position / 16.0)
		var near := false
		for dy in range(-3, 3):
			for dx in range(-3, 4):
				near = near or reached.has(cell + Vector2i(dx, dy))
		if not near:
			signs.append(info.name)
	check(signs.is_empty(), "every sign can be read from open ground %s" % signs)
	var stuck := PackedStringArray()
	for node in region.entities.get_children():
		if node is TravelPoint or node is ShuttleStop:
			var cell := Vector2i((node as Node2D).position / 16.0)
			var near := false
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					near = near or reached.has(cell + Vector2i(dx, dy))
			if not near:
				stuck.append(node.name)
	check(stuck.is_empty(), "the kiosk and the shuttle stop can be used %s" % stuck)
	check(region.find_child("Travel_CurryVillageParking", true, false) != null, "there is a map kiosk in the parking lot")
	var shuttle: ShuttleStop = region.find_child("ShuttleCurry", true, false)
	check(shuttle != null and shuttle.stop_name == "Curry Village", "the shuttle stops here")
	# Story: Jennie Curry lives here now, and the Valley map doesn't have her.
	var jennie := region.find_child("JennieCurry", true, false)
	check(jennie != null, "Jennie Curry is at the Registration Office")
	var people := 0
	for node in region.entities.get_children():
		if node is NPC:
			people += 1
	check(people >= 5, "people are about (%d)" % people)


func _check_inside(room: Region, label: String) -> void:
	for spawn in ["door", "counter", "customer"]:
		check(room.get_spawn(spawn) != null, "the %s has a %s spot" % [label, spawn])
	var open := _walkable(room)
	var reached := _flood(open, Vector2i(room.get_spawn("door").position / 16.0))
	check(reached.has(Vector2i(room.get_spawn("customer").position / 16.0)), "the customer's spot in the %s can be walked to" % label)
	var counter_cell := Vector2i(room.get_spawn("counter").position / 16.0)
	var can_reach_counter := false
	for dy in range(-1, 3):
		for dx in range(-1, 2):
			can_reach_counter = can_reach_counter or reached.has(counter_cell + Vector2i(dx, dy))
	check(can_reach_counter, "you can walk up to the %s counter" % label)
	var exit: RegionExit = room.get_node("Exits/ToCurry")
	check(exit.target_region == "curry_village", "the %s door leads back out" % label)
	check(room.find_children("*", "NPC", true, false).size() >= 1, "someone is shopping in the %s" % label)


func _check_night(world: Node, region: Region) -> void:
	var lights := region.find_children("*", "PointLight2D", true, false)
	check(lights.size() >= 30, "the village has lamps, windows and fires that glow (%d)" % lights.size())
	GameClock.paused = true
	GameClock.minutes = 12 * 60
	for _i in 6:
		await get_tree().process_frame
	var lit_by_day := lights.filter(func(l: PointLight2D) -> bool: return l.energy > 0.05).size()
	var tint := world.get_node("DayNight") as CanvasModulate
	check(lit_by_day == 0, "no lamps burn at noon (%d; tint %s, progress %.2f, first light %.2f)" % [lit_by_day, tint.color, GameClock.get_day_progress(), (lights[0] as PointLight2D).energy])
	GameClock.minutes = 23 * 60
	for _i in 6:
		await get_tree().process_frame
	var lit_at_night := lights.filter(func(l: PointLight2D) -> bool: return l.energy > 0.3).size()
	check(lit_at_night >= lights.size() * 0.8, "the lamps are lit at 11 PM (%d of %d)" % [lit_at_night, lights.size()])
	GameClock.minutes = 12 * 60
	GameClock.paused = false


func _check_map(world: Node, region: Region) -> void:
	world.open_map()
	var map: ParkMap = world.park_map
	check(map.visible and map._tab == ParkMap.Tab.AREA, "M opens the Valley map from Curry Village")
	check(map._points[map._cursor].id == "curry_village", "the cursor starts on Curry Village (%s)" % map._points[map._cursor].id)
	map.close()


## Open ground: not cliff, water, blockers, or under a prop's footprint.
func _walkable(region: Region) -> Dictionary:
	var ground := region.get_ground()
	var blocker: TileMapLayer = region.get_node("Blocker")
	var solid := [8, 9, 10, 11, 12, 14]
	var open := {}
	for c in ground.get_used_cells():
		if blocker.get_cell_source_id(c) == -1 and not (ground.get_cell_source_id(c) == 1 and ground.get_cell_atlas_coords(c).y in solid):
			open[c] = true
	for body in region.find_children("*", "StaticBody2D", true, false):
		if body is ShuttleStop or body is Vendor or body is TravelPoint:
			continue
		for shape_node in body.get_children():
			var shape := shape_node as CollisionShape2D
			if shape and shape.shape is RectangleShape2D:
				var rect := Rect2((body as Node2D).position + shape.position - shape.shape.size / 2.0, shape.shape.size)
				for y in range(floori(rect.position.y / 16.0), floori(rect.end.y / 16.0) + 1):
					for x in range(floori(rect.position.x / 16.0), floori(rect.end.x / 16.0) + 1):
						if rect.grow(-minf(3.0, minf(rect.size.x, rect.size.y) / 3.0)).intersects(Rect2(x * 16, y * 16, 16, 16)):
							open.erase(Vector2i(x, y))
	return open


func _flood(open: Dictionary, start: Vector2i) -> Dictionary:
	var reached := {start: true}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if open.has(c + d) and not reached.has(c + d):
				reached[c + d] = true
				queue.append(c + d)
	return reached
