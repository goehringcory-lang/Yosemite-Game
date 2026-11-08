extends Node
## Screenshots of a heart scene (HeartScenes): the pink heart over a
## friend's head, the first page of what they tell you, their question, their
## answer and the gift, and an everyday line after.
## Needs a window (not --headless):
##   SHOT_DIR=/tmp/shots xvfb-run -a godot --path . res://tools/shots/heart_scene_shot.tscn
## Environment:
##   SHOT_WHO     character id (default mateo_reyes)
##   SHOT_REGION  where they stand (default yosemite_village)
##   SHOT_HEARTS  3 or 5 (default 3)
##   SHOT_PICK    which answer to give (default 0)


func _env(key: String, fallback: String) -> String:
	return OS.get_environment(key) if OS.get_environment(key) != "" else fallback


func _snap(dir: String, shot_name: String, frames := 6) -> void:
	for i in frames:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/heart_%s.png" % [dir, shot_name])


func _box() -> DialogueBox:
	for child in get_tree().root.get_children():
		if child is DialogueBox and not child.is_queued_for_deletion():
			return child
	return null


func _ready() -> void:
	SaveManager.save_path = "user://heart_scene_shot_save.json"
	SaveManager.delete_save()
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var dir := _env("SHOT_DIR", "user://")
	var who := _env("SHOT_WHO", "mateo_reyes")
	var hearts := int(_env("SHOT_HEARTS", "3"))
	await world.go_to_region(_env("SHOT_REGION", "yosemite_village"), "arrival")
	GameClock.season = GameClock.Season.SUMMER
	GameClock.minutes = 11 * 60
	GameClock.paused = true
	var npc: NPC = null
	for node in world.region.find_children("*", "NPC", true, false):
		if (node as NPC).character and node.character.id == who:
			npc = node
	if npc == null:
		push_error("nobody called %s here" % who)
		get_tree().quit(1)
		return
	if hearts >= 5:
		Friendship.scenes[who] = 3
	Friendship.points[who] = hearts * Friendship.POINTS_PER_HEART
	# off to one side first, so the bubble isn't under the talk prompt
	var player: Player = world.player
	player.global_position = npc.global_position + Vector2(-110, 16)
	player.facing = Vector2i.RIGHT
	world._camera().reset_smoothing()
	await _snap(dir, "bubble", 30)
	player.global_position = npc.global_position + Vector2(0, 36)
	player.facing = Vector2i.UP
	npc.interact(player)
	var page := 0
	for i in 400:
		await get_tree().process_frame
		var box := _box()
		if box == null:
			if not npc._talking:
				break
			continue
		box.reveal_all()
		if not box._options.is_empty():
			await _snap(dir, "question", 4)
			box._cursor = int(_env("SHOT_PICK", "0"))
			box._refresh_options()
		elif page == 0 or box._text_label.text.begins_with("Received"):
			await _snap(dir, "gift" if page > 0 else "story", 4)
		page += 1
		box.press()
	await _snap(dir, "after", 10)
	SaveManager.delete_save()
	get_tree().quit()
