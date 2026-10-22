extends Node
## Photographs Crow's Camp: Crow by his fire, then the screen partway through
## his little piece of paper (TripEffect.play) and in the haze after the
## joint. Needs a window (not --headless).
## Run: SHOT_DIR=/tmp/shots godot --path . res://tools/shots/crow_shot.tscn


func _ready() -> void:
	SaveManager.save_path = "user://crow_shot_save.json"
	SaveManager.delete_save()
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	GameClock.minutes = 17 * 60
	GameClock.season = 1
	GameClock.paused = true
	var dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://"
	await world.go_to_region("crows_camp", "camp")
	var crow := world.region.find_child("Crow", true, false) as Node2D
	world.player.global_position = crow.global_position + Vector2(-56, 24)
	world.player.get_node("Camera").reset_smoothing()
	for i in 20:
		await get_tree().process_frame
	_save(dir, "crow_camp")
	TripEffect.play(self)
	for at: float in [1.5, 3.0, 2.0]:
		await get_tree().create_timer(at).timeout
		_save(dir, "crow_trip_%d" % int(Time.get_ticks_msec() / 1000))
	await get_tree().create_timer(5.0).timeout
	TripEffect.haze(self)
	await get_tree().create_timer(3.0).timeout
	_save(dir, "crow_haze")
	get_tree().quit()


func _save(dir: String, shot_name: String) -> void:
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, shot_name])
