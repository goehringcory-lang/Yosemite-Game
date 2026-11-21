extends Node
## Screenshots of trading with the Camp 4 climbers (GearSale): the rack
## trader's list with the King Cobra swaps, selling spare gear, and a can
## shared over a new route.
## Needs a window (not --headless):
##   SHOT_DIR=/tmp/shots xvfb-run -a godot --path . res://tools/shots/climber_trades_shot.tscn


func _env(key: String, fallback: String) -> String:
	return OS.get_environment(key) if OS.get_environment(key) != "" else fallback


func _snap(dir: String, shot_name: String, frames := 6) -> void:
	for i in frames:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/climber_%s.png" % [dir, shot_name])


func _box() -> DialogueBox:
	for child in get_tree().root.get_children():
		if child is DialogueBox and not child.is_queued_for_deletion():
			return child
	return null


func _pick(box: DialogueBox, starts: String) -> bool:
	for i in box._options.size():
		if str(box._options[i]).begins_with(starts):
			box._cursor = i
			box._refresh_options()
			return true
	return false


func _ready() -> void:
	SaveManager.save_path = "user://climber_trades_shot_save.json"
	SaveManager.delete_save()
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var dir := _env("SHOT_DIR", "user://")
	var guide: FirstDay = world.get_node("FirstDay")
	for id: String in FirstDay.LESSONS:
		guide.mark(id)
	for id in ["clark_register", "shop_guidebook", "shop_outfit"]:
		QuestLog.completed.append(id)
	QuestLog.record_climb("swan_slab")
	GameClock.season = GameClock.Season.SUMMER
	GameClock.day = 12
	GameClock.minutes = 11 * 60
	GameClock.paused = true
	Gear.owned = {"rope": 1, "harness": 1, "cam": 5, "quickdraw": 9, "climbing_shoes": 1, "chalk_bag": 1, "belay_device": 1}
	Inventory.add("king_cobra", 4)
	Inventory.add("trail_mix", 2)
	await world.go_to_region("yosemite_village", "arrival")
	var trader: Vendor = world.region.find_child("RackTrader", true, false)
	var player: Player = world.player
	player.global_position = trader.global_position + Vector2(0, 44)
	player.facing = Vector2i.UP
	world._camera().reset_smoothing()
	await _snap(dir, "camp4", 20)
	trader.interact(player)
	var step := 0
	for i in 900:
		await get_tree().process_frame
		var box := _box()
		if box == null:
			if not trader._talking:
				break
			continue
		box.reveal_all()
		if box._options.is_empty():
			if step == 3 and "No way" in box._text_label.text:
				await _snap(dir, "toast", 4)
			box.press()
			continue
		match step:
			0:
				_pick(box, "Cam · for")
				await _snap(dir, "menu", 4)
				_pick(box, "Sell")
				step = 1
			1:
				_pick(box, "Camera")
				_pick(box, "Cam")
				await _snap(dir, "sell", 4)
				box._cursor = box._options.size() - 1
				box._refresh_options()
				step = 2
			2:
				if not _pick(box, "Share"):
					box._cursor = box._options.size() - 1
					box._refresh_options()
				step = 3
			_:
				box._cursor = box._options.size() - 1
				box._refresh_options()
		box.press()
	SaveManager.delete_save()
	get_tree().quit()
