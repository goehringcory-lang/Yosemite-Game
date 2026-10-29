extends Node
## Screenshots of the big animals that wander by (Bears, Deer) in Leidig
## Meadow: a cinnamon mother bear and her cubs ambling across and a brown
## bear stopped to look at you; then a doe grazing with her fawns, and a
## buck staring and another bounding off.
## Needs a window (not --headless):
##   SHOT_DIR=/tmp/shots xvfb-run -a godot --path . res://tools/shots/bear_shot.tscn


func _ready() -> void:
	SaveManager.save_path = "user://bear_shot_save.json"
	SaveManager.delete_save()
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://"
	await world.go_to_region("leidig_meadow", "meadow")
	for i in 12:
		await get_tree().process_frame
	GameClock.minutes = 17 * 60 + 30
	GameClock.season = GameClock.Season.SUMMER
	GameClock.paused = true
	var bears: Bears = world.find_children("*", "Bears", true, false)[0]
	var deer: Deer = world.find_children("*", "Deer", true, false)[0]
	var at: Vector2 = world.player.global_position
	bears.add_group(at + Vector2(-170, 70), at + Vector2(500, 120), 1, 2)
	var brown := bears.add_group(at + Vector2(Bears.NOTICE_DISTANCE - 20.0, -40), at + Vector2(700, -40), 0)
	for i in 6:
		await get_tree().process_frame
	# hold them still for the picture: the brown one looking your way
	bears.set_process(false)
	brown.state = "watch"
	brown.facing = -1
	brown.queue_redraw()
	await _snap(dir, "bears_meadow")
	bears._clear()
	# the deer
	var doe := deer.add_group(at + Vector2(-190, 60), at + Vector2(-600, 60), 0, 2)
	var buck := deer.add_group(at + Vector2(200, 30), at + Vector2(600, 30), 3)
	var bounder := deer.add_group(at + Vector2(90, 140), at + Vector2(800, 140), 2)
	for i in 6:
		await get_tree().process_frame
	deer.set_process(false)
	doe.state = "forage"
	doe.queue_redraw()
	for fawn in deer.animals():
		if fawn.leader == doe:
			fawn.state = "wander"
			fawn.queue_redraw()
	buck.state = "watch"
	buck.facing = -1
	buck.queue_redraw()
	bounder.state = "leave"
	bounder.speed = deer.leave_speed
	bounder.steps = 0.7
	bounder.facing = 1
	bounder.queue_redraw()
	await _snap(dir, "deer_meadow")
	SaveManager.delete_save()
	get_tree().quit()


func _snap(dir: String, shot_name: String) -> void:
	for i in 6:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, shot_name])
