extends Node
## Plays the Ahwahnee chef's side story, The Chef's Larder: Lucien Marchand
## in the dining room asks for wild strawberries and yerba buena, then leaves
## his kitchen to meet you at the old black oak on the Tea Lawn, pulls the
## wild grape aside, and shows you the face carved in its bark.
## Run: godot --headless --path . res://tests/chef_test.tscn
## Exit code is the number of failed checks. Uses its own save file.

const QUEST := "ahwahnee_chef_larder"
const CHEF := "ahwahnee_chef"

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func said(lines: Array[Dictionary], text: String) -> bool:
	return lines.any(func(l: Dictionary) -> bool: return text in l.text)


func _ready() -> void:
	await get_tree().process_frame
	SaveManager.save_path = "user://chef_test_save.json"
	SaveManager.delete_save()
	var world = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(world)
	await get_tree().process_frame
	_check_data()
	await _play(world)
	SaveManager.delete_save()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func _check_data() -> void:
	var quest := QuestLog.get_quest(QUEST)
	var chef := QuestLog.get_character(CHEF)
	check(quest != null and not quest.main_line and not quest.press_line and quest.giver == CHEF, "The Chef's Larder is a side story from the chef")
	check(chef != null and chef.staff and not chef.visitor and chef in QuestLog.STAFF, "the chef is invented staff, not in the Register")
	check(RegisterPages.PAGES.all(func(p: Dictionary) -> bool: return p.quest != QUEST), "it writes no Register page")
	check(Portraits.for_speaker(chef.display_name) != null, "the chef has a portrait")
	check(GuardianMirror.GATHERING.any(func(e: Array) -> bool: return e[0] == CHEF), "the chef has a line in the cave")


func _play(world) -> void:
	Inventory.items.clear()
	QuestLog.start_new_game()
	QuestLog.completed.append("clark_register")
	GameClock.paused = true
	GameClock.season = GameClock.Season.WINTER
	var lines := QuestLog.talk_to(CHEF)
	check(not QuestLog.active.has(QUEST) and said(lines, "under the snow"), "in winter he says to come back in spring")
	GameClock.season = GameClock.Season.SUMMER

	world._enter_region("ahwahnee_dining_room", "from_lobby")
	await get_tree().process_frame
	var cook: NPC = world.region.find_child("AhwahneeChef", true, false)
	check(cook != null and cook.is_here() and cook.visible, "the chef is in the dining room")
	check(QuestLog.marker_for(CHEF) == "!", "with a ! for his errand")
	lines = QuestLog.talk_to(CHEF)
	check(QuestLog.active.get(QUEST, -1) == 0 and said(lines, "show you something"), "he asks for ingredients and promises to show you something")
	Inventory.add("wild_strawberry", 3)
	lines = QuestLog.talk_to(CHEF)
	check(QuestLog.active.get(QUEST, -1) == 0 and Inventory.count("wild_strawberry") == 3, "three strawberries aren't enough")
	Inventory.add("wild_strawberry", 1)
	Inventory.add("yerba_buena", 2)
	lines = QuestLog.talk_to(CHEF)
	check(Inventory.count("wild_strawberry") == 0 and Inventory.count("yerba_buena") == 0, "he takes the strawberries and the yerba buena")
	check(QuestLog.active.get(QUEST, -1) == 2 and said(lines, "old black oak"), "then sends you out to the old black oak")
	check(not cook.is_here() and not cook.visible, "and leaves the dining room")

	world._enter_region("the_ahwahnee", "tea_lawn")
	await get_tree().process_frame
	var oak: CarvedOak = world.region.find_child("CarvedOak", true, false)
	var waiting: NPC = world.region.find_child("AhwahneeChefAtOak", true, false)
	check(oak != null and waiting != null, "the oak and the chef are on the Tea Lawn")
	check(waiting.is_here() and waiting.visible, "the chef waits under the oak")
	check(not oak.is_revealed() and oak.get_node("Sprite").texture == oak.hidden_texture, "wild grape still hangs over the trunk")
	check("Wild grape" in oak.current_text() and oak.get_prompt() == "Look: The Old Black Oak", "and the oak reads as a plain old tree")
	lines = QuestLog.talk_to(CHEF)
	check(QuestLog.is_completed(QUEST) and said(lines, "carved into the bark"), "he pulls the vines aside and shows you the carving")
	check(said(lines, "theirs to tell"), "and says the story isn't his to tell")
	check(Inventory.count("bread_pudding") == 2, "he sends you off with bread pudding")
	check(oak.is_revealed() and oak.get_node("Sprite").texture == oak.revealed_texture, "the carving shows on the trunk")
	check("carved a face" in oak.current_text(), "and the oak's text describes it")
	check(not waiting.is_here() and not waiting.visible, "the chef goes back to his kitchen")
	world._enter_region("ahwahnee_dining_room", "from_lobby")
	await get_tree().process_frame
	check(cook.is_here() and cook.visible, "where he is again")
	lines = QuestLog.talk_to(CHEF)
	check(String(lines[0].text) in QuestLog.get_character(CHEF).idle_lines, "and he's back to his usual lines")
