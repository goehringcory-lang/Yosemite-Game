extends Node
## Screenshots of "General Delivery": Michael Kochakji at the Tuolumne
## Meadows post office handing over a lost hiker's resupply box, Switchback
## lost past Lembert Dome, her thanks, and the postcard postmarked.
## Needs a window (not --headless):
##   SHOT_DIR=/tmp/shots xvfb-run -a godot --path . res://tools/shots/postman_shot.tscn


func _env(key: String, fallback: String) -> String:
	return OS.get_environment(key) if OS.get_environment(key) != "" else fallback


func _snap(dir: String, shot_name: String, frames := 6) -> void:
	for i in frames:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/postman_%s.png" % [dir, shot_name])


func _box() -> DialogueBox:
	for child in get_tree().root.get_children():
		if child is DialogueBox and not child.is_queued_for_deletion():
			return child
	return null


func _npc(world: Node, id: String) -> NPC:
	for node in world.region.find_children("*", "NPC", true, false):
		if (node as NPC).character and node.character.id == id:
			return node
	return null


## Walks up to [param id] and talks, snapping the pages whose text has a key
## of [param want] in it.
func _talk(world: Node, dir: String, id: String, want: Dictionary, stand := Vector2(0, 40), facing := Vector2i.UP) -> void:
	var npc := _npc(world, id)
	if npc == null:
		push_error("%s isn't here" % id)
		return
	var player: Player = world.player
	player.global_position = npc.global_position + stand
	player.facing = facing
	world._camera().reset_smoothing()
	await _snap(dir, "before_" + id, 10)
	npc.interact(player)
	for i in 600:
		await get_tree().process_frame
		var box := _box()
		if box == null:
			if not npc._talking:
				break
			continue
		box.reveal_all()
		for key: String in want:
			if key in box._text_label.text:
				await _snap(dir, want[key], 4)
				want.erase(key)
				break
		box.press()


func _ready() -> void:
	SaveManager.save_path = "user://postman_shot_save.json"
	SaveManager.delete_save()
	Settings.tips = false
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var dir := _env("SHOT_DIR", "user://")
	var guide: FirstDay = world.get_node("FirstDay")
	for id: String in FirstDay.LESSONS:
		guide.mark(id)
	QuestLog.completed.append("harding_summit")
	Park.unlock_hub("tuolumne_meadows")
	GameClock.season = GameClock.Season.SUMMER
	GameClock.day = 12
	GameClock.minutes = 10 * 60
	GameClock.paused = true

	# Michael at the post office corner, with a box for a lost hiker.
	await world.go_to_region("tuolumne_store", "door")
	GameClock.time_changed.emit(GameClock.hour, GameClock.minute)
	await _talk(world, dir, "michael_kochakji", {"PLEASE HOLD on it": "ask", "Received 1 Resupply": "box"}, Vector2(40, 30), Vector2i.LEFT)

	# Switchback, lost on the Dog Lake trail.
	await world.go_to_region("tuolumne_meadows", "arrival")
	GameClock.minutes = 15 * 60
	GameClock.time_changed.emit(GameClock.hour, GameClock.minute)
	await _talk(world, dir, "switchback", {"my box": "found", "clean socks": "socks"}, Vector2(-44, 10), Vector2i.RIGHT)

	# Back at the counter: the postmark.
	await world.go_to_region("tuolumne_store", "door")
	GameClock.time_changed.emit(GameClock.hour, GameClock.minute)
	await _talk(world, dir, "michael_kochakji", {"Got found": "postcard", "hiker box": "hiker_box"}, Vector2(40, 30), Vector2i.LEFT)
	SaveManager.delete_save()
	get_tree().quit()
