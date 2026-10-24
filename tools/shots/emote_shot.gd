extends Node
## Saves a screenshot of the emote bubbles (scripts/story/emote.gd) over the
## people of Yosemite Village. Needs a window.
##   SHOT_DIR=/tmp/shots xvfb-run -a godot --path . res://tools/shots/emote_shot.tscn


func _ready() -> void:
	SaveManager.save_path = "user://emote_shot_save.json"
	SaveManager.delete_save()
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	GameClock.minutes = 12 * 60
	GameClock.paused = true
	await world.go_to_region("yosemite_village", "degnans_bakery")
	world.hud.visible = false
	for i in 20:
		await get_tree().process_frame
	# everyone in view shows a different bubble
	var kinds := Emote.GLYPHS.keys()
	var k := 0
	var near: Array[Node2D] = []
	for npc in get_tree().get_nodes_in_group("talkers"):
		if npc is Node2D and (npc as Node2D).global_position.distance_to(world.player.global_position) < 420.0 and npc.visible:
			near.append(npc)
	for npc in near:
		Emote.pop(npc, kinds[k % kinds.size()])
		k += 1
	await get_tree().create_timer(0.4).timeout
	var dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://"
	get_viewport().get_texture().get_image().save_png(dir + "/emotes.png")
	print("emotes over ", near.size(), " people")
	get_tree().quit()
