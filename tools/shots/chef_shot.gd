extends Node
## Photographs the Ahwahnee chef's side story (The Chef's Larder): the chef in
## the dining room, then waiting under the old black oak on the Tea Lawn with
## the wild grape still over its trunk, then the carving once he's pulled the
## vines aside. Needs a window (not --headless).
## Run: SHOT_DIR=/tmp/shots godot --path . res://tools/shots/chef_shot.tscn

const QUEST := "ahwahnee_chef_larder"


func _ready() -> void:
	SaveManager.save_path = "user://chef_shot_save.json"
	SaveManager.delete_save()
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	GameClock.minutes = 7 * 60
	GameClock.season = 1
	GameClock.paused = true
	var dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://"
	world.hud.visible = false
	await world.go_to_region("ahwahnee_dining_room", "from_lobby")
	var chef := world.region.find_child("AhwahneeChef", true, false) as Node2D
	await _shoot(world, chef.global_position + Vector2(56, 16), dir, "chef_dining_room")
	QuestLog.active[QUEST] = 2
	QuestLog.changed.emit()
	await world.go_to_region("the_ahwahnee", "tea_lawn")
	var oak := world.region.find_child("CarvedOak", true, false) as Node2D
	await _shoot(world, oak.global_position + Vector2(96, 40), dir, "chef_at_oak")
	QuestLog.talk_to("ahwahnee_chef")
	await _shoot(world, oak.global_position + Vector2(96, 40), dir, "chef_carved_oak")
	get_tree().quit()


func _shoot(world: Node, at: Vector2, dir: String, shot_name: String) -> void:
	world.player.global_position = at
	world.player.facing = Vector2i.LEFT
	world.player.get_node("Camera").reset_smoothing()
	for i in 20:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, shot_name])
