extends Node
## Plays the Guardian's Year, the year of stewardship after the finale: a
## season's arc with each of George Anderson, Enid Michael, Galen Clark and
## Clare Hodges, their work spots round the park, the rock-work minigame,
## the changes the work leaves on the map, and Clark's quest that closes the
## year. Also checks the data and the Register notes.
## Run: godot --headless --path . res://tests/guardian_year_test.tscn
## Exit code is the number of failed checks.

## Each arc and its season (GameClock.Season: spring 0 to winter 3).
const ARCS := {"anderson_mist_steps": 0, "enid_cooks_meadow": 1, "clark_grove_fire": 2, "hodges_bear_boxes": 3}

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	await get_tree().process_frame
	_check_data()
	_check_rock_work()
	_play_before_the_finale()
	_play_spring()
	_play_summer()
	_play_fall()
	_play_winter()
	_play_the_year()
	_check_save()
	await _check_dressing()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func new_game(season: int) -> void:
	Inventory.start_new_game()
	Gear.start_new_game()
	QuestLog.start_new_game()
	Herbarium.start_new_game()
	Stewardship.start_new_game()
	GameClock.paused = true
	GameClock.year = 2
	set_season(season)


func set_season(season: int) -> void:
	GameClock.season = season
	GameClock.day = 5
	GameClock.minutes = 10 * 60


## Everything before the Guardian's Year is done: the last page is written
## and the lost Guardian found.
func finish_the_story() -> void:
	for quest: QuestData in QuestLog.QUESTS:
		if not quest.guardian_line:
			QuestLog.completed.append(quest.id)
	QuestLog.unlocks.append(Guidebook.ABILITY)
	QuestLog.unlocks.append(QuestLog.GUARDIAN_FOUND)
	QuestLog.final_entry = 0


func said(lines: Array[Dictionary], text: String) -> bool:
	return lines.any(func(l: Dictionary) -> bool: return text in l.text)


## A work spot standing in the test scene.
func spot_node(id: String) -> WorkSpot:
	var node := WorkSpot.make(Stewardship.get_spot(id))
	add_child(node)
	return node


## Does every spot of [param task].
func do_all(task: String) -> void:
	for spot: Dictionary in Stewardship.spots_for(task):
		var node := spot_node(spot.id)
		node.finish_work()
		node.queue_free()


func _check_data() -> void:
	var year := QuestLog.QUESTS.filter(func(q: QuestData) -> bool: return q.guardian_line)
	check(year.size() == 5, "the Guardian's Year has four arcs and a closing quest (%d)" % year.size())
	for quest: QuestData in year:
		check(not quest.main_line and not quest.press_line and QuestLog.FINALE_QUEST in quest.requires or quest.id == QuestLog.GUARDIAN_YEAR_QUEST,
			"%s comes after the finale" % quest.id)
		check(not QuestLog.get_character(quest.giver).needs_tribal_review, "%s puts no new words in a Native character's mouth" % quest.id)
		check(RegisterPages.HISTORY.has(quest.id), "%s has a Register note" % quest.id)
		for step: Dictionary in quest.steps:
			if step.type != "work":
				continue
			check(Stewardship.TASKS.has(step.task) and Stewardship.spots_for(step.task).size() >= int(step.count),
				"%s: there are %d %s spots to do" % [quest.id, int(step.count), step.task])
	for id: String in ARCS:
		var quest: QuestData = QuestLog.get_quest(id)
		var only := [0, 1, 2, 3].filter(func(s: int) -> bool: return quest.is_offered_in(s))
		check(only == [ARCS[id]], "%s is offered in %s only" % [id, GameClock.SEASON_NAMES[ARCS[id]]])
	check(QuestLog.get_quest(QuestLog.GUARDIAN_YEAR_QUEST).requires.size() == 4, "the year closes once all four arcs are done")
	var ids := {}
	for spot: Dictionary in Stewardship.SPOTS:
		check(not ids.has(spot.id), "work spot %s is unique" % spot.id)
		ids[spot.id] = true
		check(Stewardship.TASKS.has(spot.task), "%s's task %s exists" % [spot.id, spot.task])
		check(ResourceLoader.exists("res://scenes/regions/%s.tscn" % spot.region), "%s's region %s exists" % [spot.id, spot.region])
		if spot.kind == "weed":
			var weed: Dictionary = Stewardship.WEEDS.get(spot.get("plant", ""), {})
			check(not weed.is_empty() and not Herbarium.get_plant(weed.get("native", "")).is_empty(), "%s's weed has a native look-alike in the press book" % spot.id)
	for region_id: String in Stewardship.SIGN_NOTES:
		for sign_name: String in Stewardship.SIGN_NOTES[region_id]:
			check(QuestLog.get_quest(Stewardship.SIGN_NOTES[region_id][sign_name][0]) != null, "%s's note waits on a real quest" % sign_name)


## Three heaves on the bar: in the green sets the step, a miss lets it slip.
func _check_rock_work() -> void:
	var game := RockWork.new()
	add_child(game)
	var results := []
	game.finished.connect(func(set_it: bool) -> void: results.append(set_it))
	game.start(7)
	game.press()
	check(game.results.is_empty(), "the meter waits a moment before it takes a press")
	for i in RockWork.STOPS.size():
		game.step(RockWork.GRACE + 0.01)
		game.meter_pos = game.meter_center
		game.press()
	check(game.outcome == "perfect" and results == [true], "three heaves dead centre: a perfect fit (%s)" % game.outcome)
	game.start(7)
	game.step(RockWork.GRACE + 0.01)
	game.meter_pos = game.meter_center + RockWork.WINDOW * 0.4
	game.press()
	check(game.results.size() == 1 and game.results[0] == "good" and game.stop == 1, "the edge of the green is good, and on to the next heave")
	game.step(RockWork.GRACE + 0.01)
	game.meter_pos = clampf(game.meter_center + 0.4, 0.0, 1.0) if game.meter_center < 0.5 else 0.0
	game.press()
	check(game.outcome == "slipped" and results == [true, false], "a miss lets the block slip back")
	game.start(3)
	for i in 200:
		game.step(0.05)
	check(game.outcome == "slipped", "waiting too long tires your arms out")
	game.free()


func _play_before_the_finale() -> void:
	new_game(GameClock.Season.SPRING)
	check(QuestLog.available_from("george_anderson") == null or not QuestLog.available_from("george_anderson").guardian_line,
		"no Guardian's Year before the Guardian is found")
	check(QuestLog.guardian_objective().is_empty(), "and nothing about it in the journal")
	var node := spot_node("mist_step_1")
	check(node.state() == "" and not node.visible, "the washed-out steps aren't there yet")
	node.free()


func _play_spring() -> void:
	new_game(GameClock.Season.SPRING)
	finish_the_story()
	var hint: Dictionary = QuestLog.guardian_objective()
	check(not hint.is_empty() and hint.quest.id == "anderson_mist_steps" and "George Anderson" in hint.objective,
		"in spring, the journal sends you to George Anderson (%s)" % hint.get("objective", ""))
	check("George Anderson" in HUD.objective_text(), "and so does the pause menu")
	var lines: Array[Dictionary] = QuestLog.talk_to("george_anderson")
	check(QuestLog.active.has("anderson_mist_steps") and said(lines, "rock bar") and QuestLog.is_unlocked("rock_bar"),
		"Anderson hands you a rock bar for the Mist Trail")
	var step := spot_node("mist_step_1")
	check(step.state() == "todo" and step.visible and step.is_usable() and step.get_prompt() == "Reset the step", "the washed-out step can be worked")
	step.finish_work()
	check(step.state() == "done" and not step.is_usable(), "and once it's set, it stays set")
	check("(1 of 4 done)" in QuestLog.objective_text(QuestLog.get_quest("anderson_mist_steps")), "the journal counts the steps")
	check(said(QuestLog.talk_to("george_anderson"), "Bar under the low side"), "Anderson waits for all four")
	do_all("mist_steps")
	check(QuestLog.marker_for("george_anderson") == "?", "with all four set, Anderson wears a ?")
	lines = QuestLog.talk_to("george_anderson")
	check(QuestLog.is_completed("anderson_mist_steps") and said(lines, "New in the Register: a page from George Anderson"), "the steps go in the Register")
	check(said(lines, "Civilian Conservation Corps"), "with a note on who really builds the trails")
	step.free()


func _play_summer() -> void:
	new_game(GameClock.Season.SUMMER)
	finish_the_story()
	QuestLog.completed.append("anderson_mist_steps")
	QuestLog.talk_to("enid_michael")
	check(QuestLog.active.has("enid_cooks_meadow"), "in summer Enid Michael asks for help in Cook's Meadow")
	check(Stewardship.is_wanted("meadow_weeds") and not Stewardship.is_wanted("meadow_paths"), "weeds first, then the shortcuts")
	var weed := spot_node("meadow_weed_1")
	check(weed.get_prompt() == "Pull the Himalayan blackberry", "the prompt names the weed (%s)" % weed.get_prompt())
	check("Enid showed you" in Stewardship.done_text(weed.spot), "without the native blackberry pressed, Enid's word is how you tell")
	Herbarium.press("california_blackberry")
	check("Your press book's California Blackberry" in weed.finish_work(), "with it pressed, the press book is how you know")
	do_all("meadow_weeds")
	check(Stewardship.is_wanted("meadow_paths"), "with the weeds out, the shortcuts are next, without going back to Enid")
	check("Rope off" in QuestLog.objective_text(QuestLog.get_quest("enid_cooks_meadow")), "and the journal says so")
	do_all("meadow_paths")
	check(not Stewardship.grown_back("meadow_path_1"), "the meadow doesn't heal the same season")
	var lines: Array[Dictionary] = QuestLog.talk_to("enid_michael")
	check(QuestLog.is_completed("enid_cooks_meadow") and said(lines, "given one back"), "Enid thanks you for the meadow")
	set_season(GameClock.Season.FALL)
	check(Stewardship.grown_back("meadow_path_1") and Stewardship.grown_back("meadow_weed_1"), "a season later, the paths and the weed patches are green")
	weed.free()


func _play_fall() -> void:
	new_game(GameClock.Season.FALL)
	finish_the_story()
	var lines: Array[Dictionary] = QuestLog.talk_to("galen_clark")
	check(QuestLog.active.has("clark_grove_fire") and said(lines, "sequoia needs fire"), "in fall Clark asks you to burn his grove")
	check(not Stewardship.is_wanted("grove_burn"), "no burn until the fuel's cleared")
	do_all("grove_fuel")
	check(Stewardship.is_wanted("grove_burn"), "then the drip torch is ready")
	var burn := spot_node("grove_burn")
	check(burn.get_prompt() == "Light the burn", "and you can light it")
	check("never higher than your knee" in burn.finish_work(), "a low, slow fire")
	lines = QuestLog.talk_to("galen_clark")
	check(QuestLog.is_completed("clark_grove_fire") and said(lines, "look in the ash"), "Clark sends you back in spring")
	set_season(GameClock.Season.WINTER)
	check(not Stewardship.grown_back("grove_burn"), "nothing comes up in winter")
	GameClock.year += 1
	set_season(GameClock.Season.SPRING)
	check(Stewardship.grown_back("grove_burn") and Stewardship.grown_back("grove_fuel_1"), "the spring after, seedlings come up in the ash")
	burn.free()


func _play_winter() -> void:
	new_game(GameClock.Season.WINTER)
	finish_the_story()
	QuestLog.talk_to("clare_hodges")
	check(QuestLog.active.has("hodges_bear_boxes"), "in winter Ranger Hodges has bear boxes to set")
	var regions := Stewardship.spots_for("bear_boxes").map(func(s: Dictionary) -> String: return s.region)
	check(regions.size() == 4 and "upper_pines" in regions and "housekeeping_camp" in regions, "one at each Valley campground (%s)" % [regions])
	var box := spot_node("bear_box_curry")
	box.finish_work()
	check(box.state() == "done" and box.is_usable() and box.get_prompt() == "Read: Bear Box", "a new bear box you can read")
	do_all("bear_boxes")
	check(said(QuestLog.talk_to("clare_hodges"), "A fed bear is a dead bear"), "Hodges takes the report")
	box.free()


func _play_the_year() -> void:
	new_game(GameClock.Season.SUMMER)
	finish_the_story()
	QuestLog.completed.append_array(["anderson_mist_steps", "enid_cooks_meadow", "clark_grove_fire"])
	var hint: Dictionary = QuestLog.guardian_objective()
	check(hint.quest.id == "hodges_bear_boxes" and "Come winter" in hint.objective, "between arcs, the journal says whose work is next (%s)" % hint.objective)
	QuestLog.completed.append("hodges_bear_boxes")
	QuestLog.talk_to("galen_clark")
	check(QuestLog.active.has(QuestLog.GUARDIAN_YEAR_QUEST), "with a year's work done, Clark has a last word")
	var lines: Array[Dictionary] = QuestLog.talk_to("galen_clark")
	check(QuestLog.is_completed(QuestLog.GUARDIAN_YEAR_QUEST) and QuestLog.is_unlocked("guardian_year"), "and the Guardian's Year is done")
	check(said(lines, "None of it stays done"), "the work never stays done")
	check(RegisterPages.written().any(func(p: Dictionary) -> bool: return p.by == "The Guardian (you)"), "your own page goes in the Register")
	check(QuestLog.guardian_objective().is_empty(), "and nothing is left on the year's list")


func _check_save() -> void:
	new_game(GameClock.Season.FALL)
	Stewardship.finish("grove_fuel_1")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(Stewardship.save_data()))
	Stewardship.start_new_game()
	check(not Stewardship.is_done("grove_fuel_1"), "a new game starts with nothing done")
	Stewardship.load_data(saved)
	check(Stewardship.is_done("grove_fuel_1") and int(Stewardship.done.grove_fuel_1.year) == 2, "the work is saved, with when it was done")


## The regions get their spots on the first visit, and the signs say what
## changed.
func _check_dressing() -> void:
	new_game(GameClock.Season.SPRING)
	finish_the_story()
	QuestLog.completed.append("anderson_mist_steps")
	var region: Region = (load("res://scenes/regions/happy_isles.tscn") as PackedScene).instantiate()
	add_child(region)
	StoryContent.attach(region)
	await get_tree().process_frame
	check(region.entities.has_node("Work_mist_step_1"), "the Mist Trail's steps stand at Happy Isles")
	var board := region.find_child("MistTrailSign", true, false) as InfoSign
	check(board != null and board.extra_active() and "rock bar" in board.current_text(), "and the trail sign says the steps are new")
	region.free()
