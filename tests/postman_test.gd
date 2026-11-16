extends Node
## Headless test of "General Delivery": Michael Kochakji at the Tuolumne
## Meadows post office (in the store) hands you a lost Pacific Crest Trail
## hiker's resupply box; Switchback, lost past Lembert Dome, takes it and
## gives you a postcard home; Michael postmarks it and opens the hiker box.
## Also: both of them stand where you can walk up to them, Switchback is
## only out there while the box is on its way, and she keeps no hearts.
## Run: godot --headless --path . res://tests/postman_test.tscn
## Exit code is the number of failed checks.

const QUEST := "kochakji_general_delivery"
const POSTMAN := "michael_kochakji"
const HIKER := "switchback"

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	SaveManager.save_path = "user://postman_test_save.json"
	SaveManager.delete_save()
	test_definitions()
	test_offered()
	test_quest()
	await test_placements()
	SaveManager.delete_save()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func new_game(season: int) -> void:
	NewGame.reset()
	GameClock.season = season
	GameClock.day = 3
	GameClock.minutes = 10 * 60
	QuestLog.completed.append("harding_summit")


func _texts(lines: Array) -> String:
	return "\n".join(lines.map(func(l: Dictionary) -> String: return l.text))


func test_definitions() -> void:
	var quest := QuestLog.get_quest(QUEST)
	check(quest != null and quest.giver == POSTMAN and quest.title == "General Delivery", "Michael Kochakji gives General Delivery")
	var michael := QuestLog.get_character(POSTMAN)
	check(michael != null and michael.staff and michael in QuestLog.STAFF and CharacterSheet.has_poses(michael.sprite_sheet),
		"Michael Kochakji is invented staff, with every pose")
	check(Portraits.for_speaker("Michael Kochakji") != null and Portraits.for_speaker("Switchback") != null, "both have a portrait")
	check(QuestLog.get_character(HIKER) == null, "Switchback isn't in the cast: you meet her once")
	for id in ["resupply_box", "hiker_postcard"]:
		check(ItemDB.get_item(id) != null and ItemDB.get_item(id).icon != null, "%s is an item, with an icon" % id)


func test_offered() -> void:
	new_game(GameClock.Season.SUMMER)
	QuestLog.completed.erase("harding_summit")
	check(QuestLog.available_from(POSTMAN) == null, "not before Tuolumne is open (after the Nose)")
	new_game(GameClock.Season.WINTER)
	check(QuestLog.available_from(POSTMAN) == null and QuestLog.waiting_for_season(POSTMAN) != null, "not in winter: come back in summer")
	check("summer" in _texts(QuestLog.talk_to(POSTMAN, "Michael Kochakji")), "and he says so")
	for season in [GameClock.Season.SUMMER, GameClock.Season.FALL]:
		new_game(season)
		check(QuestLog.available_from(POSTMAN) != null, "offered in season %d" % season)


func test_quest() -> void:
	new_game(GameClock.Season.SUMMER)
	var said := _texts(QuestLog.talk_to(POSTMAN, "Michael Kochakji"))
	check(QuestLog.active.has(QUEST) and Inventory.count("resupply_box") == 1, "the quest starts with the box in your pack")
	check("Received 1 Resupply Box" in said, "the box is announced (%s)" % said.right(80))
	check(QuestLog.marker_for(HIKER) == "!", "Switchback is marked")
	said = _texts(QuestLog.talk_to(POSTMAN, "Michael Kochakji"))
	check("Lembert Dome" in said and QuestLog.current_step(QuestLog.get_quest(QUEST)).type == "talk", "Michael reminds you where she went")
	var lines := QuestLog.talk_to(HIKER, "Switchback")
	said = _texts(lines)
	check(lines[0].speaker == "Switchback", "Switchback speaks as herself")
	check(Inventory.count("resupply_box") == 0 and Inventory.count("hiker_postcard") == 1, "she takes the box and gives you a postcard")
	check("You hand over 1 Resupply Box. Received 1 Switchback's Postcard." in said, "and it says so (%s)" % said.right(90))
	check(QuestLog.marker_for(POSTMAN) == "?", "Michael is waiting for the postcard")
	var mix := Inventory.count("trail_mix")
	said = _texts(QuestLog.talk_to(POSTMAN, "Michael Kochakji"))
	check(QuestLog.is_completed(QUEST) and Inventory.count("hiker_postcard") == 0, "the postcard goes in the mail and the quest is done")
	check(Inventory.count("trail_mix") == mix + 3 and "hiker box" in said, "the hiker box is yours to pick through")


func test_placements() -> void:
	# Michael in the store, by the boxes
	var store: Region = (load("res://scenes/regions/tuolumne_store.tscn") as PackedScene).instantiate()
	add_child(store)
	StoryContent.attach(store)
	var meadows: Region = (load(Park.get_hub("tuolumne_meadows").scene_path()) as PackedScene).instantiate()
	add_child(meadows)
	meadows.position = Vector2(0, 4000)
	StoryContent.attach(meadows)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var michael := _npc(store, POSTMAN)
	var hiker := _npc(meadows, HIKER)
	check(michael != null and hiker != null, "both are placed")
	if michael == null or hiker == null:
		return
	check(hiker.only_on_step == QUEST + ":0", "Switchback is out there only while the box is on its way")
	for pair: Array in [[store, michael, "door"], [meadows, hiker, "arrival"]]:
		var region: Region = pair[0]
		var npc: NPC = pair[1]
		var at := npc.global_position if npc.is_inside_tree() else region.to_global(npc.position)
		var grid := WalkGrid.finer(region, 8, Vector2(20, 12))
		var from := region.get_spawn(pair[2]).global_position
		var route := grid.route(from, at)
		check(not route.is_empty() and route[route.size() - 1].distance_to(at) < 24.0,
			"%s can be walked up to from %s (%s)" % [npc.character.display_name, pair[2], npc.position])
	store.free()
	meadows.free()


func _npc(region: Region, id: String) -> NPC:
	for node in region.entities.get_children():
		if node is NPC and node.character and node.character.id == id:
			return node
	return null
