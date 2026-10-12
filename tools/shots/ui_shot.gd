extends Node
## Saves screenshots of the game's screens: the HUD with a message and a sign,
## the journal's three tabs, the pause menu and its Settings and Controls pages, a
## conversation (and a choice), and the Valley and park maps.
## Needs a window (not --headless). Environment:
##   SHOT_DIR    folder for the PNGs (default user://)
##   SHOT_SCALE  integer upscale (default 2)
##   SHOT_REGION region to stand in (default curry_village)
## Run: SHOT_DIR=/tmp/shots godot --path . res://tools/shots/ui_shot.tscn


func _snap(dir: String, scale: int, shot_name: String) -> void:
	for i in 8:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	if scale > 1:
		image.resize(image.get_width() * scale, image.get_height() * scale, Image.INTERPOLATE_NEAREST)
	image.save_png("%s/ui_%s.png" % [dir, shot_name])


func _ready() -> void:
	SaveManager.save_path = "user://ui_shot_save.json"
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
	var scale := int(OS.get_environment("SHOT_SCALE")) if OS.get_environment("SHOT_SCALE") != "" else 2
	var region_id := OS.get_environment("SHOT_REGION") if OS.get_environment("SHOT_REGION") != "" else "curry_village"
	await world.go_to_region(region_id, "arrival")
	for i in 12:
		await get_tree().process_frame
	# HUD with a message and a sign
	world.hud.show_message("You pick up a wild strawberry.")
	world.hud.message_label.modulate.a = 1.0
	world.hud.show_info("Staircase Falls", "A seasonal fall that spills down the granite above Curry Village. It runs after the spring melt.")
	await _snap(dir, scale, "hud")
	world.hud.hide_info()
	var journal := get_tree().get_first_node_in_group("journal")
	journal.open()
	await _snap(dir, scale, "journal")
	journal.show_tab(Journal.Tab.QUESTS)
	await _snap(dir, scale, "quests")
	for id in ["acorn_cake", "acorn_cake", "leached_acorn_meal", "elderberry_sauce", "trail_mix", "wild_strawberry", "black_oak_acorn", "black_oak_acorn", "sequoia_cone"]:
		Inventory.add(id)
	for id in ["climbing_shoes", "chalk_bag", "harness", "rope", "cam", "cam", "cam", "quickdraw", "quickdraw"]:
		Gear.add(id)
	journal.show_tab(Journal.Tab.BACKPACK)
	await get_tree().process_frame
	journal.move_cursor(Vector2i.DOWN)
	await _snap(dir, scale, "backpack")
	journal.close()
	var pause := get_tree().get_first_node_in_group("pause_menu")
	pause.open()
	await _snap(dir, scale, "pause")
	pause._show_page(PauseMenu.Page.SETTINGS)
	await _snap(dir, scale, "pause_settings")
	pause._show_page(PauseMenu.Page.CONTROLS)
	await _snap(dir, scale, "pause_controls")
	pause.close()
	var box := DialogueBox.open(world.player)
	box.say([{"speaker": "Marty Kessler", "text": "Wren is looking for a partner. Take this guidebook, check the grades, and go find her at the foot of Firefall Slab."}])
	box.reveal_all()
	await _snap(dir, scale, "dialogue")
	box.choose("What do you want?", ["Trail Mix · 12 energy", "Dried Apples · 8 energy", "Nothing, thanks"], "Village Store clerk",
		[ItemDB.get_item("trail_mix").icon, ItemDB.get_item("dried_apples").icon, null])
	box.reveal_all()
	await _snap(dir, scale, "dialogue_choice")
	box.close()
	world.open_map()
	await _snap(dir, scale, "map")
	world.park_map.close()
	world.open_travel_map()
	await _snap(dir, scale, "travel_map")
	get_tree().quit()
