extends Node
## Screenshots of search and rescue from Camp 4: Jo at the rescue site, the
## boy's prints through Cook's Meadow, carrying him back, the lower after a
## climb, and the rescue call in the Quests tab.
## Needs a window (not --headless):
##   SHOT_DIR=/tmp/shots xvfb-run -a godot --path . res://tools/shots/rescue_shot.tscn


func _snap(dir: String, shot_name: String, frames := 8) -> void:
	for i in frames:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/rescue_%s.png" % [dir, shot_name])


func _ready() -> void:
	SaveManager.save_path = "user://rescue_shot_save.json"
	SaveManager.delete_save()
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	GameClock.season = GameClock.Season.SUMMER
	GameClock.minutes = 10 * 60
	GameClock.paused = true
	var dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://"
	await world.go_to_region("yosemite_village", "camp_4")
	for i in 6:
		await get_tree().process_frame
	# Jo at the rescue site, by the sign.
	var jo: NPC = null
	for node in world.region.find_children("*", "NPC", true, false):
		if node.character and node.character.id == Rescues.LEAD:
			jo = node
	if jo:
		world.player.global_position = jo.global_position + Vector2(-40, 30)
		world.player.facing = Vector2i.RIGHT
	await _snap(dir, "site", 20)
	# The first call: the boy's prints from the Cook's Meadow boardwalk.
	QuestLog.completed.append_array(["leonard_belay", Rescues.JOIN_QUEST])
	QuestLog.active[Rescues.FIRST_QUEST] = 0
	Rescues.begin(Rescues.FIRST_CALL)
	for i in 4:
		await get_tree().process_frame
	var field: RescueField = null
	for child in world.get_children():
		if child is RescueField:
			field = child
	if field and field.prints.size() > 6:
		world.player.global_position = field.prints[field.prints.size() / 2][0]
		world.player.facing = Vector2i.LEFT
	await _snap(dir, "prints", 12)
	# Found him, and carrying him back.
	Rescues.reach()
	world.player.facing = Vector2i.RIGHT
	await _snap(dir, "carry", 12)
	# The lower after a climb.
	var lower := RescueLower.new()
	add_child(lower)
	lower.set_process(false)
	lower.start(load("res://data/routes/swan_slab.tres"))
	for i in 160:
		lower.step(1.0 / 60.0, true)
	await _snap(dir, "lower")
	lower.queue_free()
	# The Quests tab, with the call underway.
	var journal: Journal = get_tree().get_first_node_in_group("journal")
	journal.open(Journal.Tab.QUESTS)
	await _snap(dir, "quests")
	journal.close()
	SaveManager.delete_save()
	get_tree().quit()
