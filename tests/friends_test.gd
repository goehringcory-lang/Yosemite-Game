extends Node
## Headless test of everyday talk and friendship (SmallTalk, HeartScenes):
## everyone whose new words are checked has lines for the seasons, the
## weather, the hours and the places they stand; news of what you did gets
## passed on, once; nobody says the same thing twice running; a heart scene
## waits at 3 and at 5 hearts, with a heart over their head, and plays
## through with a question and a gift; and a close friend saves you
## something each week. The Native characters' new lines wait on the
## tribes' next review, so they say only their reviewed lines.
## Run: godot --headless --path . res://tests/friends_test.tscn
## Exit code is the number of failed checks. Uses its own save file.

const KEYS := ["spring", "summer", "fall", "winter", "rain", "snow", "morning", "evening", "friend", "close", "places", "news", "loved"]

var failures := 0
## What the dialogue box has shown, as it tells whoever is speaking (on_line).
var shown: Array[String] = []


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	SaveManager.save_path = "user://friends_test_save.json"
	SaveManager.delete_save()
	add_to_group("talkers")
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	GameClock.paused = true
	test_cast()
	test_lines_fit()
	await test_options_fit(world)
	test_places()
	test_choices()
	test_no_repeats()
	test_news()
	test_loved()
	await test_scenes(world)
	test_save_load()
	SaveManager.delete_save()
	print("OK: %d failure(s)" % failures if failures == 0 else "FAILED: %d failure(s)" % failures)
	get_tree().quit(failures)


## The dialogue box tells "talkers" each line it shows.
func on_line(_speaker: String, text: String, _mood: String) -> void:
	shown.append(text)


func _people() -> Array[CharacterData]:
	var out: Array[CharacterData] = []
	for character: CharacterData in QuestLog.CHARACTERS + QuestLog.STAFF:
		if not character.visitor:
			out.append(character)
	return out


## Everyone with checked words has the lot; the Native characters have none yet.
func test_cast() -> void:
	var missing := []
	var native := 0
	for character in _people():
		var own: Dictionary = SmallTalk.LINES.get(character.id, {})
		var scenes: Dictionary = HeartScenes.SCENES.get(character.id, {})
		if character.id in SmallTalk.AWAITING_REVIEW:
			native += 1
			check(own.is_empty() and scenes.is_empty(), "%s's new lines wait on tribal review" % character.id)
			Friendship.start_new_game()
			Friendship.points[character.id] = Friendship.MAX_HEARTS * Friendship.POINTS_PER_HEART
			var ok := true
			for i in 20:
				for line in SmallTalk.talk(character, character.display_name):
					ok = ok and (line.text in character.idle_lines or line.text in character.rare_lines)
			check(ok and HeartScenes.ready_for(character.id) == 0, "%s says only their reviewed lines, and has no heart scene, even at 5 hearts" % character.id)
			continue
		for key in ["spring", "summer", "fall", "winter", "rain", "snow", "friend", "close", "news", "loved"]:
			if not own.has(key):
				missing.append("%s: %s" % [character.id, key])
		if not (own.has("morning") or own.has("places")):
			missing.append("%s: morning or places" % character.id)
		for level in HeartScenes.LEVELS:
			if not scenes.has(level):
				missing.append("%s: %d-heart scene" % [character.id, level])
	check(missing.is_empty(), "everyone else has lines for each season, the weather, friends, news, gifts and both heart scenes (missing %s)" % [missing])
	check(native == 5, "the five Native characters are left for review (%d)" % native)
	check(SmallTalk.LINES.size() == _people().size() - native and HeartScenes.SCENES.size() == SmallTalk.LINES.size(),
		"%d people have new lines and scenes" % SmallTalk.LINES.size())
	var unknown := []
	for id: String in SmallTalk.LINES:
		if QuestLog.get_character(id) == null:
			unknown.append(id)
		for key: String in SmallTalk.LINES[id]:
			if not key in KEYS:
				unknown.append("%s.%s" % [id, key])
	for id: String in HeartScenes.SCENES:
		if QuestLog.get_character(id) == null:
			unknown.append(id)
	check(unknown.is_empty(), "every entry belongs to someone, under a known key (%s)" % [unknown])


## Every line is one page of the dialogue box, the news has a place for the
## news, and the scenes' questions have an answer for every choice.
func test_lines_fit() -> void:
	var long := []
	var bad := []
	for id: String in SmallTalk.LINES:
		for text in SmallTalk.all_lines(id) + HeartScenes.all_lines(id):
			if DialogueBox.pages(text).size() > 1:
				long.append(text.left(40))
			if text.strip_edges() != text or text == "":
				bad.append(text.left(40))
		var news: Dictionary = SmallTalk.LINES[id].get("news", {})
		for kind: String in news:
			if not kind in SmallTalk.NEWS_KINDS or news[kind].count("%s") != 1 or news[kind].count("%") != 1:
				bad.append("%s news %s" % [id, kind])
		for text in SmallTalk.all_lines(id):
			if "%" in text and not text in news.values():
				bad.append("%s: stray %%" % id)
		for level: int in HeartScenes.SCENES.get(id, {}):
			var scene: Dictionary = HeartScenes.SCENES[id][level]
			var options: Array = scene.get("options", [])
			if options.size() < 2 or options.size() > 4 or options.size() != scene.get("replies", []).size() or scene.get("ask", "") == "":
				bad.append("%s %d: question" % [id, level])
			if scene.get("lines", []).is_empty() or scene.get("end", "") == "":
				bad.append("%s %d: lines" % [id, level])
			for item: String in scene.get("gift", {}):
				if ItemDB.get_item(item) == null:
					bad.append("%s %d: gift %s" % [id, level, item])
			for gear: String in scene.get("gear", {}):
				if Gear.get_gear(gear) == null:
					bad.append("%s %d: gear %s" % [id, level, gear])
			if scene.get("gift", {}).is_empty() and scene.get("gear", {}).is_empty():
				bad.append("%s %d: no gift" % [id, level])
			if level == HeartScenes.LEVELS.back():
				if scene.get("saves", []).is_empty() or scene.get("saved", "") == "":
					bad.append("%s: nothing saved" % id)
				for item: String in scene.get("saves", []):
					if ItemDB.get_item(item) == null:
						bad.append("%s: saves %s" % [id, item])
	check(long.is_empty(), "every new line fits one page of the dialogue box (%s)" % [long])
	check(bad.is_empty(), "news lines, questions and gifts are all well formed (%s)" % [bad])


## Each scene's question and choices fit the dialogue box.
func test_options_fit(world: Node) -> void:
	var wide := []
	var box := DialogueBox.open(world.player)
	for id: String in HeartScenes.SCENES:
		for level: int in HeartScenes.SCENES[id]:
			var scene: Dictionary = HeartScenes.SCENES[id][level]
			box.choose(scene.ask, scene.options, QuestLog.get_character(id).display_name)
			await get_tree().process_frame
			await get_tree().process_frame
			if box._panel.size.x > DialogueBox.BOX_WIDTH + 0.5:
				wide.append("%s %d (%d)" % [id, level, box._panel.size.x])
			box.press(false)
			await get_tree().process_frame
	box.close()
	await get_tree().process_frame
	check(wide.is_empty(), "every scene's choices fit the dialogue box (%s)" % [wide])


## A place line is for somewhere they really stand: their spot, a timetable
## stop, or their region.
func test_places() -> void:
	var where := {}
	for file in DirAccess.get_files_at("res://scenes/story/content"):
		if not file.ends_with(".tscn"):
			continue
		var scene: Node = load("res://scenes/story/content/" + file).instantiate()
		for node in scene.find_children("*", "NPC", true, false):
			var npc := node as NPC
			if npc.character == null:
				continue
			var list: Array = where.get_or_add(npc.character.id, [])
			list.append(file.get_basename())
			list.append(npc.spot)
			for stop: Array in NPC.parse_timetable(npc.timetable):
				list.append(stop[1])
		scene.free()
	var stray := []
	var count := 0
	for id: String in SmallTalk.LINES:
		for place: String in SmallTalk.LINES[id].get("places", {}):
			count += 1
			if not place in where.get(id, []):
				stray.append("%s: %s" % [id, place])
	check(count >= 15 and stray.is_empty(), "%d place lines, each somewhere that person stands (%s)" % [count, stray])


## A date of [param season] whose weather passes [param test].
func _set_day(season: int, test: Callable) -> void:
	GameClock.season = season
	for year in range(1, 6):
		for day in range(1, GameClock.DAYS_PER_SEASON + 1):
			if test.call(Weather.on_day(year, season, day)):
				GameClock.year = year
				GameClock.day = day
				return
	push_error("no such day")


func _texts(choices: Array) -> Array:
	return choices.map(func(choice: Array) -> String: return choice[0])


func _dry(weather: Dictionary) -> bool:
	return weather.rain == 0.0 and weather.snow == 0.0


## What fits is what's said: the season, the weather, the hour, the place
## and how well they know you, with their usual lines mixed in.
func test_choices() -> void:
	Friendship.start_new_game()
	var ansel := QuestLog.get_character("ansel_adams")
	var own: Dictionary = SmallTalk.LINES.ansel_adams
	_set_day(GameClock.Season.SUMMER, _dry)
	GameClock.minutes = 12 * 60
	var texts := _texts(SmallTalk.choices(ansel))
	check(own.summer in texts and not own.winter in texts and not own.rain in texts and not own.snow in texts, "a dry summer day gets the summer line, not winter's or the weather's")
	check(not own.morning in texts and not own.evening in texts, "at noon there's no morning or evening line")
	check(not own.friend in texts and not own.close in texts, "and friends' lines wait for friends")
	check(Array(ansel.idle_lines).all(func(text: String) -> bool: return text in texts), "their usual lines stay in the mix")
	_set_day(GameClock.Season.SPRING, func(weather: Dictionary) -> bool: return weather.rain > 0.0)
	GameClock.minutes = 7 * 60
	var choices := SmallTalk.choices(ansel)
	texts = _texts(choices)
	check(own.spring in texts and own.rain in texts and own.morning in texts, "a rainy spring morning gets spring, rain and morning lines")
	var rain_weight := 0
	var usual_weight := 0
	for choice: Array in choices:
		if choice[0] == own.rain:
			rain_weight = choice[1]
		elif choice[0] in ansel.idle_lines:
			usual_weight = choice[1]
	check(rain_weight > usual_weight, "and the rain comes up more than the usual lines (%d to %d)" % [rain_weight, usual_weight])
	var rainy := 0
	for i in 200:
		if SmallTalk.pick(ansel) == own.rain:
			rainy += 1
	check(rainy > 40, "so on a wet day the rain is talked about often (%d of 200)" % rainy)
	_set_day(GameClock.Season.WINTER, func(weather: Dictionary) -> bool: return weather.snow > 0.0)
	GameClock.minutes = 19 * 60
	texts = _texts(SmallTalk.choices(ansel))
	check(own.snow in texts and own.evening in texts and own.winter in texts and not own.rain in texts, "a snowy winter evening gets snow, winter and evening lines")
	GameClock.minutes = 23 * 60
	texts = _texts(SmallTalk.choices(ansel))
	check(not own.evening in texts and not own.morning in texts, "late at night, neither")
	Friendship.points.ansel_adams = SmallTalk.FRIEND_HEARTS * Friendship.POINTS_PER_HEART
	texts = _texts(SmallTalk.choices(ansel))
	check(own.friend in texts and not own.close in texts, "at %d hearts a friend's line, not yet a close friend's" % SmallTalk.FRIEND_HEARTS)
	Friendship.points.ansel_adams = SmallTalk.CLOSE_HEARTS * Friendship.POINTS_PER_HEART
	texts = _texts(SmallTalk.choices(ansel))
	check(own.friend in texts and own.close in texts, "at %d hearts both" % SmallTalk.CLOSE_HEARTS)
	check(own.places.cooks_meadow in _texts(SmallTalk.choices(ansel, PackedStringArray(["cooks_meadow", "yosemite_village"]))), "in Cook's Meadow Ansel talks about the meadow")
	check(not own.places.cooks_meadow in _texts(SmallTalk.choices(ansel, PackedStringArray(["bests_studio", "yosemite_village"]))), "and not in his studio")
	var enid: Dictionary = SmallTalk.LINES.enid_michael
	var at_dome := _texts(SmallTalk.choices(QuestLog.get_character("enid_michael"), PackedStringArray(["sentinel_dome", "glacier_point"])))
	check(enid.places.glacier_point in at_dome and not enid.places.yosemite_village in at_dome, "a region counts as a place: Enid talks about the view at Sentinel Dome, the labels in the Museum garden")
	Friendship.start_new_game()


## Nobody says the same thing twice running, and there's plenty to hear.
func test_no_repeats() -> void:
	Friendship.start_new_game()
	_set_day(GameClock.Season.FALL, _dry)
	for id: String in ["greg", "john_muir", "galen_clark"]:
		var character := QuestLog.get_character(id)
		var last := ""
		var repeats := 0
		var heard := {}
		var everyday := true
		for i in 80:
			GameClock.minutes = (6 + i % 16) * 60
			var said := SmallTalk.talk(character, character.display_name)
			everyday = everyday and not said.is_empty() and said.all(func(line: Dictionary) -> bool: return line.get("everyday", false))
			var text: String = said[0].text if not said.is_empty() else ""
			if text == last:
				repeats += 1
			last = text
			heard[text] = true
		check(repeats == 0, "%s never says the same line twice running" % id)
		check(heard.size() >= 5, "and has plenty to say (%d different lines)" % heard.size())
		check(everyday, "all of it everyday talk")
	Friendship.start_new_game()


func _said(id: String) -> String:
	var character := QuestLog.get_character(id)
	var lines := SmallTalk.talk(character, character.display_name)
	var texts := PackedStringArray()
	for line: Dictionary in lines:
		texts.append(line.text)
	return " ".join(texts)


## What you did gets about: once each, for a few days, if they have something
## to say about it.
func test_news() -> void:
	Friendship.start_new_game()
	QuestLog.start_new_game()
	FieldLog.start_new_game()
	Achievements.start_new_game()
	_set_day(GameClock.Season.SUMMER, _dry)
	GameClock.minutes = 12 * 60
	check(Friendship.with_article("8-inch Brook Trout") == "an 8-inch Brook Trout" and Friendship.with_article("18-inch Brown Trout") == "an 18-inch Brown Trout"
		and Friendship.with_article("12-inch Rainbow Trout") == "a 12-inch Rainbow Trout" and Friendship.with_article("American Black Bear") == "an American Black Bear"
		and Friendship.with_article("Bobcat") == "a Bobcat", "news says a or an the way it's spoken")
	QuestLog.record_climb("the_nose")
	check(not Friendship.news.is_empty() and Friendship.news.back().what == "the Nose" and Friendship.news.back().kind == "climb", "a first ascent is news (%s)" % [Friendship.news])
	var leonard := _said("dick_leonard")
	check(leonard.begins_with("The Nose? Well done!"), "Leonard brings it up, capitalized (%s)" % leonard)
	check(not "Nose" in _said("dick_leonard"), "once")
	check("the Nose" in _said("wren_alvarez"), "Wren heard about it too")
	check(not QuestLog.record_climb("the_nose") and Friendship.news.size() == 1, "a second time up isn't news")
	GameClock.day += SmallTalk.NEWS_DAYS + 1
	check(not "Nose" in _said("galen_clark"), "after %d days it's old news" % SmallTalk.NEWS_DAYS)
	GameClock.day -= SmallTalk.NEWS_DAYS + 1
	# a rescue: Jo was there, the cache hears about it
	Rescues.rescued.emit({"title": "Lost in Cook's Meadow", "who": "Toby Lindqvist"})
	check("Toby Lindqvist" in _said("mateo_reyes"), "a rescue gets passed on at the cache")
	check(not "Toby" in _said("jo_tolliver"), "but Jo doesn't need telling")
	# fish: a first of its kind, or a trophy
	Achievements.caught({"id": "brown_trout", "length": 18})
	check(_said("greg").begins_with("An 18-inch Brown Trout! Nice."), "Greg hears about your first brown")
	var count := Friendship.news_count
	Achievements.caught({"id": "brown_trout", "length": 12})
	check(Friendship.news_count == count, "a second, smaller one isn't news")
	Achievements.caught({"id": "brown_trout", "length": 24, "trophy": true})
	check(Friendship.news_count == count + 1 and Friendship.news.back().what == "a 24-inch Brown Trout", "a trophy is")
	# sightings: only the rare ones
	count = Friendship.news_count
	FieldLog.spot("robin", true)
	check(Friendship.news_count == count, "a robin isn't news")
	FieldLog.spot("black_bear", true)
	check(Friendship.news.back().what == "an American Black Bear", "a bear is")
	check("an American Black Bear" in _said("clare_hodges"), "and Ranger Hodges wants it logged")
	# someone with nothing to say about a kind of news just talks
	count = Friendship.news_count
	Friendship.note_news("sighting", "a Bobcat")
	check(not "Bobcat" in _said("greg"), "Greg has nothing to say about bobcats")
	# finishing someone's quest: they've heard all about it
	QuestLog.record_climb("snake_dike")
	QuestLog.quest_completed.emit(QuestLog.get_quest("harding_summit"))
	check(not "Snake Dike" in _said("warren_harding"), "whoever gave the quest has just heard the news")
	# and a story beat is news enough
	Friendship.start_new_game()
	QuestLog.completed.append_array(["harding_summit", "johnson_solo", "johnson_astroman"])
	QuestLog.record_climb("swan_slab")
	var beat := QuestLog.talk_to("beverly_johnson")
	check(not beat.is_empty() and not beat[0].get("everyday", false) and not "Swan Slab" in _said("beverly_johnson"), "after their news of the story, they don't bring up what you did too")
	QuestLog.start_new_game()
	FieldLog.start_new_game()
	Achievements.start_new_game()
	Friendship.start_new_game()


## A loved gift gets thanks in their own words.
func test_loved() -> void:
	Friendship.start_new_game()
	Inventory.add("dry_crusts")
	check(Friendship.give("john_muir", "dry_crusts") == SmallTalk.LINES.john_muir.loved, "Muir thanks you for crusts in his own words")
	Inventory.add("acorn_mush")
	check(Friendship.give("tenaya", "acorn_mush") in Friendship.LOVED_LINES, "the reviewed characters' thanks are the usual ones")
	Friendship.start_new_game()


func _find_box() -> DialogueBox:
	for child in get_tree().root.get_children():
		if child is DialogueBox and not child.is_queued_for_deletion():
			return child
	return null


## Talks with [param npc] until it's over, picking [param choice] when asked.
## Returns whether a question came up.
func _talk(npc: NPC, player: Player, choice: int) -> bool:
	shown.clear()
	var asked := false
	npc.interact(player)
	for i in 400:
		await get_tree().process_frame
		var box := _find_box()
		if box == null:
			if not npc._talking:
				break
			continue
		if not box._options.is_empty():
			asked = true
			box._cursor = choice
		box.press()
	return asked


## The scenes at 3 and 5 hearts, and what a close friend saves for you.
func test_scenes(world: Node) -> void:
	Friendship.start_new_game()
	QuestLog.start_new_game()
	_set_day(GameClock.Season.SUMMER, _dry)
	GameClock.minutes = 12 * 60
	await world.go_to_region("yosemite_village", "arrival")
	await get_tree().process_frame
	var mateo: NPC = null
	for node in world.region.find_children("*", "NPC", true, false):
		if (node as NPC).character and node.character.id == "mateo_reyes":
			mateo = node
	check(mateo != null and mateo.quest_marker != null, "Mateo is at the rescue site")
	if mateo == null:
		return
	var player: Player = world.player
	player.global_position = mateo.global_position + Vector2(0, 24)
	Friendship.points.mateo_reyes = 290
	mateo.quest_marker.refresh()
	check(mateo.quest_marker.marker == "" and HeartScenes.ready_for("mateo_reyes") == 0, "no heart before 3 hearts")
	Friendship.add("mateo_reyes", 10)
	mateo.quest_marker.refresh()
	check(HeartScenes.ready_for("mateo_reyes") == 3 and mateo.quest_marker.marker == "heart", "at 3 hearts a heart shows over his head")
	check(Journal.friend_note("mateo_reyes") == "has something to tell you", "and the Journal says he has something to tell you")
	check(SmallTalk.talk(mateo.character, "Mateo Reyes").is_empty(), "small talk makes way for the scene")
	var jerky := Inventory.count("beef_jerky")
	var asked := await _talk(mateo, player, 2)
	var scene: Dictionary = HeartScenes.SCENES.mateo_reyes[3]
	check(asked and scene.lines[0] in shown, "talking to him, he tells you about the cache log and asks you something")
	check(scene.replies[2] in shown and not scene.replies[0] in shown, "he answers what you said")
	check(Inventory.count("beef_jerky") == jerky + 2 and shown.any(func(text: String) -> bool: return text.begins_with("Received 2 Beef Jerky")), "and gives you something")
	mateo.quest_marker.refresh()
	check(Friendship.scenes.get("mateo_reyes") == 3 and HeartScenes.ready_for("mateo_reyes") == 0 and mateo.quest_marker.marker == "", "the scene is seen and the heart goes")
	var after := QuestLog.talk_to("mateo_reyes")
	check(not after.is_empty() and after[0].get("everyday", false), "and next time it's everyday talk")
	Friendship.add("mateo_reyes", 500)
	check(HeartScenes.ready_for("mateo_reyes") == 5, "at 5 hearts there's another")
	var mix := Inventory.count("trail_mix")
	await _talk(mateo, player, 0)
	check(HeartScenes.SCENES.mateo_reyes[5].lines[0] in shown and Inventory.count("trail_mix") == mix + 2, "he tells you about El Cap and gives you trail mix")
	check(HeartScenes.close("mateo_reyes") and Journal.friend_note("mateo_reyes") == "saves you something each week", "now he's a close friend")
	check(HeartScenes.saved_gift("mateo_reyes", "Mateo Reyes").is_empty(), "who saves you something, starting a week from now")
	GameClock.day += HeartScenes.SAVE_EVERY
	var saves: Array = HeartScenes.SCENES.mateo_reyes[5].saves
	var before := saves.map(func(id: String) -> int: return Inventory.count(id))
	var saved := SmallTalk.talk(mateo.character, "Mateo Reyes")
	var after_counts := saves.map(func(id: String) -> int: return Inventory.count(id))
	check(saved.size() == 2 and saved[0].text == HeartScenes.SCENES.mateo_reyes[5].saved and saved[1].text.begins_with("Received 1 "), "a week later he has something for you (%s)" % [saved])
	check(after_counts != before and saved.all(func(line: Dictionary) -> bool: return line.get("everyday", false)), "it's in your pack")
	check(not SmallTalk.talk(mateo.character, "Mateo Reyes")[0].text.begins_with("Received"), "then it's a week until the next")
	GameClock.day -= HeartScenes.SAVE_EVERY
	# a vendor's friend: Marty, at the Mountain Shop counter
	Friendship.points.mountain_shop = 300
	check(HeartScenes.ready_for("mountain_shop") == 3, "Marty has a scene at 3 hearts too")


func test_save_load() -> void:
	var saved := Friendship.save_data()
	Friendship.start_new_game()
	Friendship.load_data(JSON.parse_string(JSON.stringify(saved)))
	check(Friendship.scenes.get("mateo_reyes") == 5 and Friendship.saved_for_you.has("mateo_reyes") and Friendship.said.size() == saved.said.size(), "scenes seen and things saved are saved")
	check(Friendship.news.size() == saved.news.size() and Friendship.news_count == saved.news_count and Friendship.told == saved.told, "and so is the news")
	Friendship.load_data({"points": {"john_muir": 120.0}, "talked": {}, "gifted": {}})
	check(Friendship.hearts("john_muir") == 1 and Friendship.scenes.is_empty() and Friendship.news.is_empty() and Friendship.news_count == 0, "a save from before all this loads fine")
	Friendship.start_new_game()
