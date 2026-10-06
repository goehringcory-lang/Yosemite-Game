extends Node
## Saves screenshots of the game's screens: the HUD with a message and a sign,
## the journal, the pause menu, a conversation, and the Valley and park maps.
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
	# HUD with a message, the pack and a sign
	world.hud.show_message("You pick up a wild strawberry.")
	world.hud.message_label.modulate.a = 1.0
	world.hud.bag_panel.visible = true
	world.hud.show_info("Staircase Falls", "A seasonal fall that spills down the granite above Curry Village. It runs after the spring melt.")
	await _snap(dir, scale, "hud")
	world.hud.hide_info()
	var journal := get_tree().get_first_node_in_group("journal")
	journal.open()
	await _snap(dir, scale, "journal")
	journal.close()
	var pause := get_tree().get_first_node_in_group("pause_menu")
	pause.open()
	await _snap(dir, scale, "pause")
	pause.close()
	var box := DialogueBox.open(world.player)
	box.say([{"speaker": "Marty Kessler", "text": "Wren is looking for a partner. Take this guidebook, check the grades, and go find her at the foot of Firefall Slab."}])
	await _snap(dir, scale, "dialogue")
	box.close()
	world.open_map()
	await _snap(dir, scale, "map")
	world.park_map.close()
	world.open_travel_map()
	await _snap(dir, scale, "travel_map")
	get_tree().quit()
