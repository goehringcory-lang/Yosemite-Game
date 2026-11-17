extends Node
## Headless test of Wren's own story, three side quests after her Apron:
## "With a Form" (references from Marty and Jo for the climbing school),
## "First Client" (she guides you, then turns her first real client round on
## Nutcracker) and "Swinging Leads" (Jo's word, then Royal Arches together).
## Also: the chalk bags at your camp, her line at the supper, and what she,
## Marty and Jo say afterwards.
## Run: godot --headless --path . res://tests/wren_story_test.tscn
## Exit code is the number of failed checks.

const WREN := "wren_alvarez"
const MARTY := "mountain_shop"
const JO := "jo_tolliver"
const ARC := ["wren_reference", "wren_first_client", "wren_long_way"]
## Wren's earlier quests, which come first.
const BEFORE := ["partner_apron", "wren_apron", "wren_slackline", "wren_lightning"]

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	SaveManager.save_path = "user://wren_story_test_save.json"
	SaveManager.delete_save()
	test_definitions()
	test_with_a_form()
	test_first_client()
	test_swinging_leads()
	test_afterwards()
	test_heart_scene()
	SaveManager.delete_save()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func new_game(done: Array) -> void:
	NewGame.reset()
	GameClock.season = GameClock.Season.SUMMER
	GameClock.day = 3
	GameClock.minutes = 12 * 60
	QuestLog.completed.append_array(BEFORE + done)


func _texts(lines: Array) -> String:
	return "\n".join(lines.map(func(l: Dictionary) -> String: return l.text))


func _talk(id: String) -> String:
	return _texts(QuestLog.talk_to(id))


func _feed(energy: int) -> void:
	Inventory.add("trail_mix", energy / maxi(1, FoodDB.energy("trail_mix")) + 2)


func test_definitions() -> void:
	for id: String in ARC:
		var quest := QuestLog.get_quest(id)
		check(quest != null and quest.giver == WREN and not quest.main_line and not quest.press_line, "%s is Wren's side story" % id)
	var wren := QuestLog.get_character(WREN)
	check(wren != null and not wren.needs_tribal_review and "Invented" in wren.sources, "Wren is invented, so her story is free to write")
	for id: String in ARC:
		for target: String in QuestLog.get_quest(id).steps.filter(func(s: Dictionary) -> bool: return s.type == "talk").map(func(s: Dictionary) -> String: return s.target):
			var who := QuestLog.get_character(target)
			check(who != null and who.staff, "%s only sends you to invented staff (%s)" % [id, target])


func test_with_a_form() -> void:
	new_game(["robbins_clean"])
	check(QuestLog.available_from(WREN) == null, "not before you've met Jo at the rescue site")
	new_game(["robbins_clean", "hodges_rescue_team"])
	var said := _talk(WREN)
	check(QuestLog.active.has("wren_reference") and "climbing school" in said, "Wren is applying to guide, and asks for your help")
	check(QuestLog.marker_for(MARTY) == "!", "Marty is marked for her first reference")
	check("partners" in _talk(MARTY), "Marty signs, and says why")
	check(QuestLog.marker_for(JO) == "!", "then Jo")
	check("turn round" in _talk(JO), "Jo won't sign till she hears when Wren would turn a client round")
	check(QuestLog.marker_for(WREN) == "!", "so back to Wren")
	check("pretending" in _talk(WREN), "Wren answers")
	check("Jo yet" in _talk(WREN), "and asks, if you come back first, whether Jo has heard it")
	check("whole job" in _talk(JO), "and Jo signs")
	_talk(WREN)
	check(QuestLog.active.has("wren_reference"), "lunch for the check-out climb next")
	_feed(20)
	said = _talk(WREN)
	check(QuestLog.is_completed("wren_reference") and "spring" in said, "check-out done: the list goes up in spring")


func test_first_client() -> void:
	new_game(["robbins_clean", "hodges_rescue_team", "wren_reference"])
	check(QuestLog.available_from(WREN) == null, "her first client waits till you've climbed the Nose")
	QuestLog.completed.append("harding_summit")
	GameClock.season = GameClock.Season.WINTER
	check(QuestLog.available_from(WREN) == null and QuestLog.waiting_for_season(WREN) != null, "the guide list goes up in spring")
	check("spring" in _talk(WREN), "and she says so")
	GameClock.season = GameClock.Season.SPRING
	var said := _talk(WREN)
	check(QuestLog.active.has("wren_first_client") and "first client" in said, "she got it, and you're her first client")
	_talk(WREN)
	check(QuestLog.current_step(QuestLog.get_quest("wren_first_client")).type == "time", "it's a morning climb, not now")
	GameClock.minutes = 7 * 60
	said = _talk(WREN)
	check("carabiner" in said and "Nutcracker" in said, "she guides you up Firefall Slab, and her real client wants Nutcracker")
	check(QuestLog.marker_for(MARTY) == "!", "Marty knows how it went")
	said = _talk(MARTY)
	check("turned him round" in said and "money back" in said, "she turned him round before the storm, and he wanted his money back")
	said = _talk(WREN)
	check(QuestLog.is_completed("wren_first_client") and "bad guide" in said, "and she thinks she's a bad guide")


func test_swinging_leads() -> void:
	new_game(["robbins_clean", "hodges_rescue_team", "wren_reference", "harding_summit", "wren_first_client"])
	check(QuestLog.available_from(WREN) == null, "Swinging Leads waits for Royal Arches and your first call-out")
	QuestLog.completed.append_array(["bestor_arches", "hodges_rescue_team", "jo_first_call"])
	var said := _talk(WREN)
	check(QuestLog.active.has("wren_long_way") and "turned round" in said, "she asks you to ask Jo")
	said = _talk(JO)
	check("walk home" in said and "keeping her" in said, "Jo: the ones who turn round walk home, and the school's keeping her")
	_feed(40)
	said = _talk(WREN)
	check("Twice" in said, "she hears it")
	GameClock.minutes = 12 * 60
	_talk(WREN)
	check(QuestLog.active.has("wren_long_way"), "the Arches are a dawn start")
	var cams := Gear.count("cam")
	GameClock.minutes = 6 * 60
	said = _talk(WREN)
	check(QuestLog.is_completed("wren_long_way") and "saying yes" in said, "on top, she says yes to the school")
	check(Gear.count("cam") == cams + 1, "and gives you one of her cams")
	check(Camp.has("chalk_peg") and "chalk bag" in said, "and her chalk bag for your camp")


func test_afterwards() -> void:
	new_game(["robbins_clean", "hodges_rescue_team", "wren_reference", "harding_summit", "wren_first_client"])
	var lines := SmallTalk.choices(QuestLog.get_character(WREN)).map(func(o: Array) -> String: return o[0])
	check(lines.any(func(t: String) -> bool: return "replaying" in t), "after her first client, Wren keeps replaying it")
	QuestLog.completed.append_array(["bestor_arches", "jo_first_call", "wren_long_way"])
	lines = SmallTalk.choices(QuestLog.get_character(WREN)).map(func(o: Array) -> String: return o[0])
	check(lines.any(func(t: String) -> bool: return "guide now" in t) and not lines.any(func(t: String) -> bool: return "replaying" in t),
		"once she's guiding she talks about that instead")
	for id: String in [MARTY, JO]:
		lines = SmallTalk.choices(QuestLog.get_character(id)).map(func(o: Array) -> String: return o[0])
		check(lines.any(func(t: String) -> bool: return "Wren" in t), "%s talks about Wren guiding" % id)
	var entry: Array = GuardianFeast.LINES.filter(func(e: Array) -> bool: return e[0] == WREN)[0]
	check("guide" in GuardianFeast.line_for(entry), "at the supper she's a guide")
	QuestLog.completed.erase("wren_long_way")
	check(GuardianFeast.line_for(entry) == entry[1], "and without her story, the usual line")
	for id: String in SmallTalk.LINES:
		for quest_id: String in SmallTalk.LINES[id].get("after", {}):
			check(QuestLog.get_quest(quest_id) != null, "%s's lines after %s follow a real quest" % [id, quest_id])


func test_heart_scene() -> void:
	new_game([])
	var scene: Dictionary = HeartScenes.SCENES[WREN][5]
	check("someday" in " ".join(HeartScenes.scene_now(scene).lines) or "keep thinking" in " ".join(HeartScenes.scene_now(scene).lines),
		"before her application, Wren's 5-heart scene is a daydream")
	QuestLog.active["wren_reference"] = 0
	check("really doing it" in " ".join(HeartScenes.scene_now(scene).lines), "once she's applied, she says so")
	QuestLog.active.erase("wren_reference")
	QuestLog.completed.append("wren_reference")
	check(HeartScenes.scene_now(scene).ask == "Do you think I'm any good at it?", "and asks a guide's question")
