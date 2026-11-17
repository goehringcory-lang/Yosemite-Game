extends Node
## Screenshots of Wren's own story: her application ("With a Form"), Jo's
## question, Wren guiding you as her first client, Marty on the storm on
## Nutcracker, and the top of Royal Arches ("Swinging Leads").
## Needs a window (not --headless):
##   SHOT_DIR=/tmp/shots xvfb-run -a godot --path . res://tools/shots/wren_story_shot.tscn

const EARLIER := ["clark_register", "shop_guidebook", "shop_outfit", "partner_apron", "leonard_belay", "eichorn_apron",
	"robbins_clean", "wren_apron", "wren_slackline", "wren_lightning", "hodges_rescue_team"]


func _env(key: String, fallback: String) -> String:
	return OS.get_environment(key) if OS.get_environment(key) != "" else fallback


func _snap(dir: String, shot_name: String, frames := 6) -> void:
	for i in frames:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/wren_%s.png" % [dir, shot_name])


func _box() -> DialogueBox:
	for child in get_tree().root.get_children():
		if child is DialogueBox and not child.is_queued_for_deletion():
			return child
	return null


## The person to talk to in this region: an NPC with [param id], or the
## shop counter that talks as them.
func _find(world: Node, id: String) -> Node2D:
	for node in world.region.find_children("*", "NPC", true, false):
		if node.character and node.character.id == id:
			return node
	for node in world.region.find_children("*", "Vendor", true, false):
		if node.shop and node.shop.talk_target == id:
			return node
	return null


## Talks to [param id] and snaps the pages whose text has a key of [param
## want] in it.
func _talk(world: Node, dir: String, id: String, want: Dictionary) -> void:
	var who := _find(world, id)
	if who == null:
		push_error("%s isn't here" % id)
		return
	var player: Player = world.player
	player.global_position = who.global_position + Vector2(0, 40)
	player.facing = Vector2i.UP
	world._camera().reset_smoothing()
	for i in 10:
		await get_tree().process_frame
	who.interact(player)
	for i in 900:
		await get_tree().process_frame
		var box := _box()
		if box == null:
			if not who._talking:
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


func _at(hour: int) -> void:
	GameClock.minutes = hour * 60
	GameClock.time_changed.emit(GameClock.hour, GameClock.minute)


func _ready() -> void:
	SaveManager.save_path = "user://wren_story_shot_save.json"
	SaveManager.delete_save()
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var dir := _env("SHOT_DIR", "user://")
	var guide: FirstDay = world.get_node("FirstDay")
	for id: String in FirstDay.LESSONS:
		guide.mark(id)
	QuestLog.completed.append_array(EARLIER)
	GameClock.season = GameClock.Season.SUMMER
	GameClock.day = 8
	GameClock.paused = true

	# With a Form: Wren asks, then Jo's question.
	await world.go_to_region("curry_village", "arrival")
	_at(12)
	await _talk(world, dir, "wren_alvarez", {"With a form": "ask"})
	QuestLog.talk_to("mountain_shop")
	await world.go_to_region("yosemite_village", "arrival")
	_at(12)
	await _talk(world, dir, "jo_tolliver", {"turn round, because": "jo"})
	QuestLog.talk_to("wren_alvarez")
	QuestLog.talk_to("jo_tolliver")
	Inventory.add("trail_mix", 4)
	QuestLog.talk_to("wren_alvarez")

	# First Client: a guided morning on Firefall Slab, then Marty's side of it.
	QuestLog.completed.append("harding_summit")
	GameClock.season = GameClock.Season.SPRING
	QuestLog.talk_to("wren_alvarez")
	await world.go_to_region("curry_village", "arrival")
	GameClock.season = GameClock.Season.SPRING
	_at(7)
	await _talk(world, dir, "wren_alvarez", {"carabiner": "guide"})
	await world.go_to_region("curry_mountain_shop", "door")
	await _talk(world, dir, "mountain_shop", {"money back": "marty"})
	QuestLog.talk_to("wren_alvarez")

	# Swinging Leads: the top of Royal Arches.
	QuestLog.completed.append_array(["bestor_arches", "jo_first_call"])
	_at(12) # the dawn start is its own step
	QuestLog.talk_to("wren_alvarez")
	QuestLog.talk_to("jo_tolliver")
	Inventory.add("trail_mix", 6)
	QuestLog.talk_to("wren_alvarez")
	await world.go_to_region("curry_village", "arrival")
	GameClock.season = GameClock.Season.SPRING
	_at(6)
	await _talk(world, dir, "wren_alvarez", {"That's the rim": "rim", "saying yes": "yes"})
	SaveManager.delete_save()
	get_tree().quit()
