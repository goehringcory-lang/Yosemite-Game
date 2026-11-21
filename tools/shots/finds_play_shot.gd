extends Node
## Screenshots of a hidden find in play (Finds): standing beside the booty cam
## at El Capitan's foot, the card when you take it, and the Logbook's Hidden
## finds section with a rumor. Needs a window. SHOT_DIR, SHOT_SCALE as for
## logbook_shot.
## Run: SHOT_DIR=/tmp/shots xvfb-run -a godot --path . res://tools/shots/finds_play_shot.tscn


func _snap(dir: String, scale: int, shot_name: String) -> void:
	for i in 10:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	if scale > 1:
		image.resize(image.get_width() * scale, image.get_height() * scale, Image.INTERPOLATE_NEAREST)
	image.save_png("%s/finds_%s.png" % [dir, shot_name])


func _ready() -> void:
	SaveManager.save_path = "user://finds_shot_save.json"
	SaveManager.delete_save()
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	GameClock.minutes = 16 * 60
	GameClock.season = GameClock.Season.SUMMER
	GameClock.paused = true
	var dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://"
	var scale := int(OS.get_environment("SHOT_SCALE")) if OS.get_environment("SHOT_SCALE") != "" else 2
	await world.go_to_region("el_capitan_meadow", "arrival")
	for i in 20:
		await get_tree().process_frame
	var find := Finds.get_find("el_cap_booty_cam")
	var player: Player = world.player
	player.position = Vector2(find.pos[0] + 28, find.pos[1] + 4)
	player.facing = Vector2i.LEFT
	for i in 40:
		await get_tree().physics_frame
	Achievements.pending_toasts().clear()
	world.hud.message_label.modulate.a = 0.0
	await _snap(dir, scale, "near")
	var spot := world.region.entities.get_node("Find_el_cap_booty_cam") as FindSpot
	spot.interact(player)
	await _snap(dir, scale, "card")
	world.hud.hide_info()
	for id in ["yosemite_village/Yosemite Village", "half_dome/Half Dome", "mirror_lake/Mirror Lake"]:
		Discoveries.found[id] = true
	Achievements.pending_toasts().clear()
	var journal: Journal = get_tree().get_first_node_in_group("journal")
	journal.open(Journal.Tab.LOGBOOK)
	for i in 10:
		await get_tree().process_frame
	journal.scroll_by(OS.get_environment("SHOT_SCROLL").to_int() if OS.get_environment("SHOT_SCROLL") != "" else 560)
	await _snap(dir, scale, "logbook")
	get_tree().quit()
