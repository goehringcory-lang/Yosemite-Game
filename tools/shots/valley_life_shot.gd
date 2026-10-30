extends Node
## Screenshots of the valley life features: the back and forward casts on
## the cast meter and reeling in a trout on the Merced, Greg in Curry
## Village, the Camp 4 bulletin board's notes, the Journal's calendar and
## field log, and the Quests tab's board notes.
## Needs a window (not --headless):
##   SHOT_DIR=/tmp/shots xvfb-run -a godot --path . res://tools/shots/valley_life_shot.tscn

const Test := preload("res://tests/valley_life_test.gd")


func _snap(dir: String, shot_name: String, frames := 8) -> void:
	for i in frames:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/valley_life_%s.png" % [dir, shot_name])


func _ready() -> void:
	SaveManager.save_path = "user://valley_life_shot_save.json"
	SaveManager.delete_save()
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	GameClock.season = GameClock.Season.SUMMER
	GameClock.minutes = 10 * 60
	GameClock.paused = true
	var dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://"
	world._enter_region("yosemite_village", "arrival")
	for i in 6:
		await get_tree().process_frame
	# On the bank with a rod, a trout on the line.
	var bank: Dictionary = Test.new()._bank(world)
	world.player.global_position = bank.at
	world.player.facing = bank.facing
	Gear.add(Fishing.ROD)
	var game := FishingMinigame.new()
	add_child(game)
	game.set_process(false)
	game.start(Fishing.get_fish("brown_trout"), 3, {})
	# the back cast, the marker sweeping toward the green
	game.step(FishingMinigame.GRACE + 0.01, false)
	game.meter_pos = game.meter_center - game.window()
	game.step(0.01, false)
	await _snap(dir, "back_cast")
	game.meter_pos = game.meter_center
	game.press()
	game.step(FishingMinigame.UNROLL + 0.01, false)
	game.meter_pos = game.meter_center + game.window() * 0.9
	game.meter_dir = -1.0
	game.step(0.01, false)
	await _snap(dir, "forward_cast")
	game.meter_pos = game.meter_center
	game.press()
	while game.phase == FishingMinigame.Phase.WAIT:
		game.step(0.1, false)
	for i in 50:
		game.step(1.0 / 60.0, game.band + FishingMinigame.BAND / 2.0 < game.fish_at)
	await _snap(dir, "reel")
	game.queue_free()
	# Greg on the plaza, with his flies to trade.
	await world.go_to_region("curry_village", "arrival")
	for node in world.region.find_children("*", "NPC", true, false):
		if node.character and node.character.id == "greg":
			world.player.global_position = node.global_position + Vector2(0, 40)
			world.player.facing = Vector2i.UP
	await _snap(dir, "greg", 20)
	# Notes on the board, the calendar and field log, and the Quests tab.
	for id in ["bridget_degnan", "john_muir", "wren_alvarez"]:
		Friendship.note_talk(id)
	world.hud.show_info("Camp 4 bulletin board", BoardRequests.read())
	await _snap(dir, "board")
	world.hud.hide_info()
	for id in ["stellers_jay", "robin", "butterfly_0", "mountain_chickadee", "brown_trout"]:
		FieldLog.spot(id, true)
	var journal: Journal = get_tree().get_first_node_in_group("journal")
	journal.open(Journal.Tab.JOURNAL)
	await _snap(dir, "journal_top")
	journal.scroll_by(260)
	await _snap(dir, "journal_log")
	journal.show_tab(Journal.Tab.QUESTS)
	await _snap(dir, "quests")
	journal.close()
	get_tree().quit()
