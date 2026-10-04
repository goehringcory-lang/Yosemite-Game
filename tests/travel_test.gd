extends Node
## Checks the park's regions and travel: every hub loads with walkable spawn
## points, doors and roads connect the regions, seasonal closures and locks
## are respected, and saves remember where the player is.
## Run: godot --headless --path . res://tests/travel_test.tscn
## Exit code is the number of failed checks.

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	SaveManager.save_path = "user://travel_test_save.json"
	SaveManager.delete_save()
	Engine.time_scale = 20.0

	_check_hub_maps()

	var world := await _start_world()
	check(world.region.region_id == Park.HOME_REGION, "a new game starts at the Lamon Homestead")
	check(Park.routes.size() == 10, "routes connect all five hubs (%d)" % Park.routes.size())
	var start := GameClock.minutes

	# The homestead gate leads into the Valley, near the Lamon orchard.
	await world.go_to_region("yosemite_valley", "lamon_homestead")
	check(world.region.region_id == "yosemite_valley", "the gate leads into Yosemite Valley")
	check(world.player.get_parent() == world.region.entities, "the player moved into the Valley's Entities")
	check(world.forage == null or world.forage.get_parent() == world.region.entities, "the Valley uses its own forage spawner")
	check(world.hud.location_label.text.begins_with("Yosemite Valley"), "location banner shows the hub (%s)" % world.hud.location_label.text)
	check(GameClock.minutes == start, "walking through the gate takes no clock time")
	var gate: Vector2 = world.player.position
	Input.action_press("move_down")
	for i in 20:
		await get_tree().physics_frame
	Input.action_release("move_down")
	check(world.player.position.distance_to(gate) > 4.0, "the player can walk around the Valley")

	# Spring 1: El Portal and Wawona are open; Glacier Point is locked and
	# Tuolumne's road is closed for snow.
	var legs := _legs_by_destination("yosemite_valley")
	check(legs.el_portal.open and legs.wawona.open, "roads to El Portal and Wawona are open in spring")
	check(not legs.glacier_point.open and legs.glacier_point.locked, "Glacier Point is locked until the Apron climb")
	check(not legs.tuolumne_meadows.open, "Tuolumne Meadows is out of reach in early spring")
	check(legs.tuolumne_meadows.minutes == 90 and legs.wawona.minutes == 60, "drive times match the park's estimates")

	# A kiosk opens the travel map; closing it gives control back.
	world.open_travel_map("wawona")
	check(world.park_map.visible and not world.player.can_act and GameClock.paused, "the travel map opens and pauses the game")
	world.park_map.close()
	check(not world.park_map.visible and world.player.can_act and not GameClock.paused, "closing the map resumes the game")

	# Drive to Wawona.
	var before := GameClock.minutes
	await world.travel(legs.wawona)
	check(world.region.region_id == "wawona", "drove to Wawona")
	check(GameClock.minutes - before == 60, "the drive took an hour (%d min)" % (GameClock.minutes - before))
	check(world.player.position == world.region.get_spawn("arrival").position, "arrived at Wawona's arrival point")

	# Unlocking Glacier Point isn't enough while its road is snowed in.
	Park.unlock_hub("glacier_point")
	var to_glacier := Park.best_leg("wawona", "glacier_point")
	check(not to_glacier.open and not to_glacier.locked, "Glacier Point Road is still closed in early spring")
	GameClock.season = GameClock.Season.SUMMER
	GameClock.day = 1
	to_glacier = Park.best_leg("wawona", "glacier_point")
	check(to_glacier.open, "Glacier Point Road is open in summer")
	await world.travel(to_glacier)
	check(world.region.region_id == "glacier_point", "drove to Glacier Point")
	check(world.region.get_spawn("apron_top") != null, "Glacier Point has the Apron climb's top spot")

	# A climb (or any other system) can move the player directly.
	get_tree().call_group("world", "go_to_region", "yosemite_valley", "apron_base")
	await get_tree().create_timer(2.5).timeout
	while world._busy:
		await get_tree().process_frame
	check(world.region.region_id == "yosemite_valley" and world.player.position == world.region.get_spawn("apron_base").position,
		"go_to_region lands on a named spot")

	# Tuolumne needs both an unlock and an open Tioga Road.
	check(not Park.best_leg("yosemite_valley", "tuolumne_meadows").open, "Tuolumne stays locked until the high-country unlock")
	Park.unlock_hub("tuolumne_meadows")
	var to_tuolumne := Park.best_leg("yosemite_valley", "tuolumne_meadows")
	check(to_tuolumne.open, "Tioga Road is open in summer")

	# It's too late for a long drive near midnight (arrival after 1 AM).
	GameClock.minutes = 23 * 60 + 40
	await world.travel(to_tuolumne)
	check(world.region.region_id == "yosemite_valley", "no 90-minute drive at 11:40 PM")
	GameClock.minutes = 9 * 60

	# Road exits open the travel map with the right destination picked.
	var exit: RegionExit = world.region.get_node("Map/Exits").get_child(0)
	world.use_exit(exit)
	check(world.park_map.visible and world.park_map._selected == exit.travel_to, "a road exit opens the map to %s" % exit.travel_to)
	world.park_map.close()

	# Saves remember the region and unlocked hubs.
	await world.travel(Park.best_leg("yosemite_valley", "tuolumne_meadows"))
	check(world.region.region_id == "tuolumne_meadows", "drove over Tioga Road to Tuolumne Meadows")
	var saved_position: Vector2 = world.player.position
	SaveManager.save_game()
	world.free()
	Park.unlocked_hubs.clear()
	world = await _start_world()
	check(world.region.region_id == "tuolumne_meadows" and world.player.position == saved_position,
		"loading puts the player back in Tuolumne (%s at %s, saved %s)" % [world.region.region_id, world.player.position, saved_position])
	check(Park.is_hub_unlocked("glacier_point"), "unlocked hubs are saved")
	check(world.forage == null or world.forage.get_parent() == world.region.entities, "Tuolumne uses its own forage spawner")

	# Staying up too late away from home: a ranger drives you back to camp.
	var day := GameClock.day
	GameClock.advance_minutes(GameClock.PASS_OUT_HOUR * 60)
	await get_tree().create_timer(3.0).timeout
	check(world.region.region_id == Park.HOME_REGION and GameClock.day == day + 1, "passing out away from home wakes you at the homestead")
	check(world.forage != null, "the homestead forage is back")

	_check_controls(world)
	await _check_central_hub(world)

	# Winter closes both seasonal roads.
	GameClock.season = GameClock.Season.WINTER
	legs = _legs_by_destination("yosemite_valley")
	check(not legs.glacier_point.open and not legs.tuolumne_meadows.open and legs.wawona.open, "winter closes Tioga and Glacier Point roads only")

	world.free()
	SaveManager.delete_save()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


## Space, C, click, and gamepad X interact now that there are no tools; the
## journal and pause menu open from their actions and close again.
func _check_controls(world: Node) -> void:
	var player: Player = world.player
	for action in ["interact", "use_tool"]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = true
		check(event.is_action_pressed(action), "%s is a working action" % action)
	for action in ["move_up", "move_down", "move_left", "move_right", "interact", "use_tool", "map", "journal", "pause",
			"tab_next", "tab_previous", "ui_cancel", "ui_accept"]:
		var joypad := InputMap.action_get_events(action).any(func(e: InputEvent) -> bool: return e is InputEventJoypadButton or e is InputEventJoypadMotion)
		var keyboard := InputMap.action_get_events(action).any(func(e: InputEvent) -> bool: return e is InputEventKey or e is InputEventMouseButton)
		check(joypad and keyboard, "%s works on keyboard/mouse and gamepad" % action)
	var journal: Journal = world.get_tree().get_first_node_in_group("journal")
	var pause: PauseMenu = world.get_tree().get_first_node_in_group("pause_menu")
	_press("journal")
	check(journal.is_open() and not player.can_act, "J opens the journal")
	_press("journal")
	check(not journal.is_open() and player.can_act, "J closes the journal")
	_press("pause")
	check(pause.is_open() and not player.can_act and GameClock.paused, "Esc opens the pause menu")
	_press("ui_cancel")
	check(not pause.is_open() and player.can_act, "Esc closes the pause menu")
	_press("map")
	check(world.park_map.visible, "M opens the map")
	_press("map")
	check(not world.park_map.visible and player.can_act, "M closes the map")


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	var release := InputEventAction.new()
	release.action = action
	Input.parse_input_event(release)
	Input.flush_buffered_events()


## The Yosemite Village central hub: drivers arrive there, every spot in it is
## reachable on foot (over its bridges), and the traders and shuttle work.
func _check_central_hub(world: Node) -> void:
	var to_valley := Park.best_leg(world.region.hub_id, "yosemite_valley")
	if world.region.hub_id == "yosemite_valley":
		await world.go_to_region("yosemite_village", "arrival")
	else:
		await world.travel(to_valley)
	check(world.region.region_id == "yosemite_village", "driving to the Valley arrives in Yosemite Village")
	var region: Region = world.region
	var open := _walkable_cells(region)
	var start := Vector2i(region.get_spawn("arrival").position / 16.0)
	var reached := _flood(open, start)
	var unreachable := PackedStringArray()
	for marker in region.get_node("Markers").get_children():
		if not reached.has(Vector2i((marker as Node2D).position / 16.0)):
			unreachable.append(marker.name)
	check(unreachable.is_empty(), "every spot in the Village hub is reachable on foot (%s)" % ", ".join(unreachable))
	var ground := region.get_ground()
	var bridges := ground.get_used_cells().filter(func(c: Vector2i) -> bool: return ground.get_cell_source_id(c) == 1 and ground.get_cell_atlas_coords(c).y == 18)
	check(bridges.size() >= 10, "the Village hub has bridges over the creek and river (%d tiles)" % bridges.size())
	check(region.find_children("*", "RegionExit", true, false).size() >= 4, "roads lead out of the Village hub")

	# Facing something usable shows a prompt naming the button and the action.
	var board: Node2D = region.find_child("Camp4Sign", true, false)
	world.player.position = board.position + Vector2(0, 14)
	world.player.facing = Vector2i.UP
	world.player.interaction_area.position = Vector2(0, -12)
	for i in 4:
		await get_tree().physics_frame
	await get_tree().process_frame
	check(world.hud.prompt_panel.visible and world.hud.prompt_label.text == "E  Read: Camp 4", "facing a sign shows its prompt (%s)" % world.hud.prompt_label.text)
	world.player.position = region.get_spawn("arrival").position
	for i in 4:
		await get_tree().physics_frame
	await get_tree().process_frame

	# Trading: food is the currency, and traders fill out a rack you already have.
	var rack: Vendor = region.find_child("RackTrader", true, false)
	var store: Vendor = region.find_child("StoreClerk", true, false)
	Gear.owned = {"approach_shoes": 1, "chalk_bag": 1}
	check(rack.available_offers().is_empty(), "the Camp 4 trader has nothing until you have a rope and two cams")
	Gear.owned = {"rope": 1, "harness": 1, "cam": 2}
	check(rack.available_offers().size() == 3, "with a starter rack the trader offers cams, draws, and a belay device")
	Inventory.items = {}
	var cam_offer: ShopOffer = rack.available_offers()[0]
	check(rack.buy(cam_offer).is_empty() and Gear.count("cam") == 2, "no food, no trade")
	Inventory.add("acorn_cake", 2)
	var paid := rack.buy(cam_offer)
	check(not paid.is_empty() and Gear.count("cam") == 3 and Inventory.count("acorn_cake") == 0, "two acorn cakes buy a third cam (paid %s)" % paid)
	Inventory.add("miners_lettuce", 6)
	var trail_mix: ShopOffer = store.available_offers()[0]
	check(not store.buy(trail_mix).is_empty() and Inventory.count("trail_mix") == 1 and Inventory.count("miners_lettuce") == 1,
		"the Village Store trades fresh forage for trail mix")

	# The shuttle runs from the Village to the rest of the Valley.
	var stop: ShuttleStop = region.find_child("ShuttleVillage", true, false)
	var before := GameClock.minutes
	stop.ride(stop.destinations().filter(func(d: Dictionary) -> bool: return d.name == "Happy Isles")[0])
	await get_tree().create_timer(2.5).timeout
	check(world.region.region_id == "yosemite_valley" and world.player.position == world.region.get_spawn("happy_isles").position,
		"the shuttle drops you at Happy Isles")
	check(GameClock.minutes - before == ShuttleStop.RIDE_MINUTES, "the shuttle ride takes %d minutes" % ShuttleStop.RIDE_MINUTES)
	for dest: Dictionary in ShuttleStop.STOPS:
		var scene: PackedScene = load(world.region_scene_path(dest.region))
		var probe: Region = scene.instantiate()
		add_child(probe)
		check(probe.get_spawn(dest.spawn) != null, "shuttle stop %s has a spot to land on" % dest.name)
		probe.free()


func _walkable_cells(region: Region) -> Dictionary:
	var ground := region.get_ground()
	var blocker: TileMapLayer = region.get_node("Blocker")
	var solid := [8, 9, 10, 11, 12, 14] # cliff, talus, scree, river, lake, falls
	var open := {}
	for c in ground.get_used_cells():
		if blocker.get_cell_source_id(c) == -1 and not (ground.get_cell_source_id(c) == 1 and ground.get_cell_atlas_coords(c).y in solid):
			open[c] = true
	for body in region.find_children("*", "StaticBody2D", true, false):
		if body is ShuttleStop or body is Vendor:
			continue
		var shape := body.get_node_or_null("Collision") as CollisionShape2D
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


func _start_world() -> Node:
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	return world


func _legs_by_destination(hub_id: String) -> Dictionary:
	var legs := {}
	for leg in Park.legs_from(hub_id):
		legs[leg.to] = leg
	return legs


## Every generated hub loads, and its spawn points and objects are on open ground.
func _check_hub_maps() -> void:
	for hub in ParkAtlas.HUBS:
		var region: Region = (load(hub.scene_path()) as PackedScene).instantiate()
		add_child(region)
		var blocker: TileMapLayer = region.get_node("Map/Blocker")
		var ground := region.get_ground()
		check(ground.get_used_rect().size.x > 100, "%s map loads (%s tiles)" % [hub.id, ground.get_used_rect().size])
		var spawns := region.get_node("Map/Spawns").get_children()
		var blocked := spawns.filter(func(m: Node2D) -> bool: return blocker.get_cell_source_id(blocker.local_to_map(m.position)) != -1)
		check(region.get_spawn("arrival") != null and blocked.is_empty(), "%s spawn points are walkable (%d spawns)" % [hub.id, spawns.size()])
		check(region.find_children("*", "TravelPoint", true, false).size() > 0, "%s has a map kiosk" % hub.id)
		check(region.get_places().size() >= 5, "%s has named places" % hub.id)
		region.free()
