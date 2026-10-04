extends Node
## Saves screenshots of a region as the player would see it. Needs a window
## (not --headless). Environment:
##   SHOT_REGION  region id, e.g. curry_village
##   SHOT_SPAWNS  comma-separated spawn names to visit, or "name@x,y" tile spots
##   SHOT_DIR     folder for the PNGs (default user://)
##   SHOT_SCALE   integer upscale for the saved PNG (default 2)
##   SHOT_HOUR    game hour to shoot at (default 12)
##   SHOT_SEASON  0 spring, 1 summer, 2 fall, 3 winter (default 1)
## Run: SHOT_REGION=curry_village SHOT_SPAWNS=arrival godot --path . res://tools/shots/region_shot.tscn


func _ready() -> void:
	SaveManager.save_path = "user://region_shot_save.json"
	SaveManager.delete_save()
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	GameClock.minutes = (int(OS.get_environment("SHOT_HOUR")) if OS.get_environment("SHOT_HOUR") != "" else 12) * 60
	GameClock.season = int(OS.get_environment("SHOT_SEASON")) if OS.get_environment("SHOT_SEASON") != "" else 1
	GameClock.paused = true
	var dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://"
	var scale := int(OS.get_environment("SHOT_SCALE")) if OS.get_environment("SHOT_SCALE") != "" else 2
	var region_id := OS.get_environment("SHOT_REGION")
	for spot in OS.get_environment("SHOT_SPAWNS").split(","):
		if spot == "":
			continue
		var at := spot.split("@")
		await world.go_to_region(region_id, at[0])
		if at.size() > 1:
			var xy := at[1].split(":")
			world.player.global_position = Vector2(float(xy[0]), float(xy[1])) * 16.0
			world.player.get_node("Camera").reset_smoothing()
		world.hud.visible = false
		GameClock.paused = true
		for i in 12:
			await get_tree().process_frame
		var image := get_viewport().get_texture().get_image()
		if scale > 1:
			image.resize(image.get_width() * scale, image.get_height() * scale, Image.INTERPOLATE_NEAREST)
		image.save_png("%s/%s_%s.png" % [dir, region_id, spot.replace("@", "_").replace(":", "_")])
	get_tree().quit()
