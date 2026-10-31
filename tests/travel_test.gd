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

	# The homestead gate leads into Curry Village, in the Valley.
	await world.go_to_region("curry_village", "homestead")
	check(world.region.region_id == "curry_village", "the gate leads into Curry Village")
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

	# The Ledge Trail: down to Curry Village from beside the hotel site, and
	# back up, which is open now that Glacier Point is.
	var ledge_down: RegionDoor = world.region.find_child("LedgeTrail", true, false)
	var ledge_top: Node2D = world.region.get_spawn("ledge_trail_top")
	check(ledge_down != null and ledge_top != null and ledge_top.position.distance_to(ledge_down.position) < 96.0, "the Ledge Trail tops out beside its own spot")
	check(ledge_down != null and await _can_use(world.player, ledge_down), "and its trailhead can be walked up to")
	ledge_down.interact(world.player)
	await get_tree().create_timer(2.5).timeout
	while world._busy:
		await get_tree().process_frame
	check(world.region.region_id == "curry_village" and world.player.position == world.region.get_spawn("ledge_trailhead").position,
		"the Ledge Trail comes down behind Curry Village")
	var ledge_up: RegionDoor = world.region.find_child("LedgeTrail", true, false)
	check(ledge_up != null and ledge_up.is_unlocked() and await _can_use(world.player, ledge_up), "and its foot can be walked up to")
	var set_out := GameClock.minutes
	ledge_up.interact(world.player)
	await get_tree().create_timer(2.5).timeout
	while world._busy:
		await get_tree().process_frame
	check(world.region.region_id == "glacier_point" and world.player.position == world.region.get_spawn("ledge_trail_top").position,
		"the Ledge Trail climbs back to Glacier Point")
	check(GameClock.minutes - set_out == ledge_up.minutes, "the climb up takes its time (%d min)" % (GameClock.minutes - set_out))

	# Topping out the Apron before the road opens: the map points to the trail down.
	GameClock.season = GameClock.Season.SPRING
	GameClock.day = 3
	world.open_travel_map("yosemite_valley")
	check(world.park_map._route_label.text.contains("On foot: Four Mile Trail"), "with the road snowed in, the map names the trail down (%s)" % world.park_map._route_label.text)
	check(world.park_map._info_panel.get_combined_minimum_size().y <= ParkMap.INFO_RECT.size.y, "and the note still fits the panel")
	world.open_travel_map("")
	check(world.park_map._route_label.text.contains("Every road out is closed") and world.park_map._route_label.text.contains("Four Mile Trail"), "a kiosk says so too (%s)" % world.park_map._route_label.text)
	world.park_map.close()
	GameClock.season = GameClock.Season.SUMMER
	GameClock.day = 1
	world.open_travel_map("yosemite_valley")
	check(not world.park_map._route_label.text.contains("On foot"), "with the road open, the map just gives the drive")
	world.park_map.close()

	# A climb (or any other system) can move the player directly.
	get_tree().call_group("world", "go_to_region", "el_capitan_meadow", "the_nose")
	await get_tree().create_timer(2.5).timeout
	while world._busy:
		await get_tree().process_frame
	check(world.region.region_id == "el_capitan_meadow" and world.player.position == world.region.get_spawn("the_nose").position,
		"go_to_region lands on a named spot")

	# Tuolumne needs both an unlock and an open Tioga Road.
	check(not Park.best_leg("yosemite_valley", "tuolumne_meadows").open, "Tuolumne stays locked until the high-country unlock")
	Park.unlock_hub("tuolumne_meadows")
	var to_tuolumne := Park.best_leg("yosemite_valley", "tuolumne_meadows")
	check(to_tuolumne.open, "Tioga Road is open in summer")

	# It's too late for a long drive near midnight (arrival after 1 AM).
	GameClock.minutes = 23 * 60 + 40
	await world.travel(to_tuolumne)
	check(world.region.region_id == "el_capitan_meadow", "no 90-minute drive at 11:40 PM")
	GameClock.minutes = 9 * 60

	# Northside Drive west comes to a fork in the road. Turn right and Big Oak
	# Flat Road climbs to Crane Flat, where the Tioga Road drives on to
	# Tuolumne; straight on is El Portal. The way you turn is the choice: no map.
	var west: RegionExit = world.region.get_node("Exits/NorthsideDriveWest")
	await world.go_to_region(west.target_region, west.target_spawn)
	check(world.region.region_id == "big_oak_flat_junction", "Northside Drive west comes to the Big Oak Flat Road junction")
	var clock := GameClock.minutes
	world.use_exit(world.region.get_node("Exits/BigOakFlatRoad"))
	await _settle(world)
	check(world.region.region_id == "crane_flat" and GameClock.minutes == clock + 20,
		"turning right up Big Oak Flat Road drives to Crane Flat (%d min)" % (GameClock.minutes - clock))
	GameClock.season = GameClock.Season.WINTER
	world.use_exit(world.region.get_node("Exits/TiogaRoad"))
	await _settle(world)
	check(world.region.region_id == "crane_flat" and not world.park_map.visible, "the Tioga Road is shut at Crane Flat in winter")
	GameClock.season = GameClock.Season.SUMMER
	clock = GameClock.minutes
	world.use_exit(world.region.get_node("Exits/TiogaRoad"))
	await _settle(world)
	check(world.region.region_id == "tuolumne_meadows" and GameClock.minutes == clock + 70,
		"the Tioga Road drives on from Crane Flat to Tuolumne Meadows (%d min)" % (GameClock.minutes - clock))
	await world.go_to_region("big_oak_flat_junction", "east")
	clock = GameClock.minutes
	world.use_exit(world.region.get_node("Exits/ElPortalRoad"))
	await _settle(world)
	check(world.region.region_id == "el_portal" and not world.park_map.visible and GameClock.minutes == clock + 15,
		"straight on at the junction drives to El Portal (%d min)" % (GameClock.minutes - clock))

	# Road exits out of a hub open the travel map with the right destination picked.
	var exit: RegionExit = world.region.get_node("Exits/ElPortalRoad")
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

	await _check_spawns_are_free(world)
	await _check_unstick(world)
	await _check_wake_up(world)
	await _check_controls(world)
	await _check_menus(world)
	await _check_central_hub(world)
	await _check_getting_around(world)
	_check_valley_links()
	await _check_curfew(world)

	# Winter closes both seasonal roads.
	GameClock.season = GameClock.Season.WINTER
	legs = _legs_by_destination("yosemite_valley")
	check(not legs.glacier_point.open and not legs.tuolumne_meadows.open and legs.wawona.open, "winter closes Tioga and Glacier Point roads only")

	world.free()
	SaveManager.delete_save()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


## Every place a door, road, shuttle, or climb drops the player has room to
## stand and walk. (El Portal's arrival spot used to be inside a tree.)
func _check_spawns_are_free(world: Node) -> void:
	var targets := {}
	targets["%s/%s" % [Park.HOME_REGION, Park.HOME_SPAWN]] = [Park.HOME_REGION, Park.HOME_SPAWN]
	for hub in ParkAtlas.HUBS:
		for leg in Park.legs_from(hub.id):
			var to := Park.get_hub(leg.to)
			var region_id: String = to.arrival_region if to.arrival_region != "" else leg.to
			targets["%s/%s" % [region_id, leg.spawn]] = [region_id, leg.spawn]
	for stop: Dictionary in ShuttleStop.STOPS:
		targets["%s/%s" % [stop.region, stop.spawn]] = [stop.region, stop.spawn]
	for route in Guidebook.routes():
		if route.destination() != "":
			targets["%s/%s" % [route.destination(), route.destination_spawn]] = [route.destination(), route.destination_spawn]
	for file in DirAccess.get_files_at("res://scenes/regions"):
		if not file.ends_with(".tscn"):
			continue
		var scene: Region = load("res://scenes/regions/" + file).instantiate()
		add_child(scene)
		for node in scene.find_children("*", "", true, false):
			if (node is RegionDoor or node is RegionExit) and node.target_region != "":
				var spawn: String = node.target_spawn if node.target_spawn != "" else "arrival"
				targets["%s/%s" % [node.target_region, spawn]] = [node.target_region, spawn]
		scene.free()
	var stuck := PackedStringArray()
	for key: String in targets:
		var target: Array = targets[key]
		world._enter_region(target[0], target[1])
		for i in 3:
			await get_tree().physics_frame
		var marker: Marker2D = world.region.get_spawn(target[1])
		if marker == null or world.player.test_move(Transform2D(0.0, marker.global_position), Vector2.ZERO):
			stuck.append(key)
	check(targets.size() > 20, "checked %d arrival spots" % targets.size())
	check(stuck.is_empty(), "no arrival spot is inside a tree or wall (%s)" % ", ".join(stuck))
	world._enter_region(Park.HOME_REGION, Park.HOME_SPAWN)


## The safety net: a player dropped somewhere solid is moved to the nearest open ground.
func _check_unstick(world: Node) -> void:
	var player: Player = world.player
	world._enter_region("el_portal", "arrival")
	for i in 3:
		await get_tree().physics_frame
	# Find something solid near the arrival (a tree or a building) to drop the player in.
	var origin := player.global_position
	var solid := Vector2.INF
	for r in range(32, 640, 16):
		for i in 16:
			var p := origin + Vector2.from_angle(i * TAU / 32.0) * r
			if player.test_move(Transform2D(0.0, p), Vector2.ZERO):
				solid = p
				break
		if solid != Vector2.INF:
			break
	check(solid != Vector2.INF, "found a solid spot near the El Portal arrival")
	player.global_position = solid
	await world._unstick_player()
	check(not player.test_move(player.global_transform, Vector2.ZERO) and player.global_position.distance_to(solid) <= 192.0,
		"a player dropped in a tree is moved to open ground (%s)" % player.global_position)
	world._enter_region(Park.HOME_REGION, Park.HOME_SPAWN)


## Waking up: the night's spoiled food is mentioned in the morning message,
## and the player faces down with the interaction area to match.
func _check_wake_up(world: Node) -> void:
	var player: Player = world.player
	Inventory.add("wild_strawberry", 1)
	Larder.batches["wild_strawberry"] = [1]
	player.facing = Vector2i.LEFT
	player.interaction_area.position = Vector2(-24, 0)
	await world.sleep()
	var message: String = world.hud.message_label.text
	check("Good morning" in message and "Spoiled overnight" in message,
		"the morning message keeps the spoiled-food note (%s)" % message.replace("\n", " / "))
	check(player.facing == Vector2i.DOWN and player.interaction_area.position == Vector2(0, 24), "after waking the interaction area faces down")


## Esc closes a sign before it opens the pause menu, button hints follow the
## device in use, and the journal scrolls with the keys or the stick.
func _check_menus(world: Node) -> void:
	var pause: PauseMenu = world.get_tree().get_first_node_in_group("pause_menu")
	world.hud.show_info("Sign", "Some words.")
	_press("pause")
	check(not world.hud.info_panel.visible and not pause.is_open() and world.player.can_act, "Esc with a sign open closes the sign, not the pause menu")
	_press("pause")
	check(pause.is_open(), "Esc with no sign opens the pause menu")
	_press("ui_cancel")

	world.hud._input(InputEventKey.new())
	check(world.hud._status.text.contains("[J] Journal"), "the hint line names the journal key (%s)" % world.hud._status.text)
	world.open_travel_map()
	check("[Arrows] Choose   [E] Travel   [Esc] Close" in world.park_map._hint_label.text, "the travel map shows keyboard prompts")
	world.hud._input(InputEventJoypadButton.new())
	check("[D-pad] Choose   [A] Travel   [B] Close" in world.park_map._hint_label.text, "the open map switches to gamepad prompts")
	check(world.hud._status.text.contains("[Y] Journal") and not world.hud._status.text.contains("[J] Journal"), "the hint line switches to the gamepad's Y")
	world.park_map.close()
	world.open_shuttle_map("Happy Isles")
	check("[A] Ride" in world.park_map._area_hint.text, "the shuttle map shows gamepad prompts (%s)" % world.park_map._area_hint.text)
	world.park_map.close()
	world.hud._input(InputEventKey.new())
	check(world.hud._status.text.contains("[J] Journal"), "keyboard prompts come back with the keyboard")

	var journal: Journal = world.get_tree().get_first_node_in_group("journal")
	journal.open()
	for i in 30:
		journal._line("Filler line %d" % i)
	for i in 3:
		await get_tree().process_frame
	check(journal._body.size.y > journal._scroll.size.y, "the journal can be taller than its page")
	_press("move_down")
	check(journal._scroll.scroll_vertical == Journal.SCROLL_STEP, "Down scrolls the journal (%d)" % journal._scroll.scroll_vertical)
	_press("ui_page_down")
	check(journal._scroll.scroll_vertical > Journal.SCROLL_STEP * 3, "Page Down scrolls a page (%d)" % journal._scroll.scroll_vertical)
	_press("move_up")
	var scrolled := journal._scroll.scroll_vertical
	_press("ui_up")
	check(journal._scroll.scroll_vertical == scrolled - Journal.SCROLL_STEP, "Up scrolls back")
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_Y
	stick.axis_value = 1.0
	scrolled = journal._scroll.scroll_vertical
	Input.parse_input_event(stick)
	Input.flush_buffered_events()
	await get_tree().process_frame
	check(journal._scroll.scroll_vertical == scrolled + Journal.SCROLL_STEP, "pushing the stick down scrolls the journal one step")
	stick.axis_value = 0.0
	Input.parse_input_event(stick)
	Input.flush_buffered_events()
	await get_tree().process_frame
	journal.close()
	world.hud._input(InputEventKey.new()) # the stick switched the prompts to the gamepad
	check(world.player.can_act and not journal.is_open(), "the journal closes after scrolling")


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
	await _check_book(world, journal, player)
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


## Q and B open the book on Quests and the Backpack, the keys and Tab move
## between its tabs, and the arrows move over the Backpack's slots.
func _check_book(world: Node, journal: Journal, player: Player) -> void:
	for action in ["quests", "backpack"]:
		check(InputMap.has_action(action) and InputMap.action_get_events(action).any(func(e: InputEvent) -> bool: return e is InputEventKey), "%s has a key" % action)
	_press("quests")
	check(journal.is_open() and journal.tab() == Journal.Tab.QUESTS and not player.can_act and GameClock.paused, "Q opens the book on Quests")
	check(journal._body.get_child(0).text == "Main story" and journal._footer.text.contains("[Q/Esc] Close"), "Quests starts with the main story (%s)" % journal._footer.text)
	check(not journal._detail.visible, "only the Backpack shows the detail lines")
	_press("backpack")
	check(journal.is_open() and journal.tab() == Journal.Tab.BACKPACK, "B turns to the Backpack without closing")
	_press("ui_focus_next")
	check(journal.tab() == Journal.Tab.JOURNAL, "Tab goes round to the Journal")
	_press("ui_focus_prev")
	check(journal.tab() == Journal.Tab.BACKPACK, "Shift+Tab goes back")
	var bumper := InputEventJoypadButton.new()
	bumper.button_index = JOY_BUTTON_LEFT_SHOULDER
	bumper.pressed = true
	Input.parse_input_event(bumper)
	Input.flush_buffered_events()
	check(journal.tab() == Journal.Tab.PRESS, "LB turns back a tab")
	world.hud._input(InputEventKey.new()) # the bumper switched the prompts to the gamepad
	_press("ui_cancel")
	check(not journal.is_open() and player.can_act and not GameClock.paused, "Esc closes the book from any tab")

	var before := Inventory.items.duplicate()
	Inventory.items = {"acorn_cake": 3, "trail_mix": 1, "black_oak_acorn": 12, "sequoia_cone": 1}
	Inventory.changed.emit()
	_press("backpack")
	for i in 3:
		await get_tree().process_frame
	var names := journal._slot_items.map(func(slot: Dictionary) -> String: return slot.name)
	check(names.slice(-4) == ["Acorn Cake", "Trail Mix", "Black Oak Acorn", "Giant Sequoia Cone"], "the Backpack sorts food from forage (%s)" % [names])
	var gear := names.size() - 4
	check(gear > 0 and journal._cursor == 0 and journal._detail.visible and journal._detail_name.text.begins_with(names[0]), "the cursor starts on the first piece of gear (%s)" % journal._detail_name.text)
	check(get_viewport().get_visible_rect().encloses(journal._panel.get_global_rect()), "the Backpack fits on screen (%s)" % journal._panel.get_global_rect())
	_press("move_down")
	check(journal._cursor == gear, "Down goes to the row of food (%d)" % journal._cursor)
	check(journal._detail_name.text == "Acorn Cake x3   (45 energy each, keeps %d days)" % Larder.days_left("acorn_cake"), "the detail line names the food and what it's worth (%s)" % journal._detail_name.text)
	check(journal._detail_text.text == ItemDB.get_item("acorn_cake").description, "and describes it")
	_press("move_right")
	check(journal._cursor == gear + 1, "Right goes along the row")
	_press("move_down")
	_press("move_left")
	check(journal._cursor == gear + 2 and journal._detail_name.text.contains("not ready to eat"), "raw acorns say they aren't ready to eat (%s)" % journal._detail_name.text)
	_press("move_down")
	check(journal._cursor == gear + 2, "Down stops on the last row")
	_press("move_up")
	_press("move_up")
	check(journal._cursor < gear, "Up goes back to the gear")
	_press("backpack")
	check(not journal.is_open() and player.can_act, "B closes the Backpack")
	Inventory.items = before
	Inventory.changed.emit()


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
	var start := Vector2i(region.get_spawn("arrival").position / 32.0)
	var reached := _flood(open, start)
	var unreachable := PackedStringArray()
	for marker in region.get_node("Markers").get_children():
		if not reached.has(Vector2i((marker as Node2D).position / 32.0)):
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
	world.player.interaction_area.position = Vector2(0, -24)
	for i in 4:
		await get_tree().physics_frame
	# process_frame fires before nodes' _process, so wait two: the second comes
	# after the HUD has updated its prompt for the new overlap, even when a slow
	# frame ran all four physics steps at once.
	await get_tree().process_frame
	await get_tree().process_frame
	check(world.hud.prompt_panel.visible and world.hud.prompt_label.text == "[E] Read: Camp 4", "facing a sign shows its prompt (%s)" % world.hud.prompt_label.text)
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
	check(rack.available_offers().size() == 2, "with a starter rack the trader offers cams and draws (the belay device comes from Royal Robbins)")
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
	check(world.region.region_id == "happy_isles" and world.player.position == world.region.get_spawn("shuttle").position,
		"the shuttle drops you at Happy Isles")
	check(GameClock.minutes - before == ShuttleStop.RIDE_MINUTES, "the shuttle ride takes %d minutes" % ShuttleStop.RIDE_MINUTES)
	for dest: Dictionary in ShuttleStop.STOPS:
		var scene: PackedScene = load(world.region_scene_path(dest.region))
		var probe: Region = scene.instantiate()
		add_child(probe)
		check(probe.get_spawn(dest.spawn) != null, "shuttle stop %s has a spot to land on" % dest.name)
		probe.free()


## Holding the run button covers ground faster, and the Ahwahnee is joined to
## the rest of the Valley both ways: a trailhead sign on the Valley map leads
## in, and the shuttle stops at its entrance circle.
func _check_getting_around(world: Node) -> void:
	var player: Player = world.player
	world._enter_region("the_ahwahnee", "entrance_circle")
	var walked := await _distance_moved(player, "move_down", false)
	player.position = world.region.get_spawn("entrance_circle").position
	var ran := await _distance_moved(player, "move_down", true)
	check(walked > 4.0 and is_equal_approx(ran / walked, Player.RUN_BOOST), "holding run is %.2fx walking (%.1f px to %.1f px)" % [Player.RUN_BOOST, walked, ran])
	var joypad := InputMap.action_get_events("run").any(func(e: InputEvent) -> bool: return e is InputEventJoypadButton or e is InputEventJoypadMotion)
	var keyboard := InputMap.action_get_events("run").any(func(e: InputEvent) -> bool: return e is InputEventKey)
	check(joypad and keyboard, "run works on keyboard and gamepad")

	var stop: ShuttleStop = world.region.find_child("ShuttleAhwahnee", true, false)
	check(stop != null and await _can_use(player, stop), "the Ahwahnee has a shuttle stop you can walk up to")
	check(stop != null and stop.destinations().size() == ShuttleStop.STOPS.size() - 1, "it rides to every other stop")

	# Out by Northside Drive across Ahwahnee Meadow, and back up the road.
	var road: RegionExit = world.region.find_child("NorthsideDriveWest", true, false)
	await world.go_to_region(road.target_region, road.target_spawn)
	check(world.region.region_id == "ahwahnee_meadow", "the road west crosses Ahwahnee Meadow")
	var back: RegionExit = world.region.find_child("ToAhwahnee", true, false)
	check(back != null and back.position.distance_to(world.region.get_spawn(road.target_spawn).position) < 128.0,
		"the way back into the Ahwahnee is beside where its road comes out")
	player.position = back.position
	await get_tree().create_timer(2.5).timeout
	check(world.region.region_id == "the_ahwahnee" and not player.test_move(player.global_transform, Vector2.ZERO),
		"walking back up the road leads into the Ahwahnee grounds")
	world._enter_region(Park.HOME_REGION, Park.HOME_SPAWN)


## Roads with no way back. El Capitan Bridge is crossed north to south only.
const ONE_WAY_ROADS := ["el_capitan_meadow -> bridalveil_fall/el_cap_bridge"]


## Each place in the Valley is one scene, joined to its neighbors by roads
## and trails. Every road between two Valley scenes lands on a spot that
## exists, and a road straight back starts right beside it (so turning round
## takes you back where you came from, never somewhere else), except the
## ONE_WAY_ROADS.
func _check_valley_links() -> void:
	var scenes := {}
	for file in DirAccess.get_files_at("res://scenes/regions"):
		if file.ends_with(".tscn"):
			var region: Region = load("res://scenes/regions/" + file).instantiate()
			if region.hub_id == "yosemite_valley" and not region.indoors:
				scenes[region.region_id] = region
			else:
				region.free()
	check(not scenes.has("yosemite_valley"), "there is no big Valley map: each place is its own scene")
	var broken := PackedStringArray()
	var count := 0
	for id: String in scenes:
		for exit in (scenes[id] as Region).find_children("*", "RegionExit", true, false):
			if not scenes.has(exit.target_region):
				continue
			count += 1
			var there: Region = scenes[exit.target_region]
			var spot := there.get_spawn(exit.target_spawn)
			if spot == null:
				broken.append("%s -> %s/%s (no spot)" % [id, exit.target_region, exit.target_spawn])
				continue
			var back := there.find_children("*", "RegionExit", true, false).filter(func(e: RegionExit) -> bool:
				return e.target_region == id and e.position.distance_to(spot.position) < 200.0)
			if back.is_empty() and not ONE_WAY_ROADS.has("%s -> %s/%s" % [id, exit.target_region, exit.target_spawn]):
				broken.append("%s -> %s/%s (no way back)" % [id, exit.target_region, exit.target_spawn])
	# Every trail up to Glacier Point (the Ledge Trail, the Four Mile Trail,
	# the Mist Trail) waits for the Apron climb that opens the rim, and the
	# hiking trails shut for snow in winter as the road does.
	var trails_up := PackedStringArray()
	var unguarded := PackedStringArray()
	for id: String in scenes:
		for door in (scenes[id] as Region).find_children("*", "RegionDoor", true, false):
			if door.target_region != "glacier_point":
				continue
			trails_up.append(door.name)
			if door.needs_hub != "glacier_point" or door.locked_text == "":
				unguarded.append("%s/%s (no lock)" % [id, door.name])
			elif door.name != "LedgeTrail" and not Park.SEASONAL.has(door.closure):
				unguarded.append("%s/%s (no winter closure)" % [id, door.name])
	check(trails_up.size() >= 3 and unguarded.is_empty(), "the trails up to Glacier Point (%s) open with the rim (%s)"
		% [", ".join(trails_up), ", ".join(unguarded)])
	for region: Region in scenes.values():
		region.free()
	check(count >= 30 and broken.is_empty(), "%d roads between Valley scenes all lead back the way they came (%s)" % [count, ", ".join(broken)])


## Waits out a drive or a walk to the next region.
func _settle(world: Node) -> void:
	await get_tree().process_frame
	while world._busy:
		await get_tree().process_frame


## How far the player gets in a few physics frames of holding [param action].
func _distance_moved(player: Player, action: String, run: bool) -> float:
	await get_tree().physics_frame
	var from := player.position
	Input.action_press(action)
	if run:
		Input.action_press("run")
	for i in 3:
		await get_tree().physics_frame
	Input.action_release(action)
	Input.action_release("run")
	await get_tree().physics_frame
	return player.position.distance_to(from)


## Standing just south of [param target] and facing it, is it what the
## interact button would use?
func _can_use(player: Player, target: Node2D) -> bool:
	player.global_position = target.global_position + Vector2(0, 8)
	player.facing = Vector2i.UP
	player.interaction_area.position = Vector2(0, -24)
	for i in 3:
		await get_tree().physics_frame
	return not player.test_move(player.global_transform, Vector2.ZERO) and player.get_target() == target


## The pass-out hour arriving mid-ride or mid-conversation isn't lost: the
## player passes out as soon as the ride ends or the box closes. Late rides
## aren't offered.
func _check_curfew(world: Node) -> void:
	while world._busy:
		await get_tree().process_frame
	await world.go_to_region("yosemite_village", "arrival")
	var stop: ShuttleStop = world.region.find_child("ShuttleVillage", true, false)
	GameClock.minutes = 25 * 60 + 10
	stop.interact(world.player)
	check(not world.park_map.visible and world.player.can_act, "the shuttle doesn't run after 1 AM")
	GameClock.minutes = 12 * 60
	stop.interact(world.player)
	check(world.park_map.visible, "the shuttle runs by day")
	world.park_map.close()

	# A ride that ends at 2 AM.
	var day := GameClock.day
	GameClock.minutes = 25 * 60 + 50
	await world.go_to_region("happy_isles", "shuttle", ShuttleStop.RIDE_MINUTES)
	await get_tree().create_timer(4.0).timeout
	check(GameClock.day == day + 1 and world.region.region_id == Park.HOME_REGION and world.player.can_act and not world._busy,
		"a ride that ends at 2 AM still passes the player out (day %d, %s)" % [GameClock.day, world.region.region_id])

	# The pass-out waits for an open conversation to end.
	await world.go_to_region("yosemite_village", "arrival")
	day = GameClock.day
	DialogueBox.say_to(world.player, [{"speaker": "Test", "text": "Hello."}])
	GameClock.minutes = 25 * 60 + 50
	GameClock.advance_minutes(10)
	await get_tree().create_timer(2.0).timeout
	check(GameClock.day == day and world.region.region_id == "yosemite_village" and not world.player.can_act, "the pass-out waits while a dialogue box is open")
	var box: DialogueBox = world.get_tree().get_first_node_in_group("dialogue_box")
	check(box != null and not box.is_queued_for_deletion(), "the dialogue box is still on screen at 2 AM")
	box.press()
	await get_tree().create_timer(4.0).timeout
	check(GameClock.day == day + 1 and world.region.region_id == Park.HOME_REGION and world.player.can_act, "the player passes out once the box closes")
	check(world.get_tree().get_nodes_in_group("dialogue_box").all(func(b: Node) -> bool: return b.is_queued_for_deletion()), "no dialogue box is left open")


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
			for y in range(floori(rect.position.y / 32.0), floori(rect.end.y / 32.0) + 1):
				for x in range(floori(rect.position.x / 32.0), floori(rect.end.x / 32.0) + 1):
					if rect.grow(-minf(6.0, minf(rect.size.x, rect.size.y) / 3.0)).intersects(Rect2(x * 32, y * 32, 32, 32)):
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
		# A generated hub keeps its terrain in Map; a hand-built one (Glacier
		# Point) has it at the top, with its spawns in Markers.
		var blocker: TileMapLayer = region.get_node("Map/Blocker") if region.map else region.get_node("Blocker")
		var ground := region.get_ground()
		check(ground.get_used_rect().size.x > 100, "%s map loads (%s tiles)" % [hub.id, ground.get_used_rect().size])
		var spawns := region.get_node("Map/Spawns" if region.map else "Markers").get_children()
		var blocked := spawns.filter(func(m: Node2D) -> bool: return blocker.get_cell_source_id(blocker.local_to_map(m.position)) != -1)
		check(region.get_spawn("arrival") != null and blocked.is_empty(), "%s spawn points are walkable (%d spawns)" % [hub.id, spawns.size()])
		check(region.find_children("*", "TravelPoint", true, false).size() > 0, "%s has a map kiosk" % hub.id)
		check(region.get_places().size() >= 5, "%s has named places" % hub.id)
		region.free()
