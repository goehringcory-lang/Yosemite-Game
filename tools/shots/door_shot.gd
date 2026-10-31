extends Node
## Pictures going in through a door, a few frames apart, to check the
## place left behind opens away from the player with no dark screen.
## Env: SHOT_DIR, SHOT_REGION (default yosemite_village), SHOT_DOOR (a
## BuildingDoor's name; default the first). Needs a window.

func _ready() -> void:
	var dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://"
	var region_id := OS.get_environment("SHOT_REGION") if OS.get_environment("SHOT_REGION") != "" else "yosemite_village"
	SaveManager.save_path = "user://door_shot_save.json"
	SaveManager.delete_save()
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await world.go_to_region(region_id, "arrival")
	var doors: Array = world.region.find_children("*", "BuildingDoor", true, false)
	var door: BuildingDoor = doors[0]
	if OS.get_environment("SHOT_DOOR") != "":
		door = world.region.find_child(OS.get_environment("SHOT_DOOR"), true, false)
	GameClock.advance_minutes((12 - GameClock.hour) * 60)
	world.player.global_position = door.global_position + Vector2(0, 28)
	world.player.get_node("Camera").reset_smoothing()
	for i in 30:
		await get_tree().process_frame
	await _save(dir, "door_0_outside")
	door.interact(world.player)
	for i in 30:
		await get_tree().process_frame
		if i in [1, 3, 6, 10, 16, 29]:
			await _save(dir, "door_%02d" % (i + 1))
	print("wrote door shots of %s into %s" % [door.label, world.region.region_id])
	get_tree().quit()


func _save(dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
