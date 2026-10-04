extends Node
## Plays through the core loop headlessly and checks the results: walking,
## seasonal forage in the right habitats, picking it up, saving and loading,
## and the day ending at the curfew.
## Run: godot --headless --path . res://tests/smoke_test.tscn
## Exit code is the number of failed checks.

var failures := 0

func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1

func _ready() -> void:
	SaveManager.save_path = "user://smoke_test_save.json"
	SaveManager.delete_save()
	Engine.time_scale = 20.0
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var player: Player = world.player
	check(player.global_position == world.region.get_spawn(Park.HOME_SPAWN).global_position, "player at spawn")
	check(Inventory.items.is_empty(), "a new game starts with an empty pack")
	check(world.region.get_ground().get_used_rect().size == Vector2i(40, 30), "map is 40x30")
	check(world.region.get_node_or_null("Farm") == null and world.region.find_child("ShippingCrate", true, false) == null, "no farm or shipping crate")

	# Walk: press right for a moment
	var start := player.global_position
	Input.action_press("move_right")
	for i in 10: await get_tree().physics_frame
	Input.action_release("move_right")
	check(player.global_position.x > start.x and player.facing == Vector2i.RIGHT, "player walks right and faces right")

	# Yosemite forage: right season, right habitat
	var forage: ForageSpawner = world.forage
	GameClock.season = GameClock.Season.SPRING
	await forage.respawn()
	var spring_ids := _forage_ids(world)
	check(spring_ids == ["miners_lettuce", "miners_lettuce", "miners_lettuce", "morel_mushroom", "sierra_onion", "sierra_onion",
			"wild_strawberry", "wild_strawberry", "yerba_buena", "yerba_buena"], "spring forage (%s)" % [spring_ids])
	for f: Forageable in forage.get_children():
		match f.item.id:
			"yerba_buena":
				check(forage._touches_tile(f.cell, ForageSpawner.WATER_TILE), "yerba buena grows by the river")
			"morel_mushroom", "miners_lettuce":
				check(_near_oak(world, f.cell), "%s grows under a black oak" % f.item.display_name)
	GameClock.season = GameClock.Season.FALL
	await forage.respawn()
	var fall_ids := _forage_ids(world)
	check(fall_ids.count("black_oak_acorn") == 4 and fall_ids.count("toyon_berries") == 2 and fall_ids.count("yampah") == 1,
		"fall forage: acorns, toyon, yampah (%s)" % [fall_ids])
	for f: Forageable in forage.get_children():
		if f.item.id == "black_oak_acorn":
			check(_near_oak(world, f.cell), "acorn lies under a black oak")
		elif f.item.id == "toyon_berries":
			check(forage._touches_tile(f.cell, ForageSpawner.MANZANITA_TILE), "toyon grows in the chaparral")

	# Pick up an acorn
	var acorn: Forageable
	for f: Forageable in forage.get_children():
		if f.item.id == "black_oak_acorn":
			acorn = f
	player.global_position = acorn.global_position + Vector2(0, 14)
	player.facing = Vector2i.UP
	player.interaction_area.position = Vector2(0, -12)
	await get_tree().physics_frame
	await get_tree().physics_frame
	player._interact()
	check(Inventory.count("black_oak_acorn") == 1 and acorn.is_queued_for_deletion(), "acorn picked up")
	check(world.hud.bag_panel.visible and world.hud.bag_list.get_child_count() == 1, "bag panel lists the acorn")
	Inventory.add("acorn_cake", 2)
	check(world.hud.bag_list.get_child_count() == 2, "bag panel lists cooked food too")
	check(world.hud._status.text.begins_with("Food 90 energy"), "status strip shows food energy (%s)" % world.hud._status.text)
	check(world.hud.status_bar.size.x <= 472.0, "status strip fits on screen (%.0f px)" % world.hud.status_bar.size.x)

	# Sleep, then save + reload
	await world.sleep()
	check(GameClock.day == 2, "sleeping starts the next day")
	var saved_day := GameClock.day
	var saved_forage := _forage_ids(world)
	var saved_items := Inventory.items.duplicate()
	world.free()
	GameClock.day = 1
	Inventory.start_new_game()
	world = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(world)
	await get_tree().process_frame
	check(GameClock.day == saved_day and Inventory.items == saved_items, "clock and pack restored from save")
	check(saved_forage.size() > 0 and _forage_ids(world) == saved_forage, "forage restored from save (%s)" % [saved_forage])

	# Saves from the farming days still load, minus the seed packets.
	Inventory.load_data({"money": 35, "items": {"yampah_seeds": 5, "black_oak_acorn": 3}})
	check(Inventory.items == {"black_oak_acorn": 3}, "old seed packets are dropped on load")

	# Curfew
	GameClock.advance_minutes(GameClock.PASS_OUT_HOUR * 60)
	await get_tree().create_timer(3.0).timeout
	check(GameClock.day == saved_day + 1 and GameClock.hour == 6, "passing out at 2 AM starts next day")

	# Season rollover
	GameClock.day = 28
	GameClock.season = GameClock.Season.SPRING
	await world.sleep()
	check(GameClock.season == GameClock.Season.SUMMER and GameClock.day == 1, "season rolls to Summer")
	check(not _forage_ids(world).has("morel_mushroom") and not _forage_ids(world).has("miners_lettuce"), "spring-only forage is gone in Summer")

	SaveManager.delete_save()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func _forage_ids(world: Node) -> Array:
	var ids := []
	for f: Forageable in world.forage.get_children():
		ids.append(f.item.id)
	ids.sort()
	return ids


func _near_oak(world: Node, cell: Vector2i) -> bool:
	for oak: Node2D in get_tree().get_nodes_in_group("black_oak"):
		var offset: Vector2i = cell - world.forage.world_to_cell(oak.global_position)
		if absi(offset.x) <= ForageSpawner.OAK_REACH and offset.y >= 0 and offset.y <= ForageSpawner.OAK_REACH:
			return true
	return false
