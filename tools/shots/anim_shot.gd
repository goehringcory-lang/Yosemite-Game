extends Node
## Screenshots of people moving (CharacterSheet's poses): crouching to pick
## something up, the rod and line following a cast and a fish on, carrying
## someone back on a rescue, lying down to sleep, a friend waving and
## someone talking, and the run's spray of dust.
## Needs a window (not --headless):
##   SHOT_DIR=/tmp/shots xvfb-run -a godot --path . res://tools/shots/anim_shot.tscn

const Test := preload("res://tests/valley_life_test.gd")


func _snap(dir: String, shot_name: String, frames := 8) -> void:
	for i in frames:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/anim_%s.png" % [dir, shot_name])


func _ready() -> void:
	SaveManager.save_path = "user://anim_shot_save.json"
	SaveManager.delete_save()
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	GameClock.season = GameClock.Season.SUMMER
	GameClock.minutes = 10 * 60
	GameClock.paused = true
	var dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://"
	var player: Player = world.player
	world._enter_region("yosemite_village", "arrival")
	for i in 6:
		await get_tree().process_frame
	player.can_act = false
	world._camera().reset_smoothing()
	# Crouched to pick up what's at your feet.
	player.facing = Vector2i.LEFT
	player.pose("crouch")
	await _snap(dir, "forage")
	player.clear_pose()
	# On the bank: the rod back over your shoulder, then out, a trout on.
	var bank: Dictionary = Test.new()._bank(world)
	player.global_position = bank.at
	player.facing = bank.facing
	world._camera().reset_smoothing()
	Gear.add(Fishing.ROD)
	var game := FishingMinigame.new()
	add_child(game)
	game.set_process(false)
	game.start(Fishing.get_fish("brown_trout"), 3, {})
	player.fishing._game = game
	player.fishing._fly_at = player.fishing.to_local(Fishing.cast_point(player))
	game.step(FishingMinigame.GRACE + 0.01, false)
	game.meter_pos = game.meter_center - game.window() * 0.4
	game.step(0.01, false)
	await _snap(dir, "back_cast")
	game.meter_pos = game.meter_center
	game.press()
	game.step(FishingMinigame.UNROLL + 0.01, false)
	game.meter_pos = game.meter_center
	game.press()
	while game.phase == FishingMinigame.Phase.WAIT:
		game.step(0.1, false)
	for i in 50:
		game.step(1.0 / 60.0, game.band + FishingMinigame.BAND / 2.0 < game.fish_at)
	await _snap(dir, "reel")
	player.fishing._game = null
	player.fishing.queue_redraw()
	game.queue_free()
	player.clear_pose()
	# Lying down to sleep (and the Zzz) by the trail.
	world._enter_region("yosemite_village", "arrival")
	for i in 4:
		await get_tree().process_frame
	world._camera().reset_smoothing()
	player.lie_down(true)
	Emote.pop(player, "sleep")
	await _snap(dir, "sleep", 20)
	player.lie_down(false)
	# A friend waving, someone talking.
	for node in world.region.find_children("*", "NPC", true, false):
		var npc := node as NPC
		if npc.character == null or npc._sprite == null or not npc.visible:
			continue
		player.global_position = npc.global_position + Vector2(56, 10)
		world._camera().reset_smoothing()
		player.facing = Vector2i.LEFT
		npc.set_physics_process(false)
		npc.facing = Vector2i.RIGHT
		npc._talking = true
		npc._speaking = 2.0
		npc._update_frame(false)
		break
	await _snap(dir, "talk", 3)
	SaveManager.delete_save()
	get_tree().quit()
