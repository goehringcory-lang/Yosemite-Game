extends Node
## Screenshots of the game-feel touches: the "you got this" cards, a
## conversation with a portrait, the clock dial, and the end-of-day summary.
## Needs a window (not --headless):
##   SHOT_DIR=/tmp/shots xvfb-run -a godot --path . res://tools/shots/polish_shot.tscn


func _snap(dir: String, shot_name: String, frames := 8) -> void:
	for i in frames:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	image.resize(image.get_width() * 2, image.get_height() * 2, Image.INTERPOLATE_NEAREST)
	image.save_png("%s/polish_%s.png" % [dir, shot_name])


func _ready() -> void:
	SaveManager.save_path = "user://polish_shot_save.json"
	SaveManager.delete_save()
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	GameClock.minutes = 11 * 60
	GameClock.paused = true
	var dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://"
	await world.go_to_region("curry_village", "arrival")
	for i in 12:
		await get_tree().process_frame
	# The cards: a stack of forage, a cooked dish, and new gear.
	Inventory.add("wild_strawberry")
	Inventory.add("wild_strawberry")
	Inventory.add("miners_lettuce")
	Inventory.add("acorn_cake")
	Gear.add("cam")
	await _snap(dir, "toasts", 20)
	# A conversation with a portrait, and a shop's choices.
	var box := DialogueBox.open(world.player)
	box.say([{"speaker": "Wren Alvarez", "text": "You made it! Heels low, trust the rubber. That's all slab is. Well, that and not looking down. I'll belay first."}])
	box.reveal_all()
	await _snap(dir, "dialogue")
	box.choose("What'll it be? Everything here trades for food.", ["A cam for 40 food energy", "Two quickdraws for 24 food energy", "Nothing, thanks"], "Marty Kessler")
	box.reveal_all()
	await _snap(dir, "dialogue_choice")
	box.close()
	# A shop and the campfire, with pictures of what's on offer.
	var shop_box := DialogueBox.open(world.player)
	shop_box.choose("You're carrying 148 energy of food. What do you want?",
		["Quickdraw x2 for 24 food energy", "Cam for 40 food energy", "Haul bag for 60 food energy", "Done"], "Marty Kessler",
		[Gear.get_gear("quickdraw").icon, Gear.get_gear("cam").icon, Gear.get_gear("haul_bag").icon, null])
	shop_box.reveal_all()
	await _snap(dir, "shop")
	shop_box.close()
	var fire_box := DialogueBox.open(world.player)
	var dishes := ["acorn_mush", "acorn_cake", "elderberry_sauce", "roasted_morels", "yerba_buena_tea", "spring_greens"]
	var names := []
	var pictures := []
	for id in dishes:
		names.append(ItemDB.get_item(id).display_name)
		pictures.append(ItemDB.get_item(id).icon)
	names.append("Leave")
	pictures.append(null)
	fire_box.choose("Campfire. What will you make?", names, "", pictures)
	fire_box.reveal_all()
	await _snap(dir, "campfire")
	fire_box.close()
	var pause := get_tree().get_first_node_in_group("pause_menu")
	pause.open()
	pause._show_page(PauseMenu.Page.SETTINGS)
	await _snap(dir, "settings")
	pause.close()
	# The clock dial through the day, and someone with a quest for you.
	for hour in [7, 13, 19, 23]:
		GameClock.minutes = hour * 60
		GameClock.time_changed.emit(GameClock.hour, GameClock.minute)
		await _snap(dir, "clock_%d" % hour, 4)
	GameClock.minutes = 11 * 60
	GameClock.time_changed.emit(GameClock.hour, GameClock.minute)
	QuestLog.completed.append("clark_register")
	await world.go_to_region("curry_mountain_shop", "arrival")
	await _snap(dir, "marker", 40)
	# Birds and butterflies on a fair spring morning.
	GameClock.minutes = 10 * 60
	await world.go_to_region("curry_village", "arrival")
	await get_tree().create_timer(9.0).timeout
	var critters: Critters = null
	for child in world.get_children():
		if child is Critters:
			critters = child
	print("CRITTERS ", critters.counts())
	await _snap(dir, "critters", 2)
	# walk up to the nearest bird so it takes off
	var nearest := Vector2.INF
	for bird in critters._birds:
		if bird.pos.distance_to(world.player.global_position) < nearest.distance_to(world.player.global_position):
			nearest = bird.pos
	if nearest != Vector2.INF:
		world.player.global_position = nearest + Vector2(20, 0)
		await get_tree().create_timer(0.25).timeout
		await _snap(dir, "critters_flee", 1)
	# The day's page at bedtime.
	world.day_log.clear()
	for id in ["miners_lettuce", "miners_lettuce", "miners_lettuce", "wild_strawberry", "sierra_onion", "black_oak_acorn", "black_oak_acorn", "acorn_cake"]:
		Inventory.add(id)
	Gear.add("quickdraw", 2)
	world.day_log.ticks.append("Firefall Slab")
	world.day_log.quests.append("Partner for the Apron")
	world.day_log.perks.append("Enid's Eye")
	world.day_log.dishes = 2
	var page := DaySummary.open(world, world.day_log)
	await _snap(dir, "day_summary", 90)
	page.press()
	get_tree().quit()
