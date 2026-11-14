extends Node
## Screenshots of "Down Before the Snow" (Warmth): Marty asking you to find
## the demo puffy, the torn jacket at the foot of Midnight Lightning, the
## winter cold without it (the snowflake bubble), and the mended puffy
## handed over.
## Needs a window (not --headless):
##   SHOT_DIR=/tmp/shots xvfb-run -a godot --path . res://tools/shots/puffy_shot.tscn


func _env(key: String, fallback: String) -> String:
	return OS.get_environment(key) if OS.get_environment(key) != "" else fallback


func _snap(dir: String, shot_name: String, frames := 6) -> void:
	for i in frames:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/puffy_%s.png" % [dir, shot_name])


func _box() -> DialogueBox:
	for child in get_tree().root.get_children():
		if child is DialogueBox and not child.is_queued_for_deletion():
			return child
	return null


## Talks to Marty at the counter and snaps the pages whose text has a key of
## [param want] in it. The trade menu after is left by its last option.
func _talk(world: Node, dir: String, want: Dictionary) -> void:
	var marty: Vendor = null
	for node in world.region.find_children("*", "Vendor", true, false):
		if (node as Vendor).shop and node.shop.talk_target == "mountain_shop":
			marty = node
	if marty == null:
		push_error("Marty isn't here")
		return
	var player: Player = world.player
	player.global_position = marty.global_position + Vector2(0, 44)
	player.facing = Vector2i.UP
	world._camera().reset_smoothing()
	marty.interact(player)
	for i in 600:
		await get_tree().process_frame
		var box := _box()
		if box == null:
			if not marty._talking:
				break
			continue
		box.reveal_all()
		if not box._options.is_empty():
			box._cursor = box._options.size() - 1
			box._refresh_options()
			box.press()
			continue
		for key: String in want:
			if key in box._text_label.text:
				await _snap(dir, want[key], 4)
				want.erase(key)
				break
		box.press()


func _ready() -> void:
	SaveManager.save_path = "user://puffy_shot_save.json"
	SaveManager.delete_save()
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var dir := _env("SHOT_DIR", "user://")
	# well past the first day, so its guide card is out of the way
	var guide: FirstDay = world.get_node("FirstDay")
	for id: String in FirstDay.LESSONS:
		guide.mark(id)
	for id in ["clark_register", "shop_guidebook", "shop_outfit"]:
		QuestLog.completed.append(id)
	GameClock.season = GameClock.Season.FALL
	GameClock.day = 12
	GameClock.minutes = 11 * 60
	GameClock.paused = true

	# Marty sets it aside.
	await world.go_to_region("curry_mountain_shop", "door")
	await _talk(world, dir, {"Patagonia": "ask"})

	# The torn puffy under Midnight Lightning.
	await world.go_to_region("yosemite_village", "arrival")
	GameClock.season = GameClock.Season.FALL
	GameClock.day = 12
	GameClock.minutes = 15 * 60
	GameClock.time_changed.emit(GameClock.hour, GameClock.minute)
	var pickup := world.region.find_child("Camp4TornPuffy", true, false) as Node2D
	if pickup:
		world.player.global_position = pickup.global_position + Vector2(-56, 20)
		world.player.facing = Vector2i.RIGHT
		world._camera().reset_smoothing()
		await _snap(dir, "camp4", 30)

	# Winter, without it: hunched in the cold.
	GameClock.season = GameClock.Season.WINTER
	await world.go_to_region("yosemite_village", "arrival")
	GameClock.season = GameClock.Season.WINTER
	GameClock.day = 9
	GameClock.minutes = 10 * 60
	GameClock.time_changed.emit(GameClock.hour, GameClock.minute)
	world.player.global_position += Vector2(0, 40)
	world._camera().reset_smoothing()
	await _snap(dir, "warm_up", 20)
	var bubble := Emote.pop(world.player, "cold")
	print("cold bubble: ", bubble, " cold=", Warmth.is_cold())
	await _snap(dir, "cold", 8)

	# Back at the shop with everything: the mended jacket.
	Inventory.add("torn_puffy")
	Inventory.add("wood_rose_hips", 3)
	# the jacket and the rose hips turn in; the trade is left for the shot
	QuestLog.talk_to("mountain_shop")
	QuestLog.talk_to("mountain_shop")
	Inventory.add("trail_mix", 2)
	await world.go_to_region("curry_mountain_shop", "door")
	await _talk(world, dir, {"Patched, zipped": "mended", "Received": "received"})
	SaveManager.delete_save()
	get_tree().quit()
