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
	# SHOT_PIXEL_FONT=1 shoots with the pixel font (Settings > Font).
	if OS.get_environment("SHOT_PIXEL_FONT") == "1":
		Settings.ensure_loaded()
		Settings.pixel_font = true
		Settings.apply_font()
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
	# Ferns swaying as the player brushes through.
	var rustle: Rustle = null
	for child in world.get_children():
		if child is Rustle:
			rustle = child
	if rustle and rustle.plant_count() > 0:
		var fern: Sprite2D = rustle._plants[rustle.plant_count() / 2]
		world.player.global_position = fern.global_position + Vector2(-30, 0)
		await get_tree().create_timer(0.6).timeout
		for other in rustle._plants:
			if other.global_position.distance_to(fern.global_position) < 60.0:
				rustle.brush(other, 1.0)
		await get_tree().create_timer(0.12).timeout
		await _snap(dir, "rustle", 1)
	# Giving Wren a gift: the prompt, the choice, her thanks and the hearts.
	var wren: NPC = null
	for node in get_tree().get_nodes_in_group("persist") + world.region.find_children("*", "NPC", true, false):
		if node is NPC and node.character and node.character.id == "wren_alvarez":
			wren = node
	if wren:
		Inventory.add("trail_mix", 2)
		Inventory.add("wild_strawberry", 3)
		Friendship.add("wren_alvarez", 90)
		world.player.global_position = wren.global_position + Vector2(0, 14)
		world.player.facing = Vector2i.UP
		world.player.interaction_area.position = Vector2(0, -12)
		await get_tree().create_timer(0.8).timeout
		await _snap(dir, "gift_prompt", 2)
		wren.receive_gift(world.player)
		await get_tree().create_timer(0.3).timeout
		await _snap(dir, "gift_choice", 2)
		var gift_box: DialogueBox = get_tree().get_first_node_in_group("dialogue_box")
		gift_box.press(true)
		await get_tree().create_timer(0.35).timeout
		gift_box.reveal_all()
		await _snap(dir, "gift_thanks", 1)
		while is_instance_valid(gift_box) and gift_box.is_inside_tree():
			gift_box.press(true)
			await get_tree().create_timer(0.1).timeout
		Friendship.add("john_muir", 340)
		Friendship.add("galen_clark", 150)
		var book := get_tree().get_first_node_in_group("journal")
		book.open()
		await get_tree().process_frame
		book._scroll.scroll_vertical = 0
		for child in book._body.get_children():
			if child is Label and child.text == "Friends":
				await get_tree().process_frame
				book._scroll.ensure_control_visible(child)
		await _snap(dir, "friends", 4)
		book.close()
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
