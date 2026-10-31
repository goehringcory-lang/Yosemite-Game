extends Node
## Saves the pixel-diamond wipe between places part way through (see
## pixel_wipe.gdshader): the screen a quarter, half and three quarters
## covered. Needs a window:
##   SHOT_DIR=/tmp/shots xvfb-run -a godot --path . res://tools/shots/wipe_shot.tscn


func _ready() -> void:
	SaveManager.save_path = "user://wipe_shot_save.json"
	SaveManager.delete_save()
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	GameClock.minutes = 11 * 60
	GameClock.paused = true
	await world.go_to_region("curry_village", "arrival")
	for i in 30:
		await get_tree().process_frame
	var dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://"
	for cover in [0.25, 0.5, 0.75]:
		world.hud.fade.color.a = cover
		for i in 4:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s/wipe_%d.png" % [dir, int(cover * 100)])
	SaveManager.delete_save()
	get_tree().quit()
